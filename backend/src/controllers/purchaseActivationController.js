/**
 * Purchase Activation Controller — v23.1
 *
 * Handles server-side activation of non-booking purchases (PawSpot map_boost,
 * PawFollow subscription) when their Airwallex PaymentIntent succeeds.
 *
 * Why this exists:
 *   Until v23.0, both flows relied on the client calling /confirm after the
 *   payment sheet closed successfully. If the user closed the app or lost
 *   connectivity in that small window, the boost / subscription was never
 *   activated even though Airwallex had captured the money. This controller
 *   makes the activation idempotent and webhook-driven, so it always happens.
 */

const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const UserSubscription = require('../models/UserSubscription');
const logger = require('../utils/logger');

const _roleModel = (role) => {
  const r = (role || '').toLowerCase();
  if (r === 'walker') return Walker;
  if (r === 'sitter') return Sitter;
  return Owner;
};

const _roleModelName = (role) => {
  const r = (role || '').toLowerCase();
  if (r === 'walker') return 'Walker';
  if (r === 'sitter') return 'Sitter';
  return 'Owner';
};

/**
 * Activate a map_boost purchase from a webhook payment_intent.succeeded.
 * Idempotent — if a boostPurchase entry with the same paymentId already
 * exists, the call is a no-op.
 *
 * @param {object} opts
 * @param {string} opts.piId — Airwallex PaymentIntent id
 * @param {object} opts.metadata — PI metadata (userId, role, tier, days, currency, ...)
 */
async function activateMapBoostFromWebhook({ piId, metadata }) {
  const userId = metadata?.userId;
  const role = metadata?.role;
  const tier = metadata?.tier;
  const days = Number(metadata?.days || 0);
  const currency = (metadata?.currency || 'EUR').toUpperCase();

  if (!userId || !role || !tier || !days) {
    throw new Error(
      `Invalid map_boost metadata (userId=${userId}, role=${role}, tier=${tier}, days=${days})`,
    );
  }

  const Model = _roleModel(role);
  const user = await Model.findById(userId);
  if (!user) throw new Error(`User not found ${role}:${userId}`);

  // Idempotency : if we already activated this exact PI, skip.
  const alreadyActivated = (user.boostPurchases || []).some(
    (p) => p.paymentId === piId && p.kind === 'map',
  );
  if (alreadyActivated) {
    logger.info(`[purchaseActivation] map_boost already activated for PI ${piId} — skipping`);
    return { alreadyActivated: true };
  }

  const now = new Date();
  const currentExpiry =
    user.mapBoostExpiry && new Date(user.mapBoostExpiry) > now
      ? new Date(user.mapBoostExpiry)
      : now;
  const newExpiry = new Date(currentExpiry.getTime() + days * 86_400_000);

  user.mapBoostExpiry = newExpiry;
  user.mapBoostTier = tier;
  user.boostPurchases = user.boostPurchases || [];
  user.boostPurchases.push({
    tier,
    amount: 0, // amount is on the Airwallex side; we keep the entry minimal
    currency,
    days,
    purchasedAt: now,
    paymentProvider: 'airwallex',
    paymentId: piId,
    kind: 'map',
  });
  await user.save();

  logger.info(
    `[purchaseActivation] map_boost activated ${role} ${userId} tier=${tier} days=${days} → ${newExpiry.toISOString()}`,
  );

  // Best-effort notification.
  try {
    const { sendNotification } = require('../services/notificationSender');
    await sendNotification({
      userId,
      role,
      type: 'map_boost_activated',
      data: {
        tier,
        days: String(days),
        expiresAt: newExpiry.toISOString(),
      },
      actor: { role: 'system', id: null },
    });
  } catch (_) {
    /* notif non-critical */
  }

  return { activated: true, tier, days, expiresAt: newExpiry };
}

/**
 * Activate a PawFollow / premium subscription purchase from a webhook.
 * Idempotent on the metadata.paymentId field of UserSubscription.history.
 */
async function activateSubscriptionFromWebhook({ piId, metadata }) {
  const userId = metadata?.userId;
  const role = metadata?.role;
  const plan = metadata?.plan;
  const intervalDays = Number(metadata?.intervalDays || 30);
  const currency = (metadata?.currency || 'EUR').toUpperCase();

  if (!userId || !role || !plan) {
    throw new Error(
      `Invalid subscription metadata (userId=${userId}, role=${role}, plan=${plan})`,
    );
  }

  const userModelName = _roleModelName(role);

  let sub = await UserSubscription.findOne({
    userId,
    userModel: userModelName,
  });
  if (!sub) {
    sub = new UserSubscription({
      userId,
      userModel: userModelName,
      plan,
      status: 'active',
      activatedAt: new Date(),
      currency,
    });
  }

  // Idempotency : skip if we already recorded this exact PI.
  const history = sub.history || [];
  if (history.some((h) => h.paymentId === piId)) {
    logger.info(`[purchaseActivation] subscription already activated for PI ${piId} — skipping`);
    return { alreadyActivated: true };
  }

  const now = new Date();
  const currentExpiry =
    sub.expiresAt && new Date(sub.expiresAt) > now ? new Date(sub.expiresAt) : now;
  const newExpiry = new Date(currentExpiry.getTime() + intervalDays * 86_400_000);

  sub.plan = plan;
  sub.status = 'active';
  sub.expiresAt = newExpiry;
  sub.currency = currency;

  // Map-boost credit allowance per plan :
  //   yearly  → 12 credits (one per month for the year)
  //   monthly → 1 credit
  //   family  → 1 credit (family is also monthly-billed)
  const creditsToAdd = plan === 'yearly' ? 12 : 1;
  sub.mapBoostCreditsRemaining = (sub.mapBoostCreditsRemaining || 0) + creditsToAdd;

  sub.history = history;
  sub.history.push({
    plan,
    paymentProvider: 'airwallex',
    paymentId: piId,
    activatedAt: now,
    expiresAt: newExpiry,
    intervalDays,
    currency,
  });

  await sub.save();

  logger.info(
    `[purchaseActivation] subscription activated ${role} ${userId} plan=${plan} → ${newExpiry.toISOString()}`,
  );

  // Best-effort notification.
  try {
    const { sendNotification } = require('../services/notificationSender');
    await sendNotification({
      userId,
      role,
      type: 'subscription_activated',
      data: {
        plan,
        intervalDays: String(intervalDays),
        expiresAt: newExpiry.toISOString(),
      },
      actor: { role: 'system', id: null },
    });
  } catch (_) {
    /* notif non-critical */
  }

  return { activated: true, plan, expiresAt: newExpiry };
}

module.exports = {
  activateMapBoostFromWebhook,
  activateSubscriptionFromWebhook,
};
