import { NextResponse, type NextRequest } from "next/server";

// v562 — Search Console (17/09) : « Page en double sans URL canonique » (20) et
// « Détectée, non indexée » (320). Cause n°1 : les QR des affiches partenaires
// (/download?ref=<commerce>) et les liens ?utm/?lang créent une URL par
// variante sans balise canonique. On envoie à Google l'URL canonique (sans
// paramètres, hôte www) dans l'en-tête HTTP Link, pour TOUTES les pages, y
// compris les pages « use client » qui ne peuvent pas exporter de metadata.
// Les espaces privés / techniques reçoivent X-Robots-Tag: noindex (ils ne
// doivent pas consommer le budget d'exploration ni apparaître dans Google).
const NOINDEX = [
  "/login", "/signup", "/verify-email", "/open", "/pay", "/kyc-complete",
  "/search", "/map", "/boutique", "/posts", "/pawpoints", "/family", "/book",
  "/dashboard", "/chat", "/bookings", "/invoices", "/profile", "/pets",
  "/walk", "/friends", "/sitter-setup", "/delete-account",
];

export function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;
  const res = NextResponse.next();
  const path = pathname !== "/" && pathname.endsWith("/") ? pathname.slice(0, -1) : pathname;
  res.headers.set("Link", `<https://www.hopetsit.com${path === "/" ? "/" : path}>; rel="canonical"`);
  if (NOINDEX.some((p) => path === p || path.startsWith(p + "/"))) {
    res.headers.set("X-Robots-Tag", "noindex, follow");
  }
  return res;
}

export const config = {
  // Pages seulement : ni API, ni fichiers statiques (images, PDF des affiches, sitemap…).
  matcher: ["/((?!api/|_next/|.*\\.[a-zA-Z0-9]+$).*)"],
};
