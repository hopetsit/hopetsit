"use client";

import { useT } from "@/lib/i18n/LanguageProvider";

const APK_URL = "/HoPetSit.apk"; // placeholder — host the APK at this path or change to a Render URL.

export default function DownloadPage() {
  const { t } = useT();

  return (
    <div className="mx-auto max-w-2xl px-4 py-16 md:py-24">
      <h1 className="text-center font-display text-4xl font-extrabold tracking-tight md:text-5xl">
        {t("dl_title")}
      </h1>
      <p className="mt-4 text-center text-lg text-ink-muted">{t("dl_sub")}</p>

      <div className="mt-12 grid gap-4">
        <a
          href={APK_URL}
          download
          className="flex items-center justify-between rounded-2xl bg-walker p-5 text-white shadow-cta hover:bg-walker-dark"
        >
          <span className="flex items-center gap-3">
            <span className="text-2xl">🤖</span>
            <span>
              <span className="block text-xs uppercase tracking-wider opacity-80">Android · APK · 93 MB</span>
              <span className="text-base font-bold">{t("dl_apk")}</span>
            </span>
          </span>
          <span className="text-xl">→</span>
        </a>

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
