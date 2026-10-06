"use client";

import { useEffect, useState, type ReactNode } from "react";

// 06/10/2026 (GUS) — bandeau daté : il disparaît tout seul après `until`
// (ISO), même si la page statique n'a pas été reconstruite depuis. Côté
// serveur, la page ne le rend plus du tout dès le premier build après la date.
// Hooks en tête, aucun retour anticipé avant eux (piège des hooks du 22/09).
export function ExpiringNotice({ until, children }: { until: string; children: ReactNode }) {
  const [expired, setExpired] = useState(false);
  useEffect(() => {
    setExpired(Date.now() > Date.parse(until));
  }, [until]);
  if (expired) return null;
  return <>{children}</>;
}

export default ExpiringNotice;
