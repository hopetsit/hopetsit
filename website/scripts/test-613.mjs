// Test 613 (site) : node scripts/test-613.mjs
// PARITÉ app ↔ site, lue dans les fichiers Dart du dépôt (rien recopié à la main dans ce test) :
//  - « Rejoindre john » : pm613_join / pm613_join_plain / pm613_walk_time / route_duration_* (9 langues) ;
//  - « Rejoindre john · 355 m · 4 min à pied » : nombre jamais séparé de son unité (espaces insécables) ;
//  - alertes : gravité des 27 types, couleurs, auréole < 2 h, pâleur 1 → 0,78 → 0,58, emoji de chaque type ;
//  - jamais de rond vide : la règle « encre au centre » est la même que l'app.
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { joinLabel613, joinLine613, keepNumberWithUnit613, formatJoinDistance613, shouldRecomputeJoin613 } from "../src/lib/join613.ts";
import { alertLevel613, ALERT_COLOR_613, alertAlpha613, alertFresh613, REPORT_EMOJI_613, reportEmoji613, hasInk613, alertPinHtml613 } from "../src/lib/alerts613.ts";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const DEPOT = path.resolve(HERE, "../..");
const read = (p) => fs.readFileSync(path.join(DEPOT, p), "utf8");
const LANGS = ["fr", "en", "es", "de", "it", "pt", "ko", "ja", "pl"];
const TX = Object.fromEntries(LANGS.map((l) => [l, JSON.parse(read(`website/src/lib/i18n/generated/${l}.json`))]));

let n = 0;
const ok = (name, fn) => { fn(); n++; console.log("OK ", name); };

function dartBlock(src, lang) {
  const m = src.match(new RegExp(`'${lang}': <String, String>\\{([\\s\\S]*?)\\n  \\},`));
  assert.ok(m, `bloc ${lang}`);
  return m[1];
}
function dartVal(block, key) {
  const m = block.match(new RegExp(`'${key}':\\s*'((?:[^'\\\\]|\\\\.)*)'`)) || block.match(new RegExp(`'${key}':\\s*"((?:[^"\\\\]|\\\\.)*)"`));
  assert.ok(m, `clé ${key}`);
  return m[1].replace(/\\'/g, "'").replace(/\\"/g, '"');
}
const PM = read("frontend/lib/localization/v565/pm613_i18n.dart");
const APP = Object.fromEntries(LANGS.map((l) => {
  const b = dartBlock(PM, l), tr = read(`frontend/lib/localization/translations/${l}.dart`);
  return [l, {
    pm613_join: dartVal(b, "pm613_join"), pm613_join_plain: dartVal(b, "pm613_join_plain"), pm613_walk_time: dartVal(b, "pm613_walk_time"),
    route_duration_min: dartVal(tr, "route_duration_min"), route_duration_h: dartVal(tr, "route_duration_h"),
  }];
}));

ok("textes « Rejoindre » : 5 clés × 9 langues identiques à l'app, au caractère près", () => {
  const bad = [];
  for (const l of LANGS) for (const [k, v] of Object.entries(APP[l])) if (TX[l][k] !== v) bad.push([l, k, v, TX[l][k]]);
  assert.deepEqual(bad, []);
});

// Réplique de pawKeepNumberWithUnit613 (Dart) pour l'attendu : (\d)[ \t]+ → \d + NBSP ; [ \t]+(\d) → NBSP + \d.
const dartKeep = (s) => s.replace(/(\d)[ \t]+/g, "$1 ").replace(/[ \t]+(\d)/g, " $1");
ok("règle des espaces insécables = celle de l'app (le motif Dart est lu dans pawmap_sheets.dart)", () => {
  const src = read("frontend/lib/views/map/widgets/pawmap_sheets.dart");
  assert.ok(src.includes("RegExp(r'(\\d)[ \\t]+')") && src.includes("RegExp(r'[ \\t]+(\\d)')"), "motif Dart inchangé");
  for (const s of ["355 m", "4 min", "1 h 05 min", "1 Std. 5 Min.", "도보 4분", "4 min à pied", "1.2 km"]) assert.equal(keepNumberWithUnit613(s), dartKeep(s));
});

