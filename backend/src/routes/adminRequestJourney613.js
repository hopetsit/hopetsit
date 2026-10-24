/**
 * 04/10/2026 (ADA, v613, demande de Daniel) — « dans l'admin, on peut voir si
 * l'annonce a été contactée ? une case » puis « chaque demande, je sais s'il
 * y a des contacts, si c'est validé ou pas, etc. ».
 *
 * Le PARCOURS d'une demande, en LECTURE SEULE (aucune écriture, aucune action
 * sur l'argent, aucune relance, aucune adresse e-mail renvoyée) :
 *   1 Publiée            Post.createdAt
 *   2 Prévenus N         Notification { data.postId, type new_request_* }
 *   3 Ont ouvert N       idem, readAt non nul
 *   4 Contacts N         ⚠️ LIEN INDIRECT : une conversation n'est PAS rattachée
 *                        à une demande (Conversation = ownerId + sitterId|walkerId,
 *                        Message sans postId). On compte les conversations de ce
 *                        propriétaire où un prestataire a écrit DEPUIS la
 *                        publication. `contacts.linked = false` le signale.
 *   5 Candidatures N     Application.postId
 *   6 Validée / refusée  Application.status accepted|rejected (+ Booking)
 *   7 Payée              Booking (Application.bookingId ou Post.reservedBy.bookingId) :
 *                        paymentStatus/paidAt, pricing.totalPrice, pricing.commission
 *   8 Fin                Booking completed / cancelled / refunded, ou date de la
 *                        prestation dépassée sans validation → expirée
 *
 * 16/10/2026 (ADA, demande de Daniel) : en plus, pour chaque demande
 *   · serviceEnd / walkDurationMinutes / serviceTimeZone (fuseau de la ville de
 *     la demande, d'après ses coordonnées ; null = afficher en UTC) → l'admin
 *     montre « Prestation du … au … » ;
 *   · visibility : en ligne pour les prestataires, ou retirée (réservée,
 *     prestation finie, fermée, masquée) avec la date de suppression prévue
 *     (postCleanupScheduler : 48 h après la fin) ;
 *   · détail : distance (km) de chaque prestataire prévenu et de chaque
 *     candidat par rapport à la demande (ex. « Busan · 11 000 km »).
 *
 *   GET /admin/requests613/summary?ids=a,b,c   (50 au plus) → { items: { id: résumé } }
 *   GET /admin/requests613/live?limit=10       → demandes des VRAIS comptes, en ligne,
 *        plus récentes d'abord + compteurs (ouvertes / avec candidature / validées / payées)
 *   GET /admin/requests613/:postId/journey     → détail : prévenus, candidatures,
 *        contacts, réservation (chaque personne : prénom, rôle, ville, type de compte)
 */
const express = require('express');
const mongoose = require('mongoose');
const { requireAuth, requireRole } = require('../middleware/auth');
const { auditAdmin } = require('../middleware/auditAdmin');
const logger = require('../utils/logger');

const router = express.Router();
const requireAdmin = [requireAuth, requireRole('admin'), auditAdmin];

const NOTIF_TYPES = ['new_request_nearby', 'new_request_for_you'];
const INTERNAL_EMAIL_RE = /(^hopetsit@|^dadaciao84@|@invalid\.example)/i;
const isId = (s) => /^[a-f0-9]{24}$/i.test(String(s || ''));
const oid = (s) => new mongoose.Types.ObjectId(String(s));
const M = () => ({
  Post: require('../models/Post'),
  Owner: require('../models/Owner'),
  Sitter: require('../models/Sitter'),
  Walker: require('../models/Walker'),
  Notification: require('../models/Notification'),
  Application: require('../models/Application'),
  Booking: require('../models/Booking'),
  Conversation: require('../models/Conversation'),
  Message: require('../models/Message'),
});

