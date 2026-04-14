const express = require('express');
const multer = require('multer');

const {
  listSitters,
  getSitterProfile,
  findNearbySitters,
  updateSitterPricing,
  getSitterPricing,
  updateSitterProfile,
  updateSitterAvatar,
  updateSitterPaypalEmail,
  getSitterPaypalEmail,
  getMyAvailability,
  updateMyAvailability,
  getSitterAvailability,
  submitIdentityVerification,
  getMyIdentityVerification,
} = require('../controllers/sitterController');
const { requireAuth, requireRole } = require('../middleware/auth');

const router = express.Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB
  },
});

/**
 * @swagger
 * /sitters/me/pricing:
 *   get:
 *     summary: Get sitter pricing information (Sitter only)
 *     tags: [Sitters]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Pricing information retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 pricing:
 *                   type: object
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Only sitters can access this endpoint
 */
router.get('/me/pricing', requireAuth, requireRole('sitter'), getSitterPricing);
/**
 * @swagger
 * /sitters/me/rates:
 *   get:
 *     summary: Get sitter rate tiers (Sitter only)
 *     tags: [Sitters]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Rate tiers retrieved successfully
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Only sitters can access this endpoint
 */
router.get('/me/rates', requireAuth, requireRole('sitter'), getSitterPricing);

/**
 * @swagger
 * /sitters/me/pricing:
 *   put:
 *     summary: Update sitter pricing (Sitter only)
 *     tags: [Sitters]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               hourlyRate:
 *                 type: number
 *                 example: 25
 *               weeklyRate:
 *                 type: number
 *                 example: 700
 *               monthlyRate:
 *                 type: number
 *                 example: 2600
 *               servicePricing:
 *                 type: object
 *                 properties:
 *                   petSitting:
 *                     type: number
 *                   houseSitting:
 *                     type: number
 *                   dayCare:
 *                     type: number
 *                   dogWalking:
 *                     type: number
 *     responses:
 *       200:
 *         description: Pricing updated successfully
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Only sitters can access this endpoint
 */
router.put('/me/pricing', requireAuth, requireRole('sitter'), updateSitterPricing);
/**
 * @swagger
 * /sitters/me/rates:
 *   put:
 *     summary: Update sitter rate tiers (Sitter only)
 *     tags: [Sitters]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               hourlyRate:
 *                 type: number
 *                 example: 15
 *               weeklyRate:
 *                 type: number
 *                 example: 400
 *               monthlyRate:
 *                 type: number
 *                 example: 1500
 *     responses:
 *       200:
 *         description: Rate tiers updated successfully
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Only sitters can access this endpoint
 */
router.put('/me/rates', requireAuth, requireRole('sitter'), updateSitterPricing);

/**
 * @swagger
 * /sitters/paypal-email:
 *   put:
 *     summary: Update sitter PayPal payout email (Sitter only)
 *     tags: [Sitters]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - paypalEmail
 *             properties:
 *               paypalEmail:
 *                 type: string
 *                 format: email
 *                 example: sitter-payments@example.com
 *                 description: PayPal email address where sitter will receive payouts.
 *     responses:
 *       200:
 *         description: PayPal email updated successfully
 *       400:
 *         description: Invalid or missing PayPal email
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Only sitters can access this endpoint
 */
router.put('/paypal-email', requireAuth, requireRole('sitter'), updateSitterPaypalEmail);

/**
 * @swagger
 * /sitters/paypal-email:
 *   get:
 *     summary: Get sitter PayPal payout email (Sitter only)
 *     tags: [Sitters]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: PayPal email retrieved successfully (or not set)
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 hasPaypalEmail:
 *                   type: boolean
 *                   example: true
 *                 paypalEmail:
 *                   type: string
 *                   nullable: true
 *                   example: sitter-payments@example.com
 *                 message:
 *                   type: string
 *                   example: PayPal email is not set.
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Only sitters can access this endpoint
 */
router.get('/paypal-email', requireAuth, requireRole('sitter'), getSitterPaypalEmail);

// Sprint 5 step 6 — availability calendar
router.get('/me/availability', requireAuth, requireRole('sitter'), getMyAvailability);
router.put('/me/availability', requireAuth, requireRole('sitter'), updateMyAvailability);
router.get('/:id/availability', getSitterAvailability);

// Sprint 5 step 7 — identity verification (sitter-side)
router.post(
  '/identity-verification',
  requireAuth,
  requireRole('sitter'),
  upload.single('document'),
  submitIdentityVerification
);
router.get('/me/identity-verification', requireAuth, requireRole('sitter'), getMyIdentityVerification);

