// 17/11 (LEO) — textes de l'accueil du 17/11 : les 9 langues ont exactement les mêmes clés, aucune vide,
// aucune promesse interdite (revenus, « tous vérifiés », chiffres inventés). Lancer : node scripts/test-accueil1711.mjs
import { readFileSync } from "node:fs";
const src = readFileSync(new URL("../src/lib/i18n/accueil1711.ts", import.meta.url), "utf8");
const langs = ["fr", "en", "es", "de", "it", "pt", "pl", "ko", "ja"];
const blocks = {};
for (const l of langs) {
  const m = src.match(new RegExp(`\\n  ${l}: \\{\\n([\\s\\S]*?)\\n  \\},`));
  if (!m) { console.error("bloc manquant:", l); process.exit(1); }
  blocks[l] = Object.fromEntries([...m[1].matchAll(/^\s{4}([a-z0-9_]+): "((?:[^"\\]|\\.)*)",?$/gm)].map((x) => [x[1], x[2]]));
}
const ref = Object.keys(blocks.fr).sort();
let bad = 0;
for (const l of langs) {
  const keys = Object.keys(blocks[l]).sort();
  const miss = ref.filter((k) => !keys.includes(k)), extra = keys.filter((k) => !ref.includes(k));
  const empty = keys.filter((k) => !blocks[l][k].trim());
  if (miss.length || extra.length || empty.length) { bad++; console.error(l, { miss, extra, empty }); }
  const all = Object.values(blocks[l]).join(" ");
  if (/\d{3,}|€|\$|%/.test(all.replace(/72/g, ""))) { bad++; console.error(l, "chiffre ou montant inattendu"); }
}
if (/tous vérifiés|all verified|gagne|earn|revenu|income/i.test(JSON.stringify(blocks))) { bad++; console.error("promesse interdite"); }
console.log(bad ? `ECHEC (${bad})` : `OK — ${langs.length} langues × ${ref.length} clés`);
process.exit(bad ? 1 : 0);
