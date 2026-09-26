"use client";

// 26/09/2026 (589) — FENÊTRE D'ANNONCE de la PawMap, comme l'app
// (frontend/lib/views/map/widgets/pawmap_announcement.dart) : à l'ouverture de
// /map, la PREMIÈRE annonce jamais vue par ce navigateur, UNE fois (l'id est
// mémorisé dès l'affichage, clé pawmap_announce_seen_v589). Les annonces
// « update » (mettre l'app à jour) sont ignorées : on ne met pas un site à jour.

import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import { getMapAnnouncements, type MapAnnouncement } from "@/lib/api";
import { AppIcon } from "@/components/AppIcon";

const SEEN_KEY = "pawmap_announce_seen_v589";

function readSeen(): string[] {
  try {
    const raw = localStorage.getItem(SEEN_KEY);
    const v = raw ? JSON.parse(raw) : [];
    return Array.isArray(v) ? v.map(String) : [];
  } catch {
    return [];
  }
}
function markSeen(id: string) {
  try {
    const seen = readSeen();
    if (!seen.includes(id)) localStorage.setItem(SEEN_KEY, JSON.stringify([...seen, id].slice(-100)));
  } catch { /* stockage indisponible : l'annonce pourra revenir, sans gravité */ }
}
function isWebUrl(u: string) {
  return /^https?:\/\//i.test(u);
}

export function PawMapAnnouncement({ enabled, dark = false }: { enabled: boolean; dark?: boolean }) {
  const { t, lang } = useT();
  const [item, setItem] = useState<MapAnnouncement | null>(null);

  useEffect(() => {
    if (!enabled) return;
    let stop = false;
    const tid = setTimeout(() => {
      getMapAnnouncements(lang)
        .then((list) => {
          if (stop) return;
          const seen = new Set(readSeen());
          const first = list.find((a) => a.kind !== "update" && !seen.has(a.id));
          if (!first) return;
          markSeen(first.id);
          setItem(first);
        })
        .catch(() => { /* hors ligne, CORS en local… : pas d'annonce */ });
    }, 900);
    return () => { stop = true; clearTimeout(tid); };
    // Une seule lecture par ouverture de la carte (la langue du moment).
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [enabled]);

  useEffect(() => {
    if (!item) return;
    const onKey = (e: KeyboardEvent) => { if (e.key === "Escape") setItem(null); };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [item]);

  if (!item) return null;
  const isLink = item.kind === "link" && isWebUrl(item.url);
  const close = () => setItem(null);
  const primary = () => {
    if (isLink) {
      try { window.open(item.url, "_blank", "noopener,noreferrer"); } catch { /* bloqué : rien */ }
    }
    close();
  };

  return (
    <div className="fixed inset-0 z-[3200] flex items-end justify-center bg-[#231715]/55 p-0 sm:items-center sm:p-4" role="dialog" aria-modal="true" aria-labelledby="pm-announce-title" onClick={close}>
      <div
        className="w-full max-w-md overflow-hidden rounded-t-[28px] shadow-[0_24px_60px_-18px_rgba(35,23,21,0.6)] sm:rounded-[28px]"
        style={{ background: dark ? "#231A22" : "#FFFFFF" }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Bandeau orange dégradé + icône. */}
        <div className="relative flex items-center gap-3 px-5 pb-4 pt-5" style={{ background: "linear-gradient(90deg,#E2503A 0%,#D83C28 55%,#B92425 100%)" }}>
          <span className="grid h-12 w-12 shrink-0 place-items-center rounded-full" style={{ background: "rgba(255,255,255,0.18)", border: "1.5px solid #FFFFFF", boxShadow: "0 8px 18px -8px rgba(80,14,6,0.7)" }}>
            {isLink ? (
              <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="#FFFFFF" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                <path d="M14 4h6v6M20 4l-9 9M18 14v4.5A1.5 1.5 0 0 1 16.5 20h-11A1.5 1.5 0 0 1 4 18.5v-11A1.5 1.5 0 0 1 5.5 6H10" />
              </svg>
            ) : (
              <AppIcon name="megaphone" size={22} color="#FFFFFF" />
            )}
          </span>
          <h2 id="pm-announce-title" className="min-w-0 flex-1 font-display text-lg font-bold leading-snug tracking-[-0.01em] text-white [overflow-wrap:anywhere]">
            {item.title || "PawMap"}
          </h2>
          <button type="button" onClick={close} aria-label={t("common_close")} title={t("common_close")} className="grid h-10 w-10 shrink-0 place-items-center rounded-full transition hover:scale-[1.05] active:scale-95" style={{ background: "rgba(255,255,255,0.2)" }}>
            <AppIcon name="close" size={16} color="#FFFFFF" />
          </button>
        </div>
        <div className="px-5 pb-6 pt-4 sm:px-6">
          {item.body && (
            <p className="whitespace-pre-line text-[15px] leading-relaxed [overflow-wrap:anywhere]" style={{ color: dark ? "#F3E4DC" : "#3B2A26" }}>{item.body}</p>
          )}
          <button
            type="button"
            onClick={primary}
            className="relative mt-5 inline-flex min-h-[50px] w-full items-center justify-center gap-2 overflow-hidden rounded-[18px] px-5 text-[15px] font-bold text-white transition hover:brightness-105 active:scale-[0.98]"
            style={{ background: "linear-gradient(90deg,#E2503A,#D83C28 55%,#B92425)", boxShadow: "0 12px 24px -12px #B92425" }}
          >
            {isLink ? t("p589_announce_open") : t("p589_announce_ok")}
            {isLink && <AppIcon name="arrow-right" size={17} color="#FFFFFF" />}
          </button>
        </div>
      </div>
    </div>
  );
}
