// 25/10/2026 (LEO, 622) — tests des modules purs lib/mapPrice622.ts (prix de la PawMap) et
// lib/pawmapEdge622.ts (rien de coupé, rien sous les rails, aucun chevauchement).
//   node scripts/test-pawmap622.mjs
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import ts from "typescript";

const here = path.dirname(fileURLToPath(import.meta.url));
const load = (rel) => ts.transpileModule(fs.readFileSync(path.join(here, "..", "src", "lib", rel), "utf8"), { compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2020 } }).outputText;
const url = (js) => "data:text/javascript;base64," + Buffer.from(js).toString("base64");
const price = await import(url(load("mapPrice622.ts")));
const layoutUrl = url(load("pawmapLayout607.ts"));
const edge = await import(url(load("pawmapEdge622.ts").replace(/from "\.\/pawmapLayout607"/g, `from "${layoutUrl}"`)));

let n = 0;
const ok = (name, fn) => { fn(); n++; console.log("OK    " + name); };

// ── Prix ────────────────────────────────────────────────────────────────────
ok("tarif réel : priceFrom 0 + prices{14,29 €/jour} → 14,29 €/jour (cas mesuré le 25/10)", () => {
  const r = price.withEffectivePrice622({ role: "sitter", priceFrom: 0, priceUnit: "", currency: "EUR", prices: { house_sitting: { amount: 14.29, unit: "day" }, day_care: { amount: 14.29, unit: "day" } } });
  assert.equal(r.priceFrom, 14.29); assert.equal(r.priceUnit, "day");
});
ok("tarif réel : priceFrom > 0 inchangé ; rien du tout = rien (jamais inventé)", () => {
  const a = { role: "sitter", priceFrom: 20, prices: { x: { amount: 5, unit: "day" } } };
  assert.equal(price.withEffectivePrice622(a), a);
  const b = { role: "walker", priceFrom: 0, prices: {} };
  assert.equal(price.withEffectivePrice622(b), b);
  assert.equal(price.minFromPrices622({ a: { amount: -3 }, b: { amount: "x" } }), null);
});
ok("membre : rôles normalisés, même objet quand rien ne change", () => {
  const m = { role: "sitter", priceFrom: 0, roles: [{ role: "sitter", priceFrom: 0, prices: { h: { amount: 12, unit: "visit" } } }, { role: "owner", priceFrom: 0 }] };
  const out = price.normalizeMemberPrices622(m);
  assert.equal(out.roles[0].priceFrom, 12); assert.equal(out.roles[0].priceUnit, "visit"); assert.equal(out.roles[1], m.roles[1]);
  const same = { role: "sitter", priceFrom: 9, roles: [{ role: "sitter", priceFrom: 9 }] };
  assert.equal(price.normalizeMemberPrices622(same), same);
});
const fmt = (r) => `${r.priceFrom} ${r.currency}/${r.priceUnit || "?"}`;
ok("groupe : plus petit tarif des GARDIENS d'abord, sinon promeneurs", () => {
  const items = [
    { roles: [{ role: "walker", priceFrom: 7, currency: "EUR", priceUnit: "walk" }] },
    { roles: [{ role: "sitter", priceFrom: 25, currency: "EUR", priceUnit: "day" }] },
    { roles: [{ role: "sitter", priceFrom: 18, currency: "EUR", priceUnit: "day" }, { role: "owner", priceFrom: 0 }] },
  ];
  assert.deepEqual(price.clusterFromPrice622(items, (m) => m.roles, fmt), { label: "18 EUR/day", role: "sitter" });
  assert.deepEqual(price.clusterFromPrice622([items[0]], (m) => m.roles, fmt), { label: "7 EUR/walk", role: "walker" });
});
ok("groupe : deux devises → rien ; personne n'a de tarif → rien", () => {
  const items = [{ roles: [{ role: "sitter", priceFrom: 20, currency: "EUR" }] }, { roles: [{ role: "sitter", priceFrom: 30, currency: "USD" }] }];
  assert.equal(price.clusterFromPrice622(items, (m) => m.roles, fmt), null);
  assert.equal(price.clusterFromPrice622([{ roles: [{ role: "sitter", priceFrom: 0 }] }], (m) => m.roles, fmt), null);
});
ok("groupe : le format peut refuser (règle « l'autre côté du marché ») → rien", () => {
  assert.equal(price.clusterFromPrice622([{ roles: [{ role: "sitter", priceFrom: 20, currency: "EUR" }] }], (m) => m.roles, () => null), null);
});
ok("demande : corps de l'estimation publique (position arrondie, devise, dates complètes seulement)", () => {
  const b = price.requestEstimateBody622({ serviceType: "house_sitting", lat: 48.85663, lng: 2.35219, currency: "eur", dateMode: "exact", startDate: "2026-11-02T00:00:00.000Z", endDate: "2026-11-06T00:00:00.000Z" });
  assert.deepEqual(b, { serviceType: "house_sitting", lat: 48.86, lng: 2.35, currency: "EUR", startDate: "2026-11-02", endDate: "2026-11-06" });
  assert.deepEqual(price.requestEstimateBody622({ serviceType: "house_sitting", lat: 48.85, lng: 2.35, dateMode: "tbd", startDate: "2026-11-02", endDate: "2026-11-06" }), { serviceType: "house_sitting", lat: 48.85, lng: 2.35 });
  assert.deepEqual(price.requestEstimateBody622({ serviceType: "house_sitting", lat: 1, lng: 1, startDate: "2026-11-06", endDate: "2026-11-02" }), { serviceType: "house_sitting", lat: 1, lng: 1 });
  assert.equal(price.requestEstimateBody622({ serviceType: "", lat: 1, lng: 1 }), null);
  assert.equal(price.requestEstimateBody622({ serviceType: "x", lat: 0, lng: 0 }), null);
  assert.equal(price.requestEstimateBody622({ serviceType: "home_visit", lat: 1, lng: 1, visitsPerDay: 2 }).visitsPerDay, 2);
});
ok("demande : bulle = sans dates ; même zone d'~50 km / même service / même devise = UNE clé", () => {
  const a = price.requestEstimateBody622({ serviceType: "house_sitting", lat: 48.85, lng: 2.35, currency: "EUR", startDate: "2026-11-02", endDate: "2026-11-06" }, false);
  assert.equal(a.startDate, undefined);
  const b = price.requestEstimateBody622({ serviceType: "house_sitting", lat: 48.9, lng: 2.3, currency: "EUR" }, false);
  assert.equal(price.requestBubbleKey622(a), price.requestBubbleKey622(b));
  const c = price.requestEstimateBody622({ serviceType: "dog_walking", lat: 48.9, lng: 2.3, currency: "EUR" }, false);
  assert.notEqual(price.requestBubbleKey622(a), price.requestBubbleKey622(c));
  const d = price.requestEstimateBody622({ serviceType: "house_sitting", lat: 40.73, lng: -73.99, currency: "USD" }, false);
  assert.notEqual(price.requestBubbleKey622(a), price.requestBubbleKey622(d));
  assert.equal(price.BUBBLE_ESTIMATE_MAX_622 <= 10, true);
});
ok("demande sans devise : New York → pays US (dollars) ; Paris → rien ajouté (euro serveur)", () => {
  assert.equal(price.requestEstimateBody622({ serviceType: "house_sitting", lat: 40.92, lng: -73.86 }).country, "US");
  assert.equal(price.requestEstimateBody622({ serviceType: "house_sitting", lat: 32.78, lng: -96.8 }).country, "US");
  const paris = price.requestEstimateBody622({ serviceType: "house_sitting", lat: 48.86, lng: 2.4 });
  assert.equal(paris.country, undefined); assert.equal(paris.currency, undefined);
  assert.equal(price.requestEstimateBody622({ serviceType: "house_sitting", lat: 40.9, lng: -73.8, currency: "USD" }).country, undefined);
});
ok("demande : service par défaut garde / promenade", () => {
  assert.equal(price.requestServiceType622([], "walk"), "dog_walking");
  assert.equal(price.requestServiceType622(null, "sitting"), "house_sitting");
  assert.equal(price.requestServiceType622(["home_visit", "x"], "sitting"), "home_visit");
});
ok("estimation utilisable : basedOn 0 / fromRate null / pas de marché → rien", () => {
  assert.equal(price.usableEstimate622({ market: true, fromRate: 10, basedOn: 23 }), true);
  assert.equal(price.usableEstimate622({ market: true, fromRate: null, basedOn: 0 }), false);
  assert.equal(price.usableEstimate622({ market: true, fromRate: 10, basedOn: 0 }), false);
  assert.equal(price.usableEstimate622({ market: false, fromRate: 10, basedOn: 3 }), false);
  assert.equal(price.usableEstimate622(null), false);
});

