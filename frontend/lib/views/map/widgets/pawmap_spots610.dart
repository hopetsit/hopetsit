// 610 (PAM, 04/10/2026) — la couche PawSpot est ALLUMÉE par défaut pour tous.
//
// Mesuré le 04/10 : Cam (compte gratuit créé le matin, iPhone 609) ne voyait
// AUCUN des 4 PawSpots de La Isla que le téléphone de Daniel affichait. Le
// serveur les renvoie bien à un compte gratuit (/pawspots/nearby, 4 spots).
// Cause côté app : `_showPawSpots` partait à FAUX et ne s'allumait tout seul
// que pour un abonné (refreshBenefits), alors que la couche est gratuite
// depuis la v556. Seul un « éteint » choisi à la main (mémorisé) l'éteint.
import 'package:get_storage/get_storage.dart';

/// Valeur de départ de la couche PawSpot : vraie sauf si la personne l'a
/// éteinte (`pawspot_layer_on` == false). Les réglages du compte
/// (`pawMap.layers.pawspots`) s'appliquent ensuite par-dessus.
bool pawSpotLayerDefault610(Object? stored) => stored != false;

/// Lecture prudente de la mémoire locale (GetStorage absent en test).
bool pawSpotLayerInitial610() {
  try {
    return pawSpotLayerDefault610(GetStorage().read('pawspot_layer_on'));
  } catch (_) {
    return true;
  }
}

// ─── 610 (PAM, 04/10) — les actions PawSpot de la carte, testables ─────────
// Daniel : « les boutons des spots non exécutés à l'écran : que ce ne soit
// plus seulement de la lecture de code ». Les 4 actions (Photo du spot,
// Taguer un lieu, Voir les spots, interrupteur PawSpot) vivent ici, avec
// leurs dépendances injectées ; la PawMap les branche sur ses vrais outils
// (appareil photo, envoi Cloudinary, fiches) et les tests sur des faux.

typedef PawSpotLatLng610 = ({double lat, double lng});

class PawSpotActions610 {
  PawSpotActions610({
    required this.layerOn,
    required this.saveLayer,
    required this.loadNearby,
    required this.takePhoto,
    required this.uploadPhoto,
    required this.openCreate,
    required this.openList,
    required this.startPicking,
    required this.mapCenter,
    required this.gps,
    required this.afterCreated,
    this.onUploading,
    this.onUploadFailed,
    this.spotsLoaded,
  });

  /// Couche PawSpot affichée ?
  final bool Function() layerOn;

  /// Allume / éteint la couche et mémorise le choix (appareil + compte).
  final void Function(bool on) saveLayer;
  final Future<void> Function() loadNearby;

  /// Appareil photo → chemin du fichier (null = annulé).
  final Future<String?> Function() takePhoto;
  final Future<String?> Function(String path) uploadPhoto;

  /// Fiche de création à [at] (photo déjà envoyée si [photoUrl] non vide) ;
  /// vrai si le spot a été publié.
  final Future<bool?> Function(PawSpotLatLng610 at, String photoUrl) openCreate;
  final Future<void> Function() openList;

  /// Viseur « Taguer un lieu » (pin au centre, Valider → fiche).
  final void Function() startPicking;
  final PawSpotLatLng610 Function() mapCenter;
  final PawSpotLatLng610? Function() gps;
  final Future<void> Function(PawSpotLatLng610 at) afterCreated;
  final void Function()? onUploading;
  final void Function()? onUploadFailed;

  /// Nombre de spots déjà chargés (null = inconnu → on recharge).
  final int Function()? spotsLoaded;

  bool _photoBusy = false;

  /// « Photo du spot » : appareil photo → envoi → fiche remplie, posée à MA
  /// position GPS (on photographie l'endroit où l'on est).
  Future<void> photo() async {
    if (_photoBusy) return;
    _photoBusy = true;
    try {
      final path = await takePhoto();
      if (path == null) return;
      onUploading?.call();
      final url = await uploadPhoto(path);
      if (url == null || url.isEmpty) {
        onUploadFailed?.call();
        return;
      }
      final at = gps() ?? mapCenter();
      final created = await openCreate(at, url);
      if (created == true) await afterCreated(at);
    } finally {
      _photoBusy = false;
    }
  }

  /// « Taguer un lieu » : la couche s'allume, le viseur apparaît.
  void tag() {
    if (!layerOn()) saveLayer(true);
    startPicking();
  }

  /// « Voir les spots » : la couche s'allume (gratuit), puis la liste.
  Future<void> spots() async {
    if (!layerOn()) {
      saveLayer(true);
      await loadNearby();
    } else if ((spotsLoaded?.call() ?? 0) == 0) {
      await loadNearby();
    }
    await openList();
  }

  /// Interrupteur PawSpot : éteint ↔ allumé (gratuit pour tous).
  Future<void> toggle() async {
    if (layerOn()) {
      saveLayer(false);
      return;
    }
    saveLayer(true);
    await loadNearby();
  }

  /// Valider le viseur « Taguer un lieu » à [at].
  Future<void> confirmTag(PawSpotLatLng610 at) async {
    final created = await openCreate(at, '');
    if (created == true) await afterCreated(at);
  }
}
