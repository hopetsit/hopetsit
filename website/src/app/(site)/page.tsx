"use client";

import dynamic from "next/dynamic";
import Link from "@/components/SiteLink";
import { useMemo } from "react";
import StoreBadges from "@/components/StoreBadges";
import { AppIcon, type AppIconName } from "@/components/AppIcon";
import { PageTitle } from "@/components/PageTitle";
import { useT } from "@/lib/i18n/LanguageProvider";
import { useAuth } from "@/lib/useAuth";
import { pawmapShotFor, PhoneFrame, screensPreviewFor } from "@/lib/screens";
import { ROLE_COLOR } from "@/lib/pawmapLegend";
// 31/10 (LEO, décision BOB, étape 3) — premier écran = le formulaire 1 étape (fr/en) : accueil 94 vues → 0 clic d'action.
import { ParisHeroForm } from "@/components/ParisHeroForm";
// 10/11 (LEO, ordres de Daniel « embellir la page d'accueil » + « les pages ne sont pas à jour dans les autres
// langues ») — l'accueil est la MÊME dans les 9 langues : le formulaire de demande en premier écran partout
// (avant : fr/en seulement, les 7 autres langues gardaient l'ancienne recherche), les services dont « Garde en
// journée », la pastille « Véhiculé », les villes. Textes nouveaux : src/lib/i18n/accueil1011.ts.
import { a1011, heroUi1011 } from "@/lib/i18n/accueil1011";
import { k1011 } from "@/lib/i18n/conclure1011";
// 17/11 (LEO, ordre de Daniel transmis par BOB : « améliore la page d'accueil et aussi l'arrière-plan ») — l'accueil
// parle d'abord au PROPRIÉTAIRE : à quoi ça sert et pourquoi faire confiance dès le premier écran (faits VRAIS
// seulement), un bouton secondaire pour les gardiens, « comment ça marche » en 3 étapes, les captures de l'app, un
// appel final sans promesse de revenus. Le fond suit la variante du site (src/lib/siteBg1711.ts, classes hps-hero-1711
// de globals.css). Formulaire du premier écran (ParisHeroForm, NEO) : inchangé. Liens des villes : inchangés.
import { a1711 } from "@/lib/i18n/accueil1711";
import { SITE_BG_1711 } from "@/lib/siteBg1711";
import { trackSiteEvent } from "@/components/SiteAnalytics";

// v562 — Refonte « minimaliste, pro, façon Apple » (Daniel, 13/09).
// 24/09/2026 — LOT B (plan de LEO validé par Daniel « oui, valide tout ») :
//   étape 0 : plus aucun débordement à 375 px (les deux téléphones côte à côte
//             faisaient 404 px dans 375 : la page glissait de côté) ;
//   étape 1 : « Réserve ici en 2 minutes » — recherche ville/service en haut,
//             puis LA CARTE RÉELLE + le tableau de bord en 2e position,
//             sections en double fusionnées (preuves → héro, services +
//             abonnements + bande Premium → une seule grille, galerie de
//             captures → /download), 8 écrans max sur téléphone.
// Mêmes routes ; zéro emoji (icônes maison AppIcon) ; zéro gris.
const PublicPawMap = dynamic(() => import("@/components/PublicPawMap"), {
  ssr: false,
  loading: () => (
    <div className="flex h-[360px] items-center justify-center rounded-[28px] bg-[#FAF1EC] md:h-[420px]">
      <span className="h-6 w-6 animate-spin rounded-full border-2 border-[#C92A12] border-t-transparent" />
    </div>
  ),
});

// Tuile de pattes du fond du héros (même dessin que le papier peint « à mon animal » de globals.css), en couleur
// PLEINE #F3C7B8 sur crème : pas d'opacité, donc jamais de gris.
const PAWS_TILE = `url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 220 220' fill='%23F3C7B8'><g id='p'><ellipse cx='0' cy='6' rx='9' ry='7.5'/><ellipse cx='-9' cy='-3' rx='4' ry='5.2' transform='rotate(-24 -9 -3)'/><ellipse cx='-3' cy='-9' rx='4' ry='5.4'/><ellipse cx='3' cy='-9' rx='4' ry='5.4'/><ellipse cx='9' cy='-3' rx='4' ry='5.2' transform='rotate(24 9 -3)'/></g><use href='%23p' transform='translate(40 40) rotate(-20) scale(1.1)'/><use href='%23p' transform='translate(150 30) rotate(30) scale(.85)'/><use href='%23p' transform='translate(95 125) rotate(10)'/><use href='%23p' transform='translate(185 170) rotate(-35) scale(.9)'/><use href='%23p' transform='translate(30 185) rotate(45) scale(.75)'/><path transform='translate(200 95) scale(.55)' d='M0 12 C-14 2,-8 -12,0 -6 C8 -12,14 2,0 12z'/><path transform='translate(80 200) scale(.5) rotate(-15)' d='M0 12 C-14 2,-8 -12,0 -6 C8 -12,14 2,0 12z'/></svg>") 0 0 / 220px 220px repeat`;

const PARIS: [number, number] = [48.8566, 2.3522];

// v585 — mobile (Bob, 25/09) : à 375 px le titre coupait « pet-/sitter » et
// laissait « 2 » seul en bout de ligne. Les mots à trait d'union restent
// entiers et un nombre reste collé au mot suivant. Fonction simple (pas un
// hook), sans effet sur les langues sans espaces (ja, ko).
function keepTogether(text: string, lang?: string) {
  // 10/11 — japonais : le titre n'a pas d'espaces, le navigateur coupait au milieu d'un mot (« ペットシッ / ター »).
  // On le découpe en groupes de sens (après une particule suivie d'un mot en katakana ou en kanji) et chaque
  // groupe reste entier sur sa ligne.
  if (lang === "ja") {
    // (sans « lookbehind » : les anciens Safari le refusent et toute la page planterait)
    return text
      .replace(/([でをにはがと、])(?=[\u30A0-\u30FF\u4E00-\u9FFF])/g, "$1\u0001")
      .split("\u0001")
      .map((part, i) => <span key={i} className="inline-block">{part}</span>);
  }
  // 10/11 — un petit mot juste avant le nombre reste collé lui aussi (« in 2 minutes », « en 2 minutes ») :
  // plus de « in » seul en fin de ligne.
  const joined = text.replace(/(\d+) (?=\S)/g, "$1\u00A0").replace(/(^|\s)(\p{L}{1,3}) (?=\d)/gu, "$1$2\u00A0");
  return joined.split(/(\S*-\S*)/).map((part, i) =>
    part.includes("-") && !/\s/.test(part) ? <span key={i} className="whitespace-nowrap">{part}</span> : part,
  );
}

