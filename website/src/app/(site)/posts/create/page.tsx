"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import { gp } from "@/lib/i18n/guestPublish2809";
import { parseAskFor, type AskRole } from "@/lib/i18n/demander2809";
import { trackSiteEvent } from "@/components/SiteAnalytics";
import ServiceLocationPicker587 from "@/components/ServiceLocationPicker587";
// 29/09 (NEO) — « N gardiens et promeneurs à <ville> seront prévenus » sous le bouton.
import ProofNearButton2909 from "@/components/ProofNearButton2909";
// 616 (LEO, 08/10) — ville choisie dans une liste « GPS » + bouton « Ma position ».
import CityAutocomplete616, { searchCities616, type CityCoords } from "@/components/CityAutocomplete616";
import { c616 } from "@/lib/i18n/cityPicker616";
import { locationComplete, locationOptions, locationToSend, p587, type ServiceLocation } from "@/lib/i18n/publish587";
import {
  API_BASE,
  ApiError,
  createPost,
  createPostWithMedia,
  getMyProfile,
  getStoredUser,
  login,
  POST_SERVICE_TYPES,
  resendVerificationCode,
  signup,
  verifyEmail,
} from "@/lib/api";

// v402 — Owner publie une annonce depuis le SITE (parité app). Endpoint
// existant POST /posts (owner only). Aucun impact app.
/** Brouillon gardé le temps de l'inscription (ce navigateur seulement). */
const DRAFT_KEY = "hopetsit_post_draft_v1";

