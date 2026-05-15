"use client";

// v23.1 part 146 — PawMap interactive : la carte des points d'intérêt
// pet-friendly (vétos, parcs, plages, points d'eau, hôtels…). Auth required.
//
// Flow :
//   1. Récupère la géolocalisation du user (navigator.geolocation, fallback Paris)
//   2. Charge les POI dans un rayon de 10km via GET /map-pois/nearby
//   3. Affiche les markers sur OpenStreetMap (Leaflet)
//   4. Filtre par catégorie via toggle chips
//   5. Quand l'user pan la carte, refetch les POI autour du nouveau centre
//      (avec debounce pour pas spammer l'API).

import dynamic from "next/dynamic";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useRef, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import {
  ApiError,
  getNearbyPois,
  getStoredUser,
  POI_CATEGORY_LABELS,
  Poi,
  PoiCategory,
} from "@/lib/api";

const PoiMap = dynamic(() => import("@/components/PoiMap"), {
  ssr: false,
  loading: () => (
    <div className="flex h-[70vh] min-h-[450px] items-center justify-center rounded-2xl border border-ink/5 bg-bg-soft text-ink-muted">
      Chargement de la carte…
    </div>
  ),
});

// Tous les codes de catégorie POI.
const ALL_CATEGORIES = Object.keys(POI_CATEGORY_LABELS) as PoiCategory[];

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

  if (loading) {
    return (
      <div className="mx-auto max-w-5xl px-4 py-24 text-center text-ink-muted">
        Localisation en cours…
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-6xl px-4 py-8 md:py-12">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-2">
        <Link href="/dashboard" className="text-sm text-ink-muted hover:text-ink">
          ← Dashboard
        </Link>
        {fetching && (
          <span className="text-xs text-ink-muted">⌛ Recherche en cours…</span>
        )}
      </div>

      <h1 className="font-display text-3xl font-extrabold md:text-4xl">
        PawMap — Europe pet-friendly
      </h1>
      <p className="mt-2 text-ink-muted">
        {pois.length} lieux pet-friendly autour de toi (10 km).
        Déplace la carte pour explorer une autre zone.
      </p>

      {/* Filtre par catégorie */}
      <div className="mt-6 flex flex-wrap gap-2">
        <CategoryChip
          label="Tous"
          emoji="🗺️"
          active={selectedCategory === "all"}
          onClick={() => setSelectedCategory("all")}
        />
        {ALL_CATEGORIES.map((cat) => (
          <CategoryChip
            key={cat}
            label={POI_CATEGORY_LABELS[cat].label}
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
        />
      </div>

      {/* Détails du POI sélectionné */}
      {selectedPoi && (
        <div className="mt-6 rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
          <div className="flex items-start justify-between gap-3">
            <div>
              <div className="text-xs uppercase tracking-wider text-ink-muted">
                {POI_CATEGORY_LABELS[selectedPoi.category]?.emoji}{" "}
                {POI_CATEGORY_LABELS[selectedPoi.category]?.label}
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
              aria-label="Fermer"
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
                🌐 Site web
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
                <span className="ml-1 text-ink-muted">({selectedPoi.reviewsCount} avis)</span>
              ) : null}
            </div>
          )}
        </div>
      )}

      {/* Légende */}
      <div className="mt-8 rounded-2xl border border-ink/5 bg-bg-soft px-4 py-3 text-xs text-ink-muted">
        💡 Les POI sont remontés par la communauté HoPetSit + OpenStreetMap. Tu peux
        signaler un nouveau lieu directement depuis l&apos;app mobile (édition Premium).
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
