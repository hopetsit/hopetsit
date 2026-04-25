import type { Metadata, Viewport } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { LanguageProvider } from "@/lib/i18n/LanguageProvider";
import { Header } from "@/components/Header";
import { Footer } from "@/components/Footer";

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
  authors: [{ name: "HoPetSit Limited" }],
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
  },
  twitter: {
    card: "summary_large_image",
    title: "HoPetSit",
    description:
      "Pet sitters and dog walkers across Europe. One app, three roles, full transparency.",
  },
  robots: { index: true, follow: true },
  icons: { icon: "/favicon.svg" },
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
        <LanguageProvider>
          <Header />
          <main>{children}</main>
          <Footer />
        </LanguageProvider>
      </body>
    </html>
  );
}
