"use client";

import { useEffect, useState } from "react";
import { API_BASE } from "@/lib/api";
import { trackSiteEvent } from "@/components/SiteAnalytics";
import { providerCurrency, providerFrom, formatMoney, type ProviderRateSource } from "@/lib/providerRates";

// 22/09/2026 — PREUVE D'OFFRE RÉELLE sur les pages villes propriétaires.
//
// ⚠️ 22/09 au soir — le mot « vérifié » a été RETIRÉ de ces phrases : la route
// /supply/city exclut les comptes de test, masqués et bannis, mais PAS ceux qui
// n'ont jamais validé leur e-mail (2 gardiens sur 7 en Île-de-France). Annoncer
// « gardiens vérifiés » était faux. Le nombre, lui, est exact.
//
// Mesure du 22/09 : /garde-animaux/paris a reçu 52 visiteurs (toute la pub
// Meta « Paris · Propriétaires ») et ZÉRO clic, sur aucun bouton. La page
// promet « un pet-sitter vérifié près de chez toi » sans montrer qu'il existe
// le moindre gardien. On affiche donc un nombre VRAI, compté en direct.
//
// Règles tenues ici :
//   - la route publique /supply/city ne renvoie QUE des nombres (aucun nom,
//     aucune photo, aucune position) ;
//   - si le compte est à zéro, si l'appel échoue ou tarde, le bloc ne
//     s'affiche pas du tout : jamais de « 0 gardien », jamais de chiffre
//     inventé, et la page reste exactement comme avant ;
//   - rendu côté client uniquement : le HTML servi à Google ne change pas.
type N = { sitters: number; walkers: number; city: string };

// 26/09/2026 (SAM) — 3 VRAIS VISAGES au-dessus du nombre. Route publique
// /supply/city/faces : prénom, photo, ville, note — exactement ce que la fiche
// publique /p/<rôle>/<id> montre déjà. Pas de photo → pas de carte ; erreur
// ou lenteur → rien ne s'affiche (la page reste comme avant).
type Face = { id: string; role: "sitter" | "walker"; firstName: string; photo: string; city: string; rating: number; verified: boolean; price?: string };

