"use client";

// 25/09/2026 (PawMap 585, lot 2 — bug 16) — LISTE DÉROULANTE MAISON.
// Le <select> natif de Chrome s'ouvre en GRIS FONCÉ (menu système) : Daniel
// l'a vu sur « Type de service » de la réservation. Ce composant le remplace
// dans les formulaires connectés du site :
//   · liste blanc chaud, coins 16, ombre teintée (brun ambré), jamais de gris ;
//   · ligne choisie en teinte pâle PLEINE de la couleur du rôle + coche ;
//   · texte à l'encre chaude ; sombre = encre foncée chaude (jamais gris) ;
//   · clavier complet : ↑ ↓ Début Fin, Entrée/Espace, Échap, Tab, frappe
//     de lettres (va à l'option qui commence ainsi) ; aria combobox/listbox ;
//   · longue liste (> 12, ex. pays) : champ de recherche en tête.

import { useEffect, useId, useMemo, useRef, useState, type KeyboardEvent, type ReactNode } from "react";

export type SelectOption = { value: string; label: string; sub?: string; icon?: ReactNode };

type Tone = "owner" | "sitter" | "walker" | "neutral";

// Teintes PLEINES (jamais d'opacité sur blanc : zéro gris).
const TONES: Record<Tone, { accent: string; pale: string; ink: string; paleDark: string; inkDark: string }> = {
  owner: { accent: "#C92A12", pale: "#FBE3DC", ink: "#9E1F0B", paleDark: "#4A2019", inkDark: "#FFB4A3" },
  sitter: { accent: "#2563EB", pale: "#DCE8FD", ink: "#1E4FB0", paleDark: "#1D2C4D", inkDark: "#A9C6FF" },
  walker: { accent: "#16A34A", pale: "#D9F5E3", ink: "#15803D", paleDark: "#173826", inkDark: "#9FE3B7" },
  neutral: { accent: "#C92A12", pale: "#FBE3DC", ink: "#9E1F0B", paleDark: "#4A2019", inkDark: "#FFB4A3" },
};

