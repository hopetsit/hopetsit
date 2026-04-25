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
    setLangState(detectInitialLang());
  }, []);

  // Reflect choice in <html lang> for SEO + screen-readers.
  useEffect(() => {
    if (typeof document !== "undefined") {
      document.documentElement.lang = lang;
    }
  }, [lang]);

  const setLang = useCallback((l: Lang) => {
    setLangState(l);
    try {
      window.localStorage.setItem(STORAGE_KEY, l);
    } catch {
      /* ignore */
    }
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
