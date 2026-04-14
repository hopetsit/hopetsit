require('dotenv').config();
const mongoose = require('mongoose');

const Sitter = require('../models/Sitter');
const Owner = require('../models/Owner');

const MONGODB_URI = process.env.MONGODB_URI;

async function createLocationIndexes() {
  try {
    console.log('🔌 Connecting to MongoDB...');
    await mongoose.connect(MONGODB_URI);
    console.log('✅ Connected to MongoDB');

    console.log('\n📊 Checking and fixing existing location data...');

    // Fix existing Sitter documents with invalid location format
    // Remove location field from documents that don't have valid GeoJSON coordinates
    const sittersWithInvalidLocation = await Sitter.find({
      $or: [
        { 'location.coordinates': { $exists: false } },
        { 'location.coordinates': null },
        { 'location.type': { $ne: 'Point' } }
      ],
      'location': { $exists: true }
    });

    if (sittersWithInvalidLocation.length > 0) {
      console.log(`   Found ${sittersWithInvalidLocation.length} sitters with invalid location format`);
      console.log('   🔧 Fixing invalid location objects...');
      
      // Remove location field from documents without valid coordinates
      // MongoDB 2dsphere index cannot index documents with null coordinates
      for (const sitter of sittersWithInvalidLocation) {
        // Unset location field entirely - these documents won't be indexed
        await Sitter.updateOne(
          { _id: sitter._id },
          { $unset: { location: '' } }
        );
      }
      console.log(`   ✅ Fixed ${sittersWithInvalidLocation.length} sitter location objects`);
    }

    // Fix existing Owner documents with invalid location format
    const ownersWithInvalidLocation = await Owner.find({
      $or: [
        { 'location.coordinates': { $exists: false } },
        { 'location.coordinates': null },
        { 'location.type': { $ne: 'Point' } }
      ],
      'location': { $exists: true }
    });

    if (ownersWithInvalidLocation.length > 0) {
      console.log(`   Found ${ownersWithInvalidLocation.length} owners with invalid location format`);
      console.log('   🔧 Fixing invalid location objects...');
      
      // Remove location field from documents without valid coordinates
      for (const owner of ownersWithInvalidLocation) {
        await Owner.updateOne(
          { _id: owner._id },
          { $unset: { location: '' } }
        );
      }
      console.log(`   ✅ Fixed ${ownersWithInvalidLocation.length} owner location objects`);
    }

    console.log('\n📊 Creating geospatial indexes...');

    // Create partial index for Sitter location (only indexes documents with valid coordinates)
    try {
      console.log('   Creating partial index for Sitter.location...');
      await Sitter.collection.createIndex(
        { 'location': '2dsphere' },
        { 
          name: 'location_2dsphere',
          background: true,
          partialFilterExpression: { 'location.coordinates': { $exists: true, $type: 'array' } }
        }
      );
      console.log('   ✅ Sitter location index created (partial)');
    } catch (error) {
      if (error.code === 85) {
        console.log('   ⚠️  Sitter location index already exists (different options)');
        // Drop and recreate
        try {
          await Sitter.collection.dropIndex('location_2dsphere');
        } catch (dropError) {
          // Index might not exist with that name
        }
        await Sitter.collection.createIndex(
          { 'location': '2dsphere' },
          { 
            name: 'location_2dsphere',
            background: true,
            partialFilterExpression: { 'location.coordinates': { $exists: true, $type: 'array' } }
          }
        );
        console.log('   ✅ Sitter location index recreated');
      } else if (error.code === 86) {
        console.log('   ✅ Sitter location index already exists');
      } else {
        throw error;
      }
    }

    // Create partial index for Owner location (only indexes documents with valid coordinates)
    try {
      console.log('   Creating partial index for Owner.location...');
      await Owner.collection.createIndex(
        { 'location': '2dsphere' },
        { 
          name: 'location_2dsphere',
          background: true,
          partialFilterExpression: { 'location.coordinates': { $exists: true, $type: 'array' } }
        }
      );
      console.log('   ✅ Owner location index created (partial)');
    } catch (error) {
      if (error.code === 85) {
        console.log('   ⚠️  Owner location index already exists (different options)');
        // Drop and recreate
        try {
          await Owner.collection.dropIndex('location_2dsphere');
        } catch (dropError) {
          // Index might not exist with that name
        }
        await Owner.collection.createIndex(
          { 'location': '2dsphere' },
          { 
            name: 'location_2dsphere',
            background: true,
            partialFilterExpression: { 'location.coordinates': { $exists: true, $type: 'array' } }
          }
        );
        console.log('   ✅ Owner location index recreated');
      } else if (error.code === 86) {
        console.log('   ✅ Owner location index already exists');
      } else {
        throw error;
      }
    }

    // Verify indexes
    console.log('\n📋 Verifying indexes...');
    const sitterIndexes = await Sitter.collection.indexes();
    const ownerIndexes = await Owner.collection.indexes();

    console.log('\n   Sitter indexes:');
    sitterIndexes.forEach(index => {
      console.log(`     - ${index.name}: ${JSON.stringify(index.key)}`);
    });

    console.log('\n   Owner indexes:');
    ownerIndexes.forEach(index => {
      console.log(`     - ${index.name}: ${JSON.stringify(index.key)}`);
    });

    console.log('\n✅ Geospatial indexes created successfully!');
    console.log('\n💡 You can now use the /sitters/nearby endpoint for geospatial queries.');

    await mongoose.connection.close();
    console.log('\n🔌 Database connection closed');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error creating indexes:', error);
    await mongoose.connection.close();
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  createLocationIndexes();
}

module.exports = createLocationIndexes;

