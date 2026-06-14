"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
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
  const { t } = useT();
  const router = useRouter();

  const id = postId(post);
  const ownerObj =
    post.owner ||
    (typeof post.ownerId === "object" ? (post.ownerId as { id?: string; _id?: string; name?: string }) : undefined);
  const ownerId = String(ownerObj?.id || (ownerObj as { _id?: string })?._id || (typeof post.ownerId === "string" ? post.ownerId : "") || "");
  const ownerName = ownerObj?.name || "";

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
    .map((d) => new Date(d as string).toLocaleDateString())
    .join(" → ");

  return (
    <div className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          {!isOwner && ownerName && (
            <p className="text-sm font-bold text-ink">{ownerName}</p>
          )}
          {post.isOwnerBoosted && (
            <span className="mt-0.5 inline-block rounded-full bg-owner-light px-2 py-0.5 text-xs font-bold text-owner-dark">
              🚀 {t("posts_boosted")}
            </span>
          )}
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

      {Array.isArray(post.serviceTypes) && post.serviceTypes.length > 0 && (
        <div className="mt-3 flex flex-wrap gap-1.5">
          {post.serviceTypes.map((s) => (
            <span key={s} className="rounded-full bg-bg-soft px-2.5 py-1 text-xs font-medium text-ink">
              {svcLabel(s)}
            </span>
          ))}
        </div>
      )}

      {dateRange && <p className="mt-2 text-xs text-ink-muted">📅 {dateRange}</p>}
      {post.notes && <p className="mt-1 text-xs text-ink-muted">📝 {post.notes}</p>}

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
