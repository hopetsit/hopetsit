// 10/11/2026 (BOB, 640) — retours de Daniel : « les cœurs amis s'affichent mal » puis « ma photo de profil
// grande comme celles de mes amis ». Sur la carte du site, un ami est dessiné avec SA PHOTO, à la même taille
// que « moi » (56 px), avec un halo rose net et un cœur en haut à gauche.
//   node scripts/test-photopin640.mjs
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import ts from "typescript";

const here = path.dirname(fileURLToPath(import.meta.url));
const load = (rel) => ts.transpileModule(fs.readFileSync(path.join(here, "..", "src", "lib", rel), "utf8"), { compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2020 } }).outputText;
const url = (js) => "data:text/javascript;base64," + Buffer.from(js).toString("base64");
const pinsUrl = url(load("pins1910.ts"));
const m = await import(url(load("pawmapLegend.ts").replace(/from "\.\/pins1910"/g, `from "${pinsUrl}"`)));

let n = 0;
const ok = (name, fn) => { fn(); n++; console.log("OK    " + name); };
const count = (h, re) => (h.match(re) || []).length;
const PHOTO = "https://exemple.test/photo.jpg";

ok("ami en photo 640 : 56 px, sa photo, halo rose net #ff5ad2, UN cœur en haut à gauche", () => {
  const h = m.photoPinHtml({ name: "Lina", role: "owner", avatar: PHOTO, size: 56, heart: true });
  assert.match(h, /^<div style="position:relative;width:56px;height:56px;">/);
  assert.match(h, /<img src="https:\/\/exemple\.test\/photo\.jpg"/);
  assert.ok(h.includes(m.FRIEND_GLOW_640));
  assert.match(m.FRIEND_GLOW_640, /0 0 0 3px #fff,0 0 0 7px #ff5ad2/);
  assert.equal(count(h, /data-heart-640=""/g), 1);
  assert.match(h, /data-heart-640="" style="position:absolute;left:-4px;top:-4px;width:20px;height:20px;border-radius:50%;[^"]*background:linear-gradient\(160deg,#f73cc0,#d9159f\);box-shadow:0 0 0 1\.5px #fff/);
});

ok("ami et moi : même diamètre (56) quand la carte passe size 56 ; sans size : moi 56, ami 50 (ancien dessin intact)", () => {
  const moi = m.photoPinHtml({ name: "Dan", role: "owner", avatar: PHOTO, me: true });
  const ami = m.photoPinHtml({ name: "Lina", role: "sitter", avatar: PHOTO, size: 56, heart: true });
  const ancien = m.photoPinHtml({ name: "Lina", role: "sitter", avatar: PHOTO });
  assert.match(moi, /^<div style="position:relative;width:56px;height:56px;">/);
  assert.match(ami, /^<div style="position:relative;width:56px;height:56px;">/);
  assert.match(ancien, /^<div style="position:relative;width:50px;height:50px;">/);
  assert.ok(ancien.includes(m.FRIEND_GLOW) && !ancien.includes(m.FRIEND_GLOW_640));
  assert.equal(count(ancien, /data-heart-640/g), 0);
});

ok("moi : jamais de cœur ni de halo rose, étiquette « Moi » sous le rond", () => {
  const h = m.photoPinHtml({ name: "Dan", role: "owner", avatar: PHOTO, me: true, heart: true, meLabel: "Moi" });
  assert.equal(count(h, /data-heart-640/g), 0);
  assert.ok(!h.includes("#ff5ad2"));
  assert.match(h, /top:59px;[^>]*>Moi<\/span>/);
});

ok("un seul halo : suivi > boost > PawFollow > ami — le cœur ne sort QUE sous le halo ami", () => {
  for (const extra of [{ followed: true }, { boosted: true }, { pawFollow: true }]) {
    const h = m.photoPinHtml({ name: "Lina", role: "walker", avatar: PHOTO, size: 56, heart: true, ...extra });
    assert.equal(count(h, /data-heart-640/g), 0, JSON.stringify(extra));
    assert.ok(!h.includes(m.FRIEND_GLOW_640), JSON.stringify(extra));
  }
  const suivi = m.photoPinHtml({ name: "Lina", role: "walker", avatar: PHOTO, size: 56, heart: true, followed: true, boosted: true });
  assert.match(suivi, /animation:hps-follow/);
});

ok("photo absente ou cassée : les initiales restent dessous, aucune icône « image cassée »", () => {
  const sans = m.photoPinHtml({ name: "Lina Rose", role: "owner", size: 56, heart: true });
  assert.doesNotMatch(sans, /<img /);
  assert.match(sans, />LR<\/span>/);
  const avec = m.photoPinHtml({ name: "Lina Rose", role: "owner", avatar: PHOTO, size: 56, heart: true });
  assert.match(avec, />LR<\/span><img [^>]*onerror="this\.style\.display='none'"/);
  const douteuse = m.photoPinHtml({ name: "Lina", role: "owner", avatar: "javascript:alert(1)", size: 56, heart: true });
  assert.doesNotMatch(douteuse, /<img |javascript:/);
});

ok("nom et photo échappés (pas d'injection dans le HTML du repère)", () => {
  const h = m.photoPinHtml({ name: "<b>x", role: "owner", avatar: 'https://exemple.test/a".jpg', size: 56, heart: true, caption: "<i>vu" });
  assert.doesNotMatch(h, /<b>|<i>vu|a"\.jpg/);
});

ok("pastille en ligne, couronne et légende : toujours là avec le cœur, sans se superposer au coin haut gauche", () => {
  const h = m.photoPinHtml({ name: "Lina", role: "sitter", avatar: PHOTO, size: 56, heart: true, premium: true, online: true, caption: "Lina" });
  assert.equal(count(h, /data-heart-640=""/g), 1);
  assert.match(h, /top:59px;left:50%;[^>]*>Lina<\/span>/);
  const dessus = m.photoPinHtml({ name: "Lina", role: "sitter", avatar: PHOTO, size: 56, heart: true, caption: "vu il y a 5 min", captionAbove: true });
  assert.match(dessus, /bottom:59px;left:50%;/);
});

ok("cœur seul : taille réglable, toujours rond, dégradé rose, liseré blanc", () => {
  assert.match(m.friendHeartBadge640(), /width:20px;height:20px/);
  assert.match(m.friendHeartBadge640(24), /width:24px;height:24px/);
});

console.log(`\n${n} tests OK`);
