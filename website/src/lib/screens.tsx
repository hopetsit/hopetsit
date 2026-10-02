// v534 — captures d'écran de l'app, par langue (jeu FR / jeu EN, autres
// langues → EN).
// v562 — captures RÉELLES sans texte incrusté : ce sont les pages du site qui
// les encadrent (PhoneFrame). JPEG 1080 px, qualité 82.
// v580 (22/09/2026) — jeu REFAIT sur simulateur iPhone 17 Pro, position Paris,
// avec l'app à jour : nouveau design, fond à pattes, zéro gris, accents
// français corrigés. Les anciennes (v561, 13/09) montraient l'app d'avant les
// refontes 571→580 ; v573 ne couvrait que la carte.
// v589 (26/09/2026) — 01-carte / 01-map REFAITES sur iPhone 17e (build 588) :
// nouvelle PawMap (languette Options, pilule Direct, capsule droite, membres
// avec photo), Paris, 9:41, mêmes noms et dimensions (1080×2348, q82).

export type ScreenShot = { src: string; alt: string; w?: number; h?: number };
// 02/10/2026 (609, LEO) — captures 609 de PAM (webp 768 × 1669) là où elles
// existent sans montrer de vrai membre identifiable (règle de BOB) : la carte
// (une seule membre, prénom seul), l'accueil gardien « Ramène tes clients »,
// la collection PawPoints. Le héro de la carte est la capture FR pour toutes
// les langues : les 3 variantes EN montrent plusieurs vrais membres nommés.
const W609 = 768;
const H609 = 1669;

const EN: ScreenShot[] = [
  { src: "/screens/v609/fr/01-carte.webp", alt: "PawMap", w: W609, h: H609 },
  { src: "/screens/v580/en/02-report.jpg", alt: "Alerts" },
  { src: "/screens/v609/en/00-sitter-home.webp", alt: "Sitter home", w: W609, h: H609 },
  { src: "/screens/v609/en/05-pawpoints.webp", alt: "PawPoints", w: W609, h: H609 },
  { src: "/screens/v580/en/07-shop.jpg", alt: "Shop" },
];

const FR: ScreenShot[] = [
  { src: "/screens/v609/fr/01-carte.webp", alt: "PawMap", w: W609, h: H609 },
  { src: "/screens/v580/fr/02-signaler.jpg", alt: "Alertes" },
  { src: "/screens/v609/fr/00-accueil-gardien.webp", alt: "Accueil gardien", w: W609, h: H609 },
  { src: "/screens/v609/fr/05-pawpoints.webp", alt: "PawPoints", w: W609, h: H609 },
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
export function pawmapShotFor(_lang: string): string {
  return "/screens/v609/fr/01-carte.webp";
}

/** Cadre de téléphone sobre (bord sombre, coins très arrondis, ombre douce). */
export function PhoneFrame({
  src,
  alt,
  className = "",
  priority = false,
  w = 1080,
  h = 2340,
}: {
  src: string;
  alt: string;
  className?: string;
  priority?: boolean;
  /** Dimensions réelles du fichier (réserve la place : aucun saut de mise en page). */
  w?: number;
  h?: number;
}) {
  return (
    <div className={`rounded-[36px] bg-[#231715] p-[6px] shadow-[0_30px_60px_-28px_rgba(35,23,21,0.45)] ${className}`}>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src={src}
        alt={alt}
        width={w}
        height={h}
        loading={priority ? "eager" : "lazy"}
        decoding="async"
        {...(priority ? { fetchPriority: "high" as const } : {})}
        className="block h-auto w-full rounded-[30px] bg-black"
      />
    </div>
  );
}
