const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const { decrypt } = require('../utils/encryption');
const Booking = require('../models/Booking');
const Application = require('../models/Application');
const Pet = require('../models/Pet');
const Review = require('../models/Review');
const { sanitizeBooking, sanitizeConversation } = require('../utils/sanitize');
const Conversation = require('../models/Conversation');
const { isOwnerSitterInteractionBlocked } = require('../services/blockService');
const {
  getRecommendedPriceRange,
  calculateTotalWithAddOns,
  SERVICE_TYPES,
  LOCATION_TYPES,
} = require('../utils/pricing');
const {
  createPaymentIntent,
  getPaymentIntent,
  confirmPaymentIntent,
  createRefund,
} = require('../services/stripeService');
const {
  createPaypalOrder,
  capturePaypalOrder,
  getPaypalOrder,
} = require('../services/paypalService');
const { sendPayoutToSitter } = require('../services/paypalPayoutService');
const { assertSupportedCurrency, DEFAULT_CURRENCY } = require('../utils/currency');
const { createNotificationSafe } = require('../services/notificationService');
const { mergeScheduleFromApplication, normalizeServiceType } = require('../utils/bookingAgreementFields');
const {
  buildRequestFingerprint,
  normalizeText,
  normalizeDate,
  normalizeNumber,
  normalizePetIds,
  normalizeAddOns,
} = require('../utils/requestFingerprint');
const { calculateTierBasePrice } = require('../utils/tierPricing');

const normalizeIncomingDateString = (value) => {
  if (value == null) return '';
  if (value instanceof Date) return value.toISOString();
  if (typeof value === 'string') return value.trim();
  return String(value).trim();
};

/**
 * @swagger
 * /bookings:
 *   post:
 *     summary: Create owner-to-sitter booking request (deduplicated)
 *     tags: [Bookings]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: sitterId
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [petIds, serviceDate, timeSlot, basePrice]
 *             properties:
 *               petIds:
 *                 type: array
 *                 items:
 *                   type: string
 *               serviceDate:
 *                 type: string
 *                 format: date-time
 *               startDate:
 *                 type: string
 *                 format: date-time
 *                 nullable: true
 *               endDate:
 *                 type: string
 *                 format: date-time
 *                 nullable: true
 *               timeSlot:
 *                 type: string
 *               serviceType:
 *                 nullable: true
 *                 oneOf: [{ type: string }, { type: number }, { type: boolean }, { type: object }]
 *               houseSittingVenue:
 *                 type: string
 *                 enum: [owners_home, sitters_home]
 *                 description: Required when serviceType is house_sitting
 *               duration:
 *                 type: number
 *               basePrice:
 *                 type: number
 *               addOns:
 *                 type: array
 *                 items:
 *                   type: object
 *               locationType:
 *                 type: string
 *                 enum: [standard, large_city]
 *               description:
 *                 type: string
 *     responses:
 *       201:
 *         description: Booking request created
 *       200:
 *         description: Duplicate-click prevented. Existing open booking returned.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 duplicatePrevented:
 *                   type: boolean
 *                   example: true
 *                 message:
 *                   type: string
 *                 booking:
 *                   $ref: '#/components/schemas/Booking'
 */
const createBooking = async (req, res) => {
  try {
    const ownerId = req.user?.id;
    const sitterIdQuery = req.query?.sitterId;
    const body = req.body || {};
    const {
      petIds, // Array of pet IDs
      description = '',
      serviceType,
      houseSittingVenue,
      duration,
      addOns = [],
      locationType,
    } = body;
    const serviceDateRaw =
      body.serviceDate ??
      body.date ??
      body.startDate ??
      body.start_date ??
      '';
    const startDateRaw =
      body.startDate ??
      body.start_date ??
      body.serviceDate ??
      body.date ??
      null;
    const endDateRaw =
      body.endDate ??
      body.end_date ??
      null;
    const timeSlotRaw =
      body.timeSlot ??
      body.startTime ??
      body.start_time ??
      body.time ??
      '';

    if (!ownerId) {
      return res.status(403).json({ error: 'Owner context missing.' });
    }

    const sitterId = typeof sitterIdQuery === 'string' ? sitterIdQuery.trim() : '';

    if (!sitterId) {
      return res.status(400).json({ error: 'sitterId query parameter is required.' });
    }

    // Validate petIds array
    if (!petIds || !Array.isArray(petIds) || petIds.length === 0) {
      return res.status(400).json({ error: 'petIds array is required and must contain at least one pet ID.' });
    }

    // Validate all pet IDs and ensure they belong to the owner
    const mongoose = require('mongoose');
    const validPetIds = [];
    
    for (const petId of petIds) {
      if (!mongoose.Types.ObjectId.isValid(petId)) {
        return res.status(400).json({ error: `Invalid petId format: ${petId}` });
      }
      
      const pet = await Pet.findOne({ _id: petId, ownerId: ownerId });
      if (!pet) {
        return res.status(404).json({ error: `Pet with ID ${petId} not found or does not belong to you.` });
      }
      
      validPetIds.push(pet._id);
    }
    
    // Remove duplicates
    const uniquePetIds = [...new Set(validPetIds.map(id => id.toString()))].map(id => new mongoose.Types.ObjectId(id));

    const trimmedDescription = typeof description === 'string' ? description.trim() : '';
    const trimmedTimeSlot = typeof timeSlotRaw === 'string' ? timeSlotRaw.trim() : String(timeSlotRaw || '').trim();
    const normalizedDate = normalizeIncomingDateString(serviceDateRaw);
    const normalizedStartDate = normalizeIncomingDateString(startDateRaw);
    const normalizedEndDate = normalizeIncomingDateString(endDateRaw);

    if (!normalizedDate) {
      return res.status(400).json({ error: 'serviceDate is required.' });
    }

    if (!trimmedTimeSlot) {
      return res.status(400).json({ error: 'timeSlot is required.' });
    }

    // Relaxed serviceType handling: accept any value from client.
    const canonicalServiceType = normalizeServiceType(serviceType);
    const normalizedHouseSittingVenue =
      typeof houseSittingVenue === 'string' ? houseSittingVenue.trim().toLowerCase() : '';
    const isHouseSittingType =
      typeof serviceType === 'string' &&
      ['house_sitting', 'house sitting'].includes(serviceType.trim().toLowerCase());
    if (isHouseSittingType) {
      if (!['owners_home', 'sitters_home'].includes(normalizedHouseSittingVenue)) {
        return res.status(400).json({
          error: 'houseSittingVenue is required for house_sitting and must be owners_home or sitters_home.',
        });
      }
    } else if (houseSittingVenue != null && normalizedHouseSittingVenue && !['owners_home', 'sitters_home'].includes(normalizedHouseSittingVenue)) {
      return res.status(400).json({
        error: 'houseSittingVenue must be owners_home or sitters_home when provided.',
      });
    }

    // Validate location type
    const validLocationType = locationType === LOCATION_TYPES.LARGE_CITY 
      ? LOCATION_TYPES.LARGE_CITY 
      : LOCATION_TYPES.STANDARD;

    // Validate duration for dog_walking
    let durationNum = null;
    if (canonicalServiceType === SERVICE_TYPES.DOG_WALKING) {
      if (!duration || (duration !== 30 && duration !== 60)) {
        return res.status(400).json({ error: 'duration is required for dog_walking. Valid values: 30 or 60 minutes.' });
      }
      durationNum = duration;
    }

    const owner = await Owner.findById(ownerId);
    if (!owner) {
      return res.status(404).json({ error: 'Owner not found.' });
    }

    // Determine booking currency from owner's preferred currency.
    // This enforces the rule: bookingCurrency = owner.currency.
    const bookingCurrency = assertSupportedCurrency(
      owner.currency || DEFAULT_CURRENCY,
      'Owner currency must be set to create a booking.'
    );

    const sitter = await Sitter.findById(sitterId);
    if (!sitter) {
      return res.status(404).json({ error: 'Sitter not found.' });
    }
    if (!sitter.hourlyRate || sitter.hourlyRate <= 0) {
      return res.status(400).json({
        error: 'Sitter must set hourlyRate before creating a payable booking request.',
      });
    }

    const isBlocked = await isOwnerSitterInteractionBlocked(ownerId, sitterId);
    if (isBlocked) {
      return res.status(403).json({ error: 'You cannot send requests to this sitter.' });
    }

    // Get recommended price range for reference (in booking currency)
    let recommendedRange = null;
    if (canonicalServiceType) {
      try {
        const recommended = getRecommendedPriceRange(
          canonicalServiceType,
          validLocationType,
          durationNum,
          bookingCurrency
        );
        recommendedRange = {
          min: recommended.min,
          max: recommended.max,
          currency: recommended.currency,
        };
      } catch (error) {
        console.error('Error getting recommended price range:', error);
      }
    }

    const tierPricing = calculateTierBasePrice({
      hourlyRate: sitter.hourlyRate,
      weeklyRate: sitter.weeklyRate,
      monthlyRate: sitter.monthlyRate,
      startDate: normalizedStartDate,
      endDate: normalizedEndDate,
      serviceDate: normalizedDate,
      durationMinutes: durationNum || duration,
    });

    // Calculate pricing breakdown with commission in booking currency
    const pricingBreakdown = calculateTotalWithAddOns(tierPricing.basePrice, addOns, bookingCurrency);

    const requestFingerprint = buildRequestFingerprint({
      ownerId,
      sitterId,
      petIds: normalizePetIds(uniquePetIds),
      serviceDate: normalizeDate(normalizedDate),
      startDate: normalizeDate(normalizedStartDate),
      endDate: normalizeDate(normalizedEndDate),
      timeSlot: normalizeText(trimmedTimeSlot),
      serviceType: serviceType == null ? null : String(serviceType),
      houseSittingVenue: normalizedHouseSittingVenue || null,
      duration: normalizeNumber(durationNum ?? duration),
      basePrice: normalizeNumber(tierPricing.basePrice),
      locationType: normalizeText(validLocationType),
      addOns: normalizeAddOns(addOns),
      description: normalizeText(trimmedDescription),
    });

    const duplicateOpenBooking = await Booking.findOne({
      ownerId,
      sitterId,
      status: { $in: ['pending', 'accepted', 'agreed'] },
      requestFingerprint,
    })
      .sort({ createdAt: -1 })
      .populate('ownerId')
      .populate('sitterId')
      .populate('petIds');

    if (duplicateOpenBooking) {
      return res.status(200).json({
        booking: sanitizeBooking(duplicateOpenBooking),
        duplicatePrevented: true,
        message: 'Identical open booking request already exists.',
      });
    }

    const booking = await Booking.create({
      ownerId,
      sitterId,
      petIds: uniquePetIds,
      description: trimmedDescription,
      date: normalizedDate,
      startDate: normalizedStartDate || null,
      endDate: normalizedEndDate || null,
      timeSlot: trimmedTimeSlot,
      serviceType,
      houseSittingVenue: normalizedHouseSittingVenue || null,
      requestFingerprint,
      duration: durationNum,
      locationType: validLocationType,
      pricing: {
        basePrice: pricingBreakdown.basePrice,
        pricingTier: tierPricing.pricingTier,
        appliedRate: tierPricing.appliedRate,
        totalHours: tierPricing.totalHours,
        totalDays: tierPricing.totalDays,
        addOns: pricingBreakdown.addOns || [],
        addOnsTotal: pricingBreakdown.addOnsTotal || 0,
        totalPrice: pricingBreakdown.totalPrice,
        commission: pricingBreakdown.commission,
        netPayout: pricingBreakdown.netPayout,
        commissionRate: pricingBreakdown.commissionRate,
        currency: pricingBreakdown.currency,
      },
      recommendedPriceRange: recommendedRange,
    });

    await booking.populate('ownerId');
    await booking.populate('sitterId');
    await booking.populate('petIds'); // Populate full pet details

    await createNotificationSafe({
      recipientRole: 'sitter',
      recipientId: sitterId,
      actorRole: 'owner',
      actorId: ownerId,
      type: 'booking_new',
      title: 'New booking request',
      body: trimmedDescription || 'You received a new booking request.',
      data: {
        bookingId: booking._id.toString(),
        ownerId: ownerId.toString(),
      },
    });

    res.status(201).json({ 
      booking: sanitizeBooking(booking), 
      message: 'Request sent successfully.',
      pricing: {
        totalPrice: pricingBreakdown.totalPrice,
        commission: pricingBreakdown.commission,
        netPayout: pricingBreakdown.netPayout,
        currency: pricingBreakdown.currency,
      },
    });
  } catch (error) {
    console.error('Create booking error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid owner or sitter id.' });
    }
    if (error.message && error.message.includes('must be')) {
      return res.status(400).json({ error: error.message });
    }
    if (error.message && (error.message.includes('hourlyRate') || error.message.includes('required for pricing'))) {
      return res.status(400).json({ error: error.message });
    }
    res.status(500).json({ error: 'Unable to send booking request. Please try again later.' });
  }
};

