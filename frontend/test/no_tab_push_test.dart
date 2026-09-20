// v573 — garde-fou : « le menu d'en bas avait disparu » (Daniel, 20/09/2026).
//
// Les 5 destinations du menu principal (Accueil · Chat · PawMap · Réservations
// · Profil) ne doivent JAMAIS être empilées telles quelles par
// `Get.to(() => const XScreen())` : on obtient une page plein écran SANS menu.
// Il faut passer par `openMainTabOr(index, …)` (`lib/utils/map_ui_state.dart`)
// ou `_goToTab` du service de liens. Ce test échoue dès qu'un nouvel
// empilement de ce type apparaît dans `lib/`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test("aucun écran d'onglet n'est empilé sans menu", () {
    final pattern = RegExp(
      r'Get\.to\(\s*\(\)\s*=>\s*const\s+'
      r'(ChatScreen|SitterChatScreen|PawMapScreen|OwnerBookingsScreen|'
      r'SitterBookingsScreen|WalkerBookingsScreen|ProfileScreen|'
      r'SitterProfileScreen|WalkerProfileScreen)\(\)\s*\)',
    );
    // Replis légitimes : uniquement quand le menu n'est pas monté.
    const allowed = <String>{
      'lib/services/deep_link_service.dart',
      'lib/utils/map_ui_state.dart',
    };
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      if (allowed.contains(path)) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        if (pattern.hasMatch(line)) offenders.add('$path:${i + 1}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Utilise openMainTabOr(index, () => const XScreen()) : '
          '${offenders.join(', ')}',
    );
  });
}
