const mongoose = require('mongoose');

const Review = require('../models/Review');
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const { sanitizeDoc, sanitizeReview } = require('../utils/sanitize');
const { sendNotification } = require('../services/notificationSender');
const { recomputeSitterStatus } = require('../services/loyaltyService');
const logger = require('../utils/logger');

// v18.6 — walker support ajouté.
const ROLE_TO_MODEL = {
  owner: 'Owner',
  sitter: 'Sitter',
  walker: 'Walker',
};

const getModelByRole = (role) => {
  const modelName = ROLE_TO_MODEL[role];
  if (!modelName) return null;
  if (modelName === 'Owner') return Owner;
  if (modelName === 'Sitter') return Sitter;
  if (modelName === 'Walker') return Walker;
  return null;
};

const createReview = async (req, res) => {
  try {
    // Sprint 7 step 4 — mutual reviews: role determined by JWT, opposite role is the reviewee.
    // v18.6 : le client peut (et devrait) envoyer revieweeRole pour qu'on sache si
    // c'est un sitter ou un walker. Fallback : on infère à partir de bookingId
    // (provider = sitterId ou walkerId).
    const reviewerId = req.user.id;
    const reviewerRole = req.user.role;

    const { revieweeId, rating, comment = '', bookingId } = req.body || {};
    let revieweeRole = (req.body?.revieweeRole || '').toString().toLowerCase();
    if (!revieweeRole) {
      // Fallback heuristique : owner → sitter par défaut (legacy).
      revieweeRole = reviewerRole === 'owner' ? 'sitter' : 'owner';
    }

    if (!reviewerId || !mongoose.Types.ObjectId.isValid(reviewerId)) {
      return res.status(400).json({ error: 'Valid reviewerId is required.' });
    }
    if (!revieweeId || !mongoose.Types.ObjectId.isValid(revieweeId)) {
      return res.status(400).json({ error: 'Valid revieweeId is required.' });
    }
    if (!ROLE_TO_MODEL[reviewerRole] || !ROLE_TO_MODEL[revieweeRole]) {
      return res.status(400).json({ error: 'Invalid roles provided.' });
    }
    if (String(reviewerId) === String(revieweeId) && reviewerRole === revieweeRole) {
      return res.status(400).json({ error: 'You cannot review yourself.' });
    }

    const numericRating = Number(rating);
    if (!Number.isFinite(numericRating) || numericRating < 1 || numericRating > 5) {
      return res.status(400).json({ error: 'Rating must be between 1 and 5.' });
    }

    const reviewerModel = getModelByRole(reviewerRole);
    const revieweeModel = getModelByRole(revieweeRole);

    const reviewerExists = await reviewerModel.exists({ _id: reviewerId });
    if (!reviewerExists) {
      return res.status(404).json({ error: 'Reviewer not found.' });
    }

    const reviewee = await revieweeModel.findById(revieweeId);
    if (!reviewee) {
      return res.status(404).json({ error: 'Reviewee not found.' });
    }

    // v18.6 — exiger une booking soit 'completed' soit 'paid' (owner review
    // juste après paiement avant que le service soit marqué complete).
    // Walker support : si revieweeRole='walker', on filter sur walkerId.
    const Booking = require('../models/Booking');
    const query = { status: { $in: ['completed', 'paid'] } };
    if (reviewerRole === 'owner') {
      query.ownerId = reviewerId;
      if (revieweeRole === 'walker') {
        query.walkerId = revieweeId;
      } else {
        query.sitterId = revieweeId;
      }
    } else {
      // reviewer is sitter or walker reviewing owner
      query.ownerId = revieweeId;
      if (reviewerRole === 'walker') {
        query.walkerId = reviewerId;
      } else {
        query.sitterId = reviewerId;
      }
    }
    if (bookingId && mongoose.Types.ObjectId.isValid(bookingId)) {
      query._id = bookingId;
    }
    const booking = await Booking.findOne(query).select('_id').lean();
    if (!booking) {
      logger.warn(
        `[createReview] no booking found for reviewer=${reviewerRole}:${reviewerId} -> reviewee=${revieweeRole}:${revieweeId} bookingId=${bookingId}`,
      );
      return res.status(400).json({
        error: 'A completed booking between you and this user is required to leave a review.',
      });
    }

    // Enforce "one review per reviewer per booking".
    const alreadyReviewed = await Review.exists({
      bookingId: booking._id,
      reviewerId,
    });
    if (alreadyReviewed) {
      return res.status(409).json({ error: 'You have already reviewed this booking.' });
    }

    let review;
    try {
      review = await Review.create({
        reviewerId,
        reviewerModel: ROLE_TO_MODEL[reviewerRole],
        revieweeId,
        revieweeModel: ROLE_TO_MODEL[revieweeRole],
        rating: numericRating,
        comment: String(comment || '').trim().slice(0, 500),
        bookingId: booking._id,
      });
    } catch (e) {
      if (e.code === 11000) {
        return res.status(409).json({ error: 'You have already reviewed this booking.' });
      }
      throw e;
    }

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
    logger.error('Create review error', error);
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

    // Sprint 7 step 5 — hide moderated reviews from public listings.
    const filter = { hidden: { $ne: true } };

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
    logger.error('List reviews error', error);
    res.status(500).json({ error: 'Unable to fetch reviews. Please try again later.' });
  }
};

// Sprint 7 step 4 — reviewee can post ONE reply to a review.
const replyToReview = async (req, res) => {
  try {
    const { id } = req.params;
    const { body } = req.body || {};
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ error: 'Invalid review id.' });
    }
    const trimmed = String(body || '').trim();
    if (!trimmed) return res.status(400).json({ error: 'Reply body is required.' });
    const review = await Review.findById(id);
    if (!review) return res.status(404).json({ error: 'Review not found.' });
    if (String(review.revieweeId) !== req.user.id) {
      return res.status(403).json({ error: 'Only the reviewee can reply to this review.' });
    }
    if (review.reply && review.reply.repliedAt) {
      return res.status(409).json({ error: 'You have already replied to this review.' });
    }
    review.reply = { body: trimmed.slice(0, 500), repliedAt: new Date() };
    await review.save();
    res.json({ review: sanitizeDoc(review) });
  } catch (e) {
    logger.error('replyToReview error', e);
    res.status(500).json({ error: 'Unable to post reply.' });
  }
};

// Sprint 7 step 5 — user reports an inappropriate review; emails admin at 3+ reports.
const reportReview = async (req, res) => {
  try {
    const { id } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ error: 'Invalid review id.' });
    }
    const review = await Review.findByIdAndUpdate(
      id,
      { $inc: { reportedCount: 1 } },
      { new: true }
    ).select('reportedCount hidden');
    if (!review) return res.status(404).json({ error: 'Review not found.' });
    if (review.reportedCount >= 3 && !review.hidden) {
      try {
        const { sendEmail } = require('../services/emailService');
        const to = process.env.ADMIN_ALERT_EMAIL;
        if (to) {
          sendEmail(
            to,
            `[HopeTSIT] Review flagged (${review.reportedCount} reports) — #${id}`,
            `Review ${id} reached ${review.reportedCount} reports. Please review in the admin dashboard.`
          ).catch(() => {});
        }
      } catch (_) {}
    }
    res.json({ ok: true, reportedCount: review.reportedCount });
  } catch (e) {
    logger.error('reportReview error', e);
    res.status(500).json({ error: 'Unable to report review.' });
  }
};

module.exports = {
  createReview,
  listReviews,
  replyToReview,
  reportReview,
};

