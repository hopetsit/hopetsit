// Test de lib/priceUnit.ts + priceAlt dans lib/memberPersons.ts (605, site) :
//   node scripts/test-priceUnit605.mjs
// Même méthode que test-memberPersons.mjs : copie dans un dossier temporaire,
// alias « @/lib » remplacés ; formatPrice est extrait tel quel de pawmapLegend.ts.
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import assert from "node:assert/strict";

const here = dirname(fileURLToPath(import.meta.url));
const lib = join(here, "..", "src", "lib");
const dir = mkdtempSync(join(tmpdir(), "pu605-"));
const legend = readFileSync(join(lib, "pawmapLegend.ts"), "utf8");
const fp = legend.match(/export function formatPrice\([\s\S]*?\n\}\n/);
if (!fp) throw new Error("formatPrice introuvable dans pawmapLegend.ts");
writeFileSync(join(dir, "legendPrice.ts"), fp[0]);
// 620 — priceUnit.ts lit aussi les unités de lib/i18n/dates620.ts (copié tel quel).
writeFileSync(join(dir, "dates620.ts"), readFileSync(join(lib, "i18n", "dates620.ts"), "utf8").replace(/import type \{ Lang \} from "\.\/langs";\n/, "type Lang = string;\n"));
writeFileSync(
  join(dir, "priceUnit.ts"),
  readFileSync(join(lib, "priceUnit.ts"), "utf8")
    .replace(/from "@\/lib\/pawmapLegend"/, 'from "./legendPrice.ts"')
    .replace(/from "@\/lib\/i18n\/dates620"/, 'from "./dates620.ts"')
    .replace(/import type \{ Lang \} from "@\/lib\/i18n\/langs";\n/, "type Lang = string;\n"),
);
writeFileSync(join(dir, "mapCluster.ts"), readFileSync(join(lib, "mapCluster.ts"), "utf8"));
writeFileSync(
  join(dir, "memberPersons.ts"),
  readFileSync(join(lib, "memberPersons.ts"), "utf8")
    .replace(/import type \{[^}]*\} from "@\/lib\/api";\n/, "")
    .replace(/from "@\/lib\/mapCluster"/, 'from "./mapCluster.ts"')
    .replace(/: NearbyMember\b/g, ": any")
    .replace(/NearbyMember\[\]/g, "any[]")
    .replace(/NonNullable<NearbyMember\["roles"\]>\[number\]/g, "any")
    .replace(/NearbyMember\["roles"\]/g, "any")
    .replace(/ as NearbyMember/g, ""),
);
const P = await import(join(dir, "priceUnit.ts"));
const M = await import(join(dir, "memberPersons.ts"));
let n = 0;
const ok = (name, fn) => { fn(); n += 1; console.log("ok -", name); };
const FR = { week: "sem", month: "mois" };

