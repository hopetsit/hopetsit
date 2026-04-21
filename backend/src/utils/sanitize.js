const { DEFAULT_CURRENCY } = require('./currency');
const { formatLocationForResponse } = require('./location');

const sanitizeDoc = (doc, { omit = [] } = {}) => {
  if (!doc) return null;
  const plain = typeof doc.toObject === 'function' ? doc.toObject() : doc;
  const result = { ...plain };
  omit.forEach((field) => {
    delete result[field];
  });
  delete result.__v;
  if (result._id) {
    result.id = result._id.toString();
    delete result._id;
  }
  return result;
};

const buildMaskedNumber = (number, last4) => {
  const digits = typeof number === 'string' ? number.replace(/\D/g, '') : '';
  const tail = last4 || digits.slice(-4);
  if (!tail) return '';
  const leadingLength = Math.max(digits.length - tail.length, 0);
  const maskedLeading = leadingLength > 0 ? '*'.repeat(leadingLength) : '';
  const combined = `${maskedLeading}${tail}`;
  return combined.replace(/(.{4})/g, '$1 ').trim();
};

const sanitizeCard = (cardDoc) => {
  if (!cardDoc) return null;
  const holderName = cardDoc.holderName || '';
  const last4 = cardDoc.last4 || (cardDoc.number ? cardDoc.number.slice(-4) : '');
  const brand = cardDoc.brand || '';
  const expMonth = cardDoc.expMonth ?? null;
  const expYear = cardDoc.expYear ?? null;
  const expDate =
    cardDoc.expDate ||
    (typeof expMonth === 'number' && typeof expYear === 'number'
      ? `${String(expMonth).padStart(2, '0')}/${String(expYear).slice(-2)}`
      : '');
  const updatedAt =
    cardDoc.updatedAt instanceof Date
      ? cardDoc.updatedAt.toISOString()
      : typeof cardDoc.updatedAt === 'string'
        ? cardDoc.updatedAt
        : null;
  const maskedNumber =
    cardDoc.maskedNumber ||
    buildMaskedNumber(cardDoc.number, last4);

  if (!holderName && !last4 && !brand && !maskedNumber) {
    return null;
  }

  return {
    holderName,
    brand,
    last4: last4 || '',
    maskedNumber: maskedNumber || '',
    expMonth: expMonth ?? null,
    expYear: expYear ?? null,
    expDate: expDate || '',
    updatedAt,
  };
};

const sanitizeUser = (userDoc, { includeCard = false, includeEmail = false, includeIdentityDoc = false } = {}) => {
  if (!userDoc) return null;
  const sanitized = sanitizeDoc(userDoc, { omit: ['password'] });
  delete sanitized.password;

  // Sprint 3 step 5: never expose email publicly. Callers serving the
  // authenticated user's own profile (or admin) must opt in with includeEmail.
  if (!includeEmail) {
    delete sanitized.email;
  }

  // Sprint 5 step 7 — redact identity-verification document URL everywhere
  // except for the sitter themselves or the admin; expose a boolean flag only.
  if (sanitized.identityVerification && typeof sanitized.identityVerification === 'object') {
    sanitized.identityVerified = sanitized.identityVerification.status === 'verified';
    if (!includeIdentityDoc) {
      delete sanitized.identityVerification.documentUrl;
    }
  } else {
    sanitized.identityVerified = false;
  }
  
  // Only include card if explicitly requested (for card endpoints)
  if (includeCard && sanitized.card) {
    const card = sanitizeCard(sanitized.card);
    if (card) {
      sanitized.card = card;
    } else {
      delete sanitized.card;
    }
  } else {
    // Remove card from all other responses
    delete sanitized.card;
  }

  // Ensure service is always returned as array (for backward compatibility with legacy string)
  if (sanitized.service !== undefined) {
    sanitized.service = Array.isArray(sanitized.service)
      ? sanitized.service
      : sanitized.service
        ? [String(sanitized.service).trim()].filter(Boolean)
        : [];
  }

  // Format location for API response (lat, lng, city) - always include for consistent API shape
  const rawLocation = sanitized.location;
  const formattedLocation = formatLocationForResponse(rawLocation);
  sanitized.location = formattedLocation || {
    lat: null,
    lng: null,
    city: '',
    coordinates: [],
    ...(rawLocation?.locationType && { locationType: rawLocation.locationType }),
  };

  return sanitized;
};

