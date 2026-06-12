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
const { normalizeCurrency } = require('../utils/currency');
const logger = require('../utils/logger');

const router = express.Router();

// v21.1.1 — Stripe purgé. Default 'airwallex' (compte Stripe fermé).
const PROVIDER = (process.env.PAYMENT_PROVIDER || 'airwallex').toLowerCase();

// ── Helpers ──────────────────────────────────────────────────────────────────
const ROLE_TO_MODEL_NAME = { owner: 'Owner', sitter: 'Sitter', walker: 'Walker' };

function userModelFromRole(role) {
  return ROLE_TO_MODEL_NAME[role] || 'Owner';
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
      const u = await ModelCtor.findById(userId).select('isStaff').lean();
      if (u && u.isStaff) {
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

    // v23.1.332 — Daniel : nouveau parrainage = -10% sur un plan PawFollow ou
    // PawFamily (au lieu de 5€), valable pour les 3 rôles. Si l'utilisateur a une
    // réduction de parrainage DISPONIBLE (un filleul a complété sa 1ère
    // réservation), on applique -10% sur CE plan et on consomme la réduction.
    let referralDiscountApplied = false;
    try {
      const Referral = require('../models/Referral');
      const avail = await Referral.findOne({
        referrerId: userId,
        status: 'completed',
        creditAwarded: true,
        rewardConsumed: { $ne: true },
      });
      if (avail) {
        pricing.amount = Math.round(pricing.amount * 0.9 * 100) / 100;
        avail.rewardConsumed = true;
        avail.rewardConsumedAt = new Date();
        await avail.save();
        referralDiscountApplied = true;
        logger.info(
          `[subscription] parrainage -10% appliqué pour ${role} ${userId} `
          + `(referral ${avail._id}) → nouveau montant ${pricing.amount} ${pricing.currency}`,
        );
      }
    } catch (e) {
      logger.warn(`[subscription] referral discount check failed: ${e.message}`);
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
        await activateSubscriptionFromWebhook({
          piId: `wallet_${Date.now()}_${plan}`,
          metadata: {
            userId: String(userId),
            role,
            plan,
            intervalDays: String(pricing.intervalDays),
            currency: pricing.currency,
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
        // v23.1 part 62 — attach customer_id so the HPP auto-displays the
        // user's saved cards on Premium / subscription purchases.
        let airwallexCustomerId = null;
        try {
          const userDoc = await StaffModel.findById(userId).select('email name').lean();
          if (userDoc && userDoc.email) {
            const customer = await airwallex.findOrCreateCustomer({
              userId: String(userId),
              email: userDoc.email,
              firstName: (userDoc.name || '').split(' ')[0] || userDoc.name || '',
              lastName: (userDoc.name || '').split(' ').slice(1).join(' ') || '',
            });
            airwallexCustomerId = customer?.id || null;
          }
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
          ...(airwallexCustomerId ? { customer_id: airwallexCustomerId } : {}),
          metadata: {
            type: 'subscription_purchase',
            userId: String(userId),
            role,
            plan,
            currency: pricing.currency,
            intervalDays: String(pricing.intervalDays),
          },
        });

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
          currency: pricing.currency,
          intervalDays: pricing.intervalDays,
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

    sub.payments = sub.payments || [];
    sub.payments.push({
      plan,
      amount: pricing.amount,
      currency: pricing.currency,
      paidAt: now,
      paymentProvider: 'stripe',
      paymentIntentId: paymentIntentId || '',
      periodStart: startFrom,
      periodEnd: newPeriodEnd,
    });

    await sub.save();

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
