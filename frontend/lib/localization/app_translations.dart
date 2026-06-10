import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../data/network/api_client.dart';
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
    // v23.1.348 — Daniel : "la langue doit suivre le système dès
    // l'installation". On synchronise la langue UI vers le backend
    // (user.appLocale) pour que notifications + emails partent dans la
    // bonne langue. Fire-and-forget : un échec réseau ne bloque jamais
    // le changement de langue local.
    _syncedThisSession = false; // re-sync après un changement manuel
    syncToBackend();
  }

  // v23.1.348 — garde anti-spam : 1 synchro par session app (plus une à
  // chaque changement manuel de langue via updateLocale ci-dessus).
  static bool _syncedThisSession = false;

  /// Pousse la langue UI courante (choisie OU héritée du téléphone) vers le
  /// backend (PATCH /users/me/app-locale) — silencieux et best-effort :
  ///   - pas de token → utilisateur pas connecté → no-op,
  ///   - ApiClient pas enregistré (boot précoce) → no-op,
  ///   - erreur réseau → ignorée (retentée à la prochaine session).
  static Future<void> syncToBackend() async {
    if (_syncedThisSession) return;
    try {
      if (!Get.isRegistered<ApiClient>()) return;
      // v23.1.348 — le JWT vit dans le secure storage (Keychain/Keystore)
      // depuis v125, avec GetStorage en legacy : ApiClient.authToken combine
      // les deux sources — on l'utilise au lieu de lire GetStorage direct.
      final token = Get.find<ApiClient>().authToken;
      if (token == null || token.isEmpty) return;
      final code = getCurrentLanguageCode();
      _syncedThisSession = true;
      await Get.find<ApiClient>().patch(
        '/users/me/app-locale',
        body: {'locale': code},
        requiresAuth: true,
      );
      debugPrint('[i18n] appLocale synced to backend: $code');
    } catch (e) {
      _syncedThisSession = false; // retentera plus tard
      debugPrint('[i18n] appLocale sync failed (non-bloquant): $e');
    }
  }

  /// Returns the simple language code currently persisted, or the fallback.
  static String getCurrentLanguageCode() {
    final storage = GetStorage();
    final storedCode = storage.read<String>(_languageCodeKey);
    if (storedCode != null && _supportedLocaleMap.containsKey(storedCode)) {
      return storedCode;
    }
    // v23.1.347 — Daniel : "CGU et confidentialité toujours en anglais ?!".
    // L'UI (getInitialLocale) suit la LANGUE DU TÉLÉPHONE quand l'utilisateur
    // n'a jamais choisi de langue dans le profil, mais ce getter retombait
    // directement sur l'anglais → app affichée en français MAIS pages légales
    // (CGU, confidentialité) et autres lecteurs de ce code en anglais. On
    // applique la MÊME cascade : langue choisie → langue du téléphone → EN.
    final deviceLocale = Get.deviceLocale;
    if (deviceLocale != null &&
        _supportedLocaleMap.containsKey(deviceLocale.languageCode)) {
      return deviceLocale.languageCode;
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
