// 623 (PAM, 26/10/2026) — maquette « Améliorer boutons et profil PawMap ».
// Règle visiblePrices, éclatement, bulle dans l'écran, ressort, dessins.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart' show ensurePawPinFonts;
import 'package:hopetsit/views/map/widgets/pawmap_ring2610.dart';

({String amount, String unit})? _p(String role) => switch (role) {
      'owner' => (amount: '12 €', unit: ''),
      'sitter' => (amount: '25 €', unit: '/jour'),
      'walker' => (amount: '10 €', unit: '/balade'),
      _ => null,
    };

void main() {
  group('visiblePrices', () {
    test('propriétaire → gardien + promeneur, jamais propriétaire', () {
      final r = pawVisiblePrices2610('owner', ['owner', 'sitter', 'walker'], _p);
      expect(r.map((e) => e.role), ['sitter', 'walker']);
    });
    test('gardien → budget propriétaire seulement', () {
      final r = pawVisiblePrices2610('sitter', ['owner', 'sitter', 'walker'], _p);
      expect(r.map((e) => e.role), ['owner']);
    });
    test('promeneur → budget propriétaire seulement', () {
      final r = pawVisiblePrices2610('walker', ['owner', 'walker'], _p);
      expect(r.map((e) => e.role), ['owner']);
    });
    test('gardien face à un gardien : rien', () {
      expect(pawVisiblePrices2610('sitter', ['sitter'], _p), isEmpty);
      expect(pawVisiblePrices2610('walker', ['sitter', 'walker'], _p), isEmpty);
    });
    test('rôle sans prix : pas de segment', () {
      final r = pawVisiblePrices2610('owner', ['sitter', 'walker'],
          (role) => role == 'walker' ? (amount: '10 €', unit: '/balade') : null);
      expect(r.map((e) => e.role), ['walker']);
    });
    test('prix découpé montant / unité', () {
      final s = pawSplitPrice2610('25 €/jour');
      expect(s.amount, '25 €');
      expect(s.unit, '/jour');
      expect(pawSplitPrice2610('12 €').unit, '');
    });
  });

  group('éclatement', () {
    test('6 sur 72, le reste sur 132 (× 0,95 en y)', () {
      final f = pawSpiderfy2610(10);
      for (var i = 0; i < 6; i++) {
        expect(f[i].distance, closeTo(72, 0.01));
      }
      expect(f[0].dx, closeTo(0, 0.01));
      expect(f[0].dy, closeTo(-72, 0.01));
      for (var i = 6; i < 10; i++) {
        final d = Offset(f[i].dx, f[i].dy / 0.95).distance;
        expect(d, closeTo(132, 0.01));
      }
    });
    test('au-delà de 21 : 15 sur 132 puis 3e cercle de 192, rien ne se touche', () {
      final f = pawSpiderfy2610(40);
      for (var i = 6; i < 21; i++) {
        expect(Offset(f[i].dx, f[i].dy / 0.95).distance, closeTo(132, 0.01));
      }
      for (var i = 21; i < 40; i++) {
        expect(Offset(f[i].dx, f[i].dy / 0.95).distance, closeTo(192, 0.01));
      }
      var minD = 1e9;
      for (var i = 0; i < f.length; i++) {
        for (var j = i + 1; j < f.length; j++) {
          minD = (f[i] - f[j]).distance < minD ? (f[i] - f[j]).distance : minD;
        }
      }
      expect(minD, greaterThanOrEqualTo(50)); // ronds de 50 : jamais en contact
      // ≤ 21 : identique à la maquette (le reste sur 132).
      final g = pawSpiderfy2610(21);
      expect(g.skip(6).every((o) => (Offset(o.dx, o.dy / 0.95).distance - 132).abs() < 0.01), isTrue);
    });
    test('2 profils : sur le petit cercle seulement', () {
      final f = pawSpiderfy2610(2);
      expect(f.length, 2);
      expect(f.every((o) => (o.distance - 72).abs() < 0.01), isTrue);
    });
  });

  group('bulle dans l\'écran', () {
    test('au centre : pas de décalage', () {
      expect(pawBubbleTailDx2610(200, 187.5, 375), 0);
    });
    test('près du bord gauche : le corps se décale, la pointe reste', () {
      final t = pawBubbleTailDx2610(240, 30, 375);
      // corps décalé de +102 (12 + 120 − 30) → pointe à −86 du centre… bornée.
      expect(t, lessThan(0));
      final bodyLeft = 30 - t - 120;
      expect(bodyLeft, greaterThanOrEqualTo(12 - 0.01));
    });
    test('près du bord droit', () {
      final t = pawBubbleTailDx2610(240, 345, 375);
      expect(t, greaterThan(0));
      final bodyRight = 345 - t + 120;
      expect(bodyRight, lessThanOrEqualTo(375 - 12 + 0.01));
    });
  });

  test('ressort : part de 1, dépasse, finit à 1,18', () {
    expect(pawSpringScale2610(0), closeTo(1, 1e-9));
    final peak = [for (final t in kPawSpringSteps2610) pawSpringScale2610(t.toDouble())]
        .reduce((a, b) => a > b ? a : b);
    expect(peak, greaterThan(1.18));
    expect(pawSpringScale2610(1000), closeTo(1.18, 0.002));
  });

  test('couleurs du README', () {
    expect(PawRole2610.color('owner'), const Color(0xFFF23B16));
    expect(PawRole2610.color('sitter'), const Color(0xFF1A6CFF));
    expect(PawRole2610.color('walker'), const Color(0xFF12B350));
    expect(PawRole2610.gold, const Color(0xFFF6B400));
    expect(PawRole2610.live, const Color(0xFFE8452F));
    expect(kShowPinPrices2610, isFalse);
  });

  // Planche de contrôle (rendu réel des dessins) écrite si PAM623_SHEET=chemin.
  test('planche des marqueurs', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await ensurePawPinFonts();
    final fl = FontLoader('PawSymbols')
      ..addFont(rootBundle.load('assets/pawsymbols/PawSymbolsRounded.ttf'));
    await fl.load();
    final out = Platform.environment['PAM623_SHEET'];
    const w = 520.0, h = 300.0, sc = 3.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..scale(sc);
    c.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFFEEF0EA));
    final ringSets = <(List<String>, bool, double?)>[
      (['sitter'], true, null),
      (['owner'], false, null),
      (['walker'], true, 0.2),
      (['sitter', 'walker'], true, null),
      (['owner', 'sitter', 'walker'], true, null),
    ];
    // Variante extras (PawBoost + coche vérifiée), ligne du bas à droite.
    paintRing2610(c, const Offset(250, 245), roles: const ['sitter'], boostPhase: 0.25, verified: true, status: true);
    paintRing2610(c, const Offset(335, 245), roles: const ['walker'], premium: true, pin618: 1, status: false);
    paintRing2610(c, const Offset(420, 240), roles: const ['sitter', 'walker'], premium: true, verified: true, status: true, livePhase: 0.3);
    for (var i = 0; i < ringSets.length; i++) {
      final (r, prem, live) = ringSets[i];
      paintRing2610(c, Offset(50 + i * 95.0, 70), roles: r, premium: prem, livePhase: live);
    }
    c.save();
    c.translate(20, 150);
    paintCluster2610(c, count: 14, counts: const {'walker': 4, 'owner': 5, 'sitter': 5},
        labelPrefix: 'dès', labelPrice: '10 €/balade', labelRole: 'walker');
    c.restore();
    c.save();
    c.translate(140, 150);
    paintCluster2610(c, count: 2, counts: const {'sitter': 1, 'owner': 1}, dark: true);
    c.restore();
    c.save();
    c.translate(210, 150);
    paintBubble2610(c, const [
      PawPriceSeg2610('owner', '12 €', '/jour'),
      PawPriceSeg2610('sitter', '25 €', '/jour'),
      PawPriceSeg2610('walker', '10 €', '/balade'),
    ]);
    c.restore();
    c.save();
    c.translate(20, 220);
    paintBubble2610(c, const [PawPriceSeg2610('walker', '10 €', '/balade')], tailDx: -20);
    c.restore();
    final img = await rec.endRecording().toImage((w * sc).toInt(), (h * sc).toInt());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    expect(png, isNotNull);
    if (out != null && out.isNotEmpty) File(out).writeAsBytesSync(png!.buffer.asUint8List());
  });
}
