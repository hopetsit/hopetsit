const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');

const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Pet = require('../models/Pet');
const Post = require('../models/Post');
const Booking = require('../models/Booking');
const Application = require('../models/Application');
const Conversation = require('../models/Conversation');
const Message = require('../models/Message');
const Review = require('../models/Review');
const Task = require('../models/Task');
const Block = require('../models/Block');
const { sanitizeUser, sanitizeDoc, sanitizePet, sanitizePost, sanitizeBooking, sanitizeReview } = require('../utils/sanitize');
const { encrypt } = require('../utils/encryption');
const { getOwnerStats } = require('../services/loyaltyService');
const { getMyReferrals } = require('../services/referralService');
const { uploadMedia } = require('../services/cloudinary');
const { normalizeCurrency, DEFAULT_CURRENCY } = require('../utils/currency');
const { processLocationData } = require('../utils/location');
const logger = require('../utils/logger');

const OWNER_SERVICES = ['Pet Sitting', 'House Sitting', 'Day Care', 'Long Stay'];
const SITTER_SERVICES = [...OWNER_SERVICES, 'Dog Walking'];

const detectCardBrand = (digits) => {
  if (/^4/.test(digits)) return 'Visa';
  if (/^5[1-5]/.test(digits)) return 'Mastercard';
  if (/^3[47]/.test(digits)) return 'American Express';
  if (/^6(?:011|5|4[4-9]\d)/.test(digits)) return 'Discover';
  if (/^3(?:0[0-5]|[68])/.test(digits)) return 'Diners Club';
  if (/^35/.test(digits)) return 'JCB';
  return 'Card';
};

const buildCardPayload = ({ holderName, cardNumber, expDate, cvc }) => {
  if (!holderName || !holderName.trim()) {
    throw new Error('Card holder name is required.');
  }

  const digits = String(cardNumber || '').replace(/\D/g, '');
  if (!digits || digits.length < 13 || digits.length > 19) {
    throw new Error('Please enter a valid card number.');
  }

  const cleanedCvc = String(cvc || '').replace(/\s/g, '');
  if (!/^\d{3,4}$/.test(cleanedCvc)) {
    throw new Error('Please enter a valid CVC.');
  }

  const exp = String(expDate || '').replace(/\s/g, '');
  const match = /^(\d{2})\/(\d{2})$/.exec(exp);
  if (!match) {
    throw new Error('Expiration date must be in MM/YY format.');
  }

  const expMonth = parseInt(match[1], 10);
  const expYear = 2000 + parseInt(match[2], 10);
  if (Number.isNaN(expMonth) || Number.isNaN(expYear) || expMonth < 1 || expMonth > 12) {
    throw new Error('Expiration date is invalid.');
  }

  const now = new Date();
  const currentYear = now.getFullYear();
  const currentMonth = now.getMonth() + 1;
  if (expYear < currentYear || (expYear === currentYear && expMonth < currentMonth)) {
    throw new Error('This card appears to be expired.');
  }

  const maskedNumber = `${'*'.repeat(Math.max(0, digits.length - 4))}${digits.slice(-4)}`
    .replace(/(.{4})/g, '$1 ')
    .trim();

  return {
    holderName: holderName.trim(),
    number: encrypt(digits),
    maskedNumber,
    last4: digits.slice(-4),
    brand: detectCardBrand(digits),
    expMonth,
    expYear,
    expDate: `${match[1]}/${match[2]}`,
    cvc: encrypt(cleanedCvc),
    updatedAt: new Date(),
  };
};

