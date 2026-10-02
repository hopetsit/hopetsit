/**
 * pawPointsRoutes — v416 (refonte niveaux + récompenses, Daniel).
 *
 *   GET  /pawpoints/catalog   → niveaux, barème, récompenses abonnement (fixes)
 *                               + récompenses admin custom. PUBLIC.
 *   GET  /pawpoints/me        → mon état (points à vie + dépensables + niveau +
 *                               progression) + récompenses déjà réclamées. AUTH.
 *   POST /pawpoints/redeem/:id → échange. id = sub_* (abonnement, auto-appliqué,
 *                               1×/user) OU ObjectId (récompense admin custom).
 *
 * 100% ADDITIF. L'app + le site LISENT le catalogue → modif admin sans rebuild.
 */

const express = require('express');
const mongoose = require('mongoose');
const { requireAuth } = require('../middleware/auth');
const PawReward = require('../models/PawReward');
const PawRewardRedemption = require('../models/PawRewardRedemption');
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const pawPoints = require('../services/pawPointsService');
const { grantFreePeriod } = require('../services/subscriptionGrantService');
const logger = require('../utils/logger');

const router = express.Router();

const ROLE_TO_MODEL_NAME = { owner: 'Owner', sitter: 'Sitter', walker: 'Walker' };

/**
 * v532 — identité complète d'un compte : son email et les identifiants de ses
 * TROIS documents de rôle. Un compte HoPetSit possède un document par rôle
 * (propriétaire / gardien / promeneur) reliés par l'email ; tout ce qui était
 * calculé sur le seul document du rôle actif (points, contributions,
 * récompenses déjà réclamées) « disparaissait » au changement de profil.
 */
async function _identity(userId, role) {
  const out = { email: '', ids: [] };
  try {
    const r = String(role || '').toLowerCase();
    const Model = r === 'walker' ? Walker : r === 'sitter' ? Sitter : Owner;
    const me = await Model.findById(userId).select('email name').lean();
    if (!me) return out;
    out.email = me.email || '';
    out.name = me.name || '';
    // v576 — les identifiants des profils frères viennent maintenant de
    // `utils/personScope` (bâti sur identityGroup) : il relie aussi les
    // comptes par `oldId`, que la recherche par e-mail seule laissait de côté
    // (anciens profils dont l'e-mail a changé). Même définition de « la
    // personne » que les amis, les blocages et les PawSpots.
    const { personIds } = require('../utils/personScope');
    out.ids = await personIds(userId);
    if (!out.ids.length) out.ids = [userId];
  } catch (_) { /* best-effort */ }
  return out;
}
const modelFor = (role) => {
  const r = String(role || '').toLowerCase();
  return r === 'walker' ? Walker : r === 'sitter' ? Sitter : Owner;
};

// 607 (ZOE) — barème lu dans le catalogue UNIQUE (pawPointsCatalog607).
// Les apps ≤ 606 traduisent `pawpoints_earn_<key>` et retombent sinon sur
// `label` (français) : on ne leur envoie que les 6 gains qu'elles savent
// traduire. 607+, site et admin : tout le barème.
const LEGACY_EARN_KEYS = ['spotCreated', 'photoAdded', 'spotValidated', 'usefulComment', 'correctReport', 'spotPopular'];
const _clientBuild = (req) => {
  const v = String((req && req.headers && req.headers['x-app-version']) || '').trim();
  if (!v) return null;
  const m = v.match(/(?:\+|^)(\d{1,6})$/);
  return m ? Number(m[1]) : null;
};
const isLegacyApp = (req) => {
  const b = _clientBuild(req);
  return b !== null && b < 607;
};
const earnRules = (req) => pawPoints.CATALOG607.EARN_RULES
  .filter((r) => !isLegacyApp(req) || LEGACY_EARN_KEYS.includes(r.key))
  .map((r) => ({ key: r.key, points: r.points, label: r.t.fr, icon: r.icon, limit: r.limit }));

// Niveaux exposés (avec index, label, seuil, couleur, emoji, bonus, perks).
const levelsList = () => pawPoints.LEVELS.map((l) => ({
  index: l.index, key: l.key, label: l.label, min: l.min,
  emoji: l.emoji, color: l.color, bonusPct: l.bonusPct, perks: l.perks,
}));

