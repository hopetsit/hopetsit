const express = require('express');
const multer = require('multer');
const { submitVisitReport, getVisitReport } = require('../controllers/visitReportController');

const {
  createBooking,
  listBookings,
  getMyBookings,
  cancelBooking,
  cancelOwnerSentBookingRequest,
  selfCancelWithRefund,
  respondBooking,
  agreeToBooking,
  createBookingPaymentIntent,
  confirmBookingPayment,
   createBookingPaypalOrder,
   captureBookingPaypalPayment,
  getBookingAgreement,
  requestCancellation,
  getPaymentStatus,
  completeBooking,
} = require('../controllers/bookingController');
const { requireAuth, requireRole } = require('../middleware/auth');
const { attachOwnerFromToken, attachUserFromToken } = require('../middleware/ownerContext');

const router = express.Router();

/**
 * @docs
 * /bookings:
 *   post:
 *     summary: Create a new booking (Owner only)
 *     tags: [Bookings]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: sitterId
 *         required: true
 *         schema:
 *           type: string
 *         description: Sitter ID to create booking with
 *         example: 507f1f77bcf86cd799439011
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
 *                 description: Array of pet IDs to include in this booking (at least one pet required)
 *                 minItems: 1
 *                 items: { type: string }
 *                 example:
 *                   - 507f1f77bcf86cd799439012
 *                   - 507f1f77bcf86cd799439013
 *               description:
 *                 type: string
 *                 example: Need pet sitting for my dog
 *               serviceDate:
 *                 type: string
 *                 format: date
 *                 description: Service date in YYYY-MM-DD format
 *                 example: 2024-12-25
 *               timeSlot:
 *                 type: string
 *                 example: Morning
 *               serviceType:
 *                 type: string
 *                 enum:
 *                   - home_visit
 *                   - dog_walking
 *                   - overnight_stay
 *                   - long_stay
 *                 description: Service type - home_visit (Pet Sitting/House Sitting), dog_walking (Dog Walking), overnight_stay (Overnight Stay), long_stay (Extended Long Stay 3+ nights)
 *                 example: home_visit
 *               duration:
 *                 type: number
 *                 description: "Duration in minutes (required for dog_walking: 30 or 60)"
 *                 example: 30
 *               basePrice:
 *                 type: number
 *                 description: Base price for the service (positive number)
 *                 example: 50
 *               addOns:
 *                 type: array
 *                 description: Optional add-ons
 *                 items:
 *                   type: object
 *                   properties:
 *                     type:
 *                       type: string
 *                       enum: [extraAnimals, medicationSpecialCare, additionalDog, lateEveningWalk]
 *                       example: extraAnimals
 *                     description:
 *                       type: string
 *                       example: Additional pet care
 *                     amount:
 *                       type: number
 *                       example: 10
 *                     currency:
 *                       type: string
 *                       example: EUR
 *               locationType:
 *                 type: string
 *                 enum: [standard, large_city]
 *                 description: "Location type for pricing (default: standard)"
 *                 example: standard
 *     responses:
 *       201:
 *         description: Booking created successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 booking:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                     ownerId:
 *                       type: string
 *                     sitterId:
 *                       type: string
 *                     petIds:
 *                       type: array
 *                       items: { type: string }
 *                       description: Array of pet IDs included in this booking
 *                     pets:
 *                       type: array
 *                       description: Full pet details (populated from petIds)
 *                       items:
 *                         type: object
 *                         properties:
 *                           id:
 *                             type: string
 *                           petName:
 *                             type: string
 *                           breed:
 *                             type: string
 *                           category:
 *                             type: string
 *                           weight:
 *                             type: string
 *                           height:
 *                             type: string
 *                           colour:
 *                             type: string
 *                           vaccination:
 *                             type: string
 *                           medicationAllergies:
 *                             type: string
 *                           avatar:
 *                             type: object
 *                     description:
 *                       type: string
 *                     date:
 *                       type: string
 *                     timeSlot:
 *                       type: string
 *                     serviceType:
 *                       type: string
 *                     duration:
 *                       type: number
 *                     status:
 *                       type: string
 *                       enum: [pending, accepted, rejected, agreed, paid, payment_failed, cancelled, refunded]
 *                     pricing:
 *                       type: object
 *                       properties:
 *                         basePrice:
 *                           type: number
 *                         addOns:
 *                           type: array
 *                         addOnsTotal:
 *                           type: number
 *                         totalPrice:
 *                           type: number
 *                         commission:
 *                           type: number
 *                         netPayout:
 *                           type: number
 *                         commissionRate:
 *                           type: number
 *                         currency:
 *                           type: string
 *                     recommendedPriceRange:
 *                       type: object
 *                       properties:
 *                         min:
 *                           type: number
 *                         max:
 *                           type: number
 *                         currency:
 *                           type: string
 *                 message:
 *                   type: string
 *                   example: Request sent successfully.
 *                 pricing:
 *                   type: object
 *                   properties:
 *                     totalPrice:
 *                       type: number
 *                     commission:
 *                       type: number
 *                     netPayout:
 *                       type: number
 *                     currency:
 *                       type: string
 *       400:
 *         description: Invalid input
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Owner context missing or blocked
 *       404:
 *         description: Owner, Sitter, or Pet not found
 */
