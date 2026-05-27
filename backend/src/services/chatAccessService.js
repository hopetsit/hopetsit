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
 *
 * v23.1 part 237 — Daniel : "gros bug message chat marche pas".
 * ROOT CAUSE : ce service avait son propre check different du middleware
 * chatAccess.js (v228 bypass aggressif). Resultat : meme avec un
 * PawFollow actif + email staff hardcode + bypass middleware OK, le
 * SERVICE rejetait avec 402 CHAT_ACCESS_REQUIRED quand sendMessage
 * etait appele. Maintenant on aligne les memes 5 niveaux de bypass.
 */
async function getChatAccess(userId, userModelOrRole) {
  const userModel =
    ROLE_TO_MODEL[userModelOrRole] ||
    (['Owner', 'Sitter', 'Walker'].includes(userModelOrRole)
      ? userModelOrRole
      : 'Owner');

  const now = new Date();

  // v23.1 part 237 — email whitelist hardcoded staff + STAFF_EMAILS env.
  // Lookup user once for email + isStaff check.
  const Model = MODEL_CTOR[userModel];
  const me = Model ? await Model.findById(userId).select('isStaff email').lean() : null;
  const staff = !!(me && me.isStaff);
  const HARDCODED_STAFF_EMAILS = new Set(['dadaciao84@gmail.com']);
  const envStaffEmails = String(process.env.STAFF_EMAILS || '')
    .split(',').map((s) => s.trim().toLowerCase()).filter(Boolean);
  const emailLower = String(me?.email || '').toLowerCase();
  const isStaffByEmail = !!emailLower && (
    HARDCODED_STAFF_EMAILS.has(emailLower) ||
    envStaffEmails.includes(emailLower)
  );

  // v23.1 part 237 — hasActivePawFollow check (userId-only, no userModel
  // filter) + ANY active UserSubscription fallback (for legacy docs
  // without userModel field).
  let iHavePawFollow = false;
  let anyActiveSub = false;
  try {
    const { hasActivePawFollow } = require('../models/UserSubscription');
    iHavePawFollow = await hasActivePawFollow(userId);
  } catch (_) {/* defensive */}
  try {
    const found = await UserSubscription.findOne({
      userId,
      status: 'active',
      currentPeriodEnd: { $gt: now },
    }).select('status').lean();
    anyActiveSub = !!found;
  } catch (_) {/* defensive */}

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

  // v23.1 part 237 — bypass chain aligned with chatAccess.js middleware :
  //   - isStaff DB flag
  //   - email whitelist (HARDCODED + env)
  //   - hasActivePawFollow (no userModel filter)
  //   - ANY active UserSubscription
  //   - legacy hasPremium (userModel-filtered) | hasChatAddon
  const anyBypass = staff || isStaffByEmail || iHavePawFollow || anyActiveSub;

  return {
    hasPremium: hasPremium || anyBypass,
    hasChatAddon: hasChatAddon || anyBypass,
    hasAny: hasPremium || hasChatAddon || anyBypass,
    isStaff: staff || isStaffByEmail,
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
