require('dotenv').config();
const mongoose = require('mongoose');
const Admin = require('../models/Admin');
const logger = require('../utils/logger');

// Sprint 6.5 step 5 — exposed as function so runAllMigrations can chain it.
// v21.1.1 — passe en upsert : si l'admin existe déjà, on resync son password
// avec ADMIN_SEED_PASSWORD au lieu de skipper. Comme ça l'admin perdu de
// password peut juste set la var d'env et redeploy pour reset.
const seedAdmin = async () => {
  const email = process.env.ADMIN_SEED_EMAIL;
  const password = process.env.ADMIN_SEED_PASSWORD;
  if (!email || !password) {
    logger.info('[seedAdmin] ADMIN_SEED_EMAIL/PASSWORD not set — skipped.');
    return { skipped: true };
  }
  const passwordHash = await Admin.hashPassword(password);
  const lowered = email.toLowerCase();
  const existing = await Admin.findOne({ email: lowered });
  if (existing) {
    existing.passwordHash = passwordHash;
    await existing.save();
    logger.info(`[seedAdmin] admin password resynced for ${existing.email}`);
    return { updated: true };
  }
  const admin = await Admin.create({
    email: lowered,
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
