"use client";

/**
 * SiteAnalytics — v576
 *
 * Mesure d'audience maison du site : combien de personnes arrivent depuis la
 * pub Meta, et combien touchent le bouton du store.
 *
 * SANS COOKIE, SANS STOCKAGE, SANS DONNÉE PERSONNELLE :
 *   - aucun cookie, aucun localStorage, aucun sessionStorage n'est écrit ;
 *   - les paramètres de campagne (utm_*, fbclid, gclid) sont gardés dans une
 *     simple variable de module, le temps de l'onglet, et disparaissent à la
 *     fermeture ;
 *   - on envoie le CHEMIN seul (jamais la query string, jamais un identifiant
 *     d'utilisateur) et le NOM D'HÔTE du referrer (jamais l'URL complète) ;
 *   - côté serveur, l'IP et le user-agent ne servent qu'à une empreinte
 *     anonyme qui change chaque jour, et ne sont jamais stockés.
 * Conséquence : aucun bandeau de consentement à ajouter.
 *
 * Ne ralentit pas la page : zéro dépendance, envoi via navigator.sendBeacon
 * (hors du chemin critique) programmé sur requestIdleCallback.
 */

import { useEffect } from "react";
import { usePathname } from "next/navigation";
import { API_BASE } from "@/lib/api";

const ENDPOINT = `${API_BASE}/site-events`;

/** Espaces privés / connectés : jamais mesurés (le serveur les refuse aussi). */
const EXCLUDED_PREFIXES = ["/admin", "/dashboard", "/chat"];

export type SiteEventType = "pageview" | "store_click" | "cta_click";

type Extra = {
  /** store_click : quel store. */
  store?: "ios" | "android" | "other";
  /** cta_click : quel bouton (libellé court, jamais de donnée perso). */
  label?: string;
  /** Chemin forcé (défaut : la page courante). */
  path?: string;
};

// ── Mémoire de visite (variable de module — PAS de stockage navigateur) ──────
type Campaign = { us: string; um: string; uc: string; r: string };
let campaign: Campaign | null = null;

function hostOfReferrer(): string {
  try {
    if (!document.referrer) return "";
    const h = new URL(document.referrer).hostname;
    // Navigation interne : inutile de la faire remonter comme une source.
    return h === window.location.hostname ? "" : h;
  } catch {
    return "";
  }
}

/**
 * Lit les paramètres de campagne UNE SEULE FOIS par onglet, puis les réutilise
 * pour les pages suivantes de la même visite (sinon un clic store en page 3
 * serait compté « direct » alors qu'il vient de la pub).
 *
 * `fbclid` / `gclid` : on n'envoie PAS leur valeur (c'est un identifiant de
 * clic), seulement le fait qu'ils étaient là.
 */
function readCampaign(): Campaign {
  if (campaign) return campaign;
  let us = "";
  let um = "";
  let uc = "";
  try {
    const q = new URLSearchParams(window.location.search);
    us = (q.get("utm_source") || "").slice(0, 80);
    um = (q.get("utm_medium") || "").slice(0, 80);
    uc = (q.get("utm_campaign") || "").slice(0, 80);
    if (!us && q.get("fbclid")) us = "fbclid";
    if (!us && q.get("gclid")) us = "gclid";
  } catch {
    /* URL exotique → on reste sur « direct » */
  }
  campaign = { us, um, uc, r: hostOfReferrer() };
  return campaign;
}

// ── Garde-fous ───────────────────────────────────────────────────────────────

function privacyOptOut(): boolean {
  try {
    const nav = navigator as Navigator & {
      doNotTrack?: string;
      globalPrivacyControl?: boolean;
      msDoNotTrack?: string;
    };
    const win = window as Window & { doNotTrack?: string };
    if (nav.doNotTrack === "1" || win.doNotTrack === "1" || nav.msDoNotTrack === "1") return true;
    if (nav.globalPrivacyControl === true) return true;
  } catch {
    /* rien */
  }
  return false;
}

