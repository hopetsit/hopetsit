"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { trackSiteEvent, useCampaignHref } from "@/components/SiteAnalytics";
import { EstimateLine620 } from "@/components/DateMode620";

// 12/10/2026 (SAM) — CHANGEMENT D'APPROCHE sur la page où arrive la pub Paris.
// Mesure du 12/10 (admin « Trafic du site », 7 jours, visiteurs de la pub
// paris_owners) : 956 arrivées → 250 restent 3 s → 8 clics « Publier ma
// demande » → 15 formulaires ouverts → 0 étape 2 → 0 demande. Le bouton seul
// (08/10) puis le formulaire en 2 étapes (11/10) n'ont pas fait bouger le
// 1er clic : 99 % des visiteurs ne cliquent jamais. Ordre de Daniel du 08/10 :
// « si après 3 jours il n'y a toujours aucun formulaire ouvert, tu changes
// d'approche, tu ne repeins pas le même bouton ».
//
// Désormais le PREMIER ÉCRAN EST LE FORMULAIRE : service (un tap), dates, une
// phrase, « Continuer ». Plus rien à cliquer avant de commencer. « Continuer »
// enregistre le brouillon (même clé que /posts/create : hopetsit_post_draft_v1)
// et ouvre /posts/create?etape=2 — l'étape 2 = compte invité + « Publier ».
// Le lieu est pré-rempli d'après le service (garde à domicile = chez moi,
// promenade = le promeneur vient chercher le chien) ; « Modifier ma demande »
// à l'étape 2 permet de le changer.
//
// Mesure : « hero_form_service » (1er tap sur un service, = le visiteur a
// commencé), « signup_web_hero » (Continuer, compté « publier » comme avant),
// puis pub_ouvert / pub_etape2 / pub_compte / pub_publiee sur /posts/create.
// Retour arrière : remettre <ParisHeroCta> dans (fr)/garde-animaux/paris/page.tsx.
const DRAFT_KEY = "hopetsit_post_draft_v1";

const SERVICES: { id: string; label: string; icon: string; location: string }[] = [
  { id: "house_sitting", label: "Garde à domicile", icon: "🏠", location: "at_owner" },
  { id: "dog_walking", label: "Promenade", icon: "🐕", location: "pickup" },
  { id: "day_care", label: "Garderie de jour", icon: "☀️", location: "at_sitter" },
];