/**
 * Parse the booking start date (stored as a string) into a Date object.
 * The application stores dates as "YYYY-MM-DD" or ISO strings; we accept both.
 * Falls back to the booking creation date when the start date cannot be parsed.
 */
const resolveBookingStartDate = (booking) => {
  const raw = booking?.startDate || booking?.date || null;
  if (raw) {
    const parsed = new Date(raw);
    if (!Number.isNaN(parsed.getTime())) {
      // Force midnight local time so the payout is eligible during the whole day.
      parsed.setHours(0, 0, 0, 0);
      return parsed;
    }
  }
  return booking?.createdAt ? new Date(booking.createdAt) : new Date();
};

/**
 * Returns true when the booking start date is today or already in the past.
 * Used to decide whether the sitter payout should be released immediately
 * (same-day booking) or scheduled for the first day of the service.
 */
const isBookingPayoutDue = (booking) => {
  const start = resolveBookingStartDate(booking);
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  return start.getTime() <= today.getTime();
};

/**
 * Schedules or triggers the sitter payout for a booking that has just been paid.
 *
 * Business rule (HopeTSIT):
 *   The money stays in escrow until the first day of the pet sitting service.
 *   On that first day, `processScheduledSitterPayouts` (run by the scheduler)
 *   will call `processSitterPayoutForBooking` to actually release the funds.
 *
 * If the booking start date is today or already past (same-day booking,
 * admin retry, legacy data), the payout is released immediately.
 */
const schedulePayoutForBooking = async (booking) => {
  if (!booking) return;
  if (booking.payoutStatus === 'completed' || booking.payoutStatus === 'processing') {
    return;
  }

  booking.scheduledPayoutAt = resolveBookingStartDate(booking);

  if (isBookingPayoutDue(booking)) {
    // First day of the pet sitting already reached → release now.
    await booking.save();
    await processSitterPayoutForBooking(booking);
    return;
  }

  booking.payoutStatus = 'scheduled';
  await booking.save();
  console.log(
    `🗓️  Payout scheduled for booking ${booking._id.toString()} on ${booking.scheduledPayoutAt.toISOString()}`
  );
};

/**
 * Internal helper to process sitter payout for a paid booking using PayPal Payouts.
 * This function is idempotent and will not trigger a second payout when payoutStatus is completed.
 *
 * @param {import('mongoose').Document} booking
 */
const processSitterPayoutForBooking = async (booking) => {
  try {
    if (!booking) {
      return;
    }

    // Ensure booking is in a valid state for payout
    if (booking.status !== 'paid' || booking.paymentStatus !== 'paid') {
      return;
    }

    if (booking.paymentProvider !== 'paypal') {
      // Only process payouts for PayPal-based payments
      return;
    }

    // Idempotency: never send payout twice
    if (booking.payoutStatus === 'completed') {
      console.log('ℹ️ Payout already completed for booking', booking._id.toString());
      return;
    }

    const netPayout = booking.pricing?.netPayout;
    const currency = booking.pricing?.currency;

    if (typeof netPayout !== 'number' || !Number.isFinite(netPayout) || netPayout <= 0) {
      console.warn('⚠️ Skipping payout due to invalid netPayout', {
        bookingId: booking._id.toString(),
        netPayout,
      });
      return;
    }

    const sitterId =
      booking.sitterId && booking.sitterId._id
        ? booking.sitterId._id
        : booking.sitterId;

    const sitter = await Sitter.findById(sitterId);
    if (!sitter) {
      console.error('❌ Unable to process payout: sitter not found for booking', booking._id.toString());
      booking.payoutStatus = 'failed';
      booking.payoutError = 'Sitter not found for payout.';
      await booking.save();
      return;
    }

    const sitterPaypalEmail = decrypt(sitter.paypalEmail || '').trim();
    if (!sitterPaypalEmail) {
      console.warn('⚠️ Skipping payout: sitter PayPal email missing', {
        bookingId: booking._id.toString(),
        sitterId: sitter._id.toString(),
      });
      booking.payoutStatus = 'failed';
      booking.payoutError = 'Sitter PayPal email is missing.';
      await booking.save();
      return;
    }

    // Mark as processing before calling external API
    booking.payoutStatus = 'processing';
    booking.sitterPaypalEmail = sitterPaypalEmail;
    await booking.save();

    const payoutResult = await sendPayoutToSitter({
      bookingId: booking._id.toString(),
      sitterEmail: sitterPaypalEmail,
      amount: netPayout,
      currency,
    });

    booking.payoutStatus = 'completed';
    booking.payoutBatchId = payoutResult.batchId;
    booking.payoutId = payoutResult.payoutItemId;
    booking.payoutAt = new Date();
    booking.payoutError = null;
    await booking.save();
  } catch (error) {
    console.error('❌ Error while processing sitter payout for booking', booking._id.toString(), error);
    booking.payoutStatus = 'failed';
    booking.payoutError = error.message || String(error);
    try {
      await booking.save();
    } catch (saveError) {
      console.error('❌ Failed to persist payout failure state for booking', booking._id.toString(), saveError);
    }
  }
};

