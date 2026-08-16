"use client";

// v23.1 part 146 — Carte temps réel d'une promenade.
// Utilise Leaflet + OpenStreetMap (gratuit, pas de clé API).
// Le composant écoute les events socket `map:friend-position` côté owner
// et déplace un marker en temps réel.

import { useEffect, useRef, useState } from "react";
import { Circle, MapContainer, Marker, Polyline, Popup, TileLayer } from "react-leaflet";
import "leaflet/dist/leaflet.css";
import L from "leaflet";
import { useSocketEvent } from "@/lib/useSocket";

// Hack standard pour les icones Leaflet dans un bundler webpack/Next :
// l'image par défaut a un path relatif cassé. On utilise des assets CDN.
// v23.1 part 146 — fix global des icônes Leaflet en environnement bundler.
// Le path par défaut `marker-icon.png` ne se résout pas correctement avec
// Webpack/Next, donc on pointe sur le CDN officiel.
// @ts-expect-error — Leaflet stocke ses defaults via _getIconUrl interne.
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
});

// v23.1 part 240 — Daniel : "je vois le halo vert si c un walker ou halo
// bleu si c un sitter". Le site web reproduit la meme distinction de role
// que la PawMap mobile : walker = vert, sitter = bleu. Le owner garde le
// pin orange (gradient brand) historique.
function makeProviderIcon(role: "walker" | "sitter" | "owner"): L.DivIcon {
  const colors: Record<string, [string, string, string]> = {
    walker: ["#16A34A", "#22C55E", "🚶"], // vert
    sitter: ["#2563EB", "#3B82F6", "🏠"], // bleu
    owner: ["#C92A12", "#FF6B4A", "🐾"], // orange brand
  };
  const [c1, c2, emoji] = colors[role] || colors.walker;
  return new L.DivIcon({
    className: "",
    html: `<div style="
      width: 36px; height: 36px; border-radius: 50%;
      background: linear-gradient(135deg, ${c1}, ${c2});
      border: 3px solid white; box-shadow: 0 2px 8px rgba(0,0,0,0.3);
      display: flex; align-items: center; justify-content: center;
      font-size: 18px;">${emoji}</div>`,
    iconSize: [36, 36],
    iconAnchor: [18, 18],
  });
}

// Halo de couleur autour du marker (equivalent du halo PawMap mobile).
function haloColor(role: "walker" | "sitter" | "owner"): string {
  if (role === "walker") return "#16A34A";
  if (role === "sitter") return "#2563EB";
  return "#C92A12";
}

type Position = { lat: number; lng: number; at?: string };

export default function WalkLiveMap({
  walkerId,
  walkerName,
  walkerRole = "walker",
  initialPosition,
}: {
  walkerId?: string;
  walkerName?: string;
  /** v240 — role pour le halo couleur (vert walker / bleu sitter). */
  walkerRole?: "walker" | "sitter" | "owner";
  initialPosition?: Position;
}) {
  // Position courante du walker (peut commencer null si pas de fix initial).
  const [current, setCurrent] = useState<Position | null>(initialPosition || null);
  // Historique des positions pour tracer le polyline du trajet.
  const [trail, setTrail] = useState<Position[]>(initialPosition ? [initialPosition] : []);
  const lastUpdateRef = useRef<number>(Date.now());
  const [staleness, setStaleness] = useState(0);

  // v23.1 part 146 — listener socket : nouveau point GPS reçu.
  useSocketEvent<{ userId: string; role: string; lat: number; lng: number; at?: string }>(
    "map:friend-position",
    (data) => {
      if (walkerId && data.userId !== walkerId) return;
      const next: Position = { lat: data.lat, lng: data.lng, at: data.at };
      setCurrent(next);
      setTrail((prev) => {
        // Évite les doublons exacts (même lat/lng que le dernier point).
        if (prev.length > 0) {
          const last = prev[prev.length - 1];
          if (last.lat === next.lat && last.lng === next.lng) return prev;
        }
        // Cap à 200 points pour ne pas exploser la RAM sur longues promenades.
        const updated = [...prev, next];
        return updated.length > 200 ? updated.slice(-200) : updated;
      });
      lastUpdateRef.current = Date.now();
      setStaleness(0);
    },
  );

  // Indicateur de fraîcheur : combien de temps depuis le dernier point reçu.
  useEffect(() => {
    const id = setInterval(() => {
      setStaleness(Math.floor((Date.now() - lastUpdateRef.current) / 1000));
    }, 1000);
    return () => clearInterval(id);
  }, []);

  const center: [number, number] = current
    ? [current.lat, current.lng]
    : [48.8566, 2.3522]; // Paris par défaut

  const trailLatLngs: [number, number][] = trail.map((p) => [p.lat, p.lng]);

  return (
    <div className="relative h-[60vh] min-h-[400px] w-full overflow-hidden rounded-2xl border border-ink/5 shadow-card">
      <MapContainer
        key={`${center[0]},${center[1]}`} // re-mount si la position change radicalement
        center={center}
        zoom={current ? 15 : 11}
        style={{ height: "100%", width: "100%" }}
        scrollWheelZoom={true}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        {trailLatLngs.length > 1 && (
          <Polyline
            positions={trailLatLngs}
            pathOptions={{ color: haloColor(walkerRole), weight: 4, opacity: 0.7 }}
          />
        )}
        {current && (
          <>
            {/* v23.1 part 240 — halo couleur autour du marker (parite mobile
                PawMap). Walker vert / Sitter bleu / Owner orange. */}
            <Circle
              center={[current.lat, current.lng]}
              radius={60}
              pathOptions={{
                color: haloColor(walkerRole),
                fillColor: haloColor(walkerRole),
                fillOpacity: 0.18,
                weight: 2,
                opacity: 0.7,
              }}
            />
            <Marker
              position={[current.lat, current.lng]}
              icon={makeProviderIcon(walkerRole)}
            >
              <Popup>
                <div className="text-sm">
                  <strong>{walkerName || "Walker"}</strong>
                  <br />
                  Dernier point : {staleness < 5 ? "à l'instant" : `il y a ${staleness}s`}
                </div>
              </Popup>
            </Marker>
          </>
        )}
      </MapContainer>

      {/* Overlay status */}
      <div className="absolute right-3 top-3 z-[400] rounded-full bg-white/95 px-3 py-1.5 text-xs font-semibold shadow-lg backdrop-blur">
        {!current ? (
          <span className="text-ink-muted">⌛ En attente de la position…</span>
        ) : staleness < 10 ? (
          <span className="text-green-700">
            <span className="mr-1 inline-block h-2 w-2 animate-pulse rounded-full bg-green-500"></span>
            En direct
          </span>
        ) : staleness < 60 ? (
          <span className="text-amber-700">
            <span className="mr-1 inline-block h-2 w-2 rounded-full bg-amber-500"></span>
            Dernier point {staleness}s
          </span>
        ) : (
          <span className="text-red-700">
            <span className="mr-1 inline-block h-2 w-2 rounded-full bg-red-500"></span>
            Signal perdu ({staleness}s)
          </span>
        )}
      </div>

    </div>
  );
}
