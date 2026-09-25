const express = require('express');
const multer = require('multer');

const { updateService, updateProfile, updateCard, deleteAccount, updateOwnerCardFromToken, deleteAccountFromToken, updateProfilePicture, getOwnerProfile, switchRole, registerFcmToken, unregisterFcmToken, acceptTerms, updateAppLocale, getMyLoyalty, getMyReferralsRoute, addFavoriteProvider, removeFavoriteProvider, getFavoriteProviders,
  // v565
  getNotificationPrefs, updateNotificationPrefs, requestEmailChange, confirmEmailChange, resendEmailChange } = require('../controllers/userController');
const { requireAuth, requireRole } = require('../middleware/auth');
const { identityGroup } = require('../utils/identityGroup');

const router = express.Router();

// ─── v575 — P0-3 SÉCURITÉ : les routes `/users/:id/*` ────────────────────────
// Les 4 routes qui prennent un id dans l'URL (`PUT /:id/service`,
// `PUT /:id/profile`, `PUT /:id/card`, `DELETE /:id`) étaient montées SANS
// `requireAuth` : n'importe qui connaissant un id — et un id fuit dans
// `ownerId` / `sitterId` / `walkerId` de nombreuses réponses — pouvait
// modifier un profil ou SUPPRIMER un compte.
//
// `requireSelfId` complète `requireAuth` : la cible doit être la personne
// connectée. Une personne = jusqu'à 3 documents (Owner / Sitter / Walker)
// reliés par l'e-mail → on accepte tout id du GROUPE D'IDENTITÉ
// (`utils/identityGroup`), pas seulement `req.user.id` : l'app édite parfois
// le profil d'un rôle frère avec le jeton d'un autre.
//
// Pas d'exception admin ici : l'administration passe par ses propres routes
// `/admin/users/...` (middleware `requireAdmin` dans `adminRoutes.js`).
const requireSelfId = async (req, res, next) => {
  const logger = require('../utils/logger');
  try {
    const meId = String(req.user?.id || '');
    const targetId = String(req.params?.id || '');
    if (!meId) {
      return res.status(401).json({ error: 'Authorization token is required.' });
    }
    if (!targetId) {
      return res.status(400).json({ error: 'Invalid user id.' });
    }
    if (targetId === meId) return next();

    const { set } = await identityGroup(meId);
    if (set.has(targetId)) return next();

    logger.warn(
      {
        path: req.originalUrl,
        method: req.method,
        userId: meId,
        targetId,
      },
      '[requireSelfId] 403 — tentative de modification du compte d’autrui',
    );
    return res.status(403).json({
      error: 'You can only modify your own account.',
      code: 'FORBIDDEN_NOT_SELF',
    });
  } catch (error) {
    logger.error('[requireSelfId] identity check failed', error);
    return res.status(403).json({
      error: 'You can only modify your own account.',
      code: 'FORBIDDEN_NOT_SELF',
    });
  }
};

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
router.get('/me/profile', requireAuth, getOwnerProfile);

