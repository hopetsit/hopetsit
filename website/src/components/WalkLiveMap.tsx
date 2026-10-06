"use client";

// Carte du suivi en direct d'une réservation (/walk/<id>) — Leaflet + OpenStreetMap.
//
// 05/10/2026 (612, LEO) — alignée sur l'app (cible de Daniel : « un seul tracé,
// la photo, un halo discret ») :
//   · une COURTE TRAÎNE violette (612 §7 : 200 derniers mètres, épaisseur 3,
//     fondu 0,12 → 1) derrière la photo, nettoyée (sauts GPS) et lissée — mêmes
//     valeurs que l'app (`liveTail612`) ; au départ on reprend le tracé déjà
//     nettoyé par le serveur (`initialTrail`), puis chaque point reçu s'y ajoute ;
//   · plus AUCUN cercle en mètres (l'ancien halo de 60 m grossissait avec le
//     zoom) : la lueur violette est DANS la photo, en pixels ;
//   · la photo de la personne suivie (plus d'emoji) ;
//   · la carte n'est plus recréée à chaque position : elle glisse (0,9 s) et
//     garde le zoom choisi ; un glissé au doigt met le suivi en pause, le
//     bouton « Reprendre le suivi » recentre ;
//   · textes dans les 9 langues du site, couleurs pleines (zéro gris).

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { MapContainer, Marker, Polyline, TileLayer, useMap, useMapEvents } from "react-leaflet";
import "leaflet/dist/leaflet.css";
import L from "leaflet";
import { useSocketEvent } from "@/lib/useSocket";
import { useT } from "@/lib/i18n/LanguageProvider";
import { PAWMAP_KEYFRAMES, photoPinHtml } from "@/lib/pawmapLegend";
import { appendTrail612, liveTail612, TRAIL_COLOR_612, TRAIL_WEIGHT_612, type TrailPoint } from "@/lib/trail612";

type Position = { lat: number; lng: number; at?: string };

/** Zoom « rue » du suivi ; on ne recule jamais si l'on est déjà plus près (comme l'app). */
const STREET_ZOOM = 17;
/** Au-delà de 2 min sans point : « signal perdu » (même seuil que la PawMap). */
const LOST_AFTER_S = 120;

function prefersReducedMotion(): boolean {
  return typeof window !== "undefined" && !!window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
}

