"use client";

// v565 (point 29) — route « thème » `referral_credited`, `map_boost_*`,
// `profile_boost_activated` → boutique PawSpot / boosts sur le web.

import { AppRoutePage } from "@/components/AppRoutePage";

export default function PawSpotRoutePage() {
  return <AppRoutePage appPath="paw-spot" webHref="/boutique" />;
}
