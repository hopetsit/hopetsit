const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
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
  sendPayoutToIBAN,
} = require('../services/stripeService');
const {
  createPaypalOrder,
  capturePaypalOrder,
  getPaypalOrder,
  refundPaypalCapture,
} = require('../services/paypalService');
const { sendPayoutToSitter } = require('../services/paypalPayoutService');
const { assertSupportedCurrency, DEFAULT_CURRENCY } = require('../utils/currency');
const { countryToCurrency } = require('../utils/countryCurrency');
const { createNotificationSafe } = require('../services/notificationService');
const { sendNotification } = require('../services/notificationSender');
const { onBookingCompleted, consumeLoyaltyDiscount } = require('../services/loyaltyService');
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
const logger = require('../utils/logger');

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
    // Session v16-owner-walker — Owner can now book a Walker directly.
    // Caller sends either ?sitterId=... OR ?walkerId=..., never both.
    const walkerIdQuery = req.query?.walkerId;
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

    // Session v16-owner-walker — resolve which provider the Owner targets.
    // walkerId wins if both happen to be sent (shouldn't happen client-side
    // but keeps the behaviour deterministic). providerId is the id we write
    // to the Booking, providerType picks which collection we fetch.
    const walkerIdClean =
      typeof walkerIdQuery === 'string' ? walkerIdQuery.trim() : '';
    const sitterIdClean =
      typeof sitterIdQuery === 'string' ? sitterIdQuery.trim() : '';
    const providerType = walkerIdClean
      ? 'walker'
      : sitterIdClean
        ? 'sitter'
        : null;
    const providerId = walkerIdClean || sitterIdClean;
    // Legacy alias kept to minimise diff in the rest of this function —
    // most downstream code still reads `sitterId`, which now just means
    // "the provider id" regardless of whether it's a sitter or a walker.
    const sitterId = providerId;

    if (!providerId) {
      return res.status(400).json({
        error: 'sitterId or walkerId query parameter is required.',
      });
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

    // Session v16-owner-walker — fetch the right collection based on
    // providerType. For walkers we build a minimal "sitter-shim" object
    // (plain JS, not a Mongoose doc) carrying only the fields the
    // downstream pricing code needs: hourlyRate / dailyRate / weeklyRate /
    // monthlyRate / rate / currency. This avoids branching the whole
    // pricing pipeline on providerType.
    let sitter = null;
    if (providerType === 'walker') {
      const Walker = require('../models/Walker');
      const walker = await Walker.findById(providerId);
      if (!walker) {
        return res.status(404).json({ error: 'Walker not found.' });
      }
      const findWalkRate = (min) => {
        const rate = (walker.walkRates || []).find(
          (r) =>
            r.durationMinutes === min && r.enabled && r.basePrice > 0,
        );
        return rate ? rate.basePrice : null;
      };
      let derivedHourly = findWalkRate(60);
      if (!derivedHourly) {
        const half = findWalkRate(30);
        if (half) derivedHourly = half * 2;
      }
      if (!derivedHourly) {
        const ninety = findWalkRate(90);
        if (ninety) derivedHourly = ninety * (60 / 90);
      }
      if (!derivedHourly) {
        const twoHours = findWalkRate(120);
        if (twoHours) derivedHourly = twoHours / 2;
      }
      if (!derivedHourly || derivedHourly <= 0) {
        return res.status(400).json({
          error:
            'Walker must set at least one walk rate before creating a payable booking request.',
        });
      }
      sitter = {
        _id: walker._id,
        hourlyRate: derivedHourly,
        dailyRate: 0,
        weeklyRate: 0,
        monthlyRate: 0,
        rate: String(derivedHourly),
        currency: walker.currency || DEFAULT_CURRENCY,
        // The rest of the file reads these fields in a few places; keeping
        // them helps the sanitize helpers treat walkers as sitter-like
        // without a special case.
        name: walker.name,
        email: walker.email,
        mobile: walker.mobile,
      };
    } else {
      sitter = await Sitter.findById(sitterId);
      if (!sitter) {
        return res.status(404).json({ error: 'Sitter not found.' });
      }
      // Session v15-6 — the Sitter edit UI was simplified in v15 so sitters
      // often configure only dailyRate/weeklyRate/monthlyRate (no hourly).
      // Reject only when *no* rate at all is set; otherwise we'll derive the
      // hourly fallback from the most specific rate available below.
      const hasAnyRate =
        (sitter.hourlyRate && sitter.hourlyRate > 0) ||
        (sitter.dailyRate && sitter.dailyRate > 0) ||
        (sitter.weeklyRate && sitter.weeklyRate > 0) ||
        (sitter.monthlyRate && sitter.monthlyRate > 0);
      if (!hasAnyRate) {
        return res.status(400).json({
          error:
            'Sitter must set at least one rate (hourly, daily, weekly or monthly) before creating a payable booking request.',
        });
      }
    }
    // v18.9.5 — ne dérive PLUS hourlyRate quand dailyRate existe. Le
    // tierPricing fait désormais le fallback proprement (tier 'daily' pour
    // les bookings ≥ 8h, sinon hourly dérivé pour les courts créneaux).
    // On ne force un fallback QUE si aucun rate explicit n'existe.
    if ((!sitter.hourlyRate || sitter.hourlyRate <= 0) &&
        (!sitter.dailyRate || sitter.dailyRate <= 0)) {
      if (sitter.weeklyRate && sitter.weeklyRate > 0) {
        sitter.hourlyRate = sitter.weeklyRate / 56;
      } else if (sitter.monthlyRate && sitter.monthlyRate > 0) {
        sitter.hourlyRate = sitter.monthlyRate / 240;
      }
    }

    // v18.9.3 — fix prix 30 min walker via demande DIRECTE (owner→walker).
    // Si le walker a un walkRate EXPLICITE pour la durée demandée, on
    // shim hourlyRate pour que tierPricing retombe exactement sur ce tarif.
    // Ex : walker a mis 5€ pour 30min ET 7€ pour 60min. Sans ce fix, owner
    // paye 0.5 × 7 = 3.50€ (au lieu de 5€).
    if (providerType === 'walker' && durationNum) {
      const Walker = require('../models/Walker');
      const walkerForRates = await Walker.findById(providerId);
      if (walkerForRates && Array.isArray(walkerForRates.walkRates)) {
        const exactRate = walkerForRates.walkRates.find(
          (r) => r.durationMinutes === durationNum &&
                 r.enabled && r.basePrice > 0,
        );
        if (exactRate) {
          sitter.hourlyRate = exactRate.basePrice * 60 / durationNum;
        }
      }
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
        logger.error('Error getting recommended price range:', error);
      }
    }

    const tierPricing = calculateTierBasePrice({
      hourlyRate: sitter.hourlyRate,
      // v18.9.5 — pass dailyRate pour le tier "daily" (pet_sitting /
      // day_care / house_sitting ≥ 8h).
      dailyRate: sitter.dailyRate,
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
      // Session v16-owner-walker — write only the relevant provider field.
      // The Booking schema's pre('validate') enforces exactly one is set.
      sitterId: providerType === 'sitter' ? sitterId : null,
      walkerId: providerType === 'walker' ? providerId : null,
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

    // Session v16.2 - route the notification to the correct collection
    // based on providerType. Previously hardcoded to 'sitter', which meant
    // walker bookings either failed silently (wrong enum) or persisted with
    // a null recipientId.
    const notificationRecipientRole =
      providerType === 'walker' ? 'walker' : 'sitter';
    const notificationRecipientId =
      providerType === 'walker' ? providerId : sitterId;

    // v18.4 — single path via sendNotification (writes bell + FCM + email).
    // Removed the direct createNotificationSafe call that was creating a
    // second duplicate in-app notification with English hardcoded text.
    sendNotification({
      userId: notificationRecipientId.toString
        ? notificationRecipientId.toString()
        : String(notificationRecipientId),
      role: notificationRecipientRole,
      type: 'booking_new',
      data: {
        bookingId: booking._id.toString(),
        ownerId: ownerId.toString(),
        providerRole: notificationRecipientRole,
      },
      actor: { role: 'owner', id: ownerId.toString ? ownerId.toString() : String(ownerId) },
    }).catch(() => {});

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
    logger.error('Create booking error', error);
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
 * Session v17 — unified provider resolver for a Booking doc.
 *
 * Every paid Booking targets EITHER a sitter (legacy) OR a walker (since
 * v16-owner-walker). The Booking schema enforces this XOR via a pre-save
 * validator. Before v17, almost every downstream helper hard-coded the
 * sitter path and silently broke for walker bookings.
 *
 * This helper returns the single provider doc/id/model regardless of
 * which side of the XOR is set. Pass a booking that has been populated
 * with .populate('sitterId').populate('walkerId') if you want the full
 * doc; otherwise only the ObjectId id is returned.
 *
 * Shape:
 *   { type: 'sitter' | 'walker' | null,
 *     id:   string | null,              // always the string id
 *     doc:  Mongoose doc | null,        // populated doc when available
 *     Model: Sitter | Walker | null }   // for re-queries
 */
const getBookingProvider = (booking) => {
  if (booking?.walkerId) {
    const ref = booking.walkerId;
    const isPopulated = ref && typeof ref === 'object' && ref._id;
    return {
      type: 'walker',
      id: isPopulated ? ref._id.toString() : String(ref),
      doc: isPopulated ? ref : null,
      Model: Walker,
    };
  }
  if (booking?.sitterId) {
    const ref = booking.sitterId;
    const isPopulated = ref && typeof ref === 'object' && ref._id;
    return {
      type: 'sitter',
      id: isPopulated ? ref._id.toString() : String(ref),
      doc: isPopulated ? ref : null,
      Model: Sitter,
    };
  }
  return { type: null, id: null, doc: null, Model: null };
};

/**
 * Parse the booking start date+time (stored as strings) into a Date object.
 * The application stores dates as "YYYY-MM-DD" or ISO strings and timeSlot
 * as "HH:mm" or "H h MM" patterns. We try ISO first, then combine the date
 * part of startDate/date with the hours+minutes parsed from timeSlot.
 *
 * Session v17 — hour-exact granularity. Previously forced midnight local so
 * the payout was eligible during the whole day; now we preserve the actual
 * start time of the service so the scheduler (polling every 5 minutes) can
 * release funds at the precise hour the service begins.
 *
 * Falls back to the booking creation date when nothing else can be parsed.
 */
const parseTimeSlotToHoursMinutes = (timeSlot) => {
  if (!timeSlot || typeof timeSlot !== 'string') return null;
  // Accepts "14:00", "14h00", "14h", "14 h 30", "9:05", "09:5", etc.
  const cleaned = timeSlot.trim().toLowerCase().replace(/\s+/g, '');
  const match = cleaned.match(/^(\d{1,2})[:h](\d{0,2})/);
  if (!match) {
    // Edge case: "9h" with no minutes.
    const hourOnly = cleaned.match(/^(\d{1,2})h$/);
    if (hourOnly) {
      const h = Number(hourOnly[1]);
      if (Number.isInteger(h) && h >= 0 && h <= 23) return { h, m: 0 };
    }
    return null;
  }
  const h = Number(match[1]);
  const m = match[2] === '' ? 0 : Number(match[2]);
  if (!Number.isInteger(h) || !Number.isInteger(m) || h < 0 || h > 23 || m < 0 || m > 59) {
    return null;
  }
  return { h, m };
};

const resolveBookingStartDate = (booking) => {
  const raw = booking?.startDate || booking?.date || null;
  if (raw) {
    const parsed = new Date(raw);
    if (!Number.isNaN(parsed.getTime())) {
      // Session v17 — if the raw value already carries a time component (ISO
      // string with hours), trust it. Otherwise combine with timeSlot.
      const hasTimePart = typeof raw === 'string' && /T\d{2}:/.test(raw);
      if (hasTimePart) {
        return parsed;
      }
      const hm = parseTimeSlotToHoursMinutes(booking?.timeSlot);
      if (hm) {
        parsed.setHours(hm.h, hm.m, 0, 0);
      } else {
        // Fallback: start-of-day. Rare — only legacy bookings without
        // timeSlot hit this path.
        parsed.setHours(0, 0, 0, 0);
      }
      return parsed;
    }
  }
  return booking?.createdAt ? new Date(booking.createdAt) : new Date();
};

/**
 * Returns true when the booking start datetime is now or already in the past.
 * Used to decide whether the provider payout should be released immediately
 * (same-day/late booking, admin retry) or scheduled for the exact start time.
 *
 * Session v17 — hour-exact comparison (was day-exact before).
 */
const isBookingPayoutDue = (booking) => {
  const start = resolveBookingStartDate(booking);
  return start.getTime() <= Date.now();
};

/**
 * Schedules or triggers the sitter payout for a booking that has just been paid.
 *
 * Business rule (HopeTSIT):
 *   The money stays in escrow until the first day of the pet sitting service.
 *   On that first day, `processScheduledSitterPayouts` (run by the scheduler)
 *   will call `processProviderPayoutForBooking` to actually release the funds.
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
    await processProviderPayoutForBooking(booking);
    return;
  }

  booking.payoutStatus = 'scheduled';
  await booking.save();
  logger.info(
    `🗓️  Payout scheduled for booking ${booking._id.toString()} on ${booking.scheduledPayoutAt.toISOString()}`
  );
};

/**
 * Internal helper to process the provider payout (sitter OR walker) for a
 * paid booking. Uses Stripe destination-charge auto-transfer when possible,
 * otherwise falls back to PayPal payout or Stripe transfer to IBAN.
 *
 * Idempotent — bails out if payoutStatus is already 'completed'.
 *
 * Session v17 — renamed from processSitterPayoutForBooking and extended to
 * resolve the provider via getBookingProvider() so walker bookings are
 * actually paid out (previously they crashed with "sitter not found").
 *
 * @param {import('mongoose').Document} booking
 */
const processProviderPayoutForBooking = async (booking) => {
  try {
    if (!booking) return;

    // Ensure booking is in a valid state for payout
    if (booking.status !== 'paid' || booking.paymentStatus !== 'paid') return;

    // Idempotency: never send payout twice
    if (booking.payoutStatus === 'completed') {
      logger.info('ℹ️ Payout already completed for booking', booking._id.toString());
      return;
    }

    // Stripe destination-charge payments are auto-transferred to the
    // provider's connected account at capture time — no manual payout needed.
    if (booking.paymentProvider === 'stripe' && booking.petsitterConnectedAccountId) {
      booking.payoutStatus = 'completed';
      booking.payoutAt = booking.payoutAt || new Date();
      await booking.save();
      logger.info('✅ Stripe destination-charge payout auto-completed for booking', booking._id.toString());
      return;
    }

    const netPayout = booking.pricing?.netPayout;
    const currency = booking.pricing?.currency;

    if (typeof netPayout !== 'number' || !Number.isFinite(netPayout) || netPayout <= 0) {
      logger.warn('⚠️ Skipping payout due to invalid netPayout', {
        bookingId: booking._id.toString(),
        netPayout,
      });
      return;
    }

    // Session v17 — resolve sitter OR walker via the unified provider
    // helper. The "sitter" variable name is kept below to minimise diff in
    // the payoutMethod branches; semantically it now means "provider".
    const provider = getBookingProvider(booking);
    if (!provider.id || !provider.Model) {
      logger.error('❌ Unable to process payout: provider missing on booking', booking._id.toString());
      booking.payoutStatus = 'failed';
      booking.payoutError = 'Provider missing on booking (no sitterId nor walkerId).';
      await booking.save();
      return;
    }
    const sitter = await provider.Model.findById(provider.id);
    if (!sitter) {
      logger.error(`❌ Unable to process payout: ${provider.type} not found for booking`, booking._id.toString());
      booking.payoutStatus = 'failed';
      booking.payoutError = `${provider.type === 'walker' ? 'Walker' : 'Sitter'} not found for payout.`;
      await booking.save();
      return;
    }

    // v18.5 — #3 hold admin : si le provider n'a toujours rien configuré
    // (ni IBAN ni PayPal ni Stripe Connect actif) au moment du payout,
    // on ne marque PAS `failed` (ce qui coincerait définitivement les
    // fonds), on marque `held` et on laisse `processHeldPayouts` retry
    // périodiquement. L'argent reste sur le compte plateforme, les comptes
    // sont justes.
    const hasIban = !!(
      sitter.ibanNumber && String(sitter.ibanNumber).trim().length > 0
    );
    const hasPaypal = !!(
      sitter.paypalEmail && String(sitter.paypalEmail).trim().length > 0
    );
    const hasStripeConnectActive =
      sitter.stripeConnectAccountId &&
      sitter.stripeConnectAccountStatus === 'active';
    if (!hasIban && !hasPaypal && !hasStripeConnectActive) {
      booking.payoutStatus = 'held';
      booking.heldAmount = netPayout;
      booking.heldSince = booking.heldSince || new Date();
      await booking.save();
      logger.info(
        `⏸️  Payout HELD for booking ${booking._id.toString()} — provider ${provider.type}:${sitter._id} has no payout method yet. Will release when IBAN/PayPal configured.`
      );
      return;
    }

    // Determine payout method: use sitter's preference, fallback to paypal
    const payoutMethod = sitter.payoutMethod || 'paypal';

    // ── IBAN payout ──
    // v18.9.6 — correction BUG CRITIQUE : l'ancien code appelait
    // stripe.transfers.create({ destination: customer.id, ... }) ce qui
    // échoue TOUJOURS côté Stripe parce que l'API Transfers exige un
    // Connected Account (acct_...), pas un Customer (cus_...). Résultat :
    // tout IBAN payout terminait en 'failed'.
    // Nouveau flow : on passe en 'pending_manual_transfer' → Daniel
    // (admin) exécute le virement SEPA depuis son propre compte bancaire
    // puis valide via /admin/bookings/:id/mark-iban-paid. Les fonds
    // restent sur le compte plateforme en attendant, les comptes sont
    // cohérents.
    if (payoutMethod === 'iban') {
      const ibanNumber = decrypt(sitter.ibanNumber || '').trim();
      const holderName = (sitter.ibanHolder || sitter.name || '').trim();
      if (!ibanNumber) {
        logger.warn('⚠️ Skipping IBAN payout: IBAN missing', {
          bookingId: booking._id.toString(),
          providerId: sitter._id.toString(),
        });
        booking.payoutStatus = 'failed';
        booking.payoutError = 'Provider IBAN is missing.';
        await booking.save();
        return;
      }

      const maskedIban =
        ibanNumber.length >= 8
          ? ibanNumber.slice(0, 4) + '****' + ibanNumber.slice(-4)
          : ibanNumber;
      booking.payoutStatus = 'pending_manual_transfer';
      booking.payoutMethod = 'iban';
      booking.manualPayoutDetails = {
        iban: ibanNumber,
        ibanMasked: maskedIban,
        holderName,
        bic: sitter.ibanBic || '',
        providerEmail: sitter.email || '',
        providerRole: provider.type,
        providerId: sitter._id.toString(),
        amount: netPayout,
        currency: (currency || 'EUR').toUpperCase(),
        queuedAt: new Date(),
      };
      booking.payoutError = null;
      await booking.save();
      logger.info(
        `⏳ IBAN payout queued for manual admin transfer: booking=${booking._id.toString()} provider=${provider.type}:${sitter._id} amount=${netPayout} ${currency} iban=${maskedIban}`,
      );
      return;
    }

    // ── PayPal payout ──
    if (payoutMethod === 'paypal' || booking.paymentProvider === 'paypal') {
      const sitterPaypalEmail = decrypt(sitter.paypalEmail || '').trim();
      if (!sitterPaypalEmail) {
        logger.warn('⚠️ Skipping payout: sitter PayPal email missing', {
          bookingId: booking._id.toString(),
          sitterId: sitter._id.toString(),
        });
        booking.payoutStatus = 'failed';
        booking.payoutError = 'Sitter PayPal email is missing.';
        await booking.save();
        return;
      }

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
      logger.info('✅ PayPal payout completed for booking', booking._id.toString());
      return;
    }

    // ── Stripe Connect payout (sitter chose stripe as payout method) ──
    if (payoutMethod === 'stripe') {
      // Stripe Connect destination charges handle the transfer automatically,
      // but if paymentProvider was paypal, we can't stripe-payout. Flag it.
      if (booking.paymentProvider === 'paypal') {
        logger.warn('⚠️ Provider payout method is stripe but payment was via PayPal — falling back to PayPal payout');
        // Recursive call with paypal override
        sitter.payoutMethod = 'paypal';
        return processProviderPayoutForBooking(booking);
      }
      booking.payoutStatus = 'completed';
      booking.payoutAt = new Date();
      await booking.save();
      logger.info('✅ Stripe Connect payout auto-completed for booking', booking._id.toString());
      return;
    }

    logger.warn('⚠️ Unknown payout method for sitter', { payoutMethod, sitterId: sitter._id.toString() });
    booking.payoutStatus = 'failed';
    booking.payoutError = `Unknown payout method: ${payoutMethod}`;
    await booking.save();
  } catch (error) {
    logger.error('❌ Error while processing sitter payout for booking', booking._id.toString(), error);
    booking.payoutStatus = 'failed';
    booking.payoutError = error.message || String(error);
    try {
      await booking.save();
    } catch (saveError) {
      logger.error('❌ Failed to persist payout failure state for booking', booking._id.toString(), saveError);
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
    logger.error('Fetch bookings error', error);
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

    if (!userRole || !['owner', 'sitter', 'walker'].includes(userRole)) {
      return res.status(400).json({ error: 'Invalid user role. Expected "owner", "sitter" or "walker".' });
    }

    // Session v17 — walker was stubbed to return [] here because an earlier
    // comment ("Booking has ownerId/sitterId only") was wrong: the Booking
    // schema has supported walkerId since v16-owner-walker. Filter by the
    // correct provider field depending on the authenticated role.
    const filter = {};
    if (userRole === 'owner') {
      filter.ownerId = userId;
    } else if (userRole === 'walker') {
      filter.walkerId = userId;
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
      .populate('walkerId', 'name email avatar mobile address location rating reviewsCount')
      .populate('petIds');

    // Format bookings for Bookings History screen
    const formattedBookings = await Promise.all(bookings.map(async (booking) => {
      const sanitized = sanitizeBooking(booking);
      // Session v17 — pick the right "other party" depending on whether the
      // booking targets a sitter or a walker. For an owner, the other party
      // is whichever provider the booking is for. For a sitter or walker,
      // it's always the owner.
      let otherParty;
      let otherPartyRaw;
      if (userRole === 'owner') {
        otherParty = sanitized.walker || sanitized.sitter;
        otherPartyRaw = booking.walkerId || booking.sitterId;
      } else {
        otherParty = sanitized.owner;
        otherPartyRaw = booking.ownerId;
      }

      // Get phone number
      const phone = otherPartyRaw?.mobile || '';

      // Get location
      let location = '';
      if (userRole === 'owner' && otherPartyRaw?.location?.city) {
        // For sitter/walker, use city from location object
        location = otherPartyRaw.location.city;
      } else if ((userRole === 'sitter' || userRole === 'walker') && otherPartyRaw?.address) {
        // For owner, use address
        location = otherPartyRaw.address;
      }

      // Get rating
      let rating = 0;
      let reviewsCount = 0;

      if (userRole === 'owner') {
        // For sitter/walker, use rating field directly
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
        // v16.3i — owner can pay when status is 'agreed' (application flow)
        // or 'accepted' (direct booking flow).
        canPay: (booking.status === 'agreed' || booking.status === 'accepted') && userRole === 'owner',
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
    logger.error('Get my bookings error', error);
    res.status(500).json({ error: 'Unable to fetch bookings. Please try again later.' });
  }
};

const cancelBooking = async (req, res) => {
  try {
    const ownerId = req.user?.id;
    // Session v17 — caller can identify the provider via ?sitterId or ?walkerId.
    // Walker bookings previously rejected with a 400 because sitterId was
    // required. We accept either and match against whichever field the
    // booking actually has.
    const sitterIdQuery = req.query?.sitterId;
    const walkerIdQuery = req.query?.walkerId;
    const { id } = req.params;

    if (!ownerId) {
      return res.status(403).json({ error: 'Owner context missing.' });
    }

    const sitterId = typeof sitterIdQuery === 'string' ? sitterIdQuery.trim() : '';
    const walkerId = typeof walkerIdQuery === 'string' ? walkerIdQuery.trim() : '';

    if (!sitterId && !walkerId) {
      return res.status(400).json({ error: 'sitterId or walkerId query parameter is required.' });
    }

    const booking = await Booking.findById(id).populate('petIds');

    if (!booking) {
      return res.status(404).json({ error: 'Booking not found.' });
    }

    const bookingOwnerMatches = booking.ownerId.toString() === ownerId;
    const bookingProviderId = (booking.walkerId || booking.sitterId || '').toString();
    const providedProviderId = walkerId || sitterId;
    if (!bookingOwnerMatches || bookingProviderId !== providedProviderId) {
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
    await booking.populate('walkerId');

    // Session v17.1 — release the reservation on any Post flagged as
    // reserved-by this booking. Best-effort so a missing Post (soft-deleted
    // or pre-v17.1) never blocks the cancellation itself.
    try {
      const Post = require('../models/Post');
      await Post.updateMany(
        { 'reservedBy.bookingId': booking._id },
        {
          $set: {
            reservedBy: {
              bookingId: null,
              providerRole: null,
              providerId: null,
              providerName: '',
              reservedAt: null,
            },
          },
        },
      );
    } catch (releaseErr) {
      logger.warn(
        '[cancelBooking] failed to release Post reservation',
        releaseErr?.message || releaseErr,
      );
    }

    res.json({ booking: sanitizeBooking(booking), message: 'Booking cancelled.' });
  } catch (error) {
    logger.error('Cancel booking error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid booking id.' });
    }
    res.status(500).json({ error: 'Unable to cancel booking. Please try again later.' });
  }
};

/**
 * Refund the payment for a booking, regardless of provider.
 * Stripe → createRefund (by chargeId or paymentIntentId)
 * PayPal → refundPaypalCapture (by captureId)
 */
const refundBookingPayment = async (booking) => {
  if (booking.paymentProvider === 'stripe') {
    const chargeId = booking.stripeChargeId || booking.stripePaymentIntentId;
    if (!chargeId) throw new Error('No Stripe charge/PI ID to refund.');
    return createRefund(chargeId);
  }
  if (booking.paymentProvider === 'paypal') {
    const captureId = booking.paypalCaptureId;
    if (!captureId) throw new Error('No PayPal capture ID to refund.');
    return refundPaypalCapture(captureId);
  }
  throw new Error(`Unknown payment provider: ${booking.paymentProvider}`);
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
      logger.error('⚠️  Self-cancel refund failed', refundErr);
      // Do not fail the cancellation — the booking is marked and admin can retry.
    }

    return res.json({
      booking: sanitizeBooking(booking),
      message: 'Booking cancelled and refund initiated.',
    });
  } catch (error) {
    logger.error('Self-cancel with refund error', error);
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
    logger.error('Cancel owner sent booking request error', error);
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

    const booking = await Booking.findById(id)
      .populate('ownerId')
      .populate('sitterId')
      .populate('walkerId')
      .populate('petIds');
    if (!booking) {
      return res.status(404).json({ error: 'Booking not found.' });
    }

    if (booking.status !== 'pending') {
      return res.status(409).json({ error: `Booking already ${booking.status}.` });
    }

    // Session v16.2 - derive actor info from whichever provider field is set
    // so walker accept/reject notifications reach the owner correctly.
    const isWalkerResponder = !!booking.walkerId;
    const actorRoleForOwnerNotif = isWalkerResponder ? 'walker' : 'sitter';
    const actorIdForOwnerNotif = isWalkerResponder
      ? (booking.walkerId?._id ? booking.walkerId._id.toString() : booking.walkerId.toString())
      : (booking.sitterId?._id ? booking.sitterId._id.toString() : booking.sitterId.toString());

    if (action === 'accept') {
      booking.status = 'accepted';
      booking.acceptedAt = new Date();
      await booking.save();

      // v18.4 — single path via sendNotification (bell + FCM + email).
      sendNotification({
        userId: booking.ownerId?._id ? booking.ownerId._id.toString() : booking.ownerId.toString(),
        role: 'owner',
        type: 'booking_accepted',
        data: {
          bookingId: booking._id.toString(),
          providerRole: actorRoleForOwnerNotif,
        },
        actor: { role: actorRoleForOwnerNotif, id: actorIdForOwnerNotif },
      }).catch(() => {});

      // Session v17 — Conversation model is sitter-only (sitterId required +
      // unique index on {ownerId, sitterId}). For walker bookings we skip
      // conversation creation entirely until Conversation gains walkerId
      // support in a future version. This avoids a required-field crash on
      // walker accept without breaking the sitter flow.
      let conversation = null;
      if (!isWalkerResponder) {
        conversation = await Conversation.findOne({
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
      }

      return res.json({
        booking: sanitizeBooking(booking),
        conversation: conversation ? sanitizeConversation(conversation) : null,
      });
    }

    booking.status = 'rejected';
    booking.rejectedAt = new Date();
    await booking.save();
    await booking.populate(['ownerId', 'sitterId', 'walkerId']);

    // v18.4 — single path via sendNotification (bell + FCM + email).
    sendNotification({
      userId: booking.ownerId?._id ? booking.ownerId._id.toString() : booking.ownerId.toString(),
      role: 'owner',
      type: 'booking_rejected',
      data: {
        bookingId: booking._id.toString(),
        providerRole: actorRoleForOwnerNotif,
      },
      actor: { role: actorRoleForOwnerNotif, id: actorIdForOwnerNotif },
    }).catch(() => {});

    return res.json({ booking: sanitizeBooking(booking) });
  } catch (error) {
    logger.error('Respond booking error', error);
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

    // v18.6 — agreeToBooking walker support : populate walkerId aussi.
    const booking = await Booking.findById(id)
      .populate('ownerId')
      .populate('sitterId')
      .populate('walkerId')
      .populate('petIds');
    if (!booking) {
      return res.status(404).json({ error: 'Booking not found.' });
    }

    // v18.6 — résolution provider walker OU sitter (getBookingProvider).
    const providerRef = getBookingProvider(booking);
    const ownerId = booking.ownerId._id.toString();
    const providerId = providerRef?.id || null;
    const providerRole = providerRef?.type || null; // 'sitter' | 'walker'

    if (userRole === 'owner' && ownerId !== userId) {
      return res.status(403).json({ error: 'You do not have permission to agree to this booking.' });
    }

    if ((userRole === 'sitter' || userRole === 'walker') && providerId !== userId) {
      return res.status(403).json({ error: 'You do not have permission to agree to this booking.' });
    }

    // Check if booking is in valid state to be agreed
    if (!['pending', 'accepted'].includes(booking.status)) {
      return res.status(400).json({ error: `Booking cannot be agreed. Current status: ${booking.status}` });
    }

    const updatedBooking = await Booking.findByIdAndUpdate(
      id,
      {
        status: 'agreed',
        agreedAt: new Date(),
      },
      { new: true, runValidators: false }
    )
      .populate('ownerId')
      .populate('sitterId')
      .populate('walkerId')
      .populate('petIds');

    // Sprint 4 step 3 — notify both parties of mutual acceptance
    const petName = Array.isArray(updatedBooking.petIds) && updatedBooking.petIds[0]?.name
      ? updatedBooking.petIds[0].name : '';
    const providerDoc = providerRole === 'walker'
      ? updatedBooking.walkerId
      : updatedBooking.sitterId;
    const notifData = {
      bookingId: updatedBooking._id.toString(),
      petName,
      ownerName: updatedBooking.ownerId?.name || '',
      sitterName: providerDoc?.name || '',
    };
    Promise.allSettled([
      sendNotification({
        userId: ownerId,
        role: 'owner',
        type: 'BOOKING_MUTUALLY_ACCEPTED',
        data: { ...notifData, name: notifData.ownerName },
      }),
      providerId
        ? sendNotification({
            userId: providerId,
            role: providerRole || 'sitter',
            type: 'BOOKING_MUTUALLY_ACCEPTED',
            data: { ...notifData, name: notifData.sitterName },
          })
        : Promise.resolve(),
    ]).catch(() => {});

    // ── UX simplification (Sprint payment-flow) ────────────────────────────────
    // When the OWNER is the one agreeing, auto-create the Stripe PaymentIntent
    // and return its clientSecret in the same response, so the Flutter app can
    // open Stripe PaymentSheet immediately (no detour via "Reservations").
    // This is best-effort: any failure is swallowed so the agree response stays
    // successful and the owner can still pay via the legacy endpoint.
    let payment = null;
    if (userRole === 'owner') {
      try {
        payment = await _prepareOwnerPaymentForAgreedBooking(updatedBooking, ownerId, req.body || {});
      } catch (payErr) {
        logger.warn('[agreeToBooking] auto PaymentIntent creation failed, owner will need to retry via /create-payment-intent', payErr?.message || payErr);
        payment = { error: payErr?.message || 'payment_unavailable' };
      }
    }

    res.json({
      booking: sanitizeBooking(updatedBooking),
      message: 'Booking marked as agreed.' + (payment?.clientSecret ? ' Payment ready.' : ' Owner can now proceed with payment.'),
      payment, // null (not owner) | { clientSecret, paymentIntentId, amount, currency, ... } | { error }
    });
  } catch (error) {
    logger.error('Agree to booking error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid booking id.' });
    }
    res.status(500).json({ error: 'Unable to update booking. Please try again later.' });
  }
};

/**
 * Helper used by `agreeToBooking` when the OWNER is the acceptor: prepares
 * (reuses or creates) a Stripe PaymentIntent for the freshly agreed booking
 * and returns the data the mobile client needs to open Stripe PaymentSheet.
 *
 * Mirrors the core logic of `createBookingPaymentIntent` but without the
 * Express req/res coupling.  Throws on validation failure so the caller can
 * decide whether to surface the error to the client or degrade gracefully.
 *
 * @param {Object} booking   - populated Booking document (ownerId/sitterId/petIds populated)
 * @param {string} ownerId   - authenticated owner id
 * @param {Object} body      - the original req.body (for useLoyaltyCredit flag)
 * @returns {Promise<{paymentIntentId, clientSecret, amount, currency, commissionAmount, netSitterAmount, loyaltyDiscountApplied}>}
 */
const _prepareOwnerPaymentForAgreedBooking = async (booking, ownerId, body = {}) => {
  if (!booking.pricing || typeof booking.pricing.totalPrice !== 'number' || booking.pricing.totalPrice <= 0) {
    throw new Error('Booking is missing valid pricing information.');
  }
  // Session v17.1 — walker-aware provider resolution.
  const providerRef = getBookingProvider(booking);
  const sitter = providerRef.doc;
  if (!sitter) {
    throw new Error('Provider (sitter or walker) is missing on this booking.');
  }
  // v18.5 — #3 hold admin : on NE bloque PLUS le paiement si le provider n'a
  // pas encore configuré IBAN/PayPal. L'owner paye comme d'habitude, la
  // plateforme capture tout le montant, et si le provider n'est pas encore
  // configuré au moment du payout, booking.payoutStatus passe à 'held' (voir
  // schedulePayoutForBooking). Le scheduler débloque dès que le provider
  // configure IBAN ou PayPal.
  //
  // On garde les checks `hasIban/hasPaypal/hasStripeConnect` comme info
  // locale pour les logs — plus pour bloquer.
  const hasIban = !!(
    sitter.ibanNumber &&
    String(sitter.ibanNumber).trim().length > 0
  );
  const hasPaypal = !!(
    sitter.paypalEmail &&
    String(sitter.paypalEmail).trim().length > 0
  );
  const hasStripeConnect =
    sitter.stripeConnectAccountId &&
    sitter.stripeConnectAccountStatus === 'active';
  if (!hasIban && !hasPaypal && !hasStripeConnect) {
    logger.info(
      `[_prepareOwnerPaymentForAgreedBooking] Provider ${providerRef.type}:${sitter._id} has no payout method. Owner will pay; payout will be HELD until provider configures IBAN/PayPal.`
    );
  }

  // If a PaymentIntent already exists for this booking, return it (unless already paid).
  if (booking.stripePaymentIntentId) {
    const existing = await getPaymentIntent(booking.stripePaymentIntentId);
    if (existing.status === 'succeeded') {
      throw new Error('Payment already completed for this booking.');
    }
    return {
      paymentIntentId: existing.id,
      clientSecret: existing.client_secret,
      amount: existing.amount,
      currency: (existing.currency || 'eur').toUpperCase(),
      reused: true,
    };
  }

  const totalPrice = Number(booking.pricing.totalPrice);
  if (isNaN(totalPrice) || totalPrice <= 0) throw new Error('Invalid booking price.');

  const fallbackCurrency = countryToCurrency(sitter.country) || DEFAULT_CURRENCY;
  const bookingCurrency = assertSupportedCurrency(
    booking.pricing?.currency || fallbackCurrency,
    'Booking currency must be one of EUR/USD/GBP/CHF to create a payment.'
  );

  let loyaltyDiscountApplied = null;
  let effectiveTotal = totalPrice;
  if (body?.useLoyaltyCredit === true) {
    const discount = await consumeLoyaltyDiscount(ownerId, booking._id);
    if (discount.applied) {
      effectiveTotal = Math.max(0, totalPrice - discount.discountAmount);
      loyaltyDiscountApplied = discount;
    }
  }

  const amountInCents = Math.round(effectiveTotal * 100);
  if (isNaN(amountInCents) || amountInCents <= 0) throw new Error('Invalid payment amount.');

  // Session v18.0 — only pass connectedAccountId when Stripe Connect is
  // active. When it's not, createPaymentIntent falls back to a plain
  // platform charge and the payout is released by the scheduler later.
  //
  // Session v18.2 — attach to Stripe Customer for "Mes paiements" reuse.
  let ownerStripeCustomerId = null;
  try {
    const { getOrCreateStripeCustomerForOwner } = require('../services/stripeService');
    ownerStripeCustomerId = await getOrCreateStripeCustomerForOwner({
      ownerId: booking.ownerId._id.toString(),
      email: booking.ownerId.email,
      name: booking.ownerId.name,
    });
  } catch (custErr) {
    logger.warn('[_prepareOwnerPaymentForAgreedBooking] Stripe Customer create/find failed', custErr?.message || custErr);
  }

  const paymentIntent = await createPaymentIntent({
    amount: amountInCents,
    connectedAccountId: hasStripeConnect ? sitter.stripeConnectAccountId : null,
    bookingId: booking._id.toString(),
    ownerId: booking.ownerId._id.toString(),
    sitterId: providerRef.id,
    providerType: providerRef.type,
    currency: bookingCurrency.toLowerCase(),
    isTopSitter: sitter.isTopSitter === true || sitter.isTopWalker === true,
    stripeCustomerId: ownerStripeCustomerId,
  });

  booking.stripePaymentIntentId = paymentIntent.id;
  // Session v18.0 — only persist the connected account id when destination
  // charges are actually used. Otherwise leave it null so that
  // processProviderPayoutForBooking falls through to the IBAN / PayPal
  // branches at service-start time.
  booking.petsitterConnectedAccountId = hasStripeConnect
    ? sitter.stripeConnectAccountId
    : null;
  booking.paymentProvider = 'stripe';
  booking.paymentStatus = 'pending';
  await booking.save();

  // v18.9.8 — commission is paid by the owner ON TOP of the provider rate.
  // totalPrice already includes the 20% mark-up, so the application fee
  // (= platform cut) is the stored commission in cents. Loyalty discount
  // is absorbed by the platform so the provider still receives their
  // FULL advertised rate.
  const baseCommissionInCents = Math.round((booking.pricing?.commission || 0) * 100);
  const discountInCents = loyaltyDiscountApplied
    ? Math.round((loyaltyDiscountApplied.discountAmount || 0) * 100)
    : 0;
  const applicationFee = Math.max(0, baseCommissionInCents - discountInCents);
  const netSitter = amountInCents - applicationFee;

  return {
    paymentIntentId: paymentIntent.id,
    clientSecret: paymentIntent.client_secret,
    amount: amountInCents,
    currency: bookingCurrency,
    commissionAmount: applicationFee,
    netSitterAmount: netSitter,
    loyaltyDiscountApplied: loyaltyDiscountApplied
      ? { amount: loyaltyDiscountApplied.discountAmount, creditId: loyaltyDiscountApplied.creditId }
      : null,
  };
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

    const booking = await Booking.findById(id)
      .populate('ownerId')
      .populate('sitterId')
      .populate('walkerId') // Session v17 — walker bookings need this populated too
      .populate('petIds');
    if (!booking) {
      return res.status(404).json({ error: 'Booking not found.' });
    }

    // Verify owner owns this booking
    if (booking.ownerId._id.toString() !== ownerId) {
      return res.status(403).json({ error: 'You do not have permission to pay for this booking.' });
    }

    // v16.3i — accept both 'agreed' (owner accepted sitter application flow)
    // and 'accepted' (sitter/walker accepted owner's direct booking). The
    // previous check allowed only 'agreed', which blocked all direct-booking
    // payments after the provider had accepted.
    if (booking.status !== 'agreed' && booking.status !== 'accepted') {
      return res.status(400).json({
        error: `Payment can only be initiated for agreed or accepted bookings. Current status: ${booking.status}`
      });
    }

    // Validate that booking has required pricing information
    if (!booking.pricing || typeof booking.pricing.totalPrice !== 'number' || booking.pricing.totalPrice <= 0) {
      return res.status(400).json({
        error: 'This booking is missing valid pricing information. Please create a new booking with proper pricing details.'
      });
    }

    // Session v17 — resolve sitter OR walker via the unified helper.
    const providerRef = getBookingProvider(booking);
    const sitter = providerRef.doc;
    if (!sitter) {
      return res.status(404).json({ error: 'Provider not found on booking.' });
    }
    // v18.5 — #3 hold admin : on NE bloque PLUS le paiement si le provider
    // n'a pas encore configuré IBAN/PayPal. Le owner peut payer, la
    // plateforme capture tout (commission + netPayout), et
    // `schedulePayoutForBooking` placera le netPayout en `held` si le
    // provider n'a rien configuré. Dès qu'il ajoute IBAN ou PayPal, le
    // scheduler envoie le held amount.
    //
    // On garde les variables hasIban/hasPaypal/hasStripeConnect juste pour
    // logs informatifs.
    const hasIban = !!(sitter.ibanNumber && String(sitter.ibanNumber).trim().length > 0);
    const hasPaypal = !!(sitter.paypalEmail && String(sitter.paypalEmail).trim().length > 0);
    const hasStripeConnect =
      sitter.stripeConnectAccountId &&
      sitter.stripeConnectAccountStatus === 'active';
    if (!hasIban && !hasPaypal && !hasStripeConnect) {
      logger.info(
        `[createBookingPaymentIntent] Provider ${providerRef.type}:${sitter._id} has no payout method. Owner will pay; payout will be HELD until provider configures IBAN/PayPal.`
      );
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

    // Validate and normalize booking currency for payment.
    // Fallback chain: booking.pricing.currency -> sitter.country-derived -> DEFAULT.
    const fallbackCurrency = countryToCurrency(sitter.country) || DEFAULT_CURRENCY;
    const bookingCurrency = assertSupportedCurrency(
      booking.pricing?.currency || fallbackCurrency,
      'Booking currency must be one of EUR/USD/GBP/CHF to create a payment.'
    );

    // Sprint 7 step 1 — apply loyalty discount if opted-in.
    let loyaltyDiscountApplied = null;
    let effectiveTotal = totalPrice;
    if (req.body?.useLoyaltyCredit === true) {
      const discount = await consumeLoyaltyDiscount(ownerId, booking._id);
      if (discount.applied) {
        effectiveTotal = Math.max(0, totalPrice - discount.discountAmount);
        loyaltyDiscountApplied = discount;
      }
    }
    const amountInCents = Math.round(effectiveTotal * 100);
    
    if (isNaN(amountInCents) || amountInCents <= 0) {
      return res.status(400).json({ 
        error: 'Invalid payment amount. Please check the booking pricing.' 
      });
    }

    // Session v18.0 — use Stripe Connect destination charge ONLY when the
    // provider has finished their Connect onboarding. Otherwise fall back
    // to a plain platform charge and let payoutScheduler release the 80%
    // via the provider's IBAN or PayPal at service-start.
    //
    // Session v18.2 — attach the charge to the owner's Stripe Customer so
    // the card ends up in "Mes paiements" automatically.
    let ownerStripeCustomerId = null;
    try {
      const { getOrCreateStripeCustomerForOwner } = require('../services/stripeService');
      ownerStripeCustomerId = await getOrCreateStripeCustomerForOwner({
        ownerId: booking.ownerId._id.toString(),
        email: booking.ownerId.email,
        name: booking.ownerId.name,
      });
    } catch (custErr) {
      logger.warn('[createBookingPaymentIntent] Stripe Customer create/find failed, charge will not be attached', custErr?.message || custErr);
    }

    const paymentIntent = await createPaymentIntent({
      amount: amountInCents,
      connectedAccountId: hasStripeConnect ? sitter.stripeConnectAccountId : null,
      bookingId: booking._id.toString(),
      ownerId: booking.ownerId._id.toString(),
      sitterId: providerRef.id,
      providerType: providerRef.type,
      currency: bookingCurrency.toLowerCase(),
      isTopSitter: sitter.isTopSitter === true || sitter.isTopWalker === true,
      stripeCustomerId: ownerStripeCustomerId,
    });

    // Save PaymentIntent ID and (conditionally) connected account ID.
    booking.stripePaymentIntentId = paymentIntent.id;
    booking.petsitterConnectedAccountId = hasStripeConnect
      ? sitter.stripeConnectAccountId
      : null;
    booking.paymentProvider = 'stripe';
    booking.paymentStatus = 'pending';
    await booking.save();

    // v18.9.8 — see _prepareOwnerPaymentForAgreedBooking. The commission is
    // paid ON TOP by the owner and stored in booking.pricing.commission.
    // Loyalty discount is absorbed by the platform (provider keeps full
    // advertised rate).
    const baseCommissionInCents = Math.round((booking.pricing?.commission || 0) * 100);
    const discountInCents = loyaltyDiscountApplied
      ? Math.round((loyaltyDiscountApplied.discountAmount || 0) * 100)
      : 0;
    const applicationFee = Math.max(0, baseCommissionInCents - discountInCents);
    const netSitter = amountInCents - applicationFee;

    res.json({
      paymentIntentId: paymentIntent.id,
      clientSecret: paymentIntent.client_secret,
      amount: amountInCents,
      currency: bookingCurrency,
      commissionAmount: applicationFee,
      netSitterAmount: netSitter,
      loyaltyDiscountApplied: loyaltyDiscountApplied
        ? {
            amount: loyaltyDiscountApplied.discountAmount,
            creditId: loyaltyDiscountApplied.creditId,
          }
        : null,
      booking: sanitizeBooking(booking),
      message: 'PaymentIntent created successfully. Use clientSecret with Stripe Payment Sheet.',
    });
  } catch (error) {
    logger.error('Create payment intent error', error);
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

    // v18.6 — PayPal walker support : populate walkerId aussi.
    const booking = await Booking.findById(id)
      .populate('ownerId')
      .populate('sitterId')
      .populate('walkerId')
      .populate('petIds');
    if (!booking) {
      return res.status(404).json({ error: 'Booking not found.' });
    }

    // Verify owner owns this booking
    if (booking.ownerId._id.toString() !== ownerId) {
      return res.status(403).json({ error: 'You do not have permission to pay for this booking.' });
    }

    // v16.3i — accept both 'agreed' and 'accepted' so direct-booking owner
    // can pay after sitter/walker accepted. See companion fix above.
    if (booking.status !== 'agreed' && booking.status !== 'accepted') {
      return res.status(400).json({
        error: `Payment can only be initiated for agreed or accepted bookings. Current status: ${booking.status}`,
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
        logger.error('Error fetching existing PayPal order, creating a new one instead:', err);
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
    logger.error('Create PayPal order error', error);
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

    const booking = await Booking.findById(id)
      .populate('ownerId')
      .populate('sitterId')
      .populate('walkerId') // Session v17 — walker bookings need this populated too
      .populate('petIds');
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
    if (!booking.stripePaymentIntentId) {
      booking.stripePaymentIntentId = paymentIntentId;
      await booking.save();
    }

    // v18.7 — FALLBACK quand le webhook Stripe n'arrive pas / est en retard.
    // On marque la booking comme paid IMMEDIATEMENT si Stripe confirme
    // succeeded, ET on déclenche le chat unlock. Le webhook fera la même
    // chose en idempotent si/quand il arrive (guard status déjà 'paid').
    if (
      confirmedPaymentIntent.status === 'succeeded' &&
      booking.status !== 'paid'
    ) {
      try {
        booking.status = 'paid';
        booking.paymentStatus = 'paid';
        booking.paidAt = new Date();
        booking.paymentProvider = 'stripe';
        if (confirmedPaymentIntent.latest_charge) {
          booking.stripeChargeId =
            typeof confirmedPaymentIntent.latest_charge === 'string'
              ? confirmedPaymentIntent.latest_charge
              : confirmedPaymentIntent.latest_charge.id;
        }
        await booking.save();
        logger.info(
          `[confirmBookingPayment] Booking ${booking._id} marked as PAID via client-confirm fallback (webhook race-proof).`
        );

        // Schedule payout + unlock chat + send notifications — same as webhook.
        await schedulePayoutForBooking(booking);

        const providerId = booking.walkerId
          ? (booking.walkerId.toString?.() || String(booking.walkerId))
          : (booking.sitterId?.toString?.() || String(booking.sitterId));
        const providerRole = booking.walkerId ? 'walker' : 'sitter';

        // Load the webhook helper lazily (it's a controller-local function).
        const stripeWebhookController = require('./stripeWebhookController');
        if (typeof stripeWebhookController._unlockChatAndWelcome === 'function') {
          await stripeWebhookController._unlockChatAndWelcome({
            ownerId:
              booking.ownerId?.toString?.() || String(booking.ownerId),
            providerId,
            providerRole,
            bookingId: booking._id.toString(),
          });
        }
      } catch (fallbackErr) {
        logger.error(
          '[confirmBookingPayment] client-confirm fallback failed (non-blocking)',
          fallbackErr?.message || fallbackErr
        );
      }
    }

    // Return payment intent status
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
    logger.error('Confirm payment error', error);
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
        logger.warn('Unable to parse PayPal capture ID from captured order:', parseError);
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
    logger.error('Capture PayPal order error', error);
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
      // v16.3i — Align with GET /bookings/my. Accept both 'agreed' and 'accepted'.
      canPay: (booking.status === 'agreed' || booking.status === 'accepted') && userId === ownerId,
      createdAt: sanitized.createdAt,
      updatedAt: sanitized.updatedAt,
    };

    res.json({ agreement });
  } catch (error) {
    logger.error('Get booking agreement error', error);
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
          logger.error('Error retrieving payment intent for charge ID:', error);
        }
      } else if (booking.stripePaymentIntentId) {
        // Check payment intent status even if we have charge ID
        try {
          const paymentIntent = await getPaymentIntent(booking.stripePaymentIntentId);
          paymentIntentStatus = paymentIntent.status;
        } catch (error) {
          logger.error('Error retrieving payment intent status:', error);
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
          logger.info(`✅ Refund processed for booking ${booking._id}: ${refund.id}`);
        } catch (refundError) {
          logger.error('Refund error:', refundError);
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
        logger.warn(`⚠️ Booking ${booking._id} cancelled but no charge ID available. Payment Intent Status: ${paymentIntentStatus || 'unknown'}`);
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
    logger.error('Request cancellation error', error);
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

    const booking = await Booking.findById(id)
      .populate('ownerId')
      .populate('sitterId')
      .populate('walkerId') // Session v17 — walker bookings need this populated too
      .populate('petIds');
    if (!booking) {
      return res.status(404).json({ error: 'Booking not found.' });
    }

    // Verify user has permission (owner or sitter/walker provider).
    const ownerId = booking.ownerId._id.toString();
    const providerRef = getBookingProvider(booking);
    const providerId = providerRef.id;

    if (userId !== ownerId && userId !== providerId) {
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
        logger.error('Error fetching payment intent:', error);
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
        logger.error('Error fetching PayPal order:', error);
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
      canRetryPayment: booking.status === 'payment_failed' || booking.status === 'agreed' || booking.status === 'accepted',
      message: booking.status === 'paid' 
        ? 'Payment completed successfully.'
        : booking.status === 'payment_failed'
        ? 'Payment failed. You can retry payment.'
        : booking.status === 'agreed'
        ? 'Payment not yet initiated.'
        : 'Payment status unknown.',
    });
  } catch (error) {
    logger.error('Get payment status error', error);
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

    const booking = await Booking.findById(id)
      .populate('ownerId')
      .populate('sitterId')
      .populate('walkerId') // Session v17 — walker bookings need this populated too
      .populate('petIds');
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

    await processProviderPayoutForBooking(booking);

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
    logger.error('Retry payout error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid booking id.' });
    }
    res.status(500).json({ error: 'Unable to retry payout. Please try again later.' });
  }
};


/**
 * processScheduledSitterPayouts — called by the background scheduler.
 * Session v17 — granularity is now hour-exact (was day-exact). Query uses
 * { $lte: now } so any booking whose scheduledPayoutAt has passed is
 * released on the next scheduler tick (every 5 minutes). Both walker and
 * sitter bookings are released; processProviderPayoutForBooking handles
 * both via getBookingProvider().
 */
const processScheduledSitterPayouts = async () => {
  const now = new Date();

  const dueBookings = await Booking.find({
    payoutStatus: 'scheduled',
    scheduledPayoutAt: { $lte: now },
  })
    .populate('ownerId')
    .populate('sitterId')
    .populate('walkerId')
    .populate('petIds');

  if (!dueBookings.length) return { released: 0 };

  let released = 0;
  for (const booking of dueBookings) {
    try {
      await processProviderPayoutForBooking(booking);
      released += 1;
    } catch (err) {
      logger.error(`⚠️  processScheduledSitterPayouts: failed for booking ${booking._id}`, err);
    }
  }
  logger.info(`💸 processScheduledSitterPayouts: released ${released} payout(s).`);
  return { released };
};


/**
 * v18.5 — #3 hold admin : scan toutes les bookings marquées `held` et
 * recheck si le provider a depuis ajouté un IBAN ou un PayPal. Si oui,
 * on bascule la booking en `scheduled` (qui sera traitée par le prochain
 * tick de processScheduledSitterPayouts) ou on la release direct si la
 * date de service est déjà passée. Idempotent.
 *
 * Appelé à chaque tick du scheduler (toutes les 5 minutes via
 * startPayoutScheduler dans payoutScheduler.js).
 */
const processHeldPayouts = async () => {
  const heldBookings = await Booking.find({
    payoutStatus: 'held',
    paymentStatus: 'paid',
  })
    .populate('ownerId')
    .populate('sitterId')
    .populate('walkerId')
    .populate('petIds');

  if (!heldBookings.length) return { released: 0, stillHeld: 0 };

  let released = 0;
  let stillHeld = 0;
  for (const booking of heldBookings) {
    try {
      const provider = getBookingProvider(booking);
      if (!provider.doc) {
        stillHeld += 1;
        continue;
      }
      const doc = provider.doc;
      const hasIban = !!(
        doc.ibanNumber && String(doc.ibanNumber).trim().length > 0
      );
      const hasPaypal = !!(
        doc.paypalEmail && String(doc.paypalEmail).trim().length > 0
      );
      const hasStripeConnectActive =
        doc.stripeConnectAccountId &&
        doc.stripeConnectAccountStatus === 'active';

      if (!hasIban && !hasPaypal && !hasStripeConnectActive) {
        // Still nothing configured — leave held, next tick will retry.
        stillHeld += 1;
        continue;
      }

      // Provider has configured something. Mark released and trigger
      // processProviderPayoutForBooking which will pick the right method.
      booking.heldReleasedAt = new Date();
      // Reset to pending so processProviderPayoutForBooking enters the
      // actual transfer path instead of re-marking held.
      booking.payoutStatus = 'pending';
      await booking.save();
      logger.info(
        `🔓 HELD payout released for booking ${booking._id.toString()} — provider ${provider.type}:${doc._id} just configured payout. Processing transfer now.`
      );
      await processProviderPayoutForBooking(booking);
      released += 1;
    } catch (err) {
      logger.error(
        `⚠️  processHeldPayouts: failed for booking ${booking._id}`,
        err
      );
      stillHeld += 1;
    }
  }
  logger.info(
    `⏸️  processHeldPayouts: released=${released}, stillHeld=${stillHeld}`
  );
  return { released, stillHeld };
};


// Sprint 7 step 1 — mark a paid booking as completed (owner action) and fire loyalty hooks.
const completeBooking = async (req, res) => {
  try {
    const { id } = req.params;
    const booking = await Booking.findById(id);
    if (!booking) return res.status(404).json({ error: 'Booking not found.' });
    if (String(booking.ownerId) !== req.user.id) {
      return res.status(403).json({ error: 'Only the owner can mark this booking as completed.' });
    }
    if (booking.paymentStatus !== 'paid') {
      return res.status(400).json({ error: 'Booking must be paid before completion.' });
    }
    if (booking.status === 'completed') {
      return res.json({ booking: sanitizeBooking(booking), alreadyCompleted: true });
    }
    booking.status = 'completed';
    await booking.save();
    try {
      await onBookingCompleted(booking);
    } catch (e) {
      logger.warn('loyalty hook failed', e.message);
    }
    return res.json({ booking: sanitizeBooking(booking) });
  } catch (e) {
    logger.error('completeBooking error', e);
    return res.status(500).json({ error: 'Unable to complete booking.' });
  }
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
  // v18.5 — #3 hold admin : released en background quand provider config
  // son IBAN/PayPal.
  processHeldPayouts,
  completeBooking,
  // Session v17 — payout helper now supports walker too. Renamed from
  // processSitterPayoutForBooking. The legacy export below keeps existing
  // call sites (e.g. adminRoutes.js) working without modification.
  processProviderPayoutForBooking,
  processSitterPayoutForBooking: processProviderPayoutForBooking,
  // Shared helper — used by applicationController to offer the owner an
  // immediate Stripe PaymentSheet right after accepting an application.
  _prepareOwnerPaymentForAgreedBooking,
};

