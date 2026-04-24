const express = require('express');
const { retryBookingPayout } = require('../controllers/bookingController');
const { requireAuth, requireRole } = require('../middleware/auth');
const Booking = require('../models/Booking');
const Sitter = require('../models/Sitter');
const Owner = require('../models/Owner');
const Walker = require('../models/Walker');
const Pet = require('../models/Pet');
const { decrypt } = require('../utils/encryption');
const { sendTestEmail } = require('../services/emailService');
const pricingService = require('../services/pricingService');
const serviceCatalogService = require('../services/serviceCatalogService');
const mapPoiSeedService = require('../services/mapPoiSeedService');
const logger = require('../utils/logger');

const router = express.Router();

// ─── ADMIN AUTH MIDDLEWARE ───────────────────────────────────────────────────
// JWT-based: requireAuth verifies token, requireRole('admin') checks payload.role.
// Admin JWTs are issued by POST /auth/admin/login (see authController.adminLogin).
const requireAdmin = [requireAuth, requireRole('admin')];

// ─── SMTP TEST ───────────────────────────────────────────────────────────────
// POST /admin/test-email?to=someone@example.com
// Lets admins verify the SMTP configuration by sending a test email.
// Reports success, or returns the underlying SMTP error so it can be diagnosed
// from the admin dashboard without SSH access to Render.
router.post('/test-email', requireAdmin, async (req, res) => {
  const to = req.body?.to || req.query?.to;
  if (!to || !/^\S+@\S+\.\S+$/.test(String(to))) {
    return res.status(400).json({ error: 'Provide a valid recipient email as ?to=... or { to: ... }' });
  }
  const smtpConfigured = Boolean(process.env.SMTP_HOST);
  try {
    const result = await sendTestEmail(to);
    return res.json({
      ok: true,
      smtpConfigured,
      host: process.env.SMTP_HOST || null,
      from: process.env.SMTP_FROM || process.env.SMTP_USER || null,
      messageId: result?.messageId || null,
      skipped: result?.skipped || false,
      reason: result?.reason || null,
    });
  } catch (err) {
    logger.error('[admin/test-email] failed', err);
    return res.status(500).json({
      ok: false,
      smtpConfigured,
      host: process.env.SMTP_HOST || null,
      error: err?.message || String(err),
      code: err?.code || null,
      response: err?.response || null,
    });
  }
});