function plainEmail(stored) {
  let e = stored;
  try { e = require('../utils/encryption').decrypt(stored); } catch (_) { /* en clair */ }
  return String(e || '').toLowerCase().trim();
}
/** 'test' (+test) | 'staff' (isStaff, hopetsit@, dadaciao84@, sonde) | 'real'. */
function kindOf(doc) {
  if (!doc) return 'real';
  const email = plainEmail(doc.email);
  if (/\+test/i.test(email)) return 'test';
  if (doc.isStaff === true || INTERNAL_EMAIL_RE.test(email)) return 'staff';
  return 'real';
}
const firstName = (n) => String(n || '').trim().split(/\s+/)[0] || '';
const cityOf = (d) => (d && ((d.location && d.location.city) || d.city || d.coverageCity)) || '';
const DIST = require('../utils/applicationDistance1610');
const CUR = require('../utils/applicationCurrency1610');
/** Tarif affiché du prestataire : { amount, unit: 'day'|'hour'|'week'|'month'|'walk', minutes? }. */
function rateOf(d) {
  if (!d) return null;
  if (d.dailyRate > 0) return { amount: d.dailyRate, unit: 'day' };
  if (d.hourlyRate > 0) return { amount: d.hourlyRate, unit: 'hour' };
  if (d.weeklyRate > 0) return { amount: d.weeklyRate, unit: 'week' };
  if (d.monthlyRate > 0) return { amount: d.monthlyRate, unit: 'month' };
  const w = (Array.isArray(d.walkRates) ? d.walkRates : []).find((r) => r && r.enabled !== false && r.basePrice > 0);
  return w ? { amount: w.basePrice, unit: 'walk', minutes: w.durationMinutes || null } : null;
}
const PURGE_GRACE_MS = 48 * 60 * 60 * 1000; // postCleanupScheduler.GRACE_MS
let timeZoneFor = () => null;
try { ({ timeZoneFor } = require('../services/plushService607')); } catch (_) { /* sans fuseau */ }

/** Charge prénom / ville / type de compte → Map "role:id". */
async function people(byRole) {
  const out = new Map();
  const models = M();
  const MOD = { owner: models.Owner, sitter: models.Sitter, walker: models.Walker };
  await Promise.all(Object.entries(byRole).map(async ([role, ids]) => {
    const list = [...new Set(ids.filter(isId).map(String))];
    if (!list.length || !MOD[role]) return;
    const docs = await MOD[role].find({ _id: { $in: list } })
      .select('name email isStaff city coverageCity location.city location.coordinates currency country countryCode hourlyRate dailyRate weeklyRate monthlyRate walkRates visitRate visitDurationMinutes').lean();
    for (const d of docs) {
      out.set(`${role}:${d._id}`, { name: firstName(d.name), city: cityOf(d), country: String(d.country || '').toUpperCase(), kind: kindOf(d), coords: DIST.profileCoords(d), currency: CUR.resolveCurrency(d).currency, currencyStored: CUR.currencyOf(d), currencyInferred: CUR.resolveCurrency(d).inferred, rate: rateOf(d) });
    }
  }));
  return out;
}

const serviceDateOf = (p) => p.startDate || null;
const serviceEndOf = (p) => p.endDate || p.startDate || null;

function bookingStage(b) {
  if (!b) return { payment: { state: 'none' }, end: null };
  const refunded = b.status === 'refunded' || ['refunded', 'refund'].includes(b.paymentStatus);
  const paid = !refunded && (b.paymentStatus === 'paid' || ['paid', 'completed'].includes(b.status) || !!b.paidAt);
  const pr = b.pricing || {};
  const payment = {
    state: refunded ? 'refunded' : (paid ? 'paid' : 'unpaid'),
    amount: typeof pr.totalPrice === 'number' ? pr.totalPrice : null,
    commission: typeof pr.commission === 'number' ? pr.commission : null,
    currency: pr.currency || 'EUR',
    at: b.paidAt || null,
  };
  let end = null;
  if (b.status === 'completed') end = { state: 'completed', at: b.ownerConfirmedAt || b.serviceEndedAt || b.updatedAt || null };
  else if (b.status === 'cancelled' || refunded) end = { state: 'cancelled', at: b.cancelledAt || b.refundedAt || b.updatedAt || null };
  return { payment, end, bookingStatus: b.status };
}

/**
 * Calcule le parcours de plusieurs demandes en un minimum de requêtes.
 * @returns Map postId → résumé
 */
