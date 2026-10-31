"use client";

// 31/10/2026 (LEO, décision BOB point 2) — enveloppe du bloc de preuve des pages villes : il s'efface quand le
// premier écran (CityFirstScreen3110) affiche « Devenir gardien », pour ne plus annoncer « N gardiens à moins de
// 100 km » sous « il manque des gardiens actifs ». Même source de vérité : le mode publié par le premier écran.
import { useSyncExternalStore } from "react";
import { getCityFirstScreenMode, getCityFirstScreenModeServer, subscribeCityFirstScreen } from "@/lib/cityFirstScreenStore3110";

export function CitySupplyProofGate3110({ children }: { children: React.ReactNode }) {
  const mode = useSyncExternalStore(subscribeCityFirstScreen, getCityFirstScreenMode, getCityFirstScreenModeServer);
  if (mode === "recruit") return null;
  return <>{children}</>;
}

export default CitySupplyProofGate3110;
