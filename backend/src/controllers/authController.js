const dayjs = require('dayjs');
const jwt = require('jsonwebtoken');

const Owner = require('../models/Owner');
const Admin = require('../models/Admin');
const Sitter = require('../models/Sitter');
const VerificationCode = require('../models/VerificationCode');
const { sendVerificationEmail, sendPasswordResetEmail } = require('../services/emailService');
const { generateVerificationCode } = require('../utils/code');
const { sanitizeUser } = require('../utils/sanitize');
const firebaseAdmin = require('../config/firebaseAdmin');
const { normalizeCurrency, DEFAULT_CURRENCY } = require('../utils/currency');

const OWNER_SERVICES = ['Pet Sitting', 'House Sitting', 'Day Care', 'Long Stay'];
const SITTER_SERVICES = [...OWNER_SERVICES, 'Dog Walking'];

const isValidEmail = (value) => {
  if (!value || typeof value !== 'string') return false;
  const trimmed = value.trim();
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmed);
};

const parseOptionalNonNegativeRate = (value, fieldName) => {
  if (value === undefined || value === null || value === '') return undefined;
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) {
    throw new Error(`${fieldName} must be a non-negative number.`);
  }
  return parsed;
};

const signAuthToken = (payload, options = {}) => {
  if (!process.env.JWT_SECRET) {
    throw new Error('JWT_SECRET environment variable is not configured.');
  }
  return jwt.sign(payload, process.env.JWT_SECRET, {
    expiresIn: '7d',
    ...options,
  });
};

const findAccountByEmail = async (email) => {
  const lower = email.toLowerCase();
  const owner = await Owner.findOne({ email: lower });
  if (owner) {
    return { role: 'owner', account: owner };
  }
  const sitter = await Sitter.findOne({ email: lower });
  if (sitter) {
    return { role: 'sitter', account: sitter };
  }
  return null;
};

const generateRandomPassword = () => {
  return `firebase_${Math.random().toString(36).slice(2)}_${Date.now().toString(36)}`;
};

/**
 * Processes location data from frontend. Optional: returns undefined when no valid coordinates.
 * Only returns a location object when valid [lng, lat] exist (safe for MongoDB 2dsphere index).
 *
 * @param {Object} locationData - Location data from request
 * @returns {Object|undefined} GeoJSON Point with coordinates, or undefined
 */
const processLocationData = (locationData) => {
  if (!locationData || typeof locationData !== 'object') return undefined;

  let latitude = null;
  let longitude = null;

  if (locationData.coordinates && Array.isArray(locationData.coordinates)) {
    [longitude, latitude] = locationData.coordinates;
  } else if (locationData.lat !== undefined && locationData.lng !== undefined) {
    latitude = typeof locationData.lat === 'number' ? locationData.lat : parseFloat(locationData.lat);
    longitude = typeof locationData.lng === 'number' ? locationData.lng : parseFloat(locationData.lng);
  } else if (locationData.latitude !== undefined && locationData.longitude !== undefined) {
    latitude = typeof locationData.latitude === 'number' ? locationData.latitude : parseFloat(locationData.latitude);
    longitude = typeof locationData.longitude === 'number' ? locationData.longitude : parseFloat(locationData.longitude);
  }

  const valid =
    latitude != null && longitude != null &&
    !isNaN(latitude) && !isNaN(longitude) &&
    longitude >= -180 && longitude <= 180 &&
    latitude >= -90 && latitude <= 90;

  if (!valid) return undefined;

  return {
    type: 'Point',
    coordinates: [longitude, latitude],
    city: (locationData.city || '').trim(),
  };
};

