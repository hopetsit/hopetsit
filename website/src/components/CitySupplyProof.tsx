"use client";

import { useEffect, useState, type MouseEvent } from "react";
import { API_BASE } from "@/lib/api";
import { trackSiteEvent, withCampaign } from "@/components/SiteAnalytics";
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
type N = { sitters: number; walkers: number; where: string };

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
// 04/10/2026 (SAM, mission BOB) — PHOTOS LÉGÈRES. Mesure en 4G lente à 375 px :
// noms et prix à 3,4 s, mais les photos à 9 s, 12 s et 18,5 s — les originaux
// Cloudinary pèsent 1 900, 607 et 278 Ko pour un rond de 56 px. La pub promet
// « leur photo et leur prix » : à 3 s, le visiteur voyait des ronds vides.
// On demande à Cloudinary une vignette 112×112 (écran Retina), recadrée sur le
// visage. URL hors Cloudinary ou déjà transformée → inchangée.
function vignette(url: string): string {
  try {
    const m = url.match(/^(https:\/\/res\.cloudinary\.com\/[^/]+\/image\/upload\/)(v\d+\/.+)$/);
    return m ? `${m[1]}c_fill,g_face,w_112,h_112,q_auto,f_auto/${m[2]}` : url;
  } catch {
    return url;
  }
}

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

// 29/09/2026 (SAM, mission BOB) — VILLE SANS OFFRE DANS LE RAYON (Dallas :
// 0 gardien / 1 promeneur à 25 km le 29/09). Plutôt que de cacher la ligne ou
// d'écrire « 0 gardien », on élargit UNE fois à 100 km (même route publique,
// même règle : un chiffre vrai) et on le dit : « 3 gardiens et 1 promeneur
// déjà inscrits à moins de 100 km de Dallas ». Toujours rien → la ligne
// n'apparaît pas et la page garde sa promesse sans mentir.
const WHERE: Record<string, (city: string, km?: number) => string> = {
  fr: (c, km) => (km ? `déjà inscrits à moins de ${km} km de ${c}` : `déjà inscrits autour de ${c}`),
  en: (c, km) => (km ? `already signed up within ${km} km of ${c}` : `already signed up around ${c}`),
  es: (c, km) => (km ? `ya registrados a menos de ${km} km de ${c}` : `ya registrados cerca de ${c}`),
  de: (c, km) => (km ? `bereits im Umkreis von ${km} km um ${c}` : `bereits rund um ${c}`),
  it: (c, km) => (km ? `già iscritti entro ${km} km da ${c}` : `già iscritti intorno a ${c}`),
  pt: (c, km) => (km ? `já inscritos a menos de ${km} km de ${c}` : `já inscritos perto de ${c}`),
  pl: (c, km) => (km ? `już zapisanych w promieniu ${km} km od ${c}` : `już zapisanych w okolicy ${c}`),
  ko: (c, km) => (km ? `${c}에서 ${km} km 이내에` : `${c} 주변에`),
  ja: (c, km) => (km ? `${c}から${km} km以内に` : `${c}の近くに`),
};