const listBookings = async (req, res) => {
  try {
    // Check if this is a "my" endpoint request (user authenticated)
    const userId = req.user?.id;
    const userRole = req.user?.role;
    
    const { ownerId, sitterId, status } = req.query;
    const filter = {};
    
    // If user is authenticated (from /my endpoint), filter by their role
    if (userId && userRole) {
      if (userRole === 'owner') {
        filter.ownerId = userId;
      } else if (userRole === 'sitter') {
        filter.sitterId = userId;
      }
    } else {
      // For regular /bookings endpoint, use query parameters
      if (ownerId) {
        filter.ownerId = ownerId;
      }
      if (sitterId) {
        filter.sitterId = sitterId;
      }
    }
    
    if (status) {
      filter.status = status;
    } else {
      filter.status = { $ne: 'cancelled' };
    }

    const bookings = await Booking.find(filter)
      .sort({ createdAt: -1 })
      .populate('ownerId')
      .populate('sitterId')
      .populate('petIds');

    res.json({ bookings: bookings.map(sanitizeBooking) });
  } catch (error) {
    console.error('Fetch bookings error', error);
    res.status(500).json({ error: 'Unable to fetch bookings. Please try again later.' });
  }
};

/**
 * Get bookings history for authenticated user (token-based)
 * GET /bookings/my?status=all|pending|agreed|paid|payment_failed|cancelled|refunded
 */
const getMyBookings = async (req, res) => {
  try {
    const userId = req.user?.id;
    const userRole = req.user?.role;
    const { status } = req.query;

    if (!userId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (!userRole || !['owner', 'sitter'].includes(userRole)) {
      return res.status(400).json({ error: 'Invalid user role. Expected "owner" or "sitter".' });
    }

    // Build filter based on user role
    const filter = {};
    if (userRole === 'owner') {
      filter.ownerId = userId;
    } else {
      filter.sitterId = userId;
    }

    // Filter by status if provided
    if (status && status !== 'all') {
      // Map frontend status names to database statuses
      const statusMap = {
        pending: 'pending',
        agreed: 'agreed',
        paid: 'paid',
        failed: 'payment_failed',
        cancelled: 'cancelled',
        refunded: 'refunded',
      };
      
      if (statusMap[status]) {
        filter.status = statusMap[status];
      }
    }

    const bookings = await Booking.find(filter)
      .sort({ updatedAt: -1 })
      .populate('ownerId', 'name email avatar mobile address')
      .populate('sitterId', 'name email avatar mobile address location rating reviewsCount')
      .populate('petIds');

    // Format bookings for Bookings History screen
    const formattedBookings = await Promise.all(bookings.map(async (booking) => {
      const sanitized = sanitizeBooking(booking);
      const otherParty = userRole === 'owner' ? sanitized.sitter : sanitized.owner;
      const otherPartyRaw = userRole === 'owner' ? booking.sitterId : booking.ownerId;

      // Get phone number
      const phone = otherPartyRaw?.mobile || '';

      // Get location
      let location = '';
      if (userRole === 'owner' && otherPartyRaw?.location?.city) {
        // For sitter, use city from location object
        location = otherPartyRaw.location.city;
      } else if (userRole === 'sitter' && otherPartyRaw?.address) {
        // For owner, use address
        location = otherPartyRaw.address;
      }

      // Get rating
      let rating = 0;
      let reviewsCount = 0;
      
      if (userRole === 'owner') {
        // For sitter, use rating field directly
        rating = otherPartyRaw?.rating || 0;
        reviewsCount = otherPartyRaw?.reviewsCount || 0;
      } else {
        // For owner, calculate rating from Review model
        const ownerReviews = await Review.find({
          revieweeId: otherPartyRaw?._id,
          revieweeModel: 'Owner',
        });
        
        if (ownerReviews.length > 0) {
          const totalRating = ownerReviews.reduce((sum, review) => sum + review.rating, 0);
          rating = Number((totalRating / ownerReviews.length).toFixed(2));
          reviewsCount = ownerReviews.length;
        }
      }

      // Get pet details from petIds array (pets are already populated)
      const pets = Array.isArray(booking.petIds) ? booking.petIds : [];
      
      return {
        id: sanitized.id,
        status: sanitized.status,
        paymentStatus: booking.paymentStatus || 'pending', // Include payment status
        pets: pets.map(pet => {
          if (pet && typeof pet === 'object' && pet._id) {
            // Pet is populated, return full details
            return {
              id: pet._id.toString(),
              petName: pet.petName || '',
              breed: pet.breed || '',
              category: pet.category || '',
              weight: pet.weight || '',
              height: pet.height || '',
              colour: pet.colour || '',
              vaccination: pet.vaccination || '',
              medicationAllergies: pet.medicationAllergies || '',
              avatar: pet.avatar || { url: '', publicId: '' },
            };
          }
          return null;
        }).filter(pet => pet !== null), // Remove null entries
        petIds: pets.map(pet => {
          return pet?._id?.toString() || pet?.toString() || pet;
        }),
        description: booking.description,
        date: booking.date,
        timeSlot: booking.timeSlot,
        serviceType: booking.serviceType,
        houseSittingVenue: booking.houseSittingVenue || null,
        duration: booking.duration,
        otherParty: {
          id: otherParty?.id || '',
          name: otherParty?.name || '',
          email: otherParty?.email || '',
          avatar: otherParty?.avatar?.url || '',
          phone: phone,
          rating: rating,
          reviewsCount: reviewsCount,
          location: location,
        },
        pricing: {
          basePrice: sanitized.pricing?.basePrice || 0,
          pricingTier: sanitized.pricing?.pricingTier || 'hourly',
          appliedRate: sanitized.pricing?.appliedRate || 0,
          totalHours: sanitized.pricing?.totalHours || 0,
          totalDays: sanitized.pricing?.totalDays || 0,
          totalPrice: sanitized.pricing?.totalPrice || 0,
          platformFee: sanitized.pricing?.commission || 0,
          netPayout: sanitized.pricing?.netPayout || 0,
          currency: sanitized.pricing?.currency || DEFAULT_CURRENCY,
        },
        canPay: booking.status === 'agreed' && userRole === 'owner',
        canCancel: booking.status === 'paid' && booking.cancellation,
        cancellationStatus: booking.cancellation ? {
          ownerConfirmed: booking.cancellation.ownerConfirmed,
          sitterConfirmed: booking.cancellation.sitterConfirmed,
          bothConfirmed: booking.cancellation.ownerConfirmed && booking.cancellation.sitterConfirmed,
        } : null,
        createdAt: sanitized.createdAt,
        updatedAt: sanitized.updatedAt,
      };
    }));

    // Count bookings by status
    const statusCounts = {
      all: bookings.length,
      pending: bookings.filter(b => b.status === 'pending').length,
      agreed: bookings.filter(b => b.status === 'agreed').length,
      paid: bookings.filter(b => b.status === 'paid').length,
      failed: bookings.filter(b => b.status === 'payment_failed').length,
      cancelled: bookings.filter(b => b.status === 'cancelled').length,
      refunded: bookings.filter(b => b.status === 'refunded').length,
    };

    res.json({
      bookings: formattedBookings,
      statusCounts,
      count: formattedBookings.length,
    });
  } catch (error) {
    console.error('Get my bookings error', error);
    res.status(500).json({ error: 'Unable to fetch bookings. Please try again later.' });
  }
};

const cancelBooking = async (req, res) => {
  try {
    const ownerId = req.user?.id;
    const sitterIdQuery = req.query?.sitterId;
    const { id } = req.params;

    if (!ownerId) {
      return res.status(403).json({ error: 'Owner context missing.' });
    }

    const sitterId = typeof sitterIdQuery === 'string' ? sitterIdQuery.trim() : '';

    if (!sitterId) {
      return res.status(400).json({ error: 'sitterId query parameter is required.' });
    }

    const booking = await Booking.findById(id).populate('petIds');

    if (!booking) {
      return res.status(404).json({ error: 'Booking not found.' });
    }

    if (booking.ownerId.toString() !== ownerId || booking.sitterId.toString() !== sitterId) {
      return res.status(403).json({ error: 'You do not have permission to cancel this booking.' });
    }

    if (booking.status === 'cancelled') {
      return res.status(409).json({ error: 'Booking already cancelled.' });
    }

    booking.status = 'cancelled';
    booking.paymentStatus = 'cancelled'; // Update payment status
    await booking.save();
    await booking.populate('ownerId');
    await booking.populate('sitterId');

    res.json({ booking: sanitizeBooking(booking), message: 'Booking cancelled.' });
  } catch (error) {
    console.error('Cancel booking error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid booking id.' });
    }
    res.status(500).json({ error: 'Unable to cancel booking. Please try again later.' });
  }
};

