"use client";

import { useT } from "@/lib/i18n/LanguageProvider";

// v23.1.317 — Daniel : "enlever l'APK du site web" (avant lancement Play Store ;
// Google déconseille la distribution du même APK hors store). Le téléchargement
// direct est retiré, on affiche "bientôt sur Google Play / App Store".

export default function DownloadPage() {
  const { t } = useT();

  return (
    <div className="mx-auto max-w-2xl px-4 py-16 md:py-24">
      <h1 className="text-center font-display text-4xl font-extrabold tracking-tight md:text-5xl">
        {t("dl_title")}
      </h1>
      <p className="mt-4 text-center text-lg text-ink-muted">{t("dl_sub")}</p>

      <div className="mt-12 grid gap-4">
        <div className="flex items-center justify-between rounded-2xl border border-ink/10 bg-white p-5 opacity-70">
          <span className="flex items-center gap-3">
            <span className="text-2xl">🤖</span>
            <span>
              <span className="block text-xs uppercase tracking-wider text-ink-soft">Android · Google Play</span>
              <span className="text-base font-bold text-ink">{t("dl_play")}</span>
            </span>
          </span>
          <span className="text-xs text-ink-soft">soon</span>
        </div>

        <div className="flex items-center justify-between rounded-2xl border border-ink/10 bg-white p-5 opacity-70">
          <span className="flex items-center gap-3">
            <span className="text-2xl">▶</span>
            <span>
              <span className="block text-xs uppercase tracking-wider text-ink-soft">Google Play</span>
              <span className="text-base font-bold text-ink">{t("dl_play")}</span>
            </span>
          </span>
          <span className="text-xs text-ink-soft">soon</span>
        </div>

        <div className="flex items-center justify-between rounded-2xl border border-ink/10 bg-white p-5 opacity-70">
          <span className="flex items-center gap-3">
            <span className="text-2xl"></span>
            <span>
              <span className="block text-xs uppercase tracking-wider text-ink-soft">App Store</span>
              <span className="text-base font-bold text-ink">{t("dl_app_store")}</span>
            </span>
          </span>
          <span className="text-xs text-ink-soft">soon</span>
        </div>
      </div>
    </div>
  );
}