// ── Mise en page ────────────────────────────────────────────────────────────
const view = { l: 0, t: 0, r: 375, b: 600 };
const rails = [{ l: 12, t: 80, r: 62, b: 590 }, { l: 313, t: 90, r: 363, b: 590 }, { l: 179, t: 8, r: 367, b: 52 }];
const R = (l, t, w, h) => ({ l, t, r: l + w, b: t + h });
const touches = (a, b) => a.l < b.r && a.r > b.l && a.t < b.b && a.b > b.t;
const apply = (items, res) => items.filter((i) => !res.hidden.has(i.id)).map((i) => { const s = res.shifts.get(i.id) || { dx: 0, dy: 0 }; return { ...i, rect: { l: i.rect.l + s.dx, t: i.rect.t + s.dy, r: i.rect.r + s.dx, b: i.rect.b + s.dy } }; });

// 26/10 (ordre de Daniel, « les marqueurs ne sont pas à leur place ») : un rond de personne / un groupe
// reste sur sa position (glissement ≤ 12 px) ; sans place il s'efface (2e passage), il ne part plus au loin.
const two = (items, v, ov) => { const r1 = edge.resolveEdges622(items, v, ov); return r1.unplaced.size ? edge.resolveEdges622(items, v, ov, { hideUnplaced: true }) : r1; };
const moved = (res, id) => { const s = res.shifts.get(id); return s ? Math.hypot(s.dx, s.dy) : 0; };
ok("bord : bulle coupée en haut → ramenée de ≤ 12 px dans la carte ; sans place le rond RESTE (jamais effacé, jamais loin)", () => {
  const near = [{ id: "a", layer: "member", rect: R(150, -8, 80, 90), anchor: { x: 190, y: 47 } }];
  const r1 = two(near, view, []);
  const o1 = apply(near, r1);
  assert.equal(o1.length, 1); assert.ok(o1[0].rect.t >= 0 && moved(r1, "a") <= 12);
  const far = [{ id: "b", layer: "member", rect: R(150, -40, 80, 90), anchor: { x: 190, y: 20 } }];
  const r2 = two(far, view, []);
  // 27/10 (règle 626, app = site) : un rond de membre n'est JAMAIS effacé ; il reste à ≤ 12 px de sa place.
  assert.ok(!r2.hidden.has("b") && moved(r2, "b") <= 12);
});
ok("bord : pointe hors de la carte → masquée (jamais un morceau d'épingle)", () => {
  const items = [{ id: "a", layer: "member", rect: R(-30, 200, 46, 46), anchor: { x: -7, y: 223 } }];
  const res = edge.resolveEdges622(items, view, []);
  assert.ok(res.hidden.has("a"));
});
ok("rails (règle 626) : un rond sous un rail en sort de ≤ 12 px s'il y a la place, sinon il RESTE (jamais effacé, jamais loin)", () => {
  const items = [
    { id: "l", layer: "member", rect: R(20, 300, 46, 46), anchor: { x: 43, y: 323 } },
    { id: "t", layer: "mgroup", rect: R(250, 10, 40, 40), anchor: { x: 270, y: 30 } },
  ];
  const res = two(items, view, rails);
  const out = apply(items, res);
  assert.equal(out.length, items.length);
  for (const it of out) assert.ok(moved(res, it.id) <= 12, it.id);
});
ok("chevauchement : deux membres et une demande au même point → ronds gardés à ≤ 12 px, la demande jamais dessus", () => {
  const items = [
    { id: "m1", layer: "member", rect: R(150, 250, 46, 76), anchor: { x: 173, y: 296 } },
    { id: "m2", layer: "member", rect: R(155, 255, 46, 76), anchor: { x: 178, y: 301 } },
    { id: "rq", layer: "request", rect: R(140, 270, 90, 34), anchor: { x: 185, y: 304 } },
  ];
  const res = two(items, view, rails);
  const out = apply(items, res);
  for (const it of out) if (it.layer !== "request") assert.ok(moved(res, it.id) <= 12, it.id);
  // 27/10 (règle 626) : les deux ronds restent (en vrai, deux ronds à < 56 px sont FUSIONNÉS en groupe en
  // amont, voir test-pawmap2710) ; la demande, elle, ne se pose jamais sur un rond.
  assert.ok(!res.hidden.has("m1") && !res.hidden.has("m2"));
  const rq = out.find((x) => x.id === "rq");
  if (rq) for (const m of out.filter((x) => x.layer === "member")) assert.ok(!touches(rq.rect, m.rect), `rq/${m.id}`);
});
ok("secondaire : un groupe de lieux collé à un membre glisse (≤ 40 px) ou s'efface, jamais dessus", () => {
  const items = [
    { id: "m", layer: "member", rect: R(150, 250, 46, 46), anchor: { x: 173, y: 273 } },
    { id: "p", layer: "pgroup", rect: R(160, 260, 32, 32), anchor: { x: 176, y: 276 } },
  ];
  const res = edge.resolveEdges622(items, view, rails);
  const out = apply(items, res);
  if (!res.hidden.has("p")) { const s = res.shifts.get("p"); assert.ok(Math.hypot(s.dx, s.dy) <= 40); assert.ok(!touches(out[0].rect, out[1].rect)); }
});
ok("dense : 40 lieux entassés → aucun chevauchement entre ceux qui restent", () => {
  const items = Array.from({ length: 40 }, (_, i) => ({ id: `p${i}`, layer: "place", rect: R(150 + (i % 5) * 4, 250 + Math.floor(i / 5) * 4, 26, 34), anchor: { x: 163 + (i % 5) * 4, y: 283 + Math.floor(i / 5) * 4 } }));
  const out = apply(items, edge.resolveEdges622(items, view, rails));
  for (let i = 0; i < out.length; i++) for (let j = i + 1; j < out.length; j++) assert.ok(!touches(out[i].rect, out[j].rect));
  assert.ok(out.length >= 3);
});
ok("trop dense (règle 626) : 2e passage → aucun rond de membre, « Moi » ni ami effacé ; les lieux s'effacent", () => {
  const items = Array.from({ length: 30 }, (_, i) => ({ id: `m${i}`, layer: i === 0 ? "me" : i === 1 ? "friend" : i < 20 ? "member" : "place", rect: R(100, 200, 160, 160), anchor: { x: 180, y: 280 } }));
  const res = edge.resolveEdges622(items, { l: 0, t: 0, r: 375, b: 600 }, rails, { hideUnplaced: true });
  for (let i = 0; i < 20; i++) assert.ok(!res.hidden.has(`m${i}`), `m${i}`);
  for (let i = 0; i < 20; i++) assert.ok(moved(res, `m${i}`) <= 12, `m${i}`);
  assert.ok([...res.hidden].some((h) => +h.slice(1) >= 20));
  assert.ok(res.unplaced.size > 0);
});
ok("priorité (26/10, ordre de Daniel) : le rond d'une personne reste sur sa position, c'est la demande qui s'écarte", () => {
  const items = [
    { id: "m", layer: "member", rect: R(150, 250, 46, 76), anchor: { x: 173, y: 296 } },
    { id: "rq", layer: "request", rect: R(140, 260, 90, 34), anchor: { x: 185, y: 294 } },
  ];
  const res = edge.resolveEdges622(items, view, []);
  assert.equal(res.shifts.get("m"), undefined); assert.ok(res.shifts.get("rq") || res.hidden.has("rq"));
});
ok("déterministe : même entrée → même sortie", () => {
  const items = [{ id: "a", layer: "member", rect: R(20, 300, 46, 46), anchor: { x: 43, y: 323 } }, { id: "b", layer: "place", rect: R(60, 300, 26, 34), anchor: { x: 73, y: 333 } }];
  const a = edge.resolveEdges622(items, view, rails); const b = edge.resolveEdges622(items, view, rails);
  assert.deepEqual([...a.shifts.entries()], [...b.shifts.entries()]); assert.deepEqual([...a.hidden], [...b.hidden]);
});

console.log(`\n${n}/${n} OK`);
