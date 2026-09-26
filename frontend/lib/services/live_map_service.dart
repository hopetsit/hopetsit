import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
// v23.1.294 — AndroidSettings.foregroundNotificationConfig pour garder le GPS
// vivant en arrière-plan (foreground service + notif persistante). Les
// permissions FOREGROUND_SERVICE(_LOCATION) + ACCESS_BACKGROUND_LOCATION sont
// déjà dans AndroidManifest.xml.
import 'package:geolocator_android/geolocator_android.dart' as gloc_android;
import 'package:geolocator_apple/geolocator_apple.dart' as gloc_apple;
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_config.dart';
import 'package:hopetsit/data/network/secure_token_store.dart';
import 'package:hopetsit/services/live_tracking_bg.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/services/socket_service.dart';
import 'package:hopetsit/utils/storage_keys.dart';

/// Single friend's live position — used to drive the PawMap "friends layer".
class FriendPosition {
  final String userId;
  final String role;
  final double latitude;
  final double longitude;
  final DateTime at;
  final String city;
  // v565 — contrat §8 : le serveur garde la DERNIÈRE position 24 h et
  // renvoie `lastSeenAt` + `stale` (true si > 3 min). On les garde pour
  // afficher « actif / signal perdu · vu il y a X » chez les amis.
  final DateTime? lastSeenAt;
  final bool stale;

  /// v584 (25/09) — un PARTAGE est actif chez cet ami (session en cours).
  /// Sans partage, sa position n'est qu'un « vu il y a X » : jamais « en
  /// direct », jamais de suivi proposé.
  final bool sharing;

  /// v589 — tous les ids de profil de cette personne (envoyés par le
  /// serveur) : une personne = UN rond, même quand sa position arrive sous
  /// l'id d'un autre de ses profils.
  final List<String> personIds;

  const FriendPosition({
    required this.userId,
    required this.role,
    required this.latitude,
    required this.longitude,
    required this.at,
    this.city = '',
    this.lastSeenAt,
    this.stale = false,
    this.sharing = false,
    this.personIds = const <String>[],
  });

  factory FriendPosition.fromJson(Map<String, dynamic> j, {DateTime? now}) {
    final at = DateTime.tryParse(j['at']?.toString() ?? '') ?? DateTime.now();
    // v587 (25/09) — Daniel : « le direct ne marche pas, je vois suspendu ».
    // L'âge du dernier signe de vie était calculé avec l'HEURE DU TÉLÉPHONE
    // contre un horodatage du SERVEUR : un téléphone en avance de 2 min
    // voyait un direct bien vivant « signal perdu ». Le serveur v587 envoie
    // `ageMs` (âge mesuré chez lui) : on le rapporte à l'heure locale.
    final ageMs = (j['ageMs'] as num?)?.toInt();
    final DateTime? seen = ageMs != null
        ? (now ?? DateTime.now()).subtract(Duration(milliseconds: ageMs))
        : DateTime.tryParse(j['lastSeenAt']?.toString() ?? '');
    return FriendPosition(
      userId: j['userId']?.toString() ?? '',
      role: (j['role'] as String?) ?? '',
      latitude: ((j['lat'] as num?) ?? 0).toDouble(),
      longitude: ((j['lng'] as num?) ?? 0).toDouble(),
      at: at,
      city: (j['city'] as String?) ?? '',
      lastSeenAt: seen ?? at,
      stale: j['stale'] == true,
      // Serveur v584 : `sharing` explicite. Un serveur plus ancien (v583) ne
      // le renvoie pas : on retombe sur son `stale` (false = signal < 3 min,
      // donc un partage réellement actif) — jamais sur une position de profil.
      sharing: j.containsKey('sharing') ? j['sharing'] == true : j['stale'] == false,
      personIds: <String>[
        if (j['personIds'] is List)
          for (final e in (j['personIds'] as List))
            if ((e ?? '').toString().isNotEmpty) e.toString(),
      ],
    );
  }

  /// v565 — dernier signe de vie connu (position ou battement).
  DateTime get seenAt => lastSeenAt ?? at;

  /// v565 — « signal perdu » : le serveur le dit (`stale`) OU aucun signe de
  /// vie depuis plus de 3 min (même seuil que le serveur, calculé en local
  /// pour rester juste entre deux rafraîchissements).
  bool get isStale =>
      stale || DateTime.now().difference(seenAt) > const Duration(minutes: 3);

  /// v584 (25/09) — état VRAI du direct, même règle que le serveur
  /// (`utils/liveState.js`), recalculée en local entre deux rafraîchissements.
  FriendLiveState get liveState => friendLiveState(
        sharing: sharing,
        seenAt: seenAt,
        now: DateTime.now(),
      );

  /// « En direct » : partage actif ET signe de vie < 2 min.
  bool get isLive => liveState == FriendLiveState.live;

  /// « Signal perdu » : partage actif, muet depuis 2 à 10 min.
  bool get isLost => liveState == FriendLiveState.lost;

  FriendPosition copyWith({
    double? latitude,
    double? longitude,
    DateTime? at,
    String? city,
    DateTime? lastSeenAt,
    bool? stale,
    bool? sharing,
    String? userId,
    List<String>? personIds,
  }) =>
      FriendPosition(
        userId: userId ?? this.userId,
        role: role,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        at: at ?? this.at,
        city: city ?? this.city,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
        stale: stale ?? this.stale,
        sharing: sharing ?? this.sharing,
        personIds: personIds ?? this.personIds,
      );

  /// Tous les ids connus de la personne (l'id de la position compris).
  Set<String> get allIds => <String>{
        if (userId.isNotEmpty) userId.trim().toLowerCase(),
        for (final x in personIds)
          if (x.isNotEmpty) x.trim().toLowerCase(),
      };
}

