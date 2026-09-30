// v605 (30/09) — Daniel : bulle avec UNITÉ pour les gardiens qui n'ont que
// des tarifs à la semaine / au mois (GIRMA, 100 €/sem). Le serveur (a3d3a01a)
// renvoie `priceAlt: {amount, unit}` par rôle et au niveau du point ;
// `priceFrom` reste 0. Avant : aucune bulle. Après : « 100 €/sem », bulle
// entière (vrai peintre), aussi en duo et dans la carte focus.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/localization/v565/pawmap605_i18n.dart';
import 'package:hopetsit/views/map/pawmap_person.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';

const double ms = PawMapLegend.memberSize;
String fmt(String c, double p) => '${p.round()} €';
String unitFr(String u) => pawmap605I18n['fr']![u == 'month' ? 'pm605_per_month' : 'pm605_per_week']!;

// Point GIRMA tel que renvoyé par GET /friends/members/world en prod le
// 30/09 (copie du champ utile, ids réels).
final Map<String, dynamic> girma = {
  'id': '6aa1b248505cbf5f66d04ada',
  'role': 'sitter',
  '_role': 'sitter',
  'roles': [
    {'id': '6aa1b248505cbf5f66d04ada', 'role': 'sitter', 'priceFrom': 0,
     'priceAlt': {'amount': 100, 'unit': 'week'}, 'currency': 'EUR'},
  ],
  'name': 'GIRMA',
  'avatar': '',
  'priceFrom': 0,
  'priceAlt': {'amount': 100, 'unit': 'week'},
  'currency': 'EUR',
};

void main() {
  test('unités traduites dans les 9 langues', () {
    for (final l in const ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
      expect(pawmap605I18n[l]!['pm605_per_week']!.startsWith('/'), isTrue, reason: l);
      expect(pawmap605I18n[l]!['pm605_per_month']!.startsWith('/'), isTrue, reason: l);
    }
  });

  test('GIRMA : bulle « 100 €/sem » (avant : aucune bulle)', () {
    final roles = pawMapExpandRoles(girma);
    final before = pawMapPersonPriceBubble(roles,
        shows: (_) => true, shownRoles: const {}, format: fmt);
    expect(before, isNull, reason: 'sans unitSuffix = comportement 604');
    final b = pawMapPersonPriceBubble(roles,
        shows: (_) => true, shownRoles: const {}, format: fmt, unitSuffix: unitFr);
    expect(b, isNotNull);
    expect(b!.text, '100 €/sem');
    expect(b.role, 'sitter');
  });

  test('au mois, et un tarif jour passe toujours devant', () {
    expect(
        pawMapRolePriceText({'priceFrom': 0, 'priceAlt': {'amount': 350, 'unit': 'month'}},
            format: fmt, unitSuffix: unitFr),
        '350 €/mois');
    expect(
        pawMapRolePriceText({'priceFrom': 20, 'priceAlt': {'amount': 350, 'unit': 'month'}},
            format: fmt, unitSuffix: unitFr),
        '20 €');
    expect(pawMapRolePriceText({'priceFrom': 0, 'priceAlt': null}, format: fmt, unitSuffix: unitFr), '');
  });

  test('duo gardien (semaine) + promeneur (jour)', () {
    final b = pawMapPersonPriceBubble([
      {'_role': 'sitter', 'priceFrom': 0, 'priceAlt': {'amount': 100, 'unit': 'week'}},
      {'_role': 'walker', 'priceFrom': 12},
    ], shows: (_) => true, shownRoles: const {}, format: fmt, unitSuffix: unitFr);
    expect(b!.text, '100 €/sem|12 €');
    expect(b.role, 'duo');
  });

  test('couche abonnés sans priceAlt : reprise depuis la couche monde', () {
    final idx = pawMapWorldIndex([girma]);
    final near = <String, dynamic>{
      'id': '6aa1b248505cbf5f66d04ada', '_role': 'sitter', 'priceFrom': 0,
      'roles': [{'id': '6aa1b248505cbf5f66d04ada', 'role': 'sitter', 'priceFrom': 0}],
    };
    final out = pawMapWithWorldPrices(near, idx);
    expect((out['priceAlt'] as Map)['amount'], 100);
    expect(((out['roles'] as List).first as Map)['priceAlt'], isA<Map>());
  });

  testWidgets('rond SANS photo : bulle « 100 €/sem » entière dans le bitmap', (t) async {
    const bubble = '100 €/sem';
    final w = PawMapPinPainter.memberBitmapWidth(ms, priceBubble: bubble);
    final dx = (w - PawMapPinPainter.memberBitmapSize(ms)) / 2;
    final h = PawMapPinPainter.memberBitmapSize(ms, withLabel: true, withBubble: true);
    final img = await t.runAsync(() async {
      await ensurePawPinFonts();
      return renderPinImage(w, h, (c) {
        c.save();
        c.translate(dx, 0);
        PawMapPinPainter.paintMemberDot(c,
            role: 'sitter', size: ms, priceLabel: 'GIRMA', priceBubble: bubble);
        c.restore();
      }, scale: 1);
    });
    final bd = await t.runAsync(() => img!.toByteData(format: ui.ImageByteFormat.rawRgba));
    final px = bd!.buffer.asUint8List();
    final iw = img!.width;
    const zone = 32 + 22;
    var blue = 0, edge = 0;
    for (var y = 0; y < zone; y++) {
      for (var x = 0; x < iw; x++) {
        final i = (y * iw + x) * 4;
        final r = px[i], g = px[i + 1], b = px[i + 2], a = px[i + 3];
        if (a >= 230 && b > 150 && b > r + 60 && b > g + 20) blue++;
        if (x < 2 || x >= iw - 2) edge = a > edge ? a : edge;
      }
    }
    expect(blue, greaterThan(150), reason: 'bulle bleue attendue');
    expect(edge, lessThanOrEqualTo(16), reason: 'bulle coupée au bord');
    expect(w, greaterThan(PawMapPinPainter.memberBitmapSize(ms)),
        reason: 'le bitmap s\'élargit pour le texte plus long');
  });
}
