// Test du budget (587, option A de Daniel) côté site, sans dépendance :
//   node scripts/test-budget587.mjs
// Vérifie le format de la bulle / de la carte d'annonce (formatPrice) :
// « 35 € », « $35 », rien sans budget (jamais « 0 € »).
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import assert from "node:assert/strict";

const here = dirname(fileURLToPath(import.meta.url));
const src = readFileSync(join(here, "..", "src", "lib", "pawmapLegend.ts"), "utf8");
const start = src.indexOf("export function formatPrice");
const end = src.indexOf("\n}\n", start) + 3;
const dir = mkdtempSync(join(tmpdir(), "b587-"));
writeFileSync(join(dir, "fp.ts"), src.slice(start, end));
const { formatPrice } = await import(join(dir, "fp.ts"));

assert.equal(formatPrice(35, "EUR"), "35 €");
assert.equal(formatPrice(35, "USD"), "$35");
assert.equal(formatPrice(12.5, "GBP"), "£13");
assert.equal(formatPrice(0, "EUR"), null);
assert.equal(formatPrice(null, "EUR"), null);
assert.equal(formatPrice(undefined, undefined), null);
// devise du budget prioritaire sur celle du compte (map/page.tsx, posts/page.tsx)
const p = { budget: 40, budgetCurrency: "USD", currency: "EUR" };
assert.equal(formatPrice(p.budget, p.budgetCurrency || p.currency), "$40");
const q = { budget: 0, budgetCurrency: "", currency: "EUR" };
assert.equal(formatPrice(q.budget, q.budgetCurrency || q.currency), null);
console.log("budget587 : 8 tests OK");
