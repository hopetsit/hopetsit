const UserSubscription = require('../models/UserSubscription');
const UserChatAddon = require('../models/UserChatAddon');

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

  return {
    hasPremium,
    hasChatAddon,
    hasAny: hasPremium || hasChatAddon,
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
