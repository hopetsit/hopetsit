// 1011 « conclure » (contrat du 10/11) — petits outils partagés par le
// formulaire « Publier ma demande », les cartes de demande et les profils.
//
//   * Demande : `timeFrom` / `timeTo` (« HH:MM », 24 h, '' = pas d'horaire) et
//     `ownerNoCar` (bool) — facultatifs, le serveur ignore une valeur invalide.
//   * Profil gardien / promeneur : `hasVehicle` (bool ou null = pas dit).
//   * 639 — demande : `foodProvided` (true / false, ou null = non précisé).
//
// Le serveur est la seule source : ici on ne fait que lire, nettoyer, afficher.
import 'package:get/get.dart';

/// « 9:5 » → « 09:05 » ; valeur absente ou invalide → ''.
String cleanHm1011(Object? v) {
  if (v == null) return '';
  final m = RegExp(r'^\s*(\d{1,2})\s*[:hH]\s*(\d{1,2})\s*$').firstMatch(v.toString());
  if (m == null) return '';
  final h = int.tryParse(m.group(1)!);
  final mi = int.tryParse(m.group(2)!);
  if (h == null || mi == null || h > 23 || mi > 59) return '';
  return '${h.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}';
}

/// Booléen souple (JSON ou champ multipart relu en texte).
bool parseBool1011(Object? v) =>
    v == true || v == 1 || (v is String && (v.toLowerCase() == 'true' || v == '1'));

/// Booléen à trois états : `true`, `false`, ou `null` quand rien n'est dit.
bool? parseTriBool1011(Object? v) {
  if (v == null) return null;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().toLowerCase().trim();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0') return false;
  return null;
}

/// « 09:00 – 18:00 », « À partir de 09:00 », « Jusqu'à 18:00 », ou '' sans
/// horaire. Les deux valeurs sont nettoyées avant l'affichage.
String hoursLabel1011(Object? from, Object? to) {
  final f = cleanHm1011(from);
  final t = cleanHm1011(to);
  if (f.isEmpty && t.isEmpty) return '';
  if (f.isNotEmpty && t.isNotEmpty) return '$f – $t';
  if (f.isNotEmpty) return 'c1011_hours_from'.trParams(<String, String>{'time': f});
  return 'c1011_hours_until'.trParams(<String, String>{'time': t});
}

/// Champs 1011 d'une demande, prêts à partir vers le serveur.
///
///  * Création (`forUpdate: false`) : on n'envoie que ce qui est rempli — un
///    horaire non vide, « sans voiture » seulement s'il est coché.
///  * Modification (`forUpdate: true`) : `null` = inchangé (rien n'est envoyé),
///    `''` = horaire effacé, et le booléen part tel quel (true comme false).
///
///  * 639 — `foodProvided` (« Je fournis la nourriture ») : `null` = pas dit →
///    rien n'est envoyé (création comme modification) ; sinon le booléen part
///    tel quel, `true` comme `false`.
Map<String, Object> requestExtras1011({
  String? timeFrom,
  String? timeTo,
  bool? ownerNoCar,
  bool? foodProvided,
  bool forUpdate = false,
}) {
  final out = <String, Object>{};
  void hour(String key, String? raw) {
    if (raw == null) return;
    final v = cleanHm1011(raw);
    if (v.isNotEmpty || forUpdate) out[key] = v;
  }

  hour('timeFrom', timeFrom);
  hour('timeTo', timeTo);
  if (ownerNoCar != null && (ownerNoCar || forUpdate)) {
    out['ownerNoCar'] = ownerNoCar;
  }
  if (foodProvided != null) out['foodProvided'] = foodProvided;
  return out;
}

/// 639 — ligne « nourriture » d'une demande : « Nourriture fournie » à `true`,
/// « Nourriture à prévoir » à `false`, '' quand rien n'est précisé (`null`,
/// champ absent d'un ancien serveur) → rien à afficher.
String foodLabel639(bool? foodProvided) {
  if (foodProvided == null) return '';
  return (foodProvided ? 'f639_food_yes' : 'f639_food_no').tr;
}
