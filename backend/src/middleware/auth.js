const jwt = require('jsonwebtoken');

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

const requireAuth = (req, res, next) => {
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
    return next();
  } catch (error) {
    console.error('Auth middleware error', error);
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

