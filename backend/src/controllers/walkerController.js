const Walker = require('../models/Walker');
const { sanitizeUser } = require('../utils/sanitize');
const { uploadMedia } = require('../services/cloudinary');
const { encrypt, decrypt } = require('../utils/encryption');
const logger = require('../utils/logger');

const bufferToDataUri = (file) => `data:${file.mimetype};base64,${file.buffer.toString('base64')}`;

/**
 * Walker controller — minimal Phase-1 endpoints so the frontend can wire up
 * the walker role. Deeper features (pricing, identity verification, avatar
 * upload, availability calendar) will be added in later sessions mirroring
 * the sitter controller structure.
 */

/**
 * GET /walkers
 * Paginated public list of active walkers, optionally filtered by city.
 */
const listWalkers = async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit, 10) || 20));
    const skip = (page - 1) * limit;

    // Session v15-6 — old walkers created before the `status` field was
    // introduced have the field missing entirely; without this we'd hide
    // them from every owner feed. Treat "missing or active" as active so
    // legacy accounts stay visible until they get their first admin action.
    const filter = {
      $or: [
        { status: 'active' },
        { status: { $exists: false } },
        { status: null },
      ],
    };
    if (req.query.city) {
      filter['location.city'] = new RegExp(`^${req.query.city}$`, 'i');
    }

    const [walkers, total] = await Promise.all([
      Walker.find(filter)
        .select('-password -ibanNumber -insuranceCertUrl -paypalEmail')
        .sort({ averageRating: -1, createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      Walker.countDocuments(filter),
    ]);

    res.json({
      walkers: walkers.map((w) => sanitizeUser(w)),
      pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
    });
  } catch (error) {
    logger.error('listWalkers error', error);
    res.status(500).json({ error: 'Unable to list walkers.' });
  }
};

/**
 * GET /walkers/:id
 * Public profile of a single walker by id.
 */
const getWalkerProfile = async (req, res) => {
  try {
    const walker = await Walker.findById(req.params.id)
      .select('-password -ibanNumber -insuranceCertUrl -paypalEmail')
      .lean();
    if (!walker) {
      return res.status(404).json({ error: 'Walker not found.' });
    }
    res.json({ walker: sanitizeUser(walker) });
  } catch (error) {
    logger.error('getWalkerProfile error', error);
    res.status(500).json({ error: 'Unable to fetch walker profile.' });
  }
};

/**
 * GET /walkers/nearby?lat=&lng=&radiusInMeters=
 * Geospatial lookup of active walkers within a radius. Results sorted by distance.
 */
const findNearbyWalkers = async (req, res) => {
  try {
    const lat = parseFloat(req.query.lat);
    const lng = parseFloat(req.query.lng);
    const radiusInMeters = Math.min(
      200000,
      Math.max(100, parseInt(req.query.radiusInMeters, 10) || 10000)
    );
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      return res.status(400).json({ error: 'Query params `lat` and `lng` are required.' });
    }

    const walkers = await Walker.aggregate([
      {
        $geoNear: {
          near: { type: 'Point', coordinates: [lng, lat] },
          distanceField: 'distanceInMeters',
          maxDistance: radiusInMeters,
          spherical: true,
          // Session v15-6 — include legacy walkers without status field.
          query: {
            $or: [
              { status: 'active' },
              { status: { $exists: false } },
              { status: null },
            ],
          },
        },
      },
      { $limit: 50 },
      {
        $project: {
          password: 0,
          ibanNumber: 0,
          insuranceCertUrl: 0,
          paypalEmail: 0,
        },
      },
    ]);

    res.json({ walkers: walkers.map((w) => sanitizeUser(w)) });
  } catch (error) {
    logger.error('findNearbyWalkers error', error);
    res.status(500).json({ error: 'Unable to fetch nearby walkers.' });
  }
};

/**
 * GET /walkers/me
 * Authenticated walker fetches their own full profile.
 */
const getMyWalkerProfile = async (req, res) => {
  try {
    if (req.user?.role !== 'walker') {
      return res.status(403).json({ error: 'Walker role required.' });
    }
    const walker = await Walker.findById(req.user.id).select('-password').lean();
    if (!walker) {
      return res.status(404).json({ error: 'Walker profile not found.' });
    }
    res.json({ walker: sanitizeUser(walker, { includeEmail: true }) });
  } catch (error) {
    logger.error('getMyWalkerProfile error', error);
    res.status(500).json({ error: 'Unable to fetch walker profile.' });
  }
};

/**
 * PATCH /walkers/me
 * Authenticated walker updates their own editable profile fields.
 */
const updateMyWalkerProfile = async (req, res) => {
  try {
    if (req.user?.role !== 'walker') {
      return res.status(403).json({ error: 'Walker role required.' });
    }

    // Whitelist editable fields to avoid mass-assignment vulnerabilities.
    const allowed = [
      'name',
      'mobile',
      'countryCode',
      'language',
      'address',
      'bio',
      'skills',
      'acceptedPetTypes',
      'maxPetsPerWalk',
      'hasInsurance',
      'insuranceExpiresAt',
      'coverageCity',
      'coverageRadiusKm',
      'defaultWalkDurationMinutes',
      'availableTimeSlots',
      'service',
    ];
    const update = {};
    for (const key of allowed) {
      if (Object.prototype.hasOwnProperty.call(req.body, key)) {
        update[key] = req.body[key];
      }
    }

    const walker = await Walker.findByIdAndUpdate(req.user.id, update, {
      new: true,
      runValidators: true,
    })
      .select('-password')
      .lean();

    if (!walker) {
      return res.status(404).json({ error: 'Walker profile not found.' });
    }
    res.json({ walker: sanitizeUser(walker, { includeEmail: true }) });
  } catch (error) {
    logger.error('updateMyWalkerProfile error', error);
    if (error.name === 'ValidationError') {
      return res.status(400).json({ error: error.message });
    }
    res.status(500).json({ error: 'Unable to update walker profile.' });
  }
};

