const Booking = require('../models/Booking');
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Review = require('../models/Review');
const OwnerCredit = require('../models/OwnerCredit');
const { sendNotification } = require('./notificationSender');

const getOwnerStats = async (ownerId) => {
  const completedBookingsCount = await Booking.countDocuments({
    ownerId,
    status: 'completed',
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

  // Sprint 7 step 2 — also recompute sitter Top status.
  if (booking.sitterId) {
    recomputeSitterStatus(booking.sitterId).catch(() => {});
  }

  const count = await Booking.countDocuments({ ownerId, status: 'completed' });

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
    { ownerId, used: false, type: 'loyalty_3rd' },
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
 * Recompute Sitter.isTopSitter + completedServicesCount + averageRating.
 * Fires TOP_SITTER_ACHIEVED when the sitter crosses the threshold.
 */
const recomputeSitterStatus = async (sitterId) => {
  if (!sitterId) return null;
  const [count, agg] = await Promise.all([
    Booking.countDocuments({ sitterId, status: 'completed' }),
    Review.aggregate([
      { $match: { revieweeId: require('mongoose').Types.ObjectId.createFromHexString(String(sitterId)) } },
      { $group: { _id: null, avg: { $avg: '$rating' }, n: { $sum: 1 } } },
    ]).catch(() => []),
  ]);
  const avgRating = (agg && agg[0]?.avg) ? Number(agg[0].avg.toFixed(2)) : 0;
  const shouldBeTop = count >= 20 && avgRating > 4.5;
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

module.exports = { getOwnerStats, onBookingCompleted, consumeLoyaltyDiscount, recomputeSitterStatus };
