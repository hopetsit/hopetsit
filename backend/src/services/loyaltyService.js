const Booking = require('../models/Booking');
const Owner = require('../models/Owner');
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

module.exports = { getOwnerStats, onBookingCompleted, consumeLoyaltyDiscount };
