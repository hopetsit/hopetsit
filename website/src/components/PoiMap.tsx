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
//   3. une polyline d'itinéraire orange (#EF4324) renvoyée par le backend.

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

/**
 * v23.1.358 — Daniel : "mets le nom et le rôle des amis en direct sur la
 * PawMap, et quand on clique sur eux ça zoome dessus". Marker ami avec
 * tooltip PERMANENT « nom · rôle » sous l'avatar + clic → flyTo zoom 16.
 */
function LiveFriendMarker({
  p,
  isFamily,
  roleLabel,
}: {
  p: FriendLivePosition;
  isFamily: boolean;
  roleLabel: string;
}) {
  const map = useMap();
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
        icon={makeAvatarIcon(p.role, p.name, p.avatar, isFamily)}
        zIndexOffset={800}
        eventHandlers={{
          click: () =>
            map.flyTo([p.lat, p.lng], Math.max(map.getZoom(), 16), {
              duration: 0.8,
            }),
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
        <Popup>
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

function makeSpotIcon(type: PawSpotType, isGolden: boolean): L.DivIcon {
  const bg = isGolden ? "#FFD700" : SPOT_COLOR[type] || SPOT_COLOR.other;
  const ring = isGolden
    ? "border: 3px solid white; box-shadow: 0 0 0 2px #B45309, 0 2px 6px rgba(0,0,0,0.35);"
    : "border: 3px solid white; box-shadow: 0 2px 6px rgba(0,0,0,0.3);";
  return new L.DivIcon({
    className: "",
    html: `<div style="
      width: 34px; height: 34px; border-radius: 50%;
      background: ${bg};
      ${ring}
      display: flex; align-items: center; justify-content: center;
      font-size: 17px; line-height: 1;
    ">🐾</div>`,
    iconSize: [34, 34],
    iconAnchor: [17, 17],
    popupAnchor: [0, -17],
  });
}

// Pin "ma position".
const userIcon = new L.DivIcon({
  className: "",
  html: `<div style="
    width: 16px; height: 16px; border-radius: 50%;
    background: #2563EB;
    border: 3px solid white;
    box-shadow: 0 0 0 4px rgba(37,99,235,0.3), 0 2px 6px rgba(0,0,0,0.3);
  "></div>`,
  iconSize: [16, 16],
  iconAnchor: [8, 8],
});

export default function PoiMap({
  center,
  pois,
  userLocation,
  selectedPoi,
  onSelectPoi,
  onMapMove,
  spots = [],
  spotTypeLabels,
  friendPositions = [],
  familyIds = [],
  roleLabels,
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
  /** v23.1 carte unique — amis/famille en direct (couche optionnelle). */
  friendPositions?: FriendLivePosition[];
  familyIds?: string[];
  /** v23.1.358 — libellés i18n des rôles (owner/sitter/walker) pour le
      tooltip permanent « nom · rôle » sous chaque ami en direct. */
  roleLabels?: Partial<Record<Role, string>>;
  /** v23.1 carte unique — polyline itinéraire (orange #EF4324). */
  routePoints?: { lat: number; lng: number }[] | null;
  /** Bouton "Itinéraire" des popups (spots + POI). */
  onDirections?: (target: { lat: number; lng: number }) => void;
  directionsLabel?: string;
}) {
  const familySet = useMemo(() => new Set(familyIds), [familyIds]);
  // Re-mount la carte si le centre change radicalement (>10km).
  const [mapKey, setMapKey] = useState(() => `${center[0]},${center[1]}`);
  useEffect(() => {
    setMapKey(`${center[0]},${center[1]}`);
  }, [center]);

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
        key={mapKey}
        center={center}
        zoom={13}
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

        {userLocation && (
          <Marker
            position={[userLocation.lat, userLocation.lng]}
            icon={userIcon}
          >
            <Popup>
              <strong>Votre position</strong>
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
                      style={{ backgroundColor: "#EF4324" }}
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
                  {Number(spot.quality || 0).toFixed(1)}
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
                    style={{ backgroundColor: "#EF4324" }}
                  >
                    🧭 {directionsLabel}
                  </button>
                )}
              </div>
            </Popup>
          </Marker>
        ))}

        {/* v23.1 carte unique — couche PawFollow amis/famille en direct :
            halo couleur rôle + anneau violet famille + avatar (icônes
            partagées avec FriendsLiveMap). */}
        {friendPositions.map((p) => (
          <LiveFriendMarker
            key={`live-${p.userId}`}
            p={p}
            isFamily={familySet.has(p.userId)}
            roleLabel={roleLabels?.[p.role] ?? p.role}
          />
        ))}

        {/* v23.1 carte unique — itinéraire piéton (polyline orange). */}
        {routePoints && routePoints.length > 1 && (
          <Polyline
            positions={routePoints.map(
              (p) => [p.lat, p.lng] as [number, number],
            )}
            pathOptions={{ color: "#EF4324", weight: 5, opacity: 0.9 }}
          />
        )}
      </MapContainer>
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
