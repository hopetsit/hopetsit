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
  "/login", "/signup", "/forgot-password", "/verify-email", "/open", "/pay", "/kyc-complete",
  "/search", "/map", "/boutique", "/posts", "/pawpoints", "/family", "/book",
  "/dashboard", "/chat", "/bookings", "/invoices", "/profile", "/pets",
  // 16/10/2026 (LEO) — /application/<id> : lien e-mail « candidature reçue » du propriétaire (privé).
  "/application",
  // 22/09/2026 — /p/<role>/<id> : lien de profil qu'un prestataire partage
  // lui-même. Utile et public, mais ce n'est PAS un annuaire : on ne le fait
  // pas indexer par Google.
  "/p/",
  "/walk", "/friends", "/sitter-setup", "/delete-account",
  // v565 — pages « thème » des e-mails/push (ouvrent l'app ou renvoient
  // vers l'équivalent web) : privées, jamais à indexer.
  "/notifications", "/wallet", "/subscription", "/paw-spot", "/post", "/report",
];

// 11/10/2026 (BOB) — Vercel gratuit : 100 % des lectures ISR consommées (1 M en 30 j), pause du
// site annoncée. Observability : des centaines de pages villes différentes lues en 12 h = robots
// (SEO payants, IA, scrapers), pas des visiteurs. Ils sont refusés ICI, avant le cache ISR, donc
// sans lecture facturée. Google, Bing, Apple, DuckDuckGo, Facebook/WhatsApp/Twitter/LinkedIn
// (aperçus de liens) restent autorisés : ce sont les seuls qui apportent des visiteurs.
const BLOCKED_BOTS = /AhrefsBot|SemrushBot|MJ12bot|DotBot|PetalBot|Bytespider|GPTBot|ClaudeBot|anthropic-ai|CCBot|Amazonbot|DataForSeoBot|BLEXBot|MegaIndex|SeznamBot|serpstatbot|ZoominfoBot|Barkrowler|ImagesiftBot|Diffbot|omgili|meta-externalagent|Applebot-Extended|Google-Extended|PerplexityBot|YouBot|OAI-SearchBot|cohere-ai|TimpiBot|SiteAuditBot|AwarioBot|DuckAssistBot|Scrapy|python-requests|Go-http-client|curl\/|wget\//i;

export function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;
  const ua = req.headers.get("user-agent") || "";
  if (BLOCKED_BOTS.test(ua)) {
    return new NextResponse("Forbidden", { status: 403, headers: { "Cache-Control": "no-store", "X-Robots-Tag": "noindex" } });
  }
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
  // v565 — `/.well-known/*` exclu EXPLICITEMENT : `apple-app-site-association`
  // n'a pas d'extension, il passait donc dans le middleware et recevait un
  // en-tête Link canonical. Apple veut ce fichier servi tel quel (JSON pur,
  // sans redirection) → on ne le touche plus.
  matcher: ["/((?!api/|_next/|\\.well-known/|.*\\.[a-zA-Z0-9]+$).*)"],
};
