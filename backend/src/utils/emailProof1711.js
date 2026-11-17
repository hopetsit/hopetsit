/**
 * 17/11/2026 (NEO, ordre de Daniel transmis par BOB) — « E-MAIL D'ABORD » : la preuve que la personne lit bien
 * la boîte e-mail est apportée AVANT la création du compte (code à 6 chiffres tapé sur la page).
 *
 * `emailProof` = jeton signé, valable 60 min, qui dit « cette adresse a tapé le bon code ». Il est présenté à
 * POST /auth/signup et à POST /ad-leads/site : le compte naît alors déjà vérifié, et rien n'est créé avant.
 *
 * Sécurité : signé avec une clé DÉRIVÉE de JWT_SECRET (jamais JWT_SECRET tel quel) → ce jeton ne peut pas
 * servir de jeton de session (requireAuth le refuse), et un jeton de session ne peut pas servir de preuve.
 */
const crypto = require('crypto');
const jwt = require('jsonwebtoken');

const TYPE = 'email_first';
const TTL_SECONDS = 60 * 60;
const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

function proofSecret() {
  if (!process.env.JWT_SECRET) throw new Error('JWT_SECRET environment variable is not configured.');
  return crypto.createHmac('sha256', process.env.JWT_SECRET).update('hopetsit:email_first:1711').digest('hex');
}

/** Jeton de preuve pour cette adresse (minuscules). */
function signEmailProof(email) {
  const e = String(email || '').trim().toLowerCase();
  return jwt.sign({ t: TYPE, email: e }, proofSecret(), { expiresIn: TTL_SECONDS });
}

/** Vrai si `token` est une preuve valide, non expirée, POUR CETTE ADRESSE. Ne lève jamais. */
function verifyEmailProof(token, email) {
  const e = String(email || '').trim().toLowerCase();
  if (!token || typeof token !== 'string' || token.length > 2000 || !e) return false;
  try {
    const p = jwt.verify(token, proofSecret());
    return !!p && p.t === TYPE && p.email === e;
  } catch (_) {
    return false;
  }
}

// Fautes de frappe évidentes du domaine — même table que ~/hopetsit-social/vigie.py (FIX), plus quelques
// variantes relevées dans la base (hotmial, gmal, gnail, outloo…). Clé = domaine tapé, valeur = domaine voulu.
const DOMAIN_FIX = {
  'iclous.com': 'icloud.com', 'icloud.fr': 'icloud.com', 'iclod.com': 'icloud.com', 'icloud.coms': 'icloud.com', 'icloud.con': 'icloud.com', 'icoud.com': 'icloud.com',
  'gmai.com': 'gmail.com', 'gmail.co': 'gmail.com', 'gmial.com': 'gmail.com', 'gamil.com': 'gmail.com', 'gmail.fr': 'gmail.com', 'gmail.con': 'gmail.com',
  'gmail.cm': 'gmail.com', 'gmail.coms': 'gmail.com', 'gmail.comm': 'gmail.com', 'gmail.om': 'gmail.com', 'gmail.cim': 'gmail.com', 'gmal.com': 'gmail.com',
  'gnail.com': 'gmail.com', 'gmaill.com': 'gmail.com', 'gmail.cpm': 'gmail.com', 'gmail.vom': 'gmail.com', 'gmail.xom': 'gmail.com',
  'hotmal.com': 'hotmail.com', 'hotmail.fr.com': 'hotmail.fr', 'hotmai.com': 'hotmail.com', 'hotmail.co': 'hotmail.com', 'hotmail.coms': 'hotmail.com',
  'hotmail.con': 'hotmail.com', 'hotmial.com': 'hotmail.com', 'hotmial.fr': 'hotmail.fr', 'hotmil.com': 'hotmail.com', 'hotmal.fr': 'hotmail.fr',
  'outlok.com': 'outlook.com', 'outlook.fr.com': 'outlook.fr', 'outlook.coms': 'outlook.com', 'outlook.con': 'outlook.com', 'outloo.com': 'outlook.com', 'outlok.fr': 'outlook.fr',
  'yaho.com': 'yahoo.com', 'yahoo.fr.com': 'yahoo.fr', 'yahoo.co': 'yahoo.com', 'yahoo.coms': 'yahoo.com', 'yahoo.con': 'yahoo.com', 'yaho.fr': 'yahoo.fr', 'yahooo.com': 'yahoo.com', 'yahooo.fr': 'yahoo.fr',
  'orange.f': 'orange.fr', 'wanadoo.f': 'wanadoo.fr', 'live.f': 'live.fr', 'aol.coms': 'aol.com', 'aol.con': 'aol.com',
};

/** « lea@gmail.con » → « lea@gmail.com » ; '' si le domaine n'est pas une faute de frappe connue. */
function typoSuggestion(email) {
  const e = String(email || '').trim().toLowerCase();
  const at = e.lastIndexOf('@');
  if (at < 1) return '';
  const fixed = DOMAIN_FIX[e.slice(at + 1)];
  return fixed ? `${e.slice(0, at)}@${fixed}` : '';
}

/** a.b+alias@gmail.com → a.b@gmail.com (même boîte) : clé des limiteurs, jamais l'adresse du compte. */
function canonicalEmail(email) {
  const [local, domain] = String(email || '').trim().toLowerCase().split('@');
  if (!domain) return String(email || '').trim().toLowerCase();
  return `${local.split('+')[0]}@${domain}`;
}

/**
 * INTERRUPTEUR (allumé par défaut depuis le 17/11, =off pour l'éteindre) — rendre la preuve OBLIGATOIRE à l'inscription par e-mail + mot de passe.
 *   SIGNUP_EMAIL_PROOF_REQUIRED=on          → le site (X-App-Version: web) doit présenter `emailProof` ;
 *   SIGNUP_EMAIL_PROOF_MIN_BUILD=<n° build> → …et les apps à partir de ce build aussi (ex. 650).
 * Les apps plus anciennes (ou sans en-tête) gardent TOUJOURS le parcours d'avant : rien ne casse.
 */
function proofRequiredFor(req) {
  // 17/11 (BOB, ordre de Daniel « il est obligé de confirmer son e-mail pour continuer ») : ALLUMÉ par défaut une fois
  // le nouveau site vérifié en ligne (671e1c02). Retour arrière sans republier : SIGNUP_EMAIL_PROOF_REQUIRED=off.
  if (String(process.env.SIGNUP_EMAIL_PROOF_REQUIRED || 'on').trim().toLowerCase() === 'off') return false;
  const raw = String((req && req.headers && req.headers['x-app-version']) || '').trim().toLowerCase();
  if (!raw) return false;
  if (raw === 'web') return true;
  const min = parseInt(process.env.SIGNUP_EMAIL_PROOF_MIN_BUILD || '', 10);
  if (!Number.isFinite(min) || min <= 0) return false;
  const plus = raw.split('+');
  const build = plus.length > 1 ? parseInt(plus[plus.length - 1], 10) : parseInt(raw.split('.').pop(), 10);
  return Number.isFinite(build) && build >= min;
}

module.exports = { signEmailProof, verifyEmailProof, typoSuggestion, canonicalEmail, proofRequiredFor, DOMAIN_FIX, EMAIL_RE, TTL_SECONDS };
