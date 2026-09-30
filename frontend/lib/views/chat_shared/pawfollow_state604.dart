// v604 (ZOE, 30/09/2026) — ÉTAT RÉEL DU SUIVI EN DIRECT D'UNE CONVERSATION,
// PAR SENS, lu sur le SERVEUR.
//
// Daniel (captures du 30/09) : l'en-tête d'une conversation montrait encore
// « En direct · voir la carte », « Suivi actif · Ouvrir la carte » et « Ta
// position part en direct » après l'arrêt du direct ; puis « que les boutons
// de Messages et de la PawMap soient coordonnés, que l'un suive l'autre ou
// que les deux se suivent en même temps ».
//
// La vérité vient du serveur (backend/src/utils/pawfollowState604.js) :
//   GET  /conversations/:id/pawfollow-state   à l'ouverture du fil ;
//   socket `pawfollow:state`                   à chaque changement (< 1 s) ;
//   relecture toutes les 15 s tant que le fil est ouvert, et à chaque
//   reconnexion de la socket (filet de sécurité, jamais un cache seul) ;
//   POST /conversations/:id/pawfollow/stop    « Arrêter de suivre » (mon sens
//   seulement) ou « Arrêter le partage » (scope 'sharing').
//
// Deux sens indépendants, vus par CE téléphone :
//   outgoing = MA position part vers l'autre (il me suit) ;
//   incoming = SA position vient vers moi (je le suis).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/services/socket_service.dart';

/// Un sens du suivi (tel que le serveur le calcule pour moi).
@immutable
class PawFollowDir {
  const PawFollowDir({
    this.status = 'none',
    this.following = false,
    this.live = false,
    this.messageId = '',
    this.endReason = '',
    this.endedAt,
  });

  /// none | pending | accepted | refused | expired | ended
  final String status;

  /// Demande acceptée et en cours.
  final bool following;

  /// En cours ET le partageur diffuse réellement.
  final bool live;
  final String messageId;

  /// live_stopped | duration_ended | follow_stopped | share_stopped | ''
  final String endReason;
  final DateTime? endedAt;

  static const PawFollowDir empty = PawFollowDir();

  factory PawFollowDir.fromJson(dynamic raw) {
    if (raw is! Map) return empty;
    return PawFollowDir(
      status: (raw['status'] ?? 'none').toString(),
      following: raw['following'] == true,
      live: raw['live'] == true,
      messageId: (raw['messageId'] ?? '').toString(),
      endReason: (raw['endReason'] ?? '').toString(),
      endedAt: DateTime.tryParse((raw['endedAt'] ?? '').toString()),
    );
  }
}

/// État d'une conversation pour moi : mes deux sens.
@immutable
class PawFollowConvState {
  const PawFollowConvState({
    this.outgoing = PawFollowDir.empty,
    this.incoming = PawFollowDir.empty,
  });
  final PawFollowDir outgoing;
  final PawFollowDir incoming;

  factory PawFollowConvState.fromJson(Map raw) => PawFollowConvState(
        outgoing: PawFollowDir.fromJson(raw['outgoing']),
        incoming: PawFollowDir.fromJson(raw['incoming']),
      );
}

/// Ce que montre la pilule d'en-tête.
enum PawFollowHeaderKind {
  /// Rien en cours : « Suivre » / « Partager ma position ».
  none,

  /// L'autre diffuse vers moi : « En direct · voir la carte ».
  peerLive,

  /// Ma position part vers lui : « En direct · voir la carte ».
  myLive,

  /// Je suivais l'autre, son direct est arrêté : « Direct arrêté · … ».
  peerStopped,

  /// Il me suit, mon direct est arrêté : « Relancer le direct ».
  myStopped,
}

/// Règle PURE (testée) de la pilule d'en-tête.
///
/// Priorité à l'AUTRE (l'en-tête parle de lui) : son direct, puis son arrêt ;
/// ensuite le mien. [myLive] = ce téléphone diffuse (ou un autre de mes
/// téléphones) ; [peerLiveLocal] = ce que la PawMap reçoit de lui (null =
/// rien reçu) — un « non » local l'emporte sur un « oui » serveur en retard.
PawFollowHeaderKind pawFollowHeaderKind(
  PawFollowConvState s, {
  required bool myLive,
  required bool? peerLiveLocal,
  DateTime? now,
}) {
  final inc = s.incoming;
  final out = s.outgoing;
  if (inc.following && inc.live && peerLiveLocal != false) {
    return PawFollowHeaderKind.peerLive;
  }
  // v605 (ZOE) — BOB : « A suit B, puis B suit A » ne doit faire disparaître
  // aucune pilule. Quand l'autre vient d'accepter mais ne diffuse PAS encore
  // (suivi accepté, jamais arrêté par lui) alors que MA position part en
  // direct, l'en-tête garde « En direct » (mon sens) au lieu d'un faux
  // « Direct arrêté ». Réponse serveur réelle : seq605_2_accepted_A.
  if (inc.following && !inc.live && out.following && myLive) {
    return PawFollowHeaderKind.myLive;
  }
  // Son direct est arrêté : suivi accepté sans diffusion, ou demande que SON
  // arrêt a terminée (jamais quand c'est moi qui ai arrêté de le suivre).
  final DateTime? endedAt = inc.endedAt;
  final bool peerEndedHisLive = inc.status == 'ended' &&
      (inc.endReason == 'live_stopped' || inc.endReason == 'duration_ended') &&
      endedAt != null &&
      (now ?? DateTime.now()).difference(endedAt) < const Duration(hours: 12);
  if (inc.following || peerEndedHisLive) {
    return PawFollowHeaderKind.peerStopped;
  }
  if (out.following && myLive) return PawFollowHeaderKind.myLive;
  if (out.following) return PawFollowHeaderKind.myStopped;
  return PawFollowHeaderKind.none;
}

