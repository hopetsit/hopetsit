/**
 * Sprint 8 step 6 — optional Sentry error tracking.
 * Active only when SENTRY_DSN_BACKEND is set; otherwise a no-op.
 */
const logger = require('./logger');

let Sentry = null;
let initialised = false;

const init = () => {
  if (initialised) return Sentry;
  const dsn = process.env.SENTRY_DSN_BACKEND;
  if (!dsn) return null;
  try {
    Sentry = require('@sentry/node');
    Sentry.init({
      dsn,
      environment: process.env.NODE_ENV || 'development',
      tracesSampleRate: Number(process.env.SENTRY_TRACES_SAMPLE_RATE || '0'),
    });
    initialised = true;
    logger.info('[sentry] initialised');
    return Sentry;
  } catch (e) {
    logger.warn('[sentry] init failed', e.message || e);
    return null;
  }
};

const captureException = (err, context) => {
  if (!Sentry) return;
  try {
    if (context) Sentry.setContext('details', context);
    Sentry.captureException(err);
  } catch (_) { /* noop */ }
};

module.exports = { init, captureException };
