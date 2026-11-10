// 639 (10/11) — handoff « Bouton Balade en direct »
// (docs/design_handoff_bouton_balade_en_direct/).
//
// Le bouton rond BALADE de la PawMap, redessiné : disque vert en relief,
// pastille violette, tête de chien. En direct : le chien se balance, quatre
// feuilles flottent et quatre pattes tournent autour.
//
// RÈGLE DE LA MAQUETTE : on ne change QUE l'apparence. Ce widget occupe
// exactement la place d'un `PawJewel` de même `size` (zone tactile ≥ 44 dp,
// même emplacement de pastille, mêmes retours haptiques, même Semantics).
// Les décorations sont peintes en surimpression : elles ne comptent ni dans
// la mise en page ni dans les appuis.
//
// La maquette est dessinée pour D = 144 ; tout est multiplié par D / 144.
// À 38 dp le compteur et la capsule « EN DIRECT » ne tiennent pas dans le
// disque : ils restent SOUS le bouton (appelant), et la pastille du chien est
// agrandie pour rester lisible.
//
// Rien ici ne décide d'une action : le bouton reçoit son `onTap`.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Bouton rond « Balade en direct » (remplace le `PawJewel` du bouton Balade).
class PawWalkJewel extends StatefulWidget {
  const PawWalkJewel({
    super.key,
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.size = 38,
    this.live = false,
    this.active = false,
    this.badge,
  });

  /// Libellé d'accessibilité (le même que celui passé au `PawJewel`).
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Diamètre en dp logiques (38 dans la barre de la PawMap).
  final double size;

  /// Balade en cours : chien qui se balance, feuilles et pattes.
  final bool live;

  /// État « sélectionné » annoncé aux lecteurs d'écran.
  final bool active;

  /// Pastille posée en haut à droite (nombre de suiveurs).
  final Widget? badge;

  @override
  State<PawWalkJewel> createState() => _PawWalkJewelState();
}

