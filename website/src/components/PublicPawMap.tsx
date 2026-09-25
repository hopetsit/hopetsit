"use client";

// 24/09/2026 — LOT B (étape 2 du plan de LEO) : LA VRAIE CARTE SANS COMPTE.
// Affichée sur /pawmap et en 2e position de l'accueil. Elle montre les
// gardiens et promeneurs autour d'une ville, à leur position FLOUTÉE (~1 km,
// floutage fait dans lib/api.ts avant tout affichage), jamais l'adresse, jamais
// de date de naissance. Un clic sur une épingle = fiche courte + « Réserver »
// (« Inscris-toi pour les contacter » sans compte). Même légende que l'app.
//
// Chargée en `dynamic(..., { ssr: false })` par les pages : Leaflet touche
// `window` et ne se rend pas côté serveur.

import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";
import { MapContainer, Marker, Popup, TileLayer, ZoomControl, useMap, useMapEvents } from "react-leaflet";
import "leaflet/dist/leaflet.css";
import L from "leaflet";
import { useT } from "@/lib/i18n/LanguageProvider";
import { useAuth } from "@/lib/useAuth";
import { getPublicProviders, type PublicProvider } from "@/lib/api";
import { clusterize, haversineKm, MEMBER_CELL_PX } from "@/lib/mapCluster";
import {
  memberPinHtml,
  memberClusterHtml,
  dominantRole,
  formatPrice,
  ROLE_COLOR,
  PAWMAP_KEYFRAMES,
  PIN_Z,
} from "@/lib/pawmapLegend";
import { safeFly } from "@/lib/safeFly";
import { AppIcon } from "@/components/AppIcon";
import { PawMapLegendModal } from "@/components/PawMapLegendModal";

function memberIcon(p: PublicProvider, caption: string | null): L.DivIcon {
  return L.divIcon({
    className: "",
    html: memberPinHtml({
      role: p.role,
      boosted: p.boosted,
      avatar: p.avatar || null,
      caption,
      size: 46,
    }),
    iconSize: [46, 46],
    iconAnchor: [23, 23],
    popupAnchor: [0, -26],
  });
}
function clusterIcon(items: PublicProvider[]): L.DivIcon {
  const sz = items.length >= 10 ? 44 : 40;
  return L.divIcon({ className: "", html: memberClusterHtml(items.length, dominantRole(items.map((p) => p.role))), iconSize: [sz, sz], iconAnchor: [sz / 2, sz / 2] });
}

/**
 * 25/09 (PawMap 584, point 5) — chaque recherche de ville / « ma position »
 * CENTRE et ZOOME (≥ 12), même si la carte est déjà à peu près là. Avant :
 * on ne volait que si le centre était « loin », sans toucher au zoom → une
 * carte dézoomée sur la France restait sur la France après « paris ».
 */
