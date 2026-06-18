"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import { petTraitLabel } from "@/lib/petTraits";
import {
  ApiError,
  RequestPost,
  addPostComment,
  contactOwnerAboutPost,
  deletePost,
  getMyPosts,
  getRequestPosts,
  getStoredUser,
  postId,
  toggleLikePost,
} from "@/lib/api";

// v402 — Annonces sur le SITE (parité app), 100% additif :
//   • Owner   : ses annonces + bouton "Publier une annonce".
//   • Sitter/Walker : feed des demandes (filtré par rôle côté backend) avec
//     Contacter (→ chat), like et commentaire.
// v404 — emoji + libellé des types d'animaux (annonce).
const ANIMAL_EMOJI: Record<string, string> = {
  dog: "🐶", cat: "🐱", nac: "🐹", bird: "🐦", reptile: "🦎", other: "🐾",
};
function animalLabel(t: (k: string) => string, k: string): string {
  const map: Record<string, string> = {
    dog: t("posts_animal_dog"),
    cat: t("posts_animal_cat"),
    nac: t("posts_animal_nac"),
    bird: t("posts_animal_bird"),
    reptile: t("posts_animal_reptile"),
    other: t("posts_animal_other"),
  };
  return map[k] || k;
}

export default function PostsPage() {
  const { t } = useT();
  const router = useRouter();

  const [role, setRole] = useState<string | null>(null);
  const [posts, setPosts] = useState<RequestPost[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const u = getStoredUser();
    if (!u) {
      router.replace("/login");
      return;
    }
    setRole(u.role);
    (async () => {
      setLoading(true);
      setError(null);
      try {
        const list = u.role === "owner" ? await getMyPosts() : await getRequestPosts();
        setPosts(list);
      } catch (e) {
        if (e instanceof ApiError && e.status === 401) {
          router.replace("/login");
          return;
        }
        setError(e instanceof Error ? e.message : "Error");
      } finally {
        setLoading(false);
      }
    })();
  }, [router]);

  const isOwner = role === "owner";

  return (
    <div className="mx-auto max-w-2xl px-4 py-12 md:py-16">
      <div className="flex items-center justify-between gap-3">
        <h1 className="font-display text-2xl font-extrabold tracking-tight md:text-3xl">
          {isOwner ? t("posts_my_title") : t("posts_feed_title")}
        </h1>
        {isOwner && (
          <Link
            href="/posts/create"
            className="rounded-full bg-owner px-4 py-2 text-sm font-semibold text-white shadow-cta hover:bg-owner-dark"
          >
            + {t("posts_create_cta")}
          </Link>
        )}
      </div>

      {loading && <p className="mt-10 text-center text-sm text-ink-muted">{t("common_loading")}</p>}
      {error && <p className="mt-10 text-center text-sm text-owner-dark">{error}</p>}

      {!loading && !error && posts.length === 0 && (
        <p className="mt-16 text-center text-sm text-ink-muted">
          {isOwner ? t("posts_none_owner") : t("posts_none_provider")}
        </p>
      )}

      <div className="mt-8 space-y-4">
        {posts.map((p) => (
          <PostCard
            key={postId(p)}
            post={p}
            isOwner={isOwner}
            onDeleted={() => setPosts((prev) => prev.filter((x) => postId(x) !== postId(p)))}
          />
        ))}
      </div>
    </div>
  );
}

