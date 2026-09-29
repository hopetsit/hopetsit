const mongoose = require('mongoose');
const logger = require('../utils/logger');

/**
 * v599 (ZOE, 29/09/2026) — E-MAIL DIFFÉRÉ « message non lu » (décision Daniel, 29/09 08 h).
 *
 * Règle : l'e-mail lié aux messages ne part que si le PREMIER message non lu d'une
 * conversation est TOUJOURS non lu après 15 minutes, UNE seule fois par
 * conversation tant qu'elle n'est pas lue. Lire la conversation (n'importe quel
 * appareil ou le site — le « lu » est synchronisé) annule l'attente ; après une
 * lecture, le prochain message repose une attente neuve. Aucun e-mail par
 * message, aucun e-mail aux comptes `+test`.
 *
 * Mécanique (robuste au redémarrage de Render, pas un setTimeout) :
 *   1. `scheduleUnreadEmail` : au message, UPSERT d'une attente
 *      (conversationId, recipientId) avec `unreadEmailDueAt = maintenant + 15 min`.
 *      Index unique → un 2e ou 3e message ne crée rien (idempotent).
 *   2. `cancelUnreadEmail` : à la lecture, suppression des attentes de ce fil pour
 *      cette personne (ses 3 profils). Appelé par chatReadSync599.afterConversationRead
 *      (REST, socket, ouverture du fil) et par la suppression de conversation.
 *   3. `runOnce` : balayage toutes les minutes. Chaque attente échue est RÉCLAMÉE
 *      atomiquement (findOneAndUpdate sur « pas encore réclamée ») avant l'envoi :
 *      jamais deux e-mails pour la même attente, même à deux instances. Avant
 *      d'envoyer, on relit la conversation : si elle a été lue entre-temps (ou
 *      supprimée, ou ouverte à l'écran), l'attente est effacée sans e-mail.
 *      Après l'envoi, l'attente reste (sentAt posé) jusqu'à la lecture : aucun
 *      autre e-mail pour ce fil tant qu'il n'est pas lu.
 * Panne d'envoi : la réclamation est rendue, 3 essais au plus. Un serveur qui
 * meurt entre la réclamation et l'envoi perd cet e-mail (jamais de doublon :
 * c'est la règle la plus forte) ; la lecture efface l'attente et le fil repart.
 */

const DELAY_MS = 15 * 60 * 1000;
const TICK_MS = 60 * 1000;
const MAX_ATTEMPTS = 3;
const BATCH_LIMIT = 200;
const TEST_EMAIL_RE = /\+test/i;

let timer = null;
let running = false;

const Model = () => require('../models/ChatUnreadEmail599');
const idOf = (v) => (v ? String(v._id || v.id || v) : '');
const dbReady = () => mongoose.connection && mongoose.connection.readyState === 1;
const isTestEmail = (email) => TEST_EMAIL_RE.test(String(email || ''));

/**
 * Pose l'attente (ou ne fait rien si une attente existe déjà pour ce fil et ce
 * destinataire, envoyée ou non). Retourne { created } ; ne lève jamais.
 */
const scheduleUnreadEmail = async ({
  conversationId, recipientId, recipientRole, recipientIds = null, payload = {}, now = Date.now(),
}) => {
  const cid = idOf(conversationId);
  const rid = idOf(recipientId);
  const role = String(recipientRole || '').toLowerCase();
  if (!cid || !rid || !['owner', 'sitter', 'walker'].includes(role)) {
    return { created: false, reason: 'bad_args' };
  }
  if (!dbReady()) {
    logger.warn(`[chat.email.defer] base indisponible : attente non posée (conv ${cid}, ${role}:${rid})`);
    return { created: false, reason: 'db' };
  }
  const ids = Array.from(new Set([rid, ...((Array.isArray(recipientIds) ? recipientIds : []).map(String))]));
  const dueAt = new Date(Number(now) + DELAY_MS);
  try {
    const r = await Model().updateOne(
      { conversationId: cid, recipientId: rid },
      {
        $setOnInsert: {
          conversationId: cid,
          recipientId: rid,
          recipientRole: role,
          recipientIds: ids,
          unreadEmailDueAt: dueAt,
          claimedAt: null,
          sentAt: null,
          attempts: 0,
          lastError: '',
          payload: {
            userId: String(payload.userId || rid),
            role: String(payload.role || role),
            type: String(payload.type || 'NEW_MESSAGE'),
            data: payload.data && typeof payload.data === 'object' ? payload.data : {},
            actor: payload.actor || null,
          },
        },
      },
      { upsert: true },
    );
    const created = Boolean(r && (r.upsertedCount || r.upsertedId));
    logger.info(
      created
        ? `[chat.email.defer] attente posée conv ${cid} → ${role}:${rid}, échéance ${dueAt.toISOString()}`
        : `[chat.email.defer] attente déjà en place conv ${cid} → ${role}:${rid} : rien à faire`,
    );
    return { created, dueAt };
  } catch (e) {
    // Course entre deux messages simultanés : l'index unique tranche.
    if (e && (e.code === 11000 || /E11000/.test(String(e.message || '')))) {
      return { created: false, reason: 'exists' };
    }
    logger.warn(`[chat.email.defer] pose échouée conv ${cid} : ${e && e.message ? e.message : e}`);
    return { created: false, reason: 'error' };
  }
};

