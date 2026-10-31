"use client";

// 31/10/2026 (LEO, demande de Daniel « quand on tape la ville dans le formulaire, qu'elle soit sélectionnée par
// carte pour être précis ») — champ VILLE du formulaire 1 étape :
//   · suggestions au fil de la frappe via NOTRE route publique GET /geo/cities (Photon/OpenStreetMap côté
//     serveur, cache, repli Nominatim ; jamais Google) — anti-rebond 400 ms, rien sous 3 caractères,
//     au plus 1 requête par seconde, dernière réponse gagnante ;
//   · un choix dans la liste pose la ville + lat/lng et DÉPLIE une mini-carte OSM (200 px) avec une épingle
//     déplaçable pour confirmer l'endroit exact (déplacée = lat/lng mis à jour) ;
//   · la position part avec la demande (POST /ad-leads/site : elle décide des gardiens prévenus et de la
//     distance montrée aux candidats ; sans position : repli code postal côté serveur).
// Téléphone d'abord : la carte n'apparaît qu'APRÈS la sélection, pour ne pas allonger le premier écran.
// Hooks en tête, aucun retour conditionnel avant.

import dynamic from "next/dynamic";
import { useEffect, useRef, useState } from "react";
import { API_BASE } from "@/lib/api";

const MiniMap = dynamic(() => import("@/components/MiniMapPick3110"), { ssr: false, loading: () => <div className="h-full w-full animate-pulse" style={{ background: "#FBE9E5" }} /> });

export type PlacePick = { city: string; lat: number; lng: number; countryCode?: string; admin?: string };
type Suggestion = { name: string; admin?: string; country?: string; countryCode?: string; label?: string; lat: number; lng: number };

const TXT = {
  fr: { label: "Ville", ph: "Tape ta ville…", hint: "Choisis ta ville dans la liste, puis déplace l'épingle sur ton quartier.", pin: "Déplace l'épingle pour préciser l'endroit (jamais ton adresse exacte montrée aux gardiens).", picked: "Position choisie", none: "Aucune ville trouvée : vérifie l'orthographe, ou indique ton code postal." },
  en: { label: "City", ph: "Type your city…", hint: "Pick your city from the list, then move the pin to your neighbourhood.", pin: "Move the pin to refine the spot (your exact address is never shown to sitters).", picked: "Location set", none: "No city found: check the spelling, or enter your ZIP code." },
};

