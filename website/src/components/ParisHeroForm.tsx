"use client";

import { useEffect, useRef, useState, type MouseEvent } from "react";
import Link from "@/components/SiteLink";
import { trackSiteEvent } from "@/components/SiteAnalytics";
import { EstimateLine620 } from "@/components/DateMode620";
import { ApiError, publishSiteLead } from "@/lib/api";
import { PlaceMapConfirm3110, PlacePicker3110, type PlacePick } from "@/components/PlacePicker3110";

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
    postal: "Code postal", first: "Prénom", email: "E-mail", animal: "Animal", city: "Ville",
    cta: "Publier ma demande", busy: "Publication…",
    need_service: "Choisis un service.", need_place: "Choisis ta ville dans la liste ou indique ton code postal.", need_email: "Indique un e-mail valide : c'est là que les candidats arrivent, avec leur prix.",
    err: "La publication n'a pas abouti. Réessaie dans un instant.", err_test: "Cette adresse est réservée aux tests.", err_many: "Trop d'envois. Réessaie dans quelques minutes.",
    done_title: "Ta demande est en ligne.",
    done_body: "Tu reçois les candidats avec leur prix par e-mail — tu choisis, tu paies, annulation gratuite jusqu'à 72 h avant.",
    done_notified: (n: number) => (n > 0 ? `${n} gardien${n > 1 ? "s" : ""} et promeneur${n > 1 ? "s" : ""} près de chez toi ${n > 1 ? "sont prévenus" : "est prévenu"}.` : "Les gardiens et promeneurs près de chez toi sont prévenus."),
    done_existing: "Ta demande était déjà en ligne : la voici.",
    done_link: "Voir ma demande", done_mail: "Un e-mail te permet de revenir ici sans mot de passe.",
    done_by_email: "Cette adresse a déjà un compte HoPetSit. Pour ouvrir ta demande, clique sur le lien de l'e-mail « ta demande est en ligne » (il ouvre ton espace sans mot de passe), ou connecte-toi.",
    done_login: "Me connecter",
    target_note: "Ta demande sera envoyée d'abord à ce gardien, puis aux autres près de chez toi.",
    terms: "En publiant, tu acceptes les", terms_link: "conditions d'utilisation",
  },
  en: {
    from: "From", to: "To", dates_hint: "No dates yet? Leave empty: you'll set them later.",
    postal: "ZIP code", first: "First name", email: "Email", animal: "Pet", city: "City",
    cta: "Post my request", busy: "Posting…",
    need_service: "Pick a service.", need_place: "Pick your city from the list or enter your ZIP code.", need_email: "Enter a valid email: that's where candidates arrive, with their price.",
    err: "Posting didn't go through. Try again in a moment.", err_test: "This address is reserved for tests.", err_many: "Too many attempts. Try again in a few minutes.",
    done_title: "Your request is live.",
    done_body: "You get the candidates with their price by email — you choose, you pay, free cancellation up to 72 h before.",
    done_notified: (n: number) => (n > 0 ? `${n} sitter${n > 1 ? "s" : ""} and walker${n > 1 ? "s" : ""} near you ${n > 1 ? "have" : "has"} been notified.` : "Sitters and walkers near you have been notified."),
    done_existing: "Your request was already live: here it is.",
    done_link: "See my request", done_mail: "An email lets you come back here without a password.",
    done_by_email: "This address already has a HoPetSit account. To open your request, click the link in the “your request is live” email (it opens your space without a password), or sign in.",
    done_login: "Sign in",
    target_note: "Your request goes to this sitter first, then to the others near you.",
    terms: "By posting, you accept the", terms_link: "terms of use",
  },
};