/**
 * Self‑cancel a paid booking up to 72h before the service start date.
 *
 * Business rule:
 *   - Either the pet owner or the pet sitter can trigger this endpoint.
 *   - The booking must be `paid` (money already captured, held in escrow).
 *   - The booking start date must be strictly more than 72 hours in the future.
 *   - If all conditions are met, the booking is marked `cancelled` and a
 *     refund is issued to the owner (PayPal or Stripe, depending on provider).
 *   - If the start date is within the 72h window, the request is rejected
 *     so the parties must go through the mutual cancellation flow instead.
 */
const SEVENTY_TWO_HOURS_MS = 72 * 60 * 60 * 1000;

const selfCancelWithRefund = async (req, res) => {
  try {
    const userId = req.user?.id;
    const { id } = req.params;

    if (!userId) {
      return res.status(401).json({ error: 'Authentication required.' });
    }

    const booking = await Booking.findById(id)
      .populate('ownerId')
      .populate('sitterId')
      .populate('petIds');

    if (!booking) {
      return res.status(404).json({ error: 'Booking not found.' });
    }

    const bookingOwnerId = booking.ownerId?._id
      ? booking.ownerId._id.toString()
      : booking.ownerId?.toString();
    const bookingSitterId = booking.sitterId?._id
      ? booking.sitterId._id.toString()
      : booking.sitterId?.toString();

    const isOwner = bookingOwnerId === userId;
    const isSitter = bookingSitterId === userId;

    if (!isOwner && !isSitter) {
      return res
        .status(403)
        .json({ error: 'You do not have permission to cancel this booking.' });
    }

    if (booking.status !== 'paid') {
      return res.status(409).json({
        error: `Only paid bookings can be self‑cancelled (current status: ${booking.status}).`,
      });
    }

    const startDate = resolveBookingStartDate
      ? resolveBookingStartDate(booking)
      : booking.startDate || booking.startsAt || booking.serviceStartDate;
    if (!startDate) {
      return res
        .status(400)
        .json({ error: 'Booking start date is missing; cannot enforce 72h rule.' });
    }

    const msUntilStart = new Date(startDate).getTime() - Date.now();
    if (msUntilStart <= SEVENTY_TWO_HOURS_MS) {
      return res.status(409).json({
        error:
          'The 72‑hour free cancellation window has closed. Please use mutual cancellation.',
        hoursUntilStart: Math.max(0, Math.round(msUntilStart / 3600000)),
      });
    }

    // Mark cancelled + refund the pet owner (escrow release back).
    booking.status = 'cancelled';
    booking.paymentStatus = 'refunded';
    booking.cancellationReason =
      req.body?.reason || (isOwner ? 'owner_self_cancel_72h' : 'sitter_self_cancel_72h');
    booking.cancelledAt = new Date();
    booking.cancelledBy = isOwner ? 'owner' : 'sitter';

    // If a payout was scheduled, cancel it — money stays in escrow & will be refunded.
    if (booking.payoutStatus === 'scheduled') {
      booking.payoutStatus = 'cancelled';
      booking.scheduledPayoutAt = null;
    }

    await booking.save();

    // Best‑effort refund; refund provider helpers may or may not exist depending on build.
    try {
      if (typeof refundBookingPayment === 'function') {
        await refundBookingPayment(booking);
      }
    } catch (refundErr) {
      console.error('⚠️  Self-cancel refund failed', refundErr);
      // Do not fail the cancellation — the booking is marked and admin can retry.
    }

    return res.json({
      booking: sanitizeBooking(booking),
      message: 'Booking cancelled and refund initiated.',
    });
  } catch (error) {
    console.error('Self-cancel with refund error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid booking id.' });
    }
    return res
      .status(500)
      .json({ error: 'Unable to cancel booking. Please try again later.' });
  }
};

/**
 * Owner cancels a sent booking request (token-based, no sitterId query required).
 * Intended for owner -> sitter request flow to avoid relying on client-side sitterId.
 */
const cancelOwnerSentBookingRequest = async (req, res) => {
  try {
    const ownerId = req.user?.id;
    const { id } = req.params;

    if (!ownerId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    const booking = await Booking.findById(id).populate('ownerId').populate('sitterId').populate('petIds');
    if (!booking) {
      return res.status(404).json({ error: 'Booking not found.' });
    }

    const bookingOwnerId = booking.ownerId?._id ? booking.ownerId._id.toString() : booking.ownerId.toString();
    if (bookingOwnerId !== ownerId) {
      return res.status(403).json({ error: 'You can only cancel your own sent booking requests.' });
    }

    // Allow cancel only for request/open stages; do not allow paid/refunded/cancelled here.
    if (!['pending', 'accepted', 'agreed'].includes(booking.status)) {
      return res.status(409).json({
        error: `This request cannot be cancelled at status "${booking.status}".`,
      });
    }

    booking.status = 'cancelled';
    booking.paymentStatus = 'cancelled';
    await booking.save();
    await booking.populate('ownerId');
    await booking.populate('sitterId');

    return res.json({
      booking: sanitizeBooking(booking),
      message: 'Sent booking request cancelled successfully.',
    });
  } catch (error) {
    console.error('Cancel owner sent booking request error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid booking id.' });
    }
    return res.status(500).json({ error: 'Unable to cancel sent booking request. Please try again later.' });
  }
};

const respondBooking = async (req, res) => {
  try {
    const { id } = req.params;
    const { action } = req.body || {};

    if (!['accept', 'reject'].includes(action)) {
      return res.status(400).json({ error: 'Invalid action. Expected "accept" or "reject".' });
    }

    const booking = await Booking.findById(id).populate('ownerId').populate('sitterId').populate('petIds');
    if (!booking) {
      return res.status(404).json({ error: 'Booking not found.' });
    }

    if (booking.status !== 'pending') {
      return res.status(409).json({ error: `Booking already ${booking.status}.` });
    }

    if (action === 'accept') {
      booking.status = 'accepted';
      booking.acceptedAt = new Date();
      await booking.save();

      await createNotificationSafe({
        recipientRole: 'owner',
        recipientId: booking.ownerId?._id ? booking.ownerId._id.toString() : booking.ownerId.toString(),
        actorRole: 'sitter',
        actorId: booking.sitterId?._id ? booking.sitterId._id.toString() : booking.sitterId.toString(),
        type: 'booking_accepted',
        title: 'Booking accepted',
        body: 'Your booking request was accepted.',
        data: { bookingId: booking._id.toString() },
      });

      let conversation = await Conversation.findOne({
        ownerId: booking.ownerId._id,
        sitterId: booking.sitterId._id,
      })
        .populate('ownerId')
        .populate('sitterId')
        .populate('petIds');

      if (!conversation) {
        conversation = await Conversation.create({
          ownerId: booking.ownerId._id,
          sitterId: booking.sitterId._id,
          ownerUnreadCount: 0,
          sitterUnreadCount: 0,
        });
        await conversation.populate(['ownerId', 'sitterId']);
      } else {
        conversation.lastMessageAt = new Date();
        conversation.ownerUnreadCount = conversation.ownerUnreadCount || 0;
        conversation.sitterUnreadCount = conversation.sitterUnreadCount || 0;
        await conversation.save();
        await conversation.populate(['ownerId', 'sitterId']);
      }

      return res.json({
        booking: sanitizeBooking(booking),
        conversation: sanitizeConversation(conversation),
      });
    }

    booking.status = 'rejected';
    booking.rejectedAt = new Date();
    await booking.save();
    await booking.populate(['ownerId', 'sitterId']);

    await createNotificationSafe({
      recipientRole: 'owner',
      recipientId: booking.ownerId?._id ? booking.ownerId._id.toString() : booking.ownerId.toString(),
      actorRole: 'sitter',
      actorId: booking.sitterId?._id ? booking.sitterId._id.toString() : booking.sitterId.toString(),
      type: 'booking_rejected',
      title: 'Booking rejected',
      body: 'Your booking request was rejected.',
      data: { bookingId: booking._id.toString() },
    });

    return res.json({ booking: sanitizeBooking(booking) });
  } catch (error) {
    console.error('Respond booking error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid booking id.' });
    }
    res.status(500).json({ error: 'Unable to update booking. Please try again later.' });
  }
};

