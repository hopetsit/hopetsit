"use client";

// v23.1 part 146 — PawMap interactive : la carte des points d'intérêt
// pet-friendly (vétos, parcs, plages, points d'eau, hôtels…). Auth required.
//
// v23.1 carte unique — Daniel : "sur le site web, UNE SEULE carte : depuis
// /map on a PawFollow (amis/famille en direct), PawSpot (spots
// communautaires) et l'itinéraire, tout réuni ; la page /friends/live est
// fusionnée". Architecture : on intègre les markers directement dans PoiMap
// (une seule MapContainer Leaflet) plutôt que d'empiler deux cartes —
// la logique amis/famille + socket est PORTÉE depuis /friends/live au
// niveau de cette page (les icônes avatars sont partagées avec
// FriendsLiveMap).
//
// Flow :
//   1. Récupère la géolocalisation du user (navigator.geolocation, fallback Paris)
//   2. Charge les POI dans un rayon de 10km via GET /map-pois/nearby
//   3. Affiche les markers sur OpenStreetMap (Leaflet)
//   4. Filtre par catégorie via toggle chips
//   5. Chips couches : PawFollow (amis/famille live) + PawSpots (communauté)
//   6. Bouton Itinéraire (popups spots + POI) → polyline orange + bandeau
//      distance/durée (402 → message PawFollow + lien /boutique)
//   7. Quand l'user pan la carte, refetch les POI (et spots si actifs)
//      autour du nouveau centre (avec debounce pour pas spammer l'API).

import dynamic from "next/dynamic";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
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
  getFriendLastPosition,
  getFriendsLivePositions,
  getMyBenefits,
  getMyFamily,
  getMyFriends,
  getNearbyMembers,
  getNearbyPawSpots,
  getNearbyReports,
  getNearbyPois,
  getPawSpotDirections,
  getStoredUser,
  visitSpot,
} from "@/lib/api";
import { useSocket, useSocketEvent } from "@/lib/useSocket";
import { getSocket } from "@/lib/socket";
// v23.1.365 — FIX build Vercel : importer haloColor depuis FriendsLiveMap
// chargeait Leaflet AU PRERENDER ("window is not defined" sur /map). Les
// couleurs rôle vivent ici en local (l'import type est erased, lui OK).
import type { FriendLivePosition } from "@/components/FriendsLiveMap";

const ROLE_CHIP_COLOR: Record<string, string> = {
  owner: "#EF4324",
  sitter: "#2563EB",
  walker: "#16A34A",
};
const roleChipColor = (role: string) => ROLE_CHIP_COLOR[role] || "#6B7280";

// v23.1.147 — note : PoiMap est dynamic pour éviter le SSR de Leaflet.
// Son loading state est en français hardcodé ; il est court (1-2s) donc
// l'impact UX inter-langues est minime — on l'ignore.
const PoiMap = dynamic(() => import("@/components/PoiMap"), {
  ssr: false,
  loading: () => (
    <div className="flex h-[70vh] min-h-[450px] items-center justify-center rounded-2xl border border-ink/5 bg-bg-soft text-ink-muted">
      ⌛
    </div>
  ),
});

// Tous les codes de catégorie POI.
const ALL_CATEGORIES = Object.keys(POI_CATEGORY_LABELS) as PoiCategory[];


function roleFromModel(model: string): "walker" | "sitter" | "owner" {
  const m = (model || "").toLowerCase();
  if (m === "walker") return "walker";
  if (m === "sitter") return "sitter";
  return "owner";
}

