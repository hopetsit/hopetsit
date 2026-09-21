// v575 — audit P0-1 / P1-6 : durées de promenade, mêmes bornes que le
// serveur (`backend/src/utils/walkDuration.js` et le schéma `walkRates` du
// promeneur) : un entier, multiple de 15, entre 15 et 300 minutes.
//
// Fonctions PURES, sans dépendance Flutter : testables directement.

/// Pas, minimum et maximum d'une durée de promenade, en minutes.
const int kWalkDurationStep = 15;
const int kWalkDurationMin = 15;
const int kWalkDurationMax = 300;

/// `true` si [minutes] est une durée de promenade acceptée par le serveur.
bool isValidWalkDuration(num? minutes) {
  if (minutes == null) return false;
  final v = minutes.toDouble();
  if (v != v.roundToDouble()) return false;
  final i = v.toInt();
  return i % kWalkDurationStep == 0 &&
      i >= kWalkDurationMin &&
      i <= kWalkDurationMax;
}

/// v575 — audit P1-6 : durée de promenade à envoyer pour une annonce.
///
/// AVANT, la vraie durée était écrasée (`<= 45 ? 30 : 60`) : une annonce de
/// 90 min partait à 60. Ordre de résolution :
///   1. [chosen] — la durée que le propriétaire a CHOISIE (`walkDurationMinutes`
///      de l'annonce, v575) ;
///   2. [end] − [start] arrondi au multiple de 15 le plus proche (15–300) ;
///   3. [fallback] (30 min par défaut) quand l'annonce n'a ni l'un ni l'autre.
int walkDurationForPost({
  int? chosen,
  DateTime? start,
  DateTime? end,
  int fallback = 30,
}) {
  final fromChoice = roundToWalkDuration(chosen);
  if (fromChoice != null) return fromChoice;
  if (start != null && end != null) {
    final fromRange = roundToWalkDuration(
      end.difference(start).inMinutes.abs(),
    );
    if (fromRange != null) return fromRange;
  }
  return fallback;
}

/// Arrondit une durée libre (fin − début d'une annonce, par exemple) au
/// multiple de 15 le plus proche, borné à 15–300 minutes.
///
/// Renvoie `null` si la valeur n'est pas exploitable (nulle, négative, NaN) —
/// l'appelant décide alors de son repli.
int? roundToWalkDuration(num? minutes) {
  if (minutes == null) return null;
  final v = minutes.toDouble();
  if (v.isNaN || v.isInfinite || v <= 0) return null;
  var rounded = (v / kWalkDurationStep).round() * kWalkDurationStep;
  if (rounded < kWalkDurationMin) rounded = kWalkDurationMin;
  if (rounded > kWalkDurationMax) rounded = kWalkDurationMax;
  return rounded;
}