ok("prix jour/heure : inchangé (formatPrice)", () => {
  assert.equal(P.formatPriceUnit(22, "EUR", { amount: 100, unit: "week" }, FR), "22 €");
  assert.equal(P.formatPriceUnit(15, "USD", null, FR), "$15");
});
ok("GIRMA : 0 jour/heure, 100 €/sem", () => {
  assert.equal(P.formatPriceUnit(0, "EUR", { amount: 100, unit: "week" }, FR), "100 €/sem");
  assert.equal(P.formatPriceUnit(undefined, null, { amount: 350, unit: "month" }, FR), "350 €/mois");
  assert.equal(P.formatPriceUnit(0, "USD", { amount: 120, unit: "week" }, { week: "wk", month: "mo" }), "$120/wk");
});
ok("rien du tout ou priceAlt mal formé : null", () => {
  assert.equal(P.formatPriceUnit(0, "EUR", null, FR), null);
  assert.equal(P.formatPriceUnit(0, "EUR", { amount: 0, unit: "week" }, FR), null);
  assert.equal(P.formatPriceUnit(0, "EUR", { amount: 50, unit: "year" }, FR), null);
});
ok("repli carte publique : semaine > mois, seulement sans jour ni heure", () => {
  assert.deepEqual(P.priceAltFromRates({ hourlyRate: 0, dailyRate: 0, weeklyRate: 100, monthlyRate: 350 }), { amount: 100, unit: "week" });
  assert.deepEqual(P.priceAltFromRates({ weeklyRate: 0, monthlyRate: 350 }), { amount: 350, unit: "month" });
  assert.equal(P.priceAltFromRates({ dailyRate: 30, weeklyRate: 100 }), null);
  assert.equal(P.priceAltFromRates({ hourlyRate: 12, monthlyRate: 350 }), null);
  assert.equal(P.priceAltFromRates({}), null);
});
ok("rolesOf garde priceAlt (point et roles[])", () => {
  const g = { id: "s-g", role: "sitter", priceFrom: 0, priceAlt: { amount: 100, unit: "week" }, location: { coordinates: [2.24, 48.835] },
    roles: [{ id: "s-g", role: "sitter", priceFrom: 0, priceAlt: { amount: 100, unit: "week" } }, { id: "o-g", role: "owner" }] };
  const r = M.rolesOf(g);
  assert.deepEqual(r[0].priceAlt, { amount: 100, unit: "week" });
  const g2 = { ...g, roles: [{ id: "s-g", role: "sitter" }] };
  assert.deepEqual(M.rolesOf(g2)[0].priceAlt, { amount: 100, unit: "week" });
});
ok("mergePersons (proches + monde) garde priceAlt", () => {
  const near = { id: "s-g", role: "sitter", location: { coordinates: [2.24, 48.835] }, roles: [{ id: "s-g", role: "sitter" }] };
  const world = { id: "s-g", role: "sitter", priceFrom: 0, priceAlt: { amount: 100, unit: "week" }, location: { coordinates: [2.241, 48.836] },
    roles: [{ id: "s-g", role: "sitter", priceFrom: 0, priceAlt: { amount: 100, unit: "week" } }] };
  const out = M.mergePersons([near], [world]);
  assert.equal(out.length, 1);
  assert.deepEqual(out[0].priceAlt, { amount: 100, unit: "week" });
  assert.deepEqual(M.rolesOf(out[0])[0].priceAlt, { amount: 100, unit: "week" });
});
ok("620 : priceUnit du serveur → « 12 €/visite », « 22 €/jour », « $10/walk » ; inconnu → inchangé", () => {
  const FR620 = { week: "sem", month: "mois", day: "jour", visit: "visite", walk: "balade", night: "nuit", hour: "h" };
  assert.equal(P.formatPriceUnit(12, "EUR", null, FR620, "visit"), "12 €/visite");
  assert.equal(P.formatPriceUnit(22, "EUR", null, FR620, "day"), "22 €/jour");
  assert.equal(P.formatPriceUnit(10, "USD", null, { week: "wk", month: "mo", walk: "walk" }, "walk"), "$10/walk");
  assert.equal(P.formatPriceUnit(22, "EUR", null, FR620, "year"), "22 €");
  assert.equal(P.formatPriceUnit(22, "EUR", null, FR620, undefined), "22 €");
  assert.equal(P.formatPriceUnit(22, "EUR", null, FR, "visit"), "22 €"); // libellés 605 seuls : pas d'unité inventée
  assert.equal(P.formatPriceUnit(0, "EUR", { amount: 100, unit: "week" }, FR620, "visit"), "100 €/sem");
  const labels = P.priceUnitLabels((k) => ({ pu605_week: "sem", pu605_month: "mois" })[k], "fr");
  assert.equal(labels.visit, "visite"); assert.equal(labels.day, "jour");
  assert.equal(P.priceUnitLabels((k) => k, "en").visit, "visit");
});
ok("620 : rolesOf / mergePersons gardent priceUnit", () => {
  const g = { id: "s-v", role: "sitter", priceFrom: 12, priceUnit: "visit", location: { coordinates: [2.24, 48.835] }, roles: [{ id: "s-v", role: "sitter", priceFrom: 12, priceUnit: "visit" }] };
  assert.equal(M.rolesOf(g)[0].priceUnit, "visit");
  const near = { id: "s-v", role: "sitter", location: { coordinates: [2.24, 48.835] }, roles: [{ id: "s-v", role: "sitter" }] };
  const out = M.mergePersons([near], [g]);
  assert.equal(out[0].priceUnit, "visit"); assert.equal(M.rolesOf(out[0])[0].priceUnit, "visit");
});
console.log(`\n${n} tests OK`);
