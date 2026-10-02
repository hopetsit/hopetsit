// 02/10/2026 (607, LEO) — /s/<slug> : page publique personnelle d'un gardien /
// promeneur (décision de Daniel, idée 1 « ramène tes clients »). Une URL par
// prestataire existant (vraie page unique, pas une page ville) : rendue côté
// serveur, revalidée toutes les 5 min, indexable sauf `indexable:false`,
// canonique, JSON-LD Person + Service, og:image = sa photo.
// ⚠️ openGraph de page REMPLACE celui du layout : siteName, type et image
// sont répétés ici (piège du 21/09).
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { t as bundles } from "@/lib/i18n/translations";
import { ProviderLinkPage } from "@/components/ProviderLinkPage";
import { fetchPublicProvider, fill, rateSourceOf, SITE_URL, type PublicProvider607 } from "@/lib/publicProvider607";
import { providerCurrency, providerRateLines } from "@/lib/providerRates";

export const revalidate = 300;
export const dynamicParams = true;
export function generateStaticParams() {
  return [];
}

const fr = bundles.fr;
const OG_DEFAULT = { url: `${SITE_URL}/og-image.png`, width: 1200, height: 630, alt: "HoPetSit" };

function texts(p: PublicProvider607) {
  const role = fr[p.role === "walker" ? "role_walker" : "role_sitter"];
  const title = p.city ? fill(fr.s607_title, { name: p.name, role, city: p.city }) : `${p.name} · ${role}`;
  const bio = (p.bio || "").replace(/\s+/g, " ").trim();
  const base = p.city ? fill(fr.s607_desc, { name: p.name, role, city: p.city }) : `${p.name}, ${role} — HoPetSit.`;
  const description = bio ? `${base} ${bio}`.slice(0, 158).replace(/\s\S*$/, "") + (bio.length + base.length > 158 ? "…" : "") : base;
  return { title, description, role };
}

export async function generateMetadata({ params }: { params: { slug: string } }): Promise<Metadata> {
  const p = await fetchPublicProvider(params.slug).catch(() => null);
  if (!p) return { title: "HoPetSit", robots: { index: false, follow: true } };
  const { title, description } = texts(p);
  const url = `${SITE_URL}/s/${p.slug}`;
  const image = p.photo ? { url: p.photo, alt: p.name } : OG_DEFAULT;
  return {
    title,
    description,
    alternates: { canonical: url },
    robots: p.indexable ? { index: true, follow: true } : { index: false, follow: true },
    openGraph: { type: "profile", siteName: "HoPetSit", url, title: `${title} · HoPetSit`, description, images: [image] },
    twitter: { card: p.photo ? "summary" : "summary_large_image", title: `${title} · HoPetSit`, description, images: [image.url] },
  };
}

function jsonLd(p: PublicProvider607) {
  const { role, description } = texts(p);
  const url = `${SITE_URL}/s/${p.slug}`;
  const src = rateSourceOf(p);
  const currency = providerCurrency(src);
  const UNIT: Record<string, string> = { hour: "HUR", day: "DAY", week: "WEE", month: "MON", "30": "MIN", "60": "HUR", "120": "HUR" };
  const offers = providerRateLines(p.role, src)
    .filter((l) => l.key !== "extra")
    .map((l) => ({
      "@type": "Offer",
      price: l.value,
      priceCurrency: currency,
      name: fr[l.labelKey] || l.key,
      priceSpecification: { "@type": "UnitPriceSpecification", price: l.value, priceCurrency: currency, unitCode: UNIT[l.key] || undefined, ...(l.key === "30" ? { referenceQuantity: { "@type": "QuantitativeValue", value: 30, unitCode: "MIN" } } : {}), ...(l.key === "120" ? { referenceQuantity: { "@type": "QuantitativeValue", value: 2, unitCode: "HUR" } } : {}) },
    }));
  const person: Record<string, unknown> = {
    "@type": "Person",
    "@id": `${url}#person`,
    name: p.name,
    url,
    jobTitle: role,
    ...(p.photo ? { image: p.photo } : {}),
    ...(p.city ? { address: { "@type": "PostalAddress", addressLocality: p.city } } : {}),
  };
  const service: Record<string, unknown> = {
    "@type": "Service",
    "@id": `${url}#service`,
    name: `${role} · ${p.name}`,
    serviceType: p.role === "walker" ? "Dog walking" : "Pet sitting",
    description,
    provider: { "@id": `${url}#person` },
    url,
    ...(p.city ? { areaServed: { "@type": "City", name: p.city } } : {}),
    ...(offers.length ? { offers } : {}),
  };
  return { "@context": "https://schema.org", "@graph": [person, service] };
}

export default async function Page({ params }: { params: { slug: string } }) {
  const p = await fetchPublicProvider(params.slug);
  if (!p) notFound();
  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd(p)).replace(/</g, "\\u003c") }} />
      <ProviderLinkPage p={p} />
    </>
  );
}
