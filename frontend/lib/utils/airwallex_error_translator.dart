import 'package:get/get.dart';

import '../data/network/api_exception.dart';

/// v23.1 — translates the structured payment error codes returned by the
/// backend (see backend/src/services/airwallexService.js → mapAirwallexError)
/// into i18n keys / human-friendly localized strings.
///
/// Backend returns JSON like:
///   { "error": "...", "code": "PAYMENT_INTENT_FAILED", "details": "...", "debug": {...} }
///
/// The frontend reads `code` first to decide what to display in the toast.
class AirwallexErrorTranslator {
  AirwallexErrorTranslator._();

  /// Maps a structured backend code to a translation key.
  static const Map<String, String> _codeToKey = {
    'PAYMENT_INTENT_FAILED': 'payment_error_intent_failed',
    'PAYMENT_AUTH_FAILED': 'payment_error_auth_failed',
    'PAYMENT_DECLINED': 'payment_error_declined',
    'PROVIDER_NOT_CONFIGURED': 'payment_error_provider_not_configured',
    'AMOUNT_INVALID': 'payment_error_amount_invalid',
    'CURRENCY_INVALID': 'payment_error_currency_invalid',
    'ENV_NOT_CONFIGURED': 'payment_error_env_not_configured',
    'INVALID_ID': 'payment_error_invalid_id',
    'PROVIDER_INCOMPLETE': 'payment_error_provider_incomplete',
    'UNKNOWN': 'payment_error_unknown',
  };

  /// Translate a code into a localized message. Falls back to
  /// `payment_error_unknown.tr` if the code is null/unmapped.
  static String translate(String? code) {
    if (code == null || code.isEmpty) {
      return 'payment_error_unknown'.tr;
    }
    final key = _codeToKey[code] ?? 'payment_error_unknown';
    return key.tr;
  }

  /// Convenience: extract the structured `code` from an [ApiException].
  /// Looks at `details['code']` (the backend JSON payload) first, otherwise
  /// returns null.
  static String? extractCode(ApiException error) {
    final details = error.details;
    if (details is Map) {
      final c = details['code'];
      if (c is String && c.isNotEmpty) return c;
    }
    return null;
  }

  /// Returns true when the code maps to a 4xx-style validation error the
  /// user can act on (vs a 5xx where retrying is the only sensible advice).
  static bool isUserActionable(String? code) {
    if (code == null) return false;
    return code == 'AMOUNT_INVALID' ||
        code == 'CURRENCY_INVALID' ||
        code == 'PROVIDER_NOT_CONFIGURED' ||
        code == 'PROVIDER_INCOMPLETE' ||
        code == 'PAYMENT_DECLINED' ||
        code == 'INVALID_ID';
  }
}
