import type { Metadata } from "next";
import { CityPage } from "../_cityPage";

export const metadata: Metadata = {
  title: "Pet sitter in Dallas, TX — dog walking & pet care | HoPetSit",
  description:
    "Find a verified pet sitter or dog walker in Dallas. Real reviews, secure in-app payment and live GPS tracking of every walk. Free on HoPetSit.",
  alternates: { canonical: "https://www.hopetsit.com/petsitter/dallas" },
};

export default function DallasPage() {
  return (
    <CityPage
      c={{
        city: "Dallas",
        lang: "en",
        h1: "Pet sitter in Dallas: dog & cat care, walks and more",
        intro:
          "Between work, weekends and travel, you can't always be there for your pet. HoPetSit connects you with verified pet sitters and dog walkers across Dallas — from Uptown to Oak Cliff — for care you can actually trust.",
        servicesTitle: "Services near you",
        services: [
          {
            icon: "🏠",
            t: "Pet sitting",
            p: "Your pet stays in familiar surroundings, or with a passionate sitter in your neighborhood.",
          },
          {
            icon: "🚶",
            t: "Dog walking",
            p: "A walk at Klyde Warren Park or White Rock Lake while you're at work — tracked live on GPS.",
          },
          {
            icon: "🔑",
            t: "Drop-in visits",
            p: "Food, litter, cuddles and meds for cats who'd rather stay home.",
          },
        ],
        whyTitle: "Why Dallas pet parents choose HoPetSit",
        why: [
          "ID-verified profiles with reviews from real, completed bookings.",
          "PawFollow live GPS: watch your dog's walk in real time on the map.",
          "Secure in-app payment, released only after you confirm the service.",
          "PawMap: Dallas' pet-friendly parks, patios and vets, shared by the community.",
          "A free app, available in English, Spanish and 4 more languages.",
        ],
        faqTitle: "Dallas FAQ",
        faq: [
          {
            q: "How much does a pet sitter cost in Dallas?",
            a: "Expect $20-$40 per day for pet sitting in Dallas and $15-$25 for a dog walk. Every sitter sets their own rate on their profile.",
          },
          {
            q: "How do I know a sitter is trustworthy?",
            a: "HoPetSit profiles show identity verification and reviews that can only be left after real bookings. You can chat before you confirm anything.",
          },
          {
            q: "Can I track my dog's walk?",
            a: "Yes — with PawFollow, the walker's position shows live on the map for the whole walk.",
          },
        ],
        ctaTitle: "Find your Dallas pet sitter",
        ctaBody:
          "Download HoPetSit for free, compare sitters near you and book in minutes.",
        ctaButton: "Download the HoPetSit app",
      }}
    />
  );
}