/**
 * Mark booking as AGREED (both parties agreed on details)
 * PUT /bookings/:id/agree
 */
const agreeToBooking = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user?.id;
    const userRole = req.user?.role;

    if (!userId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    const booking = await Booking.findById(id).populate('ownerId').populate('sitterId').populate('petIds');
    if (!booking) {
      return res.status(404).json({ error: 'Booking not found.' });
    }

    // Verify user has permission
    const ownerId = booking.ownerId._id.toString();
    const sitterId = booking.sitterId._id.toString();

    if (userRole === 'owner' && ownerId !== userId) {
      return res.status(403).json({ error: 'You do not have permission to agree to this booking.' });
    }

    if (userRole === 'sitter' && sitterId !== userId) {
      return res.status(403).json({ error: 'You do not have permission to agree to this booking.' });
    }

    // Check if booking is in valid state to be agreed
    if (!['pending', 'accepted'].includes(booking.status)) {
      return res.status(400).json({ error: `Booking cannot be agreed. Current status: ${booking.status}` });
    }

    // Mark as agreed using findByIdAndUpdate to only update status field
    // Using runValidators: false to avoid validation errors on old bookings missing new required fields
    const updatedBooking = await Booking.findByIdAndUpdate(
      id,
      { 
        status: 'agreed',
        agreedAt: new Date(),
      },
      { new: true, runValidators: false }
    ).populate('ownerId').populate('sitterId').populate('petIds');

    res.json({
      booking: sanitizeBooking(updatedBooking),
      message: 'Booking marked as agreed. Owner can now proceed with payment.',
    });
  } catch (error) {
    console.error('Agree to booking error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid booking id.' });
    }
    res.status(500).json({ error: 'Unable to update booking. Please try again later.' });
  }
};

/**
 * Create PaymentIntent for booking payment
 * POST /bookings/:id/create-payment-intent
 */
const createBookingPaymentIntent = async (req, res) => {
  try {
    const { id } = req.params;
    const ownerId = req.user?.id;
    const userRole = req.user?.role;

    if (!ownerId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (userRole !== 'owner') {
      return res.status(403).json({ error: 'Only owners can initiate payment.' });
    }

    const booking = await Booking.findById(id).populate('ownerId').populate('sitterId').populate('petIds');
    if (!booking) {
      return res.status(404).json({ error: 'Booking not found.' });
    }

    // Verify owner owns this booking
    if (booking.ownerId._id.toString() !== ownerId) {
      return res.status(403).json({ error: 'You do not have permission to pay for this booking.' });
    }

    // Check if booking is in AGREED status
    if (booking.status !== 'agreed') {
      return res.status(400).json({ 
        error: `Payment can only be initiated for agreed bookings. Current status: ${booking.status}` 
      });
    }

    // Validate that booking has required pricing information
    if (!booking.pricing || typeof booking.pricing.totalPrice !== 'number' || booking.pricing.totalPrice <= 0) {
      return res.status(400).json({ 
        error: 'This booking is missing valid pricing information. Please create a new booking with proper pricing details.' 
      });
    }

    // Check if sitter has Stripe Connect account
    const sitter = booking.sitterId;
    if (!sitter.stripeConnectAccountId || sitter.stripeConnectAccountStatus !== 'active') {
      return res.status(400).json({ 
        error: 'Sitter must have an active Stripe Connect account to receive payments. Please contact the sitter.' 
      });
    }

    // Check if payment already exists
    if (booking.stripePaymentIntentId) {
      const existingPaymentIntent = await getPaymentIntent(booking.stripePaymentIntentId);
      if (existingPaymentIntent.status === 'succeeded') {
        return res.status(400).json({ error: 'Payment already completed for this booking.' });
      }
      // Return existing PaymentIntent client secret
      return res.json({
        paymentIntentId: existingPaymentIntent.id,
        clientSecret: existingPaymentIntent.client_secret,
        booking: sanitizeBooking(booking),
      });
    }

    // Create PaymentIntent - validate amount is a valid number
    const totalPrice = Number(booking.pricing.totalPrice);
    if (isNaN(totalPrice) || totalPrice <= 0) {
      return res.status(400).json({ 
        error: 'Invalid booking price. Total price must be a positive number.' 
      });
    }

    // Validate and normalize booking currency for payment
    const bookingCurrency = assertSupportedCurrency(
      booking.pricing?.currency || DEFAULT_CURRENCY,
      'Booking currency must be USD or EUR to create a payment.'
    );

    const amountInCents = Math.round(totalPrice * 100); // Convert to minor units (cents)
    
    if (isNaN(amountInCents) || amountInCents <= 0) {
      return res.status(400).json({ 
        error: 'Invalid payment amount. Please check the booking pricing.' 
      });
    }

    const paymentIntent = await createPaymentIntent({
      amount: amountInCents,
      connectedAccountId: sitter.stripeConnectAccountId,
      bookingId: booking._id.toString(),
      ownerId: booking.ownerId._id.toString(),
      sitterId: booking.sitterId._id.toString(),
      currency: bookingCurrency.toLowerCase(),
    });

    // Save PaymentIntent ID and connected account ID to booking
    booking.stripePaymentIntentId = paymentIntent.id;
    booking.petsitterConnectedAccountId = sitter.stripeConnectAccountId;
    booking.paymentProvider = 'stripe';
    booking.paymentStatus = 'pending'; // Set payment status to pending when payment intent is created
    await booking.save();

    res.json({
      paymentIntentId: paymentIntent.id,
      clientSecret: paymentIntent.client_secret,
      booking: sanitizeBooking(booking),
      message: 'PaymentIntent created successfully. Use clientSecret with Stripe Payment Sheet.',
    });
  } catch (error) {
    console.error('Create payment intent error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid booking id.' });
    }
    if (error.message && (error.message.includes('Unsupported currency') || error.message.includes('Currency is required'))) {
      return res.status(400).json({ error: error.message });
    }
    if (error.message && error.message.includes('must have')) {
      return res.status(400).json({ error: error.message });
    }
    res.status(500).json({ error: 'Unable to create payment intent. Please try again later.' });
  }
};

/**
 * Create PayPal order for booking payment
 * POST /bookings/:id/paypal/create-order
 */
const createBookingPaypalOrder = async (req, res) => {
  try {
    const { id } = req.params;
    const ownerId = req.user?.id;
    const userRole = req.user?.role;

    if (!ownerId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (userRole !== 'owner') {
      return res.status(403).json({ error: 'Only owners can initiate payment.' });
    }

    const booking = await Booking.findById(id).populate('ownerId').populate('sitterId').populate('petIds');
    if (!booking) {
      return res.status(404).json({ error: 'Booking not found.' });
    }

    // Verify owner owns this booking
    if (booking.ownerId._id.toString() !== ownerId) {
      return res.status(403).json({ error: 'You do not have permission to pay for this booking.' });
    }

    // Check if booking is in AGREED status
    if (booking.status !== 'agreed') {
      return res.status(400).json({
        error: `Payment can only be initiated for agreed bookings. Current status: ${booking.status}`,
      });
    }

    // Validate that booking has required pricing information
    if (!booking.pricing || typeof booking.pricing.totalPrice !== 'number' || booking.pricing.totalPrice <= 0) {
      return res.status(400).json({
        error: 'This booking is missing valid pricing information. Please create a new booking with proper pricing details.',
      });
    }

    // Use same currency validation as Stripe
    const bookingCurrency = assertSupportedCurrency(
      booking.pricing?.currency || DEFAULT_CURRENCY,
      'Booking currency must be USD or EUR to create a payment.'
    );

    const totalPrice = Number(booking.pricing.totalPrice);
    if (isNaN(totalPrice) || totalPrice <= 0) {
      return res.status(400).json({
        error: 'Invalid booking price. Total price must be a positive number.',
      });
    }

    // If a PayPal order already exists, return it instead of creating a new one
    if (booking.paypalOrderId) {
      try {
        const existingOrder = await getPaypalOrder(booking.paypalOrderId);

        const existingApproveLink =
          Array.isArray(existingOrder.links) &&
          existingOrder.links.find((link) => link.rel === 'approve')
            ? existingOrder.links.find((link) => link.rel === 'approve').href
            : null;

        return res.json({
          orderId: existingOrder.id,
          status: existingOrder.status,
          approveUrl: existingApproveLink,
          // Alias for clients that expect "approvalUrl"
          approvalUrl: existingApproveLink,
          booking: sanitizeBooking(booking),
        });
      } catch (err) {
        console.error('Error fetching existing PayPal order, creating a new one instead:', err);
      }
    }

    const order = await createPaypalOrder({
      amount: totalPrice,
      currency: bookingCurrency,
      bookingId: booking._id.toString(),
      ownerId: booking.ownerId._id.toString(),
      sitterId: booking.sitterId._id.toString(),
    });

    booking.paypalOrderId = order.id;
    booking.paymentProvider = 'paypal';
    booking.paymentStatus = 'pending';
    await booking.save();

    const approveLink =
      Array.isArray(order.links) && order.links.find((link) => link.rel === 'approve')
        ? order.links.find((link) => link.rel === 'approve').href
        : null;

    res.json({
      orderId: order.id,
      status: order.status,
      approveUrl: approveLink,
      // Alias for clients that expect "approvalUrl"
      approvalUrl: approveLink,
      booking: sanitizeBooking(booking),
      message: 'PayPal order created successfully. Use orderId to approve and capture the payment.',
    });
  } catch (error) {
    console.error('Create PayPal order error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid booking id.' });
    }
    if (error.message && (error.message.includes('Unsupported currency') || error.message.includes('Currency'))) {
      return res.status(400).json({ error: error.message });
    }
    res.status(500).json({ error: 'Unable to create PayPal order. Please try again later.' });
  }
};