export function ParisHeroForm({ city, lead, note, lang = "fr", country = "FR", campaign = "paris_owners", page = "/garde-animaux/paris", cityEditable = false }: {
  city: string; lead: string; note: string; lang?: Lang; country?: string; campaign?: string; page?: string;
  /** 31/10 (accueil, décision BOB) — la ville se saisit (Paris / New York proposées par défaut). */
  cityEditable?: boolean;
}) {
  const t = TXT[lang];
  const [cityValue, setCityValue] = useState(city);
  // 31/10 (Daniel) — position choisie sur la carte (ville de la liste + épingle déplaçable).
  const [place, setPlace] = useState<PlacePick | null>(null);
  const [target, setTarget] = useState<{ role: "sitter" | "walker"; id: string } | null>(null);
  // La langue (donc la ville proposée) peut arriver après le premier rendu : on suit la prop.
  useEffect(() => { setCityValue(city); }, [city]);
  // 31/10 — accueil : « Réserver <prénom> » (profil public, épingle) arrive avec ?for=<rôle>:<id>&city=&service= :
  // ville, service et prestataire ciblé pré-remplis (le serveur le prévient en premier).
  useEffect(() => {
    if (!cityEditable) return;
    try {
      const q = new URLSearchParams(window.location.search);
      const m = /^(sitter|walker):([a-f0-9]{24})$/i.exec(q.get("for") || "");
      if (m) setTarget({ role: m[1].toLowerCase() as "sitter" | "walker", id: m[2] });
      const c = (q.get("city") || "").trim().slice(0, 80);
      if (c) setCityValue(c);
      const sv = q.get("service") || "";
      if (sv === "garde" || sv === "promenade" || sv === "visites") setService(sv);
      else if (m && m[1].toLowerCase() === "walker") setService("promenade");
    } catch { /* adresse exotique */ }
  }, [cityEditable]);
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
  const [done, setDone] = useState<{ notified?: number; existing: boolean; sessionOpened: boolean } | null>(null);
  // 31/10 16 h 40 (ZOE, mesuré à 375 px) : après « Publier ma demande » (bouton en bas du formulaire), la carte
  // « Ta demande est en ligne » remplaçait un bloc plus haut et finissait HORS ÉCRAN (haut à −280 px) : la personne
  // ne voyait que les badges des stores. On la ramène sous l'en-tête.
  const doneRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!done || !doneRef.current) return;
    try { doneRef.current.scrollIntoView({ block: "start", behavior: "smooth" }); } catch { /* vieux navigateur */ }
  }, [done]);

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
    if (!postalCode.trim() && !place) { trackSiteEvent("cta_click", { label: "hero_form_sans_lieu" }); return setErr(t.need_place); }
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.trim())) { trackSiteEvent("cta_click", { label: "hero_form_sans_email" }); return setErr(t.need_email); }
    trackSiteEvent("cta_click", { label: "signup_web_hero" });
    setBusy(true);
    try {
      const r = await publishSiteLead({
        email: email.trim(), firstName: firstName.trim(), service, animal, postalCode: postalCode.trim(), city: (place ? place.city : cityValue.trim()) || city,
        country: (place && place.countryCode) || country, lang,
        ...(place ? { lat: place.lat, lng: place.lng } : {}),
        startDate: startDate || undefined, endDate: endDate || startDate || undefined, campaign, page, website,
        ...(target ? { targetProvider: target } : {}),
      });
      trackSiteEvent("cta_click", { label: r.existing ? "hero_form_deja" : "hero_form_envoye" });
      setDone({ notified: r.notified, existing: r.existing, sessionOpened: r.sessionOpened });
    } catch (e) {
      const code = e instanceof ApiError && e.details && typeof e.details === "object" ? String((e.details as { code?: string }).code || "") : "";
      trackSiteEvent("cta_click", { label: `hero_form_refus_${(code || (e instanceof ApiError ? e.status : "x")).toString().toLowerCase()}` });
      setErr(code === "TEST_ACCOUNT" ? t.err_test : code === "TOO_MANY" ? t.err_many : code === "EMAIL_INVALID" ? t.need_email : t.err);
    } finally {
      setBusy(false);
    }
  }

  const bias = country === "US" ? { lat: 40.7128, lng: -74.006 } : country === "FR" ? { lat: 48.8566, lng: 2.3522 } : null;
  const field = "mt-1 w-full rounded-xl border border-ink/15 bg-white px-3 py-2.5 text-[15px] text-ink focus:border-owner focus:outline-none";
  const svcId = SERVICES.find((s) => s.id === service)?.svc || "";

  if (done) {
    return (
      <div ref={doneRef} className="mt-3 scroll-mt-24 rounded-3xl bg-white p-5 text-center md:mx-auto md:max-w-md" style={{ boxShadow: "0 0 0 2px #15803D, 0 14px 30px -18px rgba(35,23,21,.5)" }} data-testid="hero-done" data-hero-done-3110="">
        <p className="text-[22px] font-extrabold leading-tight" style={{ color: "#15803D" }}>✓ {t.done_title}</p>
        <p className="mt-2 text-[15px] font-semibold leading-snug text-ink">{done.existing ? t.done_existing : t.done_notified(done.notified ?? 0)}</p>
        <p className="mt-2 text-[14px] leading-snug text-ink">{t.done_body}</p>
        {done.sessionOpened ? (
          <>
            <Link href="/posts" className="mt-4 inline-block rounded-full bg-owner px-6 py-3.5 text-[16px] font-extrabold text-white shadow-card" onClick={() => trackSiteEvent("cta_click", { label: "hero_form_voir" })}>
              {t.done_link} →
            </Link>
            <p className="mt-3 text-xs text-ink-soft">{t.done_mail}</p>
          </>
        ) : (
          // 31/10 16 h 40 (ZOE) — compte déjà existant : pas de session ouverte ici (une adresse e-mail seule ne prouve
          // rien) ; la personne passe par le lien de l'e-mail ou par la connexion.
          <>
            <p className="mt-3 text-[13px] leading-snug text-ink" data-hero-done-email="">{t.done_by_email}</p>
            <Link href="/login?redirect=%2Fposts" className="mt-4 inline-block rounded-full border-2 border-owner px-6 py-3 text-[15px] font-extrabold text-owner" onClick={() => trackSiteEvent("cta_click", { label: "hero_form_login" })}>
              {t.done_login} →
            </Link>
          </>
        )}
      </div>
    );
  }

  return (
    <div className="mt-2 rounded-3xl border border-owner/20 bg-owner-light/60 p-4 md:mx-auto md:max-w-md" data-testid="hero-form" data-hero-form-3110={lang} onClickCapture={touch}>
      <p className="text-[15px] font-semibold leading-snug text-ink md:text-base">{lead}</p>
      {target && <p className="mt-1.5 rounded-xl bg-white px-3 py-1.5 text-[12px] font-bold" style={{ color: "#1E4FB0" }} data-hero-target={target.role}>{t.target_note}</p>}

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
            visitsPerDay={1} venue={svcId === "house_sitting" ? "owners_home" : null} currency={country === "US" ? "USD" : "EUR"} location={{ city: place ? place.city : (cityEditable ? cityValue : city) }} />
        </div>
      )}

      {/* Ville (liste + carte) et code postal sur une rangée, prénom et e-mail sur la suivante : le bouton reste
          dans le premier écran à 375 px même avec le champ Ville en plus. */}
      <div className="mt-3 grid grid-cols-[1.4fr_1fr] gap-2">
        <PlacePicker3110 lang={lang} value={cityValue} onChange={setCityValue} pick={place} setPick={(p) => { setPlace(p); trackSiteEvent("cta_click", { label: p ? "hero_form_carte" : "hero_form_carte_off" }); }} inputClass={field} bias={bias} />
        <label className="block text-xs font-semibold text-ink">{t.postal}
          <input value={postalCode} onChange={(e) => setPostalCode(e.target.value)} inputMode="numeric" autoComplete="postal-code" maxLength={12} className={field} data-testid="hero-postal" />
        </label>
      </div>
      <PlaceMapConfirm3110 lang={lang} pick={place} setPick={(p) => setPlace(p)} />
      <div className="mt-2 grid grid-cols-[1fr_1.4fr] gap-2">
        <label className="block text-xs font-semibold text-ink">{t.first}
          <input value={firstName} onChange={(e) => setFirstName(e.target.value)} autoComplete="given-name" maxLength={60} className={field} data-testid="hero-first" />
        </label>
        <label className="block text-xs font-semibold text-ink">{t.email}
          <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} autoComplete="email" inputMode="email" maxLength={120} className={field} data-testid="hero-email"
            onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); void submit(); } }} />
        </label>
      </div>
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
