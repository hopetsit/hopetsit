const express = require('express');
const logger = require('../utils/logger');
const { unsubscribeToken, runLifecycleOnce } = require('../services/lifecycleEmailScheduler');

const router = express.Router();

// v560 — désabonnement des e-mails de cycle de vie (lien en pied de chaque
// e-mail, jeton HMAC — aucun secret ni connexion requis).
router.get('/unsubscribe', async (req, res) => {
  const role = String(req.query.r || '');
  const id = String(req.query.u || '');
  const t = String(req.query.t || '');
  const ok = ['owner', 'sitter', 'walker'].includes(role) && /^[a-f0-9]{24}$/i.test(id) && t && t === unsubscribeToken(role, id);
  let done = false;
  if (ok) {
    try {
      const Model = require(`../models/${role === 'owner' ? 'Owner' : role === 'sitter' ? 'Sitter' : 'Walker'}`);
      const r = await Model.updateOne({ _id: id }, { $set: { marketingOptOut: true } });
      done = r.matchedCount > 0 || r.n > 0;
    } catch (e) {
      logger.warn(`[lifecycle] unsubscribe failed : ${e?.message || e}`);
    }
  }
  res.status(ok ? 200 : 400).type('html').send(`<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>HoPetSit</title></head>
<body style="font-family:Arial,Helvetica,sans-serif;max-width:520px;margin:60px auto;padding:24px;color:#222;text-align:center">
<h2 style="color:#C92A12">HoPetSit</h2>
<p style="font-size:16px">${done
    ? 'C’est noté : tu ne recevras plus nos e-mails de conseils. Les e-mails liés à tes réservations et paiements restent actifs.<br><br>Done: you will no longer receive our tips emails. Booking and payment emails stay active.'
    : 'Lien invalide ou expiré. / Invalid or expired link.'}</p>
<p><a href="https://www.hopetsit.com" style="color:#C92A12">hopetsit.com</a></p></body></html>`);
});

// Déclenchement manuel (admin) — utile pour tester en prod sans attendre l'heure.
router.post('/run', async (req, res) => {
  const key = String(req.headers['x-admin-key'] || '');
  if (!process.env.LIFECYCLE_ADMIN_KEY || key !== process.env.LIFECYCLE_ADMIN_KEY) {
    return res.status(403).json({ error: 'forbidden' });
  }
  try {
    const r = await runLifecycleOnce({ max: Number(req.query.max || 40) });
    return res.json(r);
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

module.exports = router;
