const Conversation = require('../models/Conversation');
const Booking = require('../models/Booking');
const logger = require('../utils/logger');

/**
 * v18.8 — walker-aware. Accepte (ownerId, sitterId[, walkerId]).
 * Chat ouvert si au moins un booking payé existe entre owner et le
 * provider (sitter OU walker selon le cas).
 */
const evaluateChatAccess = async ({ ownerId, sitterId, walkerId }) => {
  if (!ownerId || (!sitterId && !walkerId)) {
    return { blocked: true, bookingId: null, status: null, paymentStatus: null };
  }

  // v18.8.1 — query plus large : on accepte que l'id provider soit stocké
  // dans walkerId OU sitterId (cas des bookings historiques créés avant le
  // champ walkerId).
  const providerId = walkerId || sitterId;

  const paidExists = await Booking.exists({
    ownerId,
    paymentStatus: 'paid',
    $or: [{ walkerId: providerId }, { sitterId: providerId }],
  });
  if (paidExists) return { blocked: false };

  const latest = await Booking.findOne({
    ownerId,
    $or: [{ walkerId: providerId }, { sitterId: providerId }],
  })
    .sort({ createdAt: -1 })
    .select('_id status paymentStatus')
    .lean();
  return {
    blocked: true,
    bookingId: latest?._id?.toString() || null,
    status: latest?.status || null,
    paymentStatus: latest?.paymentStatus || null,
  };
};

/**
 * Express middleware: 403 with PAYMENT_REQUIRED when chat is gated.
 * v18.8 — prend en compte conversation.walkerId pour les chats owner↔walker.
 * Avant v18.8, un walker tapait 403 car la conversation avait sitterId=null
 * et evaluateChatAccess queryait Booking.findOne({ ownerId, sitterId:null }).
 */
const requirePaidBooking = async (req, res, next) => {
  try {
    const conversation = await Conversation.findById(req.params.id)
      .select('ownerId sitterId walkerId')
      .lean();
    if (!conversation) {
      return res.status(404).json({ error: 'Conversation not found.' });
    }

    // v20.0.18 — bypass pour Staff (Daniel + employés) et pour les users
    // avec Premium actif ou Chat add-on. Avant, seul un booking payé
    // ouvrait le chat → Staff ne pouvait pas tester le chat sans passer
    // par un paiement réel. Désormais les 3 entry-points sont :
    //   1) booking payé existant
    //   2) isStaff === true
    //   3) Premium actif ou Chat add-on actif
    try {
      const Owner = require('../models/Owner');
      const Sitter = require('../models/Sitter');
      const Walker = require('../models/Walker');
      const UserSubscription = require('../models/UserSubscription');

      const role = req.user?.role;
      const userId = req.user?.id;
      if (role && userId) {
        const Model = role === 'walker' ? Walker : role === 'sitter' ? Sitter : Owner;
        const me = await Model.findById(userId).select('isStaff').lean();
        if (me && me.isStaff === true) return next();

        const userModel =
          role === 'walker' ? 'Walker' : role === 'sitter' ? 'Sitter' : 'Owner';
        const sub = await UserSubscription.findOne({ userId, userModel })
          .select('status currentPeriodEnd chatAddonActive chatAddonExpiresAt')
          .lean();
        const now = new Date();
        const premiumActive =
          sub && sub.status === 'active' &&
          sub.currentPeriodEnd && new Date(sub.currentPeriodEnd) > now;
        const chatAddonActive =
          sub && sub.chatAddonActive === true &&
          sub.chatAddonExpiresAt && new Date(sub.chatAddonExpiresAt) > now;
        if (premiumActive || chatAddonActive) return next();
      }
    } catch (staffErr) {
      // Ne pas bloquer l'accès si le check Staff plante — on tombe sur le
      // flow booking-payé classique.
      logger.warn?.('[requirePaidBooking] staff bypass check failed', staffErr?.message);
    }

    const access = await evaluateChatAccess({
      ownerId: conversation.ownerId,
      sitterId: conversation.sitterId,
      walkerId: conversation.walkerId,
    });
    if (access.blocked) {
      return res.status(403).json({
        error: 'Payment required',
        code: 'PAYMENT_REQUIRED',
        bookingId: access.bookingId,
      });
    }
    return next();
  } catch (e) {
    logger.error('requirePaidBooking error', e);
    return res.status(500).json({ error: 'Chat access check failed.' });
  }
};

module.exports = { requirePaidBooking, evaluateChatAccess };
