// 26/10/2026 (LEO, 2610) — tests du module pur lib/pawmap2610.ts (maquette PawMap de l'app,
// ~/hopetsit-social/design_pawmap_2610/) et du rond sélectionné « épinglé » de pawmapEdge622.
//   node scripts/test-pawmap2610.mjs
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import ts from "typescript";

const here = path.dirname(fileURLToPath(import.meta.url));
const load = (rel) => ts.transpileModule(fs.readFileSync(path.join(here, "..", "src", "lib", rel), "utf8"), { compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2020 } }).outputText;
const url = (js) => "data:text/javascript;base64," + Buffer.from(js).toString("base64");
const m = await import(url(load("pawmap2610.ts")));
const layoutUrl = url(load("pawmapLayout607.ts"));
const edge = await import(url(load("pawmapEdge622.ts").replace(/from "\.\/pawmapLayout607"/g, `from "${layoutUrl}"`)));

let n = 0;
const ok = (name, fn) => { fn(); n++; console.log("OK    " + name); };

ok("couleurs du README : #f23b16 / #1a6cff / #12b350, or #f6b400 (icône #7a4500), direct #e8452f", () => {
  assert.equal(m.ROLE_2610.owner.color, "#f23b16");
  assert.equal(m.ROLE_2610.sitter.color, "#1a6cff");
  assert.equal(m.ROLE_2610.walker.color, "#12b350");
  assert.equal(m.ROLE_2610.owner.glow, "rgba(242,59,22,0.5)");
  assert.equal(m.GOLD_2610, "#f6b400"); assert.equal(m.GOLD_ICON_2610, "#7a4500"); assert.equal(m.LIVE_2610, "#e8452f");
});

ok("rond 1 rôle : 50 px, anneau r 19,5 épaisseur 5, centre r 16 (32 px), aucune pastille", () => {
  const h = m.profilePinHtml2610({ roles: ["sitter"] });
  assert.match(h, /width:50px;height:50px/);
  assert.match(h, /r="19.5" stroke="#1a6cff" stroke-width="5"/);
  assert.match(h, /r="16" fill="#1a6cff"/);
  assert.doesNotMatch(h, /data-chips-2610/);
  assert.doesNotMatch(h, /data-price-bubble-2610/);
  assert.match(h, /0 4px 10px -2px rgba\(26,108,255,0.5\)/);
});

