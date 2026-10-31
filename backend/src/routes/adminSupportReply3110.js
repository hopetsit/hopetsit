'use strict';
/**
 * 3110 (ADA, demande de BOB) — réponse support par e-mail depuis l'admin.
 *
 *   POST /api/v1/admin/support-reply   { to, subject, text, bugReportId? }
 *   → 200 { ok, id, to, bugReportId, bugStatus, sent }
 *
 * - e-mail TEXTE simple via emailService.sendEmail (expéditeur = SMTP_FROM, donc contact@hopetsit.com),
 *   signature « L'équipe HoPetSit », Reply-To contact@hopetsit.com (SUPPORT_REPLY_TO pour changer) ;
 * - refus (400) : `to` invalide, adresse +test (jamais d'e-mail aux comptes de test), sujet vide,
 *   texte vide ou > 4 000 caractères, `bugReportId` mal formé ;
 * - journal : collection SupportReply3110 (to, sujet, texte, admin, date, bugReportId) ;
 * - si `bugReportId` existe : le bug passe en `in_progress`, sauf s'il est déjà `fixed`
 *   (ou done / wontfix / duplicate : on ne rouvre pas un bug classé).
 * Aucun e-mail n'est envoyé sans appel explicite de l'admin.
 */
const express = require('express');
const mongoose = require('mongoose');
const { requireAuth, requireRole } = require('../middleware/auth');
const { auditAdmin } = require('../middleware/auditAdmin');
const logger = require('../utils/logger');
const emailService = require('../services/emailService');

const router = express.Router();
const requireAdmin = [requireAuth, requireRole('admin'), auditAdmin];

const MAX_TEXT = 4000;
const REPLY_TO = process.env.SUPPORT_REPLY_TO || 'contact@hopetsit.com';
const SIGNATURE = "\n\n— L'équipe HoPetSit\ncontact@hopetsit.com";
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const KEEP_STATUS = new Set(['fixed', 'done', 'wontfix', 'duplicate']);

/** Pur : valide le corps de la requête. Retourne { error } ou { to, subject, text, bugReportId }. */
function validateSupportReply(body) {
  const b = body && typeof body === 'object' ? body : {};
  const to = String(b.to || '').trim().toLowerCase();
  const subject = String(b.subject || '').trim();
  const text = String(b.text || '').replace(/\r\n/g, '\n').trim();
  const bugReportId = b.bugReportId ? String(b.bugReportId).trim() : null;
  if (!to || !EMAIL_RE.test(to)) return { error: 'Adresse e-mail du destinataire invalide.' };
  if (/\+test/i.test(to)) return { error: 'Pas d\'e-mail aux adresses +test (comptes de test).' };
  if (!subject) return { error: 'Sujet vide.' };
  if (subject.length > 200) return { error: 'Sujet trop long (200 caractères max).' };
  if (!text) return { error: 'Texte vide.' };
  if (text.length > MAX_TEXT) return { error: `Texte trop long (${text.length} > ${MAX_TEXT} caractères).` };
  if (bugReportId && !mongoose.Types.ObjectId.isValid(bugReportId)) return { error: 'bugReportId invalide.' };
  return { to, subject, text, bugReportId };
}

router.post('/', requireAdmin, async (req, res) => {
  const v = validateSupportReply(req.body);
  if (v.error) return res.status(400).json({ error: v.error });
  const { to, subject, text, bugReportId } = v;
  try {
    const BugReport = require('../models/BugReport');
    const SupportReply = require('../models/SupportReply3110');

    let bug = null;
    if (bugReportId) bug = await BugReport.findById(bugReportId);

    const fullText = `${text}${SIGNATURE}`;
    const info = await emailService.sendEmail(to, subject, fullText, null, { replyTo: REPLY_TO });
    const sent = !(info && info.skipped);

    let bugStatusBefore = ''; let bugStatusAfter = '';
    if (bug) {
      bugStatusBefore = bug.status || 'open';
      if (!KEEP_STATUS.has(bugStatusBefore) && bugStatusBefore !== 'in_progress') {
        bug.status = 'in_progress';
        await bug.save();
      }
      bugStatusAfter = bug.status;
    }

    const row = await SupportReply.create({
      to, subject, text: fullText, adminId: String((req.user && req.user.id) || ''),
      bugReportId: bug ? bug._id : null, bugStatusBefore, bugStatusAfter,
      messageId: (info && info.messageId) ? String(info.messageId) : '',
    });
    logger.info(`[admin/support-reply] sent=${sent} id=${row._id} bug=${bug ? bug._id : '-'} admin=${row.adminId}`);
    return res.json({
      ok: true, id: String(row._id), to, sent, skipped: sent ? null : (info && info.reason) || null,
      bugReportId: bug ? String(bug._id) : null, bugFound: !!bug || (bugReportId ? false : null), bugStatus: bugStatusAfter || null,
    });
  } catch (e) {
    logger.error('[admin/support-reply] failed', e);
    return res.status(500).json({ error: 'Envoi impossible : ' + (e && e.message ? e.message : 'erreur serveur') });
  }
});

module.exports = router;
module.exports.validateSupportReply = validateSupportReply;
