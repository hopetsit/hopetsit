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
  final RxBool hideFromMap = false.obs;

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
      hideFromMap.value = m['hideFromMap'] == true;
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

  /// Mode « amis seulement » : écrit sur le compte SANS délai ; renvoie vrai
  /// si le serveur a accepté.
  Future<bool> setHideFromMap(bool value) async {
    if (!_loggedIn || _api == null) return false;
    try {
      await _api!.patch('/users/me/map-prefs',
          body: {'hideFromMap': value}, requiresAuth: true);
      hideFromMap.value = value;
      return true;
    } catch (e) {
      debugPrint('[MapPrefs] hideFromMap : $e');
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
