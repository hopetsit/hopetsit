"use client";

// v565 (point 29) — route « thème » `subscription_*` (e-mails/push). Sur le
// web : la boutique (session requise) — le login renvoie ensuite dessus.

import { AppRoutePage } from "@/components/AppRoutePage";

export default function SubscriptionRoutePage() {
  return <AppRoutePage appPath="subscription" webHref="/boutique" />;
}
