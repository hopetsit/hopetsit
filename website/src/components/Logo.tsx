// Official HoPetSit brand logo — v532 : logo HOPE26, identique à l'icône de
// l'app mobile (frontend/assets/brand/png/logo-mark.png). Servi depuis
// /public/logo.png pour être mis en cache par le CDN. Le SVG historique
// portait l'ANCIEN logo ; la vignette de partage vit désormais dans
// /public/og-image.png (cf. layout.tsx).

// v532b — Daniel : « sur le site aussi change-le et mets-le plus gros ».
// Le fichier /public/logo.png repart du master 1254 px du pack (il était
// re-généré à 512, donc flou sur écran Retina) et les tailles d'affichage
// passent de 36/32 à 52/48 px.
export function Logo({ size = 52 }: { size?: number }) {
  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src="/logo.png"
      alt="HoPetSit logo"
      width={size}
      height={size}
      // v532b — PAS d'arrondi CSS : le logo a déjà sa propre forme arrondie et
      // son halo va jusqu'aux bords de l'image. Un `rounded-[20%]` rognait les
      // coins du halo — le même symptôme que sur l'icône Android.
      className=""
      style={{ width: size, height: size }}
    />
  );
}

export function LogoWithText({ size = 48 }: { size?: number }) {
  return (
    <span className="inline-flex items-center gap-2.5 font-display font-extrabold text-ink">
      <Logo size={size} />
      <span className="text-[23px] tracking-tight">
        Ho<span className="text-owner">Pet</span>Sit
      </span>
    </span>
  );
}
