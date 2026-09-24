// v585 (lot D) — ZÉRO GRIS, contrôlé par la SATURATION (règle de Daniel,
// EQUIPE_HOPETSIT.md : « zéro gris nulle part, détecté par la saturation
// HSL »). Une couleur littérale `Color(0xAARRGGBB)` est un gris quand sa
// saturation HSL est < 0,25 et sa luminosité entre 12 % et 92 % (les
// blancs, noirs et encres très sombres ne sont pas des gris). Les
// `Colors.grey`, `Colors.blueGrey`, `Colors.black12…87` et `Colors.white70…10`
// (blancs / noirs translucides = gris sur fond) comptent aussi.
//
// Les gris encore présents sont listés dans `lotd_allowlist.dart` (compte par
// fichier, figé) : ce test ÉCHOUE si un gris apparaît dans un fichier absent
// de la liste, ou si un fichier en contient PLUS qu'avant.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lotd_allowlist.dart';

final RegExp _hex = RegExp(r'Color\(0x([0-9A-Fa-f]{8})\)');
final RegExp _named = RegExp(
    r'Colors\.(grey|blueGrey|black(12|26|38|45|54|87)|white(70|60|54|38|30|24|12|10))\b');

/// Gris = saturation < 0,25 et luminosité 12–92 %, alpha ≥ 25 %.
bool isGray(String hex8) {
  final int v = int.parse(hex8, radix: 16);
  final Color c = Color(v);
  if (c.a < 0.25) return false;
  final HSLColor hsl = HSLColor.fromColor(c);
  if (hsl.lightness < 0.12 || hsl.lightness > 0.92) return false;
  return hsl.saturation < 0.25;
}

Map<String, int> scanGrays(Directory lib) {
  final Map<String, int> out = <String, int>{};
  for (final f in lib.listSync(recursive: true).whereType<File>()) {
    if (!f.path.endsWith('.dart')) continue;
    final rel = f.path.substring(f.path.indexOf('lib/'));
    if (rel == 'lib/widgets/paw_button_kit.dart') continue;
    int n = 0;
    for (final line in f.readAsLinesSync()) {
      if (line.trimLeft().startsWith('//')) continue;
      final code = line.split('//').first;
      for (final m in _hex.allMatches(code)) {
        if (isGray(m.group(1)!)) n++;
      }
      n += _named.allMatches(code).length;
    }
    if (n > 0) out[rel] = n;
  }
  return out;
}

void main() {
  test('la règle reconnaît un gris et laisse passer une teinte chaude', () {
    expect(isGray('FF9E9E9E'), isTrue); // gris Material 500
    expect(isGray('FFF5F5F5'), isFalse); // quasi blanc : pas un gris
    expect(isGray('FF17141F'), isFalse); // encre premium, très sombre
    expect(isGray('FFB5651D'), isFalse); // caramel chaud (saturation 0,84)
    expect(isGray('FFC92A12'), isFalse); // orange propriétaire
    expect(isGray('FFB9A7A2'), isTrue); // beige-gris (saturation 0,12)
  });

  test('aucun gris nouveau dans lib/ (hors liste figée)', () {
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue, reason: 'lancer depuis frontend/');
    final found = scanGrays(lib);
    final List<String> problems = <String>[];
    found.forEach((file, n) {
      final allowed = kGrayColorsAllowed[file] ?? 0;
      if (n > allowed) {
        problems.add('$file : $n gris, autorisé $allowed');
      }
    });
    expect(problems, isEmpty,
        reason: 'Gris réapparu (teintes chaudes PLEINES seulement) :\n${problems.join('\n')}');
  });

  test('le kit de boutons et les icônes maison ne contiennent aucun gris', () {
    for (final p in ['lib/widgets/paw_button_kit.dart', 'lib/widgets/paw_icons.dart']) {
      final s = File(p).readAsStringSync();
      for (final m in _hex.allMatches(s)) {
        expect(isGray(m.group(1)!), isFalse, reason: '$p : ${m.group(0)}');
      }
      expect(_named.hasMatch(s), isFalse, reason: p);
    }
  });
}