/// Mémoire des états serveur par conversation + écoute socket + relecture.
class PawFollowStateStore {
  PawFollowStateStore._();

  /// conversationId → état serveur (absent = pas encore lu).
  static final RxMap<String, PawFollowConvState> states =
      <String, PawFollowConvState>{}.obs;

  static final Map<String, int> _watchers = <String, int>{};
  static Timer? _poll;
  static bool _hooked = false;

  /// Tests : applique un événement socket `pawfollow:state` tel quel.
  @visibleForTesting
  static void debugApplySocketEvent(dynamic raw) => _onSocketState(raw);

  static void _onSocketState(dynamic raw) {
    try {
      if (raw is! Map) return;
      final cid = (raw['conversationId'] ?? '').toString();
      if (cid.isEmpty) return;
      states[cid] = PawFollowConvState.fromJson(raw);
    } catch (e) {
      debugPrint('[pawfollow604] socket state parse failed: $e');
    }
  }

  static void _bindSocket() {
    if (!Get.isRegistered<SocketService>()) return;
    final svc = Get.find<SocketService>();
    void bind() {
      final s = svc.socket;
      if (s == null) return;
      s.off('pawfollow:state', _onSocketState);
      s.on('pawfollow:state', _onSocketState);
      // Reconnexion : ce qui a pu changer pendant la coupure est relu.
      for (final cid in _watchers.keys) {
        unawaited(refresh(cid));
      }
    }

    if (!_hooked) {
      _hooked = true;
      svc.addOnConnectedHook(bind);
    } else {
      bind();
    }
  }

  /// Le fil [conversationId] est ouvert : lecture serveur immédiate, puis
  /// socket + relecture toutes les 15 s tant qu'il reste ouvert.
  static void watch(String conversationId) {
    if (conversationId.isEmpty) return;
    _watchers[conversationId] = (_watchers[conversationId] ?? 0) + 1;
    _bindSocket();
    unawaited(refresh(conversationId));
    _poll ??= Timer.periodic(const Duration(seconds: 15), (_) {
      for (final cid in _watchers.keys.toList()) {
        unawaited(refresh(cid));
      }
    });
  }

  static void unwatch(String conversationId) {
    final n = (_watchers[conversationId] ?? 0) - 1;
    if (n <= 0) {
      _watchers.remove(conversationId);
    } else {
      _watchers[conversationId] = n;
    }
    if (_watchers.isEmpty) {
      _poll?.cancel();
      _poll = null;
    }
  }

  /// Relit l'état serveur. Échec réseau : on garde la dernière valeur lue.
  static Future<void> refresh(String conversationId) async {
    try {
      if (!Get.isRegistered<ApiClient>()) return;
      final r = await Get.find<ApiClient>().get(
        '/conversations/$conversationId/pawfollow-state',
        requiresAuth: true,
      );
      if (r is Map) states[conversationId] = PawFollowConvState.fromJson(r);
    } catch (e) {
      debugPrint('[pawfollow604] refresh failed: $e');
    }
  }

  /// « Arrêter de suivre » ([scope] 'following') ou « Arrêter le partage »
  /// ('sharing'). Renvoie true si le serveur a bien terminé au moins un sens.
  static Future<bool> stop(
    String conversationId, {
    String scope = 'following',
    String? messageId,
  }) async {
    if (!Get.isRegistered<ApiClient>()) return false;
    final r = await Get.find<ApiClient>().post(
      '/conversations/$conversationId/pawfollow/stop',
      body: <String, dynamic>{
        'scope': scope,
        if (messageId != null && messageId.isNotEmpty) 'messageId': messageId,
      },
      requiresAuth: true,
    );
    if (r is Map) {
      states[conversationId] = PawFollowConvState.fromJson(r);
      return ((r['ended'] as num?) ?? 0) > 0;
    }
    return false;
  }
}
