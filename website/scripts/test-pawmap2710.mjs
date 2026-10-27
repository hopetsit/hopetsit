// 27/10/2026 (LEO) — tests du module pur lib/pawmapGroups2710.ts : regroupement STABLE (règle 626 de PAM,
// portée à l'identique de l'app), toucher d'un groupe (vol sur l'emprise réelle, liste si même endroit),
// groupes de lieux en rond « Anneau » (parité app 625).
//   node scripts/test-pawmap2710.mjs
// Parité app : scripts/pawmap626_parite_app.json = sortie du code de l'APP (frontend/lib/views/map/widgets/
// pawmap_cluster626.dart, exécuté par `dart run` sur les données synthétiques du test pam626_cluster_test de
// PAM). Le site doit donner EXACTEMENT les mêmes groupes, aux mêmes zooms, et le même vol.
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import ts from "typescript";

const here = path.dirname(fileURLToPath(import.meta.url));
const load = (rel) => ts.transpileModule(fs.readFileSync(path.join(here, "..", "src", "lib", rel), "utf8"), { compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2020 } }).outputText;
const url = (js) => "data:text/javascript;base64," + Buffer.from(js).toString("base64");
const p2610 = url(load("pawmap2610.ts"));
const g = await import(url(load("pawmapGroups2710.ts").replace(/from "\.\/pawmap2610"/g, `from "${p2610}"`)));
const pinsUrl = url(load("pins1910.ts"));
const legend = await import(url(load("pawmapLegend.ts").replace(/from "\.\/pins1910"/g, `from "${pinsUrl}"`)));
const APP = JSON.parse(fs.readFileSync(path.join(here, "pawmap626_parite_app.json"), "utf8"));

let n = 0;
const ok = (name, fn) => { fn(); n++; console.log("OK    " + name); };

const DATA = APP.points.map(([id, lat, lng]) => ({ id, lat, lng }));
const pos = (p) => [p.lat, p.lng];
const id = (p) => p.id;
let seed = 7;
const rnd = () => { seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648; };
const shuffle = (a) => { const b = [...a]; for (let i = b.length - 1; i > 0; i--) { const j = Math.floor(rnd() * (i + 1)); [b[i], b[j]] = [b[j], b[i]]; } return b; };
const sig = (groups) => groups.map((x) => `${x.key}|${x.items.map(id).sort().join(",")}|${x.anchor.id}`);
const ZKEYS = Object.keys(APP).filter((k) => /^z/.test(k));

ok(`PARITÉ APP 626 : mêmes groupes, mêmes ancres, mêmes identifiants que l'app à ${ZKEYS.length} zooms (${DATA.length} membres)`, () => {
  const idx = g.clusterIndex2710(DATA, id, pos);
  for (const k of ZKEYS) assert.deepEqual(sig(idx.at(Number(k.slice(1)))).sort(), [...APP[k]].sort(), k);
});

ok("PARITÉ APP 626 : toucher le groupe des USA à z 4,6 → même niveau de division et même vol que l'app", () => {
  const idx = g.clusterIndex2710(DATA, id, pos);
  const grp = idx.at(4.6).filter((c) => c.items.some((p) => p.id.startsWith("u"))).sort((a, b) => b.items.length - a.items.length)[0];
  assert.equal(grp.items.length, APP.tap.n);
  const exp = idx.expansionLevel(grp.items.map(id), 4.6);
  assert.equal(exp, APP.tap.exp);
  const t = g.clusterTapTarget2710({ pts: grp.items.map(pos), w: 393 - 144, h: 852 - 310, currentZoom: 4.6, expansionLevel: exp, maxZoom: 20 });
  assert.ok(Math.abs(t.zoom - APP.tap.zoom) < 1e-9, `${t.zoom} / ${APP.tap.zoom}`);
  assert.ok(Math.abs(t.center[0] - APP.tap.lat) < 1e-9 && Math.abs(t.center[1] - APP.tap.lng) < 1e-9);
});

ok("STABILITÉ : même zoom + mêmes données dans un autre ordre (5 ordres) = exactement les mêmes groupes, zooms 0 à 20", () => {
  const a = g.clusterIndex2710(DATA, id, pos);
  for (let k = 0; k < 5; k++) {
    const b = g.clusterIndex2710(shuffle(DATA), id, pos);
    for (let z = 0; z <= 20; z++) assert.deepEqual(sig(b.at(z)), sig(a.at(z)), `zoom ${z}`);
  }
});

ok("STABILITÉ : deux CHEMINS de chargement (Europe puis USA puis Europe / USA puis Europe) = même cache, mêmes groupes", () => {
  const c1 = new Map(); const c2 = new Map();
  const usa = DATA.filter((p) => p.id.startsWith("u")); const eu = DATA.filter((p) => p.id.startsWith("e"));
  g.mergeCache2710(c1, eu, id); g.mergeCache2710(c1, usa, id); const A = g.mergeCache2710(c1, eu, id);
  g.mergeCache2710(c2, shuffle(usa), id); const B = g.mergeCache2710(c2, shuffle(eu), id);
  const ia = g.clusterIndex2710(A, id, pos), ib = g.clusterIndex2710(B, id, pos);
  for (const z of [3, 5, 8, 10, 12]) assert.deepEqual(sig(ib.at(z)), sig(ia.at(z)));
});

