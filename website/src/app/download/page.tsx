"use client";

import StoreBadges from "@/components/StoreBadges";
import { useT } from "@/lib/i18n/LanguageProvider";
// v534 — captures d'ecran par langue (EN / FR).
import { screensPreviewFor } from "@/lib/screens";

// v508 — Daniel : l'app est EN LIGNE sur le Play Store 🎉 → vrais badges
// stores (Google Play actif + hl=<langue>, App Store « bientôt »). Remplace
// les deux cartes grises « soon » de la v317.

export default function DownloadPage() {
  const { t, lang } = useT();

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
        {/* v534 — jeu FRANCAIS quand le site est en francais, ANGLAIS sinon.
            Avant, les visuels anglais etaient affiches en dur a tout le monde. */}
        {screensPreviewFor(lang).map((s) => (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            key={s.src}
            src={s.src}
            alt={`HoPetSit — ${s.alt}`}
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
