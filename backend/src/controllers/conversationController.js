const mongoose = require('mongoose');
const Conversation = require('../models/Conversation');
const Message = require('../models/Message');
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
// v18.8 — walker chat end-to-end : l'owner peut démarrer une conversation
// avec un walker (param walkerId) et le walker peut démarrer avec un owner.
let Walker;
try {
  Walker = require('../models/Walker');
} catch (_) {
  Walker = null;
}
const Block = require('../models/Block');
const Booking = require('../models/Booking');
const { sanitizeConversation, sanitizeMessage } = require('../utils/sanitize');
const {
  sendMessage,
  markConversationRead: markConversationReadService,
  hasValidPaidBooking,
} = require('../services/conversationService');
const { getChatAccess } = require('../services/chatAccessService');
const { uploadMedia } = require('../services/cloudinary');
const { HttpError } = require('../utils/errors');
const { emitToConversation, emitChatMessage } = require('../sockets/emitter');
// v566 — accusés de réception / lecture (✓ ✓✓ ✓✓ bleu).
const receipts = require('../services/messageReceiptService');
// v583 (lot A) — conversation avec MOI-MÊME (mes autres profils) masquée.
const { selfIdSet, excludeSelfConversations } = require('../utils/identityGroup');
const logger = require('../utils/logger');

const bufferToDataUri = (file) => `data:${file.mimetype};base64,${file.buffer.toString('base64')}`;

const mapUploadToAttachment = (uploadResult) => ({
  url: uploadResult.url,
  publicId: uploadResult.publicId,
  resourceType: uploadResult.resourceType || 'image',
  format: uploadResult.format || '',
  bytes: typeof uploadResult.bytes === 'number' ? uploadResult.bytes : null,
  width: typeof uploadResult.width === 'number' ? uploadResult.width : null,
  height: typeof uploadResult.height === 'number' ? uploadResult.height : null,
  duration: typeof uploadResult.duration === 'number' ? uploadResult.duration : null,
  thumbnailUrl: uploadResult.thumbnailUrl || uploadResult.url,
  originalFilename: uploadResult.originalFilename || '',
});

// ─── v565 §5 — chat : réponse à un message, vocal, drapeaux admin ───────────
const AppConfig = require('../models/AppConfig');
const { buildPresenceIndex, isIdentityOnline } = require('../sockets/emitter');

/** 403 FEATURE_DISABLED si le drapeau admin est à false. */
const assertChatFeature = async (feature) => {
  const flags = await AppConfig.getChatFeatures();
  if (flags && flags[feature] === false) {
    const err = new HttpError(403, `This chat feature is disabled by the administrator (${feature}).`);
    err.code = 'FEATURE_DISABLED';
    err.details = { feature };
    throw err;
  }
};

/** Identité de l'expéditeur : JWT en priorité, corps en repli (anciens clients). */
const resolveSender = (req) => {
  const jwtRole = String(req.user?.role || '').toLowerCase();
  const jwtId = req.user?.id ? String(req.user.id) : '';
  const bodyRole = String(req.body?.senderRole || '').toLowerCase();
  const bodyId = req.body?.senderId ? String(req.body.senderId) : '';
  if (jwtId && ['owner', 'sitter', 'walker'].includes(jwtRole)) {
    if (bodyId && bodyId !== jwtId) {
      logger.warn(`[chat] senderId ${bodyId} ignoré : le jeton dit ${jwtRole}:${jwtId}`);
    }
    return { senderRole: jwtRole, senderId: jwtId };
  }
  return { senderRole: bodyRole, senderId: bodyId };
};

const replyKindOf = (msg) => {
  if (!msg) return 'text';
  if (msg.type === 'phone_share' || msg.type === 'address_share') return msg.type;
  if (msg.type === 'voice') return 'audio';
  const a = Array.isArray(msg.attachments) && msg.attachments[0];
  if (a) {
    if (a.resourceType === 'audio') return 'audio';
    if (a.resourceType === 'video') return 'video';
    return 'image';
  }
  return 'text';
};

/**
 * Charge le message cité (même conversation, non supprimé) et renvoie
 * l'instantané à stocker : { messageId, body ≤120, senderRole, senderId, kind }.
 * `replyTo` accepte un objet ou une chaîne JSON (multipart).
 */
const buildReplySnapshot = async (conversationId, replyTo) => {
  let raw = replyTo;
  if (typeof raw === 'string') {
    const t = raw.trim();
    if (!t) return null;
    try { raw = JSON.parse(t); } catch (_) { raw = { messageId: t }; }
  }
  const messageId = raw && (raw.messageId || raw.id || raw._id);
  if (!messageId) return null;
  if (!mongoose.Types.ObjectId.isValid(String(messageId))) {
    throw new HttpError(400, 'replyTo.messageId is invalid.');
  }
  await assertChatFeature('reply');
  const quoted = await Message.findOne({ _id: messageId, conversationId }).lean();
  if (!quoted) throw new HttpError(404, 'Quoted message not found in this conversation.');
  if (quoted.deletedAt) throw new HttpError(400, 'Quoted message has been deleted.');
  const kind = replyKindOf(quoted);
  let body = typeof quoted.body === 'string' ? quoted.body.trim() : '';
  if (!body) {
    body = kind === 'audio' ? '🎤' : kind === 'video' ? '🎬' : kind === 'image' ? '📷' : '';
  }
  return {
    messageId: quoted._id,
    body: body.slice(0, 120),
    senderRole: quoted.senderRole || 'owner',
    senderId: quoted.senderId || null,
    kind,
  };
};

/**
 * v575 — audit P2-1 : NATURE du dernier message, pour que l'app rende
 * l'aperçu dans SA langue (`chatPreviewForKind`). Renvoie '' pour un vrai
 * message texte — dans ce cas l'app affiche `lastMessage` tel quel.
 * Les valeurs correspondent exactement aux cas de `chatPreviewForKind`.
 */
const previewKindOf = ({ body, attachments, type }) => {
  const hasText = typeof body === 'string' && body.trim().length > 0;
  if (hasText) return '';
  const t = String(type || '').toLowerCase();
  if (t === 'voice' || t === 'audio') return 'audio';
  if (t === 'phone_share' || t === 'address_share') return t;
  const list = Array.isArray(attachments) ? attachments : [];
  if (list.length === 0) return '';
  if (list.length === 1) {
    return list[0]?.resourceType === 'video' ? 'video' : 'image';
  }
  // Plusieurs pièces jointes : l'app n'a pas de libellé pluriel dédié, on
  // retombe sur « pièce jointe » (cas `default` de chatPreviewForKind).
  return 'attachment';
};

/** Aperçu de conversation / notification pour une pièce jointe. */
const attachmentPreview = (attachments, kind) => {
  if (kind === 'voice') return '🎤 Message vocal';
  const list = Array.isArray(attachments) ? attachments : [];
  if (list.length === 1) return list[0].resourceType === 'video' ? 'Sent a video' : 'Sent a photo';
  const videos = list.filter((a) => a.resourceType === 'video').length;
  if (videos === list.length) return `Sent ${videos} ${videos === 1 ? 'video' : 'videos'}`;
  if (videos) return `Sent ${list.length} attachments`;
  return `Sent ${list.length} ${list.length === 1 ? 'photo' : 'photos'}`;
};

/**
 * Persiste `replyTo` / `type` sur un message créé par conversationService
 * (qui ne connaît pas ces champs) et met à jour l'objet renvoyé.
 */
