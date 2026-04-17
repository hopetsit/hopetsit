require('dotenv').config();

const http = require('http');
const mongoose = require('mongoose');

const app = require('./app');
const createSocketServer = require('./sockets');
const { startPayoutScheduler } = require('./services/payoutScheduler');
const { startMapTtlScheduler } = require('./services/mapReportTtlScheduler');
const logger = require('./utils/logger');

const PORT = process.env.PORT || 5000;
const MONGODB_URI = process.env.MONGODB_URI;

const server = http.createServer(app);
createSocketServer(server);

async function startServer() {
  try {
    await mongoose.connect(MONGODB_URI);
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