// v414 — parité site web : le site PUT /users/me/profile (role-agnostic) pour
// enregistrer nom/bio/préférences/2FA. Sans cette route, la requête tombait sur
// `/:id/profile` avec id='me' → CastError → 400 "Invalid user id." On résout
// l'id depuis le token (peu importe le rôle) puis on délègue à updateProfile,
// qui sait déjà persister preferences/twoFactorEnabled (v405) et synchroniser
// les champs partagés vers les autres rôles du même compte.
router.put('/me/profile', requireAuth, (req, res, next) => {
  req.params.id = req.user.id;
  return updateProfile(req, res, next);
});

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
      // v23.1.276 — Daniel : "change premium à PawFollow avec les jours restant
      // et rajoute badge Family avec les jours". On expose désormais :
      //   - pawFollowExpiry : fin de l'abo PawFollow INDIVIDUEL (mensuel/annuel)
      //   - familyActive + familyExpiry : plan FAMILLE actif où je suis
      //     titulaire OU membre accepté (status='active').
      // Cela permet 2 badges distincts (PawFollow doré + Family violet) avec
      // leurs jours respectifs, et la bannière boutique scindée en deux.
      let pawFollowExpiry = null;
      let familyActive = false;
      let familyExpiry = null;
      try {
        const UserSubscription = require('../models/UserSubscription');
        const {
          familyActiveMatch,
          familyExpiryOf,
        } = require('../models/UserSubscription');
        const now = new Date();
        // v23.1.283 — famille DÉCOUPLÉE de l'individuel. L'abo INDIVIDUEL =
        // plan monthly/yearly/solo actif (currentPeriodEnd futur). Le plan
        // FAMILLE a son propre timer familyExpiry (ou ancien plan='famille').
        const sub = await UserSubscription.findOne({
          userId: req.user.id,
          userModel: modelName,
        }).select('currentPeriodEnd plan familyExpiry status').lean();
        if (sub) {
          // v23.1.284 — détection individuel par DATE (status peut être périmé).
          const indivActive =
            sub.currentPeriodEnd &&
            new Date(sub.currentPeriodEnd) > now &&
            sub.plan !== 'famille' &&
            sub.plan !== 'family';
          if (indivActive) {
            subscriptionActive = true;
            subscriptionPlan = sub.plan || null;
            pawFollowExpiry = sub.currentPeriodEnd;
          }
        }
        // Famille : titulaire (familyExpiry OU ancien plan) OU membre actif.
        const fam = await UserSubscription.findOne({
          $and: [
            familyActiveMatch(now),
            {
              $or: [
                { userId: req.user.id, userModel: modelName },
                {
                  familyMembers: {
                    $elemMatch: { userId: req.user.id, status: 'active' },
                  },
                },
              ],
            },
          ],
        })
          .select('currentPeriodEnd familyExpiry plan')
          .lean();
        if (fam) {
          familyActive = true;
          familyExpiry = familyExpiryOf(fam);
        }
      } catch (e) {
        logger.warn(`[users/me/benefits] subscription lookup failed : ${e.message}`);
      }

      // v23.1.278/283 — PawFollow INDIVIDUEL actif = isPremium legacy/staff OU
      // abo individuel actif. subscriptionActive ne vaut désormais true QUE pour
      // l'individuel (la famille est gérée séparément) → les 2 badges peuvent
      // coexister sans se calculer ensemble.
      const pawFollowActive = !!user.isPremium || subscriptionActive;

      // v23.1.353 — refonte PawSpot : abo communautaire actif ? (+ essai 7 j)
      // v23.1.358 — BUG (Daniel : "je prends un abonnement PawSpot mais ça
      // ne passe pas en ON") : `UserSubscription` et `now` étaient déclarés
      // DANS le try{} PawFollow plus haut → hors de portée ici →
      // ReferenceError avalé par le catch → pawspotActive TOUJOURS false.
      // Fix : require local + new Date() direct + warn loggé.
      let pawspotActive = false;
      let pawspotExpiry = null;
      // v23.1.387 — Paw Premium (bundle PawFollow + PawSpot + extras) :
      // timer dédié premiumExpiry → badge noir/or + points ×2.
      let premiumActive = false;
      let premiumExpiry = null;
      // v23.1.388 — lazy-heal : aligne les timers des comptes frères (même
      // email, autres rôles) à chaque lecture du profil — couvre les achats
      // antérieurs et garantit « acheté en walker = visible en sitter ».
      try {
        const { syncAllRolesByEmail } = require('../models/UserSubscription');
        await syncAllRolesByEmail(req.user.id, modelName);
      } catch (_) { /* best-effort */ }
      try {
        const UserSubscriptionPs = require('../models/UserSubscription');
        const psSub = await UserSubscriptionPs.findOne({
          userId: req.user.id,
          userModel: modelName,
        }).select('pawspotExpiry premiumExpiry').lean();
        const _bn = new Date();
        if (psSub?.pawspotExpiry && new Date(psSub.pawspotExpiry) > _bn) {
          pawspotActive = true;
          pawspotExpiry = psSub.pawspotExpiry;
        }
        if (psSub?.premiumExpiry && new Date(psSub.premiumExpiry) > _bn) {
          premiumActive = true;
          premiumExpiry = psSub.premiumExpiry;
        }
      } catch (e) {
        logger.warn(`[users/me/benefits] pawspot lookup failed : ${e.message}`);
      }

      // v426 — Premium Staff : un membre du staff (isStaff) a TOUS les abos
      // gratuits (cf /subscriptions/status qui renvoie déjà isPremium:true).
      // Avant, /users/me/benefits ne lisait que les timers (premiumExpiry,
      // pawspotExpiry…) qui ne sont PAS posés pour un staff « free » → tous
      // les flags retombaient à false → PawSpotController.premiumActive=false,
      // ActiveBenefitsRow sans badge, PawFollow/PawSpot bloqués sur la carte,
      // et ReportPremiumHelper.isUnlocked privé de sa 2e source. On force donc
      // tous les drapeaux premium à true pour le staff (additif, lecture seule).
      let isStaff = user.isStaff === true;
      // v497 — Daniel : « j'ai mis mon ami STAFF mais il n'est toujours pas
      // premium ». CAUSE : isStaff peut n'être posé que sur UN SEUL des 3 docs
      // rôle (Owner/Sitter/Walker) — s'il se connecte sous un autre rôle, ce
      // doc a isStaff=false → benefits ne le voit pas premium. La propagation
      // admin (v495) ne corrige que les NOUVEAUX toggles. Pour les comptes DÉJÀ
      // marqués staff, on relit isStaff sur les 3 docs de la même personne
      // (même email/oldId) → premium garanti quel que soit le rôle, SANS devoir
      // re-cocher dans l'admin ni réinstaller l'app. Lookup léger (1× /session).
      if (!isStaff && (user.email || user.oldId)) {
        try {
          const Owner = require('../models/Owner');
          const Sitter = require('../models/Sitter');
          const Walker = require('../models/Walker');
          const or = [];
          if (user.email) or.push({ email: user.email });
          if (user.oldId) or.push({ oldId: user.oldId });
          const [o, s2, w] = await Promise.all([
            Owner.findOne({ $or: or, isStaff: true }).select('_id').lean(),
            Sitter.findOne({ $or: or, isStaff: true }).select('_id').lean(),
            Walker.findOne({ $or: or, isStaff: true }).select('_id').lean(),
          ]);
          if (o || s2 || w) isStaff = true;
        } catch (e) {
          logger.warn(`[users/me/benefits] cross-role isStaff lookup failed : ${e.message}`);
        }
      }

      // v565 §4 — verrou contacts : true = seuil (CONTACTS_FREE_UNTIL_USERS)
      // atteint ET aucun débloquage global (staff / abonnement / add-on chat).
      let contactsLocked = false;
      try {
        const { isContactsLockedGlobally, hasContactsUnlock } = require('../services/chatAccessService');
        if (await isContactsLockedGlobally()) {
          const unlock = isStaff ? { unlocked: true } : await hasContactsUnlock(req.user.id);
          contactsLocked = !unlock.unlocked;
        }
      } catch (e) {
        logger.warn(`[users/me/benefits] contacts lock check failed : ${e.message}`);
      }

      // v585 (bug 11) — PawBoost vaut pour la PERSONNE : le boost acheté sous
      // un autre rôle compte aussi (Daniel : « j'active PawBoost, mon rond
      // garde la couleur du rôle » après un changement de rôle).
      let personBoostRes = null;
      try {
        const { personIds: _pids } = require('../utils/personScope');
        const { personBoost } = require('../utils/personMapPosition');
        const ids = (await _pids(req.user.id)).map(String);
        const O = require('../models/Owner');
        const S = require('../models/Sitter');
        const W = require('../models/Walker');
        const sibs = (await Promise.all([O, S, W].map((M) => M.find({ _id: { $in: ids } })
          .select('boostExpiry boostTier').lean()))).flat();
        personBoostRes = personBoost([user, ...sibs]);
      } catch (e) {
        logger.warn(`[users/me/benefits] person boost failed : ${e.message}`);
      }
      const payload = {
        role,
        isStaff,
        contactsLocked,
        boostExpiry: (personBoostRes && personBoostRes.boostExpiry) || user.boostExpiry || null,
        boostTier: (personBoostRes && personBoostRes.boostTier) || user.boostTier || null,
        mapBoostExpiry: user.mapBoostExpiry || null,
        mapBoostTier: user.mapBoostTier || null,
        pawspotActive: pawspotActive || isStaff,
        pawspotExpiry,
        premiumActive: premiumActive || isStaff,
        premiumExpiry,
        pawPoints: user.pawPoints || 0,
        mapBoostLocation: user.mapBoostLocation || null,
        kycStatus: user.kycStatus || 'none',
        kycVerifiedAt: user.kycVerifiedAt || null,
        verified: !!user.verified,
        ibanVerified: !!user.ibanVerified,
        isPremium: !!user.isPremium || subscriptionActive || isStaff,
        subscriptionPlan,
        pawFollowActive: pawFollowActive || isStaff,
        pawFollowExpiry,
        familyActive,
        familyExpiry,
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
// v575 P0-3 — authentification + cible = soi-même (cf. `requireSelfId`).
router.put('/:id/service', requireAuth, requireSelfId, updateService);

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
// v575 P0-3 — authentification + cible = soi-même (cf. `requireSelfId`).
// ⚠️ Cette route EST utilisée par l'app (préférences, 2FA, « Modifier le
// profil » propriétaire) : elle envoie déjà son jeton (`requiresAuth: true`).
router.put('/:id/profile', requireAuth, requireSelfId, updateProfile);

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
// v575 P0-3 — authentification + cible = soi-même (cf. `requireSelfId`).
// (La route répond 410 depuis la v568 : plus aucun PAN ne transite ici.)
router.put('/:id/card', requireAuth, requireSelfId, updateCard);

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
// v575 P0-3 — authentification + cible = soi-même (cf. `requireSelfId`).
router.delete('/:id', requireAuth, requireSelfId, deleteAccount);

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
// v574 — rôles que possède la personne (synchronisation entre appareils).
router.get('/me/roles', requireAuth, require('../controllers/rolesController').getMyRoles);

// Sprint 4 step 1 — FCM device token registration
router.post('/fcm-token', requireAuth, registerFcmToken);
router.delete('/fcm-token', requireAuth, unregisterFcmToken);

// Sprint 5 step 4 — accept current T&C (records date + version)
router.patch('/accept-terms', requireAuth, acceptTerms);
// v23.1.348 — la langue suit le système : l'app synchronise sa locale UI.
router.patch('/me/app-locale', requireAuth, updateAppLocale);

// v565 §2 — préférences de notification (son + catégories), synchronisées
// sur les 3 profils de la personne. Corps partiel accepté au PATCH.
// v584 (lot C, 24/09) — préférences de la PawMap sur le compte + mode
// « visible par mes amis seulement » (même champ que Préférences).
const { getMapPrefs, updateMapPrefs } = require('../controllers/mapPrefsController');
router.get('/me/map-prefs', requireAuth, requireRole('owner', 'sitter', 'walker'), getMapPrefs);
router.patch('/me/map-prefs', requireAuth, requireRole('owner', 'sitter', 'walker'), updateMapPrefs);
router.get('/me/notification-prefs', requireAuth, requireRole('owner', 'sitter', 'walker'), getNotificationPrefs);
router.patch('/me/notification-prefs', requireAuth, requireRole('owner', 'sitter', 'walker'), updateNotificationPrefs);

// v566 — informations de facturation (NIF, NIE, CIF, SIRET, TVA, EIN, passeport…),
// synchronisées sur les 3 profils de la personne ; reprises sur les factures.
{
  const { getMyBillingInfo, updateMyBillingInfo } = require('../controllers/billingInfoController');
  router.get('/me/billing-info', requireAuth, requireRole('owner', 'sitter', 'walker'), getMyBillingInfo);
  router.patch('/me/billing-info', requireAuth, requireRole('owner', 'sitter', 'walker'), updateMyBillingInfo);
}

// v565 §3 — changement d'e-mail par l'utilisateur (code envoyé à la NOUVELLE
// adresse, 24 h ; confirmation → e-mail remplacé sur les 3 profils).
router.post('/me/email-change', requireAuth, requireRole('owner', 'sitter', 'walker'), requestEmailChange);
router.post('/me/email-change/confirm', requireAuth, requireRole('owner', 'sitter', 'walker'), confirmEmailChange);
router.post('/me/email-change/resend', requireAuth, requireRole('owner', 'sitter', 'walker'), resendEmailChange);

// Sprint 7 step 1 — owner loyalty stats
router.get('/me/loyalty', requireAuth, requireRole('owner'), getMyLoyalty);

// Sprint 7 step 3 — referral program (owner + sitter)
router.get('/me/referrals', requireAuth, getMyReferralsRoute);

// v444 — Favoris prestataires (cœur sur les cartes de recherche owner).
// Owner-only. 100 % additif. Le cœur des SitterCard/WalkerCard les persiste.
//   GET    /users/me/favorites               → liste [{providerId, providerRole}]
//   POST   /users/me/favorites               → ajout idempotent {providerId, providerRole}
//   DELETE /users/me/favorites/:providerId   → suppression
// v576 — Daniel : « mes listes également » doivent être synchronisées entre les
// 3 profils. Les favoris sont stockés sur le document Owner de la personne,
// mais `requireRole('owner')` refusait (403) l'accès depuis les profils gardien
// et promeneur : la même personne perdait sa liste en changeant de rôle. Le
// middleware ci-dessous résout le document Owner DU GROUPE D'IDENTITÉ et
// présente le contrôleur avec ce profil — aucune donnée n'est déplacée, la
// liste reste unique et vit toujours sur le document Owner.
const asOwnerProfile = async (req, res, next) => {
  try {
    if (String(req.user?.role || '').toLowerCase() === 'owner') return next();
    const Owner = require('../models/Owner');
    const g = await identityGroup(req.user.id);
    const ownerDoc = g.docs.find((d) => d.model === 'Owner')
      || (await Owner.findOne({ _id: { $in: g.ids } }).select('_id').lean()
        .then((d) => (d ? { id: String(d._id) } : null)));
    if (!ownerDoc) {
      // La personne n'a pas (encore) de profil propriétaire : liste vide
      // plutôt qu'un 403 incompréhensible côté app.
      if (req.method === 'GET') return res.json({ favorites: [] });
      return res.status(403).json({
        error: 'An owner profile is required to manage favorites.',
        code: 'OWNER_PROFILE_REQUIRED',
      });
    }
    req.user = { ...req.user, id: String(ownerDoc.id), role: 'owner' };
    return next();
  } catch (e) {
    return res.status(500).json({ error: 'Unable to resolve owner profile.' });
  }
};

router.get('/me/favorites', requireAuth, asOwnerProfile, getFavoriteProviders);
router.post('/me/favorites', requireAuth, asOwnerProfile, addFavoriteProvider);
router.delete('/me/favorites/:providerId', requireAuth, asOwnerProfile, removeFavoriteProvider);

// v23.1 part 133 — Phase 7 audit P7-12 : RGPD article 15 (droit d'accès)
// + article 20 (droit à la portabilité). Renvoie un JSON complet de
// toutes les données de l'user sur la plateforme. L'user peut ensuite
// l'archiver / le porter chez un concurrent.
router.get(
  '/me/export',
  requireAuth,
  requireRole('owner', 'sitter', 'walker'),
  async (req, res) => {
    try {
      const Owner = require('../models/Owner');
      const Sitter = require('../models/Sitter');
      const Walker = require('../models/Walker');
      const Pet = require('../models/Pet');
      const Booking = require('../models/Booking');
      const Application = require('../models/Application');
      const Review = require('../models/Review');
      const Message = require('../models/Message');
      const Conversation = require('../models/Conversation');
      const Notification = require('../models/Notification');
      const Invoice = require('../models/Invoice');
      const WalletTransaction = require('../models/WalletTransaction');
      const UserSubscription = require('../models/UserSubscription');
      const BugReport = require('../models/BugReport');

      const role = (req.user.role || '').toLowerCase();
      const userId = req.user.id;
      const Model = role === 'sitter' ? Sitter : role === 'walker' ? Walker : Owner;
      const modelName = role === 'sitter' ? 'Sitter' : role === 'walker' ? 'Walker' : 'Owner';

      const user = await Model.findById(userId).lean();
      if (!user) return res.status(404).json({ error: 'User not found.' });

      // On strip les champs sensibles d'auth (password hash, refresh
      // tokens) — l'user n'a pas besoin de ça dans l'export RGPD.
      delete user.password;
      delete user.passwordHash;
      delete user.firebaseUid;

      const conversationFilter =
        role === 'owner' ? { ownerId: userId } : { sitterId: userId };
      const conversations = await Conversation.find(conversationFilter).lean();
      const conversationIds = conversations.map((c) => c._id);

      const [bookings, applications, reviewsByMe, reviewsAboutMe, messages, notifications, invoices, wallet, subs, bugs, pets] = await Promise.all([
        Booking.find({ [role === 'owner' ? 'ownerId' : role === 'sitter' ? 'sitterId' : 'walkerId']: userId }).lean(),
        Application.find({ [role === 'owner' ? 'ownerId' : role === 'sitter' ? 'sitterId' : 'walkerId']: userId }).lean(),
        Review.find({ reviewerId: userId, reviewerModel: modelName }).lean(),
        Review.find({ revieweeId: userId, revieweeModel: modelName }).lean(),
        Message.find({ conversationId: { $in: conversationIds } }).lean(),
        Notification.find({ recipientId: userId, recipientModel: modelName }).lean(),
        Invoice.find({ [role === 'owner' ? 'ownerId' : role === 'sitter' ? 'sitterId' : 'walkerId']: userId }).lean(),
        WalletTransaction.find({ userId, userModel: modelName }).lean(),
        UserSubscription.find({ userId, userModel: modelName }).lean(),
        BugReport.find({ userId }).lean(),
        role === 'owner' ? Pet.find({ ownerId: userId }).lean() : Promise.resolve([]),
      ]);

      const payload = {
        exportedAt: new Date().toISOString(),
        role,
        rgpdNotice: 'Cet export contient toutes vos données personnelles stockées par HoPetSit (CARDELLI HERMANOS LIMITED). Article 15 + 20 RGPD.',
        profile: user,
        pets,
        bookings,
        applications,
        reviewsByMe,
        reviewsAboutMe,
        conversations,
        messages,
        notifications,
        invoices,
        walletTransactions: wallet,
        subscriptions: subs,
        bugReports: bugs,
      };

      res.setHeader(
        'Content-Disposition',
        `attachment; filename="hopetsit-data-export-${userId}.json"`,
      );
      res.setHeader('Content-Type', 'application/json');
      res.status(200).json(payload);
    } catch (e) {
      const logger = require('../utils/logger');
      logger.error('[users/me/export]', e);
      res.status(500).json({ error: 'Unable to export data.', details: e.message });
    }
  },
);

module.exports = router;

