require('dotenv').config();

const http = require('http');
const mongoose = require('mongoose');

const app = require('./app');
const createSocketServer = require('./sockets');
const { startPayoutScheduler } = require('./services/payoutScheduler');
const { startMapTtlScheduler } = require('./services/mapReportTtlScheduler');
const { startPostCleanupScheduler } = require('./services/postCleanupScheduler');
const pricingService = require('./services/pricingService');
const serviceCatalogService = require('./services/serviceCatalogService');
const { seedAdmin } = require('./scripts/seedAdmin');
const logger = require('./utils/logger');

const PORT = process.env.PORT || 5000;
const MONGODB_URI = process.env.MONGODB_URI;

const server = http.createServer(app);
createSocketServer(server);

async function startServer() {
  try {
    await mongoose.connect(MONGODB_URI);
    // Load pricing grid from DB before we start accepting requests so the
    // /packages endpoints return live prices from the first call.
    await pricingService.init();
    // Load the admin-editable service catalog (duration presets, active
    // flags, label overrides) the same way.
    await serviceCatalogService.init();
    // v21.1.1 — Auto-seed/resync the root admin from ADMIN_SEED_EMAIL +
    // ADMIN_SEED_PASSWORD env vars at every boot. If the env vars are
    // missing, this is a no-op. If the admin exists, the password gets
    // resynced — donc l'admin peut reset son password en changeant juste
    // ADMIN_SEED_PASSWORD côté Render et en redéployant.
    try {
      const result = await seedAdmin();
      logger.info(`[boot] seedAdmin: ${JSON.stringify(result)}`);
    } catch (e) {
      logger.error('[boot] seedAdmin failed (non-fatal)', e);
    }
    // v23.1.367 — Daniel : badge Staff ⭐ automatique sur les comptes
    // fondateurs (emails ci-dessous ; chiffrés en DB → scan + decrypt).
    // Idempotent : ne touche que les comptes pas encore flaggés. Effet :
    // boutique gratuite + spots PawSpot DORÉS (Gold Creator d'office).
    try {
      const { decrypt } = require('./utils/encryption');
      const STAFF_EMAILS = ['dadaciao84@gmail.com', 'hopetsit@gmail.com'];
      let flagged = 0;
      for (const modelName of ['Owner', 'Sitter', 'Walker']) {
        const Model = require(`./models/${modelName}`);
        const candidates = await Model.find({ isStaff: { $ne: true } })
          .select('email').limit(5000).lean();
        for (const u of candidates) {
          let email = '';
          try {
            email = (decrypt(u.email || '') || '').toLowerCase().trim();
          } catch (_) { continue; }
          if (STAFF_EMAILS.includes(email)) {
            await Model.updateOne({ _id: u._id }, { $set: { isStaff: true } });
            flagged += 1;
            logger.info(
              `[boot] ensureStaff: ${modelName} ${u._id} → isStaff=true (${email})`,
            );
          }
        }
      }
      if (flagged > 0) {
        logger.info(`⭐ [boot] ensureStaff: ${flagged} compte(s) flaggé(s) staff.`);
      }
    } catch (e) {
      logger.error('[boot] ensureStaff failed (non-fatal)', e);
    }
    server.listen(PORT, () => {
      logger.info(`PetsInsta backend listening at http://localhost:${PORT}`);
    });
    startPayoutScheduler();
    startMapTtlScheduler();
    // v23.1.288 — supprime les annonces 48h après la fin du service.
    startPostCleanupScheduler();
  } catch (error) {
    logger.error('Failed to start server', error);
    process.exit(1);
  }
}

startServer();
