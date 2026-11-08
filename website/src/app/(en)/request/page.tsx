import type { Metadata } from "next";
import DemandeFlow0811 from "@/components/DemandeFlow0811";
import { dm } from "@/lib/i18n/demande0811";

// 08/11/2026 (NEO, ordre de Daniel 16 h 45 transmis par BOB) — META AD LANDING PAGE « New York · owners » (the ad now
// sends to the SITE, no more Meta form). The owner posts AND verifies their email in one go: 1-step form → code received
// by email typed here → request live, session open, app offered.
// URL for SAM: https://www.hopetsit.com/request?city=nyc&utm_source=meta&utm_medium=paid&utm_campaign=nyc_owners
// Ad page, not a Google page (rule of 20/09: no more indexed pages) → noindex.
const TITLE = "Post my pet-sitting request in New York";
const DESCRIPTION = "Sitters near you reply with their price. Post your request in 1 minute, no password.";

export const metadata: Metadata = {
  title: TITLE,
  description: DESCRIPTION,
  robots: { index: false, follow: true },
  alternates: { canonical: "https://www.hopetsit.com/request" },
  openGraph: { title: TITLE, description: DESCRIPTION, url: "https://www.hopetsit.com/request", type: "website", siteName: "HoPetSit", images: [{ url: "https://www.hopetsit.com/og-image.png", width: 1200, height: 630, alt: "HoPetSit" }] },
};

export default function RequestPage() {
  return (
    <main className="min-h-[80vh] bg-[#FFF7F3] px-4 pb-14 pt-6 md:pt-10">
      <div className="mx-auto max-w-3xl">
        <h1 className="text-center font-display text-[26px] font-extrabold leading-tight text-ink md:text-4xl">
          {dm("en", "title", { city: "New York" })}
        </h1>
        <DemandeFlow0811 lang="en" defaultCity="nyc" />
      </div>
    </main>
  );
}
