"use client";

// 24/09/2026 — LOT B : le bouton « ? » de la carte ouvre CETTE légende en
// images (9 langues). Les dessins sont ceux des épingles réelles
// (lib/pawmapLegend.ts) : ce ne sont pas des copies qui pourraient diverger.
// Mémo : rond = personne · goutte = lieu · carré = groupe de lieux ·
// noir et or = PawSpot · rose = ami.
// 25/09 (587, point 10) — plus explicative : sections Se repérer · Voir qui est
// autour · Être visible / en direct · Agir · Réglages ; pour chaque bouton, à
// quoi il sert, pourquoi, le geste exact (clés h587_*, lib/i18n/help587.ts,
// mêmes textes que l'app) ; un exemple par section ; une FAQ.

import { useEffect, useRef, useState, type ReactNode } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import {
  memberPinHtml,
  photoPinHtml,
  memberClusterHtml,
  placePinHtml,
  placeClusterHtml,
  spotPinHtml,
  spotClusterHtml,
  reportPinHtml,
  requestBubbleHtml,
  PAWMAP_KEYFRAMES,
  ROLE_COLOR,
  PAWBOOST_TURQUOISE,
  PAWFOLLOW_VIOLET,
  PREMIUM_GOLD,
  FRIEND_PINK,
} from "@/lib/pawmapLegend";
import { AppIcon, type AppIconName } from "@/components/AppIcon";

// 25/09 (586) — dessins des nouveaux contrôles de la carte (poignée, Publier,
// Direct, œil), mêmes couleurs que sur /map.
function roundHtml(bg: string, inner: string, shadow: string, size = 40) {
  return `<span style="display:grid;place-items:center;width:${size}px;height:${size}px;border-radius:999px;background:${bg};border:1.5px solid #fff;box-shadow:0 6px 14px -6px ${shadow}">${inner}</span>`;
}
const MEGAPHONE = '<svg viewBox="0 0 24 24" width="19" height="19" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3.5 10v4h3l7 4V6l-7 4zM17 9a4 4 0 0 1 0 6M19.5 7a7.5 7.5 0 0 1 0 10"/></svg>';
const LIVE = '<svg viewBox="0 0 24 24" width="19" height="19" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round"><circle cx="12" cy="12" r="2.6" fill="#fff" stroke="none"/><path d="M8.2 8.2a5.4 5.4 0 0 0 0 7.6M15.8 8.2a5.4 5.4 0 0 1 0 7.6M5.3 5.3a9.5 9.5 0 0 0 0 13.4M18.7 5.3a9.5 9.5 0 0 1 0 13.4"/></svg>';
function eyesHtml() {
  const eye = '<path d="M2.4 12C3.4 9.4 7 5.2 12 5.2s8.6 4.2 9.6 6.8c-1 2.6-4.6 6.8-9.6 6.8S3.4 14.6 2.4 12z"/><circle cx="12" cy="12" r="3"/>';
  const svg = (inner: string) => `<svg viewBox="0 0 24 24" width="17" height="17" fill="none" stroke="#17141F" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${inner}</svg>`;
  return `<span style="display:flex;flex-direction:column;align-items:center;gap:3px">${svg(eye)}${svg(eye + '<path d="M18.2 14.6c-.9-.9-2.4-.3-2.4.9 0 1.5 2.4 3 2.4 3s2.4-1.5 2.4-3c0-1.2-1.5-1.8-2.4-.9z" fill="#F06AA0" stroke="#fff" stroke-width="1.2"/>')}${svg('<path d="M3 3l18 18M10.6 5.3c.5-.1.9-.1 1.4-.1 5 0 8.6 4.2 9.6 6.8-.4 1-1.2 2.3-2.4 3.5M6.6 6.6C4.3 8.1 2.9 10.4 2.4 12c1 2.6 4.6 6.8 9.6 6.8 1.7 0 3.2-.4 4.5-1.1M9.9 9.9a3 3 0 0 0 4.2 4.2"/>')}</span>`;
}

/** 587 (point 3) — languette des barres repliables (verre chaud + chevron). */
function barTabHtml(side: "left" | "right") {
  const d = side === "left" ? "M14 7l-5 5 5 5" : "M10 7l5 5-5 5";
  return `<span style="display:grid;place-items:center;width:22px;height:38px;border-radius:12px;background:linear-gradient(180deg,#FFFBF7,#FFF2E8);border:1px solid #fff;box-shadow:0 6px 14px -8px rgba(146,64,14,.55)"><svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="#3B2A26" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="${d}"/></svg></span>`;
}

/** 589 — rond orange signature de l'en-tête (« ? », Actualiser, roue Options). */
const ORANGE_BG = "linear-gradient(165deg,#C92A12 0%,#C92A12 50%,#9E1F0B 100%)";
const QMARK = '<svg viewBox="0 0 24 24" width="19" height="19" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M9.3 9.2a2.8 2.8 0 0 1 5.4 1c0 1.9-2.7 2.5-2.7 4.3"/><circle cx="12" cy="18" r="1.1" fill="#fff" stroke="none"/></svg>';
const REFRESH = '<svg viewBox="0 0 24 24" width="19" height="19" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M20 12a8 8 0 1 1-2.35-5.65"/><path d="M20.5 3.5v5h-5"/></svg>';
const GEAR = '<svg viewBox="0 0 24 24" width="20" height="20"><path fill="#fff" fill-rule="evenodd" d="M10.3 2.2h3.4l.5 2.5c.6.2 1.2.5 1.7.8l2.2-1.3 2.4 2.4-1.3 2.2c.3.5.6 1.1.8 1.7l2.5.5v3.4l-2.5.5c-.2.6-.5 1.2-.8 1.7l1.3 2.2-2.4 2.4-2.2-1.3c-.5.3-1.1.6-1.7.8l-.5 2.5h-3.4l-.5-2.5c-.6-.2-1.2-.5-1.7-.8l-2.2 1.3-2.4-2.4 1.3-2.2c-.3-.5-.6-1.1-.8-1.7l-2.5-.5v-3.4l2.5-.5c.2-.6.5-1.2.8-1.7L3.5 6.6l2.4-2.4 2.2 1.3c.5-.3 1.1-.6 1.7-.8zM12 8.4a3.6 3.6 0 1 0 0 7.2 3.6 3.6 0 0 0 0-7.2z"/></svg>';
/** 589 — bouton « Personnaliser » de l'app : pastille blanche, liseré orange, flèches + crayon. */
function customHtml() {
  return `<span style="display:grid;place-items:center;width:40px;height:40px;border-radius:999px;background:#fff;border:1.8px solid #C92A12;box-shadow:0 6px 14px -8px #C92A12"><svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="#C92A12" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 4v11M4 7l3-3 3 3M4 12l3 3 3-3"/><path d="M13.5 19.5l.6-2.6 5.6-5.6a1.4 1.4 0 0 1 2 2l-5.6 5.6z"/></svg></span>`;
}