// 10/11 — même tuile de pattes, en orange PLEIN plus clair que la bande (jamais d'opacité), pour l'appel final.
// 11/11/2026 (BOB, ordre de Daniel : « mets un plus beau arrière-plan sur la page d'accueil ») — fond du héros :
// lumières chaudes aux couleurs de la marque (ambre en haut à gauche, orange HoPetSit en haut à droite, rose et
// or en bas) sur un dégradé pêche → blanc, pattes gardées, vague douce en bas. CSS + SVG en ligne seulement :
// 0 image à charger, donc aucun poids en plus sur téléphone. Jamais de gris. Retour arrière : HERO_BG_1111 = false.
const HERO_BG_1111 = true;
const HERO_BG_OLD_3110 = `${PAWS_TILE}, radial-gradient(55% 60% at 80% 25%, rgba(201,42,18,0.16), rgba(201,42,18,0) 70%), linear-gradient(165deg, #F8D9CC 0%, #FFF3EC 40%, #FFFFFF 100%)`;
const HERO_BG_NEW_1111 = [
  PAWS_TILE,
  "radial-gradient(42% 46% at 8% 4%, rgba(255,170,110,0.55), rgba(255,170,110,0) 72%)",
  "radial-gradient(46% 52% at 94% 10%, rgba(201,42,18,0.30), rgba(201,42,18,0) 72%)",
  "radial-gradient(40% 40% at 86% 82%, rgba(240,106,160,0.20), rgba(240,106,160,0) 72%)",
  "radial-gradient(42% 38% at 6% 88%, rgba(244,192,74,0.26), rgba(244,192,74,0) 72%)",
  "linear-gradient(180deg, #FFDCC9 0%, #FFEDE2 38%, #FFF8F3 72%, #FFFFFF 100%)",
].join(", ");
const PAWS_TILE_BAND = PAWS_TILE.replace("fill='%23F3C7B8'", "fill='%23B5230F'");

const GRAD = "linear-gradient(90deg, #C92A12, #9E1F0B)";

// 10/11 — pays d'envoi par langue affichée (le serveur fixe la devise d'après le pays ; l'e-mail part en anglais
// hors fr). La ville reste à saisir : celle-ci n'est que la proposition de départ.
const HOME_COUNTRY: Record<string, string> = { fr: "FR", en: "US", es: "ES", de: "DE", it: "IT", pt: "PT", pl: "PL", ko: "KR", ja: "JP" };

// 10/11 — ornement commun des titres de section : une patte entre deux traits en dégradé horizontal.
function Ornament({ tone = "#C92A12", soft = "#F6D9CF" }: { tone?: string; soft?: string }) {
  return (
    <span aria-hidden="true" className="mb-3 flex items-center justify-center gap-2.5">
      <span className="h-[3px] w-9 rounded-full" style={{ backgroundImage: `linear-gradient(90deg, ${soft}, ${tone})` }} />
      <AppIcon name="paw" size={18} color={tone} />
      <span className="h-[3px] w-9 rounded-full" style={{ backgroundImage: `linear-gradient(90deg, ${tone}, ${soft})` }} />
    </span>
  );
}

// 10/11 — une carte « service » pré-remplit le formulaire du haut : on appuie sur SON bouton de service (rien
// n'est ajouté au formulaire, qui reste le seul maître de son état), puis on y remonte.
function goToForm(serviceId?: string) {
  if (typeof document === "undefined") return;
  if (serviceId) {
    const btn = document.querySelector<HTMLButtonElement>(`[data-testid="hero-services-1011"] button[data-svc="${serviceId}"]`);
    if (btn && btn.getAttribute("aria-pressed") !== "true") btn.click();
  }
  const target = document.getElementById("publier");
  const calm = typeof window !== "undefined" && window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (target) target.scrollIntoView({ behavior: calm ? "auto" : "smooth", block: "start" });
  else window.scrollTo({ top: 0, behavior: calm ? "auto" : "smooth" });
}

