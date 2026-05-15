"use client";

// v23.1 part 146 — Page recherche providers (sitters + walkers).
// Owner only — sitter/walker n'a pas vocation à chercher des providers.

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import {
  ApiError,
  getStoredUser,
  listSitters,
  listWalkers,
  ProviderProfile,
} from "@/lib/api";

type ProviderKind = "sitter" | "walker";

export default function SearchPage() {
  const { t } = useT();
  const router = useRouter();
  const [kind, setKind] = useState<ProviderKind>("sitter");
  const [city, setCity] = useState("");
  const [providers, setProviders] = useState<ProviderProfile[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const u = getStoredUser();
    if (!u) {
      router.replace("/login");
      return;
    }
    if (u.role !== "owner") {
      router.replace("/dashboard");
      return;
    }
    fetchList(kind, "");
  }, [router]);

  async function fetchList(k: ProviderKind, cityFilter: string) {
    setLoading(true);
    setError(null);
    try {
      const res =
        k === "walker"
          ? await listWalkers({ city: cityFilter || undefined, limit: 30 })
          : await listSitters({ city: cityFilter || undefined, limit: 30 });
      setProviders(res.providers);
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) {
        router.replace("/login");
        return;
      }
      setError(e instanceof Error ? e.message : "Search failed");
    } finally {
      setLoading(false);
    }
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    fetchList(kind, city.trim());
  }

  function switchKind(k: ProviderKind) {
    setKind(k);
    fetchList(k, city.trim());
  }

  return (
    <div className="mx-auto max-w-5xl px-4 py-12 md:py-16">
      <div className="mb-6">
        <Link href="/dashboard" className="text-sm text-ink-muted hover:text-ink">
          ← Dashboard
        </Link>
      </div>

      <h1 className="font-display text-3xl font-extrabold md:text-4xl">
        Trouver un pet-sitter
      </h1>
      <p className="mt-2 text-ink-muted">
        Parcours les profils disponibles. Tu peux ensuite envoyer une demande
        directement depuis le navigateur.
      </p>

      {/* Toggle sitter / walker */}
      <div className="mt-8 inline-flex rounded-full bg-ink/5 p-1">
        <button
          type="button"
          onClick={() => switchKind("sitter")}
          className={`rounded-full px-5 py-2 text-sm font-semibold transition ${
            kind === "sitter"
              ? "bg-sitter text-white shadow-sm"
              : "text-ink-muted hover:text-ink"
          }`}
        >
          🏡 Sitters
        </button>
        <button
          type="button"
          onClick={() => switchKind("walker")}
          className={`rounded-full px-5 py-2 text-sm font-semibold transition ${
            kind === "walker"
              ? "bg-walker text-white shadow-sm"
              : "text-ink-muted hover:text-ink"
          }`}
        >
          🚶 Walkers
        </button>
      </div>

      <form onSubmit={handleSubmit} className="mt-4 flex gap-2">
        <input
          type="text"
          value={city}
          onChange={(e) => setCity(e.target.value)}
          placeholder="Ville (Paris, Berlin, London…)"
          className="flex-1 rounded-full border border-ink/15 px-5 py-2.5 text-sm focus:border-walker focus:outline-none focus:ring-2 focus:ring-walker/20"
        />
        <button
          type="submit"
          className="rounded-full bg-ink px-5 py-2.5 text-sm font-semibold text-white hover:opacity-90"
        >
          Rechercher
        </button>
      </form>

      {error && (
        <div className="mt-6 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {loading ? (
        <div className="mt-12 text-center text-ink-muted">{t("common_loading")}</div>
      ) : providers.length === 0 ? (
        <div className="mt-12 rounded-3xl border border-dashed border-ink/15 px-6 py-16 text-center">
          <p className="text-2xl">🔍</p>
          <p className="mt-3 font-semibold text-ink">Aucun résultat</p>
          <p className="mt-1 text-sm text-ink-muted">
            Essaye une autre ville ou bascule sur l&apos;autre catégorie.
          </p>
        </div>
      ) : (
        <div className="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {providers.map((p) => (
            <ProviderCard key={p.id} provider={p} kind={kind} />
          ))}
        </div>
      )}
    </div>
  );
}

function ProviderCard({
  provider,
  kind,
}: {
  provider: ProviderProfile;
  kind: ProviderKind;
}) {
  const rating = provider.averageRating ?? provider.rating ?? 0;
  const startingPrice =
    kind === "walker"
      ? provider.walkRates?.walkSolo30 || provider.hourlyRate
      : provider.hourlyRate;
  const color = kind === "walker" ? "walker" : "sitter";

  return (
    <Link
      href={`/book/${kind}/${provider.id}`}
      className="group block rounded-2xl border border-ink/5 bg-white p-5 shadow-card transition hover:border-ink/15 hover:shadow-lg"
    >
      <div className="flex items-start gap-4">
        <div className="flex h-14 w-14 shrink-0 items-center justify-center overflow-hidden rounded-full bg-ink/10 text-xl font-bold text-ink-muted">
          {provider.avatar?.url ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={provider.avatar.url} alt="" className="h-full w-full object-cover" />
          ) : (
            provider.name?.charAt(0).toUpperCase() || "?"
          )}
        </div>
        <div className="min-w-0 flex-1">
          <div className="truncate text-base font-bold text-ink">{provider.name}</div>
          {provider.location?.city && (
            <div className="mt-0.5 text-xs text-ink-muted">
              📍 {provider.location.city}
            </div>
          )}
          {rating > 0 && (
            <div className="mt-1 text-xs text-amber-600">
              ★ {rating.toFixed(1)}
              {provider.reviewsCount ? (
                <span className="text-ink-muted"> ({provider.reviewsCount})</span>
              ) : null}
            </div>
          )}
        </div>
        {(provider.isBoosted || provider.isMapBoosted) && (
          <span className="rounded-full bg-amber-100 px-2 py-0.5 text-xs font-bold text-amber-800">
            ⭐ Top
          </span>
        )}
      </div>

      {provider.bio && (
        <p className="mt-3 line-clamp-2 text-xs text-ink-muted">{provider.bio}</p>
      )}

      <div className="mt-4 flex items-center justify-between">
        {startingPrice ? (
          <div className="text-sm">
            <span className="text-xs text-ink-muted">À partir de</span>{" "}
            <span className="font-bold text-ink">{startingPrice} €</span>
          </div>
        ) : (
          <div className="text-xs text-ink-muted">Tarif sur demande</div>
        )}
        <span className={`rounded-full bg-${color} px-3 py-1 text-xs font-semibold text-white group-hover:opacity-90`}>
          Réserver →
        </span>
      </div>
    </Link>
  );
}
