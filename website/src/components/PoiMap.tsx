"use client";

// v23.1 part 146 — Composant carte interactive avec POI pet-friendly.
// v23.1 carte unique — Daniel : "sur le site web, UNE SEULE carte". PoiMap
// est LA carte du site : lieux + ma position + couches optionnelles pilotées
// par /map (amis en direct, PawSpots, signalements, membres, itinéraire).
//
// 24/09/2026 — LOT B, étape 3 : LA NOUVELLE LÉGENDE (LEGENDE_PAWMAP.md,
// validée par Daniel le 23/09), identique à l'app :
//   rond = personne (icône du rôle, couleur du rôle à tous les zooms),
//   goutte = lieu (couleur du type), carré = groupe de lieux, noir et or =
//   PawSpot, rose = ami, couronne or = Premium, PawBoost = lueur turquoise qui
//   respire + fusée, « Moi » 56 px avec ma photo, demandes des propriétaires
//   en bulle orange foncé (prix dedans), signalement = triangle rouge.
// + zoom de suivi « joli » (vol en douceur, zoom rue, suit le point, tracé
//   violet PawFollow, pause au geste), mode sombre, prix sur l'épingle au
//   zoom rue. Tous les dessins viennent de lib/pawmapLegend.ts.

import { useEffect, useMemo, useRef, useState } from "react";
import {
  Circle,
  CircleMarker,
  MapContainer,
  Marker,
  Pane,
  Polyline,
  Popup,
  TileLayer,
  Tooltip,
  useMap,
  useMapEvents,
} from "react-leaflet";
import "leaflet/dist/leaflet.css";
import L from "leaflet";
import type { RouteStep } from "@/lib/api";
import { getProviderBadge607 } from "@/lib/api";
import { CollisionPass607 } from "@/components/CollisionPass607";
import { VerifiedPill } from "@/components/VerifiedPill";
import {
  MapReport,
  MapReportType,
  NearbyMember,
  POI_CATEGORY_LABELS,
  PawSpot,
  PawSpotType,
  Poi,
  PoiCategory,
} from "@/lib/api";
import { makeAvatarIcon } from "@/components/FriendsLiveMap";
import { liveTail612, TRAIL_COLOR_612, TRAIL_WEIGHT_612 } from "@/lib/trail612";
import { alertAlpha613, alertFresh613, alertPinHtml613, emojiDraws613, reportEmoji613 } from "@/lib/alerts613";
import { JOIN_LEAD_MIN_M_613, meters613 } from "@/lib/join613";
import type { FriendLivePosition, Role } from "@/components/FriendsLiveMap";
import { clusterize } from "@/lib/mapCluster";
import {
  PRICE_ZOOM_607,
  CITY_PRICE_ZOOM_607,
  MEMBER_CELL_PX_607,
  mercatorPx,
  mergeCloseGroups,
  pinBox,
  repelBoxes,
  type PlacedBox,
  mercatorToLatLng,
  pickLabelSide,
  bubbleHasRoom,
  labelRect,
  circleRect,
  textWidth,
  type Px,
  type Rect,
  type LabelSide,
} from "@/lib/pawmapOverlap607";
import {
  memberPinHtml,
  photoPinHtml,
  memberClusterHtml,
  placePinHtml,
  placeClusterHtml,
  spotPinHtml,
  spotClusterHtml,
  dominantRole,
  roleCounts,
  requestBubbleHtml,
  ROLE_COLOR,
  PAWFOLLOW_VIOLET,
  PAWMAP_KEYFRAMES,
  PIN_Z,
  roleKey,
  ROLE_GLYPH,
  showsPriceBubble,
  spotPinAnchor,
  POPPINS,
} from "@/lib/pawmapLegend";
import { safeFly } from "@/lib/safeFly";
import { ensureOwnerProfile, isMyProfile, needsOwnerSwitch } from "@/lib/bookAsOwner";
import { OwnerRequestsCard } from "@/components/OwnerRequestsCard";
import { useT } from "@/lib/i18n/LanguageProvider";
import { formatPriceUnit, priceUnitLabels, type PriceAlt } from "@/lib/priceUnit";
import { serviceLabel620 } from "@/lib/i18n/dates620";
import {
  expandRows,
  formatKm,
  isFriendMember,
  personIdsOf,
  pointOf,
  isStackedGroup,
  rolesMatching,
  rolesOf,
  sameRole,
  distanceKmTo,
  type PersonRole,
} from "@/lib/memberPersons";
import { RankPill611 } from "@/components/Rank611";
import { parseRank611, type Rank611 } from "@/lib/ranks611";
import { parsePins1910, pinsOnAvatarHtml, type Pins1910 } from "@/lib/pins1910";
import { PinChips1910 } from "@/components/Pins1910";
import { clusterFromPrice622, normalizeMemberPrices622, type MapRequestPricing622 } from "@/lib/mapPrice622";
import { RequestFromLine622, useFromText622, useRequestFromLabels622 } from "@/components/RequestFrom622";
import { clusterIndex2710, clusterTapTarget2710, type ClusterIndex2710 } from "@/lib/pawmapGroups2710";
import { PAWMAP_2610_CSS, SPIDER_MAX_2610, cachedIcon2610, popOnce2610, clusterHtml2610, priceBubbleHtml2610, profilePinHtml2610, role2610, splitPrice2610, visibleRoles2610, type Price2610, type Role2610 } from "@/lib/pawmap2610";

export { clusterize } from "@/lib/mapCluster";

// 25/09 — une fiche (popup) ne passe plus sous le rail de gauche ni sous les
// boutons du haut : Leaflet décale la carte pour la laisser entièrement libre.
L.Popup.mergeOptions({ autoPanPaddingTopLeft: L.point(72, 64), autoPanPaddingBottomRight: L.point(64, 24) });

// v559 — pictogramme d'une manœuvre Valhalla (info-bulle des repères de virage).
function stepGlyph(type: number): string {
  if (type >= 4 && type <= 6) return "◉";
  if (type >= 9 && type <= 11) return "↱";
  if (type >= 14 && type <= 16) return "↰";
  if (type === 12 || type === 13) return "↩";
  if (type === 26 || type === 27) return "⟳";
  return "↑";
}

// Fix global icones Leaflet (sinon path cassé en bundler).
// @ts-expect-error — Leaflet stocke ses defaults via _getIconUrl interne.
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
});

/** Demande d'un propriétaire, position déjà FLOUTÉE par la page (~1 km). */
export type MapRequest = {
  id: string;
  lat: number;
  lng: number;
  service: "sitting" | "walk";
  priceLabel?: string | null;
  mine?: boolean;
  boosted?: boolean;
  title?: string;
  body?: string;
  ownerName?: string;
  city?: string;
  /** v587 (point 8) — lieu du service déjà traduit (« Chez moi », « Point de rendez-vous · … »). */
  locationLabel?: string;
  /** 590 — photo du propriétaire (carte focus). */
  ownerAvatar?: string;
  /** 26/10 (2610) — profil propriétaire de la demande : son rond montre ce budget au toucher. */
  ownerId?: string;
  /** 622 — de quoi demander « à partir de » (POST /pricing/estimate/public) : service, devise, dates. */
  pricing?: MapRequestPricing622 | null;
};

// ── Icônes (un dessin par famille, dans lib/pawmapLegend) ────────────────────
const placeIconCache = new Map<string, L.DivIcon>();
function placeIcon(category: PoiCategory): L.DivIcon {
  let ic = placeIconCache.get(category);
  if (!ic) {
    // 25/09 — lieux ordinaires plus discrets (26 px) : les personnes passent devant.
    ic = L.divIcon({ className: "hps-l-place", html: placePinHtml(category, 26), iconSize: [26, 34], iconAnchor: [13, 33], popupAnchor: [0, -30] });
    placeIconCache.set(category, ic);
  }
  return ic;
}
// 590 (§6) — goutte 40 px noir / or à TOUS les zooms, pointe = position.
function spotIcon(type: PawSpotType, golden: boolean, label?: string | null): L.DivIcon {
  return L.divIcon({ className: "hps-l-spot", html: spotPinHtml(type, golden, { label }), iconSize: [40, 50], iconAnchor: spotPinAnchor(40), popupAnchor: [0, -44] });
}
// 613 — épingle d'alerte de l'app : anneau de gravité, auréole fixe < 2 h, jamais de rond vide.
const reportIconCache = new Map<string, L.DivIcon>();
const reportIcon = (type: string, fresh: boolean) => {
  const key = `${type}|${fresh ? 1 : 0}`;
  let ic = reportIconCache.get(key);
  if (!ic) {
    ic = L.divIcon({ className: "hps-l-report", html: alertPinHtml613(type, { size: 36, fresh, emojiOk: emojiDraws613(reportEmoji613(type)) }), iconSize: [36, 36], iconAnchor: [18, 18], popupAnchor: [0, -16] });
    reportIconCache.set(key, ic);
  }
  return ic;
};
// 26/10 (2610, maquette de l'app « A · Anneau ») — rond de profil 50 px, prix SEULEMENT sur le rond
// sélectionné, autres ronds à 85 % pendant une sélection, décalage d'éclatement d'un groupe (`off`).
function memberIcon(m: NearbyMember, caption: string | null, roles: PersonRole[], dark: boolean, o: { selected?: boolean; dim?: boolean; prices?: Price2610[]; live?: boolean; off?: { x: number; y: number } | null } = {}): L.DivIcon {
  const ox = Math.round(o.off?.x ?? 0);
  const oy = Math.round(o.off?.y ?? 0);
  // 27/10 — rond d'un groupe éclaté (≤ 12 px de sa vraie place) : « épinglé » dans la passe de mise en page.
  const className = `hps-l-member${o.dim ? " hps2610-dim" : ""}${o.off ? " hps-fan-2710" : ""}`;
  const html = profilePinHtml2610({
      pop: popOnce2610(`m:${m.id}`, !!o.selected),
      roles: roles.map((r) => r.role),
      premium: !!(m.isPremiumOnly ?? m.isPremium),
      live: !!o.live,
      // 26/10 (Daniel) — signes existants gardés, redessinés discrets sur l'Anneau.
      boosted: !!m.isBoosted,
      pawFollow: !!m.hasPawFollow,
      verified: !!m.identityVerified,
      online: m.approx ? null : m.isOnline !== false,
      pinsHtml: pinsOnAvatarHtml(parsePins1910(m.pins), 50),
      selected: !!o.selected,
      prices: o.prices,
      caption,
      dark,
    });
  // 26/10 (bug « ça clignote ») — même dessin = même icône : aucune réécriture à chaque rendu.
  return cachedIcon2610(`${className}|${ox},${oy}|${html.replace(/animation:hps2610-pop[^;]*;/, "")}`, () => L.divIcon({ className, html, iconSize: [50, 50], iconAnchor: [25 - ox, 25 - oy], popupAnchor: [0, -28] }));
}
/** Ami à sa position de PROFIL (floutée) : photo, anneau rose, pas de direct. */
function friendProfileIcon(m: NearbyMember, premium: boolean, roles: PersonRole[], caption?: string | null, bubble?: string | null, duo?: [string, string] | null, captionAbove = false): L.DivIcon {
  return L.divIcon({
    className: "hps-l-friend",
    // 25/09 (585, bug 11) — un ami boosté garde sa lueur turquoise + fusée.
    html: photoPinHtml({ role: roles[0]?.role || m.role, name: m.name, avatar: m.avatar, premium, boosted: !!m.isBoosted, roles: roles.map((r) => r.role), caption, captionAbove, priceBubble: bubble, priceDuo: duo ?? null, pins: parsePins1910(m.pins) }),
    iconSize: [50, 50],
    iconAnchor: [25, 25],
    popupAnchor: [0, -28],
  });
}
function meIcon(o: { role: string; name: string; avatar?: string | null; premium?: boolean; meLabel?: string; friendsOnly?: boolean; boosted?: boolean; pawFollow?: boolean }): L.DivIcon {
  return L.divIcon({
    className: "hps-l-me",
    html: `<div style="position:relative;width:56px;height:56px;"><div style="position:absolute;inset:-8px;border-radius:50%;border:3px solid ${ROLE_COLOR[roleKey(o.role)]};animation:hps-pulse 2s ease-out infinite;"></div>${photoPinHtml({ ...o, me: true })}</div>`,
    iconSize: [56, 56],
    iconAnchor: [28, 28],
    popupAnchor: [0, -32],
  });
}
/** 622 — zoom à partir duquel les prix se montrent (pays). */
const PRICE_ZOOM_COUNTRY_622 = 6;
function requestIcon(r: MapRequest, mineLabel: string, fromLabel?: string | null, selected = false): L.DivIcon {
  // 622 — budget du propriétaire ; sans budget, « dès 10 €/jour » (estimation publique, jamais inventée).
  // 26/10 (2610, maquette de l'app : « par défaut, aucun prix sur la carte ») — le budget n'est plus écrit
  // sur la bulle de demande ; demande TOUCHÉE (gardien / promeneur) : bulle de prix 2610 au-dessus,
  // segment propriétaire (budget saisi, sinon « dès X »).
  const budget = !r.mine ? r.priceLabel || fromLabel || null : null;
  const top = selected && budget ? `<span data-selected-2610="" style="position:absolute;left:0;right:0;bottom:0;height:34px;">${priceBubbleHtml2610([{ role: "owner", ...splitPrice2610(budget) }], 39)}</span>` : "";
  const html = `<div style="position:relative;">${requestBubbleHtml({ service: r.service, priceLabel: null, boosted: r.boosted, mine: r.mine, mineLabel })}${top}</div>`;
  // 26/10 (bug « ça clignote ») — même dessin = même icône.
  return cachedIcon2610(`req|${html}`, () => L.divIcon({
    className: "hps-l-request",
    html,
    // 590 — bulle 26 + pointe 7 : la pointe touche la position (floutée).
    iconSize: [96, 34],
    iconAnchor: [48, 34],
    popupAnchor: [0, -32],
  }));
}

