const express = require('express');

const {
  signup,
  login,
  googleAuth,
  appleAuth,
  verifyEmail,
  resendVerificationCode,
  forgotPassword,
  verifyPasswordResetOtp,
  resetPassword,
  changePassword,
  chooseService,
  adminLogin,
} = require('../controllers/authController');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

/**
 * @swagger
 * /auth/signup:
 *   post:
 *     summary: Register a new user (Owner or Sitter)
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - role
 *               - user
 *             properties:
 *               role:
 *                 type: string
 *                 enum: [owner, sitter]
 *                 description: User role
 *               user:
 *                 type: object
 *                 required:
 *                   - name
 *                   - email
 *                   - password
 *                 properties:
 *                   name:
 *                     type: string
 *                     example: John Doe
 *                   email:
 *                     type: string
 *                     format: email
 *                     example: john@example.com
 *                   paypalEmail:
 *                     type: string
 *                     format: email
 *                     description: Optional PayPal email for sitter payouts (sitter only)
 *                     example: sitter-payments@example.com
 *                   password:
 *                     type: string
 *                     format: password
 *                     minLength: 6
 *                     example: password123
 *                   mobile:
 *                     type: string
 *                     example: 5551234567
 *                   countryCode:
 *                     type: string
 *                     description: International country calling code (E.164 format, e.g. +1, +44)
 *                     example: +1
 *                   address:
 *                     type: string
 *                     example: 123 Main St
 *                   language:
 *                     type: string
 *                     example: English
 *                   currency:
 *                     type: string
 *                     description: Preferred currency (EUR or USD)
 *                     enum: [EUR, USD]
 *                     example: EUR
 *                   acceptedTerms:
 *                     type: boolean
 *                     example: true
 *                   service:
 *                     type: string
 *                     example: Pet Sitting
 *                   rate:
 *                     type: string
 *                     example: $20/hour
 *                   skills:
 *                     type: string
 *                     example: Dog training, Cat care
 *                   bio:
 *                     type: string
 *                     example: Experienced pet sitter
 *                   hourlyRate:
 *                     type: number
 *                     example: 25
 *                   weeklyRate:
 *                     type: number
 *                     description: Optional weekly tier rate for sitter
 *                     example: 400
 *                   monthlyRate:
 *                     type: number
 *                     description: Optional monthly tier rate for sitter
 *                     example: 1500
 *                   location:
 *                     type: object
 *                     description: Location data - either coordinates from geolocation API or city name
 *                     properties:
 *                       coordinates:
 *                         type: array
 *                         items:
 *                           type: number
 *                         minItems: 2
 *                         maxItems: 2
 *                         description: "[longitude, latitude] from browser geolocation API"
 *                         example: [13.4050, 52.5200]
 *                       lat:
 *                         type: number
 *                         format: float
 *                         description: Latitude (alternative to coordinates array)
 *                         example: 33.6844
 *                       lng:
 *                         type: number
 *                         format: float
 *                         description: Longitude (alternative to coordinates array)
 *                         example: 73.0479
 *                       latitude:
 *                         type: number
 *                         format: float
 *                         description: Latitude (alternative format)
 *                         example: 33.6844
 *                       longitude:
 *                         type: number
 *                         format: float
 *                         description: Longitude (alternative format)
 *                         example: 73.0479
 *                       city:
 *                         type: string
 *                         description: City name if coordinates are not available
 *                         example: Berlin
 *                       address:
 *                         type: string
 *                         description: Optional address string
 *                         example: "123 Main Street, Berlin"
 *                     example:
 *                       lat: 33.6844
 *                       lng: 73.0479
 *                       city: "New York"
 *           examples:
 *             sitterWithLocation:
 *               summary: Sitter signup with location (lat/lng)
 *               description: Example of sitter registration with location using lat/lng format
 *               value:
 *                 role: sitter
 *                 user:
 *                   name: "Jane Smith"
 *                   email: "sitterl1@gmail.com"
 *                   password: "Abcd@123"
 *                   paypalEmail: "jane.sitter.paypal@example.com"
 *                   mobile: "5559876543"
 *                   countryCode: "+1"
 *                   language: "English"
 *                   address: "456 Oak Avenue, New York"
 *                   acceptedTerms: true
 *                   service: "House Sitting"
 *                   hourlyRate: 15
 *                   weeklyRate: 400
 *                   monthlyRate: 1500
 *                   location:
 *                     lat: 33.6844
 *                     lng: 73.0479
 *             ownerWithCoordinates:
 *               summary: Owner signup with coordinates array
 *               description: Example of owner registration with location using coordinates array format
 *               value:
 *                 role: owner
 *                 user:
 *                   name: "John Doe"
 *                   email: "john.owner@example.com"
 *                   password: "Password123!"
 *                   mobile: "5551234567"
 *                   countryCode: "+1"
 *                   language: "English"
 *                   address: "123 Main Street, Berlin"
 *                   acceptedTerms: true
 *                   service: "Pet Sitting"
 *                   location:
 *                     coordinates: [13.4050, 52.5200]
 *                     city: "Berlin"
 *             sitterWithCityOnly:
 *               summary: Sitter signup with city only (no coordinates)
 *               description: Example of sitter registration with only city name (coordinates can be added later)
 *               value:
 *                 role: sitter
 *                 user:
 *                   name: "Sarah Johnson"
 *                   email: "sarah.sitter@example.com"
 *                   password: "Password123!"
 *                   mobile: "5554445566"
 *                   countryCode: "+44"
 *                   language: "English"
 *                   address: "321 Elm Street, London"
 *                   acceptedTerms: true
 *                   service: "Pet Sitting"
 *                   location:
 *                     city: "London"
 *     responses:
 *       201:
 *         description: User registered successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: User registered successfully. Verification code sent to email.
 *                 user:
 *                   $ref: '#/components/schemas/Owner'
 *       400:
 *         description: Invalid input or missing required fields
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       409:
 *         description: User already exists
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.post('/signup', signup);

/**
 * @swagger
 * /auth/login:
 *   post:
 *     summary: Login user and get JWT token
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 example: john@example.com
 *               password:
 *                 type: string
 *                 format: password
 *                 example: password123
 *     responses:
 *       200:
 *         description: Login successful
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 token:
 *                   type: string
 *                   example: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
 *                 user:
 *                   oneOf:
 *                     - $ref: '#/components/schemas/Owner'
 *                     - $ref: '#/components/schemas/Sitter'
 *       401:
 *         description: Invalid credentials
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.post('/login', login);
router.post('/admin/login', adminLogin);

/**
 * @swagger
 * /auth/google:
 *   post:
 *     summary: Authenticate with Google via Firebase ID token (Web & Mobile)
 *     tags: [Authentication]
 *     description: >
 *       Frontend must first authenticate the user with Firebase (Google or email/password)
 *       and then send the resulting Firebase ID token to this endpoint. The backend verifies
 *       the token using Firebase Admin SDK, resolves or creates a user by email, and issues
 *       an application JWT.
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - idToken
 *             properties:
 *               idToken:
 *                 type: string
 *                 description: Firebase ID token obtained from client-side Firebase Authentication.
 *                 example: eyJhbGciOiJSUzI1NiIsImtpZCI6IjE2MjM0NTY3OCIsInR5cCI6IkpXVCJ9...
 *               role:
 *                 type: string
 *                 enum: [owner, sitter]
 *                 description: >
 *                   Required when signing up a new user (when no existing user with the email exists).
 *                   Ignored if a user with the given email is already present.
 *                 example: owner
 *               user:
 *                 type: object
 *                 description: Optional user data for new account creation
 *                 properties:
 *                   countryCode:
 *                     type: string
 *                     example: "+1"
 *                   currency:
 *                     type: string
 *                     enum: [EUR, USD]
 *                     example: EUR
 *                   paypalEmail:
 *                     type: string
 *                     format: email
 *                     description: Optional PayPal email for sitter payouts (sitter only)
 *                     example: sitter-payments@example.com
 *                   location:
 *                     type: object
 *                     properties:
 *                       coordinates:
 *                         type: array
 *                         items:
 *                           type: number
 *                         description: "[longitude, latitude]"
 *                         example: [-122.4194, 37.7749]
 *                       city:
 *                         type: string
 *                         example: "San Francisco"
 *                       locationType:
 *                         type: string
 *                         enum: [standard, large_city]
 *                         example: standard
 *           examples:
 *             existingUser:
 *               summary: Existing user logging in with Google
 *               value:
 *                 idToken: eyJhbGciOiJSUzI1NiIsImtpZCI6IjE2MjM0NTY3OCIsInR5cCI6IkpXVCJ9...
 *             newOwnerUser:
 *               summary: New Owner signing up with Google
 *               value:
 *                 idToken: eyJhbGciOiJSUzI1NiIsImtpZCI6IjE2MjM0NTY3OCIsInR5cCI6IkpXVCJ9...
 *                 role: owner
 *             newSitterUser:
 *               summary: New Sitter signing up with Google
 *               value:
 *                 idToken: eyJhbGciOiJSUzI1NiIsImtpZCI6IjE2MjM0NTY3OCIsInR5cCI6IkpXVCJ9...
 *                 role: sitter
 *                 user:
 *                   paypalEmail: "alex.sitter.paypal@example.com"
 *     responses:
 *       200:
 *         description: Existing user logged in successfully with Google account
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 role:
 *                   type: string
 *                   enum: [owner, sitter]
 *                   description: Role of the authenticated user.
 *                   example: owner
 *                 provider:
 *                   type: string
 *                   description: Firebase sign-in provider identifier.
 *                   example: google.com
 *                 token:
 *                   type: string
 *                   description: Application JWT issued by the backend (use in Authorization header as `Bearer <token>`).
 *                   example: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.app-payload.signature
 *                 user:
 *                   description: Sanitized user profile of the authenticated account.
 *                   oneOf:
 *                     - $ref: '#/components/schemas/Owner'
 *                     - $ref: '#/components/schemas/Sitter'
 *             examples:
 *               existingOwner:
 *                 summary: Existing Owner logging in with Google
 *                 value:
 *                   role: owner
 *                   provider: google.com
 *                   token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.app-payload.signature
 *                   user:
 *                     id: 661234abcd1234abcd1234ef
 *                     name: Jane Doe
 *                     email: jane.owner@example.com
 *                     mobile: "491234567890"
 *                     countryCode: "+49"
 *                     address: "Main Street 1, Berlin"
 *                     language: "English"
 *                     service: "Pet Sitting"
 *                     avatar:
 *                       url: "https://example.com/avatar.jpg"
 *                       publicId: "avatars/jane-owner"
 *                     verified: true
 *                     createdAt: "2024-11-01T12:00:00.000Z"
 *                     updatedAt: "2024-11-10T09:30:00.000Z"
 *       201:
 *         description: New user created from Google account and logged in successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 role:
 *                   type: string
 *                   enum: [owner, sitter]
 *                   description: Role of the newly created user.
 *                   example: sitter
 *                 provider:
 *                   type: string
 *                   description: Firebase sign-in provider identifier.
 *                   example: google.com
 *                 token:
 *                   type: string
 *                   description: Application JWT issued by the backend.
 *                   example: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.app-payload.signature
 *                 user:
 *                   description: Sanitized profile of the newly created account.
 *                   oneOf:
 *                     - $ref: '#/components/schemas/Owner'
 *                     - $ref: '#/components/schemas/Sitter'
 *             examples:
 *               newSitter:
 *                 summary: New Sitter created from Google login
 *                 value:
 *                   role: sitter
 *                   provider: google.com
 *                   token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.app-payload.signature
 *                   user:
 *                     id: 661234abcd1234abcd1234ff
 *                     name: "Alex Petlover"
 *                     email: alex.sitter@example.com
 *                     mobile: ""
 *                     countryCode: ""
 *                     address: ""
 *                     location: "Berlin"
 *                     language: "German"
 *                     service: "Dog Walking"
 *                     bio: ""
 *                     skills: ""
 *                     hourlyRate: 0
 *                     rating: 0
 *                     reviewsCount: 0
 *                     avatar:
 *                       url: "https://example.com/avatar-alex.jpg"
 *                       publicId: "avatars/alex-sitter"
 *                     verified: true
 *                     createdAt: "2024-11-10T09:45:00.000Z"
 *                     updatedAt: "2024-11-10T09:45:00.000Z"
 *       400:
 *         description: Bad request (missing token, missing role for new user, or invalid token data)
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *             examples:
 *               missingToken:
 *                 summary: idToken not provided
 *                 value:
 *                   error: "idToken is required."
 *               missingRole:
 *                 summary: Role missing for new user
 *                 value:
 *                   error: "Role is required for new Google users and must be \"owner\" or \"sitter\"."
 *       401:
 *         description: Invalid or expired Firebase ID token
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *             example:
 *               error: "Invalid or expired Firebase ID token."
 *       500:
 *         description: Server error during authentication
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *             example:
 *               error: "Unable to authenticate with Google. Please try again later."
 */
