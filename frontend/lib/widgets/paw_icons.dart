// v585 (lot D du chantier du 24/09) — LE jeu d'icônes maison HoPetSit.
//
// NORME_DESIGN.md « Icônes — une seule famille maison » : trait arrondi 2 px,
// coins ronds, grille 24 px, BICOLORE (trait à la couleur du rôle + aplat
// pâle de la même teinte ou blanc), même poids partout. Chaque icône a UN
// sens dans toute l'app et le site (maison = gardien, marcheur = promeneur,
// patte = propriétaire, fusée = PawBoost, couronne = Premium, œil barré =
// mode amis…). Le site reprend les mêmes tracés (`website/src/lib/pawIcons.ts`).
//
// Rendu par `flutter_svg` (`SvgPicture.string`), deux couleurs :
//   · `{c}` = le trait (couleur du rôle, ou blanc sur un fond de rôle) ;
//   · `{f}` = l'aplat (teinte pâle : blanc à 30 % sur un fond de rôle, ou le
//     rôle à 18 % sur fond clair).
// Aucun emoji dans l'interface : cette famille les remplace.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Les icônes de la famille. Les premières sont les plus vues (menu, rail,
/// boutons principaux) ; la liste s'allonge au fil des écrans.
enum PawIcon {
  paw, // propriétaire · animal
  house, // gardien · garde
  walker, // promeneur · promenade
  chat,
  calendar,
  user,
  bell,
  search,
  pin, // lieu / PawMap
  heart,
  star,
  rocket, // PawBoost
  crown, // Paw Premium
  eyeOff, // visible par mes amis seulement
  eye,
  send, // envoyer (avion en papier)
  check,
  plus,
  camera,
  bulb, // une idée
  wrench, // un problème
  wallet,
  card,
  gear,
  help,
  share,
  locate, // ma position
  dog,
  cat,
  lock,
  logout,
  trash,
  pencil,
  arrowRight,
  arrowLeft,
  phone,
  mail,
  filter,
  clock,
  bag, // boutique
  gift,
  globe,
  bolt,
  map,
  sos,
  layers,
  moon,
  route,
  friends,
  shield,
  doc,
  close,
  refresh,
  info,
  coin, // PawPoints / PawSpot
  bone,
  fish,
  home, // accueil (onglet)
  key,
  image,
  play,
  bird,
  rabbit,
  bellOff,
  medal,
  diamond,
  sun,
}

