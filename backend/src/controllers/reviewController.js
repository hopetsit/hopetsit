const mongoose = require('mongoose');

const Review = require('../models/Review');
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const { sanitizeDoc, sanitizeReview } = require('../utils/sanitize');
const { sendNotification } = require('../services/notificationSender');
const { recomputeSitterStatus } = require('../services/loyaltyService');

const ROLE_TO_MODEL = {
  owner: 'Owner',
  sitter: 'Sitter',
};

const getModelByRole = (role) => {
  const modelName = ROLE_TO_MODEL[role];
  if (!modelName) return null;
  return modelName === 'Owner' ? Owner : Sitter;
};

const createReview = async (req, res) => {
  try {
    // Get owner ID from authenticated token
    const reviewerId = req.user.id;
    const reviewerRole = 'owner';
    
    const { revieweeId, revieweeRole = 'sitter', rating, comment = '' } = req.body || {};

    if (!reviewerId || !mongoose.Types.ObjectId.isValid(reviewerId)) {
      return res.status(400).json({ error: 'Valid reviewerId is required.' });
    }
    if (!revieweeId || !mongoose.Types.ObjectId.isValid(revieweeId)) {
      return res.status(400).json({ error: 'Valid revieweeId (sitter ID) is required.' });
    }
    if (!ROLE_TO_MODEL[reviewerRole] || !ROLE_TO_MODEL[revieweeRole]) {
      return res.status(400).json({ error: 'Invalid roles provided.' });
    }
    if (String(reviewerId) === String(revieweeId) && reviewerRole === revieweeRole) {
      return res.status(400).json({ error: 'You cannot review yourself.' });
    }
    
    // Support float ratings (1.5, 2.5, etc.)
    const numericRating = Number(rating);
    if (!Number.isFinite(numericRating) || numericRating < 1 || numericRating > 5) {
      return res.status(400).json({ error: 'Rating must be between 1 and 5 (decimals like 1.5, 2.5 are allowed).' });
    }

    const reviewerModel = getModelByRole(reviewerRole);
    const revieweeModel = getModelByRole(revieweeRole);

    const reviewerExists = await reviewerModel.exists({ _id: reviewerId });
    if (!reviewerExists) {
      return res.status(404).json({ error: 'Reviewer not found.' });
    }

    if (reviewerRole !== 'owner' || revieweeRole !== 'sitter') {
      return res.status(403).json({
        error: 'Only pet owners can review pet sitters.',
      });
    }

    const reviewee = await revieweeModel.findById(revieweeId);
    if (!reviewee) {
      return res.status(404).json({ error: 'Sitter not found.' });
    }

    const review = await Review.create({
      reviewerId,
      reviewerModel: ROLE_TO_MODEL[reviewerRole],
      revieweeId,
      revieweeModel: ROLE_TO_MODEL[revieweeRole],
      rating: numericRating,
      comment: comment.trim(),
    });

    if (revieweeRole === 'sitter') {
      const previousTotal = (reviewee.rating || 0) * (reviewee.reviewsCount || 0);
      const newReviewsCount = (reviewee.reviewsCount || 0) + 1;
      const newAverage = (previousTotal + numericRating) / newReviewsCount;
      reviewee.rating = Number(newAverage.toFixed(2));
      reviewee.reviewsCount = newReviewsCount;
      await reviewee.save();
    }

    // Sprint 7 step 2 — recompute Top Sitter status if the reviewee is a sitter.
    if (revieweeRole === 'sitter') {
      recomputeSitterStatus(revieweeId).catch(() => {});
    }

    // Sprint 4 step 3 — NEW_REVIEW to reviewee
    sendNotification({
      userId: String(revieweeId),
      role: revieweeRole,
      type: 'NEW_REVIEW',
      data: {
        reviewId: review._id.toString(),
        rating: numericRating,
        comment: (comment || '').trim().slice(0, 200),
      },
      actor: { role: reviewerRole, id: String(reviewerId) },
    }).catch(() => {});

    res.status(201).json({ review: sanitizeDoc(review) });
  } catch (error) {
    console.error('Create review error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid id provided.' });
    }
    res.status(500).json({ error: 'Unable to save review. Please try again later.' });
  }
};

const listReviews = async (req, res) => {
  try {
    const {
      reviewerId,
      reviewerRole = 'owner',
      revieweeId,
      revieweeRole,
    } = req.query || {};

    if (!reviewerId && !revieweeId) {
      return res.status(400).json({ error: 'reviewerId or revieweeId is required.' });
    }

    const filter = {};

    let reviewerModelName;
    if (reviewerId) {
      if (!mongoose.Types.ObjectId.isValid(reviewerId)) {
        return res.status(400).json({ error: 'Valid reviewerId is required.' });
      }
      reviewerModelName = ROLE_TO_MODEL[reviewerRole];
      if (!reviewerModelName) {
        return res.status(400).json({ error: 'Invalid reviewerRole provided.' });
      }
      filter.reviewerId = reviewerId;
      filter.reviewerModel = reviewerModelName;
    }

    let revieweeModelName;
    if (revieweeId) {
      if (!mongoose.Types.ObjectId.isValid(revieweeId)) {
        return res.status(400).json({ error: 'Valid revieweeId is required.' });
      }
      const effectiveRevieweeRole = revieweeRole || 'sitter';
      revieweeModelName = ROLE_TO_MODEL[effectiveRevieweeRole];
      if (!revieweeModelName) {
        return res.status(400).json({ error: 'Invalid revieweeRole provided.' });
      }
      filter.revieweeId = revieweeId;
      filter.revieweeModel = revieweeModelName;
    } else if (revieweeRole) {
      revieweeModelName = ROLE_TO_MODEL[revieweeRole];
      if (!revieweeModelName) {
        return res.status(400).json({ error: 'Invalid revieweeRole provided.' });
      }
      filter.revieweeModel = revieweeModelName;
    } else if (reviewerModelName === ROLE_TO_MODEL.owner) {
      filter.revieweeModel = ROLE_TO_MODEL.sitter;
    }

    const reviews = await Review.find(filter)
      .sort({ createdAt: -1 })
      .populate('revieweeId')
      .populate('reviewerId');

    res.json({ reviews: reviews.map(sanitizeReview) });
  } catch (error) {
    console.error('List reviews error', error);
    res.status(500).json({ error: 'Unable to fetch reviews. Please try again later.' });
  }
};

module.exports = {
  createReview,
  listReviews,
};

