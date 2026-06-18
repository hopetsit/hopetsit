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
  // v465 — Daniel : « 0m ans » s'affichait encore. RACINE : un âge INCONNU
  // (0) ne doit RIEN afficher du tout, et certaines valeurs arrivaient
  // malformées (« 0m ans », « 0 mois »). On parse le nombre + l'unité de
  // façon tolérante et on retourne '' dès que le nombre vaut 0.
  // Mois : « 5m », « 5 m », « 5m ans » (malformé), « 5 mois ».
  final months =
      RegExp(r'^(\d+)\s*(?:m\b|mois)', caseSensitive: false).firstMatch(a);
  if (months != null) {
    final n = int.tryParse(months.group(1)!) ?? 0;
    if (n <= 0) return ''; // âge inconnu → on n'affiche rien (fini « 0m ans »)
    return '$n ${'pet_age_months'.tr}';
  }
  // Années : « 2y », « 2 ans », « 2 », « 2 años/years/jahre/anni/anos ».
  final years = RegExp(
    r'^(\d+)\s*(?:y\b|ans|años|years|jahre|anni|anos)?',
    caseSensitive: false,
  ).firstMatch(a);
  if (years != null && years.group(1) != null) {
    final n = int.tryParse(years.group(1)!) ?? 0;
    if (n <= 0) return '';
    return '$n ${'pet_age_unit'.tr}';
  }
  return a; // forme inattendue → affichée telle quelle (jamais d'unité en trop)
}
