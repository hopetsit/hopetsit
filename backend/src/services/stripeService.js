/**
 * Stripe Service - Payment Processing with Stripe Connect
 * 
 * Handles:
 * - PaymentIntent creation with destination charges (20% commission)
 * - Stripe Connect account creation and onboarding
 * - Refund processing
 * - Webhook event handling
 */

const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

const PLATFORM_COMMISSION_RATE = 0.2; // 20%

/**
 * Create a PaymentIntent with destination charge (Stripe Connect)
 * @param {Object} params - Payment parameters
 * @param {number} params.amount - Total amount in cents (minor units)
 * @param {string} params.currency - Required. Currency code (e.g. 'eur', 'usd') - lowercase for Stripe
 * @param {string} params.connectedAccountId - Stripe Connect account ID of the sitter
 * @param {string} params.bookingId - Booking ID for metadata
 * @param {string} params.ownerId - Owner ID for metadata
 * @param {string} params.sitterId - Sitter ID for metadata
 * @returns {Promise<Object>} PaymentIntent object
 */
/**
 * Create a PLATFORM-only PaymentIntent (no Stripe Connect destination).
 * Used by: boost, subscription (Premium), map-boost.
 *
 * @param {Object} params
 * @param {number} params.amount   — total in cents (minor units)
 * @param {string} params.currency — ISO lowercase ('eur','gbp','chf','usd')
 * @param {Object} [params.metadata] — freeform tracking metadata
 */
const createPlatformPaymentIntent = async ({ amount, currency, metadata = {} }) => {
  if (!process.env.STRIPE_SECRET_KEY) {
    throw new Error('STRIPE_SECRET_KEY is not configured');
  }
  if (!currency || typeof currency !== 'string' || !currency.trim()) {
    throw new Error('Currency is required for PaymentIntent');
  }
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new Error('Amount must be a positive integer in cents');
  }

  // Convert metadata values to strings (Stripe requires string values).
  const stripeMetadata = {};
  for (const [k, v] of Object.entries(metadata || {})) {
    if (v !== undefined && v !== null) stripeMetadata[k] = String(v);
  }

  return stripe.paymentIntents.create({
    amount: Math.round(amount),
    currency: currency.toLowerCase(),
    automatic_payment_methods: { enabled: true },
    metadata: stripeMetadata,
  });
};

const createPaymentIntent = async ({
  amount,
  currency,
  connectedAccountId,  // Session v18.0 — optional. When null, charge lands on
                       // the platform account and payoutScheduler releases the
                       // provider share to their IBAN or PayPal at service start.
  bookingId,
  ownerId,
  sitterId,
  providerType,
  isTopSitter = false,
  // Session v18.2 — when provided, Stripe attaches the PaymentMethod used
  // for this payment to the Customer, so the owner's "Mes paiements" page
  // can list and reuse the card later. setupFutureUsage default 'off_session'
  // means we can charge again without the CVV.
  stripeCustomerId = null,
  setupFutureUsage = 'off_session',
}) => {
  if (!process.env.STRIPE_SECRET_KEY) {
    throw new Error('STRIPE_SECRET_KEY is not configured');
  }

  if (!currency || typeof currency !== 'string' || !currency.trim()) {
    throw new Error('Currency is required for PaymentIntent');
  }

  // Sprint 7 step 2 — Top Sitters pay reduced commission (15% instead of 20%).
  // Only used when destination charges are active (connectedAccountId set).
  const commissionRate = isTopSitter ? 0.15 : PLATFORM_COMMISSION_RATE;
  const applicationFeeAmount = Math.round(amount * commissionRate);

  // Base PaymentIntent parameters — shared across destination charges and
  // plain platform charges.
  const paymentIntentParams = {
    amount,
    currency: currency.toLowerCase(),
    automatic_payment_methods: { enabled: true },
    metadata: {
      booking_id: bookingId.toString(),
      pet_owner_id: ownerId.toString(),
      petsitter_id: sitterId.toString(),
      platform_fee_amount: applicationFeeAmount.toString(),
      net_to_petsitter: (amount - applicationFeeAmount).toString(),
      provider_type: providerType || 'sitter',
      charge_mode: connectedAccountId ? 'destination' : 'platform_then_payout',
    },
  };

  // Session v18.0 — two charge modes:
  // 1. Destination charge (legacy, requires Stripe Connect) — fires when
  //    connectedAccountId is provided. Funds go straight to the provider's
  //    Stripe account; platform keeps application_fee_amount automatically.
  // 2. Platform charge (new) — when connectedAccountId is null. Funds land
  //    on the platform account; processProviderPayoutForBooking fires at
  //    service-start time via payoutScheduler to push the 80% to the
  //    provider's IBAN (Stripe Transfer) or PayPal (PayPal Payout).
  if (connectedAccountId) {
    paymentIntentParams.application_fee_amount = applicationFeeAmount;
    paymentIntentParams.transfer_data = { destination: connectedAccountId };
  }

  // Session v18.2 — attach to the owner's Stripe Customer so the card
  // gets saved and can be reused from the "Mes paiements" screen.
  if (stripeCustomerId) {
    paymentIntentParams.customer = stripeCustomerId;
    if (setupFutureUsage) {
      paymentIntentParams.setup_future_usage = setupFutureUsage;
    }
  }

  const paymentIntent = await stripe.paymentIntents.create(paymentIntentParams);
  return paymentIntent;
};