function seeChipsHtml() {
  const dot = (bg: string, ring = "#fff") => `<span style="width:14px;height:14px;border-radius:5px;background:${bg};border:1.5px solid ${ring}"></span>`;
  return `<span style="display:grid;grid-template-columns:repeat(4,14px);gap:3px">${["#F06AA0", "#C92A12", "#2563EB", "#16A34A", "#0E7490", "#17141F", "#D32F2F", "#C92A12"].map((c, i) => dot(c, i === 5 ? "#F4C04A" : "#fff")).join("")}</span>`;
}


// 25/09 (587, point 10) — icônes du rail, copie des `RAIL_SVG` de /map (eux-mêmes
// identiques à l'app) : la légende montre EXACTEMENT les boutons de la carte.
const RAIL_ICON = {
  around: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#FFFFFF"><path d="M12 22s-7.5-6.5-7.5-12A7.5 7.5 0 0 1 19.5 10c0 5.5-7.5 12-7.5 12z"/><g fill="rgba(0,0,0,.34)"><circle cx="10.2" cy="7.2" r="1.1"/><circle cx="13.8" cy="7.2" r="1.1"/><circle cx="8.4" cy="9.4" r="1"/><circle cx="15.6" cy="9.4" r="1"/><path d="M12 9.3c-1.7 0-3.3 1.6-3.3 3.1 0 .9.8 1.7 1.7 1.7.6 0 1.1-.3 1.6-.3s1 .3 1.6.3c.9 0 1.7-.8 1.7-1.7 0-1.5-1.6-3.1-3.3-3.1z"/></g></svg>',
  route: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 18c0-5 3-6 6-6s6-1 6-6" stroke-dasharray="3 2.6"/><circle cx="6" cy="18" r="2.6" fill="#FFFFFF" stroke="none"/><path d="M18 2.5c-1.8 0-3.2 1.4-3.2 3.2 0 2.2 3.2 5.3 3.2 5.3s3.2-3.1 3.2-5.3c0-1.8-1.4-3.2-3.2-3.2z" fill="#FFFFFF" stroke="none"/></svg>',
  chat: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#FFFFFF"><path d="M12 3C6.9 3 3 6.3 3 10.4c0 2 1 3.9 2.6 5.2L4.8 20l4.6-1.9c.8.2 1.7.3 2.6.3 5.1 0 9-3.3 9-7.4S17.1 3 12 3z"/><g fill="rgba(0,0,0,.34)"><circle cx="8.6" cy="10.6" r="1.1"/><circle cx="12" cy="10.6" r="1.1"/><circle cx="15.4" cy="10.6" r="1.1"/></g></svg>',
  photo: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#FFFFFF"><path d="M9 4h6l1.4 2.2H20a1.6 1.6 0 0 1 1.6 1.6V18A1.6 1.6 0 0 1 20 19.6H4A1.6 1.6 0 0 1 2.4 18V7.8A1.6 1.6 0 0 1 4 6.2h3.6z"/><circle cx="12" cy="12.8" r="3.6" fill="rgba(0,0,0,.34)"/></svg>',
  spot: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#FFFFFF"><path d="M12 22s-7.5-6.5-7.5-12A7.5 7.5 0 0 1 19.5 10c0 5.5-7.5 12-7.5 12z"/><path d="M12 5.4l1.4 2.9 3.1.4-2.3 2.2.6 3.1L12 12.5 9.2 14l.6-3.1-2.3-2.2 3.1-.4z" fill="rgba(0,0,0,.34)"/></svg>',
  add: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#FFFFFF"><path d="M12 22s-7.5-6.5-7.5-12A7.5 7.5 0 0 1 19.5 10c0 5.5-7.5 12-7.5 12z"/><path d="M10.9 6h2.2v2.9H16v2.2h-2.9V14h-2.2v-2.9H8V8.9h2.9z" fill="rgba(0,0,0,.34)"/></svg>',
  report: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#FFFFFF"><path d="M12 2.8 22.6 21H1.4z"/><path d="M10.9 9h2.2v6h-2.2zM10.9 16.5h2.2v2.2h-2.2z" fill="rgba(0,0,0,.4)"/></svg>',
  feed: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#FFFFFF"><path d="M5 2.5h2.2V21.5H5z"/><path d="M7.2 3.5h11.3l-2.4 4.5 2.4 4.5H7.2z"/><circle cx="18.5" cy="5" r="3.6" fill="#E24834" stroke="#fff" stroke-width="1.4"/></svg>',
} as const;
function railHtml(k: keyof typeof RAIL_ICON, g1: string, g2: string) {
  return `<span style="display:grid;place-items:center;width:40px;height:40px;border-radius:999px;background:linear-gradient(165deg,${g1},${g2});border:1.5px solid #fff;box-shadow:0 6px 14px -6px ${g2}"><span style="display:block;width:20px;height:20px">${RAIL_ICON[k].replace("<svg ", '<svg width="20" height="20" ')}</span></span>`;
}

/** Pastille ronde d'icône (même dessin que la capsule de /map). */
function RoundIcon({ name, color, filled = false }: { name: AppIconName; color: string; filled?: boolean }) {
  return (
    <span
      className="grid h-10 w-10 place-items-center rounded-full"
      style={filled
        ? { background: `linear-gradient(165deg,${color},${color})`, border: "1.5px solid #fff", boxShadow: `0 6px 14px -6px ${color}` }
        : { background: `${color}24`, border: `1px solid ${color}73` }}
    >
      <AppIcon name={name} size={20} color={filled ? "#fff" : color} />
    </span>
  );
}

// 30/09 — sommaire cliquable (demande de Daniel) : une couleur du kit par
// section, reprise sur la pastille numérotée du sommaire ET du titre. Jamais de
// couleur « encre » à faible opacité (elle redeviendrait grise) : les teintes
// pâles sont des crèmes fixes, les couleurs vives restent pleines.
const SECTION_COLOR: Record<string, string> = {
  find: "#C92A12",
  see: "linear-gradient(165deg,#F06AA0,#E0568B)",
  live: "#0E7490",
  walk: "#16A34A",
  act: "#2563EB",
  set: "#7C3AED",
  faq: "#17141F",
  pioneer: "linear-gradient(165deg,#E0553F,#C92A12 55%,#A31F0C)",
  plush: "linear-gradient(165deg,#34B857,#16A34A)",
  points: "linear-gradient(165deg,#F4C04A,#B07800)",
};

