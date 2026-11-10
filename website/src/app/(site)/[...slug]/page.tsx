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

import Link from "@/components/SiteLink";
import { useEffect, useMemo, useState } from "react";
// v576 — mesure d'audience : clics vers les stores depuis la page de repli.
import StoreBadges from "@/components/StoreBadges";
import { useT } from "@/lib/i18n/LanguageProvider";
import { l1011 } from "@/lib/i18n/liens1011";
// 1011 (ZOE, ordre de Daniel « les pages ne sont pas à jour dans les autres langues ») — textes en 9 langues.
import { g1011 } from "@/lib/i18n/langues1011";

// v23.1.317 — Daniel (audit) : l'ID App Store était un placeholder (id6740000000)
// → lien cassé 404. L'app iOS n'est pas encore publiée : on pointe vers la page
// /download ("bientôt sur les stores") au lieu d'un lien mort. À remplacer par
// la vraie URL App Store le jour de la publication iOS.
const APP_STORE_URL = "https://apps.apple.com/app/id6763645719";
const PLAY_STORE_URL =
  "https://play.google.com/store/apps/details?id=com.cardellihermanos.hopetsit";

// Map du chemin web → page liste équivalente quand disponible. Permet à
// l'utilisateur desktop de "continuer sur le web" sans atterrir sur une
// page vide.
// `label` = clé de la table en 9 langues (langues1011), affichée par g1011(lang, label).
// 1011 (ZOE point 3) — `direct` : le site sait ouvrir CETTE page précise (une conversation).
// Le visiteur y est conduit tout seul (tout de suite sur ordinateur, après la tentative
// d'ouverture de l'app sur téléphone) au lieu de rester devant les boutons des stores.
function webFallbackFor(path: string): { href: string; label: string; direct?: boolean } | null {
  // Strip trailing slash + query.
  const clean = path.split("?")[0].split("#")[0].replace(/\/$/, "");
  const segments = clean.split("/").filter(Boolean);
  const first = segments[0] ?? "";
  switch (first) {
    case "bookings":
      return { href: "/bookings", label: "slug_lbl_bookings" };
    case "chat":
      if (segments[1] && /^[A-Za-z0-9_-]{6,64}$/.test(segments[1])) {
        return { href: `/chat?c=${encodeURIComponent(segments[1])}`, label: "slug_lbl_conv", direct: true };
      }
      return { href: "/chat", label: "slug_lbl_messages" };
    case "book":
    case "post":
      // /book/:postId ou /post/:postId — fallback vers la home
      return { href: "/", label: "slug_lbl_home" };
    case "wallet":
      return { href: "/dashboard", label: "slug_lbl_dashboard" };
    case "subscription":
      return { href: "/pricing", label: "slug_lbl_subs" };
    case "paw-spot":
    case "map-boost":
      return { href: "/pawmap", label: "slug_lbl_pawmap" };
    case "notifications":
      return { href: "/dashboard", label: "slug_lbl_dashboard" };
    case "walk":
      return { href: "/bookings", label: "slug_lbl_bookings" };
    case "friends":
    case "amis":
      // v23.1.254 — notifs amis / famille / suivi live (friend_request_*,
      // family_*, live_tracking_*). v565 : la page /friends (demandes,
      // liste, famille) existe depuis la v509 → on y renvoie directement.
      return { href: "/friends", label: "slug_lbl_friends" };
    // v23.1.175 — cases manquantes ajoutées (audit web Next.js).
    case "profile":
      return { href: "/profile", label: "slug_lbl_profile" };
    case "pay":
      return { href: "/pay", label: "slug_lbl_pay" };
    case "invite":
      // /invite/family/<email> ou /invite/<code> — flow d'invitation
      return { href: "/signup", label: "slug_lbl_signup" };
    case "auth":
      // /auth/* — flow de bridge session web → app
      return { href: "/login", label: "slug_lbl_login" };
    // v603 (ZOE) — cibles précises des e-mails de notification (même routeur
    // que la cloche et le push du 602). Sans ces cas, la page ne tentait pas
    // d'ouvrir l'app et n'offrait aucun bouton : impasse.
    case "request":
    case "application":
      return { href: "/bookings", label: "slug_lbl_bookings" };
    case "identity":
    case "reviews":
      return { href: "/profile", label: "slug_lbl_profile" };
    case "member":
      return { href: "/friends", label: "slug_lbl_friends" };
    case "shop":
      return { href: "/boutique", label: "slug_lbl_shop" };
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
  const { lang } = useT();
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
    // v575 — ET uniquement sur un chemin que l'app sait ouvrir. Avant, TOUTE
    // URL inconnue (lien de pub mal orthographié, ancienne URL, typo) tentait
    // `hopetsit://<chemin>` : dans le navigateur intégré de Facebook cela
    // produit une alerte ou un écran figé, et si l'app est installée elle
    // s'ouvre sur une route inconnue (= écran de démarrage). Un visiteur perdu
    // à chaque fois.
    const fb = webFallbackFor(path);
    if (detected === "desktop" && fb?.direct) {
      // Ordinateur : pas d'app à ouvrir, on va droit à la conversation sur le site.
      window.location.replace(fb.href);
      return;
    }
    if (detected !== "desktop" && fb) {
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
        // Téléphone sans l'app (la page est toujours à l'écran) : la conversation s'ouvre sur le site.
        if (fb.direct && !document.hidden) window.location.replace(fb.href);
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
        {/* v578 — Daniel : « ça c'est horrible, mets notre vraie icône animée
            (celle de la PawMap de l'app) ». Le carré orange + emoji 🐾 laisse
            la place au vrai logo PawMap, animé (les doigts sortent du
            coussinet au survol / à l'apparition). */}
        <div className="mx-auto mb-6 flex justify-center">
          {/* v580b — Daniel : « je veux le carré orange comme l'icône
              officielle ». On affiche l'icône réelle de l'app, animée par
              une respiration douce (classe hps-app-icon). */}
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src="/logo.png"
            alt="HoPetSit"
            width={84}
            height={84}
            className="hps-app-icon h-[84px] w-[84px]"
          />
        </div>

        <h1 className="text-2xl font-bold text-ink mb-2">
          {g1011(lang, "slug_title")}
        </h1>
        <p className="text-ink-muted text-sm mb-6">
          {g1011(lang, "slug_body")}
          {platform !== "desktop" &&
            " " + g1011(lang, "slug_mobile")}
          {platform === "desktop" &&
            " " + g1011(lang, "slug_desktop")}
        </p>

        {fallback?.direct && (
          <Link
            href={fallback.href}
            data-direct-web-1011=""
            className="mb-3 block w-full rounded-xl bg-[#231715] py-3 font-semibold text-white transition-colors hover:bg-black"
          >
            {l1011(lang, "open_conv")}
          </Link>
        )}

        {platform !== "desktop" && hasTriedOpen && fallback && (
          <button
            type="button"
            onClick={handleOpenApp}
            className="block w-full bg-orange-500 hover:bg-orange-600 text-white font-semibold py-3 rounded-xl mb-3 transition-colors"
          >
            {g1011(lang, "slug_open_btn")}
          </button>
        )}

        {/* v578 — Daniel : « et les vrais designs Google Play et App Store ».
            Les deux pavés « App Store » / « Play Store » en texte brut sont
            remplacés par les VRAIS badges officiels (logos + phrase traduite
            dans les 9 langues), déjà utilisés sur l'accueil. */}
        <div className="mb-4 flex flex-col items-center gap-3">
          <StoreBadges center />
        </div>

        {fallback && !fallback.direct && (
          <Link
            href={fallback.href}
            className="block text-orange-600 hover:text-orange-700 text-sm font-medium underline pt-3 border-t border-ink-line"
          >
            {g1011(lang, fallback.label)}
          </Link>
        )}

        <p className="text-xs text-ink-soft mt-6">
          {g1011(lang, "slug_link_asked")} <code className="font-mono">{path}</code>
        </p>
      </div>
    </main>
  );
}
