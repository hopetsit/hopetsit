"use client";

// v565 (point 29) — `/open/<route>` : lien e-mail portant le chemin cible de
// l'app (ex. /open/friends/requests). App installée → lien universel (AASA
// `/open/*`) ; sinon cette page tente `hopetsit://<route>` puis /download.

import { OpenAppRedirect } from "@/components/OpenAppRedirect";

export default function OpenRoutePage({ params }: { params: { rest: string[] } }) {
  const route = (params?.rest ?? []).join("/") || "open";
  return <OpenAppRedirect route={route} />;
}
