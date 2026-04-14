const mongoose = require('mongoose');
require('dotenv').config();

const Booking = require('../models/Booking');
const Pet = require('../models/Pet');

/**
 * Migration script to:
 * 1. Add petId to existing bookings based on ownerId and petName
 * 2. Remove petName from bookings (set to empty string)
 * 
 * For each booking:
 * - Get ownerId
 * - Find pet for that owner (try matching by petName first, then get first pet)
 * - Update booking with petId
 * - Remove petName
 */
async function migrateBookingsWithPetId() {
  try {
    // Connect to MongoDB
    const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/petinsta';
    await mongoose.connect(mongoUri);
    console.log('✅ Connected to MongoDB');

    // Find all bookings without petId
    const bookings = await Booking.find({ 
      $or: [
        { petId: { $exists: false } },
        { petId: null }
      ]
    });

    console.log(`\n📊 Found ${bookings.length} bookings to migrate\n`);

    let successCount = 0;
    let failedCount = 0;
    const failedBookings = [];

    for (const booking of bookings) {
      try {
        const ownerId = booking.ownerId;
        const petName = booking.petName || '';

        if (!ownerId) {
          console.log(`⚠️  Booking ${booking._id}: No ownerId found, skipping...`);
          failedCount++;
          failedBookings.push({
            bookingId: booking._id,
            reason: 'No ownerId'
          });
          continue;
        }

        // Try to find pet by ownerId and petName (exact match)
        let pet = null;
        
        if (petName && petName.trim()) {
          // Try exact match first
          pet = await Pet.findOne({
            ownerId: ownerId,
            petName: petName.trim(),
          });

          // If exact match fails, try case-insensitive match
          if (!pet) {
            const escapedPetName = petName.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
            pet = await Pet.findOne({
              ownerId: ownerId,
              petName: { $regex: new RegExp(`^${escapedPetName}$`, 'i') },
            });
          }
        }

        // If no pet found by name, get the first pet for this owner
        if (!pet) {
          pet = await Pet.findOne({
            ownerId: ownerId,
          }).sort({ updatedAt: -1 }); // Get most recently updated pet
        }

        if (pet) {
          // Update booking with petId and remove petName
          await Booking.findByIdAndUpdate(
            booking._id,
            {
              $set: {
                petId: pet._id,
                petName: '', // Remove petName
              }
            }
          );

          console.log(`✅ Booking ${booking._id}: Added petId ${pet._id} (pet: "${pet.petName}")`);
          successCount++;
        } else {
          console.log(`⚠️  Booking ${booking._id}: No pet found for owner ${ownerId}, petName: "${petName}"`);
          failedCount++;
          failedBookings.push({
            bookingId: booking._id,
            ownerId: ownerId.toString(),
            petName: petName,
            reason: 'No pet found for this owner'
          });
        }
      } catch (error) {
        console.error(`❌ Error processing booking ${booking._id}:`, error.message);
        failedCount++;
        failedBookings.push({
          bookingId: booking._id,
          reason: error.message
        });
      }
    }

    // Summary
    console.log('\n' + '='.repeat(60));
    console.log('📈 MIGRATION SUMMARY');
    console.log('='.repeat(60));
    console.log(`✅ Successfully migrated: ${successCount} bookings`);
    console.log(`⚠️  Failed: ${failedCount} bookings`);
    
    if (failedBookings.length > 0) {
      console.log('\n❌ Failed Bookings:');
      failedBookings.forEach((failed, index) => {
        console.log(`   ${index + 1}. Booking ID: ${failed.bookingId}`);
        console.log(`      Reason: ${failed.reason}`);
        if (failed.ownerId) {
          console.log(`      Owner ID: ${failed.ownerId}`);
        }
        if (failed.petName) {
          console.log(`      Pet Name: ${failed.petName}`);
        }
        console.log('');
      });
    }

    console.log('\n✅ Migration completed!');
    
  } catch (error) {
    console.error('❌ Migration error:', error);
    throw error;
  } finally {
    await mongoose.connection.close();
    console.log('🔌 Disconnected from MongoDB');
  }
}

// Run the migration
if (require.main === module) {
  migrateBookingsWithPetId()
    .then(() => {
      console.log('\n✨ Script finished successfully');
      process.exit(0);
    })
    .catch((error) => {
      console.error('\n💥 Script failed:', error);
      process.exit(1);
    });
}

module.exports = migrateBookingsWithPetId;

