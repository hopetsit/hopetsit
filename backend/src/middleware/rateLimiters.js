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

// v23.1 part 128 — Phase 4 audit P4-2 : rate-limit dédié et plus strict
// pour /auth/admin/login. 3 tentatives par 15 minutes — un admin légitime
// connaît ses creds ; au-delà c'est du brute-force.
const adminLoginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 3,
  standardHeaders: true,
  legacyHeaders: false,
  handler: jsonResponse('Too many admin login attempts. Try again in 15 minutes.'),
});

// v23.1 part 128 — Phase 4 audit P4-20 : rate-limit pour le namespace
// /admin/* entier. Si le token admin fuit (XSS, etc.), au moins
// l'attaquant ne peut pas spammer 1000 deletes/s.
const adminLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 120, // 2 actions/sec en moyenne, suffit pour le panel admin légitime
  standardHeaders: true,
  legacyHeaders: false,
  handler: jsonResponse('Too many admin requests. Slow down.'),
});

module.exports = { authLimiter, sensitiveLimiter, adminLoginLimiter, adminLimiter };
