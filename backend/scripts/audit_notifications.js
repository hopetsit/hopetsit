#!/usr/bin/env node
/* eslint-disable no-console */
/**
 * Audit des notifications HoPetSit — SANS base de données, SANS envoi.
 *
 *   node backend/scripts/audit_notifications.js            # rapport lisible
 *   node backend/scripts/audit_notifications.js --json     # rapport JSON
 *   node backend/scripts/audit_notifications.js --verbose  # + tableau type → route → catégorie → variables
 *
 * Contrôles (référence = locales/fr/notifications.json) :
 *   1. catalogue  : mêmes types dans les 9 langues, 4 champs non vides
 *                   (title, body, emailSubject, emailBody) ;
 *   2. variables  : mêmes {{variables}} que le français, champ par champ ;
 *   3. appelants  : chaque variable d'un gabarit est fournie par AU MOINS un
 *                   appelant de sendNotification (analyse statique de src/) et
 *                   chaque type émis par le code a un gabarit ;
 *   4. longueurs  : titre ≤ 50 car., corps push ≤ 140 car. (variables = 8 car.) ;
 *   5. e-mail     : {{emailLink}} présent dans un <a href>, lien de secours,
 *                   aucun lien en dur hors https://www.hopetsit.com, aucun
 *                   `hopetsit://`, aucune accolade simple `{emailLink}` ;
 *   6. langue     : reste d'anglais / de français dans une autre langue,
 *                   texte identique au français ou à l'anglais, ko/ja sans
 *                   caractères coréens / japonais ;
 *   7. routage    : buildAppRoute(type) ≠ /notifications et chemin connu de
 *                   l'app (deep_link_service.dart) ; catégorie de préférences ;
 *   8. test-fire  : TEST_SAMPLE_DATA couvre toutes les variables ;
 *   9. cycle de vie : locales/<lang>/lifecycle.json, mêmes étapes, mêmes champs,
 *                   mêmes variables que le français.
 *
 * Code de sortie : 0 = aucune ERREUR (les AVERTISSEMENTS n'échouent pas), 1 sinon.
 */
const fs = require('fs');
const path = require('path');

const SRC = path.join(__dirname, '..', 'src');
const LOCALES_DIR = path.join(SRC, 'locales');
const LOCALES = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
const FIELDS = ['title', 'body', 'emailSubject', 'emailBody'];
const MAX_TITLE = 50;
const MAX_BODY = 140;
const VAR_RE = /\{\{\s*([\w.]+)\s*\}\}/g;
// Variables injectées par sendNotification lui-même (jamais par l'appelant).
const BUILTIN_VARS = new Set(['emailLink']);

const args = new Set(process.argv.slice(2));
const AS_JSON = args.has('--json');
const VERBOSE = args.has('--verbose');

const errors = [];
const warnings = [];
const err = (zone, msg) => errors.push({ zone, msg });
const warn = (zone, msg) => warnings.push({ zone, msg });

const readJson = (file) => {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (e) {
    err('catalogue', `${path.relative(SRC, file)} illisible : ${e.message}`);
    return {};
  }
};
const varsOf = (s) => {
  const out = new Set();
  for (const m of String(s || '').matchAll(VAR_RE)) out.add(m[1]);
  return out;
};
const stripHtml = (s) => String(s || '').replace(/<[^>]+>/g, ' ').replace(/&[a-z]+;/g, ' ');
const plain = (s) => stripHtml(s).replace(VAR_RE, ' ').replace(/https?:\/\/\S+/g, ' ');
const sizedLength = (s) => Array.from(String(s || '').replace(VAR_RE, 'XXXXXXXX')).length;

// ── 1. Catalogues ───────────────────────────────────────────────────────────
const catalogs = {};
for (const l of LOCALES) catalogs[l] = readJson(path.join(LOCALES_DIR, l, 'notifications.json'));
const REF = catalogs.fr;
const TYPES = Object.keys(REF);

for (const l of LOCALES) {
  const cat = catalogs[l];
  for (const t of TYPES) {
    if (!cat[t]) { err('catalogue', `[${l}] type absent : ${t}`); continue; }
    for (const f of FIELDS) {
      if (typeof cat[t][f] !== 'string' || !cat[t][f].trim()) err('catalogue', `[${l}] ${t}.${f} vide ou absent`);
    }
    for (const f of Object.keys(cat[t])) {
      if (!FIELDS.includes(f)) warn('catalogue', `[${l}] ${t}.${f} : champ inconnu (ignoré par le serveur)`);
    }
  }
  for (const t of Object.keys(cat)) {
    if (!REF[t]) err('catalogue', `[${l}] type en trop (absent du français) : ${t}`);
  }
}