/// v589 — Daniel : « je vois la même personne à deux endroits différents ».
/// Clé sous laquelle ranger [fp] : celle d'une position DÉJÀ connue de la
/// même personne (ids en commun), sinon son propre id. Pure, testée.
String friendPositionKey(Map<String, FriendPosition> current, FriendPosition fp) {
  final ids = fp.allIds;
  if (current.containsKey(fp.userId)) return fp.userId;
  for (final e in current.entries) {
    if (e.value.allIds.any(ids.contains) ||
        ids.contains(e.key.trim().toLowerCase())) {
      return e.key;
    }
  }
  return fp.userId;
}

/// Fusion des ids connus de la personne (ancienne + nouvelle position).
List<String> mergedPersonIds(FriendPosition? a, FriendPosition b) => <String>{
      ...?a?.personIds,
      ...b.personIds,
      if (a != null && a.userId.isNotEmpty) a.userId,
      if (b.userId.isNotEmpty) b.userId,
    }.toList();

/// v584 (25/09) — les trois états d'un ami sur la carte.
enum FriendLiveState { live, lost, seen }

const Duration kFriendLiveFresh = Duration(minutes: 2);
const Duration kFriendLiveLost = Duration(minutes: 10);

/// Règle PURE (testée) : « en direct » = partage actif ET < 2 min ; « signal
/// perdu » = partage actif, 2 à 10 min ; sinon « vu il y a X ».
FriendLiveState friendLiveState({
  required bool sharing,
  required DateTime? seenAt,
  required DateTime now,
}) {
  if (!sharing || seenAt == null) return FriendLiveState.seen;
  final age = now.difference(seenAt);
  if (age <= kFriendLiveFresh) return FriendLiveState.live;
  if (age <= kFriendLiveLost) return FriendLiveState.lost;
  return FriendLiveState.seen;
}

/// v587 — un événement `map:friend-position` reçu à [receivedAt] : c'est la
/// preuve d'un partage actif, et son signe de vie est l'heure de RÉCEPTION
/// (jamais l'horodatage du serveur comparé à l'horloge du téléphone). Pure,
/// testée.
FriendPosition applyLiveEvent(FriendPosition fp, DateTime receivedAt) =>
    fp.copyWith(stale: false, lastSeenAt: receivedAt, sharing: true);

/// v565 — durées de partage proposées au démarrage (contrat §8).
/// Défaut : jusqu'à l'arrêt manuel.
enum LiveShareDuration { oneHour, fourHours, untilStop }

extension LiveShareDurationApi on LiveShareDuration {
  /// Valeur envoyée au serveur (`duration` de POST /friends/live-position).
  String get apiValue {
    switch (this) {
      case LiveShareDuration.oneHour:
        return '1h';
      case LiveShareDuration.fourHours:
        return '4h';
      case LiveShareDuration.untilStop:
        return 'until_stop';
    }
  }

  Duration? get length {
    switch (this) {
      case LiveShareDuration.oneHour:
        return const Duration(hours: 1);
      case LiveShareDuration.fourHours:
        return const Duration(hours: 4);
      case LiveShareDuration.untilStop:
        return null;
    }
  }

  static LiveShareDuration fromApi(String? v) {
    switch (v) {
      case '1h':
        return LiveShareDuration.oneHour;
      case '4h':
        return LiveShareDuration.fourHours;
      default:
        return LiveShareDuration.untilStop;
    }
  }
}

/// v565 — état RÉEL de mon partage, affiché dans le bandeau PawMap.
///   off    : je ne partage pas
///   active : positions livrées (socket vivante, ou battement HTTP passé)
///   lost   : socket coupée ET dernier battement HTTP en échec (ou GPS muet)
enum LiveShareStatus { off, active, lost }

/// Bridges the socket layer with the PawMap UI:
///   - Emits `map:identify` after connection so backend knows who we are.
///   - Emits `map:position-update` when we want to broadcast our location.
///   - Listens to `map:friend-position` / `map:friend-offline` and keeps a
///     reactive map of `userId → FriendPosition` that the UI can observe.
///
/// This service is a GetX service so we can inject it once at app boot and
/// have the subscription outlive individual screens.
/// v589 — décision prise à la lecture de `GET /friends/live-state`.
///   · arrêté par la personne (n'importe quel appareil) alors que CE
///     téléphone diffuse → on coupe ici ;
///   · direct actif alors que ce téléphone ne diffuse pas → « autre téléphone ».
/// Un direct simplement absent (serveur redémarré, session RAM perdue) ne
/// coupe JAMAIS le téléphone qui diffuse : seul un arrêt voulu le fait.
class LiveStateDecision {
  const LiveStateDecision({required this.stopLocal, required this.elsewhere});
  final bool stopLocal;
  final bool elsewhere;
}

LiveStateDecision liveStateDecision(Map<String, dynamic> state,
    {required bool broadcasting, DateTime? localStartedAt}) {
  final bool active = state['active'] == true;
  final bool stopped = state['stopped'] == true;
  if (broadcasting) {
    // Un arrêt ANTÉRIEUR à mon démarrage ici est périmé : je viens de relancer
    // le direct et le serveur n'a pas encore reçu ma première position.
    final DateTime? stoppedAt =
        DateTime.tryParse((state['stoppedAt'] ?? '').toString());
    final bool fresh = stoppedAt != null &&
        (localStartedAt == null || stoppedAt.isAfter(localStartedAt));
    return LiveStateDecision(
        stopLocal: stopped && !active && fresh, elsewhere: false);
  }
  return LiveStateDecision(stopLocal: false, elsewhere: active);
}

class LiveMapService extends GetxService {
  LiveMapService({GetStorage? storage}) : _storage = storage ?? GetStorage();

  final GetStorage _storage;

  /// userId → latest FriendPosition from the socket
  final RxMap<String, FriendPosition> friendPositions =
      <String, FriendPosition>{}.obs;

  /// Has the user agreed to broadcast their position at all.
  final RxBool broadcasting = false.obs;

  /// v589 — mon direct tourne sur un AUTRE de mes téléphones (lu sur le
  /// serveur : `GET /friends/live-state`, puis `map:self-live`). Ce téléphone
  /// ne diffuse pas, mais la pilule le dit au lieu d'afficher « Direct » éteint.
  final RxBool liveElsewhere = false.obs;

