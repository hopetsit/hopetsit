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
/**
 * 620b — estimation « à partir de » d'une demande ouverte (sans tarif ni prestataire visé).
 * Position : `post.location` (formulaire ou demande enregistrée), sinon `body.location` /
 * `body.lat,lng,city`, sinon la position / ville du profil de l'appelant. Devise : `body.currency`,
 * sinon celle du profil de l'appelant, sinon EUR. Un compte de test ne regarde que des comptes de test.
 * Réponse (200) : { serviceType, dateMode, indicative:true, fromRate, unit, quantity, ownerTotalFrom,
 *   basedOn, currency, durationMinutes, radiusKm, rateSource:'market', unitRate, unitTotal:null,
 *   commission:null, ownerTotal:null, commissionRate }
 */
const openEstimate620 = async ({ req, body, post, serviceType, unit, duration, currency, commissionRate }) => {
  const engine = require('../utils/pricingEngine620');
  const fromRate620 = require('../services/fromRate620');
  const { normalizeCurrency } = require('../utils/currency');
  const uid = req.user && req.user.id ? String(req.user.id) : '';
  const role = req.user && req.user.role;
  let me = null;
  if (/^[0-9a-fA-F]{24}$/.test(uid)) {
    const Model = role === 'walker' ? require('../models/Walker') : role === 'sitter' ? require('../models/Sitter') : require('../models/Owner');
    try { me = await Model.findById(uid).select('email currency city location').lean(); } catch (_) { me = null; }
  }
  const loc = (post && post.location) || (body.location && typeof body.location === 'object' ? body.location : null)
    || ((body.lat != null || body.lng != null || body.city) ? { lat: body.lat, lng: body.lng, city: body.city } : null);
  let center = fromRate620.centerOf(loc);
  let city = String((loc && loc.city) || '').trim();
  if (!center && !city && me) {
    center = fromRate620.centerOf(me.location);
    city = String(me.city || (me.location && me.location.city) || '').trim();
  }
  const cur = normalizeCurrency(currency || (me && me.currency) || 'EUR');
  const ownerIsTest = !!(me && require('../utils/testAccount2809').isTestAccountEmail(me.email));
  const selfIds = new Set(uid ? [uid] : []);
  try {
    const { identityGroup } = require('../utils/identityGroup');
    if (uid) for (const gid of (await identityGroup(uid)).ids) selfIds.add(String(gid));
  } catch (_) { /* non bloquant */ }
  const market = await fromRate620.fromRateFor({
    serviceType, center, city, currency: cur, ownerIsTest, selfIds, durationMinutes: duration,
  });
  const q = engine.quantityFor(post || {}, serviceType);
  const mode = engine.effectiveDateMode(post || {});
  const outUnit = unit || q.unit;
  const quantity = mode === 'tbd' ? null : q.quantity;
  const ownerTotalFrom = market.fromRate && quantity
    ? engine.round2(engine.round2(market.fromRate * quantity) * (1 + commissionRate))
    : null;
  return {
    serviceType,
    dateMode: mode,
    indicative: true,
    fromRate: market.fromRate,
    unit: outUnit,
    quantity,
    ownerTotalFrom,
    basedOn: market.basedOn,
    currency: cur,
    durationMinutes: market.durationMinutes,
    radiusKm: market.radiusKm,
    rateSource: 'market',
    unitRate: market.fromRate || 0,
    unitTotal: null,
    commission: null,
    ownerTotal: null,
    commissionRate,
  };
};

