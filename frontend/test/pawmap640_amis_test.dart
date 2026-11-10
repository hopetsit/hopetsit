// 640 (PAM) — amis en PHOTO sur la PawMap, « grande comme moi » (Daniel,
// 10/11 : « ma photo de profil grande, comme celles de mes amis »).
// Planche clair + sombre dessinée par le VRAI peintre de la carte
// (PawMapPinPainter.paintPhotoDot) avec les vraies polices, plus les
// contrôles du coupe-circuit kPawFriendPhoto640.
// Régénérer après un changement VOULU :
//   flutter test test/pawmap640_amis_test.dart --update-goldens
// Retour 639 (pastille + mini cœur), à vérifier aussi :
//   flutter test test/pawmap640_amis_test.dart --dart-define=PAWMAP_FRIEND_PHOTO=false
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/localization/v565/pawmap640_i18n.dart';
import 'package:hopetsit/localization/v565/v565_i18n.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';

const double _sc = 3;
const double _w = 640, _h = 500;
const double _mF = PawMapPinPainter.photoMarginFriend640;
const double _mG = PawMapPinPainter.photoMarginGlow;

void _cross(Canvas c, Offset p) {
  final paint = Paint()
    ..color = const Color(0x55000000)
    ..strokeWidth = 1 / _sc;
  c.drawLine(p.translate(-52, 0), p.translate(52, 0), paint);
  c.drawLine(p.translate(0, -52), p.translate(0, 52), paint);
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
  )..layout(maxWidth: 120);
  tp.paint(c, Offset(at.dx - tp.width / 2, at.dy));
}

/// Pose un rond photo par son ANCRE (centre du cercle) sur [at], exactement
/// comme `_photoIcon` + `_photoAnchor` de l'écran.
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
  bool verified = false,
  double? boostPhase,
  double? followPhase,
  List<Color>? ringColors,
  Color fallbackTint = PawMapLegend.owner,
  IconData fallbackIcon = Icons.pets_rounded,
  bool dashedRing = false,
  bool eyeOff = false,
}) {
  final bool withLabel = label != null && label.isNotEmpty;
  final double base = PawMapPinPainter.photoBitmapSize(size, margin: margin);
  final double h =
      PawMapPinPainter.photoBitmapSize(size, withLabel: withLabel, margin: margin);
  final double ay = PawMapPinPainter.photoAnchorY(size,
      withLabel: withLabel, margin: margin, labelAbove: labelAbove && withLabel);
  c.save();
  c.translate(at.dx - base / 2, at.dy - ay * h);
  PawMapPinPainter.paintPhotoDot(
    c,
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
    verified: verified,
    boostPhase: boostPhase,
    followPhase: followPhase,
    fallbackTint: fallbackTint,
    fallbackIcon: fallbackIcon,
    dashedRing: dashedRing,
    eyeOff: eyeOff,
    margin: margin,
  );
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
        fallbackIcon: fallbackIcon);

void _me(Canvas c, Offset at, ui.Image? avatar,
        {bool crown = false, double? boostPhase, bool friendsOnly = false}) =>
    _dot(c, at,
        avatar: avatar,
        ring: PawMapLegend.owner,
        size: PawMapLegend.meSize,
        margin: boostPhase != null
            ? _mG
            : (crown || friendsOnly
                ? PawMapPinPainter.photoMarginTight
                : PawMapPinPainter.photoMarginBare),
        label: 'Moi',
        crown: crown,
        crownSize: PawMapLegend.crownMe,
        boostPhase: boostPhase,
        dashedRing: friendsOnly,
        eyeOff: friendsOnly,
        fallbackTint: PawMapLegend.owner);