const buildProfileUpdate = ({ name, mobile, countryCode, language, address, avatar, bio, skills, currency }) => {
  const update = {};
  if (name !== undefined) {
    if (typeof name !== 'string' || !name.trim()) {
      throw new Error('Name must be a non-empty string.');
    }
    update.name = name.trim();
  }
  if (mobile !== undefined) {
    if (typeof mobile !== 'string') {
      throw new Error('Mobile must be a string.');
    }
    update.mobile = mobile.trim();
  }
  if (countryCode !== undefined) {
    update.countryCode = countryCode.toString().trim();
  }
  if (language !== undefined) {
    if (typeof language !== 'string') {
      throw new Error('Language must be a string.');
    }
    update.language = language.trim();
  }
  if (address !== undefined) {
    if (typeof address !== 'string') {
      throw new Error('Address must be a string.');
    }
    update.address = address.trim();
  }
  if (bio !== undefined) {
    if (typeof bio !== 'string') {
      throw new Error('Bio must be a string.');
    }
    update.bio = bio.trim();
  }
  if (skills !== undefined) {
    if (typeof skills !== 'string') {
      throw new Error('Skills must be a string.');
    }
    update.skills = skills.trim();
  }
  if (currency !== undefined) {
    update.currency = normalizeCurrency(currency, { required: true });
  }
  if (avatar !== undefined) {
    if (avatar === null) {
      update.avatar = { url: '', publicId: '' };
    } else if (typeof avatar === 'object' && avatar !== null) {
      const url = typeof avatar.url === 'string' ? avatar.url.trim() : '';
      const publicId = typeof avatar.publicId === 'string' ? avatar.publicId.trim() : '';
      if (!url) {
        throw new Error('Avatar url is required.');
      }
      update.avatar = { url, publicId };
    } else {
      throw new Error('Avatar must be an object or null.');
    }
  }

  return update;
};

const updateService = async (req, res) => {
  try {
    const { id } = req.params;
    const { service } = req.body || {};

    const rawServices = Array.isArray(service) ? service : service != null ? [service] : [];
    const normalizedServices = rawServices
      .map((s) => (typeof s === 'string' ? s.trim() : typeof s === 'number' ? String(s).trim() : ''))
      .filter(Boolean);

    if (normalizedServices.length === 0) {
      return res.status(400).json({ error: 'Service is required (array of service names).' });
    }

    let account = await Owner.findById(id);
    let role = 'owner';
    let allowedServices = OWNER_SERVICES;

    if (!account) {
      account = await Sitter.findById(id);
      role = 'sitter';
      allowedServices = SITTER_SERVICES;
    }

    if (!account) {
      return res.status(404).json({ error: 'User not found.' });
    }

    const invalid = normalizedServices.filter((s) => !allowedServices.includes(s));
    if (invalid.length > 0) {
      return res.status(400).json({
        error: `Invalid service(s): ${invalid.join(', ')}. Allowed: ${allowedServices.join(', ')}.`,
      });
    }

    account.service = normalizedServices;
    await account.save();

    res.json({ role, user: sanitizeUser(account, { includeEmail: true }) });
  } catch (error) {
    logger.error('Update service error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid user id.' });
    }
    res.status(500).json({ error: 'Unable to update service. Please try again later.' });
  }
};

