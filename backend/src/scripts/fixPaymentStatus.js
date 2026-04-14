/**
 * Fix paymentStatus for bookings that are paid but have paymentStatus as pending
 * This script updates paymentStatus to match the booking status
 * 
 * Usage: node src/scripts/fixPaymentStatus.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const Booking = require('../models/Booking');

async function fixPaymentStatus() {
  try {
    // Connect to MongoDB
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('✅ Connected to MongoDB\n');

    // Find bookings that are paid but paymentStatus is pending or missing
    const bookings = await Booking.find({
      $or: [
        { status: 'paid', paymentStatus: { $ne: 'paid' } },
        { status: 'paid', paymentStatus: { $exists: false } },
        { status: 'refunded', paymentStatus: { $ne: 'refund' } },
        { status: 'refunded', paymentStatus: { $exists: false } },
      ],
    });

    console.log(`📊 Found ${bookings.length} bookings with mismatched payment status\n`);

    if (bookings.length === 0) {
      console.log('✅ All bookings have correct payment status!');
      await mongoose.connection.close();
      return;
    }

    let updatedCount = 0;

    for (const booking of bookings) {
      try {
        let newPaymentStatus = null;

        // Map booking status to payment status
        if (booking.status === 'paid') {
          newPaymentStatus = 'paid';
        } else if (booking.status === 'refunded') {
          newPaymentStatus = 'refund';
        } else if (booking.status === 'cancelled') {
          newPaymentStatus = 'cancelled';
        } else {
          // For other statuses, keep paymentStatus as pending
          newPaymentStatus = 'pending';
        }

        if (newPaymentStatus && booking.paymentStatus !== newPaymentStatus) {
          booking.paymentStatus = newPaymentStatus;
          await booking.save();
          
          console.log(`  ✅ Booking ${booking._id}:`);
          console.log(`     - Status: ${booking.status}`);
          console.log(`     - Payment Status: ${booking.paymentStatus} (updated)`);
          
          updatedCount++;
        }
      } catch (error) {
        console.error(`  ❌ Error updating booking ${booking._id}:`, error.message);
      }
    }

    console.log(`\n✅ Fix payment status complete!`);
    console.log(`   - Updated: ${updatedCount} bookings`);
    console.log(`\n💡 All bookings now have correct payment status.\n`);

    await mongoose.connection.close();
    console.log('✅ Database connection closed');
  } catch (error) {
    console.error('❌ Error:', error);
    await mongoose.connection.close();
    process.exit(1);
  }
}

// Run the script
fixPaymentStatus();

