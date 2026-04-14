const Conversation = require('../models/Conversation');
const Message = require('../models/Message');
const Block = require('../models/Block');
const Booking = require('../models/Booking');
const {
  sanitizeConversation,
  sanitizeMessage,
} = require('../utils/sanitize');
const { HttpError } = require('../utils/errors');
const { maskPhonesInText } = require('../utils/phoneMask');
const { decrypt } = require('../utils/encryption');
const { createNotificationSafe } = require('./notificationService');
const { sendNotification } = require('./notificationSender');

const normalizeId = (value) => {
  if (!value) return null;
  if (typeof value === 'string') return value;
  if (value._id) return value._id.toString();
  if (typeof value.toString === 'function') return value.toString();
  return null;
};

const getConversationOrThrow = async (conversationId, { populate = false } = {}) => {
  const query = populate
    ? Conversation.findById(conversationId).populate('ownerId').populate('sitterId')
    : Conversation.findById(conversationId);

  const conversation = await query;

  if (!conversation) {
    throw new HttpError(404, 'Conversation not found.');
  }

  return conversation;
};

const assertParticipant = (conversation, role, userId) => {
  const ownerIdValue = normalizeId(conversation.ownerId);
  const sitterIdValue = normalizeId(conversation.sitterId);

  if (
    (role === 'owner' && ownerIdValue !== userId) ||
    (role === 'sitter' && sitterIdValue !== userId)
  ) {
    throw new HttpError(403, 'User is not part of this conversation.');
  }
};

const ensureRole = (role) => {
  if (!['owner', 'sitter'].includes(role)) {
    throw new HttpError(400, 'Invalid role. Expected "owner" or "sitter".');
  }
};

const ensureNonEmpty = (value, message, status = 400) => {
  if (!value) {
    throw new HttpError(status, message);
  }
};

const sanitizeAttachmentsPayload = (attachments) => {
  if (!Array.isArray(attachments)) {
    return [];
  }
  return attachments
    .map((attachment) => ({
      url: typeof attachment.url === 'string' ? attachment.url.trim() : '',
      publicId: typeof attachment.publicId === 'string' ? attachment.publicId.trim() : '',
      resourceType: typeof attachment.resourceType === 'string' ? attachment.resourceType : 'image',
      format: typeof attachment.format === 'string' ? attachment.format : '',
      bytes:
        typeof attachment.bytes === 'number' && Number.isFinite(attachment.bytes)
          ? attachment.bytes
          : null,
      width:
        typeof attachment.width === 'number' && Number.isFinite(attachment.width)
          ? attachment.width
          : null,
      height:
        typeof attachment.height === 'number' && Number.isFinite(attachment.height)
          ? attachment.height
          : null,
      duration:
        typeof attachment.duration === 'number' && Number.isFinite(attachment.duration)
          ? attachment.duration
          : null,
      thumbnailUrl: typeof attachment.thumbnailUrl === 'string' ? attachment.thumbnailUrl : '',
      originalFilename:
        typeof attachment.originalFilename === 'string' ? attachment.originalFilename : '',
    }))
    .filter((attachment) => attachment.url && attachment.publicId);
};

const buildLastMessagePreview = ({ body, attachments }) => {
  if (body) {
    return body;
  }
  if (!attachments || attachments.length === 0) {
    return '';
  }
  if (attachments.length === 1) {
    const [attachment] = attachments;
    if (attachment.resourceType === 'video') {
      return 'Sent a video';
    }
    return 'Sent a photo';
  }
  const videoCount = attachments.filter((item) => item.resourceType === 'video').length;
  const imageCount = attachments.length - videoCount;
  if (videoCount && imageCount) {
    return `Sent ${attachments.length} attachments`;
  }
  if (videoCount === attachments.length) {
    return `Sent ${videoCount} ${videoCount === 1 ? 'video' : 'videos'}`;
  }
  return `Sent ${attachments.length} ${attachments.length === 1 ? 'photo' : 'photos'}`;
};

/**
 * Check if there's at least one valid paid booking between owner and sitter
 * A valid paid booking is one where:
 * - status === 'paid' OR paymentStatus === 'paid'
 * - status !== 'cancelled' AND status !== 'refunded'
 * @param {string} ownerId - Owner ID
 * @param {string} sitterId - Sitter ID
 * @returns {Promise<boolean>} - True if at least one valid paid booking exists
 */
const hasValidPaidBooking = async (ownerId, sitterId) => {
  if (!ownerId || !sitterId) {
    return false;
  }

  // Find a booking where:
  // 1. ownerId and sitterId match
  // 2. Payment is confirmed (status === 'paid' OR paymentStatus === 'paid')
  // 3. Booking is not cancelled or refunded
  const validPaidBooking = await Booking.findOne({
    ownerId: ownerId,
    sitterId: sitterId,
    status: { $nin: ['cancelled', 'refunded'] },
    $or: [
      { status: 'paid' },
      { paymentStatus: 'paid' },
    ],
  });

  return !!validPaidBooking;
};