async function journeys(posts, { now = new Date(), detail = false } = {}) {
  const { Notification, Application, Booking, Conversation, Message } = M();
  const ids = posts.map((p) => String(p._id));
  const out = new Map();
  if (!ids.length) return out;

  const [notifs, apps] = await Promise.all([
    Notification.find({ 'data.postId': { $in: ids }, type: { $in: NOTIF_TYPES } })
      .select('data.postId type recipientRole recipientId createdAt readAt').sort({ createdAt: 1 }).lean(),
    Application.find({ postId: { $in: ids.map(oid) } })
      .select('postId sitterId walkerId status bookingId createdAt updatedAt pricing.totalPrice pricing.currency pricing.indicative pricing.appliedRate pricing.unit pricing.quantity pricing.stale').sort({ createdAt: 1 }).lean(),
  ]);

  const bookingIds = new Set();
  for (const a of apps) if (a.bookingId) bookingIds.add(String(a.bookingId));
  for (const p of posts) if (p.reservedBy && p.reservedBy.bookingId) bookingIds.add(String(p.reservedBy.bookingId));
  const bookings = bookingIds.size
    ? await Booking.find({ _id: { $in: [...bookingIds].map(oid) } })
      .select('status paymentStatus paidAt pricing.totalPrice pricing.commission pricing.currency agreedAt acceptedAt cancelledAt refundedAt ownerConfirmedAt serviceEndedAt updatedAt sitterId walkerId').lean()
    : [];
  const bookingById = new Map(bookings.map((b) => [String(b._id), b]));

  // Contacts (lien indirect) : conversations des propriétaires concernés,
  // dernier message d'un prestataire par conversation.
  const ownerIds = [...new Set(posts.map((p) => String(p.ownerId && (p.ownerId._id || p.ownerId))).filter(isId))];
  const convs = ownerIds.length
    ? await Conversation.find({ ownerId: { $in: ownerIds.map(oid) } }).select('ownerId sitterId walkerId').lean()
    : [];
  let lastProviderMsg = new Map();
  if (convs.length) {
    const agg = await Message.aggregate([
      { $match: { conversationId: { $in: convs.map((c) => c._id) }, senderRole: { $in: ['sitter', 'walker'] } } },
      { $group: { _id: '$conversationId', last: { $max: '$createdAt' }, first: { $min: '$createdAt' } } },
    ]);
    lastProviderMsg = new Map(agg.map((r) => [String(r._id), r]));
  }

  const peopleWanted = { owner: [], sitter: [], walker: [] };
  for (const p of posts) peopleWanted.owner.push(String(p.ownerId && (p.ownerId._id || p.ownerId)));
  for (const a of apps) {
    if (a.sitterId) peopleWanted.sitter.push(String(a.sitterId));
    if (a.walkerId) peopleWanted.walker.push(String(a.walkerId));
  }
  if (detail) {
    for (const n of notifs) if (peopleWanted[n.recipientRole]) peopleWanted[n.recipientRole].push(String(n.recipientId));
    for (const c of convs) {
      if (c.sitterId) peopleWanted.sitter.push(String(c.sitterId));
      if (c.walkerId) peopleWanted.walker.push(String(c.walkerId));
    }
  }
  const who = await people(peopleWanted);
  const person = (role, id) => ({ role, id: String(id), ...(who.get(`${role}:${id}`) || { name: '', city: '', kind: 'real', coords: null }) });
  // Distance (km) d'un profil à la demande, d'après les coordonnées de l'annonce.
  const kmTo = (p, pr) => (pr && pr.coords ? DIST.distanceKm(p, { location: { coordinates: [pr.coords.lng, pr.coords.lat] } }) : null);

  for (const p of posts) {
    const pid = String(p._id);
    const ownerId = String(p.ownerId && (p.ownerId._id || p.ownerId));
    const n = notifs.filter((x) => String(x.data && x.data.postId) === pid);
    const a = apps.filter((x) => String(x.postId) === pid);
    const published = new Date(p.createdAt);

    const contactConvs = convs.filter((c) => {
      if (String(c.ownerId) !== ownerId) return false;
      const m = lastProviderMsg.get(String(c._id));
      return m && new Date(m.last) >= published;
    });

    const accepted = a.filter((x) => x.status === 'accepted');
    const rejected = a.filter((x) => x.status === 'rejected');
    const acc = accepted.length ? accepted[accepted.length - 1] : null;
    const bookingId = (p.reservedBy && p.reservedBy.bookingId && String(p.reservedBy.bookingId))
      || (acc && acc.bookingId && String(acc.bookingId)) || null;
    const booking = bookingId ? bookingById.get(bookingId) || null : null;
    const bs = bookingStage(booking);

    let decision = { state: 'none' };
    if (acc) {
      const role = acc.walkerId ? 'walker' : 'sitter';
      const pr = person(role, acc.walkerId || acc.sitterId);
      decision = { state: 'accepted', at: (booking && (booking.agreedAt || booking.acceptedAt)) || acc.updatedAt || null, by: { name: pr.name, role, kind: pr.kind } };
    } else if (a.length && rejected.length === a.length) {
      decision = { state: 'refused', at: rejected[rejected.length - 1].updatedAt || null };
    }

    const svcEnd = serviceEndOf(p);
    let end = bs.end || { state: 'none' };
    if (end.state === 'none' && decision.state !== 'accepted') {
      if ((svcEnd && new Date(svcEnd) < now) || p.status === 'closed') {
        end = { state: 'expired', at: svcEnd || p.closedAt || null };
      }
    }

    let status;
    if (end.state === 'completed') status = 'completed';
    else if (end.state === 'cancelled') status = 'cancelled';
    else if (bs.payment.state === 'paid') status = 'paid';
    else if (decision.state === 'accepted') status = 'accepted';
    else if (end.state === 'expired') status = 'expired';
    else if (a.length) status = 'applied';
    else status = 'waiting';

    // 04/10 (BOB) — compter des PERSONNES, pas des notifications : après une
    // relance (resend), 13 promeneurs = 23 notifications pour la même demande.
    const notifiedPeople = new Set(n.map((x) => String(x.recipientId)));
    const readPeople = new Set(n.filter((x) => x.readAt).map((x) => String(x.recipientId)));
    const readCount = readPeople.size;
    let color;
    if (a.length) color = 'green';
    else if (!n.length) color = 'red';
    else if (!readCount) color = 'orange';
    else color = 'yellow';

    const ownerP = person('owner', ownerId);
    const center = DIST.postCenter(p);
    const visibility = visibilityOf(p, { svcEnd, decision, bs, now });
    const item = {
      postId: pid,
      owner: { id: ownerId, name: ownerP.name, kind: ownerP.kind },
      city: (p.location && p.location.city) || '',
      country: (p.location && p.location.country ? String(p.location.country).toUpperCase() : '') || ownerP.country || '',
      applicationsAt: a.map((x) => x.createdAt),
      serviceTypes: p.serviceTypes || [],
      serviceDate: serviceDateOf(p),
      serviceEnd: p.endDate || null,
      walkDurationMinutes: typeof p.walkDurationMinutes === 'number' ? p.walkDurationMinutes : null,
      // 620 (ZOE, relevé ADA) — mode de dates, visites/jour, animaux, code postal, budget.
      dateMode: require('../utils/pricingEngine620').effectiveDateMode(p),
      visitsPerDay: [1, 2].includes(Number(p.visitsPerDay)) ? Number(p.visitsPerDay) : null,
      animalTypes: Array.isArray(p.animalTypes) ? p.animalTypes : [],
      animalCount: typeof p.animalCount === 'number' ? p.animalCount : 0,
      postalCode: (p.location && p.location.postalCode) || '',
      price: Number(p.budget) > 0 ? { amount: Number(p.budget), currency: p.budgetCurrency || '' } : null,
      serviceTimeZone: center ? timeZoneFor(center.lat, center.lng) : null,
      hasPosition: !!center,
      applyMaxKm: DIST.maxKm(), // 16/10 (Daniel) : 200 km
      visibility,
      hidden: p.hidden === true,
      status,
      color,
      stages: {
        published: { at: p.createdAt },
        notified: { count: notifiedPeople.size, notifications: n.length },
        opened: { count: readCount },
        contacts: { count: contactConvs.length, linked: false },
        applications: {
          count: a.length,
          pending: a.filter((x) => x.status === 'pending').length,
          accepted: accepted.length,
          rejected: rejected.length,
          who: a.slice(0, 5).map((x) => {
            const role = x.walkerId ? 'walker' : 'sitter';
            const pr = person(role, x.walkerId || x.sitterId);
            // 620 (ZOE, relevé ADA) — tarif, total (null = indicatif, en attente des dates) et statut.
            const pricing = x.pricing || {};
            return {
              name: pr.name, role, kind: pr.kind, km: kmTo(p, pr),
              // 620b (ZOE, 24/10) — `stale` : la demande a changé de service et le prestataire n'a pas de
              // tarif pour le nouveau → « tarif à venir » (pas de tarif à afficher, total null).
              rate: pricing.stale === true ? null : (pricing.indicative === true && Number(pricing.appliedRate) > 0
                ? { amount: Number(pricing.appliedRate), unit: pricing.unit || '' } : (pr.rate || null)),
              total: typeof pricing.totalPrice === 'number' ? pricing.totalPrice : null,
              currency: pricing.currency || pr.currency || 'EUR',
              indicative: pricing.indicative === true,
              stale: pricing.stale === true,
              status: x.status,
            };
          }),
        },
        decision,
        payment: bs.payment,
        end,
      },
    };
    if (detail) {
      item.notified = n.map((x) => {
        const pr = person(x.recipientRole, x.recipientId);
        return { id: String(x.recipientId), name: pr.name, role: x.recipientRole, city: pr.city, kind: pr.kind, km: kmTo(p, pr), at: x.createdAt, read: !!x.readAt, readAt: x.readAt || null, targeted: x.type === 'new_request_for_you' };
      });
      // 612 (ZOE) — prévenus PAR CANAL, lus dans le registre des alertes (null pour
      // une annonce d'avant le 612 : seule la cloche en garde la trace).
      try {
        const sum = await require('../services/requestAlert612').channelSummary(p._id);
        item.alertChannels = sum.people
          ? { people: sum.people, bell: sum.bell, push: sum.push, email: sum.email, emailUnsubscribed: sum.emailUnsubscribed, pushNoToken: sum.pushNoToken }
          : null;
      } catch (_) { item.alertChannels = null; }
      item.applications = a.map((x) => {
        const role = x.walkerId ? 'walker' : 'sitter';
        const pr = person(role, x.walkerId || x.sitterId);
        // 16/10 — devise de la fiche du candidat vs devise du propriétaire, tarif
        // affiché, et total STOCKÉ sur la candidature (= ce que l'acceptation
        // facturerait : pricing recopié tel quel dans la réservation).
        const ownerCurrency = ownerP.currency || 'EUR';
        const pricing = x.pricing || {};
        return {
          name: pr.name, role, city: pr.city, kind: pr.kind, km: kmTo(p, pr), tooFar: (() => { const k = kmTo(p, pr); const m = DIST.maxKm(); return m > 0 && typeof k === 'number' && k > m; })(),
          status: x.status, at: x.createdAt, updatedAt: x.updatedAt,
          currency: pr.currency || null, currencyStored: pr.currencyStored || null, currencyInferred: !!pr.currencyInferred, ownerCurrency, currencyMismatch: !!pr.currency && pr.currency !== ownerCurrency,
          // 2410 (ZOE, relevé ADA) — même lecture que who[] : tarif indicatif appliqué, « tarif à venir » (stale → rate null).
          rate: pricing.stale === true ? null : (pricing.indicative === true && Number(pricing.appliedRate) > 0
            ? { amount: Number(pricing.appliedRate), unit: pricing.unit || '' } : (pr.rate || null)),
          total: typeof pricing.totalPrice === 'number' ? pricing.totalPrice : null, totalCurrency: pricing.currency || ownerCurrency,
          indicative: pricing.indicative === true, stale: pricing.stale === true,
        };
      });
      item.contacts = await Promise.all(contactConvs.map(async (c) => {
        const role = c.walkerId ? 'walker' : 'sitter';
        const pr = person(role, c.walkerId || c.sitterId);
        const count = await Message.countDocuments({ conversationId: c._id, senderRole: role, createdAt: { $gte: published } });
        return { name: pr.name, role, city: pr.city, kind: pr.kind, messages: count, lastAt: lastProviderMsg.get(String(c._id)).last };
      }));
      item.booking = booking ? { status: booking.status, paymentStatus: booking.paymentStatus || null } : null;
    }
    out.set(pid, item);
  }
  return out;
}

