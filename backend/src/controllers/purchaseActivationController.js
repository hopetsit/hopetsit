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
  const planCanonical = plan === 'family' ? 'famille' : plan;
  // v23.1.387 — family_yearly = même timer famille, intervalle 365 j.
  const { isFamilyPlan, isPremiumPlan } = require('../models/UserSubscription');
  const isFamilyPurchase = isFamilyPlan(planCanonical);
  const isPremiumPurchase = isPremiumPlan(planCanonical);

  // v23.1.283 — Daniel : "prendre PawFollow ou PawFamily désactive l'autre" +
  // "1 mois = 300 j au lieu de 30". RACINE : l'abo individuel et le plan Famille
  // partageaient UN SEUL plan + currentPeriodEnd → écrasement mutuel + empilage
  // des jours. On DÉCOUPLE : familyExpiry pour la famille, currentPeriodEnd pour
  // l'individuel. migrateLegacyFamily déplace d'abord toute ancienne sub famille
  // (plan='famille' + currentPeriodEnd) vers familyExpiry pour ne rien perdre.
  const { migrateLegacyFamily } = require('../models/UserSubscription');
  migrateLegacyFamily(sub, now);

  // Base d'extension d'un timer : on repart de sa valeur future ou de
  // maintenant (jamais d'empilage rétroactif).
  const extendFrom = (d) =>
    new Date((d && new Date(d) > now ? new Date(d) : now).getTime() + intervalDays * 86_400_000);

  let newExpiry;
  if (isFamilyPurchase) {
    // Timer FAMILLE indépendant : on étend familyExpiry (sans toucher l'abo
    // individuel). plan/currentPeriodEnd restent ceux de l'individuel.
    newExpiry = extendFrom(sub.familyExpiry);
    sub.familyExpiry = newExpiry;
    sub.status = 'active';
  } else if (isPremiumPurchase) {
    // v23.1.387 — Paw Premium = bundle : on étend les TROIS timers d'un coup.
    //   currentPeriodEnd → PawFollow individuel (tracking)
    //   pawspotExpiry    → PawSpot communautaire
    //   premiumExpiry    → extras Premium (badge, points ×2, priorité)
    newExpiry = extendFrom(sub.currentPeriodEnd);
    sub.plan = planCanonical;
    sub.status = 'active';
    sub.currentPeriodStart = sub.currentPeriodStart || now;
    sub.currentPeriodEnd = newExpiry;
    sub.expiresAt = newExpiry; // legacy alias
    sub.pawspotExpiry = extendFrom(sub.pawspotExpiry);
    sub.premiumExpiry = extendFrom(sub.premiumExpiry);
  } else {
    // Abo INDIVIDUEL (monthly/yearly/solo) : on étend currentPeriodEnd (sans
    // toucher la famille). Un mois sur un slot vide = exactement 30 j.
    newExpiry = extendFrom(sub.currentPeriodEnd);
    sub.plan = planCanonical;
    sub.status = 'active';
    sub.currentPeriodStart = sub.currentPeriodStart || now;
    sub.currentPeriodEnd = newExpiry;
    sub.expiresAt = newExpiry; // legacy alias
  }
  sub.currency = currency;

  // Map-boost credit allowance per plan :
  //   yearly / family_yearly / premium_yearly → 12 credits (1 par mois)
  //   monthly / family / premium_monthly      → 1 credit
  const creditsToAdd = intervalDays >= 365 ? 12 : 1;
  sub.mapBoostCreditsRemaining = (sub.mapBoostCreditsRemaining || 0) + creditsToAdd;

  sub.history = history;
  sub.history.push({
    plan: planCanonical,
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

  // v23.1.388 — un compte = 3 profils : les timers suivent les comptes
  // frères (même email). Best-effort, jamais bloquant.
  try {
    const { syncSubscriptionAcrossRoles } = require('../models/UserSubscription');
    await syncSubscriptionAcrossRoles(userId, userModelName);
  } catch (_) { /* */ }

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

/**
 * v23.1 part 67 — Profile Boost activation from webhook.
 * Daniel : "Jai aussi payer le forfait boost ne fonctionne pas" — the
 * boost route created a PI tagged metadata.type='boost_purchase' but
 * the webhook had no handler for it (only map_boost was wired). Money
 * was captured, nothing got activated. This function is the missing
 * piece. Idempotent on (boostPurchases.paymentId).
 *
 * Mirrors the in-route /confirm logic but is webhook-driven so it always
 * runs even if the client app crashes between pay and /confirm.
 */
async function activateBoostFromWebhook({ piId, metadata }) {
  const userId = metadata?.userId;
  const role = metadata?.role;
  const tier = metadata?.tier;
  const days = Number(metadata?.days || 0);
  const currency = (metadata?.currency || 'EUR').toUpperCase();

  if (!userId || !role || !tier || !days) {
    throw new Error(
      `Invalid boost metadata (userId=${userId}, role=${role}, tier=${tier}, days=${days})`,
    );
  }

  const Model = _roleModel(role);
  const user = await Model.findById(userId);
  if (!user) throw new Error(`User not found ${role}:${userId}`);

  // Idempotency : skip if we already activated this exact PI for profile boost.
  const alreadyActivated = (user.boostPurchases || []).some(
    (p) => p.paymentId === piId && (!p.kind || p.kind === 'profile'),
  );
  if (alreadyActivated) {
    logger.info(`[purchaseActivation] profile boost already activated for PI ${piId} — skipping`);
    return { alreadyActivated: true };
  }

  const now = new Date();
  const currentExpiry =
    user.boostExpiry && new Date(user.boostExpiry) > now
      ? new Date(user.boostExpiry)
      : now;
  const newExpiry = new Date(currentExpiry.getTime() + days * 86_400_000);

  user.boostExpiry = newExpiry;
  user.boostTier = tier;
  user.boostPurchases = user.boostPurchases || [];
  user.boostPurchases.push({
    tier,
    amount: 0,
    currency,
    days,
    purchasedAt: now,
    paymentProvider: 'airwallex',
    paymentId: piId,
    kind: 'profile',
  });
  await user.save();

  logger.info(
    `[purchaseActivation] profile boost activated ${role} ${userId} tier=${tier} days=${days} → ${newExpiry.toISOString()}`,
  );

  try {
    const { sendNotification } = require('../services/notificationSender');
    await sendNotification({
      userId,
      role,
      type: 'profile_boost_activated',
      data: { tier, days: String(days), expiresAt: newExpiry.toISOString() },
      actor: { role: 'system', id: null },
    });
  } catch (_) { /* non-critical */ }

  return { activated: true, tier, days, expiresAt: newExpiry };
}

/**
 * v23.1 part 67 — Chat add-on activation from webhook.
 * Same rationale as activateBoostFromWebhook : the chatAddon route
 * created a PI tagged 'chat_addon_purchase' but the webhook never
 * activated it. Idempotent on UserChatAddon.history[].paymentId.
 */
async function activateChatAddonFromWebhook({ piId, metadata }) {
  const userId = metadata?.userId;
  const role = metadata?.role;
  const intervalDays = Number(metadata?.intervalDays || 30);
  const currency = (metadata?.currency || 'EUR').toUpperCase();

  if (!userId || !role) {
    throw new Error(`Invalid chat_addon metadata (userId=${userId}, role=${role})`);
  }

  const UserChatAddon = require('../models/UserChatAddon');
  const userModelName = _roleModelName(role);

  let addon = await UserChatAddon.findOne({ userId, userModel: userModelName });
  if (!addon) {
    addon = new UserChatAddon({
      userId,
      userModel: userModelName,
      status: 'active',
      currency,
    });
  }

  const history = addon.history || [];
  if (history.some((h) => h.paymentId === piId)) {
    logger.info(`[purchaseActivation] chat_addon already activated for PI ${piId} — skipping`);
    return { alreadyActivated: true };
  }

  const now = new Date();
  const currentExpiry = addon.expiresAt && new Date(addon.expiresAt) > now
    ? new Date(addon.expiresAt) : now;
  const newExpiry = new Date(currentExpiry.getTime() + intervalDays * 86_400_000);

  addon.status = 'active';
  addon.expiresAt = newExpiry;
  addon.currency = currency;
  addon.history = history;
  addon.history.push({
    paymentProvider: 'airwallex',
    paymentId: piId,
    activatedAt: now,
    expiresAt: newExpiry,
    intervalDays,
    currency,
  });
  await addon.save();

  logger.info(
    `[purchaseActivation] chat_addon activated ${role} ${userId} → ${newExpiry.toISOString()}`,
  );

  try {
    const { sendNotification } = require('../services/notificationSender');
    await sendNotification({
      userId,
      role,
      type: 'chat_addon_activated',
      data: { intervalDays: String(intervalDays), expiresAt: newExpiry.toISOString() },
      actor: { role: 'system', id: null },
    });
  } catch (_) { /* non-critical */ }

  return { activated: true, intervalDays, expiresAt: newExpiry };
}

/**
 * v23.1.353 — refonte PawSpot (Daniel) : active/étend l'abonnement PawSpot
 * communautaire (4,99 €/mois · 39,99 €/an). Idempotent par paymentId via
 * UserSubscription.history (kind 'pawspot').
 */
async function activatePawSpotFromWebhook({ piId, metadata }) {
  const UserSubscription = require('../models/UserSubscription');
  const userId = metadata?.userId;
  const role = String(metadata?.role || 'owner').toLowerCase();
  const days = Number(metadata?.days || 0) || (metadata?.plan === 'yearly' ? 365 : 30);
  if (!userId || !days) {
    throw new Error(`Invalid pawspot metadata (userId=${userId}, days=${days})`);
  }
  const userModel = role === 'walker' ? 'Walker' : role === 'sitter' ? 'Sitter' : 'Owner';
  let sub = await UserSubscription.findOne({ userId, userModel });
  if (!sub) sub = new UserSubscription({ userId, userModel });
  sub.pawspotHistory = sub.pawspotHistory || [];
  if (piId && sub.pawspotHistory.some((h) => h.paymentId === piId)) {
    return { pawspotExpiry: sub.pawspotExpiry, deduplicated: true };
  }
  const now = new Date();
  const base = sub.pawspotExpiry && new Date(sub.pawspotExpiry) > now
    ? new Date(sub.pawspotExpiry) : now;
  sub.pawspotExpiry = new Date(base.getTime() + days * 86400000);
  sub.pawspotHistory.push({ paymentId: piId || '', at: now, days });
  await sub.save();
  return { pawspotExpiry: sub.pawspotExpiry };
}

module.exports = {
  activateMapBoostFromWebhook,
  activateSubscriptionFromWebhook,
  activateBoostFromWebhook,
  activateChatAddonFromWebhook,
  activatePawSpotFromWebhook,
};
