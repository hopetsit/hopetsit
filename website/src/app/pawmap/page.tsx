"use client";

import dynamic from "next/dynamic";
import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { PawMapHeroBadge } from "@/components/PawMapHeroBadge";
import { AppIcon } from "@/components/AppIcon";
import { PageTitle } from "@/components/PageTitle";
import { useT } from "@/lib/i18n/LanguageProvider";
import { useAuth } from "@/lib/useAuth";
import { getCitySupply, type PublicProvider } from "@/lib/api";
import { ROLE_COLOR } from "@/lib/pawmapLegend";

// v493 — page PawMap recentrée sur la carte et la communauté.
// v562 — refonte minimaliste façon Apple (Daniel, 13/09).
// 24/09/2026 — LOT B, étape 2 du plan de LEO validé par Daniel : LA VRAIE
// CARTE SANS COMPTE. Les captures de l'app laissent la place à une carte
// Leaflet réelle (gardiens et promeneurs floutés à ~1 km), une recherche de
// ville, le nombre de prestataires autour, et « Réserver » sur chaque épingle
// (« Inscris-toi pour les contacter » sans compte). Mêmes routes, clés i18n
// conservées + nouvelles (pawmap_public_*).

const PublicPawMap = dynamic(() => import("@/components/PublicPawMap"), {
  ssr: false,
  loading: () => (
    <div className="flex h-[60vh] min-h-[420px] items-center justify-center rounded-[28px] bg-[#FAF1EC] text-[#6E4F48]">
      <span className="h-6 w-6 animate-spin rounded-full border-2 border-[#C92A12] border-t-transparent" />
    </div>
  ),
});

const PARIS: [number, number] = [48.8566, 2.3522];

