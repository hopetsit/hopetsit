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
    default: "HoPetSit — Pet sitters and dog walkers across Europe",
    template: "%s · HoPetSit",
  },
  description:
    "Book trusted pet sitters and dog walkers in 29 European countries, or earn money taking care of pets you love. One app, three roles, full transparency.",
  applicationName: "HoPetSit",
  authors: [{ name: "CARDELLI HERMANOS LIMITED" }],
  keywords: [
    "pet sitter", "dog walker", "pet sitting Europe", "dog boarding",
    "pet care marketplace", "HoPetSit", "garde animaux", "promeneur de chien",
  ],
  openGraph: {
    type: "website",
    siteName: "HoPetSit",
    url: "https://hopetsit.com",
    title: "HoPetSit — Pet sitters and dog walkers across Europe",
    description:
      "Trusted marketplace connecting pet owners with sitters and dog walkers in 29 European countries.",
    images: [
      {
        url: "/logo.svg",
        width: 1024,
        height: 1024,
        alt: "HoPetSit",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "HoPetSit",
    description:
      "Pet sitters and dog walkers across Europe. One app, three roles, full transparency.",
    images: ["/logo.svg"],
  },
  robots: { index: true, follow: true },
  // v402 — Daniel : "sur Google le favicon sort Wix". Google ignore souvent
  // les favicons SVG et préfère un favicon.ico raster. On sert donc d'abord le
  // .ico + des PNG (logo HoPetSit) ; le SVG reste pour les navigateurs modernes.
  icons: {
    icon: [
      { url: "/favicon.ico", sizes: "any" },
      { url: "/icon-32.png", type: "image/png", sizes: "32x32" },
      { url: "/icon-192.png", type: "image/png", sizes: "192x192" },
      { url: "/favicon.svg", type: "image/svg+xml" },
    ],
    apple: "/apple-touch-icon.png",
    shortcut: "/favicon.ico",
  },
};

export const viewport: Viewport = {
  themeColor: "#EF4324",
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
                  legalName: "CARDELLI HERMANOS LIMITED",
                  url: "https://hopetsit.com",
                  logo: "https://hopetsit.com/logo.svg",
                  email: "hopetsit@gmail.com",
                  description:
                    "Trusted marketplace connecting pet owners with sitters and dog walkers across Europe.",
                  // v402 — référencement des réseaux sociaux officiels (Google
                  // les associe à la marque via sameAs).
                  sameAs: [
                    "https://www.instagram.com/hopetsit/",
                    "https://www.tiktok.com/@hopetsit",
                    "https://www.youtube.com/@HoPetSit",
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
