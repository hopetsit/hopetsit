// Test du prix estimé de la réservation (lib/bookingEstimate.ts) CONTRE le
// calcul réel du serveur (backend/src/utils/tierPricing.js) :
//   node scripts/test-bookingEstimate.mjs
// Même principe que test-memberPersons.mjs : Node ≥ 23 retire les types.
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
import assert from "node:assert/strict";

const here = dirname(fileURLToPath(import.meta.url));
const dir = mkdtempSync(join(tmpdir(), "be585-"));
writeFileSync(join(dir, "bookingEstimate.ts"), readFileSync(join(here, "..", "src", "lib", "bookingEstimate.ts"), "utf8"));
const E = await import(join(dir, "bookingEstimate.ts"));
const require = createRequire(import.meta.url);
const { calculateTierBasePrice } = require(join(here, "..", "..", "backend", "src", "utils", "tierPricing.js"));

let n = 0;
const ok = (name, fn) => { fn(); n += 1; console.log("ok -", name); };
const sitter = { hourlyRate: 6, dailyRate: 25, weeklyRate: 150, monthlyRate: 500 };
const serverSitter = (win, durationMinutes = null) =>
  calculateTierBasePrice({ ...sitter, startDate: win.start, endDate: win.end, durationMinutes }).basePrice;

const cases = [
  { name: "garde à domicile 3 nuits", i: { role: "sitter", service: "house_sitting", startDate: "2026-10-10", startTime: "10:00", endDate: "2026-10-13", pets: 1 } },
  { name: "long séjour 9 nuits (tarif semaine)", i: { role: "sitter", service: "long_stay", startDate: "2026-10-10", startTime: "10:00", endDate: "2026-10-19", pets: 1 } },
  { name: "long séjour 35 nuits (tarif mois)", i: { role: "sitter", service: "long_stay", startDate: "2026-10-10", startTime: "10:00", endDate: "2026-11-14", pets: 2 } },
  { name: "garderie (8 h)", i: { role: "sitter", service: "day_care", startDate: "2026-10-10", startTime: "09:00", pets: 1 } },
  { name: "visite 30 min", i: { role: "sitter", service: "home_visit", startDate: "2026-10-10", startTime: "09:00", durationMinutes: 30, pets: 1 } },
];
for (const c of cases) {
  ok(`gardien : ${c.name} = serveur`, () => {
    const win = E.bookingWindow(c.i);
    assert.ok(win);
    const server = serverSitter(win, c.i.service === "home_visit" ? c.i.durationMinutes : null);
    assert.equal(E.estimateBooking(sitter, c.i), server);
  });
}

const walker = { walkRates: [{ durationMinutes: 30, basePrice: 9, enabled: true }, { durationMinutes: 60, basePrice: 15, enabled: true }, { durationMinutes: 120, basePrice: 26, enabled: true }] };
for (const m of [30, 60, 120]) {
  ok(`promeneur ${m} min = tarif exact du palier`, () => {
    const i = { role: "walker", service: "dog_walking", startDate: "2026-10-10", startTime: "10:00", durationMinutes: m, pets: 1 };
    const win = E.bookingWindow(i);
    const hourly = (walker.walkRates.find((r) => r.durationMinutes === m).basePrice * 60) / m;
    const server = calculateTierBasePrice({ hourlyRate: hourly, dailyRate: 0, weeklyRate: 0, monthlyRate: 0, startDate: win.start, endDate: win.end, durationMinutes: m }).basePrice;
    assert.equal(E.estimateBooking(walker, i), server);
    assert.equal(E.estimateBooking(walker, i), walker.walkRates.find((r) => r.durationMinutes === m).basePrice);
  });
}
ok("fin avant début = pas d'estimation", () => {
  assert.equal(E.estimateBooking(sitter, { role: "sitter", service: "house_sitting", startDate: "2026-10-10", startTime: "10:00", endDate: "2026-10-09", pets: 1 }), null);
});
ok("sans aucun tarif = pas d'estimation", () => {
  assert.equal(E.estimateBooking({}, { role: "sitter", service: "day_care", startDate: "2026-10-10", startTime: "10:00", pets: 1 }), null);
});
console.log(`\n${n} tests OK`);