ok("« Rejoindre john · 355 m · 4 min à pied » dans les 9 langues ; aucun chiffre collé à une espace ordinaire", () => {
  for (const l of LANGS) {
    const t = (k) => TX[l][k];
    const got = joinLine613(t, { name: "john Carter", meters: 354.6, seconds: 240, walk: true });
    const a = APP[l];
    const want = [a.pm613_join.replace("@name", "john"), dartKeep("355 m"), dartKeep(a.pm613_walk_time.replace("@t", a.route_duration_min.replace("{min}", "4")))].join(" · ");
    assert.equal(got, want, l);
    // comme l'app : dans la distance et le temps (morceaux séparés par « · »), aucune espace ordinaire ne touche un chiffre
    for (const part of got.split(" · ").slice(1)) assert.ok(!/\d[ \t]|[ \t]\d/.test(part), `${l} : espace ordinaire à côté d'un chiffre dans « ${part} »`);
    // une heure et plus
    const h = joinLine613(t, { name: "john", meters: 5230, seconds: 3900, walk: true });
    assert.ok(h.split(" · ").slice(1).every((part) => !/\d[ \t]|[ \t]\d/.test(part)) && h.includes("5.2\u00A0km"), `${l} : ${h}`);
    // sans prénom
    assert.equal(joinLabel613(t, "  "), a.pm613_join_plain);
  }
  // FR exact (la phrase de BOB)
  assert.equal(joinLine613((k) => TX.fr[k], { name: "john", meters: 355, seconds: 240, walk: true }), "Rejoindre john · 355 m · 4 min à pied");
  // à vélo / en voiture : pas de « à pied »
  assert.equal(joinLine613((k) => TX.fr[k], { name: "john", meters: 1500, seconds: 300, walk: false }), "Rejoindre john · 1.5 km · 5 min");
  assert.equal(formatJoinDistance613(999.6), "1.0 km");
});

ok("recalcul quand john bouge = PawRouteFollow611 (50 m, ou 10 m après 30 s)", () => {
  const src = read("frontend/lib/views/map/widgets/pawmap_route611.dart");
  assert.match(src, /moveM = 50;/); assert.match(src, /slowMoveM = 10;/); assert.match(src, /every = Duration\(seconds: 30\);/);
  assert.equal(shouldRecomputeJoin613(50, 0), true);
  assert.equal(shouldRecomputeJoin613(49, 29_000), false);
  assert.equal(shouldRecomputeJoin613(10, 30_000), true);
  assert.equal(shouldRecomputeJoin613(9, 60_000), false);
});

