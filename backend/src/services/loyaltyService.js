const Booking = require('../models/Booking');
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const Review = require('../models/Review');
const OwnerCredit = require('../models/OwnerCredit');
const { sendNotification } = require('./notificationSender');
const logger = require('../utils/logger');

const getOwnerStats = async (ownerId) => {
  // v23.1.271 — Daniel : "top owner/sitter/walker reste à 0". On compte aussi
  // les services CONFIRMÉS (nouveau flux de confirmation owner) en plus des
  // bookings marqués 'completed' (ancien flux). Sinon le compteur ne bouge
  // jamais car le flux de confirmation ne posait pas status='completed'.
  const completedBookingsCount = await Booking.countDocuments({
    ownerId,
    $or: [{ status: 'completed' }, { confirmationStatus: 'confirmed' }],
  });
  const credits = await OwnerCredit.find({ ownerId, used: false }).lean();
  const availableCreditsTotal = credits.reduce((s, c) => s + (c.amount || 0), 0);
  const hasDiscountAvailable = credits.some((c) => c.type === 'loyalty_3rd');
  return {
    completedBookingsCount,
    isPremium: completedBookingsCount >= 10,
    hasDiscountAvailable,
    availableCreditsTotal,
    credits,
  };
};

/**
 * Handle the "booking completed" event for loyalty purposes.
 * - Every 3rd completed booking → create a -10% discount credit.
 * - On 10th completed booking → promote to Premium + notification.
 */
const onBookingCompleted = async (booking) => {
  const ownerId = booking.ownerId;
  if (!ownerId) return;

  // Sprint 7 step 7 — notify both parties that the booking is completed.
  const data = { bookingId: booking._id.toString() };
  Promise.allSettled([
    sendNotification({ userId: String(ownerId), role: 'owner', type: 'BOOKING_COMPLETED', data }),
    booking.sitterId
      ? sendNotification({ userId: String(booking.sitterId), role: 'sitter', type: 'BOOKING_COMPLETED', data })
      : Promise.resolve(),
  ]).catch(() => {});

  // Sprint 7 step 2 — also recompute sitter Top status.
  if (booking.sitterId) {
    recomputeSitterStatus(booking.sitterId).catch(() => {});
  }
  // v20 — same for walker if the booking is a walk (walkerId set).
  if (booking.walkerId) {
    recomputeWalkerStatus(booking.walkerId).catch(() => {});
  }

  // Sprint 7 step 3 — referral credit on referred user's 1st completed booking.
  try {
    const { onReferredFirstBookingCompleted } = require('./referralService');
    await onReferredFirstBookingCompleted({
      bookingId: booking._id,
      userId: ownerId,
      role: 'owner',
    });
  } catch (e) {
    logger.warn('referral hook failed', e.message);
  }

  const count = await Booking.countDocuments({
    ownerId,
    $or: [{ status: 'completed' }, { confirmationStatus: 'confirmed' }],
  });

  // Every 3rd completed booking: grant a 10% discount credit on next booking.
  if (count > 0 && count % 3 === 0) {
    const baseAmount = Number(booking.pricing?.totalPrice || 0);
    const discountAmount = Math.round(baseAmount * 0.1 * 100) / 100;
    if (discountAmount > 0) {
      await OwnerCredit.create({
        ownerId,
        type: 'loyalty_3rd',
        amount: discountAmount,
        currency: booking.pricing?.currency || 'EUR',
      });
    }
  }

  // 10th completed booking: Premium achievement.
  if (count === 10) {
    await Owner.findByIdAndUpdate(ownerId, { isPremium: true });
    sendNotification({
      userId: String(ownerId),
      role: 'owner',
      type: 'PREMIUM_ACHIEVED',
      data: { count },
    }).catch(() => {});
  }

  return { count, isPremiumNow: count >= 10 };
};

/**
 * Try to consume one loyalty_3rd credit for a booking.
 * Returns { applied: bool, discountAmount, creditId }.
 */
const consumeLoyaltyDiscount = async (ownerId, bookingId) => {
  const credit = await OwnerCredit.findOneAndUpdate(
    // v23.1.317 — Daniel (audit) : le crédit de parrainage (referral_5eur) était
    // affiché dans le solde mais JAMAIS dépensable (filtre loyalty_3rd seul). On
    // l'inclut : c'est aussi un montant fixe en euros, même mécanisme de déduction.
    { ownerId, used: false, type: { $in: ['loyalty_3rd', 'referral_5eur'] } },
    { used: true, usedAt: new Date(), usedOnBookingId: bookingId },
    { new: true, sort: { createdAt: 1 } }
  );
  if (!credit) return { applied: false };
  return {
    applied: true,
    discountAmount: credit.amount,
    creditId: credit._id,
  };
};

/**
 * v23.1.317 — Daniel (audit) : un crédit consommé (marqué used:true à la création
 * du PaymentIntent) n'était JAMAIS restitué si le paiement échouait/était annulé
 * → l'owner perdait sa réduction définitivement. Ce helper remet le crédit
 * disponible (used:false) pour un booking dont le paiement n'a pas abouti.
 * Idempotent : ne touche que les crédits effectivement liés à ce booking.
 */