// Les 9 langues du site. Ces textes vivent ICI et pas dans OwnerCityPage :
// Next.js interdit de passer une fonction d'un composant serveur à un
// composant client (le build échoue). On passe donc la langue.
const LIGNE: Record<string, (n: N) => string> = {
  fr: (n: N) => {
      const g = n.sitters > 1 ? `${n.sitters} gardiens` : `${n.sitters} gardien`;
      const p = n.walkers > 1 ? `${n.walkers} promeneurs` : `${n.walkers} promeneur`;
      if (!n.walkers) return `${g} ${n.where}`;
      if (!n.sitters) return `${p} ${n.where}`;
      return `${g} et ${p} ${n.where}`;
    },
  en: (n: N) => {
      const g = n.sitters > 1 ? `${n.sitters} sitters` : `${n.sitters} sitter`;
      const p = n.walkers > 1 ? `${n.walkers} dog walkers` : `${n.walkers} dog walker`;
      if (!n.walkers) return `${g} ${n.where}`;
      if (!n.sitters) return `${p} ${n.where}`;
      return `${g} and ${p} ${n.where}`;
    },
  es: (n: N) => {
      const g = n.sitters > 1 ? `${n.sitters} cuidadores` : `${n.sitters} cuidador`;
      const p = n.walkers > 1 ? `${n.walkers} paseadores` : `${n.walkers} paseador`;
      if (!n.walkers) return `${g} ${n.where}`;
      if (!n.sitters) return `${p} ${n.where}`;
      return `${g} y ${p} ${n.where}`;
    },
  de: (n: N) => {
      const g = n.sitters > 1 ? `${n.sitters} Sitter` : `${n.sitters} Sitter`;
      const p = n.walkers > 1 ? `${n.walkers} Gassigeher` : `${n.walkers} Gassigeher`;
      if (!n.walkers) return `${g} ${n.where} angemeldet`;
      if (!n.sitters) return `${p} ${n.where} angemeldet`;
      return `${g} und ${p} ${n.where} angemeldet`;
    },
  it: (n: N) => {
      const g = n.sitters > 1 ? `${n.sitters} sitter` : `${n.sitters} sitter`;
      const p = n.walkers > 1 ? `${n.walkers} dog sitter per passeggiate` : `${n.walkers} dog sitter per passeggiate`;
      if (!n.walkers) return `${g} ${n.where}`;
      if (!n.sitters) return `${p} ${n.where}`;
      return `${g} e ${p} ${n.where}`;
    },
  pt: (n: N) => {
      const g = n.sitters > 1 ? `${n.sitters} cuidadores` : `${n.sitters} cuidador`;
      const p = n.walkers > 1 ? `${n.walkers} passeadores` : `${n.walkers} passeador`;
      if (!n.walkers) return `${g} ${n.where}`;
      if (!n.sitters) return `${p} ${n.where}`;
      return `${g} e ${p} ${n.where}`;
    },
  pl: (n: N) => {
      const g = `${n.sitters} opiekunów`;
      const p = `${n.walkers} wyprowadzaczy psów`;
      if (!n.walkers) return `${g} ${n.where}`;
      if (!n.sitters) return `${p} ${n.where}`;
      return `${g} i ${p} ${n.where}`;
    },
  ko: (n: N) => {
      if (!n.walkers) return `${n.where} 펫시터 ${n.sitters}명이 등록되어 있어요`;
      if (!n.sitters) return `${n.where} 산책 도우미 ${n.walkers}명이 등록되어 있어요`;
      return `${n.where} 펫시터 ${n.sitters}명과 산책 도우미 ${n.walkers}명이 등록되어 있어요`;
    },
  ja: (n: N) => {
      if (!n.walkers) return `${n.where}シッターが${n.sitters}人登録しています`;
      if (!n.sitters) return `${n.where}散歩スタッフが${n.walkers}人登録しています`;
      return `${n.where}シッターが${n.sitters}人、散歩スタッフが${n.walkers}人登録しています`;
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
  const [n, setN] = useState<{ sitters: number; walkers: number; km?: number } | null>(null);
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
    const lire = (params: URLSearchParams) =>
      fetch(`${API_BASE}/supply/city?${params.toString()}`, { signal: ctrl.signal })
        .then((r) => (r.ok ? r.json() : null))
        .then((d) => (d ? { sitters: Number(d.sitters) || 0, walkers: Number(d.walkers) || 0 } : null));
    lire(q)
      .then(async (c) => {
        if (!vivant || !c) return;
        if (c.sitters + c.walkers > 0) return setN(c);
        // Rien à 25 km : on regarde une fois à 100 km, et on affiche la distance.
        const loin = new URLSearchParams(q);
        loin.set("radiusKm", "100");
        const l = await lire(loin);
        if (vivant && l && l.sitters + l.walkers > 0) setN({ ...l, km: 100 });
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
  const where = (WHERE[lang] || WHERE.en)(city, n?.km);
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
      {label({ ...n, where })}
    </p>
    )}
    {faces.length > 0 && (
      <ul className="mt-3 grid gap-2.5 md:grid-cols-3" aria-label={n ? label({ ...n, where }) : undefined}>
        {faces.map((f) => {
          const walker = f.role === "walker";
          // Mesure : un label par rôle, lisible dans /admin/site-analytics (byCta).
          // 05/10 (SAM) : la fiche /p/… recharge la page → on y recopie les utm_* au clic.
          const clic = (e: MouseEvent<HTMLAnchorElement>) => {
            trackSiteEvent("cta_click", { label: walker ? "carte_promeneur" : "carte_gardien" });
            e.currentTarget.href = withCampaign(`/p/${f.role}/${f.id}`);
          };
          return (
          <li key={`${f.role}-${f.id}`}>
            <a
              href={`/p/${f.role}/${f.id}`}
              onClick={clic}
              className="flex h-full items-center gap-3 rounded-2xl bg-white p-3 shadow-[0_2px_10px_rgba(35,23,21,0.08)] ring-1 ring-owner/10 transition active:scale-[0.98] md:flex-col md:text-center"
            >
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={vignette(f.photo)}
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
