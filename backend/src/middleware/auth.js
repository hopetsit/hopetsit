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
    if (payload.role === 'owner' || payload.role === 'sitter') {
      const Model = payload.role === 'sitter'
        ? require('../models/Sitter')
        : require('../models/Owner');
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
      return res.status(403).json({ error: 'You do not have permission to perform this action.' });
    }
    return next();
  };

module.exports = {
  requireAuth,
  requireRole,
};

