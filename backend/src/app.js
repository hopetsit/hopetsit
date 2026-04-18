const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const pinoHttp = require('pino-http');
const logger = require('./utils/logger');
const sentry = require('./utils/sentry');
sentry.init();
const swaggerUi = require('swagger-ui-express');
const swaggerSpec = require('./config/swagger');

const authRoutes = require('./routes/authRoutes');
const healthRoutes = require('./routes/healthRoutes');
const userRoutes = require('./routes/userRoutes');
const petRoutes = require('./routes/petRoutes');
const sitterRoutes = require('./routes/sitterRoutes');
const walkerRoutes = require('./routes/walkerRoutes');
const bookingRoutes = require('./routes/bookingRoutes');
const postRoutes = require('./routes/postRoutes');
const applicationRoutes = require('./routes/applicationRoutes');
const conversationRoutes = require('./routes/conversationRoutes');
const taskRoutes = require('./routes/taskRoutes');
const blockRoutes = require('./routes/blockRoutes');
const reviewRoutes = require('./routes/reviewRoutes');
const uploadRoutes = require('./routes/uploadRoutes');
const pricingRoutes = require('./routes/pricingRoutes');
const stripeConnectRoutes = require('./routes/stripeConnectRoutes');
const stripeWebhookRoutes = require('./routes/stripeWebhookRoutes');
const adminRoutes = require('./routes/adminRoutes');
const ibanRoutes = require('./routes/ibanRoutes');
const notificationRoutes = require('./routes/notificationRoutes');
const walkRoutes = require('./routes/walkRoutes');
const termsRoutes = require('./routes/termsRoutes');
const privacyPolicyRoutes = require('./routes/privacyPolicyRoutes');
const reportRoutes = require('./routes/reportRoutes');
const boostRoutes = require('./routes/boostRoutes');
const mapPoiRoutes = require('./routes/mapPoiRoutes');
const mapReportRoutes = require('./routes/mapReportRoutes');
const mapBoostRoutes = require('./routes/mapBoostRoutes');
const subscriptionRoutes = require('./routes/subscriptionRoutes');
const chatAddonRoutes = require('./routes/chatAddonRoutes');
const friendRoutes = require('./routes/friendRoutes');
const { authLimiter, sensitiveLimiter } = require('./middleware/rateLimiters');

const app = express();

// Configure helmet with CSP that allows Stripe scripts and inline scripts for test pages
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: [
        "'self'",
        "'unsafe-inline'", // Allow inline scripts for test pages
        "https://js.stripe.com", // Allow Stripe.js
      ],
      scriptSrcAttr: ["'unsafe-inline'"], // Allow inline event handlers (onclick, etc.)
      styleSrc: ["'self'", "'unsafe-inline'"], // Allow inline styles
      imgSrc: ["'self'", "data:", "https:"], // Allow images from any HTTPS source
      connectSrc: [
        "'self'",
        "https://api.stripe.com", // Allow Stripe API calls
      ],
      frameSrc: ["'self'", "https://js.stripe.com", "https://hooks.stripe.com"], // Allow Stripe iframes
    },
  },
}));
// CORS whitelist from ALLOWED_ORIGINS env var (comma-separated).
// Requests without an Origin header (native mobile apps, curl, server-to-server) are allowed.
const allowedOrigins = (process.env.ALLOWED_ORIGINS || 'http://localhost:3000,http://localhost:5000')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