const patchMessageExtras = async (result, { replyTo, type, lastMessage, conversationId }) => {
  const $set = {};
  if (replyTo) $set.replyTo = replyTo;
  if (type) $set.type = type;
  const msgId = result?.message?.id || result?.message?._id;
  if (msgId && Object.keys($set).length) {
    await Message.updateOne({ _id: msgId }, { $set });
    if (replyTo) result.message.replyTo = { ...replyTo, messageId: String(replyTo.messageId), senderId: replyTo.senderId ? String(replyTo.senderId) : null };
    if (type) result.message.type = type;
  }
  if (lastMessage && conversationId) {
    await Conversation.updateOne({ _id: conversationId }, { $set: { lastMessage } });
    if (result?.conversation) result.conversation.lastMessage = lastMessage;
  }
  return result;
};

/**
 * Message vocal (ou pièce jointe) dans une conversation BOOKING, sans passer
 * par conversationService.sendMessage (qui fige type='text' et un aperçu
 * « Sent a photo »). Le gating d'accès est déjà fait par requirePaidBooking ;
 * on revérifie participant + blocage comme le service.
 */
const persistBookingAttachmentMessage = async ({ conversation, senderRole, senderId, body, attachments, type, replyTo }) => {
  const idStr = (v) => (v ? String(v._id || v) : null);
  const ownerId = idStr(conversation.ownerId);
  const sitterId = idStr(conversation.sitterId);
  const walkerId = idStr(conversation.walkerId);
  const mine = senderRole === 'owner' ? ownerId : senderRole === 'sitter' ? sitterId : walkerId;
  if (!mine || mine !== String(senderId)) {
    throw new HttpError(403, 'User is not part of this conversation.');
  }
  const providerId = sitterId || walkerId;
  const providerModel = sitterId ? 'Sitter' : 'Walker';
  const blocked = await Block.exists({
    $or: [
      { blockerId: ownerId, blockerModel: 'Owner', blockedId: providerId, blockedModel: providerModel },
      { blockerId: providerId, blockerModel: providerModel, blockedId: ownerId, blockedModel: 'Owner' },
    ],
  });
  if (blocked) throw new HttpError(403, 'Messaging is disabled because one user has been blocked.');
  const cleanBody = typeof body === 'string'
    ? require('../services/textModerationService').moderateText(body.trim()).clean
    : '';
  const message = await Message.create({
    conversationId: conversation._id,
    senderRole,
    senderId,
    body: cleanBody,
    attachments,
    type: type || 'text',
    replyTo: replyTo || null,
  });
  const preview = cleanBody || attachmentPreview(attachments, type === 'voice' ? 'voice' : 'media');
  // v575 — audit P2-1 : `preview` reste le texte de repli (anciennes apps) ;
  // `lastMessageKind` permet aux apps ≥ 575 de le traduire.
  const previewKind = previewKindOf({ body: cleanBody, attachments, type });
  const inc = senderRole === 'owner' ? { sitterUnreadCount: 1 } : { ownerUnreadCount: 1 };
  await Conversation.updateOne(
    { _id: conversation._id },
    {
      $set: {
        lastMessage: preview,
        lastMessageKind: previewKind,
        lastMessageAt: new Date(),
        clearedFor: [],
      },
      $inc: inc,
    },
  );
  // Notification NEW_MESSAGE au destinataire (owner ↔ prestataire).
  try {
    const recipientRole = senderRole === 'owner' ? (walkerId ? 'walker' : 'sitter') : 'owner';
    const recipientId = senderRole === 'owner' ? (walkerId || sitterId) : ownerId;
    if (recipientId && recipientId !== String(senderId)) {
      const SenderModel = senderRole === 'owner' ? Owner : senderRole === 'sitter' ? Sitter : Walker;
      const senderDoc = SenderModel ? await SenderModel.findById(senderId).select('name').lean() : null;
      const { sendNotification } = require('../services/notificationSender');
      sendNotification({
        userId: recipientId,
        role: recipientRole,
        type: 'NEW_MESSAGE',
        data: {
          conversationId: String(conversation._id),
          messageId: String(message._id),
          senderName: (senderDoc?.name || '').trim() || 'HoPetSit',
          preview: preview.slice(0, 120),
        },
        actor: { role: senderRole, id: senderId },
      }).catch((e) => logger.warn(`[chat.voice] NEW_MESSAGE notif failed : ${e?.message || e}`));
    }
  } catch (_) { /* best-effort */ }
  const fresh = await Conversation.findById(conversation._id)
    .populate('ownerId').populate('sitterId').populate('walkerId');
  return {
    message: sanitizeMessage(message),
    conversation: sanitizeConversation(fresh || conversation),
  };
};

const listConversations = async (req, res) => {
  try {
    const { role, userId } = req.query;

    if (!role || !userId) {
      return res.status(400).json({ error: 'role and userId are required.' });
    }

    if (!['owner', 'sitter'].includes(role)) {
      return res.status(400).json({ error: 'Invalid role. Expected "owner" or "sitter".' });
    }

    const query = role === 'owner' ? { ownerId: userId } : { sitterId: userId };

    const conversations = await Conversation.find(query)
      .sort({ updatedAt: -1 })
      .populate('ownerId')
      .populate('sitterId');

    res.json({ conversations: conversations.map(sanitizeConversation) });
  } catch (error) {
    logger.error('Fetch conversations error', error);
    res.status(500).json({ error: 'Unable to fetch conversations. Please try again later.' });
  }
};

