// v584 — lot C du chantier du 24/09 : LES ÉPINGLES DE LA PAWMAP.
//
// Source de vérité : ~/hopetsit-social/LEGENDE_PAWMAP.md (validée point par
// point par Daniel le 23/09/2026, partagée avec le site). Une FORME par
// famille, la couleur ne fait que préciser :
//   · rond   = une personne (Moi = ma photo 56 px + « Moi » ; ami = sa photo +
//              anneau rose ; membre = patte / maison / marcheur blanc sur la
//              couleur de son rôle, À TOUS LES ZOOMS) ;
//   · goutte = un lieu (entièrement à la couleur du type, icône blanche) ;
//   · carré  = un groupe de lieux (blanc, bord à la couleur dominante) ;
//   · noir & or = PawSpot (goutte noire liserée d'or ; doré = goutte OR,
//              patte noire ; groupe = carré noir, chiffre or) ;
//   · rond plein = un groupe de membres (couleur du rôle dominant + nombre) ;
//   · bulle orange = une demande de propriétaire (prix dedans, sinon
//              l'icône du service).
// Repères en plus, jamais à la place de la couleur du rôle :
//   · Paw Premium = pastille OR (couronne encre), en haut à droite ;
//   · PawBoost   = lueur TURQUOISE qui respire + petite fusée (jamais l'or) ;
//   · amis        = anneau ROSE, point vert si en ligne ;
//   · mode « amis seulement » (sur MON rond) = anneau POINTILLÉ + œil barré.
//
// v592 (26/09, Daniel : « le vrai HD, les halos jolis comme sur le web, les
// bulles, tout doit être HD, et que tout fonctionne par couleur ») — REFONTE
// À L'IDENTIQUE DU SITE (`website/src/lib/pawmapLegend.ts`, qui dessine les
// épingles de `PoiMap.tsx`) :
//   · mêmes tailles, épaisseurs, positions de pastilles, au pixel CSS près ;
//   · mêmes dessins : les glyphes SVG du site (patte, maison, marcheur,
//     couronne, fusée, coche, œil barré, lieux, éclat) sont TRACÉS en
//     vectoriel ici (mini lecteur de chemins SVG) — plus d'icônes-police ;
//   · halos = vrais dégradés RADIAUX calculés comme un `box-shadow` CSS
//     (courbe de Gauss), qui s'éteignent AVANT le bord du bitmap : plus
//     jamais de lueur coupée net ;
//   · plusieurs rôles = anneaux CONCENTRIQUES (liseré blanc + anneau du rôle),
//     comme le site — plus de secteurs ;
//   · polices du site (Poppins pour les étiquettes et bulles, Inter pour les
//     chiffres) chargées depuis assets/fonts sous des noms PRIVÉS
//     (`PawPinPoppins`, `PawPinInter`) : aucun autre écran n'est touché ;
//   · photos recadrées « cover » (plus de visage écrasé) et lissées en
//     haute qualité ; tout est dessiné à la densité réelle de l'écran
//     (`pawPinRenderScale`, 2×–4×).
//
// Les fonctions de dessin sont PURES (canvas + paramètres) : les tests
// « golden » les rendent sans carte.
//
// Zéro gris (saturation), zéro emoji.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// v584 (25/09) — prénom court sous un rond au zoom rue : le premier mot,
/// 12 caractères au plus (« dadaciao84+testwalker » débordait de l'étiquette
/// sur les captures du parcours), puis « … ». Pure, testée.
String pawMapShortName(String name, {int max = 12}) {
  final first = name.trim().split(RegExp(r'\s+')).first;
  if (first.length <= max) return first;
  return '${first.substring(0, max - 1)}…';
}

/// Couleurs et tailles de la légende (LEGENDE_PAWMAP.md). NE JAMAIS les
/// réutiliser pour autre chose sur la carte.
class PawMapLegend {
  PawMapLegend._();

  static const Color owner = Color(0xFFC92A12);
  static const Color sitter = Color(0xFF2563EB);
  static const Color walker = Color(0xFF16A34A);
  static const Color pawFollow = Color(0xFF7C3AED);
  static const Color boost = Color(0xFF06B6D4);
  static const Color gold = Color(0xFFF4C04A);
  static const Color friend = Color(0xFFF06AA0);
  static const Color ink = Color(0xFF17141F);
  // v592 — même vert que le point « en ligne » du site (#16A34A).
  static const Color online = Color(0xFF16A34A);
  // v592 — point « hors ligne / signal perdu » (site : #C2410C) : l'orange
  // FONCÉ de la marque (Daniel, 26/09 : « l'orange foncé, pas clair »).
  static const Color offline = Color(0xFF9E1F0B);

  // Tailles logiques (px) de la légende.
  // v584 (25/09, Daniel : « mets plus en valeur les utilisateurs et les
  // PawSpots ») : les MEMBRES sont les plus visibles (46-56), les PawSpots
  // ressortent (40 / 44 doré), les lieux ordinaires restent discrets (30).
  static const double meSize = 56;
  static const double friendSize = 50;
  static const double memberSize = 46;
  // v592 — groupe de membres = ROND (site) de 40 / 44 px dans un bitmap 64.
  static const double memberClusterHeight = 52;
  static const double placeSize = 30;
  static const double placeClusterSize = 32; // site : carré blanc 32
  static const double spotSize = 40; // v590 — handoff §6 : goutte 40
  static const double spotGoldSize = 44;
  static const double spotClusterSize = 36; // site : carré noir 36
  // v592 — bulle de demande : 26 px (site) + 18 px réservés au-dessus pour
  // la pastille « Ma demande ».
  static const double requestBubbleHeight = 44;

  static const double crownMember = 20;
  static const double crownFriend = 22;
  static const double crownMe = 24;

