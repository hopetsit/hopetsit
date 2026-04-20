const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const Post = require('../models/Post');
const Pet = require('../models/Pet');
const { sanitizePost } = require('../utils/sanitize');
const { isOwnerSitterInteractionBlocked } = require('../services/blockService');
const { uploadMedia } = require('../services/cloudinary');
const { createNotificationSafe } = require('../services/notificationService');
const { translateToAll } = require('../services/translationService');
const logger = require('../utils/logger');

const HOUSE_SITTING_VENUES = ['owners_home', 'sitters_home'];

const normalizeHouseSittingVenue = (value) => {
  if (value == null) return null;
  const normalized = String(value).trim().toLowerCase();
  if (!normalized) return null;
  return HOUSE_SITTING_VENUES.includes(normalized) ? normalized : null;
};

const includesHouseSittingService = (serviceTypes = []) => {
  const normalizedServices = (Array.isArray(serviceTypes) ? serviceTypes : [serviceTypes])
    .map((s) => String(s || '').trim().toLowerCase())
    .filter(Boolean);
  return normalizedServices.includes('house_sitting') || normalizedServices.includes('house sitting');
};

const createPost = async (req, res) => {
  try {
    const { body, startDate, endDate, serviceTypes, petId, location, notes, houseSittingVenue, serviceLocation } = req.body || {};
    const ownerId = req.user?.id;

    if (!ownerId) {
      return res.status(403).json({ error: 'Owner context missing.' });
    }

    const trimmedBody = typeof body === 'string' ? body.trim() : '';

    if (!trimmedBody) {
      return res.status(400).json({ error: 'Post body is required.' });
    }

    const owner = await Owner.findById(ownerId);
    if (!owner) {
      return res.status(404).json({ error: 'Owner not found.' });
    }

    const postPayload = {
      ownerId,
      body: trimmedBody,
      postType: 'request',
    };

    // Optional dates (store as Date objects)
    if (startDate) {
      const parsedStart = new Date(startDate);
      if (!Number.isNaN(parsedStart.getTime())) {
        postPayload.startDate = parsedStart;
      }
    }
    if (endDate) {
      const parsedEnd = new Date(endDate);
      if (!Number.isNaN(parsedEnd.getTime())) {
        postPayload.endDate = parsedEnd;
      }
    }

    const rawServices =
      Array.isArray(serviceTypes) ? serviceTypes : serviceTypes != null ? [serviceTypes] : [];
    const normalizedServices = rawServices
      .map((s) => (typeof s === 'string' ? s.trim() : String(s).trim()))
      .filter(Boolean);
    if (normalizedServices.length > 0) {
      postPayload.serviceTypes = normalizedServices;
    }

    const normalizedVenue = normalizeHouseSittingVenue(houseSittingVenue);
    const isHouseSittingPost = includesHouseSittingService(normalizedServices);
    if (isHouseSittingPost) {
      if (!normalizedVenue) {
        return res.status(400).json({
          error: 'houseSittingVenue is required for house_sitting service and must be owners_home or sitters_home.',
        });
      }
      postPayload.houseSittingVenue = normalizedVenue;
    } else if (houseSittingVenue != null && !normalizedVenue) {
      return res.status(400).json({
        error: 'houseSittingVenue must be owners_home or sitters_home when provided.',
      });
    } else if (normalizedVenue) {
      postPayload.houseSittingVenue = normalizedVenue;
    }

    if (petId) {
      postPayload.petId = petId;
    }

    // Location can come as object (JSON body) or JSON string (multipart-style clients)
    if (location) {
      let parsedLocation = location;
      if (typeof parsedLocation === 'string') {
        try {
          parsedLocation = JSON.parse(parsedLocation);
        } catch (e) {
          parsedLocation = null;
        }
      }
      if (parsedLocation && typeof parsedLocation === 'object') {
        postPayload.location = parsedLocation;
      }
    }

    if (typeof notes === 'string' && notes.trim()) {
      postPayload.notes = notes.trim();
    }

    // Sprint 5 step 2 — service location preference.
    if (['at_owner', 'at_sitter', 'both'].includes(serviceLocation)) {
      postPayload.serviceLocation = serviceLocation;
    }

    // Sprint 4 step 6 — auto-translate body to all supported locales.
    try {
      const sourceLang =
        (typeof req.body?.language === 'string' && req.body.language) ||
        owner.language ||
        'en';
      const { translations, sourceLanguage } = await translateToAll(trimmedBody, sourceLang);
      postPayload.translations = translations;
      postPayload.sourceLanguage = sourceLanguage;
    } catch (e) {
      logger.warn('Post translation failed (non-blocking):', e?.message || e);
    }

    const newPost = await Post.create(postPayload);

    await newPost.populate('ownerId');

    res.status(201).json({ post: sanitizePost(newPost) });
  } catch (error) {
    logger.error('Create post error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid owner id.' });
    }
    res.status(500).json({ error: 'Unable to create post. Please try again later.' });
  }
};

