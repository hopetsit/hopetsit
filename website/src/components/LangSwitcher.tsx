"use client";

import { useT } from "@/lib/i18n/LanguageProvider";
import { LANGUAGES, Lang } from "@/lib/i18n/translations";
import { useCallback, useEffect, useRef, useState } from "react";

// v548 — Daniel : « la sélection des langues n'est pas fluide ». Avant : liste
// qui apparaissait/disparaissait d'un coup, pas de clavier, pas de repère sur
// la langue active, fermeture uniquement au clic. Maintenant : ouverture et
// fermeture animées (scale + fondu), langue active cochée, navigation clavier
// (flèches, Entrée, Échap), fermeture au clic extérieur / défilement /
// redimensionnement, cibles tactiles plus grandes, et la page fait un léger
// fondu pendant le changement (voir LanguageProvider + globals.css).
const ANIM_MS = 160;

export function LangSwitcher() {
  const { lang, setLang } = useT();
  const [open, setOpen] = useState(false);       // état logique
  const [mounted, setMounted] = useState(false); // la liste est dans le DOM
  const [visible, setVisible] = useState(false); // classes d'animation
  const [focusIdx, setFocusIdx] = useState(-1);
  const wrapRef = useRef<HTMLDivElement>(null);
  const listRef = useRef<HTMLUListElement>(null);
  const btnRef = useRef<HTMLButtonElement>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Monte la liste, puis déclenche l'animation à la frame suivante ;
  // à la fermeture, joue l'animation inverse avant de retirer du DOM.
  useEffect(() => {
    if (timer.current) clearTimeout(timer.current);
    if (open) {
      setMounted(true);
      const raf = requestAnimationFrame(() => setVisible(true));
      return () => cancelAnimationFrame(raf);
    }
    setVisible(false);
    timer.current = setTimeout(() => setMounted(false), ANIM_MS);
    return () => { if (timer.current) clearTimeout(timer.current); };
  }, [open]);

  // Fermeture au clic extérieur, au défilement et au redimensionnement.
  useEffect(() => {
    if (!open) return;
    const onDown = (e: PointerEvent) => {
      if (!wrapRef.current?.contains(e.target as Node)) setOpen(false);
    };
    const close = () => setOpen(false);
    document.addEventListener("pointerdown", onDown);
    window.addEventListener("scroll", close, { passive: true });
    window.addEventListener("resize", close);
    return () => {
      document.removeEventListener("pointerdown", onDown);
      window.removeEventListener("scroll", close);
      window.removeEventListener("resize", close);
    };
  }, [open]);

  // Focus clavier sur l'élément courant à l'ouverture.
  useEffect(() => {
    if (!visible) return;
    const idx = Math.max(0, LANGUAGES.findIndex((l) => l.code === lang));
    setFocusIdx(idx);
    const el = listRef.current?.querySelectorAll<HTMLButtonElement>("button")[idx];
    el?.focus({ preventScroll: true });
  }, [visible, lang]);

  const choose = useCallback((code: Lang) => {
    setOpen(false);
    if (code !== lang) setLang(code);
    btnRef.current?.focus({ preventScroll: true });
  }, [lang, setLang]);

  const onKeyDown = (e: React.KeyboardEvent) => {
    if (!open) {
      if (e.key === "ArrowDown" || e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        setOpen(true);
      }
      return;
    }
    const n = LANGUAGES.length;
    if (e.key === "Escape") { e.preventDefault(); setOpen(false); btnRef.current?.focus(); }
    else if (e.key === "ArrowDown") { e.preventDefault(); focusItem((focusIdx + 1) % n); }
    else if (e.key === "ArrowUp") { e.preventDefault(); focusItem((focusIdx - 1 + n) % n); }
    else if (e.key === "Home") { e.preventDefault(); focusItem(0); }
    else if (e.key === "End") { e.preventDefault(); focusItem(n - 1); }
    else if (e.key === "Tab") { setOpen(false); }
  };

  const focusItem = (idx: number) => {
    setFocusIdx(idx);
    listRef.current?.querySelectorAll<HTMLButtonElement>("button")[idx]?.focus({ preventScroll: true });
  };

  const current = LANGUAGES.find((l) => l.code === lang) ?? LANGUAGES[0];

  return (
    <div ref={wrapRef} className="relative" onKeyDown={onKeyDown}>
      <button
        ref={btnRef}
        type="button"
        onClick={() => setOpen((v) => !v)}
        className={`inline-flex items-center gap-1.5 rounded-full border bg-white px-3 py-1.5 text-sm font-medium text-ink transition-colors duration-150 ${
          open ? "border-ink/30 bg-bg-soft" : "border-ink/10 hover:border-ink/30"
        }`}
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-label={current.label}
      >
        <span aria-hidden="true">{current.flag}</span>
        <span className="hidden sm:inline">{current.code.toUpperCase()}</span>
        <svg
          width="10" height="10" viewBox="0 0 12 12" aria-hidden="true"
          className={`transition-transform duration-150 ${open ? "rotate-180" : ""}`}
        >
          <path d="M2 4l4 4 4-4" stroke="currentColor" strokeWidth="1.6" fill="none" />
        </svg>
      </button>
      {mounted && (
        <ul
          ref={listRef}
          role="listbox"
          aria-activedescendant={focusIdx >= 0 ? `lang-opt-${LANGUAGES[focusIdx].code}` : undefined}
          className={`absolute right-0 z-50 mt-2 w-48 origin-top-right overflow-hidden rounded-xl border border-ink/10 bg-white py-1 shadow-card transition-[opacity,transform] duration-150 ease-out ${
            visible ? "translate-y-0 scale-100 opacity-100" : "-translate-y-1 scale-95 opacity-0"
          }`}
        >
          {LANGUAGES.map((l) => {
            const active = l.code === lang;
            return (
              <li key={l.code} id={`lang-opt-${l.code}`} role="option" aria-selected={active}>
                <button
                  type="button"
                  tabIndex={-1}
                  onClick={() => choose(l.code as Lang)}
                  className={`flex w-full items-center gap-2.5 px-3 py-2.5 text-left text-sm transition-colors duration-100 hover:bg-bg-soft focus:bg-bg-soft focus:outline-none ${
                    active ? "font-semibold text-owner" : "text-ink"
                  }`}
                >
                  <span aria-hidden="true">{l.flag}</span>
                  <span className="flex-1">{l.label}</span>
                  {active && (
                    <svg width="14" height="14" viewBox="0 0 16 16" aria-hidden="true">
                      <path d="M3 8.5l3 3 7-7" stroke="currentColor" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round" />
                    </svg>
                  )}
                </button>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
