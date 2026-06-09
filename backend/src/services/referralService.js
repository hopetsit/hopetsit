const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const Referral = require('../models/Referral');
const OwnerCredit = require('../models/OwnerCredit');
const Booking = require('../models/Booking');
const { generateUniqueReferralCode } = require('../utils/referralCode');
const { sendNotification } = require('./notificationSender');

// Session avril 2026 — walker role added alongside owner/sitter.
const resolveReferralModel = (role) => {
  if (role === 'sitter') return Sitter;
  if (role === 'walker') return Walker;
  return Owner;
};

const ensureReferralCode = async (role, userId) => {
  const Model = resolveReferralModel(role);
  const user = await Model.findById(userId).select('referralCode');
  if (!user) return null;
  if (user.referralCode) return user.referralCode;
  const code = await generateUniqueReferralCode({ Owner, Sitter, Walker });
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
  const walker = await Walker.findOne({ referralCode: upper }).select('_id').lean();
  if (walker) return { id: walker._id, role: 'walker' };
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
  // v23.1.317 — Daniel : "vérifie les parrainages". BUG BLOQUANT : on comptait
  // uniquement status:'completed', or le flux de confirmation owner ne pose PAS
  // status='completed' (il pose confirmationStatus='confirmed'). Résultat : le
  // crédit de parrainage n'était JAMAIS accordé pour la majorité des cas. On
  // aligne sur le même $or que loyaltyService/owner stats.
  const field = role === 'sitter' ? 'sitterId' : 'ownerId';
  const completedCount = await Booking.countDocuments({
    [field]: userId,
    $or: [{ status: 'completed' }, { confirmationStatus: 'confirmed' }],
  });
  if (completedCount !== 1) return;
  const referral = await Referral.findOne({
    referredUserId: userId,
    status: 'pending',
  });
  if (!referral) return;
  referral.status = 'completed';
  referral.completedAt = new Date();
  // v23.1.332 — Daniel : NOUVELLE récompense de parrainage = -10% sur un plan
  // PawFollow ou PawFamily (PLUS de crédit 5€), valable pour les 3 rôles
  // (owner/sitter/walker). On marque la récompense "gagnée" (creditAwarded=true) ;
  // elle sera appliquée AUTOMATIQUEMENT au prochain achat d'abonnement
  // PawFollow/PawFamily (cf subscriptionRoutes /subscribe) puis marquée
  // rewardConsumed=true. (On ne crée plus d'OwnerCredit de 5€.)
  referral.creditAwarded = true;
  await referral.save();

  // Notify the referrer — réduction -10% disponible.
  sendNotification({
    userId: String(referral.referrerId),
    role: referral.referrerRole,
    type: 'REFERRAL_CREDITED',
    data: {
      referredUserId: String(userId),
      rewardType: 'sub_discount_10',
      percent: 10,
    },
  }).catch(() => {});
};

const getMyReferrals = async (ownerOrSitterId, role) => {
  const code = await ensureReferralCode(role, ownerOrSitterId);
  const referrals = await Referral.find({ referrerId: ownerOrSitterId })
    .sort({ createdAt: -1 })
    .lean();
  // v23.1.332 — récompense = -10% sur PawFollow/PawFamily. Le nombre de
  // réductions DISPONIBLES = parrainages complétés dont la récompense n'a pas
  // encore été consommée à un achat d'abonnement.
  const availableDiscounts = referrals.filter(
    (r) => r.status === 'completed' && r.creditAwarded && !r.rewardConsumed,
  ).length;
  return { code, referrals, availableDiscounts, discountPercent: 10 };
};

module.exports = {
  ensureReferralCode,
  findReferrerByCode,
  createPendingReferral,
  onReferredFirstBookingCompleted,
  getMyReferrals,
};
