"use client";

// 25/09/2026 (PawMap 586, point 3) — « qui me voit sur la carte » : icône
// œil à 3 états et sélecteur à 3 pilules, partagés par /map (capsule +
// panneau) et /profile. Une seule vérité : /users/me/map-prefs (lib/api.ts).
import type { MapVisibility } from "@/lib/api";

/** 25/09 (586) — œil « qui me voit » : œil = Tous, œil + cœur = Amis, œil barré = Masqué. */
export function EyeIcon({ state, size = 20 }: { state: MapVisibility; size?: number }) {
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      {state === "hidden" ? (
        <path d="M3 3l18 18M10.6 5.3c.5-.1.9-.1 1.4-.1 5 0 8.6 4.2 9.6 6.8-.4 1-1.2 2.3-2.4 3.5M6.6 6.6C4.3 8.1 2.9 10.4 2.4 12c1 2.6 4.6 6.8 9.6 6.8 1.7 0 3.2-.4 4.5-1.1M9.9 9.9a3 3 0 0 0 4.2 4.2" />
      ) : (
        <>
          <path d="M2.4 12C3.4 9.4 7 5.2 12 5.2s8.6 4.2 9.6 6.8c-1 2.6-4.6 6.8-9.6 6.8S3.4 14.6 2.4 12z" />
          <circle cx="12" cy="12" r="3" />
        </>
      )}
      {state === "friends" && (
        <path d="M18.2 14.6c-.9-.9-2.4-.3-2.4.9 0 1.5 2.4 3 2.4 3s2.4-1.5 2.4-3c0-1.2-1.5-1.8-2.4-.9z" fill="#F06AA0" stroke="#FFFFFF" strokeWidth="1.2" />
      )}
    </svg>
  );
}
/** 25/09 (586) — 3 pilules Tous / Amis seulement / Masqué (carte et /profile). */
export function VisibilityPills({ value, busy, onChange, labels }: { value: MapVisibility; busy?: boolean; onChange: (v: MapVisibility) => void; labels: Record<MapVisibility, string> }) {
  const opts: MapVisibility[] = ["all", "friends", "hidden"];
  return (
    <div className="mt-2 grid grid-cols-3 gap-1.5" role="radiogroup">
      {opts.map((o) => {
        const on = value === o;
        return (
          <button
            key={o}
            type="button"
            role="radio"
            aria-checked={on}
            disabled={busy}
            onClick={() => { if (!on) onChange(o); }}
            className="flex min-h-[40px] items-center justify-center gap-1 rounded-xl px-1.5 py-1 text-center text-[12px] font-bold leading-tight transition"
            style={on ? { background: "#17141F", color: "#FFFFFF" } : { background: "#FFFFFF", color: "#17141F", boxShadow: "inset 0 0 0 1.5px #E4C7B8" }}
          >
            <EyeIcon state={o} size={15} />
            <span>{labels[o]}</span>
          </button>
        );
      })}
    </div>
  );
}

export default VisibilityPills;
