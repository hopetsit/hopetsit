// v534 — captures d'écran de l'app, par langue.
//
// Daniel : « mets les screenshots EN et FR sur le web ». Jusqu'ici la page
// d'accueil et la page /download affichaient en dur les visuels ANGLAIS
// (suffixe `_us`), y compris quand le site était consulté en français.
//
// Les visuels sont fournis en deux jeux complets (textes intégrés à l'image),
// donc on choisit le jeu selon la langue courante. Toute langue autre que le
// français retombe sur l'anglais : c'est la seule autre version disponible,
// et un visuel anglais reste lisible pour un lecteur espagnol ou allemand,
// alors qu'un visuel français ne le serait pas.
//
// Les fichiers sont des JPEG (qualité 82) : les PNG d'origine pesaient 13 Mo
// au total, ce qui aurait plombé le chargement de la page d'accueil.

export type ScreenShot = { src: string; alt: string };

const EN: ScreenShot[] = [
  { src: "/screens/v534/en/01-map.jpg", alt: "PawMap" },
  { src: "/screens/v534/en/02-report.jpg", alt: "Alerts" },
  { src: "/screens/v534/en/03-friends.jpg", alt: "Friends" },
  { src: "/screens/v534/en/04-bookings.jpg", alt: "Bookings" },
  { src: "/screens/v534/en/05-profile.jpg", alt: "Profile" },
  { src: "/screens/v534/en/06-premium.jpg", alt: "Premium" },
];

const FR: ScreenShot[] = [
  { src: "/screens/v534/fr/01-carte.jpg", alt: "PawMap" },
  { src: "/screens/v534/fr/02-signaler.jpg", alt: "Alertes" },
  { src: "/screens/v534/fr/03-amis.jpg", alt: "Amis" },
  { src: "/screens/v534/fr/04-reservations.jpg", alt: "Réservations" },
  { src: "/screens/v534/fr/05-profil.jpg", alt: "Profil" },
  { src: "/screens/v534/fr/06-premium.jpg", alt: "Premium" },
];

/** Jeu complet (6 visuels) pour la langue courante. */
export function screensFor(lang: string): ScreenShot[] {
  return lang === "fr" ? FR : EN;
}

/** Les 4 premiers, pour la bande de la page /download. */
export function screensPreviewFor(lang: string): ScreenShot[] {
  return screensFor(lang).slice(0, 4);
}
