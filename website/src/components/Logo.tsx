// Official HoPetSit brand logo — v532 : logo HOPE26, identique à l'icône de
// l'app mobile (frontend/assets/brand/png/logo-mark.png). Servi depuis
// /public/logo.png pour être mis en cache par le CDN. Le SVG historique
// portait l'ANCIEN logo ; la vignette de partage vit désormais dans
// /public/og-image.png (cf. layout.tsx).

// v532b — Daniel : « sur le site aussi change-le et mets-le plus gros ».
// Le fichier /public/logo.png repart du master 1254 px du pack (il était
// re-généré à 512, donc flou sur écran Retina) et les tailles d'affichage
// passent de 36/32 à 52/48 px.
export function Logo({ size = 52, className }: { size?: number; className?: string }) {
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
      className={className ?? ""}
      // v575 — quand une taille responsive est passée en classe, pas de style
      // inline (il gagnerait sur la classe et figerait la taille).
      style={className ? undefined : { width: size, height: size }}
    />
  );
}

// v575 — sur un écran de 360 px (la quasi-totalité du trafic de la pub Meta),
// logo + « HoPetSit » + drapeau + « S'inscrire » + menu dépassaient la largeur :
// le drapeau recouvrait la fin du nom de la marque, en haut de la page
// d'atterrissage. Logo 48 → 40 px et nom 23 → 20 px sous md.
export function LogoWithText({ size = 48 }: { size?: number }) {
  return (
    <span className="inline-flex items-center gap-1.5 font-display font-extrabold text-ink md:gap-2.5">
      <Logo size={size} className="h-10 w-10 md:h-12 md:w-12" />
      <span className="text-[18px] tracking-tight md:text-[23px]">
        Ho<span className="text-owner">Pet</span>Sit
      </span>
    </span>
  );
}
