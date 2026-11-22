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
ok("tri 17/11 : identité vérifiée d'abord, puis l'ordre d'avant ; le focus reste devant", () => {
  const v = (id, dlat, total, role = "sitter") => { const x = mk(id, dlat, 0, total); x.sitter.identityVerified = true; if (role === "walker") { x.walker = x.sitter; delete x.sitter; } return x; };
  const items = [mk("pres", 0.01, 0.01, 30), v("loinV", 0.5, 90), mk("moyen", 0.1, 0.1, 20), v("presV", 0.02, 80, "walker")];
  assert.deepEqual(lib.sortCandidates3110(items, P).map((x) => x.id), ["presV", "loinV", "pres", "moyen"]);
  assert.deepEqual(lib.sortCandidates3110(items, P, "moyen").map((x) => x.id), ["moyen", "presV", "loinV", "pres"]);
  assert.equal(lib.verified1711(items[0]), false);
  assert.equal(lib.verified1711(items[3]), true);
  // personne de vérifié : exactement l'ordre d'avant
  const none = [mk("a", 0.3, 0.3, 50), mk("b", 0.01, 0.01, 90), mk("c", 0.01, 0.01, 60)];
  assert.deepEqual(lib.sortCandidates3110(none, P).map((x) => x.id), ["c", "b", "a"]);
});
ok("tri 22/11 : photo d'abord, puis identité vérifiée, puis le plus proche ; le focus reste devant", () => {
  const w = (id, dlat, total, { photo = false, verif = false, role = "sitter" } = {}) => {
    const x = mk(id, dlat, 0, total);
    if (photo) x.sitter.avatar = "https://img.test/" + id + ".jpg";
    if (verif) x.sitter.identityVerified = true;
    if (role === "walker") { x.walker = x.sitter; delete x.sitter; }
    return x;
  };
  const items = [
    w("presRien", 0.01, 30),
    w("loinPhoto", 0.5, 90, { photo: true }),
    w("moyenVerif", 0.1, 20, { verif: true }),
    w("moyenPhotoVerif", 0.1, 80, { photo: true, verif: true, role: "walker" }),
    w("presPhoto", 0.02, 70, { photo: true }),
  ];
  // avec photo : vérifié d'abord, puis du plus proche au plus loin ; sans photo ensuite : vérifié, puis le plus proche
  assert.deepEqual(lib.sortCandidates3110(items, P).map((x) => x.id), ["moyenPhotoVerif", "presPhoto", "loinPhoto", "moyenVerif", "presRien"]);
  assert.deepEqual(lib.sortCandidates3110(items, P, "presRien").map((x) => x.id), ["presRien", "moyenPhotoVerif", "presPhoto", "loinPhoto", "moyenVerif"]);
  assert.equal(lib.hasPhoto2211(items[0]), false);
  assert.equal(lib.hasPhoto2211(items[3]), true);
  // photo vide, espaces ou objet : pas une photo (seul le champ texte `avatar` de la carte compte)
  const vide = w("v", 0.01, 10); vide.sitter.avatar = "   ";
  const objet = w("o", 0.01, 10); objet.sitter.avatar = { url: "x" };
  assert.equal(lib.hasPhoto2211(vide), false);
  assert.equal(lib.hasPhoto2211(objet), false);
  assert.equal(lib.hasPhoto2211({ id: "z", status: "pending" }), false);
  // tout le monde a une photo (ou personne) : exactement l'ordre du 17/11
  const all = [w("a", 0.3, 50, { photo: true }), w("b", 0.01, 90, { photo: true }), w("c", 0.2, 60, { photo: true, verif: true })];
  assert.deepEqual(lib.sortCandidates3110(all, P).map((x) => x.id), ["c", "b", "a"]);
});
ok("distance 22/11 : promenade / visite, plus de 10 km après tous les autres ; autres services inchangés ; inconnue = proche", () => {
  const w = (id, dlat, total, extra = {}) => { const x = mk(id, dlat, 0, total, extra); return x; };
  // 0.2° de latitude ≈ 22 km ; 0.05° ≈ 6 km ; 0.09° ≈ 10 km (pas « plus de 10 »)
  const loinPhotoVerif = w("loinPV", 0.2, 20); loinPhotoVerif.sitter.avatar = "https://img.test/l.jpg"; loinPhotoVerif.sitter.identityVerified = true;
  const items = [loinPhotoVerif, w("pres", 0.05, 90), w("limite", 0.09, 50), w("inconnu", null, 10), w("loin2", 0.25, 5 + 10)];
  assert.equal(lib.FAR_KM_2211, 10);
  for (const svc of ["dog_walking", "home_visit"]) {
    assert.deepEqual(lib.sortCandidates3110(items, P, undefined, [svc]).map((x) => x.id), ["pres", "limite", "inconnu", "loinPV", "loin2"], svc);
    assert.equal(lib.isFar2211(items[0], P, [svc]), true);
    assert.equal(lib.isFar2211(items[1], P, [svc]), false);
    assert.equal(lib.isFar2211(items[2], P, [svc]), false); // 10 km tout juste : proche
    assert.equal(lib.isFar2211(items[3], P, [svc]), false); // distance inconnue : proche
    assert.equal(lib.isFar2211(items[0], null, [svc]), false); // demande sans point : personne n'est « loin »
  }
  // aucun candidat ne disparaît
  assert.equal(lib.sortCandidates3110(items, P, undefined, ["dog_walking"]).length, items.length);
  // le candidat du lien reste devant, même loin
  assert.deepEqual(lib.sortCandidates3110(items, P, "loin2", ["dog_walking"]).map((x) => x.id), ["loin2", "pres", "limite", "inconnu", "loinPV"]);
  // garde à domicile, garderie, demande mixte, services inconnus : rien ne change (photo + vérifié d'abord)
  for (const svcs of [["house_sitting"], ["day_care"], ["house_sitting", "dog_walking"], [], undefined, null]) {
    assert.deepEqual(lib.sortCandidates3110(items, P, undefined, svcs).map((x) => x.id), ["loinPV", "pres", "limite", "loin2", "inconnu"], String(svcs));
    assert.equal(lib.isFar2211(items[0], P, svcs), false);
  }
  // le service de la CANDIDATURE prime sur ceux de la demande
  const balade = w("b", 0.2, 20, { serviceType: "dog_walking" });
  const garde = w("g", 0.2, 20, { serviceType: "house_sitting" });
  assert.equal(lib.isFar2211(balade, P, ["house_sitting"]), true);
  assert.equal(lib.isFar2211(garde, P, ["dog_walking"]), false);
});
ok("lot A 22/11 : textes des 9 langues (message prêt, intertitre {km}, libellé « lui parler »)", () => {
  for (const l of LANGS) {
    const d = i18n.CAND3110[l];
    assert.ok(d.q_call.trim().length > 10 && d.q_call.includes("10"), `${l}.q_call`);
    assert.ok(d.far_title.includes("{km}"), `${l}.far_title`);
    assert.ok(i18n.c3110(l, "far_title", { km: 10 }).includes("10"), `${l}.far_title rendu`);
    assert.equal(i18n.c3110(l, "ask_btn", { name: "Inès" }).includes("{name}"), false, `${l}.ask_btn`);
    assert.notEqual(i18n.c3110(l, "q_call"), "q_call");
  }
  assert.equal(i18n.CAND3110.fr.ask_btn, "Lui parler avant de réserver");
  assert.equal(i18n.CAND3110.fr.q_call, "Pouvons-nous nous parler 10 minutes avant que je réserve ?");
});
ok("lot B 22/11 : « Réserver, payer plus tard » — textes des 9 langues, variables {name} {hours} {date} intactes", () => {
  for (const l of LANGS) {
    const d = i18n.CAND3110[l];
    for (const k of ["later_btn", "later_text", "later_held_sub"]) assert.ok(d[k].includes("{name}"), `${l}.${k}`);
    assert.ok(d.later_text.includes("{hours}"), `${l}.later_text`);
    assert.ok(d.later_held.includes("{date}"), `${l}.later_held`);
    const txt = i18n.c3110(l, "later_text", { name: "Inès", hours: 48 });
    assert.ok(txt.includes("Inès") && txt.includes("48") && !txt.includes("{"), `${l}.later_text rendu`);
    assert.ok(i18n.c3110(l, "later_held", { date: "mar. 24 nov., 14:00" }).includes("24 nov"), `${l}.later_held rendu`);
    for (const k of ["later_confirm", "later_busy", "later_pay", "later_write", "later_released", "later_err_late", "later_err"]) assert.notEqual(i18n.c3110(l, k), k, `${l}.${k}`);
  }
  assert.equal(i18n.c3110("fr", "later_btn", { name: "Inès" }), "Réserver Inès, payer plus tard");
  assert.ok(i18n.CAND3110.fr.later_text.includes("Rien n'est débité maintenant"));
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
