require('dotenv').config();
const mongoose = require('mongoose');

const Sitter = require('../models/Sitter');

const MONGODB_URI = process.env.MONGODB_URI;

async function checkSittersWithCoordinates() {
  try {
    console.log('🔌 Connecting to MongoDB...');
    await mongoose.connect(MONGODB_URI);
    console.log('✅ Connected to MongoDB\n');

    // Count total sitters
    const totalSitters = await Sitter.countDocuments();
    console.log(`📊 Total sitters in database: ${totalSitters}`);

    // Count sitters with valid coordinates
    const sittersWithCoordinates = await Sitter.countDocuments({
      'location.coordinates': { $exists: true, $type: 'array', $ne: null }
    });
    console.log(`📍 Sitters with valid coordinates: ${sittersWithCoordinates}`);

    // Count verified sitters
    const verifiedSitters = await Sitter.countDocuments({ verified: true });
    console.log(`✅ Verified sitters: ${verifiedSitters}`);

    // Get sample sitters with coordinates
    const sampleSitters = await Sitter.find({
      'location.coordinates': { $exists: true, $type: 'array', $ne: null }
    })
      .select('name email location verified')
      .limit(10);

    if (sampleSitters.length > 0) {
      console.log('\n📍 Sample sitters with coordinates:');
      sampleSitters.forEach((sitter, index) => {
        const [lng, lat] = sitter.location.coordinates || [];
        console.log(`   ${index + 1}. ${sitter.name} (${sitter.email})`);
        console.log(`      Location: [${lng}, ${lat}] (lat: ${lat}, lng: ${lng})`);
        console.log(`      City: ${sitter.location.city || 'N/A'}`);
        console.log(`      Verified: ${sitter.verified ? 'Yes' : 'No'}`);
        console.log('');
      });
    } else {
      console.log('\n⚠️  No sitters found with valid coordinates!');
      console.log('💡 Sitters need to have location.coordinates set to appear in nearby search.');
      console.log('💡 Update sitters with coordinates using the signup or profile update endpoints.');
    }

    // Check sitters without coordinates
    const sittersWithoutCoordinates = await Sitter.countDocuments({
      $or: [
        { 'location.coordinates': { $exists: false } },
        { 'location.coordinates': null },
        { 'location': { $exists: false } }
      ]
    });
    console.log(`❌ Sitters without coordinates: ${sittersWithoutCoordinates}`);

    await mongoose.connection.close();
    console.log('\n🔌 Database connection closed');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    await mongoose.connection.close();
    process.exit(1);
  }
}

if (require.main === module) {
  checkSittersWithCoordinates();
}

module.exports = checkSittersWithCoordinates;