router.post('/google', googleAuth);

/**
 * @swagger
 * /auth/apple:
 *   post:
 *     summary: Authenticate with Apple Sign-In via Firebase ID token (Web & Mobile)
 *     tags: [Authentication]
 *     description: >
 *       Frontend must first authenticate the user with Firebase (Apple provider)
 *       and then send the resulting Firebase ID token to this endpoint. The backend verifies
 *       the token using Firebase Admin SDK, resolves or creates a user by email, and issues
 *       an application JWT.
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - idToken
 *             properties:
 *               idToken:
 *                 type: string
 *                 description: Firebase ID token obtained from client-side Firebase Authentication (Apple provider).
 *                 example: eyJhbGciOiJSUzI1NiIsImtpZCI6IjE2MjM0NTY3OCIsInR5cCI6IkpXVCJ9...
 *               role:
 *                 type: string
 *                 enum: [owner, sitter]
 *                 description: >
 *                   Required when signing up a new user (when no existing user with the email exists).
 *                   Ignored if a user with the given email is already present.
 *                 example: owner
 *               user:
 *                 type: object
 *                 description: Optional user data for new account creation
 *                 properties:
 *                   countryCode:
 *                     type: string
 *                     example: "+1"
 *                   currency:
 *                     type: string
 *                     enum: [EUR, USD]
 *                     example: EUR
 *                   paypalEmail:
 *                     type: string
 *                     format: email
 *                     description: Optional PayPal email for sitter payouts (sitter only)
 *                     example: sitter-payments@example.com
 *                   location:
 *                     type: object
 *                     properties:
 *                       coordinates:
 *                         type: array
 *                         items:
 *                           type: number
 *                         description: "[longitude, latitude]"
 *                         example: [-122.4194, 37.7749]
 *                       city:
 *                         type: string
 *                         example: "San Francisco"
 *                       locationType:
 *                         type: string
 *                         enum: [standard, large_city]
 *                         example: standard
 *           examples:
 *             existingUser:
 *               summary: Existing user logging in with Apple
 *               value:
 *                 idToken: eyJhbGciOiJSUzI1NiIsImtpZCI6IjE2MjM0NTY3OCIsInR5cCI6IkpXVCJ9...
 *             newOwnerUser:
 *               summary: New Owner signing up with Apple
 *               value:
 *                 idToken: eyJhbGciOiJSUzI1NiIsImtpZCI6IjE2MjM0NTY3OCIsInR5cCI6IkpXVCJ9...
 *                 role: owner
 *             newSitterUser:
 *               summary: New Sitter signing up with Apple
 *               value:
 *                 idToken: eyJhbGciOiJSUzI1NiIsImtpZCI6IjE2MjM0NTY3OCIsInR5cCI6IkpXVCJ9...
 *                 role: sitter
 *                 user:
 *                   paypalEmail: "alex.sitter.paypal@example.com"
 *     responses:
 *       200:
 *         description: Existing user logged in successfully with Apple account
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 existingUser:
 *                   type: boolean
 *                   example: true
 *                 role:
 *                   type: string
 *                   enum: [owner, sitter]
 *                   description: Role of the authenticated user.
 *                   example: owner
 *                 provider:
 *                   type: string
 *                   description: Firebase sign-in provider identifier.
 *                   example: apple.com
 *                 token:
 *                   type: string
 *                   description: Application JWT issued by the backend (use in Authorization header as `Bearer <token>`).
 *                   example: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.app-payload.signature
 *                 user:
 *                   description: Sanitized user profile of the authenticated account.
 *                   oneOf:
 *                     - $ref: '#/components/schemas/Owner'
 *                     - $ref: '#/components/schemas/Sitter'
 *             examples:
 *               existingOwner:
 *                 summary: Existing Owner logging in with Apple
 *                 value:
 *                   existingUser: true
 *                   role: owner
 *                   provider: apple.com
 *                   token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.app-payload.signature
 *                   user:
 *                     id: 661234abcd1234abcd1234ef
 *                     name: Jane Doe
 *                     email: jane.owner@example.com
 *                     mobile: "491234567890"
 *                     countryCode: "+49"
 *                     address: "Main Street 1, Berlin"
 *                     language: "English"
 *                     service: "Pet Sitting"
 *                     avatar:
 *                       url: "https://example.com/avatar.jpg"
 *                       publicId: "avatars/jane-owner"
 *                     verified: true
 *                     authProvider: apple
 *                     createdAt: "2024-11-01T12:00:00.000Z"
 *                     updatedAt: "2024-11-10T09:30:00.000Z"
 *       201:
 *         description: New user created from Apple account and logged in successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 existingUser:
 *                   type: boolean
 *                   example: false
 *                 role:
 *                   type: string
 *                   enum: [owner, sitter]
 *                   description: Role of the newly created user.
 *                   example: sitter
 *                 provider:
 *                   type: string
 *                   description: Firebase sign-in provider identifier.
 *                   example: apple.com
 *                 token:
 *                   type: string
 *                   description: Application JWT issued by the backend.
 *                   example: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.app-payload.signature
 *                 user:
 *                   description: Sanitized profile of the newly created account.
 *                   oneOf:
 *                     - $ref: '#/components/schemas/Owner'
 *                     - $ref: '#/components/schemas/Sitter'
 *             examples:
 *               newSitter:
 *                 summary: New Sitter created from Apple login
 *                 value:
 *                   existingUser: false
 *                   role: sitter
 *                   provider: apple.com
 *                   token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.app-payload.signature
 *                   user:
 *                     id: 661234abcd1234abcd1234ff
 *                     name: "Alex Petlover"
 *                     email: alex.sitter@example.com
 *                     mobile: ""
 *                     countryCode: ""
 *                     address: ""
 *                     location:
 *                       lat: 37.7749
 *                       lng: -122.4194
 *                       city: "San Francisco"
 *                     language: "English"
 *                     service: "Dog Walking"
 *                     bio: ""
 *                     skills: ""
 *                     hourlyRate: 0
 *                     rating: 0
 *                     reviewsCount: 0
 *                     avatar:
 *                       url: "https://example.com/avatar-alex.jpg"
 *                       publicId: "avatars/alex-sitter"
 *                     verified: true
 *                     authProvider: apple
 *                     createdAt: "2024-11-10T09:45:00.000Z"
 *                     updatedAt: "2024-11-10T09:45:00.000Z"
 *       400:
 *         description: Bad request (missing token, missing role for new user, or invalid token data)
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *             examples:
 *               missingToken:
 *                 summary: idToken not provided
 *                 value:
 *                   error: "idToken is required."
 *               missingRole:
 *                 summary: Role missing for new user
 *                 value:
 *                   error: "Role is required for new Apple users and must be \"owner\" or \"sitter\"."
 *       401:
 *         description: Invalid or expired Firebase ID token
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *             example:
 *               error: "Invalid or expired Firebase ID token."
 *       500:
 *         description: Server error during authentication
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *             example:
 *               error: "Unable to authenticate with Apple. Please try again later."
 */