const estimatePricing620 = async (req, res) => {
  try {
    const engine = require('../utils/pricingEngine620');
    const body = req.body && typeof req.body === 'object' ? req.body : {};
    let post = body.post && typeof body.post === 'object' ? body.post : null;
    if (!post && typeof body.postId === 'string' && /^[0-9a-fA-F]{24}$/.test(body.postId)) {
      post = await require('../models/Post').findById(body.postId)
        .select('dateMode startDate endDate visitsPerDay houseSittingVenue serviceLocation serviceTypes walkDurationMinutes location').lean();
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
    if (!(rate > 0)) {
      // 620b (ZOE, 24/10 — point relevé par PAM) : demande OUVERTE (aucun prestataire visé)
      // → tarif « à partir de » = minimum des prestataires du rayon d'alerte, devise du
      // propriétaire (services/fromRate620). Toujours 200 : { fromRate: null, basedOn: 0 }
      // quand personne ne propose le service autour de la demande.
      return res.json(await openEstimate620({ req, body, post, serviceType, unit, duration, currency: body.currency, commissionRate }));
    }
    const out = engine.estimate({ serviceType, unit, rate, post, commissionRate, currency });
    return res.json({ serviceType, ...out, durationMinutes, rateSource });
  } catch (error) {
    logger.error('[pricingController.estimatePricing620]', error);
    return res.status(500).json({ error: 'Unable to estimate.' });
  }
};

/**
 * 2410 (ZOE, 24/10/2026 — demande de BOB, point relevé par LEO) — ESTIMATION PUBLIQUE « à partir de ».
 * POST /pricing/estimate/public — SANS session : les visiteurs de la pub sur /posts/create voient
 * « à partir de 12 €/visite » AVANT de créer leur compte. Limité en débit (routeur) et mis en cache
 * 5 min par (service, pays, devise, position, dates).
 *   corps : { serviceType, city?, postalCode?, country?, lang?, lat?, lng?, startDate?, endDate?,
 *            visitsPerDay?, walkDurationMinutes? }
 *   position : lat/lng, sinon code postal (geocodePostal2310), sinon ville (geocodeCity via le rayon
 *              d'alerte), sinon aucune → basedOn 0 ;
 *   devise : déduite du pays (countryToCurrency), sinon `currency` connue, sinon EUR ;
 *   réponse : la même que la route authentifiée (fromRate, unit, quantity, ownerTotalFrom, basedOn,
 *             indicative…) + positionSource ; JAMAIS de donnée personnelle (ni nom, ni id, ni e-mail) :
 *             seuls des minimums et des compteurs sortent. Visiteur = « vrai » monde (comptes de test exclus).
 */
const PUBLIC_CACHE_TTL_MS = 5 * 60 * 1000;
const PUBLIC_CACHE_MAX = 1000;
const publicCache = new Map(); // clé → { at, value }
const _resetPublicCacheForTest = () => publicCache.clear();

const estimatePublic620 = async (req, res) => {
  try {
    const engine = require('../utils/pricingEngine620');
    const { countryToCurrency, COUNTRY_CURRENCY } = require('../utils/countryCurrency');
    const postal = require('../utils/geocodePostal2310');
    const body = req.body && typeof req.body === 'object' ? req.body : {};
    const serviceType = engine.serviceKey(body.serviceType);
    if (!serviceType) return res.status(400).json({ error: 'serviceType is required.', code: 'SERVICE_REQUIRED' });

    const str = (v, n) => String(v == null ? '' : v).trim().slice(0, n);
    const city = str(body.city, 80);
    const postalCode = postal.cleanCode(body.postalCode);
    const lang = str(body.lang, 2).toLowerCase();
    let country = str(body.country, 2).toUpperCase();
    if (!/^[A-Z]{2}$/.test(country)) country = (postal.guessCountry('', lang, postalCode) || '').toUpperCase();
    let lat = Number(body.lat); let lng = Number(body.lng);
    const hasCoords = Number.isFinite(lat) && Number.isFinite(lng) && Math.abs(lat) <= 90 && Math.abs(lng) <= 180 && !(lat === 0 && lng === 0);
    if (!hasCoords) { lat = undefined; lng = undefined; }
    const bodyCurrency = str(body.currency, 3).toUpperCase();
    const currency = country ? countryToCurrency(country)
      : (Object.values(COUNTRY_CURRENCY).includes(bodyCurrency) ? bodyCurrency : DEFAULT_CURRENCY);
    const dates = engine.resolveDates({ startDate: body.startDate, endDate: body.endDate, visitsPerDay: body.visitsPerDay });
    const d = dates.ok ? dates : { dateMode: 'tbd', startDate: null, endDate: null, visitsPerDay: null };
    const durationRaw = Number(body.walkDurationMinutes != null ? body.walkDurationMinutes : body.durationMinutes);
    const duration = durationRaw > 0 ? durationRaw : undefined;

    const key = [serviceType, country, currency, postalCode, city.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, ''),
      hasCoords ? `${lat.toFixed(2)},${lng.toFixed(2)}` : '', d.dateMode,
      d.startDate ? d.startDate.toISOString().slice(0, 10) : '', d.endDate ? d.endDate.toISOString().slice(0, 10) : '',
      d.visitsPerDay || '', duration || ''].join('|');
    const now = Date.now();
    const hit = publicCache.get(key);
    if (hit && now - hit.at < PUBLIC_CACHE_TTL_MS) return res.json({ ...hit.value, cached: true });

    // Position : coordonnées, sinon code postal, sinon ville (géocodée par le rayon d'alerte).
    let location = null; let positionSource = 'none';
    if (hasCoords) { location = { lat, lng, city }; positionSource = 'coords'; }
    else if (postalCode.length >= 3) {
      let g = null;
      try { g = await postal.locationFromPostal(postalCode, { country, lang, city }); } catch (_) { g = null; }
      if (g) { location = { lat: g.lat, lng: g.lng, city: g.city || city }; positionSource = 'postal'; }
    }
    if (!location && city) { location = { city }; positionSource = 'city'; }

    const post = { dateMode: d.dateMode, startDate: d.startDate, endDate: d.endDate, visitsPerDay: d.visitsPerDay, walkDurationMinutes: duration, location };
    const out = await openEstimate620({
      req: {}, body: {}, post, serviceType, unit: undefined, duration, currency, commissionRate: PLATFORM_COMMISSION_RATE,
    });
    const value = { ...out, positionSource, country: country || null, public: true };
    if (publicCache.size >= PUBLIC_CACHE_MAX) publicCache.delete(publicCache.keys().next().value);
    publicCache.set(key, { at: now, value });
    return res.json({ ...value, cached: false });
  } catch (error) {
    logger.error('[pricingController.estimatePublic620]', error);
    return res.status(500).json({ error: 'Unable to estimate.' });
  }
};

module.exports = {
  estimatePricing620,
  estimatePublic620,
  _resetPublicCacheForTest,
  getProviderCommissionRate,
  getRecommendedPriceRanges,
  getServiceRecommendedPrice,
  calculatePricing,
  validatePrice,
};

