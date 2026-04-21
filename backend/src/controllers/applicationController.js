const Application = require('../models/Application');
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Booking = require('../models/Booking');
const Pet = require('../models/Pet');
const Conversation = require('../models/Conversation');
const {
  sanitizeApplication,
  sanitizeConversation,
  sanitizeBooking,
} = require('../utils/sanitize');
const { isOwnerSitterInteractionBlocked } = require('../services/blockService');
const { calculateTotalWithAddOns, SERVICE_TYPES, LOCATION_TYPES } = require('../utils/pricing');
const { assertSupportedCurrency, DEFAULT_CURRENCY } = require('../utils/currency');
const { normalizeServiceType } = require('../utils/bookingAgreementFields');
const { createNotificationSafe } = require('../services/notificationService');
// Session v17.3 — FCM push + email helper. createNotificationSafe only
// writes the in-app bell record; sendNotification fans out across all
// three channels (in-app socket, FCM push, email) using locale templates.
const { sendNotification } = require('../services/notificationSender');
const { _prepareOwnerPaymentForAgreedBooking } = require('./bookingController');
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

const cancelApplication = async (req, res) => {
  try {
    const { id } = req.params;
    const { sitterId } = req.body || {};

    if (!sitterId) {
      return res.status(400).json({ error: 'sitterId is required to cancel an application.' });
    }

    const application = await Application.findById(id);

    if (!application) {
      return res.status(404).json({ error: 'Application not found.' });
    }

    if (application.sitterId.toString() !== sitterId) {
      return res.status(403).json({ error: 'You are not allowed to cancel this application.' });
    }

    if (application.status !== 'pending') {
      return res.status(409).json({ error: `Cannot cancel an application that is ${application.status}.` });
    }

    await Application.deleteOne({ _id: application._id });

    return res.json({ message: 'Application cancelled.' });
  } catch (error) {
    logger.error('Cancel application error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid application id.' });
    }
    return res.status(500).json({ error: 'Unable to cancel application. Please try again later.' });
  }
};

/**
 * Sitter cancels a sent application request (token-based, no body required).
 */
const cancelSitterSentApplicationRequest = async (req, res) => {
  try {
    const sitterId = req.user?.id;
    const { id } = req.params;

    if (!sitterId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    const application = await Application.findById(id).populate('ownerId').populate('sitterId').populate('walkerId');
    if (!application) {
      return res.status(404).json({ error: 'Application not found.' });
    }

    // Session v16.3c - support walker cancellation too.
    const providerDoc = application.sitterId || application.walkerId;
    if (!providerDoc) {
      return res.status(404).json({ error: 'Application has no provider reference.' });
    }
    const appSitterId = providerDoc._id
      ? providerDoc._id.toString()
      : providerDoc.toString();
    if (appSitterId !== sitterId) {
      return res.status(403).json({ error: 'You can only cancel your own sent requests.' });
    }

    if (application.status !== 'pending') {
      return res.status(409).json({ error: `Cannot cancel an application that is ${application.status}.` });
    }

    await Application.deleteOne({ _id: application._id });

    return res.json({ message: 'Sent request cancelled successfully.', applicationId: id });
  } catch (error) {
    logger.error('Cancel sitter sent application request error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid application id.' });
    }
    return res.status(500).json({ error: 'Unable to cancel sent request. Please try again later.' });
  }
};