router.post('/apple', appleAuth);

/**
 * @swagger
 * /auth/verify:
 *   post:
 *     summary: Verify email with verification code
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - code
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 example: john@example.com
 *               code:
 *                 type: string
 *                 example: 123456
 *     responses:
 *       200:
 *         description: Email verified successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: Email verified successfully.
 *                 role:
 *                   type: string
 *                   enum: [owner, sitter]
 *                 token:
 *                   type: string
 *                   description: JWT authentication token
 *                 user:
 *                   oneOf:
 *                     - $ref: '#/components/schemas/Owner'
 *                     - $ref: '#/components/schemas/Sitter'
 *       400:
 *         description: Invalid or expired code
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.post('/verify', verifyEmail);

/**
 * @swagger
 * /auth/resend-code:
 *   post:
 *     summary: Resend verification code to email
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 example: john@example.com
 *     responses:
 *       200:
 *         description: Verification code resent
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: Verification code sent to email.
 *       404:
 *         description: User not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.post('/resend-code', resendVerificationCode);

/**
 * @swagger
 * /auth/forgot-password:
 *   post:
 *     summary: Request password reset
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 example: john@example.com
 *     responses:
 *       200:
 *         description: Password reset code sent to email
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: Password reset code sent to email.
 *       404:
 *         description: User not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.post('/forgot-password', forgotPassword);

/**
 * @swagger
 * /auth/verify-password-reset-otp:
 *   post:
 *     summary: Verify password reset OTP (Step 2 of password reset)
 *     tags: [Authentication]
 *     description: Verifies the OTP sent to user's email. Must be called before reset-password.
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - code
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 example: john@example.com
 *               code:
 *                 type: string
 *                 example: 123456
 *     responses:
 *       200:
 *         description: OTP verified successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: OTP verified successfully. You can now reset your password.
 *                 verified:
 *                   type: boolean
 *                   example: true
 *       400:
 *         description: Invalid code or missing fields
 *       404:
 *         description: User not found
 *       410:
 *         description: Code expired
 */
