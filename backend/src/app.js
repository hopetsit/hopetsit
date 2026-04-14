const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const swaggerUi = require('swagger-ui-express');
const swaggerSpec = require('./config/swagger');

const authRoutes = require('./routes/authRoutes');
const healthRoutes = require('./routes/healthRoutes');
const userRoutes = require('./routes/userRoutes');
const petRoutes = require('./routes/petRoutes');
const sitterRoutes = require('./routes/sitterRoutes');
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

// Serve static files from public directory (for test HTML page)
app.use(express.static('public'));

// Stripe webhook route must use raw body (register before JSON middleware)
app.use('/webhooks', stripeWebhookRoutes);

app.use(express.json({ limit: '25mb' }));
app.use(express.urlencoded({ limit: '25mb', extended: true }));
app.use(morgan('dev'));

// Swagger API Documentation
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec, {
  customCss: '.swagger-ui .topbar { display: none }',
  customSiteTitle: 'PetsInsta API Documentation',
}));

app.use('/health', healthRoutes);
app.use('/auth', authRoutes);
app.use('/users', userRoutes);
app.use('/pets', petRoutes);
app.use('/sitters', sitterRoutes);
app.use('/bookings', bookingRoutes);
app.use('/posts', postRoutes);
app.use('/applications', applicationRoutes);
app.use('/conversations', conversationRoutes);
app.use('/tasks', taskRoutes);
app.use('/blocks', blockRoutes);
app.use('/reviews', reviewRoutes);
app.use('/uploads', uploadRoutes);
app.use('/pricing', pricingRoutes);
app.use('/stripe-connect', stripeConnectRoutes);
app.use('/admin', adminRoutes);
app.use('/sitter', ibanRoutes);
app.use('/notifications', notificationRoutes);

module.exports = app;