const updateProfile = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, mobile, countryCode, language, address, avatar, bio, skills, currency, location, servicePreferences } = req.body || {};

    const update = buildProfileUpdate({ name, mobile, countryCode, language, address, avatar, bio, skills, currency });

    // Sprint 5 step 2 — accept owner service preferences.
    if (servicePreferences && typeof servicePreferences === 'object') {
      update.servicePreferences = {
        atOwner: servicePreferences.atOwner !== false,
        atSitter: servicePreferences.atSitter === true,
      };
    }

    // Process location if provided
    let locationUpdate = null;
    let unsetLocation = false;
    if (location !== undefined) {
      if (location === null || (typeof location === 'object' && Object.keys(location || {}).length === 0)) {
        unsetLocation = true;
      } else {
        const locationType = location?.locationType || 'standard';
        const processed = processLocationData(location, { locationType });
        if (processed) {
          locationUpdate = processed;
        }
      }
    }

    if (locationUpdate) {
      update.location = locationUpdate;
    }
    if (Object.keys(update).length === 0 && !unsetLocation) {
      return res.status(400).json({ error: 'No profile fields provided.' });
    }

    const trimmedMobile =
      typeof update.mobile === 'string' && update.mobile.trim().length > 0
        ? update.mobile.trim()
        : null;

    if (trimmedMobile) {
      update.mobile = trimmedMobile;
      const existingOwner = await Owner.findOne({
        mobile: trimmedMobile,
        _id: { $ne: id },
      });
      const existingSitter = await Sitter.findOne({
        mobile: trimmedMobile,
        _id: { $ne: id },
      });
      if (existingOwner || existingSitter) {
        return res
          .status(409)
          .json({ error: 'This mobile number is already associated with another account.' });
      }
    }

    const updateOps = {};
    if (Object.keys(update).length > 0) {
      updateOps.$set = update;
    }
    if (unsetLocation) {
      updateOps.$unset = { location: '' };
    }

    let account = await Owner.findByIdAndUpdate(id, updateOps, { new: true });
    let role = 'owner';

    if (!account) {
      account = await Sitter.findByIdAndUpdate(id, updateOps, { new: true });
      role = 'sitter';
    }

    if (!account) {
      return res.status(404).json({ error: 'User not found.' });
    }

    res.json({ role, user: sanitizeUser(account, { includeEmail: true }) });
  } catch (error) {
    logger.error('Update profile error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid user id.' });
    }
    if (error.message && error.message.includes('Avatar url is required')) {
      return res.status(400).json({ error: error.message });
    }
    if (error.message && error.message.includes('must be')) {
      return res.status(400).json({ error: error.message });
    }
    res.status(500).json({ error: 'Unable to update profile. Please try again later.' });
  }
};

const updateCard = async (req, res) => {
  try {
    const { id } = req.params;
    const { holderName, cardNumber, expDate, cvc } = req.body || {};

    let cardData;
    try {
      cardData = buildCardPayload({ holderName, cardNumber, expDate, cvc });
    } catch (validationError) {
      return res.status(400).json({ error: validationError.message });
    }

    let account = await Owner.findByIdAndUpdate(id, { card: cardData }, { new: true });
    let role = 'owner';

    if (!account) {
      account = await Sitter.findByIdAndUpdate(id, { card: cardData }, { new: true });
      role = 'sitter';
    }

    if (!account) {
      return res.status(404).json({ error: 'User not found.' });
    }

    res.json({ role, user: sanitizeUser(account, { includeCard: true, includeEmail: true }) });
  } catch (error) {
    logger.error('Update card error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid user id.' });
    }
    res.status(500).json({ error: 'Unable to update card. Please try again later.' });
  }
};

const updateOwnerCardFromToken = async (req, res) => {
  try {
    const ownerId = req.user?.id;
    if (!ownerId) {
      return res.status(403).json({ error: 'Owner context missing.' });
    }

    let cardData;
    try {
      cardData = buildCardPayload(req.body || {});
    } catch (validationError) {
      return res.status(400).json({ error: validationError.message });
    }

    const owner = await Owner.findByIdAndUpdate(ownerId, { card: cardData }, { new: true });
    if (!owner) {
      return res.status(404).json({ error: 'Owner not found.' });
    }

    res.json({ user: sanitizeUser(owner, { includeCard: true, includeEmail: true }) });
  } catch (error) {
    logger.error('Update owner card (token) error', error);
    res.status(500).json({ error: 'Unable to update card. Please try again later.' });
  }
};

