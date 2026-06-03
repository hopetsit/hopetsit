"use client";

// v23.1 part 246 — Page "Mes amis en direct" (deep refonte).
// URL: /friends/live
//
// Daniel : "ameliorer liste amis et famille et quand je clic sur le profil
// jle geolocalise pour le suivre comme sa si un sitter ou walker ou famille
// promene mon chien je peux aussi le voir sur le web arrange tt sa au mieux
// et deep".
//
// Refonte :
//   1. Fetch en parallele : friends + family members + last positions
//   2. Liste split en 2 sections : Famille (avec ring violet) puis Amis
//   3. Chaque tile est CLIQUABLE → flyTo + ouvre le popup sur la map
//   4. Bouton "Suivre" CTA explicite sur chaque tile
//   5. Tous les textes via t() (parite avec mobile)

import dynamic from "next/dynamic";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import {
  ApiError,
  FamilyMember,
  FriendItem,
  getFriendLastPosition,
  getMyFamily,
  getMyFriends,
  getStoredUser,
} from "@/lib/api";
import { useSocket } from "@/lib/useSocket";
import type { FriendLivePosition } from "@/components/FriendsLiveMap";

const FriendsLiveMap = dynamic(() => import("@/components/FriendsLiveMap"), {
  ssr: false,
  loading: () => (
    <div className="flex h-[65vh] min-h-[450px] items-center justify-center rounded-2xl border border-ink/5 bg-bg-soft text-ink-muted">
      ⌛
    </div>
  ),
});

function roleFromModel(model: string): "walker" | "sitter" | "owner" {
  const m = (model || "").toLowerCase();
  if (m === "walker") return "walker";
  if (m === "sitter") return "sitter";
  return "owner";
}

// Couleurs role pour le badge dans la tile + le dot online indicator.
function roleColor(role: "walker" | "sitter" | "owner"): string {
  if (role === "walker") return "#16A34A"; // vert
  if (role === "sitter") return "#2563EB"; // bleu
  return "#EF4324"; // owner orange brand
}

