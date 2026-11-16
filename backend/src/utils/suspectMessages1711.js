'use strict';

/**
 * 17/11/2026 (BOB, ordre de Daniel : « pour les messages suspects tu crées une alerte dans l'admin »).
 *
 * Cas de départ : une « propriétaire » de New York demandait aux gardiens de passer sur Telegram
 * pour une garde de deux mois (13/11). Personne ne l'avait vu pendant 4 jours.
 *
 * Fonctions PURES (aucun accès base) : repèrent, dans le texte d'un message du chat, ce qui
 * ressemble à une sortie de la plateforme. Trois familles :
 *   - 'hors_app'      : demande de continuer sur une autre messagerie (Telegram, WhatsApp…) ;
 *   - 'paiement'      : paiement proposé en dehors de HoPetSit (PayPal, Zelle, chèque, carte cadeau…) ;
 *   - 'coordonnees'   : coordonnées déjà masquées par le chat ([MASQUÉ]) — ne déclenche JAMAIS seul
 *                       (un gardien qui donne son numéro n'est pas une fraude), sert de précision.
 * Niveau : 'fort' si c'est un PROPRIÉTAIRE qui demande à sortir de l'app ou si un paiement hors app
 * est proposé ; 'moyen' sinon.
 */

const APPS = [
  ['Telegram', /\btele?gram\b|\bt\.me\//i],
  ['WhatsApp', /\bwhat'?s\s?app\b|\bwatsapp\b|\bwhatsap\b|\bwa\.me\//i],
  ['Snapchat', /\bsnap\s?chat\b/i],
  ['Instagram', /\binsta(?:gram)?\b/i],
  ['Facebook / Messenger', /\bfacebook\b|\bmessenger\b|\bfb\b/i],
  ['WeChat', /\bwe\s?chat\b/i],
  ['Viber', /\bviber\b/i],
  ['Skype', /\bskype\b/i],
  ['Discord', /\bdiscord\b/i],
  ['Google Chat / Hangouts', /\bhangouts?\b|\bgoogle\s+chat\b/i],
];

const PAYMENTS = [
  ['PayPal', /\bpay\s?pal\b/i],
  ['Zelle', /\bzelle\b/i],
  ['Cash App', /\bcash\s?app\b/i],
  ['Venmo', /\bvenmo\b/i],
  ['Western Union / MoneyGram', /\bwestern\s+union\b|\bmoney\s?gram\b/i],
  ['Carte cadeau', /\bgift\s?cards?\b|\bcartes?\s+cadeaux?\b|\bcoupons?\s+pcs\b|\btranscash\b/i],
  ['Crypto', /\bbitcoin\b|\bbtc\b|\busdt\b|\bcrypto\b/i],
  ['Chèque', /\bcashier'?s?\s+che(?:ck|que)\b|\bcertified\s+che(?:ck|que)\b|\bche(?:ck|que)\s+(?:by\s+)?mail\b|\bpar\s+ch[eè]que\b|\bsend\s+(?:you\s+)?a\s+che(?:ck|que)\b/i],
  ['Virement direct', /\bwire\s+transfer\b|\bbank\s+transfer\b|\bvirement\b/i],
  ['Espèces', /\ben\s+esp[eè]ces\b|\bin\s+cash\b|\bpay\s+(?:you\s+)?cash\b/i],
];

const MASK_RE = /\[MASQUÉ\]/;

/** Regex unique pour présélectionner les messages en base (insensible à la casse). */
const PREFILTER_SOURCE = [...APPS, ...PAYMENTS].map(([, re]) => `(?:${re.source})`).join('|');

/**
 * @param {string} text  corps du message
 * @param {string} senderRole 'owner' | 'sitter' | 'walker'
 * @returns {null | { level: 'fort'|'moyen', reasons: string[], apps: string[], payments: string[], masked: boolean }}
 */
function detectSuspect(text, senderRole = 'owner') {
  const body = String(text || '');
  if (!body.trim()) return null;
  const apps = APPS.filter(([, re]) => re.test(body)).map(([n]) => n);
  const payments = PAYMENTS.filter(([, re]) => re.test(body)).map(([n]) => n);
  if (!apps.length && !payments.length) return null;
  const masked = MASK_RE.test(body);
  const reasons = [];
  if (apps.length) reasons.push('hors_app');
  if (payments.length) reasons.push('paiement');
  if (masked) reasons.push('coordonnees');
  const level = payments.length || (apps.length && senderRole === 'owner') ? 'fort' : 'moyen';
  return { level, reasons, apps, payments, masked };
}

/** Phrase simple pour l'admin (français). */
function reasonText(hit) {
  if (!hit) return '';
  const parts = [];
  if (hit.apps.length) parts.push(`demande de passer sur ${hit.apps.join(', ')}`);
  if (hit.payments.length) parts.push(`paiement hors de l'app (${hit.payments.join(', ')})`);
  if (hit.masked) parts.push('coordonnées envoyées');
  return parts.join(' · ');
}

/**
 * Regroupe des messages suspects par (conversation, expéditeur).
 * @param {Array<{conversationId, senderRole, senderId, body, createdAt}>} messages
 * @returns {Array} une ligne par expéditeur et par conversation, la plus récente d'abord
 */
function groupSuspects(messages) {
  const groups = new Map();
  for (const m of messages || []) {
    const hit = detectSuspect(m.body, m.senderRole);
    if (!hit) continue;
    const key = `${m.conversationId}:${m.senderRole}:${m.senderId}`;
    const at = new Date(m.createdAt).getTime();
    let g = groups.get(key);
    if (!g) {
      g = {
        key,
        conversationId: String(m.conversationId),
        senderRole: m.senderRole,
        senderId: String(m.senderId),
        count: 0,
        level: 'moyen',
        apps: new Set(),
        payments: new Set(),
        masked: false,
        firstAt: at,
        lastAt: at,
        excerpt: '',
      };
      groups.set(key, g);
    }
    g.count += 1;
    if (hit.level === 'fort') g.level = 'fort';
    hit.apps.forEach((a) => g.apps.add(a));
    hit.payments.forEach((p) => g.payments.add(p));
    g.masked = g.masked || hit.masked;
    if (at <= g.firstAt) g.firstAt = at;
    if (at >= g.lastAt) { g.lastAt = at; g.excerpt = String(m.body).replace(/\s+/g, ' ').trim().slice(0, 220); }
  }
  return [...groups.values()]
    .map((g) => {
      const hit = { apps: [...g.apps], payments: [...g.payments], masked: g.masked };
      return {
        ...g,
        apps: hit.apps,
        payments: hit.payments,
        reason: reasonText(hit),
        firstAt: new Date(g.firstAt).toISOString(),
        lastAt: new Date(g.lastAt).toISOString(),
      };
    })
    .sort((a, b) => (a.level === b.level ? (a.lastAt < b.lastAt ? 1 : -1) : (a.level === 'fort' ? -1 : 1)));
}

module.exports = { detectSuspect, reasonText, groupSuspects, PREFILTER_SOURCE };