void _sheet(Canvas c, bool dark, List<ui.Image> av) {
  c.drawRect(const Rect.fromLTWH(0, 0, _w, _h),
      Paint()..color = dark ? const Color(0xFF1B2026) : const Color(0xFFEAF0E4));
  final road = Paint()
    ..color = dark ? const Color(0xFF2C343D) : const Color(0xFFFFFFFF)
    ..strokeWidth = 7;
  c.drawLine(const Offset(0, 95), const Offset(_w, 70), road);
  c.drawLine(const Offset(0, 250), const Offset(_w, 275), road);
  c.drawLine(const Offset(0, 420), const Offset(_w, 400), road);
  c.drawLine(const Offset(250, 0), const Offset(290, _h), road);

  Offset p(int col, int row) => Offset(70 + col * 125.0, 78 + row * 165.0);
  void cap(int col, int row, String t) =>
      _caption(c, p(col, row).translate(0, 66), t, dark);

  // Rangée 1 — la demande : moi, ami, ami Premium, ami boosté, ami en direct.
  _cross(c, p(0, 0));
  _me(c, p(0, 0), av[0]);
  cap(0, 0, 'Moi (56)');
  _cross(c, p(1, 0));
  _friend(c, p(1, 0), av[1]);
  cap(1, 0, 'Ami en ligne');
  _cross(c, p(2, 0));
  _friend(c, p(2, 0), av[2], crown: true, role: PawMapLegend.walker);
  cap(2, 0, 'Ami Premium');
  _cross(c, p(3, 0));
  _friend(c, p(3, 0), av[3], boostPhase: 0.5, role: PawMapLegend.owner);
  cap(3, 0, 'Ami boosté (pas de cœur)');
  _cross(c, p(4, 0));
  _friend(c, p(4, 0), av[1], label: 'Léa');
  cap(4, 0, 'Ami en direct');

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
  _friend(c, p(2, 1), null, online: false, role: PawMapLegend.walker,
      fallbackIcon: Icons.directions_walk_rounded);
  cap(2, 1, 'Ami sans photo');
  _cross(c, p(3, 1));
  _friend(c, p(3, 1), av[1], dimmed: true, label: 'Max');
  cap(3, 1, 'Signal perdu');
  _cross(c, p(4, 1));
  _friend(c, p(4, 1), av[2], followPhase: 0.25, label: 'Tom');
  cap(4, 1, 'Suivi en direct (violet)');

  // Rangée 3 — « moi » dans tous ses états + l'ami à côté de moi.
  _cross(c, p(0, 2));
  _me(c, p(0, 2), av[0], crown: true);
  cap(0, 2, 'Moi Premium');
  _cross(c, p(1, 2));
  _me(c, p(1, 2), av[0], boostPhase: 0.5);
  cap(1, 2, 'Moi boosté');
  _cross(c, p(2, 2));
  _me(c, p(2, 2), av[0], friendsOnly: true);
  cap(2, 2, 'Moi, amis seulement');
  // Côte à côte : même photo de 56, l'ami porte en plus son anneau rose.
  _cross(c, p(3, 2).translate(20, 0));
  _me(c, p(3, 2).translate(20, 0), av[0]);
  _cross(c, p(4, 2).translate(-15, 0));
  _friend(c, p(4, 2).translate(-15, 0), av[3], crown: true);
  _caption(c, p(3, 2).translate(62, 66), 'Moi et un ami, côte à côte', dark);
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
      c.drawArc(const Rect.fromLTWH(50, 62, 20, 14), 0.3, 2.5, false,
          Paint()
            ..color = const Color(0xFF9E1F0B)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }, scale: 2);

