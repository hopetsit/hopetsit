"use client";

/**
 * 06/11/2026 (SAM, ordre de Daniel) — bandeau de consentement sobre pour le pixel Meta.
 * fr / en d'après la langue affichée (data-ui-lang, posée par LanguageProvider ; repli <html lang>).
 * « Accepter » → localStorage "yes" + le pixel se charge (MetaPixel). « Refuser » → "no", rien ne charge.
 * Tant que rien n'est choisi : aucun cookie, aucun script Meta. La mesure maison (SiteAnalytics, sans
 * cookie) ne dépend pas de ce choix. Rendu : barre en bas, 375 px et bureau.
 * Règle des hooks : tous AVANT le premier return conditionnel.
 *
 * 06/11 soir (SAM) — mesuré à 375 px en ligne : la barre en bas (131 px, z 60) RECOUVRAIT la barre
 * collante « Publier ma demande gratuite » (z 40) et « Télécharger l'app », et son bouton orange
 * ressemblait au bouton principal. Désormais :
 *  - bandeau compact (une ligne) collé SOUS l'en-tête, jamais en bas : aucune barre d'action masquée ;
 *  - deux boutons neutres de même poids (l'orange reste réservé à « Publier ») ;
 *  - jamais affiché sur les pages où l'on agit (publier, confirmer, payer, candidature) : le Lead et
 *    le Purchase y partent de toute façon par le serveur (Conversions API), sans le navigateur.
 */
import { useEffect, useState } from "react";
import { usePathname } from "next/navigation";

/** Pages d'action : rien ne doit se poser par-dessus le bouton qui compte. */
const PAGES_SANS_BANDEAU = [
  "/posts/merci", "/posts/confirmer", "/posts/create", "/post", "/application",
  "/demande", "/request", // 09/11 (BOB) : pages de pub — le bandeau recouvrait le titre à 375 px ; le Lead CAPI serveur suffit
  "/pay", "/book", "/bookings", "/checkout", "/login", "/signup", "/verify-email",
];
import { CONSENT_EVENT, readConsent, writeConsent } from "@/lib/metaPixel0611";

const TXT = {
  fr: {
    text: "Pixel Meta pour mesurer nos pubs, aucun autre traceur.",
    more: "Détails",
    yes: "Accepter",
    no: "Refuser",
  },
  en: {
    text: "Meta pixel to measure our ads, no other tracker.",
    more: "Details",
    yes: "Accept",
    no: "Decline",
  },
  // 1011 (ZOE, ordre de Daniel « les pages ne sont pas à jour dans les autres langues ») — 7 langues
  // ajoutées ICI, en ligne : ce bandeau est chargé sur toutes les pages, pas d'import d'une grosse table.
  es: {
    text: "Píxel de Meta para medir nuestros anuncios, ningún otro rastreador.",
    more: "Detalles",
    yes: "Aceptar",
    no: "Rechazar",
  },
  de: {
    text: "Meta-Pixel, um unsere Anzeigen zu messen, kein anderer Tracker.",
    more: "Details",
    yes: "Akzeptieren",
    no: "Ablehnen",
  },
  it: {
    text: "Pixel di Meta per misurare le nostre inserzioni, nessun altro tracciante.",
    more: "Dettagli",
    yes: "Accetta",
    no: "Rifiuta",
  },
  pt: {
    text: "Pixel da Meta para medir os nossos anúncios, nenhum outro rastreador.",
    more: "Detalhes",
    yes: "Aceitar",
    no: "Recusar",
  },
  pl: {
    text: "Piksel Meta do pomiaru naszych reklam, żadnego innego trackera.",
    more: "Szczegóły",
    yes: "Akceptuj",
    no: "Odrzuć",
  },
  ko: {
    text: "광고 성과 측정을 위한 Meta 픽셀만 사용하며, 다른 추적기는 없어요.",
    more: "자세히",
    yes: "동의",
    no: "거부",
  },
  ja: {
    text: "広告の効果測定に Meta ピクセルのみを使用します。ほかのトラッカーはありません。",
    more: "詳細",
    yes: "同意する",
    no: "拒否する",
  },
};
type BannerLang = keyof typeof TXT;

function uiLang(): BannerLang {
  try {
    const root = document.documentElement;
    const l = (root.dataset.uiLang || root.lang || "fr").slice(0, 2).toLowerCase();
    return l in TXT ? (l as BannerLang) : "en";
  } catch {
    return "fr";
  }
}

export default function ConsentBanner() {
  const [show, setShow] = useState(false);
  const [lang, setLang] = useState<BannerLang>("fr");
  const [top, setTop] = useState(56);
  const pathname = usePathname() || "/";

  useEffect(() => {
    // Après l'hydratation seulement (localStorage + langue affichée).
    setLang(uiLang());
    setShow(readConsent() === "");
    try {
      // Juste sous l'en-tête fixe (57 px sur mobile), quelle que soit sa hauteur.
      const h = document.querySelector("header")?.getBoundingClientRect().bottom;
      if (h && h > 0 && h < 160) setTop(Math.round(h));
    } catch { /* garde 56 */ }
    const onChoice = () => setShow(false);
    window.addEventListener(CONSENT_EVENT, onChoice);
    // 1011 (BOB) — la langue du visiteur est posée sur <html> APRÈS ce montage (effet du
    // LanguageProvider, puis chargement du dictionnaire) : sans ce suivi, le bandeau restait
    // en français pour un visiteur allemand, polonais, coréen… sur une page servie en français.
    let obs: MutationObserver | null = null;
    try {
      obs = new MutationObserver(() => setLang(uiLang()));
      obs.observe(document.documentElement, { attributes: true, attributeFilter: ["data-ui-lang", "lang"] });
    } catch { /* vieux navigateur : garde la langue lue au montage */ }
    return () => {
      window.removeEventListener(CONSENT_EVENT, onChoice);
      if (obs) obs.disconnect();
    };
  }, []);

  const nu = pathname.replace(/^\/[a-z]{2}(?=\/)/, ""); // /en/posts/merci → /posts/merci
  const pageAction = PAGES_SANS_BANDEAU.some((p) => nu === p || nu.startsWith(p + "/"));
  if (!show || pageAction) return null;
  const t = TXT[lang];
  const btn = "min-h-[32px] rounded-lg border border-[#D9C3BC] bg-white px-3 text-[13px] font-semibold text-[#4A3B37]";
  return (
    <div
      role="dialog"
      aria-live="polite"
      aria-label={t.text}
      data-consent-0611=""
      className="fixed inset-x-0 z-[60] border-b border-[#F1D9D2] bg-white/95 px-3 py-1.5 shadow-[0_2px_8px_rgba(0,0,0,0.06)] backdrop-blur"
      style={{ top }}
    >
      <div className="mx-auto flex max-w-3xl items-center gap-2">
        <p className="m-0 min-w-0 flex-1 text-[12px] leading-tight text-[#4A3B37]">
          {t.text}{" "}
          <a href="/privacy" className="underline underline-offset-2" style={{ color: "#4A3B37" }}>{t.more}</a>
        </p>
        <button type="button" onClick={() => writeConsent("no")} className={btn}>{t.no}</button>
        <button type="button" onClick={() => writeConsent("yes")} className={btn}>{t.yes}</button>
      </div>
    </div>
  );
}
