const rateLimit = require('express-rate-limit');

const jsonResponse = (message) => (req, res) => {
  res.status(429).json({
    error: 'Too many requests',
    message,
    retryAfter: res.getHeader('Retry-After'),
  });
};

const authLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  handler: jsonResponse('Too many authentication attempts. Try again in a minute.'),
});

const sensitiveLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  handler: jsonResponse('Too many requests on sensitive endpoint. Slow down.'),
});

module.exports = { authLimiter, sensitiveLimiter };
