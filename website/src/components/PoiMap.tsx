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
  ZoomControl,
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
} from "@/lib/pawmapLegend";
import { safeFly } from "@/lib/safeFly";

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
function spotIcon(type: PawSpotType, golden: boolean): L.DivIcon {
  const size = golden ? 40 : 32;
  return L.divIcon({ className: "", html: spotPinHtml(type, golden), iconSize: [size, Math.round(size * 1.3)], iconAnchor: [size / 2, Math.round(size * 1.3) - 1], popupAnchor: [0, -Math.round(size * 1.2)] });
}
const reportIcon = () => L.divIcon({ className: "", html: reportPinHtml(30), iconSize: [30, 30], iconAnchor: [15, 15], popupAnchor: [0, -14] });
function memberIcon(m: NearbyMember, caption: string | null): L.DivIcon {
  return L.divIcon({
    className: "",
    html: memberPinHtml({
      role: m.role,
      premium: !!(m.isPremiumOnly ?? m.isPremium),
      boosted: !!m.isBoosted,
      pawFollow: !!m.hasPawFollow,
      online: m.approx ? null : m.isOnline !== false,
      avatar: m.avatar || null,
      caption,
      size: 46,
    }),
    iconSize: [46, 46],
    iconAnchor: [23, 23],
    popupAnchor: [0, -26],
  });
}
/** Ami à sa position de PROFIL (floutée) : photo, anneau rose, pas de direct. */
function friendProfileIcon(m: NearbyMember, premium: boolean): L.DivIcon {
  return L.divIcon({
    className: "",
    html: photoPinHtml({ role: m.role, name: m.name, avatar: m.avatar, premium }),
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
    iconSize: [80, 44],
    iconAnchor: [40, 42],
    popupAnchor: [0, -40],
  });
}

