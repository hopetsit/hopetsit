"use client";

// v23.1 part 243 round 3 — Carte web "PawFollow Friends".
// Daniel : "il faut mettre a jour le site web tout le paw follow suivre
// les utilisateurs rien nest fais". Equivalent web de la PawMap mobile :
// chaque ami accepte qui partage sa position apparait avec un halo
// couleur par role (walker=vert, sitter=bleu, owner=orange, famille=violet).
//
// Le composant ecoute `map:friend-position` + `map:friend-offline` pour
// bouger / retirer les markers en temps reel.

import { useEffect, useMemo, useRef, useState } from "react";
import { Circle, MapContainer, Marker, Popup, TileLayer, useMap } from "react-leaflet";
import "leaflet/dist/leaflet.css";
import L from "leaflet";
import { useSocketEvent } from "@/lib/useSocket";
import type { FriendItem } from "@/lib/api";

// Hack standard Leaflet bundler-safe.
// @ts-expect-error — Leaflet stocke ses defaults via _getIconUrl interne.
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
});

type Role = "walker" | "sitter" | "owner" | "family";

function roleFromModel(model: string): "walker" | "sitter" | "owner" {
  const m = (model || "").toLowerCase();
  if (m === "walker") return "walker";
  if (m === "sitter") return "sitter";
  return "owner";
}

// v243 round 3 — meme code couleur que la PawMap mobile.
// Famille → violet (#8B5CF6), prime sur le role.
// Walker → vert, Sitter → bleu, Owner → orange.
function haloColor(role: Role): string {
  if (role === "family") return "#8B5CF6";
  if (role === "walker") return "#16A34A";
  if (role === "sitter") return "#2563EB";
  return "#EF4324";
}

function makeAvatarIcon(role: Role, name: string, avatar?: string): L.DivIcon {
  const color = haloColor(role);
  const initials = (name || "?")
    .split(/\s+/)
    .map((w) => w[0] || "")
    .slice(0, 2)
    .join("")
    .toUpperCase();
  const inner = avatar
    ? `<img src="${avatar}" alt="" style="width:100%;height:100%;object-fit:cover;border-radius:50%;" />`
    : `<span style="color:white;font-weight:700;font-size:14px;">${initials}</span>`;
  return new L.DivIcon({
    className: "",
    html: `<div style="
      width: 40px; height: 40px; border-radius: 50%;
      background: ${color};
      border: 3px solid white; box-shadow: 0 2px 8px rgba(0,0,0,0.3);
      display: flex; align-items: center; justify-content: center;
      overflow: hidden;">${inner}</div>`,
    iconSize: [40, 40],
    iconAnchor: [20, 20],
  });
}

export type FriendLivePosition = {
  userId: string;
  role: Role;
  name: string;
  avatar?: string;
  lat: number;
  lng: number;
  at: string;
};

function FitBoundsOnChange({ positions }: { positions: FriendLivePosition[] }) {
  const map = useMap();
  const fittedOnce = useRef(false);
  useEffect(() => {
    if (positions.length === 0) return;
    if (fittedOnce.current) return;
    const latlngs = positions.map((p) => [p.lat, p.lng] as [number, number]);
    if (latlngs.length === 1) {
      map.setView(latlngs[0], 14);
    } else {
      map.fitBounds(L.latLngBounds(latlngs).pad(0.2));
    }
    fittedOnce.current = true;
  }, [positions, map]);
  return null;
}

export default function FriendsLiveMap({
  friends,
  initialPositions = [],
  familyIds = [],
}: {
  friends: FriendItem[];
  initialPositions?: FriendLivePosition[];
  familyIds?: string[];
}) {
  const familySet = useMemo(() => new Set(familyIds), [familyIds]);

  // Index friends by userId pour resoudre le role/name lors d'un event socket.
  const friendByUserId = useMemo(() => {
    const map = new Map<string, FriendItem>();
    for (const f of friends) {
      if (f.other?.id) map.set(f.other.id, f);
    }
    return map;
  }, [friends]);

  const [positions, setPositions] = useState<Map<string, FriendLivePosition>>(() => {
    const m = new Map<string, FriendLivePosition>();
    for (const p of initialPositions) m.set(p.userId, p);
    return m;
  });

  // map:friend-position → update or add.
  useSocketEvent<{
    userId: string;
    role: string;
    lat: number;
    lng: number;
    at?: string;
  }>("map:friend-position", (data) => {
    const friend = friendByUserId.get(data.userId);
    const baseRole: Role = familySet.has(data.userId)
      ? "family"
      : roleFromModel(friend?.other?.model || data.role || "owner");
    setPositions((prev) => {
      const next = new Map(prev);
      next.set(data.userId, {
        userId: data.userId,
        role: baseRole,
        name: friend?.other?.name || "Ami",
        avatar: friend?.other?.avatar,
        lat: data.lat,
        lng: data.lng,
        at: data.at || new Date().toISOString(),
      });
      return next;
    });
  });

  // map:friend-offline → retirer du Map.
  useSocketEvent<{ userId: string }>("map:friend-offline", (data) => {
    setPositions((prev) => {
      if (!prev.has(data.userId)) return prev;
      const next = new Map(prev);
      next.delete(data.userId);
      return next;
    });
  });

  const positionsList = Array.from(positions.values());
  const center: [number, number] =
    positionsList.length > 0
      ? [positionsList[0].lat, positionsList[0].lng]
      : [48.8566, 2.3522]; // Paris fallback.

  return (
    <div className="relative h-[65vh] min-h-[450px] w-full overflow-hidden rounded-2xl border border-ink/5 shadow-card">
      <MapContainer
        center={center}
        zoom={positionsList.length > 0 ? 13 : 5}
        style={{ height: "100%", width: "100%" }}
        scrollWheelZoom={true}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        <FitBoundsOnChange positions={positionsList} />
        {positionsList.map((p) => (
          <span key={p.userId}>
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
            <Marker
              position={[p.lat, p.lng]}
              icon={makeAvatarIcon(p.role, p.name, p.avatar)}
            >
              <Popup>
                <div className="text-sm">
                  <strong>{p.name}</strong>
                  <br />
                  <span className="text-xs uppercase tracking-wider opacity-70">
                    {p.role}
                  </span>
                  <br />
                  <span className="text-xs opacity-70">
                    {new Date(p.at).toLocaleString()}
                  </span>
                </div>
              </Popup>
            </Marker>
          </span>
        ))}
      </MapContainer>

      {/* Overlay status */}
      <div className="absolute right-3 top-3 z-[400] rounded-full bg-white/95 px-3 py-1.5 text-xs font-semibold shadow-lg backdrop-blur">
        {positionsList.length === 0 ? (
          <span className="text-ink-muted">
            ⌛ Aucun ami en direct pour le moment
          </span>
        ) : (
          <span className="text-green-700">
            <span className="mr-1 inline-block h-2 w-2 animate-pulse rounded-full bg-green-500"></span>
            {positionsList.length} ami{positionsList.length > 1 ? "s" : ""} en direct
          </span>
        )}
      </div>
    </div>
  );
}
