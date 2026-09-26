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
import type { FriendLivePosition, Role } from "@/components/FriendsLiveMap";
import { clusterize, MEMBER_CELL_PX } from "@/lib/mapCluster";
import {
  memberPinHtml,
  photoPinHtml,
  memberClusterHtml,
  placePinHtml,
  placeClusterHtml,
  spotPinHtml,
  spotClusterHtml,
  dominantRole,
  reportPinHtml,
  requestBubbleHtml,
  formatPrice,
  ROLE_COLOR,
  PAWFOLLOW_VIOLET,
  PAWMAP_KEYFRAMES,
  PIN_Z,
  roleKey,
  ROLE_GLYPH,
  showsPriceBubble,
  spotPinAnchor,
  ROLE_SOLID,
  POPPINS,
} from "@/lib/pawmapLegend";
import { safeFly } from "@/lib/safeFly";
import { ensureOwnerProfile, isMyProfile, needsOwnerSwitch } from "@/lib/bookAsOwner";
import { OwnerRequestsCard } from "@/components/OwnerRequestsCard";
import {
  expandRows,
  formatKm,
  isFriendMember,
  isStackedGroup,
  personIdsOf,
  pointOf,
  rolesMatching,
  rolesOf,
  distanceKmTo,
  type PersonRole,
} from "@/lib/memberPersons";

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
};

// ── Icônes (un dessin par famille, dans lib/pawmapLegend) ────────────────────
const placeIconCache = new Map<string, L.DivIcon>();
function placeIcon(category: PoiCategory): L.DivIcon {
  let ic = placeIconCache.get(category);
  if (!ic) {
    // 25/09 — lieux ordinaires plus discrets (26 px) : les personnes passent devant.
    ic = L.divIcon({ className: "", html: placePinHtml(category, 26), iconSize: [26, 34], iconAnchor: [13, 33], popupAnchor: [0, -30] });
    placeIconCache.set(category, ic);
  }
  return ic;
}
// 590 (§6) — goutte 40 px noir / or à TOUS les zooms, pointe = position.
function spotIcon(type: PawSpotType, golden: boolean, label?: string | null): L.DivIcon {
  return L.divIcon({ className: "", html: spotPinHtml(type, golden, { label }), iconSize: [40, 50], iconAnchor: spotPinAnchor(40), popupAnchor: [0, -44] });
}
const reportIcon = () => L.divIcon({ className: "", html: reportPinHtml(30), iconSize: [30, 30], iconAnchor: [15, 15], popupAnchor: [0, -14] });
function memberIcon(m: NearbyMember, caption: string | null, roles: PersonRole[], bubble: string | null, dark: boolean): L.DivIcon {
  return L.divIcon({
    className: "",
    html: memberPinHtml({
      role: roles[0]?.role || m.role,
      roles: roles.map((r) => r.role),
      premium: !!(m.isPremiumOnly ?? m.isPremium),
      boosted: !!m.isBoosted,
      pawFollow: !!m.hasPawFollow,
      online: m.approx ? null : m.isOnline !== false,
      avatar: m.avatar || null,
      caption,
      priceBubble: bubble,
      verified: !!m.identityVerified,
      dark,
      size: 46,
    }),
    iconSize: [46, 46],
    iconAnchor: [23, 23],
    popupAnchor: [0, -26],
  });
}
/** Ami à sa position de PROFIL (floutée) : photo, anneau rose, pas de direct. */
function friendProfileIcon(m: NearbyMember, premium: boolean, roles: PersonRole[], caption?: string | null, bubble?: string | null): L.DivIcon {
  return L.divIcon({
    className: "",
    // 25/09 (585, bug 11) — un ami boosté garde sa lueur turquoise + fusée.
    html: photoPinHtml({ role: roles[0]?.role || m.role, name: m.name, avatar: m.avatar, premium, boosted: !!m.isBoosted, roles: roles.map((r) => r.role), caption, priceBubble: bubble }),
    iconSize: [50, 50],
    iconAnchor: [25, 25],
    popupAnchor: [0, -28],
  });
}
function meIcon(o: { role: string; name: string; avatar?: string | null; premium?: boolean; meLabel?: string; friendsOnly?: boolean; boosted?: boolean; pawFollow?: boolean }): L.DivIcon {
  return L.divIcon({
    className: "",
    html: `<div style="position:relative;width:56px;height:56px;"><div style="position:absolute;inset:-8px;border-radius:50%;border:3px solid ${ROLE_COLOR[roleKey(o.role)]};animation:hps-pulse 2s ease-out infinite;"></div>${photoPinHtml({ ...o, me: true })}</div>`,
    iconSize: [56, 56],
    iconAnchor: [28, 28],
    popupAnchor: [0, -32],
  });
}
function requestIcon(r: MapRequest, mineLabel: string): L.DivIcon {
  return L.divIcon({
    className: "",
    html: requestBubbleHtml({ service: r.service, priceLabel: r.priceLabel, boosted: r.boosted, mine: r.mine, mineLabel }),
    // 590 — bulle 26 + pointe 7 : la pointe touche la position (floutée).
    iconSize: [96, 34],
    iconAnchor: [48, 34],
    popupAnchor: [0, -32],
  });
}