const createApplication = async (req, res) => {
  try {
    const sitterId = req.user?.id;
    const { ownerId: ownerIdQuery } = req.query || {};
    const body = req.body || {};
    const {
      petName,
      description,
      serviceDate,
      startDate,
      endDate,
      houseSittingVenue,
      timeSlot,
      petIds,
      petId,
      duration,
      addOns = [],
      locationType,
      // Session v17.1 — optional stable back-reference to the owner's Post
      // that is being applied to. When present, the frontend can resolve
      // "is this post already applied to?" by Post id instead of a fragile
      // multi-field fingerprint.
      postId,
    } = body;

    const ORDERED_SERVICE_TYPES = ['home_visit', 'dog_walking', 'overnight_stay', 'long_stay'];
    let serviceType =
      body.serviceType ??
      body.service_type ??
      body.type ??
      null;
    if (
      (serviceType === undefined || serviceType === null || serviceType === '') &&
      body.serviceTypeIndex !== undefined &&
      body.serviceTypeIndex !== null
    ) {
      const idx = Number(body.serviceTypeIndex);
      if (Number.isInteger(idx) && idx >= 0 && idx < ORDERED_SERVICE_TYPES.length) {
        serviceType = ORDERED_SERVICE_TYPES[idx];
      }
    }
    if (typeof serviceType === 'number' && Number.isInteger(serviceType)) {
      if (serviceType >= 0 && serviceType < ORDERED_SERVICE_TYPES.length) {
        serviceType = ORDERED_SERVICE_TYPES[serviceType];
      }
    }

    if (!sitterId) {
      return res.status(403).json({ error: 'Sitter context missing.' });
    }

    const ownerId = typeof ownerIdQuery === 'string' ? ownerIdQuery.trim() : '';

    if (!ownerId) {
      return res.status(400).json({ error: 'ownerId query parameter is required.' });
    }

    const trimmedPetName = typeof petName === 'string' ? petName.trim() : '';
    const trimmedDescription = typeof description === 'string' ? description.trim() : '';
    const trimmedTimeSlot = typeof timeSlot === 'string' ? timeSlot.trim() : '';

    const owner = await Owner.findById(ownerId);
    if (!owner) {
      return res.status(404).json({ error: 'Owner not found.' });
    }

    // Session v16.3b - support BOTH sitter and walker applications. The
    // previous implementation assumed req.user was always a sitter, which
    // made walkers get a 404 when they tried to apply to an owner's post.
    // We also relax the rate check: sitters can now configure daily/weekly/
    // monthly instead of hourly (v15-6 flexible rates), so we accept ANY
    // non-zero rate. Walkers have their own `walkRates` array.
    const providerRole = req.user?.role;
    let provider = null;
    if (providerRole === 'walker') {
      const Walker = require('../models/Walker');
      provider = await Walker.findById(sitterId);
      if (!provider) {
        return res.status(404).json({ error: 'Walker not found.' });
      }
      // Derive an hourly equivalent from walkRates (same precedence as
      // bookingController): 60-min direct, else 30x2, else 90*(60/90), else 120/2.
      const findWalkRate = (min) => {
        const rate = (provider.walkRates || []).find(
          (r) => r.durationMinutes === min && r.enabled && r.basePrice > 0,
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
          error: 'You must set at least one walk rate before sending requests to owners.',
          details: 'Open your profile and set a price for 30 min or 60 min walks.',
        });
      }
      // Sitter-shim so the downstream pricing code keeps working.
      provider.hourlyRate = derivedHourly;
    } else {
      // Default sitter path.
      provider = await Sitter.findById(sitterId);
      if (!provider) {
        return res.status(404).json({ error: 'Sitter not found.' });
      }
      const hasAnyRate =
        (provider.hourlyRate && provider.hourlyRate > 0) ||
        (provider.dailyRate && provider.dailyRate > 0) ||
        (provider.weeklyRate && provider.weeklyRate > 0) ||
        (provider.monthlyRate && provider.monthlyRate > 0);
      if (!hasAnyRate) {
        return res.status(400).json({
          error: 'You must set at least one rate (hourly, daily, weekly or monthly) before sending requests to owners.',
          details: 'Update your profile with a non-zero rate and try again.',
        });
      }
      // Derive hourly fallback from the most specific rate available so
      // downstream tier math works (matches bookingController behavior).
      if (!provider.hourlyRate || provider.hourlyRate <= 0) {
        if (provider.dailyRate && provider.dailyRate > 0) {
          provider.hourlyRate = provider.dailyRate / 8;
        } else if (provider.weeklyRate && provider.weeklyRate > 0) {
          provider.hourlyRate = provider.weeklyRate / 56;
        } else if (provider.monthlyRate && provider.monthlyRate > 0) {
          provider.hourlyRate = provider.monthlyRate / 240;
        }
      }
    }
    // Alias so the existing code below reading `sitter.*` keeps working.
    const sitter = provider;

    const isBlocked = await isOwnerSitterInteractionBlocked(ownerId, sitterId);
    if (isBlocked) {
      return res.status(403).json({ error: 'You cannot send requests to this owner.' });
    }

    // Parse and validate pet IDs. Supports legacy petId and new petIds array.
    const mongoose = require('mongoose');
    const incomingPetIds = Array.isArray(petIds) && petIds.length > 0
      ? petIds
      : petId
        ? [petId]
        : [];

    if (incomingPetIds.length === 0) {
      return res.status(400).json({ error: 'petIds (or petId) is required.' });
    }

    const validatedPetIds = [];
    for (const rawPetId of incomingPetIds) {
      if (!mongoose.Types.ObjectId.isValid(rawPetId)) {
        return res.status(400).json({ error: `Invalid petId format: ${rawPetId}` });
      }
      const pet = await Pet.findOne({ _id: rawPetId, ownerId });
      if (!pet) {
        return res.status(404).json({ error: `Pet ${rawPetId} not found for this owner.` });
      }
      validatedPetIds.push(pet._id);
    }
    const uniquePetIds = [...new Set(validatedPetIds.map((id) => id.toString()))]
      .map((id) => new mongoose.Types.ObjectId(id));

    // Relaxed serviceType handling: accept any value from client.
    const normalizedForInternalChecks = normalizeServiceType(serviceType);
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

    const normalizedTimeSlot = typeof timeSlot === 'string' ? timeSlot.trim() : '';
    if (!normalizedTimeSlot) {
      return res.status(400).json({ error: 'timeSlot is required.' });
    }

    if (!serviceDate) {
      return res.status(400).json({ error: 'serviceDate is required.' });
    }

    const validLocationType = locationType === LOCATION_TYPES.LARGE_CITY
      ? LOCATION_TYPES.LARGE_CITY
      : LOCATION_TYPES.STANDARD;

    let durationNum = null;
    if (normalizedForInternalChecks === SERVICE_TYPES.DOG_WALKING) {
      const parsedDuration = Number(duration);
      if (![30, 60].includes(parsedDuration)) {
        return res.status(400).json({ error: 'duration is required for dog_walking. Valid values: 30 or 60.' });
      }
      durationNum = parsedDuration;
    }

    const bookingCurrency = assertSupportedCurrency(
      owner.currency || DEFAULT_CURRENCY,
      'Owner currency must be USD or EUR.'
    );

    const normalizedAddOns = Array.isArray(addOns)
      ? addOns.map((addOn) => ({
          type: typeof addOn?.type === 'string' ? addOn.type.trim() : '',
          description: typeof addOn?.description === 'string' ? addOn.description.trim() : '',
          amount: Number.isFinite(Number(addOn?.amount)) && Number(addOn.amount) >= 0 ? Number(addOn.amount) : 0,
        }))
      : [];

    const parsedDate =
      serviceDate && typeof serviceDate === 'string'
        ? new Date(serviceDate)
        : serviceDate instanceof Date
          ? serviceDate
          : null;
    const parsedStartDate =
      startDate && typeof startDate === 'string'
        ? new Date(startDate)
        : startDate instanceof Date
          ? startDate
          : null;
    const parsedEndDate =
      endDate && typeof endDate === 'string'
        ? new Date(endDate)
        : endDate instanceof Date
          ? endDate
          : null;

    const tierPricing = calculateTierBasePrice({
      hourlyRate: sitter.hourlyRate,
      weeklyRate: sitter.weeklyRate,
      monthlyRate: sitter.monthlyRate,
      startDate: parsedStartDate,
      endDate: parsedEndDate,
      serviceDate: parsedDate || serviceDate,
      durationMinutes: durationNum || duration,
    });
    const pricingBreakdown = calculateTotalWithAddOns(tierPricing.basePrice, normalizedAddOns, bookingCurrency);

    const requestFingerprint = buildRequestFingerprint({
      ownerId,
      sitterId,
      petIds: normalizePetIds(uniquePetIds),
      serviceDate: normalizeDate(parsedDate || serviceDate),
      startDate: normalizeDate(parsedStartDate || startDate),
      endDate: normalizeDate(parsedEndDate || endDate),
      timeSlot: normalizeText(trimmedTimeSlot),
      serviceType: serviceType == null ? null : String(serviceType),
      houseSittingVenue: normalizedHouseSittingVenue || null,
      duration: normalizeNumber(durationNum ?? duration),
      basePrice: normalizeNumber(tierPricing.basePrice),
      locationType: normalizeText(validLocationType),
      addOns: normalizeAddOns(normalizedAddOns),
      description: normalizeText(trimmedDescription),
    });

    // Strong dedupe: a sitter should never be able to flood an owner with
    // duplicate requests. We block BOTH exact fingerprint matches AND any
    // pending request from the same sitter -> owner for overlapping pets.
    // IMPORTANT: when a duplicate is detected we return the existing
    // application WITHOUT creating a new notification (no push, no badge).
    const dedupeOr = [{ requestFingerprint }];
    if (Array.isArray(uniquePetIds) && uniquePetIds.length > 0) {
      dedupeOr.push({ petIds: { $all: uniquePetIds } });
    }

    const duplicatePending = await Application.findOne({
      ownerId,
      // Session v16.3b - dedupe against the correct provider field.
      ...(providerRole === 'walker'
        ? { walkerId: sitterId }
        : { sitterId }),
      status: 'pending',
      $or: dedupeOr,
    })
      .sort({ createdAt: -1 })
      .populate('ownerId')
      .populate('sitterId')
      .populate('walkerId');

    if (duplicatePending) {
      return res.status(200).json({
        application: sanitizeApplication(duplicatePending),
        duplicatePrevented: true,
        message: 'A pending request already exists for this sitter and pet(s). No new notification was sent.',
      });
    }

    // Session v17.1 — validate postId if the client provided one. Accept a
    // plain 24-char ObjectId string; silently ignore garbage so we never
    // reject a legitimate application on a client-side bug.
    let normalizedPostId = null;
    if (typeof postId === 'string' && /^[a-fA-F0-9]{24}$/.test(postId.trim())) {
      normalizedPostId = postId.trim();
    }

    const application = await Application.create({
      // Session v16.3b - route to the correct provider field based on role.
      sitterId: providerRole === 'walker' ? null : sitterId,
      walkerId: providerRole === 'walker' ? sitterId : null,
      ownerId,
      postId: normalizedPostId,
      petName: trimmedPetName,
      petIds: uniquePetIds,
      description: trimmedDescription,
      serviceDate: parsedDate,
      startDate: parsedStartDate,
      endDate: parsedEndDate,
      timeSlot: trimmedTimeSlot,
      postBody: trimmedDescription,
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
    });
    await application.populate(['ownerId', 'sitterId', 'walkerId']);

    await createNotificationSafe({
      recipientRole: 'owner',
      recipientId: ownerId,
      // Session v16.3b - use the real provider role so the in-app notif
      // reaches the right bell and the actor shows the correct collection.
      actorRole: providerRole === 'walker' ? 'walker' : 'sitter',
      actorId: sitterId,
      type: 'application_new',
      title: 'New request',
      body: trimmedDescription || 'A pet-care provider sent you a request.',
      data: {
        applicationId: application._id.toString(),
        providerRole: providerRole === 'walker' ? 'walker' : 'sitter',
        providerId: sitterId.toString(),
      },
    });

    // Session v17.5 — also fire FCM push + email to the owner so their
    // phone wakes up when a walker or sitter sends a new application.
    // Before v17.5 only the in-app bell notification was created, which
    // meant the owner only saw it when they manually opened the app.
    // Best-effort: template-missing / FCM errors are swallowed inside
    // sendNotification and logged on the server.
    sendNotification({
      userId: ownerId,
      role: 'owner',
      type: 'application_new',
      data: {
        applicationId: application._id.toString(),
        providerRole: providerRole === 'walker' ? 'walker' : 'sitter',
        providerId: sitterId.toString(),
      },
      actor: {
        role: providerRole === 'walker' ? 'walker' : 'sitter',
        id: sitterId,
      },
    }).catch(() => {});

    res.status(201).json({ application: sanitizeApplication(application) });
  } catch (error) {
    logger.error('Create application error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid sitter or owner id.' });
    }
    if (error.message && (error.message.includes('hourlyRate') || error.message.includes('required for pricing'))) {
      return res.status(400).json({ error: error.message });
    }
    res.status(500).json({ error: 'Unable to send application. Please try again later.' });
  }
};