const getChatList = async (req, res) => {
  try {
    const userId = req.user?.id;
    const userRole = req.user?.role;

    if (!userId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (!userRole || !['owner', 'sitter', 'walker'].includes(userRole.toLowerCase())) {
      return res.status(400).json({ error: 'Invalid user role. Expected "owner", "sitter" or "walker".' });
    }

    const normalizedRole = userRole.toLowerCase();

    // v18.7 — walker chat activé. La Conversation schema supporte XOR
    // sitter/walker depuis v18.6. On query sur le champ correspondant au
    // rôle courant.
    // v23.1.200 — Daniel : "bouton 💬 sur friend + family member".
    // On retourne maintenant 2 types de conversations dans la chat list :
    //   1. Bookings (owner ↔ sitter/walker) — filtrage role classique
    //   2. friendChats — toute conv friendChat où l'user est participant
    let query;
    if (normalizedRole === 'owner') {
      query = {
        $or: [
          { ownerId: userId, friendChat: { $ne: true } },
          { friendChat: true, 'participants.userId': userId },
        ],
      };
    } else if (normalizedRole === 'walker') {
      query = {
        $or: [
          { walkerId: userId, friendChat: { $ne: true } },
          { friendChat: true, 'participants.userId': userId },
        ],
      };
    } else {
      query = {
        $or: [
          { sitterId: userId, friendChat: { $ne: true } },
          { friendChat: true, 'participants.userId': userId },
        ],
      };
    }

    // v23.1.255 — exclut les conversations que CET utilisateur a masquées
    // (soft-delete). Un nouveau message vide clearedFor → réapparition.
    query.clearedFor = { $ne: userId };

    const conversations = await Conversation.find(query)
      .sort({ updatedAt: -1 })
      .populate('ownerId', 'name email avatar oldId lastSeenAt')
      .populate('sitterId', 'name email avatar oldId lastSeenAt')
      .populate('walkerId', 'name email avatar oldId lastSeenAt');

    // v565 §6 — présence réelle : un index (sockets connectés → ids/e-mails/
    // oldId) construit UNE fois, puis chaque correspondant testé en O(1) sur
    // son identité complète (owner/sitter/walker).
    let presence = null;
    try { presence = await buildPresenceIndex(); } catch (_) { presence = null; }
    const presenceOf = (doc) => ({
      isOnline: presence ? isIdentityOnline(doc, presence) : false,
      lastSeenAt: doc?.lastSeenAt ? new Date(doc.lastSeenAt).toISOString() : null,
    });

    // v566 — coches devant l'aperçu : statut du DERNIER message de chaque
    // conversation (une seule requête pour toute la liste).
    let lastReceipts = new Map();
    try {
      lastReceipts = await receipts.lastMessageReceipts({ conversations, userId });
    } catch (e) {
      logger.warn(`[chat.list] lastMessageReceipts failed : ${e?.message || e}`);
    }
    const receiptOf = (conversation) =>
      lastReceipts.get(String(conversation._id)) || {
        lastMessageId: null,
        lastMessageSenderId: null,
        lastMessageSenderRole: null,
        lastMessageMine: false,
        lastMessageStatus: null,
        lastMessageDeliveredAt: null,
        lastMessageReadAt: null,
      };
    const unreadConversationIds = [];

    // Enhance conversations with user details
    const enhancedConversations = await Promise.all(
      conversations.map(async (conversation) => {
        const sanitized = sanitizeConversation(conversation);
        let otherParty = null;
        let unread = 0;
        let pres = { isOnline: false, lastSeenAt: null };

        // v23.1.200 — friendChat : autre participant = celui qui n'est pas moi.
        if (conversation.friendChat === true) {
          const others = (conversation.participants || []).filter(
            (p) => String(p.userId) !== String(userId),
          );
          const me = (conversation.participants || []).find(
            (p) => String(p.userId) === String(userId),
          );
          unread = me?.unreadCount || 0;
          const o = others[0];
          if (o) {
            const ROLE_MODELS = { Owner: 'owner', Sitter: 'sitter', Walker: 'walker' };
            try {
              const Model = require('../models/' + o.userModel);
              const otherDoc = await Model.findById(o.userId)
                .select('name email avatar oldId lastSeenAt').lean();
              if (otherDoc) {
                pres = presenceOf(otherDoc);
                otherParty = {
                  id: otherDoc._id?.toString() || '',
                  name: otherDoc.name || '',
                  email: otherDoc.email || '',
                  avatar: otherDoc.avatar?.url || '',
                  role: ROLE_MODELS[o.userModel] || 'owner',
                  ...pres,
                };
              }
              // v490 — Daniel : un utilisateur SUPPRIMÉ (otherDoc introuvable)
              // ne doit PLUS apparaître. Avant : ghost gris « Utilisateur
              // supprimé ». Maintenant otherParty reste null → conversation
              // retirée de la liste par le filtre `if (!otherParty)` ci-dessous.
            } catch (_) {/* defensive */}
          }
          // Conversation amie avec un compte supprimé → on l'enlève.
          if (!otherParty) return null;
          if (unread > 0) unreadConversationIds.push(conversation._id);
          return { ...sanitized, otherParty, unreadCount: unread, ...pres, ...receiptOf(conversation) };
        }

        // Branch booking classique (legacy).
        if (normalizedRole === 'owner') {
          const provider = conversation.sitterId || conversation.walkerId;
          if (provider) {
            pres = presenceOf(provider);
            otherParty = {
              id: provider._id?.toString() || '',
              name: provider.name || '',
              email: provider.email || '',
              avatar: provider.avatar?.url || '',
              role: conversation.sitterId ? 'sitter' : 'walker',
              ...pres,
            };
          }
        } else {
          const owner = conversation.ownerId;
          if (owner) {
            pres = presenceOf(owner);
            otherParty = {
              id: owner._id?.toString() || '',
              name: owner.name || '',
              email: owner.email || '',
              avatar: owner.avatar?.url || '',
              role: 'owner',
              ...pres,
            };
          }
        }
        // v490 — Daniel : compte supprimé (provider/owner introuvable après
        // populate) → on retire la conversation au lieu d'afficher un ghost.
        if (!otherParty) return null;
        const bookingUnread = normalizedRole === 'owner'
          ? conversation.ownerUnreadCount || 0
          : conversation.sitterUnreadCount || 0;
        if (bookingUnread > 0) unreadConversationIds.push(conversation._id);
        return {
          ...sanitized,
          otherParty,
          unreadCount: bookingUnread,
          ...pres,
          ...receiptOf(conversation),
        };
      })
    );

    // v490 — retire les conversations dont l'autre participant a supprimé son
    // compte (entrées null ci-dessus) → plus de « Utilisateur supprimé » gris.
    // v583 (lot A, validé par Daniel le 23/09) — retire aussi la conversation
    // avec MOI-MÊME (l'autre participant est un de mes profils : « Daniel C »
    // avec lui-même sur sa capture). Rien n'est supprimé en base.
    let selfIds = new Set();
    try { selfIds = await selfIdSet(req); } catch (_) { selfIds = new Set(); }
    const cleanedConversations = excludeSelfConversations(
      enhancedConversations.filter(Boolean),
      selfIds,
    );

    res.json({
      conversations: cleanedConversations,
      count: cleanedConversations.length,
    });

    // v566 — rattrapage « remis » : la liste vient d'atteindre l'appareil, donc
    // tout ce qui attendait dans les conversations NON LUES est remis (✓✓ gris
    // chez l'expéditeur). Après la réponse, groupé, jamais bloquant.
    if (unreadConversationIds.length) {
      receipts.safely(
        'markDeliveredForConversations',
        receipts.markDeliveredForConversations({
          conversationIds: unreadConversationIds,
          recipientId: userId,
        }),
      );
    }
  } catch (error) {
    logger.error('Get chat list error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid user id.' });
    }
    res.status(500).json({ error: 'Impossible de charger la liste des conversations. Veuillez réessayer.' });
  }
};