export function ParisHeroForm({ city, lead, note }: { city: string; lead: string; note: string }) {
  // Tous les hooks AVANT tout retour (règle de l'équipe : un hook après un
  // retour conditionnel plante la page en production sans que tsc le voie).
  const router = useRouter();
  const [service, setService] = useState("");
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [body, setBody] = useState("");
  const [err, setErr] = useState("");
  const [busy, setBusy] = useState(false);
  const [started, setStarted] = useState(false);
  const [touched, setTouched] = useState(false);
  const href = useCampaignHref(`/posts/create?city=${encodeURIComponent(city)}&etape=2&from=hero`);

  // 13/10 (SAM) : 1re interaction de TOUTE sorte dans le formulaire (date,
  // phrase, service ou « Continuer »). Avant, seul le tap sur un service était
  // compté : un visiteur qui commençait par la date ou la phrase restait
  // invisible, et « 0 tap » ne prouvait pas que personne ne touchait au formulaire.
  // 15/10 (SAM) : écouté sur click/focus, plus sur pointerdown — sur téléphone un
  // DÉFILEMENT qui commence sur le formulaire déclenchait pointerdown : le 14/10,
  // 119 « taps » pub pour 44 lectures de 3 s et 0 service choisi = des défilements.
  function touch() {
    if (touched) return;
    setTouched(true);
    trackSiteEvent("cta_click", { label: "hero_form_touche" });
  }

  function pick(id: string) {
    setErr("");
    setService((cur) => (cur === id ? "" : id));
    if (!started) {
      setStarted(true);
      trackSiteEvent("cta_click", { label: "hero_form_service" });
    }
  }

  function onContinue() {
    setErr("");
    if (!service || !body.trim()) {
      // Clic sur « Continuer » refusé : compté pour voir si le formulaire bloque.
      trackSiteEvent("cta_click", { label: !service ? "hero_form_sans_service" : "hero_form_sans_phrase" });
      return setErr(!service ? "Choisissez un service." : "Décrivez votre besoin en une phrase.");
    }
    const svc = SERVICES.find((s) => s.id === service);
    try {
      window.localStorage.setItem(DRAFT_KEY, JSON.stringify({
        body: body.trim(),
        services: [service],
        serviceLocation: svc?.location || "",
        meetingPoint: "",
        startDate,
        endDate,
        notes: "",
        animalCount: 1,
        animalTypes: [],
        city,
        budget: "",
        targetProvider: null,
        fromHero: true,
      }));
    } catch { /* navigation privée : le formulaire repart de l'étape 1, pré-rempli par ?city= */ }
    trackSiteEvent("cta_click", { label: "signup_web_hero" });
    setBusy(true);
    router.push(href);
  }

  const field = "mt-1 w-full rounded-xl border border-ink/15 bg-white px-3 py-2.5 text-sm text-ink focus:border-owner focus:outline-none";

  return (
    <div className="mt-3 rounded-3xl border border-owner/20 bg-owner-light/60 p-4 md:mx-auto md:max-w-md" data-testid="hero-form" onClickCapture={touch} onFocusCapture={touch}>
      <p className="text-[15px] font-semibold leading-snug text-ink md:text-base">{lead}</p>

      <div className="mt-3 grid grid-cols-3 gap-2" role="group" aria-label="Service">
        {SERVICES.map((s) => (
          <button
            key={s.id}
            type="button"
            onClick={() => pick(s.id)}
            aria-pressed={service === s.id}
            className={`min-h-[56px] rounded-2xl border px-1.5 py-2 text-center text-[12px] font-bold leading-tight transition ${
              service === s.id ? "border-owner bg-owner text-white shadow-card" : "border-ink/10 bg-white text-ink"
            }`}
          >
            <span aria-hidden className="block text-base leading-none">{s.icon}</span>
            <span className="mt-1 block">{s.label}</span>
          </button>
        ))}
      </div>

      <div className="mt-3 grid grid-cols-2 gap-2">
        <label className="block text-xs font-semibold text-ink">
          Du
          <input type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} className={field} />
        </label>
        <label className="block text-xs font-semibold text-ink">
          Au
          <input type="date" value={endDate} onChange={(e) => setEndDate(e.target.value)} className={field} />
        </label>
      </div>

      {/* 24/10/2026 (LEO, ordre de BOB 23 h 10) — « à partir de X €/jour · estimation ~Y € · d'après N
          gardiens » dès qu'un service est choisi (dates → total), via la route publique de ZOE pour le
          visiteur sans compte (route authentifiée si connecté). Rien quand personne n'est inscrit autour. */}
      {service && (
        <div className="mt-3">
          <EstimateLine620
            lang="fr"
            service={service}
            dateMode={startDate && endDate ? "exact" : "tbd"}
            startDate={startDate}
            endDate={endDate}
            visitsPerDay={1}
            venue={service === "house_sitting" ? "owners_home" : null}
            currency="EUR"
            location={{ city }}
          />
        </div>
      )}

      <label className="mt-3 block text-xs font-semibold text-ink">
        Votre besoin, en une phrase
        <input
          value={body}
          onChange={(e) => setBody(e.target.value)}
          maxLength={500}
          placeholder="Ex. : garder mon chat 5 jours pendant les vacances"
          className={field}
          onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); onContinue(); } }}
        />
      </label>

      {err && <p className="mt-2 text-center text-sm font-semibold text-owner-dark">{err}</p>}

      <button
        id="hero-publier"
        type="button"
        onClick={onContinue}
        disabled={busy}
        data-testid="hero-continuer"
        className="mt-3 block w-full rounded-full bg-owner px-6 py-4 text-center text-lg font-extrabold text-white shadow-card disabled:opacity-70"
      >
        {busy ? "Un instant…" : "Continuer — gratuit"}
      </button>
      <p className="mt-2 text-center text-xs text-ink-soft">{note}</p>
    </div>
  );
}

export default ParisHeroForm;