const listPosts = async (req, res) => {
  try {
    const { ownerId } = req.query;
    const filter = ownerId ? { ownerId } : { ownerId: { $ne: null } };
    const posts = await Post.find(filter).sort({ createdAt: -1 }).populate('ownerId');

    // Safety filter: never return posts without a valid ownerId
    const visiblePosts = posts.filter((post) => !!post.ownerId);
    
    // Enhanced posts with pet information
    const enhancedPosts = await Promise.all(
      visiblePosts.map(async (post) => {
        const sanitizedPost = sanitizePost(post);
        
        // Get owner information
        const owner = post.ownerId;
        const ownerData = {
          id: owner?._id?.toString() || '',
          name: owner?.name || '',
          email: owner?.email || '',
          avatar: owner?.avatar?.url || '',
        };
        
        // Get all pets for this owner
        const pets = await Pet.find({ ownerId: owner?._id || owner }).sort({ createdAt: -1 });
        const petsData = pets.map((pet) => ({
          id: pet._id.toString(),
          petName: pet.petName || '',
          avatar: pet.avatar?.url || '',
          photos: Array.isArray(pet.photos) 
            ? pet.photos.map((photo) => ({
                url: photo.url || '',
                publicId: photo.publicId || '',
                uploadedAt: photo.uploadedAt || null,
              }))
            : [],
        }));
        
        return {
          ...sanitizedPost,
          owner: ownerData,
          pets: petsData,
          likesCount: sanitizedPost.likesCount || 0,
          commentsCount: sanitizedPost.commentsCount || 0,
        };
      })
    );
    
    res.json({
      posts: enhancedPosts,
    });
  } catch (error) {
    logger.error('Fetch posts error', error);
    res.status(500).json({ error: 'Unable to fetch posts. Please try again later.' });
  }
};

const getMediaPosts = async (req, res) => {
  try {
    const { ownerId } = req.query;
    const filter = { postType: 'media' };
    if (ownerId) {
      filter.ownerId = ownerId;
    }
    
    const posts = await Post.find(filter).sort({ createdAt: -1 }).populate('ownerId');
    const visiblePosts = posts.filter((post) => !!post.ownerId);
    
    // Enhanced posts with pet information
    const enhancedPosts = await Promise.all(
      visiblePosts.map(async (post) => {
        const sanitizedPost = sanitizePost(post);
        
        // Get owner information
        const owner = post.ownerId;
        const ownerData = {
          id: owner?._id?.toString() || '',
          name: owner?.name || '',
          email: owner?.email || '',
          avatar: owner?.avatar?.url || '',
        };
        
        // Get all pets for this owner
        const pets = await Pet.find({ ownerId: owner?._id || owner }).sort({ createdAt: -1 });
        const petsData = pets.map((pet) => ({
          id: pet._id.toString(),
          petName: pet.petName || '',
          avatar: pet.avatar?.url || '',
          photos: Array.isArray(pet.photos) 
            ? pet.photos.map((photo) => ({
                url: photo.url || '',
                publicId: photo.publicId || '',
                uploadedAt: photo.uploadedAt || null,
              }))
            : [],
        }));
        
        return {
          ...sanitizedPost,
          owner: ownerData,
          pets: petsData,
          likesCount: sanitizedPost.likesCount || 0,
          commentsCount: sanitizedPost.commentsCount || 0,
        };
      })
    );
    
    res.json({
      posts: enhancedPosts,
      count: enhancedPosts.length,
    });
  } catch (error) {
    logger.error('Fetch media posts error', error);
    res.status(500).json({ error: 'Unable to fetch media posts. Please try again later.' });
  }
};

