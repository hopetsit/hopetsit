"use client";
// 616 (LEO, 08/10/2026, demande de Daniel) — CHAMP VILLE « GPS » du formulaire
// « Publier une annonce » (/posts/create, invité ET membre).
//
// Avant : texte libre (« PEGO ») → le serveur devinait la position par le nom.
// Désormais :
//   · suggestions pendant la frappe (≥ 2 lettres, 300 ms, 5 au plus),
//     « Pego, Communauté valencienne, Espagne » ; clavier (↑ ↓ Entrée Échap)
//     et doigt ;
//   · la ville choisie porte ses coordonnées (lat/lng), envoyées avec la demande
//     dans location.lat / location.lng — le champ que le serveur lit déjà pour
//     l'alerte des prestataires à 100 km (postController → requestAlert612) ;
//   · bouton « Ma position » : GPS du navigateur, ville par géocodage inverse,
//     coordonnées arrondies à ~1 km (jamais l'adresse exacte).
//
// Géocodeur : la route serveur GET /geo/cities (la même que la recherche de
// ville de l'app, v554 : Photon, gratuit, sans clé, fait pour l'autocomplétion),
// et Photon en direct si le serveur ne répond pas. Nominatim INTERDIT l'autocomplétion côté client (règle d'usage) et ne
// sait pas compléter (« asnie » → rien, vérifié v554) : il ne sert ici qu'en
// secours du géocodage inverse, comme dans l'app (location_service.dart).
import { useEffect, useId, useRef, useState } from "react";
import type { Lang } from "@/lib/i18n/langs";
import { c616 } from "@/lib/i18n/cityPicker616";
import { API_BASE } from "@/lib/api";

export type CityCoords = { lat: number; lng: number };
export type CitySuggestion616 = { city: string; label: string; lat: number; lng: number };

const PHOTON = "https://photon.komoot.io";
/** Photon ne parle que ces langues ; ailleurs, noms locaux (« España »). */
const photonLang = (lang: Lang) => (lang === "fr" || lang === "en" || lang === "de" ? lang : "default");

