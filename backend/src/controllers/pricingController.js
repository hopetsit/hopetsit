const {
  LOCATION_TYPES,
  SERVICE_TYPES,
  PLATFORM_COMMISSION_RATE,
  commissionRateForProvider,
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

/**
 * v613 — taux de commission d'UN prestataire, calculé par la MÊME fonction que
 * la création de réservation / candidature (`commissionRateForProvider`, lue
 * sur isTopSitter / isTopWalker) : 15 % pour un Top, 20 % sinon. L'écran
 * « Envoyer une demande » de l'app l'affiche au lieu d'un 20 % figé.
 * GET /pricing/commission-rate?providerId=<id>&role=sitter|walker
 * Public : le badge Top est déjà visible sur le profil public.
 */
const getProviderCommissionRate = async (req, res) => {
  try {
    const providerId = String(req.query.providerId || '');
    const role = req.query.role === 'walker' ? 'walker' : 'sitter';
    if (!/^[0-9a-fA-F]{24}$/.test(providerId)) {
      return res.status(400).json({ error: 'providerId is required.' });
    }
    // Chargés ici (et non en tête) : ce contrôleur est aussi importé par des
    // tests unitaires sans base.
    const Model = role === 'walker' ? require('../models/Walker') : require('../models/Sitter');
    const provider = await Model.findById(providerId).select('isTopSitter isTopWalker').lean();
    if (!provider) return res.status(404).json({ error: 'Provider not found.' });
    const isTopProvider = role === 'walker'
      ? provider.isTopWalker === true
      : provider.isTopSitter === true;
    return res.json({
      providerId,
      role,
      isTopProvider,
      commissionRate: commissionRateForProvider(isTopProvider),
    });
  } catch (error) {
    logger.error('[pricingController.getProviderCommissionRate]', error);
    return res.status(500).json({ error: 'Unable to read commission rate.' });
  }
};

/**
 * 620 (ZOE, 24/10/2026 — ordre de Daniel « prix par visite, dates à prévoir ») —
 * ESTIMATION UNIQUE pour le site et l'app (plus de copie du calcul côté client).
 * POST /pricing/estimate (auth)
 * Body : { serviceType?, post? | postId?, rate?, unit?, providerId?, providerRole?,
 *          durationMinutes?, currency? }
 *   · `post` = { dateMode, startDate, endDate, visitsPerDay, houseSittingVenue,
 *     serviceLocation, walkDurationMinutes } (formulaire en cours) ou `postId` (demande
 *     enregistrée) ;
 *   · tarif : `rate` explicite, sinon celui du prestataire `providerId`/`providerRole`
 *     (commission 15 % Top / 20 %), sinon celui de l'appelant s'il est gardien/promeneur.
 * Réponse : { serviceType, dateMode, indicative, quantity, unit, unitRate, unitTotal,
 *             commission, ownerTotal, commissionRate, currency, durationMinutes, rateSource }
 *   indicative = true (demande « dates à prévoir ») → quantity / totaux = null.
 */
const estimatePricing620 = async (req, res) => {
  try {
    const engine = require('../utils/pricingEngine620');
    const body = req.body && typeof req.body === 'object' ? req.body : {};
    let post = body.post && typeof body.post === 'object' ? body.post : null;
    if (!post && typeof body.postId === 'string' && /^[0-9a-fA-F]{24}$/.test(body.postId)) {
      post = await require('../models/Post').findById(body.postId)
        .select('dateMode startDate endDate visitsPerDay houseSittingVenue serviceLocation serviceTypes walkDurationMinutes').lean();
      if (!post) return res.status(404).json({ error: 'Post not found.' });
    }
    post = post || {};
    const serviceType = engine.serviceKey(body.serviceType) || engine.mainService(post);
    if (!serviceType) return res.status(400).json({ error: 'serviceType is required.', code: 'SERVICE_REQUIRED' });
    const unit = body.unit ? String(body.unit) : undefined;
    const duration = Number(body.durationMinutes || post.walkDurationMinutes) || undefined;

    let rate = Number(body.rate);
    let commissionRate = PLATFORM_COMMISSION_RATE;
    let currency = String(body.currency || '').toUpperCase() || DEFAULT_CURRENCY;
    let rateSource = 'body';
    let durationMinutes = duration || null;
    let providerRole = body.providerRole === 'walker' ? 'walker' : body.providerRole === 'sitter' ? 'sitter' : null;
    let providerId = typeof body.providerId === 'string' && /^[0-9a-fA-F]{24}$/.test(body.providerId) ? body.providerId : null;
    if (!providerId && !(rate > 0) && req.user && (req.user.role === 'sitter' || req.user.role === 'walker')) {
      providerId = String(req.user.id);
      providerRole = req.user.role;
    }
    if (!(rate > 0) && providerId) {
      const Model = providerRole === 'walker' ? require('../models/Walker') : require('../models/Sitter');
      const provider = await Model.findById(providerId)
        .select('hourlyRate dailyRate weeklyRate monthlyRate visitRate visitDurationMinutes walkRates currency isTopSitter isTopWalker').lean();
      if (!provider) return res.status(404).json({ error: 'Provider not found.' });
      const r = engine.rateFor(provider, serviceType, { durationMinutes: duration, unit });
      if (!r) {
        return res.status(200).json({
          serviceType, dateMode: engine.effectiveDateMode(post), indicative: true, quantity: null,
          unit: unit || engine.unitFor(serviceType), unitRate: 0, unitTotal: null, commission: null,
          ownerTotal: null, commissionRate, currency: provider.currency || currency, durationMinutes: null,
          rateSource: 'none', code: 'NO_RATE',
        });
      }
      rate = r.rate;
      durationMinutes = r.durationMinutes || durationMinutes;
      rateSource = r.source;
      currency = provider.currency || currency;
      commissionRate = commissionRateForProvider(providerRole === 'walker' ? provider.isTopWalker === true : provider.isTopSitter === true);
    }
    if (!(rate > 0)) return res.status(400).json({ error: 'rate (or providerId) is required.', code: 'RATE_REQUIRED' });
    const out = engine.estimate({ serviceType, unit, rate, post, commissionRate, currency });
    return res.json({ serviceType, ...out, durationMinutes, rateSource });
  } catch (error) {
    logger.error('[pricingController.estimatePricing620]', error);
    return res.status(500).json({ error: 'Unable to estimate.' });
  }
};

module.exports = {
  estimatePricing620,
  getProviderCommissionRate,
  getRecommendedPriceRanges,
  getServiceRecommendedPrice,
  calculatePricing,
  validatePrice,
};