/** Garde la personne suivie au centre : 1er point = zoom rue, ensuite la carte glisse. */
function FollowCamera({ target, paused, nonce, onUserDrag }: { target: Position | null; paused: boolean; nonce: number; onUserDrag: () => void }) {
  const map = useMap();
  const started = useRef(false);
  const lastNonce = useRef(nonce);
  useEffect(() => {
    if (!target) return;
    const here: [number, number] = [target.lat, target.lng];
    const animate = !prefersReducedMotion();
    try {
      if (!started.current) {
        started.current = true;
        map.setView(here, Math.max(map.getZoom(), STREET_ZOOM), { animate: false });
      } else if (lastNonce.current !== nonce) {
        map.setView(here, Math.max(map.getZoom(), STREET_ZOOM), { animate });
      } else if (!paused) {
        map.panTo(here, { animate, duration: 0.9, easeLinearity: 0.3 });
      }
    } catch { /* animation en cours */ }
    lastNonce.current = nonce;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [map, target?.lat, target?.lng, paused, nonce]);
  useMapEvents({ dragstart: onUserDrag });
  return null;
}

function formatAgo(ms: number, t: (k: string) => string): string {
  const s = Math.max(0, Math.round(ms / 1000));
  if (s < 60) return t("ago_s").replace("{n}", String(s));
  const m = Math.round(s / 60);
  if (m < 60) return t("ago_min").replace("{n}", String(m));
  const h = Math.round(m / 60);
  if (h < 48) return t("ago_h").replace("{n}", String(h));
  return t("ago_d").replace("{n}", String(Math.round(h / 24)));
}

export default function WalkLiveMap({
  walkerId,
  walkerName,
  walkerRole = "walker",
  walkerAvatar,
  initialPosition,
  initialTrail,
}: {
  walkerId?: string;
  walkerName?: string;
  walkerRole?: "walker" | "sitter" | "owner";
  walkerAvatar?: string | null;
  initialPosition?: Position;
  /** Tracé déjà nettoyé par le serveur (GET /friends/live-positions), s'il existe. */
  initialTrail?: TrailPoint[];
}) {
  const { t } = useT();
  const [current, setCurrent] = useState<Position | null>(initialPosition || null);
  // Tracé BRUT (points reçus) ; le tracé dessiné en est la version nettoyée et lissée.
  const [rawTrail, setRawTrail] = useState<TrailPoint[]>(() => {
    const base = Array.isArray(initialTrail) ? initialTrail : [];
    return initialPosition ? appendTrail612(base, initialPosition.lat, initialPosition.lng) : base;
  });
  // Heure du dernier point : celle du serveur si on la connaît (jamais « à l'instant » par défaut).
  const lastUpdateRef = useRef<number | null>(initialPosition ? (initialPosition.at ? new Date(initialPosition.at).getTime() || Date.now() : Date.now()) : null);
  const [ageS, setAgeS] = useState<number | null>(lastUpdateRef.current == null ? null : Math.max(0, Math.floor((Date.now() - lastUpdateRef.current) / 1000)));
  const [paused, setPaused] = useState(false);
  const [nonce, setNonce] = useState(0);

  // La position et le tracé du serveur arrivent après le 1er rendu (la page les charge en parallèle).
  const seededPos = useRef(!!initialPosition);
  useEffect(() => {
    if (!initialPosition || seededPos.current) return;
    seededPos.current = true;
    setCurrent((cur) => cur ?? initialPosition);
    setRawTrail((prev) => appendTrail612(prev, initialPosition.lat, initialPosition.lng));
    if (lastUpdateRef.current == null) lastUpdateRef.current = initialPosition.at ? new Date(initialPosition.at).getTime() || Date.now() : Date.now();
  }, [initialPosition]);
  const seededTrail = useRef(Array.isArray(initialTrail) && initialTrail.length > 0);
  useEffect(() => {
    if (!initialTrail || initialTrail.length === 0 || seededTrail.current) return;
    seededTrail.current = true;
    // Le tracé du serveur vient AVANT les points déjà reçus par la socket.
    setRawTrail((prev) => prev.reduce((acc, p) => appendTrail612(acc, p[0], p[1]), initialTrail));
  }, [initialTrail]);

  useSocketEvent<{ userId: string; personIds?: string[]; role: string; lat: number; lng: number; at?: string }>(
    "map:friend-position",
    (data) => {
      if (walkerId && data.userId !== walkerId && !(Array.isArray(data.personIds) && data.personIds.includes(walkerId))) return;
      if (!Number.isFinite(data.lat) || !Number.isFinite(data.lng)) return;
      setCurrent({ lat: data.lat, lng: data.lng, at: data.at });
      setRawTrail((prev) => appendTrail612(prev, data.lat, data.lng));
      lastUpdateRef.current = Date.now();
      setAgeS(0);
    },
  );

  useEffect(() => {
    const id = setInterval(() => {
      if (lastUpdateRef.current != null) setAgeS(Math.max(0, Math.floor((Date.now() - lastUpdateRef.current) / 1000)));
    }, 1000);
    return () => clearInterval(id);
  }, []);

  const tail = useMemo(() => liveTail612(rawTrail), [rawTrail]);
  const lost = ageS != null && ageS >= LOST_AFTER_S;
  const lostLabel = t("live_state_lost");
  const icon = useMemo(
    () => L.divIcon({
      className: "hps-l-friend",
      html: photoPinHtml({ role: walkerRole, name: walkerName || "", avatar: walkerAvatar || undefined, followed: !lost, lost, caption: lost ? lostLabel : null, online: !lost }),
      iconSize: [50, 50],
      iconAnchor: [25, 25],
    }),
    [walkerRole, walkerName, walkerAvatar, lost, lostLabel],
  );
  const onUserDrag = useCallback(() => setPaused(true), []);
  const resume = useCallback(() => { setPaused(false); setNonce((n) => n + 1); }, []);

  const center: [number, number] = current ? [current.lat, current.lng] : [48.8566, 2.3522];

  return (
    <div data-walk-live="" data-walk-state={!current ? "waiting" : lost ? "lost" : "live"} className="relative h-[60vh] min-h-[400px] w-full overflow-hidden rounded-[28px] border border-[#F1D9CC] shadow-[0_18px_40px_-24px_rgba(124,58,237,0.55)]">
      <style dangerouslySetInnerHTML={{ __html: PAWMAP_KEYFRAMES }} />
      <MapContainer center={center} zoom={current ? STREET_ZOOM : 11} minZoom={3} maxZoom={19} style={{ height: "100%", width: "100%", background: "#F7EDE4" /* fond chaud pendant le chargement des tuiles (Leaflet met du gris #ddd) */ }} scrollWheelZoom>
        <TileLayer attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>' url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" maxZoom={19} />
        <FollowCamera target={current} paused={paused} nonce={nonce} onUserDrag={onUserDrag} />
        {/* 612 §7 — COURTE TRAÎNE (200 derniers mètres, épaisseur 3, violet) qui s'estompe vers
            l'arrière en 5 morceaux et finit sous la photo. Aucun cercle, aucun pointillé. */}
        {tail.map((part, k) => (
          <Polyline key={`tail-${k}-${tail.length}`} positions={part.pts} smoothFactor={0.4} pathOptions={{ color: TRAIL_COLOR_612, weight: TRAIL_WEIGHT_612, opacity: part.alpha, lineCap: k === tail.length - 1 ? "round" : "butt", lineJoin: "round", className: "hps-walk-follow" }} />
        ))}
        {current && <Marker position={[current.lat, current.lng]} icon={icon} zIndexOffset={1000} title={walkerName || undefined} />}
      </MapContainer>

      {/* État du direct */}
      <div data-walk-status="" role="status" className="absolute right-3 top-3 z-[400] max-w-[calc(100%-5rem)] rounded-full border-[1.5px] border-white px-3 py-1.5 text-xs font-bold shadow-[0_8px_18px_-10px_rgba(35,23,21,0.6)]" style={{ background: !current ? "#FFF7F2" : lost ? "#FFF4E5" : "#E9F7EE", color: !current ? "#6E4F48" : lost ? "#9A3412" : "#1F7A37" }}>
        {!current ? (
          <span>{t("service_card_owner_not_started")}</span>
        ) : lost ? (
          <span className="inline-flex items-center gap-1.5">
            <span aria-hidden="true" className="inline-block h-2 w-2 shrink-0 rounded-full bg-[#EA580C]" />
            <span className="min-w-0 break-words">{lostLabel} · {t("friend_seen_ago").replace("{ago}", formatAgo((ageS || 0) * 1000, t))}</span>
          </span>
        ) : (
          <span className="inline-flex items-center gap-1.5">
            <span aria-hidden="true" className="inline-block h-2 w-2 shrink-0 animate-pulse rounded-full bg-[#16A34A] motion-reduce:animate-none" />
            {t("dash_live")}
          </span>
        )}
      </div>

      {current && paused && (
        <button
          type="button"
          data-walk-resume=""
          onClick={resume}
          className="absolute bottom-6 left-1/2 z-[400] inline-flex min-h-[44px] -translate-x-1/2 items-center gap-2 whitespace-nowrap rounded-[18px] border-[1.5px] border-white px-4 text-[13px] font-extrabold text-white shadow-[0_10px_22px_-10px_rgba(124,58,237,0.9)]"
          style={{ background: "linear-gradient(90deg,#8B5CF6,#7C3AED 55%,#5B21B6)" }}
        >
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" aria-hidden="true"><circle cx="12" cy="12" r="3.2" fill="currentColor" stroke="none" /><path d="M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3" /></svg>
          {t("map_follow_resume")}
        </button>
      )}
    </div>
  );
}
