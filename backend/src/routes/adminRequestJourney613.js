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

/** Charge prénom / ville / type de compte → Map "role:id". */
async function people(byRole) {
  const out = new Map();
  const models = M();
  const MOD = { owner: models.Owner, sitter: models.Sitter, walker: models.Walker };
  await Promise.all(Object.entries(byRole).map(async ([role, ids]) => {
    const list = [...new Set(ids.filter(isId).map(String))];
    if (!list.length || !MOD[role]) return;
    const docs = await MOD[role].find({ _id: { $in: list } })
      .select('name email isStaff city coverageCity location.city').lean();
    for (const d of docs) {
      out.set(`${role}:${d._id}`, { name: firstName(d.name), city: cityOf(d), kind: kindOf(d) });
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
      .select('postId sitterId walkerId status bookingId createdAt updatedAt').sort({ createdAt: 1 }).lean(),
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
  const person = (role, id) => ({ role, id: String(id), ...(who.get(`${role}:${id}`) || { name: '', city: '', kind: 'real' }) });

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
    const item = {
      postId: pid,
      owner: { id: ownerId, name: ownerP.name, kind: ownerP.kind },
      city: (p.location && p.location.city) || '',
      serviceTypes: p.serviceTypes || [],
      serviceDate: serviceDateOf(p),
      serviceEnd: p.endDate || null,
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
            return { name: pr.name, role, kind: pr.kind };
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
        return { name: pr.name, role: x.recipientRole, city: pr.city, kind: pr.kind, at: x.createdAt, read: !!x.readAt, readAt: x.readAt || null, targeted: x.type === 'new_request_for_you' };
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
        return { name: pr.name, role, city: pr.city, kind: pr.kind, status: x.status, at: x.createdAt, updatedAt: x.updatedAt };
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

const POST_FIELDS = 'ownerId postType location.city serviceTypes startDate endDate createdAt hidden status closedAt reservedBy';

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
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit, 10) || 10));
    const { Post } = M();
    const posts = await Post.find({ postType: 'request', hidden: { $ne: true } })
      .sort({ createdAt: -1 }).limit(500).select(POST_FIELDS).lean();
    const map = await journeys(posts);
    const real = [...map.values()].filter((x) => x.owner.kind === 'real');
    const excluded = map.size - real.length;
    const counters = {
      total: real.length,
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
