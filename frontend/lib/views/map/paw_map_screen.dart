import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/friend_controller.dart';
import 'package:hopetsit/controllers/map_report_controller.dart';
import 'package:hopetsit/controllers/paw_map_controller.dart';
import 'package:hopetsit/controllers/pawspot_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/models/map_poi_model.dart';
import 'package:hopetsit/models/map_report_model.dart';
import 'package:hopetsit/models/nearby_request_model.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/services/friend_marker_service.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/services/location_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/map_ui_state.dart';
import 'package:hopetsit/widgets/app_switch.dart';
import 'package:hopetsit/widgets/golden_paw_coin.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/views/friends/friends_screen.dart';
import 'package:hopetsit/views/friends/people_live_screen.dart';
import 'package:hopetsit/views/map/alerts_screen.dart';
import 'package:hopetsit/views/map/pawspot_sheets.dart';
import 'package:hopetsit/views/map/widgets/create_report_sheet.dart';
import 'package:hopetsit/widgets/app_text.dart';
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
  const PawMapScreen({
    super.key,
    this.initialLat,
    this.initialLng,
    this.focusUserId,
    this.focusUserRole,
    this.focusUserName,
  });
  final double? initialLat;
  final double? initialLng;
  final String? focusUserId;
  final String? focusUserRole; // 'walker' | 'sitter' | 'owner'
  final String? focusUserName;

  @override
  State<PawMapScreen> createState() => _PawMapScreenState();
}