/**
 * Confirm PaymentIntent for booking payment
 * POST /bookings/:id/confirm-payment/:paymentIntentId
 */
const confirmBookingPayment = async (req, res) => {
  try {
    const { id, paymentIntentId } = req.params;
    const { payment_method, return_url } = req.body;
    const ownerId = req.user?.id;
    const userRole = req.user?.role;

    if (!ownerId) {
      return res.status(401).json({ 
        error: 'Authentication required. Please provide a valid token.',
        details: 'Include Authorization header: Bearer <your-token>'
      });
    }

    if (userRole !== 'owner') {
      return res.status(403).json({ 
        error: 'Only owners can confirm payment.',
        details: `Current role: ${userRole}. You must be authenticated as an owner.`
      });
    }

    if (!paymentIntentId) {
      return res.status(400).json({ error: 'Payment intent ID is required in the URL path.' });
    }

    const booking = await Booking.findById(id).populate('ownerId').populate('sitterId').populate('petIds');
    if (!booking) {
      return res.status(404).json({ error: 'Booking not found.' });
    }

    // Verify owner owns this booking
    if (booking.ownerId._id.toString() !== ownerId) {
      return res.status(403).json({ 
        error: 'You do not have permission to confirm payment for this booking.',
        details: `Booking owner ID: ${booking.ownerId._id.toString()}, Your ID: ${ownerId}`
      });
    }

    // Verify payment intent belongs to this booking
    if (booking.stripePaymentIntentId && booking.stripePaymentIntentId !== paymentIntentId) {
      return res.status(400).json({ 
        error: 'Payment intent ID does not match the booking\'s payment intent.' 
      });
    }

    // Confirm the payment intent
    const confirmOptions = {};
    if (payment_method) {
      confirmOptions.payment_method = payment_method;
    }
    if (return_url) {
      confirmOptions.return_url = return_url;
    }

    const confirmedPaymentIntent = await confirmPaymentIntent(paymentIntentId, confirmOptions);

    // Update booking with payment intent ID if not already set (for tracking only)
    // IMPORTANT: Do NOT update booking status here - webhooks are the single source of truth
    if (!booking.stripePaymentIntentId) {
      booking.stripePaymentIntentId = paymentIntentId;
      await booking.save();
    }

    // Return payment intent status without updating booking status
    // Booking status will be updated by Stripe webhook (payment_intent.succeeded or payment_intent.payment_failed)
    if (confirmedPaymentIntent.status === 'requires_action') {
      // Payment requires additional action (e.g., 3D Secure)
      return res.json({
        paymentIntentId: confirmedPaymentIntent.id,
        status: confirmedPaymentIntent.status,
        clientSecret: confirmedPaymentIntent.client_secret,
        requiresAction: true,
        nextAction: confirmedPaymentIntent.next_action,
        booking: sanitizeBooking(booking),
        message: 'Payment requires additional authentication. Please complete the required action.',
        note: 'Booking status will be updated automatically via webhook after payment confirmation.',
      });
    }

    // Return current payment intent status
    // Note: If status is 'succeeded', the webhook will update booking status to 'paid'
    res.json({
      paymentIntentId: confirmedPaymentIntent.id,
      status: confirmedPaymentIntent.status,
      booking: sanitizeBooking(booking),
      message: confirmedPaymentIntent.status === 'succeeded' 
        ? 'Payment confirmed. Booking status will be updated automatically via webhook.' 
        : confirmedPaymentIntent.status === 'processing'
        ? 'Payment is being processed. Please wait for confirmation via webhook.'
        : `Payment status: ${confirmedPaymentIntent.status}`,
      note: 'Booking status updates are handled automatically by Stripe webhooks for security and reliability.',
    });
  } catch (error) {
    console.error('Confirm payment error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid booking id.' });
    }
    if (error.type === 'StripeInvalidRequestError') {
      return res.status(400).json({ 
        error: error.message || 'Invalid payment intent. Please check the payment intent ID.' 
      });
    }
    if (error.message && error.message.includes('canceled')) {
      return res.status(400).json({ error: error.message });
    }
    res.status(500).json({ error: 'Unable to confirm payment. Please try again later.' });
  }
};

/**
 * Capture PayPal order for booking payment
 * POST /bookings/:id/paypal/capture/:orderId
 */
const captureBookingPaypalPayment = async (req, res) => {
  try {
    const { id, orderId } = req.params;
    const ownerId = req.user?.id;
    const userRole = req.user?.role;

    if (!ownerId) {
      return res.status(401).json({
        error: 'Authentication required. Please provide a valid token.',
        details: 'Include Authorization header: Bearer <your-token>',
      });
    }

    if (userRole !== 'owner') {
      return res.status(403).json({
        error: 'Only owners can confirm PayPal payment.',
        details: `Current role: ${userRole}. You must be authenticated as an owner.`,
      });
    }

    if (!orderId) {
      return res.status(400).json({ error: 'PayPal order ID is required in the URL path.' });
    }

    const booking = await Booking.findById(id).populate('ownerId').populate('sitterId').populate('petIds');
    if (!booking) {
      return res.status(404).json({ error: 'Booking not found.' });
    }

    // Verify owner owns this booking
    if (booking.ownerId._id.toString() !== ownerId) {
      return res.status(403).json({
        error: 'You do not have permission to confirm payment for this booking.',
        details: `Booking owner ID: ${booking.ownerId._id.toString()}, Your ID: ${ownerId}`,
      });
    }

    // Verify order belongs to this booking
    if (booking.paypalOrderId && booking.paypalOrderId !== orderId) {
      return res.status(400).json({
        error: "PayPal order ID does not match the booking's PayPal order.",
      });
    }

    const capturedOrder = await capturePaypalOrder(orderId);

    const orderStatus = capturedOrder.status;

    if (orderStatus === 'COMPLETED') {
      booking.status = 'paid';
      booking.paymentStatus = 'paid';
      booking.paymentProvider = 'paypal';
      booking.paidAt = new Date();

      // Store capture ID if available
      let captureId = null;
      try {
        const unit = Array.isArray(capturedOrder.purchaseUnits) ? capturedOrder.purchaseUnits[0] : null;
        const payments = unit && unit.payments;
        const captures = payments && Array.isArray(payments.captures) ? payments.captures : [];
        if (captures.length > 0 && captures[0].id) {
          captureId = captures[0].id;
        }
      } catch (parseError) {
        console.warn('Unable to parse PayPal capture ID from captured order:', parseError);
      }

      if (captureId) {
        booking.paypalCaptureId = captureId;
      }

      if (!booking.paypalOrderId) {
        booking.paypalOrderId = orderId;
      }

      await booking.save();

      await createNotificationSafe({
        recipientRole: 'sitter',
        recipientId: booking.sitterId?._id ? booking.sitterId._id.toString() : booking.sitterId.toString(),
        actorRole: 'owner',
        actorId: booking.ownerId?._id ? booking.ownerId._id.toString() : booking.ownerId.toString(),
        type: 'booking_paid',
        title: 'Booking paid',
        body: 'A booking was paid successfully.',
        data: {
          bookingId: booking._id.toString(),
          paymentProvider: 'paypal',
        },
      });

      // Business rule: the money stays in escrow until the first day of the
      // pet sitting service. schedulePayoutForBooking() will either release
      // the funds immediately (same-day booking) or mark the booking as
      // "scheduled" so that the payout scheduler picks it up on day 1.
      await schedulePayoutForBooking(booking);
    }

    res.json({
      orderId: capturedOrder.id,
      status: orderStatus,
      booking: sanitizeBooking(booking),
      message:
        orderStatus === 'COMPLETED'
          ? 'PayPal payment completed and booking marked as paid.'
          : `PayPal order status: ${orderStatus}`,
    });
  } catch (error) {
    console.error('Capture PayPal order error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid booking id.' });
    }
    res.status(500).json({ error: 'Unable to capture PayPal payment. Please try again later.' });
  }
};

