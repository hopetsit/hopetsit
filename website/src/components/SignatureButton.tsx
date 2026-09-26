"use client";

// 25/09/2026 — LOT D : le bouton « signature HoPetSit » du SITE, jumeau du
// kit de l'app (`frontend/lib/widgets/paw_button_kit.dart`, NORME_DESIGN.md,
// validée par Daniel le 23/09) :
//   · principal : dégradé HORIZONTAL du rôle, reflet verre (moitié haute plus
//     claire), disque blanc à gauche avec l'icône à la couleur du rôle, texte
//     blanc, 56 px, coins 18, LE PRIX DANS LE BOUTON (« Réserver Léa · 25 € ») ;
//   · secondaire : fond blanc, contour 1,5 px du rôle, petit disque teinté ;
//   · lien : texte couleur du rôle, sans cadre ;
//   · produit : PawFollow violet, PawBoost turquoise, Premium noir + texte or.
// Signature au toucher : une EMPREINTE DE PATTE s'imprime là où on clique
// (`.hps-pawprint`, globals.css), enfoncement à 0,97. Reflet qui passe toutes
// les 6 s sur les boutons qui rapportent (`earns`). Désactivé = teinte PÂLE
// ET PLEINE du rôle, jamais gris ; chargement = petit rond DANS le bouton,
// libellé conservé. ⛔ Le libellé n'est JAMAIS coupé : il passe sur 2 lignes.
// `prefers-reduced-motion` → tout fixe. Habillage seul : l'action est celle
// passée par la page.

import Link from "next/link";
import { useState, type MouseEvent, type ReactNode } from "react";
import { AppIcon, type AppIconName } from "@/components/AppIcon";

export type SignatureTone = "owner" | "sitter" | "walker" | "follow" | "boost" | "premium" | "danger";
export type SignatureKind = "primary" | "secondary" | "link";

const TONES: Record<SignatureTone, { a: string; b: string; ink: string; pale: string; text?: string }> = {
  owner:   { a: "#C92A12", b: "#9E1F0B", ink: "#8A1D0C", pale: "#FCE4DC" },
  sitter:  { a: "#2F6FD6", b: "#1E4FB0", ink: "#173F8F", pale: "#DDEAFB" },
  walker:  { a: "#2FAE4E", b: "#15803D", ink: "#0F6B33", pale: "#DCEFE3" },
  follow:  { a: "#8F5CF2", b: "#6A2FD6", ink: "#4C1FA3", pale: "#E9DDFB" },
  boost:   { a: "#22C7E3", b: "#0596B5", ink: "#066A80", pale: "#D6F3F9" },
  premium: { a: "#2B2140", b: "#15120D", ink: "#F4C04A", pale: "#3A3050", text: "#F4C04A" },
  danger:  { a: "#E0473A", b: "#B71C1C", ink: "#8E1414", pale: "#FADBD8" },
};

export type SignatureButtonProps = {
  label: string;
  icon?: AppIconName;
  price?: string;
  tone?: SignatureTone;
  kind?: SignatureKind;
  href?: string;
  onClick?: (e: MouseEvent<HTMLElement>) => void | Promise<void>;
  disabled?: boolean;
  disabledReason?: string;
  loading?: boolean;
  earns?: boolean;
  type?: "button" | "submit";
  className?: string;
  children?: ReactNode;
  ariaLabel?: string;
};

type Print = { id: number; x: number; y: number };

