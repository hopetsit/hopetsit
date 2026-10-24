// 24/10/2026 (620, LEO) — tests du module pur lib/services620.ts (catalogue,
// modes de dates, quantités, estimation locale, tarifs).
//   node scripts/test-services620.mjs
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import ts from "typescript";

const here = path.dirname(fileURLToPath(import.meta.url));
const src = fs.readFileSync(path.join(here, "..", "src", "lib", "services620.ts"), "utf8");
const js = ts.transpileModule(src, { compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2020 } }).outputText;
const mod = await import("data:text/javascript;base64," + Buffer.from(js).toString("base64"));
const { parseCatalog620, quantityFor620, daysBetween620, dateModeOf620, datesValid620, estimateLocal620, parseEstimate620, readProviderRates620, rateForService620, offeredServices620, LEGACY_SERVICES_620 } = mod;

let n = 0;
const ok = (name, fn) => { fn(); n++; console.log("OK    " + name); };

ok("catalogue : ancien serveur (3 services, pas de home_visit) → null", () => {
  assert.equal(parseCatalog620({ services: [{ key: "house_sitting", unit: "day" }, { key: "day_care" }, { key: "dog_walking", unit: "walk" }] }), null);
  assert.equal(parseCatalog620({ error: "not found" }), null);
  assert.equal(parseCatalog620(null), null);
  assert.equal(LEGACY_SERVICES_620.length, 3);
});
ok("catalogue : contrat 620 (tableau) → 4 services dans l'ordre, unités, visites 1|2, durées 30|60", () => {
  const c = parseCatalog620({ services: [
    { key: "dog_walking", unit: "walk" }, { key: "home_visit", unit: "visit", durations: [30, 60], visitsPerDay: [1, 2], labels: { fr: "Visite à domicile" } },
    { key: "day_care", unit: "day" }, { key: "house_sitting", unit: "day" } ] });
  assert.deepEqual(c.map((s) => s.key), ["house_sitting", "home_visit", "day_care", "dog_walking"]);
  assert.equal(c[1].unit, "visit"); assert.deepEqual(c[1].visitsPerDay, [1, 2]); assert.deepEqual(c[1].durations, [30, 60]);
  assert.equal(c[1].labels.fr, "Visite à domicile"); assert.equal(c[3].unit, "walk");
});
ok("catalogue : forme objet { services: { home_visit: {…} } } + service désactivé ignoré", () => {
  const c = parseCatalog620({ services: { house_sitting: { unit: "day" }, home_visit: { unit: "visit" }, day_care: { active: false }, dog_walking: {} } });
  assert.deepEqual(c.map((s) => s.key), ["house_sitting", "home_visit", "dog_walking"]);
  assert.deepEqual(c[1].visitsPerDay, [1, 2]); // repli du contrat
});
ok("catalogue : forme RÉELLE de ZOE (serviceCatalogService.getServices620 : key, unit, active, label{9}, unitLabel, durations, visitsPerDay, walkDurations)", () => {
  const raw = { services: [
    { key: "house_sitting", unit: "day", active: true, icon: "", label: { fr: "Garde à domicile", en: "House sitting" }, desc: {}, unitLabel: { fr: "jour" }, venues: ["owners_home", "sitters_home"] },
    { key: "home_visit", unit: "visit", active: true, icon: "", label: { fr: "Visite à domicile", en: "Home visit", ja: "訪問ケア" }, desc: {}, unitLabel: { fr: "visite" }, durations: [30, 60], visitsPerDay: [1, 2] },
    { key: "day_care", unit: "day", active: true, label: { fr: "Garderie de jour" }, desc: {}, unitLabel: {} },
    { key: "dog_walking", unit: "walk", active: true, label: { fr: "Promenade de chien" }, desc: {}, unitLabel: {}, walkDurations: [30, 60, 90, 120] },
  ], all: [], dateModes: ["exact", "approx", "tbd"], languages: ["fr", "en"], promenadeMinutes: [30, 60, 90, 120], longOutingMinutes: [180] };
  const c = parseCatalog620(raw);
  assert.deepEqual(c.map((s) => s.key), ["house_sitting", "home_visit", "day_care", "dog_walking"]);
  assert.equal(c[1].labels.ja, "訪問ケア"); assert.deepEqual(c[1].visitsPerDay, [1, 2]); assert.deepEqual(c[1].durations, [30, 60]);
  assert.equal(c[3].labels.fr, "Promenade de chien");
});
ok("jours : fin − début + 1 ; inversé = 0 ; vide = 0", () => {
  assert.equal(daysBetween620("2026-11-02", "2026-11-06"), 5);
  assert.equal(daysBetween620("2026-11-02", "2026-11-02"), 1);
  assert.equal(daysBetween620("2026-11-06", "2026-11-02"), 0);
  assert.equal(daysBetween620("", "2026-11-02"), 0);
  assert.equal(daysBetween620("2026-11-02T10:00:00.000Z", "2026-11-06T18:00:00.000Z"), 5);
});
ok("mode de dates d'une demande : dateMode prime, sinon exact si début+fin, sinon tbd", () => {
  assert.equal(dateModeOf620({ dateMode: "approx", startDate: "a", endDate: "b" }), "approx");
  assert.equal(dateModeOf620({ startDate: "2026-11-02", endDate: "2026-11-06" }), "exact");
  assert.equal(dateModeOf620({ startDate: "2026-11-02" }), "tbd");
  assert.equal(dateModeOf620({}), "tbd");
  assert.equal(dateModeOf620(null), "tbd");
});
ok("validité : exact/approx exigent début ≤ fin ; tbd toujours valable", () => {
  assert.equal(datesValid620("exact", "2026-11-02", "2026-11-06"), true);
  assert.equal(datesValid620("approx", "2026-11-06", "2026-11-02"), false);
  assert.equal(datesValid620("exact", "", ""), false);
  assert.equal(datesValid620("tbd", "", ""), true);
});
ok("quantité : jours, nuits chez le gardien, visites × /jour, balade = 1, tbd = null", () => {
  const S = "2026-11-02", E = "2026-11-06";
  assert.deepEqual(quantityFor620({ service: "house_sitting", dateMode: "exact", startDate: S, endDate: E }), { quantity: 5, unit: "day" });
  assert.deepEqual(quantityFor620({ service: "house_sitting", dateMode: "approx", startDate: S, endDate: E, venue: "sitters_home" }), { quantity: 4, unit: "night" });
  assert.deepEqual(quantityFor620({ service: "house_sitting", dateMode: "exact", startDate: S, endDate: S, venue: "sitters_home" }), { quantity: 1, unit: "night" });
  assert.deepEqual(quantityFor620({ service: "home_visit", dateMode: "exact", startDate: S, endDate: E, visitsPerDay: 2 }), { quantity: 10, unit: "visit" });
  assert.deepEqual(quantityFor620({ service: "home_visit", dateMode: "exact", startDate: S, endDate: E }), { quantity: 5, unit: "visit" });
  assert.deepEqual(quantityFor620({ service: "day_care", dateMode: "exact", startDate: S, endDate: E }), { quantity: 5, unit: "day" });
  assert.deepEqual(quantityFor620({ service: "dog_walking", dateMode: "exact", startDate: S, endDate: E }), { quantity: 1, unit: "walk" });
  assert.deepEqual(quantityFor620({ service: "home_visit", dateMode: "tbd" }), { quantity: null, unit: "visit" });
  assert.deepEqual(quantityFor620({ service: "home_visit", dateMode: "exact", startDate: E, endDate: S }), { quantity: null, unit: "visit" });
});
ok("estimation locale : 5 visites × 18 € = 90 €, commission 20 % → 108 € ; tbd = indicatif", () => {
  const e = estimateLocal620({ quantity: 5, unit: "visit" }, 18, "EUR");
  assert.equal(e.unitTotal, 90); assert.equal(e.commission, 18); assert.equal(e.ownerTotal, 108); assert.equal(e.indicative, false);
  const t = estimateLocal620({ quantity: null, unit: "visit" }, 18, "EUR");
  assert.equal(t.ownerTotal, null); assert.equal(t.indicative, true); assert.equal(t.rate, 18);
  const z = estimateLocal620({ quantity: 5, unit: "visit" }, null, "EUR");
  assert.equal(z.ownerTotal, null); assert.equal(z.rate, null);
});
ok("réponse serveur : { estimate: {…} } ou à plat, tolérante", () => {
  const a = parseEstimate620({ estimate: { quantity: 5, unitTotal: 90, commission: 18, ownerTotal: 108, indicative: false, unit: "visit", rate: 18, currency: "eur" } }, { quantity: 5, unit: "visit" }, "EUR");
  assert.equal(a.ownerTotal, 108); assert.equal(a.currency, "EUR"); assert.equal(a.fromServer, true);
  const b = parseEstimate620({ quantity: null, ownerTotal: null, indicative: true, rate: 12 }, { quantity: null, unit: "visit" }, "EUR");
  assert.equal(b.indicative, true); assert.equal(b.rate, 12);
  assert.equal(parseEstimate620({ error: "x" }, { quantity: null, unit: "visit" }, "EUR"), null);
  // réponse réelle de ZOE (pricingController) : à plat, unitRate ; NO_RATE → unitRate 0 → tarif null
  const z = parseEstimate620({ serviceType: "home_visit", dateMode: "exact", indicative: false, quantity: 10, unit: "visit", unitRate: 12, unitTotal: 120, commission: 24, ownerTotal: 144, commissionRate: 0.2, currency: "EUR", durationMinutes: 60, rateSource: "provider" }, { quantity: 10, unit: "visit" }, "EUR");
  assert.equal(z.rate, 12); assert.equal(z.ownerTotal, 144); assert.equal(z.quantity, 10);
  const nr = parseEstimate620({ serviceType: "home_visit", dateMode: "tbd", indicative: true, quantity: null, unit: "visit", unitRate: 0, unitTotal: null, commission: null, ownerTotal: null, code: "NO_RATE" }, { quantity: null, unit: "visit" }, "EUR");
  assert.equal(nr.rate, null); assert.equal(nr.indicative, true);
});
ok("tarifs d'un profil : visitRate, durée 30|60, balades, devise", () => {
  const r = readProviderRates620({ currency: "eur", dailyRate: 22, hourlyRate: "0", visitRate: 12, visitDurationMinutes: 60, walkRates: [{ durationMinutes: 30, basePrice: 10, enabled: true }, { durationMinutes: 60, basePrice: 15 }, { durationMinutes: 120, basePrice: 0 }] });
  assert.equal(r.currency, "EUR"); assert.equal(r.dailyRate, 22); assert.equal(r.hourlyRate, null); assert.equal(r.visitRate, 12); assert.equal(r.visitDurationMinutes, 60);
  assert.deepEqual(r.walkRates, [{ durationMinutes: 30, basePrice: 10 }, { durationMinutes: 60, basePrice: 15 }]);
  assert.deepEqual(rateForService620(r, "home_visit"), { rate: 12, unit: "visit" });
  assert.deepEqual(rateForService620(r, "house_sitting"), { rate: 22, unit: "day" });
  assert.deepEqual(rateForService620(r, "day_care"), { rate: 22, unit: "day" });
  assert.deepEqual(rateForService620(r, "dog_walking"), { rate: 10, unit: "walk" });
  assert.deepEqual(rateForService620(r, "dog_walking", 60), { rate: 15, unit: "walk" });
  assert.deepEqual(offeredServices620("sitter", r), ["house_sitting", "home_visit", "day_care"]);
  assert.deepEqual(offeredServices620("walker", r), ["dog_walking"]);
  const noVisit = readProviderRates620({ dailyRate: 22 });
  assert.equal(rateForService620(noVisit, "home_visit"), null);
  assert.deepEqual(offeredServices620("sitter", noVisit), ["house_sitting", "day_care"]);
  const hourOnly = readProviderRates620({ hourlyRate: 3 });
  assert.deepEqual(rateForService620(hourOnly, "house_sitting"), { rate: 24, unit: "day" });
});

console.log(`\n${n}/${n} tests verts (services620)`);
