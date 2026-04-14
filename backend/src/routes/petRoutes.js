const express = require('express');
const multer = require('multer');

const { createOrUpdatePet, listPets, getPetById, uploadPetMedia, getMyPets, getAllPets, updatePetProfile, updatePetMedia } = require('../controllers/petController');
const { requireAuth, requireRole } = require('../middleware/auth');

const router = express.Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB
  },
});

const petMediaUpload = upload.fields([
  { name: 'file', maxCount: 1 },
  { name: 'photo', maxCount: 10 },
  { name: 'avatar', maxCount: 1 },
  { name: 'passportImage', maxCount: 1 },
  { name: 'media', maxCount: 1 },
  { name: 'video', maxCount: 10 },
]);

/**
 * @swagger
 * /pets/create-pet-profile:
 *   post:
 *     summary: Create or update pet profile (Owner only)
 *     tags: [Pets]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - pet
 *             properties:
 *               pet:
 *                 type: object
 *                 required:
 *                   - petName
 *                   - category
 *                   - vaccination
 *                 properties:
 *                   petName:
 *                     type: string
 *                     description: Pet's name (required)
 *                     example: Max
 *                   category:
 *                     type: string
 *                     description: Pet category/type (required)
 *                     example: Dog
 *                   breed:
 *                     type: string
 *                     example: Golden Retriever
 *                   dob:
 *                     type: string
 *                     description: Date of birth
 *                     example: 2021-01-15
 *                   weight:
 *                     type: string
 *                     description: Pet weight
 *                     example: 25 kg
 *                   height:
 *                     type: string
 *                     description: Pet height
 *                     example: 50 cm
 *                   colour:
 *                     type: string
 *                     example: Golden
 *                   passportNumber:
 *                     type: string
 *                     example: PET123456
 *                   chipNumber:
 *                     type: string
 *                     example: CHIP789012
 *                   medicationAllergies:
 *                     type: string
 *                     example: None
 *                   vaccination:
 *                     type: string
 *                     description: Vaccination details (required)
 *                     example: Up to date - last vaccination 2024-01-15
 *                   bio:
 *                     type: string
 *                     description: Pet biography/description
 *                     example: Friendly and playful dog
 *                   profileView:
 *                     type: string
 *                     example: public
 *                   avatar:
 *                     type: object
 *                     properties:
 *                       url:
 *                         type: string
 *                       publicId:
 *                         type: string
 *                   photos:
 *                     type: array
 *                     items:
 *                       type: object
 *                       properties:
 *                         url:
 *                           type: string
 *                         publicId:
 *                           type: string
 *                   videos:
 *                     type: array
 *                     items:
 *                       type: object
 *                       properties:
 *                         url:
 *                           type: string
 *                         publicId:
 *                           type: string
 *                   passportImage:
 *                     type: object
 *                     properties:
 *                       url:
 *                         type: string
 *                       publicId:
 *                         type: string
 *               petId:
 *                 type: string
 *                 description: Pet ID if updating existing pet (omit for new pet)
 *                 example: 507f1f77bcf86cd799439012
 *     responses:
 *       201:
 *         description: Pet profile created/updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 pet:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                     ownerId:
 *                       type: string
 *                     petName:
 *                       type: string
 *                     category:
 *                       type: string
 *                     breed:
 *                       type: string
 *                     dob:
 *                       type: string
 *                     weight:
 *                       type: string
 *                     height:
 *                       type: string
 *                     colour:
 *                       type: string
 *                     passportNumber:
 *                       type: string
 *                     chipNumber:
 *                       type: string
 *                     medicationAllergies:
 *                       type: string
 *                     vaccination:
 *                       type: string
 *                     bio:
 *                       type: string
 *                     avatar:
 *                       type: object
 *                     photos:
 *                       type: array
 *                     videos:
 *                       type: array
 *                     passportImage:
 *                       type: object
 *                     createdAt:
 *                       type: string
 *                     updatedAt:
 *                       type: string
 *       400:
 *         description: Invalid input or missing required fields (petName, category, vaccination)
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 errors:
 *                   type: object
 *                   description: Object with field names as keys and error messages as values
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Only owners can manage pet profiles
 *       404:
 *         description: Owner not found
 */
router.post('/create-pet-profile', requireAuth, requireRole('owner'), createOrUpdatePet);

