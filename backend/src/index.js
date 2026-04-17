require('dotenv').config();

const http = require('http');
const mongoose = require('mongoose');

const app = require('./app');
const createSocketServer = require('./sockets');
const { startPayoutScheduler } = require('./services/payoutScheduler');
const { startMapTtlScheduler } = require('./services/mapReportTtlScheduler');
const pricingService = require('./services/pricingService');
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
    server.listen(PORT, () => {
      logger.info(`PetsInsta backend listening at http://localhost:${PORT}`);
    });
    startPayoutScheduler();
    startMapTtlScheduler();
  } catch (error) {
    logger.error('Failed to start server', error);
    process.exit(1);
  }
}

startServer();