/**
 * La personne a lu le fil (ou l'a supprimé) : plus d'attente pour elle sur ce fil.
 * Retourne { cancelled } ; ne lève jamais.
 */
const cancelUnreadEmail = async ({ conversationId, readerIds }) => {
  const cid = idOf(conversationId);
  const ids = (Array.isArray(readerIds) ? readerIds : [readerIds]).map(idOf).filter(Boolean);
  if (!cid || !ids.length) return { cancelled: 0, reason: 'bad_args' };
  if (!dbReady()) return { cancelled: 0, reason: 'db' };
  try {
    const r = await Model().deleteMany({
      conversationId: cid,
      $or: [{ recipientId: { $in: ids } }, { recipientIds: { $in: ids } }],
    });
    const n = (r && r.deletedCount) || 0;
    if (n) logger.info(`[chat.email.defer] lecture conv ${cid} : ${n} attente(s) annulée(s)`);
    return { cancelled: n };
  } catch (e) {
    logger.warn(`[chat.email.defer] annulation échouée conv ${cid} : ${e && e.message ? e.message : e}`);
    return { cancelled: 0, reason: 'error' };
  }
};

/** Vrai si le destinataire de l'attente a encore du non-lu sur cette conversation. */
const isStillUnread = (conversation, pending) => {
  if (!conversation) return false;
  const mine = new Set([String(pending.recipientId), ...((pending.recipientIds || []).map(String))]);
  if (conversation.friendChat === true && Array.isArray(conversation.participants)) {
    return conversation.participants.some(
      (p) => p && mine.has(idOf(p.userId)) && Number(p.unreadCount || 0) > 0,
    );
  }
  const ownerId = idOf(conversation.ownerId);
  const providerId = idOf(conversation.sitterId) || idOf(conversation.walkerId);
  if (ownerId && mine.has(ownerId)) return Number(conversation.ownerUnreadCount || 0) > 0;
  if (providerId && mine.has(providerId)) return Number(conversation.sitterUnreadCount || 0) > 0;
  return false; // plus membre du fil → rien à envoyer
};

const loadConversation = async (cid) => {
  const Conversation = require('../models/Conversation');
  let conv = await Conversation.findById(cid).lean();
  if (conv && conv.mergedInto) {
    const target = await Conversation.findById(conv.mergedInto).lean();
    if (target) conv = target;
  }
  return conv;
};

const conversationOpenFor = async (cid, ids) => {
  try {
    const emitter = require('../sockets/emitter');
    if (typeof emitter.isConversationOpenFor !== 'function') return false;
    return Boolean(await emitter.isConversationOpenFor(cid, ids));
  } catch (_) {
    return false;
  }
};

/**
 * Un balayage : traite les attentes échues. Retourne des compteurs.
 * `now` est injectable (tests) ; jamais deux balayages en même temps dans un processus.
 */