export default function HomePage() {
  const { t, lang } = useT();
  const { user, ready } = useAuth();
  const heroUi = useMemo(() => heroUi1011(lang), [lang]);
  const logged = ready && !!user;
  const serverLang: "fr" | "en" = lang === "fr" ? "fr" : "en";

  const roles = [
    { key: "owner", icon: "paw" as AppIconName, color: ROLE_COLOR.owner, bg: "#FBE9E5", title: t("role_owner_title"), body: t("role_owner_body"), price: t("pricing_owner_price") },
    { key: "sitter", icon: "home" as AppIconName, color: ROLE_COLOR.sitter, bg: "#E3EFFE", title: t("role_sitter_title"), body: t("role_sitter_body"), price: t("pricing_provider_price") },
    { key: "walker", icon: "walker" as AppIconName, color: ROLE_COLOR.walker, bg: "#DEF7E5", title: t("role_walker_title"), body: t("role_walker_body"), price: t("pricing_provider_price") },
  ] as const;

  // 17/11 — la confiance, en faits VRAIS (jamais « tous vérifiés » : le badge se voit sur les profils qui l'ont).
  const miniTrust = [a1711(lang, "m_pay"), a1711(lang, "m_cancel"), a1711(lang, "m_id")];
  const trustCards: { icon: AppIconName; color: string; bg: string; title: string; body: string }[] = [
    { icon: "shield-check", color: ROLE_COLOR.walker, bg: "#DEF7E5", title: a1711(lang, "c_id_title"), body: a1711(lang, "c_id_body") },
    { icon: "lock", color: ROLE_COLOR.owner, bg: "#FBE9E5", title: a1711(lang, "c_pay_title"), body: a1711(lang, "c_pay_body") },
    { icon: "clock", color: ROLE_COLOR.sitter, bg: "#E3EFFE", title: a1711(lang, "c_cancel_title"), body: a1711(lang, "c_cancel_body") },
    { icon: "chat", color: ROLE_COLOR.owner, bg: "#FBE9E5", title: a1711(lang, "c_chat_title"), body: a1711(lang, "c_chat_body") },
  ];
  // Bouton secondaire « gardien » : la page de recrutement de la langue quand elle existe, sinon l'inscription.
  const sitterHref = lang === "fr" ? "/devenir-petsitter" : lang === "en" ? "/become-a-pet-sitter" : "/signup";
  const appShots = screensPreviewFor(lang).slice(0, 3);

  // 10/11 — les 4 services du formulaire, présentés (mêmes noms, même ordre que dans l'app et le formulaire).
  const services: { id: "garde" | "journee" | "promenade" | "visites"; icon: AppIconName; color: string; bg: string; title: string; desc: string }[] = [
    { id: "garde", icon: "moon", color: ROLE_COLOR.sitter, bg: "#E3EFFE", title: a1011(lang, "svc_garde"), desc: a1011(lang, "svc_garde_desc") },
    { id: "journee", icon: "sun", color: ROLE_COLOR.owner, bg: "#FBE9E5", title: a1011(lang, "svc_journee"), desc: a1011(lang, "svc_journee_desc") },
    { id: "promenade", icon: "walker", color: ROLE_COLOR.walker, bg: "#DEF7E5", title: a1011(lang, "svc_promenade"), desc: a1011(lang, "svc_promenade_desc") },
    { id: "visites", icon: "home", color: ROLE_COLOR.sitter, bg: "#E3EFFE", title: a1011(lang, "svc_visites"), desc: a1011(lang, "svc_visites_desc") },
  ];

  // 10/11 — ce que montre la carte d'un candidat (aucun nom, prix ni avis inventé : seulement les libellés).
  const proofs: { icon: AppIconName; label: string }[] = [
    { icon: "shield-check", label: t("trust_id_title") },
    { icon: "coins", label: a1011(lang, "proof_price") },
    { icon: "route", label: k1011(lang, "vehicle_badge") },
    { icon: "clock", label: a1011(lang, "proof_cancel") },
  ];

  // 3 services + PawPremium dans UNE grille (fusion des sections « 3 apps »,
  // « abonnements expliqués » et « bande PawPremium » de la v562).
  const products = [
    { name: "PetSitting", title: t("home_app1_title"), body: t("home_app1_body"), logo: "/pawboost_logo.svg", href: "/pawmap", cta: t("home_book_on_site"), dark: false },
    { name: "PawFollow", title: t("home_app2_title"), body: t("home_app2_body"), logo: "/pawfollow_logo.svg", href: "/pricing", cta: `${t("home_discover")} PawFollow`, dark: false },
    { name: "PawSpot", title: t("home_app3_title"), body: t("home_app3_body"), logo: "/pawspot_logo.svg", href: "/pawmap", cta: `${t("home_discover")} PawSpot`, dark: false },
    { name: "PawPremium", title: t("home_pawpremium_title_short"), body: t("home_pawpremium_blurb"), logo: "/pawpremium_logo.svg", href: "/boutique", cta: `${t("home_discover")} PawPremium`, dark: true },
  ] as const;

  // 17/11 — 3 étapes, celles du parcours réel : publier (sans compte), recevoir les candidats et leur prix,
  // choisir et payer (argent versé après la garde).
  const steps = [
    { n: "1", icon: "megaphone" as AppIconName, title: a1011(lang, "step1_title"), body: a1011(lang, "step1_body") },
    { n: "2", icon: "people" as AppIconName, title: a1711(lang, "s2_title"), body: a1711(lang, "s2_body") },
    { n: "3", icon: "lock" as AppIconName, title: a1711(lang, "s3_title"), body: a1011(lang, "step3_body") },
  ] as const;

  const faq = Array.from({ length: 10 }, (_, i) => ({ q: t(`faq_q${i + 1}`), a: t(`faq_a${i + 1}`) }))
    .filter((x) => x.q && !x.q.startsWith("faq_"))
    .slice(0, 4);

  const pawmapShot = pawmapShotFor(lang);
  const dashHref = logged ? "/dashboard" : "/login?redirect=%2Fdashboard";

  // 10/11 — bloc des villes : la colonne États-Unis reste en anglais pour un visiteur français (comme avant,
  // et c'est ce que lit Google) ; dans les 7 autres langues, les deux colonnes sont traduites.
  const usLang = lang === "fr" ? "en" : lang;
  const chip = "inline-flex items-center rounded-[12px] border border-[#F3D2C8] bg-[#FFF7F3] px-3 py-1.5 text-[#231715] transition hover:border-owner hover:bg-owner-light hover:text-owner-dark max-lg:min-h-[44px]";
  const textLink = "font-semibold text-owner hover:underline max-lg:inline-flex max-lg:min-h-[44px] max-lg:items-center";
  const h2 = "text-balance text-center font-display text-3xl font-bold tracking-[-0.02em] text-[#231715] md:text-5xl";

  return (
    // 10/11 — en coréen, une ligne ne se coupe jamais au milieu d'un mot (« 예 / 약하세요 ») : `break-keep`
    // sur une enveloppe sans boîte (`contents`), donc aucune mise en page ne change dans les autres langues.
    <div className={lang === "ko" ? "contents break-keep" : lang === "ja" ? "contents [word-break:auto-phrase]" : "contents"}>
      <PageTitle titleKey="page_title_home" descKey="page_desc_home" />

      {/* ── 1. HÉRO ── « Réserve ici en 2 minutes » : le formulaire en haut,
           l'app en second. Une colonne sur téléphone, téléphone à droite sur
           grand écran seulement (plus jamais 3 cadres côte à côte). */}
      {/* 31/10 (LEO, demande de Daniel « version PC, centre mieux ») — à partir de 1024 px : conteneur 1180 px centré,
          deux colonnes équilibrées (formulaire 560 px | maquette 400 px) centrées dans la page, marges égales ;
          dégagement en haut pour que le H1 ne passe jamais sous l'en-tête collant. Mobile/tablette inchangés. */}
      {/* 31/10 (3e demande de Daniel « éviter ce grand espace blanc, et aussi mets un fond d'écran ») : colonnes
          rapprochées (formulaire 460 px | maquette 288-320 px, écart 48-64 px, le tout centré), et un vrai fond de héros :
          dégradé chaud orange → crème + pattes discrètes (SVG en couleur pleine, jamais du gris) — CSS seul, 0 octet
          d'image, donc rien de lourd sur téléphone et LCP inchangé. */}
      <section className="hps-hero-1711" style={SITE_BG_1711 === "old" ? { background: HERO_BG_1111 ? HERO_BG_NEW_1111 : HERO_BG_OLD_3110 } : undefined} data-hero-bg-3110="" data-hero-bg-1711={SITE_BG_1711}>
        {/* 11/11 — vague douce en bas du héros (fond d'avant le 17/11 seulement : classe masquée par les variantes A et B). */}
        <svg aria-hidden="true" className="hps-hero-wave-1711 pointer-events-none absolute inset-x-0 bottom-0 h-10 w-full md:h-16" viewBox="0 0 1440 80" preserveAspectRatio="none">
          <path d="M0 46 C 240 6, 480 6, 720 34 S 1200 74, 1440 30 L1440 80 L0 80 Z" fill="#FFE1D2" opacity="0.7" />
          <path d="M0 58 C 300 22, 560 26, 820 50 S 1240 78, 1440 46 L1440 80 L0 80 Z" fill="#FFFFFF" />
        </svg>
        <div className="mx-auto grid max-w-6xl items-center gap-10 px-4 pb-10 pt-8 md:pb-14 md:pt-16 lg:max-w-[1180px] lg:grid-cols-[minmax(0,448px)_auto] lg:justify-center lg:gap-12 lg:pt-20 xl:gap-16">
          <div className="min-w-0 text-center lg:text-left">
            {/* 17/11 — à quoi ça sert, en une ligne (remplace « 177 pays », qui ne dit rien à un propriétaire). */}
            <p className="text-[12.5px] font-bold uppercase tracking-[0.08em] text-owner-dark" data-home-eyebrow-1711="">{a1711(lang, "eyebrow")}</p>
            <h1 className={`mt-2.5 font-display font-bold tracking-[-0.03em] text-[#231715] md:text-6xl ${lang === "ja" ? "text-[1.75rem] leading-[1.2] lg:text-[2.5rem]" : "text-[2rem] leading-[1.05] lg:text-5xl"}`}>
              {keepTogether(t("home_hero_title_book"), lang)}
            </h1>
            {/* 17/11 — pourquoi faire confiance, AVANT le formulaire : 3 faits vrais, courts. */}
            <ul className="mt-3.5 flex flex-wrap items-center justify-center gap-x-3.5 gap-y-1.5 text-[12.5px] font-semibold leading-tight text-[#231715] lg:justify-start" data-home-minitrust-1711="">
              {miniTrust.map((m) => (
                <li key={m} className="inline-flex items-center gap-1.5">
                  <AppIcon name="check" size={14} color="#16A34A" className="shrink-0" />
                  {m}
                </li>
              ))}
            </ul>

            {/* 31/10 (LEO, décision BOB) — le formulaire 1 étape (ville à saisir), publié sans compte.
                10/11 — dans les 9 langues : fr et en gardent leurs textes ; les 7 autres reçoivent les leurs par
                `ui` (le serveur, lui, reçoit toujours fr ou en).
                17/11 — `lead` : « Les gardiens et promeneurs… » (plus « gardiens vérifiés » : tous ne le sont pas). */}
            <div className="mx-auto w-full max-w-md text-left lg:mx-0" data-home-form-3110={lang}>
              <ParisHeroForm
                city={a1011(lang, "hero_city")}
                cityEditable
                lang={serverLang}
                uiLang={lang}
                ui={heroUi}
                polish
                country={HOME_COUNTRY[lang] || "US"}
                campaign={`home_${lang}`}
                page="/"
                lead={a1711(lang, "lead")}
                note={a1011(lang, "note")}
              />
            </div>

            {/* 17/11 — bouton SECONDAIRE (norme : blanc, contour 1,5 px à la couleur du rôle, disque teinté) pour
                les gardiens et promeneurs ; le bouton principal de l'écran reste « Publier ma demande ». */}
            <div className="mx-auto mt-4 w-full max-w-md lg:mx-0">
              <Link
                href={sitterHref}
                onClick={() => trackSiteEvent("cta_click", { label: "home_gardien" })}
                data-home-sitter-1711=""
                className="flex min-h-[48px] w-full items-center justify-center gap-2.5 rounded-[16px] border-[1.5px] border-[#2563EB] bg-white px-4 py-2 text-center text-[15px] font-bold leading-tight text-[#173F8F] transition hover:bg-[#F1F6FE]"
              >
                <span className="grid h-8 w-8 shrink-0 place-items-center rounded-[10px] bg-[#E3EFFE]"><AppIcon name="home" size={16} color="#2563EB" /></span>
                <span className="min-w-0 text-balance">{a1711(lang, "sitter_cta")}</span>
              </Link>
            </div>

            <div className="mt-4 flex flex-wrap items-center justify-center gap-3 lg:justify-start">
              <StoreBadges className="justify-center lg:justify-start" />
            </div>
          </div>
          <div className="hidden justify-center lg:flex">
            <PhoneFrame src={pawmapShot} alt={t("hero609_alt")} className="w-72 xl:w-80" priority w={768} h={1669} />
          </div>
        </div>
      </section>

      {/* ── 2. CONFIANCE ── 17/11 : quatre faits vrais (badge sur les profils qui l'ont, paiement gardé, annulation
           gratuite jusqu'à 72 h avant, messagerie). Aucun chiffre, aucun avis inventé. */}
      <section className="py-10 md:py-16" data-home-trust-1711="">
        <div className="mx-auto max-w-6xl px-4">
          <Ornament />
          <h2 className={h2}>{a1711(lang, "trust_title")}</h2>
          <p className="mx-auto mt-3 max-w-2xl text-balance text-center text-base text-[#6E4F48] md:text-lg">{a1711(lang, "trust_sub")}</p>
          <ul className="mt-7 grid gap-3 sm:grid-cols-2 md:mt-10 lg:grid-cols-4 lg:gap-4">
            {trustCards.map((c) => (
              <li key={c.title} className="flex items-start gap-3.5 rounded-[20px] border border-[#F3D2C8] bg-white p-4 shadow-[0_14px_30px_-24px_rgba(201,42,18,0.45)] md:p-5 lg:block">
                <span className="grid h-11 w-11 shrink-0 place-items-center rounded-[14px]" style={{ background: c.bg }}>
                  <AppIcon name={c.icon} size={22} color={c.color} />
                </span>
                <div className="min-w-0">
                  <h3 className="font-display text-[16px] font-bold leading-snug tracking-[-0.01em] text-[#231715] lg:mt-4 lg:text-[17px]">{c.title}</h3>
                  <p className="mt-1 text-[13.5px] leading-relaxed text-[#6E4F48] lg:mt-1.5 lg:text-sm">{c.body}</p>
                </div>
              </li>
            ))}
          </ul>
        </div>
      </section>

      {/* ── 3. COMMENT ÇA MARCHE ── 17/11 : 3 étapes (avant : 4, dans un carrousel à faire glisser sur téléphone). */}
      <section className="bg-white py-10 md:py-16" data-home-steps-1711="">
        <div className="mx-auto max-w-5xl px-4">
          <Ornament />
          <h2 className={h2}>{t("nav_how")}</h2>
          <ol className="mt-7 grid gap-3 md:mt-10 md:grid-cols-3 md:gap-4">
            {steps.map((s) => (
              <li key={s.n} className="relative flex items-start gap-4 rounded-[20px] border border-[#F3D2C8] bg-[#FFF7F3] p-4 md:block md:rounded-[24px] md:p-6">
                <span className="grid h-11 w-11 shrink-0 place-items-center rounded-[14px] font-display text-lg font-bold text-white" style={{ backgroundImage: GRAD }}>{s.n}</span>
                <div className="min-w-0">
                  <h3 className="font-display text-[16px] font-bold leading-snug tracking-[-0.01em] text-[#231715] md:mt-4 md:text-lg">{s.title}</h3>
                  <p className="mt-1 text-[13.5px] leading-relaxed text-[#6E4F48] md:mt-1.5 md:text-sm">{s.body}</p>
                </div>
              </li>
            ))}
          </ol>
          <div className="mx-auto mt-6 max-w-sm md:mt-8">
            <button type="button" onClick={() => { trackSiteEvent("cta_click", { label: "home_etapes_publier" }); goToForm(); }} className="inline-flex min-h-[56px] w-full items-center justify-center gap-2.5 rounded-[18px] px-5 text-[16px] font-bold text-white transition hover:brightness-110" style={{ backgroundImage: GRAD }}>
              <span className="grid h-8 w-8 shrink-0 place-items-center rounded-[10px] bg-white"><AppIcon name="megaphone" size={16} color="#C92A12" /></span>
              {a1011(lang, "f_cta")}
            </button>
          </div>
        </div>
      </section>

      {/* ── 4. SERVICES ── 10/11 : les 4 services du formulaire, dont « Garde en journée ». Une carte = un
           appui : le service est coché dans le formulaire du haut et la page y remonte. */}
      <section className="py-10 md:py-16" data-home-services-1011="">
        <div className="mx-auto max-w-6xl px-4">
          <Ornament />
          <h2 className={h2}>{a1011(lang, "services_title")}</h2>
          <p className="mx-auto mt-3 max-w-2xl text-balance text-center text-base text-[#6E4F48] md:text-lg">{a1011(lang, "services_sub")}</p>

          <div className="mt-8 grid grid-cols-2 gap-3 md:mt-12 lg:grid-cols-4 lg:gap-4">
            {services.map((s) => (
              <button
                key={s.id}
                type="button"
                onClick={() => goToForm(s.id)}
                data-home-svc-1011={s.id}
                className="group flex h-full flex-col rounded-[22px] border border-[#F3D2C8] bg-white p-4 text-left transition hover:-translate-y-0.5 hover:border-owner hover:shadow-[0_18px_32px_-22px_rgba(201,42,18,0.55)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-owner md:p-6"
              >
                <span className="grid h-12 w-12 place-items-center rounded-[14px]" style={{ background: s.bg }}>
                  <AppIcon name={s.icon} size={24} color={s.color} />
                </span>
                <span className="mt-3 block font-display text-[17px] font-bold leading-tight tracking-[-0.01em] text-[#231715] md:mt-4 md:text-xl">{s.title}</span>
                <span className="mt-1.5 block text-[13px] leading-snug text-[#6E4F48] md:text-[15px] md:leading-relaxed">{s.desc}</span>
                <span className="mt-auto block pt-4">
                  <span className="flex min-h-[44px] items-center justify-center gap-1.5 rounded-[14px] px-3 text-sm font-bold text-white" style={{ backgroundImage: GRAD }}>
                    {a1011(lang, "svc_pick")}
                    <AppIcon name="arrow-right" size={15} color="#fff" />
                  </span>
                </span>
              </button>
            ))}
          </div>

          {/* Les preuves : ce qu'affiche chaque candidat avant qu'on le choisisse (dont « Véhiculé »). */}
          <div className="mt-6 rounded-[22px] border border-[#F3D2C8] bg-white p-4 md:mt-8 md:p-5" data-home-proofs-1011="">
            <p className="text-center text-[12px] font-bold uppercase tracking-[0.12em] text-owner">{a1011(lang, "cand_label")}</p>
            <ul className="mt-3 grid grid-cols-2 gap-2 lg:grid-cols-4 lg:gap-3">
              {proofs.map((p) => (
                <li key={p.label} className="flex min-h-[52px] items-center gap-2.5 rounded-[14px] bg-[#FAF1EC] px-3 py-2 text-[13px] font-semibold leading-tight text-[#231715] md:text-sm">
                  <span className="grid h-8 w-8 shrink-0 place-items-center rounded-[10px] bg-white"><AppIcon name={p.icon} size={17} color="#C92A12" /></span>
                  <span className="min-w-0">{p.label}</span>
                </li>
              ))}
            </ul>
          </div>
        </div>
      </section>

      {/* ── 5. L'APP ET LE SITE ── 17/11 : « dans l'app HoPetSit ou sur hopetsit.com » — trois captures réelles de
           l'app (jeu validé de lib/screens : aucun membre identifiable) + les badges officiels des stores. */}
      <section className="bg-white py-10 md:py-16" data-home-stores-1011="" data-home-app-1711="">
        <div className="mx-auto max-w-5xl px-4 text-center">
          <Ornament />
          <h2 className={h2}>{a1711(lang, "app_title")}</h2>
          <p className="mx-auto mt-3 max-w-xl text-balance text-[15px] leading-relaxed text-[#6E4F48] md:text-lg">{a1011(lang, "stores_sub")}</p>
          <div className="mx-auto mt-7 grid max-w-[640px] grid-cols-3 items-end gap-2.5 md:mt-10 md:gap-6">
            {appShots.map((shot, i) => (
              <div key={shot.src} className={`rounded-[18px] bg-[#231715] p-[3px] shadow-[0_24px_44px_-26px_rgba(35,23,21,0.55)] md:rounded-[30px] md:p-[5px] ${i === 1 ? "" : "translate-y-3 md:translate-y-5"}`}>
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={shot.src} alt={shot.alt} width={shot.w || 1080} height={shot.h || 2348} loading="lazy" decoding="async" className="block h-auto w-full rounded-[15px] bg-[#FBF3EE] md:rounded-[25px]" />
              </div>
            ))}
          </div>
          <StoreBadges center className="mt-10 justify-center md:mt-14" />
          <p className="mt-4 text-sm"><Link href="/download" className={textLink}>{t("hero_cta_app")} →</Link></p>
        </div>
      </section>

      {/* ── 6. CARTE + TABLEAU DE BORD ── la vraie PawMap (sans compte) et le
           tableau de bord web, mis en avant dès le 2e écran. */}
      <section className="bg-white py-10 md:py-16">
        <div className="mx-auto max-w-6xl px-4">
          <Ornament />
          <h2 className={h2}>
            {t("home_map_dash_title")}
          </h2>
          <p className="mx-auto mt-3 max-w-2xl text-balance text-center text-base text-[#6E4F48] md:text-lg">{t("home_map_dash_sub")}</p>

          <div className="mt-10 grid gap-5 lg:grid-cols-[1.25fr_0.75fr]">
            {/* La carte réelle : gardiens et promeneurs de Paris, floutés à ~1 km. */}
            <div className="rounded-[32px] border border-[#F3D2C8] bg-white p-2">
              <PublicPawMap center={PARIS} zoom={12} height="clamp(300px, 42vh, 460px)" compact />
              <div className="flex flex-wrap items-center justify-between gap-2 px-3 py-3">
                <span className="inline-flex items-center gap-2 text-sm font-semibold text-[#231715]">
                  <AppIcon name="map" size={18} color="#C92A12" />
                  {t("home_map_caption")}
                </span>
                <span className="inline-flex items-center gap-1.5 text-xs text-[#6E4F48]">
                  <AppIcon name="lock" size={13} />
                  {t("pawmap_public_privacy")}
                </span>
              </div>
            </div>

            {/* Le tableau de bord web : ce qu'on y fait, et le bouton. */}
            <div className="flex flex-col rounded-[32px] bg-[#231715] p-6 text-white md:p-8">
              <div className="flex items-center gap-3">
                <span className="grid h-11 w-11 place-items-center rounded-2xl" style={{ backgroundImage: GRAD }}><AppIcon name="calendar" size={22} color="#fff" /></span>
                <h3 className="font-display text-xl font-bold tracking-[-0.02em]">{t("home_dash_title")}</h3>
              </div>
              <p className="mt-3 text-[15px] leading-relaxed text-[#FDF8F7]">{t("home_dash_sub")}</p>

              {/* Aperçu « à faire aujourd'hui » (illustration du bloc réel du tableau de bord). */}
              <div className="mt-5 hidden grid-cols-3 gap-2 sm:grid">
                {([
                  ["wallet", t("dash_today_to_pay"), ROLE_COLOR.owner],
                  ["chat", t("dash_card_messages_title"), ROLE_COLOR.sitter],
                  ["calendar", t("dash_today_next"), ROLE_COLOR.walker],
                ] as [AppIconName, string, string][]).map(([icon, label, color]) => (
                  <div key={label} className="rounded-2xl bg-[#3A2622] p-3 text-center">
                    <span className="mx-auto grid h-9 w-9 place-items-center rounded-[12px]" style={{ background: color }}><AppIcon name={icon} size={18} color="#fff" /></span>
                    <span className="mt-2 block text-[11px] font-semibold leading-tight text-[#FDF8F7]">{label}</span>
                  </div>
                ))}
              </div>

              <ul className="mt-4 hidden space-y-2 text-sm text-[#FDF8F7] sm:block">
                {[t("home_dash_l1"), t("home_dash_l2"), t("home_dash_l3")].map((l) => (
                  <li key={l} className="flex items-start gap-2"><AppIcon name="check" size={16} color="#F4C04A" className="mt-0.5 shrink-0" />{l}</li>
                ))}
              </ul>

              <Link href={dashHref} className="mt-6 inline-flex min-h-[56px] items-center justify-center gap-2 rounded-[18px] px-6 text-[15px] font-bold text-white transition hover:brightness-110 lg:mt-auto" style={{ backgroundImage: GRAD }}>
                <span className="grid h-8 w-8 place-items-center rounded-[10px] bg-white"><AppIcon name="profile" size={16} color="#C92A12" /></span>
                {logged ? t("home_dash_cta_open") : t("home_dash_cta_login")}
              </Link>
              {!logged && (
                <Link href="/signup" className="mt-3 text-center text-sm font-semibold text-[#F4C04A] hover:underline max-lg:inline-flex max-lg:min-h-[44px] max-lg:items-center max-lg:justify-center">
                  {t("nav_signup")} →
                </Link>
              )}
            </div>
          </div>
        </div>
      </section>

      {/* ── 5. TROIS RÔLES, UN COMPTE ── + les 4 produits (une seule grille). */}
      <section className="py-10 md:py-16">
        <div className="mx-auto max-w-6xl px-4">
          <Ornament />
          <h2 className={h2}>
            {t("roles_title")}
          </h2>
          <div className="mt-8 grid gap-3 md:mt-12 md:grid-cols-3 md:gap-4">
            {roles.map((r) => (
              <div key={r.key} className="relative flex items-start gap-4 overflow-hidden rounded-[24px] border border-[#F3D2C8] bg-white p-5 md:block md:p-8">
                <span aria-hidden="true" className="absolute inset-x-0 top-0 h-1.5" style={{ background: r.color }} />
                <span className="grid h-12 w-12 shrink-0 place-items-center rounded-[14px]" style={{ background: r.bg }}>
                  <AppIcon name={r.icon} size={24} color={r.color} />
                </span>
                <div className="min-w-0">
                  <h3 className="text-lg font-semibold text-[#231715] md:mt-5 md:text-xl">{r.title}</h3>
                  <p className="mt-1 text-sm leading-relaxed text-[#6E4F48] md:mt-2 md:text-[15px]">{r.body}</p>
                  <p className="mt-2 text-sm font-semibold" style={{ color: r.color }}>{r.price}</p>
                </div>
              </div>
            ))}
          </div>

          <div className="mt-8 grid gap-2 md:mt-10 md:grid-cols-4 md:gap-3">
            {products.map((p) => (
              <Link
                key={p.name}
                href={p.href}
                className={`flex items-center gap-3 rounded-[20px] p-3 transition hover:-translate-y-0.5 md:flex-col md:items-start md:rounded-[22px] md:p-6 ${p.dark ? "bg-[#231715] text-white" : "border border-[#F3D2C8] bg-white text-[#231715]"}`}
              >
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={p.logo} alt="" width={44} height={44} className="h-10 w-10 shrink-0 md:h-11 md:w-11" />
                <span className="min-w-0 flex-1 md:flex md:flex-1 md:flex-col">
                  <span className={`block font-display text-base font-bold md:mt-3 ${p.dark ? "text-[#FFD34D]" : ""}`}>{p.name}</span>
                  <span className={`block text-[11px] font-semibold uppercase tracking-wider ${p.dark ? "text-[#FDF8F7]" : "text-[#6E4F48]"}`}>{p.title}</span>
                  <span className={`mt-2 hidden text-sm leading-relaxed md:block ${p.dark ? "text-[#FDF8F7]" : "text-[#6E4F48]"}`}>{p.body}</span>
                  <span className={`mt-auto hidden items-center gap-1 pt-3 text-sm font-semibold md:inline-flex ${p.dark ? "text-[#FFD34D]" : "text-owner"}`}>
                    {p.cta} <AppIcon name="arrow-right" size={14} />
                  </span>
                </span>
                <AppIcon name="arrow-right" size={18} color={p.dark ? "#FFD34D" : "#C92A12"} className="shrink-0 md:hidden" />
              </Link>
            ))}
          </div>
        </div>
      </section>

      {/* ── 6. VIDÉO ── */}
      <section className="bg-white py-10 md:py-16"><div className="mx-auto max-w-4xl px-4">
        <Ornament />
        <h2 className="text-balance text-center font-display text-2xl font-bold tracking-[-0.02em] text-[#231715] md:text-4xl">
          {t("video_title")}
        </h2>
        <div className="mt-6 overflow-hidden rounded-[24px] bg-black shadow-[0_0_0_2px_#1C1917,0_30px_60px_-30px_rgba(35,23,21,0.5)] md:mt-8">
          <video controls playsInline preload="metadata" poster="/videos/hopetsit_presentation_poster.jpg" className="block h-auto w-full">
            <source src="/videos/hopetsit_presentation.mp4" type="video/mp4" />
          </video>
        </div>
      </div></section>

      {/* ── 8. VILLES ── v562 (Search Console 17/09) : liens directs vers les
          pages Paris / Île-de-France et USA (exploration Google). Rendu dans les
          deux langues quel que soit le choix de l'utilisateur. Contenu inchangé.
          13/10 (GUS) : + 9 villes US déjà en ligne, celles qui ont le plus
          d'affichages Google sans clic (positions 14-21 sur « dog sitting <ville> ») :
          un lien depuis l'accueil, la page la plus forte du site. Aucune page créée.
          10/11 (LEO) : mêmes liens, mêmes textes en français (et la colonne États-Unis toujours en anglais
          pour un visiteur français) ; les 7 autres langues lisent enfin ces deux colonnes dans la leur. */}
      <section className="py-10 md:py-14">
        <div className="mx-auto grid max-w-5xl gap-4 px-4 md:grid-cols-2 md:gap-5">
          <div className="rounded-[24px] border border-[#F3D2C8] bg-white p-5 md:p-7">
            <h2 className="font-display text-xl font-bold tracking-[-0.02em] text-[#231715] md:text-2xl">{a1011(lang, "cities_fr_title")}</h2>
            {/* 30/10 (GUS) — Search Console 7 j : « dog sitter paris » (50 affichages, 14e),
                « pet sitter paris » (48, 17e), « pet sitting paris », « petsitter paris » → 0 clic ;
                la page /garde-animaux/paris n'était reliée depuis l'accueil que par le pied de
                page. Un lien en clair, avec les mots tapés, depuis la page la plus forte du site. */}
            <p className="mt-3 text-sm"><Link href="/garde-animaux/paris" className={textLink}>{a1011(lang, "cities_fr_link")} →</Link></p>
            <ul className="mt-3 flex flex-wrap gap-1.5 text-sm">
              {Array.from({ length: 20 }, (_, i) => i + 1).map((n) => (
                <li key={`p${n}`}><Link href={`/garde-animaux/paris-${n}`} className={chip}>{lang === "fr" ? `Paris ${n}${n === 1 ? "er" : "e"}` : a1011(lang, "paris_n", { n })}</Link></li>
              ))}
              {[["boulogne-billancourt","Boulogne"],["neuilly-sur-seine","Neuilly"],["levallois-perret","Levallois"],["issy-les-moulineaux","Issy"],["vincennes","Vincennes"],["montreuil","Montreuil"],["versailles","Versailles"]].map(([slug, name]) => (
                <li key={slug}><Link href={`/garde-animaux/${slug}`} className={chip}>{name}</Link></li>
              ))}
            </ul>
            <p className="mt-3 text-sm"><Link href="/devenir-petsitter/paris" className={textLink}>{a1011(lang, "cities_fr_become")} →</Link></p>
          </div>
          <div className="rounded-[24px] border border-[#F3D2C8] bg-white p-5 md:p-7">
            <h2 className="font-display text-xl font-bold tracking-[-0.02em] text-[#231715] md:text-2xl">{a1011(usLang, "cities_us_title")}</h2>
            <ul className="mt-3 flex flex-wrap gap-1.5 text-sm">
              {[["dallas","Dallas"],["fort-worth","Fort Worth"],["plano","Plano"],["frisco","Frisco"],["houston","Houston"],["austin","Austin"],["new-york","New York"],["los-angeles","Los Angeles"],["chicago","Chicago"],["miami","Miami"],["san-francisco","San Francisco"],["seattle","Seattle"],["boston","Boston"],["atlanta","Atlanta"],["denver","Denver"],["phoenix","Phoenix"],["indianapolis","Indianapolis"],["cincinnati","Cincinnati"],["minneapolis","Minneapolis"],["columbus","Columbus"],["detroit","Detroit"],["arlington-tx","Arlington, TX"],["decatur-ga","Decatur, GA"],["naples-fl","Naples, FL"],["honolulu","Honolulu"]].map(([slug, name]) => (
                <li key={slug}><Link href={`/pet-sitting/${slug}`} className={chip}>{name}</Link></li>
              ))}
            </ul>
            {/* 16/10 (SAM, §B.6 build 617) — Dallas gratuit : le guide des prix
                (article déjà en ligne) relié depuis l'accueil. Aucune page créée. */}
            <p className="mt-3 text-sm"><Link href="/blog/how-much-does-a-pet-sitter-cost-in-dallas" className={textLink}>{a1011(usLang, "cities_us_price")} →</Link></p>
            {/* 25/10 (GUS) — Search Console 28 j USA : « cat sitting » 574 affichages,
                0 clic, 20e place sur /blog/what-is-cat-sitting ; « dog sitter » 20e-30e sur les
                pages villes ; Austin 561 affichages. Les 3 guides propriétaires déjà en ligne,
                reliés depuis l'accueil (page la plus forte). Aucune page créée. */}
            <p className="mt-2 flex flex-wrap items-center gap-x-2 text-sm text-[#6E4F48]">
              <span>{a1011(usLang, "cities_guides_label")}</span>
              <Link href="/blog/what-is-cat-sitting" className={textLink}>{a1011(usLang, "cities_guide_cat")}</Link>
              <span aria-hidden="true">·</span>
              <Link href="/blog/what-is-dog-sitting" className={textLink}>{a1011(usLang, "cities_guide_dog")}</Link>
              <span aria-hidden="true">·</span>
              <Link href="/blog/finding-a-pet-sitter-in-austin" className={textLink}>{a1011(usLang, "cities_guide_austin")}</Link>
            </p>
            <p className="mt-2 flex flex-wrap items-center gap-x-2 text-sm">
              <Link href="/become-a-pet-sitter/dallas" className={textLink}>{a1011(usLang, "cities_us_become")} →</Link>
              <span aria-hidden="true" className="text-[#6E4F48]">·</span>
              <Link href="/villes" className="text-[#6E4F48] hover:underline max-lg:inline-flex max-lg:min-h-[44px] max-lg:items-center">{a1011(usLang, "cities_all")}</Link>
            </p>
          </div>
        </div>
      </section>

      {/* ── 9. FAQ ── 4 questions, le reste sur /faq. */}
      <section className="bg-white py-10 md:py-16"><div className="mx-auto max-w-3xl px-4">
        <Ornament />
        <h2 className="text-balance text-center font-display text-2xl font-bold tracking-[-0.02em] text-[#231715] md:text-4xl">
          {t("faq_title")}
        </h2>
        <div className="mt-8 space-y-2.5">
          {faq.map((f, i) => (
            <details key={f.q} className="group rounded-[18px] border border-[#F3D2C8] bg-[#FFF7F3] px-4 py-2 open:bg-white md:px-5" open={i === 0}>
              <summary className="flex min-h-[48px] cursor-pointer list-none items-center justify-between gap-4 text-[16px] font-semibold text-[#231715] [&::-webkit-details-marker]:hidden">
                {f.q}
                <span className="grid h-8 w-8 shrink-0 place-items-center rounded-[10px] bg-owner-light text-lg font-bold leading-none text-owner"><span className="block transition group-open:rotate-45">+</span></span>
              </summary>
              <p className="pb-3 pt-1 text-[15px] leading-relaxed text-[#6E4F48]">{f.a}</p>
            </details>
          ))}
        </div>
        <p className="mt-4 text-center text-sm"><Link href="/faq" className={textLink}>{t("home_faq_more")} →</Link></p>
      </div></section>

      {/* ── 10. APPEL FINAL ── 17/11 : pour le propriétaire d'abord (« Publier ma demande », qui ramène au
           formulaire), bouton secondaire pour les gardiens. Plus de « gagnent dès le premier jour » (promesse de
           revenus interdite) ; le lien vers l'app est dans le bloc des captures et le pied de page. */}
      <section className="px-4 pb-12 pt-10 md:pb-20 md:pt-16" data-home-final-1011="" data-home-final-1711="">
        <div className="mx-auto max-w-5xl overflow-hidden rounded-[28px] px-5 py-10 text-center md:px-10 md:py-16" style={{ background: `${PAWS_TILE_BAND}, ${GRAD}` }}>
          <h2 className="text-balance font-display text-3xl font-bold tracking-[-0.02em] text-white md:text-5xl">{a1711(lang, "final_title")}</h2>
          <p className="mx-auto mt-4 max-w-2xl text-balance text-base text-[#FFF3EC] md:text-lg">{a1711(lang, "final_sub")}</p>
          <div className="mx-auto mt-7 grid max-w-xl gap-3 sm:grid-cols-2">
            <button type="button" onClick={() => { trackSiteEvent("cta_click", { label: "home_final_publier" }); goToForm(); }} className="inline-flex min-h-[56px] items-center justify-center gap-2 rounded-[18px] bg-white px-5 text-[15px] font-bold leading-tight text-owner-dark transition hover:bg-[#FFF3EC]">
              <AppIcon name="megaphone" size={18} color="#9E1F0B" className="shrink-0" />{a1011(lang, "f_cta")}
            </button>
            <Link href={sitterHref} onClick={() => trackSiteEvent("cta_click", { label: "home_final_gardien" })} className="inline-flex min-h-[56px] items-center justify-center gap-2 rounded-[18px] border-[1.5px] border-white px-5 py-2 text-center text-[15px] font-bold leading-tight text-white transition hover:bg-[#B5230F]">
              <AppIcon name="home" size={18} color="#fff" className="shrink-0" /><span className="min-w-0 text-balance">{a1711(lang, "sitter_cta")}</span>
            </Link>
          </div>
        </div>
      </section>
    </div>
  );
}
