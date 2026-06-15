"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useT } from "@/lib/i18n/LanguageProvider";
import { useSocketEvent } from "@/lib/useSocket";
import {
  AppNotification,
  clearAllNotifications,
  deleteNotification,
  getMyNotifications,
  markAllNotificationsRead,
  markNotificationRead,
} from "@/lib/api";

/**
 * v409 — Daniel : « sous le titre de mon compte web, rajouter le bandeau de
 * notifications comme sur l'app (demandes reçues, acceptations, paiements) ».
 * Réutilise l'API mobile GET /notifications/my — donc 100% synchronisé avec
 * l'app (même flux Notification côté backend). Se rafraîchit en temps réel via
 * les events socket déjà émis (booking:paid / accepted, application:new,
 * notification.new).
 */
/**
 * v409 — Daniel : "quand on clique sur la notif, ça doit nous amener au bon
 * onglet ou action". Route web cible selon le type + data de la notification.
 * Renvoie null si aucune action pertinente (on se contente de marquer lu).
 */
function routeForNotification(n: AppNotification): string | null {
  const ty = (n.type || "").toLowerCase();
  const d = (n.data || {}) as Record<string, unknown>;
  const conversationId = typeof d.conversationId === "string" ? d.conversationId : "";
  const bookingId = typeof d.bookingId === "string" ? d.bookingId : "";

  // Suivi en direct (PawFollow) — carte dans le chat, sinon page de balade.
  if (ty.includes("tracking") || ty.includes("pawfollow") || ty.includes("follow")) {
    if (conversationId) return `/chat?c=${conversationId}`;
    if (bookingId) return `/walk/${bookingId}`;
    return "/chat";
  }
  // Messages → chat (deep-link conversation).
  if (ty.includes("message") || ty.includes("chat")) {
    return conversationId ? `/chat?c=${conversationId}` : "/chat";
  }
  // Demandes d'amis → page amis ; autres demandes/candidatures → réservations.
  if (ty.includes("friend")) return "/friends/live";
  if (ty.includes("application") || ty.includes("candidat") || ty.includes("request"))
    return "/bookings";
  // Paiements / réservations / acceptations / refus / annulations → réservations.
  if (
    ty.includes("paid") || ty.includes("payment") || ty.includes("payout") ||
    ty.includes("booking") || ty.includes("accept") || ty.includes("refus") ||
    ty.includes("declin") || ty.includes("reject") || ty.includes("cancel")
  ) {
    return "/bookings";
  }
  // Avis → profil ; abonnements/promo/boost → boutique.
  if (ty.includes("review") || ty.includes("rating")) return "/profile";
  if (
    ty.includes("promo") || ty.includes("subscription") || ty.includes("premium") ||
    ty.includes("pawspot") || ty.includes("boost")
  ) {
    return "/boutique";
  }
  return null;
}

function iconForType(type: string): string {
  const t = (type || "").toLowerCase();
  if (t.includes("paid") || t.includes("payment") || t.includes("payout")) return "💰";
  if (t.includes("accept")) return "✅";
  if (t.includes("refus") || t.includes("declin") || t.includes("reject")) return "❌";
  if (t.includes("tracking") || t.includes("follow")) return "📍";
  if (t.includes("message") || t.includes("chat")) return "💬";
  if (t.includes("application") || t.includes("request") || t.includes("friend"))
    return "👋";
  if (t.includes("review") || t.includes("rating")) return "⭐";
  return "🔔";
}

