/**
 * v566 — Réductions boutique RÉSERVÉES à la création du paiement, CONSOMMÉES
 * à sa réussite.
 *
 * Avant : le code promo %, la réduction de parrainage (-10 %) et la réduction
 * PawPoints étaient marqués « consommés » dès POST /subscriptions/subscribe
 * (création du PaymentIntent). Si l'utilisateur fermait la feuille de
 * paiement, sa réduction était PERDUE sans avoir rien payé.
 *
 * Maintenant :
 *   1. `pickDiscounts()`   — trouve les réductions disponibles (non consommées)
 *                            et calcule le montant réduit. N'écrit RIEN.
 *   2. `reserveDiscounts()`— une fois le PaymentIntent créé, pose sur chaque
 *                            réduction `reservedIntentId` + `reservedUntil`
 *                            (30 min). Une réserve n'est PAS une consommation.
 *   3. `consumeDiscounts()`— à l'activation (/confirm ET webhook ET wallet),
 *                            marque consommé de façon ATOMIQUE et idempotente
 *                            (filtre « pas encore consommé ») : deux appels,
 *                            une seule consommation.
 *
 * Les références voyagent dans les métadonnées du PaymentIntent
 * (`discountRefs` = "promo:<id>,paw:<id>,ref:<id>") : /confirm les relit sur
 * l'intention vérifiée chez Airwallex, le webhook les reçoit telles quelles.
 *
 * Abandon : la réserve expire seule au bout de 30 min ; et si le MÊME
 * utilisateur relance un achat avant (il a juste fermé la feuille), la
 * nouvelle intention reprend la réserve — la réduction reste donc utilisable
 * tout de suite, jamais perdue.
 */

const logger = require('../utils/logger');

const RESERVATION_TTL_MS = 30 * 60 * 1000;

const KINDS = Object.freeze({
  promo: {
    model: () => require('../models/PromoCodeRedemption'),
    notConsumed: { discountConsumedAt: null },
    consumeSet: (piId, now) => ({ discountConsumedAt: now, discountConsumedIntentId: piId }),
    reserveSet: (piId, until) => ({ discountReservedIntentId: piId, discountReservedUntil: until }),
  },
  paw: {
    model: () => require('../models/PawRewardRedemption'),
    notConsumed: { status: 'pending' },
    consumeSet: (piId) => ({ status: 'fulfilled', consumedIntentId: piId }),
    reserveSet: (piId, until) => ({ reservedIntentId: piId, reservedUntil: until }),
  },
  ref: {
    model: () => require('../models/Referral'),
    notConsumed: { rewardConsumed: { $ne: true } },
    consumeSet: (piId, now) => ({
      rewardConsumed: true, rewardConsumedAt: now, rewardConsumedIntentId: piId,
    }),
    reserveSet: (piId, until) => ({ rewardReservedIntentId: piId, rewardReservedUntil: until }),
  },
});

const round2 = (n) => Math.round(n * 100) / 100;

function planMatchesPromo(rewardPlan, plan) {
  const p = rewardPlan;
  return !p || p === 'any' || p === plan
    || (plan === 'family' && p === 'famille')
    || (plan === 'famille' && p === 'family');
}

/**
 * Réductions applicables à cet achat. Lecture seule.
 *
 * Règles inchangées (historique subscriptionRoutes) :
 *   - parrainage -10 % puis PawPoints -X % peuvent se cumuler ;
 *   - le code promo % ne s'applique que si AUCUNE des deux autres ne s'applique ;
 *   - scope 'pawspot' : seule la réduction PawPoints (sentinelle 'pawspot').
 *
 * @returns {Promise<{amount:number, fullAmount:number, applied:Array<{kind,id,percent}>}>}
 */
