// v23.1 part 133 — Phase 7 audit P7-24 : middleware d'audit pour les
// actions admin write. Posé APRÈS requireAdmin et AVANT le handler de
// route. Capture la réponse via hook sur res.json() et insère un log
// AdminAuditLog en best-effort. Aucune influence sur la réponse client.
const AdminAuditLog = require('../models/AdminAuditLog');
const logger = require('../utils/logger');

const WRITE_METHODS = new Set(['POST', 'PUT', 'PATCH', 'DELETE']);

const auditAdmin = async (req, res, next) => {
  if (!WRITE_METHODS.has(req.method)) return next();
  const start = Date.now();
  const origJson = res.json.bind(res);

  // Best-effort capture pour les notes.
  const safeParams = {};
  try {
    for (const k of Object.keys(req.params || {})) safeParams[k] = String(req.params[k]).slice(0, 64);
    for (const k of Object.keys(req.query || {})) safeParams[`q_${k}`] = String(req.query[k]).slice(0, 64);
  } catch (_) { /* ignore */ }

  res.json = (body) => {
    try {
      // Fire-and-forget : on n'attend pas que l'insert finisse pour
      // répondre au client (évite tout impact latence). Si Mongo est
      // down, on log côté logger.
      AdminAuditLog.create({
        adminId: req.user?.id,
        adminEmail: req.user?.email || '',
        action: `${req.method.toLowerCase()}_${(req.path || '').replace(/^\//, '').replace(/\//g, '_').slice(0, 80)}`,
        method: req.method,
        path: req.originalUrl || req.path || '',
        ip: req.ip || '',
        userAgent: (req.headers['user-agent'] || '').slice(0, 500),
        statusCode: res.statusCode,
        params: safeParams,
        // Pas de body complet (RGPD + bruit). On log uniquement le
        // 'success' boolean pour status correct.
        notes: `dur=${Date.now() - start}ms`,
      }).catch((e) => {
        logger.warn(`[auditAdmin] log insert failed: ${e?.message || e}`);
      });
    } catch (e) {
      logger.warn(`[auditAdmin] sync error: ${e?.message || e}`);
    }
    return origJson(body);
  };

  next();
};

module.exports = { auditAdmin };