const sanitizeBooking = (bookingDoc) => {
  if (!bookingDoc) return null;
  const booking = sanitizeDoc(bookingDoc);
  if (booking.ownerId && typeof booking.ownerId === 'object' && booking.ownerId._id) {
    booking.owner = sanitizeUser(booking.ownerId);
    delete booking.ownerId;
  }
  if (booking.sitterId && typeof booking.sitterId === 'object' && booking.sitterId._id) {
    booking.sitter = sanitizeUser(booking.sitterId);
    delete booking.sitterId;
  }
  // Session v17 — expose walker as a first-class field when the booking
  // targets a walker instead of a sitter. Mirrors the sitter handling
  // above so the frontend can rely on `booking.walker` being populated
  // when relevant. Same pattern as sanitizeApplication below (L.249-251).
  if (booking.walkerId && typeof booking.walkerId === 'object' && booking.walkerId._id) {
    booking.walker = sanitizeUser(booking.walkerId);
    delete booking.walkerId;
  }
  // Include pet details if available (petIds array)
  if (bookingDoc.petIds && Array.isArray(bookingDoc.petIds)) {
    booking.pets = bookingDoc.petIds.map(pet => {
      if (pet && typeof pet === 'object' && pet._id) {
        // Pet is populated, return full pet details
        return sanitizePet(pet);
      }
      // Pet is just an ID, return the ID
      return pet?.toString() || pet;
    });
    booking.petIds = bookingDoc.petIds.map(pet => {
      return pet?._id?.toString() || pet?.toString() || pet;
    });
  } else {
    booking.pets = [];
    booking.petIds = [];
  }
  // Include pricing information if available
  if (bookingDoc.pricing) {
    booking.pricing = {
      basePrice: bookingDoc.pricing.basePrice || 0,
      pricingTier: bookingDoc.pricing.pricingTier || 'hourly',
      appliedRate: bookingDoc.pricing.appliedRate || 0,
      totalHours: bookingDoc.pricing.totalHours || 0,
      totalDays: bookingDoc.pricing.totalDays || 0,
      addOns: Array.isArray(bookingDoc.pricing.addOns) ? bookingDoc.pricing.addOns : [],
      addOnsTotal: bookingDoc.pricing.addOnsTotal || 0,
      totalPrice: bookingDoc.pricing.totalPrice || 0,
      commission: bookingDoc.pricing.commission || 0,
      netPayout: bookingDoc.pricing.netPayout || 0,
      commissionRate: bookingDoc.pricing.commissionRate || 0.2,
      currency: bookingDoc.pricing.currency || DEFAULT_CURRENCY,
    };
  }
  // Include service details if available
  if (bookingDoc.serviceType) {
    booking.serviceType = bookingDoc.serviceType;
  }
  if (bookingDoc.duration !== undefined && bookingDoc.duration !== null) {
    booking.duration = bookingDoc.duration;
  }
  if (bookingDoc.locationType) {
    booking.locationType = bookingDoc.locationType;
  }
  booking.houseSittingVenue = bookingDoc.houseSittingVenue || null;
  if (bookingDoc.recommendedPriceRange) {
    booking.recommendedPriceRange = bookingDoc.recommendedPriceRange;
  }
  // Include status change timestamps
  if (bookingDoc.acceptedAt) {
    booking.acceptedAt = bookingDoc.acceptedAt instanceof Date 
      ? bookingDoc.acceptedAt.toISOString() 
      : bookingDoc.acceptedAt;
  }
  if (bookingDoc.rejectedAt) {
    booking.rejectedAt = bookingDoc.rejectedAt instanceof Date 
      ? bookingDoc.rejectedAt.toISOString() 
      : bookingDoc.rejectedAt;
  }
  if (bookingDoc.agreedAt) {
    booking.agreedAt = bookingDoc.agreedAt instanceof Date 
      ? bookingDoc.agreedAt.toISOString() 
      : bookingDoc.agreedAt;
  }
  if (bookingDoc.paidAt) {
    booking.paidAt = bookingDoc.paidAt instanceof Date 
      ? bookingDoc.paidAt.toISOString() 
      : bookingDoc.paidAt;
  }
  if (bookingDoc.paymentFailedAt) {
    booking.paymentFailedAt = bookingDoc.paymentFailedAt instanceof Date 
      ? bookingDoc.paymentFailedAt.toISOString() 
      : bookingDoc.paymentFailedAt;
  }
  // Include payment status
  if (bookingDoc.paymentStatus) {
    booking.paymentStatus = bookingDoc.paymentStatus;
  }
  // Include cancellation status (without sensitive Stripe IDs)
  if (bookingDoc.cancellation) {
    booking.cancellation = {
      ownerRequested: bookingDoc.cancellation.ownerRequested || false,
      sitterRequested: bookingDoc.cancellation.sitterRequested || false,
      ownerConfirmed: bookingDoc.cancellation.ownerConfirmed || false,
      sitterConfirmed: bookingDoc.cancellation.sitterConfirmed || false,
      requestedAt: bookingDoc.cancellation.requestedAt 
        ? (bookingDoc.cancellation.requestedAt instanceof Date 
          ? bookingDoc.cancellation.requestedAt.toISOString() 
          : bookingDoc.cancellation.requestedAt)
        : null,
      confirmedAt: bookingDoc.cancellation.confirmedAt 
        ? (bookingDoc.cancellation.confirmedAt instanceof Date 
          ? bookingDoc.cancellation.confirmedAt.toISOString() 
          : bookingDoc.cancellation.confirmedAt)
        : null,
      // Note: refundId is not included for security reasons
    };
  }
  return booking;
};

