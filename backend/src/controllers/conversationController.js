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
const { emitToConversation } = require('../sockets/emitter');
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
    let query;
    if (normalizedRole === 'owner') {
      query = { ownerId: userId };
    } else if (normalizedRole === 'walker') {
      query = { walkerId: userId };
    } else {
      query = { sitterId: userId };
    }

    const conversations = await Conversation.find(query)
      .sort({ updatedAt: -1 })
      .populate('ownerId', 'name email avatar')
      .populate('sitterId', 'name email avatar')
      .populate('walkerId', 'name email avatar');

    // Enhance conversations with user details
    const enhancedConversations = conversations.map((conversation) => {
      const sanitized = sanitizeConversation(conversation);

      // Get the other party's information (not the current user)
      let otherParty = null;
      if (normalizedRole === 'owner') {
        // Owner's other party = sitter or walker (whichever is set)
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
        // Sitter/walker's other party = owner
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
    });

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
    const { role, userId } = req.query;

    if (!role || !userId) {
      return res.status(400).json({ error: 'role and userId are required.' });
    }

    const conversation = await Conversation.findById(id);
    if (!conversation) {
      return res.status(404).json({ error: 'Conversation not found.' });
    }

    // v18.7 — walker-aware : conversation peut être sitter-convo OU walker-convo.
    // Avant v18.7, si walker, conversation.sitterId était null → crash
    // sur .toString() → 500 "Unable to fetch messages".
    const idToString = (v) =>
      v ? (v._id ? v._id.toString() : v.toString()) : null;

    const ownerIdValue = idToString(conversation.ownerId);
    const sitterIdValue = idToString(conversation.sitterId);
    const walkerIdValue = idToString(conversation.walkerId);

    const accessOk =
      (role === 'owner' && ownerIdValue === userId) ||
      (role === 'sitter' && sitterIdValue === userId) ||
      (role === 'walker' && walkerIdValue === userId);

    if (!accessOk) {
      return res.status(403).json({ error: 'Access denied for this conversation.' });
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

const createConversationMessage = async (req, res) => {
  try {
    const { id } = req.params;
    const { senderRole, senderId, body, attachments } = req.body;

    const result = await sendMessage({
      conversationId: id,
      senderRole,
      senderId,
      body,
      attachments,
    });

    emitToConversation(id, 'message:new', {
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

    emitToConversation(id, 'message:new', {
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
    const { role, userId } = req.body;

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
    let newMessage = null;
    if (trimmedMsgCheck) {
      newMessage = await Message.create({
        conversationId: conversation._id,
        senderRole: 'owner',
        senderId: ownerId,
        body: trimmedMsgCheck,
        attachments: [],
      });
      conversation.lastMessage = trimmedMsgCheck;
      conversation.lastMessageAt = new Date();
      conversation.sitterUnreadCount = (conversation.sitterUnreadCount || 0) + 1;
      await conversation.save();
      await conversation.populate(['ownerId', 'sitterId', 'walkerId']);
      emitToConversation(conversation._id.toString(), 'message:new', {
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
      conversation.ownerUnreadCount = (conversation.ownerUnreadCount || 0) + 1;
      await conversation.save();
      await conversation.populate(['ownerId', 'sitterId']);
      emitToConversation(conversation._id.toString(), 'message:new', {
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
      conversation.ownerUnreadCount = (conversation.ownerUnreadCount || 0) + 1;
      await conversation.save();
      await conversation.populate(['ownerId', 'walkerId']);
      emitToConversation(conversation._id.toString(), 'message:new', {
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
};

