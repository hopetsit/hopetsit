// 11/11/2026 (PAM, 641) — retour de Daniel du 10/11 : « les pastilles amis sont trop grandes, il faudra les
// faire juste un peu plus grosses que les pastilles normales ». Sur la carte du site, la photo d'un ami passe
// de 56 à 30 px : 36 px tout compris avec son liseré blanc et son anneau rose, soit +12,5 % d'une pastille
// normale (32 px). « Moi » reste à 56 px. Le dessin 640 (size 56) reste intact : voir test-photopin640.mjs.
//   node scripts/test-photopin641.mjs
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import ts from "typescript";

const here = path.dirname(fileURLToPath(import.meta.url));
const read = (rel) => fs.readFileSync(path.join(here, "..", "src", rel), "utf8");
const load = (rel) => ts.transpileModule(read(path.join("lib", rel)), { compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2020 } }).outputText;
const url = (js) => "data:text/javascript;base64," + Buffer.from(js).toString("base64");
const pinsUrl = url(load("pins1910.ts"));
const m = await import(url(load("pawmapLegend.ts").replace(/from "\.\/pins1910"/g, `from "${pinsUrl}"`)));
const pins = await import(pinsUrl);

let n = 0;
const ok = (name, fn) => { fn(); n++; console.log("OK    " + name); };
const count = (h, re) => (h.match(re) || []).length;
const PHOTO = "https://exemple.test/photo.jpg";
const PASTILLE = 32; // pastille normale du site (pawmap2610.ts, PIN_2610)
const num = (h, re) => Number((h.match(re) || [])[1]);

ok("la pastille normale du site fait bien 32 px (référence du ratio)", () => {
  assert.match(read("lib/pawmap2610.ts"), /PIN_2610 = 32\b/);
});

