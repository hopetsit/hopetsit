// v584 — lot C du chantier du 24/09 : PRÉFÉRENCES DE LA PAWMAP SUR LE COMPTE.
//
// Daniel : « tout lié entre appareils » (position, zoom, calques, rail
// enregistrés sur le COMPTE). Le serveur expose `GET/PATCH /users/me/map-prefs`
// (controllers/mapPrefsController.js, synchronisé sur les 3 profils et lu
// par le site). Ici :
//   · une copie locale (GetStorage) pour démarrer sans réseau ;
//   · au démarrage de la carte : lecture du compte ; le compte gagne s'il est
//     plus récent que la copie locale (l'autre téléphone a bougé la carte) ;
//   · chaque changement (caméra à l'arrêt, calque, rail, mode nuit…) est
//     poussé avec un court délai (2 s) pour ne pas mitrailler le serveur ;
//   · le mode « visible par mes amis seulement » (`hideFromMap`) passe par la
//     même route, sans délai (c'est un réglage de vie privée).
// Sans jeton (invité) : tout reste local.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/secure_token_store.dart';

class MapPrefsService extends GetxService {
  static const String storageKey = 'pawmap_prefs_v584';
  static const Duration pushDelay = Duration(seconds: 2);

  /// Préférences courantes (copie locale, fusionnée avec le compte).
  final RxMap<String, dynamic> prefs = <String, dynamic>{}.obs;

  /// `preferences.hideFromMap` du compte (mode amis seulement).
  /// v586 — dérivé de [mapVisibility] (vrai si ≠ 'all'), gardé pour
  /// l'existant.
  final RxBool hideFromMap = false.obs;

  /// v586 — LA vérité « qui me voit sur la carte » : 'all' | 'friends' |
  /// 'hidden' (`preferences.mapVisibility`, les 3 profils). Lue et écrite au
  /// même endroit par la carte (bouton œil), Profil › Préférences et le site.
  final RxString mapVisibility = 'all'.obs;

  static const List<String> visibilityStates = ['all', 'friends', 'hidden'];

  /// État suivant au bouton œil : Tous → Amis → Masqué → Tous.
  static String nextVisibility(String v) {
    final i = visibilityStates.indexOf(v);
    return visibilityStates[(i < 0 ? 0 : i + 1) % visibilityStates.length];
  }

  /// Lecture tolérante (nouveau champ, sinon l'ancien `hideFromMap` =
  /// « amis seulement », comme le serveur).
  static String visibilityFrom(Map? m) {
    final v = m?['mapVisibility'];
    if (v is String && visibilityStates.contains(v)) return v;
    return m?['hideFromMap'] == true ? 'friends' : 'all';
  }

  void _setVisibilityLocal(String v) {
    mapVisibility.value = v;
    hideFromMap.value = v != 'all';
  }

  /// Vrai une fois le compte lu (ou l'échec constaté) au démarrage.
  final RxBool loaded = false.obs;

  Timer? _pushTimer;
  Map<String, dynamic> _pending = {};

  static MapPrefsService get instance => Get.isRegistered<MapPrefsService>()
      ? Get.find<MapPrefsService>()
      : Get.put(MapPrefsService(), permanent: true);

  @override
  void onInit() {
    super.onInit();
    try {
      final raw = GetStorage().read(storageKey);
      if (raw is Map) prefs.assignAll(Map<String, dynamic>.from(raw));
    } catch (_) {/* stockage indisponible */}
    // v586 — état de départ = copie locale du profil (avant le réseau).
    try {
      final profile = GetStorage().read<Map<String, dynamic>>('user_profile');
      final p = profile?['preferences'];
      if (p is Map) _setVisibilityLocal(visibilityFrom(p));
    } catch (_) {/* profil illisible */}
  }

  bool get _loggedIn => (SecureTokenStore.currentToken() ?? '').isNotEmpty;

  ApiClient? get _api =>
      Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : null;

  DateTime? _updatedAt(Map<String, dynamic>? m) {
    final s = m?['updatedAt'];
    if (s is String) return DateTime.tryParse(s);
    return null;
  }

  /// Lecture du compte au démarrage de la carte. Renvoie vrai si le compte a
  /// remplacé la copie locale (plus récent) — l'écran recentre alors la carte.
  Future<bool> loadFromAccount() async {
    if (!_loggedIn || _api == null) {
      loaded.value = true;
      return false;
    }
    try {
      final res = await _api!.get('/users/me/map-prefs', requiresAuth: true);
      final m = res is Map ? Map<String, dynamic>.from(res) : null;
      if (m == null) return false;
      _setVisibilityLocal(visibilityFrom(m));
      final remote = m['pawMap'] is Map
          ? Map<String, dynamic>.from(m['pawMap'] as Map)
          : <String, dynamic>{};
      final remoteAt = _updatedAt(remote);
      final localAt = _updatedAt(prefs);
      final remoteNewer = remoteAt != null &&
          (localAt == null || remoteAt.isAfter(localAt));
      if (remote.isNotEmpty && remoteNewer) {
        prefs.assignAll(remote);
        _persistLocal();
        return true;
      }
      // Copie locale plus récente : on la pousse au compte.
      if (prefs.isNotEmpty && (remoteAt == null || !remoteNewer) && localAt != null) {
        unawaited(_push(Map<String, dynamic>.from(prefs)));
      }
      return false;
    } catch (e) {
      debugPrint('[MapPrefs] lecture du compte : $e');
      return false;
    } finally {
      loaded.value = true;
    }
  }

