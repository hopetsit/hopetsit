// 11/10/2026 (BOB) — Vercel : le forfait gratuit a atteint 100 % des « ISR Reads »
// (1 000 000 unités de 8 Ko lues en 30 jours, ~100 000 par jour depuis le 1er octobre).
// Cause mesurée (Observability) : des centaines de pages villes lues par des robots, plus
// le PRÉCHARGEMENT automatique de next/link (chaque lien visible dans l'écran déclenche
// une lecture de la page cible, même si personne ne clique : une page ville avec 40 liens
// coûte 40 lectures de ~150 Ko). Ce composant remplace next/link partout, avec
// prefetch désactivé par défaut ; un lien qui doit vraiment précharger passe prefetch={true}.
import NextLink from "next/link";
import type { ComponentProps } from "react";
import { forwardRef } from "react";

type Props = ComponentProps<typeof NextLink>;

const SiteLink = forwardRef<HTMLAnchorElement, Props>(function SiteLink(props, ref) {
  const { prefetch, ...rest } = props;
  return <NextLink ref={ref} prefetch={prefetch === true ? true : false} {...rest} />;
});

export default SiteLink;