const getRequestPosts = async (req, res) => {
  try {
    const { ownerId } = req.query;
    // hidden=true means an admin has banned/hidden the post — never surface
    // those on normal user feeds (admin has its own endpoint for that).
    const filter = { postType: 'request', hidden: { $ne: true } };
    if (ownerId) {
      filter.ownerId = ownerId;
    }

    // Sprint 5 step 2 — filter requests by sitter's service preferences.
    if (req.user?.role === 'sitter') {
      const viewer = await Sitter.findById(req.user.id).select('canServiceAtOwner canServiceAtSitter').lean();
      if (viewer) {
        const allowed = [];
        if (viewer.canServiceAtOwner) allowed.push('at_owner');
        if (viewer.canServiceAtSitter) allowed.push('at_sitter');
        // 'both' is always acceptable when at least one side matches, which is always true
        // unless the sitter has disabled both (in which case we return nothing).
        if (allowed.length === 0) {
          return res.json({ posts: [] });
        }
        allowed.push('both');
        filter.serviceLocation = { $in: allowed };
      }
      // Session avril 2026 — walking requests are walker-exclusive. Any
      // post whose serviceTypes array contains 'dog_walking' is removed
      // from the sitter's feed so walkers get first dibs on walks. Mongo
      // $nin against an array field excludes docs where the array
      // intersects the provided list.
      filter.serviceTypes = { $nin: ['dog_walking'] };
    }

    // Session avril 2026 — walkers only see posts that request a walk.
    if (req.user?.role === 'walker') {
      filter.serviceTypes = 'dog_walking';
    }

    const posts = await Post.find(filter).sort({ createdAt: -1 }).populate('ownerId');
    const visiblePosts = posts.filter((post) => !!post.ownerId);
    
    // Enhanced posts with pet information
    const enhancedPosts = await Promise.all(
      visiblePosts.map(async (post) => {
        const sanitizedPost = sanitizePost(post);
        
        // Get owner information
        const owner = post.ownerId;
        const ownerData = {
          id: owner?._id?.toString() || '',
          name: owner?.name || '',
          email: owner?.email || '',
          avatar: owner?.avatar?.url || '',
        };
        
        // Get all pets for this owner
        const pets = await Pet.find({ ownerId: owner?._id || owner }).sort({ createdAt: -1 });
        const petsData = pets.map((pet) => ({
          id: pet._id.toString(),
          petName: pet.petName || '',
          avatar: pet.avatar?.url || '',
          photos: Array.isArray(pet.photos) 
            ? pet.photos.map((photo) => ({
                url: photo.url || '',
                publicId: photo.publicId || '',
                uploadedAt: photo.uploadedAt || null,
              }))
            : [],
        }));
        
        return {
          ...sanitizedPost,
          owner: ownerData,
          pets: petsData,
        };
      })
    );
    
    res.json({
      posts: enhancedPosts,
      count: enhancedPosts.length,
    });
  } catch (error) {
    logger.error('Fetch request posts error', error);
    res.status(500).json({ error: 'Unable to fetch request posts. Please try again later.' });
  }
};

/**
 * GET /posts/requests/nearby — returns owner reservation requests within a
 * given radius of a geographic point. Used by sitter/walker PawMap layer.
 *
 * Query params:
 *   lat          required  Latitude of the viewer (e.g. the sitter).
 *   lng          required  Longitude of the viewer.
 *   maxDistance  optional  Search radius in kilometers (default 25).
 *
 * Posts are filtered by the same sitter service-preference logic as
 * getRequestPosts so sitters only see requests they can fulfill. Distance is
 * computed with the haversine formula in JS because `Post.location` is a
 * plain { city, lat, lng } object (no 2dsphere index). Good enough for MVP;
 * migrate to a geo index when the dataset grows.
 */
