/**
 * Stripe Connect Controller
 * 
 * Handles Stripe Connect onboarding and account management for sitters
 */

const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const {
  createConnectAccount,
  createAccountLink,
  getAccountStatus,
} = require('../services/stripeService');
const { sanitizeUser } = require('../utils/sanitize');
const { resolveCountry, ibanToCountry } = require('../utils/stripeCountry');
const logger = require('../utils/logger');

// Session v17 — Stripe Connect is now available for both sitters and
// walkers. All four endpoints below previously hard-rejected walker with
// a 403 "Only sitters can..." — walkers physically couldn't connect
// Stripe, which blocked the entire payout flow for them.
//
// Walker has the exact same payout-relevant fields as Sitter
// (stripeConnectAccountId, stripeConnectAccountStatus, country,
// ibanNumber, location), so the only thing that changes per role is
// the model lookup. Helper below keeps the rest of the code generic.
const getProviderModel = (role) => (role === 'walker' ? Walker : Sitter);

/**
 * Create Stripe Connect account for sitter
 * POST /stripe-connect/create-account
 */
const createStripeConnectAccount = async (req, res) => {
  try {
    const userId = req.user?.id;
    const userRole = req.user?.role;

    if (!userId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (!['sitter', 'walker'].includes(userRole)) {
      return res.status(403).json({ error: 'Only sitters or walkers can create Stripe Connect accounts.' });
    }

    const Model = getProviderModel(userRole);
    const provider = await Model.findById(userId);
    if (!provider) {
      return res.status(404).json({ error: 'Provider not found.' });
    }

    // Fix invalid location before saving (MongoDB 2dsphere index requires valid coordinates or no location)
    if (provider.location && (!provider.location.coordinates ||
        !Array.isArray(provider.location.coordinates) ||
        provider.location.coordinates.length !== 2)) {
      // Remove invalid location field to prevent geo index error
      provider.location = undefined;
    }

    let accountId = provider.stripeConnectAccountId;
    let isNewAccount = false;

    // Create Stripe Connect account if it doesn't exist
    if (!accountId) {
      let country = resolveCountry({
        explicit: req.body?.country,
        sitterCountry: provider.country,
        ibanCountry: ibanToCountry(provider.ibanNumber),
        acceptLanguage: req.headers['accept-language'],
      });
      // v18.9 — fallback FR par défaut au lieu de bloquer l'onboarding.
      // Avant v18.9, un walker/sitter sans country + sans IBAN + sans
      // Accept-Language tapait un 400 "Unable to determine country" dès
      // l'ouverture du flow Stripe Connect. On propose FR en défaut —
      // Stripe permet de changer le pays à la phase KYC si besoin.
      if (!country) {
        country = 'FR';
      }
      const account = await createConnectAccount({
        email: provider.email,
        name: provider.name,
        country,
      });

      // Save account ID to provider (sitter or walker)
      // Use updateOne to avoid Mongoose applying invalid location defaults
      const updateOps = {
        $set: {
          stripeConnectAccountId: account.id,
          stripeConnectAccountStatus: 'pending'
        }
      };

      // Remove invalid location if needed
      if (provider.location === undefined ||
          !provider.location.coordinates ||
          !Array.isArray(provider.location.coordinates) ||
          provider.location.coordinates.length !== 2) {
        updateOps.$unset = { location: '' };
      }

      await Model.updateOne({ _id: userId }, updateOps);

      // Refresh provider object
      provider.stripeConnectAccountId = account.id;
      provider.stripeConnectAccountStatus = 'pending';

      accountId = account.id;
      isNewAccount = true;
    }

    // Generate account link for onboarding (works for both new and existing accounts)
    const defaultReturnUrl = process.env.STRIPE_CONNECT_RETURN_URL || 'http://localhost:5000/stripe-connect/return';
    const defaultRefreshUrl = process.env.STRIPE_CONNECT_REFRESH_URL || 'http://localhost:5000/stripe-connect/refresh';

    const accountLink = await createAccountLink({
      accountId: accountId,
      returnUrl: defaultReturnUrl,
      refreshUrl: defaultRefreshUrl,
    });

    res.json({
      accountId: accountId,
      onboardingUrl: accountLink.url,
      expiresAt: accountLink.expires_at,
      message: isNewAccount
        ? 'Stripe Connect account created. Use the onboardingUrl to complete onboarding.'
        : 'Account link generated. Use the onboardingUrl to complete or update your onboarding.',
      // v17 — keep response key "sitter" for frontend backward-compat. When
      // the caller is a walker, the same sanitized provider doc is returned.
      sitter: sanitizeUser(provider, { includeEmail: true }),
    });
  } catch (error) {
    logger.error('Create Stripe Connect account error', error);
    if (error.message && error.message.includes('STRIPE_SECRET_KEY')) {
      return res.status(500).json({ error: 'Payment service is not configured.' });
    }
    if (error.type === 'StripeInvalidRequestError' && error.message && error.message.includes('Connect')) {
      // v18.9.1 — code machine-lisible pour que le front traduise en FR.
      return res.status(503).json({
        error: 'Stripe Connect is not enabled on this platform account.',
        code: 'STRIPE_CONNECT_PLATFORM_NOT_ENABLED',
        details: 'Platform owner must enable Connect on their Stripe account (dashboard.stripe.com → Connect → Get started).',
      });
    }
    res.status(500).json({ 
      error: 'Unable to create Stripe Connect account. Please try again later.',
      details: error.message || 'Unknown error occurred'
    });
  }
};

/**
 * Create account link for Stripe Connect onboarding
 * POST /stripe-connect/create-account-link
 */
const createStripeAccountLink = async (req, res) => {
  try {
    const userId = req.user?.id;
    const userRole = req.user?.role;
    const { returnUrl, refreshUrl } = req.body || {};

    if (!userId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (!['sitter', 'walker'].includes(userRole)) {
      return res.status(403).json({ error: 'Only sitters or walkers can create Stripe Connect account links.' });
    }

    const Model = getProviderModel(userRole);
    const provider = await Model.findById(userId);
    if (!provider) {
      return res.status(404).json({ error: 'Provider not found.' });
    }

    if (!provider.stripeConnectAccountId) {
      return res.status(400).json({
        error: 'Stripe Connect account does not exist. Create an account first.'
      });
    }

    // Default URLs if not provided
    const defaultReturnUrl = process.env.STRIPE_CONNECT_RETURN_URL || 'https://your-app.com/stripe-connect/return';
    const defaultRefreshUrl = process.env.STRIPE_CONNECT_REFRESH_URL || 'https://your-app.com/stripe-connect/refresh';

    const accountLink = await createAccountLink({
      accountId: provider.stripeConnectAccountId,
      returnUrl: returnUrl || defaultReturnUrl,
      refreshUrl: refreshUrl || defaultRefreshUrl,
    });

    res.json({
      url: accountLink.url,
      expiresAt: accountLink.expires_at,
      message: 'Account link created. Redirect user to the URL to complete onboarding.',
    });
  } catch (error) {
    logger.error('Create account link error', error);
    if (error.message && error.message.includes('STRIPE_SECRET_KEY')) {
      return res.status(500).json({ error: 'Payment service is not configured.' });
    }
    res.status(500).json({ error: 'Unable to create account link. Please try again later.' });
  }
};

/**
 * Get Stripe Connect account status
 * GET /stripe-connect/account-status
 */
const getStripeAccountStatus = async (req, res) => {
  try {
    const userId = req.user?.id;
    const userRole = req.user?.role;

    if (!userId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (!['sitter', 'walker'].includes(userRole)) {
      return res.status(403).json({ error: 'Only sitters or walkers can view Stripe Connect account status.' });
    }

    const Model = getProviderModel(userRole);
    const provider = await Model.findById(userId);
    if (!provider) {
      return res.status(404).json({ error: 'Provider not found.' });
    }

    if (!provider.stripeConnectAccountId) {
      return res.json({
        connected: false,
        status: 'not_connected',
        message: 'Stripe Connect account not created yet.',
      });
    }

    // Get account status from Stripe
    const accountStatus = await getAccountStatus(provider.stripeConnectAccountId);

    // Update provider's account status
    let status = 'pending';
    if (accountStatus.charges_enabled && accountStatus.payouts_enabled && accountStatus.details_submitted) {
      status = 'active';
    } else if (accountStatus.requirements && Object.keys(accountStatus.requirements).length > 0) {
      status = 'restricted';
    }

    // Use updateOne to avoid Mongoose applying invalid location defaults
    const updateOps = {
      $set: { stripeConnectAccountStatus: status }
    };

    // Remove invalid location if needed
    if (!provider.location ||
        !provider.location.coordinates ||
        !Array.isArray(provider.location.coordinates) ||
        provider.location.coordinates.length !== 2) {
      updateOps.$unset = { location: '' };
    }

    await Model.updateOne({ _id: userId }, updateOps);

    // Refresh provider object
    provider.stripeConnectAccountStatus = status;

    // Format response for payout status screen
    const verificationStatus = {
      identityVerification: accountStatus.requirements?.currently_due?.some(item => 
        item.includes('identity') || item.includes('individual')
      ) ? 'pending' : 'complete',
      bankAccountVerification: accountStatus.payouts_enabled ? 'complete' : 'pending',
      businessInformation: accountStatus.details_submitted ? 'complete' : 'pending',
    };

    const allVerificationsComplete = 
      verificationStatus.identityVerification === 'complete' &&
      verificationStatus.bankAccountVerification === 'complete' &&
      verificationStatus.businessInformation === 'complete';

    res.json({
      connected: true,
      accountId: provider.stripeConnectAccountId,
      status: status,
      chargesEnabled: accountStatus.charges_enabled,
      payoutsEnabled: accountStatus.payouts_enabled,
      detailsSubmitted: accountStatus.details_submitted,
      verificationStatus,
      allVerificationsComplete,
      requirements: accountStatus.requirements || {},
      message: status === 'active'
        ? 'Stripe Connect account is active and ready to receive payouts.'
        : 'Stripe Connect account is being set up. Complete verification to receive payouts.',
    });
  } catch (error) {
    logger.error('Get account status error', error);
    if (error.message && error.message.includes('STRIPE_SECRET_KEY')) {
      return res.status(500).json({ error: 'Payment service is not configured.' });
    }
    if (error.type === 'StripeInvalidRequestError') {
      return res.status(400).json({ 
        error: 'Unable to fetch account status. The Stripe Connect account may not exist or may be invalid.',
        details: error.message || 'Invalid request to Stripe'
      });
    }
    res.status(500).json({ 
      error: 'Unable to fetch account status. Please try again later.',
      details: error.message || 'Unknown error occurred'
    });
  }
};

/**
 * Handle Stripe Connect return URL (after successful onboarding)
 * GET /stripe-connect/return
 */
const handleStripeConnectReturn = async (req, res) => {
  try {
    // Stripe redirects here after onboarding is complete
    // Query params may include account ID and other info
    const { account } = req.query;

    // If account ID is provided, we can update the provider's account status.
    // Session v17 — we don't know the role at this point (Stripe redirects
    // without role context), so we look up the account in both Sitter and
    // Walker collections. stripeConnectAccountId is a unique Stripe-side id
    // so there can never be a collision between sitter and walker.
    if (account) {
      try {
        let provider = await Sitter.findOne({ stripeConnectAccountId: account });
        let ProviderModel = Sitter;
        if (!provider) {
          provider = await Walker.findOne({ stripeConnectAccountId: account });
          if (provider) ProviderModel = Walker;
        }
        if (provider) {
          // Get updated account status from Stripe
          const accountStatus = await getAccountStatus(account);

          // Update provider's account status
          let status = 'pending';
          if (accountStatus.charges_enabled && accountStatus.payouts_enabled && accountStatus.details_submitted) {
            status = 'active';
          } else if (accountStatus.requirements && Object.keys(accountStatus.requirements).length > 0) {
            status = 'restricted';
          }

          // Use updateOne to avoid Mongoose applying invalid location defaults
          const updateOps = {
            $set: { stripeConnectAccountStatus: status }
          };

          // Remove invalid location if needed
          if (!provider.location ||
              !provider.location.coordinates ||
              !Array.isArray(provider.location.coordinates) ||
              provider.location.coordinates.length !== 2) {
            updateOps.$unset = { location: '' };
          }

          await ProviderModel.updateOne({ _id: provider._id }, updateOps);

          // Refresh provider object
          provider.stripeConnectAccountStatus = status;
        }
      } catch (error) {
        logger.error('Error updating account status on return:', error);
        // Continue anyway - don't fail the redirect
      }
    }

    // Return a simple success message
    // In production, you might want to redirect to your frontend app
    res.status(200).json({
      success: true,
      message: 'Stripe Connect onboarding completed successfully!',
      accountId: account || null,
      note: 'You can now close this window and return to the app.',
    });
  } catch (error) {
    logger.error('Handle Stripe Connect return error', error);
    res.status(200).json({
      success: true,
      message: 'Redirect received from Stripe. Please check your account status in the app.',
    });
  }
};

/**
 * Handle Stripe Connect refresh URL (if onboarding session expires)
 * GET /stripe-connect/refresh
 */
const handleStripeConnectRefresh = async (req, res) => {
  try {
    // Stripe redirects here if the onboarding session expired
    const { account } = req.query;

    res.status(200).json({
      success: false,
      message: 'Onboarding session expired. Please start the onboarding process again.',
      accountId: account || null,
      note: 'Call the create-account endpoint again to get a new onboarding link.',
    });
  } catch (error) {
    logger.error('Handle Stripe Connect refresh error', error);
    res.status(200).json({
      success: false,
      message: 'Onboarding session expired. Please try again.',
    });
  }
};

module.exports = {
  createStripeConnectAccount,
  createStripeAccountLink,
  getStripeAccountStatus,
  handleStripeConnectReturn,
  handleStripeConnectRefresh,
};

