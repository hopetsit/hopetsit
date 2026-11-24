'use strict';
/**
 * 2411 (BOB, décision de Daniel du 24/11/2026 « Oui, lance la V1 ») — ADRESSE DE RÉPONSE d'un e-mail « nouveau message ».
 *
 * Deux propriétaires ont répondu le même jour à un e-mail HoPetSit en croyant écrire à la gardienne : leur réponse
 * arrivait dans la boîte de l'équipe. L'e-mail « nouveau message » porte désormais un Reply-To unique,
 *     <boîte>+r<id du fil>.<o|s|w>.<signature>@<domaine>
 * que Gmail livre dans la même boîte (adressage « + »). Le serveur relève la boîte (services/inboundReply2411) et
 * poste la réponse dans le fil, au nom de la personne à qui l'e-mail avait été envoyé.
 *
 *   · <o|s|w> = rôle de CELUI QUI RÉPOND (le destinataire de l'e-mail) dans ce fil ;
 *   · signature = HMAC-SHA256(JWT_SECRET, fil | rôle | id du compte), 16 hexadécimaux : une adresse ne se devine pas
 *     et ne vaut que pour CE fil et CETTE personne. L'expéditeur de la réponse est en plus comparé à l'adresse du compte.
 * Aucune donnée personnelle dans l'adresse (ni e-mail, ni nom).
 */
const crypto = require('crypto');

const ROLE_LETTER = { owner: 'o', sitter: 's', walker: 'w' };
const LETTER_ROLE = { o: 'owner', s: 'sitter', w: 'walker' };
const ID_RE = /^[a-f0-9]{24}$/;

const secret = () => String(process.env.REPLY_2411_SECRET || process.env.JWT_SECRET || '');

const sign = (conversationId, role, userId) => crypto
  .createHmac('sha256', secret())
  .update(`reply2411|${String(conversationId)}|${String(role)}|${String(userId)}`)
  .digest('hex')
  .slice(0, 16);

/** « contact@hopetsit.com » → { local: 'contact', domain: 'hopetsit.com' } ; null si l'adresse ne convient pas. */
const splitMailbox = (mailbox) => {
  const m = /^([a-z0-9._-]{1,40})@([a-z0-9.-]+\.[a-z]{2,})$/i.exec(String(mailbox || '').trim());
  return m ? { local: m[1].toLowerCase(), domain: m[2].toLowerCase() } : null;
};

/** Adresse de réponse, ou '' si un élément manque (jamais d'exception : l'e-mail part alors comme avant). */
const buildReplyAddress = ({ mailbox, conversationId, role, userId }) => {
  const box = splitMailbox(mailbox);
  const cid = String(conversationId || '').toLowerCase();
  const letter = ROLE_LETTER[String(role || '').toLowerCase()];
  const uid = String(userId || '').toLowerCase();
  if (!box || !ID_RE.test(cid) || !letter || !ID_RE.test(uid) || secret().length < 16) return '';
  return `${box.local}+r${cid}.${letter}.${sign(cid, LETTER_ROLE[letter], uid)}@${box.domain}`;
};

const ADDRESS_RE = /([a-z0-9._-]{1,40})\+r([a-f0-9]{24})\.([osw])\.([a-f0-9]{16})@([a-z0-9.-]+\.[a-z]{2,})/i;

/** Lit une adresse de réponse dans un texte (To, Delivered-To…) → { conversationId, role, sig, mailbox } ou null. */
const parseReplyAddress = (text) => {
  const m = ADDRESS_RE.exec(String(text || ''));
  if (!m) return null;
  return {
    conversationId: m[2].toLowerCase(),
    role: LETTER_ROLE[m[3].toLowerCase()],
    sig: m[4].toLowerCase(),
    mailbox: `${m[1].toLowerCase()}@${m[5].toLowerCase()}`,
  };
};

/** La signature correspond-elle à ce fil, ce rôle et ce compte ? (comparaison à temps constant) */
const verify = ({ conversationId, role, userId, sig }) => {
  if (secret().length < 16) return false;
  const a = Buffer.from(sign(String(conversationId).toLowerCase(), role, String(userId).toLowerCase()));
  const b = Buffer.from(String(sig || '').toLowerCase());
  return a.length === b.length && crypto.timingSafeEqual(a, b);
};

module.exports = { buildReplyAddress, parseReplyAddress, verify, splitMailbox, ADDRESS_RE };
