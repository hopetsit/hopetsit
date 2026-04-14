import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/localization/translations/en.dart';
import 'package:hopetsit/localization/translations/fr.dart';
import 'package:hopetsit/localization/translations/es.dart';
import 'package:hopetsit/localization/translations/de.dart';
import 'package:hopetsit/localization/translations/it.dart';
import 'package:hopetsit/localization/translations/pt.dart';

void main() {
  group('i18n coverage — en_US is canonical', () {
    // Sprint 8 step 8 — pt is a partial locale by design; allow up to this
    // many missing keys before the test fails (the rest falls back to en_US
    // at runtime via GetX).
    const int ptAllowedMissing = 1500;

    test('fr_FR has all en_US keys', () {
      final missing = enUSTranslations.keys.toSet()
        ..removeAll(frFRTranslations.keys);
      expect(missing, isEmpty,
          reason: 'Missing fr_FR keys: ${missing.take(10).join(", ")}');
    });

    test('es_ES has all en_US keys', () {
      final missing = enUSTranslations.keys.toSet()
        ..removeAll(esESTranslations.keys);
      expect(missing, isEmpty,
          reason: 'Missing es_ES keys: ${missing.take(10).join(", ")}');
    });

    test('de_DE has all en_US keys', () {
      final missing = enUSTranslations.keys.toSet()
        ..removeAll(deDETranslations.keys);
      expect(missing, isEmpty,
          reason: 'Missing de_DE keys: ${missing.take(10).join(", ")}');
    });

    test('it_IT has all en_US keys', () {
      final missing = enUSTranslations.keys.toSet()
        ..removeAll(itITTranslations.keys);
      expect(missing, isEmpty,
          reason: 'Missing it_IT keys: ${missing.take(10).join(", ")}');
    });

    test('pt_PT is tolerated as partial (fallback to en_US at runtime)', () {
      final missing = enUSTranslations.keys.toSet()
        ..removeAll(ptPTTranslations.keys);
      expect(missing.length, lessThanOrEqualTo(ptAllowedMissing),
          reason:
              'pt_PT missing too many keys (${missing.length}) — either translate them or raise the threshold.');
    });

    test('no empty values in en_US (canonical source)', () {
      final blanks = enUSTranslations.entries.where((e) => e.value.trim().isEmpty);
      expect(blanks, isEmpty,
          reason:
              'en_US contains empty translations for: ${blanks.map((e) => e.key).join(", ")}');
    });
  });
}
