import type { Metadata, Viewport } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { LanguageProvider } from "@/lib/i18n/LanguageProvider";
import { Header } from "@/components/Header";
import { Footer } from "@/components/Footer";
import { DownloadAppBanner } from "@/components/DownloadAppBanner";

const inter = Inter({ subsets: ["latin"], display: "swap" });

export const metadata: Metadata = {
  metadataBase: new URL("https://hopetsit.com"),
  title: {
    default: "HoPetSit — Pet sitters and dog walkers worldwide",
    template: "%s · HoPetSit",
  },
  description:
    "Book trusted pet sitters and dog walkers in 177 countries worldwide — USA included — or earn money taking care of pets you love. One app, three roles, full transparency.",
  applicationName: "HoPetSit",
  authors: [{ name: "CARDELLI HERMANOS LIMITED" }],
  keywords: [
    "pet sitter", "dog walker", "pet sitting USA", "pet sitting worldwide", "dog boarding",
    "pet care marketplace", "HoPetSit", "garde animaux", "promeneur de chien",
  ],
  openGraph: {
    type: "website",
    siteName: "HoPetSit",
    url: "https://hopetsit.com",
    title: "HoPetSit — Pet sitters and dog walkers worldwide",
    description:
      "Trusted marketplace connecting pet owners with sitters and dog walkers in 177 countries worldwide.",
    // v532 — vignette de partage RASTER. Avant : "/logo.svg" — or WhatsApp,
    // Instagram, Facebook et X ne rendent PAS les SVG en og:image : tous les
    // liens partagés depuis l'app sortaient sans aperçu. 1200x630 = format
    // attendu par summary_large_image.
    images: [
      {
        url: "/og-image.png",
        width: 1200,
        height: 630,
        alt: "HoPetSit — pet sitting & dog walking",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "HoPetSit",
    description:
      "Pet sitters and dog walkers worldwide. One app, three roles, full transparency.",
    images: ["/og-image.png"],
  },
  robots: { index: true, follow: true },
  // v402 — Daniel : "sur Google le favicon sort Wix". Google ignore souvent
  // les favicons SVG et préfère un favicon.ico raster. On sert donc d'abord le
  // .ico + des PNG (logo HoPetSit) ; le SVG reste pour les navigateurs modernes.
  // v532 — logo HOPE26. L'entrée favicon.svg est retirée : le nouveau logo est
  // un rendu raster (dégradés + halo), il n'existe pas en SVG fidèle, et les
  // navigateurs qui préfèrent le SVG afficheraient encore l'ANCIEN logo.
  // v534 — nouveau logo (pack HD Daniel) + « ?v=548 » sur chaque entrée :
  // les navigateurs mettent le favicon en cache très agressivement, sans ce
  // paramètre beaucoup d'utilisateurs auraient continué à voir l'ANCIEN logo
  // pendant des semaines. Les fichiers favicon.svg / logo.svg (ancien logo)
  // ont aussi été remplacés par le nouveau visuel dans /public.
  icons: {
    icon: [
      { url: "/favicon.ico?v=548", sizes: "any" },
      { url: "/icon-32.png?v=548", type: "image/png", sizes: "32x32" },
      { url: "/icon-192.png?v=548", type: "image/png", sizes: "192x192" },
      { url: "/icon-512.png?v=548", type: "image/png", sizes: "512x512" },
    ],
    apple: "/apple-touch-icon.png?v=548",
    shortcut: "/favicon.ico?v=548",
  },
};

export const viewport: Viewport = {
  themeColor: "#C92A12",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={inter.className}>
      <body className="min-h-screen bg-white text-ink antialiased">
        {/* v23.1.267 — SEO/AEO : données structurées Organization + WebSite. */}
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{
            __html: JSON.stringify({
              "@context": "https://schema.org",
              "@graph": [
                {
                  "@type": "Organization",
                  "@id": "https://hopetsit.com/#organization",
                  name: "HoPetSit",
                  // v534 — Google corrige « hopetsit » vers un concurrent :
                  // variantes du nom pour renforcer l'entité de marque.
                  alternateName: ["Ho Pet Sit", "HoPetSit App", "hopetsit.com"],
                  legalName: "CARDELLI HERMANOS LIMITED",
                  url: "https://hopetsit.com",
                  logo: "https://hopetsit.com/logo.png",
                  email: "hopetsit@gmail.com",
                  description:
                    "Trusted marketplace connecting pet owners with sitters and dog walkers worldwide.",
                  // v402 — référencement des réseaux sociaux officiels (Google
                  // les associe à la marque via sameAs).
                  sameAs: [
                    "https://www.instagram.com/hopetsit/",
                    "https://www.tiktok.com/@hopetsit",
                    "https://www.youtube.com/@HoPetSit/shorts",
                    "https://www.facebook.com/people/Hopetsit/61590596619482/",
                  ],
                },
                {
                  "@type": "WebSite",
                  "@id": "https://hopetsit.com/#website",
                  url: "https://hopetsit.com",
                  name: "HoPetSit",
                  publisher: { "@id": "https://hopetsit.com/#organization" },
                  inLanguage: ["en", "fr", "es", "de", "it", "pt"],
                },
                // v516 — SEO : l'app Android est LIVE sur Google Play →
                // données structurées MobileApplication pour que Google
                // associe le site et l'app (fiche enrichie + lien
                // d'installation dans les résultats de recherche).
                {
                  "@type": "MobileApplication",
                  "@id": "https://hopetsit.com/#app",
                  name: "HoPetSit",
                  // v518 — approuvée par Apple : dispo Android ET iOS.
                  operatingSystem: "ANDROID, IOS",
                  applicationCategory: "LifestyleApplication",
                  installUrl:
                    "https://play.google.com/store/apps/details?id=com.cardellihermanos.hopetsit",
                  sameAs: [
                    "https://play.google.com/store/apps/details?id=com.cardellihermanos.hopetsit",
                    "https://apps.apple.com/app/hopetsit/id6763645719",
                  ],
                  url: "https://hopetsit.com/download",
                  offers: { "@type": "Offer", price: "0", priceCurrency: "EUR" },
                  publisher: { "@id": "https://hopetsit.com/#organization" },
                  inLanguage: ["en", "fr", "es", "de", "it", "pt"],
                },
              ],
            }),
          }}
        />
        <LanguageProvider>
          <Header />
          {/* v23.1.452 — bannière de téléchargement site-wide (desktop : barre
              fine en flux sous le Header ; mobile : bouton flottant). */}
          <DownloadAppBanner />
          <main>{children}</main>
          <Footer />
        </LanguageProvider>
      </body>
    </html>
  );
}
