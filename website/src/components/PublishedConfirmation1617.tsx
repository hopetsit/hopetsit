"use client";

// 1617 (LEO, 16/10/2026, §D.1 + §D.2) — ÉCRAN DE CONFIRMATION après la publication
// d'une demande depuis le site (/posts/create, avec ou sans compte au départ).
//   N > 0 : « N gardiens à moins de {km} km ont été prévenus · en général ils
//           répondent dans la journée » (N et km = réponse RÉELLE du serveur :
//           `notified` et `alertRadiusKm`, jamais un chiffre inventé).
//   N = 0 : « Aucun gardien près de chez toi pour l’instant : partage ton
//           annonce » + bouton Partager (Web Share API, repli : copier le lien).
//   N inconnu (serveur n'a pas répondu dans les 4 s) : titre seul + « Voir mes demandes ».
// « gardiens » → « promeneurs » si la demande est une balade.
// Tous les hooks en tête (règle de l'équipe : un hook après un retour conditionnel
// plante la page en production sans que tsc le voie). Zéro gris : encres de la
// charte (#231715 / #6E4F48), orange #C92A12, vert promeneur #16A34A.

import { useState } from "react";
import Link from "@/components/SiteLink";
import { AppIcon } from "@/components/AppIcon";
import { trackSiteEvent } from "@/components/SiteAnalytics";
import type { Lang } from "@/lib/i18n/langs";
import { notifiedSentence, p1617 } from "@/lib/i18n/publier1617";
// 620 (§B.5) — le site ramène dans l'app : « Ouvrir dans l'app » + « Télécharger l'app ».
import { AppBridge620 } from "@/components/AppBridge620";

export type PublishedInfo = {
  postId: string;
  notified: number | null;
  alertRadiusKm: number;
  walk: boolean;
  city: string;
};

/** Lien public à partager. Le site n'a pas de page publique par demande
 *  (/post/<id> = « Ouvre dans l'app ») : Paris → la page Paris (celle de la
 *  pub), sinon la PawMap publique centrée sur la ville, qui montre désormais
 *  les demandes en bulles (§B.5). */
export function shareUrlFor(info: PublishedInfo): string {
  const base = "https://www.hopetsit.com";
  const folded = info.city.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().trim();
  if (/^paris\b/.test(folded)) return `${base}/garde-animaux/paris`;
  if (info.city.trim()) return `${base}/pawmap?city=${encodeURIComponent(info.city.trim())}`;
  return `${base}/pawmap`;
}

export default function PublishedConfirmation1617({ info, lang }: { info: PublishedInfo; lang: Lang }) {
  const [copied, setCopied] = useState(false);
  const n = info.notified;
  const none = n === 0;
  const accent = info.walk ? "#16A34A" : "#C92A12";
  const url = shareUrlFor(info);

  async function share() {
    trackSiteEvent("cta_click", { label: "pub_partager_1617" });
    const text = `${p1617(lang, "share_text")} ${url}`;
    try {
      if (typeof navigator !== "undefined" && typeof navigator.share === "function") {
        await navigator.share({ title: "HoPetSit", text: p1617(lang, "share_text"), url });
        return;
      }
    } catch { /* annulé par la personne : on propose la copie */ }
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      setTimeout(() => setCopied(false), 2500);
    } catch {
      // Dernier repli : sélection manuelle via prompt natif.
      try { window.prompt(p1617(lang, "share"), url); } catch { /* rien */ }
    }
  }

  return (
    <div data-testid="published-1617" className="mx-auto max-w-lg px-4 py-10 md:py-24">
      <div className="rounded-3xl border border-owner/20 bg-white p-7 text-center shadow-card">
        <span className="mx-auto grid h-16 w-16 place-items-center rounded-full" style={{ background: accent }} aria-hidden="true">
          <AppIcon name={none ? "people" : "check"} size={30} color="#fff" />
        </span>
        <h1 className="mt-5 font-display text-2xl font-extrabold leading-tight tracking-tight text-[#231715] md:text-3xl">
          {p1617(lang, "done_title")}
        </h1>
        {n !== null && (
          <p data-testid="notified-sentence" className="mt-3 text-[15px] font-semibold leading-relaxed" style={{ color: none ? "#C92A12" : "#231715" }}>
            {notifiedSentence(lang, n, info.alertRadiusKm, info.walk)}
          </p>
        )}
        {none && <p className="mt-2 text-sm leading-relaxed text-[#6E4F48]">{p1617(lang, "none_hint")}</p>}

        <div className="mt-6 flex flex-col gap-3">
          {none && (
            <button
              type="button"
              onClick={share}
              data-testid="share-btn"
              className="flex min-h-[48px] w-full items-center justify-center gap-2 rounded-full bg-owner px-6 text-base font-bold text-white shadow-cta transition hover:bg-owner-dark"
            >
              <AppIcon name="megaphone" size={18} color="#fff" />
              {copied ? p1617(lang, "copied") : p1617(lang, "share")}
            </button>
          )}
          <Link
            href="/posts"
            className={`flex min-h-[48px] w-full items-center justify-center gap-2 rounded-full px-6 text-base font-bold transition ${none ? "border-2 border-owner bg-white text-owner-dark hover:bg-owner-light" : "bg-owner text-white shadow-cta hover:bg-owner-dark"}`}
          >
            {p1617(lang, "see_requests")}
            <AppIcon name="arrow-right" size={16} color={none ? "#A3220E" : "#fff"} />
          </Link>
        </div>
      </div>
      <div className="mt-4">
        <AppBridge620 lang={lang} loggedIn />
      </div>
    </div>
  );
}
