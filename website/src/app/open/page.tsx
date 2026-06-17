"use client";

import { useEffect } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";

// v449 — Lien canonique des emails HoPetSit. Daniel : « tous les boutons des
// emails : ouvrir l'app si installée, sinon rediriger vers /download. Jamais
// une page vide ou ancienne. Logique simple et fiable. »
//
// Comment ça marche :
//   - App INSTALLÉE → l'OS intercepte l'App Link (Android, autoVerify) /
//     Universal Link (iOS, applinks:hopetsit.com) AVANT que cette page se
//     charge → l'application s'ouvre directement. Cette page ne s'affiche
//     même pas.
//   - App NON installée (ou App Link non vérifié) → le navigateur charge
//     cette page. On tente une dernière ouverture via le schéma custom
//     `hopetsit://open`, puis on bascule automatiquement sur /download.
//
// Couvre iPhone, Android, navigateur desktop et PWA : dans tous les cas on
// finit soit dans l'app, soit sur /download — jamais une page morte.

export default function OpenAppPage() {
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
      window.location.href = "hopetsit://open";
    } catch {
      /* schéma non supporté (desktop) → le timeout redirige vers /download */
    }

    return () => {
      clearTimeout(timer);
      document.removeEventListener("visibilitychange", onVisibility);
    };
  }, []);

  return (
    <div className="mx-auto flex max-w-md flex-col items-center px-4 py-24 text-center">
      <div className="h-12 w-12 animate-spin rounded-full border-4 border-ink/10 border-t-[#EF4324]" />
      <h1 className="mt-8 font-display text-2xl font-extrabold tracking-tight">
        {t("open_app_title")}
      </h1>
      <p className="mt-3 text-ink-muted">{t("open_app_sub")}</p>
      <a
        href="/download"
        className="mt-8 inline-block rounded-full bg-[#EF4324] px-8 py-3 font-bold text-white shadow-lg shadow-[#EF4324]/30 transition hover:brightness-105"
      >
        {t("open_app_download")}
      </a>
    </div>
  );
}
