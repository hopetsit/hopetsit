const express = require('express');
const multer = require('multer');

const {
  createPost,
  createPostWithMedia,
  listPosts,
  getMediaPosts,
  getRequestPosts,
  toggleLike,
  addComment,
  deleteComment,
  deletePost,
  updatePost,
} = require('../controllers/postController');
const { requireAuth, requireRole } = require('../middleware/auth');
const { attachOwnerFromToken } = require('../middleware/ownerContext');

const router = express.Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 25 * 1024 * 1024, // 25MB
  },
});

const postMediaUpload = upload.fields([
  { name: 'image', maxCount: 10 },
  { name: 'images', maxCount: 10 },
  { name: 'photo', maxCount: 10 },
  { name: 'photos', maxCount: 10 },
  { name: 'video', maxCount: 10 },
  { name: 'videos', maxCount: 10 },
  { name: 'file', maxCount: 10 },
  { name: 'media', maxCount: 10 },
]);

/**
 * @swagger
 * /posts:
 *   post:
 *     summary: Create a new post (Owner only)
 *     tags: [Posts]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - body
 *             properties:
 *               body:
 *                 type: string
 *                 description: Main text content of the post
 *                 example: Looking for a sitter this weekend.
 *               startDate:
 *                 type: string
 *                 format: date-time
 *                 description: Start date of the requested service (ISO string)
 *                 example: 2026-03-01T09:00:00.000Z
 *               endDate:
 *                 type: string
 *                 format: date-time
 *                 description: End date of the requested service (ISO string)
 *                 example: 2026-03-05T18:00:00.000Z
 *               serviceTypes:
 *                 type: array
 *                 description: List of requested services
 *                 items:
 *                   type: string
 *                   example: walking
 *                 example: [walking, boarding, daycare]
 *               houseSittingVenue:
 *                 type: string
 *                 enum: [owners_home, sitters_home]
 *                 description: Required when serviceTypes includes house_sitting
 *                 example: owners_home
 *               petId:
 *                 type: string
 *                 description: ID of the pet this post is about
 *                 example: 661234abcd1234abcd1234ef
 *               location:
 *                 type: object
 *                 description: Optional location information related to this post
 *                 properties:
 *                   city:
 *                     type: string
 *                     example: Berlin
 *                   lat:
 *                     type: number
 *                     example: 52.52
 *                   lng:
 *                     type: number
 *                     example: 13.405
 *               notes:
 *                 type: string
 *                 description: Additional notes or special instructions
 *                 example: My dog is friendly with other dogs.
 *     responses:
 *       201:
 *         description: Post created successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Post'
 *       400:
 *         description: Invalid input
 *       401:
 *         description: Unauthorized
 */
router.post('/', requireAuth, requireRole('owner'), createPost);

/**
 * @swagger
 * /posts/with-media:
 *   post:
 *     summary: Create a post with media attachments (Owner only)
 *     tags: [Posts]
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
 *             properties:
 *               body:
 *                 type: string
 *                 description: Caption / description for the media post
 *                 example: My cat playing in the garden!
 *               startDate:
 *                 type: string
 *                 format: date-time
 *                 description: Start date of the requested service (ISO string)
 *                 example: 2026-03-01T09:00:00.000Z
 *               endDate:
 *                 type: string
 *                 format: date-time
 *                 description: End date of the requested service (ISO string)
 *                 example: 2026-03-05T18:00:00.000Z
 *               serviceTypes:
 *                 type: array
 *                 description: List of requested services
 *                 items:
 *                   type: string
 *                   example: walking
 *                 example: [walking, boarding, daycare]
 *               houseSittingVenue:
 *                 type: string
 *                 enum: [owners_home, sitters_home]
 *                 description: Required when serviceTypes includes house_sitting
 *                 example: sitters_home
 *               petId:
 *                 type: string
 *                 description: ID of the pet this post is about
 *                 example: 661234abcd1234abcd1234ef
 *               location:
 *                 type: object
 *                 description: Optional location information related to this post
 *                 properties:
 *                   city:
 *                     type: string
 *                     example: Berlin
 *                   lat:
 *                     type: number
 *                     example: 52.52
 *                   lng:
 *                     type: number
 *                     example: 13.405
 *               notes:
 *                 type: string
 *                 description: Additional notes or special instructions
 *                 example: Prefer sitter experienced with senior dogs.
 *               image:
 *                 type: array
 *                 items:
 *                   type: string
 *                   format: binary
 *               video:
 *                 type: array
 *                 items:
 *                   type: string
 *                   format: binary
 *     responses:
 *       201:
 *         description: Post with media created successfully
 *       400:
 *         description: Invalid input
 *       401:
 *         description: Unauthorized
 */