/**
 * @swagger
 * /sitters/me/profile:
 *   put:
 *     summary: Update sitter profile (Sitter only)
 *     tags: [Sitters]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *               email:
 *                 type: string
 *               mobile:
 *                 type: string
 *               countryCode:
 *                 type: string
 *                 description: International country calling code (E.164 format, e.g. +1, +44)
 *                 example: +44
 *               address:
 *                 type: string
 *               location:
 *                 type: string
 *               bio:
 *                 type: string
 *               skills:
 *                 type: string
 *               language:
 *                 type: string
 *               currency:
 *                 type: string
 *                 description: Preferred currency (EUR or USD)
 *                 enum: [EUR, USD]
 *                 example: EUR
 *     responses:
 *       200:
 *         description: Profile updated successfully
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Only sitters can access this endpoint
 */
router.put('/me/profile', requireAuth, requireRole('sitter'), updateSitterProfile);

/**
 * @swagger
 * /sitters/me/avatar:
 *   put:
 *     summary: Update sitter avatar/profile picture (Sitter only)
 *     tags: [Sitters]
 *     security:
 *       - bearerAuth: []
 *     consumes:
 *       - multipart/form-data
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             required:
 *               - avatar
 *             properties:
 *               avatar:
 *                 type: string
 *                 format: binary
 *                 description: Image file (JPEG, PNG, WebP)
 *     responses:
 *       200:
 *         description: Avatar updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                 sitter:
 *                   $ref: '#/components/schemas/Sitter'
 *                 avatar:
 *                   type: object
 *                   properties:
 *                     url:
 *                       type: string
 *                     publicId:
 *                       type: string
 *       400:
 *         description: Invalid file type or missing file
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Only sitters can access this endpoint
 */
router.put('/me/avatar', requireAuth, requireRole('sitter'), upload.single('avatar'), updateSitterAvatar);

