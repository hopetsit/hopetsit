// 639 (PAM) — mesure RÉELLE, sur la machine de test, du coût d'une image
// d'épingle : ancien rond « anneau » (2610) contre pastille v2 (639), mêmes
// états, même densité, même chaîne que le cache de la carte (dessin →
// image → PNG). Les surfaces sont exactes (vérifiées) ; les durées sont
// affichées, jamais vérifiées (elles dépendent de la machine).
//   flutter test test/pawmap639_bench_test.dart --reporter expanded
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';
import 'package:hopetsit/views/map/widgets/pawmap_ring2610.dart';

const int _n = 40;

Future<({int px, int bytes, double ms})> _measure(
    Size sz, double sc, void Function(Canvas) paint) async {
  final w = (sz.width * sc).ceil(), h = (sz.height * sc).ceil();
  var bytes = 0;
  // Un tour à blanc (chargement des tracés, polices).
  for (var pass = 0; pass < 2; pass++) {
    final sw = Stopwatch()..start();
    for (var i = 0; i < _n; i++) {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec)..scale(sc, sc);
      paint(c);
      final img = await rec.endRecording().toImage(w, h);
      final d = (await img.toByteData(format: ui.ImageByteFormat.png))!;
      bytes = d.lengthInBytes;
      img.dispose();
    }
    sw.stop();
    if (pass == 1) {
      return (px: w * h, bytes: bytes, ms: sw.elapsedMicroseconds / 1000 / _n);
    }
  }
  throw StateError('inatteignable');
}

void main() {
  test('639 — coût d\'une image : ancien rond 2610 contre pastille v2', () async {
    final cases = <(
      String,
      Size Function(),
      void Function(Canvas),
      Size Function(),
      void Function(Canvas)
    )>[
      (
        'un rôle',
        () => pawRingBitmap2610(1, multi: false),
        (c) => paintRingBitmap2610(c, roles: const ['sitter']),
        () => pawPinBitmap639(PawPinSpec639(roles: const ['sitter'])),
        (c) => paintPin639(c, PawPinSpec639(roles: const ['sitter'])),
      ),
      (
        'trois rôles',
        () => pawRingBitmap2610(1, multi: true),
        (c) => paintRingBitmap2610(c, roles: const ['owner', 'sitter', 'walker']),
        () => pawPinBitmap639(
            PawPinSpec639(roles: const ['owner', 'sitter', 'walker'])),
        (c) => paintPin639(
            c, PawPinSpec639(roles: const ['owner', 'sitter', 'walker'])),
      ),
      (
        'Premium',
        () => pawRingBitmap2610(1, multi: false),
        (c) => paintRingBitmap2610(c, roles: const ['sitter'], premium: true),
        () => pawPinBitmap639(
            PawPinSpec639(roles: const ['sitter'], premium: true)),
        (c) => paintPin639(
            c, PawPinSpec639(roles: const ['sitter'], premium: true)),
      ),
      (
        'PawBoost',
        () => pawRingBitmap2610(1, multi: false),
        (c) => paintRingBitmap2610(c, roles: const ['walker'], boostPhase: 0.25),
        () => pawPinBitmap639(
            PawPinSpec639(roles: const ['walker'], halo: PawHalo639.boost)),
        (c) => paintPin639(
            c, PawPinSpec639(roles: const ['walker'], halo: PawHalo639.boost)),
      ),
      (
        'PawFollow',
        () => pawRingBitmap2610(1, multi: false),
        (c) => paintRingBitmap2610(c, roles: const ['sitter'], pawFollow: true),
        () => pawPinBitmap639(PawPinSpec639(
            roles: const ['sitter'], halo: PawHalo639.follow, wave: 2)),
        (c) => paintPin639(
            c,
            PawPinSpec639(
                roles: const ['sitter'], halo: PawHalo639.follow, wave: 2)),
      ),
      (
        'sélectionnée ×1,18',
        () => pawRingBitmap2610(1.18, multi: false),
        (c) => paintRingBitmap2610(c, roles: const ['sitter'], s: 1.18),
        () => pawPinBitmap639(
            PawPinSpec639(roles: const ['sitter'], selected: true, scale: 1.18)),
        (c) => paintPin639(c,
            PawPinSpec639(roles: const ['sitter'], selected: true, scale: 1.18)),
      ),
    ];

    for (final sc in const [2.0, 3.0]) {
      var oldPx = 0, newPx = 0, oldB = 0, newB = 0;
      double oldMs = 0, newMs = 0;
      for (final (name, oSz, oPaint, nSz, nPaint) in cases) {
        final o = await _measure(oSz(), sc, oPaint);
        final n = await _measure(nSz(), sc, nPaint);
        oldPx += o.px;
        newPx += n.px;
        oldB += o.bytes;
        newB += n.bytes;
        oldMs += o.ms;
        newMs += n.ms;
        // ignore: avoid_print
        print('BENCH639 @${sc}x | $name | avant ${o.px} px, ${o.bytes} o, '
            '${o.ms.toStringAsFixed(2)} ms | après ${n.px} px, ${n.bytes} o, '
            '${n.ms.toStringAsFixed(2)} ms');
        expect(n.px, lessThan(o.px), reason: '$name @$sc : image plus petite');
      }
      // ignore: avoid_print
      print('BENCH639 @${sc}x | TOTAL 6 états | avant $oldPx px, $oldB o, '
          '${oldMs.toStringAsFixed(2)} ms | après $newPx px, $newB o, '
          '${newMs.toStringAsFixed(2)} ms');
      expect(newPx, lessThan(oldPx));
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('639 — PawBoost : 1 image fixe au lieu de 4 phases de respiration', () {
    // Ancien : une image par phase de respiration (kBoostPhases) et une
    // reconstruction des marqueurs à chaque phase. Nouveau : halo fixe.
    final a = PawPinSpec639(roles: const ['walker'], halo: PawHalo639.boost);
    final b = PawPinSpec639(roles: const ['walker'], halo: PawHalo639.boost, wave: 3);
    expect(a.key, b.key);
  });
}