const POST_FIELDS = 'ownerId postType location serviceTypes startDate endDate walkDurationMinutes createdAt hidden bannedAt status closedAt reservedBy'
  + ' dateMode visitsPerDay animalTypes animalCount budget budgetCurrency'; // 620 (ZOE, relevé ADA)

/**
 * 16/10 — ce que voient les prestataires (feed /posts/requests et PawMap), et
 * quand l'annonce sera supprimée (postCleanupScheduler : 48 h après la fin).
 *   state : 'online' | 'reserved' | 'expired' | 'closed' | 'hidden'
 */
function visibilityOf(p, { svcEnd, decision, bs, now }) {
  const endAt = svcEnd ? new Date(svcEnd) : null;
  const deleteAt = (from) => (from ? new Date(new Date(from).getTime() + PURGE_GRACE_MS) : null);
  if (p.hidden === true) return { state: 'hidden', since: p.bannedAt || null, deleteAt: deleteAt(p.closedAt || endAt) };
  if (p.status === 'closed') return { state: 'closed', since: p.closedAt || null, deleteAt: deleteAt(p.closedAt || endAt) };
  const reserved = !!(p.reservedBy && p.reservedBy.bookingId) || decision.state === 'accepted' || (bs && bs.payment && bs.payment.state === 'paid');
  if (reserved) return { state: 'reserved', since: (p.reservedBy && p.reservedBy.reservedAt) || decision.at || null, deleteAt: deleteAt(endAt) };
  if (endAt && endAt < now) return { state: 'expired', since: endAt, deleteAt: deleteAt(endAt) };
  return { state: 'online', since: p.createdAt || null, until: endAt, deleteAt: deleteAt(endAt) };
}

