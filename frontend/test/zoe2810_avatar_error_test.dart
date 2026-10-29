// ZOE (28/10/2026) — garde-fou : `onBackgroundImageError` seulement sur un
// CircleAvatar qui a un `backgroundImage`. Sinon Flutter lève l'assertion
// « backgroundImage != null || onBackgroundImageError == null » : mesuré au
// simulateur, la fiche de l'animal côté gardien (pet_detail_screen.dart) restait
// VIDE en debug — l'erreur avait été posée sur l'anneau extérieur, sans image.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Retire les commentaires `//` (hors chaînes simples) pour ne pas fausser le
/// découpage des arguments.
String _sansCommentaires(String s) => s
    .split('\n')
    .map((l) {
      final i = l.indexOf('//');
      if (i < 0) return l;
      final avant = l.substring(0, i);
      // `//` à l'intérieur d'une URL entre guillemets : on garde la ligne.
      if ("'".allMatches(avant).length.isOdd) return l;
      return avant;
    })
    .join('\n');

/// Noms des arguments de premier niveau d'un appel dont le corps est [body].
List<String> _argsDePremierNiveau(String body) {
  final out = <String>[];
  var d = 0;
  var cur = StringBuffer();
  for (final c in body.split('')) {
    if ('([{'.contains(c)) d++;
    if (')]}'.contains(c)) d--;
    if (c == ',' && d == 0) {
      out.add(cur.toString());
      cur = StringBuffer();
    } else {
      cur.write(c);
    }
  }
  out.add(cur.toString());
  return out
      .where((a) => a.contains(':'))
      .map((a) => a.split(':').first.trim())
      .toList();
}

void main() {
  test('onBackgroundImageError jamais sur un CircleAvatar sans backgroundImage', () {
    final fautifs = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final s = _sansCommentaires(f.readAsStringSync());
      for (final m in RegExp(r'CircleAvatar\(').allMatches(s)) {
        var d = 1;
        var j = m.end;
        while (d > 0 && j < s.length) {
          final c = s[j];
          if ('([{'.contains(c)) d++;
          if (')]}'.contains(c)) d--;
          j++;
        }
        final noms = _argsDePremierNiveau(s.substring(m.end, j - 1));
        if (noms.contains('onBackgroundImageError') && !noms.contains('backgroundImage')) {
          final ligne = '\n'.allMatches(s.substring(0, m.start)).length + 1;
          fautifs.add('${f.path}:$ligne');
        }
      }
    }
    expect(fautifs, isEmpty, reason: 'CircleAvatar sans image avec onBackgroundImageError : $fautifs');
  });
}
