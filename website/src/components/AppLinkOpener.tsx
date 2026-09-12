"use client";

import { useEffect } from "react";
import { usePathname } from "next/navigation";

// v561 — Daniel : « quand je clique sur le bouton du mail ça me renvoie
// d'abord sur le site ». Les liens des mails sont des liens universels : quand
// l'app est installée, iOS/Android l'ouvrent directement. Quand ça n'a pas eu
// lieu (navigateur choisi « ouvrir dans Safari », client mail qui ouvre une
// vue web…), la page web se charge : on tente alors UNE fois d'ouvrir l'app
// sur le MÊME chemin via le schéma `hopetsit://` (iframe invisible = aucune
// erreur affichée si l'app est absente), uniquement :
//   - sur mobile,
//   - quand on arrive de l'extérieur (pas de navigation interne au site),
//   - sur les chemins que l'app sait ouvrir.
// Sans l'app, rien ne se passe et la page web reste affichée.
const APP_PATHS = [
  "friends",
  "bookings",
  "chat",
  "map",
  "pawmap",
  "profile",
  "posts",
  "post",
  "book",
  "walk",
  "wallet",
  "pay",
  "notifications",
  "subscription",
  "paw-spot",
  "pawspot",
  "shop",
  "alert",
  "spot",
];

export function AppLinkOpener() {
  const pathname = usePathname();

  useEffect(() => {
    if (typeof window === "undefined" || !pathname) return;
    const ua = window.navigator.userAgent.toLowerCase();
    const mobile = /iphone|ipad|ipod|android/.test(ua);
    if (!mobile) return;
    const first = pathname.split("/").filter(Boolean)[0] ?? "";
    if (!APP_PATHS.includes(first)) return;
    // Navigation interne (l'utilisateur se balade sur le site) → on ne
    // l'arrache pas vers l'app.
    const ref = document.referrer || "";
    if (ref && /hopetsit\.com/i.test(ref)) return;
    const key = `hopetsit_applink_${pathname}`;
    try {
      if (window.sessionStorage.getItem(key)) return;
      window.sessionStorage.setItem(key, "1");
    } catch {
      /* stockage indisponible : on tente quand même une fois */
    }
    const link = `hopetsit://${pathname.replace(/^\/+/, "")}${window.location.search ?? ""}`;
    const iframe = document.createElement("iframe");
    iframe.style.display = "none";
    iframe.src = link;
    document.body.appendChild(iframe);
    const timer = window.setTimeout(() => {
      try {
        document.body.removeChild(iframe);
      } catch {
        /* noop */
      }
    }, 1500);
    return () => window.clearTimeout(timer);
  }, [pathname]);

  return null;
}
