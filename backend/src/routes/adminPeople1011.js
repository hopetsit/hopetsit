/**
 * 1011 (ADA, ordre de Daniel du 10/11) — onglet « Inscriptions » de l'admin :
 * « a publié / a candidaté / a payé » par profil.
 *
 * LECTURE SEULE. La réponse ne contient QUE des identifiants de profil et des
 * compteurs : ni e-mail, ni téléphone, ni nom, ni adresse. L'admin recoupe ces
 * identifiants avec la liste des utilisateurs qu'il a déjà chargée.
 *
 *   GET /admin/people-1011/activity
 *   → { generatedAt, people: {
 *         'owner:<id>':  { published, paid },
 *         'sitter:<id>': { applied, paid },
 *         'walker:<id>': { applied, paid } } }
 *
 * « Payé » suit EXACTEMENT la règle du suivi des demandes
 * (adminRequestJourney613.bookingStage) : pas remboursé, et paymentStatus
 * 'paid' ou status 'paid' / 'completed' ou paidAt renseigné.
 * « A publié » ne compte que les demandes encore en base (une demande
 * supprimée physiquement n'est plus comptée).
 */
const express = require('express');
const { requireAuth, requireRole } = require('../middleware/auth');
const { auditAdmin } = require('../middleware/auditAdmin');
const logger = require('../utils/logger');

const router = express.Router();
const requireAdmin = [requireAuth, requireRole('admin'), auditAdmin];

// Même règle que bookingStage() du suivi des demandes.
const PAID_MATCH = {
  status: { $ne: 'refunded' },
  paymentStatus: { $nin: ['refunded', 'refund'] },
  $or: [
    { paymentStatus: 'paid' },
    { status: { $in: ['paid', 'completed'] } },
    { paidAt: { $ne: null } },
  ],
};

async function countBy(Model, match, field) {
  const rows = await Model.aggregate([
    { $match: Object.assign({}, match, { [field]: { $ne: null } }) },
    { $group: { _id: '$' + field, n: { $sum: 1 } } },
  ]);
  return rows.filter((r) => r._id);
}

router.get('/activity', requireAdmin, async (req, res) => {
  try {
    const Post = require('../models/Post');
    const Application = require('../models/Application');
    const Booking = require('../models/Booking');

    const [posts, appsSitter, appsWalker, paidOwner, paidSitter, paidWalker] = await Promise.all([
      countBy(Post, { postType: 'request' }, 'ownerId'),
      countBy(Application, {}, 'sitterId'),
      countBy(Application, {}, 'walkerId'),
      countBy(Booking, PAID_MATCH, 'ownerId'),
      countBy(Booking, PAID_MATCH, 'sitterId'),
      countBy(Booking, PAID_MATCH, 'walkerId'),
    ]);

    const people = {};
    const put = (role, rows, key) => {
      rows.forEach((r) => {
        const k = role + ':' + String(r._id);
        if (!people[k]) people[k] = role === 'owner' ? { published: 0, paid: 0 } : { applied: 0, paid: 0 };
        people[k][key] = r.n;
      });
    };
    put('owner', posts, 'published');
    put('owner', paidOwner, 'paid');
    put('sitter', appsSitter, 'applied');
    put('sitter', paidSitter, 'paid');
    put('walker', appsWalker, 'applied');
    put('walker', paidWalker, 'paid');

    return res.json({ generatedAt: new Date().toISOString(), people });
  } catch (err) {
    logger.error('[admin people-1011] activity', err && err.message);
    return res.status(500).json({ error: 'Lecture impossible.' });
  }
});

module.exports = router;
module.exports.PAID_MATCH = PAID_MATCH;
