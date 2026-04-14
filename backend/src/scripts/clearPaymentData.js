/**
 * Clear payment data from all bookings
 * This script removes Stripe payment information so bookings can be tested again
 * 
 * Usage: node src/scripts/clearPaymentData.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const Booking = require('../models/Booking');
const logger = require('../utils/logger');

async function clearPaymentData() {
  try {
    // Connect to MongoDB
    await mongoose.connect(process.env.MONGODB_URI);
    logger.info('✅ Connected to MongoDB\n');

    // Find all bookings with payment data
    const bookings = await Booking.find({
      $or: [
        { stripePaymentIntentId: { $ne: null } },
        { stripeChargeId: { $ne: null } },
        { petsitterConnectedAccountId: { $ne: null } },
        { paidAt: { $ne: null } },
        { paymentFailedAt: { $ne: null } },
        { status: { $in: ['paid', 'payment_failed', 'refunded'] } },
      ],
    });

    logger.info(`📊 Found ${bookings.length} bookings with payment data\n`);

    if (bookings.length === 0) {
      logger.info('✅ No bookings with payment data found!');
      await mongoose.connection.close();
      return;
    }

    let updatedCount = 0;
    let skippedCount = 0;

    for (const booking of bookings) {
      try {
        const updates = {};
        let hasChanges = false;

        // Clear Stripe payment IDs
        if (booking.stripePaymentIntentId) {
          updates.stripePaymentIntentId = null;
          hasChanges = true;
        }

        if (booking.stripeChargeId) {
          updates.stripeChargeId = null;
          hasChanges = true;
        }

        if (booking.petsitterConnectedAccountId) {
          updates.petsitterConnectedAccountId = null;
          hasChanges = true;
        }

        // Clear payment timestamps
        if (booking.paidAt) {
          updates.paidAt = null;
          hasChanges = true;
        }

        if (booking.paymentFailedAt) {
          updates.paymentFailedAt = null;
          hasChanges = true;
        }

        // Reset status if it's a payment-related status
        // Only reset if status is paid, payment_failed, or refunded
        // Keep other statuses like 'agreed', 'pending', etc.
        if (['paid', 'payment_failed', 'refunded'].includes(booking.status)) {
          // Reset to 'agreed' if it was agreed before, otherwise keep current status
          // For testing purposes, set to 'agreed' so payment can be initiated again
          if (booking.agreedAt) {
            updates.status = 'agreed';
          } else if (booking.acceptedAt) {
            updates.status = 'accepted';
          } else {
            updates.status = 'pending';
          }
          hasChanges = true;
        }

        // Update booking if there are changes
        if (hasChanges) {
          await Booking.findByIdAndUpdate(
            booking._id,
            { $set: updates },
            { runValidators: false }
          );
          
          logger.info(`  ✅ Booking ${booking._id}:`);
          if (updates.stripePaymentIntentId === null) logger.info(`     - Cleared stripePaymentIntentId`);
          if (updates.stripeChargeId === null) logger.info(`     - Cleared stripeChargeId`);
          if (updates.petsitterConnectedAccountId === null) logger.info(`     - Cleared petsitterConnectedAccountId`);
          if (updates.paidAt === null) logger.info(`     - Cleared paidAt`);
          if (updates.paymentFailedAt === null) logger.info(`     - Cleared paymentFailedAt`);
          if (updates.status) logger.info(`     - Status reset to: ${updates.status}`);
          
          updatedCount++;
        } else {
          skippedCount++;
        }
      } catch (error) {
        logger.error(`  ❌ Error updating booking ${booking._id}:`, error.message);
      }
    }

    logger.info(`\n✅ Clear payment data complete!`);
    logger.info(`   - Updated: ${updatedCount} bookings`);
    logger.info(`   - Skipped: ${skippedCount} bookings`);
    logger.info(`\n💡 All bookings are now ready for payment testing.\n`);

    await mongoose.connection.close();
    logger.info('✅ Database connection closed');
  } catch (error) {
    logger.error('❌ Error:', error);
    await mongoose.connection.close();
    process.exit(1);
  }
}

// Run the script
clearPaymentData();