const getConversationMessages = async (req, res) => {
  try {
    const { id } = req.params;

    const conversation = await Conversation.findById(id);
    if (!conversation) {
      return res.status(404).json({ error: 'Conversation not found.' });
    }

    // v23.1 part 238 — Daniel : "Access denied for this conversation"
    // sur un chat ami. ROOT CAUSE : ce controller utilisait query.role +
    // query.userId + vrai check seulement sur ownerId/sitterId/walkerId.
    // Or les conversations friendChat ont participants:[{userId,userModel}]
    // au lieu d'ownerId/sitterId/walkerId → check fail → 403 systematique
    // sur tous les chats ami.
    //
    // FIX :
    //  1. Source d'identite = JWT (req.user) au lieu de query params
    //     (cohérent avec les autres endpoints + securite).
    //  2. Branch friendChat : check participants[] include userId.
    //  3. Branch booking-style : check ownerId/sitterId/walkerId.
    //  4. Bypass staff email (cohérent avec chatAccess.js middleware).
    const myId = String(req.user?.id || '');
    const idToString = (v) =>
      v ? (v._id ? v._id.toString() : v.toString()) : null;

    let accessOk = false;

    // FriendChat : check participants.
    if (conversation.friendChat === true) {
      accessOk = (conversation.participants || []).some(
        (p) => idToString(p.userId) === myId,
      );
    } else {
      // Booking-style : check ownerId / sitterId / walkerId.
      const ownerIdValue = idToString(conversation.ownerId);
      const sitterIdValue = idToString(conversation.sitterId);
      const walkerIdValue = idToString(conversation.walkerId);
      accessOk = ownerIdValue === myId
        || sitterIdValue === myId
        || walkerIdValue === myId;
    }

    // v23.1 part 238 — staff email bypass (coherent avec chatAccess.js).
    if (!accessOk) {
      try {
        const role = req.user?.role;
        const Owner = require('../models/Owner');
        const Sitter = require('../models/Sitter');
        const Walker = require('../models/Walker');
        const Model = role === 'walker' ? Walker : role === 'sitter' ? Sitter : Owner;
        const me = await Model.findById(req.user.id).select('isStaff email').lean();
        const HARDCODED_STAFF_EMAILS = new Set(['dadaciao84@gmail.com']);
        const envStaffEmails = String(process.env.STAFF_EMAILS || '')
          .split(',').map((s) => s.trim().toLowerCase()).filter(Boolean);
        const emailLower = String(me?.email || '').toLowerCase();
        if (me?.isStaff === true ||
            HARDCODED_STAFF_EMAILS.has(emailLower) ||
            envStaffEmails.includes(emailLower)) {
          accessOk = true;
        }
      } catch (_) {/* defensive */}
    }

    if (!accessOk) {
      return res.status(403).json({ error: 'Access denied for this conversation.' });
    }

    // v402 — Daniel : "à chaque connexion le badge message revient alors que j'ai
    // tout lu". CAUSE : le reset du unreadCount serveur dépendait de l'event socket
    // `conversation:read` (émis à l'ouverture du chat), qui peut se perdre si le
    // socket est lent/coupé à ce moment. Compteur serveur resté > 0 →
    // syncChatBadgeFromServer ré-inflate le badge à CHAQUE reconnexion/login.
    // FIX robuste (deploy-only, pas de rebuild) : ouvrir une conversation = charger
    // ses messages via CE endpoint REST (toujours fiable). On remet donc le
    // unreadCount du lecteur à 0 ici aussi. Couvre friendChat (participants[]) ET
    // booking (owner/sitterUnreadCount). Best-effort : n'empêche jamais la réponse.
    try {
      const myIdStr = String(req.user?.id || '');
      let changed = false;
      if (conversation.friendChat === true && Array.isArray(conversation.participants)) {
        for (const part of conversation.participants) {
          if (String(part.userId) === myIdStr && (part.unreadCount || 0) > 0) {
            part.unreadCount = 0;
            part.lastReadAt = new Date();
            changed = true;
          }
        }
      } else {
        // Booking-style : le provider (sitter ET walker) partage le slot sitter.
        if (req.user?.role === 'owner') {
          if ((conversation.ownerUnreadCount || 0) > 0) {
            conversation.ownerUnreadCount = 0;
            conversation.ownerLastReadAt = new Date();
            changed = true;
          }
        } else if ((conversation.sitterUnreadCount || 0) > 0) {
          conversation.sitterUnreadCount = 0;
          conversation.sitterLastReadAt = new Date();
          changed = true;
        }
      }
      if (changed) await conversation.save();
    } catch (e) {
      logger.warn(`[conversation.messages] reset unread failed : ${e?.message || e}`);
    }

    const messages = await Message.find({ conversationId: conversation._id }).sort({ createdAt: 1 });

    res.json({ messages: messages.map(sanitizeMessage) });
  } catch (error) {
    logger.error('Fetch messages error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid conversation id.' });
    }
    res.status(500).json({ error: 'Impossible de charger les messages. Veuillez réessayer.' });
  }
};

/**
 * v23.1.200 — pipeline simplifie pour les chats friendChat (ami/famille).
 * Pas de check booking-paye, pas de logique owner-sitter, juste :
 *   1. Verifier sender est participant
 *   2. Persister le message (Message model)
 *   3. Update conversation.lastMessage + unreadCount du destinataire
 *   4. Notif push au destinataire
 *   5. Renvoyer la card sanitized
 */
const sendFriendMessage = async ({
  conversation, senderId, senderRole, body, attachments, type, replyTo,
}) => {
  const Message = require('../models/Message');
  const isParticipant = (conversation.participants || []).some(
    (p) => String(p.userId) === String(senderId),
  );
  if (!isParticipant) {
    const err = new Error('Not a chat participant.');
    err.status = 403;
    throw err;
  }
  const msg = await Message.create({
    conversationId: conversation._id,
    senderId,
    senderRole,
    body: typeof body === 'string' ? body : '',
    attachments: Array.isArray(attachments) ? attachments : [],
    // v565 §5 — 'voice' pour un message vocal ; replyTo = instantané cité.
    type: type === 'voice' ? 'voice' : 'text',
    replyTo: replyTo || null,
  });
  // Update conversation : lastMessage + unreadCount du destinataire +1.
  const preview = typeof body === 'string' && body.length > 0
    ? body.slice(0, 120)
    : (Array.isArray(attachments) && attachments.length > 0
        ? (type === 'voice' ? '🎤 Message vocal' : '📎 Pièce jointe') : '');
  const update = {
    lastMessage: preview,
    // v575 — audit P2-1 : nature du message, rendue dans la langue de l'app.
    lastMessageKind: previewKindOf({ body, attachments, type }),
    lastMessageAt: new Date(),
    // v23.1.255 — un nouveau message ami fait réapparaître la conversation
    // chez quiconque l'avait masquée (soft-delete).
    clearedFor: [],
  };
  await Conversation.findByIdAndUpdate(conversation._id, update);
  // Increment unreadCount du destinataire (chaque participant != sender).
  await Conversation.updateOne(
    { _id: conversation._id, 'participants.userId': { $ne: senderId } },
    { $inc: { 'participants.$[other].unreadCount': 1 } },
    { arrayFilters: [{ 'other.userId': { $ne: senderId } }] },
  );
  // Notif push au(x) destinataire(s).
  try {
    const { sendNotification } = require('../services/notificationSender');
    // v566 — audit notifications : `senderName` manquait → titre « Nouveau message de »
    // troué (push, cloche, e-mail) pour le chat amis / famille.
    let senderName = '';
    try {
      const sr = String(senderRole || '').toLowerCase();
      const order = sr === 'sitter' ? [Sitter, Owner, Walker] : sr === 'walker' ? [Walker, Owner, Sitter] : [Owner, Sitter, Walker];
      for (const M of order) {
        const doc = M ? await M.findById(senderId).select('name').lean() : null;
        if (doc && doc.name) { senderName = String(doc.name).trim(); break; }
      }
    } catch (_) {/* le serveur complète à défaut (ensureSenderName) */}
    for (const p of (conversation.participants || [])) {
      if (String(p.userId) === String(senderId)) continue;
      const roleLower = String(p.userModel || 'Owner').toLowerCase();
      sendNotification({
        userId: String(p.userId),
        role: roleLower,
        type: 'NEW_MESSAGE',
        data: {
          conversationId: String(conversation._id),
          messageId: String(msg._id),
          senderName: senderName || 'HoPetSit',
          preview: String(preview || '').slice(0, 120),
        },
        actor: senderRole ? { role: String(senderRole).toLowerCase(), id: senderId } : null,
      }).catch(() => {});
    }
  } catch (_) {/* defensive */}
  // v23.1.276 — Daniel : "sur lapp jecris et sa me met message supprimé".
  // CAUSE : le chat booking renvoyait/émettait le message sous la clé `message`
  // (sanitizé), mais le chat AMI/FAMILLE le renvoyait sous `sentMessage` (brut,
  // sans flag isDeleted). L'app lisait `message` → null pour les amis → body
  // vide → faux "Message supprimé". On harmonise : on SANITIZE et on renvoie
  // les DEUX clés (`message` = canonique comme le booking + `sentMessage` =
  // rétro-compat). Shape homogène : id, body, type, isDeleted=false, createdAt.
  const sanitized = sanitizeMessage(msg);
  const withId = { ...sanitized, id: sanitized.id || String(msg._id) };
  return { message: withId, sentMessage: withId };
};

