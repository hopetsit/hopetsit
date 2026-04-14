const Sitter = require('../models/Sitter');
const Review = require('../models/Review');
const Owner = require('../models/Owner');
const { sanitizeUser } = require('../utils/sanitize');
const { decrypt, encrypt, maskEmail } = require('../utils/encryption');
const { uploadMedia } = require('../services/cloudinary');
const { normalizeCurrency, DEFAULT_CURRENCY } = require('../utils/currency');
const {
  validatePriceAgainstRecommended,
  getRecommendedPriceRange,
  SERVICE_TYPES,
  LOCATION_TYPES,
} = require('../utils/pricing');

const isValidEmail = (value) => {
  if (!value || typeof value !== 'string') return false;
  const trimmed = value.trim();
  // Simple but robust email validation for PayPal payout email
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmed);
};

const parseSkills = (skillsStr) => {
  if (!skillsStr || typeof skillsStr !== 'string') return [];
  
  // Split by comma, semicolon, or newline, then trim each item
  return skillsStr
    .split(/[,;\n]/)
    .map(s => s.trim())
    .filter(s => s.length > 0);
};

/**
 * Find nearby sitters based on owner's location
 * Uses MongoDB geospatial queries to find sitters within a specified radius
 */
const findNearbySitters = async (req, res) => {
  try {
    const { lat, lng, coordinates, radius, service, minRating, includeUnverified = false } = req.query;

    // Validate location input - accept either coordinates array or lat/lng
    let longitude = null;
    let latitude = null;

    if (coordinates) {
      // Parse coordinates array [lng, lat]
      try {
        const coords = JSON.parse(coordinates);
        if (Array.isArray(coords) && coords.length === 2) {
          [longitude, latitude] = coords;
        }
      } catch (e) {
        // If not JSON, try splitting by comma
        const coords = coordinates.split(',').map(Number);
        if (coords.length === 2 && !isNaN(coords[0]) && !isNaN(coords[1])) {
          [longitude, latitude] = coords;
        }
      }
    } else if (lat !== undefined && lng !== undefined) {
      latitude = parseFloat(lat);
      longitude = parseFloat(lng);
    }

    // Validate coordinates
    if (
      latitude === null ||
      longitude === null ||
      isNaN(latitude) ||
      isNaN(longitude) ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180
    ) {
      return res.status(400).json({
        error: 'Valid location is required. Provide either coordinates array [lng, lat] or lat and lng query parameters.',
      });
    }

    // Optional radius filter (in kilometers)
    // If not provided, show all sitters regardless of distance
    let radiusInMeters = null;
    let radiusInKm = null;
    
    if (radius !== undefined) {
      radiusInKm = parseFloat(radius);
      if (isNaN(radiusInKm) || radiusInKm <= 0 || radiusInKm > 10000) {
        return res.status(400).json({
          error: 'Radius must be a positive number between 1 and 10000 kilometers.',
        });
      }
      // Convert radius from km to meters for MongoDB (MongoDB uses meters)
      radiusInMeters = radiusInKm * 1000;
    }

    // Build query filter
    const filter = {
      'location.coordinates': { $exists: true, $type: 'array' },
    };

    // Only filter by verified status if includeUnverified is not true
    // Default behavior: show only verified sitters
    if (includeUnverified !== 'true' && includeUnverified !== true) {
      filter.verified = true;
    }

    // Optional: Filter by service type (sitter.service is array; match if array contains this value)
    if (service && typeof service === 'string' && service.trim()) {
      filter.service = service.trim();
    }

    // Optional: Filter by minimum rating
    if (minRating !== undefined) {
      const minRatingNum = parseFloat(minRating);
      if (!isNaN(minRatingNum) && minRatingNum >= 0) {
        filter.rating = { $gte: minRatingNum };
      }
    }

    // Build $geoNear stage
    const geoNearStage = {
      $geoNear: {
        near: {
          type: 'Point',
          coordinates: [longitude, latitude], // [lng, lat] format
        },
        distanceField: 'distance', // Distance in meters
        spherical: true,
        query: filter,
      },
    };

    // Add maxDistance only if radius is provided
    if (radiusInMeters !== null) {
      geoNearStage.$geoNear.maxDistance = radiusInMeters;
    }

    // Use MongoDB's $geoNear aggregation to find sitters with distance
    // If no radius is provided, show all sitters sorted by distance
    const aggregationPipeline = [
      geoNearStage,
      {
        $sort: { distance: 1 }, // Sort by distance (nearest first)
      },
    ];

    // Optional: Limit results if radius is provided (otherwise show all)
    if (radiusInMeters !== null) {
      aggregationPipeline.push({
        $limit: 500, // Limit to 500 results when radius is specified
      });
    }

    const sitters = await Sitter.aggregate(aggregationPipeline);

    // Format response with sitter details
    const nearbySitters = sitters.map((sitter) => {
      const skills = parseSkills(sitter.skills);

      return {
        id: sitter._id.toString(),
        name: sitter.name || '',
        avatar: {
          url: sitter.avatar?.url || '',
          publicId: sitter.avatar?.publicId || '',
        },
        rating: sitter.rating || 0,
        reviewsCount: sitter.reviewsCount || 0,
        service: Array.isArray(sitter.service) ? sitter.service : sitter.service ? [sitter.service] : [],
        skills: skills,
        hourlyRate: sitter.hourlyRate || 0,
        weeklyRate: sitter.weeklyRate || 0,
        monthlyRate: sitter.monthlyRate || 0,
        bio: sitter.bio || '',
        location: {
          coordinates: sitter.location?.coordinates || null,
          city: sitter.location?.city || '',
        },
        distance: sitter.distance ? (sitter.distance / 1000).toFixed(2) : null, // Convert to km, 2 decimal places
        distanceInMeters: sitter.distance || null,
        verified: sitter.verified || false,
      };
    });

    res.json({
      sitters: nearbySitters,
      count: nearbySitters.length,
      searchLocation: {
        coordinates: [longitude, latitude],
        lat: latitude,
        lng: longitude,
      },
      radius: radiusInKm || null, // null if no radius limit
      radiusInMeters: radiusInMeters || null,
      hasRadiusLimit: radiusInMeters !== null,
    });
  } catch (error) {
    console.error('Find nearby sitters error', error);
    if (error.message && error.message.includes('index')) {
      return res.status(500).json({
        error: 'Geospatial index not found. Please ensure location index is created.',
      });
    }
    res.status(500).json({ error: 'Unable to find nearby sitters. Please try again later.' });
  }
};

