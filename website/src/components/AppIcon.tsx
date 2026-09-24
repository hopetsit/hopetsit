// 24/09/2026 — LOT B : UNE SEULE famille d'icônes pour le site (norme
// NORME_DESIGN.md : trait arrondi 2 px, grille 24, bicolore couleur du rôle +
// teinte pâle, ZÉRO emoji dans l'interface). Chaque icône a UN sens partout :
// patte = propriétaire, maison = gardien, marcheur = promeneur, fusée =
// PawBoost, couronne = Premium, œil barré = mode amis…

import type { CSSProperties } from "react";

export type AppIconName =
  | "paw" | "home" | "walker" | "calendar" | "chat" | "map" | "profile" | "pets"
  | "search" | "settings" | "friends" | "family" | "shop" | "ticket" | "invoice"
  | "coins" | "megaphone" | "bell" | "rocket" | "crown" | "eye-off" | "people"
  | "pin" | "star" | "shield-check" | "wallet" | "arrow-right" | "question"
  | "moon" | "sun" | "locate" | "logout" | "check" | "lock" | "globe" | "clock"
  | "phone" | "download" | "layers" | "route" | "play";

const PATHS: Record<AppIconName, string> = {
  paw: "M12 12.6c-2.6 0-4.8 2-4.8 4.1 0 1.3 1 2.3 2.3 2.3.9 0 1.6-.4 2.5-.4s1.6.4 2.5.4c1.3 0 2.3-1 2.3-2.3 0-2.1-2.2-4.1-4.8-4.1zM6.2 8.4a1.8 2.3 0 1 0 0 4.6 1.8 2.3 0 1 0 0-4.6zM17.8 8.4a1.8 2.3 0 1 0 0 4.6 1.8 2.3 0 1 0 0-4.6zM9.6 4.8a1.8 2.4 0 1 0 0 4.8 1.8 2.4 0 1 0 0-4.8zM14.4 4.8a1.8 2.4 0 1 0 0 4.8 1.8 2.4 0 1 0 0-4.8z",
  home: "M3.5 11 12 4l8.5 7M5.5 9.8V20h4.8v-5.4h3.4V20h4.8V9.8",
  walker: "M13.3 5.1a1.6 1.6 0 1 0 0-3.2 1.6 1.6 0 0 0 0 3.2zM9.5 21.5l1.7-7 2.3 2.2v4.8M7.2 12.6V8.9l3.6-1.4c.8-.3 1.6 0 2 .7l1.1 1.8c.6 1 1.7 1.6 2.9 1.6M11.2 7.5l-1.6 8.3-3.4-.7",
  calendar: "M4.5 6.5h15v14h-15zM4.5 10.5h15M8 3.5v4M16 3.5v4M8 14h2M14 14h2M8 17.5h2",
  chat: "M12 3.5c-4.7 0-8.5 3.1-8.5 7 0 1.9.9 3.6 2.4 4.9L5 20.5l4.3-1.8c.9.2 1.8.3 2.7.3 4.7 0 8.5-3.1 8.5-7s-3.8-7-8.5-7zM8.8 10.5h.01M12 10.5h.01M15.2 10.5h.01",
  map: "M3.5 6.5v14l5.5-2.5 6 2.5 5.5-2.5v-14L15 6.5 9 4zM9 4v14M15 6.5v14",
  profile: "M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4.5 20.5c0-3.6 3.4-6 7.5-6s7.5 2.4 7.5 6",
  pets: "M12 13c-2.3 0-4.2 1.7-4.2 3.6 0 1.1.9 2 2 2 .8 0 1.4-.4 2.2-.4s1.4.4 2.2.4c1.1 0 2-.9 2-2 0-1.9-1.9-3.6-4.2-3.6zM6.8 9.5a1.5 2 0 1 0 0 4 1.5 2 0 1 0 0-4zM17.2 9.5a1.5 2 0 1 0 0 4 1.5 2 0 1 0 0-4zM9.8 6.3a1.5 2 0 1 0 0 4 1.5 2 0 1 0 0-4zM14.2 6.3a1.5 2 0 1 0 0 4 1.5 2 0 1 0 0-4zM3.5 4h17",
  search: "M10.5 17.5a7 7 0 1 0 0-14 7 7 0 0 0 0 14zM20.5 20.5l-4.9-4.9",
  settings: "M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z",
  friends: "M9 11a3.2 3.2 0 1 0 0-6.4A3.2 3.2 0 0 0 9 11zM2.5 19.5c0-3 2.9-5 6.5-5s6.5 2 6.5 5M16.5 10.5a2.6 2.6 0 1 0 0-5.2 2.6 2.6 0 0 0 0 5.2zM17.5 14.6c2.3.3 4 1.9 4 4.4",
  family: "M8 9.5a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM16 9.5a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM12 19a2.4 2.4 0 1 0 0-4.8 2.4 2.4 0 0 0 0 4.8zM2.5 16c0-2.6 2.5-4.3 5.5-4.3M21.5 16c0-2.6-2.5-4.3-5.5-4.3M9.5 21.5c.4-1.2 1.4-1.7 2.5-1.7s2.1.5 2.5 1.7",
  shop: "M5 8.5h14l-1 12H6zM8.5 8.5V6.5a3.5 3.5 0 0 1 7 0v2M9 12h.01M15 12h.01",
  ticket: "M3.5 9V6.5h17V9a2 2 0 0 0 0 4v2.5h-17V13a2 2 0 0 0 0-4zM9.5 6.5v9M9.5 10.5h.01M9.5 12.5h.01",
  invoice: "M6 3.5h9l4 4v13H6zM15 3.5v4h4M9 12h6M9 15.5h6M9 8.5h2",
  coins: "M9 9.5a6 3 0 1 0 12 0 6 3 0 1 0-12 0zM9 9.5v4c0 1.7 2.7 3 6 3s6-1.3 6-3v-4M3 13a6 3 0 0 0 6 3M3 13v4c0 1.7 2.7 3 6 3 1.2 0 2.3-.2 3.2-.5M3 13c0-1.2 1.3-2.2 3.2-2.7",
  megaphone: "M3.5 10v4h3l7 4V6l-7 4zM17 9a4 4 0 0 1 0 6M19.5 7a7.5 7.5 0 0 1 0 10",
  bell: "M6.5 16.5v-6a5.5 5.5 0 0 1 11 0v6l1.5 2h-14zM10 20.5a2 2 0 0 0 4 0M12 3v2",
  rocket: "M14.5 3c3 0 5.7 1.4 6.4 3.6-3 5.8-6.2 8.8-9 10.3l-3.8-3.8C10.3 11.1 11.5 6.3 14.5 3zM8.1 13.1 4.5 11.6c.9-2 2.2-3.5 3.8-4.6M10.9 15.9l1.5 3.6c2-.9 3.5-2.2 4.6-3.8M4.5 19.5c1-2.4 2-3.2 3.3-3.3.1 1.3-.8 2.3-3.3 3.3zM15.5 8.5h.01",
  crown: "M3.5 8.5l4.5 4L12 5.5l4 7 4.5-4-1.5 10h-14zM5.5 19.5h13",
  "eye-off": "M3 3l18 18M10.6 5.3c.5-.1.9-.1 1.4-.1 5 0 8.6 4.2 9.6 6.8-.4 1-1.2 2.3-2.4 3.5M6.6 6.6C4.3 8.1 2.9 10.4 2.4 12c1 2.6 4.6 6.8 9.6 6.8 1.7 0 3.2-.4 4.5-1.1M9.9 9.9a3 3 0 0 0 4.2 4.2",
  people: "M9 10.5a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM2.5 19.5c0-3.2 2.9-5.2 6.5-5.2s6.5 2 6.5 5.2M16.5 10.5a2.6 2.6 0 1 0 0-5.2 2.6 2.6 0 0 0 0 5.2zM17.5 14.5c2.3.4 4 2 4 4.5",
  pin: "M12 21.5s-7-6.6-7-12a7 7 0 0 1 14 0c0 5.4-7 12-7 12zM12 12a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z",
  star: "M12 3.5l2.6 5.4 5.9.8-4.3 4.1 1.1 5.9L12 16.9l-5.3 2.8 1.1-5.9-4.3-4.1 5.9-.8z",
  "shield-check": "M12 3l7.5 3v6c0 4.5-3.2 7.8-7.5 9-4.3-1.2-7.5-4.5-7.5-9V6zM8.8 12.2l2.2 2.2 4.4-4.6",
  wallet: "M3.5 7.5a2 2 0 0 1 2-2h13v3.5M3.5 7.5v11a2 2 0 0 0 2 2h14a1 1 0 0 0 1-1V10a1 1 0 0 0-1-1h-14a2 2 0 0 1-2-1.5zM16 14.5h.01",
  "arrow-right": "M5 12h14M13 6l6 6-6 6",
  question: "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM9.5 9.5a2.5 2.5 0 1 1 3.6 2.2c-.7.4-1.1 1-1.1 1.8v.5M12 17h.01",
  moon: "M20.5 14.5A8.5 8.5 0 0 1 9.5 3.5a8.5 8.5 0 1 0 11 11z",
  sun: "M12 16a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4",
  locate: "M12 15.5a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zM12 4V2M12 22v-2M4 12H2M22 12h-2M12 19a7 7 0 1 0 0-14 7 7 0 0 0 0 14z",
  logout: "M9.5 4H5.5a1 1 0 0 0-1 1v14a1 1 0 0 0 1 1h4M14 16l4-4-4-4M18 12H9.5",
  check: "M5 12.5l4.5 4.5L19 7.5",
  lock: "M6.5 10.5h11v10h-11zM8.5 10.5v-3a3.5 3.5 0 0 1 7 0v3M12 14.5v2",
  globe: "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM3 12h18M12 3c2.5 2.7 3.8 5.7 3.8 9s-1.3 6.3-3.8 9c-2.5-2.7-3.8-5.7-3.8-9S9.5 5.7 12 3z",
  clock: "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 7v5l3.5 2",
  phone: "M6.5 3.5h3l1.5 4-2 1.5a10 10 0 0 0 6 6l1.5-2 4 1.5v3a1.5 1.5 0 0 1-1.5 1.5C10.6 19 5 13.4 5 6.5A1.5 1.5 0 0 1 6.5 5z",
  download: "M12 3.5v11M7.5 10l4.5 4.5 4.5-4.5M4.5 17.5v2a1 1 0 0 0 1 1h13a1 1 0 0 0 1-1v-2",
  layers: "M12 3.5l9 4.5-9 4.5-9-4.5zM3 12.5l9 4.5 9-4.5M3 16.5l9 4.5 9-4.5",
  route: "M6 18a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5zM18 8.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5zM6 13c0-4 3.5-4.5 6-4.5s6-.5 6-4",
  play: "M8 5.5v13l10-6.5z",
};

