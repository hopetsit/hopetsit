/**
 * Subscription Routes — PawFollow plans.
 *
 * Plans (v23.1, aligned with hopetsit.com pricing):
 *   monthly → €6.99 / 30 days
 *   yearly  → €49.99 / 365 days
 *   family  → €9.99 / 30 days (up to 5 members)
 *
 * Live prices read from pricingService (DB-backed, editable from admin).
 * If pricingService is not initialised or missing a row, falls back to
 * PREMIUM_PRICING in UserSubscription.js.
 *
 * Each plan creates a one-time Airwallex PaymentIntent that extends
 * `currentPeriodEnd` on the UserSubscription doc. The webhook in
 * airwallexWebhookController activates the subscription server-side.
 */

const express = require('express');
const { requireAuth } = require('../middleware/auth');
const UserSubscription = require('../models/UserSubscription');
const {
  PREMIUM_PLAN_INTERVALS,
  PREMIUM_PRICING,
  PREMIUM_FEATURES_DEFAULT,
  getPlanPricing,
} = require('../models/UserSubscription');
const airwallex = require('../services/airwallexService');
// v568 — cartes enregistrées : UN client Airwallex par personne (partagé par
// les profils owner / sitter / walker) + branchement unique du client sur
// l'intention de paiement. Cf. utils/airwallexCustomer.js.
const {
  ensureAirwallexCustomer,
  intentCustomerFields,
} = require('../utils/airwallexCustomer');
const { normalizeCurrency } = require('../utils/currency');
const logger = require('../utils/logger');
// v532 — verification du paiement avant toute activation boutique.
const { assertPaidIntent, PaymentNotVerifiedError } = require('../utils/assertPaidIntent');
// v566 — plateforme d'origine de l'achat (ios | android | web).
const { platformFromRequest, normalizePlatform } = require('../utils/purchasePlatform');

const router = express.Router();

// v21.1.1 — Stripe purgé. Default 'airwallex' (compte Stripe fermé).
const PROVIDER = (process.env.PAYMENT_PROVIDER || 'airwallex').toLowerCase();

// ── Helpers ──────────────────────────────────────────────────────────────────
const ROLE_TO_MODEL_NAME = { owner: 'Owner', sitter: 'Sitter', walker: 'Walker' };

function userModelFromRole(role) {
  return ROLE_TO_MODEL_NAME[role] || 'Owner';
}

// v566 — montant / devise RÉELLEMENT payés : d'abord l'intention Airwallex
// vérifiée (unités majeures), puis la métadonnée posée à la création, enfin le
// prix catalogue.
function resolvePaidAmount(pi, pricing) {
  const candidates = [pi?.amount, pi?.metadata?.paidAmount];
  for (const c of candidates) {
    const n = Number(c);
    if (c !== undefined && c !== null && c !== '' && Number.isFinite(n) && n >= 0) {
      return {
        amount: n,
        currency: String(pi?.currency || pi?.metadata?.currency || pricing.currency).toUpperCase(),
      };
    }
  }
  return { amount: pricing.amount, currency: pricing.currency };
}

// v566 — prestataire enregistré dans l'historique : airwallex | paypal |
// wallet | apple — jamais 'stripe'.
function resolveProvider(pi) {
  const raw = String(pi?.metadata?.provider || '').toLowerCase();
  if (raw === 'paypal') return 'paypal';
  if (raw === 'wallet') return 'wallet';
  if (raw === 'apple' || raw === 'apple_iap') return 'apple';
  return 'airwallex';
}