class _PawWalkJewelState extends State<PawWalkJewel>
    with TickerProviderStateMixin {
  /// Appui : le disque descend de l'épaisseur du relief (150 ms).
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  )..addStatusListener(_onPressStatus);

  /// Une seule horloge pour le chien, les feuilles et les pattes. 1 260 s =
  /// plus petit multiple commun de toutes les périodes (0,9 · 3 · 4 · 4,5 ·
  /// 5 · 18 · 21 s) : la boucle reprend sans à-coup.
  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: const Duration(seconds: _WalkJewelPainter.loopSeconds),
  );

  bool _held = false;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _syncLife();
  }

  @override
  void didUpdateWidget(covariant PawWalkJewel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.live != widget.live) _syncLife();
  }

  /// L'horloge ne tourne QUE pendant une balade, et jamais si la personne a
  /// demandé la réduction des animations (image fixe).
  void _syncLife() {
    final bool run = widget.live && !_reduced;
    if (run) {
      if (!_life.isAnimating) _life.repeat();
    } else {
      if (_life.isAnimating) _life.stop();
      if (_life.value != 0) _life.value = 0;
    }
  }

  void _onPressStatus(AnimationStatus status) {
    // Appui bref : on laisse le disque finir de descendre avant de remonter.
    if (status == AnimationStatus.completed && !_held) _press.reverse();
  }

  void _down() {
    _held = true;
    _press.forward();
  }

  void _up() {
    _held = false;
    if (_press.status == AnimationStatus.forward) return;
    _press.reverse();
  }

  @override
  void dispose() {
    _press.dispose();
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.size.w;
    // Zone tactile ≥ 44 dp (pixels logiques, jamais réduite par ScreenUtil).
    final double tap = s < 44 ? 44 : s;
    // Marge de peinture autour du disque (ombre, feuilles, pattes) : hors
    // mise en page, hors appuis.
    final double bleed = s * 0.5;
    return Semantics(
      button: true,
      label: widget.label,
      selected: widget.active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _down(),
        onTapCancel: _up,
        onTapUp: (_) => _up(),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                _up();
                HapticFeedback.mediumImpact();
                widget.onLongPress!();
              },
        child: SizedBox(
          width: tap,
          height: tap,
          child: Center(
            child: SizedBox(
              width: s,
              height: s,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: -bleed,
                    top: -bleed,
                    right: -bleed,
                    bottom: -bleed,
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _WalkJewelPainter(
                            diameter: s,
                            live: widget.live,
                            moving: widget.live && !_reduced,
                            badge: widget.badge != null,
                            press: _press,
                            life: _life,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.badge != null)
                    Positioned(top: -5, right: -6, child: widget.badge!),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tout le dessin du bouton. Repeint par les deux horloges seulement : le
/// reste de l'écran n'est jamais reconstruit.
class _WalkJewelPainter extends CustomPainter {
  _WalkJewelPainter({
    required this.diameter,
    required this.live,
    required this.moving,
    required this.badge,
    required this.press,
    required this.life,
  }) : super(repaint: Listenable.merge(<Listenable>[press, life]));

  static const int loopSeconds = 1260;

  // ── Proportions (maquette : D = 144) ──────────────────────────────────
  /// Relief dur sous le disque : 8 / 144.
  static const double _reliefRatio = 0.055;

  /// Pastille violette : 0,35 D dans la maquette (avec le compteur dessous).
  /// Sans texte dans le disque, on l'agrandit pour garder le chien lisible.
  static const double _pastilleRatio = 0.70;

  /// Rayon des feuilles : 0,79 D dans la maquette. Ramené à 0,68 D en haut
  /// et 0,62 D en bas : la barre de la PawMap fait 50 dp de large et rogne
  /// ce qui dépasse.
  static const List<double> _leafRadiusRatios = <double>[
    0.68,
    0.68,
    0.62,
    0.62,
  ];

  /// Rayon de l'orbite des pattes : 0,71 D dans la maquette, ramené à
  /// 0,555 D pour la même raison (les pattes frôlent le bord du disque).
  static const double _pawRadiusRatio = 0.555;

  final double diameter;
  final bool live;
  final bool moving;
  final bool badge;
  final Animation<double> press;
  final Animation<double> life;

  double get _k => diameter / 144;
  double get _relief => math.max(diameter * _reliefRatio, 1.5);
  double get _faceRadius => (diameter - _relief) / 2;

  // Dégradés du disque et de la pastille, centrés sur (0, 0) : créés une
  // fois par taille, pas à chaque image.
  late final Paint _facePaint = Paint()
    ..isAntiAlias = true
    ..shader = _cssRadial(
      radius: _faceRadius,
      atX: 0.35,
      atY: 0.25,
      colors: const <Color>[
        Color(0xFF95F0A4),
        Color(0xFF48CB68),
        Color(0xFF28A04A),
      ],
      stops: const <double>[0, 0.4, 1],
    );

  late final Paint _pastillePaint = Paint()
    ..isAntiAlias = true
    ..shader = _cssRadial(
      radius: _faceRadius * _pastilleRatio,
      atX: 0.40,
      atY: 0.30,
      colors: const <Color>[
        Color(0xFFE9D5FF),
        Color(0xFF9B5CF6),
        Color(0xFF7C3AED),
      ],
      stops: const <double>[0, 0.58, 1],
    );

  /// `radial-gradient(circle at X% Y%, …)` d'un rond de rayon [radius] centré
  /// sur l'origine : le cercle CSS va jusqu'au coin le plus éloigné.
  static ui.Shader _cssRadial({
    required double radius,
    required double atX,
    required double atY,
    required List<Color> colors,
    required List<double> stops,
  }) {
    final double box = radius * 2;
    final Offset c = Offset(-radius + box * atX, -radius + box * atY);
    final double fx = math.max(atX, 1 - atX) * box;
    final double fy = math.max(atY, 1 - atY) * box;
    return ui.Gradient.radial(c, math.sqrt(fx * fx + fy * fy), colors, stops);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double p = Curves.easeOut.transform(press.value.clamp(0.0, 1.0));
    final double t = moving ? life.value * loopSeconds : 0;
    final double k = _k;
    final double relief = _relief;
    final double r = _faceRadius;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);

    // Décorations DERRIÈRE le disque (comme dans la maquette).
    if (live) _paintDecor(canvas, t);

    // Le disque est calé en haut de l'encombrement ; le relief occupe le bas.
    final double faceY = -relief / 2 + p * relief;

    // Ombre portée verte. Resserrée (rayon −0,13 D) pour garder l'empreinte
    // du halo de l'ancien bouton : elle ne mange pas le texte du dessous.
    final double shadowR = math.max(r - diameter * 0.13, r * 0.5);
    canvas.drawCircle(
      Offset(0, faceY + ui.lerpDouble(22 * k, 4 * k, p)!),
      shadowR,
      Paint()
        ..color = const Color(
          0xFF2AA04B,
        ).withValues(alpha: ui.lerpDouble(0.45, 0.30, p)!)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          math.max(ui.lerpDouble(18 * k, 6 * k, p)!, 1.2),
        ),
    );

    // Relief dur (#1E7A38) : immobile, le disque descend dessus à l'appui.
    canvas.drawCircle(
      Offset(0, relief / 2),
      r,
      Paint()..color = const Color(0xFF1E7A38),
    );

    // ── Le disque ───────────────────────────────────────────────────────
    canvas.translate(0, faceY);
    final Rect face = Rect.fromCircle(center: Offset.zero, radius: r);
    canvas.drawCircle(Offset.zero, r, _facePaint);
    canvas.save();
    canvas.clipPath(Path()..addOval(face));
    // Reflets internes : bas noir 14 % (7 → 4 px à l'appui), haut blanc
    // 45 % → 30 % (3 px).
    _crescent(
      canvas,
      r,
      -math.max(ui.lerpDouble(7 * k, 4 * k, p)!, 1.2),
      Colors.black.withValues(alpha: 0.14),
    );
    _crescent(
      canvas,
      r,
      math.max(3 * k, 0.9),
      Colors.white.withValues(alpha: ui.lerpDouble(0.45, 0.30, p)!),
    );

    // ── La pastille violette et le chien ────────────────────────────────
    final double pr = r * _pastilleRatio; // rayon de la pastille
    final double u = pr * 2 / 50; // 1 px de la maquette (pastille de 50)
    final double pastilleRelief = 4 * u;
    final Offset pc = Offset(0, -pastilleRelief / 2);
    // Liseré blanc 35 % (3 px).
    canvas.drawCircle(
      pc,
      pr + 3 * u,
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
    // Ombre douce 0 9 14 noir 20 %.
    canvas.drawCircle(
      pc.translate(0, 9 * u),
      pr,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.20)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(7 * u, 0.8)),
    );
    // Petit relief #5B21B6.
    canvas.drawCircle(
      pc.translate(0, pastilleRelief),
      pr,
      Paint()..color = const Color(0xFF5B21B6),
    );
    canvas.save();
    canvas.translate(pc.dx, pc.dy);
    canvas.drawCircle(Offset.zero, pr, _pastillePaint);
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: pr)),
    );
    _crescent(
      canvas,
      pr,
      math.max(2 * u, 0.7),
      Colors.white.withValues(alpha: 0.75),
    );
    canvas.restore();

    // Chien : boîte 48 × 48 de la taille de la pastille, déborde un peu.
    final double dogScale = pr * 2 / 48;
    canvas.translate(-pr, -pr);
    canvas.scale(dogScale);
    if (moving) {
      // Balancement −8° ↔ +8°, 0,9 s, ease-in-out, origine 50 % / 85 %.
      // Décalé d'un quart de période : la balade démarre tête droite.
      final double a = ui.lerpDouble(-8, 8, _yoyo(t / 0.9 + 0.25))!;
      canvas.translate(24, 40.8);
      canvas.rotate(a * math.pi / 180);
      canvas.translate(-24, -40.8);
    }
    _DogArt.paint(canvas);
    canvas.restore(); // pastille
    canvas.restore(); // découpe du disque
    canvas.restore(); // centre
  }

  /// Aller-retour 0 → 1 → 0 sur une période, chaque moitié en ease-in-out
  /// (équivalent des images clés CSS 0 % / 50 % / 100 %).
  static double _yoyo(double periods) {
    final double f = periods - periods.floorToDouble();
    final double tri = f < 0.5 ? f * 2 : 2 - f * 2;
    return Curves.easeInOut.transform(tri);
  }

  /// Ombre intérieure CSS sans flou (`inset 0 dy 0`) dans un rond de rayon
  /// [radius] centré sur l'origine : la part du rond que ne couvre pas le
  /// même rond décalé de [dy]. Le canevas est déjà découpé au rond.
  static void _crescent(Canvas canvas, double radius, double dy, Color color) {
    final Path path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromCircle(center: Offset.zero, radius: radius + 2))
      ..addOval(Rect.fromCircle(center: Offset(0, dy), radius: radius));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  // ── Feuilles et pattes (en direct seulement) ──────────────────────────
  static const List<Color> _decorColors = <Color>[
    Color(0xFF6FD98A),
    Color(0xFF9B5CF6),
    Color(0xFF8EEB9E),
    Color(0xFFB388FF),
  ];

  // Feuilles : angle sur le cercle (0° = à droite, sens horaire, comme CSS),
  // rotation propre, taille (px maquette), durée et retard du flottement.
  // Les deux feuilles du bas sont remontées sur les côtés (25° / 155° au
  // lieu de 45° / 135°) : sous le bouton il y a le texte des minutes.
  static const List<double> _leafAngles = <double>[225, 315, 25, 155];
  static const List<double> _leafRotations = <double>[-25, 40, 120, -110];
  static const List<double> _leafSizes = <double>[26, 22, 20, 18];
  static const List<double> _leafPeriods = <double>[3, 4, 5, 4.5];
  static const List<double> _leafDelays = <double>[0, 0.5, 1, 0.75];

  // Pattes : angle de départ (0° = en haut, sens horaire), taille, durée du
  // tour (18 s les grandes, 21 s les petites).
  static const List<double> _pawSizes = <double>[16, 12, 16, 12];
  static const List<double> _pawPeriods = <double>[18, 21, 18, 21];

  static final Path _leafPath = _svgPath(
    'M3 21c0-9 7-16 18-18-1 11-8 18-18 18z',
  );
  static final Path _pawPath = Path()
    ..addOval(
      Rect.fromCenter(center: const Offset(12, 14), width: 6.4, height: 7.2),
    )
    ..addOval(Rect.fromCircle(center: const Offset(7, 9.5), radius: 1.9))
    ..addOval(Rect.fromCircle(center: const Offset(17, 9.5), radius: 1.9))
    ..addOval(Rect.fromCircle(center: const Offset(9.5, 5.5), radius: 1.8))
    ..addOval(Rect.fromCircle(center: const Offset(14.5, 5.5), radius: 1.8));

  void _paintDecor(Canvas canvas, double t) {
    final double k = _k;

    // Pattes en orbite. Sous le bouton, il y a le texte des minutes : la
    // patte s'efface en passant dans l'arc du bas (±40°) pour ne jamais le
    // recouvrir, puis réapparaît.
    final double orbitR = diameter * _pawRadiusRatio;
    for (int i = 0; i < 4; i++) {
      final double start = i * math.pi / 2;
      final double orbit = start + 2 * math.pi * (t / _pawPeriods[i]);
      final double fromBottom =
          math.acos((-math.cos(orbit)).clamp(-1.0, 1.0)) * 180 / math.pi;
      final double fade = ((fromBottom - 40) / 35).clamp(0.0, 1.0);
      final double opacity = 0.9 * fade * fade * (3 - 2 * fade);
      if (opacity < 0.02) continue;
      // Plancher de lisibilité : jamais moins de 5,5 / 5 dp.
      final double sz = math.max(_pawSizes[i] * k, i.isEven ? 5.5 : 5.0);
      canvas.save();
      canvas.translate(orbitR * math.sin(orbit), -orbitR * math.cos(orbit));
      canvas.rotate(orbit + start);
      canvas.scale(sz / 24);
      canvas.translate(-12, -12);
      canvas.drawPath(
        _pawPath,
        Paint()..color = _decorColors[i].withValues(alpha: opacity),
      );
      canvas.restore();
    }

    // Feuilles. Celle du haut à droite est omise quand la pastille des
    // suiveurs occupe ce coin.
    final double lift = math.max(6 * k, 1.5);
    for (int i = 0; i < 4; i++) {
      if (badge && i == 1) continue;
      final double a = _leafAngles[i] * math.pi / 180;
      final double sz = math.max(_leafSizes[i] * k, 5.5);
      final double local = t - _leafDelays[i];
      final double dy = local <= 0 ? 0 : -lift * _yoyo(local / _leafPeriods[i]);
      final double unit = sz / 24;
      canvas.save();
      final double leafR = diameter * _leafRadiusRatios[i];
      canvas.translate(leafR * math.cos(a), leafR * math.sin(a) + dy);
      // drop-shadow(0 3px 4px rgba(30,122,56,.25)).
      canvas.save();
      canvas.translate(0, 3 * k);
      canvas.rotate(_leafRotations[i] * math.pi / 180);
      canvas.scale(unit);
      canvas.translate(-12, -12);
      canvas.drawPath(
        _leafPath,
        Paint()
          ..color = const Color(0xFF1E7A38).withValues(alpha: 0.25)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * k / unit),
      );
      canvas.restore();
      canvas.rotate(_leafRotations[i] * math.pi / 180);
      canvas.scale(unit);
      canvas.translate(-12, -12);
      canvas.drawPath(_leafPath, Paint()..color = _decorColors[i]);
      canvas.drawLine(
        const Offset(4, 20),
        const Offset(19, 5),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.6)
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _WalkJewelPainter old) =>
      old.diameter != diameter ||
      old.live != live ||
      old.moving != moving ||
      old.badge != badge ||
      old.press != press ||
      old.life != life;
}

