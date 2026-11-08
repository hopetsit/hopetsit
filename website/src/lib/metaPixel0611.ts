/**
 * 06/11/2026 (SAM, ordre de Daniel « oui fais tout ») — PIXEL META du site, soumis au consentement.
 *
 * Pourquoi : Meta optimise la pub sur « formulaire rempli » ; il n'avait AUCUN signal de ce qui compte
 * (demande publiée, choix d'un gardien, paiement). Le pixel navigateur (ici) + la Conversions API
 * côté serveur (backend/src/services/metaCapi0611.js, même pixel, même eventID = dédoublonné) lui
 * donnent ces signaux.
 *
 * Règles :
 *   - RIEN ne se charge avant « Accepter » (bandeau ConsentBanner.tsx) : pas de script, pas de cookie.
 *     Le choix est mémorisé dans localStorage (clé CONSENT_KEY : "yes" | "no"). « Refuser » = rien,
 *     la mesure maison sans cookie (SiteAnalytics) continue.
 *   - Jamais sur localhost / aperçus Vercel / espaces privés (/admin, /dashboard, /chat).
 *   - L'identifiant du pixel n'est pas un secret : il est dans le HTML de toute page qui le charge.
 *     NEXT_PUBLIC_META_PIXEL_ID (Vercel) sinon la valeur ci-dessous (pixel créé le 06/11 sur le
 *     compte pub act_943056412092153, gardé dans ~/hopetsit-social/ads/meta_ads_state.json).
 */
export const META_PIXEL_ID = (process.env.NEXT_PUBLIC_META_PIXEL_ID || "972651422131697").trim();
export const CONSENT_KEY = "hps_consent_meta_0611";
/** Événement DOM envoyé quand le visiteur tranche (le composant MetaPixel écoute). */
export const CONSENT_EVENT = "hps-consent-0611";

export type Consent = "yes" | "no" | "";

type Fbq = ((...args: unknown[]) => void) & { callMethod?: (...a: unknown[]) => void; queue?: unknown[]; loaded?: boolean; version?: string; push?: unknown };
type WinFbq = Window & { fbq?: Fbq; _fbq?: Fbq };

export function readConsent(): Consent {
  try {
    const v = window.localStorage.getItem(CONSENT_KEY);
    return v === "yes" || v === "no" ? v : "";
  } catch {
    return "";
  }
}

export function writeConsent(v: "yes" | "no") {
  try { window.localStorage.setItem(CONSENT_KEY, v); } catch { /* stockage bloqué : le bandeau reviendra */ }
  try { window.dispatchEvent(new CustomEvent(CONSENT_EVENT, { detail: v })); } catch { /* rien */ }
}

const PRIVATE_PREFIXES = ["/admin", "/dashboard", "/chat"];

/** Hôte réel + consentement donné + pixel connu. */
export function pixelAllowed(path?: string): boolean {
  if (typeof window === "undefined") return false;
  if (!META_PIXEL_ID) return false;
  const host = window.location.hostname;
  if (process.env.NEXT_PUBLIC_META_PIXEL_DEV !== "1") {
    if (host === "localhost" || host === "127.0.0.1" || host === "::1" || host.endsWith(".local") || host.endsWith(".vercel.app")) return false;
  }
  const p = (path || window.location.pathname || "/").toLowerCase();
  if (PRIVATE_PREFIXES.some((x) => p === x || p.startsWith(`${x}/`))) return false;
  return readConsent() === "yes";
}

let loading = false;

