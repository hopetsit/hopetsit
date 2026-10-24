const express = require('express');
const rateLimit = require('express-rate-limit');

const {
  getRecommendedPriceRanges,
  getServiceRecommendedPrice,
  calculatePricing,
  validatePrice,
  getProviderCommissionRate,
  estimatePricing620,
  estimatePublic620,
} = require('../controllers/pricingController');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

// 620 (ZOE) — estimation unique (site + app) : quantité × tarif unitaire + commission,
// indicative quand la demande est « dates à prévoir ». Auth requise.
router.post('/estimate', requireAuth, estimatePricing620);

// 2410 (ZOE, demande de BOB / LEO) — estimation PUBLIQUE « à partir de » pour les visiteurs de la
// pub (/posts/create sans compte) : sans session, 30 appels / min / IP (PUBLIC_ESTIMATE_RPM),
// réponse mise en cache 5 min dans le contrôleur. Aucune donnée personnelle dans la réponse.
const publicEstimateLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: () => Number(process.env.PUBLIC_ESTIMATE_RPM) || 30,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => res.status(429).json({ error: 'Too many requests', code: 'RATE_LIMITED', retryAfter: res.getHeader('Retry-After') }),
});
router.post('/estimate/public', publicEstimateLimiter, estimatePublic620);

/**
 * @swagger
 * /pricing/recommended:
 *   get:
 *     summary: Get all recommended price ranges
 *     tags: [Pricing]
 *     responses:
 *       200:
 *         description: Recommended price ranges retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 recommendedPrices:
 *                   type: object
 */
// v613 — taux de commission réel d'un prestataire (15 % Top, 20 % sinon).
router.get('/commission-rate', getProviderCommissionRate);
router.get('/recommended', getRecommendedPriceRanges);

/**
 * @swagger
 * /pricing/recommended/{serviceType}:
 *   get:
 *     summary: Get recommended price for a specific service
 *     tags: [Pricing]
 *     parameters:
 *       - in: path
 *         name: serviceType
 *         required: true
 *         schema:
 *           type: string
 *           enum: [home_visit, dog_walking, overnight_stay, long_stay]
 *         description: Service type (home_visit, dog_walking, overnight_stay, long_stay)
 *     responses:
 *       200:
 *         description: Recommended price retrieved successfully
 *       400:
 *         description: Invalid service type
 */
router.get('/recommended/:serviceType', getServiceRecommendedPrice);

/**
 * @swagger
 * /pricing/calculate:
 *   post:
 *     summary: Calculate pricing breakdown with commission
 *     tags: [Pricing]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - price
 *               - serviceType
 *             properties:
 *               price:
 *                 type: number
 *                 example: 100
 *               serviceType:
 *                 type: string
 *                 enum: [home_visit, dog_walking, overnight_stay, long_stay]
 *                 example: home_visit
 *     responses:
 *       200:
 *         description: Pricing calculated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 originalPrice:
 *                   type: number
 *                 commission:
 *                   type: number
 *                 sitterEarnings:
 *                   type: number
 *       400:
 *         description: Invalid input
 */
router.post('/calculate', calculatePricing);

/**
 * @swagger
 * /pricing/validate:
 *   post:
 *     summary: Validate sitter's custom price against recommended range
 *     tags: [Pricing]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - price
 *               - serviceType
 *             properties:
 *               price:
 *                 type: number
 *                 example: 25
 *               serviceType:
 *                 type: string
 *                 enum: [home_visit, dog_walking, overnight_stay, long_stay]
 *                 example: home_visit
 *     responses:
 *       200:
 *         description: Price validation result
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 valid:
 *                   type: boolean
 *                 message:
 *                   type: string
 *       400:
 *         description: Invalid input
 */
router.post('/validate', validatePrice);

module.exports = router;