export default function CreatePostPage() {
  const { t, lang } = useT();
  const router = useRouter();

  const [role, setRole] = useState<string | null>(null);
  // 22/09/2026 — LE FORMULAIRE D'ABORD, LE COMPTE À LA FIN.
  // Mesure du 22/09 : 33 inscriptions en 7 jours, 12 e-mails vérifiés (36 %).
  // On demandait à un inconnu de créer un compte PUIS d'aller chercher un code
  // dans sa boîte mail avant même de pouvoir décrire son besoin — et aucune
  // demande n'a jamais été publiée. Désormais on écrit la demande, puis on
  // crée le compte : le brouillon est gardé et repris après la vérification.
  const [invite, setInvite] = useState(false);
  // La ville est OBLIGATOIRE : c'est elle qui déclenche l'alerte « nouvelle
  // demande près de chez toi » chez les gardiens. Sans elle, une demande
  // publiée depuis le site ne prévenait PERSONNE.
  const [city, setCity] = useState("");
  // 616 — coordonnées de la ville CHOISIE (liste ou « Ma position »), envoyées
  // dans location.lat/lng : le serveur s'en sert pour l'alerte à 100 km
  // (sinon il géocode le nom tapé, au risque de se tromper de ville).
  const [cityCoords, setCityCoords] = useState<CityCoords | null>(null);
  const [cityLabel, setCityLabel] = useState("");
  const [body, setBody] = useState("");
  const [services, setServices] = useState<string[]>([]);
  // v587 (point 8 de Daniel) — lieu du service pour CHAQUE service (avant :
  // seulement pour la garde à domicile ; rien pour la garderie ni la promenade).
  const [svcLocation, setSvcLocation] = useState("");
  const [meetingPoint, setMeetingPoint] = useState("");
  // v587 (option A de Daniel) — « Mon budget », facultatif, devise du compte.
  const [budget, setBudget] = useState("");
  const [budgetCur, setBudgetCur] = useState("EUR");
  const budgetAmount = (() => {
    const n = Number(budget.replace(/\s/g, "").replace(",", "."));
    return Number.isFinite(n) && n > 0 ? Math.round(n * 100) / 100 : 0;
  })();
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [notes, setNotes] = useState("");
  const [animalCount, setAnimalCount] = useState(1);
  const [animalTypes, setAnimalTypes] = useState<string[]>([]);
  const [photos, setPhotos] = useState<File[]>([]);

  // v404 — types d'animaux concernés par l'annonce (clés stables + emoji).
  const ANIMAL_TYPES: { key: string; emoji: string }[] = [
    { key: "dog", emoji: "🐶" },
    { key: "cat", emoji: "🐱" },
    { key: "nac", emoji: "🐹" },
    { key: "bird", emoji: "🐦" },
    { key: "reptile", emoji: "🦎" },
    { key: "other", emoji: "🐾" },
  ];
  function toggleAnimalType(k: string) {
    setAnimalTypes((prev) => (prev.includes(k) ? prev.filter((x) => x !== k) : [...prev, k]));
  }
  const animalTypeLabel = (k: string) =>
    ({ dog: t("posts_animal_dog"), cat: t("posts_animal_cat"), nac: t("posts_animal_nac"), bird: t("posts_animal_bird"), reptile: t("posts_animal_reptile"), other: t("posts_animal_other") } as Record<string, string>)[k] || k;
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");

  // 28/09 soir (NEO, mission BOB validée par Daniel) — « Demander à Sasha ».
  // Le bouton de la carte publique et des fiches /p/… arrive ici avec
  // ?for=<rôle>:<id>. La demande est ADRESSÉE à ce prestataire : le serveur
  // le prévient en premier (notification distincte), puis la ville comme
  // avant. Le prénom vient de la fiche publique (« Prénom I. »). Gardé dans le
  // brouillon, comme le reste. Fiche introuvable → ciblage abandonné, la
  // demande part normalement à la ville.
  const [target, setTarget] = useState<{ role: AskRole; id: string } | null>(null);
  const [targetName, setTargetName] = useState("");

  // 28/09/2026 (NEO, mission BOB validée par Daniel) — UNE SEULE ÉTAPE.
  // Mesure du 28/09 (7 jours) : 8 visiteurs sur ce formulaire, 9 sur /signup,
  // 0 demande publiée. L'invité devait remplir la demande, partir sur /signup,
  // puis /verify-email, puis revenir ici et republier : 4 écrans. Désormais le
  // compte (prénom, e-mail, mot de passe, CGU — le minimum exigé par
  // POST /auth/signup) se remplit ICI, le code e-mail se tape ICI, et la
  // demande part toute seule dès que le compte est actif.
  const [accName, setAccName] = useState("");
  const [accEmail, setAccEmail] = useState("");
  const [accPassword, setAccPassword] = useState("");
  const [showPwd, setShowPwd] = useState(false);
  const [acceptTerms, setAcceptTerms] = useState(false);
  const [referralCode, setReferralCode] = useState("");
  const [step, setStep] = useState<"form" | "code">("form");
  const [pendingEmail, setPendingEmail] = useState("");
  const [code, setCode] = useState("");
  const [info, setInfo] = useState("");
  const accStarted = useRef(false);

  function addPhotos(e: React.ChangeEvent<HTMLInputElement>) {
    const files = Array.from(e.target.files || []);
    if (!files.length) return;
    setPhotos((prev) => [...prev, ...files].slice(0, 10)); // max 10
    e.target.value = ""; // permet de re-sélectionner le même fichier
  }

  function removePhoto(idx: number) {
    setPhotos((prev) => prev.filter((_, i) => i !== idx));
  }

  useEffect(() => {
    const u = getStoredUser();
    setInvite(!u);
    if (u) setRole(u.role);
    // v587 — devise du compte pour le budget (repli EUR ; le serveur applique
    // de toute façon celle du propriétaire si rien n'est envoyé).
    if (u) {
      getMyProfile()
        .then((p) => {
          const c = String((p as { currency?: string })?.currency || "").toUpperCase(); if (c) setBudgetCur(c);
          // 29/09 (NEO) — ville du profil pré-remplie pour un membre (mesure du
          // 29/09 sur l'app : le champ ville arrive vide alors que le profil en a
          // une). Jamais par-dessus une ville déjà posée (?city=, brouillon, saisie).
          const pc = String((p as { city?: string })?.city || "").trim();
          if (pc && !pc.includes("@")) setCity((cur) => cur || pc);
        })
        .catch(() => { /* hors ligne : EUR */ });
    }

    // Mesure de l'entonnoir invité (libellé court, aucune donnée perso).
    if (!u) trackSiteEvent("cta_click", { label: "pub_ouvert" });

    // Ville pré-remplie par la page ville d'où l'on vient (?city=Paris).
    try {
      const q = new URLSearchParams(window.location.search);
      const c = (q.get("city") || "").trim();
      if (c) setCity(c);
      // Code parrain (même règle que /signup : format exact uniquement).
      const ref = (q.get("ref") || "").trim();
      if (/^[A-HJ-NP-Z2-9]{8}$/.test(ref)) setReferralCode(ref);
      // Prestataire ciblé (« Demander à <prénom> »).
      const forQ = parseAskFor(q.get("for"));
      if (forQ) setTarget(forQ);
    } catch { /* URL exotique */ }

    // Brouillon laissé avant l'inscription : on le remet tel quel.
    try {
      const brut = window.localStorage.getItem(DRAFT_KEY);
      if (!brut) return;
      const d = JSON.parse(brut) as Record<string, unknown>;
      if (typeof d.body === "string") setBody(d.body);
      if (Array.isArray(d.services)) setServices(d.services as string[]);
      if (typeof d.serviceLocation === "string") setSvcLocation(d.serviceLocation);
      else if (d.venue === "owners_home") setSvcLocation("at_owner");
      else if (d.venue === "sitters_home") setSvcLocation("at_sitter");
      if (typeof d.meetingPoint === "string") setMeetingPoint(d.meetingPoint);
      if (typeof d.budget === "string") setBudget(d.budget);
      if (typeof d.startDate === "string") setStartDate(d.startDate);
      if (typeof d.endDate === "string") setEndDate(d.endDate);
      if (typeof d.notes === "string") setNotes(d.notes);
      if (typeof d.animalCount === "number") setAnimalCount(d.animalCount);
      if (Array.isArray(d.animalTypes)) setAnimalTypes(d.animalTypes as string[]);
      if (typeof d.city === "string" && d.city) {
        setCity(d.city);
        const la = Number(d.cityLat), ln = Number(d.cityLng);
        if (Number.isFinite(la) && Number.isFinite(ln) && !(la === 0 && ln === 0)) {
          setCityCoords({ lat: la, lng: ln });
          if (typeof d.cityLabel === "string") setCityLabel(d.cityLabel);
        }
      }
      // Ciblage gardé avec le brouillon (l'URL, si elle en porte un, a priorité).
      {
        const tp = d.targetProvider as { role?: string; id?: string } | undefined;
        const fromDraft = tp && parseAskFor(`${tp.role}:${tp.id}`);
        if (fromDraft) setTarget((cur) => cur || fromDraft);
      }
      // Page rechargée pendant la saisie du code : on revient sur le code.
      if (!u && typeof d.pendingEmail === "string" && d.pendingEmail) {
        setPendingEmail(d.pendingEmail);
        setAccEmail(d.pendingEmail);
        setStep("code");
      }
      if (typeof d.accName === "string") setAccName(d.accName);
    } catch { /* brouillon illisible → on repart d'une page vierge */ }
  }, [router]);

  // Prénom du prestataire ciblé, lu sur sa fiche publique (jamais stocké).
  useEffect(() => {
    if (!target) { setTargetName(""); return; }
    let vivant = true;
    fetch(`${API_BASE}/${target.role}s/${target.id}`)
      .then((r) => (r.ok ? r.json() : null))
      .then((d) => {
        if (!vivant) return;
        const f = (d && (d.sitter || d.walker)) as { firstName?: string; name?: string } | undefined;
        const first = ((f && (f.firstName || f.name)) || "").trim().split(/\s+/)[0];
        if (first) setTargetName(first);
        else setTarget(null);
      })
      .catch(() => { /* hors ligne : on garde le ciblage, le prénom viendra ou pas */ });
    return () => { vivant = false; };
  }, [target]);

  const svcLabel = (s: string) =>
    s === "house_sitting"
      ? t("posts_svc_house_sitting")
      : s === "day_care"
        ? t("posts_svc_day_care")
        : t("posts_svc_dog_walking");

  function toggleService(s: string) {
    // v404 — Daniel : UN SEUL service par annonce (avant on pouvait cocher les
    // 3). Évite aussi les annonces mixant dog_walking + autres qui brouillent
    // le filtrage walker/sitter. Re-cliquer le service actif le désélectionne.
    const next = services.includes(s) ? [] : [s];
    setServices(next);
    // v587 — un lieu qui ne va plus avec le nouveau service est vidé.
    setSvcLocation((cur) => (locationOptions(next[0], cur).includes(cur as ServiceLocation) ? cur : ""));
  }

  const service = services[0] || "";
  const needsVenue = services.includes("house_sitting");
  // Le serveur exige encore houseSittingVenue pour la garde à domicile : il se
  // déduit du lieu choisi (chez moi = owners_home, chez le gardien = sitters_home).
  const venue: "owners_home" | "sitters_home" = svcLocation === "at_sitter" ? "sitters_home" : "owners_home";

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!body.trim()) {
      setErr(t("posts_error_body"));
      return;
    }
    if (!city.trim()) {
      setErr(t("signup_city_required"));
      return;
    }
    if (service && !locationComplete(service, svcLocation, meetingPoint)) {
      setErr(p587(lang, svcLocation === "meeting_point" ? "svc587_meeting_required" : "svc587_required"));
      return;
    }
    // 616 — ville tapée sans être choisie : on prend la 1re suggestion ; aucune
    // ville trouvée → on demande gentiment de choisir dans la liste. Géocodeur
    // injoignable → on laisse partir (le serveur géocode lui-même le nom).
    let loc: { city: string; lat?: number; lng?: number } = cityCoords
      ? { city: city.trim(), lat: cityCoords.lat, lng: cityCoords.lng }
      : { city: city.trim() };
    if (!cityCoords) {
      setBusy(true); // pas de double envoi pendant la résolution
      try {
        const r = await searchCities616(city.trim(), lang);
        if (!r.length) {
          setErr(c616(lang, "choose_from_list"));
          setBusy(false);
          return;
        }
        loc = { city: r[0].city, lat: r[0].lat, lng: r[0].lng };
        setCity(r[0].city);
        setCityCoords({ lat: r[0].lat, lng: r[0].lng });
        setCityLabel(r[0].label);
      } catch { /* hors ligne : nom seul */ }
    }

    setBusy(true);
    setErr("");
    setInfo("");

    // Invité : on crée le compte propriétaire ici même. Aucune demande n'est
    // envoyée tant que le compte n'est pas actif (le serveur la refuserait).
    if (invite) {
      const name = accName.trim();
      const em = accEmail.trim().toLowerCase();
      const fail = (m: string) => { setErr(m); setBusy(false); };
      if (!name) return fail(gp(lang, "acc_name_required"));
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(em)) return fail(gp(lang, "acc_email_invalid"));
      // Mêmes règles que /signup et que l'app (les modèles exigent 8 caractères).
      if (accPassword.length < 8 || !/[A-Z]/.test(accPassword) || !/[a-z]/.test(accPassword) || !/[0-9]/.test(accPassword)) {
        return fail(t("auth_error_password_rules"));
      }
      if (!acceptTerms) return fail(t("signup_terms_required"));
      saveDraft({ accName: name, ...locDraft(loc) });
      try {
        const res = await signup({
          name, email: em, password: accPassword, role: "owner", city: loc.city, lang,
          ...(referralCode ? { referralCode } : {}),
        });
        if (!res.needsVerification && res.token) {
          await publishAfterAccount(loc);
          return;
        }
        // Le serveur a envoyé le code : on le demande SUR PLACE.
        saveDraft({ accName: name, pendingEmail: em, ...locDraft(loc) });
        setPendingEmail(em);
        setCode("");
        setStep("code");
        trackSiteEvent("cta_click", { label: "pub_code_envoye" });
      } catch (e) {
        if (e instanceof ApiError && e.status === 409) {
          // Compte propriétaire déjà vérifié : on tente la connexion avec le
          // mot de passe saisi, et la demande part dans la foulée.
          try {
            await login(em, accPassword);
            trackSiteEvent("cta_click", { label: "pub_connexion" });
            await publishAfterAccount(loc);
            return;
          } catch {
            setErr(gp(lang, "taken"));
          }
        } else {
          setErr(e instanceof ApiError && e.message ? e.message : t("auth_error_generic"));
        }
      } finally {
        setBusy(false);
      }
      return;
    }

    try {
      await publishNow(false, loc);
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) {
        // Session expirée pendant la saisie : on garde le travail de la
        // personne plutôt que de le jeter avec elle vers /login.
        saveDraft(locDraft(loc));
        router.replace(`/login?next=${encodeURIComponent("/posts/create")}`);
        return;
      }
      setErr(e instanceof ApiError ? e.message : t("posts_error"));
    } finally {
      setBusy(false);
    }
  }

  /** Brouillon (jamais le mot de passe) : survit à un rechargement. */
  function saveDraft(extra: Record<string, unknown> = {}) {
    try {
      window.localStorage.setItem(DRAFT_KEY, JSON.stringify({
        body, services, serviceLocation: svcLocation, meetingPoint, startDate, endDate, notes,
        animalCount, animalTypes, city, budget, targetProvider: target,
        ...(cityCoords ? { cityLat: cityCoords.lat, cityLng: cityCoords.lng, cityLabel } : {}),
        ...extra,
      }));
    } catch { /* navigation privée : on continue sans mémoriser */ }
  }

  /** Ville résolue à mémoriser dans le brouillon (survit au code e-mail). */
  function locDraft(l: { city: string; lat?: number; lng?: number }): Record<string, unknown> {
    return typeof l.lat === "number" && typeof l.lng === "number"
      ? { city: l.city, cityLat: l.lat, cityLng: l.lng }
      : { city: l.city };
  }

  async function publishNow(fromGuest: boolean, locIn?: { city: string; lat?: number; lng?: number }) {
    // 616 — ville + coordonnées (location.lat/lng, lues par l'alerte 100 km).
    const loc = locIn || (cityCoords
      ? { city: city.trim(), lat: cityCoords.lat, lng: cityCoords.lng }
      : { city: city.trim() });
    const input = {
      body: body.trim(),
      serviceTypes: services,
      houseSittingVenue: needsVenue ? venue : undefined,
      serviceLocation: service ? locationToSend(service, svcLocation) : undefined,
      meetingPoint: svcLocation === "meeting_point" ? meetingPoint.trim() : undefined,
      startDate: startDate ? new Date(startDate).toISOString() : undefined,
      endDate: endDate ? new Date(endDate).toISOString() : undefined,
      notes: notes.trim() || undefined,
      animalCount: animalCount > 0 ? animalCount : undefined,
      animalTypes: animalTypes.length ? animalTypes : undefined,
      // Sans ville, aucun gardien n'est prévenu (cf. le commentaire plus haut).
      location: loc,
      // v587 — budget facultatif (rien envoyé sans montant).
      budget: budgetAmount > 0 ? budgetAmount : undefined,
      budgetCurrency: budgetAmount > 0 ? budgetCur : undefined,
      // 28/09 — « Demander à <prénom> » : ce prestataire est prévenu en premier.
      targetProvider: target || undefined,
    };
    // Avec photos → /posts/with-media (postType=request) ; sinon → /posts.
    if (photos.length > 0) {
      await createPostWithMedia(input, photos);
    } else {
      await createPost(input);
    }
    try { window.localStorage.removeItem(DRAFT_KEY); } catch { /* ignore */ }
    trackSiteEvent("cta_click", { label: fromGuest ? "pub_publiee" : "pub_publiee_membre" });
    if (target) trackSiteEvent("cta_click", { label: "pub_pour_prestataire" });
    router.push("/posts");
  }

  /** Compte actif (code validé ou connexion) : la demande part toute seule. */
  async function publishAfterAccount(locIn?: { city: string; lat?: number; lng?: number }) {
    setInvite(false);
    setRole("owner");
    setStep("form");
    setInfo(gp(lang, "publishing"));
    saveDraft(locIn ? locDraft(locIn) : {});
    try {
      await publishNow(true, locIn);
    } catch {
      setInfo("");
      setErr(gp(lang, "after_fail"));
    }
  }

  async function onVerify(e: React.FormEvent) {
    e.preventDefault();
    const c = code.replace(/\s/g, "");
    if (!/^\d{6}$/.test(c)) {
      setErr(gp(lang, "code_invalid"));
      return;
    }
    setBusy(true);
    setErr("");
    setInfo("");
    try {
      await verifyEmail(pendingEmail, c, "owner");
    } catch {
      setErr(gp(lang, "code_invalid"));
      setBusy(false);
      return;
    }
    trackSiteEvent("cta_click", { label: "pub_code_ok" });
    try {
      await publishAfterAccount();
    } finally {
      setBusy(false);
    }
  }

  async function onResend() {
    setErr("");
    setInfo("");
    try {
      await resendVerificationCode(pendingEmail);
      setInfo(gp(lang, "code_resent"));
      trackSiteEvent("cta_click", { label: "pub_code_renvoye" });
    } catch (e) {
      setErr(e instanceof ApiError && e.message ? e.message : t("auth_error_generic"));
    }
  }

  function onChangeEmail() {
    setStep("form");
    setPendingEmail("");
    setCode("");
    setErr("");
    setInfo("");
    saveDraft({ accName });
  }

  function accountStarted() {
    if (accStarted.current) return;
    accStarted.current = true;
    trackSiteEvent("cta_click", { label: "pub_compte" });
  }

  // Les owners seuls publient des annonces (le backend renvoie 403 sinon).
  if (role && role !== "owner") {
    return (
      <div className="mx-auto max-w-md px-4 py-24 text-center">
        <p className="text-sm text-ink-muted">{t("posts_owner_only")}</p>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-lg px-4 py-16 md:py-24">
      <h1 className="text-center font-display text-3xl font-extrabold tracking-tight md:text-4xl">
        {t("posts_create_title")}
      </h1>

      {step === "code" ? (
        <form
          onSubmit={onVerify}
          data-testid="guest-code"
          className="mt-10 space-y-4 rounded-3xl border border-owner/20 bg-white p-7 shadow-card"
        >
          <h2 className="text-center font-display text-xl font-extrabold text-ink">{gp(lang, "code_title")}</h2>
          <p className="text-center text-sm leading-relaxed text-[#6E4F48]">
            {gp(lang, "code_sub").replace("{email}", pendingEmail)}
          </p>
          <div>
            <label htmlFor="guest-code-input" className="block text-sm font-medium text-ink">{gp(lang, "code_label")}</label>
            <input
              id="guest-code-input"
              value={code}
              onChange={(e) => setCode(e.target.value.replace(/[^0-9]/g, "").slice(0, 6))}
              inputMode="numeric"
              autoComplete="one-time-code"
              autoFocus
              maxLength={6}
              placeholder="123456"
              className="mt-1.5 w-full rounded-xl border border-ink/15 bg-bg-soft px-3.5 py-3 text-center font-display text-2xl font-extrabold tracking-[0.4em] text-ink focus:border-owner focus:outline-none"
            />
          </div>
          <button
            disabled={busy}
            className="w-full rounded-full bg-owner py-3 text-sm font-semibold text-white shadow-cta hover:bg-owner-dark disabled:opacity-60"
          >
            {busy ? gp(lang, "publishing") : gp(lang, "code_submit")}
          </button>
          <div className="flex flex-wrap items-center justify-center gap-x-5 gap-y-2 text-sm">
            <button type="button" onClick={onResend} className="font-semibold text-owner-dark underline max-lg:min-h-[44px]">
              {gp(lang, "code_resend")}
            </button>
            <button type="button" onClick={onChangeEmail} className="font-semibold text-owner-dark underline max-lg:min-h-[44px]">
              {gp(lang, "code_change")}
            </button>
          </div>
          <p className="text-center text-xs text-[#6E4F48]">{gp(lang, "code_spam")} {gp(lang, "code_kept")}</p>
          {info && <p className="text-center text-sm font-semibold text-owner-dark">{info}</p>}
          {err && <p className="text-center text-sm text-owner-dark">{err}</p>}
        </form>
      ) : (
      <form
        onSubmit={onSubmit}
        className="mt-10 space-y-5 rounded-3xl border border-ink/5 bg-white p-7 shadow-card"
      >
        {/* 28/09 soir — demande adressée à un prestataire précis. */}
        {target && targetName && (
          <div data-testid="target-provider" className="flex items-start gap-3 rounded-2xl border border-owner/25 bg-owner-light p-4">
            <span
              className="grid h-10 w-10 shrink-0 place-items-center rounded-full font-display text-base font-extrabold text-white"
              style={{ background: target.role === "walker" ? "linear-gradient(90deg,#15803D,#166534)" : "linear-gradient(90deg,#2563EB,#1E4FB0)" }}
              aria-hidden
            >
              {targetName.charAt(0).toUpperCase()}
            </span>
            <div className="min-w-0 flex-1">
              <p className="font-display text-base font-extrabold text-owner-dark">{gp(lang, "for_title").replace("{name}", targetName)}</p>
              <p className="mt-0.5 text-xs leading-snug text-[#6E4F48]">{gp(lang, "for_sub").replace("{name}", targetName)}</p>
              <button
                type="button"
                onClick={() => { setTarget(null); setTargetName(""); }}
                className="mt-1.5 text-xs font-semibold text-owner-dark underline max-lg:min-h-[44px]"
              >
                {gp(lang, "for_remove")}
              </button>
            </div>
          </div>
        )}

        {/* 616 — ville choisie dans la liste (suggestions) ou « Ma position ». */}
        <CityAutocomplete616
          lang={lang}
          label={t("posts_city_label")}
          placeholder={t("posts_city_ph")}
          value={city}
          coords={cityCoords}
          pickedLabel={cityLabel}
          onChange={(c, co, lb) => {
            setCity(c);
            setCityCoords(co);
            setCityLabel(co ? lb || "" : "");
          }}
        />

        <div>
          <label className="block text-sm font-medium text-ink">{t("posts_body_label")}</label>
          <textarea
            value={body}
            onChange={(e) => setBody(e.target.value)}
            required
            rows={4}
            placeholder={t("posts_body_ph")}
            className="mt-1.5 w-full rounded-xl border border-ink/15 bg-bg-soft px-3.5 py-2.5 text-sm text-ink focus:border-owner focus:outline-none"
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-ink">{t("posts_services_label")}</label>
          <div className="mt-2 flex flex-wrap gap-2">
            {POST_SERVICE_TYPES.map((s) => (
              <button
                key={s}
                type="button"
                onClick={() => toggleService(s)}
                className={`rounded-full border px-4 py-2 text-sm font-semibold transition max-lg:min-h-[44px] ${
                  services.includes(s)
                    ? "border-owner bg-owner-light text-owner-dark"
                    : "border-ink/15 bg-white text-ink hover:border-ink/30"
                }`}
              >
                {svcLabel(s)}
              </button>
            ))}
          </div>
        </div>

        {service && (
          <ServiceLocationPicker587
            lang={lang}
            service={service}
            value={svcLocation}
            meetingPoint={meetingPoint}
            onChange={(v) => setSvcLocation(v)}
            onMeetingPoint={setMeetingPoint}
            accent="#C92A12"
            dark="#9E1F0B"
            pale="#FBE9E5"
          />
        )}

        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="block text-sm font-medium text-ink">{t("posts_start_label")}</label>
            <input
              type="date"
              value={startDate}
              onChange={(e) => setStartDate(e.target.value)}
              className="mt-1.5 w-full rounded-xl border border-ink/15 bg-bg-soft px-3 py-2.5 text-sm text-ink focus:border-owner focus:outline-none"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-ink">{t("posts_end_label")}</label>
            <input
              type="date"
              value={endDate}
              onChange={(e) => setEndDate(e.target.value)}
              className="mt-1.5 w-full rounded-xl border border-ink/15 bg-bg-soft px-3 py-2.5 text-sm text-ink focus:border-owner focus:outline-none"
            />
          </div>
        </div>

        {/* v587 (option A de Daniel) — « Mon budget », facultatif. */}
        <div data-testid="budget587">
          <label htmlFor="budget587" className="block text-sm font-medium text-ink">{t("b587_title")}</label>
          <p className="mt-0.5 text-xs leading-snug text-[#6E4F48]">{t("b587_sub")}</p>
          <div className="relative mt-1.5">
            <input
              id="budget587"
              type="text"
              inputMode="decimal"
              maxLength={8}
              value={budget}
              onChange={(e) => setBudget(e.target.value.replace(/[^0-9.,]/g, ""))}
              placeholder={t("b587_hint")}
              className="w-full rounded-xl border border-ink/15 bg-bg-soft py-2.5 pl-3.5 pr-14 text-sm font-semibold text-ink focus:border-owner focus:outline-none"
            />
            <span className="pointer-events-none absolute inset-y-0 right-3.5 flex items-center text-sm font-extrabold text-[#C92A12]">{({ EUR: "€", USD: "$", GBP: "£", CHF: "CHF", KRW: "₩", JPY: "¥" } as Record<string, string>)[budgetCur] || budgetCur}</span>
          </div>
        </div>

        <div>
          <label className="block text-sm font-medium text-ink">{t("posts_notes_label")}</label>
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            rows={2}
            placeholder={t("posts_notes_ph")}
            className="mt-1.5 w-full rounded-xl border border-ink/15 bg-bg-soft px-3.5 py-2.5 text-sm text-ink focus:border-owner focus:outline-none"
          />
        </div>

        {/* v404 — Animaux concernés : nombre + types */}
        <div>
          <label className="block text-sm font-medium text-ink">{t("posts_animals_label")}</label>
          <div className="mt-2 flex items-center gap-3">
            <input
              type="number"
              min={1}
              max={50}
              value={animalCount}
              onChange={(e) => setAnimalCount(Math.max(1, Math.min(50, Number(e.target.value) || 1)))}
              className="w-20 rounded-xl border border-ink/15 bg-bg-soft px-3 py-2.5 text-center text-sm text-ink focus:border-owner focus:outline-none"
            />
            <span className="text-sm text-ink-muted">{t("posts_animals_count_hint")}</span>
          </div>
          <div className="mt-3 flex flex-wrap gap-2">
            {ANIMAL_TYPES.map((a) => (
              <button
                key={a.key}
                type="button"
                onClick={() => toggleAnimalType(a.key)}
                className={`rounded-full border px-3.5 py-2 text-sm font-semibold transition max-lg:min-h-[44px] ${
                  animalTypes.includes(a.key)
                    ? "border-owner bg-owner-light text-owner-dark"
                    : "border-ink/15 bg-white text-ink hover:border-ink/30"
                }`}
              >
                {a.emoji} {animalTypeLabel(a.key)}
              </button>
            ))}
          </div>
        </div>

        {/* v402 — Photos de l'annonce (ajouter / supprimer avant publication).
            28/09 : visibles aussi pour l'invité, qui ne quitte plus cette
            page pour créer son compte (les photos restent en mémoire). */}
        <div>
          <label className="block text-sm font-medium text-ink">{t("posts_photos_label")}</label>
          <div className="mt-2 flex flex-wrap gap-3">
            {photos.map((f, i) => (
              <div key={i} className="relative h-20 w-20 overflow-hidden rounded-xl border border-ink/10">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={URL.createObjectURL(f)} alt="" className="h-full w-full object-cover" />
                <button
                  type="button"
                  onClick={() => removePhoto(i)}
                  aria-label="remove"
                  className="absolute right-0.5 top-0.5 flex h-5 w-5 items-center justify-center rounded-full bg-black/60 text-xs text-white"
                >
                  ✕
                </button>
              </div>
            ))}
            {photos.length < 10 && (
              <label className="flex h-20 w-20 cursor-pointer items-center justify-center rounded-xl border-2 border-dashed border-ink/20 text-2xl text-ink-muted transition hover:border-owner hover:text-owner">
                +
                <input type="file" accept="image/*" multiple onChange={addPhotos} className="hidden" />
              </label>
            )}
          </div>
          <p className="mt-1 text-xs text-ink-muted">{t("posts_photos_hint")}</p>
        </div>

        {/* 28/09 (NEO) — le compte, sur le même écran que la demande. */}
        {invite && (
          <div data-testid="guest-account" className="space-y-4 rounded-2xl border border-owner/25 bg-owner-light p-5">
            <div>
              <p className="font-display text-base font-extrabold text-owner-dark">{gp(lang, "acc_title")}</p>
              <p className="mt-0.5 text-xs leading-snug text-[#6E4F48]">{gp(lang, "acc_sub")}</p>
            </div>
            <div>
              <label htmlFor="acc-name" className="block text-sm font-medium text-ink">{gp(lang, "acc_name")}</label>
              <input id="acc-name" value={accName} onFocus={accountStarted} onChange={(e) => setAccName(e.target.value)}
                autoComplete="given-name" className="mt-1.5 w-full rounded-xl border border-ink/15 bg-white px-3.5 py-2.5 text-sm text-ink focus:border-owner focus:outline-none" />
            </div>
            <div>
              <label htmlFor="acc-email" className="block text-sm font-medium text-ink">{gp(lang, "acc_email")}</label>
              <input id="acc-email" type="email" value={accEmail} onFocus={accountStarted} onChange={(e) => setAccEmail(e.target.value)}
                autoComplete="email" inputMode="email" className="mt-1.5 w-full rounded-xl border border-ink/15 bg-white px-3.5 py-2.5 text-sm text-ink focus:border-owner focus:outline-none" />
            </div>
            <div>
              <label htmlFor="acc-pwd" className="block text-sm font-medium text-ink">{gp(lang, "acc_password")}</label>
              <div className="relative">
                <input id="acc-pwd" type={showPwd ? "text" : "password"} value={accPassword} onFocus={accountStarted}
                  onChange={(e) => setAccPassword(e.target.value)} autoComplete="new-password"
                  className="mt-1.5 w-full rounded-xl border border-ink/15 bg-white px-3.5 py-2.5 text-sm text-ink focus:border-owner focus:outline-none pr-11" />
                <button type="button" onClick={() => setShowPwd((v) => !v)} aria-label={showPwd ? "hide" : "show"}
                  className="absolute right-3 top-1/2 mt-[3px] -translate-y-1/2 text-owner-dark">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7S1 12 1 12z"/><circle cx="12" cy="12" r="3"/>{showPwd && <line x1="2" y1="2" x2="22" y2="22"/>}</svg>
                </button>
              </div>
              <p className="mt-1 text-xs leading-snug text-[#6E4F48]">{gp(lang, "acc_pwd_hint")}</p>
            </div>
            <label className="flex items-start gap-2.5 text-sm text-ink">
              <input type="checkbox" checked={acceptTerms} onChange={(e) => setAcceptTerms(e.target.checked)}
                className="mt-0.5 h-4 w-4 shrink-0 accent-owner" />
              <span>
                {t("signup_terms_accept")}{" "}
                <Link href="/terms" className="font-semibold text-owner-dark underline">{t("terms_title")}</Link>
                {" · "}
                <Link href="/privacy" className="font-semibold text-owner-dark underline">{t("privacy_title")}</Link>
              </span>
            </label>
          </div>
        )}

        {/* 29/09 (NEO) — qui va lire la demande : chiffre vrai, rien si 0. */}
        <ProofNearButton2909 city={city} lang={lang} />
        <button
          disabled={busy}
          className="w-full rounded-full bg-owner py-3 text-sm font-semibold text-white shadow-cta hover:bg-owner-dark disabled:opacity-60"
        >
          {busy ? t("posts_publishing") : invite ? gp(lang, "acc_cta") : t("posts_submit")}
        </button>
        {invite && (
          <p className="text-center text-sm text-[#6E4F48]">
            {t("signup_have")}{" "}
            <Link
              href={`/login?next=${encodeURIComponent("/posts/create")}`}
              onClick={() => saveDraft({ accName })}
              className="font-semibold text-owner-dark underline"
            >
              {t("signup_login_link")}
            </Link>
          </p>
        )}
        {info && <p className="text-center text-sm font-semibold text-owner-dark">{info}</p>}
        {err && <p className="text-center text-sm text-owner-dark">{err}</p>}
        <p className="text-center text-xs text-ink-muted">{t("posts_no_contact_info")}</p>
      </form>
      )}
    </div>
  );
}
