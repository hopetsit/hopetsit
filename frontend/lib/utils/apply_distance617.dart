// 617 (BOB, 16/10/2026) — DISTANCE MAXIMALE D'UNE CANDIDATURE.
//
// Même constante que le serveur (`backend/src/utils/applicationDistance1610.js`,
// `DEFAULT_MAX_KM = 200`, décision de Daniel du 16/10). Au-delà, le serveur
// refuse la candidature (403 TOO_FAR) : l'app ne PROPOSE donc plus ces
// demandes au prestataire (accueil « Les plus proches de toi », filtre de
// rayon) — un gardien de Busan ne doit plus voir une garde à New York.
const double kApplyMaxKm617 = 200.0;

/// Garde seulement les demandes à moins de [kApplyMaxKm617] (borne incluse).
/// Fonction pure (testée dans test/bob617_test.dart).
List<T> withinApplyRange617<T>(Iterable<T> items, double? Function(T) kmOf) {
  final out = <T>[];
  for (final it in items) {
    final km = kmOf(it);
    if (km == null) continue;
    if (km <= kApplyMaxKm617) out.add(it);
  }
  return out;
}