  static Color roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'sitter':
        return sitter;
      case 'walker':
        return walker;
      default:
        return owner;
    }
  }

  /// v590 — handoff §4 : dégradé de l'anneau (clair → foncé) par couleur de
  /// rôle ; une autre couleur → sa version éclaircie / assombrie.
  /// Identique à `RING_GRAD` du site.
  static (Color, Color) ringGradient(Color c) {
    if (c == sitter) return (const Color(0xFF4A86F0), const Color(0xFF2458C9));
    if (c == walker) return (const Color(0xFF43B862), const Color(0xFF1F7A37));
    // v592 — Daniel (26/09) : « l'orange foncé, pas clair » → orange de la
    // marque #C92A12 → #9E1F0B (le site avait #FFA94D → #D63D1F).
    if (c == owner) return (const Color(0xFFC92A12), const Color(0xFF9E1F0B));
    if (c == friend) return (const Color(0xFFF47BB2), const Color(0xFFD6377F));
    return (lighten(c, 0.14), darken(c, 0.12));
  }

  /// Foncé du rôle (dégradé des ronds de groupe, `memberClusterHtml` du site).
  static Color roleDark(String role) {
    switch (role.toLowerCase()) {
      case 'sitter':
        return const Color(0xFF1E4FB0);
      case 'walker':
        return const Color(0xFF15803D);
      default:
        return const Color(0xFF9E1F0B);
    }
  }

  /// Icône blanche par rôle (daltoniens, idée 5 validée) : propriétaire =
  /// patte, gardien = maison, promeneur = personnage qui marche.
  static IconData roleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'sitter':
        return Icons.home_rounded;
      case 'walker':
        return Icons.directions_walk_rounded;
      default:
        return Icons.pets_rounded;
    }
  }

  /// Couleur PLEINE d'un type de lieu — v592 : celles du site (`PLACE_COLOR`),
  /// sauf « autre » qui garde le brun chaud de l'app (celui du site est trop
  /// terne : saturation 0,21 < 0,25).
  static Color placeColor(String category) {
    switch (category) {
      case 'vet':
        return const Color(0xFFB42318); // rouge vétérinaire
      case 'park':
        return const Color(0xFF0F766E); // vert d'eau sombre
      case 'water':
        return const Color(0xFF155E75); // bleu pétrole
      case 'shop':
        return const Color(0xFFA16207); // ambre brûlé
      case 'groomer':
        return const Color(0xFFDB2777); // framboise
      case 'beach':
        return const Color(0xFF0E7490); // bleu-vert
      case 'trainer':
        return const Color(0xFF4D7C0F); // olive vif
      case 'hotel':
        return const Color(0xFF3730A3); // indigo
      case 'restaurant':
        return const Color(0xFFC2410C); // orange brûlé
      default:
        return const Color(0xFF6B4F3A); // brun (teinte chaude, jamais gris)
    }
  }

  static IconData placeIcon(String category) {
    switch (category) {
      case 'vet':
        return Icons.medical_services_rounded;
      case 'park':
        return Icons.park_rounded;
      case 'water':
        return Icons.water_drop_rounded;
      case 'shop':
        return Icons.storefront_rounded;
      case 'groomer':
        return Icons.content_cut_rounded;
      case 'beach':
        return Icons.beach_access_rounded;
      case 'trainer':
        return Icons.school_rounded;
      case 'hotel':
        return Icons.hotel_rounded;
      case 'restaurant':
        return Icons.restaurant_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  static IconData spotIcon(String type) {
    switch (type) {
      case 'path_walk':
        return Icons.directions_walk_rounded;
      case 'chill':
        return Icons.self_improvement_rounded;
      case 'playground':
        return Icons.sports_soccer_rounded;
      case 'swimming':
        return Icons.pool_rounded;
      case 'food_cafe':
        return Icons.local_cafe_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  static Color darken(Color c, [double amount = 0.22]) =>
      Color.lerp(c, Colors.black, amount)!;
  static Color lighten(Color c, [double amount = 0.22]) =>
      Color.lerp(c, Colors.white, amount)!;
}

/// Nombre de phases de la respiration PawBoost (4 bitmaps par épingle
/// boostée, mis en cache : la carte ne redessine que ces marqueurs-là).
const int kBoostPhases = 4;

// ── Polices des épingles (v592) ────────────────────────────────────────────
// Les mêmes que le site (Poppins pour les étiquettes et les bulles, Inter
// pour les chiffres), lues dans assets/fonts et enregistrées sous des noms
// PRIVÉS : le reste de l'app n'est pas touché.
const String kPawPinPoppins = 'PawPinPoppins';
const String kPawPinInter = 'PawPinInter';
Future<void>? _pinFontsFuture;

/// Charge (une fois) les polices des épingles. Sans elles (asset absent),
/// le texte retombe sur Roboto / la police système — jamais d'erreur.
Future<void> ensurePawPinFonts() => _pinFontsFuture ??= _loadPinFonts();

Future<void> _loadPinFonts() async {
  Future<void> load(String family, List<String> files) async {
    try {
      final loader = FontLoader(family);
      for (final f in files) {
        loader.addFont(rootBundle.load('assets/fonts/$f.ttf'));
      }
      await loader.load();
    } catch (e) {
      debugPrint('[PawMapPins] police $family indisponible : $e');
    }
  }

  await load(kPawPinPoppins,
      ['Poppins-Medium', 'Poppins-SemiBold', 'Poppins-Bold', 'Poppins-ExtraBold']);
  await load(kPawPinInter,
      ['Inter-Medium', 'Inter-SemiBold', 'Inter-Bold', 'Inter-ExtraBold']);
}

TextStyle _pinStyle(double size, FontWeight weight, Color color,
        {bool inter = false, double? height}) =>
    TextStyle(
      fontFamily: inter ? kPawPinInter : kPawPinPoppins,
      fontFamilyFallback: const ['Roboto'],
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height ?? 1.0,
      letterSpacing: 0,
    );

// ── Mini lecteur de chemins SVG (v592) ─────────────────────────────────────
// Les glyphes sont ceux du site, tracés en VECTORIEL (nets à toute densité).
// Commandes : M L H V C S Q T A Z, absolues et relatives.
class PawSvgPath {
  PawSvgPath._();

  static final Map<String, Path> _cache = {};
  static final RegExp _tok = RegExp(
      r'[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?');
  static final RegExp _isCmd = RegExp(r'^[A-Za-z]$');

  static Path parse(String d) => _cache.putIfAbsent(d, () => _parse(d));

  static Path _parse(String d) {
    final toks = _tok.allMatches(d).map((m) => m.group(0)!).toList();
    final p = Path()..fillType = PathFillType.nonZero;
    var i = 0;
    var cmd = '';
    double x = 0, y = 0, sx = 0, sy = 0;
    double? lcx, lcy; // dernier point de contrôle (S / T)
    String prev = '';
    double n() => double.parse(toks[i++]);
    bool hasNum() => i < toks.length && !_isCmd.hasMatch(toks[i]);
    while (i < toks.length) {
      if (_isCmd.hasMatch(toks[i])) {
        cmd = toks[i++];
      }
      final rel = cmd == cmd.toLowerCase();
      final c = cmd.toUpperCase();
      switch (c) {
        case 'M':
          final nx = n() + (rel ? x : 0), ny = n() + (rel ? y : 0);
          p.moveTo(nx, ny);
          x = sx = nx;
          y = sy = ny;
          cmd = rel ? 'l' : 'L';
          lcx = lcy = null;
          break;
        case 'L':
          x = n() + (rel ? x : 0);
          y = n() + (rel ? y : 0);
          p.lineTo(x, y);
          lcx = lcy = null;
          break;
        case 'H':
          x = n() + (rel ? x : 0);
          p.lineTo(x, y);
          lcx = lcy = null;
          break;
        case 'V':
          y = n() + (rel ? y : 0);
          p.lineTo(x, y);
          lcx = lcy = null;
          break;
        case 'C':
          final x1 = n() + (rel ? x : 0), y1 = n() + (rel ? y : 0);
          final x2 = n() + (rel ? x : 0), y2 = n() + (rel ? y : 0);
          final ex = n() + (rel ? x : 0), ey = n() + (rel ? y : 0);
          p.cubicTo(x1, y1, x2, y2, ex, ey);
          lcx = x2;
          lcy = y2;
          x = ex;
          y = ey;
          break;
        case 'S':
          final rx1 = (prev == 'C' || prev == 'S') && lcx != null ? 2 * x - lcx : x;
          final ry1 = (prev == 'C' || prev == 'S') && lcy != null ? 2 * y - lcy : y;
          final x2 = n() + (rel ? x : 0), y2 = n() + (rel ? y : 0);
          final ex = n() + (rel ? x : 0), ey = n() + (rel ? y : 0);
          p.cubicTo(rx1, ry1, x2, y2, ex, ey);
          lcx = x2;
          lcy = y2;
          x = ex;
          y = ey;
          break;
        case 'Q':
          final x1 = n() + (rel ? x : 0), y1 = n() + (rel ? y : 0);
          final ex = n() + (rel ? x : 0), ey = n() + (rel ? y : 0);
          p.quadraticBezierTo(x1, y1, ex, ey);
          lcx = x1;
          lcy = y1;
          x = ex;
          y = ey;
          break;
        case 'T':
          final qx = (prev == 'Q' || prev == 'T') && lcx != null ? 2 * x - lcx : x;
          final qy = (prev == 'Q' || prev == 'T') && lcy != null ? 2 * y - lcy : y;
          final ex = n() + (rel ? x : 0), ey = n() + (rel ? y : 0);
          p.quadraticBezierTo(qx, qy, ex, ey);
          lcx = qx;
          lcy = qy;
          x = ex;
          y = ey;
          break;
        case 'A':
          final rx = n(), ry = n(), rot = n();
          final large = n() != 0, sweep = n() != 0;
          final ex = n() + (rel ? x : 0), ey = n() + (rel ? y : 0);
          p.arcToPoint(Offset(ex, ey),
              radius: Radius.elliptical(rx, ry),
              rotation: rot,
              largeArc: large,
              clockwise: sweep);
          x = ex;
          y = ey;
          lcx = lcy = null;
          break;
        case 'Z':
          p.close();
          x = sx;
          y = sy;
          lcx = lcy = null;
          break;
        default:
          i++; // commande inconnue : on saute
      }
      prev = c;
      if (c == 'Z' && hasNum()) cmd = 'L';
    }
    return p;
  }
}

/// Glyphes du site (grille 24), `website/src/lib/pawmapLegend.ts`.
class PawGlyphs {
  PawGlyphs._();

  // Patte (propriétaire, PawSpot) : 5 ellipses.
  static Path paw() => _paw ??= Path()
    ..addOval(Rect.fromCenter(center: const Offset(12, 15.6), width: 9.2, height: 7.4))
    ..addOval(Rect.fromCenter(center: const Offset(5.3, 10.9), width: 4, height: 5.2))
    ..addOval(Rect.fromCenter(center: const Offset(9.4, 7.4), width: 4, height: 5.4))
    ..addOval(Rect.fromCenter(center: const Offset(14.6, 7.4), width: 4, height: 5.4))
    ..addOval(Rect.fromCenter(center: const Offset(18.7, 10.9), width: 4, height: 5.2));
  static Path? _paw;

  static const String house =
      'M12 3.2 3 10.6V20a1.4 1.4 0 0 0 1.4 1.4h5V15h5.2v6.4h5A1.4 1.4 0 0 0 21 20v-9.4z';
  static Path walker() => _walker ??= Path()
    ..addOval(Rect.fromCircle(center: const Offset(13.2, 4.3), radius: 2.2))
    ..addPath(
        PawSvgPath.parse(
            'M9.6 21.5l1.6-6.6 2.1 2v4.6h2.2v-6.1l-2.3-2.2.7-3.3c1.1 1.4 2.7 2.3 4.6 2.3V10c-1.6 0-2.9-.8-3.6-2.1l-1-1.6c-.4-.6-1-1-1.7-1-.3 0-.6.1-.8.2L7 7.6v4.6h2.2V9l1.7-.7-1.6 8.1-3.9-.8-.4 2.1z'),
        Offset.zero);
  static Path? _walker;

  // Icônes Material du site (bulles de prix / demandes).
  static const String msHome =
      'M10 19v-5h4v5c0 .55.45 1 1 1h3c.55 0 1-.45 1-1v-7h1.7c.46 0 .68-.57.33-.87L12.67 3.6c-.38-.34-.96-.34-1.34 0l-8.36 7.53c-.34.3-.13.87.33.87H5v7c0 .55.45 1 1 1h3c.55 0 1-.45 1-1z';
  static const String msWalk =
      'M13.5 5.5c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zM9.8 8.9 7 23h2.1l1.8-8 2.1 2v6h2v-7.5l-2.1-2 .6-3C14.8 12 16.8 13 19 13v-2c-1.9 0-3.5-1-4.3-2.4l-1-1.6c-.4-.6-1-1-1.7-1-.3 0-.5.1-.8.1L6 8.3V13h2V9.6l1.8-.7';

  static const String crown = 'M3 8l4.5 4L12 5l4.5 7L21 8l-1.6 10H4.6z';
  static const String rocket =
      'M14.5 2.5c3.3 0 6.4 1.6 7 4-3.2 6.4-6.7 9.6-9.7 11.2l-3.5-3.5C10 11.2 11.3 6 14.5 2.5zM8 14.7 4.4 13c1-2.2 2.4-3.9 4.1-5.1zM9.3 16 11 19.6c2.2-1 3.9-2.4 5.1-4.1zM4 20c1.1-2.6 2.2-3.5 3.6-3.6.2 1.4-.9 2.5-3.6 3.6zM15 7a1.6 1.6 0 1 0 0 3.2A1.6 1.6 0 0 0 15 7z';
  static const String check = 'M5 12.5l4.5 4.5L19 7.5';
  static const String eyeOff =
      'M3 3l18 18M10.6 5.3A10.5 10.5 0 0 1 12 5.2c5 0 8.6 4.2 9.6 6.8-.4 1-1.2 2.3-2.4 3.5M6.6 6.6C4.3 8.1 2.9 10.4 2.4 12c1 2.6 4.6 6.8 9.6 6.8 1.7 0 3.2-.4 4.5-1.1M9.9 9.9a3 3 0 0 0 4.2 4.2';
  static const String sparkle =
      'M12 1.5l2.2 7.3 7.3 2.2-7.3 2.2-2.2 7.3-2.2-7.3L2.5 11l7.3-2.2z';

  /// Épingle de lieu du site (boîte 30 × 39, pointe ≈ 37,7).
  static const String placePin =
      'M15 1C7.3 1 1.5 6.8 1.5 14.2c0 9.6 11.2 21.6 12.6 23.1.5.5 1.3.5 1.8 0 1.4-1.5 12.6-13.5 12.6-23.1C28.5 6.8 22.7 1 15 1z';

  /// Glyphes des lieux (grille 24, `PLACE_GLYPH` du site).
  static const Map<String, String> place = {
    'vet': 'M10 3h4v7h7v4h-7v7h-4v-7H3v-4h7z',
    'shop': 'M4 7h16l-1 13H5zM8 7V5a4 4 0 0 1 8 0v2h-2V5a2 2 0 0 0-4 0v2z',
    'groomer':
        'M8.5 3a3.5 3.5 0 1 1-2.4 6l3.6 3.6 3.6-3.6a3.5 3.5 0 1 1 1.4 1.4L11.4 14l4.8 4.8-1.4 1.4-4.8-4.8-4.8 4.8-1.4-1.4L8.6 14 4.9 10.3A3.5 3.5 0 0 1 8.5 3z',
    'park': 'M12 2 5.5 11h3L4 17h6.5v5h3v-5H20l-4.5-6h3z',
    'beach':
        'M3 17c2 0 2 1.5 4 1.5s2-1.5 4-1.5 2 1.5 4 1.5 2-1.5 4-1.5 2 1.5 4 1.5v2c-2 0-2-1.5-4-1.5s-2 1.5-4 1.5-2-1.5-4-1.5-2 1.5-4 1.5-2-1.5-4-1.5zM12 3a6 6 0 0 1 6 6h-2l-3-3v9h-2V6L8 9H6a6 6 0 0 1 6-6z',
    'water': 'M12 2.5c3.5 4.5 6 7.9 6 11.3A6 6 0 0 1 6 13.8c0-3.4 2.5-6.8 6-11.3z',
    'trainer': 'M4 6h3v12H4zm13 0h3v12h-3zM8 10h8v4H8zm-6 1h2v2H2zm18 0h2v2h-2z',
    'hotel':
        'M3 5h2v10h6V9h8a2 2 0 0 1 2 2v9h-2v-3H5v3H3zM7 9a2 2 0 1 1 0 4 2 2 0 0 1 0-4z',
    'restaurant':
        'M7 2h2v6a2 2 0 0 0 2-2V2h2v4a4 4 0 0 1-3 3.9V22H8V9.9A4 4 0 0 1 5 6V2h2zm10 0c1.7 0 3 2.2 3 5s-1.3 5-3 5v10h-2V2z',
  };

  /// Glyphe blanc du rôle (patte / maison / marcheur).
  static Path role(String role) {
    switch (role.toLowerCase()) {
      case 'sitter':
        return PawSvgPath.parse(house);
      case 'walker':
        return walker();
      default:
        return paw();
    }
  }
}

/// Peintres purs. Toutes les coordonnées sont en pixels LOGIQUES : l'appelant
/// applique `canvas.scale(dpr, dpr)` avant et alloue une image à la même
/// densité après (voir [renderPinPng]).
class PawMapPinPainter {
  PawMapPinPainter._();

  // ── briques ────────────────────────────────────────────────────────────

  /// Glyphe vectoriel (grille [viewBox]) dans [box]. [stroke] > 0 = trait.
  static void drawGlyph(Canvas canvas, Path glyph, Rect box, Color color,
      {double viewBox = 24, double stroke = 0}) {
    canvas.save();
    canvas.translate(box.left, box.top);
    canvas.scale(box.width / viewBox, box.height / viewBox);
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    if (stroke > 0) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
    }
    canvas.drawPath(glyph, paint);
    canvas.restore();
  }

  static void drawSvg(Canvas canvas, String d, Rect box, Color color,
          {double viewBox = 24, double stroke = 0}) =>
      drawGlyph(canvas, PawSvgPath.parse(d), box, color,
          viewBox: viewBox, stroke: stroke);

  static void drawIcon(Canvas canvas, IconData icon, Offset center,
      double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  static void drawText(Canvas canvas, String text, Offset center, double size,
      Color color,
      {FontWeight weight = FontWeight.w800, bool inter = true}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text, style: _pinStyle(size, weight, color, inter: inter)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  /// Dégradé linéaire CSS `linear-gradient(<deg>deg, …)` sur [r] : même
  /// ligne de gradient que le navigateur (angle 0 = vers le haut, sens des
  /// aiguilles d'une montre).
  static Shader cssLinear(Rect r, double deg, List<Color> colors,
      [List<double>? stops]) {
    final a = deg * math.pi / 180;
    final dir = Offset(math.sin(a), -math.cos(a));
    final half =
        (r.width * math.sin(a).abs() + r.height * math.cos(a).abs()) / 2;
    return ui.Gradient.linear(
        r.center - dir * half, r.center + dir * half, colors, stops);
  }

  /// Ombre portée façon CSS `box-shadow: 0 dy blur spread color` d'une forme.
  static void cssShadow(Canvas canvas, Path shape,
      {double dy = 0,
      double blur = 0,
      double spread = 0,
      required Color color}) {
    Path p = shape.shift(Offset(0, dy));
    if (spread != 0) {
      final b = shape.getBounds();
      final sx = (b.width + 2 * spread) / b.width;
      final sy = (b.height + 2 * spread) / b.height;
      final m = Matrix4.identity()
        ..translateByDouble(b.center.dx, b.center.dy + dy, 0, 1)
        ..scaleByDouble(sx, sy, 1, 1)
        ..translateByDouble(-b.center.dx, -b.center.dy, 0, 1);
      p = shape.transform(m.storage);
    }
    final paint = Paint()..color = color;
    if (blur > 0) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2);
    }
    canvas.drawPath(p, paint);
  }

  /// Ancienne ombre douce (conservée pour compatibilité).
  static void drawShadow(Canvas canvas, Path shape, {double blur = 3}) =>
      cssShadow(canvas, shape,
          dy: 1.6,
          blur: blur * 2,
          color: PawMapLegend.ink.withValues(alpha: 0.22));

  // Fonction d'erreur complémentaire (Abramowitz & Stegun 7.1.26 étendu).
  static double _erfc(double x) {
    final z = x.abs();
    final t = 1 / (1 + 0.5 * z);
    final r = t *
        math.exp(-z * z -
            1.26551223 +
            t * (1.00002368 +
                t * (0.37409196 +
                    t * (0.09678418 +
                        t * (-0.18628806 +
                            t * (0.27886807 +
                                t * (-1.13520398 +
                                    t * (1.48851587 +
                                        t * (-0.82215223 + t * 0.17087277)))))))));
    return x >= 0 ? r : 2 - r;
  }

  /// Opacité d'un calque `box-shadow 0 0 blur spread` à [d] px du bord.
  static double _layerAlpha(double d, double spread, double blur) {
    if (blur <= 0) return d <= spread ? 1 : 0;
    final sigma = blur / 2;
    return 0.5 * _erfc((d - spread) / (sigma * math.sqrt2));
  }

  /// HALO RADIAL (v592) : l'équivalent exact d'un empilement de
  /// `box-shadow: 0 0 <blur> <spread> <couleur>` du site autour d'un rond de
  /// rayon [r], calculé en dégradé radial (courbe de Gauss), qui s'éteint en
  /// douceur AVANT [maxR] (le bord du bitmap) : jamais de lueur coupée net.
  /// [layers] : (spread, blur, opacité).
  static void drawCssGlow(Canvas canvas, Offset c, double r, double maxR,
      Color color, List<(double, double, double)> layers) {
    if (maxR <= r + 1) return;
    const int n = 36;
    final span = maxR - r;
    final colors = <Color>[];
    final stops = <double>[];
    double alphaAt(double d) {
      double keep = 1;
      for (final (spread, blur, a) in layers) {
        keep *= 1 - a * _layerAlpha(d, spread, blur);
      }
      // Extinction douce sur le dernier quart (jamais de bord net).
      final t = ((d - span * 0.72) / (span * 0.28)).clamp(0.0, 1.0);
      final taper = 1 - t * t * (3 - 2 * t);
      return (1 - keep) * taper;
    }

    colors.add(color.withValues(alpha: alphaAt(0)));
    stops.add(0);
    for (var i = 0; i <= n; i++) {
      final d = span * i / n;
      colors.add(color.withValues(alpha: i == n ? 0 : alphaAt(d)));
      stops.add((r + d) / maxR);
    }
    canvas.drawCircle(
        c, maxR, Paint()..shader = ui.Gradient.radial(c, maxR, colors, stops));
  }

  /// Lueur TURQUOISE qui respire (PawBoost). [phase] 0..1 → sinus doux.
  /// Valeurs de `@keyframes hps-breathe` du site.
  static void drawBoostGlow(Canvas canvas, Offset center, double radius,
          double phase, {double? maxR}) =>
      drawGlow(canvas, center, radius, phase, PawMapLegend.boost, maxR: maxR);

  /// Lueur qui respire. Turquoise = PawBoost (`hps-breathe`), violet = la
  /// personne suivie en direct (`hps-follow`).
  static void drawGlow(Canvas canvas, Offset center, double radius,
      double phase, Color color,
      {double? maxR}) {
    final s = 0.5 + 0.5 * math.sin(phase * 2 * math.pi);
    final m = maxR ?? radius + 22;
    if (color == PawMapLegend.pawFollow) {
      drawCssGlow(canvas, center, radius, m, color, [
        (3 + 4 * s, 0, 0.45 - 0.17 * s),
        (3 + 7 * s, 10 + 16 * s, 0.5 + 0.2 * s),
      ]);
    } else {
      drawCssGlow(canvas, center, radius, m, color, [
        (3 + 3 * s, 0, 0.35 + 0.15 * s),
        (4 + 6 * s, 12 + 14 * s, 0.55 + 0.25 * s),
      ]);
    }
  }

  /// Pastille ronde façon site : fond, bord blanc (ou [border]) inclus dans
  /// le diamètre, petite ombre.
  static void _badgeDisc(Canvas canvas, Offset c, double size, Color fill,
      {Color border = Colors.white,
      double borderW = 1.5,
      double shadowAlpha = 0.3}) {
    final r = size / 2;
    cssShadow(canvas, Path()..addOval(Rect.fromCircle(center: c, radius: r)),
        dy: 1, blur: 3, color: PawMapLegend.ink.withValues(alpha: shadowAlpha));
    canvas.drawCircle(c, r, Paint()..color = border);
    canvas.drawCircle(c, r - borderW, Paint()..color = fill);
  }

  /// Fusée PawBoost : blanche sur pastille turquoise (site : `rocketBadge`).
  static void drawRocketBadge(Canvas canvas, Offset center, double size) {
    _badgeDisc(canvas, center, size, PawMapLegend.boost);
    final g = (size * 0.62).roundToDouble();
    drawSvg(canvas, PawGlyphs.rocket,
        Rect.fromCenter(center: center, width: g, height: g), Colors.white);
  }

  /// Paw Premium (site : `crownBadge`) : pastille OR, bord encre 1,5,
  /// couronne encre.
  static void drawCrown(Canvas canvas, Offset center, double size) {
    _badgeDisc(canvas, center, size, PawMapLegend.gold,
        border: PawMapLegend.ink, shadowAlpha: 0.35);
    final g = (size / 2).roundToDouble() + 2;
    drawSvg(canvas, PawGlyphs.crown,
        Rect.fromCenter(center: center, width: g, height: g), PawMapLegend.ink);
  }

  /// Œil barré (mode « visible par mes amis seulement »).
  static void drawEyeOffBadge(Canvas canvas, Offset center, double size) {
    _badgeDisc(canvas, center, size, PawMapLegend.ink, shadowAlpha: 0.2);
    final g = (size * 0.65).roundToDouble();
    drawSvg(canvas, PawGlyphs.eyeOff,
        Rect.fromCenter(center: center, width: g, height: g), Colors.white,
        stroke: 2.2);
  }

  /// Coche bleue « identité vérifiée » (site : `verifiedBadge`, 15 px).
  static void drawVerifiedBadge(Canvas canvas, Offset center,
      [double size = 15]) {
    _badgeDisc(canvas, center, size, const Color(0xFF2F6FE0), shadowAlpha: 0);
    final g = size * 10 / 15;
    drawSvg(canvas, PawGlyphs.check,
        Rect.fromCenter(center: center, width: g, height: g), Colors.white,
        stroke: 3.4);
  }

  /// Point « en ligne » (vert) ou « hors ligne / signal perdu » (orange) :
  /// bord blanc 2 px inclus (site : `onlineDot`).
  static void drawOnlineDot(Canvas canvas, Offset center, double size,
      {bool online = true}) {
    _badgeDisc(canvas, center, size,
        online ? PawMapLegend.online : PawMapLegend.offline,
        borderW: 2);
  }

  static void drawDashedRing(Canvas canvas, Offset center, double radius,
      Color color, double width) {
    const dash = 5.0, gap = 3.5;
    final circumference = 2 * math.pi * radius;
    final n = (circumference / (dash + gap)).floor();
    final sweep = (circumference / n - gap) / radius;
    final step = 2 * math.pi / n;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (var i = 0; i < n; i++) {
      canvas.drawArc(rect, i * step - math.pi / 2, sweep, false, paint);
    }
  }

  /// Goutte (épingle) : pointe en bas = position exacte (ancien dessin,
  /// conservé pour compatibilité).
  static Path dropPath(double cx, double cy, double r, double tipY) {
    final p = Path();
    p.moveTo(cx, tipY);
    p.cubicTo(cx - r * 0.30, tipY - r * 0.62, cx - r * 1.02, cy + r * 0.78,
        cx - r, cy);
    p.arcToPoint(Offset(cx + r, cy), radius: Radius.circular(r), clockwise: true);
    p.cubicTo(cx + r * 1.02, cy + r * 0.78, cx + r * 0.30, tipY - r * 0.62,
        cx, tipY);
    p.close();
    return p;
  }

  /// Goutte du site pour les PawSpots : un cercle de rayon [r] et une pointe
  /// à r·√2 sous son centre (carré aux 3 coins arrondis tourné de −45°).
  static Path spotDropPath(Offset c, double r) {
    const k = math.sqrt1_2;
    final tip = Offset(c.dx, c.dy + r * math.sqrt2);
    return Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(c.dx - r * k, c.dy + r * k)
      ..arcToPoint(Offset(c.dx + r * k, c.dy + r * k),
          radius: Radius.circular(r), largeArc: true, clockwise: true)
      ..close();
  }

  // ── étiquettes (v592 : mêmes pastilles que le site) ─────────────────────

  /// Style d'étiquette sous un rond.
  ///   · [me]      « Moi » : pilule ENCRE, texte blanc (Inter 700 11) ;
  ///   · [friend]  ami (« Vu il y a 5 j », prénom) : pilule blanche bordée
  ///               de ROSE, texte à la couleur du rôle ;
  ///   · [lost]    ami au signal perdu : crème, bord orange ;
  ///   · [name]    membre : étiquette blanche 20 px, Poppins 600 10,5.
  static void _paintPill(
    Canvas canvas, {
    required String text,
    required double cx,
    required double top,
    required TextStyle style,
    required double height,
    required double padX,
    required Color bg,
    Color? border,
    double borderW = 0,
    double shadowDy = 1,
    double shadowBlur = 4,
    double shadowSpread = 0,
    double shadowAlpha = 0.25,
    double maxWidth = 160,
    double rating = 0,
  }) {
    TextPainter? rp;
    const double star = 10;
    if (rating > 0) {
      rp = TextPainter(
        text: TextSpan(
            text: rating.toStringAsFixed(1),
            style: style.copyWith(
                color: PawMapLegend.darken(PawMapLegend.gold, 0.35))),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
    }
    final extra = rp == null ? 0.0 : 4 + star + 1 + rp.width;
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: math.max(10, maxWidth - 2 * padX - extra));
    final w = tp.width + 2 * padX + extra;
    final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w / 2, top, w, height), Radius.circular(height / 2));
    if (shadowAlpha > 0) {
      cssShadow(canvas, Path()..addRRect(rect),
          dy: shadowDy,
          blur: shadowBlur,
          spread: shadowSpread,
          color: PawMapLegend.ink.withValues(alpha: shadowAlpha));
    }
    if (border != null && borderW > 0) {
      canvas.drawRRect(rect, Paint()..color = border);
      canvas.drawRRect(rect.deflate(borderW), Paint()..color = bg);
    } else {
      canvas.drawRRect(rect, Paint()..color = bg);
    }
    final left = cx - w / 2 + padX;
    final ty = top + (height - tp.height) / 2;
    tp.paint(canvas, Offset(left, ty));
    if (rp != null) {
      final sx = left + tp.width + 4;
      drawIcon(canvas, Icons.star_rounded,
          Offset(sx + star / 2, top + height / 2), star + 1, PawMapLegend.gold);
      rp.paint(canvas, Offset(sx + star + 1, top + (height - rp.height) / 2));
    }
  }

  /// Étiquette « prénom » d'un membre (site : `nameTagHtml`) : 20 px, fond
  /// blanc, Poppins 600 10,5 #1B1616, ombre 0 2 6 −1.
  static void _paintNameTag(Canvas canvas, String text, double cx, double top,
      {double rating = 0}) {
    _paintPill(canvas,
        text: text,
        cx: cx,
        top: top,
        style: _pinStyle(10.5, FontWeight.w600, const Color(0xFF1B1616)),
        height: 20,
        padX: 8,
        bg: Colors.white,
        shadowDy: 2,
        shadowBlur: 6,
        shadowSpread: -1,
        shadowAlpha: 0.35,
        rating: rating);
  }

  // ── PERSONNES (ronds) ──────────────────────────────────────────────────

  /// Marge autour d'un rond (couronne, lueur, liserés des rôles). v592 :
  /// 22 px pour que la lueur PawBoost (jusqu'à ~26 px sur le site) s'éteigne
  /// DANS le bitmap au lieu d'être coupée.
  static const double memberMargin = 22;

  /// Hauteur réservée AU-DESSUS du rond pour la bulle de prix (22 de bulle +
  /// 6 de pointe + marges).
  static const double priceBubbleZone = 32;

  /// Taille d'un bitmap de membre (avec la marge basse pour l'étiquette et,
  /// v592, la zone de la bulle de prix au-dessus).
  static double memberBitmapSize(double size,
          {bool withLabel = false, bool withBubble = false}) =>
      size +
      2 * memberMargin +
      (withLabel ? 12 : 0) +
      (withBubble ? priceBubbleZone : 0);

  /// Ancre verticale (0..1) d'un rond de membre : le centre du cercle.
  static double memberAnchorY(double size,
      {bool withLabel = false, bool withBubble = false}) {
    final zone = withBubble ? priceBubbleZone : 0.0;
    return (zone + memberMargin + size / 2) /
        memberBitmapSize(size, withLabel: withLabel, withBubble: withBubble);
  }

  /// Rond de MEMBRE sans photo (site : `memberPinHtml` sans avatar) : disque
  /// en DÉGRADÉ du rôle (170°), liseré blanc 2,5, glyphe blanc du rôle ;
  /// ombre 0 5 12 −4 ; au zoom rue le prénom dessous et, v592, le prix dans
  /// une bulle à la couleur du service AU-DESSUS ([priceBubble]).
  static void paintMemberDot(
    Canvas canvas, {
    required String role,
    double size = PawMapLegend.memberSize,
    bool crown = false,
    bool verified = false,
    bool online = false,
    bool selected = false,
    double? boostPhase,
    String? priceLabel,
    double rating = 0,
    String? priceBubble,
  }) {
    final bool withBubble = priceBubble != null && priceBubble.isNotEmpty;
    if (withBubble) {
      drawPriceBubble(canvas,
          cx: memberMargin + size / 2,
          bottom: priceBubbleZone + memberMargin - 3,
          text: priceBubble,
          role: role);
      canvas.save();
      canvas.translate(0, priceBubbleZone);
    }
    const margin = memberMargin;
    final r = size / 2;
    final c = Offset(margin + r, margin + r);
    final color = PawMapLegend.roleColor(role);
    final (light, dark) = PawMapLegend.ringGradient(color);
    final circle = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    if (boostPhase != null) {
      drawBoostGlow(canvas, c, r, boostPhase, maxR: r + margin - 0.5);
      cssShadow(canvas, circle,
          dy: 2, blur: 6, color: PawMapLegend.ink.withValues(alpha: 0.35));
    } else {
      cssShadow(canvas, circle,
          dy: 5,
          blur: 12,
          spread: -4,
          color: PawMapLegend.ink.withValues(alpha: 0.5));
    }
    if (selected) {
      canvas.drawCircle(
        c,
        r + 3.5,
        Paint()
          ..color = PawMapLegend.darken(color).withValues(alpha: 0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }
    final rect = Rect.fromCircle(center: c, radius: r);
    // Liseré blanc 2,5 (compris dans le diamètre), puis le dégradé du rôle.
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    canvas.drawCircle(c, r - 2.5,
        Paint()..shader = cssLinear(rect, 170, [light, dark]));
    // Glyphe : boîte = diamètre − 2 × (20 % + liseré), comme le site.
    final inset = (size * 0.2).roundToDouble() + 2.5;
    drawGlyph(canvas, PawGlyphs.role(role), rect.deflate(inset), Colors.white);
    if (online) {
      final s = (size * 12 / 46).roundToDouble();
      drawOnlineDot(canvas, Offset(c.dx + r - s / 2, c.dy + r - s / 2), s);
    }
    if (boostPhase != null) {
      drawRocketBadge(canvas, Offset(c.dx - (r + 5 - 9), c.dy + r + 5 - 9), 18);
    } else if (verified) {
      drawVerifiedBadge(canvas, Offset(c.dx - (r + 2 - 7.5), c.dy + r + 1 - 7.5));
    }
    if (crown) {
      _crownAt(canvas, c, r, PawMapLegend.crownMember);
    }
    if (priceLabel != null && priceLabel.isNotEmpty) {
      _paintNameTag(canvas, priceLabel, c.dx, c.dy + r + 4, rating: rating);
    }
    if (withBubble) canvas.restore();
  }

  /// Couronne en haut à droite (site : top −35 %, right −30 % de sa taille).
  static void _crownAt(Canvas canvas, Offset c, double r, double s) {
    final top = (s * 0.35).roundToDouble();
    final right = (s * 0.3).roundToDouble();
    drawCrown(canvas, Offset(c.dx + r + right - s / 2, c.dy - r - top + s / 2), s);
  }

  /// Couleurs de la bulle par service (dégradé clair → foncé ; pointe =
  /// foncé) : gardien bleu, promeneur vert, demande de propriétaire orange.
  static (Color, Color) priceBubbleColors(String role) {
    switch (role.toLowerCase()) {
      case 'sitter':
        return (const Color(0xFF4A86F0), const Color(0xFF2458C9));
      case 'walker':
        return (const Color(0xFF43B862), const Color(0xFF1F7A37));
      default:
        // v592 — orange FONCÉ de la marque (Daniel, 26/09).
        return (const Color(0xFFC92A12), const Color(0xFF9E1F0B));
    }
  }

  /// Bulle de prix centrée en [cx], bas de la pointe en [bottom] (site :
  /// `priceBubbleHtml`) : 22 px, rayon 8, dégradé 170° du service, contour
  /// blanc 2, ombre 0 5 10 −4, icône 11 + texte Poppins 700 11,5, pointe
  /// 10 × 6 foncée 1 px sous la bulle.
  static void drawPriceBubble(Canvas canvas,
      {required double cx,
      required double bottom,
      required String text,
      required String role}) {
    final (light, dark) = priceBubbleColors(role);
    final String icon =
        role.toLowerCase() == 'walker' ? PawGlyphs.msWalk : PawGlyphs.msHome;
    final tp = TextPainter(
      text: TextSpan(
          text: text, style: _pinStyle(11.5, FontWeight.w700, Colors.white)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    const double h = 22;
    const double iconS = 11;
    const double gap = 4;
    final double w = 8 + iconS + gap + tp.width + 8;
    final double top = bottom - 6 - 1 - h;
    final body = Rect.fromLTWH(cx - w / 2, top, w, h);
    final rect = RRect.fromRectAndRadius(body, const Radius.circular(8));
    cssShadow(canvas, Path()..addRRect(rect.inflate(2)),
        dy: 5,
        blur: 10,
        spread: -4,
        color: PawMapLegend.ink.withValues(alpha: 0.45));
    canvas.drawRRect(rect.inflate(2), Paint()..color = Colors.white);
    final tip = Path()
      ..moveTo(cx - 5, top + h + 1)
      ..lineTo(cx + 5, top + h + 1)
      ..lineTo(cx, top + h + 7)
      ..close();
    canvas.drawPath(tip, Paint()..color = dark);
    canvas.drawRRect(
        rect, Paint()..shader = cssLinear(body, 170, [light, dark]));
    drawSvg(
        canvas,
        icon,
        Rect.fromCenter(
            center: Offset(cx - w / 2 + 8 + iconS / 2, top + h / 2),
            width: iconS,
            height: iconS),
        Colors.white);
    tp.paint(canvas,
        Offset(cx - w / 2 + 8 + iconS + gap, top + (h - tp.height) / 2));
  }

  /// Rond PHOTO : Moi (56, anneau à la couleur de mon rôle, étiquette « Moi »),
  /// un ami (50, anneau rose) ou un membre avec photo (46, anneau du rôle).
  /// [avatar] null → glyphe blanc du rôle sur le dégradé.
  static void paintPhotoDot(
    Canvas canvas, {
    required ui.Image? avatar,
    required Color ringColor,
    required double size,
    String? label,
    Color? labelColor,
    bool crown = false,
    double crownSize = PawMapLegend.crownFriend,
    bool online = false,
    bool dashedRing = false,
    bool eyeOff = false,
    double? boostPhase,
    double? followPhase,
    bool dimmed = false,
    IconData fallbackIcon = Icons.pets_rounded,
    Color fallbackTint = PawMapLegend.owner,
    List<Color>? ringColors,
    // v590 — bulle de prix au-dessus du rond (null = aucune).
    String? priceBubble,
    String priceRole = 'sitter',
    // v592 — options du site (toutes facultatives) :
    bool verified = false,
    bool pawFollowGlow = false,
    PawPinLabelStyle? labelStyle,
  }) {
    final bool withBubble = priceBubble != null && priceBubble.isNotEmpty;
    if (withBubble) {
      drawPriceBubble(canvas,
          cx: photoMargin + size / 2,
          bottom: priceBubbleZone + photoMargin - 3,
          text: priceBubble,
          role: priceRole);
      canvas.save();
      canvas.translate(0, priceBubbleZone);
    }
    _paintPhotoDotBody(
      canvas,
      avatar: avatar,
      ringColor: ringColor,
      size: size,
      label: label,
      labelColor: labelColor,
      crown: crown,
      crownSize: crownSize,
      online: online,
      dashedRing: dashedRing,
      eyeOff: eyeOff,
      boostPhase: boostPhase,
      followPhase: followPhase,
      dimmed: dimmed,
      fallbackIcon: fallbackIcon,
      fallbackTint: fallbackTint,
      ringColors: ringColors,
      verified: verified,
      pawFollowGlow: pawFollowGlow,
      labelStyle: labelStyle,
    );
    if (withBubble) canvas.restore();
  }

  static Color _veil(Color c, bool dimmed) =>
      dimmed ? Color.lerp(c, Colors.white, 0.45)! : c;

  static void _paintPhotoDotBody(
    Canvas canvas, {
    required ui.Image? avatar,
    required Color ringColor,
    required double size,
    String? label,
    Color? labelColor,
    bool crown = false,
    double crownSize = PawMapLegend.crownFriend,
    bool online = false,
    bool dashedRing = false,
    bool eyeOff = false,
    double? boostPhase,
    // v584 (25/09) — auréole VIOLETTE qui respire : la personne que je suis
    // en direct (PawFollow). Un seul halo par rond : PawBoost > PawFollow.
    double? followPhase,
    // v584 (25/09) — « signal perdu » : rond éteint à la couleur du rôle
    // (anneau plus clair, photo voilée), jamais gris.
    bool dimmed = false,
    IconData fallbackIcon = Icons.pets_rounded,
    Color fallbackTint = PawMapLegend.owner,
    // v585 → v592 : une personne à PLUSIEURS rôles = UN rond, entouré (comme
    // le site) d'un liseré blanc + d'un anneau PLEIN par rôle en plus.
    List<Color>? ringColors,
    bool verified = false,
    bool pawFollowGlow = false,
    PawPinLabelStyle? labelStyle,
  }) {
    const margin = photoMargin;
    final r = size / 2;
    final c = Offset(margin + r, margin + r);
    final bool isFriend = ringColor == PawMapLegend.friend;
    final bool isMe = !isFriend &&
        (dashedRing || eyeOff || size >= PawMapLegend.meSize);
    final double maxR = r + margin - 0.5;

    // 1. Halo : PawBoost > suivi en direct > PawFollow (famille) > moi.
    final circle = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    if (boostPhase != null) {
      drawBoostGlow(canvas, c, r, boostPhase, maxR: maxR);
    } else if (followPhase != null) {
      drawGlow(canvas, c, r, followPhase, PawMapLegend.pawFollow, maxR: maxR);
    } else if (pawFollowGlow) {
      drawCssGlow(canvas, c, r, maxR, PawMapLegend.pawFollow,
          [(4, 0, 0.35), (5, 16, 0.55)]);
    } else if (isMe) {
      // Le site fait « pulser » un anneau autour de moi (`hps-pulse`) : sur
      // un bitmap fixe, un halo doux de la couleur de mon rôle.
      drawCssGlow(canvas, c, r, maxR, ringColor, [(2, 0, 0.18), (3, 14, 0.30)]);
    }

    // 2. Anneaux des autres rôles (site : `extraRoleRings`), sous le rond.
    final extra = <Color>[];
    if (ringColors != null) {
      for (final col in ringColors) {
        if (!extra.contains(col)) extra.add(col);
      }
    }
    if (extra.length >= 2) {
      if (!isFriend) extra.remove(ringColor);
    } else {
      extra.clear();
    }
    for (var i = extra.length - 1; i >= 0; i--) {
      canvas.drawCircle(c, r + 5.0 * (i + 1), Paint()..color = _veil(extra[i], dimmed));
      canvas.drawCircle(c, r + 5.0 * i + 2, Paint()..color = Colors.white);
    }

    // 3. Ombre du rond.
    if (boostPhase != null || followPhase != null) {
      cssShadow(canvas, circle,
          dy: 2, blur: 6, color: PawMapLegend.ink.withValues(alpha: 0.35));
    } else if (isFriend || isMe) {
      cssShadow(canvas, circle,
          dy: 3, blur: 8, color: PawMapLegend.ink.withValues(alpha: 0.35));
    } else {
      cssShadow(canvas, circle,
          dy: 5,
          blur: 12,
          spread: -4,
          color: PawMapLegend.ink.withValues(alpha: 0.5));
    }

    // 4. Anneau 3 px (dégradé 170° : rose pour un ami, rôle sinon), liseré
    //    blanc 2 px, puis la photo.
    const ring = 3.0;
    const white = 2.0;
    final rect = Rect.fromCircle(center: c, radius: r);
    final (tl, td) = PawMapLegend.ringGradient(fallbackTint);
    if (dashedRing) {
      canvas.drawCircle(c, r, Paint()..color = Colors.white);
      drawDashedRing(canvas, c, r - ring / 2, _veil(ringColor, dimmed), ring);
    } else {
      final pair = PawMapLegend.ringGradient(ringColor);
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..shader = cssLinear(rect, 170,
                [_veil(pair.$1, dimmed), _veil(pair.$2, dimmed)]));
    }
    canvas.drawCircle(c, r - ring, Paint()..color = Colors.white);
    final photoR = r - ring - white;
    final photoRect = Rect.fromCircle(center: c, radius: photoR);
    canvas.save();
    canvas.clipPath(Path()..addOval(photoRect));
    canvas.drawRect(photoRect,
        Paint()..shader = cssLinear(photoRect, 170, [tl, td]));
    if (avatar != null) {
      // « object-fit: cover » : on recadre au centre, jamais d'écrasement.
      final iw = avatar.width.toDouble(), ih = avatar.height.toDouble();
      final side = math.min(iw, ih);
      final src = Rect.fromLTWH((iw - side) / 2, (ih - side) / 2, side, side);
      canvas.drawImageRect(
        avatar,
        src,
        photoRect,
        Paint()
          ..filterQuality = FilterQuality.high
          ..isAntiAlias = true,
      );
    } else {
      final inset = photoR * 0.42;
      drawGlyph(canvas, _glyphFor(fallbackIcon), photoRect.deflate(inset),
          Colors.white);
    }
    if (dimmed) {
      // Voile chaud à la couleur du rôle (jamais gris) : « signal perdu ».
      canvas.drawRect(
          photoRect,
          Paint()
            ..color = Color.lerp(fallbackTint, Colors.white, 0.35)!
                .withValues(alpha: 0.55));
    }
    canvas.restore();

    // 5. Pastilles (positions du site, en px CSS).
    if (online || dimmed) {
      final s = (size * 13 / 50).roundToDouble();
      drawOnlineDot(canvas, Offset(c.dx + r - s / 2, c.dy + r - s / 2), s,
          online: online && !dimmed);
    }
    if (boostPhase != null) {
      final s = isMe ? 20.0 : 18.0;
      final b = (s * 0.25).roundToDouble(), l = (s * 0.3).roundToDouble();
      drawRocketBadge(
          canvas, Offset(c.dx - (r + l - s / 2), c.dy + r + b - s / 2), s);
    } else if (verified) {
      drawVerifiedBadge(canvas, Offset(c.dx - (r + 2 - 7.5), c.dy + r + 1 - 7.5));
    }
    if (eyeOff) {
      drawEyeOffBadge(canvas, Offset(c.dx - (r + 6 - 10), c.dy + r + 4 - 10), 20);
    }
    if (crown) {
      _crownAt(canvas, c, r, crownSize);
    }

    // 6. Étiquette sous le rond.
    if (label != null && label.isNotEmpty) {
      final style = labelStyle ??
          (isMe
              ? PawPinLabelStyle.me
              : isFriend
                  ? (dimmed ? PawPinLabelStyle.lost : PawPinLabelStyle.friend)
                  : PawPinLabelStyle.name);
      switch (style) {
        case PawPinLabelStyle.me:
          _paintPill(canvas,
              text: label,
              cx: c.dx,
              top: c.dy + r + 3,
              style: _pinStyle(11, FontWeight.w700, Colors.white, inter: true),
              height: 16.3,
              padX: 8,
              bg: PawMapLegend.ink,
              shadowAlpha: 0.22,
              shadowBlur: 4);
          break;
        case PawPinLabelStyle.friend:
        case PawPinLabelStyle.lost:
          final lost = style == PawPinLabelStyle.lost;
          _paintPill(canvas,
              text: label,
              cx: c.dx,
              top: c.dy + r + 3,
              style: _pinStyle(
                  11,
                  FontWeight.w700,
                  lost
                      ? const Color(0xFF9E1F0B)
                      : (labelStyle == null ? fallbackTint : (labelColor ?? fallbackTint)),
                  inter: true),
              height: 19.3,
              padX: 9.5,
              bg: lost ? const Color(0xFFFFF4E5) : Colors.white,
              border: lost ? PawMapLegend.owner : PawMapLegend.friend,
              borderW: 1.5);
          break;
        case PawPinLabelStyle.name:
          _paintNameTag(canvas, label, c.dx, c.dy + r + 4);
          break;
      }
    }
  }

  /// Glyphe vectoriel du site pour une icône de rôle (sinon patte).
  static Path _glyphFor(IconData icon) {
    if (icon == Icons.home_rounded) return PawGlyphs.role('sitter');
    if (icon == Icons.directions_walk_rounded) return PawGlyphs.role('walker');
    return PawGlyphs.paw();
  }

  static const double photoMargin = 22;
  static double photoBitmapSize(double size, {bool withLabel = false}) =>
      size + 2 * photoMargin + (withLabel ? 10 : 0);

  /// Ancre verticale (0..1) d'un rond photo : le centre du cercle.
  static double photoAnchorY(double size,
      {bool withLabel = false, bool withBubble = false}) {
    final zone = withBubble ? priceBubbleZone : 0.0;
    return (zone + photoMargin + size / 2) /
        (photoBitmapSize(size, withLabel: withLabel) + zone);
  }

  // ── GROUPES ────────────────────────────────────────────────────────────

  /// Groupe de MEMBRES (site : `memberClusterHtml`, 25/09) : un ROND plein
  /// au dégradé 160° du rôle DOMINANT, chiffre blanc Inter 800, liseré
  /// blanc 2,5 ; fin anneau rose s'il contient un ami. Jamais un carré.
  static void paintMemberCluster(Canvas canvas, int count,
      {Map<String, int>? roleCounts, bool hasFriend = false}) {
    final label = count > 99 ? '99+' : '$count';
    String dom = 'sitter';
    if (roleCounts != null) {
      var best = -1;
      for (final k in const ['owner', 'sitter', 'walker']) {
        final v = roleCounts[k] ?? 0;
        if (v > best) {
          best = v;
          dom = k;
        }
      }
    }
    final double size = count >= 10 ? 44 : 40;
    final box = memberClusterWidth(count);
    final c = Offset(6 + box / 2, 6 + box / 2);
    final r = size / 2;
    final circle = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    cssShadow(canvas, circle,
        dy: 3, blur: 8, color: PawMapLegend.ink.withValues(alpha: 0.35));
    if (hasFriend) {
      canvas.drawCircle(c, r + 2.5, Paint()..color = PawMapLegend.friend);
    }
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    canvas.drawCircle(
        c,
        r - 2.5,
        Paint()
          ..shader = cssLinear(rect, 160,
              [PawMapLegend.roleColor(dom), PawMapLegend.roleDark(dom)]));
    drawText(canvas, label, c, label.length > 2 ? 12 : 15, Colors.white);
  }

  /// Côté du bitmap d'un groupe de membres, marge de 6 px déduite (le rond
  /// fait 40 / 44 px, l'ombre a besoin de place).
  static double memberClusterWidth(int count) => PawMapLegend.memberClusterHeight;

  /// Carré d'un groupe de LIEUX (site : `placeClusterHtml`) : 32 px blanc,
  /// rayon 8, bord 1,5 et chiffre à la couleur du type dominant.
  /// Groupe de PawSpots ([black]) (site : `spotClusterHtml`) : 36 px ENCRE,
  /// rayon 10, bord or 2, chiffre OR.
  static void paintSquareCluster(Canvas canvas, int count,
      {required Color tone, bool black = false}) {
    final label = count > 99 ? '99+' : '$count';
    final box = squareClusterBitmapSize();
    final c = Offset(box / 2, box / 2);
    final double s =
        black ? PawMapLegend.spotClusterSize : PawMapLegend.placeClusterSize;
    final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: s, height: s),
        Radius.circular(black ? 10 : 8));
    cssShadow(canvas, Path()..addRRect(rect),
        dy: black ? 2 : 1,
        blur: black ? 6 : 4,
        color: PawMapLegend.ink.withValues(alpha: black ? 0.4 : 0.25));
    final borderW = black ? 2.0 : 1.5;
    canvas.drawRRect(rect, Paint()..color = black ? PawMapLegend.gold : tone);
    canvas.drawRRect(rect.deflate(borderW),
        Paint()..color = black ? PawMapLegend.ink : Colors.white);
    drawText(
      canvas,
      label,
      c,
      black ? (label.length > 2 ? 11 : 13) : (label.length > 2 ? 10 : 12),
      black ? PawMapLegend.gold : tone,
    );
  }

  static double squareClusterBitmapSize() => PawMapLegend.spotClusterSize + 20;

  // ── LIEUX (gouttes) ───────────────────────────────────────────────────

  static double dropHeight(double width) => width * 1.32 + 2 * dropMargin;
  static double dropBitmapWidth(double width) => width + 2 * dropMargin;
  // v592 — 12 px : le halo or des PawSpots (7 px sur le site) et l'ombre
  // tiennent dans le bitmap.
  static const double dropMargin = 12;

  /// Goutte de LIEU (site : `placePinHtml`) : épingle PLEINE à la couleur du
  /// type, bord blanc 1,6, ombre portée 0 2 3, glyphe blanc du type.
  /// [size] = largeur logique (30) ; la pointe tombe sur l'ancre de l'app.
  static void paintPlaceDrop(Canvas canvas,
      {required String category, double size = PawMapLegend.placeSize}) {
    const m = dropMargin;
    final k = size / 30;
    final tipY = m + size * 1.32;
    final dx = m;
    final dy = tipY - 37.7 * k;
    final color = PawMapLegend.placeColor(category);
    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(k, k);
    final pin = PawSvgPath.parse(PawGlyphs.placePin);
    cssShadow(canvas, pin,
        dy: 2, blur: 3, color: PawMapLegend.ink.withValues(alpha: 0.35));
    canvas.drawPath(pin, Paint()..color = color);
    canvas.drawPath(
        pin,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round);
    final glyph = PawGlyphs.place[category];
    final box = const Rect.fromLTWH(6.5, 5.5, 16.8, 16.8);
    if (glyph != null) {
      drawSvg(canvas, glyph, box, Colors.white);
    } else {
      canvas.drawCircle(box.center, 16.8 * 4 / 24, Paint()..color = Colors.white);
    }
    canvas.restore();
  }

  /// Goutte PawSpot (site : `spotPinHtml`, 590 §6) : goutte (cercle + pointe),
  /// halo or 7 px, ombre 0 6 12 −4.
  ///   PawSpot : fond noir #3A3232 → #171212, patte or, contour or 2,5.
  ///   PawSpot doré (validé) : fond or #FFE08A → #F0B323 → #C98A08, patte
  ///   noire, contour blanc, éclat blanc.
  static void paintPawSpotDrop(Canvas canvas,
      {required String type, bool golden = false}) {
    final double w = golden ? PawMapLegend.spotGoldSize : PawMapLegend.spotSize;
    final k = w / 40;
    const m = dropMargin;
    final r = w / 2;
    final tipY = m + w * 1.32;
    final c = Offset(m + r, tipY - r * math.sqrt2);
    final shape = spotDropPath(c, r);
    // Halo or 7 px qui suit la forme (box-shadow 0 0 0 7px), bord adouci.
    final halo = spotDropPath(c, r + 7 * k);
    canvas.drawPath(
        halo,
        Paint()
          ..color = const Color(0xFFF0B323).withValues(alpha: golden ? 0.28 : 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8));
    cssShadow(canvas, shape,
        dy: 6 * k,
        blur: 12 * k,
        spread: -4 * k,
        color: PawMapLegend.ink.withValues(alpha: 0.55));
    // Le dégradé tourne avec la goutte : 170° − 45° = 125° à l'écran.
    final box = Rect.fromCircle(center: c, radius: r);
    canvas.drawPath(shape,
        Paint()..color = golden ? Colors.white : const Color(0xFFF0B323));
    final inner = spotDropPath(c, r - 2.5 * k);
    canvas.drawPath(
        inner,
        Paint()
          ..shader = golden
              ? cssLinear(box, 125, const [
                  Color(0xFFFFE08A),
                  Color(0xFFF0B323),
                  Color(0xFFC98A08)
                ], const [
                  0,
                  0.5,
                  1
                ])
              : cssLinear(
                  box, 125, const [Color(0xFF3A3232), Color(0xFF171212)]));
    drawGlyph(
        canvas,
        PawGlyphs.paw(),
        Rect.fromCenter(center: c, width: 20 * k, height: 20 * k),
        golden ? const Color(0xFF171212) : const Color(0xFFF0B323));
    if (golden) {
      // Éclat blanc liseré d'encre, en haut à droite (top −4, right −5).
      final s = 15 * k;
      final sc = Offset(c.dx + r + 5 * k - s / 2, c.dy - r - 4 * k + s / 2);
      final sb = Rect.fromCenter(center: sc, width: s, height: s);
      drawSvg(canvas, PawGlyphs.sparkle, sb, Colors.white);
      drawSvg(canvas, PawGlyphs.sparkle, sb, const Color(0xFF171212),
          stroke: 1.2);
    }
  }

  // ── DEMANDES (bulles orange) ──────────────────────────────────────────

  static double _estTextW(String t, double fs) => t.runes.length * fs * 0.64 + 2;
  static double _reqBodyW(String? price) => (price == null || price.isEmpty)
      ? 28
      : 9 + 14 + 4 + _estTextW(price, 12) + 9;
  static double _reqPillW(String? mine) =>
      (mine == null || mine.isEmpty) ? 0 : 14 + _estTextW(mine, 10);

  /// Bulle d'une demande de propriétaire (site : `requestBubbleHtml`) :
  /// 26 px, rayon 9, dégradé 170° #C92A12 → #9E1F0B (orange FONCÉ, v592), contour blanc 2, ombre
  /// 0 6 12 −4, pointe 12 × 7 foncée, icône 14 (maison / marcheur) + budget
  /// Poppins 700 12. [mineLabel] → pastille ENCRE « Ma demande » au-dessus
  /// (le propriétaire voit les siennes).
  static void paintRequestBubble(Canvas canvas,
      {String? priceLabel,
      required bool walking,
      double? boostPhase,
      String? mineLabel}) {
    const m = 8.0;
    const H = PawMapLegend.requestBubbleHeight;
    const double h = 26;
    final boxW = requestBubbleWidth(priceLabel: priceLabel, mineLabel: mineLabel);
    final cx = m + boxW / 2;
    final bodyBottom = m + H - 1;
    final top = bodyBottom - h;
    final hasPrice = priceLabel != null && priceLabel.isNotEmpty;
    final (light, dark) = priceBubbleColors('owner');
    TextPainter? tp;
    if (hasPrice) {
      tp = TextPainter(
        text: TextSpan(
            text: priceLabel,
            style: _pinStyle(12, FontWeight.w700, Colors.white)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
    }
    final double pad = hasPrice ? 9 : 7;
    final double w = pad + 14 + (hasPrice ? 4 + tp!.width : 0) + pad;
    final bodyRect = Rect.fromLTWH(cx - w / 2, top, w, h);
    final body = RRect.fromRectAndRadius(bodyRect, const Radius.circular(9));
    if (boostPhase != null) {
      final s = 0.5 + 0.5 * math.sin(boostPhase * 2 * math.pi);
      canvas.drawRRect(
          body.inflate(3 + 2 * s),
          Paint()
            ..color = PawMapLegend.boost.withValues(alpha: 0.55 + 0.25 * s)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 + 1.5 * s));
    } else {
      cssShadow(canvas, Path()..addRRect(body.inflate(2)),
          dy: 6,
          blur: 12,
          spread: -4,
          color: PawMapLegend.ink.withValues(alpha: 0.5));
    }
    canvas.drawRRect(body.inflate(2), Paint()..color = Colors.white);
    final tip = Path()
      ..moveTo(cx - 6, bodyBottom + 1)
      ..lineTo(cx + 6, bodyBottom + 1)
      ..lineTo(cx, bodyBottom + 8)
      ..close();
    canvas.drawPath(tip, Paint()..color = dark);
    canvas.drawRRect(
        body, Paint()..shader = cssLinear(bodyRect, 170, [light, dark]));
    final icon = walking ? PawGlyphs.msWalk : PawGlyphs.msHome;
    drawSvg(
        canvas,
        icon,
        Rect.fromLTWH(cx - w / 2 + pad, top + (h - 14) / 2, 14, 14),
        Colors.white);
    if (tp != null) {
      tp.paint(canvas,
          Offset(cx - w / 2 + pad + 14 + 4, top + (h - tp.height) / 2));
    }
    if (mineLabel != null && mineLabel.isNotEmpty) {
      _paintPill(canvas,
          text: mineLabel,
          cx: cx,
          top: top - 17,
          style: _pinStyle(10, FontWeight.w700, Colors.white),
          height: 16,
          padX: 7,
          bg: PawMapLegend.ink,
          shadowAlpha: 0);
    }
    if (boostPhase != null) {
      drawRocketBadge(canvas, Offset(cx - w / 2 - 1, bodyBottom - 2), 16);
    }
  }

  static double requestBubbleWidth({String? priceLabel, String? mineLabel}) =>
      math.max(_reqBodyW(priceLabel), _reqPillW(mineLabel)) + 4;

  static double requestBubbleBitmapWidth(
          {String? priceLabel, String? mineLabel}) =>
      requestBubbleWidth(priceLabel: priceLabel, mineLabel: mineLabel) + 16;
  static double requestBubbleBitmapHeight() =>
      PawMapLegend.requestBubbleHeight + 8 + 7 + 8;
}

/// Style de l'étiquette sous un rond photo (v592, pastilles du site).
enum PawPinLabelStyle { me, friend, lost, name }

/// Rendu d'un peintre en image PNG — partagé par la carte (BitmapDescriptor)
/// et par la légende « ? » / les tests (Image.memory).
/// v589 — Daniel : « que les icônes des utilisateurs apparaissent nettes, HD,
/// pas de flou ». On dessine à la densité RÉELLE de l'écran (bornée 2×–4×).
double pawPinRenderScale() {
  try {
    final views = ui.PlatformDispatcher.instance.views;
    final dpr = views.isEmpty ? 3.0 : views.first.devicePixelRatio;
    return dpr.clamp(2.0, 4.0).toDouble();
  } catch (_) {
    return 3.0;
  }
}

/// Dessine [paint] dans une image de [logicalW] × [logicalH] px logiques à
/// la densité [scale] (par défaut celle de l'écran). Les polices des
/// épingles sont chargées avant (texte net, jamais la police de repli).
Future<ui.Image> renderPinImage(
  double logicalW,
  double logicalH,
  void Function(Canvas canvas) paint, {
  double? scale,
}) async {
  await ensurePawPinFonts();
  final double sc = scale ?? pawPinRenderScale();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(sc, sc);
  paint(canvas);
  return recorder
      .endRecording()
      .toImage((logicalW * sc).ceil(), (logicalH * sc).ceil());
}

Future<Uint8List> renderPinPng(
  double logicalW,
  double logicalH,
  void Function(Canvas canvas) paint, {
  double? scale,
}) async {
  final img = await renderPinImage(logicalW, logicalH, paint, scale: scale);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return bytes!.buffer.asUint8List();
}

/// Décode une photo (bytes) en `ui.Image`, PLUS PETIT côté = [target] (le
/// recadrage « cover » se fait au dessin : jamais de visage écrasé).
// v589 — 320 px : une photo nette même à 4× (rond « Moi » 56 dp ≈ 224 px).
Future<ui.Image?> decodeAvatar(Uint8List? bytes, {int target = 320}) async {
  if (bytes == null || bytes.isEmpty) return null;
  try {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final codec = await ui.instantiateImageCodecWithSize(
      buffer,
      getTargetSize: (int w, int h) {
        if (w <= 0 || h <= 0) return ui.TargetImageSize(width: target);
        final shortest = math.min(w, h);
        if (shortest <= target) return ui.TargetImageSize(width: w, height: h);
        final k = target / shortest;
        return ui.TargetImageSize(
            width: (w * k).round(), height: (h * k).round());
      },
    );
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (_) {
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: target);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }
}

/// Cache des épingles de la carte (idée 10 : chaque épingle dessinée UNE fois
/// puis réutilisée). Clé = description complète de l'épingle. Les photos
/// (Moi, amis) sont téléchargées une fois et gardées en mémoire.
class PawMapPinCache extends GetxService {
  final Map<String, BitmapDescriptor> _cache = {};
  final Set<String> _building = {};
  final Map<String, ui.Image?> _avatars = {};
  final Map<String, int> _avatarFails = {};

  /// Incrémenté à chaque épingle prête → l'écran reconstruit ses marqueurs.
  final RxInt rev = 0.obs;

  @override
  void onInit() {
    super.onInit();
    // v592 — polices des épingles prêtes avant la première épingle.
    unawaited(ensurePawPinFonts());
  }

  BitmapDescriptor? peek(String key) => _cache[key];

  /// Renvoie l'épingle en cache, sinon lance sa construction et renvoie null
  /// (l'appelant pose un repli et sera prévenu par [rev]).
  BitmapDescriptor? getOrBuild(
    String key,
    double logicalW,
    double logicalH,
    void Function(Canvas canvas) paint,
  ) {
    final cached = _cache[key];
    if (cached != null) return cached;
    if (_building.add(key)) {
      unawaited(_build(key, logicalW, logicalH, paint));
    }
    return null;
  }

  Future<void> _build(String key, double w, double h,
      void Function(Canvas canvas) paint) async {
    try {
      final png = await renderPinPng(w, h, paint);
      _cache[key] = BitmapDescriptor.bytes(png, width: w);
      rev.value++;
    } catch (e) {
      debugPrint('[PawMapPinCache] $key : $e');
    } finally {
      _building.remove(key);
    }
  }

  /// Photo décodée d'un membre, ou null si pas (encore) disponible. Un
  /// téléchargement est lancé au premier appel ; [rev] bouge quand elle
  /// arrive. Trois échecs → on reste sur le glyphe blanc.
  ui.Image? avatarFor(String url) {
    if (url.isEmpty || !url.startsWith('http')) return null;
    if (_avatars.containsKey(url)) return _avatars[url];
    if ((_avatarFails[url] ?? 0) >= 3) return null;
    if (_building.add('avatar:$url')) {
      unawaited(_downloadAvatar(url));
    }
    return null;
  }

  Future<void> _downloadAvatar(String url) async {
    try {
      final resp = await http.get(
        Uri.parse(url),
        headers: const {'User-Agent': 'Mozilla/5.0 (HoPetSit)'},
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        _avatars[url] = await decodeAvatar(resp.bodyBytes);
        rev.value++;
        return;
      }
      _avatarFails[url] = (_avatarFails[url] ?? 0) + 1;
    } catch (_) {
      _avatarFails[url] = (_avatarFails[url] ?? 0) + 1;
    } finally {
      _building.remove('avatar:$url');
    }
  }

  /// Vide les épingles (pas les photos) — après un changement de langue ou
  /// de thème, les libellés doivent être redessinés.
  void invalidatePins() {
    _cache.clear();
    rev.value++;
  }
}
