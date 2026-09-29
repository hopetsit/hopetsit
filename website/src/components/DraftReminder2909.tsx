"use client";
// 29/09/2026 (NEO, mission BOB) — RAPPEL DU BROUILLON AU RETOUR SUR LE SITE.
//
// Le formulaire /posts/create garde la demande d'un invité dans le navigateur
// (clé `hopetsit_post_draft_v1`) le temps de l'inscription. Mesure du 29/09 :
// 4 visiteurs ont ouvert ce formulaire en 30 jours, 1 seul a publié. Celui qui
// part sans finir revient souvent par l'accueil ou une page ville, où rien ne
// lui rappelle sa demande. Ce bandeau la lui rend : un clic → le formulaire,
// pré-rempli tel qu'il l'a laissé. Aucun e-mail, aucune donnée envoyée :
// tout reste dans son navigateur. « Plus tard » le cache pour la session
// (le brouillon n'est PAS effacé).
//
// Règle du dépôt : tous les hooks AVANT tout retour conditionnel.
import { useEffect, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useT } from "@/lib/i18n/LanguageProvider";
import { trackSiteEvent } from "@/components/SiteAnalytics";
import { pr } from "@/lib/i18n/proof2909";

const DRAFT_KEY = "hopetsit_post_draft_v1";
const HIDE_KEY = "hopetsit_post_draft_hide_2909";
// Pages où le visiteur est DÉJÀ en train de finir : pas de doublon.
const QUIET = ["/posts/create", "/login", "/signup", "/verify-email"];

/** Vrai si le brouillon contient un début de demande (texte ou ville). */
export function draftHasContent(raw: string | null): boolean {
  if (!raw) return false;
  try {
    const d = JSON.parse(raw) as { body?: unknown; city?: unknown };
    return (typeof d.body === "string" && d.body.trim().length > 0)
      || (typeof d.city === "string" && d.city.trim().length > 0);
  } catch {
    return false;
  }
}

export default function DraftReminder2909() {
  const { lang } = useT();
  const pathname = usePathname() || "/";
  const [show, setShow] = useState(false);
  const quiet = QUIET.some((p) => pathname === p || pathname.endsWith(p));

  useEffect(() => {
    if (quiet) { setShow(false); return; }
    let visible = false;
    try {
      visible = draftHasContent(window.localStorage.getItem(DRAFT_KEY))
        && window.sessionStorage.getItem(HIDE_KEY) !== "1";
    } catch { visible = false; }
    setShow(visible);
    if (visible) trackSiteEvent("cta_click", { label: "pub_rappel_vu" });
  }, [pathname, quiet]);

  if (!show) return null;

  return (
    <div data-testid="draft-reminder-2909" className="mx-auto mt-3 w-full max-w-5xl px-4">
      <div className="flex flex-col gap-3 rounded-2xl border border-owner/30 bg-owner-light p-4 sm:flex-row sm:items-center">
        <div className="min-w-0 flex-1">
          <p className="font-display text-base font-extrabold text-owner-dark">{pr(lang, "draft_title")}</p>
          <p className="mt-0.5 text-sm leading-snug text-[#6E4F48]">{pr(lang, "draft_sub")}</p>
        </div>
        <div className="flex shrink-0 items-center gap-3">
          <Link
            href="/posts/create"
            onClick={() => trackSiteEvent("cta_click", { label: "pub_rappel_clic" })}
            className="inline-flex min-h-[44px] items-center justify-center rounded-full bg-owner px-5 text-sm font-semibold text-white shadow-cta hover:bg-owner-dark"
          >
            {pr(lang, "draft_cta")}
          </Link>
          <button
            type="button"
            onClick={() => {
              try { window.sessionStorage.setItem(HIDE_KEY, "1"); } catch { /* navigation privée */ }
              setShow(false);
            }}
            className="min-h-[44px] text-sm font-semibold text-owner-dark underline"
          >
            {pr(lang, "draft_later")}
          </button>
        </div>
      </div>
    </div>
  );
}
