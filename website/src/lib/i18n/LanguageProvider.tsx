"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  ReactNode,
} from "react";
import { DEFAULT_LANG, Lang, LANGUAGES, t as bundles } from "./translations";
import { getStoredUser, syncAppLocale } from "@/lib/api";

// v497 — pousse la langue du site au backend (appLocale) si l'utilisateur est
// connecté → notifications + emails suivent la langue choisie. Best-effort.
function pushLocaleToBackend(l: Lang) {
  try {
    if (!getStoredUser()) return;
    void syncAppLocale(l).catch(() => {});
  } catch {
    /* non connecté / réseau → ignoré */
  }
}

type Ctx = {
  lang: Lang;
  setLang: (l: Lang) => void;
  t: (key: string) => string;
};

const LanguageContext = createContext<Ctx | null>(null);

const STORAGE_KEY = "hopetsit_lang";

function detectInitialLang(): Lang {
  if (typeof window === "undefined") return DEFAULT_LANG;
  try {
    const stored = window.localStorage.getItem(STORAGE_KEY);
    if (stored && LANGUAGES.some((l) => l.code === stored)) return stored as Lang;
    const nav = (navigator.language || "").slice(0, 2).toLowerCase();
    if (LANGUAGES.some((l) => l.code === nav)) return nav as Lang;
  } catch {
    /* localStorage may be blocked — fall through to default */
  }
  return DEFAULT_LANG;
}

export function LanguageProvider({ children }: { children: ReactNode }) {
  const [lang, setLangState] = useState<Lang>(DEFAULT_LANG);

  // Hydrate from storage / browser locale on mount only.
  useEffect(() => {
    const initial = detectInitialLang();
    setLangState(initial);
    // v497 — au chargement, si déjà connecté, pousse la langue au backend.
    pushLocaleToBackend(initial);
  }, []);

  // Reflect choice in <html lang> for SEO + screen-readers.
  useEffect(() => {
    if (typeof document !== "undefined") {
      document.documentElement.lang = lang;
    }
  }, [lang]);

  const setLang = useCallback((l: Lang) => {
    try {
      window.localStorage.setItem(STORAGE_KEY, l);
    } catch {
      /* ignore */
    }
    // v548 — changement « fluide » : la page fait un léger fondu (classe
    // lang-switching, voir globals.css) pendant que les textes sont remplacés,
    // au lieu d'un remplacement sec de tous les mots.
    const root = typeof document !== "undefined" ? document.documentElement : null;
    if (root) {
      root.classList.add("lang-switching");
      window.setTimeout(() => {
        setLangState(l);
        window.setTimeout(() => root.classList.remove("lang-switching"), 40);
      }, 120);
    } else {
      setLangState(l);
    }
    // v497 — synchronise la langue choisie au backend (notifs + emails).
    pushLocaleToBackend(l);
  }, []);

  const t = useCallback(
    (key: string) => {
      const dict = bundles[lang] || bundles[DEFAULT_LANG];
      return dict[key] ?? bundles[DEFAULT_LANG][key] ?? key;
    },
    [lang]
  );

  const value = useMemo(() => ({ lang, setLang, t }), [lang, setLang, t]);

  return (
    <LanguageContext.Provider value={value}>
      {children}
    </LanguageContext.Provider>
  );
}

export function useT() {
  const ctx = useContext(LanguageContext);
  if (!ctx) throw new Error("useT must be used inside <LanguageProvider>");
  return ctx;
}
