// 27/09/2026 — LEO : chargement des langues du site À LA DEMANDE.
//
// Avant : chaque page téléchargeait les 9 langues d'un coup (un fichier JS de
// ~774 Ko, ~242 Ko compressés) parce que LanguageProvider importait tout
// `translations.ts`. Maintenant les textes restent écrits au même endroit
// (translations.ts + les fichiers d'ajouts pawmap584.ts, map590.ts, …) — rien
// ne change pour qui les modifie — et ce script produit UN fichier JSON par
// langue dans src/lib/i18n/generated/. Le navigateur reçoit la langue de la
// page (celle du HTML servi) et, seulement si elle diffère, la langue du
// visiteur dans un fichier à part.
//
// Lancé automatiquement par next.config.js à chaque `next build` / `next dev`
// (y compris sur Vercel) : impossible d'oublier de régénérer. À la main :
//   node scripts/i18n-split.js          → régénère
//   node scripts/i18n-split.js --check  → vérifie 0 clé perdue, 0 texte changé
"use strict";

const fs = require("fs");
const path = require("path");

const I18N_DIR = path.join(__dirname, "..", "src", "lib", "i18n");
const OUT_DIR = path.join(I18N_DIR, "generated");

/** Évalue un fichier .ts du dossier i18n (et ses imports relatifs) sans outil externe. */
function loadTs(entry) {
  const ts = require("typescript");
  const cache = new Map();
  function load(file) {
    if (cache.has(file)) return cache.get(file).exports;
    const src = fs.readFileSync(file, "utf8");
    const out = ts.transpileModule(src, {
      compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2019 },
      fileName: file,
    }).outputText;
    const mod = { exports: {} };
    cache.set(file, mod);
    const req = (spec) => {
      if (!spec.startsWith(".")) throw new Error(`i18n-split : import non relatif interdit dans ${file} : ${spec}`);
      const base = path.resolve(path.dirname(file), spec);
      const cand = [base, `${base}.ts`, `${base}.tsx`].find((p) => fs.existsSync(p) && fs.statSync(p).isFile());
      if (!cand) throw new Error(`i18n-split : introuvable ${spec} depuis ${file}`);
      return load(cand);
    };
    new Function("exports", "require", "module", out)(mod.exports, req, mod);
    return mod.exports;
  }
  return load(entry);
}

function readSource() {
  const m = loadTs(path.join(I18N_DIR, "translations.ts"));
  if (!m.t || !Array.isArray(m.LANGUAGES)) throw new Error("i18n-split : translations.ts n'exporte plus t / LANGUAGES");
  return { bundles: m.t, codes: m.LANGUAGES.map((l) => l.code) };
}

// 27/09/2026 — décision de Daniel : le FRANÇAIS est la langue par défaut et
// de repli. Une clé absente d'une langue est complétée ici par le texte
// français (à défaut, anglais) : chaque fichier de langue se suffit à
// lui-même, le navigateur n'a jamais besoin d'une 2e langue en secours.
const FALLBACKS = ["fr", "en"];
function withFallback(bundles, codes, code) {
  const out = { ...bundles[code] };
  for (const fb of FALLBACKS) {
    if (fb === code || !bundles[fb]) continue;
    for (const [k, v] of Object.entries(bundles[fb])) if (!(k in out)) out[k] = v;
  }
  return out;
}

function writeIfChanged(file, content) {
  try {
    if (fs.readFileSync(file, "utf8") === content) return false;
  } catch {
    /* absent */
  }
  fs.writeFileSync(file, content);
  return true;
}

function generate() {
  const { bundles, codes } = readSource();
  fs.mkdirSync(OUT_DIR, { recursive: true });
  let changed = 0;
  for (const code of codes) {
    const dict = bundles[code];
    if (!dict || typeof dict !== "object") throw new Error(`i18n-split : langue ${code} absente de t`);
    const full = withFallback(bundles, codes, code);
    // Clés triées : le fichier ne change que si un texte change.
    const sorted = {};
    for (const k of Object.keys(full).sort()) sorted[k] = full[k];
    if (writeIfChanged(path.join(OUT_DIR, `${code}.json`), JSON.stringify(sorted) + "\n")) changed++;
  }
  return { codes, changed };
}