/// La tête de chien de la maquette (viewBox 0 0 48 48, tracés du bloc
/// `const dog` du prototype, recopiés tels quels).
class _DogArt {
  _DogArt._();

  static final Path _earLeft = _svgPath(
    'M14 12c-5.5-1.8-10 2.6-10 9 0 6 2.6 12 6.4 13 2.8.7 5.6-1.2 5.6-5V17c0-2.3-.8-4.2-2-5z',
  );
  static final Path _earRight = _svgPath(
    'M34 12c5.5-1.8 10 2.6 10 9 0 6-2.6 12-6.4 13-2.8.7-5.6-1.2-5.6-5V17c0-2.3.8-4.2 2-5z',
  );
  static final Path _head = _svgPath(
    'M24 7.5c-9 0-14 6.2-14 15 0 7.4 5 14 14 14s14-6.6 14-14c0-8.800-5-15-14-15z',
  );
  static final Path _patch = _svgPath(
    'M27 9.500c5.500 1 9.500 5 10.500 11 .3 2-.6 4-2.500 4.800-3 1.200-6.500-.3-8-3.300-1.800-3.600-2-8.500 0-12.500z',
  );
  static final Path _blaze = _svgPath(
    'M24 8c-1.600 3.500-2 8-1.300 13h2.600C26 16 25.600 11.500 24 8z',
  );
  static final Path _muzzle = _svgPath(
    'M24 20.500c-5 0-8.600 3.200-8.600 7.300 0 4.300 3.600 8 8.600 8s8.600-3.700 8.600-8c0-4.100-3.600-7.300-8.600-7.300z',
  );
  static final Path _brows = _svgPath(
    'M15 15.200c1.300-1.100 3.200-1.300 4.700-.5M28.300 14.700c1.500-.8 3.400-.6 4.700.5',
  );
  static final Path _nose = _svgPath(
    'M24 24c-2.400 0-4 1.200-4 2.800 0 1.200 1.100 2.200 2.500 2.800l1.500.7 1.500-.7c1.400-.6 2.500-1.600 2.500-2.800 0-1.600-1.600-2.800-4-2.800z',
  );
  static final Path _mouth = _svgPath(
    'M24 30.300v1.500M24 31.800c-1.600 2-3.700 2-5 .6M24 31.800c1.600 2 3.700 2 5 .6',
  );
  static final Path _tongue = _svgPath(
    'M21.800 32.800c0 2.800 1 5 2.200 5s2.200-2.200 2.200-5c-.7-.6-3.700-.6-4.400 0z',
  );
  static final Path _tongueLine = _svgPath('M24 33.300v3');