// ── 2. Variables identiques au français, champ par champ ────────────────────
for (const l of LOCALES) {
  if (l === 'fr') continue;
  for (const t of TYPES) {
    if (!catalogs[l][t]) continue;
    for (const f of FIELDS) {
      const a = varsOf(REF[t][f]);
      const b = varsOf(catalogs[l][t][f]);
      const missing = [...a].filter((v) => !b.has(v));
      const extra = [...b].filter((v) => !a.has(v));
      if (missing.length) err('variables', `[${l}] ${t}.${f} : variable(s) manquante(s) ${missing.map((v) => `{{${v}}}`).join(' ')}`);
      if (extra.length) err('variables', `[${l}] ${t}.${f} : variable(s) en trop ${extra.map((v) => `{{${v}}}`).join(' ')}`);
    }
  }
}

// ── 3. Appelants de sendNotification (analyse statique) ─────────────────────
const walk = (dir, out = []) => {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.name === 'node_modules' || e.name === 'locales') continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (e.name.endsWith('.js')) out.push(p);
  }
  return out;
};
/** Bloc équilibré à partir de l'index d'une ouvrante ( { [ — ignore chaînes et commentaires. */
const balanced = (src, start) => {
  const open = src[start];
  const close = { '(': ')', '{': '}', '[': ']' }[open];
  let depth = 0;
  for (let i = start; i < src.length; i += 1) {
    const c = src[i];
    if (c === '"' || c === "'" || c === '`') {
      const q = c; i += 1;
      while (i < src.length && src[i] !== q) { if (src[i] === '\\') i += 1; i += 1; }
      continue;
    }
    if (c === '/' && src[i + 1] === '/') { while (i < src.length && src[i] !== '\n') i += 1; continue; }
    if (c === '/' && src[i + 1] === '*') { i = src.indexOf('*/', i + 2) + 1; continue; }
    if (c === open) depth += 1;
    else if (c === close) { depth -= 1; if (depth === 0) return src.slice(start, i + 1); }
  }
  return src.slice(start);
};
/** Clés de premier niveau d'un littéral objet `{ a: 1, b, ...c, 'd': 2 }`. */
const topLevelKeys = (objSrc) => {
  const keys = []; const spreads = [];
  const inner = objSrc.slice(1, -1);
  let i = 0; let depth = 0; let token = '';
  const flush = () => {
    const tk = token.trim(); token = '';
    if (!tk) return;
    if (tk.startsWith('...')) { spreads.push(tk.slice(3).trim()); return; }
    const m = tk.match(/^(?:\[[^\]]+\]|['"]?([\w$]+)['"]?)\s*(?::|$)/);
    if (m && m[1]) keys.push(m[1]);
  };
  while (i < inner.length) {
    const c = inner[i];
    if (c === '"' || c === "'" || c === '`') {
      const q = c; token += c; i += 1;
      while (i < inner.length && inner[i] !== q) { if (inner[i] === '\\') { token += inner[i]; i += 1; } token += inner[i]; i += 1; }
      token += q; i += 1; continue;
    }
    if (c === '/' && inner[i + 1] === '/') { while (i < inner.length && inner[i] !== '\n') i += 1; continue; }
    if (c === '/' && inner[i + 1] === '*') { i = inner.indexOf('*/', i + 2) + 2; continue; }
    if ('({['.includes(c)) depth += 1;
    if (')}]'.includes(c)) depth -= 1;
    if (c === ',' && depth === 0) { flush(); i += 1; continue; }
    token += c; i += 1;
  }
  flush();
  return { keys, spreads };
};
/** Valeur (source brute) d'une propriété de premier niveau d'un littéral objet. */
const propSource = (objSrc, name) => {
  const inner = objSrc.slice(1, -1);
  let depth = 0;
  for (let i = 0; i < inner.length; i += 1) {
    const c = inner[i];
    if (c === '"' || c === "'" || c === '`') { const q = c; i += 1; while (i < inner.length && inner[i] !== q) { if (inner[i] === '\\') i += 1; i += 1; } continue; }
    if (c === '/' && inner[i + 1] === '/') { while (i < inner.length && inner[i] !== '\n') i += 1; continue; }
    if ('({['.includes(c)) { depth += 1; continue; }
    if (')}]'.includes(c)) { depth -= 1; continue; }
    if (depth !== 0) continue;
    const before = i === 0 ? ',' : inner.slice(0, i).trimEnd().slice(-1);
    if ((before === ',' || before === '' || before === '{') && inner.startsWith(name, i) && /^\s*[:,}]|^\s*$/.test(inner.slice(i + name.length, i + name.length + 3) || ' ')) {
      const rest = inner.slice(i + name.length).trimStart();
      if (!rest.startsWith(':')) return name; // raccourci `type,`
      const valStart = inner.indexOf(':', i + name.length) + 1;
      let j = valStart; let d = 0;
      for (; j < inner.length; j += 1) {
        const ch = inner[j];
        if (ch === '"' || ch === "'" || ch === '`') { const q = ch; j += 1; while (j < inner.length && inner[j] !== q) { if (inner[j] === '\\') j += 1; j += 1; } continue; }
        if ('({['.includes(ch)) d += 1;
        if (')}]'.includes(ch)) d -= 1;
        if ((ch === ',' && d === 0) || d < 0) break;
      }
      return inner.slice(valStart, j).trim();
    }
  }
  return null;
};

const callers = {}; // type → [{ file, line, keys:Set, open:boolean }]
const dynamicCalls = [];
for (const file of walk(SRC)) {
  const rel = path.relative(SRC, file);
  if (rel === path.join('services', 'notificationSender.js')) continue;
  const src = fs.readFileSync(file, 'utf8');
  const re = /\bsendNotification\s*\(/g;
  let m;
  while ((m = re.exec(src))) {
    const parenIdx = m.index + m[0].length - 1;
    const call = balanced(src, parenIdx);
    const line = src.slice(0, m.index).split('\n').length;
    const braceIdx = call.indexOf('{');
    if (braceIdx < 0) { dynamicCalls.push(`${rel}:${line} (argument non littéral)`); continue; }
    const obj = balanced(call, braceIdx);
    const typeSrc = propSource(obj, 'type');
    const dataSrc = propSource(obj, 'data');
    let types = [];
    if (typeSrc) {
      const direct = typeSrc.match(/^['"`](\w+)['"`]$/);
      // Ternaire : seules les BRANCHES comptent (`action === 'accept' ? 'a' : 'b'` → a, b).
      const branches = [...typeSrc.matchAll(/[?:]\s*['"`](\w+)['"`]/g)].map((x) => x[1]);
      if (direct) types = [direct[1]];
      else if (branches.length) types = branches;
    }
    let keys = new Set(); let open = false;
    if (dataSrc && dataSrc.startsWith('{')) {
      const r = topLevelKeys(balanced(dataSrc, 0));
      keys = new Set(r.keys);
      for (const sp of r.spreads) {
        // Résolution locale d'un spread `...ident` : dernier `const ident = {…}` avant l'appel.
        const ident = sp.match(/^[\w$]+$/) ? sp : null;
        let resolved = false;
        if (ident) {
          const before = src.slice(0, m.index);
          const decl = [...before.matchAll(new RegExp(`(?:const|let|var)\\s+${ident}\\s*=\\s*\\{`, 'g'))].pop();
          if (decl) {
            const o = balanced(src, decl.index + decl[0].length - 1);
            const rr = topLevelKeys(o);
            rr.keys.forEach((k) => keys.add(k));
            if (!rr.spreads.length) resolved = true;
          }
        }
        if (!resolved) open = true;
      }
    } else if (dataSrc) {
      const ident = dataSrc.match(/^[\w$]+$/) ? dataSrc : null;
      let resolved = false;
      if (ident) {
        const before = src.slice(0, m.index);
        const decl = [...before.matchAll(new RegExp(`(?:const|let|var)\\s+${ident}\\s*=\\s*\\{`, 'g'))].pop();
        if (decl) {
          const rr = topLevelKeys(balanced(src, decl.index + decl[0].length - 1));
          keys = new Set(rr.keys);
          resolved = !rr.spreads.length;
        }
      }
      if (!resolved) open = true;
    }
    if (!types.length) { dynamicCalls.push(`${rel}:${line} (type = ${typeSrc || '?'})`); continue; }
    for (const t of types) (callers[t] = callers[t] || []).push({ file: rel, line, keys, open });
  }
}

// Filets de sécurité côté notificationSender (variable complétée par le serveur si l'appelant l'oublie).
const senderSrc = fs.readFileSync(path.join(SRC, 'services', 'notificationSender.js'), 'utf8');
const SAFETY_NETS = {};
if (/const ensureSenderName\b/.test(senderSrc) && /ensureSenderName\(type/.test(senderSrc)) SAFETY_NETS['NEW_MESSAGE.senderName'] = 'ensureSenderName';

const templateVars = {};
for (const t of TYPES) {
  const s = new Set();
  for (const f of FIELDS) varsOf(REF[t][f]).forEach((v) => { if (!BUILTIN_VARS.has(v)) s.add(v.split('.')[0]); });
  templateVars[t] = s;
}
for (const t of Object.keys(callers)) {
  if (!REF[t]) {
    // Insensible à la casse ? (pickTemplate est sensible à la casse)
    const ci = TYPES.find((k) => k.toLowerCase() === t.toLowerCase());
    err('appelants', `type « ${t} » émis (${callers[t].map((c) => `${c.file}:${c.line}`).join(', ')}) SANS gabarit${ci ? ` — casse différente du gabarit « ${ci} »` : ''} → notification jamais envoyée`);
  }
}
for (const t of TYPES) {
  const cs = callers[t] || [];
  if (!cs.length) { warn('appelants', `${t} : aucun appelant littéral trouvé (type dynamique ou gabarit inutilisé)`); continue; }
  for (const v of templateVars[t]) {
    const lacking = cs.filter((c) => !c.keys.has(v) && !c.open);
    const unsure = cs.filter((c) => !c.keys.has(v) && c.open);
    if (lacking.length && SAFETY_NETS[`${t}.${v}`]) warn('appelants', `${t} : {{${v}}} non fourni par ${lacking.map((c) => `${c.file}:${c.line}`).join(', ')} — rattrapé par notificationSender.${SAFETY_NETS[`${t}.${v}`]} (à corriger chez l'appelant)`);
    else if (lacking.length) err('appelants', `${t} : {{${v}}} jamais fourni par ${lacking.map((c) => `${c.file}:${c.line}`).join(', ')} → texte troué`);
    else if (unsure.length) warn('appelants', `${t} : {{${v}}} non vérifiable (data dynamique) dans ${unsure.map((c) => `${c.file}:${c.line}`).join(', ')}`);
  }
}

// ── 4. Longueurs ────────────────────────────────────────────────────────────
for (const l of LOCALES) {
  for (const t of TYPES) {
    const e = catalogs[l][t];
    if (!e) continue;
    const tl = sizedLength(e.title);
    const bl = sizedLength(e.body);
    if (tl > MAX_TITLE) warn('longueurs', `[${l}] ${t}.title = ${tl} car. (> ${MAX_TITLE})`);
    if (bl > MAX_BODY) warn('longueurs', `[${l}] ${t}.body = ${bl} car. (> ${MAX_BODY})`);
  }
}

// ── 5. E-mail : bouton, lien de secours, domaines ───────────────────────────
let buildNotificationEmailHtml = null;
try {
  process.env.LOG_LEVEL = process.env.LOG_LEVEL || 'silent';
  ({ buildNotificationEmailHtml } = require(path.join(SRC, 'services', 'emailService.js')));
} catch (e) {
  warn('email', `emailService indisponible (${e.message.split('\n')[0]})`);
}
if (!buildNotificationEmailHtml) warn('email', 'emailService.buildNotificationEmailHtml absent : les e-mails partent sans gabarit (viewport, bouton centré, pied de page)');
for (const l of LOCALES) {
  for (const t of TYPES) {
    const html = catalogs[l][t] && catalogs[l][t].emailBody;
    if (!html) continue;
    if (!/<a\s[^>]*href="\{\{\s*emailLink\s*\}\}"/.test(html)) err('email', `[${l}] ${t}.emailBody : pas de bouton <a href="{{emailLink}}">`);
    // Lien de secours : vérifié sur l'e-mail FINAL (gabarit commun emailService).
    if (buildNotificationEmailHtml) {
      const link = 'https://www.hopetsit.com/bookings';
      const final = buildNotificationEmailHtml(html.replace(/\{\{\s*emailLink\s*\}\}/g, link), { locale: l, link, preheader: 'x' });
      if (final.split(link).length - 1 < 2) err('email', `[${l}] ${t} : e-mail final sans lien de secours`);
      if (!/name="viewport"/.test(final)) err('email', `[${l}] ${t} : e-mail final sans viewport mobile`);
      if (!/text-align:center[^>]*>\s*<a\s/.test(final)) warn('email', `[${l}] ${t} : bouton non centré dans l'e-mail final`);
    } else {
      const occurrences = (html.match(/\{\{\s*emailLink\s*\}\}/g) || []).length;
      if (occurrences < 2) warn('email', `[${l}] ${t}.emailBody : pas de lien de secours en clair (« si le bouton ne fonctionne pas »)`);
    }
    if (/(^|[^{])\{emailLink\}([^}]|$)/.test(html)) err('email', `[${l}] ${t}.emailBody : accolade simple {emailLink} (jamais remplacée)`);
    if (/hopetsit:\/\//i.test(html)) err('email', `[${l}] ${t}.emailBody : lien hopetsit:// (non cliquable dans un e-mail)`);
    for (const m of html.matchAll(/https?:\/\/[^\s"'<)]+/g)) {
      if (!m[0].startsWith('https://www.hopetsit.com')) err('email', `[${l}] ${t}.emailBody : lien en dur hors www → ${m[0]}`);
    }
    for (const f of ['title', 'body', 'emailSubject']) {
      if (/<[a-z][^>]*>/i.test(catalogs[l][t][f] || '')) err('email', `[${l}] ${t}.${f} : contient du HTML`);
    }
  }
}

// ── 6. Langue ───────────────────────────────────────────────────────────────
const FR_WORDS = ['vous', 'votre', 'vos', 'avec', 'dans', 'une', 'été', 'réservation', 'bonjour', "l'équipe", 'pour', 'cette', 'est', 'sur'];
const EN_WORDS = ['the', 'your', 'you', 'with', 'please', 'been', 'this', 'and', 'for', 'from', 'has', 'open'];
const LATIN_TARGETS = ['es', 'de', 'it', 'pt', 'pl'];
// Mots autorisés (marques et emprunts) qu'on retire avant de compter.
const BRAND_RE = /hopetsit|pawmap|pawfollow|pawspot|pawpremium|pawpoints|pawboost|paw premium|paw follow|paw spot|premium|top sitter|chat|app|iban|kyc|sos|e-mail|email|gps|live/gi;
const countHits = (text, words) => {
  const tokens = new Set(text.toLowerCase().replace(BRAND_RE, ' ').split(/[^\p{L}'’]+/u).filter(Boolean));
  return words.filter((w) => tokens.has(w));
};
const SHARED = {
  // faux amis : mots présents dans la liste FR/EN mais normaux dans la langue cible
  es: ['sur', 'has', 'este'], de: ['was', 'open', 'die', 'dies'], it: ['sur', 'una', 'per'],
  pt: ['sur', 'para'], pl: ['to', 'na', 'do'],
};
for (const l of LOCALES) {
  if (l === 'fr' || l === 'en') continue;
  for (const t of TYPES) {
    const e = catalogs[l][t];
    if (!e) continue;
    for (const f of FIELDS) {
      const txt = plain(e[f]).trim();
      if (!txt) continue;
      const same = (ref) => plain(catalogs[ref][t] && catalogs[ref][t][f]).trim() === txt;
      if (txt.replace(/[^\p{L}]/gu, '').length > 12) {
        if (same('fr')) warn('langue', `[${l}] ${t}.${f} identique au FRANÇAIS : « ${txt.slice(0, 60)} »`);
        else if (same('en')) warn('langue', `[${l}] ${t}.${f} identique à l'ANGLAIS : « ${txt.slice(0, 60)} »`);
      }
      if (l === 'ko' || l === 'ja') {
        const letters = txt.replace(BRAND_RE, '').replace(/[^\p{L}]/gu, '');
        const native = (letters.match(l === 'ko' ? /[가-힯]/g : /[぀-ヿ一-鿿]/g) || []).length;
        if (letters.length > 6 && native / letters.length < 0.6) warn('langue', `[${l}] ${t}.${f} : ${Math.round((native / letters.length) * 100)} % de caractères ${l} seulement → « ${txt.slice(0, 60)} »`);
      } else if (LATIN_TARGETS.includes(l)) {
        const ok = new Set(SHARED[l] || []);
        const fr = countHits(txt, FR_WORDS).filter((w) => !ok.has(w));
        const en = countHits(txt, EN_WORDS).filter((w) => !ok.has(w));
        if (fr.length >= 2) warn('langue', `[${l}] ${t}.${f} : reste de FRANÇAIS (${fr.join(', ')}) → « ${txt.slice(0, 70)} »`);
        if (en.length >= 2) warn('langue', `[${l}] ${t}.${f} : reste d'ANGLAIS (${en.join(', ')}) → « ${txt.slice(0, 70)} »`);
      }
    }
  }
}

// Ton français : tutoiement partout (décision Daniel, 18/09).
for (const t of TYPES) {
  for (const f of FIELDS) {
    const hits = plain(REF[t][f]).match(/(?<![\p{L}])(vous|votre|vos|veuillez|[\p{L}]{3,}ez)(?![\p{L}])/giu);
    const real = (hits || []).filter((w) => !/^(chez|assez|rez|nez)$/i.test(w));
    if (real.length) warn('langue', `[fr] ${t}.${f} : vouvoiement (${[...new Set(real)].join(', ')})`);
  }
}

// ── 7. Routage + catégories ─────────────────────────────────────────────────
const { buildAppRoute, BASE_URL } = require(path.join(SRC, 'utils', 'emailLinkBuilder.js'));
if (BASE_URL !== 'https://www.hopetsit.com' && !process.env.WEBSITE_URL) err('routage', `BASE_URL = ${BASE_URL} (attendu https://www.hopetsit.com)`);
const OID = 'a'.repeat(24);
const SAMPLE_IDS = { bookingId: OID, conversationId: OID, postId: OID, reportId: OID, walkId: OID, applicationId: OID };
// Chemins réellement gérés par l'app (frontend/lib/services/deep_link_service.dart).
const APP_PATHS = [
  /^\/bookings(\/[a-f0-9]{24})?$/, /^\/pay\?bookingId=[a-f0-9]{24}$/, /^\/chat(\/[a-f0-9]{24})?$/,
  /^\/walk\/[a-f0-9]{24}$/, /^\/post\/[a-f0-9]{24}$/, /^\/wallet$/, /^\/subscription$/, /^\/paw-spot$/,
  /^\/profile$/, /^\/friends$/, /^\/friends\/requests$/, /^\/friends\/live$/, /^\/alert\/[a-f0-9]{24}$/,
  /^\/map$/, /^\/notifications$/,
];
let categoryForType = null;
try {
  // notificationSender charge firebase-admin : on le neutralise (aucun envoi, aucune base).
  const fbPath = require.resolve(path.join(SRC, 'config', 'firebaseAdmin.js'));
  require.cache[fbPath] = { id: fbPath, filename: fbPath, loaded: true, exports: {} };
  process.env.LOG_LEVEL = process.env.LOG_LEVEL || 'silent';
  ({ categoryForType } = require(path.join(SRC, 'services', 'notificationSender.js')));
} catch (e) {
  warn('routage', `categoryForType indisponible (${e.message.split('\n')[0]})`);
}
const routing = [];
for (const t of TYPES) {
  const withIds = buildAppRoute(t, SAMPLE_IDS);
  const withoutIds = buildAppRoute(t, {});
  const cat = categoryForType ? categoryForType(t) : '?';
  routing.push({ type: t, route: withIds.replace(OID, ':id'), fallback: withoutIds, category: cat, vars: [...templateVars[t]] });
  if (withIds === '/notifications') warn('routage', `${t} : aucune route dédiée (ouvre la cloche /notifications)`);
  for (const r of [withIds, withoutIds]) {
    if (!APP_PATHS.some((re) => re.test(r))) err('routage', `${t} : route « ${r} » inconnue de l'app`);
  }
}

// ── 8. test-fire : variables d'exemple ──────────────────────────────────────
try {
  const routesSrc = fs.readFileSync(path.join(SRC, 'routes', 'notificationRoutes.js'), 'utf8');
  const idx = routesSrc.indexOf('TEST_SAMPLE_DATA');
  const brace = routesSrc.indexOf('{', idx);
  const sampleKeys = new Set(topLevelKeys(balanced(routesSrc, brace)).keys);
  const missing = new Set();
  for (const t of TYPES) for (const v of templateVars[t]) if (!sampleKeys.has(v)) missing.add(v);
  if (missing.size) err('test-fire', `TEST_SAMPLE_DATA ne fournit pas : ${[...missing].join(', ')} → textes troués dans « Tester mes notifications »`);
} catch (e) {
  warn('test-fire', `analyse impossible : ${e.message}`);
}

// ── 9. Cycle de vie ─────────────────────────────────────────────────────────
const life = {};
for (const l of LOCALES) life[l] = readJson(path.join(LOCALES_DIR, l, 'lifecycle.json'));
const flatten = (o, prefix = '', out = {}) => {
  for (const [k, v] of Object.entries(o || {})) {
    if (v && typeof v === 'object' && !Array.isArray(v)) flatten(v, `${prefix}${k}.`, out);
    else out[`${prefix}${k}`] = Array.isArray(v) ? v.join('\n') : String(v);
  }
  return out;
};
const lifeRef = flatten(life.fr);
for (const l of LOCALES) {
  if (l === 'fr') continue;
  const cur = flatten(life[l]);
  for (const k of Object.keys(lifeRef)) {
    if (!(k in cur) || !cur[k].trim()) { err('cycle-de-vie', `[${l}] ${k} absent ou vide`); continue; }
    const a = varsOf(lifeRef[k]); const b = varsOf(cur[k]);
    const miss = [...a].filter((v) => !b.has(v)); const extra = [...b].filter((v) => !a.has(v));
    if (miss.length || extra.length) err('cycle-de-vie', `[${l}] ${k} : variables ≠ français (manque ${miss.join(',') || '—'} ; en trop ${extra.join(',') || '—'})`);
    if (l !== 'en' && !/Url$/.test(k) && cur[k].replace(/[^\p{L}]/gu, '').length > 12) {
      if (plain(cur[k]).trim() === plain(lifeRef[k]).trim()) warn('cycle-de-vie', `[${l}] ${k} identique au FRANÇAIS`);
      else if (life.en && plain(cur[k]).trim() === plain(flatten(life.en)[k]).trim()) warn('cycle-de-vie', `[${l}] ${k} identique à l'ANGLAIS`);
    }
  }
  for (const k of Object.keys(cur)) if (!(k in lifeRef)) err('cycle-de-vie', `[${l}] ${k} en trop (absent du français)`);
  for (const [k, v] of Object.entries(cur)) {
    for (const m of v.matchAll(/https?:\/\/[^\s"'<)]+/g)) {
      if (/hopetsit\.com/.test(m[0]) && !m[0].startsWith('https://www.hopetsit.com')) err('cycle-de-vie', `[${l}] ${k} : lien hors www → ${m[0]}`);
    }
  }
}

// ── Rapport ─────────────────────────────────────────────────────────────────
const byZone = (list) => list.reduce((acc, x) => { (acc[x.zone] = acc[x.zone] || []).push(x.msg); return acc; }, {});
const report = {
  types: TYPES.length,
  locales: LOCALES.length,
  callSites: Object.values(callers).reduce((n, a) => n + a.length, 0),
  dynamicCalls,
  errors: byZone(errors),
  warnings: byZone(warnings),
  errorCount: errors.length,
  warningCount: warnings.length,
  routing,
};
if (AS_JSON) {
  console.log(JSON.stringify(report, null, 2));
} else {
  console.log(`Audit notifications — ${TYPES.length} types × ${LOCALES.length} langues, ${report.callSites} appels littéraux, ${dynamicCalls.length} appels dynamiques`);
  if (VERBOSE) {
    console.log('\nTYPE → ROUTE (avec id) | repli (sans id) | catégorie | variables');
    for (const r of routing) console.log(`  ${r.type.padEnd(38)} ${r.route.padEnd(22)} ${r.fallback.padEnd(18)} ${String(r.category).padEnd(14)} ${r.vars.join(',')}`);
    console.log('\nAppels dynamiques (type non littéral) :');
    dynamicCalls.forEach((d) => console.log(`  ${d}`));
  }
  const print = (label, grouped) => {
    const zones = Object.keys(grouped);
    if (!zones.length) { console.log(`\n${label} : 0`); return; }
    for (const z of zones) {
      console.log(`\n${label} · ${z} (${grouped[z].length})`);
      grouped[z].forEach((m) => console.log(`  - ${m}`));
    }
  };
  print('ERREURS', report.errors);
  print('AVERTISSEMENTS', report.warnings);
  console.log(`\nTOTAL : ${errors.length} erreur(s), ${warnings.length} avertissement(s)`);
}
process.exit(errors.length ? 1 : 0);