/**
 * GET /walkers/me/rates
 * Authenticated walker fetches their walkRates array.
 */
const getMyWalkerRates = async (req, res) => {
  try {
    if (req.user?.role !== 'walker') {
      return res.status(403).json({ error: 'Walker role required.' });
    }
    const walker = await Walker.findById(req.user.id).select('walkRates currency').lean();
    if (!walker) {
      return res.status(404).json({ error: 'Walker profile not found.' });
    }
    res.json({
      walkRates: walker.walkRates || [],
      currency: walker.currency || 'EUR',
    });
  } catch (error) {
    logger.error('getMyWalkerRates error', error);
    res.status(500).json({ error: 'Unable to fetch walker rates.' });
  }
};

/**
 * PUT /walkers/me/rates
 * Replace the walker's walkRates array. Each entry must be a valid rate object.
 */
const updateMyWalkerRates = async (req, res) => {
  try {
    if (req.user?.role !== 'walker') {
      return res.status(403).json({ error: 'Walker role required.' });
    }
    const { walkRates } = req.body;
    if (!Array.isArray(walkRates)) {
      return res.status(400).json({ error: '`walkRates` must be an array.' });
    }

    // Validate each entry: durationMinutes multiple of 15 between 15 and 300, basePrice >= 0.
    for (const entry of walkRates) {
      if (!entry || typeof entry !== 'object') {
        return res.status(400).json({ error: 'Each walkRate entry must be an object.' });
      }
      const d = Number(entry.durationMinutes);
      if (!Number.isInteger(d) || d < 15 || d > 300 || d % 15 !== 0) {
        return res.status(400).json({
          error: 'durationMinutes must be an integer multiple of 15 between 15 and 300.',
        });
      }
      const p = Number(entry.basePrice);
      if (!Number.isFinite(p) || p < 0) {
        return res.status(400).json({ error: 'basePrice must be a non-negative number.' });
      }
    }

    // De-duplicate by durationMinutes (keep the last occurrence).
    const byDuration = new Map();
    for (const entry of walkRates) {
      byDuration.set(Number(entry.durationMinutes), {
        durationMinutes: Number(entry.durationMinutes),
        basePrice: Number(entry.basePrice),
        currency: entry.currency || 'EUR',
        enabled: entry.enabled !== false,
      });
    }
    const normalized = Array.from(byDuration.values()).sort(
      (a, b) => a.durationMinutes - b.durationMinutes
    );

    const walker = await Walker.findByIdAndUpdate(
      req.user.id,
      { walkRates: normalized },
      { new: true, runValidators: true }
    )
      .select('walkRates currency')
      .lean();

    res.json({ walkRates: walker.walkRates, currency: walker.currency });
  } catch (error) {
    logger.error('updateMyWalkerRates error', error);
    if (error.name === 'ValidationError') {
      return res.status(400).json({ error: error.message });
    }
    res.status(500).json({ error: 'Unable to update walker rates.' });
  }
};

// ── Identity verification (session v3.2) ─────────────────────────────────────
// Mirror of sitterController.submitIdentityVerification so walkers can also
// upload an ID document that the admin dashboard then reviews via the same
// /admin/identity-verifications endpoint (now multi-role aware).

const submitIdentityVerification = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'Identity document file is required.' });
    }
    const dataUri = bufferToDataUri(req.file);
    const upload = await uploadMedia({ file: dataUri, folder: 'identity_verification' });
    const walker = await Walker.findByIdAndUpdate(
      req.user.id,
      {
        identityVerification: {
          status: 'pending',
          documentUrl: encrypt(upload.url),
          submittedAt: new Date(),
          reviewedAt: null,
          rejectionReason: '',
        },
      },
      { new: true },
    ).select('identityVerification');
    if (!walker) return res.status(404).json({ error: 'Walker not found.' });
    res.json({
      identityVerification: {
        status: walker.identityVerification.status,
        submittedAt: walker.identityVerification.submittedAt,
      },
    });
  } catch (e) {
    logger.error('walker submitIdentityVerification error', e);
    res.status(500).json({ error: 'Unable to submit identity document.' });
  }
};

const getMyIdentityVerification = async (req, res) => {
  try {
    const walker = await Walker.findById(req.user.id).select('identityVerification');
    if (!walker) return res.status(404).json({ error: 'Walker not found.' });
    const iv = walker.identityVerification || {};
    res.json({
      status: iv.status || 'none',
      submittedAt: iv.submittedAt || null,
      reviewedAt: iv.reviewedAt || null,
      rejectionReason: iv.rejectionReason || '',
      documentUrl: iv.documentUrl ? decrypt(iv.documentUrl) : '',
    });
  } catch (e) {
    logger.error('walker getMyIdentityVerification error', e);
    res.status(500).json({ error: 'Unable to fetch identity verification.' });
  }
};

module.exports = {
  listWalkers,
  getWalkerProfile,
  findNearbyWalkers,
  getMyWalkerProfile,
  updateMyWalkerProfile,
  getMyWalkerRates,
  updateMyWalkerRates,
  submitIdentityVerification,
  getMyIdentityVerification,
};