/**
 * Create Stripe Connect account (Express account for sitters)
 * @param {Object} params - Account parameters
 * @param {string} params.email - Sitter's email
 * @param {string} params.name - Sitter's name
 * @returns {Promise<Object>} Account object
 */
const { SUPPORTED_STRIPE_COUNTRIES } = require('../utils/stripeCountry');

const createConnectAccount = async ({ email, name, country }) => {
  if (!process.env.STRIPE_SECRET_KEY) {
    throw new Error('STRIPE_SECRET_KEY is not configured');
  }
  if (!country || !SUPPORTED_STRIPE_COUNTRIES.includes(country)) {
    const err = new Error(
      `Country required for Stripe Connect account creation. Supported: ${SUPPORTED_STRIPE_COUNTRIES.join(', ')}`
    );
    err.statusCode = 400;
    throw err;
  }

  const account = await stripe.accounts.create({
    type: 'express',
    country,
    email,
    capabilities: {
      card_payments: { requested: true },
      transfers: { requested: true },
    },
    business_type: 'individual',
    metadata: {
      name,
      country,
    },
  });

  return account;
};

/**
 * Create account link for Stripe Connect onboarding
 * @param {string} accountId - Stripe Connect account ID
 * @param {string} returnUrl - URL to return to after onboarding
 * @param {string} refreshUrl - URL to refresh if session expires
 * @returns {Promise<Object>} Account link object
 */
const createAccountLink = async ({ accountId, returnUrl, refreshUrl }) => {
  if (!process.env.STRIPE_SECRET_KEY) {
    throw new Error('STRIPE_SECRET_KEY is not configured');
  }

  const accountLink = await stripe.accountLinks.create({
    account: accountId,
    refresh_url: refreshUrl,
    return_url: returnUrl,
    type: 'account_onboarding',
  });

  return accountLink;
};

/**
 * Get Stripe Connect account status
 * @param {string} accountId - Stripe Connect account ID
 * @returns {Promise<Object>} Account object with status
 */
const getAccountStatus = async (accountId) => {
  if (!process.env.STRIPE_SECRET_KEY) {
    throw new Error('STRIPE_SECRET_KEY is not configured');
  }

  const account = await stripe.accounts.retrieve(accountId);

  return {
    id: account.id,
    charges_enabled: account.charges_enabled,
    payouts_enabled: account.payouts_enabled,
    details_submitted: account.details_submitted,
    requirements: account.requirements || {},
  };
};

