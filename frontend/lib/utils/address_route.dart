// v585 (25/09/2026) — Daniel : « Google Maps, c'est nos concurrents » : AUCUN
// bouton de l'app n'envoie vers Google Maps. Une adresse partagée dans le chat
// ou une adresse de suivi s'ouvre DANS la PawMap, itinéraire tracé par nos
// soins (paramètres `routeToLat` / `routeToLng`). Sans coordonnées, l'adresse
// est d'abord géocodée par le téléphone.
import 'package:get/get.dart';

import 'package:hopetsit/services/location_service.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

Future<void> openAddressInPawMap({
  double? lat,
  double? lng,
  String address = '',
}) async {
  double? la = lat;
  double? lo = lng;
  if ((la == null || lo == null) && address.trim().isNotEmpty) {
    try {
      final p = await LocationService().getCoordinatesFromCity(address.trim());
      la = p?.latitude;
      lo = p?.longitude;
    } catch (_) {/* adresse introuvable : message ci-dessous */}
  }
  if (la == null || lo == null) {
    CustomSnackbar.showError(
      title: 'common_error'.tr,
      message: 'lists569_action_unavailable'.tr,
    );
    return;
  }
  Get.to(() => PawMapScreen(
        initialLat: la,
        initialLng: lo,
        initialZoom: 15,
        routeToLat: la,
        routeToLng: lo,
      ));
}
