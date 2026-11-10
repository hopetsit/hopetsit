// 26/10/2026 (LEO, 2610) — tests du module pur lib/pawmap2610.ts et du rond sélectionné « épinglé » de pawmapEdge622.
// 10/11/2026 (LEO, build 639) — cas de DESSIN réécrits aux valeurs des pastilles v2 (32 px pleine couleur,
// halos, point « disponible aujourd'hui », bulle claire) ; les cas de LOGIQUE sont inchangés.
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

ok("couleurs v2 (CONTRATS §6, carte seulement) : #ff3a0f / #0f62ff / #00c24a, halos #12d8c9 / #8f5cff / #ff5ad2, disponible #1fe074", () => {
  assert.equal(m.ROLE_2610.owner.color, "#ff3a0f"); assert.equal(m.ROLE_2610.owner.light, "#ff7a52");
  assert.equal(m.ROLE_2610.sitter.color, "#0f62ff"); assert.equal(m.ROLE_2610.sitter.light, "#5ea0ff");
  assert.equal(m.ROLE_2610.walker.color, "#00c24a"); assert.equal(m.ROLE_2610.walker.light, "#3fd476");
  assert.equal(m.BOOST_2610, "#12d8c9"); assert.equal(m.FOLLOW_2610, "#8f5cff"); assert.equal(m.FRIEND_2610, "#ff5ad2");
  assert.equal(m.AVAILABLE_2610, "#1fe074");
  assert.equal(m.GOLD_2610, "#f6b400"); assert.equal(m.GOLD_ICON_2610, "#6b3a00"); assert.equal(m.LIVE_2610, "#e8452f");
  assert.equal(m.PIN_2610, 32);
});