// ─── GET /catalog ───────────────────────────────────────────────────────────
router.get('/catalog', async (req, res) => {
  try {
    // 607 — plus aucune « réduction » : une récompense admin de type
    // `discount` n'est plus proposée (ni échangeable, cf. /redeem).
    const customRewards = (await PawReward.find({ isActive: true })
      .sort({ sortOrder: 1, cost: 1 }).lean())
      .filter((r) => (r.kind || 'discount') !== 'discount');
    res.json({
      // 607 (ZOE) — catalogue UNIQUE app / site / admin, textes 9 langues.
      catalog607: pawPoints.CATALOG607.buildCatalog607(pawPoints.LEVELS),
      // Apps ≤ 606 : seulement les paliers 30 / 30 / 90 jours (voir service).
      subscriptionRewards: pawPoints.SUBSCRIPTION_REWARDS,
      rewards: customRewards.map((r) => ({
        id: String(r._id), title: r.title, description: r.description || '',
        icon: r.icon || '🎁', cost: r.cost || 0, kind: r.kind || 'discount',
        valueLabel: r.valueLabel || '',
        soldOut: !!(r.stock && r.stock > 0 && (r.redeemedCount || 0) >= r.stock),
      })),
      levels: levelsList(),
      earnRules: earnRules(req),
      goldCreatorMin: pawPoints.GOLD_CREATOR_MIN,
    });
  } catch (e) {
    logger.error('[pawpoints/catalog]', e);
    res.status(500).json({ error: 'Erreur catalogue.' });
  }
});

// ─── GET /me ─────────────────────────────────────────────────────────────────
router.get('/me', requireAuth, async (req, res) => {
  try {
    const role = req.user?.role || 'owner';
    const st = await pawPoints.getPawState(req.user.id, role);
    // v532 — identité complète du compte (email + les 3 documents de rôle).
    const me = await _identity(req.user.id, role);
    // v416 — stats contributions (design : "Tes contributions" + "Spots aimés").
    let contributions = 0;
    let spotsLiked = 0;
    try {
      const MapReport = require('../models/MapReport');
      const PawSpot = require('../models/PawSpot');
      // v532 — les contributions étaient comptées sur le seul document du rôle
      // actif : un PawSpot ajouté depuis le profil propriétaire n'apparaissait
      // plus après un changement de profil. On compte sur les 3 profils.
      const ids = me.ids.length ? me.ids : [req.user.id];
      contributions = await MapReport.countDocuments({ reporterId: { $in: ids } });
      const spots = await PawSpot.find({ creatorId: { $in: ids } }).select('likesCount').lean();
      spotsLiked = spots.reduce((s, x) => s + (Number(x.likesCount) || 0), 0);
    } catch (_) { /* best-effort */ }
    // Récompenses abonnement déjà réclamées (1×/user).
    // v532 — la limite « 1 fois par utilisateur » se basait sur l'id du
    // DOCUMENT DE RÔLE. Un même compte ayant trois profils (propriétaire /
    // gardien / promeneur), il suffisait de changer de profil pour réclamer
    // une troisième fois la même récompense. On déduplique sur l'email.
    const claimed = await PawRewardRedemption.find({
      ...(me?.email
        ? { userEmail: me.email }
        : { userId: req.user.id }),
      rewardKey: { $regex: '^(sub_|perk_)' },
      status: { $ne: 'cancelled' },
    }).select('rewardKey status').lean();
    // 607 — cadre doré obtenu (récompense perk_gold_frame), sur l'un des 3 profils.
    let goldFrame = false;
    try {
      const ids = me.ids.length ? me.ids : [req.user.id];
      goldFrame = (await Promise.all([Owner, Sitter, Walker].map((M) => M.exists({ _id: { $in: ids }, pawGoldFrame: true }))))
        .some(Boolean);
    } catch (_) { /* best-effort */ }
    // 607 — derniers gains d'activité (journal PawPointsEvent, la personne).
    let history = [];
    try {
      const PawPointsEvent = require('../models/PawPointsEvent');
      const { personKeyFromEmail } = require('../services/pawPointsActivity607');
      const pk = personKeyFromEmail(me.email) || `id:${req.user.id}`;
      history = (await PawPointsEvent.find({ personKey: pk })
        .sort({ at: -1 }).limit(20).select('key points credited at').lean())
        .map((h) => ({ key: h.key, points: h.points, credited: h.credited, at: h.at }));
    } catch (_) { /* best-effort */ }
    res.json({
      points: st.lifetime,           // total à vie (= niveau)
      lifetime: st.lifetime,
      spendable: st.spendable,        // solde dépensable
      contributions,                  // nb de signalements créés
      spotsLiked,                     // total de likes sur mes PawSpots
      level: st.level,
      nextLevel: st.nextLevel,
      bonusPct: st.bonusPct,
      isGoldCreator: st.isGoldCreator,
      goldCreatorMin: st.goldCreatorMin,
      levels: levelsList(),
      earnRules: earnRules(req),
      claimedRewardKeys: claimed.map((c) => c.rewardKey),
      history,
      catalogVersion: 607,
      goldFrame,
    });
  } catch (e) {
    logger.error('[pawpoints/me]', e);
    res.status(500).json({ error: 'Erreur points.' });
  }
});