const createConversationMessage = async (req, res) => {
  try {
    const { id } = req.params;
    const { body, attachments } = req.body;
    // v565 — expéditeur depuis le JWT (le corps ne fait plus foi).
    const { senderRole, senderId } = resolveSender(req);
    // v565 §5 — réponse à un message précis : instantané complet stocké.
    const replyTo = await buildReplySnapshot(id, req.body?.replyTo);

    // v23.1.200 — branch friendChat : pipeline simplifie (pas de check
    // booking-paye, pas de owner-sitter logic). Verifie juste que le
    // sender est participant + save + notif l'autre participant.
    // v23.1 part 227 — on select aussi ownerId/sitterId/walkerId pour que
    // emitChatMessage puisse emit aux user-rooms des 2 participants.
    const convPre = await Conversation.findById(id)
      .select('friendChat participants ownerId sitterId walkerId').lean();
    if (convPre?.friendChat === true) {
      const result = await sendFriendMessage({
        conversation: convPre,
        senderId,
        senderRole,
        body,
        attachments,
        replyTo,
      });
      // v23.1 part 227 — emit aux user-rooms aussi (badge unread).
      emitChatMessage(convPre, 'message:new', {
        conversationId: id,
        triggeredBy: { role: senderRole, userId: senderId },
        ...result,
      });
      return res.status(201).json(result);
    }

    const result = await sendMessage({
      conversationId: id,
      senderRole,
      senderId,
      body,
      attachments,
    });
    if (replyTo) await patchMessageExtras(result, { replyTo });

    // v23.1 part 227 — emit aux user-rooms aussi (Daniel : badge unread
    // qui n'apparaissait pas car les users hors-chat-room ne recevaient
    // pas le message:new).
    emitChatMessage(convPre, 'message:new', {
      conversationId: id,
      triggeredBy: { role: senderRole, userId: senderId },
      ...result,
    });

    res.status(201).json(result);
  } catch (error) {
    logger.error('Create message error', error);
    if (error instanceof HttpError) {
      const body = { error: error.message };
      if (error.code) body.code = error.code;
      if (error.details) body.details = error.details;
      return res.status(error.status).json(body);
    }
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid conversation id.' });
    }
    res.status(500).json({ error: 'Impossible d\'envoyer le message. Veuillez réessayer.' });
  }
};

const createConversationAttachmentMessage = async (req, res) => {
  try {
    const { id } = req.params;
    const { body, folder } = req.body || {};
    const files = Array.isArray(req.files) ? req.files : [];
    // v565 — expéditeur depuis le JWT (les champs multipart ne font plus foi ;
    // AVANT un multipart sans senderRole/senderId prenait 400).
    const { senderRole, senderId } = resolveSender(req);
    if (!senderRole || !senderId) {
      return res.status(400).json({ error: 'senderRole and senderId are required.' });
    }

    if (files.length === 0) {
      return res.status(400).json({ error: 'At least one file is required.' });
    }

    // v565 §5 — kind=voice (1 fichier audio) | media (défaut : photos/vidéos).
    const kind = String(req.body?.kind || 'media').toLowerCase() === 'voice' ? 'voice' : 'media';
    await assertChatFeature(kind === 'voice' ? 'voice' : 'media');
    const replyTo = await buildReplySnapshot(id, req.body?.replyTo);
    const isAudioFile = (f) =>
      /^audio\//i.test(f.mimetype || '') ||
      /\.(m4a|aac|mp3|wav|ogg|opus|caf)$/i.test(f.originalname || '');
    if (kind === 'voice') {
      if (files.length !== 1) {
        return res.status(400).json({ error: 'A voice message must contain exactly one audio file.' });
      }
      if (!isAudioFile(files[0])) {
        return res.status(400).json({ error: 'Voice message must be an audio file (.m4a / .aac).' });
      }
    }
    const durationRaw = Number(req.body?.duration);
    const duration = Number.isFinite(durationRaw) && durationRaw > 0 ? Math.round(durationRaw * 100) / 100 : null;

    const uploadFolder =
      typeof folder === 'string' && folder.trim()
        ? folder.trim()
        : `petsinsta/conversations/${id}`;

    // Cloudinary : l'audio ET la vidéo passent par resource_type 'video' ;
    // la transformation `strip_profile` (EXIF) n'a de sens que pour les images
    // et fait échouer/ralentir l'upload des médias non-image → retirée pour eux.
    const uploads = await Promise.all(
      files.map((file) => {
        const isVideo = /^video\//i.test(file.mimetype || '');
        const isAudio = isAudioFile(file);
        const nonImage = isVideo || isAudio || kind === 'voice';
        return uploadMedia({
          file: bufferToDataUri(file),
          folder: uploadFolder,
          resourceType: nonImage ? 'video' : (/^image\//i.test(file.mimetype || '') ? 'image' : 'auto'),
          options: nonImage
            ? { transformation: undefined, image_metadata: undefined, quality_analysis: undefined }
            : {},
        }).then((up) => (isAudio || kind === 'voice'
          ? { ...up, resourceType: 'audio', duration: duration ?? up.duration ?? null, thumbnailUrl: '' }
          : up));
      })
    );

    // Session v3.3 — moderate image attachments with Google Vision. Only
    // images trigger the check; videos are not supported by Vision Safe
    // Search yet. When flagged, the asset is destroyed on Cloudinary and
    // the whole message is rejected with 422.
    const { rejectIfUnsafe } = require('../services/contentModerationService');
    for (const up of uploads) {
      if (!up || up.resourceType === 'video' || up.resourceType === 'audio') continue;
      try {
        await rejectIfUnsafe(up);
      } catch (modErr) {
        if (modErr.code === 'CONTENT_REJECTED') {
          return res.status(422).json({
            error: modErr.message,
            code: modErr.code,
            details: modErr.details,
          });
        }
        throw modErr;
      }
    }

    const attachmentPayload = uploads.map(mapUploadToAttachment);
    const msgType = kind === 'voice' ? 'voice' : undefined;

    // v565 — chat AMI/FAMILLE : AVANT, les pièces jointes passaient par
    // conversationService.sendMessage (pipeline booking : ownerId/sitterId)
    // → 403 « not part of this conversation » sur toute conversation amie →
    // « l'envoi de photos/vidéos ne marche pas ». On route vers le pipeline ami.
    const convForEmit = await Conversation.findById(id)
      .select('friendChat participants ownerId sitterId walkerId').lean();
    let result;
    if (convForEmit?.friendChat === true) {
      result = await sendFriendMessage({
        conversation: convForEmit,
        senderId,
        senderRole,
        body,
        attachments: attachmentPayload,
        type: msgType,
        replyTo,
      });
    } else if (kind === 'voice') {
      result = await persistBookingAttachmentMessage({
        conversation: convForEmit,
        senderRole,
        senderId,
        body,
        attachments: attachmentPayload,
        type: 'voice',
        replyTo,
      });
    } else {
      result = await sendMessage({
        conversationId: id,
        senderRole,
        senderId,
        body,
        attachments: attachmentPayload,
      });
      if (replyTo) await patchMessageExtras(result, { replyTo });
    }

    // v23.1 part 227 — emit user-rooms + conv-room (payload : message avec
    // replyTo / type / attachments[].resourceType — contrat §5).
    emitChatMessage(convForEmit, 'message:new', {
      conversationId: id,
      triggeredBy: { role: senderRole, userId: senderId },
      ...result,
    });

    res.status(201).json(result);
  } catch (error) {
    logger.error('Create attachment message error', error);
    if (error instanceof HttpError) {
      const body = { error: error.message };
      if (error.code) body.code = error.code;
      if (error.details) body.details = error.details;
      return res.status(error.status).json(body);
    }
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid conversation id.' });
    }
    if (error.message && error.message.includes('Cloudinary')) {
      return res.status(502).json({ error: 'Unable to upload attachment. Please try again later.' });
    }
    res.status(500).json({ error: 'Unable to send message with attachment. Please try again later.' });
  }
};