  static const Color _ink = Color(0xFF3A2318);

  // Dégradés SVG en « objectBoundingBox » : calculés sur la boîte du tracé.
  static Paint _radialOn(
    Path path,
    double cx,
    double cy,
    double r,
    Color from,
    Color to,
  ) {
    final Rect b = path.getBounds();
    return Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        Offset(b.left + b.width * cx, b.top + b.height * cy),
        (b.width + b.height) / 2 * r,
        <Color>[from, to],
      );
  }

  static Paint _earPaint(Path ear) {
    final Rect b = ear.getBounds();
    return Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.linear(
        Offset(b.center.dx, b.top),
        Offset(b.center.dx, b.bottom),
        const <Color>[Color(0xFFB9713F), Color(0xFF7E4522)],
      );
  }

  static final Paint _earLeftPaint = _earPaint(_earLeft);
  static final Paint _earRightPaint = _earPaint(_earRight);
  static final Paint _headPaint = _radialOn(
    _head,
    0.38,
    0.26,
    0.80,
    const Color(0xFFFFE0B0),
    const Color(0xFFF0A455),
  );
  static final Paint _muzzlePaint = _radialOn(
    _muzzle,
    0.45,
    0.25,
    0.85,
    const Color(0xFFFFFFFF),
    const Color(0xFFFFE9CC),
  );

  static Paint _fill(Color c) => Paint()
    ..isAntiAlias = true
    ..color = c;

  static Paint _stroke(Color c, double w) => Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = w
    ..color = c;

  static final Paint _patchPaint = _fill(
    const Color(0xFFD98A45).withValues(alpha: 0.75),
  );
  static final Paint _blazePaint = _fill(const Color(0xFFFFF6E6));
  static final Paint _sheenPaint = _fill(Colors.white.withValues(alpha: 0.4));
  static final Paint _inkPaint = _fill(_ink);
  static final Paint _whitePaint = _fill(Colors.white);
  static final Paint _glintPaint = _fill(Colors.white.withValues(alpha: 0.7));
  static final Paint _noseGlintPaint = _fill(
    Colors.white.withValues(alpha: 0.8),
  );
  static final Paint _cheekPaint = _fill(
    const Color(0xFFFF8FA8).withValues(alpha: 0.6),
  );
  static final Paint _tonguePaint = _fill(const Color(0xFFFF6B8A));
  static final Paint _browPaint = _stroke(const Color(0xFF7E4522), 1.3);
  static final Paint _mouthPaint = _stroke(_ink, 1.4);
  static final Paint _tongueLinePaint = _stroke(const Color(0xFFE04A6C), 0.7);

  static Rect _oval(double cx, double cy, double rx, double ry) =>
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2);

  /// Dessine la tête dans un repère 48 × 48.
  static void paint(Canvas canvas) {
    // Oreilles tombantes, puis la tête par-dessus.
    canvas.drawPath(_earLeft, _earLeftPaint);
    canvas.drawPath(_earRight, _earRightPaint);
    canvas.drawPath(_head, _headPaint);
    // Tache sur l'œil droit, liste frontale, reflet du crâne.
    canvas.drawPath(_patch, _patchPaint);
    canvas.drawPath(_blaze, _blazePaint);
    canvas.save();
    canvas.translate(18, 12.5);
    canvas.rotate(-22 * math.pi / 180);
    canvas.drawOval(_oval(0, 0, 4.5, 2), _sheenPaint);
    canvas.restore();
    // Museau.
    canvas.drawPath(_muzzle, _muzzlePaint);
    // Yeux et reflets.
    canvas.drawOval(_oval(18.3, 20, 2.9, 3.3), _inkPaint);
    canvas.drawOval(_oval(29.7, 20, 2.9, 3.3), _inkPaint);
    canvas.drawCircle(const Offset(19.4, 18.6), 1.15, _whitePaint);
    canvas.drawCircle(const Offset(30.8, 18.6), 1.15, _whitePaint);
    canvas.drawCircle(const Offset(17.4, 21.4), 0.55, _glintPaint);
    canvas.drawCircle(const Offset(28.8, 21.4), 0.55, _glintPaint);
    // Sourcils, joues.
    canvas.drawPath(_brows, _browPaint);
    canvas.drawOval(_oval(14.3, 26, 2.2, 1.3), _cheekPaint);
    canvas.drawOval(_oval(33.7, 26, 2.2, 1.3), _cheekPaint);
    // Truffe, bouche, langue.
    canvas.drawPath(_nose, _inkPaint);
    canvas.drawOval(_oval(22.8, 25.4, 0.95, 0.55), _noseGlintPaint);
    canvas.drawPath(_mouth, _mouthPaint);
    canvas.drawPath(_tongue, _tonguePaint);
    canvas.drawPath(_tongueLine, _tongueLinePaint);
  }
}