function serializeSubscription(sub) {
  if (!sub) {
    return {
      plan: 'none',
      status: 'none',
      isPremium: false,
      features: { ...PREMIUM_FEATURES_DEFAULT, mapReportsVisible: false, mapReportsCreate: false, socialFriendsMap: false, socialChat: false, socialProximityAlerts: false, mapBoostMonthlyCredit: 0 },
      currentPeriodEnd: null,
      cancelAtPeriodEnd: false,
      mapBoostCreditsRemaining: 0,
    };
  }
  // v23.1.283 — expose le timer FAMILLE découplé (familyExpiry) + un flag
  // familyActive (familyExpiry futur OU ancien plan='famille' actif), pour que
  // les consommateurs de /status (site web) détectent la famille même quand
  // l'abo individuel et la famille sont distincts.
  const _now = new Date();
  const _famExp = sub.familyExpiry
    ? sub.familyExpiry
    : ((sub.plan === 'famille' || sub.plan === 'family') && sub.currentPeriodEnd
        ? sub.currentPeriodEnd
        : null);
  const familyActive = !!(_famExp && new Date(_famExp) > _now);
  // v23.1.387 — Paw Premium (bundle) : timer dédié aux extras.
  const premiumBundleActive = !!(sub.premiumExpiry && new Date(sub.premiumExpiry) > _now);
  return {
    plan: sub.plan,
    status: sub.status,
    isPremium: sub.isCurrentlyPremium ? sub.isCurrentlyPremium() : (sub.status === 'active' && sub.currentPeriodEnd && new Date(sub.currentPeriodEnd) > new Date()),
    familyActive,
    familyExpiry: _famExp,
    premiumBundleActive,
    premiumExpiry: sub.premiumExpiry || null,
    pawspotExpiry: sub.pawspotExpiry || null,
    features: sub.features || {},
    currentPeriodStart: sub.currentPeriodStart,
    currentPeriodEnd: sub.currentPeriodEnd,
    cancelAtPeriodEnd: sub.cancelAtPeriodEnd,
    canceledAt: sub.canceledAt,
    mapBoostCreditsRemaining: sub.mapBoostCreditsRemaining || 0,
    payments: (sub.payments || []).slice(-5).reverse(),
  };
}

// ── GET plans (public) — accepts ?currency=EUR|GBP|CHF|USD ─────────────────
router.get('/plans', (req, res) => {
  const currency = normalizeCurrency(req.query.currency);
  // v22.2 — Bug 16a : on filter() les nulls retournés par getPlanPricing
  // pour qu'un plan sans prix valide (ex: family pas encore seed en DB)
  // ne casse pas le rendu des autres côté frontend.
  const plans = Object.keys(PREMIUM_PLAN_INTERVALS)
    .map((key) => {
      const p = getPlanPricing(key, currency);
      if (!p) return null;
      return {
        plan: key,
        amount: p.amount,
        currency: p.currency,
        intervalDays: p.intervalDays,
        label: p.label,
        amountPerDay: +(p.amount / p.intervalDays).toFixed(3),
      };
    })
    .filter(Boolean);
  res.json({
    plans,
    currency,
    supportedCurrencies: Object.keys(PREMIUM_PRICING),
    features: PREMIUM_FEATURES_DEFAULT,
  });
});

