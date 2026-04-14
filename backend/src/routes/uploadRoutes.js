const express = require('express');
const multer = require('multer');

const { uploadToCloudinary, uploadFormDataToCloudinary } = require('../controllers/uploadController');

const router = express.Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB
  },
});

/**
 * @swagger
 * /uploads:
 *   post:
 *     summary: Upload file to Cloudinary (base64)
 *     tags: [Uploads]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - file
 *             properties:
 *               file:
 *                 type: string
 *                 format: base64
 *                 description: Base64 encoded file
 *               folder:
 *                 type: string
 *                 example: petsinsta/uploads
 *               resourceType:
 *                 type: string
 *                 enum: [auto, image, video]
 *                 example: auto
 *     responses:
 *       201:
 *         description: File uploaded successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 url:
 *                   type: string
 *                 publicId:
 *                   type: string
 *                 resourceType:
 *                   type: string
 *       400:
 *         description: Invalid input
 */
router.post('/', uploadToCloudinary);

/**
 * @swagger
 * /uploads/form-data:
 *   post:
 *     summary: Upload file to Cloudinary (multipart/form-data)
 *     tags: [Uploads]
 *     consumes:
 *       - multipart/form-data
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             required:
 *               - file
 *             properties:
 *               file:
 *                 type: string
 *                 format: binary
 *                 description: File to upload
 *               folder:
 *                 type: string
 *                 example: petsinsta/uploads
 *               resourceType:
 *                 type: string
 *                 enum: [auto, image, video]
 *                 example: auto
 *     responses:
 *       201:
 *         description: File uploaded successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 url:
 *                   type: string
 *                 publicId:
 *                   type: string
 *                 resourceType:
 *                   type: string
 *       400:
 *         description: Invalid input or missing file
 */
router.post('/form-data', upload.single('file'), uploadFormDataToCloudinary);

module.exports = router;