const markConversationRead = async (req, res) => {
  try {
    const { id } = req.params;
    // v23.1 part 127 — Phase 3 audit P3-28/P3-41 : auth ajoutée au
    // router. Le role + userId proviennent du JWT, plus du body — sinon
    // n'importe qui pouvait reset le compteur unread d'un autre user.
    const role = req.user?.role;
    const userId = req.user?.id;
    if (!role || !userId) {
      return res.status(401).json({ error: 'Authentication required.' });
    }

    const { conversation, updated } = await markConversationReadService({
      conversationId: id,
      role,
      userId,
    });

    // v566 — « lu » façon WhatsApp : readAt sur tous les messages de l'autre
    // partie encore non lus + `message:read` à l'expéditeur. Indépendant du
    // compteur (`updated`) : le compteur peut déjà être à 0 (remis à zéro par
    // GET /messages) alors que les messages ne sont pas encore marqués lus.
    // Idempotent : rien à marquer → aucune écriture, aucune émission.
    const read = await receipts.safely(
      'markMessagesRead',
      receipts.markMessagesRead({ conversationId: id, readerId: userId }),
    );
    const readInfo = { readCount: read?.count || 0, readAt: read?.readAt || null };

    if (updated) {
      emitToConversation(
        id,
        'conversation:read',
        {
          conversationId: id,
          conversation,
          triggeredBy: { role, userId },
        },
        {
          exclude: [{ role, userId }],
        }
      );
    }

    if (updated) {
      res.json({ updated: true, conversation, ...readInfo });
    } else {
      res.json({ updated: false, ...readInfo });
    }
  } catch (error) {
    logger.error('Mark conversation read error', error);
    if (error instanceof HttpError) {
      return res.status(error.status).json({ error: error.message });
    }
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid conversation id.' });
    }
    res.status(500).json({ error: 'Unable to mark conversation as read. Please try again later.' });
  }
};

const startConversation = async (req, res) => {
  try {
    const ownerId = req.user?.id;
    const userRole = req.user?.role;
    // v18.8 — owner peut maintenant démarrer une conversation avec
    // sitter OU walker. Le param walkerId (query ou body) a la priorité
    // pour décider le type de provider cible.
    const walkerIdParam = req.query.walkerId || req.body?.walkerId || null;
    const { sitterId } = req.query;
    const { message } = req.body;
    const targetWalker = walkerIdParam && mongoose.Types.ObjectId.isValid(walkerIdParam);

    // Validate authentication
    if (!ownerId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (userRole !== 'owner') {
      return res.status(403).json({ error: 'Only owners can start conversations with providers.' });
    }

    // v18.9 — message optionnel : ouvrir un chat sans message pré-rempli.
    // Avant, l'app envoyait "Hello, I'm interested in your services!" en
    // anglais à chaque tap sur Discussion → spam dans le fil.
    const trimmedMsgCheck = typeof message === 'string' ? message.trim() : '';

    if (!targetWalker) {
      // Path sitter (inchangé).
      if (!sitterId) {
        return res.status(400).json({ error: 'Sitter ID is required in query parameters.' });
      }
      if (!mongoose.Types.ObjectId.isValid(sitterId)) {
        return res.status(400).json({ error: 'Invalid sitter ID format.' });
      }
      const sitter = await Sitter.findById(sitterId);
      if (!sitter) {
        return res.status(404).json({ error: 'Sitter not found.' });
      }
    } else {
      // Path walker : vérifie que le walker existe.
      if (!Walker) {
        return res.status(400).json({ error: 'Walker support is not enabled on this server.' });
      }
      const walker = await Walker.findById(walkerIdParam);
      if (!walker) {
        return res.status(404).json({ error: 'Walker not found.' });
      }
    }

    // Check if owner exists
    const owner = await Owner.findById(ownerId);
    if (!owner) {
      return res.status(404).json({ error: 'Owner not found.' });
    }

    // Check if blocked
    const otherProviderId = targetWalker ? walkerIdParam : sitterId;
    const otherProviderModel = targetWalker ? 'Walker' : 'Sitter';
    const isBlocked = await Block.exists({
      $or: [
        {
          blockerId: ownerId,
          blockerModel: 'Owner',
          blockedId: otherProviderId,
          blockedModel: otherProviderModel,
        },
        {
          blockerId: otherProviderId,
          blockerModel: otherProviderModel,
          blockedId: ownerId,
          blockedModel: 'Owner',
        },
      ],
    });

    if (isBlocked) {
      return res.status(403).json({ error: 'Messaging is disabled because one user has been blocked.' });
    }

    // Session v3.2 — chat gate:
    //   * Paid booking between owner & provider → OK (historical support chat).
    //   * Else if owner has Premium OR Chat add-on → OK (pre-booking / friend chat).
    //   * Else → 402 CHAT_ACCESS_REQUIRED with upsell hints.
    const hasPaidBooking = targetWalker
      ? await hasValidPaidBooking(ownerId, null, walkerIdParam)
      : await hasValidPaidBooking(ownerId, sitterId);
    if (!hasPaidBooking) {
      const access = await getChatAccess(ownerId, 'Owner');
      if (!access.hasAny) {
        return res.status(402).json({
          error:
            'Chat requires an active Premium plan or the Chat add-on. Please subscribe to start messaging.',
          code: 'CHAT_ACCESS_REQUIRED',
          details: {
            needsPremium: !access.hasPremium,
            needsChatAddon: !access.hasChatAddon,
            upgradeUrl: '/subscriptions/plans',
            addonUrl: '/chat-addon/plans',
          },
        });
      }
    }

    // Find or create conversation
    const convoQuery = targetWalker
      ? { ownerId: ownerId, walkerId: walkerIdParam }
      : { ownerId: ownerId, sitterId: sitterId };
    let conversation = await Conversation.findOne(convoQuery)
      .populate('ownerId')
      .populate('sitterId')
      .populate('walkerId');

    if (!conversation) {
      const convoCreate = targetWalker
        ? {
            ownerId,
            walkerId: walkerIdParam,
            ownerUnreadCount: 0,
            sitterUnreadCount: 0,
          }
        : {
            ownerId,
            sitterId,
            ownerUnreadCount: 0,
            sitterUnreadCount: 0,
          };
      conversation = await Conversation.create(convoCreate);
      await conversation.populate(['ownerId', 'sitterId', 'walkerId']);
    }

    // v18.9 — ne crée un Message QUE si le body est non-vide. Sinon on
    // renvoie juste la conversation.
    // v23.1 — idempotency : if the same owner already posted the exact
    // same body in the last 60 seconds, do NOT create a duplicate message.
    // This prevented the chat opener (`payment_chat_opener_message`) from
    // being posted 3 times when the user navigated back to the post-payment
    // screen multiple times.
    let newMessage = null;
    if (trimmedMsgCheck) {
      const sixtySecondsAgo = new Date(Date.now() - 60 * 1000);
      const recentDuplicate = await Message.findOne({
        conversationId: conversation._id,
        senderRole: 'owner',
        senderId: ownerId,
        body: trimmedMsgCheck,
        createdAt: { $gte: sixtySecondsAgo },
      })
        .sort({ createdAt: -1 })
        .lean();
      if (recentDuplicate) {
        // Skip create — return the conversation as if the message was sent.
        await conversation.populate(['ownerId', 'sitterId', 'walkerId']);
        return res.status(201).json({
          message: 'Conversation started successfully.',
          conversation: sanitizeConversation(conversation),
          duplicateSkipped: true,
        });
      }
      newMessage = await Message.create({
        conversationId: conversation._id,
        senderRole: 'owner',
        senderId: ownerId,
        body: trimmedMsgCheck,
        attachments: [],
      });
      conversation.lastMessage = trimmedMsgCheck;
      // v575 — audit P2-1 : message texte → aucune nature à traduire.
      conversation.lastMessageKind = '';
      conversation.lastMessageAt = new Date();
      // v23.1.255 — un nouveau message fait RÉAPPARAÎTRE la conversation chez
      // quiconque l'avait masquée (soft-delete) → "la personne me réécrit, ça
      // rouvre la conversation".
      conversation.clearedFor = [];
      conversation.sitterUnreadCount = (conversation.sitterUnreadCount || 0) + 1;
      await conversation.save();
      await conversation.populate(['ownerId', 'sitterId', 'walkerId']);
      // v23.1 part 227 — emit aux user-rooms (badge unread).
      emitChatMessage(conversation, 'message:new', {
        conversationId: conversation._id.toString(),
        triggeredBy: { role: 'owner', userId: ownerId },
        message: sanitizeMessage(newMessage),
        conversation: sanitizeConversation(conversation),
      });
    }

    res.status(201).json({
      message: 'Conversation started successfully.',
      conversation: sanitizeConversation(conversation),
      sentMessage: newMessage ? sanitizeMessage(newMessage) : null,
    });
  } catch (error) {
    logger.error('Start conversation error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid ID format.' });
    }
    if (error.code === 11000) {
      // Duplicate key error (conversation already exists)
      // This shouldn't happen due to our findOne check, but handle it gracefully
      return res.status(409).json({ error: 'Conversation already exists.' });
    }
    res.status(500).json({ error: 'Unable to start conversation. Please try again later.' });
  }
};