/**
 * @swagger
 * /pets/create-pet-profile/images:
 *   post:
 *     summary: Upload pet media/images (Owner only)
 *     tags: [Pets]
 *     security:
 *       - bearerAuth: []
 *     consumes:
 *       - multipart/form-data
 *     parameters:
 *       - in: query
 *         name: petId
 *         required: true
 *         schema:
 *           type: string
 *         description: Pet ID to upload media for
 *         example: 507f1f77bcf86cd799439012
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             required:
 *               - petId (in query)
 *             properties:
 *               avatar:
 *                 type: string
 *                 format: binary
 *                 description: Pet avatar image (single file)
 *               photo:
 *                 type: array
 *                 items:
 *                   type: string
 *                   format: binary
 *                 description: Pet photos (up to 10 files)
 *               passportImage:
 *                 type: string
 *                 format: binary
 *                 description: Pet passport image (single file)
 *               video:
 *                 type: array
 *                 items:
 *                   type: string
 *                   format: binary
 *                 description: Pet videos (up to 10 files)
 *               file:
 *                 type: string
 *                 format: binary
 *                 description: Generic file (treated as photo)
 *               media:
 *                 type: string
 *                 format: binary
 *                 description: Generic media (treated as photo)
 *               folder:
 *                 type: string
 *                 description: Custom Cloudinary folder (optional)
 *     responses:
 *       200:
 *         description: Media uploaded successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 pet:
 *                   type: object
 *                   description: Updated pet object with media URLs
 *                 uploaded:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       type:
 *                         type: string
 *                         enum: [avatar, photo, passportImage, video]
 *                       url:
 *                         type: string
 *                       publicId:
 *                         type: string
 *       400:
 *         description: Missing petId, no files provided, or invalid input
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Only owners can upload pet media
 *       404:
 *         description: Pet not found for this owner
 */
router.post(
  '/create-pet-profile/images',
  requireAuth,
  requireRole('owner'),
  petMediaUpload,
  uploadPetMedia
);

/**
 * @swagger
 * /pets/{id}:
 *   put:
 *     summary: Update pet profile (Owner only)
 *     tags: [Pets]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Pet ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               petName:
 *                 type: string
 *               breed:
 *                 type: string
 *               age:
 *                 type: number
 *               weight:
 *                 type: number
 *               height:
 *                 type: number
 *               colour:
 *                 type: string
 *               description:
 *                 type: string
 *     responses:
 *       200:
 *         description: Pet profile updated successfully
 *       401:
 *         description: Unauthorized
 *       404:
 *         description: Pet not found
 */
router.put('/:id', requireAuth, requireRole('owner'), updatePetProfile);

/**
 * @swagger
 * /pets/{id}/media:
 *   put:
 *     summary: Update pet media (Owner only)
 *     tags: [Pets]
 *     security:
 *       - bearerAuth: []
 *     consumes:
 *       - multipart/form-data
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Pet ID
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               photo:
 *                 type: array
 *                 items:
 *                   type: string
 *                   format: binary
 *               avatar:
 *                 type: string
 *                 format: binary
 *               video:
 *                 type: array
 *                 items:
 *                   type: string
 *                   format: binary
 *     responses:
 *       200:
 *         description: Pet media updated successfully
 *       401:
 *         description: Unauthorized
 *       404:
 *         description: Pet not found
 */
router.put('/:id/media', requireAuth, requireRole('owner'), petMediaUpload, updatePetMedia);

/**
 * @swagger
 * /pets/me:
 *   get:
 *     summary: Get my pets (Owner only)
 *     tags: [Pets]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Pets retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 pets:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Pet'
 *       401:
 *         description: Unauthorized
 */
router.get('/me', requireAuth, requireRole('owner'), getMyPets);

/**
 * @swagger
 * /pets/all:
 *   get:
 *     summary: Get all pets (public)
 *     tags: [Pets]
 *     responses:
 *       200:
 *         description: Pets retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 pets:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Pet'
 */
router.get('/all', getAllPets);

/**
 * @swagger
 * /pets:
 *   get:
 *     summary: List pets with filters
 *     tags: [Pets]
 *     parameters:
 *       - in: query
 *         name: ownerId
 *         schema:
 *           type: string
 *         description: Filter by owner ID
 *       - in: query
 *         name: petType
 *         schema:
 *           type: string
 *         description: Filter by pet type
 *     responses:
 *       200:
 *         description: Pets retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 pets:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Pet'
 */
router.get('/', listPets);

/**
 * @swagger
 * /pets/{id}:
 *   get:
 *     summary: Get pet by ID
 *     tags: [Pets]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Pet ID
 *     responses:
 *       200:
 *         description: Pet retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Pet'
 *       404:
 *         description: Pet not found
 */
router.get('/:id', getPetById);

module.exports = router;

