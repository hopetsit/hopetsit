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

// v550 — Daniel (04/09/2026) : « le chat exige Premium hors réservation :
// pour une app à 40 utilisateurs c'est un mur → gratuit jusqu'à 1 000
// utilisateurs ». PHASE DE LANCEMENT : tant que la base compte moins de
// CHAT_FREE_UNTIL_USERS comptes (défaut 1000, surchargeable sur Render),
// tout le monde peut chatter librement. Le compte est mis en cache 10 min.
// Passé le seuil, le gating Premium/add-on historique se réapplique tout seul.
const CHAT_FREE_UNTIL_USERS = Number(process.env.CHAT_FREE_UNTIL_USERS || 1000);
let _launchCache = { at: 0, free: true };
async function isLaunchPhase() {
  if (!(CHAT_FREE_UNTIL_USERS > 0)) return false;
  const now = Date.now();
  if (now - _launchCache.at < 10 * 60 * 1000) return _launchCache.free;
  try {
    const [o, s, w] = await Promise.all([
      Owner.estimatedDocumentCount(),
      Sitter.estimatedDocumentCount(),
      Walker.estimatedDocumentCount(),
    ]);
    _launchCache = { at: now, free: (o + s + w) < CHAT_FREE_UNTIL_USERS };
  } catch (_) {
    _launchCache = { at: now, free: _launchCache.free };
  }
  return _launchCache.free;
}

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
    // v450 — Daniel : PawSpot (pawspotExpiry) doit aussi débloquer le chat.
    // L'ancien check ne regardait que currentPeriodEnd → un abo PawSpot SEUL
    // ratait. On détecte par DATE sur les 4 timers (PawFollow / PawFamily /
    // PawSpot / Premium) via le helper partagé.
    const { hasAnyActiveSubscription } = require('../models/UserSubscription');
    anyActiveSub = await hasAnyActiveSubscription(userId);
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
  //   - v550 : phase de lancement (< CHAT_FREE_UNTIL_USERS comptes) → libre
  const launch = await isLaunchPhase();
  const anyBypass = staff || isStaffByEmail || iHavePawFollow || anyActiveSub || launch;

  return {
    hasPremium: hasPremium || anyBypass,
    hasChatAddon: hasChatAddon || anyBypass,
    hasAny: hasPremium || hasChatAddon || anyBypass,
    isStaff: staff || isStaffByEmail,
    launchPhase: launch,
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

// ─── v565 §4 — verrou du partage de contacts (téléphone / adresse) ─────────
// Daniel (14/09) : gratuit jusqu'à CONTACTS_FREE_UNTIL_USERS comptes (700 par
// défaut), puis l'échange de téléphone/adresse se verrouille côté serveur
// (sans rebuild) et ne se débloque qu'après une réservation PAYÉE entre les
// deux personnes ou un abonnement actif de l'expéditeur (ou staff).
// Indépendant de la phase de lancement du chat (CHAT_FREE_UNTIL_USERS).
const CONTACTS_FREE_UNTIL_USERS = Number(process.env.CONTACTS_FREE_UNTIL_USERS || 700);
let _contactsCache = { at: 0, locked: false };
async function isContactsLockedGlobally() {
  if (!(CONTACTS_FREE_UNTIL_USERS > 0)) return false;
  const now = Date.now();
  if (now - _contactsCache.at < 10 * 60 * 1000) return _contactsCache.locked;
  try {
    const [o, s, w] = await Promise.all([
      Owner.estimatedDocumentCount(),
      Sitter.estimatedDocumentCount(),
      Walker.estimatedDocumentCount(),
    ]);
    _contactsCache = { at: now, locked: (o + s + w) >= CONTACTS_FREE_UNTIL_USERS };
  } catch (_) {
    _contactsCache = { at: now, locked: _contactsCache.locked };
  }
  return _contactsCache.locked;
}

const HARDCODED_STAFF_EMAILS = new Set(['dadaciao84@gmail.com']);
function _staffEmailSet() {
  const set = new Set(HARDCODED_STAFF_EMAILS);
  String(process.env.STAFF_EMAILS || '')
    .split(',').map((s) => s.trim().toLowerCase()).filter(Boolean)
    .forEach((e) => set.add(e));
  return set;
}

/**
 * Débloquage « global » de l'expéditeur (indépendant du correspondant) :
 * staff (drapeau ou e-mail) OU abonnement actif (PawPremium / PawFollow /
 * Famille / PawSpot, par date) OU add-on chat actif — cherché sur les 3 docs
 * de la personne (identityGroup).
 */
async function hasContactsUnlock(userId) {
  const { identityGroup } = require('../utils/identityGroup');
  const g = await identityGroup(userId);
  const now = new Date();
  const staffEmails = _staffEmailSet();
  try {
    const docs = (await Promise.all([Owner, Sitter, Walker].map((M) =>
      M.find({ _id: { $in: g.ids } }).select('isStaff email').lean(),
    ))).flat();
    if (docs.some((d) => d.isStaff === true || (d.email && staffEmails.has(String(d.email).toLowerCase())))) {
      return { unlocked: true, reason: 'staff' };
    }
  } catch (_) { /* on continue avec les abonnements */ }
  try {
    const { hasAnyActiveSubscription } = require('../models/UserSubscription');
    for (const id of g.ids) {
      // eslint-disable-next-line no-await-in-loop
      if (await hasAnyActiveSubscription(id)) return { unlocked: true, reason: 'subscription' };
    }
  } catch (_) { /* défensif */ }
  try {
    const addon = await UserChatAddon.findOne({
      userId: { $in: g.ids }, status: 'active', currentPeriodEnd: { $gt: now },
    }).select('_id').lean();
    if (addon) return { unlocked: true, reason: 'chat_addon' };
    const legacy = await UserSubscription.findOne({
      userId: { $in: g.ids }, chatAddonActive: true, chatAddonExpiresAt: { $gt: now },
    }).select('_id').lean();
    if (legacy) return { unlocked: true, reason: 'chat_addon' };
  } catch (_) { /* défensif */ }
  return { unlocked: false, reason: null };
}

/** Réservation PAYÉE entre deux personnes, quel que soit le rôle de chacune. */
async function hasPaidBookingBetween(userIdA, userIdB) {
  if (!userIdA || !userIdB) return false;
  const { identityGroup } = require('../utils/identityGroup');
  const Booking = require('../models/Booking');
  const [ga, gb] = await Promise.all([identityGroup(userIdA), identityGroup(userIdB)]);
  const A = ga.ids;
  const B = gb.ids;
  const paid = await Booking.exists({
    $and: [
      { $or: [{ paymentStatus: 'paid' }, { status: 'paid' }, { status: 'completed', paymentStatus: 'paid' }] },
      {
        $or: [
          { ownerId: { $in: A }, $or: [{ sitterId: { $in: B } }, { walkerId: { $in: B } }] },
          { ownerId: { $in: B }, $or: [{ sitterId: { $in: A } }, { walkerId: { $in: A } }] },
        ],
      },
    ],
  });
  return !!paid;
}

/**
 * Décision complète pour share-phone / share-address.
 * @returns {{ locked: boolean, reason: string|null, threshold: number }}
 *   reason ∈ 'below_threshold' | 'staff' | 'subscription' | 'chat_addon' | 'paid_booking' | 'locked'
 */
async function evaluateContactsAccess({ userId, otherUserId }) {
  const threshold = CONTACTS_FREE_UNTIL_USERS;
  if (!(await isContactsLockedGlobally())) return { locked: false, reason: 'below_threshold', threshold };
  const unlock = await hasContactsUnlock(userId);
  if (unlock.unlocked) return { locked: false, reason: unlock.reason, threshold };
  if (otherUserId && (await hasPaidBookingBetween(userId, otherUserId))) {
    return { locked: false, reason: 'paid_booking', threshold };
  }
  return { locked: true, reason: 'locked', threshold };
}

module.exports = {
  getChatAccess,
  canChatFreely,
  isLaunchPhase,
  ROLE_TO_MODEL,
  // v565 §4
  CONTACTS_FREE_UNTIL_USERS,
  isContactsLockedGlobally,
  hasContactsUnlock,
  hasPaidBookingBetween,
  evaluateContactsAccess,
};
