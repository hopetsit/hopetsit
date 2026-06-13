"use client";

// v23.1 part 246 — Carte web "PawFollow Friends" (deep refonte).
// Daniel : "ameliorer liste amis et famille et quand je clic sur le profil
// jle geolocalise pour le suivre". On accepte un selectedUserId pour
// permettre a la page (liste tiles) de focus la map sur un ami precis et
// ouvrir son popup. Parite design avec le mobile v244d :
//   - halo principal = couleur du role (walker vert / sitter bleu / owner
//     orange)
//   - anneau exterieur violet si membre famille (le code couleur metier
//     reste lisible)

import { useEffect, useMemo, useRef, useState } from "react";
import {
  Circle,
  LayersControl,
  MapContainer,
  Marker,
  Popup,
  TileLayer,
  useMap,
} from "react-leaflet";
import "leaflet/dist/leaflet.css";
import L from "leaflet";
import { useSocketEvent } from "@/lib/useSocket";
import type { FriendItem } from "@/lib/api";

// Hack standard Leaflet bundler-safe.
// @ts-expect-error — Leaflet stocke ses defaults via _getIconUrl interne.
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  iconRetinaUrl:
    "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
});

// v23.1 carte unique — Role/haloColor/FAMILY_VIOLET/makeAvatarIcon sont
// désormais exportés : PoiMap (la carte unique /map) réutilise exactement
// les mêmes markers avatars pour la couche PawFollow amis/famille.
export type Role = "walker" | "sitter" | "owner" | "family";

function roleFromModel(model: string): "walker" | "sitter" | "owner" {
  const m = (model || "").toLowerCase();
  if (m === "walker") return "walker";
  if (m === "sitter") return "sitter";
  return "owner";
}

// v246 — meme code couleur que la PawMap mobile post-v244d :
// le role determine la couleur principale, famille ajoute un anneau
// violet par-dessus. La fonction haloColor donne la couleur metier ;
// FAMILY_VIOLET est utilise pour le ring exterieur.
export function haloColor(role: Role): string {
  if (role === "walker") return "#16A34A";
  if (role === "sitter") return "#2563EB";
  // family = owner orange par defaut (l'anneau violet signale la famille
  // de toute facon). En pratique role="family" arrive seulement comme
  // fallback historique — la vraie info famille passe par familyIds.
  return "#EF4324";
}

export const FAMILY_VIOLET = "#8B5CF6";

