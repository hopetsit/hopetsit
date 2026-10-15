// 616 (PAM, demande Daniel 14/10 « quesitos du Trivial ») — ronds de
// regroupement en PARTS aux couleurs des rôles, proportionnelles aux
// effectifs ; un seul rôle = rond uni ; nombre lisible sur pastille blanche.
// Le painter est RENDU en image et les pixels sont mesurés ; les images
// 2 et 3 couleurs sont écrites dans ~/hopetsit-social/preuves/ (captures).
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';

const double kDpr = 3;

Future<ui.Image> _render(int count, Map<String, int>? roles) {
  final box = PawMapPinPainter.memberClusterWidth(count) + 12;
  return renderPinImage(box, box,
      (c) => PawMapPinPainter.paintMemberCluster(c, count, roleCounts: roles),
      scale: kDpr);
}

Future<Color> _pixel(ui.Image img, double x, double y) async {
  final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  final px = bd!.buffer.asUint8List();
  final w = img.width;
  final i = ((y * kDpr).round() * w + (x * kDpr).round()) * 4;
  return Color.fromARGB(px[i + 3], px[i], px[i + 1], px[i + 2]);
}

bool _close(Color a, Color b, [int tol = 28]) =>
    ((a.r - b.r) * 255).abs() <= tol &&
    ((a.g - b.g) * 255).abs() <= tol &&
    ((a.b - b.b) * 255).abs() <= tol;

Future<void> _savePng(ui.Image img, String name) async {
  final dir = Directory('${Platform.environment['HOME']}/hopetsit-social/preuves');
  if (!dir.existsSync()) return;
  final bd = await img.toByteData(format: ui.ImageByteFormat.png);
  File('${dir.path}/$name').writeAsBytesSync(bd!.buffer.asUint8List());
}

void main() {
  group('memberClusterSlices (pur)', () {
    test('sans détail : une seule part', () {
      final s = PawMapPinPainter.memberClusterSlices(null, 5);
      expect(s.length, 1);
      expect(s.first.share, 1.0);
    });
    test('un seul rôle : une part pleine', () {
      final s = PawMapPinPainter.memberClusterSlices({'sitter': 3}, 3);
      expect(s.length, 1);
      expect(s.first.role, 'sitter');
      expect(s.first.share, 1.0);
    });
    test('trois rôles : parts proportionnelles, ordre fixe', () {
      final s = PawMapPinPainter.memberClusterSlices(
          {'owner': 2, 'sitter': 1, 'walker': 1}, 4);
      expect(s.map((e) => e.role).toList(), ['owner', 'sitter', 'walker']);
      expect(s[0].share, 0.5);
      expect(s[1].share, 0.25);
      expect(s[2].share, 0.25);
      expect(s.fold<double>(0, (a, e) => a + e.share), closeTo(1, 1e-9));
    });
    test('rôle à zéro : pas de part', () {
      final s = PawMapPinPainter.memberClusterSlices(
          {'owner': 0, 'sitter': 2, 'walker': 2}, 4);
      expect(s.map((e) => e.role).toList(), ['sitter', 'walker']);
    });
  });

  group('paintMemberCluster (pixels)', () {
    // Centre du rond dans le bitmap (marge 6 + moitié du côté).
    final box = PawMapLegend.memberClusterHeight;
    final cx = 6 + box / 2, cy = 6 + box / 2;

    test('2 rôles : moitié orange (propriétaire) / moitié bleue (gardien)',
        () async {
      final img = await _render(2, {'owner': 1, 'sitter': 1});
      // Départ à midi, sens horaire : propriétaire à DROITE, gardien à GAUCHE.
      final right = await _pixel(img, cx + 15, cy);
      final left = await _pixel(img, cx - 15, cy);
      final center = await _pixel(img, cx, cy + 6);
      expect(_close(right, PawMapLegend.roleColor('owner')), isTrue,
          reason: 'droite = propriétaire, trouvé $right');
      expect(_close(left, PawMapLegend.roleColor('sitter')), isTrue,
          reason: 'gauche = gardien, trouvé $left');
      expect(_close(center, Colors.white), isTrue,
          reason: 'pastille blanche au centre, trouvé $center');
      await _savePng(img, 'pam616_rond_2couleurs.png');
      img.dispose();
    });

    test('3 rôles : 3 parts aux 3 couleurs', () async {
      final img = await _render(3, {'owner': 1, 'sitter': 1, 'walker': 1});
      // Parts de 120° : propriétaire −90°→30° (milieu −30°), gardien 30°→150°
      // (milieu 90°), promeneur 150°→270° (milieu 210°). Rayon 15.
      Future<Color> at(double deg) async {
        final a = deg * 3.141592653589793 / 180;
        return _pixel(img, cx + 15 * ui.Offset(1, 0).dx * (a == 0 ? 1 : 1) * _cos(a),
            cy + 15 * _sin(a));
      }

      expect(_close(await at(-30), PawMapLegend.roleColor('owner')), isTrue);
      expect(_close(await at(90), PawMapLegend.roleColor('sitter')), isTrue);
      expect(_close(await at(210), PawMapLegend.roleColor('walker')), isTrue);
      await _savePng(img, 'pam616_rond_3couleurs.png');
      img.dispose();
    });

    test('1 rôle : rond uni à la couleur du rôle, jamais gris', () async {
      final img = await _render(28, {'sitter': 28});
      final p = await _pixel(img, cx - 17, cy);
      final hsl = HSLColor.fromColor(p);
      expect(hsl.saturation, greaterThan(0.25), reason: 'zéro gris : $p');
      expect(_close(p, PawMapLegend.roleColor('sitter'), 60), isTrue,
          reason: 'bleu gardien attendu, trouvé $p');
      img.dispose();
    });

    test('proportions : 3 propriétaires + 1 gardien = 270° orange', () async {
      final img = await _render(4, {'owner': 3, 'sitter': 1});
      // 270° orange de −90° à 180° ; gardien de 180° à 270° (milieu 225°).
      final blue = await _pixel(img, cx + 15 * _cos(225 * 3.141592653589793 / 180),
          cy + 15 * _sin(225 * 3.141592653589793 / 180));
      final orange = await _pixel(img, cx + 15 * _cos(90 * 3.141592653589793 / 180),
          cy + 15 * _sin(90 * 3.141592653589793 / 180));
      expect(_close(blue, PawMapLegend.roleColor('sitter')), isTrue,
          reason: 'gardien à 225°, trouvé $blue');
      expect(_close(orange, PawMapLegend.roleColor('owner')), isTrue,
          reason: 'propriétaire à 90°, trouvé $orange');
      img.dispose();
    });
  });
}

double _cos(double a) => _series(a, true);
double _sin(double a) => _series(a, false);
double _series(double a, bool cos) {
  // Petit cos/sin maison pour ne pas importer dart:math dans le test.
  double x = a % (2 * 3.141592653589793);
  double term = cos ? 1 : x, sum = term;
  for (var n = 1; n < 12; n++) {
    final k = cos ? (2 * n - 1) * (2 * n) : (2 * n) * (2 * n + 1);
    term *= -x * x / k;
    sum += term;
  }
  return sum;
}