const getNearbyRequestPosts = async (req, res) => {
  try {
    const lat = parseFloat(req.query.lat);
    const lng = parseFloat(req.query.lng);
    const maxDistanceKm = Math.min(
      parseFloat(req.query.maxDistance || '25'),
      200,
    );

    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      return res
        .status(400)
        .json({ error: 'Valid lat and lng query params are required.' });
    }

    const filter = { postType: 'request', hidden: { $ne: true } };

    // Sitter service-preference filter (mirrors getRequestPosts).
    if (req.user?.role === 'sitter') {
      const viewer = await Sitter.findById(req.user.id)
        .select('canServiceAtOwner canServiceAtSitter')
        .lean();
      if (viewer) {
        const allowed = [];
        if (viewer.canServiceAtOwner) allowed.push('at_owner');
        if (viewer.canServiceAtSitter) allowed.push('at_sitter');
        if (allowed.length === 0) {
          return res.json({ posts: [], count: 0, radiusKm: maxDistanceKm });
        }
        allowed.push('both');
        filter.serviceLocation = { $in: allowed };
      }
      // Walking requests are walker-exclusive — hide them from sitter map.
      filter.serviceTypes = { $nin: ['dog_walking'] };
    }

    // Walkers on the PawMap only see walking requests.
    if (req.user?.role === 'walker') {
      filter.serviceTypes = 'dog_walking';
    }

    // Discard posts without coordinates — they can't appear on a map.
    filter['location.lat'] = { $ne: null };
    filter['location.lng'] = { $ne: null };

    const raw = await Post.find(filter)
      .sort({ createdAt: -1 })
      .populate('ownerId')
      .lean();

    // Haversine great-circle distance in kilometers.
    const toRad = (x) => (x * Math.PI) / 180;
    const R = 6371;
    const haversine = (lat1, lng1, lat2, lng2) => {
      const dLat = toRad(lat2 - lat1);
      const dLng = toRad(lng2 - lng1);
      const a =
        Math.sin(dLat / 2) ** 2 +
        Math.cos(toRad(lat1)) *
          Math.cos(toRad(lat2)) *
          Math.sin(dLng / 2) ** 2;
      return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    };

    const withDistance = raw
      .filter(
        (p) =>
          p.ownerId &&
          p.location &&
          Number.isFinite(p.location.lat) &&
          Number.isFinite(p.location.lng),
      )
      .map((p) => ({
        post: p,
        distanceKm: haversine(lat, lng, p.location.lat, p.location.lng),
      }))
      .filter((x) => x.distanceKm <= maxDistanceKm)
      .sort((a, b) => a.distanceKm - b.distanceKm)
      .slice(0, 200); // hard cap for the map payload

    const posts = withDistance.map(({ post, distanceKm }) => ({
      id: post._id.toString(),
      ownerId: post.ownerId?._id?.toString() || '',
      ownerName: post.ownerId?.name || '',
      ownerAvatar: post.ownerId?.avatar?.url || '',
      body: post.body || '',
      serviceTypes: post.serviceTypes || [],
      serviceLocation: post.serviceLocation || '',
      startDate: post.startDate,
      endDate: post.endDate,
      location: {
        city: post.location.city || '',
        lat: post.location.lat,
        lng: post.location.lng,
      },
      distanceKm: Number(distanceKm.toFixed(2)),
      createdAt: post.createdAt,
    }));

    res.json({ posts, count: posts.length, radiusKm: maxDistanceKm });
  } catch (error) {
    logger.error('[posts/requests/nearby] Error', error);
    res.status(500).json({ error: 'Unable to fetch nearby requests.' });
  }
};

