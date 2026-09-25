// v571 — fond à motif de pattes, réutilisable dans toute l'app.
// v585 (lot D du chantier du 24/09) — devient le FOND « À MON ANIMAL »
// (NORME_DESIGN.md, validé par Daniel le 23/09) : un papier peint illustré,
// plus rempli et personnel, qui s'efface derrière le texte et les cartes.
//
//   · couleur du RÔLE ACTIF : propriétaire fond pâle orange, gardien fond
//     pâle bleu, PROMENEUR FOND PÂLE VERT ; motifs dans une teinte plus
//     soutenue du même rôle, jamais gris ;
//   · les objets de MON animal (espèce lue dans « Mes animaux », mémorisée par
//     `MyPetsController`) : chien = os, balle, laisse ; chat = poisson, pelote,
//     lune ; lapin = carotte ; oiseau = plume ; plusieurs espèces = mélange ;
//     aucun animal (gardien, promeneur, invité) = pattes + maison / arbre /
//     cœur selon le rôle ; toujours quelques pattes et cœurs ;
//   · réglage « Mon fond » (Préférences) : auto / pattes seules / aucun,
//     enregistré sur le compte (`preferences.wallpaper`) et copié ici ;
//   · mode sombre : fond brun sombre de la marque teinté du rôle, motifs plus
//     clairs.
//
// Contraintes de rendu (inchangées depuis la v571) : disposition en quinconce
// DÉTERMINISTE (hachage de la cellule, aucun scintillement), `RepaintBoundary`,
// `shouldRepaint` faux tant que rien ne change, `IgnorePointer` (aucun tap
// capté). Les 70 écrans qui posent `PawPatternBackground(color:, child:)`
// n'ont rien à changer : même API.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';

/// Les motifs du papier peint.
enum PawMotif { paw, heart, bone, ball, leash, fish, yarn, moon, carrot, feather, house, tree }

/// Réglage « Mon fond » + espèces mémorisées (copie locale de ce qui est sur
/// le compte, pour que le fond soit juste dès la première image).
class PawWallpaperPrefs {
  static const String modeKey = 'wallpaper_mode_v585';
  static const String speciesKey = 'wallpaper_species_v585';

  /// Tests seulement : force le mode / les espèces sans GetStorage.
  static String? debugMode;
  static List<String>? debugSpecies;
  static String? debugRole;

