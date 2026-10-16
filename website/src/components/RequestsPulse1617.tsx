"use client";

// 1617 (LEO, 16/10/2026, §B.5) — « N propriétaires cherchent un gardien à Paris
// cette semaine » sur la page Paris (/garde-animaux/paris, /petsitter/paris).
// Source : GET /posts/requests/public-stats?city=… (propriétaires RÉELS, demandes
// ouvertes, comptes de test / staff exclus par le serveur). count = 0 → RIEN
// (jamais un chiffre inventé). Lien vers la PawMap publique où les demandes
// apparaissent en bulles floutées. Hooks en tête, zéro gris.

import { useEffect, useState } from "react";
import { TrackedLink } from "@/components/TrackedLink";
import { AppIcon } from "@/components/AppIcon";
import { getPublicRequestStats } from "@/lib/api";
import type { Lang } from "@/lib/i18n/langs";
import { p1617, statsSentence } from "@/lib/i18n/publier1617";

export default function RequestsPulse1617({ city, lang, className = "" }: { city: string; lang: Lang; className?: string }) {
  const [count, setCount] = useState(0);
  const [label, setLabel] = useState(city);

  useEffect(() => {
    let cancelled = false;
    getPublicRequestStats({ city }).then((s) => {
      if (cancelled) return;
      setCount(s.count);
      if (s.city) setLabel(s.city);
    });
    return () => { cancelled = true; };
  }, [city]);

  if (count < 1) return null;
  return (
    <p data-testid="requests-pulse-1617" className={`flex flex-wrap items-center justify-center gap-x-3 gap-y-1 rounded-2xl bg-owner-light px-4 py-2.5 text-center text-sm font-semibold leading-snug text-owner-dark ${className}`}>
      <span className="inline-flex items-center gap-1.5">
        <span aria-hidden="true" className="inline-block h-2.5 w-2.5 rounded-full bg-owner" style={{ animation: "hpsPulse1617 1.8s ease-in-out infinite" }} />
        {statsSentence(lang, count, label)}
      </span>
      <TrackedLink href={`/pawmap?city=${encodeURIComponent(label)}`} label="see_map" className="inline-flex min-h-[32px] items-center gap-1 underline-offset-4 hover:underline">
        {p1617(lang, "stats_map")}<AppIcon name="arrow-right" size={14} />
      </TrackedLink>
      <style dangerouslySetInnerHTML={{ __html: "@keyframes hpsPulse1617{0%,100%{transform:scale(1);opacity:1}50%{transform:scale(1.5);opacity:.55}}" }} />
    </p>
  );
}