const restoreLoyaltyDiscount = async (bookingId) => {
  if (!bookingId) return { restored: 0 };
  const res = await OwnerCredit.updateMany(
    { usedOnBookingId: bookingId, used: true },
    { $set: { used: false }, $unset: { usedAt: '', usedOnBookingId: '' } }
  );
  return { restored: res.modifiedCount || 0 };
};

/**
 * Recompute Sitter.isTopSitter + completedServicesCount + averageRating.
 * Fires TOP_SITTER_ACHIEVED when the sitter crosses the threshold.
 */
const recomputeSitterStatus = async (sitterId) => {
  if (!sitterId) return null;
  const [count, agg] = await Promise.all([
    Booking.countDocuments({
      sitterId,
      $or: [{ status: 'completed' }, { confirmationStatus: 'confirmed' }],
    }),
    Review.aggregate([
      // v23.1.317 — Daniel : "Top affiche 19 prestations + 0 étoile". CAUSE : le
      // $match ne filtrait QUE revieweeId, sans revieweeModel ni hidden → la
      // moyenne pouvait être faussée/0 (mélange Sitter/Walker même _id improbable,
      // mais surtout incohérent avec recomputeRevieweeRating). On aligne.
      { $match: {
        revieweeId: require('mongoose').Types.ObjectId.createFromHexString(String(sitterId)),
        revieweeModel: 'Sitter',
        hidden: { $ne: true },
      } },
      { $group: { _id: null, avg: { $avg: '$rating' }, n: { $sum: 1 } } },
    ]).catch(() => []),
  ]);
  const avgRating = (agg && agg[0]?.avg) ? Number(agg[0].avg.toFixed(2)) : 0;
  // v23.1.317 — Daniel : "note minimum de 4.5" → >= 4.5 (inclus), pas > 4.5.
  const shouldBeTop = count >= 20 && avgRating >= 4.5;
  const sitter = await Sitter.findById(sitterId).select('isTopSitter').lean();
  if (!sitter) return null;
  const wasTop = sitter.isTopSitter === true;
  await Sitter.updateOne(
    { _id: sitterId },
    {
      $set: {
        isTopSitter: shouldBeTop,
        completedServicesCount: count,
        averageRating: avgRating,
      },
    }
  );
  if (!wasTop && shouldBeTop) {
    sendNotification({
      userId: String(sitterId),
      role: 'sitter',
      type: 'TOP_SITTER_ACHIEVED',
      data: { count, avgRating },
    }).catch(() => {});
  }
  return { count, avgRating, isTopSitter: shouldBeTop };
};


/**
 * v20 — Recompute Walker.isTopWalker + completedServicesCount + averageRating.
 * Fires TOP_SITTER_ACHIEVED (reused key) when the walker crosses the threshold
 * (20 completed walks + avg rating > 4.5). Same bar as Top Sitter for parity.
 */
const recomputeWalkerStatus = async (walkerId) => {
  if (!walkerId) return null;
  const [count, agg] = await Promise.all([
    Booking.countDocuments({
      walkerId,
      $or: [{ status: 'completed' }, { confirmationStatus: 'confirmed' }],
    }),
    Review.aggregate([
      // v23.1.317 — même fix que sitter : filtre revieweeModel + hidden.
      { $match: {
        revieweeId: require('mongoose').Types.ObjectId.createFromHexString(String(walkerId)),
        revieweeModel: 'Walker',
        hidden: { $ne: true },
      } },
      { $group: { _id: null, avg: { $avg: '$rating' }, n: { $sum: 1 } } },
    ]).catch(() => []),
  ]);
  const avgRating = (agg && agg[0]?.avg) ? Number(agg[0].avg.toFixed(2)) : 0;
  // v23.1.317 — Daniel : "note minimum de 4.5" → >= 4.5 (inclus), pas > 4.5.
  const shouldBeTop = count >= 20 && avgRating >= 4.5;
  const walker = await Walker.findById(walkerId).select('isTopWalker').lean();
  if (!walker) return null;
  const wasTop = walker.isTopWalker === true;
  await Walker.updateOne(
    { _id: walkerId },
    {
      $set: {
        isTopWalker: shouldBeTop,
        completedWalksCount: count,
        averageRating: avgRating,
      },
    }
  );
  if (!wasTop && shouldBeTop) {
    sendNotification({
      userId: String(walkerId),
      role: 'walker',
      type: 'TOP_SITTER_ACHIEVED',
      data: { count, avgRating },
    }).catch(() => {});
  }
  return { count, avgRating, isTopWalker: shouldBeTop };
};

module.exports = { getOwnerStats, onBookingCompleted, consumeLoyaltyDiscount, restoreLoyaltyDiscount, recomputeSitterStatus, recomputeWalkerStatus };
