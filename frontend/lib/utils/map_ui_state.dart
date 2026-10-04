import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/views/map/pawmap_friend_focus.dart';

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

/// v594 — onglet du menu actuellement affiché (la PawMap vit cachée dans un
/// IndexedStack dès le lancement : elle doit savoir quand on l'ouvre).
final RxInt currentMainTab = 0.obs;

/// v584 — acquisition : un lien `hopetsit://pawmap?lat&lng&z` ou
/// `?city=paris` ouvre l'ONGLET PawMap (menu conservé) centré sur cet
/// endroit. La PawMap observe `pawMapPendingCenter` (zoom dans
/// `pawMapPendingZoom`).
final Rxn<LatLng> pawMapPendingCenter = Rxn<LatLng>();
final RxDouble pawMapPendingZoom = 13.0.obs;

/// v604 — Daniel (30/09) : « Le menu ne doit JAMAIS disparaître !! ».
/// Toute ouverture de la PawMap passe par l'ONGLET du menu : on revient à la
/// racine, on confie la demande à la carte (valeur observée), puis on
/// sélectionne l'onglet. Menu pas encore monté (démarrage à froid par un
/// lien ou une notification) : la demande attend, et le menu ouvre l'onglet
/// PawMap dès qu'il se monte. On ne POUSSE plus jamais la carte en page.
///
/// `true` quand le menu doit ouvrir l'onglet PawMap à son montage.
bool pawMapOpenOnMount = false;

/// Heure de la dernière ouverture EXPLICITE de la carte (lien, chat, ami…) :
/// le menu ne remplace pas alors la demande par « l'unique ami en balade ».
DateTime? pawMapExplicitOpenAt;

/// Demande générique confiée à la PawMap (centre, suivi d'une personne,
/// spot ou signalement partagé, itinéraire). Consommée une seule fois.
class PawMapIntent {
  final double? lat;
  final double? lng;
  final double? zoom;
  final String? focusUserId;
  final String? focusUserRole;
  final String? focusUserName;
  final String? focusUserAvatar;
  final String? focusSpotId;
  final String? focusReportId;
  final double? routeToLat;
  final double? routeToLng;

  const PawMapIntent({
    this.lat,
    this.lng,
    this.zoom,
    this.focusUserId,
    this.focusUserRole,
    this.focusUserName,
    this.focusUserAvatar,
    this.focusSpotId,
    this.focusReportId,
    this.routeToLat,
    this.routeToLng,
  });

  bool get hasCenter => lat != null && lng != null;
  bool get hasUser => (focusUserId ?? '').isNotEmpty;
  bool get hasShared =>
      (focusSpotId ?? '').isNotEmpty || (focusReportId ?? '').isNotEmpty;
  bool get hasRoute => routeToLat != null && routeToLng != null;
  bool get isEmpty => !hasCenter && !hasUser && !hasShared && !hasRoute;
}

final Rxn<PawMapIntent> pawMapPendingIntent = Rxn<PawMapIntent>();

/// Revient à la racine (le menu) ; renvoie `false` si le menu n'est pas monté.
bool _pawMapGoRoot() {
  pawMapExplicitOpenAt = DateTime.now();
  if (!navWrapperMounted.value) {
    pawMapOpenOnMount = true;
    return false;
  }
  try {
    Get.until((route) => route.isFirst);
  } catch (_) {/* pile déjà à la racine */}
  return true;
}

void _pawMapSelectTab(bool mounted) {
  if (mounted) requestedTab.value = kPawMapTabIndex;
}

/// Ouvre l'onglet PawMap (menu toujours visible) avec une demande facultative.
void openPawMap({
  double? lat,
  double? lng,
  double? zoom,
  String? focusUserId,
  String? focusUserRole,
  String? focusUserName,
  String? focusUserAvatar,
  String? focusSpotId,
  String? focusReportId,
  double? routeToLat,
  double? routeToLng,
}) {
  final intent = PawMapIntent(
    lat: lat,
    lng: lng,
    zoom: zoom,
    focusUserId: focusUserId,
    focusUserRole: focusUserRole,
    focusUserName: focusUserName,
    focusUserAvatar: focusUserAvatar,
    focusSpotId: focusSpotId,
    focusReportId: focusReportId,
    routeToLat: routeToLat,
    routeToLng: routeToLng,
  );
  final mounted = _pawMapGoRoot();
  if (intent.isEmpty) {
    pawMapExplicitOpenAt = null; // simple ouverture : comportement habituel
  } else {
    pawMapPendingIntent.value = intent;
  }
  _pawMapSelectTab(mounted);
}

/// Ouvre la PawMap centrée sur (lat, lng), toujours dans l'onglet du menu.
void openPawMapAt(double lat, double lng, {double zoom = 13}) {
  final mounted = _pawMapGoRoot();
  pawMapPendingZoom.value = zoom;
  pawMapPendingCenter.value = LatLng(lat, lng);
  _pawMapSelectTab(mounted);
}

/// v588 — Daniel : « dans la liste d'amis, quand je clique sur sa photo, ça
/// ne me renvoie pas vers lui sur la map ». Ami à montrer : la PawMap
/// observe `pawMapPendingFriend` (vol doux zoom 16, fiche courte, suivi s'il
/// est en direct).
final Rxn<PawMapFriendFocus> pawMapPendingFriend = Rxn<PawMapFriendFocus>();

/// Ouvre l'ONGLET PawMap (menu conservé) sur [focus].
void openPawMapOnFriend(PawMapFriendFocus focus) {
  // Retour à la racine D'ABORD (sinon `Get.until` refermerait la fiche que
  // la carte ouvre en réponse), puis la demande, puis l'onglet.
  final mounted = _pawMapGoRoot();
  pawMapPendingFriend.value = focus;
  _pawMapSelectTab(mounted);
}

/// Ouvre la PawMap avec un itinéraire vers (lat, lng), dans l'onglet du menu.
void openPawMapWithRoute(double lat, double lng) {
  final mounted = _pawMapGoRoot();
  pawMapPendingRoute.value = LatLng(lat, lng);
  _pawMapSelectTab(mounted);
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
  // v604 — la PawMap n'est JAMAIS empilée (elle perdrait le menu).
  if (index == kPawMapTabIndex) {
    openPawMap();
    return;
  }
  if (!openMainTab(index)) Get.to(fallback);
}

/// 610 — la patte verte du menu demande à la PawMap d'ouvrir la feuille
/// « En direct maintenant » (compteur : chaque appui = une demande).
final RxInt pawMapLiveListRequest610 = 0.obs;
