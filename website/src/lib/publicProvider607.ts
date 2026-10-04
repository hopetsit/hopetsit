// 02/10/2026 (607, LEO) — page publique /s/<slug> : lecture de la route de NEO
// (CONTRAT_607_lien_perso.md) et petites fonctions pures partagées entre la
// page serveur (métadonnées, JSON-LD) et l'affichage client.
import type { ProviderRateSource } from "@/lib/providerRates";

export type PublicRate = { unit: "hour" | "day" | "week" | "month" | "walk"; durationMinutes?: number; amount: number; currency?: string };
export type PublicReview = { rating: number; comment: string; reviewerName: string; createdAt: string | null };
export type PublicProvider607 = {
  slug: string;
  url: string;
  role: "sitter" | "walker";
  id: string;
  profilePath: string;
  name: string;
  firstName: string;
  photo: string;
  city: string;
  bio: string;
  services: string[];
  acceptedPetTypes: string[];
  rates: PublicRate[];
  rating: number;
  reviewsCount: number;
  reviews: PublicReview[];
  verified: boolean;
  isPioneer: boolean;
  indexable: boolean;
  /** 611 — rang (Chiot → Légende), seulement si le serveur l'envoie. */
  rank?: unknown;
};

// Même base que lib/api.ts (non importé : ce fichier sert aussi au serveur).
const API_BASE = process.env.NEXT_PUBLIC_API_BASE ?? "https://hopetsit-backend.onrender.com/api/v1";
export const PUBLIC_API_BASE = API_BASE;
export const SITE_URL = "https://www.hopetsit.com";
export const SLUG_RE = /^[a-z0-9](?:[a-z0-9-]{0,70}[a-z0-9])?$/;

/** null = 404 (inconnu, masqué) ; lève une erreur si le serveur ne répond pas. */
export async function fetchPublicProvider(slug: string): Promise<PublicProvider607 | null> {
  if (!SLUG_RE.test(slug)) return null;
  const r = await fetch(`${API_BASE}/public/providers/${encodeURIComponent(slug)}`, { next: { revalidate: 300 } });
  if (r.status === 404) return null;
  if (!r.ok) throw new Error(`public/providers ${r.status}`);
  const d = (await r.json()) as { provider?: PublicProvider607 };
  const p = d.provider;
  if (!p || !p.slug || (p.role !== "sitter" && p.role !== "walker")) return null;
  // 02/10 — garde-fou vie privée : une « ville » qui contient une adresse
  // e-mail (vu en prod : l'e-mail saisi dans le champ ville) n'est jamais
  // affichée, et la page n'est pas indexée.
  const looksPrivate = (v: string) => /@|\b[\w.-]+\.(com|fr|net|org)\b/i.test(v || "");
  const privateCity = looksPrivate(p.city) || /gmail|hotmail|yahoo|outlook/i.test(p.slug);
  return {
    ...p,
    city: privateCity ? "" : p.city,
    indexable: p.indexable && !privateCity,
    services: Array.isArray(p.services) ? p.services : [],
    acceptedPetTypes: Array.isArray(p.acceptedPetTypes) ? p.acceptedPetTypes : [],
    rates: Array.isArray(p.rates) ? p.rates : [],
    reviews: Array.isArray(p.reviews) ? p.reviews : [],
  };
}

/** Tarifs du contrat → forme des fiches existantes (providerRates.ts). */
export function rateSourceOf(p: PublicProvider607): ProviderRateSource {
  const cur = p.rates.find((r) => r.currency)?.currency || "EUR";
  const src: ProviderRateSource = { currency: cur };
  if (p.role === "walker") {
    src.walkRates = p.rates.filter((r) => r.unit === "walk").map((r) => ({ durationMinutes: r.durationMinutes, basePrice: r.amount, currency: r.currency || cur, enabled: true }));
  } else {
    for (const r of p.rates) {
      if (r.unit === "hour") src.hourlyRate = r.amount;
      else if (r.unit === "day") src.dailyRate = r.amount;
      else if (r.unit === "week") src.weeklyRate = r.amount;
      else if (r.unit === "month") src.monthlyRate = r.amount;
    }
  }
  return src;
}

/** Codes de service de l'app → clé de libellé (svc607_*), inconnus ignorés. */
const SVC_ALIAS: Record<string, string> = {
  sit_home: "sit_home", boarding: "sit_home",
  sit_owner: "sit_owner", house_sitting: "sit_owner", pet_sitting: "sit_owner",
  daycare: "daycare", day_care: "daycare",
  meds: "meds", vet_transport: "vet_transport",
  dog_walking: "walk", walk: "walk", visit: "visit", home_visit: "visit",
};
export function serviceKeys(codes: string[]): string[] {
  const out: string[] = [];
  for (const c of codes) {
    const k = SVC_ALIAS[String(c || "").trim().toLowerCase().replace(/[\s-]+/g, "_")];
    if (k && !out.includes(`svc607_${k}`)) out.push(`svc607_${k}`);
  }
  return out;
}
const PETS = new Set(["dog", "cat", "nac", "rodent", "bird", "reptile"]);
export function petKeys(codes: string[]): string[] {
  const out: string[] = [];
  for (const c of codes) {
    const k = String(c || "").trim().toLowerCase();
    if (PETS.has(k) && !out.includes(`pet607_${k}`)) out.push(`pet607_${k}`);
  }
  return out;
}

export const fill = (tpl: string, vars: Record<string, string>): string =>
  tpl.replace(/\{(\w+)\}/g, (_, k) => vars[k] ?? "");

/** Sitemap : prestataires visibles et complets (route de NEO), filtrés par pays si le serveur le donne. */
export async function fetchProviderSitemap(): Promise<{ slug: string; role: string; updatedAt?: string; country?: string }[]> {
  try {
    const r = await fetch(`${API_BASE}/public/providers/sitemap`, { next: { revalidate: 3600 } });
    if (!r.ok) return [];
    const d = (await r.json()) as { providers?: { slug: string; role: string; updatedAt?: string; country?: string }[] };
    return (d.providers || []).filter((p) => p && SLUG_RE.test(p.slug) && !/gmail|hotmail|yahoo|outlook/i.test(p.slug));
  } catch {
    return [];
  }
}
