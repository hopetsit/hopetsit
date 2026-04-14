const mongoose = require('mongoose');
const Conversation = require('../models/Conversation');
const Message = require('../models/Message');
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Block = require('../models/Block');
const Booking = require('../models/Booking');
const { sanitizeConversation, sanitizeMessage } = require('../utils/sanitize');
const {
  sendMessage,
  markConversationRead: markConversationReadService,
  hasValidPaidBooking,
} = require('../services/conversationService');
const { uploadMedia } = require('../services/cloudinary');
const { HttpError } = require('../utils/errors');
const { emitToConversation } = require('../sockets/emitter');

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
    console.error('Fetch conversations error', error);
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

    if (!userRole || !['owner', 'sitter'].includes(userRole.toLowerCase())) {
      return res.status(400).json({ error: 'Invalid user role. Expected "owner" or "sitter".' });
    }

    const normalizedRole = userRole.toLowerCase();
    const query = normalizedRole === 'owner' ? { ownerId: userId } : { sitterId: userId };

    const conversations = await Conversation.find(query)
      .sort({ updatedAt: -1 })
      .populate('ownerId', 'name email avatar')
      .populate('sitterId', 'name email avatar');

    // Enhance conversations with user details
    const enhancedConversations = conversations.map((conversation) => {
      const sanitized = sanitizeConversation(conversation);
      
      // Get the other party's information (not the current user)
      let otherParty = null;
      if (normalizedRole === 'owner') {
        const sitter = conversation.sitterId;
        if (sitter) {
          otherParty = {
            id: sitter._id?.toString() || '',
            name: sitter.name || '',
            email: sitter.email || '',
            avatar: sitter.avatar?.url || '',
            role: 'sitter',
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
    });

    res.json({ 
      conversations: enhancedConversations,
      count: enhancedConversations.length,
    });
  } catch (error) {
    console.error('Get chat list error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid user id.' });
    }
    res.status(500).json({ error: 'Unable to fetch chat list. Please try again later.' });
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

    const ownerIdValue = conversation.ownerId && conversation.ownerId._id
      ? conversation.ownerId._id.toString()
      : conversation.ownerId.toString();
    const sitterIdValue = conversation.sitterId && conversation.sitterId._id
      ? conversation.sitterId._id.toString()
      : conversation.sitterId.toString();

    if (
      (role === 'owner' && ownerIdValue !== userId) ||
      (role === 'sitter' && sitterIdValue !== userId)
    ) {
      return res.status(403).json({ error: 'Access denied for this conversation.' });
    }

    const messages = await Message.find({ conversationId: conversation._id }).sort({ createdAt: 1 });

    res.json({ messages: messages.map(sanitizeMessage) });
  } catch (error) {
    console.error('Fetch messages error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid conversation id.' });
    }
    res.status(500).json({ error: 'Unable to fetch messages. Please try again later.' });
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
    console.error('Create message error', error);
    if (error instanceof HttpError) {
      return res.status(error.status).json({ error: error.message });
    }
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid conversation id.' });
    }
    res.status(500).json({ error: 'Unable to send message. Please try again later.' });
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
    console.error('Create attachment message error', error);
    if (error instanceof HttpError) {
      return res.status(error.status).json({ error: error.message });
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
    console.error('Mark conversation read error', error);
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
    const { sitterId } = req.query;
    const { message } = req.body;

    // Validate authentication
    if (!ownerId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (userRole !== 'owner') {
      return res.status(403).json({ error: 'Only owners can start conversations with sitters.' });
    }

    // Validate sitterId
    if (!sitterId) {
      return res.status(400).json({ error: 'Sitter ID is required in query parameters.' });
    }

    // Validate message
    if (!message || typeof message !== 'string' || !message.trim()) {
      return res.status(400).json({ error: 'Message is required in request body.' });
    }

    // Validate sitterId format
    if (!mongoose.Types.ObjectId.isValid(sitterId)) {
      return res.status(400).json({ error: 'Invalid sitter ID format.' });
    }

    // Check if sitter exists
    const sitter = await Sitter.findById(sitterId);
    if (!sitter) {
      return res.status(404).json({ error: 'Sitter not found.' });
    }

    // Check if owner exists
    const owner = await Owner.findById(ownerId);
    if (!owner) {
      return res.status(404).json({ error: 'Owner not found.' });
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

    // Check if there's a valid paid booking between owner and sitter
    const hasPaidBooking = await hasValidPaidBooking(ownerId, sitterId);
    if (!hasPaidBooking) {
      return res.status(403).json({ 
        error: 'Chat is only available after payment is completed. Please complete a booking payment first.' 
      });
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

    // Send the first message
    const trimmedMessage = message.trim();
    const newMessage = await Message.create({
      conversationId: conversation._id,
      senderRole: 'owner',
      senderId: ownerId,
      body: trimmedMessage,
      attachments: [],
    });

    // Update conversation with last message
    conversation.lastMessage = trimmedMessage;
    conversation.lastMessageAt = new Date();
    conversation.sitterUnreadCount = (conversation.sitterUnreadCount || 0) + 1;
    await conversation.save();
    await conversation.populate(['ownerId', 'sitterId']);

    // Emit socket event for real-time updates
    emitToConversation(conversation._id.toString(), 'message:new', {
      conversationId: conversation._id.toString(),
      triggeredBy: { role: 'owner', userId: ownerId },
      message: sanitizeMessage(newMessage),
      conversation: sanitizeConversation(conversation),
    });

    res.status(201).json({
      message: 'Conversation started successfully.',
      conversation: sanitizeConversation(conversation),
      sentMessage: sanitizeMessage(newMessage),
    });
  } catch (error) {
    console.error('Start conversation error', error);
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

    // Validate message
    if (!message || typeof message !== 'string' || !message.trim()) {
      return res.status(400).json({ error: 'Message is required in request body.' });
    }

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

    // Check if there's a valid paid booking between owner and sitter
    const hasPaidBooking = await hasValidPaidBooking(ownerId, sitterId);
    if (!hasPaidBooking) {
      return res.status(403).json({ 
        error: 'Chat is only available after payment is completed. Please complete a booking payment first.' 
      });
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

    // Send the first message
    const trimmedMessage = message.trim();
    const newMessage = await Message.create({
      conversationId: conversation._id,
      senderRole: 'sitter',
      senderId: sitterId,
      body: trimmedMessage,
      attachments: [],
    });

    // Update conversation with last message
    conversation.lastMessage = trimmedMessage;
    conversation.lastMessageAt = new Date();
    conversation.ownerUnreadCount = (conversation.ownerUnreadCount || 0) + 1;
    await conversation.save();
    await conversation.populate(['ownerId', 'sitterId']);

    // Emit socket event for real-time updates
    emitToConversation(conversation._id.toString(), 'message:new', {
      conversationId: conversation._id.toString(),
      triggeredBy: { role: 'sitter', userId: sitterId },
      message: sanitizeMessage(newMessage),
      conversation: sanitizeConversation(conversation),
    });

    res.status(201).json({
      message: 'Conversation started successfully.',
      conversation: sanitizeConversation(conversation),
      sentMessage: sanitizeMessage(newMessage),
    });
  } catch (error) {
    console.error('Start conversation by sitter error', error);
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

module.exports = {
  listConversations,
  getChatList,
  getConversationMessages,
  createConversationMessage,
  createConversationAttachmentMessage,
  markConversationRead,
  startConversation,
  startConversationBySitter,
};