const signup = async (req, res) => {
  try {
    const { role, user } = req.body;

    if (!role || !['owner', 'sitter'].includes(role)) {
      return res.status(400).json({ error: 'Invalid role. Expected "owner" or "sitter".' });
    }

    if (!user?.email || !user?.password || !user?.name) {
      return res.status(400).json({ error: 'Missing required fields: name, email, password.' });
    }

    const email = user.email.toLowerCase();
    const mobile = (user.mobile || '').trim();
    const countryCode = (user.countryCode || '').toString().trim();
    const paypalEmailRaw = user.paypalEmail;
    const paypalEmail =
      paypalEmailRaw && typeof paypalEmailRaw === 'string' && paypalEmailRaw.trim()
        ? paypalEmailRaw.trim().toLowerCase()
        : '';
    const existingOwner = await Owner.findOne({ email });
    const existingSitter = await Sitter.findOne({ email });
    if (existingOwner || existingSitter) {
      return res.status(409).json({ error: 'User with this email already exists.' });
    }

    // Process location data (optional: only when valid coordinates provided)
    const location = processLocationData(user.location);

    // Determine and validate currency. If provided, it must be USD or EUR.
    // If omitted, default to DEFAULT_CURRENCY (backwards compatible).
    let ownerCurrency = DEFAULT_CURRENCY;
    let sitterCurrency = DEFAULT_CURRENCY;
    if (user && Object.prototype.hasOwnProperty.call(user, 'currency')) {
      // Validate explicit currency from client
      ownerCurrency = normalizeCurrency(user.currency, { required: true });
      sitterCurrency = ownerCurrency;
    }

    let weeklyRate;
    let monthlyRate;
    try {
      weeklyRate = parseOptionalNonNegativeRate(user.weeklyRate, 'weeklyRate');
      monthlyRate = parseOptionalNonNegativeRate(user.monthlyRate, 'monthlyRate');
    } catch (rateError) {
      return res.status(400).json({ error: rateError.message });
    }

    const ownerPayload = {
      name: user.name,
      email,
      mobile,
      countryCode,
      password: user.password,
      language: user.language || '',
      address: user.address || '',
      currency: ownerCurrency,
      acceptedTerms: !!user.acceptedTerms,
      service: Array.isArray(user.service) ? user.service : user.service ? [user.service] : [],
      verified: false,
    };
    if (location) ownerPayload.location = location;

    const sitterPayload = {
      name: user.name,
      email,
      mobile,
      countryCode,
      password: user.password,
      language: user.language || '',
      address: user.address || '',
      currency: sitterCurrency,
      rate: user.rate || '',
      skills: user.skills || '',
      bio: user.bio || '',
      hourlyRate: Number(user.hourlyRate) || Number(user.rate) || 0,
      dailyRate: Number(user.dailyRate) || 0,
      weeklyRate: weeklyRate ?? 0,
      monthlyRate: monthlyRate ?? 0,
      defaultRateType: ['hour', 'day', 'week', 'month'].includes(user.defaultRateType)
        ? user.defaultRateType
        : 'hour',
      acceptedTerms: !!user.acceptedTerms,
      service: Array.isArray(user.service) ? user.service : user.service ? [user.service] : [],
      verified: false,
      rating: Number(user.rating) || 0,
      reviewsCount: Number(user.reviewsCount) || 0,
      feedback: Array.isArray(user.feedback) ? user.feedback : [],
    };
    if (paypalEmail) {
      if (!isValidEmail(paypalEmail)) {
        return res.status(400).json({ error: 'paypalEmail must be a valid email address.' });
      }
      sitterPayload.paypalEmail = paypalEmail;
    }
    if (location) {
      sitterPayload.location = {
        ...location,
        locationType: user.location?.locationType || 'standard',
      };
    }

    let newUser;
    if (role === 'owner') {
      newUser = await Owner.create(ownerPayload);
    } else {
      newUser = await Sitter.create(sitterPayload);
    }

    const verificationCode = generateVerificationCode();
    await VerificationCode.findOneAndUpdate(
      { email, purpose: 'email_verification' },
      {
        email,
        code: verificationCode,
        expiresAt: dayjs().add(10, 'minute').toDate(),
        purpose: 'email_verification',
        verified: false,
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    try {
      await sendVerificationEmail(email, verificationCode);
    } catch (emailError) {
      console.error('Failed to send verification email', emailError);
    }

    res.status(201).json({
      role,
      user: sanitizeUser(newUser, { includeEmail: true }),
      verificationCode,
      message: 'Account created. Please verify your email.',
    });
  } catch (error) {
    console.error('Signup error', error);
    if (error.message && error.message.includes('currency must be either USD or EUR.')) {
      return res.status(400).json({ error: error.message });
    }
    res.status(500).json({ error: 'Unable to create account. Please try again later.' });
  }
};

const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required.' });
    }

    const result = await findAccountByEmail(email);

    if (!result) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }

    const passwordMatches = await result.account.comparePassword(password);
    if (!passwordMatches) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }

    if (!result.account.verified) {
      const userEmail = (result.account.email || email).toString().toLowerCase();
      const verificationCode = generateVerificationCode();
      await VerificationCode.findOneAndUpdate(
        { email: userEmail, purpose: 'email_verification' },
        {
          email: userEmail,
          code: verificationCode,
          expiresAt: dayjs().add(10, 'minute').toDate(),
          purpose: 'email_verification',
          verified: false,
        },
        { upsert: true, new: true, setDefaultsOnInsert: true }
      );
      try {
        await sendVerificationEmail(userEmail, verificationCode);
      } catch (emailError) {
        console.error('Failed to send verification email on login', emailError);
      }
      return res.status(403).json({
        error: 'Email not verified. Please verify your account.',
        message: 'A new verification code has been sent to your email.',
      });
    }

    const token = signAuthToken({ id: result.account._id.toString(), role: result.role });

    res.json({ role: result.role, token, user: sanitizeUser(result.account, { includeEmail: true }) });
  } catch (error) {
    console.error('Login error', error);
    if (error.message && error.message.includes('JWT_SECRET')) {
      return res.status(500).json({ error: 'Authentication service is not configured.' });
    }
    res.status(500).json({ error: 'Unable to login. Please try again later.' });
  }
};

