'use strict';
/**
 * 2411 (BOB, décision de Daniel du 24/11/2026) — RÉPONSES PAR E-MAIL → MESSAGE DANS LE FIL (version 1).
 *
 * Constat : 54 demandes sur 59 viennent de propriétaires sans l'app ; deux ont répondu le même jour à un e-mail
 * HoPetSit en croyant écrire à la gardienne. Désormais l'e-mail « nouveau message » (différé de 15 min) porte une
 * adresse de réponse signée (utils/replyAddress2411) et ce service relève la boîte toutes les 2 minutes :
 *   1. il ne lit QUE les e-mails non lus adressés à « <boîte>+r… » (les autres ne sont ni ouverts ni touchés) ;
 *   2. signature du fil vérifiée, expéditeur = adresse du compte, pas de réponse automatique d'absence ;
 *   3. texte nettoyé (citation, signature) puis posté par conversationService.sendMessage — donc mêmes règles que
 *      tout message : participant du fil, blocage, accès au chat, téléphones et e-mails masqués, modération ;
 *   4. le fil est marqué lu pour la personne (elle vient d'y répondre) : la prochaine réponse lui repartira par e-mail ;
 *   5. e-mail posté → marqué « lu » dans la boîte ; refusé → laissé NON LU (l'équipe le voit), jamais retraité.
 * Registre InboundReply2411 (index unique sur l'identifiant du message) : jamais deux fois le même e-mail.
 *
 * Sûr par défaut : l'adresse de réponse n'est posée sur un e-mail QUE si la boîte a été relevée avec succès il y a
 * moins de 15 minutes. Si la lecture de la boîte est impossible (accès refusé), rien ne change pour personne.
 * Interrupteurs Render (sans republier) : INBOUND_REPLY_2411=off coupe tout ; IMAP_HOST / IMAP_USER / IMAP_PASS
 * pour lire une autre boîte que celle de l'envoi (défaut : SMTP_USER / SMTP_PASS, imap.gmail.com pour smtp.gmail.com).
 */
const mongoose = require('mongoose');
const logger = require('../utils/logger');
const addr = require('../utils/replyAddress2411');
const { replyText } = require('../utils/replyText2411');

const TICK_MS = 120 * 1000;
// Accès refusé par la boîte : on n'insiste pas (des échecs de connexion répétés pourraient faire réagir Google et
// gêner l'ENVOI des e-mails, qui passe par le même compte). 1er échec : nouvel essai dans 10 min, puis 1 h, puis 6 h.
const BACKOFF_MS = [10 * 60 * 1000, 60 * 60 * 1000, 6 * 60 * 60 * 1000];
const READY_TTL_MS = 15 * 60 * 1000;
const MAX_PER_RUN = 20;
const MAX_ENVELOPES = 200;
const LOOKBACK_DAYS = 3;
const ROLE_MODEL = { owner: 'Owner', sitter: 'Sitter', walker: 'Walker' };

let timer = null;
let running = false;
let lastOkAt = 0;
let lastError = '';
let lastRun = null;
let failures = 0;
let nextTryAt = 0;

const enabled = () => !/^(off|0|false|no)$/i.test(String(process.env.INBOUND_REPLY_2411 || 'on').trim());
const dbReady = () => mongoose.connection && mongoose.connection.readyState === 1;

const imapConfig = () => {
  const smtpHost = String(process.env.SMTP_HOST || '').trim().toLowerCase();
  const host = String(process.env.IMAP_HOST || (smtpHost === 'smtp.gmail.com' ? 'imap.gmail.com' : '')).trim();
  const user = String(process.env.IMAP_USER || process.env.SMTP_USER || '').trim();
  const pass = String(process.env.IMAP_PASS || process.env.SMTP_PASS || '');
  if (!host || !user || !pass || !addr.splitMailbox(user)) return null;
  return { host, port: Number(process.env.IMAP_PORT) || 993, user, pass };
};

/** Boîte relevée avec succès récemment ? (condition pour poser l'adresse de réponse sur un e-mail) */
const isReady = (now = Date.now()) => enabled() && lastOkAt > 0 && now - lastOkAt < READY_TTL_MS;

/** Adresse de réponse pour l'e-mail envoyé à (rôle, compte) sur ce fil ; '' = e-mail inchangé. */
const replyToFor = ({ conversationId, role, userId }) => {
  if (!isReady()) return '';
  const cfg = imapConfig();
  if (!cfg) return '';
  return addr.buildReplyAddress({ mailbox: cfg.user, conversationId, role, userId });
};

const lower = (v) => String(v || '').trim().toLowerCase();
const headerOf = (headers, name) => {
  try {
    const v = headers && typeof headers.get === 'function' ? headers.get(name) : (headers || {})[name];
    return v == null ? '' : (typeof v === 'string' ? v : (v.text || v.value || JSON.stringify(v)));
  } catch (_) { return ''; }
};

