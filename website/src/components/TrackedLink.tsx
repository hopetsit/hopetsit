"use client";

import Link from "next/link";
import type { ReactNode } from "react";
import { trackSiteEvent } from "@/components/SiteAnalytics";

// 26/09/2026 (SAM) — un lien interne qui compte son clic (cta_click + libellé).
// Les pages villes sont des composants serveur : elles ne peuvent pas poser un
// onClick elles-mêmes. Sans ce composant, le lien « voir la carte » du premier
// écran de /garde-animaux/paris n'était compté nulle part (10 visiteurs sur
// /map le 26/09, origine inconnue).
export function TrackedLink({
  href,
  label,
  className,
  children,
}: {
  href: string;
  label: string;
  className?: string;
  children: ReactNode;
}) {
  return (
    <Link href={href} className={className} onClick={() => trackSiteEvent("cta_click", { label })}>
      {children}
    </Link>
  );
}

export default TrackedLink;
