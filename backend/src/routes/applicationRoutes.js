const express = require('express');

const {
  createApplication,
  listApplications,
  respondToApplication,
  cancelApplication,
  cancelSitterSentApplicationRequest,
} = require('../controllers/applicationController');
const { requireAuth, requireRole } = require('../middleware/auth');
const { attachOwnerFromToken, attachUserFromToken } = require('../middleware/ownerContext');

const router = express.Router();

/**
 * @swagger
 * /applications:
 *   post:
 *     summary: Create a sitter request to owner with booking-ready details (Sitter only)
 *     tags: [Applications]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: ownerId
 *         required: true
 *         schema:
 *           type: string
 *         description: Owner ID to whom the sitter is sending the request
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - petIds
 *               - serviceDate
 *               - timeSlot
 *               - serviceType
 *               - basePrice
 *             properties:
 *               petIds:
 *                 type: array
 *                 items:
 *                   type: string
 *                 description: Pet IDs belonging to the owner
 *                 example: ["507f1f77bcf86cd799439011"]
 *               serviceDate:
 *                 type: string
 *                 format: date-time
 *                 example: 2026-03-25T10:00:00.000Z
 *               startDate:
 *                 type: string
 *                 format: date-time
 *                 nullable: true
 *                 example: 2026-03-25T10:00:00.000Z
 *               endDate:
 *                 type: string
 *                 format: date-time
 *                 nullable: true
 *                 example: 2026-03-27T10:00:00.000Z
 *               timeSlot:
 *                 type: string
 *                 example: Morning
 *               serviceType:
 *                 type: string
 *                 enum: [home_visit, dog_walking, overnight_stay, long_stay]
 *                 example: overnight_stay
 *               duration:
 *                 type: number
 *                 description: Required for dog_walking (30 or 60)
 *                 example: 30
 *               basePrice:
 *                 type: number
 *                 example: 100
 *               addOns:
 *                 type: array
 *                 items:
 *                   type: object
 *                   properties:
 *                     type:
 *                       type: string
 *                     description:
 *                       type: string
 *                     amount:
 *                       type: number
 *                 example: []
 *               locationType:
 *                 type: string
 *                 enum: [standard, large_city]
 *                 example: standard
 *               houseSittingVenue:
 *                 type: string
 *                 enum: [owners_home, sitters_home]
 *                 description: Required when serviceType is house_sitting
 *                 example: owners_home
 *               description:
 *                 type: string
 *                 example: I can take care of your pet during these dates.
 *     responses:
 *       201:
 *         description: Application created successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Application'
 *       400:
 *         description: Invalid input
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Only sitters can create applications
 *       200:
 *         description: Duplicate-click prevented. Existing pending request returned.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 duplicatePrevented:
 *                   type: boolean
 *                   example: true
 *                 message:
 *                   type: string
 *                 application:
 *                   $ref: '#/components/schemas/Application'
 */
router.post('/', requireAuth, requireRole('sitter'), createApplication);

/**
 * @swagger
 * /applications:
 *   get:
 *     summary: List all applications
 *     tags: [Applications]
 *     parameters:
 *       - in: query
 *         name: bookingId
 *         schema:
 *           type: string
 *         description: Filter by booking ID
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [pending, accepted, rejected]
 *         description: Filter by status
 *     responses:
 *       200:
 *         description: Applications retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 applications:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Application'
 */
router.get('/', listApplications);

/**
 * @swagger
 * /applications/my:
 *   get:
 *     summary: Get my applications (Owner or Sitter)
 *     tags: [Applications]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Applications retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 applications:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Application'
 *       401:
 *         description: Unauthorized
 */
router.get('/my', requireAuth, attachUserFromToken, listApplications);

/**
 * @swagger
 * /applications/{id}/respond:
 *   post:
 *     summary: Respond to an application (Owner only)
 *     tags: [Applications]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Application ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - action
 *             properties:
 *               action:
 *                 type: string
 *                 enum: [accept, reject]
 *                 example: accept
 *     responses:
 *       200:
 *         description: Response sent successfully. On accept, an agreed booking is auto-created.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 application:
 *                   $ref: '#/components/schemas/Application'
 *                 booking:
 *                   $ref: '#/components/schemas/Booking'
 *                 conversation:
 *                   $ref: '#/components/schemas/Conversation'
 *       400:
 *         description: Invalid input
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Only owners can respond to applications
 *       404:
 *         description: Application not found
 */
router.post('/:id/respond', requireAuth, requireRole('owner'), respondToApplication);

/**
 * @swagger
 * /applications/{id}:
 *   delete:
 *     summary: Cancel an application
 *     tags: [Applications]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Application ID
 *     responses:
 *       200:
 *         description: Application cancelled successfully
 *       404:
 *         description: Application not found
 */
router.delete('/:id', cancelApplication);

/**
 * @swagger
 * /applications/{id}/cancel-request:
 *   post:
 *     summary: Cancel a sitter's own sent request (Sitter only)
 *     tags: [Applications]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Application ID
 *     responses:
 *       200:
 *         description: Sent request cancelled successfully
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Not the owner of this request
 *       404:
 *         description: Application not found
 *       409:
 *         description: Request already accepted/rejected and cannot be cancelled
 */
router.post('/:id/cancel-request', requireAuth, requireRole('sitter'), cancelSitterSentApplicationRequest);

module.exports = router;