/// Convertit un tracé SVG (`d="…"`) en [Path]. Sous-ensemble suffisant pour
/// la maquette : M L H V C S Z, en absolu comme en relatif, nombres collés
/// (« 2.8.7-5.6 »). Appelé une seule fois par tracé (champs statiques) ; le
/// projet n'a pas de paquet `path_drawing`, et on n'ajoute aucune dépendance.
Path _svgPath(String d) {
  final Path path = Path();
  final RegExp token = RegExp(r'[MmLlHhVvCcSsZz]|-?(?:\d+\.?\d*|\.\d+)');
  const Map<String, int> arity = <String, int>{
    'M': 2, 'L': 2, 'H': 1, 'V': 1, 'C': 6, 'S': 4, 'Z': 0, //
  };
  String cmd = '';
  final List<double> a = <double>[];
  double x = 0, y = 0; // point courant
  double startX = 0, startY = 0; // début du sous-tracé
  double ctrlX = 0, ctrlY = 0; // 2ᵉ point de contrôle de la dernière courbe
  bool afterCurve = false;

  void run() {
    final String c = cmd.toUpperCase();
    final bool rel = cmd != c;
    final int n = arity[c]!;
    if (n == 0) {
      path.close();
      x = startX;
      y = startY;
      afterCurve = false;
      return;
    }
    for (int i = 0; i + n <= a.length; i += n) {
      final double ox = rel ? x : 0;
      final double oy = rel ? y : 0;
      switch (c) {
        case 'M':
          x = ox + a[i];
          y = oy + a[i + 1];
          if (i == 0) {
            path.moveTo(x, y);
            startX = x;
            startY = y;
          } else {
            path.lineTo(x, y);
          }
          afterCurve = false;
        case 'L':
          x = ox + a[i];
          y = oy + a[i + 1];
          path.lineTo(x, y);
          afterCurve = false;
        case 'H':
          x = ox + a[i];
          path.lineTo(x, y);
          afterCurve = false;
        case 'V':
          y = oy + a[i];
          path.lineTo(x, y);
          afterCurve = false;
        case 'C':
          ctrlX = ox + a[i + 2];
          ctrlY = oy + a[i + 3];
          final double x1 = ox + a[i];
          final double y1 = oy + a[i + 1];
          x = ox + a[i + 4];
          y = oy + a[i + 5];
          path.cubicTo(x1, y1, ctrlX, ctrlY, x, y);
          afterCurve = true;
        case 'S':
          // 1er point de contrôle = symétrique du précédent 2ᵉ.
          final double x1 = afterCurve ? 2 * x - ctrlX : x;
          final double y1 = afterCurve ? 2 * y - ctrlY : y;
          ctrlX = ox + a[i];
          ctrlY = oy + a[i + 1];
          x = ox + a[i + 2];
          y = oy + a[i + 3];
          path.cubicTo(x1, y1, ctrlX, ctrlY, x, y);
          afterCurve = true;
      }
    }
  }

  for (final RegExpMatch m in token.allMatches(d)) {
    final String s = m[0]!;
    if (arity.containsKey(s.toUpperCase())) {
      if (cmd.isNotEmpty) run();
      cmd = s;
      a.clear();
    } else {
      a.add(double.parse(s));
    }
  }
  if (cmd.isNotEmpty) run();
  return path;
}
