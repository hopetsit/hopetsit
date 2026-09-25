"use client";
// 25/09/2026 (PawMap 587, point 9) — pastille signature des messages courts de
// la carte (œil Tous / Amis seulement / Masqué, direct, suivi) : même dessin
// que l'app (`pawmap_signal.dart`) — verre blanc chaud, maison dans un disque
// à la couleur de l'état, texte court à l'encre chaude, fondu + léger rebond.
// Zéro gris ; mode sombre = verre brun chaud. La durée (2 s) reste gérée par
// la page, qui retire la pastille ; `key` = le texte, pour rejouer l'entrée.
import { useEffect, useState } from "react";

export type StatusToastKind = "live" | "liveOff" | "friends" | "all" | "hidden" | "noGps" | "error" | "follow";

const COLOR: Record<StatusToastKind, string> = {
  live: "#16A34A",
  liveOff: "#17141F",
  friends: "#F06AA0",
  all: "#2563EB",
  hidden: "#17141F",
  noGps: "#C2410C",
  error: "#C92A12",
  follow: "#7C3AED",
};
const TOP: Record<StatusToastKind, string> = {
  live: "#3FB96A",
  liveOff: "#3B2A26",
  friends: "#F48AB4",
  all: "#4F7FEF",
  hidden: "#3B2A26",
  noGps: "#D8612F",
  error: "#DB5238",
  follow: "#9B6BFF",
};
/** Petit glyphe posé sur la maison : l'état se lit aussi sans la couleur. */
const BADGE: Record<StatusToastKind, string> = {
  live: '<circle cx="12" cy="12" r="3"/><path d="M7.8 7.8a6 6 0 0 0 0 8.4M16.2 7.8a6 6 0 0 1 0 8.4" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/>',
  liveOff: '<path d="M8 6h3v12H8zM13 6h3v12h-3z"/>',
  friends: '<path d="M12 20s-7-4.4-7-9.6A3.9 3.9 0 0 1 12 8a3.9 3.9 0 0 1 7 2.4C19 15.6 12 20 12 20z"/>',
  all: '<path d="M12 6c-5 0-8.6 4.2-9.6 6 1 1.8 4.6 6 9.6 6s8.6-4.2 9.6-6c-1-1.8-4.6-6-9.6-6zm0 9.5a3.5 3.5 0 1 1 0-7 3.5 3.5 0 0 1 0 7z"/>',
  hidden: '<path d="M3 4.3 4.3 3 21 19.7 19.7 21l-3.2-3.2c-1.3.6-2.8 1-4.5 1-5 0-8.6-4.2-9.6-6 .6-1 1.8-2.6 3.5-3.9zM12 6c5 0 8.6 4.2 9.6 6-.4.8-1.2 1.9-2.3 3L9.2 6.3C10.1 6.1 11 6 12 6z"/>',
  noGps: '<path d="M11 3h2v3.1A6 6 0 0 1 17.9 11H21v2h-3.1A6 6 0 0 1 13 17.9V21h-2v-3.1A6 6 0 0 1 6.1 13H3v-2h3.1A6 6 0 0 1 11 6.1z" opacity=".35"/><path d="M4 5.4 5.4 4 20 18.6 18.6 20z"/>',
  error: '<path d="M11 5h2v9h-2zM11 16h2v2h-2z"/>',
  follow: '<circle cx="12" cy="12" r="4"/>',
};

export function StatusToast({ kind, text, dark = false, onClick }: { kind: StatusToastKind; text: string; dark?: boolean; onClick?: () => void }) {
  const [shown, setShown] = useState(false);
  useEffect(() => {
    const id = requestAnimationFrame(() => setShown(true));
    return () => cancelAnimationFrame(id);
  }, []);
  const c = COLOR[kind];
  const Tag = onClick ? "button" : "div";
  return (
    <Tag
      type={onClick ? "button" : undefined}
      onClick={onClick}
      role="status"
      aria-live="polite"
      className="pointer-events-auto inline-flex min-h-[44px] max-w-[min(340px,calc(100vw-32px))] items-center gap-2.5 rounded-full py-1.5 pl-1.5 pr-4 text-left"
      style={{
        background: dark ? "linear-gradient(180deg,rgba(45,31,27,.95),rgba(30,23,22,.92))" : "linear-gradient(180deg,rgba(255,251,247,.96),rgba(255,242,232,.92))",
        border: `1px solid ${dark ? "rgba(255,228,214,.22)" : "rgba(255,255,255,.95)"}`,
        boxShadow: dark ? "0 12px 26px -8px rgba(12,6,4,.6)" : "0 12px 26px -8px rgba(146,64,14,.34)",
        backdropFilter: "blur(10px)",
        WebkitBackdropFilter: "blur(10px)",
        opacity: shown ? 1 : 0,
        transform: shown ? "scale(1)" : "scale(.88)",
        transition: "opacity 220ms ease-out, transform 320ms cubic-bezier(.34,1.56,.64,1)",
      }}
    >
      <span className="relative grid h-[30px] w-[30px] shrink-0 place-items-center rounded-full" style={{ background: `linear-gradient(135deg,${TOP[kind]},${c})`, border: "1.5px solid #fff" }} aria-hidden="true">
        <svg viewBox="0 0 24 24" width="17" height="17" fill="#fff"><path d="M12 3.2 2.8 11h2.6v9.3h5.1v-5.9h3v5.9h5.1V11h2.6z" /></svg>
        <span className="absolute -bottom-1 -right-1 grid h-[15px] w-[15px] place-items-center rounded-full bg-white" style={{ border: `1.2px solid ${c}`, color: c }}>
          <svg viewBox="0 0 24 24" width="10" height="10" fill="currentColor" dangerouslySetInnerHTML={{ __html: BADGE[kind] }} />
        </span>
      </span>
      <span className="text-[13px] font-bold leading-snug" style={{ color: dark ? "#FBEFE6" : "#3B2A26" }}>{text}</span>
    </Tag>
  );
}
