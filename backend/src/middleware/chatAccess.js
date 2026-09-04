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
      .select('ownerId sitterId walkerId friendChat participants')
      .lean();
    if (!conversation) {
      return res.status(404).json({ error: 'Conversation not found.' });
    }

    // v23.1.200 — Daniel : friend/family chat. Bypass complet du
    // pipeline booking-payé pour les conversations friendChat.
    // L'autorisation est verifiee a la creation (startFriendConversation)
    // qui valide friendship 'accepted' OU meme famille PawFollow.
    if (conversation.friendChat === true) {
      const myId = req.user?.id;
      const isParticipant = Array.isArray(conversation.participants)
        && conversation.participants.some(
          (p) => String(p.userId) === String(myId),
        );
      if (!isParticipant) {
        return res.status(403).json({ error: 'Not a chat participant.' });
      }
      return next();
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
      const { hasActivePawFollow } = require('../models/UserSubscription');

      const role = req.user?.role;
      const userId = req.user?.id;
      // v23.1 part 228 — Daniel : "chat revient erreur 403". On loggue
      // exhaustivement la decision d'acces pour debugger en prod via
      // Render. Le log apparait dans les logs Render quand un user hit
      // une conv. Chaque bypass-check ecrit son verdict.
      const diag = { convId: String(conversation._id), role, userId };
      const log403Decision = (verdict, extra = {}) => {
        try {
          logger.info(
            `[requirePaidBooking] decision=${verdict} ${JSON.stringify({ ...diag, ...extra })}`,
          );
        } catch (_) {/* defensive */}
      };

      if (role && userId) {
        // v550 — Daniel : chat GRATUIT pour tous tant que la base compte
        // moins de CHAT_FREE_UNTIL_USERS comptes (1 000 par défaut) — voir
        // chatAccessService.isLaunchPhase(). Le gating Premium se réapplique
        // seul passé le seuil.
        try {
          const { isLaunchPhase } = require('../services/chatAccessService');
          if (await isLaunchPhase()) {
            log403Decision('BYPASS_LAUNCH_PHASE');
            return next();
          }
        } catch (e) {
          log403Decision('LAUNCH_PHASE_CHECK_FAILED', { error: e?.message });
        }

        const Model = role === 'walker' ? Walker : role === 'sitter' ? Sitter : Owner;
        const me = await Model.findById(userId).select('isStaff email').lean();
        if (me && me.isStaff === true) {
          log403Decision('BYPASS_STAFF');
          return next();
        }

        // v23.1 part 228 — Daniel : "chat revient erreur 403". Whitelist
        // hardcodee pour le compte staff principal du projet. Permet
        // d'eviter d'avoir a toggle isStaff manuellement en DB ou de
        // setup une env var. Idempotent : si tu changes d'email tu peux
        // ajouter ici ou via STAFF_EMAILS env var.
        const HARDCODED_STAFF_EMAILS = new Set([
          'dadaciao84@gmail.com',
        ]);
        const envStaffEmails = String(process.env.STAFF_EMAILS || '')
          .split(',')
          .map((s) => s.trim().toLowerCase())
          .filter(Boolean);
        const isStaffByEmail =
          me && me.email && (
            HARDCODED_STAFF_EMAILS.has(String(me.email).toLowerCase()) ||
            envStaffEmails.includes(String(me.email).toLowerCase())
          );
        if (isStaffByEmail) {
          log403Decision('BYPASS_STAFF_EMAIL', { email: me.email });
          return next();
        }

        // v23.1 part 227 — Daniel : "erreur api 403 ds longlet chat".
        // Le check legacy filtrait par userModel (case-sensitive) → si la
        // sub n'avait pas ce champ (ancien doc) le bypass ratait. On
        // utilise maintenant hasActivePawFollow() qui ne filtre QUE par
        // userId + status='active' + currentPeriodEnd > now → identique
        // a la logique mapSocket v226 (coherence garantie).
        try {
          const iHavePawFollow = await hasActivePawFollow(userId);
          if (iHavePawFollow) {
            log403Decision('BYPASS_PAWFOLLOW');
            return next();
          }
        } catch (e) {
          log403Decision('PAWFOLLOW_CHECK_FAILED', { error: e?.message });
        }

        // v23.1 part 228 — fallback ultra-permissif : ANY UserSubscription
        // doc active du user (peu importe userModel/plan) → bypass.
        // v450 — Daniel : « PawSpot doit aussi débloquer le chat ». L'ancien
        // check ne regardait QUE currentPeriodEnd → un abo PawSpot SEUL
        // (pawspotExpiry) prenait 403. On détecte désormais par DATE sur les
        // 4 timers (currentPeriodEnd / familyExpiry / pawspotExpiry /
        // premiumExpiry) via hasAnyActiveSubscription.
        try {
          const { hasAnyActiveSubscription } = require('../models/UserSubscription');
          const anyActiveSub = await hasAnyActiveSubscription(userId);
          if (anyActiveSub) {
            log403Decision('BYPASS_ANY_SUB');
            return next();
          }
        } catch (e) {
          log403Decision('ANY_SUB_CHECK_FAILED', { error: e?.message });
        }

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
        if (premiumActive || chatAddonActive) {
          log403Decision('BYPASS_PREMIUM_OR_CHAT_ADDON');
          return next();
        }

        // v23.1.195 — Daniel : "si tu prend un abonnement follow le chat
        // amis famille se debloque". Cas : witoulek est ajoute a la
        // famille PawFollow de Daniel mais n'a PAS sa propre sub →
        // sans ce check il restait bloque. Maintenant : si user A et
        // user B sont dans la meme famille (titulaire ou membre actif),
        // le chat entre eux est debloque.
        try {
          const { isInSameFamily } = require('../models/UserSubscription');
          const idStr = (v) =>
            v ? (v._id ? v._id.toString() : v.toString()) : null;
          const otherId =
            idStr(conversation.ownerId) === userId
              ? idStr(conversation.sitterId) || idStr(conversation.walkerId)
              : idStr(conversation.ownerId);
          if (otherId) {
            const sameFamily = await isInSameFamily(userId, otherId);
            if (sameFamily) return next();
          }
        } catch (familyErr) {
          logger.warn?.('[requirePaidBooking] family check failed',
              familyErr?.message);
        }
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
      // v23.1 part 228 — log final 403 verdict avec details Booking pour
      // diagnostiquer (existence booking entre les 2 parties, son status,
      // son paymentStatus, etc.). Indispensable Render-side.
      try {
        logger.warn(
          `[requirePaidBooking] 403 PAYMENT_REQUIRED ${JSON.stringify({
            convId: String(conversation._id),
            ownerId: String(conversation.ownerId || ''),
            sitterId: String(conversation.sitterId || ''),
            walkerId: String(conversation.walkerId || ''),
            latestBookingId: access.bookingId,
            bookingStatus: access.status,
            paymentStatus: access.paymentStatus,
          })}`,
        );
      } catch (_) {/* defensive */}
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
