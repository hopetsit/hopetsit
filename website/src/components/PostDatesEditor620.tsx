"use client";

// 24/10/2026 (620, LEO — §B.2) : poser les dates d'une demande « à prévoir »
// (ou en changer) depuis la page des candidatures. PATCH /posts/:id avec
// dateMode exact | approx + début / fin : le serveur recalcule les
// candidatures en attente et prévient les candidats. Orange propriétaire,
// zéro gris. Hooks en tête, aucun retour conditionnel avant.

import { useState } from "react";
import { AppIcon } from "@/components/AppIcon";
import { SignatureButton } from "@/components/SignatureButton";
import type { Lang } from "@/lib/i18n/langs";
import { d620 } from "@/lib/i18n/dates620";
import { ApiError, updatePostDates620, type RequestPost } from "@/lib/api";
import { datesValid620 } from "@/lib/services620";
// 26/10 (LEO — retour de FLO) : une BALADE datée a une date ET une heure (avant : jour seul,
// enregistré à 00 h 00 UTC = 01 h 00 à Paris) ; fin pré-remplie pour poser ses dates plus vite.
import { c2610 } from "@/lib/i18n/cand2610";

const ORANGE = "#C92A12";
const ORANGE_DARK = "#9E1F0B";
const ORANGE_PALE = "#FBE9E5";
const INK = "#231715";
const INK_SOFT = "#6E4F48";

const day = (iso?: string | null) => (iso ? String(iso).slice(0, 10) : "");

