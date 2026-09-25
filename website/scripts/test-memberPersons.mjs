// Test de lib/memberPersons.ts (PawMap 585, site) sans dépendance :
//   node scripts/test-memberPersons.mjs
// Node ≥ 23 retire les types TypeScript tout seul ; on recopie les deux
// modules dans un dossier temporaire en remplaçant l'alias « @/lib ».
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import assert from "node:assert/strict";

const here = dirname(fileURLToPath(import.meta.url));
const lib = join(here, "..", "src", "lib");
const dir = mkdtempSync(join(tmpdir(), "mp585-"));
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

const john = { id: "s-john", role: "sitter", name: "John", location: { coordinates: [2.3376, 48.8606] }, priceFrom: 22,
  roles: [{ id: "s-john", role: "sitter", priceFrom: 22, rating: 4.8 }, { id: "o-john", role: "owner" }], personIds: ["s-john", "o-john"] };
const marcNearby = { id: "w-marc", role: "walker", name: "Marc", location: { coordinates: [2.36, 48.865] },
  roles: [{ id: "w-marc", role: "walker" }, { id: "o-marc", role: "owner" }], personIds: ["w-marc", "o-marc"] };
const marcWorldOld = { id: "o-marc", role: "owner", name: "Marc", location: { coordinates: [2.361, 48.866] } };

ok("rôles : le rôle du point d'abord, puis les autres", () => {
  const r = M.rolesOf(john);
  assert.deepEqual(r.map((x) => `${x.role}:${x.id}`), ["sitter:s-john", "owner:o-john"]);
  assert.equal(r[0].priceFrom, 22);
});
ok("ancien serveur : un seul rôle, ids = [id]", () => {
  assert.deepEqual(M.rolesOf(marcWorldOld).map((x) => x.role), ["owner"]);
  assert.deepEqual(M.personIdsOf(marcWorldOld), ["o-marc"]);
});
ok("ami : isFriend du serveur en priorité", () => {
  assert.equal(M.isFriendMember({ ...john, isFriend: true }, new Set()), true);
});
ok("ami : ancien serveur, amitié nouée sous un autre rôle (other.personIds)", () => {
  const set = M.friendIdSetFrom([{ other: { id: "w-marc", personIds: ["w-marc", "o-marc"] } }]);
  assert.equal(M.isFriendMember(marcWorldOld, set), true);
});
ok("ami : liste d'amis sans personIds mais point avec personIds (nouveau serveur)", () => {
  const set = M.friendIdSetFrom([{ other: { id: "o-marc" } }]);
  assert.equal(M.isFriendMember(marcNearby, set), true);
});
ok("non-ami reste non-ami", () => {
  assert.equal(M.isFriendMember(john, M.friendIdSetFrom([{ other: { id: "w-marc", personIds: ["w-marc", "o-marc"] } }])), false);
});
ok("fusion proches + monde : une personne = un point, même si les ids retenus diffèrent", () => {
  const out = M.mergePersons([marcNearby], [marcWorldOld, john]);
  assert.equal(out.length, 2);
  assert.equal(out[0].id, "w-marc");
  assert.deepEqual(out[0].location.coordinates, [2.36, 48.865]);
});
ok("fusion : les prix du monde complètent les rôles des proches", () => {
  const nearbyJohn = { id: "s-john", role: "sitter", location: { coordinates: [2.3377, 48.8607] }, roles: [{ id: "s-john", role: "sitter" }, { id: "o-john", role: "owner" }] };
  const out = M.mergePersons([nearbyJohn], [john]);
  assert.equal(out.length, 1);
  assert.equal(M.rolesOf(out[0])[0].priceFrom, 22);
  assert.equal(M.rolesOf(out[0])[0].rating, 4.8);
});
ok("groupe superposé (même position) → liste", () => {
  const a = { id: "a", role: "walker", location: { coordinates: [2.345, 48.848] } };
  const b = { id: "b", role: "sitter", location: { coordinates: [2.34501, 48.84801] } };
  assert.equal(M.isStackedGroup([a, b]), true);
});
ok("groupe qui se sépare en zoomant → zoom", () => {
  const a = { id: "a", role: "walker", location: { coordinates: [2.345, 48.848] } };
  const b = { id: "b", role: "sitter", location: { coordinates: [2.349, 48.849] } };
  assert.equal(M.isStackedGroup([a, b]), false);
});
ok("même personne sur deux points éloignés (ancien serveur) → liste", () => {
  const a = { id: "o-x", role: "owner", personIds: ["o-x", "s-x"], location: { coordinates: [2.3, 48.8] } };
  const b = { id: "s-x", role: "sitter", location: { coordinates: [2.4, 48.9] } };
  assert.equal(M.isStackedGroup([a, b]), true);
});
ok("distance depuis le point AFFICHÉ", () => {
  const km = M.distanceKmTo(john, { lat: 48.8606, lng: 2.3376 });
  assert.ok(km !== null && km < 0.001);
  assert.equal(M.formatKm(0.004), "10 m");
  assert.equal(M.formatKm(1.234), "1.2 km");
});
ok("listes : une ligne par rôle pertinent, filtre « Je cherche »", () => {
  const rows = M.expandRows([john], { wanted: ["sitter", "walker", "owner"] });
  assert.deepEqual(rows.map((r) => r.r.role), ["sitter", "owner"]);
  const onlyOwners = M.expandRows([john], { wanted: ["owner"] });
  assert.deepEqual(onlyOwners.map((r) => r.r.id), ["o-john"]);
});

ok("587 point 11 — amis placés depuis /friends : floutée, masqué absent, hors couche ajouté, une personne = un point", () => {
  const friends = [
    { status: "accepted", other: { id: "o-john", model: "Owner", name: "John", personIds: ["o-john", "s-john"], location: { coordinates: [2.34, 48.86] }, approxKm: 1, positionSource: "home", mapVisibility: "all" } },
    { status: "accepted", other: { id: "w-ana", model: "Walker", name: "Ana", personIds: ["w-ana"], location: { coordinates: [2.40, 48.84] }, approxKm: 1, mapVisibility: "friends" } },
    { status: "accepted", other: { id: "s-hid", model: "Sitter", name: "Hid", location: null, mapVisibility: "hidden" } },
  ];
  const pts = M.friendPointsFrom(friends);
  assert.deepEqual(pts.map((p) => p.id), ["o-john", "w-ana"]);
  const stranger = { id: "s-zed", role: "sitter", name: "Zed", location: { coordinates: [2.2, 48.8] } };
  const out = M.placeFriendsFromList([john, stranger], friends);
  const j = out.find((m) => M.personIdsOf(m).includes("s-john"));
  assert.deepEqual(j.location.coordinates, [2.34, 48.86]); // position de /friends, pas celle de la couche
  assert.equal(j.isFriend, true);
  assert.equal(j.priceFrom, 22); // le point garde ses champs (tarif, rôles)
  assert.equal(out.filter((m) => M.personIdsOf(m).includes("s-john")).length, 1);
  assert.ok(out.find((m) => m.id === "w-ana" && m.approx === true)); // absent des couches → ajouté
  assert.ok(!out.find((m) => m.id === "s-hid")); // masqué : aucun point
  assert.deepEqual(out.find((m) => m.id === "s-zed").location.coordinates, [2.2, 48.8]); // inconnu intact
  assert.equal(M.placeFriendsFromList([stranger], []).length, 1); // ancien serveur : inchangé
});

console.log(`\n${n} tests OK`);
