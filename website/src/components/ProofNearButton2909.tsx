"use client";
// 29/09/2026 (NEO, mission BOB) — PREUVE SOCIALE À CÔTÉ DU BOUTON « PUBLIER ».
//
// Mesure du 29/09 : 20 vrais propriétaires, 0 demande depuis toujours ; sur le
// site, 4 visiteurs ont ouvert le formulaire en 30 jours, 1 a publié (test).
// Au moment de cliquer, personne ne dit au visiteur QUI va lire sa demande.
// Ce composant lit le VRAI nombre de gardiens et promeneurs de la ville tapée
// (route publique /supply/city, nombres seulement, comptes de test exclus)
// et l'écrit sous le bouton. 0 prestataire ou erreur → rien (jamais un chiffre
// inventé, règle « ne jamais supposer »).
import { useEffect, useState } from "react";
import { API_BASE } from "@/lib/api";
import type { Lang } from "@/lib/i18n/langs";
import { pr } from "@/lib/i18n/proof2909";

type Props = { city: string; lang: Lang };

export default function ProofNearButton2909({ city, lang }: Props) {
  const [n, setN] = useState<{ city: string; total: number } | null>(null);
  const clean = city.trim();

  useEffect(() => {
    // Trop court, ou une adresse e-mail collée dans le champ ville : rien.
    if (clean.length < 2 || clean.includes("@")) {
      setN(null);
      return;
    }
    const ctrl = new AbortController();
    const timer = window.setTimeout(() => {
      fetch(`${API_BASE}/supply/city?city=${encodeURIComponent(clean)}`, { signal: ctrl.signal })
        .then((r) => (r.ok ? r.json() : null))
        .then((d: { total?: number } | null) => {
          const total = d && typeof d.total === "number" ? d.total : 0;
          setN(total > 0 ? { city: clean, total } : null);
        })
        .catch(() => { /* hors ligne ou annulé : pas de ligne */ });
    }, 600);
    return () => {
      window.clearTimeout(timer);
      ctrl.abort();
    };
  }, [clean]);

  if (!n || n.city !== clean) return null;
  const txt = pr(lang, n.total > 1 ? "proof_many" : "proof_one")
    .replace("{n}", String(n.total))
    .replace("{city}", n.city);
  return (
    <p data-testid="proof2909" className="flex items-start justify-center gap-2 text-center text-sm font-semibold text-owner-dark">
      <span aria-hidden className="mt-0.5 inline-block h-2.5 w-2.5 shrink-0 rounded-full bg-owner" />
      <span>{txt}</span>
    </p>
  );
}
