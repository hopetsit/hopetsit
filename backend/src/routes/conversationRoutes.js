const express = require('express');
const multer = require('multer');

const {
  listConversations,
  getChatList,
  getConversationMessages,
  createConversationMessage,
  createConversationAttachmentMessage,
  markConversationRead,
  startConversation,
  startConversationBySitter,
} = require('../controllers/conversationController');
const { requireAuth, requireRole } = require('../middleware/auth');
const { requirePaidBooking } = require('../middleware/chatAccess');

const router = express.Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 15 * 1024 * 1024, // 15MB per file
    files: 5,
  },
});

/**
 * @swagger
 * /conversations/start:
 *   post:
 *     summary: Start a new conversation with a sitter (Owner only)
 *     tags: [Conversations]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: sitterId
 *         required: true
 *         schema:
 *           type: string
 *         description: Sitter ID to start conversation with
 *         example: 507f1f77bcf86cd799439011
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - message
 *             properties:
 *               message:
 *                 type: string
 *                 example: Hello, I'm interested in your services!
 *     responses:
 *       201:
 *         description: Conversation started successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: Conversation started successfully.
 *                 conversation:
 *                   $ref: '#/components/schemas/Conversation'
 *                 sentMessage:
 *                   $ref: '#/components/schemas/Message'
 *       400:
 *         description: Invalid input
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Only owners can start conversations
 *       404:
 *         description: Sitter not found
 */
router.post('/start', requireAuth, requireRole('owner'), startConversation);

/**
 * @swagger
 * /conversations/start-by-sitter:
 *   post:
 *     summary: Start a new conversation with an owner (Sitter only)
 *     tags: [Conversations]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: ownerId
 *         required: true
 *         schema:
 *           type: string
 *         description: Owner ID to start conversation with
 *         example: 507f1f77bcf86cd799439011
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - message
 *             properties:
 *               message:
 *                 type: string
 *                 example: Hello, I'm available to help with your pet!
 *     responses:
 *       201:
 *         description: Conversation started successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: Conversation started successfully.
 *                 conversation:
 *                   $ref: '#/components/schemas/Conversation'
 *                 sentMessage:
 *                   $ref: '#/components/schemas/Message'
 *       400:
 *         description: Invalid input (missing ownerId, message, or invalid ID format)
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       401:
 *         description: Unauthorized - Authentication required
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       403:
 *         description: Only sitters can start conversations with owners, or users are blocked
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       404:
 *         description: Owner or Sitter not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       409:
 *         description: Conversation already exists
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.post('/start-by-sitter', requireAuth, requireRole('sitter'), startConversationBySitter);

/**
 * @swagger
 * /conversations/list:
 *   get:
 *     summary: Get chat list for authenticated user
 *     tags: [Conversations]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Chat list retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 conversations:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Conversation'
 *                 count:
 *                   type: number
 *       401:
 *         description: Unauthorized
 */
router.get('/list', requireAuth, getChatList);

/**
 * @swagger
 * /conversations:
 *   get:
 *     summary: List conversations (requires role and userId query params)
 *     tags: [Conversations]
 *     parameters:
 *       - in: query
 *         name: role
 *         required: true
 *         schema:
 *           type: string
 *           enum: [owner, sitter]
 *         description: User role
 *       - in: query
 *         name: userId
 *         required: true
 *         schema:
 *           type: string
 *         description: User ID
 *     responses:
 *       200:
 *         description: Conversations retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 conversations:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Conversation'
 *       400:
 *         description: Invalid input
 */
router.get('/', listConversations);

/**
 * @swagger
 * /conversations/{id}/messages:
 *   get:
 *     summary: Get all messages in a conversation
 *     tags: [Conversations]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Conversation ID
 *       - in: query
 *         name: role
 *         required: true
 *         schema:
 *           type: string
 *           enum: [owner, sitter]
 *         description: User role
 *       - in: query
 *         name: userId
 *         required: true
 *         schema:
 *           type: string
 *         description: User ID
 *     responses:
 *       200:
 *         description: Messages retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 messages:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Message'
 *       403:
 *         description: Access denied
 *       404:
 *         description: Conversation not found
 */
router.get('/:id/messages', requireAuth, requirePaidBooking, getConversationMessages);

/**
 * @swagger
 * /conversations/{id}/messages:
 *   post:
 *     summary: Send a text message in a conversation
 *     tags: [Conversations]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Conversation ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - senderRole
 *               - senderId
 *               - body
 *             properties:
 *               senderRole:
 *                 type: string
 *                 enum: [owner, sitter]
 *                 example: owner
 *               senderId:
 *                 type: string
 *                 example: 507f1f77bcf86cd799439011
 *               body:
 *                 type: string
 *                 example: Hello, how are you?
 *               attachments:
 *                 type: array
 *                 items:
 *                   type: object
 *     responses:
 *       201:
 *         description: Message sent successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   $ref: '#/components/schemas/Message'
 *                 conversation:
 *                   $ref: '#/components/schemas/Conversation'
 *       400:
 *         description: Invalid input
 *       403:
 *         description: Access denied or user blocked
 */
router.post('/:id/messages', requireAuth, requirePaidBooking, createConversationMessage);

/**
 * @swagger
 * /conversations/{id}/messages/attachments:
 *   post:
 *     summary: Send a message with attachments (images/videos)
 *     tags: [Conversations]
 *     consumes:
 *       - multipart/form-data
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Conversation ID
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             required:
 *               - senderRole
 *               - senderId
 *               - files
 *             properties:
 *               senderRole:
 *                 type: string
 *                 enum: [owner, sitter]
 *               senderId:
 *                 type: string
 *               body:
 *                 type: string
 *               files:
 *                 type: array
 *                 items:
 *                   type: string
 *                   format: binary
 *               folder:
 *                 type: string
 *     responses:
 *       201:
 *         description: Message with attachments sent successfully
 *       400:
 *         description: Invalid input or no files provided
 *       403:
 *         description: Access denied
 */
router.post('/:id/messages/attachments', requireAuth, requirePaidBooking, upload.array('files', 5), createConversationAttachmentMessage);

/**
 * @swagger
 * /conversations/{id}/read:
 *   post:
 *     summary: Mark conversation as read
 *     tags: [Conversations]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Conversation ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - role
 *               - userId
 *             properties:
 *               role:
 *                 type: string
 *                 enum: [owner, sitter]
 *               userId:
 *                 type: string
 *     responses:
 *       200:
 *         description: Conversation marked as read
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 updated:
 *                   type: boolean
 *                 conversation:
 *                   $ref: '#/components/schemas/Conversation'
 *       400:
 *         description: Invalid input
 */
router.post('/:id/read', markConversationRead);

module.exports = router;