ok("STABILITÉ : entre deux niveaux entiers, les groupes ne bougent pas (5,02 = 5,48 = 5,97 ; zoomSnap 0,5 : 7 = 7,5)", () => {
  const idx = g.clusterIndex2710(DATA, id, pos);
  assert.deepEqual(sig(idx.at(5.48)), sig(idx.at(5.02)));
  assert.deepEqual(sig(idx.at(5.97)), sig(idx.at(5.02)));
  assert.deepEqual(sig(idx.at(7.5)), sig(idx.at(7)));
  assert.notDeepEqual(sig(idx.at(6.01)), sig(idx.at(5.02)));
});

ok("HIÉRARCHIE : un groupe se divise en ses enfants (aucun membre ne saute dans un autre groupe en zoomant)", () => {
  const idx = g.clusterIndex2710(DATA, id, pos);
  for (let z = 0; z < 20; z++) {
    const parent = new Map();
    idx.at(z).forEach((c, i) => c.items.forEach((p) => parent.set(p.id, i)));
    for (const c of idx.at(z + 1)) assert.equal(new Set(c.items.map((p) => parent.get(p.id))).size, 1, `z=${z}`);
  }
});

ok("PLACEMENT (non-régression c0fe532c) : groupe posé sur un VRAI membre, deux groupes à ≥ 56 px, personne de perdu", () => {
  const idx = g.clusterIndex2710(DATA, id, pos);
  for (let z = 0; z <= 20; z++) {
    const gs = idx.at(z);
    for (const x of gs) assert.ok(x.items.includes(x.anchor));
    const P = gs.map((x) => g.mercatorPx2710(x.anchor.lat, x.anchor.lng, z));
    for (let i = 0; i < P.length; i++) for (let j = i + 1; j < P.length; j++) assert.ok(Math.hypot(P[i].x - P[j].x, P[i].y - P[j].y) >= 56 - 1e-6, `zoom ${z}`);
    assert.equal(gs.reduce((s, x) => s + x.items.length, 0), DATA.length);
  }
});

ok("ÉCLATEMENT (bug daniel_1) : toucher le groupe dézoomé → zoom, il se divise, chaque rond SEUL à 0 px de sa place, aucun posé hors d'un vrai membre ; l'ancien anneau 72/132 px violait la règle", () => {
  const idx = g.clusterIndex2710(DATA, id, pos);
  const z0 = 4.6;
  const grp = idx.at(z0).filter((c) => c.items.some((p) => p.id.startsWith("u"))).sort((a, b) => b.items.length - a.items.length)[0];
  const t = g.clusterTapTarget2710({ pts: grp.items.map(pos), w: 1280 - 144, h: 900 - 180, currentZoom: z0, expansionLevel: idx.expansionLevel(grp.items.map(id), z0), maxZoom: 19 });
  assert.ok(t && t.zoom > z0);
  const want = new Set(grp.items.map(id));
  let sub = 0, maxSolo = 0, offMember = 0;
  for (const c of idx.at(t.zoom)) {
    if (!c.items.some((p) => want.has(p.id))) continue;
    sub++;
    if (!c.items.includes(c.anchor)) offMember++;
    if (c.items.length === 1) { const a = g.mercatorPx2710(c.items[0].lat, c.items[0].lng, t.zoom), b = g.mercatorPx2710(c.anchor.lat, c.anchor.lng, t.zoom); maxSolo = Math.max(maxSolo, Math.hypot(a.x - b.x, a.y - b.y)); }
  }
  assert.ok(sub > 1); assert.ok(maxSolo <= 12); assert.equal(offMember, 0);
  // AVANT (c0fe532c) : 6 profils sur un cercle de 72 px et le reste sur 132 px autour du groupe, au zoom +1,5.
  const zOld = z0 + 1.5; const hub = g.mercatorPx2710(grp.anchor.lat, grp.anchor.lng, zOld);
  const k = Math.min(grp.items.length, 21);
  let oldMax = 0, oldKm = 0;
  grp.items.slice(0, k).forEach((p, j) => {
    const inner = Math.min(k, 6), ring = j < inner ? 0 : 1, cnt = ring ? k - inner : inner, i2 = ring ? j - inner : j, rad = ring ? 132 : 72;
    const a = (i2 / cnt) * Math.PI * 2 - Math.PI / 2 + (ring ? Math.PI / cnt : 0);
    const shown = { x: hub.x + Math.cos(a) * rad, y: hub.y + Math.sin(a) * rad * (ring ? 0.95 : 1) };
    const real = g.mercatorPx2710(p.lat, p.lng, zOld);
    const d = Math.hypot(real.x - shown.x, real.y - shown.y);
    oldMax = Math.max(oldMax, d); oldKm = Math.max(oldKm, (d * 40075 * Math.cos((p.lat * Math.PI) / 180)) / (256 * 2 ** zOld));
  });
  console.log(`      groupe ${grp.items.length} à z ${z0} → z ${t.zoom.toFixed(2)} : ${sub} ronds, écart max seul ${maxSolo.toFixed(1)} px | AVANT : écart max ${oldMax.toFixed(0)} px = ${oldKm.toFixed(0)} km`);
  assert.ok(oldMax > 12);
});

