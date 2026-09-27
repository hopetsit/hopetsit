// 27/09/2026 — LEO : layout racine des pages GÉNÉRIQUES (accueil, carte,
// connexion, tableau de bord, tarifs…). Décision de Daniel : servies en
// FRANÇAIS ; un visiteur dont le navigateur est dans une autre langue du site
// la retrouve dès le chargement (voir LanguageProvider). Squelette commun :
// components/RootShell.tsx.
import type { Metadata } from "next";
import { RootShell, rootMetadata, rootViewport } from "@/components/RootShell";
import { t as bundles } from "@/lib/i18n/translations";

const fr = bundles.fr;
const TITLE = `HoPetSit — ${fr.page_title_home}`;
const DESCRIPTION = fr.page_desc_home;

export const metadata: Metadata = {
  ...rootMetadata,
  title: { default: TITLE, template: "%s · HoPetSit" },
  description: DESCRIPTION,
  openGraph: { ...rootMetadata.openGraph, title: TITLE, description: DESCRIPTION, locale: "fr_FR" },
  twitter: { ...rootMetadata.twitter, description: DESCRIPTION },
};
export const viewport = rootViewport;

export default function Layout({ children }: { children: React.ReactNode }) {
  return (
    <RootShell lang="fr">
      {children}
    </RootShell>
  );
}
