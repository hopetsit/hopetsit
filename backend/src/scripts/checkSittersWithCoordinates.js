require('dotenv').config();
const mongoose = require('mongoose');

const Sitter = require('../models/Sitter');
const logger = require('../utils/logger');

const MONGODB_URI = process.env.MONGODB_URI;

async function checkSittersWithCoordinates() {
  try {
    logger.info('🔌 Connecting to MongoDB...');
    await mongoose.connect(MONGODB_URI);
    logger.info('✅ Connected to MongoDB\n');

    // Count total sitters
    const totalSitters = await Sitter.countDocuments();
    logger.info(`📊 Total sitters in database: ${totalSitters}`);

    // Count sitters with valid coordinates
    const sittersWithCoordinates = await Sitter.countDocuments({
      'location.coordinates': { $exists: true, $type: 'array', $ne: null }
    });
    logger.info(`📍 Sitters with valid coordinates: ${sittersWithCoordinates}`);

    // Count verified sitters
    const verifiedSitters = await Sitter.countDocuments({ verified: true });
    logger.info(`✅ Verified sitters: ${verifiedSitters}`);

    // Get sample sitters with coordinates
    const sampleSitters = await Sitter.find({
      'location.coordinates': { $exists: true, $type: 'array', $ne: null }
    })
      .select('name email location verified')
      .limit(10);

    if (sampleSitters.length > 0) {
      logger.info('\n📍 Sample sitters with coordinates:');
      sampleSitters.forEach((sitter, index) => {
        const [lng, lat] = sitter.location.coordinates || [];
        logger.info(`   ${index + 1}. ${sitter.name} (${sitter.email})`);
        logger.info(`      Location: [${lng}, ${lat}] (lat: ${lat}, lng: ${lng})`);
        logger.info(`      City: ${sitter.location.city || 'N/A'}`);
        logger.info(`      Verified: ${sitter.verified ? 'Yes' : 'No'}`);
        logger.info('');
      });
    } else {
      logger.info('\n⚠️  No sitters found with valid coordinates!');
      logger.info('💡 Sitters need to have location.coordinates set to appear in nearby search.');
      logger.info('💡 Update sitters with coordinates using the signup or profile update endpoints.');
    }

    // Check sitters without coordinates
    const sittersWithoutCoordinates = await Sitter.countDocuments({
      $or: [
        { 'location.coordinates': { $exists: false } },
        { 'location.coordinates': null },
        { 'location': { $exists: false } }
      ]
    });
    logger.info(`❌ Sitters without coordinates: ${sittersWithoutCoordinates}`);

    await mongoose.connection.close();
    logger.info('\n🔌 Database connection closed');
    process.exit(0);
  } catch (error) {
    logger.error('❌ Error:', error);
    await mongoose.connection.close();
    process.exit(1);
  }
}

if (require.main === module) {
  checkSittersWithCoordinates();
}

module.exports = checkSittersWithCoordinates;

