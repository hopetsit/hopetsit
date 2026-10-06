// Test de lib/trail612.ts (612, site) : node scripts/test-trail612.mjs
// Mêmes cas que l'app (test/pam612_follow_test.dart) : étoile retirée, saut isolé retiré,
// extrémités gardées, lissage qui ne s'écarte pas du chemin.
import assert from "node:assert/strict";
import { cleanTrail612, appendTrail612, meters612, shortTrail612, fadedTrail612, liveTail612, TRAIL_METERS_612, TRAIL_COLOR_612, TRAIL_WEIGHT_612 } from "../src/lib/trail612.ts";

let n = 0;
const ok = (name, fn) => { fn(); n++; console.log("OK ", name); };
const M = 1 / 111320; // ~1 m en latitude
const line = Array.from({ length: 10 }, (_, i) => [37.85 + i * 8 * M, -1.42]);

ok("moins de 3 points : rendu tel quel", () => {
  assert.deepEqual(cleanTrail612([[1, 2], [3, 4]]), [[1, 2], [3, 4]]);
  assert.deepEqual(cleanTrail612([]), []);
});
ok("étoile (allers-retours à 45 m dans un magasin) : aucun point à plus de 12 m de la ligne", () => {
  const raw = [];
  line.forEach((p, i) => { raw.push(p); if (i >= 3 && i <= 6) raw.push([p[0], p[1] + (i % 2 ? 45 : -45) * M / Math.cos(37.85 * Math.PI / 180)]); });
  const far = (pts) => Math.max(...pts.map((p) => meters612(p, [p[0], -1.42])));
  assert.ok(far(raw) > 40, "le jeu d'essai contient bien des pics");
  const out = cleanTrail612(raw);
  assert.ok(far(out) < 12, `écart max ${far(out).toFixed(1)} m`);
});
ok("saut isolé de 300 m : retiré", () => {
  const raw = [...line.slice(0, 5), [line[4][0] + 300 * M, -1.42 + 0.003], ...line.slice(5)];
  const out = cleanTrail612(raw);
  assert.ok(Math.max(...out.map((p) => Math.abs(p[1] + 1.42))) < 1e-9);
});
ok("premier et dernier point gardés, tracé plus dense (Chaikin 2 passes)", () => {
  const zig = line.map((p, i) => [p[0], p[1] + (i % 2 ? 3 : -3) * M]);
  const out = cleanTrail612(zig);
  assert.deepEqual(out[0], zig[0]);
  assert.deepEqual(out[out.length - 1], zig[zig.length - 1]);
  assert.ok(out.length > zig.length * 3);
});
ok("virage réel à angle droit : gardé (aucun point retiré avant lissage)", () => {
  const turn = [...line.slice(0, 5), ...Array.from({ length: 5 }, (_, i) => [line[4][0], -1.42 + (i + 1) * 10 * M])];
  assert.equal(cleanTrail612(turn, { smoothPasses: 0 }).length, turn.length);
});
ok("valeurs illisibles ignorées", () => {
  assert.equal(cleanTrail612([[1, 2], [NaN, 3], [1.0001, 2], [1.0002, 2]], { smoothPasses: 0 }).length, 3);
});
ok("appendTrail612 : pas de doublon, plafond", () => {
  let t = [];
  t = appendTrail612(t, 1, 2); t = appendTrail612(t, 1, 2); t = appendTrail612(t, 1.001, 2);
  assert.equal(t.length, 2);
  for (let i = 0; i < 50; i++) t = appendTrail612(t, 2 + i * 0.001, 2, 10);
  assert.equal(t.length, 10);
});
const len = (pts) => pts.slice(1).reduce((s, p, i) => s + meters612(pts[i], p), 0);
const long = Array.from({ length: 80 }, (_, i) => [37.85 + i * 8 * M, -1.42]); // 632 m
ok("valeurs de PAM : 200 m, violet #7C3AED, épaisseur 3", () => {
  assert.equal(TRAIL_METERS_612, 200); assert.equal(TRAIL_COLOR_612, "#7C3AED"); assert.equal(TRAIL_WEIGHT_612, 3);
});
ok("traîne = les 200 derniers mètres, coupée pile, finit au dernier point", () => {
  const t = shortTrail612(long);
  assert.ok(Math.abs(len(t) - 200) < 0.01, `longueur ${len(t)}`);
  assert.deepEqual(t[t.length - 1], long[long.length - 1]);
});
ok("chemin plus court que 200 m : rendu entier", () => {
  const t = shortTrail612(long.slice(0, 6));
  assert.equal(t.length, 6); assert.ok(Math.abs(len(t) - 40) < 0.1);
});
ok("fondu : 5 morceaux 0,12 · 0,34 · 0,56 · 0,78 · 1, sans trou", () => {
  const f = fadedTrail612(shortTrail612(long));
  assert.deepEqual(f.map((x) => Math.round(x.alpha * 100) / 100), [0.12, 0.34, 0.56, 0.78, 1]);
  for (let i = 1; i < f.length; i++) assert.deepEqual(f[i].pts[0], f[i - 1].pts[f[i - 1].pts.length - 1]);
  assert.deepEqual(f[4].pts[f[4].pts.length - 1], long[long.length - 1]);
});
ok("1 segment = 1 morceau plein ; moins de 2 points = rien", () => {
  assert.deepEqual(fadedTrail612([[1, 2], [1.001, 2]]).map((x) => x.alpha), [1]);
  assert.equal(fadedTrail612([[1, 2]]).length, 0);
});
ok("ordre : nettoyage + lissage AVANT la coupe (un saut GPS dans les 200 m n'allonge ni n'élargit la traîne)", () => {
  const raw = [...long.slice(0, 70), [long[70][0], -1.42 + 0.0006], ...long.slice(70)];
  const f = liveTail612(raw);
  const all = f.flatMap((x) => x.pts);
  assert.ok(Math.max(...all.map((p) => Math.abs(p[1] + 1.42))) < 1e-9);
  assert.ok(len(f.map((x) => x.pts).reduce((a, b) => [...a, ...b.slice(1)])) <= 200.01);
});
console.log(`${n}/13 verts`);