/** Réponse automatique (absence, robot) ? On ne la poste jamais : risque de boucle entre deux boîtes. */
const isAutoReply = (headers) => {
  const auto = lower(headerOf(headers, 'auto-submitted'));
  if (auto && auto !== 'no') return true;
  if (/(bulk|junk|auto_reply|list)/.test(lower(headerOf(headers, 'precedence')))) return true;
  if (headerOf(headers, 'x-autoreply') || headerOf(headers, 'x-autorespond')) return true;
  return false;
};

/**
 * Traite UN e-mail déjà analysé. Ne lève jamais.
 * @param {{messageId:string, to:string, from:string, text:string, headers?:object, date?:Date}} mail
 * @returns {Promise<{status:'posted'|'rejected'|'duplicate'|'ignored', reason?:string, conversationId?:string}>}
 */
const processParsed = async (mail) => {
  const Inbound = require('../models/InboundReply2411');
  // Identifiant du message : on n'en garde qu'une empreinte (il peut contenir un nom de domaine).
  const rawId = String((mail && mail.messageId) || '').trim();
  const messageId = rawId ? require('crypto').createHash('sha256').update(rawId).digest('hex') : '';
  const parsed = addr.parseReplyAddress(mail && mail.to);
  if (!parsed) return { status: 'ignored', reason: 'no_reply_address' };
  if (!messageId) return { status: 'ignored', reason: 'no_message_id' };
  let row;
  try {
    row = await Inbound.create({ messageId, conversationId: parsed.conversationId, role: parsed.role, receivedAt: mail.date || null });
  } catch (e) {
    if (e && (e.code === 11000 || /E11000/.test(String(e.message || '')))) return { status: 'duplicate' };
    logger.warn(`[inbound2411] registre indisponible : ${e && e.message ? e.message : e}`);
    return { status: 'ignored', reason: 'db' };
  }
  const done = async (status, reason, extra = {}) => {
    try { await Inbound.updateOne({ _id: row._id }, { $set: { status, reason: reason || '', ...extra } }); } catch (_) { /* registre */ }
    logger.info(`[inbound2411] ${status}${reason ? ` (${reason})` : ''} fil ${parsed.conversationId} rôle ${parsed.role}`);
    return { status, reason, conversationId: parsed.conversationId };
  };
  try {
    if (isAutoReply(mail.headers)) return await done('rejected', 'auto_reply');
    const identity599 = require('../utils/conversationIdentity599');
    const conv = await identity599.resolveConversation(parsed.conversationId, {
      select: 'friendChat participants ownerId sitterId walkerId mergedInto', lean: true,
    });
    if (!conv || conv.friendChat === true) return await done('rejected', 'no_conversation');
    const field = parsed.role === 'owner' ? 'ownerId' : parsed.role === 'walker' ? 'walkerId' : 'sitterId';
    const userId = conv[field] ? String(conv[field]._id || conv[field]) : '';
    if (!userId) return await done('rejected', 'role_not_in_conversation');
    if (!addr.verify({ conversationId: parsed.conversationId, role: parsed.role, userId, sig: parsed.sig })) {
      return await done('rejected', 'bad_signature');
    }
    const Model = mongoose.model(ROLE_MODEL[parsed.role]);
    const user = await Model.findById(userId).select('email').lean();
    const from = lower((/<([^>]+)>/.exec(String(mail.from || '')) || [null, mail.from])[1]);
    if (!user || !user.email || lower(user.email) !== from) return await done('rejected', 'from_mismatch', { userId });
    const text = replyText(mail.text);
    if (!text) return await done('rejected', 'empty', { userId });
    const { sendMessage, markConversationRead } = require('./conversationService');
    const canonicalId = String(conv._id);
    const result = await sendMessage({ conversationId: canonicalId, senderRole: parsed.role, senderId: userId, body: text });
    try {
      require('../sockets/emitter').emitChatMessage(conv, 'message:new', {
        conversationId: canonicalId, triggeredBy: { role: parsed.role, userId }, ...result,
      });
    } catch (_) { /* temps réel : au mieux */ }
    // La personne vient de répondre : son fil est lu, et son attente d'e-mail est levée (la réponse suivante
    // lui repartira donc par e-mail — sans cela un utilisateur « e-mail seul » ne recevrait plus rien).
    try { await markConversationRead({ conversationId: canonicalId, role: parsed.role, userId }); } catch (_) { /* au mieux */ }
    try { await require('../utils/chatReadSync599').afterConversationRead({ conversationId: canonicalId, readerId: userId }); } catch (_) { /* au mieux */ }
    return await done('posted', '', { userId, chars: text.length });
  } catch (e) {
    const code = (e && (e.code || e.status)) || '';
    return done('rejected', `error:${code || (e && e.message ? String(e.message).slice(0, 60) : 'unknown')}`);
  }
};

