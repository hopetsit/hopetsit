/**
 * Diagnostic routes — v23.1 part 229.
 *
 * Daniel : "chat revient erreur 403 ... cherche en profondeur".
 * Plutot que de patcher a l'aveugle, on expose ICI des endpoints qui
 * retournent l'etat INTERNE des decisions backend pour qu'on puisse
 * voir EXACTEMENT pourquoi un user est bloque (ou ouvert).
 *
 * Tous les endpoints sont requireAuth (sauf /version qui est public).
 */
const express = require('express');
const { requireAuth } = require('../middleware/auth');
const logger = require('../utils/logger');

const router = express.Router();

const Conversation = require('../models/Conversation');
const Booking = require('../models/Booking');
const UserSubscription = require('../models/UserSubscription');
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const { hasActivePawFollow, isInSameFamily } = require('../models/UserSubscription');

// ── /version — public — confirms which commit is currently deployed ────────
router.get('/version', (req, res) => {
  res.json({
    version: 'v23.1.229',
    commitTag: process.env.RENDER_GIT_COMMIT || process.env.GIT_COMMIT || 'unknown',
    branch: process.env.RENDER_GIT_BRANCH || 'main',
    deployedAt: process.env.RENDER_INSTANCE_LAUNCH_TIME || new Date().toISOString(),
    nodeEnv: process.env.NODE_ENV || 'unknown',
    serverTime: new Date().toISOString(),
  });
});