/**
 * Create a refund for a charge
 * @param {string} chargeId - Stripe charge ID
 * @param {number} amount - Amount to refund in cents (null for full refund)
 * @returns {Promise<Object>} Refund object
 */
const createRefund = async (chargeId, amount = null) => {
  if (!process.env.STRIPE_SECRET_KEY) {
    throw new Error('STRIPE_SECRET_KEY is not configured');
  }

  const refundParams = {
    charge: chargeId,
  };

  if (amount) {
    refundParams.amount = amount;
  }

  const refund = await stripe.refunds.create(refundParams);

  return refund;
};

/**
 * Retrieve a PaymentIntent by ID
 * @param {string} paymentIntentId - Stripe PaymentIntent ID
 * @returns {Promise<Object>} PaymentIntent object
 */
const getPaymentIntent = async (paymentIntentId) => {
  if (!process.env.STRIPE_SECRET_KEY) {
    throw new Error('STRIPE_SECRET_KEY is not configured');
  }

  const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);

  return paymentIntent;
};

/**
 * Confirm a PaymentIntent by ID
 * @param {string} paymentIntentId - Stripe PaymentIntent ID
 * @param {Object} options - Optional confirmation parameters
 * @param {string} options.payment_method - Payment method ID (optional)
 * @param {string} options.return_url - Return URL for redirect-based payment methods (optional)
 * @returns {Promise<Object>} Confirmed PaymentIntent object
 */
const confirmPaymentIntent = async (paymentIntentId, options = {}) => {
  if (!process.env.STRIPE_SECRET_KEY) {
    throw new Error('STRIPE_SECRET_KEY is not configured');
  }

  // First retrieve the payment intent to check its current status
  const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);

  // If already succeeded, return it
  if (paymentIntent.status === 'succeeded') {
    return paymentIntent;
  }

  // If already canceled, throw error
  if (paymentIntent.status === 'canceled') {
    throw new Error('Payment intent has been canceled');
  }

  // Confirm the payment intent
  const confirmParams = {};
  if (options.payment_method) {
    confirmParams.payment_method = options.payment_method;
  }
  if (options.return_url) {
    confirmParams.return_url = options.return_url;
  }

  const confirmedPaymentIntent = await stripe.paymentIntents.confirm(
    paymentIntentId,
    Object.keys(confirmParams).length > 0 ? confirmParams : undefined
  );

  return confirmedPaymentIntent;
};

/**
 * Construct webhook event from raw body and signature
 * @param {string} rawBody - Raw request body
 * @param {string} signature - Stripe signature from header
 * @returns {Object} Webhook event object
 */
const constructWebhookEvent = (rawBody, signature) => {
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
  
  if (!webhookSecret) {
    throw new Error('STRIPE_WEBHOOK_SECRET is not configured');
  }

  return stripe.webhooks.constructEvent(rawBody, signature, webhookSecret);
};

/**
 * Create a Stripe Customer + Bank-Account (IBAN) token, then send a payout
 * via Stripe Transfers to an external bank account.
 *
 * Flow: Platform balance ──Transfer──> sitter's external bank (IBAN/SEPA).
 *
 * @param {Object} params
 * @param {string} params.iban        - IBAN of the sitter
 * @param {string} params.holderName  - Account holder name
 * @param {string} params.email       - Sitter email (for Stripe Customer)
 * @param {number} params.amount      - Amount in cents (minor units)
 * @param {string} params.currency    - e.g. 'eur'
 * @param {string} params.bookingId   - For metadata
 * @param {string} params.sitterId    - For metadata
 * @returns {Promise<Object>} { transfer, customerId, bankAccountId }
 */
