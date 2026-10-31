"use client";

import { useState, type MouseEvent } from "react";
import Link from "@/components/SiteLink";
import { trackSiteEvent } from "@/components/SiteAnalytics";
import { EstimateLine620 } from "@/components/DateMode620";
import { ApiError, publishSiteLead } from "@/lib/api";

// 12/10/2026 (SAM) — le PREMIER ÉCRAN de la page où arrive la pub EST le formulaire (956 arrivées →
// 8 clics sur un bouton seul : 99 % ne cliquaient jamais).
// 31/10/2026 (LEO, feu vert BOB 14 h 20, ordre de Daniel « paiement plus simple ») — UNE SEULE ÉTAPE :
// service · dates (ou « dates à prévoir ») · code postal · prénom · e-mail · animal → « Publier ma
// demande — gratuit » → POST /ad-leads/site (compte propriétaire créé sans mot de passe, demande
// publiée, gardiens prévenus, e-mail « ta demande est en ligne ») → écran « Ta demande est en ligne »
// sur place, rien d'autre à faire (pas d'app imposée). Avant : « Continuer » → /posts/create?etape=2
// (compte invité + « Publier ») — mesure de BOB du 31/10 : 0 paiement, tout se joue sur le site.
// Au « tu » (décision BOB 31/10), promesse de la pub v8 (SAM_vers_LEO_3110.md). Paris FR + New York EN.
// Mesure (repères conservés) : « hero_form_touche » (1er vrai tap), « hero_form_service » (1er service),
// « signup_web_hero » (bouton), + « hero_form_envoye » (demande publiée), « hero_form_refus_<code> ».
// Tous les hooks AVANT tout retour (règle de l'équipe).

type Lang = "fr" | "en";
const SERVICES: { id: "garde" | "promenade" | "visites"; svc: string; icon: string; fr: string; en: string }[] = [
  { id: "garde", svc: "house_sitting", icon: "🏠", fr: "Garde", en: "Pet sitting" },
  { id: "promenade", svc: "dog_walking", icon: "🐕", fr: "Promenade", en: "Dog walking" },
  { id: "visites", svc: "home_visit", icon: "🔑", fr: "Visites chez moi", en: "Drop-in visits" },
];
const ANIMALS: { id: "chien" | "chat" | "autre"; fr: string; en: string }[] = [
  { id: "chien", fr: "Chien", en: "Dog" }, { id: "chat", fr: "Chat", en: "Cat" }, { id: "autre", fr: "Autre", en: "Other" },
];
const TXT = {
  fr: {
    from: "Du", to: "Au", dates_hint: "Pas encore de dates ? Laisse vide : tu les poseras ensuite.",
    postal: "Code postal", first: "Prénom", email: "E-mail", animal: "Animal",
    cta: "Publier ma demande — gratuit", busy: "Publication…",
    need_service: "Choisis un service.", need_place: "Indique ton code postal.", need_email: "Indique un e-mail valide : c'est là que les candidats arrivent, avec leur prix.",
    err: "La publication n'a pas abouti. Réessaie dans un instant.", err_test: "Cette adresse est réservée aux tests.", err_many: "Trop d'envois. Réessaie dans quelques minutes.",
    done_title: "Ta demande est en ligne.",
    done_body: "Tu reçois les candidats avec leur prix par e-mail — tu choisis, tu paies, annulation gratuite jusqu'à 72 h avant.",
    done_notified: (n: number) => (n > 0 ? `${n} gardien${n > 1 ? "s" : ""} et promeneur${n > 1 ? "s" : ""} près de chez toi ${n > 1 ? "sont prévenus" : "est prévenu"}.` : "Les gardiens et promeneurs près de chez toi sont prévenus."),
    done_existing: "Ta demande était déjà en ligne : la voici.",
    done_link: "Voir ma demande", done_mail: "Un e-mail te permet de revenir ici sans mot de passe.",
    terms: "En publiant, tu acceptes les", terms_link: "conditions d'utilisation",
  },
  en: {
    from: "From", to: "To", dates_hint: "No dates yet? Leave empty: you'll set them later.",
    postal: "ZIP code", first: "First name", email: "Email", animal: "Pet",
    cta: "Post my request — free", busy: "Posting…",
    need_service: "Pick a service.", need_place: "Enter your ZIP code.", need_email: "Enter a valid email: that's where candidates arrive, with their price.",
    err: "Posting didn't go through. Try again in a moment.", err_test: "This address is reserved for tests.", err_many: "Too many attempts. Try again in a few minutes.",
    done_title: "Your request is live.",
    done_body: "You get the candidates with their price by email — you choose, you pay, free cancellation up to 72 h before.",
    done_notified: (n: number) => (n > 0 ? `${n} sitter${n > 1 ? "s" : ""} and walker${n > 1 ? "s" : ""} near you ${n > 1 ? "have" : "has"} been notified.` : "Sitters and walkers near you have been notified."),
    done_existing: "Your request was already live: here it is.",
    done_link: "See my request", done_mail: "An email lets you come back here without a password.",
    terms: "By posting, you accept the", terms_link: "terms of use",
  },
};