router.post('/with-media', requireAuth, requireRole('owner'), postMediaUpload, createPostWithMedia);

/**
 * @swagger
 * /posts/media:
 *   get:
 *     summary: Get all media posts
 *     tags: [Posts]
 *     responses:
 *       200:
 *         description: Media posts retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 posts:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Post'
 */
router.get('/media', getMediaPosts);

/**
 * @swagger
 * /posts/requests:
 *   get:
 *     summary: Get all request posts
 *     tags: [Posts]
 *     responses:
 *       200:
 *         description: Request posts retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 posts:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Post'
 */
router.get('/requests', getRequestPosts);

/**
 * @swagger
 * /posts:
 *   get:
 *     summary: List all posts
 *     tags: [Posts]
 *     parameters:
 *       - in: query
 *         name: type
 *         schema:
 *           type: string
 *           enum: [media, request]
 *         description: Filter by post type
 *       - in: query
 *         name: ownerId
 *         schema:
 *           type: string
 *         description: Filter by owner ID
 *     responses:
 *       200:
 *         description: Posts retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 posts:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Post'
 */
router.get('/', listPosts);

/**
 * @swagger
 * /posts/my:
 *   get:
 *     summary: Get my posts (Owner only)
 *     tags: [Posts]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Posts retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 posts:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Post'
 *       401:
 *         description: Unauthorized
 */
router.get('/my', requireAuth, attachOwnerFromToken, listPosts);

/**
 * @swagger
 * /posts/{id}:
 *   delete:
 *     summary: Delete a post (Owner only - own post)
 *     tags: [Posts]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Post ID
 *     responses:
 *       200:
 *         description: Post deleted successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: Post deleted successfully.
 *                 postId:
 *                   type: string
 *       400:
 *         description: Invalid post id
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Only owners can delete posts, and only their own posts
 *       404:
 *         description: Post not found
 */
router.delete('/:id', requireAuth, requireRole('owner'), deletePost);

// Edit own post - owner only, whitelisted fields
router.put('/:id', requireAuth, requireRole('owner'), updatePost);
router.patch('/:id', requireAuth, requireRole('owner'), updatePost);

/**
 * @swagger
 * /posts/{id}/like:
 *   post:
 *     summary: Like a post
 *     tags: [Posts]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Post ID
 *     responses:
 *       200:
 *         description: Post liked successfully
 *       401:
 *         description: Unauthorized
 *       404:
 *         description: Post not found
 */
router.post('/:id/like', requireAuth, toggleLike);

/**
 * @swagger
 * /posts/{id}/dislike:
 *   post:
 *     summary: Dislike a post (remove like)
 *     tags: [Posts]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Post ID
 *     responses:
 *       200:
 *         description: Like removed successfully
 *       401:
 *         description: Unauthorized
 *       404:
 *         description: Post not found
 */
router.post('/:id/dislike', requireAuth, toggleLike);

/**
 * @swagger
 * /posts/{id}/comments:
 *   post:
 *     summary: Add a comment to a post
 *     tags: [Posts]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Post ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - comment
 *             properties:
 *               comment:
 *                 type: string
 *                 example: Great post!
 *     responses:
 *       201:
 *         description: Comment added successfully
 *       401:
 *         description: Unauthorized
 *       404:
 *         description: Post not found
 */
router.post('/:id/comments', requireAuth, addComment);

/**
 * @swagger
 * /posts/{id}/comments/{commentId}:
 *   delete:
 *     summary: Delete a comment from a post
 *     tags: [Posts]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Post ID
 *       - in: path
 *         name: commentId
 *         required: true
 *         schema:
 *           type: string
 *         description: Comment ID
 *     responses:
 *       200:
 *         description: Comment deleted successfully
 *       404:
 *         description: Post or comment not found
 */
router.delete('/:id/comments/:commentId', deleteComment);

module.exports = router;

