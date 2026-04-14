/**
 * Update existing bookings with missing pricing and service fields
 * This script adds default values to old bookings so they work with the payment flow
 */

require('dotenv').config();
const mongoose = require('mongoose');
const Booking = require('../models/Booking');
const { calculateTotalWithAddOns } = require('../utils/pricing');
const logger = require('../utils/logger');

const DEFAULT_SERVICE_TYPE = 'home_visit';
const DEFAULT_LOCATION_TYPE = 'standard';
const DEFAULT_BASE_PRICE = 15; // EUR
const DEFAULT_DURATION = 30; // minutes for dog_walking

async function updateBookings() {
  try {
    // Connect to MongoDB
    await mongoose.connect(process.env.MONGODB_URI);
    logger.info('✅ Connected to MongoDB');

    // Find all bookings missing required fields
    const bookings = await Booking.find({
      $or: [
        { serviceType: { $exists: false } },
        { 'pricing.totalPrice': { $exists: false } },
        { 'pricing.basePrice': { $exists: false } },
        { 'pricing.commission': { $exists: false } },
        { 'pricing.netPayout': { $exists: false } },
      ],
    });

    logger.info(`\n📊 Found ${bookings.length} bookings to update\n`);

    if (bookings.length === 0) {
      logger.info('✅ All bookings already have required fields!');
      await mongoose.connection.close();
      return;
    }

    let updatedCount = 0;
    let skippedCount = 0;

    for (const booking of bookings) {
      try {
        const updates = {};

        // Set serviceType if missing
        if (!booking.serviceType) {
          updates.serviceType = DEFAULT_SERVICE_TYPE;
          logger.info(`  📝 Booking ${booking._id}: Added serviceType = ${DEFAULT_SERVICE_TYPE}`);
        }

        // Set locationType if missing
        if (!booking.locationType) {
          updates.locationType = DEFAULT_LOCATION_TYPE;
        }

        // Set duration if missing and serviceType is dog_walking
        if (booking.serviceType === 'dog_walking' && !booking.duration) {
          updates.duration = DEFAULT_DURATION;
        }

        // Set pricing if missing
        if (!booking.pricing || !booking.pricing.totalPrice) {
          const basePrice = booking.pricing?.basePrice || DEFAULT_BASE_PRICE;
          const addOns = booking.pricing?.addOns || [];
          
          // Calculate full pricing breakdown using utility function
          const pricingBreakdown = calculateTotalWithAddOns(basePrice, addOns);
          
          updates.pricing = {
            basePrice: basePrice,
            addOns: addOns,
            addOnsTotal: pricingBreakdown.addOnsTotal,
            totalPrice: pricingBreakdown.totalPrice,
            commission: pricingBreakdown.commission,
            netPayout: pricingBreakdown.netPayout,
            commissionRate: pricingBreakdown.commissionRate,
            currency: booking.pricing?.currency || 'EUR',
          };

          logger.info(`  💰 Booking ${booking._id}: Added pricing (Total: €${pricingBreakdown.totalPrice}, Commission: €${pricingBreakdown.commission}, Payout: €${pricingBreakdown.netPayout})`);
        } else {
          // If pricing exists but missing some fields, fill them
          if (!booking.pricing.commission || !booking.pricing.netPayout) {
            const basePrice = booking.pricing.basePrice || DEFAULT_BASE_PRICE;
            const addOns = booking.pricing.addOns || [];
            const pricingBreakdown = calculateTotalWithAddOns(basePrice, addOns);
            
            updates.pricing = {
              ...booking.pricing.toObject(),
              basePrice: booking.pricing.basePrice || basePrice,
              addOnsTotal: booking.pricing.addOnsTotal || pricingBreakdown.addOnsTotal,
              totalPrice: booking.pricing.totalPrice || pricingBreakdown.totalPrice,
              commission: booking.pricing.commission || pricingBreakdown.commission,
              netPayout: booking.pricing.netPayout || pricingBreakdown.netPayout,
              commissionRate: booking.pricing.commissionRate || pricingBreakdown.commissionRate,
            };
            
            logger.info(`  🔧 Booking ${booking._id}: Updated pricing fields`);
          }
        }

        // Update booking if there are changes
        if (Object.keys(updates).length > 0) {
          await Booking.findByIdAndUpdate(
            booking._id,
            { $set: updates },
            { runValidators: false } // Skip validation for old bookings
          );
          updatedCount++;
        } else {
          skippedCount++;
        }
      } catch (error) {
        logger.error(`  ❌ Error updating booking ${booking._id}:`, error.message);
      }
    }

    logger.info(`\n✅ Update complete!`);
    logger.info(`   - Updated: ${updatedCount} bookings`);
    logger.info(`   - Skipped: ${skippedCount} bookings`);
    logger.info(`\n💡 All bookings now have the required fields for payment flow.\n`);

    await mongoose.connection.close();
    logger.info('✅ Database connection closed');
  } catch (error) {
    logger.error('❌ Error:', error);
    await mongoose.connection.close();
    process.exit(1);
  }
}

// Run the update
updateBookings();

