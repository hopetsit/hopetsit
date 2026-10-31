"use client";

// 31/10/2026 (LEO, demande de Daniel « que la ville soit sélectionnée par carte pour être précis ») —
// mini-carte OpenStreetMap (Leaflet, déjà sur le site ; jamais Google — décision du 26/09) avec UNE épingle
// orange déplaçable : glisser l'épingle ou toucher la carte déplace le point. Chargée en `dynamic(ssr:false)`
// par PlacePicker3110 (Leaflet touche `window`). Hauteur fixée par le parent (180–220 px).

import { useEffect, useMemo } from "react";
import { MapContainer, Marker, TileLayer, useMap, useMapEvents } from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";

const PIN = `<svg width="34" height="44" viewBox="0 0 34 44" xmlns="http://www.w3.org/2000/svg"><path d="M17 43C17 43 3 25.5 3 15.5A14 14 0 0 1 31 15.5C31 25.5 17 43 17 43Z" fill="#C92A12" stroke="#fff" stroke-width="2.5"/><circle cx="17" cy="15.5" r="5.5" fill="#fff"/></svg>`;

function Recenter({ lat, lng }: { lat: number; lng: number }) {
  const map = useMap();
  useEffect(() => { map.setView([lat, lng], Math.max(map.getZoom(), 13), { animate: true }); }, [lat, lng, map]);
  return null;
}

function ClickToMove({ onMove }: { onMove: (lat: number, lng: number) => void }) {
  useMapEvents({ click: (e) => onMove(e.latlng.lat, e.latlng.lng) });
  return null;
}

export default function MiniMapPick3110({ lat, lng, onMove }: { lat: number; lng: number; onMove: (lat: number, lng: number) => void }) {
  const icon = useMemo(() => L.divIcon({ className: "hps-pick-pin-3110", html: PIN, iconSize: [34, 44], iconAnchor: [17, 43] }), []);
  return (
    <MapContainer center={[lat, lng]} zoom={13} minZoom={5} maxZoom={18} style={{ height: "100%", width: "100%" }} zoomControl={false} scrollWheelZoom={false} attributionControl={false} dragging>
      <TileLayer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" maxZoom={19} />
      <Recenter lat={lat} lng={lng} />
      <ClickToMove onMove={onMove} />
      <Marker position={[lat, lng]} icon={icon} draggable eventHandlers={{ dragend: (e) => { const p = (e.target as L.Marker).getLatLng(); onMove(p.lat, p.lng); } }} />
    </MapContainer>
  );
}
