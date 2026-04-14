/**
 * Sprint 6.5 step 5 — one-shot migration runner.
 *
 * Runs all idempotent maintenance scripts in order:
 *   1. dropMobileUniqueIndex  (remove legacy unique index on phone)
 *   2. encryptSensitiveFields (encrypt IBAN/PayPal/card fields)
 *   3. seedAdmin              (create the first admin if ADMIN_SEED_* set)
 *
 * Usage:   node src/scripts/runAllMigrations.js
 * Safe to re-run: each step is idempotent and logs what it did or why it skipped.
 */
require('dotenv').config();
const mongoose = require('mongoose');
const { dropMobileUniqueIndex } = require('./dropMobileUniqueIndex');
const { encryptSensitiveFields } = require('./encryptSensitiveFields');
const { seedAdmin } = require('./seedAdmin');
const logger = require('../utils/logger');

(async () => {
  if (!process.env.MONGODB_URI) {
    logger.error('MONGODB_URI is not set. Aborting.');
    process.exit(1);
  }
  let failed = 0;
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    logger.info('============================================================');
    logger.info('HopeTSIT — runAllMigrations starting');
    logger.info('============================================================');

    const steps = [
      { name: '1/3 dropMobileUniqueIndex', run: dropMobileUniqueIndex },
      { name: '2/3 encryptSensitiveFields', run: encryptSensitiveFields },
      { name: '3/3 seedAdmin', run: seedAdmin },
    ];

    for (const step of steps) {
      logger.info(`\n→ ${step.name}`);
      try {
        await step.run();
        logger.info(`✅ ${step.name} OK`);
      } catch (e) {
        failed++;
        logger.error(`❌ ${step.name} failed:`, e.message || e);
      }
    }
  } catch (e) {
    logger.error('runAllMigrations fatal:', e);
    failed++;
  } finally {
    await mongoose.disconnect();
    logger.info('\n============================================================');
    logger.info(failed === 0 ? 'All migrations finished successfully.' : `Finished with ${failed} failure(s).`);
    logger.info('============================================================');
    process.exit(failed === 0 ? 0 : 1);
  }
})();