/**
 * @swagger
 * /sitters/nearby:
 *   get:
 *     summary: Find nearby sitters based on owner's current location
 *     tags: [Sitters]
 *     description: |
 *       **Geospatial Search API for Finding Nearby Pet Sitters**
 *       
 *       This endpoint uses MongoDB's geospatial queries to find pet sitters based on the owner's current location.
 *       Results are sorted by distance (nearest first) and include calculated distance information.
 *       
 *       **Key Features:**
 *       - Returns all sitters with valid coordinates by default (no radius limit)
 *       - Optional radius filter to limit search area
 *       - Optional filters for service type and minimum rating
 *       - Calculates and returns distance for each sitter
 *       - Only returns verified sitters by default (can include unverified for testing)
 *       
 *       **Location Input Options:**
 *       - Provide `lat` and `lng` query parameters (recommended)
 *       - Or provide `coordinates` as JSON string array `"[lng, lat]"`
 *       
 *       **Use Cases:**
 *       - Display all sitters on a map with distance markers
 *       - Show nearby sitters sorted by proximity
 *       - Filter sitters by service type or rating
 *     parameters:
 *       - in: query
 *         name: lat
 *         required: true
 *         schema:
 *           type: number
 *           format: float
 *           minimum: -90
 *           maximum: 90
 *         description: Owner's current latitude (required if coordinates not provided)
 *         example: 52.5200
 *       - in: query
 *         name: lng
 *         required: true
 *         schema:
 *           type: number
 *           format: float
 *           minimum: -180
 *           maximum: 180
 *         description: Owner's current longitude (required if coordinates not provided)
 *         example: 13.4050
 *       - in: query
 *         name: coordinates
 *         required: false
 *         schema:
 *           type: string
 *         description: |
 *           Alternative to lat/lng. Coordinates array as JSON string in format `"[longitude, latitude]"`.
 *           Example: `"[13.4050, 52.5200]"` (note: longitude comes first in GeoJSON format)
 *         example: "[13.4050, 52.5200]"
 *       - in: query
 *         name: radius
 *         required: false
 *         schema:
 *           type: number
 *           format: float
 *           minimum: 1
 *           maximum: 10000
 *         description: |
 *           Optional search radius in kilometers. 
 *           - If not provided: Returns ALL sitters with valid coordinates, sorted by distance
 *           - If provided: Returns only sitters within the specified radius
 *         example: 50
 *       - in: query
 *         name: service
 *         required: false
 *         schema:
 *           type: string
 *         description: Filter results by service type (e.g., "Dog Walking", "Pet Sitting", "House Sitting")
 *         example: "Dog Walking"
 *       - in: query
 *         name: minRating
 *         required: false
 *         schema:
 *           type: number
 *           format: float
 *           minimum: 0
 *           maximum: 5
 *         description: Filter results by minimum rating (0-5 scale)
 *         example: 4.0
 *       - in: query
 *         name: includeUnverified
 *         required: false
 *         schema:
 *           type: boolean
 *           default: false
 *         description: |
 *           Include unverified sitters in results.
 *           - `false` (default): Only return verified sitters (recommended for production)
 *           - `true`: Include both verified and unverified sitters (useful for testing)
 *         example: false
 *     responses:
 *       200:
 *         description: |
 *           Successfully retrieved nearby sitters. Results are sorted by distance (nearest first).
 *           Each sitter object includes profile information and calculated distance from the search location.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               required:
 *                 - sitters
 *                 - count
 *                 - searchLocation
 *                 - hasRadiusLimit
 *               properties:
 *                 sitters:
 *                   type: array
 *                   description: Array of nearby sitters sorted by distance (nearest first)
 *                   items:
 *                     $ref: '#/components/schemas/NearbySitter'
 *                 count:
 *                   type: integer
 *                   description: Total number of sitters returned
 *                   example: 15
 *                 searchLocation:
 *                   type: object
 *                   description: The location used for the search
 *                   required:
 *                     - coordinates
 *                     - lat
 *                     - lng
 *                   properties:
 *                     coordinates:
 *                       type: array
 *                       description: GeoJSON coordinates array [longitude, latitude]
 *                       items:
 *                         type: number
 *                       example: [13.4050, 52.5200]
 *                     lat:
 *                       type: number
 *                       description: Latitude
 *                       example: 52.5200
 *                     lng:
 *                       type: number
 *                       description: Longitude
 *                       example: 13.4050
 *                 radius:
 *                   type: number
 *                   nullable: true
 *                   description: Search radius in kilometers (null if no radius limit was applied)
 *                   example: 50
 *                 radiusInMeters:
 *                   type: number
 *                   nullable: true
 *                   description: Search radius in meters (null if no radius limit was applied)
 *                   example: 50000
 *                 hasRadiusLimit:
 *                   type: boolean
 *                   description: Whether a radius limit was applied to the search
 *                   example: false
 *             examples:
 *               allSitters:
 *                 summary: Response with all sitters (no radius limit)
 *                 value:
 *                   sitters:
 *                     - id: "507f1f77bcf86cd799439011"
 *                       name: "Alex Petlover"
 *                       avatar:
 *                         url: "https://example.com/avatar.jpg"
 *                         publicId: "avatars/alex"
 *                       rating: 4.8
 *                       reviewsCount: 25
 *                       service: "Dog Walking"
 *                       skills: ["Dog training", "Cat care", "Pet first aid"]
 *                       hourlyRate: 25
 *                       bio: "Experienced pet sitter with 5 years of experience"
 *                       location:
 *                         coordinates: [13.4050, 52.5200]
 *                         city: "Berlin"
 *                       distance: "2.35"
 *                       distanceInMeters: 2350
 *                       verified: true
 *                   count: 1
 *                   searchLocation:
 *                     coordinates: [13.4050, 52.5200]
 *                     lat: 52.5200
 *                     lng: 13.4050
 *                   radius: null
 *                   radiusInMeters: null
 *                   hasRadiusLimit: false
 *               withRadius:
 *                 summary: Response with radius limit applied
 *                 value:
 *                   sitters:
 *                     - id: "507f1f77bcf86cd799439012"
 *                       name: "Sarah Johnson"
 *                       avatar:
 *                         url: "https://example.com/avatar2.jpg"
 *                         publicId: "avatars/sarah"
 *                       rating: 4.5
 *                       reviewsCount: 15
 *                       service: "Pet Sitting"
 *                       skills: ["Cat care", "Small animals"]
 *                       hourlyRate: 20
 *                       bio: "Passionate about pet care"
 *                       location:
 *                         coordinates: [13.4100, 52.5250]
 *                         city: "Berlin"
 *                       distance: "5.12"
 *                       distanceInMeters: 5120
 *                       verified: true
 *                   count: 1
 *                   searchLocation:
 *                     coordinates: [13.4050, 52.5200]
 *                     lat: 52.5200
 *                     lng: 13.4050
 *                   radius: 50
 *                   radiusInMeters: 50000
 *                   hasRadiusLimit: true
 *       400:
 *         description: |
 *           Bad request. Possible reasons:
 *           - Invalid or missing location parameters (lat/lng or coordinates)
 *           - Invalid radius value (must be between 1 and 10000 km)
 *           - Invalid coordinate values (out of valid ranges)
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *             examples:
 *               missingLocation:
 *                 summary: Missing location parameters
 *                 value:
 *                   error: "Valid location is required. Provide either coordinates array [lng, lat] or lat and lng query parameters."
 *               invalidRadius:
 *                 summary: Invalid radius value
 *                 value:
 *                   error: "Radius must be a positive number between 1 and 10000 kilometers."
 *               invalidCoordinates:
 *                 summary: Invalid coordinate values
 *                 value:
 *                   error: "Valid location is required. Provide either coordinates array [lng, lat] or lat and lng query parameters."
 *       500:
 *         description: |
 *           Internal server error. Possible reasons:
 *           - Geospatial index not found (run `npm run create:location-indexes`)
 *           - Database connection issues
 *           - Server error during geospatial query execution
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *             examples:
 *               indexError:
 *                 summary: Geospatial index missing
 *                 value:
 *                   error: "Geospatial index not found. Please ensure location index is created."
 *               serverError:
 *                 summary: General server error
 *                 value:
 *                   error: "Unable to find nearby sitters. Please try again later."
 */
