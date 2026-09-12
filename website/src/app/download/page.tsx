"use client";

import StoreBadges from "@/components/StoreBadges";
import { useT } from "@/lib/i18n/LanguageProvider";
import { screensPreviewFor, PhoneFrame } from "@/lib/screens";

// v508 — badges stores réels. v562 — mise en page minimaliste (Daniel) :
// titre XXL centré, badges, puis 4 captures réelles de la v561 dans des
// cadres sobres sur fond gris clair.
export default function DownloadPage() {
  const { t, lang } = useT();

  return (
    <div className="bg-white">
      <div className="mx-auto max-w-3xl px-4 pb-10 pt-20 text-center md:pt-28">
        <h1 className="font-display text-[2.75rem] font-bold leading-[1.05] tracking-[-0.03em] text-[#1D1D1F] md:text-6xl">
          {t("dl_title")}
        </h1>
        <p className="mx-auto mt-5 max-w-xl text-lg text-[#6E6E73]">{t("dl_sub")}</p>
        <div className="mt-10 flex justify-center">
          <StoreBadges center />
        </div>
      </div>

      <div className="bg-[#F5F5F7] py-16">
        <div className="mx-auto flex max-w-5xl snap-x snap-mandatory gap-6 overflow-x-auto px-4 pb-4 [-ms-overflow-style:none] [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
          {screensPreviewFor(lang).map((s) => (
            <PhoneFrame key={s.src} src={s.src} alt={`HoPetSit — ${s.alt}`} className="w-48 shrink-0 snap-center first:ml-auto last:mr-auto" />
          ))}
        </div>
      </div>
    </div>
  );
}