/**
 * Google / Firebase authentication.
 * Frontend must authenticate with Firebase and send a Firebase ID token.
 *
 * Flow:
 * 1. Verify Firebase ID token
 * 2. Extract uid, email, name, picture, firebase.sign_in_provider
 * 3. If user with email exists (owner or sitter) -> link firebaseUid/authProvider if needed and login (return token)
 * 4. If not -> create new user (verified: false), send verification code, return signup-style response (no token)
 */
const googleAuth = async (req, res) => {
  try {
    const { idToken, role, user } = req.body || {};

    if (!idToken) {
      return res.status(400).json({ error: 'idToken is required.' });
    }

    let decoded;
    try {
      decoded = await firebaseAdmin.auth().verifyIdToken(idToken);
    } catch (verifyError) {
      console.error('Firebase ID token verification failed', verifyError);
      return res.status(401).json({ error: 'Invalid or expired Firebase ID token.' });
    }

    const {
      uid,
      email,
      name,
      picture,
      firebase: firebaseInfo,
    } = decoded;

    if (!email) {
      return res.status(400).json({ error: 'Firebase token does not contain a valid email.' });
    }

    const signInProvider = firebaseInfo?.sign_in_provider || 'firebase';

    // Always resolve user by email to avoid duplicate accounts and
    // ensure password + Google logins with same email map to same account.
    let result = await findAccountByEmail(email);

    // Existing user -> update firebase fields if needed and login.
    if (result) {
      const account = result.account;

      // Build updates without calling account.save() directly.
      // This avoids Mongoose re-applying default location values that break the geospatial index.
      const updates = {};
      let needsUpdate = false;

      if (!account.firebaseUid) {
        updates.firebaseUid = uid;
        needsUpdate = true;
      }
      if (account.authProvider !== 'google') {
        updates.authProvider = 'google';
        needsUpdate = true;
      }
      if (!account.verified) {
        updates.verified = true;
        needsUpdate = true;
      }
      if (picture && (!account.avatar || !account.avatar.url)) {
        const currentAvatar = account.avatar || {};
        updates.avatar = {
          ...currentAvatar,
          url: picture,
        };
        needsUpdate = true;
      }

      // Handle potentially invalid location for geo index
      const loc = account.location;
      const hasValidCoordinates =
        loc &&
        Array.isArray(loc.coordinates) &&
        loc.coordinates.length === 2 &&
        typeof loc.coordinates[0] === 'number' &&
        typeof loc.coordinates[1] === 'number';

      const updateOps = {};
      if (needsUpdate) {
        updateOps.$set = updates;
      }
      if (!hasValidCoordinates && loc !== undefined) {
        // Explicitly remove invalid location so MongoDB 2dsphere index won't choke
        updateOps.$unset = { location: '' };
      }

      if (Object.keys(updateOps).length > 0) {
        const Model = result.role === 'owner' ? Owner : Sitter;
        await Model.updateOne({ _id: account._id }, updateOps);

        // Reflect updates in memory for response
        if (updates.firebaseUid) {
          account.firebaseUid = updates.firebaseUid;
        }
        if (updates.authProvider) {
          account.authProvider = updates.authProvider;
        }
        if (updates.verified !== undefined) {
          account.verified = updates.verified;
        }
        if (updates.avatar) {
          account.avatar = updates.avatar;
        }
        if (!hasValidCoordinates && loc !== undefined) {
          account.location = undefined;
        }
      }

      const token = signAuthToken({ id: account._id.toString(), role: result.role });
      return res.json({
        existingUser: true,
        role: result.role,
        provider: signInProvider,
        token,
        user: sanitizeUser(account, { includeEmail: true }),
      });
    }

    // New user creation requires a role so we know which collection to use.
    if (!role || !['owner', 'sitter'].includes(role)) {
      return res.status(400).json({
        error: 'Role is required for new Google users and must be "owner" or "sitter".',
      });
    }

    const normalizedEmail = email.toLowerCase();
    const displayName = name || decoded.name || decoded.email || 'User';

    // Process location data if provided
    const location = processLocationData(user?.location);

    // Currency: validate when provided, otherwise default for backwards compatibility
    let baseCurrency = DEFAULT_CURRENCY;
    if (user && Object.prototype.hasOwnProperty.call(user, 'currency')) {
      baseCurrency = normalizeCurrency(user.currency, { required: true });
    }

    const baseFields = {
      name: displayName,
      email: normalizedEmail,
      mobile: '',
      countryCode: (user?.countryCode || '').toString().trim(),
      password: generateRandomPassword(),
      language: '',
      address: '',
      currency: baseCurrency,
      acceptedTerms: false,
      service: [],
      verified: true,
      firebaseUid: uid,
      authProvider: 'google',
      avatar: {
        url: picture || '',
        publicId: '',
      },
    };
    if (location) baseFields.location = location;

    let newUser;
    if (role === 'owner') {
      newUser = await Owner.create(baseFields);
    } else {
      const paypalEmailRaw = user?.paypalEmail;
      const paypalEmail =
        paypalEmailRaw && typeof paypalEmailRaw === 'string' && paypalEmailRaw.trim()
          ? paypalEmailRaw.trim().toLowerCase()
          : '';
      if (paypalEmail && !isValidEmail(paypalEmail)) {
        return res.status(400).json({ error: 'paypalEmail must be a valid email address.' });
      }
      let hourlyRateFromRequest;
      let weeklyRateFromRequest;
      let monthlyRateFromRequest;
      try {
        hourlyRateFromRequest = parseOptionalNonNegativeRate(user?.hourlyRate, 'hourlyRate');
        weeklyRateFromRequest = parseOptionalNonNegativeRate(user?.weeklyRate, 'weeklyRate');
        monthlyRateFromRequest = parseOptionalNonNegativeRate(user?.monthlyRate, 'monthlyRate');
      } catch (rateError) {
        return res.status(400).json({ error: rateError.message });
      }
      const sitterFields = {
        ...baseFields,
        rate: '',
        skills: '',
        bio: '',
        hourlyRate: hourlyRateFromRequest ?? 0,
        weeklyRate: weeklyRateFromRequest ?? 0,
        monthlyRate: monthlyRateFromRequest ?? 0,
        rating: 0,
        reviewsCount: 0,
        feedback: [],
        ...(paypalEmail ? { paypalEmail } : {}),
      };
      if (location) {
        sitterFields.location = {
          ...location,
          locationType: user?.location?.locationType || 'standard',
        };
      }
      newUser = await Sitter.create(sitterFields);
    }

    const token = signAuthToken({ id: newUser._id.toString(), role });

    return res.status(201).json({
      existingUser: false,
      role,
      provider: signInProvider,
      token,
      user: sanitizeUser(newUser, { includeEmail: true }),
    });
  } catch (error) {
    console.error('Google auth error', error);
    if (error.message && error.message.includes('currency must be either USD or EUR.')) {
      return res.status(400).json({ error: error.message });
    }
    if (error.message && error.message.includes('JWT_SECRET')) {
      return res.status(500).json({ error: 'Authentication service is not configured.' });
    }
    res.status(500).json({ error: 'Unable to authenticate with Google. Please try again later.' });
  }
};