/**
 * Get booking details with price breakdown (for Booking Agreement screen)
 * GET /bookings/:id/agreement
 */
const getBookingAgreement = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    const booking = await Booking.findById(id)
      .populate('ownerId', 'name email avatar')
      .populate('sitterId', 'name email avatar stripeConnectAccountStatus')
      .populate('petIds');

    if (!booking) {
      return res.status(404).json({ error: 'Booking not found.' });
    }

    // Verify user has permission (owner or sitter)
    const ownerId = booking.ownerId._id.toString();
    const sitterId = booking.sitterId._id.toString();

    if (userId !== ownerId && userId !== sitterId) {
      return res.status(403).json({ error: 'You do not have permission to view this booking.' });
    }

    const sanitized = sanitizeBooking(booking);

    const bookingPlain =
      typeof booking.toObject === 'function'
        ? booking.toObject({ virtuals: false })
        : { ...booking };

    const mongoose = require('mongoose');
    const bookingOid = mongoose.Types.ObjectId.isValid(id)
      ? new mongoose.Types.ObjectId(id)
      : id;
    const linkedAppRows = await Application.find({ bookingId: bookingOid })
      .select('serviceDate startDate endDate serviceType houseSittingVenue timeSlot')
      .sort({ updatedAt: -1 })
      .limit(1)
      .lean();
    const linkedApplication = linkedAppRows[0] || null;

    const schedule = mergeScheduleFromApplication({
      bookingPlain,
      applicationLean: linkedApplication,
    });
    const startDateValue =
      booking.startDate ||
      booking.date ||
      (linkedApplication?.startDate instanceof Date ? linkedApplication.startDate.toISOString() : linkedApplication?.startDate) ||
      schedule.serviceDate ||
      null;
    const endDateValue =
      booking.endDate ||
      (linkedApplication?.endDate instanceof Date ? linkedApplication.endDate.toISOString() : linkedApplication?.endDate) ||
      null;

    // Format response for Booking Agreement screen
    const pets = Array.isArray(booking.petIds) ? booking.petIds : [];
    const agreement = {
      id: sanitized.id,
      status: sanitized.status,
      pets: pets.map(pet => {
        if (pet && typeof pet === 'object' && pet._id) {
          return {
            id: pet._id.toString(),
            petName: pet.petName || '',
            breed: pet.breed || '',
            category: pet.category || '',
            weight: pet.weight || '',
            height: pet.height || '',
            colour: pet.colour || '',
            vaccination: pet.vaccination || '',
            medicationAllergies: pet.medicationAllergies || '',
            avatar: pet.avatar || { url: '', publicId: '' },
          };
        }
        return null;
      }).filter(pet => pet !== null),
      petIds: pets.map(pet => pet?._id?.toString() || pet?.toString() || pet),
      description: booking.description,
      // Scheduling: Booking document is authoritative (matches pricing). applicationRequest = sitter request snapshot.
      date: schedule.date,
      serviceDate: schedule.serviceDate,
      serviceDateCalendar: schedule.serviceDateCalendar,
      startDate: startDateValue,
      endDate: endDateValue,
      startTime: schedule.timeSlot || booking.timeSlot || '',
      timeSlot: schedule.timeSlot,
      serviceType: schedule.serviceType,
      houseSittingVenue: booking.houseSittingVenue || linkedApplication?.houseSittingVenue || null,
      scheduleSource: schedule.scheduleSource,
      applicationRequest: schedule.applicationRequest,
      duration: booking.duration,
      owner: {
        id: sanitized.owner?.id || ownerId,
        name: sanitized.owner?.name || '',
        email: sanitized.owner?.email || '',
        avatar: sanitized.owner?.avatar?.url || '',
      },
      sitter: {
        id: sanitized.sitter?.id || sitterId,
        name: sanitized.sitter?.name || '',
        email: sanitized.sitter?.email || '',
        avatar: sanitized.sitter?.avatar?.url || '',
        stripeConnectAccountStatus: booking.sitterId.stripeConnectAccountStatus || 'not_connected',
      },
      pricing: {
        basePrice: sanitized.pricing?.basePrice || 0,
        pricingTier: sanitized.pricing?.pricingTier || 'hourly',
        appliedRate: sanitized.pricing?.appliedRate || 0,
        totalHours: sanitized.pricing?.totalHours || 0,
        totalDays: sanitized.pricing?.totalDays || 0,
        addOns: sanitized.pricing?.addOns || [],
        addOnsTotal: sanitized.pricing?.addOnsTotal || 0,
        totalPrice: sanitized.pricing?.totalPrice || 0,
        platformFee: sanitized.pricing?.commission || 0,
        platformFeePercentage: 20,
        netToSitter: sanitized.pricing?.netPayout || 0,
        finalTotal: sanitized.pricing?.totalPrice || 0, // Final total owner pays (same as totalPrice)
        currency: sanitized.pricing?.currency || DEFAULT_CURRENCY,
      },
      // Align with GET /bookings/my: owner can pay when agreed (Stripe or PayPal flow).
      canPay: booking.status === 'agreed' && userId === ownerId,
      createdAt: sanitized.createdAt,
      updatedAt: sanitized.updatedAt,
    };

    res.json({ agreement });
  } catch (error) {
    console.error('Get booking agreement error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid booking id.' });
    }
    res.status(500).json({ error: 'Unable to fetch booking agreement. Please try again later.' });
  }
};

/**
 * Request cancellation (mutual agreement required)
 * POST /bookings/:id/request-cancellation
 */
const requestCancellation = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user?.id;
    const userRole = req.user?.role;

    if (!userId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    const booking = await Booking.findById(id).populate('ownerId').populate('sitterId').populate('petIds');
    if (!booking) {
      return res.status(404).json({ error: 'Booking not found.' });
    }

    const ownerId = booking.ownerId._id.toString();
    const sitterId = booking.sitterId._id.toString();

    // Verify user has permission
    if (userRole === 'owner' && ownerId !== userId) {
      return res.status(403).json({ error: 'You do not have permission to cancel this booking.' });
    }

    if (userRole === 'sitter' && sitterId !== userId) {
      return res.status(403).json({ error: 'You do not have permission to cancel this booking.' });
    }

    // Can only cancel paid bookings
    if (booking.status !== 'paid') {
      return res.status(400).json({ 
        error: `Cancellation can only be requested for paid bookings. Current status: ${booking.status}` 
      });
    }

    // Mark cancellation request
    const now = new Date();
    if (userRole === 'owner') {
      booking.cancellation.ownerRequested = true;
      booking.cancellation.ownerConfirmed = true;
      if (!booking.cancellation.requestedAt) {
        booking.cancellation.requestedAt = now;
      }
    } else {
      booking.cancellation.sitterRequested = true;
      booking.cancellation.sitterConfirmed = true;
      if (!booking.cancellation.requestedAt) {
        booking.cancellation.requestedAt = now;
      }
    }

    // Check if both parties have confirmed cancellation
    if (booking.cancellation.ownerConfirmed && booking.cancellation.sitterConfirmed) {
      // Both parties agree - process refund
      let chargeId = booking.stripeChargeId;
      let paymentIntentStatus = null;
      let refundProcessed = false;
      
      // If charge ID is missing, try to get it from payment intent
      if (!chargeId && booking.stripePaymentIntentId) {
        try {
          const paymentIntent = await getPaymentIntent(booking.stripePaymentIntentId);
          paymentIntentStatus = paymentIntent.status;
          
          // Only proceed with refund if payment was actually successful
          if (paymentIntent.status === 'succeeded' && paymentIntent.latest_charge) {
            chargeId = typeof paymentIntent.latest_charge === 'string' 
              ? paymentIntent.latest_charge 
              : paymentIntent.latest_charge.id;
            // Save it for future use
            booking.stripeChargeId = chargeId;
          }
        } catch (error) {
          console.error('Error retrieving payment intent for charge ID:', error);
        }
      } else if (booking.stripePaymentIntentId) {
        // Check payment intent status even if we have charge ID
        try {
          const paymentIntent = await getPaymentIntent(booking.stripePaymentIntentId);
          paymentIntentStatus = paymentIntent.status;
        } catch (error) {
          console.error('Error retrieving payment intent status:', error);
        }
      }
      
      if (chargeId) {
        try {
          const refund = await createRefund(chargeId);
          booking.cancellation.refundId = refund.id;
          booking.status = 'refunded';
          booking.paymentStatus = 'refund'; // Update payment status
          booking.cancellation.confirmedAt = new Date();
          refundProcessed = true;
          console.log(`✅ Refund processed for booking ${booking._id}: ${refund.id}`);
        } catch (refundError) {
          console.error('Refund error:', refundError);
          return res.status(500).json({ 
            error: 'Unable to process refund. Please try again later.',
            details: refundError.message,
            paymentIntentStatus: paymentIntentStatus
          });
        }
      } else {
        // No charge ID available - payment was never completed or not successful
        booking.status = 'cancelled';
        booking.paymentStatus = 'cancelled'; // Update payment status
        booking.cancellation.confirmedAt = new Date();
        console.warn(`⚠️ Booking ${booking._id} cancelled but no charge ID available. Payment Intent Status: ${paymentIntentStatus || 'unknown'}`);
      }
    }

    await booking.save();
    await booking.populate('ownerId');
    await booking.populate('sitterId');

    let message;
    if (booking.cancellation.ownerConfirmed && booking.cancellation.sitterConfirmed) {
      if (booking.status === 'refunded') {
        message = 'Cancellation confirmed by both parties. Refund processed successfully.';
      } else if (booking.status === 'cancelled') {
        message = 'Cancellation confirmed by both parties. No refund needed (payment was not completed).';
      } else {
        message = 'Cancellation confirmed by both parties.';
      }
    } else {
      message = 'Cancellation requested. Waiting for the other party to confirm.';
    }

    res.json({
      booking: sanitizeBooking(booking),
      message,
      cancellationStatus: {
        ownerConfirmed: booking.cancellation.ownerConfirmed,
        sitterConfirmed: booking.cancellation.sitterConfirmed,
        bothConfirmed: booking.cancellation.ownerConfirmed && booking.cancellation.sitterConfirmed,
      },
    });
  } catch (error) {
    console.error('Request cancellation error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid booking id.' });
    }
    res.status(500).json({ error: 'Unable to process cancellation request. Please try again later.' });
  }
};

