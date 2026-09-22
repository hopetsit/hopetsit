// v534 — captures d'écran de l'app, par langue (jeu FR / jeu EN, autres
// langues → EN).
// v562 — captures RÉELLES sans texte incrusté : ce sont les pages du site qui
// les encadrent (PhoneFrame). JPEG 1080 px, qualité 82.
// v580 (22/09/2026) — jeu REFAIT sur simulateur iPhone 17 Pro, position Paris,
// avec l'app à jour : nouveau design, fond à pattes, zéro gris, accents
// français corrigés. Les anciennes (v561, 13/09) montraient l'app d'avant les
// refontes 571→580 ; v573 ne couvrait que la carte.

export type ScreenShot = { src: string; alt: string };

const EN: ScreenShot[] = [
  { src: "/screens/v580/en/01-map.jpg", alt: "PawMap" },
  { src: "/screens/v580/en/02-report.jpg", alt: "Alerts" },
  { src: "/screens/v580/en/00-home.jpg", alt: "Home" },
  { src: "/screens/v580/en/05-profile.jpg", alt: "Profile" },
  { src: "/screens/v580/en/07-shop.jpg", alt: "Shop" },
];

const FR: ScreenShot[] = [
  { src: "/screens/v580/fr/01-carte.jpg", alt: "PawMap" },
  { src: "/screens/v580/fr/02-signaler.jpg", alt: "Alertes" },
  { src: "/screens/v580/fr/00-accueil.jpg", alt: "Accueil" },
  { src: "/screens/v580/fr/05-profil.jpg", alt: "Profil" },
  { src: "/screens/v580/fr/07-boutique.jpg", alt: "Boutique" },
];

/** Jeu complet (5 visuels, une seule carte) pour la langue courante. */
export function screensFor(lang: string): ScreenShot[] {
  return lang === "fr" ? FR : EN;
}

/** Les 4 premiers, pour la bande de la page /download. */
export function screensPreviewFor(lang: string): ScreenShot[] {
  return screensFor(lang).slice(0, 4);
}

/** Capture PawMap mise en avant (Paris en FR, Dallas sinon). */
export function pawmapShotFor(lang: string): string {
  return lang === "fr" ? "/screens/v580/fr/01-carte.jpg" : "/screens/v580/en/01-map.jpg";
}

/** Cadre de téléphone sobre (bord sombre, coins très arrondis, ombre douce). */
export function PhoneFrame({
  src,
  alt,
  className = "",
  priority = false,
}: {
  src: string;
  alt: string;
  className?: string;
  priority?: boolean;
}) {
  return (
    <div className={`rounded-[36px] bg-[#231715] p-[6px] shadow-[0_30px_60px_-28px_rgba(0,0,0,0.45)] ${className}`}>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src={src}
        alt={alt}
        width={1080}
        height={2340}
        loading={priority ? "eager" : "lazy"}
        className="block h-auto w-full rounded-[30px] bg-black"
      />
    </div>
  );
}