// ── /chat-access/:convId — auth — explains the EXACT chat 403 decision ──
//
// Returns JSON with every bypass step's verdict. Daniel hit this URL with
// the conversation ID where chat returns 403 → JSON tells him why.
router.get('/chat-access/:convId', requireAuth, async (req, res) => {
  const trace = {
    userId: String(req.user?.id || ''),
    role: req.user?.role || null,
    convId: String(req.params.convId),
    steps: [],
    finalDecision: 'UNKNOWN',
  };

  const step = (name, payload) => trace.steps.push({ name, ...payload });

  try {
    // Step 1 : load conversation.
    const conv = await Conversation.findById(req.params.convId).lean();
    if (!conv) {
      trace.finalDecision = 'CONV_NOT_FOUND';
      return res.json(trace);
    }
    step('CONV_LOADED', {
      friendChat: conv.friendChat === true,
      ownerId: String(conv.ownerId || ''),
      sitterId: String(conv.sitterId || ''),
      walkerId: String(conv.walkerId || ''),
      participantsCount: (conv.participants || []).length,
    });

    // Step 2 : friendChat branch.
    if (conv.friendChat === true) {
      const isParticipant = (conv.participants || []).some(
        (p) => String(p.userId) === String(req.user?.id),
      );
      step('FRIEND_CHAT_BRANCH', { isParticipant });
      trace.finalDecision = isParticipant ? 'BYPASS_FRIEND_CHAT' : 'BLOCK_NOT_PARTICIPANT';
      return res.json(trace);
    }

    // Step 3 : load my user doc to inspect isStaff + email.
    const role = req.user?.role || 'owner';
    const Model = role === 'walker' ? Walker : role === 'sitter' ? Sitter : Owner;
    const me = await Model.findById(req.user.id).select('isStaff email').lean();
    step('USER_LOADED', {
      docExists: !!me,
      isStaff: !!me?.isStaff,
      emailHint: me?.email
        ? `${String(me.email).slice(0, 4)}***@${String(me.email).split('@')[1] || ''}`
        : null,
    });

    if (me?.isStaff === true) {
      trace.finalDecision = 'BYPASS_STAFF_FLAG';
      return res.json(trace);
    }

    // Step 4 : email whitelist.
    const HARDCODED_STAFF_EMAILS = new Set(['dadaciao84@gmail.com']);
    const envStaffEmails = String(process.env.STAFF_EMAILS || '')
      .split(',').map((s) => s.trim().toLowerCase()).filter(Boolean);
    const emailLower = String(me?.email || '').toLowerCase();
    const isStaffByEmail = HARDCODED_STAFF_EMAILS.has(emailLower)
      || envStaffEmails.includes(emailLower);
    step('EMAIL_WHITELIST', {
      checkedEmail: emailLower,
      hardcodedMatch: HARDCODED_STAFF_EMAILS.has(emailLower),
      envMatch: envStaffEmails.includes(emailLower),
      envStaffEmailsCount: envStaffEmails.length,
    });
    if (isStaffByEmail) {
      trace.finalDecision = 'BYPASS_STAFF_EMAIL';
      return res.json(trace);
    }

    // Step 5 : hasActivePawFollow.
    let iHavePawFollow = false;
    try {
      iHavePawFollow = await hasActivePawFollow(req.user.id);
    } catch (e) {
      step('HAS_PAWFOLLOW_ERROR', { error: e?.message });
    }
    step('HAS_PAWFOLLOW', { result: iHavePawFollow });
    if (iHavePawFollow) {
      trace.finalDecision = 'BYPASS_PAWFOLLOW';
      return res.json(trace);
    }

    // Step 6 : ANY active subscription.
    const anyActive = await UserSubscription.findOne({
      userId: req.user.id,
      status: 'active',
      currentPeriodEnd: { $gt: new Date() },
    }).select('plan planType status currentPeriodEnd userModel').lean();
    step('ANY_ACTIVE_SUB', {
      found: !!anyActive,
      plan: anyActive?.plan || null,
      planType: anyActive?.planType || null,
      userModel: anyActive?.userModel || null,
      currentPeriodEnd: anyActive?.currentPeriodEnd || null,
    });
    if (anyActive) {
      trace.finalDecision = 'BYPASS_ANY_SUB';
      return res.json(trace);
    }

    // Step 7 : legacy userModel-filtered sub.
    const userModel = role === 'walker' ? 'Walker' : role === 'sitter' ? 'Sitter' : 'Owner';
    const sub = await UserSubscription.findOne({ userId: req.user.id, userModel })
      .select('status currentPeriodEnd chatAddonActive chatAddonExpiresAt').lean();
    const now = new Date();
    const premiumActive = sub && sub.status === 'active'
      && sub.currentPeriodEnd && new Date(sub.currentPeriodEnd) > now;
    const chatAddonActive = sub && sub.chatAddonActive === true
      && sub.chatAddonExpiresAt && new Date(sub.chatAddonExpiresAt) > now;
    step('LEGACY_SUB', {
      subFound: !!sub,
      premiumActive,
      chatAddonActive,
    });
    if (premiumActive || chatAddonActive) {
      trace.finalDecision = 'BYPASS_PREMIUM_OR_ADDON';
      return res.json(trace);
    }

    // Step 8 : isInSameFamily.
    const idStr = (v) => v ? (v._id ? v._id.toString() : v.toString()) : null;
    const otherId = idStr(conv.ownerId) === String(req.user.id)
      ? idStr(conv.sitterId) || idStr(conv.walkerId)
      : idStr(conv.ownerId);
    let sameFamily = false;
    if (otherId) {
      try {
        sameFamily = await isInSameFamily(req.user.id, otherId);
      } catch (_) {/* */}
    }
    step('SAME_FAMILY', { otherId, sameFamily });
    if (sameFamily) {
      trace.finalDecision = 'BYPASS_SAME_FAMILY';
      return res.json(trace);
    }

    // Step 9 : evaluateChatAccess (booking-paid).
    const providerId = conv.walkerId || conv.sitterId;
    const paidExists = !!(conv.ownerId && providerId) && await Booking.exists({
      ownerId: conv.ownerId,
      paymentStatus: 'paid',
      $or: [{ walkerId: providerId }, { sitterId: providerId }],
    });
    step('PAID_BOOKING', {
      paidExists,
      providerId: String(providerId || ''),
    });
    if (paidExists) {
      trace.finalDecision = 'BYPASS_PAID_BOOKING';
      return res.json(trace);
    }

    const latest = await Booking.findOne({
      ownerId: conv.ownerId,
      $or: [{ walkerId: providerId }, { sitterId: providerId }],
    }).sort({ createdAt: -1 }).select('_id status paymentStatus').lean();
    step('LATEST_BOOKING', {
      bookingId: latest?._id ? String(latest._id) : null,
      status: latest?.status || null,
      paymentStatus: latest?.paymentStatus || null,
    });

    trace.finalDecision = 'BLOCK_PAYMENT_REQUIRED';
    return res.json(trace);
  } catch (e) {
    logger.error('[diagnostic/chat-access]', e);
    trace.finalDecision = 'ERROR';
    trace.error = e?.message;
    return res.status(500).json(trace);
  }
});

// ── /sitters-visibility — auth — explains why owner doesn't see a sitter ──
router.get('/sitters-visibility', requireAuth, async (req, res) => {
  try {
    const me = await Owner.findById(req.user.id).select('email location city').lean();
    const allSitters = await Sitter.find({}).select('email location city hourlyRate dailyRate weeklyRate monthlyRate verified').limit(50).lean();
    res.json({
      viewer: {
        email: me?.email,
        viewerCity: me?.location?.city || me?.city || null,
        hasLocation: !!(me?.location?.coordinates),
      },
      totalSittersInDb: allSitters.length,
      sitters: allSitters.map((s) => ({
        id: String(s._id),
        email: s.email,
        sitterCity: s.location?.city || s.city || null,
        hasCoords: !!(s.location?.coordinates),
        hasRates: !!(s.hourlyRate || s.dailyRate || s.weeklyRate || s.monthlyRate),
        verified: !!s.verified,
      })),
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
