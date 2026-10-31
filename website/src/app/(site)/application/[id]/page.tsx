"use client";

// 16/10/2026 — LEO. Cible du lien de l'e-mail / du SMS « candidature reçue » envoyé au
// PROPRIÉTAIRE (`emailLinkBuilder` : /application/:id?from=email|sms).
// 31/10/2026 — LEO (ordre de Daniel « paiement plus simple ») : plus de rebond vers /posts.
// Cette page EST la page unique « mes candidats → payer » (OwnerCandidatesPay3110) : les
// candidats de la demande triés du plus proche au plus loin, un bouton « Choisir <prénom> et
// payer · prix », l'encart carte Airwallex sur place. Sans session : connexion puis retour ICI
// (les contacts de la pub arrivent déjà connectés par /posts/confirmer?l=…&next=…).
// Page privée (noindex via middleware). Hooks en tête, aucun retour anticipé avant.

import { useEffect, useState } from "react";
import { OwnerCandidatesPay3110 } from "@/components/OwnerCandidatesPay3110";

export default function ApplicationRoutePage({ params }: { params: { id: string } }) {
  const id = String(params?.id || "").replace(/[^a-fA-F0-9]/g, "").slice(0, 24);
  // Rendu côté client seulement (session dans localStorage) : évite un écart serveur/client.
  const [ready, setReady] = useState(false);
  useEffect(() => { setReady(true); }, []);
  if (!ready) return <div className="mx-auto max-w-md px-4 py-24" aria-busy="true" />;
  return <OwnerCandidatesPay3110 focusId={id || undefined} />;
}
