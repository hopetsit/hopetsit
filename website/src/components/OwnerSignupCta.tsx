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
  // v581 — 22/09, dernière étape : le bouton dit « Publier ma demande », il
  // ouvre donc LE FORMULAIRE, tout de suite, sans compte. On y écrit sa
  // demande ; le compte se crée à la fin, quand la personne sait ce qu'elle
  // obtient. (Avant : inscription → code par e-mail → formulaire. Deux tiers
  // des inscrits ne vérifiaient jamais leur e-mail et n'arrivaient jamais
  // jusqu'ici — mesuré le 22/09 : 33 inscriptions, 12 vérifiées, 0 demande.)
  const href = `/posts/create${city ? `?city=${encodeURIComponent(city)}` : ""}`;
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
