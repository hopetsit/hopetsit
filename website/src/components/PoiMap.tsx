"use client";

// v23.1 part 146 — Composant carte interactive avec POI pet-friendly.
// Affiche tous les POI proches d'un centre donné, avec markers colorés par
// catégorie. Popup au click → détails + action "Voir" qui scrolle vers le
// panneau latéral.
//
// v23.1 carte unique — Daniel : "sur le site web, UNE SEULE carte". PoiMap
// devient LA carte du site : en plus des POI + position user, elle sait
// afficher (couches optionnelles pilotées par /map) :
//   1. la couche PawFollow amis/famille en direct (markers avatars + halos,
//      mêmes icônes que FriendsLiveMap — helpers importés de là) ;
//   2. les PawSpots communautaires (patte 🐾 colorée par type, dorée si
//      isGolden) avec popup likes/qualité/photo + bouton Itinéraire ;
//   3. une polyline d'itinéraire orange (#C92A12) renvoyée par le backend.

import { useEffect, useMemo, useState } from "react";
import {
  Circle,
  LayersControl,
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
import {
  FAMILY_VIOLET,
  haloColor,
  makeAvatarIcon,
} from "@/components/FriendsLiveMap";
import type { FriendLivePosition, Role } from "@/components/FriendsLiveMap";
import { GOLDEN_COIN_SVG, makeTypeCoinSvg } from "@/components/PawSpotGoldCoin";

/**
 * v23.1.358 — Daniel : "mets le nom et le rôle des amis en direct sur la
 * PawMap, et quand on clique sur eux ça zoome dessus". Marker ami avec
 * tooltip PERMANENT « nom · rôle » sous l'avatar + clic → flyTo zoom 16.
 */
function LiveFriendMarker({
  p,
  isFamily,
  isPremium,
  roleLabel,
  onFocus,
}: {
  p: FriendLivePosition;
  isFamily: boolean;
  isPremium?: boolean;
  roleLabel: string;
  onFocus?: () => void;
}) {
  return (
    <span>
      <Circle
        center={[p.lat, p.lng]}
        radius={70}
        pathOptions={{
          color: haloColor(p.role),
          fillColor: haloColor(p.role),
          fillOpacity: 0.18,
          weight: 2,
          opacity: 0.7,
        }}
      />
      {isFamily && (
        <Circle
          center={[p.lat, p.lng]}
          radius={95}
          pathOptions={{
            color: FAMILY_VIOLET,
            fillOpacity: 0,
            weight: 3,
            opacity: 0.95,
          }}
        />
      )}
      <Marker
        position={[p.lat, p.lng]}
        icon={makeAvatarIcon(p.role, p.name, p.avatar, isFamily, isPremium)}
        zIndexOffset={800}
        eventHandlers={{
          // v23.1.364 — le clic notifie la PAGE (focusTarget) → FlyToFocus
          // zoome ; le remount mapKey n'écrase plus rien (cf plus haut).
          click: () => onFocus?.(),
        }}
      >
        <Tooltip
          permanent
          direction="bottom"
          offset={[0, 16]}
          className="!rounded-lg !border-0 !bg-white/95 !px-2 !py-0.5 !text-[11px] !font-semibold !shadow"
        >
          {p.name} · {roleLabel}
        </Tooltip>
        <Popup autoPan={false}>
          <div className="text-sm">
            <strong>{p.name}</strong>
            <br />
            <span className="text-xs uppercase tracking-wider opacity-70">
              {roleLabel}
            </span>
            <br />
            <span className="text-xs opacity-70">
              {new Date(p.at).toLocaleString()}
            </span>
          </div>
        </Popup>
      </Marker>
    </span>
  );
}

/**
 * v23.1.364 — vole vers la cible quand la page met à jour focusTarget
 * (clic sur un marqueur ami OU sur un chip nom·rôle de la rangée).
 */
function FlyToFocus({
  target,
}: {
  target: { lat: number; lng: number; ts: number } | null;
}) {
  const map = useMap();
  useEffect(() => {
    if (!target) return;
    map.flyTo([target.lat, target.lng], Math.max(map.getZoom(), 16), {
      duration: 0.8,
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [target?.ts]);
  return null;
}

// v404 — recentre la carte quand `center` change FORTEMENT (recherche ville /
// géoloc) SANS remonter la carte ni toucher au zoom. Le garde-fou « far » évite
// de contrarier l'utilisateur sur un simple pan (le centre y est déjà) et tout
// risque de boucle moveend → setCenter → setView.
function RecenterMap({ center }: { center: [number, number] }) {
  const map = useMap();
  useEffect(() => {
    const c = map.getCenter();
    const far =
      Math.abs(c.lat - center[0]) > 0.05 || Math.abs(c.lng - center[1]) > 0.05;
    if (far) map.setView(center, map.getZoom(), { animate: true });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [center[0], center[1]]);
  return null;
}

// Fix global icones Leaflet (sinon path cassé en bundler).
// @ts-expect-error — Leaflet stocke ses defaults via _getIconUrl interne.
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
});

// Couleur de fond du marker selon la catégorie.
const CATEGORY_COLOR: Record<PoiCategory, string> = {
  vet: "#DC2626", // red — urgence santé
  shop: "#7C3AED", // purple
  groomer: "#EC4899", // pink
  park: "#16A34A", // green
  beach: "#0EA5E9", // sky blue
  water: "#06B6D4", // cyan
  trainer: "#F59E0B", // amber
  hotel: "#8B5CF6", // violet
  restaurant: "#EA580C", // orange
  other: "#6B7280", // gray
};

function makeCategoryIcon(category: PoiCategory): L.DivIcon {
  const { emoji } = POI_CATEGORY_LABELS[category];
  const bg = CATEGORY_COLOR[category];
  return new L.DivIcon({
    className: "",
    html: `<div style="
      width: 36px; height: 36px; border-radius: 50%;
      background: ${bg};
      border: 3px solid white;
      box-shadow: 0 2px 6px rgba(0,0,0,0.3);
      display: flex; align-items: center; justify-content: center;
      font-size: 18px; line-height: 1;
    ">${emoji}</div>`,
    iconSize: [36, 36],
    iconAnchor: [18, 18],
    popupAnchor: [0, -18],
  });
}

// v23.1 carte unique — marker patte 🐾 PawSpot coloré par type ; les spots
// dorés (isGolden) passent en #FFD700 avec un liseré ambre.
const SPOT_COLOR: Record<PawSpotType, string> = {
  path_walk: "#16A34A",
  chill: "#2563EB",
  playground: "#EF4444",
  swimming: "#14B8A6",
  food_cafe: "#E8A00A",
  other: "#EC4899",
};


// v23.1.368 — Daniel : "colore mon emoji selon le thème du spot". TOUS les
// spots affichent désormais LA pièce-médaille officielle, déclinée dans la
// couleur du type ; la version OR reste celle des spots golden.
function makeSpotIcon(type: PawSpotType, isGolden: boolean): L.DivIcon {
  if (isGolden) {
    // v23.1.373 — Daniel : "la pièce dorée avec le cercle de couleur du
    // thème" — anneau couleur du TYPE autour de la pièce OR, comme la
    // légende (vert chemin, turquoise baignade…).
    const ring = SPOT_COLOR[type] || SPOT_COLOR.other;
    return new L.DivIcon({
      className: "",
      // v23.1.394 — Daniel : pièces légèrement agrandies (46→52).
      html: `<div style="width:52px;height:52px;border-radius:50%;border:3px solid ${ring};box-sizing:border-box;filter:drop-shadow(0 2px 4px rgba(0,0,0,0.35));">${GOLDEN_COIN_SVG}</div>`,
      iconSize: [52, 52],
      iconAnchor: [26, 26],
      popupAnchor: [0, -26],
    });
  }
  const bg = SPOT_COLOR[type] || SPOT_COLOR.other;
  return new L.DivIcon({
    className: "",
    // v23.1.394 — Daniel : pièces type agrandies 42→48 px.
    html: `<div style="width:48px;height:48px;filter:drop-shadow(0 2px 4px rgba(0,0,0,0.3));">${makeTypeCoinSvg(bg)}</div>`,
    iconSize: [48, 48],
    iconAnchor: [24, 24],
    popupAnchor: [0, -24],
  });
}

// Pin "ma position" — v23.1.359 : HALO ANIMÉ (pulse hps-pulse, comme le
// halo qui respire dans l'app), teinté couleur du RÔLE de l'utilisateur.
// v23.1.394 — Daniel : « ma position avec MON PROFIL, pas un point ». Si
// l'avatar est dispo → photo ronde 40px, anneau couleur du rôle + halo
// pulsé. Sinon, fallback sur l'ancien point.
// v23.1.394 — `crown` : couronne 👑 sur l'avatar quand PawPremium actif
// (Daniel : « je vois pas où doit être le badge — regarde ma position »).
function makeUserIcon(color: string, avatarUrl?: string | null, crown?: boolean): L.DivIcon {
  if (avatarUrl) {
    // v23.1.396 — Daniel : « je sors en tout petit » → 40 → 64 px.
    const ring = crown ? "#FFD700" : color;
    return new L.DivIcon({
      className: "",
      html: `<div style="position:relative;width:64px;height:64px;">
        <div style="position:absolute;inset:-7px;border-radius:50%;
          background:${ring}45;border:3px solid ${ring};
          animation:hps-pulse 1.8s ease-out infinite;"></div>
        <img src="${avatarUrl}" alt="" style="position:absolute;inset:0;
          width:64px;height:64px;border-radius:50%;object-fit:cover;
          border:4px solid ${ring};box-shadow:0 3px 10px rgba(0,0,0,0.35);
          background:#fff;" />
        ${crown ? '<div style="position:absolute;top:-20px;left:50%;transform:translateX(-50%);font-size:22px;text-shadow:0 1px 3px rgba(0,0,0,0.4);">👑</div>' : ''}
      </div>`,
      iconSize: [64, 64],
      iconAnchor: [32, 32],
      popupAnchor: [0, -38],
    });
  }
  return new L.DivIcon({
    className: "",
    html: `<div style="position:relative;width:18px;height:18px;">
      <div style="position:absolute;inset:-2px;border-radius:50%;
        background:${color}55;border:2px solid ${color};
        animation:hps-pulse 1.8s ease-out infinite;"></div>
      <div style="position:absolute;inset:0;border-radius:50%;
        background:${color};border:3px solid white;
        box-shadow:0 2px 6px rgba(0,0,0,0.3);"></div>
    </div>`,
    iconSize: [18, 18],
    iconAnchor: [9, 9],
  });
}

// v497 — Daniel : « voir les signaux sur le web ». Emoji par type de
// signalement (markers de la couche reports), + icône Leaflet divIcon ronde.
const REPORT_EMOJI: Record<MapReportType, string> = {
  lost_pet: "🐾",
  found_pet: "🔍",
  aggressive_dog: "⚠️",
  water_active: "💧",
  dead_animal: "💀",
  trap: "🪤",
  poison: "☠️",
  stray_pet: "🐈",
  construction: "🚧",
  food: "🍖",
  trash: "🗑️",
  vet_open: "🏥",
  leash_required: "🦮",
  heat_hot_ground: "🔥",
  tick_zone: "🕷️",
};
function makeReportIcon(type: MapReportType): L.DivIcon {
  const emoji = REPORT_EMOJI[type] || "🔔";
  return L.divIcon({
    className: "",
    html: `<div style="width:30px;height:30px;display:flex;align-items:center;justify-content:center;background:#fff;border-radius:50%;border:2px solid #C92A12;box-shadow:0 1px 4px rgba(0,0,0,.3);font-size:15px;">${emoji}</div>`,
    iconSize: [30, 30],
    iconAnchor: [15, 15],
  });
}

// v497 — membre PawMap proche : badge ROSE (dégradé) + patte blanche, couronne
// 👑 si Premium, point vert/gris selon en ligne. Même style que l'app.
function makeMemberIcon(premium: boolean, online: boolean): L.DivIcon {
  const crown = premium
    ? '<div style="position:absolute;top:-9px;left:50%;transform:translateX(-50%);font-size:12px;">👑</div>'
    : "";
  const dot = `<div style="position:absolute;bottom:-1px;right:-1px;width:9px;height:9px;border-radius:50%;border:1.5px solid #fff;background:${online ? "#22C55E" : "#9CA3AF"};"></div>`;
  return L.divIcon({
    className: "",
    // v505 — patte BLANCHE (logo officiel, comme l'app) au lieu de l'emoji 🐾.
    html: `<div style="position:relative;width:30px;height:30px;">${crown}<div style="width:30px;height:30px;display:flex;align-items:center;justify-content:center;border-radius:50%;background:linear-gradient(135deg,#F06AA0,#E0568B);border:2px solid #fff;box-shadow:0 1px 5px rgba(0,0,0,.35);"><svg viewBox="0 0 24 24" width="15" height="15" fill="#fff"><ellipse cx="12" cy="15.6" rx="4.6" ry="3.7"/><ellipse cx="5.3" cy="10.9" rx="2" ry="2.6"/><ellipse cx="9.4" cy="7.4" rx="2" ry="2.7"/><ellipse cx="14.6" cy="7.4" rx="2" ry="2.7"/><ellipse cx="18.7" cy="10.9" rx="2" ry="2.6"/></svg></div>${dot}</div>`,
    iconSize: [30, 30],
    iconAnchor: [15, 15],
  });
}

export default function PoiMap({
  center,
  pois,
  userLocation,
  selectedPoi,
  onSelectPoi,
  onMapMove,
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
  userHaloColor,
  userAvatarUrl,
  userIsPremium,
  userAccuracy,
  focusTarget = null,
  onFriendFocus,
  routePoints = null,
  onDirections,
  directionsLabel = "→",
}: {
  center: [number, number];
  pois: Poi[];
  userLocation?: { lat: number; lng: number } | null;
  selectedPoi?: Poi | null;
  onSelectPoi?: (poi: Poi) => void;
  /** Fired when the user finishes panning/zooming the map. */
  onMapMove?: (center: { lat: number; lng: number }) => void;
  /** v23.1 carte unique — PawSpots communautaires (couche optionnelle). */
  spots?: PawSpot[];
  /** Labels i18n des types de spot (fournis par la page via t()). */
  spotTypeLabels?: Partial<Record<PawSpotType, string>>;
  /** v497 — signalements PawMap (couche optionnelle « Voir signaux »). */
  reports?: MapReport[];
  /** Labels i18n des types de signalement (popup). */
  reportTypeLabels?: Partial<Record<MapReportType, string>>;
  /** v497 — membres PawMap proches (badge rose), abonnés. */
  members?: NearbyMember[];
  /** Labels i18n des rôles (owner/sitter/walker) pour le popup membre. */
  memberRoleLabels?: Record<string, string>;
  /** v548 — libellés du popup membre (ajouter en ami, réserver, approx.). */
  memberLabels?: {
    addFriend: string;
    sent: string;
    already: string;
    failed: string;
    book: string;
    approx: string;
  };
  /** v548 — « cliquer sur un membre et demander en ami ». */
  onAddFriend?: (m: NearbyMember) => Promise<"sent" | "already" | "error">;
  /** v497 — appelé à l'ouverture du popup d'un spot → compte la visite. */
  onSpotVisit?: (id: string) => void;
  /** v23.1 carte unique — amis/famille en direct (couche optionnelle). */
  friendPositions?: FriendLivePosition[];
  familyIds?: string[];
  /** v23.1.399 — ids des membres PawPremium → couronne 👑 + anneau OR. */
  premiumIds?: string[];
  /** v23.1.358 — libellés i18n des rôles (owner/sitter/walker) pour le
      tooltip permanent « nom · rôle » sous chaque ami en direct. */
  roleLabels?: Partial<Record<Role, string>>;
  /** v23.1.359 — couleur du halo animé "ma position" (couleur du rôle de
      l'utilisateur connecté ; bleu par défaut). */
  userHaloColor?: string;
  /** v23.1.394 — photo de profil affichée comme marqueur « ma position ». */
  userAvatarUrl?: string | null;
  /** v23.1.394 — couronne 👑 + anneau OR sur le marqueur si Premium. */
  userIsPremium?: boolean;
  /** v23.1.397 — précision (m) du relevé navigateur → cercle autour de moi. */
  userAccuracy?: number | null;
  /** v23.1.364 — cible de zoom (clic marqueur ami / chip nom·rôle). */
  focusTarget?: { lat: number; lng: number; ts: number } | null;
  onFriendFocus?: (p: FriendLivePosition) => void;
  /** v23.1 carte unique — polyline itinéraire (orange #C92A12). */
  routePoints?: { lat: number; lng: number }[] | null;
  /** Bouton "Itinéraire" des popups (spots + POI). */
  onDirections?: (target: { lat: number; lng: number }) => void;
  directionsLabel?: string;
}) {
  const familySet = useMemo(() => new Set(familyIds), [familyIds]);
  const premiumSet = useMemo(() => new Set(premiumIds), [premiumIds]);
  // v23.1.359 — halo "ma position" pulsant, couleur du rôle.
  const userIcon = useMemo(
    () => makeUserIcon(userHaloColor || "#2563EB", userAvatarUrl, userIsPremium),
    [userHaloColor, userAvatarUrl, userIsPremium],
  );
  // v404 — Daniel : "le dézoom marche mal". CAUSE : on REMONTAIT la MapContainer
  // (via une key qui changeait dès que le centre bougeait de >0.1°) → la carte
  // se réinitialisait au zoom 13. Or zoomé loin, un petit pan dépasse vite 0.1°
  // → la carte se re-zoomait toute seule (impossible de rester dézoomé). FIX :
  // plus de remount ; un composant RecenterMap recentre via setView en
  // PRÉSERVANT le zoom, et seulement pour un vrai saut (recherche ville/géoloc).

  const categoryIcons = useMemo(() => {
    const map: Partial<Record<PoiCategory, L.DivIcon>> = {};
    (Object.keys(POI_CATEGORY_LABELS) as PoiCategory[]).forEach((c) => {
      map[c] = makeCategoryIcon(c);
    });
    return map as Record<PoiCategory, L.DivIcon>;
  }, []);

  return (
    <div className="relative h-[70vh] min-h-[450px] w-full overflow-hidden rounded-2xl border border-ink/5 shadow-card">
      <MapContainer
        center={center}
        zoom={13}
        minZoom={3}
        maxZoom={19}
        style={{ height: "100%", width: "100%" }}
        scrollWheelZoom={true}
        zoomControl={true}
      >
        {/* v23.1.278 — Daniel : "rajoute la barre +/- , vue satellite, zoom
            dans la rue" sur la PawMap du site. Le zoom +/- est le contrôle
            Leaflet natif (haut-gauche) ; on ajoute un switcher de couches
            (haut-droite) Plan / Satellite (Esri World Imagery, gratuit, sans
            clé) ; maxZoom 19 permet de zoomer jusqu'au niveau de la rue. */}
        <LayersControl position="bottomright">
          <LayersControl.BaseLayer checked name="Plan">
            <TileLayer
              attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
              maxZoom={19}
            />
          </LayersControl.BaseLayer>
          <LayersControl.BaseLayer name="Satellite">
            <TileLayer
              attribution='&copy; <a href="https://www.esri.com">Esri</a>, Maxar, Earthstar Geographics'
              url="https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"
              maxZoom={19}
            />
          </LayersControl.BaseLayer>
        </LayersControl>

        <MapMoveHandler onMove={onMapMove} />
        <RecenterMap center={center} />

        {userLocation && userAccuracy != null && userAccuracy > 25 && (
          // v23.1.397 — cercle de précision : sur PC la géoloc navigateur
          // (WiFi/IP) peut dévier de 30-300 m — on le montre honnêtement.
          <Circle
            center={[userLocation.lat, userLocation.lng]}
            radius={userAccuracy}
            pathOptions={{
              color: userHaloColor || "#2563EB",
              fillColor: userHaloColor || "#2563EB",
              fillOpacity: 0.08,
              weight: 1,
              dashArray: "6 6",
            }}
          />
        )}
        {userLocation && (
          <Marker
            position={[userLocation.lat, userLocation.lng]}
            icon={userIcon}
          >
            <Popup>
              <strong>Votre position</strong>
              {userAccuracy != null && (
                <>
                  <br />
                  <span className="text-xs opacity-70">
                    Précision ±{userAccuracy} m (géoloc navigateur — le GPS du
                    téléphone est plus précis)
                  </span>
                </>
              )}
            </Popup>
          </Marker>
        )}

        {pois.map((poi) => {
          const lng = poi.location.coordinates[0];
          const lat = poi.location.coordinates[1];
          const isSelected = selectedPoi?._id === poi._id;
          return (
            <Marker
              key={poi._id}
              position={[lat, lng]}
              icon={categoryIcons[poi.category] || categoryIcons.other}
              eventHandlers={{
                click: () => onSelectPoi?.(poi),
              }}
              zIndexOffset={isSelected ? 1000 : 0}
            >
              <Popup>
                <div className="text-sm">
                  <div className="mb-1 font-bold">{poi.title}</div>
                  <div className="mb-1 text-xs text-gray-600">
                    {POI_CATEGORY_LABELS[poi.category]?.emoji}{" "}
                    {POI_CATEGORY_LABELS[poi.category]?.label}
                  </div>
                  {poi.address && (
                    <div className="text-xs text-gray-600">📍 {poi.address}</div>
                  )}
                  {poi.phone && (
                    <div className="text-xs text-gray-600">📞 {poi.phone}</div>
                  )}
                  {poi.website && (
                    <a
                      href={poi.website}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-xs text-blue-600 underline"
                    >
                      Site web
                    </a>
                  )}
                  {poi.openingHours && (
                    <div className="mt-1 text-xs text-gray-600">
                      🕐 {poi.openingHours}
                    </div>
                  )}
                  {/* v23.1 carte unique — bouton Itinéraire aussi sur les
                      popups POI existants. */}
                  {onDirections && (
                    <button
                      type="button"
                      onClick={() => onDirections({ lat, lng })}
                      className="mt-2 rounded-full px-3 py-1 text-xs font-bold text-white"
                      style={{ backgroundColor: "#C92A12" }}
                    >
                      🧭 {directionsLabel}
                    </button>
                  )}
                </div>
              </Popup>
            </Marker>
          );
        })}

        {/* v23.1 carte unique — couche PawSpots communautaires : patte 🐾
            colorée par type (dorée + liseré si isGolden). Popup : nom, type,
            ❤️ likes, ⭐ qualité, photo + bouton Itinéraire. */}
        {spots.map((spot) => (
          <Marker
            key={`spot-${spot.id}`}
            position={[spot.lat, spot.lng]}
            icon={makeSpotIcon(spot.type, spot.isGolden)}
            zIndexOffset={spot.isGolden ? 600 : 300}
            eventHandlers={{
              // v497 — ouvrir le popup d'un spot = une visite (comptée 1×/user
              // côté backend), comme l'app.
              popupopen: () => onSpotVisit?.(spot.id),
            }}
          >
            <Popup>
              <div className="text-sm" style={{ minWidth: 170 }}>
                <div className="mb-1 font-bold">
                  {spot.isGolden ? "🐾✨ " : ""}
                  {spot.name}
                </div>
                <div className="mb-1 text-xs text-gray-600">
                  {spotTypeLabels?.[spot.type] || spot.type}
                </div>
                <div className="mb-1 text-xs text-gray-700">
                  ❤️ {spot.likesCount} · ⭐{" "}
                  {Number(spot.quality || 0).toFixed(1)} · 👣 {spot.visitsCount}
                </div>
                {spot.photoUrl ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={spot.photoUrl}
                    alt=""
                    style={{
                      width: "100%",
                      maxHeight: 110,
                      objectFit: "cover",
                      borderRadius: 8,
                    }}
                  />
                ) : null}
                {onDirections && (
                  <button
                    type="button"
                    onClick={() =>
                      onDirections({ lat: spot.lat, lng: spot.lng })
                    }
                    className="mt-2 rounded-full px-3 py-1 text-xs font-bold text-white"
                    style={{ backgroundColor: "#C92A12" }}
                  >
                    🧭 {directionsLabel}
                  </button>
                )}
              </div>
            </Popup>
          </Marker>
        ))}

        {/* v497 — couche « Voir signaux » : markers emoji par type + popup
            (note + confirmations). location.coordinates = [lng, lat]. */}
        {reports.map((r) => {
          const c = r.location?.coordinates;
          if (!Array.isArray(c) || c.length < 2) return null;
          return (
            <Marker
              key={`report-${r._id}`}
              position={[c[1], c[0]]}
              icon={makeReportIcon(r.type)}
              zIndexOffset={250}
            >
              <Popup>
                <div className="text-sm" style={{ minWidth: 150 }}>
                  <div className="mb-1 font-bold">
                    {REPORT_EMOJI[r.type] || "🔔"}{" "}
                    {reportTypeLabels?.[r.type] || r.type}
                  </div>
                  {r.note ? (
                    <div className="mb-1 text-xs text-gray-700">{r.note}</div>
                  ) : null}
                  {typeof r.confirmationsCount === "number" ? (
                    <div className="text-xs text-gray-600">
                      ✅ {r.confirmationsCount}
                    </div>
                  ) : null}
                </div>
              </Popup>
            </Marker>
          );
        })}

        {/* v497 — membres PawMap proches (badge ROSE) : abonnés actifs, tous
            rôles, hors amis/famille. location.coordinates = [lng, lat]. */}
        {members.map((m) => {
          const c = m.location?.coordinates;
          if (!Array.isArray(c) || c.length < 2) return null;
          return (
            <Marker
              key={`member-${m.id}`}
              position={[c[1], c[0]]}
              icon={makeMemberIcon(!!m.isPremium, m.isOnline !== false)}
              zIndexOffset={200}
            >
              <Popup>
                <MemberPopup
                  m={m}
                  roleLabel={(memberRoleLabels && memberRoleLabels[m.role]) || m.role}
                  labels={memberLabels}
                  onAddFriend={onAddFriend}
                />
              </Popup>
            </Marker>
          );
        })}

        {/* v23.1 carte unique — couche PawFollow amis/famille en direct :
            halo couleur rôle + anneau violet famille + avatar (icônes
            partagées avec FriendsLiveMap). */}
        <FlyToFocus target={focusTarget} />
        {friendPositions.map((p) => (
          <LiveFriendMarker
            key={`live-${p.userId}`}
            p={p}
            isFamily={familySet.has(p.userId)}
            isPremium={premiumSet.has(p.userId)}
            roleLabel={roleLabels?.[p.role] ?? p.role}
            onFocus={() => onFriendFocus?.(p)}
          />
        ))}

        {/* v23.1 carte unique — itinéraire piéton (polyline orange). */}
        {routePoints && routePoints.length > 1 && (
          <Polyline
            positions={routePoints.map(
              (p) => [p.lat, p.lng] as [number, number],
            )}
            pathOptions={{ color: "#C92A12", weight: 5, opacity: 0.9 }}
          />
        )}
      </MapContainer>
    </div>
  );
}

// v548 — Daniel : « on peut cliquer sur les membres roses et demander en ami ».
// Popup membre : nom, rôle, statut (ou « position approximative » pour la
// couche monde), bouton Ajouter en ami (état envoyé / déjà / erreur) et, pour
// un sitter/walker, lien Réserver vers sa fiche.
function MemberPopup({
  m,
  roleLabel,
  labels,
  onAddFriend,
}: {
  m: NearbyMember;
  roleLabel: string;
  labels?: {
    addFriend: string; sent: string; already: string; failed: string; book: string; approx: string;
  };
  onAddFriend?: (m: NearbyMember) => Promise<"sent" | "already" | "error">;
}) {
  const [state, setState] = useState<"idle" | "busy" | "sent" | "already" | "error">("idle");
  const canBook = m.role === "sitter" || m.role === "walker";
  return (
    <div className="text-sm" style={{ minWidth: 190 }}>
      <div className="mb-1 flex items-center gap-2">
        {m.avatar ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={m.avatar} alt="" width={34} height={34} className="rounded-full object-cover" style={{ width: 34, height: 34 }} />
        ) : (
          <span
            className="inline-flex items-center justify-center rounded-full text-white"
            style={{ width: 34, height: 34, background: "linear-gradient(135deg,#F06AA0,#E0568B)" }}
          >
            🐾
          </span>
        )}
        <div>
          <div className="font-bold leading-tight">
            {m.isPremium ? "👑 " : ""}
            {m.name || "Membre"}
          </div>
          <div className="text-xs text-gray-600">
            {roleLabel}
            {m.approx ? "" : m.isOnline ? " · 🟢" : " · ⚪"}
          </div>
        </div>
      </div>
      {m.approx && labels?.approx ? (
        <div className="mb-2 text-[11px] text-gray-500">📍 {labels.approx}</div>
      ) : null}
      <div className="flex flex-wrap gap-1.5">
        {onAddFriend && labels ? (
          <button
            type="button"
            disabled={state === "busy" || state === "sent" || state === "already"}
            onClick={async () => {
              setState("busy");
              const r = await onAddFriend(m);
              setState(r);
            }}
            className="rounded-full px-3 py-1 text-xs font-semibold text-white disabled:opacity-80"
            style={{ background: state === "error" ? "#6B7280" : "linear-gradient(135deg,#F06AA0,#E0568B)" }}
          >
            {state === "sent" ? labels.sent
              : state === "already" ? labels.already
              : state === "error" ? labels.failed
              : state === "busy" ? "…"
              : `➕ ${labels.addFriend}`}
          </button>
        ) : null}
        {canBook && labels ? (
          <a
            href={`/book/${m.role}/${m.id}`}
            className="rounded-full border border-ink/15 px-3 py-1 text-xs font-semibold text-ink"
          >
            {labels.book}
          </a>
        ) : null}
      </div>
    </div>
  );
}

function MapMoveHandler({
  onMove,
}: {
  onMove?: (c: { lat: number; lng: number }) => void;
}) {
  useMapEvents({
    moveend(e) {
      const c = e.target.getCenter();
      onMove?.({ lat: c.lat, lng: c.lng });
    },
  });
  return null;
}