  /// v586 — CAUSE du « Mon fond ne marche pas » (reproduit sur l'émulateur,
  /// compte de test, 25/09) : le fond lisait le réglage UNE fois, à la
  /// construction de l'écran. Les écrans déjà construits (onglets gardés
  /// vivants comme l'Accueil, et la page Préférences elle-même) n'étaient
  /// jamais redessinés : le choix était bien enregistré, mais rien ne
  /// changeait à l'écran avant un redémarrage. Chaque changement (mode ou
  /// espèces) incrémente désormais ce compteur, que TOUS les fonds écoutent.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static GetStorage? _box() {
    try {
      return GetStorage();
    } catch (_) {
      return null;
    }
  }

  /// 'auto' | 'paws' | 'none'.
  static String mode() {
    if (debugMode != null) return debugMode!;
    final v = _box()?.read<String>(modeKey);
    return (v == 'paws' || v == 'none') ? v! : 'auto';
  }

  static void setMode(String mode) {
    final m = (mode == 'paws' || mode == 'none') ? mode : 'auto';
    final before = _safeMode();
    if (debugMode != null) {
      debugMode = m; // tests : pas de stockage
    } else {
      _box()?.write(modeKey, m);
    }
    if (before != m) revision.value++;
  }

  static String _safeMode() {
    try {
      return mode();
    } catch (_) {
      return 'auto';
    }
  }

  /// v586 — le compte fait foi : à chaque lecture du profil (connexion, autre
  /// téléphone, changement de rôle), la copie locale suit la valeur du compte
  /// quand il l'a renvoyée.
  static void syncFromAccount(String? mode) {
    if (mode == null) return;
    if (mode != 'auto' && mode != 'paws' && mode != 'none') return;
    if (_safeMode() != mode) setMode(mode);
  }

  static List<String> species() {
    if (debugSpecies != null) return debugSpecies!;
    final v = _box()?.read(speciesKey);
    if (v is List) return v.map((e) => e.toString()).toList();
    return const <String>[];
  }

  static void rememberSpecies(List<String?> categories) {
    final list = categories.map(normalizeSpecies).where((s) => s.isNotEmpty).toSet().toList();
    final before = species().toSet();
    _box()?.write(speciesKey, list);
    if (before.length != list.length || !before.containsAll(list)) revision.value++;
  }

  /// « Dog », « chat », « pájaro »… → dog / cat / bird / rabbit / ''.
  static String normalizeSpecies(String? category) {
    final c = (category ?? '').trim().toLowerCase();
    if (c.isEmpty) return '';
    const dog = ['dog', 'chien', 'perro', 'hund', 'cane', 'cão', 'pies', '개', '犬'];
    const cat = ['cat', 'chat', 'gato', 'katze', 'gatto', 'kot', '고양이', '猫'];
    const bird = ['bird', 'oiseau', 'pájaro', 'vogel', 'uccello', 'pássaro', 'ptak', '새', '鳥'];
    const rabbit = ['rabbit', 'lapin', 'conejo', 'kaninchen', 'coniglio', 'coelho', 'królik', '토끼', 'ウサギ', 'small', 'rongeur'];
    if (dog.any(c.contains)) return 'dog';
    if (cat.any(c.contains)) return 'cat';
    if (bird.any(c.contains)) return 'bird';
    if (rabbit.any(c.contains)) return 'rabbit';
    return '';
  }

  static String _role() {
    if (debugRole != null) return debugRole!;
    try {
      final r = (_box()?.read<String>('user_role') ?? '').toLowerCase();
      if (r.contains('sitter')) return 'sitter';
      if (r.contains('walker')) return 'walker';
      if (r.contains('owner')) return 'owner';
    } catch (_) {}
    return '';
  }

  /// Les motifs à dessiner pour l'état courant (mode, espèces, rôle).
  static Set<PawMotif> motifs() {
    final m = mode();
    if (m == 'none') return const <PawMotif>{};
    if (m == 'paws') return const <PawMotif>{PawMotif.paw, PawMotif.heart};
    final Set<PawMotif> out = <PawMotif>{PawMotif.paw, PawMotif.heart};
    final sp = species();
    if (sp.isEmpty) {
      switch (_role()) {
        case 'sitter':
          out.add(PawMotif.house);
          break;
        case 'walker':
          out.add(PawMotif.tree);
          break;
        default:
          break;
      }
      return out;
    }
    for (final s in sp) {
      switch (s) {
        case 'dog':
          out.addAll(const [PawMotif.bone, PawMotif.ball, PawMotif.leash]);
          break;
        case 'cat':
          out.addAll(const [PawMotif.fish, PawMotif.yarn, PawMotif.moon]);
          break;
        case 'rabbit':
          out.add(PawMotif.carrot);
          break;
        case 'bird':
          out.add(PawMotif.feather);
          break;
      }
    }
    return out;
  }
}

/// Empile le papier peint « à mon animal » derrière [child].
///
/// ```dart
/// PawPatternBackground(
///   color: AppColors.activeRoleAccent(),
///   child: Column(children: [...]),
/// )
/// ```
class PawPatternBackground extends StatelessWidget {
  /// Couleur d'accent du rôle (motifs) ; le fond pâle en est dérivé.
  final Color color;

  /// Contenu affiché PAR-DESSUS le motif (les cartes restent opaques).
  final Widget child;

  /// Opacité forcée des motifs. Par défaut 0.09 en clair et 0.10 en sombre.
  final double? opacity;

