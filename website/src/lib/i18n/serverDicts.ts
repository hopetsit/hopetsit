// 27/09/2026 — LEO : textes de chaque langue, lus CÔTÉ SERVEUR par
// components/RootShell.tsx, qui passe au LanguageProvider ceux de la langue de
// la page. Ne jamais importer ce fichier depuis un composant "use client" :
// il ferait télécharger les 9 langues.
//
// Pourquoi pas un import du JSON dans un module client par langue : avec
// plusieurs layouts racines, Next 14 attribue aux composants partagés
// (Header, Footer…) les fichiers JS d'UN seul layout — toutes les pages
// auraient téléchargé les textes polonais en plus des leurs (mesuré le 27/09).
import type { Lang } from "./langs";
import de from "./generated/de.json";
import en from "./generated/en.json";
import es from "./generated/es.json";
import fr from "./generated/fr.json";
import it from "./generated/it.json";
import ja from "./generated/ja.json";
import ko from "./generated/ko.json";
import pl from "./generated/pl.json";
import pt from "./generated/pt.json";

const DICTS: Record<Lang, Record<string, string>> = { de, en, es, fr, it, ja, ko, pl, pt };

export function dictFor(lang: Lang): Record<string, string> {
  return DICTS[lang];
}