function PostCard({
  post,
  isOwner,
  onDeleted,
}: {
  post: RequestPost;
  isOwner: boolean;
  onDeleted: () => void;
}) {
  const { t, lang } = useT();
  const router = useRouter();
  // v450 — Daniel : dates/heures de la publication suivent la LANGUE choisie
  // (avant : locale du navigateur → ex. site en FR mais date « 6/17/2026 »
  // façon US, perçu comme une erreur de traduction).
  const dtLocale =
    { fr: "fr-FR", en: "en-GB", es: "es-ES", de: "de-DE", it: "it-IT", pt: "pt-PT" }[
      lang as string
    ] || "fr-FR";

  const id = postId(post);
  const ownerObj =
    post.owner ||
    (typeof post.ownerId === "object"
      ? (post.ownerId as { id?: string; _id?: string; name?: string; bio?: string })
      : undefined);
  const ownerId = String(ownerObj?.id || (ownerObj as { _id?: string })?._id || (typeof post.ownerId === "string" ? post.ownerId : "") || "");
  const ownerName = ownerObj?.name || "";
  const ownerBio = (ownerObj as { bio?: string })?.bio || "";
  const ownerAvatar = (ownerObj as { avatar?: string })?.avatar || "";

  const svcLabel = (s: string) =>
    s === "house_sitting"
      ? t("posts_svc_house_sitting")
      : s === "day_care"
        ? t("posts_svc_day_care")
        : s === "dog_walking"
          ? t("posts_svc_dog_walking")
          : s;

  const [contacting, setContacting] = useState(false);
  const [contactMsg, setContactMsg] = useState<string | null>(null);
  const [locked, setLocked] = useState(false);
  const [liked, setLiked] = useState(false);
  const [likeBusy, setLikeBusy] = useState(false);
  const [comment, setComment] = useState("");
  const [commentSent, setCommentSent] = useState(false);
  const [deleting, setDeleting] = useState(false);

  async function onContact() {
    if (!ownerId) return;
    setContacting(true);
    setContactMsg(null);
    setLocked(false);
    try {
      const { conversationId } = await contactOwnerAboutPost(ownerId, t("posts_contact_default"));
      if (conversationId) {
        router.push(`/chat?c=${conversationId}`);
      } else {
        router.push("/chat");
      }
    } catch (e) {
      if (e instanceof ApiError && (e.status === 402 || e.status === 403)) {
        setLocked(true);
      } else if (e instanceof ApiError && e.status === 401) {
        router.replace("/login");
        return;
      } else {
        setContactMsg(e instanceof Error ? e.message : t("posts_error"));
      }
    } finally {
      setContacting(false);
    }
  }

  async function onLike() {
    setLikeBusy(true);
    try {
      await toggleLikePost(id);
      setLiked((v) => !v);
    } catch { /* ignore */ } finally {
      setLikeBusy(false);
    }
  }

  async function onComment(e: React.FormEvent) {
    e.preventDefault();
    if (!comment.trim()) return;
    try {
      await addPostComment(id, comment.trim());
      setComment("");
      setCommentSent(true);
      setTimeout(() => setCommentSent(false), 2500);
    } catch { /* ignore */ }
  }

  async function onDelete() {
    if (!window.confirm(t("posts_delete_confirm"))) return;
    setDeleting(true);
    try {
      await deletePost(id);
      onDeleted();
    } catch { setDeleting(false); }
  }

  const dateRange = [post.startDate, post.endDate]
    .filter(Boolean)
    .map((d) => new Date(d as string).toLocaleDateString(dtLocale))
    .join(" → ");

  // v450 — Daniel : « il manque l'heure ». Le backend ne renvoie pas de champ
  // `timeSlot` (le Post n'a pas de champ heure dédié) : l'horaire est porté par
  // la PARTIE HEURE de startDate/endDate (comme l'app via
  // PostDateLabel.timeLabel). On la dérive donc ici. On masque 00:00 (= aucune
  // heure réellement saisie). `post.timeSlot` reste prioritaire s'il existe.
  const fmtTime = (d?: string) => {
    if (!d) return "";
    const dt = new Date(d);
    if (Number.isNaN(dt.getTime())) return "";
    if (dt.getHours() === 0 && dt.getMinutes() === 0) return "";
    return dt.toLocaleTimeString(dtLocale, { hour: "2-digit", minute: "2-digit" });
  };
  const startTime = fmtTime(post.startDate);
  const endTime = fmtTime(post.endDate);
  const timeLabel =
    post.timeSlot ||
    (startTime && endTime && startTime !== endTime
      ? `${startTime} → ${endTime}`
      : startTime || endTime);

  // Lieu de garde : combine serviceLocation (at_owner/at_sitter/both) et le
  // legacy houseSittingVenue (owners_home/sitters_home).
  const locationLabel = (() => {
    const sl = post.serviceLocation;
    if (sl === "at_owner") return t("posts_loc_at_owner");
    if (sl === "at_sitter") return t("posts_loc_at_sitter");
    if (sl === "both") return t("posts_loc_both");
    if (post.houseSittingVenue === "owners_home") return t("posts_loc_at_owner");
    if (post.houseSittingVenue === "sitters_home") return t("posts_loc_at_sitter");
    return "";
  })();

  const pets = post.pets || [];
  const serviceLabels = (post.serviceTypes || []).map(svcLabel).join(" · ");
  // Résumé animaux pour la grille : nombre + types (legacy animalTypes quand
  // aucun animal détaillé n'est attaché au post).
  const animalTypesLabel = (post.animalTypes || [])
    .map((k) => `${ANIMAL_EMOJI[k] || "🐾"} ${animalLabel(t, k)}`)
    .join(" · ");
  const animalsSummary =
    pets.length > 0
      ? String(pets.length)
      : post.animalCount
        ? `${post.animalCount}${animalTypesLabel ? ` · ${animalTypesLabel}` : ""}`
        : animalTypesLabel || "";

  // Animaux ayant des données de caractère (bio ou traits) → carte « Caractère ».
  const petsWithCharacter = pets.filter(
    (p) => (p.bio && p.bio.trim()) || (p.characterTraits && p.characterTraits.length > 0),
  );

  return (
    <div className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
      {/* En-tête : propriétaire + badge boost + supprimer (owner). */}
      <div className="flex items-start justify-between gap-3">
        <div className="flex min-w-0 items-center gap-2.5">
          {!isOwner && (ownerAvatar ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={ownerAvatar} alt="" className="h-9 w-9 rounded-full object-cover" />
          ) : ownerName ? (
            <span className="grid h-9 w-9 place-items-center rounded-full bg-owner-light text-sm font-bold text-owner-dark">
              {ownerName.slice(0, 1).toUpperCase()}
            </span>
          ) : null)}
          <div className="min-w-0">
            {!isOwner && ownerName && (
              <p className="truncate text-sm font-bold text-ink">{ownerName}</p>
            )}
            {post.isOwnerBoosted && (
              <span className="mt-0.5 inline-block rounded-full bg-owner-light px-2 py-0.5 text-xs font-bold text-owner-dark">
                🚀 {t("posts_boosted")}
              </span>
            )}
          </div>
        </div>
        {isOwner && (
          <button
            type="button"
            onClick={onDelete}
            disabled={deleting}
            className="shrink-0 rounded-full border border-ink/15 px-3 py-1 text-xs font-semibold text-ink-muted hover:border-red-300 hover:text-red-600 disabled:opacity-60"
          >
            {t("posts_delete")}
          </button>
        )}
      </div>

      {post.body && <p className="mt-2 whitespace-pre-wrap text-sm text-ink">{post.body}</p>}

      {/* v402 — photos de l'annonce */}
      {Array.isArray(post.images) && post.images.length > 0 && (
        <div className="mt-3 flex gap-2 overflow-x-auto">
          {post.images.map((im, i) => (
            // eslint-disable-next-line @next/next/no-img-element
            <img key={i} src={im.url} alt="" className="h-28 w-28 shrink-0 rounded-xl object-cover" />
          ))}
        </div>
      )}

      {/* Grille « Demande de réservation » : Dates / Lieu / Animaux / Service /
          Horaire (parité maquette app). */}
      <div className="mt-3 rounded-2xl border border-owner/15 bg-owner/5 p-3">
        <p className="mb-2 text-xs font-bold uppercase tracking-wide text-owner-dark">
          {t("posts_reservation_title")}
        </p>
        <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
          {dateRange && <ResCell icon="📅" label={t("posts_field_dates")} value={dateRange} />}
          {locationLabel && <ResCell icon="📍" label={t("posts_field_location")} value={locationLabel} />}
          {animalsSummary && <ResCell icon="🐾" label={t("posts_field_animals")} value={animalsSummary} />}
          {serviceLabels && <ResCell icon="🛎️" label={t("posts_field_service")} value={serviceLabels} />}
          {timeLabel && <ResCell icon="🕑" label={t("posts_field_time")} value={timeLabel} />}
          {post.notes && <ResCell icon="📝" label={t("posts_field_details")} value={post.notes} />}
        </div>
      </div>

      {/* Bande animaux : nom · race · âge · sexe + nombre de photos. */}
      {pets.length > 0 && (
        <div className="mt-3 space-y-2">
          {pets.map((p) => {
            const photosCount = (p.photos || []).filter((x) => x?.url).length;
            const meta = [
              p.breed,
              typeof p.age === "number" ? t("posts_age_years").replace("@n", String(p.age)) : "",
              p.sex === "male" ? t("posts_sex_male") : p.sex === "female" ? t("posts_sex_female") : "",
            ]
              .filter(Boolean)
              .join(" · ");
            return (
              <div key={p.id || p.petName} className="flex items-center gap-3 rounded-xl border border-ink/5 bg-bg-soft px-3 py-2">
                {p.avatar ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={p.avatar} alt="" className="h-10 w-10 rounded-full object-cover" />
                ) : (
                  <span className="grid h-10 w-10 place-items-center rounded-full bg-white text-lg">
                    {ANIMAL_EMOJI[p.category || "other"] || "🐾"}
                  </span>
                )}
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-semibold text-ink">{p.petName || t("posts_animal_other")}</p>
                  {meta && <p className="truncate text-xs text-ink-muted">{meta}</p>}
                </div>
                {photosCount > 0 && (
                  <span className="shrink-0 text-xs font-medium text-ink-muted">📷 {photosCount}</span>
                )}
              </div>
            );
          })}
        </div>
      )}

      {/* Caractère des animaux (bio + traits). */}
      {petsWithCharacter.length > 0 && (
        <div className="mt-3 rounded-2xl border border-ink/5 bg-white p-3 shadow-card">
          <p className="mb-2 text-sm font-bold text-ink">{t("posts_character_title")}</p>
          <div className="space-y-2.5">
            {petsWithCharacter.map((p) => (
              <div key={`char-${p.id || p.petName}`}>
                <p className="text-sm font-semibold text-ink">
                  {ANIMAL_EMOJI[p.category || "other"] || "🐾"} {p.petName}
                  {p.breed && <span className="font-normal text-ink-muted"> · {p.breed}</span>}
                </p>
                {p.characterTraits && p.characterTraits.length > 0 && (
                  <div className="mt-1 flex flex-wrap gap-1.5">
                    {p.characterTraits.map((tr) => (
                      <span key={tr} className="rounded-full bg-bg-soft px-2 py-0.5 text-xs text-ink">
                        {petTraitLabel(tr, lang as string)}
                      </span>
                    ))}
                  </div>
                )}
                {p.bio && p.bio.trim() && (
                  <p className="mt-1 text-xs text-ink-muted">{p.bio}</p>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* À propos de moi (propriétaire) — visible pour le prestataire. */}
      {!isOwner && ownerBio && ownerBio.trim() && (
        <div className="mt-3 rounded-2xl border border-ink/5 bg-bg-soft p-3">
          <p className="mb-1 text-sm font-bold text-ink">{t("posts_owner_about_title")}</p>
          <p className="text-sm text-ink-muted">{ownerBio}</p>
        </div>
      )}

      {/* Actions provider : Contacter + like + commentaire */}
      {!isOwner && (
        <div className="mt-4 space-y-3 border-t border-ink/5 pt-4">
          <div className="flex flex-wrap items-center gap-2">
            <button
              type="button"
              onClick={onContact}
              disabled={contacting || !ownerId}
              className="rounded-full bg-owner px-4 py-2 text-sm font-semibold text-white shadow-cta hover:bg-owner-dark disabled:opacity-60"
            >
              {contacting ? t("common_loading") : `💬 ${t("posts_contact")}`}
            </button>
            <button
              type="button"
              onClick={onLike}
              disabled={likeBusy}
              className="rounded-full border border-ink/15 px-3 py-2 text-sm font-semibold text-ink hover:border-ink/30 disabled:opacity-60"
            >
              {liked ? "❤️" : "🤍"} {t("posts_like")}
            </button>
          </div>

          {locked && (
            <p className="text-sm text-owner-dark">
              {t("posts_contact_locked")}{" "}
              <Link href="/boutique" className="font-semibold underline">
                {t("posts_go_premium")}
              </Link>
            </p>
          )}
          {contactMsg && <p className="text-sm text-owner-dark">{contactMsg}</p>}

          <form onSubmit={onComment} className="flex gap-2">
            <input
              value={comment}
              onChange={(e) => setComment(e.target.value)}
              placeholder={t("posts_comment_ph")}
              className="min-w-0 flex-1 rounded-full border border-ink/15 bg-bg-soft px-3.5 py-2 text-sm text-ink focus:border-owner focus:outline-none"
            />
            <button
              type="submit"
              className="rounded-full border border-ink/15 px-3 py-2 text-sm font-semibold text-ink hover:border-ink/30"
            >
              {t("posts_comment_send")}
            </button>
          </form>
          {commentSent && <p className="text-xs text-green-600">{t("posts_comment_done")}</p>}
        </div>
      )}
    </div>
  );
}

// Cellule de la grille « Demande de réservation » (icône + libellé + valeur).
function ResCell({ icon, label, value }: { icon: string; label: string; value: string }) {
  return (
    <div className="rounded-xl bg-white px-2.5 py-2">
      <p className="text-[11px] font-medium uppercase tracking-wide text-ink-soft">
        <span aria-hidden="true">{icon}</span> {label}
      </p>
      <p className="mt-0.5 break-words text-sm font-semibold text-ink">{value}</p>
    </div>
  );
}