export function PostDatesEditor620({
  post,
  lang,
  onSaved,
  onCancel,
  startLabel,
  endLabel,
}: {
  post: RequestPost;
  lang: Lang;
  onSaved: (p: RequestPost) => void;
  onCancel?: () => void;
  startLabel: string;
  endLabel: string;
}) {
  const [mode, setMode] = useState<"exact" | "approx">(post.dateMode === "approx" ? "approx" : "exact");
  const [start, setStart] = useState(day(post.startDate));
  const [end, setEnd] = useState(day(post.endDate));
  // Balade seule : une date + une heure (heure locale du propriétaire), fin = début + durée.
  const isWalk = (post.serviceTypes || []).length > 0 && (post.serviceTypes || []).every((s) => s === "dog_walking");
  const hhmm = (iso?: string | null) => {
    if (!iso) return "";
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return "";
    const h = d.getHours(), m = d.getMinutes();
    return h === 0 && m === 0 ? "" : `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`;
  };
  const [time, setTime] = useState(hhmm(post.startDate) || "10:00");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");
  const [done, setDone] = useState(false);
  const id = String(post.id || post._id || "");
  const today = new Date().toISOString().slice(0, 10);

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setErr("");
    const endDay = isWalk ? start : end;
    if (!start || !endDay || (isWalk && !/^\d{2}:\d{2}$/.test(time))) return setErr(d620(lang, "dates_period_required"));
    if (!datesValid620(isWalk ? "exact" : mode, start, endDay)) return setErr(d620(lang, "dates_order"));
    // Heure locale du navigateur (celle du propriétaire) → ISO : « 10:00 » à Paris = 09:00 UTC.
    const walkMin = Math.max(15, Number((post as { walkDurationMinutes?: number | null }).walkDurationMinutes) || 60);
    const startIso = isWalk ? new Date(`${start}T${time}:00`).toISOString() : start;
    const endIso = isWalk ? new Date(new Date(`${start}T${time}:00`).getTime() + walkMin * 60000).toISOString() : endDay;
    setBusy(true);
    try {
      const updated = await updatePostDates620(id, { dateMode: isWalk ? "exact" : mode, startDate: startIso, endDate: endIso });
      setDone(true);
      onSaved({ ...post, ...updated, dateMode: isWalk ? "exact" : mode, startDate: updated.startDate || new Date(startIso).toISOString(), endDate: updated.endDate || new Date(endIso).toISOString() });
    } catch (ex) {
      setErr(ex instanceof ApiError && ex.message ? ex.message : d620(lang, "editor_error"));
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={save} data-testid="dates-editor-620" className="mt-3 rounded-2xl bg-white p-3" style={{ boxShadow: `inset 0 0 0 1.5px ${ORANGE}` }}>
      <p className="flex items-center gap-1.5 text-[13px] font-bold" style={{ color: ORANGE_DARK }}>
        <AppIcon name="calendar" size={15} color={ORANGE} />
        {d620(lang, "editor_title")}
      </p>
      {!isWalk && <div className="mt-2 flex flex-wrap gap-2" role="radiogroup">
        {(["exact", "approx"] as const).map((m) => {
          const on = mode === m;
          return (
            <button key={m} type="button" role="radio" aria-checked={on} data-mode={m} onClick={() => setMode(m)}
              className="rounded-full border px-3.5 py-1.5 text-[13px] font-semibold max-lg:min-h-[40px]"
              style={on ? { borderColor: ORANGE, background: ORANGE_PALE, color: ORANGE_DARK } : { borderColor: "rgba(35,23,21,0.15)", background: "#fff", color: INK }}>
              {d620(lang, `mode_${m}`)}
            </button>
          );
        })}
      </div>}
      {isWalk ? (
        <div className="mt-2 grid grid-cols-2 gap-2" data-walk-time-2610="">
          <label className="block">
            <span className="block text-xs font-medium" style={{ color: INK }}>{c2610(lang, "date_label")}</span>
            <input type="date" value={start} min={today} onChange={(e) => setStart(e.target.value)} data-testid="editor-start-620"
              className="mt-1 w-full rounded-xl border px-2.5 py-2 text-sm focus:outline-none" style={{ borderColor: "rgba(35,23,21,0.15)", color: INK, background: "#FFF9F6" }} />
          </label>
          <label className="block">
            <span className="block text-xs font-medium" style={{ color: INK }}>{c2610(lang, "time_label")}</span>
            <input type="time" value={time} step={900} onChange={(e) => setTime(e.target.value)} data-testid="editor-time-2610"
              className="mt-1 w-full rounded-xl border px-2.5 py-2 text-sm focus:outline-none" style={{ borderColor: "rgba(35,23,21,0.15)", color: INK, background: "#FFF9F6" }} />
          </label>
        </div>
      ) : (
      <div className="mt-2 grid grid-cols-2 gap-2">
        <label className="block">
          <span className="block text-xs font-medium" style={{ color: INK }}>{mode === "approx" ? d620(lang, "approx_from") : startLabel}</span>
          <input type="date" value={start} min={today} onChange={(e) => { const v = e.target.value; setStart(v); if (v && (!end || end < v)) setEnd(v); }} data-testid="editor-start-620"
            className="mt-1 w-full rounded-xl border px-2.5 py-2 text-sm focus:outline-none" style={{ borderColor: "rgba(35,23,21,0.15)", color: INK, background: "#FFF9F6" }} />
        </label>
        <label className="block">
          <span className="block text-xs font-medium" style={{ color: INK }}>{mode === "approx" ? d620(lang, "approx_to") : endLabel}</span>
          <input type="date" value={end} min={start || today} onChange={(e) => setEnd(e.target.value)} data-testid="editor-end-620"
            className="mt-1 w-full rounded-xl border px-2.5 py-2 text-sm focus:outline-none" style={{ borderColor: "rgba(35,23,21,0.15)", color: INK, background: "#FFF9F6" }} />
        </label>
      </div>
      )}
      {err && <p role="alert" className="mt-2 rounded-xl px-3 py-2 text-[12px] font-bold" style={{ background: ORANGE_PALE, color: ORANGE_DARK }}>{err}</p>}
      {done && !err && <p className="mt-2 text-[12px] font-bold" style={{ color: "#15803D" }}>{d620(lang, "editor_saved")}</p>}
      <div className="mt-3 flex flex-col gap-2 sm:flex-row sm:items-center">
        <div className="sm:flex-1">
          <SignatureButton tone="owner" icon="check" type="submit" label={busy ? d620(lang, "editor_saving") : d620(lang, "editor_save")} loading={busy} disabled={busy} />
        </div>
        {onCancel && (
          <button type="button" onClick={onCancel} className="text-[13px] font-semibold underline max-lg:min-h-[44px] sm:px-3" style={{ color: INK_SOFT }}>
            {d620(lang, "editor_cancel")}
          </button>
        )}
      </div>
    </form>
  );
}

export default PostDatesEditor620;