// ─── POST /checkin (607) ─────────────────────────────────────────────────────
// « Je suis là aujourd'hui » : série de 7 jours, profil complet, Pionnier.
// Le début de session (utils/activity590) le fait déjà pour toutes les apps ;
// l'app 607 l'appelle en ouvrant la page PawPoints pour afficher le gain.
router.post('/checkin', requireAuth, async (req, res) => {
  try {
    const role = String(req.user?.role || 'owner').toLowerCase();
    const awarded = await require('../services/pawPointsActivity607')
      .checkIn({ userId: req.user.id, role });
    res.json({ ok: true, awarded });
  } catch (e) {
    logger.error('[pawpoints/checkin]', e);
    res.status(500).json({ error: 'Erreur.' });
  }
});

// Débit atomique du solde dépensable (anti double-dépense).
async function spendPoints(Model, userId, cost, role) {
  // Backfill paresseux : si pawPointsSpendable absent, = pawPoints (à vie).
  await Model.updateOne(
    { _id: userId, pawPointsSpendable: { $exists: false } },
    [{ $set: { pawPointsSpendable: { $ifNull: ['$pawPoints', 0] } } }],
  ).catch(() => {});
  const debited = await Model.findOneAndUpdate(
    { _id: userId, pawPointsSpendable: { $gte: cost } },
    { $inc: { pawPointsSpendable: -cost } },
    { new: true },
  ).select('pawPointsSpendable');
  if (!debited) return null;
  // v532 — SANS CECI, LES MÊMES POINTS ÉTAIENT DÉPENSABLES TROIS FOIS. Le
  // débit ne touchait que le document du rôle actif ; les profils frères du
  // même compte gardaient leur solde intact, il suffisait de changer de profil
  // pour réclamer à nouveau la récompense. On aligne les trois documents
  // (le nouveau solde étant le plus bas, la synchro par MAX ne peut pas le
  // relever : on écrit donc explicitement la valeur débitée).
  try {
    const { syncPointsAcrossRoles } = require('../services/pawPointsService');
    const newBalance = Number(debited.pawPointsSpendable);
    const me = await Model.findById(userId).select('email pawPoints').lean();
    if (me?.email) {
      await Promise.all(
        [Owner, Sitter, Walker].map((M) => M.updateOne(
          { email: me.email },
          { $set: { pawPointsSpendable: newBalance } },
        ).catch(() => {})),
      );
      // Réaligne aussi le total À VIE (qui, lui, ne baisse jamais).
      await syncPointsAcrossRoles(userId, role);
    }
  } catch (_) { /* best-effort : le débit principal a déjà eu lieu */ }
  return Number(debited.pawPointsSpendable);
}

/**
 * v532 — remboursement des points quand l'octroi de la récompense échoue.
 * Doit toucher les TROIS profils, comme le débit : sinon le solde du rôle
 * actif remontait mais restait plus bas sur les autres, et la synchro par MAX
 * les réalignait ensuite… en rendant les points là où ils n'avaient pas été
 * repris. On recrédite partout la même valeur.
 */
async function _refundPoints(userId, role, cost) {
  try {
    const Model = modelFor(role);
    const back = await Model.findByIdAndUpdate(
      userId,
      { $inc: { pawPointsSpendable: Number(cost) || 0 } },
      { new: true },
    ).select('email pawPointsSpendable');
    if (!back?.email) return;
    await Promise.all(
      [Owner, Sitter, Walker].map((M) => M.updateOne(
        { email: back.email },
        { $set: { pawPointsSpendable: Number(back.pawPointsSpendable) || 0 } },
      ).catch(() => {})),
    );
  } catch (e) {
    logger.error('[pawpoints] remboursement des points échoué', e);
  }
}