export function ParisHeroForm({ city, lead, note, lang = "fr", country = "FR", campaign = "paris_owners", page = "/garde-animaux/paris" }: {
  city: string; lead: string; note: string; lang?: Lang; country?: string; campaign?: string; page?: string;
}) {
  const t = TXT[lang];
  const [service, setService] = useState<"" | "garde" | "promenade" | "visites">("");
  const [animal, setAnimal] = useState<"chien" | "chat" | "autre">("chien");
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [postalCode, setPostalCode] = useState("");
  const [firstName, setFirstName] = useState("");
  const [email, setEmail] = useState("");
  const [website, setWebsite] = useState(""); // champ piège : jamais affiché
  const [err, setErr] = useState("");
  const [busy, setBusy] = useState(false);
  const [started, setStarted] = useState(false);
  const [touched, setTouched] = useState(false);
  const [done, setDone] = useState<{ notified?: number; existing: boolean } | null>(null);

  // 27/10 (SAM) : seulement un VRAI tap (clic de confiance, page visible) — un focus() automatique
  // (robot, préchargement, remplissage auto) comptait une touche.
  function touch(e: MouseEvent) {
    if (touched || !e.nativeEvent.isTrusted || document.visibilityState !== "visible") return;
    setTouched(true);
    trackSiteEvent("cta_click", { label: "hero_form_touche" });
  }
  function pick(id: "garde" | "promenade" | "visites") {
    setErr("");
    setService((cur) => (cur === id ? "" : id));
    if (!started) { setStarted(true); trackSiteEvent("cta_click", { label: "hero_form_service" }); }
  }

  async function submit() {
    setErr("");
    if (!service) { trackSiteEvent("cta_click", { label: "hero_form_sans_service" }); return setErr(t.need_service); }
    if (!postalCode.trim()) { trackSiteEvent("cta_click", { label: "hero_form_sans_lieu" }); return setErr(t.need_place); }
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.trim())) { trackSiteEvent("cta_click", { label: "hero_form_sans_email" }); return setErr(t.need_email); }
    trackSiteEvent("cta_click", { label: "signup_web_hero" });
    setBusy(true);
    try {
      const r = await publishSiteLead({
        email: email.trim(), firstName: firstName.trim(), service, animal, postalCode: postalCode.trim(), city, country, lang,
        startDate: startDate || undefined, endDate: endDate || startDate || undefined, campaign, page, website,
      });
      trackSiteEvent("cta_click", { label: r.existing ? "hero_form_deja" : "hero_form_envoye" });
      setDone({ notified: r.notified, existing: r.existing });
    } catch (e) {
      const code = e instanceof ApiError && e.details && typeof e.details === "object" ? String((e.details as { code?: string }).code || "") : "";
      trackSiteEvent("cta_click", { label: `hero_form_refus_${(code || (e instanceof ApiError ? e.status : "x")).toString().toLowerCase()}` });
      setErr(code === "TEST_ACCOUNT" ? t.err_test : code === "TOO_MANY" ? t.err_many : code === "EMAIL_INVALID" ? t.need_email : t.err);
    } finally {
      setBusy(false);
    }
  }

  const field = "mt-1 w-full rounded-xl border border-ink/15 bg-white px-3 py-2.5 text-[15px] text-ink focus:border-owner focus:outline-none";
  const svcId = SERVICES.find((s) => s.id === service)?.svc || "";

  if (done) {
    return (
      <div className="mt-3 rounded-3xl bg-white p-5 text-center md:mx-auto md:max-w-md" style={{ boxShadow: "0 0 0 2px #15803D, 0 14px 30px -18px rgba(35,23,21,.5)" }} data-testid="hero-done" data-hero-done-3110="">
        <p className="text-[22px] font-extrabold leading-tight" style={{ color: "#15803D" }}>✓ {t.done_title}</p>
        <p className="mt-2 text-[15px] font-semibold leading-snug text-ink">{done.existing ? t.done_existing : t.done_notified(done.notified ?? 0)}</p>
        <p className="mt-2 text-[14px] leading-snug text-ink">{t.done_body}</p>
        <Link href="/posts" className="mt-4 inline-block rounded-full bg-owner px-6 py-3.5 text-[16px] font-extrabold text-white shadow-card" onClick={() => trackSiteEvent("cta_click", { label: "hero_form_voir" })}>
          {t.done_link} →
        </Link>
        <p className="mt-3 text-xs text-ink-soft">{t.done_mail}</p>
      </div>
    );
  }

  return (
    <div className="mt-3 rounded-3xl border border-owner/20 bg-owner-light/60 p-4 md:mx-auto md:max-w-md" data-testid="hero-form" data-hero-form-3110={lang} onClickCapture={touch}>
      <p className="text-[15px] font-semibold leading-snug text-ink md:text-base">{lead}</p>

      <div className="mt-3 grid grid-cols-3 gap-2" role="group" aria-label="Service">
        {SERVICES.map((s) => (
          <button key={s.id} type="button" onClick={() => pick(s.id)} aria-pressed={service === s.id}
            className={`min-h-[56px] rounded-2xl border px-1.5 py-2 text-center text-[12px] font-bold leading-tight transition ${service === s.id ? "border-owner bg-owner text-white shadow-card" : "border-ink/10 bg-white text-ink"}`}>
            <span aria-hidden className="block text-base leading-none">{s.icon}</span>
            <span className="mt-1 block">{s[lang]}</span>
          </button>
        ))}
      </div>

      <div className="mt-3 grid grid-cols-2 gap-2">
        <label className="block text-xs font-semibold text-ink">{t.from}
          <input type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} className={field} data-testid="hero-start" />
        </label>
        <label className="block text-xs font-semibold text-ink">{t.to}
          <input type="date" value={endDate} onChange={(e) => setEndDate(e.target.value)} className={field} data-testid="hero-end" />
        </label>
      </div>
      <p className="mt-1 text-[11px] text-ink-soft">{t.dates_hint}</p>

      {svcId && (
        <div className="mt-3">
          <EstimateLine620 lang={lang} service={svcId} dateMode={startDate && endDate ? "exact" : "tbd"} startDate={startDate} endDate={endDate}
            visitsPerDay={1} venue={svcId === "house_sitting" ? "owners_home" : null} currency={country === "US" ? "USD" : "EUR"} location={{ city }} />
        </div>
      )}

      <div className="mt-3 grid grid-cols-2 gap-2">
        <label className="block text-xs font-semibold text-ink">{t.postal}
          <input value={postalCode} onChange={(e) => setPostalCode(e.target.value)} inputMode="numeric" autoComplete="postal-code" maxLength={12} className={field} data-testid="hero-postal" />
        </label>
        <label className="block text-xs font-semibold text-ink">{t.first}
          <input value={firstName} onChange={(e) => setFirstName(e.target.value)} autoComplete="given-name" maxLength={60} className={field} data-testid="hero-first" />
        </label>
      </div>
      <label className="mt-2 block text-xs font-semibold text-ink">{t.email}
        <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} autoComplete="email" inputMode="email" maxLength={120} className={field} data-testid="hero-email"
          onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); void submit(); } }} />
      </label>
      <div className="mt-2 flex items-center gap-2" role="group" aria-label={t.animal}>
        <span className="text-xs font-semibold text-ink">{t.animal}</span>
        {ANIMALS.map((a) => (
          <button key={a.id} type="button" onClick={() => setAnimal(a.id)} aria-pressed={animal === a.id}
            className={`min-h-[36px] rounded-full border px-3 text-[12px] font-bold ${animal === a.id ? "border-owner bg-owner text-white" : "border-ink/10 bg-white text-ink"}`}>
            {a[lang]}
          </button>
        ))}
      </div>
      {/* Champ piège anti-robot : invisible, jamais rempli par une personne. */}
      <div aria-hidden className="absolute h-0 w-0 overflow-hidden opacity-0" style={{ position: "absolute", left: -9999 }}>
        <label>Website<input tabIndex={-1} autoComplete="off" value={website} onChange={(e) => setWebsite(e.target.value)} name="website" /></label>
      </div>

      {err && <p className="mt-2 text-center text-sm font-semibold text-owner-dark" role="alert">{err}</p>}

      <button id="hero-publier" type="button" onClick={() => void submit()} disabled={busy} data-testid="hero-continuer"
        className="mt-3 block w-full rounded-full bg-owner px-6 py-4 text-center text-lg font-extrabold text-white shadow-card disabled:opacity-70">
        {busy ? t.busy : t.cta}
      </button>
      <p className="mt-2 text-center text-xs text-ink-soft">{note}</p>
      <p className="mt-1 text-center text-[11px] text-ink-soft">{t.terms} <Link href={lang === "fr" ? "/cgu" : "/terms"} className="underline">{t.terms_link}</Link>.</p>
    </div>
  );
}

export default ParisHeroForm;
