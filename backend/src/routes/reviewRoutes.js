const express = require('express');

const { createReview, listReviews, replyToReview, reportReview } = require('../controllers/reviewController');
const { requireAuth, requireRole } = require('../middleware/auth');

const router = express.Router();

/**
 * @swagger
 * /reviews:
 *   post:
 *     summary: Create a review for a sitter (Owner only)
 *     tags: [Reviews]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - sitterId
 *               - bookingId
 *               - rating
 *             properties:
 *               sitterId:
 *                 type: string
 *                 example: 507f1f77bcf86cd799439011
 *               bookingId:
 *                 type: string
 *                 example: 507f1f77bcf86cd799439012
 *               rating:
 *                 type: number
 *                 minimum: 1
 *                 maximum: 5
 *                 example: 5
 *               comment:
 *                 type: string
 *                 example: Great service!
 *     responses:
 *       201:
 *         description: Review created successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Review'
 *       400:
 *         description: Invalid input
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Only owners can create reviews
 */
// Sprint 7 step 4 — mutual reviews (owner or sitter can review).
router.post('/', requireAuth, createReview);

// Sprint 7 step 4 — reply (once) to a review (reviewee only).
router.post('/:id/reply', requireAuth, replyToReview);

// Sprint 7 step 5 — report a review as inappropriate.
router.post('/:id/report', requireAuth, reportReview);

/**
 * @swagger
 * /reviews:
 *   get:
 *     summary: List all reviews
 *     tags: [Reviews]
 *     parameters:
 *       - in: query
 *         name: sitterId
 *         schema:
 *           type: string
 *         description: Filter by sitter ID
 *       - in: query
 *         name: bookingId
 *         schema:
 *           type: string
 *         description: Filter by booking ID
 *     responses:
 *       200:
 *         description: Reviews retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 reviews:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Review'
 */
router.get('/', listReviews);

module.exports = router;