router.get('/summary', requireAdmin, async (req, res) => {
  try {
    const ids = String(req.query.ids || '').split(',').map((s) => s.trim()).filter(isId).slice(0, 50);
    if (!ids.length) return res.json({ items: {} });
    const { Post } = M();
    const posts = await Post.find({ _id: { $in: ids.map(oid) }, postType: 'request' }).select(POST_FIELDS).lean();
    const map = await journeys(posts);
    res.json({ items: Object.fromEntries(map) });
  } catch (e) {
    logger.error('[admin/requests613/summary]', e);
    res.status(500).json({ error: e.message });
  }
});

router.get('/live', requireAdmin, async (req, res) => {
  try {
    // 23/10 (BOB, demande de Daniel « je veux voir toutes les annonces en ligne ») : plafond 50 → 500,
    // l'accueil de l'admin demande limit=500 et montre chaque annonce avec son suivi.
    const limit = Math.min(500, Math.max(1, parseInt(req.query.limit, 10) || 10));
    const { Post } = M();
    const posts = await Post.find({ postType: 'request', hidden: { $ne: true } })
      .sort({ createdAt: -1 }).limit(500).select(POST_FIELDS).lean();
    const map = await journeys(posts);
    const real = [...map.values()].filter((x) => x.owner.kind === 'real');
    const excluded = map.size - real.length;
    const counters = {
      total: real.length,
      online: real.filter((x) => x.visibility && x.visibility.state === 'online').length, // 23/10 (BOB) — visibles par les prestataires
      open: real.filter((x) => ['waiting', 'applied'].includes(x.status)).length,
      withApplications: real.filter((x) => x.stages.applications.count > 0).length,
      accepted: real.filter((x) => x.stages.decision.state === 'accepted').length,
      paid: real.filter((x) => x.stages.payment.state === 'paid').length,
    };
    res.json({ counters, excludedTestOrStaff: excluded, items: real.slice(0, limit) });
  } catch (e) {
    logger.error('[admin/requests613/live]', e);
    res.status(500).json({ error: e.message });
  }
});

