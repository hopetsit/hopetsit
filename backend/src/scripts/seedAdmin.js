require('dotenv').config();
const mongoose = require('mongoose');
const Admin = require('../models/Admin');
const logger = require('../utils/logger');

// Sprint 6.5 step 5 — exposed as function so runAllMigrations can chain it.
// v23.1 part 128 — Phase 4 audit P4-5 : NE PLUS resync le password admin
// à chaque boot. Avant : un git push redéployait Render → reset auto du
// password depuis ADMIN_SEED_PASSWORD → tout changement de password
// effectué via la DB / un futur panel admin était effacé. Désormais on
// crée uniquement si l'admin n'existe pas. Pour reset manuellement,
// utiliser le flag explicite ADMIN_SEED_FORCE_RESET=true (au lieu d'un
// re-sync silencieux).
const seedAdmin = async () => {
  const email = process.env.ADMIN_SEED_EMAIL;
  const password = process.env.ADMIN_SEED_PASSWORD;
  if (!email || !password) {
    logger.info('[seedAdmin] ADMIN_SEED_EMAIL/PASSWORD not set — skipped.');
    return { skipped: true };
  }
  const lowered = email.toLowerCase();
  const existing = await Admin.findOne({ email: lowered });
  if (existing) {
    if (process.env.ADMIN_SEED_FORCE_RESET === 'true') {
      const passwordHash = await Admin.hashPassword(password);
      existing.passwordHash = passwordHash;
      await existing.save();
      logger.warn(
        `[seedAdmin] admin password FORCE-RESET (ADMIN_SEED_FORCE_RESET=true) for ${existing.email}. ` +
        `Retirer la var une fois fait.`,
      );
      return { forceReset: true };
    }
    logger.info(`[seedAdmin] admin ${existing.email} already exists, password unchanged.`);
    return { alreadyExists: true };
  }
  const passwordHash = await Admin.hashPassword(password);
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