const deleteAccount = async (req, res) => {
  try {
    const { id } = req.params;

    let account = await Owner.findById(id);
    let role = 'owner';

    if (!account) {
      account = await Sitter.findById(id);
      role = 'sitter';
    }

    if (!account) {
      return res.status(404).json({ error: 'User not found.' });
    }

    const roleModel = role === 'owner' ? 'Owner' : 'Sitter';
    const userId = account._id;

    const conversationFilter =
      role === 'owner' ? { ownerId: userId } : { sitterId: userId };
    const conversations = await Conversation.find(conversationFilter).select('_id');

    if (conversations.length) {
      const conversationIds = conversations.map((conversation) => conversation._id);
      await Message.deleteMany({ conversationId: { $in: conversationIds } });
      await Conversation.deleteMany({ _id: { $in: conversationIds } });
    }

    await Booking.deleteMany({
      [role === 'owner' ? 'ownerId' : 'sitterId']: userId,
    });

    await Application.deleteMany({
      [role === 'owner' ? 'ownerId' : 'sitterId']: userId,
    });

    let sitterIdsForRecalc = [];
    if (role === 'owner') {
      const ownerReviews = await Review.find({
        reviewerId: userId,
        reviewerModel: 'Owner',
        revieweeModel: 'Sitter',
      }).select('revieweeId');

      sitterIdsForRecalc = [
        ...new Set(ownerReviews.map((review) => review.revieweeId.toString())),
      ].map((value) => new mongoose.Types.ObjectId(value));
    }

    await Review.deleteMany({
      $or: [
        { reviewerId: userId, reviewerModel: roleModel },
        { revieweeId: userId, revieweeModel: roleModel },
      ],
    });

    if (sitterIdsForRecalc.length) {
      const reviewStats = await Review.aggregate([
        {
          $match: {
            revieweeModel: 'Sitter',
            revieweeId: { $in: sitterIdsForRecalc },
          },
        },
        {
          $group: {
            _id: '$revieweeId',
            averageRating: { $avg: '$rating' },
            total: { $sum: 1 },
          },
        },
      ]);

      const statsMap = new Map(reviewStats.map((stat) => [stat._id.toString(), stat]));

      for (const sitterId of sitterIdsForRecalc) {
        const key = sitterId.toString();
        const stat = statsMap.get(key);
        const totalReviews = stat ? stat.total : 0;
        const averageRating = stat ? Number(stat.averageRating.toFixed(2)) : 0;

        await Sitter.updateOne(
          { _id: sitterId },
          {
            $set: {
              rating: totalReviews === 0 ? 0 : averageRating,
              reviewsCount: totalReviews,
            },
          }
        );
      }
    }

    await Block.deleteMany({
      $or: [
        { blockerId: userId, blockerModel: roleModel },
        { blockedId: userId, blockedModel: roleModel },
      ],
    });

    await Post.updateMany(
      {
        $or: [
          { 'likes.userId': userId },
          { 'comments.userId': userId },
        ],
      },
      {
        $pull: {
          likes: { userId },
          comments: { userId },
        },
      }
    );

    if (role === 'owner') {
      await Pet.deleteMany({ ownerId: userId });
      await Post.deleteMany({ ownerId: userId });
      await Task.deleteMany({ ownerId: userId });
      await Owner.deleteOne({ _id: userId });
    } else {
      await Sitter.deleteOne({ _id: userId });
    }

    res.json({ message: 'Account and related data deleted successfully.' });
  } catch (error) {
    logger.error('Delete account error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid user id.' });
    }
    res.status(500).json({ error: 'Unable to delete account. Please try again later.' });
  }
};

const deleteAccountFromToken = async (req, res) => {
  try {
    const userId = req.user?.id;
    const role = req.user?.role;

    if (!userId || !role) {
      return res.status(403).json({ error: 'Authentication context missing.' });
    }

    const Model = role === 'sitter' ? Sitter : Owner;
    const account = await Model.findById(userId);

    if (!account) {
      return res.status(404).json({ error: 'User not found.' });
    }

    req.params.id = userId;
    return deleteAccount(req, res);
  } catch (error) {
    logger.error('Delete account (token) error', error);
    res.status(500).json({ error: 'Unable to delete account. Please try again later.' });
  }
};

