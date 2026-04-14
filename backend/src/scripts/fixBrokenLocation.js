require('dotenv').config();
const mongoose = require('mongoose');

const Sitter = require('../models/Sitter');
const Owner = require('../models/Owner');

const MONGODB_URI = process.env.MONGODB_URI;

async function fixBrokenLocation() {
  try {
    console.log('🔌 Connecting to MongoDB...');
    await mongoose.connect(MONGODB_URI);
    console.log('✅ Connected to MongoDB');

    console.log('\n📊 Finding documents with invalid location...');

    // Find ALL sitters with location field, then filter in code
    const allSitters = await Sitter.collection.find({
      'location': { $exists: true }
    }).toArray();
    
    // Filter to find ones with invalid coordinates
    const sitters = allSitters.filter(sitter => {
      const loc = sitter.location;
      if (!loc) return false;
      
      // Invalid if: no coordinates field, null coordinates, or not a valid array of 2 numbers
      if (!loc.coordinates || loc.coordinates === null) return true;
      if (!Array.isArray(loc.coordinates)) return true;
      if (loc.coordinates.length !== 2) return true;
      if (typeof loc.coordinates[0] !== 'number' || typeof loc.coordinates[1] !== 'number') return true;
      
      return false;
    });

    console.log(`   Found ${sitters.length} sitters with invalid location`);

    if (sitters.length > 0) {
      console.log(`   Found ${sitters.length} sitters with invalid location`);
      for (const sitter of sitters) {
        console.log(`   🔧 Fixing sitter: ${sitter._id} (${sitter.email || 'no email'})`);
        console.log(`      Current location:`, JSON.stringify(sitter.location, null, 2));
        
        await Sitter.collection.updateOne(
          { _id: sitter._id },
          { $unset: { location: '' } }
        );
        
        console.log(`      ✅ Removed invalid location field`);
      }
    } else {
      console.log(`   Found 0 sitters with invalid location`);
    }

    // Same for owners - find all, then filter
    const allOwners = await Owner.collection.find({
      'location': { $exists: true }
    }).toArray();
    
    // Filter to find ones with invalid coordinates
    const owners = allOwners.filter(owner => {
      const loc = owner.location;
      if (!loc) return false;
      
      // Invalid if: no coordinates field, null coordinates, or not a valid array of 2 numbers
      if (!loc.coordinates || loc.coordinates === null) return true;
      if (!Array.isArray(loc.coordinates)) return true;
      if (loc.coordinates.length !== 2) return true;
      if (typeof loc.coordinates[0] !== 'number' || typeof loc.coordinates[1] !== 'number') return true;
      
      return false;
    });

    console.log(`   Found ${owners.length} owners with invalid location`);

    if (owners.length > 0) {
      console.log(`   Found ${owners.length} owners with invalid location`);
      for (const owner of owners) {
        console.log(`   🔧 Fixing owner: ${owner._id} (${owner.email || 'no email'})`);
        console.log(`      Current location:`, JSON.stringify(owner.location, null, 2));
        
        await Owner.collection.updateOne(
          { _id: owner._id },
          { $unset: { location: '' } }
        );
        
        console.log(`      ✅ Removed invalid location field`);
      }
    } else {
      console.log(`   Found 0 owners with invalid location`);
    }

    console.log('\n✅ All broken location fields fixed!');
    console.log(`   Fixed ${sitters.length} sitters and ${owners.length} owners`);

    await mongoose.connection.close();
    console.log('\n🔌 Database connection closed');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error fixing locations:', error);
    await mongoose.connection.close();
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  fixBrokenLocation();
}

module.exports = fixBrokenLocation;