const toggleLike = async (req, res) => {
  try {
    const { id } = req.params;
    
    // Get user info from authenticated token
    const userId = req.user?.id;
    const role = req.user?.role;

    if (!userId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (!role) {
      return res.status(401).json({ error: 'User role not found in token.' });
    }

    const normalizedRole = String(role).toLowerCase();
    if (!['owner', 'sitter'].includes(normalizedRole)) {
      return res.status(400).json({ error: 'Invalid role. Expected "owner" or "sitter".' });
    }

    const Model = normalizedRole === 'owner' ? Owner : Sitter;
    const userExists = await Model.exists({ _id: userId });
    if (!userExists) {
      return res.status(404).json({ error: 'User not found.' });
    }

    const post = await Post.findById(id);
    if (!post) {
      return res.status(404).json({ error: 'Post not found.' });
    }

    // Check if sitter is blocked by owner (use stored ownerId so we never pass "null" to Block query)
    const ownerIdStored = post.ownerId ? post.ownerId.toString() : null;
    if (normalizedRole === 'sitter' && ownerIdStored) {
      const isBlocked = await isOwnerSitterInteractionBlocked(ownerIdStored, userId);
      if (isBlocked) {
        return res.status(403).json({ error: 'You cannot interact with this owner.' });
      }
    }

    // Toggle like: if already liked, remove it (dislike); otherwise add it (like)
    const existingIndex = post.likes.findIndex(
      (like) => like.userId.toString() === userId.toString()
    );
    
    let action = 'disliked';
    if (existingIndex >= 0) {
      post.likes.splice(existingIndex, 1);
    } else {
      post.likes.push({
        userId,
        userRole: normalizedRole === 'owner' ? 'Owner' : 'Sitter',
      });
      action = 'liked';
    }

    await post.save();
    await post.populate('ownerId');
    if (!post.ownerId && ownerIdStored) {
      post.ownerId = ownerIdStored;
    }

    if (action === 'liked') {
      const recipientOwnerId =
        post.ownerId && typeof post.ownerId === 'object' && post.ownerId._id
          ? post.ownerId._id.toString()
          : ownerIdStored;

      // Never notify the actor about their own post interaction
      if (recipientOwnerId && recipientOwnerId !== userId.toString()) {
        await createNotificationSafe({
          recipientRole: 'owner',
          recipientId: recipientOwnerId,
          actorRole: normalizedRole,
          actorId: userId,
          type: 'post_like',
          title: 'New like',
          body: normalizedRole === 'owner' ? 'An owner liked your post.' : 'A sitter liked your post.',
          data: {
            postId: post._id.toString(),
          },
        });
      }
    }

    res.json({ 
      post: sanitizePost(post),
      action: action,
      message: action === 'liked' ? 'Post liked successfully' : 'Post disliked successfully'
    });
  } catch (error) {
    logger.error('Toggle like error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid post id.' });
    }
    res.status(500).json({ error: 'Unable to update like. Please try again later.' });
  }
};

const addComment = async (req, res) => {
  try {
    const { id } = req.params;
    const { body } = req.body || {};
    const userId = req.user?.id;
    const userRole = req.user?.role;

    if (!userId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (!userRole || !['owner', 'sitter', 'walker'].includes(userRole.toLowerCase())) {
      return res.status(400).json({ error: 'Invalid user role. Expected "owner", "sitter" or "walker".' });
    }

    if (!body) {
      return res.status(400).json({ error: 'Comment body is required.' });
    }

    const trimmedBody = String(body).trim();
    if (!trimmedBody) {
      return res.status(400).json({ error: 'Comment body cannot be empty.' });
    }

    const normalizedRole = userRole.toLowerCase();
    const Model = normalizedRole === 'owner'
      ? Owner
      : (normalizedRole === 'walker' ? Walker : Sitter);
    const author = await Model.findById(userId);
    if (!author) {
      return res.status(404).json({ error: 'User not found.' });
    }

    const post = await Post.findById(id);
    if (!post) {
      return res.status(404).json({ error: 'Post not found.' });
    }

    const ownerIdStored = post.ownerId ? post.ownerId.toString() : null;
    if (normalizedRole === 'sitter' && ownerIdStored) {
      const isBlocked = await isOwnerSitterInteractionBlocked(ownerIdStored, userId);
      if (isBlocked) {
        return res.status(403).json({ error: 'You cannot interact with this owner.' });
      }
    }

    post.comments.push({
      userId,
      userRole: normalizedRole === 'owner'
        ? 'Owner'
        : (normalizedRole === 'walker' ? 'Walker' : 'Sitter'),
      authorName: author.name || '',
      authorAvatar: { url: author.avatar?.url || '' },
      body: trimmedBody,
    });

    await post.save();
    await post.populate('ownerId');
    if (!post.ownerId && ownerIdStored) {
      post.ownerId = ownerIdStored;
    }

    const recipientOwnerId =
      post.ownerId && typeof post.ownerId === 'object' && post.ownerId._id
        ? post.ownerId._id.toString()
        : ownerIdStored;

    // Never notify the actor about their own post interaction
    if (recipientOwnerId && recipientOwnerId !== userId.toString()) {
      await createNotificationSafe({
        recipientRole: 'owner',
        recipientId: recipientOwnerId,
        actorRole: normalizedRole,
        actorId: userId,
        type: 'post_comment',
        title: 'New comment',
        body: trimmedBody,
        data: {
          postId: post._id.toString(),
        },
      });
    }

    res.status(201).json({ 
      message: 'Comment added successfully.',
      post: sanitizePost(post) 
    });
  } catch (error) {
    logger.error('Add comment error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid post id.' });
    }
    res.status(500).json({ error: 'Unable to add comment. Please try again later.' });
  }
};