const bufferToDataUri = (file) => `data:${file.mimetype};base64,${file.buffer.toString('base64')}`;

const updateProfilePicture = async (req, res) => {
  try {
    const userId = req.user?.id;
    const userRole = req.user?.role;

    if (!userId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (!userRole || !['owner', 'sitter'].includes(userRole)) {
      return res.status(403).json({ error: 'Invalid user role. Only owners and sitters can update profile picture.' });
    }

    if (!req.file) {
      return res.status(400).json({ error: 'Profile picture file is required.' });
    }

    // Validate file type
    const allowedMimeTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
    if (!allowedMimeTypes.includes(req.file.mimetype)) {
      return res.status(400).json({ error: 'Invalid file type. Only JPEG, PNG, and WebP images are allowed.' });
    }

    // Convert buffer to data URI
    const dataUri = bufferToDataUri(req.file);

    // Upload to Cloudinary
    const folder = `petsinsta/${userRole}s/${userId}`;
    const uploadResult = await uploadMedia({
      file: dataUri,
      folder: folder,
      resourceType: 'image',
    });

    // Update user's avatar in database
    const Model = userRole === 'owner' ? Owner : Sitter;
    const user = await Model.findById(userId);

    if (!user) {
      return res.status(404).json({ error: 'User not found.' });
    }

    // Delete old avatar from Cloudinary if it exists
    if (user.avatar?.publicId) {
      try {
        const cloudinary = require('cloudinary').v2;
        await cloudinary.uploader.destroy(user.avatar.publicId);
      } catch (deleteError) {
        logger.error('Error deleting old avatar:', deleteError);
        // Continue even if deletion fails
      }
    }

    // Update avatar
    user.avatar = {
      url: uploadResult.url,
      publicId: uploadResult.publicId,
    };

    await user.save();

    res.json({
      message: 'Profile picture updated successfully.',
      user: sanitizeUser(user, { includeEmail: true }),
      avatar: {
        url: uploadResult.url,
        publicId: uploadResult.publicId,
      },
    });
  } catch (error) {
    logger.error('Update profile picture error', error);
    if (error.message && error.message.includes('Cloudinary')) {
      return res.status(502).json({ error: 'Media service is unavailable. Please try again later.' });
    }
    res.status(500).json({ error: 'Unable to update profile picture. Please try again later.' });
  }
};

const getOwnerProfile = async (req, res) => {
  try {
    const ownerId = req.user?.id;
    const userRole = req.user?.role;

    if (!ownerId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (userRole !== 'owner') {
      return res.status(403).json({ error: 'This endpoint is only accessible to owners.' });
    }

    const owner = await Owner.findById(ownerId);
    if (!owner) {
      return res.status(404).json({ error: 'Owner not found.' });
    }

    // Fetch related data
    const pets = await Pet.find({ ownerId: ownerId }).sort({ createdAt: -1 });
    const bookings = await Booking.find({ ownerId: ownerId })
      .populate('sitterId', 'name email avatar')
      .sort({ createdAt: -1 });
    const posts = await Post.find({ ownerId: ownerId }).sort({ createdAt: -1 });
    const tasks = await Task.find({ ownerId: ownerId }).sort({ createdAt: -1 });

    // Get reviews where owner is the reviewer
    const reviewsGiven = await Review.find({
      reviewerId: ownerId,
      reviewerModel: 'Owner',
    })
      .populate('revieweeId', 'name email avatar')
      .sort({ createdAt: -1 });

    // Get reviews where owner is the reviewee (if applicable, though owners typically don't receive reviews)
    const reviewsReceived = await Review.find({
      revieweeId: ownerId,
      revieweeModel: 'Owner',
    })
      .populate('reviewerId', 'name email avatar')
      .sort({ createdAt: -1 });

    const profile = {
      ...sanitizeUser(owner, { includeEmail: true }),
      pets: pets.map((pet) => sanitizePet(pet)),
      bookings: bookings.map((booking) => sanitizeBooking(booking)),
      posts: posts.map((post) => sanitizePost(post)),
      tasks: tasks.map((task) => sanitizeDoc(task)),
      reviewsGiven: reviewsGiven.map((review) => sanitizeReview(review)),
      reviewsReceived: reviewsReceived.map((review) => sanitizeReview(review)),
      stats: {
        petsCount: pets.length,
        bookingsCount: bookings.length,
        postsCount: posts.length,
        tasksCount: tasks.length,
        reviewsGivenCount: reviewsGiven.length,
        reviewsReceivedCount: reviewsReceived.length,
      },
    };

    res.json({ profile });
  } catch (error) {
    logger.error('Get owner profile error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid owner id.' });
    }
    res.status(500).json({ error: 'Unable to fetch owner profile. Please try again later.' });
  }
};