// ── GET my subscription status ──────────────────────────────────────────────
router.get('/status', requireAuth, async (req, res) => {
  try {
    const userId = req.user.id;
    const userModel = userModelFromRole(req.user.role);

    const sub = await UserSubscription.findOne({ userId, userModel });

    // v19.1.5 — Staff users (Daniel + employees) get Premium for free.
    const ModelCtor = {
      Owner: require('../models/Owner'),
      Sitter: require('../models/Sitter'),
      Walker: require('../models/Walker'),
    }[userModel];
    if (ModelCtor) {
      const u = await ModelCtor.findById(userId).select('isStaff email oldId').lean();
      let staff = !!(u && u.isStaff);
      // v497 — Daniel : isStaff peut n'être posé que sur UN des 3 docs rôle →
      // si l'ami se connecte sous un autre rôle, il perd son premium staff. On
      // relit isStaff sur les 3 docs (même email/oldId) → premium quel que soit
      // le rôle, sans re-cocher dans l'admin. (Cf même fix /users/me/benefits.)
      if (!staff && u && (u.email || u.oldId)) {
        try {
          const or = [];
          if (u.email) or.push({ email: u.email });
          if (u.oldId) or.push({ oldId: u.oldId });
          const [o, s2, w] = await Promise.all([
            require('../models/Owner').findOne({ $or: or, isStaff: true }).select('_id').lean(),
            require('../models/Sitter').findOne({ $or: or, isStaff: true }).select('_id').lean(),
            require('../models/Walker').findOne({ $or: or, isStaff: true }).select('_id').lean(),
          ]);
          if (o || s2 || w) staff = true;
        } catch (_) {/* best-effort */}
      }
      if (staff) {
        return res.json({
          plan: 'staff',
          status: 'active',
          isPremium: true,
          isStaff: true,
          features: { ...PREMIUM_FEATURES_DEFAULT, mapReportsVisible: true, mapReportsCreate: true, socialFriendsMap: true, socialChat: true, socialProximityAlerts: true, mapBoostMonthlyCredit: 999 },
          currentPeriodStart: new Date(0),
          currentPeriodEnd: new Date('2099-12-31'),
          cancelAtPeriodEnd: false,
          canceledAt: null,
          mapBoostCreditsRemaining: 999,
          payments: [],
        });
      }
    }

    res.json(serializeSubscription(sub));
  } catch (e) {
    logger.error('[subscription/status]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /subscribe — create PaymentIntent for a plan ───────────────────────
router.post('/subscribe', requireAuth, async (req, res) => {
  try {
    const { plan } = req.body;
    const currency = normalizeCurrency(req.body.currency);
    const pricing = getPlanPricing(plan, currency);
    if (!pricing) {
      return res.status(400).json({
        error: `Invalid plan. Choose from: ${Object.keys(PREMIUM_PLAN_INTERVALS).join(', ')}`,
      });
    }

    const userId = req.user.id;
    const role = req.user.role;

    // v20.0.2 — Staff users get Premium FREE forever.
    // v23.1.148 — Daniel : "pawfollow ne saffiche pas". Avant on retournait
    // juste {staff:true, activated:true} sans persister. Conséquence :
    // /users/me/benefits (qui alimente ActiveBenefitsRow) renvoyait
    // isPremium:false car ni UserSubscription ni Owner.isPremium n'étaient
    // marqués → le badge ⭐ Premium disparaissait. Maintenant on upsert une
    // vraie UserSubscription active pour que le badge apparaisse.
    const StaffModel = role === 'walker'
      ? require('../models/Walker')
      : role === 'sitter'
        ? require('../models/Sitter')
        : require('../models/Owner');
    const staffUser = await StaffModel.findById(userId).select('isStaff').lean();
    if (staffUser && staffUser.isStaff) {
      try {
        const userModelName = userModelFromRole(role);
        // v23.1.178 — Daniel : "je prend labonement famille et y se passe
        // rien". Normalisation défensive 'family' → 'famille' AVANT le
        // sub.save() pour éviter toute ValidationError silencieuse,
        // indépendamment du pre-save hook. Tous les routes lectures filtrent
        // par 'famille' (FR canonique).
        const planCanonical = plan === 'family' ? 'famille' : plan;
        // v23.1.387 — Paw Premium + Famille annuel (mêmes règles que le
        // chemin webhook, cf purchaseActivationController).
        const { isFamilyPlan, isPremiumPlan } = require('../models/UserSubscription');
        const isFamilyPurchase = isFamilyPlan(planCanonical);
        const isPremiumPurchase = isPremiumPlan(planCanonical);
        let sub = await UserSubscription.findOne({ userId, userModel: userModelName });
        const now = new Date();
        if (!sub) sub = new UserSubscription({ userId, userModel: userModelName });
        // v23.1.283 — découplage famille/individuel (cf purchaseActivationController).
        const { migrateLegacyFamily } = require('../models/UserSubscription');
        migrateLegacyFamily(sub, now);
        const extendFrom = (d) =>
          new Date((d && new Date(d) > now ? new Date(d) : now).getTime() + pricing.intervalDays * 86_400_000);
        let startFrom = now;
        let newPeriodEnd;
        if (isFamilyPurchase) {
          startFrom = sub.familyExpiry && new Date(sub.familyExpiry) > now
            ? new Date(sub.familyExpiry)
            : now;
          newPeriodEnd = extendFrom(sub.familyExpiry);
          sub.familyExpiry = newPeriodEnd;
          sub.status = 'active';
        } else if (isPremiumPurchase) {
          // Bundle : étend tracking + PawSpot + extras Premium.
          startFrom = sub.currentPeriodEnd && new Date(sub.currentPeriodEnd) > now
            ? new Date(sub.currentPeriodEnd)
            : now;
          newPeriodEnd = extendFrom(sub.currentPeriodEnd);
          sub.plan = planCanonical;
          sub.status = 'active';
          sub.currentPeriodStart = sub.currentPeriodStart || now;
          sub.currentPeriodEnd = newPeriodEnd;
          sub.pawspotExpiry = extendFrom(sub.pawspotExpiry);
          sub.premiumExpiry = extendFrom(sub.premiumExpiry);
        } else {
          startFrom = sub.currentPeriodEnd && new Date(sub.currentPeriodEnd) > now
            ? new Date(sub.currentPeriodEnd)
            : now;
          newPeriodEnd = extendFrom(sub.currentPeriodEnd);
          sub.plan = planCanonical;
          sub.status = 'active';
          sub.currentPeriodStart = sub.currentPeriodStart || now;
          sub.currentPeriodEnd = newPeriodEnd;
        }
        sub.cancelAtPeriodEnd = false;
        sub.features = { ...PREMIUM_FEATURES_DEFAULT };
        sub.payments = sub.payments || [];
        sub.payments.push({
          plan: planCanonical,
          amount: 0,
          currency: pricing.currency,
          paidAt: now,
          paymentProvider: 'staff_free',
          paymentIntentId: '',
          periodStart: startFrom,
          periodEnd: newPeriodEnd,
        });
        await sub.save();
        logger.info(
          `[subscription/staff] OK ${role} ${userId} sub=${sub._id} plan=${planCanonical}`,
        );
      } catch (persistErr) {
        logger.error(
          `[subscription/staff] persist FAILED for ${role} ${userId} plan=${plan}: ${persistErr.message}`,
        );
      }
      logger.info(`[subscription/staff] ${role} ${userId} — Premium free (staff) — persisted`);
      return res.json({
        staff: true,
        activated: true,
        plan,
        amount: 0,
        currency: pricing.currency,
        intervalDays: pricing.intervalDays,
      });
    }

    // v566 — RÉDUCTIONS (parrainage -10 %, PawPoints -X %, code promo %) :
    // on les CHOISIT ici sans rien écrire ; elles sont RÉSERVÉES sur
    // l'intention de paiement une fois créée, et CONSOMMÉES seulement quand le
    // paiement a réussi (/confirm, webhook, ou tout de suite pour le wallet).
    // Avant : consommées dès la création de l'intention → un utilisateur qui
    // fermait la feuille de paiement perdait sa réduction sans avoir payé.
    // Règles de cumul inchangées (cf discountReservationService.pickDiscounts).
    const discounts = require('../services/discountReservationService');
    const fullAmount = pricing.amount;
    const picked = await discounts.pickDiscounts({
      userId, plan, baseAmount: pricing.amount, scope: 'subscription',
    });
    pricing.amount = picked.amount;
    const discountRefs = discounts.encodeRefs(picked.applied);
    if (picked.applied.length) {
      logger.info(
        `[subscription] réductions ${discountRefs} pour ${role} ${userId} : `
        + `${fullAmount} → ${pricing.amount} ${pricing.currency} (réservées, pas consommées)`,
      );
    }

    const amountCents = Math.round(pricing.amount * 100);

    // ─── v23.1 part 84 — pay-with-wallet (walker/sitter only)
    const payWithWallet = req.body?.payWithWallet === true;
    if (payWithWallet && (role === 'walker' || role === 'sitter')) {
      try {
        const { payFromWallet } = require('../services/walletService');
        await payFromWallet({
          userId: String(userId),
          userRole: role,
          amount: pricing.amount,
          currency: pricing.currency,
          type: 'debit_purchase',
          reference: `pawfollow_${plan}`,
          meta: { kind: 'subscription', plan, intervalDays: pricing.intervalDays },
        });
        const { activateSubscriptionFromWebhook } = require('../controllers/purchaseActivationController');
        // v566 — paiement wallet = réussi immédiatement : l'activation
        // consomme les réductions et enregistre le montant RÉELLEMENT débité.
        await activateSubscriptionFromWebhook({
          piId: `wallet_${Date.now()}_${plan}`,
          metadata: {
            userId: String(userId),
            role,
            plan,
            intervalDays: String(pricing.intervalDays),
            currency: pricing.currency,
            provider: 'wallet',
            paidAmount: String(pricing.amount),
            fullAmount: String(fullAmount),
            discountRefs,
            platform: platformFromRequest(req),
          },
        });
        return res.json({
          activated: true,
          paidFromWallet: true,
          plan,
          intervalDays: pricing.intervalDays,
          amount: pricing.amount,
          currency: pricing.currency,
        });
      } catch (e) {
        if (e.code === 'INSUFFICIENT_BALANCE') {
          return res.status(402).json({ error: 'Solde wallet insuffisant.', code: 'INSUFFICIENT_BALANCE' });
        }
        logger.error('[subscription] payWithWallet failed', e);
        return res.status(500).json({ error: e.message });
      }
    }

    // ─── Airwallex flow ────────────────────────────────────────────────────
    if (PROVIDER === 'airwallex') {
      try {
        // v568 — client Airwallex partagé par les 3 profils (utilitaire
        // commun `utils/airwallexCustomer.js`) : la carte enregistrée
        // ailleurs dans l'app est proposée ici aussi.
        let airwallexCustomerId = null;
        let defaultConsentId = null;
        try {
          const ensured = await ensureAirwallexCustomer({
            userId: String(userId),
            role,
            logTag: 'subscription',
          });
          airwallexCustomerId = ensured.customerId;
          defaultConsentId = ensured.defaultConsentId;
        } catch (custErr) {
          logger.warn(`[subscription] customer ensure failed: ${custErr?.message || custErr}`);
        }

        // v23.1.158 — Daniel : "sa ne prend pas en compte ma carte cb
        // enregistrer". v156 retirait customer_id ; on le restaure pour
        // que Airwallex liste les cartes sauvegardees sur l'achat
        // subscription. Le vrai bug bloquant (PI cancelled reutilise)
        // est fixe en v157.
        const intent = await airwallex.createPlatformPaymentIntent({
          amount: amountCents,
          currency: pricing.currency,
          ...intentCustomerFields({ customerId: airwallexCustomerId }),
          metadata: {
            type: 'subscription_purchase',
            userId: String(userId),
            role,
            plan,
            currency: pricing.currency,
            intervalDays: String(pricing.intervalDays),
            // v566 — montant réellement facturé + réductions réservées.
            paidAmount: String(pricing.amount),
            fullAmount: String(fullAmount),
            // (jamais de valeur vide dans les métadonnées d'une intention)
            ...(discountRefs ? { discountRefs } : {}),
            ...(platformFromRequest(req) ? { platform: platformFromRequest(req) } : {}),
          },
        });

        // v566 — réserve (30 min) : liée à CETTE intention, non consommée.
        if (picked.applied.length) {
          await discounts.reserveDiscounts({ applied: picked.applied, piId: intent.id });
        }

        logger.info(
          `[subscription] airwallex PI created ${intent.id} ${pricing.amount} ${pricing.currency} ` +
          `plan ${plan} by ${role} ${userId}`,
        );

        return res.json({
          clientSecret: intent.client_secret,
          paymentIntentId: intent.id,
          provider: 'airwallex',
          plan,
          amount: pricing.amount,
          fullAmount,
          discountPercent: picked.applied.reduce((m, a) => Math.max(m, a.percent), 0),
          currency: pricing.currency,
          intervalDays: pricing.intervalDays,
          // v568 — transmis à la page Airwallex par l'app : sans lui, les
          // cartes enregistrées ne sont pas listées.
          customerId: airwallexCustomerId,
          defaultConsentId,
        });
      } catch (e) {
        logger.error('[subscription] airwallex create-intent failed', e);
        return res.status(502).json({
          error: 'Unable to start premium subscription right now. Please try again later.',
        });
      }
    }

    // ─── Stripe disabled (v21.1.1 purge) ─────────────────────────────────
    return res.status(502).json({ error: 'Stripe payment disabled — Airwallex only' });
  } catch (e) {
    logger.error('[subscription/subscribe] Error creating PaymentIntent', e);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /confirm — after Stripe success, extend premium window ─────────────
router.post('/confirm', requireAuth, async (req, res) => {
  try {
    // v532 — FAILLE : cet endpoint activait le produit sans jamais verifier
    // le paiement aupres d Airwallex. On exige desormais un PaymentIntent
    // reellement SUCCEEDED, appartenant a l appelant, et non deja consomme.
    let paidIntent = null;
    try {
      paidIntent = await assertPaidIntent({
        paymentIntentId: req.body?.paymentIntentId,
        userId: req.user.id,
        purpose: 'subscription',
      });
    } catch (guardErr) {
      if (guardErr instanceof PaymentNotVerifiedError) {
        // Deja consomme = le webhook Airwallex a active l achat avant nous.
        // Ce n est pas une erreur : sans ce cas, l utilisateur verrait un
        // message d echec alors qu il a paye ET que le produit est actif.
        // C est aussi ce qui empeche la DOUBLE activation (1 paiement qui
        // donnait 2 mois d abonnement).
        if (guardErr.code === 'PAYMENT_INTENT_ALREADY_USED') {
          return res.json({ success: true, alreadyActivated: true });
        }
        return res.status(guardErr.status).json({
          error: guardErr.message,
          code: guardErr.code,
        });
      }
      throw guardErr;
    }
    const { plan, paymentIntentId } = req.body;
    const currency = normalizeCurrency(req.body.currency);
    const pricing = getPlanPricing(plan, currency);
    if (!pricing) {
      return res.status(400).json({ error: 'Invalid plan.' });
    }

    const userId = req.user.id;
    const userModel = userModelFromRole(req.user.role);
    const now = new Date();

    // Upsert subscription doc
    let sub = await UserSubscription.findOne({ userId, userModel });
    if (!sub) {
      sub = new UserSubscription({ userId, userModel });
    }

    // v23.1.283 — découplage famille/individuel (cf purchaseActivationController).
    // v23.1.387 — Paw Premium + Famille annuel (mêmes règles que le webhook).
    const planCanonical = plan === 'family' ? 'famille' : plan;
    const { migrateLegacyFamily, isFamilyPlan, isPremiumPlan } = require('../models/UserSubscription');
    const isFamilyPurchase = isFamilyPlan(planCanonical);
    const isPremiumPurchase = isPremiumPlan(planCanonical);
    migrateLegacyFamily(sub, now);
    const extendFrom = (d) =>
      new Date((d && new Date(d) > now ? new Date(d) : now).getTime() + pricing.intervalDays * 86400000);
    let startFrom = now;
    let newPeriodEnd;
    if (isFamilyPurchase) {
      startFrom = sub.familyExpiry && new Date(sub.familyExpiry) > now
        ? new Date(sub.familyExpiry)
        : now;
      newPeriodEnd = extendFrom(sub.familyExpiry);
      sub.familyExpiry = newPeriodEnd;
      sub.status = 'active';
    } else if (isPremiumPurchase) {
      // Bundle : étend tracking + PawSpot + extras Premium.
      startFrom = sub.currentPeriodEnd && new Date(sub.currentPeriodEnd) > now
        ? new Date(sub.currentPeriodEnd)
        : now;
      newPeriodEnd = extendFrom(sub.currentPeriodEnd);
      sub.plan = planCanonical;
      sub.status = 'active';
      sub.currentPeriodStart = sub.currentPeriodStart || now;
      sub.currentPeriodEnd = newPeriodEnd;
      sub.pawspotExpiry = extendFrom(sub.pawspotExpiry);
      sub.premiumExpiry = extendFrom(sub.premiumExpiry);
    } else {
      startFrom = sub.currentPeriodEnd && new Date(sub.currentPeriodEnd) > now
        ? new Date(sub.currentPeriodEnd)
        : now;
      newPeriodEnd = extendFrom(sub.currentPeriodEnd);
      sub.plan = planCanonical;
      sub.status = 'active';
      sub.currentPeriodStart = sub.currentPeriodStart || now;
      sub.currentPeriodEnd = newPeriodEnd;
    }
    sub.cancelAtPeriodEnd = false;
    sub.lastPaymentIntentId = paymentIntentId || '';

    // Feature flags (Premium unlocks everything)
    sub.features = { ...PREMIUM_FEATURES_DEFAULT };

    // Top up map-boost credits: 1 per month. For yearly plans = 12 credits.
    const creditsToAdd = pricing.intervalDays >= 365 ? 12 : 1;
    sub.mapBoostCreditsRemaining = (sub.mapBoostCreditsRemaining || 0) + creditsToAdd;
    sub.mapBoostCreditsResetAt = newPeriodEnd;

    // v566 — historique : le montant RÉELLEMENT payé (après réduction) et la
    // devise lus sur l'intention vérifiée chez Airwallex, et le vrai
    // prestataire. Avant : plein tarif catalogue + 'stripe' (compte fermé).
    // Les anciennes lignes ne sont pas modifiées ('stripe' historique = carte
    // Airwallex).
    const paid = resolvePaidAmount(paidIntent, pricing);
    sub.payments = sub.payments || [];
    if (!sub.payments.some((pm) => paymentIntentId && pm.paymentIntentId === paymentIntentId)) {
      const platform = normalizePlatform(paidIntent?.metadata?.platform) || platformFromRequest(req);
      sub.payments.push({
        plan,
        amount: paid.amount,
        currency: paid.currency,
        // v566 — montant lu chez le prestataire + plateforme d'origine.
        amountSource: 'psp',
        ...(platform ? { platform } : {}),
        paidAt: now,
        paymentProvider: resolveProvider(paidIntent),
        paymentIntentId: paymentIntentId || '',
        periodStart: startFrom,
        periodEnd: newPeriodEnd,
      });
    }

    await sub.save();

    // v566 — le paiement a réussi : on consomme les réductions réservées sur
    // cette intention (idempotent : le webhook peut repasser sans effet).
    try {
      const discounts = require('../services/discountReservationService');
      await discounts.consumeDiscounts({
        refs: paidIntent?.metadata?.discountRefs,
        piId: paymentIntentId,
      });
    } catch (e) {
      logger.warn(`[subscription/confirm] consume discounts failed: ${e.message}`);
    }

    // v23.1.388 — propage les timers aux comptes frères (même email).
    try {
      const { syncSubscriptionAcrossRoles } = require('../models/UserSubscription');
      await syncSubscriptionAcrossRoles(userId, userModel);
    } catch (_) { /* */ }

    logger.info(`[subscription] ${req.user.role} ${userId} activated ${plan} → expires ${newPeriodEnd.toISOString()}`);

    res.json({
      message: 'Premium activated!',
      ...serializeSubscription(sub),
    });
  } catch (e) {
    logger.error('[subscription/confirm]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /cancel — cancel at period end (keeps access until then) ───────────
router.post('/cancel', requireAuth, async (req, res) => {
  try {
    const userId = req.user.id;
    const userModel = userModelFromRole(req.user.role);

    const sub = await UserSubscription.findOne({ userId, userModel });
    if (!sub || sub.status !== 'active') {
      return res.status(404).json({ error: 'No active subscription to cancel.' });
    }

    sub.cancelAtPeriodEnd = true;
    sub.canceledAt = new Date();
    await sub.save();

    logger.info(`[subscription] ${req.user.role} ${userId} canceled at period end`);
    res.json({
      message: 'Subscription will end at the current period.',
      ...serializeSubscription(sub),
    });
  } catch (e) {
    logger.error('[subscription/cancel]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /resume — undo a pending cancellation ──────────────────────────────
router.post('/resume', requireAuth, async (req, res) => {
  try {
    const userId = req.user.id;
    const userModel = userModelFromRole(req.user.role);

    const sub = await UserSubscription.findOne({ userId, userModel });
    if (!sub || !sub.cancelAtPeriodEnd) {
      return res.status(404).json({ error: 'No cancellation to resume.' });
    }

    sub.cancelAtPeriodEnd = false;
    sub.canceledAt = null;
    await sub.save();

    res.json({
      message: 'Subscription resumed.',
      ...serializeSubscription(sub),
    });
  } catch (e) {
    logger.error('[subscription/resume]', e);
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