router.post('/', requireAuth, requireRole('owner'), createBooking);

/**
 * @docs
 * /bookings:
 *   get:
 *     summary: List all bookings
 *     tags: [Bookings]
 *     parameters:
 *       - in: query
 *         name: ownerId
 *         schema:
 *           type: string
 *         description: Filter by owner ID
 *       - in: query
 *         name: sitterId
 *         schema:
 *           type: string
 *         description: Filter by sitter ID
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [pending, accepted, rejected, agreed, paid, payment_failed, cancelled, refunded]
 *         description: Filter by booking status
 *     responses:
 *       200:
 *         description: Bookings retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 bookings:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: string
 *                       ownerId:
 *                         type: string
 *                       sitterId:
 *                         type: string
 *                       petId:
 *                         type: string
 *                       petName:
 *                         type: string
 *                       description:
 *                         type: string
 *                       date:
 *                         type: string
 *                       timeSlot:
 *                         type: string
 *                       serviceType:
 *                         type: string
 *                       duration:
 *                         type: number
 *                       status:
 *                         type: string
 *                       pricing:
 *                         type: object
 *                       createdAt:
 *                         type: string
 *                       updatedAt:
 *                         type: string
 *       500:
 *         description: Server error
 */
router.get('/', listBookings);

/**
 * @docs
 * /bookings/my:
 *   get:
 *     summary: Get my bookings (Owner or Sitter) - Complete booking history with all details
 *     tags: [Bookings]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [all, pending, agreed, paid, failed, cancelled, refunded]
 *         description: Filter by booking status (default returns all non-cancelled)
 *     responses:
 *       200:
 *         description: Bookings retrieved successfully with complete details
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 bookings:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: string
 *                       status:
 *                         type: string
 *                         enum: [pending, accepted, rejected, agreed, paid, payment_failed, cancelled, refunded]
 *                       petName:
 *                         type: string
 *                         description: Pet name fetched from Pet collection (always up-to-date)
 *                       petWeight:
 *                         type: string
 *                         description: Pet weight from Pet collection
 *                       petHeight:
 *                         type: string
 *                         description: Pet height from Pet collection
 *                       petColor:
 *                         type: string
 *                         description: Pet color from Pet collection
 *                       description:
 *                         type: string
 *                       date:
 *                         type: string
 *                         format: date
 *                       timeSlot:
 *                         type: string
 *                       serviceType:
 *                         type: string
 *                         enum: [home_visit, dog_walking, overnight_stay, long_stay]
 *                       duration:
 *                         type: number
 *                         description: "Duration in minutes (for dog_walking: 30 or 60)"
 *                       otherParty:
 *                         type: object
 *                         description: Other party details (Sitter if Owner, Owner if Sitter)
 *                         properties:
 *                           id:
 *                             type: string
 *                           name:
 *                             type: string
 *                           email:
 *                             type: string
 *                           avatar:
 *                             type: string
 *                             description: Avatar URL
 *                           phone:
 *                             type: string
 *                             description: Mobile/phone number
 *                           rating:
 *                             type: number
 *                             description: Rating (0-5)
 *                           reviewsCount:
 *                             type: number
 *                             description: Number of reviews
 *                           location:
 *                             type: string
 *                             description: City (for sitter) or Address (for owner)
 *                       pricing:
 *                         type: object
 *                         properties:
 *                           totalPrice:
 *                             type: number
 *                             description: Total price owner pays
 *                           platformFee:
 *                             type: number
 *                             description: Platform commission (20%)
 *                           netPayout:
 *                             type: number
 *                             description: Amount sitter receives (80%)
 *                           currency:
 *                             type: string
 *                             example: EUR
 *                       canPay:
 *                         type: boolean
 *                         description: Whether owner can pay (status is 'agreed')
 *                       canCancel:
 *                         type: boolean
 *                         description: Whether booking can be cancelled (status is 'paid')
 *                       cancellationStatus:
 *                         type: object
 *                         nullable: true
 *                         properties:
 *                           ownerConfirmed:
 *                             type: boolean
 *                           sitterConfirmed:
 *                             type: boolean
 *                           bothConfirmed:
 *                             type: boolean
 *                       createdAt:
 *                         type: string
 *                         format: date-time
 *                       updatedAt:
 *                         type: string
 *                         format: date-time
 *                 statusCounts:
 *                   type: object
 *                   description: Count of bookings by status
 *                   properties:
 *                     all:
 *                       type: number
 *                     pending:
 *                       type: number
 *                     agreed:
 *                       type: number
 *                     paid:
 *                       type: number
 *                     failed:
 *                       type: number
 *                     cancelled:
 *                       type: number
 *                     refunded:
 *                       type: number
 *                 count:
 *                   type: number
 *                   description: Total number of bookings returned
 *       400:
 *         description: Invalid user role
 *       401:
 *         description: Unauthorized
 *       500:
 *         description: Server error
 */
