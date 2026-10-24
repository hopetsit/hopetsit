// 24/10/2026 (LEO) — tests du module pur lib/publicEstimate2410.ts (corps de la route publique
// POST /pricing/estimate/public, pays des pages villes, code postal des arrondissements, lien).
//   node scripts/test-publicEstimate2410.mjs
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import ts from "typescript";

const here = path.dirname(fileURLToPath(import.meta.url));
function load(rel) {
  const src = fs.readFileSync(path.join(here, "..", "src", "lib", rel), "utf8");
  return ts.transpileModule(src, { compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2020 } }).outputText;
}
// services620 est importé par publicEstimate2410 : on le sert en data: URL et on réécrit l'import.
const svcUrl = "data:text/javascript;base64," + Buffer.from(load("services620.ts")).toString("base64");
const js = load("publicEstimate2410.ts").replace(/from "\.\/services620"/g, `from "${svcUrl}"`);
const mod = await import("data:text/javascript;base64," + Buffer.from(js).toString("base64"));
const { publicEstimateBody2410, publicEstimateKey2410, countryOfRecruitCity2410, cityQueryName2410, parisPostal2410, createPostHref2410, PUBLIC_ESTIMATE_DEBOUNCE_MS } = mod;

let n = 0;
const ok = (name, fn) => { fn(); n++; console.log("OK    " + name); };

ok("debounce = 600 ms (règle de BOB)", () => assert.equal(PUBLIC_ESTIMATE_DEBOUNCE_MS, 600));

