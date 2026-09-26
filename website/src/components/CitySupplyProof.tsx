"use client";

import { useEffect, useState } from "react";
import { API_BASE } from "@/lib/api";
import { trackSiteEvent } from "@/components/SiteAnalytics";

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
type Face = { id: string; role: "sitter" | "walker"; firstName: string; photo: string; city: string; rating: number; verified: boolean };
const ROLE: Record<string, { sitter: string; walker: string; verified: string }> = {
  fr: { sitter: "Gardien·ne", walker: "Promeneur·se", verified: "Identité vérifiée" },
  en: { sitter: "Pet sitter", walker: "Dog walker", verified: "ID verified" },
  es: { sitter: "Cuidador/a", walker: "Paseador/a", verified: "Identidad verificada" },
  de: { sitter: "Tiersitter", walker: "Gassigeher", verified: "Identität geprüft" },
  it: { sitter: "Pet sitter", walker: "Dog walker", verified: "Identità verificata" },
  pt: { sitter: "Cuidador/a", walker: "Passeador/a", verified: "Identidade verificada" },
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
    const t = setTimeout(() => ctrl.abort(), 6000);
    fetch(`${API_BASE}/supply/city/faces?${new URLSearchParams({ city, limit: "3" })}`, { signal: ctrl.signal })
      .then((r) => (r.ok ? r.json() : null))
      .then((d) => {
        if (!vivant || !d || !Array.isArray(d.faces)) return;
        setFaces(d.faces.filter((f: Face) => f && f.id && f.photo && f.firstName).slice(0, 3));
      })
      .catch(() => {})
      .finally(() => clearTimeout(t));
    return () => {
      vivant = false;
      ctrl.abort();
      clearTimeout(t);
    };
  }, [city]);

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
    {faces.length > 0 && (
      <ul className="mt-4 grid grid-cols-3 gap-2" aria-label={n ? label({ ...n, city }) : undefined}>
        {faces.map((f) => (
          <li key={`${f.role}-${f.id}`}>
            <a
              href={`/p/${f.role}/${f.id}`}
              onClick={() => trackSiteEvent("cta_click", { label: `face_${f.role}` })}
              className="flex h-full flex-col items-center rounded-2xl bg-white px-1.5 pb-2.5 pt-3 text-center shadow-[0_2px_10px_rgba(35,23,21,0.08)] ring-1 ring-owner/10 transition active:scale-[0.97]"
            >
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={f.photo}
                alt={f.firstName}
                width={56}
                height={56}
                loading="eager"
                className={`h-14 w-14 rounded-full object-cover ring-2 ${f.role === "walker" ? "ring-walker" : "ring-sitter"}`}
              />
              <span className="mt-1.5 block max-w-full truncate text-[13px] font-bold leading-tight text-ink">{f.firstName}</span>
              <span className={`block text-[11px] font-semibold leading-tight ${f.role === "walker" ? "text-walker-dark" : "text-sitter-dark"}`}>
                {f.role === "walker" ? roles.walker : roles.sitter}
              </span>
              {f.verified ? (
                <span className="mt-0.5 block text-[10px] font-semibold leading-tight text-[#0F5C2B]">✓ {roles.verified}</span>
              ) : f.rating > 0 ? (
                <span className="mt-0.5 block text-[10px] font-semibold leading-tight text-[#7A5200]">★ {f.rating.toFixed(1)}</span>
              ) : null}
            </a>
          </li>
        ))}
      </ul>
    )}
    {n && (
    <p className="mt-3 flex items-center gap-2 text-sm font-semibold text-owner-dark">
      <span
        aria-hidden
        className="inline-block h-2 w-2 shrink-0 rounded-full bg-[#16A34A]"
      />
      {label({ ...n, city })}
    </p>
    )}
    </>
  );
}

export default CitySupplyProof;
