// v605 (30/09) — Daniel : « j'ai laissé la carte sur ton profil et ça m'est
// revenu sur ma position » ; « ce truc que la position change à chaque
// fois ». UNE seule règle pour tous les recentrages AUTOMATIQUES sur « Moi »
// (ceux que l'utilisateur n'a pas demandés) :
//   · 1er fix GPS à l'ouverture (_bootstrap),
//   · retour de l'arrière-plan après ≥ 2 min,
//   · chaque nouvelle position GPS pendant MA balade (« me suivre »).
// Dès que la caméra « appartient » à l'utilisateur (geste, appui sur une
// épingle / un profil, ami montré, lien ou demande d'un autre écran, suivi
// d'une personne, itinéraire, placement), la caméra ne repart JAMAIS seule
// sur Moi. Seuls le bouton « Ma position » et le départ de MA balade la
// rendent au mode « Moi ».

/// Cause d'un recentrage automatique sur ma position.
enum PawAutoRecenter { gpsFirstFix, appResume, myLiveGps }

/// La caméra peut-elle repartir d'elle-même sur « Moi » ?
///
/// [cameraHeld] : l'utilisateur (ou un autre écran pour lui) a placé la
/// caméra ailleurs depuis le dernier « Ma position » / départ de balade.
/// [following] : je suis quelqu'un en direct. [focusOpen] : une fiche /
/// carte focus est ouverte. [routeActive] : itinéraire tracé. [picking] :
/// viseur de placement. [meFollow] : mode « me suivre » (seulement pour
/// [PawAutoRecenter.myLiveGps]).
bool pawMapMayRecenterOnMe(
  PawAutoRecenter cause, {
  required bool cameraHeld,
  bool following = false,
  bool focusOpen = false,
  bool routeActive = false,
  bool picking = false,
  bool meFollow = false,
}) {
  if (following || focusOpen || routeActive || picking) return false;
  if (cameraHeld) return false;
  if (cause == PawAutoRecenter.myLiveGps) return meFollow;
  return true;
}

/// Mémoire de l'APPLI (partagée par les écrans PawMap successifs) : faut-il
/// refaire le recentrage automatique du 1er fix GPS ?
///   · jamais fait → oui, sauf geste de moins de 10 min (écran précédent) ;
///   · un geste depuis le dernier recentrage automatique → NON, même après
///     10 min (v604 : au-delà de 10 min on revolait sur moi malgré le geste) ;
///   · sinon, plus de 10 min ou plus de 300 m → oui.
bool pawMapShouldAutoRecenterAgain({
  required DateTime now,
  DateTime? lastAutoAt,
  double? lastAutoKmFromTarget,
  DateTime? lastGestureAt,
}) {
  final g = lastGestureAt;
  if (lastAutoAt == null || lastAutoKmFromTarget == null) {
    return g == null || now.difference(g) > const Duration(minutes: 10);
  }
  if (g != null && g.isAfter(lastAutoAt)) return false;
  if (now.difference(lastAutoAt) > const Duration(minutes: 10)) return true;
  return lastAutoKmFromTarget > 0.3;
}