const sanitizeApplication = (applicationDoc) => {
  if (!applicationDoc) return null;
  const application = sanitizeDoc(applicationDoc);
  if (application.ownerId && typeof application.ownerId === 'object' && application.ownerId._id) {
    application.owner = sanitizeUser(application.ownerId);
    delete application.ownerId;
  }
  if (application.sitterId && typeof application.sitterId === 'object' && application.sitterId._id) {
    application.sitter = sanitizeUser(application.sitterId);
    delete application.sitterId;
  }
  // Session v16.3b - expose walker as a first-class field when present.
  if (application.walkerId && typeof application.walkerId === 'object' && application.walkerId._id) {
    application.walker = sanitizeUser(application.walkerId);
    delete application.walkerId;
  }
  // Session v17.1 — ensure postId is always a plain string so the frontend
  // can do equality checks without worrying about ObjectId vs String.
  if (application.postId) {
    application.postId = application.postId.toString();
  } else {
    application.postId = null;
  }
  if (application.serviceDate instanceof Date) {
    application.serviceDate = application.serviceDate.toISOString();
  } else if (!application.serviceDate) {
    application.serviceDate = null;
  }
  if (application.startDate instanceof Date) {
    application.startDate = application.startDate.toISOString();
  } else if (!application.startDate) {
    application.startDate = null;
  }
  if (application.endDate instanceof Date) {
    application.endDate = application.endDate.toISOString();
  } else if (!application.endDate) {
    application.endDate = null;
  }
  if (application.pricing && typeof application.pricing === 'object') {
    application.pricing.pricingTier = application.pricing.pricingTier || 'hourly';
    application.pricing.appliedRate = application.pricing.appliedRate || 0;
    application.pricing.totalHours = application.pricing.totalHours || 0;
    application.pricing.totalDays = application.pricing.totalDays || 0;
  }
  return application;
};

const sanitizePet = (petDoc) => {
  if (!petDoc) return null;
  return sanitizeDoc(petDoc);
};

const sanitizePost = (postDoc) => {
  if (!postDoc) return null;
  const post = sanitizeDoc(postDoc);
  // Only treat as populated owner document when it looks like a user (has name/email), not a raw ObjectId
  const isOwnerDocument =
    post.ownerId &&
    typeof post.ownerId === 'object' &&
    post.ownerId._id &&
    (post.ownerId.name !== undefined || post.ownerId.email !== undefined);
  if (isOwnerDocument) {
    post.owner = sanitizeUser(post.ownerId);
    post.ownerId = post.owner.id;
  } else if (post.ownerId) {
    post.ownerId = post.ownerId.toString();
  }
  post.postType = postDoc.postType || 'request';
  if (Array.isArray(postDoc.images)) {
    post.images = postDoc.images.map((image) => ({
      url: image.url || '',
      publicId: image.publicId || '',
      uploadedAt: image.uploadedAt || null,
    }));
  } else {
    post.images = [];
  }
  if (Array.isArray(postDoc.videos)) {
    post.videos = postDoc.videos.map((video) => ({
      url: video.url || '',
      publicId: video.publicId || '',
      uploadedAt: video.uploadedAt || null,
    }));
  } else {
    post.videos = [];
  }
  if (Array.isArray(postDoc.likes)) {
    post.likes = postDoc.likes.map((like) => ({
      userId: like.userId?.toString() || '',
      userRole: like.userRole || 'Owner',
      createdAt: like.createdAt || null,
    }));
    post.likesCount = post.likes.length;
  } else {
    post.likes = [];
    post.likesCount = 0;
  }
  if (Array.isArray(postDoc.comments)) {
    post.comments = postDoc.comments.map((comment) => ({
      id: comment._id?.toString() || undefined,
      userId: comment.userId?.toString() || '',
      userRole: comment.userRole || 'Owner',
      authorName: comment.authorName || '',
      authorAvatar: comment.authorAvatar?.url || '',
      body: comment.body || '',
      createdAt: comment.createdAt || null,
    }));
    post.commentsCount = post.comments.length;
  } else {
    post.comments = [];
    post.commentsCount = 0;
  }

  // Session v17.1 — reservation marker. Expose as a compact, front-end
  // friendly shape so PetPostCard can render a badge without knowing the
  // underlying Booking / Provider ref types.
  const rb = postDoc.reservedBy;
  if (rb && rb.bookingId) {
    post.reservedBy = {
      bookingId: rb.bookingId.toString(),
      providerRole: rb.providerRole || null,
      providerId: rb.providerId ? rb.providerId.toString() : null,
      providerName: rb.providerName || '',
      reservedAt: rb.reservedAt instanceof Date
        ? rb.reservedAt.toISOString()
        : (rb.reservedAt || null),
    };
  } else {
    post.reservedBy = null;
  }

  // Additional optional metadata
  // Dates: return as ISO strings or null
  if (postDoc.startDate instanceof Date) {
    post.startDate = postDoc.startDate.toISOString();
  } else if (postDoc.startDate) {
    post.startDate = String(postDoc.startDate);
  } else {
    post.startDate = null;
  }

  if (postDoc.endDate instanceof Date) {
    post.endDate = postDoc.endDate.toISOString();
  } else if (postDoc.endDate) {
    post.endDate = String(postDoc.endDate);
  } else {
    post.endDate = null;
  }

  const rawServices =
    Array.isArray(postDoc.serviceTypes)
      ? postDoc.serviceTypes
      : postDoc.serviceTypes != null
        ? [postDoc.serviceTypes]
        : [];
  post.serviceTypes = rawServices
    .map((s) => (typeof s === 'string' ? s.trim() : String(s).trim()))
    .filter(Boolean);
  post.houseSittingVenue = postDoc.houseSittingVenue || null;

  if (postDoc.petId) {
    if (typeof postDoc.petId === 'object' && postDoc.petId._id) {
      post.petId = postDoc.petId._id.toString();
    } else {
      post.petId = postDoc.petId.toString();
    }
  } else {
    post.petId = null;
  }

  // Return location object as-is (or null) so frontend gets exactly what it sent
  post.location = postDoc.location || null;

  if (postDoc.notes !== undefined && postDoc.notes !== null) {
    post.notes = typeof postDoc.notes === 'string' ? postDoc.notes : String(postDoc.notes);
  } else {
    post.notes = '';
  }

  return post;
};

