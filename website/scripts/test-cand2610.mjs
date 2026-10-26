// 26/10/2026 (LEO) — page des candidats : textes 9 langues complets, variables intactes.
//   node scripts/test-cand2610.mjs
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import ts from "typescript";

const here = path.dirname(fileURLToPath(import.meta.url));
const src = fs.readFileSync(path.join(here, "..", "src", "lib", "i18n", "cand2610.ts"), "utf8").replace(/^import type .*$/m, "");
const js = ts.transpileModule(src, { compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2020 } }).outputText;
const m = await import("data:text/javascript;base64," + Buffer.from(js).toString("base64"));
const LANGS = ["fr", "en", "es", "de", "it", "pt", "ko", "ja", "pl"];
let n = 0;
const ok = (name, fn) => { fn(); n++; console.log("OK    " + name); };

ok("9 langues, mêmes clés que le français, aucun texte vide", () => {
  const keys = Object.keys(m.CAND2610.fr).sort();
  for (const l of LANGS) {
    assert.deepEqual(Object.keys(m.CAND2610[l]).sort(), keys, l);
    for (const k of keys) assert.ok(m.CAND2610[l][k].trim().length > 0, `${l}.${k}`);
  }
});
ok("{name} et {n} jamais traduits, remplacés", () => {
  for (const l of LANGS) {
    assert.ok(m.CAND2610[l].write.includes("{name}"), l);
    assert.ok(m.CAND2610[l].count_many.includes("{n}"), l);
    assert.ok(!m.c2610(l, "write", { name: "Hanene" }).includes("{"), l);
  }
  assert.equal(m.c2610("fr", "write", { name: "Hanene" }), "Écrire à Hanene");
});
ok("clé inconnue → la clé, langue inconnue → français", () => {
  assert.equal(m.c2610("fr", "zzz"), "zzz");
  assert.equal(m.c2610("xx", "title"), "Tes candidats");
});
console.log(`\n${n}/${n} tests OK`);
