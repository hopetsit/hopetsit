const mongoose = require('mongoose');

const Review = require('../models/Review');
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const { sanitizeDoc, sanitizeReview } = require('../utils/sanitize');
const { sendNotification } = require('../services/notificationSender');
const { recomputeSitterStatus, recomputeWalkerStatus } = require('../services/loyaltyService');
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
        // v23.1.319 — Daniel : auto-modération (gros mots/menaces) sur l'avis.
        comment: require('../services/textModerationService')
          .moderateText(String(comment || '').trim().slice(0, 500)).clean,
        bookingId: booking._id,
      });
    } catch (e) {
      if (e.code === 11000) {
        return res.status(409).json({ error: 'You have already reviewed this booking.' });
      }
      throw e;
    }

    // v23.1.290 — Daniel : l'owner peut noter sitter OU walker. Les 2 modèles
    // ont rating + reviewsCount (+ averageRating). Avant, la moyenne n'était
    // recalculée que pour les sitters → la note walker restait à 0.
    if (revieweeRole === 'sitter' || revieweeRole === 'walker') {
      const previousTotal = (reviewee.rating || 0) * (reviewee.reviewsCount || 0);
      const newReviewsCount = (reviewee.reviewsCount || 0) + 1;
      const newAverage = (previousTotal + numericRating) / newReviewsCount;
      reviewee.rating = Number(newAverage.toFixed(2));
      reviewee.reviewsCount = newReviewsCount;
      if (reviewee.averageRating !== undefined) reviewee.averageRating = reviewee.rating;
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
    const userId = String(req.user?.id || '');
    const review = await Review.findById(id).select(
      'reportedCount reportedBy hidden comment rating'
    );
    if (!review) return res.status(404).json({ error: 'Review not found.' });
    // v23.1.295 — Daniel : "un signalement une fois, pas 15". Un même
    // utilisateur ne peut signaler cet avis qu'une seule fois (idempotent).
    if (userId && (review.reportedBy || []).map(String).includes(userId)) {
      return res.json({
        ok: true,
        alreadyReported: true,
        reportedCount: review.reportedCount,
      });
    }
    if (userId) review.reportedBy = [...(review.reportedBy || []), userId];
    review.reportedCount = (review.reportedCount || 0) + 1;
    await review.save();
    // v23.1.295 — l'admin n'est alerté qu'au 1er signalement (plus de spam).
    // La suite reste visible dans l'admin (onglet Signalés) via reportedCount.
    if (!review.hidden && review.reportedCount === 1) {
      try {
        const { sendEmail } = require('../services/emailService');
        const to = process.env.ADMIN_ALERT_EMAIL;
        if (to) {
          const snippet = String(review.comment || '(aucun texte)').slice(0, 300);
          sendEmail(
            to,
            `[HopeTSIT] Avis signalé (${review.reportedCount}) — #${id}`,
            `Un avis a été signalé (${review.reportedCount} signalement(s)).\n\n` +
              `Note : ${review.rating || 0}/5\n` +
              `Commentaire : "${snippet}"\n\n` +
              `Ouvre le dashboard admin → onglet Avis → Signalés pour le masquer ou le supprimer.`
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

// v23.1.290 — résolution d'un modèle par son NOM (Owner/Sitter/Walker), utile
// pour le recompute qui travaille avec revieweeModel (un nom, pas un rôle).
const getModelByName = (name) => {
  if (name === 'Owner') return Owner;
  if (name === 'Sitter') return Sitter;
  if (name === 'Walker') return Walker;
  return null;
};

// v23.1.290 — recalcule la moyenne d'un prestataire DEPUIS ZÉRO à partir de tous
// ses avis non masqués. La moyenne mobile de createReview ne sait pas retirer/
// ajuster une note lors d'un edit/delete, donc edit & delete passent par ici.
const recomputeRevieweeRating = async (revieweeId, modelName) => {
  const Model = getModelByName(modelName);
  if (!Model || modelName === 'Owner') return;
  const agg = await Review.aggregate([
    {
      $match: {
        revieweeId: new mongoose.Types.ObjectId(String(revieweeId)),
        revieweeModel: modelName,
        hidden: { $ne: true },
      },
    },
    { $group: { _id: null, avg: { $avg: '$rating' }, count: { $sum: 1 } } },
  ]);
  const avg = agg.length ? Number((agg[0].avg || 0).toFixed(2)) : 0;
  const count = agg.length ? agg[0].count : 0;
  const r = await Model.findById(revieweeId);
  if (!r) return;
  r.rating = avg;
  r.reviewsCount = count;
  if (r.averageRating !== undefined) r.averageRating = avg;
  await r.save();
  // v23.1.317 — Daniel : "Top Walker pas à jour". AVANT, seul le Sitter était
  // recalculé sur edit/delete d'avis → le flag isTopWalker restait périmé. On
  // recalcule aussi le Walker.
  if (modelName === 'Sitter') recomputeSitterStatus(revieweeId).catch(() => {});
  if (modelName === 'Walker') recomputeWalkerStatus(revieweeId).catch(() => {});
};

// GET /reviews/mine?bookingId=...  → l'avis de l'utilisateur connecté pour ce
// booking (ou null). Sert à savoir si on est en mode création ou édition.
const getMyReview = async (req, res) => {
  try {
    const reviewerId = req.user?.id;
    if (!reviewerId || !mongoose.Types.ObjectId.isValid(reviewerId)) {
      return res.status(401).json({ error: 'Authentication required.' });
    }
    const { bookingId } = req.query;
    const q = { reviewerId };
    if (bookingId && mongoose.Types.ObjectId.isValid(bookingId)) {
      q.bookingId = bookingId;
    }
    const review = await Review.findOne(q).sort({ createdAt: -1 }).lean();
    return res.json({ review: review ? sanitizeDoc(review) : null });
  } catch (e) {
    logger.error('getMyReview error', e);
    return res.status(500).json({ error: 'Unable to load your review.' });
  }
};

// PUT /reviews/:id  → seul l'auteur peut modifier rating/comment, puis recompute.
const updateReview = async (req, res) => {
  try {
    const userId = req.user?.id;
    const { id } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ error: 'Invalid review id.' });
    }
    const review = await Review.findById(id);
    if (!review) return res.status(404).json({ error: 'Review not found.' });
    if (String(review.reviewerId) !== String(userId)) {
      return res.status(403).json({ error: 'You can only edit your own review.' });
    }
    const { rating, comment } = req.body || {};
    if (rating !== undefined) {
      const numericRating = Number(rating);
      if (!Number.isFinite(numericRating) || numericRating < 1 || numericRating > 5) {
        return res.status(400).json({ error: 'Rating must be between 1 and 5.' });
      }
      review.rating = numericRating;
    }
    if (comment !== undefined) {
      review.comment = String(comment || '').trim().slice(0, 500);
    }
    await review.save();
    await recomputeRevieweeRating(review.revieweeId, review.revieweeModel);
    return res.json({ review: sanitizeDoc(review) });
  } catch (e) {
    logger.error('updateReview error', e);
    return res.status(500).json({ error: 'Unable to update review.' });
  }
};

// DELETE /reviews/:id  → seul l'auteur, puis recompute la moyenne.
const deleteReview = async (req, res) => {
  try {
    const userId = req.user?.id;
    const { id } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ error: 'Invalid review id.' });
    }
    const review = await Review.findById(id);
    if (!review) return res.status(404).json({ error: 'Review not found.' });
    if (String(review.reviewerId) !== String(userId)) {
      return res.status(403).json({ error: 'You can only delete your own review.' });
    }
    const revieweeId = review.revieweeId;
    const revieweeModel = review.revieweeModel;
    await review.deleteOne();
    await recomputeRevieweeRating(revieweeId, revieweeModel);
    return res.json({ ok: true });
  } catch (e) {
    logger.error('deleteReview error', e);
    return res.status(500).json({ error: 'Unable to delete review.' });
  }
};

module.exports = {
  createReview,
  listReviews,
  replyToReview,
  reportReview,
  getMyReview,
  updateReview,
  deleteReview,
};