/// Corps SVG (sans la balise `<svg>`) de chaque icône : `{c}` = trait,
/// `{f}` = aplat. Grille 24 × 24, trait 2, extrémités et jointures rondes.
const Map<PawIcon, String> kPawIconBodies = <PawIcon, String>{
  PawIcon.paw:
      '<path fill="{f}" stroke="{c}" d="M12 20.5c-2.9 0-5-1.5-5-3.5 0-1.4 1.1-2.4 2.1-3.4.9-1 1.8-1.9 2.9-1.9s2 .9 2.9 1.9c1 1 2.1 2 2.1 3.4 0 2-2.1 3.5-5 3.5z"/>'
      '<circle cx="6.6" cy="10.5" r="1.8" fill="{c}" stroke="none"/><circle cx="17.4" cy="10.5" r="1.8" fill="{c}" stroke="none"/>'
      '<circle cx="9.5" cy="6" r="1.8" fill="{c}" stroke="none"/><circle cx="14.5" cy="6" r="1.8" fill="{c}" stroke="none"/>',
  PawIcon.house:
      '<path fill="{f}" stroke="{c}" d="M4 11.5 12 4.5l8 7V20a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1z"/>'
      '<path fill="{c}" stroke="none" d="M10 21v-5.5h4V21z"/>',
  PawIcon.walker:
      '<circle cx="13.5" cy="4.5" r="2" fill="{c}" stroke="none"/>'
      '<path fill="none" stroke="{c}" d="M9.5 21l1.5-5.5-2.5-2 1-5.5 3.5-.7 2 3.2 2.5 1M7 12.5l-1.5 3.5M12.5 15.5l2.5 2.2L16 21"/>'
      '<path fill="{f}" stroke="{c}" d="M9.5 8l3.5-.7 2 3.2-2.5 5-2.5-2z"/>',
  PawIcon.chat:
      '<path fill="{f}" stroke="{c}" d="M21 11.5a8 8 0 0 1-11.6 7.1L4 20l1.1-4.4A8 8 0 1 1 21 11.5z"/>'
      '<circle cx="8.5" cy="11.5" r="1.1" fill="{c}" stroke="none"/><circle cx="12" cy="11.5" r="1.1" fill="{c}" stroke="none"/><circle cx="15.5" cy="11.5" r="1.1" fill="{c}" stroke="none"/>',
  PawIcon.calendar:
      '<rect x="4" y="6" width="16" height="15" rx="2.5" fill="{f}" stroke="{c}"/>'
      '<path fill="none" stroke="{c}" d="M4 10.5h16M8 3.5v4M16 3.5v4"/>'
      '<circle cx="8.5" cy="15" r="1.1" fill="{c}" stroke="none"/><circle cx="12" cy="15" r="1.1" fill="{c}" stroke="none"/><circle cx="15.5" cy="15" r="1.1" fill="{c}" stroke="none"/>',
  PawIcon.user:
      '<circle cx="12" cy="8" r="4" fill="{f}" stroke="{c}"/>'
      '<path fill="{f}" stroke="{c}" d="M4.5 20.5a7.5 7.5 0 0 1 15 0z"/>',
  PawIcon.bell:
      '<path fill="{f}" stroke="{c}" d="M6 16.5V11a6 6 0 0 1 12 0v5.5l1.5 2h-15z"/>'
      '<path fill="none" stroke="{c}" d="M10 20.5a2 2 0 0 0 4 0"/>'
      '<circle cx="12" cy="3.5" r="1.2" fill="{c}" stroke="none"/>',
  PawIcon.search:
      '<circle cx="10.5" cy="10.5" r="6.5" fill="{f}" stroke="{c}"/>'
      '<path fill="none" stroke="{c}" d="M15.5 15.5 20.5 20.5"/>',
  PawIcon.pin:
      '<path fill="{f}" stroke="{c}" d="M12 21.5s-7-6.3-7-11.5a7 7 0 0 1 14 0c0 5.2-7 11.5-7 11.5z"/>'
      '<circle cx="12" cy="10" r="2.6" fill="{c}" stroke="none"/>',
  PawIcon.heart:
      '<path fill="{f}" stroke="{c}" d="M12 20.5 4.7 13.3a4.6 4.6 0 0 1 6.5-6.5l.8.8.8-.8a4.6 4.6 0 0 1 6.5 6.5z"/>',
  PawIcon.star:
      '<path fill="{f}" stroke="{c}" d="m12 3.5 2.6 5.4 5.9.8-4.3 4.1 1.1 5.9L12 16.9l-5.3 2.8 1.1-5.9-4.3-4.1 5.9-.8z"/>',
  PawIcon.rocket:
      '<path fill="{f}" stroke="{c}" d="M12 2.5c3 2 4 6 4 10l-1.5 3.5h-5L8 12.5c0-4 1-8 4-10z"/>'
      '<circle cx="12" cy="9.5" r="1.7" fill="{c}" stroke="none"/>'
      '<path fill="{f}" stroke="{c}" d="M8.3 12.5 5.5 15v3.5l3.2-1.8M15.7 12.5 18.5 15v3.5l-3.2-1.8"/>'
      '<path fill="none" stroke="{c}" d="M10.5 16.5 12 21.5l1.5-5"/>',
  PawIcon.crown:
      '<path fill="{f}" stroke="{c}" d="M4 18.5 3 8l5 3.5L12 5l4 6.5L21 8l-1 10.5z"/>'
      '<path fill="none" stroke="{c}" d="M4.5 18.5h15"/>',
  PawIcon.eyeOff:
      '<path fill="{f}" stroke="{c}" d="M3 12s3.5-6 9-6 9 6 9 6-3.5 6-9 6-9-6-9-6z"/>'
      '<circle cx="12" cy="12" r="2.8" fill="{c}" stroke="none"/>'
      '<path fill="none" stroke="{c}" d="M4 20 20 4"/>',
  PawIcon.eye:
      '<path fill="{f}" stroke="{c}" d="M3 12s3.5-6 9-6 9 6 9 6-3.5 6-9 6-9-6-9-6z"/>'
      '<circle cx="12" cy="12" r="2.8" fill="{c}" stroke="none"/>',
  PawIcon.send:
      '<path fill="{f}" stroke="{c}" d="M20.5 3.5 3.5 10.5l7 2.5 2.5 7z"/>'
      '<path fill="none" stroke="{c}" d="M10.5 13 20.5 3.5"/>',
  PawIcon.check:
      '<circle cx="12" cy="12" r="9" fill="{f}" stroke="none"/>'
      '<path fill="none" stroke="{c}" stroke-width="2.4" d="m6.5 12.5 3.5 3.5 7.5-8"/>',
  PawIcon.plus:
      '<circle cx="12" cy="12" r="9" fill="{f}" stroke="none"/>'
      '<path fill="none" stroke="{c}" stroke-width="2.4" d="M12 7v10M7 12h10"/>',
  PawIcon.camera:
      '<path fill="{f}" stroke="{c}" d="M4 8.5h3.2l1.3-2.5h7l1.3 2.5H20a1 1 0 0 1 1 1V19a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V9.5a1 1 0 0 1 1-1z"/>'
      '<circle cx="12" cy="13.5" r="3.2" fill="{c}" stroke="none"/>',
  PawIcon.bulb:
      '<path fill="{f}" stroke="{c}" d="M8.5 15.5a6 6 0 1 1 7 0v2h-7z"/>'
      '<path fill="none" stroke="{c}" d="M9.5 20.5h5M10 15.5l-1-3M14 15.5l1-3"/>',
  PawIcon.wrench:
      '<path fill="{f}" stroke="{c}" d="M14.5 3.5a5 5 0 0 0-4.6 6.9L3.5 16.8l3.7 3.7 6.4-6.4a5 5 0 0 0 6.9-4.6l-2.9 1.4-2.6-2.6 1.4-2.9z"/>',
  PawIcon.wallet:
      '<rect x="3" y="6" width="18" height="14" rx="2.5" fill="{f}" stroke="{c}"/>'
      '<path fill="none" stroke="{c}" d="M3 10h18"/>'
      '<circle cx="16.5" cy="15" r="1.4" fill="{c}" stroke="none"/>',
  PawIcon.card:
      '<rect x="3" y="5.5" width="18" height="13" rx="2.5" fill="{f}" stroke="{c}"/>'
      '<path fill="{c}" stroke="none" d="M3 9h18v2.5H3z"/>'
      '<path fill="none" stroke="{c}" d="M6.5 15h4"/>',
  PawIcon.gear:
      '<path fill="{f}" stroke="{c}" d="M12 3.5l1.7 1.8 2.4-.5.9 2.3 2.3.9-.5 2.4 1.8 1.7-1.8 1.7.5 2.4-2.3.9-.9 2.3-2.4-.5L12 20.5l-1.7-1.8-2.4.5-.9-2.3-2.3-.9.5-2.4L3.5 12l1.8-1.7-.5-2.4 2.3-.9.9-2.3 2.4.5z"/>'
      '<circle cx="12" cy="12" r="2.8" fill="{c}" stroke="none"/>',
  PawIcon.help:
      '<circle cx="12" cy="12" r="9" fill="{f}" stroke="{c}"/>'
      '<path fill="none" stroke="{c}" d="M9.5 9.5a2.5 2.5 0 1 1 3.6 2.2c-.7.4-1.1 1-1.1 1.8"/>'
      '<circle cx="12" cy="17" r="1.2" fill="{c}" stroke="none"/>',
  PawIcon.share:
      '<circle cx="6" cy="12" r="2.5" fill="{f}" stroke="{c}"/><circle cx="17" cy="6" r="2.5" fill="{f}" stroke="{c}"/><circle cx="17" cy="18" r="2.5" fill="{f}" stroke="{c}"/>'
      '<path fill="none" stroke="{c}" d="M8.2 10.8 14.8 7.2M8.2 13.2l6.6 3.6"/>',
  PawIcon.locate:
      '<circle cx="12" cy="12" r="6" fill="{f}" stroke="{c}"/>'
      '<circle cx="12" cy="12" r="2.2" fill="{c}" stroke="none"/>'
      '<path fill="none" stroke="{c}" d="M12 3v3M12 18v3M3 12h3M18 12h3"/>',
  PawIcon.dog:
      '<path fill="{f}" stroke="{c}" d="M7 9.5 5.5 5.5 9 7h6l3.5-1.5L17 9.5v4a5 5 0 0 1-10 0z"/>'
      '<circle cx="9.8" cy="11.8" r="1.1" fill="{c}" stroke="none"/><circle cx="14.2" cy="11.8" r="1.1" fill="{c}" stroke="none"/>'
      '<ellipse cx="12" cy="14.8" rx="1.6" ry="1.2" fill="{c}" stroke="none"/>',
  PawIcon.cat:
      '<path fill="{f}" stroke="{c}" d="M6 10 5 4.5l4 2.5h6l4-2.5-1 5.5a6 6 0 0 1-12 0z"/>'
      '<circle cx="9.8" cy="11.5" r="1.1" fill="{c}" stroke="none"/><circle cx="14.2" cy="11.5" r="1.1" fill="{c}" stroke="none"/>'
      '<path fill="none" stroke="{c}" d="M4.5 14h3M16.5 14h3M12 13.5v1.5"/>',
  PawIcon.lock:
      '<rect x="5" y="10.5" width="14" height="10.5" rx="2.5" fill="{f}" stroke="{c}"/>'
      '<path fill="none" stroke="{c}" d="M8 10.5V7.5a4 4 0 0 1 8 0v3"/>'
      '<circle cx="12" cy="15.5" r="1.5" fill="{c}" stroke="none"/>',
  PawIcon.logout:
      '<path fill="{f}" stroke="{c}" d="M10 4.5H6a1.5 1.5 0 0 0-1.5 1.5v12A1.5 1.5 0 0 0 6 19.5h4"/>'
      '<path fill="none" stroke="{c}" d="M9.5 12h10M16 8.5l3.5 3.5-3.5 3.5"/>',
  PawIcon.trash:
      '<path fill="{f}" stroke="{c}" d="M6 7.5h12l-1 12.5a1 1 0 0 1-1 1H8a1 1 0 0 1-1-1z"/>'
      '<path fill="none" stroke="{c}" d="M4 7.5h16M9.5 4.5h5M10 11v6M14 11v6"/>',
  PawIcon.pencil:
      '<path fill="{f}" stroke="{c}" d="M4 20l1-4.5L16.5 4a1.7 1.7 0 0 1 2.5 0l1 1a1.7 1.7 0 0 1 0 2.5L8.5 19z"/>'
      '<path fill="none" stroke="{c}" d="M14.5 6l3.5 3.5"/>',
  PawIcon.arrowRight:
      '<path fill="none" stroke="{c}" stroke-width="2.4" d="M4.5 12h15M13.5 6l6 6-6 6"/>',
  PawIcon.arrowLeft:
      '<path fill="none" stroke="{c}" stroke-width="2.4" d="M19.5 12h-15M10.5 6l-6 6 6 6"/>',
  PawIcon.phone:
      '<path fill="{f}" stroke="{c}" d="M6.5 3.5h3l1.5 4-2 1.5a11 11 0 0 0 6 6l1.5-2 4 1.5v3a2 2 0 0 1-2 2A15 15 0 0 1 4.5 5.5a2 2 0 0 1 2-2z"/>',
  PawIcon.mail:
      '<rect x="3" y="5.5" width="18" height="13" rx="2.5" fill="{f}" stroke="{c}"/>'
      '<path fill="none" stroke="{c}" d="m3.5 7 8.5 6 8.5-6"/>',
  PawIcon.filter:
      '<path fill="{f}" stroke="{c}" d="M4 5h16l-6 7.5v5l-4 2v-7z"/>',
  PawIcon.clock:
      '<circle cx="12" cy="12" r="9" fill="{f}" stroke="{c}"/>'
      '<path fill="none" stroke="{c}" stroke-width="2.4" d="M12 7v5l3.5 2"/>',
  PawIcon.bag:
      '<path fill="{f}" stroke="{c}" d="M6.5 9h11l-.8 11a1 1 0 0 1-1 1H8.3a1 1 0 0 1-1-1z"/>'
      '<path fill="none" stroke="{c}" d="M9 9V7.5a3 3 0 0 1 6 0V9"/>',
  PawIcon.gift:
      '<rect x="4" y="9" width="16" height="11.5" rx="2" fill="{f}" stroke="{c}"/>'
      '<path fill="none" stroke="{c}" d="M4 12.5h16M12 9v11.5M12 9c-2-.2-4.5-.7-4.5-3a1.8 1.8 0 0 1 3.5-.5c.6 1.2 1 2.5 1 3.5zm0 0c2-.2 4.5-.7 4.5-3a1.8 1.8 0 0 0-3.5-.5c-.6 1.2-1 2.5-1 3.5z"/>',
  PawIcon.globe:
      '<circle cx="12" cy="12" r="9" fill="{f}" stroke="{c}"/>'
      '<path fill="none" stroke="{c}" d="M3 12h18M12 3c3 3 3 15 0 18M12 3c-3 3-3 15 0 18"/>',
  PawIcon.bolt:
      '<path fill="{f}" stroke="{c}" d="M13.5 3 5 13.5h6l-.5 7.5L19 10.5h-6z"/>',
  PawIcon.map:
      '<path fill="{f}" stroke="{c}" d="M3.5 6.5 9 4l6 2.5L20.5 4v13.5L15 20l-6-2.5-5.5 2.5z"/>'
      '<path fill="none" stroke="{c}" d="M9 4v13.5M15 6.5V20"/>',
  PawIcon.sos:
      '<path fill="{f}" stroke="{c}" d="M12 3 21 19.5H3z"/>'
      '<path fill="none" stroke="{c}" stroke-width="2.4" d="M12 9.5v4.5"/>'
      '<circle cx="12" cy="16.8" r="1.2" fill="{c}" stroke="none"/>',
  PawIcon.layers:
      '<path fill="{f}" stroke="{c}" d="m12 3.5 9 4.5-9 4.5-9-4.5z"/>'
      '<path fill="none" stroke="{c}" d="m3 12.5 9 4.5 9-4.5M3 16.5l9 4.5 9-4.5"/>',
  PawIcon.moon:
      '<path fill="{f}" stroke="{c}" d="M20 14.5A8.5 8.5 0 0 1 9.5 4a8.5 8.5 0 1 0 10.5 10.5z"/>'
      '<circle cx="17" cy="6.5" r="1" fill="{c}" stroke="none"/>',
  PawIcon.route:
      '<circle cx="6" cy="18" r="2.5" fill="{f}" stroke="{c}"/>'
      '<path fill="none" stroke="{c}" stroke-dasharray="3 2.6" d="M6 15.5c0-5 3-6 6-6s6-1 6-6"/>'
      '<path fill="{f}" stroke="{c}" d="M18 2.5a3 3 0 0 0-3 3c0 2.2 3 5.5 3 5.5s3-3.3 3-5.5a3 3 0 0 0-3-3z"/>',
  PawIcon.friends:
      '<circle cx="9" cy="8" r="3.2" fill="{f}" stroke="{c}"/>'
      '<path fill="{f}" stroke="{c}" d="M2.5 19c0-3.3 2.9-5.5 6.5-5.5s6.5 2.2 6.5 5.5v1h-13z"/>'
      '<path fill="none" stroke="{c}" d="M15.5 6.8a2.6 2.6 0 0 1 0 5.2M16 13.6c3 .4 5.5 2.3 5.5 5.4V20h-3"/>',
  PawIcon.shield:
      '<path fill="{f}" stroke="{c}" d="M12 3 5 5.5v6c0 4.5 3 8 7 9.5 4-1.5 7-5 7-9.5v-6z"/>'
      '<path fill="none" stroke="{c}" stroke-width="2.4" d="m9 12 2.2 2.2L15.5 10"/>',
  PawIcon.doc:
      '<path fill="{f}" stroke="{c}" d="M6 3.5h8l4 4V20.5H6z"/>'
      '<path fill="none" stroke="{c}" d="M14 3.5v4h4M9 12h6M9 15.5h6"/>',
  PawIcon.close:
      '<circle cx="12" cy="12" r="9" fill="{f}" stroke="none"/>'
      '<path fill="none" stroke="{c}" stroke-width="2.4" d="m8 8 8 8M16 8l-8 8"/>',
  PawIcon.refresh:
      '<path fill="none" stroke="{c}" d="M4.5 12a7.5 7.5 0 0 1 13-5.2L20 9"/>'
      '<path fill="none" stroke="{c}" d="M19.5 12a7.5 7.5 0 0 1-13 5.2L4 15"/>'
      '<path fill="{c}" stroke="none" d="M20 4v5h-5zM4 20v-5h5z"/>',
  PawIcon.info:
      '<circle cx="12" cy="12" r="9" fill="{f}" stroke="{c}"/>'
      '<path fill="none" stroke="{c}" stroke-width="2.4" d="M12 11v6"/>'
      '<circle cx="12" cy="7.5" r="1.3" fill="{c}" stroke="none"/>',
  PawIcon.coin:
      '<circle cx="12" cy="12" r="8.5" fill="{f}" stroke="{c}"/>'
      '<path fill="{c}" stroke="none" d="M12 15.8c-1.6 0-2.8-.9-2.8-2 0-.8.6-1.4 1.2-2 .5-.6 1-1.1 1.6-1.1s1.1.5 1.6 1.1c.6.6 1.2 1.2 1.2 2 0 1.1-1.2 2-2.8 2zM8.9 9.9a1 1 0 1 0 2 0 1 1 0 0 0-2 0zM13.1 9.9a1 1 0 1 0 2 0 1 1 0 0 0-2 0z"/>',
  PawIcon.bone:
      '<circle cx="6" cy="9.6" r="2.4" fill="{c}" stroke="none"/><circle cx="6" cy="14.4" r="2.4" fill="{c}" stroke="none"/>'
      '<circle cx="18" cy="9.6" r="2.4" fill="{c}" stroke="none"/><circle cx="18" cy="14.4" r="2.4" fill="{c}" stroke="none"/>'
      '<rect x="7.5" y="9.7" width="9" height="4.6" rx="2" fill="{f}" stroke="{c}"/>',
  PawIcon.fish:
      '<path fill="{f}" stroke="{c}" d="M3.5 12c2.5-3.5 6-5.5 9-5.5s5.5 2 8 5.5c-2.5 3.5-5 5.5-8 5.5s-6.5-2-9-5.5z"/>'
      '<path fill="none" stroke="{c}" d="M16.5 8.5 20.5 6v12l-4-2.5"/>'
      '<circle cx="8" cy="11" r="1.2" fill="{c}" stroke="none"/>',
  PawIcon.home:
      '<path fill="{f}" stroke="{c}" d="M4 11.5 12 4.5l8 7V20a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1z"/>'
      '<circle cx="12" cy="14.5" r="1.8" fill="{c}" stroke="none"/>',
  PawIcon.key:
      '<circle cx="8" cy="14" r="4.5" fill="{f}" stroke="{c}"/>'
      '<circle cx="8" cy="14" r="1.4" fill="{c}" stroke="none"/>'
      '<path fill="none" stroke="{c}" d="m11.5 10.5 8-8M17 5l2.5 2.5M14.5 7.5 17 10"/>',
  PawIcon.image:
      '<rect x="3.5" y="5" width="17" height="14" rx="2.5" fill="{f}" stroke="{c}"/>'
      '<path fill="{c}" stroke="none" d="m5.5 18 4.5-5.5 3 3.5 2-2 4 4z"/>'
      '<circle cx="15.5" cy="9.5" r="1.6" fill="{c}" stroke="none"/>',
  PawIcon.bird:
      '<path fill="{f}" stroke="{c}" d="M4 13.5c2-5 6-7 9.5-7a4 4 0 0 1 4 4v.5l3 1-3 1.5c-.5 4-4 6.5-8.5 6.5H6z"/>'
      '<circle cx="14.5" cy="10" r="1.1" fill="{c}" stroke="none"/>'
      '<path fill="none" stroke="{c}" d="M8 20v1.5M11 20v1.5"/>',
  PawIcon.rabbit:
      '<path fill="{f}" stroke="{c}" d="M8.5 3.5c1.5 0 2.5 3 2.5 6h2c0-3 1-6 2.5-6s1.5 4 .5 7.2A5.5 5.5 0 1 1 8 10.7c-1-3.2-1-7.2.5-7.2z"/>'
      '<circle cx="10.2" cy="14.5" r="1" fill="{c}" stroke="none"/><circle cx="13.8" cy="14.5" r="1" fill="{c}" stroke="none"/>'
      '<ellipse cx="12" cy="17" rx="1.3" ry=".9" fill="{c}" stroke="none"/>',
  PawIcon.bellOff:
      '<path fill="{f}" stroke="{c}" d="M6 16.5V11a6 6 0 0 1 12 0v5.5l1.5 2h-15z"/>'
      '<path fill="none" stroke="{c}" d="M10 20.5a2 2 0 0 0 4 0M4 20 20 4"/>',
  PawIcon.medal:
      '<path fill="{f}" stroke="{c}" d="M7 3.5h10l-2 6H9z"/>'
      '<circle cx="12" cy="15" r="5.5" fill="{f}" stroke="{c}"/>'
      '<path fill="{c}" stroke="none" d="m12 11.8.9 1.9 2.1.3-1.5 1.5.4 2.1-1.9-1-1.9 1 .4-2.1-1.5-1.5 2.1-.3z"/>',
  PawIcon.diamond:
      '<path fill="{f}" stroke="{c}" d="M7 4.5h10l4 5-9 11-9-11z"/>'
      '<path fill="none" stroke="{c}" d="M3 9.5h18M9.5 9.5 12 20.5l2.5-11M9.5 9.5 12 4.5l2.5 5"/>',
  PawIcon.sun:
      '<circle cx="12" cy="12" r="4.5" fill="{f}" stroke="{c}"/>'
      '<path fill="none" stroke="{c}" d="M12 2.5v2.5M12 19v2.5M2.5 12H5M19 12h2.5M5.3 5.3l1.8 1.8M16.9 16.9l1.8 1.8M5.3 18.7l1.8-1.8M16.9 7.1l1.8-1.8"/>',
  PawIcon.play:
      '<circle cx="12" cy="12" r="9" fill="{f}" stroke="{c}"/>'
      '<path fill="{c}" stroke="none" d="M10 8.5v7l5.5-3.5z"/>',
};