/** Relève la boîte une fois. Ne lève jamais. `connect` est injectable pour les tests. */
const runOnce = async ({ connect } = {}) => {
  const out = { ok: false, seen: 0, posted: 0, rejected: 0, duplicate: 0 };
  if (!enabled()) return { ...out, reason: 'off' };
  const cfg = imapConfig();
  if (!cfg) return { ...out, reason: 'no_config' };
  if (!dbReady()) return { ...out, reason: 'db' };
  if (running) return { ...out, reason: 'busy' };
  if (typeof connect !== 'function' && Date.now() < nextTryAt) return { ...out, reason: 'backoff' };
  running = true;
  let client = null;
  try {
    if (typeof connect === 'function') client = await connect(cfg);
    else {
      const { ImapFlow } = require('imapflow');
      client = new ImapFlow({ host: cfg.host, port: cfg.port, secure: true, auth: { user: cfg.user, pass: cfg.pass }, logger: false, socketTimeout: 60000 });
      await client.connect();
    }
    const lock = await client.getMailboxLock('INBOX');
    try {
      const box = addr.splitMailbox(cfg.user);
      const since = new Date(Date.now() - LOOKBACK_DAYS * 24 * 3600 * 1000);
      // Non lus récents : on ne lit que leur ENVELOPPE (destinataires), et seuls ceux adressés à « <boîte>+r… »
      // sont ouverts. Le reste de la boîte n'est ni téléchargé ni marqué. (La recherche « to » de Gmail découpe
      // les adresses en mots : on filtre donc ici, sur l'adresse exacte.)
      const unseen = ((await client.search({ seen: false, since }, { uid: true })) || []).slice(-MAX_ENVELOPES);
      lastOkAt = Date.now(); lastError = ''; failures = 0; nextTryAt = 0;
      out.ok = true;
      const uids = [];
      const prefix = `${box.local}+r`;
      if (unseen.length) {
        for await (const m of client.fetch(unseen.join(','), { envelope: true }, { uid: true })) {
          const tos = [...((m.envelope && m.envelope.to) || []), ...((m.envelope && m.envelope.cc) || [])].map((a) => lower(a && a.address));
          if (tos.some((a) => a.startsWith(prefix) && addr.parseReplyAddress(a))) uids.push(m.uid);
        }
      }
      const { simpleParser } = require('mailparser');
      for (const uid of uids.slice(0, MAX_PER_RUN)) {
        // eslint-disable-next-line no-await-in-loop
        const msg = await client.fetchOne(String(uid), { source: true, envelope: true }, { uid: true });
        if (!msg || !msg.source) continue;
        out.seen += 1;
        // eslint-disable-next-line no-await-in-loop
        const p = await simpleParser(msg.source);
        const to = [headerOf(p.headers, 'delivered-to'), headerOf(p.headers, 'x-original-to'), p.to && p.to.text, p.cc && p.cc.text].filter(Boolean).join(' ');
        // eslint-disable-next-line no-await-in-loop
        const r = await processParsed({
          messageId: p.messageId || (msg.envelope && msg.envelope.messageId) || '',
          to, from: (p.from && p.from.value && p.from.value[0] && p.from.value[0].address) || '',
          text: p.text || '', headers: p.headers, date: p.date || null,
        });
        if (r.status === 'posted') {
          out.posted += 1;
          // eslint-disable-next-line no-await-in-loop
          try { await client.messageFlagsAdd(String(uid), ['\\Seen'], { uid: true }); } catch (_) { /* reste non lu : le registre empêche le doublon */ }
        } else if (r.status === 'duplicate') out.duplicate += 1;
        else if (r.status === 'rejected') out.rejected += 1;
      }
    } finally { lock.release(); }
  } catch (e) {
    lastError = String((e && (e.responseText || e.message)) || e).slice(0, 160);
    out.reason = 'imap';
    lastOkAt = 0; // plus d'adresse de réponse tant que la boîte n'est pas relue avec succès
    failures += 1;
    nextTryAt = Date.now() + BACKOFF_MS[Math.min(failures, BACKOFF_MS.length) - 1];
    logger.warn(`[inbound2411] boîte illisible : ${lastError}`);
  } finally {
    try { if (client) await client.logout(); } catch (_) { /* déjà fermée */ }
    running = false;
    lastRun = { at: new Date().toISOString(), ...out };
  }
  return out;
};

const start = () => {
  if (timer || process.env.NODE_ENV === 'test') return false;
  if (!enabled() || !imapConfig()) {
    logger.info('[inbound2411] réponses par e-mail : inactif (interrupteur coupé ou boîte non configurée)');
    return false;
  }
  timer = setInterval(() => { runOnce().catch(() => {}); }, TICK_MS);
  if (typeof timer.unref === 'function') timer.unref();
  setTimeout(() => { runOnce().catch(() => {}); }, 20000).unref();
  logger.info('[inbound2411] réponses par e-mail : relevé de la boîte toutes les 2 minutes');
  return true;
};

const stop = () => { if (timer) clearInterval(timer); timer = null; };

/** État pour l'admin (aucune adresse ni secret). */
const status = () => ({
  enabled: enabled(), configured: !!imapConfig(), ready: isReady(),
  lastOkAt: lastOkAt ? new Date(lastOkAt).toISOString() : null, lastError, lastRun,
  failures, nextTryAt: nextTryAt ? new Date(nextTryAt).toISOString() : null,
});

// Tests uniquement.
const _setReadyForTest = (v) => { lastOkAt = v ? Date.now() : 0; };

module.exports = { start, stop, runOnce, processParsed, replyToFor, isReady, status, imapConfig, isAutoReply, _setReadyForTest };
