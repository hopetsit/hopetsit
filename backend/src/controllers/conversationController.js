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
      .populate('ownerId', 'name email avatar')
      .populate('sitterId', 'name email avatar')
      .populate('walkerId', 'name email avatar');

    // Enhance conversations with user details
    const enhancedConversations = await Promise.all(
      conversations.map(async (conversation) => {
        const sanitized = sanitizeConversation(conversation);
        let otherParty = null;
        let unread = 0;

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
                .select('name email avatar').lean();
              if (otherDoc) {
                otherParty = {
                  id: otherDoc._id?.toString() || '',
                  name: otherDoc.name || '',
                  email: otherDoc.email || '',
                  avatar: otherDoc.avatar?.url || '',
                  role: ROLE_MODELS[o.userModel] || 'owner',
                };
              } else {
                otherParty = {
                  id: '', name: 'Utilisateur supprimé',
                  email: '', avatar: '', role: 'owner',
                };
              }
            } catch (_) {/* defensive */}
          }
          return { ...sanitized, otherParty, unreadCount: unread };
        }

        // Branch booking classique (legacy).
        if (normalizedRole === 'owner') {
          const provider = conversation.sitterId || conversation.walkerId;
          if (provider) {
            otherParty = {
              id: provider._id?.toString() || '',
              name: provider.name || '',
              email: provider.email || '',
              avatar: provider.avatar?.url || '',
              role: conversation.sitterId ? 'sitter' : 'walker',
            };
          }
        } else {
          const owner = conversation.ownerId;
          if (owner) {
            otherParty = {
              id: owner._id?.toString() || '',
              name: owner.name || '',
              email: owner.email || '',
              avatar: owner.avatar?.url || '',
              role: 'owner',
            };
          }
        }
        return {
          ...sanitized,
          otherParty,
          unreadCount: normalizedRole === 'owner'
            ? conversation.ownerUnreadCount || 0
            : conversation.sitterUnreadCount || 0,
        };
      })
    );

    res.json({ 
      conversations: enhancedConversations,
      count: enhancedConversations.length,
    });
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
  conversation, senderId, senderRole, body, attachments,
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
    type: 'text',
  });
  // Update conversation : lastMessage + unreadCount du destinataire +1.
  const preview = typeof body === 'string' && body.length > 0
    ? body.slice(0, 120)
    : (Array.isArray(attachments) && attachments.length > 0
        ? '📎 Pièce jointe' : '');
  const update = {
    lastMessage: preview,
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
          preview,
        },
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
    const { senderRole, senderId, body, attachments } = req.body;

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
    const { senderRole, senderId, body, folder } = req.body || {};
    const files = Array.isArray(req.files) ? req.files : [];

    if (!senderRole || !senderId) {
      return res.status(400).json({ error: 'senderRole and senderId are required.' });
    }

    if (files.length === 0) {
      return res.status(400).json({ error: 'At least one file is required.' });
    }

    const uploadFolder =
      typeof folder === 'string' && folder.trim()
        ? folder.trim()
        : `petsinsta/conversations/${id}`;

    const uploads = await Promise.all(
      files.map((file) =>
        uploadMedia({
          file: bufferToDataUri(file),
          folder: uploadFolder,
          resourceType: 'auto',
        })
      )
    );

    // Session v3.3 — moderate image attachments with Google Vision. Only
    // images trigger the check; videos are not supported by Vision Safe
    // Search yet. When flagged, the asset is destroyed on Cloudinary and
    // the whole message is rejected with 422.
    const { rejectIfUnsafe } = require('../services/contentModerationService');
    for (const up of uploads) {
      if (!up || up.resourceType === 'video') continue;
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

    const result = await sendMessage({
      conversationId: id,
      senderRole,
      senderId,
      body,
      attachments: attachmentPayload,
    });

    // v23.1 part 227 — fetch conv pour emit user-rooms + conv-room.
    const convForEmit = await Conversation.findById(id)
      .select('friendChat participants ownerId sitterId walkerId').lean();
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
      res.json({ updated: true, conversation });
    } else {
      res.json({ updated: false });
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

