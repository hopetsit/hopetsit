// v23.1.362 — l'emoji PawSpot DORÉ officiel (visuel fourni par Daniel) :
// médaille or + patte dorée avec la pointe-pin découpée dans le coussinet.
// SVG inline partagé : composant React (sections marketing) + chaîne brute
// (markers Leaflet de PoiMap).
// v23.1.368 — Daniel : "colore mon emoji selon le thème du spot" → la même
// pièce-médaille est DÉCLINABLE dans n'importe quelle couleur de type
// (makeCoinSvg), l'or restant la version des spots golden.

function clamp(v: number): number {
  return Math.max(0, Math.min(255, Math.round(v)));
}
function mix(hex: string, target: number, t: number): string {
  const n = parseInt(hex.replace("#", ""), 16);
  const r = clamp(((n >> 16) & 255) * (1 - t) + target * t);
  const g = clamp(((n >> 8) & 255) * (1 - t) + target * t);
  const b = clamp((n & 255) * (1 - t) + target * t);
  return `#${((r << 16) | (g << 8) | b).toString(16).padStart(6, "0")}`;
}
const lighten = (hex: string, t: number) => mix(hex, 255, t);
const darken = (hex: string, t: number) => mix(hex, 0, t);

/** Pièce-médaille teintée — ids de gradients uniques par couleur. */
export function makeCoinSvg(palette: {
  ringStart: string;
  ringEnd: string;
  inner: string;
  pawStart: string;
  pawEnd: string;
}): string {
  const uid = palette.pawEnd.replace("#", "");
  return `<svg width="100%" height="100%" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="hpsRing${uid}" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${palette.ringStart}"/><stop offset="1" stop-color="${palette.ringEnd}"/>
    </linearGradient>
    <linearGradient id="hpsPaw${uid}" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${palette.pawStart}"/><stop offset="1" stop-color="${palette.pawEnd}"/>
    </linearGradient>
  </defs>
  <circle cx="32" cy="32" r="29" fill="url(#hpsRing${uid})"/>
  <circle cx="32" cy="32" r="24.5" fill="${palette.inner}" stroke="${palette.ringStart}" stroke-opacity="0.7" stroke-width="1.5"/>
  <ellipse cx="20.5" cy="22" rx="4.5" ry="6" fill="url(#hpsPaw${uid})"/>
  <ellipse cx="28.5" cy="17.5" rx="4.75" ry="6.5" fill="url(#hpsPaw${uid})"/>
  <ellipse cx="38" cy="18.5" rx="4.75" ry="6.5" fill="url(#hpsPaw${uid})"/>
  <ellipse cx="45.5" cy="24.5" rx="4.5" ry="5.75" fill="url(#hpsPaw${uid})"/>
  <path d="M20 38c0-9 6-12 12.5-12S45 29 45 38c0 6-5 10.5-12.5 10.5S20 44 20 38Z" fill="url(#hpsPaw${uid})"/>
  <circle cx="32.5" cy="36" r="4.2" fill="${palette.inner}"/>
  <path d="M27.8 38.5h9.4L32.5 47Z" fill="${palette.inner}"/>
  <circle cx="32.5" cy="36" r="1.8" fill="${palette.pawStart}"/>
  <g stroke="#fff" stroke-width="1.6" stroke-linecap="round" opacity="0.95">
    <line x1="46" y1="13" x2="54" y2="13"/><line x1="50" y1="9" x2="50" y2="17"/>
    <line x1="10" y1="49" x2="16" y2="49"/><line x1="13" y1="46" x2="13" y2="52"/>
  </g>
</svg>`;
}

/** Pièce teintée depuis une couleur de TYPE de spot (nuances dérivées). */
export function makeTypeCoinSvg(base: string): string {
  return makeCoinSvg({
    ringStart: lighten(base, 0.55),
    ringEnd: darken(base, 0.1),
    inner: darken(base, 0.38),
    pawStart: lighten(base, 0.45),
    pawEnd: base,
  });
}

// La version OR officielle (spots golden).
export const GOLDEN_COIN_SVG = makeCoinSvg({
  ringStart: "#FFE989",
  ringEnd: "#D99800",
  inner: "#9A6B00",
  pawStart: "#FFE066",
  pawEnd: "#E8A00A",
});

export default function PawSpotGoldCoin({
  size = 48,
  className = "",
}: {
  size?: number;
  className?: string;
}) {
  return (
    <span
      className={`inline-block align-middle ${className}`}
      style={{
        width: size,
        height: size,
        filter: "drop-shadow(0 2px 4px rgba(0,0,0,0.25))",
      }}
      dangerouslySetInnerHTML={{ __html: GOLDEN_COIN_SVG }}
    />
  );
}
