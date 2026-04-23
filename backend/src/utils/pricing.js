/**
 * HOPETSIT - PRICING & COMMISSION POLICY
 * 
 * This utility handles:
 * - Recommended price ranges based on service type, duration, and location
 * - Commission calculations (20% platform commission)
 * - Price breakdowns for owners and sitters
 */

const { DEFAULT_CURRENCY, assertSupportedCurrency } = require('./currency');

// Location types
const LOCATION_TYPES = {
  STANDARD: 'standard', // Small / medium cities
  LARGE_CITY: 'large_city', // Large cities / high-demand areas
};

// Service types
const SERVICE_TYPES = {
  HOME_VISIT: 'home_visit',
  DOG_WALKING: 'dog_walking',
  OVERNIGHT_STAY: 'overnight_stay',
  LONG_STAY: 'long_stay',
};

// Service type values for easy access
const SERVICE_TYPE_VALUES = {
  home_visit: 'home_visit',
  dog_walking: 'dog_walking',
  overnight_stay: 'overnight_stay',
  long_stay: 'long_stay',
};

// Platform commission rate (20%)
const PLATFORM_COMMISSION_RATE = 0.2; // 20%

/**
 * Recommended Price Ranges as per client requirements
 */
const RECOMMENDED_PRICE_RANGES = {
  [SERVICE_TYPES.HOME_VISIT]: {
    duration: '30-45 minutes',
    description: 'The sitter visits the pet at the owner\'s home (feeding, water, litter, short play, basic check).',
    [LOCATION_TYPES.STANDARD]: {
      min: 10,
      max: 15,
    },
    [LOCATION_TYPES.LARGE_CITY]: {
      min: 15,
      max: 20,
    },
    addOns: {
      extraAnimals: { min: 3, max: 5 },
      medicationSpecialCare: { amount: 5 },
    },
  },
  [SERVICE_TYPES.DOG_WALKING]: {
    duration: '30-60 minutes',
    description: 'The sitter walks the dog outside, individually or in a small group.',
    '30_minutes': {
      [LOCATION_TYPES.STANDARD]: {
        min: 10,
        max: 15,
      },
      [LOCATION_TYPES.LARGE_CITY]: {
        min: 10,
        max: 15,
      },
    },
    '60_minutes': {
      [LOCATION_TYPES.STANDARD]: {
        min: 15,
        max: 20,
      },
      [LOCATION_TYPES.LARGE_CITY]: {
        min: 15,
        max: 20,
      },
    },
    addOns: {
      additionalDog: { amount: 5 },
      lateEveningWalk: { min: 3, max: 5 }, // After 21:00
    },
  },
  [SERVICE_TYPES.OVERNIGHT_STAY]: {
    duration: 'per night',
    description: 'The pet stays overnight at the sitter\'s home or the sitter stays overnight at the owner\'s home.',
    [LOCATION_TYPES.STANDARD]: {
      min: 25,
      max: 35,
    },
    [LOCATION_TYPES.LARGE_CITY]: {
      min: 30,
      max: 45,
    },
    addOns: {
      // Add-ons can be added here when client provides more details
    },
  },
  [SERVICE_TYPES.LONG_STAY]: {
    duration: 'per long stay (3+ nights)',
    description: 'Extended stay for pets (3 or more nights), typically at the sitter\'s home.',
    [LOCATION_TYPES.STANDARD]: {
      min: 60,
      max: 90,
    },
    [LOCATION_TYPES.LARGE_CITY]: {
      min: 70,
      max: 110,
    },
    addOns: {
      // Add-ons for long stay can be added here when client provides more details
    },
  },
};

/**
 * Attach currency to each add-on in the recommended addOns object
 * @param {Object} addOns - Add-on definitions (e.g. { extraAnimals: { min: 3, max: 5 }, medicationSpecialCare: { amount: 5 } })
 * @param {string} currency - Currency code (EUR or USD)
 * @returns {Object} Add-ons with currency attached to each
 */
const attachCurrencyToAddOns = (addOns, currency) => {
  if (!addOns || typeof addOns !== 'object') return {};
  const result = {};
  for (const [key, value] of Object.entries(addOns)) {
    result[key] = { ...value, currency };
  }
  return result;
};

/**
 * Get recommended price range for a service
 * @param {string} serviceType - Type of service (home_visit, dog_walking, overnight_stay, long_stay)
 * @param {string} locationType - Location type (standard, large_city)
 * @param {number} duration - Duration in minutes (for dog_walking: 30 or 60)
 * @param {string} currency - Target currency code (EUR or USD)
 * @returns {Object} Recommended price range with currency attached
 */