export function SignatureButton({
  label, icon, price, tone = "owner", kind = "primary", href, onClick, disabled, disabledReason,
  loading, earns, type = "button", className = "", children, ariaLabel,
}: SignatureButtonProps) {
  const [prints, setPrints] = useState<Print[]>([]);
  const [busy, setBusy] = useState(false);
  const [hint, setHint] = useState<string | null>(null);
  const t = TONES[tone];
  const text = price ? `${label} · ${price}` : label;
  const isBusy = Boolean(loading) || busy;
  const inactive = Boolean(disabled) || isBusy;
  const primary = kind === "primary";

  const handle = async (e: MouseEvent<HTMLElement>) => {
    if (disabled) {
      e.preventDefault();
      if (disabledReason) { setHint(disabledReason); setTimeout(() => setHint(null), 2500); }
      return;
    }
    if (isBusy) { e.preventDefault(); return; }
    const reduce = typeof window !== "undefined" && window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
    if (!reduce) {
      const r = (e.currentTarget as HTMLElement).getBoundingClientRect();
      const id = Date.now() + Math.random();
      setPrints((p) => [...p, { id, x: e.clientX - r.left, y: e.clientY - r.top }]);
      setTimeout(() => setPrints((p) => p.filter((q) => q.id !== id)), 600);
    }
    if (onClick) {
      const res = onClick(e);
      if (res && typeof (res as Promise<void>).then === "function") {
        setBusy(true);
        try { await res; } finally { setBusy(false); }
      }
    }
  };

  const height = kind === "link" ? "min-h-[40px]" : primary ? "min-h-[56px]" : "min-h-[48px]";
  const radius = primary ? "rounded-[18px]" : "rounded-[16px]";
  const style: Record<string, string> = primary
    ? disabled
      ? { background: t.pale, color: t.ink, boxShadow: "none" }
      : { background: `linear-gradient(90deg, ${t.a}, ${t.b})`, color: t.text || "#ffffff", boxShadow: `0 6px 16px -4px ${t.b}66` }
    : kind === "secondary"
      ? disabled
        ? { background: t.pale, color: t.ink, border: `1.5px solid ${t.pale}` }
        : { background: "#ffffff", color: t.ink, border: `1.5px solid ${t.a}` }
      : { background: "transparent", color: t.ink };

  const disc = (icon || isBusy) && kind !== "link" ? (
    <span
      className={`hps-btn-disc grid shrink-0 place-items-center rounded-full ${primary ? "h-[34px] w-[34px]" : "h-7 w-7"}`}
      style={{ background: primary ? "#ffffff" : `${t.a}1f` }}
      aria-hidden="true"
    >
      {isBusy ? (
        <span className="hps-spin block h-4 w-4 rounded-full border-2 border-current border-t-transparent" style={{ color: primary ? (t.text || t.a) : t.ink }} />
      ) : icon ? (
        <AppIcon name={icon} size={primary ? 19 : 16} color={primary ? (t.text && tone === "premium" ? t.ink : t.a) : t.ink} />
      ) : null}
    </span>
  ) : icon && kind === "link" ? (
    <AppIcon name={icon} size={16} color={t.ink} />
  ) : null;

  const inner = (
    <>
      {primary && !disabled && <span className="hps-btn-gloss" aria-hidden="true" />}
      {primary && earns && !disabled && <span className="hps-btn-sheen" aria-hidden="true" />}
      {disc}
      <span className="hps-btn-label relative min-w-0 text-center font-display font-bold leading-[1.15]" style={{ fontSize: primary ? 15 : 14 }}>
        {children ?? text}
      </span>
      {prints.map((p) => (
        <span key={p.id} className="hps-pawprint" style={{ left: p.x, top: p.y, background: primary ? "#ffffff" : t.a }} aria-hidden="true" />
      ))}
      {hint && <span className="hps-btn-hint" role="status">{hint}</span>}
    </>
  );

  const cls = `hps-btn relative inline-flex w-full items-center justify-center gap-2.5 overflow-hidden px-3.5 ${height} ${radius} select-none transition-transform active:scale-[0.97] ${kind === "link" ? "!px-1.5" : ""} ${inactive ? "cursor-default" : "cursor-pointer"} ${className}`;

  if (href && !disabled && !isBusy) {
    return (
      <Link href={href} className={cls} style={style} onClick={handle} aria-label={ariaLabel || text} role="button">
        {inner}
      </Link>
    );
  }
  return (
    <button type={type} className={cls} style={style} onClick={handle} aria-disabled={inactive} aria-label={ariaLabel || text}>
      {inner}
    </button>
  );
}

export default SignatureButton;