const startConversationBySitter = async (req, res) => {
  try {
    const sitterId = req.user?.id;
    const userRole = req.user?.role;
    const { ownerId } = req.query;
    const { message } = req.body;

    // Validate authentication
    if (!sitterId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (userRole !== 'sitter') {
      return res.status(403).json({ error: 'Only sitters can start conversations with owners.' });
    }

    // Validate ownerId
    if (!ownerId) {
      return res.status(400).json({ error: 'Owner ID is required in query parameters.' });
    }

    // v18.9 — message optionnel.
    const trimmedMsgCheckS = typeof message === 'string' ? message.trim() : '';

    // Validate ownerId format
    if (!mongoose.Types.ObjectId.isValid(ownerId)) {
      return res.status(400).json({ error: 'Invalid owner ID format.' });
    }

    // Check if owner exists
    const owner = await Owner.findById(ownerId);
    if (!owner) {
      return res.status(404).json({ error: 'Owner not found.' });
    }

    // Check if sitter exists
    const sitter = await Sitter.findById(sitterId);
    if (!sitter) {
      return res.status(404).json({ error: 'Sitter not found.' });
    }

    // Check if blocked
    const isBlocked = await Block.exists({
      $or: [
        {
          blockerId: ownerId,
          blockerModel: 'Owner',
          blockedId: sitterId,
          blockedModel: 'Sitter',
        },
        {
          blockerId: sitterId,
          blockerModel: 'Sitter',
          blockedId: ownerId,
          blockedModel: 'Owner',
        },
      ],
    });

    if (isBlocked) {
      return res.status(403).json({ error: 'Messaging is disabled because one user has been blocked.' });
    }

    // Session v3.2 — same chat gate as owner-side (see startConversation).
    const hasPaidBooking = await hasValidPaidBooking(ownerId, sitterId);
    if (!hasPaidBooking) {
      const access = await getChatAccess(sitterId, 'Sitter');
      if (!access.hasAny) {
        return res.status(402).json({
          error:
            'Chat requires an active Premium plan or the Chat add-on. Please subscribe to start messaging.',
          code: 'CHAT_ACCESS_REQUIRED',
          details: {
            needsPremium: !access.hasPremium,
            needsChatAddon: !access.hasChatAddon,
            upgradeUrl: '/subscriptions/plans',
            addonUrl: '/chat-addon/plans',
          },
        });
      }
    }

    // Find or create conversation
    let conversation = await Conversation.findOne({
      ownerId: ownerId,
      sitterId: sitterId,
    })
      .populate('ownerId')
      .populate('sitterId');

    if (!conversation) {
      // Create new conversation
      conversation = await Conversation.create({
        ownerId: ownerId,
        sitterId: sitterId,
        ownerUnreadCount: 0,
        sitterUnreadCount: 0,
      });
      await conversation.populate(['ownerId', 'sitterId']);
    }

    // v18.9 — Message créé UNIQUEMENT si le body est non-vide.
    let newMessage = null;
    if (trimmedMsgCheckS) {
      newMessage = await Message.create({
        conversationId: conversation._id,
        senderRole: 'sitter',
        senderId: sitterId,
        body: trimmedMsgCheckS,
        attachments: [],
      });
      conversation.lastMessage = trimmedMsgCheckS;
      // v575 — audit P2-1 : message texte → aucune nature à traduire.
      conversation.lastMessageKind = '';
      conversation.lastMessageAt = new Date();
      // v23.1.255 — réapparition de la conversation masquée sur nouveau message.
      conversation.clearedFor = [];
      conversation.ownerUnreadCount = (conversation.ownerUnreadCount || 0) + 1;
      await conversation.save();
      await conversation.populate(['ownerId', 'sitterId']);
      // v23.1 part 227 — emit aux user-rooms (badge unread).
      emitChatMessage(conversation, 'message:new', {
        conversationId: conversation._id.toString(),
        triggeredBy: { role: 'sitter', userId: sitterId },
        message: sanitizeMessage(newMessage),
        conversation: sanitizeConversation(conversation),
      });
    }

    res.status(201).json({
      message: 'Conversation started successfully.',
      conversation: sanitizeConversation(conversation),
      sentMessage: newMessage ? sanitizeMessage(newMessage) : null,
    });
  } catch (error) {
    logger.error('Start conversation by sitter error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid ID format.' });
    }
    if (error.code === 11000) {
      // Duplicate key error (conversation already exists)
      // This shouldn't happen due to our findOne check, but handle it gracefully
      return res.status(409).json({ error: 'Conversation already exists.' });
    }
    res.status(500).json({ error: 'Unable to start conversation. Please try again later.' });
  }
};

