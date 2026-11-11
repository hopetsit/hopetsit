// 642 (PAM) — les deux coupe-circuits redonnent le 641.
//   · kPawMeSmall642  = false → « Moi » à 56 pt, badges 24 / 20 / 20 ;
//   · kPawBoostSolo642 = false → aucun boosté tenu hors des groupes.
// Ce sont des constantes de compilation : ce fichier se lance DEUX fois —
//   flutter test test/pam642_coupe_circuit_test.dart
//   flutter test --dart-define=PAWMAP_ME_SMALL=false \
//       --dart-define=PAWMAP_BOOST_SOLO=false test/pam642_coupe_circuit_test.dart
// et vérifie dans chaque cas ce que la carte dessine (mesuré sur l'image).
// PAS de coupe-circuit propre au 642 : la taille des amis (40 pt ; le seul
// retour possible est PAWMAP_FRIEND_SMALL=false = amis à 70 pt du 640) et la
// position en direct (porte GPS).
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/widgets/pawmap_boost642.dart';
import 'package:hopetsit/views/map/widgets/pawmap_discreet.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';

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

void main() {
  // ignore: avoid_print
  print('642 coupe-circuits : kPawMeSmall642=$kPawMeSmall642, '
      'kPawBoostSolo642=$kPawBoostSolo642');

  test('« Moi » : constantes selon le coupe-circuit', () {
    if (kPawMeSmall642) {
      expect(kPawMeSize642, 40);
      expect(kPawMeCrown642, 16);
      expect(kPawMeRocket642, 16);
      expect(kPawMeEyeOff642, 16);
      expect(kPawMeBoxR642, 22);
      expect(kPawMeLabelR642, 20);
    } else {
      // exactement le 641
      expect(kPawMeSize642, PawMapLegend.meSize);
      expect(kPawMeSize642, 56);
      expect(kPawMeCrown642, PawMapLegend.crownMe);
      expect(kPawMeCrown642, 24);
      expect(kPawMeRocket642, 20);
      expect(kPawMeEyeOff642, 20);
      expect(kPawMeBoxR642, 30); // 56 / 2 + 2
      expect(kPawMeLabelR642, 28);
    }
  });

  testWidgets('« Moi » : diamètre et contour mesurés sur l\'image', (tester) async {
    late double me, ring;
    await tester.runAsync(() async {
      await ensurePawPinFonts();
      const double sc = 4;
      const double m = PawMapPinPainter.photoMarginBare;
      final double side = PawMapPinPainter.photoBitmapSize(kPawMeSize642, margin: m);
      // ce que fait la carte : taille kPawMeSize642, `me: true`
      final img = await renderPinImage(side, side, (c) {
        PawMapPinPainter.paintPhotoDot(c,
            avatar: null,
            ringColor: PawMapLegend.owner,
            size: kPawMeSize642,
            me: true,
            crownSize: kPawMeCrown642,
            fallbackTint: PawMapLegend.owner,
            margin: m);
      }, scale: sc);
      final px = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();
      final int cy = (side / 2 * sc).round();
      me = _solidRun(px, img.width, cy, cy) / sc;
      var x = cy;
      while (px[(cy * img.width + x - 1) * 4 + 3] >= 230) {
        x--;
      }
      var k = x;
      bool white(int i) =>
          px[(cy * img.width + i) * 4] > 245 &&
          px[(cy * img.width + i) * 4 + 1] > 245 &&
          px[(cy * img.width + i) * 4 + 2] > 245;
      while (!white(k)) {
        k++;
      }
      ring = (k - x) / sc;
      img.dispose();
    });
    // ignore: avoid_print
    print('642 coupe-circuits : « Moi » mesuré $me pt, contour $ring pt');
    expect(me, closeTo(kPawMeSmall642 ? 40 : 56, 0.75));
    expect(ring, closeTo(kPawMeSmall642 ? 2 : 3, 0.5));
  });

  test('PawBoost : boostés seuls (642) ou regroupés (coupe-circuit = 641)', () {
    // 8 profils d'une même ville fictive, dont 3 boostés
    final people = [for (var i = 0; i < 8; i++) 'p$i'];
    final pick = pawBoostSoloPick642([
      for (final i in [1, 4, 6]) (id: 'p$i', dist2: i.toDouble()),
    ]);
    final groups = pawGroupKeepingFriends<String>(
        people, pick.contains, (others) => [if (others.isNotEmpty) others]);
    if (kPawBoostSolo642) {
      expect(pick, {'p1', 'p4', 'p6'});
      expect(groups.length, 4); // 3 pastilles boostées + 1 groupe de 5
      expect(groups.last.length, 5);
    } else {
      expect(pick, isEmpty);
      expect(groups.length, 1); // un seul groupe de 8, comme au 641
      expect(groups.single.length, 8);
      expect(pawBoostSolo642(true), isFalse);
    }
    // le paramètre `enabled` donne la même preuve sans recompiler
    expect(pawBoostSoloPick642([(id: 'a', dist2: 0.0)], enabled: false), isEmpty);
  });
}
