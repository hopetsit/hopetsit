// 27/09/2026 — LEO : chargement des langues du site À LA DEMANDE.
//
// Avant : chaque page téléchargeait les 9 langues d'un coup (un fichier JS de
// ~774 Ko, ~242 Ko compressés) parce que LanguageProvider importait tout
// `translations.ts`. Maintenant les textes restent écrits au même endroit
// (translations.ts + les fichiers d'ajouts pawmap584.ts, map590.ts, …) — rien
// ne change pour qui les modifie — et ce script produit UN fichier JSON par
// langue dans src/lib/i18n/generated/. Le navigateur reçoit l'anglais (langue
// du rendu serveur et langue de repli) et UNE seule autre langue, chargée à
// part seulement si c'est la langue du visiteur.
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
    // Clés triées : le fichier ne change que si un texte change.
    const sorted = {};
    for (const k of Object.keys(dict).sort()) sorted[k] = dict[k];
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
    const added = Object.keys(gen).filter((k) => !(k in src));
    const changedVals = srcKeys.filter((k) => k in gen && gen[k] !== src[k]);
    lost += missing.length + added.length;
    diff += changedVals.length;
    total += srcKeys.length;
    console.log(`${code} : ${srcKeys.length} clés source, ${Object.keys(gen).length} générées, ${missing.length} perdues, ${added.length} en trop, ${changedVals.length} textes différents`);
  }
  if (extra.length) console.log(`Fichiers de langue en trop : ${extra.join(", ")}`);
  console.log(`Total : ${codes.length} langues, ${total} textes — ${lost} clés perdues/en trop, ${diff} textes différents`);
  return lost === 0 && diff === 0 && extra.length === 0 && codes.length > 0;
}

module.exports = { generate, check };

if (require.main === module) {
  if (process.argv.includes("--check")) {
    process.exit(check() ? 0 : 1);
  } else {
    const r = generate();
    console.log(`i18n-split : ${r.codes.length} langues (${r.codes.join(", ")}), ${r.changed} fichier(s) mis à jour`);
  }
}
