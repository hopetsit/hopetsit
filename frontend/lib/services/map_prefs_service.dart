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
    _loadStamps(); // 610
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


  // ─── 610 (PAM, 04/10) — SYNCHRO CHAMP PAR CHAMP ──────────────────────────
  // Mesuré au simulateur : le mode nuit choisi sur un appareil était effacé
  // dès qu'un autre appareil bougeait sa carte. La copie locale entière était
  // jugée « plus récente » (la caméra venait de bouger) et RENVOYÉE en bloc.
  // Désormais chaque champ (et chaque calque) porte sa propre heure de
  // modification ; on n'envoie que ce que l'utilisateur vient de changer, et
  // à la lecture du compte chaque champ garde la valeur la plus récente.

  static const String stampsKey = 'pawmap_prefs_at_v610';

  /// Champs dont les sous-clés vivent chacune leur vie (un calque, un rôle).
  static const Set<String> subKeyed = {'layers', 'homeRadiusKm'};

  /// Heures de modification LOCALES, par champ (`nightMode`,
  /// `layers__everyone`…), même format que le serveur (`pawMap.fieldAt`).
  final Map<String, String> localAt = <String, String>{};

  Map<String, String> _pendingAt = <String, String>{};

  static String stampKey(String k, [String? sub]) => sub == null ? k : '${k}__$sub';

  static bool _same(Object? a, Object? b) {
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final e in a.entries) {
        if (!b.containsKey(e.key) || !_same(e.value, b[e.key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_same(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }

  /// Ne garde du [patch] que ce qui CHANGE vraiment par rapport à [current]
  /// (un instantané complet des calques ne renvoie que le calque touché).
  static Map<String, dynamic> diffPatch(
      Map<String, dynamic> current, Map<String, dynamic> patch) {
    final out = <String, dynamic>{};
    for (final e in patch.entries) {
      if (e.key == 'updatedAt' || e.key == 'fieldAt') continue;
      final cur = current[e.key];
      if (subKeyed.contains(e.key) && e.value is Map) {
        final sub = <String, dynamic>{};
        for (final s in (e.value as Map).entries) {
          final c = cur is Map ? cur[s.key] : null;
          if (!_same(c, s.value)) sub[s.key.toString()] = s.value;
        }
        if (sub.isNotEmpty) out[e.key] = sub;
      } else if (!_same(cur, e.value)) {
        out[e.key] = e.value;
      }
    }
    return out;
  }

  /// Clés d'horodatage d'un patch (« layers__everyone »…).
  static List<String> stampsOf(Map<String, dynamic> patch) => [
        for (final e in patch.entries)
          if (subKeyed.contains(e.key) && e.value is Map)
            for (final s in (e.value as Map).keys) stampKey(e.key, s.toString())
          else
            e.key,
      ];

  /// Fusion compte → appareil, champ par champ. Renvoie la nouvelle copie,
  /// les nouvelles heures, ce qu'il faut renvoyer au compte (champs changés
  /// ICI plus récemment) et si un champ a pris la valeur du compte.
  static ({
    Map<String, dynamic> prefs,
    Map<String, String> at,
    Map<String, dynamic> push,
    Map<String, String> pushAt,
    bool changed,
  }) mergeRemote({
    required Map<String, dynamic> local,
    required Map<String, String> localAt,
    required Map<String, dynamic> remote,
  }) {
    final remoteAt = <String, String>{
      if (remote['fieldAt'] is Map)
        for (final e in (remote['fieldAt'] as Map).entries)
          if (e.value is String) e.key.toString(): e.value as String,
    };
    final remoteAll = remote['updatedAt'] is String ? remote['updatedAt'] as String : null;
    DateTime? t(String? s) => s == null ? null : DateTime.tryParse(s);
    final out = Map<String, dynamic>.from(local);
    final at = Map<String, String>.from(localAt);
    final push = <String, dynamic>{};
    final pushAt = <String, String>{};
    var changed = false;

    // Décide pour UN champ ; [put] / [read] lisent ou écrivent la valeur.
    void field(String f, bool remoteHas, Object? rv, Object? lv,
        void Function(Object?) put, void Function() keepLocalPush) {
      final la = t(localAt[f]);
      final raS = remoteAt[f] ?? (remoteHas ? remoteAll : null);
      final ra = t(raS);
      if (remoteHas && (la == null || (ra != null && !ra.isBefore(la)))) {
        if (!_same(lv, rv)) changed = true;
        put(rv);
        if (raS != null) at[f] = raS;
        return;
      }
      // Changé ici plus récemment (ou inconnu du compte) : on le renvoie.
      if (la != null && lv != null) {
        keepLocalPush();
        pushAt[f] = localAt[f]!;
      }
    }

    final keys = <String>{...local.keys, ...remote.keys}
      ..removeAll(const {'updatedAt', 'fieldAt'});
    for (final k in keys) {
      if (subKeyed.contains(k)) {
        final lm = local[k] is Map ? Map<String, dynamic>.from(local[k] as Map) : <String, dynamic>{};
        final rm = remote[k] is Map ? Map<String, dynamic>.from(remote[k] as Map) : <String, dynamic>{};
        final merged = Map<String, dynamic>.from(lm);
        for (final sub in <String>{...lm.keys, ...rm.keys}) {
          field(stampKey(k, sub), rm.containsKey(sub), rm[sub], lm[sub],
              (v) => merged[sub] = v, () {
            push[k] = {...(push[k] as Map? ?? const {}), sub: lm[sub]};
          });
        }
        if (merged.isNotEmpty) out[k] = merged;
      } else {
        field(k, remote.containsKey(k), remote[k], local[k], (v) => out[k] = v,
            () => push[k] = local[k]);
      }
    }
    if (remoteAll != null) out['updatedAt'] = remoteAll;
    return (prefs: out, at: at, push: push, pushAt: pushAt, changed: changed);
  }

  void _loadStamps() {
    try {
      final raw = GetStorage().read(stampsKey);
      if (raw is Map) {
        localAt
          ..clear()
          ..addAll({
            for (final e in raw.entries)
              if (e.value is String) e.key.toString(): e.value as String,
          });
      }
    } catch (_) {/* stockage indisponible */}
  }

  void _persistStamps() {
    try {
      GetStorage().write(stampsKey, Map<String, String>.from(localAt));
    } catch (_) {/* best effort */}
  }

  /// Lecture du compte au démarrage de la carte. Renvoie vrai si au moins un
  /// champ a pris la valeur du compte (l'écran réapplique alors les réglages).
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
      _loadStamps();
      final r = mergeRemote(
        local: Map<String, dynamic>.from(prefs),
        localAt: localAt,
        remote: remote,
      );
      prefs.assignAll(r.prefs);
      localAt
        ..clear()
        ..addAll(r.at);
      _persistLocal();
      _persistStamps();
      // Seuls les champs changés ICI plus récemment repartent, jamais le bloc.
      if (r.push.isNotEmpty) unawaited(_push(r.push, r.pushAt));
      return r.changed;
    } catch (e) {
      debugPrint('[MapPrefs] lecture du compte : $e');
      return false;
    } finally {
      loaded.value = true;
    }
  }

  /// Met à jour localement (tout de suite) et sur le compte (dans 2 s) —
  /// seulement ce qui change vraiment, avec l'heure de chaque champ.
  void update(Map<String, dynamic> patch) {
    if (patch.isEmpty) return;
    final changed = diffPatch(Map<String, dynamic>.from(prefs), patch);
    if (changed.isEmpty) return;
    final now = DateTime.now().toUtc().toIso8601String();
    final merged = Map<String, dynamic>.from(prefs);
    for (final e in changed.entries) {
      final cur = merged[e.key];
      if (e.value is Map && cur is Map) {
        merged[e.key] = {...Map<String, dynamic>.from(cur), ...Map<String, dynamic>.from(e.value as Map)};
      } else {
        merged[e.key] = e.value;
      }
    }
    merged['updatedAt'] = now;
    prefs.assignAll(merged);
    _persistLocal();
    for (final f in stampsOf(changed)) {
      localAt[f] = now;
      _pendingAt[f] = now;
    }
    _persistStamps();
    final pending = Map<String, dynamic>.from(_pending);
    for (final e in changed.entries) {
      final cur = pending[e.key];
      pending[e.key] = (e.value is Map && cur is Map)
          ? {...Map<String, dynamic>.from(cur), ...Map<String, dynamic>.from(e.value as Map)}
          : e.value;
    }
    _pending = pending;
    _pushTimer?.cancel();
    _pushTimer = Timer(pushDelay, () {
      final body = _pending;
      final at = _pendingAt;
      _pending = {};
      _pendingAt = {};
      unawaited(_push(body, at));
    });
  }

  /// Pousse immédiatement (fermeture de l'écran, passage en arrière-plan).
  Future<void> flush() async {
    _pushTimer?.cancel();
    if (_pending.isEmpty) return;
    final body = _pending;
    final at = _pendingAt;
    _pending = {};
    _pendingAt = {};
    await _push(body, at);
  }

  Future<void> _push(Map<String, dynamic> pawMap, [Map<String, String> at = const {}]) async {
    if (!_loggedIn || _api == null || pawMap.isEmpty) return;
    try {
      await _api!.patch('/users/me/map-prefs',
          body: {'pawMap': pawMap, if (at.isNotEmpty) 'pawMapAt': at},
          requiresAuth: true);
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

  /// v601 — barre de DROITE : boutons personnalisables affichés, dans
  /// l'ordre (null = jamais réglé → ordre d'origine ; [] = tout masqué).
  List<String>? get capsule {
    final r = prefs['capsule'];
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