  /// v589 — nombre de personnes qui suivent MON direct (jamais leurs noms).
  final RxInt myFollowers = 0.obs;

  /// v589 — je suis le direct de [targetId] (on) / j'arrête (off). Appelé au
  /// début du suivi, toutes les 60 s pendant, et à la fin.
  Future<void> followPresence(String targetId, bool on) async {
    try {
      if (targetId.isEmpty || !Get.isRegistered<ApiClient>()) return;
      await Get.find<ApiClient>().post('/friends/follow-presence',
          body: {'targetId': targetId, 'on': on}, requiresAuth: true);
    } catch (e) {
      debugPrint('[LiveMap] follow-presence failed: $e');
    }
  }

  Timer? _broadcastTicker;
  // v23.1 part 238 — Daniel : "suivre famille sa me donne pas la bonne
  // position". v237 fix utilisait _userPosition mais NE LE RAFRAICHIT
  // PAS pendant le broadcast (le user bouge, la position emise reste
  // l'initiale). FIX : on s'abonne au stream Geolocator continu pendant
  // le broadcast. Chaque mise a jour GPS = nouveau dernier-known stocke,
  // utilise par le ticker 10s + le _emitPosition immediate.
  StreamSubscription<Position>? _gpsSub;
  LatLng? _lastKnownGps;
  bool _hookRegistered = false;

  // v23.1.294 — position GPS live de l'utilisateur, observée par la PawMap pour
  // faire suivre la caméra "à la trace" quand « Me suivre » est actif.
  final Rxn<LatLng> myLivePosition = Rxn<LatLng>();
  // v565 — Daniel (14/09) : « le partage s'arrête tout seul en < 2 h, j'ai
  // rien touché ». Les anciennes causes d'arrêt automatique (cap de session
  // 2 h, session gratuite 30 min, immobilité 30 min) sont SUPPRIMÉES : le
  // partage ne s'arrête plus QUE sur action de l'utilisateur ou à la fin de
  // la durée qu'il a choisie (1 h / 4 h / jusqu'à l'arrêt — contrat §8).
  /// Durée choisie au démarrage de la session.
  final Rx<LiveShareDuration> sessionDuration =
      LiveShareDuration.untilStop.obs;
  /// Échéance de la session (null = jusqu'à l'arrêt manuel).
  final Rxn<DateTime> sessionEndsAt = Rxn<DateTime>();
  /// v587 — début du partage (pilule « En direct · 12 min »), gardé en local
  /// pour survivre à une relance de l'app.
  final Rxn<DateTime> sessionStartedAt = Rxn<DateTime>();
  static const String _kStartedAt = 'bg_live_started_v587';
  /// État réel de mon partage (actif / signal perdu).
  final Rx<LiveShareStatus> liveStatus = LiveShareStatus.off.obs;
  /// Compteur bumpé toutes les 30 s : les Obx qui affichent « vu il y a X »
  /// ou l'état « signal perdu » des amis se rafraîchissent sans nouvel event.
  final RxInt staleTick = 0.obs;
  Timer? _durationTimer;
  Timer? _staleTicker;
  Timer? _refreshTimer;
  Timer? _gpsRetryTimer;
  /// v584 — nouvel essai de branchement socket (voir `attach`).
  Timer? _attachRetry;
  int _attachRetries = 0;
  String? _city;
  DateTime? _lastGpsAt;
  DateTime? _lastHttpAt;
  bool _lastHttpOk = true;
  bool _gpsDegraded = false;
  /// Battement HTTP quand la socket est coupée (contrat §8 : toutes les 60 s).
  static const Duration _httpHeartbeatEvery = Duration(seconds: 60);
  /// Rafraîchissement des positions amis (stale / lastSeenAt) par HTTP.
  static const Duration _refreshEvery = Duration(minutes: 2);
  /// v587 — relecture rapide quand au moins un ami partage.
  static const Duration _refreshFastEvery = Duration(seconds: 30);