const sendPayoutToIBAN = async ({
  iban,
  holderName,
  email,
  amount,
  currency = 'eur',
  bookingId,
  sitterId,
}) => {
  if (!process.env.STRIPE_SECRET_KEY) {
    throw new Error('STRIPE_SECRET_KEY is not configured');
  }

  // 1. Create (or retrieve) a Stripe Customer for the sitter
  const customers = await stripe.customers.list({ email, limit: 1 });
  let customer;
  if (customers.data.length > 0) {
    customer = customers.data[0];
  } else {
    customer = await stripe.customers.create({
      email,
      name: holderName,
      metadata: { sitterId, type: 'iban_payout' },
    });
  }

  // 2. Create a bank-account token via IBAN
  const token = await stripe.tokens.create({
    bank_account: {
      country: iban.substring(0, 2).toUpperCase(), // first 2 chars = country
      currency: currency.toLowerCase(),
      account_holder_name: holderName,
      account_holder_type: 'individual',
      account_number: iban,
    },
  });

  // 3. Attach bank account to customer (if not already attached)
  let bankAccount;
  try {
    bankAccount = await stripe.customers.createSource(customer.id, {
      source: token.id,
    });
  } catch (err) {
    // If already attached, Stripe will error — try to find existing
    if (err.code === 'bank_account_exists') {
      const sources = await stripe.customers.listSources(customer.id, {
        object: 'bank_account',
        limit: 10,
      });
      bankAccount = sources.data.find((s) => s.last4 === iban.slice(-4));
    }
    if (!bankAccount) throw err;
  }

  // 4. Create a Transfer from platform to the customer's bank account
  const transfer = await stripe.transfers.create({
    amount,
    currency: currency.toLowerCase(),
    destination: customer.id,
    metadata: {
      bookingId,
      sitterId,
      payoutMethod: 'iban',
    },
  });

  return {
    transfer,
    customerId: customer.id,
    bankAccountId: bankAccount.id,
  };
};

// ─── Session v18.2 — owner "Mes paiements" helpers ─────────────────────
// Stripe Customer is created on the owner's first payment so the card is
// stored off-session + can be reused across bookings. The payment sheet
// attaches the PaymentMethod to the Customer automatically when we pass
// `setup_future_usage: 'off_session'` on the PaymentIntent.
const getOrCreateStripeCustomerForOwner = async ({ ownerId, email, name }) => {
  const Owner = require('../models/Owner');
  const owner = await Owner.findById(ownerId);
  if (!owner) throw new Error('Owner not found.');
  if (owner.stripeCustomerId) {
    return owner.stripeCustomerId;
  }
  const customer = await stripe.customers.create({
    email: email || undefined,
    name: name || undefined,
    metadata: { owner_id: ownerId.toString() },
  });
  owner.stripeCustomerId = customer.id;
  await owner.save();
  return customer.id;
};

const createSetupIntentForOwner = async (customerId) => {
  return stripe.setupIntents.create({
    customer: customerId,
    automatic_payment_methods: { enabled: true },
    usage: 'off_session',
  });
};

const listOwnerPaymentMethods = async (customerId) => {
  if (!customerId) return [];
  const list = await stripe.paymentMethods.list({
    customer: customerId,
    type: 'card',
    limit: 20,
  });
  return (list.data || []).map((pm) => ({
    id: pm.id,
    brand: pm.card?.brand || '',
    last4: pm.card?.last4 || '',
    expMonth: pm.card?.exp_month || null,
    expYear: pm.card?.exp_year || null,
    holder: pm.billing_details?.name || '',
  }));
};

const detachOwnerPaymentMethod = async (paymentMethodId) => {
  return stripe.paymentMethods.detach(paymentMethodId);
};

module.exports = {
  PLATFORM_COMMISSION_RATE,
  createPaymentIntent,
  createPlatformPaymentIntent,
  createConnectAccount,
  createAccountLink,
  getAccountStatus,
  createRefund,
  getPaymentIntent,
  confirmPaymentIntent,
  constructWebhookEvent,
  sendPayoutToIBAN,
  // v18.2
  getOrCreateStripeCustomerForOwner,
  createSetupIntentForOwner,
  listOwnerPaymentMethods,
  detachOwnerPaymentMethod,
};

