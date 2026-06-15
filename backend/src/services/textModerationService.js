'use strict';

/**
 * v23.1.319 — Daniel : "auto-gestion des gros mots et menaces, dans toutes les
 * langues". Modération de TEXTE auto, multilingue (fr, en, es, de, it, pt),
 * sans dépendance npm (liste maison + regex). Conforme à l'exigence Play Store
 * de filtrer le contenu généré par les utilisateurs (UGC).
 *
 * Politique :
 *   - INSULTES / gros mots  → masqués en «***» (UX douce, on ne bloque pas).
 *   - MENACES de violence   → masquées AUSSI + flag `threat:true` remonté pour
 *                             qu'un appelant puisse rejeter / créer un Report.
 *
 * Usage :
 *   const { moderateText } = require('./textModerationService');
 *   const { clean, censored, profanity, threat } = moderateText(userInput);
 *   // stocker `clean` à la place du texte original.
 *
 * NB : liste volontairement curée (pas exhaustive) — elle couvre les insultes
 * et menaces les plus courantes des 6 langues et peut être étendue facilement.
 */

// ─── Insultes / gros mots (par langue, racines en minuscule) ────────────────
const PROFANITY = [
  // FR
  'connard', 'connasse', 'salope', 'salaud', 'enculé', 'enculer', 'pute',
  'putain', 'merde', 'merdeux', 'batard', 'bâtard', 'pédé', 'tapette', 'fdp',
  'ntm', 'nique', 'niquer', 'foutre', 'bouffon', 'abruti', 'crétin', 'débile',
  'pétasse', 'trouduc', 'couille', 'bite', 'chatte', 'pue', 'sale arabe',
  // EN
  'fuck', 'fucker', 'fucking', 'motherfucker', 'shit', 'bullshit', 'asshole',
  'bitch', 'bastard', 'cunt', 'dick', 'pussy', 'slut', 'whore', 'faggot',
  'nigger', 'nigga', 'retard', 'douchebag', 'jackass', 'wanker', 'prick',
  // ES
  'puta', 'puto', 'cabron', 'cabrón', 'gilipollas', 'mierda', 'pendejo',
  'coño', 'joder', 'maricon', 'maricón', 'zorra', 'capullo', 'hijo de puta',
  // DE
  'scheisse', 'scheiße', 'arschloch', 'fotze', 'hurensohn', 'wichser',
  'schlampe', 'fick', 'ficken', 'miststück', 'hure', 'spast',
  // IT
  'stronzo', 'stronza', 'puttana', 'troia', 'cazzo', 'merda', 'bastardo',
  'figlio di puttana', 'vaffanculo', 'coglione', 'minchia', 'fancazzista',
  // PT
  'caralho', 'caralD', 'merda', 'puta', 'filho da puta', 'foda-se', 'cu',
  'corno', 'viado', 'arrombado', 'fdp', 'vai à merda',
];