const _redeemLocks = new Set();

// ─── POST /redeem/:id ─────────────────────────────────────────────────────────
router.post('/redeem/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;
    const role = String(req.user?.role || 'owner').toLowerCase();
    const userModel = ROLE_TO_MODEL_NAME[role] || 'Owner';
    const Model = modelFor(role);

    // 607 — anciennes réductions en % : plus échangeables (celles déjà
    // échangées restent valables au prochain achat, cf. snapshot).
    if (pawPoints.CATALOG607.isLegacyDiscountId(id)) {
      return res.status(410).json({ error: 'Récompense retirée.', code: 'REWARD_RETIRED' });
    }

    // ── Récompense du CATALOGUE 607 (code-définie) ─────────────────────────
    const catReward = pawPoints.CATALOG607.rewardById(id);
    if (catReward) {
      const ident = await _identity(req.user.id, role);
      // 607 — double clic / deux requêtes en même temps : un seul échange à la
      // fois par personne (le contrôle « déjà obtenu » puis le débit ne sont
      // pas atomiques ensemble).
      const lockKey = `${(ident.email || req.user.id)}`;
      if (_redeemLocks.has(lockKey)) {
        return res.status(409).json({ error: 'Échange déjà en cours.', code: 'IN_PROGRESS' });
      }
      _redeemLocks.add(lockKey);
      try {
      if (catReward.once) {
        // 1×/personne — dédup sur l'EMAIL (v532), pas sur le document de rôle.
        const already = await PawRewardRedemption.findOne({
          ...(ident.email ? { userEmail: ident.email } : { userId: req.user.id }),
          rewardKey: catReward.id,
          status: { $ne: 'cancelled' },
        }).lean();
        if (already) {
          return res.status(409).json({ error: 'Récompense déjà utilisée.', code: 'ALREADY_CLAIMED' });
        }
      }
      const newBalance = await spendPoints(Model, req.user.id, catReward.cost, role);
      if (newBalance === null) {
        return res.status(400).json({ error: 'Pas assez de PawPoints.', code: 'INSUFFICIENT' });
      }
      let grantedUntil = null;
      try {
        if (catReward.kind === 'free_days') {
          // Palier PawFollow : l'app ≤ 606 pouvait choisir PawSpot à la place.
          const asked = typeof req.body?.plan === 'string' ? req.body.plan : '';
          const plan = catReward.plan === 'monthly' && ['monthly', 'pawspot'].includes(asked)
            ? asked : catReward.plan;
          const sub = await grantFreePeriod({ userId: req.user.id, role, plan, days: catReward.days });
          grantedUntil = sub && (sub.premiumExpiry || sub.pawspotExpiry || sub.currentPeriodEnd) || null;
        } else if (catReward.kind === 'pawboost') {
          const now = new Date();
          const u = await Model.findById(req.user.id).select('boostExpiry boostTier');
          if (!u) throw new Error('profil introuvable');
          const base = u.boostExpiry && new Date(u.boostExpiry) > now ? new Date(u.boostExpiry) : now;
          u.boostExpiry = new Date(base.getTime() + catReward.days * 86400000);
          if (!u.boostTier) u.boostTier = catReward.boostTier || 'bronze';
          await u.save();
          grantedUntil = u.boostExpiry;
        } else if (catReward.kind === 'avatar_frame') {
          // Les 3 profils de la personne (même e-mail).
          const ids = ident.ids && ident.ids.length ? ident.ids : [req.user.id];
          await Promise.all([Owner, Sitter, Walker].map((M) => M.updateMany(
            { _id: { $in: ids } }, { $set: { pawGoldFrame: true } },
          ).catch(() => {})));
        } else {
          throw new Error(`type inconnu ${catReward.kind}`);
        }
      } catch (e) {
        logger.error('[pawpoints/redeem] grant failed, refunding', e);
        await _refundPoints(req.user.id, role, catReward.cost);
        return res.status(500).json({ error: 'Échec de l\'application, points remboursés.' });
      }
      const me = await Model.findById(req.user.id).select('name email').lean();
      const redemption = await PawRewardRedemption.create({
        rewardKey: catReward.id,
        title: catReward.t.fr,
        cost: catReward.cost,
        userId: req.user.id, userModel, role,
        userName: me?.name || '', userEmail: me?.email || '',
        status: 'fulfilled',
        snapshot: { id: catReward.id, kind: catReward.kind, days: catReward.days || 0, plan: catReward.plan || '', catalog: 607 },
      });
      logger.info(`🎁 [pawpoints] redeem ${catReward.id} (-${catReward.cost}) → ${role}:${req.user.id}`);
      return res.json({
        ok: true, newBalance, applied: 'fulfilled', grantedUntil,
        redemptionId: String(redemption._id),
        reward: { id: catReward.id, kind: catReward.kind, cost: catReward.cost },
      });
      } finally {
        _redeemLocks.delete(lockKey);
      }
    }

    // ── Récompense ADMIN custom (ObjectId) ──────────────────────────────────
    if (!mongoose.isValidObjectId(id)) {
      return res.status(404).json({ error: 'Récompense indisponible.' });
    }
    const reward = await PawReward.findById(id);
    // 607 — plus aucune réduction échangeable (même règle que le catalogue).
    if (!reward || !reward.isRedeemable() || (reward.kind || 'discount') === 'discount') {
      return res.status(404).json({ error: 'Récompense indisponible.' });
    }
    const newBalance = await spendPoints(Model, req.user.id, reward.cost, role);
    if (newBalance === null) {
      return res.status(400).json({ error: 'Pas assez de PawPoints.', code: 'INSUFFICIENT' });
    }

    // v450 — Daniel : « vérifie que les récompenses fonctionnent ». RACINE :
    // une récompense admin custom de type `subscription`/`boost` débitait les
    // points mais ne créait qu'une redemption `pending` JAMAIS honorée
    // automatiquement → l'utilisateur perdait ses points pour rien. On
    // OCTROIE désormais immédiatement (comme les récompenses abo intégrées) :
    //   subscription → grantFreePeriod (jours d'abo offerts)
    //   boost        → prolonge boostExpiry du user
    //   discount/badge/goodie → reste 'pending' (réduction consommée à l'achat
    //   ou remise/goodie traités à la main par l'admin).
    let applied = 'pending';
    try {
      if (reward.kind === 'subscription' && reward.plan) {
        await grantFreePeriod({
          userId: req.user.id,
          role,
          plan: reward.plan,
          days: Number(reward.intervalDays) || 30,
        });
        applied = 'fulfilled';
      } else if (reward.kind === 'boost') {
        const now = new Date();
        const u = await Model.findById(req.user.id).select('boostExpiry boostTier');
        if (u) {
          const base = u.boostExpiry && new Date(u.boostExpiry) > now
            ? new Date(u.boostExpiry) : now;
          u.boostExpiry = new Date(base.getTime() + (Number(reward.intervalDays) || 7) * 86400000);
          if (reward.boostTier) u.boostTier = reward.boostTier;
          await u.save();
          applied = 'fulfilled';
        }
      }
    } catch (e) {
      // Octroi échoué → on rembourse les points dépensés.
      logger.error('[pawpoints/redeem] admin reward grant failed, refunding', e);
      await _refundPoints(req.user.id, role, reward.cost);
      return res.status(500).json({ error: 'Échec de l\'application, points remboursés.' });
    }

    reward.redeemedCount = (reward.redeemedCount || 0) + 1;
    await reward.save();
    const me = await Model.findById(req.user.id).select('name email').lean();
    const redemption = await PawRewardRedemption.create({
      rewardId: reward._id, title: reward.title, cost: reward.cost,
      userId: req.user.id, userModel, role,
      userName: me?.name || '', userEmail: me?.email || '',
      status: applied,
      snapshot: {
        kind: reward.kind, plan: reward.plan, intervalDays: reward.intervalDays,
        boostTier: reward.boostTier, valueLabel: reward.valueLabel,
      },
    });
    logger.info(`🎁 [pawpoints] redeem "${reward.title}" (-${reward.cost}) → ${role}:${req.user.id} (${applied})`);
    return res.json({
      ok: true, newBalance, applied,
      redemptionId: String(redemption._id),
      reward: { id: String(reward._id), title: reward.title, cost: reward.cost },
    });
  } catch (e) {
    logger.error('[pawpoints/redeem]', e);
    res.status(500).json({ error: 'Erreur échange.' });
  }
});

module.exports = router;