/**
 * 16/10/2026 (ADA, demande de Daniel « observer les publications d'un coup d'œil ») —
 * GET /admin/requests613/board?limit=100&tz=Europe/Paris
 *   → compteurs du jour / de la veille / 7 j / 7 j précédents (publiées, prévenus,
 *     candidatures, validées, payées, expirées sans validation), heure du relevé,
 *     et les demandes des VRAIS comptes (masquées comprises : « retirée »), plus
 *     récentes d'abord. Lecture seule.
 */
function dayStartIn(tz, now) {
  try {
    const parts = new Intl.DateTimeFormat('en-CA', { timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23' })
      .formatToParts(now).reduce((o, x) => { o[x.type] = x.value; return o; }, {});
    const asUtc = Date.UTC(+parts.year, +parts.month - 1, +parts.day, +parts.hour, +parts.minute, +parts.second);
    const offset = asUtc - now.getTime(); // décalage du fuseau à cet instant
    return new Date(Date.UTC(+parts.year, +parts.month - 1, +parts.day) - offset);
  } catch (_) {
    return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  }
}
function boardCounters(items, now, tz) {
  const DAY = 86400000;
  const t0 = dayStartIn(tz, now);
  const windows = {
    today: [t0, now], yesterday: [new Date(t0 - DAY), t0],
    d7: [new Date(now - 7 * DAY), now], prev7: [new Date(now - 14 * DAY), new Date(now - 7 * DAY)],
  };
  const inW = (d, w) => { if (!d) return false; const t = new Date(d).getTime(); return t >= w[0].getTime() && t < w[1].getTime(); };
  const out = {};
  for (const [k, w] of Object.entries(windows)) {
    const c = { published: 0, notified: 0, applications: 0, accepted: 0, paid: 0, expired: 0 };
    for (const it of items) {
      const st = it.stages;
      if (inW(st.published.at, w)) { c.published += 1; c.notified += st.notified.count; }
      for (const d of it.applicationsAt || []) if (inW(d, w)) c.applications += 1;
      if (st.decision.state === 'accepted' && inW(st.decision.at, w)) c.accepted += 1;
      if (st.payment.state === 'paid' && inW(st.payment.at, w)) c.paid += 1;
      if (st.end.state === 'expired' && st.decision.state !== 'accepted' && inW(st.end.at, w)) c.expired += 1;
    }
    out[k] = c;
  }
  return out;
}

router.get('/board', requireAdmin, async (req, res) => {
  try {
    const limit = Math.min(200, Math.max(1, parseInt(req.query.limit, 10) || 100));
    const tz = String(req.query.tz || 'Europe/Paris');
    const now = new Date();
    const { Post } = M();
    const posts = await Post.find({ postType: 'request' }).sort({ createdAt: -1 }).limit(500).select(POST_FIELDS).lean();
    const map = await journeys(posts, { now });
    const real = [...map.values()].filter((x) => x.owner.kind === 'real');
    res.json({
      generatedAt: now, timeZone: tz,
      counters: boardCounters(real, now, tz),
      excludedTestOrStaff: map.size - real.length,
      total: real.length,
      items: real.slice(0, limit),
    });
  } catch (e) {
    logger.error('[admin/requests613/board]', e);
    res.status(500).json({ error: e.message });
  }
});

router.get('/:postId/journey', requireAdmin, async (req, res) => {
  try {
    const { postId } = req.params;
    if (!isId(postId)) return res.status(400).json({ error: 'postId invalide.' });
    const { Post } = M();
    const post = await Post.findById(postId).select(POST_FIELDS).lean();
    if (!post) return res.status(404).json({ error: 'Annonce introuvable.' });
    if (post.postType && post.postType !== 'request') return res.status(400).json({ error: 'Pas une demande.' });
    const map = await journeys([post], { detail: true });
    res.json(map.get(String(post._id)));
  } catch (e) {
    logger.error('[admin/requests613/journey]', e);
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
module.exports._journeys = journeys;
module.exports._kindOf = kindOf;
