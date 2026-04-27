import 'package:get/get.dart';

/// Translates a backend serviceType key (e.g. 'day_care', 'dog_walking',
/// 'pet_sitting', 'house_sitting') to the user's locale via GetX `.tr`.
///
/// - Normalizes the key (lowercase, spaces → underscores, dashes → underscores)
///   so values like 'Day Care', 'day-care', 'DAY_CARE' all match the same key.
/// - Falls back to a humanized form ('Day Care') if no translation key matches,
///   so we never show raw `day_care` to end users.
String translateServiceType(String? raw) {
  if (raw == null) return '';
  final cleaned = raw.trim();
  if (cleaned.isEmpty) return '';

  final normalized = cleaned
      .toLowerCase()
      .replaceAll('-', '_')
      .replaceAll(' ', '_');

  final key = 'service_$normalized';
  final translated = key.tr;

  // GetX returns the key itself when no translation is found.
  if (translated != key) return translated;

  // Humanized fallback: 'day_care' → 'Day care'.
  final spaced = normalized.replaceAll('_', ' ');
  if (spaced.isEmpty) return '';
  return spaced[0].toUpperCase() + spaced.substring(1);
}

/// Translates a list of service type keys, joined with `, `.
String translateServiceTypes(List<String> raws) {
  if (raws.isEmpty) return '';
  return raws.map(translateServiceType).where((s) => s.isNotEmpty).join(', ');
}
