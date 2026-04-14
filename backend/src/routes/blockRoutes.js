const express = require('express');

const { blockUser, unblockUser, listBlocked } = require('../controllers/blockController');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

/**
 * @swagger
 * /blocks:
 *   get:
 *     summary: List blocked users (Owner only)
 *     tags: [Blocks]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Blocked users retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 blocked:
 *                   type: array
 *                   items:
 *                     type: object
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Only owners can access this endpoint
 */
router.get('/', requireAuth, listBlocked);

/**
 * @swagger
 * /blocks:
 *   post:
 *     summary: Block a user (Owner only)
 *     tags: [Blocks]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - sitterId
 *             properties:
 *               sitterId:
 *                 type: string
 *                 example: 507f1f77bcf86cd799439011
 *     responses:
 *       200:
 *         description: User blocked successfully
 *       400:
 *         description: Invalid input
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Only owners can block users
 */
router.post('/', requireAuth, blockUser);

/**
 * @swagger
 * /blocks:
 *   delete:
 *     summary: Unblock a user (Owner only)
 *     tags: [Blocks]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - sitterId
 *             properties:
 *               sitterId:
 *                 type: string
 *                 example: 507f1f77bcf86cd799439011
 *     responses:
 *       200:
 *         description: User unblocked successfully
 *       400:
 *         description: Invalid input
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Only owners can unblock users
 */
router.delete('/', requireAuth, unblockUser);

// Convenience: DELETE /blocks/:id unblocks a user by id (role inferred
// as opposite of caller's role under unblockUser).
router.delete('/:id', requireAuth, (req, res, next) => {
  req.body = { ...(req.body || {}), sitterId: req.params.id, ownerId: req.params.id };
  return unblockUser(req, res, next);
});

module.exports = router;
