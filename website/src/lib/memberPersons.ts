// 25/09/2026 — PawMap 585 (site) : UNE PERSONNE = UN POINT, avec tous ses rôles.
//
// Contrat serveur 585 (backend/src/routes/friendRoutes.js, /members/world et
// /members/nearby) : `id` / `role` = le profil dont la position est retenue ;
// `roles` = TOUS les profils de la personne ; `personIds` = leurs ids ;
// `isFriend` = l'un de ses profils est ami de l'un des miens (à lire EN
// PRIORITÉ). Compatible avec l'ancien serveur : champs absents → la personne
// n'a qu'un rôle, ses ids = [id], l'amitié se déduit de la liste d'amis (qui
// porte `other.personIds` depuis v576).
//
// Module PUR (aucun React, aucun Leaflet) : testé par
// scripts/test-memberPersons.mjs.

import type { NearbyMember } from "@/lib/api";
import { haversineKm } from "@/lib/mapCluster";

export type RoleName = "owner" | "sitter" | "walker";

export type PersonRole = {
  id: string;
  role: RoleName;
  rating?: number;
  reviewsCount?: number;
  priceFrom?: number;
  currency?: string;
  isPremium?: boolean;
};

export function normRole(r: string | undefined | null): RoleName {
  const s = String(r || "").toLowerCase();
  if (s === "sitter") return "sitter";
  if (s === "walker") return "walker";
  return "owner";
}

/** Tous les ids de la personne (profil affiché compris, sans doublon). */
export function personIdsOf(m: NearbyMember): string[] {
  const out = new Set<string>();
  if (m.id) out.add(String(m.id));
  for (const x of m.personIds || []) if (x) out.add(String(x));
  for (const r of m.roles || []) if (r && r.id) out.add(String(r.id));
  return [...out];
}

/**
 * Les rôles de la personne, le rôle du point d'abord. Les infos d'un rôle
 * absentes de `roles` (la couche « proches » n'envoie que {id, role}) sont
 * complétées par celles du point quand il s'agit du même profil.
 */
export function rolesOf(m: NearbyMember): PersonRole[] {
  const list: PersonRole[] = [];
  const seen = new Set<string>();
  const push = (r: PersonRole) => {
    if (!r.id || seen.has(r.id)) return;
    seen.add(r.id);
    list.push(r);
  };
  const self: PersonRole = {
    id: String(m.id),
    role: normRole(m.role),
    rating: m.rating,
    reviewsCount: m.reviewsCount,
    priceFrom: m.priceFrom,
    currency: m.currency,
    isPremium: m.isPremium,
  };
  const raw = Array.isArray(m.roles) ? m.roles : [];
  const first = raw.find((r) => r && String(r.id) === String(m.id));
  push(first ? { ...self, ...cleanRole(first), id: String(first.id), role: normRole(first.role) } : self);
  for (const r of raw) {
    if (!r || !r.id) continue;
    push({ ...cleanRole(r), id: String(r.id), role: normRole(r.role) });
  }
  return list;
}

function cleanRole(r: NonNullable<NearbyMember["roles"]>[number]): Partial<PersonRole> {
  const o: Partial<PersonRole> = {};
  if (typeof r.rating === "number") o.rating = r.rating;
  if (typeof r.reviewsCount === "number") o.reviewsCount = r.reviewsCount;
  if (typeof r.priceFrom === "number") o.priceFrom = r.priceFrom;
  if (r.currency) o.currency = r.currency;
  if (typeof r.isPremium === "boolean") o.isPremium = r.isPremium;
  return o;
}

/**
 * Ensemble des ids « amis » à partir de /friends : `other.id` et, depuis
 * v576, `other.personIds` (tous les profils de l'ami).
 */
