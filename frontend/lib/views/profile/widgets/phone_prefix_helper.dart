// v565 — point 12 : préfixe téléphone déduit du pays du compte.
//
// Le serveur joint `countryCode + ' ' + mobile` au partage de téléphone
// (conversationRoutes share-phone). Il faut donc stocker :
//   • `countryCode` = indicatif (« +33 »)
//   • `mobile`      = numéro NATIONAL sans indicatif (« 612345678 »)
// Avant ce build, owner et walker concaténaient l'indicatif dans `mobile` →
// « +33 +33612345678 » au partage. Ce helper normalise les deux sens.
import 'package:country_code_picker/country_code_picker.dart' show CountryCode;
import 'package:get/get.dart';

class PhonePrefix {
  PhonePrefix._();

  /// Indicatif (« +33 ») pour un ISO-2 (« FR »), ou '' si inconnu.
  static String dialForIso(String? iso) {
    final code = (iso ?? '').trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(code)) return '';
    try {
      return CountryCode.fromCountryCode(code).dialCode ?? '';
    } catch (_) {
      return '';
    }
  }

  /// ISO-2 (« FR ») pour un indicatif (« +33 »), ou '' si inconnu.
  static String isoForDial(String? dial) {
    final d = (dial ?? '').trim();
    if (d.isEmpty) return '';
    try {
      return CountryCode.fromDialCode(d).code ?? '';
    } catch (_) {
      return '';
    }
  }

  /// ISO-2 du téléphone (région, puis langue, puis US).
  static String deviceIso() {
    final iso = Get.deviceLocale?.countryCode?.toUpperCase();
    if (iso != null && RegExp(r'^[A-Z]{2}$').hasMatch(iso)) return iso;
    const langToCountry = {
      'fr': 'FR', 'es': 'ES', 'de': 'DE', 'it': 'IT', 'pt': 'PT',
      'en': 'US', 'ko': 'KR', 'ja': 'JP', 'pl': 'PL',
    };
    return langToCountry[Get.deviceLocale?.languageCode.toLowerCase()] ?? 'US';
  }

  /// Indicatif à afficher : celui stocké, sinon déduit du pays du compte,
  /// sinon extrait du numéro (« +33… »), sinon celui du téléphone.
  static String resolveDial({
    String? storedCode,
    String? countryIso,
    String? rawMobile,
  }) {
    final stored = (storedCode ?? '').trim();
    if (stored.isNotEmpty) return stored.startsWith('+') ? stored : '+$stored';
    final fromIso = dialForIso(countryIso);
    if (fromIso.isNotEmpty) return fromIso;
    final m = RegExp(r'^\+(\d{1,4})').firstMatch((rawMobile ?? '').trim());
    if (m != null) {
      // On cherche le plus long indicatif connu (ex. +1, +33, +351).
      final digits = m.group(1)!;
      for (var len = digits.length; len >= 1; len--) {
        final candidate = '+${digits.substring(0, len)}';
        if (isoForDial(candidate).isNotEmpty) return candidate;
      }
    }
    return dialForIso(deviceIso());
  }

  /// Numéro national : retire l'indicatif s'il est présent au début du
  /// numéro saisi (« +33 6 12 » / « 0033612 » / « 33612 » → « 612 »),
  /// puis retire les espaces, tirets et parenthèses.
  static String nationalNumber(String raw, String dial) {
    var v = raw.trim();
    if (v.isEmpty) return '';
    final dialDigits = dial.replaceAll(RegExp(r'\D'), '');
    if (v.startsWith('00')) v = '+${v.substring(2)}';
    if (v.startsWith('+')) {
      final digits = v.replaceAll(RegExp(r'\D'), '');
      if (dialDigits.isNotEmpty && digits.startsWith(dialDigits)) {
        v = digits.substring(dialDigits.length);
      } else {
        // Indicatif différent de celui choisi : on garde tout sauf le « + »
        // (le serveur recevra l'indicatif sélectionné + ce numéro).
        v = digits;
      }
    } else {
      v = v.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
      if (dialDigits.isNotEmpty &&
          v.length > 9 &&
          v.startsWith(dialDigits) &&
          !v.startsWith('0')) {
        v = v.substring(dialDigits.length);
      }
    }
    return v;
  }

  /// Numéro complet lisible (« +33 612345678 »).
  static String display(String? dial, String? mobile) {
    final d = (dial ?? '').trim();
    final m = (mobile ?? '').trim();
    if (m.isEmpty) return '';
    if (m.startsWith('+')) return m;
    return d.isEmpty ? m : '$d $m';
  }
}
