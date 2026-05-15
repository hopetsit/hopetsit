"use client";

// v23.1 part 146 — Composant carte interactive avec POI pet-friendly.
// Affiche tous les POI proches d'un centre donné, avec markers colorés par
// catégorie. Popup au click → détails + action "Voir" qui scrolle vers le
// panneau latéral.

import { useEffect, useMemo, useState } from "react";
import {
  MapContainer,
  Marker,
  Popup,
  TileLayer,
  useMapEvents,
} from "react-leaflet";
import "leaflet/dist/leaflet.css";
import L from "leaflet";
import {
  POI_CATEGORY_LABELS,
  Poi,
  PoiCategory,
} from "@/lib/api";

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
}: {
  center: [number, number];
  pois: Poi[];
  userLocation?: { lat: number; lng: number } | null;
  selectedPoi?: Poi | null;
  onSelectPoi?: (poi: Poi) => void;
  /** Fired when the user finishes panning/zooming the map. */
  onMapMove?: (center: { lat: number; lng: number }) => void;
}) {
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
        style={{ height: "100%", width: "100%" }}
        scrollWheelZoom={true}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />

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
                </div>
              </Popup>
            </Marker>
          );
        })}
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