// 02/10 (607) — badge « Pionnier » (même dessin que la page /s et la fiche
// membre de /map) et peluche de la Balade (PNG de PAM, même fichier que l'app).
export function pioneerBadgeHtml(label: string): string {
  // Rond drapeau (jamais de texte coupé) + mot « Pionnier » en dessous, sur 2 lignes au besoin.
  return `<span style="display:inline-flex;flex-direction:column;align-items:center;gap:3px;width:60px"><span style="display:grid;place-items:center;width:40px;height:40px;border-radius:999px;background:linear-gradient(165deg,#E0553F,#C92A12 55%,#A31F0C);border:1.5px solid #fff;box-shadow:0 6px 14px -6px #C92A12"><svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M5 21V4"/><path d="M5 4h11l-2 4 2 4H5"/></svg></span><span style="max-width:60px;text-align:center;color:#C92A12;font:800 10px/1.1 Poppins,Inter,system-ui,sans-serif;overflow-wrap:anywhere">${label}</span></span>`;
}
// Petit ourson dessiné (rond vert de la Balade) ; remplacé par le PNG de PAM
// (même fichier que l'app) dès qu'il est livré : PLUSH_PIN_SRC.
export const PLUSH_PIN_SRC: string | null = "/plush/teddy.png";
function plushHtml(): string {
  if (PLUSH_PIN_SRC) return `<img src="${PLUSH_PIN_SRC}" alt="" width="48" height="48" style="width:48px;height:48px;object-fit:contain;filter:drop-shadow(0 4px 8px rgba(22,163,74,.45))"/>`;
  return `<span style="display:grid;place-items:center;width:46px;height:46px;border-radius:999px;background:linear-gradient(165deg,#43B862,#1F7A37);border:2px solid #fff;box-shadow:0 6px 14px -6px #16A34A"><svg viewBox="0 0 40 40" width="32" height="32"><circle cx="11" cy="11" r="6" fill="#B7793F"/><circle cx="29" cy="11" r="6" fill="#B7793F"/><circle cx="11" cy="11" r="3" fill="#F2C9A0"/><circle cx="29" cy="11" r="3" fill="#F2C9A0"/><circle cx="20" cy="21" r="13" fill="#C98A4B"/><ellipse cx="20" cy="26" rx="6.5" ry="5" fill="#F2C9A0"/><circle cx="15" cy="19" r="1.8" fill="#231715"/><circle cx="25" cy="19" r="1.8" fill="#231715"/><ellipse cx="20" cy="24.5" rx="2.4" ry="1.7" fill="#231715"/><path d="M17.5 28.2q2.5 1.8 5 0" stroke="#231715" stroke-width="1.3" fill="none" stroke-linecap="round"/></svg></span>`;
}
function NumBadge({ n, id, size = 24 }: { n: number; id: string; size?: number }) {
  return (
    <span
      aria-hidden="true"
      className="grid shrink-0 place-items-center rounded-full font-extrabold leading-none text-white"
      style={{ width: size, height: size, fontSize: size >= 28 ? 14 : 12.5, background: SECTION_COLOR[id] || "#C92A12", boxShadow: "0 0 0 2px #fff, 0 4px 10px -4px rgba(35,23,21,.45)" }}
    >
      {n}
    </span>
  );
}

type Row = { html?: string; node?: ReactNode; title: string; body?: string; color?: string; /** 29/09 — petite bulle sous le titre (texte exact de la carte). */ chip?: { text: string; color: string; border: string; bg?: string } };
type Section = { id: string; title: string; rows: Row[]; example?: string; /** 02/10 (607) — petite galerie (les 5 peluches), sous le titre. */ gallery?: { src: string; label: string }[]; /** 02/10 — lien « en savoir plus ». */ link?: { href: string; label: string }; image?: { src: string; srcSet?: string; darkSrc?: string; darkSrcSet?: string; alt: string } };

// 29/09 — section « La Balade » : dessins compacts (56 px) de ce que l'on voit
// vraiment sur /map : pilule verte du direct, tracé violet PawFollow.
function walkPillHtml(minTxt: string) {
  // 601 — le drapeau Balade de la barre de droite : badge vert compact (durée,
  // œil + nombre de suiveurs) posé au-dessus du bouton Balade en direct.
  const eye = '<svg viewBox="0 0 24 24" width="11" height="11" fill="#fff"><path d="M12 5C6.5 5 2.7 9.1 1.5 12c1.2 2.9 5 7 10.5 7s9.3-4.1 10.5-7C21.3 9.1 17.5 5 12 5zm0 11a4 4 0 1 1 0-8 4 4 0 0 1 0 8z"/><circle cx="12" cy="12" r="2"/></svg>';
  const walker = '<svg viewBox="0 0 24 24" width="20" height="20" fill="#fff"><circle cx="13.5" cy="4.5" r="2"/><path d="M9.8 8.9 7 23h2.1l1.8-8 2.1 2v6h2v-7.5l-2.1-2 .6-3A7.3 7.3 0 0 0 19 13v-2a5 5 0 0 1-4.3-2.4l-1-1.6a2 2 0 0 0-1.7-1c-.3 0-.5.1-.8.1L6 8.3V13h2V9.6z"/></svg>';
  return `<span style="display:inline-flex;flex-direction:column;align-items:center;gap:3px"><span style="display:flex;flex-direction:column;align-items:center;width:44px;padding:4px 3px;border-radius:12px;background:linear-gradient(170deg,#7FE39A -20%,#2E9E48 45%,#1D7A34 100%);border:1.4px solid #fff;box-shadow:0 3px 8px rgba(29,122,52,.35);color:#fff;font:800 10.5px/1.05 Poppins,Inter,system-ui,sans-serif;white-space:nowrap"><span>${minTxt}</span><span style="display:inline-flex;align-items:center;gap:2px;margin-top:2px;font-size:9.5px;font-weight:700">${eye}2</span></span><span style="display:grid;place-items:center;width:38px;height:38px;border-radius:999px;background:linear-gradient(170deg,#7FE39A -20%,#2E9E48 40%,#1D7A34 100%);box-shadow:inset 0 0 0 1.5px rgba(255,255,255,.3),0 6px 12px -5px #2E9E48CC">${walker}</span></span>`;
}
/** 30/09 (604) — patte du menu de l'app : plus de point vert, c'est le CONTOUR
 *  blanc de la patte qui devient vert (un ami en direct) ou rouge (mon direct
 *  sans position). Deux pattes côte à côte : verte puis rouge. */