const signAuthToken = (payload, options = {}) => {
  if (!process.env.JWT_SECRET) {
    throw new Error('JWT_SECRET environment variable is not configured.');
  }
  return jwt.sign(payload, process.env.JWT_SECRET, {
    expiresIn: '7d',
    ...options,
  });
};

const switchRole = async (req, res) => {
  try {
    const userId = req.user?.id;
    const currentRole = req.user?.role;

    if (!userId || !currentRole) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    // Determine target role
    const targetRole = currentRole === 'owner' ? 'sitter' : 'owner';

    // Find current user
    let currentUser;
    if (currentRole === 'owner') {
      currentUser = await Owner.findById(userId);
    } else {
      currentUser = await Sitter.findById(userId);
    }

    if (!currentUser) {
      return res.status(404).json({ error: 'User not found.' });
    }

    // Convert current user data to plain object
    const userData = currentUser.toObject();

    // Determine stable oldId (for existing users use their current _id)
    const baseOldId = userData.oldId || userData._id;

    // Store original password hash (already hashed)
    const originalPasswordHash = userData.password;

    // Prepare data for new role (password will be included temporarily for validation, then restored)
    let newUserData = {
      name: userData.name,
      email: userData.email,
      mobile: userData.mobile || '',
      countryCode: userData.countryCode || '',
      password: originalPasswordHash, // Include password for validation, will be restored after create
      language: userData.language || '',
      address: userData.address || '',
      currency: userData.currency || DEFAULT_CURRENCY,
      bio: userData.bio || '',
      skills: userData.skills || '',
      acceptedTerms: userData.acceptedTerms || false,
      service: Array.isArray(userData.service) ? userData.service : userData.service ? [userData.service] : [],
      verified: userData.verified || false,
      firebaseUid: userData.firebaseUid || null,
      authProvider: userData.authProvider || 'password',
      avatar: userData.avatar || { url: '', publicId: '' },
      oldId: baseOldId,
      card: userData.card || {
        holderName: '',
        number: '',
        maskedNumber: '',
        last4: '',
        brand: '',
        expMonth: null,
        expYear: null,
        expDate: '',
        cvc: '',
        updatedAt: null,
      },
    };

    // Handle location - only include if coordinates is a valid array
    // MongoDB 2dsphere index cannot index documents with null coordinates
    const originalLocation = userData.location;
    const hasValidCoordinates = originalLocation && 
        Array.isArray(originalLocation.coordinates) && 
        originalLocation.coordinates.length === 2 &&
        typeof originalLocation.coordinates[0] === 'number' &&
        typeof originalLocation.coordinates[1] === 'number';
    
    if (hasValidCoordinates) {
      // Valid coordinates array exists
      if (targetRole === 'sitter') {
        newUserData.location = {
          type: 'Point',
          coordinates: originalLocation.coordinates,
          city: originalLocation.city || '',
          locationType: originalLocation.locationType || 'standard',
        };
      } else {
        newUserData.location = {
          type: 'Point',
          coordinates: originalLocation.coordinates,
          city: originalLocation.city || '',
        };
      }
    } else {
      // Explicitly delete location property to prevent Mongoose from applying defaults with null coordinates
      delete newUserData.location;
    }

    // Add role-specific fields
    if (targetRole === 'sitter') {
      newUserData.rate = '';
      newUserData.hourlyRate = 0;
      newUserData.weeklyRate = 0;
      newUserData.monthlyRate = 0;
      newUserData.rating = 0;
      newUserData.reviewsCount = 0;
      newUserData.feedback = [];
      newUserData.servicePricing = {
        homeVisit: { basePrice: null, currency: DEFAULT_CURRENCY },
        dogWalking30: { basePrice: null, currency: DEFAULT_CURRENCY },
        dogWalking60: { basePrice: null, currency: DEFAULT_CURRENCY },
        overnightStay: { basePrice: null, currency: DEFAULT_CURRENCY },
        longStay: { basePrice: null, currency: DEFAULT_CURRENCY },
      };
      newUserData.stripeConnectAccountId = null;
      newUserData.stripeConnectAccountStatus = 'not_connected';
    }

    // Create new user in target role using collection.insertOne to bypass Mongoose defaults
    // This prevents Mongoose from applying location defaults with null coordinates
    let insertedResult;
    if (targetRole === 'sitter') {
      // When switching to sitter we let MongoDB assign a new _id,
      // but we keep oldId pointing to the original owner id.
      insertedResult = await Sitter.collection.insertOne(newUserData);
      newUser = await Sitter.findById(insertedResult.insertedId);
    } else {
      // When switching back to owner, reuse the stable oldId as _id
      // so the owner keeps the same identifier across switches.
      const ownerInsertData = {
        ...newUserData,
        _id: baseOldId,
        oldId: baseOldId,
      };
      insertedResult = await Owner.collection.insertOne(ownerInsertData);
      newUser = await Owner.findById(insertedResult.insertedId);
    }

    // Restore the original password hash using updateOne (bypasses pre-save hook)
    // This is necessary because insertOne doesn't trigger pre-save hooks, so password is already correct
    // But we still update it to be safe, and also remove location if it was invalid
    const updateOps = { $set: { password: originalPasswordHash } };
    if (!hasValidCoordinates) {
      updateOps.$unset = { location: '' };
    }

    if (targetRole === 'sitter') {
      await Sitter.updateOne({ _id: newUser._id }, updateOps);
      // Refresh the document
      newUser = await Sitter.findById(newUser._id);
    } else {
      await Owner.updateOne({ _id: newUser._id }, updateOps);
      // Refresh the document
      newUser = await Owner.findById(newUser._id);
    }

    // Delete old user
    if (currentRole === 'owner') {
      await Owner.findByIdAndDelete(userId);
    } else {
      await Sitter.findByIdAndDelete(userId);
    }

    // Generate new token with new role and new user ID
    const token = signAuthToken({ id: newUser._id.toString(), role: targetRole });

    res.json({
      message: `Successfully switched from ${currentRole} to ${targetRole}.`,
      role: targetRole,
      token,
      user: sanitizeUser(newUser, { includeEmail: true }),
    });
  } catch (error) {
    logger.error('Switch role error', error);
    if (error.code === 11000) {
      // Duplicate key error (email already exists)
      return res.status(409).json({ error: 'Email already exists. Unable to switch role.' });
    }
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid user id.' });
    }
    if (error.message && error.message.includes('JWT_SECRET')) {
      return res.status(500).json({ error: 'Authentication service is not configured.' });
    }
    res.status(500).json({ error: 'Unable to switch role. Please try again later.' });
  }
};