export default function MapPage() {
  const { t } = useT();
  const router = useRouter();
  const [userLocation, setUserLocation] = useState<{ lat: number; lng: number } | null>(null);
  // v23.1.397 — précision (mètres) du dernier relevé navigateur.
  const [userAccuracy, setUserAccuracy] = useState<number | null>(null);
  // v500 — Daniel : « la carte s'ouvre sur Paris ». La géoloc navigateur recentre
  // au 1er fix, mais Paris s'affichait avant (et en permanence si la géoloc est
  // bloquée/lente sur PC). On démarre désormais sur la DERNIÈRE position connue
  // (mémorisée en localStorage au précédent passage) → ouverture là où tu étais,
  // sans attendre le GPS. Paris ne reste que pour un tout 1er usage sans géoloc.
  const [center, setCenter] = useState<[number, number]>(() => {
    if (typeof window !== "undefined") {
      try {
        const saved = window.localStorage.getItem("hopetsit:lastMapCenter");
        if (saved) {
          const p = JSON.parse(saved);
          if (typeof p?.lat === "number" && typeof p?.lng === "number") {
            return [p.lat, p.lng];
          }
        }
      } catch {/* ignore */}
    }
    return [48.8566, 2.3522]; // Paris (fallback ultime)
  });
  const [pois, setPois] = useState<Poi[]>([]);
  // v23.1.393 — Daniel : « je ne peux pas choisir rien ou sélectionner
  // plusieurs lieux ». Multi-sélection : [] = Tous ; sinon on filtre côté
  // client (les POIs sont déjà tous chargés autour du centre).
  const [selectedCats, setSelectedCats] = useState<PoiCategory[]>([]);
  // v404 — Daniel : bouton « Rien » à côté de « Tous » → masque tous les POI.
  // ([] = Tous, donc on a besoin d'un flag distinct pour « rien afficher ».)
  const [noneSelected, setNoneSelected] = useState(false);
  const [loading, setLoading] = useState(true);
  const [fetching, setFetching] = useState(false);
  const [error, setError] = useState<string | null>(null);
  // v23.1.391 — statut PawPremium : si l'abo est ACTIF (ou staff), le
  // bouton d'achat devient un chip d'état (Daniel : « le bouton me renvoie
  // à la boutique au lieu de me montrer mes amis et les pawspots »).
  const [premiumDays, setPremiumDays] = useState<number | null>(null);
  // v23.1.394 — avatar pour le marqueur « ma position » (photo, pas un point).
  const [myAvatarUrl, setMyAvatarUrl] = useState<string | null>(null);
  useEffect(() => {
    if (!getStoredUser()) return;
    (async () => {
      try {
        const { getMyProfile } = await import("@/lib/api");
        const p = await getMyProfile();
        const url = p?.avatar?.url || null;
        if (url) setMyAvatarUrl(url);
      } catch { /* fallback : point couleur rôle */ }
    })();
  }, []);
  const [isStaffSub, setIsStaffSub] = useState(false);
  useEffect(() => {
    (async () => {
      try {
        const { getSubscriptionStatus } = await import("@/lib/api");
        const st = await getSubscriptionStatus();
        const staff = st.currentPeriodEnd
          ? new Date(st.currentPeriodEnd).getFullYear() >= 2090
          : false;
        setIsStaffSub(staff);
        if (st.premiumExpiry) {
          const d = Math.ceil((new Date(st.premiumExpiry).getTime() - Date.now()) / 86400000);
          if (d > 0) setPremiumDays(d);
        }
      } catch { /* non connecté → bouton d'achat visible */ }
    })();
  }, []);
  const [selectedPoi, setSelectedPoi] = useState<Poi | null>(null);

  // ── v23.1 carte unique — couches PawFollow / PawSpot + itinéraire ──────
  const [benefits, setBenefits] = useState<MyBenefits | null>(null);
  const [showFriends, setShowFriends] = useState(false);
  const [showSpots, setShowSpots] = useState(false);
  const [spots, setSpots] = useState<PawSpot[]>([]);
  // v497 — Daniel : « les 4 boutons PawMap sur le web » → couche signalements
  // (« Voir signaux ») + modal de création (Tag spot / Signaler), gated abo.
  const [showReports, setShowReports] = useState(false);
  const [reports, setReports] = useState<MapReport[]>([]);
  // v497 — membres PawMap proches (badge rose), visibles si VIEWER abonné.
  const [members, setMembers] = useState<NearbyMember[]>([]);
  const [createKind, setCreateKind] = useState<null | "spot" | "report">(null);
  const [createType, setCreateType] = useState<string>("");
  const [createName, setCreateName] = useState("");
  const [createNote, setCreateNote] = useState("");
  const [creating, setCreating] = useState(false);
  const [createErr, setCreateErr] = useState<string | null>(null);
  const [friendsLoading, setFriendsLoading] = useState(false);
  const [friendsForMap, setFriendsForMap] = useState<FriendItem[]>([]);
  const [familyIds, setFamilyIds] = useState<string[]>([]);
  // v23.1.399 — Daniel : la couronne 👑 doit aussi apparaître sur le site.
  const [premiumIds, setPremiumIds] = useState<string[]>([]);
  const [livePositions, setLivePositions] = useState<
    Map<string, FriendLivePosition>
  >(new Map());
  const friendsLoadedRef = useRef(false);
  const [route, setRoute] = useState<RouteResult | null>(null);
  const [routeLoading, setRouteLoading] = useState(false);
  const [directionsLocked, setDirectionsLocked] = useState(false);
  const [directionsError, setDirectionsError] = useState(false);

  // Connecte le socket pour recevoir les events temps réel amis/famille.
  const { connected: socketConnected } = useSocket();

  // v23.1.366 — Daniel : "aucun ami/famille sur la PawMap du site". Sans
  // map:identify, le serveur ne joint jamais ce socket à la room user →
  // AUCUN map:friend-position ne lui est poussé. On s'identifie à chaque
  // (re)connexion, comme l'app mobile.
  useEffect(() => {
    if (!socketConnected) return;
    const me = getStoredUser();
    if (!me) return;
    getSocket()?.emit("map:identify", { userId: me.id, role: me.role });
  }, [socketConnected]);

  // Index id → FriendItem pour résoudre nom/avatar/role des events socket
  // (porté de FriendsLiveMap — la résolution vit désormais côté page).
  const friendByUserId = useMemo(() => {
    const m = new Map<string, FriendItem>();
    for (const f of friendsForMap) {
      if (f.other?.id) m.set(f.other.id, f);
    }
    return m;
  }, [friendsForMap]);

  // map:friend-position → update or add (porté de FriendsLiveMap).
  useSocketEvent<{
    userId: string;
    role: string;
    lat: number;
    lng: number;
    at?: string;
  }>("map:friend-position", (data) => {
    const friend = friendByUserId.get(data.userId);
    const baseRole = roleFromModel(friend?.other?.model || data.role || "owner");
    setLivePositions((prev) => {
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
    setLivePositions((prev) => {
      if (!prev.has(data.userId)) return prev;
      const next = new Map(prev);
      next.delete(data.userId);
      return next;
    });
  });

  // v23.1.359 — halo "ma position" couleur du RÔLE (canon : owner orange /
  // sitter bleu / walker vert), résolu au mount depuis le user stocké.
  const [myRoleColor, setMyRoleColor] = useState("#2563EB");

  // v23.1.364 — cible de zoom : clic sur un marqueur ami OU sur un chip
  // « nom · rôle » de la rangée → FlyToFocus (PoiMap) vole dessus.
  const [focusTarget, setFocusTarget] = useState<{
    lat: number;
    lng: number;
    ts: number;
  } | null>(null);

  // Auth + géolocalisation au mount.
  useEffect(() => {
    const me = getStoredUser();
    if (!me) {
      router.replace("/login");
      return;
    }
    setMyRoleColor(
      me.role === "owner"
        ? "#EF4324"
        : me.role === "walker"
          ? "#16A34A"
          : "#2563EB",
    );
    if (!("geolocation" in navigator)) {
      // Pas de géoloc dispo → on reste sur Paris.
      setLoading(false);
      return;
    }
    // v23.1.397 — Daniel : « pourquoi je suis à côté de kasia ? ». Sur un
    // PC, le navigateur s'estime par WiFi/IP (30-300 m d'erreur) alors que
    // l'app utilise le GPS du téléphone. On AFFINE en continu : watchPosition
    // pendant ~12 s, on ne garde que les relevés qui AMÉLIORENT la précision,
    // et on expose accuracy → cercle de précision dessiné autour du marqueur.
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
          // v500 — mémorise la dernière position pour rouvrir la carte ici la
          // prochaine fois (plus de flash Paris).
          try {
            window.localStorage.setItem(
              "hopetsit:lastMapCenter",
              JSON.stringify(loc),
            );
          } catch {/* ignore */}
          if (firstFix) {
            firstFix = false;
            setCenter([loc.lat, loc.lng]);
          }
        }
        setLoading(false);
      },
      () => {
        // L'user a refusé la géoloc → fallback Paris.
        setLoading(false);
      },
      { timeout: 10000, enableHighAccuracy: true, maximumAge: 0 },
    );
    const stopId = setTimeout(
      () => navigator.geolocation.clearWatch(watchId),
      12000,
    );
    return () => {
      clearTimeout(stopId);
      navigator.geolocation.clearWatch(watchId);
    };
  }, [router]);

  // v23.1 carte unique — flags d'abonnement pour colorer les chips
  // (PawFollow violet + 👑 / PawSpot doré + 👑, gris sinon).
  useEffect(() => {
    if (!getStoredUser()) return;
    let cancelled = false;
    (async () => {
      const b = await getMyBenefits();
      if (!cancelled) setBenefits(b);
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  // Debounced refetch quand le centre change ou la catégorie change.
  const fetchTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const fetchPois = useCallback(
    async (lat: number, lng: number, category: PoiCategory | "all") => {
      if (fetchTimeoutRef.current) clearTimeout(fetchTimeoutRef.current);
      fetchTimeoutRef.current = setTimeout(async () => {
        setFetching(true);
        setError(null);
        try {
          const list = await getNearbyPois({
            lat,
            lng,
            maxDistance: 10000, // 10 km
            category: category === "all" ? undefined : category,
          });
          setPois(list);
        } catch (e) {
          if (e instanceof ApiError && e.status === 401) {
            router.replace("/login");
            return;
          }
          setError(e instanceof Error ? e.message : "Failed to load POI");
        } finally {
          setFetching(false);
        }
      }, 400);
    },
    [router],
  );

  // Premier fetch après que loading initial soit fini.
  useEffect(() => {
    if (loading) return;
    fetchPois(center[0], center[1], "all");
  }, [loading, fetchPois, center]);

  // v23.1 carte unique — fetch des PawSpots autour du centre courant quand
  // la couche est active (debounce, refetch quand l'user pan la carte).
  useEffect(() => {
    if (loading || !showSpots) return;
    const tid = setTimeout(async () => {
      try {
        const list = await getNearbyPawSpots({
          lat: center[0],
          lng: center[1],
          radius: 25000,
        });
        setSpots(list);
      } catch (e) {
        if (e instanceof ApiError && e.status === 401) {
          router.replace("/login");
        }
        // Autres erreurs : couche spots vide, pas de crash.
      }
    }, 400);
    return () => clearTimeout(tid);
  }, [loading, showSpots, center, router]);

  // v497 — couche « Voir signaux » : refetch des signalements quand active +
  // pan de la carte (mirror de la couche spots).
  useEffect(() => {
    if (loading || !showReports) return;
    const tid = setTimeout(async () => {
      try {
        const r = await getNearbyReports({
          lat: center[0],
          lng: center[1],
          maxDistance: 25000,
        });
        setReports(r.reports);
      } catch (e) {
        if (e instanceof ApiError && e.status === 401) router.replace("/login");
      }
    }, 400);
    return () => clearTimeout(tid);
  }, [loading, showReports, center, router]);

  // v497 — Daniel : « je vois les utilisateurs en rose sur le web ? ». Couche
  // membres PawMap proches (badge rose), VISIBLE uniquement si le VIEWER est
  // abonné (PawSpot/Premium) — comme l'app. Refetch au pan + à l'activation abo.
  const membersSubscribed = !!(
    benefits?.pawspotActive || benefits?.premiumActive || benefits?.isPremium
  );
  useEffect(() => {
    if (loading || !membersSubscribed) {
      setMembers([]);
      return;
    }
    const tid = setTimeout(async () => {
      try {
        const list = await getNearbyMembers({
          lat: center[0],
          lng: center[1],
          radiusInMeters: 25000,
        });
        setMembers(list);
      } catch (e) {
        if (e instanceof ApiError && e.status === 401) router.replace("/login");
      }
    }, 400);
    return () => clearTimeout(tid);
  }, [loading, membersSubscribed, center, router]);

  // v23.1 carte unique — chargement lazy des amis/famille + dernières
  // positions (logique portée telle quelle depuis /friends/live).
  const loadFriends = useCallback(async () => {
    setFriendsLoading(true);
    try {
      // 1) Fetch friends + family en parallele.
      const [friendList, familyResp] = await Promise.all([
        getMyFriends(),
        getMyFamily(),
      ]);
      const accepted = friendList.filter(
        (f) => f.status === "accepted" && !f.other?.deleted,
      );
      const allFamily = (familyResp.members || []).filter((m) => !!m.id);
      setFamilyIds(allFamily.map((m) => m.id));
      // v23.1.399 — membres PawPremium (isPremium poussé par le backend).
      // v500 — Daniel : « couronne premium pas affichée sur le web ». BUG :
      // premiumIds ne venait QUE de la FAMILLE → un AMI premium (hors famille)
      // n'avait jamais la couronne sur le web, alors que l'app la montre (elle
      // lit isPremium par ami via fetchUserMini). FIX : premiumIds = amis
      // premium (f.other.isPremium, renvoyé par le backend) + famille premium.
      const _premIds = [
        ...accepted
          .filter((f) => f.other?.isPremium)
          .map((f) => f.other.id),
        ...allFamily.filter((m) => m.isPremium).map((m) => m.id),
      ].filter(Boolean);
      setPremiumIds([...new Set(_premIds)]);

      // 2) friends élargis (friends + family synthétiques) pour résoudre
      // les events socket des membres famille hors friend-list.
      const out = [...accepted];
      const inFriendIds = new Set(
        accepted.map((f) => f.other?.id).filter(Boolean) as string[],
      );
      const ModelMap: Record<string, "Owner" | "Sitter" | "Walker"> = {
        owner: "Owner",
        sitter: "Sitter",
        walker: "Walker",
      };
      for (const m of allFamily) {
        if (!m.id || inFriendIds.has(m.id)) continue;
        out.push({
          id: `family-${m.id}`,
          status: "accepted",
          initiatedByMe: false,
          other: {
            id: m.id,
            model: ModelMap[(m.role || "").toLowerCase()] || "Owner",
            name: m.name || "Famille",
            email: m.email || "",
            avatar: m.avatar || "",
          },
          mySharePosition: true,
          theirSharePosition: true,
        });
      }
      setFriendsForMap(out);

      // 3) Dernières positions connues (ids uniques amis + famille).
      const infoById = new Map<
        string,
        { role: "walker" | "sitter" | "owner"; name: string; avatar: string }
      >();
      for (const f of accepted) {
        if (!f.other?.id) continue;
        infoById.set(f.other.id, {
          role: roleFromModel(f.other.model),
          name: f.other.name || "Ami",
          avatar: f.other.avatar || "",
        });
      }
      for (const m of allFamily) {
        if (!m.id || infoById.has(m.id)) continue;
        infoById.set(m.id, {
          role: roleFromModel(m.role),
          name: m.name || "Famille",
          avatar: m.avatar || "",
        });
      }
      // v23.1.366 — Daniel : "sur la PawMap du site n'apparaît aucun ami ou
      // famille". On s'hydrate d'abord via le BULK /friends/live-positions —
      // la MÊME source que l'app mobile (qui marche) : règles d'accès et
      // fraîcheur < 24 h encapsulées serveur. Fallback par-ami pour les ids
      // (ex. membres famille hors liste d'amis) absents du bulk.
      const bulk = await getFriendsLivePositions();
      const bulkRows: FriendLivePosition[] = [];
      const seen = new Set<string>();
      for (const b of bulk) {
        if (b.lat == null || b.lng == null) continue;
        const info = infoById.get(b.userId);
        seen.add(b.userId);
        bulkRows.push({
          userId: b.userId,
          role: roleFromModel(info ? info.role : b.role),
          name: info?.name || "Ami",
          avatar: info?.avatar,
          lat: b.lat,
          lng: b.lng,
          at: b.at || new Date().toISOString(),
        });
      }
      const idArr = Array.from(infoById.keys()).filter((id) => !seen.has(id));
      const posResults: (FriendLivePosition | null)[] = await Promise.all(
        idArr.map(async (id): Promise<FriendLivePosition | null> => {
          try {
            const p = await getFriendLastPosition(id);
            if (!p || p.lat == null || p.lng == null) return null;
            const info = infoById.get(id);
            if (!info) return null;
            return {
              userId: id,
              role: info.role,
              name: info.name,
              avatar: info.avatar,
              lat: p.lat,
              lng: p.lng,
              at: new Date().toISOString(),
            };
          } catch {
            return null;
          }
        }),
      );
      setLivePositions((prev) => {
        const next = new Map(prev);
        for (const p of [...bulkRows, ...posResults]) {
          // Les events socket déjà reçus (plus frais) gardent la priorité.
          if (p && !next.has(p.userId)) next.set(p.userId, p);
        }
        return next;
      });
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) {
        router.replace("/login");
        return;
      }
      // Défensif : couche amis vide, la carte reste utilisable.
    } finally {
      setFriendsLoading(false);
    }
  }, [router]);

  // v23.1.391 — Daniel : « mes amis et les spots n'apparaissent pas ».
  // Quand l'abonnement est ACTIF (PawFollow/Famille/Premium/staff), les
  // couches s'allument AUTOMATIQUEMENT au chargement — comme dans l'app.
  const autoLayersRef = useRef(false);
  useEffect(() => {
    if (!benefits || autoLayersRef.current) return;
    autoLayersRef.current = true;
    const premium = benefits.premiumActive === true;
    const staff = benefits.isPremium === true; // staff/abo individuel actif
    if (premium || benefits.pawFollowActive || benefits.familyActive || staff) {
      setShowFriends(true);
      if (!friendsLoadedRef.current) {
        friendsLoadedRef.current = true;
        void loadFriends();
      }
    }
    if (premium || benefits.pawspotActive || staff) {
      setShowSpots(true);
    }
  }, [benefits, loadFriends]);

  // v497 — visite d'un spot (ouverture popup) : compte côté backend (1×/user)
  // + met à jour le compteur 👣 affiché localement avec le total renvoyé.
  async function handleSpotVisit(id: string) {
    try {
      const vc = await visitSpot(id);
      setSpots((prev) =>
        prev.map((s) => (s.id === id ? { ...s, visitsCount: vc } : s)),
      );
    } catch {
      /* best-effort : le compteur se mettra à jour au prochain chargement */
    }
  }

  function toggleFriendsLayer() {
    const next = !showFriends;
    setShowFriends(next);
    if (next && !friendsLoadedRef.current) {
      friendsLoadedRef.current = true;
      void loadFriends();
    }
  }

  // v497 — Tag spot / Signaler : gated sur l'abonnement (PawSpot/Premium).
  // Sans abo → boutique. Avec abo → modal (type + note) ; position = CENTRE de
  // la carte (l'user déplace la carte pour positionner, comme un viseur).
  function openCreate(kind: "spot" | "report") {
    const subbed = !!(
      benefits?.pawspotActive || benefits?.premiumActive || benefits?.isPremium
    );
    if (!subbed) {
      router.push("/boutique");
      return;
    }
    setCreateKind(kind);
    setCreateType(kind === "spot" ? "path_walk" : "lost_pet");
    setCreateName("");
    setCreateNote("");
    setCreateErr(null);
  }
  async function submitCreate() {
    if (creating || !createKind) return;
    const lat = center[0];
    const lng = center[1];
    setCreating(true);
    setCreateErr(null);
    try {
      if (createKind === "spot") {
        if (!createName.trim()) {
          setCreateErr(t("map_spot_name_ph"));
          setCreating(false);
          return;
        }
        await createPawSpot({
          type: createType as PawSpotType,
          name: createName.trim(),
          description: createNote.trim(),
          lat,
          lng,
        });
        if (!showSpots) setShowSpots(true);
        const list = await getNearbyPawSpots({ lat, lng, radius: 25000 });
        setSpots(list);
      } else {
        await createMapReport({
          type: createType as MapReportType,
          lat,
          lng,
          note: createNote.trim(),
        });
        if (!showReports) setShowReports(true);
        const r = await getNearbyReports({ lat, lng, maxDistance: 25000 });
        setReports(r.reports);
      }
      setCreateKind(null);
    } catch (e) {
      if (e instanceof ApiError && e.status === 402) {
        setCreateErr(t("map_create_locked"));
      } else if (e instanceof ApiError && e.status === 401) {
        router.replace("/login");
      } else {
        setCreateErr(t("map_create_error"));
      }
    } finally {
      setCreating(false);
    }
  }

  // v23.1 carte unique — Itinéraire : géoloc navigateur fraîche, fallback
  // dernière position connue puis centre carte. 402 PAWFOLLOW_REQUIRED →
  // bandeau "inclus dans PawFollow / PawFamily" + lien /boutique.
  const handleDirections = useCallback(
    (target: { lat: number; lng: number }) => {
      setDirectionsLocked(false);
      setDirectionsError(false);
      setRouteLoading(true);
      const go = async (from: { lat: number; lng: number }) => {
        try {
          const r = await getPawSpotDirections({
            fromLat: from.lat,
            fromLng: from.lng,
            toLat: target.lat,
            toLng: target.lng,
          });
          setRoute(r);
        } catch (e) {
          if (e instanceof ApiError && e.status === 402) {
            setDirectionsLocked(true);
          } else if (e instanceof ApiError && e.status === 401) {
            router.replace("/login");
            return;
          } else {
            setDirectionsError(true);
          }
        } finally {
          setRouteLoading(false);
        }
      };
      const fallback = userLocation ?? { lat: center[0], lng: center[1] };
      if (typeof navigator !== "undefined" && "geolocation" in navigator) {
        navigator.geolocation.getCurrentPosition(
          (pos) =>
            void go({ lat: pos.coords.latitude, lng: pos.coords.longitude }),
          () => void go(fallback),
          { timeout: 5000 },
        );
      } else {
        void go(fallback);
      }
    },
    [userLocation, center, router],
  );

  function clearRoute() {
    setRoute(null);
    setDirectionsLocked(false);
    setDirectionsError(false);
  }

  function handleMapMove(c: { lat: number; lng: number }) {
    // Ne recentre que si l'utilisateur a vraiment bougé (>500m du centre actuel)
    // pour éviter les refetch quand on zoom in/out.
    const distance = Math.sqrt(
      Math.pow(c.lat - center[0], 2) + Math.pow(c.lng - center[1], 2),
    );
    if (distance > 0.005) {
      setCenter([c.lat, c.lng]);
    }
  }

  const livePositionsList = useMemo(
    () => Array.from(livePositions.values()),
    [livePositions],
  );

  if (loading) {
    return (
      <div className="mx-auto max-w-5xl px-4 py-24 text-center text-ink-muted">
        {t("map_loading_locating")}
      </div>
    );
  }

  // v23.1.147 — labels catégories traduits selon la langue active.
  const CAT_KEY_FOR_LANG: Record<PoiCategory, string> = {
    vet: "map_cat_vet",
    shop: "map_cat_shop",
    groomer: "map_cat_groomer",
    park: "map_cat_park",
    beach: "map_cat_beach",
    water: "map_cat_water",
    trainer: "map_cat_trainer",
    hotel: "map_cat_hotel",
    restaurant: "map_cat_restaurant",
    other: "map_cat_other",
  };

  // v23.1 carte unique — labels i18n des types PawSpot pour les popups.
  const spotTypeLabels: Record<PawSpotType, string> = {
    path_walk: t("map_spot_type_path_walk"),
    chill: t("map_spot_type_chill"),
    playground: t("map_spot_type_playground"),
    swimming: t("map_spot_type_swimming"),
    food_cafe: t("map_spot_type_food_cafe"),
    other: t("map_spot_type_other"),
  };
  // v497 — libellés + options des types de signalement (modal « Signaler » +
  // popup de la couche reports). Set restreint aux signalements essentiels.
  const reportTypeLabels: Partial<Record<MapReportType, string>> = {
    lost_pet: t("map_rtype_lost_pet"),
    found_pet: t("map_rtype_found_pet"),
    aggressive_dog: t("map_rtype_aggressive_dog"),
    dead_animal: t("map_rtype_dead_animal"),
    stray_pet: t("map_rtype_stray_pet"),
    water_active: t("map_rtype_water_active"),
  };
  const reportOptions: { type: MapReportType; emoji: string }[] = [
    { type: "lost_pet", emoji: "🐾" },
    { type: "found_pet", emoji: "🔍" },
    { type: "aggressive_dog", emoji: "⚠️" },
    { type: "dead_animal", emoji: "💀" },
    { type: "stray_pet", emoji: "🐈" },
    { type: "water_active", emoji: "💧" },
  ];
  const spotOptions: PawSpotType[] = [
    "path_walk",
    "chill",
    "playground",
    "swimming",
    "food_cafe",
    "other",
  ];

  // v23.1.393 — multi-sélection : [] = tout afficher. v404 — « Rien » = aucun POI.
  const visiblePois = noneSelected
    ? []
    : selectedCats.length === 0
      ? pois
      : pois.filter((p) => selectedCats.includes(p.category));

  return (
    <div className="mx-auto max-w-6xl px-4 py-8 md:py-12">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-2">
        <Link href="/dashboard" className="text-sm text-ink-muted hover:text-ink">
          ← {t("nav_dashboard")}
        </Link>
        {fetching && (
          <span className="text-xs text-ink-muted">{t("map_searching")}</span>
        )}
      </div>

      <h1 className="font-display text-3xl font-extrabold md:text-4xl">
        {t("map_title")}
      </h1>
      <p className="mt-2 text-ink-muted">
        {t("map_count_results").replace("{count}", String(visiblePois.length))}
        {" "}
        {t("map_pan_hint")}
      </p>

      {/* v498 — Daniel : refonte de la barre de contrôles PawMap (maquette
          PawMap-Boutons). La CARTE est inchangée ; on réutilise état + handlers.
          1) Barre d'actions  2) Amis en direct  3) Abonnements actifs
          (4) Filtrer par catégorie plus bas). */}
      {/* 1) Barre d'actions */}
      <div className="mt-6 flex flex-wrap items-center gap-2.5">
        <button
          type="button"
          onClick={() => openCreate("report")}
          className="inline-flex items-center gap-1.5 rounded-full px-4 py-2 text-sm font-bold text-white shadow-sm transition hover:brightness-110"
          style={{ backgroundColor: "#e5342a" }}
        >
          ⚠️ {t("map_report_cta")}
        </button>
        <button
          type="button"
          onClick={() => setShowReports((v) => !v)}
          className={`inline-flex items-center gap-1.5 rounded-full px-4 py-2 text-sm font-bold transition hover:brightness-105 ${showReports ? "ring-2 ring-offset-1" : ""}`}
          style={{ backgroundColor: "#fbe4e1", color: "#c0352b" }}
        >
          👁 {t("map_reports_chip")}
        </button>
        <span className="h-6 w-px bg-ink/15" aria-hidden />
        <button
          type="button"
          onClick={() => openCreate("spot")}
          className="inline-flex items-center gap-1.5 rounded-full px-4 py-2 text-sm font-bold text-white shadow-sm transition hover:brightness-110"
          style={{ backgroundColor: "#e83e8c" }}
        >
          🐾 {t("map_tag_spot_cta")}
        </button>
        <button
          type="button"
          onClick={() => setShowSpots((v) => !v)}
          className={`inline-flex items-center gap-1.5 rounded-full px-4 py-2 text-sm font-bold transition hover:brightness-105 ${showSpots ? "ring-2 ring-offset-1" : ""}`}
          style={{ backgroundColor: "#fce0ef", color: "#c2367f" }}
        >
          🐾 {t("map_spots_chip")}
        </button>
        {/* Légende : avatar membre ROSE (sans halo) + libellé Utilisateur. */}
        <span className="ml-1 inline-flex items-center gap-1.5 text-xs font-semibold text-ink-muted">
          <span
            className="grid h-6 w-6 place-items-center rounded-full border-2 border-white text-[11px] shadow"
            style={{ background: "linear-gradient(135deg,#F06AA0,#E0568B)" }}
          >
            🐾
          </span>
          {t("map_member_legend")}
        </span>
      </div>

      {/* 2) Bandeau « Amis en direct » : clic sur l'en-tête = charge/affiche la
          couche amis ; chips cliquables = zoom sur l'ami. */}
      <div className="mt-3 flex flex-wrap items-center gap-2 rounded-2xl border border-ink/10 bg-white px-4 py-2.5 shadow-sm">
        <button
          type="button"
          onClick={toggleFriendsLayer}
          className="flex items-center gap-2"
        >
          <span className="relative flex h-2.5 w-2.5">
            <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400 opacity-75" />
            <span className="relative inline-flex h-2.5 w-2.5 rounded-full bg-emerald-500" />
          </span>
          <span className="text-sm font-extrabold text-ink">
            {t("map_live_friends")}
          </span>
          <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs font-bold text-emerald-700">
            {livePositionsList.length}
          </span>
        </button>
        {friendsLoading && (
          <span className="text-xs text-ink-muted">{t("common_loading")}</span>
        )}
        {showFriends &&
          livePositionsList.map((p) => (
            <button
              key={`lf-${p.userId}`}
              type="button"
              onClick={() =>
                setFocusTarget({ lat: p.lat, lng: p.lng, ts: Date.now() })
              }
              className="inline-flex items-center gap-1.5 rounded-full border bg-white px-2 py-1 text-[11px] font-semibold transition hover:shadow"
              style={{ borderColor: `${roleChipColor(p.role)}55`, color: roleChipColor(p.role) }}
            >
              <span
                className="grid h-5 w-5 place-items-center rounded-full text-[10px] font-bold text-white"
                style={{ backgroundColor: roleChipColor(p.role) }}
              >
                {(p.name || "?").charAt(0).toUpperCase()}
              </span>
              <span className="inline-block h-2 w-2 rounded-full bg-emerald-500" />
              {p.name} · {t(`role_${p.role}`)}
            </button>
          ))}
      </div>

      {/* 3) Bandeau « Abonnements actifs » : 1 puce par abo réellement actif. */}
      {(() => {
        const subs: { label: string; bg: string; fg: string }[] = [];
        if (benefits?.premiumActive)
          subs.push({ label: "PawPremium", bg: "#1c1b18", fg: "#e3bf5a" });
        if (benefits?.pawspotActive)
          subs.push({ label: "PawSpots", bg: "#fbf2d4", fg: "#8a6510" });
        if (benefits?.familyActive)
          subs.push({ label: "PawFamily", bg: "#f1ecfb", fg: "#5a31b0" });
        if (benefits?.pawFollowActive)
          subs.push({ label: "PawFollow", bg: "#ede7f9", fg: "#4f2ba6" });
        if (!subs.length) return null;
        return (
          <div className="mt-3 flex flex-wrap items-center gap-2 rounded-2xl border border-ink/10 bg-white px-4 py-2.5 shadow-sm">
            <span className="text-sm font-extrabold text-ink">
              {t("map_active_subs")}
            </span>
            <span className="rounded-full bg-ink/10 px-2 py-0.5 text-xs font-bold text-ink">
              {subs.length}
            </span>
            {subs.map((sb) => (
              <span
                key={sb.label}
                className="rounded-full px-3 py-1 text-xs font-bold"
                style={{ backgroundColor: sb.bg, color: sb.fg }}
              >
                {sb.label}
              </span>
            ))}
            <button
              type="button"
              onClick={() => router.push("/boutique")}
              className="ml-auto rounded-full border border-ink/15 px-3 py-1 text-xs font-semibold text-ink transition hover:bg-ink/5"
            >
              {t("map_manage")}
            </button>
          </div>
        );
      })()}

      {/* v23.1 carte unique — bandeau itinéraire : distance/durée + effacer. */}
      {route && (
        <div
          className="mt-3 flex flex-wrap items-center gap-3 rounded-xl px-4 py-2 text-sm"
          style={{
            backgroundColor: "rgba(239,67,36,0.08)",
            border: "1px solid rgba(239,67,36,0.3)",
          }}
        >
          <span className="font-semibold" style={{ color: "#C2410C" }}>
            🧭{" "}
            {route.distanceMeters != null && route.durationSeconds != null
              ? t("map_route_distance")
                  .replace("{km}", (route.distanceMeters / 1000).toFixed(1))
                  .replace(
                    "{min}",
                    String(Math.max(1, Math.round(route.durationSeconds / 60))),
                  )
              : t("map_route_ready")}
          </span>
          <button
            type="button"
            onClick={clearRoute}
            className="rounded-full bg-white px-3 py-1 text-xs font-semibold text-ink shadow-sm hover:bg-ink/5"
          >
            ✕ {t("map_route_clear")}
          </button>
        </div>
      )}

      {/* v23.1.388/391 — bouton PawPremium : achat si PAS abonné, sinon
          chip d'état (amis + pawspots déjà visibles sur la carte). */}
      <div className="mt-3">
        {premiumDays !== null || isStaffSub ? (
          <span className="inline-flex items-center gap-2 rounded-full border-2 border-amber-400 bg-gradient-to-r from-[#221C12] to-[#15120D] px-4 py-2 text-xs font-bold text-yellow-400">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/pawpremium_logo.svg" alt="" width={18} height={18} />
            {isStaffSub ? t("map_premium_active_staff") : t("map_premium_active_days").replace("{days}", String(premiumDays))}
          </span>
        ) : (
          <Link href="/boutique" className="inline-flex items-center gap-2 rounded-full border-2 border-amber-400 bg-gradient-to-r from-[#221C12] to-[#15120D] px-4 py-2 text-xs font-bold text-yellow-400 hover:brightness-125">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/pawpremium_logo.svg" alt="" width={18} height={18} />
            {t("map_premium_buy_cta")} →
          </Link>
        )}
      </div>

      {/* 402 PAWFOLLOW_REQUIRED → itinéraire réservé PawFollow / PawFamily. */}
      {directionsLocked && (
        <div
          className="mt-3 flex flex-wrap items-center gap-2 rounded-xl px-4 py-3 text-sm"
          style={{ backgroundColor: "#F3E8FF", color: "#6B21A8" }}
        >
          <span>👑 {t("map_directions_locked")}</span>
          <Link href="/boutique" className="font-bold underline">
            {t("map_directions_locked_cta")}
          </Link>
        </div>
      )}

      {directionsError && (
        <div className="mt-3 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700">
          {t("map_directions_error")}
        </div>
      )}

      {/* Filtre par catégorie */}
      <div className="mt-4 flex flex-wrap gap-2">
        <CategoryChip
          label={t("map_filter_all")}
          emoji="🗺️"
          active={!noneSelected && selectedCats.length === 0}
          onClick={() => { setNoneSelected(false); setSelectedCats([]); }}
        />
        {/* v404 — « Rien » : masque tous les lieux. */}
        <CategoryChip
          label={t("map_filter_none")}
          emoji="🚫"
          active={noneSelected}
          onClick={() => { setNoneSelected(true); setSelectedCats([]); }}
        />
        {ALL_CATEGORIES.map((cat) => (
          <CategoryChip
            key={cat}
            label={t(CAT_KEY_FOR_LANG[cat])}
            emoji={POI_CATEGORY_LABELS[cat].emoji}
            active={!noneSelected && selectedCats.includes(cat)}
            onClick={() => {
              setNoneSelected(false);
              setSelectedCats((prev) =>
                prev.includes(cat)
                  ? prev.filter((c) => c !== cat)
                  : [...prev, cat],
              );
            }}
          />
        ))}
      </div>

      {error && (
        <div className="mt-4 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {/* Carte */}
      <div className="relative mt-6">
        {/* v23.1.372 — Daniel : "en haut à droite, la petite icône pour
            géolocaliser ma position" — recadre + zoome sur moi (FlyToFocus),
            comme le bouton géoloc de l'app. z-[1000] pour passer au-dessus
            des panes Leaflet. */}
        <button
          type="button"
          title={t("map_locate_btn")}
          aria-label={t("map_locate_btn")}
          onClick={() => {
            if (!("geolocation" in navigator)) return;
            navigator.geolocation.getCurrentPosition(
              (pos) => {
                const loc = {
                  lat: pos.coords.latitude,
                  lng: pos.coords.longitude,
                };
                setUserLocation(loc);
                setFocusTarget({ ...loc, ts: Date.now() });
              },
              () => {},
              { enableHighAccuracy: true, timeout: 10000 },
            );
          }}
          className="absolute right-3 top-3 z-[1000] grid h-11 w-11 place-items-center rounded-full bg-white text-[#EF4324] shadow-lg ring-1 ring-ink/10 transition hover:scale-105"
        >
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
            <circle cx="12" cy="12" r="3.5" fill="currentColor" stroke="none" />
            <circle cx="12" cy="12" r="8" />
            <line x1="12" y1="1.5" x2="12" y2="5" />
            <line x1="12" y1="19" x2="12" y2="22.5" />
            <line x1="1.5" y1="12" x2="5" y2="12" />
            <line x1="19" y1="12" x2="22.5" y2="12" />
          </svg>
        </button>
        {/* v497 — Daniel : viseur de placement PRÉCIS pendant la création.
            Point ROSE = Tag spot, point ROUGE = Signaler. Fixe au centre : on
            déplace la carte dessous pour positionner au pixel près. */}
        {createKind && (
          <div className="pointer-events-none absolute left-1/2 top-1/2 z-[1100] -translate-x-1/2 -translate-y-1/2">
            <div
              className="h-5 w-5 rounded-full border-[2.5px] border-white shadow-lg"
              style={{
                backgroundColor: createKind === "spot" ? "#EC4899" : "#EF4324",
              }}
            />
            <div
              className="absolute left-1/2 top-1/2 h-10 w-10 -translate-x-1/2 -translate-y-1/2 rounded-full"
              style={{
                border: `2px solid ${createKind === "spot" ? "#EC4899" : "#EF4324"}`,
                opacity: 0.5,
              }}
            />
          </div>
        )}
        <PoiMap
          center={center}
          pois={visiblePois}
          userLocation={userLocation}
          selectedPoi={selectedPoi}
          onSelectPoi={setSelectedPoi}
          onMapMove={handleMapMove}
          spots={showSpots ? spots : []}
          spotTypeLabels={spotTypeLabels}
          onSpotVisit={handleSpotVisit}
          reports={showReports ? reports : []}
          reportTypeLabels={reportTypeLabels}
          members={members}
          memberRoleLabels={{
            owner: t("role_owner"),
            sitter: t("role_sitter"),
            walker: t("role_walker"),
          }}
          friendPositions={showFriends ? livePositionsList : []}
          familyIds={familyIds}
          premiumIds={premiumIds}
          roleLabels={{
            owner: t("role_owner"),
            sitter: t("role_sitter"),
            walker: t("role_walker"),
          }}
          userHaloColor={myRoleColor}
          userAvatarUrl={myAvatarUrl}
          userIsPremium={premiumDays !== null || isStaffSub}
          userAccuracy={userAccuracy}
          focusTarget={focusTarget}
          onFriendFocus={(p) =>
            setFocusTarget({ lat: p.lat, lng: p.lng, ts: Date.now() })
          }
          routePoints={route?.points ?? null}
          onDirections={handleDirections}
          directionsLabel={t("map_directions_btn")}
        />
      </div>

      {/* Détails du POI sélectionné */}
      {selectedPoi && (
        <div className="mt-6 rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
          <div className="flex items-start justify-between gap-3">
            <div>
              <div className="text-xs uppercase tracking-wider text-ink-muted">
                {POI_CATEGORY_LABELS[selectedPoi.category]?.emoji}{" "}
                {t(CAT_KEY_FOR_LANG[selectedPoi.category])}
              </div>
              <h2 className="mt-1 text-lg font-bold text-ink">{selectedPoi.title}</h2>
              {selectedPoi.address && (
                <p className="mt-1 text-sm text-ink-muted">📍 {selectedPoi.address}</p>
              )}
            </div>
            <button
              type="button"
              onClick={() => setSelectedPoi(null)}
              className="text-2xl leading-none text-ink-muted hover:text-ink"
              aria-label={t("map_close")}
            >
              ×
            </button>
          </div>
          {selectedPoi.description && (
            <p className="mt-3 text-sm text-ink-muted">{selectedPoi.description}</p>
          )}
          <div className="mt-3 flex flex-wrap gap-2 text-xs">
            {selectedPoi.phone && (
              <a
                href={`tel:${selectedPoi.phone}`}
                className="rounded-full bg-bg-soft px-3 py-1 font-medium text-ink hover:bg-ink/10"
              >
                📞 {selectedPoi.phone}
              </a>
            )}
            {selectedPoi.website && (
              <a
                href={selectedPoi.website}
                target="_blank"
                rel="noopener noreferrer"
                className="rounded-full bg-bg-soft px-3 py-1 font-medium text-ink hover:bg-ink/10"
              >
                {t("map_website_action")}
              </a>
            )}
            {selectedPoi.openingHours && (
              <span className="rounded-full bg-bg-soft px-3 py-1 text-ink-muted">
                🕐 {selectedPoi.openingHours}
              </span>
            )}
          </div>
          {selectedPoi.rating && selectedPoi.rating > 0 && (
            <div className="mt-3 text-sm">
              <span className="font-bold text-amber-600">★ {selectedPoi.rating.toFixed(1)}</span>
              {selectedPoi.reviewsCount ? (
                <span className="ml-1 text-ink-muted">
                  {t("map_reviews_count").replace("{count}", String(selectedPoi.reviewsCount))}
                </span>
              ) : null}
            </div>
          )}
        </div>
      )}

      {/* Légende */}
      <div className="mt-8 rounded-2xl border border-ink/5 bg-bg-soft px-4 py-3 text-xs text-ink-muted">
        💡 {t("map_legend")}
      </div>

      {/* v497 — modal de création Tag spot / Signaler. Position = CENTRE de la
          carte (l'utilisateur déplace la carte pour positionner). */}
      {createKind && (
        <div className="fixed inset-x-0 bottom-0 z-[2000] flex justify-center p-4">
          <div className="w-full max-w-sm rounded-2xl bg-white p-5 shadow-2xl ring-1 ring-ink/10">
            {/* v497 — feuille EN BAS (pas de fond noir plein écran) → la carte +
                le viseur restent visibles pendant qu'on positionne. */}
            <h3 className="font-display text-lg font-extrabold text-ink">
              {createKind === "spot"
                ? t("map_tag_spot_cta")
                : t("map_report_cta")}
            </h3>
            <p className="mt-1 text-xs text-ink-muted">
              {t("map_create_center_hint")}
            </p>

            <label className="mt-3 block text-xs font-semibold text-ink-muted">
              {t("map_type_label")}
            </label>
            <select
              value={createType}
              onChange={(e) => setCreateType(e.target.value)}
              className="mt-1 w-full rounded-xl border border-ink/15 bg-white px-3 py-2 text-sm"
            >
              {createKind === "spot"
                ? spotOptions.map((tp) => (
                    <option key={tp} value={tp}>
                      {spotTypeLabels[tp]}
                    </option>
                  ))
                : reportOptions.map((o) => (
                    <option key={o.type} value={o.type}>
                      {o.emoji} {reportTypeLabels[o.type]}
                    </option>
                  ))}
            </select>

            {createKind === "spot" && (
              <input
                value={createName}
                onChange={(e) => setCreateName(e.target.value)}
                placeholder={t("map_spot_name_ph")}
                maxLength={80}
                className="mt-3 w-full rounded-xl border border-ink/15 px-3 py-2 text-sm"
              />
            )}
            <textarea
              value={createNote}
              onChange={(e) => setCreateNote(e.target.value)}
              placeholder={t("map_note_ph")}
              maxLength={300}
              rows={2}
              className="mt-3 w-full rounded-xl border border-ink/15 px-3 py-2 text-sm"
            />

            {createErr && (
              <p className="mt-2 text-xs font-semibold text-red-600">
                {createErr}
              </p>
            )}

            <div className="mt-4 flex justify-end gap-2">
              <button
                type="button"
                onClick={() => setCreateKind(null)}
                disabled={creating}
                className="rounded-full px-4 py-2 text-sm font-semibold text-ink-muted hover:bg-ink/5"
              >
                {t("map_create_cancel")}
              </button>
              <button
                type="button"
                onClick={submitCreate}
                disabled={creating}
                className="rounded-full bg-owner px-5 py-2 text-sm font-bold text-white shadow-sm transition hover:bg-owner-dark disabled:opacity-60"
              >
                {creating ? "⌛" : t("map_create_submit")}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function CategoryChip({
  label,
  emoji,
  active,
  onClick,
}: {
  label: string;
  emoji: string;
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`inline-flex items-center gap-1.5 rounded-full border px-3 py-1.5 text-xs font-semibold transition ${
        active
          ? "border-transparent text-white"
          : "border-ink/15 bg-white text-ink hover:border-ink/30"
      }`}
      style={active ? { backgroundColor: "#1f8a4c", borderColor: "#1f8a4c" } : undefined}
    >
      <span aria-hidden="true">{emoji}</span>
      <span>{label}</span>
    </button>
  );
}
