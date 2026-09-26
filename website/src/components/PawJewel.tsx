"use client";

// 26/09/2026 — PawMap 590 (site) : les boutons « BIJOU » de l'app
// (frontend/lib/views/map/widgets/pawmap_jewel.dart), handoff design §3.1 :
//   · rond, dégradé 170° en TROIS tons (clair −20 %, moyen 40 %, foncé 100 %) ;
//   · liseré intérieur blanc 1,5 px à 30 %, ombre intérieure en bas, filet
//     sombre 1 px, halo coloré sous le bouton ;
//   · reflet en haut (45 % de la hauteur) ;
//   · icône Material Symbols Rounded PLEINE (FILL 1, wght 600, GRAD 200,
//     opsz 48), blanche, dégradé vertical 100 % → 72 % + légère ombre.
// Survol : monte de 1 px et grossit de 5 % ; appui : 94 % ; 150 ms.
// Zone cliquable ≥ 44 px même quand le disque fait 38 px.

import { useEffect } from "react";

export type JewelPalette = readonly [string, string, string];

/** §3.2 — code couleur des boutons (identique à l'app). */
export const JEWEL = {
  chat: ["#6B9BFF", "#3B6FE0", "#2451B8"],
  photo: ["#FFC06A", "#F39A2B", "#D97A0E"],
  spots: ["#FFD76A", "#F0B323", "#CF9208"],
  tag: ["#52D6C6", "#1FA89A", "#0F7F70"],
  feed: ["#6A5C57", "#3A2F2C", "#1D1715"],
  report: ["#FF806B", "#E0402F", "#B8261A"],
  friends: ["#FF8CC2", "#E8448F", "#C12A6E"],
  route: ["#5FCC79", "#2E9E48", "#1D7A34"],
  around: ["#B08CFF", "#7B4DE0", "#5A30BF"],
  /** Les 4 boutons du haut à droite : rouges pour les 3 rôles. */
  header: ["#D9442C", "#C92A12", "#B8231A"],
} as const satisfies Record<string, JewelPalette>;

/** §9 — couleurs des rôles (viseur, flèches, bouton principal). */
export const JEWEL_ROLE: Record<"owner" | "sitter" | "walker", JewelPalette> = {
  owner: ["#D9442C", "#C92A12", "#B8231A"],
  sitter: ["#8AB8FF", "#3B78E8", "#1F4FBF"],
  walker: ["#7FE39A", "#2E9E48", "#1D7A34"],
};
/** §9 — couleur « solide » du rôle (libellés, chevrons). */
export const ROLE_SOLID_UI: Record<"owner" | "sitter" | "walker", string> = { owner: "#D8352A", sitter: "#2F6FE0", walker: "#2A9A48" };

export const jewelGradient = (p: JewelPalette) => `linear-gradient(170deg, ${p[0]} -20%, ${p[1]} 40%, ${p[2]} 100%)`;

// Une seule feuille : les icônes utilisées par la carte (sous-ensemble, léger)
// + Poppins (textes de la carte, comme l'app). `display=block` : jamais le
// nom de l'icône écrit en toutes lettres pendant le chargement.
const ICON_NAMES = [
  "add", "add_location_alt", "assignment", "award_star", "campaign", "close", "explore_nearby", "forum", "group", "groups",
  "map", "my_location", "photo_camera", "public", "question_mark", "refresh", "remove", "route", "search", "settings", "tour", "warning",
].sort();
const FONT_URLS = [
  `https://fonts.googleapis.com/css2?family=Material+Symbols+Rounded:opsz,wght,FILL,GRAD@48,600,1,200&icon_names=${ICON_NAMES.join(",")}&display=block`,
  "https://fonts.googleapis.com/css2?family=Poppins:wght@500;600;700;800&display=swap",
];

/** Charge les polices de la carte une fois (balises dans <head>). */
export function PawMapFonts() {
  useEffect(() => {
    try {
      for (const href of FONT_URLS) {
        if (document.querySelector(`link[data-hps-font="${href}"]`)) continue;
        const l = document.createElement("link");
        l.rel = "stylesheet";
        l.href = href;
        l.setAttribute("data-hps-font", href);
        document.head.appendChild(l);
      }
    } catch { /* hors navigateur */ }
  }, []);
  return null;
}