function menuDotHtml() {
  const paw = (ring: string) => `<svg viewBox="0 0 56 56" width="27" height="27"><circle cx="12" cy="17" r="5.5" fill="#C92A12" stroke="${ring}" stroke-width="2.5"/><circle cx="22" cy="9" r="5.5" fill="#2563EB" stroke="${ring}" stroke-width="2.5"/><circle cx="34" cy="9" r="5.5" fill="#16A34A" stroke="${ring}" stroke-width="2.5"/><circle cx="44" cy="17" r="5.5" fill="#7C3AED" stroke="${ring}" stroke-width="2.5"/><path d="M28 51c-7-6-14-12-14-20a14 14 0 0 1 28 0c0 8-7 14-14 20z" fill="#17141F" stroke="${ring}" stroke-width="3"/><circle cx="28" cy="31" r="5" fill="#fff"/><circle cx="28" cy="31" r="2.5" fill="#C92A12"/></svg>`;
  return `<span style="display:inline-flex;gap:2px;align-items:center;width:56px;justify-content:center">${paw("#16A34A")}${paw("#DC2626")}</span>`;
}

/**
 * `role` absent = la petite carte publique (accueil, /pawmap) : seulement les
 * épingles et la FAQ, ses autres boutons n'existent pas là. Avec `role` (la
 * vraie /map) : tous les boutons, par section, SEULEMENT ceux du rôle (Direct =
 * gardien / promeneur, Publier = propriétaire), comme sur la carte.
 */