  /// Motifs forcés (tests, aperçu du réglage) ; sinon `PawWallpaperPrefs`.
  final Set<PawMotif>? motifs;

  /// Peindre aussi le fond pâle du rôle sous les motifs (défaut oui).
  final bool paintBase;

  const PawPatternBackground({
    super.key,
    required this.color,
    required this.child,
    this.opacity,
    this.motifs,
    this.paintBase = true,
  });

  @override
  Widget build(BuildContext context) {
    // v586 — se redessine dès que « Mon fond » ou les espèces changent.
    if (motifs != null) return _build(context, motifs!);
    return ValueListenableBuilder<int>(
      valueListenable: PawWallpaperPrefs.revision,
      builder: (ctx, _, __) => _build(ctx, PawWallpaperPrefs.motifs()),
    );
  }

  Widget _build(BuildContext context, Set<PawMotif> set) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final double alpha = (opacity ?? (dark ? 0.10 : 0.09)).clamp(0.0, 1.0);
    // Fond pâle du rôle (clair) / brun de la marque teinté du rôle (sombre).
    final Color? base = !paintBase
        ? null
        : dark
            ? Color.lerp(const Color(0xFF241916), color, 0.10)
            : Color.lerp(color, Colors.white, 0.93);
    // Motifs : teinte plus soutenue du rôle (clair) / plus claire (sombre).
    final Color ink = dark ? Color.lerp(color, Colors.white, 0.35)! : color;
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: PawPatternPainter(
                  color: ink,
                  opacity: alpha,
                  motifs: set,
                  base: base,
                ),
                isComplex: true,
                willChange: false,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Peintre du papier peint. Public pour pouvoir être réutilisé seul.
class PawPatternPainter extends CustomPainter {
  final Color color;
  final double opacity;

  /// Côté d'une cellule du semis, en pixels logiques.
  final double cell;

  /// Motifs dessinés (pattes seules par défaut, comme en v571).
  final Set<PawMotif> motifs;

  /// Fond peint sous les motifs (null = transparent).
  final Color? base;

  const PawPatternPainter({
    required this.color,
    required this.opacity,
    this.cell = 96,
    this.motifs = const <PawMotif>{PawMotif.paw},
    this.base,
  });

  /// Hachage déterministe d'une cellule : mêmes motifs / tailles / rotations
  /// à chaque frame, donc aucun scintillement.
  static int _hash(int c, int r) {
    int h = (c * 73856093) ^ (r * 19349663) ^ 0x5bf03635;
    h ^= h >> 13;
    h *= 1274126177;
    h ^= h >> 16;
    return h & 0x7fffffff;
  }

