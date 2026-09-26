import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/utils/service_location587.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/friend_controller.dart';
import 'package:hopetsit/controllers/map_report_controller.dart';
import 'package:hopetsit/controllers/paw_map_controller.dart';
import 'package:hopetsit/controllers/pawspot_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/models/map_poi_model.dart';
import 'package:hopetsit/models/friendship_model.dart';
import 'package:hopetsit/models/map_report_model.dart';
import 'package:hopetsit/models/nearby_request_model.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/utils/opening_hours.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:url_launcher/url_launcher.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/services/location_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:hopetsit/utils/pawmap_theme.dart';
import 'package:hopetsit/views/booking/bookings_history_screen.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/utils/map_ui_state.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/views/friends/friends_screen.dart';
import 'package:hopetsit/views/friends/people_live_screen.dart';
import 'package:hopetsit/views/pet_owner/chat/chat_screen.dart';
import 'package:hopetsit/views/pet_sitter/chat/sitter_chat_screen.dart';
import 'package:hopetsit/views/map/pawmap_osm_tiles.dart';
import 'package:hopetsit/views/map/alerts_screen.dart';
import 'package:hopetsit/views/map/pawmap_camera_memory.dart';
import 'package:hopetsit/views/map/pawspot_sheets.dart';
import 'package:hopetsit/views/map/widgets/create_report_sheet.dart';
import 'package:hopetsit/views/map/widgets/paw_rail_button.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';
import 'package:hopetsit/views/map/pawmap_help_screen.dart';
import 'package:hopetsit/views/map/pawmap_member_profile_route.dart';
import 'package:hopetsit/views/map/pawmap_rates.dart';
import 'package:hopetsit/views/map/widgets/pawmap_sheets.dart';
import 'package:hopetsit/widgets/app_dialog_kit.dart';
import 'package:hopetsit/views/map/widgets/pawmap_rail.dart';
import 'package:hopetsit/views/map/widgets/pawmap_jewel.dart';
import 'package:hopetsit/views/map/widgets/pawmap_focus_card.dart';
import 'package:hopetsit/views/map/widgets/pawmap_buttons.dart';
import 'package:hopetsit/views/map/widgets/pawmap_sheet.dart';
import 'package:hopetsit/views/map/widgets/pawmap_discreet.dart';
import 'package:hopetsit/views/service_provider/widgets/book_as_owner.dart';
import 'package:hopetsit/services/map_prefs_service.dart';
import 'package:hopetsit/widgets/paw_tab_bar.dart' show pawTabBarTotalHeight;
import 'package:hopetsit/views/map/pawmap_friend_focus.dart';
import 'package:hopetsit/views/map/pawmap_friends_layer.dart';
import 'package:hopetsit/views/map/pawmap_person.dart';
import 'package:hopetsit/views/map/widgets/pawmap_subscriptions_section.dart';
import 'package:hopetsit/widgets/active_benefits_row.dart';
import 'package:hopetsit/views/pet_owner/reservation_request/publish_reservation_request_screen.dart';
import 'package:hopetsit/data/network/secure_token_store.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/repositories/sitter_repository.dart';
import 'package:hopetsit/repositories/walker_repository.dart';
import 'package:hopetsit/views/guest/signup_wall_sheet.dart';
import 'package:hopetsit/views/pet_owner/chat/individual_chat_screen.dart';
import 'package:hopetsit/views/pet_sitter/chat/sitter_individual_chat_screen.dart';
import 'package:hopetsit/views/service_provider/send_request_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/pawmap_header_badge.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/views/map/widgets/pawmap_signal.dart';
import 'package:hopetsit/views/map/widgets/pawmap_announcement.dart';

/// PawMap — Phase 2 Couche 1 (POIs) + Phase 3 Couche 2 (reports 48h).
///
/// - Chips at the top filter by layer (POIs / Reports / all) and by category.
/// - POI markers are static; Report markers carry a live TTL countdown.
/// - FAB "Signaler" is Premium-gated: tapping when free opens the upsell
///   snackbar, tapping when Premium opens the CreateReportSheet.
class PawMapScreen extends StatefulWidget {
  // v23.1 part 213 — Daniel : "si tu clic dessus sa te montre sur la map"
  // (alertes). On accepte un center initial pour atterrir centré sur un
  // report précis. Null → comportement par défaut (centrer sur le user).
  //
  // v23.1 part 240 — Daniel : "quand on met voir la carte pour quoi tu met
  // suivre balade une nouvelle map au lieu dutiliser la paw map et je vois
  // le halo vert si c un walker ou halo bleu si c un sitter". Ajout de
  // focusUserId/Role/Name : quand un chat ouvre la PawMap, on passe ces
  // params pour injecter une FriendPosition synthetique dans le service
  // LiveMapService → le halo vert/bleu se dessine automatiquement (cf
  // _buildHaloCircles plus bas qui lit _liveMap.friendPositions).
  //
  // v552 — Daniel : « quand on partage un lien, que ça tombe sur la chose
  // précise ». Un lien /spot/<id> ou /alert/<id> ouvre désormais la carte
  // CENTRÉE sur l'élément, avec sa fiche ouverte — au lieu d'atterrir sur
  // une carte générique.
  const PawMapScreen({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialZoom,
    this.focusUserId,
    this.focusUserRole,
    this.focusUserName,
    this.focusSpotId,
    this.focusReportId,
    this.routeToLat,
    this.routeToLng,
  });
  final double? initialLat;
  final double? initialLng;
  final double? initialZoom;
  final String? focusUserId;
  final String? focusUserRole; // 'walker' | 'sitter' | 'owner'
  final String? focusUserName;
  /// Id d'un PawSpot partagé : la carte s'y centre et ouvre sa fiche.
  final String? focusSpotId;
  /// Id d'un signalement (ou SOS) partagé : même principe.
  final String? focusReportId;
  /// v559 — Daniel : « que les nouvelles fonctionnalités marchent aussi pour
  /// le suivi, les adresses… ». Un autre écran (ami en direct, balade suivie,
  /// adresse partagée dans le chat) ouvre la carte AVEC un itinéraire déjà
  /// lancé vers ce point (modes à pied / vélo / voiture + virages).
  final double? routeToLat;
  final double? routeToLng;

  @override
  State<PawMapScreen> createState() => _PawMapScreenState();
}

class _PawMapScreenState extends State<PawMapScreen>
    with WidgetsBindingObserver {
  /// v584 — LE contrôleur de LA carte (une seule GoogleMap depuis la fusion
  /// du lot C : plus de calque agrandi avec son propre contrôleur).
  final Completer<GoogleMapController> _mapCtl = Completer();
  late final PawMapController _poiController;
  late final MapReportController _reportController;
  late final FriendController _friendController;
  late final LiveMapService _liveMap;
  // v23.1 part 249 — service marker custom avec photo profil + ring.
  /// v584 — cache des épingles de la légende (dessinées une fois) + photos.
  late final PawMapPinCache _pins;
  // Paris fallback by default — guarantees the GoogleMap widget always has
  // a camera position on the very first frame, even before geolocation
  // resolves. This fixes the "need to tap twice to see the map" bug caused
  // by IndexedStack keeping the screen built-but-hidden.
  /// v577 — Daniel : « des fois quand tu ouvres la carte ça te met à Paris
  /// avant ta position ». La carte partait TOUJOURS de Paris en dur, puis
  /// sautait sur la vraie position dès que le GPS répondait — plusieurs
  /// secondes sur un téléphone lent, et le saut se revoyait à chaque fois que
  /// l'écran était reconstruit. On repart maintenant du DERNIER endroit
  /// regardé, enregistré sur l'appareil ; Paris ne sert plus qu'au tout
  /// premier lancement, avant toute position connue.
  /// v584 (lot C, légende validée le 23/09) — le ZOOM est retenu avec le
  /// centre, et Paris n'est plus qu'un ultime repli : avant toute position
  /// connue, on part de la ville du profil (coordonnées enregistrées à
  /// l'inscription) — donc jamais « Paris » pour quelqu'un de Dallas.
  LatLng _currentCenter = _restoreLastCenter();

  static const String _kLastCenterKey = 'pawmap_last_center';

  /// Règles pures dans `PawMapCameraMemory` (testées) ; ici on ne fait que
  /// lire le stockage local.
  static LatLng _restoreLastCenter() {
    dynamic raw;
    Map<String, dynamic>? profile;
    try {
      raw = GetStorage().read(_kLastCenterKey);
      profile = GetStorage().read<Map<String, dynamic>>(StorageKeys.userProfile);
    } catch (_) {/* stockage indisponible : repli */}
    return PawMapCameraMemory.centerFrom(raw, profile);
  }

  static double _restoreLastZoom() {
    dynamic raw;
    try {
      raw = GetStorage().read(_kLastCenterKey);
    } catch (_) {/* stockage indisponible */}
    return PawMapCameraMemory.zoomFrom(raw);
  }

  /// Enregistre centre + zoom. Appelé quand la caméra S'ARRÊTE (jamais à
  /// chaque image d'un glissement : consigne du 23/09) et après le recentrage
  /// GPS du lancement.
  static void _saveLastCamera(LatLng c, double zoom) {
    try {
      GetStorage().write(_kLastCenterKey, PawMapCameraMemory.encode(c, zoom));
    } catch (_) {/* best effort */}
  }

  // v463 — Daniel : « agrandir la carte ». Mode carte agrandie = un CALQUE
  // plein écran posé PAR-DESSUS la PawMap normale (laquelle reste montée et
  // INTACTE en dessous : sa GoogleMap n'est JAMAIS redimensionnée ni détruite
  // → zéro risque de carte blanche au retour, contrairement aux tentatives
  // v451/v458 qui cachaient les panneaux et redimensionnaient la carte). Le
  // calque possède sa PROPRE GoogleMap plein écran (instance dédiée, créée à
  // la bonne taille comme l'écran plein écran v457 qui marchait). false par
  // défaut = comportement actuel inchangé.
  // v465 — réf. à l'état GLOBAL partagé : le wrapper de navigation l'observe
  // pour MASQUER le menu du bas en mode agrandi (sinon Signaler / Tag Spot /
  // bandeaux de validation restent cachés derrière le menu).


  /// v23.1.149 — Daniel : "paw map rien napparait le point de geolocolisation
  /// ou le halo nest pas la". `myLocationEnabled: true` du GoogleMap dépend
  /// d'une permission OS qui peut être refusée silencieusement → aucun point
  /// bleu visible. Pour garantir la visibilité, on superpose notre propre
  /// marker + halo dès que la géolocalisation a été résolue avec succès
  /// (LocationService.getCurrentLocation OK). Null = pas encore résolu, on
  /// n'affiche rien.
  LatLng? _userPosition;

  /// Layer toggles — by default all visible. The Demandes toggle is only
  /// rendered for sitter/walker roles (it stays true internally but the UI
  /// hides it for owners).
  final RxBool _showPois = true.obs;
  // v23.1.189 — Daniel : "sur map autour de vous quon puisse le fermer".
  // Bouton X qui hide la card "Autour de vous" pour cette session.
  // v23.1 part 251 — Daniel : "Autour de vous qd on ferme et on revien sur
  // la map reapparait". Root cause : _aroundYouVisible etait un champ
  // d'INSTANCE qui se reinitialisait a true a chaque remount du State
  // (quitter/revenir sur l'onglet map recree le State). On le backe par
  // un flag STATIC qui survit aux remounts pendant toute la session app :
  // une fois ferme, la card reste fermee meme apres navigation. Reset au
  // restart de l'app (nouvelle session, nouveaux signalements).
  // v488 — Daniel : « enlève le pop-up "Signaler autour de moi" à chaque
  // connexion ». La carte « Autour de vous » ne s'affiche plus
  // automatiquement (défaut masqué) ; l'accès aux signalements proches se
  // fera via le bouton rond « Voir signaux » (→ AlertsScreen).
  static bool _aroundYouDismissedSession = true;
  late final RxBool _aroundYouVisible =
      (!_aroundYouDismissedSession).obs;

  // v23.1.190 — Daniel : "pour les signalement au lieu de halo rouge
  // emoji du signalement". Cache BitmapDescriptor par type de report,
  // pre-calcule a partir des emojis (ReportTypes.emoji). _buildMarkers
  // consulte ce cache pour rendre des markers emoji ronds au lieu des
  // pins teardrop colorés.
  final Map<String, BitmapDescriptor> _reportEmojiMarkers = {};
  bool _emojiMarkersReady = false;
  // v584 — les lieux, spots, membres et groupes sont dessinés par
  // `PawMapPinPainter` (légende du 23/09) et gardés dans `_pins`.
  // Membre actuellement sélectionné (tap) → état « sélectionné ». null = aucun.
  String? _selectedNearbyId;
  /// v584 — mes propres demandes (propriétaire) : bulles « Ma demande ».
  final RxList<NearbyRequestPost> _myRequests = <NearbyRequestPost>[].obs;
  /// v586 — « qui me voit sur la carte » : UNE vérité à 3 états
  /// ('all' | 'friends' | 'hidden'), `MapPrefsService.mapVisibility`, la même
  /// que Profil › Préférences et le site. Plus de copie locale ici.
  String get _visibility => _prefs.mapVisibility.value;
  bool get _friendsOnly => _visibility != 'all';
  /// v584 — idée 4 : filtre « Disponible aujourd'hui ».
  final RxBool _availableTodayOnly = false.obs;
  // v591 — Daniel : « le pop-up Filtres actifs, qu'il disparaisse ». Visible
  // 5 s à l'ouverture et après chaque changement de filtre, puis replié en
  // pastille sur le bouton Réglages (« Tout afficher » reste dans le panneau).
  final RxBool _filtersBannerShown = true.obs;
  Timer? _filtersBannerTimer;
  Worker? _filtersBannerWorker;
  bool get _filtersHidePeople =>
      _memberRoles.length < 3 ||
      !_showFriends.value ||
      !_showProviders.value ||
      _availableTodayOnly.value;
  // v591 — rayon de chargement des PawSpots = zone visible (≈ 40 000 km / 2^zoom
  // de large → on prend les ¾ comme rayon), borné 25-300 km.
  double get _spotRadiusM =>
      (40000 / math.pow(2, _zoomLevel.clamp(1, 20)) * 0.75 * 1000)
          .clamp(25000, 300000)
          .toDouble();
  void _flashFiltersBanner() {
    _filtersBannerShown.value = true;
    _filtersBannerTimer?.cancel();
    _filtersBannerTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) _filtersBannerShown.value = false;
    });
  }
  /// v584 — idée 8 : les membres à moins de 50 km (compteur cliquable).
  List<Map<String, dynamic>> _aroundMembers = const [];
  final RxBool _showReports = true.obs;
  final RxBool _showFriends = true.obs;
  final RxBool _showRequests = true.obs;
  // v23.1.285 — Daniel : "améliore le menu de la pawmap comme la photo".
  // Filtre catégories POI en CHECKLIST repliable (au lieu des puces qui
  // défilaient horizontalement). _showCatFilter = panneau ouvert/fermé.
  final RxBool _showCatFilter = false.obs;

  // v23.1.263 — Daniel : "le follow géolocalise mais ne suit pas à la trace".
  // Mode SUIVI LIVE : quand on tape un ami sur la carte (ou qu'on ouvre la map
  // en "voir la balade" depuis un chat), on zoome au plus près et la caméra
  // RECENTRE automatiquement à chaque nouvelle position socket
  // (map:friend-position). `_followUserId == null` ⇒ pas de suivi.
  // `_suppressFollowAutoStop` = true pendant NOS propres animations caméra,
  // pour ne pas confondre un recentrage auto avec un drag manuel de l'user.
  String? _followUserId;
  String _followName = '';
  Worker? _followWorker;
  Worker? _followEndWorker;
  // v23.1.294 — worker de suivi de MA position quand « Me suivre » est actif.
  Worker? _myFollowWorker;
  /// v584 — zoom de suivi « joli » (Daniel, 23/09) : rue lisible, 16-17.
  static const double _followZoom = 16.5;
  /// Suivi mis en PAUSE par un geste (le tracé continue) ; « Reprendre ».
  bool _followPaused = false;
  /// Tracé violet PawFollow derrière la personne suivie.
  List<LatLng> _followTrail = const <LatLng>[];

  // v23.1.266 — Daniel : "un bouton discret pour une vue satellite". Type de
  // carte togglable normal ↔ hybride (satellite + rues/labels).
  MapType _mapType = MapType.normal;
  /// v552 — mode nuit de la CARTE (spec v3, dock bas). N'affecte que le style
  /// Google Maps, pas le thème de l'app (qui a son propre réglage).
  final RxBool _nightMode = false.obs;
  // v592 — fond de carte détaillé du site (OpenStreetMap) par-dessus Google.
  // Activé par défaut ; interrupteur dans « Calques ». Nuit et satellite
  // gardent Google (les tuiles OSM sont claires et sans vue aérienne).
  final RxBool _osmBase =
      (GetStorage().read('pawmap_osm_base') as bool? ?? true).obs;
  static final PawOsmTileProvider _osmTiles = PawOsmTileProvider();
  bool get _osmActive =>
      _osmBase.value && !_nightMode.value && _mapType == MapType.normal;

  /// Nearby reservation requests for the sitter/walker layer. Fetched in
  /// `_reloadAtCenter()` via `/posts/requests/nearby`. Empty for owner role.
  final RxList<NearbyRequestPost> _requests = <NearbyRequestPost>[].obs;

  /// v23.1 part 72 — Bug 10 : nearby walkers/sitters with their boost flag.
  /// Owners see them as map markers — boosted ones get a bigger gold pin
  /// (PawSpot) so paying actually translates to map visibility.
  final RxList<Map<String, dynamic>> _nearbyProviders = <Map<String, dynamic>>[].obs;
  // v548 — Daniel : « quand on dézoome, voir TOUS les utilisateurs sur la
  // carte mondiale ». Couche MONDE : tous les membres géolocalisés (position
  // approximative ~1 km, pas de statut en ligne), visible par tout membre
  // connecté, abonné ou non. Chargée une fois (cache serveur 5 min).
  final RxList<Map<String, dynamic>> _worldMembers = <Map<String, dynamic>>[].obs;
  bool _worldMembersLoaded = false;
  /// v550 — révision de la couche monde. La clé du cache markers ne
  /// contenait AUCUNE trace de `_worldMembers` : quand la liste arrivait
  /// (après le 1er build), le cache n'était pas invalidé → les membres roses
  /// n'apparaissaient jamais sur mobile alors qu'ils s'affichaient sur le web.
  int _worldRev = 0;
  /// v550 — vrai pendant un geste caméra (pan/zoom). On gèle le tick halo :
  /// plus aucun rebuild de la GoogleMap pendant que le doigt bouge la carte.
  bool _cameraMoving = false;
  /// v550 — zoom courant, utilisé pour plafonner le nombre de membres de la
  /// couche monde affichés (au dézoom mondial, on garde les plus proches du
  /// centre : des milliers de markers figent Google Maps sur mobile).
  double _zoomLevel = _restoreLastZoom();
  /// v550 — dernier centre réellement rechargé (voir `_scheduleReload`).
  LatLng? _lastReloadCenter;
  // v591 — rayon des PawSpots au dernier chargement (dézoom sans déplacement).
  double _lastSpotRadiusM = 25000;
  // v584 — la couleur du rôle s'affiche À TOUS LES ZOOMS (légende du 23/09 :
  // fini le rose fluo dézoomé). Plus de seuil `_roleColorZoom`.
  /// v551 — Daniel : « filtres par type, joli et minimaliste, pas de slide ».
  /// Rôles de membres affichés sur la carte (tous par défaut).
  final RxSet<String> _memberRoles = <String>{'sitter', 'walker', 'owner'}.obs;
  /// Nombre de membres réellement posés sur la carte au dernier rendu
  /// (alimente la ligne « N membres autour de toi »).
  final RxInt _membersShown = 0.obs;
  final RxBool _showProviders = true.obs;

  /// v23.1.353 — refonte PawSpot : couche des spots communautaires 🐾.
  /// OFF par défaut ; le chip doré « PawSpot 🐾 » de la barre de filtres
  /// la toggle (gated par le flag benefits.pawspotActive).
  late final PawSpotController _pawSpotController;
  final RxBool _showPawSpots = false.obs;

  /// v23.1.356 — maquette Daniel : switch « PawFollow » de la rangée de
  /// boutons rapides. ON par défaut ; OFF masque la couche LIVE (markers +
  /// halos amis/famille et mon marqueur/halo). POIs, signalements et
  /// prestataires ne sont pas affectés.
  final RxBool _showLiveLayer = true.obs;

  /// v448 — Daniel : « selon son abonnement, on peut couper l'affichage manuel
  /// on/off ». Couche Paw Premium = les halos OR des membres Paw Premium. ON
  /// par défaut quand l'abonnement Premium est actif ; le switch PawPremium de
  /// la rangée rapide la coupe/rallume manuellement (sans toucher à l'abo).
  final RxBool _showPremiumLayer = true.obs;

  /// v23.1.360 — mode VISEUR « Taguer un lieu » : pin rose fixe au centre,
  /// on déplace la carte dessous puis Valider → sheet de création à cette
  /// position exacte (Daniel : "je ne peux pas sélectionner l'endroit").
  final RxBool _pickingSpotPos = false.obs;

  /// v449 — Daniel : « mieux régler l'endroit du signalement, comme Taguer un
  /// lieu mais plus express ». Mode viseur SIGNALEMENT : pin déplaçable (tap sur
  /// la carte) + une seule action « Signaler ici » → ouvre la feuille au point
  /// choisi. Réutilise `_pickedSpotPos` pour stocker le point (un seul viseur
  /// actif à la fois).
  final RxBool _pickingReportPos = false.obs;

  /// v554 — Daniel : « le bouton Itinéraire sur la grande map n'est pas
  /// branché ». Il appelait bien le calcul d'itinéraire, mais vers le CENTRE
  /// de la carte : sans avoir déplacé la carte, départ = arrivée → « recherche
  /// échouée ». On reprend donc le viseur déjà utilisé pour PawSpot et les
  /// signalements : on vise la destination, puis on valide.
  final RxBool _pickingRoutePos = false.obs;

  /// v554 — Daniel : « le bouton à côté (mettre à jour), vérifie qu'il
  /// marche ». Il marchait, mais SANS le moindre signe visible : les couches
  /// se rechargeaient en silence. On montre maintenant un spinner à sa place
  /// pendant le rechargement, puis une confirmation courte.
  final RxBool _refreshing = false.obs;

  /// v23.1.363 — position choisie en TAPANT la carte pendant le mode viseur
  /// (marqueur réel ancré au sol — bien plus précis que le centre écran).
  LatLng? _pickedSpotPos;

  /// v23.1.353 — itinéraire "Y aller" (GET /pawspots/directions). La
  /// polyline orange est dessinée sur la carte ; le bandeau bas affiche la
  /// distance + un bouton pour l'effacer.
  Set<Polyline> _routePolylines = {};
  int? _routeDistanceMeters;
  bool _directionsLoading = false;

  // v559 — Daniel (retour testeur) : itinéraire à pied / vélo / voiture, une
  // couleur par mode, durée réelle, et « mini indications de virage ».
  String _routeMode =
      (GetStorage().read('pawmap_route_mode') as String?) ?? 'walk';
  LatLng? _routeDest;
  int? _routeDurationSeconds;
  List<PawSpotRouteStep> _routeSteps = const [];
  Set<Marker> _routeStepMarkers = {};
  final Map<String, BitmapDescriptor> _routeStepIcons = {};

  static const Map<String, Color> _routeColors = {
    'walk': Color(0xFFC92A12), // orange marque (à pied)
    'bike': Color(0xFF16A34A), // vert (vélo)
    'car': Color(0xFF2563EB), // bleu (voiture)
  };
  Color get _routeColor => _routeColors[_routeMode] ?? _routeColors['walk']!;
  IconData get _routeIcon => _routeMode == 'car'
      ? Icons.directions_car_rounded
      : _routeMode == 'bike'
          ? Icons.directions_bike_rounded
          : Icons.directions_walk_rounded;

  /// Debounce the `onCameraIdle` callback so panning/zooming quickly doesn't
  /// fire 5+ POI/report requests in a row. 500 ms is short enough to feel
  /// instant but long enough to collapse a flick-zoom into one call.
  Timer? _reloadDebounce;

  /// v23.1 part 123 — Daniel : "PawSpot Platinum (30j) doit avoir un halo
  /// animé, là c'est juste un pin doré". Animated halo pulse around every
  /// Platinum-boosted provider. Cycles 0→1 every 2.4s (5 fps, 12 ticks).
  /// Drives Circle radius (50..160m) and opacity (0.45→0) so the marker
  /// looks like a beacon pulsing outward.
  Timer? _haloTimer;
  /// v552 — workers qui forcent le recalcul de `canPop` (retour Android).
  List<Worker> _backGuardWorkers = const [];
  final RxDouble _haloPhase = 0.0.obs;

  // v584 — les halos or Premium / jaune PawSpot sont retirés (légende) : la
  // couronne suffit ; PawFollow = violet fixe ; PawBoost = lueur turquoise
  // dessinée dans l'épingle (PawMapPinPainter).

  /// v23.1 part 243 round 3 — perf : cache des markers (Daniel : "sur
  /// certain portable sa lague"). Le Obx GoogleMap rebuild a chaque tick
  /// halo (600ms), ce qui appelait _buildMarkers() qui re-itere TOUS les
  /// providers/POIs/reports et recree chaque Marker → garbage churn massif
  /// sur low-end. Maintenant on memoize avec une cle qui depend des inputs
  /// reels (lengths + show flags) : si la cle n'a pas change, on reutilise
  /// le Set cache. Le _buildMarkers ne tourne plus que quand la donnee
  /// change vraiment, pas a chaque tick visuel.
  Set<Marker>? _cachedMarkers;
  String _cachedMarkersKey = '';

  /// v500 — Daniel (version Store, installation fraîche) : « les points ne
  /// s'affichent pas, je dois mettre Rien puis Tous ». Le watchdog v352 ne
  /// tournait PAS si la géoloc expirait (early return AVANT le watchdog) —
  /// exactement le cas d'une 1re installation : la boîte de permission +
  /// le 1er fix GPS dépassent les 8s → chargement initial raté et jamais
  /// relancé. Compteur des relances du watchdog (max 3).
  int _firstLoadRetries = 0;

  /// Cached role lookup — read once, used for layer gating and UI.
  String get _role {
    final auth = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>()
        : null;
    return auth?.userRole.value ?? '';
  }

  bool get _isSitterOrWalker => _role == 'sitter' || _role == 'walker';

  /// Controller for the "Chercher une ville" search bar displayed at the
  /// top of the map. On submit, geocodes the city and recenters.
  final TextEditingController _cityCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // v591 — bandeau « Filtres actifs » : 5 s puis pastille (voir _flashFiltersBanner).
    _filtersBannerTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) _filtersBannerShown.value = false;
    });
    _filtersBannerWorker = everAll(
      [_availableTodayOnly, _showFriends, _showProviders, _memberRoles],
      (_) => _flashFiltersBanner(),
    );
    // v465 — on entre toujours en mode NORMAL (jamais bloqué en agrandi).
    // v557 — écrire un Rx pendant initState déclenche « setState() called
    // during build » sur les Obx qui l'écoutent (vu en debug) → différé
    // après la 1re frame.
    if (pawMapExpanded.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        pawMapExpanded.value = false;
      });
    }
    // v23.1 part 243 round 3 — perf : pause _haloTimer quand l'app est
    // en background (Daniel : "sur certain portable sa lague"). Le timer
    // tickait toutes les 600ms meme avec l'app ecran eteint et forcait
    // GoogleMap a rebuild dans le vide. Sur Oppo low-end ca decharge
    // la batterie et fait sauter des frames quand le user revient.
    WidgetsBinding.instance.addObserver(this);
    _poiController = Get.isRegistered<PawMapController>()
        ? Get.find<PawMapController>()
        : Get.put(PawMapController());
    _reportController = Get.isRegistered<MapReportController>()
        ? Get.find<MapReportController>()
        : Get.put(MapReportController());
    _friendController = Get.isRegistered<FriendController>()
        ? Get.find<FriendController>()
        : Get.put(FriendController());
    // v23.1.258 — Daniel : "le badge 1 des demandes d'amis n'apparaît pas".
    // Si le FriendController existait déjà (onInit pas relancé), son
    // incomingRequests pouvait être périmé/vide → badge à 0. On force un
    // refresh à l'ouverture de la PawMap pour que le compteur (et donc le
    // badge sur le bouton "Famille & Amis") soit à jour.
    unawaited(_friendController.refresh());
    // v23.1 part 244d — Daniel : "jai ajouter un walker a ma famille son
    // halo ne cest pas changer". Root cause : la PawMap ne chargait pas
    // la liste famille au mount → familyMembers.isEmpty → isFamily=false
    // pour le walker → outline violet jamais ajoute. Maintenant on force
    // un loadFamily() async au mount. Le halo se redessine ensuite tout
    // seul (Obx + halo tick).
    _friendController.loadFamily();
    // v584 — cache des épingles (permanent : partagé entre les ouvertures de
    // la carte, une épingle n'est dessinée qu'une fois par session).
    _pins = Get.isRegistered<PawMapPinCache>()
        ? Get.find<PawMapPinCache>()
        : Get.put(PawMapPinCache(), permanent: true);
    _liveMap = Get.isRegistered<LiveMapService>()
        ? Get.find<LiveMapService>()
        : Get.put(LiveMapService(), permanent: true);
    _liveMap.attach();

    // v23.1 part 240 — si on ouvre la PawMap pour "suivre" un sitter/walker
    // depuis un chat, on injecte une FriendPosition synthetique pour que
    // le halo vert (walker) ou bleu (sitter) se dessine instantanement
    // autour de sa derniere position connue. Le halo sera ensuite
    // automatiquement rafraichi par les events socket map:friend-position
    // quand le peer bouge.
    if ((widget.focusUserId ?? '').isNotEmpty &&
        widget.initialLat != null &&
        widget.initialLng != null) {
      final role = (widget.focusUserRole ?? '').toLowerCase();
      _liveMap.friendPositions[widget.focusUserId!] = FriendPosition(
        userId: widget.focusUserId!,
        role: role,
        latitude: widget.initialLat!,
        longitude: widget.initialLng!,
        at: DateTime.now(),
      );
    }

    // v23.1.263 — si on ouvre la PawMap pour "suivre" quelqu'un (focusUserId
    // passé depuis un chat / "voir la balade"), on entre directement en mode
    // suivi : la caméra restera collée à sa position.
    if ((widget.focusUserId ?? '').isNotEmpty) {
      _followUserId = widget.focusUserId;
      _followName = widget.focusUserName ?? '';
    }
    // v23.1.263 — Worker de SUIVI "à la trace". Dès qu'une nouvelle position
    // arrive pour l'ami suivi (socket map:friend-position → friendPositions),
    // on recentre la caméra dessus. C'est ce qui manquait : avant, le marker
    // (une fois le cache corrigé) bougeait, mais la caméra restait figée.
    _followWorker = ever<Map<String, FriendPosition>>(
      _liveMap.friendPositions,
      (positions) {
        final uid = _followUserId;
        if (uid == null) return;
        final fp = positions[uid];
        if (fp == null || fp.liveState == FriendLiveState.seen) {
          _endFollowIfGone();
          return;
        }
        final p = LatLng(fp.latitude, fp.longitude);
        // v584 — le tracé s'allonge (violet), même en pause.
        if (_followTrail.isEmpty ||
            _followTrail.last.latitude != p.latitude ||
            _followTrail.last.longitude != p.longitude) {
          _followTrail = <LatLng>[..._followTrail, p];
          if (_followTrail.length > 600) {
            _followTrail = _followTrail.sublist(_followTrail.length - 600);
          }
          if (mounted) setState(() {});
        }
        if (_followPaused) return;
        // v584 — suivi SANS à-coups : la caméra glisse vers la nouvelle
        // position en gardant le zoom (plus de re-zoom à chaque point).
        _animateFollowCamera(p);
      },
    );

    // v584 (25/09, règle c) — l'ami suivi coupe son partage (ou > 10 min
    // sans signal) : le suivi se termine de lui-même, à chaque tick de
    // fraîcheur (30 s) et à chaque changement de la liste.
    _followEndWorker = ever<int>(_liveMap.staleTick, (_) => _endFollowIfGone());

    // v23.1.294 — « Me suivre » : suit MA position à la trace. Quand je diffuse
    // (broadcasting), chaque mise à jour GPS recentre la caméra sur moi, comme
    // une appli de navigation. On ne vole pas la caméra si on suit déjà un ami.
    _myFollowWorker = ever<LatLng?>(
      _liveMap.myLivePosition,
      (pos) {
        if (pos == null) return;
        if (!_liveMap.broadcasting.value) return;
        if ((_followUserId ?? '').isNotEmpty) return;
        _userPosition = pos;
        _animateFollowCamera(pos);
      },
    );

    // v23.1 part 240 — Daniel : "et tu sur que dans le chat qd je met voir
    // carte sa me met sur le map sur la geoloco du sitter ou walker ?".
    // PROBLEME TROUVE : meme en passant initialLat/Lng, le _bootstrap()
    // appelait ensuite getCurrentLocation() et REMPLACAIT _currentCenter
    // par MA position. Resultat : la map s'ouvrait centree sur le sitter
    // pour 1 frame puis se recentrait sur moi. FIX : on initialise
    // _currentCenter ICI a partir des params widget, AVANT que _bootstrap()
    // tourne. Et dans _bootstrap on detecte ce cas pour ne plus override.
    if (widget.initialLat != null && widget.initialLng != null) {
      _currentCenter = LatLng(widget.initialLat!, widget.initialLng!);
    }
    if (widget.initialZoom != null) _zoomLevel = widget.initialZoom!;
    // v552 — lien partagé vers un spot / un signalement précis : on va le
    // chercher, on centre la carte dessus et on ouvre sa fiche.
    if ((widget.focusSpotId ?? '').isNotEmpty ||
        (widget.focusReportId ?? '').isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openSharedTarget());
    }
    // v559 — itinéraire demandé par un autre écran : on attend que la carte
    // et MA position soient prêtes (jusqu'à ~10 s), puis on trace.
    if (widget.routeToLat != null && widget.routeToLng != null) {
      final dest = LatLng(widget.routeToLat!, widget.routeToLng!);
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_startPendingRoute(dest)));
    }
    // v559 — itinéraire confié par un autre écran via l'ONGLET (menu conservé).
    final pending = pawMapPendingRoute.value;
    if (pending != null) {
      pawMapPendingRoute.value = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_startPendingRoute(pending)));
    }
    _pendingRouteWorker = ever<LatLng?>(pawMapPendingRoute, (v) {
      if (v == null || !mounted) return;
      pawMapPendingRoute.value = null;
      unawaited(_startPendingRoute(v));
    });
    // v584 — lien partagé / page de ville : la carte se centre sur l'endroit
    // demandé (onglet conservé), au zoom demandé.
    final pendingCenter = pawMapPendingCenter.value;
    if (pendingCenter != null) {
      pawMapPendingCenter.value = null;
      _currentCenter = pendingCenter;
      _zoomLevel = pawMapPendingZoom.value;
    }
    _pendingCenterWorker = ever<LatLng?>(pawMapPendingCenter, (v) {
      if (v == null || !mounted) return;
      pawMapPendingCenter.value = null;
      unawaited(_goToCity(v, zoom: pawMapPendingZoom.value));
    });
    // v588 — un ami touché dans la liste d'amis (photo ou ligne) : la carte
    // vole sur lui (zoom 16), ouvre sa fiche courte, le suit s'il est en
    // direct. Le bootstrap ne recentre alors plus sur MA position.
    final pendingFriend = pawMapPendingFriend.value;
    if (pendingFriend != null) {
      pawMapPendingFriend.value = null;
      _friendFocusRequested = true;
      _currentCenter = LatLng(pendingFriend.lat, pendingFriend.lng);
      _zoomLevel = kPawMapFriendFocusZoom;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => unawaited(_focusFriend(pendingFriend)));
    }
    _pendingFriendWorker = ever<PawMapFriendFocus?>(pawMapPendingFriend, (v) {
      if (v == null || !mounted) return;
      pawMapPendingFriend.value = null;
      _friendFocusRequested = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => unawaited(_focusFriend(v)));
    });
    // v23.1.353 — refonte PawSpot : les anciens halos "map boost" (tier
    // bronze/silver/gold/platinum + self-halo) sont SUPPRIMÉS de la carte.
    // PawSpot = désormais les spots communautaires 🐾 (couche dédiée,
    // chip doré dans la barre de filtres). Le MapBoostController n'est
    // donc plus initialisé ici.
    _pawSpotController = Get.isRegistered<PawSpotController>()
        ? Get.find<PawSpotController>()
        : Get.put(PawSpotController());
    // Pré-charge le flag benefits.pawspotActive (gate du chip PawSpot).
    // v23.1.371 — Daniel : "laisse PawSpot en ON quand j'ai l'abonnement,
    // OFF seulement si je l'éteins manuellement". Abonné + pas d'OFF
    // mémorisé → la couche s'allume toute seule à chaque ouverture de la
    // carte ; le choix manuel (ON/OFF) est persisté dans GetStorage.
    unawaited(_pawSpotController.refreshBenefits().then((active) {
      if (!mounted || !active || _showPawSpots.value) return;
      // v552 — mode nuit de la carte mémorisé d'une session à l'autre.
      _nightMode.value = GetStorage().read('pawmap_night_mode') == true;
      final stored = GetStorage().read('pawspot_layer_on');
      if (stored != false) {
        _showPawSpots.value = true;
        unawaited(_pawSpotController.loadNearby(_currentCenter, radiusM: _spotRadiusM));
      }
    }));

    // v23.1 part 123 — halo pulse pour Platinum.
    // v23.1 part 231 — Daniel : "app lag sur Oppo / petits ecrans".
    // Reduce frequency 200ms → 600ms (5x/sec → ~1.7x/sec). Le halo
    // pulse reste visible mais le main thread est 3x moins solicite
    // par les rebuilds Google Maps Circle. Aussi : 12 → 8 steps pour
    // un cycle complet plus court (visuellement equivalent).
    _haloTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (!mounted || _cameraMoving) return;
      _haloPhase.value = (_haloPhase.value + 1.0 / 8.0) % 1.0;
    });

    // v552 — `canPop` du PopScope est calculé DANS build() : sans ce worker,
    // agrandir la carte ne le recalculait pas et le retour Android quittait
    // quand même l'app (bug n°1 de la spec v3).
    _backGuardWorkers = [

      ever<bool>(_pickingSpotPos, (_) {
        if (mounted) setState(() {});
      }),
      ever<bool>(_pickingReportPos, (_) {
        if (mounted) setState(() {});
      }),
      ever<bool>(_pickingRoutePos, (_) {
        if (mounted) setState(() {});
      }),
    ];

    // v584 — préférences de la carte : copie locale tout de suite, puis le
    // compte (rail, calques, mode nuit, « je cherche »…), et tout changement
    // repart vers le compte (MapPrefsService). Feuille glissante observée
    // pour retirer les rails quand elle monte.
    _applyPrefs(fromAccount: false);
    _watchPrefs();
    _sheetCtl.addListener(_onSheetMoved);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_prefs.loadFromAccount().then((remoteNewer) {
        if (!mounted) return;
        if (remoteNewer) _applyPrefs(fromAccount: true);
        if (mounted) setState(() {});
      }));
      _maybeStartCoach();
      _maybeAnnounce();
    });

    // Paris fallback is the initial value — the map renders immediately
    // and _bootstrap() upgrades to real location in the background.
    _bootstrap();

    // v23.1.190 — pre-warm le cache emoji markers en background. Quand
    // pret, setState force le rebuild des markers map.
    _prewarmEmojiMarkers();
  }

  /// v23.1.190 — Daniel : "pour les signalement au lieu de halo rouge
  /// emoji du signalement". Genere les BitmapDescriptors emoji pour les
  /// 9 types de report (free + premium). Le rendu en bitmap est async
  /// (Canvas → toImage → toByteData → fromBytes) donc on pre-warm le
  /// cache UNE FOIS au mount.
  Future<void> _prewarmEmojiMarkers() async {
    // v23.1.300 — Daniel : "quand je mets pipi / nourriture etc, c'est un halo
    // jaune au lieu de l'emoji". CAUSE : on ne pré-générait QUE 9 types ; tous
    // les autres (pee, food, trash, poison, construction, wildlife...) tombaient
    // sur le pin teardrop coloré par défaut. On pré-warme désormais TOUS les
    // types (ReportTypes.all) → chaque signalement affiche bien son emoji.
    for (final t in ReportTypes.all) {
      try {
        final bd = await _buildEmojiBitmap(ReportTypes.emoji(t));
        _reportEmojiMarkers[t] = bd;
      } catch (e) {
        debugPrint('[PawMap] emoji marker $t failed: $e');
      }
    }
    if (mounted) {
      setState(() => _emojiMarkersReady = true);
    }
  }

  /// v23.1.300 — filet de sécurité : génère à la volée l'emoji d'un type de
  /// report pas encore en cache (pré-warm en cours, ou type renvoyé par le
  /// serveur qui ne serait pas dans ReportTypes.all). Évite qu'un signalement
  /// reste affiché avec le pin coloré par défaut au lieu de son emoji.
  final Set<String> _emojiGenInProgress = {};
  void _ensureEmojiMarker(String type) {
    if (_reportEmojiMarkers.containsKey(type) ||
        _emojiGenInProgress.contains(type)) {
      return;
    }
    _emojiGenInProgress.add(type);
    _buildEmojiBitmap(ReportTypes.emoji(type)).then((bd) {
      _reportEmojiMarkers[type] = bd;
      _emojiGenInProgress.remove(type);
      if (mounted) setState(() {});
    }).catchError((Object _) {
      _emojiGenInProgress.remove(type);
    });
  }

  // ─── v551 — REGROUPEMENT DES POINTS (clusters) ───────────────────────────
  // Daniel : « la carte est illisible quand tout se chevauche ». Les points
  // trop proches à l'écran fusionnent en UNE pastille avec le nombre ; un tap
  // zoome dessus et le groupe s'ouvre. Calcul en pixels Web Mercator au zoom
  // courant → le regroupement suit exactement ce que l'œil voit.
  static const double _clusterCellPx = 76;
  /// v576 — les MEMBRES se regroupent dans une cellule plus fine que les
  /// lieux : c'est le regroupement, pas le seuil de zoom, qui cachait la
  /// couleur de rôle (une pastille rose « 3 » reste rose quel que soit le
  /// zoom). Avec 44 px, les badges colorés se séparent environ un cran de
  /// zoom plus tôt, sans rendre la carte illisible.
  static const double _memberClusterCellPx = 44;

  double _mercX(double lng) => (lng + 180.0) / 360.0 * 256.0;
  double _mercY(double lat) {
    final s = math.sin(lat * math.pi / 180.0).clamp(-0.9999, 0.9999);
    return (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * 256.0;
  }

  /// Regroupe [items] par cellule d'écran. Renvoie des groupes non vides.
  List<List<T>> _clusterize<T>(
    List<T> items,
    LatLng Function(T) posOf, {
    double cellPx = _clusterCellPx,
  }) {
    final scale = math.pow(2.0, _zoomLevel).toDouble();
    final cells = <String, List<T>>{};
    for (final it in items) {
      final p = posOf(it);
      final x = _mercX(p.longitude) * scale / cellPx;
      final y = _mercY(p.latitude) * scale / cellPx;
      final key = '${x.floor()}_${y.floor()}';
      (cells[key] ??= <T>[]).add(it);
    }
    return cells.values.toList();
  }

  LatLng _centroid<T>(List<T> group, LatLng Function(T) posOf) {
    double la = 0, ln = 0;
    for (final g in group) {
      final p = posOf(g);
      la += p.latitude;
      ln += p.longitude;
    }
    return LatLng(la / group.length, ln / group.length);
  }



  /// Tap sur une pastille de groupe : zoom doux dessus jusqu'à séparer les
  /// épingles ; v584 (25/09, point 15) — si elles restent superposées au
  /// zoom max (≥ 17,5), une petite feuille liste le groupe (photo, prénom,
  /// rôle / type, « Voir »).
  Future<void> _zoomToCluster(
    LatLng target, {
    List<Map<String, dynamic>> members = const [],
    List<MapPOI> places = const [],
    List<PawSpotModel> spots = const [],
  }) async {
    if (!mounted) return;
    // v585 (25/09, Daniel : « ça zoome et c'est tout ; il faut que ça me
    // montre les deux rôles ») — si le zoom ne séparerait rien (points
    // superposés, ou une seule personne à plusieurs rôles), la liste tout de
    // suite ; le zoom ne sert que si les points se séparent vraiment.
    final superposed = pawMapClusterIsStacked(
      members.map(pawMapMemberLatLng).whereType<LatLng>().toList(),
      samePerson: pawMapSamePerson(members),
    );
    if (_zoomLevel >= 17.5 || (superposed && places.isEmpty && spots.isEmpty)) {
      _openClusterList(members: members, places: places, spots: spots);
      return;
    }
    final ctl = await _activeMapCtl();
    if (ctl == null) return;
    // v592 — un toucher doit SUFFIRE à séparer le groupe : on cadre la carte
    // sur tous ses points (avant : +2,2 niveaux, il fallait toucher 3-4 fois).
    final pts = <LatLng>[
      ...members.map(pawMapMemberLatLng).whereType<LatLng>(),
      ...places.map((p) => LatLng(p.latitude, p.longitude)),
      ...spots.map((s) => LatLng(s.lat, s.lng)),
    ];
    if (pts.length >= 2) {
      double s0 = pts.first.latitude, n0 = s0, w0 = pts.first.longitude, e0 = w0;
      for (final p in pts) {
        s0 = math.min(s0, p.latitude);
        n0 = math.max(n0, p.latitude);
        w0 = math.min(w0, p.longitude);
        e0 = math.max(e0, p.longitude);
      }
      // Points (quasi) superposés : la liste plutôt qu'un zoom inutile.
      if ((n0 - s0).abs() < 0.00005 && (e0 - w0).abs() < 0.00005) {
        _openClusterList(members: members, places: places, spots: spots);
        return;
      }
      try {
        await ctl.animateCamera(CameraUpdate.newLatLngBounds(
          LatLngBounds(southwest: LatLng(s0, w0), northeast: LatLng(n0, e0)),
          90,
        ));
        return;
      } catch (_) {/* carte pas encore mesurée : repli ci-dessous */}
    }
    final z = math.min(_zoomLevel + 2.2, 19.0);
    await ctl.animateCamera(CameraUpdate.newLatLngZoom(target, z));
  }

  void _openClusterList({
    required List<Map<String, dynamic>> members,
    required List<MapPOI> places,
    required List<PawSpotModel> spots,
  }) {
    final items = <PawMapClusterItem>[];
    // v585 — une ligne PAR RÔLE pour une personne à plusieurs rôles.
    members = [for (final m in members) ...pawMapExpandRoles(m)];
    for (final p in members) {
      final role = (p['_role'] ?? '').toString().toLowerCase();
      items.add(PawMapClusterItem(
        id: 'm:${p['id'] ?? p['_id'] ?? ''}',
        title: (p['name'] ?? '').toString(),
        subtitle: () {
          final roleLabel = role == 'walker'
              ? 'pawmap_legend_walker'.tr
              : (role == 'owner' ? 'pawmap_legend_owner'.tr : 'pawmap_legend_sitter'.tr);
          final ll = pawMapMemberLatLng(p);
          final d = _distanceLabelTo(ll?.latitude, ll?.longitude);
          return d.isEmpty ? roleLabel : '$roleLabel · $d';
        }(),
        color: PawMapLegend.roleColor(role),
        avatar: (p['avatar'] ?? '').toString(),
        icon: PawMapLegend.roleIcon(role),
      ));
    }
    for (final poi in places) {
      items.add(PawMapClusterItem(
        id: 'p:${poi.id}',
        title: poi.title,
        subtitle: PoiCategories.label(poi.category),
        color: PawMapLegend.placeColor(poi.category),
        icon: Icons.place_rounded,
      ));
    }
    for (final s in spots) {
      items.add(PawMapClusterItem(
        id: 's:${s.id}',
        title: s.name,
        subtitle: PawSpotTypes.label(s.type),
        color: s.isGolden ? PawMapLegend.gold : PawMapLegend.ink,
        icon: Icons.pets_rounded,
      ));
    }
    if (items.isEmpty) return;
    final n = items.length;
    showPawMapSheet<void>(
      context,
      PawMapClusterList(
        title: members.isNotEmpty
            ? 'pawmap_cluster_members_title'.trParams({'n': '$n'})
            : 'pawmap_cluster_places_title'.trParams({'n': '$n'}),
        items: items,
        onOpen: (it) {
          Navigator.of(context).pop();
          if (it.id.startsWith('m:')) {
            final id = it.id.substring(2);
            final p = members.firstWhereOrNull(
                (m) => (m['id'] ?? m['_id'] ?? '').toString() == id);
            if (p == null) return;
            final loc = p['location'] is Map ? p['location'] as Map : null;
            final c = loc != null && loc['coordinates'] is List ? loc['coordinates'] as List : null;
            _onNearbyTap(
              id: id,
              role: (p['_role'] ?? '').toString().toLowerCase(),
              name: (p['name'] ?? '').toString(),
              online: p['isOnline'] != false && p['online'] != false,
              premium: p['isPremium'] == true,
              lat: c != null && c.length >= 2 ? (c[1] as num).toDouble() : null,
              lng: c != null && c.length >= 2 ? (c[0] as num).toDouble() : null,
              avatar: (p['avatar'] ?? '').toString(),
              approx: p['approx'] == true,
              approxKm: (p['approxKm'] as num?)?.toDouble() ?? 1.0,
              rating: (p['rating'] as num?)?.toDouble() ?? 0,
              reviewsCount: (p['reviewsCount'] as num?)?.toInt() ?? 0,
              priceFrom: (p['priceFrom'] as num?)?.toDouble() ?? 0,
              currency: (p['currency'] ?? 'EUR').toString(),
              verified: p['kycVerified'] == true,
              boosted: p['isBoosted'] == true,
              availableToday: p['availableToday'] == true,
              isFriend: p['isFriend'] == true,
              personIds: pawMapPersonIds(p),
            );
          } else if (it.id.startsWith('p:')) {
            final poi = places.firstWhereOrNull((x) => x.id == it.id.substring(2));
            if (poi != null) _showPoiBottomSheet(poi);
          } else {
            final s = spots.firstWhereOrNull((x) => x.id == it.id.substring(2));
            if (s != null) _showPawSpotDetail(s);
          }
        },
      ),
    );
  }

  /// v584 — fiche COURTE d'un membre (LEGENDE_PAWMAP.md, « Réserver en
  /// touchant un utilisateur ») : 1er appui = cette fiche (photo, prix,
  /// étoiles, « Identité vérifiée », dispo aujourd'hui) avec un gros bouton
  /// « Réserver » à sa couleur de rôle ; 2e appui = directement l'écran de
  /// réservation (pas le profil), animal et service pré-remplis. « Voir le
  /// profil » reste un lien. Propriétaire → « Proposer mes services » s'il a
  /// une demande, sinon « Ajouter en ami » / « Message ». Sans compte →
  /// inscription, puis retour.
  /// v565 — l'état de la demande d'ami est relu depuis le serveur à
  /// l'ouverture (jamais une liste périmée).
  bool _memberSheetRefreshed = false;

  bool get _viewerLoggedIn =>
      (SecureTokenStore.currentToken() ?? '').isNotEmpty;

  /// v585 — [serverFriend] : drapeau `isFriend` du serveur (calculé sur TOUS
  /// les profils des deux personnes), lu EN PREMIER ; [personIds] : tous les
  /// ids de rôle du membre (l'amitié a pu être nouée sous un autre rôle).
  PawFriendState _relationState(String uid,
      {bool serverFriend = false, List<String> personIds = const []}) {
    final ids = {uid, ...personIds}.where((x) => x.isNotEmpty).toList();
    return pawMapRelationState(
      serverFriend: serverFriend,
      isFriend: _friendController.isFriendWithAny(ids),
      sent: ids.any(_friendController.hasPendingRequestTo),
      incoming: ids.any((x) => _friendController.incomingRequestFrom(x) != null),
    );
  }

  String _distanceLabelTo(double? lat, double? lng) {
    final me = _userPosition;
    if (me == null || lat == null || lng == null) return '';
    final d = _distanceKm(me, LatLng(lat, lng));
    if (d < 1) return '${(d * 1000).round()} m';
    return '${d.toStringAsFixed(1)} km';
  }

  void _onNearbyTap({
    required String id,
    required String role,
    required String name,
    required bool online,
    required bool premium,
    double? lat,
    double? lng,
    String avatar = '',
    bool approx = false,
    double approxKm = 1,
    double rating = 0,
    int reviewsCount = 0,
    double priceFrom = 0,
    String currency = 'EUR',
    bool verified = false,
    bool boosted = false,
    bool availableToday = false,
    bool isFriend = false,
    // v585 — tous les ids de rôle de la personne (amitié nouée sous un autre).
    List<String> personIds = const [],
    // v584 (25/09) — ami en direct (`live` / `lost`) → « Suivre la balade ».
    PawFollowState? liveState,
    // Dernier signe de vie connu (ami sans partage) → « vu il y a X ».
    DateTime? lastSeenAt,
    // v589 — vrai quand l'appel vient d'un ROND de la carte (toucher en deux
    // temps) ; depuis une liste, la fiche s'ouvre tout de suite.
    bool fromMarker = false,
  }) {
    // v589 — Daniel : « quand je clique sur un ami ou un utilisateur, ça
    // zoome sur lui (pour le suivre par exemple), et si je retouche, voir le
    // profil sort ». 1er toucher = la carte vole sur lui (zoom rue) et le
    // sélectionne ; 2e toucher sur le MÊME rond (dans les 30 s) = sa fiche.
    final now = DateTime.now();
    final bool secondTap = _focusTapId == id &&
        _focusTapAt != null &&
        now.difference(_focusTapAt!) < const Duration(seconds: 30);
    if (fromMarker && !secondTap && lat != null && lng != null) {
      // v590 — handoff §2/§4 : zoom + CARTE FOCUS (Profil › / ✕).
      final String dist = approx ? '' : _distanceLabelTo(lat, lng);
      final String price = (role == 'sitter' || role == 'walker') &&
              priceFrom > 0 &&
              pawMapShowsPriceBubble(_role, role)
          ? CurrencyHelper.formatCompact(currency, priceFrom)
          : '';
      final bool walking = liveState == PawFollowState.live;
      final String info = [
        if (walking) 'pawmap590_focus_walking'.tr,
        if (price.isNotEmpty) price,
        if (dist.isNotEmpty) dist,
        if (!walking && price.isEmpty && dist.isEmpty)
          'pawmap590_role_$role'.tr,
      ].join(' · ');
      _selectedNearbyId = id;
      _focusFirstTap(
        LatLng(lat, lng),
        PawFocusInfo(
          key: id,
          name: name,
          role: role,
          info: info,
          avatar: avatar,
          live: walking,
          friend: isFriend,
          onOpen: () => _onNearbyTap(
            id: id,
            role: role,
            name: name,
            online: online,
            premium: premium,
            lat: lat,
            lng: lng,
            avatar: avatar,
            approx: approx,
            approxKm: approxKm,
            rating: rating,
            reviewsCount: reviewsCount,
            priceFrom: priceFrom,
            currency: currency,
            verified: verified,
            boosted: boosted,
            availableToday: availableToday,
            isFriend: isFriend,
            personIds: personIds,
            liveState: liveState,
            lastSeenAt: lastSeenAt,
          ),
        ),
      );
      if (!_focusHintShown && mounted) {
        _focusHintShown = true;
        PawSignal.show(context, isFriend ? PawSignalKind.friends : PawSignalKind.all,
            'pawmap589_tap_again'.tr);
      }
      return;
    }
    _clearFocus();
    _focusTapId = null;
    _focusTapAt = null;
    _selectedNearbyId = id;
    _memberSheetRefreshed = false;
    if (mounted) setState(() {});
    final bool onlineNow = _liveMap.isOnline(id) ?? online;
    final bool friendNow = isFriend ||
        _friendController.isFriendWithAny({id, ...personIds});
    // Un ami qui partage en ce moment : même sans passer par son rond live.
    final livePos = _liveMap.friendPositions[id];
    final PawFollowState? liveNow = liveState ??
        (friendNow && livePos != null && livePos.liveState != FriendLiveState.seen
            ? (livePos.isLost ? PawFollowState.lost : PawFollowState.live)
            : null);
    final DateTime? seenAt = lastSeenAt ?? livePos?.seenAt;
    final String seenLabel = seenAt == null ? '' : _timeAgo(seenAt);
    var rates = <PawMapRateLine>[];
    final bool hasOpenRequest = role == 'owner' &&
        _requests.any((r) => r.ownerId == id);
    final member = PawMapMemberData(
      id: id,
      role: role,
      name: name,
      avatar: avatar,
      online: onlineNow,
      premium: premium,
      boosted: boosted,
      verified: verified,
      availableToday: availableToday,
      isFriend: friendNow,
      approx: approx,
      approxKm: approxKm,
      rating: rating,
      reviewsCount: reviewsCount,
      priceFrom: priceFrom,
      currency: currency,
      hasOpenRequest: hasOpenRequest,
      distanceLabel: approx ? '' : _distanceLabelTo(lat, lng),
    );
    final priceLabel = priceFrom > 0
        ? CurrencyHelper.formatCompact(currency, priceFrom)
        : '';
    PawFriendState reqState =
        _relationState(id, serverFriend: friendNow, personIds: personIds);
    showPawMapSheet<void>(
      context,
      StatefulBuilder(
        builder: (ctx, setSheet) {
          if (!_memberSheetRefreshed) {
            _memberSheetRefreshed = true;
            unawaited(_friendController.loadRequests().then((_) {
              if (!ctx.mounted) return;
              if (reqState != PawFriendState.busy &&
                  reqState != PawFriendState.error) {
                setSheet(() => reqState = _relationState(id,
                    serverFriend: friendNow, personIds: personIds));
              }
            }));
            // v584 (25/09, point 8) — les tarifs du prestataire, dans SA
            // devise, avant « Réserver » (un appel léger).
            if (role == 'sitter' || role == 'walker') {
              unawaited(_loadProviderRates(id: id, role: role, currency: currency)
                  .then((r) {
                if (!ctx.mounted) return;
                setSheet(() => rates = r.lines);
              }));
            }
          }
          return PawMapMemberSheet(
            member: member,
            viewerRole: _role,
            viewerLoggedIn: _viewerLoggedIn,
            friendState: reqState,
            priceLabel: priceLabel,
            liveState: liveNow,
            seenLabel: seenLabel,
            rates: rates,
            onFollow: liveNow == null
                ? null
                : () {
                    Navigator.of(ctx).pop();
                    unawaited(_sheetTo(PawSheetStop.low));
                    final fp = _liveMap.friendPositions[id];
                    _startFollow(
                      id,
                      fp != null ? LatLng(fp.latitude, fp.longitude) : LatLng(lat ?? 0, lng ?? 0),
                      name,
                      avatar: avatar,
                      role: role,
                    );
                  },
            onSignup: () {
              Navigator.of(ctx).pop();
              SignupWallSheet.show(
                trigger: 'booking',
                name: name,
                recommendedRole: 'pet_owner',
              );
            },
            onBook: () {
              Navigator.of(ctx).pop();
              _bookMember(id: id, role: role, name: name, currency: currency);
            },
            onProfile: () {
              Navigator.of(ctx).pop();
              _openMemberProfile(id: id, role: role, name: name, avatar: avatar);
            },
            onMessage: () {
              Navigator.of(ctx).pop();
              unawaited(_openConversationWith(
                  id: id, role: role, name: name, avatar: avatar));
            },
            onPropose: () {
              Navigator.of(ctx).pop();
              final req = _requests.firstWhereOrNull((r) => r.ownerId == id);
              if (req != null) _showRequestBottomSheet(req);
            },
            onDirections: lat != null && lng != null
                ? () {
                    Navigator.of(ctx).pop();
                    _startDirections(LatLng(lat, lng));
                  }
                : null,
            onFriend: () async {
              if (reqState == PawFriendState.incoming) {
                Navigator.of(ctx).pop();
                _openScreen(() => const FriendsScreen(initialIndex: 1));
                return;
              }
              if (reqState == PawFriendState.friends ||
                  reqState == PawFriendState.sent) {
                return;
              }
              setSheet(() => reqState = PawFriendState.busy);
              // POST /friends/request (même route que l'onglet Amis).
              final err = await _friendController.sendRequest(id, role);
              if (!ctx.mounted) return;
              setSheet(() {
                if (err.isEmpty) {
                  reqState = PawFriendState.sent;
                } else if (err == 'ALREADY_ACCEPTED') {
                  reqState = PawFriendState.friends;
                } else if (err.startsWith('ALREADY')) {
                  reqState = PawFriendState.sent;
                } else {
                  reqState = PawFriendState.error;
                }
              });
              if (err.isNotEmpty && !err.startsWith('ALREADY')) {
                CustomSnackbar.showError(
                    title: 'common_error'.tr, message: err);
              }
            },
          );
        },
      ),
    ).whenComplete(() {
      _selectedNearbyId = null;
      if (mounted) setState(() {});
    });
  }

  /// « Voir le profil » (lien secondaire) : la fiche complète.
  /// v584 (25/09, point 19) — Daniel : « Voir le profil » d'un membre le
  /// renvoyait vers SA page « Mes amis » quand le membre était propriétaire.
  /// La fiche s'ouvre selon le rôle DU MEMBRE : gardien → fiche gardien,
  /// promeneur → fiche promeneur, propriétaire (ou rôle inconnu) → fiche
  /// propriétaire publique. Écran empilé : le retour ramène à la carte.
  void _openMemberProfile({
    required String id,
    required String role,
    String name = '',
    String avatar = '',
  }) {
    final page = pawMapMemberProfilePage(id: id, role: role, name: name, avatar: avatar);
    Get.to(() => page);
  }

  /// 2e appui = l'écran de réservation, DIRECTEMENT (pas le profil), avec le
  /// service par défaut (garde si gardien, promenade si promeneur) et mon
  /// premier animal déjà cochés. Restent à choisir : dates et paiement.
  /// Les tarifs viennent de la fiche du prestataire (un appel léger).
  Future<void> _bookMember({
    required String id,
    required String role,
    required String name,
    required String currency,
  }) async {
    if (!_viewerLoggedIn) {
      await SignupWallSheet.show(
          trigger: 'booking', name: name, recommendedRole: 'pet_owner');
      return;
    }
    // v586 (point 8, Daniel : « les 3 rôles doivent pouvoir réserver ») —
    // un gardien / promeneur réserve avec son PROFIL PROPRIÉTAIRE : même
    // dialogue et même bascule que la fiche complète (`runAsOwner`).
    final r = await _loadProviderRates(id: id, role: role, currency: currency);
    if (!mounted) return;
    await runAsOwner(context,
        providerName: name,
        forMessage: false,
        then: () => Get.to(() => SendRequestScreen(
          serviceProviderName: name,
          serviceProviderId: id,
          serviceProviderRole: role == 'walker' ? 'walker' : 'sitter',
          sitterDailyRate: r.daily,
          sitterWeeklyRate: r.weekly,
          sitterMonthlyRate: r.monthly,
          walkerHalfHourRate: r.halfHour,
          walkerHourlyRate: r.hourly,
          currencyCode: r.currency,
          initialServiceType: role == 'walker' ? 'dog_walking' : 'pet_sitting',
          preselectFirstPet: true,
        )));
  }

  /// v584 (25/09, point 8) — tarifs COMPLETS d'un prestataire, dans SA
  /// devise : gardien = heure / jour / semaine / mois (+ animal
  /// supplémentaire) ; promeneur = 30 min / 1 h / 2 h. Les lignes non
  /// renseignées n'existent pas (jamais « 0 € »). Sert la fiche courte ET la
  /// réservation en 2 taps.
  Future<PawProviderRates> _loadProviderRates({
    required String id,
    required String role,
    required String currency,
  }) async {
    double? daily, weekly, monthly, hourly, halfHour, twoHours, extraPet;
    String cur = currency;
    try {
      if (role == 'walker' && Get.isRegistered<WalkerRepository>()) {
        final w = await Get.find<WalkerRepository>().getWalkerProfile(id);
        if (w.currency.isNotEmpty) cur = w.currency;
        for (final r in w.walkRates) {
          if (!r.enabled || r.basePrice <= 0) continue;
          if (r.durationMinutes == 30) halfHour = r.basePrice;
          if (r.durationMinutes == 60) hourly = r.basePrice;
          if (r.durationMinutes == 120) twoHours = r.basePrice;
        }
      } else if (Get.isRegistered<SitterRepository>()) {
        final p = await Get.find<SitterRepository>().getSitterProfile(id);
        final data = (p['sitter'] as Map<String, dynamic>?) ??
            (p['profile'] as Map<String, dynamic>?) ??
            p;
        double? pos(dynamic v) {
          final d = (v as num?)?.toDouble();
          return d != null && d > 0 ? d : null;
        }
        hourly = pos(data['hourlyRate']);
        daily = pos(data['dailyRate']);
        weekly = pos(data['weeklyRate']);
        monthly = pos(data['monthlyRate']);
        extraPet = pos(data['extraPetRate']);
        final c = (data['currency'] ?? '').toString();
        if (c.isNotEmpty) cur = c;
      }
    } catch (e) {
      debugPrint('[PawMap] tarifs du prestataire indisponibles : $e');
    }
    return PawProviderRates(
      currency: cur,
      role: role,
      hourly: hourly,
      daily: daily,
      weekly: weekly,
      monthly: monthly,
      extraPet: extraPet,
      halfHour: halfHour,
      twoHours: twoHours,
    );
  }

  /// « Message » depuis la fiche : ouvre (ou crée) la conversation, selon
  /// mon rôle, puis l'écran de discussion — même chemin que les fiches
  /// complètes.
  Future<void> _openConversationWith({
    required String id,
    required String role,
    required String name,
    required String avatar,
  }) async {
    // v586 (point 8) — gardien / promeneur → gardien / promeneur : aucune
    // route serveur ne l'ouvre (start-by-sitter|walker attend un
    // propriétaire) ; on écrit avec le PROFIL PROPRIÉTAIRE, comme la fiche.
    // Un AMI : la conversation entre amis existe pour tous les rôles.
    if (_friendController.isFriendWithAny([id])) {
      final convId = await _friendController.startFriendChat(
          targetUserId: id, targetUserRole: role);
      if (convId != null && mounted) {
        if (_role == 'sitter' || _role == 'walker') {
          Get.to(() => SitterIndividualChatScreen(
              conversationId: convId, contactName: name, contactImage: avatar));
        } else {
          Get.to(() => IndividualChatScreen(
              conversationId: convId, contactName: name, contactImage: avatar));
        }
        return;
      }
    }
    if ((_role == 'sitter' || _role == 'walker') &&
        (role == 'sitter' || role == 'walker')) {
      await runAsOwner(context,
          providerName: name,
          forMessage: true,
          then: () => unawaited(openOwnerChatWithProvider(
              providerId: id,
              providerRole: role,
              providerName: name,
              providerAvatar: avatar)));
      return;
    }
    try {
      Map<String, dynamic> res;
      final viewer = _role;
      if (viewer == 'sitter' && Get.isRegistered<SitterRepository>()) {
        res = await Get.find<SitterRepository>()
            .startConversationBySitter(ownerId: id);
      } else if (viewer == 'walker' && Get.isRegistered<WalkerRepository>()) {
        res = await Get.find<WalkerRepository>()
            .startConversationByWalker(ownerId: id);
      } else if (Get.isRegistered<OwnerRepository>()) {
        res = await Get.find<OwnerRepository>().startConversation(
          sitterId: role == 'sitter' ? id : null,
          walkerId: role == 'walker' ? id : null,
        );
      } else {
        _openCircleChat();
        return;
      }
      final conv = res['conversation'] as Map<String, dynamic>?;
      final convId = (conv?['id'] ?? conv?['_id'] ?? '').toString();
      if (convId.isEmpty) throw Exception('conversation id missing');
      if (!mounted) return;
      if (viewer == 'sitter' || viewer == 'walker') {
        Get.to(() => SitterIndividualChatScreen(
              conversationId: convId,
              contactName: name,
              contactImage: avatar,
            ));
      } else {
        Get.to(() => IndividualChatScreen(
              conversationId: convId,
              contactName: name,
              contactImage: avatar,
            ));
      }
    } catch (e) {
      debugPrint('[PawMap] conversation impossible : $e');
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'sitter_detail_start_chat_failed'.tr,
      );
    }
  }

  // ── MOI : mode « visible par mes amis seulement » ─────────────────────────

  bool _visibilitySaving = false;

  /// Tap sur MON rond → « Qui me voit sur la carte ? ».
  // v590 — handoff §2 : « Moi » suit la même logique (1er appui = zoom sur
  // moi / ma balade, 2e appui = ma fiche de visibilité, comme avant).
  void _onMeTap() {
    final me = _userPosition;
    if (me == null || _isSecondTap('me')) {
      _clearFocus();
      _openVisibilitySheet();
      return;
    }
    final live = _liveMap.broadcasting.value;
    final n = live ? _liveMap.myFollowers.value : 0;
    _focusFirstTap(
      me,
      PawFocusInfo(
        key: 'me',
        name: 'pawmap590_focus_me'.tr,
        role: _role.isEmpty ? 'owner' : _role,
        info: live
            ? [
                'pawmap590_focus_walking'.tr,
                if (n > 0) 'pawmap590_followers'.tr.replaceAll('{n}', '$n'),
              ].join(' · ')
            : 'pawmap590_direct_off'.tr,
        avatar: _myAvatarUrl(),
        live: live,
        onOpen: () {
          _clearFocus();
          _openVisibilitySheet();
        },
      ),
    );
  }

  void _openVisibilitySheet() {
    showPawMapSheet<void>(
      context,
      StatefulBuilder(
        builder: (ctx, setSheet) => PawMapVisibilitySheet(
          state: _visibility,
          saving: _visibilitySaving,
          onChanged: (v) async {
            if (v == _visibility) {
              Navigator.of(ctx).pop();
              return;
            }
            setSheet(() => _visibilitySaving = true);
            final ok = await _setVisibility(v);
            if (!ctx.mounted) return;
            setSheet(() => _visibilitySaving = false);
            if (ok) Navigator.of(ctx).pop();
          },
        ),
      ),
    );
  }

  /// v586 — bouton ŒIL de la capsule : un appui = état suivant (Tous → Amis
  /// seulement → Masqué → Tous), pastille 2 s qui dit le nouvel état.
  Future<void> _cycleVisibility() async {
    if (!_viewerLoggedIn) {
      SignupWallSheet.show(trigger: 'pawmap');
      return;
    }
    if (_visibilitySaving) return;
    _visibilitySaving = true;
    final next = MapPrefsService.nextVisibility(_visibility);
    await _setVisibility(next, snack: false);
    _visibilitySaving = false;
  }

  /// Enregistre l'état SUR LE COMPTE (même route que Préférences et le site,
  /// les 3 profils) ; en cas d'échec, rien ne change.
  Future<bool> _setVisibility(String v, {bool snack = true}) async {
    final ok = await _prefs.setMapVisibility(v);
    if (!ok) {
      if (mounted) {
        PawSignal.show(context, PawSignalKind.error, 'pawmap587_sig_vis_failed'.tr);
      }
      return false;
    }
    if (mounted) setState(() {});
    HapticFeedback.selectionClick();
    // v587 (point 9) — une seule pastille signature (verre chaud, maison à
    // la couleur de l'état, 2 s) au lieu du snackbar gris ; un appui dessus
    // rouvre « Qui me voit ? » quand on vient de l'œil.
    if (mounted) {
      PawSignal.visibility(context, _visibility,
          onTap: snack ? null : _openVisibilitySheet);
    }
    return true;
  }


  /// Bouton « ? » : la légende en images (9 langues).
  void _openLegend() {
    // v584 (Daniel, 25/09) : écran réutilisable, aussi depuis Profil › Aide.
    Get.to(() => const PawMapHelpScreen(fromMap: true));
  }

  /// v584 — idée 8 : « N membres autour de toi » → la liste (nom, rôle,
  /// distance, prix), triée du plus proche au plus loin ; tap = fiche.
  void _openAroundList() {
    final ref = _userPosition ?? _currentCenter;
    LatLng? posOf(Map<String, dynamic> p) {
      final loc = p['location'] is Map ? p['location'] as Map : null;
      final c = loc != null && loc['coordinates'] is List
          ? loc['coordinates'] as List
          : null;
      if (c == null || c.length < 2) return null;
      return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
    }

    final items = _aroundMembers
        .where((p) => posOf(p) != null)
        .map((p) => (p: p, d: _distanceKm(ref, posOf(p)!)))
        .toList()
      ..sort((a, b) => a.d.compareTo(b.d));
    showPawMapSheet<void>(
      context,
      PawMapAroundList(
        items: [
          for (final it in items)
            PawMapAroundItem(
              id: (it.p['id'] ?? it.p['_id'] ?? '').toString(),
              role: (it.p['_role'] ?? '').toString().toLowerCase(),
              name: (it.p['name'] ?? '').toString(),
              avatar: (it.p['avatar'] ?? '').toString(),
              distanceLabel: it.d < 1
                  ? '${(it.d * 1000).round()} m'
                  : '${it.d.toStringAsFixed(1)} km',
              // v590 — handoff §1 : prix de l'autre côté du marché.
              priceLabel: pawMapShowsPriceBubble(
                      _role, (it.p['_role'] ?? '').toString())
                  ? _priceLabelFor(it.p)
                  : '',
              premium: it.p['isPremium'] == true,
              verified: it.p['kycVerified'] == true,
              availableToday: it.p['availableToday'] == true,
            ),
        ],
        onTap: (item) {
          final p = _aroundMembers.firstWhereOrNull(
              (m) => (m['id'] ?? m['_id'] ?? '').toString() == item.id);
          if (p == null) return;
          Navigator.of(context).pop();
          final pos = posOf(p);
          _onNearbyTap(
            id: item.id,
            role: item.role,
            name: item.name,
            online: p['isOnline'] != false && p['online'] != false,
            premium: item.premium,
            lat: pos?.latitude,
            lng: pos?.longitude,
            avatar: item.avatar,
            approx: p['approx'] == true,
            approxKm: (p['approxKm'] as num?)?.toDouble() ?? 1.0,
            rating: (p['rating'] as num?)?.toDouble() ?? 0,
            reviewsCount: (p['reviewsCount'] as num?)?.toInt() ?? 0,
            priceFrom: (p['priceFrom'] as num?)?.toDouble() ?? 0,
            currency: (p['currency'] ?? 'EUR').toString(),
            verified: item.verified,
            boosted: p['isBoosted'] == true,
            availableToday: item.availableToday,
          );
        },
      ),
    );
  }
  /// Renders a circular white-bg marker with the emoji centered inside.
  /// 120x120 pixels gives a crisp icon on retina screens. Returns a
  /// BitmapDescriptor ready to assign to Marker(icon: ...).
  ///
  /// v23.1.353 — refonte PawSpot : le générateur accepte désormais un fond
  /// teinté ([bgColor], dessiné PAR-DESSUS la base blanche pour rester
  /// lisible), une couleur d'anneau ([ringColor]) et une épaisseur
  /// ([ringWidth]) pour les POIs (couleur catégorie) et les spots PawSpot
  /// (couleur type / doré). Les valeurs par défaut préservent le rendu
  /// historique des reports (blanc + anneau orange brand).
  Future<BitmapDescriptor> _buildEmojiBitmap(
    String emoji, {
    Color? bgColor,
    Color ringColor = const Color(0xFFC92A12),
    double ringWidth = 2.0,
  }) async {
    // v23.1.193 — Daniel : "emoji du chat en enorme sur la carte". On
    // reduit encore : 80 → 56px bitmap, emoji fontSize 40 → 28. Resultat
    // un marker compact comparable aux pins Google Maps natifs.
    const double size = 56.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Ombre douce derriere le cercle.
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(const Offset(size / 2, size / 2 + 1.5), size / 2 - 2, shadowPaint);

    // Cercle blanc (base) + voile teinté optionnel par-dessus.
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 2, bgPaint);
    if (bgColor != null) {
      final tintPaint = Paint()..color = bgColor;
      canvas.drawCircle(
          const Offset(size / 2, size / 2), size / 2 - 2, tintPaint);
    }
    // Anneau (orange brand par défaut, couleur catégorie/type sinon).
    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 3, ringPaint);

    // Emoji compact 28px.
    final tp = TextPainter(
      text: TextSpan(text: emoji, style: const TextStyle(fontSize: 28)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset((size - tp.width) / 2, (size - tp.height) / 2),
    );

    final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    // v23.1.193 (verifie 3x) — Daniel : "emoji du chat en enorme". Sans
    // width explicite, BitmapDescriptor.bytes rend a 1:1 logical pixels
    // (56 raw → 56 logical = ENORME a cote des markers natifs ~30px).
    // On passe width: 36 pour forcer un rendu compact comparable aux
    // pins Google Maps natifs. height suit le ratio 1:1.
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: 36,
    );
  }

  @override
  void dispose() {
    _filtersBannerTimer?.cancel();
    _filtersBannerWorker?.dispose();
    // v589 — plus de signal « je suis ce direct » après la carte.
    _followPresenceTimer?.cancel();
    if (_followUserId != null) {
      unawaited(_liveMap.followPresence(_followUserId!, false));
    }
    WidgetsBinding.instance.removeObserver(this);
    for (final w in _prefWorkers) {
      w.dispose();
    }
    _sheetCtl.removeListener(_onSheetMoved);
    _sheetCtl.dispose();
    _fade.dispose();
    unawaited(_prefs.flush());
    _pendingRouteWorker?.dispose();
    _pendingCenterWorker?.dispose();
    _pendingFriendWorker?.dispose();
    _reloadDebounce?.cancel();
    for (final w in _backGuardWorkers) {
      w.dispose();
    }
    _haloTimer?.cancel();
    _walkTimer?.cancel(); // v590
    _walkTimer = null;
    _followWorker?.dispose();
    _followEndWorker?.dispose();
    _myFollowWorker?.dispose();
    // v414 — Daniel : "qd l'app se ferme le direct s'éteint, je veux qu'il
    // reste allumé". On NE coupe PLUS le broadcast quand l'écran PawMap est
    // disposé (sortie d'écran / app en arrière-plan). LiveMapService est un
    // service PERMANENT et son foreground service Android (notif persistante)
    // garde le GPS + le socket vivants en arrière-plan. Le partage s'arrête
    // uniquement via : (1) le bouton « Stop » du bandeau Live actif, (2) le
    // cap de session 2 h, (3) l'auto-stop après 30 min d'immobilité.
    // _liveMap.stopBroadcasting();  // ← retiré volontairement (v414)
    _cityCtrl.dispose();
    super.dispose();
  }

  // v23.1 part 243 round 3 — pause / resume du halo selon le cycle de vie
  // de l'app. Quand on est paused/inactive (user a quitte vers home / locked),
  // on annule le timer. Quand on revient resumed, on relance avec la meme
  // periode. Gain perf : zero rebuild Google Map quand l'app est invisible.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      // v561 — Daniel : « quand on ferme l'app et qu'on la rouvre, ça revient
      // à ma position actuelle ». Après ≥ 2 min en arrière-plan, on se
      // recentre sur le GPS (sauf itinéraire en cours, suivi d'un ami ou
      // placement en cours).
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (pausedAt != null &&
          DateTime.now().difference(pausedAt) >= const Duration(minutes: 2) &&
          _routePolylines.isEmpty &&
          _followUserId == null &&
          !_pickingSpotPos.value &&
          !_pickingReportPos.value &&
          !_pickingRoutePos.value) {
        unawaited(_recenterOnUser());
      }
      if (_haloTimer == null || !(_haloTimer!.isActive)) {
        _haloTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
          if (!mounted || _cameraMoving) return;
          _haloPhase.value = (_haloPhase.value + 1.0 / 8.0) % 1.0;
        });
      }
    } else {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden) {
        _pausedAt ??= DateTime.now();
      }
      // paused / inactive / detached / hidden → coupe le timer.
      _haloTimer?.cancel();
      _haloTimer = null;
    }
  }

  /// v561 — instant du passage en arrière-plan (recentrage au retour).
  DateTime? _pausedAt;

  Future<void> _searchCity(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    try {
      final pos = await LocationService().getCoordinatesFromCity(trimmed);
      if (pos == null) {
        CustomSnackbar.showWarning(
          title: 'pawmap_snack_city_not_found'.tr,
          message: 'pawmap_snack_city_not_found_msg'.trParams({'city': trimmed}),
        );
        return;
      }
      await _goToCity(LatLng(pos.latitude, pos.longitude));
    } catch (e) {
      debugPrint('[PawMap] city search failed: $e');
      CustomSnackbar.showError(
        title: 'pawmap_snack_search_failed'.tr,
        message: 'pawmap_snack_search_failed_msg'.tr,
      );
    }
  }

  /// v554 — recentrage sur une ville. v584 : une seule carte, un seul
  /// contrôleur (la v523 animait deux cartes, il n'y en a plus qu'une).
  Future<void> _goToCity(LatLng target, {double zoom = 13}) async {
    if (!mounted) return;
    setState(() => _currentCenter = target);
    if (_mapCtl.isCompleted) {
      try {
        final ctl = await _mapCtl.future;
        await ctl.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
      } catch (_) {/* carte pas prête */}
    }
    await _reloadAtCenter();
  }

  /// v500 — Daniel : « quand je tape plusieurs fois voir amis puis la map,
  /// je dois faire plein de fois retour ». La boucle amis↔carte EMPILAIT une
  /// nouvelle copie à chaque aller-retour. Quand CETTE carte est déjà un
  /// écran empilé (ouverte depuis amis/alertes/en direct/chat), ouvrir un de
  /// ces écrans la REMPLACE (Get.off) au lieu de s'empiler par-dessus →
  /// UN SEUL retour ramène au menu du bas. Depuis l'onglet PawMap du menu
  /// (pas empilé), on garde l'empilement normal (Get.to).
  void _openScreen(Widget Function() page) {
    if (Navigator.of(context).canPop()) {
      Get.off(page);
    } else {
      Get.to(page);
    }
  }

  /// v591 — audit du 26/09 : après une annonce publiée depuis la PawMap,
  /// « Ma demande » n'apparaissait qu'après avoir déplacé la carte. On
  /// recharge au retour du formulaire.
  Future<void> _openPublishForm() async {
    if (Navigator.of(context).canPop()) {
      Get.off(() => const PublishReservationRequestScreen());
      return;
    }
    await Get.to(() => const PublishReservationRequestScreen());
    if (mounted) unawaited(_loadMyRequests());
  }

  /// v590 — une fois par ouverture : voir `POST /users/me/home-position`.
  Future<void> _sendHomePosition(LatLng p) async {
    try {
      if (!Get.isRegistered<ApiClient>()) return;
      await Get.find<ApiClient>().post('/users/me/home-position',
          body: {'lat': p.latitude, 'lng': p.longitude}, requiresAuth: true);
    } catch (_) {/* jamais bloquant */}
  }

  Future<void> _bootstrap() async {
    // v23.1.148 — Daniel : "fais que la paw map souvre sur notre geoloc pas a
    // paris". Avant : on attendait que `_mapCtl.isCompleted` soit true au
    // moment où la géoloc resolved, ce qui ratait souvent (la 1re frame du
    // GoogleMap n'a pas encore eu le temps de fire onMapCreated). Résultat :
    // la carte restait sur le fallback Paris. Maintenant : on attend
    // explicitement que le controller soit prêt avant d'animer, et on bump
    // le timeout géoloc à 8s (4s était trop court sur GPS lent / iOS au
    // démarrage).
    unawaited(_reloadAtCenter());
    // v585 (bug 11) — état PawBoost de MON rond, relu à chaque ouverture.
    unawaited(ActiveBenefitsRow.refreshBoostState());
    // v500 — watchdog TOUJOURS armé (avant, il n'était posé qu'après une
    // géoloc réussie → sur installation fraîche, géoloc timeout = aucune
    // relance et carte vide jusqu'au toggle Rien/Tous).
    _scheduleFirstLoadWatchdog();

    try {
      var loc = await LocationService()
          .getCurrentLocation()
          .timeout(const Duration(seconds: 8), onTimeout: () => null);
      // v500 — installation fraîche : la permission vient d'être accordée
      // et le 1er fix GPS peut dépasser les 8s → on retente UNE fois plus
      // longtemps au lieu d'abandonner (la carte restait sur Paris).
      loc ??= await LocationService()
          .getCurrentLocation()
          .timeout(const Duration(seconds: 15), onTimeout: () => null);
      if (loc == null) return;
      final myCenter = LatLng(loc.latitude, loc.longitude);
      if (!mounted) return;
      // v590 — « mon frère vit vers Murcia et ça le met vers Valencia » :
      // le serveur déplace la position de profil si le téléphone est à plus
      // de 50 km (déménagement) ; dans la même ville rien ne change.
      if (_viewerLoggedIn) unawaited(_sendHomePosition(myCenter));

      // v23.1 part 240 — Daniel : "et tu sur que dans le chat qd je met
      // voir carte sa me met sur le map sur la geoloco du sitter ou
      // walker ?". Avant : on remplacait toujours _currentCenter par MA
      // position GPS, meme si initialLat/Lng (position d'un sitter ou
      // d'un ami) avait ete passe → la map se centrait sur moi a la place.
      // FIX : si on a un initialLat/Lng on garde le centre demande
      // (sitter, walker, ami). On set juste _userPosition pour pouvoir
      // afficher MON point bleu en plus, dans un coin de la carte.
      final hasInitialFocus =
          (widget.initialLat != null && widget.initialLng != null) ||
              _friendFocusRequested;
      setState(() {
        // _userPosition reste toujours MA position (overlay perso).
        _userPosition = myCenter;
        // _currentCenter ne bouge que si on n'a pas de focus explicite.
        if (!hasInitialFocus) {
          _currentCenter = myCenter;
          _saveLastCamera(myCenter, _zoomLevel);
        }
      });

      // Wait for the GoogleMap controller to be ready — _mapCtl resolves
      // when onMapCreated fires. Hard timeout to avoid hanging forever if
      // the map widget never builds (e.g. user switched tabs immediately).
      // v240 — on anime la camera vers MA position UNIQUEMENT si pas de
      // focus initial (sinon on reste sur le sitter/walker/ami).
      if (!hasInitialFocus) {
        try {
          final ctl = await _mapCtl.future.timeout(
            const Duration(seconds: 6),
            onTimeout: () => throw TimeoutException('map controller not ready'),
          );
          // v584 — ma position, au ZOOM retenu (plus un 13 en dur).
          await ctl.animateCamera(
              CameraUpdate.newLatLngZoom(
                  myCenter, PawMapCameraMemory.launchZoom(_zoomLevel)));
        } catch (_) {
          // Controller never came up — _currentCenter is updated so the
          // next frame's initialCameraPosition is correct anyway.
        }
      } else {
        // Focus mode : on anime vers la position du sitter/ami. v23.1.270 —
        // Daniel : "le suivi doit zoomer FORT sur la personne". En mode SUIVI
        // (_followUserId), on zoome à _followZoom (18) au lieu de 14 — avant,
        // ce 14 écrasait le zoom 18 posé par onMapCreated → zoom trop faible.
        try {
          final ctl = await _mapCtl.future.timeout(
            const Duration(seconds: 6),
            onTimeout: () => throw TimeoutException('map controller not ready'),
          );
          final z = _followUserId != null ? _followZoom : 14.0;
          await ctl.animateCamera(
            CameraUpdate.newLatLngZoom(_currentCenter, z),
          );
        } catch (_) {/* defensive */}
      }

      await _reloadAtCenter();
    } catch (e) {
      debugPrint('[PawMap] bootstrap error: $e');
    }
  }

  /// v500 — remplace le watchdog v352 (un seul essai, et seulement si la
  /// géoloc avait réussi). Tant que les 3 couches sont vides, on relance le
  /// chargement toutes les 4s, jusqu'à 3 fois : couvre le token pas encore
  /// prêt au boot, le réseau lent, ET la permission GPS accordée en retard
  /// sur une installation fraîche (version Store).
  void _scheduleFirstLoadWatchdog() {
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      final nothingLoaded = _poiController.pois.isEmpty &&
          _reportController.reports.isEmpty &&
          _nearbyProviders.isEmpty;
      if (nothingLoaded && _firstLoadRetries < 3) {
        _firstLoadRetries++;
        debugPrint(
            '[PawMap] first-load watchdog → retry $_firstLoadRetries/3');
        unawaited(_reloadAtCenter());
        _scheduleFirstLoadWatchdog();
      }
    });
  }

  /// v23.1.189 — Daniel : "faire bouton cherche une ville". Ouvre un
  /// dialog texte qui geocode la ville saisie et centre la map dessus +
  /// reload les POI / reports.
  Future<void> _onSearchCity() async {
    final ctrl = TextEditingController();
    final suggestions = <Map<String, dynamic>>[].obs;
    final loading = false.obs;
    final typed = ''.obs;
    Timer? debounce;

    List<Map<String, dynamic>> recents() {
      try {
        final raw = GetStorage().read('pawmap_recent_cities');
        if (raw is List) {
          return raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {/* stockage illisible */}
      return const [];
    }

    void remember(Map<String, dynamic> city) {
      try {
        final list = recents().toList()
          ..removeWhere((e) =>
              e['name'] == city['name'] && e['label'] == city['label']);
        list.insert(0, city);
        GetStorage().write('pawmap_recent_cities', list.take(5).toList());
      } catch (_) {/* sans importance */}
    }

    Future<void> lookup(String q) async {
      final query = q.trim();
      typed.value = query;
      if (query.length < 2) {
        suggestions.clear();
        loading.value = false;
        return;
      }
      loading.value = true;
      try {
        final api =
            Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : null;
        if (api == null) return;
        final res = await api.get(
          '/geo/cities',
          queryParameters: {
            'q': query,
            'lang': Get.locale?.languageCode ?? 'fr',
            // Biais de proximité : « asnie » près de Paris doit sortir
            // Asnières-sur-Seine en premier, pas Asnières-en-Montagne.
            'lat': '${(_userPosition ?? _currentCenter).latitude}',
            'lng': '${(_userPosition ?? _currentCenter).longitude}',
          },
        );
        // Réponse périmée (l'utilisateur a continué à taper) : on l'ignore.
        if (typed.value != query) return;
        final list = res is List ? res : const [];
        suggestions.assignAll(
          list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
        );
      } catch (_) {
        // Suggestions indisponibles : la touche Entrée reste opérationnelle.
        suggestions.clear();
      } finally {
        if (typed.value == query) loading.value = false;
      }
    }

    Future<void> pick(Map<String, dynamic> city) async {
      final lat = (city['lat'] as num?)?.toDouble();
      final lng = (city['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return;
      remember(city);
      if (mounted) Navigator.of(context).pop();
      await _goToCity(LatLng(lat, lng));
    }

    Widget cityTile(Map<String, dynamic> city, {required bool recent}) {
      return InkWell(
        onTap: () => pick(city),
        borderRadius: BorderRadius.circular(14.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 4.w),
          child: Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: recent
                      ? PawMapTheme.veilOn(context, 0.05, darkAlpha: 0.12)
                      : (PawMapTheme.isDark(context)
                          ? PawMapTheme.accent.withValues(alpha: 0.18)
                          : PawMapTheme.pastelPeach),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  recent
                      ? Icons.history_rounded
                      : Icons.location_city_rounded,
                  size: 18.sp,
                  color: recent
                      ? PawMapTheme.subOn(context)
                      : PawMapTheme.toneOn(context, PawMapTheme.accent),
                ),
              ),
              SizedBox(width: 11.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (city['name'] ?? '').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PawMapTheme.fontOn(context,
                          size: 14.sp, weight: FontWeight.w700),
                    ),
                    if ((city['label'] ?? '').toString().isNotEmpty)
                      Text(
                        (city['label'] ?? '').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PawMapTheme.fontOn(
                          context,
                          size: 11.sp,
                          weight: FontWeight.w500,
                          color: PawMapTheme.subOn(context),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.north_east_rounded,
                  size: 16.sp, color: PawMapTheme.subOn(context)),
            ],
          ),
        ),
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        // Le clavier pousse la feuille : la liste reste visible au-dessus.
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: PawMapTheme.bgOn(ctx),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
          ),
          padding: EdgeInsets.fromLTRB(
            18.w,
            12.h,
            18.w,
            16.h + appBottomInset(ctx),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: PawMapTheme.veilOn(ctx, 0.12, darkAlpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              SizedBox(height: 14.h),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'pawmap_search_city'.tr,
                  style: PawMapTheme.fontOn(ctx,
                      size: 18.sp, weight: FontWeight.w800),
                ),
              ),
              SizedBox(height: 12.h),
              // Champ de saisie : pilule blanche, loupe à gauche, croix à
              // droite, spinner pendant que les suggestions arrivent.
              Container(
                decoration: BoxDecoration(
                  color: PawMapTheme.panelOn(ctx),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: PawMapTheme.borderOn(ctx)),
                  boxShadow: PawMapTheme.pillShadow,
                ),
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded,
                        size: 19.sp, color: PawMapTheme.accent),
                    SizedBox(width: 9.w),
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        style: PawMapTheme.fontOn(ctx,
                            size: 14.sp, weight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'pawmap_search_city_hint'.tr,
                          hintStyle: PawMapTheme.font(
                            size: 13.sp,
                            weight: FontWeight.w500,
                            color: PawMapTheme.subOn(ctx),
                          ),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 14.h),
                        ),
                        onChanged: (v) {
                          debounce?.cancel();
                          debounce = Timer(
                              const Duration(milliseconds: 320), () => lookup(v));
                        },
                        onSubmitted: (v) async {
                          debounce?.cancel();
                          final q = v.trim();
                          if (q.isEmpty) return;
                          // Une suggestion déjà affichée ? on la prend, c'est
                          // plus fiable que le géocodage sur texte libre.
                          if (suggestions.isNotEmpty) {
                            await pick(suggestions.first);
                            return;
                          }
                          if (mounted) Navigator.of(ctx).pop();
                          await _searchCity(q);
                        },
                      ),
                    ),
                    Obx(() {
                      if (loading.value) {
                        return SizedBox(
                          width: 16.w,
                          height: 16.w,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: PawMapTheme.accent,
                          ),
                        );
                      }
                      if (typed.value.isEmpty) return SizedBox(width: 4.w);
                      return GestureDetector(
                        onTap: () {
                          ctrl.clear();
                          typed.value = '';
                          suggestions.clear();
                        },
                        child: Icon(Icons.close_rounded,
                            size: 18.sp, color: PawMapTheme.subOn(ctx)),
                      );
                    }),
                  ],
                ),
              ),
              SizedBox(height: 10.h),
              Obx(() {
                final query = typed.value;
                final items = suggestions.toList();
                final rec = recents();
                // Champ vide → villes récentes (rien du tout au 1er usage).
                if (query.length < 2) {
                  if (rec.isEmpty) return SizedBox(height: 8.h);
                  return ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 260.h),
                    child: ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 4.h, left: 4.w),
                            child: Text(
                              'pawmap_search_recent'.tr,
                              style: PawMapTheme.font(
                                size: 11.sp,
                                weight: FontWeight.w700,
                                color: PawMapTheme.subOn(ctx),
                              ),
                            ),
                          ),
                        ),
                        ...rec.map((c) => cityTile(c, recent: true)),
                      ],
                    ),
                  );
                }
                if (items.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 18.h),
                    child: Text(
                      loading.value
                          ? 'directions_loading'.tr
                          : 'pawmap_snack_city_not_found'.tr,
                      style: PawMapTheme.font(
                        size: 12.5.sp,
                        weight: FontWeight.w600,
                        color: PawMapTheme.subOn(ctx),
                      ),
                    ),
                  );
                }
                return ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: 300.h),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    itemBuilder: (_, i) => cityTile(items[i], recent: false),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
    debounce?.cancel();
    // v584 — la feuille joue encore son animation de fermeture après le
    // retour de showModalBottomSheet : le TextField serait reconstruit avec
    // un contrôleur mort (« used after being disposed », vu au parcours
    // simulateur). On libère après la fin de l'animation.
    Future<void>.delayed(const Duration(milliseconds: 700), ctrl.dispose);
  }

  /// v554 — rechargement DEMANDÉ par l'utilisateur (loupe ↻ de l'AppBar).
  /// Force aussi la couche monde à repartir du réseau : sans ça, le cache de
  /// 5 min du serveur + le cache local 24 h donnaient l'impression que le
  /// bouton ne faisait rien.
  Future<void> _manualRefresh() async {
    if (_refreshing.value) return;
    _refreshing.value = true;
    try {
      _worldMembersLoaded = false;
      await _reloadAtCenter();
      if (!mounted) return;
      CustomSnackbar.showSuccess(
        title: 'pawmap_refresh_done'.tr,
        message: 'pawmap_members_around'
            .trParams({'count': '${_membersShown.value}'}),
      );
    } finally {
      _refreshing.value = false;
    }
  }

  Future<void> _reloadAtCenter() async {
    final futures = <Future<void>>[
      _poiController.loadNearby(_currentCenter),
      _reportController.loadNearby(_currentCenter),
      // v23.1.353 — refonte PawSpot : recharge aussi les spots 🐾 quand la
      // couche est active (pan/zoom → nouveaux spots autour du centre).
      if (_showPawSpots.value) _pawSpotController.loadNearby(_currentCenter, radiusM: _spotRadiusM),
    ];
    // Demandes layer is sitter/walker only — don't waste a round-trip on
    // owner sessions.
    if (_isSitterOrWalker) {
      futures.add(_loadNearbyRequests());
    } else {
      // v584 — le propriétaire voit SES demandes (« Ma demande »).
      futures.add(_loadMyRequests());
    }
    // v497 — Daniel : « membres PawMap proches » (badge rose) doivent être vus
    // par TOUS les rôles (avant : owner uniquement). On charge la liste pour
    // tout le monde (endpoint /friends/members/nearby = membres abonnés proches).
    futures.add(_loadNearbyProviders());
    // v548 — couche monde (une fois).
    futures.add(_loadWorldMembers());
    await Future.wait(futures);
    // v521 — ceinture + bretelles pour le bug « points invisibles au 1er
    // chargement » : après CHAQUE rechargement de données on force une
    // reconstruction (la clé de cache ci-dessus fait le tri — no-op si le
    // contenu n'a réellement pas changé).
    if (mounted) setState(() {});
  }

  /// v23.1 part 72 — Bug 10 : fetch nearby walkers + sitters and merge
  /// into _nearbyProviders so the map can render them. Boosted ones
  /// (isMapBoosted=true) come back from the backend already enriched.
  Future<void> _loadNearbyProviders() async {
    try {
      final api = Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : null;
      if (api == null) return;
      final params = {
        'lat': _currentCenter.latitude.toString(),
        'lng': _currentCenter.longitude.toString(),
        'radiusInMeters': '25000',
      };
      // v497 — Daniel : « membres PawMap proches = TOUS les rôles (abonnés) ».
      // On remplace /walkers|sitters/nearby (providers only, vu par owner only)
      // par l'endpoint dédié /friends/members/nearby qui renvoie owners + sitters
      // + walkers ABONNÉS (PawSpot/Premium/PawFollow/staff), proches, hors moi.
      final res = await api
          .get('/friends/members/nearby',
              queryParameters: params, requiresAuth: true)
          .catchError((_) => <String, dynamic>{});
      final list = ((res as Map?)?['members'] as List?) ?? const [];
      final merged = <Map<String, dynamic>>[];
      for (final m in list) {
        if (m is Map) {
          merged.add({
            // v585 — on GARDE tous les champs du serveur (`isFriend`,
            // `roles`, `personIds`, `kycVerified`, `isBoosted`,
            // `availableToday`, `lastSeenAt`…) : la v584 les jetait ici, d'où
            // « Ajouter en ami » proposé pour un ami (bug 2).
            ...Map<String, dynamic>.from(m),
            'id': (m['id'] ?? '').toString(),
            '_role': (m['role'] ?? '').toString(),
            'name': (m['name'] ?? '').toString(),
            'avatar': m['avatar'] ?? '',
            'location': m['location'],
            // couronne 👑 = membre Premium/staff ; le badge/halo rose s'affiche
            // pour TOUS les membres. isMapBoosted laissé false (crown=isPremium).
            'isPremium': m['isPremium'] == true,
            'isPremiumOnly': m['isPremiumOnly'] == true,
            'hasPawFollow': m['hasPawFollow'] == true,
            'hasPawSpot': m['hasPawSpot'] == true || m['isPawSpot'] == true,
            'isMapBoosted': false,
            'isOnline': m['isOnline'] != false,
          });
        }
      }
      _nearbyProviders.assignAll(merged);
    } catch (_) {
      /* keep last list */
    }
  }

  /// v548 — couche MONDE (voir `_worldMembers`). Une seule requête par
  /// ouverture de la carte ; le serveur renvoie des positions arrondies.
  Future<void> _loadWorldMembers() async {
    if (_worldMembersLoaded) return;
    // v550 — carte « peuplée » dès la première frame : on réaffiche le dernier
    // instantané connu (24 h max) pendant que la requête part. Sans ça la
    // PawMap restait vide quelques secondes au lancement — l'impression de
    // lenteur venait de là, pas du rendu.
    if (_worldMembers.isEmpty) {
      try {
        final cached = GetStorage().read('pawmap_world_cache');
        final at = GetStorage().read('pawmap_world_cache_at');
        if (cached is List &&
            at is int &&
            DateTime.now().millisecondsSinceEpoch - at <
                const Duration(hours: 24).inMilliseconds) {
          _worldMembers.assignAll(
            cached.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
          );
          _worldRev += 1;
          if (mounted) setState(() {});
        }
      } catch (_) {/* cache illisible : on attend le réseau */}
    }
    try {
      final api = Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : null;
      if (api == null) return;
      final res = await api
          .get('/friends/members/world', requiresAuth: true)
          .catchError((_) => <String, dynamic>{});
      final list = ((res as Map?)?['members'] as List?) ?? const [];
      final out = <Map<String, dynamic>>[];
      for (final m in list) {
        if (m is Map) {
          out.add({
            // v585 — tous les champs du serveur (voir _loadNearbyProviders).
            ...Map<String, dynamic>.from(m),
            'id': (m['id'] ?? '').toString(),
            '_role': (m['role'] ?? '').toString(),
            'name': (m['name'] ?? '').toString(),
            'avatar': m['avatar'] ?? '',
            'location': m['location'],
            'isPremium': m['isPremium'] == true,
            'isMapBoosted': false,
            'isOnline': m['isOnline'] == true,
            'approx': true,
            'approxKm': (m['approxKm'] as num?)?.toDouble() ??
                (res?['approxKm'] as num?)?.toDouble() ??
                1.0,
          });
        }
      }
      if (out.isEmpty && _worldMembers.isNotEmpty) return; // garde le cache
      _worldMembers.assignAll(out);
      _worldRev += 1;
      _worldMembersLoaded = true;
      try {
        GetStorage().write('pawmap_world_cache', out);
        GetStorage().write(
            'pawmap_world_cache_at', DateTime.now().millisecondsSinceEpoch);
      } catch (_) {/* stockage plein : sans importance */}
    } catch (_) {
      /* silencieux : la couche proche reste */
    }
  }

  /// Fetches owner reservation requests within ~25km of the current map
  /// center. Uses /posts/requests/nearby (added in the same session).
  Future<void> _loadNearbyRequests() async {
    try {
      final api = Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : null;
      if (api == null) return;
      final res = await api.get(
        '/posts/requests/nearby',
        queryParameters: {
          'lat': _currentCenter.latitude.toString(),
          'lng': _currentCenter.longitude.toString(),
          // v591 — audit du 26/09 : 25 km figés ici, 50 km par défaut sur
          // l'accueil → une annonce visible sur l'accueil manquait sur la
          // carte. Au moins 50 km, davantage si la carte montre plus large.
          'maxDistance': (_spotRadiusM / 1000).clamp(50, 500).round().toString(),
        },
        requiresAuth: true,
      );
      final list = (res['posts'] as List?) ?? const [];
      _requests.value = list
          .map((e) => NearbyRequestPost.fromJson(e as Map<String, dynamic>))
          .where((p) => p.lat != 0 || p.lng != 0)
          .toList();
    } catch (e) {
      debugPrint('[PawMap] loadNearbyRequests error: $e');
      _requests.clear();
    }
  }

  void _onCameraMove(CameraPosition pos) {
    _currentCenter = pos.target;
    // v584 — plus d'écriture à chaque image : centre + zoom sont enregistrés
    // à l'arrêt de la caméra (`_scheduleReload`).
    // v550 — perf : tant que la caméra bouge, le halo ne pulse pas (sinon la
    // GoogleMap se reconstruit 1,7×/s pendant le pan → saccades sur mobile).
    _cameraMoving = true;
    _zoomLevel = pos.zoom;
    // v456 — viseur « point rouge au centre » : l'emplacement choisi SUIT le
    // centre de la carte que l'utilisateur déplace sous le repère rouge fixe
    // (placement précis, façon Uber). Plus de pin à faire glisser.
    if (_pickingSpotPos.value ||
        _pickingReportPos.value ||
        _pickingRoutePos.value) {
      _pickedSpotPos = pos.target;
    }
  }

  /// Debounced wrapper for `_reloadAtCenter()`. Cancels any pending reload
  /// and schedules a fresh one 500 ms later. Wired to `onCameraIdle` so the
  /// POI / report / request layers refresh after the user stops panning.
  void _scheduleReload() {
    _cameraMoving = false; // v550 — geste terminé : le halo repulse.
    // v584 — la caméra s'arrête : on retient l'endroit ET le zoom, sur
    // l'appareil et sur le compte (« tout lié entre appareils »).
    _saveLastCamera(_currentCenter, _zoomLevel);
    _prefs.update({
      'camera': PawMapCameraMemory.encode(_currentCenter, _zoomLevel),
    });
    // v555 — pendant un placement, on résout l'adresse du point visé dès que
    // la carte s'immobilise (affichée dans la carte de placement).
    if (_pickingSpotPos.value ||
        _pickingReportPos.value ||
        _pickingRoutePos.value) {
      unawaited(_refreshPickAddress());
    }
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      // v550 — fluidité : chaque `onCameraIdle` déclenchait 5 requêtes (POI,
      // signalements, spots, demandes, membres). Un simple zoom ou un
      // micro-déplacement relançait tout le paquet et faisait saccader la
      // carte sur mobile. On ne recharge que si le centre a réellement bougé
      // (~1/4 de la largeur visible) — ou si on n'a encore jamais chargé.
      final last = _lastReloadCenter;
      if (last != null) {
        final cosC = math
            .cos(_currentCenter.latitude * math.pi / 180)
            .abs()
            .clamp(0.05, 1.0);
        final dKm = math.sqrt(
              math.pow(_currentCenter.latitude - last.latitude, 2) +
                  math.pow((_currentCenter.longitude - last.longitude) * cosC, 2),
            ) *
            111.32;
        // Rayon visible approximatif : ~40 000 km / 2^zoom.
        final visibleKm = 40000 / math.pow(2, _zoomLevel.clamp(1, 20));
        if (dKm < math.max(0.3, visibleKm * 0.25)) {
          // v591 — dézoom sur place : recharger les PawSpots sur la zone agrandie.
          if (_showPawSpots.value && _spotRadiusM > _lastSpotRadiusM * 1.4) {
            _lastSpotRadiusM = _spotRadiusM;
            unawaited(_pawSpotController.loadNearby(_currentCenter, radiusM: _spotRadiusM));
          }
          return;
        }
      }
      _lastReloadCenter = _currentCenter;
      _lastSpotRadiusM = _spotRadiusM;
      _reloadAtCenter();
    });
  }

  /// Toggles the "Suivre mon animal" broadcast — when on, friends see the
  /// user's pin moving on their PawMap. The user's own pin shows in rose
  /// (via `_hueForRole('owner')`) so it's easy to spot as "myself + pet".
  /// Session v3.2 — opened to ALL roles/tiers (was Premium-gated); Daniel
  /// wants every user to be able to share their pet's live position to help
  /// find lost animals and keep friends in the loop.
  void _toggleBroadcast() async {
    if (_liveMap.broadcasting.value) {
      _liveMap.stopBroadcasting();
      PawSignal.show(context, PawSignalKind.liveOff, 'pawmap587_sig_live_off'.tr);
      return;
    }

    // v565 — points 11 / 23 (contrat §8) : durée choisie au démarrage —
    // 1 h / 4 h / jusqu'à l'arrêt (défaut). Le partage ne s'arrête plus
    // qu'à l'échéance ou sur l'interrupteur (plus de cap 2 h ni d'arrêt
    // sur immobilité). Feuille fermée sans choix → on n'active rien.
    final chosen = await _pickLiveDuration();
    if (chosen == null || !mounted) return;
    await _startBroadcastWith(chosen);
  }

  /// Démarre le partage en direct pour [chosen] (GPS frais d'abord, puis
  /// zoom piéton) — chemin unique du bouton Direct et de la feuille.
  Future<void> _startBroadcastWith(LiveShareDuration chosen) async {
    // v19.1.5 — refresh GPS FIRST, then zoom. Before this fix we used the
    // stale `_currentCenter` which could be the last panned position on the
    // map (parfois "à côté" de l'utilisateur réel).
    // v23.1 part 237 — Daniel : "action rapide me suivre a regler".
    // Bug : _currentCenter etait mis a jour par le pan utilisateur (ligne
    // 602) → broadcast suivait la map center pas le GPS reel. Fix : on
    // met a jour _userPosition (cible immobile = vrai GPS) et le broadcast
    // closure lit _userPosition au lieu de _currentCenter.
    LatLng target = _userPosition ?? _currentCenter;
    try {
      final loc = await LocationService()
          .getCurrentLocation()
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (loc != null) {
        target = LatLng(loc.latitude, loc.longitude);
        if (mounted) {
          setState(() {
            _currentCenter = target;
            _userPosition = target; // v237 : ce que le broadcast doit suivre.
          });
        }
      }
    } catch (_) {
      // GPS indispo → on garde l'ancien _userPosition.
    }

    // v23.1 part 237 — broadcast suit _userPosition (GPS reel) au lieu de
    // _currentCenter (qui derive avec le pan). Les amis recoivent ainsi
    // VRAIMENT la position GPS de Daniel, pas son map center.
    // v587 (25/09) — Daniel : « mon frère est affiché dans l'eau ». Sans
    // fix GPS, le partage envoyait `_currentCenter` = le CENTRE DE LA CARTE
    // (qui suit le doigt : glisser la carte vers la mer y « déplaçait » le
    // direct). On n'envoie plus QUE de vraies positions GPS ; (0,0) = rien
    // (ignoré par le service), le flux GPS prend le relais dès son 1er fix.
    _liveMap.startBroadcasting(
      () => _userPosition ?? const LatLng(0, 0),
      duration: chosen,
    );
    if (mounted) {
      if (_userPosition == null) {
        PawSignal.show(context, PawSignalKind.noGps, 'pawmap587_sig_no_gps'.tr);
      } else {
        PawSignal.show(context, PawSignalKind.live, 'pawmap587_sig_live_on'.tr);
      }
    }

    // Zoom "piéton" (street level ~17) centré sur la position GPS fraîche.
    try {
      final ctl = await _mapCtl.future;
      await ctl.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: 17),
        ),
      );
    } catch (_) {}
  }

  /// v565 — feuille « Combien de temps ? » du partage en direct.
  /// v565 (18/09) — Daniel : l'option SÉLECTIONNÉE est en VERT plein
  /// (#16A34A, coche blanche), les autres en contour gris. Rouverte pendant
  /// un partage, l'option en cours reste marquée (avec le temps restant si
  /// une durée est choisie) ; on peut changer de durée ou arrêter.
  Future<LiveShareDuration?> _pickLiveDuration() {
    const green = Color(0xFF16A34A);
    final bool sharing = _liveMap.broadcasting.value;
    final LiveShareDuration? current =
        sharing ? _liveMap.sessionDuration.value : null;

    String remainingLabel() {
      final rem = _liveMap.remaining;
      if (rem == null) return '';
      final h = rem.inHours;
      final m = rem.inMinutes % 60;
      return h > 0
          ? '${h}h${m.toString().padLeft(2, '0')}'
          : '${rem.inMinutes} min';
    }

    Widget option(BuildContext ctx, LiveShareDuration d, IconData icon,
        String title, String sub, bool isDefault) {
      final bool selected = current == d;
      final String subText = selected && d != LiveShareDuration.untilStop
          ? '${'v565_live_remaining'.tr} ${remainingLabel()}'
          : sub;
      return InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: () => Navigator.of(ctx).pop(d),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: selected ? green : Colors.transparent,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: selected
                  ? green
                  : AppColors.textSecondary(ctx).withValues(alpha: 0.35),
              width: 1.4,
            ),
          ),
          child: Row(children: [
            Container(
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.18)
                    : green.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon,
                  color: selected ? Colors.white : green, size: 20.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InterText(
                    text: title,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : AppColors.textPrimary(ctx),
                    maxLines: 1,
                  ),
                  InterText(
                    text: subText,
                    fontSize: 11.5.sp,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.9)
                        : AppColors.textSecondary(ctx),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 24.w,
                height: 24.w,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, color: green, size: 17.sp),
              )
            else if (isDefault && !sharing)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: InterText(
                  text: 'v565_live_default'.tr,
                  fontSize: 9.5.sp,
                  fontWeight: FontWeight.w800,
                  color: green,
                ),
              ),
          ]),
        ),
      );
    }

    return showModalBottomSheet<LiveShareDuration>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
          padding: EdgeInsets.fromLTRB(18.w, 14.h, 18.w, 14.h),
          decoration: BoxDecoration(
            color: AppColors.card(ctx),
            borderRadius: BorderRadius.circular(24.r),
            boxShadow: PawMapTheme.pillShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 12.h),
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary(ctx).withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              Row(children: [
                Icon(Icons.podcasts_rounded, color: green, size: 22.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: InterText(
                    text: sharing
                        ? 'pawmap_live_banner_title'.tr
                        : 'v565_live_duration_title'.tr,
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(ctx),
                    maxLines: 2,
                  ),
                ),
                if (sharing)
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: green,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 7.w,
                        height: 7.w,
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                      ),
                      SizedBox(width: 5.w),
                      InterText(
                        text: 'v565_live_active'.tr,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ]),
                  ),
              ]),
              SizedBox(height: 4.h),
              InterText(
                text: sharing
                    ? 'v565_live_change_sub'.tr
                    : 'v565_live_duration_sub'.tr,
                fontSize: 12.sp,
                color: AppColors.textSecondary(ctx),
                maxLines: 3,
              ),
              SizedBox(height: 14.h),
              option(ctx, LiveShareDuration.untilStop, Icons.all_inclusive_rounded,
                  'v565_live_until_stop'.tr, 'v565_live_until_stop_sub'.tr, true),
              option(ctx, LiveShareDuration.fourHours, Icons.timer_rounded,
                  'v565_live_4h'.tr, 'v565_live_4h_sub'.tr, false),
              option(ctx, LiveShareDuration.oneHour, Icons.timer_outlined,
                  'v565_live_1h'.tr, 'v565_live_1h_sub'.tr, false),
              SizedBox(height: 2.h),
              if (sharing)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PawMapTheme.danger,
                      side: BorderSide(color: PawMapTheme.danger, width: 1.4),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _liveMap.stopBroadcasting();
                      PawSignal.show(context, PawSignalKind.liveOff,
                          'pawmap587_sig_live_off'.tr);
                    },
                    icon: Icon(Icons.stop_circle_rounded, size: 18.sp),
                    label: Text('v565_live_stop'.tr,
                        style: TextStyle(
                            fontSize: 14.sp, fontWeight: FontWeight.w700)),
                  ),
                )
              else
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: InterText(
                      text: 'common_cancel'.tr,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary(ctx),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// v565 (18/09) — feuille rouverte PENDANT un partage (tap sur le bandeau) :
  /// l'option en cours est marquée ; en choisir une autre change la durée.
  Future<void> _openLiveDurationSheet() async {
    if (!_liveMap.broadcasting.value) {
      _toggleBroadcast();
      return;
    }
    final chosen = await _pickLiveDuration();
    if (chosen == null || !mounted) return;
    if (!_liveMap.broadcasting.value) return; // arrêté depuis la feuille
    if (chosen != _liveMap.sessionDuration.value) {
      _liveMap.changeDuration(chosen);
      PawSignal.show(context, PawSignalKind.live, 'pawmap587_sig_duration'.tr);
    }
  }

  /// v565 — point 3 : feuille « Amis en direct ». Liste tous ceux dont on a
  /// une position (amis, famille), avec photo, rôle et « vu il y a X » /
  /// « signal perdu ». Tap = suivre sur la carte (le panneau se replie, rien
  /// d'autre ne s'ouvre). Itinéraire et « tout voir » en bonus.
  Future<void> _openLiveFriendsSheet() async {
    // Rafraîchit l'état de session des amis (stale / lastSeenAt) en fond.
    unawaited(_liveMap.refreshFriendPositions());
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        final maxH = MediaQuery.of(sheetCtx).size.height * 0.72;
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(maxHeight: maxH),
            margin: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
            decoration: BoxDecoration(
              color: AppColors.card(sheetCtx),
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: PawMapTheme.pillShadow,
            ),
            child: Obx(() {
              _liveMap.staleTick.value; // « vu il y a » se rafraîchit
              final positions = _liveMap.friendPositions.values.toList()
                ..sort((a, b) {
                  if (a.isStale != b.isStale) return a.isStale ? 1 : -1;
                  return b.seenAt.compareTo(a.seenAt);
                });
              final friendById = <String, Friendship>{
                for (final f in _friendController.friends)
                  if (f.other != null)
                    f.other!.id.trim().toLowerCase(): f,
              };
              final familyById = {
                for (final m in _friendController.familyMembers)
                  ((m['id'] ?? m['userId'] ?? '').toString())
                      .trim()
                      .toLowerCase(): m,
              };
              final liveCount = positions.where((p) => !p.isStale).length;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(18.w, 12.h, 8.w, 6.h),
                    child: Row(children: [
                      Container(
                        width: 40.w,
                        height: 40.w,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6EB4), PawMapTheme.roseDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: Icon(Icons.people_alt_rounded,
                            color: Colors.white, size: 22.sp),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InterText(
                              text: 'v565_live_friends_title'.tr,
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary(sheetCtx),
                              maxLines: 1,
                            ),
                            InterText(
                              text: 'v565_live_friends_count'
                                  .trParams({'n': '$liveCount'}),
                              fontSize: 12.sp,
                              color: AppColors.textSecondary(sheetCtx),
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                      if (positions.length > 1)
                        IconButton(
                          tooltip: 'v565_live_friends_fit'.tr,
                          icon: Icon(Icons.zoom_out_map_rounded,
                              color: PawMapTheme.roseDark),
                          onPressed: () {
                            Navigator.of(sheetCtx).pop();
                            unawaited(_fitAllFriends());
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                      ),
                    ]),
                  ),
                  Divider(height: 1, color: AppColors.divider(sheetCtx)),
                  Flexible(
                    child: positions.isEmpty
                        ? Padding(
                            padding: EdgeInsets.fromLTRB(24.w, 26.h, 24.w, 20.h),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.gps_off_rounded,
                                    size: 44.sp,
                                    color: AppColors.textSecondary(sheetCtx)),
                                SizedBox(height: 10.h),
                                InterText(
                                  text: 'friends_people_live_empty_title'.tr,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary(sheetCtx),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 4.h),
                                InterText(
                                  text: 'friends_people_live_empty_msg'.tr,
                                  fontSize: 12.sp,
                                  color: AppColors.textSecondary(sheetCtx),
                                  textAlign: TextAlign.center,
                                  maxLines: 4,
                                ),
                                SizedBox(height: 14.h),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: PawMapTheme.roseDark,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14.r),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.of(sheetCtx).pop();
                                    _openScreen(() => const FriendsScreen());
                                  },
                                  icon: Icon(Icons.person_add_alt_1_rounded,
                                      size: 18.sp),
                                  label: Text('v565_live_friends_invite'.tr),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.fromLTRB(10.w, 8.h, 10.w, 10.h),
                            itemCount: positions.length,
                            separatorBuilder: (_, __) => SizedBox(height: 6.h),
                            itemBuilder: (_, i) {
                              final pos = positions[i];
                              final key = pos.userId.trim().toLowerCase();
                              final friend = friendById[key];
                              final fam = familyById[key];
                              final name = friend?.other?.name ??
                                  (fam?['name'] ?? '').toString();
                              final display = name.isNotEmpty
                                  ? name
                                  : (widget.focusUserId == pos.userId
                                      ? (widget.focusUserName ?? '')
                                      : '');
                              final role = (friend?.other?.model ??
                                      (fam?['role'] ?? pos.role).toString())
                                  .toLowerCase();
                              final avatar = friend?.other?.avatar ??
                                  (fam?['avatar'] ?? '').toString();
                              final roleColor = PawMapTheme.forRole(role);
                              final stale = pos.isStale;
                              return _liveFriendRow(
                                sheetCtx,
                                pos: pos,
                                name: display.isEmpty
                                    ? 'pawmap_following_default'.tr
                                    : display,
                                role: role,
                                avatar: avatar,
                                roleColor: roleColor,
                                stale: stale,
                                isFamily: fam != null,
                              );
                            },
                          ),
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  Widget _liveFriendRow(
    BuildContext ctx, {
    required FriendPosition pos,
    required String name,
    required String role,
    required String avatar,
    required Color roleColor,
    required bool stale,
    required bool isFamily,
  }) {
    final roleLabel = role == 'walker'
        ? 'role_pet_walker'.tr
        : (role == 'owner' ? 'role_pet_owner'.tr : 'role_pet_sitter'.tr);
    final statusColor = stale ? const Color(0xFFE8920A) : const Color(0xFF16A34A);
    final statusText = stale
        ? '${'v565_live_signal_lost'.tr} · ${'pawmap_seen_ago'.tr.replaceAll('{ago}', _timeAgo(pos.seenAt))}'
        : '${'v565_live_active'.tr} · ${_timeAgo(pos.seenAt)}';
    void follow() {
      Navigator.of(ctx).pop();
      // v588 — même geste que la liste d'amis : vol doux (zoom 16), fiche
      // courte, suivi s'il est en direct ; Masqué / sans position → pastille.
      final friend = _friendController.friends.firstWhereOrNull(
          (f) => f.other != null && f.other!.matchesId(pos.userId));
      final PawMapFriendFocus? focus = friend != null
          ? pawMapFriendFocusFor(friend.other!, live: pos)
          : (pos.liveState != FriendLiveState.seen
              ? PawMapFriendFocus(
                  userId: pos.userId,
                  role: role,
                  name: name,
                  avatar: avatar,
                  lat: pos.latitude,
                  lng: pos.longitude,
                  live: true,
                  approxKm: 0,
                )
              : null);
      if (focus == null) {
        PawSignal.show(context, PawSignalKind.hidden, 'friends588_not_on_map'.tr);
        return;
      }
      unawaited(_focusFriend(focus));
    }

    return Material(
      color: AppColors.scaffold(ctx),
      borderRadius: BorderRadius.circular(16.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: follow,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
          child: Row(children: [
            Stack(children: [
              Container(
                width: 46.w,
                height: 46.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: roleColor.withValues(alpha: 0.15),
                  border: Border.all(
                    color: isFamily ? PawMapTheme.pawFollow : roleColor,
                    width: 2,
                  ),
                  image: avatar.startsWith('http')
                      ? DecorationImage(
                          image: NetworkImage(avatar), fit: BoxFit.cover)
                      : null,
                ),
                child: avatar.startsWith('http')
                    ? null
                    : Icon(Icons.pets, color: roleColor, size: 20.sp),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 13.w,
                  height: 13.w,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.card(ctx), width: 2),
                  ),
                ),
              ),
            ]),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InterText(
                    text: name,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(ctx),
                    maxLines: 1,
                  ),
                  SizedBox(height: 2.h),
                  InterText(
                    text: '$roleLabel · $statusText',
                    fontSize: 11.sp,
                    color: stale ? statusColor : AppColors.textSecondary(ctx),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'pawmap_btn_directions'.tr,
              icon: Icon(Icons.directions_rounded,
                  color: const Color(0xFF16A34A), size: 22.sp),
              onPressed: () {
                Navigator.of(ctx).pop();
                unawaited(_startDirections(LatLng(pos.latitude, pos.longitude)));
              },
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: PawMapTheme.roseDark,
                borderRadius: BorderRadius.circular(999),
              ),
              child: InterText(
                text: 'v565_live_friends_follow'.tr,
                fontSize: 11.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─── Halos (cercles en mètres) ───────────────────────────────────────────
  // v584 — légende validée le 23/09 : « les halos restent une lueur extérieure
  // autour du rond, jamais l'anneau », « un seul halo par rond : PawBoost
  // (turquoise, dessiné DANS l'épingle) > PawFollow (violet) », et « la seule
  // chose animée de la carte, c'est le boost (sauf Moi en suivi) ». Les halos
  // or Premium, jaune PawSpot et les anneaux « rose » qui respiraient autour
  // de chaque membre proche sont RETIRÉS : la couronne et la couleur du rôle
  // suffisent, et la carte respire mieux (moins de cercles à redessiner).
  // Restent : mon halo (couleur du rôle ; il ne pulse que quand je partage ma
  // position), le halo violet des amis en direct, et l'anneau de suivi.
  Set<Circle> _buildHaloCircles() {
    final Set<Circle> circles = {};
    final userPos = _userPosition;
    if (userPos != null && _showLiveLayer.value) {
      final bool live = _liveMap.broadcasting.value;
      final phase = live ? _haloPhase.value : 0.35;
      final userRadius = 25.0 + 75.0 * phase;
      final userOpacity = (0.55 * (1.0 - phase)).clamp(0.0, 1.0);
      final userColor = PawMapLegend.roleColor(_role);
      circles.add(
        Circle(
          circleId: const CircleId('user_halo_outer'),
          center: userPos,
          radius: userRadius,
          fillColor: userColor.withValues(alpha: userOpacity * 0.4),
          strokeColor: userColor.withValues(alpha: userOpacity),
          strokeWidth: 2,
        ),
      );
    }
    if (!_showLiveLayer.value) return circles;
    try {
      final follow = _followUserId?.trim().toLowerCase();
      for (final pos in _liveMap.friendPositions.values) {
        final normUserId = pos.userId.trim().toLowerCase();
        // Halo PawFollow violet, FIXE, sous l'ami en direct.
        circles.add(
          Circle(
            circleId: CircleId('live_halo_${pos.userId}'),
            center: LatLng(pos.latitude, pos.longitude),
            radius: 55,
            fillColor: PawMapLegend.pawFollow.withValues(alpha: 0.12),
            strokeColor: PawMapLegend.pawFollow.withValues(alpha: 0.55),
            strokeWidth: 2,
          ),
        );
        // v23.1.274 — anneau de SUIVI (respire) sur la personne suivie.
        if (follow != null && normUserId == follow) {
          final phase = _haloPhase.value;
          circles.add(
            Circle(
              circleId: CircleId('follow_track_${pos.userId}'),
              center: LatLng(pos.latitude, pos.longitude),
              radius: 30 + (phase * 40),
              fillColor: PawMapLegend.pawFollow.withValues(alpha: 0.10 * (1 - phase)),
              strokeColor: PawMapLegend.pawFollow.withValues(alpha: 0.95),
              strokeWidth: 4,
              zIndex: 5,
            ),
          );
        }
      }
    } catch (_) {/* defensive */}
    return circles;
  }

  // ─── Marker building ─────────────────────────────────────────────────────
  // v23.1 part 243 round 3 — cache des marqueurs : `_buildMarkers` ne tourne
  // que quand la clé change (données, interrupteurs, zoom, épingles prêtes).
  /// Index de phase PawBoost (0..3) dérivé du tick halo. N'entre dans la clé
  /// que s'il y a au moins un membre boosté à l'écran.
  int get _boostPhaseIdx => ((_haloPhase.value * kBoostPhases).floor()) % kBoostPhases;
  bool _anyBoosted = false;

  /// « Réduire les animations » du téléphone → lueur PawBoost FIXE.
  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  Set<Marker> _getMarkersFromCache() {
    final key = [
      _focusTapId ?? '', // v589 — mini bulle « Voir le profil »
      _nearbyProviders.length,
      _poiController.visiblePois.length,
      // v521 — identité des POI (le backend plafonne à 200 → même longueur).
      _poiController.visiblePois.isNotEmpty
          ? '${_poiController.visiblePois.first.id}:${_poiController.visiblePois.last.id}'
          : '',
      _reportController.reports.length,
      _showProviders.value ? 1 : 0,
      _showPois.value ? 1 : 0,
      _showReports.value ? 1 : 0,
      _emojiMarkersReady ? 1 : 0,
      _reportEmojiMarkers.length,
      _showPawSpots.value ? 1 : 0,
      _showLiveLayer.value ? 1 : 0,
      _showPremiumLayer.value ? 1 : 0,
      Get.locale?.languageCode ?? '',
      _pickingSpotPos.value ? 1 : 0,
      _pickingReportPos.value ? 1 : 0,
      _pickingRoutePos.value ? 1 : 0,
      _pawSpotController.spots.length,
      _liveMap.friendPositions.length,
      // v23.1.263 — signature des positions amis (un ami qui bouge).
      _liveMap.friendPositions.values
          .map((p) =>
              '${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)},${p.isStale ? 1 : 0}')
          .join('|'),
      _requests.length,
      _myRequests.length,
      _showRequests.value ? 1 : 0,
      _showFriends.value ? 1 : 0,
      // v584 — épingles / photos prêtes, mode amis seulement, ma photo.
      _pins.rev.value,
      _visibility,
      _friendController.familyMembers.length,
      _friendController.friends.length,
      // v587 (point 11) — position de profil des amis (/friends).
      _friendController.friends
          .map((f) =>
              '${f.other?.id}:${f.other?.mapLat?.toStringAsFixed(4)},${f.other?.mapLng?.toStringAsFixed(4)}')
          .join('|'),
      _showProviders.value ? 1 : 0,
      _pawSpotController.pawspotActive.value ? 1 : 0,
      _pawSpotController.premiumActive.value ? 1 : 0,
      // v585 (bug 11) — mon PawBoost : sans lui dans la clé, l'épingle ne se
      // redessinait pas après l'activation.
      ActiveBenefitsRow.profileBoostAccessor.value ? 1 : 0,
      _selectedNearbyId ?? '',
      _nearbyProviders
          .map((p) =>
              '${p['id'] ?? p['_id']}:${p['isPremium'] == true ? 1 : 0}:${p['isOnline'] != false && p['online'] != false ? 1 : 0}:${p['isBoosted'] == true ? 1 : 0}:${p['isFriend'] == true ? 1 : 0}:${(p['roles'] is List) ? (p['roles'] as List).length : 0}')
          .join('|'),
      _worldRev,
      _worldMembers.length,
      _memberRoles.join(','),
      _availableTodayOnly.value ? 1 : 0,
      _zoomLevel.round(),
      _zoomLevel >= _priceZoom ? 1 : 0,
      '${_currentCenter.latitude.toStringAsFixed(1)},'
          '${_currentCenter.longitude.toStringAsFixed(1)}',
      _userPosition == null
          ? ''
          : '${_userPosition!.latitude.toStringAsFixed(5)},${_userPosition!.longitude.toStringAsFixed(5)}',
      // Respiration PawBoost : seulement si un boost est visible.
      _anyBoosted && !_reduceMotion ? _boostPhaseIdx : -1,
    ].join('-');
    if (_cachedMarkers == null || _cachedMarkersKey != key) {
      _cachedMarkers = _buildMarkers();
      _cachedMarkersKey = key;
    }
    return _cachedMarkers!;
  }

  /// Zoom « rue » à partir duquel le prix s'affiche sous l'épingle (idée 2).
  // v591 — Daniel : « que la bulle prix s'affiche un peu avant de trop zoomer » (15 → 13).
  static const double _priceZoom = 13;

  // ── fabriques d'épingles (cache PawMapPinCache) ──────────────────────────

  BitmapDescriptor _memberIcon({
    required String role,
    required bool crown,
    required bool boosted,
    required bool verified,
    required bool online,
    required bool selected,
    String? priceLabel,
    double rating = 0,
    // v592 — comme le web : prénom dessous, prix dans la bulle colorée au-dessus.
    String? priceBubble,
  }) {
    final phase = boosted ? (_reduceMotion ? 0 : _boostPhaseIdx) : -1;
    final size = PawMapLegend.memberSize;
    final withLabel = priceLabel != null && priceLabel.isNotEmpty;
    final withBubble = priceBubble != null && priceBubble.isNotEmpty;
    final r1 = withLabel ? (rating * 10).round() / 10 : 0.0;
    final key =
        'member:$role:${crown ? 1 : 0}:$phase:${verified ? 1 : 0}:${online ? 1 : 0}:${selected ? 1 : 0}:${priceLabel ?? ''}:$r1:${priceBubble ?? ''}';
    final w = PawMapPinPainter.memberBitmapSize(size);
    final h = PawMapPinPainter.memberBitmapSize(size,
        withLabel: withLabel, withBubble: withBubble);
    return _pins.getOrBuild(
          key,
          w,
          h,
          (c) => PawMapPinPainter.paintMemberDot(
            c,
            role: role,
            size: size,
            crown: crown,
            verified: verified,
            online: online,
            selected: selected,
            boostPhase: boosted ? phase / kBoostPhases : null,
            priceLabel: priceLabel,
            rating: r1,
            priceBubble: withBubble ? priceBubble : null,
          ),
        ) ??
        BitmapDescriptor.defaultMarkerWithHue(role == 'sitter'
            ? BitmapDescriptor.hueAzure
            : role == 'walker'
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueOrange);
  }

  /// Ancre d'un rond de membre : centre du cercle (le bitmap a une marge et,
  /// au zoom rue, une étiquette de prix en dessous).
  Offset _memberAnchor({bool withLabel = false}) {
    final size = PawMapLegend.memberSize;
    final h = PawMapPinPainter.memberBitmapSize(size, withLabel: withLabel);
    return Offset(0.5, (PawMapPinPainter.memberMargin + size / 2) / h);
  }

  BitmapDescriptor _photoIcon({
    required String keyPrefix,
    required String avatarUrl,
    required Color ring,
    required double size,
    String? label,
    Color? labelColor,
    bool crown = false,
    double crownSize = PawMapLegend.crownFriend,
    bool online = false,
    bool dashedRing = false,
    bool eyeOff = false,
    bool boosted = false,
    int followPhase = -1,
    bool dimmed = false,
    IconData fallbackIcon = Icons.pets_rounded,
    Color fallbackTint = PawMapLegend.owner,
    List<Color>? ringColors,
    // v590 — handoff §1 : bulle de prix AU-DESSUS du rond, couleur du service.
    String? priceBubble,
    String priceRole = 'sitter',
  }) {
    final avatar = _pins.avatarFor(avatarUrl);
    final bool withBubble = priceBubble != null && priceBubble.isNotEmpty;
    final ringsKey = (ringColors ?? const <Color>[])
        .map((c) => c.toARGB32())
        .join('-');
    final phase = boosted ? (_reduceMotion ? 0 : _boostPhaseIdx) : -1;
    final withLabel = label != null && label.isNotEmpty;
    final key =
        '$keyPrefix:${avatar == null ? 0 : avatarUrl.hashCode}:${ring.toARGB32()}:$size:${label ?? ''}:${crown ? 1 : 0}:${online ? 1 : 0}:${dashedRing ? 1 : 0}:${eyeOff ? 1 : 0}:$phase:$followPhase:${dimmed ? 1 : 0}:${fallbackIcon.codePoint}:$ringsKey:${withBubble ? '$priceBubble/$priceRole' : ''}';
    final w = PawMapPinPainter.photoBitmapSize(size);
    final h = PawMapPinPainter.photoBitmapSize(size, withLabel: withLabel) +
        (withBubble ? PawMapPinPainter.priceBubbleZone : 0);
    return _pins.getOrBuild(
          key,
          w,
          h,
          (c) => PawMapPinPainter.paintPhotoDot(
            c,
            avatar: avatar,
            ringColor: ring,
            ringColors: ringColors,
            size: size,
            label: label,
            labelColor: labelColor,
            crown: crown,
            crownSize: crownSize,
            online: online,
            dashedRing: dashedRing,
            eyeOff: eyeOff,
            boostPhase: boosted ? phase / kBoostPhases : null,
            followPhase: followPhase >= 0 ? followPhase / kBoostPhases : null,
            dimmed: dimmed,
            fallbackIcon: fallbackIcon,
            fallbackTint: fallbackTint,
            priceBubble: withBubble ? priceBubble : null,
            priceRole: priceRole,
          ),
        ) ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose);
  }

  Offset _photoAnchor(double size,
      {bool withLabel = false, bool withBubble = false}) {
    final double zone = withBubble ? PawMapPinPainter.priceBubbleZone : 0;
    final h = PawMapPinPainter.photoBitmapSize(size, withLabel: withLabel) + zone;
    return Offset(0.5, (zone + PawMapPinPainter.photoMargin + size / 2) / h);
  }

  BitmapDescriptor _memberClusterIcon(int count, Map<String, int> roleCounts,
      {bool hasFriend = false}) {
    final sig = ['owner', 'sitter', 'walker']
        .map((k) => '${k[0]}${roleCounts[k] ?? 0}')
        .join();
    final w = PawMapPinPainter.memberClusterWidth(count > 99 ? 100 : count) + 12;
    final h = PawMapLegend.memberClusterHeight + 12;
    return _pins.getOrBuild(
          'mcluster:${count > 99 ? 100 : count}:$sig:${hasFriend ? 1 : 0}',
          w,
          h,
          (c) => PawMapPinPainter.paintMemberCluster(c, count,
              roleCounts: roleCounts, hasFriend: hasFriend),
        ) ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose);
  }

  BitmapDescriptor _placeIcon(String category) {
    final w = PawMapPinPainter.dropBitmapWidth(PawMapLegend.placeSize);
    final h = PawMapPinPainter.dropHeight(PawMapLegend.placeSize);
    return _pins.getOrBuild(
          'place:$category',
          w,
          h,
          (c) => PawMapPinPainter.paintPlaceDrop(c, category: category),
        ) ??
        BitmapDescriptor.defaultMarkerWithHue(_hueForPoi(category));
  }

  BitmapDescriptor _placeClusterIcon(int count, String? dominant) {
    final tone = PawMapLegend.placeColor(dominant ?? 'other');
    final s = PawMapPinPainter.squareClusterBitmapSize();
    return _pins.getOrBuild(
          'pcluster:${count > 99 ? 100 : count}:${dominant ?? ''}',
          s,
          s,
          (c) => PawMapPinPainter.paintSquareCluster(c, count, tone: tone),
        ) ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
  }

  BitmapDescriptor _spotIcon(String type, bool golden) {
    final size = golden ? PawMapLegend.spotGoldSize : PawMapLegend.spotSize;
    final w = PawMapPinPainter.dropBitmapWidth(size);
    final h = PawMapPinPainter.dropHeight(size);
    return _pins.getOrBuild(
          'spot:$type:${golden ? 1 : 0}',
          w,
          h,
          (c) => PawMapPinPainter.paintPawSpotDrop(c, type: type, golden: golden),
        ) ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
  }

  BitmapDescriptor _spotClusterIcon(int count) {
    final s = PawMapPinPainter.squareClusterBitmapSize();
    return _pins.getOrBuild(
          'scluster:${count > 99 ? 100 : count}',
          s,
          s,
          (c) => PawMapPinPainter.paintSquareCluster(c, count,
              tone: PawMapLegend.gold, black: true),
        ) ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
  }

  /// Ancre d'une goutte : la POINTE (bas du bitmap, hors marge).
  Offset _dropAnchor(double width) {
    final h = PawMapPinPainter.dropHeight(width);
    return Offset(0.5, (PawMapPinPainter.dropMargin + width * 1.32) / h);
  }

  BitmapDescriptor _requestIcon({
    String? priceLabel,
    required bool walking,
    String? mineLabel,
  }) {
    final w = PawMapPinPainter.requestBubbleBitmapWidth(
        priceLabel: priceLabel, mineLabel: mineLabel);
    final h = PawMapPinPainter.requestBubbleBitmapHeight();
    return _pins.getOrBuild(
          'request:${priceLabel ?? ''}:${walking ? 1 : 0}:${mineLabel ?? ''}',
          w,
          h,
          (c) => PawMapPinPainter.paintRequestBubble(c,
              priceLabel: priceLabel, walking: walking, mineLabel: mineLabel),
        ) ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
  }

  /// Ancre de la bulle : sa pointe (bas du corps + pointe, hors marge basse).
  Offset get _requestAnchor {
    final h = PawMapPinPainter.requestBubbleBitmapHeight();
    return Offset(0.5, (8 + PawMapLegend.requestBubbleHeight + 7) / h);
  }

  /// v590 — ma photo (profil en cache), pour la carte focus « Moi ».
  String _myAvatarUrl() {
    try {
      final profile =
          GetStorage().read<Map<String, dynamic>>(StorageKeys.userProfile);
      final raw = profile?['avatar'];
      return raw is Map ? (raw['url'] ?? '').toString() : (raw ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  String _priceLabelFor(Map<String, dynamic> p) {
    final price = (p['priceFrom'] as num?)?.toDouble() ?? 0;
    if (price <= 0) return '';
    final cur = (p['currency'] ?? 'EUR').toString();
    return CurrencyHelper.formatCompact(cur, price);
  }

  Set<Marker> _buildMarkers() {
    final Set<Marker> markers = {};
    _anyBoosted = false;
    // ── MOI : ma photo 56 px, anneau à la couleur de mon rôle, « Moi »,
    // couronne si Premium ; mode « amis seulement » = anneau pointillé +
    // œil barré (seul moi le vois : mes amis me voient normalement).
    final myPos = _userPosition;
    if (myPos != null && _showLiveLayer.value) {
      try {
        final profile =
            GetStorage().read<Map<String, dynamic>>(StorageKeys.userProfile);
        final rawAvatar = profile?['avatar'];
        final myAvatar = rawAvatar is Map
            ? (rawAvatar['url'] ?? '').toString()
            : (rawAvatar ?? '').toString();
        final roleColor = PawMapLegend.roleColor(_role);
        final bool myBoost = ActiveBenefitsRow.profileBoostAccessor.value;
        if (myBoost) _anyBoosted = true;
        markers.add(
          Marker(
            markerId: const MarkerId('me'),
            position: myPos,
            icon: _photoIcon(
              keyPrefix: 'me',
              avatarUrl: myAvatar,
              ring: roleColor,
              size: PawMapLegend.meSize,
              label: 'pawmap_me_label'.tr,
              labelColor: PawMapLegend.darken(roleColor, 0.25),
              crown: _pawSpotController.premiumActive.value,
              crownSize: PawMapLegend.crownMe,
              // v585 (bug 11) — PawBoost : lueur turquoise qui respire + fusée
              // sur MON rond aussi (prime sur la couleur du rôle ; Premium
              // garde sa couronne).
              boosted: myBoost,
              dashedRing: _friendsOnly,
              eyeOff: _friendsOnly,
              fallbackTint: roleColor,
            ),
            anchor: _photoAnchor(PawMapLegend.meSize, withLabel: true),
            zIndexInt: 10,
            consumeTapEvents: true, // v590 — zoom géré par la carte focus
            onTap: _onMeTap,
          ),
        );
      } catch (_) {/* defensive — le halo rôle reste visible */}
    }

    // ── MEMBRES (proches exacts si abonné + couche monde ~1 km) ──
    // v586 (point 7) — un AMI dépend de la pastille « Amis » seulement ; les
    // autres membres de leur pastille de rôle. Couper les lieux ne touche
    // plus jamais aux personnes.
    if (_showProviders.value || _showFriends.value) {
      // v587 — seuls les amis qui PARTAGENT en ce moment (direct ou signal
      // perdu < 10 min) ont un rond « direct » ; c'est lui qui prime.
      // v589 — tous les ids de la personne (pas seulement celui du direct).
      final friendLiveIds = _liveMap.friendPositions.values
          .where((p) => p.liveState != FriendLiveState.seen)
          .expand((p) => p.allIds)
          .toSet();
      bool isFriendMember(Map<String, dynamic> p) =>
          p['isFriend'] == true ||
          _friendController.isFriendWithAny(pawMapPersonIds(p));
      // v584 (25/09, point 1) — la couche « proches » (position exacte des
      // membres abonnés, amis en exact) n'était affichée QU'AUX abonnés : un
      // ami pouvait manquer pour un viewer sans abonnement. Le serveur décide
      // déjà de ce qu'il renvoie (règles de visibilité) : on affiche tout.
      // v587 (point 11) — la couche amis se place depuis GET /friends
      // (position de profil floutée ~1 km, absente si « Masqué ») ; elle
      // prime sur les couches proches / monde et ajoute les amis qu'elles
      // n'ont pas (au-delà du plafond, comptes de test).
      final placed = pawMapPlaceFriends(
        nearby: _nearbyProviders.toList(),
        world: _worldMembers.toList(),
        friendPoints: pawMapFriendPoints(_friendController.friends),
      );
      final nearbyIds = <String>{};
      final combined = <Map<String, dynamic>>[...placed.extra];
      for (final p in placed.extra) {
        nearbyIds.addAll(pawMapPersonIds(p));
      }
      for (final p in placed.nearby) {
        // v585 — tous les ids de la personne : son point « monde » (posé
        // avec l'id d'un AUTRE de ses rôles) ne doit pas la dédoubler.
        nearbyIds.addAll(pawMapPersonIds(p));
        combined.add(p);
      }
      // v550 — plafond d'affichage de la couche monde (les plus proches).
      final worldPool = <Map<String, dynamic>>[];
      for (final p in placed.world) {
        final id = (p['id'] ?? '').toString();
        if (id.isEmpty || pawMapPersonIds(p).any(nearbyIds.contains)) continue;
        // v587 (point 2) — un AMI n'est jamais écarté par le plafond
        // d'affichage (les plus proches d'abord) : visible à tous les zooms.
        if (isFriendMember(p)) {
          combined.add(p);
          continue;
        }
        worldPool.add(p);
      }
      final int worldCap =
          _zoomLevel >= 11 ? 400 : (_zoomLevel >= 6 ? 300 : 200);
      if (worldPool.length > worldCap) {
        final cosC =
            math.cos(_currentCenter.latitude * math.pi / 180).abs().clamp(0.05, 1.0);
        double dist2(Map<String, dynamic> p) {
          final loc = p['location'] is Map ? p['location'] as Map : null;
          final c = loc != null && loc['coordinates'] is List
              ? loc['coordinates'] as List
              : null;
          if (c == null || c.length < 2) return double.maxFinite;
          final dLat = (c[1] as num).toDouble() - _currentCenter.latitude;
          final dLng =
              ((c[0] as num).toDouble() - _currentCenter.longitude) * cosC;
          return dLat * dLat + dLng * dLng;
        }

        worldPool.sort((a, b) => dist2(a).compareTo(dist2(b)));
        combined.addAll(worldPool.take(worldCap));
      } else {
        combined.addAll(worldPool);
      }
      LatLng? posOfMember(Map<String, dynamic> p) {
        final loc = p['location'] is Map ? p['location'] as Map : null;
        final c = loc != null && loc['coordinates'] is List
            ? loc['coordinates'] as List
            : null;
        if (c == null || c.length < 2) return null;
        return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
      }

      bool roleOk(Map<String, dynamic> p) {
        if (!_showProviders.value) return false;
        final r = (p['_role'] ?? p['role'] ?? '').toString().toLowerCase();
        if (r.isEmpty || _memberRoles.contains(r)) return true;
        // Une personne à plusieurs rôles : visible si UN de ses rôles l'est.
        final roles = p['roles'];
        if (roles is List) {
          for (final e in roles) {
            final rr = (e is Map ? e['role'] : e)?.toString().toLowerCase();
            if (rr != null && _memberRoles.contains(rr)) return true;
          }
        }
        return false;
      }

      bool familyOk(Map<String, dynamic> p) {
        final friend = p['isFriend'] == true ||
            _friendController.isFriendWithAny(pawMapPersonIds(p));
        return friend ? _showFriends.value : roleOk(p);
      }

      // Idée 4 — filtre « Disponible aujourd'hui » (drapeau serveur).
      // v590 — Daniel : « ma mère ne voit aucun utilisateur ni ami ». Le
      // filtre « Disponible aujourd'hui » cachait TOUT le monde sans
      // disponibilité du jour, amis et propriétaires compris. Il ne vise
      // désormais que les gardiens et promeneurs qui ne sont pas des amis.
      bool availableOk(Map<String, dynamic> p) {
        if (!_availableTodayOnly.value || p['availableToday'] == true) return true;
        if (isFriendMember(p)) return true;
        final r = (p['_role'] ?? p['role'] ?? '').toString().toLowerCase();
        return r != 'sitter' && r != 'walker';
      }

      final placeable = combined
          .where((p) => posOfMember(p) != null && familyOk(p) && availableOk(p))
          .toList();
      // Compteur « N membres autour de toi » (< 50 km de l'utilisateur).
      const double aroundKm = 50.0;
      final ref = _userPosition ?? _currentCenter;
      final cosRef =
          math.cos(ref.latitude * math.pi / 180).abs().clamp(0.05, 1.0);
      bool within(Map<String, dynamic> p) {
        final pos = posOfMember(p);
        if (pos == null) return false;
        final dLat = (pos.latitude - ref.latitude) * 111.32;
        final dLng = (pos.longitude - ref.longitude) * 111.32 * cosRef;
        return dLat * dLat + dLng * dLng <= aroundKm * aroundKm;
      }

      final countedIds = <String>{};
      var around = 0;
      final aroundList = <Map<String, dynamic>>[];
      for (final p in [..._nearbyProviders, ..._worldMembers]) {
        if (!roleOk(p) || !availableOk(p) || !within(p)) continue;
        final id = (p['id'] ?? p['_id'] ?? '').toString();
        if (id.isNotEmpty && !countedIds.add(id)) continue;
        around += 1;
        aroundList.add(p);
      }
      if (_membersShown.value != around) {
        final n = around;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _membersShown.value = n;
        });
      }
      _aroundMembers = aroundList;

      // v587 (point 2) — Daniel : « mes amis sont difficiles à trouver, il
      // faut surzoomer ». Un ami était absorbé dans un groupe « 12 » avec des
      // inconnus. Les amis ne sont plus JAMAIS regroupés : chacun garde son
      // rond photo + anneau rose, à tous les zooms, au-dessus des autres.
      final groups = pawGroupKeepingFriends<Map<String, dynamic>>(
        placeable,
        isFriendMember,
        (others) => _clusterize<Map<String, dynamic>>(
          others,
          (p) => posOfMember(p)!,
          cellPx: _memberClusterCellPx,
        ),
      );
      final showPrice = _zoomLevel >= _priceZoom;
      for (final group in groups) {
        if (group.length > 1) {
          final target = _centroid<Map<String, dynamic>>(
              group, (p) => posOfMember(p)!);
          final roleCounts = <String, int>{'owner': 0, 'sitter': 0, 'walker': 0};
          for (final m in group) {
            final rr = (m['_role'] ?? '').toString().toLowerCase();
            if (roleCounts.containsKey(rr)) roleCounts[rr] = roleCounts[rr]! + 1;
          }
          markers.add(
            Marker(
              markerId: MarkerId('mcluster_${target.latitude.toStringAsFixed(4)}'
                  '_${target.longitude.toStringAsFixed(4)}_${group.length}'),
              position: target,
              // v592 — un groupe qui contient un ami porte l'anneau rose (web).
              icon: _memberClusterIcon(group.length, roleCounts,
                  hasFriend: group.any((m) =>
                      m['isFriend'] == true ||
                      _friendController.isFriendWithAny(pawMapPersonIds(m)))),
              anchor: const Offset(0.5, 0.5),
              zIndexInt: 7,
              consumeTapEvents: true,
              onTap: () => _zoomToCluster(target, members: group),
            ),
          );
          continue;
        }
        final p = group.first;
        // v585 — une personne à plusieurs rôles (propriétaire + gardien…).
        final List<Map<String, dynamic>> personRoles = pawMapExpandRoles(p);
        final pos = posOfMember(p)!;
        final id = (p['id'] ?? p['_id'] ?? '').toString();
        if (id.isEmpty) continue;
        // Un membre qui est aussi un ami EN DIRECT garde son marqueur live.
        // v587 — comparé sur TOUS les ids de la personne : le direct est
        // rangé sous l'id de l'amitié (souvent un AUTRE de ses rôles), et le
        // rond de profil (position floutée ~1 km) restait affiché à côté du
        // rond direct — deux ronds pour la même personne, dont un « dans
        // l'eau ». Le direct prime et remplace l'autre.
        if (pawMapPersonIds(p)
            .any((x) => friendLiveIds.contains(x.trim().toLowerCase()))) {
          continue;
        }
        final role = (p['_role'] ?? '').toString().toLowerCase();
        final name = (p['name'] ?? '').toString();
        final bool premium = p['isPremium'] == true;
        final bool boosted = p['isBoosted'] == true;
        if (boosted) _anyBoosted = true;
        final bool online = p['isOnline'] != false && p['online'] != false;
        final bool selected = _selectedNearbyId == id;
        final bool approx = p['approx'] == true;
        final double approxKm = (p['approxKm'] as num?)?.toDouble() ?? 1.0;
        final bool verified = p['kycVerified'] == true;
        final avatar = (p['avatar'] ?? '').toString();
        // Un AMI (liste d'amis) : sa photo + anneau rose, à tous les zooms.
        // v584 (25/09) — le serveur le dit (`isFriend`, tous rôles d'une même
        // personne), l'ancienne comparaison d'ids reste en secours.
        final bool isFriend = p['isFriend'] == true ||
            _friendController.isFriendWithAny(pawMapPersonIds(p));
        // v590 — handoff §1 : prix de l'autre côté du marché seulement.
        final priceLabel = role == 'owner' ||
                !showPrice ||
                !pawMapShowsPriceBubble(_role, role)
            ? ''
            : _priceLabelFor(p);
        // v584 (25/09) — au zoom rue : « Prénom · 25 € » sous le rond.
        final String firstName = pawMapShortName(name);
        // v589 — rond touché une fois (zoom) : « Prénom · Voir le profil › »,
        // la mini bulle invite au 2e toucher.
        final bool focused = _focusTapId != null &&
            pawMapPersonIds(p).contains(_focusTapId);
        // v590 — la carte focus remplace l'étiquette « · Voir le profil ›»
        // qui débordait au zoom : le rond touché garde juste son prénom.
        final String streetLabel = focused
            ? (firstName.isEmpty ? name : firstName)
            : (!showPrice
                ? ''
                : (priceLabel.isEmpty ? firstName : '$firstName · $priceLabel'));
        // v590 — rond AVEC photo : le prix part dans la bulle colorée
        // au-dessus, l'étiquette ne garde que le prénom.
        final String? bubble = priceLabel.isEmpty ? null : priceLabel;
        final String photoLabel = focused || !showPrice
            ? streetLabel
            : (firstName.isEmpty ? name : firstName);
        final BitmapDescriptor icon;
        final Offset anchor;
        if (isFriend) {
          // v592 — Daniel : « comme le web, la petite bulle Vu il y a 5 j ».
          // Hors zoom rue, un ami porte sa dernière activité sous son rond.
          final String friendLabel =
              photoLabel.isNotEmpty ? photoLabel : _friendSeenCaption(p);
          icon = _photoIcon(
            keyPrefix: 'friend:$id',
            avatarUrl: avatar,
            ring: PawMapLegend.friend,
            size: PawMapLegend.friendSize,
            label: friendLabel.isEmpty ? null : friendLabel,
            // v592 — ami à plusieurs rôles : rose puis les anneaux de ses rôles (web).
            ringColors: personRoles.length > 1
                ? [
                    for (final r in personRoles)
                      PawMapLegend.roleColor((r['_role'] ?? '').toString())
                  ]
                : null,
            priceBubble: bubble,
            priceRole: role,
            labelColor: PawMapLegend.darken(PawMapLegend.friend, 0.25),
            crown: premium && _showPremiumLayer.value,
            online: online && !approx,
            boosted: boosted,
            fallbackIcon: PawMapLegend.roleIcon(role),
            fallbackTint: PawMapLegend.roleColor(role),
          );
          anchor = _photoAnchor(PawMapLegend.friendSize,
              withLabel: friendLabel.isNotEmpty, withBubble: bubble != null);
        } else if (personRoles.length > 1) {
          // v585 (25/09, Daniel : « la pastille 2 zoome et c'est tout ») — UN
          // rond pour la personne, liseré partagé entre ses rôles.
          icon = _photoIcon(
            keyPrefix: 'multi:$id',
            avatarUrl: avatar,
            ring: PawMapLegend.roleColor(role),
            ringColors: [
              for (final r in personRoles)
                PawMapLegend.roleColor((r['_role'] ?? '').toString()),
            ],
            size: PawMapLegend.memberSize,
            label: photoLabel.isEmpty ? null : photoLabel,
            priceBubble: bubble,
            priceRole: role,
            labelColor: PawMapLegend.darken(PawMapLegend.roleColor(role), 0.25),
            crown: premium && _showPremiumLayer.value,
            crownSize: PawMapLegend.crownMember,
            online: online && !approx,
            boosted: boosted,
            fallbackIcon: PawMapLegend.roleIcon(role),
            fallbackTint: PawMapLegend.roleColor(role),
          );
          anchor = _photoAnchor(PawMapLegend.memberSize,
              withLabel: photoLabel.isNotEmpty, withBubble: bubble != null);
        } else if (avatar.startsWith('http')) {
          // v584 (25/09, Daniel : « mets plus en valeur les utilisateurs ») —
          // la PHOTO du membre dans un rond à la couleur de son rôle.
          icon = _photoIcon(
            keyPrefix: 'member:$id',
            avatarUrl: avatar,
            ring: PawMapLegend.roleColor(role),
            size: PawMapLegend.memberSize,
            label: photoLabel.isEmpty ? null : photoLabel,
            priceBubble: bubble,
            priceRole: role,
            labelColor: PawMapLegend.darken(PawMapLegend.roleColor(role), 0.25),
            crown: premium && _showPremiumLayer.value,
            crownSize: PawMapLegend.crownMember,
            online: online && !approx,
            boosted: boosted,
            fallbackIcon: PawMapLegend.roleIcon(role),
            fallbackTint: PawMapLegend.roleColor(role),
          );
          anchor = _photoAnchor(PawMapLegend.memberSize,
              withLabel: photoLabel.isNotEmpty, withBubble: bubble != null);
        } else {
          icon = _memberIcon(
            role: role,
            crown: premium && _showPremiumLayer.value,
            boosted: boosted,
            verified: verified,
            online: online && !approx,
            selected: selected,
            priceLabel: photoLabel,
            rating: (p['rating'] as num?)?.toDouble() ?? 0,
            priceBubble: bubble,
          );
          anchor = Offset(
              0.5,
              PawMapPinPainter.memberAnchorY(PawMapLegend.memberSize,
                  withLabel: photoLabel.isNotEmpty, withBubble: bubble != null));
        }
        markers.add(
          Marker(
            markerId: MarkerId('nearby_$id'),
            position: pos,
            icon: icon,
            anchor: anchor,
            // v584 — boosté = visible en premier (point 16).
            zIndexInt: selected ? 9 : (isFriend ? 8 : (boosted ? 7 : 6)),
            // v590 — handoff §2 : on gère nous-mêmes le zoom (sinon Google
            // Maps recentre aussi la carte et les deux animations se battent).
            consumeTapEvents: true,
            onTap: () => personRoles.length > 1
                ? _openClusterList(
                    members: personRoles, places: const [], spots: const [])
                : _onNearbyTap(
              fromMarker: true,
              id: id,
              role: role,
              name: name,
              online: online,
              premium: premium,
              lat: pos.latitude,
              lng: pos.longitude,
              avatar: avatar,
              approx: approx,
              approxKm: approxKm,
              rating: (p['rating'] as num?)?.toDouble() ?? 0,
              reviewsCount: (p['reviewsCount'] as num?)?.toInt() ?? 0,
              priceFrom: (p['priceFrom'] as num?)?.toDouble() ?? 0,
              currency: (p['currency'] ?? 'EUR').toString(),
              verified: verified,
              boosted: boosted,
              availableToday: p['availableToday'] == true,
              isFriend: isFriend,
              personIds: pawMapPersonIds(p),
            ),
          ),
        );
      }
    }

    // ── LIEUX : goutte à la couleur du type ; groupe = carré blanc ──
    if (_showPois.value) {
      final poiGroups = _clusterize<MapPOI>(
        _poiController.visiblePois.toList(),
        (poi) => LatLng(poi.latitude, poi.longitude),
      );
      for (final group in poiGroups) {
        if (group.length > 1) {
          final target = _centroid<MapPOI>(
              group, (poi) => LatLng(poi.latitude, poi.longitude));
          // Type DOMINANT du groupe → couleur du bord et du nombre.
          final counts = <String, int>{};
          for (final p in group) {
            counts[p.category] = (counts[p.category] ?? 0) + 1;
          }
          final dominant = (counts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first
              .key;
          markers.add(
            Marker(
              markerId: MarkerId('pcluster_${target.latitude.toStringAsFixed(4)}'
                  '_${target.longitude.toStringAsFixed(4)}_${group.length}'),
              position: target,
              icon: _placeClusterIcon(group.length, dominant),
              anchor: const Offset(0.5, 0.5),
              zIndexInt: 4,
              consumeTapEvents: true,
              onTap: () => _zoomToCluster(target, places: group),
            ),
          );
          continue;
        }
        final poi = group.first;
        markers.add(
          Marker(
            markerId: MarkerId('poi_${poi.id}'),
            position: LatLng(poi.latitude, poi.longitude),
            icon: _placeIcon(poi.category),
            anchor: _dropAnchor(PawMapLegend.placeSize),
            zIndexInt: 3,
            onTap: () => _showPoiBottomSheet(poi),
          ),
        );
      }
    }

    // ── PAWSPOTS : goutte noire liserée du type, dorée si golden ; groupe =
    // carré noir chiffre or ──
    if (_showPawSpots.value) {
      // v592 — Daniel : « les PawSpots, surtout en groupe, je dois ultra
      // zoomer ». Cellule plus petite (44 px) et, dès le zoom quartier (13),
      // seuls les spots quasi superposés (18 px) restent groupés.
      final spotGroups = _clusterize<PawSpotModel>(
        _pawSpotController.spots.toList(),
        (s) => LatLng(s.lat, s.lng),
        cellPx: _zoomLevel >= 13 ? 18 : 44,
      );
      for (final group in spotGroups) {
        if (group.length > 1) {
          final target =
              _centroid<PawSpotModel>(group, (s) => LatLng(s.lat, s.lng));
          markers.add(
            Marker(
              markerId: MarkerId('scluster_${target.latitude.toStringAsFixed(4)}'
                  '_${target.longitude.toStringAsFixed(4)}_${group.length}'),
              position: target,
              icon: _spotClusterIcon(group.length),
              anchor: const Offset(0.5, 0.5),
              zIndexInt: 5,
              consumeTapEvents: true,
              onTap: () => _zoomToCluster(target, spots: group),
            ),
          );
          continue;
        }
        final spot = group.first;
        final size =
            spot.isGolden ? PawMapLegend.spotGoldSize : PawMapLegend.spotSize;
        markers.add(
          Marker(
            markerId: MarkerId('pawspot_${spot.id}'),
            position: LatLng(spot.lat, spot.lng),
            anchor: _dropAnchor(size),
            // v590 — handoff §6 : au-dessus des lieux et des signalements.
            zIndexInt: spot.isGolden ? 6 : 5,
            icon: _spotIcon(spot.type, spot.isGolden),
            // v592 — Daniel (capture) : la bulle Google « nom / type » restait
            // ouverte et cachait le PawSpot voisin ; la fiche s'ouvre déjà au
            // toucher, la bulle est retirée.
            onTap: () => _showPawSpotDetail(spot),
          ),
        );
      }
    }

    // ── SIGNALEMENTS (inchangés : emoji du type, 48 h) ──
    if (_showReports.value) {
      for (final r in _reportController.reports) {
        if (r.isExpired) continue;
        final emojiIcon = _reportEmojiMarkers[r.type];
        if (emojiIcon == null) _ensureEmojiMarker(r.type);
        markers.add(
          Marker(
            markerId: MarkerId('report_${r.id}'),
            position: LatLng(r.latitude, r.longitude),
            icon: emojiIcon ??
                BitmapDescriptor.defaultMarkerWithHue(_hueForReport(r.type)),
            onTap: () => _showReportBottomSheet(r),
          ),
        );
      }
    }

    // ── AMIS EN DIRECT : leur photo, anneau rose, point vert ──
    if (_showFriends.value && _showLiveLayer.value) {
      final friendById = {
        for (final f in _friendController.friends)
          if (f.other != null) f.other!.id: f,
      };
      final familyById = {
        for (final m in _friendController.familyMembers)
          ((m['id'] ?? m['userId'] ?? '').toString()).trim().toLowerCase(): m,
      };
      final premiumMemberIds = !_showPremiumLayer.value
          ? <String>{}
          : (<String>{
              ..._friendController.familyMembers
                  .where((m) => m['isPremium'] == true)
                  .map((m) => ((m['id'] ?? m['userId'] ?? '')
                      .toString())
                      .trim()
                      .toLowerCase()),
              ..._friendController.friends
                  .where((f) => f.other?.isPremium == true)
                  .map((f) => (f.other?.id ?? '').trim().toLowerCase()),
            }..removeWhere((id) => id.isEmpty));
      for (final pos in _liveMap.friendPositions.values) {
        // v584 (25/09, Daniel) : « si quelqu'un se déplace, on ne peut pas
        // garder la vieille position ». Sans partage actif et récent, PAS de
        // rond « en direct » : il reste la position de profil (couche monde).
        if (pos.liveState == FriendLiveState.seen) continue;
        final friend = friendById[pos.userId];
        final famMember = friend == null
            ? familyById[pos.userId.trim().toLowerCase()]
            : null;
        final famName = (famMember?['name'] ?? '').toString();
        final displayName = friend?.other!.name ??
            (famName.isNotEmpty ? famName : null) ??
            widget.focusUserName ??
            '—';
        final famRole = (famMember?['role'] ?? '').toString();
        final role = (friend?.other?.model ??
                (famRole.isNotEmpty ? famRole : pos.role))
            .toLowerCase();
        final famAvatar = (famMember?['avatar'] ?? '').toString();
        final avatarUrl = friend?.other?.avatar ??
            (famAvatar.isNotEmpty ? famAvatar : '');
        final normPosId = pos.userId.trim().toLowerCase();
        final isPremiumMember = premiumMemberIds.contains(normPosId);
        markers.add(
          Marker(
            markerId: MarkerId('friend_${pos.userId}'),
            position: LatLng(pos.latitude, pos.longitude),
            icon: _photoIcon(
              keyPrefix: 'live:${pos.userId}',
              avatarUrl: avatarUrl,
              ring: PawMapLegend.friend,
              size: PawMapLegend.friendSize,
              crown: isPremiumMember,
              online: pos.isLive,
              // Signal perdu : rond « éteint » à la couleur du rôle, jamais gris.
              dimmed: pos.isLost,
              // v584 — auréole violette qui respire sur la personne SUIVIE.
              followPhase: _followUserId != null &&
                      _followUserId!.trim().toLowerCase() == normPosId &&
                      !_reduceMotion
                  ? _boostPhaseIdx
                  : (_followUserId != null &&
                          _followUserId!.trim().toLowerCase() == normPosId
                      ? 0
                      : -1),
              label: _focusTapId == pos.userId || _zoomLevel >= _priceZoom
                  ? pawMapShortName(displayName)
                  : null,
              fallbackTint: PawMapLegend.roleColor(role),
            ),
            anchor: _photoAnchor(PawMapLegend.friendSize,
                withLabel: _zoomLevel >= _priceZoom || _focusTapId == pos.userId),
            zIndexInt: 9, // v587 — le direct au-dessus de tout (sauf Moi)
            consumeTapEvents: true, // v590 — zoom géré par la carte focus
            // v584 (25/09, point 14) — taper un ami ouvre SA FICHE, avec
            // « Suivre la balade · en direct » en bouton principal (plus de
            // suivi lancé à l'insu de l'utilisateur).
            onTap: () => _onNearbyTap(
              fromMarker: true,
              id: pos.userId,
              role: role,
              name: displayName,
              online: pos.isLive,
              premium: isPremiumMember,
              lat: pos.latitude,
              lng: pos.longitude,
              avatar: avatarUrl,
              isFriend: true,
              liveState: pos.isLost ? PawFollowState.lost : PawFollowState.live,
            ),
          ),
        );
      }
    }

    // ── DEMANDES DES PROPRIÉTAIRES : bulle orange foncé, ~1 km ──
    if (_showRequests.value) {
      if (_isSitterOrWalker) {
        for (final req in _requests) {
          final walking = req.serviceTypes.contains('dog_walking');
          markers.add(
            Marker(
              markerId: MarkerId('req_${req.id}'),
              position: LatLng(req.lat, req.lng),
              icon: _requestIcon(
                priceLabel: req.budgetLabel,
                walking: walking,
              ),
              anchor: _requestAnchor,
              zIndexInt: 7,
              // v590 — handoff : 1er appui = zoom + carte focus
              // (« 2 nuits · 30 € »), 2e appui = la fiche de la demande.
              consumeTapEvents: true,
              onTap: () => _onRequestMarkerTap(req),
            ),
          );
        }
      } else {
        // Le propriétaire voit les SIENNES, marquées « Ma demande ».
        for (final req in _myRequests) {
          final walking = req.serviceTypes.contains('dog_walking');
          markers.add(
            Marker(
              markerId: MarkerId('myreq_${req.id}'),
              position: LatLng(req.lat, req.lng),
              icon: _requestIcon(
                walking: walking,
                mineLabel: 'pawmap_request_mine'.tr,
              ),
              anchor: _requestAnchor,
              zIndexInt: 7,
              onTap: () => _showRequestBottomSheet(req, mine: true),
            ),
          );
        }
      }
    }
    return markers;
  }

  void _onRequestMarkerTap(NearbyRequestPost req) {
    final key = 'req:${req.id}';
    if (_isSecondTap(key)) {
      _clearFocus();
      _showRequestBottomSheet(req);
      return;
    }
    final String dates = _requestDateLabel(req);
    final String budget = req.budgetLabel;
    _focusFirstTap(
      LatLng(req.lat, req.lng),
      PawFocusInfo(
        key: key,
        name: '${pawMapShortName(req.ownerName)} · ${'pawmap590_request'.tr}',
        role: 'owner',
        info: [
          if (dates.isNotEmpty) dates,
          if (budget.isNotEmpty) budget,
        ].join(' · '),
        avatar: req.ownerAvatar,
        icon: PawSymbols.home,
        onOpen: () {
          _clearFocus();
          _showRequestBottomSheet(req);
        },
      ),
    );
  }

  /// Candidatures déjà envoyées depuis la carte (postId → état), pour ne pas
  /// proposer deux fois et afficher « Déjà proposé » au réouvrement.
  final Map<String, PawProposeState> _proposeStates = {};

  String _requestDateLabel(NearbyRequestPost r) {
    final locale = Get.locale?.toString();
    String fmt(DateTime d) => DateFormat.MMMd(locale).format(d.toLocal());
    final s = r.startDate;
    final e = r.endDate;
    if (s == null && e == null) return '';
    if (s != null && e != null && !s.isAtSameMomentAs(e)) {
      return 'pawmap_request_dates'.trParams({'from': fmt(s), 'to': fmt(e)});
    }
    return fmt(s ?? e!);
  }

  /// v584 — bulle orange d'une demande : « Proposer mes services » en UN
  /// appui (idée 3 validée) ; le propriétaire est notifié tout de suite
  /// (même route que l'accueil : POST /applications). [mine] = ma propre
  /// demande (« Ma demande ») → « Voir mes annonces ».
  void _showRequestBottomSheet(NearbyRequestPost r, {bool mine = false}) {
    final walking = r.serviceTypes.contains('dog_walking');
    showPawMapSheet<void>(
      context,
      StatefulBuilder(
        builder: (ctx, setSheet) => PawMapRequestSheet(
          ownerName: r.ownerName,
          ownerAvatar: r.ownerAvatar,
          walking: walking,
          city: r.city,
          distanceLabel: mine
              ? ''
              : (r.distanceKm > 0 ? '${r.distanceKm.toStringAsFixed(1)} km' : ''),
          dateLabel: _requestDateLabel(r),
          // v587 (point 8) — où se passe le service (chez moi, point de RDV…).
          locationLabel: serviceLocationDisplay(r.serviceLocation,
              meetingPoint: r.meetingPoint),
          budgetLabel: r.budgetLabel,
          body: r.body,
          mine: mine,
          approx: r.approx,
          viewerRole: _role,
          proposeState: _proposeStates[r.id] ?? PawProposeState.idle,
          onOpenMine: () {
            Navigator.of(ctx).pop();
            openMainTabOr(0, () => const PawMapScreen());
          },
          onOwnerProfile: () {
            Navigator.of(ctx).pop();
            _onNearbyTap(
              id: r.ownerId,
              role: 'owner',
              name: r.ownerName,
              online: false,
              premium: false,
              avatar: r.ownerAvatar,
              approx: true,
            );
          },
          onPropose: () async {
            if (!_viewerLoggedIn) {
              Navigator.of(ctx).pop();
              await SignupWallSheet.show(
                  trigger: 'booking', recommendedRole: 'pet_sitter');
              return;
            }
            setSheet(() => _proposeStates[r.id] = PawProposeState.busy);
            final state = await _proposeServices(r);
            if (!ctx.mounted) return;
            setSheet(() => _proposeStates[r.id] = state);
          },
        ),
      ),
    );
  }

  /// Envoie la candidature (même contrat que le bouton de l'accueil
  /// gardien / promeneur) : animal de l'annonce, service, date, créneau,
  /// mon tarif de base ; `postId` pour retrouver la candidature.
  Future<PawProposeState> _proposeServices(NearbyRequestPost r) async {
    if (!Get.isRegistered<SitterRepository>()) return PawProposeState.idle;
    if (r.petIds.isEmpty) {
      CustomSnackbar.showError(
          title: 'common_error'.tr, message: 'pawmap_request_no_pets'.tr);
      return PawProposeState.idle;
    }
    try {
      final repo = Get.find<SitterRepository>();
      final basePrice = await _myBasePrice(repo);
      if (basePrice <= 0) {
        CustomSnackbar.showError(
            title: 'common_error'.tr,
            message: 'pawmap_request_pricing_missing'.tr);
        return PawProposeState.idle;
      }
      final serviceType = r.serviceTypes.isNotEmpty
          ? r.serviceTypes.first
          : (_role == 'walker' ? 'dog_walking' : 'pet_sitting');
      final start = r.startDate ?? r.endDate ?? DateTime.now();
      final serviceDate = start
          .toUtc()
          .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
          .toIso8601String();
      String timeSlot = 'All Day';
      final ls = r.startDate?.toLocal();
      if (ls != null) {
        final h12 = ls.hour % 12 == 0 ? 12 : ls.hour % 12;
        timeSlot =
            '$h12:${ls.minute.toString().padLeft(2, '0')} ${ls.hour < 12 ? 'AM' : 'PM'}';
      }
      final res = await repo.createApplication(
        ownerId: r.ownerId,
        petIds: [r.petIds.first],
        serviceType: serviceType,
        serviceDate: serviceDate,
        startDate: r.startDate?.toUtc().toIso8601String(),
        endDate: r.endDate?.toUtc().toIso8601String(),
        timeSlot: timeSlot,
        basePrice: basePrice,
        postId: r.id,
      );
      final dup = res['duplicatePrevented'] == true;
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: dup ? 'pawmap_request_already'.tr : 'request_send_success'.tr,
      );
      return dup ? PawProposeState.already : PawProposeState.sent;
    } catch (e) {
      final msg = e.toString();
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: msg.contains('ALREADY') || msg.contains('duplicate')
            ? 'pawmap_request_already'.tr
            : 'request_send_failed'.tr,
      );
      return msg.contains('ALREADY') || msg.contains('duplicate')
          ? PawProposeState.already
          : PawProposeState.idle;
    }
  }

  /// Mon tarif de base (même règle que l'accueil : promeneur = grille de
  /// promenades ramenée à l'heure ; gardien = horaire, sinon journalier…).
  Future<double> _myBasePrice(SitterRepository repo) async {
    try {
      final profile =
          GetStorage().read<Map<String, dynamic>>(StorageKeys.userProfile);
      final myId = (profile?['id'] ?? '').toString();
      if (myId.isEmpty) return 0;
      if (_role == 'walker' && Get.isRegistered<WalkerRepository>()) {
        final w = await Get.find<WalkerRepository>().getWalkerProfile(myId);
        double? rate(int min) {
          for (final r in w.walkRates) {
            if (r.durationMinutes == min && r.enabled && r.basePrice > 0) {
              return r.basePrice;
            }
          }
          return null;
        }

        return rate(60) ??
            (rate(30) != null ? rate(30)! * 2 : null) ??
            (rate(90) != null ? rate(90)! * (60 / 90) : null) ??
            (rate(120) != null ? rate(120)! / 2 : null) ??
            0;
      }
      final p = await repo.getSitterProfile(myId);
      final data = (p['sitter'] as Map<String, dynamic>?) ??
          (p['profile'] as Map<String, dynamic>?) ??
          p;
      for (final k in const ['hourlyRate', 'dailyRate', 'weeklyRate', 'monthlyRate']) {
        final v = (data[k] as num?)?.toDouble();
        if (v != null && v > 0) return v;
      }
      final s = double.tryParse((data['rate'] ?? '').toString());
      if (s != null && s > 0) return s;
    } catch (e) {
      debugPrint('[PawMap] tarif de base : $e');
    }
    return 0;
  }

  /// v584 — mes propres demandes ouvertes (propriétaire) : bulles « Ma
  /// demande » à leur position (c'est moi, donc position exacte).
  Future<void> _loadMyRequests() async {
    try {
      final api = Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : null;
      if (api == null) return;
      final res = await api.get('/posts/my', requiresAuth: true);
      final list = ((res as Map?)?['posts'] as List?) ?? const [];
      final out = <NearbyRequestPost>[];
      for (final j in list) {
        if (j is! Map) continue;
        if ((j['postType'] ?? 'request').toString() != 'request') continue;
        if ((j['status'] ?? 'open').toString() == 'closed') continue;
        final p = NearbyRequestPost.fromJson(Map<String, dynamic>.from(j));
        if (p.lat != 0 || p.lng != 0) out.add(p);
      }
      _myRequests.assignAll(out);
    } catch (e) {
      debugPrint('[PawMap] mes demandes : $e');
    }
  }
  /// v592 — « Vu il y a 5 j » sous le rond d'un ami (dernier signe de vie
  /// connu, `lastSeenAt` de la liste d'amis, tous ses profils). « En ligne »
  /// s'il a été vu il y a moins d'une minute. Vide si inconnu.
  String _friendSeenCaption(Map<String, dynamic> p) {
    final ids = pawMapPersonIds(p);
    DateTime? seen;
    for (final f in _friendController.friends) {
      final o = f.other;
      if (o == null || o.lastSeenAt == null) continue;
      if (!ids.any(o.matchesId)) continue;
      if (seen == null || o.lastSeenAt!.isAfter(seen)) seen = o.lastSeenAt;
    }
    if (seen == null) return '';
    if (DateTime.now().difference(seen).inMinutes < 1) {
      return 'pawmap_time_just_now'.tr;
    }
    return 'pawmap_seen_ago'.tr.replaceAll('{ago}', _timeAgo(seen));
  }

  String _timeAgo(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'pawmap_time_just_now'.tr;
    if (diff.inMinutes < 60) return 'pawmap_time_min_short'.trParams({'n': diff.inMinutes.toString()});
    if (diff.inHours < 24) return 'pawmap_time_hours_short'.trParams({'n': diff.inHours.toString()});
    return 'pawmap_time_days_short'.trParams({'n': diff.inDays.toString()});
  }

  double _hueForPoi(String category) {
    switch (category) {
      case PoiCategories.vet:
        return BitmapDescriptor.hueRed;
      case PoiCategories.park:
        return BitmapDescriptor.hueGreen;
      case PoiCategories.water:
        return BitmapDescriptor.hueCyan;
      case PoiCategories.shop:
        return BitmapDescriptor.hueViolet;
      case PoiCategories.groomer:
        return BitmapDescriptor.hueMagenta;
      default:
        return BitmapDescriptor.hueAzure;
    }
  }

  double _hueForReport(String type) {
    switch (type) {
      case ReportTypes.poop:
      case ReportTypes.pee:
        return BitmapDescriptor.hueYellow;
      case ReportTypes.hazard:
      case ReportTypes.aggressiveDog:
        return BitmapDescriptor.hueRed;
      case ReportTypes.waterActive:
        return BitmapDescriptor.hueCyan;
      case ReportTypes.waterBroken:
        return BitmapDescriptor.hueOrange;
      case ReportTypes.lostPet:
      case ReportTypes.foundPet:
        return BitmapDescriptor.hueRose;
      default:
        return BitmapDescriptor.hueOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    // v23.1.300 — Daniel : "quand je fais retour, ça m'ouvre la page amis en
    // direct au lieu de me remettre le menu". Quand on SUIT un ami à la trace
    // (PawMap empilée par-dessus people-live), le 1er retour SORT du suivi et
    // RESTE sur la carte (avec le menu) au lieu de dépiler vers l'écran
    // précédent. Un 2e retour dépile normalement.
    // v552 — Daniel (spec redesign v3, bug critique n°1) : « le bouton retour
    // d'Android ferme l'app quand la carte est en grand ». La carte agrandie
    // est un ÉTAT du même écran, pas une route : le retour tombait donc sur la
    // racine de l'onglet et quittait l'app. Ordre attendu :
    //   retour → sort d'un mode en cours (viseur, suivi)
    //          → sinon réduit la carte agrandie
    //          → sinon comportement système (quitter / dépiler).
    // v586 (précision de Daniel) — au repos, AUCUNE bande derrière la
    // poignée ni derrière le menu : la CARTE va jusqu'en bas de l'écran. Sur
    // l'onglet PawMap seulement, la barre système (3 boutons) devient
    // transparente, sans voile de contraste ; les autres onglets gardent la
    // barre teintée du rôle (v465/v469).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            _nightMode.value ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness:
            _nightMode.value ? Brightness.light : Brightness.dark,
      ),
      child: PopScope(
      canPop: _followUserId == null &&
          _sheetIsLow &&
          !_pickingSpotPos.value &&
          !_pickingRoutePos.value &&
          !_pickingReportPos.value,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // v586 — retour avec la feuille ouverte = la ranger.
        if (!_sheetIsLow) {
          unawaited(_sheetTo(PawSheetStop.low));
          return;
        }
        if (_pickingSpotPos.value ||
            _pickingReportPos.value ||
            _pickingRoutePos.value) {
          _pickingSpotPos.value = false;
          _pickingRoutePos.value = false;
          _pickingReportPos.value = false;
          _pickedSpotPos = null;
          if (mounted) setState(() {});
          return;
        }
        if (_followUserId != null) {
          _stopFollow();
          return;
        }
      },
      // v584 (lot C du chantier du 24/09) — UNE SEULE GoogleMap.
      //
      // Avant : deux cartes — la « normale » dans le corps du Scaffold et un
      // calque « agrandi » plein écran avec SA propre GoogleMap et SON propre
      // contrôleur (v463/v469). Chaque animation de caméra, chaque recherche
      // de ville, chaque itinéraire devait viser « la bonne » carte, et le
      // suivi d'un ami ne s'arrêtait pas au glissement sur la grande (pas de
      // `onCameraMoveStarted`). La fusion, validée par Daniel (« JE GARDE
      // TOUT ») : la carte occupe TOUT l'écran en permanence (le corps passe
      // derrière la barre d'état et, côté menu, le wrapper est déjà en
      // `extendBody`) ; « agrandir » ne change plus que les COMMANDES posées
      // par-dessus (en-tête, panneau, rails, dock, bouton retour) et masque le
      // menu du bas (`pawMapExpanded`, observé par le wrapper). La GoogleMap
      // n'est donc jamais redimensionnée ni recréée : zéro carte blanche.
      child: Scaffold(
        backgroundColor: AppColors.scaffold(context),
        extendBodyBehindAppBar: true,
        // ⚠️ Mesuré au simulateur (parcours integration_test, 24/09) : le
        // corps du Scaffold reçoit des contraintes LÂCHES ; une Stack qui
        // n'a que des enfants positionnés et des `SizedBox.shrink()` (les
        // Obx éteints) prenait la taille de son plus grand enfant NON
        // positionné : 0 × 0 → carte invisible. `SizedBox.expand` lui impose
        // la taille de l'écran (ce que faisait l'ancien `Expanded`).
        body: SizedBox.expand(
          // v586 — au PREMIER appui, où qu'il soit, les commandes effacées
          // pendant un geste reviennent tout de suite.
          child: Listener(
            onPointerDown: (_) => _restoreChrome(),
            behavior: HitTestBehavior.translucent,
            child: Stack(
          children: [
            // ── LA carte (unique) : toujours premier enfant, toujours à la
            // même place dans l'arbre, avec une clé → jamais recréée.
            // v586 — un vrai geste sur la carte (glisser, pincer) efface
            // les commandes à 35 % ; elles reviennent 1 s après le lâcher.
            Positioned.fill(
              key: const ValueKey<String>('pawmap_google_map'),
              child: Listener(
                onPointerDown: _onMapPointerDown,
                onPointerMove: _onMapPointerMove,
                onPointerUp: _onMapPointerEnd,
                onPointerCancel: _onMapPointerEnd,
                child: _buildGoogleMap(),
              ),
            ),
            // v592 — mention légale d'OpenStreetMap (obligatoire) quand le
            // fond détaillé est affiché : discrète, au-dessus du logo Google.
            Positioned(
              left: 72.w,
              bottom: _menuInset(context) + _sheetPeekPx + 30.h,
              child: Obx(() => !_osmActive
                  ? const SizedBox.shrink()
                  : IgnorePointer(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text('pawmap592_osm_credit'.tr,
                            style: TextStyle(
                                fontSize: 8.5.sp,
                                color: PawMapTheme.ink)),
                      ),
                    )),
            ),



            // v456 — POINT ROUGE FIXE au centre (placement précis), pour les
            // viseurs (Paw Spot, Signalement, Itinéraire). La carte bouge SOUS
            // le repère ; à Valider il disparaît et seul l'emoji reste.
            Obx(() => (_pickingSpotPos.value ||
                    _pickingReportPos.value ||
                    _pickingRoutePos.value)
                ? _buildCenterReticle()
                : const SizedBox.shrink()),
            Obx(() => _pickingRoutePos.value
                ? _buildRoutePickerOverlay()
                : const SizedBox.shrink()),
            Obx(() => _pickingSpotPos.value
                ? _buildSpotPickerOverlay()
                : const SizedBox.shrink()),
            Obx(() => _pickingReportPos.value
                ? _buildReportPickerOverlay()
                : const SizedBox.shrink()),

            // ── Rangée des rails (gauche : actions · droite : capsule) ──
            // Baseline FIXE (point 20, v565) : petite carte au-dessus du menu
            // flottant ; carte agrandie au-dessus du dock. Pendant un
            // placement le rail gauche s'efface (ses boutons sont l'action en
            // cours) et la rangée monte pour laisser respirer Annuler/Valider.
            // v584 (25/09) — Daniel : « on avait dit UNE carte, il y a
            // toujours les deux ». Le mode « Agrandir / Réduire » (rangée du
            // haut, dock, bouton Retour, rails décalés — là où les boutons
            // étaient COUPÉS sur son Samsung) est SUPPRIMÉ : une seule carte,
            // un seul rail, une seule feuille, une seule mise en page.
            Obx(() {
              final picking = _pickingSpotPos.value ||
                  _pickingReportPos.value ||
                  _pickingRoutePos.value;
              // v584 — la feuille glissante recouvre les rails dès qu'elle
              // dépasse sa position basse : ils s'effacent (elle porte les
              // mêmes actions), et reviennent quand elle redescend.
              final sheetUp = !picking && _sheetUp.value;
              if (sheetUp) return const SizedBox.shrink();
              return Positioned(
                left: 12.w,
                right: 12.w,
                bottom: _railBottom(context, picking: picking),
                child: _fading(Row(
                  // v561 — Daniel : colonne de gauche alignée sur le BAS de la
                  // capsule de droite (jamais centrée).
                  crossAxisAlignment: CrossAxisAlignment.end,
                  // v587 (point 3) — chaque barre se range hors écran d'un
                  // appui sur sa flèche (languette au bord), état retenu sur
                  // le compte (`pawMap.railCollapsed` / `capsuleCollapsed`).
                  children: [
                    if (!picking)
                      PawCollapsibleBar(
                        left: true,
                        collapsed: _prefs.railCollapsed,
                        tint: PawMapLegend.roleColor(_role.isEmpty ? 'owner' : _role),
                        edgeGap: 12.w,
                        tabBottom: 18.h,
                        onToggle: () => _prefs.update(
                            {'railCollapsed': !_prefs.railCollapsed}),
                        child: _railScroller(_buildMapActionsColumn()),
                      ),
                    const Spacer(),
                    PawCollapsibleBar(
                      left: false,
                      collapsed: _prefs.capsuleCollapsed,
                      tint: PawMapLegend.roleColor(_role.isEmpty ? 'owner' : _role),
                      edgeGap: 12.w,
                      tabBottom: 18.h,
                      onToggle: () => _prefs.update(
                          {'capsuleCollapsed': !_prefs.capsuleCollapsed}),
                      child: _buildMapControlsStack(),
                    ),
                  ],
                )),
              );
            }),

            // v589 — la poignée « Options » du bas est RETIRÉE (elle gênait
            // au milieu de la carte) : la roue orange de l'en-tête ouvre la
            // même feuille.

            // ── v584 — FEUILLE GLISSANTE ──
            // Trois positions : basse (poignée + bouton principal), moyenne
            // (« Je cherche », compteur, filtres), haute (actions, calques,
            // abonnements). Posée au-dessus du menu ; absente pendant un
            // placement.
            Obx(() {
              final picking = _pickingSpotPos.value ||
                  _pickingReportPos.value ||
                  _pickingRoutePos.value;
              if (picking) return const SizedBox.shrink();
              return Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: _buildSheet(),
              );
            }),

            // ── Zone entre les rails, au-dessus de la feuille ──
            // v584 (25/09) — par priorité : la PILULE DE SUIVI (quand je suis
            // quelqu'un en direct : photo, « en direct · 12 s », chevron →
            // feuille Suivre / Arrêter / Itinéraire / Message — plus aucune
            // barre violette en haut), sinon le bandeau d'itinéraire, sinon
            // la carte « Autour de vous ». Jamais pendant un placement.
            Obx(() {
              final picking = _pickingSpotPos.value ||
                  _pickingReportPos.value ||
                  _pickingRoutePos.value;
              if (picking) return const SizedBox.shrink();
              // v584 (25/09, vu au parcours Samsung) : la feuille montée
              // recouvrait le bandeau d'itinéraire (« 9,5 km · Étapes »
              // posé sur « Calques ») → cette zone s'efface avec les rails
              // dès que la feuille dépasse sa position basse.
              final sheetUp = _sheetUp.value;
              if (sheetUp) return const SizedBox.shrink();
              if (_followUserId != null) {
                return Positioned(
                  left: 72.w,
                  right: 62.w,
                  bottom: _menuInset(context) + _sheetPeekPx + 10.h,
                  child: Center(child: _buildFollowPill()),
                );
              }
              if (_routePolylines.isEmpty) {
                return Positioned(
                  left: 72.w,
                  right: 62.w,
                  bottom: _menuInset(context) + _sheetPeekPx + 8.h,
                  child: _fading(_buildAroundYouCard()),
                );
              }
              // Bandeau d'itinéraire : entre les deux rails.
              return Positioned(
                left: 12.w,
                right: 12.w,
                bottom: _menuInset(context) + _sheetPeekPx + 16.h,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 52.w),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _buildDirectionsBanner(),
                    ),
                  ),
                ),
              );
            }),

            // v585 — voile blanc chaud (encre en sombre) derrière la barre
            // d'état : ses icônes ne se mélangent plus à la carte. Ne capte
            // aucun toucher.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: math.max(MediaQuery.of(context).viewPadding.top, 28) + 18,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        (PawMapTheme.isDark(context)
                                ? const Color(0xFF1E1513)
                                : const Color(0xFFFFFBF7))
                            .withValues(alpha: 0.82),
                        (PawMapTheme.isDark(context)
                                ? const Color(0xFF1E1513)
                                : const Color(0xFFFFFBF7))
                            .withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Haut de l'écran : l'en-tête flottant SEUL (logo, titre,
            // « ? », recherche, rafraîchir). Daniel (25/09, point 12) : plus
            // aucune pastille d'état posée sur les boutons — « visible par
            // tes amis seulement », le partage en direct et le suivi vivent
            // dans la feuille (ligne d'état) ou en pilule entre les rails.
            // Masqué pendant un placement (la bulle d'aide doit rester seule).
            Obx(() {
              final picking = _pickingSpotPos.value ||
                  _pickingReportPos.value ||
                  _pickingRoutePos.value;
              if (picking) return const SizedBox.shrink();
              return Positioned(
                top: 0,
                left: 0,
                right: 0,
                // v585 (Daniel, Samsung : « en haut à gauche c'est recouvert,
                // l'icône ») — jamais contre la barre d'état : au moins 28 dp
                // même si le téléphone annonce moins (voile : voir plus haut).
                child: SafeArea(
                  bottom: false,
                  minimum: const EdgeInsets.only(top: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        key: _topAreaKey,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _fading(_buildFloatingHeader()),
                          // v587 (point 1a) — la pilule « ● Direct » sous le
                          // logo PawMap. Daniel (25/09) : « pour les 3 profils »
                          // — un propriétaire promène aussi son chien et
                          // partage avec ses amis.
                          if (pawMapShowsDirectPill(_role))
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 0),
                                child: _fading(Obx(() {
                                  final live = _liveMap.broadcasting.value;
                                  return PawMapDirectPill(
                                    live: live,
                                    followers: live ? _liveMap.myFollowers.value : 0,
                                    elsewhere: !live && _liveMap.liveElsewhere.value,
                                    startedAt: _liveMap.sessionStartedAt.value,
                                    noGps: live &&
                                        _liveMap.liveStatus.value ==
                                            LiveShareStatus.lost &&
                                        _liveMap.myLivePosition.value == null,
                                    onTap: () => unawaited(_toggleDirect()),
                                    onLongPress: () => _showCapsuleHelp('direct'),
                                  );
                                })),
                              ),
                            ),
                          // v590 — « ma mère ne voit personne » : des filtres
                          // enregistrés sur son compte cachaient les gens sans
                          // rien dire. Dès qu'un filtre cache des personnes :
                          // « Filtres actifs · Tout afficher », un appui remet tout.
                          Obx(() {
                            final hidden = _filtersHidePeople;
                            final shown = _filtersBannerShown.value;
                            if (!hidden || !shown || !_viewerLoggedIn) {
                              return const SizedBox.shrink();
                            }
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(12.w, 6.h, 12.w, 0),
                                child: _fading(PawPressable(
                                  key: const ValueKey<String>('pawmap_filters_active'),
                                  label: 'pawmap590_filters_active'.tr,
                                  onTap: () {
                                    _availableTodayOnly.value = false;
                                    _setAllSee(true);
                                  },
                                  child: Container(
                                    padding: EdgeInsets.fromLTRB(10.w, 6.h, 12.w, 6.h),
                                    decoration: BoxDecoration(
                                      color: PawMapTheme.panelOn(context),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: PawMapTheme.accent, width: 1.4),
                                      boxShadow: [
                                        BoxShadow(
                                          color: PawMapTheme.accent.withValues(alpha: 0.22),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.filter_alt_rounded,
                                            size: 15.sp, color: PawMapTheme.accent),
                                        SizedBox(width: 5.w),
                                        Text(
                                          'pawmap590_filters_active'.tr,
                                          style: PawMapTheme.fontOn(context,
                                              size: 11.5.sp, weight: FontWeight.w700),
                                        ),
                                        SizedBox(width: 6.w),
                                        Text(
                                          'pawmap590_show_all'.tr,
                                          style: PawMapTheme.font(
                                              size: 11.5.sp,
                                              weight: FontWeight.w800,
                                              color: PawMapTheme.accent),
                                        ),
                                      ],
                                    ),
                                  ),
                                )),
                              ),
                            );
                          }),
                        ],
                      ),
                      // v590 — handoff §4 : la CARTE FOCUS, fixe en haut entre
                      // les deux barres (hors de la zone mesurée : les barres
                      // ne rétrécissent pas quand elle apparaît).
                      Obx(() {
                        final f = _focusCard.value;
                        if (f == null) return const SizedBox.shrink();
                        return Padding(
                          padding: EdgeInsets.fromLTRB(66.w, 8.h, 66.w, 0),
                          child: _fading(PawFocusCard(
                            info: f,
                            onClose: () => _clearFocus(restore: true),
                          )),
                        );
                      }),
                    ],
                  ),
                ),
              );
            }),

            // ── v584 — découverte guidée (3 bulles, 3 premiers lancements) ──
            // En DERNIER : la bulle passe au-dessus de l'en-tête et de la
            // rangée Partager/Agrandir (au parcours simulateur, la rangée la
            // recouvrait et cachait son texte).
            if (_coachStep >= 0)
              PawMapCoach(
                step: _coachStep,
                onNext: _coachNext,
                onDone: _coachDone,
              ),
          ],
          ),
          ),
        ),
      ),
      ),
    );
  }

  // ─── v586 — la carte s'efface quand on la manipule (point 5) ────────────

  // v590 — handoff §7 : retour 250 ms après la fin du geste.
  final PawChromeFade _fade =
      PawChromeFade(returnAfter: const Duration(milliseconds: 250));

  /// Jamais pendant un placement (viseur) ni un suivi.
  bool get _fadeAllowed =>
      !_pickingSpotPos.value &&
      !_pickingReportPos.value &&
      !_pickingRoutePos.value &&
      _followUserId == null;

  /// v587 — vrai geste sur la carte (glisser > 12 px, pincer).
  final PawMapDragWatch _dragWatch = PawMapDragWatch();

  void _onMapPointerDown(PointerDownEvent e) {
    if (_dragWatch.down(e.position)) {
      _pauseFollow();
      if (_focusCard.value != null) _clearFocus();
    }
    _fade.down(e.position, allowed: _fadeAllowed);
  }

  void _onMapPointerMove(PointerMoveEvent e) {
    if (_dragWatch.move(e.position)) {
      _pauseFollow();
      // v590 — début de déplacement : le focus s'annule (handoff §2).
      if (_focusCard.value != null) _clearFocus();
    }
    _fade.move(e.position, allowed: _fadeAllowed);
  }

  void _onMapPointerEnd(PointerEvent e) {
    _dragWatch.end();
    _fade.end();
  }
  void _restoreChrome() => _fade.restore();

  /// Enveloppe d'une commande posée sur la carte : 35 % pendant un geste
  /// (fondu 150 ms), 100 % sinon. Reste touchable.
  // v590 — handoff §7 : opacité 0,2 pendant un geste, fondu 300 ms.
  Widget _fading(Widget child) => Obx(() => AnimatedOpacity(
        opacity: _fade.faded.value ? 0.2 : 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        child: child,
      ));

  /// v584 — ligne de base (depuis le bas) de la rangée des rails : au-dessus
  /// de la feuille glissante en position basse ; 284 pendant un placement
  /// (au-dessus de la carte Annuler/Valider). Une seule mise en page (25/09).
  double _railBottom(BuildContext context, {required bool picking}) {
    if (picking) {
      return 284.h - _tabBarLift(context) + _systemBottomInset(context);
    }
    // v589 — Daniel : « on regagne toute la bande du bas, baisse un peu les
    // barres ». La languette « Options » (qui réservait `_sheetPeekPx` au-dessus
    // du menu) est partie : les deux barres descendent juste au-dessus du menu.
    // Elles sont sur les bords, la patte du menu est au centre : aucun contact.
    return _menuInset(context) + 12.h;
  }

  /// v584 — en-tête flottant de la petite carte (remplace l'AppBar : la carte
  /// passe dessous, il ne la redimensionne jamais). Logo patte-épingle dans
  /// sa tuile (v573/v575), titre Poppins, recherche de ville, rafraîchir.
  Widget _buildFloatingHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 6.h, 12.w, 0),
      child: Row(
        children: [
          // v590 — handoff §3.5 : l'icône de l'app (et ses doigts animés)
          // dans une pastille de verre, « Paw » à la couleur du texte et
          // « Map » en dégradé rouge-orange.
          Container(
            height: 50,
            padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
            decoration: BoxDecoration(
              color: PawMapTheme.isDark(context)
                  ? const Color(0xE01C191F)
                  : const Color(0xE6FFFAF7),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: PawMapTheme.isDark(context)
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFF78281E).withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.30),
                  blurRadius: 22,
                  spreadRadius: -10,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PawMapHeaderBadge(size: 40),
                const SizedBox(width: 8),
                Text(
                  'Paw',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: PawMapTheme.isDark(context)
                        ? const Color(0xFFF6F1EE)
                        : const Color(0xFF1B1616),
                  ),
                ),
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (r) => const LinearGradient(
                    colors: [Color(0xFFF0684A), Color(0xFFC9281B)],
                  ).createShader(r),
                  child: Text(
                    'Map',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // v23.1.189 — recherche de ville (loupe) + mettre à jour (v554 :
          // spinner à la place du bouton pendant le rechargement).
          // v584 — « ? » : la légende en images (Daniel : « que les gens
          // comprennent ce qu'ils font »).
          _headerRoundButton(
            key: const ValueKey<String>('pawmap_header_legend'),
            icon: PawSymbols.help,
            label: 'pawmap_legend_btn'.tr,
            onTap: _openLegend,
          ),
          SizedBox(width: 2.w),
          _headerRoundButton(
            key: const ValueKey<String>('pawmap_header_search'),
            icon: PawSymbols.search,
            label: 'pawmap_search_city'.tr,
            onTap: _onSearchCity,
          ),
          SizedBox(width: 2.w),
          Obx(() => _refreshing.value
              ? SizedBox(
                  width: 42.w,
                  height: 42.w,
                  child: Center(
                    child: SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ),
                )
              : _headerRoundButton(
                  key: const ValueKey<String>('pawmap_header_refresh'),
                  icon: PawSymbols.refresh,
                  label: 'pawmap_appbar_refresh'.tr,
                  onTap: _manualRefresh,
                )),
          // v589 — Daniel : « le bouton flottant Options gêne quand on dézoome,
          // il est au milieu : le mettre en haut à droite, icône paramètres
          // style iPhone, même orange, à droite du bouton actualiser ».
          SizedBox(width: 2.w),
          // v591 — pastille tant qu'un filtre cache des personnes.
          Obx(() => _headerRoundButton(
                key: const ValueKey<String>('pawmap_header_options'),
                icon: PawSymbols.settings,
                label: 'pawmap589_options'.tr,
                badge: _filtersHidePeople && _viewerLoggedIn
                    ? const PawJewelDot()
                    : null,
                onTap: () => unawaited(_sheetTo(PawSheetStop.high)),
              )),
        ],
      ),
    );
  }

  /// Bouton rond de l'en-tête flottant : verre blanc (anthracite en sombre),
  /// icône à l'orange de la marque, ombre douce.
  Widget _headerRoundButton({
    Key? key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Widget? badge,
  }) {
    // v590 — handoff §3.1/§3.2 : les 4 boutons du haut à droite sont des
    // « bijoux » rouges de 40 dp pour les 3 rôles (?, loupe, actualiser,
    // réglages), icônes Material Symbols pleines.
    return PawJewel(
      key: key,
      palette: kJewelHeader,
      icon: icon,
      label: label,
      size: 40,
      badge: badge,
      onTap: onTap,
    );
  }

  /// v584 — LA GoogleMap unique (voir `build`). Un seul contrôleur
  /// (`_mapCtl`), un seul jeu de rappels, mêmes couches quel que soit le
  /// mode (normal / agrandi).
  Widget _buildGoogleMap() {
    return Obx(() {
      // Dépendances observées : la carte se reconstruit quand une couche
      // change vraiment (listes, interrupteurs, tick du halo, bitmaps prêts).
      _poiController.visiblePois.length;
      _reportController.reports.length;
      _showPois.value;
      _showReports.value;
      // v23.1 part 123 — tick halo (~1,7 fps) : la pulsation reste fluide.
      _haloPhase.value;
      // v23.1.163 — providers + interrupteur (sinon aucun halo à l'arrivée).
      _nearbyProviders.length;
      _showProviders.value;
      // v550 — couche MONDE ; v551 — filtre par type.
      _worldMembers.length;
      _memberRoles.length;
      // v23.1.353 — couche PawSpot.
      _showPawSpots.value;
      _pawSpotController.spots.length;
      // v23.1 part 248 — famille / amis (halo violet dès que la liste arrive).
      _friendController.familyMembers.length;
      _friendController.friends.length;
      // v584 — une épingle ou une photo finit de se dessiner → on la pose.
      _pins.rev.value;
      _myRequests.length;
      _availableTodayOnly.value;
      // v590 — tracé de balade animé (focus + ma balade).
      _walkPhase.value;
      _focusCard.value;
      _liveMap.myTrail.length;
      _liveMap.friendTrails.length;
      // v552 — mode nuit.
      final night = _nightMode.value;
      return GoogleMap(
        // v585 — jamais la barre native « ouvrir dans Google Maps » (Daniel :
        // « nos concurrents » ; Android : « Google Maps n'est pas installée »).
        mapToolbarEnabled: false,
        initialCameraPosition: CameraPosition(
          target: _currentCenter,
          zoom: _zoomLevel,
        ),
        onMapCreated: (c) {
          if (!_mapCtl.isCompleted) _mapCtl.complete(c);
          // v23.1 part 213 — centre initial demandé (alerte, ami, lien) :
          // on y va tout de suite, avant le recentrage GPS.
          final lat = widget.initialLat;
          final lng = widget.initialLng;
          if (lat != null && lng != null) {
            // v23.1.263 — ouverture en mode suivi : zoom au plus près.
            final z = (widget.focusUserId ?? '').isNotEmpty
                ? _followZoom
                : 16.0;
            c.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: LatLng(lat, lng), zoom: z),
              ),
            );
          }
        },
        // v23.1.363 — mode viseur : TAPER la carte place le pin exactement
        // là (spot, signalement, destination d'itinéraire).
        onTap: (latLng) {
          if (_pickingSpotPos.value ||
              _pickingReportPos.value ||
              _pickingRoutePos.value) {
            setState(() => _pickedSpotPos = latLng);
            return;
          }
          // v590 — appui sur la carte vide : le focus s'annule.
          if (_focusCard.value != null) _clearFocus();
        },
        onCameraMove: _onCameraMove,
        // v23.1.263 — un geste MANUEL coupe le suivi (sauf si c'est nous qui
        // recentrons : `_suppressFollowAutoStop`). Valait seulement sur la
        // petite carte avant la fusion ; vaut partout désormais.
        // v587 — plus rien ici : un recentrage de Google Maps (appui sur le
        // rond de l'ami, marge qui change) n'est pas un geste et mettait le
        // suivi « en pause » tout seul. La pause vient du VRAI geste (glisser
        // > 12 px ou pincer), lu par `_onMapPointer*` (PawMapDragWatch).
        onCameraIdle: _scheduleReload,
        myLocationEnabled: true,
        // v23.1 part 68 — nos propres commandes (capsule droite).
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        // v584 — le logo Google et les cibles de caméra évitent le menu du
        // bas ET la feuille en position basse (vu au parcours Samsung : le
        // logo passait sous la feuille) : la carte, elle, ne change pas de
        // taille.
        // v585 — et le logo Google (mention légale du SDK, à laisser
        // VISIBLE) sort de sous le rail gauche : décalé à sa droite.
        padding: EdgeInsets.only(
            left: 70.w,
            bottom: _menuInset(context) + _sheetPeekPx + 6.h),
        mapType: _mapType,
        style: night ? _nightMapStyle : null,
        tileOverlays: _osmActive
            ? <TileOverlay>{
                TileOverlay(
                  tileOverlayId: const TileOverlayId('pawmap_osm'),
                  tileProvider: _osmTiles,
                  zIndex: 0,
                ),
              }
            : const <TileOverlay>{},
        // v23.1 part 243 round 3 — marqueurs mémoïsés (_getMarkersFromCache).
        markers: _routeStepMarkers.isEmpty
            ? _getMarkersFromCache()
            : {..._getMarkersFromCache(), ..._routeStepMarkers},
        circles: {..._buildHaloCircles(), ..._walkStartCircles()},
        // v23.1.353 — polyline de l'itinéraire "Y aller" ; v584 — tracé
        // violet du suivi.
        polylines: {..._routePolylines, ..._followPolylines(), ..._walkPolylines()},
      );
    });
  }

  /// v23.1 part 68 — Daniel : "mettre bouton + - en haut a droit".
  /// Small white pill that wraps a zoom-in / zoom-out icon.
  /// v23.1.189 — Daniel : "geolocalicasation + et - paw follow et pawspot
  /// un design beaucoupl plus moderne et jolie". Pill vertical blanc qui
  /// regroupe zoom + / zoom - / geoloc cible dans une seule unite, style
  /// Google Maps moderne avec divider fin entre chaque action et ombre
  /// douce floue.
  Widget _buildMapControlsStack() {
    // v565 (18/09) — Daniel : « la barre de droite aussi, plus design ».
    // Une seule capsule blanche translucide (blur), coins 22, séparateurs
    // fins, icônes noires #1D1D1F (localiser, + / −) ou grises (satellite,
    // membres), bouton actif teinté (satellite = orange de la marque).
    // Mêmes actions, même ordre, même largeur utile qu'avant.
    return PawGlassCapsule(
      // v590 — barres symétriques de 50 dp (handoff §3.3).
      width: 50,
      children: [
        PawCapsuleButton(
          icon: Icons.my_location_rounded,
          label: 'pawmap_quick_follow'.tr,
          // v585 (bug 8) — « ma position » à l'accent du rôle.
          tint: PawMapLegend.roleColor(_role.isEmpty ? 'owner' : _role),
          onTap: _recenterOnUser,
        ),
        PawCapsuleButton(
          icon: Icons.add_rounded,
          label: '+',
          onTap: _zoomIn,
        ),
        PawCapsuleButton(
          icon: Icons.remove_rounded,
          label: '−',
          onTap: _zoomOut,
        ),
        // v23.1.266 — vue satellite (hybride) ; actif = teinté.
        PawCapsuleButton(
          icon: _mapType == MapType.normal
              ? Icons.satellite_alt_rounded
              : Icons.map_rounded,
          label: 'pawmap_dock_layers'.tr,
          secondary: true,
          active: _mapType != MapType.normal,
          tint: AppColors.primaryColor,
          onTap: _toggleMapType,
        ),
        // v23.1.266 — « voir tous mes amis » (dézoome pour les englober).
        PawCapsuleButton(
          icon: Icons.groups_rounded,
          label: 'v565_live_friends_fit'.tr,
          secondary: true,
          // v590 — handoff §3.3 : « Voir tout le monde » en rose.
          tint: PawMapTheme.rose,
          onTap: _fitAllFriends,
        ),
        // v590 — handoff §3.4 : bouton BALADE (3 rôles). Même action que la
        // pilule Direct (démarrer / arrêter le partage en direct) : gris à
        // l'arrêt, vert en direct avec le nombre de personnes qui me suivent.
        if (_viewerLoggedIn)
          Obx(() {
            final live = _liveMap.broadcasting.value;
            final n = live ? _liveMap.myFollowers.value : 0;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PawJewel(
                  key: const ValueKey<String>('pawmap_walk_btn'),
                  palette: live ? kJewelWalkOn : kJewelWalkOff,
                  icon: PawSymbols.walk,
                  label: live
                      ? 'pawmap590_walk_live'.tr
                      : 'pawmap590_walk'.tr,
                  size: 38,
                  active: live,
                  badge: n > 0 ? PawFollowersBadge(count: n) : null,
                  onTap: () => unawaited(_toggleDirect()),
                  onLongPress: () => _showCapsuleHelp('direct'),
                ),
                Transform.translate(
                  offset: const Offset(0, -4),
                  child: Text(
                    live ? 'pawmap590_walk_live'.tr : 'pawmap590_walk'.tr,
                    maxLines: 1,
                    style: GoogleFonts.poppins(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: live
                          ? const Color(0xFF2A9A48)
                          : (PawMapTheme.isDark(context)
                              ? const Color(0xFFD2C4BE)
                              : const Color(0xFF6F5C55)),
                    ),
                  ),
                ),
              ],
            );
          }),
        // v586 — l'ŒIL : qui me voit (Tous · Amis seulement · Masqué), la
        // même vérité que Profil › Préférences et le site.
        Obx(() => PawCapsuleEyeButton(
              state: _prefs.mapVisibility.value,
              onTap: () => unawaited(_cycleVisibility()),
              onLongPress: () => _showCapsuleHelp('eye'),
            )),
      ],
      // v586 — l'action du rôle, sous un trait : Publier (propriétaire) ou
      // Direct (gardien / promeneur, noir = arrêté, vert = en direct).
      // v587 (point 1a) — le Direct est monté en haut à gauche (pilule sous
      // le logo, 3 profils) : la capsule, identique pour tous (position, +,
      // −, satellite, membres, œil, flèche de repli), garde « Publier » en bas
      // pour le propriétaire.
      footer: !pawMapCapsuleHasPublish(_role)
          // v589 — gardien / promeneur : « Demandes » autour (nombre), la
          // liste triée par distance ; chaque demande ouvre sa fiche.
          ? (!_viewerLoggedIn
              ? null
              : Obx(() => PawCapsuleRoleAction(
                    kind: PawRoleActionKind.requests,
                    live: false,
                    showLabel: true,
                    count: _requests.length,
                    color: PawMapLegend.roleColor(_role),
                    onTap: _openRequestsList,
                    onLongPress: () => _showCapsuleHelp('requests'),
                  )))
          : PawCapsuleRoleAction(
              kind: PawRoleActionKind.publish,
              live: false,
              // v589 — « Publier » toujours écrit (plus seulement aux
              // 3 premiers lancements).
              showLabel: true,
              onTap: _onPublishAction,
              onLongPress: () => _showCapsuleHelp('publish'),
            ),
    );
  }


  /// v589 — liste des demandes autour (gardien / promeneur), de la plus
  /// proche à la plus loin ; un appui ouvre la fiche de la demande.
  void _openRequestsList() {
    final list = _requests.toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    if (list.isEmpty) {
      CustomSnackbar.showInfo(
        title: 'pawmap589_requests'.tr,
        message: 'pawmap589_requests_none'.tr,
      );
      return;
    }
    final Color roleColor = PawMapLegend.roleColor(_role);
    showPawMapSheet<void>(
      context,
      PawMapClusterList(
        title: 'pawmap589_requests_title'.trParams({'n': '${list.length}'}),
        items: [
          for (final r in list)
            PawMapClusterItem(
              id: 'r:${r.id}',
              title: r.ownerName.isEmpty ? 'pawmap589_requests'.tr : r.ownerName,
              subtitle: [
                r.serviceTypes.contains('dog_walking')
                    ? 'pawmap589_req_walk'.tr
                    : 'pawmap589_req_sitting'.tr,
                if (r.distanceKm > 0)
                  r.distanceKm < 1
                      ? '${(r.distanceKm * 1000).round()} m'
                      : '${r.distanceKm.toStringAsFixed(1)} km',
                if (r.budget > 0) '${r.budget.toStringAsFixed(0)} ${r.currency}',
              ].join(' · '),
              color: roleColor,
              avatar: r.ownerAvatar,
              icon: Icons.assignment_rounded,
            ),
        ],
        onOpen: (it) {
          Navigator.of(context).pop();
          final id = it.id.substring(2);
          final r = list.firstWhereOrNull((x) => x.id == id);
          if (r != null) _showRequestBottomSheet(r);
        },
      ),
    );
  }

  /// Appui long sur un bouton de la capsule / la poignée → son explication.
  void _showCapsuleHelp(String id) {
    final spec = pawCapsuleSpecOf(id);
    if (spec == null) return;
    showPawMapSheet<void>(
      context,
      PawRailHelpSheet(
          title: spec.label, help: spec.help, color: spec.color, icon: spec.icon),
    );
  }

  /// v586 — rond « Publier » (propriétaire) : le même écran que le bouton
  /// principal d'avant.
  void _onPublishAction() {
    if (!_viewerLoggedIn) {
      SignupWallSheet.show(trigger: 'booking');
      return;
    }
    unawaited(_openPublishForm());
  }

  /// v586 — rond « Direct » (gardien / promeneur) : UN appui bascule le
  /// partage en direct. UNE vérité : `LiveMapService.broadcasting` (la même
  /// que la ligne « Partager ma balade » de la feuille et la puce d'état).
  /// Démarrage sans question (durée « jusqu'à l'arrêt », modifiable par la
  /// puce « En direct » de la feuille), sauf la toute première fois (une
  /// phrase d'explication) ; confirmation courte à l'ARRÊT seulement.
  Future<void> _toggleDirect() async {
    if (!_viewerLoggedIn) {
      SignupWallSheet.show(trigger: 'pawmap');
      return;
    }
    if (_liveMap.broadcasting.value) {
      // v587 (point 9) — petite feuille « Arrêter le direct ? » (verre
      // chaud, bouton signature) au lieu du dialogue gris.
      final ok = await showPawStopLiveSheet(context);
      if (ok && mounted && _liveMap.broadcasting.value) {
        _toggleBroadcast();
      }
      return;
    }
    // v589 — mon direct tourne sur mon AUTRE téléphone : même feuille
    // « Arrêter le direct ? » ; l'arrêt vaut pour tous mes appareils.
    if (_liveMap.liveElsewhere.value) {
      final ok = await showPawStopLiveSheet(context);
      if (ok && mounted) {
        await _liveMap.stopEverywhere();
        if (mounted) {
          PawSignal.show(context, PawSignalKind.liveOff, 'pawmap587_sig_live_off'.tr);
        }
      }
      return;
    }
    if (!await _liveFirstHintOk()) return;
    await _startBroadcastWith(LiveShareDuration.untilStop);
    if (_visibility == 'hidden' && mounted) {
      PawSignal.show(context, PawSignalKind.hidden, 'pawmap587_sig_live_hidden'.tr);
    }
  }

  /// Bascule normal ↔ satellite (hybride : imagerie + rues/labels).
  void _toggleMapType() {
    setState(() {
      _mapType =
          _mapType == MapType.normal ? MapType.hybrid : MapType.normal;
    });
  }

  /// v23.1.266 — Daniel : "un bouton pour dézoomer et voir tous mes amis dans
  /// un pays". Ajuste la caméra pour englober toutes les positions amis connues
  /// (+ la mienne).
  Future<void> _fitAllFriends() async {
    if (!_mapCtl.isCompleted) return;
    final pts = _liveMap.friendPositions.values
        .where((p) => !(p.latitude == 0 && p.longitude == 0))
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
    if (_userPosition != null) pts.add(_userPosition!);
    if (pts.isEmpty) {
      CustomSnackbar.showInfo(
        title: 'pawmap_fit_none_title'.tr,
        message: 'pawmap_fit_none_msg'.tr,
      );
      return;
    }
    // On arrête le suivi le temps de la vue d'ensemble.
    if (_followUserId != null) _stopFollow();
    final ctl = await _mapCtl.future;
    if (pts.length == 1) {
      await ctl.animateCamera(CameraUpdate.newLatLngZoom(pts.first, 13));
      return;
    }
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    // Points quasi confondus → un simple zoom centré (évite un bounds dégénéré).
    if ((maxLat - minLat).abs() < 0.0005 && (maxLng - minLng).abs() < 0.0005) {
      await ctl.animateCamera(CameraUpdate.newLatLngZoom(
          LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2), 14));
      return;
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    await ctl.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }


  // ─── Suivi live d'un ami (v23.1.263) ────────────────────────────────────
  /// Recentre la caméra sur [target] (v587 : un mouvement programmé ne met
  /// jamais le suivi en pause, seul un vrai geste le fait).
  Future<void> _animateFollowCamera(LatLng target, {double? zoom}) async {
    // v584 — une seule carte : on anime LE contrôleur.
    final ctl = await _activeMapCtl();
    if (ctl == null) return;
    try {
      if (zoom != null) {
        await ctl.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
      } else {
        // newLatLng conserve le zoom courant → suivi fluide sans re-zoomer.
        await ctl.animateCamera(CameraUpdate.newLatLng(target));
      }
    } catch (_) {/* map pas prête */}
  }

  /// Démarre le suivi d'un ami — zoom de suivi « joli » (Daniel, 23/09) : la
  /// caméra VOLE en douceur jusqu'au point et s'arrête à un zoom de rue
  /// lisible (16,5) ; ensuite elle suit le point sans re-zoomer (pas de
  /// recentrage brutal), et le tracé se dessine en violet PawFollow.
  void _startFollow(String userId, LatLng pos, String name,
      {String avatar = '', String role = '', double? zoom}) {
    // v584 (25/09, règle c) : on ne suit QUE quelqu'un qui partage sa
    // position en ce moment (en direct ou signal perdu < 10 min).
    final fp = _liveMap.friendPositions[userId];
    if (fp == null || fp.liveState == FriendLiveState.seen) {
      CustomSnackbar.showError(
        title: 'pawmap_member_seen_no_share'
            .trParams({'ago': fp == null ? '—' : _timeAgo(fp.seenAt)}),
        message: 'pawmap_member_seen_explain'.trParams({'name': name}),
      );
      return;
    }
    setState(() {
      _followUserId = userId;
      _followName = name;
      _followAvatar = avatar;
      _followRole = role;
      _followPaused = false;
      _followTrail = <LatLng>[pos];
    });
    _animateFollowCamera(pos, zoom: zoom ?? _followZoom);
    // v589 — la personne suivie voit « un œil + le nombre » sur sa pilule.
    unawaited(_liveMap.followPresence(userId, true));
    _followPresenceTimer?.cancel();
    _followPresenceTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      final uid = _followUserId;
      if (uid != null) unawaited(_liveMap.followPresence(uid, true));
    });
  }

  Timer? _followPresenceTimer;

  /// v588 — Daniel : « dans la liste d'amis, quand je clique sur sa photo, ça
  /// ne me renvoie pas vers lui sur la map ». Vol doux jusqu'à l'ami (zoom
  /// 16), sa fiche courte ouverte ; en direct, le suivi démarre.
  Future<void> _focusFriend(PawMapFriendFocus f) async {
    if (!mounted) return;
    if (_followUserId != null &&
        !{f.userId, ...f.personIds}.contains(_followUserId)) {
      _stopFollow();
    }
    unawaited(_sheetTo(PawSheetStop.low));
    // En direct : la position la plus fraîche connue de la carte.
    final liveKey = [f.userId, ...f.personIds].firstWhere(
        (id) => _liveMap.friendPositions[id] != null,
        orElse: () => f.userId);
    final fp = _liveMap.friendPositions[liveKey];
    final bool liveNow = f.live && fp != null && fp.liveState != FriendLiveState.seen;
    final LatLng at = liveNow ? LatLng(fp.latitude, fp.longitude) : LatLng(f.lat, f.lng);
    _currentCenter = at;
    try {
      final ctl = await _mapCtl.future.timeout(const Duration(seconds: 8));
      if (!mounted) return;
      await ctl.animateCamera(
          CameraUpdate.newLatLngZoom(at, kPawMapFriendFocusZoom));
    } catch (_) {/* carte pas prête : initialCameraPosition fera foi */}
    if (!mounted) return;
    if (liveNow) {
      _startFollow(liveKey, at, f.name,
          avatar: f.avatar, role: f.role, zoom: kPawMapFriendFocusZoom);
    }
    _onNearbyTap(
      id: f.userId,
      role: f.role,
      name: f.name,
      online: f.online,
      premium: f.premium,
      lat: at.latitude,
      lng: at.longitude,
      avatar: f.avatar,
      approx: !liveNow,
      approxKm: f.approxKm,
      isFriend: true,
      personIds: f.personIds,
    );
  }

  String _followAvatar = '';
  String _followRole = '';

  /// v584 (25/09) — la PILULE de suivi (entre les rails, au-dessus de la
  /// feuille) : photo, « Jose · en direct · 12 s », chevron → feuille.
  Widget _buildFollowPill() {
    return Obx(() {
      _liveMap.staleTick.value; // « il y a X » se rafraîchit
      final uid = _followUserId;
      if (uid == null) return const SizedBox.shrink();
      final fp = _liveMap.friendPositions[uid];
      final state = _followPaused
          ? PawFollowState.paused
          : (fp != null && fp.isLost ? PawFollowState.lost : PawFollowState.live);
      return PawMapFollowPill(
        name: _followName.trim().isEmpty
            ? 'pawmap_following_default'.tr
            : _followName.trim(),
        avatar: _followAvatar,
        role: _followRole.isEmpty ? (fp?.role ?? 'owner') : _followRole,
        state: state,
        agoLabel: fp == null ? '' : _timeAgo(fp.seenAt),
        onTap: _openFollowSheet,
      );
    });
  }

  /// Feuille du suivi : Reprendre / Recentrer · Arrêter · Itinéraire · Message.
  void _openFollowSheet() {
    final uid = _followUserId;
    if (uid == null) return;
    final fp = _liveMap.friendPositions[uid];
    final name = _followName.trim().isEmpty
        ? 'pawmap_following_default'.tr
        : _followName.trim();
    final role = _followRole.isEmpty ? (fp?.role ?? 'owner') : _followRole;
    showPawMapSheet<void>(
      context,
      PawMapFollowSheet(
        name: name,
        avatar: _followAvatar,
        role: role,
        state: _followPaused
            ? PawFollowState.paused
            : (fp != null && fp.isLost ? PawFollowState.lost : PawFollowState.live),
        agoLabel: fp == null ? '' : _timeAgo(fp.seenAt),
        onResume: () {
          Navigator.of(context).pop();
          _resumeFollow();
        },
        onStop: () {
          Navigator.of(context).pop();
          _stopFollow();
        },
        onDirections: fp == null
            ? null
            : () {
                Navigator.of(context).pop();
                _startDirections(LatLng(fp.latitude, fp.longitude));
              },
        onMessage: () {
          Navigator.of(context).pop();
          unawaited(_openConversationWith(
              id: uid, role: role, name: name, avatar: _followAvatar));
        },
      ),
    );
  }

  /// v584 (25/09) — l'ami suivi a coupé son partage (ou plus de 10 min sans
  /// signal) : le suivi s'arrête de lui-même, et on le dit.
  void _endFollowIfGone() {
    final uid = _followUserId;
    if (uid == null) return;
    final fp = _liveMap.friendPositions[uid];
    if (fp != null && fp.liveState != FriendLiveState.seen) return;
    final name = _followName.trim().isEmpty
        ? 'pawmap_following_default'.tr
        : _followName.trim();
    _stopFollow();
    CustomSnackbar.showSuccess(
      title: 'pawmap_follow_pill_lost'.tr,
      message: 'pawmap_follow_ended'.trParams({'name': name}),
    );
  }

  /// Un geste sur la carte met le suivi EN PAUSE (le tracé continue) ; le
  /// bouton « Reprendre le suivi » recolle la caméra.
  void _pauseFollow() {
    if (_followUserId == null || _followPaused) return;
    setState(() => _followPaused = true);
  }

  void _resumeFollow() {
    final uid = _followUserId;
    if (uid == null) return;
    final fp = _liveMap.friendPositions[uid];
    // Règle (c) : « Reprendre » n'existe que si le partage est encore actif.
    if (fp == null || fp.liveState == FriendLiveState.seen) {
      _endFollowIfGone();
      return;
    }
    setState(() => _followPaused = false);
    _animateFollowCamera(LatLng(fp.latitude, fp.longitude), zoom: _followZoom);
  }

  /// Arrête le suivi (bouton Stop, retour Android).
  void _stopFollow() {
    if (_followUserId == null) return;
    _followPresenceTimer?.cancel();
    _followPresenceTimer = null;
    unawaited(_liveMap.followPresence(_followUserId!, false));
    setState(() {
      _followUserId = null;
      _followName = '';
      _followAvatar = '';
      _followRole = '';
      _followPaused = false;
      _followTrail = const <LatLng>[];
    });
  }

  /// Tracé violet PawFollow derrière la personne suivie.
  // ── v590 — handoff §5 : TRACÉ DE BALADE ANIMÉ ──
  // Trait blanc de 7 (halo) sous un trait couleur du rôle de 3,5, en
  // pointillés qui AVANCENT (décalage animé sur 1,6 s, en boucle). Affiché
  // pour la personne sur laquelle on a zoomé (carte focus) si elle est en
  // balade, et pour MA balade tant que je suis en direct. Le tracé suit la
  // carte (il zoome avec elle) ; le marqueur reste de taille constante.
  final RxInt _walkPhase = 0.obs;
  Timer? _walkTimer;
  static const int _walkSteps = 8; // 8 × 200 ms = 1,6 s

  /// Tracés à dessiner : (id, points, couleur du rôle).
  List<(String, List<LatLng>, Color)> _walkTrails() {
    final out = <(String, List<LatLng>, Color)>[];
    final focus = _focusCard.value;
    if (_liveMap.broadcasting.value && _liveMap.myTrail.length >= 2) {
      out.add(('me', _liveMap.myTrail.toList(),
          pawRoleSolid(_role.isEmpty ? 'owner' : _role)));
    }
    if (focus != null && focus.key != 'me') {
      final k = focus.key.trim().toLowerCase();
      for (final e in _liveMap.friendTrails.entries) {
        final fp = _liveMap.friendPositions[e.key];
        final match = e.key.trim().toLowerCase() == k ||
            (fp != null && fp.allIds.contains(k));
        if (match && e.value.length >= 2) {
          out.add(('f_${e.key}', e.value, pawRoleSolid(fp?.role ?? focus.role)));
          break;
        }
      }
    }
    return out;
  }

  void _syncWalkTimer(bool needed) {
    if (needed && !_reduceMotion) {
      _walkTimer ??= Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted) return;
        _walkPhase.value = (_walkPhase.value + 1) % _walkSteps;
      });
    } else if (!needed && _walkTimer != null) {
      _walkTimer?.cancel();
      _walkTimer = null;
    }
  }

  Set<Polyline> _walkPolylines() {
    final trails = _walkTrails();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncWalkTimer(trails.isNotEmpty);
    });
    if (trails.isEmpty) return const {};
    // Pointillés « 1 9 » à l'échelle du trait (3,5) → 4 px / 36 px ; le
    // décalage avance de 1/8 de période à chaque pas.
    const double period = 16;
    const double dash = 4;
    final double off = period * (_walkPhase.value / _walkSteps);
    final pattern = <PatternItem>[
      PatternItem.gap(off <= 0 ? 0.1 : off),
      PatternItem.dash(dash),
      PatternItem.gap(period - dash - off <= 0 ? 0.1 : period - dash - off),
    ];
    final set = <Polyline>{};
    for (final t in trails) {
      set.add(Polyline(
        polylineId: PolylineId('walk_halo_${t.$1}'),
        points: t.$2,
        color: Colors.white,
        width: 7,
        zIndex: 1,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ));
      set.add(Polyline(
        polylineId: PolylineId('walk_${t.$1}'),
        points: t.$2,
        color: t.$3,
        width: 4,
        zIndex: 2,
        patterns: _reduceMotion ? const <PatternItem>[] : pattern,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ));
    }
    return set;
  }

  /// Point de départ : cercle blanc (≈ 5 px), contour 3 px couleur du rôle.
  Set<Circle> _walkStartCircles() {
    final trails = _walkTrails();
    if (trails.isEmpty) return const {};
    final double mpp = 156543.03392 *
        math.cos(_currentCenter.latitude * math.pi / 180) /
        math.pow(2, _zoomLevel);
    return {
      for (final t in trails)
        Circle(
          circleId: CircleId('walk_start_${t.$1}'),
          center: t.$2.first,
          radius: math.max(2.0, mpp * 5),
          fillColor: Colors.white,
          strokeColor: t.$3,
          strokeWidth: 3,
          zIndex: 3,
        ),
    };
  }

  Set<Polyline> _followPolylines() {
    if (_followUserId == null || _followTrail.length < 2) return const {};
    return {
      Polyline(
        polylineId: const PolylineId('follow_trail'),
        points: List<LatLng>.unmodifiable(_followTrail),
        color: PawMapLegend.pawFollow,
        width: 4,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    };
  }

  // v23.1.316 — Daniel : "le zoom de la PawMap tu peux améliorer ?". Avant :
  // zoomIn()/zoomOut() sautaient d'UN niveau entier (×2 d'un coup) -> effet
  // brusque/saccadé. On passe à un pas plus doux de ±0.8 niveau (zoomBy) pour
  // un zoom progressif et fluide, toujours animé.
  /// v584 — LE contrôleur de la carte (null tant qu'elle n'est pas créée).
  /// Gardé sous ce nom : tous les gestes de caméra passent par ici.
  /// v584 (25/09) — pour le parcours `integration_test` (déplacer la caméra
  /// sur un ami en direct avant d'ouvrir sa fiche).
  @visibleForTesting
  Future<GoogleMapController?> activeMapCtlForTest() => _activeMapCtl();

  /// v590 — sonde d'intégration : un 1er appui simulé (les marqueurs natifs
  /// de Google Maps ne se touchent pas depuis un test).
  @visibleForTesting
  void focusForTest(PawFocusInfo info, LatLng target) =>
      _focusFirstTap(target, info);

  Future<GoogleMapController?> _activeMapCtl() async {
    if (!_mapCtl.isCompleted) return null;
    return _mapCtl.future;
  }

  Future<void> _zoomIn() async {
    final ctl = await _activeMapCtl();
    if (ctl == null) return;
    // Zoomer ne coupe pas le suivi (seul un vrai geste le met en pause).
    _fade.pulse();
    await ctl.animateCamera(CameraUpdate.zoomBy(0.8));
  }

  Future<void> _zoomOut() async {
    final ctl = await _activeMapCtl();
    if (ctl == null) return;
    _fade.pulse();
    await ctl.animateCamera(CameraUpdate.zoomBy(-0.8));
  }

  /// Recenters the GoogleMap camera on the user's current GPS location.
  Future<void> _recenterOnUser() async {
    try {
      // v556 — Daniel : « à l'endroit parfait ». LocationService rend la
      // DERNIÈRE position connue si elle existe (cache OS, parfois vieille de
      // plusieurs minutes) → le point tombait à côté. Pour « ma position »,
      // on exige d'abord un fix GPS frais et précis ; le cache ne sert que
      // de secours si le GPS ne répond pas en 6 s.
      Position? loc;
      try {
        loc = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: 6),
          ),
        );
      } catch (_) {/* GPS lent ou refusé → secours ci-dessous */}
      loc ??= await LocationService()
          .getCurrentLocation()
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
      if (loc == null) {
        CustomSnackbar.showWarning(
          title: 'pawmap_snack_no_loc_title'.tr,
          message: 'pawmap_snack_no_loc_msg'.tr,
        );
        return;
      }
      final center = LatLng(loc.latitude, loc.longitude);
      if (!mounted) return;
      // v23.1.149 — synchronise _userPosition pour le halo bleu custom.
      setState(() {
        _currentCenter = center;
        _userPosition = center;
      });
      final ctl = await _activeMapCtl();
      if (ctl != null) {
        // v550 — recentrage avec un zoom « quartier » si on est très dézoomé.
        // v556 — Daniel : « que ça zoome plus, à l'endroit parfait ». Le
        // bouton « ma position » zoome désormais au niveau RUE (17) dès qu'on
        // est en dessous — comme Google Maps — au lieu de s'arrêter à 14.
        await ctl.animateCamera(
          _zoomLevel < 17
              ? CameraUpdate.newLatLngZoom(center, 17)
              : CameraUpdate.newLatLng(center),
        );
      }
      await _reloadAtCenter();
    } catch (e) {
      debugPrint('[PawMap] recenter error: $e');
    }
  }

  /// Quick-signal row — surfaces the 3 free report types at the very top of
  /// the PawMap so free users can contribute immediately and paying users see
  /// the fastest path to create a common signal. Tap pushes a pre-selected
  /// CreateReportSheet.
  /// v23.1.187 — Daniel mockup : carte "Autour de vous" flottante en bas
  /// de la PawMap. Liste compacte des 3 signalements les plus proches
  /// du centre courant, avec un badge severite + un tap "Voir tout" qui
  /// ouvre AlertsScreen. Auto-cache si aucune alerte autour.
  /// v23.1.360 — overlay du mode viseur : pin rose centré (pointe sur le
  /// centre exact de la carte), bulle d'aide en haut, bandeau bas
  /// Valider (ouvre la sheet de création à _currentCenter) / Annuler.
  /// v554 — Daniel : « sur la petite map les boutons pour le spot sont
  /// gênés ; vérifie tout ou améliore le design des boutons quand ils
  /// s'ouvrent ». Les trois viseurs (PawSpot, Signalement, Itinéraire)
  /// avaient chacun leur bandeau, leur hauteur et leur style — d'où des
  /// chevauchements avec la barre d'onglets, le dock et les rails. Ils
  /// partagent désormais UN seul gabarit :
  ///   - bulle d'aide en haut (le panneau blanc est replié pendant le visée),
  ///   - barre Annuler / Valider en bas, calée au-dessus du menu (petite
  ///     carte) ou de la barre système (carte agrandie, dock masqué),
  ///   - rails et « Autour de vous » écartés le temps du placement.
  /// v555 — refonte du placement (Daniel : « améliore le système de
  /// signalement et de spot »).
  ///
  /// Ce qui n'allait pas, vu sur ses captures :
  ///  1. les boutons Valider/Annuler passaient SOUS la barre d'onglets et sous
  ///     la barre système — parce que les viseurs lisaient
  ///     `MediaQuery.viewPadding.bottom`, qui vaut **0** sur son Samsung
  ///     (l'app est en edge-to-edge). Tout le reste de la carte utilise
  ///     `_navInset()`, qui retombe sur 48 dans ce cas : d'où l'écart. Les
  ///     viseurs utilisent désormais `_navInset()` eux aussi ;
  ///  2. « Effacer l'itinéraire » flottait par-dessus les boutons ;
  ///  3. sur la carte agrandie, la bulle d'aide passait DERRIÈRE la bannière
  ///     « Partager ma position » et le bouton Réduire → illisible.
  ///
  /// Le placement prend maintenant l'écran pour lui : une carte blanche ancrée
  /// en bas (titre + adresse visée + Annuler/Valider), le repère au centre, et
  /// plus rien d'autre — seul le rail de zoom reste, posé au-dessus de la
  /// carte. L'adresse est résolue quand la caméra s'arrête : on sait ce qu'on
  /// vise au lieu de valider à l'aveugle.
  Widget _buildPickerOverlay({
    required String hint,
    required String title,
    required String confirmLabel,
    required Color confirmColor,
    required IconData icon,
    required VoidCallback onCancel,
    required VoidCallback onConfirm,
  }) {
    return Positioned.fill(
      child: Stack(
        children: [
          // Bulle d'aide, sous l'AppBar. Rien ne passe devant : la bannière du
          // haut et le panneau sont masqués pendant le placement.
          Positioned(
            top: 12.h,
            left: 20.w,
            right: 20.w,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
                  decoration: BoxDecoration(
                    color: PawMapTheme.panelOn(context),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: PawMapTheme.pillShadow,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16.sp, color: confirmColor),
                      SizedBox(width: 7.w),
                      Flexible(
                        child: Text(
                          hint,
                          textAlign: TextAlign.center,
                          style: PawMapTheme.fontOn(context,
                              size: 12.sp, weight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Carte de placement ancrée en bas. `_navInset` = la vraie hauteur de
          // la barre système (48 par défaut) ; on ajoute la barre d'onglets sur
          // la petite carte, rien sur la carte agrandie (le dock est masqué).
          Positioned(
            left: 12.w,
            right: 12.w,
            // Petite carte : la barre d'onglets pleine largeur monte jusqu'à
            // ~125 (mesuré sur les captures de Daniel : 122 = SOUS la barre).
            // Carte agrandie : juste au-dessus de la barre système.
            bottom: 140.h - _tabBarLift(context) + _systemBottomInset(context),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
                decoration: BoxDecoration(
                  color: PawMapTheme.panelOn(context),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: PawMapTheme.borderOn(context)),
                  boxShadow: PawMapTheme.pillShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 30.w,
                          height: 30.w,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: confirmColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child:
                              Icon(icon, size: 16.sp, color: confirmColor),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: PawMapTheme.fontOn(context,
                                    size: 13.5.sp, weight: FontWeight.w800),
                              ),
                              SizedBox(height: 1.h),
                              // Adresse visée : mise à jour dès que la caméra
                              // s'arrête (voir _refreshPickAddress).
                              Obx(() => Text(
                                    _pickAddress.value.isEmpty
                                        ? 'pawmap_pick_locating'.tr
                                        : _pickAddress.value,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: PawMapTheme.fontOn(
                                      context,
                                      size: 11.sp,
                                      weight: FontWeight.w500,
                                      color: PawMapTheme.subOn(context),
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(13.r),
                            onTap: onCancel,
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              decoration: BoxDecoration(
                                color: PawMapTheme.veilOn(context, 0.05,
                                    darkAlpha: 0.12),
                                borderRadius: BorderRadius.circular(13.r),
                              ),
                              child: Center(
                                child: Text(
                                  'pawspot_pick_cancel'.tr,
                                  style: PawMapTheme.fontOn(context,
                                      size: 13.sp, weight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          flex: 2,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(13.r),
                            onTap: onConfirm,
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              decoration: BoxDecoration(
                                color: confirmColor,
                                borderRadius: BorderRadius.circular(13.r),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        confirmColor.withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  confirmLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: PawMapTheme.font(
                                    size: 13.sp,
                                    weight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Adresse du point visé pendant un placement (« Los Guardianes, Murcie »).
  final RxString _pickAddress = ''.obs;
  int _pickAddressSeq = 0;

  /// Géocodage inverse du centre de la carte, appelé quand la caméra s'arrête.
  /// Un compteur de séquence évite qu'une réponse lente écrase une plus
  /// récente (l'utilisateur fait souvent glisser la carte plusieurs fois).
  Future<void> _refreshPickAddress() async {
    final at = _pickedSpotPos ?? _currentCenter;
    final seq = ++_pickAddressSeq;
    try {
      final a = await LocationService()
          .getAddressFromCoordinates(at.latitude, at.longitude)
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
      if (seq != _pickAddressSeq || !mounted) return;
      if (a == null) {
        _pickAddress.value = '';
        return;
      }
      final parts = <String>[
        (a['street'] ?? '').toString(),
        (a['city'] ?? '').toString(),
        (a['country'] ?? '').toString(),
      ].where((e) => e.trim().isNotEmpty).toList();
      _pickAddress.value = parts.take(2).join(', ');
    } catch (_) {
      if (seq == _pickAddressSeq) _pickAddress.value = '';
    }
  }

  Widget _buildSpotPickerOverlay() {
    return _buildPickerOverlay(
      hint: 'pawspot_pick_hint'.tr,
      title: 'pawmap_pick_title_spot'.tr,
      confirmLabel: 'pawspot_pick_confirm'.tr,
      confirmColor: const Color(0xFFEC1E79),
      icon: Icons.pets_rounded,
      onCancel: () {
        _pickingSpotPos.value = false;
        if (mounted) setState(() {});
      },
      onConfirm: () {
        final at = _pickedSpotPos ?? _currentCenter;
        _pickingSpotPos.value = false;
        unawaited(_openPawSpotCreate(at: at));
      },
    );
  }

  Widget _buildAroundYouCard() {
    return Obx(() {
      // v23.1.189 — bouton X dans la card cache la card pour cette
      // session. _aroundYouVisible repasse a true au prochain mount.
      if (!_aroundYouVisible.value) return const SizedBox.shrink();
      final reports = _reportController.reports;
      if (reports.isEmpty) return const SizedBox.shrink();
      // Trie par distance approx au _currentCenter et garde les 3 premiers.
      final list = reports.toList()
        ..sort((a, b) {
          final da = _approxKm(a.latitude, a.longitude);
          final db = _approxKm(b.latitude, b.longitude);
          return da.compareTo(db);
        });
      // v470 — Daniel : « Autour de vous trop grand ». On réduit à 2 entrées
      // (au lieu de 3) + paddings resserrés pour une carte compacte.
      final top = list.take(2).toList();
      return Container(
        padding: EdgeInsets.fromLTRB(10.w, 8.h, 10.w, 8.h),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow(0.10),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InterText(
                    text: 'pawmap_around_you'.tr,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                GestureDetector(
                  onTap: () => _openScreen(() => const AlertsScreen()),
                  child: InterText(
                    text: 'pawmap_around_you_see_all'.tr,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryColor,
                  ),
                ),
                SizedBox(width: 8.w),
                // v23.1.189 — bouton X pour cacher la card.
                GestureDetector(
                  onTap: () {
                    // v251 — persiste la fermeture pour toute la session.
                    _aroundYouVisible.value = false;
                    _aroundYouDismissedSession = true;
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 24.w,
                    height: 24.w,
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary(context)
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded,
                        size: 14.sp, color: AppColors.textSecondary(context)),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            ...top.map((r) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 3.h),
                  child: _buildAroundYouRow(r),
                )),
          ],
        ),
      );
    });
  }

  double _approxKm(double lat, double lng) {
    // Pythagore en degres convertis grossierement en km (~111 km/deg).
    final dLat = (lat - _currentCenter.latitude).abs();
    final dLng = (lng - _currentCenter.longitude).abs();
    return (dLat * dLat + dLng * dLng) * 111 * 111;
  }

  Widget _buildAroundYouRow(MapReport r) {
    Color sev;
    String sevLabel;
    switch (r.type) {
      case 'lost_pet':
      case 'aggressive_dog':
      case 'dead_animal':
        sev = const Color(0xFFDC2626);
        sevLabel = 'alerts_severity_urgent'.tr;
        break;
      case 'hazard':
      case 'water_broken':
      case 'poop':
        sev = const Color(0xFFF59E0B);
        sevLabel = 'alerts_severity_medium'.tr;
        break;
      default:
        sev = const Color(0xFF16A34A);
        sevLabel = 'alerts_severity_info'.tr;
    }
    final emoji = ReportTypes.emoji(r.type);
    final key = 'map_report_label_${r.type}';
    final tr = key.tr;
    final typeLabel = tr == key ? r.type : tr;
    return Row(
      children: [
        Container(
          width: 32.w,
          height: 32.w,
          decoration: BoxDecoration(
            color: sev.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Center(child: Text(emoji, style: TextStyle(fontSize: 16.sp))),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InterText(
                text: typeLabel,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
                maxLines: 1,
              ),
              if (r.city.isNotEmpty)
                InterText(
                  text: r.city,
                  fontSize: 10.sp,
                  color: AppColors.textSecondary(context),
                  maxLines: 1,
                ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: sev.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: sev.withValues(alpha: 0.4)),
          ),
          child: InterText(
            text: sevLabel,
            fontSize: 9.sp,
            fontWeight: FontWeight.w800,
            color: sev,
          ),
        ),
      ],
    );
  }


  /// Les 4 raccourcis (puce 40×40 pastel + libellé 10px), badge compteur rose.
  Widget _buildPanelActions() {
    Widget action({
      required IconData icon,
      required Color pastel,
      required Color iconColor,
      required String label,
      required VoidCallback onTap,
      int badge = 0,
      Color badgeColor = PawMapTheme.rose,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 4.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40.w,
                      height: 40.w,
                      decoration: BoxDecoration(
                        // v571 — en sombre, la pastille pastel devient la
                        // teinte de l'icône à 18 % (sinon 4 carrés très clairs
                        // sur un panneau anthracite). Clair inchangé.
                        color: PawMapTheme.isDark(context)
                            ? iconColor.withValues(alpha: 0.18)
                            : pastel,
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Icon(icon,
                          size: 19.sp,
                          color: PawMapTheme.toneOn(context, iconColor)),
                    ),
                    if (badge > 0)
                      Positioned(
                        top: -2.h,
                        right: -2.w,
                        child: Container(
                          width: 15.w,
                          height: 15.w,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: badgeColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: PawMapTheme.panelOn(context), width: 2),
                          ),
                          child: Text(
                            badge > 9 ? '9+' : '$badge',
                            style: PawMapTheme.font(
                              size: 7.5.sp,
                              weight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: PawMapTheme.fontOn(
                    context,
                    size: 10.sp,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Obx(() {
      final pending = _friendController.incomingRequests.length;
      final alerts =
          _reportController.reports.where((r) => !r.isExpired).length;
      final live = _liveMap.friendPositions.length;
      return Row(
        children: [
          action(
            icon: Icons.group_rounded,
            pastel: PawMapTheme.pastelBlue,
            iconColor: const Color(0xFF4A5BC7),
            label: 'pawmap_quick_family'.tr,
            badge: pending,
            onTap: () => _openScreen(() => const FriendsScreen()),
          ),
          action(
            icon: Icons.notifications_rounded,
            pastel: PawMapTheme.pastelPeach,
            iconColor: PawMapTheme.accent,
            label: 'pawmap_quick_alerts'.tr,
            badge: alerts,
            onTap: () => _openScreen(() => const AlertsScreen()),
          ),
          action(
            icon: Icons.my_location_rounded,
            pastel: PawMapTheme.pastelGreen,
            iconColor: PawMapTheme.ok,
            label: 'pawmap_quick_live'.tr,
            badge: live,
            badgeColor: PawMapTheme.ok,
            onTap: () => _openScreen(() => const PeopleLiveScreen()),
          ),
          action(
            icon: Icons.verified_user_rounded,
            pastel: PawMapTheme.pastelRed,
            iconColor: PawMapTheme.danger,
            label: 'pawmap_quick_my_reports'.tr,
            onTap: () => _openScreen(() => const AlertsScreen()),
          ),
        ],
      );
    });
  }

  // v586 (point 7) — les anciennes puces de filtre (menu « Lieux », Tous /
  // Rien) sont remplacées par « Ce que je veux voir » (`_buildSeeSection`).

  /// « N membres autour de toi » + accès à l'explication des ON/OFF.
  Widget _buildPanelCounterRow() {
    return Obx(() => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              // v584 — idée 8 : le compteur est CLIQUABLE → liste.
              child: GestureDetector(
                key: const ValueKey<String>('pawmap_counter_tap'),
                behavior: HitTestBehavior.opaque,
                onTap: _openAroundList,
                child: Text(
                  _membersShown.value > 0
                      ? 'pawmap_members_around'
                          .trParams({'count': '${_membersShown.value}'})
                      : 'pawmap_quick_live_sub'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PawMapTheme.fontOn(context,
                      size: 11.5.sp,
                      weight: FontWeight.w700,
                      color: AppColors.accentOn(context, PawMapTheme.accent)),
                ),
              ),
            ),
            GestureDetector(
              onTap: _showPawMapToggleInfo,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 12.sp, color: PawMapTheme.subOn(context)),
                  SizedBox(width: 4.w),
                  Text(
                    'pawmap_toggle_info_chip'.tr,
                    style: PawMapTheme.font(
                        size: 10.sp,
                        weight: FontWeight.w600,
                        color: PawMapTheme.subOn(context)),
                  ),
                ],
              ),
            ),
          ],
        ));
  }

  /// Les 3 abonnements en pilules égales. Le ON/OFF reflète l'ABONNEMENT RÉEL
  /// (PawSpotController lit /users/me/benefits) : sans abo, le toggle n'allume
  /// rien et route vers la boutique — logique inchangée depuis la v449.
  /// v585 (bug 15) — « Mes abonnements sur la carte » : PawFollow (mon
  /// cercle en direct), PawSpot (couche gratuite, interrupteur pour tous),
  /// Premium (couronne + les deux couches). Non possédé → « Découvrir »
  /// (boutique). L'état = les calques, enregistrés sur le compte.
  Widget _buildPanelModules() {
    return Obx(() {
      final followSub = _pawSpotController.followActive.value;
      final premiumOn = _pawSpotController.premiumActive.value;
      return PawMapSubscriptionsSection(lines: [
        PawMapSubscriptionLine(
          id: 'follow',
          name: 'PawFollow',
          subtitle: 'pawmap585_subs_follow_sub'.tr,
          icon: Icons.podcasts_rounded,
          color: PawMapTheme.pawFollow,
          owned: followSub,
          on: followSub && _showLiveLayer.value,
          onToggle: () => unawaited(_togglePawFollow()),
          onDiscover: () => unawaited(_promptSubscriptionRequired(1)),
        ),
        PawMapSubscriptionLine(
          id: 'spot',
          name: 'PawSpot',
          subtitle: 'pawmap585_subs_spot_sub'.tr,
          icon: Icons.stars_rounded,
          color: PawMapTheme.pawSpot,
          owned: true,
          on: _showPawSpots.value,
          onToggle: () => unawaited(_togglePawSpot()),
          onDiscover: () => unawaited(_togglePawSpot()),
        ),
        PawMapSubscriptionLine(
          id: 'premium',
          name: 'PawPremium',
          subtitle: 'pawmap585_subs_premium_sub'.tr,
          icon: Icons.workspace_premium_rounded,
          color: const Color(0xFFC9971C),
          owned: premiumOn,
          on: premiumOn && _showPremiumLayer.value,
          onToggle: () => unawaited(_togglePawPremium()),
          onDiscover: () => unawaited(_promptSubscriptionRequired(3)),
        ),
      ]);
    });
  }

  /// v585 — bouton « Mes abonnements » : la même section, en feuille.
  void _openSubscriptionsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: PawMapTheme.bgOn(ctx),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 16.h + appBottomInset(ctx)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44.w,
                height: 5.h,
                decoration: BoxDecoration(
                  color: PawMapTheme.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            Text('pawmap585_subs_title'.tr,
                style: PawMapTheme.fontOn(ctx, size: 17.sp, weight: FontWeight.w800)),
            SizedBox(height: 12.h),
            _buildPanelModules(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChecklist(Set<String> selected) {
    final cats = PoiCategories.all;
    final allShown = selected.isEmpty;
    bool isChecked(String c) => allShown || selected.contains(c);
    return Container(
      margin: EdgeInsets.fromLTRB(12.w, 0, 12.w, 8.h),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: AppColors.cardShadow(context),
        border: Border.all(
            color: AppColors.textSecondary(context).withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grille 2 colonnes.
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 4.6,
            mainAxisSpacing: 2.h,
            crossAxisSpacing: 6.w,
            children: cats.map((cat) {
              final checked = isChecked(cat);
              return InkWell(
                borderRadius: BorderRadius.circular(10.r),
                onTap: () {
                  // Cocher une catégorie réactive la couche POI (si on était
                  // en mode « Rien »).
                  _showPois.value = true;
                  _poiController.setCategoryShown(cat, !checked, cats);
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  child: Row(
                    children: [
                      Text(PoiCategories.emoji(cat),
                          style: TextStyle(fontSize: 15.sp)),
                      SizedBox(width: 7.w),
                      Expanded(
                        child: InterText(
                          text: PoiCategories.label(cat),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Case à cocher.
                      Container(
                        width: 20.w,
                        height: 20.w,
                        decoration: BoxDecoration(
                          color: checked
                              ? const Color(0xFFC92A12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6.r),
                          border: Border.all(
                            color: checked
                                ? const Color(0xFFC92A12)
                                : AppColors.textSecondary(context)
                                    .withValues(alpha: 0.5),
                            width: 1.6,
                          ),
                        ),
                        child: checked
                            ? Icon(Icons.check_rounded,
                                size: 14.sp, color: Colors.white)
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 6.h),
          // Actions : Tous (tout afficher) / Appliquer.
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _showPois.value = true;
                    _poiController.selectAllCategories();
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: AppColors.textSecondary(context)
                            .withValues(alpha: 0.4)),
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: InterText(
                    text: 'paw_map_filter_all'.tr,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showCatFilter.value = false,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC92A12),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: InterText(
                    text: 'pawmap_filter_apply'.tr,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// v584 — le rail gauche, construit depuis l'ORDRE choisi par l'utilisateur
  /// (`_railOrder`, enregistré sur le compte). Chaque id garde EXACTEMENT son
  /// action d'avant ; appui long = l'explication ; le petit bouton du bas =
  /// le menu de personnalisation (ordre et choix).
  List<String> _railOrder = kPawRailDefaultOrder;

  Widget _buildMapActionsColumn() {
    return PawMapRail(
      order: _railOrder,
      gap: _railGapFor(_railOrder.length),
      active: {
        if (_routePolylines.isNotEmpty) 'directions',
        if (_followUserId != null) 'live_friends',
        if (_showPawSpots.value) 'spots',
      },
      onTap: _onRailTap,
      onLongPress: _showRailHelp,
      onCustomize: _openRailCustomize,
    );
  }

  /// Les actions du rail — inchangées depuis la v561/v565 (mêmes briques).
  void _onRailTap(String id) {
    switch (id) {
      case 'around':
        unawaited(_openAroundMeSheet());
      case 'directions':
        _pickedSpotPos = _currentCenter;
        _pickAddress.value = '';
        _pickingRoutePos.value = true;
        unawaited(_refreshPickAddress());
      case 'live_friends':
        unawaited(_openLiveFriendsSheet());
      case 'chat':
        _openCircleChat();
      case 'photo':
        unawaited(_startSpotPhoto());
      case 'spots':
        unawaited(_openSpotsList());
      case 'tag':
        _startSpotPicking();
      case 'report':
        _startReportPicking();
      case 'feed':
        _openScreen(() => const AlertsScreen());
      default:
        debugPrint('[PawMap] bouton de rail inconnu : $id');
    }
  }

  /// Appui long sur un bouton du rail → sa bulle d'explication, avec
  /// « Essayer » (fait l'action) et « Personnaliser ».
  void _showRailHelp(String id) {
    final spec = pawRailSpecOf(id);
    if (spec == null) return;
    showPawMapSheet<void>(
      context,
      Builder(
        builder: (ctx) => PawRailHelpSheet(
          title: spec.label,
          help: spec.help,
          color: spec.color,
          icon: spec.icon,
          onDo: () {
            Navigator.of(ctx).pop();
            _onRailTap(id);
          },
          onCustomize: () {
            Navigator.of(ctx).pop();
            _openRailCustomize();
          },
        ),
      ),
    );
  }

  /// Appui long sur une action du dock / de la feuille → son explication.
  void _showDockHelp(String id) {
    // UNE seule source (kPawDockSpecs) : la même que l'écran d'aide.
    final d = pawDockSpecOf(id);
    if (d == null) return;
    showPawMapSheet<void>(
      context,
      PawRailHelpSheet(title: d.label, help: d.help, color: d.color, icon: d.icon),
    );
  }

  /// Menu de personnalisation : ordre et choix, enregistrés sur le compte.
  /// v587 (point 5) — Daniel : « réordonner les boutons de gauche, sur
  /// certains Android c'est mou ». Chaque dépôt redessinait TOUT l'écran de
  /// la carte (setState + marqueurs) et réveillait tous ses observateurs
  /// (écriture des préférences) pendant que la liste bougeait encore. La
  /// liste vit désormais seule ; le rail et le compte sont mis à jour UNE
  /// fois, à la fermeture du menu.
  Future<void> _openRailCustomize() async {
    List<String>? chosen;
    await showPawMapSheet<void>(
      context,
      PawRailCustomizeSheet(
        order: _railOrder,
        onChanged: (order) => chosen = order,
      ),
    );
    final order = chosen;
    if (order == null || !mounted) return;
    setState(() => _railOrder = order);
    _prefs.update({'rail': order});
  }

  // ─── v584 — FEUILLE GLISSANTE (3 positions) + bouton principal ───────────

  late final DraggableScrollableController _sheetCtl =
      DraggableScrollableController();

  /// Position courante de la feuille (fraction de la hauteur disponible) —
  /// les rails se retirent quand la feuille dépasse sa position basse.
  final RxDouble _sheetExtent = 0.0.obs;
  /// v587 — feuille ouverte au-delà de sa position rangée (seuil seulement).
  final RxBool _sheetUp = false.obs;

  /// v585 (Daniel, build 584 : puce « Amis seulement » coupée en bas de la
  /// feuille sur son Samsung) — la position basse montre TOUT l'en-tête
  /// (poignée + bouton principal + ligne d'état), mesuré, jamais moins de
  /// 100 dp.
  final GlobalKey _sheetHeaderKey = GlobalKey();
  double _sheetHeaderH = 0;
  /// v586 — au repos la feuille est RANGÉE : seule la poignée « Options »
  /// (pilule 32 + air) occupe le bas. Rails, pilule de suivi et logo Google
  /// se posent au-dessus d'elle.
  double get _sheetPeekPx => 50.h;

  void _measureSheetHeader() {
    final box =
        _sheetHeaderKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final h = box.size.height;
    if ((h - _sheetHeaderH).abs() > 0.5 && mounted) {
      final wasLow = _sheetIsLow;
      setState(() => _sheetHeaderH = h);
      if (wasLow) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => unawaited(_sheetTo(PawSheetStop.low)));
      }
    }
  }
  bool _sheetIsLow = true;


  /// Hauteur (px) du menu du bas sous la carte. Dans les onglets, la feuille
  /// doit rester AU-DESSUS de toute la barre « patte » (pilule + saillie de la
  /// patte, `pawTabBarTotalHeight`) : la zone tactile de la patte est
  /// centrée, exactement là où vivent la poignée et le bouton principal, et
  /// elle passe devant le corps (Daniel : « le menu ne doit gêner AUCUN
  /// bouton »). Empilée hors onglets, seule la barre système reste.
  double _menuInset(BuildContext context) {
    final double sys = _systemBottomInset(context);
    if (_tabBarLift(context) > 0) return sys;
    return pawTabBarTotalHeight(sys);
  }

  /// v585 — CAUSE du bug 1 de Daniel (puce « Amis seulement » sous le menu,
  /// patte posée sur le bouton principal), mesurée sur l'émulateur avec la
  /// barre à 3 boutons : la PawMap vit dans le `body` d'un Scaffold en
  /// `extendBody`, qui RETIRE le bas de `viewPadding` à ses enfants → ici
  /// `viewPadding.bottom` valait 0 alors que le menu (posé par le wrapper, qui
  /// lit la vraie valeur, 48) était remonté de 48 : la feuille était posée
  /// 48 dp TROP BAS, sous la pilule et la patte. On lit donc l'inset de la
  /// FENÊTRE, exactement comme le menu du bas.
  double _systemBottomInset(BuildContext context) =>
      windowBottomViewPadding(context);

  /// v585 (Daniel, émulateur : « tu vois, c'est coupé » — une bande de
  /// carte entre le bas de la feuille et la pilule du menu) — la feuille
  /// descend désormais JUSQU'AU BAS de l'écran, DERRIÈRE le menu (la zone
  /// transparente autour de la pilule montre la feuille, pas la carte) ; son
  /// contenu garde un air en bas = hauteur du menu + 16, pour que le dernier
  /// élément défile au-dessus de la pilule. La hauteur « basse » visible
  /// reste mesurée AU-DESSUS du menu (`_sheetLowPx`).
  double _sheetAvailableHeight(BuildContext context) {
    final mq = MediaQuery.of(context);
    return math.max(200.0, mq.size.height);
  }

  /// v586 — position basse de la feuille = 0 (rangée derrière la poignée).
  double get _sheetLowPx => 0;

  /// v584 — clé de mesure du haut de l'écran (en-tête + rangée Partager /
  /// Agrandir) : la feuille en position haute s'arrête DESSOUS, elle ne
  /// passe jamais sous ces commandes (vu au parcours simulateur).
  final GlobalKey _topAreaKey = GlobalKey();

  double _sheetHighFraction(BuildContext context) {
    final h = _sheetAvailableHeight(context);
    final mq = MediaQuery.of(context);
    final box = _topAreaKey.currentContext?.findRenderObject() as RenderBox?;
    final topArea = (box != null && box.hasSize)
        ? box.size.height
        : PawMapTheme.pillHeight.h + 56.h;
    final top = mq.viewPadding.top + topArea + 8.h;
    return ((h - top) / h).clamp(0.55, 0.9).toDouble();
  }

  Future<void> _sheetTo(PawSheetStop stop) async {
    if (!_sheetCtl.isAttached) return;
    final h = _sheetAvailableHeight(context);
    final size = switch (stop) {
      PawSheetStop.low => (_sheetLowPx / h).clamp(0.0, 0.6).toDouble(),
      PawSheetStop.mid => 0.46,
      PawSheetStop.high => _sheetHighFraction(context),
    };
    try {
      await _sheetCtl.animateTo(size,
          duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    } catch (_) {/* feuille démontée */}
  }

  void _onSheetMoved() {
    // v584 — le DraggableScrollableController notifie aussi PENDANT la mise
    // en page (re-clamp de l'étendue) : écrire un Rx à ce moment-là lève
    // « setState() called during build » (vu au parcours simulateur). On
    // reporte alors la mise à jour à la fin de la frame.
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applySheetMoved();
      });
      return;
    }
    _applySheetMoved();
  }

  void _applySheetMoved() {
    if (!_sheetCtl.isAttached) return;
    final size = _sheetCtl.size;
    _sheetExtent.value = size;
    // v587 (point 5) — les barres et la poignée n'écoutent plus que le
    // FRANCHISSEMENT du seuil (rangée / ouverte), pas chaque pixel du
    // glissement : avant, la rangée des rails se reconstruisait à chaque
    // image pendant que la feuille glissait (mou sur Android d'entrée de gamme).
    final up = size > 0.03;
    if (_sheetUp.value != up) _sheetUp.value = up;
    final h = _sheetAvailableHeight(context);
    final low = (_sheetLowPx / h).clamp(0.0, 0.6).toDouble();
    final isLow = size <= low + 0.03;
    if (isLow != _sheetIsLow) {
      _sheetIsLow = isLow;
      _prefs.update({'panelCollapsed': isLow});
      if (mounted) setState(() {});
    }
  }

  Widget _buildSheet() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureSheetHeader());
    final Color roleColor =
        PawMapLegend.roleColor(_role.isEmpty ? 'owner' : _role);
    return PawMapSheet(
      controller: _sheetCtl,
      availableHeight: _sheetAvailableHeight(context),
      peekHeight: _sheetLowPx,
      bottomPadding: _menuInset(context) + 16.h,
      highFraction: _sheetHighFraction(context),
      // v586 — toucher la poignée de la feuille ouverte = la ranger.
      onGripTap: () => unawaited(_sheetTo(PawSheetStop.low)),
      header: NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (_) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _measureSheetHeader());
          return false;
        },
        child: SizeChangedLayoutNotifier(
          child: KeyedSubtree(
            key: _sheetHeaderKey,
            // v589 — Daniel : « le menu paramètre, plus beau, réorganisé ».
            // En-tête clair (roue + titre + croix), puis le bouton principal.
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sheetTitleRow(),
                SizedBox(height: 10.h),
                _buildPrimaryAction(),
              ],
            ),
          ),
        ),
      ),
      children: [
        // ── Carte 1 : ce que je veux voir (familles + filtres) ──
        _sheetCard(
          key: const ValueKey<String>('sheet_card_see'),
          tone: roleColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // v586 (point 7) — une pastille INDÉPENDANTE par famille.
              _buildSeeSection(),
              Obx(() {
                // Idée 1 — carte vide = une action (au zoom quartier).
                final empty = _membersShown.value == 0 &&
                    _zoomLevel >= 12 &&
                    _worldMembers.isNotEmpty;
                if (!empty) return const SizedBox.shrink();
                return Padding(
                  padding: EdgeInsets.only(top: 10.h),
                  child: PawMapEmptyCard(
                    viewerRole: _role,
                    onAction: _onEmptyAction,
                  ),
                );
              }),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        // ── Carte 2 : raccourcis (amis, abonnements, actions, outils) ──
        _sheetCard(
          key: const ValueKey<String>('sheet_card_shortcuts'),
          tone: PawMapTheme.accent,
          title: 'pawmap589_shortcuts'.tr,
          icon: Icons.bolt_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // v585 (bugs 14/15) — Amis et Mes abonnements, en deux tuiles.
              Row(
                children: [
                  Expanded(
                    child: _quickTile(
                      key: const ValueKey<String>('pawmap_btn_friends'),
                      icon: Icons.favorite_rounded,
                      label: 'pawmap585_btn_friends'.tr,
                      color: PawMapLegend.friend,
                      onTap: () => Get.to(() => const FriendsScreen()),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _quickTile(
                      key: const ValueKey<String>('pawmap_btn_subs'),
                      icon: Icons.workspace_premium_rounded,
                      label: 'pawmap585_btn_subs'.tr,
                      color: PawMapTheme.pawFollow,
                      onTap: _openSubscriptionsSheet,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              _buildPanelActions(),
              Divider(
                height: 14.h,
                color: PawMapTheme.accent.withValues(alpha: 0.12),
              ),
              Obx(() => PawMapDockRow(
                    grid: true,
                    nightMode: _nightMode.value,
                    onSos: _openSosAnimal,
                    onShare: _shareCurrentMap,
                    onLayers: _openLayersSheet,
                    onNight: _toggleNightMode,
                    onHistory: _openHistory,
                    onLongPress: _showDockHelp,
                  )),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        // ── Carte 3 : mes abonnements sur la carte ──
        _sheetCard(
          key: const ValueKey<String>('sheet_card_subs'),
          tone: PawMapTheme.pawFollow,
          title: 'pawmap585_subs_title'.tr,
          icon: Icons.workspace_premium_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPanelModules(),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _showPawMapToggleInfo,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.only(top: 6.h),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 13.sp, color: PawMapTheme.pawFollow),
                        SizedBox(width: 4.w),
                        Text(
                          'pawmap_toggle_info_chip'.tr,
                          style: PawMapTheme.font(
                              size: 11.sp,
                              weight: FontWeight.w700,
                              color: PawMapTheme.pawFollow),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// v589 — en-tête du panneau : roue orange, « Options de la carte », croix.
  Widget _sheetTitleRow() {
    return Row(
      key: const ValueKey<String>('sheet_title_row'),
      children: [
        Container(
          width: 34.w,
          height: 34.w,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFC92A12), Color(0xFF9E1F0B)],
            ),
          ),
          child: Icon(Icons.settings_rounded, size: 18.sp, color: Colors.white),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            'pawmap589_options'.tr,
            style: PawMapTheme.fontOn(context, size: 17.sp, weight: FontWeight.w800),
          ),
        ),
        Semantics(
          button: true,
          label: 'pawmap_coach_close'.tr,
          child: GestureDetector(
            key: const ValueKey<String>('sheet_close'),
            behavior: HitTestBehavior.opaque,
            onTap: () => unawaited(_sheetTo(PawSheetStop.low)),
            child: Container(
              width: 34.w,
              height: 34.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PawMapTheme.accent.withValues(alpha: 0.10),
              ),
              child: Icon(Icons.close_rounded, size: 19.sp, color: PawMapTheme.accent),
            ),
          ),
        ),
      ],
    );
  }

  /// v589 — carte du panneau : fond du panneau, liseré et ombre teintés,
  /// titre facultatif avec son icône (jamais de gris).
  Widget _sheetCard({
    Key? key,
    required Color tone,
    required Widget child,
    String? title,
    IconData? icon,
  }) {
    final bool dark = PawMapTheme.isDark(context);
    return Container(
      key: key,
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
      decoration: BoxDecoration(
        color: dark ? tone.withValues(alpha: 0.10) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: tone.withValues(alpha: dark ? 0.35 : 0.18)),
        boxShadow: [
          BoxShadow(
            color: tone.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Container(
                  width: 26.w,
                  height: 26.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tone.withValues(alpha: 0.14),
                  ),
                  child: Icon(icon ?? Icons.circle, size: 15.sp,
                      color: PawMapTheme.toneOn(context, tone)),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    title,
                    style: PawMapTheme.fontOn(context,
                        size: 14.sp, weight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
          ],
          child,
        ],
      ),
    );
  }

  /// v589 — tuile compacte (Amis, Mes abonnements) : 46 dp, couleur de la
  /// fonction, icône dans un disque, texte sur une ligne.
  Widget _quickTile({
    Key? key,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return PawPressable(
      key: key,
      label: label,
      onTap: onTap,
      child: Container(
        // v589 — Daniel : « que My subscriptions ne soit coupé sur aucun
        // bouton » : hauteur MINIMALE, le libellé passe sur 2 lignes si besoin.
        constraints: BoxConstraints(minHeight: 46.h),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: PawMapTheme.isDark(context) ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 28.w,
              height: 28.w,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              child: Icon(icon, size: 15.sp, color: Colors.white),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                softWrap: true,
                style: PawMapTheme.font(
                    size: 12.5.sp,
                    weight: FontWeight.w800,
                    height: 1.15,
                    color: PawMapTheme.toneOn(context, color)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Historique (dock) : avantage PawFollow (option C) ; sinon la boutique.
  void _openHistory() {
    if (_pawSpotController.followActive.value) {
      _openScreen(() => const BookingsHistoryScreen());
    } else {
      unawaited(_promptSubscriptionRequired(1));
    }
  }

  /// UN bouton principal, CONTEXTUEL (Daniel : « il change selon la
  /// situation ») :
  ///   · suivi en pause → Reprendre le suivi ;
  ///   · sans compte → Crée ton compte ;
  ///   · propriétaire sans demande → Publier ma demande ;
  ///   · gardien / promeneur avec des demandes autour → Proposer mes services
  ///     (la plus proche) ;
  ///   · sinon → Partager ma position (ou la feuille de durée si déjà actif).
  Widget _buildPrimaryAction() {
    return Obx(() {
      _requests.length;
      _myRequests.length;
      _liveMap.staleTick.value;
      final live = _liveMap.broadcasting.value;
      final role = _role;
      final Color roleColor = PawMapLegend.roleColor(role.isEmpty ? 'owner' : role);
      final Widget button;
      if (_followUserId != null && _followPaused) {
        button = PawSignatureButton(
          key: const ValueKey<String>('pawmap_primary'),
          label: 'pawmap_primary_resume_follow'.tr,
          icon: Icons.play_arrow_rounded,
          color: PawMapLegend.pawFollow,
          onTap: _resumeFollow,
        );
      } else if (!_viewerLoggedIn) {
        button = PawSignatureButton(
          key: const ValueKey<String>('pawmap_primary'),
          label: 'pawmap_member_signup_to_book'.tr,
          icon: Icons.person_add_alt_1_rounded,
          color: roleColor,
          onTap: () => SignupWallSheet.show(trigger: 'booking'),
        );
      } else if (live) {
        // v584 (25/09, point 14) — je PARTAGE : le bouton le dit (violet
        // PawFollow), un appui ouvre durée / arrêter. Plus d'interrupteur
        // en haut : UNE action, UN libellé.
        button = PawSignatureButton(
          key: const ValueKey<String>('pawmap_primary'),
          label: _isSitterOrWalker
              ? 'pawmap_primary_live_on_walk'.tr
              : 'pawmap_primary_live_on'.tr,
          icon: Icons.podcasts_rounded,
          color: PawMapLegend.pawFollow,
          onTap: () => unawaited(_openLiveDurationSheet()),
        );
      } else if (role == 'owner' && _myRequests.isEmpty) {
        button = PawSignatureButton(
          key: const ValueKey<String>('pawmap_primary'),
          label: 'pawmap_primary_publish'.tr,
          icon: Icons.campaign_rounded,
          color: roleColor,
          onTap: () => unawaited(_openPublishForm()),
        );
      } else if (_isSitterOrWalker && _requests.isNotEmpty) {
        button = PawSignatureButton(
          key: const ValueKey<String>('pawmap_primary'),
          label: 'pawmap_primary_propose'.tr,
          icon: Icons.volunteer_activism_rounded,
          color: roleColor,
          onTap: () {
            final sorted = _requests.toList()
              ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
            _showRequestBottomSheet(sorted.first);
          },
        );
      } else {
        // Gardien / promeneur : « Partager ma balade en direct » (violet) ;
        // propriétaire : « Partager ma position » (couleur du rôle).
        button = PawSignatureButton(
          key: const ValueKey<String>('pawmap_primary'),
          label: _isSitterOrWalker
              ? 'pawmap_primary_share_walk'.tr
              : 'pawmap_primary_share_live'.tr,
          icon: Icons.share_location_rounded,
          color: _isSitterOrWalker ? PawMapLegend.pawFollow : roleColor,
          onTap: _startLiveShareFromPrimary,
        );
      }
      // v584 (25/09, point 3) — plus petit (52 dp) : Daniel le trouvait trop
      // gros ; et la ligne d'état (amis seulement, en direct) sous le bouton,
      // jamais posée sur les commandes de la carte (point 12).
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 52.h, child: button),
          _buildSheetStatusRow(live: live),
        ],
      );
    });
  }

  /// v584 (25/09, point 12) — puces d'état SOUS le bouton principal :
  /// « Amis seulement » (→ feuille de visibilité) et « En direct · 3h58 »
  /// (→ durée / arrêter) quand le bouton principal dit autre chose.
  Widget _buildSheetStatusRow({required bool live}) {
    final chips = <Widget>[];
    if (_friendsOnly) {
      chips.add(PawMapStatusChip(
        key: const ValueKey<String>('pawmap_status_friends_only'),
        label: _visibility == 'hidden'
            ? 'pawmap586_vis_choice_hidden'.tr
            : 'pawmap_status_friends_only'.tr,
        icon: Icons.visibility_off_rounded,
        color: PawMapLegend.ink,
        onTap: _openVisibilitySheet,
      ));
    }
    if (live) {
      final rem = _liveMap.remaining;
      String label = 'pawmap_status_live'.tr;
      if (rem != null) {
        final h = rem.inHours;
        final m = rem.inMinutes % 60;
        label = '$label · ${h > 0 ? '${h}h${m.toString().padLeft(2, '0')}' : '${rem.inMinutes} min'}';
      }
      chips.add(PawMapStatusChip(
        key: const ValueKey<String>('pawmap_status_live'),
        label: label,
        icon: Icons.podcasts_rounded,
        color: _liveMap.liveStatus.value == LiveShareStatus.lost
            ? const Color(0xFFE8920A)
            : PawMapLegend.pawFollow,
        breathing: _liveMap.liveStatus.value != LiveShareStatus.lost,
        onTap: () => unawaited(_openLiveDurationSheet()),
      ));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: 8.h),
      child: Wrap(spacing: 6.w, runSpacing: 6.h, children: chips),
    );
  }

  /// v584 (25/09, point 14) — premier usage : une phrase d'explication, puis
  /// la durée, puis le partage démarre (même chemin qu'avant : `_toggleBroadcast`).
  Future<void> _startLiveShareFromPrimary() async {
    if (!await _liveFirstHintOk()) return;
    _toggleBroadcast();
  }

  /// La toute première fois : une phrase d'explication du direct (vrai =
  /// on continue).
  Future<bool> _liveFirstHintOk() async {
    final seen = GetStorage().read('pawmap_live_hint_seen') == true;
    if (!seen) {
      try {
        GetStorage().write('pawmap_live_hint_seen', true);
      } catch (_) {/* stockage plein */}
      final ok = await showAppConfirmDialog(
        context,
        title: _isSitterOrWalker
            ? 'pawmap_primary_share_walk'.tr
            : 'pawmap_primary_share_live'.tr,
        message: 'pawmap_live_first_hint'.tr,
        confirmLabel: 'common_continue'.tr,
        cancelLabel: 'common_cancel'.tr,
        icon: Icons.share_location_rounded,
        accent: PawMapLegend.pawFollow,
        onConfirm: () async {},
      );
      if (ok != true || !mounted) return false;
    }
    return mounted;
  }

  /// Idée 1 — carte vide : le propriétaire publie, le prestataire complète
  /// son profil (onglet Profil).
  void _onEmptyAction() {
    if (_role == 'owner' || _role.isEmpty) {
      unawaited(_openPublishForm());
    } else {
      openMainTabOr(4, () => const PawMapScreen());
    }
  }

  // ─── v586 (point 7) — « Ce que je veux voir » ────────────────────────────

  /// Familles affichées, dérivées des calques (une seule vérité : les
  /// calques enregistrés sur le compte, `pawMap.layers` + `memberRoles`).
  Set<String> _seeOn() => {
        if (_showFriends.value) 'friends',
        if (_showProviders.value && _memberRoles.contains('owner')) 'owners',
        if (_showProviders.value && _memberRoles.contains('sitter')) 'sitters',
        if (_showProviders.value && _memberRoles.contains('walker')) 'walkers',
        if (_showPois.value) 'places',
        if (_showPawSpots.value) 'pawspots',
        if (_showReports.value) 'reports',
        if (_showRequests.value) 'requests',
      };

  void _setRole(String role, bool on) {
    if (on) {
      _memberRoles.add(role);
      _showProviders.value = true;
    } else {
      _memberRoles.remove(role);
    }
    _memberRoles.refresh();
  }

  /// Une pastille = UNE famille, rien d'autre.
  void _toggleSee(String id) {
    final on = _seeOn().contains(id);
    switch (id) {
      case 'friends':
        _showFriends.value = !on;
      case 'owners':
        _setRole('owner', !on);
      case 'sitters':
        _setRole('sitter', !on);
      case 'walkers':
        _setRole('walker', !on);
      case 'places':
        _showPois.value = !on;
        if (!on && _poiController.enabledCategories.contains('__none__')) {
          _poiController.selectAllCategories();
        }
      case 'pawspots':
        unawaited(_togglePawSpot());
      case 'reports':
        _showReports.value = !on;
      case 'requests':
        _showRequests.value = !on;
    }
    if (mounted) setState(() {});
  }

  /// « Tout » / « Rien » : seulement les 8 familles de la section (jamais
  /// le direct PawFollow, Premium ni « Disponible aujourd'hui »).
  void _setAllSee(bool on) {
    _showFriends.value = on;
    if (on) {
      _memberRoles.addAll({'owner', 'sitter', 'walker'});
      _showProviders.value = true;
    } else {
      _memberRoles.clear();
    }
    _memberRoles.refresh();
    _showPois.value = on;
    if (on) _poiController.selectAllCategories();
    if (_showPawSpots.value != on) unawaited(_togglePawSpot());
    _showReports.value = on;
    _showRequests.value = on;
    if (mounted) setState(() {});
  }

  Widget _buildSeeSection() {
    return Obx(() {
      // Dépendances réactives de la section.
      _showFriends.value;
      _showProviders.value;
      _memberRoles.length;
      _showPois.value;
      _showPawSpots.value;
      _showReports.value;
      _showRequests.value;
      final avail = _availableTodayOnly.value;
      final catsOpen = _showCatFilter.value;
      Widget miniChip(String key, String label, IconData icon, bool active,
              Color tone, VoidCallback onTap) =>
          Semantics(
            button: true,
            selected: active,
            label: label,
            child: GestureDetector(
              key: ValueKey<String>(key),
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                constraints: BoxConstraints(minHeight: 34.h),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: tone.withValues(
                      alpha: active
                          ? (PawMapTheme.isDark(context) ? 0.30 : 0.16)
                          : (PawMapTheme.isDark(context) ? 0.12 : 0.05)),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                      color: tone.withValues(alpha: active ? 0.7 : 0.3),
                      width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 15.sp, color: PawMapTheme.toneOn(context, tone)),
                    SizedBox(width: 5.w),
                    Flexible(
                      child: Text(label,
                          style: PawMapTheme.font(
                              size: 11.5.sp,
                              weight: FontWeight.w700,
                              color: PawMapTheme.toneOn(context, tone))),
                    ),
                  ],
                ),
              ),
            ),
          );
      return PawMapSeeSection(
        on: _seeOn(),
        onToggle: _toggleSee,
        onAll: () => _setAllSee(true),
        onNone: () => _setAllSee(false),
        counter: _buildPanelCounterRow(),
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                // Idée 4 — « Disponible aujourd'hui » (filtre, pas une famille).
                miniChip(
                  'see_available_today',
                  'pawmap_sheet_available_today'.tr,
                  Icons.event_available_rounded,
                  avail,
                  PawMapTheme.walker,
                  () => _availableTodayOnly.value = !avail,
                ),
                // Types de lieux (vétos, parcs…) : le réglage fin d'avant.
                miniChip(
                  'see_place_types',
                  'pawmap586_see_place_types'.tr,
                  catsOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.tune_rounded,
                  catsOpen,
                  const Color(0xFF0E7490),
                  () => _showCatFilter.value = !catsOpen,
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: catsOpen
                  ? Padding(
                      padding: EdgeInsets.only(top: 8.h),
                      child: _buildCategoryChecklist(_poiController
                          .enabledCategories
                          .where((c) => c != '__none__')
                          .toSet()),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    });
  }

  // ─── v584 — préférences sur le COMPTE (MapPrefsService) ─────────────────

  late final MapPrefsService _prefs = MapPrefsService.instance;
  List<Worker> _prefWorkers = const [];

  /// Applique les préférences (copie locale d'abord, puis le compte si plus
  /// récent). [fromAccount] : la caméra du compte ne remplace la carte que si
  /// l'appareil n'a aucune mémoire locale (premier lancement ici).
  void _applyPrefs({required bool fromAccount}) {
    final p = _prefs;
    final rail = p.rail;
    if (rail != null) _railOrder = normalizeRailOrder(rail);
    final layers = p.layers;
    if (layers.containsKey('places')) _showPois.value = layers['places']!;
    if (layers.containsKey('reports')) _showReports.value = layers['reports']!;
    if (layers.containsKey('members')) _showProviders.value = layers['members']!;
    if (layers.containsKey('pawspots')) _showPawSpots.value = layers['pawspots']!;
    if (layers.containsKey('live')) _showLiveLayer.value = layers['live']!;
    if (layers.containsKey('requests')) _showRequests.value = layers['requests']!;
    if (layers.containsKey('friends')) _showFriends.value = layers['friends']!;
    if (layers.containsKey('premium')) _showPremiumLayer.value = layers['premium']!;
    final roles = p.memberRoles;
    if (roles != null && roles.isNotEmpty) {
      _memberRoles
        ..clear()
        ..addAll(roles);
      _memberRoles.refresh();
    }
    final night = p.nightMode;
    if (night != null) _nightMode.value = night;
    // v590 — « Disponible aujourd'hui » n'est plus restauré d'une ouverture
    // à l'autre (un filtre oublié laissait la carte vide sans explication).
    
    final mode = p.routeMode;
    if (mode != null && _routeColors.containsKey(mode)) _routeMode = mode;
    final radius = p.aroundRadiusKm;
    if (radius != null) _aroundRadiusKm = radius;
    if (fromAccount) {
      final cam = p.camera;
      final lat = (cam?['lat'] as num?)?.toDouble();
      final lng = (cam?['lng'] as num?)?.toDouble();
      final zoom = (cam?['zoom'] as num?)?.toDouble();
      final localMemory = GetStorage().read(_kLastCenterKey);
      if (lat != null && lng != null && localMemory == null && _userPosition == null) {
        _currentCenter = LatLng(lat, lng);
        if (zoom != null) _zoomLevel = zoom;
        unawaited(_activeMapCtl().then((ctl) => ctl?.animateCamera(
            CameraUpdate.newLatLngZoom(_currentCenter, _zoomLevel))));
      }
    }
    if (mounted) setState(() {});
  }

  Map<String, bool> _layersSnapshot() => {
        'places': _showPois.value,
        'reports': _showReports.value,
        'members': _showProviders.value,
        'pawspots': _showPawSpots.value,
        'live': _showLiveLayer.value,
        'requests': _showRequests.value,
        'friends': _showFriends.value,
        'premium': _showPremiumLayer.value,
      };

  void _watchPrefs() {
    void pushLayers(dynamic _) => _prefs.update({'layers': _layersSnapshot()});
    _prefWorkers = [
      ever<bool>(_showPois, pushLayers),
      ever<bool>(_showReports, pushLayers),
      ever<bool>(_showProviders, pushLayers),
      ever<bool>(_showPawSpots, pushLayers),
      ever<bool>(_showLiveLayer, pushLayers),
      ever<bool>(_showRequests, pushLayers),
      ever<bool>(_showFriends, pushLayers),
      ever<bool>(_showPremiumLayer, pushLayers),
      ever<Set<String>>(_memberRoles,
          (r) => _prefs.update({'memberRoles': r.toList()})),
      ever<bool>(_nightMode, (v) => _prefs.update({'nightMode': v})),
      ever<bool>(_availableTodayOnly,
          (v) => _prefs.update({'availableTodayOnly': v})),
      // v586 — l'état de visibilité peut changer ailleurs (Préférences,
      // autre appareil relu) : la carte (rond « Moi », œil) suit.
      ever<String>(_prefs.mapVisibility, (_) {
        if (mounted) setState(() {});
      }),
    ];
  }

  // ─── v584 — découverte guidée (idée 7 : 3 bulles, 3 lancements max) ─────

  static bool _coachShownThisSession = false;

  /// v589 — toucher en deux temps (zoom puis fiche) : dernier rond touché.
  String? _focusTapId;

  // v590 — handoff §2/§4 : la carte focus et le cadrage d'avant le zoom.
  final Rxn<PawFocusInfo> _focusCard = Rxn<PawFocusInfo>();
  CameraPosition? _focusSavedCam;

  /// 1er appui sur un marqueur : la carte vole dessus (marqueur ~60 px
  /// au-dessus du centre, +1,5 niveau de zoom), la carte focus apparaît.
  /// Le cadrage d'avant est retenu pour ✕.
  void _focusFirstTap(LatLng target, PawFocusInfo info) {
    _focusSavedCam ??= CameraPosition(target: _currentCenter, zoom: _zoomLevel);
    _focusTapId = info.key;
    _focusTapAt = DateTime.now();
    _focusCard.value = info;
    if (mounted) setState(() {});
    _fade.pulse();
    unawaited(() async {
      final ctl = await _activeMapCtl();
      if (ctl == null) return;
      final double z = math.min(math.max(_zoomLevel + 1.5, 15.0), 18.0);
      // Mètres par pixel à ce zoom ; 60 px vers le sud pour que le marqueur
      // reste un peu au-dessus du centre (la carte focus est en haut).
      final double mpp = 156543.03392 *
          math.cos(target.latitude * math.pi / 180) /
          math.pow(2, z);
      final double dLat = (60 * mpp) / 111320.0;
      await ctl.animateCamera(CameraUpdate.newLatLngZoom(
          LatLng(target.latitude - dLat, target.longitude), z));
    }());
  }

  /// Ferme la carte focus ; [restore] = ✕ → retour au cadrage d'avant.
  void _clearFocus({bool restore = false}) {
    final saved = _focusSavedCam;
    final had = _focusCard.value != null || _focusTapId != null;
    _focusSavedCam = null;
    _focusTapId = null;
    _focusTapAt = null;
    _focusCard.value = null;
    if (restore && saved != null) {
      _fade.pulse();
      unawaited(() async {
        final ctl = await _activeMapCtl();
        await ctl?.animateCamera(CameraUpdate.newCameraPosition(saved));
      }());
    }
    if (had && mounted) setState(() {});
  }

  /// Vrai si [key] vient d'être touché une 1re fois (≤ 30 s) : 2e appui.
  bool _isSecondTap(String key) =>
      _focusTapId == key &&
      _focusTapAt != null &&
      DateTime.now().difference(_focusTapAt!) < const Duration(seconds: 30);
  DateTime? _focusTapAt;
  static bool _focusHintShown = false;
  int _coachStep = -1;

  /// v584 (25/09, point 13) — PREMIER lancement seulement : mémorisé sur le
  /// compte (`coachShown`) ET l'appareil (`pawmap_intro_seen_count`), marqué
  /// dès l'affichage (jamais re-posé au retour d'un onglet, à la réouverture
  /// ni après une mise à jour). Reste consultable par « ? ».
  void _maybeStartCoach() {
    int deviceCount = 0;
    try {
      deviceCount = (GetStorage().read('pawmap_intro_seen_count') as num?)?.toInt() ?? 0;
    } catch (_) {/* stockage illisible : on ne re-montre pas pour autant */}
    if (!shouldShowPawMapCoach(
      accountCount: _prefs.coachShown,
      deviceCount: deviceCount,
      shownThisSession: _coachShownThisSession,
    )) {
      return;
    }
    _coachShownThisSession = true;
    _markCoachSeen();
    if (mounted) setState(() => _coachStep = 0);
  }

  void _markCoachSeen() {
    try {
      GetStorage().write('pawmap_intro_seen_count', 1);
    } catch (_) {/* stockage plein */}
    if (_prefs.coachShown < 1) _prefs.update({'coachShown': 1});
  }

  void _coachNext() {
    if (!mounted) return;
    setState(() => _coachStep += 1);
    if (_coachStep >= PawMapCoach.steps) _coachDone();
  }

  void _coachDone() {
    if (!mounted) return;
    setState(() => _coachStep = -1);
    _markCoachSeen();
    _maybeAnnounce();
  }

  /// v589 — fenêtre d'annonce (admin), une fois par appareil, jamais par-
  /// dessus la découverte guidée : elle attend la fin des bulles.
  void _maybeAnnounce() {
    if (_coachStep >= 0) return;
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted || _coachStep >= 0) return;
      unawaited(maybeShowPawMapAnnouncement(context,
          canShow: () => mounted && _coachStep < 0));
    });
  }
  /// v552 — « Chat du cercle » : ouvre la messagerie du rôle courant.
  void _openCircleChat() {
    final role = (Get.isRegistered<AuthController>()
            ? (Get.find<AuthController>().userRole.value ?? '')
            : '')
        .toLowerCase();
    if (role == 'sitter' || role == 'walker') {
      _openScreen(() => const SitterChatScreen());
    } else {
      _openScreen(() => const ChatScreen());
    }
  }

  /// v552 — ouvre l'élément partagé par un lien (`/spot/:id`, `/alert/:id`).
  /// Daniel : « selon ce qu'on partage, que ça tombe sur la chose précise ».
  Future<void> _openSharedTarget() async {
    final api = Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : null;
    if (api == null) return;
    final spotId = widget.focusSpotId ?? '';
    final reportId = widget.focusReportId ?? '';
    try {
      if (spotId.isNotEmpty) {
        final res = await api.get('/pawspots/$spotId', requiresAuth: true);
        final m = (res is Map ? (res['spot'] ?? res) : null) as Map?;
        final lat = (m?['lat'] as num?)?.toDouble();
        final lng = (m?['lng'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          await _animateFollowCamera(LatLng(lat, lng), zoom: 16);
          _currentCenter = LatLng(lat, lng);
          await _pawSpotController.loadNearby(_currentCenter, radiusM: _spotRadiusM);
        }
        final spot = _pawSpotController.spots
            .firstWhereOrNull((s) => s.id == spotId);
        if (spot != null && mounted) _showPawSpotDetail(spot);
        return;
      }
      if (reportId.isNotEmpty) {
        final res = await api.get('/map-reports/$reportId', requiresAuth: true);
        final m = (res is Map ? (res['report'] ?? res) : null) as Map?;
        final coords = ((m?['location'] as Map?)?['coordinates'] as List?);
        if (coords != null && coords.length >= 2) {
          final lat = (coords[1] as num).toDouble();
          final lng = (coords[0] as num).toDouble();
          await _animateFollowCamera(LatLng(lat, lng), zoom: 16);
          _currentCenter = LatLng(lat, lng);
          _showReports.value = true;
          await _reportController.loadNearby(_currentCenter);
        }
        if (mounted) _openScreen(() => const AlertsScreen());
      }
    } catch (e) {
      debugPrint('[PawMap] lien partagé introuvable : $e');
    }
  }

  // ─── v552 — NOUVELLES ACTIONS DU DOCK ────────────────────────────────────

  /// Partage un lien qui rouvre la carte EXACTEMENT ici (position + zoom).
  /// Daniel : « quand on partage un lien, que ça tombe sur la chose précise ».
  /// Le site sait lire ?lat/?lng/?z et l'app capte le lien universel.
  /// v584 — acquisition : le lien porte aussi la VILLE (`city=`), pour
  /// que le site ouvre la bonne page de ville sans compte et que l'app
  /// retombe sur ses pieds même sans coordonnées.
  Future<void> _shareCurrentMap() async {
    final c = _currentCenter;
    String city = '';
    try {
      final a = await LocationService()
          .getAddressFromCoordinates(c.latitude, c.longitude)
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
      city = (a?['city'] ?? '').toString().trim();
    } catch (_) {/* sans ville */}
    final url = 'https://www.hopetsit.com/map'
        '?lat=${c.latitude.toStringAsFixed(5)}'
        '&lng=${c.longitude.toStringAsFixed(5)}'
        '&z=${_zoomLevel.round()}'
        '${city.isEmpty ? '' : '&city=${Uri.encodeQueryComponent(city)}'}';
    await SharePlus.instance.share(
      ShareParams(
        text: '${'pawmap_share_map_text'.tr}\n$url',
        subject: 'PawMap — HoPetSit',
      ),
    );
  }

  /// SOS animal : signalement prioritaire + alerte aux membres dans 10 km.
  /// On demande confirmation (c'est une notification envoyée à de vraies
  /// personnes) puis on appelle POST /map-reports/sos.
  Future<void> _openSosAnimal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22.r),
        ),
        title: Row(
          children: [
            Icon(Icons.sos_rounded, color: PawMapTheme.danger, size: 22.sp),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'pawmap_sos_title'.tr,
                style: PawMapTheme.font(
                    size: 17.sp,
                    weight: FontWeight.w800,
                    color: AppColors.textPrimary(context)),
              ),
            ),
          ],
        ),
        content: Text(
          'pawmap_sos_body'.tr,
          style: PawMapTheme.font(
              size: 13.sp,
              weight: FontWeight.w500,
              color: AppColors.textSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common_cancel'.tr),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PawMapTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('pawmap_sos_send'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final api = Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : null;
    if (api == null) return;
    final pos = _userPosition ?? _currentCenter;
    try {
      final res = await api.post(
        '/map-reports/sos',
        body: {
          'lat': pos.latitude,
          'lng': pos.longitude,
          'note': '',
        },
        requiresAuth: true,
      );
      final n = ((res as Map?)?['notified'] as num?)?.toInt() ?? 0;
      await _reloadAtCenter();
      CustomSnackbar.showSuccess(
        title: 'pawmap_sos_sent_title'.tr,
        message: 'pawmap_sos_sent_msg'.trParams({'count': '$n'}),
      );
    } catch (e) {
      final raw = e.toString();
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: raw.contains('SOS_COOLDOWN')
            ? 'pawmap_sos_cooldown'.tr
            : 'pawmap_sos_failed'.tr,
      );
    }
  }

  // ─── v552 — DOCK BAS DE LA CARTE AGRANDIE (spec redesign v3) ─────────────
  // Nouvelles actions demandées par la maquette. Chacune est branchée sur une
  // brique qui existe déjà dans l'app quand il y en a une (mode nuit = style
  // sombre de la carte, historique = suivi de balade, calques = les couches
  // déjà présentes) ; SOS animal est la seule vraie nouveauté produit.


  /// v565 — le rail gauche compte désormais 9 boutons : sur un petit écran il
  /// pourrait dépasser le haut de la carte. On le borne à la hauteur
  /// disponible et il défile (aligné en BAS, jamais collé au menu).
  /// v589 — bas réel (en px écran) de l'en-tête + pilule « Direct », mesuré
  /// après chaque image. Daniel : « la barre de gauche, quand il y a toutes
  /// les icônes, qu'elle ne touche pas le bouton Direct, iOS et Android ».
  /// Avant : on ne retirait que l'en-tête (≈ 72) et la marge système — la
  /// pilule Direct (≈ 42 de plus) et le minimum de 28 dp posé sur Samsung
  /// n'étaient pas comptés, d'où le chevauchement.
  double _topChromeBottom = 0;

  double _measureTopChromeBottom() {
    final box = _topAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return 0;
    return box.localToGlobal(Offset(0, box.size.height)).dy;
  }

  /// v589 — hauteur disponible pour la barre de gauche (sous la pilule
  /// Direct, au-dessus du menu), mesurée comme dans [_railScroller].
  double _railAvailableHeight() {
    final mq = MediaQuery.of(context);
    final double fallback = math.max(mq.viewPadding.top, 28.0) +
        48.h +
        (pawMapShowsDirectPill(_role) ? 42.h : 0);
    final double topBottom =
        _topChromeBottom > 0 ? _topChromeBottom : fallback;
    return mq.size.height - topBottom - 14.h - _railBottom(context, picking: false);
  }

  /// v589 — écart entre les boutons : standard (10) si tout tient, sinon
  /// resserré jusqu'à 4 pour que la barre COMPLÈTE tienne sans défiler (un
  /// bouton coupé à moitié en haut, c'est laid). En dessous, elle défile.
  double _railGapFor(int buttons) {
    // v590 — bijoux de 38 dp dans une zone tactile de 44 dp (fixe), bouton
    // « Modifier » de 38×28 : écart standard 4 dp (≈ 10 dp visibles).
    const double size = 44;
    final double edit = 28.w;
    final double glass = 6.h + 4; // marge basse du verre + liseré
    final double std = 4.h;
    final double natural = buttons * (size + std) + edit + std + glass;
    final double avail = _railAvailableHeight();
    if (natural <= avail) return std;
    final double g = (avail - buttons * size - edit - glass) / (buttons + 1);
    return g.clamp(0.0, std).toDouble();
  }

  Widget _railScroller(Widget column) {
    final mq = MediaQuery.of(context);
    final h = mq.size.height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final b = _measureTopChromeBottom();
      if (b > 0 && (b - _topChromeBottom).abs() > 1) {
        setState(() => _topChromeBottom = b);
      }
    });
    // Repli avant la 1re mesure : barre d'état (28 dp au moins) + en-tête
    // (≈ 48) + pilule Direct (≈ 42).
    final double fallback = math.max(mq.viewPadding.top, 28.0) +
        48.h +
        (pawMapShowsDirectPill(_role) ? 42.h : 0);
    final double topBottom =
        _topChromeBottom > 0 ? _topChromeBottom : fallback;
    // 14 dp d'air sous la pilule Direct, jamais moins.
    final double maxH =
        h - topBottom - 14.h - _railBottom(context, picking: false);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH.clamp(120.0, h)),
      child: SingleChildScrollView(
        reverse: true,
        physics: const ClampingScrollPhysics(),
        child: column,
      ),
    );
  }

  /// v552 — style sombre de la carte (mode nuit du dock). Palette calée sur
  /// les jetons de la maquette pour rester dans l'ambiance PawMap.
  static const String _nightMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#1d1b18"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#9c948a"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1d1b18"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#26231f"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#232a24"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#2b2823"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#332f29"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3d3831"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#262320"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#141d24"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#4a5b66"}]}
]
''';

  /// Mode nuit : style sombre appliqué à la carte (pas au reste de l'app).
  void _toggleNightMode() {
    _nightMode.value = !_nightMode.value;
    GetStorage().write('pawmap_night_mode', _nightMode.value);
    if (mounted) setState(() {});
  }

  /// Feuille « Calques » : toutes les couches de la carte au même endroit.
  void _openLayersSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      // v554 — Daniel : « sur la grande map, quand on appuie sur Calques,
      // c'est coupé par le menu du bas ». La feuille n'avait NI useSafeArea NI
      // marge système : la dernière ligne (PawFollow) passait sous la barre
      // Samsung. On ajoute les deux + un défilement de sécurité pour les
      // petits écrans et les grandes tailles de police.
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: PawMapTheme.bgOn(ctx),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
        ),
        padding: EdgeInsets.fromLTRB(
          18.w,
          14.h,
          18.w,
          24.h + appBottomInset(ctx),
        ),
        child: Obx(() {
          Widget row(String label, bool value, VoidCallback onTap,
              IconData icon, Color color) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13.r),
                ),
                child: Icon(icon, size: 18.sp, color: color),
              ),
              title: Text(label,
                  style: PawMapTheme.fontOn(ctx,
                      size: 13.sp, weight: FontWeight.w700)),
              trailing: Switch.adaptive(
                value: value,
                activeThumbColor: PawMapTheme.ok,
                onChanged: (_) => onTap(),
              ),
            );
          }

          return SingleChildScrollView(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: PawMapTheme.veilOn(ctx, 0.12, darkAlpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              SizedBox(height: 12.h),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('pawmap_dock_layers'.tr,
                    style: PawMapTheme.fontOn(ctx,
                        size: 18.sp, weight: FontWeight.w800)),
              ),
              SizedBox(height: 6.h),
              row('pawmap_filter_places'.tr, _showPois.value,
                  () => _showPois.value = !_showPois.value,
                  Icons.place_rounded, PawMapTheme.accent),
              row('pawmap_filter_reports'.tr, _showReports.value,
                  () => _showReports.value = !_showReports.value,
                  Icons.warning_amber_rounded, PawMapTheme.danger),
              row('pawmap_layer_members'.tr, _showProviders.value, () {
                _showProviders.value = !_showProviders.value;
                if (mounted) setState(() {});
              }, Icons.people_alt_rounded, PawMapTheme.rose),
              row('PawSpot', _showPawSpots.value, _togglePawSpot,
                  Icons.pets_rounded, PawMapTheme.pawSpot),
              row('PawFollow', _showLiveLayer.value, _togglePawFollow,
                  Icons.share_location_rounded, PawMapTheme.pawFollow),
              row('pawmap592_osm_base'.tr, _osmBase.value, () {
                _osmBase.value = !_osmBase.value;
                GetStorage().write('pawmap_osm_base', _osmBase.value);
                if (mounted) setState(() {});
              }, Icons.map_rounded, PawMapTheme.accent),
            ],
          ));
        }),
      ),
    );
  }

  /// v552 (corrigé sur retour Daniel) — « les boutons avec titre au lieu de
  /// juste l'icône, et ce n'est pas aligné ». La maquette montre des BOUTONS
  /// RONDS blancs, icône seule, alignés verticalement : on revient à ça. Les

  // ─── v561 — « Autour de moi » : lieux par catégorie → itinéraire ─────────

  double _aroundRadiusKm =
      ((GetStorage().read('pawmap_around_radius') as num?)?.toDouble() ?? 5.0);

  static double _distanceKm(LatLng a, LatLng b) {
    const R = 6371.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final la1 = a.latitude * math.pi / 180;
    final la2 = b.latitude * math.pi / 180;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(la1) * math.cos(la2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * R * math.asin(math.sqrt(h.clamp(0.0, 1.0)));
  }

  Future<List<MapPOI>> _fetchAroundPois(String category, double radiusKm,
      LatLng origin) async {
    final api = Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : null;
    if (api == null) return const [];
    final res = await api.get(
      '/map-pois/nearby',
      queryParameters: {
        'lat': origin.latitude.toString(),
        'lng': origin.longitude.toString(),
        'maxDistance': (radiusKm * 1000).round().toString(),
        'category': category,
      },
      requiresAuth: true,
    );
    final list = ((res as Map?)?['pois'] as List?) ?? const [];
    final out = <MapPOI>[];
    for (final j in list) {
      if (j is Map) {
        final poi = MapPOI.fromJson(Map<String, dynamic>.from(j));
        // v565 — point 7 : filtre côté app, on ne garde que les catégories
        // dédiées aux animaux (quoi que renvoie /map-pois/nearby).
        if (!PoiCategories.isPetFriendly(poi.category)) continue;
        if (poi.latitude != 0 || poi.longitude != 0) out.add(poi);
      }
    }
    out.sort((a, b) => _distanceKm(origin, LatLng(a.latitude, a.longitude))
        .compareTo(_distanceKm(origin, LatLng(b.latitude, b.longitude))));
    return out;
  }

  Future<void> _openAroundMeSheet() async {
    final origin = _userPosition ?? _currentCenter;
    String? category;
    List<MapPOI> results = const [];
    bool loading = false;
    bool failed = false;
    String mode = _routeMode;
    double radius = _aroundRadiusKm;
    const radii = <double>[1, 2, 5, 10];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(builder: (ctx, setSheet) {
        Future<void> load(String cat) async {
          setSheet(() {
            category = cat;
            loading = true;
            failed = false;
            results = const [];
          });
          List<MapPOI> r = const [];
          bool ok = true;
          try {
            r = await _fetchAroundPois(cat, radius, origin);
          } catch (_) {
            ok = false; // v565 — état d'erreur + bouton Réessayer
          }
          if (!ctx.mounted) return;
          setSheet(() {
            results = r;
            failed = !ok;
            loading = false;
          });
        }

        Widget chip(String label, bool on, VoidCallback onTap,
            {Color color = PawMapTheme.pawFollow, IconData? icon}) {
          // v571 — lisibilité sombre : sur la feuille anthracite, la teinte
          // pleine (violet / vert) passe mal en TEXTE → variante éclaircie et
          // fond un peu plus dense. En clair, rien ne change.
          final bool isDark = PawMapTheme.isDark(ctx);
          final Color offFg = isDark ? PawMapTheme.lighten(color) : color;
          return GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
              decoration: BoxDecoration(
                color: on
                    ? color
                    : color.withValues(alpha: isDark ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[
                  Icon(icon, size: 15.sp, color: on ? Colors.white : offFg),
                  SizedBox(width: 4.w),
                ],
                Text(label,
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                      color: on ? Colors.white : offFg,
                    )),
              ]),
            ),
          );
        }

        final maxH = MediaQuery.of(ctx).size.height * 0.80;
        return Container(
          constraints: BoxConstraints(maxHeight: maxH),
          margin: EdgeInsets.fromLTRB(10.w, 0, 10.w, 10.h + appBottomInset(ctx)),
          decoration: BoxDecoration(
            color: AppColors.card(ctx),
            borderRadius: BorderRadius.circular(26.r),
            boxShadow: PawMapTheme.pillShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(18.w, 14.h, 10.w, 4.h),
                child: Row(children: [
                  Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      color: PawMapTheme.pawFollow.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Icon(Icons.near_me_rounded,
                        color: PawMapTheme.pawFollow, size: 22.sp),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('pawmap_around_title'.tr,
                            style: TextStyle(
                                fontSize: 17.sp, fontWeight: FontWeight.w800)),
                        Text(
                          category == null
                              ? 'pawmap_around_subtitle'.tr
                              : '${PoiCategories.emoji(category!)} ${PoiCategories.label(category!)} · ${'pawmap_around_km'.tr.replaceAll('{km}', radius.toStringAsFixed(radius == radius.roundToDouble() ? 0 : 1))}',
                          style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.textSecondary(ctx)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (category != null)
                    IconButton(
                      tooltip: 'pawmap_around_back'.tr,
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => setSheet(() {
                        category = null;
                        results = const [];
                      }),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                  ),
                ]),
              ),
              // Rayon + mode
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 8.h),
                child: Wrap(spacing: 6.w, runSpacing: 6.h, children: [
                  for (final r in radii)
                    chip('${r.toStringAsFixed(0)} km', radius == r, () {
                      setSheet(() => radius = r);
                      _aroundRadiusKm = r;
                      try {
                        GetStorage().write('pawmap_around_radius', r);
                      } catch (_) {/* noop */}
                      _prefs.update({'aroundRadiusKm': r});
                      if (category != null) unawaited(load(category!));
                    }),
                  SizedBox(width: 6.w),
                  chip('route_mode_walk'.tr, mode == 'walk',
                      () => setSheet(() => mode = 'walk'),
                      color: _routeColors['walk']!,
                      icon: Icons.directions_walk_rounded),
                  chip('route_mode_bike'.tr, mode == 'bike',
                      () => setSheet(() => mode = 'bike'),
                      color: _routeColors['bike']!,
                      icon: Icons.directions_bike_rounded),
                  chip('route_mode_car'.tr, mode == 'car',
                      () => setSheet(() => mode = 'car'),
                      color: _routeColors['car']!,
                      icon: Icons.directions_car_rounded),
                ]),
              ),
              Divider(height: 1, color: AppColors.divider(ctx)),
              Flexible(
                child: category == null
                    ? GridView.count(
                        shrinkWrap: true,
                        padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 14.h),
                        crossAxisCount: 2,
                        mainAxisSpacing: 8.h,
                        crossAxisSpacing: 8.w,
                        childAspectRatio: 3.1,
                        children: [
                          // v565 — point 7 : UNIQUEMENT les lieux animaux /
                          // pet-friendly (vétos, animaleries, toiletteurs,
                          // parcs, plages, points d'eau, éducateurs, hôtels
                          // et restaurants pet-friendly) — jamais « autre ».
                          for (final c in PoiCategories.petFriendly)
                            GestureDetector(
                              onTap: () => unawaited(load(c)),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 12.w),
                                decoration: BoxDecoration(
                                  color: PawMapTheme.pawFollow.withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: Border.all(
                                      color: PawMapTheme.pawFollow.withValues(alpha: 0.18)),
                                ),
                                child: Row(children: [
                                  Text(PoiCategories.emoji(c),
                                      style: TextStyle(fontSize: 18.sp)),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: Text(
                                      PoiCategories.label(c),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 12.5.sp,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                        ],
                      )
                    : loading
                        ? Padding(
                            padding: EdgeInsets.all(28.h),
                            child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 3)),
                          )
                        : failed
                            ? Padding(
                                padding: EdgeInsets.all(24.h),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.wifi_off_rounded,
                                        size: 30.sp,
                                        color: AppColors.textSecondary(ctx)),
                                    SizedBox(height: 8.h),
                                    Text('v565_map_load_error'.tr,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color:
                                                AppColors.textSecondary(ctx))),
                                    SizedBox(height: 10.h),
                                    TextButton.icon(
                                      onPressed: () =>
                                          unawaited(load(category!)),
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: Text('common_retry'.tr),
                                    ),
                                  ],
                                ),
                              )
                        : results.isEmpty
                            ? Padding(
                                padding: EdgeInsets.all(24.h),
                                child: Text('pawmap_around_none'.tr,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: AppColors.textSecondary(ctx))),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                padding: EdgeInsets.fromLTRB(8.w, 6.h, 8.w, 10.h),
                                itemCount: results.length,
                                separatorBuilder: (_, __) =>
                                    Divider(height: 1, color: AppColors.divider(ctx)),
                                itemBuilder: (_, i) {
                                  final poi = results[i];
                                  final d = _distanceKm(origin,
                                      LatLng(poi.latitude, poi.longitude));
                                  final dist = d < 1
                                      ? '${(d * 1000).round()} m'
                                      : '${d.toStringAsFixed(1)} km';
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10.w),
                                    leading: Text(PoiCategories.emoji(poi.category),
                                        style: TextStyle(fontSize: 20.sp)),
                                    title: Text(poi.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 13.5.sp,
                                            fontWeight: FontWeight.w700)),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (poi.address.isNotEmpty)
                                          Text(poi.address,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: 11.5.sp)),
                                        if (poi.openingHours.isNotEmpty)
                                          _poiHoursLine(poi.openingHours),
                                      ],
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(dist,
                                            style: TextStyle(
                                                fontSize: 12.sp,
                                                fontWeight: FontWeight.w800,
                                                color: PawMapTheme.pawFollow)),
                                        Icon(Icons.directions_rounded,
                                            size: 18.sp, color: _routeColors[mode]),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.of(sheetCtx).pop();
                                      _setRouteMode(mode);
                                      unawaited(_startDirections(
                                          LatLng(poi.latitude, poi.longitude)));
                                    },
                                  );
                                },
                              ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ─── PawSpot — couche spots communautaires 🐾 (v23.1.353) ────────────────

  // v488 — _buildSpotLegend retiré de la carte : la légende des types de spots
  // est désormais affichée en bas de l'onglet PawSpot de la boutique.

  /// v23.1.360 — Daniel : "le tag ne marche pas, je ne peux pas sélectionner
  /// l'endroit". Mode VISEUR : un pin rose fixe au centre de la carte +
  /// bandeau Valider/Annuler — on déplace la CARTE sous le pin, puis on
  /// valide → la sheet de création s'ouvre avec cette position exacte.
  void _startSpotPicking() {
    if (!_showPawSpots.value) {
      _showPawSpots.value = true;
      // v23.1.371 — choix ON mémorisé (cohérent avec le switch).
      GetStorage().write('pawspot_layer_on', true);
    }
    // v23.1.363 — pin de départ au centre, puis TAP sur la carte pour le
    // déplacer (le marqueur est aussi draggable).
    _pickedSpotPos = _currentCenter;
    _pickAddress.value = '';
    _pickingSpotPos.value = true;
    if (mounted) setState(() {});
    unawaited(_refreshPickAddress());
  }

  /// v449 — Daniel : viseur SIGNALEMENT express. Pin (rouge) déplaçable au
  /// centre, tap sur la carte pour ajuster ; bandeau « Signaler ici » → ouvre
  /// la feuille de signalement au point choisi. Plus rapide que Taguer un lieu
  /// (une seule action de validation).
  void _startReportPicking() {
    // v555 — le point de départ est le CENTRE de la carte (là où est le
    // repère rouge), plus la position GPS : sinon, sans bouger la carte, le
    // signalement partait à un endroit différent de celui affiché.
    _pickedSpotPos = _currentCenter;
    _pickAddress.value = '';
    _pickingReportPos.value = true;
    if (mounted) setState(() {});
    unawaited(_refreshPickAddress());
  }

  /// Bandeau bas du viseur signalement : hint + bouton « Signaler ici » + ✕.
  /// v554 — viseur « destination de l'itinéraire » (grande ou petite carte).
  /// Même geste que Taguer un lieu : la carte glisse sous le repère vert, on
  /// valide, l'itinéraire se trace et la caméra cadre le trajet.
  Widget _buildRoutePickerOverlay() {
    return _buildPickerOverlay(
      hint: 'pawmap_route_pick_hint'.tr,
      title: 'pawmap_pick_title_route'.tr,
      confirmLabel: 'pawmap_btn_directions'.tr,
      confirmColor: PawMapTheme.ok,
      icon: Icons.directions_rounded,
      onCancel: () {
        _pickingRoutePos.value = false;
        if (mounted) setState(() {});
      },
      onConfirm: () {
        final dest = _pickedSpotPos ?? _currentCenter;
        _pickingRoutePos.value = false;
        if (mounted) setState(() {});
        unawaited(_startDirections(dest));
      },
    );
  }

  Widget _buildReportPickerOverlay() {
    return _buildPickerOverlay(
      hint: 'pawmap_report_pick_hint'.tr,
      title: 'pawmap_pick_title_report'.tr,
      confirmLabel: 'pawmap_report_pick_confirm'.tr,
      confirmColor: const Color(0xFFDC2626),
      icon: Icons.place_rounded,
      onCancel: () {
        _pickingReportPos.value = false;
        if (mounted) setState(() {});
      },
      onConfirm: () async {
        final at = _pickedSpotPos ?? _userPosition ?? _currentCenter;
        _pickingReportPos.value = false;
        if (mounted) setState(() {});
        final created = await CreateReportSheet.show(context, initialPoint: at);
        if (created) await _reloadAtCenter();
      },
    );
  }

  /// v456 — POINT ROUGE FIXE au centre de l'écran pour placer un Paw Spot ou
  /// un Signalement. L'utilisateur déplace la CARTE sous le repère ;
  /// l'emplacement choisi suit le centre (`_onCameraMove`). Purement visuel
  /// (`IgnorePointer`) : il n'apparaît jamais sur la carte une fois enregistré
  /// — à Valider, seul l'emoji définitif reste.
  Widget _buildCenterReticle() {
    // v465 — Daniel : « quand je tag un spot fais le point en ROSE pas rouge ».
    // Tag PawSpot → repère ROSE (#EC1E79) ; signalement → repère ROUGE.
    final reticleColor = _pickingSpotPos.value
        ? const Color(0xFFEC1E79)
        : (_pickingRoutePos.value
            ? PawMapTheme.ok // vert : couleur du bouton Itinéraire
            : const Color(0xFFDC2626));
    return IgnorePointer(
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: 28.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26.w,
                height: 26.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: reticleColor.withValues(alpha: 0.18),
                ),
                child: Center(
                  child: Container(
                    width: 16.w,
                    height: 16.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: reticleColor,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow(0.30),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: 2.2.w,
                height: 12.h,
                color: reticleColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// v449 — Daniel : « si l'utilisateur n'a pas d'abonnement et clique sur ON,
  /// n'active PAS le toggle ; ouvre la page d'abonnement via une popup
  /// "Abonnement requis" → boutons "Voir les offres" + "Plus tard" ». Cette
  /// popup remplace l'ancien snackbar + navigation automatique. Retourne true
  /// si l'utilisateur a choisi de voir les offres (et est passé en boutique).
  Future<bool> _promptSubscriptionRequired(int shopTab) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: AppColors.card(dctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.r),
        ),
        title: PoppinsText(
          text: 'pawmap_sub_required_title'.tr,
          fontSize: 16.sp,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary(dctx),
        ),
        content: InterText(
          text: 'pawmap_sub_required_msg'.tr,
          fontSize: 13.sp,
          color: AppColors.textSecondary(dctx),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: InterText(
              text: 'pawmap_later'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(dctx),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            onPressed: () => Navigator.of(dctx).pop(true),
            child: InterText(
              text: 'pawmap_see_offers'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
    if (go != true) return false;
    await Get.to(() => CoinShopScreen(initialTab: shopTab));
    await _pawSpotController.refreshBenefits();
    if (mounted) setState(() {});
    return true;
  }

  /// v449 — infobulle ℹ️ : « le bouton ON/OFF agit uniquement sur l'affichage
  /// de la carte ; l'abonnement reste actif même désactivé ».
  void _showPawMapToggleInfo() {
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: AppColors.card(dctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.r),
        ),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded,
                color: AppColors.primaryColor, size: 20.sp),
            SizedBox(width: 8.w),
            PoppinsText(
              text: 'pawmap_toggle_info_title'.tr,
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary(dctx),
            ),
          ],
        ),
        content: InterText(
          text: 'pawmap_toggle_info'.tr,
          fontSize: 13.sp,
          color: AppColors.textSecondary(dctx),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            child: InterText(
              text: 'common_ok'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  /// v449 — toggle PawFollow. Le switch reflète l'ABONNEMENT réel
  /// (followActive = PawFollow/PawFamily/Premium). Déjà abonné → on/off de
  /// l'AFFICHAGE seulement (abo intact) ; pas abonné → popup « Abonnement
  /// requis » (jamais d'activation locale).
  Future<void> _togglePawFollow() async {
    if (_pawSpotController.followActive.value) {
      // v448 — Daniel : abonné, on/off MANUEL de la couche live (mon cercle +
      // halos amis/famille). Le switch suit désormais cet état. L'ABONNEMENT
      // n'est pas touché — c'est uniquement l'affichage carte.
      _showLiveLayer.value = !_showLiveLayer.value;
      if (mounted) setState(() {});
      return;
    }
    await _promptSubscriptionRequired(1);
  }

  /// v449 — toggle PawSpot. Le switch reflète l'ABONNEMENT réel
  /// (pawspotActive = PawSpot/Premium). Abonné → on s'assure que la couche
  /// spots est affichée + on rappelle « Voir les spots » ; pas abonné → on
  /// route vers la boutique PawSpot (jamais d'activation locale sans abo).
  Future<void> _togglePawSpot() async {
    // v556 — la couche PawSpot se voit gratuitement : l'interrupteur marche
    // pour tout le monde. L'abonnement n'est demandé qu'au 4e tag (402
    // PAWSPOT_REQUIRED géré dans pawspot_sheets).
    // v448 — on/off MANUEL de la couche spots. ON → on (ré)affiche les
    // spots ; OFF → on masque (mémorisé).
    if (_showPawSpots.value) {
      _showPawSpots.value = false;
      GetStorage().write('pawspot_layer_on', false);
    } else {
      _showPawSpots.value = true;
      GetStorage().write('pawspot_layer_on', true);
      await _pawSpotController.loadNearby(_currentCenter, radiusM: _spotRadiusM);
      setState(() {});
    }
  }

  /// v447 — toggle PawPremium de la rangée fonctionnalité. ON = abonnement
  /// Paw Premium activé. Comme il n'y a pas de mutation côté app, le passage
  /// OFF→ON quand on n'est pas abonné ouvre l'onglet Paw Premium de la
  /// boutique (CoinShop onglet 3) ; au retour on re-vérifie les benefits.
  Future<void> _togglePawPremium() async {
    if (_pawSpotController.premiumActive.value) {
      // v449 — Daniel : « PawPremium = PawFollow + PawSpot ». Le switch
      // PawPremium PILOTE les deux couches : ON → couche live (PawFollow) ET
      // couche spots (PawSpot) ON ; OFF → les deux OFF. (Plus juste les halos
      // OR.) Premium débloque déjà les deux abos, donc c'est cohérent.
      final on = !_showPremiumLayer.value;
      _showPremiumLayer.value = on;
      _showLiveLayer.value = on;
      if (on) {
        if (!_showPawSpots.value) {
          _showPawSpots.value = true;
          GetStorage().write('pawspot_layer_on', true);
          await _pawSpotController.loadNearby(_currentCenter, radiusM: _spotRadiusM);
        }
      } else {
        _showPawSpots.value = false;
        GetStorage().write('pawspot_layer_on', false);
      }
      if (mounted) setState(() {});
      return;
    }
    await _promptSubscriptionRequired(3);
  }

  // v488 — _quickActionChip retiré : les pilules « Taguer un lieu / Voir les
  // spots » sont remplacées par les boutons ronds gauche (_buildMapActionsColumn).

  /// « Voir les spots » : active la couche (même gating abo que le switch)
  /// puis ouvre la liste des spots à proximité avec mes PawPoints en tête.
  Future<void> _openSpotsList() async {
    if (!_showPawSpots.value) {
      await _togglePawSpotLayer();
      if (!_showPawSpots.value) return; // gating abo → boutique déjà ouverte
    } else if (_pawSpotController.spots.isEmpty) {
      await _pawSpotController.loadNearby(_currentCenter, radiusM: _spotRadiusM);
    }
    if (!mounted) return;
    await showPawSpotListSheet(
      context,
      controller: _pawSpotController,
      onOpenSpot: (spot) async {
        if (_mapCtl.isCompleted) {
          final ctl = await _mapCtl.future;
          unawaited(ctl.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(spot.lat, spot.lng), 16),
          ));
        }
        _showPawSpotDetail(spot);
      },
    );
  }

  /// Toggle du chip « PawSpot 🐾 » de la barre de filtres. Au passage à ON,
  /// vérifie le flag benefits.pawspotActive : inactif → reste OFF + boutique
  /// PawSpot (CoinShop onglet 2) ; actif → charge les spots autour du centre.
  Future<void> _togglePawSpotLayer() async {
    if (_showPawSpots.value) {
      _showPawSpots.value = false;
      // v23.1.371 — OFF MANUEL mémorisé : la couche ne se rallumera pas
      // toute seule à la prochaine ouverture de la carte.
      GetStorage().write('pawspot_layer_on', false);
      return;
    }
    // v567 — VOIR les spots est GRATUIT pour tous (promesse de la boutique
    // « Gratuit pour tous : voir tous les PawSpots », et le serveur l'autorise
    // déjà). L'ancien verrou d'abonnement renvoyait à tort vers la boutique ;
    // seule la création au-delà de 3 tags reste payante (402 côté serveur).
    unawaited(_pawSpotController.refreshBenefits());
    _showPawSpots.value = true;
    GetStorage().write('pawspot_layer_on', true);
    await _pawSpotController.loadNearby(_currentCenter, radiusM: _spotRadiusM);
  }

  /// Ouvre la sheet de création — position = pin du viseur (tap/drag) si
  /// fourni, sinon le centre de la carte.
  Future<void> _openPawSpotCreate({LatLng? at}) async {
    final created = await showPawSpotCreateSheet(
      context,
      controller: _pawSpotController,
      position: at ?? _currentCenter,
    );
    if (created == true) {
      await _pawSpotController.loadNearby(_currentCenter, radiusM: _spotRadiusM);
    }
  }

  /// v555 — Daniel : « dans la grande map la photo ne marche pas, règle ou
  /// crée le système ». Le bouton « Photo du spot » appelait… le viseur de
  /// placement, exactement comme « Marquer un lieu » : aucune photo nulle
  /// part. Désormais : appareil photo → envoi → fiche de création déjà
  /// remplie avec la photo, à la position GPS (on photographie l'endroit où
  /// l'on EST — pas le centre de la carte).
  bool _spotPhotoBusy = false;
  Future<void> _startSpotPhoto() async {
    if (_spotPhotoBusy) return;
    _spotPhotoBusy = true;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        imageQuality: 80,
      );
      if (picked == null || !mounted) return;
      CustomSnackbar.showInfo(
        title: 'pawmap_btn_spot_photo'.tr,
        message: 'pawspot_photo_uploading'.tr,
      );
      final url = await _pawSpotController.uploadPhoto(File(picked.path));
      if (!mounted) return;
      if (url == null || url.isEmpty) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'pawspot_add_photo'.tr,
        );
        return;
      }
      final created = await showPawSpotCreateSheet(
        context,
        controller: _pawSpotController,
        position: _userPosition ?? _currentCenter,
        initialPhotoUrl: url,
      );
      if (created == true) {
        await _pawSpotController.loadNearby(_currentCenter, radiusM: _spotRadiusM);
      }
    } catch (e) {
      debugPrint('[PawMap] spot photo error: $e');
    } finally {
      _spotPhotoBusy = false;
    }
  }

  /// Sheet détail d'un spot (photo, stats, like/valider/itinéraire,
  /// commentaires, actions créateur).
  void _showPawSpotDetail(PawSpotModel spot) {
    showPawSpotDetailSheet(
      context,
      spot: spot,
      controller: _pawSpotController,
      onDirections: (s) {
        // 👣 visite best-effort + même flux itinéraire que les POIs.
        unawaited(_pawSpotController.visit(s.id));
        _startDirections(LatLng(s.lat, s.lng));
      },
      onChanged: () =>
          unawaited(_pawSpotController.loadNearby(_currentCenter, radiusM: _spotRadiusM)),
    );
  }

  /// Itinéraire "Y aller" (POIs + spots PawSpot) : GET /pawspots/directions
  /// → polyline orange + caméra englobant le trajet + bandeau distance.
  /// 402 PAWFOLLOW_REQUIRED → upsell PawFollow (CoinShop onglet 1).
  Future<void> _startDirections(LatLng dest) async {
    final from = _userPosition;
    if (from == null) {
      CustomSnackbar.showError(
        title: 'pawmap_snack_no_loc_title'.tr,
        message: 'pawmap_snack_no_loc_msg'.tr,
      );
      return;
    }
    if (_directionsLoading) return;
    _directionsLoading = true;
    _routeDest = dest;
    try {
      final route = await _pawSpotController.fetchDirections(
        from: from,
        to: dest,
        mode: _routeMode,
      );
      if (!mounted) return;
      if (route.points.length < 2) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'pawmap_snack_search_failed_msg'.tr,
        );
        return;
      }
      final stepMarkers = await _buildRouteStepMarkers(route.steps);
      if (!mounted) return;
      setState(() {
        _routePolylines = {
          Polyline(
            polylineId: const PolylineId('pawspot_route'),
            points: route.points,
            color: _routeColor,
            width: 5,
          ),
        };
        _routeDistanceMeters = route.distanceMeters;
        _routeDurationSeconds = route.durationSeconds;
        _routeSteps = route.steps;
        _routeStepMarkers = stepMarkers;
      });
      // Caméra : englobe tout le trajet.
      double minLat = route.points.first.latitude;
      double maxLat = minLat;
      double minLng = route.points.first.longitude;
      double maxLng = minLng;
      for (final p in route.points) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      try {
        // v554 — Daniel : « le bouton Itinéraire sur la grande map n'est pas
        // branché ». Il l'était, mais la caméra était animée sur _mapCtl (la
        // PETITE carte, cachée sous le calque agrandi) : le tracé apparaissait
        // hors champ et rien ne bougeait à l'écran. On vise désormais la carte
        // RÉELLEMENT visible.
        final ctl = await _activeMapCtl();
        if (ctl == null) return;
        await ctl.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(minLat, minLng),
              northeast: LatLng(maxLat, maxLng),
            ),
            60,
          ),
        );
      } catch (_) {/* map pas prête */}
    } catch (e) {
      if (PawSpotController.errorCode(e) == 'PAWFOLLOW_REQUIRED' ||
          PawSpotController.statusCode(e) == 402) {
        CustomSnackbar.showWarning(
          title: 'follow_pawfollow_required_title'.tr,
          message: 'directions_subscription_required'.tr,
        );
        Get.to(() => const CoinShopScreen(initialTab: 1));
      } else {
        debugPrint('[PawMap] directions error: $e');
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'pawmap_snack_search_failed_msg'.tr,
        );
      }
    } finally {
      _directionsLoading = false;
    }
  }

  /// Efface l'itinéraire en cours (bouton du bandeau).
  /// v559 — itinéraire demandé à l'ouverture (routeToLat/Lng) : on réessaie
  /// chaque seconde tant que MA position n'est pas connue (max ~10 s).
  Worker? _pendingRouteWorker;
  Worker? _pendingCenterWorker;
  Worker? _pendingFriendWorker;

  /// v588 — un ami a été demandé : le bootstrap garde la caméra sur lui.
  bool _friendFocusRequested = false;

  Future<void> _startPendingRoute(LatLng dest) async {
    for (int i = 0; i < 10; i++) {
      if (!mounted) return;
      if (_userPosition != null) {
        await _startDirections(dest);
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (mounted) await _startDirections(dest); // affichera « position inconnue »
  }

  /// v559 — PawMap poussée HORS des onglets (lien, app sans menu) : pas de
  /// barre d'onglets sous la carte → on retire la marge prévue pour elle
  /// (~100), sinon le bandeau d'itinéraire flotte « au milieu ».
  double _tabBarLift(BuildContext context) {
    bool standalone = false;
    try {
      // v585 — `Navigator.canPop()` disait « empilée » dès qu'une fenêtre
      // (dialogue des notifications, feuille…) s'ouvrait AU-DESSUS de
      // l'onglet : la feuille perdait alors le dégagement du menu et passait
      // dessous (vu sur iPhone). Seule compte la route de la PawMap elle-même.
      final route = ModalRoute.of(context);
      standalone = route != null && !route.isFirst;
    } catch (_) {/* pas de Navigator */}
    // v584 — sans AUCUN menu monté (écran hôte de test, lien profond avant
    // le montage), il n'y a pas de barre d'onglets à dégager non plus.
    if (!standalone && !navWrapperMounted.value) standalone = true;
    return standalone ? 100.h : 0;
  }

  void _clearRoute() {
    setState(() {
      _routePolylines = {};
      _routeDistanceMeters = null;
      _routeDurationSeconds = null;
      _routeSteps = const [];
      _routeStepMarkers = {};
      _routeDest = null;
    });
  }

  /// v559 — changement de mode : mémorisé, puis le trajet est recalculé
  /// vers la même destination (distance ET durée changent avec le mode).
  void _setRouteMode(String mode) {
    if (mode == _routeMode) return;
    setState(() => _routeMode = mode);
    try {
      GetStorage().write('pawmap_route_mode', mode);
    } catch (_) {/* sans importance */}
    _prefs.update({'routeMode': mode});
    final dest = _routeDest;
    if (dest != null) _startDirections(dest);
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '';
    final min = (seconds / 60).round();
    if (min < 60) return 'route_duration_min'.tr.replaceAll('{min}', '${min < 1 ? 1 : min}');
    return 'route_duration_h'.tr
        .replaceAll('{h}', '${min ~/ 60}')
        .replaceAll('{min}', (min % 60).toString().padLeft(2, '0'));
  }

  /// v559 — mini-repères de virage : petit disque blanc cerclé de la couleur
  /// du mode avec une flèche (gauche / droite / tout droit / rond-point /
  /// drapeau d'arrivée). 22 px : visibles sans gêner le tracé. Le départ
  /// n'est pas marqué (c'est l'utilisateur).
  Future<Set<Marker>> _buildRouteStepMarkers(List<PawSpotRouteStep> steps) async {
    final out = <Marker>{};
    for (int i = 0; i < steps.length; i++) {
      final s = steps[i];
      if (s.isStart) continue;
      final glyph = s.isArrival
          ? 'flag'
          : s.isLeft
              ? 'left'
              : s.isRight
                  ? 'right'
                  : s.isUTurn
                      ? 'uturn'
                      : s.isRoundabout
                          ? 'round'
                          : 'straight';
      final key = '${_routeMode}_$glyph';
      final icon = _routeStepIcons[key] ??= await _drawStepIcon(glyph, _routeColor);
      out.add(Marker(
        markerId: MarkerId('route_step_$i'),
        position: s.position,
        icon: icon,
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 40,
        infoWindow: InfoWindow(
          title: s.instruction,
          snippet: s.distanceMeters > 0
              ? (s.distanceMeters >= 1000
                  ? '${(s.distanceMeters / 1000).toStringAsFixed(1)} km'
                  : '${s.distanceMeters} m')
              : null,
        ),
      ));
    }
    return out;
  }

  Future<BitmapDescriptor> _drawStepIcon(String glyph, Color color) async {
    const double size = 22;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(2, 2);
    const c = Offset(size / 2, size / 2);
    canvas.drawCircle(c, size / 2 - 0.5,
        Paint()..color = Colors.white..style = PaintingStyle.fill);
    canvas.drawCircle(c, size / 2 - 1.2,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2);
    final iconData = glyph == 'flag'
        ? Icons.flag_rounded
        : glyph == 'left'
            ? Icons.turn_left_rounded
            : glyph == 'right'
                ? Icons.turn_right_rounded
                : glyph == 'uturn'
                    ? Icons.u_turn_left_rounded
                    : glyph == 'round'
                        ? Icons.roundabout_left_rounded
                        : Icons.arrow_upward_rounded;
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontSize: 13,
          fontFamily: iconData.fontFamily,
          package: iconData.fontPackage,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
    final img = await recorder.endRecording().toImage((size * 2).toInt(), (size * 2).toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), width: size);
  }

  /// v559 — liste « pas à pas » (feuille), ouverte depuis le bandeau.
  void _showRouteStepsSheet() {
    final color = _routeColor;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card(context),
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 16.h + appBottomInset(sheetCtx)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_routeIcon, color: color, size: 20.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: PoppinsText(
                      text: 'route_steps_title'.tr,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  InterText(
                    text: [
                      if (_routeDistanceMeters != null)
                        _routeDistanceMeters! >= 1000
                            ? '${(_routeDistanceMeters! / 1000).toStringAsFixed(1)} km'
                            : '${_routeDistanceMeters!} m',
                      if (_formatDuration(_routeDurationSeconds).isNotEmpty)
                        _formatDuration(_routeDurationSeconds),
                    ].join(' · '),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _routeSteps.length,
                  separatorBuilder: (_, __) => Divider(
                      height: 1, color: AppColors.divider(sheetCtx)),
                  itemBuilder: (_, i) {
                    final s = _routeSteps[i];
                    final ic = s.isArrival
                        ? Icons.flag_rounded
                        : s.isStart
                            ? Icons.my_location_rounded
                            : s.isLeft
                                ? Icons.turn_left_rounded
                                : s.isRight
                                    ? Icons.turn_right_rounded
                                    : s.isUTurn
                                        ? Icons.u_turn_left_rounded
                                        : s.isRoundabout
                                            ? Icons.roundabout_left_rounded
                                            : Icons.arrow_upward_rounded;
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28.w,
                            height: 28.w,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(ic, size: 16.sp, color: color),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: InterText(
                              text: s.instruction,
                              fontSize: 13.sp,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          if (s.distanceMeters > 0) ...[
                            SizedBox(width: 8.w),
                            InterText(
                              text: s.distanceMeters >= 1000
                                  ? '${(s.distanceMeters / 1000).toStringAsFixed(1)} km'
                                  : '${s.distanceMeters} m',
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary(context),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// v573 — puce de mode du bandeau d'itinéraire : les trois ont exactement la
  /// même boîte et le même glyphe ; sélectionnée = pastille pleine à la
  /// couleur du mode, anneau blanc fin et ombre colorée (l'état se lit d'un
  /// coup d'œil) ; au repos = même pastille en voile de sa couleur, avec un
  /// filet. Appui = même langage que le rail (échelle + haptique).
  Widget _routeModeChip(String mode, IconData icon) {
    final selected = _routeMode == mode;
    final color = AppColors.accentOn(context, _routeColors[mode]!);
    final label = mode == 'car'
        ? 'route_mode_car'.tr
        : mode == 'bike'
            ? 'route_mode_bike'.tr
            : 'route_mode_walk'.tr;
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: Tooltip(
        message: label,
        child: PawPressable(
          scale: 0.92,
          onTap: () => _setRouteMode(mode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            width: 30.w,
            height: 30.w,
            decoration: BoxDecoration(
              color: selected ? color : color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? Colors.white.withValues(alpha: 0.85)
                    : color.withValues(alpha: 0.28),
                width: selected ? 1.6 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.38),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child:
                Icon(icon, size: 17.sp, color: selected ? Colors.white : color),
          ),
        ),
      ),
    );
  }

  /// Bandeau flottant : mode (3 pastilles colorées), distance + durée,
  /// « Étapes », « Effacer ».
  Widget _buildDirectionsBanner() {
    final meters = _routeDistanceMeters;
    final distanceLabel = meters == null
        ? '—'
        : meters >= 1000
            ? '${(meters / 1000).toStringAsFixed(1)} km'
            : '$meters m';
    final duration = _formatDuration(_routeDurationSeconds);
    // v573 — en sombre la couleur du mode (vert / bleu / orange pur) manquait
    // de contraste sur l'anthracite du panneau : on l'éclaircit comme ailleurs.
    final color = AppColors.accentOn(context, _routeColor);
    final Color danger = AppColors.accentOn(context, const Color(0xFFC92A12));
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: PawMapTheme.panelOn(context),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: color.withValues(alpha: 0.45),
          width: PawMapTheme.pillBorderWidth,
        ),
        boxShadow: PawMapTheme.pillShadowOn(context),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _routeModeChip('walk', Icons.directions_walk_rounded),
          SizedBox(width: 4.w),
          _routeModeChip('bike', Icons.directions_bike_rounded),
          SizedBox(width: 4.w),
          _routeModeChip('car', Icons.directions_car_rounded),
          SizedBox(width: 10.w),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // v573 — la distance est LE chiffre du bandeau : Poppins gras,
              // comme les titres de l'app ; la durée reste en dessous, à la
              // couleur du mode.
              PoppinsText(
                text: distanceLabel,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: PawMapTheme.inkOn(context),
                maxLines: 1,
                height: 1.05,
              ),
              if (duration.isNotEmpty)
                InterText(
                  text: duration,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                  maxLines: 1,
                  height: 1.05,
                ),
            ],
          ),
          if (_routeSteps.length > 1) ...[
            SizedBox(width: 10.w),
            // v573 — « Étapes » et la croix parlent la même langue que les
            // puces de mode : voile de la couleur, filet fin, appui animé.
            Semantics(
              label: 'route_steps_btn'.tr,
              button: true,
              child: PawPressable(
                onTap: _showRouteStepsSheet,
                child: Container(
                  height: 28.w,
                  padding: EdgeInsets.symmetric(horizontal: 9.w),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: color.withValues(alpha: 0.28),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.format_list_bulleted_rounded,
                          size: 13.sp, color: color),
                      SizedBox(width: 3.w),
                      InterText(
                        text: 'route_steps_btn'.tr,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: color,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          SizedBox(width: 6.w),
          Semantics(
            label: 'directions_clear'.tr,
            button: true,
            child: Tooltip(
              message: 'directions_clear'.tr,
              child: PawPressable(
                scale: 0.92,
                onTap: _clearRoute,
                child: Container(
                  width: 28.w,
                  height: 28.w,
                  decoration: BoxDecoration(
                    color: danger.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: danger.withValues(alpha: 0.28),
                      width: 1,
                    ),
                  ),
                  child: Icon(Icons.close_rounded, size: 16.sp, color: danger),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── POI details sheet ───────────────────────────────────────────────────
  void _showPoiBottomSheet(MapPOI poi) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      useSafeArea: true,
      builder: (sheetCtx) => Padding(
        // Respect the system nav bar / gesture area so the bottom of the
        // sheet is never hidden under Android's 3-button bar.
        padding: EdgeInsets.fromLTRB(
          20.w,
          20.h,
          20.w,
          20.h + MediaQuery.of(sheetCtx).viewPadding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(PoiCategories.emoji(poi.category), style: TextStyle(fontSize: 28.sp)),
                SizedBox(width: 10.w),
                Expanded(
                  child: PoppinsText(
                    text: poi.title,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: InterText(
                    text: PoiCategories.label(poi.category),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryColor,
                  ),
                ),
              ],
            ),
            if (poi.description.isNotEmpty) ...[
              SizedBox(height: 8.h),
              InterText(
                text: poi.description,
                fontSize: 13.sp,
                color: AppColors.textSecondary(context),
              ),
            ],
            if (poi.address.isNotEmpty)
              _iconLine(Icons.place_outlined, poi.address),
            // v559 — option A (Daniel) : « ouvert / fermé » calculé depuis les
            // horaires OpenStreetMap + téléphone en bouton d'appel. Aucun lien
            // vers le site du commerce (décision Daniel : pas de pub gratuite).
            if (poi.openingHours.isNotEmpty) _poiHoursLine(poi.openingHours),
            if (poi.phone.isNotEmpty) _poiPhoneLine(poi.phone),
            SizedBox(height: 16.h),
            // v23.1.353 — refonte PawSpot : bouton « Y aller » plein-largeur
            // (itinéraire piéton inclus dans PawFollow / PawFamily).
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                onPressed: () {
                  Navigator.of(sheetCtx).pop();
                  _startDirections(LatLng(poi.latitude, poi.longitude));
                },
                icon: Icon(Icons.directions_rounded,
                    color: Colors.white, size: 18.sp),
                label: InterText(
                  text: 'pawspot_go_btn'.tr,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Report details sheet ────────────────────────────────────────────────
  void _showReportBottomSheet(MapReport report) {
    // v456 — Daniel : « aider pour un animal perdu ». Pour un signalement
    // d'animal perdu, l'action principale devient « J'ai vu cet animal »
    // (gratuit pour tous) : ça prolonge l'alerte ET prévient le propriétaire.
    final bool isLost = report.type == ReportTypes.lostPet;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      useSafeArea: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20.w,
            16.h,
            20.w,
            24.h + MediaQuery.of(sheetContext).viewPadding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(ReportTypes.emoji(report.type),
                      style: TextStyle(fontSize: 28.sp)),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: PoppinsText(
                      text: ReportTypes.labelFr(report.type),
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  // TTL countdown badge
                  _TtlBadge(expiresAt: report.expiresAt),
                ],
              ),
              SizedBox(height: 6.h),
              InterText(
                text: ReportTypes.hintFr(report.type),
                fontSize: 12.sp,
                color: AppColors.textSecondary(context),
              ),
              if (report.note.isNotEmpty) ...[
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: AppColors.scaffold(context),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: InterText(
                    text: report.note,
                    fontSize: 13.sp,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ],
              if (isLost) ...[
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEC407A).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                        color: const Color(0xFFEC407A).withValues(alpha: 0.30)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🐾', style: TextStyle(fontSize: 16.sp)),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: InterText(
                          text: 'pawmap_lost_help_hint'.tr,
                          fontSize: 12.sp,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 12.h),
              Row(
                children: [
                  Icon(Icons.thumb_up_alt_outlined,
                      size: 14.sp, color: AppColors.textSecondary(context)),
                  SizedBox(width: 4.w),
                  InterText(
                    text: 'pawmap_confirmations_inline'.trParams({'count': report.confirmationsCount.toString()}),
                    fontSize: 11.sp,
                    color: AppColors.textSecondary(context),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(
                    // v456 — animal perdu : bouton plein « J'ai vu cet animal »
                    // (rose, action d'aide gratuite et prioritaire).
                    flex: isLost ? 2 : 1,
                    child: isLost
                        ? ElevatedButton.icon(
                            onPressed: () async {
                              final ok =
                                  await _reportController.confirm(report.id);
                              if (!mounted || !sheetContext.mounted) return;
                              Navigator.of(sheetContext).pop();
                              if (ok) {
                                CustomSnackbar.showSuccess(
                                  title: 'pawmap_snack_thanks_title'.tr,
                                  message: 'pawmap_lost_seen_thanks'.tr,
                                );
                              }
                            },
                            icon: Icon(Icons.pets, size: 16.sp),
                            label: InterText(
                              text: 'pawmap_lost_seen_btn'.tr,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEC407A),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                          )
                        : OutlinedButton.icon(
                            onPressed: () async {
                              final ok =
                                  await _reportController.confirm(report.id);
                              if (!mounted || !sheetContext.mounted) return;
                              Navigator.of(sheetContext).pop();
                              if (ok) {
                                CustomSnackbar.showSuccess(
                                  title: 'pawmap_snack_thanks_title'.tr,
                                  message: 'pawmap_snack_extended_msg'.tr,
                                );
                              }
                            },
                            icon: Icon(Icons.check_circle_outline, size: 16.sp),
                            label: InterText(
                              text: 'pawmap_btn_confirm_extend'.tr,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                          ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final ok = await _reportController.flag(report.id);
                        if (!mounted || !sheetContext.mounted) return;
                        Navigator.of(sheetContext).pop();
                        if (ok) {
                          CustomSnackbar.showSuccess(
                            title: 'pawmap_snack_reported_title'.tr,
                            message: 'pawmap_snack_reported_msg'.tr,
                          );
                        }
                      },
                      icon: Icon(Icons.flag_outlined,
                          size: 16.sp, color: Colors.red),
                      label: InterText(
                        text: 'pawmap_btn_report_abuse'.tr,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _iconLine(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(top: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16.sp, color: AppColors.textSecondary(context)),
          SizedBox(width: 6.w),
          Expanded(child: InterText(text: text, fontSize: 12.sp)),
        ],
      ),
    );
  }

  /// v559 — statut « ouvert / fermé » (vert / rouge) + horaires bruts en
  /// dessous. Syntaxe non comprise → seulement les horaires bruts.
  Widget _poiHoursLine(String raw) {
    final status = evaluateOpeningHours(raw, DateTime.now());
    String? label;
    Color color = AppColors.textSecondary(context);
    if (status != null) {
      final locale = Get.locale?.toString();
      String hm(DateTime d) => DateFormat.Hm(locale).format(d);
      if (status.always) {
        label = 'poi_open_247'.tr;
        color = const Color(0xFF16A34A);
      } else if (status.isOpen && status.closesAt != null) {
        label = 'poi_open_until'.tr.replaceAll('{time}', hm(status.closesAt!));
        color = const Color(0xFF16A34A);
      } else if (!status.isOpen) {
        color = const Color(0xFFDC2626);
        final o = status.opensAt;
        if (o == null) {
          label = 'poi_closed_now'.tr;
        } else {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final day = DateTime(o.year, o.month, o.day);
          final diff = day.difference(today).inDays;
          if (diff <= 0) {
            label = 'poi_closed_opens_today'.tr.replaceAll('{time}', hm(o));
          } else if (diff == 1) {
            label = 'poi_closed_opens_tomorrow'.tr.replaceAll('{time}', hm(o));
          } else {
            label = 'poi_closed_opens_day'.tr
                .replaceAll('{day}', DateFormat.EEEE(locale).format(o))
                .replaceAll('{time}', hm(o));
          }
        }
      }
    }
    return Padding(
      padding: EdgeInsets.only(top: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.schedule_outlined, size: 16.sp, color: color),
          SizedBox(width: 6.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label != null)
                  InterText(
                    text: label,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                InterText(
                  text: raw,
                  fontSize: 11.5.sp,
                  color: AppColors.textSecondary(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// v559 — téléphone : un appui ouvre le composeur.
  Widget _poiPhoneLine(String phone) {
    final tel = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    return Padding(
      padding: EdgeInsets.only(top: 8.h),
      child: GestureDetector(
        onTap: tel.isEmpty
            ? null
            : () async {
                final uri = Uri(scheme: 'tel', path: tel);
                try {
                  await launchUrl(uri);
                } catch (_) {/* pas d'app téléphone (tablette) */}
              },
        child: Row(
          children: [
            Icon(Icons.phone_outlined, size: 16.sp, color: AppColors.primaryColor),
            SizedBox(width: 6.w),
            Expanded(
              child: InterText(
                text: phone,
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
            ),
            if (tel.isNotEmpty)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: InterText(
                  text: 'poi_call'.tr,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Helper widgets
// ════════════════════════════════════════════════════════════════════════════

// v447 — l'ancien _LayerToggle (chips de la rangée à scroll horizontal) a été
// remplacé par _compactFilterButton dans _PawMapScreenState : la rangée de
// filtres tient désormais sur une seule ligne (4 Expanded, sans slide).

/// TTL countdown badge that rebuilds itself every minute so the user can see
/// the "hours left" number actually tick down.
class _TtlBadge extends StatefulWidget {
  const _TtlBadge({required this.expiresAt});
  final DateTime expiresAt;

  @override
  State<_TtlBadge> createState() => _TtlBadgeState();
}

class _TtlBadgeState extends State<_TtlBadge> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = widget.expiresAt.difference(DateTime.now()).inMinutes;
    final bool urgent = minutes < 120; // < 2h left
    final Color color = urgent ? Colors.red : AppColors.primaryColor;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time_rounded, size: 14.sp, color: color),
          SizedBox(width: 4.w),
          InterText(
            text: minutes < 60
                ? '${minutes}min'
                : '${minutes ~/ 60}h${(minutes % 60).toString().padLeft(2, '0')}',
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ],
      ),
    );
  }
}