Future<Uint8List> _rgba(ui.Image img) async =>
    (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();

/// Nombre de pixels « rose cœur » (dégradé #F73CC0 → #D9159F) dans [box].
int _heartPixels(Uint8List px, int w, Rect box) {
  var n = 0;
  for (var y = box.top.floor(); y < box.bottom.ceil(); y++) {
    for (var x = box.left.floor(); x < box.right.ceil(); x++) {
      final i = (y * w + x) * 4;
      final r = px[i], g = px[i + 1], b = px[i + 2];
      if (r >= 205 && g <= 75 && b >= 140 && b <= 205) n++;
    }
  }
  return n;
}

void main() {
  // ── Coupe-circuit : les constantes dérivées ──────────────────────────────
  test('640 — coupe-circuit : tailles et rayons dérivés', () {
    expect(kPawFriendPin639, kPawFriendPastille639 && !kPawFriendPhoto640);
    if (kPawFriendPhoto640) {
      expect(kPawFriendSize640, PawMapLegend.meSize); // 56, comme « moi »
      expect(kPawFriendCrown640, PawMapLegend.crownMe);
      expect(kPawFriendBoxR640, 35.5); // photo 28 + liseré 3 + anneau 4 + 0,5
      expect(kPawFriendLabelR640, 35);
      expect(kPawFriendPin639, isFalse);
    } else {
      expect(kPawFriendSize640, PawMapLegend.friendSize); // 50, comme avant
      expect(kPawFriendCrown640, PawMapLegend.crownFriend);
      expect(kPawFriendBoxR640, 27.5);
      expect(kPawFriendLabelR640, 25);
      expect(kPawFriendPin639, kPawFriendPastille639);
    }
  });

  test('640 — « moi » jamais plus petit qu\'un ami', () {
    expect(PawMapLegend.meSize >= kPawFriendSize640, isTrue);
    expect(PawMapLegend.crownMe >= kPawFriendCrown640, isTrue);
  });

  test('640 — image d\'un ami : pas plus lourde que l\'ami d\'avant le 639', () {
    final double before =
        PawMapPinPainter.photoBitmapSize(PawMapLegend.friendSize, margin: _mG); // 110
    expect(before, 110);
    if (kPawFriendPhoto640) {
      final double now = PawMapPinPainter.photoBitmapSize(kPawFriendSize640, margin: _mF);
      expect(now, 108);
      expect(now <= before, isTrue);
      // l'anneau rose (7) + la lueur tiennent dans la marge
      expect(_mF > kPawFriendOut640 + 12, isTrue);
    }
  });

  test('640 — le cœur : en haut à gauche, à cheval sur l\'anneau rose', () {
    const c = Offset(100, 100);
    final h = pawFriendHeartCenter640(c, 28);
    expect(h.dx < c.dx && h.dy < c.dy, isTrue);
    expect((h - c).distance, closeTo(28 + kPawFriendWhite640, 0.001));
    // jamais sous la couronne (haut-droite)
    final crown = PawMapPinPainter.crownCenter(c, 28, kPawFriendCrown640);
    expect((crown - h).distance > (kPawFriendHeart640 + kPawFriendCrown640) / 2, isTrue);
  });

  test('640 — textes légende + aide dans les 9 langues', () {
    const langs = ['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
    const keys = ['pawmap640_legend_friend', 'help640_friend_b'];
    for (final l in langs) {
      for (final k in keys) {
        expect(pawmap640I18n[l]?[k]?.trim().isNotEmpty, isTrue, reason: '$l / $k');
      }
    }
    expect(pawmap640I18n.keys.toSet(), langs.toSet());
    // branchés dans le pack chargé par l'app
    expect(v565Packs.contains(pawmap640I18n), isTrue);
    // le français ne doit pas être resté dans une autre langue
    final fr = pawmap640I18n['fr']!;
    for (final l in langs.where((l) => l != 'fr')) {
      for (final k in keys) {
        expect(pawmap640I18n[l]![k] == fr[k], isFalse, reason: '$l / $k = français');
      }
    }
  });

  // ── Rendu : le cœur n'apparaît qu'avec le halo d'ami ─────────────────────
  testWidgets('640 — cœur présent sur un ami, absent sous PawBoost / suivi / moi',
      (tester) async {
    final found = <String, int>{};
    await tester.runAsync(() async {
      await ensurePawPinFonts();
      Future<int> count(String name, double margin,
          {required Color ring, double? boost, double? follow}) async {
        const size = PawMapLegend.meSize;
        final double side = PawMapPinPainter.photoBitmapSize(size, margin: margin);
        final img = await renderPinImage(side, side, (c) {
          PawMapPinPainter.paintPhotoDot(c,
              avatar: null,
              ringColor: ring,
              size: kPawFriendPhoto640 || ring != PawMapLegend.friend
                  ? size
                  : PawMapLegend.friendSize,
              boostPhase: boost,
              followPhase: follow,
              fallbackTint: PawMapLegend.sitter,
              margin: margin);
        }, scale: 2);
        final px = await _rgba(img);
        final ctr = Offset(margin + size / 2, margin + size / 2);
        final hc = pawFriendHeartCenter640(ctr, size / 2);
        // cœur du badge seulement (rayon 6) : hors anneau rose (#FF5AD2).
        final n = _heartPixels(
            px, img.width, Rect.fromCircle(center: hc * 2, radius: 12));
        img.dispose();
        return found[name] = n;
      }

      await count('ami', kPawFriendPhoto640 ? _mF : _mG, ring: PawMapLegend.friend);
      await count('ami boosté', _mG, ring: PawMapLegend.friend, boost: 0.5);
      await count('ami suivi', _mG, ring: PawMapLegend.friend, follow: 0.25);
      await count('moi', PawMapPinPainter.photoMarginBare, ring: PawMapLegend.sitter);
    });
    // ignore: avoid_print
    print('640 pixels cœur : $found');
    if (kPawFriendPhoto640) {
      expect(found['ami']! > 150, isTrue, reason: 'cœur attendu : $found');
    } else {
      expect(found['ami'], 0, reason: 'pas de cœur sur l\'ancien rond : $found');
    }
    expect(found['ami boosté'], 0);
    expect(found['ami suivi'], 0);
    expect(found['moi'], 0);
  });

  // ── Planche (golden) + copie de preuve ───────────────────────────────────
  for (final dark in [false, true]) {
    testWidgets('640 — planche amis en photo — ${dark ? 'sombre' : 'clair'}',
        (tester) async {
      ui.Image? board;
      Uint8List? png;
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
        png = (await board!.toByteData(format: ui.ImageByteFormat.png))!
            .buffer
            .asUint8List();
        final out = Platform.environment['PAWMAP640_OUT'];
        if (out != null && out.isNotEmpty) {
          final name =
              'planche_${kPawFriendPhoto640 ? '640' : 'retour639'}_${dark ? 'sombre' : 'clair'}.png';
          File('$out/$name').writeAsBytesSync(png!);
        }
      });
      expect(board, isNotNull);
      expect(png, isNotNull);
      if (kPawFriendPhoto640) {
        await expectLater(
            board!,
            matchesGoldenFile(
                'goldens/pawmap640/planche_${dark ? 'sombre' : 'clair'}.png'));
      }
    });
  }
}