export function makeAvatarIcon(
  role: Role,
  name: string,
  avatar?: string,
  isFamily?: boolean,
  isPremium?: boolean,
): L.DivIcon {
  const color = haloColor(role);
  // v23.1.399 — Daniel : couronne 👑 + anneau OR pour les membres Paw
  // Premium (prioritaire sur le violet famille), comme dans l'app.
  const GOLD = "#E8A00A";
  const ringColor = isPremium ? GOLD : isFamily ? FAMILY_VIOLET : "white";
  const ringWidth = isPremium || isFamily ? 4 : 3;
  const haloColorEdge = isPremium ? GOLD : isFamily ? FAMILY_VIOLET : color;
  const initials = (name || "?")
    .split(/\s+/)
    .map((w) => w[0] || "")
    .slice(0, 2)
    .join("")
    .toUpperCase();
  const inner = avatar
    ? `<img src="${avatar}" alt="" style="width:100%;height:100%;object-fit:cover;border-radius:50%;" />`
    : `<span style="color:white;font-weight:700;font-size:18px;">${initials}</span>`;
  const crown = isPremium
    ? `<div style="position:absolute;top:-18px;left:50%;transform:translateX(-50%);font-size:22px;text-shadow:0 1px 3px rgba(0,0,0,0.4);">👑</div>`
    : "";
  // v23.1.359 — anneau pulsé ; v23.1.396 — 64 px ; v23.1.399 — couronne premium.
  return new L.DivIcon({
    className: "",
    html: `<div style="position:relative;width:64px;height:64px;">
      <div style="position:absolute;inset:-4px;border-radius:50%;
        border:3px solid ${haloColorEdge};
        animation:hps-pulse 2s ease-out infinite;"></div>
      <div style="
        width: 64px; height: 64px; border-radius: 50%;
        background: ${color};
        border: ${ringWidth}px solid ${ringColor};
        box-shadow: 0 3px 10px rgba(0,0,0,0.3);
        display: flex; align-items: center; justify-content: center;
        overflow: hidden;">${inner}</div>
      ${crown}
    </div>`,
    iconSize: [64, 64],
    iconAnchor: [32, 32],
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

function FitBoundsOnChange({
  positions,
}: {
  positions: FriendLivePosition[];
}) {
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

// v246 — fly to a specific friend when the selectedUserId prop changes.
// Daniel : "quand je clic sur le profil jle geolocalise pour le suivre".
function FlyToSelected({
  selectedUserId,
  positions,
}: {
  selectedUserId?: string;
  positions: FriendLivePosition[];
}) {
  const map = useMap();
  useEffect(() => {
    if (!selectedUserId) return;
    const target = positions.find((p) => p.userId === selectedUserId);
    if (!target) return;
    map.flyTo([target.lat, target.lng], 15, { duration: 1.2 });
  }, [selectedUserId, positions, map]);
  return null;
}

// v23.1.284 — Daniel : "sur la pawmap du site web je veux que ce soit
// synchronisé comme sur le téléphone et qu'on puisse follow la personne".
// FollowFriend = équivalent web du mode suivi de la PawMap mobile : tant que
// followUserId est défini, la caméra RE-CENTRE en continu sur la dernière
// position live de l'ami (mise à jour par socket map:friend-position). Un
// drag manuel arrête le suivi (comme onCameraMoveStarted côté app).
function FollowFriend({
  followUserId,
  positions,
  onStop,
}: {
  followUserId?: string;
  positions: FriendLivePosition[];
  onStop?: () => void;
}) {
  const map = useMap();
  const lastFollowed = useRef<string | undefined>(undefined);
  const suppressStop = useRef(false);

  useEffect(() => {
    if (!followUserId) {
      lastFollowed.current = undefined;
      return;
    }
    const target = positions.find((p) => p.userId === followUserId);
    if (!target) return;
    suppressStop.current = true;
    if (lastFollowed.current !== followUserId) {
      // Entrée en mode suivi → zoom rapproché (parité _followZoom mobile).
      map.flyTo([target.lat, target.lng], 17, { duration: 1.0 });
      lastFollowed.current = followUserId;
    } else {
      // Déplacement live → recentrage doux sans changer le zoom.
      map.panTo([target.lat, target.lng], { animate: true, duration: 0.8 });
    }
    const tid = setTimeout(() => {
      suppressStop.current = false;
    }, 1100);
    return () => clearTimeout(tid);
  }, [followUserId, positions, map]);

  // Arrêt du suivi sur drag manuel (pas sur les recentrages programmatiques).
  useEffect(() => {
    if (!followUserId) return;
    const onDragStart = () => {
      if (!suppressStop.current) onStop?.();
    };
    map.on("dragstart", onDragStart);
    return () => {
      map.off("dragstart", onDragStart);
    };
  }, [followUserId, map, onStop]);

  return null;
}

// v23.1 part 248 — Daniel : "un bouton suivre tout le monde". Quand le
// nonce change (incrementee par la page au clic du bouton), on fitBounds
// sur TOUTES les positions live pour qu'elles soient toutes visibles
// d'un coup. Different du FitBoundsOnChange qui ne fit qu'au premier
// load et qu'une seule fois.
function FitAllOnNonce({
  nonce,
  positions,
}: {
  nonce: number;
  positions: FriendLivePosition[];
}) {
  const map = useMap();
  useEffect(() => {
    if (nonce <= 0) return;
    if (positions.length === 0) return;
    const latlngs = positions.map((p) => [p.lat, p.lng] as [number, number]);
    if (latlngs.length === 1) {
      map.flyTo(latlngs[0], 14, { duration: 1.0 });
    } else {
      map.flyToBounds(L.latLngBounds(latlngs).pad(0.25), { duration: 1.2 });
    }
  }, [nonce, positions, map]);
  return null;
}

export default function FriendsLiveMap({
  friends,
  initialPositions = [],
  familyIds = [],
  selectedUserId,
  fitAllNonce = 0,
  followUserId,
  onStopFollow,
  followLabel = "Suivi en direct",
  stopLabel = "Stop",
}: {
  friends: FriendItem[];
  initialPositions?: FriendLivePosition[];
  familyIds?: string[];
  /** v246 — controle de focus depuis la liste cote page. */
  selectedUserId?: string;
  /** v248 — incremente par "Suivre tout le monde" pour fitBounds. */
  fitAllNonce?: number;
  /** v23.1.284 — suivi continu d'un ami (caméra qui le traque en live). */
  followUserId?: string;
  onStopFollow?: () => void;
  followLabel?: string;
  stopLabel?: string;
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

  const [positions, setPositions] = useState<Map<string, FriendLivePosition>>(
    () => {
      const m = new Map<string, FriendLivePosition>();
      for (const p of initialPositions) m.set(p.userId, p);
      return m;
    },
  );

  // Refs sur chaque Marker pour pouvoir ouvrir le popup quand le user
  // tape un tile dans la liste (selectedUserId change -> openPopup).
  const markerRefs = useRef<Map<string, L.Marker>>(new Map());

  // map:friend-position → update or add.
  useSocketEvent<{
    userId: string;
    role: string;
    lat: number;
    lng: number;
    at?: string;
  }>("map:friend-position", (data) => {
    const friend = friendByUserId.get(data.userId);
    // v246 — on garde le role metier reel et on signale famille via le
    // ring exterieur (cf. makeAvatarIcon isFamily).
    const baseRole: Role = roleFromModel(
      friend?.other?.model || data.role || "owner",
    );
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

  // Quand selectedUserId change, ouvre le popup correspondant.
  useEffect(() => {
    if (!selectedUserId) return;
    const m = markerRefs.current.get(selectedUserId);
    if (m) {
      // Petite tempo pour laisser flyTo se terminer avant d'ouvrir
      // le popup (sinon il peut se fermer pendant l'animation).
      const tid = setTimeout(() => m.openPopup(), 800);
      return () => clearTimeout(tid);
    }
  }, [selectedUserId]);

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
        maxZoom={19}
        style={{ height: "100%", width: "100%" }}
        scrollWheelZoom={true}
        zoomControl={true}
      >
        {/* v23.1.278 — zoom +/- natif Leaflet + switcher Plan/Satellite
            (Esri, gratuit) + maxZoom 19 (zoom rue), comme sur la PawMap. */}
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
        <FitBoundsOnChange positions={positionsList} />
        <FlyToSelected
          selectedUserId={selectedUserId}
          positions={positionsList}
        />
        <FitAllOnNonce nonce={fitAllNonce} positions={positionsList} />
        <FollowFriend
          followUserId={followUserId}
          positions={positionsList}
          onStop={onStopFollow}
        />
        {positionsList.map((p) => {
          const isFamily = familySet.has(p.userId);
          return (
            <span key={p.userId}>
              {/* 1) Halo role color (vert/bleu/orange). */}
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
              {/* 2) v246 — anneau exterieur violet si famille (parite
                  mobile v244d : conserve le code couleur metier + signale
                  le statut famille). */}
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
                ref={(instance) => {
                  if (instance) {
                    markerRefs.current.set(p.userId, instance);
                  } else {
                    markerRefs.current.delete(p.userId);
                  }
                }}
              >
                <Popup>
                  <div className="text-sm">
                    <strong>{p.name}</strong>
                    <br />
                    <span className="text-xs uppercase tracking-wider opacity-70">
                      {p.role}
                      {isFamily ? " · Famille" : ""}
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
        })}
      </MapContainer>

      {/* v23.1.284 — bannière "Suivi en direct" + bouton Stop (parité mobile). */}
      {followUserId && (
        <div className="absolute left-3 top-3 z-[400] flex items-center gap-2 rounded-full bg-walker px-3 py-1.5 text-xs font-bold text-white shadow-lg">
          <span className="inline-block h-2 w-2 animate-pulse rounded-full bg-white"></span>
          <span>
            {followLabel}
            {(() => {
              const f = positionsList.find((p) => p.userId === followUserId);
              return f ? ` — ${f.name}` : "";
            })()}
          </span>
          <button
            type="button"
            onClick={onStopFollow}
            className="ml-1 rounded-full bg-white/25 px-2 py-0.5 font-bold hover:bg-white/40"
          >
            {stopLabel}
          </button>
        </div>
      )}

      {/* Overlay status */}
      <div className="absolute right-3 top-3 z-[400] rounded-full bg-white/95 px-3 py-1.5 text-xs font-semibold shadow-lg backdrop-blur">
        {positionsList.length === 0 ? (
          <span className="text-ink-muted">
            ⌛ Aucun ami en direct pour le moment
          </span>
        ) : (
          <span className="text-green-700">
            <span className="mr-1 inline-block h-2 w-2 animate-pulse rounded-full bg-green-500"></span>
            {positionsList.length} ami{positionsList.length > 1 ? "s" : ""} en
            direct
          </span>
        )}
      </div>
    </div>
  );
}
