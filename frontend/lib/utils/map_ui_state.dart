import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';

/// v465 — état partagé « carte PawMap agrandie ».
///
/// Quand l'utilisateur agrandit la PawMap, on masque la barre de navigation du
/// bas (StackedNavigationWrapper) pour que la carte soit vraiment plein écran
/// et que le bouton « Signaler », le bouton « Tag Spot » et les bandeaux de
/// validation ne soient plus cachés derrière le menu / la barre système Samsung.
///
/// PawMapScreen écrit cette valeur ; le wrapper l'observe (Obx) pour afficher
/// ou masquer le menu. Top-level → pas de couplage entre les deux widgets.
final RxBool pawMapExpanded = false.obs;

/// v559 — Daniel : « la barre itinéraire est au milieu et le menu de l'app a
/// disparu ». Ouvrir la PawMap depuis un autre écran (chat, personnes en
/// direct, balade suivie, lien) la POUSSAIT hors des onglets : plus de menu,
/// et les marges prévues pour la barre d'onglets tombaient dans le vide.
/// Désormais on bascule sur l'ONGLET PawMap (menu conservé) et on lui confie
/// l'itinéraire à lancer. Le wrapper observe `requestedTab` ; la PawMap
/// observe `pawMapPendingRoute`.
final RxInt requestedTab = (-1).obs;
final Rxn<LatLng> pawMapPendingRoute = Rxn<LatLng>();
final RxBool navWrapperMounted = false.obs;

/// Onglet PawMap dans StackedNavigationWrapper.
const int kPawMapTabIndex = 2;

/// Ouvre la PawMap avec un itinéraire vers (lat, lng) : via l'onglet quand le
/// menu principal est monté (on revient d'abord à la racine de la pile),
/// sinon en écran poussé (ex. app ouverte par un lien avant le menu).
void openPawMapWithRoute(double lat, double lng) {
  if (navWrapperMounted.value) {
    try {
      Get.until((route) => route.isFirst);
    } catch (_) {/* pile déjà à la racine */}
    pawMapPendingRoute.value = LatLng(lat, lng);
    requestedTab.value = kPawMapTabIndex;
    return;
  }
  Get.to(() => PawMapScreen(
        initialLat: lat,
        initialLng: lng,
        routeToLat: lat,
        routeToLng: lng,
      ));
}
