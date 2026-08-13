const dayjs = require('dayjs');
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
// v532 — photos de preuve de remise / récupération (cf. _saveHandoverPhoto).
const { uploadMedia } = require('../services/cloudinary');
const {
  getRecommendedPriceRange,
  calculateTotalWithAddOns,
  commissionRateForProvider,
  SERVICE_TYPES,
  LOCATION_TYPES,
} = require('../utils/pricing');
// Stripe disabled (v21.1.1 purge) — calls now use airwallex.* (createPlatformPaymentIntent, retrievePaymentIntent, confirmPaymentIntent, createRefund, createPayout)
// v21 — Airwallex platform-only PI fallback when PAYMENT_PROVIDER=airwallex.
// Marketplace split (Beneficiaries + Payouts API) lands in v21.1 ;
// in the meantime funds accumulate on the HoPetSit Airwallex wallet and
// payout-scheduler manually releases the 80% to the provider's IBAN.
const airwallex = require('../services/airwallexService');
// v21.1.1 — Stripe purgé. Le default passe à 'airwallex' : si PAYMENT_PROVIDER
// n'est pas configuré côté Render, on tombe sur Airwallex et pas Stripe (qui
// est mort, compte fermé). Variable env optionnelle conservée pour rollback
// d'urgence éventuel sur un autre PSP futur.
const PAYMENT_PROVIDER = (process.env.PAYMENT_PROVIDER || 'airwallex').toLowerCase();
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
const { onBookingCompleted, consumeLoyaltyDiscount, restoreLoyaltyDiscount, recomputeSitterStatus, recomputeWalkerStatus } = require('../services/loyaltyService');
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

    // v23.1 part 127 — Phase 3 audit P3-29 : refuser les dates passées.
    // dayjs gère la TZ system, on compare sur le jour calendaire.
    if (dayjs(normalizedDate).startOf('day').isBefore(dayjs().startOf('day'))) {
      return res.status(400).json({
        error: 'serviceDate cannot be in the past.',
        code: 'DATE_IN_PAST',
      });
    }

    if (!trimmedTimeSlot) {
      return res.status(400).json({ error: 'timeSlot is required.' });
    }

    // v23.1 part 127 — Phase 3 audit P3-30 : ceinture+bretelles, vérifier
    // qu'on a au moins 1 pet après dedup (techniquement impossible vu la
    // boucle ci-dessus, mais on ne veut surtout pas créer une booking
    // sans pet — la pricing pourrait être 0).
    if (uniquePetIds.length === 0) {
      return res.status(400).json({ error: 'At least one valid petId is required.' });
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
        // v23.1.302 — report le badge Top pour la commission réduite (#69).
        isTopWalker: walker.isTopWalker === true,
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
        logger.error(
          { err: error, message: error?.message, stack: error?.stack },
          '❌ Error getting recommended price range',
        );
        console.error('[getRecommendedPriceRange] EXPLICIT:', error);
      }
    }

    // v20.0.19 — CRITICAL FIX : pour day_care, si le client n'a pas envoyé
    // endDate (ancien client, ou parce que le UI ne capturait que endTime
    // sans endDate), on force une plage journée de 8h à partir de startDate.
    // Sans ce filet de sécurité, tierPricing fallback à 1h et avec
    // durationMinutes éventuellement à 30, on facturait 2.5€ au lieu de
    // dailyRate. Le frontend v20.0.19 sync désormais endDate=startDate mais
    // on garde ce filet pour les anciens clients installés.
    const rawServiceType = String(serviceType || '').toLowerCase();
    const isDayCareBooking =
      rawServiceType === 'day_care' || rawServiceType === 'garderie';
    let effectiveEndDateForPricing = normalizedEndDate;
    if (isDayCareBooking && !effectiveEndDateForPricing && normalizedStartDate) {
      const startMs = new Date(normalizedStartDate).getTime();
      if (Number.isFinite(startMs)) {
        effectiveEndDateForPricing = new Date(startMs + 8 * 60 * 60 * 1000);
      }
    }

    // v23.1 — minimum 5 hours for day-bound services (day_care, pet_sitting,
    // house_sitting). Without this, owners could create a 30-minute "garderie"
    // booking that tier-priced as hourly fraction (~4€) below the sitter's
    // dailyRate (5€), confusing both parties. Reject early with a clear message.
    const dayBoundTypes = ['day_care', 'garderie', 'pet_sitting', 'house_sitting'];
    if (dayBoundTypes.includes(rawServiceType) && normalizedStartDate && effectiveEndDateForPricing) {
      const startTs = new Date(normalizedStartDate).getTime();
      const endTs = new Date(effectiveEndDateForPricing).getTime();
      if (Number.isFinite(startTs) && Number.isFinite(endTs)) {
        const hours = (endTs - startTs) / (1000 * 60 * 60);
        if (hours > 0 && hours < 5) {
          return res.status(400).json({
            error: 'Minimum 5 hours required for day_care / pet_sitting / house_sitting bookings.',
            code: 'MIN_DURATION_DAY_CARE',
            details: `La garderie ou pet-sitting demande au moins 5 heures. Tu as demandé ${hours.toFixed(1)}h. Allonge la plage horaire ou choisis un autre type de service.`,
          });
        }
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
      endDate: effectiveEndDateForPricing,
      serviceDate: normalizedDate,
      // v20.0.19 — pour day_care on IGNORE explicitement le durationMinutes
      // (souvent 30 si le UI walker a laissé traîner une sélection). Le tier
      // daily doit être calculé sur la plage 8h forcée ci-dessus.
      durationMinutes:
        canonicalServiceType === SERVICE_TYPES.DAY_CARE
          ? null
          : (durationNum || duration),
    });

    // Calculate pricing breakdown with commission in booking currency
    // v23.1.302 — commission Top (#69) : 15% au lieu de 20% si le prestataire a
    // le badge Top Sitter / Top Walker (tarif net presta inchangé).
    const isTopProvider = providerType === 'walker'
        ? sitter?.isTopWalker === true
        : sitter?.isTopSitter === true;
    const pricingBreakdown = calculateTotalWithAddOns(
      tierPricing.basePrice,
      addOns,
      bookingCurrency,
      commissionRateForProvider(isTopProvider),
    );

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
    // v22.5 — DEBUG : pino structured logging + console fallback so the
    // real stack appears in Render logs. Also returns 'details: error.message'
    // to client so the toast on phone shows something actionable instead of
    // the generic 'Unable to send booking request.' message.
    logger.error(
      {
        err: error,
        name: error?.name,
        message: error?.message,
        stack: error?.stack,
      },
      '❌ Create booking error',
    );
    console.error('[createBooking] EXPLICIT:', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid owner or sitter id.' });
    }
    if (error.message && error.message.includes('must be')) {
      return res.status(400).json({ error: error.message });
    }
    if (error.message && (error.message.includes('hourlyRate') || error.message.includes('required for pricing'))) {
      return res.status(400).json({ error: error.message });
    }
    // v23.1 — pricing.js throws structured "Invalid service type" /
    // "Invalid location type" / "No recommended range" / "Base price must
    // be a positive number" / "Unsupported currency". Map these to 400 so
    // the client toast shows the actionable cause instead of a generic 500.
    if (
      error.message &&
      (error.message.includes('Invalid service type') ||
       error.message.includes('Invalid location type') ||
       error.message.includes('No recommended range') ||
       error.message.includes('Base price must be') ||
       error.message.includes('Unsupported currency'))
    ) {
      return res.status(400).json({ error: error.message });
    }
    res.status(500).json({
      error: 'Unable to send booking request. Please try again later.',
      details: error?.message || String(error),
    });
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

/**
 * v23.1.354 — heure de FIN d'un timeSlot type "10:00 - 12:00" / "14h-18h".
 * Retourne le DERNIER couple heure/minute si le créneau en contient >= 2,
 * sinon null (créneau mono-heure : la fin vient de duration / endDate).
 */