// 28/09/2026 (SAM, mission BOB) — LE PRIX sur chaque carte. 106 visiteurs de
// la pub en 36 h → 0 clic : des visages sans prix ne répondent pas à « combien
// ça coûte près de chez moi ? ». Le tarif vient de la fiche PUBLIQUE du
// prestataire (GET /sitters/:id, /walkers/:id — la même que /p/<rôle>/<id>),
// et on n'en lit QUE les tarifs. Même règle que la fiche (providerRates.ts) :
// un tarif absent ou à 0 n'existe pas → pas de prix affiché, jamais inventé.
// On demande 6 visages et on garde d'abord ceux qui ont un prix.
async function tarif(f: Face, lang: string, units: Record<string, string>, signal: AbortSignal): Promise<string | undefined> {
  try {
    const r = await fetch(`${API_BASE}/${f.role}s/${f.id}`, { signal });
    if (!r.ok) return undefined;
    const d = await r.json();
    const src = (d && (d.sitter || d.walker)) as ProviderRateSource | undefined;
    if (!src) return undefined;
    const des = providerFrom(f.role, src);
    if (!des) return undefined;
    return `${formatMoney(des.value, providerCurrency(src), lang)}/${units[des.unitKey] || ""}`;
  } catch {
    return undefined;
  }
}
const ROLE: Record<string, { sitter: string; walker: string; verified: string; see: string; units: Record<string, string> }> = {
  fr: { sitter: "Gardien·ne", walker: "Promeneur·se", verified: "Identité vérifiée", see: "Voir le profil", units: { unit_day: "jour", unit_hour: "heure", unit_week: "semaine", unit_month: "mois", unit_30: "30 min", unit_60: "1 h", unit_120: "2 h" } },
  en: { sitter: "Pet sitter", walker: "Dog walker", verified: "ID verified", see: "View profile", units: { unit_day: "day", unit_hour: "hour", unit_week: "week", unit_month: "month", unit_30: "30 min", unit_60: "1 hr", unit_120: "2 hrs" } },
  es: { sitter: "Cuidador/a", walker: "Paseador/a", verified: "Identidad verificada", see: "Ver perfil", units: { unit_day: "día", unit_hour: "hora", unit_week: "semana", unit_month: "mes", unit_30: "30 min", unit_60: "1 h", unit_120: "2 h" } },
  de: { sitter: "Tiersitter", walker: "Gassigeher", verified: "Identität geprüft", see: "Profil ansehen", units: { unit_day: "Tag", unit_hour: "Std.", unit_week: "Woche", unit_month: "Monat", unit_30: "30 Min.", unit_60: "1 Std.", unit_120: "2 Std." } },
  it: { sitter: "Pet sitter", walker: "Dog walker", verified: "Identità verificata", see: "Vedi profilo", units: { unit_day: "giorno", unit_hour: "ora", unit_week: "settimana", unit_month: "mese", unit_30: "30 min", unit_60: "1 h", unit_120: "2 h" } },
  pt: { sitter: "Cuidador/a", walker: "Passeador/a", verified: "Identidade verificada", see: "Ver perfil", units: { unit_day: "dia", unit_hour: "hora", unit_week: "semana", unit_month: "mês", unit_30: "30 min", unit_60: "1 h", unit_120: "2 h" } },
  pl: { sitter: "Opiekun/ka", walker: "Wyprowadzacz/ka", verified: "Tożsamość zweryfikowana", see: "Zobacz profil", units: { unit_day: "dzień", unit_hour: "godz.", unit_week: "tydzień", unit_month: "miesiąc", unit_30: "30 min", unit_60: "1 godz.", unit_120: "2 godz." } },
  ko: { sitter: "펫시터", walker: "산책 도우미", verified: "신원 확인됨", see: "프로필 보기", units: { unit_day: "일", unit_hour: "시간", unit_week: "주", unit_month: "월", unit_30: "30분", unit_60: "1시간", unit_120: "2시간" } },
  ja: { sitter: "シッター", walker: "散歩スタッフ", verified: "本人確認済み", see: "プロフィールを見る", units: { unit_day: "日", unit_hour: "時間", unit_week: "週", unit_month: "月", unit_30: "30分", unit_60: "1時間", unit_120: "2時間" } },
};