const getRecommendedPriceRange = (serviceType, locationType, duration = null, currency = DEFAULT_CURRENCY) => {
  const normalizedServiceType = serviceType.toLowerCase();
  if (!SERVICE_TYPE_VALUES[normalizedServiceType]) {
    throw new Error(`Invalid service type: ${serviceType}`);
  }

  if (!LOCATION_TYPES[locationType.toUpperCase()]) {
    throw new Error(`Invalid location type: ${locationType}`);
  }

  const normalizedCurrency = assertSupportedCurrency(currency, 'Pricing recommendations support only USD or EUR.');

  const service = RECOMMENDED_PRICE_RANGES[normalizedServiceType];

  if (normalizedServiceType === SERVICE_TYPES.DOG_WALKING) {
    const durationKey = duration === 30 ? '30_minutes' : '60_minutes';
    const range = service[durationKey][locationType];
    return {
      min: range.min,
      max: range.max,
      duration: duration === 30 ? '30 minutes' : '60 minutes',
      description: service.description,
      addOns: attachCurrencyToAddOns(service.addOns, normalizedCurrency),
      currency: normalizedCurrency,
    };
  }

  const range = service[locationType];
  return {
    min: range.min,
    max: range.max,
    duration: service.duration,
    description: service.description,
    addOns: attachCurrencyToAddOns(service.addOns, normalizedCurrency),
    currency: normalizedCurrency,
  };
};

/**
 * Calculate commission and payout breakdown.
 *
 * v18.9.8 — BUSINESS RULE CHANGE: the 20% platform commission is now paid
 * ENTIRELY by the owner, ON TOP of the provider's advertised rate. The
 * provider (sitter / walker) receives their FULL advertised rate as net
 * payout. Before v18.9.8, the commission was deducted from the provider's
 * payout, which was unfair to providers.
 *
 * @param {number} basePrice - Base price set by sitter / walker (what the
 *                             provider wants to receive net).
 * @param {string} [currency=DEFAULT_CURRENCY] - Currency code (EUR or USD)
 * @returns {Object} Price breakdown with commission, netPayout and ownerTotal.
 */
const calculatePricingBreakdown = (basePrice, currency = DEFAULT_CURRENCY) => {
  if (typeof basePrice !== 'number' || basePrice <= 0) {
    throw new Error('Base price must be a positive number');
  }

  const normalizedCurrency = assertSupportedCurrency(
    currency,
    'Pricing breakdown supports only USD or EUR.'
  );

  // Commission is computed ON the provider base rate and ADDED to the owner
  // total. It is NOT subtracted from the provider's payout anymore.
  //   provider advertises : 10 €
  //   commission (20%)    :  2 €   ← paid by owner
  //   owner total         : 12 €
  //   provider net payout : 10 €   (= basePrice, unchanged)
  const commission = basePrice * PLATFORM_COMMISSION_RATE;
  const netPayout = basePrice; // provider receives full advertised rate
  const ownerTotal = basePrice + commission;

  return {
    basePrice: parseFloat(basePrice.toFixed(2)),
    commission: parseFloat(commission.toFixed(2)),
    netPayout: parseFloat(netPayout.toFixed(2)),
    ownerTotal: parseFloat(ownerTotal.toFixed(2)),
    commissionRate: PLATFORM_COMMISSION_RATE,
    currency: normalizedCurrency,
  };
};

/**
 * Calculate total price with add-ons
 * @param {number} basePrice - Base price
 * @param {Array} addOns - Array of add-on objects with type and amount
 * @param {string} [currency=DEFAULT_CURRENCY] - Currency code (EUR or USD)
 * @returns {Object} Total pricing breakdown
 */
const calculateTotalWithAddOns = (basePrice, addOns = [], currency = DEFAULT_CURRENCY) => {
  const normalizedCurrency = assertSupportedCurrency(
    currency,
    'Total with add-ons supports only USD or EUR.'
  );

  const addOnsTotal = addOns.reduce((sum, addOn) => {
    return sum + (addOn.amount || 0);
  }, 0);

  // v18.9.8 — the provider gross (what the provider wants to receive) is
  // basePrice + addOns. The commission is computed on this amount and
  // ADDED on top. `totalPrice` = what the owner actually pays.
  const providerGross = basePrice + addOnsTotal;
  const breakdown = calculatePricingBreakdown(providerGross, normalizedCurrency);

  return {
    ...breakdown,
    addOns: addOns.map(addOn => ({
      type: addOn.type,
      description: addOn.description || '',
      amount: parseFloat((addOn.amount || 0).toFixed(2)),
      currency: normalizedCurrency,
    })),
    addOnsTotal: parseFloat(addOnsTotal.toFixed(2)),
    // totalPrice is what the OWNER pays (provider gross + 20% commission).
    // Keeps backward compatibility with any consumer expecting this field.
    totalPrice: parseFloat(breakdown.ownerTotal.toFixed(2)),
    // providerGross stays available for display / reporting if needed.
    providerGross: parseFloat(providerGross.toFixed(2)),
  };
};

