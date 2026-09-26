"use client";

// v23.1 part 146 — PawMap interactive : la carte des points d'intérêt
// pet-friendly (vétos, parcs, plages, points d'eau, hôtels…). Auth required.
//
// v23.1 carte unique — Daniel : "sur le site web, UNE SEULE carte : depuis
// /map on a PawFollow (amis/famille en direct), PawSpot (spots
// communautaires) et l'itinéraire, tout réuni". Une seule MapContainer
// (PoiMap), la logique amis/famille + socket vit ici.
//
// 24/09/2026 — LOT B, étape 3 (plan de LEO validé par Daniel) : LA MÊME CARTE
// QUE L'APP, pas une cousine.
//   • Ordinateur en 2 colonnes : la carte à gauche (pleine hauteur), le
//     panneau à droite ; téléphone : une colonne + feuille glissante en bas
//     (3 positions : poignée / moitié / plein).
//   • Légende LEGENDE_PAWMAP.md appliquée à la lettre (PoiMap) + bouton « ? ».
//   • Un seul sélecteur « Je cherche : gardiens / promeneurs / propriétaires /
//     lieux / amis / demandes » à la place de la pile d'interrupteurs (les
//     réglages fins — catégories de lieux — restent en dessous).
//   • Réserver en 2 clics depuis une épingle, prix sur l'épingle au zoom rue.
//   • Demandes des propriétaires en bulle orange (position floutée ~1 km),
//     « Proposer mes services » en 1 clic.
//   • Compteur cliquable « N membres à moins de 50 km » → liste.
//   • Carte vide = une action. Mode sombre. Ouverture sur ma position en
//     gardant le ZOOM (mémorisé). Zoom de suivi « joli » (vol, suit, tracé
//     violet, pause au geste, « Reprendre le suivi »).
//   • Mode « visible par mes amis seulement » : marques sur MON rond + pastille
//     en haut de la carte pour rebasculer en 1 geste (même réglage que les
//     Préférences, synchronisé sur le compte).
// Toutes les fonctions d'avant sont conservées (mêmes handlers, mêmes routes).

import dynamic from "next/dynamic";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import { locationDisplay } from "@/lib/i18n/publish587";
import { evaluateOpeningHours } from "@/lib/openingHours";
import type { RouteMode } from "@/lib/api";
import BackLink from "@/components/BackLink";
import { PawMapLogo } from "@/components/PawMapLogo";
import { AppIcon, type AppIconName } from "@/components/AppIcon";
import { PageTitle } from "@/components/PageTitle";
import { PawMapLegendModal } from "@/components/PawMapLegendModal";
import { PawMapAnnouncement } from "@/components/PawMapAnnouncement";
import { StatusToast, type StatusToastKind } from "@/components/StatusToast";
import { SelectMenu } from "@/components/SelectMenu";
import StoreBadges from "@/components/StoreBadges";
import { EyeIcon, VisibilityPills } from "@/components/MapVisibility";
import { ensureOwnerProfile } from "@/lib/bookAsOwner";
import type { MapRequest, LiveLabels, CardLabels } from "@/components/PoiMap";
import {
  ApiError,
  FriendItem,
  MapReport,
  MapReportType,
  MyBenefits,
  NearbyMember,
  PawSpot,
  PawSpotType,
  POI_CATEGORY_LABELS,
  Poi,
  PoiCategory,
  RouteResult,
  createMapReport,
  createPawSpot,
  uploadImage,
  startFriendConversation,
  startProviderConversation,
  startConversationWithOwner,
  getFriendsLivePositions,
  getMyBenefits,
  getMapSeekPrefs,
  getMapBarPrefs,
  saveMapBarPrefs,
  saveMapSeekPrefs,
  saveMapLayerPrefs,
  type MapLayerPrefs,
  getMyFamily,
  getMyFriends,
  getMyPosts,
  getNearbyMembers,
  getRequestPosts,
  getWorldMembers,
  sendFriendRequest,
  getMapVisibility,
  setMapVisibility,
  nextMapVisibility,
  type MapVisibility,
  getNearbyPawSpots,
  getNearbyReports,
  getNearbyPois,
  getPawSpotDirections,
  getStoredUser,
  visitSpot,
} from "@/lib/api";
import { useSocket, useSocketEvent } from "@/lib/useSocket";
import { usePresence } from "@/lib/usePresence";
import { getSocket } from "@/lib/socket";
import type { FriendLivePosition } from "@/components/FriendsLiveMap";
import { haversineKm } from "@/lib/mapCluster";
import { ROLE_COLOR, blurLatLng, formatPrice, placePinHtml, reportPinHtml, spotPinHtml, roleKey } from "@/lib/pawmapLegend";
import { expandRows, formatKm, friendIdSetFrom, isFriendMember, locateFriend, mergePersons, personIdsOf, placeFriendsFromList, rolesMatching } from "@/lib/memberPersons";
import type { Map as LeafletMap } from "leaflet";

const roleChipColor = (role: string) => ROLE_COLOR[roleKey(role)];

// PoiMap est dynamic pour éviter le SSR de Leaflet.
const PoiMap = dynamic(() => import("@/components/PoiMap"), {
  ssr: false,
  loading: () => (
    <div className="flex h-full min-h-[420px] items-center justify-center rounded-[28px] bg-[#FAF1EC] text-[#6E4F48]">
      <span className="h-6 w-6 animate-spin rounded-full border-2 border-[#C92A12] border-t-transparent" />
    </div>
  ),
});

const ALL_CATEGORIES = Object.keys(POI_CATEGORY_LABELS) as PoiCategory[];

function roleFromModel(model: string): "walker" | "sitter" | "owner" {
  const m = (model || "").toLowerCase();
  if (m === "walker") return "walker";
  if (m === "sitter") return "sitter";
  return "owner";
}

