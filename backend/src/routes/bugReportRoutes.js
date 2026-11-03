/**
 * Bug Report Routes — v20.0.8
 *
 * POST /bug-reports         → authenticated user submits a bug
 *   Side-effect: email to hopetsit@gmail.com so the owner sees it immediately.
 */
const express = require('express');
const { requireAuth, optionalAuth } = require('../middleware/auth');
const BugReport = require('../models/BugReport');
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const { sendEmail } = require('../services/emailService');
const logger = require('../utils/logger');
const {
  normalizeKind,
  minDescriptionLength,
  mailSubject,
} = require('../utils/bugReportKind');

const router = express.Router();

const BUG_REPORT_INBOX =
  process.env.BUG_REPORT_INBOX || 'hopetsit@gmail.com';

const resolveModel = (role) =>
  role === 'owner' ? Owner : role === 'walker' ? Walker : Sitter;

router.post('/', requireAuth, async (req, res) => {
  try {
    const { title, description, screen, appVersion, platform, kind } =
      req.body || {};
    // v585 (lot D) — boîte à idées : même route, étiquette `kind`.
    const reportKind = normalizeKind(kind);
    const minLen = minDescriptionLength(reportKind);
    const text = String(description || '').trim();
    if (text.length < minLen) {
      return res.status(400).json({
        error: `Description too short (min ${minLen} chars).`,
      });
    }

    // Fetch user info for the report + email.
    const Model = resolveModel(req.user.role);
    const user = await Model.findById(req.user.id)
      .select('name email')
      .lean();

    const doc = await BugReport.create({
      userId: req.user.id,
      userRole: req.user.role,
      userName: user?.name || '',
      userEmail: user?.email || '',
      title: String(title || '').slice(0, 120),
      description: text.slice(0, 4000),
      screen: String(screen || '').slice(0, 120),
      appVersion: String(appVersion || '').slice(0, 40),
      platform: String(platform || '').slice(0, 20),
      kind: reportKind,
    });

    // Fire-and-forget email to the inbox.
    const subject = mailSubject(doc);
    const kindLabel = reportKind === 'idea' ? 'Idée' : 'Problème';
    const mailBody =
      `Type: ${kindLabel}\n` +
      `Role: ${doc.userRole}\n` +
      `User: ${doc.userName || '?'} <${doc.userEmail || '?'}>\n` +
      `Screen: ${doc.screen || '-'}\n` +
      `App version: ${doc.appVersion || '-'}\n` +
      `Platform: ${doc.platform || '-'}\n` +
      `Created: ${doc.createdAt.toISOString()}\n` +
      `Report ID: ${doc._id}\n\n` +
      `--- Description ---\n${doc.description}\n`;
    const esc = (s) => String(s || '').replace(/</g, '&lt;');
    const mailHtml =
      `<p><strong>${reportKind === 'idea' ? 'Nouvelle idée' : 'Nouveau bug report'} HoPetSit</strong></p>` +
      `<ul>` +
      `<li>Type: <b>${kindLabel}</b></li>` +
      `<li>Role: <b>${doc.userRole}</b></li>` +
      `<li>User: ${esc(doc.userName) || '?'} &lt;${esc(doc.userEmail) || '?'}&gt;</li>` +
      `<li>Screen: ${doc.screen || '-'}</li>` +
      `<li>App version: ${doc.appVersion || '-'}</li>` +
      `<li>Platform: ${doc.platform || '-'}</li>` +
      `<li>Created: ${doc.createdAt.toISOString()}</li>` +
      `<li>Report ID: <code>${doc._id}</code></li>` +
      `</ul>` +
      `<hr/>` +
      `<pre style="white-space:pre-wrap">${doc.description.replace(/</g, '&lt;')}</pre>`;

    sendEmail(BUG_REPORT_INBOX, subject, mailBody, mailHtml)
      .then(() => {
        BugReport.updateOne({ _id: doc._id }, { emailDispatched: true }).catch(
          () => {},
        );
      })
      .catch((e) => {
        logger.warn('[bugReport] email dispatch failed', e);
      });

    res.json({ ok: true, reportId: doc._id });
  } catch (e) {
    logger.error('[bugReport] create', e);
    res.status(500).json({ error: e.message });
  }
});