ok("multi-rôle : anneau découpé avec écart de 6°, camembert, pastilles 17 px pour chaque rôle", () => {
  const h = m.profilePinHtml2610({ roles: ["sitter", "walker"] });
  assert.equal((h.match(/stroke-width="5"/g) || []).length, 2);
  assert.match(h, /data-chips-2610/);
  assert.equal((h.match(/width:17px;height:17px;border-radius:50%;background:#(1a6cff|12b350)/g) || []).length, 2);
  // 1er arc commence à 6° (pas à 0°) : point de départ ≠ le haut du cercle.
  const d = h.match(/<path d="(M [^"]+)" stroke="#1a6cff"/)[1];
  const [x0, y0] = d.split(" ").slice(1, 3).map(Number);
  assert.ok(Math.abs(x0 - (25 + 19.5 * Math.sin((6 * Math.PI) / 180))) < 0.01 && Math.abs(y0 - (25 - 19.5 * Math.cos((6 * Math.PI) / 180))) < 0.01);
  const h3 = m.profilePinHtml2610({ roles: ["owner", "sitter", "walker"] });
  assert.equal((h3.match(/stroke-width="5"/g) || []).length, 3);
});

ok("couronne 17 px haut-droite (-4/-4), point direct 10 px bas-droite pulsé 1,8 s", () => {
  const h = m.profilePinHtml2610({ roles: ["owner"], premium: true, live: true });
  assert.match(h, /right:-4px;top:-4px;width:17px;height:17px;border-radius:50%;background:#f6b400/);
  assert.match(h, /right:0;bottom:0;width:10px;height:10px;border-radius:50%;background:#e8452f;.*animation:hps2610-pulse 1.8s/);
});

ok("bulle de prix : RIEN tant que le rond n'est pas sélectionné, même avec des prix", () => {
  const prices = [{ role: "sitter", amount: "20 €", unit: "/jour" }];
  assert.doesNotMatch(m.profilePinHtml2610({ roles: ["sitter"], prices }), /data-price-bubble-2610/);
  const h = m.profilePinHtml2610({ roles: ["sitter"], prices, selected: true });
  assert.match(h, /data-price-bubble-2610/);
  assert.match(h, /transform:scale\(1.18\)/);
  // pointe à 30 px au-dessus du CENTRE (maquette bubBottom anneau = 30) : 25 + 30 = 55 depuis le bas du rond
  assert.match(h, /data-price-bubble-2610="" style="position:absolute;left:50%;bottom:55px/);
});

ok("bulle : pilule blanche padding 2, segment plein par rôle 24 px, icône 12 dans rond 18, 12,5/700 + 9,5/500 88 %, pointe 12 × 7", () => {
  const h = m.priceBubbleHtml2610([{ role: "sitter", amount: "20 €", unit: "/jour" }, { role: "walker", amount: "12 €", unit: "/balade" }], 30);
  assert.match(h, /gap:2px;padding:2px;border-radius:999px;background:#fff/);
  assert.equal((h.match(/height:24px;padding:0 10px 0 3px;border-radius:999px;background:#(1a6cff|12b350)/g) || []).length, 2);
  assert.match(h, /width:18px;height:18px;border-radius:50%;background:#fff/);
  assert.match(h, /width="12" height="12" fill="#1a6cff"/);
  assert.match(h, /font-size:12.5px;font-weight:700/);
  assert.match(h, /font-size:9.5px;font-weight:500;color:rgba\(255,255,255,.88\)/);
  assert.match(h, /border-left:6px solid transparent;border-right:6px solid transparent;border-top:7px solid #fff/);
  assert.match(h, /bottom:30px/);
});

ok("splitPrice : « 20 €/jour » → « 20 € » + « /jour » ; « $40/day » ; sans unité = tout en montant", () => {
  assert.deepEqual(m.splitPrice2610("20 €/jour"), { amount: "20 €", unit: "/jour" });
  assert.deepEqual(m.splitPrice2610("$40/day"), { amount: "$40", unit: "/day" });
  assert.deepEqual(m.splitPrice2610("100 €"), { amount: "100 €", unit: "" });
});

ok("visiblePrices : propriétaire (et visiteur) → gardiens + promeneurs ; gardien/promeneur → propriétaires seulement", () => {
  const prices = [{ role: "owner", amount: "12 €", unit: "/jour" }, { role: "sitter", amount: "25 €", unit: "/jour" }, { role: "walker", amount: "10 €", unit: "/balade" }];
  const all = ["owner", "sitter", "walker"];
  assert.deepEqual(m.visiblePrices2610("owner", all, prices).map((p) => p.role), ["sitter", "walker"]);
  assert.deepEqual(m.visiblePrices2610(null, all, prices).map((p) => p.role), ["sitter", "walker"]);
  assert.deepEqual(m.visiblePrices2610("sitter", all, prices).map((p) => p.role), ["owner"]);
  assert.deepEqual(m.visiblePrices2610("walker", all, prices).map((p) => p.role), ["owner"]);
  // jamais le prix d'un rôle que la personne n'a pas
  assert.deepEqual(m.visiblePrices2610("owner", ["sitter"], prices).map((p) => p.role), ["sitter"]);
});

ok("groupe : 48 px, blanc (sombre #262123), contour blanc 2,5, anneau 7, nombre 15,5/800 ; « dès X » masqué par défaut", () => {
  const h = m.clusterHtml2610({ counts: { sitter: 5, owner: 5, walker: 4 }, total: 14 });
  assert.match(h, /width:48px;height:48px/);
  assert.match(h, /background:#fff;box-shadow:0 0 0 2.5px #fff/);
  assert.equal((h.match(/stroke-width="7"/g) || []).length, 3);
  assert.match(h, /font:800 15.5px/);
  assert.doesNotMatch(h, /data-cluster-from-2610/);
  const d = m.clusterHtml2610({ counts: { sitter: 1 }, total: 2, dark: true, fromLabel: { from: "dès", amount: "25 €/jour", role: "sitter" } });
  assert.match(d, /background:#262123/);
  assert.match(d, /color:#f6efec/);
  assert.match(d, /data-cluster-from-2610/);
});

ok("éclatement : 6 sur un cercle de 72, le reste sur 132 (×0,95 en hauteur), départ en haut", () => {
  const p = m.spiderfy2610(14);
  assert.equal(p.length, 14);
  for (let i = 0; i < 6; i++) assert.ok(Math.abs(Math.hypot(p[i].x, p[i].y) - 72) < 0.2);
  assert.ok(Math.abs(p[0].x) < 0.01 && Math.abs(p[0].y + 72) < 0.01);
  for (let i = 6; i < 14; i++) assert.ok(Math.abs(Math.hypot(p[i].x, p[i].y / 0.95) - 132) < 0.3);
});

ok("éclatement sans chevauchement jusqu'à SPIDER_MAX (ronds de 50 px)", () => {
  for (let n = 2; n <= m.SPIDER_MAX_2610; n++) {
    const p = m.spiderfy2610(n);
    let min = Infinity;
    for (let i = 0; i < n; i++) for (let j = i + 1; j < n; j++) min = Math.min(min, Math.hypot(p[i].x - p[j].x, p[i].y - p[j].y));
    // rond du groupe (48) au centre : écart avec le 1er cercle
    for (const q of p) assert.ok(Math.hypot(q.x, q.y) - 25 - 24 > 0, `n=${n} touche le groupe`);
    assert.ok(min >= 50, `n=${n} : écart minimal ${min.toFixed(1)} px < 50`);
  }
});

ok("passe de mise en page : le rond sélectionné (pinned) n'est ni déplacé ni masqué, les autres s'écartent", () => {
  const view = { l: 0, t: 0, r: 400, b: 800 };
  const sel = { id: "member:sel", layer: "member", rect: { l: 100, t: 300, r: 260, b: 380 }, anchor: { x: 180, y: 355 }, pinned: true };
  const other = { id: "member:a", layer: "member", rect: { l: 150, t: 320, r: 200, b: 370 }, anchor: { x: 175, y: 345 } };
  const r = edge.resolveEdges622([other, sel], view, []);
  assert.ok(!r.shifts.has("member:sel") && !r.hidden.has("member:sel"));
  assert.ok(r.shifts.has("member:a") || r.hidden.has("member:a"));
});

ok("passe : un rond sélectionné dont la pointe est HORS de la carte est masqué (pas de bulle orpheline au bord)", () => {
  const view = { l: 0, t: 0, r: 400, b: 800 };
  const sel = { id: "member:sel", layer: "member", rect: { l: -300, t: 300, r: -140, b: 380 }, anchor: { x: -220, y: 355 }, pinned: true };
  assert.ok(edge.resolveEdges622([sel], view, []).hidden.has("member:sel"));
});

console.log(`\n${n}/${n} tests OK`);