/**
 * Apple Sign-In / Firebase authentication.
 * Frontend must authenticate with Firebase (Apple provider) and send a Firebase ID token.
 *
 * Flow:
 * 1. Verify Firebase ID token
 * 2. Extract uid, email, name, picture, firebase.sign_in_provider
 * 3. If user with email exists (owner or sitter) -> link firebaseUid/authProvider if needed and login (return token)
 * 4. If not -> create new user (verified: true), return signup-style response with token
 */
const appleAuth = async (req, res) => {
  try {
    const { idToken, role, user } = req.body || {};

    if (!idToken) {
      return res.status(400).json({ error: 'idToken is required.' });
    }

    let decoded;
    try {
      decoded = await firebaseAdmin.auth().verifyIdToken(idToken);
    } catch (verifyError) {
      console.error('Firebase ID token verification failed', verifyError);
      return res.status(401).json({ error: 'Invalid or expired Firebase ID token.' });
    }

    const {
      uid,
      email,
      name,
      picture,
      firebase: firebaseInfo,
    } = decoded;

    // Apple Sign-In may not always provide email (if user chose to hide it)
    // In that case, Firebase provides a private relay email
    if (!email) {
      return res.status(400).json({ error: 'Firebase token does not contain a valid email.' });
    }

    const signInProvider = firebaseInfo?.sign_in_provider || 'apple.com';

    // Always resolve user by email to avoid duplicate accounts and
    // ensure password + Google + Apple logins with same email map to same account.
    let result = await findAccountByEmail(email);

    // Existing user -> update firebase fields if needed and login.
    if (result) {
      const account = result.account;

      // Build updates without calling account.save() directly.
      // This avoids Mongoose re-applying default location values that break the geospatial index.
      const updates = {};
      let needsUpdate = false;

      if (!account.firebaseUid) {
        updates.firebaseUid = uid;
        needsUpdate = true;
      }
      if (account.authProvider !== 'apple') {
        updates.authProvider = 'apple';
        needsUpdate = true;
      }
      if (!account.verified) {
        updates.verified = true;
        needsUpdate = true;
      }
      if (picture && (!account.avatar || !account.avatar.url)) {
        const currentAvatar = account.avatar || {};
        updates.avatar = {
          ...currentAvatar,
          url: picture,
        };
        needsUpdate = true;
      }

      // Handle potentially invalid location for geo index
      const loc = account.location;
      const hasValidCoordinates =
        loc &&
        Array.isArray(loc.coordinates) &&
        loc.coordinates.length === 2 &&
        typeof loc.coordinates[0] === 'number' &&
        typeof loc.coordinates[1] === 'number';

      const updateOps = {};
      if (needsUpdate) {
        updateOps.$set = updates;
      }
      if (!hasValidCoordinates && loc !== undefined) {
        // Explicitly remove invalid location so MongoDB 2dsphere index won't choke
        updateOps.$unset = { location: '' };
      }

      if (Object.keys(updateOps).length > 0) {
        const Model = result.role === 'owner' ? Owner : Sitter;
        await Model.updateOne({ _id: account._id }, updateOps);

        // Reflect updates in memory for response
        if (updates.firebaseUid) {
          account.firebaseUid = updates.firebaseUid;
        }
        if (updates.authProvider) {
          account.authProvider = updates.authProvider;
        }
        if (updates.verified !== undefined) {
          account.verified = updates.verified;
        }
        if (updates.avatar) {
          account.avatar = updates.avatar;
        }
        if (!hasValidCoordinates && loc !== undefined) {
          account.location = undefined;
        }
      }

      const token = signAuthToken({ id: account._id.toString(), role: result.role });
      return res.json({
        existingUser: true,
        role: result.role,
        provider: signInProvider,
        token,
        user: sanitizeUser(account, { includeEmail: true }),
      });
    }

    // New user creation requires a role so we know which collection to use.
    if (!role || !['owner', 'sitter'].includes(role)) {
      return res.status(400).json({
        error: 'Role is required for new Apple users and must be "owner" or "sitter".',
      });
    }

    const normalizedEmail = email.toLowerCase();
    // Apple Sign-In may provide name in the first request, but subsequent logins may not
    // Use name from token, decoded name, or fallback to email/User
    const displayName = name || decoded.name || decoded.email?.split('@')[0] || 'User';

    // Process location data if provided
    const location = processLocationData(user?.location);

    // Currency: validate when provided, otherwise default for backwards compatibility
    let baseCurrency = DEFAULT_CURRENCY;
    if (user && Object.prototype.hasOwnProperty.call(user, 'currency')) {
      baseCurrency = normalizeCurrency(user.currency, { required: true });
    }

    const baseFields = {
      name: displayName,
      email: normalizedEmail,
      mobile: '',
      countryCode: (user?.countryCode || '').toString().trim(),
      password: generateRandomPassword(),
      language: '',
      address: '',
      currency: baseCurrency,
      acceptedTerms: false,
      service: [],
      verified: true,
      firebaseUid: uid,
      authProvider: 'apple',
      avatar: {
        url: picture || '',
        publicId: '',
      },
    };
    if (location) baseFields.location = location;

    let newUser;
    if (role === 'owner') {
      newUser = await Owner.create(baseFields);
    } else {
      const paypalEmailRaw = user?.paypalEmail;
      const paypalEmail =
        paypalEmailRaw && typeof paypalEmailRaw === 'string' && paypalEmailRaw.trim()
          ? paypalEmailRaw.trim().toLowerCase()
          : '';
      if (paypalEmail && !isValidEmail(paypalEmail)) {
        return res.status(400).json({ error: 'paypalEmail must be a valid email address.' });
      }
      let hourlyRateFromRequest;
      let weeklyRateFromRequest;
      let monthlyRateFromRequest;
      try {
        hourlyRateFromRequest = parseOptionalNonNegativeRate(user?.hourlyRate, 'hourlyRate');
        weeklyRateFromRequest = parseOptionalNonNegativeRate(user?.weeklyRate, 'weeklyRate');
        monthlyRateFromRequest = parseOptionalNonNegativeRate(user?.monthlyRate, 'monthlyRate');
      } catch (rateError) {
        return res.status(400).json({ error: rateError.message });
      }
      const sitterFields = {
        ...baseFields,
        rate: '',
        skills: '',
        bio: '',
        hourlyRate: hourlyRateFromRequest ?? 0,
        weeklyRate: weeklyRateFromRequest ?? 0,
        monthlyRate: monthlyRateFromRequest ?? 0,
        rating: 0,
        reviewsCount: 0,
        feedback: [],
        ...(paypalEmail ? { paypalEmail } : {}),
      };
      if (location) {
        sitterFields.location = {
          ...location,
          locationType: user?.location?.locationType || 'standard',
        };
      }
      newUser = await Sitter.create(sitterFields);
    }

    const token = signAuthToken({ id: newUser._id.toString(), role });

    return res.status(201).json({
      existingUser: false,
      role,
      provider: signInProvider,
      token,
      user: sanitizeUser(newUser, { includeEmail: true }),
    });
  } catch (error) {
    console.error('Apple auth error', error);
    if (error.message && error.message.includes('currency must be either USD or EUR.')) {
      return res.status(400).json({ error: error.message });
    }
    if (error.message && error.message.includes('JWT_SECRET')) {
      return res.status(500).json({ error: 'Authentication service is not configured.' });
    }
    res.status(500).json({ error: 'Unable to authenticate with Apple. Please try again later.' });
  }
};

