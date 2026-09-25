"use client";

import { useT } from "@/lib/i18n/LanguageProvider";
// v576 — mesure d'audience : un clic sur un badge = un clic vers un store.
import { trackSiteEvent } from "@/components/SiteAnalytics";

// v508 — Daniel : « ajoute les boutons stores et branche juste Google Play ».
// L'app est EN LIGNE sur le Play Store (com.cardellihermanos.hopetsit).
// - Google Play : lien réel, ?hl=<langue du site> → la fiche s'ouvre dans la
//   bonne langue automatiquement.
// v518 — APP APPROUVÉE PAR APPLE 🎉 : badge App Store activé. URL SANS code
// pays (pas /ca/) → Apple redirige chaque visiteur vers SON App Store
// national, dans sa langue (id 6763645719).
// Design = maquette index.html de Daniel (badges noirs officiels).

const PLAY_URL =
  "https://play.google.com/store/apps/details?id=com.cardellihermanos.hopetsit";
const APP_STORE_URL = "https://apps.apple.com/app/hopetsit/id6763645719";

// v577 — Daniel : « améliore ces deux boutons, traduits dans la bonne langue ».
// Petite ligne du badge dans les 9 langues du site (formulations des badges
// officiels Google / Apple), même largeur pour les deux, finition plus soignée
// (dégradé noir, reflet, ombre douce, léger soulèvement au survol, anneau de
// focus à la couleur de la marque). Le nom du store ne se traduit pas.
const PLAY_LABEL: Record<string, string> = {
  en: "Get it on",
  fr: "Disponible sur",
  es: "Disponible en",
  de: "Jetzt bei",
  it: "Disponibile su",
  pt: "Disponível no",
  pl: "Pobierz z",
  ko: "다운로드하기",
  ja: "で手に入れよう",
};
const APPLE_LABEL: Record<string, string> = {
  en: "Download on the",
  fr: "Télécharger dans l’",
  es: "Consíguelo en el",
  de: "Laden im",
  it: "Scarica su",
  pt: "Descarregar na",
  pl: "Pobierz w",
  ko: "다운로드하기",
  ja: "からダウンロード",
};
// v577b — texte jamais coupé : pas de hauteur figée, interligne 1.25 (les
// jambages de « g » et « y » étaient rognés), lignes insécables.
// En japonais la petite ligne se lit APRÈS le nom du store.
const LABEL_AFTER = new Set(["ja"]);

export default function StoreBadges({ center = false }: { center?: boolean }) {
  const { lang } = useT();

  const badge =
    "group inline-flex min-h-[60px] min-w-[196px] items-center gap-3 rounded-2xl border border-white/15 bg-gradient-to-b from-[#2A1B18] to-black px-4 py-2 text-white shadow-[0_8px_20px_rgba(201,42,18,0.22),inset_0_1px_0_rgba(255,255,255,0.14)] transition duration-200 hover:-translate-y-0.5 hover:shadow-[0_12px_26px_rgba(201,42,18,0.30),inset_0_1px_0_rgba(255,255,255,0.18)] active:translate-y-0 active:scale-[0.98] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#D83C28] focus-visible:ring-offset-2";
  const small = "whitespace-nowrap text-[11px] font-medium leading-[1.25] tracking-wide text-white/80";
  const big = "whitespace-nowrap text-[19px] font-semibold leading-[1.25] tracking-tight";
  const after = LABEL_AFTER.has(lang);
  const playLabel = PLAY_LABEL[lang] ?? PLAY_LABEL.en;
  const appleLabel = APPLE_LABEL[lang] ?? APPLE_LABEL.en;

  return (
    <div
      className={`flex flex-wrap items-center gap-3 ${center ? "justify-center" : ""}`}
    >
      {/* Google Play — EN LIGNE */}
      <a
        className={badge}
        aria-label={`${playLabel} Google Play`}
        href={`${PLAY_URL}&hl=${lang}`}
        target="_blank"
        rel="noopener noreferrer"
        onClick={() => trackSiteEvent("store_click", { store: "android" })}
      >
        <svg width="24" height="26" viewBox="0 0 512 512" aria-hidden="true">
          <path
            d="M48 59.49v393a4.33 4.33 0 0 0 7.37 3.07L260 256 55.37 56.42A4.33 4.33 0 0 0 48 59.49z"
            fill="#00d3ff"
          />
          <path
            d="M345.8 174L89.22 25.85 89 25.69a4.32 4.32 0 0 0-5.94 1.55L260 256z"
            fill="#00f076"
          />
          <path
            d="M83.06 484.76a4.29 4.29 0 0 0 5.94 1.55l.22-.13L345.8 338 260 256z"
            fill="#ff3a44"
          />
          <path
            d="M457.34 226.67L387.8 187 297.83 256l90 69 69.54-39.68a32.51 32.51 0 0 0 0-58.65z"
            fill="#ffc900"
          />
        </svg>
        <span className={`flex items-start gap-0.5 ${after ? "flex-col-reverse" : "flex-col"}`}>
          <span className={small}>{playLabel}</span>
          <span className={big}>Google Play</span>
        </span>
      </a>

      {/* App Store — EN LIGNE (approuvé par Apple, v518) */}
      <a
        className={badge}
        aria-label={`${appleLabel} App Store`}
        href={APP_STORE_URL}
        target="_blank"
        rel="noopener noreferrer"
        onClick={() => trackSiteEvent("store_click", { store: "ios" })}
      >
        <svg
          width="26"
          height="26"
          viewBox="0 0 24 24"
          fill="#fff"
          aria-hidden="true"
        >
          <path d="M17.05 12.54c-.02-2.02 1.65-2.99 1.73-3.04-.94-1.38-2.41-1.57-2.93-1.59-1.25-.13-2.44.73-3.07.73-.63 0-1.61-.71-2.65-.69-1.36.02-2.62.79-3.32 2.01-1.42 2.46-.36 6.1 1.01 8.1.67.98 1.47 2.08 2.51 2.04 1.01-.04 1.39-.65 2.61-.65 1.22 0 1.56.65 2.63.63 1.09-.02 1.78-1 2.44-1.99.77-1.14 1.09-2.24 1.11-2.3-.02-.01-2.13-.82-2.15-3.26zM15.03 6.59c.55-.67.93-1.6.82-2.53-.8.03-1.77.53-2.34 1.2-.51.59-.96 1.53-.84 2.44.89.07 1.8-.45 2.36-1.11z" />
        </svg>
        <span className={`flex items-start gap-0.5 ${after ? "flex-col-reverse" : "flex-col"}`}>
          <span className={small}>{appleLabel}</span>
          <span className={big}>App Store</span>
        </span>
      </a>
    </div>
  );
}
