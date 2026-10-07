"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { trackSiteEvent, useCampaignHref } from "@/components/SiteAnalytics";

// 03/10/2026 (SAM) — barre « Publier ma demande » collée en bas de l'écran,
// téléphone seulement (md:hidden).
// Mesure du 03/10 (admin « Trafic du site », 7 j) : /garde-animaux/paris =
// 390 visiteurs de la pub → 50 restent 3 s → 2 clics « Publier ma demande »
// (signup_web). À 375 px, les 3 profils de gardiens poussent le bouton SOUS
// le premier écran (capture du 02/10) : la plupart des visiteurs ne le voient
// jamais. La barre le rend visible dès l'arrivée, sans rien retirer.
// Clic compté à part (« signup_web_barre ») pour comparer avec le bouton de
// la page. Elle se retire en bas de page pour ne pas cacher le pied de page.
export function OwnerStickyCta({ label, city, watchId }: { label: string; city?: string; watchId?: string }) {
  const [hidden, setHidden] = useState(false);
  // 08/10 (SAM) — page Paris : tant que le gros bouton du premier écran
  // (id watchId) est visible, la barre reste cachée → un seul bouton à l'écran.
  const [heroVu, setHeroVu] = useState(!!watchId);
  useEffect(() => {
    if (!watchId) return;
    const el = document.getElementById(watchId);
    if (!el || typeof IntersectionObserver === "undefined") {
      setHeroVu(false);
      return;
    }
    const io = new IntersectionObserver(([e]) => setHeroVu(e.isIntersecting), { threshold: 0 });
    io.observe(el);
    return () => io.disconnect();
  }, [watchId]);
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

  // 05/10 (SAM) : utm_* recopiés, sinon le formulaire perd l'origine « pub ».
  const cache = hidden || heroVu;
  const href = useCampaignHref(`/posts/create${city ? `?city=${encodeURIComponent(city)}` : ""}`);
  return (
    <div
      className={`fixed inset-x-0 bottom-0 z-40 border-t border-ink/10 bg-white/95 px-4 pt-3 backdrop-blur transition-transform duration-200 md:hidden ${cache ? "translate-y-full" : "translate-y-0"}`}
      style={{ paddingBottom: "calc(env(safe-area-inset-bottom, 0px) + 12px)" }}
      aria-hidden={cache}
    >
      <Link
        href={href}
        tabIndex={cache ? -1 : 0}
        onClick={() => trackSiteEvent("cta_click", { label: "signup_web_barre" })}
        className="block w-full rounded-full bg-owner px-6 py-3.5 text-center text-base font-bold text-white shadow-card"
      >
        {label}
      </Link>
    </div>
  );
}

export default OwnerStickyCta;
