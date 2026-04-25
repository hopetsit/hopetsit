"use client";

import { useT } from "@/lib/i18n/LanguageProvider";
import { LANGUAGES, Lang } from "@/lib/i18n/translations";
import { useState, useRef, useEffect } from "react";

export function LangSwitcher() {
  const { lang, setLang } = useT();
  const [open, setOpen] = useState(false);
  const wrapRef = useRef<HTMLDivElement>(null);

  // Close the dropdown on outside click — purely presentational, no portal needed.
  useEffect(() => {
    function onDoc(e: MouseEvent) {
      if (!wrapRef.current?.contains(e.target as Node)) setOpen(false);
    }
    if (open) document.addEventListener("click", onDoc);
    return () => document.removeEventListener("click", onDoc);
  }, [open]);

  const current = LANGUAGES.find((l) => l.code === lang) ?? LANGUAGES[0];

  return (
    <div ref={wrapRef} className="relative">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        className="inline-flex items-center gap-1.5 rounded-full border border-ink/10 bg-white px-3 py-1.5 text-sm font-medium text-ink hover:border-ink/30"
        aria-haspopup="listbox"
        aria-expanded={open}
      >
        <span>{current.flag}</span>
        <span className="hidden sm:inline">{current.code.toUpperCase()}</span>
        <svg width="10" height="10" viewBox="0 0 12 12" aria-hidden="true">
          <path d="M2 4l4 4 4-4" stroke="currentColor" strokeWidth="1.6" fill="none" />
        </svg>
      </button>
      {open && (
        <ul
          role="listbox"
          className="absolute right-0 mt-2 w-44 overflow-hidden rounded-xl border border-ink/10 bg-white shadow-card z-50"
        >
          {LANGUAGES.map((l) => (
            <li key={l.code}>
              <button
                type="button"
                onClick={() => { setLang(l.code as Lang); setOpen(false); }}
                className={`flex w-full items-center gap-2 px-3 py-2 text-sm hover:bg-bg-soft ${
                  l.code === lang ? "font-semibold text-owner" : "text-ink"
                }`}
              >
                <span>{l.flag}</span>
                <span>{l.label}</span>
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
