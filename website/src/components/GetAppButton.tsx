"use client";

import { useEffect, useState } from "react";

// v575 — bouton principal du premier écran des pages villes (pub Meta).
// Un seul tap, pas de page intermédiaire : on envoie directement sur le store
// de l'appareil. Tant que le JS n'a pas tourné (et sur desktop), le lien pointe
// sur /download qui montre les deux badges → aucun lien mort, aucun saut de
// mise en page (le href change, pas le rendu).
const PLAY_URL =
  "https://play.google.com/store/apps/details?id=com.cardellihermanos.hopetsit";
const APP_STORE_URL = "https://apps.apple.com/app/hopetsit/id6763645719";

export function GetAppButton({
  label,
  className = "",
}: {
  label: string;
  className?: string;
}) {
  const [href, setHref] = useState("/download");

  useEffect(() => {
    if (typeof navigator === "undefined") return;
    const ua = navigator.userAgent || "";
    const iOS =
      /iPhone|iPad|iPod/i.test(ua) ||
      // iPadOS 13+ se déclare « Macintosh » : on le reconnaît au tactile.
      (/Macintosh/.test(ua) && typeof document !== "undefined" && "ontouchend" in document);
    if (iOS) setHref(APP_STORE_URL);
    else if (/Android/i.test(ua)) setHref(PLAY_URL);
  }, []);

  return (
    <a href={href} className={className}>
      {label}
    </a>
  );
}

export default GetAppButton;