router.get('/nearby', findNearbySitters);

/**
 * @swagger
 * /sitters:
 *   get:
 *     summary: List all sitters
 *     tags: [Sitters]
 *     parameters:
 *       - in: query
 *         name: location
 *         schema:
 *           type: string
 *         description: Filter by location
 *       - in: query
 *         name: service
 *         schema:
 *           type: string
 *         description: Filter by service type
 *       - in: query
 *         name: minRating
 *         schema:
 *           type: number
 *         description: Minimum rating
 *     responses:
 *       200:
 *         description: Sitters retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 sitters:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Sitter'
 *       500:
 *         description: Server error
 */
router.get('/', listSitters);

/**
 * @swagger
 * /sitters/{id}:
 *   get:
 *     summary: Get sitter profile by ID
 *     tags: [Sitters]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Sitter ID
 *     responses:
 *       200:
 *         description: Sitter profile retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Sitter'
 *       404:
 *         description: Sitter not found
 */
router.get('/:id', getSitterProfile);

// ─── IBAN PAYOUT (like Vinted) ────────────────────────────────────────────────
// requireAuth / requireRole are already imported at the top of this file.
const Sitter = require('../models/Sitter');

/**
 * PUT /sitters/me/iban
 * Sitter saves their IBAN bank details for payout
 */
router.put('/me/iban', requireAuth, requireRole('sitter'), async (req, res) => {
  try {
    const { ibanHolder, ibanNumber, ibanBic } = req.body;
    if (!ibanHolder || !ibanNumber || !ibanBic) {
      return res.status(400).json({ error: 'ibanHolder, ibanNumber and ibanBic are required.' });
    }
    // Basic IBAN format check (2 letters + digits, 15-34 chars)
    const ibanClean = ibanNumber.replace(/\s/g, '').toUpperCase();
    if (!/^[A-Z]{2}[0-9A-Z]{13,32}$/.test(ibanClean)) {
      return res.status(400).json({ error: 'Invalid IBAN format.' });
    }
    const sitter = await Sitter.findByIdAndUpdate(
      req.user.id,
      {
        ibanHolder: ibanHolder.trim(),
        ibanNumber: ibanClean,
        ibanBic: ibanBic.trim().toUpperCase(),
        ibanVerified: false, // Admin must re-verify on change
        payoutMethod: 'iban',
      },
      { new: true }
    ).select('ibanHolder ibanNumber ibanBic ibanVerified payoutMethod');
    if (!sitter) return res.status(404).json({ error: 'Sitter not found.' });
    // Return masked IBAN for security
    const masked = ibanClean.slice(0, 4) + '****' + ibanClean.slice(-4);
    res.json({ message: 'IBAN saved successfully.', ibanNumberMasked: masked, ibanVerified: false, payoutMethod: 'iban' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

/**
 * GET /sitters/me/iban
 * Sitter views their own IBAN (masked)
 */
router.get('/me/iban', requireAuth, requireRole('sitter'), async (req, res) => {
  try {
    const sitter = await Sitter.findById(req.user.id).select('ibanHolder ibanNumber ibanBic ibanVerified payoutMethod');
    if (!sitter) return res.status(404).json({ error: 'Sitter not found.' });
    const masked = sitter.ibanNumber
      ? sitter.ibanNumber.slice(0, 4) + '****' + sitter.ibanNumber.slice(-4)
      : '';
    res.json({
      ibanHolder: sitter.ibanHolder || '',
      ibanNumberMasked: masked,
      ibanBic: sitter.ibanBic || '',
      ibanVerified: sitter.ibanVerified || false,
      payoutMethod: sitter.payoutMethod || 'stripe',
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
