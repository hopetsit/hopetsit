import 'package:get/get.dart';

/// v451 — Daniel : l'âge s'affichait « 0m ans » (et ne se mettait pas à jour).
/// L'âge renvoyé par le backend peut être :
///   - un NOMBRE D'ANNÉES brut (« 2 »)  → édité dans la fiche,
///   - une forme dérivée de la date de naissance : « 5m » (mois) / « 2y » (ans).
/// Ce helper formate proprement ET localisé, sans JAMAIS coller « ans » derrière
/// un suffixe d'unité (fin du bug « 0m ans »). Retourne '' si vide.
String petAgeDisplay(String? rawAge) {
  final a = (rawAge ?? '').trim();
  if (a.isEmpty) return '';
  final months = RegExp(r'^(\d+)\s*m$', caseSensitive: false).firstMatch(a);
  if (months != null) return '${months.group(1)} ${'pet_age_months'.tr}';
  final years = RegExp(r'^(\d+)\s*y$', caseSensitive: false).firstMatch(a);
  if (years != null) return '${years.group(1)} ${'pet_age_unit'.tr}';
  if (RegExp(r'^\d+$').hasMatch(a)) return '$a ${'pet_age_unit'.tr}';
  return a; // forme inattendue → affichée telle quelle (jamais d'unité en trop)
}