/**
 * Get payment status for a booking
 * GET /bookings/:id/payment-status
 */
const getPaymentStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    const booking = await Booking.findById(id).populate('ownerId').populate('sitterId').populate('petIds');
    if (!booking) {
      return res.status(404).json({ error: 'Booking not found.' });
    }

    // Verify user has permission (owner or sitter)
    const ownerId = booking.ownerId._id.toString();
    const sitterId = booking.sitterId._id.toString();

    if (userId !== ownerId && userId !== sitterId) {
      return res.status(403).json({ error: 'You do not have permission to view this booking payment status.' });
    }

    // Get payment intent status from Stripe if it exists
    let paymentIntentStatus = null;
    let paymentIntentDetails = null;

    if (booking.stripePaymentIntentId) {
      try {
        paymentIntentDetails = await getPaymentIntent(booking.stripePaymentIntentId);
        paymentIntentStatus = paymentIntentDetails.status;
      } catch (error) {
        console.error('Error fetching payment intent:', error);
        // Continue without Stripe details
      }
    }

    // Get PayPal order status if it exists
    let paypalOrderStatus = null;
    if (booking.paypalOrderId) {
      try {
        const order = await getPaypalOrder(booking.paypalOrderId);
        paypalOrderStatus = order.status;
      } catch (error) {
        console.error('Error fetching PayPal order:', error);
      }
    }

    res.json({
      bookingId: booking._id.toString(),
      status: booking.status,
      paymentStatus: booking.paymentStatus || 'pending', // Include payment status
      paymentIntentId: booking.stripePaymentIntentId,
      chargeId: booking.stripeChargeId,
      paymentIntentStatus: paymentIntentStatus, // 'succeeded', 'processing', 'requires_payment_method', etc.
      paymentProvider: booking.paymentProvider || null,
      paypalOrderId: booking.paypalOrderId || null,
      paypalCaptureId: booking.paypalCaptureId || null,
      paypalOrderStatus: paypalOrderStatus,
      paidAt: booking.paidAt,
      payoutStatus: booking.payoutStatus || 'pending',
      payoutBatchId: booking.payoutBatchId || null,
      payoutAt: booking.payoutAt || null,
      pricing: booking.pricing
        ? {
            basePrice: booking.pricing.basePrice || 0,
            pricingTier: booking.pricing.pricingTier || 'hourly',
            appliedRate: booking.pricing.appliedRate || 0,
            totalHours: booking.pricing.totalHours || 0,
            totalDays: booking.pricing.totalDays || 0,
            totalPrice: booking.pricing.totalPrice || 0,
            commission: booking.pricing.commission || 0,
            netPayout: booking.pricing.netPayout || 0,
            currency: booking.pricing.currency || DEFAULT_CURRENCY,
          }
        : null,
      canRetryPayment: booking.status === 'payment_failed' || booking.status === 'agreed',
      message: booking.status === 'paid' 
        ? 'Payment completed successfully.'
        : booking.status === 'payment_failed'
        ? 'Payment failed. You can retry payment.'
        : booking.status === 'agreed'
        ? 'Payment not yet initiated.'
        : 'Payment status unknown.',
    });
  } catch (error) {
    console.error('Get payment status error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid booking id.' });
    }
    res.status(500).json({ error: 'Unable to fetch payment status. Please try again later.' });
  }
};

/**
 * Admin endpoint: retry payout for a paid booking whose payout previously failed.
 * POST /admin/bookings/:id/retry-payout
 */
const retryBookingPayout = async (req, res) => {
  try {
    const { id } = req.params;

    const booking = await Booking.findById(id).populate('ownerId').populate('sitterId').populate('petIds');
    if (!booking) {
      return res.status(404).json({ error: 'Booking not found.' });
    }

    if (booking.paymentStatus !== 'paid' || booking.status !== 'paid') {
      return res.status(400).json({
        error: 'Payout can only be retried for bookings with paid status.',
      });
    }

    if (booking.paymentProvider !== 'paypal') {
      return res.status(400).json({
        error: 'Payout retry is only supported for PayPal payments.',
      });
    }

    if (booking.payoutStatus === 'completed') {
      return res.status(400).json({
        error: 'Payout has already been completed for this booking.',
      });
    }

    if (booking.payoutStatus !== 'failed') {
      return res.status(400).json({
        error: `Payout can only be retried when payoutStatus is "failed". Current status: ${booking.payoutStatus || 'pending'}.`,
      });
    }

    await processSitterPayoutForBooking(booking);

    // Reload latest state
    await booking.reload();

    res.json({
      bookingId: booking._id.toString(),
      payoutStatus: booking.payoutStatus,
      payoutBatchId: booking.payoutBatchId || null,
      payoutAt: booking.payoutAt || null,
      payoutError: booking.payoutError || null,
      message:
        booking.payoutStatus === 'completed'
          ? 'Payout retried and completed successfully.'
          : 'Payout retry attempted. Check payoutStatus and payoutError for details.',
    });
  } catch (error) {
    console.error('Retry payout error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid booking id.' });
    }
    res.status(500).json({ error: 'Unable to retry payout. Please try again later.' });
  }
};


/**
 * processScheduledSitterPayouts — called by the background scheduler every
 * hour. Finds all bookings whose escrow payout is due (scheduled date <= now)
 * and releases the sitter payout via processSitterPayoutForBooking.
 */
const processScheduledSitterPayouts = async () => {
  const now = new Date();
  const endOfToday = new Date(now);
  endOfToday.setHours(23, 59, 59, 999);

  const dueBookings = await Booking.find({
    payoutStatus: 'scheduled',
    scheduledPayoutAt: { $lte: endOfToday },
  }).populate('ownerId').populate('sitterId').populate('petIds');

  if (!dueBookings.length) return { released: 0 };

  let released = 0;
  for (const booking of dueBookings) {
    try {
      await processSitterPayoutForBooking(booking);
      released += 1;
    } catch (err) {
      console.error(`⚠️  processScheduledSitterPayouts: failed for booking ${booking._id}`, err);
    }
  }
  console.log(`💸 processScheduledSitterPayouts: released ${released} payout(s).`);
  return { released };
};


module.exports = {
  createBooking,
  listBookings,
  getMyBookings,
  cancelBooking,
  cancelOwnerSentBookingRequest,
  selfCancelWithRefund,
  respondBooking,
  agreeToBooking,
  createBookingPaymentIntent,
  confirmBookingPayment,
  createBookingPaypalOrder,
  captureBookingPaypalPayment,
  getBookingAgreement,
  requestCancellation,
  getPaymentStatus,
  retryBookingPayout,
  processScheduledSitterPayouts,
};

