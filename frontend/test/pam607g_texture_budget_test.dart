// 607 (PAM, 02/10/2026) — budget de textures iOS. Mesuré au simulateur à
// Bondy : en dézoomant, « Reached the max number of texture atlases » ×54,
// épingles rognées et « Moi » disparu (sans retour au rezoom). La passe ne
// pose plus que ce qui tient dans le budget, en retirant d'abord les lieux.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/widgets/pawmap_layout607.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart' show pawPlushOffsetFromMe;

PawPlaced _p(String id, double x, {double w = 100, double h = 100}) => PawPlaced(
      id: id,
      at: Offset(x, 0),
      size: Size(w, h),
      anchor: const Offset(0.5, 1),
    );

void main() {
  double area(PawPlaced p) => p.size.width * p.size.height;

  test('sous le budget : rien n\'est retiré', () {
    final items = [_p('me', 0), _p('poi_a', 200), _p('nearby_b', 400)];
    expect(pawTextureBudget(items, budgetPx: 1e6, areaOf: area), isEmpty);
  });

  test('au-delà : les lieux partent d\'abord, jamais Moi ni une personne', () {
    final items = <PawPlaced>[
      _p('me', 0),
      _p('friend_x', 10),
      _p('nearby_m1', 20),
      _p('nearby_m2', 30),
      _p('plush_t', 40),
      for (var i = 0; i < 20; i++) _p('poi_$i', 100.0 + i),
      for (var i = 0; i < 5; i++) _p('pcluster_$i', 300.0 + i),
    ];
    // 10 000 px chacun ; budget = 9 images
    final hide = pawTextureBudget(items, budgetPx: 90000, areaOf: area);
    for (final id in ['me', 'friend_x', 'nearby_m1', 'nearby_m2', 'plush_t']) {
      expect(hide.contains(id), isFalse, reason: id);
    }
    // 5 personnes/peluche + 4 lieux tiennent, le reste part
    final kept = items.where((p) => !hide.contains(p.id)).length;
    expect(kept, 9);
    expect(hide.every((id) => !id.startsWith('nearby_') && id != 'me'), isTrue);
  });

  test('déterministe et indépendant de l\'ordre d\'entrée', () {
    final items = [for (var i = 0; i < 30; i++) _p('poi_$i', i.toDouble()), _p('me', 0)];
    final a = pawTextureBudget(items, budgetPx: 55000, areaOf: area);
    final b = pawTextureBudget(items.reversed, budgetPx: 55000, areaOf: area);
    expect(a, b);
    expect(a.length, 30 - 4);
  });

  test('ce que la passe de collision a déjà retiré ne compte pas', () {
    final items = [_p('me', 0), _p('poi_a', 1), _p('poi_b', 2)];
    final hide = pawTextureBudget(items,
        budgetPx: 20000, areaOf: area, alreadyHidden: const {'poi_a'});
    expect(hide, isEmpty);
  });

  test('hors de la zone visible : les membres lointains partent avant les lieux à l\'écran', () {
    final items = <PawPlaced>[
      _p('me', 0),
      for (var i = 0; i < 6; i++) _p('poi_v$i', 50.0 + i), // à l'écran
      for (var i = 0; i < 10; i++) _p('nearby_far$i', 5000.0 + i), // très loin
      _p('friend_far', 6000),
    ];
    const keep = Rect.fromLTWH(-500, -500, 1000, 1000);
    final hide = pawTextureBudget(items, budgetPx: 80000, areaOf: area, keepArea: keep);
    // Moi + 6 lieux à l'écran + l'ami lointain (jamais retiré) = 8 images
    for (var i = 0; i < 6; i++) {
      expect(hide.contains('poi_v$i'), isFalse);
    }
    expect(hide.contains('me'), isFalse);
    expect(hide.contains('friend_far'), isFalse);
    expect(hide.where((id) => id.startsWith('nearby_far')).length, 10);
  });

  test('peluche jamais sous Moi : image posée sur le côté, hors du rond', () {
    expect(pawPlushOffsetFromMe(const Offset(80, 0)), Offset.zero);
    for (final rel in const [Offset(10, 0), Offset.zero, Offset(-6, 8), Offset(2, 30)]) {
      final shown = rel + pawPlushOffsetFromMe(rel);
      expect(shown.dx.abs(), greaterThanOrEqualTo(50), reason: '$rel');
      expect(shown.dy.abs(), lessThanOrEqualTo(18), reason: 'jamais sous l\'étiquette « Moi »');
    }
    expect((const Offset(-6, 8) + pawPlushOffsetFromMe(const Offset(-6, 8))).dx < 0, isTrue);
  });
}