export function SelectMenu({
  value,
  onChange,
  options,
  placeholder = "—",
  ariaLabel,
  labelledBy,
  tone = "neutral",
  dark = false,
  searchPlaceholder,
  size = "md",
  className = "",
  id,
  disabled,
}: {
  value: string;
  onChange: (v: string) => void;
  options: SelectOption[];
  placeholder?: string;
  ariaLabel?: string;
  labelledBy?: string;
  tone?: Tone;
  dark?: boolean;
  /** Texte du champ de recherche (listes longues). */
  searchPlaceholder?: string;
  size?: "sm" | "md";
  className?: string;
  id?: string;
  disabled?: boolean;
}) {
  const uid = useId().replace(/:/g, "");
  const listId = `sel-${uid}-list`;
  const [open, setOpen] = useState(false);
  const [active, setActive] = useState(-1);
  const [query, setQuery] = useState("");
  const [up, setUp] = useState(false);
  const rootRef = useRef<HTMLDivElement | null>(null);
  const btnRef = useRef<HTMLButtonElement | null>(null);
  const listRef = useRef<HTMLUListElement | null>(null);
  const searchRef = useRef<HTMLInputElement | null>(null);
  const typed = useRef({ s: "", t: 0 });
  const c = TONES[tone];
  const searchable = options.length > 12;

  const shown = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return options;
    const norm = (s: string) => s.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
    return options.filter((o) => norm(o.label).includes(norm(q)));
  }, [options, query]);
  const selected = options.find((o) => o.value === value) || null;

  // Fermer au clic extérieur.
  useEffect(() => {
    if (!open) return;
    const onDoc = (e: MouseEvent | TouchEvent) => {
      if (rootRef.current && !rootRef.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", onDoc);
    document.addEventListener("touchstart", onDoc);
    return () => {
      document.removeEventListener("mousedown", onDoc);
      document.removeEventListener("touchstart", onDoc);
    };
  }, [open]);

  // À l'ouverture : sens (haut/bas selon la place), option active = la choisie.
  useEffect(() => {
    if (!open) return;
    try {
      const r = btnRef.current?.getBoundingClientRect();
      if (r) setUp(window.innerHeight - r.bottom < 300 && r.top > window.innerHeight - r.bottom);
    } catch { /* */ }
    const i = shown.findIndex((o) => o.value === value);
    setActive(i >= 0 ? i : 0);
    if (searchable) setTimeout(() => searchRef.current?.focus(), 0);
    else setTimeout(() => listRef.current?.focus(), 0);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  // L'option active reste visible.
  useEffect(() => {
    if (!open || active < 0) return;
    const el = listRef.current?.querySelector<HTMLElement>(`[data-idx="${active}"]`);
    el?.scrollIntoView({ block: "nearest" });
  }, [active, open]);

  const choose = (i: number) => {
    const o = shown[i];
    if (!o) return;
    onChange(o.value);
    setOpen(false);
    setQuery("");
    setTimeout(() => btnRef.current?.focus(), 0);
  };
  const onKey = (e: KeyboardEvent) => {
    if (!open) {
      if (["ArrowDown", "ArrowUp", "Enter", " "].includes(e.key)) {
        e.preventDefault();
        setOpen(true);
      }
      return;
    }
    if (e.key === "ArrowDown") { e.preventDefault(); setActive((a) => Math.min(shown.length - 1, a + 1)); }
    else if (e.key === "ArrowUp") { e.preventDefault(); setActive((a) => Math.max(0, a - 1)); }
    else if (e.key === "Home") { e.preventDefault(); setActive(0); }
    else if (e.key === "End") { e.preventDefault(); setActive(shown.length - 1); }
    else if (e.key === "Enter" || (e.key === " " && !searchable)) { e.preventDefault(); choose(active); }
    else if (e.key === "Escape") { e.preventDefault(); setOpen(false); setQuery(""); btnRef.current?.focus(); }
    else if (e.key === "Tab") { setOpen(false); setQuery(""); }
    else if (!searchable && e.key.length === 1 && /\S/.test(e.key)) {
      // Frappe de lettres : aller à l'option qui commence ainsi.
      const now = Date.now();
      typed.current = { s: (now - typed.current.t < 700 ? typed.current.s : "") + e.key.toLowerCase(), t: now };
      const i = shown.findIndex((o) => o.label.toLowerCase().startsWith(typed.current.s));
      if (i >= 0) setActive(i);
    }
  };

  const h = size === "sm" ? "min-h-[36px] text-xs px-2.5" : "min-h-[46px] text-sm px-3.5";
  const bg = dark ? "#221A20" : "#FFFFFF";
  const fg = dark ? "#FBEFE6" : "#231715";
  const border = dark ? "#4A3A40" : "#EAD6CB";
  return (
    <div ref={rootRef} className={`relative ${className}`}>
      <button
        ref={btnRef}
        id={id}
        type="button"
        role="combobox"
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-controls={listId}
        aria-label={ariaLabel}
        aria-labelledby={labelledBy}
        disabled={disabled}
        onClick={() => setOpen((o) => !o)}
        onKeyDown={onKey}
        className={`flex w-full items-center gap-2 rounded-[14px] border text-left font-semibold outline-none transition focus-visible:ring-2 disabled:cursor-not-allowed disabled:opacity-60 ${h}`}
        style={{ background: bg, color: fg, borderColor: open ? c.accent : border, boxShadow: open ? `0 0 0 3px ${dark ? c.paleDark : c.pale}` : undefined }}
      >
        {selected?.icon ? <span className="shrink-0">{selected.icon}</span> : null}
        <span className={`min-w-0 flex-1 truncate ${selected ? "" : "font-medium"}`} style={selected ? undefined : { color: dark ? "#CDB9AE" : "#8A6B64" }}>
          {selected ? selected.label : placeholder}
        </span>
        <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke={c.accent} strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" className={`shrink-0 transition-transform ${open ? "rotate-180" : ""}`}><path d="M6 9l6 6 6-6" /></svg>
      </button>
      {open && (
        <div
          className={`absolute left-0 right-0 z-[3000] overflow-hidden rounded-[16px] ${up ? "bottom-[calc(100%+6px)]" : "top-[calc(100%+6px)]"}`}
          style={{
            background: dark ? "#221A20" : "#FFFBF8",
            border: `1px solid ${dark ? "#4A3A40" : "#F3E3DC"}`,
            boxShadow: dark ? "0 20px 44px -14px rgba(12,6,4,0.75)" : "0 20px 44px -16px rgba(120,53,15,0.42)",
          }}
        >
          {searchable && (
            <div className="p-2 pb-1">
              <input
                ref={searchRef}
                value={query}
                onChange={(e) => { setQuery(e.target.value); setActive(0); }}
                onKeyDown={onKey}
                placeholder={searchPlaceholder || "…"}
                aria-controls={listId}
                aria-activedescendant={active >= 0 ? `${listId}-${active}` : undefined}
                className="w-full rounded-[12px] border px-3 py-2 text-sm outline-none"
                style={{ background: dark ? "#2C2229" : "#FFFFFF", color: fg, borderColor: border }}
              />
            </div>
          )}
          <ul
            ref={listRef}
            id={listId}
            role="listbox"
            tabIndex={-1}
            aria-label={ariaLabel}
            aria-labelledby={labelledBy}
            aria-activedescendant={active >= 0 ? `${listId}-${active}` : undefined}
            onKeyDown={onKey}
            className="max-h-[280px] overflow-y-auto overscroll-contain p-1.5 outline-none"
          >
            {shown.length === 0 && <li className="px-3 py-2.5 text-sm" style={{ color: dark ? "#CDB9AE" : "#8A6B64" }}>—</li>}
            {shown.map((o, i) => {
              const sel = o.value === value;
              const act = i === active;
              return (
                <li
                  key={o.value || `empty-${i}`}
                  id={`${listId}-${i}`}
                  data-idx={i}
                  role="option"
                  aria-selected={sel}
                  onMouseEnter={() => setActive(i)}
                  onMouseDown={(e) => e.preventDefault()}
                  onClick={() => choose(i)}
                  className="flex min-h-[44px] cursor-pointer items-center gap-2.5 rounded-[12px] px-3 py-2 text-sm"
                  style={{
                    background: sel ? (dark ? c.paleDark : c.pale) : act ? (dark ? "#2F242B" : "#FDF1EB") : "transparent",
                    color: sel ? (dark ? c.inkDark : c.ink) : fg,
                    fontWeight: sel ? 700 : 500,
                  }}
                >
                  {o.icon ? <span className="shrink-0">{o.icon}</span> : null}
                  <span className="min-w-0 flex-1">
                    <span className="block">{o.label}</span>
                    {o.sub && <span className="block text-[11px] font-medium" style={{ color: dark ? "#CDB9AE" : "#8A6B64" }}>{o.sub}</span>}
                  </span>
                  {sel && (
                    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke={dark ? c.inkDark : c.accent} strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" className="shrink-0"><path d="M5 12.5l4.5 4.5L19 7.5" /></svg>
                  )}
                </li>
              );
            })}
          </ul>
        </div>
      )}
    </div>
  );
}
