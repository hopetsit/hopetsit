import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
import 'package:hopetsit/views/map/alerts_screen.dart';
import 'package:hopetsit/views/map/pawmap_camera_memory.dart';
import 'package:hopetsit/views/map/pawspot_sheets.dart';
import 'package:hopetsit/views/service_provider/service_provider_detail_screen.dart';
import 'package:hopetsit/views/service_provider/walker_detail_screen.dart';
import 'package:hopetsit/views/map/widgets/create_report_sheet.dart';
import 'package:hopetsit/views/map/widgets/paw_rail_button.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';
import 'package:hopetsit/views/map/pawmap_help_screen.dart';
import 'package:hopetsit/views/map/widgets/pawmap_sheets.dart';
import 'package:hopetsit/views/map/widgets/pawmap_rail.dart';
import 'package:hopetsit/views/map/widgets/pawmap_buttons.dart';
import 'package:hopetsit/views/map/widgets/pawmap_sheet.dart';
import 'package:hopetsit/services/map_prefs_service.dart';
import 'package:hopetsit/widgets/paw_tab_bar.dart' show pawTabBarTotalHeight;
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
  final RxBool _mapExpanded = pawMapExpanded;

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
  /// v584 — mode « visible par mes amis seulement » (preferences.hideFromMap),
  /// synchronisé sur le compte par MapPrefsService.
  bool _friendsOnly = false;
  /// v584 — idée 4 : filtre « Disponible aujourd'hui ».
  final RxBool _availableTodayOnly = false.obs;
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
  bool _suppressFollowAutoStop = false;
  Worker? _followWorker;
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
    _friendsOnly = _readFriendsOnlyFromProfile();
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
        if (fp == null) return;
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
        unawaited(_pawSpotController.loadNearby(_currentCenter));
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
      ever<bool>(_mapExpanded, (_) {
        if (mounted) setState(() {});
      }),
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
        // Le mode « amis seulement » vient toujours du compte.
        _friendsOnly = _prefs.hideFromMap.value;
        if (remoteNewer) _applyPrefs(fromAccount: true);
        if (mounted) setState(() {});
      }));
      _maybeStartCoach();
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

  /// v552 — spec redesign v3, bug critique n°2 : « boutons masqués par la
  /// barre système ». Sur les Samsung à 3 boutons, la barre de navigation
  /// mange ~48 px : tout ce qui est ancré en bas doit partir de cette marge.
  /// Rails (gauche/droit) : marge + 126 · dock bas : marge + 66.
  double _navInset(BuildContext context) {
    final v = MediaQuery.of(context).viewPadding.bottom;
    return v > 0 ? v : 48.0;
  }

  /// Tap sur une pastille de groupe : on zoome dessus, le groupe s'ouvre.
  Future<void> _zoomToCluster(LatLng target) async {
    final ctl = await _activeMapCtl();
    if (ctl == null) return;
    final z = math.min(_zoomLevel + 2.2, 19.0);
    await ctl.animateCamera(CameraUpdate.newLatLngZoom(target, z));
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

  PawFriendState _relationState(String uid) {
    if (_friendController.isFriendWith(uid)) return PawFriendState.friends;
    if (_friendController.hasPendingRequestTo(uid)) return PawFriendState.sent;
    if (_friendController.incomingRequestFrom(uid) != null) {
      return PawFriendState.incoming;
    }
    return PawFriendState.idle;
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
  }) {
    _selectedNearbyId = id;
    _memberSheetRefreshed = false;
    if (mounted) setState(() {});
    final bool onlineNow = _liveMap.isOnline(id) ?? online;
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
      isFriend: isFriend || _friendController.isFriendWith(id),
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
    PawFriendState reqState = _relationState(id);
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
                setSheet(() => reqState = _relationState(id));
              }
            }));
          }
          return PawMapMemberSheet(
            member: member,
            viewerRole: _role,
            viewerLoggedIn: _viewerLoggedIn,
            friendState: reqState,
            priceLabel: priceLabel,
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
              _openMemberProfile(id: id, role: role);
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
  void _openMemberProfile({required String id, required String role}) {
    if (role == 'walker') {
      Get.to(() => WalkerDetailScreen(walkerId: id));
    } else if (role == 'sitter') {
      Get.to(() => ServiceProviderDetailScreen(sitterId: id, status: 'available'));
    } else {
      // Un propriétaire n'a pas de fiche « réservable » : ses infos vivent
      // dans la conversation / la liste d'amis.
      _openScreen(() => const FriendsScreen());
    }
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
    if (_role != 'owner' && _role.isNotEmpty) {
      // Un gardien / promeneur ne réserve pas un confrère : on ouvre sa fiche.
      _openMemberProfile(id: id, role: role);
      return;
    }
    double? daily, weekly, monthly, halfHour, hourly;
    String cur = currency;
    try {
      if (role == 'walker' && Get.isRegistered<WalkerRepository>()) {
        final w = await Get.find<WalkerRepository>().getWalkerProfile(id);
        cur = w.currency;
        for (final r in w.walkRates) {
          if (!r.enabled || r.basePrice <= 0) continue;
          if (r.durationMinutes == 30) halfHour = r.basePrice;
          if (r.durationMinutes == 60) hourly = r.basePrice;
        }
      } else if (Get.isRegistered<SitterRepository>()) {
        final p = await Get.find<SitterRepository>().getSitterProfile(id);
        final data = (p['sitter'] as Map<String, dynamic>?) ??
            (p['profile'] as Map<String, dynamic>?) ??
            p;
        daily = (data['dailyRate'] as num?)?.toDouble();
        weekly = (data['weeklyRate'] as num?)?.toDouble();
        monthly = (data['monthlyRate'] as num?)?.toDouble();
        final c = (data['currency'] ?? '').toString();
        if (c.isNotEmpty) cur = c;
      }
    } catch (e) {
      debugPrint('[PawMap] tarifs du prestataire indisponibles : $e');
    }
    if (!mounted) return;
    Get.to(() => SendRequestScreen(
          serviceProviderName: name,
          serviceProviderId: id,
          serviceProviderRole: role == 'walker' ? 'walker' : 'sitter',
          sitterDailyRate: daily,
          sitterWeeklyRate: weekly,
          sitterMonthlyRate: monthly,
          walkerHalfHourRate: halfHour,
          walkerHourlyRate: hourly,
          currencyCode: cur,
          initialServiceType: role == 'walker' ? 'dog_walking' : 'pet_sitting',
          preselectFirstPet: true,
        ));
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

  /// Lecture locale de `preferences.hideFromMap` (copie du profil).
  static bool _readFriendsOnlyFromProfile() {
    try {
      final profile =
          GetStorage().read<Map<String, dynamic>>(StorageKeys.userProfile);
      final prefs = profile?['preferences'];
      if (prefs is Map) return prefs['hideFromMap'] == true;
    } catch (_) {/* profil illisible */}
    return false;
  }

  bool _visibilitySaving = false;

  /// Tap sur MON rond → « Qui me voit sur la carte ? ».
  void _onMeTap() => _openVisibilitySheet();

  void _openVisibilitySheet() {
    showPawMapSheet<void>(
      context,
      StatefulBuilder(
        builder: (ctx, setSheet) => PawMapVisibilitySheet(
          friendsOnly: _friendsOnly,
          saving: _visibilitySaving,
          onChanged: (v) async {
            if (v == _friendsOnly) {
              Navigator.of(ctx).pop();
              return;
            }
            setSheet(() => _visibilitySaving = true);
            final ok = await _setFriendsOnly(v);
            if (!ctx.mounted) return;
            setSheet(() => _visibilitySaving = false);
            if (ok) Navigator.of(ctx).pop();
          },
        ),
      ),
    );
  }

  /// Enregistre le réglage SUR LE COMPTE (même champ que Préférences :
  /// `preferences.hideFromMap`, propagé aux 3 profils par le serveur) et
  /// confirme. En cas d'échec, rien ne change localement.
  Future<bool> _setFriendsOnly(bool friendsOnly) async {
    try {
      final ok = await _prefs.setHideFromMap(friendsOnly);
      if (!ok) throw Exception('map-prefs refused');
      _friendsOnly = friendsOnly;
      // Copie locale du profil : cohérente avec Préférences sans rechargement.
      try {
        final profile =
            GetStorage().read<Map<String, dynamic>>(StorageKeys.userProfile);
        if (profile != null) {
          final prefs = Map<String, dynamic>.from(
              (profile['preferences'] as Map?) ?? const {});
          prefs['hideFromMap'] = friendsOnly;
          profile['preferences'] = prefs;
          GetStorage().write(StorageKeys.userProfile, profile);
        }
      } catch (_) {/* sans importance */}
      if (mounted) setState(() {});
      CustomSnackbar.showSuccess(
        title: 'pawmap_visibility_title'.tr,
        message: friendsOnly
            ? 'pawmap_visibility_now_friends'.tr
            : 'pawmap_visibility_now_all'.tr,
      );
      return true;
    } catch (e) {
      debugPrint('[PawMap] visibilité : $e');
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'pawmap_visibility_failed'.tr,
      );
      return false;
    }
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
              priceLabel: _priceLabelFor(it.p),
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
    WidgetsBinding.instance.removeObserver(this);
    for (final w in _prefWorkers) {
      w.dispose();
    }
    _sheetCtl.removeListener(_onSheetMoved);
    _sheetCtl.dispose();
    unawaited(_prefs.flush());
    _pendingRouteWorker?.dispose();
    _pendingCenterWorker?.dispose();
    _reloadDebounce?.cancel();
    for (final w in _backGuardWorkers) {
      w.dispose();
    }
    _haloTimer?.cancel();
    _followWorker?.dispose();
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

      // v23.1 part 240 — Daniel : "et tu sur que dans le chat qd je met
      // voir carte sa me met sur le map sur la geoloco du sitter ou
      // walker ?". Avant : on remplacait toujours _currentCenter par MA
      // position GPS, meme si initialLat/Lng (position d'un sitter ou
      // d'un ami) avait ete passe → la map se centrait sur moi a la place.
      // FIX : si on a un initialLat/Lng on garde le centre demande
      // (sitter, walker, ami). On set juste _userPosition pour pouvoir
      // afficher MON point bleu en plus, dans un coin de la carte.
      final hasInitialFocus =
          widget.initialLat != null && widget.initialLng != null;
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
      if (_showPawSpots.value) _pawSpotController.loadNearby(_currentCenter),
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
            'id': (m['id'] ?? '').toString(),
            '_role': (m['role'] ?? '').toString(),
            'name': (m['name'] ?? '').toString(),
            'avatar': m['avatar'] ?? '',
            'location': m['location'],
            'isPremium': m['isPremium'] == true,
            'isMapBoosted': false,
            'isOnline': true,
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
          'maxDistance': '25',
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
        if (dKm < math.max(0.3, visibleKm * 0.25)) return;
      }
      _lastReloadCenter = _currentCenter;
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
      CustomSnackbar.showSuccess(
        title: 'pawmap_snack_tracking_off_title'.tr,
        message: 'pawmap_snack_tracking_off_msg'.tr,
      );
      return;
    }

    // v565 — points 11 / 23 (contrat §8) : durée choisie au démarrage —
    // 1 h / 4 h / jusqu'à l'arrêt (défaut). Le partage ne s'arrête plus
    // qu'à l'échéance ou sur l'interrupteur (plus de cap 2 h ni d'arrêt
    // sur immobilité). Feuille fermée sans choix → on n'active rien.
    final chosen = await _pickLiveDuration();
    if (chosen == null || !mounted) return;

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
    _liveMap.startBroadcasting(
      () => _userPosition ?? _currentCenter,
      duration: chosen,
    );
    CustomSnackbar.showSuccess(
      title: 'pawmap_snack_tracking_on_title'.tr,
      message: 'pawmap_snack_tracking_on_msg'.tr,
    );

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
                      CustomSnackbar.showSuccess(
                        title: 'pawmap_snack_tracking_off_title'.tr,
                        message: 'pawmap_snack_tracking_off_msg'.tr,
                      );
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
      CustomSnackbar.showSuccess(
        title: 'pawmap_snack_tracking_on_title'.tr,
        message: 'v565_live_duration_changed'.tr,
      );
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
      // Point 3 : suivre SANS ouvrir le panneau déroulant → on le replie.
      unawaited(_sheetTo(PawSheetStop.low));
      _startFollow(pos.userId, LatLng(pos.latitude, pos.longitude), name);
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
      _friendsOnly ? 1 : 0,
      _friendController.familyMembers.length,
      _friendController.friends.length,
      _showProviders.value ? 1 : 0,
      _pawSpotController.pawspotActive.value ? 1 : 0,
      _pawSpotController.premiumActive.value ? 1 : 0,
      _selectedNearbyId ?? '',
      _nearbyProviders
          .map((p) =>
              '${p['id'] ?? p['_id']}:${p['isPremium'] == true ? 1 : 0}:${p['isOnline'] != false && p['online'] != false ? 1 : 0}:${p['isBoosted'] == true ? 1 : 0}')
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
  static const double _priceZoom = 15;

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
  }) {
    final phase = boosted ? (_reduceMotion ? 0 : _boostPhaseIdx) : -1;
    final size = PawMapLegend.memberSize;
    final withLabel = priceLabel != null && priceLabel.isNotEmpty;
    final r1 = withLabel ? (rating * 10).round() / 10 : 0.0;
    final key =
        'member:$role:${crown ? 1 : 0}:$phase:${verified ? 1 : 0}:${online ? 1 : 0}:${selected ? 1 : 0}:${priceLabel ?? ''}:$r1';
    final w = PawMapPinPainter.memberBitmapSize(size);
    final h = PawMapPinPainter.memberBitmapSize(size, withLabel: withLabel);
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
    Color fallbackTint = PawMapLegend.owner,
  }) {
    final avatar = _pins.avatarFor(avatarUrl);
    final phase = boosted ? (_reduceMotion ? 0 : _boostPhaseIdx) : -1;
    final withLabel = label != null && label.isNotEmpty;
    final key =
        '$keyPrefix:${avatar == null ? 0 : avatarUrl.hashCode}:${ring.toARGB32()}:$size:${label ?? ''}:${crown ? 1 : 0}:${online ? 1 : 0}:${dashedRing ? 1 : 0}:${eyeOff ? 1 : 0}:$phase';
    final w = PawMapPinPainter.photoBitmapSize(size);
    final h = PawMapPinPainter.photoBitmapSize(size, withLabel: withLabel);
    return _pins.getOrBuild(
          key,
          w,
          h,
          (c) => PawMapPinPainter.paintPhotoDot(
            c,
            avatar: avatar,
            ringColor: ring,
            size: size,
            label: label,
            labelColor: labelColor,
            crown: crown,
            crownSize: crownSize,
            online: online,
            dashedRing: dashedRing,
            eyeOff: eyeOff,
            boostPhase: boosted ? phase / kBoostPhases : null,
            fallbackTint: fallbackTint,
          ),
        ) ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose);
  }

  Offset _photoAnchor(double size, {bool withLabel = false}) {
    final h = PawMapPinPainter.photoBitmapSize(size, withLabel: withLabel);
    return Offset(0.5, (PawMapPinPainter.photoMargin + size / 2) / h);
  }

  BitmapDescriptor _memberClusterIcon(int count, Map<String, int> roleCounts) {
    final sig = ['owner', 'sitter', 'walker']
        .map((k) => '${k[0]}${roleCounts[k] ?? 0}')
        .join();
    final w = PawMapPinPainter.memberClusterWidth(count > 99 ? 100 : count) + 12;
    final h = PawMapLegend.memberClusterHeight + 12;
    return _pins.getOrBuild(
          'mcluster:${count > 99 ? 100 : count}:$sig',
          w,
          h,
          (c) => PawMapPinPainter.paintMemberCluster(c, count,
              roleCounts: roleCounts),
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
              dashedRing: _friendsOnly,
              eyeOff: _friendsOnly,
              fallbackTint: roleColor,
            ),
            anchor: _photoAnchor(PawMapLegend.meSize, withLabel: true),
            zIndexInt: 10,
            onTap: _onMeTap,
          ),
        );
      } catch (_) {/* defensive — le halo rôle reste visible */}
    }

    // ── MEMBRES (proches exacts si abonné + couche monde ~1 km) ──
    if (_showProviders.value) {
      final friendLiveIds = _liveMap.friendPositions.keys
          .map((k) => k.trim().toLowerCase())
          .toSet();
      final bool nearbyVisible = _pawSpotController.pawspotActive.value ||
          _pawSpotController.premiumActive.value;
      final nearbyIds = <String>{};
      final combined = <Map<String, dynamic>>[];
      if (nearbyVisible) {
        for (final p in _nearbyProviders) {
          nearbyIds.add((p['id'] ?? p['_id'] ?? '').toString());
          combined.add(p);
        }
      }
      // v550 — plafond d'affichage de la couche monde (les plus proches).
      final worldPool = <Map<String, dynamic>>[];
      for (final p in _worldMembers) {
        final id = (p['id'] ?? '').toString();
        if (id.isEmpty || nearbyIds.contains(id)) continue;
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
        final r = (p['_role'] ?? p['role'] ?? '').toString().toLowerCase();
        return r.isEmpty || _memberRoles.contains(r);
      }

      // Idée 4 — filtre « Disponible aujourd'hui » (drapeau serveur).
      bool availableOk(Map<String, dynamic> p) =>
          !_availableTodayOnly.value || p['availableToday'] == true;

      final placeable = combined
          .where((p) => posOfMember(p) != null && roleOk(p) && availableOk(p))
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

      final groups = _clusterize<Map<String, dynamic>>(
        placeable,
        (p) => posOfMember(p)!,
        cellPx: _memberClusterCellPx,
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
              icon: _memberClusterIcon(group.length, roleCounts),
              anchor: const Offset(0.5, 0.5),
              zIndexInt: 7,
              onTap: () => _zoomToCluster(target),
            ),
          );
          continue;
        }
        final p = group.first;
        final pos = posOfMember(p)!;
        final id = (p['id'] ?? p['_id'] ?? '').toString();
        if (id.isEmpty) continue;
        // Un membre qui est aussi un ami EN DIRECT garde son marqueur live.
        if (friendLiveIds.contains(id.trim().toLowerCase())) continue;
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
        final bool isFriend = _friendController.isFriendWith(id);
        final priceLabel = role == 'owner' || !showPrice ? '' : _priceLabelFor(p);
        final BitmapDescriptor icon;
        final Offset anchor;
        if (isFriend) {
          icon = _photoIcon(
            keyPrefix: 'friend:$id',
            avatarUrl: avatar,
            ring: PawMapLegend.friend,
            size: PawMapLegend.friendSize,
            crown: premium && _showPremiumLayer.value,
            online: online && !approx,
            boosted: boosted,
            fallbackTint: PawMapLegend.friend,
          );
          anchor = _photoAnchor(PawMapLegend.friendSize);
        } else {
          icon = _memberIcon(
            role: role,
            crown: premium && _showPremiumLayer.value,
            boosted: boosted,
            verified: verified,
            online: online && !approx,
            selected: selected,
            priceLabel: priceLabel,
            rating: (p['rating'] as num?)?.toDouble() ?? 0,
          );
          anchor = _memberAnchor(withLabel: priceLabel.isNotEmpty);
        }
        markers.add(
          Marker(
            markerId: MarkerId('nearby_$id'),
            position: pos,
            icon: icon,
            anchor: anchor,
            zIndexInt: selected ? 9 : (isFriend ? 8 : 6),
            onTap: () => _onNearbyTap(
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
              onTap: () => _zoomToCluster(target),
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
            infoWindow: InfoWindow(
              title: poi.title,
              snippet: poi.address.isNotEmpty
                  ? poi.address
                  : PoiCategories.label(poi.category),
            ),
            onTap: () => _showPoiBottomSheet(poi),
          ),
        );
      }
    }

    // ── PAWSPOTS : goutte noire liserée du type, dorée si golden ; groupe =
    // carré noir chiffre or ──
    if (_showPawSpots.value) {
      final spotGroups = _clusterize<PawSpotModel>(
        _pawSpotController.spots.toList(),
        (s) => LatLng(s.lat, s.lng),
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
              zIndexInt: 4,
              onTap: () => _zoomToCluster(target),
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
            zIndexInt: spot.isGolden ? 5 : 4,
            icon: _spotIcon(spot.type, spot.isGolden),
            infoWindow: InfoWindow(
              title: spot.name,
              snippet: PawSpotTypes.label(spot.type),
            ),
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
            infoWindow: InfoWindow(
              title: '${ReportTypes.emoji(r.type)} ${ReportTypes.labelFr(r.type)}',
              snippet:
                  '${'pawmap_remaining_hours_label'.trParams({'hours': r.liveHoursRemaining.toStringAsFixed(0)})} · ${'pawmap_confirmations'.trParams({'count': r.confirmationsCount.toString()})}',
            ),
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
              online: !pos.isStale,
              fallbackTint: PawMapLegend.roleColor(role),
            ),
            anchor: _photoAnchor(PawMapLegend.friendSize),
            zIndexInt: 8,
            infoWindow: InfoWindow(
              title: displayName,
              snippet: pos.isStale
                  ? '${'v565_live_signal_lost'.tr} · ${'pawmap_seen_ago'.tr.replaceAll('{ago}', _timeAgo(pos.seenAt))}'
                  : '${'v565_live_active'.tr} · ${_timeAgo(pos.seenAt)}',
              onTap: () => _onNearbyTap(
                id: pos.userId,
                role: role,
                name: displayName,
                online: true,
                premium: isPremiumMember,
                lat: pos.latitude,
                lng: pos.longitude,
                avatar: avatarUrl,
                isFriend: true,
              ),
            ),
            // v23.1.263 — taper un ami = suivi « à la trace » (vol doux).
            onTap: () => _startFollow(
              pos.userId,
              LatLng(pos.latitude, pos.longitude),
              displayName,
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
              onTap: () => _showRequestBottomSheet(req),
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
    return PopScope(
      canPop: _followUserId == null &&
          !_mapExpanded.value &&
          !_pickingSpotPos.value &&
          !_pickingRoutePos.value &&
          !_pickingReportPos.value,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
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
        if (_mapExpanded.value) _mapExpanded.value = false;
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
          child: Stack(
          children: [
            // ── LA carte (unique) : toujours premier enfant, toujours à la
            // même place dans l'arbre, avec une clé → jamais recréée.
            Positioned.fill(
              key: const ValueKey<String>('pawmap_google_map'),
              child: _buildGoogleMap(),
            ),

            // v23.1.263 — bannière "Suivi en direct" : visible tant qu'on
            // suit un ami à la trace. Bouton Stop pour reprendre la main.
            if (_followUserId != null)
              Positioned(
                top: MediaQuery.of(context).viewPadding.top + 64.h,
                left: 12.w,
                right: 12.w,
                child: Center(child: _buildFollowingBanner()),
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
            Obx(() {
              final picking = _pickingSpotPos.value ||
                  _pickingReportPos.value ||
                  _pickingRoutePos.value;
              final expanded = _mapExpanded.value;
              // v584 — la feuille glissante recouvre les rails dès qu'elle
              // dépasse sa position basse : ils s'effacent (elle porte les
              // mêmes actions), et reviennent quand elle redescend.
              final sheetUp = !expanded && !picking && _sheetExtent.value >
                  (_sheetPeek.h / _sheetAvailableHeight(context)) + 0.03;
              if (sheetUp) return const SizedBox.shrink();
              return Positioned(
                left: 12.w,
                right: 12.w,
                bottom: _railBottom(context,
                    expanded: expanded, picking: picking),
                child: Row(
                  // v561 — Daniel : colonne de gauche alignée sur le BAS de la
                  // capsule de droite (jamais centrée).
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!picking)
                      _railScroller(
                        _buildMapActionsColumn(),
                        expanded: expanded,
                      ),
                    const Spacer(),
                    _buildMapControlsStack(),
                  ],
                ),
              );
            }),

            // ── v584 — FEUILLE GLISSANTE (petite carte) ──
            // Trois positions : basse (poignée + bouton principal), moyenne
            // (« Je cherche », compteur, filtres), haute (actions, calques,
            // abonnements). Posée au-dessus du menu ; absente en carte
            // agrandie (le dock la remplace) et pendant un placement.
            Obx(() {
              final picking = _pickingSpotPos.value ||
                  _pickingReportPos.value ||
                  _pickingRoutePos.value;
              if (_mapExpanded.value || picking) return const SizedBox.shrink();
              return Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: _menuInset(context),
                child: _buildSheet(),
              );
            }),

            // v23.1.187 — carte « Autour de vous » (petite carte seulement) ;
            // v554 — jamais pendant un placement ni quand un itinéraire est
            // affiché (le bandeau distance + Effacer prend sa place).
            Obx(() {
              final picking = _pickingSpotPos.value ||
                  _pickingReportPos.value ||
                  _pickingRoutePos.value;
              final expanded = _mapExpanded.value;
              if (picking) return const SizedBox.shrink();
              if (_routePolylines.isEmpty) {
                if (expanded) return const SizedBox.shrink();
                return Positioned(
                  left: 72.w,
                  right: 62.w,
                  bottom: _menuInset(context) + _sheetPeek.h + 8.h,
                  child: _buildAroundYouCard(),
                );
              }
              // Bandeau d'itinéraire : entre les deux rails (petite carte) ;
              // en haut sous la rangée Partager/Réduire (carte agrandie, le
              // bas est occupé par le dock et les rails — v554/v559).
              if (expanded) {
                return Positioned(
                  top: MediaQuery.of(context).viewPadding.top + 64.h,
                  left: 12.w,
                  right: 12.w,
                  child: Center(child: _buildDirectionsBanner()),
                );
              }
              return Positioned(
                left: 12.w,
                right: 12.w,
                bottom: _menuInset(context) + _sheetPeek.h + 16.h,
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

            // ── Haut de l'écran ──
            // Petite carte : en-tête flottant (logo, titre, recherche,
            // rafraîchir) + rangée Partager en direct / Agrandir + panneau.
            // Carte agrandie : rangée Partager en direct / Réduire seulement.
            // Masqué pendant un placement (la bulle d'aide doit rester seule).
            Obx(() {
              final picking = _pickingSpotPos.value ||
                  _pickingReportPos.value ||
                  _pickingRoutePos.value;
              if (picking) return const SizedBox.shrink();
              final expanded = _mapExpanded.value;
              return Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: expanded
                      ? Padding(
                          padding: EdgeInsets.only(top: 8.h),
                          child: Row(
                            children: [
                              Expanded(child: _buildLiveBroadcastBanner()),
                              _buildExpandPill(expanded: true),
                              SizedBox(width: 12.w),
                            ],
                          ),
                        )
                      : Column(
                          key: _topAreaKey,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildFloatingHeader(),
                            _buildTopRow(),
                          ],
                        ),
                ),
              );
            }),

            // ── Carte agrandie : bouton RETOUR (bas-gauche) + dock ──
            // v565 point 20 : sur la grande carte le menu du bas a disparu →
            // bouton Retour qui réduit la carte. v552 : dock (SOS animal,
            // Partager la carte, Calques, Mode nuit, Historique). Les deux
            // s'effacent pendant un placement (ils recouvraient Valider).
            Obx(() {
              final picking = _pickingSpotPos.value ||
                  _pickingReportPos.value ||
                  _pickingRoutePos.value;
              if (!_mapExpanded.value || picking) {
                return const SizedBox.shrink();
              }
              return Positioned(
                left: 0,
                right: 0,
                bottom: _navInset(context) + 14.h,
                child: Stack(
                  children: [
                    _buildMapDock(),
                    Positioned(
                      left: 12.w,
                      bottom: 0,
                      child: _buildExpandedBackButton(),
                    ),
                  ],
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
    );
  }

  /// v584 — ligne de base (depuis le bas) de la rangée des rails.
  ///  · petite carte : 168 au-dessus du menu flottant (v561), 284 pendant
  ///    un placement (au-dessus de la carte Annuler/Valider) ;
  ///  · carte agrandie : au-dessus du dock (14 + 46 + 22 = 82, v553), 136
  ///    pendant un placement (le dock est masqué, la carte de placement prend
  ///    sa place).
  double _railBottom(BuildContext context,
      {required bool expanded, required bool picking}) {
    if (expanded) return _navInset(context) + (picking ? 136.h : 82.h);
    if (picking) {
      return 284.h - _tabBarLift(context) +
          MediaQuery.of(context).viewPadding.bottom;
    }
    // v584 — au-dessus de la feuille glissante en position basse.
    return _menuInset(context) + _sheetPeek.h + 12.h;
  }

  /// v584 — en-tête flottant de la petite carte (remplace l'AppBar : la carte
  /// passe dessous, il ne la redimensionne jamais). Logo patte-épingle dans
  /// sa tuile (v573/v575), titre Poppins, recherche de ville, rafraîchir.
  Widget _buildFloatingHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 6.h, 12.w, 0),
      child: Row(
        children: [
          PawMapHeaderBadge(size: 38.w),
          SizedBox(width: 10.w),
          PoppinsText(
            text: 'PawMap',
            fontSize: 20.sp,
            fontWeight: FontWeight.w800,
            color: PawMapTheme.inkOn(context),
          ),
          const Spacer(),
          // v23.1.189 — recherche de ville (loupe) + mettre à jour (v554 :
          // spinner à la place du bouton pendant le rechargement).
          // v584 — « ? » : la légende en images (Daniel : « que les gens
          // comprennent ce qu'ils font »).
          _headerRoundButton(
            key: const ValueKey<String>('pawmap_header_legend'),
            icon: Icons.question_mark_rounded,
            label: 'pawmap_legend_btn'.tr,
            onTap: _openLegend,
          ),
          SizedBox(width: 8.w),
          _headerRoundButton(
            key: const ValueKey<String>('pawmap_header_search'),
            icon: Icons.search_rounded,
            label: 'pawmap_search_city'.tr,
            onTap: _onSearchCity,
          ),
          SizedBox(width: 8.w),
          Obx(() => _refreshing.value
              ? SizedBox(
                  width: 40.w,
                  height: 40.w,
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
                  icon: Icons.refresh_rounded,
                  label: 'pawmap_appbar_refresh'.tr,
                  onTap: _manualRefresh,
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
  }) {
    return PawPressable(
      key: key,
      label: label,
      onTap: onTap,
      child: PawGlassPill(
        color: AppColors.primaryColor.withValues(alpha: 0.35),
        height: 40.w,
        width: 40.w,
        padding: EdgeInsets.zero,
        child: Icon(icon,
            size: 21.sp,
            color: AppColors.accentOn(context, AppColors.primaryColor)),
      ),
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
      // v552 — mode nuit ; v584 — agrandi (padding de la carte).
      final night = _nightMode.value;
      final expanded = _mapExpanded.value;
      return GoogleMap(
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
          }
        },
        onCameraMove: _onCameraMove,
        // v23.1.263 — un geste MANUEL coupe le suivi (sauf si c'est nous qui
        // recentrons : `_suppressFollowAutoStop`). Valait seulement sur la
        // petite carte avant la fusion ; vaut partout désormais.
        onCameraMoveStarted: () {
          // v584 — un geste met le suivi en PAUSE (bouton « Reprendre »).
          if (_followUserId != null && !_suppressFollowAutoStop) {
            _pauseFollow();
          }
        },
        onCameraIdle: _scheduleReload,
        myLocationEnabled: true,
        // v23.1 part 68 — nos propres commandes (capsule droite).
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        // v584 — le logo Google et les cibles de caméra évitent le menu du
        // bas (petite carte) : la carte, elle, ne change pas de taille.
        padding: EdgeInsets.only(
          bottom: expanded ? 0 : 100.h - _tabBarLift(context),
        ),
        mapType: _mapType,
        style: night ? _nightMapStyle : null,
        // v23.1 part 243 round 3 — marqueurs mémoïsés (_getMarkersFromCache).
        markers: _routeStepMarkers.isEmpty
            ? _getMarkersFromCache()
            : {..._getMarkersFromCache(), ..._routeStepMarkers},
        circles: _buildHaloCircles(),
        // v23.1.353 — polyline de l'itinéraire "Y aller" ; v584 — tracé
        // violet du suivi.
        polylines: {..._routePolylines, ..._followPolylines()},
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
      children: [
        PawCapsuleButton(
          icon: Icons.my_location_rounded,
          label: 'pawmap_quick_follow'.tr,
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
          onTap: _fitAllFriends,
        ),
      ],
    );
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
  /// Recentre la caméra sur [target]. Marque le mouvement comme "programmatique"
  /// pendant ~800 ms pour que onCameraMoveStarted ne coupe pas le suivi.
  Future<void> _animateFollowCamera(LatLng target, {double? zoom}) async {
    // v584 — une seule carte : on anime LE contrôleur.
    final ctl = await _activeMapCtl();
    if (ctl == null) return;
    _suppressFollowAutoStop = true;
    try {
      if (zoom != null) {
        await ctl.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
      } else {
        // newLatLng conserve le zoom courant → suivi fluide sans re-zoomer.
        await ctl.animateCamera(CameraUpdate.newLatLng(target));
      }
    } catch (_) {/* map pas prête */}
    Future.delayed(const Duration(milliseconds: 800), () {
      _suppressFollowAutoStop = false;
    });
  }

  /// Démarre le suivi d'un ami — zoom de suivi « joli » (Daniel, 23/09) : la
  /// caméra VOLE en douceur jusqu'au point et s'arrête à un zoom de rue
  /// lisible (16,5) ; ensuite elle suit le point sans re-zoomer (pas de
  /// recentrage brutal), et le tracé se dessine en violet PawFollow.
  void _startFollow(String userId, LatLng pos, String name) {
    setState(() {
      _followUserId = userId;
      _followName = name;
      _followPaused = false;
      _followTrail = <LatLng>[pos];
    });
    _animateFollowCamera(pos, zoom: _followZoom);
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
    setState(() => _followPaused = false);
    final fp = _liveMap.friendPositions[uid];
    if (fp != null) {
      _animateFollowCamera(LatLng(fp.latitude, fp.longitude), zoom: _followZoom);
    }
  }

  /// Arrête le suivi (bouton Stop, retour Android).
  void _stopFollow() {
    if (_followUserId == null) return;
    setState(() {
      _followUserId = null;
      _followName = '';
      _followPaused = false;
      _followTrail = const <LatLng>[];
    });
  }

  /// Tracé violet PawFollow derrière la personne suivie.
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

  /// Bannière "Suivi en direct" affichée tant qu'on suit un ami à la trace ;
  /// en pause : « Suivi en pause · Reprendre ».
  Widget _buildFollowingBanner() {
    final name = _followName.trim().isEmpty
        ? 'pawmap_following_default'.tr
        : _followName.trim();
    final paused = _followPaused;
    final Color tone = paused ? PawMapLegend.ink : PawMapLegend.pawFollow;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: tone.withValues(alpha: 0.30),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9.w,
            height: 9.w,
            decoration: BoxDecoration(
              color: paused ? PawMapLegend.gold : Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8.w),
          Flexible(
            child: InterText(
              text: paused
                  ? 'pawmap_follow_paused'.tr
                  : 'pawmap_following_label'.trParams({'name': name}),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              maxLines: 1,
            ),
          ),
          SizedBox(width: 10.w),
          if (paused)
            GestureDetector(
              key: const ValueKey<String>('follow_resume'),
              onTap: _resumeFollow,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: PawMapLegend.gold,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: InterText(
                  text: 'pawmap_follow_resume'.tr,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: PawMapLegend.ink,
                ),
              ),
            ),
          if (paused) SizedBox(width: 6.w),
          GestureDetector(
            key: const ValueKey<String>('follow_stop'),
            onTap: _stopFollow,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: InterText(
                text: 'pawmap_following_stop'.tr,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // v23.1.316 — Daniel : "le zoom de la PawMap tu peux améliorer ?". Avant :
  // zoomIn()/zoomOut() sautaient d'UN niveau entier (×2 d'un coup) -> effet
  // brusque/saccadé. On passe à un pas plus doux de ±0.8 niveau (zoomBy) pour
  // un zoom progressif et fluide, toujours animé.
  /// v584 — LE contrôleur de la carte (null tant qu'elle n'est pas créée).
  /// Gardé sous ce nom : tous les gestes de caméra passent par ici.
  Future<GoogleMapController?> _activeMapCtl() async {
    if (!_mapCtl.isCompleted) return null;
    return _mapCtl.future;
  }

  Future<void> _zoomIn() async {
    final ctl = await _activeMapCtl();
    if (ctl == null) return;
    // Zoomer ne doit pas couper le suivi en cours.
    if (_followUserId != null) _suppressFollowAutoStop = true;
    await ctl.animateCamera(CameraUpdate.zoomBy(0.8));
    if (_followUserId != null) {
      Future.delayed(const Duration(milliseconds: 800),
          () => _suppressFollowAutoStop = false);
    }
  }

  Future<void> _zoomOut() async {
    final ctl = await _activeMapCtl();
    if (ctl == null) return;
    if (_followUserId != null) _suppressFollowAutoStop = true;
    await ctl.animateCamera(CameraUpdate.zoomBy(-0.8));
    if (_followUserId != null) {
      Future.delayed(const Duration(milliseconds: 800),
          () => _suppressFollowAutoStop = false);
    }
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
            bottom: pawMapExpanded.value
                ? _navInset(context) + 12.h
                : 140.h - _tabBarLift(context) + MediaQuery.of(context).viewPadding.bottom,
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


  // ─── v584 — HAUT DE LA PETITE CARTE ─────────────────────────────────────
  // Le panneau blanc du haut (v552) est devenu la FEUILLE GLISSANTE du bas
  // (`_buildSheet`). En haut ne restent que la rangée « Partager en direct /
  // Agrandir » et, si je suis « visible par mes amis seulement », la
  // pastille qui permet de rebasculer en un geste.
  Widget _buildTopRow() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTopShareRow(),
        if (_friendsOnly)
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: PawMapFriendsOnlyPill(onTap: _openVisibilitySheet),
            ),
          ),
      ],
    );
  }

  /// Hauteur commune des trois cadres de la rangée repliée.
  /// v573 — jeton partagé : filtres, « Partager en direct » et « Agrandir »
  /// tirent leur hauteur, leur rayon et leur épaisseur de bord du MÊME endroit
  /// (PawMapTheme.pill*), sans quoi les trois pilules ne tombaient pas juste.
  static double get _topRowHeight => PawMapTheme.pillHeight.h;

  /// Corps de texte commun aux pilules du haut (InterText, graisse 800).
  /// ⚠️ Valeur BRUTE : `InterText` applique `.sp` lui-même — l'écrire `12.sp`
  /// ici la mettait au carré et rendait le libellé minuscule à 320 dp.
  static const double _topPillFontSize = 12;

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

  /// Chips de filtre : centrés, passent à la ligne, JAMAIS de défilement
  /// horizontal (règle posée par Daniel en v447 et reprise par la maquette).
  /// Signalements / Gardiens / Promeneurs / Propriétaires sont cumulables ;
  /// « Tous » et « Rien » ne sont que des raccourcis.
  Widget _buildPanelFilters() {
    // v552 — Daniel : « autour de Tous ou Rien, un contour rose pour savoir
    // lequel est sélectionné ». `outlined` entoure le raccourci actif.
    // v552 — Daniel : « le fond noir des boutons, mets une couleur plus
    // douce ». Un chip actif prend désormais la COULEUR DE SON TYPE en
    // pastel (bleu gardien, vert promeneur, orange propriétaire, rouge
    // signalement) : c'est plus doux que le noir de la maquette ET ça reprend
    // le code couleur des points sur la carte — on lit le filtre d'un coup
    // d'œil. Inactif = gris très clair.
    Widget chip(String label, bool active, VoidCallback onTap,
        {bool rose = false,
        Widget? trailing,
        bool outlined = false,
        Color tone = PawMapTheme.ink}) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 7.h),
          decoration: BoxDecoration(
            color: rose
                ? PawMapTheme.rose
                : (active
                    ? tone.withValues(
                        alpha: PawMapTheme.isDark(context) ? 0.18 : 0.14)
                    : PawMapTheme.veilOn(context, 0.05, darkAlpha: 0.10)),
            borderRadius: BorderRadius.circular(999),
            border: outlined
                ? Border.all(color: PawMapTheme.rose, width: 2)
                : (active
                    ? Border.all(
                        color: PawMapTheme.toneOn(context, tone)
                            .withValues(alpha: 0.35),
                        width: 1.4)
                    : null),
            boxShadow: rose
                ? [
                    BoxShadow(
                      color: PawMapTheme.rose.withValues(alpha: 0.30),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: PawMapTheme.font(
                  size: 11.5.sp,
                  weight: active || rose ? FontWeight.w700 : FontWeight.w600,
                  color: rose
                      ? Colors.white
                      : (active
                          ? PawMapTheme.toneOn(context, tone)
                          : PawMapTheme.veilOn(context, 0.62,
                              darkAlpha: 0.78)),
                ),
              ),
              if (trailing != null) ...[SizedBox(width: 5.w), trailing],
            ],
          ),
        ),
      );
    }

    return Obx(() {
      final open = _showCatFilter.value;
      final roles = _memberRoles;
      void toggleRole(String r) {
        if (roles.contains(r)) {
          _memberRoles.remove(r);
        } else {
          _memberRoles.add(r);
        }
        _memberRoles.refresh();
        if (mounted) setState(() {});
      }

      // Raccourcis : « Tous » est actif quand TOUT est affiché, « Rien »
      // quand plus rien ne l'est — le contour rose montre lequel s'applique.
      final everythingOn = _showPois.value &&
          _showReports.value &&
          roles.length >= 3;
      final nothingOn =
          !_showPois.value && !_showReports.value && roles.isEmpty;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            alignment: WrapAlignment.center,
            children: [
              chip(
                'pawmap_filter_places'.tr,
                _showPois.value,
                () => _showCatFilter.value = !open,
                rose: true,
                trailing: Icon(
                  open
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 13.sp,
                  color: Colors.white,
                ),
              ),
              chip('pawmap_filter_reports'.tr, _showReports.value,
                  () => _showReports.value = !_showReports.value,
                  tone: PawMapTheme.danger),
              chip('role_pet_sitter'.tr, roles.contains('sitter'),
                  () => toggleRole('sitter'), tone: PawMapTheme.sitter),
              chip('role_pet_walker'.tr, roles.contains('walker'),
                  () => toggleRole('walker'), tone: PawMapTheme.walker),
              chip('role_pet_owner'.tr, roles.contains('owner'),
                  () => toggleRole('owner'), tone: PawMapTheme.owner),
              // v584 — idée 4 : « Disponible aujourd'hui » (drapeau serveur).
              chip('pawmap_sheet_available_today'.tr, _availableTodayOnly.value,
                  () => _availableTodayOnly.value = !_availableTodayOnly.value,
                  tone: PawMapTheme.walker),
              chip('paw_map_filter_all'.tr, false, outlined: everythingOn, () {
                _showPois.value = true;
                _showReports.value = true;
                _poiController.selectAllCategories();
                _memberRoles.addAll({'sitter', 'walker', 'owner'});
                _memberRoles.refresh();
                if (mounted) setState(() {});
              }),
              chip('pawmap_filter_none'.tr, false, outlined: nothingOn, () {
                _showPois.value = false;
                _showReports.value = false;
                _memberRoles.clear();
                _memberRoles.refresh();
                if (mounted) setState(() {});
              }),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: open
                ? _buildCategoryChecklist(_poiController.enabledCategories
                    .where((c) => c != '__none__')
                    .toSet())
                : const SizedBox.shrink(),
          ),
        ],
      );
    });
  }

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
  Widget _buildPanelModules() {
    Widget module(String label, bool on, VoidCallback onTap, Color accent) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: PawMapTheme.veilOn(context, 0.04, darkAlpha: 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  // v552 — « PawFollow » et « PawPremium » sont des marques :
                  // on les réduit plutôt que de les tronquer en « PawFollo… ».
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: PawMapTheme.fontOn(context,
                          size: 9.5.sp, weight: FontWeight.w700),
                    ),
                  ),
                ),
                SizedBox(width: 6.w),
                Container(
                  width: 32.w,
                  height: 19.h,
                  padding: EdgeInsets.all(2.w),
                  alignment:
                      on ? Alignment.centerRight : Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: on
                        ? accent
                        : (PawMapTheme.isDark(context)
                            ? const Color(0xFF664F4A)
                            : const Color(0xFFDCD4C8)),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Container(
                    width: 15.w,
                    height: 15.w,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Obx(() {
      final followSub = _pawSpotController.followActive.value;
      final premiumOn = _pawSpotController.premiumActive.value;
      return Row(
        children: [
          module('PawFollow', followSub && _showLiveLayer.value,
              _togglePawFollow, PawMapTheme.pawFollow),
          SizedBox(width: 6.w),
          module('PawSpot', _showPawSpots.value, _togglePawSpot,
              PawMapTheme.pawSpot),
          SizedBox(width: 6.w),
          module('PawPremium', premiumOn && _showPremiumLayer.value,
              _togglePawPremium, PawMapTheme.ok),
        ],
      );
    });
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

  // ─── Floating action button for creating reports ─────────────────────────
  // v21.1.1 — corner button passé en pill extended : icône + label texte
  // visible (ex "PawPass", "PawSpot") au lieu d'un cercle anonyme. Beaucoup
  // plus parlant pour les freemium users qui découvrent la boutique.
  // Shadow colorée pour profondeur, gradient subtle pour donner du relief.
  /// v23.1.189 — Daniel : "paw follow et pawspot un design beaucoupl plus
  /// moderne et jolie". Pastille glassy : fond blanc translucide, accent
  /// vif a gauche (pastille couleur ronde + icone blanche dessus), label
  /// en gras a droite, ombre douce + halo coloré soft.
  /// pour que le user comprenne qu'il est visible par ses amis.
  /// v558 — coupe un libellé en deux lignes à l'espace le plus proche du
  /// milieu (« Partager en direct » → « Partager / en direct »). Sans espace
  /// (japonais), le libellé reste sur une ligne et le FittedBox le réduit.
  static String _twoLines(String s) {
    final t = s.trim();
    final mid = t.length ~/ 2;
    int best = -1;
    for (int i = 0; i < t.length; i++) {
      if (t[i] == ' ' && (best < 0 || (i - mid).abs() < (best - mid).abs())) {
        best = i;
      }
    }
    if (best < 0) return t;
    return '${t.substring(0, best)}\n${t.substring(best + 1)}';
  }

  /// v558 — `compact` : cellule de la rangée repliée (largeur = 1/3 de
  /// l'écran, hauteur imposée par la rangée) : marges gérées par la rangée,
  /// texte sur 2 lignes max, point et interrupteur réduits. Le texte n'est
  /// jamais tronqué : il se réduit (FittedBox) si une langue est plus longue.
  Widget _buildLiveBroadcastBanner({bool compact = false}) {
    // v418 — maquette Daniel : bannière TOUJOURS visible avec interrupteur
    // ON/OFF. C'est LE contrôle du partage en direct.
    // v565 (18/09) — Daniel : pilule modernisée, mêmes couleurs : verre blanc
    // translucide + liseré vert quand OFF ; vert plein (point blanc + « En
    // direct · 3h58 », interrupteur vert) quand ON ; orange « Signal perdu »
    // si le signal est coupé. Tap sur le libellé = sous-menu de durée.
    const green = Color(0xFF16A34A);
    const amber = Color(0xFFE8920A);
    return Obx(() {
      final on = _liveMap.broadcasting.value;
      _liveMap.staleTick.value;
      final lost = on && _liveMap.liveStatus.value == LiveShareStatus.lost;
      final rem = _liveMap.remaining;
      String label = on
          ? (lost ? 'v565_live_signal_lost'.tr : 'v565_live_active'.tr)
          : 'pawmap_live_share_off'.tr;
      if (on && !lost && rem != null) {
        final h = rem.inHours;
        final m = rem.inMinutes % 60;
        label =
            '$label · ${h > 0 ? '${h}h${m.toString().padLeft(2, '0')}' : '${rem.inMinutes} min'}';
      }
      final Color tone = lost ? amber : green;
      final Color fg = on ? Colors.white : AppColors.textPrimary(context);
      final switchW = compact ? 36.w : 44.w;
      return Padding(
        padding: compact
            ? EdgeInsets.zero
            : EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 0),
        child: PawGlassPill(
          color: tone,
          filled: on,
          gradient: on
              ? LinearGradient(
                  colors: lost
                      ? const [Color(0xFFE8920A), Color(0xFFD97706)]
                      : const [Color(0xFF16A34A), Color(0xFF059669)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          height: compact ? double.infinity : _topRowHeight,
          padding: EdgeInsets.fromLTRB(10.w, 0, 4.w, 0),
          child: Row(
            children: [
              // v573 — pastille d'état ANIMÉE : elle grossit et s'auréole
              // quand le partage est actif (vert, ou ambre « signal perdu »),
              // et redevient un point gris discret à l'arrêt. Le halo est
              // blanc sur fond plein, teinté sur fond clair.
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOut,
                width: (on ? 10 : 8).w,
                height: (on ? 10 : 8).w,
                decoration: BoxDecoration(
                  color: on
                      ? Colors.white
                      : AppColors.textSecondary(context)
                          .withValues(alpha: 0.75),
                  shape: BoxShape.circle,
                  boxShadow: on
                      ? [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.75),
                            blurRadius: 7,
                            spreadRadius: 0.5,
                          ),
                        ]
                      : null,
                ),
              ),
              SizedBox(width: 7.w),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => unawaited(_openLiveDurationSheet()),
                  child: Tooltip(
                    message: 'pawmap_live_banner_msg'.tr,
                    // Jamais de débordement (allemand / portugais) : deux
                    // lignes max, réduit si besoin, jamais tronqué.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: InterText(
                        text: compact ? _twoLines(label) : label,
                        // v573 — même corps et même graisse que « Agrandir » :
                        // les trois pilules du haut partagent leur typo.
                        fontSize: _topPillFontSize,
                        fontWeight: FontWeight.w800,
                        color: fg,
                        maxLines: compact ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        height: 1.05,
                      ),
                    ),
                  ),
                ),
              ),
              // v573 — interrupteur propre : sur la pilule PLEINE (partage
              // actif) un rail vert sur fond vert ne se voyait pas → rail
              // blanc translucide + liseré blanc ; à l'arrêt, rail gris et
              // pastille blanche cerclée. Le vert « actif » suit la teinte
              // courante (ambre quand le signal est perdu).
              SizedBox(
                width: switchW,
                height: 24.h,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Switch(
                    value: on,
                    onChanged: (_) => _toggleBroadcast(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    activeThumbColor: Colors.white,
                    activeTrackColor:
                        Colors.white.withValues(alpha: 0.34),
                    trackOutlineColor: WidgetStateProperty.resolveWith(
                        (st) => st.contains(WidgetState.selected)
                            ? Colors.white.withValues(alpha: 0.9)
                            // v584 — « aucun gris » : rail à l'arrêt en
                            // teinte chaude PLEINE (vert pâle), liseré vert.
                            : green.withValues(alpha: 0.55)),
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: const Color(0xFFBFE8CB),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ─── v463 — Mode « carte agrandie » ──────────────────────────────────────

  /// Barre du haut (mode normal) : la bannière « Suivi en direct ON/OFF »
  /// (inchangée) + un bouton COMPACT « Agrandir » sur la même ligne.
  Widget _buildTopShareRow() {
    return Row(
      children: [
        // La bannière conserve ses marges L/R = 12 → elle gère le bord gauche
        // et l'écart avant le bouton.
        Expanded(child: _buildLiveBroadcastBanner()),
        _buildExpandPill(expanded: false),
        SizedBox(width: 12.w),
      ],
    );
  }

  /// Bouton compact Agrandir / Réduire (≈ 50 % plus petit, discret).
  /// v465 — en mode AGRANDI, fond ROSE intense (Daniel) ; en mode normal,
  /// pilule blanche discrète.
  /// v558 — `fill` : cellule de la rangée repliée (remplit sa case, sans marge
  /// haute, même rayon que ses deux voisines).
  Widget _buildExpandPill({required bool expanded, bool fill = false}) {
    // v565 (18/09) — Daniel : pilule modernisée, même rose : verre blanc +
    // liseré rose (Agrandir) ; rose plein (Réduire, carte agrandie). Icône et
    // libellé alignés, FittedBox → jamais de débordement.
    const pink = Color(0xFFEC1E79); // rose intense
    final fg = expanded ? Colors.white : pink;
    final label = expanded ? 'pawmap_reduce_map'.tr : 'pawmap_expand_short'.tr;
    return Padding(
      padding: EdgeInsets.only(top: fill ? 0 : 8.h),
      child: PawPressable(
        label: label,
        onTap: () => _mapExpanded.value = !expanded,
        child: PawGlassPill(
          color: pink,
          filled: expanded,
          height: fill ? double.infinity : _topRowHeight,
          width: fill ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                expanded
                    ? Icons.close_fullscreen_rounded
                    : Icons.open_in_full_rounded,
                size: 17.sp,
                color: fg,
              ),
              SizedBox(width: 6.w),
              // Pas de Flexible : la pilule vit aussi dans une Row à largeur
              // libre (rangée du haut) → largeur bornée explicitement.
              // v573 — pas de Flexible ici : hors rangée repliée la pilule vit
              // dans une Row à largeur NON bornée (RenderFlex planterait). Le
              // plafond de largeur + FittedBox + ellipsis suffisent à tenir à
              // 320 dp, en allemand comme en polonais.
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 88.w),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: InterText(
                    text: label,
                    fontSize: _topPillFontSize,
                    fontWeight: FontWeight.w800,
                    color: fg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
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
  void _openRailCustomize() {
    showPawMapSheet<void>(
      context,
      PawRailCustomizeSheet(
        order: _railOrder,
        onChanged: (order) {
          if (!mounted) return;
          setState(() => _railOrder = order);
          _prefs.update({'rail': order});
        },
      ),
    );
  }

  // ─── v584 — FEUILLE GLISSANTE (3 positions) + bouton principal ───────────

  late final DraggableScrollableController _sheetCtl =
      DraggableScrollableController();

  /// Position courante de la feuille (fraction de la hauteur disponible) —
  /// les rails se retirent quand la feuille dépasse sa position basse.
  final RxDouble _sheetExtent = 0.0.obs;
  static const double _sheetPeek = 100;
  bool _sheetIsLow = true;

  /// 'all' | 'sitters' | 'walkers' | 'places' | 'friends' (idée 6).
  String _lookingFor = 'all';

  /// Hauteur (px) du menu du bas sous la carte. Dans les onglets, la feuille
  /// doit rester AU-DESSUS de toute la barre « patte » (pilule + saillie de la
  /// patte, `pawTabBarTotalHeight`) : la zone tactile de la patte est
  /// centrée, exactement là où vivent la poignée et le bouton principal, et
  /// elle passe devant le corps (Daniel : « le menu ne doit gêner AUCUN
  /// bouton »). Empilée hors onglets, seule la barre système reste.
  double _menuInset(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (_tabBarLift(context) > 0) return mq.viewPadding.bottom;
    return pawTabBarTotalHeight(mq.viewPadding.bottom);
  }

  double _sheetAvailableHeight(BuildContext context) {
    final mq = MediaQuery.of(context);
    return math.max(200.0, mq.size.height - _menuInset(context));
  }

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
      PawSheetStop.low => (_sheetPeek.h / h).clamp(0.08, 0.5).toDouble(),
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
    final h = _sheetAvailableHeight(context);
    final low = (_sheetPeek.h / h).clamp(0.08, 0.5).toDouble();
    final isLow = size <= low + 0.03;
    if (isLow != _sheetIsLow) {
      _sheetIsLow = isLow;
      _prefs.update({'panelCollapsed': isLow});
      if (mounted) setState(() {});
    }
  }

  Widget _buildSheet() {
    return PawMapSheet(
      controller: _sheetCtl,
      availableHeight: _sheetAvailableHeight(context),
      peekHeight: _sheetPeek.h,
      highFraction: _sheetHighFraction(context),
      header: _buildPrimaryAction(),
      children: [
        PawMapLookingSelector(value: _lookingFor, onChanged: _applyLooking),
        SizedBox(height: 12.h),
        _buildPanelCounterRow(),
        Obx(() {
          // Idée 1 — carte vide = une action (au zoom quartier, données lues).
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
        SizedBox(height: 12.h),
        _sheetSection('pawmap_sheet_filters'.tr),
        _buildPanelFilters(),
        SizedBox(height: 14.h),
        _sheetSection('pawmap_sheet_actions'.tr),
        _buildPanelActions(),
        SizedBox(height: 8.h),
        Obx(() => PawMapDockRow(
              wrap: true,
              nightMode: _nightMode.value,
              onSos: _openSosAnimal,
              onShare: _shareCurrentMap,
              onLayers: _openLayersSheet,
              onNight: _toggleNightMode,
              onHistory: _openHistory,
              onLongPress: _showDockHelp,
            )),
        SizedBox(height: 14.h),
        _sheetSection('pawmap_sheet_more'.tr),
        _buildPanelModules(),
        SizedBox(height: 6.h),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: _showPawMapToggleInfo,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 6.h),
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
          ),
        ),
      ],
    );
  }

  Widget _sheetSection(String title) => Padding(
        padding: EdgeInsets.only(bottom: 8.h, left: 2.w),
        child: Text(
          title.toUpperCase(),
          style: PawMapTheme.fontOn(context,
              size: 11.sp,
              weight: FontWeight.w800,
              letterSpacing: 0.6,
              color: PawMapTheme.subOn(context)),
        ),
      );

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
      final live = _liveMap.broadcasting.value;
      final role = _role;
      final Color roleColor = PawMapLegend.roleColor(role.isEmpty ? 'owner' : role);
      if (_followUserId != null && _followPaused) {
        return PawSignatureButton(
          key: const ValueKey<String>('pawmap_primary'),
          label: 'pawmap_primary_resume_follow'.tr,
          icon: Icons.play_arrow_rounded,
          color: PawMapLegend.pawFollow,
          onTap: _resumeFollow,
        );
      }
      if (!_viewerLoggedIn) {
        return PawSignatureButton(
          key: const ValueKey<String>('pawmap_primary'),
          label: 'pawmap_member_signup_to_book'.tr,
          icon: Icons.person_add_alt_1_rounded,
          color: roleColor,
          onTap: () => SignupWallSheet.show(trigger: 'booking'),
        );
      }
      if (role == 'owner' && _myRequests.isEmpty) {
        return PawSignatureButton(
          key: const ValueKey<String>('pawmap_primary'),
          label: 'pawmap_primary_publish'.tr,
          icon: Icons.campaign_rounded,
          color: roleColor,
          onTap: () => Get.to(() => const PublishReservationRequestScreen()),
        );
      }
      if (_isSitterOrWalker && _requests.isNotEmpty) {
        return PawSignatureButton(
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
      }
      return PawSignatureButton(
        key: const ValueKey<String>('pawmap_primary'),
        label: live ? 'v565_live_active'.tr : 'pawmap_primary_share_live'.tr,
        icon: live ? Icons.podcasts_rounded : Icons.share_location_rounded,
        color: live ? PawMapLegend.walker : roleColor,
        onTap: () => unawaited(_openLiveDurationSheet()),
      );
    });
  }

  /// Idée 1 — carte vide : le propriétaire publie, le prestataire complète
  /// son profil (onglet Profil).
  void _onEmptyAction() {
    if (_role == 'owner' || _role.isEmpty) {
      Get.to(() => const PublishReservationRequestScreen());
    } else {
      openMainTabOr(4, () => const PawMapScreen());
    }
  }

  /// Idée 6 — « Je cherche » : un préréglage des couches ; les réglages fins
  /// (chips, calques) restent disponibles dessous.
  void _applyLooking(String v) {
    setState(() => _lookingFor = v);
    switch (v) {
      case 'sitters':
        _memberRoles
          ..clear()
          ..add('sitter');
        _showProviders.value = true;
        _showPois.value = false;
      case 'walkers':
        _memberRoles
          ..clear()
          ..add('walker');
        _showProviders.value = true;
        _showPois.value = false;
      case 'places':
        _showPois.value = true;
        _showProviders.value = false;
      case 'friends':
        _showProviders.value = false;
        _showPois.value = false;
        _showFriends.value = true;
        _showLiveLayer.value = true;
        unawaited(_openLiveFriendsSheet());
      default:
        _memberRoles.addAll({'sitter', 'walker', 'owner'});
        _showProviders.value = true;
        _showPois.value = true;
        _showFriends.value = true;
    }
    _memberRoles.refresh();
    _prefs.update({'lookingFor': v});
    if (mounted) setState(() {});
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
    final avail = p.availableTodayOnly;
    if (avail != null) _availableTodayOnly.value = avail;
    final looking = p.lookingFor;
    if (looking != null) _lookingFor = looking;
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
    ];
  }

  // ─── v584 — découverte guidée (idée 7 : 3 bulles, 3 lancements max) ─────

  static bool _coachShownThisSession = false;
  int _coachStep = -1;

  void _maybeStartCoach() {
    if (_coachShownThisSession) return;
    if (_prefs.coachShown >= 3) return;
    _coachShownThisSession = true;
    if (mounted) setState(() => _coachStep = 0);
  }

  void _coachNext() {
    if (!mounted) return;
    setState(() => _coachStep += 1);
    if (_coachStep >= PawMapCoach.steps) _coachDone();
  }

  void _coachDone() {
    if (!mounted) return;
    setState(() => _coachStep = -1);
    _prefs.update({'coachShown': _prefs.coachShown + 1});
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
          await _pawSpotController.loadNearby(_currentCenter);
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
  /// v565 — point 20 : bouton Retour de la grande carte (bas-gauche).
  Widget _buildExpandedBackButton() {
    // v565 (18/09) — verre blanc translucide, liseré fin, appui animé.
    return PawPressable(
      label: 'pawmap_reduce_map'.tr,
      onTap: () => _mapExpanded.value = false,
      child: PawGlassPill(
        color: PawMapTheme.inkOn(context).withValues(alpha: 0.18),
        height: 44.h,
        width: 44.h,
        padding: EdgeInsets.zero,
        child: Icon(Icons.arrow_back_rounded,
            size: 22.sp, color: PawMapTheme.inkOn(context)),
      ),
    );
  }

  /// v565 — le rail gauche compte désormais 9 boutons : sur un petit écran il
  /// pourrait dépasser le haut de la carte. On le borne à la hauteur
  /// disponible et il défile (aligné en BAS, jamais collé au menu).
  Widget _railScroller(Widget column, {bool expanded = false}) {
    final h = MediaQuery.of(context).size.height;
    final top = MediaQuery.of(context).viewPadding.top;
    // Petite carte : AppBar + rangée du haut (≈ 56 + 62) + baseline 168.
    // Grande carte : rangée Partager/Réduire (≈ 64) + baseline 82.
    final double maxH = expanded
        ? h - top - 72.h - _navInset(context) - 82.h - 12.h
        : h - top - 120.h - _railBottom(context, expanded: false, picking: false) - 12.h;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH.clamp(120.0, h)),
      child: SingleChildScrollView(
        reverse: true,
        physics: const ClampingScrollPhysics(),
        child: column,
      ),
    );
  }

  Widget _buildMapDock() {
    // v584 — mêmes 5 actions (SOS, partager, calques, nuit, historique), en
    // pilules de verre ; le bouton Retour occupe le coin bas-gauche.
    return Obx(() => PawMapDockRow(
          nightMode: _nightMode.value,
          leftPadding: 66.w,
          onSos: _openSosAnimal,
          onShare: _shareCurrentMap,
          onLayers: _openLayersSheet,
          onNight: _toggleNightMode,
          onHistory: _openHistory,
          onLongPress: _showDockHelp,
        ));
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
      await _pawSpotController.loadNearby(_currentCenter);
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
          await _pawSpotController.loadNearby(_currentCenter);
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
      await _pawSpotController.loadNearby(_currentCenter);
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
    await _pawSpotController.loadNearby(_currentCenter);
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
      await _pawSpotController.loadNearby(_currentCenter);
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
        await _pawSpotController.loadNearby(_currentCenter);
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
          unawaited(_pawSpotController.loadNearby(_currentCenter)),
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
      standalone = Navigator.of(context).canPop();
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



