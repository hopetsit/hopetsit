// v576 — Daniel : « je vois des erreurs de traduction et des textes anglais
// bruts dans les bandeaux » (exemple vécu : « Email must be a non-empty
// string. » affiché tel quel, 21/09/2026).
//
// CAUSE. Les contrôleurs faisaient `CustomSnackbar.showError(message:
// error.message)` avec le message BRUT du serveur. `CustomSnackbar._t()`
// essaie bien de le retraduire, mais quand il ne le reconnaît pas il le
// laisse passer — et le serveur parle anglais, toujours.
//
// RÈGLE POSÉE ICI : un message serveur technique ne s'affiche JAMAIS. On
// choisit une clé i18n à partir (1) du `code` renvoyé par le serveur,
// (2) de mots-clés du message, (3) du statut HTTP, et sinon un message
// générique clair. Fonction PURE et testable — aucun `.tr` ici, seulement le
// choix de la clé.
import 'package:hopetsit/data/network/api_exception.dart';

/// Codes serveur connus → clé i18n.
const Map<String, String> _kByCode = <String, String>{
  'CITY_REQUIRED': 'fixes576_err_city_required',
  'EMAIL_REQUIRED': 'fixes576_err_email_required',
  'EMAIL_TAKEN': 'fixes576_err_email_taken',
  'EMAIL_ALREADY_USED': 'fixes576_err_email_taken',
  'INVALID_EMAIL': 'fixes576_err_email_invalid',
  'NAME_REQUIRED': 'fixes576_err_name_required',
  'OWN_POST': 'fixes576_err_forbidden',
  'ROLE_REQUIRED': 'fixes576_err_invalid',
  'MANUAL_KYC_DEPRECATED': 'fixes576_err_forbidden',
};

/// Fragments de messages serveur → clé i18n. Comparés sur une forme
/// normalisée (minuscules, ponctuation retirée), donc insensibles au point
/// final et à la casse.
const List<List<String>> _kByKeyword = <List<String>>[
  ['email must be a non empty string', 'fixes576_err_email_required'],
  ['email is required', 'fixes576_err_email_required'],
  ['already associated with another account', 'fixes576_err_email_taken'],
  ['email is already', 'fixes576_err_email_taken'],
  ['invalid email', 'fixes576_err_email_invalid'],
  ['name must be a non empty string', 'fixes576_err_name_required'],
  ['name is required', 'fixes576_err_name_required'],
  ['city is required', 'fixes576_err_city_required'],
  ['authentication required', 'fixes576_err_auth'],
  ['invalid or expired token', 'fixes576_err_auth'],
  ['do not have permission', 'fixes576_err_forbidden'],
  ['role required', 'fixes576_err_forbidden'],
  ['not found', 'fixes576_err_not_found'],
  ['too many', 'fixes576_err_too_many'],
];

/// Statut HTTP → clé i18n.
String _keyForStatus(int? status) {
  if (status == null) return 'fixes576_err_generic';
  if (status == 400 || status == 422) return 'fixes576_err_invalid';
  if (status == 401) return 'fixes576_err_auth';
  if (status == 403) return 'fixes576_err_forbidden';
  if (status == 404) return 'fixes576_err_not_found';
  if (status == 409) return 'fixes576_err_conflict';
  if (status == 429) return 'fixes576_err_too_many';
  if (status >= 500) return 'fixes576_err_server';
  return 'fixes576_err_generic';
}

String _normalize(String value) {
  var out = value.trim().toLowerCase();
  out = out.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
  out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
  return out;
}

/// Clé i18n à afficher pour une erreur serveur.
///
/// [code] : champ `code` de la réponse JSON, s'il existe.
/// [statusCode] : statut HTTP.
/// [rawMessage] : message brut du serveur (anglais) — sert seulement à
/// choisir une clé PRÉCISE, il n'est jamais affiché.
/// [fallbackKey] : clé à utiliser quand rien n'est reconnu (par défaut, le
/// message générique).
String serverErrorKey({
  String? code,
  int? statusCode,
  String? rawMessage,
  String fallbackKey = 'fixes576_err_generic',
}) {
  final c = (code ?? '').trim().toUpperCase();
  if (c.isNotEmpty && _kByCode.containsKey(c)) return _kByCode[c]!;

  final normalized = _normalize(rawMessage ?? '');
  if (normalized.isNotEmpty) {
    for (final rule in _kByKeyword) {
      if (normalized.contains(rule[0])) return rule[1];
    }
  }

  if (statusCode != null) {
    final byStatus = _keyForStatus(statusCode);
    if (byStatus != 'fixes576_err_generic') return byStatus;
  }
  return fallbackKey;
}

/// `code` porté par le corps JSON d'une [ApiException] (`details`).
String? serverErrorCodeOf(Object error) {
  if (error is! ApiException) return null;
  final details = error.details;
  if (details is Map) {
    final c = details['code'];
    if (c is String && c.trim().isNotEmpty) return c;
  }
  return null;
}

/// Clé i18n pour n'importe quelle exception remontée par la couche réseau.
/// Couvre aussi l'absence de réseau et les délais dépassés, que Daniel voyait
/// jusqu'ici sous la forme d'une trace Dart brute.
String errorKeyFor(Object error, {String fallbackKey = 'fixes576_err_generic'}) {
  if (error is NetworkUnreachableException) return 'fixes576_err_network';
  if (error is ApiTimeoutException) return 'fixes576_err_timeout';
  if (error is ApiException) {
    return serverErrorKey(
      code: serverErrorCodeOf(error),
      statusCode: error.statusCode,
      rawMessage: error.message,
      fallbackKey: fallbackKey,
    );
  }
  return fallbackKey;
}
