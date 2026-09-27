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

// 27/09/2026 — LEO : langues À LA DEMANDE + langue de page.
//
// Avant, ce fichier importait `translations.ts` entier : chaque page
// téléchargeait les 9 langues (~774 Ko, ~242 Ko compressés). Maintenant :
// - les textes de la langue de la PAGE (`base`, celle du HTML rendu par le
//   serveur) arrivent DANS le HTML, passés par RootShell (serverDicts.ts) :
//   ce sont eux qui servent à l'hydratation, donc aucun texte ne clignote
//   pour qui lit cette langue ;
// - la langue du visiteur, si elle diffère, arrive dans son propre petit
//   fichier (import() dynamique), demandé dès le chargement de ce module ;
// - les autres langues ne sont jamais téléchargées tant qu'on ne les choisit
//   pas.
// Pages génériques (groupe (site), servies en français) : on affiche le choix
// enregistré, sinon la langue du navigateur, sinon le français.
// Pages écrites dans une langue (`locked` : pages USA, villes allemandes…) :
// on affiche le choix enregistré, sinon la langue de la page, et <html lang>
// reste celle de la page (le contenu principal est dans cette langue).
// Les JSON sont produits par scripts/i18n-split.js depuis translations.ts.

type Dict = Record<string, string>;

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

const loaded: Partial<Record<Lang, Dict>> = {};
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

function isLang(x: string | null | undefined): x is Lang {
  return !!x && LANGUAGES.some((l) => l.code === x);
}

/** Langue à afficher pour ce visiteur sur une page de langue `base`. */
function detectInitialLang(base: Lang, locked: boolean): Lang {
  if (typeof window === "undefined") return base;
  try {
    const stored = window.localStorage.getItem(STORAGE_KEY);
    if (isLang(stored)) return stored;
    if (locked) return base;
    // Robots d'indexation (Googlebot rend la page avec un navigateur réglé en
    // anglais) : ils doivent lire la page dans la langue du HTML servi, le
    // français, et non la traduction choisie d'après leur navigateur.
    if (/bot|crawl|spider|slurp|lighthouse|headless/i.test(navigator.userAgent || "")) return base;
    const nav = (navigator.language || "").slice(0, 2).toLowerCase();
    if (isLang(nav)) return nav;
  } catch {
    /* localStorage may be blocked — fall through to default */
  }
  return locked ? base : DEFAULT_LANG;
}

// Côté navigateur, la langue du visiteur est demandée dès le chargement de ce
// module, AVANT l'hydratation. La langue de la page et le verrou sont lus sur
// <html> (posés par RootShell dans le HTML servi).
if (typeof document !== "undefined") {
  const root = document.documentElement;
  const base = isLang(root.lang) ? root.lang : DEFAULT_LANG;
  const first = detectInitialLang(base, root.dataset.langLock === "1");
  if (first !== base) void loadLang(first).catch(() => {});
}

export function LanguageProvider({
  base,
  baseDict,
  locked = false,
  children,
}: {
  /** Langue du HTML servi pour cette page. */
  base: Lang;
  /** Textes de cette langue (inclus dans le JS du layout). */
  baseDict: Dict;
  /** Page écrite dans une langue précise : <html lang> ne bouge pas. */
  locked?: boolean;
  children: ReactNode;
}) {
  if (!loaded[base]) loaded[base] = baseDict;
  const [lang, setLangState] = useState<Lang>(base);
  // Dernière langue demandée (une réponse réseau plus lente ne doit pas
  // écraser un choix plus récent) et langue affichée (pour le fondu).
  const wanted = useRef<Lang>(base);
  const shown = useRef<Lang>(base);

  // Au montage : langue enregistrée / du navigateur.
  useEffect(() => {
    const initial = detectInitialLang(base, locked);
    wanted.current = initial;
    if (initial !== base) {
      loadLang(initial)
        .then(() => {
          if (wanted.current === initial) setLangState(initial);
        })
        .catch(() => {
          /* hors ligne : la page reste dans sa langue plutôt que de casser */
        });
    }
    // v497 — au chargement, si déjà connecté, pousse la langue au backend.
    pushLocaleToBackend(initial);
  }, [base, locked]);

  // <html lang> (SEO + lecteurs d'écran) suit la langue affichée, sauf sur
  // une page verrouillée ; data-ui-lang donne toujours la langue affichée
  // (mesure d'audience). Fin du fondu de changement de langue (v548).
  useEffect(() => {
    shown.current = lang;
    if (typeof document !== "undefined") {
      const root = document.documentElement;
      if (!locked) root.lang = lang;
      root.dataset.uiLang = lang;
      root.classList.remove("lang-switching");
    }
  }, [lang, locked]);

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
      // Chaque fichier de langue est déjà complété par le français (i18n-split).
      const dict = loaded[lang] || baseDict;
      return dict[key] ?? baseDict[key] ?? key;
    },
    [lang, baseDict]
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
