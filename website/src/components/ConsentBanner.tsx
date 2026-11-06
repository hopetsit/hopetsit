"use client";

/**
 * 06/11/2026 (SAM, ordre de Daniel) — bandeau de consentement sobre pour le pixel Meta.
 * fr / en d'après la langue affichée (data-ui-lang, posée par LanguageProvider ; repli <html lang>).
 * « Accepter » → localStorage "yes" + le pixel se charge (MetaPixel). « Refuser » → "no", rien ne charge.
 * Tant que rien n'est choisi : aucun cookie, aucun script Meta. La mesure maison (SiteAnalytics, sans
 * cookie) ne dépend pas de ce choix. Rendu : barre en bas, 375 px et bureau.
 * Règle des hooks : tous AVANT le premier return conditionnel.
 */
import { useEffect, useState } from "react";
import { CONSENT_EVENT, readConsent, writeConsent } from "@/lib/metaPixel0611";

const TXT = {
  fr: {
    text: "HoPetSit utilise un pixel Meta pour mesurer l'efficacité de ses publicités (demandes publiées, réservations). Aucun autre traceur.",
    more: "En savoir plus",
    yes: "Accepter",
    no: "Refuser",
  },
  en: {
    text: "HoPetSit uses a Meta pixel to measure its ads (requests published, bookings). No other tracker.",
    more: "Learn more",
    yes: "Accept",
    no: "Decline",
  },
};

function uiLang(): "fr" | "en" {
  try {
    const root = document.documentElement;
    const l = (root.dataset.uiLang || root.lang || "fr").slice(0, 2).toLowerCase();
    return l === "fr" ? "fr" : "en";
  } catch {
    return "fr";
  }
}

export default function ConsentBanner() {
  const [show, setShow] = useState(false);
  const [lang, setLang] = useState<"fr" | "en">("fr");

  useEffect(() => {
    // Après l'hydratation seulement (localStorage + langue affichée).
    setLang(uiLang());
    setShow(readConsent() === "");
    const onChoice = () => setShow(false);
    window.addEventListener(CONSENT_EVENT, onChoice);
    return () => window.removeEventListener(CONSENT_EVENT, onChoice);
  }, []);

  if (!show) return null;
  const t = TXT[lang];
  return (
    <div
      role="dialog"
      aria-live="polite"
      aria-label={t.text}
      data-consent-0611=""
      className="fixed inset-x-0 bottom-0 z-[60] border-t border-[#F1D9D2] bg-white/95 px-4 py-3 shadow-[0_-4px_16px_rgba(0,0,0,0.08)] backdrop-blur"
      style={{ paddingBottom: "max(12px, env(safe-area-inset-bottom))" }}
    >
      <div className="mx-auto flex max-w-3xl flex-col gap-3 sm:flex-row sm:items-center">
        <p className="m-0 flex-1 text-[13px] leading-snug text-[#4A3B37]">
          {t.text}{" "}
          <a href="/privacy" className="underline underline-offset-2" style={{ color: "#C92A12" }}>{t.more}</a>
        </p>
        <div className="flex shrink-0 gap-2">
          <button
            type="button"
            onClick={() => writeConsent("no")}
            className="min-h-[40px] flex-1 rounded-xl border border-[#E6CFC8] bg-white px-4 text-[14px] font-semibold text-[#4A3B37] sm:flex-none"
          >
            {t.no}
          </button>
          <button
            type="button"
            onClick={() => writeConsent("yes")}
            className="min-h-[40px] flex-1 rounded-xl px-4 text-[14px] font-bold text-white sm:flex-none"
            style={{ background: "linear-gradient(90deg, #C92A12, #E8502A)" }}
          >
            {t.yes}
          </button>
        </div>
      </div>
    </div>
  );
}