router.post('/verify-password-reset-otp', verifyPasswordResetOtp);

/**
 * @swagger
 * /auth/reset-password:
 *   post:
 *     summary: Reset password (Step 3 of password reset)
 *     tags: [Authentication]
 *     description: Resets the password after OTP has been verified. Requires OTP to be verified first.
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - newPassword
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 example: john@example.com
 *               newPassword:
 *                 type: string
 *                 format: password
 *                 minLength: 6
 *                 example: newpassword123
 *     responses:
 *       200:
 *         description: Password reset successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: Password reset successful.
 *       400:
 *         description: OTP not verified or missing fields
 *       404:
 *         description: User not found
 *       410:
 *         description: Code expired
 */
router.post('/reset-password', resetPassword);

/**
 * @swagger
 * /auth/change-password:
 *   put:
 *     summary: Change password (requires authentication)
 *     tags: [Authentication]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - currentPassword
 *               - newPassword
 *             properties:
 *               currentPassword:
 *                 type: string
 *                 format: password
 *                 example: oldpassword123
 *               newPassword:
 *                 type: string
 *                 format: password
 *                 minLength: 6
 *                 example: newpassword123
 *     responses:
 *       200:
 *         description: Password changed successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: Password changed successfully.
 *       401:
 *         description: Unauthorized or invalid current password
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.put('/change-password', requireAuth, changePassword);

/**
 * @swagger
 * /auth/choose-service:
 *   post:
 *     summary: Choose service type for user
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - service
 *             properties:
 *               service:
 *                 type: array
 *                 description: List of service types (e.g. Pet Sitting, Dog Walking)
 *                 items:
 *                   type: string
 *                 example: [Pet Sitting, Dog Walking]
 *     responses:
 *       200:
 *         description: Service updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: Service updated successfully.
 *       400:
 *         description: Invalid input
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.post('/choose-service', chooseService);

module.exports = router;


