// 639 (PAM) — planches des pastilles v2, en clair et en sombre, dessinées par
// les VRAIS peintres de la carte (pawmap_pins.dart, section 639) avec les
// vraies polices (Poppins, Inter, PawSymbols). Chaque élément est posé par
// son ANCRE sur un point de grille (croix fine) : un décalage se voit.
// Régénérer après un changement VOULU :
//   flutter test test/pawmap639_planche_test.dart --update-goldens
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';

const double _sc = 3;

void _cross(Canvas c, Offset p) {
  final paint = Paint()
    ..color = const Color(0x55000000)
    ..strokeWidth = 1 / _sc;
  c.drawLine(p.translate(-40, 0), p.translate(40, 0), paint);
  c.drawLine(p.translate(0, -40), p.translate(0, 40), paint);
}

void _pin(Canvas c, Offset at, PawPinSpec639 s) {
  final l = pawPinLayout639(s);
  c.save();
  c.translate(at.dx - l.cx, at.dy - l.cy);
  paintPin639(c, s);
  c.restore();
}

void _cluster(Canvas c, Offset at, int count, Map<String, int> counts,
    {required bool dark, String? prefix, String? price, String role = 'sitter'}) {
  final l = pawClusterLayout639(labelPrefix: prefix, labelPrice: price);
  c.save();
  c.translate(at.dx - l.cx, at.dy - l.cy);
  paintCluster639(c,
      count: count,
      counts: counts,
      dark: dark,
      labelPrefix: prefix,
      labelPrice: price,
      labelRole: role);
  c.restore();
}

void _bubble(Canvas c, Offset at, List<PawPriceSeg639> segs,
    {required bool dark, double tailDx = 0, double rating = 0}) {
  final sz = pawBubbleBitmap639(segs);
  c.save();
  c.translate(at.dx - sz.width / 2 - tailDx, at.dy - sz.height);
  paintBubble639(c, segs, tailDx: tailDx, dark: dark, rating: rating);
  c.restore();
}

void _sheet(Canvas c, bool dark) {
  c.drawRect(const Rect.fromLTWH(0, 0, 560, 430),
      Paint()..color = dark ? const Color(0xFF1B2026) : const Color(0xFFEAF0E4));
  // quelques « rues » pour juger le contraste sur un fond de carte
  final road = Paint()
    ..color = dark ? const Color(0xFF2C343D) : const Color(0xFFFFFFFF)
    ..strokeWidth = 7;
  c.drawLine(const Offset(0, 130), const Offset(560, 110), road);
  c.drawLine(const Offset(0, 300), const Offset(560, 330), road);
  c.drawLine(const Offset(250, 0), const Offset(290, 430), road);

  // Rangée 1 : rôles seuls, duo, trio.
  final r1 = <PawPinSpec639>[
    PawPinSpec639(roles: const ['owner']),
    PawPinSpec639(roles: const ['sitter']),
    PawPinSpec639(roles: const ['walker']),
    PawPinSpec639(roles: const ['owner', 'sitter']),
    PawPinSpec639(roles: const ['owner', 'sitter', 'walker']),
    PawPinSpec639(roles: const ['sitter'], premium: true),
    PawPinSpec639(roles: const ['sitter'], available: true),
    PawPinSpec639(roles: const ['walker'], live: true),
  ];
  for (var i = 0; i < r1.length; i++) {
    final at = Offset(40 + i * 68.0, 50);
    _cross(c, at);
    _pin(c, at, r1[i]);
  }
  // Rangée 2 : halos et cumul.
  final r2 = <PawPinSpec639>[
    PawPinSpec639(roles: const ['walker'], halo: PawHalo639.boost),
    PawPinSpec639(roles: const ['sitter'], halo: PawHalo639.follow),
    PawPinSpec639(roles: const ['sitter'], halo: PawHalo639.follow, wave: 2),
    PawPinSpec639(roles: const ['sitter'], halo: PawHalo639.follow, wave: 4),
    PawPinSpec639(roles: const ['owner'], halo: PawHalo639.friend),
    PawPinSpec639(
        roles: const ['sitter', 'walker'],
        halo: PawHalo639.boost,
        premium: true,
        available: true),
    PawPinSpec639(
        roles: const ['owner'],
        halo: PawHalo639.friend,
        caption: 'Vu il y a 5 j'),
  ];
  for (var i = 0; i < r2.length; i++) {
    final at = Offset(44 + i * 76.0, 140);
    _cross(c, at);
    _pin(c, at, r2[i]);
  }
  // Rangée 3 : sélection (pointe + bulle), groupes.
  const one = <PawPriceSeg639>[(role: 'sitter', amount: '18 €', unit: '/j')];
  const three = <PawPriceSeg639>[
    (role: 'owner', amount: '12 €', unit: '/h'),
    (role: 'sitter', amount: '25 €', unit: '/j'),
    (role: 'walker', amount: '9 €', unit: '/h'),
  ];
  var at = const Offset(60, 260);
  _cross(c, at);
  _pin(c, at,
      PawPinSpec639(roles: const ['sitter'], selected: true, scale: 1.18, available: true));
  _bubble(c, at, one, dark: dark, rating: 4.8);
  at = const Offset(210, 260);
  _cross(c, at);
  _pin(c, at,
      PawPinSpec639(
          roles: const ['owner', 'sitter', 'walker'], selected: true, scale: 1.18));
  _bubble(c, at, three, dark: dark);
  at = const Offset(340, 260);
  _cross(c, at);
  _cluster(c, at, 12, const {'owner': 5, 'sitter': 4, 'walker': 3}, dark: dark);
  at = const Offset(400, 260);
  _cross(c, at);
  _cluster(c, at, 7, const {'sitter': 7}, dark: dark);
  at = const Offset(480, 260);
  _cross(c, at);
  _cluster(c, at, 120, const {'owner': 2, 'walker': 9},
      dark: dark, prefix: 'dès', price: '12 €', role: 'walker');
  // Rangée 4 : bulle repoussée du bord (pointe décalée), ami étiquette dessus.
  at = const Offset(60, 380);
  _cross(c, at);
  _pin(c, at, PawPinSpec639(roles: const ['walker'], selected: true, scale: 1.18));
  _bubble(c, at, three, dark: dark, tailDx: -40, rating: 5);
  at = const Offset(330, 380);
  _cross(c, at);
  _pin(c, at,
      PawPinSpec639(
          roles: const ['sitter'],
          halo: PawHalo639.friend,
          premium: true,
          caption: 'Vu il y a 2 h',
          captionAbove: true));
  at = const Offset(440, 380);
  _cross(c, at);
  _pin(c, at, PawPinSpec639(roles: const ['owner']));
  _pin(c, at.translate(36, 0), PawPinSpec639(roles: const ['sitter']));
}

void main() {
  for (final dark in [false, true]) {
    testWidgets('planche pastilles v2 — ${dark ? 'sombre' : 'clair'}',
        (tester) async {
      ui.Image? board;
      await tester.runAsync(() async {
        await (FontLoader('PawSymbols')
              ..addFont(rootBundle.load('assets/pawsymbols/PawSymbolsRounded.ttf')))
            .load();
        await ensurePawPinFonts();
        board = await renderPinImage(560, 430, (c) => _sheet(c, dark), scale: _sc);
      });
      expect(board, isNotNull);
      await expectLater(
          board!,
          matchesGoldenFile(
              'goldens/pawmap639/planche_${dark ? 'sombre' : 'clair'}.png'));
    });
  }
}
