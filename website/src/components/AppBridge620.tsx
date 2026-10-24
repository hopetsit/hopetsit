"use client";

// 24/10/2026 (620, LEO — §B.5, règle de Daniel : « 100 % digital, l'APP est le
// produit, le site RAMÈNE dans l'app ») : après la publication d'une demande et
// sur les candidatures, « Ouvrir dans l'app » (jeton à usage unique → l'app
// s'ouvre connectée, composant existant) + « Télécharger l'app » (store de
// l'appareil, composant existant). Orange propriétaire, zéro gris.

import { GetAppButton } from "@/components/GetAppButton";
import { OpenInAppButton } from "@/components/OpenInAppButton";
import { AppIcon } from "@/components/AppIcon";
import type { Lang } from "@/lib/i18n/langs";
import { d620 } from "@/lib/i18n/dates620";

export function AppBridge620({ lang, loggedIn, compact }: { lang: Lang; loggedIn: boolean; compact?: boolean }) {
  return (
    <section data-testid="app-bridge-620" className={`rounded-2xl ${compact ? "p-3" : "p-4"}`} style={{ background: "#231715" }} aria-label={d620(lang, "app_title")}>
      <div className="flex items-start gap-3">
        <span className="grid h-10 w-10 shrink-0 place-items-center rounded-xl" style={{ background: "#C92A12" }}>
          <AppIcon name="phone" size={20} color="#fff" />
        </span>
        <div className="min-w-0 flex-1">
          <p className="text-[15px] font-extrabold leading-tight text-white">{d620(lang, "app_title")}</p>
          <p className="mt-0.5 text-xs leading-snug" style={{ color: "#F3D9D2" }}>{d620(lang, "app_sub")}</p>
        </div>
      </div>
      <div className="mt-3 flex flex-col gap-2 sm:flex-row sm:flex-wrap sm:items-center">
        {loggedIn && <OpenInAppButton label={d620(lang, "app_open")} className="[&_button]:w-full sm:[&_button]:w-auto" />}
        <GetAppButton label={d620(lang, "app_get")} className="inline-flex min-h-[44px] items-center justify-center rounded-xl border-2 border-white px-5 text-sm font-bold text-white" />
      </div>
    </section>
  );
}

export default AppBridge620;
