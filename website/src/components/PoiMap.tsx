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
import { clusterize } from "@/lib/mapCluster";
import {
  memberPinHtml,
  photoPinHtml,
  memberClusterHtml,
  placePinHtml,
  placeClusterHtml,
  spotPinHtml,
  spotClusterHtml,
  reportPinHtml,
  requestBubbleHtml,
  formatPrice,
  ROLE_COLOR,
  PAWFOLLOW_VIOLET,
  PAWMAP_KEYFRAMES,
  roleKey,
} from "@/lib/pawmapLegend";

export { clusterize } from "@/lib/mapCluster";

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
    ic = L.divIcon({ className: "", html: placePinHtml(category, 30), iconSize: [30, 39], iconAnchor: [15, 38], popupAnchor: [0, -34] });
    placeIconCache.set(category, ic);
  }
  return ic;
}
function spotIcon(type: PawSpotType, golden: boolean): L.DivIcon {
  const size = golden ? 40 : 32;
  return L.divIcon({ className: "", html: spotPinHtml(type, golden), iconSize: [size, Math.round(size * 1.3)], iconAnchor: [size / 2, Math.round(size * 1.3) - 1], popupAnchor: [0, -Math.round(size * 1.2)] });
}
const reportIcon = () => L.divIcon({ className: "", html: reportPinHtml(30), iconSize: [30, 30], iconAnchor: [15, 15], popupAnchor: [0, -14] });
function memberIcon(m: NearbyMember, priceLabel: string | null): L.DivIcon {
  return L.divIcon({
    className: "",
    html: memberPinHtml({
      role: m.role,
      premium: !!(m.isPremiumOnly ?? m.isPremium),
      boosted: !!m.isBoosted,
      pawFollow: !!m.hasPawFollow,
      online: m.approx ? null : m.isOnline !== false,
      priceLabel,
      size: 36,
    }),
    iconSize: [36, 36],
    iconAnchor: [18, 18],
    popupAnchor: [0, -20],
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
function FlyToFocus({ target }: { target: { lat: number; lng: number; ts: number } | null }) {
  const map = useMap();
  useEffect(() => {
    if (!target) return;
    // Zoom de rue lisible (~17), vol en douceur (0,9 s), pas de saut sec.
    map.flyTo([target.lat, target.lng], Math.max(map.getZoom(), 17), { duration: 0.9 });
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
    if (far) map.flyTo(center, map.getZoom(), { duration: 0.9 });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [center[0], center[1]]);
  return null;
}

/** Remonte le zoom courant (regroupement + mémorisation) et le centre à l'arrêt. */
function ViewWatcher({ onZoom, onMove }: { onZoom: (z: number) => void; onMove?: (c: { lat: number; lng: number }) => void }) {
  const map = useMap();
  useEffect(() => {
    onZoom(map.getZoom());
  }, [map, onZoom]);
  useMapEvents({
    zoomend(e) {
      onZoom(e.target.getZoom());
    },
    moveend(e) {
      const c = e.target.getCenter();
      onMove?.({ lat: c.lat, lng: c.lng });
    },
  });
  return null;
}

/**
 * Zoom de suivi « joli » : la caméra vole jusqu'au point suivi (zoom de rue
 * 16,5), puis le garde centré sans à-coups ; un geste de l'utilisateur met le
 * suivi en pause (la page affiche « Reprendre le suivi »).
 */
function FollowController({ target, onUserGesture }: { target: { lat: number; lng: number; key: string } | null; onUserGesture: () => void }) {
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
      map.flyTo([target.lat, target.lng], Math.max(map.getZoom(), 16.5), { duration: 1 });
    } else {
      map.panTo([target.lat, target.lng], { animate: true, duration: 0.8, easeLinearity: 0.3 });
    }
    const done = () => { programmatic.current = false; };
    map.once("moveend", done);
    return () => { map.off("moveend", done); };
  }, [map, target]);
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

function PlaceCluster({ center, count, category }: { center: [number, number]; count: number; category: PoiCategory | null }) {
  const map = useMap();
  const icon = useMemo(() => L.divIcon({ className: "", html: placeClusterHtml(count, category), iconSize: [36, 36], iconAnchor: [18, 18] }), [count, category]);
  return <Marker position={center} icon={icon} zIndexOffset={100} eventHandlers={{ click: () => map.flyTo(center, Math.min(map.getZoom() + 2.2, 19), { duration: 0.8 }) }} />;
}
function MemberCluster({ center, count }: { center: [number, number]; count: number }) {
  const map = useMap();
  const icon = useMemo(() => L.divIcon({ className: "", html: memberClusterHtml(count), iconSize: [56, 34], iconAnchor: [28, 17] }), [count]);
  return <Marker position={center} icon={icon} zIndexOffset={250} eventHandlers={{ click: () => map.flyTo(center, Math.min(map.getZoom() + 2.2, 19), { duration: 0.8 }) }} />;
}
function SpotCluster({ center, count }: { center: [number, number]; count: number }) {
  const map = useMap();
  const icon = useMemo(() => L.divIcon({ className: "", html: spotClusterHtml(count), iconSize: [36, 36], iconAnchor: [18, 18] }), [count]);
  return <Marker position={center} icon={icon} zIndexOffset={300} eventHandlers={{ click: () => map.flyTo(center, Math.min(map.getZoom() + 2.2, 19), { duration: 0.8 }) }} />;
}

/** Ami en direct : sa photo, anneau rose, nom · rôle ; clic = suivi. */
function LiveFriendMarker({ p, isFamily, isPremium, roleLabel, onFocus, onDirections, directionsLabel, followLabel }: {
  p: FriendLivePosition;
  isFamily: boolean;
  isPremium?: boolean;
  roleLabel: string;
  onFocus?: () => void;
  onDirections?: (target: { lat: number; lng: number }) => void;
  directionsLabel?: string;
  followLabel?: string;
}) {
  return (
    <Marker
      position={[p.lat, p.lng]}
      icon={makeAvatarIcon(p.role, p.name, p.avatar, isFamily, isPremium, p.isOnline)}
      zIndexOffset={800}
      eventHandlers={{ click: () => onFocus?.() }}
    >
      <Tooltip permanent direction="bottom" offset={[0, 22]} className="!rounded-full !border-0 !bg-white/95 !px-2 !py-0.5 !text-[11px] !font-semibold !shadow">
        {p.name} · {roleLabel}
      </Tooltip>
      <Popup autoPan={false}>
        <div className="text-sm">
          <strong>{p.name}</strong>
          <br />
          <span className="text-xs font-semibold" style={{ color: ROLE_COLOR[roleKey(p.role)] }}>{roleLabel}</span>
          <br />
          <span className="text-xs text-ink-muted">{new Date(p.at).toLocaleString()}</span>
          <div className="mt-2 flex flex-wrap gap-1.5">
            {onFocus && followLabel && (
              <button type="button" onClick={onFocus} className="rounded-full px-3 py-1 text-xs font-bold text-white" style={{ backgroundColor: PAWFOLLOW_VIOLET }}>
                {followLabel}
              </button>
            )}
            {onDirections && (
              <button type="button" onClick={() => onDirections({ lat: p.lat, lng: p.lng })} className="rounded-full px-3 py-1 text-xs font-bold text-white" style={{ backgroundColor: "#16A34A" }}>
                {directionsLabel || "→"}
              </button>
            )}
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
  memberLabels?: { priceFrom?: string; addFriend: string; sent: string; already: string; failed: string; book: string; approx: string; verified?: string };
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
}) {
  const familySet = useMemo(() => new Set(familyIds), [familyIds]);
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

  const poiClusters = useMemo(
    () => clusterize(pois, zoomLevel, (poi) => (Array.isArray(poi.location?.coordinates) && poi.location.coordinates.length >= 2 ? [poi.location.coordinates[1], poi.location.coordinates[0]] : null)),
    [pois, zoomLevel],
  );
  const memberClusters = useMemo(
    () => clusterize(members, zoomLevel, (m) => (Array.isArray(m.location?.coordinates) && m.location.coordinates.length >= 2 ? [m.location.coordinates[1], m.location.coordinates[0]] : null)),
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
  const followTarget = followed ? { lat: followed.lat, lng: followed.lng, key: followed.userId } : null;
  const trail = followUserId ? trails.current.get(followUserId) || [] : [];

  const requestMineLabel = requestLabels?.mine || "";

  return (
    <div className="relative h-full min-h-[420px] w-full overflow-hidden rounded-[28px]">
      <style dangerouslySetInnerHTML={{ __html: PAWMAP_KEYFRAMES }} />
      <MapContainer center={center} zoom={initialZoom} minZoom={3} maxZoom={19} style={{ height: "100%", width: "100%" }} scrollWheelZoom zoomControl={false}>
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

        <ViewWatcher onZoom={handleZoom} onMove={onMapMove} />
        <RecenterMap center={center} />
        <FlyToFocus target={focusTarget} />
        <FollowController target={followTarget} onUserGesture={() => onFollowPause?.()} />

        {/* Ma position : cercle de précision honnête + « Moi » (56 px). */}
        {userLocation && userAccuracy != null && userAccuracy > 25 && (
          <Circle center={[userLocation.lat, userLocation.lng]} radius={userAccuracy} pathOptions={{ color: ROLE_COLOR[roleKey(userRole)], fillColor: ROLE_COLOR[roleKey(userRole)], fillOpacity: 0.08, weight: 1, dashArray: "6 6" }} />
        )}
        {userLocation && (
          <Marker position={[userLocation.lat, userLocation.lng]} icon={userIcon} zIndexOffset={900}>
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
            <Marker key={poi._id} position={[lat, lng]} icon={placeIcon(poi.category)} eventHandlers={{ click: () => onSelectPoi?.(poi) }} zIndexOffset={isSelected ? 1000 : 0}>
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
                  {onDirections && (
                    <button type="button" onClick={() => onDirections({ lat, lng })} className="mt-2 rounded-full px-3 py-1 text-xs font-bold text-white" style={{ backgroundColor: "#C92A12" }}>
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
          <Marker key={`spot-${spot.id}`} position={[spot.lat, spot.lng]} icon={spotIcon(spot.type, spot.isGolden)} zIndexOffset={spot.isGolden ? 600 : 300} eventHandlers={{ popupopen: () => onSpotVisit?.(spot.id) }}>
            <Popup>
              <div className="text-sm" style={{ minWidth: 170 }}>
                <div className="mb-1 font-bold">{spot.name}</div>
                <div className="mb-1 text-xs text-ink-muted">{spotTypeLabels?.[spot.type] || spot.type}</div>
                <div className="mb-1 text-xs text-ink-muted">♥ {spot.likesCount} · ★ {Number(spot.quality || 0).toFixed(1)} · {spot.visitsCount}</div>
                {spot.photoUrl ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={spot.photoUrl} alt="" style={{ width: "100%", maxHeight: 110, objectFit: "cover", borderRadius: 8 }} />
                ) : null}
                {onDirections && (
                  <button type="button" onClick={() => onDirections({ lat: spot.lat, lng: spot.lng })} className="mt-2 rounded-full px-3 py-1 text-xs font-bold text-white" style={{ backgroundColor: "#C92A12" }}>
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
            <Marker key={`report-${r._id}`} position={[c[1], c[0]]} icon={reportIcon()} zIndexOffset={250}>
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
          <Marker key={`req-${r.id}`} position={[r.lat, r.lng]} icon={requestIcon(r, requestMineLabel)} zIndexOffset={r.mine ? 700 : 500}>
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
          g.items.length > 1 ? <MemberCluster key={`mc-${i}-${g.items.length}-${g.center[0].toFixed(4)}`} center={g.center} count={g.items.length} /> : null,
        )}
        {memberClusters.filter((g) => g.items.length === 1).map((g) => g.items[0]).map((m) => {
          const c = m.location?.coordinates;
          if (!Array.isArray(c) || c.length < 2) return null;
          const price = m.role !== "owner" ? formatPrice(m.priceFrom, m.currency) : null;
          return (
            <Marker key={`member-${m.id}`} position={[c[1], c[0]]} icon={memberIcon(m, showPrice ? price : null)} zIndexOffset={m.isBoosted ? 450 : 200}>
              <Popup>
                <MemberPopup m={m} roleLabel={(memberRoleLabels && memberRoleLabels[m.role]) || m.role} labels={memberLabels} onAddFriend={onAddFriend} />
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
            onFocus={() => onFriendFocus?.(p)}
            onDirections={onDirections}
            directionsLabel={directionsLabel}
            followLabel={followLabel}
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
    </div>
  );
}

// v548 — fiche membre : nom, rôle, note, tarif, « Identité vérifiée », Ajouter
// en ami, et pour un gardien/promeneur un gros bouton RÉSERVER à la couleur du
// rôle (réserver en 2 clics : épingle → fiche → réservation).
function MemberPopup({ m, roleLabel, labels, onAddFriend }: {
  m: NearbyMember;
  roleLabel: string;
  labels?: { addFriend: string; sent: string; already: string; failed: string; book: string; approx: string; priceFrom?: string; verified?: string };
  onAddFriend?: (m: NearbyMember) => Promise<"sent" | "already" | "error">;
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
        <a href={`/book/${key}/${m.id}`} className="mb-2 flex min-h-[42px] items-center justify-center rounded-[14px] px-4 text-sm font-bold text-white" style={{ background: `linear-gradient(90deg, ${color}, ${key === "sitter" ? "#1E4FB0" : "#15803D"})` }}>
          {labels.book}{price ? ` · ${price}` : ""}
        </a>
      ) : null}
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
