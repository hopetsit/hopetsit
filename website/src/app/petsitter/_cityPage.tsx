import Link from "next/link";

// v531 — SEO : template des pages ville « pet sitter à X » (statique serveur,
// une langue par marché). Le préfixe _ exclut ce fichier du routing.
export type CityContent = {
  city: string;
  h1: string;
  intro: string;
  servicesTitle: string;
  services: { icon: string; t: string; p: string }[];
  whyTitle: string;
  why: string[];
  faqTitle: string;
  faq: { q: string; a: string }[];
  ctaTitle: string;
  ctaBody: string;
  ctaButton: string;
  lang: string;
};

export function CityPage({ c }: { c: CityContent }) {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Service",
        name: `Pet sitting & dog walking — ${c.city}`,
        provider: { "@type": "Organization", name: "HoPetSit", url: "https://www.hopetsit.com" },
        areaServed: c.city,
        inLanguage: c.lang,
      },
      {
        "@type": "FAQPage",
        mainEntity: c.faq.map((f) => ({
          "@type": "Question",
          name: f.q,
          acceptedAnswer: { "@type": "Answer", text: f.a },
        })),
      },
    ],
  };

  return (
    <div className="mx-auto max-w-3xl px-4 py-16 md:py-24">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <h1 className="font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        {c.h1}
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">{c.intro}</p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">{c.servicesTitle}</h2>
      <div className="mt-6 grid gap-4 md:grid-cols-3">
        {c.services.map((s) => (
          <div key={s.t} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <div className="text-2xl">{s.icon}</div>
            <h3 className="mt-2 font-bold text-ink">{s.t}</h3>
            <p className="mt-1.5 text-sm leading-relaxed text-ink-muted">{s.p}</p>
          </div>
        ))}
      </div>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">{c.whyTitle}</h2>
      <ul className="mt-6 space-y-3">
        {c.why.map((w, i) => (
          <li key={i} className="flex gap-3 rounded-2xl border border-ink/5 bg-white p-4 shadow-card">
            <span className="text-owner">✓</span>
            <span className="text-sm leading-relaxed text-ink-muted">{w}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">{c.faqTitle}</h2>
      <div className="mt-6 space-y-4">
        {c.faq.map((f) => (
          <div key={f.q} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{f.q}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.a}</p>
          </div>
        ))}
      </div>

      <div className="mt-14 rounded-3xl bg-owner-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">{c.ctaTitle}</h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">{c.ctaBody}</p>
        <Link
          href="/download"
          className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white"
        >
          {c.ctaButton}
        </Link>
      </div>
    </div>
  );
}
