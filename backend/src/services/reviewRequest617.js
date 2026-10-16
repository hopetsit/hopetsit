/**
 * 617 (ADA, 16/10/2026) — DEMANDE D'AVIS à la fin d'une réservation (§B.3 du
 * PROCHAIN_BUILD_617, accord de Daniel du 16/10 : « avis dès la première garde »).
 *
 * Appelé quand une réservation passe en `completed` (bookingController.completeBooking,
 * seul endroit du serveur où `Booking.status` devient 'completed' — vérifié par grep
 * le 16/10). Envoie au PROPRIÉTAIRE une notification `review_request_617`
 * (push + cloche, JAMAIS d'e-mail) avec
 *   data = { bookingId, revieweeRole: 'sitter'|'walker', revieweeId, providerName }.
 * L'app (build 617) ouvre la réservation sur ce type ; en attendant, la route
 * serveur (`emailLinkBuilder`) tombe sur /bookings/<id> grâce au bookingId.
 *
 * RÈGLES (tests/reviewRequest617.test.js) :
 *   · une seule fois par (bookingId, ownerId) — registre ReviewRequest617, place
 *     prise AVANT l'envoi ;
 *   · rien si un avis du propriétaire existe déjà sur cette réservation ;
 *   · rien pour un compte +test, sauf si les deux côtés sont des comptes de test ;
 *     rien pour la sonde @invalid.example ni pour un prestataire inconnu.
 */
const logger = require('../utils/logger');
const { decrypt } = require('../utils/encryption');
const { TEST_EMAIL_RE } = require('../utils/testAccount2809');
const { deriveNameParts } = require('../utils/personName');

const TYPE = 'review_request_617';
const NOT_A_PERSON_RE = /@invalid\.example$/i;

const plainEmail = (stored) => {
  let e = stored;
  try { e = decrypt(stored); } catch (_) { /* illisible */ }
  return typeof e === 'string' ? e.trim().toLowerCase() : '';
};
const firstNameOf = (doc) => {
  const { firstName } = deriveNameParts(doc || {});
  return firstName || String((doc && doc.name) || '').trim().split(/\s+/)[0] || '';
};

/**
 * Décision pure : faut-il demander un avis ?
 * @returns {{ok:boolean, why:string}}
 */
const decideReviewRequest = ({ booking, ownerEmail, providerEmail, reviewExists, alreadyAsked }) => {
  if (!booking || String(booking.status) !== 'completed') return { ok: false, why: 'not_completed' };
  if (!booking.sitterId && !booking.walkerId) return { ok: false, why: 'no_provider' };
  if (alreadyAsked) return { ok: false, why: 'already' };
  if (reviewExists) return { ok: false, why: 'reviewed' };
  const oe = String(ownerEmail || '').toLowerCase();
  const pe = String(providerEmail || '').toLowerCase();
  if (NOT_A_PERSON_RE.test(oe) || NOT_A_PERSON_RE.test(pe)) return { ok: false, why: 'test' };
  const ownerTest = TEST_EMAIL_RE.test(oe);
  const providerTest = TEST_EMAIL_RE.test(pe);
  if (ownerTest !== providerTest) return { ok: false, why: 'test' };
  return { ok: true, why: 'due' };
};

/**
 * Demande d'avis pour UNE réservation terminée. Ne lève jamais.
 * @param {Object} booking document Booking (status 'completed')
 * @param {{send?:Function}} [opts]
 * @returns {Promise<{sent:boolean, why:string}>}
 */
const requestReviewForBooking = async (booking, opts = {}) => {
  const send = typeof opts.send === 'function' ? opts.send : require('./notificationSender').sendNotification;
  const Owner = require('../models/Owner');
  const Review = require('../models/Review');
  const Registry = require('../models/ReviewRequest617');
  try {
    if (!booking || !booking._id) return { sent: false, why: 'no_booking' };
    const revieweeRole = booking.walkerId ? 'walker' : 'sitter';
    const revieweeId = booking.walkerId || booking.sitterId;
    if (!revieweeId) return { sent: false, why: 'no_provider' };
    const Provider = revieweeRole === 'walker' ? require('../models/Walker') : require('../models/Sitter');
    const [owner, provider, reviewExists, alreadyAsked] = await Promise.all([
      Owner.findById(booking.ownerId).select('email name firstName status').lean(),
      Provider.findById(revieweeId).select('email name firstName').lean(),
      Review.exists({ bookingId: booking._id, reviewerId: booking.ownerId }),
      Registry.exists({ bookingId: booking._id, ownerId: booking.ownerId }),
    ]);
    if (!owner) return { sent: false, why: 'no_owner' };
    if (!provider) return { sent: false, why: 'no_provider' };
    const d = decideReviewRequest({
      booking, ownerEmail: plainEmail(owner.email), providerEmail: plainEmail(provider.email), reviewExists: !!reviewExists, alreadyAsked: !!alreadyAsked,
    });
    if (!d.ok) return { sent: false, why: d.why };
    let claim;
    try {
      claim = await Registry.create({ bookingId: booking._id, ownerId: booking.ownerId, revieweeRole, revieweeId });
    } catch (e) {
      if (e && e.code === 11000) return { sent: false, why: 'already' };
      throw e;
    }
    const data = {
      bookingId: String(booking._id),
      revieweeRole,
      revieweeId: String(revieweeId),
      providerName: firstNameOf(provider),
    };
    try {
      await send({ userId: String(booking.ownerId), role: 'owner', type: TYPE, data, channels: { email: false } });
      logger.info(`[avis617] demande d'avis envoyée : réservation ${booking._id} (${revieweeRole})`);
      return { sent: true, why: 'sent' };
    } catch (e) {
      await Registry.updateOne({ _id: claim._id }, { $set: { status: 'failed', error: String(e && e.message ? e.message : e).slice(0, 300) } });
      logger.warn(`[avis617] envoi échoué ${booking._id} : ${e && e.message ? e.message : e}`);
      return { sent: false, why: 'send_failed' };
    }
  } catch (e) {
    logger.warn(`[avis617] réservation ${booking && booking._id} : ${e && e.message ? e.message : e}`);
    return { sent: false, why: 'error' };
  }
};

module.exports = { requestReviewForBooking, decideReviewRequest, TYPE };
