/**
 * subscriptionGrantService — v416.
 *
 * Octroi GRATUIT d'une période d'abonnement (récompense PawPoints "mois
 * gratuit") SANS paiement. Réplique la logique d'extension d'expiry de
 * POST /subscriptions/confirm, mais déclenchée par l'échange de points.
 */

const UserSubscription = require('../models/UserSubscription');
const {
  isFamilyPlan,
  isPremiumPlan,
  migrateLegacyFamily,
  PREMIUM_FEATURES_DEFAULT,
} = require('../models/UserSubscription');
const logger = require('../utils/logger');

const ROLE_TO_MODEL_NAME = { owner: 'Owner', sitter: 'Sitter', walker: 'Walker' };

/**
 * Prolonge l'abonnement de [days] jours pour [plan], gratuitement.
 * @returns la souscription mise à jour.
 */
async function grantFreePeriod({ userId, role, plan, days }) {
  const userModel = ROLE_TO_MODEL_NAME[String(role || '').toLowerCase()] || 'Owner';
  const now = new Date();
  let sub = await UserSubscription.findOne({ userId, userModel });
  if (!sub) sub = new UserSubscription({ userId, userModel });

  const planCanonical = plan === 'family' ? 'famille' : plan;
  migrateLegacyFamily(sub, now);
  const extendFrom = (d) =>
    new Date((d && new Date(d) > now ? new Date(d) : now).getTime() + days * 86400000);

  let periodEnd;
  if (isFamilyPlan(planCanonical)) {
    periodEnd = extendFrom(sub.familyExpiry);
    sub.familyExpiry = periodEnd;
    sub.status = 'active';
  } else if (isPremiumPlan(planCanonical)) {
    sub.plan = planCanonical;
    sub.status = 'active';
    sub.currentPeriodStart = sub.currentPeriodStart || now;
    sub.currentPeriodEnd = extendFrom(sub.currentPeriodEnd);
    sub.pawspotExpiry = extendFrom(sub.pawspotExpiry);
    sub.premiumExpiry = extendFrom(sub.premiumExpiry);
    periodEnd = sub.currentPeriodEnd;
    sub.features = { ...PREMIUM_FEATURES_DEFAULT };
  } else {
    // PawFollow (monthly / yearly) — étend currentPeriodEnd.
    sub.plan = planCanonical;
    sub.status = 'active';
    sub.currentPeriodStart = sub.currentPeriodStart || now;
    sub.currentPeriodEnd = extendFrom(sub.currentPeriodEnd);
    periodEnd = sub.currentPeriodEnd;
  }
  sub.cancelAtPeriodEnd = false;
  sub.payments = sub.payments || [];
  sub.payments.push({
    plan,
    amount: 0,
    currency: 'EUR',
    paidAt: now,
    paymentProvider: 'pawpoints',
    paymentIntentId: '',
    periodStart: now,
    periodEnd,
  });
  await sub.save();

  try {
    const { syncSubscriptionAcrossRoles } = require('../models/UserSubscription');
    if (typeof syncSubscriptionAcrossRoles === 'function') {
      await syncSubscriptionAcrossRoles(userId, userModel);
    }
  } catch (_) { /* best-effort */ }

  logger.info(`🎁 [pawpoints] mois gratuit accordé : ${role}:${userId} ${plan} +${days}j → ${periodEnd.toISOString()}`);
  return sub;
}

module.exports = { grantFreePeriod };
