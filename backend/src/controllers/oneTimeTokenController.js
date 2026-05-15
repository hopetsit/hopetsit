const crypto = require('crypto');
const jwt = require('jsonwebtoken');

const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const OneTimeToken = require('../models/OneTimeToken');
const { sanitizeUser } = require('../utils/sanitize');
const logger = require('../utils/logger');

/**
 * v23.1 part 146 — Bridge de session web → app via deep link.
 * Voir docstring détaillée dans `models/OneTimeToken.js`.
 */

const TTL_SECONDS = 60;
const TOKEN_HEX_REGEX = /^[a-f0-9]{64}$/;

const ROLE_TO_MODEL = {
  owner: Owner,
  sitter: Sitter,
  walker: Walker,
};

const signAuthToken = (payload, options = {}) => {
  if (!process.env.JWT_SECRET) {
    throw new Error('JWT_SECRET environment variable is not configured.');
  }
  return jwt.sign(payload, process.env.JWT_SECRET, {
    expiresIn: '30d',
    ...options,
  });
};

/**
 * POST /auth/one-time-token
 * Body: aucun (auth requise via `requireAuth` middleware)
 * Réponse: { ott: '<64 hex>', expiresIn: 60 }
 *
 * Le token brut n'est retourné qu'UNE seule fois ici. Le site doit
 * immédiatement l'utiliser pour rediriger vers `hopetsit://auth?ott=...`.
 */
const createOneTimeToken = async (req, res) => {
  try {
    const { id, role } = req.user; // posé par requireAuth
    if (!id || !ROLE_TO_MODEL[role]) {
      return res.status(400).json({ error: 'Invalid auth context.' });
    }

    // 32 bytes = 256 bits d'entropie, 64 chars hex.
    const rawToken = crypto.randomBytes(32).toString('hex');
    const tokenHash = crypto
      .createHash('sha256')
      .update(rawToken)
      .digest('hex');

    const expiresAt = new Date(Date.now() + TTL_SECONDS * 1000);

    await OneTimeToken.create({
      tokenHash,
      userId: id,
      role,
      expiresAt,
      issuedFromIp:
        (req.headers['x-forwarded-for'] || req.ip || '').split(',')[0].trim() ||
        undefined,
      issuedUserAgent: req.headers['user-agent']
        ? String(req.headers['user-agent']).slice(0, 256)
        : undefined,
    });

    logger.info(
      { userId: id, role, expiresIn: TTL_SECONDS },
      '[one-time-token] issued',
    );

    return res.json({
      ott: rawToken,
      expiresIn: TTL_SECONDS,
    });
  } catch (error) {
    logger.error({ err: error }, '[createOneTimeToken] failed');
    if (error.message && error.message.includes('JWT_SECRET')) {
      return res
        .status(500)
        .json({ error: 'Server misconfigured (JWT_SECRET missing).' });
    }
    return res
      .status(500)
      .json({ error: 'Failed to create one-time token. Please try again.' });
  }
};

/**
 * POST /auth/exchange
 * Body: { token: '<64 hex>' }
 * Réponse: { token: '<JWT 30j>', role, user }
 *
 * Pas d'auth requise — c'est justement ce endpoint qui CRÉE l'auth.
 * Le token est validé + marqué `used` de manière atomique pour
 * empêcher tout double-spending.
 */
const exchangeOneTimeToken = async (req, res) => {
  try {
    const { token } = req.body || {};

    // Validation format STRICTE avant query Mongo (anti-injection).
    if (
      !token ||
      typeof token !== 'string' ||
      !TOKEN_HEX_REGEX.test(token)
    ) {
      return res.status(400).json({ error: 'Invalid token format.' });
    }

    const tokenHash = crypto
      .createHash('sha256')
      .update(token)
      .digest('hex');

    // Atomic find + mark used. Si le token est expiré ou déjà utilisé,
    // findOneAndUpdate retourne null.
    const tokenDoc = await OneTimeToken.findOneAndUpdate(
      {
        tokenHash,
        used: false,
        expiresAt: { $gt: new Date() },
      },
      { $set: { used: true } },
      { new: true },
    ).lean();

    if (!tokenDoc) {
      return res
        .status(401)
        .json({ error: 'Invalid, expired, or already used token.' });
    }

    const Model = ROLE_TO_MODEL[tokenDoc.role];
    if (!Model) {
      return res.status(500).json({ error: 'Invalid role on token.' });
    }

    const account = await Model.findById(tokenDoc.userId);
    if (!account) {
      return res.status(404).json({ error: 'User not found.' });
    }

    // v23.1 part 146 — refuse les comptes suspended/banned, comme le
    // fait `requireAuth` pour les autres endpoints. Sinon un attaquant
    // qui a obtenu un OTT avant la suspension pourrait s'en servir
    // pour se reconnecter dans la fenêtre TTL.
    if (account.status && account.status !== 'active') {
      return res
        .status(401)
        .json({
          error:
            account.status === 'suspended'
              ? 'Account suspended. Please contact support.'
              : 'Account banned.',
          status: account.status,
        });
    }

    const newJwt = signAuthToken({ id: account._id, role: tokenDoc.role });

    logger.info(
      { userId: tokenDoc.userId, role: tokenDoc.role },
      '[one-time-token] exchanged successfully',
    );

    return res.json({
      token: newJwt,
      role: tokenDoc.role,
      user: sanitizeUser(account.toObject(), tokenDoc.role),
    });
  } catch (error) {
    logger.error({ err: error }, '[exchangeOneTimeToken] failed');
    return res
      .status(500)
      .json({ error: 'Failed to exchange token. Please try again.' });
  }
};

module.exports = {
  createOneTimeToken,
  exchangeOneTimeToken,
};