function check() {
  const { bundles, codes } = readSource();
  let lost = 0;
  let diff = 0;
  let total = 0;
  const files = fs.readdirSync(OUT_DIR).filter((f) => f.endsWith(".json")).map((f) => f.replace(/\.json$/, ""));
  const extra = files.filter((c) => !codes.includes(c));
  for (const code of codes) {
    const src = bundles[code];
    let gen = {};
    try {
      gen = JSON.parse(fs.readFileSync(path.join(OUT_DIR, `${code}.json`), "utf8"));
    } catch {
      console.log(`${code} : FICHIER MANQUANT`);
      lost += Object.keys(src).length;
      continue;
    }
    const srcKeys = Object.keys(src);
    const missing = srcKeys.filter((k) => !(k in gen));
    // Clés en plus = seulement les compléments français/anglais attendus.
    const expected = withFallback(bundles, codes, code);
    const filled = Object.keys(gen).filter((k) => !(k in src) && gen[k] === expected[k]);
    const added = Object.keys(gen).filter((k) => !(k in src) && gen[k] !== expected[k]);
    const notFilled = Object.keys(expected).filter((k) => !(k in gen));
    const changedVals = srcKeys.filter((k) => k in gen && gen[k] !== src[k]);
    lost += missing.length + added.length + notFilled.length;
    diff += changedVals.length;
    total += srcKeys.length;
    console.log(`${code} : ${srcKeys.length} clés source, ${Object.keys(gen).length} générées, ${missing.length} perdues, ${added.length} en trop, ${filled.length} complétées (fr/en), ${changedVals.length} textes différents`);
  }
  if (extra.length) console.log(`Fichiers de langue en trop : ${extra.join(", ")}`);
  console.log(`Total : ${codes.length} langues, ${total} textes — ${lost} clés perdues/en trop, ${diff} textes différents`);
  return lost === 0 && diff === 0 && extra.length === 0 && codes.length > 0;
}

// 27/09/2026 — depuis le passage aux layouts racines par langue, toute page
// doit vivre dans un groupe src/app/(site|fr|en|de|es|it|pt|pl|ko|ja)/. Un
// dossier de page posé directement sous src/app/ (ex. un nouvel article de
// blog) n'aurait pas de layout racine : Next échouerait avec un message
// obscur. On échoue ici avec la marche à suivre.
function checkRouteGroups() {
  const APP = path.join(__dirname, "..", "src", "app");
  const allowed = new Set(["api"]);
  const stray = [];
  for (const e of fs.readdirSync(APP, { withFileTypes: true })) {
    if (e.isDirectory() && !e.name.startsWith("(") && !e.name.startsWith("_") && !allowed.has(e.name)) stray.push(e.name);
    if (e.isFile() && /^(page|layout)\.(tsx|ts|jsx|js)$/.test(e.name)) stray.push(e.name);
  }
  if (stray.length) {
    throw new Error(
      `Pages hors groupe de langue dans src/app/ : ${stray.join(", ")}.\n` +
        "Chaque page doit être dans src/app/(xx)/… selon la langue de son contenu :\n" +
        "(site) = pages génériques servies en français et traduites à l'affichage ;\n" +
        "(fr) (en) (de) (es) (it) (pt) (pl) (ko) (ja) = pages écrites dans cette langue\n" +
        "(ex. article de blog anglais : src/app/(en)/blog/<slug>/page.tsx). Voir components/RootShell.tsx."
    );
  }
}

module.exports = { generate, check, checkRouteGroups };

if (require.main === module) {
  if (process.argv.includes("--check")) {
    process.exit(check() ? 0 : 1);
  } else {
    const r = generate();
    console.log(`i18n-split : ${r.codes.length} langues (${r.codes.join(", ")}), ${r.changed} fichier(s) mis à jour`);
  }
}
