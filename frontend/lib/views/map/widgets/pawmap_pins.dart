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
import 'dart:convert' show utf8;
import 'dart:io' show Directory, File, Platform;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart' show md5;
import 'package:get_storage/get_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../../utils/storage_keys.dart';

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
/// v605 — le halo d'un rond photo (un seul à la fois).
enum PawPhotoHalo { follow, boost, pawFollow, friend, me, none }

/// v605 (30/09) — Daniel : « t'es pas violet ». La personne que JE suis en
/// direct est TOUJOURS violette sur ma carte, même si elle a un PawBoost
/// (la fusée reste). Pour les autres : PawBoost > PawFollow > ami > moi.
/// Même règle sur le site (`photoPinHtml`, website/src/lib/pawmapLegend.ts).
PawPhotoHalo pickPhotoHalo({
  required bool boosted,
  required bool followed,
  bool pawFollowGlow = false,
  bool isFriend = false,
  bool isMe = false,
}) {
  if (followed) return PawPhotoHalo.follow;
  if (boosted) return PawPhotoHalo.boost;
  if (pawFollowGlow) return PawPhotoHalo.pawFollow;
  if (isFriend) return PawPhotoHalo.friend;
  if (isMe) return PawPhotoHalo.me;
  return PawPhotoHalo.none;
}

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
    // 630 (Daniel : « les halos bleu, turquoise et violet ne sont pas assez
    // voyants ») — valeurs du site de LEO : liseré BLANC 3 px, anneau PLEIN
    // 8 px (turquoise PawBoost / violet PawFollow), lueur large qui respire.
    if (color == PawMapLegend.pawFollow) {
      drawCssGlow(canvas, center, radius, m, color, [
        (8 + s, 0, 0.92),
        (8 + 2 * s, 22 + 6 * s, 0.6 + 0.15 * s),
      ]);
    } else {
      drawCssGlow(canvas, center, radius, m, color, [
        (8 + s, 0, 0.98),
        (8 + 4 * s, 24 + 8 * s, 0.8 + 0.1 * s),
      ]);
    }
    canvas.drawCircle(center, radius + 3, Paint()..color = Colors.white);
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

  /// 618 (PAM) — pin du classement sur le rond d'un membre, au MILIEU du
  /// bord gauche (seule place libre : couronne en haut à droite, coche en bas
  /// à droite, fusée en bas à gauche, point de statut en haut à gauche).
  /// [code] 1..3 = podium or / argent bleuté / bronze (chiffre), 4 = 1er Chef
  /// de meute (violet, patte dorée). Mêmes couleurs que `PawPinStyle618`.
  static void drawPin618(Canvas canvas, Offset center, int code, [double size = 16]) {
    if (code < 1 || code > 4) return;
    const fills = <int, List<Color>>{
      1: [Color(0xFFFFD86B), Color(0xFFD99A06)],
      2: [Color(0xFFD4E2F4), Color(0xFF7E9CC4)],
      3: [Color(0xFFF2B27A), Color(0xFFB0602A)],
      4: [Color(0xFFB58AF0), Color(0xFF6A2FB0)],
    };
    const inks = <int, Color>{
      1: Color(0xFF5A3C00),
      2: Color(0xFF1F3654),
      3: Color(0xFF4A2208),
    };
    final r = size / 2;
    final rect = Rect.fromCircle(center: center, radius: r);
    cssShadow(canvas, Path()..addOval(rect),
        dy: 1, blur: 3, color: PawMapLegend.ink.withValues(alpha: 0.35));
    canvas.drawCircle(center, r, Paint()..color = code == 4 ? const Color(0xFFFFC94A) : Colors.white);
    canvas.drawCircle(center, r - 1.5,
        Paint()..shader = cssLinear(rect.deflate(1.5), 135, fills[code]!));
    if (code == 4) {
      final g = size * 0.58;
      drawGlyph(canvas, PawGlyphs.paw(),
          Rect.fromCenter(center: center, width: g, height: g), const Color(0xFFFFE08A));
    } else {
      drawText(canvas, '$code', center, size * 0.58, inks[code]!, weight: FontWeight.w900);
    }
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

  /// 607 (02/10) — marge ADAPTÉE au rond : 22 seulement pour la lueur
  /// PawBoost ; couronne / sélection 17 ; sinon 11. Mesuré au simulateur :
  /// la réserve de textures du SDK Google Maps iOS déborde (« Reached the max
  /// number of texture atlases … Failed to allocate texture space for
  /// marker ») et les marqueurs sortent alors coupés net. Un rond simple
  /// passe de 90 × 90 à 68 × 68 : −43 % de pixels.
  static double memberMarginFor({bool boosted = false, bool crown = false, bool selected = false}) =>
      boosted ? memberMargin : ((crown || selected) ? 17 : 11);

  /// Hauteur réservée AU-DESSUS du rond pour la bulle de prix (22 de bulle +
  /// 6 de pointe + marges).
  static const double priceBubbleZone = 32;

  /// Taille d'un bitmap de membre (avec la marge basse pour l'étiquette et,
  /// v592, la zone de la bulle de prix au-dessus).
  static double memberBitmapSize(double size,
          {bool withLabel = false, bool withBubble = false, double margin = memberMargin}) =>
      size +
      2 * margin +
      // 607 — 18 (et non 12) : l'ombre du prénom (flou 6, décalage 2) était
      // coupée au bas de l'image.
      (withLabel ? 18 : 0) +
      (withBubble ? priceBubbleZone : 0);

  /// v605 (30/09) — largeur du bitmap d'un rond de membre SANS photo : la
  /// bulle de prix plus large que le rond (bulle duo « 20 €|12 € », prix à
  /// 4 chiffres) était ROGNÉE des deux côtés — la v592 n'élargissait que le
  /// rond photo. Le rond reste centré (ancre x = 0,5) ; décaler le dessin de
  /// `(largeur − memberBitmapSize(size)) / 2`.
  ///
  /// 607 (02/10, travail de fond « bulles ») — le PRÉNOM sous le rond
  /// (« Christine H. ★ 4,9 », jusqu'à 160 px) n'était pas compté : l'image
  /// faisait 90 px et le nom sortait coupé des deux côtés. La largeur est
  /// maintenant celle du plus large des trois (rond, bulle, prénom), ombres
  /// comprises.
  static double memberBitmapWidth(double size,
      {String? priceBubble, String? priceLabel, double rating = 0, double margin = memberMargin}) {
    var w = memberBitmapSize(size, margin: margin);
    if (priceBubble != null && priceBubble.isNotEmpty) {
      w = math.max(w, priceBubbleBitmapWidth(priceBubble));
    }
    if (priceLabel != null && priceLabel.isNotEmpty) {
      w = math.max(w, nameTagWidth(priceLabel, rating: rating) + 20);
    }
    return w;
  }

  /// 607 — largeur EXACTE de l'étiquette prénom/prix sous un rond de membre
  /// (même calcul que `_paintPill` : texte mesuré, note, plafond 160).
  static double nameTagWidth(String text, {double rating = 0}) {
    final style = _pinStyle(10.5, FontWeight.w600, const Color(0xFF1B1616));
    double extra = 0;
    if (rating > 0) {
      final rp = TextPainter(
        text: TextSpan(text: rating.toStringAsFixed(1), style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      extra = 4 + 10 + 1 + rp.width;
    }
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: math.max(10, 160 - 16 - extra));
    return tp.width + 16 + extra;
  }

  /// Ancre verticale (0..1) d'un rond de membre : le centre du cercle.
  static double memberAnchorY(double size,
      {bool withLabel = false, bool withBubble = false, double margin = memberMargin}) {
    final zone = withBubble ? priceBubbleZone : 0.0;
    return (zone + margin + size / 2) /
        memberBitmapSize(size, withLabel: withLabel, withBubble: withBubble, margin: margin);
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
    double margin = memberMargin,
    // 616 (PAM) — point de statut aussi HORS LIGNE (orange foncé plein) :
    // Daniel, 10/10 : « jamais la même pour tous ».
    bool offlineDot = false,
    int pin618 = 0, // 618 — pin du classement (0 = rien)
  }) {
    final bool withBubble = priceBubble != null && priceBubble.isNotEmpty;
    if (withBubble) {
      drawPriceBubble(canvas,
          cx: margin + size / 2,
          bottom: priceBubbleZone + margin - 3,
          text: priceBubble,
          role: role);
      canvas.save();
      canvas.translate(0, priceBubbleZone);
    }
    final r = size / 2;
    final c = Offset(margin + r, margin + r);
    final color = PawMapLegend.roleColor(role);
    final (light, dark) = PawMapLegend.ringGradient(color);
    final circle = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    if (boostPhase != null) {
      // 628 — l'ombre AVANT le halo : le liseré blanc du PawBoost reste blanc.
      cssShadow(canvas, circle,
          dy: 2, blur: 6, color: PawMapLegend.ink.withValues(alpha: 0.35));
      drawBoostGlow(canvas, c, r, boostPhase, maxR: r + margin - 0.5);
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
    // 609 (Daniel : « que ça leur donne un plus ») — coche « identité
    // vérifiée » EN BAS À DROITE (comme sur l'avatar de la fiche publique),
    // jamais cachée par la fusée PawBoost (en bas à gauche) ni la couronne
    // (en haut à droite). Le point « en ligne » passe alors en haut à gauche.
    if (online || offlineDot) {
      final s = (size * 12 / 46).roundToDouble();
      drawOnlineDot(canvas, pawOnlineDotCenter(c, r, s, verified: verified), s,
          online: online);
    }
    if (boostPhase != null) {
      drawRocketBadge(canvas, Offset(c.dx - (r + 5 - 9), c.dy + r + 5 - 9), 18);
    }
    if (verified) {
      drawVerifiedBadge(canvas, pawVerifiedBadgeCenter(c, r));
    }
    if (crown) {
      _crownAt(canvas, c, r, PawMapLegend.crownMember);
    }
    if (pin618 > 0) drawPin618(canvas, Offset(c.dx - r, c.dy), pin618);
    if (priceLabel != null && priceLabel.isNotEmpty) {
      _paintNameTag(canvas, priceLabel, c.dx, c.dy + r + 4, rating: rating);
    }
    if (withBubble) canvas.restore();
  }

  /// Couronne en haut à droite (site : top −35 %, right −30 % de sa taille).
  static void _crownAt(Canvas canvas, Offset c, double r, double s) {
    drawCrown(canvas, crownCenter(c, r, s), s);
  }

  /// Centre de la couronne (coin haut-droit du rond, comme le site).
  static Offset crownCenter(Offset c, double r, double s) {
    final top = (s * 0.35).roundToDouble();
    final right = (s * 0.3).roundToDouble();
    return Offset(c.dx + r + right - s / 2, c.dy - r - top + s / 2);
  }

  /// 607 (PAM, capture de Daniel du 01/10) — l'œil barré de « Moi » (mode
  /// amis seulement) était en BAS À GAUCHE, exactement là où se pose la fusée
  /// PawBoost : les deux pastilles s'empilaient sur la photo. Il passe sur
  /// l'anneau en bas à DROITE (40° sous l'horizontale) — place libre chez
  /// « Moi », qui n'a jamais le point « en ligne » —, à l'écart de la
  /// couronne (haut-droit), de la fusée (bas-gauche) et de l'étiquette
  /// « Moi » (dessous). Si un point « en ligne » occupe ce coin, il monte en
  /// HAUT À GAUCHE.
  static Offset eyeOffBadgeCenter(Offset c, double r, {bool online = false}) {
    const a = 40 * math.pi / 180;
    final dx = r * math.cos(a), dy = r * math.sin(a);
    return online ? Offset(c.dx - dx, c.dy - dy) : Offset(c.dx + dx, c.dy + dy);
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
  /// v594 — largeur de l'étiquette sous un rond photo (« Vu il y a 20 min »
  /// était coupée : plus large que l'image du rond).
  static double photoLabelWidth(String text) {
    final tp = TextPainter(
      text: TextSpan(
          text: text, style: _pinStyle(11, FontWeight.w700, Colors.white, inter: true)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return tp.width + 2 * 9.5 + 6;
  }

  /// 607 — largeur d'IMAGE nécessaire pour une bulle de prix : la bulle
  /// + son liseré blanc (2 × 2) + son ombre (flou 10, étalement −4 ≈ 7 de
  /// chaque côté). Avant : « + 8 » partout → bulles longues et duos coupés
  /// net à gauche et à droite (test pam607d : 44 px de bord touchés).
  static double priceBubbleBitmapWidth(String text) => priceBubbleWidth(text) + 20;

  /// v594 — largeur d'une bulle de prix ; « A|B » = bulle DUO gardien/promeneur.
  static double priceBubbleWidth(String text) {
    double w = 0;
    for (final part in text.split('|')) {
      final tp = TextPainter(
        text: TextSpan(
            text: part, style: _pinStyle(11.5, FontWeight.w700, Colors.white)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      w += 8 + 11 + 4 + tp.width + 8;
    }
    return w;
  }

  /// v594 — Daniel (26/09) : beaucoup créent gardien + promeneur. UNE bulle,
  /// moitié bleue « maison · prix gardien », moitié verte « balade · prix
  /// promeneur ». [text] = « 20 €|12 € ».
  static void _drawDuoPriceBubble(Canvas canvas,
      {required double cx, required double bottom, required String text}) {
    final parts = text.split('|');
    final tps = [
      for (final part in parts.take(2))
        TextPainter(
          text: TextSpan(
              text: part,
              style: _pinStyle(11.5, FontWeight.w700, Colors.white)),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(),
    ];
    const double h = 22;
    const double iconS = 11;
    const double gap = 4;
    final widths = [for (final tp in tps) 8 + iconS + gap + tp.width + 8];
    final double w = widths.fold(0.0, (a, b) => a + b);
    final double top = bottom - 6 - 1 - h;
    final body = Rect.fromLTWH(cx - w / 2, top, w, h);
    final rect = RRect.fromRectAndRadius(body, const Radius.circular(8));
    cssShadow(canvas, Path()..addRRect(rect.inflate(2)),
        dy: 5,
        blur: 10,
        spread: -4,
        color: PawMapLegend.ink.withValues(alpha: 0.45));
    canvas.drawRRect(rect.inflate(2), Paint()..color = Colors.white);
    final (sl, sd) = priceBubbleColors('sitter');
    final (wl, wd) = priceBubbleColors('walker');
    // Pointe sous le milieu : moitié bleue, moitié verte.
    canvas.drawPath(
        Path()
          ..moveTo(cx - 5, top + h + 1)
          ..lineTo(cx, top + h + 1)
          ..lineTo(cx, top + h + 7)
          ..close(),
        Paint()..color = sd);
    canvas.drawPath(
        Path()
          ..moveTo(cx, top + h + 1)
          ..lineTo(cx + 5, top + h + 1)
          ..lineTo(cx, top + h + 7)
          ..close(),
        Paint()..color = wd);
    canvas.save();
    canvas.clipRRect(rect);
    final left = Rect.fromLTWH(body.left, top, widths[0], h);
    final right = Rect.fromLTWH(body.left + widths[0], top, w - widths[0], h);
    canvas.drawRect(left, Paint()..shader = cssLinear(left, 170, [sl, sd]));
    canvas.drawRect(right, Paint()..shader = cssLinear(right, 170, [wl, wd]));
    canvas.restore();
    // Filet blanc entre les deux moitiés.
    canvas.drawLine(Offset(right.left, top + 4), Offset(right.left, top + h - 4),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..strokeWidth = 1);
    final icons = [PawGlyphs.msHome, PawGlyphs.msWalk];
    double x = body.left;
    for (var i = 0; i < tps.length; i++) {
      drawSvg(
          canvas,
          icons[i],
          Rect.fromCenter(
              center: Offset(x + 8 + iconS / 2, top + h / 2),
              width: iconS,
              height: iconS),
          Colors.white);
      tps[i].paint(canvas, Offset(x + 8 + iconS + gap, top + (h - tps[i].height) / 2));
      x += widths[i];
    }
  }

  static void drawPriceBubble(Canvas canvas,
      {required double cx,
      required double bottom,
      required String text,
      required String role}) {
    if (text.contains('|')) {
      _drawDuoPriceBubble(canvas, cx: cx, bottom: bottom, text: text);
      return;
    }
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
    double margin = photoMargin,
    // v598 (28/09) — étiquette AU-DESSUS du rond (ami tout près de « Moi » :
    // « Vu il y a … » reste lisible au lieu d'être masquée). Le rond descend
    // de [photoLabelExtra] pour lui laisser la place ; l'ancre suit
    // ([photoAnchorY] avec labelAbove).
    bool labelAbove = false,
    // 616 (PAM) — point de statut aussi hors ligne (orange foncé plein).
    bool offlineDot = false,
    int pin618 = 0, // 618 — pin du classement (0 = rien)
  }) {
    final bool withBubble = priceBubble != null && priceBubble.isNotEmpty;
    if (withBubble) {
      drawPriceBubble(canvas,
          cx: margin + size / 2,
          bottom: priceBubbleZone + margin - 3,
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
      margin: margin,
      labelAbove: labelAbove,
      offlineDot: offlineDot,
      pin618: pin618,
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
    double margin = photoMargin,
    bool labelAbove = false,
    bool offlineDot = false,
    int pin618 = 0,
  }) {
    final r = size / 2;
    final bool hasLabel = label != null && label.isNotEmpty;
    // v598 — étiquette au-dessus : le rond descend de la hauteur réservée à
    // l'étiquette (le bitmap garde la même taille, voir photoBitmapSize).
    final c = Offset(margin + r, margin + r + (labelAbove && hasLabel ? photoLabelZoneFor(margin) : 0));
    final bool isFriend = ringColor == PawMapLegend.friend;
    final bool isMe = !isFriend &&
        (dashedRing || eyeOff || size >= PawMapLegend.meSize);
    final double maxR = r + margin - 0.5;

    // Anneaux des autres rôles (site : `extraRoleRings`) — calculés AVANT le
    // halo : v594, Daniel (27/09) « quand il y a tous les halos, le PawBoost
    // de mon frère ne marche pas » : 3 anneaux (15 px) recouvraient la lueur,
    // qui partait du rond. Elle part maintenant du DERNIER anneau.
    // v597 — Daniel (27/09, validé) : plus d'anneaux de rôle EMPILÉS (ils
    // recouvraient la lueur PawBoost). Le CONTOUR de la photo porte les
    // rôles, comme le bouton « Profil » : 1 rôle = son dégradé, 2 ou 3 =
    // contour bicolore / tricolore, ordre fixe propriétaire → gardien →
    // promeneur. Un ami garde son halo ROSE, son contour = ses rôles.
    final roleSet = <Color>{...?ringColors};
    if (!isFriend) roleSet.add(ringColor);
    final List<Color> contour = [
      for (final k in const [PawMapLegend.owner, PawMapLegend.sitter, PawMapLegend.walker])
        if (roleSet.contains(k)) k,
    ];
    if (contour.isEmpty) contour.add(isFriend ? fallbackTint : ringColor);
    final double glowR = r;

    // 1. Halo : v605 — suivi en direct (la personne que JE suis) > PawBoost
    //    > PawFollow (famille) > ami > moi. Voir [pickPhotoHalo].
    final circle = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    final halo = pickPhotoHalo(
        boosted: boostPhase != null,
        followed: followPhase != null,
        pawFollowGlow: pawFollowGlow,
        isFriend: isFriend,
        isMe: isMe);
    if (halo == PawPhotoHalo.follow) {
      drawGlow(canvas, c, glowR, followPhase!, PawMapLegend.pawFollow, maxR: maxR);
    } else if (halo == PawPhotoHalo.boost) {
      // 628 — l'ombre AVANT le halo : le liseré blanc du PawBoost reste blanc.
      cssShadow(canvas, circle,
          dy: 2, blur: 6, color: PawMapLegend.ink.withValues(alpha: 0.35));
      drawBoostGlow(canvas, c, glowR, boostPhase!, maxR: maxR);
    } else if (pawFollowGlow) {
      // 630 — PawFollow (famille) : violet net + liseré blanc, comme le site.
      drawCssGlow(canvas, c, glowR, maxR, PawMapLegend.pawFollow,
          [(8, 0, 0.92), (8, 24, 0.7)]);
      canvas.drawCircle(c, r + 3, Paint()..color = Colors.white);
    } else if (isFriend) {
      // v594 — Daniel (26/09) : « le halo rose oui » (l'or non, la couronne
      // suffit). Lueur rose FIXE autour de chaque ami, sous PawBoost/suivi.
      drawCssGlow(canvas, c, glowR, maxR, PawMapLegend.friend,
          [(4, 0, 0.42), (6, 16, 0.62)]);
    } else if (isMe) {
      // Le site fait « pulser » un anneau autour de moi (`hps-pulse`) : sur
      // un bitmap fixe, un halo doux de la couleur de mon rôle.
      drawCssGlow(canvas, c, r, maxR, ringColor, [(2, 0, 0.18), (3, 14, 0.30)]);
    }

    // 2. (v597) plus d'anneaux de rôle sous le rond : voir `contour`.

    // 3. Ombre du rond (628 : déjà dessinée sous le halo PawBoost).
    if (halo == PawPhotoHalo.boost) {
      // rien : voir ci-dessus
    } else if (boostPhase != null || followPhase != null) {
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
    } else if (contour.length == 1) {
      final pair = PawMapLegend.ringGradient(contour.first);
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..shader = cssLinear(rect, 170,
                [_veil(pair.$1, dimmed), _veil(pair.$2, dimmed)]));
    } else {
      // Contour bi/tricolore : aplats nets, diagonale comme le site (135°).
      final n = contour.length;
      final colors = <Color>[];
      final stops = <double>[];
      for (var i = 0; i < n; i++) {
        final col = _veil(contour[i], dimmed);
        colors..add(col)..add(col);
        stops..add(i / n)..add((i + 1) / n);
      }
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..shader = ui.Gradient.linear(
                rect.topLeft, rect.bottomRight, colors, stops));
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
    // 616 — [offlineDot] : le point est aussi dessiné HORS LIGNE (orange
    // foncé plein), jamais la même pastille pour tout le monde.
    if (online || dimmed || offlineDot) {
      final s = (size * 13 / 50).roundToDouble();
      drawOnlineDot(canvas, pawOnlineDotCenter(c, r, s, verified: verified), s,
          online: online && !dimmed);
    }
    if (boostPhase != null) {
      final s = isMe ? 20.0 : 18.0;
      final b = (s * 0.25).roundToDouble(), l = (s * 0.3).roundToDouble();
      drawRocketBadge(
          canvas, Offset(c.dx - (r + l - s / 2), c.dy + r + b - s / 2), s);
    }
    // 609 — coche en bas à droite, jamais sous la fusée ni la couronne.
    if (verified) {
      drawVerifiedBadge(canvas, pawVerifiedBadgeCenter(c, r));
    }
    if (eyeOff) {
      drawEyeOffBadge(canvas, eyeOffBadgeCenter(c, r, online: online || dimmed || offlineDot), 20);
    }
    if (crown) {
      _crownAt(canvas, c, r, crownSize);
    }
    if (pin618 > 0) drawPin618(canvas, Offset(c.dx - r, c.dy), pin618);

    // 6. Étiquette sous le rond (v598 : ou au-dessus, [labelAbove]).
    if (label != null && label.isNotEmpty) {
      final style = labelStyle ??
          (isMe
              ? PawPinLabelStyle.me
              : isFriend
                  ? (dimmed ? PawPinLabelStyle.lost : PawPinLabelStyle.friend)
                  : PawPinLabelStyle.name);
      // Haut de la pastille : sous le rond (+3 / +4), ou au-dessus (sa
      // hauteur + 3 au-dessus de l'anneau).
      double top(double gap, double height) =>
          labelAbove ? c.dy - r - 3 - height : c.dy + r + gap;
      switch (style) {
        case PawPinLabelStyle.me:
          _paintPill(canvas,
              text: label,
              cx: c.dx,
              top: top(3, 16.3),
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
              top: top(3, 19.3),
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
          _paintNameTag(canvas, label, c.dx, top(4, 20));
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
  /// v598 (28/09) — marge SERRÉE des ronds photo SANS halo dans l'app : le
  /// rond nu (anneau, couronne, point « en ligne », ombre) n'occupe que ~9 dp
  /// au-delà de son rayon ; 6 dp de vide en moins de chaque côté = −24 % de
  /// pixels par rond dans la réserve de textures du SDK iOS (cause des ronds
  /// rognés), sans rien changer à l'image. Les ronds à halo gardent 30.
  static const double photoMarginTight = 16;
  /// 607 — rond photo SANS couronne, œil barré ni halo : 11 dp suffisent
  /// (anneau, point « en ligne », ombre) — test pam607d.
  static const double photoMarginBare = 11;
  // v594 — marge des ronds À HALO (ami, PawBoost, suivi, plusieurs rôles) :
  // la lueur doit dépasser les 3 anneaux de rôles (15 px). Les autres ronds
  // gardent 22 : Google compte toute l'image comme zone de toucher, une
  // marge plus grande rendait le 1er appui moins précis (Daniel, 27/09).
  static const double photoMarginGlow = 30;
  /// Hauteur ajoutée au bitmap pour l'étiquette (sous le rond, ou au-dessus
  /// avec `labelAbove` — v598). 10 → 14 (v598) : avec la marge serrée, la
  /// queue d'ombre de la pastille touchait le bord du bitmap.
  static const double photoLabelExtra = 14;
  static double photoBitmapSize(double size,
          {bool withLabel = false, double margin = photoMargin}) =>
      size + 2 * margin + (withLabel ? photoLabelZoneFor(margin) : 0);

  /// 607 — place de l'étiquette sous (ou au-dessus) d'un rond photo, en plus
  /// de la marge : l'étiquette + son ombre dépassent de 31 dp le bord du
  /// rond ; à marge 11 il faut donc 20 (et non 14).
  static double photoLabelZoneFor(double margin) =>
      margin >= photoMarginTight ? photoLabelExtra : math.max(photoLabelExtra, 31 - margin);

  /// Ancre verticale (0..1) d'un rond photo : le centre du cercle.
  /// v598 — [labelAbove] : l'étiquette est au-dessus, le rond est descendu
  /// de [photoLabelExtra] (voir `_paintPhotoDotBody`).
  static double photoAnchorY(double size,
      {bool withLabel = false,
      bool withBubble = false,
      double margin = photoMargin,
      bool labelAbove = false}) {
    final zone = withBubble ? priceBubbleZone : 0.0;
    final double shift = withLabel && labelAbove ? photoLabelZoneFor(margin) : 0.0;
    return (zone + shift + margin + size / 2) /
        (photoBitmapSize(size, withLabel: withLabel, margin: margin) + zone);
  }

  // ── GROUPES ────────────────────────────────────────────────────────────

  /// 616 (PAM, demande Daniel 14/10 « quesitos du Trivial ») — parts d'un
  /// rond de regroupement : une part par rôle PRÉSENT (propriétaire →
  /// gardien → promeneur), proportionnelle à l'effectif. Un seul rôle (ou
  /// pas de détail) = une seule part pleine. Pure, testée (pam616).
  static List<({String role, double share})> memberClusterSlices(
      Map<String, int>? roleCounts, int count) {
    final out = <({String role, double share})>[];
    if (roleCounts != null) {
      var total = 0;
      for (final k in const ['owner', 'sitter', 'walker']) {
        total += math.max(0, roleCounts[k] ?? 0);
      }
      if (total > 0) {
        for (final k in const ['owner', 'sitter', 'walker']) {
          final v = math.max(0, roleCounts[k] ?? 0);
          if (v > 0) out.add((role: k, share: v / total));
        }
      }
    }
    if (out.isEmpty) out.add((role: 'sitter', share: 1.0));
    return out;
  }

  /// Rayon de la pastille blanche au centre d'un rond de groupe.
  static double memberClusterBadgeRadius(int count) =>
      count > 99 ? 13.5 : (count >= 10 ? 12.5 : 11.5);

  /// Groupe de MEMBRES (site : `memberClusterHtml`, 25/09) : un ROND plein,
  /// liseré blanc 2,5 ; fin anneau rose s'il contient un ami. Jamais un carré.
  /// 616 — le rond est découpé en PARTS aux couleurs des rôles présents
  /// (proportionnelles aux effectifs, `memberClusterSlices`) ; un seul rôle
  /// = rond uni au dégradé 160° du rôle. Le nombre est posé sur une pastille
  /// blanche au centre, à la couleur foncée du rôle dominant.
  /// 622 (parité site) — étiquette « dès X » sous un rond de groupe : hauteur
  /// et largeur de la pastille, et taille de l'image qui la contient.
  static const double clusterPriceH622 = 18;
  static double clusterPriceW622(String text) => _estTextW(text, 10) + 16;
  static Size memberClusterBitmap622(int count, String? priceLabel) {
    final base = memberClusterWidth(count) + 12;
    if (priceLabel == null || priceLabel.isEmpty) return Size(base, base);
    return Size(math.max(base, clusterPriceW622(priceLabel) + 8),
        base + clusterPriceH622 + 2);
  }

  static void paintMemberCluster(Canvas canvas, int count,
      {Map<String, int>? roleCounts,
      bool hasFriend = false,
      String? priceLabel,
      String priceRole = 'sitter'}) {
    final label = count > 99 ? '99+' : '$count';
    final slices = memberClusterSlices(roleCounts, count);
    String dom = slices.first.role;
    var best = -1.0;
    for (final sl in slices) {
      if (sl.share > best) {
        best = sl.share;
        dom = sl.role;
      }
    }
    final double size = count >= 10 ? 44 : 40;
    final box = memberClusterWidth(count);
    final bmp = memberClusterBitmap622(count, priceLabel);
    final c = Offset(bmp.width / 2, 6 + box / 2);
    final r = size / 2;
    final circle = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    cssShadow(canvas, circle,
        dy: 3, blur: 8, color: PawMapLegend.ink.withValues(alpha: 0.35));
    if (hasFriend) {
      canvas.drawCircle(c, r + 2.5, Paint()..color = PawMapLegend.friend);
    }
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    final inner = r - 2.5;
    if (slices.length == 1) {
      canvas.drawCircle(
          c,
          inner,
          Paint()
            ..shader = cssLinear(rect, 160,
                [PawMapLegend.roleColor(dom), PawMapLegend.roleDark(dom)]));
    } else {
      // Parts : départ à midi, sens horaire, propriétaire → gardien → promeneur.
      final arcRect = Rect.fromCircle(center: c, radius: inner);
      var start = -math.pi / 2;
      for (final sl in slices) {
        final sweep = 2 * math.pi * sl.share;
        canvas.drawArc(arcRect, start, sweep, true,
            Paint()..color = PawMapLegend.roleColor(sl.role));
        start += sweep;
      }
      // Fins traits blancs entre les parts (lisibilité, comme un camembert).
      start = -math.pi / 2;
      final sep = Paint()
        ..color = Colors.white
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      for (final sl in slices) {
        canvas.drawLine(
            c,
            Offset(c.dx + inner * math.cos(start), c.dy + inner * math.sin(start)),
            sep);
        start += 2 * math.pi * sl.share;
      }
    }
    // Pastille blanche + nombre à la couleur foncée du rôle dominant.
    final br = memberClusterBadgeRadius(count);
    canvas.drawCircle(c, br, Paint()..color = Colors.white);
    drawText(canvas, label, c, label.length > 2 ? 10 : 12,
        PawMapLegend.roleDark(dom));
    // 622 — « dès 12 €/jour » sous le rond, pastille PLEINE à la couleur du
    // rôle (bleu gardien / vert promeneur), texte blanc : jamais de gris.
    if (priceLabel != null && priceLabel.isNotEmpty) {
      _paintPill(canvas,
          text: priceLabel,
          cx: c.dx,
          top: 6 + box + 2,
          style: _pinStyle(10, FontWeight.w800, Colors.white),
          height: clusterPriceH622,
          padX: 8,
          bg: PawMapLegend.roleColor(priceRole),
          border: Colors.white,
          borderW: 1.5,
          shadowAlpha: 0.25);
    }
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
  // v597 — Daniel (27/09, capture) : « sur les PawSpots il n'y a pas le nom,
  // sur le web oui ». Étiquette du site : fond #171212, contour or 1,5,
  // texte or #F5C542 Poppins 700 10, sous la pointe, 150 px max.
  static const double spotLabelZone = 22;
  static double spotLabelWidth(String text) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: _pinStyle(10, FontWeight.w700, Colors.white)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    // 607 — + 12 (et non + 4) : l'ombre du nom (flou 4) sortait de l'image
    // pour un nom au plafond de 150 px (coupé net, test pam607d).
    return math.min(150, tp.width + 2 * 7 + 3) + 12;
  }

  static void paintPawSpotLabel(Canvas canvas,
      {required String label, required double cx, required double top}) {
    _paintPill(canvas,
        text: label,
        cx: cx,
        top: top,
        style: _pinStyle(10, FontWeight.w700, const Color(0xFFF5C542), height: 1.25),
        height: 17.5,
        padX: 7,
        bg: const Color(0xFF171212),
        border: const Color(0xFFF0B323),
        borderW: 1.5,
        shadowAlpha: 0.3,
        maxWidth: 150);
  }

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
  // 622 — largeur MESURÉE du prix (TextPainter, même style que le dessin) :
  // l'estimation surévaluait « dès 10 €/jour » de ~25 px, la bulle prenait
  // de la place pour rien dans le placement.
  static final Map<String, double> _reqTextW622 = <String, double>{};
  static double _reqPriceW(String price) => _reqTextW622.putIfAbsent(price, () {
        try {
          final tp = TextPainter(
            text: TextSpan(text: price, style: _pinStyle(12, FontWeight.w700, Colors.white)),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout();
          return tp.width.ceilToDouble();
        } catch (_) {
          return _estTextW(price, 12);
        }
      });
  static double _reqBodyW(String? price) => (price == null || price.isEmpty)
      ? 28
      : 9 + 14 + 4 + _reqPriceW(price) + 9;
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
      String? mineLabel,
      int count = 1}) {
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
    // 622 (PAM, 25/10 — Daniel : « plusieurs pins maison au même endroit
    // s'empilent en paquet illisible ») — un GROUPE de demandes = une seule
    // bulle + pastille ENCRE au chiffre, posée DANS la marge de l'image (rien
    // ne dépasse sur la bulle voisine).
    if (count > 1) {
      final c = Offset(bodyRect.right - 2, top + 2);
      const r = 8.5;
      canvas.drawCircle(c, r + 1.5, Paint()..color = Colors.white);
      canvas.drawCircle(c, r, Paint()..color = PawMapLegend.ink);
      final ctp = TextPainter(
        text: TextSpan(
            text: count > 99 ? '99+' : '$count',
            style: _pinStyle(count > 9 ? 8.5 : 10, FontWeight.w800, Colors.white)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      ctp.paint(canvas, c - Offset(ctp.width / 2, ctp.height / 2));
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

/// 607 (02/10) — densité des ronds de MEMBRES (les plus nombreux : 81 sur
/// 111 marqueurs à Paris zoom 13, 5,0 des 5,6 mégapixels de textures).
/// iOS : 2× (au lieu de 2,5×) — la réserve de textures du SDK Google Maps
/// iOS débordait (« Reached the max number of texture atlases », mesuré au
/// simulateur) et des marqueurs sortaient coupés net. Moi, amis, groupes :
/// densité de l'écran inchangée. Android : inchangé.
double pawMemberPinScale() =>
    defaultTargetPlatform == TargetPlatform.iOS ? 2.0 : pawPinRenderScale();

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
    // v598 (28/09) — iOS : 2,5× au lieu de 3×. Le SDK Google Maps iOS range
    // chaque image de marqueur dans une réserve de textures limitée (journal
    // « Reached the max number of texture atlases ») ; à 3× les ~80 ronds de
    // Paris la remplissaient à chaque changement d'image et sortaient ROGNÉS.
    // −31 % de pixels par rond, le plugin ne redessine pas (il ajuste l'échelle
    // de l'UIImage) : rendu quasi identique, réserve qui respire. Android : 3×.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return dpr.clamp(2.0, 2.5).toDouble();
    }
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
/// 607 — PNG 1 × 1 entièrement transparent (67 octets).
final Uint8List kPawTransparentPng = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// 612 — journal de MESURE (build `--dart-define=HPS_PROBE603=true`
/// seulement, jamais dans les stores) : durée de chaque image d'épingle.
const bool _kProbe612 = bool.fromEnvironment('HPS_PROBE603', defaultValue: false);

class PawMapPinCache extends GetxService {
  final Map<String, BitmapDescriptor> _cache = {};
  final Set<String> _building = {};
  final Map<String, ui.Image?> _avatars = {};
  final Map<String, int> _avatarFails = {};

  /// Incrémenté à chaque épingle prête → l'écran reconstruit ses marqueurs.
  final RxInt rev = 0.obs;

  /// 607 (PAM, 02/10) — Daniel : « des mini-lags ». Chaque épingle prête
  /// incrémentait [rev] tout de suite : 80 ronds redessinés après un zoom =
  /// 80 reconstructions complètes de la carte, l'une après l'autre (mesuré :
  /// 24 à 31 reconstructions par parcours). Les épingles prêtes dans la même
  /// fenêtre de 48 ms ne déclenchent plus qu'UNE reconstruction.
  Timer? _revTimer;
  static final bool _inTests = Platform.environment.containsKey('FLUTTER_TEST');
  void _bumpRev() {
    if (_inTests) {
      rev.value++;
      return;
    }
    if (_revTimer != null) return;
    _revTimer = Timer(const Duration(milliseconds: 48), () {
      _revTimer = null;
      rev.value++;
    });
  }

  /// 607 — taille logique (px) de chaque image d'épingle produite ici, pour
  /// la passe de mise en page (`pawResolveCollisions`). Null = inconnue.
  static final Expando<Size> _sizes = Expando<Size>('pawPinSize');
  static Size? sizeOf(BitmapDescriptor d) => _sizes[d];
  static void rememberSize(BitmapDescriptor d, Size s) => _sizes[d] = s;

  /// 607 — image VIDE (1 × 1 transparent) posée le temps qu'une épingle se
  /// dessine, à la place de l'épingle Google rose/orange qui « clignotait »
  /// avant le vrai rond.
  static final BitmapDescriptor transparent =
      BitmapDescriptor.bytes(kPawTransparentPng, width: 1, height: 1);

  @override
  void onInit() {
    super.onInit();
    // v592 — polices des épingles prêtes avant la première épingle.
    unawaited(ensurePawPinFonts());
    // 639 — pastilles v2 les plus courantes dessinées dès le lancement.
    if (!_inTests) {
      unawaited(ensurePawPinFonts().then((_) => prewarm639()));
    }
    // v597 — Daniel (27/09) : « ma photo orange, puis ma photo de profil
    // charge : micro-lag ». Ma photo est demandée DÈS le lancement (la PawMap
    // est construite au démarrage), et relue depuis le disque (plus de
    // téléchargement à chaque ouverture de l'app).
    try {
      final profile =
          GetStorage().read<Map<String, dynamic>>(StorageKeys.userProfile);
      final raw = profile?['avatar'];
      final url = raw is Map ? (raw['url'] ?? '').toString() : (raw ?? '').toString();
      if (url.isNotEmpty) avatarFor(url);
    } catch (_) {/* pas de profil en mémoire : rien à précharger */}
  }

  static Directory? _diskDir;
  Future<File?> _diskFile(String url) async {
    try {
      _diskDir ??= Directory('${(await getTemporaryDirectory()).path}/pawmap_avatars');
      final d = _diskDir!;
      if (!await d.exists()) await d.create(recursive: true);
      return File('${d.path}/${md5.convert(utf8.encode(url))}.img');
    } catch (_) {
      return null;
    }
  }

  BitmapDescriptor? peek(String key) => _cache[key];

  /// Renvoie l'épingle en cache, sinon lance sa construction et renvoie null
  /// (l'appelant pose un repli et sera prévenu par [rev]).
  BitmapDescriptor? getOrBuild(
    String key,
    double logicalW,
    double logicalH,
    void Function(Canvas canvas) paint, {
    // v594 — « les bulles de prix s'affichent une fois sur deux » : en
    // passant le seuil de zoom, chaque épingle change d'image et, le temps
    // du dessin, la carte montrait une épingle Google rose. Avec [slot]
    // (un marqueur), on garde sa DERNIÈRE image jusqu'à la nouvelle.
    String? slot,
    // 607 — densité de rendu propre à cette image (null = écran).
    double? scale,
  }) {
    final cached = _cache[key];
    if (cached != null) {
      if (slot != null) _lastBySlot[slot] = cached;
      return cached;
    }
    if (_building.add(key)) {
      unawaited(_build(key, logicalW, logicalH, paint, scale));
    }
    return slot == null ? null : _lastBySlot[slot];
  }

  final Map<String, BitmapDescriptor> _lastBySlot = {};

  /// 639 — image d'une pastille v2 (clé = [PawPinSpec639.key]). Toutes les
  /// personnes dans le même état partagent UNE image.
  BitmapDescriptor? pin639(PawPinSpec639 s, {String? slot}) {
    final sz = pawPinBitmap639(s);
    return getOrBuild(s.key, sz.width, sz.height, (c) => paintPin639(c, s),
        slot: slot, scale: pawMemberPinScale());
  }

  /// 639 — pré-rendu des pastilles les plus courantes (7 combinaisons de
  /// rôles, avec et sans couronne) : prêtes avant la première épingle.
  /// Renvoie le nombre d'images demandées.
  int prewarm639() {
    var n = 0;
    for (final roles in kPawPrewarmRoles639) {
      for (final premium in const [false, true]) {
        pin639(PawPinSpec639(roles: roles, premium: premium));
        n++;
      }
    }
    return n;
  }

  // ── 612 (mesuré sur émulateur Android, carte chargée : 100 membres,
  // 50 PawSpots) — à l'ouverture, ~80 images d'épingles étaient dessinées
  // TOUTES EN MÊME TEMPS (jusqu'à 89 en cours, 2 s pour la plus lente), à
  // CHAQUE lancement de l'app, et la carte était reconstruite 6 fois en
  // 1,2 s. Désormais :
  // chaque image prête est gardée SUR DISQUE (dossier temporaire, par
  // version de l'app et densité d'écran) : aux ouvertures suivantes elle est
  // relue, pas redessinée.
  // ESSAYÉ ET RETIRÉ (mesuré) : limiter à 6 dessins à la fois + une
  // reconstruction toutes les 160 ms — 60 épingles prêtes en 2,5 s au lieu de
  // 0,3 s. Les dessins restent donc tous lancés en parallèle.
  int _running = 0;

  static Directory? _pinDir;
  static bool _pinDirTried = false;
  Future<Directory?> _pinDiskDir() async {
    if (_inTests) return null;
    if (_pinDirTried) return _pinDir;
    _pinDirTried = true;
    try {
      final info = await PackageInfo.fromPlatform();
      final root = Directory('${(await getTemporaryDirectory()).path}/pawmap_pins');
      final name = 'v${info.buildNumber}_${pawPinRenderScale().toStringAsFixed(2)}';
      final d = Directory('${root.path}/$name');
      if (!await d.exists()) {
        // Autre version de l'app (dessins peut-être changés) : on repart de zéro.
        if (await root.exists()) await root.delete(recursive: true);
        await d.create(recursive: true);
      }
      _pinDir = d;
    } catch (_) {
      _pinDir = null;
    }
    return _pinDir;
  }

  Future<void> _build(String key, double w, double h,
      void Function(Canvas canvas) paint, [double? scale]) async {
    await _buildNow(key, w, h, paint, scale);
  }

  Future<void> _buildNow(String key, double w, double h,
      void Function(Canvas canvas) paint, [double? scale]) async {
    _running++;
    final int t0 = _kProbe612 ? DateTime.now().millisecondsSinceEpoch : 0;
    try {
      Uint8List? png;
      var fromDisk = false;
      File? file;
      final dir = await _pinDiskDir();
      if (dir != null) {
        file = File('${dir.path}/${md5.convert(utf8.encode('$key|$w|$h|${scale ?? 0}'))}.png');
        try {
          if (await file.exists()) {
            final b = await file.readAsBytes();
            if (b.length > 60) {
              png = b;
              fromDisk = true;
            }
          }
        } catch (_) {/* fichier abîmé : on redessine */}
      }
      png ??= await renderPinPng(w, h, paint, scale: scale);
      if (!fromDisk && file != null) {
        unawaited(file.writeAsBytes(png, flush: false).then((_) {}, onError: (_) {}));
      }
      if (_kProbe612) {
        // ignore: avoid_print
        print('[P603] ${DateTime.now().millisecondsSinceEpoch} PIN '
            '${DateTime.now().millisecondsSinceEpoch - t0}ms en_cours=$_running '
            '${key.split(':').first} ${png.length}o ${fromDisk ? 'disque' : 'dessin'}');
      }
      final d = BitmapDescriptor.bytes(png, width: w);
      _sizes[d] = Size(w, h); // 607 — taille logique (mise en page)
      _cache[key] = d;
      _bumpRev();
    } catch (e) {
      debugPrint('[PawMapPinCache] $key : $e');
    } finally {
      _building.remove(key);
      _running--;
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
    // v597 — copie disque (l'URL change quand la photo change : clé sûre).
    final int t0 = _kProbe612 ? DateTime.now().millisecondsSinceEpoch : 0;
    final file = await _diskFile(url);
    try {
      if (file != null && await file.exists()) {
        final img = await decodeAvatar(await file.readAsBytes());
        if (img != null) {
          if (_kProbe612) {
            // ignore: avoid_print
            print('[P603] ${DateTime.now().millisecondsSinceEpoch} PHOTO disque '
                '${DateTime.now().millisecondsSinceEpoch - t0}ms');
          }
          _avatars[url] = img;
          _bumpRev();
          _building.remove('avatar:$url');
          return;
        }
      }
    } catch (_) {/* copie abîmée : on retélécharge */}
    try {
      final resp = await http.get(
        Uri.parse(url),
        headers: const {'User-Agent': 'Mozilla/5.0 (HoPetSit)'},
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        _avatars[url] = await decodeAvatar(resp.bodyBytes);
        if (_kProbe612) {
          // ignore: avoid_print
          print('[P603] ${DateTime.now().millisecondsSinceEpoch} PHOTO reseau '
              '${DateTime.now().millisecondsSinceEpoch - t0}ms');
        }
        _bumpRev();
        if (file != null && _avatars[url] != null) {
          unawaited(file.writeAsBytes(resp.bodyBytes, flush: false).then((_) {}, onError: (_) {}));
        }
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

/// 609 — centre de la coche « identité vérifiée » : en bas à DROITE du rond
/// (symétrique de la fusée PawBoost, en bas à gauche).
Offset pawVerifiedBadgeCenter(Offset c, double r, [double size = 15]) =>
    Offset(c.dx + (r + 2 - size / 2), c.dy + r + 1 - size / 2);

/// 609 — point « en ligne » : en bas à droite, ou en HAUT À GAUCHE quand la
/// coche « vérifiée » occupe le bas à droite (jamais l'un sur l'autre).
Offset pawOnlineDotCenter(Offset c, double r, double s, {bool verified = false}) =>
    verified
        ? Offset(c.dx - r + s / 2, c.dy - r + s / 2)
        : Offset(c.dx + r - s / 2, c.dy + r - s / 2);

// ═══════════════════════════════════════════════════════════════════════════
// 639 — PASTILLES v2 (maquette docs/design_handoff_pawmap_pastilles_v2)
// ═══════════════════════════════════════════════════════════════════════════
// Une pastille de 32 pt, pleine couleur, sans anneau blanc ; halos fins,
// petits badges, groupes blancs à anneau partagé, bulle de prix claire.
// Tout est PUR (aucun état, aucune donnée) : la carte fabrique une
// [PawPinSpec639], la met en cache par sa [PawPinSpec639.key], et l'ancre
// EXACTEMENT sur le centre du disque ([pawPinAnchor639]).
// Les couleurs de cette section ne servent QUE sur la carte (CONTRATS §6).

/// Interrupteur du dessin v2 sur la carte. `false` = retour aux ronds à
/// anneau d'avant le 639 (pawmap_ring2610.dart), sans autre changement.
const bool kPawPins639 = bool.fromEnvironment('PAWMAP_PINS_V2', defaultValue: true);

/// Amis (hors « en direct ») en pastille v2 + halo fuchsia + cœur, comme la
/// maquette. `false` = retour aux ronds photo d'avant le 639.
const bool kPawFriendPastille639 = true;

/// La coche « identité vérifiée » n'existe pas dans la maquette v2 : elle
/// n'est plus dessinée sur la pastille (elle reste dans la fiche au toucher).
/// `true` = la redessiner (petit rond bleu en bas à droite).
const bool kPawPinVerified639 = false;

/// Images de l'onde PawFollow (1,8 s ÷ 6 = la minuterie 300 ms de la carte).
const int kPawWaveSteps639 = 6;

/// Rayon du disque et du halo, en points.
const double kPawPinDiscR639 = 16;
const double kPawPinHaloR639 = 21.5;

/// Couleurs et icônes des pastilles v2 — CARTE UNIQUEMENT.
class PawPin639 {
  PawPin639._();

  static const Color owner = Color(0xFFFF3A0F);
  static const Color ownerLight = Color(0xFFFF7A52);
  static const Color sitter = Color(0xFF0F62FF);
  static const Color sitterLight = Color(0xFF5EA0FF);
  static const Color walker = Color(0xFF00C24A);
  static const Color walkerLight = Color(0xFF3FD476);

  static const Color boost = Color(0xFF12D8C9);
  static const Color boostInk = Color(0xFF003D38);
  static const Color follow = Color(0xFF8F5CFF);
  static const Color friend = Color(0xFFFF5AD2);
  static const Color heartA = Color(0xFFF73CC0);
  static const Color heartB = Color(0xFFD9159F);
  static const Color gold = Color(0xFFF6B400);
  static const Color goldInk = Color(0xFF6B3A00);
  static const Color live = Color(0xFFE8452F);
  static const Color available = Color(0xFF1FE074);
  static const Color verified = Color(0xFF0F62FF);
  static const Color note = Color(0xFFFFC526);
  static const Color noteInk = Color(0xFF3D2600);

  // Maquette : #262123 et #7a6f71. Décalés d'un ou deux points vers le
  // chaud (#262021, #7c6d70) : règle « zéro gris » de l'app.
  static Color surface(bool dark) =>
      dark ? const Color(0xFF262021) : const Color(0xFFFFFFFF);
  static Color text(bool dark) =>
      dark ? const Color(0xFFF6EFEC) : const Color(0xFF1D1719);
  static Color muted(bool dark) =>
      dark ? const Color(0xFFA99C9E) : const Color(0xFF7C6D70);
  static Color edge(bool dark) =>
      dark ? const Color(0x38FFFFFF) : const Color(0x12000000);
  static Color line(bool dark) =>
      dark ? const Color(0x2EFFFFFF) : const Color(0x24000000);

  /// Ordre fixe des rôles (camembert, mini-pastilles).
  static const List<String> order = <String>['owner', 'sitter', 'walker'];

  static Color role(String r) {
    switch (r) {
      case 'sitter':
        return sitter;
      case 'walker':
        return walker;
      default:
        return owner;
    }
  }

  static Color roleLight(String r) {
    switch (r) {
      case 'sitter':
        return sitterLight;
      case 'walker':
        return walkerLight;
      default:
        return ownerLight;
    }
  }

  // Police figée des boutons de la carte (assets/pawsymbols) : pets / home /
  // directions_walk — les mêmes pictos que la maquette.
  static const IconData pets = IconData(0xe91d, fontFamily: 'PawSymbols');
  static const IconData home = IconData(0xe9b2, fontFamily: 'PawSymbols');
  static const IconData walk = IconData(0xe536, fontFamily: 'PawSymbols');

  static IconData icon(String r) {
    switch (r) {
      case 'sitter':
        return home;
      case 'walker':
        return walk;
      default:
        return pets;
    }
  }

  static Color halo(PawHalo639 h) {
    switch (h) {
      case PawHalo639.boost:
        return boost;
      case PawHalo639.follow:
        return follow;
      case PawHalo639.friend:
        return friend;
      case PawHalo639.none:
        return const Color(0x00000000);
    }
  }
}

/// Le halo d'une pastille v2 — UN SEUL à la fois.
enum PawHalo639 { none, boost, follow, friend }

/// Priorité inchangée (c'est [pickPhotoHalo] qui tranche) : suivi en direct
/// → PawBoost → PawFollow → Ami. Le suivi en direct et PawFollow partagent
/// le halo violet.
PawHalo639 pawHalo639({
  required bool boosted,
  bool followed = false,
  bool pawFollow = false,
  bool isFriend = false,
}) {
  switch (pickPhotoHalo(
      boosted: boosted,
      followed: followed,
      pawFollowGlow: pawFollow,
      isFriend: isFriend)) {
    case PawPhotoHalo.follow:
    case PawPhotoHalo.pawFollow:
      return PawHalo639.follow;
    case PawPhotoHalo.boost:
      return PawHalo639.boost;
    case PawPhotoHalo.friend:
      return PawHalo639.friend;
    case PawPhotoHalo.me:
    case PawPhotoHalo.none:
      return PawHalo639.none;
  }
}

/// Rôles d'une pastille : connus, sans doublon, dans l'ordre fixe.
List<String> pawPinRoles639(Iterable<String> roles) {
  final set = <String>{for (final r in roles) r.trim().toLowerCase()};
  final out = <String>[
    for (final r in PawPin639.order)
      if (set.contains(r)) r,
  ];
  return out.isEmpty ? const <String>['owner'] : out;
}

/// Point vert « disponible aujourd'hui » : UNIQUEMENT quand le serveur envoie
/// `availableDot == true` ET que la personne est gardien ou promeneur.
/// Champ absent (ancien serveur) = pas de point. `availableToday` n'est
/// jamais lu ici (il sert au filtre).
bool pawAvailableDot639(Map<dynamic, dynamic> p, Iterable<String> roles) =>
    p['availableDot'] == true &&
    roles.any((r) => r == 'sitter' || r == 'walker');

/// Les 7 combinaisons de rôles d'une personne (pré-rendu du cache).
const List<List<String>> kPawPrewarmRoles639 = <List<String>>[
  ['owner'],
  ['sitter'],
  ['walker'],
  ['owner', 'sitter'],
  ['owner', 'walker'],
  ['sitter', 'walker'],
  ['owner', 'sitter', 'walker'],
];

/// Tout ce qui décide du dessin d'une pastille v2.
@immutable
class PawPinSpec639 {
  PawPinSpec639({
    required Iterable<String> roles,
    this.halo = PawHalo639.none,
    this.premium = false,
    this.live = false,
    bool available = false,
    this.selected = false,
    bool verified = false,
    double scale = 1,
    int wave = -1,
    this.caption = '',
    this.captionAbove = false,
    this.captionColor = const Color(0xFFB8128F),
  })  : roles = pawPinRoles639(roles),
        scale = (scale * 100).round() / 100,
        wave = halo == PawHalo639.follow && wave >= 0
            ? wave % kPawWaveSteps639
            : -1,
        verified = verified && kPawPinVerified639,
        available = available &&
            roles.any((r) {
              final k = r.trim().toLowerCase();
              return k == 'sitter' || k == 'walker';
            });

  final List<String> roles;
  final PawHalo639 halo;
  final bool premium;

  /// Point rouge « en direct » (bas-droite).
  final bool live;

  /// Point vert « disponible aujourd'hui » (bas-gauche).
  final bool available;

  /// Pastille touchée : pointe sous le disque (mono-rôle).
  final bool selected;
  final bool verified;

  /// Échelle de sélection (1 → 1,18), arrondie au centième.
  final double scale;

  /// Image de l'onde PawFollow (0..5), −1 = pas d'onde.
  final int wave;

  /// Étiquette d'un ami (« Vu il y a… ») — dessinée hors échelle.
  final String caption;
  final bool captionAbove;
  final Color captionColor;

  bool get multi => roles.length > 1;
  bool get tip => selected && !multi;

  /// Clé de cache : deux specs de même clé donnent la même image.
  String get key => 'pin639:${roles.map((r) => r[0]).join()}:h${halo.index}:'
      '${premium ? 1 : 0}${live ? 1 : 0}${available ? 1 : 0}'
      '${selected ? 1 : 0}${verified ? 1 : 0}:$scale:w$wave:'
      '${captionAbove ? 'a' : 'b'}${captionColor.toARGB32()}:$caption';
}

double _capW639(String caption) =>
    math.min(160.0, PawMapPinPainter.photoLabelWidth(caption) - 6);

const double _kCapH639 = 19.3;

/// Rayon au-delà duquel l'étiquette d'une pastille se pose (3 pt plus loin) :
/// le halo ; dessous, le bas des mini-pastilles d'un multi-rôle.
double pawPinCaptionR639(bool multi, {bool above = false}) =>
    multi && !above ? 25.5 : kPawPinHaloR639 + 0.5;

/// Géométrie de l'image d'une pastille : taille en points ENTIERS PAIRS et
/// centre du disque à des coordonnées ENTIÈRES — l'ancre tombe au pixel.
({double w, double h, double cx, double cy}) pawPinLayout639(PawPinSpec639 s) {
  // Étendues depuis le centre du disque, à l'échelle 1.
  double side = 20, top = 19, bottom = 21;
  if (s.multi) {
    bottom = 28;
    if (s.roles.length > 2) side = 25;
  }
  if (s.tip) bottom = math.max(bottom, 23);
  if (s.halo != PawHalo639.none) {
    side = math.max(side, 32);
    top = math.max(top, 32);
    bottom = math.max(bottom, 32);
    if (s.halo == PawHalo639.follow) {
      // Même taille à toutes les images de l'onde (pas de saut d'ancre).
      side = math.max(side, 35);
      top = math.max(top, 35);
      bottom = math.max(bottom, 35);
    }
  }
  if (s.halo == PawHalo639.friend) {
    side = math.max(side, 26.5);
    top = math.max(top, 26.5);
  } else if (s.halo == PawHalo639.boost) {
    side = math.max(side, 24.5);
    top = math.max(top, 24.5);
  }
  if (s.premium) {
    side = math.max(side, 24.5);
    top = math.max(top, 24.5);
  }
  if (s.available) {
    side = math.max(side, s.multi ? 23.5 : 20.5);
    bottom = math.max(bottom, 21.5);
  }
  if (s.live || s.verified) {
    side = math.max(side, 21.5);
    bottom = math.max(bottom, 22.5);
  }
  side *= s.scale;
  top *= s.scale;
  bottom *= s.scale;
  if (s.caption.isNotEmpty) {
    side = math.max(side, _capW639(s.caption) / 2 + 6);
    final double reach =
        (pawPinCaptionR639(s.multi, above: s.captionAbove) + 3) * s.scale + _kCapH639 + 6;
    if (s.captionAbove) {
      top = math.max(top, reach);
    } else {
      bottom = math.max(bottom, reach);
    }
  }
  final double half = side.ceilToDouble();
  final double t = top.ceilToDouble();
  double b = bottom.ceilToDouble();
  if ((t + b) % 2 != 0) b += 1;
  return (w: 2 * half, h: t + b, cx: half, cy: t);
}

Size pawPinBitmap639(PawPinSpec639 s) {
  final l = pawPinLayout639(s);
  return Size(l.w, l.h);
}

/// Ancre EXACTE : le centre du disque, en fraction de l'image réellement
/// produite (`ceil(taille × densité)` pixels).
Offset pawPinAnchor639(PawPinSpec639 s, {double? renderScale}) {
  final l = pawPinLayout639(s);
  final double sc = renderScale ?? pawMemberPinScale();
  return Offset(
      l.cx * sc / (l.w * sc).ceil(), l.cy * sc / (l.h * sc).ceil());
}

/// Centre du point vert « disponible aujourd'hui » (repère = centre du
/// disque). Maquette : en bas à gauche, décalé de −1 pt → (−13 ; 13). Sur une
/// pastille MULTI-rôle (cas absent de la maquette) ce point tomberait sur la
/// mini-pastille de gauche : il remonte sur le bord gauche du disque
/// (−16 ; 3), à plus de 13,5 pt du centre de chaque mini-pastille (rayons
/// 8 + 5,5), donc sans jamais la toucher.
Offset pawAvailableDotAt639(bool multi) =>
    multi ? const Offset(-16, 3) : const Offset(-13, 13);

/// Encombrement d'une pastille pour le placement (éviter les chevauchements) :
/// le disque et son filet, rien d'autre.
Rect pawPinBox639({bool halo = false}) => Rect.fromCircle(
    center: Offset.zero, radius: halo ? kPawPinHaloR639 + 0.5 : 17);

Path _circle639(Offset c, double r) =>
    Path()..addOval(Rect.fromCircle(center: c, radius: r));

/// Petit rond à liseré blanc (badges, points).
void _dot639(Canvas canvas, Offset c, double r, Paint fill,
    {double shadowBlur = 2, Color shadow = const Color(0x40000000)}) {
  PawMapPinPainter.cssShadow(canvas, _circle639(c, r + 1.5),
      dy: 1, blur: shadowBlur, color: shadow);
  canvas.drawCircle(c, r + 1.5, Paint()..color = Colors.white);
  canvas.drawCircle(c, r, fill);
}

const String _kHeart639 =
    'M4 7.3C1.5 5.3 0 3.9 0 2.2C0 .9 1 0 2.2 0C2.9 0 3.6 .35 4 .9C4.4 .35 5.1 0 5.8 0C7 0 8 .9 8 2.2C8 3.9 6.5 5.3 4 7.3Z';

/// Étoile à 5 branches inscrite dans un carré de côté [size].
Path pawStarPath639(Offset c, double size) {
  final double ro = size / 2, ri = ro * 0.46;
  final p = Path();
  for (var i = 0; i < 10; i++) {
    final double r = i.isEven ? ro : ri;
    final double a = -math.pi / 2 + i * math.pi / 5;
    final o = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
    if (i == 0) {
      p.moveTo(o.dx, o.dy);
    } else {
      p.lineTo(o.dx, o.dy);
    }
  }
  return p..close();
}

void _paintHalo639(Canvas canvas, PawPinSpec639 s) {
  final Color c = PawPin639.halo(s.halo);
  const double r = kPawPinHaloR639;
  // Lueur 0 0 9 1 — seulement à l'EXTÉRIEUR du cercle.
  canvas.save();
  canvas.clipPath(Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Rect.fromCircle(center: Offset.zero, radius: 60))
    ..addOval(Rect.fromCircle(center: Offset.zero, radius: r)));
  canvas.drawCircle(
      Offset.zero,
      r + 1,
      Paint()
        ..color = c.withValues(alpha: 0xC0 / 255)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5));
  canvas.restore();
  canvas.drawCircle(
      Offset.zero, r, Paint()..color = c.withValues(alpha: 0x38 / 255));
  canvas.drawCircle(
      Offset.zero,
      r - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = c);
  if (s.wave >= 0) {
    // Onde : 1 → 1,6, opacité .75 → 0, ease-out, 1,8 s.
    final double e = Curves.easeOut.transform(s.wave / kPawWaveSteps639);
    final double k = 1 + 0.6 * e;
    canvas.drawCircle(
        Offset.zero,
        (r - 1) * k,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * k
          ..color = c.withValues(alpha: 0.75 * (1 - e)));
  }
}

void _paintPinBody639(Canvas canvas, PawPinSpec639 s) {
  const double r = kPawPinDiscR639;
  final String main = s.roles.first;
  if (s.halo != PawHalo639.none) _paintHalo639(canvas, s);

  // Pointe de sélection (derrière le disque).
  if (s.tip) {
    canvas.save();
    canvas.translate(0, 13.5);
    canvas.rotate(math.pi / 4);
    final rr = RRect.fromRectAndCorners(
        Rect.fromCenter(center: Offset.zero, width: 9, height: 9),
        bottomRight: const Radius.circular(2));
    canvas.drawRRect(
        rr.shift(const Offset(1, 1)),
        Paint()
          ..color = const Color(0x4D000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1));
    canvas.drawRRect(rr, Paint()..color = PawPin639.role(main));
    canvas.restore();
  }

  // Disque : ombre 0 1 3 .35, filet 0,5 pt .25, pleine couleur.
  PawMapPinPainter.cssShadow(canvas, _circle639(Offset.zero, r),
      dy: 1, blur: 3, color: const Color(0x59000000));
  canvas.drawCircle(
      Offset.zero, r + 0.5, Paint()..color = const Color(0x40000000));
  canvas.drawCircle(Offset.zero, r, Paint()..color = PawPin639.role(main));
  if (s.multi) {
    final int n = s.roles.length;
    final rect = Rect.fromCircle(center: Offset.zero, radius: r);
    for (var i = 1; i < n; i++) {
      canvas.drawArc(rect, -math.pi / 2 + i * 2 * math.pi / n,
          2 * math.pi / n, true, Paint()..color = PawPin639.role(s.roles[i]));
    }
  }
  PawMapPinPainter.drawIcon(canvas,
      s.multi ? PawPin639.pets : PawPin639.icon(main), Offset.zero, 17,
      Colors.white);

  // Mini-pastilles des rôles (multi) : 12 pt, écart 3, sous le disque.
  if (s.multi) {
    final int n = s.roles.length;
    for (var i = 0; i < n; i++) {
      final c = Offset((i - (n - 1) / 2) * 15, 17);
      PawMapPinPainter.cssShadow(canvas, _circle639(c, 7.5),
          dy: 1, blur: 2, color: const Color(0x4D000000));
      canvas.drawCircle(c, 8, Paint()..color = const Color(0x24000000));
      canvas.drawCircle(c, 7.5, Paint()..color = Colors.white);
      canvas.drawCircle(c, 6, Paint()..color = PawPin639.role(s.roles[i]));
      PawMapPinPainter.drawIcon(
          canvas, PawPin639.icon(s.roles[i]), c, 8, Colors.white);
    }
  }

  // Badge du halo, en haut à gauche.
  if (s.halo == PawHalo639.boost) {
    const c = Offset(-14.5, -14.5);
    _dot639(canvas, c, 6.5, Paint()..color = PawPin639.boost);
    PawMapPinPainter.drawSvg(canvas, PawGlyphs.rocket,
        Rect.fromCenter(center: c, width: 9, height: 9), PawPin639.boostInk);
  } else if (s.halo == PawHalo639.friend) {
    const c = Offset(-14.5, -14.5);
    final rect = Rect.fromCircle(center: c, radius: 7.5);
    _dot639(
        canvas,
        c,
        7.5,
        Paint()
          ..shader = PawMapPinPainter.cssLinear(
              rect, 160, const [PawPin639.heartA, PawPin639.heartB]),
        shadowBlur: 3,
        shadow: const Color(0x7378005A));
    // Reflet intérieur 0 1 0 blanc .35.
    canvas.drawPath(
        Path.combine(PathOperation.difference, _circle639(c, 7.5),
            _circle639(c.translate(0, 1), 7.5)),
        Paint()..color = const Color(0x59FFFFFF));
    canvas.save();
    canvas.translate(c.dx - 4, c.dy - 3.65);
    canvas.drawPath(PawSvgPath.parse(_kHeart639), Paint()..color = Colors.white);
    canvas.restore();
  }

  // Couronne Premium, en haut à droite — par-dessus tout.
  if (s.premium) {
    const c = Offset(14, -14);
    _dot639(canvas, c, 7, Paint()..color = PawPin639.gold);
    const double w = 8.4, h = 7;
    final double x = c.dx - w / 2, y = c.dy - h / 2;
    const pts = <List<double>>[
      [0, 12], [27, 52], [50, 0], [73, 52], [100, 12], [88, 100], [12, 100],
    ];
    final p = Path();
    for (var i = 0; i < pts.length; i++) {
      final double px = x + w * pts[i][0] / 100, py = y + h * pts[i][1] / 100;
      if (i == 0) {
        p.moveTo(px, py);
      } else {
        p.lineTo(px, py);
      }
    }
    canvas.drawPath(p..close(), Paint()..color = PawPin639.goldInk);
  }

  // Point vert « disponible aujourd'hui », en bas à gauche.
  if (s.available) {
    _dot639(canvas, pawAvailableDotAt639(s.multi), 4,
        Paint()..color = PawPin639.available,
        shadow: const Color(0x4D000000));
  }

  // Point rouge « en direct », en bas à droite (sinon la coche, si activée).
  if (s.live) {
    _dot639(canvas, const Offset(13.5, 13.5), 3.5,
        Paint()..color = PawPin639.live);
  } else if (s.verified) {
    const c = Offset(13.5, 13.5);
    _dot639(canvas, c, 4.5, Paint()..color = PawPin639.verified);
    PawMapPinPainter.drawSvg(canvas, PawGlyphs.check,
        Rect.fromCenter(center: c, width: 7, height: 7), Colors.white,
        stroke: 3.2);
  }
}

/// Dessine la pastille v2 dans une image de [pawPinBitmap639].
void paintPin639(Canvas canvas, PawPinSpec639 s) {
  final l = pawPinLayout639(s);
  canvas.save();
  canvas.translate(l.cx, l.cy);
  canvas.save();
  canvas.scale(s.scale, s.scale);
  _paintPinBody639(canvas, s);
  canvas.restore();
  if (s.caption.isNotEmpty) {
    final double gap =
        (pawPinCaptionR639(s.multi, above: s.captionAbove) + 3) * s.scale;
    PawMapPinPainter._paintPill(canvas,
        text: s.caption,
        cx: 0,
        top: s.captionAbove ? -gap - _kCapH639 : gap,
        style: _pinStyle(11, FontWeight.w700, s.captionColor, inter: true),
        height: _kCapH639,
        padX: 9.5,
        bg: Colors.white,
        border: PawPin639.friend,
        borderW: 1.5);
  }
  canvas.restore();
}

// ── groupe v2 ────────────────────────────────────────────────────────────

TextPainter _tp639(String t, double size, FontWeight w, Color color,
        {double letterSpacing = 0}) =>
    TextPainter(
      text: TextSpan(
          text: t,
          style: _pinStyle(size, w, color)
              .copyWith(letterSpacing: letterSpacing)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

/// Largeur de la pilule « dès X » sous un groupe ouvert (0 = pas de pilule).
double pawClusterLabelW639({String? labelPrefix, String? labelPrice}) {
  final String price = labelPrice ?? '';
  if (price.isEmpty) return 0;
  final String prefix = labelPrefix ?? '';
  final double pw = prefix.isEmpty
      ? 0
      : _tp639(prefix, 10, FontWeight.w600, Colors.black).width + 5;
  return 8 + 7 + 5 + pw + _tp639(price, 12, FontWeight.w800, Colors.black).width + 10;
}

({double w, double h, double cx, double cy}) pawClusterLayout639(
    {String? labelPrefix, String? labelPrice}) {
  final double lw =
      pawClusterLabelW639(labelPrefix: labelPrefix, labelPrice: labelPrice);
  double side = 20, bottom = 21;
  const double top = 19;
  if (lw > 0) {
    side = math.max(side, lw / 2 + 8);
    bottom = 21 + 24 + 13; // pilule (haut +21, h 24) + ombre 0 5 10 −3
  }
  final double half = side.ceilToDouble();
  double b = bottom.ceilToDouble();
  if ((top + b) % 2 != 0) b += 1;
  return (w: 2 * half, h: top + b, cx: half, cy: top);
}

Size pawClusterBitmap639({String? labelPrefix, String? labelPrice}) {
  final l =
      pawClusterLayout639(labelPrefix: labelPrefix, labelPrice: labelPrice);
  return Size(l.w, l.h);
}

/// Ancre exacte d'un groupe : le centre de son disque.
Offset pawClusterAnchor639(
    {String? labelPrefix, String? labelPrice, double? renderScale}) {
  final l =
      pawClusterLayout639(labelPrefix: labelPrefix, labelPrice: labelPrice);
  final double sc = renderScale ?? pawMemberPinScale();
  return Offset(
      l.cx * sc / (l.w * sc).ceil(), l.cy * sc / (l.h * sc).ceil());
}

/// Groupe v2 : disque 32 pt « surface », anneau 3,5 pt partagé par rôle
/// (départ à 9 h, sens horaire, promeneur → propriétaire → gardien, écart 5°),
/// compteur 13 pt extra-gras ; pilule « dès X » quand le groupe est ouvert.
void paintCluster639(
  Canvas canvas, {
  required int count,
  required Map<String, int> counts,
  bool dark = false,
  String? labelPrefix,
  String? labelPrice,
  String labelRole = 'sitter',
}) {
  final l =
      pawClusterLayout639(labelPrefix: labelPrefix, labelPrice: labelPrice);
  const double r = kPawPinDiscR639;
  canvas.save();
  canvas.translate(l.cx, l.cy);
  PawMapPinPainter.cssShadow(canvas, _circle639(Offset.zero, r),
      dy: 1, blur: 3, color: const Color(0x59000000));
  canvas.drawCircle(
      Offset.zero, r + 0.5, Paint()..color = const Color(0x40000000));
  canvas.drawCircle(Offset.zero, r, Paint()..color = PawPin639.surface(dark));

  const ringOrder = <String>['walker', 'owner', 'sitter'];
  final parts = <MapEntry<String, int>>[
    for (final k in ringOrder)
      if ((counts[k] ?? 0) > 0) MapEntry(k, counts[k]!),
  ];
  final int total = parts.fold<int>(0, (a, e) => a + e.value);
  if (total > 0) {
    const double gap = 5 * math.pi / 180;
    final rect = Rect.fromCircle(center: Offset.zero, radius: r - 1.75);
    double a = math.pi; // 9 h
    for (final e in parts) {
      final double sweep = 2 * math.pi * e.value / total;
      if (sweep > gap) {
        canvas.drawArc(
            rect,
            a + gap,
            sweep - gap,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.5
              ..color = PawPin639.role(e.key));
      }
      a += sweep;
    }
  }
  final tp = _tp639(count > 99 ? '99+' : '$count', 13, FontWeight.w800,
      PawPin639.text(dark),
      letterSpacing: -0.52);
  tp.paint(canvas, Offset(-tp.width / 2 - 0.26, -tp.height / 2));

  final String price = labelPrice ?? '';
  if (price.isNotEmpty) {
    final double lw =
        pawClusterLabelW639(labelPrefix: labelPrefix, labelPrice: labelPrice);
    final rr = RRect.fromRectAndRadius(
        Rect.fromLTWH(-lw / 2, 21, lw, 24), const Radius.circular(12));
    final path = Path()..addRRect(rr);
    PawMapPinPainter.cssShadow(canvas, path,
        dy: 5, blur: 10, spread: -3, color: const Color(0x47000000));
    PawMapPinPainter.cssShadow(canvas, path,
        dy: 1, blur: 1, color: const Color(0x24000000));
    canvas.drawRRect(rr, Paint()..color = PawPin639.surface(dark));
    canvas.drawRRect(
        rr.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = PawPin639.edge(dark));
    double x = -lw / 2 + 8;
    canvas.drawCircle(
        Offset(x + 3.5, 33), 3.5, Paint()..color = PawPin639.role(labelRole));
    x += 7 + 5;
    final String prefix = labelPrefix ?? '';
    if (prefix.isNotEmpty) {
      final pp = _tp639(prefix, 10, FontWeight.w600, PawPin639.muted(dark));
      pp.paint(canvas, Offset(x, 33 - pp.height / 2));
      x += pp.width + 5;
    }
    final vp = _tp639(price, 12, FontWeight.w800, PawPin639.text(dark));
    vp.paint(canvas, Offset(x, 33 - vp.height / 2));
  }
  canvas.restore();
}

// ── bulle de prix v2 ─────────────────────────────────────────────────────

/// Un segment de la bulle : un rôle, son prix, son unité (« /h »).
typedef PawPriceSeg639 = ({String role, String amount, String unit});

/// Distance, en points, entre la pointe de la bulle et le point de la carte :
/// la pilule flotte à 25 × 1,18 = 29,5 pt au-dessus du centre de la pastille
/// touchée ; la pointe descend de 6,3 pt.
const double kBubbleLift639 = 23.2;
const double _kBubTail639 = 6.3;
const double _kBubSide639 = 10; // ombre 0 6 9
const double _kBubTop639 = 12; // étiquette de note (dépasse de 10) + liseré

double _segW639(PawPriceSeg639 s, bool first) =>
    (first ? 0 : 5) +
    20 +
    5 +
    _tp639(s.amount, 13, FontWeight.w800, Colors.black, letterSpacing: -0.26)
        .width +
    (s.unit.isEmpty
        ? 0
        : 1 + _tp639(s.unit, 9.5, FontWeight.w600, Colors.black).width) +
    8;

/// Largeur de la pilule (sans marge) : 4 + segments + 4.
double pawBubbleBodyW639(List<PawPriceSeg639> segs) {
  double w = 8;
  for (var i = 0; i < segs.length; i++) {
    w += _segW639(segs[i], i == 0);
  }
  return w;
}

({double w, double h, double bodyTop}) _bubLayout639(
    List<PawPriceSeg639> segs, double lift) {
  final double w = 2 * ((pawBubbleBodyW639(segs) / 2 + _kBubSide639).ceilToDouble());
  double h = (_kBubTop639 + 28 + _kBubTail639 + lift).ceilToDouble();
  if (h % 2 != 0) h += 1;
  return (w: w, h: h, bodyTop: h - lift - _kBubTail639 - 28);
}

/// Image de la bulle : la zone transparente sous la pointe ([lift]) fait
/// PARTIE de l'image — l'ancre reste le bas de l'image, comme avant.
Size pawBubbleBitmap639(List<PawPriceSeg639> segs,
    {double lift = kBubbleLift639}) {
  final l = _bubLayout639(segs, lift);
  return Size(l.w, l.h);
}

/// Ancre : la pointe (décalée de [tailDx] quand la bulle est repoussée du
/// bord de l'écran), tout en bas de l'image.
Offset pawBubbleAnchor639(List<PawPriceSeg639> segs, double tailDx,
    {double lift = kBubbleLift639, double? renderScale}) {
  final l = _bubLayout639(segs, lift);
  final double sc = renderScale ?? pawMemberPinScale();
  return Offset((l.w / 2 + tailDx) * sc / (l.w * sc).ceil(),
      l.h * sc / (l.h * sc).ceil());
}

/// Bulle de prix v2 : pilule 28 pt claire (sombre en mode nuit), un rond de
/// rôle par segment, pointe 11 pt, étiquette de note en haut à droite.
void paintBubble639(
  Canvas canvas,
  List<PawPriceSeg639> segs, {
  double tailDx = 0,
  double lift = kBubbleLift639,
  bool dark = false,
  double rating = 0,
  String? ratingLabel,
}) {
  final l = _bubLayout639(segs, lift);
  final double bw = pawBubbleBodyW639(segs);
  final double left = (l.w - bw) / 2, top = l.bodyTop;
  final rr = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, bw, 28), const Radius.circular(14));
  // Pointe : carré 11 tourné de 45°, coin du bas arrondi 3, remonté de 7.
  final double tx = (l.w / 2 + tailDx)
      .clamp(left + 14, left + bw - 14)
      .toDouble();
  final m = Matrix4.identity()
    ..translateByDouble(tx, top + 28 - 7 + 5.5, 0, 1)
    ..rotateZ(math.pi / 4);
  final tail = (Path()
        ..addRRect(RRect.fromRectAndCorners(
            Rect.fromCenter(center: Offset.zero, width: 11, height: 11),
            bottomRight: const Radius.circular(3))))
      .transform(m.storage);
  final shape = Path.combine(PathOperation.union, Path()..addRRect(rr), tail);
  PawMapPinPainter.cssShadow(canvas, shape,
      dy: 6, blur: 9, color: const Color(0x3D000000));
  PawMapPinPainter.cssShadow(canvas, shape,
      dy: 1, blur: 1, color: const Color(0x33000000));
  canvas.drawPath(shape, Paint()..color = PawPin639.surface(dark));
  canvas.save();
  canvas.clipRRect(rr);
  canvas.drawRRect(
      rr.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = PawPin639.edge(dark));
  canvas.restore();

  final double cy = top + 14;
  double x = left + 4;
  for (var i = 0; i < segs.length; i++) {
    final s = segs[i];
    if (i > 0) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, cy - 7, 1, 14),
              const Radius.circular(1)),
          Paint()..color = PawPin639.line(dark));
      x += 5;
    }
    final c = Offset(x + 10, cy);
    final disc = Rect.fromCircle(center: c, radius: 10);
    canvas.drawCircle(
        c,
        10,
        Paint()
          ..shader = PawMapPinPainter.cssLinear(disc, 160,
              [PawPin639.roleLight(s.role), PawPin639.role(s.role)]));
    canvas.drawPath(
        Path.combine(PathOperation.difference, _circle639(c, 10),
            _circle639(c.translate(0, 1), 10)),
        Paint()..color = const Color(0x59FFFFFF));
    canvas.drawPath(
        Path.combine(PathOperation.difference, _circle639(c, 10),
            _circle639(c.translate(0, -1), 10)),
        Paint()..color = const Color(0x1F000000));
    PawMapPinPainter.drawIcon(
        canvas, PawPin639.icon(s.role), c, 13, Colors.white);
    x += 20 + 5;
    final ap = _tp639(s.amount, 13, FontWeight.w800, PawPin639.text(dark),
        letterSpacing: -0.26);
    final double ay = cy - ap.height / 2;
    ap.paint(canvas, Offset(x, ay));
    x += ap.width;
    if (s.unit.isNotEmpty) {
      final up = _tp639(s.unit, 9.5, FontWeight.w600, PawPin639.muted(dark));
      final double base =
          ay + ap.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      up.paint(
          canvas,
          Offset(
              x + 1,
              base -
                  up.computeDistanceToActualBaseline(TextBaseline.alphabetic)));
      x += 1 + up.width;
    }
    x += 8;
  }

  // Étiquette de note : à 10 pt du bord droit, dépasse de 10 pt en haut.
  if (rating > 0) {
    final np = _tp639(ratingLabel ?? rating.toStringAsFixed(1), 10,
        FontWeight.w800, PawPin639.noteInk);
    final double nw = 4 + 11 + 1 + np.width + 6;
    final nr = RRect.fromRectAndRadius(
        Rect.fromLTWH(left + bw - 10 - nw, top - 10, nw, 16),
        const Radius.circular(8));
    canvas.drawRRect(nr.inflate(1.5), Paint()..color = PawPin639.surface(dark));
    canvas.drawRRect(nr, Paint()..color = PawPin639.note);
    canvas.drawPath(
        pawStarPath639(Offset(nr.left + 4 + 5.5, nr.top + 8), 10),
        Paint()..color = PawPin639.noteInk);
    np.paint(canvas, Offset(nr.left + 4 + 11 + 1, nr.top + 8 - np.height / 2));
  }
}