// Les 9 langues du site. Ces textes vivent ICI et pas dans OwnerCityPage :
// Next.js interdit de passer une fonction d'un composant serveur à un
// composant client (le build échoue). On passe donc la langue.
const LIGNE: Record<string, (n: N) => string> = {
  fr: (n: N) => {
      const g = n.sitters > 1 ? `${n.sitters} gardiens` : `${n.sitters} gardien`;
      const p = n.walkers > 1 ? `${n.walkers} promeneurs` : `${n.walkers} promeneur`;
      if (!n.walkers) return `${g} déjà inscrits autour de ${n.city}`;
      if (!n.sitters) return `${p} déjà inscrits autour de ${n.city}`;
      return `${g} et ${p} déjà inscrits autour de ${n.city}`;
    },
  en: (n: N) => {
      const g = n.sitters > 1 ? `${n.sitters} sitters` : `${n.sitters} sitter`;
      const p = n.walkers > 1 ? `${n.walkers} dog walkers` : `${n.walkers} dog walker`;
      if (!n.walkers) return `${g} already signed up around ${n.city}`;
      if (!n.sitters) return `${p} already signed up around ${n.city}`;
      return `${g} and ${p} already signed up around ${n.city}`;
    },
  es: (n: N) => {
      const g = n.sitters > 1 ? `${n.sitters} cuidadores` : `${n.sitters} cuidador`;
      const p = n.walkers > 1 ? `${n.walkers} paseadores` : `${n.walkers} paseador`;
      if (!n.walkers) return `${g} ya registrados cerca de ${n.city}`;
      if (!n.sitters) return `${p} ya registrados cerca de ${n.city}`;
      return `${g} y ${p} ya registrados cerca de ${n.city}`;
    },
  de: (n: N) => {
      const g = n.sitters > 1 ? `${n.sitters} Sitter` : `${n.sitters} Sitter`;
      const p = n.walkers > 1 ? `${n.walkers} Gassigeher` : `${n.walkers} Gassigeher`;
      if (!n.walkers) return `${g} bereits rund um ${n.city} angemeldet`;
      if (!n.sitters) return `${p} bereits rund um ${n.city} angemeldet`;
      return `${g} und ${p} bereits rund um ${n.city} angemeldet`;
    },
  it: (n: N) => {
      const g = n.sitters > 1 ? `${n.sitters} sitter` : `${n.sitters} sitter`;
      const p = n.walkers > 1 ? `${n.walkers} dog sitter per passeggiate` : `${n.walkers} dog sitter per passeggiate`;
      if (!n.walkers) return `${g} già iscritti intorno a ${n.city}`;
      if (!n.sitters) return `${p} già iscritti intorno a ${n.city}`;
      return `${g} e ${p} già iscritti intorno a ${n.city}`;
    },
  pt: (n: N) => {
      const g = n.sitters > 1 ? `${n.sitters} cuidadores` : `${n.sitters} cuidador`;
      const p = n.walkers > 1 ? `${n.walkers} passeadores` : `${n.walkers} passeador`;
      if (!n.walkers) return `${g} já inscritos perto de ${n.city}`;
      if (!n.sitters) return `${p} já inscritos perto de ${n.city}`;
      return `${g} e ${p} já inscritos perto de ${n.city}`;
    },
  pl: (n: N) => {
      const g = `${n.sitters} opiekunów`;
      const p = `${n.walkers} wyprowadzaczy psów`;
      if (!n.walkers) return `${g} już zapisanych w okolicy ${n.city}`;
      if (!n.sitters) return `${p} już zapisanych w okolicy ${n.city}`;
      return `${g} i ${p} już zapisanych w okolicy ${n.city}`;
    },
  ko: (n: N) => {
      if (!n.walkers) return `${n.city} 주변에 펫시터 ${n.sitters}명이 등록되어 있어요`;
      if (!n.sitters) return `${n.city} 주변에 산책 도우미 ${n.walkers}명이 등록되어 있어요`;
      return `${n.city} 주변에 펫시터 ${n.sitters}명과 산책 도우미 ${n.walkers}명이 등록되어 있어요`;
    },
  ja: (n: N) => {
      if (!n.walkers) return `${n.city}の近くにシッターが${n.sitters}人登録しています`;
      if (!n.sitters) return `${n.city}の近くに散歩スタッフが${n.walkers}人登録しています`;
      return `${n.city}の近くにシッターが${n.sitters}人、散歩スタッフが${n.walkers}人登録しています`;
    },
};

