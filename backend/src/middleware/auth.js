const jwt = require('jsonwebtoken');
const logger = require('../utils/logger');

const getTokenFromHeader = (authorizationHeader = '') => {
  if (typeof authorizationHeader !== 'string') {
    return null;
  }
  const trimmed = authorizationHeader.trim();
  if (!trimmed.toLowerCase().startsWith('bearer ')) {
    return null;
  }
  return trimmed.slice(7).trim();
};

const verifyToken = (token) => {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    throw new Error('JWT_SECRET environment variable is not configured.');
  }
  return jwt.verify(token, secret);
};

const requireAuth = async (req, res, next) => {
  try {
    const token = getTokenFromHeader(req.headers.authorization);
    if (!token) {
      return res.status(401).json({ error: 'Authorization token is required.' });
    }
    const payload = verifyToken(token);
    req.user = {
      id: payload.id,
      role: payload.role,
    };
    // Sprint 7 step 6 — block suspended/banned accounts.
    // Extended to cover the walker role alongside owner and sitter.
    const ROLE_TO_MODEL_PATH = {
      owner: '../models/Owner',
      sitter: '../models/Sitter',
      walker: '../models/Walker',
    };
    const modelPath = ROLE_TO_MODEL_PATH[payload.role];
    if (modelPath) {
      const Model = require(modelPath);
      const user = await Model.findById(payload.id).select('status').lean();
      if (user && user.status && user.status !== 'active') {
        const msg = user.status === 'suspended'
          ? 'Account suspended. Please contact support.'
          : 'Account banned.';
        return res.status(401).json({ error: msg, status: user.status });
      }
    }
    return next();
  } catch (error) {
    logger.error('Auth middleware error', error);
    if (error.name === 'JsonWebTokenError' || error.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Invalid or expired authorization token.' });
    }
    return res.status(500).json({ error: 'Authentication failed. Please try again later.' });
  }
};

const requireRole =
  (...allowedRoles) =>
  (req, res, next) => {
    if (!req.user) {
      return res.status(500).json({ error: 'Authentication context missing.' });
    }
    if (!allowedRoles.includes(req.user.role)) {
      // v23.1 — explicit logging so we can identify WHICH endpoint a 403
      // came from when bug reports come in. Daniel reports walker hitting
      // 'You do not have permission' — this tells us exactly which route.
      logger.warn(
        {
          path: req.originalUrl,
          method: req.method,
          userRole: req.user.role,
          allowedRoles,
        },
        '[requireRole] 403 forbidden',
      );
      return res.status(403).json({
        error: 'You do not have permission to perform this action.',
        code: 'FORBIDDEN_ROLE',
        // v23.1 — surface path + role in `details` so the toast (which now
        // prefers `details`) shows the actionable info directly.
        details: `${req.method} ${req.originalUrl} requires role(s): ${allowedRoles.join('|')} (you are: ${req.user.role})`,
        debug: {
          path: req.originalUrl,
          method: req.method,
          yourRole: req.user.role,
          allowedRoles,
        },
      });
    }
    return next();
  };

// v535 — SPEC ONBOARDING P2 : l'OTP email n'est plus bloquant au login ; en
// contrepartie, les actions qui ENGAGENT DE L'ARGENT exigent un email
// vérifié. Posé sur : payer une garde (create-payment-intent) et retirer ses
// gains (/wallet/withdraw). L'app mappe le code EMAIL_NOT_VERIFIED vers
// l'écran de saisie du code (le code est renvoyé par /auth/resend-code).
const requireVerifiedEmail = async (req, res, next) => {
  try {
    const role = String(req.user?.role || '').toLowerCase();
    const Model = role === 'walker'
      ? require('../models/Walker')
      : role === 'sitter'
        ? require('../models/Sitter')
        : require('../models/Owner');
    const doc = await Model.findById(req.user.id).select('verified').lean();
    if (!doc) return res.status(404).json({ error: 'User not found.' });
    if (doc.verified !== true) {
      return res.status(403).json({
        error: 'Please verify your email to continue.',
        code: 'EMAIL_NOT_VERIFIED',
      });
    }
    return next();
  } catch (e) {
    return res.status(500).json({ error: 'Verification check failed.' });
  }
};

module.exports = {
  requireAuth,
  requireRole,
  requireVerifiedEmail,
};