  /// v23.1 part 240 — Daniel (3eme tentative) : "personne en live sa marche
  /// toujour pas sa me donne ma geolocalisation au lieu de la geolocalisation
  /// reel de la personne corrige sa sa fais deja 3 fois que je tele dis,
  /// donc le bouton me suivre marcha pas car jai fais les test et apres qd
  /// la personne met voir en live sa lui donne sa geolocalisation au lieu de
  /// la mienne". ROOT CAUSE trouvee : attach() etait UNIQUEMENT appele dans
  /// paw_map_screen.dart. Si user ne visite jamais PawMap → map:identify
  /// jamais emis → backend rejette map:position-update (cf mapSocket.js
  /// L122 `if (!identity) return;`) → broadcast silencieusement no-op.
  ///
  /// FIX : on enregistre attach() en hook onConnected du SocketService.
  /// Comme ca des que la socket connect (boot, reconnect background→fg,
  /// network hiccup), on emet map:identify automatiquement. Idempotent
  /// grace aux .off() avant .on() dans attach().
  @override
  void onInit() {
    super.onInit();
    try {
      final svc = Get.find<SocketService>();
      if (!_hookRegistered) {
        _hookRegistered = true;
        svc.addOnConnectedHook(attach);
        // v23.1.300 — Daniel : "quand je me déco/reco, ça ne se réajoute pas
        // automatiquement". À chaque (re)connexion socket, si je partage ma
        // position, je la ré-émets IMMÉDIATEMENT (sans attendre le ticker 10s)
        // → je réapparais tout de suite chez mes amis/famille. attach() (hook
        // précédent, même liste, ordre garanti) a déjà ré-émis map:identify.
        svc.addOnConnectedHook(() {
          if (!broadcasting.value) return;
          final pos = _lastKnownGps;
          if (pos != null) _emitPosition(pos);
        });
      }
      // Si la socket est deja connectee, addOnConnectedHook fire le
      // callback immediatement (cf SocketService.addOnConnectedHook).
      // Sinon, tentative defensive d'attach maintenant (no-op si pas
      // de socket — attach() return early).
      if (svc.isConnected) {
        attach();
      }
    } catch (e) {
      debugPrint('[LiveMap] onInit hook failed: $e');
    }
    // v565 — « vu il y a X » et « signal perdu » se recalculent toutes les
    // 30 s même sans nouvel event socket.
    _staleTicker?.cancel();
    _staleTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      staleTick.value++;
    });
    // v565 — session persistée (app relancée après un swipe-kill ou un
    // redémarrage) : on reprend le partage au lieu d'afficher « OFF » alors
    // que le service de fond diffuse encore (cf. bug v532).
    unawaited(_resumePersistedSession());
  }

  /// v565 — reprend une session de partage persistée dans GetStorage si elle
  /// n'est pas échue. Best-effort : sans dernière position GPS connue, on
  /// attend le premier fix du flux (le ticker n'émet rien tant qu'il n'y a
  /// pas de position).
  Future<void> _resumePersistedSession() async {
    try {
      if (broadcasting.value) return;
      if (_storage.read(kBgLiveActive) != true) return;
      final until = (_storage.read(kBgUntil) as num?)?.toInt() ?? 0;
      if (until > 0 && DateTime.now().millisecondsSinceEpoch >= until) {
        // Échue pendant que l'app était fermée : on nettoie proprement.
        stopBroadcasting();
        return;
      }
      LatLng? last;
      try {
        final p = await Geolocator.getLastKnownPosition();
        if (p != null) last = LatLng(p.latitude, p.longitude);
      } catch (_) {/* pas de dernière position */}
      final duration = LiveShareDurationApi.fromApi(
          (_storage.read(kBgDuration) ?? '').toString());
      final city = (_storage.read(kBgCity) ?? '').toString();
      startBroadcasting(
        () => last ?? const LatLng(0, 0),
        city: city.isEmpty ? null : city,
        duration: duration,
        endsAt: until > 0 ? DateTime.fromMillisecondsSinceEpoch(until) : null,
      );
      debugPrint('[LiveMap] session persistée reprise (${duration.apiValue})');
    } catch (e) {
      debugPrint('[LiveMap] resume persisted session failed: $e');
    }
  }

  /// v565 — temps restant de la session (null = jusqu'à l'arrêt).
  Duration? get remaining {
    final end = sessionEndsAt.value;
    if (end == null) return null;
    final d = end.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  /// Register socket listeners — idempotent.
  void attach() {
    // v584 (25/09) — Daniel : « les amis n'apparaissent pas sur le
    // téléphone (ils apparaissent sur le site) ». Avant, TOUT ce qui suit
    // — y compris l'hydratation HTTP des positions d'amis — attendait la
    // socket : ouverte avant qu'elle ne soit prête, la carte restait sans
    // aucun ami tant que rien ne bougeait. L'hydratation ne dépend pas de la
    // socket : elle part tout de suite, et on retente `attach()` un peu plus
    // tard pour brancher les événements live dès que la socket existe.
    _hydrateLastKnownPositions();
    final svc = Get.isRegistered<SocketService>() ? Get.find<SocketService>() : null;
    final socket = svc?.socket;
    if (socket == null) {
      debugPrint('[LiveMap] socket not ready yet — positions hydratées par HTTP, nouvel essai dans 3 s');
      _attachRetry?.cancel();
      if (_attachRetries < 10) {
        _attachRetries += 1;
        _attachRetry = Timer(const Duration(seconds: 3), attach);
      }
      return;
    }
    _attachRetries = 0;
    _attachRetry?.cancel();
    _attachRetry = null;

    // Identify on the map channel (separate from chat identify).
    final role = _storage.read<String>(StorageKeys.userRole);
    final profile = _storage.read<Map<String, dynamic>>(StorageKeys.userProfile);
    final userId = profile?['id']?.toString();
    if (role != null && userId != null) {
      socket.emit('map:identify', {'role': role, 'userId': userId});
    }

    // v23.1.351 — Daniel : "à la 1re connexion sur la PawMap, tous les amis/
    // famille doivent apparaître". Avant : friendPositions n'était rempli QUE
    // par les events live map:friend-position → carte vide d'amis tant que
    // LEUR téléphone n'émettait pas. On hydrate maintenant avec la dernière
    // position connue (<24h, mêmes règles d'accès que le live) en un appel.
    _hydrateLastKnownPositions();

    socket.off('map:friend-position');
    socket.on('map:friend-position', (raw) {
      try {
        final map = (raw as Map).cast<String, dynamic>();
        final fp = FriendPosition.fromJson(map);
        // v565 — une position live = signe de vie frais : jamais « stale ».
        // v584 — et c'est la preuve d'un PARTAGE actif.
        // v587 — l'événement arrive EN DIRECT : sa réception EST le signe de
        // vie, mesuré à l'heure du téléphone (avant : `at` du serveur, faux
        // si l'horloge du téléphone dérive, et faux pour un battement qui
        // rejoue une position plus ancienne).
        // v589 — rangée PAR PERSONNE : jamais un second rond.
        final key = friendPositionKey(friendPositions, fp);
        final merged = fp.copyWith(
            userId: key, personIds: mergedPersonIds(friendPositions[key], fp));
        friendPositions[key] = applyLiveEvent(merged, DateTime.now());
      } catch (e) {
        debugPrint('[LiveMap] friend-position parse error: $e');
      }
    });

    socket.off('map:friend-offline');
    socket.on('map:friend-offline', (raw) {
      try {
        final map = (raw as Map).cast<String, dynamic>();
        final uid = map['userId']?.toString();
        // v584 (25/09) — l'ami a COUPÉ son partage : on garde sa dernière
        // position (« vu il y a X »), mais plus rien de « direct ».
        if (uid != null) {
          // v589 — même personne sous un autre id : on retrouve SA position.
          final probe = FriendPosition(
            userId: uid,
            role: '',
            latitude: 0,
            longitude: 0,
            at: DateTime.now(),
            personIds: <String>[
              if (map['personIds'] is List)
                for (final e in (map['personIds'] as List)) e.toString(),
            ],
          );
          final key = friendPositionKey(friendPositions, probe);
          final cur = friendPositions[key];
          if (cur != null) {
            friendPositions[key] = cur.copyWith(sharing: false, stale: true);
          }
        }
      } catch (_) {}
    });

    // v565 — contrat §8 : à l'échéance de la durée choisie, le serveur
    // prévient le DIFFUSEUR (`map:live-session-ended`) : on coupe localement
    // (sans ré-émettre go-offline : le serveur a déjà tout fermé).
    socket.off('map:live-session-ended');
    socket.on('map:live-session-ended', (_) {
      if (!broadcasting.value) return;
      _durationTimer?.cancel();
      _durationTimer = null;
      final wasEnd = sessionEndsAt.value != null;
      stopBroadcasting();
      if (wasEnd) {
        CustomSnackbar.showInfo(
          title: 'v565_live_ended_title'.tr,
          message: 'v565_live_ended_msg'.tr,
        );
      }
    });

    // v589 — mon direct suit la PERSONNE : lancé ou arrêté depuis un autre
    // de mes téléphones, le serveur prévient les autres (`map:self-live`).
    // v589 — nombre de personnes qui suivent mon direct.
    socket.off('map:followers');
    socket.on('map:followers', (raw) {
      try {
        final n = ((raw as Map)['count'] as num?)?.toInt() ?? 0;
        myFollowers.value = n < 0 ? 0 : n;
      } catch (_) {/* payload inattendu */}
    });

    socket.off('map:self-live');
    socket.on('map:self-live', (raw) {
      try {
        final map = (raw as Map).cast<String, dynamic>();
        _applyRemoteLive(active: map['active'] == true, announce: true);
      } catch (_) {/* payload inattendu */}
    });
    unawaited(syncLiveState());

    // v565 — contrat §6 : présence « en ligne » en temps réel. On retire
    // UNIQUEMENT notre propre handler (d'autres écrans écoutent le même
    // event) avant de le remettre → idempotent à chaque reconnexion.
    socket.off('presence:update', _onPresenceUpdate);
    socket.on('presence:update', _onPresenceUpdate);
  }

  /// v565 — contrat §6 : `userId → en ligne ?` alimenté par `presence:update`.
  /// La PawMap (fiche membre, marqueurs) lit ici en priorité sur le champ
  /// `isOnline` figé renvoyé au chargement.
  final RxMap<String, bool> presence = <String, bool>{}.obs;

  void _onPresenceUpdate(dynamic raw) {
    try {
      final map = (raw as Map).cast<String, dynamic>();
      final uid = map['userId']?.toString();
      if (uid == null || uid.isEmpty) return;
      presence[uid] = map['online'] == true;
    } catch (_) {/* payload inattendu */}
  }

  /// v565 — en ligne ? (null = inconnu → l'appelant garde sa valeur chargée).
  bool? isOnline(String userId) => presence[userId];

  /// v589 — relit l'état du direct de la PERSONNE sur le serveur (3 profils,
  /// tous appareils) : à l'ouverture, à chaque (re)connexion socket.
  Future<void> syncLiveState() async {
    try {
      if (!Get.isRegistered<ApiClient>()) return;
      final raw = await Get.find<ApiClient>()
          .get('/friends/live-state', requiresAuth: true);
      if (raw is! Map) return;
      myFollowers.value = (raw['followers'] as num?)?.toInt() ?? 0;
      final d = liveStateDecision(raw.cast<String, dynamic>(),
          broadcasting: broadcasting.value,
          localStartedAt: sessionStartedAt.value);
      if (d.stopLocal) {
        _applyRemoteLive(active: false, announce: true);
      } else {
        liveElsewhere.value = d.elsewhere;
      }
    } catch (e) {
      debugPrint('[LiveMap] live-state failed: $e');
    }
  }

  void _applyRemoteLive({required bool active, bool announce = false}) {
    if (active) {
      // Mon propre démarrage revient aussi dans mon salon : rien à faire.
      if (!broadcasting.value) liveElsewhere.value = true;
      return;
    }
    liveElsewhere.value = false;
    if (!broadcasting.value && _storage.read(kBgLiveActive) != true) return;
    stopBroadcasting(notifyServer: false);
    if (announce) {
      CustomSnackbar.showInfo(
        title: 'pawmap587_sig_live_off'.tr,
        message: 'live589_stopped_elsewhere'.tr,
      );
    }
  }

  /// v589 — arrêter depuis CE téléphone un direct lancé sur un autre : le
  /// serveur coupe les 3 profils et fait taire le service de fond de l'autre.
  Future<void> stopEverywhere() async {
    liveElsewhere.value = false;
    if (broadcasting.value) {
      stopBroadcasting();
      return;
    }
    await _postOfflineHttp();
  }

  // v23.1.351 — garde anti-spam : 1 hydratation par session (attach() est
  // ré-appelé à chaque reconnexion socket ; le live prend le relais ensuite).
  bool _hydratedOnce = false;

  /// Hydrate `friendPositions` avec la DERNIÈRE position connue (<24h) de
  /// chaque ami/famille traçable — GET /friends/live-positions (mêmes règles
  /// d'accès que le live : opt-out > famille > PawFollow > partage). On
  /// n'écrase JAMAIS une position live déjà reçue (plus fraîche par nature).
  Future<void> _hydrateLastKnownPositions() async {
    if (_hydratedOnce) return;
    _hydratedOnce = true;
    final ok = await refreshFriendPositions();
    if (!ok) _hydratedOnce = false; // retentera à la prochaine (re)connexion
    // v565 — puis rafraîchissement périodique : `stale` / `lastSeenAt` restent
    // justes même si la socket ne livre plus rien (signal perdu côté ami).
    // v587 — toutes les 30 s dès qu'un ami partage (ou qu'on en suit un) :
    // si la socket ne livre rien, la relecture garde l'ami « en direct »
    // (seuil 2 min) au lieu de le faire clignoter en « signal perdu » ;
    // sinon toutes les 2 min comme avant.
    _refreshTimer?.cancel();
    var ticks = 0;
    _refreshTimer = Timer.periodic(_refreshFastEvery, (_) {
      ticks += 1;
      final fast = friendPositions.values.any((p) => p.sharing);
      if (fast || ticks % (_refreshEvery.inSeconds ~/ _refreshFastEvery.inSeconds) == 0) {
        unawaited(refreshFriendPositions());
      }
    });
  }

  /// v565 — GET /friends/live-positions : fusionne `stale` + `lastSeenAt`
  /// dans les positions connues, sans jamais reculer une position plus
  /// fraîche reçue par la socket. Renvoie false en cas d'échec réseau.
  Future<bool> refreshFriendPositions() async {
    try {
      if (!Get.isRegistered<ApiClient>()) return false;
      final r = await Get.find<ApiClient>()
          .get('/friends/live-positions', requiresAuth: true);
      final list = (r is Map && r['positions'] is List)
          ? r['positions'] as List
          : const [];
      for (final item in list) {
        if (item is! Map) continue;
        final raw = FriendPosition.fromJson(item.cast<String, dynamic>());
        if (raw.userId.isEmpty) continue;
        // v589 — rangée PAR PERSONNE (voir friendPositionKey).
        final key = friendPositionKey(friendPositions, raw);
        final cur = friendPositions[key];
        final fp = raw.copyWith(
            userId: key, personIds: mergedPersonIds(cur, raw));
        if (cur == null) {
          friendPositions[key] = fp;
        } else if (!fp.at.isBefore(cur.at)) {
          friendPositions[key] = fp; // serveur au moins aussi frais
        } else {
          // live plus frais : on ne garde du serveur que l'état de session.
          friendPositions[key] = cur.copyWith(
            personIds: fp.personIds,
            stale: fp.stale && cur.isStale,
            lastSeenAt: fp.seenAt.isAfter(cur.seenAt) ? fp.seenAt : cur.seenAt,
            // v584 — le serveur fait foi sur « partage actif ou non ».
            sharing: fp.sharing,
          );
        }
      }
      debugPrint('[LiveMap] refreshed ${list.length} friend position(s)');
      return true;
    } catch (e) {
      debugPrint('[LiveMap] refresh friend positions failed: $e');
      return false;
    }
  }

  /// Start broadcasting my position to friends. Call [stopBroadcasting] when
  /// the user toggles sharing off.
  ///
  /// v565 — contrat §8. La session dure [duration] (1 h / 4 h / jusqu'à
  /// l'arrêt, défaut jusqu'à l'arrêt) ; [endsAt] sert à REPRENDRE une session
  /// persistée sans repartir de zéro. Plus aucun cap de session ni d'arrêt
  /// sur immobilité : `map:go-offline` ne part QUE sur action de
  /// l'utilisateur ou à l'échéance choisie.
  ///
  /// `latestPosition` est conservé en fallback si le flux GPS n'a pas encore
  /// livré sa première position (cold start du LocationManager) ; (0,0) est
  /// ignoré (jamais envoyé).
  void startBroadcasting(
    LatLng Function() latestPosition, {
    String? city,
    LiveShareDuration duration = LiveShareDuration.untilStop,
    DateTime? endsAt,
  }) {
    if (broadcasting.value) return;
    broadcasting.value = true;
    liveElsewhere.value = false;
    liveStatus.value = LiveShareStatus.active;
    _city = city;
    sessionDuration.value = duration;
    // v587 — reprise d'une session persistée : on garde son vrai début.
    final keptStart = endsAt != null || _storage.read(kBgLiveActive) == true
        ? (_storage.read(_kStartedAt) as num?)?.toInt()
        : null;
    sessionStartedAt.value = keptStart != null && keptStart > 0
        ? DateTime.fromMillisecondsSinceEpoch(keptStart)
        : DateTime.now();
    try {
      _storage.write(_kStartedAt, sessionStartedAt.value!.millisecondsSinceEpoch);
    } catch (_) {/* stockage plein */}
    final len = duration.length;
    sessionEndsAt.value = endsAt ?? (len == null ? null : DateTime.now().add(len));

    // v416 — Daniel : "le direct doit rester allumé même app fermée de force".
    // On arme le SERVICE DE FOND (isolate séparé, survit au swipe-kill sur
    // Android) : on lui dépose le token + l'URL + la ville + la durée dans
    // GetStorage (il n'a pas accès au secure storage), puis on le démarre.
    // v565 — pour TOUT le monde (plus de session « gratuite » qui meurt avec
    // l'app) : c'est la robustesse demandée au point 23. Best-effort : si ça
    // échoue, le flux socket + le battement HTTP en avant-plan continuent.
    try {
      final token = SecureTokenStore.instance.tokenSync ??
          SecureTokenStore.currentToken();
      _storage.write(kBgLiveActive, true);
      _storage.write(kBgToken, token ?? '');
      _storage.write(kBgBaseUrl, ApiConfig.baseUrl);
      _storage.write(kBgCity, city ?? '');
      _storage.write(kBgDuration, duration.apiValue);
      _storage.write(
          kBgUntil, sessionEndsAt.value?.millisecondsSinceEpoch ?? 0);
      if (defaultTargetPlatform == TargetPlatform.android) {
        startLiveTrackingService();
      }
    } catch (e) {
      debugPrint('[LiveMap] background service start failed: $e');
    }

    // Init last known from the closure (typically _userPosition fresh).
    final initial = latestPosition();
    final hasInitial = !(initial.latitude == 0 && initial.longitude == 0);
    _lastKnownGps = hasInitial ? initial : null;
    myLivePosition.value = hasInitial ? initial : null;

    _startGpsStream();

    // Emit once immediately (si on a une position), puis toutes les 10 s.
    if (hasInitial) _emitPosition(initial, city: city);
    _broadcastTicker?.cancel();
    _broadcastTicker = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!broadcasting.value) return;
      final fromClosure = latestPosition();
      final pos = _lastKnownGps ??
          ((fromClosure.latitude == 0 && fromClosure.longitude == 0)
              ? null
              : fromClosure);
      _tick(pos);
    });

    // v565 — fin de la durée choisie : la SEULE fin automatique.
    _durationTimer?.cancel();
    final end = sessionEndsAt.value;
    if (end != null) {
      final wait = end.difference(DateTime.now());
      _durationTimer = Timer(wait.isNegative ? Duration.zero : wait, () {
        if (!broadcasting.value) return;
        stopBroadcasting();
        CustomSnackbar.showInfo(
          title: 'v565_live_ended_title'.tr,
          message: 'v565_live_ended_msg'.tr,
        );
      });
    }
  }

  /// v565 — flux GPS. iOS : `allowsBackgroundLocationUpdates` (barre bleue),
  /// et si le flux tombe en erreur on repart en mode DÉGRADÉ (précision
  /// réduite, filtre 100 m ≈ « changements significatifs ») qui consomme
  /// moins et survit mieux à la mise en veille ; on retente la haute
  /// précision 5 min plus tard. Android : service de premier plan
  /// (notification persistante) via foregroundNotificationConfig.
  void _startGpsStream() {
    _gpsSub?.cancel();
    _gpsRetryTimer?.cancel();
    try {
      _gpsSub = Geolocator.getPositionStream(
        locationSettings: _buildLocationSettings(degraded: _gpsDegraded),
      ).listen((pos) {
        final p = LatLng(pos.latitude, pos.longitude);
        _lastKnownGps = p;
        _lastGpsAt = DateTime.now();
        _gpsError = false;
        myLivePosition.value = p; // la PawMap suit la caméra « à la trace »
      }, onError: (e) {
        debugPrint('[LiveMap] GPS stream error: $e');
        _gpsError = true;
        _scheduleGpsRestart(degraded: true);
      }, onDone: () {
        if (broadcasting.value) _scheduleGpsRestart(degraded: _gpsDegraded);
      });
      if (_gpsDegraded) {
        // Retour à la haute précision après 5 min de mode dégradé.
        _gpsRetryTimer = Timer(const Duration(minutes: 5), () {
          if (!broadcasting.value) return;
          _gpsDegraded = false;
          _startGpsStream();
        });
      }
    } catch (e) {
      debugPrint('[LiveMap] failed to start GPS stream: $e');
      _scheduleGpsRestart(degraded: true);
    }
  }

  void _scheduleGpsRestart({required bool degraded}) {
    if (!broadcasting.value) return;
    _gpsDegraded = degraded;
    _gpsRetryTimer?.cancel();
    _gpsRetryTimer = Timer(const Duration(seconds: 5), () {
      if (broadcasting.value) _startGpsStream();
    });
  }

  /// v565 — un tick (10 s) : socket vivante → émission socket ; socket
  /// coupée → reconnexion automatique + battement HTTP toutes les 60 s
  /// (position si on en a une, sinon simple `heartbeat`). L'état affiché
  /// (`liveStatus`) reflète ce qui est RÉELLEMENT passé.
  void _tick(LatLng? pos) {
    final svc = Get.find<SocketService>();
    if (svc.isConnected && svc.socket != null) {
      if (pos != null) _emitPosition(pos, city: _city);
      // v587 — sans AUCUNE position GPS réelle, rien ne part : on ne se dit
      // pas « en direct » (jamais le centre de la carte à la place).
      _setStatus(_gpsSilent || pos == null
          ? LiveShareStatus.lost
          : LiveShareStatus.active);
      return;
    }
    // Socket coupée : on la relance et on passe par HTTP.
    unawaited(svc.reconnectIfNeeded());
    final last = _lastHttpAt;
    if (last == null ||
        DateTime.now().difference(last) >= _httpHeartbeatEvery) {
      unawaited(_postHttp(pos));
    } else {
      _setStatus(_lastHttpOk && !_gpsSilent
          ? LiveShareStatus.active
          : LiveShareStatus.lost);
    }
  }

  /// GPS en panne depuis plus de 3 min alors qu'on diffuse.
  /// v587 — un téléphone IMMOBILE ne reçoit aucune nouvelle position (filtre
  /// de 5 m) : ce n'est pas une panne. Avant, 3 min assis suffisaient pour
  /// que MON direct s'affiche « signal perdu » alors que la position partait
  /// bien toutes les 10 s. Seule une ERREUR du flux GPS compte désormais.
  bool _gpsError = false;
  bool get _gpsSilent {
    if (!_gpsError) return false;
    final at = _lastGpsAt;
    if (at == null) return true;
    return DateTime.now().difference(at) > const Duration(minutes: 3);
  }

  void _setStatus(LiveShareStatus s) {
    if (!broadcasting.value) return;
    if (liveStatus.value != s) liveStatus.value = s;
  }

  /// v565 — POST /friends/live-position (contrat §8) : position + `duration`,
  /// ou `heartbeat: true` seul quand on n'a pas de position.
  Future<void> _postHttp(LatLng? pos) async {
    _lastHttpAt = DateTime.now();
    try {
      if (!Get.isRegistered<ApiClient>()) throw StateError('no api');
      await Get.find<ApiClient>().post(
        '/friends/live-position',
        body: {
          if (pos != null) 'lat': pos.latitude,
          if (pos != null) 'lng': pos.longitude,
          if (pos == null) 'heartbeat': true,
          if ((_city ?? '').isNotEmpty) 'city': _city,
          'duration': sessionDuration.value.apiValue,
        },
        requiresAuth: true,
      );
      _lastHttpOk = true;
      _setStatus(_gpsSilent || pos == null
          ? LiveShareStatus.lost
          : LiveShareStatus.active);
    } catch (e) {
      _lastHttpOk = false;
      _setStatus(LiveShareStatus.lost);
      debugPrint('[LiveMap] HTTP heartbeat failed: $e');
    }
  }

  /// v23.1.294 — réglages GPS. Sur Android on attache un foreground service
  /// (notif persistante) pour que le partage survive en arrière-plan.
  LocationSettings _buildLocationSettings({bool degraded = false}) {
    final accuracy = degraded ? LocationAccuracy.low : LocationAccuracy.high;
    final int filter = degraded ? 100 : 5;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return gloc_android.AndroidSettings(
        accuracy: accuracy,
        distanceFilter: filter,
        foregroundNotificationConfig: gloc_android.ForegroundNotificationConfig(
          notificationTitle: 'live_share_notif_title'.tr,
          notificationText: 'live_share_notif_text'.tr,
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    // v414 — Daniel : "le direct s'éteint quand l'app se ferme". Sur iOS,
    // AppleSettings.allowBackgroundLocationUpdates garde le GPS vivant en
    // arrière-plan (UIBackgroundModes>location est déjà dans Info.plist) et
    // showBackgroundLocationIndicator affiche la barre bleue obligatoire.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return gloc_apple.AppleSettings(
        accuracy: accuracy,
        distanceFilter: filter,
        activityType: ActivityType.fitness,
        allowBackgroundLocationUpdates: true,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }
    return LocationSettings(accuracy: accuracy, distanceFilter: filter);
  }

  /// Arrêt du partage — UNIQUEMENT sur action de l'utilisateur ou fin de la
  /// durée choisie (contrat §8). Coupe tout : flux GPS, tickers, service de
  /// fond, état persisté, et émet `map:go-offline`.
  /// v565 (18/09) — changer la durée PENDANT un partage (feuille rouverte) :
  /// nouvelle échéance calculée depuis maintenant, persistée pour le service
  /// de fond, timer réarmé, serveur prévenu par HTTP (`duration`).
  void changeDuration(LiveShareDuration d) {
    if (!broadcasting.value) return;
    sessionDuration.value = d;
    final len = d.length;
    sessionEndsAt.value = len == null ? null : DateTime.now().add(len);
    try {
      _storage.write(kBgDuration, d.apiValue);
      _storage.write(
          kBgUntil, sessionEndsAt.value?.millisecondsSinceEpoch ?? 0);
    } catch (_) {/* best-effort */}
    _durationTimer?.cancel();
    _durationTimer = null;
    final end = sessionEndsAt.value;
    if (end != null) {
      _durationTimer = Timer(end.difference(DateTime.now()), () {
        if (!broadcasting.value) return;
        stopBroadcasting();
        CustomSnackbar.showInfo(
          title: 'v565_live_ended_title'.tr,
          message: 'v565_live_ended_msg'.tr,
        );
      });
    }
    unawaited(_postHttp(_lastKnownGps));
  }

  /// [notifyServer] = false quand l'arrêt vient DÉJÀ du serveur (arrêté
  /// depuis un autre appareil, `map:self-live`) : rien à lui renvoyer.
  void stopBroadcasting({bool notifyServer = true}) {
    _broadcastTicker?.cancel();
    _broadcastTicker = null;
    _durationTimer?.cancel();
    _durationTimer = null;
    _gpsRetryTimer?.cancel();
    _gpsRetryTimer = null;
    _gpsSub?.cancel();
    _gpsSub = null;
    _lastKnownGps = null;
    _lastGpsAt = null;
    _gpsError = false;
    _lastHttpAt = null;
    _gpsDegraded = false;
    myLivePosition.value = null;
    sessionEndsAt.value = null;
    sessionStartedAt.value = null;
    try {
      _storage.write(_kStartedAt, 0);
    } catch (_) {/* stockage plein */}
    liveStatus.value = LiveShareStatus.off;
    // v532 — CE `return` RENDAIT L'ARRÊT IMPOSSIBLE APRÈS UN SWIPE-KILL.
    // `broadcasting` ne vit qu'en mémoire, alors que le service de fond, lui,
    // survit à la fermeture de l'app (START_STICKY). On coupe donc TOUJOURS
    // l'état persisté et le service de fond, même si l'app se croit déjà à
    // l'arrêt.
    final wasBroadcasting = broadcasting.value;
    broadcasting.value = false;
    if (wasBroadcasting && notifyServer) {
      final svc = Get.find<SocketService>();
      final socket = svc.socket;
      if (socket != null && svc.isConnected) {
        socket.emit('map:go-offline');
      } else {
        // Socket coupée : le serveur est prévenu par HTTP (offline:true).
        unawaited(_postOfflineHttp());
      }
    }
    // v416 — coupe aussi le service de fond (il enverra un ping offline final).
    try {
      _storage.write(kBgLiveActive, false);
      _storage.write(kBgToken, '');
      _storage.write(kBgUntil, 0);
      stopLiveTrackingService();
    } catch (e) {
      debugPrint('[LiveMap] background service stop failed: $e');
    }
  }

  Future<void> _postOfflineHttp() async {
    try {
      if (!Get.isRegistered<ApiClient>()) return;
      await Get.find<ApiClient>().post(
        '/friends/live-position',
        body: {'offline': true},
        requiresAuth: true,
      );
    } catch (e) {
      debugPrint('[LiveMap] offline HTTP failed: $e');
    }
  }

  void _emitPosition(LatLng pos, {String? city}) {
    final svc = Get.find<SocketService>();
    final socket = svc.socket;
    if (socket == null) return;
    socket.emit('map:position-update', {
      'lat': pos.latitude,
      'lng': pos.longitude,
      if (city != null) 'city': city,
      // v565 — contrat §8 : durée choisie (le serveur l'ignore s'il ne la
      // lit pas sur la socket ; elle fait foi via HTTP).
      'duration': sessionDuration.value.apiValue,
    });
  }

  @override
  void onClose() {
    _staleTicker?.cancel();
    _refreshTimer?.cancel();
    stopBroadcasting();
    super.onClose();
  }
}
