const express = require('express');
const {
  createStripeConnectAccount,
  createStripeAccountLink,
  getStripeAccountStatus,
  handleStripeConnectReturn,
  handleStripeConnectRefresh,
} = require('../controllers/stripeConnectController');
const { requireAuth, requireRole } = require('../middleware/auth');

const router = express.Router();

/**
 * @swagger
 * /stripe-connect/create-account:
 *   post:
 *     summary: Create Stripe Connect account (Sitter only)
 *     tags: [Stripe Connect]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Stripe Connect account created successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 accountId:
 *                   type: string
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Only sitters can create Stripe Connect accounts
 */
router.post('/create-account', requireAuth, requireRole('sitter', 'walker'), createStripeConnectAccount);

/**
 * @swagger
 * /stripe-connect/create-account-link:
 *   post:
 *     summary: Create Stripe Connect account link for onboarding (Sitter only)
 *     tags: [Stripe Connect]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               returnUrl:
 *                 type: string
 *                 example: https://app.petsinsta.com/stripe/return
 *               refreshUrl:
 *                 type: string
 *                 example: https://app.petsinsta.com/stripe/refresh
 *     responses:
 *       200:
 *         description: Account link created successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 url:
 *                   type: string
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Only sitters can access this endpoint
 */
router.post('/create-account-link', requireAuth, requireRole('sitter', 'walker'), createStripeAccountLink);

/**
 * @swagger
 * /stripe-connect/account-status:
 *   get:
 *     summary: Get Stripe Connect account status (Sitter only)
 *     tags: [Stripe Connect]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Account status retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 accountId:
 *                   type: string
 *                 status:
 *                   type: string
 *                 chargesEnabled:
 *                   type: boolean
 *                 payoutsEnabled:
 *                   type: boolean
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Only sitters can access this endpoint
 */
router.get('/account-status', requireAuth, requireRole('sitter', 'walker'), getStripeAccountStatus);

/**
 * @swagger
 * /stripe-connect/return:
 *   get:
 *     summary: Stripe Connect return URL (called by Stripe)
 *     tags: [Stripe Connect]
 *     parameters:
 *       - in: query
 *         name: state
 *         schema:
 *           type: string
 *         description: State parameter from Stripe
 *     responses:
 *       200:
 *         description: Return URL handled successfully
 */
router.get('/return', handleStripeConnectReturn);

/**
 * @swagger
 * /stripe-connect/refresh:
 *   get:
 *     summary: Stripe Connect refresh URL (called by Stripe)
 *     tags: [Stripe Connect]
 *     parameters:
 *       - in: query
 *         name: state
 *         schema:
 *           type: string
 *         description: State parameter from Stripe
 *     responses:
 *       200:
 *         description: Refresh URL handled successfully
 */
router.get('/refresh', handleStripeConnectRefresh);

module.exports = router;