const deleteComment = async (req, res) => {
  try {
    const { id, commentId } = req.params;
    const { userId } = req.body || {};

    if (!commentId) {
      return res.status(400).json({ error: 'commentId is required.' });
    }

    const post = await Post.findById(id).populate('ownerId');
    if (!post) {
      return res.status(404).json({ error: 'Post not found.' });
    }

    const commentIndex = post.comments.findIndex(
      (comment) => comment._id?.toString() === commentId
    );

    if (commentIndex === -1) {
      return res.status(404).json({ error: 'Comment not found.' });
    }

    const comment = post.comments[commentIndex];
    if (userId && comment.userId?.toString() !== userId.toString()) {
      return res.status(403).json({ error: 'You can only delete your own comments.' });
    }

    post.comments.splice(commentIndex, 1);
    await post.save();
    await post.populate('ownerId');

    res.json({ post: sanitizePost(post) });
  } catch (error) {
    logger.error('Delete comment error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid id provided.' });
    }
    res.status(500).json({ error: 'Unable to delete comment. Please try again later.' });
  }
};

const deletePost = async (req, res) => {
  try {
    const { id } = req.params;
    const ownerId = req.user?.id;
    const userRole = req.user?.role;

    if (!ownerId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (userRole !== 'owner') {
      return res.status(403).json({ error: 'Only owners can delete posts.' });
    }

    const post = await Post.findById(id);
    if (!post) {
      return res.status(404).json({ error: 'Post not found.' });
    }

    if (post.ownerId.toString() !== ownerId.toString()) {
      return res.status(403).json({ error: 'You can only delete your own posts.' });
    }

    await Post.findByIdAndDelete(id);

    return res.json({
      message: 'Post deleted successfully.',
      postId: id,
    });
  } catch (error) {
    logger.error('Delete post error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid post id.' });
    }
    return res.status(500).json({ error: 'Unable to delete post. Please try again later.' });
  }
};

const bufferToDataUri = (file) => `data:${file.mimetype};base64,${file.buffer.toString('base64')}`;

