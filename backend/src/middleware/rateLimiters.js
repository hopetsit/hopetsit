const rateLimit = require('express-rate-limit');

const jsonResponse = (message) => (req, res) => {
  res.status(429).json({
    error: 'Too many requests',
    message,
    retryAfter: res.getHeader('Retry-After'),
  });
};

// v532 — le tunnel d'inscription (signup → verify → resend → auto-login) tient
// en 4 à 6 appels et passait TOUS par la même limite de 5/min/IP : un
// utilisateur qui se trompait d'un chiffre dans son code OTP se faisait
// éjecter en 429 « Too many authentication attempts » AVANT l'auto-login,
// compte vérifié mais session perdue. Aggravant : la limite est par IP, donc
// deux personnes sur le même WiFi (ou derrière un CGNAT opérateur) se
// bloquaient mutuellement.
// On sépare désormais :
//   - authLimiter (12/min)         : login, mots de passe oubliés, OAuth…
//   - signupFlowLimiter (30/min)   : signup, vérification email, renvoi de code
// Le brute-force reste couvert : 12 essais de mot de passe par minute et par
// IP n'ouvrent aucune attaque réaliste, et /auth/admin/login garde sa limite
// dédiée de 3 essais / 15 min.
const authLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 12,
  standardHeaders: true,
  legacyHeaders: false,
  handler: jsonResponse('Too many authentication attempts. Try again in a minute.'),
});

const SIGNUP_FLOW_PATHS = new Set([
  '/signup',
  '/verify',
  '/resend-code',
]);

/** Vrai pour les endpoints du tunnel d'inscription (montés sous /auth). */
const isSignupFlow = (req) => SIGNUP_FLOW_PATHS.has(req.path);

const signupFlowLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  standardHeaders: true,
  legacyHeaders: false,
  handler: jsonResponse('Too many verification attempts. Try again in a minute.'),
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

module.exports = {
  authLimiter,
  signupFlowLimiter,
  isSignupFlow,
  sensitiveLimiter,
  adminLoginLimiter,
  adminLimiter,
};
