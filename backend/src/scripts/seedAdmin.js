require('dotenv').config();
const mongoose = require('mongoose');
const Admin = require('../models/Admin');
const logger = require('../utils/logger');

// Sprint 6.5 step 5 — exposed as function so runAllMigrations can chain it.
const seedAdmin = async () => {
  const email = process.env.ADMIN_SEED_EMAIL;
  const password = process.env.ADMIN_SEED_PASSWORD;
  if (!email || !password) {
    logger.info('[seedAdmin] ADMIN_SEED_EMAIL/PASSWORD not set — skipped.');
    return { skipped: true };
  }
  const existing = await Admin.findOne({ email: email.toLowerCase() });
  if (existing) {
    logger.info(`[seedAdmin] admin already exists: ${existing.email} — skipped.`);
    return { existing: true };
  }
  const passwordHash = await Admin.hashPassword(password);
  const admin = await Admin.create({
    email: email.toLowerCase(),
    passwordHash,
    name: 'Root Admin',
  });
  logger.info(`[seedAdmin] admin created: ${admin.email}`);
  return { created: true };
};

module.exports = { seedAdmin };

if (require.main === module) {
  (async () => {
    try {
      await mongoose.connect(process.env.MONGODB_URI);
      await seedAdmin();
    } catch (err) {
      logger.error('seedAdmin failed:', err);
      process.exitCode = 1;
    } finally {
      await mongoose.disconnect();
    }
  })();
}
