"use client";

// v23.1.170 — Daniel : "tout les boutons des email ne marche pas jai
// essayer de mon mail au web par exemple sa met erreur 404".
//
// Cause racine (audit v170) : 9 chemins sur 13 générés par `buildEmailLink`
// n'avaient PAS de page.tsx correspondante sur le site Next.js. Quand
// l'utilisateur clique le bouton depuis un email sur DESKTOP (pas
// d'interception Universal Link iOS / App Link Android), le browser
// charge directement le site web → 404.
//
// Solution : un catch-all `[...slug]` qui :
//   1. Tente d'ouvrir l'app native via custom scheme `hopetsit://<path>`
//      (fonctionne quand l'app est installée sur le device — sur iOS
//      Safari respecte ce scheme, sur Android le browser également).
//   2. Si après ~1500 ms l'app ne s'est pas ouverte (browser desktop OU
//      mobile sans l'app), affiche une UI fallback qui propose :
//      - "Ouvre dans l'app HoPetSit" (re-tente le custom scheme)
//      - Liens App Store / Play Store
//      - Lien "Continuer sur le web" qui mappe le path vers une page
//        liste équivalente (/bookings/:id → /bookings, /chat/:id → /chat, …)
//   3. Pour les chemins inconnus, fallback générique vers la home.
//
// Cette implémentation évite la prolifération de 8 pages stubs identiques
// (option (b) recommandée par l'audit).

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";

// v23.1.317 — Daniel (audit) : l'ID App Store était un placeholder (id6740000000)
// → lien cassé 404. L'app iOS n'est pas encore publiée : on pointe vers la page
// /download ("bientôt sur les stores") au lieu d'un lien mort. À remplacer par
// la vraie URL App Store le jour de la publication iOS.
const APP_STORE_URL = "/download";
const PLAY_STORE_URL =
  "https://play.google.com/store/apps/details?id=com.hopetsit.app";

// Map du chemin web → page liste équivalente quand disponible. Permet à
// l'utilisateur desktop de "continuer sur le web" sans atterrir sur une
// page vide.
function webFallbackFor(path: string): { href: string; label: string } | null {
  // Strip trailing slash + query.
  const clean = path.split("?")[0].split("#")[0].replace(/\/$/, "");
  const segments = clean.split("/").filter(Boolean);
  const first = segments[0] ?? "";
  switch (first) {
    case "bookings":
      return { href: "/bookings", label: "Voir mes réservations" };
    case "chat":
      return { href: "/chat", label: "Voir mes messages" };
    case "book":
    case "post":
      // /book/:postId ou /post/:postId — fallback vers la home
      return { href: "/", label: "Retour à l'accueil" };
    case "wallet":
      return { href: "/dashboard", label: "Voir mon tableau de bord" };
    case "subscription":
      return { href: "/pricing", label: "Voir les abonnements" };
    case "paw-spot":
    case "map-boost":
      return { href: "/pawmap", label: "Voir la PawMap" };
    case "notifications":
      return { href: "/dashboard", label: "Voir mon tableau de bord" };
    case "walk":
      return { href: "/bookings", label: "Voir mes réservations" };
    case "friends":
    case "amis":
      // v23.1.254 — notifs amis / famille / suivi live (friend_request_*,
      // family_*, live_tracking_*). v23.1 carte unique : le hub web vit
      // désormais sur /map (couche PawFollow de la carte unique).
      return { href: "/map", label: "Voir mes amis" };
    // v23.1.175 — cases manquantes ajoutées (audit web Next.js).
    case "profile":
      return { href: "/profile", label: "Voir mon profil" };
    case "pay":
      return { href: "/pay", label: "Aller au paiement" };
    case "invite":
      // /invite/family/<email> ou /invite/<code> — flow d'invitation
      return { href: "/signup", label: "Créer un compte HoPetSit" };
    case "auth":
      // /auth/* — flow de bridge session web → app
      return { href: "/login", label: "Se connecter" };
    default:
      return null;
  }
}

// Reconstitue l'URL custom-scheme pour l'app native depuis le path Next.js.
// Ex. /bookings/abc?focus=1 → hopetsit://bookings/abc?focus=1
function buildAppDeepLink(path: string, search: string): string {
  const cleanPath = path.startsWith("/") ? path.slice(1) : path;
  return `hopetsit://${cleanPath}${search ?? ""}`;
}

