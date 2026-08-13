// Official HoPetSit brand logo — v532 : logo HOPE26, identique à l'icône de
// l'app mobile (frontend/assets/brand/png/logo-mark.png). Servi depuis
// /public/logo.png pour être mis en cache par le CDN. Le SVG historique
// portait l'ANCIEN logo ; la vignette de partage vit désormais dans
// /public/og-image.png (cf. layout.tsx).

export function Logo({ size = 36 }: { size?: number }) {
  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src="/logo.png"
      alt="HoPetSit logo"
      width={size}
      height={size}
      className="rounded-[20%]"
      style={{ width: size, height: size }}
    />
  );
}

export function LogoWithText({ size = 32 }: { size?: number }) {
  return (
    <span className="inline-flex items-center gap-2 font-display font-extrabold text-ink">
      <Logo size={size} />
      <span className="text-[20px] tracking-tight">
        Ho<span className="text-owner">Pet</span>Sit
      </span>
    </span>
  );
}
