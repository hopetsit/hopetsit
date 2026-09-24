/**
 * Bug Report Routes — v20.0.8
 *
 * POST /bug-reports         → authenticated user submits a bug
 *   Side-effect: email to hopetsit@gmail.com so the owner sees it immediately.
 */
const express = require('express');
const { requireAuth } = require('../middleware/auth');
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

module.exports = router;
