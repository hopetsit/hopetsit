const UserSubscription = require('../models/UserSubscription');
const UserChatAddon = require('../models/UserChatAddon');
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');

/**
 * chatAccessService — session v3.2.
 *
 * Answers the single question: does this user have a paid chat tier right
 * now? Either via Premium (the full plan) or via the cheap Chat add-on.
 *
 * When BOTH are absent and the caller has no alternate justification (e.g.
 * a paid booking with the other party), the caller should respond with HTTP
 * 402 and the `CHAT_ACCESS_REQUIRED` code so the client can upsell cleanly.
 */

const ROLE_TO_MODEL = { owner: 'Owner', sitter: 'Sitter', walker: 'Walker' };
const MODEL_CTOR = { Owner, Sitter, Walker };

async function isStaffUser(userId, userModel) {
  const Model = MODEL_CTOR[userModel];
  if (!Model) return false;
  const doc = await Model.findById(userId).select('isStaff').lean();
  return !!(doc && doc.isStaff);
}

/**
 * Returns a compact descriptor of the user's chat access:
 *   { hasPremium, hasChatAddon, hasAny }
 */
async function getChatAccess(userId, userModelOrRole) {
  const userModel =
    ROLE_TO_MODEL[userModelOrRole] ||
    (['Owner', 'Sitter', 'Walker'].includes(userModelOrRole)
      ? userModelOrRole
      : 'Owner');

  const now = new Date();

  const [sub, addon] = await Promise.all([
    UserSubscription.findOne({ userId, userModel })
      .select('status currentPeriodEnd')
      .lean(),
    UserChatAddon.findOne({ userId, userModel })
      .select('status currentPeriodEnd')
      .lean(),
  ]);

  const hasPremium =
    !!sub &&
    sub.status === 'active' &&
    sub.currentPeriodEnd &&
    new Date(sub.currentPeriodEnd) > now;

  const hasChatAddon =
    !!addon &&
    addon.status === 'active' &&
    addon.currentPeriodEnd &&
    new Date(addon.currentPeriodEnd) > now;

  // v19.1.5 — Staff users (Daniel + employees) bypass all paywalls.
  const staff = await isStaffUser(userId, userModel);

  return {
    hasPremium: hasPremium || staff,
    hasChatAddon: hasChatAddon || staff,
    hasAny: hasPremium || hasChatAddon || staff,
    isStaff: staff,
  };
}

/**
 * Convenience boolean — true when the user can chat beyond the basic
 * paid-booking support chat (i.e. friend chat / pre-booking chat).
 */
async function canChatFreely(userId, userModelOrRole) {
  const access = await getChatAccess(userId, userModelOrRole);
  return access.hasAny;
}

module.exports = {
  getChatAccess,
  canChatFreely,
  ROLE_TO_MODEL,
};