const sanitizeConversation = (conversationDoc) => {
  if (!conversationDoc) return null;
  const conversation = sanitizeDoc(conversationDoc);
  if (conversation.ownerId && typeof conversation.ownerId === 'object' && conversation.ownerId._id) {
    conversation.owner = sanitizeUser(conversation.ownerId);
    delete conversation.ownerId;
  } else if (conversation.ownerId) {
    conversation.ownerId = conversation.ownerId.toString();
  }
  if (conversation.sitterId && typeof conversation.sitterId === 'object' && conversation.sitterId._id) {
    conversation.sitter = sanitizeUser(conversation.sitterId);
    delete conversation.sitterId;
  } else if (conversation.sitterId) {
    conversation.sitterId = conversation.sitterId.toString();
  }
  conversation.ownerUnreadCount = conversation.ownerUnreadCount || 0;
  conversation.sitterUnreadCount = conversation.sitterUnreadCount || 0;
  return conversation;
};

const sanitizeMessage = (messageDoc) => {
  if (!messageDoc) return null;
  const message = sanitizeDoc(messageDoc);
  if (message.conversationId && typeof message.conversationId === 'object') {
    message.conversationId = message.conversationId.toString();
  }
  if (message.senderId && typeof message.senderId === 'object') {
    message.senderId = message.senderId.toString();
  }
  if (Array.isArray(message.attachments)) {
    message.attachments = message.attachments.map((attachment) => ({
      url: attachment.url || '',
      publicId: attachment.publicId || '',
      resourceType: attachment.resourceType || 'image',
      format: attachment.format || '',
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
      thumbnailUrl: attachment.thumbnailUrl || '',
      originalFilename: attachment.originalFilename || '',
    }));
  } else {
    message.attachments = [];
  }
  if (typeof message.body !== 'string') {
    message.body = '';
  }
  return message;
};

const sanitizeReview = (reviewDoc) => {
  if (!reviewDoc) return null;
  const review = sanitizeDoc(reviewDoc);
  if (review.reviewerId && typeof review.reviewerId === 'object' && review.reviewerId._id) {
    review.reviewer = sanitizeUser(review.reviewerId);
    delete review.reviewerId;
  } else if (review.reviewerId) {
    review.reviewerId = review.reviewerId.toString();
  }
  if (review.revieweeId && typeof review.revieweeId === 'object' && review.revieweeId._id) {
    review.reviewee = sanitizeUser(review.revieweeId);
    delete review.revieweeId;
  } else if (review.revieweeId) {
    review.revieweeId = review.revieweeId.toString();
  }
  return review;
};

module.exports = {
  sanitizeDoc,
  sanitizeUser,
  sanitizeCard,
  sanitizeBooking,
  sanitizeApplication,
  sanitizeConversation,
  sanitizeMessage,
  sanitizePost,
  sanitizePet,
  sanitizeReview,
};

