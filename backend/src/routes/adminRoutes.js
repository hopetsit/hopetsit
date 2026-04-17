const express = require('express');
const { retryBookingPayout } = require('../controllers/bookingController');
const { requireAuth, requireRole } = require('../middleware/auth');
const Booking = require('../models/Booking');
const Sitter = require('../models/Sitter');
const Owner = require('../models/Owner');
const Pet = require('../models/Pet');
const { decrypt } = require('../utils/encryption');
const { sendTestEmail } = require('../services/emailService');
const pricingService = require('../services/pricingService');
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

// Sprint 5 step 7 — identity verification admin review
router.get('/identity-verifications', requireAdmin, async (req, res) => {
  try {
    const { status = 'pending' } = req.query;
    const sitters = await Sitter.find({ 'identityVerification.status': status })
      .select('name identityVerification')
      .sort({ 'identityVerification.submittedAt': -1 })
      .lean();
    const payload = sitters.map((s) => ({
      id: s._id.toString(),
      name: s.name,
      submittedAt: s.identityVerification?.submittedAt || null,
      status: s.identityVerification?.status || 'none',
      documentUrl: s.identityVerification?.documentUrl
        ? decrypt(s.identityVerification.documentUrl)
        : '',
    }));
    res.json({ verifications: payload });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Sprint 7 step 5 — review moderation.
const Review = require('../models/Review');

// Sprint 7 step 6 — platform stats + user moderation.
router.get('/platform-stats', requireAdmin, async (req, res) => {
  try {
    const [totalOwners, totalSitters, totalBookings, totalBookingsCompleted, premiumCount, topSitterCount, revAgg] = await Promise.all([
      Owner.countDocuments(),
      Sitter.countDocuments(),
      Booking.countDocuments(),
      Booking.countDocuments({ status: 'completed' }),
      Owner.countDocuments({ isPremium: true }),
      Sitter.countDocuments({ isTopSitter: true }),
      Booking.aggregate([
        { $match: { paymentStatus: 'paid' } },
        { $group: { _id: null, total: { $sum: '$pricing.commission' } } },
      ]).catch(() => []),
    ]);
    res.json({
      totalUsers: totalOwners + totalSitters,
      totalOwners,
      totalSitters,
      totalBookings,
      totalBookingsCompleted,
      premiumCount,
      topSitterCount,
      platformRevenue: revAgg?.[0]?.total ?? 0,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

const userModelFor = (role) => (role === 'sitter' ? Sitter : role === 'owner' ? Owner : null);

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
    const sitter = await Sitter.findByIdAndUpdate(req.params.id, { $set: update }, { new: true })
      .select('identityVerification');
    if (!sitter) return res.status(404).json({ error: 'Sitter not found.' });
    res.json({
      status: sitter.identityVerification.status,
      reviewedAt: sitter.identityVerification.reviewedAt,
      rejectionReason: sitter.identityVerification.rejectionReason,
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
// Aggregates all boost purchases from both Sitter and Owner collections.
router.get('/boosts', requireAdmin, async (req, res) => {
  try {
    const { page = 1, limit = 30, tier, role } = req.query;
    const now = new Date();

    // Fetch boost purchases from both collections
    const [sitters, owners] = await Promise.all([
      Sitter.find({ 'boostPurchases.0': { $exists: true } })
        .select('name email boostExpiry boostTier boostPurchases')
        .lean(),
      Owner.find({ 'boostPurchases.0': { $exists: true } })
        .select('name email boostExpiry boostTier boostPurchases')
        .lean(),
    ]);

    // Flatten all purchases into a single list
    let allPurchases = [];
    for (const s of sitters) {
      for (const p of (s.boostPurchases || [])) {
        allPurchases.push({
          userId: s._id,
          userName: s.name,
          userEmail: s.email,
          role: 'sitter',
          tier: p.tier,
          amount: p.amount,
          currency: p.currency || 'EUR',
          days: p.days,
          purchasedAt: p.purchasedAt,
          paymentProvider: p.paymentProvider || '-',
          paymentId: p.paymentId || '-',
          currentBoostTier: s.boostTier,
          boostExpiry: s.boostExpiry,
          isActive: s.boostExpiry ? new Date(s.boostExpiry) > now : false,
        });
      }
    }
    for (const o of owners) {
      for (const p of (o.boostPurchases || [])) {
        allPurchases.push({
          userId: o._id,
          userName: o.name,
          userEmail: o.email,
          role: 'owner',
          tier: p.tier,
          amount: p.amount,
          currency: p.currency || 'EUR',
          days: p.days,
          purchasedAt: p.purchasedAt,
          paymentProvider: p.paymentProvider || '-',
          paymentId: p.paymentId || '-',
          currentBoostTier: o.boostTier,
          boostExpiry: o.boostExpiry,
          isActive: o.boostExpiry ? new Date(o.boostExpiry) > now : false,
        });
      }
    }

    // Filter by tier / role
    if (tier) allPurchases = allPurchases.filter(p => p.tier === tier);
    if (role) allPurchases = allPurchases.filter(p => p.role === role);

    // Sort newest first
    allPurchases.sort((a, b) => new Date(b.purchasedAt) - new Date(a.purchasedAt));

    // Summary stats
    const totalRevenue = allPurchases.reduce((s, p) => s + (p.amount || 0), 0);
    const activeBoosts = new Set();
    for (const p of allPurchases) {
      if (p.isActive) activeBoosts.add(`${p.role}_${p.userId}`);
    }
    const tierBreakdown = {};
    for (const p of allPurchases) {
      if (!tierBreakdown[p.tier]) tierBreakdown[p.tier] = { count: 0, revenue: 0 };
      tierBreakdown[p.tier].count++;
      tierBreakdown[p.tier].revenue += p.amount || 0;
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
        activeBoostsCount: activeBoosts.size,
        tierBreakdown,
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

module.exports = router;