export default function PawMapPage() {
  const { t, lang } = useT();
  const { user, ready } = useAuth();
  const [center, setCenter] = useState<[number, number]>(PARIS);
  const [cityLabel, setCityLabel] = useState("Paris");
  const [cityQuery, setCityQuery] = useState("");
  const [searching, setSearching] = useState(false);
  const [searchError, setSearchError] = useState(false);
  const [providers, setProviders] = useState<PublicProvider[]>([]);
  const [supply, setSupply] = useState<{ sitters: number; walkers: number } | null>(null);
  const [locating, setLocating] = useState(false);
  const [focusKey, setFocusKey] = useState(0);
  const router = useRouter();

  // 25/09 (PawMap 584, point 11) — connecté, « PawMap » = MA PawMap : la carte
  // connectée de /map (mes amis, les membres autour de moi, mes demandes, mon
  // rond « Moi », le rail complet). La ville ou la position demandée suit.
  const loggedIn = ready && !!user;
  useEffect(() => {
    if (!loggedIn) return;
    let qs = "";
    try { qs = window.location.search || ""; } catch { /* ignore */ }
    router.replace(`/map${qs}`);
  }, [loggedIn, router]);

  // Ville demandée par l'accueil (/pawmap?city=Lyon) ou lien partagé (?lat&lng).
  useEffect(() => {
    try {
      const qs = new URLSearchParams(window.location.search);
      const qlat = parseFloat(qs.get("lat") || "");
      const qlng = parseFloat(qs.get("lng") || "");
      if (Number.isFinite(qlat) && Number.isFinite(qlng)) {
        setCenter([qlat, qlng]);
        setCityLabel(qs.get("city") || "");
        return;
      }
      const c = qs.get("city");
      if (c) {
        setCityQuery(c);
        void geocode(c);
      }
    } catch { /* ignore */ }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Compteur « N gardiens · M promeneurs autour de {ville} » (route publique).
  useEffect(() => {
    let alive = true;
    getCitySupply({ lat: center[0], lng: center[1], radiusKm: 25, city: cityLabel || undefined }).then((s) => {
      if (alive && s) setSupply({ sitters: s.sitters, walkers: s.walkers });
    });
    return () => { alive = false; };
  }, [center, cityLabel]);

  async function geocode(q: string) {
    setSearching(true);
    setSearchError(false);
    try {
      const resp = await fetch(
        `https://nominatim.openstreetmap.org/search?format=json&limit=1&accept-language=${encodeURIComponent(lang)}&q=${encodeURIComponent(q)}`,
      );
      const results = (await resp.json()) as { lat: string; lon: string; display_name?: string }[];
      const hit = results?.[0];
      if (hit && Number.isFinite(parseFloat(hit.lat))) {
        setCenter([parseFloat(hit.lat), parseFloat(hit.lon)]);
        setCityLabel(q.trim());
        setFocusKey((k) => k + 1);
      } else {
        setSearchError(true);
      }
    } catch {
      setSearchError(true);
    } finally {
      setSearching(false);
    }
  }

  function locateMe() {
    if (typeof navigator === "undefined" || !("geolocation" in navigator)) return;
    setLocating(true);
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setCenter([pos.coords.latitude, pos.coords.longitude]);
        setCityLabel("");
        setFocusKey((k) => k + 1);
        setLocating(false);
      },
      () => setLocating(false),
      { enableHighAccuracy: false, timeout: 8000, maximumAge: 60000 },
    );
  }

  const cats = [
    { icon: "shield-check" as const, label: t("map_cat_vet") },
    { icon: "shop" as const, label: t("map_cat_shop") },
    { icon: "pets" as const, label: t("map_cat_groomer") },
    { icon: "globe" as const, label: t("map_cat_park") },
    { icon: "sun" as const, label: t("map_cat_beach") },
    { icon: "pin" as const, label: t("map_cat_water") },
    { icon: "star" as const, label: t("map_cat_trainer") },
    { icon: "home" as const, label: t("map_cat_hotel") },
    { icon: "clock" as const, label: t("map_cat_restaurant") },
  ];

  const nearest = useMemo(() => providers.slice(0, 6), [providers]);
  const roleLabel: Record<string, string> = { sitter: t("role_sitter"), walker: t("role_walker") };

  // Tous les hooks sont au-dessus (piège du 20/09) : on peut sortir ici.
  if (loggedIn) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center bg-white">
        <span className="h-7 w-7 animate-spin rounded-full border-2 border-[#C92A12] border-t-transparent" aria-label="PawMap" />
      </div>
    );
  }

  return (
    <div className="bg-white">
      <PageTitle titleKey="page_title_pawmap" descKey="pawmap_sub" />
      {/* ── 1. EN-TÊTE COURT ── logo sur sa tuile, titre, puis LA CARTE. */}
      <div className="mx-auto max-w-6xl px-4 pb-6 pt-10 text-center md:pt-14">
        <PawMapHeroBadge />
        <h1 className="mt-5 font-display text-[2.2rem] font-bold leading-[1.05] tracking-[-0.03em] text-[#231715] md:text-5xl">
          {t("pawmap_public_title")}
        </h1>
        <p className="mx-auto mt-4 max-w-2xl text-base text-[#6E4F48] md:text-lg">{t("pawmap_public_sub")}</p>

        {/* Recherche de ville + « Autour de moi » — même géocodeur que l'app. */}
        <form
          onSubmit={(e) => { e.preventDefault(); if (cityQuery.trim()) void geocode(cityQuery); }}
          className="mx-auto mt-6 flex max-w-xl items-center gap-2 rounded-full bg-[#FAF1EC] p-1.5 pl-4"
        >
          <AppIcon name="pin" size={20} color="#C92A12" className="shrink-0" />
          <input
            value={cityQuery}
            onChange={(e) => { setCityQuery(e.target.value); setSearchError(false); }}
            placeholder={t("map_search_city_ph")}
            aria-label={t("map_search_city_ph")}
            className="min-w-0 flex-1 bg-transparent text-sm outline-none placeholder:text-ink-soft"
          />
          <button
            type="button"
            onClick={locateMe}
            aria-label={t("map_locate_btn")}
            title={t("map_locate_btn")}
            className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-white text-[#C92A12] transition hover:bg-owner-light"
          >
            {locating ? <span className="h-4 w-4 animate-spin rounded-full border-2 border-[#C92A12] border-t-transparent" /> : <AppIcon name="locate" size={20} />}
          </button>
          <button
            type="submit"
            disabled={searching || !cityQuery.trim()}
            className="min-h-[40px] shrink-0 rounded-full bg-[#231715] px-4 text-sm font-semibold text-white transition hover:bg-black disabled:cursor-not-allowed disabled:opacity-40"
          >
            {searching ? "…" : t("map_search_city_btn")}
          </button>
        </form>
        {searchError && <p className="mt-2 text-xs font-semibold text-[#C92A12]">{t("map_search_city_none")}</p>}

        {supply && (supply.sitters > 0 || supply.walkers > 0) && (
          <p className="mt-4 inline-flex flex-wrap items-center justify-center gap-x-3 gap-y-1 rounded-full bg-[#FAF1EC] px-4 py-2 text-sm font-semibold text-[#231715]">
            <span className="inline-flex items-center gap-1.5" style={{ color: ROLE_COLOR.sitter }}>
              <AppIcon name="home" size={16} color={ROLE_COLOR.sitter} />
              {t("pawmap_public_sitters").replace("{count}", String(supply.sitters))}
            </span>
            <span className="inline-flex items-center gap-1.5" style={{ color: ROLE_COLOR.walker }}>
              <AppIcon name="walker" size={16} color={ROLE_COLOR.walker} />
              {t("pawmap_public_walkers").replace("{count}", String(supply.walkers))}
            </span>
            {cityLabel && <span className="text-[#6E4F48]">· {cityLabel}</span>}
          </p>
        )}
      </div>

      {/* ── 2. LA CARTE (vraie) ── */}
      <div className="mx-auto max-w-6xl px-4">
        <PublicPawMap center={center} zoom={12} focusKey={focusKey} height="min(62vh, 620px)" onProviders={setProviders} />
        <p className="mt-3 flex flex-wrap items-center justify-center gap-x-4 gap-y-1 text-center text-xs text-[#6E4F48]">
          <span className="inline-flex items-center gap-1.5"><AppIcon name="lock" size={14} />{t("pawmap_public_privacy")}</span>
          {!(ready && user) && (
            <Link href="/signup" className="inline-flex items-center gap-1 font-semibold text-owner hover:underline">
              {t("pawmap_signup_to_contact")} <AppIcon name="arrow-right" size={14} />
            </Link>
          )}
        </p>
      </div>

      {/* ── 3. LES PLUS PROCHES ── fiches courtes, « Réserver » en 2 clics. */}
      {nearest.length > 0 && (
        <div className="mx-auto max-w-6xl px-4 pt-10">
          <h2 className="font-display text-2xl font-bold tracking-[-0.02em] text-[#231715] md:text-3xl">{t("pawmap_public_nearest")}</h2>
          <ul className="mt-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {nearest.map((p) => {
              const color = ROLE_COLOR[p.role];
              const bookHref = `/book/${p.role}/${p.id}`;
              const href = ready && user ? bookHref : `/signup?next=${encodeURIComponent(bookHref)}`;
              return (
                <li key={p.id} className="flex items-center gap-3 rounded-[20px] bg-[#FAF1EC] p-4">
                  {p.avatar ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={p.avatar} alt="" className="h-12 w-12 shrink-0 rounded-full object-cover" style={{ border: `2.5px solid ${color}` }} />
                  ) : (
                    <span className="grid h-12 w-12 shrink-0 place-items-center rounded-full text-white" style={{ background: color }}>
                      <AppIcon name={p.role === "walker" ? "walker" : "home"} size={22} color="#fff" />
                    </span>
                  )}
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-sm font-bold text-[#231715]">{p.name || roleLabel[p.role]}</span>
                    <span className="block truncate text-xs font-semibold" style={{ color }}>
                      {roleLabel[p.role]}
                      {p.rating > 0 ? ` · ${p.rating.toFixed(1)} ★` : ""}
                      {p.identityVerified ? ` · ${t("trust_id_title")}` : ""}
                    </span>
                  </span>
                  <Link href={href} className="grid h-11 w-11 shrink-0 place-items-center rounded-full text-white" style={{ background: color }} aria-label={t("map_member_book")} title={t("map_member_book")}>
                    <AppIcon name="calendar" size={20} color="#fff" />
                  </Link>
                </li>
              );
            })}
          </ul>
        </div>
      )}

      <div className="mx-auto max-w-6xl px-4 py-16 md:py-20">
        {/* ── 4. CE QU'ON TROUVE AUSSI (dans l'app et sur /map connecté) ── */}
        <h2 className="text-center font-display text-2xl font-bold tracking-[-0.02em] text-[#231715] md:text-4xl">
          {t("pawmap_categories")}
        </h2>
        <p className="mx-auto mt-3 max-w-2xl text-center text-sm text-[#6E4F48] md:text-base">{t("pawmap_public_places_note")}</p>
        <div className="mt-8 grid grid-cols-2 gap-3 sm:grid-cols-3">
          {cats.map((c) => (
            <div key={c.label} className="flex items-center gap-3 rounded-[18px] bg-[#FAF1EC] p-3.5">
              <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-white text-[#C92A12]"><AppIcon name={c.icon} size={20} /></span>
              <span className="text-sm font-semibold text-[#231715]">{c.label}</span>
            </div>
          ))}
        </div>

        {/* ── 5. COMMENT ÇA MARCHE (3 étapes) ── */}
        <h2 className="mt-16 text-center font-display text-2xl font-bold tracking-[-0.02em] text-[#231715] md:text-4xl">
          {t("nav_how")}
        </h2>
        <div className="mt-8 grid gap-4 md:grid-cols-3">
          {[t("pawmap_step1"), t("pawspot_desc"), t("pawmap_pawpoints_desc")].map((body, i) => (
            <div key={i} className="rounded-[24px] bg-[#FAF1EC] p-6">
              <span className="font-display text-sm font-semibold tracking-widest text-owner">0{i + 1}</span>
              <p className="mt-3 text-[15px] leading-relaxed text-[#231715]">{body}</p>
            </div>
          ))}
        </div>

        {/* ── 6. PAWPREMIUM + APP ── une seule bande, pas de doublon. */}
        <section className="mt-16 flex flex-col items-center gap-6 rounded-[28px] bg-[#231715] p-8 text-center md:flex-row md:p-12 md:text-left">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/pawpremium_logo.svg" alt="PawPremium" width={72} height={72} className="shrink-0" />
          <div className="flex-1">
            <h2 className="font-display text-2xl font-bold tracking-[-0.02em] text-[#FFD34D]">PawPremium</h2>
            <p className="mx-auto mt-2 max-w-xl text-[15px] leading-relaxed text-[#FDF8F7] md:mx-0">{t("pawpremium_subtitle")}</p>
          </div>
          <div className="flex shrink-0 flex-col gap-2 sm:flex-row md:flex-col">
            <Link href="/boutique" className="inline-flex min-h-[44px] items-center justify-center rounded-full bg-white px-6 text-sm font-semibold text-[#231715] transition hover:bg-[#F0E3DF]">
              {t("pawpremium_cta")}
            </Link>
            <Link href="/download" className="inline-flex min-h-[44px] items-center justify-center gap-2 rounded-full bg-owner px-6 text-sm font-semibold text-white transition hover:bg-owner-dark">
              <AppIcon name="download" size={16} color="#fff" />{t("nav_download")}
            </Link>
          </div>
        </section>
      </div>
    </div>
  );
}
