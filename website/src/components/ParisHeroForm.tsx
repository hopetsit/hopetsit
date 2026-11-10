"use client";

import { useEffect, useRef, useState, type MouseEvent } from "react";
import Link from "@/components/SiteLink";
import { trackSiteEvent } from "@/components/SiteAnalytics";
import { EstimateLine620 } from "@/components/DateMode620";
import { ApiError, publishSiteLead } from "@/lib/api";
import { PlaceMapConfirm3110, PlacePicker3110, type PlacePick } from "@/components/PlacePicker3110";
// 06/11/2026 (NEO, ordre de Daniel « dates obligatoires ») — plus de « laisse vide » : dates de début et de fin
// obligatoires (balade : la date), même refus côté serveur (400 DATES_REQUIRED). Mesure de FLO (14 j) : 19 demandes
// sur 45 avec candidats « à prévoir » → aucun prix total, jamais de bouton « Payer », 0 paiement.
import { dr } from "@/lib/i18n/datesRequired0611";
import { f2 } from "@/lib/i18n/formulaire2etapes1110";
import { d620 } from "@/lib/i18n/dates620";
import { c2610 } from "@/lib/i18n/cand2610";
// 10/11/2026 (LEO, ordre de Daniel « les pages ne sont pas à jour dans les autres langues ») — types seulement
// (effacés à la compilation : aucun octet de plus pour les pages qui n'utilisent pas `ui`).
import type { HeroUi1011 } from "@/lib/i18n/accueil1011";
import type { Lang as UiLang } from "@/lib/i18n/langs";

// 12/10/2026 (SAM) — le PREMIER ÉCRAN de la page où arrive la pub EST le formulaire (956 arrivées →
// 8 clics sur un bouton seul : 99 % ne cliquaient jamais).
// 31/10/2026 (LEO, feu vert BOB 14 h 20, ordre de Daniel « paiement plus simple ») — UNE SEULE ÉTAPE :
// service · dates (OBLIGATOIRES depuis le 06/11, NEO) · code postal · prénom · e-mail · animal → « Publier ma
// demande — gratuit » → POST /ad-leads/site (compte propriétaire créé sans mot de passe, demande
// publiée, gardiens prévenus, e-mail « ta demande est en ligne ») → écran « Ta demande est en ligne »
// sur place, rien d'autre à faire (pas d'app imposée). Avant : « Continuer » → /posts/create?etape=2
// (compte invité + « Publier ») — mesure de BOB du 31/10 : 0 paiement, tout se joue sur le site.
// Au « tu » (décision BOB 31/10), promesse de la pub v8 (SAM_vers_LEO_3110.md). Paris FR + New York EN.
// Mesure (repères conservés) : « hero_form_touche » (1er vrai tap), « hero_form_service » (1er service),
// « signup_web_hero » (bouton), + « hero_form_envoye » (demande publiée), « hero_form_refus_<code> ».
// Tous les hooks AVANT tout retour (règle de l'équipe).
// 10/11/2026 (LEO, plan « conclure » validé par Daniel le 09/11, CONTRAT_1011) — mesuré sur 7 j : 127 arrivées
// de pub, 4 touchent le formulaire, 1 publie ; 43 demandes sur 46 sans code postal. Donc :
//  · 4 services en 2 × 2, dont « Garde en journée » (id `journee` → day_care, prix au jour) ;
//  · code postal OBLIGATOIRE, même avec un lieu choisi sur la carte (refus serveur POSTAL_REQUIRED géré) ;
//  · « ＋ Préciser (horaires, budget, voiture) » replié : timeFrom / timeTo "HH:MM", budget, noCar — envoyés
//    seulement s'ils sont remplis, le bouton reste dans le premier écran à 375 px ;
//  · mesure du premier contact avec chaque étape : « lecture_form_direct | lecture_form_scroll » (formulaire à
//    l'écran sans / après défilement), « lecture_bouton_direct | lecture_bouton_scroll » (bouton d'envoi),
//    « lecture_defile » (page défilée) — préfixe « lecture_ » = signaux passifs, jamais comptés comme des clics
//    dans le tableau des pubs — puis « hero_form_dates », « hero_form_postal », « hero_form_email »,
//    « hero_form_preciser » (premier geste dans le champ). Une fois chacun par page.