class _PawMapScreenState extends State<PawMapScreen>
    with WidgetsBindingObserver {
  final Completer<GoogleMapController> _mapCtl = Completer();
  // v469 — Daniel : « quand la map est AGRANDIE je veux voir ET SUIVRE amis et
  // famille ». Le calque plein écran possède sa PROPRE GoogleMap → il lui faut
  // son propre contrôleur, sinon _startFollow animait la carte normale CACHÉE
  // dessous (la caméra du calque restait figée). On garde ce ref tant que le
  // calque est monté ; il est invalidé à la réduction.
  GoogleMapController? _expandedCtl;
  late final PawMapController _poiController;
  late final MapReportController _reportController;
  late final FriendController _friendController;
  late final LiveMapService _liveMap;
  // v23.1 part 249 — service marker custom avec photo profil + ring.
  late final FriendMarkerService _friendMarkerService;
  // Paris fallback by default — guarantees the GoogleMap widget always has
  // a camera position on the very first frame, even before geolocation
  // resolves. This fixes the "need to tap twice to see the map" bug caused
  // by IndexedStack keeping the screen built-but-hidden.
  LatLng _currentCenter = const LatLng(48.8566, 2.3522);

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
  // v23.1.353 — refonte PawSpot : les POIs passent aussi en marqueurs EMOJI
  // (même générateur canvas que les reports) avec un fond teinté couleur
  // catégorie. Cache séparé par catégorie POI.
  final Map<String, BitmapDescriptor> _poiEmojiMarkers = {};
  // v23.1.353 — marqueurs emoji des spots communautaires PawSpot. Clé =
  // type de spot ('path_walk'...) ou '__golden__' (empreinte dorée 🐾).
  final Map<String, BitmapDescriptor> _spotEmojiMarkers = {};
  // v489 — Daniel (maquette « Map User Avatar ») : MINI-BADGE ROSE pour les
  // membres Paw Map proches (ni amis ni famille). Cercle rose + patte blanche
  // (membre anonyme, pas de photo) + point en/hors ligne + 👑 si premium.
  // Clé = 'pb_<online>_<premium>_<selected>'. Rendu bitmap canvas mis en cache.
  final Map<String, BitmapDescriptor> _pawBadgeMarkers = {};
  // Bump à chaque badge rose généré → invalide la clé de cache des markers
  // pour que le vrai badge remplace le fallback rose temporaire.
  int _pawBadgeRev = 0;
  // Membre rose actuellement sélectionné (tap) → état « sélectionné » (badge
  // surélevé/foncé). null = aucun.
  String? _selectedNearbyId;
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
  static const double _followZoom = 18.0;

  // v23.1.266 — Daniel : "un bouton discret pour une vue satellite". Type de
  // carte togglable normal ↔ hybride (satellite + rues/labels).
  MapType _mapType = MapType.normal;

  /// Nearby reservation requests for the sitter/walker layer. Fetched in
  /// `_reloadAtCenter()` via `/posts/requests/nearby`. Empty for owner role.
  final RxList<NearbyRequestPost> _requests = <NearbyRequestPost>[].obs;

  /// v23.1 part 72 — Bug 10 : nearby walkers/sitters with their boost flag.
  /// Owners see them as map markers — boosted ones get a bigger gold pin
  /// (PawSpot) so paying actually translates to map visibility.
  final RxList<Map<String, dynamic>> _nearbyProviders = <Map<String, dynamic>>[].obs;
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

  /// v23.1.363 — position choisie en TAPANT la carte pendant le mode viseur
  /// (marqueur réel ancré au sol — bien plus précis que le centre écran).
  LatLng? _pickedSpotPos;

  /// v23.1.353 — itinéraire "Y aller" (GET /pawspots/directions). La
  /// polyline orange est dessinée sur la carte ; le bandeau bas affiche la
  /// distance + un bouton pour l'effacer.
  Set<Polyline> _routePolylines = {};
  int? _routeDistanceMeters;
  bool _directionsLoading = false;

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
  final RxDouble _haloPhase = 0.0.obs;

  // v23.1.444 — Daniel : "les amis/abonnés en HALO ANIMÉ coloré". Palette
  // unique des halos vivants de la PawMap (cohérente avec la légende et le
  // FriendMarkerService) : vert PawFollow / or PawSpot / violet PawFamily.
  static const Color _greenPawFollow = Color(0xFF16A34A);
  static const Color _goldPawSpot = Color(0xFFE8A00A);
  static const Color _violetPawFamily = Color(0xFF8B5CF6);

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
    pawMapExpanded.value = false;
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
    // v23.1 part 249 — service de generation de markers custom avec
    // photo profil + cercle role color + ring violet famille (parite
    // design website). Permanent : on partage le cache entre toutes
    // les ouvertures PawMap pour eviter de regenerer les bitmaps a
    // chaque navigation.
    _friendMarkerService = Get.isRegistered<FriendMarkerService>()
        ? Get.find<FriendMarkerService>()
        : Get.put(FriendMarkerService(), permanent: true);
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
        // v23.1.270 — Daniel : "zoom fort + à la trace". On force _followZoom
        // à chaque position pour rester collé en gros plan sur la personne
        // (avant : newLatLng gardait le zoom courant → souvent trop large).
        _animateFollowCamera(
          LatLng(fp.latitude, fp.longitude),
          zoom: _followZoom,
        );
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
      if (!mounted) return;
      _haloPhase.value = (_haloPhase.value + 1.0 / 8.0) % 1.0;
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
    // v23.1.353 — refonte PawSpot : pré-warm aussi les marqueurs emoji des
    // POIs (fond teinté couleur catégorie au lieu du pin teardrop).
    for (final c in PoiCategories.all) {
      try {
        final color = _colorForPoi(c);
        _poiEmojiMarkers[c] = await _buildEmojiBitmap(
          PoiCategories.emoji(c),
          bgColor: color.withValues(alpha: 0.30),
          ringColor: color,
        );
      } catch (e) {
        debugPrint('[PawMap] poi emoji marker $c failed: $e');
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

  /// v23.1.353 — pendant du _ensureEmojiMarker pour les POIs : génère à la
  /// volée le marqueur emoji d'une catégorie pas encore en cache (catégorie
  /// inconnue renvoyée par le serveur, pré-warm en cours...).
  void _ensurePoiEmojiMarker(String category) {
    final key = 'poi_$category';
    if (_poiEmojiMarkers.containsKey(category) ||
        _emojiGenInProgress.contains(key)) {
      return;
    }
    _emojiGenInProgress.add(key);
    final color = _colorForPoi(category);
    _buildEmojiBitmap(
      PoiCategories.emoji(category),
      bgColor: color.withValues(alpha: 0.30),
      ringColor: color,
    ).then((bd) {
      _poiEmojiMarkers[category] = bd;
      _emojiGenInProgress.remove(key);
      if (mounted) setState(() {});
    }).catchError((Object _) {
      _emojiGenInProgress.remove(key);
    });
  }

  /// v23.1.353 — marqueurs emoji des spots PawSpot. Un spot GOLDEN (validé
  /// communauté / 50+ ❤️ / créateur Gold) affiche l'empreinte 🐾 sur fond
  /// doré avec un anneau plus épais ; sinon emoji du type sur fond teinté.
  void _ensureSpotEmojiMarker(String cacheKey) {
    final genKey = 'spot_$cacheKey';
    if (_spotEmojiMarkers.containsKey(cacheKey) ||
        _emojiGenInProgress.contains(genKey)) {
      return;
    }
    _emojiGenInProgress.add(genKey);
    final bool golden = cacheKey.startsWith('__golden__');
    // v23.1.361/373 — LA pièce-médaille officielle : dorée pour les spots
    // golden (avec un ANNEAU à la couleur du TYPE, comme la légende —
    // Daniel : "la pièce dorée juste avec le cercle de couleur"), sinon
    // déclinée dans la couleur du type.
    final future = golden
        ? _buildCoinBitmap(
            typeRing: PawSpotTypes.color(
                cacheKey.substring('__golden__'.length)),
          )
        : _buildCoinBitmap(base: PawSpotTypes.color(cacheKey));
    future.then((bd) {
      _spotEmojiMarkers[cacheKey] = bd;
      _emojiGenInProgress.remove(genKey);
      if (mounted) setState(() {});
    }).catchError((Object _) {
      _emojiGenInProgress.remove(genKey);
    });
  }

  // ── v489 — MINI-BADGE ROSE « membre Paw Map proche » (maquette Map User
  // Avatar) ───────────────────────────────────────────────────────────────
  /// Pré-génère (async, en cache) le badge rose pour un état donné. Fallback
  /// pin rose le temps que le bitmap se calcule, puis setState pour le poser.
  void _ensurePawBadgeMarker(bool online, bool premium, bool selected) {
    final key = 'pb_${online ? 1 : 0}_${premium ? 1 : 0}_${selected ? 1 : 0}';
    if (_pawBadgeMarkers.containsKey(key) ||
        _emojiGenInProgress.contains(key)) {
      return;
    }
    _emojiGenInProgress.add(key);
    _buildPawBadgeBitmap(online: online, premium: premium, selected: selected)
        .then((bd) {
      _pawBadgeMarkers[key] = bd;
      _emojiGenInProgress.remove(key);
      _pawBadgeRev++;
      if (mounted) setState(() {});
    }).catchError((Object _) {
      _emojiGenInProgress.remove(key);
    });
  }

  /// Cercle rose (dégradé) + patte blanche centrée + anneau blanc + point
  /// en/hors ligne (vert/gris) + petit badge doré 👑 si premium. Hors ligne =
  /// teinte désaturée. Sélectionné = cercle surélevé/foncé + liseré externe.
  Future<BitmapDescriptor> _buildPawBadgeBitmap({
    required bool online,
    required bool premium,
    required bool selected,
  }) async {
    const double size = 72.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(36, 38);
    final double r = selected ? 25 : 24;
    const pink = Color(0xFFF06AA0);
    const pinkDark = Color(0xFFE0568B);
    final Color fillTop = !online
        ? const Color(0xFFC9A6B6)
        : (selected ? pinkDark : pink);
    final Color fillBottom =
        online ? pinkDark : const Color(0xFFB89AAA);

    // Ombre douce.
    canvas.drawCircle(
      center.translate(0, 2.5),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Cercle rose dégradé.
    final rect = Rect.fromCircle(center: center, radius: r);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [fillTop, fillBottom],
        ).createShader(rect),
    );
    // Anneau blanc.
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );
    // Liseré externe (état sélectionné).
    if (selected) {
      canvas.drawCircle(
        center,
        r + 3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = pinkDark.withValues(alpha: 0.6),
      );
    }
    // Patte blanche centrée (membre anonyme — pas de photo).
    _drawWhitePaw(canvas, center, r * 1.5);
    // Point en/hors ligne (bas-droite).
    final dotC = Offset(center.dx + r * 0.72, center.dy + r * 0.72);
    canvas.drawCircle(dotC, 7.5, Paint()..color = Colors.white);
    canvas.drawCircle(
      dotC,
      5.5,
      Paint()
        ..color =
            online ? const Color(0xFF2ECC71) : const Color(0xFFC3C3C9),
    );
    // Badge doré 👑 (haut-droite) si membre premium.
    if (premium) {
      final crownC = Offset(center.dx + r * 0.74, center.dy - r * 0.74);
      canvas.drawCircle(crownC, 9.5, Paint()..color = Colors.white);
      canvas.drawCircle(
        crownC,
        8,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFBE3A1), Color(0xFFF4C04A)],
          ).createShader(Rect.fromCircle(center: crownC, radius: 8)),
      );
      final tp = TextPainter(
        text: const TextSpan(text: '👑', style: TextStyle(fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, crownC.translate(-tp.width / 2, -tp.height / 2));
    }

    final img =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), width: 42);
  }

  /// Patte blanche (4 coussinets + paume) dessinée dans une boîte [paw] px
  /// centrée sur [center]. Coordonnées calquées sur la patte SVG de la maquette
  /// (viewBox 0..24).
  void _drawWhitePaw(Canvas canvas, Offset center, double paw) {
    final white = Paint()..color = Colors.white;
    double sx(double vx) => center.dx + (vx - 12) / 24 * paw;
    double sy(double vy) => center.dy + (vy - 12.5) / 24 * paw;
    double sc(double v) => v / 24 * paw;
    void toe(double vx, double vy, double rx, double ry) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(sx(vx), sy(vy)),
          width: sc(rx) * 2,
          height: sc(ry) * 2,
        ),
        white,
      );
    }

    toe(6.4, 11, 2.0, 2.6);
    toe(10.3, 7.4, 2.0, 2.7);
    toe(14.7, 7.4, 2.0, 2.7);
    toe(18.6, 11, 2.0, 2.6);
    // Paume (coussinet central).
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(sx(12.5), sy(16.5)),
        width: sc(11),
        height: sc(8.5),
      ),
      white,
    );
  }

  /// Tap sur un membre rose (badge OU halo) : marque l'état sélectionné +
  /// ouvre l'info du membre (nom + rôle). Même comportement cliquable qu'avant.
  void _onNearbyTap({
    required String id,
    required String role,
    required String name,
    required bool online,
    required bool premium,
  }) {
    _selectedNearbyId = id;
    if (mounted) setState(() {});
    final emoji = role == 'walker' ? '🐕' : '🐾';
    final title = name.isNotEmpty
        ? name
        : (role == 'walker'
            ? 'pawmap_default_walker'.tr
            : 'pawmap_default_sitter'.tr);
    Get.snackbar(
      '$emoji $title',
      premium
          ? 'mapboost_marker_active'.tr
          : (role == 'walker'
              ? 'role_pet_walker'.tr
              : 'role_pet_sitter'.tr),
      snackPosition: SnackPosition.BOTTOM,
      margin: EdgeInsets.all(12.w),
      duration: const Duration(seconds: 3),
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
    Color ringColor = const Color(0xFFEF4324),
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

  /// v23.1.368 — Daniel : "colore mon emoji selon le thème du spot".
  /// LA pièce-médaille officielle (emoji fourni : anneau brillant, patte en
  /// relief, pointe-pin dans le coussinet, étincelles) déclinée dans la
  /// COULEUR DU TYPE — sans `base` : la version OR (spots golden).
  Future<BitmapDescriptor> _buildCoinBitmap({
    Color? base,
    Color? typeRing,
  }) async {
    // Palette : or officiel par défaut, sinon nuances dérivées du type.
    final Color ringStart = base == null
        ? const Color(0xFFFFE989)
        : Color.lerp(base, Colors.white, 0.55)!;
    final Color ringEnd = base == null
        ? const Color(0xFFD99800)
        : Color.lerp(base, Colors.black, 0.10)!;
    final Color inner = base == null
        ? const Color(0xFF9A6B00)
        : Color.lerp(base, Colors.black, 0.38)!;
    final Color pawStart = base == null
        ? const Color(0xFFFFE066)
        : Color.lerp(base, Colors.white, 0.45)!;
    final Color pawEnd = base ?? const Color(0xFFE8A00A);

    const double size = 64.0;
    const Offset c = Offset(32, 32);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Ombre douce.
    canvas.drawCircle(
      const Offset(32, 34),
      29,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    // v23.1.373 — anneau couleur du TYPE autour de la pièce OR (Daniel :
    // "comme dans la légende — vert chemin, turquoise baignade...").
    if (typeRing != null) {
      canvas.drawCircle(
        c,
        30.4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..color = typeRing,
      );
    }
    // Anneau extérieur brillant.
    canvas.drawCircle(
      c,
      29,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(10, 8),
          const Offset(54, 58),
          [ringStart, ringEnd],
        ),
    );
    // Fond intérieur + liseré clair.
    canvas.drawCircle(c, 24.5, Paint()..color = inner);
    canvas.drawCircle(
      c,
      24.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = ringStart.withValues(alpha: 0.7),
    );

    // Patte en relief (4 doigts + coussinet), dégradé.
    final pawPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(18, 14),
        const Offset(46, 52),
        [pawStart, pawEnd],
      );
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(20.5, 22), width: 9, height: 12),
        pawPaint);
    canvas.drawOval(
        Rect.fromCenter(
            center: const Offset(28.5, 17.5), width: 9.5, height: 13),
        pawPaint);
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(38, 18.5), width: 9.5, height: 13),
        pawPaint);
    canvas.drawOval(
        Rect.fromCenter(
            center: const Offset(45.5, 24.5), width: 9, height: 11.5),
        pawPaint);
    final pad = Path()
      ..moveTo(20, 38)
      ..cubicTo(20, 29, 26, 26, 32.5, 26)
      ..cubicTo(39, 26, 45, 29, 45, 38)
      ..cubicTo(45, 44, 40, 48.5, 32.5, 48.5)
      ..cubicTo(25, 48.5, 20, 44, 20, 38)
      ..close();
    canvas.drawPath(pad, pawPaint);

    // Pointe-PIN découpée dans le coussinet.
    final hole = Paint()..color = inner;
    canvas.drawCircle(const Offset(32.5, 36), 4.2, hole);
    final tip = Path()
      ..moveTo(27.8, 38.5)
      ..lineTo(37.2, 38.5)
      ..lineTo(32.5, 47)
      ..close();
    canvas.drawPath(tip, hole);
    canvas.drawCircle(
        const Offset(32.5, 36), 1.8, Paint()..color = pawStart);

    // Étincelles ✨.
    void sparkle(Offset p, double r) {
      final sp = Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(p.dx - r, p.dy), Offset(p.dx + r, p.dy), sp);
      canvas.drawLine(Offset(p.dx, p.dy - r), Offset(p.dx, p.dy + r), sp);
    }

    sparkle(const Offset(50, 13), 4);
    sparkle(const Offset(13, 49), 3);

    final img =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    // v23.1.369 — Daniel : "l'emoji plus grand, comme la taille des
    // utilisateurs, légèrement moins grand" — avatars amis = 96 px →
    // pièces type 64, pièce OR 70 (le doré ressort toujours un peu).
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: base == null ? 70 : 64,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reloadDebounce?.cancel();
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
      if (_haloTimer == null || !(_haloTimer!.isActive)) {
        _haloTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
          if (!mounted) return;
          _haloPhase.value = (_haloPhase.value + 1.0 / 8.0) % 1.0;
        });
      }
    } else {
      // paused / inactive / detached / hidden → coupe le timer.
      _haloTimer?.cancel();
      _haloTimer = null;
    }
  }

  /// v19.1.3 — Modernized search bar: pill-shaped glassmorphic surface with
  /// subtle green accent border, matching the Signaler FAB so the top and
  /// bottom controls feel like one system.
  /// v420 — retirée de la carte (recherche désormais dans l'AppBar) ; gardée
  /// pour réutilisation éventuelle.
  // ignore: unused_element
  Widget _buildCitySearchBar(BuildContext context) {
    // v21.1.1 — Search pill modernisée :
    //   * BorderRadius 32 (vraie pill)
    //   * 2 shadows pour profondeur (proche + ambiante)
    //   * Pas de border, le shadow porte la séparation
    //   * Icon loupe dans un cercle teinté primary (pas juste un Icon flat)
    //   * Hauteur 50.h pour confort tap sur mobile
    return Container(
      height: 50.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(width: 6.w),
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_rounded,
              size: 20.sp,
              color: AppColors.primaryColor,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: TextField(
              controller: _cityCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: _searchCity,
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                // v23.1.276 — Daniel : "vérifie les couleurs en dark mode sur la
                // PawMap". La GoogleMap reste TOUJOURS claire (pas de style
                // sombre), donc le pill de recherche est blanc : on FIXE le
                // texte en sombre (sinon textPrimary=blanc en dark → invisible).
                color: const Color(0xFF1F2937),
              ),
              decoration: InputDecoration(
                hintText: 'paw_map_search_city_hint'.tr,
                hintStyle: TextStyle(
                  color: const Color(0xFF9CA3AF),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                ),
                // v23.1.396 — Daniel : "en dark mode on voit rien". Le
                // THÈME sombre injectait filled+fillColor sombre et une
                // bordure focus → rectangle noir dans la pilule blanche.
                // On neutralise TOUT héritage du thème : la pilule reste
                // blanche, texte sombre, aucun fond ni bordure interne.
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 14.h),
              ),
            ),
          ),
          if (_cityCtrl.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _cityCtrl.clear();
                setState(() {});
              },
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.w),
                child: Container(
                  width: 22.w,
                  height: 22.w,
                  decoration: BoxDecoration(
                    color: AppColors.greyText.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14.sp,
                    color: AppColors.greyText,
                  ),
                ),
              ),
            )
          else
            SizedBox(width: 14.w),
        ],
      ),
    );
  }

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
      final target = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() => _currentCenter = target);
      if (_mapCtl.isCompleted) {
        final ctl = await _mapCtl.future;
        await ctl.animateCamera(CameraUpdate.newLatLngZoom(target, 13));
      }
      await _reloadAtCenter();
    } catch (e) {
      debugPrint('[PawMap] city search failed: $e');
      CustomSnackbar.showError(
        title: 'pawmap_snack_search_failed'.tr,
        message: 'pawmap_snack_search_failed_msg'.tr,
      );
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

    try {
      final loc = await LocationService()
          .getCurrentLocation()
          .timeout(const Duration(seconds: 8), onTimeout: () => null);
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
          await ctl.animateCamera(CameraUpdate.newLatLngZoom(myCenter, 13));
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

      // v23.1.352 — Daniel : "je dois mettre Rien puis Tous pour que les
      // points apparaissent au lieu que ça apparaisse direct". Watchdog du
      // 1er chargement : si 4s après le bootstrap les couches sont toujours
      // vides (fetch initial raté : permission GPS tout juste accordée,
      // réseau lent, course au boot), on relance UNE fois le chargement —
      // plus besoin de toggler le filtre pour forcer l'affichage.
      Future.delayed(const Duration(seconds: 4), () {
        if (!mounted) return;
        final nothingLoaded = _poiController.pois.isEmpty &&
            _reportController.reports.isEmpty &&
            _nearbyProviders.isEmpty;
        if (nothingLoaded) {
          debugPrint('[PawMap] first-load watchdog → retry reload');
          unawaited(_reloadAtCenter());
        }
      });
    } catch (e) {
      debugPrint('[PawMap] bootstrap error: $e');
    }
  }

  /// v23.1.189 — Daniel : "faire bouton cherche une ville". Ouvre un
  /// dialog texte qui geocode la ville saisie et centre la map dessus +
  /// reload les POI / reports.
  Future<void> _onSearchCity() async {
    final ctrl = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.r),
          ),
          title: Row(
            children: [
              Icon(Icons.search_rounded,
                  color: AppColors.primaryColor, size: 22.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: InterText(
                  text: 'pawmap_search_city'.tr,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'pawmap_search_city_hint'.tr,
              prefixIcon: const Icon(Icons.location_city_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('common_cancel'.tr),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
              child: Text('pawmap_search_city_btn'.tr),
            ),
          ],
        );
      },
    );
    if (query == null || query.isEmpty) return;
    // Delegue au handler existant qui utilise LocationService + reload.
    await _searchCity(query);
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
      // v23.1 part 72 — owners see nearby walkers/sitters as map pins
      // with PawSpot-boosted ones highlighted.
      futures.add(_loadNearbyProviders());
    }
    await Future.wait(futures);
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
      final results = await Future.wait([
        api.get('/walkers/nearby', queryParameters: params, requiresAuth: true)
            .catchError((_) => <String, dynamic>{}),
        api.get('/sitters/nearby', queryParameters: params, requiresAuth: true)
            .catchError((_) => <String, dynamic>{}),
      ]);
      final walkers = ((results[0] as Map?)?['walkers'] as List?) ?? const [];
      final sitters = ((results[1] as Map?)?['sitters'] as List?) ?? const [];
      final merged = <Map<String, dynamic>>[];
      for (final w in walkers) {
        if (w is Map) {
          merged.add({
            ...Map<String, dynamic>.from(w),
            '_role': 'walker',
          });
        }
      }
      for (final s in sitters) {
        if (s is Map) {
          merged.add({
            ...Map<String, dynamic>.from(s),
            '_role': 'sitter',
          });
        }
      }
      _nearbyProviders.assignAll(merged);
    } catch (_) {
      /* keep last list */
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
    // v456 — viseur « point rouge au centre » : l'emplacement choisi SUIT le
    // centre de la carte que l'utilisateur déplace sous le repère rouge fixe
    // (placement précis, façon Uber). Plus de pin à faire glisser.
    if (_pickingSpotPos.value || _pickingReportPos.value) {
      _pickedSpotPos = pos.target;
    }
  }

  /// Debounced wrapper for `_reloadAtCenter()`. Cancels any pending reload
  /// and schedules a fresh one 500 ms later. Wired to `onCameraIdle` so the
  /// POI / report / request layers refresh after the user stops panning.
  void _scheduleReload() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
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
    _liveMap.startBroadcasting(() => _userPosition ?? _currentCenter);
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

  // v23.1 part 123 — Platinum halo pulse. Returns a Set<Circle> with one
  // animated circle per Platinum-boosted provider visible on the map.
  // The phase is read from _haloPhase (0..1) — Obx parent re-runs us at
  // 5fps which is enough for a peaceful beacon feel without thrashing GL.
  Set<Circle> _buildHaloCircles() {
    final Set<Circle> circles = {};

    // v23.1.149 — Daniel : "paw map rien napparait le point de
    // geolocolisation ou le halo nest pas la". On dessine notre propre
    // halo bleu pulsant autour de la position user dès qu'elle est
    // résolue (indépendant de myLocationEnabled qui peut échouer
    // silencieusement selon la permission OS).
    final userPos = _userPosition;
    // v23.1.356 — switch PawFollow OFF → couche live masquée (mon halo aussi).
    if (userPos != null && _showLiveLayer.value) {
      final phase = _haloPhase.value;
      final userRadius = 25.0 + 75.0 * phase; // 25 → 100 m
      final userOpacity = (0.55 * (1.0 - phase)).clamp(0.0, 1.0);
      // v23.1.352 — Daniel : "tu as mis un petit point bleu au lieu de me
      // laisser mon halo selon rôle". Le halo perso prend la couleur du RÔLE
      // (owner orange / sitter bleu / walker vert) au lieu du bleu générique.
      final userColor = AppColors.roleAccent(_role);
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
      // Solid inner dot (radius 8m) — couleur rôle, visible même quand le
      // pulse est à son apex (opacity faible).
      circles.add(
        Circle(
          circleId: const CircleId('user_halo_dot'),
          center: userPos,
          radius: 8,
          fillColor: userColor,
          strokeColor: Colors.white,
          strokeWidth: 2,
        ),
      );
    }

    // v23.1.353 — refonte PawSpot : les halos "map boost" (self-halo +
    // halos tier bronze/silver/gold/platinum des providers) sont SUPPRIMÉS.
    // PawSpot = désormais les spots communautaires 🐾 (couche dédiée).
    // On garde : halo user, anneau ROLE des providers, halos amis/famille.

    // v449 — Daniel : « je vois encore des halos ». Le halo statique sous
    // chaque POI (cercle teinté de la catégorie) est RETIRÉ : le marqueur
    // emoji du POI porte déjà son anneau de couleur, le halo au sol faisait
    // doublon et donnait l'impression d'un « halo » résiduel. (Les halos
    // amis/famille/utilisateur restent, eux, volontaires.)

    // v23.1.276 — Daniel : "unifie les halos des utilisateurs pour que tout
    // soit plus fluide et compréhensible". Avant, un `return` ici (owner-only)
    // empêchait les halos AMIS (plus bas) de s'afficher pour un sitter/walker.
    // On enferme donc la boucle PROVIDER dans un `if` au lieu de couper, pour
    // toujours atteindre le bloc amis. + DEDUP : un provider qui est AUSSI un
    // ami live ne reçoit PAS de halo provider (son halo ami unifié le
    // représente déjà) → fini les 2-3 halos empilés sur la même personne.
    final friendLiveIds = _liveMap.friendPositions.keys
        .map((k) => k.trim().toLowerCase())
        .toSet();
    // v489 — halo ROSE des membres proches : visible UNIQUEMENT si abonné
    // PawSpot/PawPremium (mêmes règles que le badge rose dans _buildMarkers).
    if (!_isSitterOrWalker &&
        _showProviders.value &&
        (_pawSpotController.pawspotActive.value ||
            _pawSpotController.premiumActive.value)) {
      for (final p in _nearbyProviders) {
      final loc = p['location'] is Map ? p['location'] as Map : null;
      final coords = loc != null && loc['coordinates'] is List
          ? loc['coordinates'] as List
          : null;
      if (coords == null || coords.length < 2) continue;
      final lng = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();
      final id = (p['id'] ?? p['_id'] ?? '').toString();
      if (id.isEmpty) continue;
      // v23.1.276 — dédup halos : ce provider est aussi un ami live → on saute
      // son halo provider (anneau role + tier), son halo AMI unifié suffit.
      if (friendLiveIds.contains(id.trim().toLowerCase())) continue;
      // v23.1.161 — Daniel : "la couleur des halo marche pas". v159 mettait
      // l'anneau role-color DANS le if(isMapBoosted), donc seuls les
      // providers avec PawSpot actif l'avaient. Maintenant on dessine
      // l'anneau role-color pour TOUS les providers visibles → Daniel
      // voit toujours vert (walker) / bleu (sitter) autour de chaque pin
      // sur la map, meme quand personne a PawSpot autour de lui.
      final role = (p['_role'] ?? '').toString().toLowerCase();
      // v23.1.444 — Daniel : "les amis/abonnés en HALO ANIMÉ au lieu de
      // pins". Le PawSpot (provider map-boosté) prend un halo OR pulsant ;
      // sinon couleur du rôle (walker vert / sitter bleu / owner orange).
      // L'anneau RESPIRE désormais avec _haloPhase (effet beacon) au lieu
      // d'être un cercle statique.
      // v489 — Daniel (maquette « Map User Avatar ») : halo ROSE (membre Paw
      // Map proche, inconnu) au lieu de la couleur de rôle. Le badge rose
      // (patte blanche) est posé PAR-DESSUS dans _buildMarkers ; ce Circle =
      // la pulsation rose animée. Tap → info du membre (idem badge).
      final bool providerPremium =
          p['isMapBoosted'] == true || p['isPremium'] == true;
      final bool providerOnline =
          p['isOnline'] != false && p['online'] != false;
      const Color roseHalo = Color(0xFFF06AA0);
      final providerHp = _haloPhase.value; // 0..1
      final providerName = (p['name'] ?? '').toString();
      circles.add(
        Circle(
          circleId: CircleId('halo_role_$id'),
          center: LatLng(lat, lng),
          radius: 25 + 35 * providerHp, // respiration 25 → 60m
          fillColor: roseHalo.withValues(
            alpha: (0.22 * (1 - providerHp)).clamp(0.0, 1.0),
          ),
          strokeColor: roseHalo.withValues(
            alpha: (0.9 * (1 - providerHp) + 0.1).clamp(0.0, 1.0),
          ),
          strokeWidth: 3,
          consumeTapEvents: true,
          onTap: () => _onNearbyTap(
            id: id,
            role: role,
            name: providerName,
            online: providerOnline,
            premium: providerPremium,
          ),
        ),
      );
      }
    }

    // v23.1.174 — Daniel : "halo argent sur les amis, halo rose sur les
    // membres famille PawFollow". On lit la liste des family members du
    // FriendController + les friend positions broadcastées via mapSocket.
    //
    // v23.1 part 225 — Daniel : "pour le suivi walker en vert et sitter
    // en bleu, quand je suive animal sa me mette sur la map et halo vert
    // ou bleu selon service". On override desormais la priorite couleur :
    //   1. Walker actif (model=Walker) → VERT (greenColor) — il promene
    //      mon animal, je le suis pour voir ou il est avec mon chien.
    //   2. Sitter actif (model=Sitter) → BLEU (sitterAccent) — il garde
    //      mon animal, meme logique.
    //   3. Sinon, fallback historique : family ROSE / friend ARGENT.
    try {
      final friendCtl = Get.isRegistered<FriendController>()
          ? Get.find<FriendController>()
          : null;
      // v23.1 part 248 — Daniel : "dans lapp sa marche tjr pas" (halo
      // violet famille). Robustesse :
      //   - on lit a la fois `id` ET `userId` cote chaque membre (l'API
      //     renvoie `id`, mais on supporte aussi `userId` au cas ou
      //     l'historique du backend changeait).
      //   - on trim + lowercase pour matcher meme si la casse differe.
      //   - on ignore le filtre par status (active/pending) : meme un
      //     pending family member doit avoir son ring violet quand il
      //     broadcast — Daniel le voit deja sur la PawMap, c'est just le
      //     ring qui doit s'allumer.
      final familyMemberIds = friendCtl?.familyMembers
              .map((m) =>
                  ((m['id'] ?? m['userId'] ?? '').toString()).trim().toLowerCase())
              .where((id) => id.isNotEmpty)
              .toSet() ??
          <String>{};
      // v23.1.398 — membres Paw Premium → grand halo OR (au lieu du violet
      // famille). Champ isPremium poussé par GET /friends/family/members.
      // v448 — Daniel : si la couche Premium est coupée manuellement
      // (_showPremiumLayer OFF), on n'applique plus l'or → membres en violet.
      // v469 — Daniel : couronne 👑 Paw Premium visible par TOUS (pas que la
      // famille). On réunit les membres famille premium ET les AMIS premium
      // (flag isPremium désormais renvoyé par le backend pour chaque contact).
      final premiumMemberIds = !_showPremiumLayer.value
          ? <String>{}
          : (<String>{
              ...((friendCtl?.familyMembers ?? const [])
                  .where((m) => m['isPremium'] == true)
                  .map((m) => ((m['id'] ?? m['userId'] ?? '')
                      .toString())
                      .trim()
                      .toLowerCase())),
              ...((friendCtl?.friends ?? const [])
                  .where((f) => f.other?.isPremium == true)
                  .map((f) => (f.other?.id ?? '').trim().toLowerCase())),
            }..removeWhere((id) => id.isEmpty));
      // v23.1 part 225 — Index userId → role (lowercase) tire de la
      // liste d'amis acceptes pour pouvoir override la couleur halo
      // selon le metier de l'ami qui broadcast.
      final Map<String, String> friendIdToRole = {};
      try {
        for (final f in friendCtl?.friends ?? []) {
          final id = f.other?.id ?? '';
          final model = f.other?.model ?? '';
          if (id.isNotEmpty && model.isNotEmpty) {
            friendIdToRole[id] = model.toLowerCase();
          }
        }
      } catch (_) {/* defensive */}

      // v23.1 part 243 — halo color priority.
      // v23.1.275 — Daniel : "si l'ami sitter/walker/owner passe a famille
      // alors met un SEUL halo violet, pas la peine d'emettre 3 halos
      // differents". On abandonne l'ancienne strategie (role + 2e anneau
      // violet empile) au profit d'une PRIORITE FAMILLE : famille -> un
      // unique halo violet ; sinon couleur du role (walker vert / sitter
      // bleu / owner orange / ami argent). Un seul cercle par personne.
      // v23.1.444 — palette unique des halos vivants (cf constantes de
      // classe) : vert PawFollow / or PawSpot / violet PawFamily.
      const familyViolet = _violetPawFamily;

      for (final pos in _liveMap.friendPositions.values) {
        // v23.1.356 — switch PawFollow OFF → halos amis/famille masqués.
        if (!_showLiveLayer.value) break;
        // v23.1 part 240 — fallback sur FriendPosition.role quand le peer
        // n'est pas dans la liste d'amis (ex: ouverture depuis un chat
        // sitter/walker non-ami). Sinon halo neutre alors qu'on a le metier.
        final role = (friendIdToRole[pos.userId] ?? pos.role).toLowerCase();
        // v23.1 part 248 — normalisation symetrique pour le matching
        // famille : trim + lowercase cote pos.userId comme on l'a fait
        // sur familyMemberIds plus haut. Evite les ratés a cause d'un
        // hex case mismatch sur certaines plateformes.
        final normUserId = pos.userId.trim().toLowerCase();
        final isFamily = familyMemberIds.contains(normUserId);
        // v23.1.275 — Daniel : "si l'ami sitter/walker/owner passe a famille
        // alors met un SEUL halo violet, pas la peine d'emettre 3 halos
        // differents". PRIORITE FAMILLE : si la personne est dans ma famille
        // PawFollow, son halo est UNIQUEMENT violet (code couleur famille) —
        // on n'empile plus halo-de-role + anneau violet (ca faisait 2 cercles).
        // Sinon, couleur du role : walker VERT / sitter BLEU / owner ORANGE /
        // ami ARGENT. Dans tous les cas le centre lit la position LIVE, donc
        // le halo SUIT la personne a la trace pendant la promenade / la garde.
        // v23.1.398 — Paw Premium PRIORITAIRE : halo OR (au lieu du violet
        // famille / couleur rôle) pour signaler le bundle premium.
        final isPremiumMember = premiumMemberIds.contains(normUserId);
        Color color;
        String tag;
        if (isPremiumMember) {
          color = _goldPawSpot; // or PawSpot / Paw Premium
          tag = 'premium';
        } else if (isFamily) {
          color = familyViolet; // violet PawFamily
          tag = 'family';
        } else if (role == 'walker') {
          color = AppColors.greenColor;
          tag = 'walker';
        } else if (role == 'sitter') {
          color = AppColors.sitterAccent;
          tag = 'sitter';
        } else if (role == 'owner') {
          color = AppColors.primaryColor;
          tag = 'owner';
        } else {
          // v23.1.444 — Daniel : "halo VERT pour les amis PawFollow qui
          // partagent leur position" (au lieu de l'ancien argent neutre).
          color = _greenPawFollow;
          tag = 'friend';
        }
        // Halo UNIQUE — violet si famille, sinon couleur du role. Centre =
        // position LIVE -> il se deplace avec la personne (suivi a la trace).
        // v23.1.300 — Daniel : "halo orange (owner) animé sur iOS mais figé
        // sur Android". Avant : Circle STATIQUE (radius 60) → rien ne bougeait.
        // Maintenant il RESPIRE avec _haloPhase (comme le halo bleu user) → il
        // pulse identiquement sur Android ET iOS (effet beacon).
        final roleHp = _haloPhase.value; // 0..1
        circles.add(
          Circle(
            circleId: CircleId('${tag}_halo_${pos.userId}'),
            center: LatLng(pos.latitude, pos.longitude),
            radius: 45 + 35 * roleHp, // respiration 45 → 80m
            fillColor: color.withValues(
              alpha: (0.20 * (1 - roleHp)).clamp(0.0, 1.0),
            ),
            strokeColor: color.withValues(
              alpha: (0.85 * (1 - roleHp) + 0.15).clamp(0.0, 1.0),
            ),
            strokeWidth: 2,
          ),
        );
        // v23.1.274 — Daniel : "le pin halo de paw follow doit suivre
        // la personne qd y bouge". Quand on SUIT activement cette personne
        // (_followUserId == son id), on rajoute un anneau "tracking" qui
        // RESPIRE avec _haloPhase (30→70m) pour montrer sans ambiguite que
        // le suivi est live et centre sur elle. Le centre lit la position
        // LIVE (pos.latitude/longitude) exactement comme le halo principal,
        // donc l'anneau se deplace a la trace : a chaque map:friend-position
        // recue, l'Obx rebuild (signature coords v263) et ce cercle est
        // recalcule au nouveau point. Compare en normalise (trim+lower) pour
        // matcher meme si la casse de l'hex differe d'une plateforme.
        final follow = _followUserId;
        if (follow != null && normUserId == follow.trim().toLowerCase()) {
          final phase = _haloPhase.value; // 0..1
          circles.add(
            Circle(
              circleId: CircleId('follow_track_${pos.userId}'),
              center: LatLng(pos.latitude, pos.longitude),
              radius: 30 + (phase * 40), // respiration 30→70m
              fillColor: color.withValues(alpha: 0.10 * (1 - phase)),
              strokeColor: color.withValues(alpha: 0.95),
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
  // v23.1 part 243 round 3 — wrapper qui reutilise le cache si la cle
  // d'invalidation n'a pas change. Sur low-end (Oppo/Samsung A-series)
  // ca evite des centaines de _buildMarkers/sec quand le halo tick.
  Set<Marker> _getMarkersFromCache() {
    final key = [
      _nearbyProviders.length,
      _poiController.visiblePois.length,
      _reportController.reports.length,
      _showProviders.value ? 1 : 0,
      _showPois.value ? 1 : 0,
      _showReports.value ? 1 : 0,
      _emojiMarkersReady ? 1 : 0,
      // v23.1.300 — invalide le cache quand un nouvel emoji est généré à la
      // volée (sinon le marqueur reste figé sur le pin coloré par défaut).
      _reportEmojiMarkers.length,
      // v23.1.353 — refonte PawSpot : invalidation pour les caches emoji
      // POI/spots et pour la couche des spots communautaires 🐾.
      _poiEmojiMarkers.length,
      _spotEmojiMarkers.length,
      _showPawSpots.value ? 1 : 0,
      // v23.1.356 — switch PawFollow (couche live ON/OFF).
      _showLiveLayer.value ? 1 : 0,
      // v448 — switch PawPremium (halos OR membres Premium ON/OFF).
      _showPremiumLayer.value ? 1 : 0,
      // v23.1.373 — Daniel : "baignade pack traduction" — après un
      // changement de langue en cours de session, les InfoWindows gardaient
      // l'ancien libellé (cache marqueurs aveugle à la locale). La locale
      // entre dans la clé de cache → re-render des snippets traduits.
      Get.locale?.languageCode ?? '',
      // v23.1.363 — mode viseur (pin de placement tap/drag).
      _pickingSpotPos.value ? 1 : 0,
      // v449 — viseur signalement (même pin, couleur rouge).
      _pickingReportPos.value ? 1 : 0,
      _pickedSpotPos == null
          ? ''
          : '${_pickedSpotPos!.latitude.toStringAsFixed(5)},${_pickedSpotPos!.longitude.toStringAsFixed(5)}',
      _pawSpotController.spots.length,
      _liveMap.friendPositions.length,
      // v23.1.263 — Daniel : "le follow géolocalise mais ne suit pas à la
      // trace". La clé n'incluait que le NOMBRE d'amis → un ami qui se
      // déplace (même nombre) ne réinvalidait pas le cache → marker FIGÉ.
      // On ajoute une signature des coordonnées (5 décimales ≈ 1 m) : le
      // marker bouge désormais en temps réel à chaque position socket.
      _liveMap.friendPositions.values
          .map((p) =>
              '${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}')
          .join('|'),
      _requests.length,
      _showRequests.value ? 1 : 0,
      _showFriends.value ? 1 : 0,
      // v23.1 part 249 — Invalide aussi le cache markers quand le
      // FriendMarkerService genere un nouveau BitmapDescriptor (photo
      // profil arrivee du CDN). Sans ca, le placeholder colore reste
      // affiche jusqu'a la prochaine vraie data change.
      _friendMarkerService.rev.value,
      // v249 — invalidation aussi quand familyMembers change : un
      // walker qui devient famille doit avoir son ring violet
      // instantanement.
      _friendController.familyMembers.length,
      // v489 — badges roses « membres proches » : invalide le cache quand
      // l'abonnement, la liste/état des membres, la sélection ou un nouveau
      // bitmap badge changent.
      _showProviders.value ? 1 : 0,
      _pawSpotController.pawspotActive.value ? 1 : 0,
      _pawSpotController.premiumActive.value ? 1 : 0,
      _selectedNearbyId ?? '',
      _pawBadgeRev,
      _nearbyProviders
          .map((p) =>
              '${p['id'] ?? p['_id']}:${p['isMapBoosted'] == true || p['isPremium'] == true ? 1 : 0}:${p['isOnline'] != false && p['online'] != false ? 1 : 0}')
          .join('|'),
    ].join('-');
    if (_cachedMarkers == null || _cachedMarkersKey != key) {
      _cachedMarkers = _buildMarkers();
      _cachedMarkersKey = key;
    }
    return _cachedMarkers!;
  }

  Set<Marker> _buildMarkers() {
    final Set<Marker> markers = {};
    // v23.1.352 — Daniel : "au dézoom je ne me vois plus / petit point au
    // lieu de mon halo". Mon PROPRE marqueur photo (même style que les amis :
    // cercle couleur rôle + avatar), taille écran fixe → je me vois à
    // n'importe quel zoom, en plus du halo rôle (cercles en mètres).
    final myPos = _userPosition;
    // v23.1.356 — switch PawFollow OFF → mon marqueur photo masqué aussi.
    if (myPos != null && _showLiveLayer.value) {
      try {
        final profile = GetStorage()
            .read<Map<String, dynamic>>(StorageKeys.userProfile);
        final myId = (profile?['id'] ?? 'me').toString();
        final rawAvatar = profile?['avatar'];
        final myAvatar = rawAvatar is Map
            ? (rawAvatar['url'] ?? '').toString()
            : (rawAvatar ?? '').toString();
        final icon = _friendMarkerService.getOrPlaceholder(
          userId: 'me_$myId',
          avatarUrl: myAvatar,
          role: _role,
          isFamily: false,
          // v23.1.395 — couronne 👑 + anneau or sur MON marqueur si Premium.
          isPremium: _pawSpotController.premiumActive.value,
        );
        markers.add(
          Marker(
            markerId: const MarkerId('me'),
            position: myPos,
            icon: icon,
            anchor: const Offset(0.5, 0.5),
            zIndexInt: 10,
            infoWindow: InfoWindow(title: '📍 ${'pawmap_me_label'.tr}'),
          ),
        );
      } catch (_) {/* defensive — le halo rôle reste visible */}
    }
    // v489 — Daniel (maquette « Map User Avatar ») : les prestataires proches
    // (ni amis ni famille) = MINI-BADGE ROSE (cercle rose + patte blanche +
    // point en/hors ligne + 👑 si premium), CLIQUABLE (tap → info du membre).
    // Visible UNIQUEMENT si l'utilisateur courant est abonné PawSpot ou
    // PawPremium (sinon RIEN). Le halo rose ANIMÉ est le Circle de
    // _buildHaloCircles ; ici on pose le badge bitmap par-dessus.
    final bool nearbyVisible = !_isSitterOrWalker &&
        _showProviders.value &&
        (_pawSpotController.pawspotActive.value ||
            _pawSpotController.premiumActive.value);
    if (nearbyVisible) {
      final friendLiveIds = _liveMap.friendPositions.keys
          .map((k) => k.trim().toLowerCase())
          .toSet();
      for (final p in _nearbyProviders) {
        final loc = p['location'] is Map ? p['location'] as Map : null;
        final coords = loc != null && loc['coordinates'] is List
            ? loc['coordinates'] as List
            : null;
        if (coords == null || coords.length < 2) continue;
        final lng = (coords[0] as num).toDouble();
        final lat = (coords[1] as num).toDouble();
        final id = (p['id'] ?? p['_id'] ?? '').toString();
        if (id.isEmpty) continue;
        // Dédup : un membre qui est aussi un ami live garde son marqueur ami
        // (photo) — pas de badge rose en double.
        if (friendLiveIds.contains(id.trim().toLowerCase())) continue;
        final role = (p['_role'] ?? '').toString().toLowerCase();
        final name = (p['name'] ?? '').toString();
        final bool premium =
            p['isMapBoosted'] == true || p['isPremium'] == true;
        final bool online = p['isOnline'] != false && p['online'] != false;
        final bool selected = _selectedNearbyId == id;
        final icon = _pawBadgeMarkers[
            'pb_${online ? 1 : 0}_${premium ? 1 : 0}_${selected ? 1 : 0}'];
        if (icon == null) _ensurePawBadgeMarker(online, premium, selected);
        markers.add(
          Marker(
            markerId: MarkerId('nearby_$id'),
            position: LatLng(lat, lng),
            icon: icon ??
                BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRose),
            anchor: const Offset(0.5, 0.5),
            zIndexInt: selected ? 9 : 6,
            onTap: () => _onNearbyTap(
              id: id,
              role: role,
              name: name,
              online: online,
              premium: premium,
            ),
          ),
        );
      }
    }
    if (_showPois.value) {
      for (final poi in _poiController.visiblePois) {
        // v23.1.353 — refonte PawSpot : marqueur EMOJI (même générateur que
        // les reports) avec fond teinté couleur catégorie, au lieu du pin
        // teardrop. Fallback pin coloré le temps que le bitmap se génère.
        final poiIcon = _poiEmojiMarkers[poi.category];
        if (poiIcon == null) _ensurePoiEmojiMarker(poi.category);
        markers.add(
          Marker(
            markerId: MarkerId('poi_${poi.id}'),
            position: LatLng(poi.latitude, poi.longitude),
            icon: poiIcon ??
                BitmapDescriptor.defaultMarkerWithHue(
                  _hueForPoi(poi.category),
                ),
            infoWindow: InfoWindow(
              title: '${PoiCategories.emoji(poi.category)} ${poi.title}',
              snippet: poi.address.isNotEmpty
                  ? poi.address
                  : PoiCategories.label(poi.category),
            ),
            onTap: () => _showPoiBottomSheet(poi),
          ),
        );
      }
    }
    // v456 — Daniel : plus de marqueur draggable au sol pour le placement.
    // Le repère est un POINT ROUGE FIXE au centre de l'écran (overlay
    // `_buildCenterReticle`) ; l'utilisateur déplace la carte SOUS ce repère,
    // et la position choisie suit le centre (`_onCameraMove`).
    // v23.1.353 — refonte PawSpot : couche des spots communautaires 🐾.
    // Marqueur emoji du type (fond couleur type) ; spot GOLDEN → empreinte
    // 🐾 sur fond doré avec anneau plus épais. Tap → sheet détail.
    if (_showPawSpots.value) {
      for (final spot in _pawSpotController.spots) {
        // v23.1.373 — pièce OR avec ANNEAU couleur du type → cache par type.
        final cacheKey =
            spot.isGolden ? '__golden__${spot.type}' : spot.type;
        final spotIcon = _spotEmojiMarkers[cacheKey];
        if (spotIcon == null) _ensureSpotEmojiMarker(cacheKey);
        markers.add(
          Marker(
            markerId: MarkerId('pawspot_${spot.id}'),
            position: LatLng(spot.lat, spot.lng),
            icon: spotIcon ??
                BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueYellow,
                ),
            infoWindow: InfoWindow(
              title:
                  '${spot.isGolden ? '🐾' : PawSpotTypes.emoji(spot.type)} ${spot.name}',
              snippet: PawSpotTypes.label(spot.type),
            ),
            onTap: () => _showPawSpotDetail(spot),
          ),
        );
      }
    }
    if (_showReports.value) {
      for (final r in _reportController.reports) {
        if (r.isExpired) continue;
        // v23.1.190 — Daniel : "pour les signalement au lieu de halo
        // rouge emoji du signalement". On pioche dans le cache emoji
        // pre-calcule, fallback sur le pin teardrop coloré si pas
        // encore pret (pendant le pre-warm initial).
        final emojiIcon = _reportEmojiMarkers[r.type];
        // v23.1.300 — si l'emoji de ce type n'est pas (encore) en cache, on le
        // génère à la volée → le marqueur passera du pin coloré à l'emoji dès
        // que le bitmap est prêt (setState + clé cache inclut la taille du map).
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
    if (_showFriends.value) {
      // Build a quick lookup of friend profile by id to get their name.
      final friendById = {
        for (final f in _friendController.friends)
          if (f.other != null) f.other!.id: f,
      };
      // v23.1 part 249 — Daniel : "la photo de profile avec le cercle vert
      // si walker bleu si sitter orange si owner et violet si famille".
      // On construit un Set des userIds membres famille (incluant pending)
      // pour decider si le ring violet doit apparaitre.
      final familyMemberIds = _friendController.familyMembers
          .map((m) => ((m['id'] ?? m['userId'] ?? '').toString()).trim().toLowerCase())
          .where((id) => id.isNotEmpty)
          .toSet();
      // v23.1.398 — Daniel : « mon frère a Paw Premium mais reste violet
      // famille, pas de couronne ». Set des membres Premium (champ isPremium
      // poussé par GET /friends/family/members) → couronne 👑 + anneau OR
      // sur LEUR marqueur, prioritaire sur le violet famille.
      // v448 — couche Premium coupée manuellement (_showPremiumLayer OFF) →
      // set vide → pas d'or/couronne (membres en violet famille).
      // v469 — couronne 👑 visible par TOUS : famille premium + AMIS premium.
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
      // v23.1.297 — Daniel : "compter famille ET amis". Le backend pousse
      // désormais aussi la position des membres famille (mapSocket). Lookup
      // id->map pour dessiner leur pin même s'ils ne sont PAS aussi des amis
      // (sinon ils comptent dans "Mon cercle" mais n'ont aucun marqueur).
      final familyById = {
        for (final m in _friendController.familyMembers)
          ((m['id'] ?? m['userId'] ?? '').toString()).trim().toLowerCase(): m,
      };
      for (final pos in _liveMap.friendPositions.values) {
        // v23.1.356 — switch PawFollow OFF → markers amis/famille masqués.
        if (!_showLiveLayer.value) break;
        final friend = friendById[pos.userId];
        // v23.1.297 — fallback membre famille (pas forcément un ami) : on le
        // dessine quand même pour qu'il apparaisse sur la carte ET dans le
        // compteur "Mon cercle".
        final famMember = friend == null
            ? familyById[pos.userId.trim().toLowerCase()]
            : null;
        // v23.1.352 — Daniel : "quand je dézoome je vois pas mes amis". On ne
        // SAUTE plus les positions non encore matchées dans les listes amis/
        // famille (chargées en async) : toute FriendPosition reçue (elle a
        // déjà passé les règles d'accès côté serveur) a son marqueur PHOTO —
        // taille écran fixe, donc visible à N'IMPORTE quel zoom, contrairement
        // aux halos (cercles en mètres) qui disparaissent au dézoom.
        final famName = (famMember?['name'] ?? '').toString();
        final displayName = friend?.other!.name ??
            (famName.isNotEmpty ? famName : null) ??
            widget.focusUserName ??
            '—';
        // v249 — choix du role + avatar.
        final famRole = (famMember?['role'] ?? '').toString();
        final role = (friend?.other?.model ??
                (famRole.isNotEmpty ? famRole : pos.role))
            .toLowerCase();
        final famAvatar = (famMember?['avatar'] ?? '').toString();
        final avatarUrl = friend?.other?.avatar ??
            (famAvatar.isNotEmpty ? famAvatar : '');
        final normPosId = pos.userId.trim().toLowerCase();
        final isFamily = familyMemberIds.contains(normPosId);
        // v23.1.398 — couronne 👑 + anneau OR si ce membre est Paw Premium.
        final isPremiumMember = premiumMemberIds.contains(normPosId);
        final icon = _friendMarkerService.getOrPlaceholder(
          userId: pos.userId,
          avatarUrl: avatarUrl,
          role: role,
          isFamily: isFamily,
          isPremium: isPremiumMember,
        );
        markers.add(
          Marker(
            markerId: MarkerId('friend_${pos.userId}'),
            position: LatLng(pos.latitude, pos.longitude),
            icon: icon,
            // v249 — ancre au centre du bitmap (carre 120px) pour que
            // la photo soit centree pile sur la coord.
            anchor: const Offset(0.5, 0.5),
            infoWindow: InfoWindow(
              title: '👤 $displayName',
              snippet: isFamily
                  ? '${'pawmap_quick_family'.tr} · ${_timeAgo(pos.at)}'
                  : 'Vu il y a ${_timeAgo(pos.at)}',
            ),
            // v23.1.263 — taper un ami = zoom au plus près + suivi "à la
            // trace" : la caméra reste collée à lui à chaque nouvelle position.
            onTap: () => _startFollow(
              pos.userId,
              LatLng(pos.latitude, pos.longitude),
              displayName,
            ),
          ),
        );
      }
    }
    // Demandes layer — only sitters/walkers fetch & see these.
    if (_showRequests.value && _isSitterOrWalker) {
      for (final req in _requests) {
        markers.add(
          Marker(
            markerId: MarkerId('req_${req.id}'),
            position: LatLng(req.lat, req.lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueYellow,
            ),
            infoWindow: InfoWindow(
              title: '📣 ${req.ownerName.isNotEmpty ? req.ownerName : 'pawmap_default_request'.tr}',
              snippet: _requestSnippet(req),
            ),
            onTap: () => _showRequestBottomSheet(req),
          ),
        );
      }
    }
    return markers;
  }

  String _requestSnippet(NearbyRequestPost r) {
    final parts = <String>[];
    if (r.city.isNotEmpty) parts.add(r.city);
    parts.add('${r.distanceKm.toStringAsFixed(1)} km');
    if (r.serviceTypes.isNotEmpty) parts.add(r.serviceTypes.first);
    return parts.join(' · ');
  }

  /// Shows the details of a nearby reservation request and lets the
  /// sitter/walker act on it. For now the action is a simple CTA that
  /// pops the sheet and tells the user to open the full request from the
  /// Home screen — proper deep-link to the request detail / send-request
  /// flow will be wired in a follow-up when the backend exposes a
  /// canonical detail-by-id endpoint.
  void _showRequestBottomSheet(NearbyRequestPost r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      useSafeArea: true,
      builder: (sheetCtx) => Padding(
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
                Text('📣', style: TextStyle(fontSize: 22.sp)),
                SizedBox(width: 8.w),
                Expanded(
                  child: PoppinsText(
                    text: r.ownerName.isNotEmpty
                        ? r.ownerName
                        : 'Demande de garde',
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                InterText(
                  text: '${r.distanceKm.toStringAsFixed(1)} km',
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryColor,
                ),
              ],
            ),
            if (r.city.isNotEmpty) ...[
              SizedBox(height: 4.h),
              InterText(
                text: r.city,
                fontSize: 12.sp,
                color: AppColors.textSecondary(context),
              ),
            ],
            if (r.serviceTypes.isNotEmpty) ...[
              SizedBox(height: 10.h),
              Wrap(
                spacing: 6.w,
                runSpacing: 6.h,
                children: r.serviceTypes
                    .map((s) => Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: InterText(
                            text: s,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryColor,
                          ),
                        ))
                    .toList(),
              ),
            ],
            if (r.body.isNotEmpty) ...[
              SizedBox(height: 12.h),
              InterText(
                text: r.body,
                fontSize: 13.sp,
                color: AppColors.textPrimary(context),
              ),
            ],
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  CustomSnackbar.showSuccess(
                    title: 'pawmap_snack_post_opened_title'.tr,
                    message: 'pawmap_snack_post_opened_msg'.tr,
                  );
                },
                icon: const Icon(Icons.open_in_new, color: Colors.white),
                label: InterText(
                  text: 'pawmap_btn_view_post'.tr,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

  /// v23.1.353 — couleur pleine par catégorie POI, alignée sur _hueForPoi
  /// (vet rouge, park vert, water cyan, shop violet, groomer magenta,
  /// reste azure). Sert au fond/anneau du marqueur emoji + au mini halo.
  Color _colorForPoi(String category) {
    switch (category) {
      case PoiCategories.vet:
        return const Color(0xFFDC2626); // rouge
      case PoiCategories.park:
        return const Color(0xFF16A34A); // vert
      case PoiCategories.water:
        return const Color(0xFF06B6D4); // cyan
      case PoiCategories.shop:
        return const Color(0xFF8B5CF6); // violet
      case PoiCategories.groomer:
        return const Color(0xFFD946EF); // magenta
      default:
        return const Color(0xFF3B82F6); // azure
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
    return PopScope(
      canPop: _followUserId == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_followUserId != null) _stopFollow();
      },
      child: Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        title: Row(
          children: [
            // v470 — Daniel : « tu as mis un point orange au lieu du logo ». Le
            // colorFilter srcIn écrasait TOUT le logo (disque+pin+pattes) en un
            // aplat orange = un simple point. On utilise désormais le VRAI logo
            // orange (disque orange + pin blanc + pattes), SANS colorFilter.
            SvgPicture.asset(
              'assets/images/pawmap_logo_orange.svg',
              width: 28.w,
              height: 28.w,
            ),
            SizedBox(width: 8.w),
            InterText(
              text: 'PawMap',
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
          ],
        ),
        actions: [
          // v23.1.189 — Daniel : "en haut le suivre et amis horizontale ne
          // serve plus". Les 2 pills Suivre + Amis sont supprimees car les
          // 4 grosses cartes ci-dessous (v184) remplissent deja ces actions.
          // On ne garde que la loupe pour ouvrir la recherche ville + le
          // refresh.
          IconButton(
            tooltip: 'pawmap_search_city'.tr,
            icon: const Icon(Icons.search_rounded),
            onPressed: _onSearchCity,
          ),
          IconButton(
            tooltip: 'pawmap_appbar_refresh'.tr,
            icon: const Icon(Icons.refresh),
            onPressed: _reloadAtCenter,
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── PawMap NORMALE (inchangée) ──────────────────────────────────
          // v463 — tout le contenu d'origine reste DANS cette Column : la
          // GoogleMap normale n'est jamais redimensionnée ni détruite. Le mode
          // agrandi est un calque posé par-dessus (voir plus bas).
          Column(
        children: [
          // v463 — Daniel : barre du haut = [ Suivi en direct ON/OFF ] +
          // bouton compact [ Agrandir ] sur la MÊME ligne.
          _buildTopShareRow(),

          // v23.1.184 — Daniel : "je veux que tu reorganise la paw map
          // dans ce style" (mockup avec 4 grosses cartes colorees Suivre
          // / Famille & Amis / Alertes / Signaler). Remplace les anciens
          // _buildQuickSignalRow + _buildEmergencyRow qui faisaient
          // doublon avec le FAB et chargeaient l'ecran.
          _buildQuickActionsRow(),

          // v23.1.363 — Daniel : Signalements/Mon cercle fusionnés sur LA
          // MÊME ligne que Lieux/Tous/Rien (voir _buildCategoryFilterBar).

          // v23.1.285 — Daniel : "améliore le menu de la pawmap comme la photo".
          // Filtre catégories POI : bouton « Lieux (N) » + bouton « Tous », qui
          // ouvre une checklist 2 colonnes repliable (au lieu des puces qui
          // défilaient horizontalement et qu'on ne voyait pas en entier).
          _buildCategoryFilterBar(),

          // Map
          Expanded(
            child: Stack(
              children: [
                Obx(() {
                    // Force rebuild when either list changes
                    _poiController.visiblePois.length;
                    _reportController.reports.length;
                    _showPois.value;
                    _showReports.value;
                    // v23.1 part 123 — rebuild every halo tick (~5 fps) so
                    // le pulse Platinum reste fluide.
                    _haloPhase.value;
                    // v23.1.163 — VRAI ROOT CAUSE du bug "halo ne change pas
                    // de couleur" : l'Obx ne declarait PAS _nearbyProviders
                    // ni _showProviders comme dependance, donc le GoogleMap
                    // rebuildait UNIQUEMENT au tick halo (5fps), pas quand
                    // les providers chargeaient depuis l'API. Resultat :
                    // _buildHaloCircles s'executait sur _nearbyProviders=[]
                    // pendant des secondes, aucun halo n'apparaissait. Fix :
                    // on lit explicitement la length + le show flag pour
                    // forcer le rebuild a chaque assignAll().
                    _nearbyProviders.length;
                    _showProviders.value;
                    // v23.1.353 — refonte PawSpot : rebuild quand la couche
                    // spots 🐾 se toggle ou que les spots chargent.
                    _showPawSpots.value;
                    _pawSpotController.spots.length;
                    // v23.1 part 248 — Daniel : "ds lapp sa marche tjr pas"
                    // (halo violet famille). On declare explicitement
                    // familyMembers.length comme dependance Obx pour que
                    // dans le cas ou loadFamily() reussit APRES le premier
                    // tick halo, la map rebuild immediatement avec le ring
                    // violet visible.
                    try {
                      final fc = Get.isRegistered<FriendController>()
                          ? Get.find<FriendController>()
                          : null;
                      // ignore: unused_local_variable
                      final famLen = fc?.familyMembers.length ?? 0;
                      // ignore: unused_local_variable
                      final friLen = fc?.friends.length ?? 0;
                    } catch (_) {/* defensive */}
                    // v23.1 part 249 — rebuild quand un nouveau marker
                    // custom (photo profil) finit de generer. Sans cette
                    // dependance Obx, le marker reste sur le placeholder
                    // par defaut jusqu'a la prochaine vraie data change.
                    // ignore: unused_local_variable
                    final markerRev = _friendMarkerService.rev.value;
                    return GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _currentCenter,
                        zoom: 13,
                      ),
                      onMapCreated: (c) {
                        if (!_mapCtl.isCompleted) _mapCtl.complete(c);
                        // v23.1 part 213 — Si initialLat/Lng passés (clic
                        // sur une alerte), on anime la camera dessus
                        // immediatement (avant le _recenterOnUser auto).
                        final lat = widget.initialLat;
                        final lng = widget.initialLng;
                        if (lat != null && lng != null) {
                          // v23.1.263 — si on ouvre en mode suivi (focusUserId),
                          // on zoome au plus près directement.
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
                      // v23.1.363 — mode viseur : TAPER la carte place le
                      // pin du futur spot exactement là (Daniel : "je ne
                      // peux pas bien choisir ma position").
                      onTap: (latLng) {
                        // v449 — viseur spot OU signalement : taper la carte
                        // déplace le pin du futur spot/signalement.
                        if (_pickingSpotPos.value || _pickingReportPos.value) {
                          setState(() => _pickedSpotPos = latLng);
                        }
                      },
                      onCameraMove: _onCameraMove,
                      // v23.1.263 — un drag MANUEL de la carte coupe le suivi
                      // (sauf si c'est NOUS qui recentrons la caméra : flag
                      // _suppressFollowAutoStop). L'user reprend la main quand
                      // il veut, et retape l'ami pour resuivre.
                      onCameraMoveStarted: () {
                        if (_followUserId != null && !_suppressFollowAutoStop) {
                          _stopFollow();
                        }
                      },
                      onCameraIdle: _scheduleReload,
                      myLocationEnabled: true,
                      // v23.1 part 68 — Daniel : "cest derriere le bouton ma
                      // position quil ya un autre bouton a effacer". Google
                      // Maps' default location button overlapped our custom
                      // geoloc pin in the top row. Disabled here ; keep our
                      // own _recenterOnUser pin only.
                      myLocationButtonEnabled: false,
                      // v23.1 part 68 — disable Google's default zoom
                      // controls (they appear bottom-right on Android and
                      // overlap with the Signaler FAB). We provide our own
                      // +/- pair under the geoloc pin.
                      zoomControlsEnabled: false,
                      // v23.1 part 243 round 3 — markers memoizes, voir
                      // _cachedMarkers + _getMarkersFromCache plus haut.
                      // Plus de _buildMarkers() sur chaque tick halo.
                      mapType: _mapType,
                      markers: _getMarkersFromCache(),
                      circles: _buildHaloCircles(),
                      // v23.1.353 — polyline orange de l'itinéraire "Y aller"
                      // (GET /pawspots/directions).
                      polylines: _routePolylines,
                    );
                  }),

                // Loading pill
                Obx(() {
                  final loading = _poiController.isLoading.value ||
                      _reportController.isLoading.value;
                  if (!loading) return const SizedBox.shrink();
                  return Positioned(
                    top: 12.h,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14.w,
                              height: 14.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            InterText(
                              text: 'pawmap_loading'.tr,
                              fontSize: 12.sp,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                // v23.1.263 — bannière "Suivi en direct" : visible tant qu'on
                // suit un ami à la trace. Bouton Stop pour reprendre la main.
                if (_followUserId != null)
                  Positioned(
                    top: 12.h,
                    left: 12.w,
                    right: 12.w,
                    child: Center(child: _buildFollowingBanner()),
                  ),

                // v19.1.3 — compact upsell pins in the LEFT corner so they
                // stop covering the map (users complained the wide banner at
                // the bottom blocked freemium browsing). Premium = green
                // circular icon, Map Boost = blue circular icon. Tapping opens
                // the full CoinShop screen.
                // v23.1 part 40 — Daniel : déplace PawFollow/PawSpot du
                // BOTTOM-LEFT vers le HAUT-LEFT (sous la barre de recherche)
                // pour libérer la zone du bas.
                // v23.1.353 — refonte PawSpot : le pill bleu « PawSpot »
                // (raccourci boutique map-boost) est SUPPRIMÉ — la couche
                // spots communautaires 🐾 vit dans la barre de filtres.
                // v23.1.364 — Daniel : "le badge bouton PawFollow sur la
                // PawMap a réapparu, vire-le" — le pill flottant violet est
                // SUPPRIMÉ : le switch PawFollow de la rangée rapide suffit.

                // Barre de recherche ville (gauche) + bouton géoloc (droite)
                // en haut de la map. Les deux sont visibles en permanence
                // pour un accès rapide.
                // v23.1.189 — Daniel : "geolocalicasation + et -" plus
                // modernes. La search-bar est seule sur la 1ere ligne ;
                // les boutons + / - / geoloc sont regroupes dans un
                // pill vertical blanc plein a droite (style Google Maps
                // moderne) avec un divider fin entre chaque action.
                // v420 — Daniel : "enlève la barre rechercher sur la map, il y
                // a déjà rechercher en haut à droite" (icône 🔍 de l'AppBar).
                // La pill de recherche ville flottante est retirée. Les
                // contrôles +/-/géoloc remontent en haut à droite.
                Positioned(
                  // v469 — Daniel : relever très légèrement la barre +/-/satellite
                  // (elle touchait le bord du menu/panneau).
                  top: 4.h,
                  right: 12.w,
                  child: _buildMapControlsStack(),
                ),

                // v23.1 part 67 — Daniel : "2 boutons qui se chevauchent".
                // Le Signaler FAB et le bouton géoloc étaient tous les deux
                // en haut à droite avec un gap insuffisant sur petits écrans.
                // On remet Signaler en BOTTOM-RIGHT (au-dessus de la nav bar)
                // pour séparer clairement les deux affordances : géoloc en
                // haut, signaler en bas. La zone centrale de la map reste
                // dégagée.
                // v418 — Daniel : "le bouton signaler en bas à gauche petit".
                // On le déplace en BAS À GAUCHE (était bottom-right) et on le
                // rend compact (rond, icône seule). La carte « Autour de vous »
                // est remontée pour ne plus le chevaucher (cf _buildAroundYouCard).
                // v488 — Daniel : 4 boutons RONDS (Voir spots / Tag spot / Voir
                // signaux / Signaler) centrés verticalement à GAUCHE, petite
                // carte (remplace l'unique FAB Signaler + les pilules).
                // v490/v494 — Daniel : le 4e bouton (Signaler) restait masqué par
                // le menu. La colonne centrée était trop haute pour la petite
                // carte. On l'ANCRE EN HAUT (top fixe) → les 4 boutons (compactés)
                // stackent depuis le haut et tiennent au-dessus du menu.
                Positioned(
                  left: 12.w,
                  top: 8.h,
                  child: _buildMapActionsColumn(),
                ),

                // v456 — POINT ROUGE FIXE au centre (placement précis), pour
                // les DEUX viseurs (Paw Spot ET Signalement). La carte bouge
                // SOUS le repère ; à Valider il disparaît et seul l'emoji reste.
                Obx(() => (_pickingSpotPos.value || _pickingReportPos.value)
                    ? _buildCenterReticle()
                    : const SizedBox.shrink()),

                // v23.1.360 — mode VISEUR « Taguer un lieu » : bandeau
                // Valider/Annuler. La carte bouge SOUS le repère central.
                Obx(() => _pickingSpotPos.value
                    ? _buildSpotPickerOverlay()
                    : const SizedBox.shrink()),

                // v449 — viseur SIGNALEMENT (express) : bandeau « Signaler ici ».
                Obx(() => _pickingReportPos.value
                    ? _buildReportPickerOverlay()
                    : const SizedBox.shrink()),

                // v23.1.187 — Daniel mockup : carte "Autour de vous" flottante
                // en bas de la PawMap. Liste compacte des 3 signalements les
                // plus proches avec badge severite + tap → AlertsScreen.
                // v23.1.353 — masquée pendant qu'un itinéraire est affiché
                // (le bandeau distance + "Effacer" prend sa place).
                if (_routePolylines.isEmpty)
                  Positioned(
                    // v418 — le FAB Signaler est passé en bas à GAUCHE : on
                    // décale la carte « Autour de vous » pour ne pas le couvrir.
                    left: 72.w,
                    right: 12.w,
                    // v470 — Daniel : « Autour de vous derrière le menu et trop
                    // grand ». On relève la carte au-dessus du menu pleine
                    // largeur (116) + inset ; la taille est réduite dans
                    // _buildAroundYouCard (police + paddings + max 2 lignes).
                    bottom: 116.h + MediaQuery.of(context).viewPadding.bottom,
                    child: _buildAroundYouCard(),
                  )
                else
                  Positioned(
                    left: 12.w,
                    right: 12.w,
                    // v401 — Daniel : "le bouton Effacer l'itinéraire trop bas,
                    // il gêne". Le bandeau distance + Effacer passait sous la
                    // barre de gestes Android. On le remonte de tout l'inset
                    // système + une marge pour qu'il ne croise plus le FAB
                    // Signaler (bottom-right, à 24.h + inset).
                    // v470 — relevé franchement au-dessus de la barre de menu
                    // pleine largeur.
                    bottom: 136.h + MediaQuery.of(context).viewPadding.bottom,
                    child: Center(child: _buildDirectionsBanner()),
                  ),
              ],
            ),
          ),
        ],
      ),

          // ── CALQUE « carte agrandie » (par-dessus la PawMap normale) ────
          // La PawMap normale ci-dessus reste montée et INTACTE (sa GoogleMap
          // n'est jamais redimensionnée ni détruite). Ce calque possède sa
          // PROPRE GoogleMap plein écran ; à la réduction il disparaît et la
          // carte normale réapparaît telle quelle → zéro risque de carte
          // blanche (contrairement aux tentatives v451/v458).
          Obx(() => _mapExpanded.value
              ? Positioned.fill(child: _buildExpandedMapOverlay())
              : const SizedBox.shrink()),
        ],
      ),
      ),
    );
  }

  /// v23.1 part 68 — Daniel : "mettre bouton + - en haut a droit".
  /// Small white pill that wraps a zoom-in / zoom-out icon.
  /// v23.1.189 — Daniel : "geolocalicasation + et - paw follow et pawspot
  /// un design beaucoupl plus moderne et jolie". Pill vertical blanc qui
  /// regroupe zoom + / zoom - / geoloc cible dans une seule unite, style
  /// Google Maps moderne avec divider fin entre chaque action et ombre
  /// douce floue.
  Widget _buildMapControlsStack() {
    return Container(
      width: 44.w,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStackedControl(
            icon: Icons.my_location_rounded,
            onTap: _recenterOnUser,
            tone: AppColors.primaryColor,
          ),
          _stackedDivider(),
          _buildStackedControl(
            icon: Icons.add_rounded,
            onTap: _zoomIn,
            // v23.1.281 — ton FIXE foncé : la pilule est blanche (lisible sur
            // la carte claire) donc l'icône ne doit PAS suivre le thème, sinon
            // en dark mode textPrimary devient blanc → icône blanche invisible.
            tone: const Color(0xFF1F2937),
          ),
          _stackedDivider(),
          _buildStackedControl(
            icon: Icons.remove_rounded,
            onTap: _zoomOut,
            // v23.1.281 — ton FIXE foncé : la pilule est blanche (lisible sur
            // la carte claire) donc l'icône ne doit PAS suivre le thème, sinon
            // en dark mode textPrimary devient blanc → icône blanche invisible.
            tone: const Color(0xFF1F2937),
          ),
          // v23.1.266 — bouton vue satellite (hybride) discret.
          _stackedDivider(),
          _buildStackedControl(
            icon: _mapType == MapType.normal
                ? Icons.satellite_alt_rounded
                : Icons.map_rounded,
            onTap: _toggleMapType,
            tone: _mapType == MapType.normal
                ? const Color(0xFF1F2937)
                : AppColors.primaryColor,
          ),
          // v23.1.266 — bouton "voir tous mes amis" (dézoome pour les englober).
          _stackedDivider(),
          _buildStackedControl(
            icon: Icons.groups_rounded,
            onTap: _fitAllFriends,
            // v23.1.281 — ton FIXE foncé : la pilule est blanche (lisible sur
            // la carte claire) donc l'icône ne doit PAS suivre le thème, sinon
            // en dark mode textPrimary devient blanc → icône blanche invisible.
            tone: const Color(0xFF1F2937),
          ),
        ],
      ),
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

  Widget _buildStackedControl({
    required IconData icon,
    required VoidCallback onTap,
    required Color tone,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22.r),
        child: SizedBox(
          width: 44.w,
          height: 44.w,
          child: Icon(icon, color: tone, size: 22.sp),
        ),
      ),
    );
  }

  Widget _stackedDivider() {
    return Container(
      height: 1,
      margin: EdgeInsets.symmetric(horizontal: 8.w),
      color: AppColors.greyText.withValues(alpha: 0.15),
    );
  }

  // ─── Suivi live d'un ami (v23.1.263) ────────────────────────────────────
  /// Recentre la caméra sur [target]. Marque le mouvement comme "programmatique"
  /// pendant ~800 ms pour que onCameraMoveStarted ne coupe pas le suivi.
  Future<void> _animateFollowCamera(LatLng target, {double? zoom}) async {
    // v469 — si la carte est AGRANDIE, on anime la caméra du calque (sa propre
    // GoogleMap visible) ; sinon celle de la carte normale.
    GoogleMapController? ctl;
    if (pawMapExpanded.value && _expandedCtl != null) {
      ctl = _expandedCtl;
    } else {
      if (!_mapCtl.isCompleted) return;
      ctl = await _mapCtl.future;
    }
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

  /// Démarre le suivi d'un ami : zoom au plus près + recentrage auto ensuite.
  void _startFollow(String userId, LatLng pos, String name) {
    setState(() {
      _followUserId = userId;
      _followName = name;
    });
    _animateFollowCamera(pos, zoom: _followZoom);
  }

  /// Arrête le suivi (bouton Stop ou drag manuel de la carte).
  void _stopFollow() {
    if (_followUserId == null) return;
    setState(() {
      _followUserId = null;
      _followName = '';
    });
  }

  /// Bannière "Suivi en direct" affichée tant qu'on suit un ami à la trace.
  Widget _buildFollowingBanner() {
    final name = _followName.trim().isEmpty
        ? 'pawmap_following_default'.tr
        : _followName.trim();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: AppColors.primaryColor,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9.w,
            height: 9.w,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8.w),
          Flexible(
            child: InterText(
              text: 'pawmap_following_label'.trParams({'name': name}),
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              maxLines: 1,
            ),
          ),
          SizedBox(width: 10.w),
          GestureDetector(
            onTap: _stopFollow,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: InterText(
                text: 'pawmap_following_stop'.tr,
                fontSize: 11.sp,
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
  Future<void> _zoomIn() async {
    if (!_mapCtl.isCompleted) return;
    final ctl = await _mapCtl.future;
    // Zoomer ne doit pas couper le suivi en cours.
    if (_followUserId != null) _suppressFollowAutoStop = true;
    await ctl.animateCamera(CameraUpdate.zoomBy(0.8));
    if (_followUserId != null) {
      Future.delayed(const Duration(milliseconds: 800),
          () => _suppressFollowAutoStop = false);
    }
  }

  Future<void> _zoomOut() async {
    if (!_mapCtl.isCompleted) return;
    final ctl = await _mapCtl.future;
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
      final loc = await LocationService()
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
      if (_mapCtl.isCompleted) {
        final ctl = await _mapCtl.future;
        await ctl.animateCamera(CameraUpdate.newLatLng(center));
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
  Widget _buildSpotPickerOverlay() {
    return Positioned.fill(
      child: Stack(
        children: [
          // v23.1.363 — le faux pin central est remplacé par un VRAI
          // marqueur rose ancré au sol (tap sur la carte / drag du pin).
          // Bulle d'aide.
          Positioned(
            top: 10.h,
            left: 24.w,
            right: 24.w,
            child: IgnorePointer(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: InterText(
                  text: 'pawspot_pick_hint'.tr,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F2937),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          // Bandeau Valider / Annuler.
          // v465 — Daniel : le bandeau était caché derrière la barre Samsung.
          // On ajoute l'inset système physique pour qu'il reste au-dessus.
          Positioned(
            left: 16.w,
            right: 16.w,
            // v470 — Daniel : « en carte agrandie les boutons Valider du tag
            // sont derrière la barre Samsung ». En agrandi le menu est masqué
            // mais l'inset seul ne suffisait pas → on garde un socle FIXE (48)
            // au-dessus de la barre système. En normal, on dégage le menu (~96).
            bottom: 16.h +
                MediaQuery.of(context).viewPadding.bottom +
                (pawMapExpanded.value ? 64.h : 116.h),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14.r),
                    onTap: () => _pickingSpotPos.value = false,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                            color: AppColors.greyText.withValues(alpha: 0.5)),
                      ),
                      child: Center(
                        child: InterText(
                          text: 'pawspot_pick_cancel'.tr,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14.r),
                    onTap: () {
                      final at = _pickedSpotPos ?? _currentCenter;
                      _pickingSpotPos.value = false;
                      unawaited(_openPawSpotCreate(at: at));
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEC4899), Color(0xFFF472B6)],
                        ),
                        borderRadius: BorderRadius.circular(14.r),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEC4899)
                                .withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: InterText(
                          text: 'pawspot_pick_confirm'.tr,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
              color: Colors.black.withValues(alpha: 0.10),
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
                  onTap: () => Get.to(() => const AlertsScreen()),
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
                      color: AppColors.greyText.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded,
                        size: 14.sp, color: AppColors.greyText),
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
                  color: AppColors.greyText,
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

  /// v23.1.184 — Daniel : "je veux que tu reorganise la paw map dans ce
  /// style" (mockup avec 4 grosses cartes colorees Suivre / Famille &
  /// Amis / Alertes / Signaler en haut).
  ///
  /// Header strip avec 4 quick-actions colorees, posees au-dessus de la
  /// map. Remplace les anciens _buildQuickSignalRow + _buildEmergencyRow
  /// qui faisaient doublon avec le FAB et chargeaient l'ecran.
  Widget _buildQuickActionsRow() {
    // v418 — refonte maquette Daniel : grille 2×2 de cartes larges (icône
    // ronde colorée + titre + sous-titre + chevron). Mon cercle (violet) /
    // Alertes (orange) / En direct (vert) / Mes signalements (rouge).
    // Le toggle « Suivre » est désormais la bannière verte « Tu es en direct ».
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 4.h),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Obx(() {
                  final pending = _friendController.incomingRequests.length;
                  return _gridActionCard(
                    icon: Icons.group_rounded,
                    title: 'pawmap_quick_family'.tr,
                    subtitle: 'pawmap_quick_circle_sub'.tr,
                    color: const Color(0xFF8B5CF6),
                    badgeCount: pending,
                    onTap: () => Get.to(() => const FriendsScreen()),
                  );
                }),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _gridActionCard(
                  icon: Icons.notifications_rounded,
                  title: 'pawmap_quick_alerts'.tr,
                  subtitle: 'pawmap_quick_alerts_sub'.tr,
                  color: const Color(0xFFF59E0B),
                  onTap: () => Get.to(() => const AlertsScreen()),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: _gridActionCard(
                  icon: Icons.my_location_rounded,
                  title: 'pawmap_quick_live'.tr,
                  subtitle: 'pawmap_quick_live_sub'.tr,
                  color: const Color(0xFF16A34A),
                  onTap: () => Get.to(() => const PeopleLiveScreen()),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _gridActionCard(
                  icon: Icons.verified_user_rounded,
                  title: 'pawmap_quick_my_reports'.tr,
                  subtitle: 'pawmap_quick_my_reports_sub'.tr,
                  color: const Color(0xFFDC2626),
                  onTap: () => Get.to(() => const AlertsScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// v418 — carte large 2×2 (maquette PawMap) : pastille ronde colorée +
  /// titre + sous-titre + chevron, sur fond blanc arrondi.
  Widget _gridActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return Material(
      color: AppColors.card(context),
      borderRadius: BorderRadius.circular(16.r),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.greyText.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 38.w,
                    height: 38.w,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 20.sp),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: EdgeInsets.all(4.w),
                        constraints: BoxConstraints(minWidth: 16.w, minHeight: 16.w),
                        decoration: const BoxDecoration(
                          color: Color(0xFFDC2626),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: InterText(
                            text: '$badgeCount',
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // v448 — Daniel : « réduis la police pour voir mes membres »
                    // (cartes Mon cercle / Mes signalements). Police plus petite
                    // + 2 lignes → le libellé entier reste visible, pas coupé.
                    InterText(
                      text: title,
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 1.h),
                    InterText(
                      text: subtitle,
                      fontSize: 8.5.sp,
                      color: AppColors.greyText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.greyText, size: 18.sp),
            ],
          ),
        ),
      ),
    );
  }

  // v23.1.285 — barre de filtre catégories POI + checklist 2 colonnes
  // repliable (remplace les puces horizontales). Le panneau pousse la carte
  // vers le bas (il est dans la Column, pas en overlay → pas de souci de z-index
  // au-dessus de GoogleMap).
  Widget _buildCategoryFilterBar() {
    return Obx(() {
      final selected = _poiController.enabledCategories
          .where((c) => c != '__none__')
          .toSet();
      final total = PoiCategories.all.length;
      // v23.1.288 — Daniel : retirer le bouton « Rien » (inutile). Pour tout
      // masquer, on utilise le toggle 📍 de la rangée de couches. « Tous »
      // rallume la couche POI + enlève le filtre. _showPois reste piloté par ce
      // toggle maître ; on garde la logique de comptage ci-dessous.
      final poisOn = _showPois.value;
      final allShown = poisOn && selected.isEmpty;
      // 0 si la couche est éteinte (Rien), sinon nb affiché.
      final shownCount = !poisOn ? 0 : (selected.isEmpty ? total : selected.length);
      final open = _showCatFilter.value;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // v447 — Daniel : "AUCUN slide horizontal". La rangée de filtres
          // (Lieux (N/N) ▾ | Tous | Rien | Signalements) tient TOUJOURS sur
          // une ligne grâce à 4 Expanded compacts — fini le
          // SingleChildScrollView horizontal. Le toggle « Mon cercle » est
          // gouverné par le switch PawFollow (couche live) et les demandes
          // sitter/walker restent visibles par défaut.
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            child: Row(
              children: [
                // Lieux (N/N) ▾ — ouvre/ferme la checklist catégories.
                Expanded(
                  child: _compactFilterButton(
                    onTap: () => _showCatFilter.value = !open,
                    active: true,
                    leading:
                        Text('📍', style: TextStyle(fontSize: 11.sp)),
                    label: '${'pawmap_filter_places'.tr} ($shownCount/$total)',
                    trailing: Icon(
                      open
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFFEF4324),
                      size: 15.sp,
                    ),
                  ),
                ),
                SizedBox(width: 6.w),
                // Tous — rallume la couche POI + enlève le filtre.
                Expanded(
                  child: _compactFilterButton(
                    onTap: () {
                      _showPois.value = true;
                      _poiController.selectAllCategories();
                    },
                    active: allShown,
                    label: 'paw_map_filter_all'.tr,
                  ),
                ),
                SizedBox(width: 6.w),
                // Rien — éteint la couche POI.
                Expanded(
                  child: _compactFilterButton(
                    onTap: () => _showPois.value = false,
                    active: !poisOn,
                    leading: Icon(Icons.block_rounded,
                        size: 12.sp,
                        color: !poisOn
                            ? const Color(0xFFEF4324)
                            : AppColors.greyText),
                    label: 'pawmap_filter_none'.tr,
                  ),
                ),
                SizedBox(width: 6.w),
                // Signalements — toggle de la couche reports 48h.
                Expanded(
                  child: Obx(() {
                    final active = _showReports.value;
                    final count = _reportController.reports
                        .where((r) => !r.isExpired)
                        .length;
                    return _compactFilterButton(
                      onTap: () => _showReports.value = !active,
                      active: active,
                      leading: Text('⚠️', style: TextStyle(fontSize: 11.sp)),
                      label: 'pawmap_filter_reports'.tr,
                      trailing: count > 0
                          ? Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 4.w, vertical: 1.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4324),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: InterText(
                                text: '$count',
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    );
                  }),
                ),
              ],
            ),
          ),
          // v23.1.356 — maquette Daniel : rangée « boutons rapides » sur UNE
          // seule ligne (PawFollow ⭐ / PawSpot 🐾 avec switch ON-OFF +
          // couronne 👑 si abonnement actif, Taguer un lieu, Voir les spots).
          // Remplace l'ancien chip PawSpot de la barre et le mini-FAB 🐾+.
          _buildQuickTogglesRow(),
          // Checklist 2 colonnes (repliable).
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: open
                ? _buildCategoryChecklist(selected)
                : const SizedBox.shrink(),
          ),
        ],
      );
    });
  }

  /// v447 — bouton compact de la rangée de filtres (Lieux / Tous / Rien /
  /// Signalements). Conçu pour vivre dans un Expanded : largeur fluide, label
  /// ellipsé, cadre fin — la rangée tient TOUJOURS sur une ligne, sans slide.
  Widget _compactFilterButton({
    required VoidCallback onTap,
    required bool active,
    required String label,
    Widget? leading,
    Widget? trailing,
  }) {
    const accent = Color(0xFFEF4324);
    return InkWell(
      borderRadius: BorderRadius.circular(11.r),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.10) : Colors.white,
          borderRadius: BorderRadius.circular(11.r),
          border: Border.all(
            color: active ? accent : const Color(0xFFE0E0E0),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leading != null) ...[
              leading,
              SizedBox(width: 3.w),
            ],
            Flexible(
              child: InterText(
                text: label,
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w800,
                color: active ? accent : const Color(0xFF1F2937),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            if (trailing != null) ...[
              SizedBox(width: 3.w),
              trailing,
            ],
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
        border: Border.all(color: AppColors.greyText.withValues(alpha: 0.12)),
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
                              ? const Color(0xFFEF4324)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6.r),
                          border: Border.all(
                            color: checked
                                ? const Color(0xFFEF4324)
                                : AppColors.greyText.withValues(alpha: 0.5),
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
                        color: AppColors.greyText.withValues(alpha: 0.4)),
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
                    backgroundColor: const Color(0xFFEF4324),
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
  Widget _buildLiveBroadcastBanner() {
    // v418 — maquette Daniel : bannière verte TOUJOURS visible avec interrupteur
    // ON/OFF (« Tu es en direct / Tes amis & ta famille voient ta position »).
    // C'est LE contrôle du partage en direct (l'ancienne carte « Suivre » est
    // remplacée par cette bannière). OFF → gris, ON → vert.
    return Obx(() {
      final on = _liveMap.broadcasting.value;
      return Container(
        margin: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 0),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          gradient: on
              ? const LinearGradient(
                  colors: [Color(0xFF16A34A), Color(0xFF059669)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: on ? null : AppColors.card(context),
          borderRadius: BorderRadius.circular(16.r),
          // v488 — Daniel : surbrillance contour VERT sur « Partager ma
          // position » (toujours visible, ON comme OFF).
          border: Border.all(
            color: const Color(0xFF16A34A),
            width: 2,
          ),
          boxShadow: on
              ? [
                  BoxShadow(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 10.w,
              height: 10.w,
              decoration: BoxDecoration(
                color: on ? Colors.white : AppColors.greyText,
                shape: BoxShape.circle,
                boxShadow: on
                    ? [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.7),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InterText(
                    text: on
                        ? 'pawmap_live_banner_title'.tr
                        : 'pawmap_live_share_off'.tr,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: on ? Colors.white : AppColors.textPrimary(context),
                  ),
                  SizedBox(height: 1.h),
                  InterText(
                    text: 'pawmap_live_banner_msg'.tr,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: on
                        ? Colors.white.withValues(alpha: 0.95)
                        : AppColors.greyText,
                  ),
                ],
              ),
            ),
            // Interrupteur ON/OFF (maquette : toggle blanc sur vert).
            Switch(
              value: on,
              onChanged: (_) => _toggleBroadcast(),
              activeThumbColor: const Color(0xFF16A34A),
              activeTrackColor: Colors.white,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: AppColors.greyText.withValues(alpha: 0.4),
            ),
          ],
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
  Widget _buildExpandPill({required bool expanded}) {
    const pink = Color(0xFFEC1E79); // rose intense
    final fg = expanded ? Colors.white : AppColors.textPrimary(context);
    return Padding(
      padding: EdgeInsets.only(top: 8.h),
      child: Material(
        color: expanded ? pink : AppColors.card(context),
        borderRadius: BorderRadius.circular(14.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(14.r),
          onTap: () {
            // v469 — en réduisant, on invalide le contrôleur du calque (sa
            // GoogleMap va être démontée) → le suivi repasse sur _mapCtl.
            if (expanded) _expandedCtl = null;
            _mapExpanded.value = !expanded;
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              // v488 — Daniel : surbrillance contour ROSE sur Agrandir/Réduire.
              border: Border.all(color: pink, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  expanded
                      ? Icons.close_fullscreen_rounded
                      : Icons.open_in_full_rounded,
                  size: 16.sp,
                  color: fg,
                ),
                SizedBox(height: 2.h),
                InterText(
                  text: expanded
                      ? 'pawmap_reduce_map'.tr
                      : 'pawmap_expand_short'.tr,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Calque plein écran posé PAR-DESSUS la PawMap normale. Possède sa propre
  /// GoogleMap (instance dédiée, plein écran). La carte normale en dessous
  /// n'est JAMAIS redimensionnée → zéro carte blanche au retour.
  Widget _buildExpandedMapOverlay() {
    return Material(
      // Fond opaque (couleur du rôle) → aucun flash blanc pendant le 1er rendu.
      color: AppColors.scaffold(context),
      child: Stack(
        children: [
          // Carte plein écran dédiée.
          Positioned.fill(
            child: Obx(() {
              // Mêmes dépendances Obx que la carte normale (markers/halo/spots).
              _poiController.visiblePois.length;
              _reportController.reports.length;
              _showPois.value;
              _showReports.value;
              _haloPhase.value;
              _nearbyProviders.length;
              _showProviders.value;
              _showPawSpots.value;
              _pawSpotController.spots.length;
              // ignore: unused_local_variable
              final markerRev = _friendMarkerService.rev.value;
              return GoogleMap(
                initialCameraPosition:
                    CameraPosition(target: _currentCenter, zoom: 13),
                // v469 — le calque a SON contrôleur (séparé de _mapCtl) pour que
                // le suivi anime BIEN la carte agrandie visible, pas la carte
                // normale cachée dessous.
                onMapCreated: (c) {
                  _expandedCtl = c;
                  // Si on suit déjà quelqu'un au moment d'agrandir, on recolle
                  // tout de suite la caméra du calque sur lui.
                  final uid = _followUserId;
                  if (uid != null) {
                    final fp = _liveMap.friendPositions[uid];
                    if (fp != null) {
                      c.animateCamera(CameraUpdate.newLatLngZoom(
                          LatLng(fp.latitude, fp.longitude), _followZoom));
                    }
                  }
                },
                onTap: (latLng) {
                  if (_pickingSpotPos.value || _pickingReportPos.value) {
                    setState(() => _pickedSpotPos = latLng);
                  }
                },
                onCameraMove: _onCameraMove,
                onCameraIdle: _scheduleReload,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapType: _mapType,
                markers: _getMarkersFromCache(),
                circles: _buildHaloCircles(),
                polylines: _routePolylines,
              );
            }),
          ),

          // Repère central + bandeaux de validation (mêmes que la carte normale).
          Obx(() => (_pickingSpotPos.value || _pickingReportPos.value)
              ? _buildCenterReticle()
              : const SizedBox.shrink()),
          Obx(() => _pickingSpotPos.value
              ? _buildSpotPickerOverlay()
              : const SizedBox.shrink()),
          Obx(() => _pickingReportPos.value
              ? _buildReportPickerOverlay()
              : const SizedBox.shrink()),

          // EN HAUT : [ Suivi en direct ON/OFF ] [ Réduire la carte ]
          Positioned(
            top: 8.h,
            left: 0,
            right: 0,
            child: Row(
              children: [
                Expanded(child: _buildLiveBroadcastBanner()),
                _buildExpandPill(expanded: true),
                SizedBox(width: 12.w),
              ],
            ),
          ),

          // v488 — Daniel : MÊMES 4 boutons ronds qu'en petite carte (Voir
          // spots / Tag spot / Voir signaux / Signaler), centrés verticalement
          // à GAUCHE, en mode agrandi aussi.
          Positioned(
            left: 12.w,
            top: 0,
            bottom: 0,
            child: Center(child: _buildMapActionsColumn()),
          ),
        ],
      ),
    );
  }


  /// v488 — Daniel : 4 boutons RONDS à gauche (petite ET grande carte), de haut
  /// en bas : Voir spots · Tag spot · Voir signaux · Signaler. Boutons Material
  /// (PAS de FloatingActionButton → aucun conflit de Hero tag entre les 2
  /// cartes coexistantes). Tag spot / Voir spots respectent l'abonnement
  /// PawSpot (sinon → route boutique via _togglePawSpot). Signaler + Voir
  /// signaux restent gratuits.
  Widget _buildMapActionsColumn() {
    return Obx(() {
      final spotOk = _pawSpotController.pawspotActive.value;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _roundMapBtn(
            icon: Icons.travel_explore_rounded,
            color: const Color(0xFF2563EB),
            label: 'pawmap_view_spots_btn'.tr,
            onTap: () => spotOk
                ? unawaited(_openSpotsList())
                : unawaited(_togglePawSpot()),
          ),
          SizedBox(height: 8.h),
          _roundMapBtn(
            icon: Icons.add_location_alt_rounded,
            color: const Color(0xFFD9A441),
            label: 'pawmap_tag_spot'.tr,
            onTap: () =>
                spotOk ? _startSpotPicking() : unawaited(_togglePawSpot()),
          ),
          SizedBox(height: 8.h),
          _roundMapBtn(
            icon: Icons.notifications_active_rounded,
            color: const Color(0xFFEA580C),
            label: 'pawmap_view_reports_btn'.tr,
            onTap: () => Get.to(() => const AlertsScreen()),
          ),
          SizedBox(height: 8.h),
          _roundMapBtn(
            icon: Icons.add_moderator_rounded,
            color: const Color(0xFFDC2626),
            label: 'pawmap_btn_send'.tr,
            onTap: _startReportPicking,
          ),
        ],
      );
    });
  }

  /// Bouton rond (Material + InkWell, sans Hero) + mini-label dessous.
  Widget _roundMapBtn({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          elevation: 4,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              // v494 — Daniel : « Signaler » (4e bouton) masqué par le menu sur
              // la petite carte. Boutons compactés (44→38) + colonne ancrée en
              // haut (cf. Positioned) pour que les 4 tiennent au-dessus du menu.
              width: 38.w,
              height: 38.w,
              child: Icon(icon, color: Colors.white, size: 18.sp),
            ),
          ),
        ),
        SizedBox(height: 3.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(7.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: InterText(
            text: label,
            fontSize: 8.5.sp,
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ─── PawSpot — couche spots communautaires 🐾 (v23.1.353) ────────────────

  /// Mini FAB doré « 🐾 + » (au-dessus du FAB Signaler) → sheet de création.
  /// v23.1.356 — maquette Daniel : rangée « boutons rapides » une-ligne sous
  /// la barre de filtres. PawFollow (switch couche live, VIOLET + 👑 si abo
  /// PawFollow/PawFamily actif) · PawSpot (switch couche spots, DORÉ + 👑 si
  /// abo actif) · Taguer un lieu · Voir les spots.
  /// v23.1.360 — maquette Daniel : grille 2×2 PLEINE LARGEUR (fini le
  /// scroll horizontal) — ligne 1 : PawFollow ⭐ | PawSpot 🐾 (switch +
  /// couronne 👑 si abonné) ; ligne 2 : Taguer un lieu | Voir les spots.
  /// + LÉGENDE des 6 types de spots quand la couche PawSpot est ON.
  Widget _buildQuickTogglesRow() {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 8.h),
      child: Obx(() {
        // v449 — Daniel : les 3 switches doivent refléter l'ABONNEMENT RÉEL,
        // pas un simple toggle de couche. ON uniquement si l'abo est actif
        // (payé / essai / staff) ; OFF → ne s'allume PAS tout seul, on route
        // vers la boutique. Les flags viennent de PawSpotController qui les
        // lit depuis GET /users/me/benefits :
        //   followActive  = pawFollowActive OU familyActive OU premium
        //   pawspotActive = pawspotActive OU premium
        //   premiumActive = premiumActive
        final followSub = _pawSpotController.followActive.value;
        final spotSub = _pawSpotController.pawspotActive.value;
        final premiumOn = _pawSpotController.premiumActive.value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // v449 — Daniel : petit ℹ️ qui rappelle que ON/OFF n'agit que sur
            // l'AFFICHAGE de la carte (l'abonnement reste actif).
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: _showPawMapToggleInfo,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 4.h, right: 2.w),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 14.sp, color: AppColors.textSecondary(context)),
                      SizedBox(width: 4.w),
                      InterText(
                        text: 'pawmap_toggle_info_chip'.tr,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _quickSwitchChip(
                    label: 'PawFollow',
                    // v23.1.387 — nouveau logo officiel (pin violet + patte).
                    assetIcon: 'assets/images/pawfollow_logo.png',
                    accent: const Color(0xFF7C3AED),
                    subscribed: followSub,
                    // v448 — ON = abo actif ET couche live affichée. Abonné, on
                    // peut couper/rallumer l'affichage manuellement.
                    value: followSub && _showLiveLayer.value,
                    onChanged: (_) => unawaited(_togglePawFollow()),
                  ),
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: _quickSwitchChip(
                    label: 'PawSpot',
                    // v447 — LOGO OFFICIEL PawSpot = la pièce dorée
                    // GoldenPawCoin (même mark que la boutique / les onglets),
                    // pas un emoji générique.
                    coinIcon: true,
                    accent: const Color(0xFFE8A00A),
                    subscribed: spotSub,
                    // v448 — ON = abo actif ET couche spots affichée. Abonné,
                    // on/off manuel de la couche ; OFF→ON sans abo route en
                    // boutique.
                    value: spotSub && _showPawSpots.value,
                    onChanged: (_) => unawaited(_togglePawSpot()),
                  ),
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: _quickSwitchChip(
                    label: 'PawPremium',
                    // v447 — logo officiel Paw Premium (pièce or + couronne).
                    assetIcon: 'assets/images/pawpremium_logo.png',
                    accent: const Color(0xFFE8A00A),
                    subscribed: premiumOn,
                    // v448 — ON = abo Premium actif ET couche premium affichée.
                    // Abonné, on/off manuel des halos OR Premium.
                    value: premiumOn && _showPremiumLayer.value,
                    onChanged: (_) => unawaited(_togglePawPremium()),
                  ),
                ),
              ],
            ),
            // v488 — Daniel : les pilules « Taguer un lieu / Voir les spots »
            // ET la légende sont RETIRÉES de la carte. Tag spot / Voir spots
            // sont désormais 2 des 4 boutons ronds à gauche ; la légende des
            // types vit en bas de l'onglet PawSpot de la boutique.
          ],
        );
      }),
    );
  }

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
    _pickingSpotPos.value = true;
    if (mounted) setState(() {});
  }

  /// v449 — Daniel : viseur SIGNALEMENT express. Pin (rouge) déplaçable au
  /// centre, tap sur la carte pour ajuster ; bandeau « Signaler ici » → ouvre
  /// la feuille de signalement au point choisi. Plus rapide que Taguer un lieu
  /// (une seule action de validation).
  void _startReportPicking() {
    _pickedSpotPos = _userPosition ?? _currentCenter;
    _pickingReportPos.value = true;
    if (mounted) setState(() {});
  }

  /// Bandeau bas du viseur signalement : hint + bouton « Signaler ici » + ✕.
  Widget _buildReportPickerOverlay() {
    return Positioned(
      left: 12.w,
      right: 12.w,
      // v470 — Daniel : en agrandi le bandeau « Signaler ici » passait derrière
      // la barre Samsung → socle FIXE (48) au-dessus de la barre système ;
      // en normal on dégage le menu pleine largeur (~96).
      bottom: 24.h +
          MediaQuery.of(context).viewPadding.bottom +
          (pawMapExpanded.value ? 64.h : 116.h),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.place_rounded,
                  color: const Color(0xFFDC2626), size: 20.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: InterText(
                  text: 'pawmap_report_pick_hint'.tr,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                  maxLines: 2,
                ),
              ),
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: () {
                  _pickingReportPos.value = false;
                  if (mounted) setState(() {});
                },
                child: Icon(Icons.close_rounded,
                    color: AppColors.greyText, size: 22.sp),
              ),
              SizedBox(width: 10.w),
              GestureDetector(
                onTap: () async {
                  final at = _pickedSpotPos ?? _userPosition ?? _currentCenter;
                  _pickingReportPos.value = false;
                  if (mounted) setState(() {});
                  final created =
                      await CreateReportSheet.show(context, initialPoint: at);
                  if (created) await _reloadAtCenter();
                },
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: InterText(
                    text: 'pawmap_report_pick_confirm'.tr,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
        : const Color(0xFFDC2626);
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
                          color: Colors.black.withValues(alpha: 0.30),
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

  /// Chip avec Switch compact (PawFollow / PawSpot), pleine largeur
  /// (maquette : fond blanc, bordure couleur, couronne 👑 si abonné).
  Widget _quickSwitchChip({
    required String label,
    IconData? icon,
    String? emoji,
    String? assetIcon, // v23.1.387 — logo PNG (nouveau logo PawFollow)
    bool coinIcon = false, // v447 — pièce dorée officielle PawSpot
    required Color accent,
    required bool subscribed,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final Color tone = subscribed ? accent : AppColors.greyText;
    // v449 — Daniel : « tout doit être lisible, rien de coupé ». 3 chips sur
    // une ligne (PawFollow / PawSpot / PawPremium). On resserre logo + switch
    // et on rend le LIBELLÉ via FittedBox(scaleDown) → la marque s'affiche
    // TOUJOURS en entier (jamais d'« … »), elle se réduit légèrement si la
    // largeur du chip est trop juste. Le Switch Material garde une emprise de
    // ~52 px même mis à l'échelle 0.52 ; on la borne dans un SizedBox pour
    // libérer la place du libellé.
    const double switchBox = 30.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: subscribed
            ? accent.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: tone.withValues(alpha: 0.55), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // v447 — LOGO OFFICIEL : pièce dorée GoldenPawCoin (PawSpot),
          // sinon PNG officiel (PawFollow / PawPremium), grisé hors abo.
          if (coinIcon)
            Opacity(
              opacity: subscribed ? 1.0 : 0.55,
              child: GoldenPawCoin(size: 16.w),
            )
          else if (assetIcon != null)
            ColorFiltered(
              colorFilter: subscribed
                  ? const ColorFilter.mode(
                      Colors.transparent, BlendMode.multiply)
                  : const ColorFilter.matrix(<double>[
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0, 0, 0, 1, 0,
                    ]),
              child: Image.asset(assetIcon, width: 16.w, height: 16.w),
            )
          else
            Container(
              width: 16.w,
              height: 16.w,
              decoration: BoxDecoration(
                color: subscribed
                    ? accent
                    : AppColors.greyText.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: emoji != null
                  ? Center(
                      child: Text(emoji, style: TextStyle(fontSize: 9.sp)))
                  : Icon(icon, size: 11.sp, color: Colors.white),
            ),
          SizedBox(width: 3.w),
          // Libellé pleine lisibilité : FittedBox.scaleDown → jamais tronqué.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: InterText(
                text: label,
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w800,
                color: subscribed ? accent : const Color(0xFF1F2937),
                maxLines: 1,
              ),
            ),
          ),
          // Switch borné : emprise réduite pour ne pas voler la place du label.
          SizedBox(
            width: switchBox,
            child: Center(
              child: Transform.scale(
                scale: 0.52,
                child: AppSwitch(
                  value: value,
                  onChanged: onChanged,
                  accent: accent,
                ),
              ),
            ),
          ),
        ],
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
    final active = _pawSpotController.pawspotActive.value;
    if (active) {
      // v448 — Daniel : abonné, on/off MANUEL de la couche spots. ON → on
      // (ré)affiche les spots + légende ; OFF → on masque (mémorisé).
      if (_showPawSpots.value) {
        _showPawSpots.value = false;
        GetStorage().write('pawspot_layer_on', false);
      } else {
        _showPawSpots.value = true;
        GetStorage().write('pawspot_layer_on', true);
        await _pawSpotController.loadNearby(_currentCenter);
      }
      if (mounted) setState(() {});
      return;
    }
    // Pas abonné → popup « Abonnement requis » ; au retour, si l'abo vient
    // d'être pris, on allume la couche.
    final went = await _promptSubscriptionRequired(2);
    if (went && _pawSpotController.pawspotActive.value && mounted) {
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
    final active = _pawSpotController.pawspotActive.value ||
        await _pawSpotController.refreshBenefits();
    if (!active) {
      CustomSnackbar.showWarning(
        title: 'pawspot_subscribe_required'.tr,
        message: 'pawspot_shop_subtitle'.tr,
      );
      // v23.1.358 — Daniel : "je prends un abonnement mais ça ne passe pas
      // en ON". Au RETOUR de la boutique, on re-vérifie les benefits : si
      // l'abo (ou l'essai 7 j) vient d'être activé → switch ON automatique
      // + chargement des spots, sans que l'utilisateur ait à re-taper.
      await Get.to(() => const CoinShopScreen(initialTab: 2));
      final nowActive = await _pawSpotController.refreshBenefits();
      if (nowActive && mounted) {
        _showPawSpots.value = true;
        GetStorage().write('pawspot_layer_on', true);
        await _pawSpotController.loadNearby(_currentCenter);
      }
      return;
    }
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
    try {
      final route = await _pawSpotController.fetchDirections(
        from: from,
        to: dest,
      );
      if (!mounted) return;
      if (route.points.length < 2) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'pawmap_snack_search_failed_msg'.tr,
        );
        return;
      }
      setState(() {
        _routePolylines = {
          Polyline(
            polylineId: const PolylineId('pawspot_route'),
            points: route.points,
            color: const Color(0xFFEF4324),
            width: 5,
          ),
        };
        _routeDistanceMeters = route.distanceMeters;
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
        final ctl = await _mapCtl.future;
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
  void _clearRoute() {
    setState(() {
      _routePolylines = {};
      _routeDistanceMeters = null;
    });
  }

  /// Bandeau flottant bas : distance du trajet + bouton "Effacer".
  Widget _buildDirectionsBanner() {
    final meters = _routeDistanceMeters;
    final distanceLabel = meters == null
        ? '—'
        : meters >= 1000
            ? '${(meters / 1000).toStringAsFixed(1)} km'
            : '$meters m';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: const Color(0xFFEF4324).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_walk_rounded,
              size: 16.sp, color: const Color(0xFFEF4324)),
          SizedBox(width: 6.w),
          InterText(
            text: distanceLabel,
            fontSize: 13.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1F2937),
          ),
          SizedBox(width: 12.w),
          GestureDetector(
            onTap: _clearRoute,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4324).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: InterText(
                text: 'directions_clear'.tr,
                fontSize: 11.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFEF4324),
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
            if (poi.phone.isNotEmpty)
              _iconLine(Icons.phone_outlined, poi.phone),
            if (poi.openingHours.isNotEmpty)
              _iconLine(Icons.schedule_outlined, poi.openingHours),
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
                      size: 14.sp, color: AppColors.greyText),
                  SizedBox(width: 4.w),
                  InterText(
                    text: 'pawmap_confirmations_inline'.trParams({'count': report.confirmationsCount.toString()}),
                    fontSize: 11.sp,
                    color: AppColors.greyText,
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
          Icon(icon, size: 16.sp, color: AppColors.greyText),
          SizedBox(width: 6.w),
          Expanded(child: InterText(text: text, fontSize: 12.sp)),
        ],
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

