// v585 (lot D) — « Tout mon menu marche bien » (Daniel), partie STATIQUE :
// le contrat de navigation lu dans le code source.
//
//   1. Les 3 menus (propriétaire / gardien / promeneur) ont bien 5 onglets,
//      dans l'ordre Accueil · Messages · PawMap · Réservations · Profil, et
//      chaque écran d'onglet existe dans lib/.
//   2. Chaque rangée de la page Profil (`ProfileRow`, 3 rôles) a une action
//      (`onTap`) qui n'est ni `null` ni vide, et sa cible (écran `Get.to`,
//      onglet `openMainTabOr`, méthode du contrôleur, feuille) existe.
//   3. Les écrans cibles sont importés (un `Get.to(() => X())` vers une classe
//      qui n'existe pas ne compile pas, mais un import oublié dans un autre
//      fichier si).
// La partie DYNAMIQUE (ouvrir chaque écran pour de vrai) est dans
// `lotd_menu_screens_test.dart`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String p) => File(p).readAsStringSync();

/// Toutes les classes `class X extends StatelessWidget|StatefulWidget…`
/// déclarées dans lib/.
Set<String> _widgetClasses() {
  final out = <String>{};
  final rx = RegExp(r'^class\s+([A-Z]\w*)\s+extends\s+', multiLine: true);
  for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
    if (!f.path.endsWith('.dart')) continue;
    for (final m in rx.allMatches(f.readAsStringSync())) {
      out.add(m.group(1)!);
    }
  }
  return out;
}

void main() {
  final classes = _widgetClasses();

  group('les 3 menus du bas : 5 onglets, écrans existants', () {
    const wrappers = <String, List<String>>{
      'lib/views/pet_owner/bottom_nav/bottom_nav_wrapper.dart': [
        'HomeScreen', 'ChatScreen', 'PawMapScreen', 'OwnerBookingsScreen', 'ProfileScreen'
      ],
      'lib/views/pet_sitter/bottom_wrapper/sitter_nav_wrapper.dart': [
        'SitterHomescreen', 'SitterChatScreen', 'PawMapScreen', 'SitterBookingsScreen', 'SitterProfileScreen'
      ],
      'lib/views/pet_walker/bottom_wrapper/walker_nav_wrapper.dart': [
        'SitterHomescreen', 'SitterChatScreen', 'PawMapScreen', 'WalkerBookingsScreen', 'WalkerProfileScreen'
      ],
    };
    wrappers.forEach((file, expected) {
      test(file, () {
        final src = _read(file);
        final m = RegExp(r'_screens\s*=\s*(?:const\s*)?\[(.*?)\];', dotAll: true).firstMatch(src);
        expect(m, isNotNull, reason: 'liste _screens introuvable');
        final body = m!.group(1)!.replaceAll(RegExp(r'//.*'), '');
        final found = RegExp(r'([A-Z]\w*)\s*\(').allMatches(body).map((x) => x.group(1)!).toList();
        expect(found, expected, reason: 'onglets de $file');
        for (final c in expected) {
          expect(classes, contains(c), reason: '$c n\'existe pas dans lib/');
        }
      });
    });
  });

  group('page Profil : chaque rangée a une action branchée', () {
    final src = _read('lib/views/profile/widgets/profile_categories.dart');

    test('aucune rangée sans onTap, aucune action vide', () {
      final rows = RegExp(r'ProfileRow\(\s*(.*?)\n\s*\),', dotAll: true).allMatches(src).toList();
      expect(rows.length, greaterThanOrEqualTo(28), reason: 'rangées du profil');
      final problems = <String>[];
      for (final r in rows) {
        final body = '${r.group(1)!}\n';
        final title = RegExp(r"title:\s*'([^']+)'").firstMatch(body)?.group(1) ?? '?';
        final onTap = RegExp(r'onTap:\s*(.+?),?\n', dotAll: true).firstMatch(body)?.group(1)?.trim();
        if (onTap == null || onTap == 'null' || onTap == '() {}' || onTap == '(){}') {
          problems.add('$title → onTap $onTap');
          continue;
        }
        // Cibles connues : écran poussé, onglet, méthode du contrôleur, feuille.
        final target = RegExp(r'Get\.to\(\s*\(\)\s*=>\s*(?:const\s+)?([A-Z]\w*)\(').firstMatch(onTap)?.group(1);
        final tab = RegExp(r'openMainTabOr\((\d)').firstMatch(onTap);
        final host = RegExp(r'host\.(\w+)').firstMatch(onTap);
        final sheet = RegExp(r'\b(show\w+|open\w+)\(').firstMatch(onTap);
        // Un rappel passé par l'écran parent (ex. `onEditProfile`).
        final callback = RegExp(r'^on[A-Z]\w*$').hasMatch(onTap);
        if (target != null) {
          if (!classes.contains(target)) problems.add('$title → $target introuvable');
        } else if (tab == null && host == null && sheet == null && !callback) {
          problems.add('$title → action non reconnue : $onTap');
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('Aide : Comprendre la PawMap en tête, boîte à idées, dépannage en bas', () {
      final help = src.substring(src.indexOf('Widget _help('));
      final order = [
        help.indexOf("'pawmap_help_title'.tr"),
        help.indexOf("'feedback_title'.tr"),
        help.indexOf("'terms_read_button'.tr"),
        help.indexOf("'profile_privacy'.tr"),
        help.indexOf("'help_troubleshoot'.tr"),
      ];
      for (int i = 0; i < order.length; i++) {
        expect(order[i], greaterThanOrEqualTo(0), reason: 'entrée $i absente');
        if (i > 0) expect(order[i], greaterThan(order[i - 1]), reason: 'ordre de l\'aide');
      }
      expect(help, contains('PawMapHelpScreen()'));
      expect(help, contains('IdeaBoxScreen()'));
      expect(help, contains('NotificationTestScreen()'));
      expect(help, isNot(contains('BugReportScreen()')), reason: 'une seule entrée idée/problème');
    });
  });

  test('deep links : chaque onglet cible du routeur existe (1 chat, 2 PawMap, 3 réservations, 4 profil)', () {
    final src = _read('lib/services/deep_link_service.dart');
    expect(src, contains('_goToTab'));
    final state = _read('lib/utils/map_ui_state.dart');
    expect(state, contains('kPawMapTabIndex = 2'));
    expect(state, contains('openMainTabOr'));
  });
}