// ── Petits composants ────────────────────────────────────────────────────────
function FlyToFocus({ target }: { target: { lat: number; lng: number; ts: number; zoom?: number } | null }) {
  const map = useMap();
  useEffect(() => {
    if (!target) return;
    // Zoom demandé (ville = 12, ma position = 14), sinon zoom de rue lisible
    // (~17) ; vol en douceur (0,9 s), jamais pendant une autre animation.
    safeFly(map, [target.lat, target.lng], target.zoom ?? Math.max(map.getZoom(), 17));
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
      safeFly(map, [target.lat, target.lng], Math.max(map.getZoom(), 16.5), 1);
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
/** Groupe de membres : zoom doux ; au zoom rue et toujours collés = liste. */
function MemberCluster({ center, items, onList, friendSet }: { center: [number, number]; items: NearbyMember[]; onList: (l: NearbyMember[]) => void; friendSet: Set<string> }) {
  const map = useMap();
  const count = items.length;
  const dom = dominantRole(items.map((m) => m.role));
  const hasFriend = items.some((m) => friendSet.has(m.id) || (m as NearbyMember & { isFriend?: boolean }).isFriend === true);
  const sz = count >= 10 ? 44 : 40;
  const icon = useMemo(() => L.divIcon({ className: "", html: memberClusterHtml(count, dom, hasFriend), iconSize: [sz, sz], iconAnchor: [sz / 2, sz / 2] }), [count, dom, hasFriend, sz]);
  return (
    <Marker
      position={center}
      icon={icon}
      zIndexOffset={PIN_Z.member}
      eventHandlers={{ click: () => (map.getZoom() >= 17 ? onList(items) : safeFly(map, center, Math.min(map.getZoom() + 2.2, 19), 0.8)) }}
    />
  );
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
 * est suivi. Un clic ouvre SA fiche (jamais un suivi lancé sans le dire) :
 * « Suivre la balade · en direct », Itinéraire, Message.
 */
function LiveFriendMarker({ p, isFamily, isPremium, roleLabel, followed, now, labels, onFollow, onDirections, directionsLabel, onMessage }: {
  p: FriendLivePosition;
  isFamily: boolean;
  isPremium?: boolean;
  roleLabel: string;
  followed: boolean;
  now: number;
  labels?: LiveLabels;
  onFollow?: () => void;
  onDirections?: (target: { lat: number; lng: number }) => void;
  directionsLabel?: string;
  onMessage?: () => void;
}) {
  const lost = p.state === "lost";
  const icon = useMemo(
    () => L.divIcon({
      className: "",
      html: photoPinHtml({ role: p.role, name: p.name, avatar: p.avatar, premium: isPremium, pawFollow: isFamily && !followed, followed, lost, caption: lost ? labels?.lost : null, online: lost ? false : true }),
      iconSize: [50, 50],
      iconAnchor: [25, 25],
      popupAnchor: [0, -28],
    }),
    [p.role, p.name, p.avatar, isPremium, isFamily, followed, lost, labels?.lost],
  );
  const age = p.lastSeenAt ? Math.max(0, now - new Date(p.lastSeenAt).getTime()) : 0;
  const color = ROLE_COLOR[roleKey(p.role)];
  return (
    <Marker position={[p.lat, p.lng]} icon={icon} zIndexOffset={followed ? PIN_Z.friendFollowed : PIN_Z.friend}>
      <Popup autoPan>
        <div style={{ minWidth: 210 }}>
          <div className="flex items-center gap-3">
            <span className="h-11 w-11 shrink-0 overflow-hidden rounded-full" style={{ border: "3px solid #F06AA0", background: color }}>
              {p.avatar ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={p.avatar} alt="" className="h-full w-full object-cover" />
              ) : null}
            </span>
            <div className="min-w-0">
              <div className="truncate text-[15px] font-bold text-[#231715]">{p.name}</div>
              <div className="text-xs font-semibold" style={{ color }}>{roleLabel}</div>
            </div>
          </div>
          {labels && (
            <div className="mt-2 inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-[11px] font-bold" style={lost ? { background: "#FFF4E5", color: "#9A3412" } : { background: "#EDE9FE", color: "#5B21B6" }}>
              <span className="inline-block h-2 w-2 rounded-full" style={{ background: lost ? "#EA580C" : "#7C3AED" }} />
              {lost ? labels.lost : labels.live} · {labels.ago(age)}
            </div>
          )}
          <div className="mt-3 flex flex-col gap-2">
            {onFollow && labels && (
              <button type="button" onClick={onFollow} className="flex min-h-[44px] items-center justify-center gap-2 rounded-[14px] px-4 text-sm font-bold text-white" style={{ background: "linear-gradient(90deg,#7C3AED,#6D28D9)" }}>
                {labels.follow}
              </button>
            )}
            <div className="flex gap-2">
              {onDirections && (
                <button type="button" onClick={() => onDirections({ lat: p.lat, lng: p.lng })} className="flex min-h-[40px] flex-1 items-center justify-center rounded-[12px] border-[1.5px] px-3 text-xs font-bold" style={{ borderColor: "#16A34A", color: "#15803D" }}>
                  {directionsLabel || "→"}
                </button>
              )}
              {onMessage && labels && (
                <button type="button" onClick={onMessage} className="flex min-h-[40px] flex-1 items-center justify-center rounded-[12px] border-[1.5px] px-3 text-xs font-bold" style={{ borderColor: "#2563EB", color: "#1E4FB0" }}>
                  {labels.message}
                </button>
              )}
            </div>
          </div>
        </div>
      </Popup>
    </Marker>
  );
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
  members = [],
  memberRoleLabels,
  memberLabels,
  onAddFriend,
  onSpotVisit,
  friendPositions = [],
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
  memberLabels?: { priceFrom?: string; addFriend: string; sent: string; already: string; failed: string; book: string; approx: string; verified?: string; viewProfile?: string };
  onAddFriend?: (m: NearbyMember) => Promise<"sent" | "already" | "error">;
  onSpotVisit?: (id: string) => void;
  friendPositions?: FriendLivePosition[];
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
  focusTarget?: { lat: number; lng: number; ts: number } | null;
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
}) {
  const familySet = useMemo(() => new Set(familyIds), [familyIds]);
  const friendSet = useMemo(() => new Set(friendIds), [friendIds]);
  const liveIdSet = useMemo(() => new Set(friendPositions.map((p) => p.userId)), [friendPositions]);
  const [memberList, setMemberList] = useState<NearbyMember[] | null>(null);
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
  const memberCaption = (m: NearbyMember): string | null => {
    if (!showPrice) return null;
    const first = (m.name || "").trim().split(/\s+/)[0];
    const price = m.role !== "owner" ? formatPrice(m.priceFrom, m.currency) : null;
    return [first, memberRoleLabels?.[m.role] || null, price].filter(Boolean).join(" · ") || null;
  };

  const poiClusters = useMemo(
    () => clusterize(pois, zoomLevel, (poi) => (Array.isArray(poi.location?.coordinates) && poi.location.coordinates.length >= 2 ? [poi.location.coordinates[1], poi.location.coordinates[0]] : null)),
    [pois, zoomLevel],
  );
  const memberClusters = useMemo(
    () => clusterize(members, zoomLevel, (m) => (Array.isArray(m.location?.coordinates) && m.location.coordinates.length >= 2 ? [m.location.coordinates[1], m.location.coordinates[0]] : null), MEMBER_CELL_PX),
    [members, zoomLevel],
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
  const dirClose = onDirections
    ? (target: { lat: number; lng: number }) => { try { mapObj?.closePopup(); } catch { /* */ } onDirections(target); }
    : undefined;

  return (
    <div className="relative h-full min-h-[420px] w-full overflow-hidden rounded-[28px]">
      <style dangerouslySetInnerHTML={{ __html: PAWMAP_KEYFRAMES }} />
      <MapContainer ref={setMapObj} center={center} zoom={initialZoom} minZoom={3} maxZoom={19} style={{ height: "100%", width: "100%" }} scrollWheelZoom zoomControl={false}>
        <ZoomControl position="bottomright" />
        {dark ? (
          <TileLayer
            key="dark"
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> &copy; <a href="https://carto.com/">CARTO</a>'
            url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
            maxZoom={19}
          />
        ) : (
          <TileLayer key="light" attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>' url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" maxZoom={19} />
        )}

        <ViewWatcher onZoom={handleZoom} onMove={onMapMove} onBounds={onBoundsChange} />
        <RecenterMap center={center} />
        <FlyToFocus target={focusTarget} />
        <RouteFit points={routePoints} />
        <FollowController target={followTarget} onUserGesture={() => onFollowPause?.()} />

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
          <Marker key={`spot-${spot.id}`} position={[spot.lat, spot.lng]} icon={spotIcon(spot.type, spot.isGolden)} zIndexOffset={spot.isGolden ? PIN_Z.spotGolden : PIN_Z.spot} eventHandlers={{ popupopen: () => onSpotVisit?.(spot.id) }}>
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

        {/* DEMANDES des propriétaires : bulle orange foncé, prix dedans. */}
        {requests.map((r) => (
          <Marker key={`req-${r.id}`} position={[r.lat, r.lng]} icon={requestIcon(r, requestMineLabel)} zIndexOffset={PIN_Z.request + (r.mine ? 200 : 0)}>
            <Popup>
              <div className="text-sm" style={{ minWidth: 180 }}>
                <div className="font-bold" style={{ color: ROLE_COLOR.owner }}>{r.mine ? requestLabels?.mine : requestLabels?.title}</div>
                <div className="mt-0.5 text-xs font-semibold text-ink">
                  {r.service === "walk" ? requestLabels?.walk : requestLabels?.sitting}
                  {r.priceLabel ? ` · ${r.priceLabel}` : ""}
                  {r.city ? ` · ${r.city}` : ""}
                </div>
                {r.body && <div className="mt-1 line-clamp-3 text-xs text-ink-muted">{r.body}</div>}
                {!r.mine && onOfferService && requestLabels && (
                  <button type="button" onClick={() => onOfferService(r.id)} className="mt-2 flex min-h-[40px] w-full items-center justify-center rounded-full px-3 text-xs font-bold text-white" style={{ background: `linear-gradient(90deg, #D83C28, #B92425)` }}>
                    {requestLabels.offer}
                  </button>
                )}
              </div>
            </Popup>
          </Marker>
        ))}

        {/* MEMBRES : rond couleur du rôle + icône du rôle, pilule blanche pour un groupe. */}
        {memberClusters.map((g, i) =>
          g.items.length > 1 ? <MemberCluster key={`mc-${i}-${g.items.length}-${g.center[0].toFixed(4)}`} center={g.center} items={g.items} onList={setMemberList} friendSet={friendSet} /> : null,
        )}
        {memberClusters.filter((g) => g.items.length === 1).map((g) => g.items[0]).map((m) => {
          const c = m.location?.coordinates;
          if (!Array.isArray(c) || c.length < 2) return null;
          const isFriend = friendSet.has(m.id) || (m as NearbyMember & { isFriend?: boolean }).isFriend === true;
          // Un ami qui partage en direct a déjà son rond « en direct » : pas de doublon.
          if (isFriend && liveIdSet.has(m.id)) return null;
          if (isFriend) {
            const seen = friendSeen[m.id];
            return (
              <Marker key={`friend-${m.id}`} position={[c[1], c[0]]} icon={friendProfileIcon(m, premiumSet.has(m.id) || !!m.isPremium)} zIndexOffset={PIN_Z.friend}>
                <Popup>
                  <FriendProfilePopup m={m} roleLabel={(memberRoleLabels && memberRoleLabels[m.role]) || m.role} seen={seen} now={now} labels={liveLabels} bookLabel={memberLabels?.book} onMessage={onMessage} />
                </Popup>
              </Marker>
            );
          }
          return (
            <Marker key={`member-${m.id}`} position={[c[1], c[0]]} icon={memberIcon(m, memberCaption(m))} zIndexOffset={m.isBoosted ? PIN_Z.memberBoosted : PIN_Z.member}>
              <Popup>
                <MemberPopup
                  m={m}
                  roleLabel={(memberRoleLabels && memberRoleLabels[m.role]) || m.role}
                  labels={memberLabels}
                  onAddFriend={onAddFriend}
                  onDirections={dirClose}
                  directionsLabel={directionsLabel}
                  onMessage={onMessageMember && onMessageMember(m) ? () => onMessageMember(m)?.() : undefined}
                  messageLabel={liveLabels?.message}
                />
              </Popup>
            </Marker>
          );
        })}

        {/* AMIS en direct : photo + anneau rose ; tracé violet du suivi. */}
        {trail.length > 1 && <Polyline positions={trail} pathOptions={{ color: PAWFOLLOW_VIOLET, weight: 5, opacity: 0.85, lineCap: "round" }} />}
        {friendPositions.map((p) => (
          <LiveFriendMarker
            key={`live-${p.userId}`}
            p={p}
            isFamily={familySet.has(p.userId)}
            isPremium={premiumSet.has(p.userId)}
            roleLabel={roleLabels?.[p.role] ?? p.role}
            followed={followHaloId === p.userId}
            now={now}
            labels={liveLabels}
            onFollow={onFriendFocus ? () => onFriendFocus(p) : undefined}
            onDirections={dirClose}
            directionsLabel={directionsLabel}
            onMessage={onMessage ? () => onMessage({ id: p.userId, role: p.role, name: p.name }) : undefined}
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

      {/* Groupe toujours superposé au zoom rue : la liste de ses membres. */}
      {memberList && (
        <div className="absolute inset-x-3 top-16 z-[1100] max-h-[55%] overflow-y-auto rounded-[20px] bg-white p-3 shadow-xl sm:left-auto sm:right-3 sm:w-80">
          <div className="mb-1 flex items-center justify-between px-1">
            <p className="text-sm font-bold text-[#231715]">{memberList.length}</p>
            <button type="button" onClick={() => setMemberList(null)} aria-label="×" className="grid h-9 w-9 place-items-center rounded-full bg-[#FAF1EC] text-lg font-bold text-[#231715]">×</button>
          </div>
          <ul className="space-y-1">
            {memberList.map((m) => {
              const key = roleKey(m.role);
              const color = ROLE_COLOR[key];
              const price = key !== "owner" ? formatPrice(m.priceFrom, m.currency) : null;
              const href = key === "owner" ? null : `/book/${key}/${m.id}`;
              const body = (
                <>
                  <span className="h-10 w-10 shrink-0 overflow-hidden rounded-full" style={{ border: `2.5px solid ${color}`, background: color }}>
                    {m.avatar ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={m.avatar} alt="" className="h-full w-full object-cover" />
                    ) : (
                      <span className="block h-full w-full p-2" dangerouslySetInnerHTML={{ __html: memberPinHtml({ role: m.role, size: 36 }) }} />
                    )}
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-sm font-bold text-[#231715]">{m.name || memberRoleLabels?.[m.role] || m.role}</span>
                    <span className="block text-xs font-semibold" style={{ color }}>{memberRoleLabels?.[m.role] || m.role}{price ? ` · ${price}` : ""}</span>
                  </span>
                </>
              );
              return (
                <li key={`ml-${m.id}`}>
                  {href ? (
                    <a href={href} className="flex min-h-[52px] items-center gap-3 rounded-2xl px-2 py-1.5 hover:bg-[#FAF1EC]">{body}</a>
                  ) : (
                    <div className="flex min-h-[52px] items-center gap-3 rounded-2xl px-2 py-1.5">{body}</div>
                  )}
                </li>
              );
            })}
          </ul>
        </div>
      )}
    </div>
  );
}

/** Ami sans partage actif : position de PROFIL floutée, « vu il y a X ». */
function FriendProfilePopup({ m, roleLabel, seen, now, labels, bookLabel, onMessage }: {
  m: NearbyMember;
  roleLabel: string;
  seen?: string | null;
  now: number;
  labels?: LiveLabels;
  bookLabel?: string;
  onMessage?: (who: { id: string; role: string; name: string }) => void;
}) {
  const key = roleKey(m.role);
  const color = ROLE_COLOR[key];
  const age = seen ? Math.max(0, now - new Date(seen).getTime()) : null;
  const price = key !== "owner" ? formatPrice(m.priceFrom, m.currency) : null;
  return (
    <div style={{ minWidth: 210 }}>
      <div className="flex items-center gap-3">
        <span className="h-11 w-11 shrink-0 overflow-hidden rounded-full" style={{ border: "3px solid #F06AA0", background: color }}>
          {m.avatar ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={m.avatar} alt="" className="h-full w-full object-cover" />
          ) : null}
        </span>
        <div className="min-w-0">
          <div className="truncate text-[15px] font-bold text-[#231715]">{m.name || roleLabel}</div>
          <div className="text-xs font-semibold" style={{ color }}>{roleLabel}</div>
        </div>
      </div>
      {labels && (
        <div className="mt-2 text-xs text-[#6E4F48]">
          {age !== null && <div className="font-semibold text-[#231715]">{age < 60_000 ? labels.seenNow : labels.seenAgo.replace("{ago}", labels.ago(age))}</div>}
          <div>{labels.notSharing}</div>
          <div className="mt-0.5 text-[11px] text-[#8A6B64]">{labels.profileApprox}</div>
        </div>
      )}
      <div className="mt-3 flex flex-col gap-2">
        {key !== "owner" && bookLabel && (
          <a href={`/book/${key}/${m.id}`} className="flex min-h-[44px] items-center justify-center rounded-[14px] px-4 text-sm font-bold text-white" style={{ background: `linear-gradient(90deg, ${key === "sitter" ? "#2563EB" : "#15803D"}, ${key === "sitter" ? "#1E4FB0" : "#166534"})`, color: "#fff" }}>
            {bookLabel}{price ? ` · ${price}` : ""}
          </a>
        )}
        <div className="flex gap-2">
          {onMessage && labels && (
            <button type="button" onClick={() => onMessage({ id: m.id, role: m.role, name: m.name })} className="flex min-h-[40px] flex-1 items-center justify-center rounded-[12px] border-[1.5px] px-3 text-xs font-bold" style={{ borderColor: "#F06AA0", color: "#9D174D" }}>
              {labels.message}
            </button>
          )}
          {key !== "owner" && labels && (
            <a href={`/p/${key}/${m.id}`} className="flex min-h-[40px] flex-1 items-center justify-center rounded-[12px] border-[1.5px] px-3 text-xs font-bold" style={{ borderColor: color, color }}>
              {labels.viewProfile}
            </a>
          )}
        </div>
      </div>
    </div>
  );
}

// v548 — fiche membre : nom, rôle, note, tarif, « Identité vérifiée », Ajouter
// en ami, et pour un gardien/promeneur un gros bouton RÉSERVER à la couleur du
// rôle (réserver en 2 clics : épingle → fiche → réservation).
function MemberPopup({ m, roleLabel, labels, onAddFriend, onDirections, directionsLabel, onMessage, messageLabel }: {
  m: NearbyMember;
  roleLabel: string;
  labels?: { addFriend: string; sent: string; already: string; failed: string; book: string; approx: string; priceFrom?: string; verified?: string; viewProfile?: string };
  onAddFriend?: (m: NearbyMember) => Promise<"sent" | "already" | "error">;
  onDirections?: (target: { lat: number; lng: number }) => void;
  directionsLabel?: string;
  onMessage?: () => void;
  messageLabel?: string;
}) {
  const [state, setState] = useState<"idle" | "busy" | "sent" | "already" | "error">("idle");
  const key = roleKey(m.role);
  const color = ROLE_COLOR[key];
  const canBook = key === "sitter" || key === "walker";
  const price = formatPrice(m.priceFrom, m.currency);
  return (
    <div className="text-sm" style={{ minWidth: 200 }}>
      <div className="mb-1 flex items-center gap-2">
        {m.avatar ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={m.avatar} alt="" width={40} height={40} className="rounded-full object-cover" style={{ width: 40, height: 40, border: `2.5px solid ${color}` }} />
        ) : (
          <span className="inline-flex items-center justify-center rounded-full" style={{ width: 40, height: 40, background: color }} dangerouslySetInnerHTML={{ __html: memberPinHtml({ role: m.role, size: 40 }) }} />
        )}
        <div className="min-w-0">
          <div className="truncate font-bold leading-tight">{m.name || roleLabel}</div>
          <div className="text-xs font-semibold" style={{ color }}>
            {roleLabel}
            {m.approx ? "" : m.isOnline ? " · ●" : ""}
          </div>
        </div>
      </div>
      {key !== "owner" && ((m.rating ?? 0) > 0 || price) ? (
        <div className="mb-1 text-xs font-bold text-ink">
          {[(m.rating ?? 0) > 0 ? `★ ${(m.rating ?? 0).toFixed(1)}${(m.reviewsCount ?? 0) > 0 ? ` (${m.reviewsCount})` : ""}` : null, price ? `${labels?.priceFrom ?? ""} ${price}`.trim() : null].filter(Boolean).join("  ·  ")}
        </div>
      ) : null}
      {m.identityVerified && labels?.verified ? <div className="mb-1 text-xs font-semibold" style={{ color: "#16A34A" }}>✓ {labels.verified}</div> : null}
      {m.approx && labels?.approx ? <div className="mb-2 text-[11px] text-ink-soft">{labels.approx.replace("{km}", String(m.approxKm ?? 1))}</div> : null}
      {canBook && labels ? (
        <>
          <a href={`/book/${key}/${m.id}`} className="mb-2 flex min-h-[44px] items-center justify-center gap-2 rounded-[14px] px-4 text-sm font-bold text-white shadow-[0_8px_18px_-8px_rgba(23,20,31,0.45)]" style={{ background: `linear-gradient(90deg, ${key === "sitter" ? "#2563EB" : "#15803D"}, ${key === "sitter" ? "#1E4FB0" : "#166534"})`, color: "#fff" }}>
            {labels.book}{price ? ` · ${labels.priceFrom ?? ""} ${price}`.replace(/ {2,}/g, " ") : ""}
          </a>
          {labels.viewProfile && (
            <a href={`/p/${key}/${m.id}`} className="mb-2 flex min-h-[38px] items-center justify-center rounded-[12px] border-[1.5px] bg-white px-3 text-xs font-bold" style={{ borderColor: color, color: key === "sitter" ? "#1E4FB0" : "#15803D" }}>
              {labels.viewProfile}
            </a>
          )}
        </>
      ) : null}
      {(onDirections || onMessage) && (
        <div className="mb-2 flex gap-2">
          {onDirections && Array.isArray(m.location?.coordinates) && (
            <button type="button" onClick={() => onDirections({ lat: m.location.coordinates[1], lng: m.location.coordinates[0] })} className="flex min-h-[38px] flex-1 items-center justify-center rounded-[12px] border-[1.5px] bg-white px-2 text-xs font-bold" style={{ borderColor: "#16A34A", color: "#15803D" }}>
              {directionsLabel || "→"}
            </button>
          )}
          {onMessage && messageLabel && (
            <button type="button" onClick={onMessage} className="flex min-h-[38px] flex-1 items-center justify-center rounded-[12px] border-[1.5px] bg-white px-2 text-xs font-bold" style={{ borderColor: "#2563EB", color: "#1E4FB0" }}>
              {messageLabel}
            </button>
          )}
        </div>
      )}
      {onAddFriend && labels ? (
        <button
          type="button"
          disabled={state === "busy" || state === "sent" || state === "already"}
          onClick={async () => { setState("busy"); const r = await onAddFriend(m); setState(r); }}
          className="rounded-full px-3 py-1 text-xs font-semibold disabled:opacity-80"
          style={{ background: "#FBE9E5", color: state === "error" ? "#B42318" : "#9E1F0B" }}
        >
          {state === "sent" ? labels.sent : state === "already" ? labels.already : state === "error" ? labels.failed : state === "busy" ? "…" : `+ ${labels.addFriend}`}
        </button>
      ) : null}
    </div>
  );
}
