// 641 (PAM) — Daniel, 10/11 : « les pastilles amis sont trop grandes, il
// faudra les faire juste un peu plus grosses que les pastilles normales ».
// Une pastille normale = disque de 32 pt (kPawPinDiscR639 × 2). L'ami du 640
// faisait 70 pt tout compris (2,2 ×). Il fait maintenant 36 pt (+12,5 %).
// Tout est MESURÉ sur l'image produite par le vrai peintre de la carte.
// Planche à regarder (clair + sombre) :
//   PAM641_OUT=/un/dossier flutter test test/pam641_friend_size_test.dart
// Régénérer après un changement VOULU :
//   flutter test test/pam641_friend_size_test.dart --update-goldens
// Retour aux tailles du 640 :
//   flutter test test/pam641_friend_size_test.dart --dart-define=PAWMAP_FRIEND_SMALL=false
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';

const double _mF = PawMapPinPainter.photoMarginFriend640;
const double _mG = PawMapPinPainter.photoMarginGlow;
const bool _on = kPawFriendPhoto640 && kPawFriendSmall641;

Future<Uint8List> _rgba(ui.Image img) async =>
    (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();

/// Largeur (en pixels) de la plage OPAQUE (alpha ≥ 230) qui contient [x0]
/// sur la ligne [y] : le diamètre du rond plein, sans ombre ni lueur.
int _solidRun(Uint8List px, int w, int x0, int y) {
  bool solid(int x) => x >= 0 && x < w && px[(y * w + x) * 4 + 3] >= 230;
  if (!solid(x0)) return 0;
  var a = x0, b = x0;
  while (solid(a - 1)) {
    a--;
  }
  while (solid(b + 1)) {
    b++;
  }
  return b - a + 1;
}

/// Alpha le plus fort sur le bord (1 px) de l'image : > 0 = dessin coupé.
int _maxEdgeAlpha(Uint8List px, int w, int h) {
  var m = 0;
  for (var x = 0; x < w; x++) {
    m = math.max(m, px[x * 4 + 3]);
    m = math.max(m, px[((h - 1) * w + x) * 4 + 3]);
  }
  for (var y = 0; y < h; y++) {
    m = math.max(m, px[(y * w) * 4 + 3]);
    m = math.max(m, px[(y * w + w - 1) * 4 + 3]);
  }
  return m;
}

/// Rose du disque du cœur (dégradé #F73CC0 → #D9159F), SANS l'anneau rose
/// (#FF5AD2, vert 90) ni son ombre portée sur l'anneau (rouge < 215 dès que
/// le vert passe sous 63).
bool _isHeart(int r, int g, int b) => r >= 215 && g <= 62 && b >= 150 && b <= 200;

/// Image d'un ami fabriquée COMME l'écran (`_photoIcon`) : élargie quand
/// l'étiquette dépasse, rond recentré. Renvoie l'image et le centre du rond.
Future<(ui.Image, Offset)> _friendImage({
  String? label,
  bool labelAbove = false,
  bool crown = false,
  bool online = false,
  int pin618 = 0,
  double? boost,
  double? follow,
  ui.Image? avatar,
  double scale = 4,
}) async {
  const double size = kPawFriendSize640;
  final bool halo = boost != null || follow != null;
  final double margin = (kPawFriendPhoto640 && !halo) ? _mF : _mG;
  final bool withLabel = label != null && label.isNotEmpty;
  final double base = PawMapPinPainter.photoBitmapSize(size, margin: margin);
  final double h =
      PawMapPinPainter.photoBitmapSize(size, withLabel: withLabel, margin: margin);
  final double w =
      withLabel ? math.max(base, PawMapPinPainter.photoLabelWidth(label)) : base;
  final double dx = (w - base) / 2;
  final img = await renderPinImage(w, h, (c) {
    c.translate(dx, 0);
    PawMapPinPainter.paintPhotoDot(c,
        avatar: avatar,
        ringColor: PawMapLegend.friend,
        size: size,
        label: label,
        labelAbove: labelAbove && withLabel,
        crown: crown,
        crownSize: kPawFriendCrown640,
        online: online,
        offlineDot: true,
        boostPhase: boost,
        followPhase: follow,
        fallbackTint: PawMapLegend.sitter,
        fallbackIcon: Icons.home_rounded,
        margin: margin,
        pin618: pin618);
  }, scale: scale);
  final double cy = margin +
      size / 2 +
      (labelAbove && withLabel ? PawMapPinPainter.photoLabelZoneFor(margin) : 0);
  return (img, Offset(dx + margin + size / 2, cy));
}

// ── Planche ────────────────────────────────────────────────────────────────
const double _sc = 3;
const double _w = 640, _h = 430;

void _cross(Canvas c, Offset p) {
  final paint = Paint()
    ..color = const Color(0x55000000)
    ..strokeWidth = 1 / _sc;
  c.drawLine(p.translate(-34, 0), p.translate(34, 0), paint);
  c.drawLine(p.translate(0, -34), p.translate(0, 34), paint);
}

void _caption(Canvas c, Offset at, String text, bool dark) {
  final tp = TextPainter(
    text: TextSpan(
        text: text,
        style: TextStyle(
            fontFamily: kPawPinInter,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: dark ? const Color(0xFFFFE9DC) : const Color(0xFF3A1F14))),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout(maxWidth: 104);
  tp.paint(c, Offset(at.dx - tp.width / 2, at.dy));
}

/// Pastille normale posée par son ancre (centre du disque) sur [at].
void _pin(Canvas c, Offset at, PawPinSpec639 s) {
  final l = pawPinLayout639(s);
  c.save();
  c.translate(at.dx - l.cx, at.dy - l.cy);
  paintPin639(c, s);
  c.restore();
}

/// Rond photo posé par son ancre (centre du cercle), comme l'écran.
void _dot(
  Canvas c,
  Offset at, {
  required ui.Image? avatar,
  required Color ring,
  required double size,
  required double margin,
  String? label,
  bool labelAbove = false,
  bool crown = false,
  double crownSize = PawMapLegend.crownFriend,
  bool online = false,
  bool offlineDot = false,
  bool dimmed = false,
  double? boostPhase,
  double? followPhase,
  List<Color>? ringColors,
  Color fallbackTint = PawMapLegend.owner,
  IconData fallbackIcon = Icons.pets_rounded,
  int pin618 = 0,
}) {
  final bool withLabel = label != null && label.isNotEmpty;
  final double base = PawMapPinPainter.photoBitmapSize(size, margin: margin);
  final double h =
      PawMapPinPainter.photoBitmapSize(size, withLabel: withLabel, margin: margin);
  final double ay = PawMapPinPainter.photoAnchorY(size,
      withLabel: withLabel, margin: margin, labelAbove: labelAbove && withLabel);
  c.save();
  c.translate(at.dx - base / 2, at.dy - ay * h);
  PawMapPinPainter.paintPhotoDot(c,
      avatar: avatar,
      ringColor: ring,
      ringColors: ringColors,
      size: size,
      label: label,
      labelAbove: labelAbove && withLabel,
      crown: crown,
      crownSize: crownSize,
      online: online,
      offlineDot: offlineDot,
      dimmed: dimmed,
      boostPhase: boostPhase,
      followPhase: followPhase,
      fallbackTint: fallbackTint,
      fallbackIcon: fallbackIcon,
      margin: margin,
      pin618: pin618);
  c.restore();
}

void _friend(
  Canvas c,
  Offset at,
  ui.Image? avatar, {
  String? label,
  bool labelAbove = false,
  bool crown = false,
  bool online = true,
  bool dimmed = false,
  double? boostPhase,
  double? followPhase,
  List<Color>? ringColors,
  Color role = PawMapLegend.sitter,
  IconData fallbackIcon = Icons.home_rounded,
  int pin618 = 0,
}) =>
    _dot(c, at,
        avatar: avatar,
        ring: PawMapLegend.friend,
        size: kPawFriendSize640,
        margin: (kPawFriendPhoto640 && boostPhase == null && followPhase == null)
            ? _mF
            : _mG,
        label: label,
        labelAbove: labelAbove,
        crown: crown,
        crownSize: kPawFriendCrown640,
        online: online,
        offlineDot: true,
        dimmed: dimmed,
        boostPhase: boostPhase,
        followPhase: followPhase,
        ringColors: ringColors,
        fallbackTint: role,
        fallbackIcon: fallbackIcon,
        pin618: pin618);

void _sheet(Canvas c, bool dark, List<ui.Image> av) {
  c.drawRect(const Rect.fromLTWH(0, 0, _w, _h),
      Paint()..color = dark ? const Color(0xFF1B2026) : const Color(0xFFEAF0E4));
  final road = Paint()
    ..color = dark ? const Color(0xFF2C343D) : const Color(0xFFFFFFFF)
    ..strokeWidth = 7;
  c.drawLine(const Offset(0, 80), const Offset(_w, 62), road);
  c.drawLine(const Offset(0, 215), const Offset(_w, 235), road);
  c.drawLine(const Offset(0, 360), const Offset(_w, 345), road);
  c.drawLine(const Offset(300, 0), const Offset(330, _h), road);

  Offset p(int col, int row) => Offset(55 + col * 106.0, 62 + row * 140.0);
  void cap(int col, int row, String t) =>
      _caption(c, p(col, row).translate(0, 50), t, dark);

  // Rangée 1 — la demande : la pastille normale, puis l'ami à côté.
  _cross(c, p(0, 0));
  _pin(c, p(0, 0), PawPinSpec639(roles: const ['sitter']));
  cap(0, 0, 'Pastille normale (32)');
  _cross(c, p(1, 0));
  _friend(c, p(1, 0), av[1]);
  cap(1, 0, 'Ami en ligne (36)');
  _cross(c, p(2, 0));
  _friend(c, p(2, 0), av[2], crown: true, role: PawMapLegend.walker);
  cap(2, 0, 'Ami Premium');
  _cross(c, p(3, 0));
  _pin(c, p(3, 0),
      PawPinSpec639(roles: const ['walker'], halo: PawHalo639.boost, premium: true));
  cap(3, 0, 'Pastille boostée Premium');
  _cross(c, p(4, 0));
  _friend(c, p(4, 0), av[3], boostPhase: 0.5, role: PawMapLegend.owner);
  cap(4, 0, 'Ami boosté (pas de cœur)');
  _cross(c, p(5, 0));
  _friend(c, p(5, 0), av[1], label: 'Léa');
  cap(5, 0, 'Ami en direct');

  // Rangée 2 — variantes.
  _cross(c, p(0, 1));
  _friend(c, p(0, 1), av[2],
      label: 'Vu il y a 5 j',
      online: false,
      ringColors: const [PawMapLegend.owner, PawMapLegend.sitter, PawMapLegend.walker]);
  cap(0, 1, 'Ami 3 rôles, hors ligne');
  _cross(c, p(1, 1));
  _friend(c, p(1, 1), av[3], label: 'Vu il y a 2 h', labelAbove: true, crown: true);
  cap(1, 1, 'Étiquette au-dessus');
  _cross(c, p(2, 1));
  _friend(c, p(2, 1), null,
      online: false,
      role: PawMapLegend.walker,
      fallbackIcon: Icons.directions_walk_rounded);
  cap(2, 1, 'Ami sans photo');
  _cross(c, p(3, 1));
  _friend(c, p(3, 1), av[1], dimmed: true, label: 'Max');
  cap(3, 1, 'Signal perdu');
  _cross(c, p(4, 1));
  _friend(c, p(4, 1), av[2], followPhase: 0.25, label: 'Tom');
  cap(4, 1, 'Suivi en direct (violet)');
  _cross(c, p(5, 1));
  _friend(c, p(5, 1), av[3], crown: true, pin618: 1);
  cap(5, 1, 'Ami Premium épinglé n° 1');

  // Rangée 3 — côte à côte : pastilles normales, amis, moi.
  final Offset q = p(0, 2);
  _pin(c, q.translate(0, 0), PawPinSpec639(roles: const ['owner']));
  _friend(c, q.translate(44, 0), av[1]);
  _pin(c, q.translate(88, 0), PawPinSpec639(roles: const ['sitter'], available: true));
  _friend(c, q.translate(132, 0), av[3], crown: true, role: PawMapLegend.owner);
  _pin(c, q.translate(176, 0), PawPinSpec639(roles: const ['walker'], live: true));
  _caption(c, q.translate(88, 50), 'Amis parmi les pastilles normales', dark);
  _cross(c, p(3, 2));
  _friend(c, p(3, 2), av[2], pin618: 4, role: PawMapLegend.walker);
  cap(3, 2, 'Ami chef de meute');
  _cross(c, p(4, 2).translate(-12, 0));
  _dot(c, p(4, 2).translate(-12, 0),
      avatar: av[0],
      ring: PawMapLegend.owner,
      size: PawMapLegend.meSize,
      margin: PawMapPinPainter.photoMarginBare,
      label: 'Moi',
      crownSize: PawMapLegend.crownMe,
      fallbackTint: PawMapLegend.owner);
  _cross(c, p(5, 2));
  _friend(c, p(5, 2), av[3]);
  _caption(c, p(4, 2).translate(42, 50), 'Moi (56) et un ami (36)', dark);
}

/// Portrait de synthèse (aucune photo réelle dans le dépôt de tests).
Future<ui.Image> _portrait(Color bg, Color skin, Color hair) =>
    renderPinImage(120, 120, (c) {
      c.drawRect(const Rect.fromLTWH(0, 0, 120, 120),
          Paint()
            ..shader = ui.Gradient.linear(
                Offset.zero, const Offset(120, 120), [bg, Color.lerp(bg, Colors.white, 0.45)!]));
      c.drawOval(const Rect.fromLTWH(18, 84, 84, 70), Paint()..color = hair);
      c.drawCircle(const Offset(60, 54), 27, Paint()..color = hair);
      c.drawOval(const Rect.fromLTWH(38, 34, 44, 52), Paint()..color = skin);
      c.drawCircle(const Offset(51, 58), 2.6, Paint()..color = const Color(0xFF3A1F14));
      c.drawCircle(const Offset(69, 58), 2.6, Paint()..color = const Color(0xFF3A1F14));
    }, scale: 2);

void main() {
  // ── Tailles ──────────────────────────────────────────────────────────────
  test('641 — ami : +10 à +15 % d\'une pastille normale, pas plus', () {
    const double normal = 2 * kPawPinDiscR639;
    expect(normal, 32);
    const double total = kPawFriendSize640 + 2 * kPawFriendOut640;
    if (_on) {
      expect(total, kPawFriendTotal641);
      expect(total, 36);
      expect(total / normal >= 1.10, isTrue, reason: '${total / normal}');
      expect(total / normal <= 1.15, isTrue, reason: '${total / normal}');
      expect(kPawFriendSize640, 30);
      expect(_mF, 16);
      expect(PawMapPinPainter.photoBitmapSize(kPawFriendSize640, margin: _mF), 62);
      // boîte anti-chevauchement et rayon d'étiquette : le rond, pas plus
      expect(kPawFriendBoxR640, 18.5);
      expect(kPawFriendLabelR640, 18);
    } else if (kPawFriendPhoto640) {
      expect(total, 70); // coupe-circuit : exactement le 640
      expect(_mF, 26);
    }
  });

  test('641 — « moi » inchangé (56), jamais plus petit qu\'un ami', () {
    expect(PawMapLegend.meSize, 56);
    expect(PawMapLegend.meSize >= kPawFriendSize640 + 2 * kPawFriendOut640 || !_on, isTrue);
  });

  test('641 — badges : dans l\'image, jamais l\'un sur l\'autre', () {
    if (!_on) return;
    const double r = kPawFriendSize640 / 2;
    const c = Offset(_mF + r, _mF + r);
    const double side = 2 * (_mF + r); // 62
    final heart = pawFriendHeartCenter640(c, r);
    final crown = PawMapPinPainter.crownCenter(c, r, kPawFriendCrown640);
    final dot = pawOnlineDotCenter(c, r, kPawFriendDot641);
    final pinHeart = pawFriendCorner641(c, r, -1, 1); // ami : sous le cœur
    final pinBoost = pawFriendCorner641(c, r, -1, -1); // boosté : pas de cœur
    // le cœur est exactement sur le milieu de l'anneau rose
    expect((heart - c).distance,
        closeTo(r + kPawFriendWhite640 + kPawFriendRing640 / 2, 0.001));
    void inside(Offset p, double s, String what) {
      expect(p.dx - s / 2 >= 1 && p.dy - s / 2 >= 1, isTrue, reason: what);
      expect(p.dx + s / 2 <= side - 1 && p.dy + s / 2 <= side - 1, isTrue, reason: what);
    }

    inside(heart, kPawFriendHeart640, 'cœur');
    inside(crown, kPawFriendCrown640, 'couronne');
    inside(dot, kPawFriendDot641, 'point en ligne');
    inside(pinHeart, 16, 'pin 618');
    void apart(Offset a, double sa, Offset b, double sb, String what) =>
        expect((a - b).distance >= (sa + sb) / 2, isTrue,
            reason: '$what : ${(a - b).distance}');
    apart(heart, kPawFriendHeart640, crown, kPawFriendCrown640, 'cœur / couronne');
    apart(heart, kPawFriendHeart640, pinHeart, 16, 'cœur / pin 618');
    apart(pinHeart, 16, dot, kPawFriendDot641, 'pin 618 / point');
    apart(pinBoost, 16, crown, kPawFriendCrown640, 'pin 618 / couronne (boosté)');
    apart(heart, kPawFriendHeart640, dot, kPawFriendDot641, 'cœur / point');
  });

  // ── Rendu mesuré ─────────────────────────────────────────────────────────
  testWidgets('641 — diamètres mesurés sur l\'image : normale 32, ami 36',
      (tester) async {
    late double normal, normalBoost, friend, boosted;
    await tester.runAsync(() async {
      const double sc = 4;
      final spec = PawPinSpec639(roles: const ['sitter']);
      final l = pawPinLayout639(spec);
      final pin = await renderPinImage(l.w, l.h, (c) => paintPin639(c, spec), scale: sc);
      var px = await _rgba(pin);
      // sous l'icône blanche (opaque elle aussi) : la ligne du centre convient
      normal = _solidRun(px, pin.width, (l.cx * sc).round(), (l.cy * sc).round()) / sc;
      pin.dispose();

      final specB = PawPinSpec639(roles: const ['sitter'], halo: PawHalo639.boost);
      final lb = pawPinLayout639(specB);
      final pinB =
          await renderPinImage(lb.w, lb.h, (c) => paintPin639(c, specB), scale: sc);
      px = await _rgba(pinB);
      normalBoost =
          _solidRun(px, pinB.width, (lb.cx * sc).round(), (lb.cy * sc).round()) / sc;
      pinB.dispose();

      final (img, ctr) = await _friendImage(scale: sc);
      px = await _rgba(img);
      friend = _solidRun(px, img.width, (ctr.dx * sc).round(), (ctr.dy * sc).round()) / sc;
      img.dispose();

      // boosté : plus d'anneau rose → le rond seul (30) + l'anneau du halo
      final (imgB, ctrB) = await _friendImage(scale: sc, boost: 0.5);
      px = await _rgba(imgB);
      boosted =
          _solidRun(px, imgB.width, (ctrB.dx * sc).round(), (ctrB.dy * sc).round()) / sc;
      imgB.dispose();
    });
    // ignore: avoid_print
    print('641 diamètres mesurés (pt) : normale $normal, normale boostée '
        '$normalBoost, ami $friend, ami boosté $boosted');
    expect(normal, closeTo(32, 0.75));
    if (_on) {
      expect(friend, closeTo(36, 0.75));
      expect(friend / normal >= 1.08 && friend / normal <= 1.17, isTrue,
          reason: 'ratio ${friend / normal}');
      // boosté : jamais plus de +15 % d'une pastille normale à halo (43 pt)
      expect(boosted <= 2 * kPawPinHaloR639 * 1.15, isTrue,
          reason: 'ami boosté : $boosted');
    } else if (kPawFriendPhoto640) {
      expect(friend, closeTo(70, 0.75));
    }
  });

  testWidgets('641 — rien de coupé : le bord de l\'image est vide', (tester) async {
    final edges = <String, int>{};
    await tester.runAsync(() async {
      Future<void> edge(String name, Future<(ui.Image, Offset)> f) async {
        final (img, _) = await f;
        final px = await _rgba(img);
        edges[name] = _maxEdgeAlpha(px, img.width, img.height);
        img.dispose();
      }

      await edge('ami', _friendImage(online: true));
      await edge('ami Premium épinglé',
          _friendImage(online: true, crown: true, pin618: 1));
      await edge('étiquette dessous',
          _friendImage(online: true, crown: true, label: 'Vu il y a 12 min'));
      await edge(
          'étiquette dessus',
          _friendImage(
              online: true, crown: true, label: 'Vu il y a 12 min', labelAbove: true));
      await edge('ami boosté',
          _friendImage(online: true, crown: true, pin618: 2, boost: 0.5));
      await edge('ami suivi', _friendImage(online: true, crown: true, follow: 0.25));
    });
    // ignore: avoid_print
    print('641 alpha max au bord de l\'image : $edges');
    if (!kPawFriendPhoto640) return;
    for (final e in edges.entries) {
      expect(e.value <= 6, isTrue, reason: '${e.key} coupé : alpha ${e.value} au bord');
    }
  });

  testWidgets('641 — le cœur : présent, lisible, centré sur l\'anneau rose',
      (tester) async {
    late int n;
    late Offset centre, want;
    late double wide, high;
    await tester.runAsync(() async {
      const double sc = 4;
      final (img, ctr) = await _friendImage(scale: sc);
      final px = await _rgba(img);
      want = pawFriendHeartCenter640(ctr, kPawFriendSize640 / 2);
      final box = Rect.fromCircle(center: want * sc, radius: (kPawFriendHeart640 / 2 + 1) * sc);
      var x0 = 1 << 30, x1 = -1, y0 = 1 << 30, y1 = -1;
      n = 0;
      for (var y = box.top.floor(); y < box.bottom.ceil(); y++) {
        for (var x = box.left.floor(); x < box.right.ceil(); x++) {
          final i = (y * img.width + x) * 4;
          if (_isHeart(px[i], px[i + 1], px[i + 2])) {
            n++;
            x0 = math.min(x0, x);
            x1 = math.max(x1, x);
            y0 = math.min(y0, y);
            y1 = math.max(y1, y);
          }
        }
      }
      // Centre du disque rose : milieu gauche-droite, et bas du disque moins
      // son rayon (le haut porte un reflet blanc, le barycentre serait
      // faussé par le cœur blanc, plus large en haut).
      wide = n == 0 ? 0 : (x1 - x0 + 1) / sc;
      high = n == 0 ? 0 : (y1 - y0 + 1) / sc;
      centre = n == 0
          ? Offset.zero
          : Offset((x0 + x1 + 1) / 2 / sc, (y1 + 1) / sc - wide / 2);
      img.dispose();
    });
    // ignore: avoid_print
    print('641 cœur : $n px roses (échelle 4), disque $wide × $high pt, '
        'centre mesuré $centre, attendu $want');
    if (!kPawFriendPhoto640) {
      expect(n, 0);
      return;
    }
    // un disque de 16 pt à l'échelle 4 ≈ 3 200 px, moins le cœur blanc
    expect(n > 900, isTrue, reason: 'cœur trop petit : $n px');
    expect((centre - want).distance <= 0.5, isTrue,
        reason: 'cœur décentré : $centre au lieu de $want');
    // disque rose = badge − liseré blanc 1,5 de chaque côté
    expect(wide, closeTo(kPawFriendHeart640 - 3, 0.75));
    expect(high <= wide + 0.25, isTrue, reason: 'disque $wide × $high');
  });

  // ── Planche (golden) + copie à regarder ──────────────────────────────────
  for (final dark in [false, true]) {
    testWidgets('641 — planche amis à 36 pt — ${dark ? 'sombre' : 'clair'}',
        (tester) async {
      ui.Image? board;
      await tester.runAsync(() async {
        await (FontLoader('PawSymbols')
              ..addFont(rootBundle.load('assets/pawsymbols/PawSymbolsRounded.ttf')))
            .load();
        await ensurePawPinFonts();
        final av = <ui.Image>[
          await _portrait(const Color(0xFFFFB199), const Color(0xFFF2C6A0), const Color(0xFF4A2A18)),
          await _portrait(const Color(0xFF9CC5FF), const Color(0xFFE8B98F), const Color(0xFF8A3B12)),
          await _portrait(const Color(0xFF9EE6B8), const Color(0xFFC98E62), const Color(0xFF2A1408)),
          await _portrait(const Color(0xFFFFD98A), const Color(0xFFF6D3B3), const Color(0xFFC96A1B)),
        ];
        board = await renderPinImage(_w, _h, (c) => _sheet(c, dark, av), scale: _sc);
        final out = Platform.environment['PAM641_OUT'];
        if (out != null && out.isNotEmpty) {
          final png = (await board!.toByteData(format: ui.ImageByteFormat.png))!
              .buffer
              .asUint8List();
          File('$out/planche_${_on ? '641' : 'coupe_circuit'}_${dark ? 'sombre' : 'clair'}.png')
              .writeAsBytesSync(png);
        }
      });
      expect(board, isNotNull);
      if (_on) {
        await expectLater(
            board!,
            matchesGoldenFile(
                'goldens/pawmap641/planche_${dark ? 'sombre' : 'clair'}.png'));
      }
    });
  }
}
