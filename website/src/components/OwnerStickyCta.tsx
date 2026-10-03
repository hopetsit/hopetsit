"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { trackSiteEvent } from "@/components/SiteAnalytics";

// 03/10/2026 (SAM) — barre « Publier ma demande » collée en bas de l'écran,
// téléphone seulement (md:hidden).
// Mesure du 03/10 (admin « Trafic du site », 7 j) : /garde-animaux/paris =
// 390 visiteurs de la pub → 50 restent 3 s → 2 clics « Publier ma demande »
// (signup_web). À 375 px, les 3 profils de gardiens poussent le bouton SOUS
// le premier écran (capture du 02/10) : la plupart des visiteurs ne le voient
// jamais. La barre le rend visible dès l'arrivée, sans rien retirer.
// Clic compté à part (« signup_web_barre ») pour comparer avec le bouton de
// la page. Elle se retire en bas de page pour ne pas cacher le pied de page.
export function OwnerStickyCta({ label, city }: { label: string; city?: string }) {
  const [hidden, setHidden] = useState(false);
  useEffect(() => {
    const onScroll = () => {
      const bas = window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 480;
      setHidden(bas);
    };
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onScroll);
    return () => {
      window.removeEventListener("scroll", onScroll);
      window.removeEventListener("resize", onScroll);
    };
  }, []);

  const href = `/posts/create${city ? `?city=${encodeURIComponent(city)}` : ""}`;
  return (
    <div
      className={`fixed inset-x-0 bottom-0 z-40 border-t border-ink/10 bg-white/95 px-4 pt-3 backdrop-blur transition-transform duration-200 md:hidden ${hidden ? "translate-y-full" : "translate-y-0"}`}
      style={{ paddingBottom: "calc(env(safe-area-inset-bottom, 0px) + 12px)" }}
      aria-hidden={hidden}
    >
      <Link
        href={href}
        tabIndex={hidden ? -1 : 0}
        onClick={() => trackSiteEvent("cta_click", { label: "signup_web_barre" })}
        className="block w-full rounded-full bg-owner px-6 py-3.5 text-center text-base font-bold text-white shadow-card"
      >
        {label}
      </Link>
    </div>
  );
}

export default OwnerStickyCta;