function measurable(path: string): boolean {
  if (typeof window === "undefined" || typeof navigator === "undefined") return false;
  if (process.env.NODE_ENV !== "production") return false;
  const host = window.location.hostname;
  // Développement local et déploiements de test : jamais comptés.
  if (
    host === "localhost"
    || host === "127.0.0.1"
    || host === "::1"
    || host.endsWith(".local")
    || host.endsWith(".vercel.app")
  ) return false;
  if (privacyOptOut()) return false;
  const p = (path || "/").toLowerCase();
  return !EXCLUDED_PREFIXES.some((x) => p === x || p.startsWith(`${x}/`));
}

function langOfPage(): string {
  try {
    // Posé par LanguageProvider sur <html lang>.
    return (document.documentElement.lang || navigator.language || "").slice(0, 5);
  } catch {
    return "";
  }
}

/** Chemin seul : ni query string, ni fragment. */
function cleanPath(path?: string): string {
  const raw = path ?? window.location.pathname ?? "/";
  return raw.split("?")[0].split("#")[0].slice(0, 200) || "/";
}

// ── Envoi ────────────────────────────────────────────────────────────────────

function post(body: Record<string, string>) {
  const payload = JSON.stringify(body);
  try {
    if (navigator.sendBeacon) {
      // text/plain = requête « simple » : aucun preflight CORS, et l'envoi
      // survit à la navigation déclenchée par le clic.
      const blob = new Blob([payload], { type: "text/plain;charset=UTF-8" });
      if (navigator.sendBeacon(ENDPOINT, blob)) return;
    }
  } catch {
    /* on tente le repli */
  }
  try {
    void fetch(ENDPOINT, {
      method: "POST",
      headers: { "Content-Type": "text/plain;charset=UTF-8" },
      body: payload,
      keepalive: true,
      credentials: "omit",
      mode: "cors",
    }).catch(() => {});
  } catch {
    /* la mesure ne doit jamais casser la page */
  }
}

function whenIdle(fn: () => void) {
  try {
    const ric = (window as Window & {
      requestIdleCallback?: (cb: () => void, opts?: { timeout: number }) => number;
    }).requestIdleCallback;
    if (typeof ric === "function") {
      ric(fn, { timeout: 2000 });
      return;
    }
  } catch {
    /* repli */
  }
  window.setTimeout(fn, 250);
}

/**
 * Envoie un événement de mesure.
 * Les clics partent IMMÉDIATEMENT (avant la navigation vers le store) ;
 * les pages vues attendent un temps mort du navigateur.
 */
export function trackSiteEvent(type: SiteEventType, extra: Extra = {}) {
  const path = (() => {
    try { return cleanPath(extra.path); } catch { return "/"; }
  })();
  if (!measurable(path)) return;
  const c = readCampaign();
  const body: Record<string, string> = { t: type, p: path, l: langOfPage() };
  if (c.r) body.r = c.r;
  if (c.us) body.us = c.us;
  if (c.um) body.um = c.um;
  if (c.uc) body.uc = c.uc;
  if (type === "store_click" && extra.store) body.s = extra.store;
  if (type === "cta_click" && extra.label) body.lb = extra.label.slice(0, 60);

  // 26/09/2026 (SAM) — la langue se relit AU MOMENT de l'envoi : au montage,
  // <html lang> vaut encore « en » (valeur du serveur) tant que
  // LanguageProvider ne l'a pas posée → 444 visiteurs comptés « en » pour 73
  // « fr » sur une semaine où la pub était 100 % française.
  if (type === "pageview") whenIdle(() => post({ ...body, l: langOfPage() }));
  else post(body);
}

/** Envoyé une fois par page (rendu `null`, inséré une seule fois dans layout). */
export default function SiteAnalytics() {
  const pathname = usePathname();

  useEffect(() => {
    trackSiteEvent("pageview", { path: pathname || "/" });
  }, [pathname]);

  return null;
}

export { SiteAnalytics };