function toSuggestion(f: unknown): CitySuggestion616 | null {
  const feat = f as { properties?: Record<string, unknown>; geometry?: { coordinates?: number[] } };
  const p = feat?.properties || {};
  const c = feat?.geometry?.coordinates || [];
  const lng = Number(c[0]);
  const lat = Number(c[1]);
  const city = String(p.name || p.city || "").trim();
  if (!city || !Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  const region = String(p.state || p.county || "").trim();
  const country = String(p.country || "").trim();
  const parts = [city];
  if (region && region.toLowerCase() !== city.toLowerCase()) parts.push(region);
  if (country) parts.push(country);
  return { city, label: parts.join(", "), lat, lng };
}

/**
 * Jusqu'à 5 villes pour un texte ; [] si rien ; lève une erreur si réseau KO.
 * 1) la route du serveur GET /geo/cities — celle de la recherche de ville de
 *    l'app (v554) : Photon + secours Nominatim + cache commun ;
 * 2) Photon en direct si le serveur est injoignable.
 */
export async function searchCities616(q: string, lang: Lang, signal?: AbortSignal): Promise<CitySuggestion616[]> {
  try {
    const r = await fetch(`${API_BASE}/geo/cities?q=${encodeURIComponent(q)}&lang=${lang}`, { signal });
    if (r.ok) {
      const d = (await r.json()) as { name?: string; admin?: string; country?: string; lat?: number; lng?: number }[];
      if (Array.isArray(d)) {
        const out: CitySuggestion616[] = [];
        for (const e of d) {
          const city = String(e.name || "").trim();
          const lat = Number(e.lat), lng = Number(e.lng);
          if (!city || !Number.isFinite(lat) || !Number.isFinite(lng)) continue;
          const admin = String(e.admin || "").trim();
          const label = [city, admin.toLowerCase() === city.toLowerCase() ? "" : admin, String(e.country || "").trim()]
            .filter(Boolean).join(", ");
          out.push({ city, label, lat, lng });
          if (out.length >= 5) break;
        }
        return out;
      }
    }
  } catch (e) {
    if (signal?.aborted) throw e;
    /* serveur injoignable : Photon en direct */
  }
  return searchPhoton(q, lang, signal);
}

async function searchPhoton(q: string, lang: Lang, signal?: AbortSignal): Promise<CitySuggestion616[]> {
  const url = `${PHOTON}/api/?q=${encodeURIComponent(q)}&limit=8&layer=city&lang=${photonLang(lang)}`;
  const r = await fetch(url, { signal });
  if (!r.ok) throw new Error(`photon ${r.status}`);
  const d = (await r.json()) as { features?: unknown[] };
  const out: CitySuggestion616[] = [];
  const seen = new Set<string>();
  for (const f of d.features || []) {
    const s = toSuggestion(f);
    if (!s) continue;
    const k = s.label.toLowerCase();
    if (seen.has(k)) continue;
    seen.add(k);
    out.push(s);
    if (out.length >= 5) break;
  }
  return out;
}

/** Ville d'une position GPS (Photon, puis Nominatim en secours). */
async function reverseCity616(lat: number, lng: number, lang: Lang): Promise<CitySuggestion616 | null> {
  try {
    const r = await fetch(`${PHOTON}/reverse?lat=${lat}&lon=${lng}&layer=city&lang=${photonLang(lang)}`);
    if (r.ok) {
      const d = (await r.json()) as { features?: unknown[] };
      const s = d.features && d.features.length ? toSuggestion(d.features[0]) : null;
      if (s) return s;
    }
  } catch { /* secours ci-dessous */ }
  try {
    const r = await fetch(`https://nominatim.openstreetmap.org/reverse?format=json&zoom=10&addressdetails=1&lat=${lat}&lon=${lng}&accept-language=${lang}`);
    if (!r.ok) return null;
    const d = (await r.json()) as { address?: Record<string, string> };
    const a = d.address || {};
    const city = (a.city || a.town || a.village || a.municipality || a.county || "").trim();
    if (!city) return null;
    const label = [city, a.state || a.province || "", a.country || ""].filter(Boolean).join(", ");
    return { city, label, lat, lng };
  } catch {
    return null;
  }
}

/** ~1 km : jamais la position exacte du domicile (règle de la légende PawMap). */
const round2 = (x: number) => Math.round(x * 100) / 100;

type Props = {
  lang: Lang;
  label: string;
  placeholder: string;
  value: string;
  coords: CityCoords | null;
  /** Texte tapé (coords = null) ou ville choisie (coords + libellé complet). */
  onChange: (city: string, coords: CityCoords | null, label?: string) => void;
  /** Libellé complet de la ville choisie (« Pego, …, Espagne »). */
  pickedLabel?: string;
};

export default function CityAutocomplete616({ lang, label, placeholder, value, coords, onChange, pickedLabel }: Props) {
  const uid = useId();
  const listId = `city616-list-${uid}`;
  const [items, setItems] = useState<CitySuggestion616[]>([]);
  const [open, setOpen] = useState(false);
  const [active, setActive] = useState(-1);
  const [loading, setLoading] = useState(false);
  const [noResult, setNoResult] = useState(false);
  const [geoBusy, setGeoBusy] = useState(false);
  const [geoMsg, setGeoMsg] = useState("");
  const typed = useRef(false); // la recherche ne part que sur une frappe réelle
  const blurTimer = useRef<number | null>(null);

  useEffect(() => {
    const q = value.trim();
    if (!typed.current || coords || q.length < 2) {
      setItems([]);
      setLoading(false);
      setNoResult(false);
      return;
    }
    const ctrl = new AbortController();
    setLoading(true);
    const t = window.setTimeout(() => {
      searchCities616(q, lang, ctrl.signal)
        .then((r) => {
          setItems(r);
          setActive(r.length ? 0 : -1);
          setNoResult(r.length === 0);
          setOpen(true);
        })
        .catch(() => { /* annulé ou hors ligne : pas de liste */ })
        .finally(() => { if (!ctrl.signal.aborted) setLoading(false); });
    }, 300);
    return () => {
      window.clearTimeout(t);
      ctrl.abort();
    };
  }, [value, coords, lang]);

  function pick(s: CitySuggestion616) {
    typed.current = false;
    onChange(s.city, { lat: s.lat, lng: s.lng }, s.label);
    setItems([]);
    setOpen(false);
    setActive(-1);
    setNoResult(false);
    setGeoMsg("");
  }

  function onKeyDown(e: React.KeyboardEvent<HTMLInputElement>) {
    if (!open || !items.length) {
      if (e.key === "Escape") setOpen(false);
      return;
    }
    if (e.key === "ArrowDown") {
      e.preventDefault();
      setActive((i) => (i + 1) % items.length);
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setActive((i) => (i <= 0 ? items.length - 1 : i - 1));
    } else if (e.key === "Enter") {
      // Entrée choisit la ville surlignée au lieu d'envoyer le formulaire.
      if (active >= 0 && items[active]) {
        e.preventDefault();
        pick(items[active]);
      }
    } else if (e.key === "Escape") {
      setOpen(false);
    }
  }

  function locateMe() {
    setGeoMsg("");
    if (typeof navigator === "undefined" || !navigator.geolocation) {
      setGeoMsg(c616(lang, "unavailable"));
      return;
    }
    setGeoBusy(true);
    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        const lat = round2(pos.coords.latitude);
        const lng = round2(pos.coords.longitude);
        const s = await reverseCity616(pos.coords.latitude, pos.coords.longitude, lang);
        setGeoBusy(false);
        if (!s) {
          setGeoMsg(c616(lang, "unavailable"));
          return;
        }
        // La ville vient du géocodage inverse, la position reste celle du GPS
        // arrondie à ~1 km (plus juste que le centre-ville pour les 100 km).
        pick({ ...s, lat, lng });
      },
      (err) => {
        setGeoBusy(false);
        setGeoMsg(c616(lang, err && err.code === 1 ? "denied" : "unavailable"));
      },
      { enableHighAccuracy: false, timeout: 10000, maximumAge: 300000 },
    );
  }

  const showList = open && (items.length > 0 || noResult);

  return (
    <div data-testid="city616">
      <label htmlFor={`city616-${uid}`} className="block text-sm font-medium text-ink">{label}</label>
      <div className="mt-1.5 flex flex-col gap-2 sm:flex-row">
        <div className="relative min-w-0 flex-1">
          <input
            id={`city616-${uid}`}
            data-testid="city616-input"
            value={value}
            onChange={(e) => {
              typed.current = true;
              setGeoMsg("");
              onChange(e.target.value, null);
            }}
            onKeyDown={onKeyDown}
            onFocus={() => { if (items.length) setOpen(true); }}
            onBlur={() => {
              blurTimer.current = window.setTimeout(() => setOpen(false), 180);
            }}
            required
            role="combobox"
            aria-autocomplete="list"
            aria-expanded={showList}
            aria-controls={listId}
            aria-activedescendant={showList && active >= 0 ? `${listId}-${active}` : undefined}
            autoComplete="off"
            enterKeyHint="search"
            placeholder={placeholder}
            className="w-full rounded-xl border border-ink/15 bg-bg-soft px-3.5 py-2.5 pr-9 text-sm text-ink focus:border-owner focus:outline-none max-lg:min-h-[44px]"
          />
          {/* Ville choisie = coche ; recherche en cours = petit rond qui tourne. */}
          {coords ? (
            <span aria-hidden className="pointer-events-none absolute inset-y-0 right-3 flex items-center text-owner">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"><path d="M5 12.5l4.5 4.5L19 7.5" /></svg>
            </span>
          ) : loading ? (
            <span aria-label={c616(lang, "searching")} className="absolute inset-y-0 right-3 flex items-center">
              <span className="h-4 w-4 animate-spin rounded-full border-2 border-owner/30 border-t-owner" />
            </span>
          ) : null}
          {showList && (
            <ul
              id={listId}
              role="listbox"
              aria-label={c616(lang, "list_label")}
              data-testid="city616-list"
              className="absolute left-0 right-0 top-full z-30 mt-1 overflow-hidden rounded-2xl border border-owner/20 bg-white py-1 shadow-card"
            >
              {items.map((s, i) => (
                <li
                  key={`${s.label}-${i}`}
                  id={`${listId}-${i}`}
                  role="option"
                  aria-selected={i === active}
                  data-testid="city616-option"
                  onMouseDown={(e) => e.preventDefault()}
                  onMouseEnter={() => setActive(i)}
                  onClick={() => {
                    if (blurTimer.current) window.clearTimeout(blurTimer.current);
                    pick(s);
                  }}
                  className={`flex min-h-[44px] cursor-pointer items-center gap-2.5 px-3.5 py-2 text-sm ${
                    i === active ? "bg-owner-light text-owner-dark" : "text-ink"
                  }`}
                >
                  <svg width="16" height="16" viewBox="0 0 24 24" className="shrink-0 text-owner" fill="currentColor" aria-hidden><path d="M12 2a7 7 0 0 0-7 7c0 5.2 7 13 7 13s7-7.8 7-13a7 7 0 0 0-7-7zm0 9.5A2.5 2.5 0 1 1 12 6.5a2.5 2.5 0 0 1 0 5z" /></svg>
                  <span className="min-w-0">
                    <span className="font-semibold">{s.city}</span>
                    <span className="text-[#6E4F48]">{s.label.slice(s.city.length)}</span>
                  </span>
                </li>
              ))}
              {noResult && !items.length && (
                <li className="px-3.5 py-2.5 text-sm text-[#6E4F48]">{c616(lang, "no_result")}</li>
              )}
            </ul>
          )}
        </div>
        <button
          type="button"
          data-testid="city616-gps"
          onClick={locateMe}
          disabled={geoBusy}
          className="inline-flex min-h-[44px] shrink-0 items-center justify-center gap-1.5 whitespace-nowrap rounded-full border border-owner bg-owner-light px-4 text-sm font-semibold text-owner-dark transition-colors hover:bg-[#F7D9D2] disabled:opacity-80"
        >
          {geoBusy ? (
            <span className="h-4 w-4 animate-spin rounded-full border-2 border-owner/30 border-t-owner" aria-hidden />
          ) : (
            <svg width="16" height="16" viewBox="0 0 24 24" className="shrink-0 text-owner" fill="currentColor" aria-hidden><path d="M12 2a7 7 0 0 0-7 7c0 5.2 7 13 7 13s7-7.8 7-13a7 7 0 0 0-7-7zm0 9.5A2.5 2.5 0 1 1 12 6.5a2.5 2.5 0 0 1 0 5z" /></svg>
          )}
          {geoBusy ? c616(lang, "locating") : c616(lang, "my_position")}
        </button>
      </div>
      {coords && pickedLabel && (
        <p data-testid="city616-picked" className="mt-1 text-xs font-semibold text-owner-dark">{pickedLabel}</p>
      )}
      {geoMsg && <p role="alert" data-testid="city616-geo-msg" className="mt-1 text-xs font-semibold text-owner-dark">{geoMsg}</p>}
    </div>
  );
}
