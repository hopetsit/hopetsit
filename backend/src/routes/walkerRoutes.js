const express = require('express');
const multer = require('multer');

const {
  listWalkers,
  getWalkerProfile,
  findNearbyWalkers,
  getMyWalkerProfile,
  updateMyWalkerProfile,
  getMyWalkerRates,
  updateMyWalkerRates,
  submitIdentityVerification,
  getMyIdentityVerification,
} = require('../controllers/walkerController');
const { requireAuth, requireRole } = require('../middleware/auth');

const router = express.Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
});

/**
 * Walker routes — public discovery + authenticated self-management.
 *
 * Public:
 *   GET  /walkers                 -> paginated list (filter ?city=)
 *   GET  /walkers/nearby          -> geospatial lookup (?lat=&lng=&radiusInMeters=)
 *   GET  /walkers/:id             -> single public profile
 *
 * Authenticated walker only:
 *   GET  /walkers/me              -> my full profile
 *   PATCH /walkers/me             -> update my editable fields
 *   GET  /walkers/me/rates        -> my walkRates
 *   PUT  /walkers/me/rates        -> replace my walkRates
 *
 * NOTE: /walkers/me routes MUST be declared before /walkers/:id so Express
 * does not treat "me" as an id.
 */

// Authenticated walker self-management (declared first to avoid :id collision).
router.get('/me', requireAuth, requireRole('walker'), getMyWalkerProfile);
router.patch('/me', requireAuth, requireRole('walker'), updateMyWalkerProfile);
router.get('/me/rates', requireAuth, requireRole('walker'), getMyWalkerRates);
router.put('/me/rates', requireAuth, requireRole('walker'), updateMyWalkerRates);
// Session v3.2 — identity verification (parity with /sitters/identity-verification).
router.post(
  '/identity-verification',
  requireAuth,
  requireRole('walker'),
  upload.single('document'),
  submitIdentityVerification,
);
router.get(
  '/me/identity-verification',
  requireAuth,
  requireRole('walker'),
  getMyIdentityVerification,
);

// v18.9.8 — Earnings / virements pour walker. Même structure de réponse que
// /sitters/me/earnings (le frontend partage le même écran). Le filtre est
// walkerId au lieu de sitterId.
const Booking = require('../models/Booking');

router.get('/me/earnings', requireAuth, requireRole('walker'), async (req, res) => {
  try {
    const walkerId = req.user.id;
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit) || 20));
    const skip = (page - 1) * limit;

    const filter = {
      walkerId,
      paymentStatus: 'paid',
    };

    if (req.query.from || req.query.to) {
      filter.paidAt = {};
      if (req.query.from) filter.paidAt.$gte = new Date(req.query.from);
      if (req.query.to) filter.paidAt.$lte = new Date(req.query.to);
    }

    const [bookings, total] = await Promise.all([
      Booking.find(filter)
        .select('status paymentStatus paymentProvider payoutStatus payoutAt paidAt pricing createdAt startDate endDate serviceType')
        .populate('ownerId', 'name avatar')
        .sort({ paidAt: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      Booking.countDocuments(filter),
    ]);

    const allPaid = await Booking.find({ walkerId, paymentStatus: 'paid' })
      .select('pricing.netPayout pricing.totalPrice pricing.commission payoutStatus')
      .lean();

    const totalEarned = allPaid.reduce((s, b) => s + (b.pricing?.netPayout || 0), 0);
    const totalCommission = allPaid.reduce((s, b) => s + (b.pricing?.commission || 0), 0);
    const totalPaidOut = allPaid
      .filter((b) => b.payoutStatus === 'completed')
      .reduce((s, b) => s + (b.pricing?.netPayout || 0), 0);
    const pendingPayout = totalEarned - totalPaidOut;

    res.json({
      earnings: bookings.map((b) => ({
        bookingId: b._id,
        owner: b.ownerId ? { name: b.ownerId.name, avatar: b.ownerId.avatar } : null,
        serviceType: b.serviceType || '',
        startDate: b.startDate,
        endDate: b.endDate,
        paidAt: b.paidAt,
        paymentProvider: b.paymentProvider,
        payoutStatus: b.payoutStatus || 'pending',
        payoutAt: b.payoutAt,
        totalPrice: b.pricing?.totalPrice || 0,
        commission: b.pricing?.commission || 0,
        netPayout: b.pricing?.netPayout || 0,
        currency: b.pricing?.currency || 'EUR',
      })),
      summary: {
        totalEarned: Math.round(totalEarned * 100) / 100,
        totalCommission: Math.round(totalCommission * 100) / 100,
        totalPaidOut: Math.round(totalPaidOut * 100) / 100,
        pendingPayout: Math.round(pendingPayout * 100) / 100,
        totalBookings: total,
      },
      pagination: { page, limit, total, pages: Math.ceil(total / limit) },
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Public discovery.
router.get('/nearby', findNearbyWalkers);
router.get('/', listWalkers);
router.get('/:id', getWalkerProfile);

module.exports = router;