const listSitters = async (req, res) => {
  try {
    const sitters = await Sitter.find().sort({ rating: -1, createdAt: -1 });
    res.json({ sitters: sitters.map(sanitizeUser) });
  } catch (error) {
    console.error('Fetch sitters error', error);
    res.status(500).json({ error: 'Unable to fetch sitters. Please try again later.' });
  }
};

const getSitterProfile = async (req, res) => {
  try {
    const { id } = req.params;
    
    const sitter = await Sitter.findById(id);
    if (!sitter) {
      return res.status(404).json({ error: 'Sitter not found.' });
    }

    // Get reviews for this sitter from Review model
    const reviews = await Review.find({
      revieweeId: id,
      revieweeModel: 'Sitter',
    })
      .sort({ createdAt: -1 })
      .populate('reviewerId');

    // Format reviews with reviewer information
    const formattedReviews = reviews.map((review) => {
      const reviewer = review.reviewerId;
      return {
        id: review._id.toString(),
        reviewer: {
          id: reviewer?._id?.toString() || '',
          name: reviewer?.name || '',
          avatar: reviewer?.avatar?.url || '',
        },
        rating: review.rating || 0,
        comment: review.comment || '',
        createdAt: review.createdAt,
      };
    });

    // Parse skills from string to array
    const skills = parseSkills(sitter.skills);

    // Format sitter profile response
    const sitterProfile = {
      id: sitter._id.toString(),
      name: sitter.name || '',
      email: sitter.email || '',
      mobile: sitter.mobile || '',
      countryCode: sitter.countryCode || '',
      language: sitter.language || '',
      currency: sitter.currency || DEFAULT_CURRENCY,
      address: sitter.address || '',
      rate: sitter.rate || '',
      hourlyRate: sitter.hourlyRate || 0,
      weeklyRate: sitter.weeklyRate || 0,
      monthlyRate: sitter.monthlyRate || 0,
      // Main profile image
      avatar: {
        url: sitter.avatar?.url || '',
        publicId: sitter.avatar?.publicId || '',
      },
      // Rating information
      rating: sitter.rating || 0,
      reviewsCount: sitter.reviewsCount || 0,
      // About/Bio section
      bio: sitter.bio || '',
      // Skills array
      skills: skills,
      // Service type (array)
      service: Array.isArray(sitter.service) ? sitter.service : sitter.service ? [sitter.service] : [],
      verified: sitter.verified || false,
      // Location information
      location: sitter.location ? {
        coordinates: sitter.location.coordinates || null,
        city: sitter.location.city || '',
        locationType: sitter.location.locationType || 'standard',
      } : null,
      // Reviews array
      reviews: formattedReviews,
      createdAt: sitter.createdAt,
      updatedAt: sitter.updatedAt,
    };

    res.json({ sitter: sitterProfile });
  } catch (error) {
    console.error('Fetch sitter profile error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid sitter id.' });
    }
    res.status(500).json({ error: 'Unable to fetch sitter profile. Please try again later.' });
  }
};