export default function FriendsLivePage() {
  const { t } = useT();
  const router = useRouter();
  const [friends, setFriends] = useState<FriendItem[]>([]);
  const [familyMembers, setFamilyMembers] = useState<FamilyMember[]>([]);
  const [initialPositions, setInitialPositions] = useState<FriendLivePosition[]>(
    [],
  );
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  // v246 — userId du friend selectionne (tile click). Passe a FriendsLiveMap
  // qui flyTo dessus et ouvre son popup.
  const [selectedUserId, setSelectedUserId] = useState<string | undefined>();

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
        // 1) Fetch friends + family en parallele.
        const [friendList, familyResp] = await Promise.all([
          getMyFriends(),
          getMyFamily(),
        ]);
        const accepted = friendList.filter(
          (f) => f.status === "accepted" && !f.other?.deleted,
        );
        setFriends(accepted);
        // v23.1 part 248 — Daniel : "mes amis en direct y manque famille".
        // Cause : v246 filtrait uniquement les actives -> walker invite
        // mais pas encore accepte (status='pending') etait masque -> la
        // section Famille restait vide. Maintenant on garde TOUTES les
        // entrees famille avec un id, et on tag chaque tile avec son
        // status pour afficher un badge "En attente" sur les pending.
        const allFamily = (familyResp.members || []).filter((m) => !!m.id);
        setFamilyMembers(allFamily);

        // 2) Fetch les dernieres positions connues : on prend les ids
        // uniques de la fusion amis + famille (un membre famille peut
        // ne pas etre dans la friend list classique). Pour les family
        // members hors friendList on injecte une FriendItem synthetique
        // dans la map cote FriendsLiveMap via le tableau friends elargi.
        const allIds = new Set<string>();
        for (const f of accepted) {
          if (f.other?.id) allIds.add(f.other.id);
        }
        for (const m of allFamily) {
          if (m.id) allIds.add(m.id);
        }
        const idArr = Array.from(allIds);

        // Map id -> (role, name, avatar) pour construire les
        // FriendLivePosition. On preferer le friend item si dispo, sinon
        // le family member.
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

  // Family ID set pour passer au FriendsLiveMap + tag les tiles.
  const familyIds = useMemo(
    () => familyMembers.map((m) => m.id),
    [familyMembers],
  );
  const familyIdSet = useMemo(() => new Set(familyIds), [familyIds]);

  // Liste "Famille" tiles : on injecte les family members. Si un family
  // member est aussi friend, on prend le nom/avatar du friend (plus a jour).
  // v248 — on propage le status pour afficher un badge "En attente" sur
  // les pending et permettre le filtrage cote "Suivre tout le monde".
  const familyTiles = useMemo(() => {
    return familyMembers.map((m) => {
      const friend = friends.find((f) => f.other?.id === m.id);
      return {
        id: m.id,
        role: roleFromModel(friend?.other?.model || m.role),
        name: friend?.other?.name || m.name || "Famille",
        avatar: friend?.other?.avatar || m.avatar || "",
        status: m.status, // 'active' | 'pending' | ...
        pawSpotTier: friend?.other?.pawSpotTier ?? null,
      };
    });
  }, [familyMembers, friends]);

  // Liste "Amis" tiles : tous les friends qui ne sont pas dans famille
  // (sinon on les afficherait 2 fois). La famille a sa propre section.
  const friendTiles = useMemo(() => {
    return friends
      .filter((f) => f.other?.id && !familyIdSet.has(f.other.id))
      .map((f) => ({
        id: f.other!.id,
        role: roleFromModel(f.other!.model),
        name: f.other!.name || "Ami",
        avatar: f.other!.avatar || "",
        pawSpotTier: f.other!.pawSpotTier ?? null,
      }));
  }, [friends, familyIdSet]);

  // v23.1.276 — Daniel : "ya pas amis sitter et walker comme categorie qui
  // apparaissent dans suivre mes amis". On éclate les amis (hors famille) par
  // RÔLE pour avoir des sections distinctes : Amis (owners), Pet-sitters,
  // Promeneurs — cohérent avec le code couleur rôle de l'app.
  const ownerFriendTiles = useMemo(
    () => friendTiles.filter((f) => f.role !== "sitter" && f.role !== "walker"),
    [friendTiles],
  );
  const sitterFriendTiles = useMemo(
    () => friendTiles.filter((f) => f.role === "sitter"),
    [friendTiles],
  );
  const walkerFriendTiles = useMemo(
    () => friendTiles.filter((f) => f.role === "walker"),
    [friendTiles],
  );

  // Synthetic friends list (friends + family) pour resoudre les events
  // socket dans FriendsLiveMap pour la famille hors-friendList.
  const friendsForMap = useMemo<FriendItem[]>(() => {
    const out = [...friends];
    const inFriendIds = new Set(
      friends.map((f) => f.other?.id).filter(Boolean) as string[],
    );
    for (const m of familyMembers) {
      if (!m.id || inFriendIds.has(m.id)) continue;
      // Construit une FriendItem synthetique pour permettre au composant
      // map d'indexer le membre famille (le modele utilise est PascalCase).
      const ModelMap: Record<string, "Owner" | "Sitter" | "Walker"> = {
        owner: "Owner",
        sitter: "Sitter",
        walker: "Walker",
      };
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
    return out;
  }, [friends, familyMembers]);

  function handleTileClick(userId: string) {
    setSelectedUserId(userId);
    // Scroll up smoothly so the user voit la map bouger.
    if (typeof window !== "undefined") {
      window.scrollTo({ top: 0, behavior: "smooth" });
    }
  }

  // v23.1 part 248 — Daniel : "un bouton suivre tout le monde". Au clic
  // on annule la selection (selectedUserId=undefined) et la map fitBounds
  // sur TOUTES les positions en ligne. On declenche le fit en remountant
  // l'effet : on flip un counter qu'on passe au map component.
  const [followAllNonce, setFollowAllNonce] = useState(0);
  function handleFollowAll() {
    setSelectedUserId(undefined);
    setFollowAllNonce((n) => n + 1);
    if (typeof window !== "undefined") {
      window.scrollTo({ top: 0, behavior: "smooth" });
    }
  }

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

  const totalAccepted = friendTiles.length + familyTiles.length;
  const totalOnline = initialPositions.length;

  return (
    <div className="mx-auto max-w-6xl px-4 py-8 md:py-12">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-2">
        <Link
          href="/dashboard"
          className="text-sm text-ink-muted hover:text-ink"
        >
          ← {t("nav_dashboard")}
        </Link>
        <Link href="/map" className="text-sm text-ink-muted hover:text-ink">
          🗺️ {t("nav_pawmap")}
        </Link>
      </div>

      <h1 className="font-display text-3xl font-extrabold md:text-4xl">
        {t("friends_live_title")}
      </h1>
      <p className="mt-2 text-ink-muted">
        {totalAccepted === 0
          ? t("friends_live_empty")
          : t("friends_live_subtitle")
              .replace("{total}", String(totalAccepted))
              .replace("{online}", String(totalOnline))}
      </p>

      {/* v248 — Toolbar : bouton "Suivre tout le monde" si on a au moins
          1 personne en ligne. fitBoundsAll permet a la map de se recadrer
          sur l'ensemble des amis + famille en direct. */}
      {totalOnline > 0 && (
        <div className="mt-6 flex flex-wrap items-center gap-2">
          <button
            type="button"
            onClick={handleFollowAll}
            className="inline-flex items-center gap-2 rounded-full bg-walker px-4 py-2 text-sm font-semibold text-white shadow-cta hover:bg-walker-dark"
          >
            <span>🐾</span>
            <span>{t("friends_live_follow_all_btn")}</span>
            <span className="ml-1 rounded-full bg-white/25 px-2 py-0.5 text-[10px] font-bold">
              {totalOnline}
            </span>
          </button>
        </div>
      )}

      <div className="mt-4">
        <FriendsLiveMap
          friends={friendsForMap}
          initialPositions={initialPositions}
          familyIds={familyIds}
          selectedUserId={selectedUserId}
          fitAllNonce={followAllNonce}
        />
      </div>

      {/* v246 — Section Famille (ring violet) en premier puisqu'elle prime
          dans la hierarchie sociale. */}
      {familyTiles.length > 0 && (
        <FriendsSection
          title={t("friends_live_section_family")}
          tiles={familyTiles}
          onlinePositions={initialPositions}
          selectedUserId={selectedUserId}
          onTileClick={handleTileClick}
          isFamily
          t={t}
        />
      )}

      {/* v23.1.276 — Sections AMIS éclatées par rôle : Amis (owners),
          Pet-sitters, Promeneurs — pour que les amis sitter/walker aient
          leur propre catégorie (sans famille, pas de doublon). */}
      {ownerFriendTiles.length > 0 && (
        <FriendsSection
          title={t("friends_live_section_friends")}
          tiles={ownerFriendTiles}
          onlinePositions={initialPositions}
          selectedUserId={selectedUserId}
          onTileClick={handleTileClick}
          t={t}
        />
      )}

      {sitterFriendTiles.length > 0 && (
        <FriendsSection
          title={`🐾 ${t("role_sitter")}`}
          tiles={sitterFriendTiles}
          onlinePositions={initialPositions}
          selectedUserId={selectedUserId}
          onTileClick={handleTileClick}
          t={t}
        />
      )}

      {walkerFriendTiles.length > 0 && (
        <FriendsSection
          title={`🐕 ${t("role_walker")}`}
          tiles={walkerFriendTiles}
          onlinePositions={initialPositions}
          selectedUserId={selectedUserId}
          onTileClick={handleTileClick}
          t={t}
        />
      )}

      {/* Info box pedagogique. */}
      <div className="mt-8 rounded-2xl border border-ink/5 bg-bg-soft px-4 py-3 text-xs text-ink-muted">
        💡 {t("friends_live_info_box")}
      </div>
    </div>
  );
}

// ─── Section list (Famille ou Amis) ─────────────────────────────────────

type Tile = {
  id: string;
  role: "walker" | "sitter" | "owner";
  name: string;
  avatar: string;
  // v23.1 part 248 — facultatif (seul Famille l'utilise) : si 'pending',
  // l'invitation n'a pas encore ete acceptee -> on affiche un badge en
  // attente sur le tile et on n'attend pas de position.
  status?: "active" | "pending" | "declined" | string;
  // v23.1.280 — tier PawSpot actif de l'ami ('bronze'|'silver'|'gold'|
  // 'platinum') → anneau doré/bleu sur l'avatar (parité app).
  pawSpotTier?: string | null;
};

// v23.1.280 — Daniel : "si l'ami a l'option PawSpot, anneau doré ou bleu selon
// l'option". Gold/Platinum → doré (#F59E0B), Silver/Bronze → bleu (#3B82F6),
// sinon null. Identique au switch Dart de _FriendTile.
function pawSpotRingColor(tier?: string | null): string | null {
  switch ((tier || "").toLowerCase()) {
    case "gold":
    case "platinum":
      return "#F59E0B"; // doré
    case "silver":
    case "bronze":
      return "#3B82F6"; // bleu
    default:
      return null;
  }
}

function FriendsSection({
  title,
  tiles,
  onlinePositions,
  selectedUserId,
  onTileClick,
  isFamily = false,
  t,
}: {
  title: string;
  tiles: Tile[];
  onlinePositions: FriendLivePosition[];
  selectedUserId?: string;
  onTileClick: (id: string) => void;
  isFamily?: boolean;
  t: (k: string) => string;
}) {
  const onlineSet = new Set(onlinePositions.map((p) => p.userId));
  return (
    <div className="mt-8">
      <div className="mb-3 flex items-center gap-2">
        {isFamily && (
          <span
            aria-hidden="true"
            className="inline-block h-3 w-3 rounded-full border-2"
            style={{ borderColor: "#8B5CF6" }}
          />
        )}
        <h2 className="font-display text-xl font-bold">
          {title}{" "}
          <span className="text-sm font-normal text-ink-muted">
            ({tiles.length})
          </span>
        </h2>
      </div>
      <div className="grid grid-cols-1 gap-3 md:grid-cols-2 lg:grid-cols-3">
        {tiles.map((tile) => {
          const isOnline = onlineSet.has(tile.id);
          const isSelected = selectedUserId === tile.id;
          const color = roleColor(tile.role);
          // v23.1.280 — anneau avatar : PawSpot (doré/bleu) prioritaire, sinon
          // violet famille, sinon transparent (parité _FriendTile app).
          const pawRing = pawSpotRingColor(tile.pawSpotTier);
          const avatarRing = pawRing ?? (isFamily ? "#8B5CF6" : null);
          return (
            <button
              key={tile.id}
              type="button"
              onClick={() => onTileClick(tile.id)}
              className={`group relative flex items-center gap-3 rounded-2xl border bg-white p-4 text-left shadow-card transition hover:border-ink/15 hover:shadow-lg ${
                isSelected ? "ring-2 ring-walker" : "border-ink/5"
              }`}
              title={
                isOnline
                  ? t("friends_live_tile_follow_action")
                  : t("friends_live_tile_offline_hint")
              }
            >
              {/* Avatar + anneau : PawSpot doré/bleu > violet famille > rien */}
              <div
                className="relative flex h-12 w-12 flex-shrink-0 items-center justify-center rounded-full"
                style={{
                  backgroundColor: color,
                  border: avatarRing
                    ? `3px solid ${avatarRing}`
                    : "3px solid transparent",
                }}
              >
                {tile.avatar ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={tile.avatar}
                    alt=""
                    className="h-full w-full rounded-full object-cover"
                  />
                ) : (
                  <span className="text-sm font-bold text-white">
                    {(tile.name || "?")
                      .split(/\s+/)
                      .map((w) => w[0] || "")
                      .slice(0, 2)
                      .join("")
                      .toUpperCase()}
                  </span>
                )}
              </div>
              {/* Nom + role */}
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-semibold text-ink">
                  {tile.name}
                </p>
                <div className="mt-0.5 flex items-center gap-1.5">
                  <span
                    className="rounded-full px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider text-white"
                    style={{ backgroundColor: color }}
                  >
                    {t(`role_${tile.role}`)}
                  </span>
                  {isFamily && (
                    <span
                      className="rounded-full px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider"
                      style={{
                        backgroundColor: "#F3E8FF",
                        color: "#7E22CE",
                      }}
                    >
                      {t("friends_live_badge_family")}
                    </span>
                  )}
                  {/* v23.1.280 — badge PawSpot doré/bleu si l'ami a l'option. */}
                  {pawRing && (
                    <span
                      className="rounded-full px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider"
                      style={{
                        backgroundColor: `${pawRing}26`,
                        color: pawRing,
                      }}
                    >
                      📍 {t("friends_live_badge_pawspot")}
                    </span>
                  )}
                  {/* v248 — badge "En attente" pour les pending family. */}
                  {tile.status === "pending" && (
                    <span
                      className="rounded-full px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider"
                      style={{
                        backgroundColor: "#FEF3C7",
                        color: "#92400E",
                      }}
                    >
                      {t("friends_live_badge_pending")}
                    </span>
                  )}
                </div>
              </div>
              {/* Indicateur online + CTA Suivre. */}
              <div className="flex flex-col items-end gap-1">
                <span
                  className={`inline-block h-2.5 w-2.5 rounded-full ${
                    isOnline ? "animate-pulse" : ""
                  }`}
                  style={{
                    backgroundColor: isOnline ? color : "#CBD5E1",
                  }}
                  title={
                    isOnline
                      ? t("friends_live_dot_online")
                      : t("friends_live_dot_offline")
                  }
                />
                {isOnline && (
                  <span
                    className="rounded-full px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider text-white"
                    style={{ backgroundColor: color }}
                  >
                    {t("friends_live_tile_follow_action")}
                  </span>
                )}
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
}