// ── Alertes ──
const AL = read("frontend/lib/views/map/widgets/pawmap_alerts613.dart");
const MODEL = read("frontend/lib/models/map_report_model.dart");
const consts = Object.fromEntries([...MODEL.matchAll(/static const String (\w+) = '([a-z_]+)';/g)].map((m) => [m[1], m[2]]));
const ALL_TYPES = [...new Set(Object.values(consts))];
ok(`gravité des ${ALL_TYPES.length} types = pawAlertLevel613 de l'app`, () => {
  const sw = AL.match(/pawAlertLevel613\(String type\) => switch \(type\) \{([\s\S]*?)\};/)[1];
  const listFor = (lvl) => { const m = sw.match(new RegExp(`((?:'[a-z_]+'\\s*\\|\\|\\s*)*'[a-z_]+')\\s*=>\\s*PawAlertLevel\\.${lvl}`)); return m ? [...m[1].matchAll(/'([a-z_]+)'/g)].map((x) => x[1]) : []; };
  const danger = listFor("danger"), info = listFor("info");
  assert.ok(danger.length >= 6 && info.length >= 7, `tables lues : ${danger} / ${info}`);
  assert.ok(ALL_TYPES.length >= 27, `types lus : ${ALL_TYPES.length}`);
  for (const t of ALL_TYPES) {
    const want = danger.includes(t) ? "danger" : info.includes(t) ? "info" : "attention";
    assert.equal(alertLevel613(t), want, t);
  }
});
ok("couleurs : danger #DC2626, attention #EA580C, info #2563EB (lues dans le Dart)", () => {
  const hex = (lvl) => "#" + AL.match(new RegExp(`PawAlertLevel\\.${lvl} => const Color\\(0xFF([0-9A-F]{6})\\)`))[1];
  for (const lvl of ["danger", "attention", "info"]) assert.equal(ALERT_COLOR_613[lvl], hex(lvl));
  assert.deepEqual(ALERT_COLOR_613, { danger: "#DC2626", attention: "#EA580C", info: "#2563EB" });
});
ok("auréole < 2 h ; pâleur 1 (< 24 h) → 0,78 (< 36 h) → 0,58", () => {
  assert.match(AL, /kPawAlertFresh613 = Duration\(hours: 2\)/);
  assert.match(AL, /if \(h < 24\) return 1\.0;/); assert.match(AL, /if \(h < 36\) return 0\.78;/); assert.match(AL, /return 0\.58;/);
  const now = Date.parse("2026-10-07T12:00:00Z"), ago = (h) => new Date(now - h * 3600e3).toISOString();
  assert.equal(alertFresh613(ago(1.99), now), true); assert.equal(alertFresh613(ago(2), now), false);
  assert.deepEqual([0, 23.98, 24, 35.98, 36, 47].map((h) => alertAlpha613(ago(h), now)), [1, 1, 0.78, 0.78, 0.58, 0.58]);
});
ok("emoji de chaque type = ReportTypes.emoji de l'app (⚠️ compris), repli 📍", () => {
  const body = MODEL.match(/static String emoji\(String t\) \{([\s\S]*?)\n  \}/)[1];
  const appMap = {};
  for (const m of body.matchAll(/case (\w+):[\s\S]*?return '([^']+)';/g)) appMap[consts[m[1]]] = m[2];
  assert.ok(Object.keys(appMap).length >= 26, `${Object.keys(appMap).length} emoji lus`);
  assert.deepEqual(REPORT_EMOJI_613, appMap);
  assert.equal(reportEmoji613("inconnu"), "📍");
  assert.equal(reportEmoji613("hazard"), "⚠️");
});
ok("jamais de rond vide : emoji absent → icône SVG de la gravité ; règle d'encre = pawPinHasInk613", () => {
  const PIN = read("frontend/lib/views/map/widgets/pawmap_report_pin613.dart");
  assert.match(PIN, /int box = 26, int minPixels = 14/); assert.match(PIN, /mn < 205 \|\| mx - mn > 40/);
  const w = 56, blank = new Uint8ClampedArray(w * w * 4).fill(255);
  assert.equal(hasInk613(blank, w, w), false);
  const inked = blank.slice(); for (let y = 24; y < 32; y++) for (let x = 24; x < 32; x++) { const i = (y * w + x) * 4; inked[i] = 220; inked[i + 1] = 40; inked[i + 2] = 40; }
  assert.equal(hasInk613(inked, w, w), true);
  for (const t of ALL_TYPES) {
    const lvl = alertLevel613(t);
    const fb = alertPinHtml613(t, { emojiOk: false });
    assert.ok(fb.includes("data-alert-fallback") && fb.includes(`fill="${ALERT_COLOR_613[lvl]}"`) && /<path d="M/.test(fb) && !fb.includes(reportEmoji613(t)), t);
    const em = alertPinHtml613(t, { emojiOk: true, fresh: true });
    assert.ok(em.includes(reportEmoji613(t)) && em.includes("data-alert-fresh") && em.includes(`solid ${ALERT_COLOR_613[lvl]}`), t);
    assert.ok(!/#(?:9CA3AF|6B7280|D1D5DB|E5E7EB|808080|C0C0C0)/i.test(em + fb), `${t} : gris`);
  }
});

console.log(`\n${n}/${n} tests verts`);