// ── Petits composants ────────────────────────────────────────────────────────
function FlyToFocus({ target }: { target: { lat: number; lng: number; ts: number; zoom?: number; /** 612 — zoom plancher : on s'en approche, on ne recule jamais si l'on est déjà plus près (suivi). */ minZoom?: number; duration?: number } | null }) {
  const map = useMap();
  useEffect(() => {
    if (!target) return;
    // Zoom demandé (ville = 12, ma position = 14), sinon zoom de rue lisible
    // (~17) ; vol en douceur (0,9 s), jamais pendant une autre animation.
    safeFly(map, [target.lat, target.lng], target.minZoom != null ? Math.max(map.getZoom(), target.minZoom) : target.zoom ?? Math.max(map.getZoom(), 17), target.duration ?? 0.9);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [target?.ts]);
  return null;
}

// v404 — recentre quand `center` change FORTEMENT (recherche / géoloc), sans
// toucher au zoom ni contrarier un simple pan.
function RecenterMap({ center }: { center: [number, number] }) {
  const map = useMap();
  useEffect(() => {
    const c = map.getCenter();
    const far = Math.abs(c.lat - center[0]) > 0.05 || Math.abs(c.lng - center[1]) > 0.05;
    if (far) safeFly(map, center, map.getZoom());
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [center[0], center[1]]);
  return null;
}

/** Remonte le zoom courant (regroupement + mémorisation) et le centre à l'arrêt. */
function ViewWatcher({ onZoom, onMove, onBounds }: { onZoom: (z: number) => void; onMove?: (c: { lat: number; lng: number }) => void; onBounds?: (b: { s: number; w: number; n: number; e: number }) => void }) {
  const map = useMap();
  const emitBounds = () => {
    if (!onBounds) return;
    try { const b = map.getBounds(); onBounds({ s: b.getSouth(), w: b.getWest(), n: b.getNorth(), e: b.getEast() }); } catch { /* carte pas prête */ }
  };
  // Une seule fois au montage : `onZoom` est recréé à chaque rendu de la
  // page, le mettre en dépendance faisait boucler (setState → rendu → effet).
  useEffect(() => {
    onZoom(map.getZoom());
    emitBounds();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [map]);
  useMapEvents({
    zoomend(e) {
      onZoom(e.target.getZoom());
      emitBounds();
    },
    moveend(e) {
      const c = e.target.getCenter();
      onMove?.({ lat: c.lat, lng: c.lng });
      emitBounds();
    },
  });
  return null;
}

/**
 * Zoom de suivi « joli » : la caméra vole jusqu'au point suivi (zoom de rue
 * 16,5), puis le garde centré sans à-coups ; un geste de l'utilisateur met le
 * suivi en pause (la page affiche « Reprendre le suivi »).
 */
function FollowController({ target, onUserGesture }: { target: { lat: number; lng: number; key: string; ts?: number } | null; onUserGesture: () => void }) {
  const map = useMap();
  const lastKey = useRef<string | null>(null);
  const programmatic = useRef(false);
  useEffect(() => {
    if (!target) {
      lastKey.current = null;
      return;
    }
    programmatic.current = true;
    if (lastKey.current !== target.key) {
      lastKey.current = target.key;
      // 588 — vol doux sur l'ami suivi : zoom 16, 0,8 s (comme un clic ami).
      // 612 — comme l'app : « Suivre » ne recule JAMAIS si l'on est déjà plus près.
      safeFly(map, [target.lat, target.lng], Math.max(map.getZoom(), FRIEND_ZOOM), 0.8);
    } else {
      try { map.panTo([target.lat, target.lng], { animate: true, duration: 0.8, easeLinearity: 0.3 }); } catch { /* animation en cours */ }
    }
    const done = () => { programmatic.current = false; };
    map.once("moveend", done);
    return () => { map.off("moveend", done); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [map, target?.lat, target?.lng, target?.key, target?.ts]);
  useMapEvents({
    dragstart() {
      if (target) onUserGesture();
    },
    zoomstart() {
      if (target && !programmatic.current) onUserGesture();
    },
  });
  return null;
}

/** 25/09 — un itinéraire reçu est cadré entièrement (on le VOIT). */
function RouteFit({ points, extra, join, token }: { points: { lat: number; lng: number }[] | null; extra?: ({ lat: number; lng: number } | null | undefined)[]; join?: boolean; token?: number }) {
  const map = useMap();
  // 613 — `token` (posé par la page à chaque NOUVEL itinéraire) : un recalcul silencieux
  // (la personne rejointe a bougé) ne recadre pas la carte.
  const key = points && points.length > 1 ? (token ? `t${token}` : `${points.length}-${points[0].lat}-${points[points.length - 1].lng}`) : "";
  useEffect(() => {
    if (!points || points.length < 2) return;
    try {
      map.stop();
      const all = [...points, ...((extra || []).filter(Boolean) as { lat: number; lng: number }[])];
      const b = L.latLngBounds(all.map((p) => [p.lat, p.lng] as [number, number]));
      // 613 (comme l'app) — « Rejoindre john » : Moi, john et le trajet cadrés dans la ZONE
      // LIBRE (entre les rails, sous les boutons du haut, au-dessus de la pilule + du bandeau),
      // marge d'une photo + étiquette (44 px). Zoom rue au plus.
      if (join) map.fitBounds(b, { paddingTopLeft: [62 + 44, 64 + 44], paddingBottomRight: [62 + 44, 150 + 44], maxZoom: 18 });
      else map.fitBounds(b, { paddingTopLeft: [70, 120], paddingBottomRight: [70, 40], maxZoom: 17 });
    } catch { /* carte pas prête */ }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);
  return null;
}

/**
 * 27/10 (ordre de Daniel, captures daniel_2710 ; règle 626 de PAM, même comportement que l'app) — toucher un
 * groupe = VOL animé vers le centre de l'emprise RÉELLE de ses membres, au zoom qui les montre tous dans la
 * zone utile (carte − 2 × 72 px en largeur, − 180 px en hauteur), au moins jusqu'au niveau où le groupe se
 * divise. Il ne se divise pas avant le zoom maximal (même endroit) ou on y est déjà : renvoie false → la liste.
 * Plus aucun anneau : un membre n'est jamais dessiné ailleurs qu'à sa place.
 */
function flyToGroup2710<T>(map: L.Map, items: T[], idOf: (t: T) => string, posOf: (t: T) => [number, number] | null, index: ClusterIndex2710<T> | null): boolean {
  const pts = items.map(posOf).filter((p): p is [number, number] => !!p);
  const sz = map.getSize();
  const exp = index ? index.expansionLevel(items.map(idOf), map.getZoom()) : null;
  const t = clusterTapTarget2710({ pts, w: Math.max(120, sz.x - 2 * 72), h: Math.max(160, sz.y - 180), currentZoom: map.getZoom(), expansionLevel: exp, maxZoom: map.getMaxZoom() });
  if (!t) return false;
  // Carte au demi-niveau (zoomSnap 0,5) : on arrondit vers le bas — l'emprise tient toujours, et jamais sous le
  // niveau où le groupe se divise (niveau = partie entière du zoom), donc il se divise bien à l'arrivée.
  const z = Math.min(map.getMaxZoom(), Math.max(Math.floor(t.zoom * 2) / 2, exp ?? 0));
  try { map.stop(); map.flyTo(L.latLng(t.center[0], t.center[1]), z, { duration: 0.8 }); } catch { safeFly(map, t.center, z, 0.8); }
  return true;
}
/** Type de lieu le plus représenté d'un groupe (couleur de l'anneau, comme l'app : `dominant`). */
function dominantPlace2710(items: Poi[]): PoiCategory | null {
  const n = new Map<PoiCategory, number>();
  for (const p of items) n.set(p.category, (n.get(p.category) || 0) + 1);
  let best: PoiCategory | null = null, bc = 0;
  for (const [c, k] of [...n.entries()].sort((a, b) => (a[0] < b[0] ? -1 : 1))) if (k > bc) { best = c; bc = k; }
  return best;
}
const poiPos2710 = (poi: Poi): [number, number] | null => (Array.isArray(poi.location?.coordinates) && poi.location.coordinates.length >= 2 ? [poi.location.coordinates[1], poi.location.coordinates[0]] : null);
const memberPos2710 = (m: NearbyMember): [number, number] | null => (Array.isArray(m.location?.coordinates) && m.location.coordinates.length >= 2 ? [m.location.coordinates[1], m.location.coordinates[0]] : null);
const spotPos2710 = (s: PawSpot): [number, number] => [s.lat, s.lng];
/** Lieux / PawSpots au même endroit : pas de liste sur le site → zoom maximal sur eux. */
function flyMax2710(map: L.Map, center: [number, number]) { safeFly(map, center, map.getMaxZoom(), 0.8); }
function PlaceCluster({ center, count, category, items, index, dark = false }: { center: [number, number]; count: number; category: PoiCategory | null; items: Poi[]; index: ClusterIndex2710<Poi>; dark?: boolean }) {
  const map = useMap();
  // 27/10 (parité app 625) — rond « Anneau » 48 px à la couleur du type dominant (plus de carré blanc).
  const icon = useMemo(() => L.divIcon({ className: "hps-l-pgroup", html: placeClusterHtml(count, category, dark), iconSize: [48, 48], iconAnchor: [24, 24] }), [count, category, dark]);
  return <Marker position={center} icon={icon} zIndexOffset={PIN_Z.place + 50} eventHandlers={{ click: () => { if (!flyToGroup2710(map, items, (p) => String(p._id), poiPos2710, index)) flyMax2710(map, center); } }} />;
}
/** Groupe de membres : toucher = vol (flyToGroup2710) ; même endroit (≤ 40 m, ou une seule personne) ou
 *  zoom maximal = la liste de ses membres. */
function MemberCluster({ center, items, onList, index, dark = false, shift }: { center: [number, number]; items: NearbyMember[]; onList: (l: NearbyMember[]) => void; index: ClusterIndex2710<NearbyMember>; dark?: boolean; shift?: Px }) {
  const map = useMap();
  const count = items.length;
  // 2610 — anneau segmenté proportionnel aux rôles (maquette de l'app, README §3).
  const counts = roleCounts(items.map((m) => m.role));
  const countsKey = `${counts.owner}/${counts.sitter}/${counts.walker}`;
  const sx = Math.round(shift?.x ?? 0);
  const sy = Math.round(shift?.y ?? 0);
  const icon = useMemo(() => cachedIcon2610(`mgroup|${countsKey}|${count}|${dark ? 1 : 0}|${sx},${sy}`, () => L.divIcon({ className: "hps-l-mgroup", html: clusterHtml2610({ counts, total: count, dark, fromLabel: null }), iconSize: [48, 48], iconAnchor: [24 - sx, 24 - sy] })), [count, countsKey, dark, sx, sy]);
  const onClick = () => {
    // Même règle que l'app (pawMapClusterIsStacked : 40 m, ou la même personne) : zoomer ne les séparerait pas.
    if (isStackedGroup(items, 40)) { onList(items); return; }
    if (!flyToGroup2710(map, items, (m) => String(m.id), memberPos2710, index)) onList(items);
  };
  return <Marker position={center} icon={icon} zIndexOffset={PIN_Z.member} eventHandlers={{ click: onClick }} />;
}
function SpotCluster({ center, count, items, index }: { center: [number, number]; count: number; items: PawSpot[]; index: ClusterIndex2710<PawSpot> }) {
  const map = useMap();
  const icon = useMemo(() => L.divIcon({ className: "hps-l-sgroup", html: spotClusterHtml(count), iconSize: [36, 36], iconAnchor: [18, 18] }), [count]);
  return <Marker position={center} icon={icon} zIndexOffset={PIN_Z.spot} eventHandlers={{ click: () => { if (!flyToGroup2710(map, items, (x) => String(x.id), spotPos2710, index)) flyMax2710(map, center); } }} />;
}

/** Libellés du suivi en direct (fournis par la page, 9 langues). */
export type LiveLabels = {
  live: string;
  lost: string;
  follow: string;
  message: string;
  seenAgo: string;
  seenNow: string;
  notSharing: string;
  profileApprox: string;
  viewProfile: string;
  ago: (ms: number) => string;
};

/**
 * Ami qui PARTAGE (état vrai du serveur) : sa photo, anneau rose ; « signal
 * perdu » sous le rond entre 2 et 10 min ; auréole violette qui respire s'il
 * est suivi. Un clic ouvre SA fiche (carte du bas, jamais une bulle rognée à
 * 375 px) : « Suivre la balade · en direct », Itinéraire, Message.
 */
function LiveFriendMarker({ p, isFamily, isPremium, boosted, roles, followed, labels, onOpen }: {
  p: FriendLivePosition;
  isFamily: boolean;
  isPremium?: boolean;
  /** 27/09 — PawBoost de la personne (n'importe lequel de ses rôles, lu sur les couches membres). */
  boosted?: boolean;
  /** 27/09 — tous ses rôles : contour bi/tricolore. */
  roles?: string[];
  followed: boolean;
  labels?: LiveLabels;
  onOpen: () => void;
}) {
  const lost = p.state === "lost";
  const icon = useMemo(
    () => L.divIcon({
      className: "hps-l-friend",
      html: photoPinHtml({ role: p.role, name: p.name, avatar: p.avatar, premium: isPremium, boosted, roles, pawFollow: isFamily && !followed, followed, lost, caption: lost ? labels?.lost : null, online: lost ? false : true }),
      iconSize: [50, 50],
      iconAnchor: [25, 25],
    }),
    [p.role, p.name, p.avatar, isPremium, boosted, (roles || []).join(","), isFamily, followed, lost, labels?.lost],
  );
  return <Marker position={[p.lat, p.lng]} icon={icon} zIndexOffset={followed ? PIN_Z.me + 500 /* 612 — comme l'app : la personne suivie passe AU-DESSUS de « Moi » */ : PIN_Z.friend} eventHandlers={{ click: onOpen }} />;
}

/** Libellés de la fiche membre (9 langues, fournis par la page). */
export type CardLabels = {
  /** 586 (point 8) — réserver avec le profil propriétaire. */
  bookAsOwner?: string;
  switchingOwner?: string;
  switchOwnerError?: string;
  book: string;
  priceFrom: string;
  addFriend: string;
  sent: string;
  already: string;
  failed: string;
  approx: string;
  verified: string;
  viewProfile: string;
  directions: string;
  message: string;
  friend: string;
  chooseProfile: string;
  profilesHere: string;
  see: string;
  distance: string;
  back: string;
  close: string;
  /** Langue du site (séparateur décimal des distances). */
  lang?: string;
};

/** 590 — libellés de la carte focus (9 langues, fournis par la page). */
export type FocusLabels = {
  profile: string;
  close: string;
  request: string;
  walking: string;
  roles: Record<string, string>;
  sitting: string;
  walk: string;
  /** 02/10 (609) — « Vérifié ». */
  verified?: string;
};

/** 590 (§4) — la carte focus : 1er clic sur une personne ou une demande. */
type Focus = {
  key: string;
  lat: number;
  lng: number;
  name: string;
  /** owner | sitter | walker (anneau + bouton « Profil »). */
  role: string;
  /** 27/09 — TOUS les rôles de la personne : bouton « Profil » (et anneau hors
   *  ami) bicolore / tricolore, ordre fixe propriétaire → gardien → promeneur. */
  roles?: string[];
  avatar?: string | null;
  info: string;
  live?: boolean;
  friend?: boolean;
  icon?: "home" | "walk" | "paw";
  /** Ami en direct : son tracé de balade s'affiche. */
  liveId?: string;
  /** 02/10 (609) — identité vérifiée : pastille « ✓ Vérifié ». */
  verified?: boolean;
  /** 04/10 (611) — rang de la personne (Chiot → Légende) ; null = rien affiché. */
  rank?: Rank611 | null;
  /** 19/10 (618) — pins podium / « 1er Chef de meute » ; null = rien affiché. */
  pins?: Pins1910 | null;
  open: () => void;
};

// §9 — palettes « bijou » des rôles (clair, moyen, foncé) + rose ami.
const JEWEL_ROLE: Record<string, [string, string, string]> = {
  owner: ["#D9442C", "#C92A12", "#B8231A"],
  sitter: ["#8AB8FF", "#3B78E8", "#1F4FBF"],
  walker: ["#7FE39A", "#2E9E48", "#1D7A34"],
  friend: ["#F47BB2", "#E35A9A", "#D6377F"],
};
const jewelGrad = (p: [string, string, string]) => `linear-gradient(170deg,${p[0]},${p[1]} 50%,${p[2]})`;
const ROLE_ORDER = ["owner", "sitter", "walker"] as const;
/** 27/09 (règle Daniel 26/09, comme l'app 594) — 1 rôle = son dégradé ;
 *  2 ou 3 rôles = dégradé horizontal des rôles, ordre fixe orange → bleu → vert. */
function rolesGrad(roles: string[] | undefined, fallback: [string, string, string]): string {
  const ks = ROLE_ORDER.filter((k) => (roles || []).includes(k));
  if (ks.length < 2) return jewelGrad(fallback);
  const n = ks.length;
  const stops = ks.flatMap((k, i) => {
    const c = JEWEL_ROLE[k][1];
    const a = (i / n) * 100 + (i ? 6 : 0);
    const b = ((i + 1) / n) * 100 - (i < n - 1 ? 6 : 0);
    return [`${c} ${a.toFixed(0)}%`, `${c} ${b.toFixed(0)}%`];
  });
  return `linear-gradient(90deg,${stops.join(",")})`;
}

/** Efface la carte focus au clic sur la carte vide ou au début d'un glisser. */
// 611 — contenu de la bulle d'un signalement, avec la confirmation gratuite.
function ReportPopupBody({ r, label, onConfirm, labels }: {
  r: MapReport;
  label: string;
  onConfirm?: (id: string) => Promise<number | null>;
  labels?: { lostSeen: string; confirm: string; lostThanks: string; extended: string; failed: string };
}) {
  const [state, setState] = useState<"idle" | "busy" | "done" | "fail">("idle");
  const [count, setCount] = useState<number | null>(typeof r.confirmationsCount === "number" ? r.confirmationsCount : null);
  const lost = r.type === "lost_pet";
  return (
    <div className="text-sm" style={{ minWidth: 170 }} data-report-popup={r._id}>
      <div className="mb-1 font-bold" style={{ color: "#D32F2F" }}>{label}</div>
      {r.note ? <div className="mb-1 text-xs text-ink-muted">{r.note}</div> : null}
      {count !== null ? <div className="text-xs text-ink-muted">✓ {count}</div> : null}
      {onConfirm && labels && state !== "done" && (
        <button
          type="button"
          data-report-confirm=""
          disabled={state === "busy"}
          onClick={async () => {
            setState("busy");
            try {
              const n = await onConfirm(r._id);
              if (typeof n === "number") setCount(n);
              setState("done");
            } catch {
              setState("fail");
            }
          }}
          className="mt-2 min-h-[40px] w-full rounded-full px-3 text-[13px] font-bold text-white shadow-sm transition active:scale-[0.98] disabled:opacity-60"
          style={{ background: lost ? "linear-gradient(180deg,#F0569A,#D6246E)" : "linear-gradient(180deg,#E0553F,#C92A12)" }}
        >
          {state === "busy" ? "…" : lost ? labels.lostSeen : labels.confirm}
        </button>
      )}
      {state === "done" && labels && <div data-report-confirmed="" className="mt-2 text-xs font-semibold" style={{ color: "#15803D" }}>{lost ? labels.lostThanks : labels.extended}</div>}
      {state === "fail" && labels && <div className="mt-1 text-xs font-semibold" style={{ color: "#B42318" }}>{labels.failed}</div>}
    </div>
  );
}

function FocusWatcher({ onClear, onReset }: { onClear: () => void; onReset?: () => void }) {
  // 2610 — clic dans le vide = bulle masquée ET caméra remise comme avant ; glisser = bulle masquée.
  useMapEvents({ click: onReset ?? onClear, dragstart: onClear });
  return null;
}

/**
 * 590 — fiche d'une DEMANDE, ouverte au 2e clic (popup Leaflet posée seule
 * sur la carte ; position mémorisée sinon react-leaflet la rouvre à chaque
 * rendu).
 */
function RequestPopup({ r, onClose, children }: { r: MapRequest; onClose: () => void; children: React.ReactNode }) {
  const map = useMap();
  const ref = useRef<L.Popup | null>(null);
  const pos = useMemo(() => [r.lat, r.lng] as [number, number], [r.lat, r.lng]);
  const closeRef = useRef(onClose);
  closeRef.current = onClose;
  useEffect(() => {
    const h = (e: L.PopupEvent) => { if (e.popup === ref.current) closeRef.current(); };
    map.on("popupclose", h);
    return () => { map.off("popupclose", h); };
  }, [map]);
  return <Popup ref={ref} position={pos} offset={[0, -36]}>{children}</Popup>;
}

/** 588 — zoom d'un clic sur un ami (liste, pilule ou rond) : rue lisible. */
const FRIEND_ZOOM = 16;

/** Ce que la carte du bas montre. */
type Sheet =
  | { kind: "person"; m: NearbyMember }
  | { kind: "role"; m: NearbyMember; r: PersonRole; back?: Sheet }
  | { kind: "list"; items: NearbyMember[] }
  | { kind: "live"; p: FriendLivePosition };

const PLUSH_TYPES_607 = ["teddy", "bunny", "kitty", "puppy", "fox"];
const plushIconCache = new Map<string, L.DivIcon>();
/** Icône d'une mini-peluche (PNG 192 px de PAM affiché à 40 px, dorée à 46 px), qui flotte doucement. */
function plushIcon(type: string, golden: boolean): L.DivIcon {
  const t = PLUSH_TYPES_607.includes(type) ? type : "teddy";
  const key = `${t}${golden ? "_gold" : ""}`;
  const hit = plushIconCache.get(key);
  if (hit) return hit;
  const sz = golden ? 46 : 40;
  const icon = L.divIcon({
    className: "hps-l-plush",
    html: `<img src="/plush/${key}.png" alt="" width="${sz}" height="${sz}" data-plush="${key}" style="display:block;width:${sz}px;height:${sz}px;object-fit:contain;filter:drop-shadow(0 4px 6px rgba(23,20,31,.35));animation:hps-plush-float 2.6s ease-in-out infinite"/>`,
    iconSize: [sz, sz],
    iconAnchor: [sz / 2, sz / 2],
    popupAnchor: [0, -sz / 2],
  });
  plushIconCache.set(key, icon);
  return icon;
}

export default function PoiMap({
  center,
  initialZoom = 13,
  pois,
  userLocation,
  selectedPoi,
  onSelectPoi,
  onMapMove,
  onZoomChange,
  spots = [],
  spotTypeLabels,
  reports = [],
  reportTypeLabels,
  members: membersRaw = [],
  memberRoleLabels,
  cardLabels,
  wantedRoles = ["sitter", "walker", "owner"],
  distanceFrom = null,
  onMapReady,
  satellite = false,
  onAddFriend,
  onReportConfirm,
  reportConfirmLabels,
  onSpotVisit,
  friendPositions = [],
  liveIdsAll = [],
  familyIds = [],
  premiumIds = [],
  roleLabels,
  userRole = "sitter",
  userName = "",
  userAvatarUrl,
  userIsPremium,
  userBoosted,
  userPawFollow,
  userFriendsOnly,
  userAccuracy,
  meLabel = "Moi",
  positionLabel = "",
  accuracyLabel = "",
  focusTarget = null,
  onFriendFocus,
  followUserId = null,
  onFollowPause,
  followLabel,
  routePoints = null,
  routeColor = "#C92A12",
  routeSteps = null,
  routeFrom = null,
  joinTo = null,
  followCamHold = false,
  routeFitToken = 0,
  onDirections,
  directionsLabel = "→",
  formatOpenStatus,
  callLabel = "",
  requests = [],
  plushies = [],
  plushLabels,
  requestLabels,
  onOfferService,
  dark = false,
  onBoundsChange,
  friendIds = [],
  friendSeen = {},
  followHaloId = null,
  liveLabels,
  now = 0,
  onMessage,
  onMessageMember,
  focusFriend = null,
  focusLabels,
  focusTop = 64,
  uiFade = false,
}: {
  center: [number, number];
  /** Zoom d'ouverture (mémorisé par la page). */
  initialZoom?: number;
  pois: Poi[];
  userLocation?: { lat: number; lng: number } | null;
  selectedPoi?: Poi | null;
  onSelectPoi?: (poi: Poi) => void;
  onMapMove?: (center: { lat: number; lng: number }) => void;
  onZoomChange?: (zoom: number) => void;
  spots?: PawSpot[];
  spotTypeLabels?: Partial<Record<PawSpotType, string>>;
  reports?: MapReport[];
  reportTypeLabels?: Partial<Record<MapReportType, string>>;
  members?: NearbyMember[];
  memberRoleLabels?: Record<string, string>;
  /** 25/09 (585) — fiche membre / choix du rôle / liste d'un groupe. */
  cardLabels?: CardLabels;
  /** Rôles cochés dans « Je cherche » (le liseré principal et les listes). */
  wantedRoles?: string[];
  /** D'où l'on mesure les distances (ma position, sinon le centre regardé). */
  distanceFrom?: { lat: number; lng: number } | null;
  /** La page garde la carte pour ses propres boutons (zoom, ma position). */
  onMapReady?: (map: L.Map) => void;
  /** Fond satellite (Esri World Imagery, sans clé). */
  satellite?: boolean;
  onAddFriend?: (m: NearbyMember) => Promise<"sent" | "already" | "error">;
  onSpotVisit?: (id: string) => void;
  /** 611 — confirmer un signalement (gratuit pour tous, comme l'app) :
   *  « J'ai vu cet animal » sur un animal perdu, « Confirmer +12h » ailleurs. */
  onReportConfirm?: (id: string) => Promise<number | null>;
  reportConfirmLabels?: { lostSeen: string; confirm: string; lostThanks: string; extended: string; failed: string };
  friendPositions?: FriendLivePosition[];
  /** 587 — ids (tous rôles) des amis qui partagent en direct. */
  liveIdsAll?: string[];
  familyIds?: string[];
  premiumIds?: string[];
  roleLabels?: Partial<Record<Role, string>>;
  /** « Moi » : rôle (anneau), nom, photo, couronne, boost, mode amis. */
  userRole?: string;
  userName?: string;
  userAvatarUrl?: string | null;
  userIsPremium?: boolean;
  userBoosted?: boolean;
  userPawFollow?: boolean;
  userFriendsOnly?: boolean;
  userAccuracy?: number | null;
  meLabel?: string;
  positionLabel?: string;
  accuracyLabel?: string;
  focusTarget?: { lat: number; lng: number; ts: number; zoom?: number; /** 612 — zoom plancher : on s'en approche, on ne recule jamais si l'on est déjà plus près (suivi). */ minZoom?: number; duration?: number } | null;
  onFriendFocus?: (p: FriendLivePosition) => void;
  /** Ami suivi en direct (zoom de suivi « joli »). */
  followUserId?: string | null;
  onFollowPause?: () => void;
  followLabel?: string;
  routePoints?: { lat: number; lng: number }[] | null;
  routeColor?: string;
  routeSteps?: RouteStep[] | null;
  /** 613 — départ de l'itinéraire (ma position au calcul) : trait plein de Moi au début du trajet. */
  routeFrom?: { lat: number; lng: number } | null;
  /** 613 — « Rejoindre john » : position ACTUELLE de john (trait plein de la fin du trajet à sa photo, cadrage). */
  joinTo?: { lat: number; lng: number } | null;
  /** 613 — pendant « Rejoindre », la caméra du suivi ne recolle plus sur john (Moi reste à l'écran). */
  followCamHold?: boolean;
  /** 613 — change à chaque nouvel itinéraire (cadrage) ; inchangé au recalcul silencieux. */
  routeFitToken?: number;
  onDirections?: (target: { lat: number; lng: number; friendId?: string }) => void;
  directionsLabel?: string;
  formatOpenStatus?: (raw: string) => { label: string; open: boolean } | null;
  callLabel?: string;
  /** Demandes des propriétaires (bulle orange), positions floutées par la page. */
  requests?: MapRequest[];
  /** 02/10 (607) — mini-peluches de MA Balade (le serveur ne les renvoie que pendant une Balade). */
  plushies?: { id: string; type: string; golden?: boolean; lat: number; lng: number }[];
  plushLabels?: { title: string; hint: string };
  requestLabels?: { title: string; mine: string; offer: string; sitting: string; walk: string };
  onOfferService?: (id: string) => void;
  /** Mode sombre : fond de carte sombre, épingles gardent leur liseré blanc. */
  dark?: boolean;
  /** 25/09 — zone visible (compteur + état vide de la page). */
  onBoundsChange?: (b: { s: number; w: number; n: number; e: number }) => void;
  /** Ids de mes amis (tous rôles) : leur point de profil = anneau rose. */
  friendIds?: string[];
  /** Dernier passage de chaque ami (`other.lastSeenAt` de /friends). */
  friendSeen?: Record<string, string | null | undefined>;
  /** Ami suivi (auréole violette, même quand le suivi est en pause). */
  followHaloId?: string | null;
  liveLabels?: LiveLabels;
  /** Horloge de la page (âge « en direct · 12 s »). */
  now?: number;
  onMessage?: (who: { id: string; role: string; name: string }) => void;
  /** Message à un membre (non ami) : renvoie l'action, ou null si impossible. */
  onMessageMember?: (m: NearbyMember) => (() => void) | null;
  /** 588 — ami (hors direct) choisi dans le panneau : vol doux + sa fiche. */
  focusFriend?: { m: NearbyMember; ts: number } | null;
  /** 590 — carte focus (1er clic) : libellés, hauteur sous la rangée du haut. */
  focusLabels?: FocusLabels;
  focusTop?: number;
  /** 590 — la carte bouge : la carte focus passe à 20 % comme les barres. */
  uiFade?: boolean;
}) {
  // 30/09 (605) — unités « /sem », « /mois » de la bulle de prix (9 langues).
  const { t: tUnits, lang: langUnits } = useT();
  const priceUnits = priceUnitLabels(tUnits, langUnits);
  // 622 (25/10, Daniel : « il n'y a pas beaucoup les prix ») — tarif effectif de chaque membre :
  // `priceFrom`, sinon le plus petit tarif réel de `prices` (jamais inventé).
  const members = useMemo(() => membersRaw.map((m) => normalizeMemberPrices622(m)), [membersRaw]);
  /** « dès 10 €/jour » ; en japonais le « から » suit le prix (« 10 €/日～ »). */
  const fromText622 = useFromText622();
  // 622 — demandes SANS budget : « dès 10 €/jour » lu sur POST /pricing/estimate/public, UN appel par
  // service / devise / zone d'~50 km, au plus BUBBLE_ESTIMATE_MAX_622 par carte (route limitée à 30/min).
  const reqFromItems = useMemo(() => requests.map((r) => (r.priceLabel || r.mine ? null : r.pricing ?? null)), [requests]);
  const reqFromLabel = useRequestFromLabels622(reqFromItems);
  const reqFromOf = (r: MapRequest): string | null => (r.priceLabel || r.mine ? null : reqFromLabel(r.pricing));
  const familySet = useMemo(() => new Set(familyIds), [familyIds]);
  const friendSet = useMemo(() => new Set(friendIds), [friendIds]);
  const liveIdSet = useMemo(() => new Set([...friendPositions.map((p) => p.userId), ...liveIdsAll]), [friendPositions, liveIdsAll]);
  const [sheet, setSheet] = useState<Sheet | null>(null);
  const premiumSet = useMemo(() => new Set(premiumIds), [premiumIds]);
  const userIcon = useMemo(
    () => meIcon({ role: userRole, name: userName, avatar: userAvatarUrl, premium: userIsPremium, meLabel, friendsOnly: userFriendsOnly, boosted: userBoosted, pawFollow: userPawFollow }),
    [userRole, userName, userAvatarUrl, userIsPremium, meLabel, userFriendsOnly, userBoosted, userPawFollow],
  );

  const [zoomLevel, setZoomLevel] = useState(initialZoom);
  const handleZoom = (z: number) => {
    setZoomLevel(z);
    onZoomChange?.(z);
  };
  // 607 — seuils de l'app : prénom + prix au zoom rue (13, `_priceZoom`) ;
  // dès le zoom ville (9, `_cityPriceZoom`) une épingle SEULE porte déjà sa
  // bulle si la place est libre au-dessus d'elle (décision de BOB, réversible
  // dans lib/pawmapOverlap607.ts).
  const showPrice = zoomLevel >= PRICE_ZOOM_607;
  // 622 (25/10, Daniel : « il n'y a pas beaucoup les prix ») — bulles et « dès X » des groupes dès le zoom
  // PAYS (6) au lieu du zoom ville (9) ; la passe 622 garantit qu'aucune bulle n'en chevauche une autre.
  const cityZoom = !showPrice && zoomLevel >= Math.min(CITY_PRICE_ZOOM_607, PRICE_ZOOM_COUNTRY_622);
  // 590 (§1, §4) — au zoom rue : le PRÉNOM sous le rond ; le prix part dans
  // une bulle à la couleur du service AU-DESSUS du rond, seulement s'il est
  // de l'autre côté du marché (propriétaire → tarifs ; prestataire → rien).
  const memberCaption = (m: NearbyMember): string | null => {
    if (!showPrice) return null;
    const first = (m.name || "").trim().split(/\s+/)[0];
    return first || memberRoleLabels?.[m.role] || null;
  };
  // 620 — `unit` (day | visit | walk…) envoyé par le serveur selon le service : « 12 €/visite ».
  const priceFor = (role: string, amount?: number | null, currency?: string | null, alt?: PriceAlt | null, unit?: string | null): string | null => {
    const k = roleKey(role);
    if (k === "owner" || !showsPriceBubble(userRole, k)) return null;
    // 605 — sans tarif jour / heure : « 100 €/sem » ou « 350 €/mois ».
    return formatPriceUnit(amount, currency, alt, priceUnits, unit);
  };
  // 26/10 (2610, maquette de l'app) — AUCUN prix sur la carte par défaut : la bulle n'existe que sur
  // le rond touché (`selectedPrices2610`). Remplace l'affichage permanent du 622.
  void cityZoom;
  const memberBubble = (role: string, amount?: number | null, currency?: string | null, alt?: PriceAlt | null, unit?: string | null, selected = false): string | null =>
    selected ? priceFor(role, amount, currency, alt, unit) : null;
  // 27/09 — gardien ET promeneur parmi les rôles montrés (filtre compris) :
  // les deux prix, gardien d'abord. Sinon null → bulle simple habituelle.
  const duoPrices = (roles: PersonRole[]): [string, string] | null => {
    const s = roles.find((r) => roleKey(r.role) === "sitter");
    const w = roles.find((r) => roleKey(r.role) === "walker");
    if (!s || !w) return null;
    const ps = priceFor("sitter", s.priceFrom, s.currency, s.priceAlt, s.priceUnit);
    const pw = priceFor("walker", w.priceFrom, w.currency, w.priceAlt, w.priceUnit);
    return ps && pw ? [ps, pw] : null;
  };
  const memberDuo = (roles: PersonRole[], selected = false): [string, string] | null => (selected ? duoPrices(roles) : null);
  /** 2610 — `visiblePrices` : un segment par rôle de L'AUTRE côté du marché (rôle actif du spectateur). */
  const selectedPrices2610 = (roles: PersonRole[], m: NearbyMember): Price2610[] => {
    const allowed = visibleRoles2610(userRole);
    const out: Price2610[] = [];
    for (const r of roles) {
      const k = role2610(r.role);
      if (!allowed.includes(k) || out.some((x) => x.role === k)) continue;
      if (k === "owner") {
        // Gardien / promeneur → budget de la demande de ce propriétaire (déjà chargée par la page).
        const ids = new Set([...personIdsOf(m), r.id].map(String));
        const b = ownerBudget2610(ids);
        if (b) out.push({ role: "owner", ...splitPrice2610(b) });
        continue;
      }
      const label = formatPriceUnit(r.priceFrom ?? (roles.length === 1 ? m.priceFrom : null), r.currency ?? m.currency, (r.priceAlt as PriceAlt | null) ?? (roles.length === 1 ? m.priceAlt : null) ?? null, priceUnits, r.priceUnit ?? (roles.length === 1 ? m.priceUnit : null));
      if (label) out.push({ role: k, ...splitPrice2610(label) });
    }
    return out;
  };
  /** 2610 — budget le plus bas parmi les demandes ouvertes d'un propriétaire (saisi, sinon « dès X »). */
  const ownerBudget2610 = (ids: Set<string>): string | null => {
    let best: { n: number; label: string } | null = null;
    for (const rq of requests) {
      if (rq.mine || !rq.ownerId || !ids.has(String(rq.ownerId))) continue;
      const label = rq.priceLabel || reqFromOf(rq);
      if (!label) continue;
      const n = parseFloat(label.replace(/[^0-9.,]/g, "").replace(",", ".")) || Infinity;
      if (!best || n < best.n) best = { n, label };
    }
    return best ? best.label : null;
  };


  // 27/10 (règle 626, même règle que l'app) — lieux : index hiérarchique stable (56 px), groupe posé sur un vrai lieu.
  const poiIndex = useMemo(() => clusterIndex2710(pois, (poi) => String(poi._id), poiPos2710), [pois]);
  const poiPos = poiPos2710;
  const poiClusters = useMemo(() => poiIndex.at(zoomLevel).map((g) => ({ items: g.items, center: poiPos2710(g.anchor)!, key: g.key })), [poiIndex, zoomLevel]);
  // 587 (point 6) — les AMIS ne sont jamais regroupés avec des inconnus :
  // exclus du regroupement, dessinés un par un au-dessus des membres, à
  // tous les zooms, sans plafond.
  const friendMembers = useMemo(() => members.filter((m) => isFriendMember(m, friendSet)), [members, friendSet]);
  // 27/09 — la personne (couche membres) derrière un ami en direct : son
  // PawBoost et ses rôles, comme dans l'app (_personBoosted).
  const liveOwnerOf = (uid: string): NearbyMember | undefined => {
    const k = String(uid).toLowerCase();
    return members.find((m) => personIdsOf(m).some((x) => String(x).toLowerCase() === k));
  };
  const otherMembersAll = useMemo(() => members.filter((m) => !isFriendMember(m, friendSet)), [members, friendSet]);
  // 26/10 (2610) — groupe ÉCLATÉ : ses membres sortent du regroupement et se posent autour de lui.
  const [spider, setSpider] = useState<{ ids: string[]; center: [number, number]; key: string } | null>(null);
  const spiderSet = useMemo(() => new Set(spider?.ids ?? []), [spider]);
  const otherMembers = useMemo(() => otherMembersAll.filter((m) => !spiderSet.has(m.id)), [otherMembersAll, spiderSet]);
  const spiderMembers = useMemo(() => {
    if (!spider) return [] as NearbyMember[];
    const byId = new Map(otherMembersAll.map((m) => [m.id, m] as const));
    return spider.ids.map((id) => byId.get(id)).filter((m): m is NearbyMember => !!m);
  }, [spider, otherMembersAll]);
  // 27/10 — regroupement STABLE (règle 626 de PAM, lib/pawmapGroups2710) : index hiérarchique calculé une
  // fois par jeu de données ; niveau = partie entière du zoom ; groupe posé sur son membre le plus central.
  // Même zoom + mêmes données = mêmes groupes, quel que soit le chemin ou l'ordre d'arrivée des données.
  const memberIndex = useMemo(() => clusterIndex2710(otherMembers, (m) => String(m.id), memberPos2710), [otherMembers]);
  const memberClusters = useMemo(() => memberIndex.at(zoomLevel).map((g) => ({ items: g.items, center: memberPos2710(g.anchor)!, key: g.key })), [memberIndex, zoomLevel]);
  const spotIndex = useMemo(() => clusterIndex2710(spots, (s) => String(s.id), spotPos2710, (z) => (z >= 13 ? 18 : 44)), [spots]);
  const spotClusters = useMemo(() => spotIndex.at(zoomLevel).map((g) => ({ items: g.items, center: [g.anchor.lat, g.anchor.lng] as [number, number], key: g.key })), [spotIndex, zoomLevel]);

  // Suivi : point suivi + tracé violet (positions reçues, en mémoire de la session).
  const trails = useRef<Map<string, [number, number][]>>(new Map());
  const followed = followUserId ? friendPositions.find((p) => p.userId === followUserId) : undefined;
  useEffect(() => {
    if (!followed) return;
    const arr = trails.current.get(followed.userId) || [];
    const last = arr[arr.length - 1];
    if (!last || Math.abs(last[0] - followed.lat) > 1e-6 || Math.abs(last[1] - followed.lng) > 1e-6) {
      arr.push([followed.lat, followed.lng]);
      if (arr.length > 500) arr.shift();
      trails.current.set(followed.userId, arr);
    }
  }, [followed]);
  const followTarget = useMemo(
    () => (followed && !followCamHold ? { lat: followed.lat, lng: followed.lng, key: followed.userId } : null),
    [followed?.lat, followed?.lng, followed?.userId, followCamHold],
  );
  const trail = followUserId ? trails.current.get(followUserId) || [] : [];

  const requestMineLabel = requestLabels?.mine || "";

  // ── 607 (PAM) — ce qui est posé à l'écran, en px, pour que les pastilles
  // s'écartent de Moi / des amis, que « Vu il y a » ne se pose sur rien et
  // qu'une bulle de prix de zoom ville n'apparaisse que si la place est libre.
  // Même ordre et mêmes rayons que paw_map_screen.dart. Calcul simple (pas de
  // hook) : refait à chaque rendu, dans l'ordre de dessin des épingles.
  const lay = (() => {
    const pxOf = (p: [number, number]) => mercatorPx(p[0], p[1], zoomLevel);
    const meRects: Rect[] = [];
    const POP0 = "700 11.5px Poppins, Inter, system-ui, sans-serif";
    const bubbleW0 = (bubble: string | null, duo: [string, string] | null): number =>
      duo
        ? textWidth(duo[0], POP0, 11.5) + textWidth(duo[1], POP0, 11.5) + textWidth("·", POP0, 11.5) + 16 + 22 + 12
        : textWidth(bubble || "", POP0, 11.5) + 16 + 15;
    // 02/10 (607, PAM v2 — CONTRAT_607_bulles §3) : collision par BOÎTES RÉELLES.
    const meAt: Px | null = userLocation ? pxOf([userLocation.lat, userLocation.lng]) : null;
    const meW = textWidth(meLabel || "Moi", "700 11px Inter, system-ui, sans-serif", 11) + 16;
    const meBox = pinBox(56 / 2 + 2, { labelW: meW, labelH: 16.3, labelGap: 3 });
    if (meAt) meRects.push(circleRect(meAt, 56 / 2 + 2), labelRect(meAt, 56 / 2, meW, "below", 16.3));
    const friendBox = pinBox(50 / 2 + 2.5);
    const entries: { items: NearbyMember[]; c: Px; r: number; friend: boolean }[] = [];
    for (const g of memberClusters) entries.push({ items: g.items, c: pxOf(g.center), r: g.items.length > 1 ? 24 + 2.5 : 50 / 2 + 1 + (showPrice ? 10 : 0), friend: false });
    for (const m of friendMembers) { const p = pointOf(m); if (p) entries.push({ items: [m], c: pxOf(p), r: 50 / 2 + 2, friend: true }); }
    // A. Amis trop près de « Moi » : décalés en éventail (un trait rose relie leur vraie position).
    const friendIdx = entries.map((e, i) => (e.friend ? i : -1)).filter((i) => i >= 0);
    const fanAt: Px[] = [...friendPositions.map((fp) => pxOf([fp.lat, fp.lng])), ...friendIdx.map((i) => entries[i].c)];
    const fanShift: Px[] = meAt ? repelBoxes(fanAt, fanAt.map(() => friendBox), [{ at: meAt, box: meBox }]) : fanAt.map(() => ({ x: 0, y: 0 }));
    const fixedBoxes: PlacedBox[] = [...(meAt ? [{ at: meAt, box: meBox }] : []), ...fanAt.map((p, k) => ({ at: { x: p.x + fanShift[k].x, y: p.y + fanShift[k].y }, box: friendBox }))];
    // B. Pastilles et membres seuls (jamais un ami) : place libre la plus proche (prénom et bulle compris).
    const boxOf = (e: { items: NearbyMember[] }): Rect => {
      if (e.items.length > 1) {
        // 2610 — « dès X » masqué tant que le groupe n'est pas touché : seul le rond (48 px) compte.
        return pinBox(24 + 2.5);
      }
      const m = e.items[0];
      const wanted = rolesMatching(m, wantedRoles);
      const roles = wanted.length ? [...wanted, ...rolesOf(m).filter((r) => !wanted.some((w) => sameRole(w, r)))] : rolesOf(m);
      const shown = wanted.length ? wanted : roles;
      const r0 = roles[0];
      const cap = memberCaption({ ...m, role: r0.role });
      const lw = showPrice && cap ? textWidth(cap, "700 11px Inter, system-ui, sans-serif", 11) + 16 : 0;
      let bw = 0;
      if (showPrice || cityZoom) {
        const duo = memberDuo(shown);
        const bubble = memberBubble(r0.role, r0.priceFrom ?? m.priceFrom, r0.currency ?? m.currency, r0.priceAlt ?? m.priceAlt, r0.priceUnit ?? m.priceUnit);
        if (duo || bubble) bw = bubbleW0(bubble, duo) + 4;
      }
      return pinBox(46 / 2 + 1, { labelW: lw, bubbleW: bw });
    };
    const movable = entries.map((e) => !e.friend);
    const moved = repelBoxes(entries.map((e) => e.c), entries.map((e) => (e.friend ? friendBox : boxOf(e))), fixedBoxes, movable);
    const shifts: Px[] = entries.map((e, i) => (e.friend ? fanShift[friendPositions.length + friendIdx.indexOf(i)] : moved[i]));
    entries.forEach((e, i) => { e.c = { x: e.c.x + shifts[i].x, y: e.c.y + shifts[i].y }; });
    /** Amis en direct décalés en éventail : nouvelle position (la personne suivie n'est jamais décalée, voir `trackedId`). */
    const liveFan = new Map<string, { pos: [number, number]; from: [number, number] }>();
    friendPositions.forEach((fp, k) => {
      const sh = fanShift[k];
      if (Math.hypot(sh.x, sh.y) < 0.5) return;
      liveFan.set(fp.userId, { pos: mercatorToLatLng({ x: fanAt[k].x + sh.x, y: fanAt[k].y + sh.y }, zoomLevel), from: [fp.lat, fp.lng] });
    });
    // 612 — plus de trait rose vers la vraie position (retiré de l'app le 05/10).
    const indexOf = new Map<NearbyMember, number>();
    entries.forEach((e, i) => { if (e.items.length === 1) indexOf.set(e.items[0], i); });
    const placed: Rect[] = [];
    const near = (a: Px, b: Px) => Math.abs(a.x - b.x) < 260 && Math.abs(a.y - b.y) < 260;
    const obstaclesBut = (self: number): Rect[] => {
      const c = entries[self].c;
      const out: Rect[] = [...meRects];
      entries.forEach((e, j) => { if (j !== self && near(c, e.c)) out.push(circleRect(e.c, e.r)); });
      out.push(...placed);
      return out;
    };
    const POP = "700 11.5px Poppins, Inter, system-ui, sans-serif";
    const bubbleW = (bubble: string | null, duo: [string, string] | null): number =>
      duo
        ? textWidth(duo[0], POP, 11.5) + textWidth(duo[1], POP, 11.5) + textWidth("·", POP, 11.5) + 16 + 22 + 12
        : textWidth(bubble || "", POP, 11.5) + 16 + 15;
    /** Bulle(s) de prix d'une épingle seule, retirées au zoom ville sans place. */
    const priceFit = (m: NearbyMember, bubble: string | null, duo: [string, string] | null): { bubble: string | null; duo: [string, string] | null } => {
      if (!cityZoom || (!bubble && !duo)) return { bubble, duo };
      const i = indexOf.get(m);
      if (i === undefined) return { bubble, duo };
      return bubbleHasRoom(entries[i].c, entries[i].r, bubbleW(bubble, duo) + 8, obstaclesBut(i)) ? { bubble, duo } : { bubble: null, duo: null };
    };
    /** Côté de l'étiquette d'un ami (« Vu il y a … »), ou "none". */
    const friendSide = (m: NearbyMember, caption: string | null, hasBubble: boolean): LabelSide => {
      if (!caption) return "none";
      const i = indexOf.get(m);
      if (i === undefined) return "below";
      const w = textWidth(caption, "700 11px Inter, system-ui, sans-serif", 11) + 16 + 3;
      const side = pickLabelSide({ center: entries[i].c, radius: 50 / 2, width: w, obstacles: obstaclesBut(i), allowAbove: !hasBubble });
      if (side !== "none") placed.push(labelRect(entries[i].c, 50 / 2, w, side));
      return side;
    };
    /** Position (lat, lng) d'un membre seul déplacé par la règle « Moi » ; null = inchangée. */
    const movedPos = (m: NearbyMember): [number, number] | null => {
      const i = indexOf.get(m);
      if (i === undefined) return null;
      const sh = shifts[i];
      if (Math.abs(sh.x) < 0.5 && Math.abs(sh.y) < 0.5) return null;
      return mercatorToLatLng(entries[i].c, zoomLevel);
    };
    return { shifts, priceFit, friendSide, movedPos, liveFan };
  })();

  // 25/09 — « Itinéraire » ferme la fiche ouverte : le trajet et sa carte
  // de résumé restent visibles (avant, la fiche les recouvrait à 375 px).
  const [mapObj, setMapObj] = useState<L.Map | null>(null);
  useEffect(() => { if (mapObj) onMapReady?.(mapObj); /* eslint-disable-next-line react-hooks/exhaustive-deps */ }, [mapObj]);
  // Ouvrir une fiche : le point reste visible au-dessus de la carte du bas.
  const openSheet = (next: Sheet | null, at?: [number, number] | null) => {
    setSheet(next);
    if (!next || !at || !mapObj) return;
    try {
      const narrow = mapObj.getSize().x < 640;
      mapObj.panInside(L.latLng(at[0], at[1]), { paddingTopLeft: L.point(60, 70), paddingBottomRight: L.point(narrow ? 60 : 420, narrow ? Math.min(340, mapObj.getSize().y * 0.62) : 60) });
    } catch { /* carte pas prête */ }
  };
  // 588 — la fiche d'une personne : choix du rôle si elle en a plusieurs.
  const sheetFor = (m: NearbyMember): Sheet => {
    const wanted = rolesMatching(m, wantedRoles);
    const roles = wanted.length ? [...wanted, ...rolesOf(m).filter((r) => !wanted.some((w) => sameRole(w, r)))] : rolesOf(m);
    return roles.length > 1 ? { kind: "person", m } : { kind: "role", m, r: roles[0] };
  };
  // 588 — « quand je clic sur mon ami, ça ne zoome pas sur lui » : un ami
  // cliqué = vol doux (flyTo, zoom 16, 0,8 s) ET sa fiche. Le point est posé
  // au centre de ce que la fiche laisse VISIBLE (bas au téléphone, droite
  // sur ordinateur), sinon la fiche le recouvrirait.
  const flyToFriend = (m: NearbyMember) => {
    const at = pointOf(m);
    if (!at) return;
    setSheet(sheetFor(m));
    if (!mapObj) return;
    try {
      const size = mapObj.getSize();
      const narrow = size.x < 640;
      const px = mapObj.project(L.latLng(at[0], at[1]), FRIEND_ZOOM);
      const dx = narrow ? 0 : Math.min(420, size.x * 0.4) / 2;
      const dy = narrow ? Math.min(340, size.y * 0.62) / 2 : 0;
      const c = mapObj.unproject(px.add(L.point(dx, dy)), FRIEND_ZOOM);
      safeFly(mapObj, [c.lat, c.lng], FRIEND_ZOOM, 0.8);
    } catch {
      safeFly(mapObj, at, FRIEND_ZOOM, 0.8);
    }
  };
  const flyToFriendRef = useRef(flyToFriend);
  flyToFriendRef.current = flyToFriend;
  useEffect(() => {
    if (focusFriend) flyToFriendRef.current(focusFriend.m);
  }, [focusFriend?.ts]);

  const dirClose = onDirections
    ? (target: { lat: number; lng: number; friendId?: string }) => { try { mapObj?.closePopup(); } catch { /* */ } onDirections(target); }
    : undefined;

  // ── 590 (§2, §4) — 1er clic = la carte vole sur la personne (≈ +1,5
  // niveau, point un peu au-dessus du centre) et la CARTE FOCUS apparaît en
  // haut ; 2e clic (ou « Profil › ») = la fiche existante ; ✕ = retour au
  // cadrage d'avant. Clic sur la carte vide / glisser = la carte focus part.
  const [focus, setFocus] = useState<Focus | null>(null);
  const focusKeyRef = useRef<string | null>(null);
  focusKeyRef.current = focus?.key ?? null;
  const prevViewRef = useRef<{ c: [number, number]; z: number } | null>(null);
  const [openReq, setOpenReq] = useState<MapRequest | null>(null);
  const clearFocus = () => {
    if (!focusKeyRef.current) return;
    setFocus(null);
    prevViewRef.current = null;
  };
  const closeFocus = () => {
    const pv = prevViewRef.current;
    setFocus(null);
    prevViewRef.current = null;
    if (pv && mapObj) safeFly(mapObj, pv.c, pv.z, 0.6);
  };
  // 26/10 (2610, maquette de l'app) — profil : 1er clic = zoom +2 centré + bulle de prix ; re-clic sur
  // le même profil = bulle masquée et caméra remise comme avant (la fiche s'ouvre par la bulle ou
  // « Profil › » de la carte focus). Dans un groupe éclaté : pas de vol, re-clic = bulle masquée.
  const spiderRef = useRef(spider);
  spiderRef.current = spider;
  const resetAll2610 = () => {
    const sp = spiderRef.current;
    if (!focusKeyRef.current && !sp) return;
    if (!sp && !focusKeyRef.current?.startsWith("p:") && !focusKeyRef.current?.startsWith("req:")) { clearFocus(); return; }
    if (sp) setSpider(null);
    closeFocus();
  };

  const tapFocus = (f: Focus) => {
    if (!focusLabels || !mapObj) { f.open(); return; }
    // 2610 — profil OU demande : même comportement (re-clic = bulle masquée, caméra remise).
    const profile2610 = f.key.startsWith("p:") || f.key.startsWith("req:");
    if (focusKeyRef.current === f.key) {
      if (profile2610) {
        if (spiderRef.current) { setFocus(null); return; }
        closeFocus();
        return;
      }
      setFocus(null);
      prevViewRef.current = null;
      f.open();
      return;
    }
    if (profile2610 && spiderRef.current && spiderRef.current.ids.includes(f.key.slice(2))) {
      setSheet(null);
      setOpenReq(null);
      setFocus(f);
      return;
    }
    if (spiderRef.current) setSpider(null);
    if (!prevViewRef.current) {
      const c = mapObj.getCenter();
      prevViewRef.current = { c: [c.lat, c.lng], z: mapObj.getZoom() };
    }
    setSheet(null);
    setOpenReq(null);
    setFocus(f);
    try {
      const z = profile2610 ? Math.min(19, mapObj.getZoom() + 2) : Math.min(18, Math.max(mapObj.getZoom() + 1.5, 15));
      const px = mapObj.project(L.latLng(f.lat, f.lng), z);
      // Le point ~60 px au-dessus du centre, mais toujours SOUS la carte
      // focus (et sa bulle de prix) quand la carte est basse.
      const h = mapObj.getSize().y;
      const want = Math.max(h / 2 - 60, focusTop + 130);
      const c = mapObj.unproject(px.add(L.point(0, h / 2 - want)), z);
      safeFly(mapObj, [c.lat, c.lng], z, 0.45);
    } catch {
      safeFly(mapObj, [f.lat, f.lng], Math.max(mapObj.getZoom(), 15), 0.45);
    }
  };
  const kmFrom = (at: [number, number] | null): string => {
    if (!at || !distanceFrom) return "";
    const R = 6371;
    const dLat = ((at[0] - distanceFrom.lat) * Math.PI) / 180;
    const dLng = ((at[1] - distanceFrom.lng) * Math.PI) / 180;
    const a = Math.sin(dLat / 2) ** 2 + Math.cos((distanceFrom.lat * Math.PI) / 180) * Math.cos((at[0] * Math.PI) / 180) * Math.sin(dLng / 2) ** 2;
    return formatKm(2 * R * Math.asin(Math.min(1, Math.sqrt(a))), cardLabels?.lang) || "";
  };
  const firstOf = (name: string) => (name || "").trim().split(/\s+/)[0] || name;
  const personFocus = (m: NearbyMember, role: string, price: number | null | undefined, currency: string | null | undefined, open: () => void, friend: boolean, shown?: PersonRole[], alt?: PriceAlt | null, unit?: string | null): Focus | null => {
    const at = pointOf(m);
    if (!at) return null;
    const k = roleKey(role);
    // 27/09 — gardien + promeneur montrés : les deux prix (« 🏠 20 € · 🐾 12 € »).
    const duo = shown ? duoPrices(shown) : null;
    const pr = duo ? `🏠 ${duo[0]} · 🐾 ${duo[1]}` : priceFor(k, price, currency, alt, unit);
    const km = kmFrom(at);
    return {
      key: `p:${m.id}`,
      lat: at[0],
      lng: at[1],
      name: m.name || focusLabels?.roles[k] || "",
      role: k,
      roles: rolesOf(m).map((r) => roleKey(r.role)),
      avatar: m.avatar,
      info: [pr, km].filter(Boolean).join(" · ") || focusLabels?.roles[k] || "",
      friend,
      icon: k === "walker" ? "walk" : k === "sitter" ? "home" : "paw",
      verified: m.identityVerified === true,
      rank: parseRank611(m.rank),
      pins: parsePins1910(m.pins),
      open,
    };
  };
  // Tracé de la balade (§5) : ami en direct sous la carte focus, ou suivi.
  const walkId = focus?.liveId ?? followHaloId ?? null;
  const walkPos = walkId ? friendPositions.find((p) => p.userId === walkId) : undefined;
  const walkTrail = useMemo(() => {
    if (!walkPos) return [] as [number, number][];
    const pts = (Array.isArray(walkPos.trail) ? walkPos.trail : []).filter(
      (q): q is [number, number] => Array.isArray(q) && Number.isFinite(q[0]) && Number.isFinite(q[1]),
    ).map((q) => [q[0], q[1]] as [number, number]);
    const last = pts[pts.length - 1];
    if (!last || Math.abs(last[0] - walkPos.lat) > 1e-6 || Math.abs(last[1] - walkPos.lng) > 1e-6) pts.push([walkPos.lat, walkPos.lng]);
    return pts;
  }, [walkPos]);
  // 612 — le tracé dessiné : celui du serveur (déjà sans sauts) + les points reçus depuis,
  // repassés par le même nettoyage que l'app puis lissés. À défaut, les positions gardées
  // en mémoire pendant le suivi. Un seul des deux, jamais les deux.
  const followLine = useMemo(
    () => liveTail612(walkTrail.length > 1 ? walkTrail : trail),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [walkTrail, trail.length, followed?.lat, followed?.lng],
  );
  /** La personne suivie (ou dont la balade est affichée) : jamais décalée, aucun cercle autour. */
  const trackedId = walkId ?? followUserId ?? null;

  return (
    <div className="relative h-full min-h-[420px] w-full overflow-hidden rounded-[28px] max-lg:rounded-none">
      <style dangerouslySetInnerHTML={{ __html: PAWMAP_KEYFRAMES + PAWMAP_2610_CSS }} />
      <MapContainer ref={setMapObj} center={center} zoom={initialZoom} minZoom={3} maxZoom={19} zoomSnap={0.5} style={{ height: "100%", width: "100%" }} scrollWheelZoom zoomControl={false}>
        {satellite ? (
          <TileLayer
            key="sat"
            attribution="&copy; Esri, Maxar, Earthstar Geographics"
            url="https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"
            maxZoom={19}
          />
        ) : dark ? (
          // 25/09 (585) — CARTO « dark_all » exige désormais une clé (tuile
          // « API KEY REQUIRED », vérifiée aussi avec le référent hopetsit.com) :
          // mode nuit = tuiles OpenStreetMap assombries par un filtre chaud.
          <TileLayer key="dark" className="hps-dark-tiles" attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>' url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" maxZoom={19} />
        ) : (
          <TileLayer key="light" attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>' url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" maxZoom={19} />
        )}

        <ViewWatcher onZoom={handleZoom} onMove={onMapMove} onBounds={onBoundsChange} />
        <RecenterMap center={center} />
        <FlyToFocus target={focusTarget} />
        <RouteFit points={routePoints} extra={joinTo ? [routeFrom ?? userLocation, joinTo] : undefined} join={!!joinTo} token={routeFitToken || undefined} />
        <FollowController target={followTarget} onUserGesture={() => onFollowPause?.()} />
        <FocusWatcher onClear={clearFocus} onReset={resetAll2610} />
        {/* 02/10 (607, PAM) — passe de mise en page unique (CONTRAT_607_bulles §2). */}
        <CollisionPass607 />

        {/* Ma position : cercle de précision honnête + « Moi » (56 px). */}
        {/* 612 — pendant un suivi : aucun cercle en mètres sur la carte (comme l'app). */}
        {userLocation && userAccuracy != null && userAccuracy > 25 && !trackedId && (
          <Circle center={[userLocation.lat, userLocation.lng]} radius={userAccuracy} pathOptions={{ color: ROLE_COLOR[roleKey(userRole)], fillColor: ROLE_COLOR[roleKey(userRole)], fillOpacity: 0.08, weight: 1, dashArray: "6 6" }} />
        )}
        {userLocation && (
          <Marker position={[userLocation.lat, userLocation.lng]} icon={userIcon} zIndexOffset={PIN_Z.me}>
            <Popup>
              <strong>{positionLabel || meLabel}</strong>
              {userAccuracy != null && accuracyLabel && (
                <>
                  <br />
                  <span className="text-xs text-ink-muted">{accuracyLabel.replace("{m}", String(userAccuracy))}</span>
                </>
              )}
            </Popup>
          </Marker>
        )}

        {/* 02/10 (607, PAM) — MINI-PELUCHES : même PNG que l'app (40 px, dorée 46 px),
            au-dessus des lieux et des demandes, sous les personnes. */}
        {plushies.map((pl) => (
          <Marker key={`plush-${pl.id}`} position={[pl.lat, pl.lng]} icon={plushIcon(pl.type, !!pl.golden)} zIndexOffset={PIN_Z.request + 500}>
            {plushLabels && (
              <Popup>
                <strong>{plushLabels.title}</strong>
                <br />
                <span className="text-xs">{plushLabels.hint}</span>
              </Popup>
            )}
          </Marker>
        ))}

        {/* LIEUX : goutte par type, carré blanc pour un groupe. */}
        {poiClusters.map((g, i) =>
          g.items.length > 1 ? (
            <PlaceCluster key={`pc-${g.key}`} center={g.center} count={g.items.length} category={dominantPlace2710(g.items)} items={g.items} index={poiIndex} dark={dark} />
          ) : null,
        )}
        {poiClusters.filter((g) => g.items.length === 1).map((g) => g.items[0]).map((poi) => {
          const lng = poi.location.coordinates[0];
          const lat = poi.location.coordinates[1];
          const isSelected = selectedPoi?._id === poi._id;
          return (
            <Marker key={poi._id} position={[lat, lng]} icon={placeIcon(poi.category)} eventHandlers={{ click: () => onSelectPoi?.(poi) }} zIndexOffset={isSelected ? PIN_Z.placeSelected : PIN_Z.place}>
              <Popup>
                <div className="text-sm">
                  <div className="mb-1 font-bold">{poi.title}</div>
                  <div className="mb-1 text-xs font-semibold" style={{ color: "#6E4F48" }}>{POI_CATEGORY_LABELS[poi.category]?.label}</div>
                  {poi.address && <div className="text-xs text-ink-muted">{poi.address}</div>}
                  {poi.openingHours && (() => {
                    const st = formatOpenStatus?.(poi.openingHours) ?? null;
                    return (
                      <div className="mt-1 text-xs">
                        {st && <div className="font-bold" style={{ color: st.open ? "#16A34A" : "#B42318" }}>{st.label}</div>}
                        <div className="text-ink-muted">{poi.openingHours}</div>
                      </div>
                    );
                  })()}
                  {poi.phone && (
                    <div className="mt-1 text-xs">
                      <a href={`tel:${poi.phone.replace(/[^0-9+]/g, "")}`} className="font-semibold text-ink underline">
                        {poi.phone}{callLabel ? ` · ${callLabel}` : ""}
                      </a>
                    </div>
                  )}
                  {dirClose && (
                    <button type="button" onClick={() => dirClose({ lat, lng })} className="mt-2 rounded-full px-3 py-1 text-xs font-bold text-white" style={{ backgroundColor: "#C92A12" }}>
                      {directionsLabel}
                    </button>
                  )}
                </div>
              </Popup>
            </Marker>
          );
        })}

        {/* PAWSPOTS : goutte noire (or si doré), carré noir pour un groupe. */}
        {spotClusters.map((g, i) =>
          g.items.length > 1 ? <SpotCluster key={`sc-${g.key}`} center={g.center} count={g.items.length} items={g.items} index={spotIndex} /> : null,
        )}
        {spotClusters.filter((g) => g.items.length === 1).map((g) => g.items[0]).map((spot) => (
          <Marker key={`spot-${spot.id}`} position={[spot.lat, spot.lng]} icon={spotIcon(spot.type, spot.isGolden, showPrice ? spot.name : null)} zIndexOffset={spot.isGolden ? PIN_Z.spotGolden : PIN_Z.spot} eventHandlers={{ popupopen: () => onSpotVisit?.(spot.id) }}>
            <Popup>
              <div className="text-sm" style={{ minWidth: 170 }}>
                <div className="mb-1 font-bold">{spot.name}</div>
                <div className="mb-1 text-xs text-ink-muted">{spotTypeLabels?.[spot.type] || spot.type}</div>
                <div className="mb-1 text-xs text-ink-muted">♥ {spot.likesCount} · ★ {Number(spot.quality || 0).toFixed(1)} · {spot.visitsCount}</div>
                {spot.photoUrl ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={spot.photoUrl} alt="" style={{ width: "100%", maxHeight: 110, objectFit: "cover", borderRadius: 8 }} />
                ) : null}
                {dirClose && (
                  <button type="button" onClick={() => dirClose({ lat: spot.lat, lng: spot.lng })} className="mt-2 rounded-full px-3 py-1 text-xs font-bold text-white" style={{ backgroundColor: "#C92A12" }}>
                    {directionsLabel}
                  </button>
                )}
              </div>
            </Popup>
          </Marker>
        ))}

        {/* SIGNALEMENTS : triangle rouge. */}
        {reports.map((r) => {
          const c = r.location?.coordinates;
          if (!Array.isArray(c) || c.length < 2) return null;
          return (
            <Marker key={`report-${r._id}`} position={[c[1], c[0]]} icon={reportIcon(r.type, alertFresh613(r.createdAt, now || Date.now()))} opacity={alertAlpha613(r.createdAt, now || Date.now())} zIndexOffset={PIN_Z.report}>
              <Popup>
                <ReportPopupBody r={r} label={reportTypeLabels?.[r.type] || r.type} onConfirm={onReportConfirm} labels={reportConfirmLabels} />
              </Popup>
            </Marker>
          );
        })}

        {/* DEMANDES des propriétaires : bulle orange du service, budget
            dedans. 590 — 1er clic = carte focus, 2e clic = la fiche. */}
        {requests.map((r) => (
          <Marker
            key={`req-${r.id}`}
            position={[r.lat, r.lng]}
            icon={requestIcon(r, requestMineLabel, reqFromOf(r), focus?.key === `req:${r.id}`)}
            zIndexOffset={PIN_Z.request + (r.mine ? 200 : 0)}
            eventHandlers={{
              click: (e) => {
                if (r.mine || !focusLabels) { clearFocus(); setOpenReq(r); return; }
                // 2610 — demande touchée : clic SUR sa bulle de budget = sa fiche.
                if (focus?.key === `req:${r.id}` && (e.originalEvent?.target as Element | null)?.closest?.("[data-price-bubble-2610]")) { setFocus(null); prevViewRef.current = null; setOpenReq(r); return; }
                tapFocus({
                  key: `req:${r.id}`,
                  lat: r.lat,
                  lng: r.lng,
                  name: r.ownerName ? `${firstOf(r.ownerName)} · ${focusLabels.request}` : requestLabels?.title || focusLabels.request,
                  role: "owner",
                  avatar: r.ownerAvatar || null,
                  info: [r.service === "walk" ? focusLabels.walk : focusLabels.sitting, r.priceLabel || reqFromOf(r)].filter(Boolean).join(" · "),
                  icon: r.service === "walk" ? "walk" : "home",
                  open: () => setOpenReq(r),
                });
              },
            }}
          />
        ))}
        {openReq && (
          <RequestPopup key={`rp-${openReq.id}`} r={openReq} onClose={() => setOpenReq(null)}>
            <div className="text-sm" style={{ minWidth: 180 }}>
              <div className="font-bold" style={{ color: ROLE_COLOR.owner }}>{openReq.mine ? requestLabels?.mine : requestLabels?.title}</div>
              <div className="mt-0.5 text-xs font-semibold text-ink">
                {openReq.service === "walk" ? requestLabels?.walk : requestLabels?.sitting}
                {openReq.priceLabel ? ` · ${openReq.priceLabel}` : ""}
                {openReq.city ? ` · ${openReq.city}` : ""}
              </div>
              {!openReq.priceLabel && openReq.pricing && <RequestFromLine622 pricing={openReq.pricing} />}
              {openReq.locationLabel && <div className="mt-0.5 text-xs font-semibold text-ink">📍 {openReq.locationLabel}</div>}
              {openReq.body && <div className="mt-1 line-clamp-3 text-xs text-ink-muted">{openReq.body}</div>}
              {!openReq.mine && onOfferService && requestLabels && (
                <button type="button" onClick={() => onOfferService(openReq.id)} className="mt-2 flex min-h-[40px] w-full items-center justify-center rounded-full px-3 text-xs font-bold text-white" style={{ background: `linear-gradient(90deg, #C92A12, #9E1F0B)` }}>
                  {requestLabels.offer}
                </button>
              )}
            </div>
          </RequestPopup>
        )}

        {/* MEMBRES : UNE personne = UN rond (liseré de chacun de ses rôles),
            rond de groupe à la couleur dominante. Clic = fiche du bas. */}
        {memberClusters.map((g, i) =>
          g.items.length > 1 ? <MemberCluster key={`mc-${g.key}`} center={g.center} items={g.items} onList={(items) => openSheet({ kind: "list", items }, g.center)} index={memberIndex} dark={dark} /> : null,
        )}
        {/* 27/10 — groupe éclaté (même endroit / zoom maximal) : le rond du groupe disparaît, ses membres
            sont posés sur LEUR vraie position à ≤ 12 px près ; clic dans le vide = refermé. */}
        {[...memberClusters.filter((g) => g.items.length === 1).map((g) => g.items[0]), ...friendMembers, ...(spider ? spiderMembers : [])].map((m) => {
          const spiderIdx = spider ? spiderMembers.indexOf(m) : -1;
          // 27/10 (règle 626) — plus d'éclatement : chaque rond est dessiné à sa vraie position.
          const spiderOff: { x: number; y: number } | null = spiderIdx >= 0 ? { x: 0, y: 0 } : null;
          const pt: [number, number] | null = pointOf(m);
          if (!pt) return null;
          const isFriend = isFriendMember(m, friendSet);
          // Un ami qui partage en direct a déjà son rond « en direct » : pas de doublon.
          if (isFriend && personIdsOf(m).some((x) => liveIdSet.has(x))) return null;
          const wanted = rolesMatching(m, wantedRoles);
          const roles = wanted.length ? [...wanted, ...rolesOf(m).filter((r) => !wanted.some((w) => sameRole(w, r)))] : rolesOf(m);
          // Rôles MONTRÉS par le filtre (prix double seulement s'il montre gardien ET promeneur).
          const shown = wanted.length ? wanted : roles;
          const open = () => openSheet(roles.length > 1 ? { kind: "person", m } : { kind: "role", m, r: roles[0] }, pt);
          if (isFriend) {
            const prem = personIdsOf(m).some((x) => premiumSet.has(x)) || !!m.isPremium;
            // « Vu il y a X » sous son rond (dernier signe de vie connu).
            const seenIso = personIdsOf(m).map((x) => friendSeen?.[x]).find(Boolean) || null;
            const seenMs = seenIso ? new Date(seenIso).getTime() : NaN;
            const rawCaption = liveLabels && Number.isFinite(seenMs)
              ? (now - seenMs < 60000 ? liveLabels.seenNow : liveLabels.seenAgo.replace("{ago}", liveLabels.ago(now - seenMs)))
              : null;
            const fAlt = roles[0].priceAlt ?? m.priceAlt;
            const fUnit = roles[0].priceUnit ?? m.priceUnit;
            const fSel = focus?.key === `p:${m.id}`;
            const fFit = lay.priceFit(m, memberBubble(roles[0].role, roles[0].priceFrom ?? m.priceFrom, roles[0].currency ?? m.currency, fAlt, fUnit, fSel), memberDuo(shown, fSel));
            // 607 — dessous si libre, sinon dessus (sans bulle), sinon rien.
            const side = lay.friendSide(m, rawCaption, !!(fFit.bubble || fFit.duo));
            const caption = side === "none" ? null : rawCaption;
            const fOpen = () => flyToFriend(m);
            return <Marker key={`friend-${m.id}`} position={lay.movedPos(m) ?? pt} icon={friendProfileIcon(m, prem, roles, caption, fFit.bubble, fFit.duo, side === "above")} zIndexOffset={PIN_Z.friend} eventHandlers={{ click: () => { const f = personFocus(m, roles[0].role, roles[0].priceFrom ?? m.priceFrom, roles[0].currency ?? m.currency, fOpen, true, shown, fAlt, fUnit); if (f) tapFocus(f); else fOpen(); } }} />;
          }
          const r0 = roles[0];
          const pFrom = r0.priceFrom ?? m.priceFrom;
          const pCur = r0.currency ?? m.currency;
          const pAlt = r0.priceAlt ?? m.priceAlt;
          const pUnit = r0.priceUnit ?? m.priceUnit;
          // 2610 — bulle de prix seulement sur le rond sélectionné ; clic SUR la bulle = la fiche.
          const sel = focus?.key === `p:${m.id}`;
          const dim = !!focus && !sel;
          const live = personIdsOf(m).some((x) => liveIdSet.has(x));
          const prices = sel ? selectedPrices2610(shown, m) : [];
          return (
            <Marker key={`member-${m.id}${spiderOff ? "-sp" : ""}`} position={pt} icon={memberIcon(m, spiderOff ? null : memberCaption({ ...m, role: r0.role }), roles, dark, { selected: sel, dim, prices, live, off: spiderOff })} zIndexOffset={sel ? PIN_Z.me + 500 : spiderOff ? PIN_Z.member + 800 : m.isBoosted ? PIN_Z.memberBoosted : PIN_Z.member} eventHandlers={{ click: (e) => { const onBubble = !!(e.originalEvent?.target as Element | null)?.closest?.("[data-price-bubble-2610]"); if (sel && onBubble) { open(); return; } const f = personFocus(m, r0.role, pFrom, pCur, open, false, shown, pAlt, pUnit); if (f) tapFocus(f); else open(); } }} />
          );
        })}

        {/* AMIS en direct : photo + anneau rose ; tracé violet du suivi. */}
        {/* 612 (Daniel, 05/10) — comme l'app : une seule traîne violette, nettoyée (sauts GPS)
            et lissée. Retirés : le double trait blanc + pointillés animés, le rond de départ,
            les traits roses de l'éventail. La lueur violette reste DANS la photo suivie. */}
        {/* 612 §7 — courte traîne : 200 derniers mètres, épaisseur 3, fondu 0,12 → 1, finit sous la photo. */}
        {followLine.map((part, k) => (
          <Polyline key={`wf-${walkId ?? followUserId}-${k}-${followLine.length}`} positions={part.pts} smoothFactor={0.4} pathOptions={{ color: TRAIL_COLOR_612, weight: TRAIL_WEIGHT_612, opacity: part.alpha, lineCap: k === followLine.length - 1 ? "round" : "butt", lineJoin: "round", className: "hps-walk-follow" }} />
        ))}
        {friendPositions.map((p0) => { const fan = p0.userId === trackedId ? undefined : lay.liveFan.get(p0.userId); const p = fan ? { ...p0, lat: fan.pos[0], lng: fan.pos[1] } : p0; return (
          <LiveFriendMarker
            key={`live-${p.userId}`}
            p={p}
            isFamily={familySet.has(p.userId)}
            isPremium={premiumSet.has(p.userId)}
            boosted={liveOwnerOf(p.userId)?.isBoosted === true}
            roles={(() => { const m = liveOwnerOf(p.userId); return m ? rolesOf(m).map((r) => r.role) : [p.role]; })()}
            followed={followHaloId === p.userId}
            labels={liveLabels}
            onOpen={() => {
              const open = () => { if (onFriendFocus) { setSheet(null); onFriendFocus(p); } else openSheet({ kind: "live", p }, [p.lat, p.lng]); };
              const km = kmFrom([p.lat, p.lng]);
              tapFocus({
                key: `live:${p.userId}`,
                lat: p.lat,
                lng: p.lng,
                name: p.name,
                role: roleKey(p.role),
                avatar: p.avatar,
                info: [p.state === "lost" ? liveLabels?.lost : focusLabels?.walking, km].filter(Boolean).join(" · "),
                live: p.state !== "lost",
                friend: true,
                icon: "paw",
                liveId: p.userId,
                open,
              });
            }}
          />
        );})}

        {/* ITINÉRAIRE : polyline couleur du mode + repères de virage.
            613 (comme l'app, kPawRouteZ613) — dans un calque AU-DESSUS de la traîne violette
            (avant : même calque, la traîne recréée à chaque position repassait par-dessus et on
            ne voyait plus que « son trajet à lui »). Deux traits PLEINS relient ma position au
            début du trajet et la fin du trajet à la photo de la personne rejointe : un seul trait
            continu de moi à lui. Pas de repère d'arrivée posé sur sa photo. */}
        <Pane name="hps-route613" style={{ zIndex: 450 }}>
          {routePoints && routePoints.length > 1 && (
            <Polyline positions={routePoints.map((p) => [p.lat, p.lng] as [number, number])} pathOptions={{ color: routeColor, weight: 5, opacity: 0.9, lineCap: "round", lineJoin: "round", className: "hps-route613" }} />
          )}
          {routePoints && routePoints.length > 1 && (() => {
            const from = routeFrom ?? userLocation ?? null;
            const a = routePoints[0], z = routePoints[routePoints.length - 1];
            return (
              <>
                {from && meters613(from, a) >= JOIN_LEAD_MIN_M_613 && (
                  <Polyline key="lead-in" positions={[[from.lat, from.lng], [a.lat, a.lng]]} pathOptions={{ color: routeColor, weight: 5, opacity: 0.9, lineCap: "round", className: "hps-route613-in" }} />
                )}
                {joinTo && meters613(z, joinTo) >= JOIN_LEAD_MIN_M_613 && (
                  <Polyline key="lead-out" positions={[[z.lat, z.lng], [joinTo.lat, joinTo.lng]]} pathOptions={{ color: routeColor, weight: 5, opacity: 0.9, lineCap: "round", className: "hps-route613-out" }} />
                )}
              </>
            );
          })()}
          {routeSteps &&
            routeSteps
              .filter((s) => s.type !== 1 && s.type !== 2 && s.type !== 3)
              .filter((s) => !(joinTo && s.type >= 4 && s.type <= 6))
              .map((s, i) => (
                <CircleMarker key={`step-${i}`} center={[s.lat, s.lng]} radius={s.type >= 4 && s.type <= 6 ? 7 : 5} pathOptions={{ color: routeColor, weight: 2, fillColor: "#ffffff", fillOpacity: 1 }}>
                  <Tooltip direction="top" offset={[0, -6]}>
                    <span className="text-xs">{stepGlyph(s.type)} {s.instruction}</span>
                  </Tooltip>
                </CircleMarker>
              ))}
        </Pane>
      </MapContainer>

      {focus && focusLabels && (
        <FocusCard key={focus.key} f={focus} labels={focusLabels} dark={dark} top={focusTop} faded={uiFade} onClose={closeFocus} onOpen={() => { const o = focus.open; setFocus(null); prevViewRef.current = null; o(); }} />
      )}

      {/* 25/09 (585) — FICHE DU BAS : choix du rôle, fiche du bon rôle, liste
          d'un groupe superposé, ami en direct. Au-dessus des rails, jamais
          rognée : pleine largeur à 375 px, 344 px à droite sur ordinateur. */}
      {sheet && cardLabels && (
        <PersonSheet
          sheet={sheet}
          setSheet={setSheet}
          labels={cardLabels}
          roleLabels={memberRoleLabels || {}}
          wantedRoles={wantedRoles}
          distanceFrom={distanceFrom}
          friendSet={friendSet}
          friendSeen={friendSeen}
          now={now}
          liveLabels={liveLabels}
          onAddFriend={onAddFriend}
          onDirections={dirClose ? (t) => { setSheet(null); dirClose(t); } : undefined}
          onMessage={onMessage}
          onMessageMember={onMessageMember}
          onFollow={onFriendFocus ? (p) => { setSheet(null); onFriendFocus(p); } : undefined}
          viewerRole={userRole}
        />
      )}
    </div>
  );
}


// ── 26/09/2026 (PawMap 590, §4) — la CARTE FOCUS ─────────────────────────────
// Fixe en haut de la carte (elle ne zoome pas), entre les deux barres : mini
// photo à l'anneau du rôle, nom (+ point vert en balade), info, « Profil › »
// en dégradé du rôle, ✕ qui ramène la carte au cadrage d'avant. Même verre
// que les barres (clair / sombre), mêmes tailles que l'app.
function FocusCard({ f, labels, dark, top, faded, onClose, onOpen }: { f: Focus; labels: FocusLabels; dark: boolean; top: number; faded: boolean; onClose: () => void; onOpen: () => void }) {
  const pal = JEWEL_ROLE[f.friend ? "friend" : roleKey(f.role)];
  // Bouton « Profil » : toujours aux couleurs des rôles (un ami compris) ;
  // l'anneau de la photo reste rose pour un ami.
  const btnGrad = rolesGrad(f.roles, JEWEL_ROLE[roleKey(f.role)]);
  const btnShadow = JEWEL_ROLE[roleKey(f.role)][1];
  const ringGrad = f.friend ? jewelGrad(pal) : rolesGrad(f.roles, pal);
  const ink = dark ? "#F6F1EE" : "#1B1616";
  const sub = dark ? "#A39A97" : "#7A6F6C";
  const [imgOk, setImgOk] = useState(true);
  const glyph = f.icon === "walk" ? ROLE_GLYPH.walker : f.icon === "home" ? ROLE_GLYPH.sitter : ROLE_GLYPH.owner;
  return (
    <div className="pointer-events-none absolute inset-x-0 z-[1065] flex justify-center px-[62px] sm:px-[72px]" style={{ top, opacity: faded ? 0.2 : 1, transition: "opacity 300ms ease" }}>
      <div
        key={f.key}
        role="group"
        aria-label={`${f.name}. ${f.info}`}
        className="pointer-events-auto flex w-full max-w-[440px] items-center gap-2 rounded-[22px] p-2"
        style={{
          background: dark ? "linear-gradient(180deg,rgba(46,40,38,.94),rgba(26,23,29,.92))" : "linear-gradient(180deg,rgba(255,255,255,.96),rgba(252,244,240,.92))",
          boxShadow: `inset 0 0 0 1px ${dark ? "rgba(255,255,255,.08)" : "rgba(120,40,30,.08)"}, 0 14px 30px -14px rgba(35,18,12,.5)`,
          backdropFilter: "blur(14px)",
          WebkitBackdropFilter: "blur(14px)",
          animation: "hps-focus-in 320ms cubic-bezier(.2,.8,.2,1)",
        }}
      >
        <button type="button" onClick={onOpen} className="flex min-w-0 flex-1 items-center gap-2.5 text-left">
          <span className="grid h-[42px] w-[42px] shrink-0 place-items-center rounded-full p-[2.5px]" style={{ background: ringGrad }}>
            <span className="relative block h-full w-full overflow-hidden rounded-full border-[1.5px] border-white" style={{ background: jewelGrad(pal) }}>
              <span className="absolute inset-[22%] block" dangerouslySetInnerHTML={{ __html: glyph }} />
              {f.avatar && imgOk ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={f.avatar} alt="" className="absolute inset-0 h-full w-full object-cover" onError={() => setImgOk(false)} />
              ) : null}
            </span>
          </span>
          <span className="min-w-0 flex-1">
            <span className="flex min-w-0 items-center gap-1.5">
              <span className="truncate text-[14px] font-bold leading-tight" style={{ color: ink, fontFamily: POPPINS }}>{f.name}</span>
              {f.live && <span aria-hidden="true" className="inline-block h-2 w-2 shrink-0 rounded-full" style={{ background: "#2E9E48" }} />}
              {f.verified && labels.verified && <VerifiedPill label={labels.verified} small />}
            </span>
            {(f.rank || f.pins) && <span className="mt-[3px] mb-px flex items-center gap-1">{f.rank && <RankPill611 rank={f.rank} mode={dark ? "dark" : "light"} compact />}<PinChips1910 pins={f.pins} compact /></span>}
            {f.info && <span className="block truncate text-[11.5px] font-medium leading-snug" style={{ color: sub, fontFamily: POPPINS }}>{f.info}</span>}
          </span>
        </button>
        <button
          type="button"
          onClick={onOpen}
          aria-label={labels.profile}
          className="relative inline-flex h-[34px] shrink-0 items-center overflow-hidden rounded-full px-2 text-[12px] font-bold text-white transition-transform duration-150 hover:-translate-y-px active:scale-95 min-[420px]:pl-3 min-[420px]:pr-1.5"
          style={{ background: btnGrad, boxShadow: `0 5px 10px -4px ${btnShadow}, inset 0 0 0 1.5px rgba(255,255,255,.3)`, fontFamily: POPPINS }}
        >
          <span aria-hidden="true" className="pointer-events-none absolute inset-x-2 top-[2px] h-[45%] rounded-full" style={{ background: "linear-gradient(180deg,rgba(255,255,255,.45),rgba(255,255,255,0))" }} />
          {/* Téléphone étroit : le chevron seul (le nom garde la place). */}
          <span className="relative hidden min-[420px]:inline">{labels.profile}</span>
          <svg className="relative" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#fff" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M10 7l5 5-5 5" /></svg>
        </button>
        <button type="button" onClick={onClose} aria-label={labels.close} title={labels.close} className="group grid h-11 w-9 shrink-0 place-items-center">
          <span className="grid h-[30px] w-[30px] place-items-center rounded-full transition-colors" style={{ background: dark ? "#2A2321" : "#FFFFFF", boxShadow: `inset 0 0 0 1px ${dark ? "rgba(255,255,255,.12)" : "rgba(120,40,30,.14)"}` }}>
            <svg viewBox="0 0 24 24" width="16" height="16" fill="none" strokeWidth="2.6" strokeLinecap="round" aria-hidden="true" className="transition-colors" style={{ stroke: sub }}><path d="M7 7l10 10M17 7 7 17" /></svg>
          </span>
        </button>
      </div>
    </div>
  );
}

// ── 25/09/2026 (PawMap 585) — la FICHE DU BAS ────────────────────────────────
// Remplace les bulles Leaflet des membres : à 375 px elles passaient sous les
// boutons de droite (« Itinéraire » caché par le mode nuit). Une seule carte
// blanche, posée AU-DESSUS des rails, qui ne déborde jamais.

const ROLE_DARK: Record<string, string> = { owner: "#9E1F0B", sitter: "#1E4FB0", walker: "#15803D" };
const ROLE_GRAD: Record<string, string> = {
  owner: "linear-gradient(90deg,#C92A12,#9E1F0B)",
  sitter: "linear-gradient(90deg,#2F6FD6,#1E4FB0)",
  walker: "linear-gradient(90deg,#2FAE4E,#15803D)",
};

function Avatar({ src, name, role, size, friend }: { src?: string | null; name: string; role: string; size: number; friend?: boolean }) {
  const key = roleKey(role);
  const color = ROLE_COLOR[key];
  return (
    <span className="relative grid shrink-0 place-items-center overflow-hidden rounded-full" style={{ width: size, height: size, background: color, border: `3px solid ${friend ? "#F06AA0" : color}`, boxShadow: "0 0 0 2px #fff" }}>
      <span className="absolute inset-[18%] block" dangerouslySetInnerHTML={{ __html: ROLE_GLYPH[key] }} />
      {src ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={src} alt="" className="relative h-full w-full object-cover" onError={(e) => { (e.currentTarget as HTMLImageElement).style.display = "none"; }} />
      ) : null}
      <span className="sr-only">{name}</span>
    </span>
  );
}

function firstName(name: string): string {
  return (name || "").trim().split(/\s+/)[0] || name;
}

function PersonSheet({ sheet, setSheet, labels, roleLabels, wantedRoles, distanceFrom, friendSet, friendSeen, now, liveLabels, onAddFriend, onDirections, onMessage, onMessageMember, onFollow, viewerRole }: {
  sheet: Sheet;
  setSheet: (s: Sheet | null) => void;
  labels: CardLabels;
  roleLabels: Record<string, string>;
  wantedRoles: string[];
  distanceFrom: { lat: number; lng: number } | null;
  friendSet: Set<string>;
  friendSeen: Record<string, string | null | undefined>;
  now: number;
  liveLabels?: LiveLabels;
  onAddFriend?: (m: NearbyMember) => Promise<"sent" | "already" | "error">;
  onDirections?: (target: { lat: number; lng: number; friendId?: string }) => void;
  onMessage?: (who: { id: string; role: string; name: string }) => void;
  onMessageMember?: (m: NearbyMember) => (() => void) | null;
  onFollow?: (p: FriendLivePosition) => void;
  /** 590 (§1) — prix de l'autre côté du marché seulement dans les listes. */
  viewerRole?: string;
}) {
  const { t: tUnits, lang: langUnits } = useT();
  const priceUnits = priceUnitLabels(tUnits, langUnits);
  const dist = (m: NearbyMember) => {
    const d = formatKm(distanceKmTo(m, distanceFrom), labels.lang);
    return d ? labels.distance.replace("{d}", d) : "";
  };
  const roleName = (r: string) => roleLabels[roleKey(r)] || r;
  const close = (
    <button type="button" onClick={() => setSheet(null)} aria-label={labels.close} className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-[#FAF1EC] text-[#231715] transition hover:bg-[#F3E3DC]">
      <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="#231715" strokeWidth="2.4" strokeLinecap="round" aria-hidden="true"><path d="M6 6l12 12M18 6 6 18" /></svg>
    </button>
  );
  const back = (to: Sheet) => (
    <button type="button" onClick={() => setSheet(to)} aria-label={labels.back} className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-[#FAF1EC] transition hover:bg-[#F3E3DC]">
      <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#231715" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M15 5l-7 7 7 7" /></svg>
    </button>
  );

  // Une ligne « photo · prénom · rôle coloré · distance · Voir ».
  const RoleRow = ({ m, r, friend, onSee }: { m: NearbyMember; r: PersonRole; friend: boolean; onSee: () => void }) => {
    const k = roleKey(r.role);
    const price = k !== "owner" && showsPriceBubble(viewerRole, k) ? formatPriceUnit(r.priceFrom, r.currency, r.priceAlt, priceUnits, r.priceUnit) : null;
    return (
      <li>
        <button type="button" onClick={onSee} className="flex min-h-[60px] w-full items-center gap-3 rounded-2xl bg-[#FDF8F7] px-2.5 py-2 text-left transition hover:bg-[#FAF1EC]">
          <Avatar src={m.avatar} name={m.name} role={k} size={42} friend={friend} />
          <span className="min-w-0 flex-1">
            <span className="block truncate text-[14px] font-bold text-[#231715]">{firstName(m.name) || roleName(k)}</span>
            <span className="block truncate text-[12px] font-bold" style={{ color: ROLE_DARK[k] }}>
              {roleName(k)}{price ? ` · ${labels.priceFrom} ${price}` : ""}
            </span>
            {dist(m) && <span className="block truncate text-[11px] font-semibold text-[#8A6B64]">{dist(m)}</span>}
          </span>
          <span className="inline-flex min-h-[36px] shrink-0 items-center rounded-full px-3.5 text-[12px] font-bold text-white" style={{ background: ROLE_GRAD[k] }}>{labels.see}</span>
        </button>
      </li>
    );
  };

  let body: React.ReactNode = null;
  if (sheet.kind === "person") {
    const m = sheet.m;
    const friend = isFriendMember(m, friendSet);
    const wanted = rolesMatching(m, wantedRoles);
    const roles = [...wanted, ...rolesOf(m).filter((r) => !wanted.some((w) => sameRole(w, r)))];
    body = (
      <>
        <div className="flex items-center gap-3">
          <Avatar src={m.avatar} name={m.name} role={roles[0]?.role || m.role} size={48} friend={friend} />
          <div className="min-w-0 flex-1">
            <p className="truncate font-display text-[16px] font-bold text-[#231715]">{m.name}</p>
            <p className="text-[12px] font-semibold text-[#6E4F48]">{labels.chooseProfile}{friend ? <span className="ml-1.5 rounded-full bg-[#FDE7F0] px-2 py-0.5 text-[11px] font-bold text-[#9D174D]">{labels.friend}</span> : null}</p>
          </div>
          {close}
        </div>
        <ul className="mt-3 space-y-1.5">
          {roles.map((r) => <RoleRow key={`pr-${r.role}-${r.id}`} m={m} r={r} friend={friend} onSee={() => setSheet({ kind: "role", m, r, back: sheet })} />)}
        </ul>
      </>
    );
  } else if (sheet.kind === "list") {
    const rows = expandRows(sheet.items, { wanted: wantedRoles, from: distanceFrom, friendIds: friendSet });
    body = (
      <>
        <div className="flex items-center gap-3">
          <p className="min-w-0 flex-1 font-display text-[16px] font-bold text-[#231715]">{labels.profilesHere.replace("{count}", String(rows.length))}</p>
          {close}
        </div>
        <ul className="mt-3 space-y-1.5">
          {rows.map((row) => <RoleRow key={`lr-${row.m.id}-${row.r.id}`} m={row.m} r={row.r} friend={row.friend} onSee={() => setSheet({ kind: "role", m: row.m, r: row.r, back: sheet })} />)}
        </ul>
      </>
    );
  } else if (sheet.kind === "role") {
    body = <RoleCard key={`rc-${sheet.r.id}`} m={sheet.m} r={sheet.r} backBtn={sheet.back ? back(sheet.back) : null} closeBtn={close} labels={labels} roleName={roleName} dist={dist(sheet.m)} friend={isFriendMember(sheet.m, friendSet)} friendSeen={friendSeen} now={now} liveLabels={liveLabels} onAddFriend={onAddFriend} onDirections={onDirections} onMessage={onMessage} onMessageMember={onMessageMember} />;
  } else {
    const p = sheet.p;
    const k = roleKey(p.role);
    const lost = p.state === "lost";
    const age = p.lastSeenAt ? Math.max(0, now - new Date(p.lastSeenAt).getTime()) : 0;
    body = (
      <>
        <div className="flex items-center gap-3">
          <Avatar src={p.avatar} name={p.name} role={k} size={48} friend />
          <div className="min-w-0 flex-1">
            <p className="truncate font-display text-[16px] font-bold text-[#231715]">{p.name}</p>
            <p className="text-[12px] font-bold" style={{ color: ROLE_DARK[k] }}>{roleName(k)} <span className="ml-1 rounded-full bg-[#FDE7F0] px-2 py-0.5 text-[11px] font-bold text-[#9D174D]">{labels.friend}</span></p>
          </div>
          {close}
        </div>
        {liveLabels && (
          <div className="mt-2.5 inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-[11px] font-bold" style={lost ? { background: "#FFF4E5", color: "#9A3412" } : { background: "#EDE9FE", color: "#5B21B6" }}>
            <span className="inline-block h-2 w-2 rounded-full" style={{ background: lost ? "#EA580C" : "#7C3AED" }} />
            {lost ? liveLabels.lost : liveLabels.live} · {liveLabels.ago(age)}
          </div>
        )}
        <div className="mt-3 flex flex-col gap-2">
          {onFollow && liveLabels && (
            <button type="button" onClick={() => onFollow(p)} className="flex min-h-[48px] items-center justify-center rounded-[16px] px-4 text-[14px] font-bold text-white" style={{ background: "linear-gradient(90deg,#8B5CF6,#6D28D9)" }}>{liveLabels.follow}</button>
          )}
          <div className="grid grid-cols-2 gap-2">
            {onDirections && <SecondaryBtn color="#15803D" onClick={() => onDirections({ lat: p.lat, lng: p.lng, friendId: p.userId })}>{labels.directions}</SecondaryBtn>}
            {onMessage && <SecondaryBtn color="#9D174D" onClick={() => onMessage({ id: p.userId, role: p.role, name: p.name })}>{labels.message}</SecondaryBtn>}
          </div>
        </div>
      </>
    );
  }
  return (
    <div
      role="dialog"
      aria-modal="false"
      className="absolute inset-x-2 bottom-2 z-[1200] max-h-[calc(100%-16px)] overflow-y-auto overscroll-contain rounded-[22px] bg-white p-3.5 shadow-[0_18px_44px_-14px_rgba(120,53,15,0.45)] ring-1 ring-[#F3E3DC] sm:inset-x-auto sm:bottom-3 sm:right-[76px] sm:w-[348px]"
    >
      {body}
    </div>
  );
}

function SecondaryBtn({ color, onClick, href, children }: { color: string; onClick?: () => void; href?: string; children: React.ReactNode }) {
  const cls = "flex min-h-[44px] min-w-0 items-center justify-center rounded-[14px] border-[1.5px] bg-white px-2 text-center text-[13px] font-bold leading-tight transition hover:bg-[#FDF8F7]";
  if (href) return <a href={href} className={cls} style={{ borderColor: color, color }}>{children}</a>;
  return <button type="button" onClick={onClick} className={cls} style={{ borderColor: color, color }}>{children}</button>;
}

/** La fiche d'UN rôle d'une personne : Réserver / ami / Itinéraire / profil. */
function RoleCard({ m, r, backBtn, closeBtn, labels, roleName, dist, friend, friendSeen, now, liveLabels, onAddFriend, onDirections, onMessage, onMessageMember }: {
  m: NearbyMember;
  r: PersonRole;
  backBtn: React.ReactNode;
  closeBtn: React.ReactNode;
  labels: CardLabels;
  roleName: (r: string) => string;
  dist: string;
  friend: boolean;
  friendSeen: Record<string, string | null | undefined>;
  now: number;
  liveLabels?: LiveLabels;
  onAddFriend?: (m: NearbyMember) => Promise<"sent" | "already" | "error">;
  onDirections?: (target: { lat: number; lng: number; friendId?: string }) => void;
  onMessage?: (who: { id: string; role: string; name: string }) => void;
  onMessageMember?: (m: NearbyMember) => (() => void) | null;
}) {
  const { t: tUnits, lang: langUnits } = useT();
  const priceUnits = priceUnitLabels(tUnits, langUnits);
  const [state, setState] = useState<"idle" | "busy" | "sent" | "already" | "error">("idle");
  const [bookState, setBookState] = useState<"idle" | "busy" | "error">("idle");
  const [asOwner, setAsOwner] = useState(false);
  const [mine, setMine] = useState(false);
  useEffect(() => { setAsOwner(needsOwnerSwitch()); setMine(isMyProfile(r.id)); }, [r.id]);
  // 25/09 (586, point 9) — fiche propriétaire : ses demandes en cours.
  const [reqCount, setReqCount] = useState(0);
  const k = roleKey(r.role);
  const provider = k === "sitter" || k === "walker";
  // 02/10 (607, NEO) — lien personnel /s/<slug> quand il existe (sinon /p).
  const [sLink, setSLink] = useState<string | null>(null);
  useEffect(() => {
    setSLink(null);
    if (!provider || !/^[a-f0-9]{24}$/i.test(String(r.id))) return;
    let alive = true;
    void getProviderBadge607(k as "sitter" | "walker", String(r.id)).then((b) => { if (alive && b?.slug) setSLink(`/s/${b.slug}`); });
    return () => { alive = false; };
  }, [provider, k, r.id]);
  const price = provider ? formatPriceUnit(r.priceFrom, r.currency, r.priceAlt, priceUnits, r.priceUnit) : null;
  // 620 (Daniel 24/10 : « le prix sur la fiche membre suit le service ») — prix PAR
  // SERVICE envoyés par le serveur : « Garde 22 €/jour · Visite 12 €/visite ».
  const servicePrices: { key: string; text: string }[] = [];
  if (provider) {
    const pl = r.prices ?? m.prices;
    for (const key of ["house_sitting", "home_visit", "day_care", "dog_walking"]) {
      const p0 = pl && pl[key];
      const txt = p0 ? formatPriceUnit(p0.amount, r.currency ?? m.currency, null, priceUnits, p0.unit) : null;
      if (txt) servicePrices.push({ key, text: `${serviceLabel620(langUnits, key)} ${txt}` });
    }
  }
  // Le membre « vu sous ce rôle » : id et rôle du profil choisi (fiche,
  // réservation, demande d'ami, conversation prestataire).
  const asRole: NearbyMember = { ...m, id: r.id, role: k, priceFrom: r.priceFrom, priceAlt: r.priceAlt, priceUnit: r.priceUnit, currency: r.currency, rating: r.rating, reviewsCount: r.reviewsCount };
  const pt = pointOf(m);
  const seenIso = personIdsOf(m).map((x) => friendSeen[x]).find(Boolean) || null;
  const age = seenIso ? Math.max(0, now - new Date(seenIso).getTime()) : null;
  const msgMember = !friend && onMessageMember ? onMessageMember(asRole) : null;
  const rating = (r.rating ?? 0) > 0 ? `★ ${(r.rating ?? 0).toFixed(1)}${(r.reviewsCount ?? 0) > 0 ? ` (${r.reviewsCount})` : ""}` : null;
  return (
    <>
      <div className="flex items-center gap-3">
        {backBtn}
        <Avatar src={m.avatar} name={m.name} role={k} size={52} friend={friend} />
        <div className="min-w-0 flex-1">
          <p className="truncate font-display text-[16px] font-bold leading-tight text-[#231715]">{m.name || roleName(k)}</p>
          <p className="mt-0.5 flex flex-wrap items-center gap-1.5 text-[12px] font-bold" style={{ color: ROLE_DARK[k] }}>
            {roleName(k)}
            {friend && <span className="rounded-full bg-[#FDE7F0] px-2 py-0.5 text-[11px] font-bold text-[#9D174D]">{labels.friend}</span>}
          </p>
          {/* 04/10 (611) — rang (Chiot → Légende), seulement si le serveur l'envoie. */}
          <RankPill611 rank={parseRank611(m.rank)} className="mt-1" />
          {/* 19/10 (618) — pins, seulement si le serveur les envoie. */}
          <PinChips1910 pins={parsePins1910(m.pins)} className="mt-1" />
          {dist && <p className="mt-0.5 text-[11px] font-semibold text-[#8A6B64]">{dist}</p>}
        </div>
        {closeBtn}
      </div>
      {(rating || price || m.identityVerified) && (
        <div className="mt-2.5 flex flex-wrap items-center gap-x-3 gap-y-1 text-[12px] font-bold text-[#231715]">
          {rating && <span className="text-[#8A5A00]">{rating}</span>}
          {price && <span>{labels.priceFrom} {price}</span>}
          {m.identityVerified && <VerifiedPill label={labels.verified} />}
        </div>
      )}
      {servicePrices.length > 0 && (
        <ul data-prices-620="" className="mt-2 flex flex-wrap gap-1.5">
          {servicePrices.map((sp) => (
            <li key={sp.key} className="rounded-full px-2.5 py-1 text-[11px] font-bold" style={{ background: k === "walker" ? "#DEF7E5" : "#E3EFFE", color: ROLE_DARK[k] }}>{sp.text}</li>
          ))}
        </ul>
      )}
      {friend && liveLabels && (
        <div className="mt-2 text-[12px] leading-snug text-[#6E4F48]">
          {age !== null && <span className="block font-semibold text-[#231715]">{age < 60_000 ? liveLabels.seenNow : liveLabels.seenAgo.replace("{ago}", liveLabels.ago(age))}</span>}
          <span className="block">{liveLabels.notSharing}</span>
        </div>
      )}
      {m.approx && <p className="mt-1.5 text-[11px] text-[#8A6B64]">{labels.approx.replace("{km}", String(m.approxKm ?? 1))}</p>}
      <div className="mt-3 flex flex-col gap-2">
        {provider ? (
          <>
            {/* 25/09 (586, point 8) — Réserver TOUJOURS en premier (sauf ma
                propre fiche), « Message » en second, quel que soit mon rôle ;
                un gardien / promeneur réserve avec son profil propriétaire. */}
            {/* 24/10 (620, Daniel : « aussi dans la PawMap ») — « Réserver » ouvre le
                formulaire /posts/create pré-rempli pour ce prestataire (4 services,
                3 modes de dates, visites par jour, estimation), plus la page /book. */}
            {!mine && (
              <a
                href={`/posts/create?for=${k}:${r.id}`}
                data-book-620={`${k}:${r.id}`}
                onClick={async (e) => {
                  if (!asOwner) return;
                  e.preventDefault();
                  if (bookState === "busy") return;
                  setBookState("busy");
                  if (await ensureOwnerProfile()) window.location.href = `/posts/create?for=${k}:${r.id}`;
                  else setBookState("error");
                }}
                className="relative flex min-h-[50px] items-center justify-center gap-2 overflow-hidden rounded-[16px] px-4 text-center text-[14px] font-bold leading-tight text-white shadow-[0_10px_22px_-10px_rgba(23,20,31,0.55)]"
                style={{ background: ROLE_GRAD[k], color: "#fff" }}
              >
                <span className="pointer-events-none absolute inset-x-0 top-0 h-1/2 bg-gradient-to-b from-white/25 to-transparent" />
                <span className="relative">{bookState === "busy" && labels.switchingOwner ? labels.switchingOwner : `${labels.book}${price ? ` · ${labels.priceFrom} ${price}` : ""}`}</span>
              </a>
            )}
            {!mine && asOwner && labels.bookAsOwner && <p className="-mt-0.5 text-center text-[11px] font-bold text-[#9E1F0B]">{labels.bookAsOwner}</p>}
            {bookState === "error" && labels.switchOwnerError && <p className="text-center text-[11px] font-bold text-[#B42318]" role="alert">{labels.switchOwnerError}</p>}
            {!mine && (friend && onMessage ? (
              <SecondaryBtn color="#9D174D" onClick={() => onMessage({ id: r.id, role: k, name: m.name })}>{labels.message}</SecondaryBtn>
            ) : msgMember ? (
              <SecondaryBtn color={ROLE_DARK[k]} onClick={msgMember}>{labels.message}</SecondaryBtn>
            ) : null)}
            <div className="grid grid-cols-2 gap-2">
              {onDirections && pt && (friend || !m.approx) && <SecondaryBtn color="#15803D" onClick={() => onDirections({ lat: pt[0], lng: pt[1], friendId: friend ? r.id : undefined })}>{labels.directions}</SecondaryBtn>}
              {!friend && !mine && onAddFriend && (
                <button
                  type="button"
                  disabled={state === "busy" || state === "sent" || state === "already"}
                  onClick={async () => { setState("busy"); setState(await onAddFriend(asRole)); }}
                  className="flex min-h-[44px] min-w-0 items-center justify-center rounded-[14px] border-[1.5px] border-[#F06AA0] bg-white px-2 text-center text-[13px] font-bold leading-tight text-[#9D174D] disabled:opacity-90"
                >
                  {state === "sent" ? labels.sent : state === "already" ? labels.already : state === "error" ? labels.failed : state === "busy" ? "…" : `+ ${labels.addFriend}`}
                </button>
              )}
            </div>
            <a href={sLink ?? `/p/${k}/${r.id}`} data-profile-link={sLink ? "s" : "p"} className="flex min-h-[44px] items-center justify-center rounded-[14px] px-2 text-center text-[13px] font-bold leading-tight underline-offset-2 hover:underline" style={{ color: ROLE_DARK[k] }}>
              {labels.viewProfile} ›
            </a>
          </>
        ) : (
          <>
            {k === "owner" && !mine && <OwnerRequestsCard ownerId={r.id} onLoaded={setReqCount} />}
            <div className="grid grid-cols-2 gap-2">
              {onDirections && pt && (friend || !m.approx) && <SecondaryBtn color="#15803D" onClick={() => onDirections({ lat: pt[0], lng: pt[1], friendId: friend ? r.id : undefined })}>{labels.directions}</SecondaryBtn>}
              {friend && onMessage ? (
                <SecondaryBtn color="#9D174D" onClick={() => onMessage({ id: r.id, role: k, name: m.name })}>{labels.message}</SecondaryBtn>
              ) : msgMember && reqCount === 0 ? (
                <SecondaryBtn color={ROLE_DARK[k]} onClick={msgMember}>{labels.message}</SecondaryBtn>
              ) : !friend && onAddFriend ? (
                <button
                  type="button"
                  disabled={state === "busy" || state === "sent" || state === "already"}
                  onClick={async () => { setState("busy"); setState(await onAddFriend(asRole)); }}
                  className="flex min-h-[44px] min-w-0 items-center justify-center rounded-[14px] border-[1.5px] border-[#F06AA0] bg-white px-2 text-center text-[13px] font-bold leading-tight text-[#9D174D] disabled:opacity-90"
                >
                  {state === "sent" ? labels.sent : state === "already" ? labels.already : state === "error" ? labels.failed : state === "busy" ? "…" : `+ ${labels.addFriend}`}
                </button>
              ) : null}
            </div>
            {!friend && msgMember && reqCount === 0 && onAddFriend && (
              <button
                type="button"
                disabled={state === "busy" || state === "sent" || state === "already"}
                onClick={async () => { setState("busy"); setState(await onAddFriend(asRole)); }}
                className="flex min-h-[44px] min-w-0 items-center justify-center rounded-[14px] border-[1.5px] border-[#F06AA0] bg-white px-2 text-center text-[13px] font-bold leading-tight text-[#9D174D] disabled:opacity-90"
              >
                {state === "sent" ? labels.sent : state === "already" ? labels.already : state === "error" ? labels.failed : state === "busy" ? "…" : `+ ${labels.addFriend}`}
              </button>
            )}
          </>
        )}
      </div>
    </>
  );
}