export function friendIdSetFrom(friends: { other?: { id?: string; personIds?: string[] } | null }[]): Set<string> {
  const s = new Set<string>();
  for (const f of friends || []) {
    const o = f && f.other;
    if (!o) continue;
    if (o.id) s.add(String(o.id));
    for (const x of o.personIds || []) if (x) s.add(String(x));
  }
  return s;
}

/** Ami ? `isFriend` du serveur d'abord, sinon l'un de ses ids est dans ma liste d'amis. */
export function isFriendMember(m: NearbyMember, friendIds: Set<string>): boolean {
  if (m.isFriend === true) return true;
  return personIdsOf(m).some((x) => friendIds.has(x));
}

/**
 * Fusion « proches » (position exacte, abonnés) + « monde » (floutée) : une
 * personne n'apparaît qu'UNE fois, même si les deux couches ont retenu des
 * profils différents. Les rôles du monde (note, prix) complètent ceux des
 * proches.
 */
export function mergePersons(nearby: NearbyMember[], world: NearbyMember[]): NearbyMember[] {
  const out: NearbyMember[] = [];
  const idx = new Map<string, number>();
  const add = (m: NearbyMember) => {
    const ids = personIdsOf(m);
    const hit = ids.map((x) => idx.get(x)).find((i) => i !== undefined);
    if (hit !== undefined) {
      const cur = out[hit];
      // Compléter les rôles (note, prix) sans déplacer le point.
      const byId = new Map(rolesOf(m).map((r) => [r.id, r]));
      const merged: PersonRole[] = rolesOf(cur).map((r) => ({ ...(byId.get(r.id) || {}), ...stripUndef(r), id: r.id, role: r.role }));
      for (const r of rolesOf(m)) if (!merged.some((x) => x.id === r.id)) merged.push(r);
      const allIds = [...new Set([...personIdsOf(cur), ...ids])];
      out[hit] = {
        ...cur,
        roles: merged,
        personIds: allIds,
        isFriend: cur.isFriend === true || m.isFriend === true || undefined,
        rating: cur.rating ?? m.rating,
        reviewsCount: cur.reviewsCount ?? m.reviewsCount,
        priceFrom: cur.priceFrom ?? m.priceFrom,
        currency: cur.currency ?? m.currency,
        avatar: cur.avatar || m.avatar,
        identityVerified: cur.identityVerified ?? m.identityVerified,
        isBoosted: cur.isBoosted ?? m.isBoosted,
      };
      for (const x of allIds) idx.set(x, hit);
      return;
    }
    const i = out.length;
    out.push(m);
    for (const x of ids) idx.set(x, i);
  };
  for (const m of nearby || []) add(m);
  for (const m of world || []) add(m);
  return out;
}

function stripUndef<T extends object>(o: T): Partial<T> {
  const r: Partial<T> = {};
  for (const [k, v] of Object.entries(o)) if (v !== undefined) (r as Record<string, unknown>)[k] = v;
  return r;
}

/** Rôles de la personne retenus par le filtre « Je cherche » (ordre conservé). */
export function rolesMatching(m: NearbyMember, wanted: string[]): PersonRole[] {
  const set = new Set(wanted.map((w) => normRole(w)));
  return rolesOf(m).filter((r) => set.has(r.role));
}

/** Position affichée [lat, lng] du point (ou null). */
export function pointOf(m: NearbyMember): [number, number] | null {
  const c = m.location?.coordinates;
  if (!Array.isArray(c) || c.length < 2) return null;
  const lat = Number(c[1]);
  const lng = Number(c[0]);
  return Number.isFinite(lat) && Number.isFinite(lng) ? [lat, lng] : null;
}

/** Distance (km) depuis `from` jusqu'au point AFFICHÉ de la personne. */
export function distanceKmTo(m: NearbyMember, from: { lat: number; lng: number } | null | undefined): number | null {
  const p = pointOf(m);
  if (!p || !from) return null;
  return haversineKm(from.lat, from.lng, p[0], p[1]);
}