export function PawMapLegendModal({ open, onClose, role }: { open: boolean; onClose: () => void; role?: "owner" | "sitter" | "walker" }) {
  const { t } = useT();
  // 30/09 — hooks AVANT le retour anticipé (piège : un hook placé après
  // « if (!open) return null » plante la page en production).
  const scrollRef = useRef<HTMLDivElement>(null);
  const tocRef = useRef<HTMLElement>(null);
  const [showBack, setShowBack] = useState(false);
  useEffect(() => {
    if (!open) return;
    setShowBack(false);
    const onKey = (e: KeyboardEvent) => { if (e.key === "Escape") onClose(); };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, onClose]);
  if (!open) return null;

  const full = role !== undefined;
  const roleK = role ?? "owner";
  const provider = roleK === "sitter" || roleK === "walker";
  const visExplained = [
    `${t("v587_all_t")} — ${t("v587_all_d")}`,
    `${t("v587_friends_t")} — ${t("v587_friends_d")}`,
    `${t("v587_hidden_t")} — ${t("v587_hidden_d")}`,
    t("v587_live"),
    t("v587_where"),
  ].join("\n");

  // 27/09 — Daniel : expliquer les couleurs du bouton « Profil » selon le
  // rôle et la bulle double prix (mêmes couleurs que la carte).
  const pill = (bg: string, label: string) => (
    <span className="inline-flex h-[20px] items-center rounded-full px-2 text-[9.5px] font-bold text-white" style={{ background: bg, boxShadow: "inset 0 0 0 1px rgba(255,255,255,.3)" }}>{label}</span>
  );
  const roleColorsRow: Row = {
    node: (
      <span className="flex flex-col items-center gap-[3px]">
        {pill("linear-gradient(170deg,#D9442C,#C92A12 50%,#B8231A)", "›")}
        {pill("linear-gradient(90deg,#3B78E8 44%,#2E9E48 56%)", "››")}
        {pill("linear-gradient(90deg,#C92A12 27%,#3B78E8 39%,#3B78E8 61%,#2E9E48 73%)", "›››")}
      </span>
    ),
    title: t("priv2709_roles_t"),
    body: t("priv2709_roles_b"),
    color: "#231715",
  };
  const duoRow: Row = {
    node: (
      <span className="inline-flex h-[22px] items-center gap-[2px] rounded-[8px] px-1 text-[8.5px] font-bold text-white" style={{ background: "linear-gradient(90deg,#4A86F0,#2458C9 45%,#43B862 55%,#1F7A37)", boxShadow: "0 0 0 2px #fff" }}>🏠20·🚶12</span>
    ),
    title: t("priv2709_duo_t"),
    body: t("priv2709_duo_b"),
    color: ROLE_COLOR.sitter,
  };
  const pins: Row[] = [
    { html: photoPinHtml({ role: "owner", name: "Moi", me: true, meLabel: t("legend_me_label") }), title: t("legend_me"), body: t("legend_me_body"), color: ROLE_COLOR.owner },
    // 27/09 — mon rond en « amis seulement » / « masqué » (pointillés + œil barré).
    { html: photoPinHtml({ role: "owner", name: "Moi", me: true, friendsOnly: true, meLabel: t("legend_me_label") }), title: t("priv2709_mefr_t"), body: t("priv2709_mefr_b"), color: "#17141F" },
    // 27/09 — ami : halo rose, contour aux couleurs de SES rôles.
    { html: photoPinHtml({ role: "sitter", roles: ["sitter", "walker"], name: "Léa Martin", online: true }), title: t("legend_friend"), body: t("legend_friend_body"), color: FRIEND_PINK },
    { html: memberPinHtml({ role: "owner" }), title: t("legend_member_owner"), body: t("legend_member_owner_body"), color: ROLE_COLOR.owner },
    { html: memberPinHtml({ role: "sitter" }), title: t("legend_member_sitter"), body: t("legend_member_sitter_body"), color: ROLE_COLOR.sitter },
    { html: memberPinHtml({ role: "walker" }), title: t("legend_member_walker"), body: t("legend_member_walker_body"), color: ROLE_COLOR.walker },
    // 02/10 (609) — identité vérifiée : coche bleue en haut à gauche du rond.
    { html: memberPinHtml({ role: "sitter", verified: true }), title: t("ver609_help_title"), body: t("ver609_help_body"), color: "#2563EB" },
    roleColorsRow,
    duoRow,
    { html: memberPinHtml({ role: "sitter", premium: true }), title: t("legend_premium"), body: t("legend_premium_body"), color: PREMIUM_GOLD },
    { html: memberPinHtml({ role: "walker", boosted: true }), title: t("legend_boost"), body: t("legend_boost_body"), color: PAWBOOST_TURQUOISE },
    { html: memberPinHtml({ role: "walker", pawFollow: true }), title: t("legend_follow"), body: t("legend_follow_body"), color: PAWFOLLOW_VIOLET },
    // 27/09 — un seul halo à la fois (PawBoost > PawFollow > ami) + couronne.
    { node: (
        <span className="flex items-center gap-[5px]">
          {[["rgba(6,182,212,.75)", "#06B6D4"], ["rgba(124,58,237,.55)", "#7C3AED"], ["rgba(227,90,154,.62)", "#E35A9A"]].map(([g, c]) => (
            <span key={c} className="block h-[13px] w-[13px] rounded-full border-2 border-white" style={{ background: c, boxShadow: `0 0 7px 3px ${g}` }} />
          ))}
        </span>
      ), title: t("priv2709_halo_t"), body: t("priv2709_halo_b"), color: "#17141F" },
    { html: memberClusterHtml(4, "sitter"), title: t("legend_member_group"), body: t("legend_member_group_body"), color: ROLE_COLOR.sitter },
    { html: memberClusterHtml(3, "walker", true), title: t("legend_member_group_friend"), body: t("legend_member_group_friend_body"), color: FRIEND_PINK },
    { html: requestBubbleHtml({ service: "sitting", priceLabel: "25 €" }), title: t("legend_request"), body: t("legend_request_body"), color: ROLE_COLOR.owner },
    { html: placePinHtml("vet"), title: t("legend_place"), body: t("legend_place_body") },
    { html: placeClusterHtml(6, "park"), title: t("legend_place_group"), body: t("legend_place_group_body") },
    { html: spotPinHtml("path_walk", false), title: t("legend_spot"), body: t("legend_spot_body") },
    { html: spotPinHtml("path_walk", true), title: t("legend_spot_gold"), body: t("legend_spot_gold_body"), color: PREMIUM_GOLD },
    { html: spotClusterHtml(3), title: t("legend_spot_group") },
    { html: reportPinHtml(), title: t("legend_report"), body: t("legend_report_body") },
  ];
  const roleColor = ROLE_COLOR[roleK];

  // 29/09 — Daniel : « La Balade » expliquée. TEXTES DE PAM (help599_*,
  // ~/hopetsit-social/pawmap_599/balade_textes_9langues.json), mot pour mot :
  // site et app disent la même chose. Visible aussi sur la carte publique.
  // Le contour vert/rouge de la patte du menu n'existe que dans l'app → « Dans l'app ».
  const walkSection: Section = {
    id: "walk",
    title: t("help599_sec_balade"),
    example: t("help599_ex_balade"),
    // 29/09 01 h 38 — l'image de PAM (même fichier que l'app, sans mot) : claire / nuit, @2x et @3x.
    image: {
      src: "/pawmap/balade_604_clair@2x.png", srcSet: "/pawmap/balade_604_clair@2x.png 2x, /pawmap/balade_604_clair@3x.png 3x",
      darkSrc: "/pawmap/balade_604_nuit@2x.png", darkSrcSet: "/pawmap/balade_604_nuit@2x.png 2x, /pawmap/balade_604_nuit@3x.png 3x",
      alt: t("help599_img_caption"),
    },
    rows: [
      { html: walkPillHtml(t("p601_pawmap601_walk_min").replace("{n}", "12")), title: `${t("help599_t_me")} · « ${t("m590_on_walk")} · ${t("p601_pawmap601_walk_min").replace("{n}", "12")} · ${t("bal2909_followers").replace("{n}", "2")} »`, body: t("help599_b_me"), color: "#1F7A37" },
      { html: photoPinHtml({ role: "walker", name: "Kathy", followed: true, online: true }), title: t("help599_t_others"), body: t("help599_b_others"), color: PAWFOLLOW_VIOLET, chip: { text: t("bal2909_live_now"), color: ROLE_COLOR.walker, border: FRIEND_PINK } },
      { html: menuDotHtml(), title: `${t("help599_t_dot")} · ${t("p589_in_app")}`, body: t("help599_b_dot"), color: "#16A34A" },
    ],
  };

  // 02/10 (607) — décision de Daniel : « Ramène tes clients / Pionnier » et
  // « Les peluches de la Balade », mêmes clés et mêmes textes que l'app
  // (help607_*, lib/i18n/site607.ts). Visibles aussi sur la carte publique.
  const sections607: Section[] = [
    { id: "pioneer", title: t("help607_pioneer_title"), rows: [{ html: pioneerBadgeHtml(t("help607_pioneer_badge")), title: "", body: t("help607_pioneer_body") }] },
    {
      id: "plush",
      title: t("help607_plush_title"),
      // 02/10 (Daniel) — les 5 peluches côte à côte (PNG de PAM) + la dorée à part, avec le barème.
      gallery: ["teddy", "bunny", "kitty", "puppy", "fox"].map((ty, i) => ({ src: `/plush/${ty}.png`, label: t(`help607_plush_names_${i + 1}`) })),
      rows: [
        { html: plushHtml(), title: "", body: t("help607_plush_body") },
        { html: `<img src="/plush/teddy_gold.png" alt="" width="52" height="52" style="width:52px;height:52px;object-fit:contain;filter:drop-shadow(0 4px 8px rgba(183,121,31,.5))"/>`, title: t("help607_plush_gold"), body: t("help607_plush_bonus"), color: "#8A5A00" },
      ],
      link: { href: "/pawpoints-guide", label: t("ppg_link") },
    },
    // 02/10 (607, ZOE) — « Les PawPoints » : même texte que l'app (pp607_help_points_*).
    { id: "points", title: t("pp607_help_points_title"), link: { href: "/pawpoints-guide", label: t("ppg_link") }, rows: [{ html: `<span style="display:grid;place-items:center;width:46px;height:46px;border-radius:999px;background:linear-gradient(165deg,#F4C04A,#D99A0B 55%,#B07800);border:2px solid #fff;box-shadow:0 6px 14px -6px #B07800;font-size:22px">🪙</span>`, title: "", body: t("pp607_help_points_body") }] },
  ];

  const sections: Section[] = full
    ? [
        {
          id: "find", title: t("h587_sec_find"), example: t("h587_ex_find"),
          rows: [
            // 589 — les ronds orange de l'en-tête : « ? » puis Actualiser.
            { html: roundHtml(ORANGE_BG, QMARK, "rgba(185,36,37,0.85)"), title: t("p589_t_legendbtn"), body: t("p589_b_legendbtn"), color: "#C92A12" },
            { html: roundHtml(ORANGE_BG, REFRESH, "rgba(185,36,37,0.85)"), title: t("p589_refresh"), body: t("p589_b_refresh"), color: "#C92A12" },
            { node: <RoundIcon name="pin" color="#C92A12" />, title: t("h587_t_pins"), body: t("h587_b_pins") },
            ...pins,
            { node: <RoundIcon name="locate" color={roleColor} filled />, title: t("map_locate_btn"), body: t("h587_b_locate"), color: roleColor },
            { node: <span className="grid h-10 w-10 place-items-center rounded-full border border-[#17141F]/40 bg-[#17141F]/10 text-base font-extrabold leading-none text-[#17141F] dark:text-[#FBEFE6]">±</span>, title: t("h587_t_zoom"), body: t("h587_b_zoom") },
            { node: <RoundIcon name="globe" color="#C92A12" />, title: t("h587_t_sat"), body: t("h587_b_sat") },
            { node: <RoundIcon name="search" color="#2563EB" />, title: t("h587_t_search"), body: t("h587_b_search") },
            { html: railHtml("around", "#A076FF", "#7040D6"), title: t("map_around_title"), body: t("h587_b_around") },
            { html: railHtml("route", "#3DBF6C", "#188A42"), title: t("map_directions_btn"), body: t("h587_b_directions") },
            { node: <RoundIcon name="map" color="#2563EB" />, title: t("h587_t_fade"), body: t("h587_b_fade") },
          ],
        },
        {
          id: "see", title: t("h587_sec_see"), example: t("h587_ex_see"),
          rows: [
            { html: seeChipsHtml(), title: t("m586_see_title"), body: t("h587_b_see") },
            { node: <RoundIcon name="friends" color={FRIEND_PINK} />, title: t("map_live_friends"), body: t("h587_b_live_friends"), color: FRIEND_PINK },
            { node: <RoundIcon name="people" color="#E8448F" />, title: t("map_members_show"), body: t("h587_b_members"), color: "#E8448F" },
            { node: <RoundIcon name="friends" color={FRIEND_PINK} filled />, title: t("map_friends_btn"), body: t("h587_b_friends"), color: FRIEND_PINK },
            { html: railHtml("spot", "#FAC346", "#E2981A"), title: t("map_panel_spots_title"), body: t("h587_b_spots") },
            { html: railHtml("feed", "#6B5A50", "#2E231D"), title: t("map_panel_reports_title"), body: t("h587_b_feed") },
          ],
        },
        {
          id: "live", title: t("h587_sec_live"), example: provider ? t("h601_ex_live_walker") : t("h587_ex_live_owner"),
          rows: [
            { html: eyesHtml(), title: t("m586_leg_eye_t"), body: t("h587_b_eye"), color: "#17141F" },
            // 587 — Daniel : les 3 réglages en clair, mêmes phrases que le réglage (vis587).
            { html: eyesHtml(), title: t("v587_title"), body: visExplained, color: "#17141F" },
            // 587 — le Direct existe pour les 3 profils (propriétaire compris).
            { html: `<span style="display:flex;gap:4px">${roundHtml("linear-gradient(165deg,#2C2533,#17141F)", LIVE, "rgba(23,20,31,0.7)", 30)}${roundHtml("linear-gradient(165deg,#34B857,#16A34A)", LIVE, "#16A34A", 30)}</span>`, title: t("p601_pawmap590_walk"), body: `${t("h601_b_direct")} ${t("p589_direct_account")}`, color: "#17141F" },
          ],
        },
        walkSection,
        {
          id: "act", title: t("h587_sec_act"), example: t("h587_ex_act"),
          rows: [
            ...(!provider
              ? [{ html: roundHtml("linear-gradient(165deg,#E0553F,#C92A12 55%,#A31F0C)", MEGAPHONE, "#C92A12"), title: t("m586_publish"), body: t("h587_b_publish"), color: ROLE_COLOR.owner }]
              : []),
            // 02/10 (607) — bouton PawPoints de la barre de gauche.
            { html: `<span style="display:grid;place-items:center;width:40px;height:40px;border-radius:999px;background:linear-gradient(165deg,#FFD86B,#E8A00A 50%,#B07800);border:1.5px solid #fff;box-shadow:0 6px 14px -6px #B07800"><img src="/plush/teddy.png" alt="" width="26" height="26" style="width:26px;height:26px;object-fit:contain"/></span>`, title: t("ppr607_btn"), body: t("ppr607_help"), color: "#8A5A00" },
            { html: railHtml("chat", "#5B9DFF", "#2358D6"), title: t("dash_card_messages_title"), body: t("h587_b_chat") },
            { html: railHtml("photo", "#FFB067", "#E07A12"), title: t("map_spot_photo_label"), body: t("h587_b_photo") },
            { html: railHtml("add", "#48C8BA", "#18968A"), title: t("map_tag_spot_cta"), body: t("h587_b_tag") },
            { html: railHtml("report", "#FF6E5C", "#D63A28"), title: t("map_report_cta"), body: t("h587_b_report") },
          ],
        },
        {
          id: "set", title: t("h587_sec_set"), example: t("h587_ex_set"),
          rows: [
            // 589 — la roue « Options de la carte » remplace la pilule du bas.
            { html: roundHtml(ORANGE_BG, GEAR, "rgba(185,36,37,0.85)"), title: t("p589_options"), body: t("p589_b_options"), color: "#C92A12" },
            { html: `<span style="display:flex;gap:4px">${barTabHtml("left")}${barTabHtml("right")}</span>`, title: t("m587_leg_bars_t"), body: t("m587_leg_bars_b"), color: "#17141F" },
            { node: <RoundIcon name="moon" color="#17141F" />, title: t("p589_night"), body: t("p589_b_night") },
            { node: <RoundIcon name="crown" color="#7C3AED" />, title: t("map_subs_title"), body: t("h587_b_subs"), color: "#7C3AED" },
            // 589 — « Modifier ma barre » n'existe que dans l'app : dit clairement.
            { html: customHtml(), title: `${t("p589_custom_t")} · ${t("p589_in_app")}`, body: t("p589_b_custom"), color: "#C92A12" },
          ],
        },
        ...sections607,
      ]
    : [{ id: "find", title: t("h587_sec_find"), rows: [{ node: <RoundIcon name="pin" color="#C92A12" />, title: t("h587_t_pins"), body: t("h587_b_pins") }, ...pins] }, walkSection, ...sections607];

  // 587 — « Qui voit ma position ? » = les phrases du réglage, mot pour mot.
  const faq = [1, 2, 3, 4].map((n) => ({ q: t(`h587_q${n}`), a: n === 2 ? visExplained : t(`h587_a${n}`) }));

  // 30/09 — sommaire : sections numérotées dans l'ordre d'affichage, FAQ en dernier.
  const toc = [...sections.map((s) => ({ id: s.id, title: s.title })), { id: "faq", title: t("h587_faq_title") }].map((x, i) => ({ ...x, n: i + 1 }));
  const reduceMotion = () => typeof window !== "undefined" && window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
  // Défile DANS la fenêtre (le conteneur qui défile), jamais la page derrière.
  const goTo = (id: string) => {
    const box = scrollRef.current;
    const target = document.getElementById(`legend-part-${id}`);
    if (!box || !target) return;
    const top = target.getBoundingClientRect().top - box.getBoundingClientRect().top + box.scrollTop - 12;
    box.scrollTo({ top: Math.max(0, top), behavior: reduceMotion() ? "auto" : "smooth" });
    document.getElementById(`legend-sec-${id}`)?.focus({ preventScroll: true });
  };
  const backToToc = () => {
    scrollRef.current?.scrollTo({ top: 0, behavior: reduceMotion() ? "auto" : "smooth" });
    tocRef.current?.querySelector<HTMLButtonElement>("button")?.focus({ preventScroll: true });
  };
  const onScroll = () => {
    const box = scrollRef.current;
    const nav = tocRef.current;
    if (!box || !nav) return;
    const past = box.scrollTop > nav.offsetTop + nav.offsetHeight;
    if (past !== showBack) setShowBack(past);
  };

  return (
    <div
      className="fixed inset-0 z-[3000] flex items-end justify-center bg-[#231715]/55 p-0 sm:items-center sm:p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="pawmap-legend-title"
      onClick={onClose}
    >
      <style dangerouslySetInnerHTML={{ __html: `${PAWMAP_KEYFRAMES}@keyframes hps-dot-pulse{0%,100%{box-shadow:0 0 0 0 rgba(255,255,255,.7)}50%{box-shadow:0 0 0 5px rgba(255,255,255,0)}}.hps-dot-pulse{animation:hps-dot-pulse 1.4s ease-out infinite}` }} />
      <div
        ref={scrollRef}
        onScroll={onScroll}
        data-legend-scroll=""
        className="relative max-h-[88vh] w-full max-w-lg overflow-y-auto overscroll-contain rounded-t-[28px] bg-white p-4 shadow-2xl sm:rounded-[28px] sm:p-7 dark:bg-[#241916]"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <h2 id="pawmap-legend-title" className="font-display text-xl font-bold tracking-[-0.02em] text-[#231715] dark:text-[#FBEFE6]">
              {t("legend_title")}
            </h2>
            <p className="mt-1 text-sm text-[#3B2A26] dark:text-[#EBDDD6]">{full ? t("h587_intro") : t("legend_intro")}</p>
          </div>
          <button
            type="button"
            onClick={onClose}
            aria-label={t("map_close")}
            className="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-[#FAF1EC] text-[#231715] transition hover:bg-[#F0E3DF] dark:bg-[#3A2A25] dark:text-[#FBEFE6]"
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round"><path d="M6 6l12 12M6 18L18 6" /></svg>
          </button>
        </div>

        {/* 30/09 — sommaire cliquable : chaque titre mène directement à sa section. */}
        <nav ref={tocRef} aria-labelledby="legend-toc-title" className="mt-4 rounded-[22px] border border-[#F1D9CC] bg-[#FFF7F2] p-3 dark:border-[#4A332C] dark:bg-[#2E201C]">
          <p id="legend-toc-title" className="px-1 text-[12px] font-extrabold uppercase tracking-[0.06em] text-[#C92A12] dark:text-[#FF9A85]">{t("toc3009_title")}</p>
          <ul className="mt-2 grid grid-cols-2 gap-1.5">
            {toc.map((x) => (
              <li key={x.id} className="min-w-0">
                <button
                  type="button"
                  data-toc={x.id}
                  onClick={() => goTo(x.id)}
                  className="flex min-h-[44px] w-full items-center gap-2 rounded-2xl border border-[#F1D9CC] bg-white px-2.5 py-1.5 text-left transition hover:border-[#C92A12] hover:bg-[#FCEDE4] focus-visible:outline focus-visible:outline-2 focus-visible:outline-[#C92A12] dark:border-[#4A332C] dark:bg-[#241916] dark:hover:border-[#FF9A85] dark:hover:bg-[#3A2A25]"
                >
                  <NumBadge n={x.n} id={x.id} />
                  <span className="min-w-0 break-words text-[13px] font-bold leading-tight text-[#231715] dark:text-[#FBEFE6]">{x.title}</span>
                </button>
              </li>
            ))}
          </ul>
        </nav>

        <p className="mt-4 rounded-2xl bg-[#17141F] px-4 py-3 text-sm font-semibold text-[#F4C04A]">{t("legend_memo")}</p>

        {/* 27/09 — Daniel : positions floutées ~1 km, seul le Direct est exact. */}
        <div className="mt-3 flex items-start gap-3 rounded-2xl border border-[#2E9E48]/40 bg-[#E9F7EE] px-4 py-3 dark:border-[#43B862]/40 dark:bg-[#15291B]">
          <span aria-hidden="true" className="grid h-9 w-9 shrink-0 place-items-center rounded-full" style={{ background: "linear-gradient(165deg,#43B862,#1F7A37)" }}>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"><rect x="5" y="11" width="14" height="10" rx="2.5" /><path d="M8 11V8a4 4 0 0 1 8 0v3" /></svg>
          </span>
          <span className="min-w-0">
            <span className="block text-sm font-bold text-[#1F7A37] dark:text-[#7FE39A]">{t("priv2709_title")}</span>
            <span className="mt-0.5 block break-words text-[13px] leading-snug text-[#23352A] dark:text-[#DDEFE2]">{t("priv2709_body")}</span>
          </span>
        </div>

        {sections.map((sec, si) => (
          <section key={sec.id} id={`legend-part-${sec.id}`} aria-labelledby={`legend-sec-${sec.id}`} className="mt-6">
            <h3 id={`legend-sec-${sec.id}`} tabIndex={-1} className="flex items-center gap-2.5 font-display text-lg font-bold text-[#231715] outline-none dark:text-[#FBEFE6]">
              <NumBadge n={si + 1} id={sec.id} size={28} />
              <span className="min-w-0 break-words">{sec.title}</span>
            </h3>
            {sec.image && (
              // 29/09 — image de la section = celle de PAM (même fichier que l'app), nette à 2× / 3×,
              // version nuit quand le mode sombre est actif ; légende d'image en dessous.
              <figure className="mt-3">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={sec.image.src} srcSet={sec.image.srcSet} alt={sec.image.alt} width={720} height={430} loading="lazy" className={`block h-auto w-full rounded-[20px] border border-[#7C3AED]/25 shadow-[0_10px_24px_-14px_rgba(124,58,237,0.6)] ${sec.image.darkSrc ? "dark:hidden" : ""}`} />
                {sec.image.darkSrc && (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={sec.image.darkSrc} srcSet={sec.image.darkSrcSet} alt={sec.image.alt} width={720} height={430} loading="lazy" className="hidden h-auto w-full rounded-[20px] border border-[#7C3AED]/40 shadow-[0_10px_24px_-14px_rgba(124,58,237,0.6)] dark:block" />
                )}
                <figcaption className="mt-1.5 break-words text-center text-[12px] font-semibold leading-snug text-[#3B2A26] dark:text-[#EBDDD6]">{sec.image.alt}</figcaption>
              </figure>
            )}
            {sec.gallery && (
              <ul className="mt-3 grid grid-cols-5 gap-1.5" data-legend-gallery={sec.id}>
                {sec.gallery.map((g) => (
                  <li key={g.src} className="flex min-w-0 flex-col items-center rounded-2xl bg-[#EFFAF2] px-1 py-2 text-center dark:bg-[#15291B]">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={g.src} alt="" width={44} height={44} className="h-11 w-11 object-contain" />
                    <span className="mt-1 w-full break-words text-[11px] font-bold leading-tight text-[#0F5C2B] dark:text-[#BFE8CC]">{g.label}</span>
                  </li>
                ))}
              </ul>
            )}
            <ul className="mt-2 space-y-1.5">
              {sec.rows.map((r, i) => (
                <li key={`${sec.id}-${i}`} className="flex items-start gap-3 rounded-2xl px-1 py-2 sm:gap-4 sm:px-2">
                  {r.node
                    ? <span className="grid h-14 w-14 shrink-0 place-items-center">{r.node}</span>
                    : <span className="grid h-14 w-14 shrink-0 place-items-center sm:h-16 sm:w-16" dangerouslySetInnerHTML={{ __html: r.html || "" }} />}
                  <span className="min-w-0 flex-1 pt-1">
                    {r.title && <span className="block break-words text-sm font-bold dark:!text-[#FBEFE6]" style={{ color: r.color || "#231715" }}>{r.title}</span>}
                    {r.chip && (
                      <span className="mt-1 inline-block rounded-full px-2 py-[1px] text-[11px] font-bold leading-[1.3]" style={{ color: r.chip.color, background: r.chip.bg || "#fff", border: `1.5px solid ${r.chip.border}`, boxShadow: "0 1px 4px rgba(23,20,31,.25)" }}>{r.chip.text}</span>
                    )}
                    {r.body && <span className="mt-0.5 block whitespace-pre-line break-words text-[13px] leading-snug text-[#3B2A26] dark:text-[#EBDDD6]">{r.body}</span>}
                  </span>
                </li>
              ))}
            </ul>
            {sec.link && (
              <a href={sec.link.href} className="mt-1 inline-flex min-h-[44px] items-center gap-1 px-1 text-[13px] font-extrabold text-[#9E1F0B] underline-offset-2 hover:underline dark:text-[#FF9A85]">
                {sec.link.label} →
              </a>
            )}
            {sec.example && (
              <p className="mt-2 flex items-start gap-2.5 rounded-2xl border border-[#E8920A]/45 bg-[#FCEDE4] px-3.5 py-3 text-[13px] leading-snug text-[#3B2A26] dark:bg-[#2E201C] dark:text-[#EBDDD6]">
                <span aria-hidden="true" className="shrink-0 text-base leading-none">💡</span>
                <span className="min-w-0 break-words"><strong className="font-extrabold text-[#C92A12] dark:text-[#FF9A85]">{t("h587_ex_label")} · </strong>{sec.example}</span>
              </p>
            )}
          </section>
        ))}

        <section id="legend-part-faq" aria-labelledby="legend-sec-faq" className="mt-6">
          <h3 id="legend-sec-faq" tabIndex={-1} className="flex items-center gap-2.5 font-display text-lg font-bold text-[#231715] outline-none dark:text-[#FBEFE6]">
            <NumBadge n={sections.length + 1} id="faq" size={28} />
            <span className="min-w-0 break-words">{t("h587_faq_title")}</span>
          </h3>
          <div className="mt-2 space-y-2">
            {faq.map((f) => (
              <details key={f.q} className="group rounded-2xl border border-[#C92A12]/25 bg-white px-3.5 py-3 dark:bg-[#2E201C]" open={full}>
                <summary className="cursor-pointer list-none break-words text-sm font-extrabold text-[#231715] dark:text-[#FBEFE6]">{f.q}</summary>
                <p className="mt-1.5 whitespace-pre-line break-words text-[13px] leading-snug text-[#3B2A26] dark:text-[#EBDDD6]">{f.a}</p>
              </details>
            ))}
          </div>
        </section>

        <button
          type="button"
          onClick={onClose}
          className="mt-5 inline-flex min-h-[48px] w-full items-center justify-center gap-2 rounded-[18px] bg-[#231715] px-5 text-sm font-semibold text-white transition hover:bg-black dark:bg-[#C92A12]"
        >
          <AppIcon name="check" size={18} />
          {t("legend_close")}
        </button>

        {/* 30/09 — retour au sommaire : collé en bas de la fenêtre dès qu'on a dépassé le sommaire. */}
        <div className="pointer-events-none sticky bottom-0 z-10 flex h-0 justify-end">
          <button
            type="button"
            onClick={backToToc}
            tabIndex={showBack ? 0 : -1}
            aria-hidden={!showBack}
            data-toc-back=""
            className={`pointer-events-auto -mt-[60px] mb-2 inline-flex min-h-[44px] items-center gap-1.5 self-end rounded-full px-4 text-[13px] font-extrabold text-white shadow-[0_10px_22px_-10px_rgba(201,42,18,0.9)] transition-opacity duration-200 ${showBack ? "opacity-100" : "pointer-events-none opacity-0"}`}
            style={{ background: "linear-gradient(165deg,#E0553F,#C92A12 55%,#A31F0C)", border: "1.5px solid #fff" }}
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M6 14l6-6 6 6" /></svg>
            {t("toc3009_back")}
          </button>
        </div>
      </div>
    </div>
  );
}

export default PawMapLegendModal;
