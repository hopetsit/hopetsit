"use client";

// v23.1 part 243 round 3 — Page "Mes amis en direct".
// URL: /friends/live
//
// Daniel : "il faut mettre a jour le site web tout le paw follow suivre
// les utilisateurs rien nest fais". Cette page est l'equivalent web de la
// PawMap mobile en mode social :
//   1. Liste tous les amis acceptes (GET /friends)
//   2. Pour chacun, fetch leur derniere position connue (GET /friends/:id/last-position)
//      en parallele — best-effort, 403 si l'ami a coupe son toggle.
//   3. Affiche une Leaflet map avec un halo par role + ecoute les events
//      socket map:friend-position / map:friend-offline pour le live.

import dynamic from "next/dynamic";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import {
  ApiError,
  FriendItem,
  getFriendLastPosition,
  getMyFriends,
  getStoredUser,
} from "@/lib/api";
import { useSocket } from "@/lib/useSocket";
import type { FriendLivePosition } from "@/components/FriendsLiveMap";

const FriendsLiveMap = dynamic(() => import("@/components/FriendsLiveMap"), {
  ssr: false,
  loading: () => (
    <div className="flex h-[65vh] min-h-[450px] items-center justify-center rounded-2xl border border-ink/5 bg-bg-soft text-ink-muted">
      Chargement de la carte…
    </div>
  ),
});

function roleFromModel(model: string): "walker" | "sitter" | "owner" {
  const m = (model || "").toLowerCase();
  if (m === "walker") return "walker";
  if (m === "sitter") return "sitter";
  return "owner";
}

export default function FriendsLivePage() {
  const { t } = useT();
  const router = useRouter();
  const [friends, setFriends] = useState<FriendItem[]>([]);
  const [initialPositions, setInitialPositions] = useState<FriendLivePosition[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Initialise le socket pour que la map recoive les events temps reel.
  useSocket();

  useEffect(() => {
    if (!getStoredUser()) {
      router.replace("/login");
      return;
    }
    (async () => {
      setLoading(true);
      try {
        const list = await getMyFriends();
        // Filtre : on garde seulement les amis acceptes non supprimes.
        const accepted = list.filter(
          (f) => f.status === "accepted" && !f.other?.deleted,
        );
        setFriends(accepted);

        // Fetch en parallele les dernieres positions connues. Si l'ami a
        // coupe son toggle, /last-position renvoie 403 → on l'ignore.
        // v23.1 part 244d — fix Vercel build TS error : `satisfies` ne
        // widen pas le type, donc role: "walker"|"sitter"|"owner" reste
        // narrow et le filter type-predicate FriendLivePosition (qui
        // accepte aussi "family") refuse l'assignation. Cast explicite.
        const posResults: (FriendLivePosition | null)[] = await Promise.all(
          accepted.map(async (f): Promise<FriendLivePosition | null> => {
            if (!f.other?.id) return null;
            try {
              const p = await getFriendLastPosition(f.other.id);
              if (!p || p.lat == null || p.lng == null) return null;
              return {
                userId: f.other.id,
                role: roleFromModel(f.other.model),
                name: f.other.name || "Ami",
                avatar: f.other.avatar,
                lat: p.lat,
                lng: p.lng,
                at: new Date().toISOString(),
              };
            } catch {
              return null;
            }
          }),
        );
        setInitialPositions(
          posResults.filter((p): p is FriendLivePosition => p !== null),
        );
      } catch (e) {
        if (e instanceof ApiError && e.status === 401) {
          router.replace("/login");
          return;
        }
        setError(e instanceof Error ? e.message : "Loading failed");
      } finally {
        setLoading(false);
      }
    })();
  }, [router]);

  if (loading) {
    return (
      <div className="mx-auto max-w-5xl px-4 py-24 text-center text-ink-muted">
        {t("common_loading")}
      </div>
    );
  }

  if (error) {
    return (
      <div className="mx-auto max-w-5xl px-4 py-24">
        <Link
          href="/dashboard"
          className="text-sm text-ink-muted hover:text-ink"
        >
          ← {t("nav_dashboard")}
        </Link>
        <p className="mt-6 text-center text-red-700">{error}</p>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-6xl px-4 py-8 md:py-12">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-2">
        <Link
          href="/dashboard"
          className="text-sm text-ink-muted hover:text-ink"
        >
          ← {t("nav_dashboard")}
        </Link>
        <Link
          href="/map"
          className="text-sm text-ink-muted hover:text-ink"
        >
          🗺️ PawMap
        </Link>
      </div>

      <h1 className="font-display text-3xl font-extrabold md:text-4xl">
        Mes amis en direct
      </h1>
      <p className="mt-2 text-ink-muted">
        {friends.length === 0 ? (
          <>
            Vous n&apos;avez pas encore d&apos;amis sur HoPetSit. Telechargez
            l&apos;app pour ajouter des proches et activer le partage de
            position.
          </>
        ) : (
          <>
            {friends.length} ami{friends.length > 1 ? "s" : ""} accepte
            {friends.length > 1 ? "s" : ""}. Halo violet pour la famille,
            vert pour walker, bleu pour sitter, orange pour owner. La carte
            se met a jour automatiquement quand un ami partage sa position
            depuis l&apos;app.
          </>
        )}
      </p>

      <div className="mt-8">
        <FriendsLiveMap
          friends={friends}
          initialPositions={initialPositions}
        />
      </div>

      {/* Liste des amis sous la map */}
      {friends.length > 0 && (
        <div className="mt-8">
          <h2 className="font-display text-xl font-bold">Liste des amis</h2>
          <div className="mt-4 grid grid-cols-1 gap-3 md:grid-cols-2 lg:grid-cols-3">
            {friends.map((f) => {
              const role = roleFromModel(f.other.model);
              const dotColor =
                role === "walker"
                  ? "bg-green-500"
                  : role === "sitter"
                    ? "bg-blue-500"
                    : "bg-orange-500";
              const isOnline = initialPositions.some(
                (p) => p.userId === f.other.id,
              );
              return (
                <div
                  key={f.id}
                  className="flex items-center gap-3 rounded-2xl border border-ink/5 bg-white p-4 shadow-card"
                >
                  {f.other.avatar ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={f.other.avatar}
                      alt=""
                      className="h-10 w-10 rounded-full object-cover"
                    />
                  ) : (
                    <div className="grid h-10 w-10 place-items-center rounded-full bg-bg-soft text-sm font-bold text-ink-muted">
                      {(f.other.name || "?")
                        .split(/\s+/)
                        .map((w) => w[0] || "")
                        .slice(0, 2)
                        .join("")
                        .toUpperCase()}
                    </div>
                  )}
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-semibold text-ink">
                      {f.other.name || "Ami"}
                    </p>
                    <p className="text-xs text-ink-muted capitalize">{role}</p>
                  </div>
                  <span
                    className={`inline-block h-2.5 w-2.5 rounded-full ${
                      isOnline ? dotColor : "bg-slate-300"
                    }`}
                    title={
                      isOnline
                        ? "Position partagee"
                        : "Position non partagee"
                    }
                  />
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* Info box */}
      <div className="mt-8 rounded-2xl border border-ink/5 bg-bg-soft px-4 py-3 text-xs text-ink-muted">
        💡 La position d&apos;un ami n&apos;apparait que s&apos;il a active
        le partage dans l&apos;application mobile, ou s&apos;il dispose
        d&apos;un abonnement PawFollow actif. Vous pouvez gerer ces autorisations
        depuis votre liste d&apos;amis sur le telephone.
      </div>
    </div>
  );
}