const runOnce = async ({ now = Date.now(), limit = BATCH_LIMIT } = {}) => {
  const out = { due: 0, sent: 0, cancelled: 0, skipped: 0, failed: 0 };
  if (!dbReady()) return { ...out, reason: 'db' };
  if (running) return { ...out, reason: 'busy' };
  running = true;
  try {
    const M = Model();
    const due = await M.find({
      sentAt: null,
      claimedAt: null,
      unreadEmailDueAt: { $lte: new Date(Number(now)) },
    }).sort({ unreadEmailDueAt: 1 }).limit(limit).select('_id').lean();
    out.due = due.length;
    for (const d of due) {
      // Réclamation atomique : une seule instance emporte cette attente.
      // eslint-disable-next-line no-await-in-loop
      const pending = await M.findOneAndUpdate(
        { _id: d._id, sentAt: null, claimedAt: null },
        { $set: { claimedAt: new Date(Number(now)) }, $inc: { attempts: 1 } },
        { new: true },
      ).lean();
      if (!pending) { out.skipped += 1; continue; }
      const cid = String(pending.conversationId);
      const who = `${pending.recipientRole}:${pending.recipientId}`;
      const ids = Array.from(new Set([String(pending.recipientId), ...((pending.recipientIds || []).map(String))]));
      try {
        // eslint-disable-next-line no-await-in-loop
        const conversation = await loadConversation(cid);
        // eslint-disable-next-line no-await-in-loop
        const stillUnread = isStillUnread(conversation, pending) && !(await conversationOpenFor(cid, ids));
        if (!stillUnread) {
          // eslint-disable-next-line no-await-in-loop
          await M.deleteOne({ _id: pending._id });
          out.cancelled += 1;
          logger.info(`[chat.email.defer] conv ${cid} lue avant l'échéance (${who}) : aucun e-mail`);
          continue;
        }
        const { sendDeferredChatEmail } = require('./notificationSender');
        // eslint-disable-next-line no-await-in-loop
        const r = await sendDeferredChatEmail(pending.payload || {});
        // Envoyé OU sans objet (pas d'e-mail, catégorie coupée, compte +test) :
        // l'attente est close jusqu'à la lecture, aucun autre e-mail pour ce fil.
        // eslint-disable-next-line no-await-in-loop
        await M.updateOne(
          { _id: pending._id },
          { $set: { sentAt: new Date(Number(now)), lastError: r && r.skipped ? String(r.reason || 'skipped') : '' } },
        );
        if (r && r.skipped) {
          out.skipped += 1;
          logger.info(`[chat.email.defer] conv ${cid} (${who}) : e-mail sans objet (${r.reason})`);
        } else {
          out.sent += 1;
          logger.info(`[chat.email.defer] conv ${cid} (${who}) : e-mail envoyé après 15 min sans lecture`);
        }
      } catch (e) {
        out.failed += 1;
        const msg = e && e.message ? e.message : String(e);
        const giveUp = Number(pending.attempts || 1) >= MAX_ATTEMPTS;
        logger.warn(`[chat.email.defer] conv ${cid} (${who}) : envoi échoué (${pending.attempts}/${MAX_ATTEMPTS}) : ${msg}`);
        // eslint-disable-next-line no-await-in-loop
        await M.updateOne(
          { _id: pending._id },
          { $set: giveUp ? { sentAt: new Date(Number(now)), lastError: `abandon: ${msg}`.slice(0, 300) } : { claimedAt: null, lastError: msg.slice(0, 300) } },
        ).catch(() => {});
      }
    }
  } catch (e) {
    logger.warn(`[chat.email.defer] balayage échoué : ${e && e.message ? e.message : e}`);
  } finally {
    running = false;
  }
  return out;
};

const startChatUnreadEmailScheduler = ({ intervalMs = TICK_MS } = {}) => {
  if (timer) return timer;
  const tick = () => {
    runOnce().catch((e) => logger.warn(`[chat.email.defer] tick : ${e && e.message ? e.message : e}`));
  };
  timer = setInterval(tick, intervalMs);
  if (typeof timer.unref === 'function') timer.unref();
  logger.info('[chat.email.defer] planificateur démarré (e-mail « message non lu » différé 15 min, balayage 1/min)');
  return timer;
};

const stopChatUnreadEmailScheduler = () => {
  if (timer) clearInterval(timer);
  timer = null;
};

module.exports = {
  DELAY_MS,
  TICK_MS,
  MAX_ATTEMPTS,
  isTestEmail,
  isStillUnread,
  scheduleUnreadEmail,
  cancelUnreadEmail,
  runOnce,
  startChatUnreadEmailScheduler,
  stopChatUnreadEmailScheduler,
};