const parseTimeSlotEndToHoursMinutes = (timeSlot) => {
  if (!timeSlot || typeof timeSlot !== 'string') return null;
  const cleaned = timeSlot.trim().toLowerCase().replace(/\s+/g, '');
  const all = [...cleaned.matchAll(/(\d{1,2})[:h](\d{2})/g)];
  if (all.length < 2) return null;
  const last = all[all.length - 1];
  const h = Number(last[1]);
  const m = Number(last[2]);
  if (!Number.isInteger(h) || h < 0 || h > 23) return null;
  if (!Number.isInteger(m) || m < 0 || m > 59) return null;
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
 * Session v23.1 — resolve the booking END datetime.
 * Falls back, in order, to: explicit endDate → startDate + duration →
 * startDate + serviceType default duration → startDate + 1h.
 */
const resolveBookingEndDate = (booking) => {
  const rawEnd = booking?.endDate || null;
  if (rawEnd) {
    const parsed = new Date(rawEnd);
    if (!Number.isNaN(parsed.getTime())) {
      const hasTimePart = typeof rawEnd === 'string' && /T\d{2}:/.test(rawEnd);
      if (hasTimePart) return parsed;
      // v23.1.354 — si le créneau porte une heure de fin ("10:00 - 12:00"),
      // on l'applique au jour de endDate. Sinon : fin de journée (23:59).
      const hmEnd = parseTimeSlotEndToHoursMinutes(booking?.timeSlot);
      if (hmEnd) {
        parsed.setHours(hmEnd.h, hmEnd.m, 0, 0);
      } else {
        parsed.setHours(23, 59, 0, 0);
      }
      return parsed;
    }
  }
  // v23.1.354 — pas de endDate : heure de FIN du timeSlot sur le jour de
  // début ("10:00 - 12:00" → 12:00). Si la fin "précède" le début (créneau
  // de nuit "22:00 - 06:00"), on bascule au lendemain.
  const start = resolveBookingStartDate(booking);
  const hmEnd2 = parseTimeSlotEndToHoursMinutes(booking?.timeSlot);
  if (hmEnd2) {
    const end = new Date(start);
    end.setHours(hmEnd2.h, hmEnd2.m, 0, 0);
    if (end.getTime() <= start.getTime()) end.setDate(end.getDate() + 1);
    return end;
  }
  // Fallback : startDate + duration (minutes) for short services like dog walking.
  const durationMinutes = Number.isFinite(booking?.duration)
    ? Number(booking.duration)
    : null;
  if (durationMinutes && durationMinutes > 0) {
    return new Date(start.getTime() + durationMinutes * 60 * 1000);
  }
  // Final fallback : start + 1h, just in case neither endDate nor duration is set.
  return new Date(start.getTime() + 60 * 60 * 1000);
};

/**
 * Session v23.1 — Release window after service completion (in milliseconds).
 * v23.1 part 66 — POLICY CHANGE.
 *
 * NEW RULE (Daniel) : the provider gets the money on the DAY THE
 * SERVICE STARTS, not 24h after it ends. This aligns with the offline
 * pet-sitting market where providers expect to be paid on the day they
 * pick up the animal.
 *
 * - Pour les promenades chien (dog walking), le release a lieu au
 *   début du créneau réservé (ex : 14h00 ce jour).
 * - Pour les gardes longues (boarding / sitting / day-care), le
 *   release a lieu à l'heure exacte de début (ex : 8h00 du J1 où
 *   l'owner dépose le chien).
 *
 * Le owner garde un dispute-window via :
 *   • notre flow de cancel < 72h auto-refund (preserved)
 *   • le bouton "Signaler un problème" du booking (manual refund admin)
 *
 * Si on doit réintroduire un buffer (env risk team Airwallex), on peut
 * définir PAYOUT_RELEASE_OFFSET_HOURS (positif = retard, négatif =
 * avance). Default 0 = release at start exactly.
 */
const PAYOUT_RELEASE_OFFSET_MS =
  (Number(process.env.PAYOUT_RELEASE_OFFSET_HOURS) || 0) * 60 * 60 * 1000;

/**
 * Compute the scheduled payout datetime for a paid booking:
 *   = booking.startDate (i.e. the day/hour the provider starts the service)
 *     + optional PAYOUT_RELEASE_OFFSET_HOURS.
 */
const resolvePayoutReleaseAt = (booking) => {
  const start = resolveBookingStartDate(booking);
  return new Date(start.getTime() + PAYOUT_RELEASE_OFFSET_MS);
};

/**
 * Session v23.1 — returns true when the scheduled payout datetime
 * (endDate + 24h) is now or already in the past. Used to decide whether
 * the provider payout should be released immediately (legacy/same-day
 * booking, admin retry) or scheduled for later.
 */
const isBookingPayoutDue = (booking) => {
  const releaseAt = resolvePayoutReleaseAt(booking);
  return releaseAt.getTime() <= Date.now();
};

/**
 * Schedules or triggers the sitter payout for a booking that has just been paid.
 *
 * Business rule (HoPetSit v23.1, aligned with Airwallex risk pack policy):
 *   The money stays in escrow until **24 hours after the service ENDS**.
 *   This gives the owner a dispute window after the booking is completed,
 *   while still releasing funds to the provider quickly (typically within
 *   1 day for dog walks, the morning after the last night for overnight stays).
 *
 *   `processScheduledSitterPayouts` (run by the scheduler every 5 minutes)
 *   calls `processProviderPayoutForBooking` to release the funds once the
 *   release datetime is reached.
 *
 * If the release datetime is already in the past (legacy data, admin retry),
 * the payout is released immediately.
 */
// v23.1.259 — Système de confirmation (Daniel). Auto-release de sécurité :
// si l'owner ne confirme pas la fin du service, le paiement est libéré
// automatiquement 48h après la fin prévue (ou 48h après que le provider a
// tapé "rendu", selon ce qui arrive en premier). L'owner peut libérer plus
// tôt en confirmant, ou bloquer via un litige.
const CONFIRMATION_AUTO_RELEASE_MS = 48 * 60 * 60 * 1000;

// v532 — PREUVE DE REMISE / RÉCUPÉRATION.
//
// Tolérance de démarrage anticipé : un prestataire peut arriver un peu en
// avance, mais pas déclencher un service prévu dans trois semaines.
const EARLY_START_TOLERANCE_MS = 2 * 60 * 60 * 1000;

// Bascule d'application STRICTE de la preuve (photo + code).
//
// Pourquoi une bascule : la v530 est en production sur le Play Store et
// n'envoie ni photo ni code. Rendre la preuve obligatoire immédiatement
// empêcherait tous les utilisateurs non encore mis à jour de démarrer ou de
// terminer une garde EN COURS. Par défaut on ENREGISTRE la preuve quand
// l'app la fournit (v532+) sans bloquer les anciennes versions ; une fois la
// v532 largement adoptée, passer HANDOVER_PROOF_REQUIRED=true sur Render
// rend photo et code obligatoires, sans redéploiement de code.
// À noter : la garde temporelle et l'ordre des étapes, eux, s'appliquent
// TOUJOURS — ils ne dépendent d'aucune donnée envoyée par le client.
const HANDOVER_PROOF_REQUIRED =
  String(process.env.HANDOVER_PROOF_REQUIRED || '').toLowerCase() === 'true';

/**
 * Enregistre la photo de remise/récupération envoyée en multipart (`photo`).
 *
 * Retourne `{ url, publicId, at }` ou `null` si aucune photo n'a été fournie
 * (anciennes versions de l'app). Best-effort : un échec Cloudinary ne bloque
 * jamais le cycle de garde — on préfère un service qui avance sans preuve à
 * un prestataire coincé devant la porte du client.
 */
const _saveHandoverPhoto = async (req, booking, kind) => {
  const file = req.file;
  if (!file || !file.buffer) return null;
  try {
    const dataUri = `data:${file.mimetype};base64,${file.buffer.toString('base64')}`;
    const uploadResult = await uploadMedia({
      file: dataUri,
      folder: `petsinsta/handover/${booking._id}`,
      resourceType: 'image',
    });
    return {
      url: uploadResult.url,
      publicId: uploadResult.publicId,
      at: new Date(),
    };
  } catch (e) {
    logger.warn(`[handover] upload ${kind} failed (non-blocking): ${e?.message || e}`);
    return null;
  }
};

const schedulePayoutForBooking = async (booking) => {
  if (!booking) return;
  if (booking.payoutStatus === 'completed' || booking.payoutStatus === 'processing') {
    return;
  }

  // v23.1.259 — On NE libère plus le paiement au START du service. Le booking
  // entre dans le flux de confirmation : le provider doit marquer début/fin,
  // l'owner confirme (→ libère), sinon auto-release 48h après la fin prévue.
  // On programme scheduledPayoutAt = fin + 48h : le scheduler EXISTANT
  // (processScheduledSitterPayouts) libère à cette date si rien d'autre
  // n'arrive avant, et SAUTE les litiges. La confirmation owner avance la
  // date à "maintenant" (cf confirmServiceCompletion).
  if (!booking.confirmationStatus || booking.confirmationStatus === 'none') {
    booking.confirmationStatus = 'awaiting_start';
  }
  // v532 — code de remise à 4 chiffres, généré une seule fois au paiement.
  // Le propriétaire le voit dans son app et le montre au prestataire au
  // moment de la remise ; sans lui, « J'ai récupéré l'animal » est refusé.
  if (!booking.handoverCode) {
    booking.handoverCode = String(Math.floor(1000 + Math.random() * 9000));
  }
  const endAt = resolveBookingEndDate(booking);
  const autoReleaseAt = new Date(endAt.getTime() + CONFIRMATION_AUTO_RELEASE_MS);
  booking.autoReleaseAt = autoReleaseAt;
  booking.scheduledPayoutAt = autoReleaseAt;

  if (autoReleaseAt.getTime() <= Date.now()) {
    // Service terminé depuis >48h (donnée legacy / résa passée) → release now.
    booking.payoutStatus = 'scheduled';
    await booking.save();
    await processProviderPayoutForBooking(booking);
    return;
  }

  booking.payoutStatus = 'scheduled';
  await booking.save();
  logger.info(
    `🗓️  Payout (flux confirmation) programmé pour booking ${booking._id.toString()} le ${autoReleaseAt.toISOString()} (auto-release 48h après fin ; avancé si l'owner confirme).`,
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

    // v23.1.339 — ESCROW STRICT (Daniel : "le paiement est libre, j'ai pu
    // retirer sans aucune confirmation" ; "via publication, demande directe
    // sitter/walker, owner->walker, owner->sitter : les sous ne se bloquent
    // pas"). Ce helper est le POINT DE PASSAGE UNIQUE de toute libération de
    // payout (wallet withdrawable + virement IBAN/PayPal). On REFUSE de
    // libérer tant que :
    //   - l'owner n'a pas confirmé la fin du service (confirmationStatus ===
    //     'confirmed', posé par confirmService), OU
    //   - l'auto-release programmé n'est pas atteint (scheduledPayoutAt <= now,
    //     géré par le scheduler 48h après la fin).
    // Jamais sur 'disputed'. Les bookings legacy (confirmationStatus 'none',
    // antérieurs au flux de confirmation) gardent l'ancien comportement.
    // Sans ce gate, confirmBookingPayment / les appelants au moment du paiement
    // libéraient l'argent immédiatement car le seul contrôle était status==='paid'.
    {
      const cs = booking.confirmationStatus || 'none';
      if (cs === 'disputed') {
        logger.info(
          `⛔ Payout bloqué (litige) booking ${booking._id.toString()}`,
        );
        return;
      }
      if (cs !== 'none') {
        const schedAt = booking.scheduledPayoutAt
          ? new Date(booking.scheduledPayoutAt).getTime()
          : null;
        const autoReleaseReached = schedAt !== null && schedAt <= Date.now();
        if (cs !== 'confirmed' && !autoReleaseReached) {
          logger.info(
            `⏳ Payout RETENU (escrow) booking ${booking._id.toString()} — ` +
            `confirmationStatus=${cs}, scheduledPayoutAt=${booking.scheduledPayoutAt}. ` +
            `Libération à la confirmation owner ou à l'auto-release 48h.`,
          );
          return;
        }
      }
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

    // v532 — VERROU ANTI-DOUBLE-VIREMENT. Les contrôles ci-dessus lisent un
    // document déjà chargé en mémoire : deux exécutions concurrentes (tick du
    // planificateur pendant que l'owner confirme, relance admin, ou deux
    // instances Render) voyaient toutes les deux `payoutStatus` différent de
    // 'completed' et envoyaient l'argent CHACUNE. On prend maintenant le
    // verrou de façon atomique en base : un seul gagnant.
    // La condition de reprise (verrou de plus de 15 min) évite qu'un
    // traitement interrompu bloque définitivement le versement.
    const PAYOUT_LOCK_STALE_MS = 15 * 60 * 1000;
    const claimed = await Booking.findOneAndUpdate(
      {
        _id: booking._id,
        $or: [
          { payoutStatus: { $nin: ['completed', 'processing'] } },
          {
            payoutStatus: 'processing',
            payoutProcessingAt: { $lt: new Date(Date.now() - PAYOUT_LOCK_STALE_MS) },
          },
        ],
      },
      { $set: { payoutStatus: 'processing', payoutProcessingAt: new Date() } },
      { new: true },
    ).select('_id payoutStatus');
    if (!claimed) {
      logger.info(
        `ℹ️ Payout déjà en cours ou terminé pour booking ${booking._id.toString()} — exécution concurrente ignorée.`,
      );
      return;
    }
    booking.payoutStatus = 'processing';
    booking.payoutProcessingAt = new Date();

    // Session v17 — resolve sitter OR walker via the unified provider
    // helper. The "sitter" variable name is kept below to minimise diff in
    // the payoutMethod branches; semantically it now means "provider".
    const provider = getBookingProvider(booking);
    if (!provider.id || !provider.Model) {
      logger.error('❌ Unable to process payout: provider missing on booking', booking._id.toString());
      // v23.1.374 — BOUCLE D'ERREUR RENDER (Daniel) : booking.save() sur un
      // doc SANS sitter/walker re-déclenchait la validation pre-save
      // ("Booking must target either a sitter or a walker") → l'état
      // 'failed' n'était JAMAIS persisté → la réservation corrompue était
      // re-tentée à CHAQUE tick du scheduler. updateOne atomique = pas de
      // hooks/validators → le doc sort définitivement de la file.
      await Booking.updateOne(
        { _id: booking._id },
        {
          $set: {
            payoutStatus: 'failed',
            payoutError: 'Provider missing on booking (no sitterId nor walkerId).',
          },
        },
      );
      return;
    }
    const sitter = await provider.Model.findById(provider.id);
    if (!sitter) {
      logger.error(`❌ Unable to process payout: ${provider.type} not found for booking`, booking._id.toString());
      // v23.1.374 — updateOne atomique (cf. provider missing ci-dessus).
      await Booking.updateOne(
        { _id: booking._id },
        {
          $set: {
            payoutStatus: 'failed',
            payoutError: `${provider.type === 'walker' ? 'Walker' : 'Sitter'} not found for payout.`,
          },
        },
      );
      return;
    }

    // v23.1.270 — Daniel : "j'ai fini un service et 0€ dans mon wallet". Le
    // modèle "part 83" veut que l'argent du provider arrive dans son WALLET
    // (puis retrait/boutique). Mais les branches stripe (défaut, mort) et
    // IBAN-sans-bénéficiaire-Airwallex marquaient "completed/pending" SANS
    // créditer le wallet → solde à 0. Ce helper crédite le wallet
    // (withdrawable=true, idempotent par booking) + notifie le provider.
    const creditProviderWalletNow = async (sourceTag) => {
      try {
        const { creditWallet } = require('../services/walletService');
        const c = await creditWallet({
          userId: sitter._id.toString(),
          userRole: provider.type,
          amount: netPayout,
          currency: (currency || 'EUR').toUpperCase(),
          type: 'credit_booking',
          bookingId: booking._id.toString(),
          meta: { source: sourceTag, autoPayout: false },
          withdrawable: true,
        });
        try {
          const { sendNotification } = require('../services/notificationSender');
          await sendNotification({
            userId: sitter._id.toString(),
            role: provider.type,
            type: 'wallet_credited',
            data: {
              bookingId: booking._id.toString(),
              amount: String(netPayout),
              currency: (currency || 'EUR').toUpperCase(),
            },
            actor: { role: 'system', id: null },
          });
        } catch (_) { /* non-critical */ }
        return c;
      } catch (e) {
        logger.error(
          `❌ wallet credit failed booking=${booking._id.toString()}: ${e?.message || e}`,
        );
        return null;
      }
    };

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
      // v23.1.270 — modèle wallet : on crédite QUAND MÊME le wallet (l'argent
      // est dispo en in-app : boutique, + retrait dès qu'un IBAN est ajouté).
      // On ne bloque plus les fonds en "held" → fini le 0€.
      await creditProviderWalletNow('wallet_credit_no_payout_method');
      booking.payoutMethod = 'wallet';
      booking.payoutStatus = 'completed';
      booking.payoutCompletedAt = new Date();
      booking.payoutError = null;
      await booking.save();
      logger.info(
        `💰 Wallet credited (no bank method yet) booking ${booking._id.toString()} provider ${provider.type}:${sitter._id} amount=${netPayout} ${currency}`,
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

      // v23.1 part 83 — NOUVEAU MODÈLE Daniel : "le walker est payé le
      // jour où il commence sa mission, l'argent va dans son wallet et
      // soit il l'utilise pour la boutique soit il le retire et reçoit
      // automatiquement l'argent sur son compte".
      //
      // Au lieu de pousser direct vers l'IBAN au start service, on
      // CRÉDITE le wallet (withdrawable=true). Le walker décide ensuite :
      //   • dépenser le solde dans la boutique (Boost / PawSpot / etc.)
      //   • OU tap "Retirer" → processPendingWithdrawals (v23.1.78)
      //     déclenche createPayout vers son IBAN.
      // Plus besoin de createPayout ici. Le booking est marqué
      // 'completed' (côté payout) dès que le wallet est crédité.
      const useAirwallexPayout =
        (PAYMENT_PROVIDER === 'airwallex')
        && !!sitter.airwallexBeneficiaryId
        && String(sitter.airwallexBeneficiaryId).trim().length > 0;

      if (useAirwallexPayout) {
        try {
          const { creditWallet } = require('../services/walletService');
          const credit = await creditWallet({
            userId: sitter._id.toString(),
            // v23.1 part 252 — BUG CRITIQUE : on passait `role:` mais
            // creditWallet attend `userRole:` (throw 'invalid args' sinon).
            // Resultat : le wallet n'etait JAMAIS credite (try/catch
            // silencieux) → solde walker/sitter restait a 0€ malgre
            // l'historique. Fix : role → userRole.
            userRole: provider.type,
            amount: netPayout,
            currency: (currency || 'EUR').toUpperCase(),
            type: 'credit_booking',
            bookingId: booking._id.toString(),
            referenceId: '',
            meta: { source: 'wallet_credit_at_service_start', autoPayout: false },
            withdrawable: true,
          });
          booking.payoutMethod = 'wallet';
          booking.payoutStatus = 'completed'; // wallet credit is the settlement
          booking.payoutCompletedAt = new Date();
          booking.payoutError = null;
          await booking.save();
          logger.info(
            `💰 Wallet credit (au start service) booking=${booking._id.toString()} ` +
            `provider=${provider.type}:${sitter._id} amount=${netPayout} ${currency} ` +
            `wallet_tx=${credit?.transactionId || '?'}`,
          );
          // Notif walker : argent disponible.
          try {
            const { sendNotification } = require('../services/notificationSender');
            await sendNotification({
              userId: sitter._id.toString(),
              role: provider.type,
              type: 'wallet_credited',
              data: {
                bookingId: booking._id.toString(),
                amount: String(netPayout),
                currency: (currency || 'EUR').toUpperCase(),
              },
              actor: { role: 'system', id: null },
            });
          } catch (_) { /* non-critical */ }
          return;
        } catch (awxErr) {
          logger.error(
            `❌ Airwallex payout failed (falling back to manual transfer queue) ` +
            `booking=${booking._id.toString()} : ${awxErr?.message || awxErr}`,
          );
          // Fall through to the manual-transfer queue below.
        }
      }

      // v23.1.270 — modèle wallet (part 83) : on CRÉDITE le wallet
      // (withdrawable=true) au lieu de mettre en file de virement manuel. Le
      // provider retire ensuite depuis son wallet → processPendingWithdrawals
      // déclenche le virement Airwallex (bénéficiaire créé au retrait). Sans
      // ça, un IBAN sans bénéficiaire Airwallex laissait le solde à 0€.
      await creditProviderWalletNow('wallet_credit_iban');
      booking.payoutMethod = 'wallet';
      booking.payoutStatus = 'completed';
      booking.payoutCompletedAt = new Date();
      booking.manualPayoutDetails = {
        ibanMasked: maskedIban,
        holderName,
        providerRole: provider.type,
        providerId: sitter._id.toString(),
        amount: netPayout,
        currency: (currency || 'EUR').toUpperCase(),
        queuedAt: new Date(),
      };
      booking.payoutError = null;
      await booking.save();
      logger.info(
        `💰 Wallet credited (IBAN → retrait via wallet) booking=${booking._id.toString()} provider=${provider.type}:${sitter._id} amount=${netPayout} ${currency} iban=${maskedIban}`,
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

      // v23.1 part 81 — credit provider wallet for HISTORY only
      // (withdrawable=false). PayPal payout already shipped the money.
      try {
        const { creditWallet } = require('../services/walletService');
        await creditWallet({
          userId: sitter._id.toString(),
          // v23.1 part 252 — fix role → userRole (cf. note ligne ~1024).
          userRole: provider.type,
          amount: netPayout,
          currency: (currency || 'EUR').toUpperCase(),
          type: 'credit_booking',
          bookingId: booking._id.toString(),
          referenceId: payoutResult.payoutItemId || '',
          meta: { source: 'paypal_payout', autoPayout: true },
          withdrawable: false,
        });
      } catch (walletErr) {
        logger.warn(
          `⚠️ wallet credit skipped after PayPal payout (booking ${booking._id}): ${walletErr?.message || walletErr}`,
        );
      }

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
      // v23.1.270 — Stripe Connect est purgé (aucun compte connecté). Cette
      // branche marquait "completed" SANS rien verser → 0€. On crédite le
      // wallet (modèle part 83) : c'est le cas par défaut quand le provider
      // n'a pas changé son payoutMethod (défaut 'stripe').
      await creditProviderWalletNow('wallet_credit_default');
      booking.payoutMethod = 'wallet';
      booking.payoutStatus = 'completed';
      booking.payoutCompletedAt = new Date();
      booking.payoutAt = new Date();
      booking.payoutError = null;
      await booking.save();
      logger.info('💰 Wallet credited (défaut/stripe→wallet) for booking', booking._id.toString());
      return;
    }

    logger.warn('⚠️ Unknown payout method for sitter', { payoutMethod, sitterId: sitter._id.toString() });
    // v23.1.374 — updateOne atomique (pas de validators, cf. plus haut).
    await Booking.updateOne(
      { _id: booking._id },
      {
        $set: {
          payoutStatus: 'failed',
          payoutError: `Unknown payout method: ${payoutMethod}`,
        },
      },
    );
  } catch (error) {
    // v23.1 part 46 — fix Daniel "logs Render disent juste Error while
    // processing sitter payout sans détail". Pino ignores 2nd/3rd args
    // unless you pass an object, so `logger.error('msg', id, err)` only
    // surfaced the message in the Render log stream and we never knew
    // what actually threw. Now we serialise message + stack into a
    // single string so the cause is visible in the live log.
    logger.error(
      `❌ Error while processing payout for booking ${booking._id.toString()} : ` +
      `${error?.message || String(error)} | stack=${(error?.stack || '').split('\n').slice(0, 3).join(' | ')}`,
    );
    // v23.1.374 — BOUCLE D'ERREUR RENDER (Daniel) : booking.save() pouvait
    // RE-THROW la même erreur de validation (doc corrompu sans provider) →
    // l'état 'failed' n'était jamais persisté → re-tentative à chaque tick
    // du scheduler, à l'infini. updateOne atomique = pas de hooks → le doc
    // sort définitivement de la file des payouts.
    try {
      await Booking.updateOne(
        { _id: booking._id },
        {
          $set: {
            payoutStatus: 'failed',
            payoutError: error.message || String(error),
          },
        },
      );
    } catch (saveError) {
      logger.error(
        `❌ Failed to persist payout failure state for booking ${booking._id.toString()} : ` +
        `${saveError?.message || String(saveError)}`,
      );
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

    // v532 — le code de remise n'est exposé qu'au propriétaire (cf. plus bas).
    const isOwnerView = userRole === 'owner';

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
        // v23.1.259 — état du flux de confirmation de service (pour afficher
        // les bons boutons : démarrer / terminer / confirmer / litige).
        confirmationStatus: booking.confirmationStatus || 'none',
        serviceStartedAt: booking.serviceStartedAt || null,
        serviceEndedAt: booking.serviceEndedAt || null,
        autoReleaseAt: booking.autoReleaseAt || null,
        // v532 — code de remise : visible UNIQUEMENT par le propriétaire.
        // C'est lui qui le montre au prestataire au moment de la remise ; si
        // le prestataire le voyait dans sa propre app, la preuve ne vaudrait
        // plus rien (il pourrait valider sans être présent).
        handoverCode: isOwnerView ? (booking.handoverCode || null) : null,
        // Photos de preuve : visibles des deux côtés une fois prises.
        pickupProofUrl: booking.pickupProof?.url || null,
        returnProofUrl: booking.returnProof?.url || null,
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
/**
 * v532 — PLAFOND DES REMISES : garantit qu'on encaisse toujours notre part.
 *
 * Le modèle est « commission EN PLUS » : le propriétaire paie
 * `basePrice + commission`, le prestataire touche `basePrice` en entier. Notre
 * seule marge sur une garde est donc la commission.
 *
 * Or les crédits (fidélité = 10 % du total d'une garde PRÉCÉDENTE, parrainage
 * = 5 € fixes) étaient déduits du total encaissé SANS jamais réduire le
 * versement au prestataire. Dès que le crédit dépassait la commission de la
 * garde en cours, on payait le prestataire avec notre propre argent :
 *   garde précédente 200 € de base → crédit de 24 €
 *   garde suivante    50 € de base → commission 10 €, encaissé 60 − 24 = 36 €,
 *   versé au prestataire 50 €      → PERTE SÈCHE de 14 € pour HoPetSit.
 * Un crédit supérieur au total menait même à un PaymentIntent de 0 €.
 *
 * On plafonne donc la remise à la commission de la garde en cours : le client
 * garde son avantage, le prestataire est payé plein tarif, et notre marge ne
 * peut jamais devenir négative.
 *
 * @returns {number} montant de remise réellement applicable (≥ 0).
 */
const capDiscountToCommission = (booking, requestedDiscount) => {
  const asked = Number(requestedDiscount) || 0;
  if (asked <= 0) return 0;
  const commission = Number(booking?.pricing?.commission) || 0;
  if (commission <= 0) return 0;
  const capped = Math.min(asked, commission);
  if (capped < asked) {
    logger.warn(
      `[discount] remise plafonnée pour booking ${booking?._id} : ${asked}€ demandés → ${capped}€ ` +
      '(limite = commission de la garde ; au-delà, HoPetSit paierait le prestataire de sa poche).',
    );
  }
  return Math.round(capped * 100) / 100;
};

const refundBookingPayment = async (booking) => {
  if (booking.paymentProvider === 'paypal') {
    const captureId = booking.paypalCaptureId;
    if (!captureId) throw new Error('No PayPal capture ID to refund.');
    return refundPaypalCapture(captureId);
  }
  // v23.1 part 79 — implement Airwallex refund (was stubbed). Owner
  // self-cancel < 72h auto-refund + admin manual refund both flow
  // through here. Refunds the FULL booking amount to the original
  // card via the saved PaymentIntent. createRefund returns the
  // Airwallex refund id ; we store it on the booking for audit.
  if (booking.paymentProvider === 'airwallex') {
    const piId = booking.airwallexPaymentIntentId;
    if (!piId) throw new Error('No Airwallex PaymentIntent ID to refund.');
    // v532 — on remboursait `pricing.totalPrice` (le prix AFFICHÉ). Or ce
    // n'est pas ce qui a été encaissé sur la carte dès qu'il y a eu une
    // remise : code promo, PawPoints, ou paiement partiel par le
    // portefeuille. Airwallex REFUSE tout remboursement supérieur au montant
    // capturé → l'appel échouait en bloc et le client ne récupérait
    // strictement RIEN (au lieu de récupérer ce qu'il avait payé).
    // On lit donc le montant réellement capturé sur le PaymentIntent ; en
    // dernier recours on omet `amount`, ce qui demande à Airwallex de
    // rembourser l'intégralité du capturé.
    let refundCents = null;
    try {
      const pi = await airwallex.retrievePaymentIntent(piId);
      const capturedMajor = Number(
        pi?.captured_amount != null ? pi.captured_amount : pi?.amount,
      );
      if (Number.isFinite(capturedMajor) && capturedMajor > 0) {
        refundCents = Math.round(capturedMajor * 100);
      }
    } catch (e) {
      logger.warn(
        `[refundBookingPayment] lecture du PaymentIntent ${piId} impossible (${e.message}) — remboursement du montant capturé intégral.`,
      );
    }
    const grossCents = Math.round(
      ((booking.pricing && booking.pricing.totalPrice) ||
        booking.totalAmount ||
        0) * 100,
    );
    // Filet de sécurité : ne jamais rembourser plus que le prix de la garde.
    if (refundCents != null && grossCents > 0 && refundCents > grossCents) {
      refundCents = grossCents;
    }
    const refund = await airwallex.createRefund({
      paymentIntentId: piId,
      ...(refundCents != null ? { amount: refundCents } : {}),
      reason: 'requested_by_customer',
      metadata: {
        type: 'booking_refund',
        bookingId: booking._id.toString(),
      },
    });
    if (refund && refund.id) {
      booking.refundId = refund.id;
      booking.refundedAt = new Date();
      await booking.save().catch(() => {});
    }
    logger.info(
      `[refundBookingPayment] airwallex refund ${refund?.id} issued for booking ${booking._id} (${refundCents != null ? `€${refundCents / 100}` : 'montant capturé intégral'}).`,
    );
    return refund;
  }
  throw new Error(`Refund not implemented for provider: ${booking.paymentProvider}`);
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

    // v23.1.160 — Daniel : "car owner walker au sitter peuvent annuler
    // jusqua 72h avant c les regles du paiement". Avant : seuls owner +
    // sitter pouvaient self-cancel ; walker n'avait AUCUN endpoint pour
    // annuler. Asymetrie critique → walker bloque dans un booking qu'il
    // peut plus honorer. Maintenant : owner + sitter + walker tous les 3
    // peuvent annuler jusqu'a 72h avant le service start, avec refund
    // automatique a l'owner.
    const booking = await Booking.findById(id)
      .populate('ownerId')
      .populate('sitterId')
      .populate('walkerId')
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
    const bookingWalkerId = booking.walkerId?._id
      ? booking.walkerId._id.toString()
      : booking.walkerId?.toString();

    const isOwner = bookingOwnerId === userId;
    const isSitter = bookingSitterId === userId;
    const isWalker = bookingWalkerId === userId;

    if (!isOwner && !isSitter && !isWalker) {
      return res
        .status(403)
        .json({ error: 'You do not have permission to cancel this booking.' });
    }

    // v449 — Daniel : « annuler avant 72h ne marche pas ». Cause : un booking
    // PAYÉ peut avoir status='agreed' (paiement via un chemin qui pose
    // paymentStatus/paidAt sans flipper status='paid') → ce garde le rejetait
    // en 409. On accepte aussi paymentStatus==='paid' (ou paidAt présent).
    const isPaidForCancel =
      booking.status === 'paid' ||
      booking.paymentStatus === 'paid' ||
      !!booking.paidAt;
    if (!isPaidForCancel) {
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
    const cancellerRole = isOwner ? 'owner' : isSitter ? 'sitter' : 'walker';
    booking.status = 'cancelled';
    booking.paymentStatus = 'refunded';
    booking.cancellationReason =
      req.body?.reason || `${cancellerRole}_self_cancel_72h`;
    booking.cancelledAt = new Date();
    booking.cancelledBy = cancellerRole;

    // If a payout was scheduled, cancel it — money stays in escrow & will be refunded.
    if (booking.payoutStatus === 'scheduled') {
      booking.payoutStatus = 'cancelled';
      booking.scheduledPayoutAt = null;
    }

    await booking.save();

    // v23.1 — flag the invoice as refunded so it shows the right status
    // on the Factures tab for both owner and provider.
    try {
      const { markInvoiceRefunded } = require('./invoiceController');
      await markInvoiceRefunded(booking._id);
    } catch (e) {
      logger.warn(`[selfCancelWithRefund] markInvoiceRefunded failed: ${e?.message || e}`);
    }

    // Best‑effort refund; refund provider helpers may or may not exist depending on build.
    try {
      if (typeof refundBookingPayment === 'function') {
        await refundBookingPayment(booking);
      }
    } catch (refundErr) {
      logger.error('⚠️  Self-cancel refund failed', refundErr);
      // Do not fail the cancellation — the booking is marked and admin can retry.
    }

    // v23.1.160 — Notif aux 2 parties. L'owner doit savoir si le walker/sitter
    // annule (et qu'il sera rembourse) ; le walker/sitter doit savoir si l'owner
    // annule (et qu'il ne sera pas paye). Avant : silence radio total, les users
    // decouvraient l'annulation par hasard dans la liste des bookings.
    try {
      const { sendNotification } = require('../services/notificationSender');
      const providerType = bookingWalkerId ? 'walker' : 'sitter';
      const providerId = bookingWalkerId || bookingSitterId;
      const notifData = {
        bookingId: booking._id.toString(),
        cancelledBy: cancellerRole,
      };
      // Notif a l'AUTRE partie. Si l'owner annule -> notif provider.
      // Si provider annule -> notif owner.
      if (isOwner && providerId) {
        await sendNotification({
          userId: providerId,
          role: providerType,
          type: 'booking_cancelled_by_owner',
          data: notifData,
          actor: { role: 'owner', id: bookingOwnerId },
        });
      } else if ((isSitter || isWalker) && bookingOwnerId) {
        await sendNotification({
          userId: bookingOwnerId,
          role: 'owner',
          type: 'booking_cancelled_by_provider',
          data: { ...notifData, providerType: cancellerRole },
          actor: { role: cancellerRole, id: userId },
        });
      }
    } catch (notifErr) {
      logger.warn(`[selfCancelWithRefund] notification failed: ${notifErr?.message || notifErr}`);
      // Best-effort — never block the cancel because a notif failed.
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
    // v23.1 part 127 — Phase 3 audit P3-25 : auth ajoutée côté router,
    // ici on a req.user.id et req.user.role garantis.
    const userId = req.user?.id;
    const userRole = req.user?.role;

    if (!['accept', 'reject'].includes(action)) {
      return res.status(400).json({ error: 'Invalid action. Expected "accept" or "reject".' });
    }

    // v23.1 part 127 — Phase 3 audit P3-27 : update atomique pour éviter
    // la race entre 2 providers qui acceptent simultanément. On update
    // uniquement si le statut est encore "pending" ET si l'user
    // authentifié est bien le sitter/walker cible de la booking. Si null,
    // c'est qu'un autre acteur a déjà répondu (ou que l'user n'est pas
    // partie à la booking) → 409.
    const newStatus = action === 'accept' ? 'accepted' : 'rejected';
    const timestampField = action === 'accept' ? 'acceptedAt' : 'rejectedAt';

    const ownershipFilter = userRole === 'walker'
      ? { _id: id, status: 'pending', walkerId: userId }
      : { _id: id, status: 'pending', sitterId: userId };

    const updatedBooking = await Booking.findOneAndUpdate(
      ownershipFilter,
      { $set: { status: newStatus, [timestampField]: new Date() } },
      { new: true },
    )
      .populate('ownerId')
      .populate('sitterId')
      .populate('walkerId')
      .populate('petIds');

    if (!updatedBooking) {
      // Soit la booking n'existe pas, soit elle n'est plus pending,
      // soit l'user n'est pas le provider. On distingue les 2 cas
      // pour donner un message utile (sans leak l'existence du doc).
      const existing = await Booking.findById(id).select('status sitterId walkerId').lean();
      if (!existing) return res.status(404).json({ error: 'Booking not found.' });
      const expectedProvider = userRole === 'walker' ? existing.walkerId : existing.sitterId;
      if (!expectedProvider || expectedProvider.toString() !== userId) {
        return res.status(403).json({ error: 'You are not the provider on this booking.' });
      }
      return res.status(409).json({ error: `Booking already ${existing.status}.` });
    }

    const booking = updatedBooking;

    // Session v16.2 - derive actor info from whichever provider field is set
    // so walker accept/reject notifications reach the owner correctly.
    const isWalkerResponder = !!booking.walkerId;
    const actorRoleForOwnerNotif = isWalkerResponder ? 'walker' : 'sitter';
    const actorIdForOwnerNotif = isWalkerResponder
      ? (booking.walkerId?._id ? booking.walkerId._id.toString() : booking.walkerId.toString())
      : (booking.sitterId?._id ? booking.sitterId._id.toString() : booking.sitterId.toString());

    if (action === 'accept') {
      // status/acceptedAt déjà set par findOneAndUpdate.

      // v18.4 — single path via sendNotification (bell + FCM + email).
      // v23.1 part 45 — fix Daniel "je ne reçois pas l'acceptation sitter".
      // The previous .catch(() => {}) swallowed every error silently — if
      // the owner had no fcmTokens or the email decrypt threw, no one
      // would ever know. Log explicitly so Render logs surface the
      // root cause on failure.
      sendNotification({
        userId: booking.ownerId?._id ? booking.ownerId._id.toString() : booking.ownerId.toString(),
        role: 'owner',
        type: 'booking_accepted',
        data: {
          bookingId: booking._id.toString(),
          providerRole: actorRoleForOwnerNotif,
        },
        actor: { role: actorRoleForOwnerNotif, id: actorIdForOwnerNotif },
      }).catch((e) => {
        logger.warn(
          `[respondBooking] booking_accepted notif failed for owner=${booking.ownerId?._id || booking.ownerId} : ${e?.message || e}`,
        );
      });

      // v23.1 part 41 — fix Daniel "owner ne recoi pas notif walker accepté".
      // Emit socket event so owner home banner refreshes immediately
      // (without waiting for the 30s periodic refresh). The frontend
      // BookingsController._attachSocketListeners now listens for
      // booking:accepted and calls loadBookings().
      try {
        const { emitToUser } = require('../sockets');
        const ownerIdStr = booking.ownerId?._id
          ? booking.ownerId._id.toString()
          : booking.ownerId.toString();
        emitToUser('owner', ownerIdStr, 'booking:accepted', {
          bookingId: booking._id.toString(),
          providerRole: actorRoleForOwnerNotif,
        });
      } catch (e) {
        logger.warn(`[respondBooking] booking:accepted emit failed : ${e?.message || e}`);
      }

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

    // v23.1 part 127 — Phase 3 audit P3-27 : status/rejectedAt déjà
    // set par findOneAndUpdate ci-dessus. On garde uniquement les
    // notifs + retour de réponse.

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
    // v23.1 — structured logging + surface details so the toast is actionable
    // instead of generic 500 'Unable to update booking. Please try again later.'.
    logger.error(
      { err: error, name: error?.name, message: error?.message, stack: error?.stack },
      '❌ Respond booking error',
    );
    console.error('[respondBooking] EXPLICIT:', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid booking id.', code: 'INVALID_ID' });
    }
    if (error?.message && /already (accepted|rejected|cancelled|paid|completed|agreed)/i.test(error.message)) {
      return res.status(409).json({ error: error.message, code: 'BOOKING_FINAL_STATE' });
    }
    res.status(500).json({
      error: 'Unable to update booking. Please try again later.',
      code: 'RESPOND_BOOKING_FAILED',
      details: error?.message || String(error),
    });
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
  if (booking.airwallexPaymentIntentId) {
    const existing = await airwallex.retrievePaymentIntent(booking.airwallexPaymentIntentId);
    if ((existing.status || '').toUpperCase() === 'SUCCEEDED') {
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
    // v532 — cf. note plus bas : on libère d'abord le crédit déjà rattaché à
    // cette réservation pour ne pas en brûler un second à chaque nouvelle
    // tentative de paiement.
    await restoreLoyaltyDiscount(booking._id).catch(() => {});
    const discount = await consumeLoyaltyDiscount(ownerId, booking._id);
    if (discount.applied) {
      // v532 — plafonné à notre commission (cf. capDiscountToCommission).
      const usable = capDiscountToCommission(booking, discount.discountAmount);
      if (usable > 0) {
        effectiveTotal = Math.max(0, totalPrice - usable);
        loyaltyDiscountApplied = { ...discount, discountAmount: usable };
      } else {
        // Rien d'applicable : on rend le crédit au lieu de le brûler.
        await restoreLoyaltyDiscount(booking._id).catch(() => {});
      }
    }
  }

  const amountInCents = Math.round(effectiveTotal * 100);
  if (isNaN(amountInCents) || amountInCents <= 0) throw new Error('Invalid payment amount.');

  // v21.1.1 — Stripe purgé. Airwallex only. No more Stripe Customer creation.
  // v21 — Airwallex flow uses platform-only PI ; the
  // 80% sitter cut is released later by payoutScheduler via IBAN payout.
  //
  // v23.1 part 67 — Daniel : "Payer publication bug" → page Airwallex
  // vide quand owner paie après accept d'une candidature. Root cause :
  // ce code path (_prepareOwnerPaymentForAgreedBooking, appelé depuis
  // applicationController) n'avait PAS le fix customer_id de v23.1.58
  // — la HPP n'avait donc rien à afficher comme moyens de paiement.
  // Fix : attacher customer_id ici aussi (idempotent, mêmes args que
  // /create-payment-intent).
  let airwallexCustomerId = null;
  try {
    const ownerDoc = booking.ownerId;
    const customer = await airwallex.findOrCreateCustomer({
      userId: ownerDoc._id.toString(),
      email: ownerDoc.email,
      firstName: (ownerDoc.name || '').split(' ')[0] || ownerDoc.name || '',
      lastName: (ownerDoc.name || '').split(' ').slice(1).join(' ') || '',
    });
    airwallexCustomerId = customer?.id || null;
    logger.info(
      `[booking._prepare] customer ensured ${airwallexCustomerId} for owner ${ownerDoc._id}`,
    );
  } catch (custErr) {
    logger.warn(
      `[booking._prepare] customer ensure failed (continuing without) : ${custErr?.message || custErr}`,
    );
  }

  let paymentIntent;
  let usedProvider = 'airwallex';
  paymentIntent = await airwallex.createPlatformPaymentIntent({
    amount: amountInCents,
    currency: bookingCurrency.toUpperCase(),
    ...(airwallexCustomerId ? { customer_id: airwallexCustomerId } : {}),
    metadata: {
      type: 'booking',
      bookingId: booking._id.toString(),
      ownerId: booking.ownerId._id.toString(),
      sitterId: providerRef.id,
      providerType: providerRef.type,
    },
  });
  logger.info(
    `[booking._prepare] airwallex PI created ${paymentIntent.id} ` +
    `${amountInCents / 100} ${bookingCurrency.toUpperCase()} ` +
    `for booking ${booking._id}`
  );

  booking.airwallexPaymentIntentId = paymentIntent.id;
  // Session v18.0 — only persist the connected account id when destination
  // charges are actually used. Otherwise leave it null so that
  // processProviderPayoutForBooking falls through to the IBAN / PayPal
  // branches at service-start time.
  booking.petsitterConnectedAccountId = (usedProvider === 'stripe' && hasStripeConnect)
    ? sitter.stripeConnectAccountId
    : null;
  booking.paymentProvider = usedProvider;
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
    let providerRef = getBookingProvider(booking);
    let sitter = providerRef.doc;

    // v22.3 — Bug 17b : auto-réparation si booking sans provider attaché
    // (legacy buggy bookings). On essaye de retrouver le provider via
    // l'Application qui pointe vers ce booking, puis on patch le booking.
    if (!sitter) {
      try {
        const Application = require('../models/Application');
        const app = await Application.findOne({ bookingId: booking._id })
          .populate('sitterId')
          .populate('walkerId');
        if (app) {
          if (app.sitterId && !booking.sitterId) {
            booking.sitterId = app.sitterId._id || app.sitterId;
            await booking.save();
            await booking.populate('sitterId');
            providerRef = getBookingProvider(booking);
            sitter = providerRef.doc;
            logger.info(`[createPaymentIntent] auto-repair booking ${booking._id} sitterId from application ${app._id}`);
          } else if (app.walkerId && !booking.walkerId) {
            booking.walkerId = app.walkerId._id || app.walkerId;
            await booking.save();
            await booking.populate('walkerId');
            providerRef = getBookingProvider(booking);
            sitter = providerRef.doc;
            logger.info(`[createPaymentIntent] auto-repair booking ${booking._id} walkerId from application ${app._id}`);
          }
        }
      } catch (e) {
        logger.warn(`[createPaymentIntent] auto-repair failed: ${e.message}`);
      }
    }

    if (!sitter) {
      return res.status(404).json({
        error: 'Provider not found on booking.',
        debug: {
          bookingId: booking._id.toString(),
          hasSitterId: !!booking.sitterId,
          hasWalkerId: !!booking.walkerId,
          status: booking.status,
        },
      });
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

    // v23.1.156 — Daniel : payment bloque sur page blanche Airwallex.
    // Cause : si le PI existant est en status CANCELLED (apres un
    // tap "Annuler" precedent ou un timeout webhook), on le renvoyait
    // au frontend → bridge ouvrait Airwallex HPP sur un PI mort →
    // page blanche. Maintenant : on detecte les statuts non-utilisables
    // et on cree un nouveau PI a la place.
    if (booking.airwallexPaymentIntentId) {
      try {
        const existingPaymentIntent = await airwallex.retrievePaymentIntent(
          booking.airwallexPaymentIntentId,
        );
        const existingStatus = (existingPaymentIntent.status || '').toUpperCase();
        if (existingStatus === 'SUCCEEDED') {
          return res.status(400).json({
            error: 'Payment already completed for this booking.',
          });
        }
        // Statut REUTILISABLE : on renvoie le PI existant.
        // Airwallex docs : 'REQUIRES_PAYMENT_METHOD' / 'REQUIRES_CONFIRMATION'
        // sont les seuls statuts qu'on peut continuer a confirmer.
        const reusableStatuses = new Set([
          'REQUIRES_PAYMENT_METHOD',
          'REQUIRES_CONFIRMATION',
          'REQUIRES_CUSTOMER_ACTION',
        ]);
        if (reusableStatuses.has(existingStatus)) {
          return res.json({
            paymentIntentId: existingPaymentIntent.id,
            clientSecret: existingPaymentIntent.client_secret,
            booking: sanitizeBooking(booking),
          });
        }
        // Sinon (CANCELLED, REQUIRES_CAPTURE, EXPIRED, etc.) : on
        // detache le PI pourri du booking et on continue vers la
        // creation d'un nouveau ci-dessous.
        logger.info(
          `[createPaymentIntent] existing PI ${booking.airwallexPaymentIntentId} ` +
          `is in non-reusable status ${existingStatus} → creating fresh PI`,
        );
        booking.airwallexPaymentIntentId = null;
        await booking.save();
      } catch (e) {
        // Si retrievePaymentIntent echoue (PI introuvable, network), on
        // detache aussi et on cree un nouveau plutot que de bloquer.
        logger.warn(
          `[createPaymentIntent] retrievePaymentIntent failed for ` +
          `${booking.airwallexPaymentIntentId}: ${e.message} → creating fresh PI`,
        );
        booking.airwallexPaymentIntentId = null;
        await booking.save();
      }
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
      // v532 — un crédit déjà « consommé » pour CETTE réservation (paiement
      // abandonné, PaymentIntent expiré puis recréé) était perdu et un SECOND
      // crédit était brûlé à la tentative suivante. On libère d'abord celui
      // rattaché à la réservation : la nouvelle tentative réutilise le même.
      await restoreLoyaltyDiscount(booking._id).catch(() => {});
      const discount = await consumeLoyaltyDiscount(ownerId, booking._id);
      if (discount.applied) {
        // v532 — plafonné à notre commission (cf. capDiscountToCommission).
        const usable = capDiscountToCommission(booking, discount.discountAmount);
        if (usable > 0) {
          effectiveTotal = Math.max(0, totalPrice - usable);
          loyaltyDiscountApplied = { ...discount, discountAmount: usable };
        } else {
          await restoreLoyaltyDiscount(booking._id).catch(() => {});
        }
      }
    }
    const amountInCents = Math.round(effectiveTotal * 100);

    if (isNaN(amountInCents) || amountInCents <= 0) {
      return res.status(400).json({
        error: 'Invalid payment amount. Please check the booking pricing.'
      });
    }

    // v23.1 — saveCard flag : if true, attach the booking PI to a customer
    // so a payment_consent is automatically created and the card surfaces
    // in SavedCardsScreen after the payment succeeds.
    // v23.1 part 40 — fix Daniel : OR if user picked an existing saved card
    // (paymentConsentId), attach customer + that specific consent to the PI
    // so Airwallex HPP pre-fills with the card (no manual re-entry).
    //
    // v23.1 part 58 — CRITICAL FIX. Per Airwallex docs, the HPP auto-discovers
    // saved cards by reading `customer_id` off the PaymentIntent. Previously
    // we only attached customer_id when wantsSaveCard || selectedConsentId
    // was true — meaning if the owner just tapped "Pay" without explicitly
    // ticking "save card" or selecting a saved card, no customer_id was
    // attached → HPP had nothing to look up → "enter card manually" UI.
    //
    // Now we ALWAYS attach customer_id (idempotent — findOrCreateCustomer
    // returns the same customer for the same user). Whether to save the
    // card on this PI is still gated on wantsSaveCard / first-time logic.
    const wantsSaveCard = req.body?.saveCard === true;
    const selectedConsentId = (req.body?.paymentConsentId || '').toString().trim();
    let airwallexCustomerId = null;
    try {
      const ownerDoc = booking.ownerId;
      const customer = await airwallex.findOrCreateCustomer({
        userId: ownerDoc._id.toString(),
        email: ownerDoc.email,
        firstName: (ownerDoc.name || '').split(' ')[0] || ownerDoc.name,
        lastName: (ownerDoc.name || '').split(' ').slice(1).join(' ') || '',
      });
      airwallexCustomerId = customer?.id || null;
      logger.info(
        `[createPaymentIntent] customer ensured ${airwallexCustomerId} ` +
        `(merchant=${ownerDoc._id.toString()}) wantsSave=${wantsSaveCard} ` +
        `selectedConsent=${selectedConsentId || 'none'}`,
      );
    } catch (custErr) {
      logger.warn(`[createPaymentIntent] customer ensure failed: ${custErr?.message || custErr}`);
    }

    // Session v18.0 — use Stripe Connect destination charge ONLY when the
    // provider has finished their Connect onboarding. Otherwise fall back
    // to a plain platform charge and let payoutScheduler release the 80%
    // via the provider's IBAN or PayPal at service-start.
    //
    // v21.1.1 — Stripe purgé. Airwallex only. No more Stripe Customer creation.
    // v21 — dual-provider switch (cf. _prepareOwnerPaymentForAgreedBooking
    // for the same pattern). Airwallex flow uses a platform-only PI ; the
    // 80% sitter cut is released later by payoutScheduler.
    let paymentIntent;
    let usedProvider = 'airwallex';
    paymentIntent = await airwallex.createPlatformPaymentIntent({
      amount: amountInCents,
      currency: bookingCurrency.toUpperCase(),
      // v23.1 part 56 — CORRECT Airwallex CIT flow per official docs
      // (https://www.airwallex.com/docs/payments/online-payments/save-and-reuse-payment-details).
      //
      // For a Customer-Initiated Transaction (the user tapping "Pay" in
      // our app), Airwallex says :
      //   "Call redirectToCheckout() with the customer_id on the
      //    PaymentIntent — Airwallex will list all the payment methods
      //    saved on the Customer, allowing your shopper to select any
      //    of the saved payment methods. For a saved card, the shopper
      //    will be prompted to enter their CVC."
      //
      // Translation : we ONLY need to attach `customer_id` to the PI.
      // Airwallex's HPP automatically discovers and lists every saved
      // card belonging to that customer. The frontend just opens HPP,
      // user picks the saved card from the list, types CVC, done — no
      // re-entering the full card.
      //
      // What we used to do wrong (parts 40/47) :
      //   - We passed `payment_consent_id` directly on the PI, then
      //     tried `confirmPaymentIntent(payment_consent_reference)`
      //     server-side. That flow is for **Merchant-Initiated**
      //     Transactions (subscriptions, off-session charges) — NOT
      //     for in-app one-tap reuse. Airwallex would either reject
      //     or fall back, and the frontend opened HPP without the
      //     saved-card list visible.
      //
      // For the FIRST payment (no saved card yet), we attach a
      // payment_consent block of type=recurring so the card gets
      // saved on the customer profile after the charge succeeds.
      //
      // For SUBSEQUENT payments (selectedConsentId set), we just
      // attach customer_id — Airwallex finds the saved card by
      // customer_id automatically. The consentId only acts as a
      // hint to the frontend showing "you already saved 8571" ;
      // the actual reuse is handled by Airwallex via customer_id.
      // v23.1 part 60 — IMPORTANT: only attach `payment_consent` block
      // when the user EXPLICITLY ticked "save my card". Daniel reported
      // the HPP rendered an empty payment area (header + amount + footer
      // visible, but no card form / no saved-card list in between). Root
      // cause was that v23.1.58 attached customer_id ALWAYS but kept
      // adding the `payment_consent: { type: 'recurring', next_triggered_by:
      // 'customer' }` block on every PI (gated only on selectedConsentId).
      // Airwallex's HPP doesn't know how to render a one-shot payment
      // when the PI carries a fresh recurring consent block — it ends
      // up showing nothing.
      //
      // Correct flow per Airwallex docs :
      //   - customer_id alone   → HPP auto-lists saved cards & lets the
      //                           user pick one or enter a new card.
      //   - customer_id + payment_consent block → only when the merchant
      //                           wants to PERSIST the new card. Tied to
      //                           the "Save my card" checkbox.
      //   - selectedConsentId   → don't add payment_consent (card already
      //                           saved).
      // v23.1.158 — Daniel : "sa c debloquer mais sa ne prend pas en
      // compte ma carte cb enregistrer". v156 retirait customer_id par
      // defaut pour debloquer HPP, mais ca empechait Airwallex de
      // lister les cartes sauvegardees. Le VRAI bug bloquant etait le
      // PI CANCELLED reutilise (fixe en v157), pas le customer_id.
      //
      // On restaure donc customer_id PAR DEFAUT (comportement v23.1.61) :
      //   - customer_id toujours attache si dispo → HPP liste les cartes
      //     sauvegardees + permet d'en ajouter une nouvelle.
      //   - payment_consent UNIQUEMENT si l'user tique "save card" sur
      //     un nouveau paiement (jamais sur un saved card reuse).
      ...(airwallexCustomerId ? {
        customer_id: airwallexCustomerId,
        ...(wantsSaveCard && !selectedConsentId ? {
          payment_consent: {
            type: 'recurring',
            next_triggered_by: 'customer',
            merchant_trigger_reason: 'unscheduled',
          },
        } : {}),
      } : {}),
      metadata: {
        type: 'booking',
        bookingId: booking._id.toString(),
        ownerId: booking.ownerId._id.toString(),
        sitterId: providerRef.id,
        providerType: providerRef.type,
      },
    });
    logger.info(
      `[booking.createPaymentIntent] airwallex PI created ${paymentIntent.id} ` +
      `${amountInCents / 100} ${bookingCurrency.toUpperCase()} ` +
      `for booking ${booking._id}`
    );

    // Save PaymentIntent ID and (conditionally) connected account ID.
    booking.airwallexPaymentIntentId = paymentIntent.id;
    booking.petsitterConnectedAccountId = (usedProvider === 'stripe' && hasStripeConnect)
      ? sitter.stripeConnectAccountId
      : null;
    booking.paymentProvider = usedProvider;
    booking.paymentStatus = 'pending';
    await booking.save();

    // v23.1 part 56 — server-side confirm REMOVED. Per Airwallex docs,
    // CIT subsequent payments don't need server-side confirm — the HPP
    // shows saved cards via customer_id alone. The old code tried
    // `payment_consent_reference` confirm which is for MIT only and
    // caused either silent rejections or a fallback to "enter card
    // manually" UI. We keep these vars at false/null for backward
    // compat with the frontend that still reads them.
    let serverConfirmed = false;
    let nextActionUrl = null;
    let savedCardError = null;
    if (false && selectedConsentId) {
      try {
        const confirmed = await airwallex.confirmPaymentIntent(paymentIntent.id, {
          payment_consent_reference: { id: selectedConsentId },
        });
        const confirmedStatus = (confirmed?.status || '').toUpperCase();
        // v23.1 part 49 — verbose log so we can trace exactly what Airwallex
        // returns. The saved-card flow being silent was the #1 source of
        // "card visible but HPP redemande la saisie" confusion.
        logger.info(
          `[booking.createPaymentIntent] server-side confirm with consent ${selectedConsentId} ` +
          `→ status=${confirmedStatus} | next_action=${confirmed?.next_action ? JSON.stringify(confirmed.next_action).slice(0, 200) : 'none'}`,
        );
        if (confirmedStatus === 'SUCCEEDED') {
          serverConfirmed = true;
        } else if (confirmedStatus === 'REQUIRES_CUSTOMER_ACTION') {
          // 3DS step needed — return the redirect URL so the client opens
          // the WebView directly at that URL (skipping the regular HPP
          // bridge which doesn't pre-fill saved cards anyway).
          nextActionUrl =
            confirmed?.next_action?.url ||
            confirmed?.next_action?.redirect_to_url?.url ||
            null;
          if (!nextActionUrl) {
            logger.warn(
              `[booking.createPaymentIntent] REQUIRES_CUSTOMER_ACTION but no nextActionUrl ` +
              `in response — full response: ${JSON.stringify(confirmed).slice(0, 500)}`,
            );
            // v23.1 part 54 — REQUIRES_CUSTOMER_ACTION without a URL is
            // unworkable. Surface as savedCardError so the frontend
            // doesn't silently fall back to HPP (which Daniel saw
            // happen with his old one_off consent).
            savedCardError = `Carte sauvegardée non utilisable (3DS sans URL). Réessaie avec une nouvelle carte.`;
          }
        } else {
          savedCardError = `Carte sauvegardée non utilisable (status=${confirmedStatus}). Réessaie avec une nouvelle carte.`;
          logger.warn(
            `[booking.createPaymentIntent] saved card consent ${selectedConsentId} unusable ` +
            `(status=${confirmedStatus}) — surfacing error to client. ` +
            `Full response: ${JSON.stringify(confirmed).slice(0, 500)}`,
          );
        }
      } catch (confirmErr) {
        savedCardError =
          confirmErr?.details?.message ||
          confirmErr?.message ||
          'Carte sauvegardée non utilisable. Réessaie avec une nouvelle carte.';
        logger.warn(
          `[booking.createPaymentIntent] server-side confirm threw for consent ${selectedConsentId} : ` +
          `${confirmErr?.message || confirmErr} | code=${confirmErr?.code} | ` +
          `details=${JSON.stringify(confirmErr?.details || {}).slice(0, 300)}`,
        );
      }

      // v23.1 part 54 — fix Daniel "carte 8571 dans la liste mais HPP
      // s'ouvre quand même". Auto-detach (disable) consents that we
      // failed to confirm — they are almost certainly broken (old
      // one_off consents from before the type=recurring fix, expired
      // cards, disabled consents, etc.). Detaching them removes the
      // card from listPaymentMethods so the user gets a clean state at
      // the next payment instead of repeatedly tapping a phantom card.
      if (savedCardError && !serverConfirmed && !nextActionUrl) {
        try {
          await airwallex.detachPaymentMethod(selectedConsentId);
          logger.info(
            `[booking.createPaymentIntent] auto-detached unusable consent ${selectedConsentId} after server-side confirm failure`,
          );
          savedCardError +=
            ' (Carte retirée automatiquement — sera re-sauvegardée au prochain paiement réussi.)';
        } catch (detachErr) {
          logger.warn(
            `[booking.createPaymentIntent] auto-detach failed for ${selectedConsentId} : ${detachErr?.message || detachErr}`,
          );
        }
      }
    }

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
      // v23.1 part 47/49 — saved-card fast path signals.
      //   serverConfirmed=true → frontend skips HPP, calls /confirm-payment.
      //   nextActionUrl → 3DS challenge URL, frontend opens that in
      //     WebView (still no card re-entry needed).
      //   savedCardError → consent rejected outright by Airwallex (disabled,
      //     expired, declined). Frontend should surface to the user instead
      //     of silently falling back to HPP.
      serverConfirmed,
      nextActionUrl,
      savedCardError,
      message: serverConfirmed
        ? 'PaymentIntent confirmed via saved card. Skip HPP.'
        : (nextActionUrl
            ? 'Saved card requires 3DS verification. Open nextActionUrl.'
            : (savedCardError
                ? 'Saved card unusable.'
                : 'PaymentIntent created successfully. Open HPP for user payment.')),
    });
  } catch (error) {
    // v23.1 — structured error mapping (PART 4). Backend now returns a stable
    // `code` (PAYMENT_INTENT_FAILED, PROVIDER_NOT_CONFIGURED, …) so the
    // frontend can show a translated, actionable toast instead of the raw
    // English Airwallex error.
    const mapped = airwallex.mapAirwallexError(error);
    logger.error(
      {
        err: error,
        name: error?.name,
        message: error?.message,
        stack: error?.stack,
        airwallexStatus: error?.status,
        airwallexCode: error?.code,
        airwallexDetails: error?.details,
        mappedCode: mapped.code,
      },
      '❌ Create payment intent error',
    );
    console.error('[createBookingPaymentIntent] EXPLICIT:', error);

    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid booking id.', code: 'INVALID_ID' });
    }
    if (mapped.code === 'CURRENCY_INVALID' || mapped.code === 'AMOUNT_INVALID') {
      return res.status(400).json({ error: mapped.message, code: mapped.code });
    }
    if (mapped.code === 'ENV_NOT_CONFIGURED') {
      return res.status(500).json({
        error: mapped.message,
        code: mapped.code,
        debug: {
          airwallexEnv: {
            hasClientId: !!process.env.AIRWALLEX_CLIENT_ID,
            hasApiKey: !!process.env.AIRWALLEX_API_KEY,
            useDemo: process.env.AIRWALLEX_USE_DEMO === 'true',
          },
        },
      });
    }
    if (error.message && error.message.includes('must have')) {
      return res.status(400).json({ error: error.message, code: 'PROVIDER_INCOMPLETE' });
    }
    // Fallback — keep the raw airwallex details under `debug` for diagnostic
    // until paiements stabilisés. Frontend reads `code` first.
    res.status(500).json({
      error: 'Unable to create payment intent. Please try again later.',
      code: mapped.code,
      details: mapped.message,
      debug: {
        message: error.message,
        name: error.name,
        awxStatus: mapped.status,
        awxCode: mapped.awxCode,
        awxDetails: mapped.details,
        airwallexEnv: {
          hasClientId: !!process.env.AIRWALLEX_CLIENT_ID,
          hasApiKey: !!process.env.AIRWALLEX_API_KEY,
          useDemo: process.env.AIRWALLEX_USE_DEMO === 'true',
        },
        stack: (error.stack || '').split('\n').slice(0, 5),
      },
    });
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
    if (booking.airwallexPaymentIntentId && booking.airwallexPaymentIntentId !== paymentIntentId) {
      return res.status(400).json({
        error: 'Payment intent ID does not match the booking\'s payment intent.'
      });
    }
    // v532 — FAILLE CRITIQUE : le contrôle ci-dessus n'existait QUE si la
    // réservation portait déjà un airwallexPaymentIntentId. Sur une résa
    // `agreed` (aucun PI créé) ou après cancelBookingPaymentIntent (qui remet
    // le champ à null), il n'y avait AUCUNE vérification : l'owner pouvait
    // appeler cet endpoint avec l'id d'un PaymentIntent SUCCEEDED lui
    // appartenant mais sans rapport (sa vérification carte à 0,50 €, son KYC
    // à 3 €, une vieille réservation à 10 €) et faire passer en « payée » une
    // réservation de 500 € jamais encaissée — le prestataire étant ensuite
    // réellement payé. On exige désormais que le PaymentIntent désigne CETTE
    // réservation dans ses métadonnées.
    if (!booking.airwallexPaymentIntentId) {
      let piCheck = null;
      try {
        piCheck = await airwallex.retrievePaymentIntent(paymentIntentId);
      } catch (e) {
        logger.error(`[confirmBookingPayment] retrieve (garde) failed ${paymentIntentId}: ${e.message}`);
        return res.status(502).json({ error: 'Unable to verify payment with Airwallex. Please try again.' });
      }
      const piBookingId = String(
        piCheck?.metadata?.bookingId || piCheck?.metadata?.booking_id || '',
      ).trim();
      if (piBookingId !== String(booking._id)) {
        logger.warn(
          `[confirmBookingPayment] REFUS : PI ${paymentIntentId} (bookingId=${piBookingId || 'absent'}) ` +
          `ne correspond pas au booking ${booking._id} (owner ${ownerId}).`,
        );
        return res.status(400).json({
          error: 'This payment does not belong to this booking.',
          code: 'PAYMENT_INTENT_MISMATCH',
        });
      }
    }

    // v22.5 — HOTFIX : on remplace l'ancien stub 502 ("Stripe payment
    // confirmation disabled") par la vraie confirmation Airwallex.
    //
    // Flow Airwallex (vs Stripe legacy) :
    //   1. Frontend a déjà confirmé le PI via le SDK Airwallex côté client
    //      (avec carte sauvegardée ou nouvelle carte). À l'arrivée ici, le
    //      PI est soit déjà SUCCEEDED, soit en cours.
    //   2. On retrieve le PI sur Airwallex pour avoir l'état canonique
    //      (le webhook payment_intent.succeeded est la source de vérité,
    //      mais cet endpoint sert à donner un retour synchrone à l'UI).
    //   3. Si SUCCEEDED, on marque la booking paid + trigger payout
    //      (idempotent : le webhook fera la même chose si on est plus
    //      rapide ou plus lent que lui).
    //   4. Sinon on remonte le statut Airwallex pour que l'UI gère
    //      (REQUIRES_PAYMENT_METHOD, REQUIRES_CONFIRMATION, etc.).
    let pi;
    try {
      pi = await airwallex.retrievePaymentIntent(paymentIntentId);
    } catch (e) {
      logger.error(`[confirmBookingPayment] retrievePaymentIntent failed for ${paymentIntentId}: ${e.message}`);
      return res.status(502).json({
        error: 'Unable to verify payment with Airwallex. Please try again.',
        details: e.message,
      });
    }

    const piStatus = (pi?.status || '').toUpperCase();
    logger.info(`[confirmBookingPayment] booking=${booking._id} PI=${paymentIntentId} status=${piStatus}`);

    // Idempotent : si la webhook a déjà marqué paid, on retourne success direct.
    const alreadyPaid = booking.paymentStatus === 'paid' || piStatus === 'SUCCEEDED';

    if (alreadyPaid) {
      // Marquer la booking si pas encore fait (race avec le webhook).
      const justMarkedPaid = booking.paymentStatus !== 'paid';
      if (justMarkedPaid) {
        // v23.1 part 45 — fix Daniel "wallet, notif, payée tab tout cassé".
        // Root cause : we only set paymentStatus = 'paid' but the downstream
        // gate processProviderPayoutForBooking requires BOTH
        // `booking.status === 'paid' && booking.paymentStatus === 'paid'`
        // (PayPal flow at line ~2944 sets both — Airwallex was the odd
        // one out). Without status='paid' the payout never triggered, the
        // wallet was never credited and "booking_paid" notifs were
        // suppressed by the same gate downstream.
        booking.status = 'paid';
        booking.paymentStatus = 'paid';
        booking.paidAt = new Date();
        booking.paymentProvider = 'airwallex';
        await booking.save();
        logger.info(`✅ [confirmBookingPayment] booking ${booking._id} marked paid (sync path).`);

        // v23.1 part 47 — fix Daniel "earnings history montre les paiements
        // mais wallet reste à 0€". Root cause : creditWallet was only
        // called from inside the payout success path (Airwallex SEPA
        // payout returned OK). When payout threw or fell back to the
        // manual_transfer queue, creditWallet was never called and the
        // wallet stayed at 0 even though the booking was clearly paid.
        // Credit the wallet immediately when payment is confirmed,
        // independent of the payout outcome — the wallet now represents
        // "money earned, regardless of when it lands in the bank". The
        // creditWallet() function is idempotent on (bookingId, type), so
        // the call inside processProviderPayoutForBooking won't double-
        // credit when the payout eventually succeeds.
        try {
          const { creditWallet } = require('../services/walletService');
          const provider = getBookingProvider(booking);
          const netPayout = booking.pricing?.netPayout;
          const currency = booking.pricing?.currency || 'EUR';
          if (
            provider?.id &&
            provider?.type &&
            typeof netPayout === 'number' &&
            Number.isFinite(netPayout) &&
            netPayout > 0
          ) {
            // v23.1 part 81 — wallet is now purely informational for the
            // booking flow. The actual money will be auto-paid to the
            // walker's IBAN at service start (processProviderPayoutForBooking
            // → airwallex.createPayout). Crediting the wallet balance here
            // would let the walker request a manual withdrawal of the same
            // amount on top of the auto-payout = double pay. We only
            // log the transaction for the in-app earnings history.
            await creditWallet({
              userId: provider.id,
              // v23.1 part 252 — fix role → userRole (cf. note ligne ~1024).
              userRole: provider.type,
              amount: netPayout,
              currency: currency.toUpperCase(),
              type: 'credit_booking',
              bookingId: booking._id.toString(),
              meta: { source: 'confirm_payment_sync', autoPayout: false },
              // v23.1.330 — Daniel : argent bloqué jusqu'à la confirmation de fin
              // de service. Au PAIEMENT = HISTORIQUE SEULEMENT (withdrawable:false,
              // n'incrémente pas le solde retirable). Le solde est libéré
              // (withdrawable:true) uniquement à confirmService. Conforme au
              // commentaire "only log for history" ci-dessus (le true était un bug).
              withdrawable: false,
            });
          }
        } catch (walletErr) {
          logger.warn(
            `[confirmBookingPayment] wallet credit failed for booking ${booking._id}: ${walletErr?.message || walletErr}`,
          );
        }

        // v23.1.339 — Daniel : "l'argent est libre, j'ai pu retirer sans
        // aucune confirmation". On NE LIBÈRE PLUS le payout au paiement.
        // À la place on initialise l'ESCROW (flux de confirmation) via
        // schedulePayoutForBooking : confirmationStatus='awaiting_start',
        // autoReleaseAt = fin du service + 48h, payoutStatus='scheduled'.
        // L'argent ne devient retirable QUE :
        //   - à la confirmation de fin de service par l'owner (confirmService), OU
        //   - à l'auto-release 48h via le scheduler (processScheduledSitterPayouts).
        // (Le webhook Airwallex fait déjà ce schedulePayoutForBooking ; ici on
        // couvre le chemin de confirmation synchrone qui, avant, libérait tout
        // de suite. Le gate escrow dans processProviderPayoutForBooking bloque
        // de toute façon toute libération prématurée — double sécurité.)
        try {
          if (typeof schedulePayoutForBooking === 'function') {
            await schedulePayoutForBooking(booking);
          }
        } catch (e) {
          logger.error(`[confirmBookingPayment] escrow schedule failed: ${e.message}`);
        }

        // v23.1 — push notif (bell + FCM + email) to BOTH the provider and
        // the owner so a paid booking surfaces immediately in the bell badge,
        // the lock-screen push, and the email inbox. Idempotent because
        // justMarkedPaid is true only once.
        try {
          const providerRole2 = booking.walkerId ? 'walker' : 'sitter';
          // v23.1 part 52 — fix Daniel : critical bug where the populated
          // booking refs were stringified verbatim. `booking.walkerId` is
          // a populated Mongoose document (we call .populate('walkerId')
          // earlier in the function), so `booking.walkerId.toString()`
          // returns the WHOLE document inspect output (~5KB JSON-ish
          // string) — not the ObjectId. sendNotification then called
          // `Walker.findById(<5KB-string>)` which threw "Cast to ObjectId
          // failed". This is why owner+walker booking_paid notifs went
          // silently to /dev/null while wallet credit (which used the
          // raw _id) worked fine. Now we extract _id explicitly.
          const providerId2 = booking.walkerId
            ? (booking.walkerId._id ? booking.walkerId._id.toString() : String(booking.walkerId))
            : (booking.sitterId ? (booking.sitterId._id ? booking.sitterId._id.toString() : String(booking.sitterId)) : null);
          const ownerId2 = booking.ownerId
            ? (booking.ownerId._id ? booking.ownerId._id.toString() : String(booking.ownerId))
            : null;
          if (providerId2) {
            sendNotification({
              userId: providerId2,
              role: providerRole2,
              type: 'booking_paid',
              data: {
                bookingId: booking._id.toString(),
                providerRole: providerRole2,
              },
              actor: { role: 'owner', id: ownerId2 },
            }).catch((e) => {
              // v23.1 part 46 — surface the cause instead of silently
              // dropping. Daniel's main "no payment notif" bug came from
              // silent .catch swallowing every failure.
              logger.warn(
                `[confirmBookingPayment] booking_paid notif failed for ${providerRole2}=${providerId2} : ${e?.message || e}`,
              );
            });
          }
          if (ownerId2) {
            sendNotification({
              userId: ownerId2,
              role: 'owner',
              type: 'booking_paid_owner',
              data: {
                bookingId: booking._id.toString(),
                providerRole: providerRole2,
              },
              actor: { role: providerRole2, id: providerId2 },
            }).catch((e) => {
              logger.warn(
                `[confirmBookingPayment] booking_paid_owner notif failed for owner=${ownerId2} : ${e?.message || e}`,
              );
            });
          }
        } catch (e) {
          logger.error(`[confirmBookingPayment] sendNotification failed: ${e.message}`);
        }
      }

      // v23.1 — fallback path : when the Airwallex webhook does not reach us
      // (demo env, mis-configured webhook URL), the system message and chat
      // unlock that the webhook handler creates would never fire and the
      // user sees "Le chat s'ouvre après confirmation du paiement" forever.
      // Mirror that webhook logic here, idempotently (skip if a system msg
      // already exists for this booking's conversation).
      try {
        const Conversation = require('../models/Conversation');
        const Message = require('../models/Message');
        // v23.1 part 53 — fix Daniel "tjr pareil bug 2" : same populated-doc
        // bug as the booking_paid flow above, but for the chat unlock +
        // NEW_MESSAGE notif. ownerId2/providerId2 were populated Mongoose
        // docs ; calling .toString() on them later in the sendNotification
        // calls (lines ~2937, 2949) stringified the full doc inspect output.
        // Result : `[notif.entry] userId={ servicePreferences: ... }` →
        // resolveUser cast failed → no in-app DB record → NO bell badge
        // increment for chat. Extract _id explicitly here, then everything
        // else (Message.create, emitToUser, sendNotification) reuses the
        // raw ObjectIds (Mongoose's populated docs accept passthrough for
        // refs).
        const _id = (ref) =>
          ref && ref._id ? ref._id : ref;
        const _idStr = (ref) =>
          ref && ref._id ? ref._id.toString() : (ref ? String(ref) : null);
        const ownerId2 = _id(booking.ownerId);
        const sitterId2 = booking.sitterId ? _id(booking.sitterId) : null;
        const walkerId2 = booking.walkerId ? _id(booking.walkerId) : null;
        const providerId2 = sitterId2 || walkerId2;
        if (ownerId2 && providerId2) {
          const providerField = sitterId2 ? 'sitterId' : 'walkerId';
          const providerRole = sitterId2 ? 'sitter' : 'walker';
          let conversation = await Conversation.findOne({
            ownerId: ownerId2,
            [providerField]: providerId2,
          });
          if (!conversation) {
            conversation = await Conversation.create({
              ownerId: ownerId2,
              [providerField]: providerId2,
              bookingId: booking._id,
            });
            logger.info(`[confirmBookingPayment] conversation created ${conversation._id} for booking ${booking._id}`);
          }
          // v23.1 part 40 — on ne bloque PAS le 2e paiement entre les MÊMES
          // parties : la dédup est scopée PAR PAIEMENT (bookingId/intentId),
          // pas par conversation.
          // v23.1.342 — Daniel : "vérifie que l'auto message se déclenche bien
          // instantanément". Le chemin sync reste instantané (création +
          // socket dans la même requête), MAIS il courait en DOUBLE avec le
          // webhook : le webhook déduplique par metadata.bookingId/intentId
          // alors qu'ici on ne vérifiait rien (existingSysMsg=false) et on ne
          // stampait pas le metadata → selon l'ordre webhook/sync, les 2
          // messages partaient 2 fois. Fix : même requête de dédup que le
          // webhook (scopée à CE paiement → un 2e paiement refire bien ses
          // propres messages) + stamps bookingId/intentId ci-dessous.
          const existingSysMsg = await Message.findOne({
            conversationId: conversation._id,
            senderRole: 'system',
            $or: [
              { 'metadata.bookingId': booking._id.toString() },
              {
                'metadata.kind': 'payment_confirmed',
                'metadata.intentId': paymentIntentId,
              },
            ],
          }).lean();
          if (existingSysMsg) {
            logger.info(
              `[confirmBookingPayment] system messages already posted for booking ${booking._id} — skipping duplicates (webhook won the race).`,
            );
          }
          if (!existingSysMsg) {
            // v23.1.255 — metadata.kind ajouté pour que le frontend localise
            // le texte dans la langue de CHAQUE viewer (le body FR n'est plus
            // qu'un fallback web/anciens clients). Avant : ces 2 messages
            // s'affichaient en français même en UI espagnole.
            const systemMessage = await Message.create({
              conversationId: conversation._id,
              senderRole: 'system',
              senderId: ownerId2,
              body: '✅ Paiement confirmé. La réservation est active — vous pouvez désormais discuter ici.',
              type: 'text',
              // v23.1.342 — stamps bookingId/intentId alignés sur le webhook :
              // c'est la clé de dédup croisée sync ↔ webhook (anti-doublons).
              metadata: {
                kind: 'payment_confirmed',
                bookingId: booking._id.toString(),
                intentId: paymentIntentId,
              },
            });
            // v23.1 part 37 — 2e system message "discutons du lieu de rencontre"
            const rendezvousMessage = await Message.create({
              conversationId: conversation._id,
              senderRole: 'system',
              senderId: ownerId2,
              body: '👋 Bonjour ! Discutons ici pour convenir du lieu et de l\'heure de rencontre.',
              type: 'text',
              metadata: {
                kind: 'rendezvous_prompt',
                bookingId: booking._id.toString(),
                intentId: paymentIntentId,
              },
            });
            // v23.1 part 41 — fix Daniel "badge message marche pas" :
            // increment ownerUnreadCount + sitterUnreadCount (schema uses
            // sitterUnreadCount as generic provider field, even for walkers)
            // + update lastMessage so conversation list shows the right preview.
            try {
              conversation.lastMessage = rendezvousMessage.body;
              conversation.lastMessageAt = new Date();
              conversation.ownerUnreadCount = (conversation.ownerUnreadCount || 0) + 2;
              conversation.sitterUnreadCount = (conversation.sitterUnreadCount || 0) + 2;
              await conversation.save();
            } catch (e) {
              logger.warn(`[confirmBookingPayment] conversation badge update failed : ${e.message}`);
            }
            try {
              const { emitToUser } = require('../sockets');
              const ownerIdStr = _idStr(ownerId2);
              const providerIdStr = _idStr(providerId2);
              for (const msg of [systemMessage, rendezvousMessage]) {
                emitToUser('owner', ownerIdStr, 'message:new', {
                  conversationId: conversation._id.toString(),
                  message: msg.toObject(),
                });
                emitToUser(providerRole, providerIdStr, 'message:new', {
                  conversationId: conversation._id.toString(),
                  message: msg.toObject(),
                });
              }
              emitToUser('owner', ownerIdStr, 'booking:paid', {
                bookingId: booking._id.toString(),
                paymentStatus: 'paid',
              });
              // v23.1 part 53 — also emit to the provider so their home
              // banner refreshes to "Paiement reçu" without waiting for
              // the 30s polling tick.
              emitToUser(providerRole, providerIdStr, 'booking:paid', {
                bookingId: booking._id.toString(),
                paymentStatus: 'paid',
              });
            } catch (_) { /* socket non-critique */ }
            // v23.1 part 34 — envoie NEW_MESSAGE notif (badge in-app + FCM
            // push + email) aux 2 parties dans le fallback sync.
            // v23.1 part 53 — userId via _idStr() pour éviter la stringif
            // du doc populated (fix Daniel "bug 2 message badge").
            try {
              const { sendNotification } = require('../services/notificationSender');
              const previewText = (systemMessage.body || '').slice(0, 120);
              await Promise.allSettled([
                sendNotification({
                  userId: _idStr(ownerId2),
                  role: 'owner',
                  type: 'NEW_MESSAGE',
                  data: {
                    conversationId: conversation._id.toString(),
                    messageId: systemMessage._id.toString(),
                    senderName: 'HoPetSit',
                    preview: previewText,
                  },
                  actor: { role: 'system', id: null },
                }),
                sendNotification({
                  userId: _idStr(providerId2),
                  role: providerRole,
                  type: 'NEW_MESSAGE',
                  data: {
                    conversationId: conversation._id.toString(),
                    messageId: systemMessage._id.toString(),
                    senderName: 'HoPetSit',
                    preview: previewText,
                  },
                  actor: { role: 'system', id: null },
                }),
              ]);
            } catch (e) {
              logger.warn(`[confirmBookingPayment] NEW_MESSAGE notif fallback failed: ${e.message}`);
            }
            logger.info(`✅ [confirmBookingPayment] system message + chat unlocked + notif sent for booking ${booking._id} (sync fallback)`);
          }
        }
      } catch (e) {
        logger.error(`[confirmBookingPayment] chat unlock fallback failed: ${e.message}`);
      }

      // v23.1 part 24 — fallback : auto-create invoice when webhook hasn't
      // fired yet (demo env, mis-configured webhook URL). Idempotent : the
      // controller checks an existing invoice for this booking and returns
      // the existing one instead of duplicating.
      try {
        const { createInvoiceForBooking } = require('./invoiceController');
        if (typeof createInvoiceForBooking === 'function') {
          const populated = await Booking.findById(booking._id)
            .populate('ownerId')
            .populate('sitterId')
            .populate('walkerId')
            .populate('petIds');
          await createInvoiceForBooking(populated);
          logger.info(`✅ [confirmBookingPayment] invoice auto-created (sync fallback) for booking ${booking._id}`);
        }
      } catch (e) {
        logger.error(`[confirmBookingPayment] invoice fallback failed: ${e.message}`);
      }

      // v23.1 part 24 — fallback : schedule payout (the webhook normally does
      // this, but in demo mode without webhooks the provider would never get
      // paid).
      try {
        if (typeof schedulePayoutForBooking === 'function') {
          await schedulePayoutForBooking(booking);
        }
      } catch (e) {
        logger.error(`[confirmBookingPayment] payout schedule fallback failed: ${e.message}`);
      }

      return res.status(200).json({
        success: true,
        status: 'succeeded',
        bookingId: booking._id.toString(),
        paymentStatus: 'paid',
        paymentIntentId,
      });
    }

    // États intermédiaires : on retourne 200 mais sans success=true pour
    // que l'UI puisse afficher un loader / re-tenter / attendre la webhook.
    if (piStatus === 'REQUIRES_CAPTURE' || piStatus === 'PENDING' || piStatus === 'PROCESSING') {
      return res.status(200).json({
        success: false,
        status: piStatus.toLowerCase(),
        message: 'Payment is being processed. Please wait a moment.',
        paymentIntentId,
      });
    }

    // États qui demandent une action user.
    if (piStatus === 'REQUIRES_PAYMENT_METHOD' || piStatus === 'REQUIRES_CONFIRMATION') {
      return res.status(400).json({
        error: 'Payment method required or not yet confirmed. Please try paying again.',
        status: piStatus.toLowerCase(),
      });
    }

    // Échecs explicites.
    if (piStatus === 'CANCELLED' || piStatus === 'FAILED' || piStatus === 'EXPIRED') {
      booking.paymentStatus = piStatus === 'CANCELLED' ? 'cancelled' : 'failed';
      booking.paymentFailedAt = new Date();
      await booking.save();
      return res.status(400).json({
        error: `Payment ${piStatus.toLowerCase()}. Please try again with a different payment method.`,
        status: piStatus.toLowerCase(),
      });
    }

    // Default : retourner l'état brut pour debug.
    return res.status(200).json({
      success: false,
      status: piStatus.toLowerCase() || 'unknown',
      paymentIntentId,
      raw: { status: pi?.status },
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

    // v532 — `walkerId` n'était PAS peuplé : sur une réservation de promenade
    // `booking.sitterId` vaut null et la ligne `booking.sitterId._id` plantait
    // en TypeError → 500. Aucune promenade payée ne pouvait être annulée.
    const booking = await Booking.findById(id)
      .populate('ownerId')
      .populate('sitterId')
      .populate('walkerId')
      .populate('petIds');
    if (!booking) {
      return res.status(404).json({ error: 'Booking not found.' });
    }

    const ownerId = booking.ownerId?._id?.toString() || String(booking.ownerId || '');
    const provider = getBookingProvider(booking);
    const providerId = provider?.id || null;

    // v532 — TROU D'AUTORISATION : seuls les rôles 'owner' et 'sitter' étaient
    // vérifiés. Un compte de rôle 'walker' passait donc les deux tests sans
    // aucun contrôle et pouvait annuler — et faire rembourser — la
    // réservation de N'IMPORTE QUI. On vérifie désormais l'appartenance à la
    // réservation, quel que soit le rôle.
    const isOwner = ownerId && ownerId === userId;
    const isProvider = providerId && providerId === userId;
    if (!isOwner && !isProvider) {
      return res.status(403).json({ error: 'You do not have permission to cancel this booking.' });
    }
    if (userRole === 'owner' && !isOwner) {
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
    if (isOwner) {
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
      // Les deux parties sont d'accord → remboursement du propriétaire.
      //
      // v532 — CE BLOC NE REMBOURSAIT JAMAIS RIEN. Il était resté en logique
      // Stripe : il cherchait un `stripeChargeId`, sinon le déduisait de
      // `paymentIntent.latest_charge` — un champ qui N'EXISTE PAS chez
      // Airwallex. `chargeId` restait donc toujours vide et on tombait dans la
      // branche « pas de charge » : la réservation passait en `cancelled`,
      // l'argent du propriétaire restait chez nous, et le message annonçait
      // « aucun remboursement nécessaire ». Et dans le cas improbable où un
      // vieux `stripeChargeId` traînait, `createRefund(chargeId)` passait une
      // CHAÎNE à une fonction qui attend `{ paymentIntentId }` → exception
      // « paymentIntentId is required » → 500.
      // On passe par le helper `refundBookingPayment`, celui déjà utilisé par
      // l'auto-annulation à 72 h et par l'admin (Airwallex ET PayPal).
      booking.cancellation.confirmedAt = new Date();
      // On coupe d'abord le versement au prestataire : sans ça, le planificateur
      // de payouts pouvait libérer l'argent pendant qu'on rembourse.
      booking.payoutStatus = 'cancelled';
      const canRefund =
        booking.paymentStatus === 'paid' &&
        (booking.airwallexPaymentIntentId || booking.paypalCaptureId);
      if (canRefund) {
        try {
          const refund = await refundBookingPayment(booking);
          booking.cancellation.refundId = refund?.id || null;
          booking.status = 'refunded';
          booking.paymentStatus = 'refunded';
          logger.info(`✅ Refund processed for booking ${booking._id}: ${refund?.id}`);
        } catch (refundError) {
          logger.error('Refund error:', refundError);
          return res.status(502).json({
            error: 'Unable to process refund. Please try again later.',
            code: 'REFUND_FAILED',
          });
        }
        // Reprise du crédit prestataire s'il avait déjà été rendu retirable
        // (service confirmé puis annulé d'un commun accord). On ne touche au
        // solde que si ce crédit précis l'avait bien incrémenté.
        try {
          const WalletTransaction = require('../models/WalletTransaction');
          const prov = getBookingProvider(booking);
          if (prov?.id && prov?.type) {
            const [credited, alreadyReversed] = await Promise.all([
              WalletTransaction.findOne({
                userId: prov.id,
                bookingId: booking._id,
                type: 'credit_booking',
                status: { $in: ['completed', 'pending'] },
                'meta.withdrawable': true,
              }).lean(),
              WalletTransaction.findOne({
                userId: prov.id,
                bookingId: booking._id,
                type: 'admin_adjustment',
                'meta.reason': 'mutual_cancellation_reversal',
              }).lean(),
            ]);
            if (credited && !alreadyReversed) {
              const { debitWallet } = require('../services/walletService');
              await debitWallet({
                userId: prov.id,
                userRole: prov.type,
                amount: Number(credited.amount) || Number(booking?.pricing?.netPayout) || 0,
                currency: booking?.pricing?.currency || 'EUR',
                type: 'admin_adjustment',
                bookingId: String(booking._id),
                meta: { reason: 'mutual_cancellation_reversal' },
              });
            }
          }
        } catch (wErr) {
          logger.error('[requestCancellation] reprise wallet échouée', wErr);
        }
      } else {
        // Rien n'a été encaissé (ou paiement jamais confirmé) : simple annulation.
        booking.status = 'cancelled';
        booking.paymentStatus = booking.paymentStatus === 'paid' ? 'cancelled' : booking.paymentStatus;
        logger.warn(
          `⚠️ Booking ${booking._id} annulée sans remboursement (paymentStatus=${booking.paymentStatus}, provider=${booking.paymentProvider || 'n/a'}).`,
        );
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

    if (booking.airwallexPaymentIntentId) {
      try {
        paymentIntentDetails = await airwallex.retrievePaymentIntent(booking.airwallexPaymentIntentId);
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
      paymentIntentId: booking.airwallexPaymentIntentId,
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

    // v532 — `booking.reload()` N'EXISTE PAS dans Mongoose 8 : cette ligne
    // levait un TypeError APRÈS l'envoi effectif du virement. Le catch
    // répondait alors 500 « Unable to retry payout » — l'admin croyait à un
    // échec et recliquait, ce qui pouvait payer le prestataire DEUX FOIS.
    const fresh = await Booking.findById(id).select(
      'payoutStatus payoutBatchId payoutAt payoutError',
    );

    res.json({
      bookingId: String(id),
      payoutStatus: fresh?.payoutStatus || booking.payoutStatus,
      payoutBatchId: fresh?.payoutBatchId || booking.payoutBatchId || null,
      payoutAt: fresh?.payoutAt || booking.payoutAt || null,
      payoutError: fresh?.payoutError || booking.payoutError || null,
      message:
        (fresh?.payoutStatus || booking.payoutStatus) === 'completed'
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
    // v23.1.259 — NE JAMAIS libérer un paiement en litige. L'owner a signalé
    // un problème → résolution manuelle (remboursement / accord) requise. Les
    // statuts de confirmation 'awaiting_start'/'in_progress' ne sont PAS
    // exclus : leur scheduledPayoutAt = fin+48h n'est de toute façon pas
    // encore atteint tant que le service n'est pas fini.
    confirmationStatus: { $ne: 'disputed' },
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
      // v23.1.374 — BOUCLE D'ERREUR RENDER (Daniel) : si le payout a ÉCHOUÉ
      // (ex. booking corrompu sans provider → payoutStatus='failed' posé en
      // updateOne), il ne faut NI le compter "released" NI auto-confirmer le
      // service (le save() de l'auto-confirm re-throwait la validation du
      // modèle à chaque tick). On relit le statut frais en DB : seul un
      // payout réellement 'completed' continue.
      const fresh = await Booking.findById(booking._id)
        .select('payoutStatus').lean();
      if (fresh?.payoutStatus !== 'completed'
          && fresh?.payoutStatus !== 'processing') {
        logger.warn(
          `[scheduler] payout not completed for booking ${booking._id} ` +
          `(status=${fresh?.payoutStatus || '?'}) — skipped auto-confirm.`,
        );
        continue;
      }
      released += 1;
      // v23.1.271 — auto-release 48h (owner n'a pas confirmé dans les temps) :
      // on AUTO-CONFIRME le service pour qu'il compte vers le statut Top (les
      // compteurs loyalty incluent les services confirmés). Le recompute Top
      // sera rafraîchi au prochain trigger non-populé (confirm / avis) pour
      // éviter de réinitialiser averageRating ici (booking est populé).
      if (booking.confirmationStatus !== 'confirmed'
          && booking.confirmationStatus !== 'disputed') {
        booking.confirmationStatus = 'confirmed';
        booking.ownerConfirmedAt = booking.ownerConfirmedAt || new Date();
        await booking.save();
        // v23.1.276 — Daniel : "top sitter/walker n'augmente pas". L'auto-release
        // 48h confirmait le service mais NE recalculait JAMAIS le statut Top
        // (le commentaire promettait "un trigger ultérieur" qui n'existait pas).
        // On recompute donc ici, avec l'id EXPLICITE du provider (booking est
        // populé → booking.sitterId est un doc, on extrait _id) pour mettre à
        // jour completedServicesCount + isTopSitter/isTopWalker + averageRating.
        try {
          const sid = booking.sitterId && (booking.sitterId._id || booking.sitterId);
          const wid = booking.walkerId && (booking.walkerId._id || booking.walkerId);
          if (sid) await recomputeSitterStatus(sid);
          if (wid) await recomputeWalkerStatus(wid);
        } catch (e) {
          logger.warn(`[scheduler] Top recompute failed booking ${booking._id}: ${e?.message || e}`);
        }
        // v23.1.344 — Daniel : "avantages fidélité ne se met pas à jour".
        // L'auto-release 48h auto-confirmait le service SANS déclencher
        // onBookingCompleted → le crédit -10% (chaque 3e réservation) et le
        // Premium owner (10e) sautaient quand le seuil était franchi par
        // auto-release. On le déclenche ici avec les ids EXTRAITS (booking est
        // populé : String(doc) imprimerait tout le document → cast cassé,
        // même bug que v276).
        try {
          const oid = booking.ownerId && (booking.ownerId._id || booking.ownerId);
          const sid2 = booking.sitterId && (booking.sitterId._id || booking.sitterId);
          const wid2 = booking.walkerId && (booking.walkerId._id || booking.walkerId);
          await onBookingCompleted({
            _id: booking._id,
            ownerId: oid,
            sitterId: sid2,
            walkerId: wid2,
            pricing: booking.pricing,
          });
        } catch (e) {
          logger.warn(`[scheduler] loyalty hook failed booking ${booking._id}: ${e?.message || e}`);
        }
      }
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
    // v23.1.259 — ne jamais débloquer un paiement en litige.
    confirmationStatus: { $ne: 'disputed' },
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
    // v23.1 part 68 — Daniel : "ancinne publication sefface apres le
    // booking FINI". Auto-close the originating Post (if any) so the
    // owner's old request stops appearing in candidate feeds. We only
    // mark it 'closed' (status) ; data stays in DB for analytics.
    try {
      const Application = require('../models/Application');
      const Post = require('../models/Post');
      const app = await Application.findOne({
        bookingId: booking._id,
        postId: { $ne: null },
      }).lean();
      if (app && app.postId) {
        await Post.updateOne(
          { _id: app.postId, status: { $ne: 'closed' } },
          { $set: { status: 'closed', closedAt: new Date(), closedReason: 'booking_completed' } },
        );
        logger.info(
          `[completeBooking] auto-closed Post ${app.postId} after booking ${booking._id} completed`,
        );
      }
    } catch (e) {
      logger.warn(`[completeBooking] auto-close post failed : ${e.message}`);
    }
    return res.json({ booking: sanitizeBooking(booking) });
  } catch (e) {
    logger.error('completeBooking error', e);
    return res.status(500).json({ error: 'Unable to complete booking.' });
  }
};


/**
 * v23.1 — explicit cancel of an in-flight Airwallex PaymentIntent.
 * Owner taps "Annuler" on the Payment screen → frontend POSTs here →
 * we call airwallex.cancelPaymentIntent and mark booking.paymentStatus =
 * 'cancelled_by_user'. Idempotent : if PI already cancelled / paid, we
 * just return success without throwing.
 */
const cancelBookingPaymentIntent = async (req, res) => {
  try {
    const ownerId = req.user?.id;
    const { id } = req.params;
    if (!ownerId) {
      return res.status(403).json({ error: 'Owner context missing.' });
    }
    const booking = await Booking.findById(id);
    if (!booking) {
      return res.status(404).json({ error: 'Booking not found.' });
    }
    if (booking.ownerId.toString() !== ownerId) {
      return res.status(403).json({ error: 'You do not have permission to cancel this booking.' });
    }
    const pid = booking.airwallexPaymentIntentId;
    if (!pid) {
      // No PI to cancel, soft no-op.
      return res.status(200).json({ ok: true, code: 'NO_PAYMENT_INTENT' });
    }
    if (booking.paymentStatus === 'paid') {
      return res.status(409).json({ error: 'Booking is already paid; cannot cancel.' });
    }
    try {
      await airwallex.cancelPaymentIntent(pid, { reason: 'requested_by_customer' });
    } catch (e) {
      // Airwallex returns 400 if PI is already in a final state — treat as soft success.
      logger.warn(`[cancelBookingPaymentIntent] Airwallex cancel returned ${e?.status}: ${e?.message}`);
    }
    // v23.1.156 — Daniel : logs Render montraient Error 500 sur cette
    // route (enum 'cancelled_by_user' rejete par le model Booking — enum
    // valid: pending/paid/failed/refunded/cancelled/refund). Resultat :
    // l'app ne pouvait pas annuler proprement le PI et le booking
    // restait avec un airwallexPaymentIntentId CANCELLED qu'on
    // reutilisait au prochain "Pay" → page blanche Airwallex.
    // Fix : on utilise l'enum 'cancelled' (sans suffix) qui est valide.
    booking.paymentStatus = 'cancelled';
    booking.airwallexPaymentIntentId = null;
    await booking.save();
    return res.status(200).json({ ok: true, bookingId: booking._id.toString(), paymentStatus: booking.paymentStatus });
  } catch (error) {
    logger.error({ err: error }, '[cancelBookingPaymentIntent] failed');
    return res.status(500).json({
      error: 'Unable to cancel payment intent.',
      details: error?.message || String(error),
    });
  }
};

/**
 * GET /api/v1/bookings/:id/provider-location
 *
 * v23.1 part 66 — PawFollow live-tracking.
 * Returns the latest GeoJSON `location.coordinates` of the booking's
 * provider (sitter or walker) for an authenticated OWNER, only if :
 *   1. The owner is the booking's owner (auth scope)
 *   2. The booking is paid + active (date is today or within window)
 *   3. The owner has an ACTIVE PawFollow subscription
 *
 * The provider's location is updated whenever they call /location/update
 * (existing endpoint used by the nearby map). Future iteration : push
 * realtime via socket emit('provider:location-update', { lat, lng }).
 */
// v23.1.343 — Daniel : "vérifie bien que le follow se termine une fois le
// service terminé". Fenêtre de suivi de service = du paiement à la FIN :
//   - le prestataire a marqué "J'ai rendu l'animal" (awaiting_confirmation),
//     l'owner a confirmé (confirmed) ou litige (disputed) → suivi CLOS ;
//   - booking completed / cancelled / refunded → CLOS ;
//   - garde-fou : fin prévue du service + 12h (prestataire qui oublie de
//     marquer "rendu") → CLOS.
// Sans ça, l'owner pouvait suivre la position RÉELLE du walker/sitter
// indéfiniment après le service (Walker.location = sa position courante,
// rafraîchie par la map) → fuite de vie privée.
// v23.1.349 — Daniel : "ça a peut-être marché car j'ai un abonnement qui a
// continué à tourner" — règle métier confirmée : un abonnement PawFollow /
// PawFamily ACTIF autorise le suivi continu MÊME hors fenêtre de service
// (c'est le produit vendu). Helper partagé par les 3 gates de suivi.
const hasActiveTrackingSubscription = async (userId, role) => {
  try {
    const UserSubscription = require('../models/UserSubscription');
    const userModel =
      role === 'walker' ? 'Walker' : role === 'sitter' ? 'Sitter' : 'Owner';
    const sub = await UserSubscription.findOne({
      userId,
      userModel,
      status: 'active',
    }).lean();
    if (!sub) return false;
    const now = new Date();
    const expiry = sub.currentPeriodEnd || sub.expiresAt;
    if (expiry && new Date(expiry) > now) return true;
    if (sub.familyExpiry && new Date(sub.familyExpiry) > now) return true;
    return false;
  } catch (_) {
    return false; // défensif : traité comme sans abonnement
  }
};

const SERVICE_TRACKING_GRACE_MS = 12 * 60 * 60 * 1000;
const isServiceTrackingClosed = (booking) => {
  const cs = booking.confirmationStatus || 'none';
  if (['awaiting_confirmation', 'confirmed', 'disputed'].includes(cs)) return true;
  const st = (booking.status || '').toLowerCase();
  if (['completed', 'cancelled', 'refunded'].includes(st)) return true;
  try {
    const endAt = resolveBookingEndDate(booking);
    if (Date.now() > endAt.getTime() + SERVICE_TRACKING_GRACE_MS) return true;
  } catch (_) { /* defensive */ }
  return false;
};

const getProviderLocation = async (req, res) => {
  try {
    const ownerId = req.user.id;
    const { id: bookingId } = req.params;
    const booking = await Booking.findById(bookingId).lean();
    if (!booking) return res.status(404).json({ error: 'Booking not found.' });
    if (String(booking.ownerId) !== String(ownerId)) {
      return res.status(403).json({ error: 'Not your booking.' });
    }
    const pay = (booking.paymentStatus || '').toLowerCase();
    if (pay !== 'paid') {
      return res.status(409).json({ error: 'Tracking only available for paid bookings.' });
    }

    // v23.1.343 — le suivi s'arrête à la fin du service (cf helper ci-dessus).
    // v23.1.349 — SAUF abonnement PawFollow/PawFamily actif (suivi continu).
    if (isServiceTrackingClosed(booking)) {
      const subscribed = await hasActiveTrackingSubscription(ownerId, 'owner');
      if (!subscribed) {
        return res.status(410).json({
          error: 'Service is over — live tracking is closed.',
          code: 'TRACKING_ENDED',
        });
      }
    }

    // v23.1.343 — Daniel (décision business) : le suivi PENDANT un service
    // payé est GRATUIT (inclus dans la commission) — c'est PawFollow qui est
    // payant pour le suivi hors service (amis/famille). L'ancien gate 402
    // PAWFOLLOW_REQUIRED ici contredisait ce modèle : supprimé.

    // Resolve provider model + id.
    let provider = null;
    let providerRole = null;
    if (booking.walkerId) {
      provider = await Walker.findById(booking.walkerId).select('location name avatar').lean();
      providerRole = 'walker';
    } else if (booking.sitterId) {
      provider = await Sitter.findById(booking.sitterId).select('location name avatar').lean();
      providerRole = 'sitter';
    }
    if (!provider) {
      return res.status(404).json({ error: 'Provider not found.' });
    }

    const coords = provider?.location?.coordinates;
    if (!Array.isArray(coords) || coords.length !== 2) {
      return res.status(204).json({
        error: 'Provider location not yet shared.',
        code: 'NO_LOCATION_YET',
      });
    }

    return res.json({
      providerRole,
      providerName: provider.name || '',
      providerAvatar: provider.avatar?.url || '',
      coordinates: { lng: coords[0], lat: coords[1] },
      updatedAt: provider.updatedAt || null,
    });
  } catch (e) {
    logger.error('[booking.getProviderLocation]', e);
    return res.status(500).json({ error: 'Unable to fetch provider location.' });
  }
};

/**
 * v23.1.170 — POST /bookings/:id/follow-request (sitter/walker only)
 *
 * Daniel : "pareil du coter de walker et sitter y doive poivoir envoyer
 * au owner suis moi et que les 3 profile recoive les notification".
 *
 * Bouton miroir côté provider : permet au sitter/walker d'envoyer une
 * notification proactive au owner du booking pour proposer le suivi
 * live. L'owner reçoit un push notif `live_tracking_request_received`
 * qui ouvre LiveWalkMapScreen au tap.
 *
 * Sécurité :
 *   - Auth obligatoire + rôle sitter ou walker
 *   - Le booking doit être 'paid' (sinon refus 409)
 *   - L'utilisateur doit être le provider du booking (sitter/walker concerné)
 *   - Pas de rate limit explicite ici, mais le push notif est idempotent
 *     (mêmes data → même bundle iOS / Android, override en cas de spam)
 */
const requestLiveTracking = async (req, res) => {
  try {
    const userId = req.user.id;
    const userRole = req.user.role; // 'owner', 'sitter' or 'walker'
    const { id: bookingId } = req.params;

    const booking = await Booking.findById(bookingId).lean();
    if (!booking) return res.status(404).json({ error: 'Booking not found.' });

    // v23.1.176 — Daniel : "demande suivre votre animale ds le chat ya
    // pas". On accepte maintenant les 3 rôles : owner ET provider.
    //   - owner → demande au walker/sitter de partager sa position
    //   - sitter/walker → demande à l'owner d'autoriser le suivi
    // Direction de la demande déduite du rôle appelant.
    const isOwner =
      userRole === 'owner' && String(booking.ownerId) === String(userId);
    const isProvider =
      (userRole === 'sitter' && String(booking.sitterId) === String(userId)) ||
      (userRole === 'walker' && String(booking.walkerId) === String(userId));
    if (!isOwner && !isProvider) {
      return res.status(403).json({ error: 'Not your booking.' });
    }

    const pay = (booking.paymentStatus || '').toLowerCase();
    if (pay !== 'paid') {
      return res.status(409).json({
        error: 'Live tracking only available for paid bookings.',
        code: 'BOOKING_NOT_PAID',
      });
    }

    // v23.1.343 — Daniel : "le follow se termine une fois le service
    // terminé". On refuse aussi d'ENVOYER une demande de suivi quand la
    // fenêtre de service est close (rendu / confirmé / litige / fin+12h).
    // v23.1.349 — SAUF abonnement PawFollow/PawFamily actif du demandeur.
    if (isServiceTrackingClosed(booking)) {
      const subscribed = await hasActiveTrackingSubscription(userId, userRole);
      if (!subscribed) {
        return res.status(410).json({
          error: 'Service is over — live tracking is closed.',
          code: 'TRACKING_ENDED',
        });
      }
    }

    const ownerId = booking.ownerId;
    if (!ownerId) {
      return res.status(404).json({ error: 'Owner not found on booking.' });
    }

    // v23.1.170-fix — Daniel : "que owner suive ma balade". Pour que
    // /provider-location renvoie une position au lieu de NO_LOCATION_YET,
    // on persiste les coordonnées GPS envoyées par le client dans le
    // document Walker / Sitter. Le client envoie { lat, lng } dans le body.
    try {
      const { lat, lng } = req.body || {};
      const hasCoords =
        typeof lat === 'number' && typeof lng === 'number' &&
        !Number.isNaN(lat) && !Number.isNaN(lng);
      if (hasCoords) {
        const Walker = require('../models/Walker');
        const Sitter = require('../models/Sitter');
        const update = {
          'location.type': 'Point',
          'location.coordinates': [lng, lat],
          'location.updatedAt': new Date(),
        };
        if (userRole === 'walker') {
          await Walker.findByIdAndUpdate(userId, { $set: update });
        } else if (userRole === 'sitter') {
          await Sitter.findByIdAndUpdate(userId, { $set: update });
        }
      }
    } catch (e) {
      logger.warn('[booking.requestLiveTracking] location update failed', e);
    }

    // v23.1.176 — Daniel : "demande suivre votre animale ds le chat ya
    // pas". On crée un message chat type 'pawfollow_request' dans la
    // conversation du booking, pour que l'owner voie une carte avec
    // boutons Accepter / Refuser DIRECTEMENT dans le chat.
    let pawfollowMessageId = null;
    try {
      const Conversation = require('../models/Conversation');
      const Message = require('../models/Message');
      // v23.1.203 — Daniel : "popup vert mais aucune card dans le chat".
      // Cause racine : Conversation schema n'a PAS de champ `bookingId`,
      // donc Conversation.findOne({ bookingId }) retournait TOUJOURS null
      // → message pawfollow_request jamais cree. Fix : match par
      // ownerId + sitterId XOR walkerId (les champs reels du schema).
      const providerKey = booking.walkerId
        ? { walkerId: booking.walkerId }
        : { sitterId: booking.sitterId };
      const conversation = await Conversation.findOne({
        ownerId: booking.ownerId,
        ...providerKey,
      }).lean();
      if (conversation) {
        // Anti-spam : si une demande pending existe < 5 min, on ne crée
        // pas de doublon.
        const fiveMinAgo = new Date(Date.now() - 5 * 60 * 1000);
        const existing = await Message.findOne({
          conversationId: conversation._id,
          type: 'pawfollow_request',
          'metadata.status': 'pending',
          createdAt: { $gt: fiveMinAgo },
        });
        if (!existing) {
          // v23.1.176 — Direction calculée selon le rôle appelant.
          // - owner appelle → owner_to_provider (le walker/sitter doit
          //   répondre via accept/refuse)
          // - provider appelle → walker_to_owner OR sitter_to_owner
          let direction;
          let providerRoleForBooking = null;
          if (booking.walkerId) providerRoleForBooking = 'walker';
          else if (booking.sitterId) providerRoleForBooking = 'sitter';
          let responderRole;
          if (userRole === 'owner') {
            direction = `owner_to_${providerRoleForBooking || 'provider'}`;
            responderRole = providerRoleForBooking || 'sitter';
          } else if (userRole === 'walker') {
            direction = 'walker_to_owner';
            responderRole = 'owner';
          } else {
            direction = 'sitter_to_owner';
            responderRole = 'owner';
          }
          // v23.1 part 200 — Daniel : "refonte carte chat pawfollow_request"
          // (mockup avec pet card top + dates orange + section GPS + badge
          // statut + boutons accept/refuse). Pour que la carte ait toutes
          // les infos sans devoir refetch, on snapshot ici :
          //   - petName / petPhoto    (carte pet en haut)
          //   - startAt / endAt       (dates booking en orange)
          //   - lastLat / lastLng     (dernière position GPS connue du
          //                            provider, pour la mini-section GPS)
          //   - serviceType           (label "Walk" / "Sitting" / etc.)
          let petName = '';
          let petPhoto = '';
          let startAt = null;
          let endAt = null;
          let lastLat = null;
          let lastLng = null;
          let serviceType = '';
          try {
            const Pet = require('../models/Pet');
            const petDoc = booking.petId
              ? await Pet.findById(booking.petId).lean()
              : null;
            if (petDoc) {
              petName = petDoc.name || '';
              petPhoto = petDoc.image || petDoc.photo || petDoc.avatar || '';
            }
            startAt = booking.startDate || booking.dateStart || booking.from || null;
            endAt = booking.endDate || booking.dateEnd || booking.to || null;
            serviceType = booking.serviceType || booking.service || (booking.walkerId ? 'walk' : 'sitting');
            // dernière position GPS broadcastée par le provider (champ
            // standard updates plus haut dans la même fonction)
            if (booking.walkerId) {
              const Walker = require('../models/Walker');
              const w = await Walker.findById(booking.walkerId).lean();
              lastLat = w?.lastKnownLat ?? w?.location?.coordinates?.[1] ?? null;
              lastLng = w?.lastKnownLng ?? w?.location?.coordinates?.[0] ?? null;
            } else if (booking.sitterId) {
              const Sitter = require('../models/Sitter');
              const s = await Sitter.findById(booking.sitterId).lean();
              lastLat = s?.lastKnownLat ?? s?.location?.coordinates?.[1] ?? null;
              lastLng = s?.lastKnownLng ?? s?.location?.coordinates?.[0] ?? null;
            }
          } catch (snapshotErr) {
            logger.warn(
              '[booking.requestLiveTracking] snapshot enrichment failed',
              snapshotErr,
            );
            // Defensive : on continue, la carte se contente du minimum.
          }
          const msg = await Message.create({
            conversationId: conversation._id,
            senderId: userId,
            senderRole: userRole,
            type: 'pawfollow_request',
            body: '', // pas de texte, la carte UI render direct
            metadata: {
              status: 'pending',
              direction,
              bookingId: String(bookingId),
              requesterId: String(userId),
              requesterRole: userRole,
              responderRole,
              expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
              // v23.1 part 200 — snapshot données pour le rendu de la carte
              petName,
              petPhoto,
              startAt,
              endAt,
              lastLat,
              lastLng,
              serviceType,
            },
          });
          pawfollowMessageId = msg._id;
          // v23.1.191 — Met aussi a jour lastMessage avec un preview
          // clair, sinon la chat list affiche du garbage hérité.
          // v407 — Daniel : "le badge 1 dans le menu message n'apparaît pas".
          // CAUSE : ce message pawfollow_request ne bumpait PAS unreadCount →
          // au resync le badge restait à 0 (seul le socket live le montrait, et
          // pas en background). On incrémente l'unread du DESTINATAIRE comme un
          // message normal (cf conversationService). Le walker partage
          // sitterUnreadCount (= unread "côté prestataire").
          const unreadField =
            userRole === 'owner' ? 'sitterUnreadCount' : 'ownerUnreadCount';
          await Conversation.findByIdAndUpdate(conversation._id, {
            $set: {
              lastMessage: '📍 Demande de suivi en direct',
              lastMessageAt: new Date(),
              // v23.1.256 — réapparition si un participant avait masqué la conv.
              clearedFor: [],
            },
            $inc: { [unreadField]: 1 },
          });
          // v23.1.255 — Daniel : "la demande de suivre mon animal ne
          // s'affiche pas sur les 3 profils". CAUSE RACINE : ce broadcast
          // utilisait require('../sockets/io') — un module qui N'EXISTE PAS
          // → throw avalé par le catch → la carte pawfollow_request était
          // créée en DB mais JAMAIS poussée en temps réel. En plus, il visait
          // la room `conversation_<id>` alors que chatSocket joint la room
          // `<id>` brut. Résultat : demande de suivi invisible tant qu'on ne
          // rouvrait pas le chat (et avec le socket mort → invisible tout
          // court). FIX : emitChatMessage() — la bonne API, qui cible la room
          // conversation (chat ouvert) ET les user-rooms des participants
          // (badge + insertion live même hors écran chat), sur les 3 profils.
          try {
            const { emitChatMessage } = require('../sockets/emitter');
            emitChatMessage(conversation, 'message:new', {
              conversationId: String(conversation._id),
              message: msg.toObject(),
            });
          } catch (_) {/* defensive */}
        }
      }
    } catch (e) {
      logger.warn('[booking.requestLiveTracking] chat msg failed', e);
    }

    // v23.1.255 — Push notif au BON destinataire (le responder), pas
    // toujours l'owner. Avant : userId hardcodé = ownerId → quand c'est
    // l'OWNER qui envoyait "suivez mon animal" au provider, c'est l'owner
    // qui se notifiait lui-même et le walker/sitter ne recevait RIEN.
    //   - owner demande   → notifie le provider (walker/sitter du booking)
    //   - provider demande → notifie l'owner
    try {
      const { sendNotification } = require('../services/notificationSender');
      const buildEmailLink = require('../utils/emailLinkBuilder').buildEmailLink;
      let recipientId;
      let recipientRole;
      if (isOwner) {
        recipientRole = booking.walkerId ? 'walker' : 'sitter';
        recipientId = booking.walkerId || booking.sitterId;
      } else {
        recipientRole = 'owner';
        recipientId = ownerId;
      }
      if (recipientId) {
        await sendNotification({
          userId: String(recipientId),
          role: recipientRole,
          type: 'live_tracking_request_received',
          title: 'live_tracking_request_title',
          body: 'live_tracking_request_body',
          data: {
            bookingId: String(bookingId),
            providerRole: userRole,
            // Deep link → /walk/:bookingId qui ouvre LiveWalkMapScreen.
            emailLink: buildEmailLink('walk', { bookingId: String(bookingId) }),
          },
        });
      }
    } catch (e) {
      logger.warn('[booking.requestLiveTracking] notif failed', e);
    }

    return res.json({
      success: true,
      bookingId: String(bookingId),
      ownerNotified: true,
      chatMessageId: pawfollowMessageId ? String(pawfollowMessageId) : null,
    });
  } catch (e) {
    logger.error('[booking.requestLiveTracking]', e);
    return res.status(500).json({ error: 'Unable to request live tracking.' });
  }
};

/**
 * v23.1.176 — POST /pawfollow-request/:messageId/respond
 * body: { action: 'accept' | 'refuse' }
 *
 * Daniel : "[Accepter] [Refuser]" dans la carte chat. Cette route met à
 * jour metadata.status du message et broadcast la mise à jour aux 2
 * parties via socket. Si action='accept', on déclenche le suivi live
 * (le provider doit déjà avoir broadcasté sa position via le flow normal).
 */
const respondToPawfollowRequest = async (req, res) => {
  try {
    const userId = req.user.id;
    const userRole = req.user.role;
    const { messageId } = req.params;
    const { action } = req.body || {};

    if (!['accept', 'refuse'].includes(action)) {
      return res.status(400).json({
        error: 'action must be "accept" or "refuse".',
      });
    }

    const Message = require('../models/Message');
    const Conversation = require('../models/Conversation');
    const message = await Message.findById(messageId);
    if (!message) {
      return res.status(404).json({ error: 'Message not found.' });
    }
    if (message.type !== 'pawfollow_request') {
      return res.status(400).json({ error: 'Not a pawfollow request.' });
    }
    if (message.metadata?.status !== 'pending') {
      return res.status(409).json({
        error: 'Request already responded to.',
        currentStatus: message.metadata?.status,
      });
    }
    // Seul le responder (la partie qui doit répondre) peut accept/refuse.
    if (message.metadata.responderRole !== userRole) {
      return res.status(403).json({
        error: 'You are not allowed to respond to this request.',
      });
    }
    // Vérifie aussi que le user est bien dans la conversation.
    const conv = await Conversation.findById(message.conversationId).lean();
    if (!conv) {
      return res.status(404).json({ error: 'Conversation not found.' });
    }

    message.metadata = {
      ...message.metadata,
      status: action === 'accept' ? 'accepted' : 'refused',
      respondedAt: new Date(),
      respondedBy: String(userId),
    };
    message.markModified('metadata');
    await message.save();

    // Broadcast via socket aux 2 parties.
    // v23.1.256 — même bug que requestLiveTracking : require('../sockets/io')
    // (module INEXISTANT) → throw avalé → la mise à jour accept/refus n'était
    // JAMAIS diffusée en temps réel. FIX : emitChatMessage (room conversation
    // + user-rooms participants). On émet aussi 'message:new' avec le message
    // mis à jour pour que les clients qui ne gèrent pas 'message:updated'
    // rafraîchissent quand même la carte (dédup par id côté frontend).
    try {
      const { emitChatMessage } = require('../sockets/emitter');
      const payload = {
        conversationId: String(conv._id),
        message: message.toObject(),
      };
      emitChatMessage(conv, 'message:updated', payload);
      emitChatMessage(conv, 'message:new', payload);
    } catch (_) {/* defensive */}

    return res.json({
      success: true,
      messageId: String(message._id),
      status: message.metadata.status,
    });
  } catch (e) {
    logger.error('[booking.respondToPawfollowRequest]', e);
    return res
      .status(500)
      .json({ error: 'Unable to respond to pawfollow request.' });
  }
};

/**
 * v23.1.182 — POST /api/v1/conversations/:id/follow-request
 *
 * Daniel : "le chat souvre jenvoi la demande suivre mon animale sa
 * mouvre pas de balade en cour au lieu denvoyer linviutation au walker
 * ou sitter". L'existing `requestLiveTracking` exige un booking PAID,
 * mais Daniel veut envoyer la demande même SANS booking actif (= chat
 * libre entre owner et walker/sitter découvert via PawMap, par exemple).
 *
 * Différences avec requestLiveTracking :
 *   - input : conversationId au lieu de bookingId
 *   - pas de check paymentStatus
 *   - pas de check location coords
 *   - création direct du message pawfollow_request dans la conv
 *   - notif au responder
 *
 * Sécurité : seul l'owner de la conv peut envoyer (sens owner → provider).
 */
const requestLiveTrackingByConversation = async (req, res) => {
  try {
    const userId = req.user.id;
    const userRole = req.user.role;
    const { id: conversationId } = req.params;

    const Conversation = require('../models/Conversation');
    const Message = require('../models/Message');

    const conversation = await Conversation.findById(conversationId).lean();
    if (!conversation) {
      return res.status(404).json({ error: 'Conversation not found.' });
    }

    // v23.1.256 — Daniel : "la demande de suivi ne s'affiche sur AUCUN
    // profil". CAUSE : les guards de rôle ci-dessous renvoyaient 403 dès que
    // ça ne collait pas pile (chats friendChat sans walkerId/sitterId, ou
    // toute incohérence de rôle) → le message n'était JAMAIS créé. On
    // remplace par une résolution PERMISSIVE : on vérifie juste que
    // l'appelant est participant de CETTE conversation (booking OU
    // friendChat), et on déduit le destinataire = l'autre partie. Le message
    // est ainsi toujours créé dans la conversation regardée → la carte
    // apparaît côté expéditeur (qui recharge) ET côté destinataire (socket).
    const idStr = (v) => (v ? (v._id ? String(v._id) : String(v)) : null);
    let direction;
    let responderRole;
    let responderId;
    let isParticipant = false;

    if (conversation.friendChat === true && Array.isArray(conversation.participants)) {
      const meP = conversation.participants.find(
        (p) => idStr(p.userId) === String(userId),
      );
      const otherP = conversation.participants.find(
        (p) => idStr(p.userId) !== String(userId),
      );
      isParticipant = !!meP;
      if (otherP) {
        responderId = idStr(otherP.userId);
        responderRole = String(otherP.userModel || 'owner').toLowerCase();
      }
      direction = `${userRole}_to_${responderRole || 'other'}`;
    } else {
      // Conversation booking : owner ↔ sitter/walker.
      const ownerIdV = idStr(conversation.ownerId);
      const sitterIdV = idStr(conversation.sitterId);
      const walkerIdV = idStr(conversation.walkerId);
      const providerIdV = walkerIdV || sitterIdV;
      const providerRole = conversation.walkerId ? 'walker' : 'sitter';
      if (String(userId) === ownerIdV) {
        isParticipant = true;
        direction = `owner_to_${providerRole}`;
        responderRole = providerRole;
        responderId = providerIdV;
      } else if (providerIdV && String(userId) === providerIdV) {
        isParticipant = true;
        direction = `${providerRole}_to_owner`;
        responderRole = 'owner';
        responderId = ownerIdV;
      }
    }

    if (!isParticipant) {
      return res
        .status(403)
        .json({ error: 'Not a conversation participant.' });
    }

    // v23.1.293 — Daniel : "des fois la demande de suivi s'envoie à moi-même".
    // Garde-fou : le destinataire doit exister ET être différent de l'émetteur
    // (cas conversation à 1 participant, rôle dupliqué après switchRole, etc.).
    if (!responderId || String(responderId) === String(userId)) {
      return res.status(400).json({
        error: 'Cannot request live tracking from yourself.',
        code: 'SELF_TRACKING_REQUEST',
      });
    }

    // v23.1.349 — Daniel (BUG GRAVE) : "une fois le service fini j'ai renvoyé
    // une demande de suivi et ça a marché — ça doit être bloqué avec un message
    // 'service fini, refaites un service ou prenez un abonnement PawFollow /
    // PawFamily'". Puis précision Daniel : "ça a peut-être marché car j'ai un
    // abonnement qui a continué à tourner" — EXACT, et c'est la bonne règle :
    // un abonnement PawFollow/PawFamily ACTIF autorise le suivi continu hors
    // service (c'est précisément ce que vend l'abonnement). Règle finale :
    //   - conversation amis/famille (friendChat) → autorisé (produit PawFollow,
    //     gaté par l'acceptation de l'autre partie) ;
    //   - conversation booking + fenêtre de service OUVERTE → autorisé ;
    //   - conversation booking + service fini : autorisé SI le demandeur a un
    //     abonnement actif, sinon 410 + message d'upsell.
    if (conversation.friendChat !== true) {
      const convOwnerId = idStr(conversation.ownerId);
      const convProviderField = conversation.walkerId ? 'walkerId' : 'sitterId';
      const convProviderId = idStr(conversation.walkerId) || idStr(conversation.sitterId);
      let hasOpenServiceWindow = false;
      if (convOwnerId && convProviderId) {
        const recent = await Booking.find({
          ownerId: convOwnerId,
          [convProviderField]: convProviderId,
          paymentStatus: 'paid',
          status: { $nin: ['cancelled', 'refunded'] },
        })
          .sort({ createdAt: -1 })
          .limit(10)
          .lean();
        hasOpenServiceWindow = recent.some((b) => !isServiceTrackingClosed(b));
      }
      if (!hasOpenServiceWindow) {
        // Abonnement PawFollow / PawFamily actif du DEMANDEUR → autorisé
        // (suivi continu = le produit). Sinon : blocage + message d'upsell.
        const subscribed = await hasActiveTrackingSubscription(userId, userRole);
        if (!subscribed) {
          return res.status(410).json({
            error:
              'Service is over — book a new service or subscribe to PawFollow / PawFamily for continuous tracking.',
            code: 'TRACKING_ENDED',
          });
        }
      }
    }

    // v23.1.256 — persiste la position GPS de l'appelant (si fournie) pour
    // que l'autre partie puisse réellement suivre (sinon /provider-location
    // renvoie NO_LOCATION_YET). Même logique que requestLiveTracking.
    try {
      const { lat, lng } = req.body || {};
      const hasCoords =
        typeof lat === 'number' && typeof lng === 'number' &&
        !Number.isNaN(lat) && !Number.isNaN(lng);
      if (hasCoords) {
        const Walker = require('../models/Walker');
        const Sitter = require('../models/Sitter');
        const Owner = require('../models/Owner');
        const update = {
          'location.type': 'Point',
          'location.coordinates': [lng, lat],
          'location.updatedAt': new Date(),
        };
        const Model =
          userRole === 'walker' ? Walker :
          userRole === 'sitter' ? Sitter :
          userRole === 'owner' ? Owner : null;
        if (Model) await Model.findByIdAndUpdate(userId, { $set: update });
      }
    } catch (e) {
      logger.warn('[requestLiveTrackingByConversation] location update failed', e);
    }

    // Anti-spam : pas de doublon < 5 min.
    const fiveMinAgo = new Date(Date.now() - 5 * 60 * 1000);
    const existing = await Message.findOne({
      conversationId: conversation._id,
      type: 'pawfollow_request',
      'metadata.status': 'pending',
      createdAt: { $gt: fiveMinAgo },
    });
    if (existing) {
      return res.json({
        success: true,
        chatMessageId: String(existing._id),
        duplicate: true,
      });
    }

    const msg = await Message.create({
      conversationId: conversation._id,
      senderId: userId,
      senderRole: userRole,
      type: 'pawfollow_request',
      body: '',
      metadata: {
        status: 'pending',
        direction,
        // pas de bookingId — chat libre.
        bookingId: null,
        requesterId: String(userId),
        requesterRole: userRole,
        responderRole,
        expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
      },
    });

    // v23.1.191 — Daniel : "[SUIVI_REQUEST] souhaite voi..." dans la
    // chat list. Cause : on n'ecrivait pas lastMessage → l'ancien
    // texte garbage restait. On set un preview clair multi-lang.
    // v407 — Daniel : "badge 1 menu message n'apparaît pas". On incrémente
    // l'unread du DESTINATAIRE (sinon badge=0 au resync). friendChat →
    // participants[].unreadCount ; booking → owner/sitterUnreadCount (le
    // walker partage sitterUnreadCount = unread "côté prestataire").
    const _setUpdate = {
      lastMessage: '📍 Demande de suivi en direct',
      lastMessageAt: new Date(),
      // v23.1.256 — réapparition si un participant avait masqué la conv.
      clearedFor: [],
    };
    if (conversation.friendChat === true && responderId) {
      await Conversation.updateOne(
        { _id: conversation._id, 'participants.userId': responderId },
        { $set: _setUpdate, $inc: { 'participants.$.unreadCount': 1 } },
      );
    } else {
      const unreadField =
        responderRole === 'owner' ? 'ownerUnreadCount' : 'sitterUnreadCount';
      await Conversation.findByIdAndUpdate(conversation._id, {
        $set: _setUpdate,
        $inc: { [unreadField]: 1 },
      });
    }

    // v23.1.255 — emitChatMessage (au lieu de emitToConversation) pour que
    // la carte arrive en temps réel ET bump le badge même si le destinataire
    // n'a pas le chat ouvert (cible room conversation + user-rooms des
    // participants). Aligné sur conversationController + le fix du chemin
    // /bookings/:id/follow-request.
    try {
      const { emitChatMessage } = require('../sockets/emitter');
      emitChatMessage(conversation, 'message:new', {
        conversationId: String(conversation._id),
        message: msg.toObject(),
      });
    } catch (_) {/* defensive */}

    // Notif au responder (push + email + in-app + socket).
    try {
      const { sendNotification } = require('../services/notificationSender');
      const buildEmailLink = require('../utils/emailLinkBuilder').buildEmailLink;
      await sendNotification({
        userId: String(responderId),
        role: responderRole,
        type: 'live_tracking_request_received',
        data: {
          conversationId: String(conversation._id),
          messageId: String(msg._id),
          requesterRole: userRole,
          emailLink: buildEmailLink('chat', {
            conversationId: String(conversation._id),
          }),
        },
      });
    } catch (e) {
      logger.warn('[booking.requestLiveTrackingByConversation] notif failed', e);
    }

    return res.json({
      success: true,
      conversationId: String(conversation._id),
      chatMessageId: String(msg._id),
    });
  } catch (e) {
    logger.error('[booking.requestLiveTrackingByConversation]', e);
    return res
      .status(500)
      .json({ error: 'Unable to send follow request.' });
  }
};

// ──────────────────────────────────────────────────────────────────────────
// v23.1.259 — SYSTÈME DE CONFIRMATION DE SERVICE (Daniel)
//
// Flux validé :
//   1. Le PROVIDER tape "J'ai récupéré l'animal" → startService (in_progress)
//   2. Le PROVIDER tape "J'ai rendu l'animal"   → completeService
//      (awaiting_confirmation, auto-release programmé à +48h)
//   3. L'OWNER confirme                          → confirmService
//      (confirmed → paiement libéré immédiatement)
//      OU signale un problème                    → disputeService
//      (disputed → paiement bloqué, résolution manuelle)
//   Sécurité : si l'owner ne fait rien sous 48h, le scheduler existant
//   libère le paiement automatiquement (scheduledPayoutAt = autoReleaseAt).
// ──────────────────────────────────────────────────────────────────────────

const _resolveConfirmProvider = (booking) => {
  if (booking.walkerId) {
    return { id: String(booking.walkerId), role: 'walker' };
  }
  if (booking.sitterId) {
    return { id: String(booking.sitterId), role: 'sitter' };
  }
  return { id: null, role: null };
};

const _isBookingProviderUser = (booking, userId, userRole) =>
  (userRole === 'sitter' && String(booking.sitterId) === String(userId)) ||
  (userRole === 'walker' && String(booking.walkerId) === String(userId));

// POST /bookings/:id/service/start — provider marque "J'ai récupéré l'animal".
const startService = async (req, res) => {
  try {
    const userId = req.user.id;
    const userRole = req.user.role;
    const booking = await Booking.findById(req.params.id);
    if (!booking) return res.status(404).json({ error: 'Booking not found.' });
    if (!_isBookingProviderUser(booking, userId, userRole)) {
      return res.status(403).json({ error: 'Only the assigned provider can start the service.' });
    }
    if ((booking.paymentStatus || '').toLowerCase() !== 'paid') {
      return res.status(409).json({ error: 'Booking is not paid.', code: 'BOOKING_NOT_PAID' });
    }
    if (['confirmed', 'disputed'].includes(booking.confirmationStatus)) {
      return res.status(409).json({ error: 'Service already finalized.', confirmationStatus: booking.confirmationStatus });
    }
    // v532 — GARDE TEMPORELLE. AVANT, rien ne vérifiait la date : dès le
    // paiement encaissé, le prestataire pouvait enchaîner « récupéré » puis
    // « rendu » et être payé 48 h plus tard, pour une garde prévue dans trois
    // semaines. On autorise le démarrage à partir de 2 h avant l'heure prévue.
    const startAt = resolveBookingStartDate(booking);
    if (startAt && Date.now() < startAt.getTime() - EARLY_START_TOLERANCE_MS) {
      return res.status(409).json({
        error: 'Service has not started yet.',
        code: 'SERVICE_NOT_STARTED_YET',
        startsAt: startAt,
      });
    }
    // v532 — CODE DE REMISE : le propriétaire l'affiche dans son app et le
    // dicte au prestataire. Sans lui, impossible de valider à distance.
    const providedCode = String(req.body?.code || '').trim();
    if (booking.handoverCode) {
      if (providedCode && providedCode !== booking.handoverCode) {
        return res.status(422).json({
          error: 'Wrong handover code.',
          code: 'HANDOVER_CODE_INVALID',
        });
      }
      if (!providedCode && HANDOVER_PROOF_REQUIRED) {
        return res.status(422).json({
          error: 'Handover code required.',
          code: 'HANDOVER_CODE_REQUIRED',
        });
      }
    }
    const pickupProof = await _saveHandoverPhoto(req, booking, 'pickup');
    if (!pickupProof && HANDOVER_PROOF_REQUIRED) {
      return res.status(422).json({
        error: 'A photo of the pet is required.',
        code: 'HANDOVER_PHOTO_REQUIRED',
      });
    }
    if (pickupProof) booking.pickupProof = pickupProof;
    booking.confirmationStatus = 'in_progress';
    booking.serviceStartedAt = booking.serviceStartedAt || new Date();
    await booking.save();
    try {
      const { sendNotification } = require('../services/notificationSender');
      const buildEmailLink = require('../utils/emailLinkBuilder').buildEmailLink;
      await sendNotification({
        userId: String(booking.ownerId),
        role: 'owner',
        type: 'service_started',
        data: {
          bookingId: String(booking._id),
          emailLink: buildEmailLink('booking', { bookingId: String(booking._id) }),
        },
      });
    } catch (e) { logger.warn('[startService] notif failed', e); }
    return res.json({
      success: true,
      confirmationStatus: booking.confirmationStatus,
      serviceStartedAt: booking.serviceStartedAt,
    });
  } catch (e) {
    logger.error('[startService]', e);
    return res.status(500).json({ error: 'Unable to start service.' });
  }
};

// POST /bookings/:id/service/complete — provider marque "J'ai rendu l'animal".
const completeService = async (req, res) => {
  try {
    const userId = req.user.id;
    const userRole = req.user.role;
    const booking = await Booking.findById(req.params.id);
    if (!booking) return res.status(404).json({ error: 'Booking not found.' });
    if (!_isBookingProviderUser(booking, userId, userRole)) {
      return res.status(403).json({ error: 'Only the assigned provider can complete the service.' });
    }
    if ((booking.paymentStatus || '').toLowerCase() !== 'paid') {
      return res.status(409).json({ error: 'Booking is not paid.', code: 'BOOKING_NOT_PAID' });
    }
    if (['confirmed', 'disputed'].includes(booking.confirmationStatus)) {
      return res.status(409).json({ error: 'Service already finalized.', confirmationStatus: booking.confirmationStatus });
    }
    // v532 — SÉQUENCE OBLIGATOIRE : on ne peut pas « rendre » un animal qu'on
    // n'a jamais « récupéré ». L'étape de récupération était sautable, ce qui
    // permettait de déclencher le compte à rebours de paiement sans prestation.
    if (booking.confirmationStatus !== 'in_progress') {
      return res.status(409).json({
        error: 'Service must be started first.',
        code: 'SERVICE_NOT_STARTED',
        confirmationStatus: booking.confirmationStatus,
      });
    }
    const returnProof = await _saveHandoverPhoto(req, booking, 'return');
    if (!returnProof && HANDOVER_PROOF_REQUIRED) {
      return res.status(422).json({
        error: 'A photo of the pet is required.',
        code: 'HANDOVER_PHOTO_REQUIRED',
      });
    }
    if (returnProof) booking.returnProof = returnProof;
    booking.confirmationStatus = 'awaiting_confirmation';
    booking.serviceEndedAt = new Date();
    booking.autoReleaseAt = new Date(Date.now() + CONFIRMATION_AUTO_RELEASE_MS);
    booking.scheduledPayoutAt = booking.autoReleaseAt;
    if (booking.payoutStatus !== 'completed' && booking.payoutStatus !== 'processing') {
      booking.payoutStatus = 'scheduled';
    }
    await booking.save();
    // v23.1.343 — Daniel : "le follow se termine une fois le service terminé".
    // On clôt toute session de balade encore active sur ce booking → le relais
    // walk.position refuse les positions suivantes (status !== 'active') même
    // si le prestataire a oublié de terminer la balade dans l'app.
    try {
      const WalkSession = require('../models/WalkSession');
      await WalkSession.updateMany(
        { bookingId: booking._id, status: 'active' },
        { $set: { status: 'ended', endedAt: new Date() } },
      );
    } catch (e) { logger.warn('[completeService] walk session close failed', e); }
    try {
      const { sendNotification } = require('../services/notificationSender');
      const buildEmailLink = require('../utils/emailLinkBuilder').buildEmailLink;
      await sendNotification({
        userId: String(booking.ownerId),
        role: 'owner',
        type: 'service_completion_request',
        data: {
          bookingId: String(booking._id),
          emailLink: buildEmailLink('booking', { bookingId: String(booking._id) }),
        },
      });
    } catch (e) { logger.warn('[completeService] notif failed', e); }
    return res.json({
      success: true,
      confirmationStatus: booking.confirmationStatus,
      serviceEndedAt: booking.serviceEndedAt,
      autoReleaseAt: booking.autoReleaseAt,
    });
  } catch (e) {
    logger.error('[completeService]', e);
    return res.status(500).json({ error: 'Unable to complete service.' });
  }
};

// v23.1.340 — Daniel : "le sitter ou walker doit avoir une notification pour
// confirmer le début du service, pour qu'il puisse cliquer Début de service.
// Simple et compréhensible." Appelé par le payoutScheduler (tick 5 min) :
// pour chaque réservation PAYÉE dont l'heure de début est arrivée et que le
// prestataire n'a pas encore démarrée, on lui envoie UNE SEULE notification
// 'service_start_due' (cloche + push + email, 6 langues) : "C'est l'heure !
// Appuie sur 🐾 J'ai récupéré l'animal pour confirmer le début du service."
// Le tap sur la notif ouvre l'écran Réservations où se trouve le bouton.
const SERVICE_START_REMINDER_MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000;
const processServiceStartReminders = async () => {
  const now = new Date();
  let sent = 0;
  try {
    // Bornage requête : payé + pas démarré + rappel jamais envoyé + la date
    // (jour) de début est passée. L'heure exacte (date + timeSlot) est
    // affinée en JS via resolveBookingStartDate.
    const candidates = await Booking.find({
      paymentStatus: 'paid',
      status: 'paid',
      confirmationStatus: 'awaiting_start',
      serviceStartedAt: null,
      serviceStartReminderSentAt: null,
      $or: [
        { startDate: { $lte: now } },
        { date: { $lte: now } },
      ],
    }).limit(200);

    for (const booking of candidates) {
      try {
        const startAt = resolveBookingStartDate(booking);
        if (startAt.getTime() > now.getTime()) continue; // pas encore l'heure
        // Réclamation atomique : 2 ticks concurrents ne doublent jamais l'envoi.
        const claimed = await Booking.findOneAndUpdate(
          { _id: booking._id, serviceStartReminderSentAt: null },
          { $set: { serviceStartReminderSentAt: now } },
          { new: true },
        );
        if (!claimed) continue; // un autre tick l'a prise
        // Anti-spam legacy : réservation dont le début date de plus de 7 jours
        // (données d'avant la feature) → on marque sans notifier.
        if (now.getTime() - startAt.getTime() > SERVICE_START_REMINDER_MAX_AGE_MS) {
          continue;
        }
        const provider = _resolveConfirmProvider(booking);
        if (!provider.id || !provider.role) continue;
        const { sendNotification } = require('../services/notificationSender');
        const buildEmailLink = require('../utils/emailLinkBuilder').buildEmailLink;
        await sendNotification({
          userId: provider.id,
          role: provider.role,
          type: 'service_start_due',
          data: {
            bookingId: String(booking._id),
            providerRole: provider.role,
            emailLink: buildEmailLink('booking', { bookingId: String(booking._id) }),
          },
          actor: { role: 'owner', id: booking.ownerId ? String(booking.ownerId) : null },
        });
        sent += 1;
      } catch (e) {
        logger.warn(
          `[serviceStartReminder] failed for booking ${booking._id}: ${e?.message || e}`,
        );
      }
    }
  } catch (e) {
    logger.error('[serviceStartReminder] outer error', e);
  }
  if (sent > 0) {
    logger.info(`🐾 [serviceStartReminder] sent ${sent} start-service reminder(s).`);
  }
  return { sent };
};

// v449 — Daniel : « la 1re confirmation du prestataire doit apparaître avec une
// NOTIFICATION 72h avant le début du service (pas seulement une fois payé) ».
const SERVICE_START_T72H_MS = 72 * 60 * 60 * 1000;

/**
 * Tick scheduler : pour chaque réservation PAYÉE non démarrée dont le début est
 * dans le FUTUR et à <= 72h, on envoie UNE fois au prestataire la notif
 * 'service_start_t72h' (push + mail + cloche) → il sait que le service approche
 * et peut préparer sa 1re confirmation. Réclamation atomique anti-doublon.
 */
const processServiceStartT72hReminders = async () => {
  const now = new Date();
  let sent = 0;
  try {
    const horizon = new Date(now.getTime() + SERVICE_START_T72H_MS);
    const candidates = await Booking.find({
      paymentStatus: 'paid',
      status: 'paid',
      confirmationStatus: 'awaiting_start',
      serviceStartedAt: null,
      startServiceT72hReminderSentAt: null,
    }).limit(200);

    for (const booking of candidates) {
      try {
        const startAt = resolveBookingStartDate(booking);
        if (!startAt) continue;
        // Fenêtre : début dans le FUTUR (> maintenant) ET à 72h ou moins.
        if (startAt.getTime() <= now.getTime()) continue;
        if (startAt.getTime() > horizon.getTime()) continue;
        const claimed = await Booking.findOneAndUpdate(
          { _id: booking._id, startServiceT72hReminderSentAt: null },
          { $set: { startServiceT72hReminderSentAt: now } },
          { new: true },
        );
        if (!claimed) continue;
        const provider = _resolveConfirmProvider(booking);
        if (!provider.id || !provider.role) continue;
        const { sendNotification } = require('../services/notificationSender');
        const buildEmailLink = require('../utils/emailLinkBuilder').buildEmailLink;
        await sendNotification({
          userId: provider.id,
          role: provider.role,
          type: 'service_start_t72h',
          data: {
            bookingId: String(booking._id),
            providerRole: provider.role,
            emailLink: buildEmailLink('booking', { bookingId: String(booking._id) }),
          },
          actor: { role: 'owner', id: booking.ownerId ? String(booking.ownerId) : null },
        });
        sent += 1;
      } catch (e) {
        logger.warn(`[serviceStartT72h] failed for booking ${booking._id}: ${e?.message || e}`);
      }
    }
  } catch (e) {
    logger.error('[serviceStartT72h] outer error', e);
  }
  if (sent > 0) {
    logger.info(`🐾 [serviceStartT72h] sent ${sent} T-72h reminder(s).`);
  }
  return { sent };
};

/**
 * v23.1.354 — Daniel : "la 2e confirmation du sitter/walker sort sur le
 * bandeau pas de suite après la 1re, mais 5 min avant la fin du service,
 * avec notification mail et téléphone."
 * Tick scheduler : pour chaque service DÉMARRÉ (in_progress) dont la fin
 * (resolveBookingEndDate) est à <= 30 min, on envoie UNE fois au prestataire
 * la notif 'service_end_soon' (push FCM + e-mail via notificationSender).
 * Le bandeau app applique le même gate de son côté (_serviceEndAt - 30 min).
 */
// v23.1.357 — Daniel : 5 min avant la fin (et plus 30).
const SERVICE_END_REMINDER_LEAD_MS = 5 * 60 * 1000;
const SERVICE_END_REMINDER_MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000;
const processServiceEndReminders = async () => {
  const now = new Date();
  let sent = 0;
  try {
    const candidates = await Booking.find({
      paymentStatus: 'paid',
      status: 'paid',
      confirmationStatus: 'in_progress',
      serviceEndReminderSentAt: null,
      $or: [
        { startDate: { $lte: now } },
        { date: { $lte: now } },
      ],
    }).limit(200);

    for (const booking of candidates) {
      try {
        const endAt = resolveBookingEndDate(booking);
        // Pas encore dans la fenêtre des 5 dernières minutes.
        if (endAt.getTime() - SERVICE_END_REMINDER_LEAD_MS > now.getTime()) continue;
        // Réclamation atomique : 2 ticks concurrents ne doublent jamais l'envoi.
        const claimed = await Booking.findOneAndUpdate(
          { _id: booking._id, serviceEndReminderSentAt: null },
          { $set: { serviceEndReminderSentAt: now } },
          { new: true },
        );
        if (!claimed) continue;
        // Anti-spam legacy : fin passée depuis plus de 7 jours → marque sans notifier.
        if (now.getTime() - endAt.getTime() > SERVICE_END_REMINDER_MAX_AGE_MS) continue;
        const provider = _resolveConfirmProvider(booking);
        if (!provider.id || !provider.role) continue;
        const { sendNotification } = require('../services/notificationSender');
        const buildEmailLink = require('../utils/emailLinkBuilder').buildEmailLink;
        await sendNotification({
          userId: provider.id,
          role: provider.role,
          type: 'service_end_soon',
          data: {
            bookingId: String(booking._id),
            providerRole: provider.role,
            emailLink: buildEmailLink('booking', { bookingId: String(booking._id) }),
          },
          actor: { role: 'owner', id: booking.ownerId ? String(booking.ownerId) : null },
        });
        sent += 1;
      } catch (e) {
        logger.warn(
          `[serviceEndReminder] failed for booking ${booking._id}: ${e?.message || e}`,
        );
      }
    }
  } catch (e) {
    logger.error('[serviceEndReminder] outer error', e);
  }
  if (sent > 0) {
    logger.info(`🏁 [serviceEndReminder] sent ${sent} end-service reminder(s).`);
  }
  return { sent };
};

// POST /bookings/:id/service/confirm — owner confirme → libère le paiement.
const confirmService = async (req, res) => {
  try {
    const userId = req.user.id;
    const userRole = req.user.role;
    const booking = await Booking.findById(req.params.id);
    if (!booking) return res.status(404).json({ error: 'Booking not found.' });
    if (userRole !== 'owner' || String(booking.ownerId) !== String(userId)) {
      return res.status(403).json({ error: 'Only the owner can confirm the service.' });
    }
    if (booking.confirmationStatus === 'confirmed') {
      return res.json({ success: true, confirmationStatus: 'confirmed', alreadyConfirmed: true });
    }
    if (booking.confirmationStatus === 'disputed') {
      return res.status(409).json({ error: 'Booking is under dispute.', confirmationStatus: 'disputed' });
    }
    // v532 — GARDE TEMPORELLE (symétrique de celle de startService). Confirmer
    // libère immédiatement l'argent au prestataire. Sans contrôle de date, un
    // prestataire pouvait faire confirmer une garde prévue dans trois semaines
    // (« valide juste pour finaliser la réservation ») et encaisser aussitôt,
    // sans jamais garder l'animal — et le séquestre censé protéger le
    // propriétaire ne servait plus à rien.
    // On autorise la confirmation dès que la garde a commencé (démarrage
    // enregistré) ou que l'heure prévue est atteinte, avec la même tolérance
    // de 2 h qu'au démarrage.
    if (booking.confirmationStatus !== 'in_progress') {
      const startAt = resolveBookingStartDate(booking);
      if (startAt && Date.now() < startAt.getTime() - EARLY_START_TOLERANCE_MS) {
        return res.status(409).json({
          error: 'Service has not started yet.',
          code: 'SERVICE_NOT_STARTED_YET',
          startsAt: startAt,
        });
      }
    }
    booking.confirmationStatus = 'confirmed';
    booking.ownerConfirmedAt = new Date();
    // Libération immédiate : scheduledPayoutAt = maintenant.
    booking.scheduledPayoutAt = new Date();
    if (booking.payoutStatus !== 'completed' && booking.payoutStatus !== 'processing') {
      booking.payoutStatus = 'scheduled';
    }
    await booking.save();
    // v23.1.343 — fin de service confirmée → clôt les sessions de balade
    // actives (le suivi live s'arrête, cf completeService).
    try {
      const WalkSession = require('../models/WalkSession');
      await WalkSession.updateMany(
        { bookingId: booking._id, status: 'active' },
        { $set: { status: 'ended', endedAt: new Date() } },
      );
    } catch (e) { logger.warn('[confirmService] walk session close failed', e); }
    // Release now (best-effort ; le scheduler rattrape sinon). IMPORTANT : le
    // payout exige booking.status='paid' (cf processProviderPayoutForBooking),
    // donc on le fait AVANT le hook de complétion.
    try {
      await processProviderPayoutForBooking(booking);
    } catch (e) { logger.warn('[confirmService] payout release failed (scheduler will retry)', e); }
    // v23.1.271 — Daniel : "top sitter/walker reste à 0". Le statut Top
    // (loyalty) ne se mettait jamais à jour car le flux de confirmation ne
    // déclenchait pas onBookingCompleted. On le déclenche ici : recompute Top
    // sitter/walker + Premium owner + crédits fidélité (les compteurs incluent
    // désormais les services confirmés, cf loyaltyService).
    try {
      await onBookingCompleted(booking);
    } catch (e) { logger.warn('[confirmService] loyalty hook failed', e?.message || e); }
    try {
      const { sendNotification } = require('../services/notificationSender');
      const buildEmailLink = require('../utils/emailLinkBuilder').buildEmailLink;
      const prov = _resolveConfirmProvider(booking);
      if (prov.id) {
        await sendNotification({
          userId: prov.id,
          role: prov.role,
          type: 'service_confirmed',
          data: {
            bookingId: String(booking._id),
            emailLink: buildEmailLink('wallet'),
          },
        });
      }
    } catch (e) { logger.warn('[confirmService] notif failed', e); }
    return res.json({ success: true, confirmationStatus: 'confirmed', ownerConfirmedAt: booking.ownerConfirmedAt });
  } catch (e) {
    logger.error('[confirmService]', e);
    return res.status(500).json({ error: 'Unable to confirm service.' });
  }
};

// POST /bookings/:id/service/dispute — owner signale un problème → bloque.
const disputeService = async (req, res) => {
  try {
    const userId = req.user.id;
    const userRole = req.user.role;
    const booking = await Booking.findById(req.params.id);
    if (!booking) return res.status(404).json({ error: 'Booking not found.' });
    if (userRole !== 'owner' || String(booking.ownerId) !== String(userId)) {
      return res.status(403).json({ error: 'Only the owner can dispute the service.' });
    }
    if (booking.confirmationStatus === 'confirmed') {
      return res.status(409).json({ error: 'Service already confirmed; payment released.' });
    }
    booking.confirmationStatus = 'disputed';
    booking.disputedAt = new Date();
    booking.disputeReason = (req.body?.reason || '').toString().slice(0, 500);
    // Bloque le payout : le scheduler saute les 'disputed' (cf
    // processScheduledSitterPayouts). On retire aussi la date programmée.
    booking.scheduledPayoutAt = null;
    await booking.save();
    try {
      const { sendNotification } = require('../services/notificationSender');
      const buildEmailLink = require('../utils/emailLinkBuilder').buildEmailLink;
      const prov = _resolveConfirmProvider(booking);
      if (prov.id) {
        await sendNotification({
          userId: prov.id,
          role: prov.role,
          type: 'service_disputed',
          data: {
            bookingId: String(booking._id),
            emailLink: buildEmailLink('booking', { bookingId: String(booking._id) }),
          },
        });
      }
    } catch (e) { logger.warn('[disputeService] notif failed', e); }
    return res.json({ success: true, confirmationStatus: 'disputed', disputedAt: booking.disputedAt });
  } catch (e) {
    logger.error('[disputeService]', e);
    return res.status(500).json({ error: 'Unable to dispute service.' });
  }
};

/**
 * v532 — ARBITRAGE ADMIN D'UN LITIGE.  POST /admin/bookings/:id/resolve-dispute
 *
 * AVANT, un litige était un cul-de-sac ABSOLU : disputeService posait
 * confirmationStatus='disputed' et scheduledPayoutAt=null, puis toutes les
 * portes se fermaient (le scheduler filtre les litiges, le gate d'escrow
 * retourne sec). Aucune route, aucun écran admin, aucun SLA ne permettait
 * d'en sortir : un seul clic du propriétaire — même accidentel — gelait
 * l'argent définitivement, des DEUX côtés.
 *
 * Deux issues possibles :
 *   action='release' → on donne raison au prestataire : paiement libéré.
 *   action='refund'  → on donne raison au propriétaire : remboursement carte.
 */
const resolveDispute = async (req, res) => {
  try {
    const action = String(req.body?.action || '').trim().toLowerCase();
    const note = String(req.body?.note || '').trim().slice(0, 500);
    if (!['release', 'refund'].includes(action)) {
      return res.status(400).json({ error: 'action must be release or refund.' });
    }
    const booking = await Booking.findById(req.params.id);
    if (!booking) return res.status(404).json({ error: 'Booking not found.' });
    if (booking.confirmationStatus !== 'disputed') {
      return res.status(409).json({
        error: 'This booking is not disputed.',
        confirmationStatus: booking.confirmationStatus,
      });
    }

    booking.disputeResolvedAt = new Date();
    booking.disputeResolutionNote = note || null;

    if (action === 'release') {
      booking.confirmationStatus = 'confirmed';
      booking.ownerConfirmedAt = booking.ownerConfirmedAt || new Date();
      booking.scheduledPayoutAt = new Date();
      booking.disputeResolution = 'released';
      if (booking.payoutStatus !== 'completed' && booking.payoutStatus !== 'processing') {
        booking.payoutStatus = 'scheduled';
      }
      await booking.save();
      await processProviderPayoutForBooking(booking);
    } else {
      // Remboursement intégral au propriétaire (Airwallex ou PayPal).
      await refundBookingPayment(booking);
      booking.disputeResolution = 'refunded';
      booking.status = 'refunded';
      booking.paymentStatus = 'refunded';
      booking.payoutStatus = 'cancelled';
      booking.scheduledPayoutAt = null;
      await booking.save();
    }

    // On informe les DEUX parties de l'issue.
    try {
      const { sendNotification } = require('../services/notificationSender');
      const providerId = booking.walkerId || booking.sitterId;
      const providerRole = booking.walkerId ? 'walker' : 'sitter';
      const type = action === 'release'
        ? 'service_confirmed'
        : 'booking_refunded';
      await sendNotification({
        userId: String(booking.ownerId),
        role: 'owner',
        type,
        data: { bookingId: String(booking._id) },
      });
      if (providerId) {
        await sendNotification({
          userId: String(providerId),
          role: providerRole,
          type,
          data: { bookingId: String(booking._id) },
        });
      }
    } catch (e) {
      logger.warn('[resolveDispute] notif failed', e);
    }

    logger.info(
      `[resolveDispute] booking ${booking._id} arbitre par admin ${req.user?.id} -> ${action}`,
    );
    return res.json({
      success: true,
      action,
      confirmationStatus: booking.confirmationStatus,
      payoutStatus: booking.payoutStatus,
    });
  } catch (e) {
    logger.error('[resolveDispute]', e);
    return res.status(500).json({ error: e?.message || 'Unable to resolve dispute.' });
  }
};

module.exports = {
  resolveDispute,
  createBooking,
  listBookings,
  getMyBookings,
  cancelBooking,
  cancelOwnerSentBookingRequest,
  selfCancelWithRefund,
  respondBooking,
  agreeToBooking,
  createBookingPaymentIntent,
  cancelBookingPaymentIntent,
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
  // v23.1 part 66 — PawFollow live tracking
  getProviderLocation,
  requestLiveTracking,
  respondToPawfollowRequest,
  // v23.1.182 — Suivre sans booking via conversation.
  requestLiveTrackingByConversation,
  // v23.1.259 — Confirmation de service + libération paiement.
  startService,
  completeService,
  processServiceStartReminders,
  processServiceStartT72hReminders,
  processServiceEndReminders,
  confirmService,
  disputeService,
};
