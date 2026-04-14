const {
  LOCATION_TYPES,
  SERVICE_TYPES,
  PLATFORM_COMMISSION_RATE,
  getRecommendedPriceRange,
  calculatePricingBreakdown,
  calculateTotalWithAddOns,
  validatePriceAgainstRecommended,
  getAllRecommendedRanges,
} = require('../utils/pricing');
const { assertSupportedCurrency, DEFAULT_CURRENCY } = require('../utils/currency');
const logger = require('../utils/logger');

/**
 * Get recommended price ranges for all services
 * GET /pricing/recommended?locationType=standard|large_city&currency=EUR|USD
 */
const getRecommendedPriceRanges = async (req, res) => {
  try {
    const { locationType, currency } = req.query;
    const validLocationType = locationType === LOCATION_TYPES.LARGE_CITY 
      ? LOCATION_TYPES.LARGE_CITY 
      : LOCATION_TYPES.STANDARD;

    const validatedCurrency = assertSupportedCurrency(
      currency || DEFAULT_CURRENCY,
      'Pricing recommendations support only USD or EUR.'
    );
    const recommendedRanges = getAllRecommendedRanges(validLocationType, validatedCurrency);

    res.json({
      locationType: validLocationType,
      commissionRate: PLATFORM_COMMISSION_RATE,
      recommendedRanges,
      message: 'Recommended price ranges based on service type, duration, and location.',
    });
  } catch (error) {
    logger.error('Get recommended price ranges error', error);
    if (error.message && (error.message.includes('Unsupported') || error.message.includes('currency'))) {
      return res.status(400).json({ error: error.message });
    }
    res.status(500).json({ error: 'Unable to fetch recommended price ranges. Please try again later.' });
  }
};

/**
 * Get recommended price range for a specific service
 * GET /pricing/recommended/:serviceType?locationType=standard|large_city&duration=30|60
 */
const getServiceRecommendedPrice = async (req, res) => {
  try {
    const { serviceType } = req.params;
    const { locationType, duration, currency } = req.query;

    if (!serviceType || !SERVICE_TYPES[serviceType.toUpperCase()]) {
      return res.status(400).json({ 
        error: 'Invalid service type. Valid types: home_visit, dog_walking, overnight_stay, long_stay' 
      });
    }

    const normalizedServiceType = serviceType.toLowerCase();
    const validLocationType = locationType === LOCATION_TYPES.LARGE_CITY 
      ? LOCATION_TYPES.LARGE_CITY 
      : LOCATION_TYPES.STANDARD;

    const validatedCurrency = assertSupportedCurrency(
      currency || DEFAULT_CURRENCY,
      'Pricing recommendations support only USD or EUR.'
    );

    let durationNum = null;
    if (serviceType === SERVICE_TYPES.DOG_WALKING) {
      durationNum = duration ? parseInt(duration, 10) : 30;
      if (durationNum !== 30 && durationNum !== 60) {
        durationNum = 30; // Default to 30 minutes
      }
    }

    const recommended = getRecommendedPriceRange(normalizedServiceType, validLocationType, durationNum, validatedCurrency);

    res.json({
      serviceType: normalizedServiceType,
      locationType: validLocationType,
      duration: durationNum || recommended.duration,
      recommendedRange: {
        min: recommended.min,
        max: recommended.max,
        currency: recommended.currency,
      },
      description: recommended.description,
      addOns: recommended.addOns,
      commissionRate: PLATFORM_COMMISSION_RATE,
    });
  } catch (error) {
    logger.error('Get service recommended price error', error);
    if (error.message && (error.message.includes('Invalid') || error.message.includes('Unsupported') || error.message.includes('currency'))) {
      return res.status(400).json({ error: error.message });
    }
    res.status(500).json({ error: 'Unable to fetch recommended price. Please try again later.' });
  }
};

/**
 * Calculate pricing breakdown with commission
 * POST /pricing/calculate
 * Body: { basePrice: number, addOns?: Array, currency?: string }
 */
const calculatePricing = async (req, res) => {
  try {
    const { basePrice, addOns, currency } = req.body || {};

    if (typeof basePrice !== 'number' || basePrice <= 0) {
      return res.status(400).json({ error: 'basePrice must be a positive number.' });
    }

    const validatedCurrency = assertSupportedCurrency(
      currency || DEFAULT_CURRENCY,
      'Pricing breakdown supports only USD or EUR.'
    );
    const breakdown = calculateTotalWithAddOns(basePrice, addOns || [], validatedCurrency);

    res.json({
      pricing: breakdown,
      message: 'Pricing breakdown calculated successfully.',
    });
  } catch (error) {
    logger.error('Calculate pricing error', error);
    if (error.message && (error.message.includes('must be') || error.message.includes('Unsupported') || error.message.includes('currency'))) {
      return res.status(400).json({ error: error.message });
    }
    res.status(500).json({ error: 'Unable to calculate pricing. Please try again later.' });
  }
};

/**
 * Validate sitter's custom price against recommended range
 * POST /pricing/validate
 * Body: { customPrice: number, serviceType: string, locationType: string, duration?: number, currency?: string }
 */
const validatePrice = async (req, res) => {
  try {
    const { customPrice, serviceType, locationType, duration, currency } = req.body || {};

    if (typeof customPrice !== 'number' || customPrice <= 0) {
      return res.status(400).json({ error: 'customPrice must be a positive number.' });
    }

    const normalizedServiceType = serviceType ? serviceType.toLowerCase() : '';
    if (!serviceType || !['home_visit', 'dog_walking', 'overnight_stay', 'long_stay'].includes(normalizedServiceType)) {
      return res.status(400).json({ 
        error: 'Invalid service type. Valid types: home_visit, dog_walking, overnight_stay, long_stay' 
      });
    }

    if (!locationType || !LOCATION_TYPES[locationType.toUpperCase()]) {
      return res.status(400).json({ 
        error: 'Invalid location type. Valid types: standard, large_city' 
      });
    }

    const validatedCurrency = assertSupportedCurrency(
      currency || DEFAULT_CURRENCY,
      'Price validation supports only USD or EUR.'
    );

    const validation = validatePriceAgainstRecommended(
      customPrice,
      normalizedServiceType,
      locationType,
      duration,
      validatedCurrency
    );

    if (!validation.isValid) {
      return res.status(400).json({ error: validation.error });
    }

    // Calculate pricing breakdown for the custom price
    const breakdown = calculatePricingBreakdown(customPrice, validatedCurrency);

    res.json({
      validation,
      pricing: breakdown,
      message: validation.message,
    });
  } catch (error) {
    logger.error('Validate price error', error);
    if (error.message && (error.message.includes('Invalid') || error.message.includes('Unsupported') || error.message.includes('currency'))) {
      return res.status(400).json({ error: error.message });
    }
    res.status(500).json({ error: 'Unable to validate price. Please try again later.' });
  }
};

module.exports = {
  getRecommendedPriceRanges,
  getServiceRecommendedPrice,
  calculatePricing,
  validatePrice,
};

