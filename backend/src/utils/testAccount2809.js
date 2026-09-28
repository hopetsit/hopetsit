/**
 * 28/09/2026 — Daniel : « enregistre la correction dans le serveur pour les
 * comptes test uniquement ». Un test du parcours « Publier ma demande » avec
 * une adresse `+test` a prévenu les vrais gardiens de Paris d'une demande qui
 * n'existait pas. Une adresse contenant « +test » est un compte de test :
 * ses demandes ne préviennent personne. Seuls les comptes `+test` sont
 * concernés (pas le compte de Daniel ni hopetsit@).
 */
const { decrypt } = require('./encryption');

const TEST_EMAIL_RE = /\+test/i;

const isTestAccountEmail = (stored) => {
  let email = stored;
  try { email = decrypt(stored); } catch (_) { /* e-mail illisible → pas un test */ }
  return typeof email === 'string' && TEST_EMAIL_RE.test(email);
};

module.exports = { isTestAccountEmail, TEST_EMAIL_RE };