const createPostWithMedia = async (req, res) => {
  try {
    const ownerId = req.user?.id;
    const userRole = req.user?.role;
    const { body, folder, startDate, endDate, serviceTypes, petId, location, notes, houseSittingVenue } = req.body || {};

    if (!ownerId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (userRole !== 'owner') {
      return res.status(403).json({ error: 'Only owners can create posts.' });
    }

    const owner = await Owner.findById(ownerId);
    if (!owner) {
      return res.status(404).json({ error: 'Owner not found.' });
    }

    // Check if files are provided
    if (!req.files || Object.keys(req.files).length === 0) {
      return res.status(400).json({ error: 'At least one image or video file is required.' });
    }

    // Validate file types
    const allowedMimeTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'video/mp4', 'video/quicktime', 'video/x-msvideo'];
    
    const uploadFolder = folder || `petsinsta/posts/${ownerId}`;
    const uploadedImages = [];
    const uploadedVideos = [];

    // Process uploaded files
    const fieldToMediaType = {
      image: 'image',
      images: 'image',
      photo: 'image',
      photos: 'image',
      video: 'video',
      videos: 'video',
      file: 'image', // default fallback
      media: 'image', // default fallback
    };

    for (const [fieldName, files] of Object.entries(req.files)) {
      const detectedMediaType = fieldToMediaType[fieldName] || 'image';
      const resourceType = detectedMediaType === 'video' ? 'video' : 'image';

      for (const file of files) {
        // Validate file type
        if (!allowedMimeTypes.includes(file.mimetype)) {
          return res.status(400).json({ 
            error: `Invalid file type for ${file.originalname}. Only JPEG, PNG, WebP images and MP4, MOV, AVI videos are allowed.` 
          });
        }

        const dataUri = bufferToDataUri(file);
        const uploadResult = await uploadMedia({
          file: dataUri,
          folder: uploadFolder,
          resourceType,
        });

        // Session v3.3 — Google Vision Safe Search hook. No-op when
        // CONTENT_MODERATION_ENABLED is off; rejects adult/violence images
        // and cleans up the Cloudinary asset before we save the post.
        if (detectedMediaType === 'image') {
          const { rejectIfUnsafe } = require('../services/contentModerationService');
          try {
            await rejectIfUnsafe(uploadResult);
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

        const mediaEntry = {
          url: uploadResult.url,
          publicId: uploadResult.publicId,
          uploadedAt: new Date(),
        };

        if (detectedMediaType === 'image') {
          uploadedImages.push(mediaEntry);
        } else if (detectedMediaType === 'video') {
          uploadedVideos.push(mediaEntry);
        }
      }
    }

    // Body is optional - use empty string if not provided
    const trimmedBody = typeof body === 'string' ? body.trim() : '';

    const postPayload = {
      ownerId,
      body: trimmedBody,
      images: uploadedImages,
      videos: uploadedVideos,
      postType: 'media',
    };

    // Optional dates (store as Date objects)
    if (startDate) {
      const parsedStart = new Date(startDate);
      if (!Number.isNaN(parsedStart.getTime())) {
        postPayload.startDate = parsedStart;
      }
    }
    if (endDate) {
      const parsedEnd = new Date(endDate);
      if (!Number.isNaN(parsedEnd.getTime())) {
        postPayload.endDate = parsedEnd;
      }
    }

    const rawServices =
      Array.isArray(serviceTypes) ? serviceTypes : serviceTypes != null ? [serviceTypes] : [];
    const normalizedServices = rawServices
      .map((s) => (typeof s === 'string' ? s.trim() : String(s).trim()))
      .filter(Boolean);
    if (normalizedServices.length > 0) {
      postPayload.serviceTypes = normalizedServices;
    }

    const normalizedVenue = normalizeHouseSittingVenue(houseSittingVenue);
    const isHouseSittingPost = includesHouseSittingService(normalizedServices);
    if (isHouseSittingPost) {
      if (!normalizedVenue) {
        return res.status(400).json({
          error: 'houseSittingVenue is required for house_sitting service and must be owners_home or sitters_home.',
        });
      }
      postPayload.houseSittingVenue = normalizedVenue;
    } else if (houseSittingVenue != null && !normalizedVenue) {
      return res.status(400).json({
        error: 'houseSittingVenue must be owners_home or sitters_home when provided.',
      });
    } else if (normalizedVenue) {
      postPayload.houseSittingVenue = normalizedVenue;
    }

    if (petId) {
      postPayload.petId = petId;
    }

    // Location can come as object (when backend receives JSON) or JSON string (multipart/form-data)
    if (location) {
      let parsedLocation = location;
      if (typeof parsedLocation === 'string') {
        try {
          parsedLocation = JSON.parse(parsedLocation);
        } catch (e) {
          parsedLocation = null;
        }
      }
      if (parsedLocation && typeof parsedLocation === 'object') {
        postPayload.location = parsedLocation;
      }
    }

    if (typeof notes === 'string' && notes.trim()) {
      postPayload.notes = notes.trim();
    }

    // Create the post
    const newPost = await Post.create(postPayload);

    await newPost.populate('ownerId');

    res.status(201).json({ 
      message: 'Post created successfully.',
      post: sanitizePost(newPost),
    });
  } catch (error) {
    logger.error('Create post with media error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid owner id.' });
    }
    if (error.message && error.message.includes('Cloudinary')) {
      return res.status(502).json({ error: 'Media service is unavailable. Please try again later.' });
    }
    res.status(500).json({ error: 'Unable to create post. Please try again later.' });
  }
};

