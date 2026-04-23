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
const { getChatAccess } = require('./chatAccessService');

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
  const walkerIdValue = normalizeId(conversation.walkerId);

  if (
    (role === 'owner' && ownerIdValue !== userId) ||
    (role === 'sitter' && sitterIdValue !== userId) ||
    (role === 'walker' && walkerIdValue !== userId)
  ) {
    throw new HttpError(403, 'User is not part of this conversation.');
  }
};

// v18.8 — accepte désormais walker en plus de owner/sitter.
const ensureRole = (role) => {
  if (!['owner', 'sitter', 'walker'].includes(role)) {
    throw new HttpError(400, 'Invalid role. Expected "owner", "sitter" or "walker".');
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
 * v18.8 — Accepte désormais (ownerId, sitterId[, walkerId]).
 * Quand walkerId est fourni, on match sur walkerId au lieu de sitterId.
 * Conserve la compatibilité avec l'ancienne signature à 2 arguments.
 *
 * @param {string} ownerId - Owner ID
 * @param {string|null} sitterId - Sitter ID (null si c'est un booking walker)
 * @param {string} [walkerId] - Walker ID (optional)
 * @returns {Promise<boolean>} - True if at least one valid paid booking exists
 */
const hasValidPaidBooking = async (ownerId, sitterId, walkerId) => {
  if (!ownerId) return false;
  if (!sitterId && !walkerId) return false;

  // v18.8.1 — booking-id match plus large. Avant, si le provider était un
  // walker mais que son Booking historique stockait l'id sous sitterId
  // (pré-v17, pré-walkerId), le query ne matchait plus → 402
  // CHAT_ACCESS_REQUIRED. On autorise désormais walkerId OU sitterId
  // quand l'un des deux est fourni.
  const providerId = walkerId || sitterId;
  const validPaidBooking = await Booking.findOne({
    ownerId,
    status: { $nin: ['cancelled', 'refunded'] },
    $and: [
      { $or: [{ status: 'paid' }, { paymentStatus: 'paid' }] },
      { $or: [{ walkerId: providerId }, { sitterId: providerId }] },
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
  const walkerId = normalizeId(conversation.walkerId);

  // v18.8 — block rule walker-aware : sitter OU walker en face.
  const otherProviderId = sitterId || walkerId;
  const otherProviderModel = sitterId ? 'Sitter' : 'Walker';
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
    throw new HttpError(403, 'Messaging is disabled because one user has been blocked.');
  }

  // Session v3.2 — chat access rule:
  //   * If a paid booking exists → OK (historical support chat).
  //   * Else if sender has Premium OR Chat add-on → OK (friends / pre-booking chat).
  //   * Else → 402 CHAT_ACCESS_REQUIRED so client can upsell.
  const hasPaidBooking = await hasValidPaidBooking(ownerId, sitterId, walkerId);
  if (!hasPaidBooking) {
    const senderUserModel = senderRole === 'owner'
      ? 'Owner'
      : senderRole === 'walker'
        ? 'Walker'
        : 'Sitter';
    const access = await getChatAccess(senderId, senderUserModel);
    if (!access.hasAny) {
      const err = new HttpError(402, 'Chat access required');
      err.code = 'CHAT_ACCESS_REQUIRED';
      err.details = {
        needsPremium: !access.hasPremium,
        needsChatAddon: !access.hasChatAddon,
        upgradeUrl: '/subscriptions/plans',
        addonUrl: '/chat-addon/plans',
      };
      throw err;
    }
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
  await conversation.populate(['ownerId', 'sitterId', 'walkerId']);

  // v18.8 — destinataire de la notif NEW_MESSAGE est dynamique :
  // owner → provider (sitter OU walker) ; provider → owner.
  const ownerIdForNotif = normalizeId(conversation.ownerId);
  const sitterIdForNotif = normalizeId(conversation.sitterId);
  const walkerIdForNotif = normalizeId(conversation.walkerId);
  const isWalkerConvo = !!walkerIdForNotif;
  const recipientRole = senderRole === 'owner'
    ? (isWalkerConvo ? 'walker' : 'sitter')
    : 'owner';
  const recipientId = senderRole === 'owner'
    ? (isWalkerConvo ? walkerIdForNotif : sitterIdForNotif)
    : ownerIdForNotif;

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
            : senderRole === 'walker'
              ? conversation.walkerId?.name || ''
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