// ─── Menaces de violence (patterns multilingues) ────────────────────────────
// Regex souples : « je vais te tuer », « I'll kill you », « te voy a matar »…
const THREAT_PATTERNS = [
  // FR
  /\bje\s+vais\s+te\s+(tuer|crever|défoncer|frapper|buter|égorger)/i,
  /\bje\s+vais\s+vous\s+(tuer|crever|défoncer|frapper|buter)/i,
  /\b(tu\s+es|t'es)\s+mort\b/i,
  /\bje\s+(te|vais\s+te)\s+retrouve(r)?\b.*\b(tuer|frapper|cogner)/i,
  /\bmenace.*\bmort\b/i,
  // EN
  /\bi('|\s*a)?m?\s*(will|gonna|going to)\s+(kill|murder|beat|hurt|destroy)\s+(you|u)\b/i,
  /\bi('|\s*a)?ll\s+(kill|murder|beat|hurt|destroy)\s+(you|u)\b/i,
  /\byou('|\s*a)?re\s+(a\s+)?dead\b/i,
  /\bi\s+know\s+where\s+you\s+live\b/i,
  // ES
  /\bte\s+voy\s+a\s+(matar|reventar|golpear|destrozar)/i,
  /\bvoy\s+a\s+matarte\b/i,
  /\bestas\s+muerto\b/i,
  // DE
  /\bich\s+(werde|bring)\s+dich\s+(um|töten|umbringen|schlagen)/i,
  /\bdu\s+bist\s+(so\s+)?tot\b/i,
  // IT
  /\bti\s+(ammazzo|uccido|gonfio|spacco)\b/i,
  /\bsei\s+(un\s+uomo\s+)?morto\b/i,
  // PT
  /\bvou\s+te\s+(matar|bater|destruir|acabar)/i,
  /\bvoce\s+(esta|está|ta)\s+morto\b/i,
];

// Échappe une chaîne pour usage dans une regex.
const escapeRe = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// Normalise un peu le leetspeak basique (a@, i1!, e3, o0, s$) pour limiter le
// contournement « f.u.c.k » / « put@in ».
const deLeet = (s) =>
  s
    .toLowerCase()
    .replace(/@/g, 'a')
    .replace(/\$/g, 's')
    .replace(/0/g, 'o')
    .replace(/1/g, 'i')
    .replace(/3/g, 'e')
    .replace(/4/g, 'a')
    .replace(/[._\-*]/g, ''); // retire séparateurs « f.u.c.k »

// v406 — on sépare MOTS simples (matchés token par token sur la version
// dé-leetée) et PHRASES multi-mots (« sale arabe », « hijo de puta »…) qui,
// elles, doivent être cherchées sur le TEXTE ENTIER (un seul token ne peut
// jamais contenir un espace). Sans ça les entrées multi-mots ne bloquaient
// JAMAIS — bug signalé par Daniel sur le filtre admin.
const _isPhrase = (w) => /\s/.test(String(w || '').trim());
const PROFANITY_WORDS = PROFANITY.filter((w) => !_isPhrase(w));
const PROFANITY_PHRASES = PROFANITY.filter(_isPhrase);

// Construit une regex de détection des insultes (sur la version dé-leetée).
const PROFANITY_RE = new RegExp(
  '(' + PROFANITY_WORDS.map((w) => escapeRe(deLeet(w))).join('|') + ')',
  'gi',
);
// Regex plein-texte pour les phrases (insensible à la casse).
const PROFANITY_PHRASE_RE = PROFANITY_PHRASES.length
  ? new RegExp('(' + PROFANITY_PHRASES.map((w) => escapeRe(w)).join('|') + ')', 'gi')
  : null;

// v404 — mots interdits SUPPLÉMENTAIRES gérés par l'admin (modèle BannedWord),
// chargés en mémoire au boot + à chaque ajout/suppression. S'appliquent app+web
// (cette modération tourne côté serveur sur les annonces + messages).
// v406 — idem : mots simples → EXTRA_RE (par token), phrases → EXTRA_PHRASE_RE
// (plein-texte). refreshBannedWords (adminRoutes) éclate déjà les blocs collés
// en mots individuels et purge les variantes « [auto] » non traduites.
let EXTRA_RE = null;
let EXTRA_PHRASE_RE = null;
function setExtraWords(words) {
  const list = (words || [])
    .map((w) => String(w || '').trim())
    .filter(Boolean)
    .filter((w) => !w.startsWith('[auto]')); // purge fallback non traduit
  const wordsOnly = list.filter((w) => !_isPhrase(w));
  const phrases = list.filter(_isPhrase);
  EXTRA_RE = wordsOnly.length
    ? new RegExp('(' + wordsOnly.map((w) => escapeRe(deLeet(w))).join('|') + ')', 'gi')
    : null;
  EXTRA_PHRASE_RE = phrases.length
    ? new RegExp('(' + phrases.map((w) => escapeRe(w)).join('|') + ')', 'gi')
    : null;
}

const STARS = (w) => '*'.repeat(Math.max(3, w.length));

/**
 * Analyse + censure un texte.
 * @param {string} text
 * @returns {{clean:string, censored:boolean, profanity:boolean, threat:boolean}}
 */
function moderateText(text) {
  if (text == null || typeof text !== 'string' || text.trim() === '') {
    return { clean: text, censored: false, profanity: false, threat: false };
  }

  // 1) Menaces : on masque la phrase entière par «***» + on remonte le flag.
  let threat = false;
  let working = text;
  for (const re of THREAT_PATTERNS) {
    const reG = new RegExp(re.source, re.flags.includes('g') ? re.flags : re.flags + 'g');
    if (re.test(working)) {
      threat = true;
      working = working.replace(reG, '***');
    }
  }

  let profanity = false;

  // 2a) PHRASES multi-mots (« sale arabe », « hijo de puta », blocs admin
  // multi-mots) : censure sur le TEXTE ENTIER (le passage token par token
  // ci-dessous ne peut pas matcher un espace). v406.
  const censorPhrases = (re) => {
    if (!re) return;
    re.lastIndex = 0;
    if (re.test(working)) {
      profanity = true;
      re.lastIndex = 0;
      working = working.replace(re, (m) => STARS(m.replace(/\s+/g, '')));
    }
  };
  censorPhrases(PROFANITY_PHRASE_RE);
  censorPhrases(EXTRA_PHRASE_RE);

  // 2b) Insultes (mots simples) : détection sur la version dé-leetée, censure
  // sur le texte original mot par mot (on remplace tout mot dont la forme
  // dé-leetée matche).
  const clean = working.replace(/[\p{L}\p{N}@$._\-*]+/gu, (token) => {
    const normalized = deLeet(token);
    PROFANITY_RE.lastIndex = 0;
    let hit = PROFANITY_RE.test(normalized);
    if (!hit && EXTRA_RE) {
      EXTRA_RE.lastIndex = 0;
      hit = EXTRA_RE.test(normalized);
    }
    if (hit) {
      profanity = true;
      return STARS(token.replace(/[._\-*@$]/g, ''));
    }
    return token;
  });

  return {
    clean,
    censored: profanity || threat,
    profanity,
    threat,
  };
}

/** Raccourci booléen. */
function isClean(text) {
  const r = moderateText(text);
  return !r.profanity && !r.threat;
}

module.exports = { moderateText, isClean, setExtraWords, PROFANITY, THREAT_PATTERNS };