export default function MapPage() {
  const { t, lang } = useT();
  const router = useRouter();
  const [userLocation, setUserLocation] = useState<{ lat: number; lng: number } | null>(null);
  const [userAccuracy, setUserAccuracy] = useState<number | null>(null);
  // v500 — ouverture sur la DERNIÈRE position connue (Paris pour un tout 1er usage).
  // v552 — lien partagé /map?lat&lng&z prioritaire.
  const [center, setCenter] = useState<[number, number]>(() => {
    if (typeof window !== "undefined") {
      try {
        const qs = new URLSearchParams(window.location.search);
        const qlat = parseFloat(qs.get("lat") || "");
        const qlng = parseFloat(qs.get("lng") || "");
        if (Number.isFinite(qlat) && Number.isFinite(qlng)) return [qlat, qlng];
      } catch {/* ignore */}
      try {
        const saved = window.localStorage.getItem("hopetsit:lastMapCenter");
        if (saved) {
          const p = JSON.parse(saved);
          if (typeof p?.lat === "number" && typeof p?.lng === "number") return [p.lat, p.lng];
        }
      } catch {/* ignore */}
    }
    return [48.8566, 2.3522];
  });
  // 24/09 — le ZOOM aussi est retenu (légende : « retenir aussi le zoom »).
  const [initialZoom] = useState<number>(() => {
    if (typeof window !== "undefined") {
      try {
        const qs = new URLSearchParams(window.location.search);
        const qz = parseFloat(qs.get("z") || "");
        if (Number.isFinite(qz) && qz >= 3 && qz <= 19) return qz;
        const z = parseFloat(window.localStorage.getItem("hopetsit:lastMapZoom") || "");
        if (Number.isFinite(z) && z >= 3 && z <= 19) return z;
      } catch {/* ignore */}
    }
    return 13;
  });
  const [pois, setPois] = useState<Poi[]>([]);
  const [selectedCats, setSelectedCats] = useState<PoiCategory[]>([]);
  const [noneSelected, setNoneSelected] = useState(false);
  const [loading, setLoading] = useState(true);
  const [fetching, setFetching] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [premiumDays, setPremiumDays] = useState<number | null>(null);
  const [myAvatarUrl, setMyAvatarUrl] = useState<string | null>(null);
  const [myName, setMyName] = useState("");
  // 25/09 (PawMap 586, point 3) — « qui me voit » à 3 états (Tous / Amis
  // seulement / Masqué), UNE route : /users/me/map-prefs (lib/api.ts). Mon
  // rond garde l'anneau pointillé + l'œil barré dès que je ne suis pas
  // visible par tous.
  const [visibility, setVisibility] = useState<MapVisibility>("all");
  const friendsOnly = visibility !== "all";
  const [friendsOnlyBusy, setFriendsOnlyBusy] = useState(false);
  const [friendsOnlyMsg, setFriendsOnlyMsg] = useState<{ kind: StatusToastKind; text: string } | null>(null);
  useEffect(() => {
    if (!getStoredUser()) return;
    getMapVisibility().then(setVisibility).catch(() => { /* repli : visible par tous */ });
  }, []);
  const [liveInfoOpen, setLiveInfoOpen] = useState(false);
  // 25/09 (587, point 1a) — MON direct : le site n'envoie pas de GPS, il lit
  // seulement l'état écrit par l'app sur mon profil (location.liveShareActive
  // + dernier signe de vie location.updatedAt, règle serveur liveState : actif
  // si le dernier signe de vie a moins de 10 min). La durée s'affiche quand le
  // serveur donne l'heure de départ (liveShareStartedAt), sinon « En direct ».
  const [myLive, setMyLive] = useState<{ on: boolean; startedAt: number | null }>({ on: false, startedAt: null });
  useEffect(() => {
    const me = getStoredUser();
    // 587 (Daniel : « le bouton en haut à gauche pour les 3 profils ») — un
    // propriétaire promène aussi son chien : son direct se lit comme les autres.
    if (!me) return;
    let stop = false;
    const read = async () => {
      try {
        const { getMyProfile } = await import("@/lib/api");
        const p = (await getMyProfile()) as unknown as { location?: { liveShareActive?: boolean; updatedAt?: string | null; liveShareStartedAt?: string | null }; liveShareStartedAt?: string | null };
        const loc = p?.location || {};
        const seen = loc.updatedAt ? new Date(loc.updatedAt).getTime() : NaN;
        const on = loc.liveShareActive === true && Number.isFinite(seen) && Date.now() - seen <= 10 * 60 * 1000;
        const st = loc.liveShareStartedAt || p?.liveShareStartedAt || null;
        const startedAt = st && Number.isFinite(new Date(st).getTime()) ? new Date(st).getTime() : null;
        if (!stop) setMyLive({ on, startedAt: on ? startedAt : null });
      } catch { /* repli : arrêté */ }
    };
    void read();
    const id = setInterval(() => { void read(); }, 60000);
    return () => { stop = true; clearInterval(id); };
  }, []);
  useEffect(() => {
    const me = getStoredUser();
    if (!me) return;
    setMyName(me.name || "");
    (async () => {
      try {
        const { getMyProfile } = await import("@/lib/api");
        const p = await getMyProfile();
        const url = p?.avatar?.url || null;
        if (url) setMyAvatarUrl(url);
        if (p?.name) setMyName(p.name);
      } catch { /* repli : initiales */ }
    })();
  }, []);
  const [isStaffSub, setIsStaffSub] = useState(false);
  useEffect(() => {
    (async () => {
      try {
        const { getSubscriptionStatus } = await import("@/lib/api");
        const st = await getSubscriptionStatus();
        const staff = st.currentPeriodEnd ? new Date(st.currentPeriodEnd).getFullYear() >= 2090 : false;
        setIsStaffSub(staff);
        if (st.premiumExpiry) {
          const d = Math.ceil((new Date(st.premiumExpiry).getTime() - Date.now()) / 86400000);
          if (d > 0) setPremiumDays(d);
        }
      } catch { /* non connecté → bouton d'achat visible */ }
    })();
  }, []);
  const [selectedPoi, setSelectedPoi] = useState<Poi | null>(null);

  // ── couches ──
  const [benefits, setBenefits] = useState<MyBenefits | null>(null);
  // 25/09 (point 11) — mes amis sont affichés dès l'ouverture (comme l'app).
  const [showFriends, setShowFriends] = useState(true);
  const [showSpots, setShowSpots] = useState(false);
  const [spots, setSpots] = useState<PawSpot[]>([]);
  const [showReports, setShowReports] = useState(false);
  const [memberRoles, setMemberRoles] = useState<string[]>(["sitter", "walker", "owner"]);
  const [reports, setReports] = useState<MapReport[]>([]);
  const [members, setMembers] = useState<NearbyMember[]>([]);
  const [worldMembers, setWorldMembers] = useState<NearbyMember[]>([]);
  const [createKind, setCreateKind] = useState<null | "spot" | "report">(null);
  const [createType, setCreateType] = useState<string>("");
  const [createName, setCreateName] = useState("");
  const [createNote, setCreateNote] = useState("");
  const [creating, setCreating] = useState(false);
  const [createErr, setCreateErr] = useState<string | null>(null);
  const [createPhoto, setCreatePhoto] = useState<File | null>(null);
  const [createPhotoPreview, setCreatePhotoPreview] = useState<string | null>(null);
  const [uploadingPhoto, setUploadingPhoto] = useState(false);
  const photoInputRef = useRef<HTMLInputElement | null>(null);
  const [sidePanel, setSidePanel] = useState<null | "reports" | "spots" | "members">(null);
  const [friendsLoading, setFriendsLoading] = useState(false);
  const [friendsForMap, setFriendsForMap] = useState<FriendItem[]>([]);
  const [familyIds, setFamilyIds] = useState<string[]>([]);
  const [premiumIds, setPremiumIds] = useState<string[]>([]);
  const [livePositions, setLivePositions] = useState<Map<string, FriendLivePosition>>(new Map());
  const friendsLoadedRef = useRef(false);
  const [friendSeen, setFriendSeen] = useState<Record<string, string | null>>({});
  const [route, setRoute] = useState<RouteResult | null>(null);
  const [routeLoading, setRouteLoading] = useState(false);
  const [routeMode, setRouteModeState] = useState<RouteMode>("walk");
  const [routeTarget, setRouteTarget] = useState<{ lat: number; lng: number } | null>(null);
  const [showSteps, setShowSteps] = useState(false);
  useEffect(() => {
    try {
      const saved = localStorage.getItem("pawmap_route_mode");
      if (saved === "walk" || saved === "bike" || saved === "car") setRouteModeState(saved);
    } catch { /* stockage indisponible */ }
  }, []);
  const ROUTE_COLORS: Record<RouteMode, string> = { walk: "#C92A12", bike: "#16A34A", car: "#2563EB" };
  const routeColor = ROUTE_COLORS[routeMode];

  // 24/09 — nouveautés d'interface.
  const [dark, setDark] = useState(false);
  useEffect(() => {
    try { setDark(localStorage.getItem("hopetsit:mapDark") === "1"); } catch { /* ignore */ }
  }, []);
  const [legendOpen, setLegendOpen] = useState(false);
  // 25/09 (587, point 3) — barres repliables : rail gauche et capsule droite
  // glissent hors de l'écran (transform seul, 200 ms) en laissant une
  // languette ; état retenu sur le COMPTE (pawMap.railCollapsed /
  // capsuleCollapsed, mêmes clés que l'app), recopié sur l'appareil pour
  // l'affichage immédiat et comme repli si le serveur ne le garde pas.
  const [railCollapsed, setRailCollapsed] = useState(false);
  const [capsuleCollapsed, setCapsuleCollapsed] = useState(false);
  useEffect(() => {
    try {
      setRailCollapsed(localStorage.getItem("hopetsit:mapRailCollapsed") === "1");
      setCapsuleCollapsed(localStorage.getItem("hopetsit:mapCapsuleCollapsed") === "1");
    } catch { /* stockage indisponible */ }
    if (!getStoredUser()) return;
    let stop = false;
    void getMapBarPrefs().then((p) => {
      if (stop || !p) return;
      if (p.railCollapsed !== null) { setRailCollapsed(p.railCollapsed); try { localStorage.setItem("hopetsit:mapRailCollapsed", p.railCollapsed ? "1" : "0"); } catch { /* */ } }
      if (p.capsuleCollapsed !== null) { setCapsuleCollapsed(p.capsuleCollapsed); try { localStorage.setItem("hopetsit:mapCapsuleCollapsed", p.capsuleCollapsed ? "1" : "0"); } catch { /* */ } }
    });
    return () => { stop = true; };
  }, []);
  function toggleBar(key: "railCollapsed" | "capsuleCollapsed") {
    const cur = key === "railCollapsed" ? railCollapsed : capsuleCollapsed;
    const next = !cur;
    if (key === "railCollapsed") setRailCollapsed(next); else setCapsuleCollapsed(next);
    try { localStorage.setItem(key === "railCollapsed" ? "hopetsit:mapRailCollapsed" : "hopetsit:mapCapsuleCollapsed", next ? "1" : "0"); } catch { /* */ }
    if (getStoredUser()) void saveMapBarPrefs({ [key]: next });
  }

  // 25/09 (585) — capsule droite : zoom, ma position, satellite, membres.
  const mapRef = useRef<LeafletMap | null>(null);
  const [satellite, setSatellite] = useState(false);
  useEffect(() => {
    try { setSatellite(localStorage.getItem("hopetsit:mapSat") === "1"); } catch { /* ignore */ }
  }, []);
  const [followUserId, setFollowUserId] = useState<string | null>(null);
  const [followPaused, setFollowPaused] = useState(false);
  const [followSheet, setFollowSheet] = useState(false);
  const [liveToast, setLiveToast] = useState<string | null>(null);
  // 25/09 (586, point 1) — au repos la feuille DISPARAÎT (« closed ») : seule
  // reste la poignée « Options » en bas au centre de la carte.
  const [sheet, setSheet] = useState<"closed" | "half" | "full">("closed");
  const sheetDragRef = useRef<number | null>(null);
  // 25/09 (586, point 1 suite) — téléphone / tablette : la carte descend
  // jusqu'au BAS de l'écran, bord à bord (aucune bande sous la poignée).
  const mapColRef = useRef<HTMLDivElement | null>(null);
  const [fitH, setFitH] = useState<number | null>(null);
  useEffect(() => {
    if (loading) return;
    const fit = () => {
      const el = mapColRef.current;
      if (!el) { setFitH(null); return; }
      // Bureau aussi : carte (et panneau latéral) jusqu'au bas de l'écran.
      const top = el.getBoundingClientRect().top + window.scrollY;
      setFitH(Math.max(window.innerWidth >= 1024 ? 560 : 420, Math.round(window.innerHeight - top)));
    };
    fit();
    window.addEventListener("resize", fit);
    return () => window.removeEventListener("resize", fit);
  }, [loading]);
  // 25/09 (586, point 4) — la carte bouge (glisser, molette, pincement) :
  // rails, capsule, en-tête de la carte et poignée passent à 35 % ; retour à
  // 100 % au relâchement + 1 s, ou au premier toucher d'un contrôle.
  const [mapGesture, setMapGesture] = useState(false);
  const gestureTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const [mapReadyTick, setMapReadyTick] = useState(0);
  useEffect(() => {
    const m = mapRef.current;
    if (!m) return;
    const start = () => {
      if (gestureTimerRef.current) { clearTimeout(gestureTimerRef.current); gestureTimerRef.current = null; }
      setMapGesture(true);
    };
    const end = () => {
      if (gestureTimerRef.current) clearTimeout(gestureTimerRef.current);
      gestureTimerRef.current = setTimeout(() => setMapGesture(false), 1000);
    };
    const el = m.getContainer();
    // Geste de l'UTILISATEUR seulement (glisser, molette, pincement) : un vol
    // programmé (ma position, suivi) ne doit pas effacer les contrôles.
    const onWheel = () => { start(); end(); };
    const onTouch = (e: TouchEvent) => { if (e.touches.length >= 2) start(); };
    m.on("dragstart", start);
    m.on("dragend", end);
    const onZoomEnd = () => { if (gestureTimerRef.current) end(); };
    m.on("zoomend", onZoomEnd);
    el.addEventListener("wheel", onWheel, { passive: true });
    el.addEventListener("touchstart", onTouch, { passive: true });
    el.addEventListener("touchend", end, { passive: true });
    return () => {
      m.off("dragstart", start);
      m.off("dragend", end);
      m.off("zoomend", onZoomEnd);
      el.removeEventListener("wheel", onWheel);
      el.removeEventListener("touchstart", onTouch);
      el.removeEventListener("touchend", end);
      if (gestureTimerRef.current) clearTimeout(gestureTimerRef.current);
    };
  }, [mapReadyTick]);
  const revealControls = useCallback(() => {
    if (gestureTimerRef.current) { clearTimeout(gestureTimerRef.current); gestureTimerRef.current = null; }
    setMapGesture(false);
  }, []);
  const [showRequests, setShowRequests] = useState(true);
  const [requests, setRequests] = useState<MapRequest[]>([]);
  const [catsOpen, setCatsOpen] = useState(false);
  // 26/09 (589) — rond « Actualiser » de l'en-tête : un clic relance TOUTES
  // les couches (lieux, membres, monde, PawSpots, signalements, demandes,
  // amis) ; petit cercle qui tourne pendant le chargement.
  const [reloadTick, setReloadTick] = useState(0);
  const [refreshing, setRefreshing] = useState(false);
  // 26/09 (589) — roue « Options de la carte » : sur ordinateur le panneau est
  // déjà là, la roue le remonte en haut et le fait briller un instant.
  const [optionsFlash, setOptionsFlash] = useState(false);
  const panelScrollRef = useRef<HTMLDivElement | null>(null);
  // 26/09 (589, point 3) — le rail gauche ne touche JAMAIS la rangée du haut
  // (« Direct », « Amis ») : écart entre boutons resserré (10 → 4 px), puis
  // boutons réduits (44 → 36 px) si la carte est basse.
  const topRowRef = useRef<HTMLDivElement | null>(null);
  const [railFit, setRailFit] = useState<{ gap: number; btn: number }>({ gap: 10, btn: 44 });
  // Carte très basse et rangée du haut sur 2 lignes : « Amis » passe en rond
  // (icône seule, nom en info-bulle) pour que tout tienne sur UNE ligne.
  const [compactTop, setCompactTop] = useState(false);
  // Même règle pour la capsule droite : jamais sur les ronds orange du haut
  // (réduite d'un bloc, jusqu'à 72 %, si la carte est très basse).
  const capsuleRef = useRef<HTMLDivElement | null>(null);
  const [capsuleScale, setCapsuleScale] = useState(1);
  const [shareToast, setShareToast] = useState(false);
  useEffect(() => {
    if (loading) return;
    const N = 8; // boutons du rail gauche (même ordre que l'app)
    const measure = () => {
      const col = mapColRef.current;
      if (!col) return;
      const h = col.getBoundingClientRect().height;
      const row = topRowRef.current;
      const topReserve = row ? row.getBoundingClientRect().bottom - col.getBoundingClientRect().top + 10 : 66;
      // bas du rail = 16 px ; capsule de verre = 2 × 6 px de marge intérieure.
      const fit = (room: number) => {
        let b = 44;
        let g = Math.floor((room - N * b) / (N - 1));
        if (g >= 10) g = 10;
        else if (g < 4) {
          g = 4;
          b = Math.max(34, Math.floor((room - (N - 1) * g) / N));
        }
        return { gap: g, btn: b };
      };
      const avail = h - topReserve - 16 - 12;
      const { gap, btn } = fit(avail);
      setRailFit((p) => (p.gap === gap && p.btn === btn ? p : { gap, btn }));
      const cap = capsuleRef.current;
      if (cap) {
        const natural = cap.offsetHeight;
        const room = h - (12 + 44 + 10) - 16;
        const sc = natural > room ? Math.max(0.72, Math.floor((room / natural) * 100) / 100) : 1;
        setCapsuleScale((p) => (p === sc ? p : sc));
      }
      const rowH = row ? row.getBoundingClientRect().height : 44;
      setCompactTop((c) => {
        if (!c && rowH > 60 && btn < 40) return true;
        // Retour au nom écrit seulement s'il reste LARGEMENT la place (pas de va-et-vient).
        if (c && fit(avail - 60).btn >= 44) return false;
        return c;
      });
    };
    measure();
    const ro = typeof ResizeObserver !== "undefined" ? new ResizeObserver(measure) : null;
    if (ro) {
      if (mapColRef.current) ro.observe(mapColRef.current);
      if (topRowRef.current) ro.observe(topRowRef.current);
      if (capsuleRef.current) ro.observe(capsuleRef.current);
    }
    window.addEventListener("resize", measure);
    return () => { ro?.disconnect(); window.removeEventListener("resize", measure); };
  }, [loading, fitH]);

  const formatOpenStatus = useCallback(
    (raw: string): { label: string; open: boolean } | null => {
      const st = evaluateOpeningHours(raw, new Date());
      if (!st) return null;
      const hm = (d: Date) => d.toLocaleTimeString(lang, { hour: "2-digit", minute: "2-digit" });
      if (st.always) return { label: t("poi_open_247"), open: true };
      if (st.isOpen && st.closesAt) return { label: t("poi_open_until").replace("{time}", hm(st.closesAt)), open: true };
      if (!st.opensAt) return { label: t("poi_closed_now"), open: false };
      const now = new Date();
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const day = new Date(st.opensAt.getFullYear(), st.opensAt.getMonth(), st.opensAt.getDate());
      const diff = Math.round((day.getTime() - today.getTime()) / 86_400_000);
      if (diff <= 0) return { label: t("poi_closed_opens_today").replace("{time}", hm(st.opensAt)), open: false };
      if (diff === 1) return { label: t("poi_closed_opens_tomorrow").replace("{time}", hm(st.opensAt)), open: false };
      return { label: t("poi_closed_opens_day").replace("{day}", st.opensAt.toLocaleDateString(lang, { weekday: "long" })).replace("{time}", hm(st.opensAt)), open: false };
    },
    [lang, t],
  );
  const [directionsLocked, setDirectionsLocked] = useState(false);
  const [directionsError, setDirectionsError] = useState(false);
  // 25/09 (Itinéraire) — d'où part le trajet : ma position GPS, ou le centre
  // de la carte quand le navigateur ne donne pas la position (dit à l'écran).
  const [routeFrom, setRouteFrom] = useState<"gps" | "center" | null>(null);

  const { connected: socketConnected } = useSocket();
  useEffect(() => {
    if (!socketConnected) return;
    const me = getStoredUser();
    if (!me) return;
    getSocket()?.emit("map:identify", { userId: me.id, role: me.role });
  }, [socketConnected]);
  const { presence, resolveOnline } = usePresence();

  // 25/09 (587, point 6) — UNE personne = UN id canonique (celui de
  // l'amitié, `other.id`), quel que soit le rôle qui partage : la socket et
  // /friends/live-positions peuvent parler du profil gardien d'un ami dont
  // l'amitié est portée par son profil propriétaire. Sans cela : deux points
  // pour la même personne.
  const friendCanon = useMemo(() => {
    const m = new Map<string, string>();
    for (const f of friendsForMap) {
      const o = f.other;
      if (!o?.id) continue;
      m.set(String(o.id), String(o.id));
      for (const x of (o as { personIds?: string[] }).personIds || []) if (x) m.set(String(x), String(o.id));
    }
    return m;
  }, [friendsForMap]);
  const friendCanonRef = useRef(friendCanon);
  friendCanonRef.current = friendCanon;
  // 26/09 (589) — le serveur envoie aussi TOUS les ids de la personne
  // (`personIds`) : si l'id reçu est inconnu, on retrouve la personne par eux.
  const canonId = useCallback((id: string, personIds?: string[]) => {
    const direct = friendCanonRef.current.get(String(id));
    if (direct) return direct;
    for (const x of personIds || []) {
      const hit = friendCanonRef.current.get(String(x));
      if (hit) return hit;
    }
    return String(id);
  }, []);
  const friendByUserId = useMemo(() => {
    const m = new Map<string, FriendItem>();
    for (const f of friendsForMap) if (f.other?.id) m.set(f.other.id, f);
    return m;
  }, [friendsForMap]);

  useSocketEvent<{ userId: string; role: string; lat: number; lng: number; at?: string; personIds?: string[] }>("map:friend-position", (raw) => {
    const data = { ...raw, userId: canonId(raw.userId, raw.personIds) };
    const friend = friendByUserId.get(data.userId);
    const baseRole = roleFromModel(friend?.other?.model || data.role || "owner");
    setLivePositions((prev) => {
      const next = new Map(prev);
      next.set(data.userId, {
        userId: data.userId,
        role: baseRole,
        name: friend?.other?.name || t("common_friend"),
        avatar: friend?.other?.avatar,
        lat: data.lat,
        lng: data.lng,
        at: data.at || new Date().toISOString(),
        // Un point reçu par la socket = le partage est actif maintenant.
        lastSeenAt: new Date().toISOString(),
        state: "live",
        isOnline: prev.get(data.userId)?.isOnline ?? friend?.isOnline ?? friend?.other?.isOnline ?? true,
      });
      return next;
    });
  });
  useSocketEvent<{ userId: string; personIds?: string[] }>("map:friend-offline", (raw) => {
    const data = { userId: canonId(raw.userId, raw.personIds) };
    setLivePositions((prev) => {
      if (!prev.has(data.userId)) return prev;
      const next = new Map(prev);
      next.delete(data.userId);
      return next;
    });
  });

  const [myRole, setMyRole] = useState<string>("sitter");
  const [focusTarget, setFocusTarget] = useState<{ lat: number; lng: number; ts: number; zoom?: number; duration?: number } | null>(null);
  // 588 — ami (position de profil floutée) choisi dans le panneau.
  const [focusFriend, setFocusFriend] = useState<{ m: NearbyMember; ts: number } | null>(null);
  // 25/09 (point 5) — zone VISIBLE de la carte : compteur et état vide.
  const [viewBounds, setViewBounds] = useState<{ s: number; w: number; n: number; e: number } | null>(null);
  const [locating, setLocating] = useState(false);
  const [locateMsg, setLocateMsg] = useState<string | null>(null);
  const [cityQuery, setCityQuery] = useState("");
  const [citySearching, setCitySearching] = useState(false);
  const [cityError, setCityError] = useState(false);
  // 25/09 (PawMap 584, point 5) — chercher une ville CENTRE et ZOOME dessus
  // (zoom 12, vol en douceur), puis les membres de la zone se chargent
  // (moveend → nouveau centre). Avant : le centre changeait sans le zoom → une
  // carte dézoomée restait sur la France et la feuille disait « personne ».
  async function geocodeCity(q: string): Promise<boolean> {
    const resp = await fetch(`https://nominatim.openstreetmap.org/search?format=json&limit=1&accept-language=${encodeURIComponent(lang)}&q=${encodeURIComponent(q)}`);
    const results = (await resp.json()) as { lat: string; lon: string }[];
    const hit = results?.[0];
    if (!hit || !Number.isFinite(parseFloat(hit.lat))) return false;
    const lat = parseFloat(hit.lat);
    const lng = parseFloat(hit.lon);
    setCenter([lat, lng]);
    setFocusTarget({ lat, lng, ts: Date.now(), zoom: 12 });
    try {
      window.localStorage.setItem("hopetsit:lastMapCenter", JSON.stringify({ lat, lng }));
      window.localStorage.setItem("hopetsit:lastMapZoom", "12");
    } catch {/* ignore */}
    return true;
  }
  async function handleCitySearch(e: React.FormEvent) {
    e.preventDefault();
    const q = cityQuery.trim();
    if (!q || citySearching) return;
    setCitySearching(true);
    setCityError(false);
    try {
      if (!(await geocodeCity(q))) setCityError(true);
    } catch {
      setCityError(true);
    } finally {
      setCitySearching(false);
    }
  }

  // Ville demandée depuis l'accueil ou /pawmap (?city=Lyon) : connecté, on
  // arrive ici avec la même recherche.
  const cityParamDone = useRef(false);
  useEffect(() => {
    if (loading || cityParamDone.current) return;
    cityParamDone.current = true;
    try {
      const c = new URLSearchParams(window.location.search).get("city");
      if (c && c.trim()) { setCityQuery(c); void geocodeCity(c.trim()).catch(() => {}); }
    } catch { /* ignore */ }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [loading]);

  // Auth + géolocalisation au mount.
  useEffect(() => {
    const me = getStoredUser();
    if (!me) {
      router.replace("/login?redirect=%2Fmap");
      return;
    }
    setMyRole(me.role);
    if (!("geolocation" in navigator)) {
      setLoading(false);
      return;
    }
    let bestAcc = Infinity;
    let firstFix = true;
    const watchId = navigator.geolocation.watchPosition(
      (pos) => {
        const acc = pos.coords.accuracy ?? 99999;
        if (acc < bestAcc) {
          bestAcc = acc;
          const loc = { lat: pos.coords.latitude, lng: pos.coords.longitude };
          setUserLocation(loc);
          setUserAccuracy(Math.round(acc));
          try { window.localStorage.setItem("hopetsit:lastMapCenter", JSON.stringify(loc)); } catch {/* ignore */}
          if (firstFix) {
            firstFix = false;
            let asked = false;
            try { const q = new URLSearchParams(window.location.search); asked = !!(q.get("city") || q.get("lat")); } catch { /* ignore */ }
            if (!asked) setCenter([loc.lat, loc.lng]);
          }
        }
        setLoading(false);
      },
      () => { setLoading(false); },
      { timeout: 10000, enableHighAccuracy: true, maximumAge: 0 },
    );
    const stopId = setTimeout(() => navigator.geolocation.clearWatch(watchId), 12000);
    return () => {
      clearTimeout(stopId);
      navigator.geolocation.clearWatch(watchId);
    };
  }, [router]);

  useEffect(() => {
    if (!getStoredUser()) return;
    let cancelled = false;
    (async () => {
      const b = await getMyBenefits();
      if (!cancelled) setBenefits(b);
    })();
    return () => { cancelled = true; };
  }, []);

  const fetchTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const fetchPois = useCallback(
    async (lat: number, lng: number, category: PoiCategory | "all") => {
      if (fetchTimeoutRef.current) clearTimeout(fetchTimeoutRef.current);
      fetchTimeoutRef.current = setTimeout(async () => {
        setFetching(true);
        setError(null);
        try {
          const list = await getNearbyPois({ lat, lng, maxDistance: 10000, category: category === "all" ? undefined : category });
          setPois(list);
        } catch (e) {
          if (e instanceof ApiError && e.status === 401) { router.replace("/login"); return; }
          setError(e instanceof Error ? e.message : "Failed to load POI");
        } finally {
          setFetching(false);
        }
      }, 400);
    },
    [router],
  );
  useEffect(() => {
    if (loading) return;
    fetchPois(center[0], center[1], "all");
  }, [loading, fetchPois, center, reloadTick]);

  useEffect(() => {
    if (loading || !showSpots) return;
    const tid = setTimeout(async () => {
      try {
        setSpots(await getNearbyPawSpots({ lat: center[0], lng: center[1], radius: 25000 }));
      } catch (e) {
        if (e instanceof ApiError && e.status === 401) router.replace("/login");
      }
    }, 400);
    return () => clearTimeout(tid);
  }, [loading, showSpots, center, router, reloadTick]);

  useEffect(() => {
    if (loading || !showReports) return;
    const tid = setTimeout(async () => {
      try {
        const r = await getNearbyReports({ lat: center[0], lng: center[1], maxDistance: 25000 });
        setReports(r.reports);
      } catch (e) {
        if (e instanceof ApiError && e.status === 401) router.replace("/login");
      }
    }, 400);
    return () => clearTimeout(tid);
  }, [loading, showReports, center, router, reloadTick]);

  const membersSubscribed = !!(benefits?.pawspotActive || benefits?.premiumActive || benefits?.isPremium);
  useEffect(() => {
    // 25/09 — la couche « proches » pour tous (le serveur décide ce qu'il
    // renvoie), comme l'app : sinon un ami ou un gardien proche pouvait manquer.
    if (loading) { setMembers([]); return; }
    const tid = setTimeout(async () => {
      try {
        setMembers(await getNearbyMembers({ lat: center[0], lng: center[1], radiusInMeters: 25000 }));
      } catch (e) {
        if (e instanceof ApiError && e.status === 401) router.replace("/login");
      }
    }, 400);
    return () => clearTimeout(tid);
  }, [loading, center, router, reloadTick]);

  useEffect(() => {
    if (loading) return;
    let cancelled = false;
    getWorldMembers().then((list) => { if (!cancelled) setWorldMembers(list); }).catch(() => {});
    return () => { cancelled = true; };
  }, [loading, reloadTick]);

  // 24/09 — demandes des propriétaires (bulle orange) : le prestataire voit
  // celles autour de lui (feed /posts/requests), le propriétaire les siennes
  // (« Ma demande »). Position FLOUTÉE ~1 km avant tout affichage.
  const isProviderRole = myRole === "sitter" || myRole === "walker";
  useEffect(() => {
    if (loading || !showRequests) { setRequests([]); return; }
    let cancelled = false;
    (async () => {
      try {
        const posts = isProviderRole ? await getRequestPosts() : await getMyPosts();
        if (cancelled) return;
        const out: MapRequest[] = [];
        for (const p of posts) {
          const id = String(p.id || p._id || "");
          const lat = Number(p.location?.lat);
          const lng = Number(p.location?.lng);
          if (!id || !Number.isFinite(lat) || !Number.isFinite(lng) || (lat === 0 && lng === 0)) continue;
          if (p.status && !["open", "active", "published", "pending"].includes(String(p.status).toLowerCase())) continue;
          const [blat, blng] = blurLatLng(lat, lng, id);
          const types = (p.serviceTypes || []).map((s) => String(s).toLowerCase());
          out.push({
            id,
            lat: blat,
            lng: blng,
            service: types.some((s) => s.includes("walk")) ? "walk" : "sitting",
            // v587 — budget saisi par le propriétaire (« 35 € »), sinon l'icône.
            priceLabel: formatPrice(p.budget ?? null, p.budgetCurrency || p.currency),
            mine: !isProviderRole,
            boosted: p.isOwnerBoosted === true,
            body: p.body || p.notes || "",
            city: p.location?.city || p.location?.label || "",
            // v587 (point 8) — où se passe le service, lu par le prestataire.
            locationLabel: locationDisplay(lang, p),
          });
        }
        setRequests(out);
      } catch { /* couche vide, la carte reste utilisable */ }
    })();
    return () => { cancelled = true; };
  }, [loading, showRequests, isProviderRole, lang, reloadTick]);

  // 25/09 (PawMap 585) — UNE personne = UN point, même quand « proches » et
  // « monde » ont retenu deux profils différents (lib/memberPersons.ts). Une
  // personne reste visible si L'UN de ses rôles est coché dans « Je cherche ».
  const [showMembers, setShowMembers] = useState(true);
  // 587 (point 11) — puis la position de profil floutée renvoyée par /friends
  // prime pour chaque ami (et ajoute ceux que les couches n'ont pas).
  const mergedMembers = useMemo(() => placeFriendsFromList(placeFriendsAtProfile(mergePersons(members, worldMembers), worldMembers, friendIdSetFrom(friendsForMap)), friendsForMap), [members, worldMembers, friendsForMap]);
  // 25/09 (586, point 7) — familles INDÉPENDANTES : un ami ne dépend que de
  // la pastille « Amis », un autre membre que des pastilles de rôle.
  const allMembers = useMemo(() => {
    if (!showMembers) return [];
    const fset = friendIdSetFrom(friendsForMap);
    return mergedMembers.filter((m) => (isFriendMember(m, fset) ? showFriends : rolesMatching(m, memberRoles).length > 0));
  }, [mergedMembers, memberRoles, showMembers, friendsForMap, showFriends]);

  // Membres à moins de 50 km (même règle que l'app) — liste + compteur.
  // 25/09 (point 5) — la référence est ce qu'on REGARDE (centre de la
  // carte), plus ma position GPS : après « paris », la liste parle de Paris.
  // 25/09 (585, point 3) — la distance AFFICHÉE part de ma position (sinon du
  // centre regardé) jusqu'au point AFFICHÉ de la personne, jamais d'une autre
  // position de profil.
  const distanceFrom = useMemo(() => userLocation ?? { lat: center[0], lng: center[1] }, [userLocation, center]);
  const membersNear = useMemo(() => {
    const ref = { lat: center[0], lng: center[1] };
    return allMembers
      .map((m) => {
        const lat = m.location?.coordinates?.[1];
        const lng = m.location?.coordinates?.[0];
        if (typeof lat !== "number" || typeof lng !== "number") return null;
        return { m, km: haversineKm(ref.lat, ref.lng, lat, lng), shownKm: haversineKm(distanceFrom.lat, distanceFrom.lng, lat, lng), lat, lng };
      })
      .filter((x): x is { m: NearbyMember; km: number; shownKm: number; lat: number; lng: number } => !!x && x.km <= 50)
      .sort((a, b) => a.shownKm - b.shownKm);
  }, [allMembers, center, distanceFrom]);
  const membersAround = membersNear.length;
  // Personne DANS la zone visible (les 3 rôles, sans filtre) = état vide.
  const membersInView = useMemo(() => {
    if (!viewBounds) return membersAround;
    return mergedMembers.filter((m) => {
      const lat = m.location?.coordinates?.[1];
      const lng = m.location?.coordinates?.[0];
      return typeof lat === "number" && typeof lng === "number" && lat >= viewBounds.s && lat <= viewBounds.n && lng >= viewBounds.w && lng <= viewBounds.e;
    }).length;
  }, [mergedMembers, viewBounds, membersAround]);

  const handleAddFriend = useCallback(
    async (m: NearbyMember): Promise<"sent" | "already" | "error"> => {
      try {
        const r = (await sendFriendRequest(m.id, m.role)) as { alreadyPending?: boolean } | null;
        return r && r.alreadyPending ? "already" : "sent";
      } catch (e) {
        if (e instanceof ApiError && e.status === 409) return "already";
        if (e instanceof ApiError && e.status === 401) router.replace("/login");
        return "error";
      }
    },
    [router],
  );

  // 25/09 (PawMap 584, points 4 + 9) — SUIVI EN DIRECT VRAI. On ne garde
  // que les partages actifs et récents renvoyés par le serveur (drapeaux
  // `sharing` / `state`, règle backend/src/utils/liveState.js) : `live` < 2
  // min, `lost` 2-10 min. Plus AUCUNE « dernière position » de profil
  // traitée comme un direct (avant : /friends/:id/last-position pour chaque
  // ami → « Suivi en direct de Jose » sur une position de la veille). Un ami
  // sans partage reste visible à sa position de PROFIL floutée (couche monde).
  const infoRef = useRef<Map<string, { role: "walker" | "sitter" | "owner"; name: string; avatar: string }>>(new Map());
  const refreshLive = useCallback(async (infoById?: Map<string, { role: "walker" | "sitter" | "owner"; name: string; avatar: string }>) => {
    const info = infoById ?? infoRef.current;
    const bulk = await getFriendsLivePositions();
    const fresh = new Map<string, FriendLivePosition>();
    const nowMs = Date.now();
    for (const b0 of bulk) {
      if (b0.lat == null || b0.lng == null) continue;
      // 587 — âge mesuré par le serveur : dernier signe de vie ramené sur
      // l'horloge de CE navigateur (une horloge décalée ne change plus l'état).
      // Repli (serveur de production sans ageMs) : lastSeenAt tel quel.
      const ageOk = typeof b0.ageMs === "number" && Number.isFinite(b0.ageMs) && b0.ageMs >= 0;
      const b = { ...b0, userId: canonId(b0.userId, (b0 as { personIds?: string[] }).personIds), lastSeenAt: ageOk ? new Date(nowMs - (b0.ageMs as number)).toISOString() : b0.lastSeenAt };
      const st = liveStateOf(b, nowMs);
      if (st === "seen") continue;
      const i = info.get(b.userId);
      const prevFresh = fresh.get(b.userId);
      // Deux rôles de la même personne : on garde le signe de vie le plus récent.
      if (prevFresh && prevFresh.lastSeenAt && b.lastSeenAt && new Date(prevFresh.lastSeenAt).getTime() >= new Date(b.lastSeenAt).getTime()) continue;
      fresh.set(b.userId, {
        userId: b.userId,
        role: roleFromModel(i ? i.role : b.role),
        name: i?.name || t("common_friend"),
        avatar: i?.avatar,
        lat: b.lat,
        lng: b.lng,
        at: b.at || new Date().toISOString(),
        lastSeenAt: b.lastSeenAt || (ageOk ? null : b.at) || null,
        state: st,
      });
    }
    setLivePositions((prev) => {
      const next = new Map<string, FriendLivePosition>();
      for (const [id, p] of fresh) {
        const old = prev.get(id);
        // Une position socket plus fraîche que la réponse HTTP est gardée.
        const oldT = old?.lastSeenAt ? new Date(old.lastSeenAt).getTime() : 0;
        const newT = p.lastSeenAt ? new Date(p.lastSeenAt).getTime() : 0;
        next.set(id, old && oldT > newT ? { ...old, state: p.state } : { ...p, isOnline: old?.isOnline });
      }
      // Ceux qui viennent d'arriver par la socket (< 2 min) restent.
      for (const [id, p] of prev) {
        if (next.has(id)) continue;
        const tt = p.lastSeenAt ? new Date(p.lastSeenAt).getTime() : 0;
        if (nowMs - tt < 2 * 60 * 1000) next.set(id, p);
      }
      return next;
    });
  }, [t, canonId]);

  // Horloge de la carte : âge « en direct · 12 s », passage live → signal
  // perdu → disparition (10 min), sans attendre le serveur.
  const [nowTs, setNowTs] = useState(() => Date.now());
  useEffect(() => {
    const id = setInterval(() => setNowTs(Date.now()), 5000);
    return () => clearInterval(id);
  }, []);
  // Relecture de l'état vrai toutes les 30 s tant que la couche amis est là.
  useEffect(() => {
    if (!showFriends) return;
    const id = setInterval(() => { void refreshLive().catch(() => {}); }, 30000);
    return () => clearInterval(id);
  }, [showFriends, refreshLive]);

  const loadFriends = useCallback(async () => {
    setFriendsLoading(true);
    try {
      const [friendList, familyResp] = await Promise.all([getMyFriends(), getMyFamily()]);
      const accepted = friendList.filter((f) => f.status === "accepted" && !f.other?.deleted);
      const allFamily = (familyResp.members || []).filter((m) => !!m.id);
      setFamilyIds(allFamily.map((m) => m.id));
      const _premIds = [...accepted.filter((f) => f.other?.isPremium).map((f) => f.other.id), ...allFamily.filter((m) => m.isPremium).map((m) => m.id)].filter(Boolean);
      setPremiumIds([...new Set(_premIds)]);

      const out = [...accepted];
      const inFriendIds = new Set(accepted.map((f) => f.other?.id).filter(Boolean) as string[]);
      const ModelMap: Record<string, "Owner" | "Sitter" | "Walker"> = { owner: "Owner", sitter: "Sitter", walker: "Walker" };
      for (const m of allFamily) {
        if (!m.id || inFriendIds.has(m.id)) continue;
        out.push({
          id: `family-${m.id}`,
          status: "accepted",
          initiatedByMe: false,
          other: { id: m.id, model: ModelMap[(m.role || "").toLowerCase()] || "Owner", name: m.name || t("common_family"), email: m.email || "", avatar: m.avatar || "" },
          mySharePosition: true,
          theirSharePosition: true,
        });
      }
      setFriendsForMap(out);
      const seenMap: Record<string, string | null> = {};
      for (const f of accepted) {
        if (!f.other?.id) continue;
        const seen = f.other.lastSeenAt ?? f.lastSeenAt ?? null;
        // 587 — « vu il y a X » retrouvé quel que soit le rôle affiché de l'ami.
        for (const x of [f.other.id, ...((f.other as { personIds?: string[] }).personIds || [])]) if (x) seenMap[x] = seen;
      }
      setFriendSeen(seenMap);

      const infoById = new Map<string, { role: "walker" | "sitter" | "owner"; name: string; avatar: string }>();
      for (const f of accepted) {
        if (!f.other?.id) continue;
        infoById.set(f.other.id, { role: roleFromModel(f.other.model), name: f.other.name || t("common_friend"), avatar: f.other.avatar || "" });
      }
      for (const m of allFamily) {
        if (!m.id || infoById.has(m.id)) continue;
        infoById.set(m.id, { role: roleFromModel(m.role), name: m.name || t("common_family"), avatar: m.avatar || "" });
      }
      infoRef.current = infoById;
      await refreshLive(infoById);
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) { router.replace("/login"); return; }
    } finally {
      setFriendsLoading(false);
    }
  }, [router, t, refreshLive]);

  // Amis chargés dès l'ouverture (anneau rose sur leur point, direct vrai).
  useEffect(() => {
    if (loading || friendsLoadedRef.current) return;
    friendsLoadedRef.current = true;
    void loadFriends();
  }, [loading, loadFriends]);

  const autoLayersRef = useRef(false);
  useEffect(() => {
    if (!benefits || autoLayersRef.current) return;
    autoLayersRef.current = true;
    const premium = benefits.premiumActive === true;
    const staff = benefits.isPremium === true;
    if (premium || benefits.pawFollowActive || benefits.familyActive || staff) {
      setShowFriends(true);
      if (!friendsLoadedRef.current) { friendsLoadedRef.current = true; void loadFriends(); }
    }
    if (premium || benefits.pawspotActive || staff) setShowSpots(true);
  }, [benefits, loadFriends]);

  // 25/09 (585, lot 2 — bug 15) — « Mes abonnements sur la carte » : l'état
  // des interrupteurs est enregistré sur le COMPTE (/users/me/map-prefs,
  // calques friends / pawspots / premium, suivis par l'app) ; si le serveur
  // ne répond pas, repli sur cet appareil (et on le dit).
  const [layersLocalOnly, setLayersLocalOnly] = useState(false);
  const layerPrefsRef = useRef(false);
  useEffect(() => {
    if (!benefits || layerPrefsRef.current) return;
    layerPrefsRef.current = true;
    (async () => {
      const acc = await getMapSeekPrefs();
      let layers: MapLayerPrefs;
      let roles: string[] | null = acc ? acc.memberRoles : null;
      if (acc) layers = acc.layers;
      else {
        try { layers = JSON.parse(localStorage.getItem("hopetsit:mapLayers") || "{}") as MapLayerPrefs; } catch { layers = {}; }
        try { const r = JSON.parse(localStorage.getItem("hopetsit:mapRoles") || "null"); roles = Array.isArray(r) ? r : null; } catch { roles = null; }
      }
      // 25/09 (586, point 7) — « Ce que je veux voir » retrouvé à l'identique.
      if (typeof layers.places === "boolean") { setNoneSelected(!layers.places); setSelectedCats([]); }
      if (typeof layers.reports === "boolean") setShowReports(layers.reports);
      if (typeof layers.requests === "boolean") setShowRequests(layers.requests);
      if (roles) setMemberRoles(roles.filter((r) => ["owner", "sitter", "walker"].includes(r)));
      if (typeof layers.friends === "boolean") {
        setShowFriends(layers.friends);
        if (layers.friends && !friendsLoadedRef.current) { friendsLoadedRef.current = true; void loadFriends(); }
      }
      if (typeof layers.pawspots === "boolean") setShowSpots(layers.pawspots);
    })();
  }, [benefits, loadFriends]);

  async function handleSpotVisit(id: string) {
    try {
      const vc = await visitSpot(id);
      setSpots((prev) => prev.map((s) => (s.id === id ? { ...s, visitsCount: vc } : s)));
    } catch { /* best-effort */ }
  }
  function saveLayers(patch: MapLayerPrefs, roles?: string[]) {
    try {
      const cur = JSON.parse(localStorage.getItem("hopetsit:mapLayers") || "{}");
      localStorage.setItem("hopetsit:mapLayers", JSON.stringify({ ...cur, ...patch }));
      if (roles) localStorage.setItem("hopetsit:mapRoles", JSON.stringify(roles));
    } catch { /* stockage indisponible */ }
    void (roles ? saveMapSeekPrefs(patch, roles) : saveMapLayerPrefs(patch)).then((ok) => setLayersLocalOnly(!ok));
  }
  function setFriendsLayer(on: boolean) {
    setShowFriends(on);
    if (on && !friendsLoadedRef.current) { friendsLoadedRef.current = true; void loadFriends(); }
  }
  function toggleFriendsLayer() {
    const next = !showFriends;
    setShowFriends(next);
    if (next && !friendsLoadedRef.current) { friendsLoadedRef.current = true; void loadFriends(); }
  }
  function openCreate(kind: "spot" | "report", wantPhoto = false) {
    const subbed = !!(benefits?.pawspotActive || benefits?.premiumActive || benefits?.isPremium);
    if (!subbed) { router.push("/boutique"); return; }
    setCreateKind(kind);
    setCreateType(kind === "spot" ? "path_walk" : "lost_pet");
    setCreateName("");
    setCreateNote("");
    setCreateErr(null);
    setCreatePhoto(null);
    setCreatePhotoPreview(null);
    if (wantPhoto) setTimeout(() => photoInputRef.current?.click(), 50);
  }
  async function submitCreate() {
    if (creating || !createKind) return;
    const lat = center[0];
    const lng = center[1];
    setCreating(true);
    setCreateErr(null);
    try {
      if (createKind === "spot") {
        if (!createName.trim()) { setCreateErr(t("map_spot_name_ph")); setCreating(false); return; }
        let photoUrl = "";
        if (createPhoto) {
          setUploadingPhoto(true);
          try { photoUrl = await uploadImage(createPhoto); } finally { setUploadingPhoto(false); }
        }
        await createPawSpot({ type: createType as PawSpotType, name: createName.trim(), description: createNote.trim(), lat, lng, photoUrl });
        if (!showSpots) setShowSpots(true);
        setSpots(await getNearbyPawSpots({ lat, lng, radius: 25000 }));
      } else {
        await createMapReport({ type: createType as MapReportType, lat, lng, note: createNote.trim() });
        if (!showReports) setShowReports(true);
        const r = await getNearbyReports({ lat, lng, maxDistance: 25000 });
        setReports(r.reports);
      }
      setCreateKind(null);
    } catch (e) {
      if (e instanceof ApiError && e.status === 402) setCreateErr(t("map_create_locked"));
      else if (e instanceof ApiError && e.status === 401) router.replace("/login");
      else setCreateErr(t("map_create_error"));
    } finally {
      setCreating(false);
    }
  }

  const handleDirections = useCallback(
    (target: { lat: number; lng: number }, modeOverride?: RouteMode) => {
      const mode = modeOverride ?? routeMode;
      setDirectionsLocked(false);
      setDirectionsError(false);
      setRouteLoading(true);
      setRouteTarget(target);
      setShowSteps(false);
      setRoute(null);
      setRouteFrom(null);
      const go = async (from: { lat: number; lng: number }, origin: "gps" | "center") => {
        setRouteFrom(origin);
        try {
          setRoute(await getPawSpotDirections({ fromLat: from.lat, fromLng: from.lng, toLat: target.lat, toLng: target.lng, mode, lang }));
        } catch (e) {
          if (e instanceof ApiError && e.status === 402) setDirectionsLocked(true);
          else if (e instanceof ApiError && e.status === 401) { router.replace("/login"); return; }
          else setDirectionsError(true);
        } finally {
          setRouteLoading(false);
        }
      };
      // Avant : sans position, départ silencieux du centre de la carte, et le
      // résultat (ou le refus « abonnement requis ») n'apparaissait que dans
      // le panneau — replié sur téléphone : « Itinéraire ne fait rien ».
      const fallback = () => (userLocation ? go(userLocation, "gps") : go({ lat: center[0], lng: center[1] }, "center"));
      if (typeof navigator !== "undefined" && "geolocation" in navigator) {
        navigator.geolocation.getCurrentPosition((pos) => void go({ lat: pos.coords.latitude, lng: pos.coords.longitude }, "gps"), () => void fallback(), { timeout: 6000, maximumAge: 60000 });
      } else {
        void fallback();
      }
    },
    [userLocation, center, router, routeMode, lang],
  );
  function setRouteMode(mode: RouteMode) {
    if (mode === routeMode) return;
    setRouteModeState(mode);
    try { localStorage.setItem("pawmap_route_mode", mode); } catch { /* ignore */ }
    if (routeTarget) handleDirections(routeTarget, mode);
  }
  function formatRouteDuration(seconds: number): string {
    const min = Math.max(1, Math.round(seconds / 60));
    if (min < 60) return String(min);
    return `${Math.floor(min / 60)} h ${String(min % 60).padStart(2, "0")}`;
  }
  function clearRoute() {
    setRoute(null);
    setRouteFrom(null);
    setRouteLoading(false);
    setRouteTarget(null);
    setShowSteps(false);
    setDirectionsLocked(false);
    setDirectionsError(false);
  }
  function handleMapMove(c: { lat: number; lng: number }) {
    const distance = Math.sqrt(Math.pow(c.lat - center[0], 2) + Math.pow(c.lng - center[1], 2));
    if (distance > 0.005) setCenter([c.lat, c.lng]);
  }
  function handleZoomChange(z: number) {
    try { localStorage.setItem("hopetsit:lastMapZoom", String(z)); } catch { /* ignore */ }
  }
  // 26/09 (589) — Actualiser : toutes les couches repartent du serveur.
  function manualRefresh() {
    if (refreshing) return;
    setRefreshing(true);
    setReloadTick((n) => n + 1);
    void loadFriends().catch(() => {});
    setTimeout(() => setRefreshing(false), 1400);
  }
  // 26/09 (589) — roue « Options de la carte ».
  function openOptions() {
    revealControls();
    const desktop = typeof window !== "undefined" && window.innerWidth >= 1024;
    if (!desktop) { setSheet("full"); return; }
    try { panelScrollRef.current?.scrollTo({ top: 0, behavior: "smooth" }); } catch { /* */ }
    setOptionsFlash(true);
    setTimeout(() => setOptionsFlash(false), 1300);
  }
  // 26/09 (589) — « Partager la carte » : lien /map?lat&lng&z (déjà lu à
  // l'ouverture), feuille de partage du système sinon copie + pastille.
  async function shareMap() {
    let lat = center[0], lng = center[1], z = 13;
    try {
      const m = mapRef.current;
      if (m) { const c = m.getCenter(); lat = c.lat; lng = c.lng; z = m.getZoom(); }
    } catch { /* */ }
    const url = `https://www.hopetsit.com/map?lat=${lat.toFixed(5)}&lng=${lng.toFixed(5)}&z=${Math.round(z)}`;
    try {
      if (typeof navigator !== "undefined" && typeof navigator.share === "function") {
        await navigator.share({ title: "PawMap · HoPetSit", url });
        return;
      }
    } catch (e) {
      if (e instanceof Error && e.name === "AbortError") return;
    }
    try { await navigator.clipboard.writeText(url); } catch { /* */ }
    setShareToast(true);
    setTimeout(() => setShareToast(false), 2600);
  }
  function toggleDark() {
    setDark((d) => {
      try { localStorage.setItem("hopetsit:mapDark", d ? "0" : "1"); } catch { /* ignore */ }
      return !d;
    });
  }
  function locateMe() {
    if (locating) return;
    if (typeof navigator === "undefined" || !("geolocation" in navigator)) { setLocateMsg(t("map_locate_unsupported")); return; }
    setLocateMsg(null);
    setLocating(true);
    const onFound = (pos: GeolocationPosition) => {
      const loc = { lat: pos.coords.latitude, lng: pos.coords.longitude };
      setUserLocation(loc);
      setCenter([loc.lat, loc.lng]);
      setFocusTarget({ ...loc, ts: Date.now(), zoom: 14 });
      setLocating(false);
    };
    const onFail = (err: GeolocationPositionError) => {
      setLocating(false);
      setLocateMsg(err && err.code === 1 ? t("map_locate_denied") : t("map_locate_failed"));
    };
    navigator.geolocation.getCurrentPosition(onFound, () => navigator.geolocation.getCurrentPosition(onFound, onFail, { enableHighAccuracy: false, timeout: 8000, maximumAge: 30000 }), { enableHighAccuracy: true, timeout: 12000, maximumAge: 0 });
  }
  const visToastRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  // 587 (point 9) — pastille signature (même dessin que l'app), 2 s.
  function flashVisibility(msg: string, kind: StatusToastKind) {
    setFriendsOnlyMsg({ kind, text: msg });
    if (visToastRef.current) clearTimeout(visToastRef.current);
    visToastRef.current = setTimeout(() => setFriendsOnlyMsg(null), 2000);
  }
  async function changeVisibility(next: MapVisibility) {
    if (friendsOnlyBusy) return;
    setFriendsOnlyBusy(true);
    try {
      const v = await setMapVisibility(next);
      setVisibility(v);
      flashVisibility(t(v === "all" ? "v587_all_d" : v === "friends" ? "v587_friends_d" : "v587_hidden_d"), v === "all" ? "all" : v === "friends" ? "friends" : "hidden");
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) { router.replace("/login"); return; }
      flashVisibility(t("m586_vis_error"), "error");
    } finally {
      setFriendsOnlyBusy(false);
    }
  }
  // 588 — « quand je clic sur mon ami, ça ne zoome pas sur lui ». Un ami en
  // DIRECT cliqué (liste, pilule, rond, fiche) : suivi lancé, vol doux
  // (zoom 16, 0,8 s, via FollowController) et sa petite fiche ouverte.
  // Déjà suivi : on recentre quand même (avant, rien ne bougeait).
  function startFollow(p: FriendLivePosition) {
    if (!showFriends) setFriendsLayer(true);
    if (followUserId === p.userId) setFocusTarget({ lat: p.lat, lng: p.lng, ts: Date.now(), zoom: 16, duration: 0.8 });
    setFollowUserId(p.userId);
    setFollowPaused(false);
    setFollowSheet(true);
  }
  function stopFollow() {
    setFollowUserId(null);
    setFollowPaused(false);
    setFollowSheet(false);
  }

  const livePositionsList = useMemo(
    () =>
      Array.from(livePositions.values())
        .map((p) => ({ ...p, state: liveStateOf({ lastSeenAt: p.lastSeenAt, at: p.at, sharing: true, state: p.state }, nowTs) }))
        .filter((p): p is FriendLivePosition & { state: "live" | "lost" } => p.state !== "seen")
        .map((p) => (presence.has(p.userId) ? { ...p, isOnline: !!presence.get(p.userId) } : p)),
    [livePositions, presence, nowTs],
  );
  // 587 — tous les ids (3 rôles) des amis qui partagent : leur point de profil disparaît.
  const liveIdsAll = useMemo(() => {
    const set = new Set(livePositionsList.map((p) => p.userId));
    for (const [id, c] of friendCanon) if (set.has(c)) set.add(id);
    return [...set];
  }, [livePositionsList, friendCanon]);
  const membersWithPresence = useMemo(
    () => allMembers.map((m) => (m.approx ? m : { ...m, isOnline: resolveOnline(m.id, m.isOnline) })),
    [allMembers, resolveOnline],
  );
  const followed = followUserId ? livePositionsList.find((p) => p.userId === followUserId) : undefined;
  // 588 — clic sur un ami du panneau : son direct s'il partage, sinon sa
  // position de profil floutée (couche amis 587, fusionnée dans les membres),
  // sinon (Masqué) la pastille « Cet ami n'est pas visible sur la carte ».
  function focusOnFriend(f: FriendItem) {
    const o = f.other;
    if (!o?.id) return;
    const ids = [String(o.id), ...(o.personIds || []).map(String)];
    const spot = locateFriend(ids, livePositionsList, mergedMembers, { hidden: o.mapVisibility === "hidden" });
    if (!spot) { flashVisibility(t("map_friend_not_visible"), "hidden"); return; }
    // Téléphone / tablette : la feuille du panneau se referme, on VOIT la carte.
    if (typeof window !== "undefined" && window.innerWidth < 1024) setSheet("closed");
    if (spot.kind === "live") { startFollow(spot.p); return; }
    if (!showFriends) setFriendsLayer(true);
    if (followUserId) stopFollow();
    setFocusFriend({ m: spot.m, ts: Date.now() });
  }
  // Mes amis hors direct (liste « Amis » du panneau), ceux qui ont une position d'abord.
  const friendsNotLive = useMemo(() => {
    const live = new Set(livePositionsList.map((p) => p.userId));
    return friendsForMap
      .filter((f) => f.other?.id && !live.has(f.other.id))
      .map((f) => ({ f, spot: locateFriend([String(f.other.id), ...(f.other.personIds || []).map(String)], [], mergedMembers, { hidden: f.other.mapVisibility === "hidden" }) }))
      .sort((a, b) => Number(!a.spot) - Number(!b.spot) || (a.f.other.name || "").localeCompare(b.f.other.name || ""));
  }, [friendsForMap, livePositionsList, mergedMembers]);
  // Le suivi se termine tout seul quand le partage cesse (plus de vieille
  // position gardée à l'écran) : petit message « X a arrêté de partager ».
  const followedNameRef = useRef("");
  if (followed) followedNameRef.current = followed.name;
  useEffect(() => {
    if (followUserId && !followed) {
      setFollowUserId(null);
      setFollowPaused(false);
      setFollowSheet(false);
      setLiveToast(t("live_stopped_sharing").replace("{name}", followedNameRef.current || t("common_friend")));
      const id = setTimeout(() => setLiveToast(null), 5000);
      return () => clearTimeout(id);
    }
  }, [followUserId, followed, t]);
  const liveLabels: LiveLabels = useMemo(
    () => ({
      live: t("live_state_live"),
      lost: t("live_state_lost"),
      follow: t("live_follow_cta"),
      message: t("live_message"),
      seenAgo: t("friend_seen_ago"),
      seenNow: t("friend_seen_now"),
      notSharing: t("friend_not_sharing"),
      profileApprox: t("friend_profile_approx"),
      viewProfile: t("friend_view_profile"),
      ago: (ms: number) => formatAgo(ms, t),
    }),
    [t],
  );
  // 25/09 (585) — l'amitié a pu être nouée sous un AUTRE profil de la
  // personne : on écrit au profil qui porte l'amitié (other.id de /friends).
  const friendIdSet = useMemo(() => friendIdSetFrom(friendsForMap), [friendsForMap]);
  const cardLabels: CardLabels = useMemo(
    () => ({
      book: t("map_member_book"), priceFrom: t("map_member_price_from"), addFriend: t("map_member_add_friend"),
      sent: t("map_member_request_sent"), already: t("map_member_already"), failed: t("map_member_request_failed"),
      approx: t("map_member_approx"), verified: t("trust_id_title"), viewProfile: t("friend_view_profile"),
      directions: t("map_directions_btn"), message: t("live_message"), friend: t("map_friend_badge"),
      bookAsOwner: t("m586_book_as_owner"), switchingOwner: t("m586_switching_owner"), switchOwnerError: t("m586_switch_owner_error"),
      chooseProfile: t("map_choose_profile"), profilesHere: t("map_profiles_here"), see: t("map_see"),
      // Sans ma position, la distance part du centre de la carte : on le dit.
      distance: userLocation ? t("map_distance_from_you") : t("map_distance_from_center"), back: t("map_back"), close: t("common_close"), lang,
    }),
    [t, lang, userLocation],
  );
  async function openMessage(who: { id: string; role: string; name: string }) {
    const f = friendsForMap.find((x) => x.other && (x.other.id === who.id || (x.other.personIds || []).includes(who.id)));
    const target = f?.other?.id && !f.id.startsWith("family-") ? { id: f.other.id, role: roleFromModel(f.other.model) } : { id: who.id, role: roleKey(who.role) };
    try {
      const r = await startFriendConversation({ targetUserId: target.id, targetUserRole: target.role });
      router.push(r.conversationId ? `/chat?c=${r.conversationId}` : "/chat");
    } catch {
      router.push("/chat");
    }
  }

  if (loading) {
    return (
      <div className="mx-auto max-w-5xl px-4 py-24 text-center text-[#6E4F48]">
        <PageTitle titleKey="page_title_map" />
        {t("map_loading_locating")}
      </div>
    );
  }

  const CAT_KEY_FOR_LANG: Record<PoiCategory, string> = {
    vet: "map_cat_vet", shop: "map_cat_shop", groomer: "map_cat_groomer", park: "map_cat_park", beach: "map_cat_beach",
    water: "map_cat_water", trainer: "map_cat_trainer", hotel: "map_cat_hotel", restaurant: "map_cat_restaurant", other: "map_cat_other",
  };
  const spotTypeLabels: Record<PawSpotType, string> = {
    path_walk: t("map_spot_type_path_walk"), chill: t("map_spot_type_chill"), playground: t("map_spot_type_playground"),
    swimming: t("map_spot_type_swimming"), food_cafe: t("map_spot_type_food_cafe"), other: t("map_spot_type_other"),
  };
  const reportTypeLabels: Partial<Record<MapReportType, string>> = {
    lost_pet: t("map_rtype_lost_pet"), found_pet: t("map_rtype_found_pet"), aggressive_dog: t("map_rtype_aggressive_dog"),
    dead_animal: t("map_rtype_dead_animal"), stray_pet: t("map_rtype_stray_pet"), water_active: t("map_rtype_water_active"),
    trap: t("map_rtype_trap"), poison: t("map_rtype_poison"), construction: t("map_rtype_construction"), food: t("map_rtype_food"),
    trash: t("map_rtype_trash"), vet_open: t("map_rtype_vet_open"), leash_required: t("map_rtype_leash_required"),
    heat_hot_ground: t("map_rtype_heat_hot_ground"), tick_zone: t("map_rtype_tick_zone"),
  };
  const reportOptions: MapReportType[] = ["lost_pet", "found_pet", "aggressive_dog", "dead_animal", "stray_pet", "water_active"];
  const spotOptions: PawSpotType[] = ["path_walk", "chill", "playground", "swimming", "food_cafe", "other"];
  const visiblePois = noneSelected ? [] : selectedCats.length === 0 ? pois : pois.filter((p) => selectedCats.includes(p.category));
  const roleColor = ROLE_COLOR[roleKey(myRole)];
  const roleLight = myRole === "owner" ? "bg-owner-light" : myRole === "walker" ? "bg-walker-light" : "bg-sitter-light";
  const roleTextDark = myRole === "owner" ? "text-owner-dark" : myRole === "walker" ? "text-walker-dark" : "text-sitter-dark";

  // 25/09 (586, point 7) — « CE QUE JE VEUX VOIR » : une pastille
  // INDÉPENDANTE par famille, à sa couleur de légende. « Tout » / « Rien »
  // n'agissent que sur cette liste ; « Moi » reste toujours visible ; choix
  // retenus sur le compte (pawMap.layers + pawMap.memberRoles).
  function toggleRole(role: string) {
    const next = memberRoles.includes(role) ? memberRoles.filter((r) => r !== role) : [...memberRoles, role];
    setMemberRoles(next);
    saveLayers({ members: next.length > 0 }, next);
  }
  const seeChips: { k: string; label: string; on: boolean; fg: string; bg: string; icon: React.ReactNode; toggle: () => void }[] = [
    { k: "friends", label: t("m586_see_friends"), on: showFriends, fg: "#FFFFFF", bg: "#F06AA0", icon: <AppIcon name="friends" size={15} color="currentColor" />, toggle: () => { const v = !showFriends; setFriendsLayer(v); saveLayers({ friends: v }); } },
    { k: "owner", label: t("m586_see_owners"), on: memberRoles.includes("owner"), fg: "#FFFFFF", bg: ROLE_COLOR.owner, icon: <AppIcon name="paw" size={15} color="currentColor" />, toggle: () => toggleRole("owner") },
    { k: "sitter", label: t("m586_see_sitters"), on: memberRoles.includes("sitter"), fg: "#FFFFFF", bg: ROLE_COLOR.sitter, icon: <AppIcon name="home" size={15} color="currentColor" />, toggle: () => toggleRole("sitter") },
    { k: "walker", label: t("m586_see_walkers"), on: memberRoles.includes("walker"), fg: "#FFFFFF", bg: ROLE_COLOR.walker, icon: <AppIcon name="walker" size={15} color="currentColor" />, toggle: () => toggleRole("walker") },
    { k: "places", label: t("m586_see_places"), on: !noneSelected, fg: "#FFFFFF", bg: "#0E7490", icon: <AppIcon name="pin" size={15} color="currentColor" />, toggle: () => { const v = noneSelected; setNoneSelected(!v); setSelectedCats([]); saveLayers({ places: v }); } },
    { k: "spots", label: t("m586_see_spots"), on: showSpots, fg: "#F4C04A", bg: "#17141F", icon: <AppIcon name="star" size={15} color="currentColor" />, toggle: () => { const v = !showSpots; setShowSpots(v); saveLayers({ pawspots: v }); } },
    { k: "reports", label: t("m586_see_reports"), on: showReports, fg: "#FFFFFF", bg: "#D32F2F", icon: <svg viewBox="0 0 24 24" width="15" height="15" fill="currentColor" aria-hidden="true"><path d="M12 2.8 22.6 21H1.4z" /><path d="M10.9 9h2.2v6h-2.2zM10.9 16.5h2.2v2.2h-2.2z" fill={showReports ? "#D32F2F" : "#FFFFFF"} /></svg>, toggle: () => { const v = !showReports; setShowReports(v); saveLayers({ reports: v }); } },
    { k: "requests", label: t("m586_see_requests"), on: showRequests, fg: "#FFFFFF", bg: ROLE_COLOR.owner, icon: <AppIcon name="megaphone" size={15} color="currentColor" />, toggle: () => { const v = !showRequests; setShowRequests(v); saveLayers({ requests: v }); } },
  ];
  function seeAll(on: boolean) {
    const roles = on ? ["owner", "sitter", "walker"] : [];
    setFriendsLayer(on); setMemberRoles(roles); setNoneSelected(!on); setSelectedCats([]);
    setShowSpots(on); setShowReports(on); setShowRequests(on);
    saveLayers({ friends: on, members: on, places: on, pawspots: on, reports: on, requests: on }, roles);
  }

  const sheetH = sheet === "closed" ? "max-lg:hidden" : sheet === "half" ? "h-[50vh]" : "h-[86vh]";
  // Glisser la poignée / l'en-tête de la feuille : vers le haut = ouvrir ou
  // agrandir, vers le bas = réduire puis fermer (seuil 24 px).
  const dragY = sheetDragRef;
  const onSheetPointerDown = (e: React.PointerEvent) => { dragY.current = e.clientY; };
  const sheetSwipe = (e: React.PointerEvent): "up" | "down" | null => {
    const y0 = dragY.current;
    dragY.current = null;
    if (y0 === null) return null;
    const dy = e.clientY - y0;
    return dy < -24 ? "up" : dy > 24 ? "down" : null;
  };
  const isOwner = roleKey(myRole) === "owner";
  // 25/09 (586, point 4) — effacement au geste : jamais pendant un placement
  // (viseur) ni un suivi en direct.
  const fadeAllowed = !createKind && !followUserId;
  const fadeCls = `transition-opacity duration-150 ${mapGesture && fadeAllowed ? "opacity-[0.35]" : "opacity-100"}`;

  return (
    <div className="mx-auto max-w-[1400px] px-4 pb-24 pt-5 md:pt-8 lg:pb-0">
      <PageTitle titleKey="page_title_map" />
      {/* ── En-tête : retour, titre, recherche de ville ── */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex min-w-0 items-center gap-3">
          <BackLink href="/dashboard" label={t("nav_dashboard")} />
          <h1 className="flex items-center gap-2.5 font-display text-2xl font-bold tracking-[-0.02em] text-[#231715] md:text-3xl">
            <span className="grid h-10 w-10 shrink-0 place-items-center rounded-2xl" style={{ background: "linear-gradient(165deg,#F26A46 0%,#DD4430 45%,#C7311F 100%)", boxShadow: "0 6px 16px rgba(221,68,48,0.32)" }}>
              <PawMapLogo size={30} title={null} />
            </span>
            <span className="truncate">PawMap</span>
          </h1>
          {fetching && <span className="text-xs text-[#6E4F48]">{t("map_searching")}</span>}
        </div>
        <form onSubmit={handleCitySearch} className="flex min-w-0 basis-full items-center gap-2 rounded-full bg-[#FAF1EC] p-1.5 pl-3 sm:max-w-sm sm:flex-1 sm:basis-auto">
          <AppIcon name="pin" size={18} color="#C92A12" className="shrink-0" />
          <input value={cityQuery} onChange={(e) => { setCityQuery(e.target.value); setCityError(false); }} placeholder={t("map_search_city_ph")} aria-label={t("map_search_city_ph")} className="min-w-0 flex-1 bg-transparent text-sm outline-none placeholder:text-ink-soft" />
          <button type="submit" disabled={citySearching || !cityQuery.trim()} className="grid h-11 w-11 shrink-0 place-items-center rounded-full text-white transition disabled:cursor-not-allowed" style={cityQuery.trim() || citySearching ? { background: ROLE_GRAD_BTN[roleKey(myRole)], boxShadow: `0 6px 14px -6px ${roleColor}` } : { background: "#FBE3DC" }} aria-label={t("map_search_city_btn")} title={t("map_search_city_btn")}>
            {/* 25/09 (585, lot 2) — plus de rond noir à 40 % (= gris) quand le champ est vide : teinte pâle PLEINE. */}
            {citySearching ? <span className="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent" /> : <AppIcon name="search" size={18} color={cityQuery.trim() ? "#fff" : "#9E1F0B"} />}
          </button>
        </form>
      </div>
      {cityError && <p className="mt-2 text-right text-xs font-semibold text-[#C92A12]">{t("map_search_city_none")}</p>}
      {error && <div className="mt-3 rounded-xl bg-[#FBE9E5] px-4 py-3 text-sm text-[#9E1F0B]">{error}</div>}

      {/* ── 2 COLONNES sur ordinateur : carte | panneau ── */}
      <div className="mt-4 lg:grid lg:grid-cols-[minmax(0,1fr)_380px] lg:gap-5">
        {/* ── COLONNE CARTE ── */}
        <div ref={mapColRef} className="relative -mx-4 overflow-x-clip h-[64vh] min-h-[420px] lg:mx-0 lg:h-[calc(100vh-230px)] lg:min-h-[560px]" style={fitH ? { height: fitH } : undefined}>
          {/* 25/09 (585, lot 2 — bug 15) — bouton « Amis » bien visible : amis,
              demandes, en direct et PawFamily (page /friends). */}
          {/* 25/09 (587, point 1a) — coin haut-gauche, juste sous le titre
              PawMap : pilule « ● Direct » (gardien / promeneur), puis « Amis ».
              Rangée qui passe à la ligne plutôt que de chevaucher « ? ». */}
          <div ref={topRowRef} className={`pointer-events-none absolute left-3 right-[168px] top-3 z-[1000] flex flex-wrap items-start gap-2 ${fadeCls}`}>
            {/* 587 — pilule « ● Direct » pour les 3 profils (propriétaire compris). */}
            {getStoredUser() && (
              <button
                type="button"
                onPointerDown={revealControls}
                onClick={() => setLiveInfoOpen(true)}
                aria-label={myLive.on ? t("m586_live_on") : t("m586_live_off")}
                title={myLive.on ? t("m586_live_on") : t("m586_live_off")}
                className={`pointer-events-auto inline-flex min-h-[44px] items-center gap-2 whitespace-nowrap rounded-full py-1 pl-3.5 pr-4 text-sm font-bold text-white transition-transform duration-200 hover:scale-[1.03] active:scale-95 ${myLive.on ? "hps-live-breathe" : ""}`}
                style={myLive.on
                  ? { background: "linear-gradient(165deg,#22C55E,#16A34A 55%,#15803D)", border: "1.5px solid #FFFFFF", boxShadow: "0 0 0 3px rgba(22,163,74,.28), 0 0 16px 4px rgba(22,163,74,.5)" }
                  : { background: "linear-gradient(165deg,#2C2533,#17141F)", border: "1.5px solid #FFFFFF", boxShadow: "0 8px 18px -8px rgba(23,20,31,0.75)" }}
              >
                <span aria-hidden="true" className="block h-2.5 w-2.5 rounded-full" style={{ background: myLive.on ? "#FFFFFF" : "#22C55E", boxShadow: myLive.on ? "0 0 0 3px rgba(255,255,255,.35)" : "0 0 0 3px rgba(34,197,94,.3)" }} />
                {myLive.on
                  ? (myLive.startedAt ? t("m587_live_since").replace("{d}", formatAgo(nowTs - myLive.startedAt, t)) : t("m586_live_on"))
                  : t("m586_live")}
              </button>
            )}
            <Link href="/friends" onPointerDown={revealControls} title={t("map_friends_btn")} aria-label={t("map_friends_btn")} className={`pointer-events-auto inline-flex min-h-[44px] items-center gap-2 whitespace-nowrap rounded-full py-1 text-sm font-bold hover:scale-[1.03] ${compactTop ? "px-1.5" : "pl-1.5 pr-4"}`} style={{ ...glassStyle(dark), color: dark ? "#FBEFE6" : "#231715" }}>
              <span className="grid h-8 w-8 place-items-center rounded-full" style={{ background: "linear-gradient(165deg,#F48AB4,#E0568B)", border: "1.5px solid #fff" }}><AppIcon name="friends" size={17} color="#fff" /></span>
              {!compactTop && t("map_friends_btn")}
            </Link>
          </div>

          {/* 26/09 (589) — coin haut-droit, comme l'app : TROIS ronds orange
              signature, « ? » (légende), Actualiser, puis la ROUE « Options de
              la carte » (elle remplace la pilule « Options » du bas). Le mode
              nuit est passé dans les outils du panneau (Raccourcis). */}
          <div onPointerDown={revealControls} className={`absolute right-3 top-3 z-[1000] flex items-center gap-2 ${fadeCls}`}>
            <OrangeRound onClick={() => setLegendOpen(true)} label={t("legend_btn")}>
              <AppIcon name="question" size={21} color="#FFFFFF" />
            </OrangeRound>
            <OrangeRound onClick={manualRefresh} label={t("p589_refresh")} busy={refreshing}>
              {refreshing
                ? <span className="h-5 w-5 animate-spin rounded-full border-[2.5px] border-white border-t-transparent" />
                : <svg viewBox="0 0 24 24" width="21" height="21" fill="none" stroke="#FFFFFF" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M20 12a8 8 0 1 1-2.35-5.65" /><path d="M20.5 3.5v5h-5" /></svg>}
            </OrangeRound>
            <OrangeRound onClick={openOptions} label={t("p589_options")}>
              <GearIcon size={22} />
            </OrangeRound>
          </div>
          {locateMsg && (
            <div className="absolute bottom-[270px] right-[72px] z-[1100] max-w-[230px] rounded-2xl bg-white px-3 py-2 text-[12px] font-medium text-[#231715] shadow-[0_10px_26px_-10px_rgba(120,53,15,0.45)]">
              {locateMsg}
              <button type="button" onClick={() => setLocateMsg(null)} className="ml-2 font-bold text-[#C92A12]" aria-label="OK">OK</button>
            </div>
          )}

          {/* 25/09 — ITINÉRAIRE visible SUR la carte (téléphone compris) :
              calcul en cours, résultat (mode, distance, durée), refus
              « abonnement requis » ou erreur — jamais un clic sans effet. */}
          {(routeLoading || route || directionsLocked || directionsError) && (
            <div className="absolute left-3 right-3 top-[64px] z-[1060] rounded-[18px] bg-white p-2.5 shadow-[0_10px_28px_-10px_rgba(35,23,21,0.45)] sm:right-auto sm:top-3 sm:w-[340px]" role="status">
              <div className="flex items-center gap-2">
                <span className="grid h-8 w-8 shrink-0 place-items-center rounded-full" style={{ background: `${routeColor}1f` }}>
                  {routeLoading ? <span className="h-4 w-4 animate-spin rounded-full border-2 border-t-transparent" style={{ borderColor: routeColor, borderTopColor: "transparent" }} /> : <AppIcon name="route" size={17} color={directionsLocked ? "#6B21A8" : directionsError ? "#9E1F0B" : routeColor} />}
                </span>
                <div className="min-w-0 flex-1 text-[13px] font-bold leading-tight text-[#231715]">
                  {routeLoading
                    ? t("route_computing")
                    : directionsLocked
                      ? <span style={{ color: "#6B21A8" }}>{t("map_directions_locked")}</span>
                      : directionsError
                        ? <span style={{ color: "#9E1F0B" }}>{t("map_directions_error")}</span>
                        : route && route.distanceMeters != null && route.durationSeconds != null
                          ? t("map_route_distance").replace("{km}", (route.distanceMeters / 1000).toFixed(1)).replace("{min}", formatRouteDuration(route.durationSeconds))
                          : t("map_route_ready")}
                  {routeFrom === "center" && !directionsLocked && !directionsError && (
                    <span className="mt-0.5 block text-[11px] font-semibold text-[#9A3412]">{t("route_from_center")}</span>
                  )}
                </div>
                <button type="button" onClick={clearRoute} aria-label={t("common_close")} className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-[#FAF1EC]"><AppIcon name="close" size={15} color="#231715" /></button>
              </div>
              {directionsLocked ? (
                <Link href="/boutique" className="mt-2 flex min-h-[40px] items-center justify-center gap-2 rounded-[12px] px-3 text-xs font-bold text-white" style={{ background: "linear-gradient(90deg,#7C3AED,#6D28D9)" }}>
                  <AppIcon name="crown" size={15} color="#fff" />{t("map_directions_locked_cta")}
                </Link>
              ) : routeTarget && !directionsError ? (
                <div className="mt-2 flex items-center gap-1.5">
                  {(["walk", "bike", "car"] as RouteMode[]).map((m) => (
                    <button key={m} type="button" onClick={() => setRouteMode(m)} aria-pressed={routeMode === m} className="min-h-[34px] flex-1 rounded-[10px] px-2 text-[11px] font-bold transition" style={routeMode === m ? { background: ROUTE_COLORS[m], color: "#fff" } : { background: "#fff", color: ROUTE_COLORS[m], boxShadow: `inset 0 0 0 1.5px ${ROUTE_COLORS[m]}66` }}>
                      {t(m === "walk" ? "map_route_mode_walk" : m === "bike" ? "map_route_mode_bike" : "map_route_mode_car")}
                    </button>
                  ))}
                  {route && route.steps.length > 1 && (
                    <button type="button" onClick={() => { setShowSteps(true); setSheet("full"); }} className="min-h-[34px] shrink-0 rounded-[10px] px-2 text-[11px] font-bold" style={{ color: routeColor, boxShadow: `inset 0 0 0 1.5px ${routeColor}66` }}>
                      {t("route_steps")}
                    </button>
                  )}
                </div>
              ) : null}
            </div>
          )}

          {/* 25/09 (points 4 + 9) — SUIVI EN DIRECT : plus de barre violette.
              Une petite PILULE discrète en bas de la carte (photo, « Jose · en
              direct · 12 s », chevron) ; un clic ouvre une petite feuille
              Recentrer / Itinéraire / Message / Arrêter de suivre. */}
          {followed && (
            <div className="pointer-events-none absolute inset-x-0 bottom-5 z-[1050] flex flex-col items-center gap-2 px-[72px]">
              {followSheet && (
                <div className="pointer-events-auto w-full max-w-[300px] rounded-[20px] bg-white p-2 shadow-[0_12px_32px_-8px_rgba(76,29,149,0.45)]" role="dialog" aria-label={t("live_sheet_title")}>
                  <div className="grid grid-cols-2 gap-1.5">
                    <button type="button" onClick={() => { setFollowPaused(false); setFocusTarget({ lat: followed.lat, lng: followed.lng, ts: Date.now(), zoom: 16.5 }); setFollowSheet(false); }} className="flex min-h-[44px] items-center justify-center gap-1.5 rounded-[14px] bg-[#EDE9FE] px-2 text-xs font-bold text-[#5B21B6]">
                      <AppIcon name="locate" size={16} color="#6D28D9" />{t("live_recenter")}
                    </button>
                    <button type="button" onClick={() => { handleDirections({ lat: followed.lat, lng: followed.lng }); setFollowSheet(false); }} className="flex min-h-[44px] items-center justify-center gap-1.5 rounded-[14px] bg-[#DCFCE7] px-2 text-xs font-bold text-[#15803D]">
                      <AppIcon name="route" size={16} color="#15803D" />{t("map_directions_btn")}
                    </button>
                    <button type="button" onClick={() => { void openMessage({ id: followed.userId, role: followed.role, name: followed.name }); }} className="flex min-h-[44px] items-center justify-center gap-1.5 rounded-[14px] bg-[#DBEAFE] px-2 text-xs font-bold text-[#1E4FB0]">
                      <AppIcon name="chat" size={16} color="#1E4FB0" />{t("live_message")}
                    </button>
                    <button type="button" onClick={stopFollow} className="flex min-h-[44px] items-center justify-center gap-1.5 rounded-[14px] px-2 text-xs font-bold text-[#9E1F0B] ring-1 ring-inset ring-[#F3C4BA]">
                      <AppIcon name="close" size={16} color="#9E1F0B" />{t("live_stop_follow")}
                    </button>
                  </div>
                </div>
              )}
              <button
                type="button"
                onClick={() => {
                  // 588 — la pilule recentre aussi sur l'ami (vol doux) et reprend le suivi.
                  setFollowPaused(false);
                  setFocusTarget({ lat: followed.lat, lng: followed.lng, ts: Date.now(), zoom: 16, duration: 0.8 });
                  setFollowSheet((v) => !v);
                }}
                aria-expanded={followSheet}
                aria-label={t("live_open_sheet")}
                className="pointer-events-auto inline-flex min-h-[44px] max-w-full items-center gap-2 rounded-full bg-white/95 py-1 pl-1 pr-3 text-xs font-bold text-[#231715] shadow-[0_8px_24px_-6px_rgba(76,29,149,0.45)] ring-1 ring-[#DDD6FE] backdrop-blur"
              >
                <span className="relative h-9 w-9 shrink-0 overflow-hidden rounded-full" style={{ border: "2.5px solid #F06AA0", background: ROLE_COLOR[roleKey(followed.role)] }}>
                  {followed.avatar ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={followed.avatar} alt="" className="h-full w-full object-cover" />
                  ) : (
                    <span className="grid h-full w-full place-items-center text-[13px] font-bold text-white">{(followed.name || "?").charAt(0).toUpperCase()}</span>
                  )}
                </span>
                <span className="min-w-0 truncate">{followed.name}</span>
                <span className="inline-flex shrink-0 items-center gap-1" style={{ color: followed.state === "lost" ? "#C2410C" : "#6D28D9" }}>
                  <span className={`inline-block h-2 w-2 rounded-full ${followed.state === "lost" ? "" : "animate-pulse"}`} style={{ background: followed.state === "lost" ? "#EA580C" : "#7C3AED" }} />
                  {followed.state === "lost" ? t("live_state_lost") : t("live_state_live")} · {formatAgo(followed.lastSeenAt ? nowTs - new Date(followed.lastSeenAt).getTime() : 0, t)}
                </span>
                <span className={`shrink-0 text-[#6D28D9] transition-transform ${followSheet ? "rotate-90" : "-rotate-90"}`}><AppIcon name="arrow-right" size={14} color="#6D28D9" /></span>
              </button>
            </div>
          )}
          {(liveToast || friendsOnlyMsg) && (
            <div className={`pointer-events-none absolute inset-x-0 z-[1060] flex justify-center px-[72px] ${followed ? "bottom-[76px]" : "bottom-5"}`}>
              {liveToast
                ? <StatusToast key={`lt-${liveToast}`} kind={liveToast === t("route_pick_target") ? "follow" : "liveOff"} text={liveToast} dark={dark} />
                : friendsOnlyMsg && <StatusToast key={`vt-${friendsOnlyMsg.kind}-${friendsOnlyMsg.text}`} kind={friendsOnlyMsg.kind} text={friendsOnlyMsg.text} dark={dark} />}
            </div>
          )}

          {/* Viseur de placement (Tag spot / Signaler). */}
          {createKind && (
            <div className="pointer-events-none absolute left-1/2 top-1/2 z-[1100] -translate-x-1/2 -translate-y-1/2">
              <div className="h-5 w-5 rounded-full border-[2.5px] border-white shadow-lg" style={{ backgroundColor: createKind === "spot" ? "#17141F" : "#D32F2F" }} />
              <div className="absolute left-1/2 top-1/2 h-10 w-10 -translate-x-1/2 -translate-y-1/2 rounded-full" style={{ border: `2px solid ${createKind === "spot" ? "#17141F" : "#D32F2F"}`, opacity: 0.5 }} />
            </div>
          )}

          {/* RAIL GAUCHE (25/09, PawMap 585 — « ça peut être plus joli ? ») :
              une CAPSULE de verre dépoli teinté (blanc chaud, liseré blanc fin,
              ombre chaude — jamais de gris), boutons 44 px espacés de 10 px,
              chacun un disque dégradé de sa couleur + reflet + icône blanche ;
              actif = anneau blanc + léger agrandissement. Même ordre que l'app. */}
          <div className="absolute bottom-4 left-3 z-[1000]" style={{ transform: railCollapsed ? "translateX(calc(-100% - 12px))" : "translateX(0)", transition: "transform 200ms cubic-bezier(.2,.8,.2,1)" }}>
          <div onPointerDown={revealControls} className={fadeCls} {...inertIf(railCollapsed)}>
            <div className="flex flex-col rounded-[30px] p-[6px]" style={{ ...glassStyle(dark), gap: railFit.gap }}>
              {(
                [
                  { k: "around", g1: "#A076FF", g2: "#7040D6", label: t("map_around_title"), on: () => { setSheet("full"); document.getElementById("around-list")?.scrollIntoView({ behavior: "smooth", block: "start" }); } },
                  { k: "route", g1: "#3DBF6C", g2: "#188A42", label: t("map_directions_btn"), on: () => {
                    if (selectedPoi) { const [lng, lat] = selectedPoi.location.coordinates; handleDirections({ lat, lng }); }
                    else if (followed) handleDirections({ lat: followed.lat, lng: followed.lng });
                    else {
                      // Aucune destination choisie : on le DIT, puis la liste « autour de toi ».
                      setLiveToast(t("route_pick_target"));
                      setTimeout(() => setLiveToast(null), 4500);
                      setSheet("full"); document.getElementById("around-list")?.scrollIntoView({ behavior: "smooth", block: "start" });
                    }
                  } },
                  { k: "chat", g1: "#5B9DFF", g2: "#2358D6", label: t("dash_card_messages_title"), on: () => router.push("/chat") },
                  { k: "photo", g1: "#FFB067", g2: "#E07A12", label: t("map_spot_photo_label"), on: () => openCreate("spot", true) },
                  { k: "spot", g1: "#FAC346", g2: "#E2981A", label: t("map_panel_spots_title"), on: () => {
                    if (sidePanel === "spots") { setSidePanel(null); return; }
                    setShowSpots(true); setSidePanel("spots"); setSheet("full");
                    setTimeout(() => document.getElementById("side-panel")?.scrollIntoView({ behavior: "smooth", block: "start" }), 80);
                  }, active: sidePanel === "spots" },
                  { k: "add", g1: "#48C8BA", g2: "#18968A", label: t("map_tag_spot_cta"), on: () => openCreate("spot") },
                  { k: "report", g1: "#FF6E5C", g2: "#D63A28", label: t("map_report_cta"), on: () => openCreate("report") },
                  { k: "feed", g1: "#6B5A50", g2: "#2E231D", label: t("map_panel_reports_title"), on: () => {
                    if (sidePanel === "reports") { setSidePanel(null); return; }
                    setShowReports(true); setSidePanel("reports"); setSheet("full");
                    setTimeout(() => document.getElementById("side-panel")?.scrollIntoView({ behavior: "smooth", block: "start" }), 80);
                  }, active: sidePanel === "reports" },
                ] as { k: keyof typeof RAIL_SVG; g1: string; g2: string; label: string; on: () => void; active?: boolean }[]
              ).map((b) => (
                <button
                  key={`rail-${b.k}`}
                  type="button"
                  title={b.label}
                  aria-label={b.label}
                  aria-pressed={b.active}
                  onClick={b.on}
                  className="relative grid place-items-center overflow-hidden rounded-full transition-transform duration-300 ease-[cubic-bezier(.3,1.5,.4,1)] hover:scale-[1.06] active:scale-95 active:duration-100"
                  style={{
                    width: railFit.btn,
                    height: railFit.btn,
                    background: `linear-gradient(165deg, ${b.g1}, ${b.g2})`,
                    border: "1.5px solid #FFFFFF",
                    transform: b.active ? "scale(1.08)" : undefined,
                    boxShadow: b.active
                      ? `0 0 0 3px #FFFFFF, 0 0 0 5px ${b.g1}, 0 8px 18px -6px ${b.g2}`
                      : `0 6px 14px -6px ${b.g2}, inset 0 -2px 4px ${b.g2}`,
                  }}
                >
                  <span className="pointer-events-none absolute inset-x-[5px] top-[2px] h-[46%] rounded-full" style={{ background: "linear-gradient(180deg, rgba(255,255,255,0.55), rgba(255,255,255,0))" }} />
                  <span className="relative block h-[22px] w-[22px]" dangerouslySetInnerHTML={{ __html: RAIL_SVG[b.k] }} />
                </button>
              ))}
            </div>
          </div>
          <BarTab side="left" collapsed={railCollapsed} dark={dark} className={fadeCls} label={railCollapsed ? t("m587_rail_show") : t("m587_rail_hide")} onClick={() => { revealControls(); toggleBar("railCollapsed"); }} />
          </div>

          {/* CAPSULE DROITE (même verre) : zoom, ma position (accent du rôle),
              satellite, membres. Alignée en bas sur le rail gauche. */}
          <div className="absolute bottom-4 right-3 z-[1000]" style={{ transform: capsuleCollapsed ? "translateX(calc(100% + 12px))" : "translateX(0)", transition: "transform 200ms cubic-bezier(.2,.8,.2,1)" }}>
          <div onPointerDown={revealControls} className={fadeCls} style={capsuleScale < 1 ? { transform: `scale(${capsuleScale})`, transformOrigin: "bottom right" } : undefined} {...inertIf(capsuleCollapsed)}>
            <div ref={capsuleRef} className="flex flex-col items-center rounded-[30px] p-[6px]" style={glassStyle(dark)}>
              <CapsuleBtn dark={dark} label={t("map_zoom_in")} onClick={() => { try { mapRef.current?.zoomIn(); } catch { /* */ } }}>
                <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" aria-hidden="true"><path d="M12 5v14M5 12h14" /></svg>
              </CapsuleBtn>
              <CapsuleSep dark={dark} />
              <CapsuleBtn dark={dark} label={t("map_zoom_out")} onClick={() => { try { mapRef.current?.zoomOut(); } catch { /* */ } }}>
                <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" aria-hidden="true"><path d="M5 12h14" /></svg>
              </CapsuleBtn>
              <CapsuleSep dark={dark} />
              <button
                type="button"
                title={t("map_locate_btn")}
                aria-label={t("map_locate_btn")}
                disabled={locating}
                onClick={locateMe}
                className="my-1 grid h-11 w-11 place-items-center rounded-full text-white transition-transform duration-200 hover:scale-[1.05] active:scale-95"
                style={{ background: ROLE_GRAD_BTN[roleKey(myRole)], border: "1.5px solid #FFFFFF", boxShadow: `0 6px 14px -6px ${roleColor}` }}
              >
                {locating ? <span className="h-5 w-5 animate-spin rounded-full border-2 border-white border-t-transparent" /> : <AppIcon name="locate" size={21} color="#fff" />}
              </button>
              <CapsuleSep dark={dark} />
              <CapsuleBtn dark={dark} label={satellite ? t("map_layer_plan") : t("map_layer_satellite")} pressed={satellite} accent={roleColor} onClick={() => setSatellite((v) => { try { localStorage.setItem("hopetsit:mapSat", v ? "0" : "1"); } catch { /* */ } return !v; })}>
                <AppIcon name={satellite ? "map" : "globe"} size={20} color="currentColor" />
              </CapsuleBtn>
              <CapsuleSep dark={dark} />
              <CapsuleBtn dark={dark} label={showMembers ? t("map_members_hide") : t("map_members_show")} pressed={showMembers} accent={roleColor} onClick={() => setShowMembers((v) => !v)}>
                <AppIcon name="people" size={20} color="currentColor" />
              </CapsuleBtn>
              {/* 25/09 (586, point 3) — ŒIL « qui me voit » : un clic = état
                  suivant (Tous → Amis → Masqué → Tous), pastille 2 s. */}
              {getStoredUser() && (
                <>
                  <CapsuleSep dark={dark} />
                  <CapsuleBtn
                    dark={dark}
                    label={`${t("m586_vis_title")} : ${t(visibility === "all" ? "v587_all_t" : visibility === "friends" ? "v587_friends_t" : "v587_hidden_t")} — ${t(visibility === "all" ? "v587_all_d" : visibility === "friends" ? "v587_friends_d" : "v587_hidden_d")}`}
                    pressed={visibility !== "all"}
                    accent={roleColor}
                    onClick={() => { void changeVisibility(nextMapVisibility(visibility)); }}
                  >
                    {friendsOnlyBusy ? <span className="h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent" /> : <EyeIcon state={visibility} />}
                  </CapsuleBtn>
                </>
              )}
              {/* 25/09 (586, point 2) — un trait, puis l'ACTION DU RÔLE.
                  587 (point 1a) : le Direct du gardien / promeneur est passé en
                  haut à gauche ; la capsule garde « Publier » (propriétaire). */}
              {isOwner && (
                <>
                  <span aria-hidden="true" className="my-1.5 block h-[2px] w-7 rounded-full" style={{ background: dark ? "#6B4F57" : "#E4C7B8" }} />
                  {/* 26/09 (589) — mégaphone + petit « + » (créer une annonce),
                      et « Publier » TOUJOURS écrit dessous, comme l'app. */}
                  <Link
                    href="/posts/create"
                    title={t("m586_publish_long")}
                    aria-label={t("m586_publish_long")}
                    className="flex flex-col items-center transition-transform duration-200 hover:scale-[1.04] active:scale-95"
                  >
                    <span className="relative grid h-11 w-11 place-items-center rounded-full text-white" style={{ background: "linear-gradient(165deg,#E0553F,#C92A12 55%,#A31F0C)", border: "1.5px solid #FFFFFF", boxShadow: "0 6px 14px -6px #C92A12" }}>
                      <AppIcon name="megaphone" size={21} color="#fff" />
                      <span aria-hidden="true" className="absolute -right-1 -top-1 grid h-[17px] w-[17px] place-items-center rounded-full bg-white" style={{ border: "1.4px solid #C92A12", boxShadow: "0 2px 5px -1px rgba(146,31,11,0.45)" }}>
                        <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="#C92A12" strokeWidth="3.4" strokeLinecap="round" aria-hidden="true"><path d="M12 5.5v13M5.5 12h13" /></svg>
                      </span>
                    </span>
                    <span className="mt-1 whitespace-nowrap px-1 text-[10.5px] font-extrabold leading-none" style={{ color: dark ? "#FFB39E" : "#9E1F0B" }}>
                      {t("m586_publish")}
                    </span>
                  </Link>
                </>
              )}
            </div>
          </div>
          <BarTab side="right" collapsed={capsuleCollapsed} dark={dark} className={fadeCls} label={capsuleCollapsed ? t("m587_caps_show") : t("m587_caps_hide")} onClick={() => { revealControls(); toggleBar("capsuleCollapsed"); }} />
          </div>

          {/* 26/09 (589) — la pilule « Options » du bas est SUPPRIMÉE (elle
              gênait au milieu de la carte) : la roue orange en haut à droite
              ouvre le panneau. */}
          {shareToast && (
            <div className="pointer-events-none absolute inset-x-0 top-[64px] z-[1070] flex justify-center px-4" role="status">
              <span className="rounded-full bg-white px-4 py-2 text-[13px] font-bold text-[#9E1F0B] shadow-[0_10px_26px_-10px_rgba(120,53,15,0.5)]">{t("p589_link_copied")}</span>
            </div>
          )}

          <PoiMap
            center={center}
            initialZoom={initialZoom}
            pois={visiblePois}
            userLocation={userLocation}
            selectedPoi={selectedPoi}
            onSelectPoi={setSelectedPoi}
            onMapMove={handleMapMove}
            onZoomChange={handleZoomChange}
            onBoundsChange={setViewBounds}
            spots={showSpots ? spots : []}
            spotTypeLabels={spotTypeLabels}
            onSpotVisit={handleSpotVisit}
            reports={showReports ? reports : []}
            reportTypeLabels={reportTypeLabels}
            members={membersWithPresence}
            memberRoleLabels={{ owner: t("role_owner"), sitter: t("role_sitter"), walker: t("role_walker") }}
            cardLabels={cardLabels}
            wantedRoles={memberRoles}
            distanceFrom={distanceFrom}
            onMapReady={(m) => { mapRef.current = m; setMapReadyTick((n) => n + 1); }}
            satellite={satellite}
            onAddFriend={handleAddFriend}
            friendPositions={showFriends ? livePositionsList : []}
            liveIdsAll={showFriends ? liveIdsAll : []}
            familyIds={familyIds}
            premiumIds={premiumIds}
            roleLabels={{ owner: t("role_owner"), sitter: t("role_sitter"), walker: t("role_walker") }}
            userRole={myRole}
            userName={myName}
            userAvatarUrl={myAvatarUrl}
            userIsPremium={premiumDays !== null || isStaffSub || benefits?.premiumActive === true}
            userBoosted={benefits?.isBoosted === true}
            userPawFollow={benefits?.pawFollowActive === true || benefits?.familyActive === true}
            userFriendsOnly={friendsOnly}
            userAccuracy={userAccuracy}
            meLabel={t("legend_me_label")}
            positionLabel={t("map_your_position")}
            accuracyLabel={t("map_accuracy_note")}
            focusTarget={focusTarget}
            focusFriend={focusFriend}
            onFriendFocus={startFollow}
            followHaloId={followUserId}
            friendIds={[...friendIdSet]}
            friendSeen={friendSeen}
            liveLabels={liveLabels}
            now={nowTs}
            onMessage={(w) => { void openMessage(w); }}
            onMessageMember={(m) => {
              // Visiteur → gardien / promeneur : la conversation « prestataire »
              // (même route que l'app). 25/09 (586, point 8) — quel que soit
              // mon rôle : un gardien / promeneur écrit avec son profil
              // propriétaire (passage automatique). Fiche propriétaire : non.
              const k = roleKey(m.role);
              if (k === "owner") {
                // 25/09 (586, point 9) — gardien / promeneur → propriétaire.
                const me = roleKey(myRole);
                if (me === "owner") return null;
                return () => {
                  void startConversationWithOwner(me as "sitter" | "walker", m.id)
                    .then((cid) => router.push(cid ? `/chat?c=${cid}` : "/chat"))
                    .catch(() => router.push("/chat"));
                };
              }
              return () => {
                void ensureOwnerProfile()
                  .then((ok) => { if (!ok) throw new Error("switch"); return startProviderConversation(k, m.id); })
                  .then((cid) => router.push(cid ? `/chat?c=${cid}` : "/chat"))
                  .catch(() => router.push(`/book/${k}/${m.id}`));
              };
            }}
            followUserId={followPaused ? null : followUserId}
            onFollowPause={() => setFollowPaused(true)}
            followLabel={t("map_follow_resume")}
            routePoints={route?.points ?? null}
            routeColor={routeColor}
            routeSteps={route?.steps ?? null}
            onDirections={handleDirections}
            directionsLabel={t("map_directions_btn")}
            formatOpenStatus={formatOpenStatus}
            callLabel={t("poi_call")}
            requests={showRequests ? requests : []}
            requestLabels={{ title: t("map_request_title"), mine: t("map_request_mine"), offer: t("map_request_offer"), sitting: t("home_service_sitting"), walk: t("home_service_walk") }}
            onOfferService={(id) => router.push(`/post/${id}`)}
            dark={dark}
          />
        </div>

        {/* ── PANNEAU « Options de la carte » : colonne droite sur ordinateur,
            feuille glissante sur téléphone (ouverte par la roue orange). ── */}
        {/* 26/09 (589) — rangé en CARTES comme l'app : en-tête (roue + titre +
            croix), bouton principal, « Ce que je veux voir », « Raccourcis »,
            « Mes abonnements sur la carte », puis les listes. Aucune fonction
            retirée. */}
        <aside
          className={`fixed inset-x-0 bottom-0 z-[1500] flex flex-col rounded-t-[28px] bg-[#FFF8F4] shadow-[0_-10px_40px_-10px_rgba(35,23,21,0.35)] transition-[height,box-shadow] duration-300 ${sheetH} lg:static lg:z-auto lg:h-[calc(100vh-230px)] lg:min-h-[560px] lg:rounded-[28px] lg:bg-[#FAF1EC] ${optionsFlash ? "lg:shadow-[0_0_0_3px_#D83C28,0_18px_40px_-18px_rgba(185,36,37,0.6)]" : "lg:shadow-none"}`}
         style={fitH && typeof window !== "undefined" && window.innerWidth >= 1024 ? { height: fitH } : undefined}>
          {/* Poignée (téléphone, tablette) : glisser vers le bas = ranger,
              vers le haut = agrandir ; un clic alterne moitié / plein écran. */}
          <button
            type="button"
            onClick={() => setSheet((v) => (v === "full" ? "half" : "full"))}
            onPointerDown={onSheetPointerDown}
            onPointerUp={(e) => { const d = sheetSwipe(e); if (d === "down") setSheet((v) => (v === "full" ? "half" : "closed")); else if (d === "up") setSheet("full"); }}
            aria-label={sheet === "full" ? t("map_sheet_less") : t("map_sheet_more")}
            className="flex h-5 w-full shrink-0 touch-none items-end justify-center lg:hidden"
          >
            <span className="block h-1.5 w-12 rounded-full" style={{ background: "#E4B5A6" }} />
          </button>
          {/* En-tête : roue orange + « Options de la carte » + croix. */}
          <div className="flex shrink-0 items-center gap-3 px-4 pb-2 pt-2 lg:px-5 lg:pt-5">
            <span className="relative grid h-10 w-10 shrink-0 place-items-center overflow-hidden rounded-full" style={{ background: "linear-gradient(165deg,#E2503A 0%,#D83C28 50%,#B92425 100%)", border: "1.5px solid #FFFFFF", boxShadow: "0 6px 14px -6px rgba(185,36,37,0.8)" }}>
              <GearIcon size={20} />
            </span>
            <h2 className="min-w-0 flex-1 font-display text-[18px] font-bold leading-tight tracking-[-0.01em] text-[#231715]">{t("p589_options")}</h2>
            <button type="button" onClick={() => setSheet("closed")} aria-label={t("m586_options_close")} title={t("m586_options_close")} className="grid h-11 w-11 shrink-0 place-items-center rounded-full lg:hidden">
              <span className="grid h-9 w-9 place-items-center rounded-full bg-[#FBE3DC]"><AppIcon name="close" size={15} color="#9E1F0B" /></span>
            </button>
          </div>

          <div ref={panelScrollRef} className="min-h-0 flex-1 overflow-y-auto px-4 pb-6 lg:px-5">
            {/* BOUTON PRINCIPAL : propriétaire → « Publier » ; les 3 profils →
                la ligne du direct (il se lance dans l'app). */}
            {isOwner && (
              <Link href="/posts/create" className="mb-2.5 flex min-h-[52px] items-center gap-3 rounded-2xl p-2.5 pr-3 text-left text-white transition hover:brightness-105" style={{ background: "linear-gradient(90deg,#E2503A,#D83C28 55%,#B92425)", boxShadow: "0 12px 24px -14px #B92425" }}>
                <span className="relative grid h-9 w-9 shrink-0 place-items-center rounded-full" style={{ background: "rgba(255,255,255,0.18)", border: "1.5px solid #FFFFFF" }}><AppIcon name="megaphone" size={18} color="#fff" /></span>
                <span className="min-w-0 flex-1 text-sm font-bold">{t("m586_publish_long")}</span>
                <AppIcon name="arrow-right" size={16} color="#FFFFFF" />
              </Link>
            )}
            <button type="button" onClick={() => setLiveInfoOpen(true)} className="mb-3 flex min-h-[52px] w-full items-center gap-3 rounded-2xl bg-white p-2.5 pr-3 text-left shadow-[0_6px_18px_-14px_rgba(120,53,15,0.6)] transition hover:bg-[#FFFBF9]">
              <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full" style={{ background: myLive.on ? "linear-gradient(165deg,#22C55E,#16A34A 55%,#15803D)" : "linear-gradient(165deg,#2C2533,#17141F)" }}><LiveIcon size={18} /></span>
              <span className="min-w-0 flex-1">
                <span className="block text-sm font-bold" style={{ color: myLive.on ? "#15803D" : "#17141F" }}>{myLive.on ? (myLive.startedAt ? t("m587_live_since").replace("{d}", formatAgo(nowTs - myLive.startedAt, t)) : t("m586_live_on")) : t("m586_live")}</span>
                <span className="block text-[11px] leading-snug text-[#6E4F48]">{myLive.on ? t("m587_live_on_title") : t("m587_live_app_title")}</span>
              </span>
              <AppIcon name="arrow-right" size={16} color="#17141F" />
            </button>

            {/* « Ce que je veux voir » : pastilles d'égale largeur, 2 colonnes. */}
            <section className="rounded-2xl bg-white p-3 shadow-[0_6px_18px_-14px_rgba(120,53,15,0.6)]" aria-labelledby="see-title">
              <div className="flex items-center gap-2">
                <h2 id="see-title" className="min-w-0 flex-1 font-display text-[15px] font-bold text-[#231715]">{t("m586_see_title")}</h2>
                <button type="button" onClick={() => seeAll(true)} className="min-h-[34px] rounded-xl px-3 text-[12px] font-bold text-[#17141F] transition hover:bg-[#FAF1EC]" style={{ boxShadow: "inset 0 0 0 1.5px #E4C7B8" }}>{t("m586_see_all")}</button>
                <button type="button" onClick={() => seeAll(false)} className="min-h-[34px] rounded-xl px-3 text-[12px] font-bold text-[#17141F] transition hover:bg-[#FAF1EC]" style={{ boxShadow: "inset 0 0 0 1.5px #E4C7B8" }}>{t("m586_see_none")}</button>
              </div>
              <div className="mt-2.5 grid grid-cols-2 gap-2">
                {seeChips.map((c) => (
                  <button
                    key={c.k}
                    type="button"
                    onClick={c.toggle}
                    aria-pressed={c.on}
                    className="flex min-h-[40px] min-w-0 items-center gap-1.5 rounded-xl py-1 pl-1.5 pr-2 text-left text-[12px] font-bold leading-tight transition-all duration-200 ease-out active:scale-[0.97]"
                    style={c.on
                      ? { background: c.bg, color: c.fg, boxShadow: `0 6px 14px -8px ${c.bg}, inset 0 1px 0 rgba(255,255,255,0.25)` }
                      : { background: "#FFFFFF", color: c.k === "spots" ? "#17141F" : c.bg, boxShadow: `inset 0 0 0 1.5px ${c.bg}` }}
                  >
                    <span className="grid h-6 w-6 shrink-0 place-items-center rounded-full" style={c.on ? { background: "rgba(255,255,255,0.22)" } : { background: c.k === "spots" ? "#FFF3D1" : `${c.bg}1A` }}>{c.icon}</span>
                    <span className="min-w-0 [overflow-wrap:anywhere]">{c.label}</span>
                  </button>
                ))}
              </div>
              <p className="mt-2 text-[11px] leading-snug text-[#6E4F48]">{t("m586_see_hint")}</p>
            </section>

            {/* RACCOURCIS : Amis et Mes abonnements (tuiles), puis les actions,
                puis les outils en rangée d'icônes colorées. */}
            <section className="mt-3 rounded-2xl bg-white p-3 shadow-[0_6px_18px_-14px_rgba(120,53,15,0.6)]" aria-labelledby="shortcuts-title">
              <h2 id="shortcuts-title" className="px-0.5 font-display text-[15px] font-bold text-[#231715]">{t("p589_shortcuts")}</h2>
              <div className="mt-2.5 grid grid-cols-2 gap-2">
                <Link href="/friends" className="flex min-h-[48px] min-w-0 items-center gap-2 rounded-xl bg-[#FDEBF3] px-2.5 text-[13px] font-bold text-[#9D174D] transition hover:brightness-[0.98]">
                  <span className="grid h-8 w-8 shrink-0 place-items-center rounded-full" style={{ background: "linear-gradient(165deg,#F48AB4,#E0568B)", border: "1.5px solid #fff" }}><AppIcon name="friends" size={16} color="#fff" /></span>
                  <span className="min-w-0 leading-tight">{t("map_friends_btn")}</span>
                </Link>
                <Link href="/subscription" className="flex min-h-[48px] min-w-0 items-center gap-2 rounded-xl bg-[#EFE8FD] px-2.5 text-[13px] font-bold text-[#5B21B6] transition hover:brightness-[0.98]">
                  <span className="grid h-8 w-8 shrink-0 place-items-center rounded-full" style={{ background: "linear-gradient(165deg,#9B6BFF,#6A34E0)", border: "1.5px solid #fff" }}><AppIcon name="crown" size={16} color="#fff" /></span>
                  <span className="min-w-0 leading-tight">{t("profile_subs_title")}</span>
                </Link>
              </div>

              {/* Compteur cliquable → liste des membres. */}
              <button
                type="button"
                onClick={() => { setSidePanel(sidePanel === "members" ? null : "members"); setSheet("full"); }}
                className={`mt-2 flex w-full items-center gap-3 rounded-xl p-2.5 text-left transition ${sidePanel === "members" ? roleLight : "bg-[#FDF8F7] hover:bg-[#FAF1EC]"}`}
              >
                <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full text-white" style={{ background: roleColor }}><AppIcon name="people" size={18} color="#fff" /></span>
                <span className="min-w-0 flex-1">
                  <span className={`block text-sm font-bold ${roleTextDark}`}>{t("map_members_around").replace("{count}", String(membersAround))}</span>
                  <span className="block text-xs text-[#6E4F48]">{t("map_panel_members_title")}</span>
                </span>
                <AppIcon name="arrow-right" size={18} color={roleColor} />
              </button>

              {/* Carte vide = une action (idée 1). */}
              {membersInView === 0 && (
                <div className="mt-2 rounded-xl bg-[#FDF8F7] p-3">
                  <p className="text-sm font-bold text-[#231715]">{t("map_empty_title")}</p>
                  {myRole === "owner" ? (
                    <Link href="/posts/create" className="mt-2 flex min-h-[44px] items-center justify-center gap-2 rounded-[14px] bg-owner px-4 text-sm font-bold text-white transition hover:bg-owner-dark">
                      <AppIcon name="megaphone" size={16} color="#fff" />{t("map_empty_owner_cta")}
                    </Link>
                  ) : (
                    <Link href="/profile" className="mt-2 flex min-h-[44px] items-center justify-center gap-2 rounded-[14px] px-4 text-sm font-bold text-white transition" style={{ background: roleColor }}>
                      <AppIcon name={myRole === "walker" ? "walker" : "home"} size={16} color="#fff" />{t("map_empty_provider_cta")}
                    </Link>
                  )}
                </div>
              )}

              {/* Outils : icône colorée + nom dessous. */}
              <div className="mt-3 grid grid-cols-3 gap-1.5">
                {([
                  { k: "share", label: t("p589_share_map"), g1: "#5B9DFF", g2: "#2358D6", on: () => { void shareMap(); }, pressed: undefined as boolean | undefined,
                    icon: <svg viewBox="0 0 24 24" width="19" height="19" fill="none" stroke="#fff" strokeWidth="2.3" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M12 15V3.5M7.5 8 12 3.5 16.5 8" /><path d="M5 12.5v6A1.5 1.5 0 0 0 6.5 20h11a1.5 1.5 0 0 0 1.5-1.5v-6" /></svg> },
                  { k: "layers", label: t("p589_layers"), g1: "#3DBF6C", g2: "#188A42", pressed: satellite, on: () => setSatellite((v) => { try { localStorage.setItem("hopetsit:mapSat", v ? "0" : "1"); } catch { /* */ } return !v; }),
                    icon: <AppIcon name="layers" size={19} color="#fff" /> },
                  { k: "night", label: t("p589_night"), g1: "#4B3F63", g2: "#17141F", pressed: dark, on: toggleDark,
                    icon: <AppIcon name={dark ? "sun" : "moon"} size={19} color={dark ? "#FBD38D" : "#fff"} /> },
                ]).map((o) => (
                  <button key={o.k} type="button" onClick={o.on} aria-pressed={o.pressed} className="flex min-w-0 flex-col items-center gap-1 rounded-xl px-1 py-1.5 transition hover:bg-[#FDF8F7] active:scale-95">
                    <span className="grid h-11 w-11 place-items-center rounded-full" style={{ background: `linear-gradient(165deg,${o.g1},${o.g2})`, border: "1.5px solid #FFFFFF", boxShadow: o.pressed ? `0 0 0 3px #FFFFFF, 0 0 0 5px ${o.g1}` : `0 6px 14px -7px ${o.g2}` }}>{o.icon}</span>
                    <span className="w-full text-center text-[11px] font-bold leading-tight text-[#3B2A26] [overflow-wrap:anywhere]">{o.label}</span>
                  </button>
                ))}
              </div>
            </section>

            {/* 25/09 (585, lot 2 — bug 15) — MES ABONNEMENTS SUR LA CARTE : une
                ligne par abonnement (icône, nom, ce que ça active sur la carte),
                interrupteur à la couleur de l'abonnement s'il est possédé,
                sinon « Découvrir » vers la boutique. */}
            {(() => {
              const premiumOwned = benefits?.premiumActive === true || benefits?.isPremium === true || premiumDays !== null || isStaffSub;
              const followOwned = premiumOwned || benefits?.pawFollowActive === true || benefits?.familyActive === true;
              const spotOwned = premiumOwned || benefits?.pawspotActive === true;
              const rows: { k: string; logo: string; name: string; sub: string; owned: boolean; on: boolean; color: string; toggle: () => void; shop: string }[] = [
                { k: "follow", logo: "/pawfollow_logo.svg", name: "PawFollow", sub: t("map_sub_follow_sub"), owned: followOwned, on: showFriends, color: "#7C3AED", shop: "/boutique?tab=pawfollow",
                  toggle: () => { const v = !showFriends; setFriendsLayer(v); saveLayers({ friends: v }); } },
                { k: "spot", logo: "/pawspot_logo.svg", name: "PawSpot", sub: t("map_sub_spot_sub"), owned: spotOwned, on: showSpots, color: "#E8920A", shop: "/boutique?tab=pawspot",
                  toggle: () => { const v = !showSpots; setShowSpots(v); saveLayers({ pawspots: v }); } },
                { k: "premium", logo: "/pawpremium_logo.svg", name: "PawPremium",
                  sub: isStaffSub ? t("map_premium_active_staff") : premiumDays !== null ? t("map_premium_active_days").replace("{days}", String(premiumDays)) : t("map_sub_premium_sub"),
                  owned: premiumOwned, on: showFriends && showSpots, color: "#17141F", shop: "/boutique?tab=premium",
                  toggle: () => { const v = !(showFriends && showSpots); setFriendsLayer(v); setShowSpots(v); saveLayers({ friends: v, pawspots: v, premium: v }); } },
              ];
              return (
                <section className="mt-3 rounded-2xl bg-white p-3 shadow-[0_6px_18px_-14px_rgba(120,53,15,0.6)]" aria-labelledby="map-subs-title">
                  <h2 id="map-subs-title" className="px-1 font-display text-[15px] font-bold text-[#231715]">{t("map_subs_title")}</h2>
                  <ul className="mt-2 space-y-1.5">
                    {rows.map((r) => (
                      <li key={r.k} className="flex min-h-[56px] items-center gap-3 rounded-xl bg-[#FDF8F7] px-2.5 py-2">
                        {/* eslint-disable-next-line @next/next/no-img-element */}
                        <img src={r.logo} alt="" width={36} height={36} className="h-9 w-9 shrink-0" />
                        <span className="min-w-0 flex-1">
                          <span className="block text-sm font-bold text-[#231715]">{r.name}</span>
                          <span className="block text-[11px] leading-snug text-[#6E4F48]">{r.sub}</span>
                        </span>
                        {r.owned ? (
                          <button type="button" role="switch" aria-checked={r.on} aria-label={r.name} onClick={r.toggle} className="relative inline-block h-7 w-12 shrink-0 rounded-full transition" style={{ background: r.on ? r.color : "#F0E3DF" }}>
                            <span className={`absolute top-1 h-5 w-5 rounded-full bg-white shadow transition-all ${r.on ? "left-6" : "left-1"}`} style={r.k === "premium" && r.on ? { background: "#F4C04A" } : undefined} />
                          </button>
                        ) : (
                          <Link href={r.shop} className="inline-flex min-h-[36px] shrink-0 items-center rounded-full px-3 text-xs font-bold" style={{ color: r.k === "premium" ? "#8A5A00" : r.color, background: r.k === "premium" ? "#FFF3D1" : r.k === "follow" ? "#EDE9FE" : "#FFF1DC" }}>
                            {t("map_sub_discover")}
                          </Link>
                        )}
                      </li>
                    ))}
                  </ul>
                  {layersLocalOnly && <p className="mt-2 px-1 text-[11px] font-semibold text-[#9A3412]">{t("map_sub_saved_local")}</p>}
                </section>
              );
            })()}

            {/* Amis en direct. */}
            <div className="mt-3 rounded-2xl bg-white p-3 shadow-[0_6px_18px_-14px_rgba(120,53,15,0.6)]">
              <button type="button" onClick={toggleFriendsLayer} className="flex w-full items-center gap-2 text-left">
                <span className="relative flex h-2.5 w-2.5"><span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-[#16A34A] opacity-75" /><span className="relative inline-flex h-2.5 w-2.5 rounded-full bg-[#16A34A]" /></span>
                <span className="text-sm font-semibold text-[#231715]">{t("map_live_friends")}</span>
                <span className="rounded-full bg-[#FAF1EC] px-2 py-0.5 text-xs font-semibold text-[#231715]">{livePositionsList.length}</span>
                {friendsLoading && <span className="text-xs text-[#6E4F48]">{t("common_loading")}</span>}
              </button>
              {showFriends && livePositionsList.length > 0 && (
                <div className="mt-2 flex flex-wrap gap-1.5">
                  {livePositionsList.map((p) => (
                    <button key={`lf-${p.userId}`} type="button" onClick={() => startFollow(p)} className="inline-flex min-h-[32px] items-center gap-1.5 rounded-full border bg-white px-2 text-[11px] font-semibold transition hover:shadow" style={{ borderColor: `${roleChipColor(p.role)}55`, color: roleChipColor(p.role) }}>
                      <span className="grid h-5 w-5 place-items-center rounded-full text-[10px] font-bold text-white" style={{ backgroundColor: roleChipColor(p.role) }}>{(p.name || "?").charAt(0).toUpperCase()}</span>
                      <span className={`inline-block h-2 w-2 rounded-full ${p.isOnline === false ? "bg-[#C2410C]" : "bg-[#16A34A]"}`} />
                      {p.name} · {t(`role_${p.role}`)}
                    </button>
                  ))}
                </div>
              )}
              {/* 588 — mes autres amis : un clic = vol doux sur sa position
                  (floutée) + sa fiche ; Masqué = pastille « pas visible ». */}
              {friendsNotLive.length > 0 && (
                <>
                  <p className="mt-3 text-xs font-bold text-[#9D174D]">{t("map_seek_friends")} · {friendsNotLive.length}</p>
                  <div className="mt-1.5 flex max-h-40 flex-wrap gap-1.5 overflow-y-auto">
                    {friendsNotLive.map(({ f, spot }) => (
                      <button key={`fr-${f.id}`} type="button" onClick={() => focusOnFriend(f)} className="inline-flex min-h-[32px] items-center gap-1.5 rounded-full border bg-white px-2 text-[11px] font-semibold transition hover:shadow" style={{ borderColor: spot ? "#F06AA055" : "#F3C4BA", color: spot ? roleChipColor(roleFromModel(f.other.model)) : "#8A6B64" }}>
                        <span className="grid h-5 w-5 place-items-center rounded-full text-[10px] font-bold text-white" style={{ backgroundColor: spot ? roleChipColor(roleFromModel(f.other.model)) : "#C9A79F" }}>{(f.other.name || "?").charAt(0).toUpperCase()}</span>
                        {f.other.name || t("common_friend")}
                      </button>
                    ))}
                  </div>
                </>
              )}
            </div>

            {/* 25/09 (586, point 3) — « qui me voit » : les 3 mêmes états que
                l'œil de la capsule et que /profile (une seule route). */}
            <div className="mt-3 rounded-2xl bg-white p-3">
              <p className="flex items-center gap-2 text-sm font-semibold text-[#231715]"><span className="text-[#17141F]"><EyeIcon state={visibility} size={18} /></span>{t("m586_vis_title")}</p>
              <VisibilityPills value={visibility} busy={friendsOnlyBusy} onChange={(v) => { void changeVisibility(v); }} labels={{ all: t("v587_all_t"), friends: t("v587_friends_t"), hidden: t("v587_hidden_t") }} descs={{ all: t("v587_all_d"), friends: t("v587_friends_d"), hidden: t("v587_hidden_d") }} notes={[t("v587_live"), t("v587_where")]} />
            </div>

            {/* Itinéraire en cours. */}
            {route && (
              <div className="mt-3 rounded-2xl px-4 py-3 text-sm" style={{ backgroundColor: "#fff", boxShadow: `inset 0 0 0 1.5px ${routeColor}55` }}>
                <div className="flex flex-wrap items-center gap-2">
                  <ModePicker mode={routeMode} onChange={setRouteMode} label="" labels={{ walk: t("map_route_mode_walk"), bike: t("map_route_mode_bike"), car: t("map_route_mode_car") }} />
                  <span className="font-semibold" style={{ color: routeColor }}>
                    {routeLoading ? "…" : route.distanceMeters != null && route.durationSeconds != null ? t("map_route_distance").replace("{km}", (route.distanceMeters / 1000).toFixed(1)).replace("{min}", formatRouteDuration(route.durationSeconds)) : t("map_route_ready")}
                  </span>
                  {route.steps.length > 1 && (
                    <button type="button" onClick={() => setShowSteps((v) => !v)} className="rounded-full bg-[#FAF1EC] px-3 py-1 text-xs font-semibold text-[#231715] hover:bg-[#F0E3DF]">{showSteps ? t("map_route_steps_hide") : t("map_route_steps")}</button>
                  )}
                  <button type="button" onClick={clearRoute} className="rounded-full bg-[#FAF1EC] px-3 py-1 text-xs font-semibold text-[#231715] hover:bg-[#F0E3DF]">✕ {t("map_route_clear")}</button>
                </div>
                {showSteps && route.steps.length > 1 && (
                  <ol className="mt-2 max-h-48 space-y-1 overflow-y-auto text-xs text-ink">
                    {route.steps.map((s, i) => (
                      <li key={i} className="flex items-start gap-2">
                        <span className="mt-0.5 grid h-5 w-5 shrink-0 place-items-center rounded-full text-[11px] font-bold" style={{ backgroundColor: `${routeColor}1f`, color: routeColor }}>
                          {s.type >= 4 && s.type <= 6 ? "◉" : s.type >= 9 && s.type <= 11 ? "↱" : s.type >= 14 && s.type <= 16 ? "↰" : s.type === 12 || s.type === 13 ? "↩" : s.type === 26 || s.type === 27 ? "⟳" : "↑"}
                        </span>
                        <span className="flex-1">{s.instruction}</span>
                        {s.distanceMeters > 0 && <span className="shrink-0 text-[#6E4F48]">{s.distanceMeters >= 1000 ? `${(s.distanceMeters / 1000).toFixed(1)} km` : `${s.distanceMeters} m`}</span>}
                      </li>
                    ))}
                  </ol>
                )}
              </div>
            )}
            {directionsLocked && (
              <div className="mt-3 flex flex-wrap items-center gap-2 rounded-2xl px-4 py-3 text-sm" style={{ backgroundColor: "#F3E8FF", color: "#6B21A8" }}>
                <AppIcon name="crown" size={16} color="#6B21A8" />
                <span>{t("map_directions_locked")}</span>
                <Link href="/boutique" className="font-bold underline">{t("map_directions_locked_cta")}</Link>
              </div>
            )}
            {directionsError && <div className="mt-3 rounded-2xl bg-[#FBE9E5] px-4 py-3 text-sm text-[#9E1F0B]">{t("map_directions_error")}</div>}

            {/* Réglages fins : catégories de lieux (repliables). */}
            {!noneSelected && (
              <div className="mt-3 rounded-2xl bg-white p-3">
                <button type="button" onClick={() => setCatsOpen((v) => !v)} className="flex w-full items-center justify-between text-left text-sm font-semibold text-[#231715]">
                  <span className="inline-flex items-center gap-2"><AppIcon name="layers" size={16} color="#0F766E" />{t("map_filter_all")} · {visiblePois.length}</span>
                  <span className={`transition ${catsOpen ? "rotate-90" : ""}`}><AppIcon name="arrow-right" size={16} /></span>
                </button>
                {catsOpen && (
                  <div className="mt-2 flex flex-wrap gap-1.5">
                    <CategoryChip label={t("map_filter_all")} active={selectedCats.length === 0} onClick={() => setSelectedCats([])} />
                    {ALL_CATEGORIES.map((cat) => (
                      <CategoryChip key={cat} label={t(CAT_KEY_FOR_LANG[cat])} pinHtml={placePinHtml(cat, 16)} active={selectedCats.includes(cat)} onClick={() => setSelectedCats((prev) => (prev.includes(cat) ? prev.filter((c) => c !== cat) : [...prev, cat]))} />
                    ))}
                  </div>
                )}
              </div>
            )}

            {/* PANNEAU : signalements / spots / membres. */}
            {sidePanel && (() => {
              const from = userLocation ?? { lat: center[0], lng: center[1] };
              type Row = { id: string; lat: number; lng: number; km: number; pin: string; title: string; sub: string; photo: string; meta: string; color?: string; book?: string; friend?: boolean };
              let rows: Row[] = [];
              let title = "";
              if (sidePanel === "reports") {
                title = t("map_panel_reports_title");
                rows = reports.map((r) => { const [lng, lat] = r.location.coordinates; return { id: r._id, lat, lng, km: haversineKm(from.lat, from.lng, lat, lng), pin: reportPinHtml(22), title: reportTypeLabels[r.type] || r.type, sub: r.note || "", photo: r.photoUrl || "", meta: `${new Date(r.createdAt).toLocaleDateString(lang)}${r.confirmationsCount ? ` · ✓ ${r.confirmationsCount}` : ""}` }; });
              } else if (sidePanel === "spots") {
                title = t("map_panel_spots_title");
                rows = spots.map((sp) => ({ id: sp.id, lat: sp.lat, lng: sp.lng, km: haversineKm(from.lat, from.lng, sp.lat, sp.lng), pin: spotPinHtml(sp.type, sp.isGolden).replace(/width:\d+px;height:\d+px/, "width:22px;height:29px"), title: sp.name, sub: `${spotTypeLabels[sp.type] || sp.type}${sp.description ? ` · ${sp.description}` : ""}`, photo: sp.photoUrl || "", meta: `♥ ${sp.likesCount} · ${t("map_spot_visits").replace("{count}", String(sp.visitsCount))}` }));
              } else {
                title = t("map_panel_members_title");
                // 25/09 (585) — une personne à deux rôles = une ligne PAR rôle
                // coché dans « Je cherche », étiquetée ; distance depuis ma
                // position jusqu'au point affiché.
                const byId = new Map(membersNear.map((x) => [x.m.id, x]));
                rows = expandRows(membersNear.map((x) => x.m), { wanted: memberRoles, friendIds: friendIdSet }).map(({ m, r, friend }) => {
                  const x = byId.get(m.id)!;
                  const key = roleKey(r.role);
                  const price = key !== "owner" ? formatPrice(r.priceFrom, r.currency) : null;
                  return { id: `${m.id}-${r.id}`, lat: x.lat, lng: x.lng, km: x.shownKm, pin: "", title: m.name || t("common_member"), sub: `${t(`role_${key}`)}${price ? ` · ${t("map_member_price_from")} ${price}` : ""}${(r.rating ?? 0) > 0 ? ` · ★ ${(r.rating ?? 0).toFixed(1)}` : ""}`, photo: m.avatar || "", meta: m.approx ? t("map_member_approx").replace("{km}", String(m.approxKm ?? 1)) : "", color: ROLE_COLOR[key], book: key !== "owner" ? `/book/${key}/${r.id}` : undefined, friend };
                });
              }
              rows.sort((a, b) => a.km - b.km);
              return (
                <div id="side-panel" className="mt-3 scroll-mt-24 rounded-2xl bg-white p-3">
                  <div className="flex items-center gap-2">
                    <h2 className="font-display text-base font-bold text-[#231715]">{title}</h2>
                    <span className="rounded-full bg-[#FAF1EC] px-2 py-0.5 text-xs font-semibold text-[#231715]">{rows.length}</span>
                    <button type="button" onClick={() => setSidePanel(null)} className="ml-auto grid h-8 w-8 place-items-center rounded-full bg-[#FAF1EC] text-[#231715]" aria-label={t("map_close")}>×</button>
                  </div>
                  {sidePanel !== "members" && <ModePicker mode={routeMode} onChange={setRouteMode} label={t("map_route_mode_label")} labels={{ walk: t("map_route_mode_walk"), bike: t("map_route_mode_bike"), car: t("map_route_mode_car") }} />}
                  {rows.length === 0 ? (
                    <p className="mt-3 text-sm text-[#6E4F48]">{t("map_panel_empty")}</p>
                  ) : (
                    <ul className="mt-3 space-y-1.5">
                      {rows.slice(0, 30).map((r) => (
                        <li key={`${sidePanel}-${r.id}`} className="flex items-center gap-2.5 rounded-xl bg-[#FDF8F7] p-2 transition hover:bg-[#FAF1EC]">
                          <button type="button" onClick={() => setFocusTarget({ lat: r.lat, lng: r.lng, ts: Date.now() })} title={t("map_around_show")} className="flex min-w-0 flex-1 items-center gap-2.5 text-left">
                            {r.photo ? (
                              // eslint-disable-next-line @next/next/no-img-element
                              <img src={r.photo} alt="" className="h-9 w-9 shrink-0 rounded-full object-cover" style={r.color ? { border: `2px solid ${r.color}` } : undefined} />
                            ) : r.pin ? (
                              <span className="grid h-9 w-9 shrink-0 place-items-center" dangerouslySetInnerHTML={{ __html: r.pin }} />
                            ) : (
                              <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full text-white" style={{ background: r.color || "#6E4F48" }}><AppIcon name="profile" size={16} color="#fff" /></span>
                            )}
                            <span className="min-w-0">
                              <span className="flex min-w-0 items-center gap-1.5"><span className="truncate text-sm font-semibold text-[#231715]">{r.title}</span>{r.friend && <span className="shrink-0 rounded-full bg-[#FDE7F0] px-1.5 py-px text-[10px] font-bold text-[#9D174D]">{t("map_friend_badge")}</span>}</span>
                              {r.sub && <span className="block truncate text-xs font-semibold" style={{ color: r.color ? ROLE_TEXT_DARK[r.color] || r.color : "#6E4F48" }}>{r.sub}</span>}
                              <span className="block truncate text-[11px] text-[#8A6B64]">{formatKm(r.km, lang)}{r.meta ? ` · ${r.meta}` : ""}</span>
                            </span>
                          </button>
                          {r.book ? (
                            <a href={r.book} className="grid h-9 w-9 shrink-0 place-items-center rounded-full text-white" style={{ background: r.color }} title={t("map_member_book")} aria-label={t("map_member_book")}><AppIcon name="calendar" size={16} color="#fff" /></a>
                          ) : (
                            <button type="button" onClick={() => handleDirections({ lat: r.lat, lng: r.lng })} title={t("map_directions_btn")} aria-label={t("map_directions_btn")} className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-owner text-white transition hover:bg-owner-dark"><AppIcon name="route" size={16} color="#fff" /></button>
                          )}
                        </li>
                      ))}
                    </ul>
                  )}
                </div>
              );
            })()}

            {/* AUTOUR DE TOI : 6 lieux les plus proches. */}
            {!noneSelected && (() => {
              const from = userLocation ?? { lat: center[0], lng: center[1] };
              const near = visiblePois.map((p) => { const [lng, lat] = p.location.coordinates; return { p, km: haversineKm(from.lat, from.lng, lat, lng) }; }).sort((a, b) => a.km - b.km).slice(0, 6);
              return (
                <div id="around-list" className="mt-3 scroll-mt-24 rounded-2xl bg-white p-3">
                  <div className="flex items-center gap-2">
                    <span className="grid h-8 w-8 place-items-center rounded-full bg-[#8B5CF6] text-white"><AppIcon name="locate" size={16} color="#fff" /></span>
                    <h2 className="font-display text-base font-bold text-[#231715]">{t("map_around_title")}</h2>
                  </div>
                  <p className="mt-1 text-xs text-[#6E4F48]">{t("map_around_sub")}</p>
                  <ModePicker mode={routeMode} onChange={setRouteMode} label={t("map_route_mode_label")} labels={{ walk: t("map_route_mode_walk"), bike: t("map_route_mode_bike"), car: t("map_route_mode_car") }} />
                  {near.length === 0 ? (
                    <p className="mt-3 text-sm text-[#6E4F48]">{t("map_around_empty")}</p>
                  ) : (
                    <ul className="mt-3 space-y-1.5">
                      {near.map(({ p, km }) => {
                        const st = p.openingHours ? formatOpenStatus(p.openingHours) : null;
                        const [lng, lat] = p.location.coordinates;
                        const active = selectedPoi?._id === p._id;
                        return (
                          <li key={`near-${p._id}`} className={`flex items-center gap-2.5 rounded-xl p-2 transition ${active ? "bg-owner-light" : "bg-[#FDF8F7] hover:bg-[#FAF1EC]"}`}>
                            <button type="button" onClick={() => { setSelectedPoi(p); setFocusTarget({ lat, lng, ts: Date.now() }); }} title={t("map_around_show")} className="flex min-w-0 flex-1 items-center gap-2.5 text-left">
                              <span className="grid h-9 w-9 shrink-0 place-items-center" dangerouslySetInnerHTML={{ __html: placePinHtml(p.category, 22) }} />
                              <span className="min-w-0">
                                <span className="block truncate text-sm font-semibold text-[#231715]">{p.title}</span>
                                <span className="block truncate text-xs text-[#6E4F48]">
                                  {km < 1 ? `${Math.round(km * 1000)} m` : `${km.toFixed(1)} km`}
                                  {st && <>{" · "}<span className={st.open ? "text-[#0F7C37]" : "text-[#B42318]"}>{st.label}</span></>}
                                </span>
                              </span>
                            </button>
                            <button type="button" onClick={() => handleDirections({ lat, lng })} title={t("map_directions_btn")} aria-label={t("map_directions_btn")} className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-owner text-white transition hover:bg-owner-dark"><AppIcon name="route" size={16} color="#fff" /></button>
                          </li>
                        );
                      })}
                    </ul>
                  )}
                </div>
              );
            })()}

            {/* Détails du lieu sélectionné. */}
            {selectedPoi && (
              <div className="mt-3 rounded-2xl bg-white p-3">
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <div className="text-xs font-semibold uppercase tracking-wider text-[#6E4F48]">{t(CAT_KEY_FOR_LANG[selectedPoi.category])}</div>
                    <h2 className="mt-1 text-base font-bold text-ink">{selectedPoi.title}</h2>
                    {selectedPoi.address && <p className="mt-1 text-sm text-[#6E4F48]">{selectedPoi.address}</p>}
                  </div>
                  <button type="button" onClick={() => setSelectedPoi(null)} className="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-[#FAF1EC] text-[#231715]" aria-label={t("map_close")}>×</button>
                </div>
                {selectedPoi.description && <p className="mt-2 text-sm text-[#6E4F48]">{selectedPoi.description}</p>}
                <div className="mt-2 flex flex-wrap gap-2 text-xs">
                  {selectedPoi.phone && <a href={`tel:${selectedPoi.phone}`} className="inline-flex items-center gap-1 rounded-full bg-[#FAF1EC] px-3 py-1 font-medium text-ink"><AppIcon name="phone" size={13} />{selectedPoi.phone}</a>}
                  {selectedPoi.website && <a href={selectedPoi.website} target="_blank" rel="noopener noreferrer" className="rounded-full bg-[#FAF1EC] px-3 py-1 font-medium text-ink">{t("map_website_action")}</a>}
                  {selectedPoi.openingHours && <span className="inline-flex items-center gap-1 rounded-full bg-[#FAF1EC] px-3 py-1 text-[#6E4F48]"><AppIcon name="clock" size={13} />{selectedPoi.openingHours}</span>}
                </div>
                {selectedPoi.rating && selectedPoi.rating > 0 && (
                  <div className="mt-2 text-sm"><span className="font-bold text-[#B8860B]">★ {selectedPoi.rating.toFixed(1)}</span>{selectedPoi.reviewsCount ? <span className="ml-1 text-[#6E4F48]">{t("map_reviews_count").replace("{count}", String(selectedPoi.reviewsCount))}</span> : null}</div>
                )}
              </div>
            )}

            <p className="mt-3 text-[11px] leading-snug text-[#8A6B64]">{t("map_legend")}</p>
          </div>
        </aside>
      </div>

      {/* Modal de création Tag spot / Signaler (position = centre de la carte). */}
      {createKind && (
        <div className="fixed inset-x-0 bottom-0 z-[2000] flex justify-center p-4">
          <div className="w-full max-w-sm rounded-2xl bg-white p-5 shadow-2xl">
            <h3 className="font-display text-lg font-semibold text-[#231715]">{createKind === "spot" ? t("map_tag_spot_cta") : t("map_report_cta")}</h3>
            <p className="mt-1 text-xs text-[#6E4F48]">{t("map_create_center_hint")}</p>
            <label className="mt-3 block text-xs font-semibold text-[#6E4F48]">{t("map_type_label")}</label>
            <SelectMenu
              className="mt-1"
              ariaLabel={t("map_type_label")}
              value={createType}
              onChange={setCreateType}
              tone={roleKey(myRole)}
              options={createKind === "spot" ? spotOptions.map((tp) => ({ value: tp, label: spotTypeLabels[tp] })) : reportOptions.map((tp) => ({ value: tp, label: reportTypeLabels[tp] || tp }))}
            />
            {createKind === "spot" && (
              <>
                <input value={createName} onChange={(e) => setCreateName(e.target.value)} placeholder={t("map_spot_name_ph")} maxLength={80} className="mt-3 w-full rounded-xl border border-[#EADFDC] px-3 py-2 text-sm" />
                <label className="mt-3 block text-xs font-semibold text-[#6E4F48]">{t("map_spot_photo_label")}</label>
                <input ref={photoInputRef} type="file" accept="image/*" className="hidden" onChange={(e) => { const f = e.target.files?.[0] || null; setCreatePhoto(f); setCreatePhotoPreview(f ? URL.createObjectURL(f) : null); }} />
                <button type="button" onClick={() => photoInputRef.current?.click()} className="mt-1 flex w-full items-center gap-3 rounded-xl border border-dashed border-[#D6C3BE] bg-[#FAF1EC] px-3 py-2 text-left text-xs text-[#6E4F48] transition hover:bg-owner-light">
                  {createPhotoPreview ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={createPhotoPreview} alt="" className="h-12 w-12 shrink-0 rounded-lg object-cover" />
                  ) : (
                    <span className="grid h-12 w-12 shrink-0 place-items-center rounded-lg bg-white text-[#C92A12]"><AppIcon name="download" size={20} /></span>
                  )}
                  <span>{createPhoto ? createPhoto.name : t("map_spot_photo_hint")}</span>
                </button>
              </>
            )}
            <textarea value={createNote} onChange={(e) => setCreateNote(e.target.value)} placeholder={t("map_note_ph")} maxLength={300} rows={2} className="mt-3 w-full rounded-xl border border-[#EADFDC] px-3 py-2 text-sm" />
            {createErr && <p className="mt-2 text-xs font-semibold text-[#B42318]">{createErr}</p>}
            <div className="mt-4 flex justify-end gap-2">
              <button type="button" onClick={() => setCreateKind(null)} disabled={creating} className="rounded-full px-4 py-2 text-sm font-semibold text-[#6E4F48] hover:bg-[#FAF1EC]">{t("map_create_cancel")}</button>
              <button type="button" onClick={submitCreate} disabled={creating} className="rounded-full bg-owner px-5 py-2 text-sm font-bold text-white shadow-sm transition hover:bg-owner-dark disabled:opacity-60">{uploadingPhoto ? t("map_uploading") : creating ? "…" : t("map_create_submit")}</button>
            </div>
          </div>
        </div>
      )}

      {/* 25/09 (587) — lueur verte qui respire de la pilule « En direct » (fixe si « réduire les animations »). */}
      <style>{`@keyframes hps-live-breathe{0%,100%{box-shadow:0 0 0 3px rgba(22,163,74,.28),0 0 14px 3px rgba(22,163,74,.45)}50%{box-shadow:0 0 0 6px rgba(22,163,74,.22),0 0 26px 9px rgba(22,163,74,.62)}}.hps-live-breathe{animation:hps-live-breathe 1.6s ease-in-out infinite}@media (prefers-reduced-motion: reduce){.hps-live-breathe{animation:none}}`}</style>
      <PawMapLegendModal open={legendOpen} onClose={() => setLegendOpen(false)} role={roleKey(myRole)} />
      {/* 26/09 (589) — fenêtre d'annonce (une fois par navigateur). */}
      <PawMapAnnouncement enabled={!loading} dark={dark} />
      {/* 25/09 (586, point 2) — le site n'émet pas de position GPS en direct :
          le rond « Direct » explique qu'il se lance depuis l'app. */}
      {liveInfoOpen && (
        <div className="fixed inset-0 z-[3000] flex items-end justify-center bg-[#231715]/55 sm:items-center sm:p-4" role="dialog" aria-modal="true" aria-labelledby="live-info-title" onClick={() => setLiveInfoOpen(false)}>
          <div className="w-full max-w-md rounded-t-[28px] bg-white p-5 shadow-2xl sm:rounded-[28px] sm:p-7" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-start gap-3">
              <span className="grid h-12 w-12 shrink-0 place-items-center rounded-full" style={myLive.on ? { background: "linear-gradient(165deg,#22C55E,#16A34A 55%,#15803D)", boxShadow: "0 6px 14px -6px #16A34A" } : { background: "linear-gradient(165deg,#2C2533,#17141F)", boxShadow: "0 6px 14px -6px rgba(23,20,31,0.7)" }}><LiveIcon size={22} /></span>
              <div className="min-w-0 flex-1">
                <h2 id="live-info-title" className="font-display text-lg font-bold leading-snug tracking-[-0.01em] text-[#231715]">{t(myLive.on ? "m587_live_on_title" : "m587_live_app_title")}</h2>
                <p className="mt-1.5 text-sm leading-relaxed text-[#6E4F48]">{t(myLive.on ? "m587_live_on_body" : "m586_live_app_body")}</p>
              </div>
            </div>
            <StoreBadges center className="mt-5" />
            <button type="button" onClick={() => setLiveInfoOpen(false)} className="mt-5 inline-flex min-h-[48px] w-full items-center justify-center rounded-[18px] px-5 text-sm font-bold" style={{ color: ROLE_TEXT_DARK[roleColor] || "#231715", boxShadow: `inset 0 0 0 1.5px ${roleColor}` }}>
              {t("common_close")}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

function CategoryChip({ label, pinHtml, active, onClick }: { label: string; pinHtml?: string; active: boolean; onClick: () => void }) {
  return (
    <button type="button" onClick={onClick} aria-pressed={active} className={`inline-flex min-h-[32px] items-center gap-1.5 rounded-full px-2.5 text-xs font-semibold transition ${active ? "bg-owner-light text-owner-dark" : "bg-[#FAF1EC] text-[#231715] hover:bg-[#F0E3DF]"}`}>
      {pinHtml ? <span className="grid h-5 w-4 place-items-center" dangerouslySetInnerHTML={{ __html: pinHtml }} /> : null}
      <span>{label}</span>
    </button>
  );
}

/** v562 — icônes du rail, identiques à celles de l'app (`_fabSvg*` de paw_map_screen.dart). */
const RAIL_SVG = {
  around: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#FFFFFF"><path d="M12 22s-7.5-6.5-7.5-12A7.5 7.5 0 0 1 19.5 10c0 5.5-7.5 12-7.5 12z"/><g fill="rgba(0,0,0,.34)"><circle cx="10.2" cy="7.2" r="1.1"/><circle cx="13.8" cy="7.2" r="1.1"/><circle cx="8.4" cy="9.4" r="1"/><circle cx="15.6" cy="9.4" r="1"/><path d="M12 9.3c-1.7 0-3.3 1.6-3.3 3.1 0 .9.8 1.7 1.7 1.7.6 0 1.1-.3 1.6-.3s1 .3 1.6.3c.9 0 1.7-.8 1.7-1.7 0-1.5-1.6-3.1-3.3-3.1z"/></g></svg>',
  route: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 18c0-5 3-6 6-6s6-1 6-6" stroke-dasharray="3 2.6"/><circle cx="6" cy="18" r="2.6" fill="#FFFFFF" stroke="none"/><path d="M18 2.5c-1.8 0-3.2 1.4-3.2 3.2 0 2.2 3.2 5.3 3.2 5.3s3.2-3.1 3.2-5.3c0-1.8-1.4-3.2-3.2-3.2z" fill="#FFFFFF" stroke="none"/></svg>',
  chat: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#FFFFFF"><path d="M12 3C6.9 3 3 6.3 3 10.4c0 2 1 3.9 2.6 5.2L4.8 20l4.6-1.9c.8.2 1.7.3 2.6.3 5.1 0 9-3.3 9-7.4S17.1 3 12 3z"/><g fill="rgba(0,0,0,.34)"><circle cx="8.6" cy="10.6" r="1.1"/><circle cx="12" cy="10.6" r="1.1"/><circle cx="15.4" cy="10.6" r="1.1"/></g></svg>',
  photo: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#FFFFFF"><path d="M9 4h6l1.4 2.2H20a1.6 1.6 0 0 1 1.6 1.6V18A1.6 1.6 0 0 1 20 19.6H4A1.6 1.6 0 0 1 2.4 18V7.8A1.6 1.6 0 0 1 4 6.2h3.6z"/><circle cx="12" cy="12.8" r="3.6" fill="rgba(0,0,0,.34)"/></svg>',
  spot: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#FFFFFF"><path d="M12 22s-7.5-6.5-7.5-12A7.5 7.5 0 0 1 19.5 10c0 5.5-7.5 12-7.5 12z"/><path d="M12 5.4l1.4 2.9 3.1.4-2.3 2.2.6 3.1L12 12.5 9.2 14l.6-3.1-2.3-2.2 3.1-.4z" fill="rgba(0,0,0,.34)"/></svg>',
  add: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#FFFFFF"><path d="M12 22s-7.5-6.5-7.5-12A7.5 7.5 0 0 1 19.5 10c0 5.5-7.5 12-7.5 12z"/><path d="M10.9 6h2.2v2.9H16v2.2h-2.9V14h-2.2v-2.9H8V8.9h2.9z" fill="rgba(0,0,0,.34)"/></svg>',
  report: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#FFFFFF"><path d="M12 2.8 22.6 21H1.4z"/><path d="M10.9 9h2.2v6h-2.2zM10.9 16.5h2.2v2.2h-2.2z" fill="rgba(0,0,0,.4)"/></svg>',
  feed: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#FFFFFF"><path d="M5 2.5h2.2V21.5H5z"/><path d="M7.2 3.5h11.3l-2.4 4.5 2.4 4.5H7.2z"/><circle cx="18.5" cy="5" r="3.6" fill="#E24834" stroke="#fff" stroke-width="1.4"/></svg>',
} as const;

/** v562 — choix à pied / vélo / voiture, partagé par toutes les listes. */
function ModePicker({ mode, onChange, label, labels }: { mode: RouteMode; onChange: (m: RouteMode) => void; label: string; labels: Record<RouteMode, string> }) {
  const colors: Record<RouteMode, string> = { walk: "#C92A12", bike: "#16A34A", car: "#2563EB" };
  const icons: Record<RouteMode, AppIconName> = { walk: "walker", bike: "route", car: "pin" };
  return (
    <div className="mt-2 flex flex-wrap items-center gap-1.5">
      {label && <span className="mr-1 text-xs font-semibold text-[#6E4F48]">{label}</span>}
      {(["walk", "bike", "car"] as RouteMode[]).map((m) => (
        <button key={m} type="button" aria-pressed={mode === m} onClick={() => onChange(m)} className="inline-flex min-h-[30px] items-center gap-1 rounded-full px-2.5 text-xs font-bold transition" style={{ backgroundColor: mode === m ? colors[m] : `${colors[m]}1a`, color: mode === m ? "#fff" : colors[m] }}>
          <AppIcon name={icons[m]} size={13} color={mode === m ? "#fff" : colors[m]} />
          {labels[m]}
        </button>
      ))}
    </div>
  );
}

// 25/09 (587, point 6) — un ami qui NE partage PAS est posé à sa position de
// PROFIL (couche monde, floutée ~1 km, comme l'app), jamais à la position
// exacte de la couche « proches » (dernier GPS d'ouverture de l'app ou
// centre-ville). S'il n'est pas dans la couche monde : même floutage ~1 km
// sur place. Son direct, lui, remplace ce point (PoiMap, tous ses ids).
function placeFriendsAtProfile(list: NearbyMember[], world: NearbyMember[], friendIds: Set<string>): NearbyMember[] {
  const worldById = new Map<string, NearbyMember>();
  for (const w of world || []) for (const x of personIdsOf(w)) worldById.set(x, w);
  return list.map((m) => {
    if (!isFriendMember(m, friendIds) || m.approx) return m;
    const w = personIdsOf(m).map((x) => worldById.get(x)).find(Boolean);
    if (w && Array.isArray(w.location?.coordinates)) {
      return { ...m, location: { ...(m.location || {}), coordinates: w.location!.coordinates }, approx: true, approxKm: w.approxKm ?? 1 } as NearbyMember;
    }
    const c = m.location?.coordinates;
    if (!Array.isArray(c) || c.length < 2) return m;
    const [blat, blng] = blurLatLng(c[1], c[0], String(m.id));
    return { ...m, location: { ...(m.location || {}), coordinates: [blng, blat] }, approx: true, approxKm: 1 } as NearbyMember;
  });
}

// 25/09 (PawMap 584) — même règle que backend/src/utils/liveState.js,
// recalculée ici à chaque tic : `live` (partage actif, < 2 min), `lost`
// (2-10 min, « signal perdu »), `seen` (rien de direct). Compatible avec le
// serveur v583 qui n'envoie pas encore `sharing` / `state` : on se fie alors
// à l'âge du dernier signal.
function liveStateOf(
  p: { lastSeenAt?: string | null; at?: string | null; sharing?: boolean; state?: string },
  now: number,
): "live" | "lost" | "seen" {
  if (p.sharing === false || p.state === "seen") return "seen";
  const ref = p.lastSeenAt || p.at;
  if (!ref) return "seen";
  const tms = new Date(ref).getTime();
  if (!Number.isFinite(tms)) return "seen";
  const age = now - tms;
  if (age <= 2 * 60 * 1000) return "live";
  if (age <= 10 * 60 * 1000) return "lost";
  return "seen";
}

/** « 12 s », « 4 min », « 3 h », « 2 j » dans la langue choisie. */
function formatAgo(ms: number, t: (k: string) => string): string {
  const s = Math.max(0, Math.round(ms / 1000));
  if (s < 60) return t("ago_s").replace("{n}", String(s));
  const m = Math.round(s / 60);
  if (m < 60) return t("ago_min").replace("{n}", String(m));
  const h = Math.round(m / 60);
  if (h < 48) return t("ago_h").replace("{n}", String(h));
  return t("ago_d").replace("{n}", String(Math.round(h / 24)));
}

// ── 25/09/2026 (PawMap 585) — verre des rails ────────────────────────────────
// Blanc CHAUD très translucide + liseré blanc fin + ombre teintée (brun
// ambré, jamais grise) ; mode nuit : encre foncée chaude, jamais du gris.
function glassStyle(dark: boolean): React.CSSProperties {
  return dark
    ? {
        background: "linear-gradient(180deg, rgba(44,33,42,0.82), rgba(23,20,31,0.78))",
        border: "1px solid rgba(255,228,214,0.22)",
        boxShadow: "0 16px 36px -12px rgba(12,6,4,0.7), inset 0 1px 0 rgba(255,228,214,0.14)",
        backdropFilter: "blur(14px) saturate(1.4)",
        WebkitBackdropFilter: "blur(14px) saturate(1.4)",
      }
    : {
        // Assez opaque pour rester CHAUD même sur la vue satellite (sinon le
        // flou d'une photo sombre donne un verre gris).
        background: "linear-gradient(180deg, rgba(255,251,247,0.86), rgba(255,242,232,0.78))",
        border: "1px solid rgba(255,255,255,0.95)",
        boxShadow: "0 16px 34px -14px rgba(146,64,14,0.45), inset 0 1px 0 rgba(255,255,255,0.95)",
        backdropFilter: "blur(14px) saturate(1.5)",
        WebkitBackdropFilter: "blur(14px) saturate(1.5)",
      };
}
const ROLE_GRAD_BTN: Record<string, string> = {
  owner: "linear-gradient(165deg,#E0553F,#B92425)",
  sitter: "linear-gradient(165deg,#3B7BE6,#1E4FB0)",
  walker: "linear-gradient(165deg,#34B857,#15803D)",
};
/**
 * 26/09 (589) — rond orange SIGNATURE de l'en-tête de la carte (« ? »,
 * Actualiser, roue Options) : dégradé #E2503A → #D83C28 → #B92425, liseré
 * blanc, reflet, icône blanche — le même que l'app (_headerRoundButton).
 */
function OrangeRound({ onClick, label, busy, children }: { onClick: () => void; label: string; busy?: boolean; children: React.ReactNode }) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={label}
      title={label}
      aria-busy={busy || undefined}
      className="relative grid h-11 w-11 place-items-center overflow-hidden rounded-full transition-transform duration-200 hover:scale-[1.05] active:scale-95"
      style={{ background: "linear-gradient(165deg,#E2503A 0%,#D83C28 50%,#B92425 100%)", border: "1.5px solid #FFFFFF", boxShadow: "0 8px 18px -8px rgba(185,36,37,0.85)" }}
    >
      <span aria-hidden="true" className="pointer-events-none absolute inset-x-[5px] top-[2px] h-[46%] rounded-full" style={{ background: "linear-gradient(180deg, rgba(255,255,255,0.45), rgba(255,255,255,0))" }} />
      <span className="relative grid place-items-center">{children}</span>
    </button>
  );
}
/** 26/09 (589) — roue « réglages » pleine, style iPhone (8 dents, moyeu creux). */
function GearIcon({ size = 22, color = "#FFFFFF" }: { size?: number; color?: string }) {
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} aria-hidden="true">
      <path
        fill={color}
        fillRule="evenodd"
        d="M10.3 2.2h3.4l.5 2.5c.6.2 1.2.5 1.7.8l2.2-1.3 2.4 2.4-1.3 2.2c.3.5.6 1.1.8 1.7l2.5.5v3.4l-2.5.5c-.2.6-.5 1.2-.8 1.7l1.3 2.2-2.4 2.4-2.2-1.3c-.5.3-1.1.6-1.7.8l-.5 2.5h-3.4l-.5-2.5c-.6-.2-1.2-.5-1.7-.8l-2.2 1.3-2.4-2.4 1.3-2.2c-.3-.5-.6-1.1-.8-1.7l-2.5-.5v-3.4l2.5-.5c.2-.6.5-1.2.8-1.7L3.5 6.6l2.4-2.4 2.2 1.3c.5-.3 1.1-.6 1.7-.8zM12 8.4a3.6 3.6 0 1 0 0 7.2 3.6 3.6 0 0 0 0-7.2z"
      />
    </svg>
  );
}
/** Barre rangée hors écran : ni focus clavier ni lecteur d'écran (React 18 : `inert` en attribut texte). */
function inertIf(on: boolean): Record<string, string> {
  return on ? { inert: "", "aria-hidden": "true" } : {};
}
/**
 * 25/09 (587, point 3) — languette de repli d'une barre : petite flèche en
 * verre teinté au bord INTÉRIEUR de la barre (elle suit la barre quand elle
 * glisse et reste seule visible au bord de l'écran). Zone tactile 44 × 48.
 */
function BarTab({ side, collapsed, dark, label, onClick, className = "" }: { side: "left" | "right"; collapsed: boolean; dark: boolean; label: string; onClick: () => void; className?: string }) {
  // Barre gauche : « < » la range, « > » la ramène ; barre droite : l'inverse.
  const pointLeft = side === "left" ? !collapsed : collapsed;
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={label}
      title={label}
      aria-expanded={!collapsed}
      className={`absolute bottom-1 grid h-12 w-11 ${side === "left" ? "left-full justify-items-start pl-1" : "right-full justify-items-end pr-1"} items-center ${className}`}
    >
      <span className="grid h-11 w-6 place-items-center rounded-[12px] transition-transform duration-200 hover:scale-[1.06] active:scale-95" style={glassStyle(dark)}>
        <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke={dark ? "#FBEFE6" : "#3B2A26"} strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <path d={pointLeft ? "M14 7l-5 5 5 5" : "M10 7l5 5-5 5"} />
        </svg>
      </span>
    </button>
  );
}
/** Bouton de la capsule droite : icône à l'encre chaude, actif = teinte du rôle. */
function CapsuleBtn({ dark, label, onClick, pressed, accent, children }: { dark: boolean; label: string; onClick: () => void; pressed?: boolean; accent?: string; children: React.ReactNode }) {
  const on = pressed && accent;
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={label}
      title={label}
      aria-pressed={pressed}
      className="grid h-11 w-11 place-items-center rounded-full transition duration-200 hover:scale-[1.05] active:scale-95"
      style={{
        color: on ? ROLE_ON_FG[accent!] || "#3B2A26" : dark ? "#FBEFE6" : "#3B2A26",
        background: on ? ROLE_ON_BG[accent!] || "#FBE9E5" : "transparent",
        boxShadow: on ? "inset 0 0 0 1.5px #FFFFFF" : undefined,
      }}
    >
      {children}
    </button>
  );
}
// État « actif » d'un interrupteur de la capsule : teinte PLEINE et claire du
// rôle + icône dans le foncé du rôle (clé = couleur du rôle).
const ROLE_ON_BG: Record<string, string> = { "#C92A12": "#FBE3DC", "#2563EB": "#DCE8FD", "#16A34A": "#D9F5E3" };
const ROLE_TEXT_DARK: Record<string, string> = { "#C92A12": "#9E1F0B", "#2563EB": "#1E4FB0", "#16A34A": "#15803D" };
const ROLE_ON_FG: Record<string, string> = { "#C92A12": "#9E1F0B", "#2563EB": "#1E4FB0", "#16A34A": "#15803D" };
/** Séparateur à peine visible (teinte chaude pleine : pas de gris). */
function CapsuleSep({ dark }: { dark: boolean }) {
  return <span aria-hidden="true" className="my-[3px] block h-px w-6" style={{ background: dark ? "#4A3A40" : "#EBD7CC" }} />;
}

/** 25/09 (586) — icône « Direct » : point central + ondes. */
function LiveIcon({ size = 21 }: { size?: number }) {
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} fill="none" stroke="#FFFFFF" strokeWidth="2.2" strokeLinecap="round" aria-hidden="true">
      <circle cx="12" cy="12" r="2.6" fill="#FFFFFF" stroke="none" />
      <path d="M8.2 8.2a5.4 5.4 0 0 0 0 7.6M15.8 8.2a5.4 5.4 0 0 1 0 7.6M5.3 5.3a9.5 9.5 0 0 0 0 13.4M18.7 5.3a9.5 9.5 0 0 1 0 13.4" />
    </svg>
  );
}
