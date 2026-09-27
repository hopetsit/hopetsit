// 27/09/2026 — LEO : liste des langues du site, séparée des textes.
// Un composant du navigateur qui a besoin de la liste (sélecteur de langue)
// l'importe d'ici : importer `translations.ts` ferait télécharger les
// 9 langues à chaque visiteur. Les textes, eux, sont servis par
// LanguageProvider, une langue à la fois (voir scripts/i18n-split.js).

export type Lang = "en" | "fr" | "es" | "de" | "it" | "pt" | "ko" | "ja" | "pl";

export const LANGUAGES: { code: Lang; label: string; flag: string }[] = [
  { code: "en", label: "English", flag: "🇺🇸" },
  { code: "fr", label: "Français", flag: "🇫🇷" },
  { code: "es", label: "Español", flag: "🇪🇸" },
  { code: "de", label: "Deutsch", flag: "🇩🇪" },
  { code: "it", label: "Italiano", flag: "🇮🇹" },
  { code: "pt", label: "Português", flag: "🇵🇹" },
  { code: "ko", label: "한국어", flag: "🇰🇷" },
  { code: "ja", label: "日本語", flag: "🇯🇵" },
  // v546 — Daniel : ouverture Varsovie → polonais sur app + site.
  { code: "pl", label: "Polski", flag: "🇵🇱" },
];

// 27/09/2026 — décision de Daniel : le FRANÇAIS est la langue par défaut du
// site (HTML des pages génériques servi en français, langue de repli d'une
// clé absente, langue d'un visiteur dont le navigateur parle une langue que
// le site ne connaît pas). Les pages écrites dans une langue précise (pages
// USA, pages villes allemandes, espagnoles…) gardent LEUR langue : voir les
// groupes de routes src/app/(xx)/ et components/RootShell.tsx.
export const DEFAULT_LANG: Lang = "fr";
