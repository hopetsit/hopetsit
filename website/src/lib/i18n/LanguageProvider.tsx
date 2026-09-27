"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  ReactNode,
} from "react";
import { DEFAULT_LANG, Lang, LANGUAGES } from "./langs";
import { getStoredUser, syncAppLocale } from "@/lib/api";
// 27/09/2026 — LEO : langues À LA DEMANDE. Avant, ce fichier importait
// `translations.ts` entier : chaque page téléchargeait les 9 langues (~774 Ko,
// ~242 Ko compressés) avant de s'afficher. Maintenant seul l'anglais est dans
// le JS de la page (c'est la langue du HTML rendu par le serveur, donc celle
// de l'hydratation, et la langue de repli d'une clé absente) ; la langue du
// visiteur arrive dans son propre petit fichier, et les 7 autres ne sont
// jamais téléchargées tant qu'on ne les choisit pas. Les JSON sont produits
// par scripts/i18n-split.js depuis translations.ts (lancé par next.config.js).
import enDict from "./generated/en.json";

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

type Dict = Record<string, string>;

const EN: Dict = enDict as Dict;
const loaded: Partial<Record<Lang, Dict>> = { en: EN };
const pending: Partial<Record<Lang, Promise<Dict>>> = {};

/** Télécharge (une seule fois) le dictionnaire d'une langue. */
function loadLang(l: Lang): Promise<Dict> {
  const ready = loaded[l];
  if (ready) return Promise.resolve(ready);
  let p = pending[l];
  if (!p) {
    p = import(`./generated/${l}.json`)
      .then((m: { default?: Dict } & Dict) => {
        const d = (m.default ?? m) as Dict;
        loaded[l] = d;
        return d;
      })
      .catch((e: unknown) => {
        delete pending[l]; // réseau coupé : on pourra réessayer
        throw e;
      });
    pending[l] = p;
  }
  return p;
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

// Côté navigateur, la langue du visiteur est demandée dès le chargement de ce
// module, AVANT l'hydratation : quand l'effet de montage la réclame, elle est
// en général déjà là (pas plus d'anglais affiché qu'avant).
if (typeof window !== "undefined") {
  const first = detectInitialLang();
  if (first !== DEFAULT_LANG) void loadLang(first).catch(() => {});
}

export function LanguageProvider({ children }: { children: ReactNode }) {
  const [lang, setLangState] = useState<Lang>(DEFAULT_LANG);
  // Dernière langue demandée (une réponse réseau plus lente ne doit pas
  // écraser un choix plus récent) et langue affichée (pour le fondu).
  const wanted = useRef<Lang>(DEFAULT_LANG);
  const shown = useRef<Lang>(DEFAULT_LANG);

  // Hydrate from storage / browser locale on mount only.
  useEffect(() => {
    const initial = detectInitialLang();
    wanted.current = initial;
    if (initial !== DEFAULT_LANG) {
      loadLang(initial)
        .then(() => {
          if (wanted.current === initial) setLangState(initial);
        })
        .catch(() => {
          /* hors ligne : la page reste en anglais plutôt que de casser */
        });
    }
    // v497 — au chargement, si déjà connecté, pousse la langue au backend.
    pushLocaleToBackend(initial);
  }, []);

  // Reflect choice in <html lang> for SEO + screen-readers, et fin du fondu
  // de changement de langue (v548) une fois la nouvelle langue rendue.
  useEffect(() => {
    shown.current = lang;
    if (typeof document !== "undefined") {
      document.documentElement.lang = lang;
      document.documentElement.classList.remove("lang-switching");
    }
  }, [lang]);

  const setLang = useCallback((l: Lang) => {
    try {
      window.localStorage.setItem(STORAGE_KEY, l);
    } catch {
      /* ignore */
    }
    wanted.current = l;
    // v548 — changement « fluide » : la page fait un léger fondu (classe
    // lang-switching, voir globals.css) pendant que les textes sont remplacés,
    // au lieu d'un remplacement sec de tous les mots.
    const root = typeof document !== "undefined" ? document.documentElement : null;
    root?.classList.add("lang-switching");
    // La classe est retirée par l'effet [lang] ci-dessus, juste après le
    // rendu dans la nouvelle langue (pas par une minuterie : un onglet
    // caché ralentit les timers et la page resterait estompée). Le fondu
    // dure au moins 120 ms, et au plus le temps de recevoir la langue.
    const minDelay = new Promise<void>((r) => window.setTimeout(r, root ? 120 : 0));
    Promise.all([loadLang(l), minDelay])
      .then(() => {
        if (wanted.current !== l) return;
        if (shown.current === l) root?.classList.remove("lang-switching");
        else setLangState(l);
      })
      .catch(() => {
        // Langue non reçue (réseau) : on reste dans la langue affichée.
        if (wanted.current === l) wanted.current = shown.current;
        root?.classList.remove("lang-switching");
      });
    // v497 — synchronise la langue choisie au backend (notifs + emails).
    pushLocaleToBackend(l);
  }, []);

  const t = useCallback(
    (key: string) => {
      const dict = loaded[lang] || EN;
      return dict[key] ?? EN[key] ?? key;
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
