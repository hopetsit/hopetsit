"use client";

import { OpenAppRedirect } from "@/components/OpenAppRedirect";

// v449 — Lien canonique des emails HoPetSit. Daniel : « tous les boutons des
// emails : ouvrir l'app si installée, sinon rediriger vers /download. Jamais
// une page vide ou ancienne. Logique simple et fiable. »
//
// Comment ça marche :
//   - App INSTALLÉE → l'OS intercepte l'App Link (Android, autoVerify) /
//     Universal Link (iOS, applinks:hopetsit.com) AVANT que cette page se
//     charge → l'application s'ouvre directement. Cette page ne s'affiche
//     même pas.
//   - App NON installée (ou App Link non vérifié) → le navigateur charge
//     cette page. On tente une dernière ouverture via le schéma custom
//     `hopetsit://open`, puis on bascule automatiquement sur /download.
//
// Couvre iPhone, Android, navigateur desktop et PWA : dans tous les cas on
// finit soit dans l'app, soit sur /download — jamais une page morte.

export default function OpenAppPage() {
  // v565 — la logique vit dans OpenAppRedirect (partagée avec /open/<route>).
  return <OpenAppRedirect route="open" />;
}
