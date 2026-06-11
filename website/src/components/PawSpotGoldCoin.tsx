// v23.1.362 — l'emoji PawSpot DORÉ officiel (visuel fourni par Daniel) :
// médaille or + patte dorée avec la pointe-pin découpée dans le coussinet.
// SVG inline partagé : composant React (sections marketing) + chaîne brute
// (markers Leaflet de PoiMap).

export const GOLDEN_COIN_SVG = `<svg width="100%" height="100%" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="hpsRing" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#FFE989"/><stop offset="1" stop-color="#D99800"/>
    </linearGradient>
    <linearGradient id="hpsPaw" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#FFE066"/><stop offset="1" stop-color="#E8A00A"/>
    </linearGradient>
  </defs>
  <circle cx="32" cy="32" r="29" fill="url(#hpsRing)"/>
  <circle cx="32" cy="32" r="24.5" fill="#9A6B00" stroke="#FFE989" stroke-opacity="0.7" stroke-width="1.5"/>
  <ellipse cx="20.5" cy="22" rx="4.5" ry="6" fill="url(#hpsPaw)"/>
  <ellipse cx="28.5" cy="17.5" rx="4.75" ry="6.5" fill="url(#hpsPaw)"/>
  <ellipse cx="38" cy="18.5" rx="4.75" ry="6.5" fill="url(#hpsPaw)"/>
  <ellipse cx="45.5" cy="24.5" rx="4.5" ry="5.75" fill="url(#hpsPaw)"/>
  <path d="M20 38c0-9 6-12 12.5-12S45 29 45 38c0 6-5 10.5-12.5 10.5S20 44 20 38Z" fill="url(#hpsPaw)"/>
  <circle cx="32.5" cy="36" r="4.2" fill="#9A6B00"/>
  <path d="M27.8 38.5h9.4L32.5 47Z" fill="#9A6B00"/>
  <circle cx="32.5" cy="36" r="1.8" fill="#FFE066"/>
  <g stroke="#fff" stroke-width="1.6" stroke-linecap="round" opacity="0.95">
    <line x1="46" y1="13" x2="54" y2="13"/><line x1="50" y1="9" x2="50" y2="17"/>
    <line x1="10" y1="49" x2="16" y2="49"/><line x1="13" y1="46" x2="13" y2="52"/>
  </g>
</svg>`;

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