/// Le SVG complet d'une icône, prêt pour `SvgPicture.string`.
String pawIconSvg(PawIcon icon, {required Color color, Color? fill}) {
  final String c = _hex(color);
  final String f = _hex(fill ?? color.withValues(alpha: 0.18));
  final String body = (kPawIconBodies[icon] ?? '')
      .replaceAll('{c}', c)
      .replaceAll('{f}', f);
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
      'fill="none" stroke-width="2" stroke-linecap="round" '
      'stroke-linejoin="round">$body</svg>';
}

String _hex(Color c) {
  final int a = (c.a * 255).round();
  final int r = (c.r * 255).round();
  final int g = (c.g * 255).round();
  final int b = (c.b * 255).round();
  if (a >= 255) {
    return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
  }
  return 'rgba($r,$g,$b,${(a / 255).toStringAsFixed(3)})';
}

/// Une icône de la famille, bicolore.
///
/// ```dart
/// PawIconWidget(PawIcon.house, color: role)              // trait rôle, aplat rôle 18 %
/// PawIconWidget(PawIcon.house, color: Colors.white,      // sur un fond de rôle
///     fill: Colors.white.withValues(alpha: .3))
/// ```
class PawIconWidget extends StatelessWidget {
  const PawIconWidget(
    this.icon, {
    super.key,
    this.size = 24,
    required this.color,
    this.fill,
    this.semanticLabel,
  });