router.get('/my', requireAuth, attachUserFromToken, getMyBookings);

/**
 * @docs
 * /bookings/{id}/agreement:
 *   get:
 *     summary: Get booking agreement details
 *     tags: [Bookings]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Booking ID
 *     responses:
 *       200:
 *         description: Agreement retrieved successfully
 *       401:
 *         description: Unauthorized
 *       404:
 *         description: Booking not found
 */
router.get('/:id/agreement', requireAuth, attachUserFromToken, getBookingAgreement);

/**
 * @docs
 * /bookings/{id}/payment-status:
 *   get:
 *     summary: Get booking payment status
 *     tags: [Bookings]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Booking ID
 *     responses:
 *       200:
 *         description: Payment status retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 bookingId:
 *                   type: string
 *                 status:
 *                   type: string
 *                 paymentStatus:
 *                   type: string
 *                   enum: [pending, paid, cancelled, refund]
 *                 paymentProvider:
 *                   type: string
 *                   nullable: true
 *                   enum: [stripe, paypal]
 *                 paypalOrderId:
 *                   type: string
 *                   nullable: true
 *                 paypalCaptureId:
 *                   type: string
 *                   nullable: true
 *                 paypalOrderStatus:
 *                   type: string
 *                   nullable: true
 *                 paidAt:
 *                   type: string
 *                   format: date-time
 *                   nullable: true
 *                 payoutStatus:
 *                   type: string
 *                   enum: [pending, processing, completed, failed]
 *                 payoutBatchId:
 *                   type: string
 *                   nullable: true
 *                 payoutAt:
 *                   type: string
                   format: date-time
                   nullable: true
                 message:
                   type: string
 *       401:
 *         description: Unauthorized
 *       404:
 *         description: Booking not found
 */
router.get('/:id/payment-status', requireAuth, attachUserFromToken, getPaymentStatus);

/**
 * @docs
 * /bookings/{id}/agree:
 *   put:
 *     summary: Agree to booking details (Owner or Sitter)
 *     tags: [Bookings]
 *     description: Marks a booking as 'agreed' when both parties agree on the details. Owner can then proceed with payment.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Booking ID
 *     responses:
 *       200:
 *         description: Booking marked as agreed successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 booking:
 *                   type: object
 *                   description: Updated booking with status 'agreed'
 *                 message:
 *                   type: string
 *                   example: Booking marked as agreed. Owner can now proceed with payment.
 *       400:
 *         description: Booking cannot be agreed (not in pending or accepted status)
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: User does not have permission to agree to this booking
 *       404:
 *         description: Booking not found
 */