ok("pastille 1 rôle : 32 px pleine couleur, SANS anneau blanc, filet 0,5 + ombre, icône 17 centrée, ombre au sol", () => {
  const h = m.profilePinHtml2610({ roles: ["sitter"] });
  assert.match(h, /^<div data-pin-2610=""  style="position:relative;width:32px;height:32px;transform-origin:50% 50%;">/);
  assert.match(h, /data-disc-2610="" style="position:absolute;inset:0;border-radius:50%;background:#0f62ff;box-shadow:0 0 0 \.5px rgba\(0,0,0,\.25\),0 1px 3px rgba\(0,0,0,\.35\);"/);
  assert.match(h, /left:7\.5px;top:7\.5px;width:17px;height:17px/);
  assert.match(h, /data-ground-2610="" style="position:absolute;left:7px;top:29px;width:18px;height:6px/);
  assert.doesNotMatch(h, /stroke=|#fff 0|0 0 0 2/); // aucun anneau, aucun contour blanc autour du disque
  assert.doesNotMatch(h, /data-(chips|price-bubble|boost|follow|friend|wave|rocket|heart|crown|available|live|online|verified|seltail)-2610/);
});

ok("multi-rôle : camembert dans le disque, icône « animaux », mini-pastilles 12 px (écart 3, haut à 27) pour chaque rôle", () => {
  const h = m.profilePinHtml2610({ roles: ["sitter", "walker"] });
  assert.match(h, /data-disc-2610="" style="position:absolute;inset:0;border-radius:50%;overflow:hidden;/);
  assert.equal((h.match(/<path d="M 16 16 L /g) || []).length, 2);
  assert.match(h, /data-chips-2610="" style="position:absolute;left:50%;top:27px;transform:translateX\(-50%\);display:flex;gap:3px;"/);
  assert.equal((h.match(/width:12px;height:12px;border-radius:50%;background:#(0f62ff|00c24a)/g) || []).length, 2);
  const h3 = m.profilePinHtml2610({ roles: ["owner", "sitter", "walker"] });
  assert.equal((h3.match(/<path d="M 16 16 L /g) || []).length, 3);
  assert.equal((h3.match(/width:12px;height:12px;border-radius:50%;background:#(ff3a0f|0f62ff|00c24a)/g) || []).length, 3);
});

ok("couronne 14 px haut-droite (-5/-5), point direct 7 px bas-droite (-1/-1) pulsé 1,8 s", () => {
  const h = m.profilePinHtml2610({ roles: ["owner"], premium: true, live: true });
  assert.match(h, /data-crown-2610="" style="[^"]*right:-5px;top:-5px;width:14px;height:14px;background:#f6b400/);
  assert.match(h, /data-live-2610="" style="position:absolute;right:-1px;bottom:-1px;width:7px;height:7px;border-radius:50%;background:#e8452f;[^"]*animation:hps2610-pulse 1\.8s/);
});

ok("point « disponible aujourd'hui » : 8 px #1fe074 bas-gauche, UNIQUEMENT si availableDot === true et rôle gardien/promeneur", () => {
  const on = m.profilePinHtml2610({ roles: ["sitter"], availableDot: true });
  assert.match(on, /data-available-2610="" style="position:absolute;left:-1px;bottom:-1px;width:8px;height:8px;border-radius:50%;background:#1fe074;box-shadow:0 0 0 1\.5px #fff;"/);
  assert.match(m.profilePinHtml2610({ roles: ["walker"], availableDot: true }), /data-available-2610/);
  // champ absent (ancien serveur), false, ou valeur « vraie » qui n'est pas true : pas de point
  for (const v of [undefined, null, false, 1, "true"]) assert.doesNotMatch(m.profilePinHtml2610({ roles: ["sitter"], availableDot: v }), /data-available-2610/);
  // jamais sur un propriétaire seul
  assert.doesNotMatch(m.profilePinHtml2610({ roles: ["owner"], availableDot: true }), /data-available-2610/);
  // multi-rôle avec un rôle prestataire : point remonté au-dessus des mini-pastilles
  assert.match(m.profilePinHtml2610({ roles: ["owner", "walker"], availableDot: true }), /data-available-2610="" style="position:absolute;left:-3px;bottom:9px/);
});

ok("bulle de prix : RIEN tant que la pastille n'est pas sélectionnée ; sélection = ×1,18 + pointe 9 px + bulle à 38 px", () => {
  const prices = [{ role: "sitter", amount: "20 €", unit: "/jour" }];
  const off = m.profilePinHtml2610({ roles: ["sitter"], prices });
  assert.doesNotMatch(off, /data-price-bubble-2610/); assert.doesNotMatch(off, /data-seltail-2610/);
  const h = m.profilePinHtml2610({ roles: ["sitter"], prices, selected: true });
  assert.match(h, /data-selected-2610=""/);
  assert.match(h, /transform:scale\(1\.18\)/);
  assert.match(h, /data-seltail-2610="" style="position:absolute;left:11\.5px;top:25\.5px;width:9px;height:9px;border-radius:2px;background:#0f62ff;transform:rotate\(45deg\)/);
  // pointe de la bulle à 21 px au-dessus du centre : 16 + 21 + 1 (demi-diagonale rognée) = 38 depuis le bas
  assert.equal(m.BUBBLE_BOTTOM_2610, 38);
  assert.match(h, /data-price-bubble-2610="" style="position:absolute;left:50%;bottom:38px/);
  // multi-rôle sélectionné : pas de pointe de sélection (les mini-pastilles occupent le bas)
  assert.doesNotMatch(m.profilePinHtml2610({ roles: ["sitter", "walker"], selected: true }), /data-seltail-2610/);
});

ok("bulle v2 : pilule CLAIRE 28 px, pastille d'icône 20 en dégradé, 13/800 + 9,5/600, séparateur 1×14, pointe 11 px, note 16 px", () => {
  const h = m.priceBubbleHtml2610([{ role: "sitter", amount: "20 €", unit: "/jour" }, { role: "walker", amount: "12 €", unit: "/balade" }], 30, { rating: "4.8" });
  assert.match(h, /data-bubble-2610="" style="position:relative;z-index:1;display:flex;align-items:center;height:28px;padding:0 4px;border-radius:999px;background:#ffffff;box-shadow:inset 0 0 0 1px rgba\(0,0,0,\.07\);"/);
  assert.match(h, /width:20px;height:20px;border-radius:50%;background:linear-gradient\(160deg,#5ea0ff,#0f62ff\)/);
  assert.match(h, /width:20px;height:20px;border-radius:50%;background:linear-gradient\(160deg,#3fd476,#00c24a\)/);
  assert.match(h, /font-size:13px;font-weight:800;color:#1d1719/);
  assert.match(h, /font-size:9\.5px;font-weight:600;color:#7a6f71/);
  assert.equal((h.match(/data-bubble-sep-2610/g) || []).length, 1);
  assert.match(h, /data-tail-2610="" style="[^"]*width:11px;height:11px;border-radius:3px;background:#ffffff;transform:rotate\(45deg\);margin-top:-5\.5px;"/);
  assert.match(h, /data-bubble-rating-2610="" style="[^"]*height:16px;[^"]*background:#ffc526/);
  assert.match(h, /color:#3d2600;">4\.8</);
  assert.match(h, /bottom:30px/);
  // la passe de collision décale la pilule par `translate` : elle ne porte ni translate ni animation
  const pill = h.match(/data-bubble-2610="" style="([^"]*)"/)[1];
  assert.doesNotMatch(pill, /translate|animation/);
  // sans note : pas de pastille de note ; sombre : fond #262123, texte #f6efec
  const d = m.priceBubbleHtml2610([{ role: "owner", amount: "30 €", unit: "" }], 39, { dark: true });
  assert.doesNotMatch(d, /data-bubble-rating-2610/);
  assert.match(d, /background:#262123/); assert.match(d, /color:#f6efec/);
  assert.doesNotMatch(d, /hps2610-bub/); // pas d'apparition animée sans `pop`
  assert.match(m.priceBubbleHtml2610([{ role: "owner", amount: "30 €", unit: "" }], 39, { pop: true }), /animation:hps2610-bub \.28s/);
});

ok("groupe : 32 px, fond blanc (sombre #262123), anneau 3,3 partagé par rôle, nombre 13/800 ; « dès X » masqué par défaut", () => {
  const h = m.clusterHtml2610({ counts: { sitter: 5, owner: 5, walker: 4 }, total: 14 });
  assert.match(h, /data-cluster-2610=""  style="position:relative;width:32px;height:32px;"/);
  assert.match(h, /background:#ffffff;box-shadow:0 0 0 \.5px rgba\(0,0,0,\.25\),0 1px 3px rgba\(0,0,0,\.35\)/);
  assert.equal((h.match(/stroke-width="3\.3"/g) || []).length, 3);
  assert.match(h, /font:800 13px/);
  assert.doesNotMatch(h, /data-cluster-from-2610/);
  // un seul rôle : anneau plein (un cercle), pas d'arc
  const one = m.clusterHtml2610({ counts: { walker: 3 }, total: 3 });
  assert.equal((one.match(/stroke-width="3\.3"/g) || []).length, 1);
  const d = m.clusterHtml2610({ counts: { sitter: 1 }, total: 2, dark: true, fromLabel: { from: "dès", amount: "25 €/jour", role: "sitter" } });
  assert.match(d, /background:#262123/);
  assert.match(d, /color:#f6efec/);
  assert.match(d, /data-cluster-open-2610/);
  assert.match(d, /data-cluster-from-2610="" style="position:absolute;left:50%;top:37px;[^"]*height:24px/);
});

ok("halos v2 : UN seul (PawBoost > PawFollow > ami), 43 px bord 2 px, fusée 13 / onde violette / cœur 15 ; couronne toujours en plus", () => {
  const b = m.profilePinHtml2610({ roles: ["walker"], boosted: true, pawFollow: true, friend: true, premium: true });
  assert.match(b, /data-boost-2610="" style="position:absolute;left:-5\.5px;top:-5\.5px;width:43px;height:43px;[^"]*border:2px solid #12d8c9;background:rgba\(18,216,201,\.22\);box-shadow:0 0 9px 1px rgba\(18,216,201,\.75\);/);
  assert.match(b, /data-rocket-2610="" style="[^"]*left:-5px;top:-5px;width:13px;height:13px;background:#12d8c9/);
  assert.doesNotMatch(b, /data-(follow|friend|wave|heart)-2610/);
  assert.match(b, /data-crown-2610/);
  const f = m.profilePinHtml2610({ roles: ["walker"], pawFollow: true, friend: true });
  assert.match(f, /data-follow-2610="" style="[^"]*border:2px solid #8f5cff;background:rgba\(143,92,255,\.22\)/);
  assert.match(f, /data-wave-2610="" style="[^"]*border:2px solid #8f5cff;animation:hps2610-wave 1\.8s ease-out infinite;"/);
  assert.doesNotMatch(f, /data-(boost|friend|rocket|heart)-2610/);
  const a = m.profilePinHtml2610({ roles: ["sitter"], friend: true });
  assert.match(a, /data-friend-2610="" style="[^"]*border:2px solid #ff5ad2;background:rgba\(255,90,210,\.22\)/);
  assert.match(a, /data-heart-2610="" style="[^"]*left:-6px;top:-6px;width:15px;height:15px;background:linear-gradient\(160deg,#f73cc0,#d9159f\)/);
});

ok("signes du site gardés : coche « identité vérifiée » 10 px bord droit, point en ligne 7 px bas-droite, le direct passe devant", () => {
  const h = m.profilePinHtml2610({ roles: ["sitter"], verified: true, online: true });
  assert.match(h, /data-verified-2610="" style="[^"]*right:-5px;top:11px;width:10px;height:10px;background:#2F6FE0/);
  assert.match(h, /data-online-2610="" style="position:absolute;right:-1px;bottom:-1px;width:7px;height:7px;border-radius:50%;background:#16A34A/);
  assert.match(m.profilePinHtml2610({ roles: ["sitter"], online: false }), /data-online-2610="" style="[^"]*background:#C2410C/);
  const d = m.profilePinHtml2610({ roles: ["sitter"], live: true, online: true });
  assert.match(d, /data-live-2610/); assert.doesNotMatch(d, /data-online-2610/);
  // multi-rôle : la coche passe en haut au centre, les points remontent au-dessus des mini-pastilles
  assert.match(m.profilePinHtml2610({ roles: ["sitter", "walker"], verified: true }), /data-verified-2610="" style="[^"]*left:11px;top:-5px/);
  assert.match(m.profilePinHtml2610({ roles: ["sitter", "walker"], online: true }), /data-online-2610="" style="position:absolute;right:-3px;bottom:9px/);
});

ok("clair / sombre : surfaces de la maquette ; « réduire les animations » coupe l'onde et les animations", () => {
  assert.deepEqual(m.surface2610(false), { bg: "#ffffff", ink: "#1d1719", muted: "#7a6f71", line: "rgba(0,0,0,.07)", sep: "rgba(0,0,0,.14)" });
  assert.deepEqual(m.surface2610(true), { bg: "#262123", ink: "#f6efec", muted: "#a99c9e", line: "rgba(255,255,255,.22)", sep: "rgba(255,255,255,.18)" });
  const css = m.PAWMAP_2610_CSS;
  const rm = css.slice(css.indexOf("@media (prefers-reduced-motion: reduce)"));
  assert.ok(rm.length > 40);
  assert.match(rm, /\[data-pin-2610\], \[data-price-bubble-2610\], \[data-live-2610\], \[data-boost-2610\] \{ animation:none !important; \}/);
  assert.match(rm, /\[data-wave-2610\] \{ display:none !important; \}/);
  // le nom du rebond que la passe de collision écoute n'a pas changé
  assert.match(css, /@keyframes hps2610-pop/);
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
  // 26/10 : un rond ne s'écarte plus loin — il glisse de ≤ 12 px, sinon il est replié puis effacé (2e passage).
  assert.ok(r.shifts.has("member:a") || r.hidden.has("member:a") || r.unplaced.has("member:a"));
});

ok("passe : un rond sélectionné dont la pointe est HORS de la carte est masqué (pas de bulle orpheline au bord)", () => {
  const view = { l: 0, t: 0, r: 400, b: 800 };
  const sel = { id: "member:sel", layer: "member", rect: { l: -300, t: 300, r: -140, b: 380 }, anchor: { x: -220, y: 355 }, pinned: true };
  assert.ok(edge.resolveEdges622([sel], view, []).hidden.has("member:sel"));
});

ok("anti-clignotement : rebond une seule fois par sélection, même dessin = même objet icône", () => {
  assert.equal(m.popOnce2610("a", true, 1000), true);
  assert.equal(m.popOnce2610("a", true, 1200), true); // encore dans les 0,35 s du rebond
  assert.equal(m.popOnce2610("a", true, 2000), false); // redessiné plus tard : net, sans rebond
  assert.equal(m.popOnce2610("a", false, 2100), false);
  assert.equal(m.popOnce2610("a", true, 3000), true); // nouvelle sélection : rebond
  assert.doesNotMatch(m.profilePinHtml2610({ roles: ["sitter"], selected: true, pop: false }), /hps2610-pop/);
  assert.match(m.profilePinHtml2610({ roles: ["sitter"], selected: true, pop: false }), /transform:scale\(1.18\)/);
  let made = 0; const a = m.cachedIcon2610("k1", () => ({ id: ++made })); const b = m.cachedIcon2610("k1", () => ({ id: ++made }));
  assert.equal(a, b); assert.equal(made, 1);
});

ok("regroupement ancré : chaque groupe sur une VRAIE position (jamais en mer), aucune paire à moins de 56 px", () => {
  // Deux côtes d'une baie : 3 membres à l'ouest, 3 à l'est, la moyenne tombe au milieu (en mer).
  const P = (x, y) => ({ x, y });
  const west = [P(0, 0), P(4, 10), P(2, 20)], east = [P(40, 0), P(44, 12), P(42, 22)];
  const out = m.mergeAnchored2610([west, east], (p) => p, 56);
  assert.equal(out.length, 1); // fusionnés (moins de 56 px) au lieu d'être écartés
  const g = out[0];
  assert.ok([...west, ...east].includes(g.anchor)); // posé sur un membre réel, pas sur la moyenne (21, 11)
  // Grille de 200 points aléatoires : aucune paire de positions affichées à moins de 56 px.
  let seed = 7; const rnd = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
  const pts = Array.from({ length: 200 }, () => P(rnd() * 1200, rnd() * 800));
  const res = m.mergeAnchored2610(pts.map((p) => [p]), (p) => p, 56);
  assert.equal(res.reduce((s, r) => s + r.items.length, 0), 200);
  for (let i = 0; i < res.length; i++) for (let j = i + 1; j < res.length; j++) {
    const a = res[i].anchor, b = res[j].anchor;
    assert.ok(Math.hypot(a.x - b.x, a.y - b.y) >= 56, "deux ronds à moins de 56 px");
  }
  for (const r of res) assert.ok(r.items.includes(r.anchor));
});

ok("passe : un rond de personne / un groupe glisse de 12 px au plus (sinon il reste ou s'efface), une demande s'écarte", () => {
  const view = { l: 0, t: 0, r: 400, b: 800 };
  const a = { id: "member:a", layer: "member", rect: { l: 100, t: 100, r: 150, b: 150 }, anchor: { x: 125, y: 125 } };
  const b = { id: "mgroup:b", layer: "mgroup", rect: { l: 120, t: 100, r: 170, b: 150 }, anchor: { x: 145, y: 125 } };
  const q = { id: "request:q", layer: "request", rect: { l: 110, t: 110, r: 200, b: 140 }, anchor: { x: 155, y: 140 } };
  const r = edge.resolveEdges622([a, b, q], view, []);
  for (const [id, s] of r.shifts) if (!id.startsWith("request")) assert.ok(Math.hypot(s.dx, s.dy) <= 12, id + " glisse trop");
  assert.ok(r.shifts.has("request:q") || r.hidden.has("request:q"));
  // rond au bord : pas de grand glissement vers l'intérieur
  const e = { id: "member:e", layer: "member", rect: { l: -30, t: 300, r: 20, b: 350 }, anchor: { x: 5, y: 325 } };
  const r2 = edge.resolveEdges622([e], view, []);
  const s2 = r2.shifts.get("member:e");
  assert.ok(!s2 || Math.hypot(s2.dx, s2.dy) <= 12);
});

// 1011 — ami : même dessin que l'app (pastille + halo fuchsia + cœur), légende possible au-dessus.
ok("ami : halo fuchsia + cœur, pas de fusée", () => {
  const h = m.profilePinHtml2610({ roles: ["sitter", "walker"], friend: true });
  assert.ok(h.includes("data-friend-2610"), "halo ami");
  assert.ok(h.includes("data-heart-2610"), "cœur");
  assert.ok(!h.includes("data-rocket-2610"), "pas de fusée");
});
ok("ami boosté : le halo boost garde la priorité, pas de cœur", () => {
  const h = m.profilePinHtml2610({ roles: ["sitter"], friend: true, boosted: true });
  assert.ok(h.includes("data-boost-2610"), "halo boost");
  assert.ok(h.includes("data-rocket-2610"), "fusée");
  assert.ok(!h.includes("data-heart-2610"), "pas de cœur");
  assert.ok(!h.includes("data-friend-2610"), "pas de halo ami");
});
ok("non-ami : ni halo ami ni cœur", () => {
  const h = m.profilePinHtml2610({ roles: ["walker"] });
  assert.ok(!h.includes("data-friend-2610") && !h.includes("data-heart-2610"));
});
ok("légende au-dessus : posée par le bas (S + 8), jamais par le haut", () => {
  const h = m.profilePinHtml2610({ roles: ["sitter"], friend: true, caption: "vu il y a 5 min", captionAbove: true });
  const cap = h.match(/<span data-pin-extra=""[^>]*>vu il y a 5 min<\/span>/)?.[0] || "";
  assert.ok(cap, "légende présente");
  assert.ok(cap.includes(`bottom:${m.PIN_2610 + 8}px`), "bottom S+8");
  assert.ok(!/[;"]top:/.test(cap), "pas de top");
});
ok("légende par défaut : toujours sous le rond (inchangé)", () => {
  const h = m.profilePinHtml2610({ roles: ["sitter"], caption: "Léa" });
  const cap = h.match(/<span data-pin-extra=""[^>]*>Léa<\/span>/)?.[0] || "";
  assert.ok(cap.includes(`top:${m.PIN_2610 + 6}px`), "top S+6");
  assert.ok(!cap.includes("bottom:"), "pas de bottom");
});

console.log(`\n${n}/${n} tests OK`);
