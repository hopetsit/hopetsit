"use client";

// v565 (point 29) — route par défaut de `buildAppRoute` (tout type inconnu).
// Le site n'a pas de centre de notifications : le tableau de bord (bandeau
// de notifications en temps réel) est l'équivalent web.

import { AppRoutePage } from "@/components/AppRoutePage";

export default function NotificationsRoutePage() {
  return <AppRoutePage appPath="notifications" webHref="/dashboard" />;
}
