const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Referral = require('../models/Referral');
const OwnerCredit = require('../models/OwnerCredit');
const Booking = require('../models/Booking');
const { generateUniqueReferralCode } = require('../utils/referralCode');
const { sendNotification } = require('./notificationSender');

const ensureReferralCode = async (role, userId) => {
  const Model = role === 'sitter' ? Sitter : Owner;
  const user = await Model.findById(userId).select('referralCode');
  if (!user) return null;
  if (user.referralCode) return user.referralCode;
  const code = await generateUniqueReferralCode({ Owner, Sitter });
  await Model.updateOne({ _id: userId }, { $set: { referralCode: code } });
  return code;
};

const findReferrerByCode = async (code) => {
  if (!code) return null;
  const upper = String(code).toUpperCase().trim();
  const owner = await Owner.findOne({ referralCode: upper }).select('_id').lean();
  if (owner) return { id: owner._id, role: 'owner' };
  const sitter = await Sitter.findOne({ referralCode: upper }).select('_id').lean();
  if (sitter) return { id: sitter._id, role: 'sitter' };
  return null;
};

/**
 * Record a pending referral from signup. Returns the Referral doc or null.
 */
const createPendingReferral = async ({ referralCode, referredUserId, referredRole }) => {
  const referrer = await findReferrerByCode(referralCode);
  if (!referrer) return null;
  // Self-referral not allowed.
  if (String(referrer.id) === String(referredUserId)) return null;
  try {
    return await Referral.create({
      referrerId: referrer.id,
      referrerRole: referrer.role,
      referredUserId,
      referredRole,
      status: 'pending',
      creditAwarded: false,
    });
  } catch (_) {
    // Duplicate (unique index) → ignore.
    return null;
  }
};

/**
 * Called from loyaltyService.onBookingCompleted: if this is the referred user's
 * FIRST completed booking, flip pending referral → completed and grant credit.
 */
const onReferredFirstBookingCompleted = async ({ bookingId, userId, role }) => {
  // Count completed bookings for this user; act only on the first.
  const field = role === 'sitter' ? 'sitterId' : 'ownerId';
  const completedCount = await Booking.countDocuments({ [field]: userId, status: 'completed' });
  if (completedCount !== 1) return;
  const referral = await Referral.findOne({
    referredUserId: userId,
    status: 'pending',
  });
  if (!referral) return;
  referral.status = 'completed';
  referral.completedAt = new Date();
  // Only owners receive the 5€ credit (it's an OwnerCredit).
  if (referral.referrerRole === 'owner') {
    await OwnerCredit.create({
      ownerId: referral.referrerId,
      type: 'referral_5eur',
      amount: 5,
      currency: 'EUR',
    });
    referral.creditAwarded = true;
  }
  await referral.save();

  // Notify the referrer.
  sendNotification({
    userId: String(referral.referrerId),
    role: referral.referrerRole,
    type: 'REFERRAL_CREDITED',
    data: {
      referredUserId: String(userId),
      amount: 5,
      currency: 'EUR',
    },
  }).catch(() => {});
};

const getMyReferrals = async (ownerOrSitterId, role) => {
  const code = await ensureReferralCode(role, ownerOrSitterId);
  const referrals = await Referral.find({ referrerId: ownerOrSitterId })
    .sort({ createdAt: -1 })
    .lean();
  const credits = await OwnerCredit.find({
    ownerId: ownerOrSitterId,
    type: 'referral_5eur',
  }).lean();
  const totalCredits = credits.reduce((s, c) => s + (c.amount || 0), 0);
  return { code, referrals, totalCredits };
};

module.exports = {
  ensureReferralCode,
  findReferrerByCode,
  createPendingReferral,
  onReferredFirstBookingCompleted,
  getMyReferrals,
};