/**
 * updatePost — allows the post owner to edit their own publication.
 * Accepts a subset of editable fields. Protects ownerId and timestamps.
 */
const updatePost = async (req, res) => {
  try {
    const { id } = req.params;
    const ownerId = req.user?.id;
    const userRole = req.user?.role;

    if (!ownerId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (userRole !== 'owner') {
      return res.status(403).json({ error: 'Only owners can edit posts.' });
    }

    const post = await Post.findById(id);
    if (!post) {
      return res.status(404).json({ error: 'Post not found.' });
    }

    if (post.ownerId.toString() !== ownerId.toString()) {
      return res.status(403).json({ error: 'You can only edit your own posts.' });
    }

    // Whitelist of editable fields only. Never allow ownerId, postType, images, videos,
    // likes, comments or timestamps to be overwritten via this endpoint.
    const {
      body,
      startDate,
      endDate,
      serviceTypes,
      petId,
      location,
      notes,
      houseSittingVenue,
    } = req.body || {};

    if (typeof body === 'string') {
      const trimmed = body.trim();
      if (!trimmed) {
        return res.status(400).json({ error: 'Post body cannot be empty.' });
      }
      post.body = trimmed;
    }

    if (startDate !== undefined) {
      post.startDate = startDate ? new Date(startDate) : null;
    }
    if (endDate !== undefined) {
      post.endDate = endDate ? new Date(endDate) : null;
    }

    if (serviceTypes !== undefined) {
      post.serviceTypes = Array.isArray(serviceTypes)
        ? serviceTypes.map((s) => String(s || '').trim()).filter(Boolean)
        : [];
    }

    if (houseSittingVenue !== undefined) {
      const normalized = normalizeHouseSittingVenue(houseSittingVenue);
      post.houseSittingVenue = normalized;
    }

    if (petId !== undefined) {
      post.petId = petId || null;
    }

    if (location !== undefined) {
      post.location = location || null;
    }

    if (typeof notes === 'string') {
      post.notes = notes.trim();
    }

    await post.save();
    await post.populate('ownerId');

    return res.json({
      message: 'Post updated successfully.',
      post: sanitizePost(post),
    });
  } catch (error) {
    logger.error('Update post error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid post id.' });
    }
    return res.status(500).json({ error: 'Unable to update post. Please try again later.' });
  }
};

/**
 * v16.3h — Fetch a single post by ID. Used by the mobile client when a
 * notification payload carries a postId that is not currently in the user's
 * feed cache (e.g. a like notification for a post that belongs to another
 * user). Returns 404 when the post does not exist or has been hidden.
 */
const getPostById = async (req, res) => {
  try {
    const { id } = req.params;
    if (!id) {
      return res.status(400).json({ error: 'Post id is required.' });
    }
    const post = await Post.findById(id)
      .populate('ownerId')
      .populate('petId');
    if (!post) {
      return res.status(404).json({ error: 'Post not found.' });
    }
    if (post.hidden) {
      return res.status(404).json({ error: 'Post is no longer available.' });
    }
    return res.json({ post: sanitizePost(post) });
  } catch (error) {
    logger.error('Get post by id error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid post id.' });
    }
    return res.status(500).json({ error: 'Unable to load post. Please try again later.' });
  }
};

module.exports = {
  createPost,
  createPostWithMedia,
  listPosts,
  getMediaPosts,
  getRequestPosts,
  getNearbyRequestPosts,
  getPostById,
  toggleLike,
  addComment,
  deleteComment,
  deletePost,
  updatePost,
};