const updateSitterPricing = async (req, res) => {
  try {
    const sitterId = req.user?.id;
    const userRole = req.user?.role;

    if (!sitterId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (userRole !== 'sitter') {
      return res.status(403).json({ error: 'Only sitters can update their pricing.' });
    }

    const {
      location,
      servicePricing,
      hourlyRate,
      weeklyRate,
      monthlyRate,
    } = req.body || {};

    const sitter = await Sitter.findById(sitterId);
    if (!sitter) {
      return res.status(404).json({ error: 'Sitter not found.' });
    }

    // Update location (city/locationType) only if sitter already has a location with valid coordinates
    if (location && sitter.location && Array.isArray(sitter.location.coordinates) && sitter.location.coordinates.length === 2) {
      if (location.city !== undefined) {
        sitter.location.city = typeof location.city === 'string' ? location.city.trim() : '';
      }
      if (location.locationType !== undefined) {
        if (!LOCATION_TYPES[location.locationType.toUpperCase()]) {
          return res.status(400).json({
            error: 'Invalid locationType. Valid types: standard, large_city',
          });
        }
        sitter.location.locationType = location.locationType;
      }
    }

    // Update service pricing if provided
    if (servicePricing) {
      // Validate and update each service pricing
      if (servicePricing.homeVisit !== undefined) {
        if (servicePricing.homeVisit.basePrice !== undefined) {
          const price = parseFloat(servicePricing.homeVisit.basePrice);
          if (isNaN(price) || price < 0) {
            return res.status(400).json({ error: 'homeVisit.basePrice must be a positive number.' });
          }
          sitter.servicePricing.homeVisit.basePrice = price;
        }
        if (servicePricing.homeVisit.currency !== undefined) {
          sitter.servicePricing.homeVisit.currency = servicePricing.homeVisit.currency;
        }
      }

      if (servicePricing.dogWalking30 !== undefined) {
        if (servicePricing.dogWalking30.basePrice !== undefined) {
          const price = parseFloat(servicePricing.dogWalking30.basePrice);
          if (isNaN(price) || price < 0) {
            return res.status(400).json({ error: 'dogWalking30.basePrice must be a positive number.' });
          }
          sitter.servicePricing.dogWalking30.basePrice = price;
        }
        if (servicePricing.dogWalking30.currency !== undefined) {
          sitter.servicePricing.dogWalking30.currency = servicePricing.dogWalking30.currency;
        }
      }

      if (servicePricing.dogWalking60 !== undefined) {
        if (servicePricing.dogWalking60.basePrice !== undefined) {
          const price = parseFloat(servicePricing.dogWalking60.basePrice);
          if (isNaN(price) || price < 0) {
            return res.status(400).json({ error: 'dogWalking60.basePrice must be a positive number.' });
          }
          sitter.servicePricing.dogWalking60.basePrice = price;
        }
        if (servicePricing.dogWalking60.currency !== undefined) {
          sitter.servicePricing.dogWalking60.currency = servicePricing.dogWalking60.currency;
        }
      }

      if (servicePricing.overnightStay !== undefined) {
        if (servicePricing.overnightStay.basePrice !== undefined) {
          const price = parseFloat(servicePricing.overnightStay.basePrice);
          if (isNaN(price) || price < 0) {
            return res.status(400).json({ error: 'overnightStay.basePrice must be a positive number.' });
          }
          sitter.servicePricing.overnightStay.basePrice = price;
        }
        if (servicePricing.overnightStay.currency !== undefined) {
          sitter.servicePricing.overnightStay.currency = servicePricing.overnightStay.currency;
        }
      }

      if (servicePricing.longStay !== undefined) {
        if (servicePricing.longStay.basePrice !== undefined) {
          const price = parseFloat(servicePricing.longStay.basePrice);
          if (isNaN(price) || price < 0) {
            return res.status(400).json({ error: 'longStay.basePrice must be a positive number.' });
          }
          sitter.servicePricing.longStay.basePrice = price;
        }
        if (servicePricing.longStay.currency !== undefined) {
          sitter.servicePricing.longStay.currency = servicePricing.longStay.currency;
        }
      }
    }

    if (hourlyRate !== undefined) {
      const value = Number(hourlyRate);
      if (!Number.isFinite(value) || value < 0) {
        return res.status(400).json({ error: 'hourlyRate must be a non-negative number.' });
      }
      sitter.hourlyRate = value;
    }

    if (weeklyRate !== undefined) {
      const value = Number(weeklyRate);
      if (!Number.isFinite(value) || value < 0) {
        return res.status(400).json({ error: 'weeklyRate must be a non-negative number.' });
      }
      sitter.weeklyRate = value;
    }

    if (monthlyRate !== undefined) {
      const value = Number(monthlyRate);
      if (!Number.isFinite(value) || value < 0) {
        return res.status(400).json({ error: 'monthlyRate must be a non-negative number.' });
      }
      sitter.monthlyRate = value;
    }

    await sitter.save();

    // Get recommended ranges for validation feedback
    const locationType = sitter.location?.locationType || LOCATION_TYPES.STANDARD;
    const validationResults = {};

    if (sitter.servicePricing.homeVisit.basePrice) {
      try {
        validationResults.homeVisit = validatePriceAgainstRecommended(
          sitter.servicePricing.homeVisit.basePrice,
          SERVICE_TYPES.HOME_VISIT,
          locationType
        );
      } catch (error) {
        validationResults.homeVisit = { isValid: false, error: error.message };
      }
    }

    if (sitter.servicePricing.dogWalking30.basePrice) {
      try {
        validationResults.dogWalking30 = validatePriceAgainstRecommended(
          sitter.servicePricing.dogWalking30.basePrice,
          SERVICE_TYPES.DOG_WALKING,
          locationType,
          30
        );
      } catch (error) {
        validationResults.dogWalking30 = { isValid: false, error: error.message };
      }
    }

    if (sitter.servicePricing.dogWalking60.basePrice) {
      try {
        validationResults.dogWalking60 = validatePriceAgainstRecommended(
          sitter.servicePricing.dogWalking60.basePrice,
          SERVICE_TYPES.DOG_WALKING,
          locationType,
          60
        );
      } catch (error) {
        validationResults.dogWalking60 = { isValid: false, error: error.message };
      }
    }

    if (sitter.servicePricing.overnightStay.basePrice) {
      try {
        validationResults.overnightStay = validatePriceAgainstRecommended(
          sitter.servicePricing.overnightStay.basePrice,
          SERVICE_TYPES.OVERNIGHT_STAY,
          locationType
        );
      } catch (error) {
        validationResults.overnightStay = { isValid: false, error: error.message };
      }
    }

    if (sitter.servicePricing.longStay.basePrice) {
      try {
        validationResults.longStay = validatePriceAgainstRecommended(
          sitter.servicePricing.longStay.basePrice,
          SERVICE_TYPES.LONG_STAY,
          locationType
        );
      } catch (error) {
        validationResults.longStay = { isValid: false, error: error.message };
      }
    }

    res.json({
      message: 'Pricing updated successfully.',
      sitter: sanitizeUser(sitter, { includeEmail: true }),
      location: sitter.location,
      servicePricing: sitter.servicePricing,
      validationResults,
    });
  } catch (error) {
    console.error('Update sitter pricing error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid sitter id.' });
    }
    res.status(500).json({ error: 'Unable to update pricing. Please try again later.' });
  }
};