type Lang = "fr" | "en";
type ServiceId = "garde" | "journee" | "promenade" | "visites";
const SERVICES: { id: ServiceId; svc: string; icon: string; fr: string; en: string; sub?: { fr: string; en: string } }[] = [
  { id: "garde", svc: "house_sitting", icon: "🏠", fr: "Garde", en: "Pet sitting", sub: { fr: "jour et nuit", en: "day and night" } },
  { id: "journee", svc: "day_care", icon: "☀️", fr: "Garde en journée", en: "Daytime care", sub: { fr: "je le récupère le soir", en: "evening pick-up" } },
  { id: "promenade", svc: "dog_walking", icon: "🐕", fr: "Promenade", en: "Dog walking" },
  { id: "visites", svc: "home_visit", icon: "🔑", fr: "Visites chez moi", en: "Drop-in visits" },
];
// 1011 — repères de mesure envoyés une seule fois par page (le formulaire se remonte quand la ville change).
const SENT_1011 = new Set<string>();
function once1011(label: string) {
  let key = label;
  try { key = `${window.location.pathname}:${label}`; } catch { /* rendu serveur */ }
  if (SENT_1011.has(key)) return;
  SENT_1011.add(key);
  trackSiteEvent("cta_click", { label });
}
const HHMM_1011 = /^([01]\d|2[0-3]):[0-5]\d$/;
// 1011 (LEO) — accueil en 9 langues : devise affichée et centre de recherche des villes selon le pays de la langue.
// Utilisés SEULEMENT quand la page fournit `ui` (les pages fr/en d'origine gardent leur calcul).
const CUR_1011: Record<string, { code: string; sign: string }> = {
  US: { code: "USD", sign: "$" }, KR: { code: "KRW", sign: "₩" }, JP: { code: "JPY", sign: "¥" }, GB: { code: "GBP", sign: "£" }, CH: { code: "CHF", sign: "CHF" },
};
const BIAS_1011: Record<string, { lat: number; lng: number }> = {
  ES: { lat: 40.4168, lng: -3.7038 }, DE: { lat: 52.52, lng: 13.405 }, IT: { lat: 41.9028, lng: 12.4964 }, PT: { lat: 38.7223, lng: -9.1393 },
  PL: { lat: 52.2297, lng: 21.0122 }, KR: { lat: 37.5665, lng: 126.978 }, JP: { lat: 35.6762, lng: 139.6503 },
};
const ANIMALS: { id: "chien" | "chat" | "autre"; fr: string; en: string }[] = [
  { id: "chien", fr: "Chien", en: "Dog" }, { id: "chat", fr: "Chat", en: "Cat" }, { id: "autre", fr: "Autre", en: "Other" },
];
const TXT = {
  fr: {
    from: "Du", to: "Au",
    postal: "Code postal", first: "Prénom", email: "E-mail", animal: "Animal", city: "Ville",
    cta: "Publier ma demande", busy: "Publication…",
    need_service: "Choisis un service.", need_place: "Indique ton code postal : il sert à prévenir les gardiens près de chez toi.",
    more: "Préciser (horaires, budget, voiture)", time_from: "Heure de début", time_to: "Heure de fin",
    budget: "Mon budget", budget_ph: "Ex. 35", no_car: "Je n'ai pas de voiture", optional: "facultatif", need_email: "Indique un e-mail valide : c'est là que les candidats arrivent, avec leur prix.",
    err: "La publication n'a pas abouti. Réessaie dans un instant.", err_test: "Cette adresse est réservée aux tests.", err_many: "Trop d'envois. Réessaie dans quelques minutes.",
    done_title: "Ta demande est en ligne.",
    done_body: "Tu reçois les candidats avec leur prix par e-mail — tu choisis, tu paies, annulation gratuite jusqu'à 72 h avant.",
    done_notified: (n: number) => (n > 0 ? `${n} gardien${n > 1 ? "s" : ""} et promeneur${n > 1 ? "s" : ""} près de chez toi ${n > 1 ? "sont prévenus" : "est prévenu"}.` : "Les gardiens et promeneurs près de chez toi sont prévenus."),
    done_existing: "Ta demande était déjà en ligne : la voici.",
    done_link: "Voir ma demande", done_mail: "Un e-mail te permet de revenir ici sans mot de passe.",
    pending_title: "Encore un clic : vérifie ta boîte mail",
    pending_body: "Tu as déjà un compte HoPetSit avec cette adresse. Pour publier ta demande et prévenir les gardiens, clique sur le bouton de l'e-mail que tu viens de recevoir.",
    pending_body_new: "On vient de t'envoyer un e-mail. Clique sur « Confirmer et publier » : ton adresse est vérifiée, ta demande est publiée et les gardiens près de chez toi sont prévenus.",
    pending_note: "Rien n'est publié tant que tu n'as pas cliqué. Pas d'e-mail ? Regarde les indésirables, ou connecte-toi avec ton mot de passe.",
    done_by_email: "Cette adresse a déjà un compte HoPetSit. Pour ouvrir ta demande, clique sur le lien de l'e-mail « ta demande est en ligne » (il ouvre ton espace sans mot de passe), ou connecte-toi.",
    done_login: "Me connecter",
    target_note: "Ta demande sera envoyée d'abord à ce gardien, puis aux autres près de chez toi.",
    terms: "En publiant, tu acceptes les", terms_link: "conditions d'utilisation",
  },
  en: {
    from: "From", to: "To",
    postal: "ZIP code", first: "First name", email: "Email", animal: "Pet", city: "City",
    cta: "Post my request", busy: "Posting…",
    need_service: "Pick a service.", need_place: "Enter your ZIP code: we use it to alert sitters near you.",
    more: "Add details (hours, budget, car)", time_from: "Start time", time_to: "End time",
    budget: "My budget", budget_ph: "e.g. 35", no_car: "I don't have a car", optional: "optional", need_email: "Enter a valid email: that's where candidates arrive, with their price.",
    err: "Posting didn't go through. Try again in a moment.", err_test: "This address is reserved for tests.", err_many: "Too many attempts. Try again in a few minutes.",
    done_title: "Your request is live.",
    done_body: "You get the candidates with their price by email — you choose, you pay, free cancellation up to 72 h before.",
    done_notified: (n: number) => (n > 0 ? `${n} sitter${n > 1 ? "s" : ""} and walker${n > 1 ? "s" : ""} near you ${n > 1 ? "have" : "has"} been notified.` : "Sitters and walkers near you have been notified."),
    done_existing: "Your request was already live: here it is.",
    done_link: "See my request", done_mail: "An email lets you come back here without a password.",
    pending_title: "One more click: check your inbox",
    pending_body: "You already have a HoPetSit account with this address. To publish your request and notify sitters, click the button in the email you just received.",
    pending_body_new: "We just sent you an email. Click “Confirm and publish”: your address is verified, your request goes live and sitters near you are notified.",
    pending_note: "Nothing is published until you click. No email? Check your spam folder, or sign in with your password.",
    done_by_email: "This address already has a HoPetSit account. To open your request, click the link in the “your request is live” email (it opens your space without a password), or sign in.",
    done_login: "Sign in",
    target_note: "Your request goes to this sitter first, then to the others near you.",
    terms: "By posting, you accept the", terms_link: "terms of use",
  },
};

