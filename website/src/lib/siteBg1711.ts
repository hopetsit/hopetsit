// 17/11/2026 (LEO, ordre de Daniel transmis par BOB : « améliore la page d'accueil et aussi l'arrière-plan »).
// LA constante qui choisit le fond de tout le site :
//   "a"   = sobre et lumineux : ivoire chaud + deux halos de lumière en haut de page, AUCUN motif derrière le texte ;
//   "b"   = chaleureux, « animal » : pêche + piste de pattes en diagonale, os, balle, poisson, cœurs (ton sur ton) ;
//   "old" = le fond d'avant le 17/11 (pattes et cœurs à 7,5 % sur blanc), pour revenir en arrière.
// RootShell pose la valeur sur <html data-bg="…"> ; tout le reste est dans globals.css (bloc « 17/11 »).
// Pour comparer sans rien republier : ajouter ?bg=a ou ?bg=b à l'adresse de n'importe quelle page (RoleWallpaper).
export type SiteBg1711 = "a" | "b" | "old";
export const SITE_BG_1711: SiteBg1711 = "b"; // 17/11 : choix de Daniel (fond B, chaleureux)