const getSitterPricing = async (req, res) => {
  try {
    const sitterId = req.user?.id;
    const userRole = req.user?.role;

    if (!sitterId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (userRole !== 'sitter') {
      return res.status(403).json({ error: 'Only sitters can view their pricing.' });
    }

    const sitter = await Sitter.findById(sitterId);
    if (!sitter) {
      return res.status(404).json({ error: 'Sitter not found.' });
    }

    const locationType = sitter.location?.locationType || LOCATION_TYPES.STANDARD;
    
    // Get recommended ranges for comparison
    const recommendedRanges = {
      homeVisit: getRecommendedPriceRange(SERVICE_TYPES.HOME_VISIT, locationType),
      dogWalking30: getRecommendedPriceRange(SERVICE_TYPES.DOG_WALKING, locationType, 30),
      dogWalking60: getRecommendedPriceRange(SERVICE_TYPES.DOG_WALKING, locationType, 60),
      overnightStay: getRecommendedPriceRange(SERVICE_TYPES.OVERNIGHT_STAY, locationType),
      longStay: getRecommendedPriceRange(SERVICE_TYPES.LONG_STAY, locationType),
    };

    res.json({
      location: sitter.location,
      hourlyRate: sitter.hourlyRate || 0,
      weeklyRate: sitter.weeklyRate || 0,
      monthlyRate: sitter.monthlyRate || 0,
      servicePricing: sitter.servicePricing,
      recommendedRanges,
      message: 'Sitter pricing information retrieved successfully.',
    });
  } catch (error) {
    console.error('Get sitter pricing error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid sitter id.' });
    }
    res.status(500).json({ error: 'Unable to fetch pricing. Please try again later.' });
  }
};