const sendMessage = async ({ conversationId, senderRole, senderId, body, attachments }) => {
  ensureNonEmpty(conversationId, 'Conversation id is required.');
  ensureNonEmpty(senderRole, 'senderRole is required.');
  ensureNonEmpty(senderId, 'senderId is required.');

  ensureRole(senderRole);

  const conversation = await getConversationOrThrow(conversationId, { populate: true });

  assertParticipant(conversation, senderRole, senderId);

  const ownerId = normalizeId(conversation.ownerId);
  const sitterId = normalizeId(conversation.sitterId);

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
    throw new HttpError(403, 'Messaging is disabled because one user has been blocked.');
  }

  // Sprint 6.5 step 3 — canonical rule aligned with middleware: PAYMENT_REQUIRED
  // when no paid booking exists between owner and sitter.
  const hasPaidBooking = await hasValidPaidBooking(ownerId, sitterId);
  if (!hasPaidBooking) {
    const err = new HttpError(403, 'Payment required');
    err.code = 'PAYMENT_REQUIRED';
    throw err;
  }

  const trimmedBody = typeof body === 'string' ? body.trim() : '';
  const normalizedAttachments = sanitizeAttachmentsPayload(attachments);

  if (!trimmedBody && normalizedAttachments.length === 0) {
    throw new HttpError(400, 'Message body or attachments are required.');
  }

  // Sprint 3 step 6 belt-and-suspenders: mask any phone number in messages
  // when the booking is not paid. Today the check above already rejects
  // unpaid chat, but masking here enforces the rule at the service layer so
  // future changes in the gating policy can't leak phone numbers.
  const effectiveBody = hasPaidBooking ? trimmedBody : maskPhonesInText(trimmedBody);

  const message = await Message.create({
    conversationId: conversation._id,
    senderRole,
    senderId,
    body: effectiveBody,
    attachments: normalizedAttachments,
  });

  conversation.lastMessage = buildLastMessagePreview({
    body: trimmedBody,
    attachments: normalizedAttachments,
  });
  conversation.lastMessageAt = new Date();
  if (senderRole === 'owner') {
    conversation.sitterUnreadCount = (conversation.sitterUnreadCount || 0) + 1;
  } else {
    conversation.ownerUnreadCount = (conversation.ownerUnreadCount || 0) + 1;
  }
  await conversation.save();
  await conversation.populate(['ownerId', 'sitterId']);

  const ownerIdForNotif = normalizeId(conversation.ownerId);
  const sitterIdForNotif = normalizeId(conversation.sitterId);
  const recipientRole = senderRole === 'owner' ? 'sitter' : 'owner';
  const recipientId = senderRole === 'owner' ? sitterIdForNotif : ownerIdForNotif;

  if (recipientId && recipientId !== senderId) {
    // Sprint 4 step 3 — multilingual NEW_MESSAGE (in-app + push + email).
    sendNotification({
      userId: recipientId,
      role: recipientRole,
      type: 'NEW_MESSAGE',
      data: {
        conversationId: conversation._id.toString(),
        messageId: message._id.toString(),
        senderName:
          senderRole === 'owner'
            ? conversation.ownerId?.name || ''
            : conversation.sitterId?.name || '',
        preview: (effectiveBody || conversation.lastMessage || '').slice(0, 120),
      },
      actor: { role: senderRole, id: senderId },
    }).catch(() => {});
  }

  return {
    message: sanitizeMessage(message),
    conversation: sanitizeConversation(conversation),
  };
};

const markConversationRead = async ({ conversationId, role, userId }) => {
  ensureNonEmpty(conversationId, 'Conversation id is required.');
  ensureNonEmpty(role, 'role is required.');
  ensureNonEmpty(userId, 'userId is required.');

  ensureRole(role);

  const conversation = await getConversationOrThrow(conversationId, { populate: true });

  assertParticipant(conversation, role, userId);

  let updated = false;
  if (role === 'owner') {
    if (conversation.ownerUnreadCount > 0) {
      conversation.ownerUnreadCount = 0;
      conversation.ownerLastReadAt = new Date();
      updated = true;
    }
  } else {
    if (conversation.sitterUnreadCount > 0) {
      conversation.sitterUnreadCount = 0;
      conversation.sitterLastReadAt = new Date();
      updated = true;
    }
  }

  if (!updated) {
    return { updated: false };
  }

  await conversation.save();
  await conversation.populate(['ownerId', 'sitterId']);

  return {
    updated: true,
    conversation: sanitizeConversation(conversation),
  };
};

const assertAccessAndFetch = async ({ conversationId, role, userId }) => {
  ensureNonEmpty(conversationId, 'Conversation id is required.');
  ensureNonEmpty(role, 'role is required.');
  ensureNonEmpty(userId, 'userId is required.');

  ensureRole(role);

  const conversation = await getConversationOrThrow(conversationId, { populate: true });
  assertParticipant(conversation, role, userId);

  return sanitizeConversation(conversation);
};

module.exports = {
  sendMessage,
  markConversationRead,
  assertAccessAndFetch,
  hasValidPaidBooking,
};