export function CitySupplyProof({
  city,
  lat,
  lng,
  lang,
}: {
  city: string;
  lat?: number;
  lng?: number;
  lang: string;
}) {
  const [n, setN] = useState<{ sitters: number; walkers: number } | null>(null);
  const [faces, setFaces] = useState<Face[]>([]);

  useEffect(() => {
    let vivant = true;
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), 7000);
    const units = (ROLE[lang] || ROLE.en).units;
    fetch(`${API_BASE}/supply/city/faces?${new URLSearchParams({ city, limit: "6" })}`, { signal: ctrl.signal })
      .then((r) => (r.ok ? r.json() : null))
      .then(async (d) => {
        if (!vivant || !d || !Array.isArray(d.faces)) return;
        const base: Face[] = d.faces.filter((f: Face) => f && f.id && f.photo && f.firstName).slice(0, 6);
        const prix = await Promise.all(base.map((f) => tarif(f, lang, units, ctrl.signal)));
        if (!vivant) return;
        const avec = base.map((f, i) => ({ ...f, price: prix[i] }));
        // Ceux qui ont un prix d'abord (ordre du serveur conservé sinon).
        setFaces([...avec.filter((f) => f.price), ...avec.filter((f) => !f.price)].slice(0, 3));
      })
      .catch(() => {})
      .finally(() => clearTimeout(t));
    return () => {
      vivant = false;
      ctrl.abort();
      clearTimeout(t);
    };
  }, [city, lang]);

  useEffect(() => {
    let vivant = true;
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), 6000);
    const q = new URLSearchParams({ city });
    if (Number.isFinite(lat) && Number.isFinite(lng)) {
      q.set("lat", String(lat));
      q.set("lng", String(lng));
    }
    fetch(`${API_BASE}/supply/city?${q.toString()}`, { signal: ctrl.signal })
      .then((r) => (r.ok ? r.json() : null))
      .then((d) => {
        if (!vivant || !d) return;
        const sitters = Number(d.sitters) || 0;
        const walkers = Number(d.walkers) || 0;
        if (sitters + walkers > 0) setN({ sitters, walkers });
      })
      .catch(() => {
        /* hors ligne, serveur en veille, requête annulée → on n'affiche rien */
      })
      .finally(() => clearTimeout(t));
    return () => {
      vivant = false;
      ctrl.abort();
      clearTimeout(t);
    };
  }, [city, lat, lng]);

  const label = LIGNE[lang] || LIGNE.en;
  const roles = ROLE[lang] || ROLE.en;
  if (!n && !faces.length) return null;

  return (
    <>
    {n && (
    <p className="mt-4 flex items-center gap-2 text-sm font-semibold text-owner-dark">
      <span
        aria-hidden
        className="inline-block h-2 w-2 shrink-0 rounded-full bg-[#16A34A]"
      />
      {label({ ...n, city })}
    </p>
    )}
    {faces.length > 0 && (
      <ul className="mt-3 grid gap-2.5 md:grid-cols-3" aria-label={n ? label({ ...n, city }) : undefined}>
        {faces.map((f) => {
          const walker = f.role === "walker";
          // Mesure : un label par rôle, lisible dans /admin/site-analytics (byCta).
          const clic = () => trackSiteEvent("cta_click", { label: walker ? "carte_promeneur" : "carte_gardien" });
          return (
          <li key={`${f.role}-${f.id}`}>
            <a
              href={`/p/${f.role}/${f.id}`}
              onClick={clic}
              className="flex h-full items-center gap-3 rounded-2xl bg-white p-3 shadow-[0_2px_10px_rgba(35,23,21,0.08)] ring-1 ring-owner/10 transition active:scale-[0.98] md:flex-col md:text-center"
            >
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={f.photo}
                alt={f.firstName}
                width={56}
                height={56}
                loading="eager"
                className={`h-14 w-14 shrink-0 rounded-full object-cover ring-2 ${walker ? "ring-walker" : "ring-sitter"}`}
              />
              <span className="min-w-0 flex-1">
                <span className="block truncate text-[15px] font-bold leading-tight text-ink">{f.firstName}</span>
                <span className={`block text-xs font-semibold leading-tight ${walker ? "text-walker-dark" : "text-sitter-dark"}`}>
                  {walker ? roles.walker : roles.sitter}
                  {f.city ? <span className="font-medium text-ink"> · {f.city}</span> : null}
                </span>
                {f.price ? (
                  <span className="mt-1 block text-[15px] font-extrabold leading-tight text-owner-dark">{f.price}</span>
                ) : null}
                {f.verified ? (
                  <span className="mt-0.5 block text-[11px] font-semibold leading-tight text-[#0F5C2B]">✓ {roles.verified}</span>
                ) : f.rating > 0 ? (
                  <span className="mt-0.5 block text-[11px] font-semibold leading-tight text-[#7A5200]">★ {f.rating.toFixed(1)}</span>
                ) : null}
              </span>
              <span className={`shrink-0 rounded-full px-3.5 py-2 text-[13px] font-bold text-white ${walker ? "bg-walker-dark" : "bg-sitter-dark"}`}>
                {roles.see}
              </span>
            </a>
          </li>
          );
        })}
      </ul>
    )}
    </>
  );
}

export default CitySupplyProof;