/** Charge fbevents.js UNE fois (appelé seulement après « Accepter ») et initialise le pixel. */
export function loadPixel(): boolean {
  if (!pixelAllowed()) return false;
  const w = window as WinFbq;
  if (w.fbq) return true;
  if (loading) return true;
  loading = true;
  // Amorce officielle Meta (file d'attente tant que le script n'est pas arrivé), sans eval.
  const n: Fbq = function fbqStub(...args: unknown[]) {
    if (n.callMethod) n.callMethod(...args);
    else (n.queue as unknown[]).push(args);
  } as Fbq;
  n.push = n; n.loaded = true; n.version = "2.0"; n.queue = [];
  w.fbq = n; if (!w._fbq) w._fbq = n;
  const s = document.createElement("script");
  s.async = true;
  s.src = "https://connect.facebook.net/en_US/fbevents.js";
  document.head.appendChild(s);
  n("init", META_PIXEL_ID);
  return true;
}

export type PixelEvent = "PageView" | "Lead" | "ViewContent" | "InitiateCheckout" | "Purchase" | "CompleteRegistration";

/** Envoie un événement standard ; eventId = même valeur que le serveur (dédoublonnage CAPI). */
export function pixelTrack(name: PixelEvent, params: Record<string, string | number> = {}, eventId?: string) {
  try {
    if (!loadPixel()) return;
    const w = window as WinFbq;
    if (!w.fbq) return;
    if (eventId) w.fbq("track", name, params, { eventID: eventId });
    else w.fbq("track", name, params);
  } catch { /* la mesure ne casse jamais la page */ }
}

/**
 * Correspondance repères maison (trackSiteEvent) → événements Meta. Un seul endroit, pour ne pas
 * toucher aux pages des autres agents :
 *   pageview /application/<id>        → ViewContent (page « mes candidats → payer »)
 *   cta lead_confirme                 → Lead            (eventId = id du contact, ?l= de /posts/confirmer)
 *   cta cand_choisir_payer            → InitiateCheckout
 *   cta cand_paye_ok                  → Purchase        (valeur + devise + eventId = réservation, si fournis)
 * Rien d'autre ne part vers Meta.
 */
export function pixelFromSiteEvent(type: string, path: string, extra: { label?: string; value?: number; currency?: string; eventId?: string }) {
  try {
    if (!pixelAllowed(path)) return;
    const label = extra.label || "";
    if (type === "pageview") {
      if (/^\/application\/[^/]+/.test(path)) pixelTrack("ViewContent", { content_name: "candidats", content_category: "application" }, idFromPath(path));
      return;
    }
    if (type !== "cta_click") return;
    // 09/11 (BOB, ordre Daniel « optimiser la pub sur la demande publiée ») — page /demande et /request :
    // demande_publiee → Lead avec le même eventId que le Lead CAPI serveur (id du contact) = dédoublonné ;
    // demande_envoyee (formulaire envoyé, code pas encore tapé) → CompleteRegistration.
    if (label === "demande_publiee") {
      pixelTrack("Lead", { content_name: "demande_publiee", content_category: "demande_page" }, extra.eventId);
    } else if (label === "demande_envoyee") {
      pixelTrack("CompleteRegistration", { content_name: "demande_envoyee" }, extra.eventId);
    } else if (label === "lead_confirme") {
      pixelTrack("Lead", { content_name: "demande_publiee" }, extra.eventId || leadIdFromUrl());
    } else if (label === "cand_choisir_payer") {
      pixelTrack("InitiateCheckout", { content_name: "choisir_payer" }, extra.eventId || idFromPath(path));
    } else if (label === "cand_paye_ok") {
      const p: Record<string, string | number> = { content_name: "reservation" };
      if (typeof extra.value === "number" && Number.isFinite(extra.value)) p.value = extra.value;
      if (extra.currency) p.currency = String(extra.currency).toUpperCase();
      pixelTrack("Purchase", p, extra.eventId);
    }
  } catch { /* jamais bloquant */ }
}

function idFromPath(path: string): string | undefined {
  const m = path.match(/^\/application\/([A-Za-z0-9]+)/);
  return m ? m[1] : undefined;
}

function leadIdFromUrl(): string | undefined {
  try {
    const l = new URLSearchParams(window.location.search).get("l") || "";
    return /^[a-f0-9]{32}$/.test(l) ? l : undefined;
  } catch {
    return undefined;
  }
}
