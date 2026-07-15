"use client";

import StoreBadges from "@/components/StoreBadges";
import { useT } from "@/lib/i18n/LanguageProvider";

// v508 — Daniel : l'app est EN LIGNE sur le Play Store 🎉 → vrais badges
// stores (Google Play actif + hl=<langue>, App Store « bientôt »). Remplace
// les deux cartes grises « soon » de la v317.

export default function DownloadPage() {
  const { t } = useT();

  return (
    <div className="mx-auto max-w-2xl px-4 py-16 md:py-24">
      <h1 className="text-center font-display text-4xl font-extrabold tracking-tight md:text-5xl">
        {t("dl_title")}
      </h1>
      <p className="mt-4 text-center text-lg text-ink-muted">{t("dl_sub")}</p>

      <div className="mt-12 flex justify-center">
        <StoreBadges center />
      </div>

      {/* Aperçu de l'app sous les badges (réutilise les captures store).
          v525 — Daniel : nouvelles captures US (Dallas/$, suffixe _us pour
          casser le cache CDN). */}
      <div className="mt-14 flex snap-x snap-mandatory gap-4 overflow-x-auto pb-4 [-ms-overflow-style:none] [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
        {[
          "/screens/02_pawmap_us.jpg",
          "/screens/03_sitter_us.jpg",
          "/screens/05_live_tracking_us.jpg",
          "/screens/04_chat_us.jpg",
        ].map((src) => (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            key={src}
            src={src}
            alt="HoPetSit"
            loading="lazy"
            width={640}
            height={1385}
            className="w-36 shrink-0 snap-center rounded-2xl shadow-xl ring-1 ring-black/5 first:ml-auto last:mr-auto"
          />
        ))}
      </div>
    </div>
  );
}