ok("ami : photo 30 px, 36 px tout compris = +10 à +15 % d'une pastille normale, pas plus", () => {
  assert.equal(m.FRIEND_SMALL_641, true);
  assert.equal(m.FRIEND_PX_641, 30);
  assert.equal(m.FRIEND_PHOTO_PX_641, 30);
  const blanc = num(m.FRIEND_GLOW_641, /0 0 0 (\d+)px #fff/);
  const rose = num(m.FRIEND_GLOW_641, /0 0 0 (\d+)px #ff5ad2/);
  assert.equal(blanc, 1);
  assert.equal(rose, 3); // 1 px de blanc + 2 px de rose
  const total = m.FRIEND_PX_641 + 2 * rose;
  assert.equal(total, 36);
  assert.ok(total / PASTILLE >= 1.1 && total / PASTILLE <= 1.15, `ratio ${total / PASTILLE}`);
});

ok("ami en petit format : rond 30, halo 641, anneau de rôle 2 px + liseré blanc 1 px, sa photo", () => {
  const h = m.photoPinHtml({ name: "Lina", role: "owner", avatar: PHOTO, size: m.FRIEND_PHOTO_PX_641, heart: true });
  assert.match(h, /^<div style="position:relative;width:30px;height:30px;">/);
  assert.ok(h.includes(m.FRIEND_GLOW_641) && !h.includes(m.FRIEND_GLOW_640));
  assert.match(h, /padding:2px;box-shadow/);
  assert.match(h, /border:1px solid #fff;/);
  assert.match(h, /<img src="https:\/\/exemple\.test\/photo\.jpg"/);
});

ok("cœur : UN seul, 16 px, centré sur le milieu de l'anneau rose (coin haut gauche)", () => {
  const h = m.photoPinHtml({ name: "Lina", role: "owner", avatar: PHOTO, size: 30, heart: true });
  assert.equal(count(h, /data-heart-640=""/g), 1);
  assert.match(h, /data-heart-640="" style="position:absolute;left:-5px;top:-5px;width:16px;height:16px;border-radius:50%;/);
  // centre du cœur = -5 + 8 = 3 ; milieu de l'anneau rose à 45° = 15 - (15 + 1 + 1) × √½ = 2,98
  const attendu = 15 - (15 + 1 + 1) * Math.SQRT1_2;
  assert.ok(Math.abs(-5 + 8 - attendu) <= 0.5, `centre attendu ${attendu}`);
});

ok("badges réduits et jamais l'un sur l'autre : couronne 16, point en ligne 10, fusée 16", () => {
  const h = m.photoPinHtml({ name: "Lina", role: "sitter", avatar: PHOTO, size: 30, heart: true, premium: true, online: true });
  assert.match(h, /top:-6px;right:-5px;width:16px;height:16px;/); // couronne
  assert.match(h, /bottom:-2px;right:-2px;width:10px;height:10px;/); // point en ligne, à cheval sur l'anneau
  // cœur : x de -6,5 à 12,5 (liseré compris) ; couronne : x de 19 à 35 → pas de recouvrement
  assert.ok(-5 + 16 + 1.5 < 30 + 5 - 16);
  const b = m.photoPinHtml({ name: "Lina", role: "sitter", avatar: PHOTO, size: 30, heart: true, boosted: true });
  assert.match(b, /bottom:-4px;left:-5px;width:16px;height:16px;/); // fusée
  assert.equal(count(b, /data-heart-640/g), 0);
});

ok("pins (podium, chef de meute) : en bas à gauche sous le cœur, jamais sur le point en ligne", () => {
  const un = pins.pinsOnAvatarHtml({ podium: 1 }, 30, { bottomLeft: true });
  assert.match(un, /data-pins-avatar="" style="position:absolute;bottom:-5px;right:19px;flex-direction:row-reverse;/);
  // un pin de 16 px : bord droit à x = 30 - 19 = 11 ; le point en ligne commence à x = 30 + 2 - 10 = 22
  assert.ok(30 - 19 < 30 + 2 - 10);
  // haut du pin à y = 30 + 5 - 16 = 19 ; bas du cœur (liseré compris) à y = 12,5
  assert.ok(30 + 5 - 16 > -5 + 16 + 1.5);
  const h = m.photoPinHtml({ name: "Lina", role: "sitter", avatar: PHOTO, size: 30, heart: true, online: true, pins: { podium: 1, firstPackLeader: true } });
  assert.match(h, /data-pins-avatar="" style="position:absolute;bottom:-5px;right:19px;/);
  // ancien dessin (56 px) : le pin reste au milieu du bord gauche
  const grand = m.photoPinHtml({ name: "Lina", role: "sitter", avatar: PHOTO, size: 56, heart: true, pins: { podium: 1 } });
  assert.match(grand, /data-pins-avatar="" style="position:absolute;top:50%;/);
});

ok("« moi » : inchangé (56 px, anneau 3 px + liseré 2 px, jamais de halo rose ni de cœur)", () => {
  const h = m.photoPinHtml({ name: "Dan", role: "owner", avatar: PHOTO, me: true, heart: true, premium: true, meLabel: "Moi" });
  assert.match(h, /^<div style="position:relative;width:56px;height:56px;">/);
  assert.match(h, /padding:3px;box-shadow/);
  assert.match(h, /border:2px solid #fff;/);
  assert.match(h, /width:24px;height:24px;/); // couronne de « moi »
  assert.ok(!h.includes("#ff5ad2"));
  assert.equal(count(h, /data-heart-640/g), 0);
});

ok("ami suivi / PawFollow / boosté en petit format : un seul halo, pas de cœur, rond 30", () => {
  for (const extra of [{ followed: true }, { boosted: true }, { pawFollow: true }]) {
    const h = m.photoPinHtml({ name: "Lina", role: "walker", avatar: PHOTO, size: 30, heart: true, ...extra });
    assert.match(h, /^<div style="position:relative;width:30px;height:30px;">/, JSON.stringify(extra));
    assert.equal(count(h, /data-heart-640/g), 0, JSON.stringify(extra));
    assert.ok(!h.includes(m.FRIEND_GLOW_641), JSON.stringify(extra));
  }
});

ok("sans photo : initiales lisibles (10 px) ; étiquette 2 px sous l'anneau rose (35 px), dessus aussi", () => {
  const h = m.photoPinHtml({ name: "Lina Rose", role: "owner", size: 30, heart: true, caption: "Lina" });
  assert.match(h, /font:700 10px\/1 Inter[^>]*>LR<\/span>/);
  assert.match(h, /top:35px;left:50%;[^>]*>Lina<\/span>/);
  const dessus = m.photoPinHtml({ name: "Lina Rose", role: "owner", size: 30, heart: true, caption: "Lina", captionAbove: true });
  assert.match(dessus, /bottom:35px;left:50%;/);
});

ok("dessin 640 intact quand on passe size 56 (coupe-circuit)", () => {
  const h = m.photoPinHtml({ name: "Lina", role: "owner", avatar: PHOTO, size: 56, heart: true, premium: true, online: true });
  assert.ok(h.includes(m.FRIEND_GLOW_640) && !h.includes(m.FRIEND_GLOW_641));
  assert.match(h, /left:-4px;top:-4px;width:20px;height:20px;/);
  assert.match(h, /width:22px;height:22px;/);
  assert.match(h, /bottom:0;right:0;width:13px;height:13px;/);
});

ok("la carte et la légende utilisent la même taille d'ami", () => {
  const poi = read("components/PoiMap.tsx");
  assert.match(poi, /const FRIEND_PX_640 = FRIEND_PHOTO_640 \? FRIEND_PHOTO_PX_641 : 50;/);
  const leg = read("components/PawMapLegendModal.tsx");
  assert.match(leg, /heart: true, size: FRIEND_PHOTO_PX_641/);
  assert.doesNotMatch(leg, /heart: true, size: 56/);
});

console.log(`\n${n} tests OK`);