const verifyEmail = async (req, res) => {
  try {
    const { code } = req.body;
    const { email } = req.query;

    if (!email) {
      return res.status(400).json({ error: 'Email is required in query parameters.' });
    }

    if (!code) {
      return res.status(400).json({ error: 'Code is required.' });
    }

    const result = await findAccountByEmail(email);
    if (!result) {
      return res.status(404).json({ error: 'User not found.' });
    }

    const record = await VerificationCode.findOne({ 
      email: email.toLowerCase(),
      purpose: 'email_verification'
    });
    if (!record) {
      return res.status(400).json({ error: 'No verification code found for this email.' });
    }

    if (dayjs(record.expiresAt).isBefore(dayjs())) {
      await VerificationCode.deleteOne({ email: email.toLowerCase() });
      return res.status(410).json({ error: 'Verification code expired. Please request a new code.' });
    }

    if (record.code !== code) {
      return res.status(400).json({ error: 'Invalid verification code.' });
    }

    result.account.verified = true;
    await result.account.save();
    await VerificationCode.deleteOne({ email: email.toLowerCase() });

    // Generate JWT token after successful verification
    const token = signAuthToken({ id: result.account._id.toString(), role: result.role });

    res.json({
      message: 'Email verified successfully.',
      role: result.role,
      token,
      user: sanitizeUser(result.account, { includeEmail: true }),
    });
  } catch (error) {
    console.error('Verification error', error);
    res.status(500).json({ error: 'Unable to verify email. Please try again later.' });
  }
};

