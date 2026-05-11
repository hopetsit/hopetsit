const express = require('express');
const multer = require('multer');

const { updateService, updateProfile, updateCard, deleteAccount, updateOwnerCardFromToken, deleteAccountFromToken, updateProfilePicture, getOwnerProfile, switchRole, registerFcmToken, unregisterFcmToken, acceptTerms, getMyLoyalty, getMyReferralsRoute } = require('../controllers/userController');
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
 * /users/me/profile:
 *   get:
 *     summary: Get owner profile (Owner only)
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Owner profile retrieved successfully. Includes location (lat, lng, city) when set.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 profile:
 *                   $ref: '#/components/schemas/Owner'
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Only owners can access this endpoint
 */
router.get('/me/profile', requireAuth, requireRole('owner'), getOwnerProfile);

// v23.1 part 114 — Daniel : "le boost marche pas" / "aucun des paw spot ne marche".
// Endpoint léger qui renvoie les flags d'avantages actifs (boostExpiry,
// mapBoostExpiry, kycStatus, isPremium, etc.) pour le user courant, peu
// importe son rôle. Permet à l'app mobile d'afficher les badges
// (ActiveBenefitsRow) instantanément même pour les sitters/walkers
// (qui n'ont pas accès à /users/me/profile, réservé aux owners).
router.get(
  '/me/benefits',
  requireAuth,
  requireRole('owner', 'sitter', 'walker'),
  async (req, res) => {
    const logger = require('../utils/logger');
    try {
      const role = (req.user.role || '').toLowerCase();
      let Model;
      let modelName;
      if (role === 'owner') { Model = require('../models/Owner'); modelName = 'Owner'; }
      else if (role === 'sitter') { Model = require('../models/Sitter'); modelName = 'Sitter'; }
      else if (role === 'walker') { Model = require('../models/Walker'); modelName = 'Walker'; }
      else return res.status(403).json({ error: 'Unsupported role.' });

      // v23.1 part 115 — on retire isPremium du select() pour Sitter/Walker
      // (le champ n'existe que sur Owner). On lit `lean()` puis on fallback
      // sur undefined sans erreur.
      const user = await Model.findById(req.user.id).lean();
      if (!user) {
        logger.warn(`[users/me/benefits] user not found role=${role} id=${req.user.id}`);
        return res.status(404).json({ error: 'User not found.' });
      }

      // v23.1 part 115 — Premium dérivé : isPremium (owner) OU UserSubscription
      // active. La query filtre par {userId, userModel} (composite unique
      // index) pour éviter les collisions entre rôles.
      let subscriptionActive = false;
      let subscriptionPlan = null;
      try {
        const UserSubscription = require('../models/UserSubscription');
        const sub = await UserSubscription.findOne({
          userId: req.user.id,
          userModel: modelName,
          status: 'active',
        }).select('currentPeriodEnd plan').lean();
        if (sub && sub.currentPeriodEnd && new Date(sub.currentPeriodEnd) > new Date()) {
          subscriptionActive = true;
          subscriptionPlan = sub.plan || null;
        }
      } catch (e) {
        logger.warn(`[users/me/benefits] subscription lookup failed : ${e.message}`);
      }

      const payload = {
        role,
        boostExpiry: user.boostExpiry || null,
        boostTier: user.boostTier || null,
        mapBoostExpiry: user.mapBoostExpiry || null,
        mapBoostTier: user.mapBoostTier || null,
        mapBoostLocation: user.mapBoostLocation || null,
        kycStatus: user.kycStatus || 'none',
        kycVerifiedAt: user.kycVerifiedAt || null,
        verified: !!user.verified,
        ibanVerified: !!user.ibanVerified,
        isPremium: !!user.isPremium || subscriptionActive,
        subscriptionPlan,
        // v23.1 part 115 — flag identityVerification (manual upload status)
        // pour le banner KYC du profil.
        identityVerificationStatus: user.identityVerification?.status || 'none',
      };
      logger.debug(
        `[users/me/benefits] role=${role} id=${req.user.id} boost=${!!payload.boostExpiry} mapBoost=${!!payload.mapBoostExpiry} kyc=${payload.kycStatus} premium=${payload.isPremium}`,
      );
      return res.json(payload);
    } catch (e) {
      logger.error('[users/me/benefits]', e);
      return res.status(500).json({ error: e.message });
    }
  },
);

/**
 * @swagger
 * /users/me/card:
 *   put:
 *     summary: Update owner card information (Owner only)
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               cardNumber:
 *                 type: string
 *                 example: 4111111111111111
 *               cardHolderName:
 *                 type: string
 *                 example: John Doe
 *               expiryMonth:
 *                 type: number
 *                 example: 12
 *               expiryYear:
 *                 type: number
 *                 example: 2025
 *               cvv:
 *                 type: string
 *                 example: 123
 *     responses:
 *       200:
 *         description: Card updated successfully
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Only owners can access this endpoint
 */
