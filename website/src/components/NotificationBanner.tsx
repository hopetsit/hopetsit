"use client";

import { useCallback, useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import { useSocketEvent } from "@/lib/useSocket";
import {
  AppNotification,
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
  const [items, setItems] = useState<AppNotification[]>([]);
  const [loaded, setLoaded] = useState(false);

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
    if (n.readAt) return;
    setItems((prev) =>
      prev.map((x) => (x.id === n.id ? { ...x, readAt: new Date().toISOString() } : x)),
    );
    try {
      await markNotificationRead(n.id);
    } catch {
      /* best-effort */
    }
  }

  async function onMarkAll() {
    setItems((prev) => prev.map((x) => ({ ...x, readAt: x.readAt ?? new Date().toISOString() })));
    try {
      await markAllNotificationsRead();
    } catch {
      /* best-effort */
    }
  }

  // N'affiche rien tant que pas chargé OU si zéro notif (pas de bandeau vide
  // inutile sous le titre).
  if (!loaded || items.length === 0) return null;

  return (
    <section className="mt-6 rounded-2xl border border-ink/5 bg-white p-4 shadow-card">
      <div className="mb-3 flex items-center justify-between">
        <h2 className="flex items-center gap-2 font-display text-lg font-extrabold text-ink">
          <span>🔔</span>
          {t("notif_banner_title")}
          {unread.length > 0 && (
            <span className="rounded-full bg-owner px-2 py-0.5 text-xs font-bold text-white">
              {unread.length}
            </span>
          )}
        </h2>
        {unread.length > 0 && (
          <button
            type="button"
            onClick={onMarkAll}
            className="text-xs font-semibold text-owner hover:underline"
          >
            {t("notif_mark_all_read")}
          </button>
        )}
      </div>

      <ul className="flex flex-col gap-2">
        {items.slice(0, 8).map((n) => (
          <li key={n.id}>
            <button
              type="button"
              onClick={() => onItemClick(n)}
              className={`flex w-full items-start gap-3 rounded-xl border px-3 py-2.5 text-left transition hover:bg-bg-soft ${
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
          </li>
        ))}
      </ul>
    </section>
  );
}