router.put('/:id/agree', requireAuth, attachUserFromToken, agreeToBooking);

/**
 * @docs
 * /bookings/{id}/create-payment-intent:
 *   post:
 *     summary: Create Stripe PaymentIntent for booking payment (Owner only)
 *     tags: [Bookings]
 *     description: Creates a Stripe PaymentIntent for an agreed booking. Requires sitter to have active Stripe Connect account.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Booking ID
 *     responses:
 *       200:
 *         description: PaymentIntent created successfully (or existing PaymentIntent returned)
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 paymentIntentId:
 *                   type: string
 *                   description: Stripe PaymentIntent ID
 *                 clientSecret:
 *                   type: string
 *                   description: Client secret for Stripe Payment Sheet (use this in frontend)
 *                 booking:
 *                   type: object
 *                   description: Booking object
 *                 message:
 *                   type: string
 *                   example: PaymentIntent created successfully. Use clientSecret with Stripe Payment Sheet.
 *       400:
 *         description: Booking not in 'agreed' status, missing pricing, or sitter doesn't have Stripe Connect account
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Only owners can create payment intents, or owner doesn't own this booking
 *       404:
 *         description: Booking not found
 */
router.post('/:id/create-payment-intent', requireAuth, requireRole('owner'), createBookingPaymentIntent);

/**
 * @docs
 * /bookings/{id}/confirm-payment/{paymentIntentId}:
 *   post:
 *     summary: Confirm booking payment (Owner only)
 *     tags: [Bookings]
 *     description: "Confirms a Stripe PaymentIntent for booking payment. Note: Actual status updates come via webhook."
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Booking ID
 *       - in: path
 *         name: paymentIntentId
 *         required: true
 *         schema:
 *           type: string
 *         description: Stripe PaymentIntent ID
 *     requestBody:
 *       required: false
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               payment_method:
 *                 type: string
 *                 description: Payment method ID
 *               return_url:
 *                 type: string
 *                 description: Return URL for payment confirmation
 *     responses:
 *       200:
 *         description: Payment confirmation initiated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 paymentIntent:
 *                   type: object
 *                   description: Stripe PaymentIntent object
 *                 booking:
 *                   type: object
 *                   description: Updated booking object
 *       400:
 *         description: Invalid payment intent ID or booking status
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Only owners can confirm payment, or owner doesn't own this booking
 *       404:
 *         description: Booking or payment intent not found
 */
router.post('/:id/confirm-payment/:paymentIntentId', requireAuth, requireRole('owner'), confirmBookingPayment);

/**
 * @docs
 * /bookings/{id}/paypal/create-order:
 *   post:
 *     summary: Create PayPal order for booking payment (Owner only)
 *     tags: [Bookings]
 *     description: Creates a PayPal order for an agreed booking. Uses the same pricing, commission, and currency logic as Stripe.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Booking ID
 *     responses:
 *       200:
 *         description: PayPal order created successfully (or existing order returned)
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 orderId:
 *                   type: string
 *                   description: PayPal order ID
 *                 status:
 *                   type: string
 *                   description: PayPal order status
 *                 approveUrl:
 *                   type: string
 *                   nullable: true
 *                   description: URL where the owner can approve the payment (when applicable)
 *                 booking:
 *                   type: object
 *                   description: Booking object
 *                 message:
 *                   type: string
 *       400:
 *         description: Booking not in 'agreed' status or missing pricing
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Only owners can create PayPal orders, or owner doesn't own this booking
 *       404:
 *         description: Booking not found
 */
router.post('/:id/paypal/create-order', requireAuth, requireRole('owner'), createBookingPaypalOrder);