export function PlacePicker3110({ lang, value, onChange, pick, setPick, inputClass, bias }: {
  lang: "fr" | "en";
  value: string;
  onChange: (city: string) => void;
  pick: PlacePick | null;
  setPick: (p: PlacePick | null) => void;
  inputClass: string;
  /** Centre de recherche (ville de la page) pour classer les suggestions proches en premier. */
  bias?: { lat: number; lng: number } | null;
}) {
  const t = TXT[lang];
  const [list, setList] = useState<Suggestion[]>([]);
  const [open, setOpen] = useState(false);
  const [searched, setSearched] = useState(false);
  // Pas de recherche tant que la personne n'a pas tapé (la ville de la page est pré-remplie).
  const [typed, setTyped] = useState(false);
  const timer = useRef<number | null>(null);
  const lastAt = useRef(0);
  const seq = useRef(0);
  const ctrl = useRef<AbortController | null>(null);

  // Suggestions : 400 ms après la dernière frappe, ≥ 3 caractères, ≥ 1 s entre deux requêtes, dernière gagnante.
  useEffect(() => {
    if (timer.current) window.clearTimeout(timer.current);
    const q = value.trim();
    if (!typed) return;
    if (pick && q === pick.city) { setList([]); return; }
    if (q.length < 3) { setList([]); setSearched(false); return; }
    const wait = Math.max(400, 1000 - (Date.now() - lastAt.current));
    timer.current = window.setTimeout(() => {
      lastAt.current = Date.now();
      const mine = ++seq.current;
      ctrl.current?.abort();
      const c = new AbortController();
      ctrl.current = c;
      const p = new URLSearchParams({ q, lang });
      if (bias) { p.set("lat", String(bias.lat)); p.set("lng", String(bias.lng)); }
      fetch(`${API_BASE}/geo/cities?${p}`, { signal: c.signal })
        .then((r) => (r.ok ? r.json() : []))
        .then((j: unknown) => {
          if (mine !== seq.current) return;
          const arr = Array.isArray(j) ? (j as Suggestion[]).filter((e) => e && e.name && Number.isFinite(e.lat) && Number.isFinite(e.lng)) : [];
          setList(arr.slice(0, 6));
          setSearched(true);
          setOpen(true);
        })
        .catch(() => { if (mine === seq.current) { setList([]); setSearched(true); } });
    }, wait);
    return () => { if (timer.current) window.clearTimeout(timer.current); };
  }, [value, lang, bias, pick, typed]);

  function choose(s: Suggestion) {
    onChange(s.name);
    setPick({ city: s.name, lat: s.lat, lng: s.lng, countryCode: s.countryCode, admin: s.admin });
    setList([]);
    setOpen(false);
  }

  return (
    <div className="relative" data-place-picker-3110={pick ? "picked" : "empty"}>
      <label className="block text-xs font-semibold text-ink">{t.label}
        <input
          value={value}
          onChange={(e) => { setTyped(true); onChange(e.target.value); if (pick && e.target.value.trim() !== pick.city) setPick(null); }}
          onFocus={() => { if (list.length) setOpen(true); }}
          onBlur={() => window.setTimeout(() => setOpen(false), 150)}
          placeholder={t.ph}
          autoComplete="off"
          autoCapitalize="words"
          maxLength={80}
          className={inputClass}
          data-testid="hero-city"
          aria-autocomplete="list"
          aria-expanded={open && list.length > 0}
        />
      </label>
      {open && list.length > 0 && (
        <ul className="absolute left-0 right-0 z-[1200] mt-1 overflow-hidden rounded-xl bg-white" style={{ boxShadow: "0 12px 28px -12px rgba(35,23,21,.45), inset 0 0 0 1px #F6D9CF" }} role="listbox" data-place-list-3110={list.length}>
          {list.map((s, i) => (
            <li key={`${s.name}|${s.label}|${i}`}>
              <button type="button" role="option" aria-selected={false} onMouseDown={(e) => e.preventDefault()} onClick={() => choose(s)}
                className="flex w-full items-baseline justify-between gap-2 px-3 py-2.5 text-left hover:bg-[#FFF6F2]">
                <span className="text-[14px] font-bold text-ink">{s.name}</span>
                <span className="truncate text-[12px]" style={{ color: "#6E4F48" }}>{s.label || [s.admin, s.country].filter(Boolean).join(", ")}</span>
              </button>
            </li>
          ))}
        </ul>
      )}
      {!pick && typed && searched && list.length === 0 && value.trim().length >= 3 && (
        <p className="mt-1 text-[11px] font-semibold" style={{ color: "#9E1F0B" }}>{t.none}</p>
      )}
      {!pick && typed && !searched && <p className="mt-1 text-[11px]" style={{ color: "#8A6B64" }}>{t.hint}</p>}
    </div>
  );
}

/** La mini-carte de confirmation (pleine largeur, sous la rangée Ville / Code postal), dépliée après le choix. */
export function PlaceMapConfirm3110({ lang, pick, setPick }: { lang: "fr" | "en"; pick: PlacePick | null; setPick: (p: PlacePick | null) => void }) {
  const t = TXT[lang];
  if (!pick) return null;
  return (
    <div className="mt-2" data-place-map-3110="">
      <div className="h-[200px] overflow-hidden rounded-xl" style={{ boxShadow: "inset 0 0 0 1.5px #F6D9CF" }}>
        <MiniMap lat={pick.lat} lng={pick.lng} onMove={(lat, lng) => setPick({ ...pick, lat, lng })} />
      </div>
      <p className="mt-1 flex items-start justify-between gap-2 text-[11px] leading-snug" style={{ color: "#6E4F48" }}>
        <span>{t.pin}</span>
        <span className="shrink-0 rounded-full bg-white px-2 py-0.5 font-bold" style={{ color: "#15803D" }} data-place-coords-3110={`${pick.lat.toFixed(4)},${pick.lng.toFixed(4)}`}>✓ {t.picked}</span>
      </p>
    </div>
  );
}

export default PlacePicker3110;
