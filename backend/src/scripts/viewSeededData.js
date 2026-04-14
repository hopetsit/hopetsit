/**
 * View Seeded Pricing Data
 * 
 * This script displays all the seeded pricing data in a readable format
 */

require('dotenv').config();
const mongoose = require('mongoose');

const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Booking = require('../models/Booking');
const logger = require('../utils/logger');

const MONGODB_URI = process.env.MONGODB_URI;

async function viewSeededData() {
  try {
    logger.info('🔌 Connecting to MongoDB...');
    await mongoose.connect(MONGODB_URI);
    logger.info('✅ Connected to MongoDB\n');

    // View Sitters with Pricing
    logger.info('═══════════════════════════════════════════════════════════════');
    logger.info('📋 SITTERS WITH PRICING DATA');
    logger.info('═══════════════════════════════════════════════════════════════\n');

    const sitters = await Sitter.find({
      $or: [
        { 'location.locationType': { $exists: true } },
        { 'servicePricing.homeVisit.basePrice': { $exists: true } },
      ],
    }).sort({ createdAt: -1 });

    if (sitters.length === 0) {
      logger.info('⚠️  No sitters with pricing data found.\n');
    } else {
      sitters.forEach((sitter, index) => {
        logger.info(`${index + 1}. ${sitter.name} (${sitter.email})`);
        logger.info(`   Location: ${sitter.location?.city || 'N/A'} (${sitter.location?.locationType || 'N/A'})`);
        logger.info(`   Service: ${Array.isArray(sitter.service) ? sitter.service.join(', ') : sitter.service || 'N/A'}`);
        logger.info('   Pricing:');
        
        if (sitter.servicePricing?.homeVisit?.basePrice) {
          logger.info(`     - Home Visit: ${sitter.servicePricing.homeVisit.basePrice}€`);
        }
        if (sitter.servicePricing?.dogWalking30?.basePrice) {
          logger.info(`     - Dog Walking (30min): ${sitter.servicePricing.dogWalking30.basePrice}€`);
        }
        if (sitter.servicePricing?.dogWalking60?.basePrice) {
          logger.info(`     - Dog Walking (60min): ${sitter.servicePricing.dogWalking60.basePrice}€`);
        }
        if (sitter.servicePricing?.overnightStay?.basePrice) {
          logger.info(`     - Overnight Stay: ${sitter.servicePricing.overnightStay.basePrice}€`);
        }
        if (sitter.servicePricing?.longStay?.basePrice) {
          logger.info(`     - Long Stay (3+ nights): ${sitter.servicePricing.longStay.basePrice}€`);
        }
        logger.info('');
      });
    }

    // View Bookings with Pricing
    logger.info('═══════════════════════════════════════════════════════════════');
    logger.info('📋 BOOKINGS WITH PRICING BREAKDOWN');
    logger.info('═══════════════════════════════════════════════════════════════\n');

    const bookings = await Booking.find({
      'pricing.totalPrice': { $exists: true },
    })
      .populate('ownerId', 'name email')
      .populate('sitterId', 'name email')
      .sort({ createdAt: -1 });

    if (bookings.length === 0) {
      logger.info('⚠️  No bookings with pricing data found.\n');
    } else {
      bookings.forEach((booking, index) => {
        logger.info(`${index + 1}. Booking for ${booking.petName}`);
        logger.info(`   Owner: ${booking.ownerId?.name || 'N/A'} (${booking.ownerId?.email || 'N/A'})`);
        logger.info(`   Sitter: ${booking.sitterId?.name || 'N/A'} (${booking.sitterId?.email || 'N/A'})`);
        logger.info(`   Service: ${booking.serviceType || 'N/A'}`);
        const isNightBased =
          booking.serviceType === 'overnight_stay' || booking.serviceType === 'long_stay';
        logger.info(
          `   Duration: ${booking.duration || 'N/A'} ${isNightBased ? 'night(s)' : 'minute(s)'}`
        );
        logger.info(`   Location Type: ${booking.locationType || 'N/A'}`);
        logger.info(`   Status: ${booking.status || 'N/A'}`);
        logger.info(`   Date: ${booking.date || 'N/A'} at ${booking.timeSlot || 'N/A'}`);
        
        if (booking.pricing) {
          logger.info('   💰 Pricing Breakdown:');
          logger.info(`      Base Price: ${booking.pricing.basePrice}€`);
          
          if (booking.pricing.addOns && booking.pricing.addOns.length > 0) {
            logger.info(`      Add-ons:`);
            booking.pricing.addOns.forEach((addOn) => {
              logger.info(`        - ${addOn.description || addOn.type}: ${addOn.amount}€`);
            });
            logger.info(`      Add-ons Total: ${booking.pricing.addOnsTotal}€`);
          }
          
          logger.info(`      Total Price (Owner pays): ${booking.pricing.totalPrice}€`);
          logger.info(`      Platform Commission (20%): ${booking.pricing.commission}€`);
          logger.info(`      Net Payout (Sitter receives): ${booking.pricing.netPayout}€`);
        }
        
        if (booking.recommendedPriceRange) {
          logger.info(`   📊 Recommended Range: ${booking.recommendedPriceRange.min}€ - ${booking.recommendedPriceRange.max}€`);
        }
        
        logger.info('');
      });
    }

    // Summary Statistics
    logger.info('═══════════════════════════════════════════════════════════════');
    logger.info('📊 SUMMARY STATISTICS');
    logger.info('═══════════════════════════════════════════════════════════════\n');

    const totalBookings = bookings.length;
    const totalRevenue = bookings.reduce((sum, b) => sum + (b.pricing?.totalPrice || 0), 0);
    const totalCommission = bookings.reduce((sum, b) => sum + (b.pricing?.commission || 0), 0);
    const totalPayout = bookings.reduce((sum, b) => sum + (b.pricing?.netPayout || 0), 0);

    logger.info(`Total Sitters with Pricing: ${sitters.length}`);
    logger.info(`Total Bookings: ${totalBookings}`);
    logger.info(`Total Revenue (Owner payments): ${totalRevenue.toFixed(2)}€`);
    logger.info(`Total Commission (Platform): ${totalCommission.toFixed(2)}€`);
    logger.info(`Total Payout (Sitters): ${totalPayout.toFixed(2)}€`);
    logger.info(`Commission Rate: 20%`);
    logger.info('');

    await mongoose.connection.close();
    logger.info('🔌 Database connection closed');
    process.exit(0);
  } catch (error) {
    logger.error('❌ Error viewing data:', error);
    await mongoose.connection.close();
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  viewSeededData();
}

module.exports = { viewSeededData };