function Recenter({ center, zoom, focusKey }: { center: [number, number]; zoom: number; focusKey: number }) {
  const map = useMap();
  const first = useRef(true);
  useEffect(() => {
    if (first.current) { first.current = false; return; }
    safeFly(map, center, zoom);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [center[0], center[1], focusKey]);
  return null;
}

type View = { lat: number; lng: number; zoom: number; s: number; w: number; n: number; e: number };
function Watcher({ onChange }: { onChange: (v: View) => void }) {
  const map = useMap();
  const emit = () => {
    const c = map.getCenter();
    const b = map.getBounds();
    onChange({ lat: c.lat, lng: c.lng, zoom: map.getZoom(), s: b.getSouth(), w: b.getWest(), n: b.getNorth(), e: b.getEast() });
  };
  useEffect(() => {
    emit();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  useMapEvents({ moveend: emit, zoomend: emit });
  return null;
}

/**
 * Groupe : points superposés (même position à ~25 m près — un gardien qui est
 * aussi promeneur, deux voisins) = la LISTE tout de suite, zoomer ne les
 * séparerait pas (PawMap 585) ; sinon on cadre le groupe ; zoom rue = liste.
 */
function ClusterMarker({ center, items, onList }: { center: [number, number]; items: PublicProvider[]; onList: (l: PublicProvider[]) => void }) {
  const map = useMap();
  return (
    <Marker
      position={center}
      icon={clusterIcon(items)}
      zIndexOffset={PIN_Z.member}
      eventHandlers={{
        click: () => {
          let far = 0;
          for (let i = 0; i < items.length; i += 1) for (let j = i + 1; j < items.length; j += 1) far = Math.max(far, haversineKm(items[i].lat, items[i].lng, items[j].lat, items[j].lng) * 1000);
          // Même personne (gardien ET promeneur) : même prénom et même photo —
          // la route publique n'envoie pas d'identifiant de personne.
          const samePerson = items.every((p) => p.avatar && p.avatar === items[0].avatar && p.name === items[0].name);
          if (far <= 25 || samePerson || map.getZoom() >= 16) { onList(items); return; }
          try {
            map.stop();
            map.flyToBounds(L.latLngBounds(items.map((p) => [p.lat, p.lng] as [number, number])), { padding: [60, 60], maxZoom: 18, duration: 0.8 });
          } catch {
            safeFly(map, center, Math.min(map.getZoom() + 2.2, 18), 0.8);
          }
        },
      }}
    />
  );
}

export type PublicPawMapProps = {
  center: [number, number];
  zoom?: number;
  /** Hauteur CSS de la carte (ex. "60vh" ou "360px"). */
  height?: string;
  /** Aperçu de l'accueil : moins de contrôles, un seul bouton « Ouvrir ». */
  compact?: boolean;
  /** Change à CHAQUE recherche / « ma position » : force le vol + zoom. */
  focusKey?: number;
  onProviders?: (list: PublicProvider[]) => void;
};

export default function PublicPawMap({ center, zoom = 12, height = "60vh", compact = false, focusKey = 0, onProviders }: PublicPawMapProps) {
  const { t } = useT();
  const { user, ready } = useAuth();
  const [providers, setProviders] = useState<PublicProvider[]>([]);
  const [view, setView] = useState<View>({ lat: center[0], lng: center[1], zoom, s: center[0] - 0.1, w: center[1] - 0.15, n: center[0] + 0.1, e: center[1] + 0.15 });
  const [fetchedOnce, setFetchedOnce] = useState(false);
  const [clusterList, setClusterList] = useState<PublicProvider[] | null>(null);
  const [legendOpen, setLegendOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [dark, setDark] = useState(false);
  const lastFetch = useRef<{ lat: number; lng: number } | null>(null);
  const reqSeq = useRef(0);

  // Chargement des prestataires autour du centre courant (recharge quand on a
  // bougé d'au moins ~5 km, pour ne pas marteler l'API). Le compteur de
  // requêtes remplace un drapeau « alive » de nettoyage : en développement
  // React monte deux fois les effets (StrictMode), et un drapeau annulait la
  // seule requête partie → carte vide et spinner figé (vu le 24/09).
  useEffect(() => {
    const prev = lastFetch.current;
    const moved = !prev || Math.abs(prev.lat - view.lat) > 0.045 || Math.abs(prev.lng - view.lng) > 0.06;
    if (!moved) return;
    lastFetch.current = { lat: view.lat, lng: view.lng };
    const seq = ++reqSeq.current;
    setLoading(true);
    getPublicProviders({ lat: view.lat, lng: view.lng, radiusKm: 30 })
      .then((list) => {
        if (seq !== reqSeq.current) return;
        setProviders(list);
        onProviders?.(list);
      })
      .catch(() => {})
      .finally(() => { if (seq === reqSeq.current) { setLoading(false); setFetchedOnce(true); } });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [view.lat, view.lng]);

  const clusters = useMemo(
    () => clusterize(providers, view.zoom, (p) => [p.lat, p.lng], MEMBER_CELL_PX),
    [providers, view.zoom],
  );
  const showCaption = view.zoom >= 14;
  const roleLabel: Record<string, string> = { sitter: t("role_sitter"), walker: t("role_walker"), owner: t("role_owner") };
  // Membres DANS la zone visible : l'état vide ne s'affiche que s'il n'y a
  // vraiment personne à l'écran (avant : dès que la dernière requête, faite
  // autour d'un autre centre, revenait vide).
  const visibleCount = useMemo(
    () => providers.filter((p) => p.lat >= view.s && p.lat <= view.n && p.lng >= view.w && p.lng <= view.e).length,
    [providers, view.s, view.n, view.w, view.e],
  );
  const empty = fetchedOnce && !loading && visibleCount === 0;
  const captionOf = (p: PublicProvider) => {
    if (!showCaption) return null;
    const first = (p.name || "").trim().split(/\s+/)[0];
    return [first, roleLabel[p.role], formatPrice(p.priceFrom, p.currency)].filter(Boolean).join(" · ");
  };

  return (
    <div className="relative w-full overflow-hidden rounded-[28px]" style={{ height }}>
      <style dangerouslySetInnerHTML={{ __html: PAWMAP_KEYFRAMES }} />
      <MapContainer center={center} zoom={zoom} minZoom={3} maxZoom={18} style={{ height: "100%", width: "100%" }} scrollWheelZoom={!compact} zoomControl={false}>
        {!compact && <ZoomControl position="bottomright" />}
        {dark ? (
          <TileLayer key="dark" className="hps-dark-tiles" attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>' url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" maxZoom={19} />
        ) : (
          <TileLayer attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>' url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" maxZoom={19} />
        )}
        <Recenter center={center} zoom={zoom} focusKey={focusKey} />
        <Watcher onChange={setView} />
        {clusters.map((g, i) =>
          g.items.length > 1 ? (
            <ClusterMarker key={`c-${i}-${g.items.length}-${g.center[0].toFixed(3)}`} center={g.center} items={g.items} onList={setClusterList} />
          ) : null,
        )}
        {clusters.filter((g) => g.items.length === 1).map((g) => g.items[0]).map((p) => {
          const color = ROLE_COLOR[p.role];
          const bookHref = `/book/${p.role}/${p.id}`;
          const href = ready && user ? bookHref : `/signup?next=${encodeURIComponent(bookHref)}`;
          return (
            <Marker key={`p-${p.id}`} position={[p.lat, p.lng]} icon={memberIcon(p, captionOf(p))} zIndexOffset={p.boosted ? PIN_Z.memberBoosted : PIN_Z.member}>
              <Popup autoPan>
                <div style={{ minWidth: 200 }}>
                  <div className="flex items-center gap-3">
                    {p.avatar ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={p.avatar} alt="" width={44} height={44} className="rounded-full object-cover" style={{ width: 44, height: 44, border: `2.5px solid ${color}` }} />
                    ) : (
                      <span className="grid h-11 w-11 place-items-center rounded-full text-white" style={{ background: color }}>
                        <AppIcon name={p.role === "walker" ? "walker" : "home"} size={22} color="#fff" />
                      </span>
                    )}
                    <div className="min-w-0">
                      <div className="truncate text-[15px] font-bold text-[#231715]">{p.name || roleLabel[p.role]}</div>
                      <div className="text-xs font-semibold" style={{ color }}>{roleLabel[p.role]}{p.city ? ` · ${p.city}` : ""}</div>
                    </div>
                  </div>
                  <div className="mt-2 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-[#231715]">
                    {p.rating > 0 && (
                      <span className="inline-flex items-center gap-1 font-bold"><AppIcon name="star" size={13} color="#F4C04A" />{p.rating.toFixed(1)}{p.reviewsCount > 0 ? ` (${p.reviewsCount})` : ""}</span>
                    )}
                    {formatPrice(p.priceFrom, p.currency) && (
                      <span className="font-bold" style={{ color }}>{t("map_member_price_from")} {formatPrice(p.priceFrom, p.currency)}</span>
                    )}
                    {p.identityVerified && (
                      <span className="inline-flex items-center gap-1 font-semibold text-[#16A34A]"><AppIcon name="shield-check" size={13} color="#16A34A" />{t("trust_id_title")}</span>
                    )}
                    {p.availableToday && (
                      <span className="rounded-full bg-[#DEF7E5] px-2 py-0.5 font-semibold text-[#0F7C37]">{t("map_available_today")}</span>
                    )}
                  </div>
                  <div className="mt-1 text-[11px] text-[#8A6B64]">{t("map_member_approx").replace("{km}", String(p.approxKm))}</div>
                  <Link
                    href={href}
                    className="mt-3 flex min-h-[44px] items-center justify-center gap-2 rounded-[14px] px-4 text-sm font-bold text-white"
                    style={{ background: `linear-gradient(90deg, ${p.role === "sitter" ? "#2563EB" : "#15803D"}, ${p.role === "sitter" ? "#1E4FB0" : "#166534"})`, color: "#fff" }}
                  >
                    <span className="grid h-7 w-7 place-items-center rounded-full bg-white"><AppIcon name="calendar" size={15} color={color} /></span>
                    {ready && user ? t("map_member_book") : t("pawmap_signup_to_contact")}
                  </Link>
                </div>
              </Popup>
            </Marker>
          );
        })}
      </MapContainer>

      {/* Bouton « ? » (légende) + mode sombre + compteur : au-dessus des panneaux Leaflet. */}
      <div className="absolute left-3 top-3 z-[1000] flex items-center gap-2">
        <button
          type="button"
          onClick={() => setLegendOpen(true)}
          aria-label={t("legend_btn")}
          title={t("legend_btn")}
          className="grid h-11 w-11 place-items-center rounded-full bg-white text-[#231715] shadow-lg transition hover:scale-105"
        >
          <AppIcon name="question" size={22} />
        </button>
        {!compact && (
          <button
            type="button"
            onClick={() => setDark((d) => !d)}
            aria-label={t("map_dark_mode")}
            title={t("map_dark_mode")}
            aria-pressed={dark}
            className="grid h-11 w-11 place-items-center rounded-full bg-white text-[#231715] shadow-lg transition hover:scale-105"
          >
            <AppIcon name={dark ? "sun" : "moon"} size={20} />
          </button>
        )}
        {visibleCount > 0 && (
          <span className="rounded-full bg-white/95 px-3 py-2 text-xs font-bold text-[#231715] shadow-lg">
            {t("map_members_around").replace("{count}", String(visibleCount))}
          </span>
        )}
        {loading && <span className="h-5 w-5 animate-spin rounded-full border-2 border-[#C92A12] border-t-transparent" />}
      </div>

      {/* Carte vide = une action (idée 1 validée) : sans gardien autour, on propose la suite. */}
      {empty && (
        <div className="absolute inset-x-3 bottom-3 z-[1000] rounded-[20px] bg-white/95 p-4 shadow-xl sm:inset-x-auto sm:left-3 sm:max-w-xs">
          <p className="text-sm font-bold text-[#231715]">{t("map_empty_title")}</p>
          <div className="mt-2 flex flex-col gap-2">
            <Link href="/posts/create" className="flex min-h-[44px] items-center justify-center gap-2 rounded-[14px] bg-owner px-4 text-sm font-bold text-white transition hover:bg-owner-dark">
              <AppIcon name="megaphone" size={16} color="#fff" />{t("map_empty_owner_cta")}
            </Link>
            <Link href="/signup" className="flex min-h-[44px] items-center justify-center gap-2 rounded-[14px] border-[1.5px] border-sitter px-4 text-sm font-bold text-sitter-dark transition hover:bg-sitter-light">
              <AppIcon name="home" size={16} color="#1A73E8" />{t("map_empty_provider_cta")}
            </Link>
          </div>
        </div>
      )}

      {compact && (
        <Link
          href="/pawmap"
          className="absolute bottom-3 right-3 z-[1000] inline-flex min-h-[44px] items-center gap-2 rounded-full bg-[#D83C28] px-5 text-sm font-bold text-white shadow-lg transition hover:bg-[#B92425]"
        >
          {t("cta_open_pawmap")}
          <AppIcon name="arrow-right" size={16} color="#fff" />
        </Link>
      )}

      {/* Groupe toujours superposé au zoom rue : la liste de ses membres. */}
      {clusterList && (
        <div className="absolute inset-x-3 bottom-3 z-[1100] max-h-[60%] overflow-y-auto rounded-[20px] bg-white p-3 shadow-xl sm:inset-x-auto sm:left-3 sm:w-80">
          <div className="mb-2 flex items-center justify-between px-1">
            <p className="text-sm font-bold text-[#231715]">{t("map_members_around").replace("{count}", String(clusterList.length))}</p>
            <button type="button" onClick={() => setClusterList(null)} aria-label={t("common_close")} className="grid h-9 w-9 place-items-center rounded-full bg-[#FAF1EC] text-[#231715]">
              <AppIcon name="close" size={16} />
            </button>
          </div>
          <ul className="space-y-1.5">
            {clusterList.map((p) => {
              const color = ROLE_COLOR[p.role];
              const bookHref = `/book/${p.role}/${p.id}`;
              const href = ready && user ? bookHref : `/signup?next=${encodeURIComponent(bookHref)}`;
              return (
                <li key={`cl-${p.id}`}>
                  <Link href={href} className="flex min-h-[52px] items-center gap-3 rounded-2xl px-2 py-1.5 transition hover:bg-[#FAF1EC]">
                    <span className="h-10 w-10 shrink-0 overflow-hidden rounded-full" style={{ border: `2.5px solid ${color}`, background: color }}>
                      {p.avatar ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img src={p.avatar} alt="" className="h-full w-full object-cover" />
                      ) : (
                        <span className="grid h-full w-full place-items-center"><AppIcon name={p.role === "walker" ? "walker" : "home"} size={18} color="#fff" /></span>
                      )}
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className="block truncate text-sm font-bold text-[#231715]">{p.name || roleLabel[p.role]}</span>
                      <span className="block text-xs font-semibold" style={{ color }}>{roleLabel[p.role]}{formatPrice(p.priceFrom, p.currency) ? ` · ${t("map_member_price_from")} ${formatPrice(p.priceFrom, p.currency)}` : ""}</span>
                    </span>
                    <AppIcon name="arrow-right" size={16} color={color} />
                  </Link>
                </li>
              );
            })}
          </ul>
        </div>
      )}

      <PawMapLegendModal open={legendOpen} onClose={() => setLegendOpen(false)} />
    </div>
  );
}
