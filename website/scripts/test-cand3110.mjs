// 31/10/2026 (LEO) — page unique « mes candidats → payer » : textes 9 langues complets, variables
// intactes, tri « le plus proche puis le moins cher », choix de la demande, pays du paiement.
//   node scripts/test-cand3110.mjs
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import ts from "typescript";

const here = path.dirname(fileURLToPath(import.meta.url));
const load = async (rel, stubs = "") => {
  const src = fs.readFileSync(path.join(here, "..", rel), "utf8").replace(/^import .*$/gm, "");
  const js = ts.transpileModule(stubs + src, { compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2020 } }).outputText;
  return import("data:text/javascript;base64," + Buffer.from(js).toString("base64"));
};
const i18n = await load("src/lib/i18n/cand3110.ts");
const stubs = `const applicationId = (a) => String(a.id || a._id || ""); const applicationProvider = (a) => a.walker ? { role: "walker", who: a.walker } : { role: "sitter", who: a.sitter || null };\n`;
const lib = await load("src/lib/cand3110.ts", stubs);
const LANGS = ["fr", "en", "es", "de", "it", "pt", "ko", "ja", "pl"];
let n = 0;
const ok = (name, fn) => { fn(); n++; console.log("OK    " + name); };

ok("9 langues, mêmes clés que le français, aucun texte vide", () => {
  const keys = Object.keys(i18n.CAND3110.fr).sort();
  assert.ok(keys.length >= 35);
  for (const l of LANGS) {
    assert.deepEqual(Object.keys(i18n.CAND3110[l]).sort(), keys, l);
    for (const k of keys) assert.ok(i18n.CAND3110[l][k].trim().length > 0, `${l}.${k}`);
  }
});
ok("{name} {km} {n} jamais traduits, remplacés par c3110", () => {
  for (const l of LANGS) {
    const d = i18n.CAND3110[l];
    for (const k of ["choose_pay", "panel_title", "panel_sub", "g_escrow", "g_chat", "paid_sub", "paid_chat"]) assert.ok(d[k].includes("{name}"), `${l}.${k}`);
    assert.ok(d.km.includes("{km}"), `${l}.km`);
    assert.ok(d.count_many.includes("{n}"), `${l}.count_many`);
    assert.equal(i18n.c3110(l, "choose_pay", { name: "Inès" }).includes("{name}"), false);
    assert.ok(i18n.c3110(l, "choose_pay", { name: "Inès" }).includes("Inès"));
    assert.ok(i18n.c3110(l, "km", { km: 3 }).includes("3"));
  }
  assert.equal(i18n.c3110("xx", "pay"), i18n.CAND3110.fr.pay);
  assert.equal(i18n.c3110("fr", "cle_inconnue"), "cle_inconnue");
});

const P = { lat: -35, lng: -30 };
const mk = (id, dlat, dlng, total, extra = {}) => ({ id, status: "pending", sitter: { id: "s" + id, name: "N " + id, location: dlat == null ? null : { lat: P.lat + dlat, lng: P.lng + dlng } }, pricing: { totalPrice: total, appliedRate: 10, currency: "EUR" }, ...extra });

ok("tri : le plus proche d'abord, puis le moins cher, distance inconnue en dernier", () => {
  const items = [mk("a", 0.3, 0.3, 50), mk("b", 0.01, 0.01, 90), mk("c", 0.01, 0.01, 60), mk("d", null, null, 10)];
  assert.deepEqual(lib.sortCandidates3110(items, P).map((x) => x.id), ["c", "b", "a", "d"]);
  // ~1 km d'arrondi : deux candidats à 0,4 et 0,9 km sont à égalité de distance (1 km) → le moins cher
  const close = [mk("x", 0.008, 0, 40), mk("y", 0.003, 0, 30)];
  assert.deepEqual(lib.sortCandidates3110(close, P).map((x) => x.id), ["y", "x"]);
});
ok("tri : le candidat du lien (focus) passe devant, total incohérent compte comme inconnu", () => {
  const items = [mk("a", 0.01, 0.01, 50), mk("b", 0.5, 0.5, 20), mk("c", 0.01, 0.01, 5)];
  assert.deepEqual(lib.sortCandidates3110(items, P, "b").map((x) => x.id), ["b", "a", "c"]);
  assert.equal(lib.totalOf3110(mk("c", 0, 0, 5)), null); // 5 < tarif 10
  assert.equal(lib.totalOf3110(mk("s", 0, 0, 50, { pricing: { totalPrice: 50, stale: true } })), null);
  assert.equal(lib.totalOf3110(mk("i", 0, 0, 50, { pricing: { totalPrice: 50, indicative: true } })), null);
  assert.equal(lib.totalOf3110(mk("o", 0, 0, 64.8)), 64.8);
});
ok("tri stable sans point de demande (ordre serveur), km null", () => {
  const items = [mk("a", 0.3, 0.3, 50), mk("b", 0.01, 0.01, 50)];
  assert.deepEqual(lib.sortCandidates3110(items, null).map((x) => x.id), ["a", "b"]);
  assert.equal(lib.kmOf3110(items[0], null), null);
  assert.equal(lib.kmOf3110(items[1], P), 1);
  assert.equal(lib.kmOf3110(mk("z", 0.09, 0, 1), P), 10);
});
ok("demande à afficher : celle du focus, sinon la plus de candidats en attente", () => {
  const apps = [{ id: "1", postId: "P1", status: "pending" }, { id: "2", postId: "P2", status: "pending" }, { id: "3", postId: "P2", status: "pending" }, { id: "4", postId: "P3", status: "accepted" }];
  assert.equal(lib.pickPostId3110(apps, "1"), "P1");
  assert.equal(lib.pickPostId3110(apps, "zz"), "P2");
  assert.equal(lib.pickPostId3110(apps), "P2");
  assert.equal(lib.pickPostId3110([]), "");
});
ok("pays Airwallex depuis la devise", () => {
  assert.equal(lib.countryForCurrency3110("EUR"), "FR");
  assert.equal(lib.countryForCurrency3110("usd"), "US");
  assert.equal(lib.countryForCurrency3110("GBP"), "GB");
  assert.equal(lib.countryForCurrency3110(""), "FR");
});
console.log(`\n${n}/${n} OK`);
