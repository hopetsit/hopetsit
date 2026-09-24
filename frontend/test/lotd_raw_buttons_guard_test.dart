// v585 (lot D) — GARDE-FOU : un bouton Material BRUT (`ElevatedButton`,
// `TextButton`, `OutlinedButton`, `FilledButton`, et leurs `.icon`) ne doit
// pas réapparaître hors du kit signature (`lib/widgets/paw_button_kit.dart`,
// NORME_DESIGN.md « Contrôle final »).
//
// Les boutons bruts encore présents dans des sous-pages sont listés dans
// `lotd_allowlist.dart` (compte par fichier, figé). Ce test ÉCHOUE si :
//   · un fichier absent de la liste contient un bouton brut (nouveau) ;
//   · un fichier de la liste en contient PLUS qu'avant.
// Les lignes de commentaire sont ignorées.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lotd_allowlist.dart';

final RegExp _raw =
    RegExp(r'\b(ElevatedButton|TextButton|OutlinedButton|FilledButton)(\.icon)?\(');

Map<String, int> scanRawButtons(Directory lib) {
  final Map<String, int> out = <String, int>{};
  for (final f in lib.listSync(recursive: true).whereType<File>()) {
    if (!f.path.endsWith('.dart')) continue;
    final rel = f.path.substring(f.path.indexOf('lib/'));
    if (rel == 'lib/widgets/paw_button_kit.dart') continue;
    int n = 0;
    for (final line in f.readAsLinesSync()) {
      if (line.trimLeft().startsWith('//')) continue;
      n += _raw.allMatches(line.split('//').first).length;
    }
    if (n > 0) out[rel] = n;
  }
  return out;
}

void main() {
  test('aucun bouton Material brut hors du kit (hors liste figée)', () {
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue, reason: 'lancer depuis frontend/');
    final found = scanRawButtons(lib);
    final List<String> problems = <String>[];
    found.forEach((file, n) {
      final allowed = kRawButtonsAllowed[file] ?? 0;
      if (n > allowed) {
        problems.add('$file : $n bouton(s) brut(s), autorisé $allowed');
      }
    });
    expect(problems, isEmpty,
        reason: 'Bouton brut réapparu — utiliser PawButton / CustomButton / '
            'ProfilePrimaryButton / ActionPillButton :\n${problems.join('\n')}');
  });

  test('le kit lui-même ne contient aucun bouton Material brut', () {
    final kit = File('lib/widgets/paw_button_kit.dart').readAsStringSync();
    expect(_raw.hasMatch(kit), isFalse);
  });
}
