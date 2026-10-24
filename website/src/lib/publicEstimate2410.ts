// 24/10/2026 (LEO, complément de BOB 23 h 10 — serveur de ZOE `POST /pricing/estimate/public`) :
// « à partir de X €/unité · estimation ~Y € (d'après N gardiens) » pour un VISITEUR SANS COMPTE
// (arrivées de la pub sur /posts/create) et sur les pages villes.
//
// Module PUR (aucun React, aucun fetch) : testé par scripts/test-publicEstimate2410.mjs.
//
// Contrat serveur (ZOE_rapport.md, 24/10 23 h) : sans session, 30 appels / min / IP, cache 5 min.
// Corps { serviceType, city?, postalCode?, country?, lang?, lat?, lng?, startDate?, endDate?,
// visitsPerDay?, walkDurationMinutes? }. Position : lat/lng, sinon code postal (pays donné ou
// deviné par la langue), sinon ville. Devise déduite du pays. Réponse = celle de la route
// authentifiée (fromRate / unit / quantity / ownerTotalFrom / basedOn …) + positionSource.
// Mesuré en production le 24/10 (preuve_route_publique.log) : « New York » sans `country` →
// basedOn 0 / EUR, avec `country: "US"` → 20 $/jour, basedOn 5 : LE PAYS EST OBLIGATOIRE
// pour les pages villes hors France.
//
// Règles de BOB : rien quand basedOn vaut 0 ; jamais plus d'un appel par changement
// (debounce 600 ms, côté composant) ; même parité app/site.

import type { DateMode620 } from "./services620";
import { daysBetween620 } from "./services620";

export const PUBLIC_ESTIMATE_DEBOUNCE_MS = 600;

export type PublicEstimateInput2410 = {
  serviceType: string;
  city?: string | null;
  postalCode?: string | null;
  country?: string | null;
  lang?: string | null;
  dateMode?: DateMode620;
  startDate?: string | null;
  endDate?: string | null;
  visitsPerDay?: number | null;
  walkDurationMinutes?: number | null;
};

export type PublicEstimateBody2410 = {
  serviceType: string;
  city?: string;
  postalCode?: string;
  country?: string;
  lang?: string;
  startDate?: string;
  endDate?: string;
  visitsPerDay?: number;
  walkDurationMinutes?: number;
};

/** Jour civil AAAA-MM-JJ valable ? */
function isDay(v: unknown): v is string {
  return typeof v === "string" && /^\d{4}-\d{2}-\d{2}$/.test(v);
}

/**
 * Corps de `POST /pricing/estimate/public`. Retourne null quand il n'y a rien à demander :
 * ni ville ni code postal (le serveur répondrait `positionSource none`, basedOn 0), ou des
 * dates incomplètes / inversées en mode « dates précises » (on attend la 2e date : UN appel
 * par changement utile, pas un appel par frappe). Les dates ne partent qu'en mode exact/approx ;
 * en « à prévoir », on ne demande que le tarif unitaire. Aucune donnée personnelle.
 */
export function publicEstimateBody2410(input: PublicEstimateInput2410): PublicEstimateBody2410 | null {
  const serviceType = String(input.serviceType || "").trim();
  if (!serviceType) return null;
  const city = String(input.city || "").trim();
  const postalCode = String(input.postalCode || "").trim();
  if (!city && postalCode.length < 3) return null;
  const body: PublicEstimateBody2410 = { serviceType };
  if (city) body.city = city;
  if (postalCode.length >= 3) body.postalCode = postalCode;
  const country = String(input.country || "").trim().toUpperCase();
  if (/^[A-Z]{2}$/.test(country)) body.country = country;
  const lang = String(input.lang || "").trim().toLowerCase();
  if (/^[a-z]{2}$/.test(lang)) body.lang = lang;
  const mode: DateMode620 = input.dateMode || (isDay(input.startDate) && isDay(input.endDate) ? "exact" : "tbd");
  if (mode !== "tbd") {
    const s = isDay(input.startDate) ? input.startDate : "";
    const e = isDay(input.endDate) ? input.endDate : "";
    if (!s || !e) {
      // Une seule date posée : on attend l'autre (sinon un appel inutile par frappe).
      if (s || e) return null;
    } else if (daysBetween620(s, e) <= 0) {
      return null; // fin avant début : le formulaire refuse déjà, on n'interroge pas
    } else {
      body.startDate = s;
      body.endDate = e;
    }
  }
  if (serviceType === "home_visit") {
    const v = Number(input.visitsPerDay);
    body.visitsPerDay = v === 2 ? 2 : 1;
  }
  if (serviceType === "dog_walking") {
    const w = Number(input.walkDurationMinutes);
    if (Number.isFinite(w) && w > 0) body.walkDurationMinutes = w;
  }
  return body;
}