/** Icône Material Symbols Rounded pleine. */
export function PawSymbol({ name, size = 20, color, gradient = false }: { name: string; size?: number; color?: string; gradient?: boolean }) {
  return (
    <span
      aria-hidden="true"
      className="material-symbols-rounded select-none"
      style={{
        fontFamily: "'Material Symbols Rounded'",
        fontSize: size,
        width: size,
        height: size,
        lineHeight: 1,
        overflow: "hidden",
        display: "inline-block",
        fontWeight: 600,
        fontStyle: "normal",
        letterSpacing: "normal",
        whiteSpace: "nowrap",
        direction: "ltr",
        fontVariationSettings: "'FILL' 1, 'wght' 600, 'GRAD' 200, 'opsz' 48",
        WebkitFontSmoothing: "antialiased",
        ...(gradient
          ? {
              background: "linear-gradient(180deg, #FFFFFF, rgba(255,255,255,0.72))",
              WebkitBackgroundClip: "text",
              backgroundClip: "text",
              color: "transparent",
              filter: "drop-shadow(0 1.5px 1.2px rgba(23,12,8,0.3))",
            }
          : { color: color || "currentColor" }),
      }}
    >
      {name}
    </span>
  );
}

/** Bouton rond « bijou ». */
export function PawJewel({
  palette,
  icon,
  label,
  onClick,
  size = 38,
  tap = 44,
  iconSize,
  active = false,
  badge,
  children,
}: {
  palette: JewelPalette;
  icon?: string;
  label: string;
  onClick?: () => void;
  /** Diamètre du disque (38 barres, 40 en-tête). */
  size?: number;
  /** Zone cliquable (≥ 44 px). */
  tap?: number;
  iconSize?: number;
  active?: boolean;
  /** Pastille en haut à droite (point rouge, « + »…). */
  badge?: React.ReactNode;
  /** Contenu à la place de l'icône (sablier…). */
  children?: React.ReactNode;
}) {
  const glyph = iconSize ?? Math.round(size * 0.52);
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={label}
      title={label}
      aria-pressed={active || undefined}
      className="hps-jewel group relative grid shrink-0 place-items-center"
      style={{ width: tap, height: tap }}
    >
      <span
        className="hps-jewel-disc relative grid place-items-center rounded-full"
        style={{
          width: size,
          height: size,
          background: jewelGradient(palette),
          boxShadow: [
            `inset 0 0 0 ${active ? 2.2 : 1.5}px rgba(255,255,255,${active ? 0.85 : 0.3})`,
            "inset 0 -3px 5px rgba(23,12,8,0.22)",
            "0 0 0 1px rgba(23,12,8,0.12)",
            `0 6px 12px -5px ${palette[1]}${active ? "" : "CC"}`,
          ].join(", "),
        }}
      >
        <span
          aria-hidden="true"
          className="pointer-events-none absolute"
          style={{ left: 5, right: 5, top: 3, height: "45%", borderRadius: "50% 50% 45% 45%", background: "linear-gradient(180deg, rgba(255,255,255,0.55), rgba(255,255,255,0))" }}
        />
        <span className="relative grid place-items-center">{children ?? (icon ? <PawSymbol name={icon} size={glyph} gradient /> : null)}</span>
        {badge ? <span className="absolute -right-1.5 -top-1.5">{badge}</span> : null}
      </span>
    </button>
  );
}

/** Pastille rouge 8 px (« Voir signaux »). */
export function JewelDot() {
  return <span className="block h-[9px] w-[9px] rounded-full" style={{ background: "#E8402C", boxShadow: "0 0 0 1.5px #FFFFFF" }} />;
}

/**
 * Verre des barres (§3.3, `pawSiteGlass` de l'app) : clair = blanc → pêche,
 * sombre = encre chaude ; liseré 1 px, ombre chaude. Les deux barres sont
 * symétriques (même matière, même rayon 25).
 */
export function barGlass(dark: boolean): React.CSSProperties {
  return dark
    ? {
        background: "linear-gradient(180deg, rgba(46,40,38,0.92), rgba(26,23,29,0.90))",
        boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.08), 0 14px 30px -14px rgba(12,6,4,0.7)",
        backdropFilter: "blur(14px)",
        WebkitBackdropFilter: "blur(14px)",
      }
    : {
        background: "linear-gradient(180deg, rgba(255,255,255,0.95), rgba(252,244,240,0.88))",
        boxShadow: "inset 0 0 0 1px rgba(120,40,30,0.08), 0 14px 30px -14px rgba(35,18,12,0.45)",
        backdropFilter: "blur(14px)",
        WebkitBackdropFilter: "blur(14px)",
      };
}

/** Feuille de style des bijoux (survol / appui, 150 ms). */
export const JEWEL_CSS = `.hps-jewel .hps-jewel-disc{transition:transform 150ms ease}.hps-jewel:hover .hps-jewel-disc{transform:translateY(-1px) scale(1.05)}.hps-jewel:active .hps-jewel-disc{transform:scale(.94)}.hps-jewel:focus-visible{outline:none}.hps-jewel:focus-visible .hps-jewel-disc{outline:2.5px solid #FFFFFF;outline-offset:2px}@media (prefers-reduced-motion: reduce){.hps-jewel .hps-jewel-disc{transition:none}}`;