/**
 * Validate sitter's custom price against recommended range
 * @param {number} customPrice - Price set by sitter
 * @param {string} serviceType - Type of service
 * @param {string} locationType - Location type
 * @param {number} duration - Duration in minutes (for dog_walking)
 * @param {string} [currency=DEFAULT_CURRENCY] - Currency code (EUR or USD)
 * @returns {Object} Validation result
 */
const validatePriceAgainstRecommended = (customPrice, serviceType, locationType, duration = null, currency = DEFAULT_CURRENCY) => {
  try {
    const recommended = getRecommendedPriceRange(serviceType, locationType, duration, currency);
    const isWithinRange = customPrice >= recommended.min && customPrice <= recommended.max;
    const isBelowMin = customPrice < recommended.min;
    const isAboveMax = customPrice > recommended.max;

    return {
      isValid: true,
      isWithinRange,
      isBelowMin,
      isAboveMax,
      customPrice,
      recommendedRange: {
        min: recommended.min,
        max: recommended.max,
        currency: recommended.currency,
      },
      message: isWithinRange
        ? 'Price is within recommended range'
        : isBelowMin
          ? `Price is below recommended minimum of ${recommended.min} ${recommended.currency}`
          : `Price is above recommended maximum of ${recommended.max} ${recommended.currency}`,
    };
  } catch (error) {
    return {
      isValid: false,
      error: error.message,
    };
  }
};

/**
 * Get all recommended price ranges for display
 * @param {string} locationType - Location type (standard, large_city)
 * @param {string} [currency=DEFAULT_CURRENCY] - Currency code (EUR or USD)
 * @returns {Object} All recommended price ranges
 */
const getAllRecommendedRanges = (locationType = LOCATION_TYPES.STANDARD, currency = DEFAULT_CURRENCY) => {
  const normalizedCurrency = assertSupportedCurrency(
    currency,
    'Recommended ranges support only USD or EUR.'
  );

  return {
    [SERVICE_TYPES.HOME_VISIT]: {
      ...getRecommendedPriceRange(SERVICE_TYPES.HOME_VISIT, locationType, null, normalizedCurrency),
      serviceType: SERVICE_TYPES.HOME_VISIT,
      serviceName: 'Home Visit',
    },
    [SERVICE_TYPES.DOG_WALKING]: {
      '30_minutes': {
        ...getRecommendedPriceRange(SERVICE_TYPES.DOG_WALKING, locationType, 30, normalizedCurrency),
        serviceType: SERVICE_TYPES.DOG_WALKING,
        serviceName: 'Dog Walking',
      },
      '60_minutes': {
        ...getRecommendedPriceRange(SERVICE_TYPES.DOG_WALKING, locationType, 60, normalizedCurrency),
        serviceType: SERVICE_TYPES.DOG_WALKING,
        serviceName: 'Dog Walking',
      },
    },
    [SERVICE_TYPES.OVERNIGHT_STAY]: {
      ...getRecommendedPriceRange(SERVICE_TYPES.OVERNIGHT_STAY, locationType, null, normalizedCurrency),
      serviceType: SERVICE_TYPES.OVERNIGHT_STAY,
      serviceName: 'Overnight Stay / Pet Boarding',
    },
    [SERVICE_TYPES.LONG_STAY]: {
      ...getRecommendedPriceRange(SERVICE_TYPES.LONG_STAY, locationType, null, normalizedCurrency),
      serviceType: SERVICE_TYPES.LONG_STAY,
      serviceName: 'Long Stay (3+ nights)',
    },
  };
};

module.exports = {
  LOCATION_TYPES,
  SERVICE_TYPES,
  PLATFORM_COMMISSION_RATE,
  RECOMMENDED_PRICE_RANGES,
  getRecommendedPriceRange,
  calculatePricingBreakdown,
  calculateTotalWithAddOns,
  validatePriceAgainstRecommended,
  getAllRecommendedRanges,
};