/** Clé de dédoublonnage d'un corps : même clé = même appel, on ne le refait pas. */
export function publicEstimateKey2410(body: PublicEstimateBody2410 | null): string {
  if (!body) return "";
  return [body.serviceType, body.country || "", body.lang || "", body.city || "", body.postalCode || "", body.startDate || "", body.endDate || "", body.visitsPerDay ?? "", body.walkDurationMinutes ?? ""].join("|");
}

// ─── Pages villes ────────────────────────────────────────────────────────────

/** Mots de la colonne `region` de recruit-cities.ts → code pays ISO-2 (toutes les régions relevées le 24/10). */
const REGION_COUNTRY: Array<[RegExp, string]> = [
  [/\bUSA\b/, "US"],
  [/United Kingdom/i, "GB"],
  [/\bIreland\b/i, "IE"],
  [/Netherlands/i, "NL"],
  [/Denmark/i, "DK"],
  [/Sweden/i, "SE"],
  [/Norway/i, "NO"],
  [/Finland/i, "FI"],
  [/Greece/i, "GR"],
  [/Czech/i, "CZ"],
  [/Hungary/i, "HU"],
  [/Romania/i, "RO"],
  [/Croatia/i, "HR"],
  [/Portugal/i, "PT"],
  [/Spain|España/i, "ES"],
  [/Germany|Deutschland/i, "DE"],
  [/France|Île-de-France|Provence|Auvergne|Grand Est|Occitanie|Aquitaine|Normandie|Pays de la Loire|Centre-Val|Bretagne|Hauts-de-France|Bourgogne/i, "FR"],
  [/Malta/i, "MT"],
  [/Estonia/i, "EE"],
  [/Latvia/i, "LV"],
  [/Lithuania/i, "LT"],
  [/Slovakia/i, "SK"],
  [/Slovenia/i, "SI"],
  [/Bulgaria/i, "BG"],
  [/Belgique|Belgium/i, "BE"],
  [/Suisse|Schweiz|Switzerland/i, "CH"],
  [/Luxembourg/i, "LU"],
  [/Monaco/i, "MC"],
  [/Österreich|Austria/i, "AT"],
  [/Italia|Italy/i, "IT"],
  [/Polska|Poland/i, "PL"],
  [/대한민국|Korea/i, "KR"],
  [/日本|Japan/i, "JP"],
];

/** Repli par langue de la page quand la région ne dit rien. */
const LANG_COUNTRY: Record<string, string> = { fr: "FR", en: "US", es: "ES", de: "DE", it: "IT", pt: "PT", pl: "PL", ko: "KR", ja: "JP" };

/** Pays ISO-2 d'une ville de recruit-cities.ts (région d'abord, langue ensuite). */
export function countryOfRecruitCity2410(region: string | null | undefined, lang: string | null | undefined): string {
  const r = String(region || "");
  for (const [re, cc] of REGION_COUNTRY) if (re.test(r)) return cc;
  return LANG_COUNTRY[String(lang || "").toLowerCase()] || "";
}

/** Ville à interroger : « Paris 11e » → « Paris » (un gardien inscrit à Paris dessert le 11e comme le 15e). */
export function cityQueryName2410(name: string): string {
  const base = String(name || "").replace(/\s+\d+\s*(er|e|ème|eme|th|st|nd|rd)?$/i, "").trim();
  return base || String(name || "").trim();
}

/** Code postal d'un arrondissement de Paris (slug « paris-N ») : 75001…75020 ; sinon "". */
export function parisPostal2410(slug: string | null | undefined): string {
  const m = /^paris-(\d{1,2})$/.exec(String(slug || ""));
  if (!m) return "";
  const n = Number(m[1]);
  if (!Number.isInteger(n) || n < 1 || n > 20) return "";
  return `750${String(n).padStart(2, "0")}`;
}

/**
 * Lien « Publier ma demande » depuis le bloc prix d'une page ville : ville pré-remplie (?city=,
 * lu par /posts/create) ; le service et les dates saisies partent dans le brouillon local (clé du
 * formulaire, qui a priorité), jamais dans l'URL. Pas de `?pre=` : ce paramètre est réservé à
 * l'e-mail de la pub à formulaire (il écrit une phrase et compte un événement « pub_prerempli »).
 */
export function createPostHref2410(cityName: string): string {
  return `/posts/create?city=${encodeURIComponent(cityName)}&from=prix`;
}