  final PawIcon icon;
  final double size;
  final Color color;
  final Color? fill;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      pawIconSvg(icon, color: color, fill: fill),
      width: size,
      height: size,
      semanticsLabel: semanticLabel,
    );
  }
}

/// Icône d'espèce d'un animal (chien / chat / oiseau / lapin, sinon patte),
/// depuis `PetModel.category` (« Dog », « chat », « bird »…).
PawIcon petSpeciesPawIcon(String? category) {
  final String c = (category ?? '').trim().toLowerCase();
  if (c.contains('dog') || c.contains('chien') || c.contains('perro') ||
      c.contains('hund') || c.contains('cane') || c.contains('cão') ||
      c.contains('pies') || c.contains('개') || c.contains('犬')) {
    return PawIcon.dog;
  }
  if (c.contains('cat') || c.contains('chat') || c.contains('gato') ||
      c.contains('katze') || c.contains('gatto') || c.contains('kot') ||
      c.contains('고양이') || c.contains('猫')) {
    return PawIcon.cat;
  }
  if (c.contains('bird') || c.contains('oiseau') || c.contains('pájaro') ||
      c.contains('vogel') || c.contains('uccello') || c.contains('pássaro') ||
      c.contains('ptak') || c.contains('새') || c.contains('鳥')) {
    return PawIcon.bird;
  }
  if (c.contains('rabbit') || c.contains('lapin') || c.contains('conejo') ||
      c.contains('kaninchen') || c.contains('coniglio') || c.contains('coelho') ||
      c.contains('królik') || c.contains('토끼') || c.contains('ウサギ') ||
      c.contains('small') || c.contains('rongeur') || c.contains('petit')) {
    return PawIcon.rabbit;
  }
  return PawIcon.paw;
}

/// Icône « rôle » (patte / maison / marcheur), UN sens dans toute l'app.
PawIcon pawIconForRole(String? role) {
  switch ((role ?? '').toLowerCase()) {
    case 'sitter':
      return PawIcon.house;
    case 'walker':
      return PawIcon.walker;
    default:
      return PawIcon.paw;
  }
}