ok("corps : ville + code postal + pays + langue + dates (garde 5 jours), aucune autre clé", () => {
  const b = publicEstimateBody2410({ serviceType: "house_sitting", city: " Paris ", postalCode: "75011", country: "fr", lang: "FR", dateMode: "exact", startDate: "2026-11-02", endDate: "2026-11-06" });
  assert.deepEqual(b, { serviceType: "house_sitting", city: "Paris", postalCode: "75011", country: "FR", lang: "fr", startDate: "2026-11-02", endDate: "2026-11-06" });
});
ok("corps : visite à domicile → visitsPerDay 1|2 ; promenade → walkDurationMinutes si connu", () => {
  const v = publicEstimateBody2410({ serviceType: "home_visit", city: "Paris", dateMode: "exact", startDate: "2026-11-02", endDate: "2026-11-06", visitsPerDay: 2 });
  assert.equal(v.visitsPerDay, 2);
  const v1 = publicEstimateBody2410({ serviceType: "home_visit", city: "Paris", dateMode: "tbd", visitsPerDay: 7 });
  assert.equal(v1.visitsPerDay, 1); assert.equal(v1.startDate, undefined);
  const w = publicEstimateBody2410({ serviceType: "dog_walking", city: "Paris", dateMode: "tbd", walkDurationMinutes: 60 });
  assert.equal(w.walkDurationMinutes, 60); assert.equal("visitsPerDay" in w, false);
});
ok("corps : « à prévoir » n'envoie aucune date même si saisies ; sans mode, 2 dates = exact", () => {
  const b = publicEstimateBody2410({ serviceType: "house_sitting", city: "Paris", dateMode: "tbd", startDate: "2026-11-02", endDate: "2026-11-06" });
  assert.equal(b.startDate, undefined);
  const c = publicEstimateBody2410({ serviceType: "house_sitting", city: "Paris", startDate: "2026-11-02", endDate: "2026-11-06" });
  assert.equal(c.endDate, "2026-11-06");
});
ok("rien à demander : sans ville ni code postal → null ; code postal < 3 caractères = absent ; sans service → null", () => {
  assert.equal(publicEstimateBody2410({ serviceType: "house_sitting", city: "", postalCode: "75" }), null);
  assert.equal(publicEstimateBody2410({ serviceType: "", city: "Paris" }), null);
  assert.deepEqual(publicEstimateBody2410({ serviceType: "house_sitting", postalCode: "75011" }), { serviceType: "house_sitting", postalCode: "75011" });
});
ok("UN appel par changement utile : une seule date posée → null (on attend l'autre) ; fin avant début → null", () => {
  assert.equal(publicEstimateBody2410({ serviceType: "house_sitting", city: "Paris", dateMode: "exact", startDate: "2026-11-02", endDate: "" }), null);
  assert.equal(publicEstimateBody2410({ serviceType: "house_sitting", city: "Paris", dateMode: "exact", startDate: "", endDate: "2026-11-06" }), null);
  assert.equal(publicEstimateBody2410({ serviceType: "house_sitting", city: "Paris", dateMode: "exact", startDate: "2026-11-06", endDate: "2026-11-02" }), null);
  // aucune date en mode exact : tarif unitaire seul (comme « à prévoir »)
  assert.deepEqual(publicEstimateBody2410({ serviceType: "house_sitting", city: "Paris", dateMode: "exact", startDate: "", endDate: "" }), { serviceType: "house_sitting", city: "Paris" });
});
ok("corps : pays invalide ignoré, langue invalide ignorée, aucune donnée personnelle possible (clés fixes)", () => {
  const b = publicEstimateBody2410({ serviceType: "house_sitting", city: "Paris", country: "France", lang: "français" });
  assert.deepEqual(Object.keys(b).sort(), ["city", "serviceType"]);
});
ok("clé de dédoublonnage : même corps = même clé, corps différent = clé différente, null = ''", () => {
  const a = publicEstimateBody2410({ serviceType: "house_sitting", city: "Paris", postalCode: "75011", startDate: "2026-11-02", endDate: "2026-11-06" });
  const b = publicEstimateBody2410({ serviceType: "house_sitting", city: "Paris", postalCode: "75011", startDate: "2026-11-02", endDate: "2026-11-06" });
  const c = publicEstimateBody2410({ serviceType: "house_sitting", city: "Paris", postalCode: "75011", startDate: "2026-11-02", endDate: "2026-11-07" });
  assert.equal(publicEstimateKey2410(a), publicEstimateKey2410(b));
  assert.notEqual(publicEstimateKey2410(a), publicEstimateKey2410(c));
  assert.equal(publicEstimateKey2410(null), "");
});
ok("pays des pages villes (mesuré en prod : New York sans pays → basedOn 0 ; avec US → 20 $/jour)", () => {
  assert.equal(countryOfRecruitCity2410("New York, USA", "en"), "US");
  assert.equal(countryOfRecruitCity2410("Texas, USA", "en"), "US");
  assert.equal(countryOfRecruitCity2410("United Kingdom", "en"), "GB");
  assert.equal(countryOfRecruitCity2410("Ireland", "en"), "IE");
  assert.equal(countryOfRecruitCity2410("Netherlands", "en"), "NL");
  assert.equal(countryOfRecruitCity2410("France (English)", "en"), "FR");
  assert.equal(countryOfRecruitCity2410("Île-de-France", "fr"), "FR");
  assert.equal(countryOfRecruitCity2410("Provence-Alpes-Côte d'Azur", "fr"), "FR");
  assert.equal(countryOfRecruitCity2410("Belgique", "fr"), "BE");
  assert.equal(countryOfRecruitCity2410("Suisse", "fr"), "CH");
  assert.equal(countryOfRecruitCity2410("Schweiz", "de"), "CH");
  assert.equal(countryOfRecruitCity2410("Österreich", "de"), "AT");
  assert.equal(countryOfRecruitCity2410("Luxembourg", "fr"), "LU");
  assert.equal(countryOfRecruitCity2410("Monaco", "fr"), "MC");
  assert.equal(countryOfRecruitCity2410("Deutschland", "de"), "DE");
  assert.equal(countryOfRecruitCity2410("España", "es"), "ES");
  assert.equal(countryOfRecruitCity2410("Italia", "it"), "IT");
  assert.equal(countryOfRecruitCity2410("Portugal", "pt"), "PT");
  assert.equal(countryOfRecruitCity2410("Polska", "pl"), "PL");
  assert.equal(countryOfRecruitCity2410("대한민국", "ko"), "KR");
  assert.equal(countryOfRecruitCity2410("日本", "ja"), "JP");
  // région inconnue → langue ; langue inconnue → ''
  assert.equal(countryOfRecruitCity2410("Nulle part", "fr"), "FR");
  assert.equal(countryOfRecruitCity2410("", "xx"), "");
});
ok("ville interrogée : « Paris 11e » → « Paris », « Boulogne-Billancourt » inchangée ; code postal des arrondissements", () => {
  assert.equal(cityQueryName2410("Paris 11e"), "Paris");
  assert.equal(cityQueryName2410("Paris 1er"), "Paris");
  assert.equal(cityQueryName2410("Boulogne-Billancourt"), "Boulogne-Billancourt");
  assert.equal(parisPostal2410("paris-11"), "75011");
  assert.equal(parisPostal2410("paris-1"), "75001");
  assert.equal(parisPostal2410("paris-20"), "75020");
  assert.equal(parisPostal2410("paris-21"), "");
  assert.equal(parisPostal2410("paris"), "");
  assert.equal(parisPostal2410("paris-en"), "");
  assert.equal(parisPostal2410("boulogne-billancourt"), "");
});
ok("lien « Publier ma demande » : ville pré-remplie (?city=), jamais de date ni de ?pre= (réservé à la pub) dans l'URL", () => {
  assert.equal(createPostHref2410("Paris"), "/posts/create?city=Paris&from=prix");
  assert.equal(createPostHref2410("New York"), "/posts/create?city=New%20York&from=prix");
});

console.log(`\n${n}/${n} tests verts (publicEstimate2410)`);
