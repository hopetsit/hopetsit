import 'package:flutter/widgets.dart';
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

/// v584 — acquisition : un lien `hopetsit://pawmap?lat&lng&z` ou
/// `?city=paris` ouvre l'ONGLET PawMap (menu conservé) centré sur cet
/// endroit. La PawMap observe `pawMapPendingCenter` (zoom dans
/// `pawMapPendingZoom`).
final Rxn<LatLng> pawMapPendingCenter = Rxn<LatLng>();
final RxDouble pawMapPendingZoom = 13.0.obs;

/// Ouvre la PawMap centrée sur (lat, lng) : via l'onglet quand le menu est
/// monté, sinon en écran poussé.
void openPawMapAt(double lat, double lng, {double zoom = 13}) {
  if (navWrapperMounted.value) {
    try {
      Get.until((route) => route.isFirst);
    } catch (_) {/* pile déjà à la racine */}
    pawMapPendingZoom.value = zoom;
    pawMapPendingCenter.value = LatLng(lat, lng);
    requestedTab.value = kPawMapTabIndex;
    return;
  }
  Get.to(() => PawMapScreen(initialLat: lat, initialLng: lng, initialZoom: zoom));
}

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

/// v573 — Daniel : « le menu d'en bas avait disparu ». Les 5 destinations du
/// menu (0 Accueil · 1 Chat · 2 PawMap · 3 Réservations · 4 Profil — mêmes
/// index pour les 3 rôles) étaient souvent EMPILÉES (`Get.to(XScreen())`)
/// depuis une notification, le profil ou un bandeau : page plein écran, donc
/// sans menu. `openMainTab` revient à la racine et bascule sur l'onglet ;
/// renvoie `false` si le menu n'est pas monté.
bool openMainTab(int index) {
  if (!navWrapperMounted.value) return false;
  try {
    Get.until((route) => route.isFirst);
  } catch (_) {/* pile déjà à la racine */}
  requestedTab.value = index;
  return true;
}

/// Bascule sur l'onglet [index] ; à défaut de menu, empile [fallback].
void openMainTabOr(int index, Widget Function() fallback) {
  if (!openMainTab(index)) Get.to(fallback);
}