// Icônes remplies (pas de trait) : la patte et les petites pattes.
const FILLED = new Set<AppIconName>(["paw", "pets", "walker", "star"]);

export function AppIcon({
  name,
  size = 22,
  color = "currentColor",
  className = "",
  style,
  title,
}: {
  name: AppIconName;
  size?: number;
  color?: string;
  className?: string;
  style?: CSSProperties;
  title?: string;
}) {
  const filled = FILLED.has(name);
  return (
    <svg
      viewBox="0 0 24 24"
      width={size}
      height={size}
      className={className}
      style={style}
      fill={filled ? color : "none"}
      stroke={filled ? "none" : color}
      strokeWidth={2}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden={title ? undefined : true}
      role={title ? "img" : undefined}
    >
      {title ? <title>{title}</title> : null}
      <path d={PATHS[name]} />
    </svg>
  );
}

/** Disque bicolore (teinte pâle du rôle + icône à la couleur du rôle). */
export function IconDisc({
  name,
  color,
  bg,
  size = 44,
  iconSize,
  className = "",
}: {
  name: AppIconName;
  color: string;
  bg: string;
  size?: number;
  iconSize?: number;
  className?: string;
}) {
  return (
    <span
      className={`inline-flex shrink-0 items-center justify-center rounded-full ${className}`}
      style={{ width: size, height: size, background: bg }}
    >
      <AppIcon name={name} size={iconSize ?? Math.round(size * 0.5)} color={color} />
    </span>
  );
}

export default AppIcon;
