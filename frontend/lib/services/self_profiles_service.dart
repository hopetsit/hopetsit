// v586 (point 8 de Daniel, 25/09/2026) — « est-ce MA fiche ? ».
//
// Une personne = jusqu'à 3 profils (propriétaire / gardien / promeneur), donc
// 3 ids. La fiche d'un prestataire montre TOUJOURS « Réserver » sauf sur sa
// propre fiche — quel que soit le profil actif. On compare l'id de la fiche à :
//   · l'id du profil actif (profil enregistré localement) ;
//   · les ids de ses autres profils (`GET /users/me/roles` → `profiles`),
//     gardés en mémoire et sur le téléphone.
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/repositories/user_repository.dart';
import 'package:hopetsit/utils/storage_keys.dart';

class SelfProfiles {
  SelfProfiles._();

  static const String _kIds = 'self_profile_ids_v586';

  /// Ids connus des profils de la personne connectée (hors profil actif).
  static final RxSet<String> ids = <String>{}.obs;
  static bool _restored = false;
  static bool _loading = false;

  /// Remplace les ids connus (tests, et après une lecture serveur).
  static void setIds(Iterable<String> values) {
    ids
      ..clear()
      ..addAll(values.where((s) => s.isNotEmpty));
  }

  static String _activeId() {
    try {
      final p = GetStorage().read<Map<String, dynamic>>(StorageKeys.userProfile);
      return (p?['id'] ?? p?['_id'] ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  static void _restore() {
    if (_restored) return;
    _restored = true;
    try {
      final raw = GetStorage().read(_kIds);
      if (raw is List && ids.isEmpty) {
        ids.addAll(raw.whereType<String>().where((s) => s.isNotEmpty));
      }
    } catch (_) {/* stockage indisponible */}
  }

  /// Vrai si [id] est l'un des profils de la personne connectée.
  static bool isMe(String id) {
    final String v = id.trim();
    _restore();
    // Lu EN PREMIER : un `Obx` qui appelle isMe s'abonne toujours à la liste
    // (sinon GetX lève « improper use of Obx » quand on sort plus tôt).
    final bool known = ids.contains(v);
    if (v.isEmpty) return false;
    final String active = _activeId();
    if (active.isNotEmpty && active == v) return true;
    // Les ids connus ne valent que s'ils appartiennent à la personne
    // ACTUELLEMENT connectée (son profil actif en fait partie) : jamais ceux
    // d'un compte précédent sur le même téléphone.
    return known && active.isNotEmpty && ids.contains(active);
  }

  /// Recharge les ids depuis le serveur (silencieux, une requête à la fois).
  static DateTime? _lastAt;

  static Future<void> refresh() async {
    if (_loading || !Get.isRegistered<UserRepository>()) return;
    final now = DateTime.now();
    if (_lastAt != null && now.difference(_lastAt!) < const Duration(minutes: 5)) return;
    _lastAt = now;
    _loading = true;
    try {
      final list = await Get.find<UserRepository>().getMyProfileIds();
      if (list.isNotEmpty) {
        setIds(list);
        try {
          GetStorage().write(_kIds, list);
        } catch (_) {/* mémoire seulement */}
      }
    } catch (_) {
      // réseau / invité : on garde ce qu'on sait.
    } finally {
      _loading = false;
    }
  }
}
