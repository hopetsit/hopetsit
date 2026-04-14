import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../utils/storage_keys.dart';
import 'translations/en.dart';
import 'translations/fr.dart';
import 'translations/es.dart';
import 'translations/de.dart';
import 'translations/it.dart';
import 'translations/pt.dart';

/// Centralizes supported locales and translation keys for the app.
class LocalizationService {
  LocalizationService._();

  /// Storage key for persisting the selected language code.
  static const String _languageCodeKey = StorageKeys.languageCode;

  /// Fallback locale when nothing is stored or device locale is unsupported.
  static const Locale fallbackLocale = Locale('en', 'US');

  /// Mapping from simple language codes to concrete [Locale]s.
  static final Map<String, Locale> _supportedLocaleMap = <String, Locale>{
    'en': const Locale('en', 'US'),
    'fr': const Locale('fr', 'FR'),
    'es': const Locale('es', 'ES'),
    'de': const Locale('de', 'DE'),
    'it': const Locale('it', 'IT'),
    'pt': const Locale('pt', 'PT'),
  };

  /// Human‑readable language names used in selection UIs.
  static final Map<String, String> languageLabels = <String, String>{
    'en': 'English',
    'fr': 'Français',
    'es': 'Español',
    'de': 'Deutsch',
    'it': 'Italiano',
    'pt': 'Português',
  };

  /// All supported locales for Flutter / GetX.
  static List<Locale> get supportedLocales =>
      _supportedLocaleMap.values.toList(growable: false);

  /// Determine the initial locale using persisted value, then device locale.
  static Locale getInitialLocale() {
    final storage = GetStorage();
    final storedCode = storage.read<String>(_languageCodeKey);

    if (storedCode != null && _supportedLocaleMap.containsKey(storedCode)) {
      return _supportedLocaleMap[storedCode]!;
    }

    final deviceLocale = Get.deviceLocale;
    if (deviceLocale != null &&
        _supportedLocaleMap.containsKey(deviceLocale.languageCode)) {
      return _supportedLocaleMap[deviceLocale.languageCode]!;
    }

    return fallbackLocale;
  }

  /// Persist and apply the new locale at runtime.
  static Future<void> updateLocale(String languageCode) async {
    final storage = GetStorage();
    final locale = _supportedLocaleMap[languageCode] ?? fallbackLocale;
    await storage.write(_languageCodeKey, languageCode);
    Get.updateLocale(locale);
  }

  /// Returns the simple language code currently persisted, or the fallback.
  static String getCurrentLanguageCode() {
    final storage = GetStorage();
    final storedCode = storage.read<String>(_languageCodeKey);
    if (storedCode != null && _supportedLocaleMap.containsKey(storedCode)) {
      return storedCode;
    }
    return fallbackLocale.languageCode;
  }
}

/// GetX translations for the app, now split into per-locale files under
/// translations/{lang}.dart (sprint 8 step 2). en_US is the canonical source;
/// missing keys in other locales are logged in debug builds.
class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys {
    _checkMissingKeys();
    return <String, Map<String, String>>{
      'en_US': enUSTranslations,
      'fr_FR': frFRTranslations,
      'es_ES': esESTranslations,
      'de_DE': deDETranslations,
      'it_IT': itITTranslations,
      'pt_PT': ptPTTranslations,
    };
  }

  static bool _didCheck = false;
  void _checkMissingKeys() {
    if (_didCheck || !kDebugMode) return;
    _didCheck = true;
    final canonical = enUSTranslations.keys.toSet();
    final others = <String, Map<String, String>>{
      'fr_FR': frFRTranslations,
      'es_ES': esESTranslations,
      'de_DE': deDETranslations,
      'it_IT': itITTranslations,
      'pt_PT': ptPTTranslations,
    };
    others.forEach((locale, map) {
      final missing = canonical.difference(map.keys.toSet());
      if (missing.isNotEmpty) {
        debugPrint(
          '[i18n] $locale is missing ${missing.length} keys '
          '(first 5: ${missing.take(5).join(", ")})',
        );
      }
    });
  }
}