/**
 * Update sitter PayPal payout email
 * PUT /sitters/paypal-email
 * Body: { paypalEmail: string }
 */
const updateSitterPaypalEmail = async (req, res) => {
  try {
    const sitterId = req.user?.id;
    const userRole = req.user?.role;

    if (!sitterId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (userRole !== 'sitter') {
      return res.status(403).json({ error: 'Only sitters can update their PayPal email.' });
    }

    const { paypalEmail } = req.body || {};

    if (!paypalEmail || typeof paypalEmail !== 'string' || !isValidEmail(paypalEmail)) {
      return res.status(400).json({ error: 'A valid PayPal email address is required.' });
    }

    const trimmedEmail = paypalEmail.trim().toLowerCase();

    const sitter = await Sitter.findById(sitterId);
    if (!sitter) {
      return res.status(404).json({ error: 'Sitter not found.' });
    }

    sitter.paypalEmail = trimmedEmail;
    await sitter.save();

    res.json({
      message: 'PayPal email updated successfully.',
      paypalEmail: sitter.paypalEmail,
    });
  } catch (error) {
    console.error('Update sitter PayPal email error', error);
    res.status(500).json({ error: 'Unable to update PayPal email. Please try again later.' });
  }
};

/**
 * Get sitter PayPal payout email
 * GET /sitters/paypal-email
 */
const getSitterPaypalEmail = async (req, res) => {
  try {
    const sitterId = req.user?.id;
    const userRole = req.user?.role;

    if (!sitterId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (userRole !== 'sitter') {
      return res.status(403).json({ error: 'Only sitters can access their PayPal email.' });
    }

    const sitter = await Sitter.findById(sitterId).select('paypalEmail');
    if (!sitter) {
      return res.status(404).json({ error: 'Sitter not found.' });
    }

    const paypalEmail = decrypt(sitter.paypalEmail || '').trim();
    if (!paypalEmail) {
      return res.json({
        hasPaypalEmail: false,
        paypalEmail: null,
        message: 'PayPal email is not set.',
      });
    }

    // Return masked email only (sprint2/step6 policy: never expose cleartext via API).
    return res.json({
      hasPaypalEmail: true,
      paypalEmail: maskEmail(paypalEmail),
    });
  } catch (error) {
    console.error('Get sitter PayPal email error', error);
    return res.status(500).json({ error: 'Unable to fetch PayPal email. Please try again later.' });
  }
};

const updateSitterProfile = async (req, res) => {
  try {
    const sitterId = req.user?.id;
    const userRole = req.user?.role;

    if (!sitterId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (userRole !== 'sitter') {
      return res.status(403).json({ error: 'Only sitters can update their profile.' });
    }

    const sitter = await Sitter.findById(sitterId);
    if (!sitter) {
      return res.status(404).json({ error: 'Sitter not found.' });
    }

    const {
      name,
      email,
      mobile,
      countryCode,
      language,
      address,
      currency,
      rate,
      skills,
      bio,
      service,
      hourlyRate,
      weeklyRate,
      monthlyRate,
      location,
      avatar,
      canServiceAtOwner,
      canServiceAtSitter,
    } = req.body || {};

    // Build update object with only provided fields
    const updateData = {};

    // Sprint 5 step 2 — sitter service capability.
    if (typeof canServiceAtOwner === 'boolean') updateData.canServiceAtOwner = canServiceAtOwner;
    if (typeof canServiceAtSitter === 'boolean') updateData.canServiceAtSitter = canServiceAtSitter;

    // Update name
    if (name !== undefined) {
      if (typeof name !== 'string' || !name.trim()) {
        return res.status(400).json({ error: 'Name must be a non-empty string.' });
      }
      updateData.name = name.trim();
    }

    // Update email (check uniqueness)
    if (email !== undefined) {
      const trimmedEmail = typeof email === 'string' ? email.trim().toLowerCase() : '';
      if (!trimmedEmail) {
        return res.status(400).json({ error: 'Email must be a non-empty string.' });
      }
      
      // Check if email is already taken by another user
      const existingOwner = await Owner.findOne({ email: trimmedEmail });
      const existingSitter = await Sitter.findOne({ 
        email: trimmedEmail, 
        _id: { $ne: sitterId } 
      });
      
      if (existingOwner || existingSitter) {
        return res.status(409).json({ error: 'This email is already associated with another account.' });
      }
      
      updateData.email = trimmedEmail;
    }

    // Update mobile (check uniqueness)
    if (mobile !== undefined) {
      const trimmedMobile = typeof mobile === 'string' ? mobile.trim() : '';
      
      if (trimmedMobile) {
        // Check if mobile is already taken by another user
        const existingOwner = await Owner.findOne({ mobile: trimmedMobile });
        const existingSitter = await Sitter.findOne({ 
          mobile: trimmedMobile, 
          _id: { $ne: sitterId } 
        });
        
        if (existingOwner || existingSitter) {
          return res.status(409).json({ error: 'This mobile number is already associated with another account.' });
        }
      }
      
      updateData.mobile = trimmedMobile;
    }

    // Update language
    if (language !== undefined) {
      updateData.language = typeof language === 'string' ? language.trim() : '';
    }

    // Update currency
    if (currency !== undefined) {
      try {
        updateData.currency = normalizeCurrency(currency, { required: true });
      } catch (err) {
        return res.status(400).json({ error: err.message });
      }
    }

    // Update countryCode
    if (countryCode !== undefined) {
      updateData.countryCode = countryCode.toString().trim();
    }

    // Update address
    if (address !== undefined) {
      updateData.address = typeof address === 'string' ? address.trim() : '';
    }

    // Update rate
    if (rate !== undefined) {
      updateData.rate = typeof rate === 'string' ? rate.trim() : '';
    }

    // Update skills
    if (skills !== undefined) {
      updateData.skills = typeof skills === 'string' ? skills.trim() : '';
    }

    // Update bio
    if (bio !== undefined) {
      updateData.bio = typeof bio === 'string' ? bio.trim() : '';
    }

    // Update service (array)
    if (service !== undefined) {
      const raw = Array.isArray(service) ? service : service != null ? [service] : [];
      updateData.service = raw
        .map((s) => (typeof s === 'string' ? s.trim() : typeof s === 'number' ? String(s).trim() : ''))
        .filter(Boolean);
    }

    // Update hourlyRate
    if (hourlyRate !== undefined) {
      const rateNum = typeof hourlyRate === 'number' ? hourlyRate : parseFloat(hourlyRate);
      if (isNaN(rateNum) || rateNum < 0) {
        return res.status(400).json({ error: 'hourlyRate must be a non-negative number.' });
      }
      updateData.hourlyRate = rateNum;
    }
    if (weeklyRate !== undefined) {
      const rateNum = typeof weeklyRate === 'number' ? weeklyRate : parseFloat(weeklyRate);
      if (isNaN(rateNum) || rateNum < 0) {
        return res.status(400).json({ error: 'weeklyRate must be a non-negative number.' });
      }
      updateData.weeklyRate = rateNum;
    }
    if (monthlyRate !== undefined) {
      const rateNum = typeof monthlyRate === 'number' ? monthlyRate : parseFloat(monthlyRate);
      if (isNaN(rateNum) || rateNum < 0) {
        return res.status(400).json({ error: 'monthlyRate must be a non-negative number.' });
      }
      updateData.monthlyRate = rateNum;
    }

    // Update location: only persist when valid coordinates exist (2dsphere index)
    if (location !== undefined && typeof location === 'object' && location !== null) {
      if (location.locationType !== undefined && !LOCATION_TYPES[location.locationType.toUpperCase()]) {
        return res.status(400).json({
          error: 'Invalid locationType. Valid types: standard, large_city',
        });
      }
      const currentLocation = sitter.location || {};
      const city = location.city !== undefined
        ? (typeof location.city === 'string' ? location.city.trim() : '')
        : currentLocation.city || '';
      const locationType = location.locationType !== undefined
        ? location.locationType
        : currentLocation.locationType || LOCATION_TYPES.STANDARD;
      const coords = location.coordinates ?? currentLocation.coordinates;
      const hasValidCoords = Array.isArray(coords) && coords.length === 2 &&
        typeof coords[0] === 'number' && typeof coords[1] === 'number' &&
        coords[0] >= -180 && coords[0] <= 180 && coords[1] >= -90 && coords[1] <= 90;
      if (hasValidCoords) {
        updateData.location = {
          type: 'Point',
          coordinates: coords,
          city,
          locationType,
        };
      } else {
        updateData._unsetLocation = true;
      }
    }

    // Update avatar
    if (avatar !== undefined) {
      if (avatar === null) {
        updateData.avatar = { url: '', publicId: '' };
      } else if (typeof avatar === 'object' && avatar !== null) {
        const currentAvatar = sitter.avatar || {};
        updateData.avatar = {
          url: avatar.url !== undefined 
            ? (typeof avatar.url === 'string' ? avatar.url.trim() : '') 
            : currentAvatar.url || '',
          publicId: avatar.publicId !== undefined 
            ? (typeof avatar.publicId === 'string' ? avatar.publicId.trim() : '') 
            : currentAvatar.publicId || '',
        };
      }
    }

    const unsetLocation = updateData._unsetLocation;
    delete updateData._unsetLocation;

    if (Object.keys(updateData).length === 0 && !unsetLocation) {
      return res.status(400).json({ error: 'No profile fields provided to update.' });
    }

    const updateOps = {};
    if (Object.keys(updateData).length > 0) updateOps.$set = updateData;
    if (unsetLocation) updateOps.$unset = { location: '' };

    const updatedSitter = await Sitter.findByIdAndUpdate(
      sitterId,
      updateOps,
      { new: true, runValidators: true }
    );

    if (!updatedSitter) {
      return res.status(404).json({ error: 'Sitter not found.' });
    }

    res.json({
      message: 'Profile updated successfully.',
      sitter: sanitizeUser(updatedSitter, { includeEmail: true }),
    });
  } catch (error) {
    console.error('Update sitter profile error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid sitter id.' });
    }
    if (error.name === 'ValidationError') {
      return res.status(400).json({ error: error.message });
    }
    if (error.code === 11000) {
      // Duplicate key error (unique constraint violation)
      const field = Object.keys(error.keyPattern)[0];
      return res.status(409).json({ 
        error: `This ${field} is already associated with another account.` 
      });
    }
    res.status(500).json({ error: 'Unable to update profile. Please try again later.' });
  }
};

const bufferToDataUri = (file) => `data:${file.mimetype};base64,${file.buffer.toString('base64')}`;

const updateSitterAvatar = async (req, res) => {
  try {
    const sitterId = req.user?.id;
    const userRole = req.user?.role;

    if (!sitterId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (userRole !== 'sitter') {
      return res.status(403).json({ error: 'Only sitters can update their avatar.' });
    }

    if (!req.file) {
      return res.status(400).json({ error: 'Avatar file is required. Please upload an image file.' });
    }

    // Validate file type
    const allowedMimeTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
    if (!allowedMimeTypes.includes(req.file.mimetype)) {
      return res.status(400).json({ 
        error: 'Invalid file type. Only JPEG, PNG, and WebP images are allowed.' 
      });
    }

    // Find sitter
    const sitter = await Sitter.findById(sitterId);
    if (!sitter) {
      return res.status(404).json({ error: 'Sitter not found.' });
    }

    // Convert buffer to data URI
    const dataUri = bufferToDataUri(req.file);

    // Upload to Cloudinary
    const folder = `petsinsta/sitters/${sitterId}`;
    const uploadResult = await uploadMedia({
      file: dataUri,
      folder: folder,
      resourceType: 'image',
    });

    // Delete old avatar from Cloudinary if it exists
    if (sitter.avatar?.publicId) {
      try {
        const cloudinary = require('cloudinary').v2;
        await cloudinary.uploader.destroy(sitter.avatar.publicId);
      } catch (deleteError) {
        console.error('Error deleting old avatar:', deleteError);
        // Continue even if deletion fails
      }
    }

    // Update avatar in database
    sitter.avatar = {
      url: uploadResult.url,
      publicId: uploadResult.publicId,
    };

    await sitter.save();

    res.json({
      message: 'Avatar updated successfully.',
      sitter: sanitizeUser(sitter, { includeEmail: true }),
      avatar: {
        url: uploadResult.url,
        publicId: uploadResult.publicId,
      },
    });
  } catch (error) {
    console.error('Update sitter avatar error', error);
    if (error.message && error.message.includes('Cloudinary')) {
      return res.status(502).json({ error: 'Media service is unavailable. Please try again later.' });
    }
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid sitter id.' });
    }
    res.status(500).json({ error: 'Unable to update avatar. Please try again later.' });
  }
};

// Sprint 5 step 6 — availability calendar
const toUtcMidnight = (value) => {
  const d = new Date(value);
  if (isNaN(d.getTime())) return null;
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
};
const normalizeDateList = (list) =>
  Array.isArray(list) ? Array.from(new Set(list.map(toUtcMidnight).filter(Boolean).map((d) => d.toISOString()))).map((s) => new Date(s)) : [];

const getMyAvailability = async (req, res) => {
  try {
    const sitter = await Sitter.findById(req.user.id).select('availableDates unavailableDates');
    if (!sitter) return res.status(404).json({ error: 'Sitter not found.' });
    res.json({
      availableDates: sitter.availableDates || [],
      unavailableDates: sitter.unavailableDates || [],
    });
  } catch (e) {
    console.error('getMyAvailability error', e);
    res.status(500).json({ error: 'Unable to fetch availability.' });
  }
};

const updateMyAvailability = async (req, res) => {
  try {
    const { availableDates, unavailableDates } = req.body || {};
    const update = {};
    if (availableDates !== undefined) update.availableDates = normalizeDateList(availableDates);
    if (unavailableDates !== undefined) update.unavailableDates = normalizeDateList(unavailableDates);
    if (!Object.keys(update).length) {
      return res.status(400).json({ error: 'availableDates or unavailableDates required.' });
    }
    const sitter = await Sitter.findByIdAndUpdate(req.user.id, update, { new: true })
      .select('availableDates unavailableDates');
    if (!sitter) return res.status(404).json({ error: 'Sitter not found.' });
    res.json({
      availableDates: sitter.availableDates,
      unavailableDates: sitter.unavailableDates,
    });
  } catch (e) {
    console.error('updateMyAvailability error', e);
    res.status(500).json({ error: 'Unable to update availability.' });
  }
};

const getSitterAvailability = async (req, res) => {
  try {
    const sitter = await Sitter.findById(req.params.id).select('availableDates unavailableDates');
    if (!sitter) return res.status(404).json({ error: 'Sitter not found.' });
    res.json({
      availableDates: sitter.availableDates || [],
      unavailableDates: sitter.unavailableDates || [],
    });
  } catch (e) {
    console.error('getSitterAvailability error', e);
    res.status(500).json({ error: 'Unable to fetch availability.' });
  }
};

// Sprint 5 step 7 — identity verification
const submitIdentityVerification = async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'Identity document file is required.' });
    const dataUri = bufferToDataUri(req.file);
    const upload = await uploadMedia({ file: dataUri, folder: 'identity_verification' });
    const sitter = await Sitter.findByIdAndUpdate(
      req.user.id,
      {
        identityVerification: {
          status: 'pending',
          documentUrl: encrypt(upload.url),
          submittedAt: new Date(),
          reviewedAt: null,
          rejectionReason: '',
        },
      },
      { new: true }
    ).select('identityVerification');
    if (!sitter) return res.status(404).json({ error: 'Sitter not found.' });
    res.json({
      identityVerification: {
        status: sitter.identityVerification.status,
        submittedAt: sitter.identityVerification.submittedAt,
      },
    });
  } catch (e) {
    console.error('submitIdentityVerification error', e);
    res.status(500).json({ error: 'Unable to submit identity document.' });
  }
};

const getMyIdentityVerification = async (req, res) => {
  try {
    const sitter = await Sitter.findById(req.user.id).select('identityVerification');
    if (!sitter) return res.status(404).json({ error: 'Sitter not found.' });
    const iv = sitter.identityVerification || {};
    res.json({
      status: iv.status || 'none',
      submittedAt: iv.submittedAt || null,
      reviewedAt: iv.reviewedAt || null,
      rejectionReason: iv.rejectionReason || '',
      documentUrl: iv.documentUrl ? decrypt(iv.documentUrl) : '',
    });
  } catch (e) {
    console.error('getMyIdentityVerification error', e);
    res.status(500).json({ error: 'Unable to fetch identity verification.' });
  }
};

module.exports = {
  listSitters,
  getSitterProfile,
  findNearbySitters,
  updateSitterPricing,
  getSitterPricing,
  updateSitterProfile,
  updateSitterAvatar,
  updateSitterPaypalEmail,
  getMyAvailability,
  updateMyAvailability,
  getSitterAvailability,
  getSitterPaypalEmail,
  submitIdentityVerification,
  getMyIdentityVerification,
};

