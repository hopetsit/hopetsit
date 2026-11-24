'use strict';
/**
 * 2411 (BOB) — TEXTE d'une réponse par e-mail, avant de la poster dans un fil : on garde ce que la personne a écrit,
 * on retire le message cité, la signature et les mentions « Envoyé de mon iPhone ». 1 000 caractères au plus
 * (limite du champ de message du site). Renvoie '' quand il ne reste rien : la réponse n'est alors PAS postée.
 * Le masquage des téléphones et des e-mails reste fait par conversationService.sendMessage, comme pour tout message.
 */
const MAX = 1000;

// « Le mar. 24 nov. 2026 à 17:42, Daniel de HoPetSit <…> a écrit : » (souvent coupé sur deux lignes).
const WROTE = /(a\s+[ée]crit|wrote|escribi[óo]|schrieb|ha\s+scritto|escreveu|napisa[łl]\(?a?\)?)\s*:?\s*$/i;
const WROTE_START = /^(le|on|el|am|il|em|w dniu|dnia)\b/i;
const ORIGINAL = /^-{2,}\s*(original message|message d['’]origine|mensaje original|urspr[üu]ngliche nachricht|messaggio originale|mensagem original|forwarded message|message transf[ée]r[ée])/i;
const HEADER_BLOCK = /^(de|from|von|da|od)\s?:\s.*@/i;
const OUR_ADDRESS = /<[^>]*@(?:[a-z0-9-]+\.)*hopetsit\.com>|\+r[a-f0-9]{24}\.[osw]\.[a-f0-9]{16}@/i;
const SIGNATURE = /^(--\s?$|_{5,}$|envoy[ée] (de|depuis) mon |sent from my |enviado desde mi |enviado do meu |gesendet von meinem |von meinem .* gesendet|inviato da |t[ée]l[ée]charger outlook|obtenir outlook|get outlook for |envoy[ée] (à partir de|depuis) outlook|wys[łl]ane z )/i;

function replyText(raw) {
  const lines = String(raw || '').replace(/\r\n?/g, '\n').replace(/[​﻿]/g, '').split('\n');
  const kept = [];
  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i].replace(/\s+$/, '');
    const t = line.trim();
    const next = (lines[i + 1] || '').trim();
    if (/^>/.test(t)) break; // début de la citation
    if (ORIGINAL.test(t) || HEADER_BLOCK.test(t) || OUR_ADDRESS.test(t) || SIGNATURE.test(t)) break;
    if (WROTE_START.test(t) && (WROTE.test(t) || WROTE.test(`${t} ${next}`))) break;
    if (WROTE.test(t) && /\d{4}|@/.test(t)) break;
    kept.push(line);
  }
  let out = kept.join('\n').replace(/\n{3,}/g, '\n\n').trim();
  if (out.length > MAX) out = `${out.slice(0, MAX - 1).trimEnd()}…`;
  return out;
}

module.exports = { replyText, MAX };
