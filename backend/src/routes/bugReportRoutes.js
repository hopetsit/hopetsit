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

const router = express.Router();

const BUG_REPORT_INBOX =
  process.env.BUG_REPORT_INBOX || 'hopetsit@gmail.com';

const resolveModel = (role) =>
  role === 'owner' ? Owner : role === 'walker' ? Walker : Sitter;

router.post('/', requireAuth, async (req, res) => {
  try {
    const { title, description, screen, appVersion, platform } = req.body || {};
    const text = String(description || '').trim();
    if (text.length < 10) {
      return res.status(400).json({
        error: 'Description too short (min 10 chars).',
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
    });

    // Fire-and-forget email to the inbox.
    const mailSubject = `[HoPetSit bug] ${doc.title || doc._id}`;
    const mailBody =
      `Role: ${doc.userRole}\n` +
      `User: ${doc.userName || '?'} <${doc.userEmail || '?'}>\n` +
      `Screen: ${doc.screen || '-'}\n` +
      `App version: ${doc.appVersion || '-'}\n` +
      `Platform: ${doc.platform || '-'}\n` +
      `Created: ${doc.createdAt.toISOString()}\n` +
      `Report ID: ${doc._id}\n\n` +
      `--- Description ---\n${doc.description}\n`;
    const mailHtml =
      `<p><strong>Nouveau bug report HoPetSit</strong></p>` +
      `<ul>` +
      `<li>Role: <b>${doc.userRole}</b></li>` +
      `<li>User: ${doc.userName || '?'} &lt;${doc.userEmail || '?'}&gt;</li>` +
      `<li>Screen: ${doc.screen || '-'}</li>` +
      `<li>App version: ${doc.appVersion || '-'}</li>` +
      `<li>Platform: ${doc.platform || '-'}</li>` +
      `<li>Created: ${doc.createdAt.toISOString()}</li>` +
      `<li>Report ID: <code>${doc._id}</code></li>` +
      `</ul>` +
      `<hr/>` +
      `<pre style="white-space:pre-wrap">${doc.description.replace(/</g, '&lt;')}</pre>`;

    sendEmail(BUG_REPORT_INBOX, mailSubject, mailBody, mailHtml)
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
