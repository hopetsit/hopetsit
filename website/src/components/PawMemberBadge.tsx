// v493 — Badge « membre Paw Map proche » : cercle ROSE dégradé + patte BLANCHE,
// réplique web du mini-badge dessiné dans l'app (paw_map_screen._buildPawBadge).
// Utilisé dans les sections PawSpot / Paw Premium pour illustrer l'option
// « voir les membres proches ». Purement décoratif (design-only).
export function PawMemberBadge({ size = 24 }: { size?: number }) {
  const id = "pmb"; // gradient id (un seul usage visuel par page suffit)
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 48 48"
      xmlns="http://www.w3.org/2000/svg"
      className="inline-block shrink-0 align-middle"
      aria-hidden="true"
    >
      <defs>
        <linearGradient id={id} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="#F06AA0" />
          <stop offset="100%" stopColor="#E0568B" />
        </linearGradient>
      </defs>
      <circle cx="24" cy="24" r="22" fill={`url(#${id})`} stroke="#fff" strokeWidth="3" />
      {/* patte blanche : 4 coussinets + paume */}
      <g fill="#fff">
        <ellipse cx="15" cy="22" rx="3.4" ry="4.4" />
        <ellipse cx="21.5" cy="16.5" rx="3.4" ry="4.6" />
        <ellipse cx="28.5" cy="16.5" rx="3.4" ry="4.6" />
        <ellipse cx="35" cy="22" rx="3.4" ry="4.4" />
        <ellipse cx="25" cy="31" rx="9" ry="7" />
      </g>
    </svg>
  );
}
