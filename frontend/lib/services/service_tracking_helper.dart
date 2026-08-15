import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/utils/logger.dart';

/// v534 — DÉMARRAGE AUTOMATIQUE DU SUIVI PENDANT UNE PRESTATION.
///
/// Daniel : « vérifie le live tracking entre owner, sitter et walker ».
///
/// L'audit a montré que le suivi ne démarrait JAMAIS tout seul : le
/// propriétaire payait, le prestataire appuyait sur « J'ai récupéré
/// l'animal », le propriétaire tapait « Suivre mon animal »… et voyait un
/// point FIGÉ — la position instantanée prise au moment du clic. Pour que ça
/// bouge, le prestataire devait penser à activer manuellement l'interrupteur
/// « Partager ma position » de la PawMap. Personne ne le faisait.
///
/// On démarre donc la diffusion au moment où le prestataire déclare avoir
/// récupéré l'animal, et on l'arrête quand il déclare l'avoir rendu. C'est
/// exactement la fenêtre pendant laquelle le propriétaire a le droit de
/// suivre (le backend ferme l'accès dès la fin du service), et le prestataire
/// garde la main : le bandeau vert de la PawMap reste affiché et permet de
/// couper à tout moment.
class ServiceTrackingHelper {
  const ServiceTrackingHelper._();

  /// Lance la diffusion de position pour la durée de la prestation.
  ///
  /// Best-effort : si la permission est refusée ou le GPS indisponible, on
  /// n'échoue PAS l'action métier (le service a bien démarré côté serveur),
  /// on se contente de ne pas diffuser.
  static Future<void> startForService() async {
    try {
      final live = Get.isRegistered<LiveMapService>()
          ? Get.find<LiveMapService>()
          : Get.put(LiveMapService(), permanent: true);
      if (live.broadcasting.value) return; // déjà en cours

      // On exige une VRAIE position : sans elle, on diffuserait le centre de
      // la carte, ce qui afficherait le prestataire au mauvais endroit chez
      // le propriétaire (défaut relevé par l'audit).
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        AppLogger.logWarning(
          '[ServiceTracking] permission refusée — pas de diffusion',
        );
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        AppLogger.logWarning('[ServiceTracking] GPS désactivé — pas de diffusion');
        return;
      }

      final pos = await Geolocator.getCurrentPosition();
      var latest = LatLng(pos.latitude, pos.longitude);
      live.startBroadcasting(() => latest);
      // Le ticker interne rappelle cette closure ; on garde la dernière
      // position connue à jour via le flux GPS du service lui-même.
      live.myLivePosition.listen((p) {
        if (p != null) latest = p;
      });
      AppLogger.logInfo('[ServiceTracking] diffusion démarrée pour la prestation');
    } catch (e) {
      AppLogger.logWarning('[ServiceTracking] démarrage impossible: $e');
    }
  }

  /// Coupe la diffusion à la fin de la prestation.
  static Future<void> stopForService() async {
    try {
      if (!Get.isRegistered<LiveMapService>()) return;
      Get.find<LiveMapService>().stopBroadcasting();
      AppLogger.logInfo('[ServiceTracking] diffusion arrêtée (fin de prestation)');
    } catch (e) {
      AppLogger.logWarning('[ServiceTracking] arrêt impossible: $e');
    }
  }
}
