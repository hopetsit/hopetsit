"use client";

import Link from "@/components/SiteLink";
import { LogoWithText } from "./Logo";
import { PawMapCTA } from "./PawMapCTA";
import { useT } from "@/lib/i18n/LanguageProvider";

// v402 — réseaux sociaux officiels HoPetSit (fournis par Daniel).
const SOCIALS: { label: string; href: string; icon: React.ReactNode }[] = [
  {
    label: "Instagram",
    href: "https://www.instagram.com/hopetsit/",
    icon: (
      <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth={2}>
        <rect x="3" y="3" width="18" height="18" rx="5" />
        <circle cx="12" cy="12" r="4" />
        <circle cx="17.5" cy="6.5" r="1" fill="currentColor" stroke="none" />
      </svg>
    ),
  },
  {
    label: "TikTok",
    href: "https://www.tiktok.com/@hopetsit",
    icon: (
      <svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor">
        <path d="M16 3c.3 2.2 1.8 4 4 4.3V10c-1.5 0-2.9-.5-4-1.3V15a5.5 5.5 0 1 1-5.5-5.5c.3 0 .6 0 .9.08v2.7a2.8 2.8 0 1 0 1.9 2.6V3H16z" />
      </svg>
    ),
  },
  {
    label: "YouTube",
    href: "https://www.youtube.com/@HoPetSit/shorts",
    icon: (
      <svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor">
        <path d="M21.6 7.2a2.5 2.5 0 0 0-1.8-1.8C18.2 5 12 5 12 5s-6.2 0-7.8.4A2.5 2.5 0 0 0 2.4 7.2 26 26 0 0 0 2 12a26 26 0 0 0 .4 4.8 2.5 2.5 0 0 0 1.8 1.8C5.8 19 12 19 12 19s6.2 0 7.8-.4a2.5 2.5 0 0 0 1.8-1.8A26 26 0 0 0 22 12a26 26 0 0 0-.4-4.8zM10 15V9l5 3-5 3z" />
      </svg>
    ),
  },
  {
    label: "Facebook",
    href: "https://www.facebook.com/people/Hopetsit/61590596619482/",
    icon: (
      <svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor">
        <path d="M14 9h3V6h-3c-2.2 0-4 1.8-4 4v2H7v3h3v6h3v-6h2.5l.5-3H13v-2c0-.6.4-1 1-1z" />
      </svg>
    ),
  },
];

// 31/10 (LEO, étape 3 — décision BOB) — pied de page fr/en en 3 blocs : propriétaires · gardiens · HoPetSit,
// avec les deux actions en tête (« Publier ma demande », « Devenir gardien »). Tous les liens existants
// (SEO / maillage de GUS) sont conservés dans une rangée « Villes & guides ». Autres langues : inchangées.
const BLOCKS: Record<"fr" | "en", {
  owner: { title: string; cta: string; ctaHref: string; links: { href: string; label: string }[] };
  sitter: { title: string; cta: string; ctaHref: string; links: { href: string; label: string }[] };
  brand: { title: string; links: { href: string; label: string }[] };
  seo: string;
}> = {
  fr: {
    owner: { title: "Propriétaires", cta: "Publier ma demande", ctaHref: "/garde-animaux/paris", links: [
      { href: "/how-it-works", label: "Comment ça marche" }, { href: "/pricing", label: "Tarifs" }, { href: "/pawmap", label: "PawMap" }, { href: "/posts", label: "Mes candidats" } ] },
    sitter: { title: "Gardiens et promeneurs", cta: "Devenir gardien", ctaHref: "/devenir-petsitter", links: [
      { href: "/blog/devenir-pet-sitter-combien-ca-rapporte", label: "Combien ça rapporte ?" }, { href: "/download", label: "Télécharger l'app" }, { href: "/villes", label: "Toutes les villes" } ] },
    brand: { title: "HoPetSit", links: [
      { href: "/contact", label: "Contact" }, { href: "/faq", label: "FAQ" }, { href: "/terms", label: "Conditions d'utilisation" }, { href: "/privacy", label: "Confidentialité" },
      { href: "/refund", label: "Remboursements" }, { href: "/delete-account", label: "Supprimer mon compte" }, { href: "/imprint", label: "Mentions légales" } ] },
    seo: "Villes & guides",
  },
  en: {
    owner: { title: "Pet owners", cta: "Post my request", ctaHref: "/pet-sitting/new-york", links: [
      { href: "/how-it-works", label: "How it works" }, { href: "/pricing", label: "Pricing" }, { href: "/pawmap", label: "PawMap" }, { href: "/posts", label: "My candidates" } ] },
    sitter: { title: "Sitters and walkers", cta: "Become a sitter", ctaHref: "/become-a-pet-sitter/new-york", links: [
      { href: "/become-a-pet-sitter/dallas", label: "Become a pet sitter in Dallas" }, { href: "/download", label: "Get the app" }, { href: "/villes", label: "All cities" } ] },
    brand: { title: "HoPetSit", links: [
      { href: "/contact", label: "Contact" }, { href: "/faq", label: "FAQ" }, { href: "/terms", label: "Terms of use" }, { href: "/privacy", label: "Privacy" },
      { href: "/refund", label: "Refunds" }, { href: "/delete-account", label: "Delete my account" }, { href: "/imprint", label: "Legal notice" } ] },
    seo: "Cities & guides",
  },
};