const listApplications = async (req, res) => {
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
      } else if (userRole === 'walker') {
        // Session v16.3b - walker-owned applications live under walkerId.
        filter.walkerId = userId;
      }
    } else {
      // For regular /applications endpoint, require ownerId or sitterId
      if (!ownerId && !sitterId) {
        return res.status(400).json({ error: 'ownerId or sitterId is required.' });
      }
      if (ownerId) {
        filter.ownerId = ownerId;
      }
      if (sitterId) {
        filter.sitterId = sitterId;
      }
    }
    
    if (status) {
      filter.status = status;
    }

    const applications = await Application.find(filter)
      .sort({ createdAt: -1 })
      .populate('ownerId')
      .populate('sitterId')
      .populate('walkerId')
      .populate('bookingId');

    res.json({ applications: applications.map(sanitizeApplication) });
  } catch (error) {
    logger.error('Fetch applications error', error);
    res.status(500).json({ error: 'Unable to fetch applications. Please try again later.' });
  }
};

const respondToApplication = async (req, res) => {
  try {
    const ownerId = req.user?.id;
    const { id } = req.params;
    const { action } = req.body || {};

    if (!ownerId) {
      return res.status(403).json({ error: 'Owner context missing.' });
    }

    const normalizedAction = typeof action === 'string' ? action.toLowerCase().trim() : '';

    if (!['accept', 'reject'].includes(normalizedAction)) {
      return res.status(400).json({ error: 'Invalid action. Expected "accept" or "reject".' });
    }

    const application = await Application.findById(id).populate('ownerId').populate('sitterId').populate('walkerId');
    if (!application) {
      return res.status(404).json({ error: 'Application not found.' });
    }

    if (application.ownerId._id.toString() !== ownerId) {
      return res.status(403).json({ error: 'You do not have permission to update this application.' });
    }

    if (application.status !== 'pending') {
      return res.status(409).json({ error: `Application already ${application.status}.` });
    }

    // Session v17.1 — walker-aware. The legacy code assumed every Application
    // targets a sitter (sitterId non-null). For walker applications (walkerId
    // set, sitterId null) it crashed at `application.sitterId._id` with a
    // TypeError caught by the 500 handler → "Unable to update application".
    // We resolve the provider side once and use the right fields throughout.
    const isWalkerApp = !!application.walkerId;
    const providerRole = isWalkerApp ? 'walker' : 'sitter';
    const providerDoc = isWalkerApp ? application.walkerId : application.sitterId;
    const providerRefId = providerDoc?._id
      ? providerDoc._id.toString()
      : (providerDoc ? providerDoc.toString() : null);
    if (!providerRefId) {
      return res.status(400).json({
        error: 'Application is missing both sitterId and walkerId — refusing to proceed.',
      });
    }

    if (normalizedAction === 'accept') {
      application.status = 'accepted';

      // Move accepted application into booking flow so owner can pay.
      let booking = null;
      if (application.bookingId) {
        booking = await Booking.findById(application.bookingId)
          .populate('ownerId')
          .populate('sitterId')
          .populate('walkerId')
          .populate('petIds');
      }

      if (!booking) {
        if (!Array.isArray(application.petIds) || application.petIds.length === 0) {
          return res.status(400).json({
            error: 'Application is missing petIds required to create booking.',
          });
        }
        if (!application.serviceDate || !application.timeSlot || !application.serviceType) {
          return res.status(400).json({
            error: 'Application is missing required booking fields (serviceDate, timeSlot, serviceType).',
          });
        }
        if (!application.pricing || typeof application.pricing.totalPrice !== 'number' || application.pricing.totalPrice <= 0) {
          return res.status(400).json({
            error: 'Application is missing valid pricing required to create booking.',
          });
        }

        booking = await Booking.create({
          ownerId: application.ownerId._id,
          // Session v17.1 — write the correct provider side (XOR enforced by
          // the Booking schema's pre-validate hook).
          sitterId: isWalkerApp ? null : providerRefId,
          walkerId: isWalkerApp ? providerRefId : null,
          petIds: application.petIds,
          description: application.description || '',
          date: application.startDate instanceof Date
            ? application.startDate.toISOString()
            : application.serviceDate instanceof Date
              ? application.serviceDate.toISOString()
              : String(application.serviceDate),
          startDate: application.startDate instanceof Date ? application.startDate.toISOString() : null,
          endDate: application.endDate instanceof Date ? application.endDate.toISOString() : null,
          timeSlot: application.timeSlot || '',
          serviceType: application.serviceType,
          houseSittingVenue: application.houseSittingVenue || null,
          duration: application.duration || null,
          locationType: application.locationType || LOCATION_TYPES.STANDARD,
          pricing: {
            basePrice: application.pricing.basePrice,
            pricingTier: application.pricing.pricingTier || 'hourly',
            appliedRate: application.pricing.appliedRate || 0,
            totalHours: application.pricing.totalHours || 0,
            totalDays: application.pricing.totalDays || 0,
            addOns: Array.isArray(application.pricing.addOns) ? application.pricing.addOns : [],
            addOnsTotal: application.pricing.addOnsTotal || 0,
            totalPrice: application.pricing.totalPrice,
            commission: application.pricing.commission,
            netPayout: application.pricing.netPayout,
            commissionRate: application.pricing.commissionRate || 0.2,
            currency: application.pricing.currency || DEFAULT_CURRENCY,
          },
          status: 'agreed',
          agreedAt: new Date(),
        });
      }

      application.bookingId = booking._id;
      await application.save();
      await application.populate(['ownerId', 'sitterId', 'walkerId', 'bookingId']);
      await booking.populate('ownerId');
      await booking.populate('sitterId');
      await booking.populate('walkerId');
      await booking.populate('petIds');

      // Session v17.1 — mark the source Post as reserved so the feed shows
      // the "Réservé" / "Reserved" badge and the card button flips to a
      // non-actionable state on other providers' feeds. Uses
      // application.postId (added in v17.1). Best-effort: if Post.update
      // fails (e.g. applications without a postId because they were created
      // pre-v17.1), the rest of the flow still succeeds.
      if (application.postId) {
        try {
          const Post = require('../models/Post');
          await Post.updateOne(
            { _id: application.postId },
            {
              $set: {
                reservedBy: {
                  bookingId: booking._id,
                  providerRole,
                  providerId: providerRefId,
                  providerName: providerDoc?.name || '',
                  reservedAt: new Date(),
                },
              },
            },
          );
        } catch (reserveErr) {
          logger.warn(
            '[respondToApplication] failed to flag Post as reserved',
            reserveErr?.message || reserveErr,
          );
        }
      }

      await createNotificationSafe({
        recipientRole: providerRole,
        recipientId: providerRefId,
        actorRole: 'owner',
        actorId: ownerId,
        type: 'application_accepted',
        title: 'Request accepted',
        body: 'Your request was accepted.',
        data: {
          applicationId: application._id.toString(),
          bookingId: booking._id.toString(),
          // Session v17.1 — carry provider role so the Flutter notification
          // card can render the right colour (green walker / blue sitter).
          providerRole,
        },
      });

      // Session v17.3 — FCM push + email so the provider gets an actual
      // device push, not just an in-app badge. Best-effort.
      sendNotification({
        userId: providerRefId,
        role: providerRole,
        type: 'application_accepted',
        data: {
          applicationId: application._id.toString(),
          bookingId: booking._id.toString(),
          providerRole,
        },
        actor: { role: 'owner', id: ownerId },
      }).catch(() => {});

      // Session v17.1 — Conversation model is sitter-only (sitterId required
      // + unique index). Create the conversation only for sitter applications
      // so we don't crash on walker accept. Walker conversations will land in
      // a future session once the Conversation schema supports walkerId too.
      let conversation = null;
      if (!isWalkerApp) {
        conversation = await Conversation.findOne({
          ownerId: application.ownerId._id,
          sitterId: providerRefId,
        })
          .populate('ownerId')
          .populate('sitterId');

        if (!conversation) {
          conversation = await Conversation.create({
            ownerId: application.ownerId._id,
            sitterId: providerRefId,
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

      // ── UX simplification (Sprint payment-flow) ────────────────────────────
      // The booking is already in 'agreed' state, so we can immediately prepare
      // a Stripe PaymentIntent for the owner. The Flutter client will use the
      // returned clientSecret to open Stripe PaymentSheet directly, without
      // detouring through the "Reservations" tab.
      // Best-effort: if the provider has no active Stripe Connect account (or
      // any other error), we swallow it and return payment:{error} — the UI
      // will still navigate to the PaymentPage and surface a retry.
      let payment = null;
      try {
        payment = await _prepareOwnerPaymentForAgreedBooking(booking, ownerId, {});
      } catch (payErr) {
        logger.warn('[respondToApplication] auto PaymentIntent creation failed, owner will need to retry later', payErr?.message || payErr);
        payment = { error: payErr?.message || 'payment_unavailable' };
      }

      res.json({
        application: sanitizeApplication(application),
        booking: sanitizeBooking(booking),
        conversation: conversation ? sanitizeConversation(conversation) : null,
        payment, // { clientSecret, paymentIntentId, ... } | { error } | null
      });
    } else {
      application.status = 'rejected';
      await application.save();
      await application.populate(['ownerId', 'sitterId', 'walkerId']);

      await createNotificationSafe({
        recipientRole: providerRole,
        recipientId: providerRefId,
        actorRole: 'owner',
        actorId: ownerId,
        type: 'application_rejected',
        title: 'Request rejected',
        body: 'Your request was rejected.',
        data: {
          applicationId: application._id.toString(),
          providerRole,
        },
      });

      res.json({ application: sanitizeApplication(application) });
    }
  } catch (error) {
    logger.error('Respond to application error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid application id.' });
    }
    res.status(500).json({ error: 'Unable to update application. Please try again later.' });
  }
};

module.exports = {
  createApplication,
  listApplications,
  respondToApplication,
  cancelApplication,
  cancelSitterSentApplicationRequest,
};

