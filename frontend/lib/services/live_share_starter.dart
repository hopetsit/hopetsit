// v602 (PAM, 29/09/2026) — DÉMARRER LE DIRECT DEPUIS N'IMPORTE OÙ.
//
// Daniel (retour sur le 601) : « quand j'accepte le suivi depuis les
// MESSAGES, ma position précise ne part pas : sur la carte mon icône reste
// vide, je dois ensuite appuyer sur Direct sur la carte pour que ça marche ».
//
// Cause (lue dans le code) : accepter dans le chat ne faisait qu'enregistrer
// la réponse sur le serveur (`respondPawfollowRequest`). Le partage de la
// position, lui, ne démarrait QUE par le bouton Balade / Direct de la PawMap
// (`_startBroadcastWith`), qui lit le GPS puis appelle
// `LiveMapService.startBroadcasting`. Personne ne l'appelait depuis le chat.
//
// Ici : LE MÊME chemin que le bouton Balade, sans dépendre de l'écran de la
// carte — permission de position, vraie position GPS (jamais le centre de la
// carte), `startBroadcasting` (socket + battement HTTP + service de fond),
// donc `broadcasting` passe à vrai : le chat, la PawMap (bouton Balade vert,
// drapeau, rond « Moi ») et le menu lisent UNE seule vérité.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/services/map_prefs_service.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

enum LiveStartResult {
  /// Le partage vient de démarrer sur ce téléphone.
  started,

  /// Déjà en direct sur ce téléphone : rien à faire.
  alreadyLive,

  /// Déjà en direct sur un AUTRE téléphone de la personne : rien à faire.
  liveElsewhere,

  /// Permission de position refusée.
  denied,

  /// Localisation du téléphone éteinte.
  gpsOff,

  /// Erreur inattendue (rien n'a démarré).
  failed,
}

/// Dans une demande de suivi en direct, QUI partage sa position ?
/// Même règle que l'en-tête de la carte du chat : un PROPRIÉTAIRE qui
/// demande veut SUIVRE l'autre (c'est le destinataire qui partage) ; un
/// gardien / promeneur qui demande propose de PARTAGER la sienne (c'est
/// l'expéditeur qui partage). [isMine] = la demande vient de moi.
bool pawfollowSharerIsMe({
  required String requesterRole,
  required bool isMine,
}) {
  final bool requesterFollows = requesterRole.toLowerCase() == 'owner';
  return requesterFollows ? !isMine : isMine;
}

/// L'AUTRE vient d'accepter MA proposition de partager ma position (je suis
/// gardien / promeneur et j'avais proposé « Partager ma position ») : c'est
/// le moment de démarrer mon direct. Seulement au passage « en attente →
/// acceptée » reçu en direct (jamais au simple rechargement d'une vieille
/// carte, qui relancerait un direct que j'ai arrêté).
bool pawfollowAcceptedForMyShare({
  required String previousStatus,
  required String newStatus,
  required String requesterRole,
  required bool isMine,
}) {
  if (previousStatus != 'pending' || newStatus != 'accepted') return false;
  if (!isMine) return false; // je répondais : géré au bouton « Accepter »
  return pawfollowSharerIsMe(requesterRole: requesterRole, isMine: isMine);
}

class LiveShareStarter {
  const LiveShareStarter._();

  /// Démarre le partage de MA position en direct (jusqu'à l'arrêt), comme le
  /// bouton Balade de la PawMap. Ne lève jamais.
  static Future<LiveStartResult> start() async {
    try {
      final live = Get.isRegistered<LiveMapService>()
          ? Get.find<LiveMapService>()
          : Get.put(LiveMapService(), permanent: true);
      if (live.broadcasting.value) return LiveStartResult.alreadyLive;
      if (live.liveElsewhere.value) return LiveStartResult.liveElsewhere;

      if (!await Geolocator.isLocationServiceEnabled()) {
        return LiveStartResult.gpsOff;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return LiveStartResult.denied;
      }

      // Une VRAIE position : GPS frais (8 s max), sinon la dernière position
      // de l'OS si elle a moins de 2 min. Sans rien, on démarre quand même :
      // le flux GPS du service prend le relais dès son premier point, et rien
      // ne part tant qu'il n'y a pas de vraie position (jamais (0,0)).
      LatLng? initial;
      try {
        final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        initial = LatLng(p.latitude, p.longitude);
      } catch (_) {
        try {
          final p = await Geolocator.getLastKnownPosition();
          if (p != null &&
              DateTime.now().difference(p.timestamp) <
                  const Duration(minutes: 2)) {
            initial = LatLng(p.latitude, p.longitude);
          }
        } catch (_) {/* aucune position connue */}
      }
      // Entre-temps, un autre chemin a pu démarrer le direct.
      if (live.broadcasting.value) return LiveStartResult.alreadyLive;
      live.startBroadcasting(
        () => live.myLivePosition.value ?? initial ?? const LatLng(0, 0),
        duration: LiveShareDuration.untilStop,
      );
      return LiveStartResult.started;
    } catch (e) {
      debugPrint('[LiveShareStarter] démarrage impossible : $e');
      return LiveStartResult.failed;
    }
  }

  /// [start] + un message clair (même vocabulaire que la PawMap). Renvoie
  /// vrai si ma position part (ici ou sur mon autre téléphone).
  static Future<bool> startWithFeedback() async {
    final r = await start();
    switch (r) {
      case LiveStartResult.started:
      case LiveStartResult.alreadyLive:
      case LiveStartResult.liveElsewhere:
        bool hidden = false;
        try {
          hidden = MapPrefsService.instance.mapVisibility.value == 'hidden';
        } catch (_) {/* préférences pas encore lues */}
        if (hidden) {
          CustomSnackbar.showWarning(
            title: 'pawmap602_live_on_title'.tr,
            message: 'pawmap587_sig_live_hidden'.tr,
          );
        } else if (r == LiveStartResult.started) {
          CustomSnackbar.showSuccess(
            title: 'pawmap602_live_on_title'.tr,
            message: 'pawmap602_live_on_msg'.tr,
          );
        }
        return true;
      case LiveStartResult.denied:
        CustomSnackbar.showWarning(
          title: 'pawmap602_perm_title'.tr,
          message: 'pawmap602_perm_msg'.tr,
        );
        return false;
      case LiveStartResult.gpsOff:
        CustomSnackbar.showWarning(
          title: 'pawmap602_perm_title'.tr,
          message: 'pawmap602_gps_off_msg'.tr,
        );
        return false;
      case LiveStartResult.failed:
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'pawmap602_start_failed'.tr,
        );
        return false;
    }
  }

  /// Construit [build] avec l'état RÉEL de mon direct (ce téléphone ou mon
  /// autre téléphone), et le reconstruit quand il change — la même vérité
  /// que le bouton Balade de la PawMap.
  static Widget withMyLiveState(Widget Function(bool liveNow) build) {
    if (!Get.isRegistered<LiveMapService>()) return build(false);
    final live = Get.find<LiveMapService>();
    return Obx(() {
      final bool on = live.broadcasting.value || live.liveElsewhere.value;
      return build(on);
    });
  }
}