export function formatKm(km: number | null | undefined, lang?: string): string {
  if (km == null || !Number.isFinite(km)) return "";
  if (km < 1) return `${Math.max(10, Math.round((km * 1000) / 10) * 10)} m`;
  if (km >= 10) return `${Math.round(km)} km`;
  if (!lang) return `${km.toFixed(1)} km`;
  try { return `${km.toLocaleString(lang, { minimumFractionDigits: 1, maximumFractionDigits: 1 })} km`; } catch { return `${km.toFixed(1)} km`; }
}

/**
 * Un groupe dont les points ne se sépareront pas en zoomant (même position à
 * ~25 m près, ou la même personne sur plusieurs points) : le clic ouvre la
 * liste au lieu de zoomer dans le vide.
 */
export function isStackedGroup(items: NearbyMember[], maxMeters = 25): boolean {
  if (items.length < 2) return false;
  const pts = items.map(pointOf).filter((p): p is [number, number] => !!p);
  if (pts.length < 2) return false;
  let far = 0;
  for (let i = 0; i < pts.length; i += 1) {
    for (let j = i + 1; j < pts.length; j += 1) {
      far = Math.max(far, haversineKm(pts[i][0], pts[i][1], pts[j][0], pts[j][1]) * 1000);
    }
  }
  if (far <= maxMeters) return true;
  // Même personne sur plusieurs points : tous les points partagent un id.
  const first = new Set(personIdsOf(items[0]));
  return items.every((m) => personIdsOf(m).some((x) => first.has(x)));
}

/** Une ligne par (personne, rôle) : listes « Autour de toi », groupes superposés. */
export type PersonRoleRow = { m: NearbyMember; r: PersonRole; km: number | null; friend: boolean };

export function expandRows(
  items: NearbyMember[],
  opts: { wanted?: string[]; from?: { lat: number; lng: number } | null; friendIds?: Set<string> } = {},
): PersonRoleRow[] {
  const rows: PersonRoleRow[] = [];
  for (const m of items) {
    const roles = opts.wanted ? rolesMatching(m, opts.wanted) : rolesOf(m);
    const km = distanceKmTo(m, opts.from ?? null);
    const friend = isFriendMember(m, opts.friendIds || new Set());
    for (const r of roles.length ? roles : rolesOf(m).slice(0, 1)) rows.push({ m, r, km, friend });
  }
  return rows;
}

/**
 * 587 (point 11, décision de Daniel du 25/09) — la couche AMIS se place depuis
 * `GET /friends` : chaque ami porte sa position de PROFIL floutée ~1 km
 * (`other.location.coordinates` = [lng, lat], `approxKm`, `positionSource`),
 * absente s'il est « Masqué » (`other.mapVisibility === "hidden"`). Elle PRIME
 * sur celle des couches proches / monde (le point garde rôles, note, tarif) ;
 * un ami absent des deux couches (au-delà du plafond, compte de test) est
 * ajouté. Le direct, lui, remplace ce point dans PoiMap (tous ses ids).
 * Serveur sans position dans /friends : liste inchangée (repli placeFriendsAtProfile).
 */
export type FriendForPlacement = {
  status?: string;
  other?: {
    id?: string;
    model?: string;
    name?: string;
    avatar?: string;
    personIds?: string[];
    isPremium?: boolean;
    location?: { coordinates?: [number, number] | number[] } | null;
    approxKm?: number;
    positionSource?: string | null;
    mapVisibility?: string;
    deleted?: boolean;
  } | null;
};