// v18.8 — walker démarre une conversation avec un owner (miroir de
// startConversationBySitter). Utilise le schéma XOR : on set walkerId
// au lieu de sitterId sur la Conversation.
const startConversationByWalker = async (req, res) => {
  try {
    const walkerId = req.user?.id;
    const userRole = req.user?.role;
    const { ownerId } = req.query;
    const { message } = req.body;

    if (!walkerId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }
    if (userRole !== 'walker') {
      return res.status(403).json({ error: 'Only walkers can start conversations with owners.' });
    }
    if (!ownerId) {
      return res.status(400).json({ error: 'Owner ID is required in query parameters.' });
    }
    // v18.9 — message optionnel.
    const trimmedMsgCheckW = typeof message === 'string' ? message.trim() : '';
    if (!mongoose.Types.ObjectId.isValid(ownerId)) {
      return res.status(400).json({ error: 'Invalid owner ID format.' });
    }

    const owner = await Owner.findById(ownerId);
    if (!owner) {
      return res.status(404).json({ error: 'Owner not found.' });
    }
    if (!Walker) {
      return res.status(400).json({ error: 'Walker support is not enabled on this server.' });
    }
    const walker = await Walker.findById(walkerId);
    if (!walker) {
      return res.status(404).json({ error: 'Walker not found.' });
    }

    const isBlocked = await Block.exists({
      $or: [
        { blockerId: ownerId, blockerModel: 'Owner', blockedId: walkerId, blockedModel: 'Walker' },
        { blockerId: walkerId, blockerModel: 'Walker', blockedId: ownerId, blockedModel: 'Owner' },
      ],
    });
    if (isBlocked) {
      return res.status(403).json({ error: 'Messaging is disabled because one user has been blocked.' });
    }

    // Chat gate : paid booking (owner ↔ walker) OR premium/chat addon.
    const hasPaidBooking = await hasValidPaidBooking(ownerId, null, walkerId);
    if (!hasPaidBooking) {
      const access = await getChatAccess(walkerId, 'Walker');
      if (!access.hasAny) {
        return res.status(402).json({
          error:
            'Chat requires an active Premium plan or the Chat add-on. Please subscribe to start messaging.',
          code: 'CHAT_ACCESS_REQUIRED',
          details: {
            needsPremium: !access.hasPremium,
            needsChatAddon: !access.hasChatAddon,
            upgradeUrl: '/subscriptions/plans',
            addonUrl: '/chat-addon/plans',
          },
        });
      }
    }

    let conversation = await Conversation.findOne({ ownerId, walkerId })
      .populate('ownerId')
      .populate('walkerId');

    if (!conversation) {
      conversation = await Conversation.create({
        ownerId,
        walkerId,
        ownerUnreadCount: 0,
        sitterUnreadCount: 0,
      });
      await conversation.populate(['ownerId', 'walkerId']);
    }

    let newMessage = null;
    if (trimmedMsgCheckW) {
      newMessage = await Message.create({
        conversationId: conversation._id,
        senderRole: 'walker',
        senderId: walkerId,
        body: trimmedMsgCheckW,
        attachments: [],
      });
      conversation.lastMessage = trimmedMsgCheckW;
      // v575 — audit P2-1 : message texte → aucune nature à traduire.
      conversation.lastMessageKind = '';
      conversation.lastMessageAt = new Date();
      // v23.1.255 — réapparition de la conversation masquée sur nouveau message.
      conversation.clearedFor = [];
      conversation.ownerUnreadCount = (conversation.ownerUnreadCount || 0) + 1;
      await conversation.save();
      await conversation.populate(['ownerId', 'walkerId']);
      // v23.1 part 227 — emit aux user-rooms (badge unread).
      emitChatMessage(conversation, 'message:new', {
        conversationId: conversation._id.toString(),
        triggeredBy: { role: 'walker', userId: walkerId },
        message: sanitizeMessage(newMessage),
        conversation: sanitizeConversation(conversation),
      });
    }

    res.status(201).json({
      message: 'Conversation started successfully.',
      conversation: sanitizeConversation(conversation),
      sentMessage: newMessage ? sanitizeMessage(newMessage) : null,
    });
  } catch (error) {
    logger.error('Start conversation by walker error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid ID format.' });
    }
    if (error.code === 11000) {
      return res.status(409).json({ error: 'Conversation already exists.' });
    }
    res.status(500).json({ error: 'Unable to start conversation. Please try again later.' });
  }
};

/**
 * v23.1.200 — Daniel : "bouton 💬 sur friend + family member pour
 * ouvrir un chat 1-to-1 avec un ami". POST /api/v1/conversations/friend
 *
 * Body : { targetUserId, targetUserRole }
 * Permission : friendship 'accepted' OU meme famille PawFollow.
 * Behavior : cree ou retourne la conversation friendChat existante
 * entre les 2 users (idempotent).
 */
const startFriendConversation = async (req, res) => {
  try {
    const myId = req.user?.id;
    const myRole = req.user?.role;
    if (!myId || !myRole) {
      return res.status(401).json({ error: 'Authentication required.' });
    }
    const { targetUserId, targetUserRole } = req.body || {};
    if (!targetUserId || !targetUserRole) {
      return res.status(400).json({
        error: 'targetUserId and targetUserRole are required.',
      });
    }
    if (String(targetUserId) === String(myId)) {
      return res.status(400).json({ error: 'Cannot chat with yourself.' });
    }

    const ROLE_TO_MODEL = { owner: 'Owner', sitter: 'Sitter', walker: 'Walker' };
    const myModel = ROLE_TO_MODEL[String(myRole).toLowerCase()];
    const targetModel = ROLE_TO_MODEL[String(targetUserRole).toLowerCase()];
    if (!myModel || !targetModel) {
      return res.status(400).json({ error: 'Invalid role.' });
    }

    // Permission : friendship 'accepted' OU meme famille PawFollow.
    const Friendship = require('../models/Friendship');
    const friendship = await Friendship.findOne({
      $or: [
        {
          requesterId: myId, requesterModel: myModel,
          addresseeId: targetUserId, addresseeModel: targetModel,
        },
        {
          requesterId: targetUserId, requesterModel: targetModel,
          addresseeId: myId, addresseeModel: myModel,
        },
      ],
      status: 'accepted',
    }).lean();
    let allowed = !!friendship;
    if (!allowed) {
      try {
        const { isInSameFamily } = require('../models/UserSubscription');
        allowed = await isInSameFamily(myId, targetUserId);
      } catch (_) {/* defensive */}
    }
    if (!allowed) {
      return res.status(403).json({
        error: 'You must be friends or in the same PawFollow Family to chat.',
        code: 'NOT_FRIENDS',
      });
    }

    // Idempotent : cherche une conv friendChat existante avec ces 2
    // participants (ordre indifferent).
    // v23.1.255 — Daniel : "si j'écris depuis l'onglet amis/famille, ça
    // ouvre une NOUVELLE conversation alors qu'une existe déjà". CAUSE :
    // participants.userId est un ObjectId mais le $all recevait des STRINGS
    // (myId/targetUserId viennent du JWT/body en string). Le cast Mongoose
    // sur un $all ciblant un sous-champ d'array n'est pas garanti → aucun
    // match → une conv friendChat en DOUBLON créée à chaque tap. FIX : cast
    // explicite en ObjectId pour garantir le match → réutilisation de la
    // conversation existante au lieu d'en créer une nouvelle.
    const toOid = (v) => {
      try {
        return new mongoose.Types.ObjectId(String(v));
      } catch (_) {
        return v;
      }
    };
    const myOid = toOid(myId);
    const targetOid = toOid(targetUserId);
    const existing = await Conversation.findOne({
      friendChat: true,
      'participants.userId': { $all: [myOid, targetOid] },
    });
    if (existing) {
      return res.status(200).json({
        conversation: sanitizeConversation(existing),
        existed: true,
      });
    }

    const conv = new Conversation({
      friendChat: true,
      participants: [
        { userId: myId, userModel: myModel, unreadCount: 0 },
        { userId: targetUserId, userModel: targetModel, unreadCount: 0 },
      ],
      lastMessage: '',
      lastMessageAt: new Date(),
    });
    await conv.save();

    return res.status(201).json({
      conversation: sanitizeConversation(conv),
      existed: false,
    });
  } catch (e) {
    logger.error('startFriendConversation error', e);
    return res.status(500).json({ error: 'Unable to start chat.' });
  }
};

module.exports = {
  // v565 §5 — réutilisés par chatSocket.
  buildReplySnapshot,
  patchMessageExtras,
  assertChatFeature,
  resolveSender,
  listConversations,
  getChatList,
  getConversationMessages,
  createConversationMessage,
  createConversationAttachmentMessage,
  markConversationRead,
  startConversation,
  startConversationBySitter,
  startConversationByWalker,
  startFriendConversation,
};