const resendVerificationCode = async (req, res) => {
  try {
    const { email } = req.query;

    if (!email) {
      return res.status(400).json({ error: 'Email is required in query parameters.' });
    }

    const result = await findAccountByEmail(email);
    if (!result) {
      return res.status(404).json({ error: 'User not found.' });
    }

    const verificationCode = generateVerificationCode();
    await VerificationCode.findOneAndUpdate(
      { email: email.toLowerCase(), purpose: 'email_verification' },
      {
        email: email.toLowerCase(),
        code: verificationCode,
        expiresAt: dayjs().add(10, 'minute').toDate(),
        purpose: 'email_verification',
        verified: false,
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    try {
      await sendVerificationEmail(email.toLowerCase(), verificationCode);
    } catch (emailError) {
      console.error('Failed to resend verification email', emailError);
    }

    res.json({ message: 'Verification code resent.', verificationCode });
  } catch (error) {
    console.error('Resend code error', error);
    res.status(500).json({ error: 'Unable to resend verification code. Please try again later.' });
  }
};

const forgotPassword = async (req, res) => {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({ error: 'Email is required.' });
    }

    const result = await findAccountByEmail(email);
    if (!result) {
      return res.status(404).json({ error: 'User not found.' });
    }

    const resetCode = generateVerificationCode();
    await VerificationCode.findOneAndUpdate(
      { email: email.toLowerCase() },
      {
        email: email.toLowerCase(),
        code: resetCode,
        expiresAt: dayjs().add(10, 'minute').toDate(),
        purpose: 'password_reset',
        verified: false, // Reset verified status when new code is generated
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    try {
      await sendPasswordResetEmail(email.toLowerCase(), resetCode);
    } catch (emailError) {
      console.error('Failed to send password reset email', emailError);
    }

    res.json({ message: 'Password reset code sent to email.' });
  } catch (error) {
    console.error('Forgot password error', error);
    res.status(500).json({ error: 'Unable to process request. Please try again later.' });
  }
};

/**
 * Verify password reset OTP (Step 2)
 * POST /auth/verify-password-reset-otp
 */
const verifyPasswordResetOtp = async (req, res) => {
  try {
    const { email, code } = req.body;

    if (!email || !code) {
      return res.status(400).json({ error: 'Email and code are required.' });
    }

    const result = await findAccountByEmail(email);
    if (!result) {
      return res.status(404).json({ error: 'User not found.' });
    }

    const record = await VerificationCode.findOne({ 
      email: email.toLowerCase(),
      purpose: 'password_reset'
    });
    
    if (!record) {
      return res.status(400).json({ error: 'No password reset code found for this email. Please request a new code.' });
    }

    if (dayjs(record.expiresAt).isBefore(dayjs())) {
      await VerificationCode.deleteOne({ email: email.toLowerCase() });
      return res.status(410).json({ error: 'Reset code expired. Please request a new code.' });
    }

    if (record.code !== code) {
      return res.status(400).json({ error: 'Invalid reset code.' });
    }

    // Mark OTP as verified
    record.verified = true;
    await record.save();

    res.json({ 
      message: 'OTP verified successfully. You can now reset your password.',
      verified: true
    });
  } catch (error) {
    console.error('Verify password reset OTP error', error);
    res.status(500).json({ error: 'Unable to verify OTP. Please try again later.' });
  }
};

/**
 * Reset password (Step 3) - requires verified OTP
 * POST /auth/reset-password
 */
const resetPassword = async (req, res) => {
  try {
    const { email, newPassword } = req.body;

    if (!email || !newPassword) {
      return res.status(400).json({ error: 'Email and newPassword are required.' });
    }

    const result = await findAccountByEmail(email);
    if (!result) {
      return res.status(404).json({ error: 'User not found.' });
    }

    const record = await VerificationCode.findOne({ 
      email: email.toLowerCase(),
      purpose: 'password_reset'
    });
    
    if (!record) {
      return res.status(400).json({ error: 'No password reset code found for this email. Please request a new code.' });
    }

    // Check if OTP is verified
    if (!record.verified) {
      return res.status(400).json({ 
        error: 'OTP not verified. Please verify the OTP first using /auth/verify-password-reset-otp' 
      });
    }

    if (dayjs(record.expiresAt).isBefore(dayjs())) {
      await VerificationCode.deleteOne({ email: email.toLowerCase() });
      return res.status(410).json({ error: 'Reset code expired. Please request a new code.' });
    }

    // Reset password
    result.account.password = newPassword;
    await result.account.save();
    
    // Delete the verification code after successful password reset
    await VerificationCode.deleteOne({ email: email.toLowerCase() });

    res.json({ message: 'Password reset successful.' });
  } catch (error) {
    console.error('Reset password error', error);
    res.status(500).json({ error: 'Unable to reset password. Please try again later.' });
  }
};

const changePassword = async (req, res) => {
  try {
    const userId = req.user?.id;
    const role = req.user?.role;
    const { newPassword, confirmPassword } = req.body || {};

    if (!userId || !role) {
      return res.status(403).json({ error: 'Authentication context missing.' });
    }

    if (!newPassword || !confirmPassword) {
      return res.status(400).json({ error: 'newPassword and confirmPassword are required.' });
    }

    if (typeof newPassword !== 'string' || newPassword.length < 8) {
      return res.status(400).json({ error: 'New password must be at least 8 characters long.' });
    }

    if (newPassword !== confirmPassword) {
      return res.status(400).json({ error: 'Passwords do not match.' });
    }

    const Model = role === 'sitter' ? Sitter : Owner;
    const account = await Model.findById(userId);

    if (!account) {
      return res.status(404).json({ error: 'User not found.' });
    }

    account.password = newPassword;
    await account.save();

    res.json({ message: 'Password updated successfully.' });
  } catch (error) {
    console.error('Change password error', error);
    res.status(500).json({ error: 'Unable to change password. Please try again later.' });
  }
};

const chooseService = async (req, res) => {
  try {
    const { email } = req.query;
    const { service } = req.body || {};

    if (!email) {
      return res.status(400).json({ error: 'Email is required in query parameters.' });
    }

    const rawServices = Array.isArray(service) ? service : service != null ? [service] : [];
    const normalizedServices = rawServices
      .map((s) => (typeof s === 'string' ? s.trim() : typeof s === 'number' ? String(s).trim() : ''))
      .filter(Boolean);

    if (normalizedServices.length === 0) {
      return res.status(400).json({ error: 'Service is required (array of service names).' });
    }

    const result = await findAccountByEmail(email);
    if (!result) {
      return res.status(404).json({ error: 'User not found.' });
    }

    const allowedServices = result.role === 'sitter' ? SITTER_SERVICES : OWNER_SERVICES;
    const invalid = normalizedServices.filter((s) => !allowedServices.includes(s));
    if (invalid.length > 0) {
      return res.status(400).json({
        error: `Invalid service(s): ${invalid.join(', ')}. Allowed: ${allowedServices.join(', ')}.`,
      });
    }

    result.account.service = normalizedServices;
    await result.account.save();

    res.json({
      message: 'Service updated successfully.',
      role: result.role,
      user: sanitizeUser(result.account, { includeEmail: true }),
    });
  } catch (error) {
    console.error('Choose service error', error);
    res.status(500).json({ error: 'Unable to update service. Please try again later.' });
  }
};

const adminLogin = async (req, res) => {
  try {
    const { email, password } = req.body || {};
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required.' });
    }
    const admin = await Admin.findOne({ email: String(email).toLowerCase().trim() });
    if (!admin) return res.status(401).json({ error: 'Invalid admin credentials.' });
    const ok = await admin.verifyPassword(password);
    if (!ok) return res.status(401).json({ error: 'Invalid admin credentials.' });
    const token = signAuthToken({ id: admin._id.toString(), role: 'admin' });
    return res.json({
      role: 'admin',
      token,
      admin: { id: admin._id, email: admin.email, name: admin.name },
    });
  } catch (error) {
    console.error('adminLogin error', error);
    return res.status(500).json({ error: 'Admin login failed.' });
  }
};

module.exports = {
  signup,
  login,
  verifyEmail,
  resendVerificationCode,
  forgotPassword,
  verifyPasswordResetOtp,
  resetPassword,
  changePassword,
  chooseService,
  googleAuth,
  appleAuth,
  adminLogin,
  signAuthToken,
};