/**
 * @docs
 * /bookings/{id}/paypal/capture/{orderId}:
 *   post:
 *     summary: Capture PayPal payment for a booking (Owner only)
 *     tags: [Bookings]
 *     description: Captures an approved PayPal order and marks the booking as paid when completed.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Booking ID
 *       - in: path
 *         name: orderId
 *         required: true
 *         schema:
 *           type: string
 *         description: PayPal order ID
 *     responses:
 *       200:
 *         description: PayPal payment capture attempted
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 orderId:
 *                   type: string
 *                 status:
 *                   type: string
 *                   description: PayPal order status after capture
 *                 booking:
 *                   type: object
 *                   description: Updated booking object
 *                 message:
 *                   type: string
 *       400:
 *         description: Invalid order ID or booking status
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Only owners can capture payment, or owner doesn't own this booking
 *       404:
 *         description: Booking or order not found
 */
router.post('/:id/paypal/capture/:orderId', requireAuth, requireRole('owner'), captureBookingPaypalPayment);

/**
 * @docs
 * /bookings/{id}/request-cancellation:
 *   post:
 *     summary: Request booking cancellation (Owner or Sitter)
 *     tags: [Bookings]
 *     description: Requests cancellation of a paid booking. Both parties must confirm for cancellation to proceed.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Booking ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               reason:
 *                 type: string
 *                 description: Reason for cancellation
 *                 example: Change of plans
 *     responses:
 *       200:
 *         description: Cancellation requested successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 booking:
 *                   type: object
 *                   description: Updated booking with cancellation request
 *                 message:
 *                   type: string
 *       400:
 *         description: Booking cannot be cancelled (not paid, already cancelled, etc.)
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: User does not have permission to cancel this booking
 *       404:
 *         description: Booking not found
 */
router.post('/:id/request-cancellation', requireAuth, attachUserFromToken, requestCancellation);

/**
 * @docs
 * /bookings/{id}/cancel:
 *   delete:
 *     summary: Cancel a booking (Owner only)
 *     tags: [Bookings]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Booking ID
 *     responses:
 *       200:
 *         description: Booking cancelled successfully
 *       401:
 *         description: Unauthorized
 *       404:
 *         description: Booking not found
 */
router.delete('/:id/cancel', requireAuth, requireRole('owner'), cancelBooking);

// Self-cancel (owner OR sitter) with automatic refund if >72h before start date
router.post('/:id/self-cancel', requireAuth, selfCancelWithRefund);

/**
 * @swagger
 * /bookings/{id}/cancel-request:
 *   post:
 *     summary: Cancel an owner's sent booking request (Owner only)
 *     tags: [Bookings]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Booking ID
 *     responses:
 *       200:
 *         description: Sent booking request cancelled successfully
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Not the owner of this booking request
 *       404:
 *         description: Booking not found
 *       409:
 *         description: Booking status does not allow cancellation
 */
router.post('/:id/cancel-request', requireAuth, requireRole('owner'), cancelOwnerSentBookingRequest);

/**
 * @docs
 * /bookings/{id}/respond:
 *   post:
 *     summary: Respond to a booking request (Sitter - Accept or Reject)
 *     tags: [Bookings]
 *     description: Sitter can accept or reject a booking request. Accepting creates/updates a conversation.
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Booking ID
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
 *                 description: Action to take on the booking
 *                 example: accept
 *     responses:
 *       200:
 *         description: Response sent successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 booking:
 *                   type: object
 *                   description: Updated booking object
 *                 conversation:
 *                   type: object
 *                   description: Conversation object (only present if action is 'accept')
 *       400:
 *         description: Invalid action or booking not in pending status
 *       404:
 *         description: Booking not found
 *       409:
 *         description: Booking already responded to
 */
router.post('/:id/respond', respondBooking);

// Sprint 6 step 3 — visit report.
const visitReportUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024, files: 10 },
});
router.post(
  '/:id/visit-report',
  requireAuth,
  requireRole('sitter'),
  visitReportUpload.array('photos', 10),
  submitVisitReport
);
router.get('/:id/visit-report', requireAuth, getVisitReport);

// Sprint 7 step 1 — complete a booking (owner action) triggers loyalty.
router.post('/:id/complete', requireAuth, requireRole('owner'), completeBooking);

module.exports = router;