// ─── DASHBOARD STATS ─────────────────────────────────────────────────────────
router.get('/stats', requireAdmin, async (req, res) => {
  try {
    // v18.6 — walker ajouté + paiements du jour (paidToday + todayRevenue).
    const Walker = require('../models/Walker');
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    const [totalBookings, totalSitters, totalWalkers, totalOwners, totalPets,
           pendingBookings, paidBookings, paidToday, revenue, todayRevenueAgg] =
      await Promise.all([
        Booking.countDocuments(),
        Sitter.countDocuments(),
        Walker.countDocuments(),
        Owner.countDocuments(),
        Pet.countDocuments(),
        Booking.countDocuments({ status: 'pending' }),
        Booking.countDocuments({ paymentStatus: 'paid' }),
        Booking.countDocuments({
          paymentStatus: 'paid',
          paidAt: { $gte: todayStart },
        }),
        Booking.aggregate([
          { $match: { paymentStatus: 'paid' } },
          { $group: { _id: null, total: { $sum: '$pricing.totalPrice' } } },
        ]),
        Booking.aggregate([
          {
            $match: {
              paymentStatus: 'paid',
              paidAt: { $gte: todayStart },
            },
          },
          { $group: { _id: null, total: { $sum: '$pricing.totalPrice' } } },
        ]),
      ]);
    res.json({
      totalBookings,
      totalSitters,
      totalWalkers,
      totalOwners,
      totalPets,
      pendingBookings,
      paidBookings,
      paidToday,
      totalRevenue: revenue[0]?.total ?? 0,
      todayRevenue: todayRevenueAgg[0]?.total ?? 0,
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

// ─── WALKERS (session v3.2) ──────────────────────────────────────────────────
router.get('/walkers', requireAdmin, async (req, res) => {
  try {
    const { page = 1, limit = 20, verified } = req.query;
    const filter = {};
    if (verified !== undefined) filter.verified = verified === 'true';
    const walkers = await Walker.find(filter)
      .select('-password')
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(Number(limit))
      .lean();
    const total = await Walker.countDocuments(filter);
    res.json({ walkers, total, page: Number(page), limit: Number(limit) });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.patch('/walkers/:id/verify', requireAdmin, async (req, res) => {
  try {
    const { verified } = req.body;
    const walker = await Walker.findByIdAndUpdate(
      req.params.id,
      { verified: Boolean(verified) },
      { new: true }
    ).select('-password');
    if (!walker) return res.status(404).json({ error: 'Walker not found.' });
    res.json({ walker });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.delete('/walkers/:id', requireAdmin, async (req, res) => {
  try {
    await Walker.findByIdAndDelete(req.params.id);
    res.json({ message: 'Walker deleted.' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── UPDATE BOOKING STATUS ────────────────────────────────────────────────────
router.patch('/bookings/:id', requireAdmin, async (req, res) => {
  try {
    const { status, paymentStatus, payoutStatus } = req.body;
    const update = {};
    if (status) update.status = status;
    if (paymentStatus) update.paymentStatus = paymentStatus;
    if (payoutStatus) update.payoutStatus = payoutStatus;
    const booking = await Booking.findByIdAndUpdate(req.params.id, update, { new: true }).lean();
    if (!booking) return res.status(404).json({ error: 'Booking not found.' });
    res.json({ booking });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── ADMIN MANUAL REFUND ─────────────────────────────────────────────────────
// Allows admin to issue a full refund for any paid booking (conflict resolution).
router.post('/bookings/:id/refund', requireAdmin, async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id);
    if (!booking) return res.status(404).json({ error: 'Booking not found.' });
    if (booking.paymentStatus === 'refunded') {
      return res.status(409).json({ error: 'Booking already refunded.' });
    }
    if (booking.paymentStatus !== 'paid') {
      return res.status(409).json({ error: `Cannot refund — payment status is "${booking.paymentStatus}".` });
    }

    // Attempt provider-specific refund
    let refundResult = null;
    try {
      if (booking.paymentProvider === 'stripe') {
        const { createRefund } = require('../services/stripeService');
        const chargeId = booking.stripeChargeId || booking.stripePaymentIntentId;
        if (chargeId) refundResult = await createRefund(chargeId);
      } else if (booking.paymentProvider === 'paypal') {
        const { refundPaypalCapture } = require('../services/paypalService');
        if (booking.paypalCaptureId) refundResult = await refundPaypalCapture(booking.paypalCaptureId);
      }
    } catch (refundErr) {
      logger.error('[admin/refund] Provider refund failed', refundErr);
      // Still mark as refunded in DB even if provider call fails — admin can reconcile manually
    }

    booking.paymentStatus = 'refunded';
    booking.status = 'cancelled';
    booking.payoutStatus = 'cancelled';
    booking.cancelledAt = new Date();
    booking.cancelledBy = 'admin';
    booking.cancellationReason = req.body?.reason || 'admin_manual_refund';
    await booking.save();

    logger.info(`[admin] Manual refund for booking ${req.params.id} by admin ${req.user?.id}`);
    res.json({
      message: 'Refund processed.',
      refundResult,
      booking: { _id: booking._id, paymentStatus: booking.paymentStatus, status: booking.status },
    });
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

// Sprint 5 step 7 — identity verification admin review.
// Session v3.2 — now aggregates Sitter AND Walker submissions so the admin
// dashboard sees every pending ID, no matter which role uploaded it.
router.get('/identity-verifications', requireAdmin, async (req, res) => {
  try {
    const { status = 'pending' } = req.query;
    const [sitters, walkers] = await Promise.all([
      Sitter.find({ 'identityVerification.status': status })
        .select('name identityVerification')
        .sort({ 'identityVerification.submittedAt': -1 })
        .lean(),
      Walker.find({ 'identityVerification.status': status })
        .select('name identityVerification')
        .sort({ 'identityVerification.submittedAt': -1 })
        .lean(),
    ]);
    const mapDoc = (role) => (u) => ({
      id: u._id.toString(),
      name: u.name,
      role,
      submittedAt: u.identityVerification?.submittedAt || null,
      status: u.identityVerification?.status || 'none',
      documentUrl: u.identityVerification?.documentUrl
        ? decrypt(u.identityVerification.documentUrl)
        : '',
    });
    const payload = [
      ...sitters.map(mapDoc('sitter')),
      ...walkers.map(mapDoc('walker')),
    ].sort((a, b) => {
      const da = a.submittedAt ? new Date(a.submittedAt).getTime() : 0;
      const db = b.submittedAt ? new Date(b.submittedAt).getTime() : 0;
      return db - da;
    });
    res.json({ verifications: payload });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Sprint 7 step 5 — review moderation.
const Review = require('../models/Review');

// Sprint 7 step 6 — platform stats + user moderation.
// v18.6 — walker parity ajouté aux stats (total users, revenue aujourd'hui).
router.get('/platform-stats', requireAdmin, async (req, res) => {
  try {
    const Walker = require('../models/Walker');
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    const [
      totalOwners, totalSitters, totalWalkers,
      totalBookings, totalBookingsCompleted,
      premiumCount, topSitterCount, topWalkerCount,
      revAgg, todayRevAgg,
    ] = await Promise.all([
      Owner.countDocuments(),
      Sitter.countDocuments(),
      Walker.countDocuments(),
      Booking.countDocuments(),
      Booking.countDocuments({ status: 'completed' }),
      Owner.countDocuments({ isPremium: true }),
      Sitter.countDocuments({ isTopSitter: true }),
      Walker.countDocuments({ isTopWalker: true }).catch(() => 0),
      Booking.aggregate([
        { $match: { paymentStatus: 'paid' } },
        { $group: { _id: null, total: { $sum: '$pricing.commission' } } },
      ]).catch(() => []),
      Booking.aggregate([
        {
          $match: {
            paymentStatus: 'paid',
            paidAt: { $gte: todayStart },
          },
        },
        { $group: { _id: null, total: { $sum: '$pricing.commission' } } },
      ]).catch(() => []),
    ]);
    res.json({
      totalUsers: totalOwners + totalSitters + totalWalkers,
      totalOwners,
      totalSitters,
      totalWalkers,
      totalBookings,
      totalBookingsCompleted,
      premiumCount,
      topSitterCount,
      topWalkerCount,
      platformRevenue: revAgg?.[0]?.total ?? 0,
      todayPlatformRevenue: todayRevAgg?.[0]?.total ?? 0,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// v18.6 — walker ajouté à userModelFor pour que suspend / restore / delete
// marchent aussi pour les walkers dans admin.
const userModelFor = (role) => {
  const Walker = require('../models/Walker');
  if (role === 'sitter') return Sitter;
  if (role === 'owner') return Owner;
  if (role === 'walker') return Walker;
  return null;
};

router.post('/users/:id/suspend', requireAdmin, async (req, res) => {
  try {
    const { role, reason = '' } = req.body || {};
    const Model = userModelFor(role);
    if (!Model) return res.status(400).json({ error: "role must be 'owner' or 'sitter'." });
    const user = await Model.findByIdAndUpdate(
      req.params.id,
      { status: 'suspended', banReason: String(reason) },
      { new: true }
    ).select('status banReason').lean();
    if (!user) return res.status(404).json({ error: 'User not found.' });
    logger.info(`[admin] suspended ${role} ${req.params.id} by ${req.user?.id} — reason: ${reason}`);
    res.json(user);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/users/:id/reactivate', requireAdmin, async (req, res) => {
  try {
    const { role } = req.body || {};
    const Model = userModelFor(role);
    if (!Model) return res.status(400).json({ error: "role must be 'owner' or 'sitter'." });
    const user = await Model.findByIdAndUpdate(
      req.params.id,
      { status: 'active', banReason: '', bannedAt: null },
      { new: true }
    ).select('status').lean();
    if (!user) return res.status(404).json({ error: 'User not found.' });
    logger.info(`[admin] reactivated ${role} ${req.params.id} by ${req.user?.id}`);
    res.json(user);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/users/:id/ban', requireAdmin, async (req, res) => {
  try {
    const { role, reason = '' } = req.body || {};
    const Model = userModelFor(role);
    if (!Model) return res.status(400).json({ error: "role must be 'owner' or 'sitter'." });
    const user = await Model.findByIdAndUpdate(
      req.params.id,
      { status: 'banned', banReason: String(reason), bannedAt: new Date() },
      { new: true }
    ).select('status banReason bannedAt').lean();
    if (!user) return res.status(404).json({ error: 'User not found.' });
    logger.info(`[admin] banned ${role} ${req.params.id} by ${req.user?.id} — reason: ${reason}`);
    res.json(user);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.get('/users/search', requireAdmin, async (req, res) => {
  try {
    const { q = '' } = req.query;
    const regex = new RegExp(String(q).trim(), 'i');
    const [owners, sitters] = await Promise.all([
      Owner.find({ $or: [{ email: regex }, { name: regex }] }).select('name email status').limit(20).lean(),
      Sitter.find({ $or: [{ email: regex }, { name: regex }] }).select('name email status').limit(20).lean(),
    ]);
    res.json({
      results: [
        ...owners.map(o => ({ ...o, role: 'owner' })),
        ...sitters.map(s => ({ ...s, role: 'sitter' })),
      ],
    });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.get('/reviews', requireAdmin, async (req, res) => {
  try {
    const { status = 'all', page = 1, limit = 30 } = req.query;
    const filter = {};
    if (status === 'reported') filter.reportedCount = { $gte: 1 };
    else if (status === 'hidden') filter.hidden = true;
    const reviews = await Review.find(filter)
      .sort({ reportedCount: -1, createdAt: -1 })
      .skip((Number(page) - 1) * Number(limit))
      .limit(Number(limit))
      .lean();
    const total = await Review.countDocuments(filter);
    res.json({ reviews, total, page: Number(page), limit: Number(limit) });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.patch('/reviews/:id/hide', requireAdmin, async (req, res) => {
  try {
    const { reason = '' } = req.body || {};
    const review = await Review.findByIdAndUpdate(
      req.params.id,
      { hidden: true, hiddenReason: String(reason), hiddenAt: new Date() },
      { new: true }
    ).lean();
    if (!review) return res.status(404).json({ error: 'Review not found.' });
    res.json({ review });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.patch('/reviews/:id/restore', requireAdmin, async (req, res) => {
  try {
    const review = await Review.findByIdAndUpdate(
      req.params.id,
      { hidden: false, hiddenReason: '', hiddenAt: null },
      { new: true }
    ).lean();
    if (!review) return res.status(404).json({ error: 'Review not found.' });
    res.json({ review });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.delete('/reviews/:id', requireAdmin, async (req, res) => {
  try {
    const review = await Review.findByIdAndDelete(req.params.id).lean();
    if (!review) return res.status(404).json({ error: 'Review not found.' });
    logger.info(`[admin] deleted review ${review._id} by user ${req.user?.id}`);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.patch('/identity-verifications/:id', requireAdmin, async (req, res) => {
  try {
    const { action, reason = '' } = req.body || {};
    if (!['approve', 'reject'].includes(action)) {
      return res.status(400).json({ error: "action must be 'approve' or 'reject'." });
    }
    const update = {
      'identityVerification.status': action === 'approve' ? 'verified' : 'rejected',
      'identityVerification.reviewedAt': new Date(),
      'identityVerification.rejectionReason': action === 'reject' ? String(reason || '') : '',
    };
    // Session v3.2 — try Sitter first, then Walker. Same doc id space.
    let doc = await Sitter.findByIdAndUpdate(req.params.id, { $set: update }, { new: true })
      .select('identityVerification');
    if (!doc) {
      doc = await Walker.findByIdAndUpdate(req.params.id, { $set: update }, { new: true })
        .select('identityVerification');
    }
    if (!doc) return res.status(404).json({ error: 'Verification target not found.' });
    res.json({
      status: doc.identityVerification.status,
      reviewedAt: doc.identityVerification.reviewedAt,
      rejectionReason: doc.identityVerification.rejectionReason,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── REPORTS (abuse signals from users) ──────────────────────────────────────
// Daniel's request: centralize "Signaler" reports from profile / comment /
// message / photo into a single admin queue with status transitions.
const Report = require('../models/Report');

router.get('/reports', requireAdmin, async (req, res) => {
  try {
    const { status = 'open', targetType, page = 1, limit = 50 } = req.query;
    const filter = {};
    if (status && status !== 'all') filter.status = status;
    if (targetType) filter.targetType = targetType;
    const reports = await Report.find(filter)
      .sort({ createdAt: -1 })
      .skip((Number(page) - 1) * Number(limit))
      .limit(Number(limit))
      .lean();
    const total = await Report.countDocuments(filter);
    const openCount = await Report.countDocuments({ status: 'open' });
    res.json({
      reports,
      total,
      openCount,
      page: Number(page),
      limit: Number(limit),
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.patch('/reports/:id', requireAdmin, async (req, res) => {
  try {
    const { status, resolution = '' } = req.body || {};
    if (!['open', 'reviewing', 'resolved', 'dismissed'].includes(status)) {
      return res.status(400).json({ error: 'Invalid status.' });
    }
    const resolvedBy = req.user?.email || req.user?.id || 'admin';
    const update = {
      status,
      resolution: String(resolution || ''),
    };
    if (status === 'resolved' || status === 'dismissed') {
      update.resolvedAt = new Date();
      update.resolvedBy = resolvedBy;
    }
    const report = await Report.findByIdAndUpdate(
      req.params.id,
      { $set: update },
      { new: true }
    ).lean();
    if (!report) return res.status(404).json({ error: 'Report not found.' });
    logger.info(
      `[admin] report ${report._id} -> ${status} by ${resolvedBy}`
    );
    res.json({ report });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.delete('/reports/:id', requireAdmin, async (req, res) => {
  try {
    const r = await Report.findByIdAndDelete(req.params.id).lean();
    if (!r) return res.status(404).json({ error: 'Report not found.' });
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── TERMS & CONDITIONS (admin-editable) ─────────────────────────────────────
// Daniel's request: let admin edit the T&C text from the dashboard instead of
// re-building the app every time. The public GET /terms/:lang endpoint is
// served by routes/termsRoutes.js; these admin endpoints let us list and
// upsert documents per language.
const TermsDocument = require('../models/TermsDocument');
const TERMS_LANGS = ['en', 'fr', 'es', 'it', 'de', 'pt'];

router.get('/terms', requireAdmin, async (req, res) => {
  try {
    const docs = await TermsDocument.find().lean();
    const byLang = {};
    for (const d of docs) byLang[d.language] = d;
    const payload = TERMS_LANGS.map((lang) => ({
      language: lang,
      content: byLang[lang]?.content ?? '',
      version: byLang[lang]?.version ?? '',
      updatedAt: byLang[lang]?.updatedAt ?? null,
      updatedBy: byLang[lang]?.updatedBy ?? '',
      exists: Boolean(byLang[lang]),
    }));
    res.json({ languages: TERMS_LANGS, documents: payload });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.get('/terms/:lang', requireAdmin, async (req, res) => {
  try {
    const lang = String(req.params.lang || '').toLowerCase();
    if (!TERMS_LANGS.includes(lang)) {
      return res.status(400).json({ error: 'Unsupported language.' });
    }
    const doc = await TermsDocument.findOne({ language: lang }).lean();
    if (!doc) return res.json({ language: lang, content: '', version: '', updatedAt: null, exists: false });
    res.json({ ...doc, exists: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.put('/terms/:lang', requireAdmin, async (req, res) => {
  try {
    const lang = String(req.params.lang || '').toLowerCase();
    if (!TERMS_LANGS.includes(lang)) {
      return res.status(400).json({ error: 'Unsupported language.' });
    }
    const { content = '', version = '' } = req.body || {};
    if (typeof content !== 'string') {
      return res.status(400).json({ error: 'content must be a string.' });
    }
    const updatedBy = req.user?.email || req.user?.id || 'admin';
    const doc = await TermsDocument.findOneAndUpdate(
      { language: lang },
      {
        $set: {
          content,
          version: String(version || '1.0'),
          updatedBy,
        },
        $setOnInsert: { language: lang },
      },
      { new: true, upsert: true, setDefaultsOnInsert: true }
    ).lean();
    logger.info(`[admin] terms updated lang=${lang} by ${updatedBy} (len=${content.length})`);
    res.json({ ...doc, exists: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.delete('/terms/:lang', requireAdmin, async (req, res) => {
  try {
    const lang = String(req.params.lang || '').toLowerCase();
    if (!TERMS_LANGS.includes(lang)) {
      return res.status(400).json({ error: 'Unsupported language.' });
    }
    await TermsDocument.deleteOne({ language: lang });
    res.json({ ok: true, language: lang, reverted: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── PRIVACY POLICY (admin-editable, session v3.2) ───────────────────────────
// Same pattern as TERMS above but against PrivacyPolicyDocument. Public read
// lives in routes/privacyPolicyRoutes.js.
const PrivacyPolicyDocument = require('../models/PrivacyPolicyDocument');
const PRIVACY_LANGS = ['en', 'fr', 'es', 'it', 'de', 'pt'];

router.get('/privacy-policy', requireAdmin, async (req, res) => {
  try {
    const docs = await PrivacyPolicyDocument.find().lean();
    const byLang = {};
    for (const d of docs) byLang[d.language] = d;
    const payload = PRIVACY_LANGS.map((lang) => ({
      language: lang,
      content: byLang[lang]?.content ?? '',
      version: byLang[lang]?.version ?? '',
      updatedAt: byLang[lang]?.updatedAt ?? null,
      updatedBy: byLang[lang]?.updatedBy ?? '',
      exists: Boolean(byLang[lang]),
    }));
    res.json({ languages: PRIVACY_LANGS, documents: payload });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.get('/privacy-policy/:lang', requireAdmin, async (req, res) => {
  try {
    const lang = String(req.params.lang || '').toLowerCase();
    if (!PRIVACY_LANGS.includes(lang)) {
      return res.status(400).json({ error: 'Unsupported language.' });
    }
    const doc = await PrivacyPolicyDocument.findOne({ language: lang }).lean();
    if (!doc) return res.json({ language: lang, content: '', version: '', updatedAt: null, exists: false });
    res.json({ ...doc, exists: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.put('/privacy-policy/:lang', requireAdmin, async (req, res) => {
  try {
    const lang = String(req.params.lang || '').toLowerCase();
    if (!PRIVACY_LANGS.includes(lang)) {
      return res.status(400).json({ error: 'Unsupported language.' });
    }
    const { content = '', version = '' } = req.body || {};
    if (typeof content !== 'string') {
      return res.status(400).json({ error: 'content must be a string.' });
    }
    const updatedBy = req.user?.email || req.user?.id || 'admin';
    const doc = await PrivacyPolicyDocument.findOneAndUpdate(
      { language: lang },
      {
        $set: {
          content,
          version: String(version || '1.0'),
          updatedBy,
        },
        $setOnInsert: { language: lang },
      },
      { new: true, upsert: true, setDefaultsOnInsert: true }
    ).lean();
    logger.info(`[admin] privacy-policy updated lang=${lang} by ${updatedBy} (len=${content.length})`);
    res.json({ ...doc, exists: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.delete('/privacy-policy/:lang', requireAdmin, async (req, res) => {
  try {
    const lang = String(req.params.lang || '').toLowerCase();
    if (!PRIVACY_LANGS.includes(lang)) {
      return res.status(400).json({ error: 'Unsupported language.' });
    }
    await PrivacyPolicyDocument.deleteOne({ language: lang });
    res.json({ ok: true, language: lang, reverted: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── PAYMENT ANALYTICS ───────────────────────────────────────────────────────
// Full payment/payout overview for admin dashboard
router.get('/payments', requireAdmin, async (req, res) => {
  try {
    const { page = 1, limit = 30, paymentStatus, payoutStatus, paymentProvider, from, to } = req.query;
    const filter = { paymentStatus: { $in: ['paid', 'failed', 'refunded', 'refund'] } };
    if (paymentStatus) filter.paymentStatus = paymentStatus;
    if (payoutStatus) filter.payoutStatus = payoutStatus;
    if (paymentProvider) filter.paymentProvider = paymentProvider;
    if (from || to) {
      filter.paidAt = {};
      if (from) filter.paidAt.$gte = new Date(from);
      if (to) filter.paidAt.$lte = new Date(to);
    }

    const [bookings, total, aggregates] = await Promise.all([
      Booking.find(filter)
        .sort({ paidAt: -1, createdAt: -1 })
        .skip((Number(page) - 1) * Number(limit))
        .limit(Number(limit))
        .populate('ownerId', 'name email')
        .populate('sitterId', 'name email payoutMethod')
        .lean(),
      Booking.countDocuments(filter),
      Booking.aggregate([
        { $match: { paymentStatus: 'paid' } },
        {
          $group: {
            _id: null,
            totalRevenue: { $sum: '$pricing.totalPrice' },
            totalCommission: { $sum: '$pricing.commission' },
            totalPayouts: { $sum: '$pricing.netPayout' },
            count: { $sum: 1 },
          },
        },
      ]),
    ]);

    // Provider breakdown
    const providerBreakdown = await Booking.aggregate([
      { $match: { paymentStatus: 'paid' } },
      {
        $group: {
          _id: '$paymentProvider',
          count: { $sum: 1 },
          total: { $sum: '$pricing.totalPrice' },
          commission: { $sum: '$pricing.commission' },
        },
      },
    ]);

    // Payout status breakdown
    const payoutBreakdown = await Booking.aggregate([
      { $match: { paymentStatus: 'paid' } },
      {
        $group: {
          _id: '$payoutStatus',
          count: { $sum: 1 },
          total: { $sum: '$pricing.netPayout' },
        },
      },
    ]);

    const agg = aggregates[0] || { totalRevenue: 0, totalCommission: 0, totalPayouts: 0, count: 0 };

    res.json({
      payments: bookings.map((b) => ({
        _id: b._id,
        ownerName: b.ownerId?.name || 'Unknown',
        ownerEmail: b.ownerId?.email || '',
        sitterName: b.sitterId?.name || 'Unknown',
        sitterEmail: b.sitterId?.email || '',
        sitterPayoutMethod: b.sitterId?.payoutMethod || 'stripe',
        serviceType: b.serviceType || '-',
        date: b.date,
        totalPrice: b.pricing?.totalPrice || 0,
        commission: b.pricing?.commission || 0,
        netPayout: b.pricing?.netPayout || 0,
        currency: b.pricing?.currency || 'EUR',
        paymentStatus: b.paymentStatus,
        payoutStatus: b.payoutStatus || 'pending',
        paymentProvider: b.paymentProvider || '-',
        paidAt: b.paidAt,
        payoutAt: b.payoutAt,
        payoutError: b.payoutError,
        stripePaymentIntentId: b.stripePaymentIntentId,
        paypalOrderId: b.paypalOrderId,
      })),
      total,
      page: Number(page),
      limit: Number(limit),
      summary: {
        totalRevenue: agg.totalRevenue,
        totalCommission: agg.totalCommission,
        totalPayouts: agg.totalPayouts,
        paidCount: agg.count,
      },
      providerBreakdown: providerBreakdown.reduce((acc, p) => {
        acc[p._id || 'unknown'] = { count: p.count, total: p.total, commission: p.commission };
        return acc;
      }, {}),
      payoutBreakdown: payoutBreakdown.reduce((acc, p) => {
        acc[p._id || 'pending'] = { count: p.count, total: p.total };
        return acc;
      }, {}),
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── RETRY SITTER PAYOUT (admin) ────────────────────────────────────────────
router.post('/payments/:id/retry-payout', requireAdmin, async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id);
    if (!booking) return res.status(404).json({ error: 'Booking not found.' });
    if (booking.payoutStatus === 'completed') return res.status(400).json({ error: 'Payout already completed.' });
    booking.payoutStatus = 'pending';
    booking.payoutError = null;
    await booking.save();
    // Trigger payout processing (same as automatic flow)
    const { processSitterPayoutForBooking } = require('../controllers/bookingController');
    if (typeof processSitterPayoutForBooking === 'function') {
      processSitterPayoutForBooking(booking._id).catch(() => {});
    }
    res.json({ message: 'Payout retry queued.', payoutStatus: 'pending' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── BOOST ACTIVITY ─────────────────────────────────────────────────────────
// Session v3.3 — now aggregates EVERY shop purchase, not just profile boosts:
//   * Profile boost (Sitter/Owner/Walker.boostPurchases, kind === 'profile')
//   * Map boost   (Sitter/Owner/Walker.boostPurchases, kind === 'map')
//   * Premium subscription (UserSubscription.payments)
//   * Chat add-on (UserChatAddon.payments)
//
// Each entry carries a `product` field ('profile_boost' | 'map_boost' |
// 'premium' | 'chat_addon') so the admin UI can filter / color-code.
router.get('/boosts', requireAdmin, async (req, res) => {
  try {
    const { page = 1, limit = 30, tier, role, product } = req.query;
    const now = new Date();

    const UserSubscription = require('../models/UserSubscription');
    const UserChatAddon = require('../models/UserChatAddon');

    // Fetch boost purchases from all 3 user collections
    const [sitters, owners, walkers, subs, chatAddons] = await Promise.all([
      Sitter.find({ 'boostPurchases.0': { $exists: true } })
        .select('name email boostExpiry boostTier boostPurchases')
        .lean(),
      Owner.find({ 'boostPurchases.0': { $exists: true } })
        .select('name email boostExpiry boostTier boostPurchases')
        .lean(),
      Walker.find({ 'boostPurchases.0': { $exists: true } })
        .select('name email boostExpiry boostTier boostPurchases')
        .lean(),
      UserSubscription.find({ 'payments.0': { $exists: true } })
        .select('userId userModel payments currentPeriodEnd status plan')
        .lean(),
      UserChatAddon.find({ 'payments.0': { $exists: true } })
        .select('userId userModel payments currentPeriodEnd status')
        .lean(),
    ]);

    // Build a quick lookup for sub/addon userId → name+email so the UI
    // doesn't need a second round-trip per row.
    const allUserIds = new Set();
    [...subs, ...chatAddons].forEach((d) => {
      if (d.userId) allUserIds.add(String(d.userId));
    });
    const [sitterMap, ownerMap, walkerMap] = await Promise.all([
      Sitter.find({ _id: { $in: [...allUserIds] } })
        .select('name email')
        .lean()
        .then((a) => new Map(a.map((u) => [String(u._id), u]))),
      Owner.find({ _id: { $in: [...allUserIds] } })
        .select('name email')
        .lean()
        .then((a) => new Map(a.map((u) => [String(u._id), u]))),
      Walker.find({ _id: { $in: [...allUserIds] } })
        .select('name email')
        .lean()
        .then((a) => new Map(a.map((u) => [String(u._id), u]))),
    ]);
    const resolveUser = (userId, userModel) => {
      const map =
        userModel === 'Owner'
          ? ownerMap
          : userModel === 'Walker'
          ? walkerMap
          : sitterMap;
      return map.get(String(userId)) || {};
    };

    // Flatten profile + map boost purchases
    const pushBoosts = (arr, role, users) => {
      for (const u of users) {
        for (const p of u.boostPurchases || []) {
          const kind = p.kind || 'profile';
          arr.push({
            userId: u._id,
            userName: u.name,
            userEmail: u.email,
            role,
            product: kind === 'map' ? 'map_boost' : 'profile_boost',
            tier: p.tier,
            amount: p.amount,
            currency: p.currency || 'EUR',
            days: p.days,
            purchasedAt: p.purchasedAt,
            paymentProvider: p.paymentProvider || '-',
            paymentId: p.paymentId || '-',
            currentBoostTier: u.boostTier,
            boostExpiry: u.boostExpiry,
            isActive: u.boostExpiry ? new Date(u.boostExpiry) > now : false,
          });
        }
      }
    };
    let allPurchases = [];
    pushBoosts(allPurchases, 'sitter', sitters);
    pushBoosts(allPurchases, 'owner', owners);
    pushBoosts(allPurchases, 'walker', walkers);

    // Flatten premium subscription payments
    for (const sub of subs) {
      const u = resolveUser(sub.userId, sub.userModel);
      const isActive =
        sub.status === 'active' &&
        sub.currentPeriodEnd &&
        new Date(sub.currentPeriodEnd) > now;
      for (const p of sub.payments || []) {
        allPurchases.push({
          userId: sub.userId,
          userName: u.name || '-',
          userEmail: u.email || '-',
          role: (sub.userModel || '').toLowerCase(),
          product: 'premium',
          tier: p.plan || sub.plan || 'monthly',
          amount: p.amount,
          currency: p.currency || 'EUR',
          days: p.periodStart && p.periodEnd
            ? Math.round(
                (new Date(p.periodEnd) - new Date(p.periodStart)) / 86400000,
              )
            : null,
          purchasedAt: p.paidAt,
          paymentProvider: p.paymentProvider || 'stripe',
          paymentId: p.paymentIntentId || '-',
          isActive,
        });
      }
    }

    // Flatten chat add-on payments
    for (const addon of chatAddons) {
      const u = resolveUser(addon.userId, addon.userModel);
      const isActive =
        addon.status === 'active' &&
        addon.currentPeriodEnd &&
        new Date(addon.currentPeriodEnd) > now;
      for (const p of addon.payments || []) {
        allPurchases.push({
          userId: addon.userId,
          userName: u.name || '-',
          userEmail: u.email || '-',
          role: (addon.userModel || '').toLowerCase(),
          product: 'chat_addon',
          tier: 'monthly',
          amount: p.amount,
          currency: p.currency || 'EUR',
          days: 30,
          purchasedAt: p.paidAt,
          paymentProvider: p.paymentProvider || 'stripe',
          paymentId: p.paymentIntentId || '-',
          isActive,
        });
      }
    }

    // Filter by tier / role / product
    if (tier) allPurchases = allPurchases.filter((p) => p.tier === tier);
    if (role) allPurchases = allPurchases.filter((p) => p.role === role);
    if (product) allPurchases = allPurchases.filter((p) => p.product === product);

    // Sort newest first
    allPurchases.sort(
      (a, b) => new Date(b.purchasedAt || 0) - new Date(a.purchasedAt || 0),
    );

    // Summary stats
    const totalRevenue = allPurchases.reduce((s, p) => s + (p.amount || 0), 0);
    const activeKeys = new Set();
    for (const p of allPurchases) {
      if (p.isActive) activeKeys.add(`${p.product}_${p.role}_${p.userId}`);
    }
    const tierBreakdown = {};
    for (const p of allPurchases) {
      const key = p.tier || 'unknown';
      if (!tierBreakdown[key]) tierBreakdown[key] = { count: 0, revenue: 0 };
      tierBreakdown[key].count++;
      tierBreakdown[key].revenue += p.amount || 0;
    }
    const productBreakdown = {};
    for (const p of allPurchases) {
      const key = p.product || 'unknown';
      if (!productBreakdown[key])
        productBreakdown[key] = { count: 0, revenue: 0 };
      productBreakdown[key].count++;
      productBreakdown[key].revenue += p.amount || 0;
    }

    // Paginate
    const totalCount = allPurchases.length;
    const skip = (Number(page) - 1) * Number(limit);
    const paginated = allPurchases.slice(skip, skip + Number(limit));

    res.json({
      purchases: paginated,
      total: totalCount,
      page: Number(page),
      limit: Number(limit),
      summary: {
        totalRevenue,
        totalPurchases: totalCount,
        activeBoostsCount: activeKeys.size,
        tierBreakdown,
        productBreakdown,
      },
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── PREMIUM SUBSCRIPTIONS — aggregated stats ───────────────────────────────
// GET /admin/subscriptions/stats
// Returns totals per plan and per user role (Owner / Sitter / Walker), plus
// a currency breakdown and the number of currently active subscriptions.
router.get('/subscriptions/stats', requireAdmin, async (req, res) => {
  try {
    const UserSubscription = require('../models/UserSubscription');

    const now = new Date();
    const all = await UserSubscription.find({}).lean();

    const breakdown = {
      active: 0,
      expired: 0,
      canceled: 0,
      pending: 0,
      byPlan: { monthly: 0, yearly: 0, none: 0 },
      byRole: { Owner: 0, Sitter: 0, Walker: 0 },
      byCurrency: {},
      totalRevenueByCurrency: {},
      totalPayments: 0,
    };

    for (const sub of all) {
      const isActive = sub.status === 'active' && sub.currentPeriodEnd && new Date(sub.currentPeriodEnd) > now;
      if (isActive) breakdown.active += 1;
      else if (sub.status === 'expired') breakdown.expired += 1;
      else if (sub.status === 'canceled') breakdown.canceled += 1;
      else breakdown.pending += 1;

      if (breakdown.byPlan[sub.plan] !== undefined) breakdown.byPlan[sub.plan] += 1;
      if (breakdown.byRole[sub.userModel] !== undefined) breakdown.byRole[sub.userModel] += 1;

      for (const p of sub.payments || []) {
        const cur = (p.currency || 'EUR').toUpperCase();
        breakdown.byCurrency[cur] = (breakdown.byCurrency[cur] || 0) + 1;
        breakdown.totalRevenueByCurrency[cur] = +(
          (breakdown.totalRevenueByCurrency[cur] || 0) + (p.amount || 0)
        ).toFixed(2);
        breakdown.totalPayments += 1;
      }
    }

    res.json({ stats: breakdown, totalSubscriptions: all.length });
  } catch (e) {
    logger.error('[admin/subscriptions/stats]', e);
    res.status(500).json({ error: e.message });
  }
});

// GET /admin/subscriptions — paginated list of all subs (latest first)
router.get('/subscriptions', requireAdmin, async (req, res) => {
  try {
    const UserSubscription = require('../models/UserSubscription');
    const page = Math.max(1, parseInt(req.query.page || '1', 10));
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit || '25', 10)));
    const filter = {};
    if (req.query.role && ['Owner', 'Sitter', 'Walker'].includes(req.query.role)) {
      filter.userModel = req.query.role;
    }
    if (req.query.status) filter.status = req.query.status;

    const [items, total] = await Promise.all([
      UserSubscription.find(filter)
        .sort({ updatedAt: -1 })
        .skip((page - 1) * limit)
        .limit(limit)
        .lean(),
      UserSubscription.countDocuments(filter),
    ]);

    res.json({
      items,
      pagination: { page, limit, total, pages: Math.ceil(total / limit) },
    });
  } catch (e) {
    logger.error('[admin/subscriptions]', e);
    res.status(500).json({ error: e.message });
  }
});

// GET /admin/walkers — list walker accounts with boost + premium summary
router.get('/walkers', requireAdmin, async (req, res) => {
  try {
    const Walker = require('../models/Walker');
    const UserSubscription = require('../models/UserSubscription');
    const page = Math.max(1, parseInt(req.query.page || '1', 10));
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit || '25', 10)));

    const [walkers, total] = await Promise.all([
      Walker.find({})
        .sort({ createdAt: -1 })
        .skip((page - 1) * limit)
        .limit(limit)
        .select('-password -paypalEmail -ibanNumber -insuranceCertUrl')
        .lean(),
      Walker.countDocuments(),
    ]);

    // Enrich with subscription status
    const walkerIds = walkers.map((w) => w._id);
    const subs = await UserSubscription.find({
      userModel: 'Walker',
      userId: { $in: walkerIds },
    }).lean();
    const subByUser = new Map(subs.map((s) => [String(s.userId), s]));

    const enriched = walkers.map((w) => {
      const sub = subByUser.get(String(w._id));
      const now = new Date();
      const isPremium = sub && sub.status === 'active' && sub.currentPeriodEnd && new Date(sub.currentPeriodEnd) > now;
      return {
        ...w,
        subscription: sub
          ? {
              plan: sub.plan,
              status: sub.status,
              isPremium,
              currentPeriodEnd: sub.currentPeriodEnd,
              totalPayments: (sub.payments || []).length,
            }
          : null,
      };
    });

    res.json({
      items: enriched,
      pagination: { page, limit, total, pages: Math.ceil(total / limit) },
    });
  } catch (e) {
    logger.error('[admin/walkers]', e);
    res.status(500).json({ error: e.message });
  }
});

// ─── MAP POI MODERATION ────────────────────────────────────────────────────
// GET /admin/map-pois?status=pending|active|rejected
router.get('/map-pois', requireAdmin, async (req, res) => {
  try {
    const MapPOI = require('../models/MapPOI');
    const page = Math.max(1, parseInt(req.query.page || '1', 10));
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit || '25', 10)));
    const filter = {};
    if (req.query.status) filter.status = req.query.status;
    if (req.query.category) filter.category = req.query.category;

    const [items, total] = await Promise.all([
      MapPOI.find(filter)
        .sort({ createdAt: -1 })
        .skip((page - 1) * limit)
        .limit(limit)
        .lean(),
      MapPOI.countDocuments(filter),
    ]);
    res.json({
      items,
      pagination: { page, limit, total, pages: Math.ceil(total / limit) },
    });
  } catch (e) {
    logger.error('[admin/map-pois]', e);
    res.status(500).json({ error: e.message });
  }
});

// POST /admin/map-pois/:id/validate — approve a pending submission
router.post('/map-pois/:id/validate', requireAdmin, async (req, res) => {
  try {
    const MapPOI = require('../models/MapPOI');
    const poi = await MapPOI.findById(req.params.id);
    if (!poi) return res.status(404).json({ error: 'POI not found.' });
    poi.status = 'active';
    poi.validatedBy = req.user.id;
    poi.validatedAt = new Date();
    await poi.save();
    res.json({ poi });
  } catch (e) {
    logger.error('[admin/map-pois/validate]', e);
    res.status(500).json({ error: e.message });
  }
});

// POST /admin/map-pois/:id/reject — reject a pending submission
router.post('/map-pois/:id/reject', requireAdmin, async (req, res) => {
  try {
    const MapPOI = require('../models/MapPOI');
    const poi = await MapPOI.findById(req.params.id);
    if (!poi) return res.status(404).json({ error: 'POI not found.' });
    poi.status = 'rejected';
    poi.rejectionReason = req.body.reason || '';
    poi.validatedBy = req.user.id;
    poi.validatedAt = new Date();
    await poi.save();
    res.json({ poi });
  } catch (e) {
    logger.error('[admin/map-pois/reject]', e);
    res.status(500).json({ error: e.message });
  }
});

// ─── MAP REPORT MODERATION ─────────────────────────────────────────────────
// GET /admin/map-reports?hidden=true|false
router.get('/map-reports', requireAdmin, async (req, res) => {
  try {
    const MapReport = require('../models/MapReport');
    const page = Math.max(1, parseInt(req.query.page || '1', 10));
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit || '25', 10)));
    const filter = {};
    if (req.query.hidden === 'true') filter.hidden = true;
    if (req.query.hidden === 'false') filter.hidden = false;
    if (req.query.type) filter.type = req.query.type;

    const [items, total] = await Promise.all([
      MapReport.find(filter)
        .sort({ createdAt: -1 })
        .skip((page - 1) * limit)
        .limit(limit)
        .lean(),
      MapReport.countDocuments(filter),
    ]);
    res.json({
      items,
      pagination: { page, limit, total, pages: Math.ceil(total / limit) },
    });
  } catch (e) {
    logger.error('[admin/map-reports]', e);
    res.status(500).json({ error: e.message });
  }
});

// DELETE /admin/map-reports/:id — hard-delete (admin override)
router.delete('/map-reports/:id', requireAdmin, async (req, res) => {
  try {
    const MapReport = require('../models/MapReport');
    const r = await MapReport.findByIdAndDelete(req.params.id);
    if (!r) return res.status(404).json({ error: 'Not found.' });
    res.json({ ok: true });
  } catch (e) {
    logger.error('[admin/map-reports/delete]', e);
    res.status(500).json({ error: e.message });
  }
});

// POST /admin/map-reports/:id/restore — unhide a flagged report
router.post('/map-reports/:id/restore', requireAdmin, async (req, res) => {
  try {
    const MapReport = require('../models/MapReport');
    const r = await MapReport.findById(req.params.id);
    if (!r) return res.status(404).json({ error: 'Not found.' });
    r.hidden = false;
    r.flags = []; // clear flag log after moderator review
    await r.save();
    res.json({ ok: true });
  } catch (e) {
    logger.error('[admin/map-reports/restore]', e);
    res.status(500).json({ error: e.message });
  }
});

// ═════════════════════════════════════════════════════════════════════════════
//  PRICING — shop price grid (Boost / Map Boost / Premium) x 4 currencies
// ═════════════════════════════════════════════════════════════════════════════

/**
 * GET /admin/pricing — returns the current pricing grid used by the shop.
 * Shape:
 *   {
 *     pricing: {
 *       boost:    { EUR: {bronze,silver,gold,platinum}, GBP: {...}, CHF: {...}, USD: {...} },
 *       mapBoost: { same shape },
 *       premium:  { EUR: {monthly,yearly}, GBP: {...}, CHF: {...}, USD: {...} }
 *     },
 *     defaults: { same shape },          // what "Reset" would restore to
 *     currencies: ['EUR','GBP','CHF','USD']
 *   }
 */
router.get('/pricing', requireAdmin, (req, res) => {
  try {
    res.json({
      pricing: pricingService.getAll(),
      defaults: pricingService.DEFAULTS,
      currencies: pricingService.CURRENCIES,
    });
  } catch (e) {
    logger.error('[admin/pricing:get]', e);
    res.status(500).json({ error: e.message });
  }
});

/**
 * PATCH /admin/pricing — partial update of the pricing grid.
 * Accepts the same shape as GET.pricing; only provided keys are updated.
 * Example body:
 *   { "boost": { "EUR": { "bronze": 5.99 } } }
 */
router.patch('/pricing', requireAdmin, async (req, res) => {
  try {
    const patch = req.body || {};
    const updated = await pricingService.update(patch);
    res.json({ ok: true, pricing: updated });
  } catch (e) {
    logger.warn('[admin/pricing:patch]', e);
    res.status(400).json({ error: e.message });
  }
});

/**
 * POST /admin/pricing/reset — wipes any admin customizations and restores the
 * hardcoded defaults. Useful if the grid gets fat-fingered.
 */
router.post('/pricing/reset', requireAdmin, async (req, res) => {
  try {
    const restored = await pricingService.resetToDefaults();
    res.json({ ok: true, pricing: restored });
  } catch (e) {
    logger.error('[admin/pricing:reset]', e);
    res.status(500).json({ error: e.message });
  }
});

// ═════════════════════════════════════════════════════════════════════════════
//  ANNONCES (Post) MODERATION — list, ban/unban, hard-delete a reservation
//  request. Uses soft-delete (hidden=true) by default so the post remains
//  in the DB for audit + data history; hard-delete is reserved for clearly
//  malicious content.
// ═════════════════════════════════════════════════════════════════════════════

router.get('/posts', requireAdmin, async (req, res) => {
  try {
    const Post = require('../models/Post');
    const {
      page = 1,
      limit = 30,
      status = 'all',     // all | live | banned
      postType,           // request | media
      q,                  // search in body
    } = req.query;

    const filter = {};
    if (status === 'live') filter.hidden = { $ne: true };
    if (status === 'banned') filter.hidden = true;
    if (postType) filter.postType = postType;
    if (q && q.trim().length > 0) {
      filter.body = { $regex: q.trim(), $options: 'i' };
    }

    const pageNum = Math.max(1, parseInt(page, 10));
    const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10)));
    const skip = (pageNum - 1) * limitNum;

    const [rows, total] = await Promise.all([
      Post.find(filter)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limitNum)
        .populate('ownerId', 'name email avatar')
        .lean(),
      Post.countDocuments(filter),
    ]);

    const posts = rows.map((p) => ({
      id: p._id.toString(),
      postType: p.postType,
      body: p.body,
      serviceTypes: p.serviceTypes || [],
      serviceLocation: p.serviceLocation,
      startDate: p.startDate,
      endDate: p.endDate,
      city: p.location?.city || '',
      owner: {
        id: p.ownerId?._id?.toString() || '',
        name: p.ownerId?.name || '',
        email: p.ownerId?.email || '',
        avatar: p.ownerId?.avatar?.url || '',
      },
      hidden: p.hidden === true,
      bannedAt: p.bannedAt,
      bannedBy: p.bannedBy,
      bannedReason: p.bannedReason,
      moderationNote: p.moderationNote,
      createdAt: p.createdAt,
    }));

    res.json({
      posts,
      total,
      page: pageNum,
      limit: limitNum,
      pages: Math.ceil(total / limitNum),
    });
  } catch (e) {
    logger.error('[admin/posts:get]', e);
    res.status(500).json({ error: e.message });
  }
});

router.post('/posts/:id/ban', requireAdmin, async (req, res) => {
  try {
    const Post = require('../models/Post');
    const { reason = '', note = '' } = req.body || {};
    const p = await Post.findById(req.params.id);
    if (!p) return res.status(404).json({ error: 'Post not found.' });

    p.hidden = true;
    p.bannedAt = new Date();
    p.bannedBy = req.user?.email || req.user?.id || 'admin';
    p.bannedReason = String(reason).slice(0, 500);
    if (note) p.moderationNote = String(note).slice(0, 1000);
    await p.save();

    res.json({ ok: true, postId: p._id.toString(), bannedAt: p.bannedAt });
  } catch (e) {
    logger.error('[admin/posts/ban]', e);
    res.status(500).json({ error: e.message });
  }
});

router.post('/posts/:id/unban', requireAdmin, async (req, res) => {
  try {
    const Post = require('../models/Post');
    const p = await Post.findById(req.params.id);
    if (!p) return res.status(404).json({ error: 'Post not found.' });
    p.hidden = false;
    p.bannedAt = null;
    p.bannedBy = '';
    p.bannedReason = '';
    await p.save();
    res.json({ ok: true, postId: p._id.toString() });
  } catch (e) {
    logger.error('[admin/posts/unban]', e);
    res.status(500).json({ error: e.message });
  }
});

router.delete('/posts/:id', requireAdmin, async (req, res) => {
  try {
    const Post = require('../models/Post');
    const p = await Post.findByIdAndDelete(req.params.id);
    if (!p) return res.status(404).json({ error: 'Post not found.' });
    res.json({ ok: true, deleted: p._id.toString() });
  } catch (e) {
    logger.error('[admin/posts/delete]', e);
    res.status(500).json({ error: e.message });
  }
});

// ═════════════════════════════════════════════════════════════════════════════
//  PAWMAP AGGREGATED STATS — admin dashboard for map POIs + reports.
//  Returns counts grouped by category / type, live vs expired, and recent
//  activity trend so admin can monitor community contributions. Post-TTL-
//  removal, all historical reports are kept in the DB — the "expired" bucket
//  is the bulk of the dataset (future data treasure per Daniel's ask).
// ═════════════════════════════════════════════════════════════════════════════

// ── Seed controls (OSM import) ──────────────────────────────────────────────
// Populates the mappois collection from OpenStreetMap via Overpass. Runs
// async in the background (Overpass can take 60-120s per country × category
// so we never wait on the HTTP response).

router.get('/pawmap/seed/countries', requireAdmin, (req, res) => {
  res.json({
    countries: mapPoiSeedService.ALL_EU_COUNTRIES,
    categories: Object.keys(mapPoiSeedService.CATEGORY_TAGS),
    bboxes: mapPoiSeedService.COUNTRY_BBOX,
  });
});

router.post('/pawmap/seed', requireAdmin, (req, res) => {
  try {
    const { country, categories, limit } = req.body || {};
    if (!country) return res.status(400).json({ error: 'Missing country.' });
    const jobId = mapPoiSeedService.runSeed({
      country,
      categories: Array.isArray(categories) ? categories : null,
      limit: limit ? parseInt(limit, 10) : null,
    });
    res.json({ ok: true, jobId });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

router.post('/pawmap/seed/batch', requireAdmin, (req, res) => {
  try {
    const { countries, categories, limit } = req.body || {};
    const jobId = mapPoiSeedService.runSeedBatch({
      countries: Array.isArray(countries) ? countries : null, // null = ALL EU
      categories: Array.isArray(categories) ? categories : null,
      limit: limit ? parseInt(limit, 10) : null,
    });
    res.json({ ok: true, jobId });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

router.get('/pawmap/seed/jobs', requireAdmin, (req, res) => {
  res.json({ jobs: mapPoiSeedService.listJobs() });
});

router.get('/pawmap/seed/jobs/:jobId', requireAdmin, (req, res) => {
  const job = mapPoiSeedService.getJobStatus(req.params.jobId);
  if (!job) return res.status(404).json({ error: 'Job not found.' });
  res.json({ job });
});

router.get('/pawmap/stats', requireAdmin, async (req, res) => {
  try {
    const MapPOI = require('../models/MapPOI');
    const MapReport = require('../models/MapReport');
    const now = new Date();
    const last7d = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

    // POIs: group by category + moderation status.
    const [poiByCategory, poiByStatus, poiTotal] = await Promise.all([
      MapPOI.aggregate([
        { $group: { _id: '$category', count: { $sum: 1 } } },
        { $sort: { count: -1 } },
      ]),
      MapPOI.aggregate([
        { $group: { _id: '$moderationStatus', count: { $sum: 1 } } },
      ]),
      MapPOI.countDocuments(),
    ]);

    // Reports: group by type + live/expired/hidden breakdown.
    const [
      reportByType,
      reportTotal,
      reportLive,
      reportExpired,
      reportHidden,
      reportLast7d,
    ] = await Promise.all([
      MapReport.aggregate([
        {
          $group: {
            _id: '$type',
            total: { $sum: 1 },
            live: {
              $sum: {
                $cond: [
                  { $and: [{ $gt: ['$expiresAt', now] }, { $ne: ['$hidden', true] }] },
                  1,
                  0,
                ],
              },
            },
            expired: {
              $sum: { $cond: [{ $lte: ['$expiresAt', now] }, 1, 0] },
            },
            hidden: {
              $sum: { $cond: [{ $eq: ['$hidden', true] }, 1, 0] },
            },
          },
        },
        { $sort: { total: -1 } },
      ]),
      MapReport.countDocuments(),
      MapReport.countDocuments({ expiresAt: { $gt: now }, hidden: false }),
      MapReport.countDocuments({ expiresAt: { $lte: now } }),
      MapReport.countDocuments({ hidden: true }),
      MapReport.countDocuments({ createdAt: { $gte: last7d } }),
    ]);

    // Cities with the most reports (top 10) — useful to spot active zones.
    const topCities = await MapReport.aggregate([
      { $match: { 'location.city': { $ne: '' } } },
      { $group: { _id: '$location.city', count: { $sum: 1 } } },
      { $sort: { count: -1 } },
      { $limit: 10 },
    ]);

    res.json({
      pois: {
        total: poiTotal,
        byCategory: poiByCategory.map((x) => ({
          category: x._id,
          count: x.count,
        })),
        byStatus: poiByStatus.map((x) => ({
          status: x._id || 'unknown',
          count: x.count,
        })),
      },
      reports: {
        total: reportTotal,
        live: reportLive,
        expired: reportExpired,
        hidden: reportHidden,
        last7d: reportLast7d,
        byType: reportByType.map((x) => ({
          type: x._id,
          total: x.total,
          live: x.live,
          expired: x.expired,
          hidden: x.hidden,
        })),
      },
      topReportCities: topCities.map((x) => ({
        city: x._id,
        count: x.count,
      })),
    });
  } catch (e) {
    logger.error('[admin/pawmap/stats]', e);
    res.status(500).json({ error: e.message });
  }
});

// ═════════════════════════════════════════════════════════════════════════════
//  SERVICE CATALOG — bookable services (dog_walking / day_care / pet_sitting)
//  + duration presets for Promenade / Sortie longue
// ═════════════════════════════════════════════════════════════════════════════

router.get('/services', requireAdmin, (req, res) => {
  try {
    res.json({
      catalog: serviceCatalogService.getAll(),
      defaults: serviceCatalogService.DEFAULTS,
      serviceKeys: serviceCatalogService.SERVICE_KEYS,
      languages: serviceCatalogService.SUPPORTED_LANGS,
    });
  } catch (e) {
    logger.error('[admin/services:get]', e);
    res.status(500).json({ error: e.message });
  }
});

router.patch('/services', requireAdmin, async (req, res) => {
  try {
    const updated = await serviceCatalogService.update(req.body || {});
    res.json({ ok: true, catalog: updated });
  } catch (e) {
    logger.warn('[admin/services:patch]', e);
    res.status(400).json({ error: e.message });
  }
});

router.post('/services/reset', requireAdmin, async (req, res) => {
  try {
    const restored = await serviceCatalogService.resetToDefaults();
    res.json({ ok: true, catalog: restored });
  } catch (e) {
    logger.error('[admin/services:reset]', e);
    res.status(500).json({ error: e.message });
  }
});

// ─── v18.9.8 — IBAN Manual Payouts (Mark as Paid) ───────────────────────────
// Liste des bookings en attente de virement manuel (payoutStatus =
// 'pending_manual_transfer'). Ces bookings ont été payées par l'owner mais
// le provider reçoit par IBAN → transfer à faire à la main côté admin.
router.get('/iban-payouts/pending', requireAdmin, async (req, res) => {
  try {
    const bookings = await Booking.find({
      payoutStatus: 'pending_manual_transfer',
    })
      .sort({ 'manualPayoutDetails.queuedAt': 1 })
      .populate('ownerId', 'name email')
      .populate('sitterId', 'name email ibanHolder ibanNumber ibanBic')
      .populate('walkerId', 'name email ibanHolder ibanNumber ibanBic')
      .limit(200)
      .lean();

    const items = bookings.map((b) => {
      const provider = b.walkerId || b.sitterId;
      return {
        bookingId: b._id,
        providerName: provider?.name || '-',
        providerEmail: provider?.email || '-',
        providerRole: b.walkerId ? 'walker' : 'sitter',
        ownerName: b.ownerId?.name || '-',
        amount: b.manualPayoutDetails?.amount ?? b.pricing?.netPayout ?? 0,
        currency: b.manualPayoutDetails?.currency || b.pricing?.currency || 'EUR',
        ibanHolder: b.manualPayoutDetails?.holderName || provider?.ibanHolder || '-',
        ibanMasked: b.manualPayoutDetails?.ibanMasked || '-',
        ibanBic: b.manualPayoutDetails?.bic || provider?.ibanBic || '-',
        queuedAt: b.manualPayoutDetails?.queuedAt || b.updatedAt,
        serviceType: b.serviceType || '',
      };
    });

    res.json({
      count: items.length,
      totalPending: items.reduce((s, i) => s + (i.amount || 0), 0),
      items,
    });
  } catch (e) {
    logger.error('[admin/iban-payouts/pending]', e);
    res.status(500).json({ error: e.message });
  }
});

// Marque un booking comme payé manuellement. On passe payoutStatus de
// 'pending_manual_transfer' → 'completed' et on stocke payoutAt + optionnel
// reference (numéro de virement SEPA pour trace).
router.post(
  '/iban-payouts/:bookingId/mark-paid',
  requireAdmin,
  async (req, res) => {
    try {
      const { bookingId } = req.params;
      const { reference } = req.body || {};
      const booking = await Booking.findById(bookingId);
      if (!booking) {
        return res.status(404).json({ error: 'Booking not found.' });
      }
      if (booking.payoutStatus !== 'pending_manual_transfer') {
        return res.status(400).json({
          error: `Booking is not in pending_manual_transfer state (current: ${booking.payoutStatus}).`,
        });
      }
      booking.payoutStatus = 'completed';
      booking.payoutAt = new Date();
      if (reference && typeof reference === 'string') {
        booking.manualPayoutDetails = {
          ...(booking.manualPayoutDetails || {}),
          paidReference: reference.trim(),
          paidAt: new Date(),
        };
      }
      await booking.save();
      res.json({
        ok: true,
        bookingId: booking._id,
        payoutStatus: booking.payoutStatus,
        payoutAt: booking.payoutAt,
      });
    } catch (e) {
      logger.error('[admin/iban-payouts/mark-paid]', e);
      res.status(500).json({ error: e.message });
    }
  },
);

// ─── v19.0 — Wallet withdrawals pending (Mark as Paid) ──────────────────────
// Comme les bookings manual transfers mais pour les retraits wallet déclenchés
// par le provider. Même flow : admin voit les pending, exécute SEPA/PayPal,
// clique Mark as Paid → transaction passe de pending à completed.
const WalletTransaction = require('../models/WalletTransaction');
const SitterModel = require('../models/Sitter');
const WalkerModel = require('../models/Walker');

router.get('/wallet/withdrawals/pending', requireAdmin, async (req, res) => {
  try {
    const items = await WalletTransaction.find({
      type: 'debit_withdrawal',
      status: 'pending',
    })
      .sort({ createdAt: 1 })
      .limit(200)
      .lean();

    // Hydrate les infos user (nom, email, IBAN/PayPal).
    const hydrated = await Promise.all(
      items.map(async (tx) => {
        const Model = tx.userRole === 'walker' ? WalkerModel : SitterModel;
        const u = await Model.findById(tx.userId).select(
          'name email ibanHolder ibanNumber ibanBic paypalEmail',
        );
        return {
          transactionId: tx._id,
          userId: tx.userId,
          userRole: tx.userRole,
          userName: u?.name || '-',
          userEmail: u?.email || '-',
          amount: tx.amount,
          currency: tx.currency,
          method: tx.withdrawalMethod,
          ibanHolder: u?.ibanHolder || '-',
          ibanBic: u?.ibanBic || '-',
          paypalEmail: u?.paypalEmail || '-',
          queuedAt: tx.createdAt,
        };
      }),
    );

    res.json({
      count: hydrated.length,
      totalPending: hydrated.reduce((s, i) => s + i.amount, 0),
      items: hydrated,
    });
  } catch (e) {
    logger.error('[admin/wallet/withdrawals/pending]', e);
    res.status(500).json({ error: e.message });
  }
});

router.post(
  '/wallet/withdrawals/:transactionId/mark-paid',
  requireAdmin,
  async (req, res) => {
    try {
      const tx = await WalletTransaction.findById(req.params.transactionId);
      if (!tx) {
        return res.status(404).json({ error: 'Transaction not found.' });
      }
      if (tx.type !== 'debit_withdrawal' || tx.status !== 'pending') {
        return res.status(400).json({
          error: `Transaction is not a pending withdrawal (${tx.type}/${tx.status}).`,
        });
      }
      tx.status = 'completed';
      tx.completedAt = new Date();
      if (req.body?.reference && typeof req.body.reference === 'string') {
        tx.referenceId = req.body.reference.trim();
      }
      await tx.save();
      res.json({
        ok: true,
        transactionId: tx._id,
        status: tx.status,
        completedAt: tx.completedAt,
      });
    } catch (e) {
      logger.error('[admin/wallet/withdrawals/mark-paid]', e);
      res.status(500).json({ error: e.message });
    }
  },
);

// ============================================================================
// v19.1.3 - Chat moderation panel
// ============================================================================
const Message = require('../models/Message');
const Conversation = require('../models/Conversation');

// GET /admin/conversations — list recent conversations with metadata
router.get('/conversations', requireAdmin, async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit, 10) || 100, 500);
    const rows = await Conversation.find({})
      .sort({ lastMessageAt: -1, updatedAt: -1 })
      .limit(limit)
      .lean();
    res.json({
      conversations: rows.map((c) => ({
        id: c._id.toString(),
        ownerId: c.ownerId ? c.ownerId.toString() : null,
        sitterId: c.sitterId ? c.sitterId.toString() : null,
        walkerId: c.walkerId ? c.walkerId.toString() : null,
        lastMessage: c.lastMessage || '',
        lastMessageAt: c.lastMessageAt || c.updatedAt,
        ownerUnreadCount: c.ownerUnreadCount || 0,
        sitterUnreadCount: c.sitterUnreadCount || 0,
        walkerUnreadCount: c.walkerUnreadCount || 0,
      })),
    });
  } catch (e) {
    logger.error('[admin/conversations]', e);
    res.status(500).json({ error: e.message });
  }
});

// GET /admin/conversations/:id/messages — full message history for moderation
// (includes soft-deleted messages so admins can audit content that was hidden
// from end users).
router.get('/conversations/:id/messages', requireAdmin, async (req, res) => {
  try {
    const messages = await Message.find({ conversationId: req.params.id })
      .sort({ createdAt: 1 })
      .lean();
    res.json({
      messages: messages.map((m) => ({
        id: m._id.toString(),
        conversationId: m.conversationId.toString(),
        senderRole: m.senderRole,
        senderId: m.senderId ? m.senderId.toString() : null,
        body: m.body || '',
        attachments: m.attachments || [],
        type: m.type || 'text',
        createdAt: m.createdAt,
        deletedAt: m.deletedAt || null,
        deletedBy: m.deletedBy || null,
      })),
    });
  } catch (e) {
    logger.error('[admin/conversation/messages]', e);
    res.status(500).json({ error: e.message });
  }
});

// v19.1.3 — Admin Wallet overview. Lists provider wallet balances joined
// with Stripe Connect account status so admin can audit who has money
// waiting vs. who has auto-managed payouts enabled.
router.get('/wallets', requireAdmin, async (req, res) => {
  try {
    const Sitter = require('../models/Sitter');
    const Walker = require('../models/Walker');
    const [sitters, walkers] = await Promise.all([
      Sitter.find({ walletBalance: { $gt: 0 } })
        .select('name email walletBalance walletCurrency stripeAccountId stripePayoutsEnabled')
        .limit(200)
        .lean(),
      Walker.find({ walletBalance: { $gt: 0 } })
        .select('name email walletBalance walletCurrency stripeAccountId stripePayoutsEnabled')
        .limit(200)
        .lean(),
    ]);
    const rows = [
      ...sitters.map((s) => ({ role: 'sitter', ...s, id: s._id.toString() })),
      ...walkers.map((w) => ({ role: 'walker', ...w, id: w._id.toString() })),
    ].sort((a, b) => (b.walletBalance || 0) - (a.walletBalance || 0));

    const totalBalance = rows.reduce((sum, r) => sum + (r.walletBalance || 0), 0);
    const connectedCount = rows.filter((r) => !!r.stripeAccountId).length;

    res.json({
      wallets: rows,
      summary: {
        totalBalance: Math.round(totalBalance * 100) / 100,
        providerCount: rows.length,
        stripeConnectedCount: connectedCount,
      },
    });
  } catch (e) {
    logger.error('[admin/wallets]', e);
    res.status(500).json({ error: e.message });
  }
});

router.delete('/messages/:id', requireAdmin, async (req, res) => {
  try {
    const msg = await Message.findById(req.params.id);
    if (!msg) return res.status(404).json({ error: 'Message not found.' });
    if (!msg.deletedAt) {
      msg.deletedAt = new Date();
      msg.deletedBy = 'admin';
      await msg.save();
    }
    try {
      const { emitToConversation } = require('../sockets/emitter');
      emitToConversation(msg.conversationId.toString(), 'message:deleted', {
        conversationId: msg.conversationId.toString(),
        messageId: msg._id.toString(),
      });
    } catch (_) {}
    res.json({ deleted: true, messageId: msg._id.toString() });
  } catch (e) {
    logger.error('[admin/messages/delete]', e);
    res.status(500).json({ error: e.message });
  }
});

// v19.1.5 — Toggle isStaff flag on a user (owner/sitter/walker). Staff users
// get Premium + Chat + all paywalls bypassed for free. Reserved to Daniel
// (platform owner) and HoPetSit employees.
router.post('/users/:role/:id/staff', requireAdmin, async (req, res) => {
  try {
    const { role, id } = req.params;
    const { isStaff } = req.body || {};
    const Model = role === 'sitter'
      ? require('../models/Sitter')
      : role === 'walker'
        ? require('../models/Walker')
        : role === 'owner'
          ? require('../models/Owner')
          : null;
    if (!Model) return res.status(400).json({ error: 'Invalid role.' });
    const updated = await Model.findByIdAndUpdate(
      id,
      { $set: { isStaff: !!isStaff } },
      { new: true },
    ).select('name email isStaff');
    if (!updated) return res.status(404).json({ error: 'User not found.' });
    logger.info(`[admin] ${role} ${id} isStaff=${!!isStaff}`);
    res.json({
      id: updated._id.toString(),
      name: updated.name,
      email: updated.email,
      isStaff: updated.isStaff,
    });
  } catch (e) {
    logger.error('[admin/users/staff]', e);
    res.status(500).json({ error: e.message });
  }
});

// v20 — Loyalty stats for the admin "Avantages" tab.
// Returns counts + top lists for: owners with isPremium (10+ bookings),
// sitters with isTopSitter (20+ completed + 4.5 rating), walkers with isTopWalker.
router.get('/loyalty', requireAdmin, async (req, res) => {
  try {
    const Owner = require('../models/Owner');
    const Sitter = require('../models/Sitter');
    const Walker = require('../models/Walker');

    const [ownersPremium, sittersTop, walkersTop,
           ownerTotal, sitterTotal, walkerTotal] = await Promise.all([
      Owner.find({ isPremium: true })
        .select('name email createdAt')
        .sort({ createdAt: -1 })
        .limit(200)
        .lean(),
      Sitter.find({ isTopSitter: true })
        .select('name email completedServicesCount averageRating createdAt')
        .sort({ averageRating: -1, completedServicesCount: -1 })
        .limit(200)
        .lean(),
      Walker.find({ isTopWalker: true })
        .select('name email completedWalksCount averageRating createdAt')
        .sort({ averageRating: -1, completedWalksCount: -1 })
        .limit(200)
        .lean(),
      Owner.countDocuments({}),
      Sitter.countDocuments({}),
      Walker.countDocuments({}),
    ]);

    res.json({
      summary: {
        ownerTotal,
        sitterTotal,
        walkerTotal,
        ownersPremiumCount: ownersPremium.length,
        sittersTopCount: sittersTop.length,
        walkersTopCount: walkersTop.length,
      },
      ownersPremium: ownersPremium.map((o) => ({
        id: o._id.toString(), name: o.name, email: o.email, createdAt: o.createdAt,
      })),
      sittersTop: sittersTop.map((s) => ({
        id: s._id.toString(), name: s.name, email: s.email,
        completed: s.completedServicesCount || 0,
        rating: s.averageRating || 0,
      })),
      walkersTop: walkersTop.map((w) => ({
        id: w._id.toString(), name: w.name, email: w.email,
        completed: w.completedWalksCount || 0,
        rating: w.averageRating || 0,
      })),
    });
  } catch (e) {
    logger.error('[admin/loyalty]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── v20.0.8 — BUG REPORTS ─────────────────────────────────────────────────────
const BugReport = require('../models/BugReport');

router.get('/bug-reports', requireAdmin, async (req, res) => {
  try {
    const { status } = req.query;
    const filter = status ? { status } : {};
    const [reports, openCount, totalCount] = await Promise.all([
      BugReport.find(filter).sort({ createdAt: -1 }).limit(300).lean(),
      BugReport.countDocuments({ status: 'open' }),
      BugReport.countDocuments({}),
    ]);
    res.json({ reports, openCount, totalCount });
  } catch (e) {
    logger.error('[admin/bug-reports]', e);
    res.status(500).json({ error: e.message });
  }
});

router.patch('/bug-reports/:id', requireAdmin, async (req, res) => {
  try {
    const { status, adminNote } = req.body || {};
    const update = {};
    if (status) update.status = status;
    if (typeof adminNote === 'string') update.adminNote = adminNote;
    const doc = await BugReport.findByIdAndUpdate(req.params.id, update, {
      new: true,
    });
    if (!doc) return res.status(404).json({ error: 'Report not found.' });
    res.json({ report: doc });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.delete('/bug-reports/:id', requireAdmin, async (req, res) => {
  try {
    await BugReport.findByIdAndDelete(req.params.id);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ── v20.0.8 — PLATFORM PAYOUTS / REVENUE ─────────────────────────────────────
router.get('/payouts', requireAdmin, async (req, res) => {
  try {
    const Subscription = require('../models/UserSubscription');
    let Donation = null;
    try { Donation = require('../models/Donation'); } catch (_) {}

    const now = new Date();
    const start30d = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    const start7d = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const startMonth = new Date(now.getFullYear(), now.getMonth(), 1);

    const [agg, last30Agg, last7Agg, monthAgg] = await Promise.all([
      Booking.aggregate([
        { $match: { paymentStatus: 'paid' } },
        { $group: {
            _id: null,
            totalGross: { $sum: { $ifNull: ['$totalAmount', 0] } },
            totalCommission: { $sum: { $ifNull: ['$commissionAmount', 0] } },
            count: { $sum: 1 },
        } },
      ]),
      Booking.aggregate([
        { $match: { paymentStatus: 'paid', paidAt: { $gte: start30d } } },
        { $group: { _id: null, commission: { $sum: { $ifNull: ['$commissionAmount', 0] } }, count: { $sum: 1 } } },
      ]),
      Booking.aggregate([
        { $match: { paymentStatus: 'paid', paidAt: { $gte: start7d } } },
        { $group: { _id: null, commission: { $sum: { $ifNull: ['$commissionAmount', 0] } }, count: { $sum: 1 } } },
      ]),
      Booking.aggregate([
        { $match: { paymentStatus: 'paid', paidAt: { $gte: startMonth } } },
        { $group: { _id: null, commission: { $sum: { $ifNull: ['$commissionAmount', 0] } }, count: { $sum: 1 } } },
      ]),
    ]);

    const subAgg = await Subscription.aggregate([
      { $unwind: { path: '$payments', preserveNullAndEmptyArrays: false } },
      { $group: { _id: null, total: { $sum: { $ifNull: ['$payments.amount', 0] } }, count: { $sum: 1 } } },
    ]);

    let donationsTotal = 0; let donationsCount = 0;
    if (Donation) {
      try {
        const dAgg = await Donation.aggregate([
          { $match: { status: 'succeeded' } },
          { $group: { _id: null, total: { $sum: { $ifNull: ['$amount', 0] } }, count: { $sum: 1 } } },
        ]);
        donationsTotal = dAgg[0]?.total || 0;
        donationsCount = dAgg[0]?.count || 0;
      } catch (_) {}
    }

    const a = agg[0] || {};
    const commissionAllTime = a.totalCommission || 0;
    const subscriptionAllTime = subAgg[0]?.total || 0;
    const platformRevenue = commissionAllTime + subscriptionAllTime + donationsTotal;

    res.json({
      summary: {
        platformRevenue,
        commissionAllTime,
        subscriptionAllTime,
        donationsTotal,
        bookingCount: a.count || 0,
        subscriptionPaymentCount: subAgg[0]?.count || 0,
        donationsCount,
      },
      bookings: {
        grossAllTime: a.totalGross || 0,
        commissionAllTime,
        count: a.count || 0,
        last7d: { commission: last7Agg[0]?.commission || 0, count: last7Agg[0]?.count || 0 },
        last30d: { commission: last30Agg[0]?.commission || 0, count: last30Agg[0]?.count || 0 },
        thisMonth: { commission: monthAgg[0]?.commission || 0, count: monthAgg[0]?.count || 0 },
      },
    });
  } catch (e) {
    logger.error('[admin/payouts]', e);
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
