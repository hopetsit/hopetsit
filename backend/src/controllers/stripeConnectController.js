/**
 * Stripe Connect Controller
 * 
 * Handles Stripe Connect onboarding and account management for sitters
 */

const Sitter = require('../models/Sitter');
const {
  createConnectAccount,
  createAccountLink,
  getAccountStatus,
} = require('../services/stripeService');
const { sanitizeUser } = require('../utils/sanitize');
const { resolveCountry, ibanToCountry } = require('../utils/stripeCountry');
const logger = require('../utils/logger');

/**
 * Create Stripe Connect account for sitter
 * POST /stripe-connect/create-account
 */
const createStripeConnectAccount = async (req, res) => {
  try {
    const sitterId = req.user?.id;
    const userRole = req.user?.role;

    if (!sitterId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (userRole !== 'sitter') {
      return res.status(403).json({ error: 'Only sitters can create Stripe Connect accounts.' });
    }

    const sitter = await Sitter.findById(sitterId);
    if (!sitter) {
      return res.status(404).json({ error: 'Sitter not found.' });
    }

    // Fix invalid location before saving (MongoDB 2dsphere index requires valid coordinates or no location)
    if (sitter.location && (!sitter.location.coordinates || 
        !Array.isArray(sitter.location.coordinates) || 
        sitter.location.coordinates.length !== 2)) {
      // Remove invalid location field to prevent geo index error
      sitter.location = undefined;
    }

    let accountId = sitter.stripeConnectAccountId;
    let isNewAccount = false;

    // Create Stripe Connect account if it doesn't exist
    if (!accountId) {
      const country = resolveCountry({
        explicit: req.body?.country,
        sitterCountry: sitter.country,
        ibanCountry: ibanToCountry(sitter.ibanNumber),
        acceptLanguage: req.headers['accept-language'],
      });
      if (!country) {
        return res.status(400).json({
          error:
            'Unable to determine country for Stripe Connect account. Provide "country" (ISO-2) in body, set sitter.country, or save an IBAN first.',
        });
      }
      const account = await createConnectAccount({
        email: sitter.email,
        name: sitter.name,
        country,
      });

      // Save account ID to sitter
      // Use updateOne to avoid Mongoose applying invalid location defaults
      const updateOps = { 
        $set: { 
          stripeConnectAccountId: account.id,
          stripeConnectAccountStatus: 'pending'
        }
      };
      
      // Remove invalid location if needed
      if (sitter.location === undefined || 
          !sitter.location.coordinates || 
          !Array.isArray(sitter.location.coordinates) || 
          sitter.location.coordinates.length !== 2) {
        updateOps.$unset = { location: '' };
      }
      
      await Sitter.updateOne({ _id: sitterId }, updateOps);
      
      // Refresh sitter object
      sitter.stripeConnectAccountId = account.id;
      sitter.stripeConnectAccountStatus = 'pending';

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
      sitter: sanitizeUser(sitter, { includeEmail: true }),
    });
  } catch (error) {
    logger.error('Create Stripe Connect account error', error);
    if (error.message && error.message.includes('STRIPE_SECRET_KEY')) {
      return res.status(500).json({ error: 'Payment service is not configured.' });
    }
    if (error.type === 'StripeInvalidRequestError' && error.message && error.message.includes('Connect')) {
      return res.status(400).json({ 
        error: 'Stripe Connect is not enabled for your account. Please enable Stripe Connect in your Stripe Dashboard first.',
        details: 'Visit https://stripe.com/docs/connect to learn how to enable Connect.'
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
    const sitterId = req.user?.id;
    const userRole = req.user?.role;
    const { returnUrl, refreshUrl } = req.body || {};

    if (!sitterId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (userRole !== 'sitter') {
      return res.status(403).json({ error: 'Only sitters can create Stripe Connect account links.' });
    }

    const sitter = await Sitter.findById(sitterId);
    if (!sitter) {
      return res.status(404).json({ error: 'Sitter not found.' });
    }

    if (!sitter.stripeConnectAccountId) {
      return res.status(400).json({ 
        error: 'Stripe Connect account does not exist. Create an account first.' 
      });
    }

    // Default URLs if not provided
    const defaultReturnUrl = process.env.STRIPE_CONNECT_RETURN_URL || 'https://your-app.com/stripe-connect/return';
    const defaultRefreshUrl = process.env.STRIPE_CONNECT_REFRESH_URL || 'https://your-app.com/stripe-connect/refresh';

    const accountLink = await createAccountLink({
      accountId: sitter.stripeConnectAccountId,
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
    const sitterId = req.user?.id;
    const userRole = req.user?.role;

    if (!sitterId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (userRole !== 'sitter') {
      return res.status(403).json({ error: 'Only sitters can view Stripe Connect account status.' });
    }

    const sitter = await Sitter.findById(sitterId);
    if (!sitter) {
      return res.status(404).json({ error: 'Sitter not found.' });
    }

    if (!sitter.stripeConnectAccountId) {
      return res.json({
        connected: false,
        status: 'not_connected',
        message: 'Stripe Connect account not created yet.',
      });
    }

    // Get account status from Stripe
    const accountStatus = await getAccountStatus(sitter.stripeConnectAccountId);

    // Update sitter's account status
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
    if (!sitter.location || 
        !sitter.location.coordinates || 
        !Array.isArray(sitter.location.coordinates) || 
        sitter.location.coordinates.length !== 2) {
      updateOps.$unset = { location: '' };
    }
    
    await Sitter.updateOne({ _id: sitterId }, updateOps);
    
    // Refresh sitter object
    sitter.stripeConnectAccountStatus = status;

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
      accountId: sitter.stripeConnectAccountId,
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

    // If account ID is provided, we can update the sitter's account status
    if (account) {
      try {
        const sitter = await Sitter.findOne({ stripeConnectAccountId: account });
        if (sitter) {
          // Get updated account status from Stripe
          const accountStatus = await getAccountStatus(account);
          
          // Update sitter's account status
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
          if (!sitter.location || 
              !sitter.location.coordinates || 
              !Array.isArray(sitter.location.coordinates) || 
              sitter.location.coordinates.length !== 2) {
            updateOps.$unset = { location: '' };
          }
          
          await Sitter.updateOne({ _id: sitter._id }, updateOps);
          
          // Refresh sitter object
          sitter.stripeConnectAccountStatus = status;
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