export function friendPointsFrom(friends: FriendForPlacement[]): NearbyMember[] {
  const out: NearbyMember[] = [];
  const seen = new Set<string>();
  for (const f of friends || []) {
    const o = f && f.other;
    if (!o || !o.id || o.deleted || (f.status && f.status !== "accepted")) continue;
    if (o.mapVisibility === "hidden") continue;
    const c = o.location && o.location.coordinates;
    if (!Array.isArray(c) || c.length < 2 || !Number.isFinite(Number(c[0])) || !Number.isFinite(Number(c[1]))) continue;
    const ids = [String(o.id), ...(o.personIds || []).map(String).filter((x) => x && x !== String(o.id))];
    if (ids.some((x) => seen.has(x))) continue;
    ids.forEach((x) => seen.add(x));
    const role = normRole(String(o.model || "owner"));
    out.push({
      id: String(o.id),
      role,
      name: o.name || "",
      avatar: o.avatar || "",
      location: { coordinates: [Number(c[0]), Number(c[1])] },
      isPremium: !!o.isPremium,
      isPawSpot: false,
      isOnline: false,
      approx: true,
      approxKm: typeof o.approxKm === "number" ? o.approxKm : 1,
      personIds: ids,
      isFriend: true,
      positionSource: o.positionSource || undefined,
    } as NearbyMember);
  }
  return out;
}

export function placeFriendsFromList(list: NearbyMember[], friends: FriendForPlacement[]): NearbyMember[] {
  const points = friendPointsFrom(friends);
  if (!points.length) return list;
  const byId = new Map<string, NearbyMember>();
  for (const fp of points) for (const x of personIdsOf(fp)) byId.set(x, fp);
  const used = new Set<NearbyMember>();
  const out: NearbyMember[] = [];
  for (const m of list || []) {
    const fp = personIdsOf(m).map((x) => byId.get(x)).find(Boolean);
    if (!fp) { out.push(m); continue; }
    if (used.has(fp)) continue; // une personne = UN point
    used.add(fp);
    out.push({
      ...m,
      location: { ...(m.location || {}), coordinates: fp.location.coordinates },
      approx: true,
      approxKm: fp.approxKm,
      positionSource: fp.positionSource,
      personIds: [...new Set([...personIdsOf(m), ...personIdsOf(fp)])],
      isFriend: true,
      avatar: m.avatar || fp.avatar,
    } as NearbyMember);
  }
  for (const fp of points) if (!used.has(fp)) out.push(fp);
  return out;
}

/**
 * 25/09 (588) — « quand je clic sur mon ami, ça ne zoome pas sur lui ».
 * OÙ est cet ami sur la carte, dans l'ordre de la couche amis 587 :
 *   1. son DIRECT (partage en cours) → `live` : la page lance le suivi ;
 *   2. sinon son point de la carte (position de profil floutée de /friends,
 *      fusionnée dans les membres) → `member` ;
 *   3. sinon (Masqué, aucune position) → null : pastille « pas visible ».
 * `ids` = tous les ids de la personne (other.id + other.personIds).
 */
export type FriendSpot<L extends { userId: string; lat: number; lng: number }> =
  | { kind: "live"; p: L; lat: number; lng: number }
  | { kind: "member"; m: NearbyMember; lat: number; lng: number };

export function locateFriend<L extends { userId: string; lat: number; lng: number }>(
  ids: string[],
  live: L[],
  members: NearbyMember[],
  opts: { hidden?: boolean } = {},
): FriendSpot<L> | null {
  const want = new Set((ids || []).filter(Boolean).map(String));
  if (!want.size) return null;
  const p = (live || []).find((x) => want.has(String(x.userId)) && Number.isFinite(x.lat) && Number.isFinite(x.lng));
  if (p) return { kind: "live", p, lat: p.lat, lng: p.lng };
  if (opts.hidden) return null;
  for (const m of members || []) {
    if (!personIdsOf(m).some((x) => want.has(x))) continue;
    const c = m.location && m.location.coordinates;
    const lat = Number(c && c[1]);
    const lng = Number(c && c[0]);
    if (!Array.isArray(c) || c.length < 2 || !Number.isFinite(lat) || !Number.isFinite(lng)) continue;
    return { kind: "member", m, lat, lng };
  }
  return null;
}
