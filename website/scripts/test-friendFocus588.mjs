// 588 — clic sur un ami de la PawMap du site (lib/memberPersons.locateFriend) :
//   node scripts/test-friendFocus588.mjs
// Node ≥ 23 retire les types TypeScript tout seul ; on recopie les deux
// modules dans un dossier temporaire en remplaçant l'alias « @/lib ».
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import assert from "node:assert/strict";

const here = dirname(fileURLToPath(import.meta.url));
const lib = join(here, "..", "src", "lib");
const dir = mkdtempSync(join(tmpdir(), "ff588-"));
writeFileSync(join(dir, "mapCluster.ts"), readFileSync(join(lib, "mapCluster.ts"), "utf8"));
writeFileSync(
  join(dir, "memberPersons.ts"),
  readFileSync(join(lib, "memberPersons.ts"), "utf8")
    .replace(/import type \{[^}]*\} from "@\/lib\/api";\n/, "")
    .replace(/from "@\/lib\/mapCluster"/, 'from "./mapCluster.ts"')
    .replace(/: NearbyMember\b/g, ": any")
    .replace(/NearbyMember\[\]/g, "any[]")
    .replace(/NonNullable<NearbyMember\["roles"\]>\[number\]/g, "any")
    .replace(/NearbyMember\["roles"\]/g, "any")
    .replace(/ as NearbyMember/g, ""),
);
const M = await import(join(dir, "memberPersons.ts"));

let n = 0;
const ok = (name, fn) => { fn(); n += 1; console.log("ok -", name); };


// Couche amis 587 : Jose (profil propriétaire o-jose, gardien s-jose) placé à
// sa position de profil floutée ; Lina partage en direct ; Paul est Masqué.
const friends = [
  { status: "accepted", other: { id: "o-jose", model: "Owner", name: "Jose", personIds: ["o-jose", "s-jose"], location: { coordinates: [2.35, 48.85] }, approxKm: 1 } },
  { status: "accepted", other: { id: "o-lina", model: "Walker", name: "Lina", location: { coordinates: [2.30, 48.87] } } },
  { status: "accepted", other: { id: "o-paul", model: "Owner", name: "Paul", mapVisibility: "hidden", location: null } },
];
// La couche « monde » connaît Jose sous son profil GARDIEN, à une autre position.
const world = [{ id: "s-jose", role: "sitter", name: "Jose", location: { coordinates: [2.40, 48.80] } }];
const members = M.placeFriendsFromList(world, friends);
const live = [{ userId: "o-lina", lat: 48.8712, lng: 2.3011, name: "Lina" }];
const idsOf = (f) => [f.other.id, ...(f.other.personIds || [])];

ok("ami hors direct : position de PROFIL floutée de /friends (pas l'ancien point du monde)", () => {
  const r = M.locateFriend(idsOf(friends[0]), live, members);
  assert.equal(r.kind, "member");
  assert.equal(r.lat, 48.85);
  assert.equal(r.lng, 2.35);
});
ok("ami retrouvé par n'importe lequel de ses profils", () => {
  const r = M.locateFriend(["s-jose"], [], members);
  assert.equal(r.kind, "member");
  assert.equal(r.lat, 48.85);
});
ok("ami en direct : le DIRECT remplace la position de profil", () => {
  const r = M.locateFriend(idsOf(friends[1]), live, members);
  assert.equal(r.kind, "live");
  assert.equal(r.p.userId, "o-lina");
  assert.equal(r.lat, 48.8712);
});
ok("ami Masqué sans direct : aucune position → null (pastille « pas visible »)", () => {
  assert.equal(M.locateFriend(idsOf(friends[2]), live, members, { hidden: true }), null);
  assert.equal(M.locateFriend(idsOf(friends[2]), live, members), null);
});
ok("Masqué mais en direct : le direct l'emporte (partage explicite)", () => {
  const r = M.locateFriend(["o-paul"], [{ userId: "o-paul", lat: 48.9, lng: 2.2 }], members, { hidden: true });
  assert.equal(r.kind, "live");
});
ok("coordonnées invalides ignorées, ids vides → null", () => {
  assert.equal(M.locateFriend(["x"], [{ userId: "x", lat: NaN, lng: 2 }], [{ id: "x", location: { coordinates: [] } }]), null);
  assert.equal(M.locateFriend([], live, members), null);
});

console.log(`\n${n} tests OK`);