app.use(cors({
  origin(origin, callback) {
    if (!origin) return callback(null, true);
    if (allowedOrigins.includes(origin)) return callback(null, true);
    return callback(new Error(`CORS: origin ${origin} not allowed`));
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
}));

// Stripe webhook route must use raw body (register before JSON middleware)
app.use('/webhooks', stripeWebhookRoutes);

app.use(express.json({ limit: '25mb' }));
app.use(express.urlencoded({ limit: '25mb', extended: true }));
// Sprint 8 step 5 — structured request logger (pino-http) with reqId + duration.
app.use(pinoHttp({ logger, autoLogging: { ignore: (req) => req.url === '/health' } }));

// Sprint 8 step 4 — Swagger UI is public in dev, protected by SWAGGER_AUTH_TOKEN in prod.
const swaggerGuard = (req, res, next) => {
  if (process.env.NODE_ENV !== 'production') return next();
  const expected = process.env.SWAGGER_AUTH_TOKEN;
  const provided = req.headers['x-swagger-auth'];
  if (!expected) return res.status(404).end();
  if (provided === expected) return next();
  res.set('WWW-Authenticate', 'Header realm="swagger"');
  return res.status(401).json({ error: 'Swagger access denied.' });
};
app.use(
  '/api-docs',
  swaggerGuard,
  swaggerUi.serve,
  swaggerUi.setup(swaggerSpec, {
    customCss: '.swagger-ui .topbar { display: none }',
    customSiteTitle: 'PetsInsta API Documentation',
  })
);

// Sprint 8 step 9 — API versioning. All routes are mounted under /api/v1
// AND also aliased at the root for 6-month backwards compatibility. The
// alias logs a deprecation warning; Stripe webhooks stay at /webhooks because
// Stripe configures them by absolute URL and moving them would break
// existing registrations.
const versionedRoutes = [
  { path: '/health', mw: [], router: healthRoutes },
  { path: '/auth', mw: [authLimiter], router: authRoutes },
  { path: '/users', mw: [], router: userRoutes },
  { path: '/pets', mw: [], router: petRoutes },
  { path: '/sitters', mw: [], router: sitterRoutes },
  { path: '/walkers', mw: [], router: walkerRoutes },
  { path: '/bookings', mw: [sensitiveLimiter], router: bookingRoutes },
  { path: '/posts', mw: [], router: postRoutes },
  { path: '/applications', mw: [], router: applicationRoutes },
  { path: '/conversations', mw: [], router: conversationRoutes },
  { path: '/tasks', mw: [], router: taskRoutes },
  { path: '/blocks', mw: [], router: blockRoutes },
  { path: '/reviews', mw: [], router: reviewRoutes },
  { path: '/uploads', mw: [], router: uploadRoutes },
  { path: '/pricing', mw: [], router: pricingRoutes },
  { path: '/stripe-connect', mw: [sensitiveLimiter], router: stripeConnectRoutes },
  { path: '/admin', mw: [], router: adminRoutes },
  { path: '/sitter', mw: [], router: ibanRoutes },
  { path: '/notifications', mw: [], router: notificationRoutes },
  { path: '/walks', mw: [], router: walkRoutes },
  { path: '/terms', mw: [], router: termsRoutes },
  { path: '/privacy-policy', mw: [], router: privacyPolicyRoutes },
  { path: '/reports', mw: [], router: reportRoutes },
  { path: '/boost', mw: [], router: boostRoutes },
  { path: '/map-pois', mw: [], router: mapPoiRoutes },
  { path: '/map-reports', mw: [], router: mapReportRoutes },
  { path: '/map-boost', mw: [sensitiveLimiter], router: mapBoostRoutes },
  { path: '/subscriptions', mw: [sensitiveLimiter], router: subscriptionRoutes },
  { path: '/chat-addon', mw: [sensitiveLimiter], router: chatAddonRoutes },
  { path: '/friends', mw: [], router: friendRoutes },
];

// Log deprecation warning for unversioned callers.
const deprecatedRootWarner = (req, res, next) => {
  logger.warn(
    { path: req.originalUrl },
    'Deprecated unversioned API path — migrate callers to /api/v1/*'
  );
  next();
};

for (const r of versionedRoutes) {
  // Primary mount under /api/v1 (canonical).
  app.use(`/api/v1${r.path}`, ...r.mw, r.router);
  // Backwards-compat mount at the root (WITHOUT the version prefix).
  app.use(r.path, deprecatedRootWarner, ...r.mw, r.router);
}

// Swagger UI also exposed at the versioned path.
app.use(
  '/api/v1/docs',
  swaggerGuard,
  swaggerUi.serve,
  swaggerUi.setup(swaggerSpec, {
    customCss: '.swagger-ui .topbar { display: none }',
    customSiteTitle: 'HopeTSIT API v1 Documentation',
  })
);

// Sprint 8 step 6 — global Express error handler: report to Sentry then
// fall back to a generic 500 so clients never see a stack trace.
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  logger.error({ err }, 'Unhandled Express error');
  sentry.captureException(err, {
    path: req.path,
    method: req.method,
    userId: req.user?.id,
  });
  if (res.headersSent) return;
  res.status(err.status || 500).json({
    error: err.expose ? err.message : 'Internal server error',
  });
});

module.exports = app;

