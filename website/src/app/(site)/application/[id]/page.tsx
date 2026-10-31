"use client";

// 16/10/2026 — LEO. Cible du lien de l'e-mail / du SMS « candidature reçue » envoyé au
// PROPRIÉTAIRE (`emailLinkBuilder` : /application/:id?from=email|sms).
// 31/10/2026 — LEO (ordre de Daniel « paiement plus simple ») : plus de rebond vers /posts.
// Cette page EST la page unique « mes candidats → payer » (OwnerCandidatesPay3110) : les
// candidats de la demande triés du plus proche au plus loin, un bouton « Choisir <prénom> et
// payer · prix », l'encart carte Airwallex sur place.
// 31/10 (feu vert BOB 13 h 15) — SANS MOT DE PASSE POUR TOUS : le lien de l'e-mail porte un jeton
// signé `?k=` (serveur, utils/applicationLink3110) ; ici on l'échange contre une session
// (POST /auth/application-link) avant d'afficher, puis on retire `k` de l'adresse. Jeton périmé
// ou demande close → parcours normal (connexion puis retour ici). Les contacts de la pub arrivent
// déjà connectés par /posts/confirmer?l=…&next=… (inchangé).
// Page privée (noindex via middleware). Hooks en tête, aucun retour anticipé avant.

import { useEffect, useState } from "react";
import { OwnerCandidatesPay3110 } from "@/components/OwnerCandidatesPay3110";
import { exchangeApplicationLink, getStoredUser } from "@/lib/api";
import { trackSiteEvent } from "@/components/SiteAnalytics";

export default function ApplicationRoutePage({ params }: { params: { id: string } }) {
  const id = String(params?.id || "").replace(/[^a-fA-F0-9]/g, "").slice(0, 24);
  // Rendu côté client seulement (session dans localStorage) : évite un écart serveur/client.
  const [ready, setReady] = useState(false);
  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const q = new URLSearchParams(window.location.search);
        const k = q.get("k") || "";
        const u = getStoredUser();
        if (k && id && (!u || u.role !== "owner")) {
          try {
            await exchangeApplicationLink(k, id);
            trackSiteEvent("cta_click", { label: "cand_lien_ok" });
          } catch {
            trackSiteEvent("cta_click", { label: "cand_lien_ko" });
          }
        }
        if (k) {
          // Le jeton ne reste pas dans l'adresse (historique, partage, mesure).
          q.delete("k");
          const qs = q.toString();
          window.history.replaceState(null, "", `${window.location.pathname}${qs ? `?${qs}` : ""}`);
        }
      } catch { /* adresse exotique : on affiche quand même */ }
      if (alive) setReady(true);
    })();
    return () => { alive = false; };
  }, [id]);
  if (!ready) return <div className="mx-auto max-w-md px-4 py-24" aria-busy="true" />;
  return <OwnerCandidatesPay3110 focusId={id || undefined} />;
}