export default function NotificationBanner() {
  const { t } = useT();
  const router = useRouter();
  const [items, setItems] = useState<AppNotification[]>([]);
  const [loaded, setLoaded] = useState(false);
  // v411 — Daniel : "le bandeau en liste déroulée gêne". On le replie en une
  // BARRE COMPACTE (🔔 + compteur) ; le clic ouvre un panneau défilant. Fermé
  // par défaut → plus de longue liste sous le titre.
  const [open, setOpen] = useState(false);

  const refresh = useCallback(async () => {
    try {
      const list = await getMyNotifications(20);
      setItems(list);
    } catch {
      /* silencieux : le bandeau n'est pas critique */
    } finally {
      setLoaded(true);
    }
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  // Temps réel : on rafraîchit quand un event pertinent arrive (le backend a
  // déjà créé la Notification correspondante via sendNotification).
  useSocketEvent("notification.new", () => refresh());
  useSocketEvent("booking:paid", () => refresh());
  useSocketEvent("booking:accepted", () => refresh());
  useSocketEvent("application:new", () => refresh());

  const unread = items.filter((n) => !n.readAt);

  async function onItemClick(n: AppNotification) {
    // Marque lu (optimiste) puis route vers le bon onglet/action.
    if (!n.readAt) {
      setItems((prev) =>
        prev.map((x) =>
          x.id === n.id ? { ...x, readAt: new Date().toISOString() } : x,
        ),
      );
      markNotificationRead(n.id).catch(() => {});
    }
    const route = routeForNotification(n);
    if (route) router.push(route);
  }

  async function onMarkAll() {
    setItems((prev) => prev.map((x) => ({ ...x, readAt: x.readAt ?? new Date().toISOString() })));
    try {
      await markAllNotificationsRead();
    } catch {
      /* best-effort */
    }
  }

  // v409 — effacer une notif (× sur l'item).
  async function onDelete(id: string) {
    setItems((prev) => prev.filter((x) => x.id !== id));
    try {
      await deleteNotification(id);
    } catch {
      /* best-effort */
    }
  }

  // v409 — tout effacer. v411 : on resynchronise avec le serveur après coup
  // pour éviter qu'un refetch concurrent (socket) ne les fasse réapparaître.
  async function onClearAll() {
    setItems([]);
    try {
      await clearAllNotifications();
      await refresh();
    } catch {
      /* best-effort */
    }
  }

  // N'affiche rien tant que pas chargé OU si zéro notif.
  if (!loaded || items.length === 0) return null;

  return (
    <section className="mt-6 overflow-hidden rounded-2xl border border-ink/5 bg-white shadow-card">
      {/* Barre compacte (repliée par défaut) — clic pour ouvrir le panneau. */}
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        className="flex w-full items-center justify-between px-4 py-3 text-left transition hover:bg-bg-soft"
      >
        <span className="flex items-center gap-2 font-display text-base font-extrabold text-ink">
          <span>🔔</span>
          {t("notif_banner_title")}
          {unread.length > 0 && (
            <span className="rounded-full bg-owner px-2 py-0.5 text-xs font-bold text-white">
              {unread.length}
            </span>
          )}
        </span>
        <span className="flex items-center gap-2 text-ink-muted">
          <span className="text-xs">{items.length}</span>
          <svg
            className={`h-4 w-4 transition-transform ${open ? "rotate-180" : ""}`}
            viewBox="0 0 20 20"
            fill="currentColor"
            aria-hidden="true"
          >
            <path
              fillRule="evenodd"
              d="M5.23 7.21a.75.75 0 011.06.02L10 11.17l3.71-3.94a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z"
              clipRule="evenodd"
            />
          </svg>
        </span>
      </button>

      {/* Panneau défilant, uniquement quand ouvert. */}
      {open && (
        <div className="border-t border-ink/5 px-4 pb-4 pt-3">
          <div className="mb-2 flex justify-end gap-3">
            {unread.length > 0 && (
              <button
                type="button"
                onClick={onMarkAll}
                className="text-xs font-semibold text-owner hover:underline"
              >
                {t("notif_mark_all_read")}
              </button>
            )}
            <button
              type="button"
              onClick={onClearAll}
              className="text-xs font-semibold text-ink-muted hover:underline"
            >
              {t("notif_clear_all")}
            </button>
          </div>
          <ul className="flex max-h-[22rem] flex-col gap-2 overflow-y-auto pr-1">
            {items.map((n) => (
              <li key={n.id} className="relative">
                <button
                  type="button"
                  onClick={() => onItemClick(n)}
                  className={`flex w-full items-start gap-3 rounded-xl border py-2.5 pl-3 pr-9 text-left transition hover:bg-bg-soft ${
                    n.readAt
                      ? "border-transparent bg-bg-soft/40"
                      : "border-owner/20 bg-owner-light/30"
                  }`}
                >
                  <span className="mt-0.5 text-xl">{iconForType(n.type)}</span>
                  <span className="min-w-0 flex-1">
                    <span className="flex items-center gap-2">
                      <span className="truncate font-semibold text-ink">{n.title}</span>
                      {!n.readAt && (
                        <span className="h-2 w-2 shrink-0 rounded-full bg-owner" aria-hidden />
                      )}
                    </span>
                    {n.body && (
                      <span className="mt-0.5 block text-sm text-ink-muted line-clamp-2">
                        {n.body}
                      </span>
                    )}
                    <span className="mt-0.5 block text-xs text-ink-muted/70">
                      {new Date(n.createdAt).toLocaleString()}
                    </span>
                  </span>
                </button>
                <button
                  type="button"
                  aria-label={t("notif_clear_all")}
                  onClick={(e) => {
                    e.stopPropagation();
                    onDelete(n.id);
                  }}
                  className="absolute right-2 top-2 flex h-6 w-6 items-center justify-center rounded-full text-ink-muted transition hover:bg-ink/10 hover:text-ink"
                >
                  ✕
                </button>
              </li>
            ))}
          </ul>
        </div>
      )}
    </section>
  );
}
