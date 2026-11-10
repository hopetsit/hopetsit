"use client";

// 1011 (ZOE, ordre de Daniel « les pages ne sont pas à jour dans les autres langues »).
// Petit texte traduit pour les pages SERVEUR (aperçus de partage /alert, /spot, /blog) :
// la page reste un composant serveur (métadonnées Open Graph), seul le libellé suit la
// langue choisie par le visiteur. Au premier rendu : français, comme avant.
import type { ReactNode } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import { g1011 } from "@/lib/i18n/langues1011";

export default function Tx1011({
  k,
  vars,
}: {
  k: string;
  vars?: Record<string, string | number>;
}) {
  const { lang } = useT();
  return <>{g1011(lang, k, vars)}</>;
}

// Même chose pour une info-bulle : <span title="…">.
export function TxTitle1011({ k, children }: { k: string; children: ReactNode }) {
  const { lang } = useT();
  return <span title={g1011(lang, k)}>{children}</span>;
}