  /// Met à jour localement (tout de suite) et sur le compte (dans 2 s).
  void update(Map<String, dynamic> patch) {
    if (patch.isEmpty) return;
    final merged = Map<String, dynamic>.from(prefs);
    for (final e in patch.entries) {
      final cur = merged[e.key];
      if (e.value is Map && cur is Map) {
        merged[e.key] = {...Map<String, dynamic>.from(cur), ...Map<String, dynamic>.from(e.value as Map)};
      } else {
        merged[e.key] = e.value;
      }
    }
    merged['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    prefs.assignAll(merged);
    _persistLocal();
    _pending = {..._pending, ...patch};
    _pushTimer?.cancel();
    _pushTimer = Timer(pushDelay, () {
      final body = _pending;
      _pending = {};
      unawaited(_push(body));
    });
  }

  /// Pousse immédiatement (fermeture de l'écran, passage en arrière-plan).
  Future<void> flush() async {
    _pushTimer?.cancel();
    if (_pending.isEmpty) return;
    final body = _pending;
    _pending = {};
    await _push(body);
  }

  Future<void> _push(Map<String, dynamic> pawMap) async {
    if (!_loggedIn || _api == null || pawMap.isEmpty) return;
    try {
      await _api!.patch('/users/me/map-prefs',
          body: {'pawMap': pawMap}, requiresAuth: true);
    } catch (e) {
      debugPrint('[MapPrefs] envoi au compte : $e');
    }
  }

  /// Mode « amis seulement » (ancienne API) : passe par [setMapVisibility].
  Future<bool> setHideFromMap(bool value) =>
      setMapVisibility(value ? 'friends' : 'all');

  /// v586 — écrit l'état sur le compte SANS délai (réglage de vie privée) ;
  /// renvoie vrai si le serveur a accepté. `hideFromMap` part avec, pour un
  /// serveur plus ancien (il comprend alors « Masqué » comme « amis
  /// seulement », jamais comme « visible par tous »). Copie locale du profil
  /// mise à jour : Préférences et carte disent la même chose sans recharger.
  Future<bool> setMapVisibility(String value) async {
    if (!visibilityStates.contains(value)) return false;
    if (!_loggedIn || _api == null) return false;
    try {
      final res = await _api!.patch('/users/me/map-prefs',
          body: {'mapVisibility': value, 'hideFromMap': value != 'all'},
          requiresAuth: true);
      final m = res is Map ? res : null;
      final server = m != null && m['mapVisibility'] is String
          ? visibilityFrom(m)
          : value;
      _setVisibilityLocal(server);
      try {
        final box = GetStorage();
        final profile = box.read<Map<String, dynamic>>('user_profile');
        if (profile != null) {
          final p = Map<String, dynamic>.from(
              (profile['preferences'] as Map?) ?? const {});
          p['mapVisibility'] = server;
          p['hideFromMap'] = server != 'all';
          profile['preferences'] = p;
          box.write('user_profile', profile);
        }
      } catch (_) {/* sans importance */}
      return true;
    } catch (e) {
      debugPrint('[MapPrefs] mapVisibility : $e');
      return false;
    }
  }

  void _persistLocal() {
    try {
      GetStorage().write(storageKey, Map<String, dynamic>.from(prefs));
    } catch (_) {/* best effort */}
  }

  // ── lecteurs typés ───────────────────────────────────────────────────────

  Map<String, dynamic>? get camera =>
      prefs['camera'] is Map ? Map<String, dynamic>.from(prefs['camera'] as Map) : null;

  Map<String, bool> get layers {
    final m = prefs['layers'];
    if (m is! Map) return const {};
    return {for (final e in m.entries) if (e.value is bool) e.key.toString(): e.value as bool};
  }

  List<String>? get rail {
    final r = prefs['rail'];
    if (r is! List) return null;
    return r.map((e) => e.toString()).toList();
  }

  List<String>? get memberRoles {
    final r = prefs['memberRoles'];
    if (r is! List) return null;
    return r.map((e) => e.toString()).toList();
  }

  bool? get nightMode => prefs['nightMode'] is bool ? prefs['nightMode'] as bool : null;
  bool? get availableTodayOnly =>
      prefs['availableTodayOnly'] is bool ? prefs['availableTodayOnly'] as bool : null;
  bool? get panelCollapsed =>
      prefs['panelCollapsed'] is bool ? prefs['panelCollapsed'] as bool : null;
  /// v587 (point 3) — rail gauche / capsule droite rangés hors écran.
  bool get railCollapsed => prefs['railCollapsed'] == true;
  bool get capsuleCollapsed => prefs['capsuleCollapsed'] == true;
  String? get lookingFor => prefs['lookingFor'] is String ? prefs['lookingFor'] as String : null;
  String? get routeMode => prefs['routeMode'] is String ? prefs['routeMode'] as String : null;
  double? get aroundRadiusKm => (prefs['aroundRadiusKm'] as num?)?.toDouble();
  int get coachShown => (prefs['coachShown'] as num?)?.toInt() ?? 0;

  @override
  void onClose() {
    _pushTimer?.cancel();
    super.onClose();
  }
}
