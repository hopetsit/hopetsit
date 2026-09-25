/// Lot D (25/09/2026) — RAYON RETENU par rôle (Daniel : « la valeur du rayon
/// est retenue et cohérente entre la PawMap et les listes »).
///
/// Avant : les 3 accueils repartaient à 50 km à chaque ouverture, et rien
/// n'était mémorisé. Ici, une seule source :
///   · appareil : GetStorage `home_radius_km_v585` = `{owner: 30, sitter: 70…}` ;
///   · compte   : `preferences.pawMap.homeRadiusKm.{rôle}` via
///     `MapPrefsService` (poussé en 2 s, validé côté serveur 10–500 km).
/// Lecture : l'appareil d'abord (immédiat), sinon le compte (autre appareil).
library;

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/services/map_prefs_service.dart';
import 'package:hopetsit/utils/search_radius.dart';

class HomeRadiusPrefs {
  HomeRadiusPrefs._();

  static const String storageKey = 'home_radius_km_v585';

  /// Clé dans `pawMap` du compte (voir `normalizeMapPrefs` côté serveur).
  static const String accountKey = 'homeRadiusKm';

  static String _role(String role) {
    final r = role.trim().toLowerCase();
    return (r == 'owner' || r == 'sitter' || r == 'walker') ? r : 'owner';
  }

  static double? _num(dynamic v) => v is num && !v.isNaN ? v.toDouble() : null;

  /// Le rayon mémorisé pour ce rôle (km), ou null si jamais choisi.
  static double? read(String role) {
    final r = _role(role);
    try {
      final local = GetStorage().read(storageKey);
      if (local is Map) {
        final v = _num(local[r]);
        if (v != null) return v;
      }
    } catch (_) {/* stockage indisponible */}
    try {
      if (Get.isRegistered<MapPrefsService>()) {
        final acc = Get.find<MapPrefsService>().prefs[accountKey];
        if (acc is Map) {
          final v = _num(acc[r]);
          if (v != null) return v;
        }
      }
    } catch (_) {/* service absent */}
    return null;
  }

  /// Le rayon à utiliser au démarrage d'un accueil : mémorisé, sinon
  /// `fallback` ; toujours borné et entier.
  static double resolve(String role, {required double min, required double max, required double fallback}) {
    return clampRadiusKm(read(role), min: min, max: max, fallback: fallback);
  }

  /// Mémorise le rayon choisi (appareil tout de suite, compte dans 2 s).
  static void write(String role, double km) {
    final r = _role(role);
    final v = km.round();
    try {
      final storage = GetStorage();
      final local = storage.read(storageKey);
      final map = local is Map ? Map<String, dynamic>.from(local) : <String, dynamic>{};
      map[r] = v;
      storage.write(storageKey, map);
    } catch (_) {/* stockage indisponible */}
    try {
      MapPrefsService.instance.update(<String, dynamic>{
        accountKey: <String, dynamic>{r: v},
      });
    } catch (_) {/* hors session */}
  }
}
