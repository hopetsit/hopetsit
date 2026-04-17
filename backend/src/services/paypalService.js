/**
 * PayPal Service - Payment Processing
 *
 * Adds PayPal as an alternative payment option alongside Stripe.
 * Uses PayPal's official server SDK and mirrors the same pricing,
 * commission, and currency logic that we use with Stripe.
 */

const {
  Client,
  Environment,
  OrdersController,
} = require('@paypal/paypal-server-sdk');

let paypalClientInstance = null;
let ordersControllerInstance = null;

/**
 * Lazily initialize and cache the PayPal API client.
 */
const getPaypalClient = () => {
  if (paypalClientInstance) {
    return paypalClientInstance;
  }

  const clientId = process.env.PAYPAL_CLIENT_ID;
  const clientSecret = process.env.PAYPAL_CLIENT_SECRET;

  if (!clientId || !clientSecret) {
    throw new Error('PAYPAL_CLIENT_ID and PAYPAL_CLIENT_SECRET must be configured');
  }

  const env =
    process.env.PAYPAL_ENVIRONMENT === 'live'
      ? Environment.Production
      : Environment.Sandbox;

  paypalClientInstance = new Client({
    clientCredentialsAuthCredentials: {
      oAuthClientId: clientId,
      oAuthClientSecret: clientSecret,
    },
    environment: env,
  });

  return paypalClientInstance;
};

/**
 * Lazily initialize and cache the Orders controller.
 */
const getOrdersController = () => {
  if (ordersControllerInstance) {
    return ordersControllerInstance;
  }
  const client = getPaypalClient();
  ordersControllerInstance = new OrdersController(client);
  return ordersControllerInstance;
};

/**
 * Create a PayPal order for a booking.
 *
 * @param {Object} params
 * @param {number} params.amount - Total amount in major units (e.g. 50.0 for €50)
 * @param {string} params.currency - Currency code (e.g. 'EUR', 'USD')
 * @param {string} params.bookingId - Booking ID for reference/metadata
 * @param {string} params.ownerId - Owner ID for metadata
 * @param {string} params.sitterId - Sitter ID for metadata
 * @returns {Promise<Object>} PayPal Order object (ApiResponse.result)
 */
const createPaypalOrder = async ({
  amount,
  currency,
  bookingId,
  ownerId,
  sitterId,
}) => {
  if (typeof amount !== 'number' || !Number.isFinite(amount) || amount <= 0) {
    throw new Error('PayPal amount must be a positive number.');
  }

  if (!currency || typeof currency !== 'string' || !currency.trim()) {
    throw new Error('Currency is required for PayPal order.');
  }

  const normalizedCurrency = currency.toUpperCase();

  const ordersController = getOrdersController();

  const valueString = amount.toFixed(2); // PayPal expects string value with 2 decimals

  // Optional return / cancel URLs for redirecting back to app or website
  // Example env values:
  // PAYPAL_RETURN_URL=https://petinsta.com/paypal-success
  // PAYPAL_CANCEL_URL=https://petinsta.com/paypal-cancel
  const returnUrl = process.env.PAYPAL_RETURN_URL;
  const cancelUrl = process.env.PAYPAL_CANCEL_URL;

  const body = {
    intent: 'CAPTURE',
    purchaseUnits: [
      {
        referenceId: bookingId,
        amount: {
          currencyCode: normalizedCurrency,
          value: valueString,
        },
        customId: bookingId,
        description: `Booking ${bookingId} payment for sitter ${sitterId}`,
      },
    ],
    applicationContext: {
      userAction: 'PAY_NOW',
      ...(returnUrl ? { returnUrl } : {}),
      ...(cancelUrl ? { cancelUrl } : {}),
    },
  };

  const response = await ordersController.createOrder({
    body,
    prefer: 'return=representation',
  });

  return response.result;
};

/**
 * Capture a PayPal order.
 *
 * @param {string} orderId - PayPal order ID
 * @returns {Promise<Object>} Captured order details (ApiResponse.result)
 */
const capturePaypalOrder = async (orderId) => {
  if (!orderId || typeof orderId !== 'string') {
    throw new Error('PayPal order ID is required to capture payment.');
  }

  const ordersController = getOrdersController();
  const response = await ordersController.captureOrder({
    id: orderId,
    prefer: 'return=representation',
  });

  return response.result;
};

/**
 * Get PayPal order details by ID.
 *
 * @param {string} orderId - PayPal order ID
 * @returns {Promise<Object>} Order details (ApiResponse.result)
 */
const getPaypalOrder = async (orderId) => {
  if (!orderId || typeof orderId !== 'string') {
    throw new Error('PayPal order ID is required to fetch order details.');
  }

  const ordersController = getOrdersController();
  const response = await ordersController.getOrder({
    id: orderId,
  });

  return response.result;
};

/**
 * Refund a captured PayPal payment (full refund).
 * Uses the PayPal REST API v2 /v2/payments/captures/{captureId}/refund
 * since the SDK's PaymentsController may not be available in all builds.
 */
const refundPaypalCapture = async (captureId) => {
  if (!captureId) throw new Error('PayPal capture ID is required for refund.');

  const clientId = process.env.PAYPAL_CLIENT_ID;
  const clientSecret = process.env.PAYPAL_CLIENT_SECRET;
  if (!clientId || !clientSecret) throw new Error('PayPal credentials not configured.');

  const isLive = process.env.PAYPAL_ENVIRONMENT === 'live';
  const baseUrl = isLive
    ? 'https://api-m.paypal.com'
    : 'https://api-m.sandbox.paypal.com';

  // Get access token
  const tokenRes = await fetch(`${baseUrl}/v1/oauth2/token`, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${Buffer.from(`${clientId}:${clientSecret}`).toString('base64')}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: 'grant_type=client_credentials',
  });
  const tokenData = await tokenRes.json();
  if (!tokenData.access_token) throw new Error('Failed to get PayPal access token for refund.');

  // Issue refund
  const refundRes = await fetch(`${baseUrl}/v2/payments/captures/${captureId}/refund`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${tokenData.access_token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({}), // empty body = full refund
  });
  const refundData = await refundRes.json();
  if (refundData.status === 'COMPLETED' || refundData.status === 'PENDING') {
    return refundData;
  }
  throw new Error(`PayPal refund failed: ${JSON.stringify(refundData)}`);
};

module.exports = {
  createPaypalOrder,
  capturePaypalOrder,
  getPaypalOrder,
  refundPaypalCapture,
};

