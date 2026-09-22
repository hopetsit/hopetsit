"use client";

import { useId } from "react";

/**
 * Logo PawMap — « patte-pin » (handoff design de Daniel, 19/09/2026).
 *
 * Un coussinet en forme d'épingle de carte (carré à coins 50% 50% 50% 0 tourné
 * de −45°, dégradé 135° #3B2E2A → #1B1614, bord blanc, ombre portée) qui
 * contient l'ŒIL du logo HoPetSit, surmonté des 4 doigts colorés (billes du
 * logo) posés sur un arc, en symétrie miroir.
 *
 * Géométrie reprise à l'identique du splash de référence
 * (`docs/design_handoff_pawmap_tab_bar/Splash Screen.dc.html`) : coussinet 120
 * ancré bas-centre, œil 80, doigts 34/40/40/34 sur un arc de rayon 92 autour de
 * (105,150), aux angles −58°, −19°, +19°, +58°. Tout est exprimé ici dans un
 * repère centré sur le bulbe du coussinet, puis placé dans un viewBox carré.
 *
 * Les mêmes formes sont dans `public/pawmap_logo.svg` (fichier statique).
 *
 * Usage :
 *   <PawMapLogo size={56} />            → statique
 *   <PawMapLogo size={96} animated />   → les doigts sortent du coussinet au
 *                                          montage (désactivé si l'utilisateur
 *                                          demande moins d'animations).
 */

/** Rayon du bulbe (ligne médiane du trait blanc). */
const RP = 63;
/** Points de tangence des deux arêtes droites de la pointe. */
const TAN = 44.55;
/** Pointe de l'épingle, sous le centre du bulbe. */
const TIP = 89.1;
/** Rayon de l'œil. */
const EYE_R = 40;

/** Les 4 doigts : position (repère du bulbe), rayon, dégradé, nom. */
const TOES = [
  { x: -78.02, y: -37.75, r: 19.5, from: "#FF7A66", to: "#D83C28", key: "red" },
  { x: -29.95, y: -75.99, r: 22.5, from: "#6FA0FF", to: "#2F6FD6", key: "blue" },
  { x: 29.95, y: -75.99, r: 22.5, from: "#7FD66F", to: "#3FA33A", key: "green" },
  { x: 78.02, y: -37.75, r: 19.5, from: "#B57FE6", to: "#7A3FB0", key: "violet" },
] as const;

/** Centre de l'arc : point d'où les doigts jaillissent quand on anime. */
const ARC_CY = 11;

/** Contour de l'épingle : deux arêtes droites vers la pointe + arc de 270°. */
const PAD_PATH = `M${TAN} ${TAN}L0 ${TIP}L${-TAN} ${TAN}A${RP} ${RP} 0 1 1 ${TAN} ${TAN}Z`;

export function PawMapLogo({
  size = 56,
  animated = false,
  className = "",
  title = "PawMap",
}: {
  size?: number;
  animated?: boolean;
  className?: string;
  /** Texte accessible ; `null` rend le logo purement décoratif. */
  title?: string | null;
}) {
  const uid = useId().replace(/:/g, "");
  const id = (name: string) => `pm-${name}-${uid}`;

  // Une image d'animation par doigt : il part du centre du coussinet
  // (translate vers l'arc + scale .25, opacité 0) et rejoint sa place.
  const keyframes = TOES.map(
    (t, i) => `
@keyframes pm-toe-${i}-${uid} {
  from { transform: translate(${(0 - t.x).toFixed(2)}px, ${(ARC_CY - t.y).toFixed(2)}px) scale(.25); opacity: 0; }
  to   { transform: none; opacity: 1; }
}`,
  ).join("");

  const css = `${keyframes}
@media (prefers-reduced-motion: no-preference) {
${TOES.map(
    (_, i) => `  .pm-toe-${i}-${uid} { animation: pm-toe-${i}-${uid} .5s cubic-bezier(.3,1.5,.4,1) ${i * 40}ms both; }`,
  ).join("\n")}
}`;

  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 256 256"
      fill="none"
      className={className}
      role={title ? "img" : undefined}
      aria-label={title ?? undefined}
      aria-hidden={title ? undefined : true}
    >
      {title ? <title>{title}</title> : null}
      {animated ? <style>{css}</style> : null}
      <defs>
        <linearGradient
          id={id("pad")}
          gradientUnits="userSpaceOnUse"
          x1={-RP}
          y1={-RP}
          x2={RP}
          y2={RP}
        >
          <stop offset="0" stopColor="#3B2E2A" />
          <stop offset="1" stopColor="#1B1614" />
        </linearGradient>
        {TOES.map((t) => (
          <radialGradient key={t.key} id={id(t.key)} cx="0.35" cy="0.3" r="0.92">
            <stop offset="0" stopColor={t.from} />
            <stop offset="1" stopColor={t.to} />
          </radialGradient>
        ))}
        <clipPath id={id("eye")}>
          <circle cx="0" cy="0" r={EYE_R} />
        </clipPath>
        <filter id={id("shPad")} x="-40%" y="-40%" width="180%" height="180%">
          <feDropShadow dx="0" dy="7" stdDeviation="6" floodColor="#1B1614" floodOpacity="0.38" />
        </filter>
        <filter id={id("shToe")} x="-60%" y="-60%" width="220%" height="220%">
          <feDropShadow dx="0" dy="3" stdDeviation="2.6" floodColor="#2A0A05" floodOpacity="0.34" />
        </filter>
        <filter id={id("shEye")} x="-40%" y="-40%" width="180%" height="180%">
          <feDropShadow dx="0" dy="2" stdDeviation="2" floodColor="#000000" floodOpacity="0.38" />
        </filter>
      </defs>

      {/* Repère centré sur le bulbe du coussinet. */}
      <g transform="translate(128 131.2) scale(1.08)">
        {/* Les doigts d'abord : le coussinet les recouvre par le bas. */}
        <g filter={`url(#${id("shToe")})`}>
          {TOES.map((t, i) => (
            <g key={t.key} transform={`translate(${t.x} ${t.y})`}>
              <g className={animated ? `pm-toe-${i}-${uid}` : undefined}>
                <circle
                  cx="0"
                  cy="0"
                  r={t.r}
                  fill={`url(#${id(t.key)})`}
                  stroke="#FFFFFF"
                  strokeWidth="5"
                />
              </g>
            </g>
          ))}
        </g>

        {/* Le coussinet (épingle de carte). */}
        <g filter={`url(#${id("shPad")})`}>
          <path
            d={PAD_PATH}
            fill={`url(#${id("pad")})`}
            stroke="#FFFFFF"
            strokeWidth="6"
            strokeLinejoin="miter"
          />
        </g>
        {/* Liseré clair du haut (équivalent du `inset 0 1px 0` de la maquette). */}
        <path
          d="M-48.74 -34.13A59.5 59.5 0 0 1 48.74 -34.13"
          fill="none"
          stroke="#FFFFFF"
          strokeOpacity="0.18"
          strokeWidth="3"
          strokeLinecap="round"
        />

        {/* L'œil du logo HoPetSit, droit, clippé dans son cercle. */}
        <g filter={`url(#${id("shEye")})`}>
          <circle cx="0" cy="0" r={EYE_R} fill="#1B1614" />
          <image
            clipPath={`url(#${id("eye")})`}
            x={-EYE_R}
            y={-EYE_R}
            width={EYE_R * 2}
            height={EYE_R * 2}
            preserveAspectRatio="xMidYMid slice"
            href="/pawmap_eye.png"
          />
        </g>
      </g>
    </svg>
  );
}

export default PawMapLogo;
