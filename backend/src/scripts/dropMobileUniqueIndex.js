require('dotenv').config();
const mongoose = require('mongoose');
const logger = require('../utils/logger');

const COLLECTIONS = ['owners', 'sitters'];
const INDEX_CANDIDATES = ['mobile_1', 'phone_1', 'countryCode_1_mobile_1'];

// Sprint 6.5 step 5 — expose as a function so runAllMigrations can chain it.
const dropMobileUniqueIndex = async () => {
  const db = mongoose.connection.db;
  let dropped = 0;
  for (const coll of COLLECTIONS) {
    const indexes = await db.collection(coll).indexes().catch(() => []);
    for (const idx of indexes) {
      if (INDEX_CANDIDATES.includes(idx.name) && idx.unique) {
        await db.collection(coll).dropIndex(idx.name);
        logger.info(`[dropMobileUniqueIndex] ${coll}: dropped ${idx.name}`);
        dropped++;
      }
    }
  }
  if (dropped === 0) logger.info('[dropMobileUniqueIndex] no legacy unique index found — skipped.');
  return { dropped };
};

module.exports = { dropMobileUniqueIndex };

if (require.main === module) {
  (async () => {
    try {
      await mongoose.connect(process.env.MONGODB_URI);
      await dropMobileUniqueIndex();
      logger.info('done');
    } catch (e) {
      logger.error('migration failed:', e);
      process.exitCode = 1;
    } finally {
      await mongoose.disconnect();
    }
  })();
}
