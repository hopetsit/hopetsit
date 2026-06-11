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
  MyBenefits,
  PawSpot,
  PawSpotType,
  POI_CATEGORY_LABELS,
  Poi,
  PoiCategory,
  RouteResult,
  getFriendLastPosition,
  getMyBenefits,
  getMyFamily,
  getMyFriends,
  getNearbyPawSpots,
  getNearbyPois,
  getPawSpotDirections,
  getStoredUser,
} from "@/lib/api";
import { useSocket, useSocketEvent } from "@/lib/useSocket";
import type { FriendLivePosition } from "@/components/FriendsLiveMap";

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

// Couleurs brand des chips couches (cf. mobile v353) :
// PawFollow violet / PawSpot doré, gris quand pas d'abonnement.
const PAWFOLLOW_VIOLET = "#7C3AED";
const PAWSPOT_GOLD = "#E8A00A";
const CHIP_GRAY = "#6B7280";

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
  const [center, setCenter] = useState<[number, number]>([48.8566, 2.3522]); // Paris default
  const [pois, setPois] = useState<Poi[]>([]);
  const [selectedCategory, setSelectedCategory] = useState<PoiCategory | "all">("all");
  const [loading, setLoading] = useState(true);
  const [fetching, setFetching] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [selectedPoi, setSelectedPoi] = useState<Poi | null>(null);

  // ── v23.1 carte unique — couches PawFollow / PawSpot + itinéraire ──────
  const [benefits, setBenefits] = useState<MyBenefits | null>(null);
  const [showFriends, setShowFriends] = useState(false);
  const [showSpots, setShowSpots] = useState(false);
  const [spots, setSpots] = useState<PawSpot[]>([]);
  const [friendsLoading, setFriendsLoading] = useState(false);
  const [friendsForMap, setFriendsForMap] = useState<FriendItem[]>([]);
  const [familyIds, setFamilyIds] = useState<string[]>([]);
  const [livePositions, setLivePositions] = useState<
    Map<string, FriendLivePosition>
  >(new Map());
  const friendsLoadedRef = useRef(false);
  const [route, setRoute] = useState<RouteResult | null>(null);
  const [routeLoading, setRouteLoading] = useState(false);
  const [directionsLocked, setDirectionsLocked] = useState(false);
  const [directionsError, setDirectionsError] = useState(false);

  // Connecte le socket pour recevoir les events temps réel amis/famille.
  useSocket();

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

  // Auth + géolocalisation au mount.
  useEffect(() => {
    if (!getStoredUser()) {
      router.replace("/login");
      return;
    }
    if (!("geolocation" in navigator)) {
      // Pas de géoloc dispo → on reste sur Paris.
      setLoading(false);
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const loc = { lat: pos.coords.latitude, lng: pos.coords.longitude };
        setUserLocation(loc);
        setCenter([loc.lat, loc.lng]);
        setLoading(false);
      },
      () => {
        // L'user a refusé la géoloc → fallback Paris.
        setLoading(false);
      },
      { timeout: 10000 },
    );
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
    fetchPois(center[0], center[1], selectedCategory);
  }, [loading, fetchPois, center, selectedCategory]);

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
      const idArr = Array.from(infoById.keys());
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
        for (const p of posResults) {
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

  function toggleFriendsLayer() {
    const next = !showFriends;
    setShowFriends(next);
    if (next && !friendsLoadedRef.current) {
      friendsLoadedRef.current = true;
      void loadFriends();
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

  const pawFollowSubscribed = !!(
    benefits?.pawFollowActive || benefits?.familyActive
  );
  const pawSpotSubscribed = !!benefits?.pawspotActive;

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
        {t("map_count_results").replace("{count}", String(pois.length))}
        {" "}
        {t("map_pan_hint")}
      </p>

      {/* v23.1 carte unique — chips couches PawFollow / PawSpots (une seule
          ligne, scroll horizontal sur mobile). */}
      <div className="mt-6 flex flex-nowrap items-center gap-2 overflow-x-auto pb-1">
        <LayerChip
          label={t("map_pawfollow_chip")}
          crown={pawFollowSubscribed}
          color={pawFollowSubscribed ? PAWFOLLOW_VIOLET : CHIP_GRAY}
          active={showFriends}
          onClick={toggleFriendsLayer}
        />
        <LayerChip
          label={`${t("map_pawspots_chip")} 🐾`}
          crown={pawSpotSubscribed}
          color={pawSpotSubscribed ? PAWSPOT_GOLD : CHIP_GRAY}
          active={showSpots}
          onClick={() => setShowSpots((v) => !v)}
        />
        {showFriends && (
          <span className="shrink-0 text-xs text-ink-muted">
            {friendsLoading
              ? t("common_loading")
              : t("map_live_count").replace(
                  "{count}",
                  String(livePositionsList.length),
                )}
          </span>
        )}
        {routeLoading && (
          <span className="shrink-0 text-xs text-ink-muted">⌛</span>
        )}
      </div>

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
          active={selectedCategory === "all"}
          onClick={() => setSelectedCategory("all")}
        />
        {ALL_CATEGORIES.map((cat) => (
          <CategoryChip
            key={cat}
            label={t(CAT_KEY_FOR_LANG[cat])}
            emoji={POI_CATEGORY_LABELS[cat].emoji}
            active={selectedCategory === cat}
            onClick={() => setSelectedCategory(cat)}
          />
        ))}
      </div>

      {error && (
        <div className="mt-4 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {/* Carte */}
      <div className="mt-6">
        <PoiMap
          center={center}
          pois={pois}
          userLocation={userLocation}
          selectedPoi={selectedPoi}
          onSelectPoi={setSelectedPoi}
          onMapMove={handleMapMove}
          spots={showSpots ? spots : []}
          spotTypeLabels={spotTypeLabels}
          friendPositions={showFriends ? livePositionsList : []}
          familyIds={familyIds}
          roleLabels={{
            owner: t("role_owner"),
            sitter: t("role_sitter"),
            walker: t("role_walker"),
          }}
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
          ? "border-walker bg-walker text-white"
          : "border-ink/15 bg-white text-ink hover:border-ink/30"
      }`}
    >
      <span aria-hidden="true">{emoji}</span>
      <span>{label}</span>
    </button>
  );
}

// v23.1 carte unique — chip toggle de couche (PawFollow / PawSpots). La
// couleur signale l'abonnement (violet/doré + 👑) ou gris sans abonnement ;
// l'état actif remplit le chip, inactif = outline.
function LayerChip({
  label,
  crown,
  color,
  active,
  onClick,
}: {
  label: string;
  crown: boolean;
  color: string;
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="inline-flex shrink-0 items-center gap-1 rounded-xl border px-2.5 py-1.5 text-[11px] font-bold transition"
      style={
        active
          ? { backgroundColor: color, borderColor: color, color: "#FFFFFF" }
          : {
              backgroundColor: "#FFFFFF",
              borderColor: `${color}66`,
              color,
            }
      }
    >
      <span>{label}</span>
      {crown && <span aria-hidden="true">👑</span>}
    </button>
  );
}