// v18.9.3 — fix 403 ajout carte côté sitter/walker. Avant v18.9.3, cette
// route n'acceptait que 'owner' alors que les 3 rôles utilisent le même
// AddCardScreen legacy.
router.put('/me/card', requireAuth, requireRole('owner', 'sitter', 'walker'), updateOwnerCardFromToken);

/**
 * @swagger
 * /users/me/profile-picture:
 *   put:
 *     summary: Update profile picture (Owner or Sitter)
 *     tags: [Users]
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
 *         description: Profile picture updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                 user:
 *                   oneOf:
 *                     - $ref: '#/components/schemas/Owner'
 *                     - $ref: '#/components/schemas/Sitter'
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
 */
router.put('/me/profile-picture', requireAuth, upload.single('avatar'), updateProfilePicture);

/**
 * @swagger
 * /users/me:
 *   delete:
 *     summary: Delete own account (Owner or Sitter)
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Account deleted successfully
 *       401:
 *         description: Unauthorized
 */
router.delete('/me', requireAuth, deleteAccountFromToken);

/**
 * @swagger
 * /users/{id}/service:
 *   put:
 *     summary: Update user service type
 *     tags: [Users]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: User ID
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
 *                 items:
 *                   type: string
 *                 example: [Pet Sitting, Dog Walking]
 *     responses:
 *       200:
 *         description: Service updated successfully
 *       404:
 *         description: User not found
 */
router.put('/:id/service', updateService);

/**
 * @swagger
 * /users/{id}/profile:
 *   put:
 *     summary: Update user profile
 *     tags: [Users]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: User ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *               mobile:
 *                 type: string
 *               countryCode:
 *                 type: string
 *                 description: International country calling code (E.164 format, e.g. +1, +44)
 *                 example: +1
 *               currency:
 *                 type: string
 *                 description: Preferred currency (EUR or USD)
 *                 enum: [EUR, USD]
 *                 example: EUR
 *               address:
 *                 type: string
 *               language:
 *                 type: string
 *               bio:
 *                 type: string
 *               skills:
 *                 type: string
 *               location:
 *                 type: object
 *                 description: Location with coordinates and city. Pass null to remove.
 *                 properties:
 *                   lat:
 *                     type: number
 *                     description: Latitude (-90 to 90)
 *                     example: 33.5288591
 *                   lng:
 *                     type: number
 *                     description: Longitude (-180 to 180)
 *                     example: 73.063089
 *                   city:
 *                     type: string
 *                     description: City name
 *                     example: Rawalpindi
 *                   locationType:
 *                     type: string
 *                     description: For sitters - standard or large_city
 *                     enum: [standard, large_city]
 *                     example: standard
 *     responses:
 *       200:
 *         description: Profile updated successfully. Returns user with location (lat, lng, city) when set.
 *       404:
 *         description: User not found
 */
router.put('/:id/profile', updateProfile);

/**
 * @swagger
 * /users/{id}/card:
 *   put:
 *     summary: Update user card information
 *     tags: [Users]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: User ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               cardNumber:
 *                 type: string
 *               cardHolderName:
 *                 type: string
 *               expiryMonth:
 *                 type: number
 *               expiryYear:
 *                 type: number
 *               cvv:
 *                 type: string
 *     responses:
 *       200:
 *         description: Card updated successfully
 *       404:
 *         description: User not found
 */
router.put('/:id/card', updateCard);

/**
 * @swagger
 * /users/{id}:
 *   delete:
 *     summary: Delete user account
 *     tags: [Users]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: User ID
 *     responses:
 *       200:
 *         description: Account deleted successfully
 *       404:
 *         description: User not found
 */
router.delete('/:id', deleteAccount);

/**
 * @swagger
 * /users/switch-role:
 *   post:
 *     summary: Switch user role (Owner to Sitter or Sitter to Owner)
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Role switched successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: Successfully switched from owner to sitter.
 *                 role:
 *                   type: string
 *                   enum: [owner, sitter]
 *                 token:
 *                   type: string
 *                   description: New JWT token with updated role
 *                 user:
 *                   type: object
 *                   description: Updated user object
 *       401:
 *         description: Unauthorized
 *       404:
 *         description: User not found
 *       500:
 *         description: Internal server error
 */
router.post('/switch-role', requireAuth, switchRole);

// Sprint 4 step 1 — FCM device token registration
router.post('/fcm-token', requireAuth, registerFcmToken);
router.delete('/fcm-token', requireAuth, unregisterFcmToken);

// Sprint 5 step 4 — accept current T&C (records date + version)
router.patch('/accept-terms', requireAuth, acceptTerms);

// Sprint 7 step 1 — owner loyalty stats
router.get('/me/loyalty', requireAuth, requireRole('owner'), getMyLoyalty);

// Sprint 7 step 3 — referral program (owner + sitter)
router.get('/me/referrals', requireAuth, getMyReferralsRoute);

module.exports = router;

