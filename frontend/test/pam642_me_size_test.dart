// 642 (PAM, Daniel 11/11) — tailles des pastilles, alignées sur le site
// (website/src/lib/pawmapLegend.ts, commit e90e10ab) :
//   · ami : photo 30 → 34, soit 40 pt avec le liseré et l'anneau rose ;
//   · « Moi » : 56 → 40 pt, exactement la taille d'un ami ; contour 2 +
//     liseré 1, couronne / fusée / œil barré de 16 ; coupe-circuit
//     kPawMeSmall642 (jumeau de ME_SMALL_1111).
// Mesures faites SUR L'IMAGE dessinée (pas seulement sur les constantes).
// Copie à regarder : PAM642_OUT=<dossier> flutter test test/pam642_me_size_test.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/widgets/pawmap_boost642.dart';
import 'package:hopetsit/views/map/widgets/pawmap_overlap607.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';

Future<Uint8List> _rgba(ui.Image img) async =>
    (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();

/// Largeur (px) de la plage OPAQUE (alpha ≥ 230) qui contient [x0] sur la
/// ligne [y] : le diamètre du rond plein, sans ombre ni lueur.
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

/// La marge que choisit la carte pour « Moi » (voir `_photoIcon`).
double _meMargin({bool boosted = false, bool crown = false, bool eyeOff = false}) =>
    boosted
        ? PawMapPinPainter.photoMarginGlow
        : ((crown || eyeOff)
            ? PawMapPinPainter.photoMarginTight
            : PawMapPinPainter.photoMarginBare);

void _paintMe(Canvas c,
    {bool crown = false, bool boosted = false, bool friendsOnly = false, String? label}) {
  PawMapPinPainter.paintPhotoDot(c,
      avatar: null,
      ringColor: PawMapLegend.owner,
      size: kPawMeSize642,
      me: true,
      label: label,
      crown: crown,
      crownSize: kPawMeCrown642,
      boostPhase: boosted ? 0.5 : null,
      dashedRing: friendsOnly,
      eyeOff: friendsOnly,
      fallbackTint: PawMapLegend.owner,
      margin: _meMargin(boosted: boosted, crown: crown, eyeOff: friendsOnly));
}

void main() {
  test('642 — constantes : « Moi » = un ami tout compris = 40 (site ME_PX_1111)', () {
    expect(kPawMeSmall642, isTrue);
    expect(kPawMeSize642, 40);
    expect(kPawFriendSize640, 34); // site FRIEND_PX_641
    expect(kPawFriendSize640 + 2 * kPawFriendOut640, 40);
    expect(kPawMeSize642, kPawFriendSize640 + 2 * kPawFriendOut640);
    // badges réduits comme sur le site (16 en petit ; 24 / 20 / 20 avant)
    expect(kPawMeCrown642, 16);
    expect(kPawMeRocket642, 16);
    expect(kPawMeEyeOff642, 16);
    // boîtes de collision (site : ME_PX_1111 / 2 + 2 ; ami 17 + 3 + 0,5)
    expect(kPawMeBoxR642, 22);
    expect(kPawMeLabelR642, 20);
    expect(kPawFriendBoxR640, 20.5);
    // la valeur d'avant reste disponible pour le coupe-circuit
    expect(PawMapLegend.meSize, 56);
    expect(PawMapLegend.crownMe, 24);
  });

  test('642 — boîtes : zone réservée de « Moi » et étiquette sous la pastille', () {
    const at = Offset(200, 300);
    final double labelW = PawMapPinPainter.photoLabelWidth('Moi') - 8;
    final box = pawPinBox(kPawMeBoxR642, labelW: labelW, labelH: 16.3, labelGap: 3)
        .shift(at);
    // rond : 22 de chaque côté (28 + 2 = 30 au 641) ; la boîte fait la
    // largeur du rond ou de l'étiquette « Moi », la plus grande des deux
    expect(box.width, math.max(44.0, labelW));
    expect(box.width < 60, isTrue, reason: 'plus étroite que le rond de 56 + 4');
    expect(box.top, at.dy - 22);
    // l'étiquette « Moi » : 3 pt SOUS le rond de 40, comptée dans la boîte
    final lab = pawLabelRect(at, kPawMeLabelR642, labelW, PawLabelSide.below, height: 16.3);
    expect(lab.top, at.dy + 20 + 3);
    expect(box.bottom >= lab.bottom - 2.01, isTrue,
        reason: 'boîte ${box.bottom} / étiquette ${lab.bottom}');
    // un ami posé à 43 pt de « Moi » ne le touche plus (au 641 : il fallait 49)
    final friend = pawPinBox(kPawFriendBoxR640).shift(at + const Offset(43, 0));
    expect(Rect.fromCircle(center: at, radius: kPawMeBoxR642).overlaps(friend), isFalse);
    final friendOld = pawPinBox(kPawFriendBoxR640).shift(at + const Offset(42, 0));
    expect(Rect.fromCircle(center: at, radius: kPawMeBoxR642).overlaps(friendOld), isTrue);
  });

  testWidgets('642 — mesuré sur l\'image : « Moi » 40 pt, ami 40 pt, normale 32',
      (tester) async {
    late double me, meOld, friend, normal, ringMe;
    await tester.runAsync(() async {
      await ensurePawPinFonts();
      const double sc = 4;
      // « Moi » (sans étiquette : la ligne du centre ne coupe que le rond)
      final double m = _meMargin();
      final double side = PawMapPinPainter.photoBitmapSize(kPawMeSize642, margin: m);
      var img = await renderPinImage(side, side, (c) => _paintMe(c), scale: sc);
      var px = await _rgba(img);
      final int cy = (side / 2 * sc).round();
      me = _solidRun(px, img.width, cy, cy) / sc;
      // épaisseur du contour de rôle : du bord du rond au liseré blanc
      var x = cy;
      while (px[(cy * img.width + x - 1) * 4 + 3] >= 230) {
        x--;
      }
      var k = x; // 1er pixel opaque à gauche
      bool white(int i) =>
          px[(cy * img.width + i) * 4] > 245 &&
          px[(cy * img.width + i) * 4 + 1] > 245 &&
          px[(cy * img.width + i) * 4 + 2] > 245;
      while (!white(k)) {
        k++;
      }
      ringMe = (k - x) / sc;
      img.dispose();

      // « Moi » d'avant (56, déduction par la taille) : toujours dessinable
      const double old = PawMapLegend.meSize;
      final double sideOld = PawMapPinPainter.photoBitmapSize(old, margin: m);
      img = await renderPinImage(sideOld, sideOld, (c) {
        PawMapPinPainter.paintPhotoDot(c,
            avatar: null,
            ringColor: PawMapLegend.owner,
            size: old,
            crownSize: PawMapLegend.crownMe,
            margin: m);
      }, scale: sc);
      px = await _rgba(img);
      final int cyo = (sideOld / 2 * sc).round();
      meOld = _solidRun(px, img.width, cyo, cyo) / sc;
      img.dispose();

      // un ami (anneau rose compris)
      const double mf = PawMapPinPainter.photoMarginFriend640;
      final double sf = PawMapPinPainter.photoBitmapSize(kPawFriendSize640, margin: mf);
      img = await renderPinImage(sf, sf, (c) {
        PawMapPinPainter.paintPhotoDot(c,
            avatar: null,
            ringColor: PawMapLegend.friend,
            size: kPawFriendSize640,
            crownSize: kPawFriendCrown640,
            fallbackTint: PawMapLegend.sitter,
            margin: mf);
      }, scale: sc);
      px = await _rgba(img);
      final int cyf = (sf / 2 * sc).round();
      friend = _solidRun(px, img.width, cyf, cyf) / sc;
      img.dispose();

      final spec = PawPinSpec639(roles: const ['sitter']);
      final l = pawPinLayout639(spec);
      img = await renderPinImage(l.w, l.h, (c) => paintPin639(c, spec), scale: sc);
      px = await _rgba(img);
      normal = _solidRun(px, img.width, (l.cx * sc).round(), (l.cy * sc).round()) / sc;
      img.dispose();
    });
    // ignore: avoid_print
    print('642 diamètres mesurés (pt) : Moi $me (avant $meOld), ami $friend, '
        'normale $normal, contour de Moi $ringMe');
    expect(me, closeTo(40, 0.75));
    expect(meOld, closeTo(56, 0.75));
    expect(friend, closeTo(40, 0.75));
    expect((me - friend).abs() <= 0.75, isTrue, reason: 'Moi $me / ami $friend');
    expect(normal, closeTo(32, 0.75));
    expect(ringMe, closeTo(2, 0.5), reason: 'contour fin (2) comme un ami');
  });

  testWidgets('642 — « Moi » : rien de coupé, quel que soit le badge', (tester) async {
    final edges = <String, int>{};
    await tester.runAsync(() async {
      await ensurePawPinFonts();
      Future<void> edge(String name,
          {bool crown = false, bool boosted = false, bool friendsOnly = false}) async {
        final double m = _meMargin(boosted: boosted, crown: crown, eyeOff: friendsOnly);
        final double w = math.max(
            PawMapPinPainter.photoBitmapSize(kPawMeSize642, margin: m),
            PawMapPinPainter.photoLabelWidth('Moi'));
        final double h =
            PawMapPinPainter.photoBitmapSize(kPawMeSize642, withLabel: true, margin: m);
        final double base = PawMapPinPainter.photoBitmapSize(kPawMeSize642, margin: m);
        final img = await renderPinImage(w, h, (c) {
          c.translate((w - base) / 2, 0);
          _paintMe(c, crown: crown, boosted: boosted, friendsOnly: friendsOnly, label: 'Moi');
        }, scale: 3);
        final px = await _rgba(img);
        edges[name] = _maxEdgeAlpha(px, img.width, img.height);
        img.dispose();
      }

      await edge('nu');
      await edge('couronne', crown: true);
      await edge('amis seulement', friendsOnly: true);
      await edge('couronne + amis seulement', crown: true, friendsOnly: true);
      await edge('pawboost', boosted: true);
      await edge('pawboost + couronne + amis seulement',
          boosted: true, crown: true, friendsOnly: true);
    });
    // ignore: avoid_print
    print('642 alpha max au bord de l\'image de « Moi » : $edges');
    edges.forEach((name, a) {
      // une queue d'ombre presque invisible est tolérée (≤ 8 / 255)
      expect(a <= 8, isTrue, reason: '« Moi » $name : dessin coupé (alpha $a)');
    });
  });

  test('642 — badges de « Moi » : jamais l\'un sur l\'autre, ni sur l\'étiquette', () {
    const double r = kPawMeSize642 / 2;
    const c = Offset(100, 100);
    final crown = PawMapPinPainter.crownCenter(c, r, kPawMeCrown642);
    final eye = PawMapPinPainter.eyeOffBadgeCenter(c, r);
    // fusée : bas-gauche (même formule que le peintre)
    const double s = kPawMeRocket642;
    final double b = (s * 0.25).roundToDouble(), l = (s * 0.3).roundToDouble();
    final rocket = Offset(c.dx - (r + l - s / 2), c.dy + r + b - s / 2);
    void apart(Offset a, Offset b, String what) =>
        expect((a - b).distance >= 16, isTrue, reason: '$what : ${(a - b).distance}');
    apart(crown, eye, 'couronne / œil barré');
    apart(crown, rocket, 'couronne / fusée');
    apart(eye, rocket, 'œil barré / fusée');
    // l'étiquette commence 3 pt sous le rond : l'œil barré (bas-droite, 40°)
    // la touche au plus par son liseré
    expect(eye.dy + kPawMeEyeOff642 / 2 <= c.dy + r + 3 + 2, isTrue);
  });

  // ── Planche : Moi, un ami, un boosté posé À CÔTÉ d'un groupe ─────────────
  for (final dark in [false, true]) {
    testWidgets('642 — planche Moi / ami / boosté dézoomé — ${dark ? 'sombre' : 'clair'}',
        (tester) async {
      ui.Image? board;
      await tester.runAsync(() async {
        await (FontLoader('PawSymbols')
              ..addFont(rootBundle.load('assets/pawsymbols/PawSymbolsRounded.ttf')))
            .load();
        await ensurePawPinFonts();
        board = await renderPinImage(420, 250, (c) => _sheet(c, dark), scale: 3);
        final out = Platform.environment['PAM642_OUT'];
        if (out != null && out.isNotEmpty) {
          final png = (await board!.toByteData(format: ui.ImageByteFormat.png))!
              .buffer
              .asUint8List();
          File('$out/planche642_${dark ? 'sombre' : 'clair'}.png').writeAsBytesSync(png);
        }
      });
      expect(board, isNotNull);
      await expectLater(board!,
          matchesGoldenFile('goldens/pawmap642/planche_${dark ? 'sombre' : 'clair'}.png'));
    });
  }
}

void _at(Canvas c, Offset at, double size, double margin, void Function(Canvas) paint,
    {bool withLabel = false}) {
  final double base = PawMapPinPainter.photoBitmapSize(size, margin: margin);
  final double h = PawMapPinPainter.photoBitmapSize(size, withLabel: withLabel, margin: margin);
  final double ay = PawMapPinPainter.photoAnchorY(size, withLabel: withLabel, margin: margin);
  c.save();
  c.translate(at.dx - base / 2, at.dy - ay * h);
  paint(c);
  c.restore();
}

void _pin(Canvas c, Offset at, PawPinSpec639 s) {
  final l = pawPinLayout639(s);
  c.save();
  c.translate(at.dx - l.cx, at.dy - l.cy);
  paintPin639(c, s);
  c.restore();
}

void _sheet(Canvas c, bool dark) {
  c.drawRect(const Rect.fromLTWH(0, 0, 420, 250),
      Paint()..color = dark ? const Color(0xFF1B2026) : const Color(0xFFEAF0E4));
  // 1. « Moi » et un ami, côte à côte : même taille
  const me = Offset(70, 70);
  _at(c, me, kPawMeSize642, _meMargin(crown: true),
      (c) => _paintMe(c, crown: true, label: 'Moi'),
      withLabel: true);
  const fr = Offset(140, 70);
  _at(c, fr, kPawFriendSize640, PawMapPinPainter.photoMarginFriend640, (c) {
    PawMapPinPainter.paintPhotoDot(c,
        avatar: null,
        ringColor: PawMapLegend.friend,
        size: kPawFriendSize640,
        crownSize: kPawFriendCrown640,
        online: true,
        offlineDot: true,
        fallbackTint: PawMapLegend.sitter,
        fallbackIcon: Icons.home_rounded,
        margin: PawMapPinPainter.photoMarginFriend640);
  });
  _pin(c, const Offset(205, 70), PawPinSpec639(roles: const ['walker']));
  // « Moi » en amis seulement + PawBoost
  _at(c, const Offset(280, 70), kPawMeSize642, _meMargin(boosted: true, eyeOff: true),
      (c) => _paintMe(c, boosted: true, friendsOnly: true, label: 'Moi'),
      withLabel: true);
  _at(c, const Offset(360, 70), kPawMeSize642, _meMargin(), (c) => _paintMe(c, label: 'Moi'),
      withLabel: true);

  // 2. dézoomé : le groupe d'une ville fictive et 3 boostés qui tombaient
  //    DESSUS → posés à côté par pawBoostOffsets642 (le compteur reste lisible)
  const town = Offset(120, 185);
  final boosted = <PawBoosted642>[
    (id: 'b1', px: town),
    (id: 'b2', px: town + const Offset(3, 2)),
    (id: 'b3', px: town + const Offset(-2, 4)),
  ];
  final off = pawBoostOffsets642(boosted, [town]);
  final sz = pawClusterBitmap639();
  final an = pawClusterAnchor639();
  c.save();
  c.translate(town.dx - an.dx * sz.width, town.dy - an.dy * sz.height);
  paintCluster639(c, count: 12, counts: const {'owner': 5, 'sitter': 4, 'walker': 3}, dark: dark);
  c.restore();
  for (final b in boosted) {
    _pin(c, b.px + (off[b.id] ?? Offset.zero),
        PawPinSpec639(roles: const ['sitter'], halo: PawHalo639.boost));
  }
  // … et le même groupe SANS le décalage (ce que ZOE avait relevé sur le site)
  const town2 = Offset(310, 185);
  c.save();
  c.translate(town2.dx - an.dx * sz.width, town2.dy - an.dy * sz.height);
  paintCluster639(c, count: 12, counts: const {'owner': 5, 'sitter': 4, 'walker': 3}, dark: dark);
  c.restore();
  _pin(c, town2, PawPinSpec639(roles: const ['sitter'], halo: PawHalo639.boost));
}
