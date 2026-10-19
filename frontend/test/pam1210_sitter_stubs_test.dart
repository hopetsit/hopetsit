// PAM 12/10/2026 — garde-fou : les deux boutons du fil gardien « Bloquer »
// et « Signaler » étaient des stubs (bannière de succès sans appel serveur,
// simple ligne de journal). Ce test ÉCHOUE si un stub « TODO: wire » revient
// dans un écran, ou si les deux boutons ne sont plus branchés sur
// `FriendController.blockUser` et `ReportDialog.show`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aucun bouton stub « TODO: wire » dans lib/views', () {
    final views = Directory('lib/views');
    expect(views.existsSync(), isTrue, reason: 'lancer depuis frontend/');
    final List<String> hits = <String>[];
    for (final f in views.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('TODO: wire')) hits.add('${f.path}:${i + 1}');
      }
    }
    expect(hits, isEmpty, reason: 'bouton non branché :\n${hits.join('\n')}');
  });

  test('fil gardien : Bloquer et Signaler sont branchés', () {
    final src = File('lib/views/pet_sitter/home/sitter_homescreen.dart')
        .readAsStringSync();
    expect(src.contains('friends.blockUser('), isTrue,
        reason: 'Bloquer doit appeler FriendController.blockUser (POST /blocks)');
    expect(src.contains("targetRole: 'owner'"), isTrue);
    expect(src.contains('ReportDialog.show('), isTrue,
        reason: 'Signaler doit ouvrir ReportDialog (POST /reports)');
    expect(src.contains("targetType: 'post'"), isTrue);
  });
}