// ── Petits composants ────────────────────────────────────────────────────────
function FlyToFocus({ target }: { target: { lat: number; lng: number; ts: number; zoom?: number; duration?: number } | null }) {
  const map = useMap();
  useEffect(() => {
    if (!target) return;
    // Zoom demandé (ville = 12, ma position = 14), sinon zoom de rue lisible
    // (~17) ; vol en douceur (0,9 s), jamais pendant une autre animation.
    safeFly(map, [target.lat, target.lng], target.zoom ?? Math.max(map.getZoom(), 17), target.duration ?? 0.9);
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
      safeFly(map, [target.lat, target.lng], FRIEND_ZOOM, 0.8);
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
function RouteFit({ points }: { points: { lat: number; lng: number }[] | null }) {
  const map = useMap();
  const key = points && points.length > 1 ? `${points.length}-${points[0].lat}-${points[points.length - 1].lng}` : "";
  useEffect(() => {
    if (!points || points.length < 2) return;
    try {
      map.stop();
      map.fitBounds(L.latLngBounds(points.map((p) => [p.lat, p.lng] as [number, number])), { paddingTopLeft: [70, 120], paddingBottomRight: [70, 40], maxZoom: 17 });
    } catch { /* carte pas prête */ }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);
  return null;
}

function PlaceCluster({ center, count, category }: { center: [number, number]; count: number; category: PoiCategory | null }) {
  const map = useMap();
  const icon = useMemo(() => L.divIcon({ className: "", html: placeClusterHtml(count, category), iconSize: [32, 32], iconAnchor: [16, 16] }), [count, category]);
  return <Marker position={center} icon={icon} zIndexOffset={PIN_Z.place + 50} eventHandlers={{ click: () => safeFly(map, center, Math.min(map.getZoom() + 2.2, 19), 0.8) }} />;
}
/**
 * Groupe de membres (25/09, PawMap 585) : si les points sont SUPERPOSÉS (même
 * position à ~25 m près, ou la même personne) le clic ouvre directement la
 * liste — zoomer ne les séparerait jamais. Sinon on cadre le groupe pour que
 * ses points se séparent vraiment ; déjà au zoom rue = liste.
 */
function MemberCluster({ center, items, onList, friendSet }: { center: [number, number]; items: NearbyMember[]; onList: (l: NearbyMember[]) => void; friendSet: Set<string> }) {
  const map = useMap();
  const count = items.length;
  const dom = dominantRole(items.map((m) => m.role));
  const hasFriend = items.some((m) => isFriendMember(m, friendSet));
  const sz = count >= 10 ? 44 : 40;
  const icon = useMemo(() => L.divIcon({ className: "", html: memberClusterHtml(count, dom, hasFriend), iconSize: [sz, sz], iconAnchor: [sz / 2, sz / 2] }), [count, dom, hasFriend, sz]);
  const onClick = () => {
    if (isStackedGroup(items) || map.getZoom() >= 17) { onList(items); return; }
    const pts = items.map(pointOf).filter((p): p is [number, number] => !!p);
    try {
      map.stop();
      map.flyToBounds(L.latLngBounds(pts), { padding: [70, 70], maxZoom: 18, duration: 0.8 });
    } catch {
      safeFly(map, center, Math.min(map.getZoom() + 2.2, 18), 0.8);
    }
  };
  return <Marker position={center} icon={icon} zIndexOffset={PIN_Z.member} eventHandlers={{ click: onClick }} />;
}
function SpotCluster({ center, count }: { center: [number, number]; count: number }) {
  const map = useMap();
  const icon = useMemo(() => L.divIcon({ className: "", html: spotClusterHtml(count), iconSize: [36, 36], iconAnchor: [18, 18] }), [count]);
  return <Marker position={center} icon={icon} zIndexOffset={PIN_Z.spot} eventHandlers={{ click: () => safeFly(map, center, Math.min(map.getZoom() + 2.2, 19), 0.8) }} />;
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
function LiveFriendMarker({ p, isFamily, isPremium, followed, labels, onOpen }: {
  p: FriendLivePosition;
  isFamily: boolean;
  isPremium?: boolean;
  followed: boolean;
  labels?: LiveLabels;
  onOpen: () => void;
}) {
  const lost = p.state === "lost";
  const icon = useMemo(
    () => L.divIcon({
      className: "",
      html: photoPinHtml({ role: p.role, name: p.name, avatar: p.avatar, premium: isPremium, pawFollow: isFamily && !followed, followed, lost, caption: lost ? labels?.lost : null, online: lost ? false : true }),
      iconSize: [50, 50],
      iconAnchor: [25, 25],
    }),
    [p.role, p.name, p.avatar, isPremium, isFamily, followed, lost, labels?.lost],
  );
  return <Marker position={[p.lat, p.lng]} icon={icon} zIndexOffset={followed ? PIN_Z.friendFollowed : PIN_Z.friend} eventHandlers={{ click: onOpen }} />;
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
};

/** 590 (§4) — la carte focus : 1er clic sur une personne ou une demande. */
type Focus = {
  key: string;
  lat: number;
  lng: number;
  name: string;
  /** owner | sitter | walker (anneau + bouton « Profil »). */
  role: string;
  avatar?: string | null;
  info: string;
  live?: boolean;
  friend?: boolean;
  icon?: "home" | "walk" | "paw";
  /** Ami en direct : son tracé de balade s'affiche. */
  liveId?: string;
  open: () => void;
};

// §9 — palettes « bijou » des rôles (clair, moyen, foncé) + rose ami.
const JEWEL_ROLE: Record<string, [string, string, string]> = {
  owner: ["#FF8A66", "#E8452F", "#B8231A"],
  sitter: ["#8AB8FF", "#3B78E8", "#1F4FBF"],
  walker: ["#7FE39A", "#2E9E48", "#1D7A34"],
  friend: ["#F47BB2", "#E35A9A", "#D6377F"],
};
const jewelGrad = (p: [string, string, string]) => `linear-gradient(170deg,${p[0]},${p[1]} 50%,${p[2]})`;

/** Efface la carte focus au clic sur la carte vide ou au début d'un glisser. */
function FocusWatcher({ onClear }: { onClear: () => void }) {
  useMapEvents({ click: onClear, dragstart: onClear });
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
  members = [],
  memberRoleLabels,
  cardLabels,
  wantedRoles = ["sitter", "walker", "owner"],
  distanceFrom = null,
  onMapReady,
  satellite = false,
  onAddFriend,
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
  onDirections,
  directionsLabel = "→",
  formatOpenStatus,
  callLabel = "",
  requests = [],
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
  focusTarget?: { lat: number; lng: number; ts: number; zoom?: number; duration?: number } | null;
  onFriendFocus?: (p: FriendLivePosition) => void;
  /** Ami suivi en direct (zoom de suivi « joli »). */
  followUserId?: string | null;
  onFollowPause?: () => void;
  followLabel?: string;
  routePoints?: { lat: number; lng: number }[] | null;
  routeColor?: string;
  routeSteps?: RouteStep[] | null;
  onDirections?: (target: { lat: number; lng: number }) => void;
  directionsLabel?: string;
  formatOpenStatus?: (raw: string) => { label: string; open: boolean } | null;
  callLabel?: string;
  /** Demandes des propriétaires (bulle orange), positions floutées par la page. */
  requests?: MapRequest[];
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
  const showPrice = zoomLevel >= 15;
  // 590 (§1, §4) — au zoom rue : le PRÉNOM sous le rond ; le prix part dans
  // une bulle à la couleur du service AU-DESSUS du rond, seulement s'il est
  // de l'autre côté du marché (propriétaire → tarifs ; prestataire → rien).
  const memberCaption = (m: NearbyMember): string | null => {
    if (!showPrice) return null;
    const first = (m.name || "").trim().split(/\s+/)[0];
    return first || memberRoleLabels?.[m.role] || null;
  };
  const priceFor = (role: string, amount?: number | null, currency?: string | null): string | null => {
    const k = roleKey(role);
    if (k === "owner" || !showsPriceBubble(userRole, k)) return null;
    return formatPrice(amount, currency);
  };
  const memberBubble = (role: string, amount?: number | null, currency?: string | null): string | null =>
    showPrice ? priceFor(role, amount, currency) : null;

  const poiClusters = useMemo(
    () => clusterize(pois, zoomLevel, (poi) => (Array.isArray(poi.location?.coordinates) && poi.location.coordinates.length >= 2 ? [poi.location.coordinates[1], poi.location.coordinates[0]] : null)),
    [pois, zoomLevel],
  );
  // 587 (point 6) — les AMIS ne sont jamais regroupés avec des inconnus :
  // exclus du regroupement, dessinés un par un au-dessus des membres, à
  // tous les zooms, sans plafond.
  const friendMembers = useMemo(() => members.filter((m) => isFriendMember(m, friendSet)), [members, friendSet]);
  const otherMembers = useMemo(() => members.filter((m) => !isFriendMember(m, friendSet)), [members, friendSet]);
  const memberClusters = useMemo(
    () => clusterize(otherMembers, zoomLevel, (m) => (Array.isArray(m.location?.coordinates) && m.location.coordinates.length >= 2 ? [m.location.coordinates[1], m.location.coordinates[0]] : null), MEMBER_CELL_PX),
    [otherMembers, zoomLevel],
  );
  const spotClusters = useMemo(() => clusterize(spots, zoomLevel, (s) => [s.lat, s.lng]), [spots, zoomLevel]);

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
    () => (followed ? { lat: followed.lat, lng: followed.lng, key: followed.userId } : null),
    [followed?.lat, followed?.lng, followed?.userId], // eslint-disable-line react-hooks/exhaustive-deps
  );
  const trail = followUserId ? trails.current.get(followUserId) || [] : [];

  const requestMineLabel = requestLabels?.mine || "";

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
    const roles = wanted.length ? [...wanted, ...rolesOf(m).filter((r) => !wanted.some((w) => w.id === r.id))] : rolesOf(m);
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
  }, [focusFriend?.ts]); // eslint-disable-line react-hooks/exhaustive-deps

  const dirClose = onDirections
    ? (target: { lat: number; lng: number }) => { try { mapObj?.closePopup(); } catch { /* */ } onDirections(target); }
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
  const tapFocus = (f: Focus) => {
    if (!focusLabels || !mapObj) { f.open(); return; }
    if (focusKeyRef.current === f.key) {
      setFocus(null);
      prevViewRef.current = null;
      f.open();
      return;
    }
    if (!prevViewRef.current) {
      const c = mapObj.getCenter();
      prevViewRef.current = { c: [c.lat, c.lng], z: mapObj.getZoom() };
    }
    setSheet(null);
    setOpenReq(null);
    setFocus(f);
    try {
      const z = Math.min(18, Math.max(mapObj.getZoom() + 1.5, 15));
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
  const personFocus = (m: NearbyMember, role: string, price: number | null | undefined, currency: string | null | undefined, open: () => void, friend: boolean): Focus | null => {
    const at = pointOf(m);
    if (!at) return null;
    const k = roleKey(role);
    const pr = priceFor(k, price, currency);
    const km = kmFrom(at);
    return {
      key: `p:${m.id}`,
      lat: at[0],
      lng: at[1],
      name: m.name || focusLabels?.roles[k] || "",
      role: k,
      avatar: m.avatar,
      info: [pr, km].filter(Boolean).join(" · ") || focusLabels?.roles[k] || "",
      friend,
      icon: k === "walker" ? "walk" : k === "sitter" ? "home" : "paw",
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
  const walkColor = walkPos ? ROLE_SOLID[roleKey(walkPos.role)] : ROLE_SOLID.owner;

  return (
    <div className="relative h-full min-h-[420px] w-full overflow-hidden rounded-[28px] max-lg:rounded-none">
      <style dangerouslySetInnerHTML={{ __html: PAWMAP_KEYFRAMES }} />
      <MapContainer ref={setMapObj} center={center} zoom={initialZoom} minZoom={3} maxZoom={19} style={{ height: "100%", width: "100%" }} scrollWheelZoom zoomControl={false}>
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
        <RouteFit points={routePoints} />
        <FollowController target={followTarget} onUserGesture={() => onFollowPause?.()} />
        <FocusWatcher onClear={clearFocus} />

        {/* Ma position : cercle de précision honnête + « Moi » (56 px). */}
        {userLocation && userAccuracy != null && userAccuracy > 25 && (
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

        {/* LIEUX : goutte par type, carré blanc pour un groupe. */}
        {poiClusters.map((g, i) =>
          g.items.length > 1 ? (
            <PlaceCluster key={`pc-${i}-${g.items.length}-${g.center[0].toFixed(4)}`} center={g.center} count={g.items.length} category={new Set(g.items.map((p) => p.category)).size === 1 ? g.items[0].category : null} />
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
          g.items.length > 1 ? <SpotCluster key={`sc-${i}-${g.items.length}-${g.center[0].toFixed(4)}`} center={g.center} count={g.items.length} /> : null,
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
            <Marker key={`report-${r._id}`} position={[c[1], c[0]]} icon={reportIcon()} zIndexOffset={PIN_Z.report}>
              <Popup>
                <div className="text-sm" style={{ minWidth: 150 }}>
                  <div className="mb-1 font-bold" style={{ color: "#D32F2F" }}>{reportTypeLabels?.[r.type] || r.type}</div>
                  {r.note ? <div className="mb-1 text-xs text-ink-muted">{r.note}</div> : null}
                  {typeof r.confirmationsCount === "number" ? <div className="text-xs text-ink-muted">✓ {r.confirmationsCount}</div> : null}
                </div>
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
            icon={requestIcon(r, requestMineLabel)}
            zIndexOffset={PIN_Z.request + (r.mine ? 200 : 0)}
            eventHandlers={{
              click: () => {
                if (r.mine || !focusLabels) { clearFocus(); setOpenReq(r); return; }
                tapFocus({
                  key: `req:${r.id}`,
                  lat: r.lat,
                  lng: r.lng,
                  name: r.ownerName ? `${firstOf(r.ownerName)} · ${focusLabels.request}` : requestLabels?.title || focusLabels.request,
                  role: "owner",
                  avatar: r.ownerAvatar || null,
                  info: [r.service === "walk" ? focusLabels.walk : focusLabels.sitting, r.priceLabel].filter(Boolean).join(" · "),
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
              {openReq.locationLabel && <div className="mt-0.5 text-xs font-semibold text-ink">📍 {openReq.locationLabel}</div>}
              {openReq.body && <div className="mt-1 line-clamp-3 text-xs text-ink-muted">{openReq.body}</div>}
              {!openReq.mine && onOfferService && requestLabels && (
                <button type="button" onClick={() => onOfferService(openReq.id)} className="mt-2 flex min-h-[40px] w-full items-center justify-center rounded-full px-3 text-xs font-bold text-white" style={{ background: `linear-gradient(90deg, #D83C28, #B92425)` }}>
                  {requestLabels.offer}
                </button>
              )}
            </div>
          </RequestPopup>
        )}

        {/* MEMBRES : UNE personne = UN rond (liseré de chacun de ses rôles),
            rond de groupe à la couleur dominante. Clic = fiche du bas. */}
        {memberClusters.map((g, i) =>
          g.items.length > 1 ? <MemberCluster key={`mc-${i}-${g.items.length}-${g.center[0].toFixed(4)}`} center={g.center} items={g.items} onList={(items) => openSheet({ kind: "list", items }, g.center)} friendSet={friendSet} /> : null,
        )}
        {[...memberClusters.filter((g) => g.items.length === 1).map((g) => g.items[0]), ...friendMembers].map((m) => {
          const pt = pointOf(m);
          if (!pt) return null;
          const isFriend = isFriendMember(m, friendSet);
          // Un ami qui partage en direct a déjà son rond « en direct » : pas de doublon.
          if (isFriend && personIdsOf(m).some((x) => liveIdSet.has(x))) return null;
          const wanted = rolesMatching(m, wantedRoles);
          const roles = wanted.length ? [...wanted, ...rolesOf(m).filter((r) => !wanted.some((w) => w.id === r.id))] : rolesOf(m);
          const open = () => openSheet(roles.length > 1 ? { kind: "person", m } : { kind: "role", m, r: roles[0] }, pt);
          if (isFriend) {
            const prem = personIdsOf(m).some((x) => premiumSet.has(x)) || !!m.isPremium;
            // « Vu il y a X » sous son rond (dernier signe de vie connu).
            const seenIso = personIdsOf(m).map((x) => friendSeen?.[x]).find(Boolean) || null;
            const seenMs = seenIso ? new Date(seenIso).getTime() : NaN;
            const caption = liveLabels && Number.isFinite(seenMs)
              ? (now - seenMs < 60000 ? liveLabels.seenNow : liveLabels.seenAgo.replace("{ago}", liveLabels.ago(now - seenMs)))
              : null;
            const fBubble = memberBubble(roles[0].role, roles[0].priceFrom ?? m.priceFrom, roles[0].currency ?? m.currency);
            const fOpen = () => flyToFriend(m);
            return <Marker key={`friend-${m.id}`} position={pt} icon={friendProfileIcon(m, prem, roles, caption, fBubble)} zIndexOffset={PIN_Z.friend} eventHandlers={{ click: () => { const f = personFocus(m, roles[0].role, roles[0].priceFrom ?? m.priceFrom, roles[0].currency ?? m.currency, fOpen, true); if (f) tapFocus(f); else fOpen(); } }} />;
          }
          const r0 = roles[0];
          const pFrom = r0.priceFrom ?? m.priceFrom;
          const pCur = r0.currency ?? m.currency;
          return (
            <Marker key={`member-${m.id}`} position={pt} icon={memberIcon(m, memberCaption({ ...m, role: r0.role }), roles, memberBubble(r0.role, pFrom, pCur), dark)} zIndexOffset={m.isBoosted ? PIN_Z.memberBoosted : PIN_Z.member} eventHandlers={{ click: () => { const f = personFocus(m, r0.role, pFrom, pCur, open, false); if (f) tapFocus(f); else open(); } }} />
          );
        })}

        {/* AMIS en direct : photo + anneau rose ; tracé violet du suivi. */}
        {trail.length > 1 && walkTrail.length < 2 && <Polyline positions={trail} pathOptions={{ color: PAWFOLLOW_VIOLET, weight: 5, opacity: 0.85, lineCap: "round" }} />}
        {/* 590 (§5) — balade en direct : halo blanc 7 px + trait du rôle
            3,5 px en pas qui avancent (pointillés animés), départ = rond blanc. */}
        {walkTrail.length > 1 && (
          <>
            <Polyline key={`wh-${walkId}`} positions={walkTrail} pathOptions={{ color: "#FFFFFF", weight: 7, opacity: 1, lineCap: "round", lineJoin: "round" }} />
            <Polyline key={`wt-${walkId}`} positions={walkTrail} pathOptions={{ color: walkColor, weight: 3.5, opacity: 1, lineCap: "round", lineJoin: "round", dashArray: "1 9", className: "hps-walk-trail" }} />
            <CircleMarker key={`ws-${walkId}`} center={walkTrail[0]} radius={5} pathOptions={{ color: walkColor, weight: 3, fillColor: "#FFFFFF", fillOpacity: 1 }} />
          </>
        )}
        {friendPositions.map((p) => (
          <LiveFriendMarker
            key={`live-${p.userId}`}
            p={p}
            isFamily={familySet.has(p.userId)}
            isPremium={premiumSet.has(p.userId)}
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
        ))}

        {/* ITINÉRAIRE : polyline couleur du mode + repères de virage. */}
        {routePoints && routePoints.length > 1 && (
          <Polyline positions={routePoints.map((p) => [p.lat, p.lng] as [number, number])} pathOptions={{ color: routeColor, weight: 5, opacity: 0.9 }} />
        )}
        {routeSteps &&
          routeSteps
            .filter((s) => s.type !== 1 && s.type !== 2 && s.type !== 3)
            .map((s, i) => (
              <CircleMarker key={`step-${i}`} center={[s.lat, s.lng]} radius={s.type >= 4 && s.type <= 6 ? 7 : 5} pathOptions={{ color: routeColor, weight: 2, fillColor: "#ffffff", fillOpacity: 1 }}>
                <Tooltip direction="top" offset={[0, -6]}>
                  <span className="text-xs">{stepGlyph(s.type)} {s.instruction}</span>
                </Tooltip>
              </CircleMarker>
            ))}
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
          <span className="grid h-[42px] w-[42px] shrink-0 place-items-center rounded-full p-[2.5px]" style={{ background: jewelGrad(pal) }}>
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
            </span>
            {f.info && <span className="block truncate text-[11.5px] font-medium leading-snug" style={{ color: sub, fontFamily: POPPINS }}>{f.info}</span>}
          </span>
        </button>
        <button
          type="button"
          onClick={onOpen}
          aria-label={labels.profile}
          className="relative inline-flex h-[34px] shrink-0 items-center overflow-hidden rounded-full px-2 text-[12px] font-bold text-white transition-transform duration-150 hover:-translate-y-px active:scale-95 min-[420px]:pl-3 min-[420px]:pr-1.5"
          style={{ background: jewelGrad(pal), boxShadow: `0 5px 10px -4px ${pal[1]}, inset 0 0 0 1.5px rgba(255,255,255,.3)`, fontFamily: POPPINS }}
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
  owner: "linear-gradient(90deg,#D83C28,#B92425)",
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
  onDirections?: (target: { lat: number; lng: number }) => void;
  onMessage?: (who: { id: string; role: string; name: string }) => void;
  onMessageMember?: (m: NearbyMember) => (() => void) | null;
  onFollow?: (p: FriendLivePosition) => void;
  /** 590 (§1) — prix de l'autre côté du marché seulement dans les listes. */
  viewerRole?: string;
}) {
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
    const price = k !== "owner" && showsPriceBubble(viewerRole, k) ? formatPrice(r.priceFrom, r.currency) : null;
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
    const roles = [...wanted, ...rolesOf(m).filter((r) => !wanted.some((w) => w.id === r.id))];
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
          {roles.map((r) => <RoleRow key={`pr-${r.id}`} m={m} r={r} friend={friend} onSee={() => setSheet({ kind: "role", m, r, back: sheet })} />)}
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
            {onDirections && <SecondaryBtn color="#15803D" onClick={() => onDirections({ lat: p.lat, lng: p.lng })}>{labels.directions}</SecondaryBtn>}
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
  onDirections?: (target: { lat: number; lng: number }) => void;
  onMessage?: (who: { id: string; role: string; name: string }) => void;
  onMessageMember?: (m: NearbyMember) => (() => void) | null;
}) {
  const [state, setState] = useState<"idle" | "busy" | "sent" | "already" | "error">("idle");
  const [bookState, setBookState] = useState<"idle" | "busy" | "error">("idle");
  const [asOwner, setAsOwner] = useState(false);
  const [mine, setMine] = useState(false);
  useEffect(() => { setAsOwner(needsOwnerSwitch()); setMine(isMyProfile(r.id)); }, [r.id]);
  // 25/09 (586, point 9) — fiche propriétaire : ses demandes en cours.
  const [reqCount, setReqCount] = useState(0);
  const k = roleKey(r.role);
  const provider = k === "sitter" || k === "walker";
  const price = provider ? formatPrice(r.priceFrom, r.currency) : null;
  // Le membre « vu sous ce rôle » : id et rôle du profil choisi (fiche,
  // réservation, demande d'ami, conversation prestataire).
  const asRole: NearbyMember = { ...m, id: r.id, role: k, priceFrom: r.priceFrom, currency: r.currency, rating: r.rating, reviewsCount: r.reviewsCount };
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
          {dist && <p className="mt-0.5 text-[11px] font-semibold text-[#8A6B64]">{dist}</p>}
        </div>
        {closeBtn}
      </div>
      {(rating || price || m.identityVerified) && (
        <div className="mt-2.5 flex flex-wrap items-center gap-x-3 gap-y-1 text-[12px] font-bold text-[#231715]">
          {rating && <span className="text-[#8A5A00]">{rating}</span>}
          {price && <span>{labels.priceFrom} {price}</span>}
          {m.identityVerified && <span className="text-[#15803D]">✓ {labels.verified}</span>}
        </div>
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
            {!mine && (
              <a
                href={`/book/${k}/${r.id}`}
                onClick={async (e) => {
                  if (!asOwner) return;
                  e.preventDefault();
                  if (bookState === "busy") return;
                  setBookState("busy");
                  if (await ensureOwnerProfile()) window.location.href = `/book/${k}/${r.id}`;
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
              {onDirections && pt && <SecondaryBtn color="#15803D" onClick={() => onDirections({ lat: pt[0], lng: pt[1] })}>{labels.directions}</SecondaryBtn>}
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
            <a href={`/p/${k}/${r.id}`} className="flex min-h-[44px] items-center justify-center rounded-[14px] px-2 text-center text-[13px] font-bold leading-tight underline-offset-2 hover:underline" style={{ color: ROLE_DARK[k] }}>
              {labels.viewProfile} ›
            </a>
          </>
        ) : (
          <>
            {k === "owner" && !mine && <OwnerRequestsCard ownerId={r.id} onLoaded={setReqCount} />}
            <div className="grid grid-cols-2 gap-2">
              {onDirections && pt && <SecondaryBtn color="#15803D" onClick={() => onDirections({ lat: pt[0], lng: pt[1] })}>{labels.directions}</SecondaryBtn>}
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
