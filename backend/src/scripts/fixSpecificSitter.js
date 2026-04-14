require('dotenv').config();
const mongoose = require('mongoose');

const Sitter = require('../models/Sitter');
const logger = require('../utils/logger');

const MONGODB_URI = process.env.MONGODB_URI;

async function fixSpecificSitter() {
  try {
    logger.info('🔌 Connecting to MongoDB...');
    await mongoose.connect(MONGODB_URI);
    logger.info('✅ Connected to MongoDB');

    // The specific sitter ID from the error
    const sitterId = '6982264a7f24e599203fb26b';
    
    logger.info(`\n📊 Checking sitter: ${sitterId}...`);
    
    const sitter = await Sitter.collection.findOne({ _id: new mongoose.Types.ObjectId(sitterId) });
    
    if (!sitter) {
      logger.info('❌ Sitter not found!');
      await mongoose.connection.close();
      process.exit(1);
    }
    
    logger.info('Current location:', JSON.stringify(sitter.location, null, 2));
    
    // Check if location is invalid
    const hasInvalidLocation = sitter.location && 
      (!sitter.location.coordinates || 
       sitter.location.coordinates === null ||
       !Array.isArray(sitter.location.coordinates) ||
       sitter.location.coordinates.length !== 2);
    
    if (hasInvalidLocation) {
      logger.info('\n🔧 Fixing invalid location...');
      await Sitter.collection.updateOne(
        { _id: new mongoose.Types.ObjectId(sitterId) },
        { $unset: { location: '' } }
      );
      logger.info('✅ Removed invalid location field');
    } else {
      logger.info('\n✅ Location is valid, no fix needed');
    }
    
    // Verify fix
    const updatedSitter = await Sitter.collection.findOne({ _id: new mongoose.Types.ObjectId(sitterId) });
    logger.info('\nUpdated document location:', updatedSitter.location ? JSON.stringify(updatedSitter.location, null, 2) : 'null (removed)');
    
    await mongoose.connection.close();
    logger.info('\n🔌 Database connection closed');
    process.exit(0);
  } catch (error) {
    logger.error('❌ Error:', error);
    await mongoose.connection.close();
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  fixSpecificSitter();
}

module.exports = fixSpecificSitter;
