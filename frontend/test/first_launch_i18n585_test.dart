// v585 (bug 17, Daniel : « le menu des langues qui apparaît la première fois :
// qu'il soit bien traduit ») — garde-fou : chaque clé affichée par les écrans
// et fenêtres du PREMIER LANCEMENT existe dans les 9 langues, le sélecteur de
// langue est le sélecteur signature, et chaque langue s'écrit dans sa langue.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/localization/app_translations.dart';

const _files = [
  'lib/views/auth/login_screen.dart',
  'lib/views/auth/sign_up_screen.dart',
  'lib/views/auth/sign_up_as.dart',
  'lib/views/guest/guest_landing_screen.dart',
  'lib/views/onboarding/onboarding_screen.dart',
  'lib/views/profile/widgets/appearance_language_section.dart',
  'lib/services/push_notification_service.dart',
  'lib/views/map/widgets/pawmap_sheet.dart',
];

void main() {
  test('toutes les clés du premier lancement existent dans les 9 langues', () {
    final all = AppTranslations().keys;
    expect(all.length, 9);
    final re = RegExp(r"'([a-z][a-z0-9_]+)'\s*\.tr");
    final missing = <String>[];
    for (final f in _files) {
      final file = File(f);
      if (!file.existsSync()) continue;
      for (final m in re.allMatches(file.readAsStringSync())) {
        final k = m.group(1)!;
        for (final loc in all.keys) {
          if (!all[loc]!.containsKey(k)) missing.add('$f : $k ($loc)');
        }
      }
    }
    expect(missing, isEmpty, reason: missing.take(40).join('\n'));
  });

  test('le sélecteur de langue de la connexion / inscription = le sélecteur signature', () {
    for (final f in ['lib/views/auth/login_screen.dart', 'lib/views/auth/sign_up_screen.dart']) {
      final s = File(f).readAsStringSync();
      expect(s.contains('showAppLanguagePicker('), isTrue, reason: f);
      expect(s.contains("title: 'language_dialog_title'.tr"), isFalse,
          reason: '$f : ancien Get.defaultDialog');
    }
  });

  test('chaque langue écrite dans SA langue, avec son drapeau', () {
    expect(LocalizationService.languageLabels, {
      'en': 'English', 'fr': 'Français', 'es': 'Español', 'de': 'Deutsch',
      'it': 'Italiano', 'pt': 'Português', 'ko': '한국어', 'ja': '日本語', 'pl': 'Polski',
    });
    for (final k in LocalizationService.languageLabels.keys) {
      expect((LocalizationService.languageFlags[k] ?? '').isNotEmpty, isTrue, reason: k);
    }
  });
}
