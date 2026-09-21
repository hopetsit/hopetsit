"use client";

import Link from "next/link";
import { trackSiteEvent } from "@/components/SiteAnalytics";

// v577 — 21/09, correction de l'étape qui fuit le plus.
// Mesure du 21/09 : /garde-animaux/paris a reçu 28 visiteurs (toute la pub Meta
// « Paris · Propriétaires ») et 0 clic vers le store, alors que le même
// compteur enregistre bien des clics sur /download. Le bouton « Publier ma
// demande » envoyait sur l'App Store : entre la promesse (un formulaire) et le
// premier écran utile, le visiteur devait installer 60 Mo, créer un compte et
// vérifier son e-mail. Personne ne franchit ça au premier contact.
//
// Le site sait pourtant tout faire depuis la v402 : /signup (rôle owner par
// défaut) puis /posts/create (POST /posts, propriétaire connecté, aucun animal
// requis). Le bouton principal mène donc maintenant au parcours WEB, et le
// store devient le choix secondaire, juste en dessous.
//
// Chiffre à regarder demain : ctaClicks sur /garde-animaux/paris (0 aujourd'hui)
// et les propriétaires inscrits en 24 h (0 aujourd'hui).
export function OwnerSignupCta({
  label,
  city,
  className = "",
}: {
  label: string;
  city?: string;
  className?: string;
}) {
  const href = `/signup?role=owner${city ? `&city=${encodeURIComponent(city)}` : ""}`;
  return (
    <Link
      href={href}
      className={className}
      onClick={() => trackSiteEvent("cta_click", { label: "signup_web" })}
    >
      {label}
    </Link>
  );
}

export default OwnerSignupCta;
