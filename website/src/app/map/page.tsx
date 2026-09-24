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
import { evaluateOpeningHours } from "@/lib/openingHours";
import type { RouteMode } from "@/lib/api";
import BackLink from "@/components/BackLink";
import { PawMapLogo } from "@/components/PawMapLogo";
import { AppIcon, type AppIconName } from "@/components/AppIcon";
import { PageTitle } from "@/components/PageTitle";
import { PawMapLegendModal } from "@/components/PawMapLegendModal";
import type { MapRequest } from "@/components/PoiMap";
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
  getFriendLastPosition,
  getFriendsLivePositions,
  getMyBenefits,
  getMyFamily,
  getMyFriends,
  getMyPosts,
  getNearbyMembers,
  getRequestPosts,
  getWorldMembers,
  sendFriendRequest,
  setHideFromMap,
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
  // 24/09 — mode « visible par mes amis seulement » (preferences.hideFromMap).
  const [friendsOnly, setFriendsOnly] = useState(false);
  const [friendsOnlyBusy, setFriendsOnlyBusy] = useState(false);
  const [friendsOnlyMsg, setFriendsOnlyMsg] = useState<string | null>(null);
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
        setFriendsOnly(p?.preferences?.hideFromMap === true);
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
  const [showFriends, setShowFriends] = useState(false);
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
  const [followUserId, setFollowUserId] = useState<string | null>(null);
  const [followPaused, setFollowPaused] = useState(false);
  const [sheet, setSheet] = useState<"peek" | "half" | "full">("peek");
  const [showRequests, setShowRequests] = useState(true);
  const [requests, setRequests] = useState<MapRequest[]>([]);
  const [catsOpen, setCatsOpen] = useState(false);

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

  const { connected: socketConnected } = useSocket();
  useEffect(() => {
    if (!socketConnected) return;
    const me = getStoredUser();
    if (!me) return;
    getSocket()?.emit("map:identify", { userId: me.id, role: me.role });
  }, [socketConnected]);
  const { presence, resolveOnline } = usePresence();

  const friendByUserId = useMemo(() => {
    const m = new Map<string, FriendItem>();
    for (const f of friendsForMap) if (f.other?.id) m.set(f.other.id, f);
    return m;
  }, [friendsForMap]);

  useSocketEvent<{ userId: string; role: string; lat: number; lng: number; at?: string }>("map:friend-position", (data) => {
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
        isOnline: prev.get(data.userId)?.isOnline ?? friend?.isOnline ?? friend?.other?.isOnline ?? true,
      });
      return next;
    });
  });
  useSocketEvent<{ userId: string }>("map:friend-offline", (data) => {
    setLivePositions((prev) => {
      if (!prev.has(data.userId)) return prev;
      const next = new Map(prev);
      next.delete(data.userId);
      return next;
    });
  });

  const [myRole, setMyRole] = useState<string>("sitter");
  const [focusTarget, setFocusTarget] = useState<{ lat: number; lng: number; ts: number } | null>(null);
  const [locating, setLocating] = useState(false);
  const [locateMsg, setLocateMsg] = useState<string | null>(null);
  const [cityQuery, setCityQuery] = useState("");
  const [citySearching, setCitySearching] = useState(false);
  const [cityError, setCityError] = useState(false);
  async function handleCitySearch(e: React.FormEvent) {
    e.preventDefault();
    const q = cityQuery.trim();
    if (!q || citySearching) return;
    setCitySearching(true);
    setCityError(false);
    try {
      const resp = await fetch(`https://nominatim.openstreetmap.org/search?format=json&limit=1&accept-language=${encodeURIComponent(typeof navigator !== "undefined" ? navigator.language : "fr")}&q=${encodeURIComponent(q)}`);
      const results = (await resp.json()) as { lat: string; lon: string }[];
      const hit = results?.[0];
      if (hit && Number.isFinite(parseFloat(hit.lat))) {
        const lat = parseFloat(hit.lat);
        const lng = parseFloat(hit.lon);
        setCenter([lat, lng]);
        try { window.localStorage.setItem("hopetsit:lastMapCenter", JSON.stringify({ lat, lng })); } catch {/* ignore */}
      } else {
        setCityError(true);
      }
    } catch {
      setCityError(true);
    } finally {
      setCitySearching(false);
    }
  }

  // Auth + géolocalisation au mount.
  useEffect(() => {
    const me = getStoredUser();
    if (!me) {
      router.replace("/login");
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
            setCenter([loc.lat, loc.lng]);
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
  }, [loading, fetchPois, center]);

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
  }, [loading, showSpots, center, router]);

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
  }, [loading, showReports, center, router]);

  const membersSubscribed = !!(benefits?.pawspotActive || benefits?.premiumActive || benefits?.isPremium);
  useEffect(() => {
    if (loading || !membersSubscribed) { setMembers([]); return; }
    const tid = setTimeout(async () => {
      try {
        setMembers(await getNearbyMembers({ lat: center[0], lng: center[1], radiusInMeters: 25000 }));
      } catch (e) {
        if (e instanceof ApiError && e.status === 401) router.replace("/login");
      }
    }, 400);
    return () => clearTimeout(tid);
  }, [loading, membersSubscribed, center, router]);

  useEffect(() => {
    if (loading) return;
    let cancelled = false;
    getWorldMembers().then((list) => { if (!cancelled) setWorldMembers(list); }).catch(() => {});
    return () => { cancelled = true; };
  }, [loading]);

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
            priceLabel: formatPrice(p.budget ?? null, p.currency),
            mine: !isProviderRole,
            boosted: p.isOwnerBoosted === true,
            body: p.body || p.notes || "",
            city: p.location?.city || p.location?.label || "",
          });
        }
        setRequests(out);
      } catch { /* couche vide, la carte reste utilisable */ }
    })();
    return () => { cancelled = true; };
  }, [loading, showRequests, isProviderRole]);

  const allMembers = useMemo(() => {
    const seen = new Set(members.map((m) => m.id));
    const merged = [...members, ...worldMembers.filter((m) => !seen.has(m.id))];
    return merged.filter((m) => (m.role ? memberRoles.includes(String(m.role).toLowerCase()) : true));
  }, [members, worldMembers, memberRoles]);

  // Membres à moins de 50 km (même règle que l'app) — liste + compteur.
  const membersNear = useMemo(() => {
    const ref = userLocation ?? { lat: center[0], lng: center[1] };
    return allMembers
      .map((m) => {
        const lat = m.location?.coordinates?.[1];
        const lng = m.location?.coordinates?.[0];
        if (typeof lat !== "number" || typeof lng !== "number") return null;
        return { m, km: haversineKm(ref.lat, ref.lng, lat, lng), lat, lng };
      })
      .filter((x): x is { m: NearbyMember; km: number; lat: number; lng: number } => !!x && x.km <= 50)
      .sort((a, b) => a.km - b.km);
  }, [allMembers, userLocation, center]);
  const membersAround = membersNear.length;

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

      const infoById = new Map<string, { role: "walker" | "sitter" | "owner"; name: string; avatar: string }>();
      for (const f of accepted) {
        if (!f.other?.id) continue;
        infoById.set(f.other.id, { role: roleFromModel(f.other.model), name: f.other.name || t("common_friend"), avatar: f.other.avatar || "" });
      }
      for (const m of allFamily) {
        if (!m.id || infoById.has(m.id)) continue;
        infoById.set(m.id, { role: roleFromModel(m.role), name: m.name || t("common_family"), avatar: m.avatar || "" });
      }
      const bulk = await getFriendsLivePositions();
      const bulkRows: FriendLivePosition[] = [];
      const seen = new Set<string>();
      for (const b of bulk) {
        if (b.lat == null || b.lng == null) continue;
        const info = infoById.get(b.userId);
        seen.add(b.userId);
        bulkRows.push({ userId: b.userId, role: roleFromModel(info ? info.role : b.role), name: info?.name || t("common_friend"), avatar: info?.avatar, lat: b.lat, lng: b.lng, at: b.at || new Date().toISOString() });
      }
      const idArr = Array.from(infoById.keys()).filter((id) => !seen.has(id));
      const posResults: (FriendLivePosition | null)[] = await Promise.all(
        idArr.map(async (id): Promise<FriendLivePosition | null> => {
          try {
            const p = await getFriendLastPosition(id);
            if (!p || p.lat == null || p.lng == null) return null;
            const info = infoById.get(id);
            if (!info) return null;
            return { userId: id, role: info.role, name: info.name, avatar: info.avatar, lat: p.lat, lng: p.lng, at: new Date().toISOString() };
          } catch {
            return null;
          }
        }),
      );
      setLivePositions((prev) => {
        const next = new Map(prev);
        for (const p of [...bulkRows, ...posResults]) if (p && !next.has(p.userId)) next.set(p.userId, p);
        return next;
      });
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) { router.replace("/login"); return; }
    } finally {
      setFriendsLoading(false);
    }
  }, [router, t]);

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

  async function handleSpotVisit(id: string) {
    try {
      const vc = await visitSpot(id);
      setSpots((prev) => prev.map((s) => (s.id === id ? { ...s, visitsCount: vc } : s)));
    } catch { /* best-effort */ }
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
      const go = async (from: { lat: number; lng: number }) => {
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
      const fallback = userLocation ?? { lat: center[0], lng: center[1] };
      if (typeof navigator !== "undefined" && "geolocation" in navigator) {
        navigator.geolocation.getCurrentPosition((pos) => void go({ lat: pos.coords.latitude, lng: pos.coords.longitude }), () => void go(fallback), { timeout: 5000 });
      } else {
        void go(fallback);
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
  function toggleDark() {
    setDark((d) => {
      try { localStorage.setItem("hopetsit:mapDark", d ? "0" : "1"); } catch { /* ignore */ }
      return !d;
    });
  }
  async function toggleFriendsOnly(next: boolean) {
    if (friendsOnlyBusy) return;
    setFriendsOnlyBusy(true);
    try {
      const v = await setHideFromMap(next);
      setFriendsOnly(v);
      setFriendsOnlyMsg(v ? t("map_friends_only_done") : t("map_visible_all_done"));
      setTimeout(() => setFriendsOnlyMsg(null), 4000);
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) router.replace("/login");
    } finally {
      setFriendsOnlyBusy(false);
    }
  }
  function startFollow(p: FriendLivePosition) {
    setFocusTarget({ lat: p.lat, lng: p.lng, ts: Date.now() });
    setFollowUserId(p.userId);
    setFollowPaused(false);
  }

  const livePositionsList = useMemo(
    () => Array.from(livePositions.values()).map((p) => (presence.has(p.userId) ? { ...p, isOnline: !!presence.get(p.userId) } : p)),
    [livePositions, presence],
  );
  const membersWithPresence = useMemo(
    () => allMembers.map((m) => (m.approx ? m : { ...m, isOnline: resolveOnline(m.id, m.isOnline) })),
    [allMembers, resolveOnline],
  );
  const followed = followUserId ? livePositionsList.find((p) => p.userId === followUserId) : undefined;

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

  // « Je cherche » : une seule rangée (multi-sélection), les réglages fins restent en dessous.
  const seek: { k: string; icon: AppIconName; label: string; on: boolean; color: string; toggle: () => void }[] = [
    { k: "sitter", icon: "home", label: t("role_sitter"), on: memberRoles.includes("sitter"), color: ROLE_COLOR.sitter, toggle: () => toggleRole("sitter") },
    { k: "walker", icon: "walker", label: t("role_walker"), on: memberRoles.includes("walker"), color: ROLE_COLOR.walker, toggle: () => toggleRole("walker") },
    { k: "owner", icon: "paw", label: t("role_owner"), on: memberRoles.includes("owner"), color: ROLE_COLOR.owner, toggle: () => toggleRole("owner") },
    { k: "places", icon: "pin", label: t("map_seek_places"), on: !noneSelected, color: "#0F766E", toggle: () => { setNoneSelected((v) => !v); setSelectedCats([]); } },
    { k: "friends", icon: "friends", label: t("map_seek_friends"), on: showFriends, color: "#F06AA0", toggle: toggleFriendsLayer },
    { k: "requests", icon: "megaphone", label: t("map_seek_requests"), on: showRequests, color: ROLE_COLOR.owner, toggle: () => setShowRequests((v) => !v) },
  ];
  function toggleRole(role: string) {
    setMemberRoles((prev) => (prev.includes(role) ? (prev.length === 1 ? ["sitter", "walker", "owner"] : prev.filter((r) => r !== role)) : [...prev, role]));
  }

  const sheetH = sheet === "peek" ? "h-[58px]" : sheet === "half" ? "h-[50vh]" : "h-[86vh]";
  const cycleSheet = () => setSheet((s) => (s === "peek" ? "half" : s === "half" ? "full" : "peek"));

  return (
    <div className="mx-auto max-w-[1400px] px-4 pb-24 pt-5 md:pt-8 lg:pb-8">
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
          <button type="submit" disabled={citySearching || !cityQuery.trim()} className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-[#231715] text-white transition hover:bg-black disabled:cursor-not-allowed disabled:opacity-40" aria-label={t("map_search_city_btn")} title={t("map_search_city_btn")}>
            {citySearching ? <span className="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent" /> : <AppIcon name="search" size={18} color="#fff" />}
          </button>
        </form>
      </div>
      {cityError && <p className="mt-2 text-right text-xs font-semibold text-[#C92A12]">{t("map_search_city_none")}</p>}
      {error && <div className="mt-3 rounded-xl bg-[#FBE9E5] px-4 py-3 text-sm text-[#9E1F0B]">{error}</div>}

      {/* ── 2 COLONNES sur ordinateur : carte | panneau ── */}
      <div className="mt-4 lg:grid lg:grid-cols-[minmax(0,1fr)_380px] lg:gap-5">
        {/* ── COLONNE CARTE ── */}
        <div className="relative h-[62vh] min-h-[420px] lg:h-[calc(100vh-190px)] lg:min-h-[560px]">
          {/* Coin haut-gauche : « ? » légende, mode sombre. */}
          <div className="absolute left-3 top-3 z-[1000] flex flex-col gap-2">
            <button type="button" onClick={() => setLegendOpen(true)} aria-label={t("legend_btn")} title={t("legend_btn")} className="grid h-11 w-11 place-items-center rounded-full bg-white text-[#231715] shadow-lg transition hover:scale-105">
              <AppIcon name="question" size={22} />
            </button>
            <button type="button" onClick={toggleDark} aria-label={t("map_dark_mode")} title={t("map_dark_mode")} aria-pressed={dark} className="grid h-11 w-11 place-items-center rounded-full bg-white text-[#231715] shadow-lg transition hover:scale-105">
              <AppIcon name={dark ? "sun" : "moon"} size={20} />
            </button>
          </div>

          {/* Pastille « visible par tes amis seulement » (rebascule en 1 geste). */}
          {(friendsOnly || friendsOnlyMsg) && (
            <div className="absolute left-1/2 top-3 z-[1000] flex max-w-[calc(100%-130px)] -translate-x-1/2 flex-col items-center gap-1">
              {friendsOnly && (
                <button type="button" onClick={() => toggleFriendsOnly(false)} disabled={friendsOnlyBusy} className="inline-flex min-h-[40px] items-center gap-2 rounded-full bg-[#17141F] px-3.5 text-xs font-bold text-white shadow-lg">
                  <AppIcon name="eye-off" size={16} color="#fff" />
                  <span className="truncate">{t("map_friends_only_pill")}</span>
                  <span className="text-[#F4C04A]">›</span>
                </button>
              )}
              {friendsOnlyMsg && <span className="rounded-full bg-white/95 px-3 py-1 text-[11px] font-semibold text-[#231715] shadow">{friendsOnlyMsg}</span>}
            </div>
          )}

          {/* Coin haut-droit : me géolocaliser. */}
          <button
            type="button"
            title={t("map_locate_btn")}
            aria-label={t("map_locate_btn")}
            disabled={locating}
            onClick={() => {
              if (locating) return;
              if (typeof navigator === "undefined" || !("geolocation" in navigator)) { setLocateMsg(t("map_locate_unsupported")); return; }
              setLocateMsg(null);
              setLocating(true);
              const onFound = (pos: GeolocationPosition) => {
                const loc = { lat: pos.coords.latitude, lng: pos.coords.longitude };
                setUserLocation(loc);
                setFocusTarget({ ...loc, ts: Date.now() });
                setLocating(false);
              };
              const onFail = (err: GeolocationPositionError) => {
                setLocating(false);
                setLocateMsg(err && err.code === 1 ? t("map_locate_denied") : t("map_locate_failed"));
              };
              navigator.geolocation.getCurrentPosition(onFound, () => navigator.geolocation.getCurrentPosition(onFound, onFail, { enableHighAccuracy: false, timeout: 8000, maximumAge: 30000 }), { enableHighAccuracy: true, timeout: 12000, maximumAge: 0 });
            }}
            className="absolute right-3 top-3 z-[1000] grid h-11 w-11 place-items-center rounded-full bg-white shadow-lg transition hover:scale-105"
            style={{ color: roleColor }}
          >
            {locating ? <span className="h-5 w-5 animate-spin rounded-full border-2 border-current border-t-transparent" /> : <AppIcon name="locate" size={22} />}
          </button>
          {locateMsg && (
            <div className="absolute right-3 top-16 z-[1100] max-w-[240px] rounded-xl bg-white/95 px-3 py-2 text-[12px] font-medium text-ink shadow-lg">
              {locateMsg}
              <button type="button" onClick={() => setLocateMsg(null)} className="ml-2 font-bold text-[#C92A12]" aria-label="OK">OK</button>
            </div>
          )}

          {/* Bandeau de suivi en direct (zoom de suivi « joli »). */}
          {followed && (
            <div className="absolute inset-x-3 top-16 z-[1000] flex items-center gap-2 rounded-2xl px-3 py-2 text-xs font-bold text-white shadow-lg sm:left-1/2 sm:right-auto sm:max-w-sm sm:-translate-x-1/2" style={{ background: "#7C3AED" }}>
              <span className="relative flex h-2.5 w-2.5 shrink-0"><span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-white opacity-70" /><span className="relative inline-flex h-2.5 w-2.5 rounded-full bg-white" /></span>
              <span className="min-w-0 flex-1 truncate">{followPaused ? t("map_follow_paused") : t("map_following").replace("{name}", followed.name)}</span>
              {followPaused && (
                <button type="button" onClick={() => setFollowPaused(false)} className="shrink-0 rounded-full bg-white px-2.5 py-1 text-[11px] font-bold" style={{ color: "#7C3AED" }}>{t("map_follow_resume")}</button>
              )}
              <button type="button" onClick={() => { setFollowUserId(null); setFollowPaused(false); }} className="shrink-0 rounded-full bg-white/20 px-2.5 py-1 text-[11px] font-bold">{t("map_follow_stop")}</button>
            </div>
          )}

          {/* Viseur de placement (Tag spot / Signaler). */}
          {createKind && (
            <div className="pointer-events-none absolute left-1/2 top-1/2 z-[1100] -translate-x-1/2 -translate-y-1/2">
              <div className="h-5 w-5 rounded-full border-[2.5px] border-white shadow-lg" style={{ backgroundColor: createKind === "spot" ? "#17141F" : "#D32F2F" }} />
              <div className="absolute left-1/2 top-1/2 h-10 w-10 -translate-x-1/2 -translate-y-1/2 rounded-full" style={{ border: `2px solid ${createKind === "spot" ? "#17141F" : "#D32F2F"}`, opacity: 0.5 }} />
            </div>
          )}

          {/* RAIL GAUCHE (design « Paw Buttons », même ordre que l'app). */}
          <div className="absolute bottom-3 left-2.5 z-[1000] flex flex-col gap-2 md:bottom-4 md:left-3 md:gap-2.5">
            {(
              [
                { k: "around", g1: "#A076FF", g2: "#7040D6", label: t("map_around_title"), on: () => { setSheet("full"); document.getElementById("around-list")?.scrollIntoView({ behavior: "smooth", block: "start" }); } },
                { k: "route", g1: "#3DBF6C", g2: "#188A42", label: t("map_directions_btn"), on: () => {
                  if (selectedPoi) { const [lng, lat] = selectedPoi.location.coordinates; handleDirections({ lat, lng }); }
                  else { setSheet("full"); document.getElementById("around-list")?.scrollIntoView({ behavior: "smooth", block: "start" }); }
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
                { k: "feed", g1: "#5A4E46", g2: "#28201B", label: t("map_panel_reports_title"), on: () => {
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
                className="grid h-11 w-11 place-items-center rounded-full transition-transform duration-300 ease-[cubic-bezier(.3,1.5,.4,1)] hover:scale-105 active:scale-90 active:duration-100"
                style={{
                  background: `linear-gradient(165deg, ${b.g1}, ${b.g2})`,
                  border: "1.5px solid rgba(255,255,255,0.85)",
                  boxShadow: b.active ? `0 0 0 3px rgba(255,255,255,0.95), 0 0 18px ${b.g1}, 0 6px 14px ${b.g2}66, inset 0 1px 0 rgba(255,255,255,0.35)` : `0 6px 14px ${b.g2}66, inset 0 1px 0 rgba(255,255,255,0.35)`,
                }}
              >
                <span className="block h-[22px] w-[22px]" dangerouslySetInnerHTML={{ __html: RAIL_SVG[b.k] }} />
              </button>
            ))}
          </div>

          <PoiMap
            center={center}
            initialZoom={initialZoom}
            pois={visiblePois}
            userLocation={userLocation}
            selectedPoi={selectedPoi}
            onSelectPoi={setSelectedPoi}
            onMapMove={handleMapMove}
            onZoomChange={handleZoomChange}
            spots={showSpots ? spots : []}
            spotTypeLabels={spotTypeLabels}
            onSpotVisit={handleSpotVisit}
            reports={showReports ? reports : []}
            reportTypeLabels={reportTypeLabels}
            members={membersWithPresence}
            memberRoleLabels={{ owner: t("role_owner"), sitter: t("role_sitter"), walker: t("role_walker") }}
            memberLabels={{
              addFriend: t("map_member_add_friend"), sent: t("map_member_request_sent"), already: t("map_member_already"),
              failed: t("map_member_request_failed"), book: t("map_member_book"), approx: t("map_member_approx"),
              priceFrom: t("map_member_price_from"), verified: t("trust_id_title"),
            }}
            onAddFriend={handleAddFriend}
            friendPositions={showFriends ? livePositionsList : []}
            familyIds={familyIds}
            premiumIds={premiumIds}
            roleLabels={{ owner: t("role_owner"), sitter: t("role_sitter"), walker: t("role_walker") }}
            userRole={myRole}
            userName={myName}
            userAvatarUrl={myAvatarUrl}
            userIsPremium={premiumDays !== null || isStaffSub || benefits?.premiumActive === true}
            userPawFollow={benefits?.pawFollowActive === true || benefits?.familyActive === true}
            userFriendsOnly={friendsOnly}
            userAccuracy={userAccuracy}
            meLabel={t("legend_me_label")}
            positionLabel={t("map_your_position")}
            accuracyLabel={t("map_accuracy_note")}
            focusTarget={focusTarget}
            onFriendFocus={startFollow}
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

        {/* ── PANNEAU : colonne droite sur ordinateur, feuille glissante sur téléphone ── */}
        <aside
          className={`fixed inset-x-0 bottom-0 z-[1500] flex flex-col rounded-t-[28px] bg-white shadow-[0_-10px_40px_-10px_rgba(35,23,21,0.35)] transition-[height] duration-300 ${sheetH} lg:static lg:z-auto lg:h-[calc(100vh-190px)] lg:min-h-[560px] lg:rounded-[28px] lg:bg-[#FAF1EC] lg:shadow-none`}
        >
          {/* Poignée (téléphone seulement). */}
          <button type="button" onClick={cycleSheet} className="flex h-[58px] w-full shrink-0 flex-col items-center justify-center gap-1 lg:hidden" aria-label={sheet === "full" ? t("map_sheet_less") : t("map_sheet_more")}>
            <span className="block h-1.5 w-12 rounded-full" style={{ background: roleColor }} />
            <span className="text-[11px] font-semibold text-[#6E4F48]">
              {sheet === "full" ? t("map_sheet_less") : t("map_sheet_more")}
              {membersAround > 0 ? ` · ${t("map_members_around").replace("{count}", String(membersAround))}` : ""}
            </span>
          </button>

          <div className="min-h-0 flex-1 overflow-y-auto px-4 pb-6 lg:px-5 lg:pt-5">
            {/* « Je cherche » : une seule rangée de pilules. */}
            <p className="text-[11px] font-bold uppercase tracking-wide text-[#8A6B64]">{t("map_seek_label")}</p>
            <div className="mt-2 flex flex-wrap gap-2">
              {seek.map((s) => (
                <button
                  key={s.k}
                  type="button"
                  onClick={s.toggle}
                  aria-pressed={s.on}
                  className="inline-flex min-h-[36px] items-center gap-1.5 rounded-xl px-3 text-xs font-bold transition"
                  style={s.on ? { background: s.color, color: "#fff" } : { background: "#fff", color: s.color, boxShadow: `inset 0 0 0 1.5px ${s.color}55` }}
                >
                  <AppIcon name={s.icon} size={15} color={s.on ? "#fff" : s.color} />
                  {s.label}
                </button>
              ))}
            </div>

            {/* Compteur cliquable → liste des membres. */}
            <button
              type="button"
              onClick={() => { setSidePanel(sidePanel === "members" ? null : "members"); setSheet("full"); }}
              className={`mt-3 flex w-full items-center gap-3 rounded-2xl p-3 text-left transition ${sidePanel === "members" ? roleLight : "bg-white hover:bg-[#FDF8F7] lg:bg-white"}`}
            >
              <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full text-white" style={{ background: roleColor }}><AppIcon name="people" size={20} color="#fff" /></span>
              <span className="min-w-0 flex-1">
                <span className={`block text-sm font-bold ${roleTextDark}`}>{t("map_members_around").replace("{count}", String(membersAround))}</span>
                <span className="block text-xs text-[#6E4F48]">{t("map_panel_members_title")}</span>
              </span>
              <AppIcon name="arrow-right" size={18} color={roleColor} />
            </button>

            {/* Carte vide = une action (idée 1). */}
            {membersAround === 0 && (
              <div className="mt-3 rounded-2xl bg-white p-4 lg:bg-white">
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

            {/* Amis en direct. */}
            <div className="mt-3 rounded-2xl bg-white p-3">
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
            </div>

            {/* Mode « amis seulement » : interrupteur. */}
            <button type="button" onClick={() => toggleFriendsOnly(!friendsOnly)} disabled={friendsOnlyBusy} aria-pressed={friendsOnly} className="mt-3 flex w-full items-center gap-3 rounded-2xl bg-white p-3 text-left transition hover:bg-[#FDF8F7]">
              <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full text-white" style={{ background: friendsOnly ? "#17141F" : "#FBE9E5" }}><AppIcon name="eye-off" size={18} color={friendsOnly ? "#fff" : "#9E1F0B"} /></span>
              <span className="min-w-0 flex-1 text-sm font-semibold text-[#231715]">{t("map_friends_only_on")}</span>
              <span className={`relative inline-block h-6 w-11 shrink-0 rounded-full transition ${friendsOnly ? "bg-[#17141F]" : "bg-[#F0E3DF]"}`}><span className={`absolute top-0.5 h-5 w-5 rounded-full bg-white shadow transition ${friendsOnly ? "left-[22px]" : "left-0.5"}`} /></span>
            </button>

            {/* Abonnements actifs. */}
            {(() => {
              const subs: { label: string; bg: string; fg: string }[] = [];
              if (benefits?.premiumActive) subs.push({ label: "PawPremium", bg: "#231715", fg: "#FFD34D" });
              if (benefits?.pawspotActive) subs.push({ label: "PawSpots", bg: "#FFFFFF", fg: "#231715" });
              if (benefits?.familyActive) subs.push({ label: "PawFamily", bg: "#FFFFFF", fg: "#231715" });
              if (benefits?.pawFollowActive) subs.push({ label: "PawFollow", bg: "#FFFFFF", fg: "#231715" });
              if (!subs.length) return null;
              return (
                <div className="mt-3 flex flex-wrap items-center gap-2 rounded-2xl bg-white px-3 py-2.5">
                  <span className="text-sm font-semibold text-[#231715]">{t("map_active_subs")}</span>
                  {subs.map((sb) => <span key={sb.label} className="rounded-full px-3 py-1 text-xs font-semibold" style={{ backgroundColor: sb.bg, color: sb.fg, boxShadow: sb.bg === "#FFFFFF" ? "inset 0 0 0 1px #EADFDC" : undefined }}>{sb.label}</span>)}
                  <button type="button" onClick={() => router.push("/boutique")} className="ml-auto rounded-full bg-[#FAF1EC] px-3 py-1 text-xs font-semibold text-[#231715] transition hover:bg-[#F0E3DF]">{t("map_manage")}</button>
                </div>
              );
            })()}

            {/* PawPremium : achat ou état. */}
            <div className="mt-3">
              {premiumDays !== null || isStaffSub ? (
                <span className="inline-flex items-center gap-2 rounded-full bg-[#231715] px-4 py-2 text-xs font-semibold text-[#FFD34D]">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src="/pawpremium_logo.svg" alt="" width={18} height={18} />
                  {isStaffSub ? t("map_premium_active_staff") : t("map_premium_active_days").replace("{days}", String(premiumDays))}
                </span>
              ) : (
                <Link href="/boutique" className="inline-flex items-center gap-2 rounded-full bg-[#231715] px-4 py-2 text-xs font-semibold text-[#FFD34D] hover:bg-black">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src="/pawpremium_logo.svg" alt="" width={18} height={18} />
                  {t("map_premium_buy_cta")} →
                </Link>
              )}
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
              type Row = { id: string; lat: number; lng: number; km: number; pin: string; title: string; sub: string; photo: string; meta: string; color?: string; book?: string };
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
                rows = membersNear.map(({ m, km, lat, lng }) => {
                  const key = roleKey(m.role);
                  const price = key !== "owner" ? formatPrice(m.priceFrom, m.currency) : null;
                  return { id: m.id, lat, lng, km, pin: "", title: m.name || t("common_member"), sub: `${t(`role_${key}`)}${price ? ` · ${t("map_member_price_from")} ${price}` : ""}${(m.rating ?? 0) > 0 ? ` · ★ ${(m.rating ?? 0).toFixed(1)}` : ""}`, photo: m.avatar || "", meta: m.approx ? t("map_member_approx").replace("{km}", String(m.approxKm ?? 1)) : "", color: ROLE_COLOR[key], book: key !== "owner" ? `/book/${key}/${m.id}` : undefined };
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
                              <span className="block truncate text-sm font-semibold text-[#231715]">{r.title}</span>
                              {r.sub && <span className="block truncate text-xs" style={{ color: r.color || "#6E4F48" }}>{r.sub}</span>}
                              <span className="block truncate text-[11px] text-[#8A6B64]">{r.km < 1 ? `${Math.round(r.km * 1000)} m` : `${r.km.toFixed(1)} km`}{r.meta ? ` · ${r.meta}` : ""}</span>
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
            <select value={createType} onChange={(e) => setCreateType(e.target.value)} className="mt-1 w-full rounded-xl border border-[#EADFDC] bg-white px-3 py-2 text-sm">
              {createKind === "spot" ? spotOptions.map((tp) => <option key={tp} value={tp}>{spotTypeLabels[tp]}</option>) : reportOptions.map((tp) => <option key={tp} value={tp}>{reportTypeLabels[tp]}</option>)}
            </select>
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

      <PawMapLegendModal open={legendOpen} onClose={() => setLegendOpen(false)} />
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
