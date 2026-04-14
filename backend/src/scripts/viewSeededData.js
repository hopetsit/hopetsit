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

const MONGODB_URI = process.env.MONGODB_URI;

async function viewSeededData() {
  try {
    console.log('🔌 Connecting to MongoDB...');
    await mongoose.connect(MONGODB_URI);
    console.log('✅ Connected to MongoDB\n');

    // View Sitters with Pricing
    console.log('═══════════════════════════════════════════════════════════════');
    console.log('📋 SITTERS WITH PRICING DATA');
    console.log('═══════════════════════════════════════════════════════════════\n');

    const sitters = await Sitter.find({
      $or: [
        { 'location.locationType': { $exists: true } },
        { 'servicePricing.homeVisit.basePrice': { $exists: true } },
      ],
    }).sort({ createdAt: -1 });

    if (sitters.length === 0) {
      console.log('⚠️  No sitters with pricing data found.\n');
    } else {
      sitters.forEach((sitter, index) => {
        console.log(`${index + 1}. ${sitter.name} (${sitter.email})`);
        console.log(`   Location: ${sitter.location?.city || 'N/A'} (${sitter.location?.locationType || 'N/A'})`);
        console.log(`   Service: ${Array.isArray(sitter.service) ? sitter.service.join(', ') : sitter.service || 'N/A'}`);
        console.log('   Pricing:');
        
        if (sitter.servicePricing?.homeVisit?.basePrice) {
          console.log(`     - Home Visit: ${sitter.servicePricing.homeVisit.basePrice}€`);
        }
        if (sitter.servicePricing?.dogWalking30?.basePrice) {
          console.log(`     - Dog Walking (30min): ${sitter.servicePricing.dogWalking30.basePrice}€`);
        }
        if (sitter.servicePricing?.dogWalking60?.basePrice) {
          console.log(`     - Dog Walking (60min): ${sitter.servicePricing.dogWalking60.basePrice}€`);
        }
        if (sitter.servicePricing?.overnightStay?.basePrice) {
          console.log(`     - Overnight Stay: ${sitter.servicePricing.overnightStay.basePrice}€`);
        }
        if (sitter.servicePricing?.longStay?.basePrice) {
          console.log(`     - Long Stay (3+ nights): ${sitter.servicePricing.longStay.basePrice}€`);
        }
        console.log('');
      });
    }

    // View Bookings with Pricing
    console.log('═══════════════════════════════════════════════════════════════');
    console.log('📋 BOOKINGS WITH PRICING BREAKDOWN');
    console.log('═══════════════════════════════════════════════════════════════\n');

    const bookings = await Booking.find({
      'pricing.totalPrice': { $exists: true },
    })
      .populate('ownerId', 'name email')
      .populate('sitterId', 'name email')
      .sort({ createdAt: -1 });

    if (bookings.length === 0) {
      console.log('⚠️  No bookings with pricing data found.\n');
    } else {
      bookings.forEach((booking, index) => {
        console.log(`${index + 1}. Booking for ${booking.petName}`);
        console.log(`   Owner: ${booking.ownerId?.name || 'N/A'} (${booking.ownerId?.email || 'N/A'})`);
        console.log(`   Sitter: ${booking.sitterId?.name || 'N/A'} (${booking.sitterId?.email || 'N/A'})`);
        console.log(`   Service: ${booking.serviceType || 'N/A'}`);
        const isNightBased =
          booking.serviceType === 'overnight_stay' || booking.serviceType === 'long_stay';
        console.log(
          `   Duration: ${booking.duration || 'N/A'} ${isNightBased ? 'night(s)' : 'minute(s)'}`
        );
        console.log(`   Location Type: ${booking.locationType || 'N/A'}`);
        console.log(`   Status: ${booking.status || 'N/A'}`);
        console.log(`   Date: ${booking.date || 'N/A'} at ${booking.timeSlot || 'N/A'}`);
        
        if (booking.pricing) {
          console.log('   💰 Pricing Breakdown:');
          console.log(`      Base Price: ${booking.pricing.basePrice}€`);
          
          if (booking.pricing.addOns && booking.pricing.addOns.length > 0) {
            console.log(`      Add-ons:`);
            booking.pricing.addOns.forEach((addOn) => {
              console.log(`        - ${addOn.description || addOn.type}: ${addOn.amount}€`);
            });
            console.log(`      Add-ons Total: ${booking.pricing.addOnsTotal}€`);
          }
          
          console.log(`      Total Price (Owner pays): ${booking.pricing.totalPrice}€`);
          console.log(`      Platform Commission (20%): ${booking.pricing.commission}€`);
          console.log(`      Net Payout (Sitter receives): ${booking.pricing.netPayout}€`);
        }
        
        if (booking.recommendedPriceRange) {
          console.log(`   📊 Recommended Range: ${booking.recommendedPriceRange.min}€ - ${booking.recommendedPriceRange.max}€`);
        }
        
        console.log('');
      });
    }

    // Summary Statistics
    console.log('═══════════════════════════════════════════════════════════════');
    console.log('📊 SUMMARY STATISTICS');
    console.log('═══════════════════════════════════════════════════════════════\n');

    const totalBookings = bookings.length;
    const totalRevenue = bookings.reduce((sum, b) => sum + (b.pricing?.totalPrice || 0), 0);
    const totalCommission = bookings.reduce((sum, b) => sum + (b.pricing?.commission || 0), 0);
    const totalPayout = bookings.reduce((sum, b) => sum + (b.pricing?.netPayout || 0), 0);

    console.log(`Total Sitters with Pricing: ${sitters.length}`);
    console.log(`Total Bookings: ${totalBookings}`);
    console.log(`Total Revenue (Owner payments): ${totalRevenue.toFixed(2)}€`);
    console.log(`Total Commission (Platform): ${totalCommission.toFixed(2)}€`);
    console.log(`Total Payout (Sitters): ${totalPayout.toFixed(2)}€`);
    console.log(`Commission Rate: 20%`);
    console.log('');

    await mongoose.connection.close();
    console.log('🔌 Database connection closed');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error viewing data:', error);
    await mongoose.connection.close();
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  viewSeededData();
}

module.exports = { viewSeededData };