export function Footer() {
  const { t, lang } = useT();
  const year = new Date().getFullYear();
  const blocks = lang === "fr" || lang === "en" ? BLOCKS[lang] : null;

  const cols = [
    {
      title: t("footer_about"),
      links: [
        { href: "/how-it-works", label: t("nav_how") },
        { href: "/pricing",      label: t("nav_pricing") },
        { href: "/pawmap",       label: t("nav_pawmap") },
        // v560 — hub des 152 pages villes (SEO).
        { href: "/villes",       label: t("footer_cities") },
      ],
    },
    {
      title: t("footer_help"),
      links: [
        { href: "/faq",      label: t("nav_faq") },
        { href: "/contact",  label: t("nav_contact") },
        { href: "/download", label: t("nav_download") },
      ],
    },
    {
      title: t("footer_legal"),
      links: [
        { href: "/terms",    label: t("footer_terms") },
        { href: "/privacy",  label: t("footer_privacy") },
        { href: "/delete-account", label: t("footer_delete_account") },
        { href: "/refund",   label: t("footer_refund") },
        { href: "/imprint",  label: t("footer_imprint") },
      ],
    },
    // v532 — SEO : maillage interne vers le blog et les pages villes
    // (libellés volontairement statiques : chaque page est monolingue).
    {
      title: "Guides",
      links: [
        { href: "/blog", label: "Blog" },
        // v577 — SEO (21/09/2026) : la page ou la publicite Paris envoie. Elle
        // n'avait qu'un seul lien entrant sur tout le site, depuis un article
        // de blog lui-meme pas indexe. Un lien de pied de page la rend
        // atteignable depuis les 223 pages deja indexees.
        { href: "/garde-animaux/paris", label: "Garde d'animaux à Paris" },
        // 26/10/2026 (Bob, semaine 44) : « devenir pet sitter » (sans ville) est
        // la requête la plus vue de la semaine côté recrutement (46
        // impressions/28 j) — la page n'existait pas avant cette semaine ; un
        // lien de pied de page la rend atteignable depuis les 223 pages déjà
        // indexées, comme pour /garde-animaux/paris en 21/09.
        { href: "/devenir-petsitter", label: "Devenir pet sitter" },
        // 29/09/2026 (LEO, retour de SAM) : /petsitter/paris et /petsitter/dallas
        // sont d'anciennes adresses (canonical vers les nouvelles) : le pied de
        // page pointe sur les pages canoniques. Push USA gratuit : les deux
        // pages Dallas (propriétaires + gardiens) et le hub des villes.
        { href: "/devenir-petsitter/paris", label: "Devenir pet sitter à Paris" },
        { href: "/petsitter/madrid", label: "Cuidador en Madrid" },
        { href: "/pet-sitting/dallas", label: "Pet sitters in Dallas" },
        { href: "/become-a-pet-sitter/dallas", label: "Become a pet sitter in Dallas" },
        // 01/10/2026 (SAM, demandé par BOB) : push USA gratuit, New York et
        // San Francisco reliés depuis toutes les pages déjà indexées.
        { href: "/pet-sitting/new-york", label: "Pet sitters in New York" },
        { href: "/pet-sitting/san-francisco", label: "Pet sitters in San Francisco" },
      ],
    },
  ];

  return (
    <footer className="border-t border-ink/5 bg-bg-soft">
      <div className="mx-auto max-w-6xl px-4 py-12 max-md:pb-24">
        {blocks && (
          <div className="mb-10 grid grid-cols-1 gap-6 md:grid-cols-3" data-footer-3110={lang}>
            <div className="rounded-3xl bg-white p-5" style={{ boxShadow: "inset 0 0 0 1.5px #F6D9CF" }}>
              <h4 className="text-[13px] font-extrabold uppercase tracking-wider" style={{ color: "#9E1F0B" }}>{blocks.owner.title}</h4>
              <Link href={blocks.owner.ctaHref} className="mt-3 block rounded-full px-5 py-3 text-center text-[15px] font-extrabold text-white shadow-card" style={{ background: "linear-gradient(135deg,#C92A12,#9E1F0B)" }}>
                {blocks.owner.cta}
              </Link>
              <ul className="mt-3 space-y-0">
                {blocks.owner.links.map((l) => <li key={l.href}><Link href={l.href} className="flex min-h-[40px] items-center text-sm font-semibold text-ink hover:text-owner-dark">{l.label}</Link></li>)}
              </ul>
            </div>
            <div className="rounded-3xl bg-white p-5" style={{ boxShadow: "inset 0 0 0 1.5px #C9DCF7" }}>
              <h4 className="text-[13px] font-extrabold uppercase tracking-wider" style={{ color: "#1E4FB0" }}>{blocks.sitter.title}</h4>
              <Link href={blocks.sitter.ctaHref} className="mt-3 block rounded-full px-5 py-3 text-center text-[15px] font-extrabold text-white shadow-card" style={{ background: "linear-gradient(135deg,#2F6FD6,#1E4FB0)" }}>
                {blocks.sitter.cta}
              </Link>
              <ul className="mt-3 space-y-0">
                {blocks.sitter.links.map((l) => <li key={l.href}><Link href={l.href} className="flex min-h-[40px] items-center text-sm font-semibold text-ink hover:text-sitter-dark">{l.label}</Link></li>)}
              </ul>
            </div>
            <div className="rounded-3xl bg-white p-5" style={{ boxShadow: "inset 0 0 0 1.5px #F6D9CF" }}>
              <h4 className="text-[13px] font-extrabold uppercase tracking-wider" style={{ color: "#231715" }}>{blocks.brand.title}</h4>
              <ul className="mt-3 grid grid-cols-2 gap-x-3">
                {blocks.brand.links.map((l) => <li key={l.href}><Link href={l.href} className="flex min-h-[40px] items-center text-sm font-semibold text-ink hover:text-owner-dark">{l.label}</Link></li>)}
              </ul>
            </div>
          </div>
        )}
        <div className="grid grid-cols-2 gap-8 md:grid-cols-6">
          <div className="col-span-2">
            <LogoWithText />
            <p className="mt-3 max-w-sm text-sm text-ink-muted">
              {t("footer_company")}
            </p>
            <p className="mt-2 text-sm text-ink-muted">
              <a href="mailto:contact@hopetsit.com" className="hover:text-ink max-lg:inline-flex max-lg:min-h-[44px] max-lg:items-center">
                contact@hopetsit.com
              </a>
            </p>
            {/* v23.1.452 — Daniel : CTA PawMap (fonctionnalité phare) dans le
                footer, présent sur chaque page. */}
            <div className="mt-5">
              <PawMapCTA size="compact" />
            </div>
            {/* v402 — réseaux sociaux HoPetSit (Daniel). */}
            <div className="mt-4 flex items-center gap-3">
              {SOCIALS.map((s) => (
                <a
                  key={s.label}
                  href={s.href}
                  target="_blank"
                  rel="noopener noreferrer"
                  aria-label={s.label}
                  title={s.label}
                  className="flex h-9 w-9 items-center justify-center rounded-full bg-white text-ink-muted shadow-sm ring-1 ring-ink/5 transition hover:text-ink hover:shadow max-lg:h-11 max-lg:w-11"
                >
                  {s.icon}
                </a>
              ))}
            </div>
          </div>
          {(blocks ? cols.filter((c) => c.title === "Guides").map((c) => ({ ...c, title: blocks.seo })) : cols).map((c) => (
            <div key={c.title} className={blocks ? "col-span-2 md:col-span-4" : undefined}>
              <h4 className="text-xs font-semibold uppercase tracking-wider text-ink-soft">
                {c.title}
              </h4>
              {/* v583 — pouce (Bob, 22/09) : ces liens faisaient 17 px de haut
                  pour 8 px d'ecart. On visait « Conditions generales » et on
                  ouvrait « Confidentialite ». Sur telephone chaque lien occupe
                  44 px et l'ecart tombe a 0 : la zone grandit, le pied de page
                  ne s'allonge presque pas. Le bureau est inchange. */}
              <ul className={blocks ? "mt-3 grid grid-cols-1 gap-x-6 sm:grid-cols-2" : "mt-3 space-y-2 max-lg:space-y-0"}>
                {c.links.map((l) => (
                  <li key={l.href}>
                    <Link
                      href={l.href}
                      className="text-sm text-ink-muted hover:text-ink max-lg:flex max-lg:min-h-[44px] max-lg:items-center"
                    >
                      {l.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
        <div className="mt-10 border-t border-ink/5 pt-6 text-xs text-ink-soft">
          © {year} CARDELLI HERMANOS LIMITED · {t("footer_rights")}
        </div>
      </div>
    </footer>
  );
}
