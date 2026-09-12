// v534 — captures d'écran de l'app, par langue (jeu FR / jeu EN, autres
// langues → EN).
// v562 — captures RÉELLES de la v561 (simulateur, Paris + Dallas) sans texte
// incrusté : ce sont les pages du site qui les encadrent (PhoneFrame). JPEG
// 1080 px, qualité 82.

export type ScreenShot = { src: string; alt: string };

const EN: ScreenShot[] = [
  { src: "/screens/v561/en/01-map.jpg", alt: "PawMap" },
  { src: "/screens/v561/en/02-report.jpg", alt: "Alerts" },
  { src: "/screens/v561/en/00-home.jpg", alt: "Home" },
  { src: "/screens/v561/en/05-profile.jpg", alt: "Profile" },
  { src: "/screens/v561/en/07-shop.jpg", alt: "Shop" },
  { src: "/screens/v561/en/06-premium.jpg", alt: "Premium" },
];

const FR: ScreenShot[] = [
  { src: "/screens/v561/fr/01-carte.jpg", alt: "PawMap" },
  { src: "/screens/v561/fr/02-signaler.jpg", alt: "Alertes" },
  { src: "/screens/v561/fr/00-accueil.jpg", alt: "Accueil" },
  { src: "/screens/v561/fr/05-profil.jpg", alt: "Profil" },
  { src: "/screens/v561/fr/07-boutique.jpg", alt: "Boutique" },
  { src: "/screens/v561/fr/06-premium.jpg", alt: "Premium" },
];

/** Jeu complet (6 visuels) pour la langue courante. */
export function screensFor(lang: string): ScreenShot[] {
  return lang === "fr" ? FR : EN;
}

/** Les 4 premiers, pour la bande de la page /download. */
export function screensPreviewFor(lang: string): ScreenShot[] {
  return screensFor(lang).slice(0, 4);
}

/** Capture PawMap mise en avant (Paris en FR, Dallas sinon). */
export function pawmapShotFor(lang: string): string {
  return lang === "fr" ? "/screens/v561/fr/01-carte.jpg" : "/screens/v561/en/11-map-dallas.jpg";
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
    <div className={`rounded-[36px] bg-[#1D1D1F] p-[6px] shadow-[0_30px_60px_-28px_rgba(0,0,0,0.45)] ${className}`}>
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
