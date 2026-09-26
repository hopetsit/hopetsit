// v592 — Daniel (26/09) : « quand je me connecte, il y a un mini lag qui
// clignote, qui tremble sur mon profil le temps que ça s'installe ».
//
// Dernier profil reçu du serveur, gardé sur l'appareil PAR RÔLE et PAR COMPTE,
// pour que l'onglet Profil s'affiche tout de suite dans sa forme finale (carte
// « profil complété à X % », note, statistiques) au lieu de se construire en
// plusieurs temps pendant que le serveur répond. La réponse serveur remplace
// ensuite le cache EN PLACE.
//
// Garde-fous :
//   · un cache n'est rendu que s'il appartient au MÊME compte (id) et au même
//     rôle — jamais le profil d'un autre compte sur un appareil partagé ;
//   · effacé à la déconnexion (`clear`, appelé par AuthController.logout) ;
//   · les listes lourdes (annonces, réservations, avis, tâches) ne sont pas
//     gardées : elles ne servent pas à l'en-tête et gonfleraient le fichier.
import 'package:get_storage/get_storage.dart';

class ProfileDisplayCache {
  ProfileDisplayCache._();

  static const String storageKey = 'profile_display_cache_v592';

  static const List<String> _heavyKeys = <String>[
    'bookings',
    'posts',
    'tasks',
    'reviews',
    'reviewsGiven',
    'reviewsReceived',
  ];

  /// Retire les listes lourdes ; garde tout le reste tel que le serveur l'a
  /// envoyé (le modèle se reconstruit avec `ProfileModel.fromJson`).
  static Map<String, dynamic> _light(Map<String, dynamic> data) {
    final out = Map<String, dynamic>.from(data);
    for (final k in _heavyKeys) {
      out.remove(k);
    }
    return out;
  }

  static void write(
    GetStorage storage, {
    required String role,
    required String userId,
    required Map<String, dynamic> data,
  }) {
    if (role.isEmpty || userId.isEmpty) return;
    try {
      final raw = storage.read(storageKey);
      final all = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      all[role] = <String, dynamic>{'userId': userId, 'data': _light(data)};
      storage.write(storageKey, all);
    } catch (_) {/* cache best-effort : jamais bloquant */}
  }

  static Map<String, dynamic>? read(
    GetStorage storage, {
    required String role,
    required String userId,
  }) {
    if (role.isEmpty || userId.isEmpty) return null;
    try {
      final raw = storage.read(storageKey);
      if (raw is! Map) return null;
      final entry = raw[role];
      if (entry is! Map) return null;
      if ((entry['userId'] ?? '').toString() != userId) return null;
      final data = entry['data'];
      if (data is! Map) return null;
      return Map<String, dynamic>.from(data);
    } catch (_) {
      return null;
    }
  }

  static void clear(GetStorage storage) {
    try {
      storage.remove(storageKey);
    } catch (_) {/* rien à effacer */}
  }
}