  /// Une patte centrée sur l'origine, coussinet + 4 doigts.
  static void _paw(Canvas canvas, Paint paint) {
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 5.2), width: 17, height: 14),
      paint,
    );
    const List<List<double>> toes = <List<double>>[
      <double>[-8.6, -3.6, 4.0, 5.2, -0.42],
      <double>[-3.0, -9.0, 4.0, 5.4, -0.14],
      <double>[3.0, -9.0, 4.0, 5.4, 0.14],
      <double>[8.6, -3.6, 4.0, 5.2, 0.42],
    ];
    for (final List<double> t in toes) {
      canvas.save();
      canvas.translate(t[0], t[1]);
      canvas.rotate(t[4]);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: t[2] * 2, height: t[3] * 2),
        paint,
      );
      canvas.restore();
    }
  }

  static void _heart(Canvas canvas, Paint paint) {
    final Path p = Path()
      ..moveTo(0, 9)
      ..cubicTo(-13, 0, -8, -11, 0, -5)
      ..cubicTo(8, -11, 13, 0, 0, 9)
      ..close();
    canvas.drawPath(p, paint);
  }

  static void _bone(Canvas canvas, Paint paint) {
    for (final Offset o in const [Offset(-11, -4), Offset(-11, 4), Offset(11, -4), Offset(11, 4)]) {
      canvas.drawCircle(o, 4.2, paint);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 22, height: 7), const Radius.circular(3.5)),
      paint,
    );
  }

  static void _ball(Canvas canvas, Paint paint, Paint hole) {
    canvas.drawCircle(Offset.zero, 9, paint);
    // La couture d'une balle : une courbe en creux.
    final Path seam = Path()
      ..moveTo(-8, -3)
      ..quadraticBezierTo(0, 6, 8, -3);
    canvas.drawPath(seam, hole..strokeWidth = 1.8);
  }

  static void _leash(Canvas canvas, Paint paint) {
    final Paint stroke = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final Path p = Path()
      ..moveTo(-10, 10)
      ..cubicTo(-14, -6, 6, -14, 8, -2)
      ..cubicTo(9, 4, 2, 6, 0, 2);
    canvas.drawPath(p, stroke);
    canvas.drawCircle(const Offset(-10, 10), 3.5, paint);
  }

  static void _fish(Canvas canvas, Paint paint, Paint hole) {
    final Path body = Path()
      ..moveTo(-12, 0)
      ..quadraticBezierTo(-4, -9, 6, -6)
      ..quadraticBezierTo(11, -3, 12, 0)
      ..quadraticBezierTo(11, 3, 6, 6)
      ..quadraticBezierTo(-4, 9, -12, 0)
      ..close();
    canvas.drawPath(body, paint);
    final Path tail = Path()
      ..moveTo(9, 0)
      ..lineTo(16, -6)
      ..lineTo(16, 6)
      ..close();
    canvas.drawPath(tail, paint);
    canvas.drawCircle(const Offset(-6, -1.5), 1.4, hole..style = PaintingStyle.fill);
  }

  static void _yarn(Canvas canvas, Paint paint, Paint hole) {
    canvas.drawCircle(Offset.zero, 9, paint);
    final Paint s = hole
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawPath(Path()..moveTo(-7, -4)..quadraticBezierTo(0, 3, 7, -4), s);
    canvas.drawPath(Path()..moveTo(-7, 3)..quadraticBezierTo(0, -3, 7, 3), s);
  }

  static void _moon(Canvas canvas, Paint paint) {
    final Path p = Path()
      ..addArc(Rect.fromCircle(center: Offset.zero, radius: 9), -math.pi / 2, math.pi)
      ..arcTo(Rect.fromCircle(center: const Offset(-4, 0), radius: 7), math.pi / 2, -math.pi, false)
      ..close();
    canvas.drawPath(p, paint);
  }

  static void _carrot(Canvas canvas, Paint paint) {
    final Path body = Path()
      ..moveTo(-5, -8)
      ..lineTo(5, -8)
      ..lineTo(0, 12)
      ..close();
    canvas.drawPath(body, paint);
    final Paint leaf = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-4, -9), const Offset(-7, -15), leaf);
    canvas.drawLine(const Offset(0, -9), const Offset(0, -16), leaf);
    canvas.drawLine(const Offset(4, -9), const Offset(7, -15), leaf);
  }

  static void _feather(Canvas canvas, Paint paint, Paint hole) {
    final Path p = Path()
      ..moveTo(0, -13)
      ..quadraticBezierTo(9, -4, 7, 6)
      ..quadraticBezierTo(4, 12, 0, 14)
      ..quadraticBezierTo(-4, 12, -7, 6)
      ..quadraticBezierTo(-9, -4, 0, -13)
      ..close();
    canvas.drawPath(p, paint);
    canvas.drawLine(const Offset(0, -10), const Offset(0, 14), hole..style = PaintingStyle.stroke..strokeWidth = 1.4);
  }

  static void _house(Canvas canvas, Paint paint) {
    final Path p = Path()
      ..moveTo(-11, 1)
      ..lineTo(0, -10)
      ..lineTo(11, 1)
      ..lineTo(8, 1)
      ..lineTo(8, 11)
      ..lineTo(-8, 11)
      ..lineTo(-8, 1)
      ..close();
    canvas.drawPath(p, paint);
  }

  static void _tree(Canvas canvas, Paint paint) {
    canvas.drawCircle(const Offset(0, -4), 9, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, 9), width: 4, height: 9), const Radius.circular(2)),
      paint,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    if (base != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = base!);
    }
    if (opacity <= 0 || motifs.isEmpty) return;
    final Paint paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    // « Creux » : pour dessiner la couture d'une balle ou l'œil d'un poisson
    // on repeint dans la couleur du fond (ou blanc translucide).
    final Paint hole = Paint()
      ..color = (base ?? Colors.white).withValues(alpha: math.min(1.0, opacity * 6))
      ..isAntiAlias = true;

    final List<PawMotif> extras = motifs.where((m) => m != PawMotif.paw && m != PawMotif.heart).toList();
    final bool hearts = motifs.contains(PawMotif.heart);

    final int cols = (size.width / cell).ceil() + 1;
    final int rows = (size.height / cell).ceil() + 1;

    for (int r = -1; r <= rows; r++) {
      for (int c = -1; c <= cols; c++) {
        final int h = _hash(c, r);
        // Quinconce : une ligne sur deux décalée d'une demi-cellule.
        final double baseX = c * cell + (r.isEven ? 0.0 : cell / 2);
        final double dx = baseX + (((h & 0x0F) - 7.5) * 1.6);
        final double dy = r * cell + ((((h >> 4) & 0x0F) - 7.5) * 1.6);
        if (dx < -cell || dy < -cell || dx > size.width + cell) continue;
        final double scale = 0.68 + ((h >> 8) & 0x07) * 0.08; // 0,68 → 1,24
        final double angle = (((h >> 11) & 0x1F) / 32.0) * 2 * math.pi;
        // Choix du motif : ~50 % pattes, ~15 % cœurs, le reste = objets de
        // mon animal (à parts égales), sinon pattes.
        final int pick = (h >> 16) % 100;
        PawMotif m = PawMotif.paw;
        if (hearts && pick >= 50 && pick < 65) {
          m = PawMotif.heart;
        } else if (extras.isNotEmpty && pick >= 65) {
          m = extras[((h >> 20) & 0xFF) % extras.length];
        }
        canvas.save();
        canvas.translate(dx, dy);
        canvas.rotate(m == PawMotif.house || m == PawMotif.tree || m == PawMotif.carrot ? angle * 0.15 : angle);
        canvas.scale(scale);
        switch (m) {
          case PawMotif.paw:
            _paw(canvas, paint);
            break;
          case PawMotif.heart:
            _heart(canvas, paint);
            break;
          case PawMotif.bone:
            _bone(canvas, paint);
            break;
          case PawMotif.ball:
            _ball(canvas, paint, Paint()..color = hole.color..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..isAntiAlias = true);
            break;
          case PawMotif.leash:
            _leash(canvas, paint);
            break;
          case PawMotif.fish:
            _fish(canvas, paint, Paint()..color = hole.color..isAntiAlias = true);
            break;
          case PawMotif.yarn:
            _yarn(canvas, paint, Paint()..color = hole.color..isAntiAlias = true);
            break;
          case PawMotif.moon:
            _moon(canvas, paint);
            break;
          case PawMotif.carrot:
            _carrot(canvas, paint);
            break;
          case PawMotif.feather:
            _feather(canvas, paint, Paint()..color = hole.color..isAntiAlias = true);
            break;
          case PawMotif.house:
            _house(canvas, paint);
            break;
          case PawMotif.tree:
            _tree(canvas, paint);
            break;
        }
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant PawPatternPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.opacity != opacity ||
      oldDelegate.cell != cell ||
      oldDelegate.base != base ||
      !_sameSet(oldDelegate.motifs, motifs);

  static bool _sameSet(Set<PawMotif> a, Set<PawMotif> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  bool shouldRebuildSemantics(covariant PawPatternPainter oldDelegate) => false;
}
