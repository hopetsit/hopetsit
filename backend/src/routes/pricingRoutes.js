const express = require('express');

const {
  getRecommendedPriceRanges,
  getServiceRecommendedPrice,
  calculatePricing,
  validatePrice,
} = require('../controllers/pricingController');

const router = express.Router();

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

