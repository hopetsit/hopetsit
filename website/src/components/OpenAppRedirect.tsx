"use client";

// v565 — logique commune de /open et /open/<route> : tenter d'ouvrir l'app
// sur le chemin demandé (`hopetsit://<route>`), et basculer sur /download si
// rien ne se passe (app absente, desktop). Extrait de app/open/page.tsx (v449)
// pour servir aussi aux liens `/open/*` des e-mails.

import { useEffect } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";

export function OpenAppRedirect({ route = "open" }: { route?: string }) {
  const { t } = useT();

  useEffect(() => {
    let redirected = false;
    const goDownload = () => {
      if (redirected) return;
      redirected = true;
      window.location.replace("/download");
    };

    // Fallback : si l'app ne s'ouvre pas, on part sur /download.
    const timer = setTimeout(goDownload, 1400);

    // Si l'onglet passe en arrière-plan, c'est que l'app s'est ouverte →
    // on annule la redirection vers /download.
    const onVisibility = () => {
      if (document.visibilityState === "hidden") {
        clearTimeout(timer);
      }
    };
    document.addEventListener("visibilitychange", onVisibility);

    // Tentative d'ouverture de l'app via le schéma custom (deferred deep link).
    try {
      const clean = route.replace(/^\/+/, "") || "open";
      window.location.href = `hopetsit://${clean}${window.location.search ?? ""}`;
    } catch {
      /* schéma non supporté (desktop) → le timeout redirige vers /download */
    }

    return () => {
      clearTimeout(timer);
      document.removeEventListener("visibilitychange", onVisibility);
    };
  }, [route]);

  return (
    <div className="mx-auto flex max-w-md flex-col items-center px-4 py-24 text-center">
      <div className="h-12 w-12 animate-spin rounded-full border-4 border-ink/10 border-t-[#C92A12]" />
      <h1 className="mt-8 font-display text-2xl font-extrabold tracking-tight">
        {t("open_app_title")}
      </h1>
      <p className="mt-3 text-ink-muted">{t("open_app_sub")}</p>
      <a
        href="/download"
        className="mt-8 inline-block rounded-full bg-[#C92A12] px-8 py-3 font-bold text-white shadow-lg shadow-[#C92A12]/30 transition hover:brightness-105"
      >
        {t("open_app_download")}
      </a>
    </div>
  );
}

export default OpenAppRedirect;