async function pickDiscounts({ userId, plan, baseAmount, scope = 'subscription' }) {
  const applied = [];
  let amount = Number(baseAmount);

  if (scope === 'subscription') {
    try {
      const Referral = KINDS.ref.model();
      const avail = await Referral.findOne({
        referrerId: userId,
        status: 'completed',
        creditAwarded: true,
        rewardConsumed: { $ne: true },
      });
      if (avail) {
        amount = round2(amount * 0.9);
        applied.push({ kind: 'ref', id: String(avail._id), percent: 10 });
      }
    } catch (e) {
      logger.warn(`[discounts] referral check failed: ${e.message}`);
    }
  }

  try {
    const PawRewardRedemption = KINDS.paw.model();
    const pending = await PawRewardRedemption.find({
      userId, rewardKey: { $regex: '^sub_disc_' }, status: 'pending',
    }).sort({ createdAt: 1 });
    const wanted = scope === 'pawspot' ? 'pawspot' : plan;
    const match = (pending || []).find((r) => {
      const plans = (r.snapshot && r.snapshot.plans) || [];
      return Array.isArray(plans) && plans.includes(wanted);
    });
    const pct = match ? Number(match.snapshot.percent) || 0 : 0;
    if (match && pct > 0) {
      amount = round2(amount * (1 - pct / 100));
      applied.push({ kind: 'paw', id: String(match._id), percent: pct });
    }
  } catch (e) {
    logger.warn(`[discounts] pawpoints check failed: ${e.message}`);
  }

  if (scope === 'subscription' && applied.length === 0) {
    try {
      const PromoCodeRedemption = KINDS.promo.model();
      const pendingPromos = await PromoCodeRedemption.find({
        userId,
        'reward.kind': 'percent_discount',
        discountConsumedAt: null,
      }).sort({ createdAt: 1 });
      const match = (pendingPromos || []).find(
        (r) => planMatchesPromo(r.reward && r.reward.plan, plan),
      );
      const pct = match ? Number(match.reward.discountPercent) || 0 : 0;
      if (match && pct > 0) {
        amount = round2(amount * (1 - pct / 100));
        applied.push({ kind: 'promo', id: String(match._id), percent: pct });
      }
    } catch (e) {
      logger.warn(`[discounts] promo check failed: ${e.message}`);
    }
  }

  return { amount, fullAmount: Number(baseAmount), applied };
}

/** "promo:<id>,paw:<id>" — tient dans une métadonnée de PaymentIntent. */
function encodeRefs(applied) {
  return (applied || []).map((a) => `${a.kind}:${a.id}`).join(',');
}

function decodeRefs(refs) {
  if (Array.isArray(refs)) return refs.filter((a) => a && KINDS[a.kind] && a.id);
  return String(refs || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean)
    .map((s) => {
      const i = s.indexOf(':');
      return i > 0 ? { kind: s.slice(0, i), id: s.slice(i + 1) } : null;
    })
    .filter((a) => a && KINDS[a.kind] && a.id);
}

/**
 * Pose la réserve (30 min) sur les réductions d'une intention créée.
 * Ne consomme rien. Une réserve précédente du même utilisateur (feuille
 * fermée puis nouvel essai) est simplement remplacée.
 */
async function reserveDiscounts({ applied, piId, now = new Date() }) {
  const until = new Date(now.getTime() + RESERVATION_TTL_MS);
  let reserved = 0;
  for (const a of decodeRefs(applied)) {
    const k = KINDS[a.kind];
    try {
      const r = await k.model().updateOne(
        { _id: a.id, ...k.notConsumed },
        { $set: k.reserveSet(String(piId), until) },
      );
      if (r && (r.modifiedCount || r.nModified || r.matchedCount)) reserved += 1;
    } catch (e) {
      logger.warn(`[discounts] reserve ${a.kind}:${a.id} failed: ${e.message}`);
    }
  }
  return { reserved, reservedUntil: until };
}

/**
 * Consomme les réductions d'un paiement RÉUSSI. Atomique + idempotent : le
 * filtre exige « pas encore consommé », donc /confirm puis webhook (ou
 * l'inverse, ou deux webhooks) ne consomment qu'UNE fois.
 *
 * @returns {Promise<number>} nombre de réductions consommées PAR CET APPEL
 */
async function consumeDiscounts({ refs, piId, now = new Date() }) {
  let consumed = 0;
  for (const a of decodeRefs(refs)) {
    const k = KINDS[a.kind];
    try {
      const doc = await k.model().findOneAndUpdate(
        { _id: a.id, ...k.notConsumed },
        { $set: k.consumeSet(String(piId || ''), now) },
        { new: true },
      );
      if (doc) {
        consumed += 1;
        logger.info(`[discounts] ${a.kind}:${a.id} consommée par le paiement ${piId}`);
      }
    } catch (e) {
      logger.warn(`[discounts] consume ${a.kind}:${a.id} failed: ${e.message}`);
    }
  }
  return consumed;
}

module.exports = {
  RESERVATION_TTL_MS,
  pickDiscounts,
  reserveDiscounts,
  consumeDiscounts,
  encodeRefs,
  decodeRefs,
};
