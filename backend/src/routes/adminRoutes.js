const express = require('express');
const { retryBookingPayout } = require('../controllers/bookingController');
const { requireAuth, requireRole } = require('../middleware/auth');
const Booking = require('../models/Booking');
const Sitter = require('../models/Sitter');
const Owner = require('../models/Owner');
const Pet = require('../models/Pet');
const { decrypt } = require('../utils/encryption');

const router = express.Router();

// ─── ADMIN AUTH MIDDLEWARE ───────────────────────────────────────────────────
// JWT-based: requireAuth verifies token, requireRole('admin') checks payload.role.
// Admin JWTs are issued by POST /auth/admin/login (see authController.adminLogin).
const requireAdmin = [requireAuth, requireRole('admin')];

// ─── DASHBOARD STATS ─────────────────────────────────────────────────────────
router.get('/stats', requireAdmin, async (req, res) => {
  try {
    const [totalBookings, totalSitters, totalOwners, totalPets,
           pendingBookings, paidBookings, revenue] = await Promise.all([
      Booking.countDocuments(),
      Sitter.countDocuments(),
      Owner.countDocuments(),
      Pet.countDocuments(),
      Booking.countDocuments({ status: 'pending' }),
      Booking.countDocuments({ paymentStatus: 'paid' }),
      Booking.aggregate([
        { $match: { paymentStatus: 'paid' } },
        { $group: { _id: null, total: { $sum: '$totalAmount' } } },
      ]),
    ]);
    res.json({
      totalBookings, totalSitters, totalOwners, totalPets,
      pendingBookings, paidBookings,
      totalRevenue: revenue[0]?.total ?? 0,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── LIST ALL BOOKINGS ────────────────────────────────────────────────────────
router.get('/bookings', requireAdmin, async (req, res) => {
  try {
    const { page = 1, limit = 20, status, paymentStatus } = req.query;
    const filter = {};
    if (status) filter.status = status;
    if (paymentStatus) filter.paymentStatus = paymentStatus;
    const bookings = await Booking.find(filter)
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(Number(limit))
      .lean();
    const total = await Booking.countDocuments(filter);
    res.json({ bookings, total, page: Number(page), limit: Number(limit) });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── LIST ALL SITTERS ────────────────────────────────────────────────────────
router.get('/sitters', requireAdmin, async (req, res) => {
  try {
    const { page = 1, limit = 20, verified } = req.query;
    const filter = {};
    if (verified !== undefined) filter.verified = verified === 'true';
    const sitters = await Sitter.find(filter)
      .select('-password')
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(Number(limit))
      .lean();
    const total = await Sitter.countDocuments(filter);
    res.json({ sitters, total, page: Number(page), limit: Number(limit) });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── LIST ALL OWNERS ─────────────────────────────────────────────────────────
router.get('/owners', requireAdmin, async (req, res) => {
  try {
    const { page = 1, limit = 20 } = req.query;
    const owners = await Owner.find()
      .select('-password')
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(Number(limit))
      .lean();
    const total = await Owner.countDocuments();
    res.json({ owners, total, page: Number(page), limit: Number(limit) });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── VERIFY / UNVERIFY SITTER ─────────────────────────────────────────────────
router.patch('/sitters/:id/verify', requireAdmin, async (req, res) => {
  try {
    const { verified } = req.body;
    const sitter = await Sitter.findByIdAndUpdate(
      req.params.id,
      { verified: Boolean(verified) },
      { new: true }
    ).select('-password');
    if (!sitter) return res.status(404).json({ error: 'Sitter not found.' });
    res.json({ sitter });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── DELETE USER ─────────────────────────────────────────────────────────────
router.delete('/sitters/:id', requireAdmin, async (req, res) => {
  try {
    await Sitter.findByIdAndDelete(req.params.id);
    res.json({ message: 'Sitter deleted.' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.delete('/owners/:id', requireAdmin, async (req, res) => {
  try {
    await Owner.findByIdAndDelete(req.params.id);
    res.json({ message: 'Owner deleted.' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── UPDATE BOOKING STATUS ────────────────────────────────────────────────────
router.patch('/bookings/:id', requireAdmin, async (req, res) => {
  try {
    const { status, paymentStatus } = req.body;
    const update = {};
    if (status) update.status = status;
    if (paymentStatus) update.paymentStatus = paymentStatus;
    const booking = await Booking.findByIdAndUpdate(req.params.id, update, { new: true }).lean();
    if (!booking) return res.status(404).json({ error: 'Booking not found.' });
    res.json({ booking });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── IBAN: ADMIN VIEW SITTER IBAN (masked) ────────────────────────────────────
router.get('/sitters/:id/iban', requireAdmin, async (req, res) => {
  try {
    const sitter = await Sitter.findById(req.params.id).select('ibanHolder ibanNumber ibanBic ibanVerified payoutMethod');
    if (!sitter) return res.status(404).json({ error: 'Sitter not found.' });
    // Mask IBAN for display: decrypt then show first 4 + last 4
    const iban = decrypt(sitter.ibanNumber);
    const masked = iban
      ? iban.slice(0, 4) + '****' + iban.slice(-4)
      : '';
    res.json({
      ibanHolder: sitter.ibanHolder,
      ibanNumberMasked: masked,
      ibanBic: sitter.ibanBic,
      ibanVerified: sitter.ibanVerified,
      payoutMethod: sitter.payoutMethod,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── IBAN: ADMIN VERIFY SITTER IBAN ──────────────────────────────────────────
router.patch('/sitters/:id/iban/verify', requireAdmin, async (req, res) => {
  try {
    const sitter = await Sitter.findByIdAndUpdate(
      req.params.id,
      { ibanVerified: true },
      { new: true }
    ).select('-password');
    if (!sitter) return res.status(404).json({ error: 'Sitter not found.' });
    res.json({ message: 'IBAN verified.', ibanVerified: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── RETRY PAYOUT ─────────────────────────────────────────────────────────────
router.post('/bookings/:id/retry-payout', requireAuth, requireRole('owner'), retryBookingPayout);

module.exports = router;
