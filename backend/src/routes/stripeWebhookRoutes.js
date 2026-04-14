const express = require('express');
const { handleStripeWebhook } = require('../controllers/stripeWebhookController');

const router = express.Router();

/**
 * @swagger
 * /webhooks/stripe:
 *   post:
 *     summary: Stripe webhook endpoint for payment events
 *     tags: [Webhooks]
 *     description: |
 *       This endpoint receives webhook events from Stripe for payment-related events.
 *       It handles payment_intent.succeeded, payment_intent.payment_failed, and other Stripe events.
 *       Authentication is done via Stripe signature verification (not JWT).
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             description: Stripe webhook event payload
 *     responses:
 *       200:
 *         description: Webhook processed successfully
 *       400:
 *         description: Invalid webhook signature or payload
 */
// Stripe webhook endpoint - must use raw body parser
router.post(
  '/stripe',
  express.raw({ type: 'application/json', verify: (req, res, buf) => {
    // Store raw body as Buffer for signature verification
    req.rawBody = buf;
  }}),
  (req, res, next) => {
    // Ensure body is a Buffer for webhook signature verification
    if (!Buffer.isBuffer(req.body)) {
      req.body = Buffer.from(JSON.stringify(req.body));
    }
    next();
  },
  handleStripeWebhook
);

module.exports = router;