ok("MÊME ENDROIT : points superposés → pas de vol, la LISTE (jamais d'anneau) ; séparés seulement au-delà du zoom max → la liste", () => {
  const same = [{ id: "a", lat: 40.7, lng: -74 }, { id: "b", lat: 40.7, lng: -74 }, { id: "c", lat: 40.7, lng: -74 }];
  const idx = g.clusterIndex2710(same, id, pos);
  assert.equal(idx.at(12).length, 1);
  assert.equal(idx.expansionLevel(same.map(id), 12), null);
  assert.equal(g.clusterTapTarget2710({ pts: same.map(pos), w: 250, h: 500, currentZoom: 12, expansionLevel: null, maxZoom: 19 }), null);
  assert.equal(g.clusterTapTarget2710({ pts: [[48.8566, 2.3522], [48.85661, 2.35221]], w: 250, h: 500, currentZoom: 18, expansionLevel: 20, maxZoom: 19 }), null);
});

ok("VOL : au moins le niveau de division + 0,05, jamais plus que le zoom maximal", () => {
  const t = g.clusterTapTarget2710({ pts: [[40, -80], [48, 10]], w: 300, h: 300, currentZoom: 5, expansionLevel: 6, maxZoom: 19 });
  assert.ok(t.zoom >= 6.05 - 1e-9);
  const t2 = g.clusterTapTarget2710({ pts: [[48.8566, 2.3522], [48.8567, 2.3523]], w: 1000, h: 700, currentZoom: 12, expansionLevel: 17, maxZoom: 19 });
  assert.ok(t2.zoom <= 19 && t2.zoom >= 17.05 - 1e-9);
});

ok("CACHE : une nouvelle réponse COMPLÈTE la liste (rien ne disparaît pendant un chargement), la fiche récente gagne", () => {
  const c = new Map();
  g.mergeCache2710(c, [{ id: "a", lat: 1, lng: 1 }, { id: "b", lat: 2, lng: 2 }], id);
  const out = g.mergeCache2710(c, [{ id: "b", lat: 3, lng: 3 }, { id: "c", lat: 4, lng: 4 }], id);
  assert.deepEqual(out.map(id), ["a", "b", "c"]);
  assert.equal(out[1].lat, 3);
});

ok("RAYON demandé au serveur = carte visible, paliers fixes 30 / 60 / 120 / 250 / 500 km", () => {
  assert.equal(g.viewRadiusKm2710(48.8, 2.3, 48.9, 2.4), 30);
  assert.equal(g.viewRadiusKm2710(42, -5, 51, 8), 500);
  assert.equal(g.viewRadiusKm2710(48.0, 1.5, 49.6, 3.2), 120);
});

ok("FLUIDITÉ : index de 3 000 membres construit en < 1,5 s, puis chaque zoom lu en < 5 ms", () => {
  const big = Array.from({ length: 3000 }, (_, i) => ({ id: `b${String(i).padStart(5, "0")}`, lat: 35 + rnd() * 25, lng: -10 + rnd() * 35 }));
  const t0 = performance.now();
  const idx = g.clusterIndex2710(big, id, pos);
  const build = performance.now() - t0;
  let worst = 0;
  for (let z = 0; z <= 19; z += 0.5) { const t1 = performance.now(); const gs = idx.at(z); worst = Math.max(worst, performance.now() - t1); assert.equal(gs.reduce((s, x) => s + x.items.length, 0), 3000); }
  console.log(`      index 3 000 membres : ${build.toFixed(0)} ms ; lecture d'un zoom : ${worst.toFixed(2)} ms au pire`);
  assert.ok(build < 1500, `${build}`); assert.ok(worst < 5, `${worst}`);
});

ok("SPOTS : 44 px puis 18 px dès le zoom 13 (même règle que l'app)", () => {
  const sp = [{ id: "s1", lat: 48.8566, lng: 2.3522 }, { id: "s2", lat: 48.8566, lng: 2.3537 }];
  const idx = g.clusterIndex2710(sp, id, pos, (z) => (z >= 13 ? 18 : 44));
  assert.equal(idx.at(12).length, 1);
  assert.equal(idx.at(15).length, 2);
});

ok("LIEUX : groupe en rond « Anneau » 48 px, anneau plein 7 px à la couleur du type, plus de carré blanc", () => {
  const h = legend.placeClusterHtml(6, "park");
  assert.match(h, /width:48px;height:48px/);
  assert.match(h, /border-radius:50%/);
  assert.match(h, /stroke="#0F766E" stroke-width="7"/);
  assert.doesNotMatch(h, /border-radius:8px/);
  assert.match(h, />6</);
  const d = legend.placeClusterHtml(120, "vet", true);
  assert.match(d, /99\+/);
  assert.match(d, /background:#262123/);
  assert.match(d, /stroke="#B42318"/);
});

console.log(`\n${n} tests OK`);
