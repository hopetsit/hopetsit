"use client";

import Link from "next/link";
import { useT } from "@/lib/i18n/LanguageProvider";

/**
 * v510 — page de retour de la vérification d'identité Didit.
 * Didit redirige ici à la fin du parcours (callback). Deux cas :
 *  - Dans l'APP : la WebView KYC intercepte toute navigation dont l'URL
 *    contient « complete » et se ferme AVANT de charger cette page
 *    (kyc_verification_screen.dart) — donc cette page n'y est jamais vue.
 *  - Dans un NAVIGATEUR : on affiche une confirmation propre.
 */
export default function KycCompletePage() {
  const { t } = useT();
  return (
    <div className="mx-auto max-w-md px-4 py-24 text-center">
      <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-full bg-emerald-50 text-3xl">
        ✅
      </div>
      <h1 className="mt-5 font-display text-2xl font-extrabold text-ink">
        {t("kyccb_title")}
      </h1>
      <p className="mt-3 text-sm text-ink-muted">{t("kyccb_body")}</p>
      <Link
        href="/dashboard"
        className="mt-6 inline-block rounded-full bg-owner px-6 py-2.5 text-sm font-semibold text-white"
      >
        {t("kyccb_back")}
      </Link>
    </div>
  );
}