export default function CatchAllPage({
  params,
}: {
  params: { slug: string[] };
}) {
  const path = useMemo(() => "/" + (params?.slug ?? []).join("/"), [
    params?.slug,
  ]);
  const [search, setSearch] = useState<string>("");
  const [hasTriedOpen, setHasTriedOpen] = useState(false);
  const [platform, setPlatform] = useState<"ios" | "android" | "desktop">(
    "desktop",
  );

  const fallback = useMemo(() => webFallbackFor(path), [path]);

  // Détection plateforme + tentative auto d'ouverture de l'app.
  useEffect(() => {
    if (typeof window === "undefined") return;
    const ua = window.navigator.userAgent.toLowerCase();
    let detected: "ios" | "android" | "desktop" = "desktop";
    if (/iphone|ipad|ipod/.test(ua)) detected = "ios";
    else if (/android/.test(ua)) detected = "android";
    setPlatform(detected);
    setSearch(window.location.search ?? "");

    // Tentative auto-open uniquement sur mobile (sur desktop le custom
    // scheme ne sert à rien — l'utilisateur n'a pas l'app installée).
    if (detected !== "desktop") {
      const link = buildAppDeepLink(path, window.location.search ?? "");
      // Iframe trick = pas de popup sur iOS si l'app n'est pas installée
      // (window.location ferait apparaître "page Web non disponible").
      const iframe = document.createElement("iframe");
      iframe.style.display = "none";
      iframe.src = link;
      document.body.appendChild(iframe);
      const timer = setTimeout(() => {
        setHasTriedOpen(true);
        try {
          document.body.removeChild(iframe);
        } catch {
          /* noop */
        }
      }, 1500);
      return () => clearTimeout(timer);
    } else {
      setHasTriedOpen(true);
    }
  }, [path]);

  const handleOpenApp = () => {
    if (typeof window === "undefined") return;
    window.location.href = buildAppDeepLink(
      path,
      window.location.search ?? "",
    );
  };

  return (
    <main className="min-h-screen bg-gradient-to-br from-orange-50 to-white flex items-center justify-center px-4 py-12">
      <div className="max-w-md w-full bg-white rounded-3xl shadow-xl p-8 text-center">
        {/* v23.1.171 — logo.png n'existe pas, on utilise un emoji + bg
            orange pour éviter l'icône cassée. Le logo svg est sur la home. */}
        <div className="mx-auto mb-6 w-20 h-20 rounded-2xl bg-orange-500 flex items-center justify-center text-white text-4xl">
          🐾
        </div>

        <h1 className="text-2xl font-bold text-slate-900 mb-2">
          Ouvre dans l'app HoPetSit
        </h1>
        <p className="text-slate-600 text-sm mb-6">
          Cette page est disponible dans l'application mobile HoPetSit.
          {platform !== "desktop" &&
            " On a essayé d'ouvrir l'app automatiquement ; si rien ne s'est passé, tape sur le bouton ci-dessous."}
          {platform === "desktop" &&
            " Télécharge l'app pour continuer, ou poursuis ta navigation sur le web."}
        </p>

        {platform !== "desktop" && hasTriedOpen && (
          <button
            type="button"
            onClick={handleOpenApp}
            className="block w-full bg-orange-500 hover:bg-orange-600 text-white font-semibold py-3 rounded-xl mb-3 transition-colors"
          >
            Ouvrir dans HoPetSit
          </button>
        )}

        <div className="grid grid-cols-2 gap-3 mb-4">
          <a
            href={APP_STORE_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="bg-slate-900 text-white text-sm font-medium py-3 rounded-xl hover:bg-slate-800 transition-colors"
          >
            App Store
          </a>
          <a
            href={PLAY_STORE_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="bg-slate-900 text-white text-sm font-medium py-3 rounded-xl hover:bg-slate-800 transition-colors"
          >
            Play Store
          </a>
        </div>

        {fallback && (
          <Link
            href={fallback.href}
            className="block text-orange-600 hover:text-orange-700 text-sm font-medium underline pt-3 border-t border-slate-100"
          >
            {fallback.label}
          </Link>
        )}

        <p className="text-xs text-slate-400 mt-6">
          Lien demandé : <code className="font-mono">{path}</code>
        </p>
      </div>
    </main>
  );
}