/** 0811 — ce que la page /demande reçoit quand la demande est enregistrée (avant le code). */
export type HeroLeadResult0811 = { id: string; email: string; pending: boolean; existing: boolean; postId: string | null; codeSent: boolean; sessionOpened: boolean; notified?: number };

export function ParisHeroForm({ city, lead, note, lang = "fr", country = "FR", campaign = "paris_owners", page = "/garde-animaux/paris", cityEditable = false, codeFlow = false, onLead, ui, uiLang, polish = false }: {
  city: string; lead: string; note: string; lang?: Lang; country?: string; campaign?: string; page?: string;
  /** 1011 (LEO) — accueil dans les 7 langues hors fr/en : libellés fournis par la page (`heroUi1011`). `lang`
   *  reste "fr" | "en" et part tel quel au serveur (qui n'écrit ses e-mails qu'en fr ou en) ; `uiLang` est la
   *  langue AFFICHÉE (dates, prix « dès … », noms de villes). Sans `ui` ni `uiLang` : rien ne change. */
  ui?: HeroUi1011;
  uiLang?: UiLang;
  /** 1011 (LEO, « embellir l'accueil ») — habillage : bordures chaudes pleines (zéro gris), bouton d'envoi en
   *  rectangle arrondi au dégradé horizontal. Mêmes champs, même envoi. Défaut : habillage d'origine. */
  polish?: boolean;
  /** 31/10 (accueil, décision BOB) — la ville se saisit (Paris / New York proposées par défaut). */
  cityEditable?: boolean;
  /** 0811 (NEO, ordre de Daniel) — page /demande : l'e-mail porte un code à taper sur la page ; la page parente
   *  reprend la main après l'envoi (`onLead`) et le formulaire n'affiche pas ses écrans « vérifie ta boîte mail ». */
  codeFlow?: boolean;
  onLead?: (r: HeroLeadResult0811) => void;
}) {
  const L: UiLang = uiLang || lang;
  const t: (typeof TXT)["fr"] = ui ? { ...TXT[lang], ...ui.t } : TXT[lang];
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
      if (sv === "garde" || sv === "journee" || sv === "promenade" || sv === "visites") setService(sv);
      else if (m && m[1].toLowerCase() === "walker") setService("promenade");
    } catch { /* adresse exotique */ }
  }, [cityEditable]);
  const [service, setService] = useState<"" | ServiceId>("");
  const [animal, setAnimal] = useState<"chien" | "chat" | "autre">("chien");
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [postalCode, setPostalCode] = useState("");
  // 1011 — précisions facultatives, repliées par défaut.
  const [more, setMore] = useState(false);
  const [timeFrom, setTimeFrom] = useState("");
  const [timeTo, setTimeTo] = useState("");
  const [budget, setBudget] = useState("");
  const [noCar, setNoCar] = useState(false);
  const formRef = useRef<HTMLDivElement>(null);
  const btnRef = useRef<HTMLButtonElement>(null);
  const postalRef = useRef<HTMLInputElement>(null);
  // 1011 — où partent ceux qui ne touchent jamais le formulaire : est-il à l'écran (sans ou après défilement),
  // le bouton d'envoi aussi, la page est-elle défilée ? Signaux passifs (« lecture_ »), une fois par page.
  useEffect(() => {
    if (typeof window === "undefined") return;
    const how = () => (window.scrollY > 24 ? "scroll" : "direct");
    let io: IntersectionObserver | null = null;
    const waiting = new Set<Element>();
    if (typeof IntersectionObserver !== "undefined") {
      io = new IntersectionObserver((entries) => {
        for (const en of entries) {
          if (!en.isIntersecting || document.visibilityState !== "visible") continue;
          once1011(`lecture_${en.target === btnRef.current ? "bouton" : "form"}_${how()}`);
          waiting.delete(en.target);
          io?.unobserve(en.target);
        }
      }, { threshold: 0.35 });
      for (const el of [formRef.current, btnRef.current]) if (el) { waiting.add(el); io.observe(el); }
    }
    // Page ouverte dans un onglet caché : on repose la question quand elle devient visible.
    const onVisible = () => {
      if (!io || document.visibilityState !== "visible") return;
      waiting.forEach((el) => { io?.unobserve(el); io?.observe(el); });
    };
    document.addEventListener("visibilitychange", onVisible);
    const onScroll = () => {
      if (window.scrollY < 160) return;
      once1011("lecture_defile");
      window.removeEventListener("scroll", onScroll);
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => { io?.disconnect(); window.removeEventListener("scroll", onScroll); document.removeEventListener("visibilitychange", onVisible); };
  }, []);
  const [firstName, setFirstName] = useState("");
  const [email, setEmail] = useState("");
  const [website, setWebsite] = useState(""); // champ piège : jamais affiché
  const [err, setErr] = useState("");
  const [busy, setBusy] = useState(false);
  const [started, setStarted] = useState(false);
  const [touched, setTouched] = useState(false);
  const [done, setDone] = useState<{ notified?: number; existing: boolean; sessionOpened: boolean; pending?: boolean } | null>(null);
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
  function pick(id: ServiceId) {
    setErr("");
    setService((cur) => (cur === id ? "" : id));
    if (!started) { setStarted(true); trackSiteEvent("cta_click", { label: "hero_form_service" }); }
  }

  async function submit() {
    setErr("");
    if (!service) { trackSiteEvent("cta_click", { label: "hero_form_sans_service" }); return setErr(t.need_service); }
    // 0611 (NEO) — dates OBLIGATOIRES : balade = la date ; sinon début et fin, début ≤ fin.
    if (!startDate || (!isWalk && !endDate)) { trackSiteEvent("cta_click", { label: "hero_form_sans_dates" }); return setErr(isWalk ? dr(L, "walk_required") : f2(L, "dates_required")); }
    if (!isWalk && endDate < startDate) return setErr(d620(L, "dates_order"));
    // 1011 — code postal OBLIGATOIRE, même avec un lieu choisi sur la carte (43 demandes sur 46 n'en avaient pas).
    if (postalCode.trim().length < 3) {
      trackSiteEvent("cta_click", { label: "hero_form_sans_lieu" });
      try { postalRef.current?.focus(); } catch { /* champ absent */ }
      return setErr(t.need_place);
    }
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.trim())) { trackSiteEvent("cta_click", { label: "hero_form_sans_email" }); return setErr(t.need_email); }
    trackSiteEvent("cta_click", { label: "signup_web_hero" });
    setBusy(true);
    // 1011 — précisions : envoyées seulement si elles sont remplies (un serveur d'avant 1011 ignore ces champs).
    const budgetNum = Number(budget.replace(",", "."));
    const extra1011 = {
      ...(HHMM_1011.test(timeFrom) ? { timeFrom } : {}),
      ...(HHMM_1011.test(timeTo) ? { timeTo } : {}),
      ...(Number.isFinite(budgetNum) && budgetNum > 0 ? { budget: Math.round(budgetNum * 100) / 100 } : {}),
      ...(noCar ? { noCar: true } : {}),
    };
    try {
      const r = await publishSiteLead({
        email: email.trim(), firstName: firstName.trim(), service, animal, postalCode: postalCode.trim(), city: (place ? place.city : cityValue.trim()) || city,
        country: (place && place.countryCode) || country, lang,
        ...(place ? { lat: place.lat, lng: place.lng } : {}),
        startDate, endDate: isWalk ? startDate : endDate, campaign, page, website,
        ...(target ? { targetProvider: target } : {}),
        ...(codeFlow ? { codeFlow: true } : {}),
        ...extra1011,
      });
      trackSiteEvent("cta_click", { label: r.pending ? "hero_form_a_confirmer" : r.existing ? "hero_form_deja" : "hero_form_envoye" });
      if (onLead) {
        // 0811 — la page /demande affiche le champ « code reçu par e-mail » à la place des écrans ci-dessous.
        onLead({ id: r.id, email: email.trim(), pending: !!r.pending, existing: r.existing, postId: r.postId ?? null, codeSent: (r as { code?: boolean }).code === true, sessionOpened: r.sessionOpened, notified: r.notified });
        return;
      }
      setDone({ notified: r.notified, existing: r.existing, sessionOpened: r.sessionOpened, pending: !!r.pending });
    } catch (e) {
      const code = e instanceof ApiError && e.details && typeof e.details === "object" ? String((e.details as { code?: string }).code || "") : "";
      trackSiteEvent("cta_click", { label: `hero_form_refus_${(code || (e instanceof ApiError ? e.status : "x")).toString().toLowerCase()}` });
      if (code === "POSTAL_REQUIRED") { try { postalRef.current?.focus(); } catch { /* champ absent */ } }
      setErr(code === "TEST_ACCOUNT" ? t.err_test : code === "TOO_MANY" ? t.err_many : code === "EMAIL_INVALID" ? t.need_email : code === "POSTAL_REQUIRED" ? t.need_place
        : code === "DATES_REQUIRED" ? (isWalk ? dr(L, "walk_required") : f2(L, "dates_required")) : code === "DATES_INVALID" ? d620(L, "dates_order") : t.err);
    } finally {
      setBusy(false);
    }
  }

  const bias = country === "US" ? { lat: 40.7128, lng: -74.006 } : country === "FR" ? { lat: 48.8566, lng: 2.3522 } : (ui && BIAS_1011[country]) || null;
  // 1011 — bordures : `border-ink/15` (encre à 15 % = gris sur blanc) devient un rose chaud PLEIN quand `polish`.
  const line = polish ? "border-[#EBCFC6]" : "border-ink/15";
  const lineSoft = polish ? "border-[#F3D2C8]" : "border-ink/10";
  const field = `mt-1 w-full rounded-xl border ${line} bg-white px-3 py-2.5 text-[15px] text-ink focus:border-owner focus:outline-none`;
  const money1011 = ui ? (CUR_1011[country] || { code: "EUR", sign: "€" }) : (country === "US" ? { code: "USD", sign: "$" } : { code: "EUR", sign: "€" });
  const svcId = SERVICES.find((s) => s.id === service)?.svc || "";
  const isWalk = service === "promenade";
  const today = new Date().toISOString().slice(0, 10);

  if (done && done.pending) {
    // 31/10 (BOB, sécurité) — un compte existe déjà avec cet e-mail : la demande est gardée en brouillon et
    // ne sera publiée (gardiens prévenus) qu'au clic sur le lien reçu dans la boîte.
    return (
      <div ref={doneRef} className="mt-3 scroll-mt-24 rounded-3xl bg-white p-5 text-center md:mx-auto md:max-w-md" style={{ boxShadow: "0 0 0 2px #C92A12, 0 14px 30px -18px rgba(35,23,21,.5)" }} data-testid="hero-pending" data-hero-pending-3110="">
        <p className="text-[22px] font-extrabold leading-tight" style={{ color: "#9E1F0B" }}>✉ {t.pending_title}</p>
        <p className="mt-2 text-[15px] font-semibold leading-snug text-ink">{done.existing ? t.pending_body : t.pending_body_new}</p>
        <p className="mt-3 text-[13px] leading-snug" style={{ color: "#6E4F48" }}>{t.pending_note}</p>
      </div>
    );
  }
  if (done) {
    return (
      <div ref={doneRef} className="mt-3 scroll-mt-24 rounded-3xl bg-white p-5 text-center md:mx-auto md:max-w-md" style={{ boxShadow: "0 0 0 2px #15803D, 0 14px 30px -18px rgba(35,23,21,.5)" }} data-testid="hero-done" data-hero-done-3110="">
        <p className="text-[22px] font-extrabold leading-tight" style={{ color: "#15803D" }}>✓ {t.done_title}</p>
        <p className="mt-2 text-[15px] font-semibold leading-snug text-ink">{done.existing ? t.done_existing : t.done_notified(done.notified ?? 0)}</p>
        <p className="mt-2 text-[14px] leading-snug text-ink">{t.done_body}</p>
        {done.sessionOpened ? (
          <>
            <Link href="/posts" className={`mt-4 inline-block ${polish ? "rounded-[18px]" : "rounded-full"} bg-owner px-6 py-3.5 text-[16px] font-extrabold text-white shadow-card`} onClick={() => trackSiteEvent("cta_click", { label: "hero_form_voir" })}>
              {t.done_link} →
            </Link>
            <p className="mt-3 text-xs text-ink-muted">{t.done_mail}</p>
          </>
        ) : (
          // 31/10 16 h 40 (ZOE) — compte déjà existant : pas de session ouverte ici (une adresse e-mail seule ne prouve
          // rien) ; la personne passe par le lien de l'e-mail ou par la connexion.
          <>
            <p className="mt-3 text-[13px] leading-snug text-ink" data-hero-done-email="">{t.done_by_email}</p>
            <Link href="/login?redirect=%2Fposts" className={`mt-4 inline-block ${polish ? "rounded-[18px]" : "rounded-full"} border-2 border-owner px-6 py-3 text-[15px] font-extrabold text-owner`} onClick={() => trackSiteEvent("cta_click", { label: "hero_form_login" })}>
              {t.done_login} →
            </Link>
          </>
        )}
      </div>
    );
  }

  // 31/10 (Daniel) — « juste derrière le formulaire, le fond d'écran soit lisse » : carte 100 % opaque (crème #FFF7F3,
  // plus aucune patte qui transparaît), marge lisse unie de 20 px (28 px dès md) qui masque le motif autour, halo doux
  // qui fond dans le dégradé, puis ombre portée. Le dégradé + pattes reste sur le reste du héros.
  // 31/10 soir (Daniel, via BOB) — « un cadre noir autour du formulaire » : 2 px #1C1917 posé en PREMIÈRE ombre (au bord
  // de la carte, par-dessus la marge crème) ; aucune incidence sur la mise en page, donc rien ne peut déborder. Les états
  // « vérifie ta boîte mail » / « en ligne » sont d'autres blocs avec leur propre cadre (orange / vert) : jamais deux cadres.
  return (
    <div id="publier" className="mt-7 scroll-mt-20 rounded-3xl bg-[#FFF7F3] p-4 shadow-[0_0_0_2px_#1C1917,0_0_0_20px_#FFF3EC,0_0_36px_32px_rgba(255,243,236,0.95),0_32px_56px_-24px_rgba(35,23,21,0.32)] md:mx-auto md:mt-10 md:max-w-md md:shadow-[0_0_0_2px_#1C1917,0_0_0_28px_#FFF3EC,0_0_44px_40px_rgba(255,243,236,0.95),0_32px_56px_-24px_rgba(35,23,21,0.32)]" data-hero-card-lisse-3110="" data-testid="hero-form" data-hero-form-3110={lang} data-hero-1011="" data-hero-ui-1011={L} ref={formRef} onClickCapture={touch}>
      <p className="text-[15px] font-semibold leading-snug text-ink md:text-base">{lead}</p>
      {target && <p className="mt-1.5 rounded-xl bg-white px-3 py-1.5 text-[12px] font-bold" style={{ color: "#1E4FB0" }} data-hero-target={target.role}>{t.target_note}</p>}

      {/* 1011 — 4 services en 2 × 2 (icône à gauche : deux rangées basses, le bouton reste dans le premier écran). */}
      <div className="mt-3 grid grid-cols-2 gap-2" role="group" aria-label={ui?.serviceAria || "Service"} data-testid="hero-services-1011">
        {SERVICES.map((s) => (
          <button key={s.id} type="button" onClick={() => pick(s.id)} aria-pressed={service === s.id} data-svc={s.id}
            className={`flex min-h-[44px] items-center gap-1 rounded-2xl border px-1.5 py-1 text-left transition ${service === s.id ? "border-owner bg-owner text-white shadow-card" : `${lineSoft} bg-white text-ink`}`}>
            <span aria-hidden className="shrink-0 text-base leading-none">{s.icon}</span>
            <span className="min-w-0">
              <span className="block text-[12.5px] font-bold leading-tight">{ui?.services?.[s.id]?.label || s[lang]}</span>
              {s.sub && <span className="block text-[10.5px] font-semibold leading-tight" style={{ color: service === s.id ? "#FFFFFF" : "#6E4F48" }}>{ui?.services?.[s.id]?.sub || s.sub[lang]}</span>}
            </span>
          </button>
        ))}
      </div>

      {isWalk ? (
        <div className="mt-3 grid grid-cols-2 gap-2" data-testid="hero-dates-walk-0611">
          <label className="block text-xs font-semibold text-ink">{c2610(L, "date_label")} *
            <input type="date" required min={today} value={startDate} onChange={(e) => { once1011("hero_form_dates"); setStartDate(e.target.value); setEndDate(e.target.value); }} className={field} data-testid="hero-start" />
          </label>
        </div>
      ) : (
        <div className="mt-3 grid grid-cols-2 gap-2" data-testid="hero-dates-0611">
          <label className="block text-xs font-semibold text-ink">{t.from} *
            <input type="date" required min={today} value={startDate} onChange={(e) => { once1011("hero_form_dates"); const v = e.target.value; setStartDate(v); if (v && (!endDate || endDate < v)) setEndDate(v); }} className={field} data-testid="hero-start" />
          </label>
          <label className="block text-xs font-semibold text-ink">{t.to} *
            <input type="date" required min={startDate || today} value={endDate} onChange={(e) => { once1011("hero_form_dates"); setEndDate(e.target.value); }} className={field} data-testid="hero-end" />
          </label>
        </div>
      )}
      {/* 0611 (NEO, texte dicté par Daniel) — pourquoi les dates sont obligatoires. */}
      <p className="mt-1 text-[11px] font-semibold text-ink" data-testid="hero-dates-hint-0611">{dr(L, "hint")}</p>

      {svcId && (
        <div className="mt-3">
          <EstimateLine620 lang={L} service={svcId} dateMode={startDate && (isWalk || endDate) ? "exact" : "tbd"} startDate={startDate} endDate={isWalk ? startDate : endDate}
            visitsPerDay={1} venue={svcId === "house_sitting" ? "owners_home" : null} currency={money1011.code} location={{ city: place ? place.city : (cityEditable ? cityValue : city), ...(place ? { lat: place.lat, lng: place.lng } : {}), ...(postalCode.trim().length >= 3 ? { postalCode: postalCode.trim() } : {}) }} />
        </div>
      )}

      {/* Ville (liste + carte) et code postal sur une rangée, prénom et e-mail sur la suivante : le bouton reste
          dans le premier écran à 375 px même avec le champ Ville en plus. */}
      <div className="mt-3 grid grid-cols-[1.4fr_1fr] gap-2">
        <PlacePicker3110 lang={lang} value={cityValue} onChange={setCityValue} pick={place} setPick={(p) => { setPlace(p); trackSiteEvent("cta_click", { label: p ? "hero_form_carte" : "hero_form_carte_off" }); }} inputClass={field} bias={bias} txt={ui?.place} searchLang={L} />
        <label className="block text-xs font-semibold text-ink">{t.postal} *
          <input ref={postalRef} required aria-required="true" value={postalCode} onChange={(e) => { once1011("hero_form_postal"); setErr(""); setPostalCode(e.target.value); }} inputMode="numeric" autoComplete="postal-code" maxLength={12} className={field} data-testid="hero-postal" />
        </label>
      </div>
      {/* 1011 — le refus « code postal » s'affiche sous le champ (avec la carte dépliée, le bas du formulaire sort de l'écran). */}
      {err && err === t.need_place && <p className="mt-1 text-xs font-semibold text-owner-dark" role="alert" data-testid="hero-postal-err">{err}</p>}
      <PlaceMapConfirm3110 lang={lang} pick={place} setPick={(p) => setPlace(p)} txt={ui?.place} />
      <div className="mt-2 grid grid-cols-[1fr_1.4fr] gap-2">
        <label className="block text-xs font-semibold text-ink">{t.first}
          <input value={firstName} onChange={(e) => setFirstName(e.target.value)} autoComplete="given-name" maxLength={60} className={field} data-testid="hero-first" />
        </label>
        <label className="block text-xs font-semibold text-ink">{t.email}
          <input type="email" value={email} onChange={(e) => { once1011("hero_form_email"); setEmail(e.target.value); }} autoComplete="email" inputMode="email" maxLength={120} className={field} data-testid="hero-email"
            onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); void submit(); } }} />
        </label>
      </div>
      <div className="mt-2 flex items-center gap-2" role="group" aria-label={t.animal}>
        <span className="text-xs font-semibold text-ink">{t.animal}</span>
        {ANIMALS.map((a) => (
          <button key={a.id} type="button" onClick={() => setAnimal(a.id)} aria-pressed={animal === a.id}
            className={`min-h-[36px] ${polish ? "rounded-[12px]" : "rounded-full"} border px-3 text-[12px] font-bold ${animal === a.id ? "border-owner bg-owner text-white" : `${lineSoft} bg-white text-ink`}`}>
            {ui?.animals?.[a.id] || a[lang]}
          </button>
        ))}
      </div>
      {/* 1011 — précisions facultatives, repliées : horaires, budget, sans voiture. */}
      <button type="button" onClick={() => { if (!more) once1011("hero_form_preciser"); setMore((v) => !v); }} aria-expanded={more} aria-controls="hero-more-1011" data-testid="hero-more-toggle"
        className="mt-2 flex min-h-[36px] w-full items-center gap-1.5 text-left text-[13px] font-bold text-owner-dark">
        <span aria-hidden className="inline-flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-white text-[14px] leading-none" style={{ boxShadow: "0 0 0 1.5px #C92A12" }}>{more ? "−" : "+"}</span>
        <span className="underline decoration-1 underline-offset-2">{t.more}</span>
      </button>
      {more && (
        <div id="hero-more-1011" className="mt-1 rounded-2xl bg-white p-3" style={{ boxShadow: "0 0 0 1px #F3D2C8" }} data-testid="hero-more">
          <div className="grid grid-cols-2 gap-2">
            <label className="block text-xs font-semibold text-ink">{t.time_from}
              <input type="time" step={900} value={timeFrom} onChange={(e) => setTimeFrom(e.target.value)} className={field} data-testid="hero-time-from" />
            </label>
            <label className="block text-xs font-semibold text-ink">{t.time_to}
              <input type="time" step={900} value={timeTo} onChange={(e) => setTimeTo(e.target.value)} className={field} data-testid="hero-time-to" />
            </label>
          </div>
          <div className="mt-2 grid grid-cols-2 items-end gap-2">
            <label className="block text-xs font-semibold text-ink">{t.budget} <span style={{ color: "#6E4F48" }}>({t.optional})</span>
              <span className="relative block">
                <input type="text" inputMode="decimal" maxLength={8} value={budget} onChange={(e) => setBudget(e.target.value.replace(/[^0-9.,]/g, ""))} placeholder={t.budget_ph} className={`${field} pr-9`} data-testid="hero-budget" />
                <span aria-hidden className="pointer-events-none absolute inset-y-0 right-3 mt-1 flex items-center text-sm font-extrabold" style={{ color: "#C92A12" }}>{money1011.sign}</span>
              </span>
            </label>
            <label className={`flex min-h-[44px] cursor-pointer items-center gap-2 rounded-xl border ${line} bg-white px-2.5 text-[12.5px] font-bold leading-tight text-ink`}>
              <input type="checkbox" checked={noCar} onChange={(e) => setNoCar(e.target.checked)} className="h-4 w-4 shrink-0 accent-[#C92A12]" data-testid="hero-nocar" />
              {t.no_car}
            </label>
          </div>
        </div>
      )}
      {/* Champ piège anti-robot : invisible, jamais rempli par une personne. */}
      <div aria-hidden className="absolute h-0 w-0 overflow-hidden opacity-0" style={{ position: "absolute", left: -9999 }}>
        <label>Website<input tabIndex={-1} autoComplete="off" value={website} onChange={(e) => setWebsite(e.target.value)} name="website" /></label>
      </div>

      {err && err !== t.need_place && <p className="mt-2 text-center text-sm font-semibold text-owner-dark" role="alert">{err}</p>}

      <button id="hero-publier" ref={btnRef} type="button" onClick={() => void submit()} disabled={busy} data-testid="hero-continuer"
        className={`mt-3 block w-full ${polish ? "rounded-[18px]" : "rounded-full"} bg-owner px-6 py-4 text-center text-lg font-extrabold text-white shadow-card disabled:opacity-70`}
        style={polish ? { backgroundImage: "linear-gradient(90deg, #C92A12, #9E1F0B)" } : undefined}>
        {busy ? t.busy : t.cta}
      </button>
      <p className="mt-2 text-center text-xs text-ink-muted">{note}</p>
      <p className="mt-1 text-center text-[11px] text-ink-muted">{t.terms} <Link href={lang === "fr" ? "/cgu" : "/terms"} className="underline">{t.terms_link}</Link>{ui?.termsAfter ?? "."}</p>
    </div>
  );
}

export default ParisHeroForm;