const resolveUserModel = (role) => {
  if (role === 'sitter') return Sitter;
  if (role === 'owner') return Owner;
  return null;
};

const acceptTerms = async (req, res) => {
  try {
    const Model = resolveUserModel(req.user?.role);
    if (!Model) return res.status(403).json({ error: 'Unsupported role.' });
    const version = process.env.TERMS_VERSION || 'v1.0';
    const result = await Model.findByIdAndUpdate(
      req.user.id,
      {
        acceptedTerms: true,
        termsAcceptedAt: new Date(),
        termsVersion: version,
      },
      { new: true }
    ).select('acceptedTerms termsAcceptedAt termsVersion');
    if (!result) return res.status(404).json({ error: 'User not found.' });
    return res.json({
      acceptedTerms: result.acceptedTerms,
      termsAcceptedAt: result.termsAcceptedAt,
      termsVersion: result.termsVersion,
    });
  } catch (e) {
    logger.error('acceptTerms error', e);
    return res.status(500).json({ error: 'Unable to record terms acceptance.' });
  }
};

const registerFcmToken = async (req, res) => {
  try {
    const { token } = req.body || {};
    if (!token || typeof token !== 'string' || !token.trim()) {
      return res.status(400).json({ error: 'token is required.' });
    }
    const Model = resolveUserModel(req.user?.role);
    if (!Model) return res.status(403).json({ error: 'Unsupported role for FCM registration.' });
    const result = await Model.findByIdAndUpdate(
      req.user.id,
      { $addToSet: { fcmTokens: token.trim() } },
      { new: true }
    ).select('fcmTokens');
    if (!result) return res.status(404).json({ error: 'User not found.' });
    return res.json({ ok: true, count: result.fcmTokens.length });
  } catch (e) {
    logger.error('registerFcmToken error', e);
    return res.status(500).json({ error: 'Unable to register FCM token.' });
  }
};

