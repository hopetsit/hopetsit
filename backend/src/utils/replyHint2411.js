'use strict';
/**
 * 2411 (BOB) — phrase de l'e-mail « nouveau message » quand la RÉPONSE PAR E-MAIL est active : elle remplace
 * « Ne réponds pas à cet e-mail » (paragraphe repéré par data-rh2411 dans locales/<langue>/notifications.json).
 * 9 langues. Le prénom est échappé par l'appelant pour la version HTML.
 */
const CAN = {
  fr: (n) => `Réponds avec le bouton ci-dessous, ou réponds simplement à cet e-mail : ${n} recevra ta réponse sur HoPetSit.`,
  en: (n) => `Reply with the button below, or simply reply to this email: ${n} will get your answer on HoPetSit.`,
  es: (n) => `Responde con el botón de abajo o simplemente responde a este correo: ${n} recibirá tu respuesta en HoPetSit.`,
  de: (n) => `Antworte über die Schaltfläche unten oder antworte einfach auf diese E-Mail: ${n} erhält deine Antwort auf HoPetSit.`,
  it: (n) => `Rispondi con il pulsante qui sotto oppure rispondi semplicemente a questa e-mail: ${n} riceverà la tua risposta su HoPetSit.`,
  pt: (n) => `Responda com o botão abaixo ou responda simplesmente a este e-mail: ${n} receberá a sua resposta no HoPetSit.`,
  ko: (n) => `아래 버튼으로 답장하거나 이 이메일에 바로 회신하세요. ${n}님이 HoPetSit에서 답장을 받습니다.`,
  ja: (n) => `下のボタンから返信するか、このメールにそのまま返信してください。${n}さんにHoPetSitで届きます。`,
  pl: (n) => `Odpowiedz przyciskiem poniżej albo po prostu odpowiedz na tego e-maila: ${n} otrzyma Twoją odpowiedź w HoPetSit.`,
};
const esc = (v) => String(v == null ? '' : v).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const P_RE = /<p data-rh2411="1"([^>]*)>[\s\S]*?<\/p>/;

/** Remplace la phrase dans le HTML (inchangé si le repère est absent) et renvoie aussi la phrase en texte brut. */
function applyReplyHint({ html, locale, senderName }) {
  const l = String(locale || '').slice(0, 2).toLowerCase();
  const f = CAN[l] || CAN.en;
  const name = String(senderName || 'HoPetSit').trim() || 'HoPetSit';
  const found = P_RE.test(String(html || ''));
  return {
    found,
    html: found ? String(html).replace(P_RE, (_m, attrs) => `<p${attrs}>${esc(f(name))}</p>`) : html,
    line: f(name),
  };
}

module.exports = { CAN, applyReplyHint };