/**
 * 03/11/2026 (Daniel : « dans le site, rajoute signaler un bug, connecté à l'admin ») —
 * POST /bug-reports/public : formulaire du pied de page, OUVERT aux visiteurs.
 * Connecté → rattaché au compte (comme l'app) ; sinon rôle `visitor` + e-mail saisi
 * (obligatoire, pour pouvoir répondre). Anti-robot : champ piège `website` rempli → 200
 * silencieux, rien d'écrit. Limiteur `sensitiveLimiter` posé sur /bug-reports (app.js).
 * Même modèle, même boîte mail, même page admin › Bugs.
 */
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
router.post('/public', optionalAuth, async (req, res) => {
  try {
    const b = req.body || {};
    if (String(b.website || '').trim()) return res.json({ ok: true }); // robot
    const reportKind = normalizeKind(b.kind);
    const minLen = minDescriptionLength(reportKind);
    const text = String(b.description || '').trim();
    if (text.length < minLen) return res.status(400).json({ error: `Description too short (min ${minLen} chars).`, code: 'TOO_SHORT' });
    let userId = null; let userRole = 'visitor'; let userName = String(b.name || '').trim().slice(0, 80); let userEmail = String(b.email || '').trim().toLowerCase().slice(0, 160);
    if (req.user && req.user.id && ['owner', 'sitter', 'walker'].includes(req.user.role)) {
      const u = await resolveModel(req.user.role).findById(req.user.id).select('name email').lean();
      if (u) { userId = req.user.id; userRole = req.user.role; userName = u.name || userName; userEmail = u.email || userEmail; }
    }
    if (userRole === 'visitor' && !EMAIL_RE.test(userEmail)) return res.status(400).json({ error: 'A valid email is required.', code: 'EMAIL_REQUIRED' });
    const doc = await BugReport.create({
      userId, userRole, userName, userEmail,
      title: String(b.title || text.slice(0, 60)).slice(0, 120),
      description: text.slice(0, 4000),
      screen: String(b.screen || 'web:footer').slice(0, 120),
      appVersion: 'web',
      platform: 'web',
      kind: reportKind,
    });
    const esc = (x) => String(x || '').replace(/&/g, '&amp;').replace(/</g, '&lt;');
    const kindLabel = reportKind === 'idea' ? 'Idée' : 'Problème';
    const mailBody = `Type: ${kindLabel} (site web)\nRole: ${userRole}\nUser: ${userName || '?'} <${userEmail || '?'}>\nPage: ${doc.screen}\nReport ID: ${doc._id}\n\n--- Description ---\n${doc.description}\n`;
    const mailHtml = `<p><strong>${reportKind === 'idea' ? 'Nouvelle idée' : 'Nouveau bug'} HoPetSit — site web</strong></p>`
      + `<ul><li>Type: <b>${kindLabel}</b></li><li>Role: <b>${esc(userRole)}</b></li><li>User: ${esc(userName) || '?'} &lt;${esc(userEmail) || '?'}&gt;</li>`
      + `<li>Page: ${esc(doc.screen)}</li><li>Report ID: <code>${doc._id}</code></li></ul><hr/><pre style="white-space:pre-wrap">${esc(doc.description)}</pre>`;
    sendEmail(BUG_REPORT_INBOX, mailSubject(doc), mailBody, mailHtml)
      .then(() => BugReport.updateOne({ _id: doc._id }, { emailDispatched: true }).catch(() => {}))
      .catch((e) => logger.warn('[bugReport] public email dispatch failed', e));
    return res.json({ ok: true, reportId: doc._id });
  } catch (e) {
    logger.error('[bugReport] public create', e);
    return res.status(500).json({ error: 'Could not send the report.' });
  }
});

module.exports = router;