const unregisterFcmToken = async (req, res) => {
  try {
    const { token } = req.body || {};
    if (!token || typeof token !== 'string' || !token.trim()) {
      return res.status(400).json({ error: 'token is required.' });
    }
    const Model = resolveUserModel(req.user?.role);
    if (!Model) return res.status(403).json({ error: 'Unsupported role for FCM unregistration.' });
    const result = await Model.findByIdAndUpdate(
      req.user.id,
      { $pull: { fcmTokens: token.trim() } },
      { new: true }
    ).select('fcmTokens');
    if (!result) return res.status(404).json({ error: 'User not found.' });
    return res.json({ ok: true, count: result.fcmTokens.length });
  } catch (e) {
    logger.error('unregisterFcmToken error', e);
    return res.status(500).json({ error: 'Unable to unregister FCM token.' });
  }
};

module.exports = {
  updateService,
  updateProfile,
  updateCard,
  updateOwnerCardFromToken,
  deleteAccountFromToken,
  deleteAccount,
  updateProfilePicture,
  getOwnerProfile,
  switchRole,
  registerFcmToken,
  unregisterFcmToken,
  acceptTerms,
  getMyLoyalty,
  getMyReferralsRoute,
};

// Sprint 7 step 3 — referral program.
async function getMyReferralsRoute(req, res) {
  try {
    const role = req.user?.role;
    if (role !== 'owner' && role !== 'sitter') {
      return res.status(403).json({ error: 'Unsupported role.' });
    }
    const data = await getMyReferrals(req.user.id, role);
    res.json(data);
  } catch (e) {
    logger.error('getMyReferrals error', e);
    res.status(500).json({ error: 'Unable to load referrals.' });
  }
}

// Sprint 7 step 1 — loyalty stats for owner self.
async function getMyLoyalty(req, res) {
  try {
    if (req.user?.role !== 'owner') {
      return res.status(403).json({ error: 'Only owners have a loyalty program.' });
    }
    const stats = await getOwnerStats(req.user.id);
    return res.json(stats);
  } catch (e) {
    logger.error('getMyLoyalty error', e);
    return res.status(500).json({ error: 'Unable to load loyalty stats.' });
  }
}

