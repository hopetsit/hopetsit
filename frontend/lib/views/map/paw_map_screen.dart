import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/friend_controller.dart';
import 'package:hopetsit/controllers/map_report_controller.dart';
import 'package:hopetsit/controllers/map_boost_controller.dart';
import 'package:hopetsit/controllers/paw_map_controller.dart';
import 'package:hopetsit/controllers/subscription_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/models/map_poi_model.dart';
import 'package:hopetsit/models/map_report_model.dart';
import 'package:hopetsit/models/nearby_request_model.dart';
import 'package:hopetsit/services/friend_marker_service.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/services/location_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/views/friends/friends_screen.dart';
import 'package:hopetsit/views/friends/people_live_screen.dart';
import 'package:hopetsit/views/map/alerts_screen.dart';
import 'package:hopetsit/views/map/report_category_grid_screen.dart';
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
  static bool _aroundYouDismissedSession = false;
  late final RxBool _aroundYouVisible =
      (!_aroundYouDismissedSession).obs;

  // v23.1.190 — Daniel : "pour les signalement au lieu de halo rouge
  // emoji du signalement". Cache BitmapDescriptor par type de report,
  // pre-calcule a partir des emojis (ReportTypes.emoji). _buildMarkers
  // consulte ce cache pour rendre des markers emoji ronds au lieu des
  // pins teardrop colorés.
  final Map<String, BitmapDescriptor> _reportEmojiMarkers = {};
  bool _emojiMarkersReady = false;
  final RxBool _showReports = true.obs;
  final RxBool _showFriends = true.obs;
  final RxBool _showRequests = true.obs;

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

  /// Synchronous premium check — reads the current subscription status if
  /// the controller is registered. Used to gate the _PremiumUpsell banner
  /// without an Obx wrapper (which was firing the "improper use of GetX"
  /// warning on first render).
  bool _isUserPremium() {
    if (!Get.isRegistered<SubscriptionController>()) return false;
    final sub = Get.find<SubscriptionController>();
    return sub.status.value?.isPremium ?? false;
  }

  @override
  void initState() {
    super.initState();
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
    // v23.1.163 — Daniel : "halo ne change pas de couleur selon option
    // pawspot". 2eme cause potentielle : MapBoostController n'etait
    // initialise QUE lors de la 1re visite de la boutique. Donc le
    // self-halo (qui lit mapBoostCtl.status.value.tier dans
    // _buildHaloCircles) ne fonctionnait pas tant que Daniel n'avait
    // pas ouvert la boutique → l'utilisateur ne voyait jamais son
    // propre halo PawSpot. Maintenant on force l'init au mount de
    // PawMap + on appelle loadStatus pour avoir le tier a jour.
    if (!Get.isRegistered<MapBoostController>()) {
      Get.put(MapBoostController());
    }
    Get.find<MapBoostController>().loadStatus();

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
    const types = [
      ReportTypes.lostPet,
      ReportTypes.aggressiveDog,
      ReportTypes.hazard,
      ReportTypes.waterActive,
      ReportTypes.waterBroken,
      ReportTypes.foundPet,
      ReportTypes.poop,
      ReportTypes.deadAnimal,
      ReportTypes.other,
    ];
    for (final t in types) {
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

  /// Renders a circular white-bg marker with the emoji centered inside.
  /// 120x120 pixels gives a crisp icon on retina screens. Returns a
  /// BitmapDescriptor ready to assign to Marker(icon: ...).
  Future<BitmapDescriptor> _buildEmojiBitmap(String emoji) async {
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

    // Cercle blanc.
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 2, bgPaint);
    // Anneau orange brand fin.
    final ringPaint = Paint()
      ..color = const Color(0xFFEF4324)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
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
    _reloadDebounce?.cancel();
    _haloTimer?.cancel();
    _followWorker?.dispose();
    _liveMap.stopBroadcasting();
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
                border: InputBorder.none,
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
    if (userPos != null) {
      final phase = _haloPhase.value;
      final userRadius = 25.0 + 75.0 * phase; // 25 → 100 m
      final userOpacity = (0.55 * (1.0 - phase)).clamp(0.0, 1.0);
      const userBlue = Color(0xFF1A73E8);
      circles.add(
        Circle(
          circleId: const CircleId('user_halo_outer'),
          center: userPos,
          radius: userRadius,
          fillColor: userBlue.withValues(alpha: userOpacity * 0.4),
          strokeColor: userBlue.withValues(alpha: userOpacity),
          strokeWidth: 2,
        ),
      );
      // Solid inner dot (radius 8m) so on est sûr de voir un point bleu
      // même quand le pulse est à son apex (opacity faible).
      circles.add(
        Circle(
          circleId: const CircleId('user_halo_dot'),
          center: userPos,
          radius: 8,
          fillColor: userBlue,
          strokeColor: Colors.white,
          strokeWidth: 2,
        ),
      );
    }

    // v23.1.154 — Daniel : "les couleurs du halo pour pawspot marche pas".
    // 1) On affiche maintenant le halo de l'utilisateur lui-meme s'il a
    //    un map_boost actif (avant, il ne voyait que les halos des AUTRES
    //    providers — son halo n'apparaissait jamais sur sa propre carte).
    // 2) Tous les tiers ont desormais un halo distinct (pas seulement
    //    Platinum), avec une couleur ET un rayon specifiques au tier :
    //      bronze   → cuivre  (40m, petit)
    //      silver   → argent  (80m, moyen)
    //      gold     → dore    (120m, grand)
    //      platinum → ambre   (160m, le plus large) + halo le plus
    //                          intense (toujours l'effet "premium")
    final phase = _haloPhase.value; // 0..1

    Color tierColor(String tier) {
      switch (tier) {
        case 'bronze':
          return const Color(0xFFB87333); // cuivre
        case 'silver':
          return const Color(0xFFB0B0B0); // argent
        case 'gold':
          return const Color(0xFFFFD700); // dore jaune
        case 'platinum':
        default:
          return const Color(0xFFFFAA00); // ambre chaud
      }
    }

    double tierMaxRadius(String tier) {
      switch (tier) {
        case 'bronze':
          return 40.0;
        case 'silver':
          return 80.0;
        case 'gold':
          return 120.0;
        case 'platinum':
        default:
          return 160.0;
      }
    }

    // — Self-halo : le user voit son propre halo s'il a un map_boost actif.
    final mapBoostCtl = Get.isRegistered<MapBoostController>()
        ? Get.find<MapBoostController>()
        : null;
    final mapBoostStatus = mapBoostCtl?.status.value;
    final selfTier = mapBoostStatus?.tier?.toLowerCase();
    if (userPos != null &&
        mapBoostStatus != null &&
        mapBoostStatus.isActive &&
        selfTier != null &&
        selfTier.isNotEmpty) {
      final selfColor = tierColor(selfTier);
      final selfMax = tierMaxRadius(selfTier);
      final selfRadius = 30.0 + (selfMax - 30.0) * phase;
      final selfOpacity = (0.55 * (1.0 - phase)).clamp(0.0, 1.0);
      circles.add(
        Circle(
          circleId: const CircleId('self_pawspot_halo'),
          center: userPos,
          radius: selfRadius,
          fillColor: selfColor.withValues(alpha: selfOpacity * 0.5),
          strokeColor: selfColor.withValues(alpha: selfOpacity),
          strokeWidth: 2,
        ),
      );
    }

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
    if (!_isSitterOrWalker && _showProviders.value) {
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
      final roleColor = role == 'walker'
          ? const Color(0xFF16A34A) // vert walker
          : role == 'sitter'
              ? const Color(0xFF2563EB) // bleu sitter
              : const Color(0xFFEF4324); // orange owner (fallback)
      circles.add(
        Circle(
          circleId: CircleId('halo_role_$id'),
          center: LatLng(lat, lng),
          radius: 25,
          fillColor: roleColor.withValues(alpha: 0.22),
          strokeColor: roleColor.withValues(alpha: 0.9),
          strokeWidth: 3,
        ),
      );

      // Halo tier (pulsant) - couleur + rayon depend du tier - seulement
      // pour les providers avec PawSpot actif (par-dessus l'anneau role).
      final isMapBoosted = p['isMapBoosted'] == true;
      if (!isMapBoosted) continue;
      final mapTier = (p['mapBoostTier'] ?? '').toString();
      final color = tierColor(mapTier);
      final maxRadius = tierMaxRadius(mapTier);
      final radius = 30.0 + (maxRadius - 30.0) * phase;
      final opacity = (0.45 * (1.0 - phase)).clamp(0.0, 1.0);
      final fill = color.withValues(alpha: opacity * 0.55);
      final stroke = color.withValues(alpha: opacity);
      circles.add(
        Circle(
          circleId: CircleId('halo_$id'),
          center: LatLng(lat, lng),
          radius: radius,
          fillColor: fill,
          strokeColor: stroke,
          strokeWidth: 2,
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
      const silver = Color(0xFFC0C0C0);
      const familyViolet = Color(0xFF8B5CF6);

      for (final pos in _liveMap.friendPositions.values) {
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
        Color color;
        String tag;
        if (isFamily) {
          color = familyViolet;
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
          color = silver;
          tag = 'friend';
        }
        // Halo UNIQUE — violet si famille, sinon couleur du role. Centre =
        // position LIVE -> il se deplace avec la personne (suivi a la trace).
        circles.add(
          Circle(
            circleId: CircleId('${tag}_halo_${pos.userId}'),
            center: LatLng(pos.latitude, pos.longitude),
            radius: 60,
            fillColor: color.withValues(alpha: 0.18),
            strokeColor: color.withValues(alpha: 0.7),
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
    ].join('-');
    if (_cachedMarkers == null || _cachedMarkersKey != key) {
      _cachedMarkers = _buildMarkers();
      _cachedMarkersKey = key;
    }
    return _cachedMarkers!;
  }

  Set<Marker> _buildMarkers() {
    final Set<Marker> markers = {};
    // v23.1 part 72 — Bug 10 : render nearby providers (owner side).
    // Boosted (isMapBoosted) get gold hue ; non-boosted get role color.
    if (_showProviders.value && !_isSitterOrWalker) {
      // v23.1.276 — dédup marqueurs : un provider qui est aussi un ami live ne
      // reçoit PAS de pin provider — son marqueur ami (avatar) le représente.
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
        if (friendLiveIds.contains(id.trim().toLowerCase())) continue;
        final role = (p['_role'] ?? 'walker').toString();
        final name = (p['name'] ?? '').toString();
        final isMapBoosted = p['isMapBoosted'] == true;
        final isBoosted = p['isBoosted'] == true;
        final mapTier = (p['mapBoostTier'] ?? '').toString();

        // v23.1.152 — Daniel : "tout marche sauf la couluer des paw spot,
        // pawspot dore etc". Avant : hueYellow (60) etait pale et hueAzure
        // (210) pour bronze ne ressemblait pas a du bronze. Refondu avec
        // des hues bruts pour avoir des pins visuellement coherents avec
        // leur nom :
        //   bronze   (24h)   → 15  (rouge-cuivre, evoque bronze)
        //   silver   (7j)    → 195 (gris-bleu, evoque argent)
        //   gold     (15j)   → 45  (ambre dore, vraiment dore)
        //   platinum (30j)   → 30  (orange chaud) + halo anime
        double hue;
        if (isMapBoosted) {
          switch (mapTier) {
            case 'platinum':
              hue = 30.0; // orange chaud
              break;
            case 'gold':
              hue = 45.0; // ambre dore (vrai gold)
              break;
            case 'silver':
              hue = 195.0; // bleu-gris argent
              break;
            case 'bronze':
            default:
              hue = 15.0; // rouge-cuivre
          }
        } else {
          hue = role == 'walker'
              ? BitmapDescriptor.hueGreen
              : BitmapDescriptor.hueAzure;
        }
        final tierLabel = isMapBoosted
            ? ({
                'bronze': 'mapboost_marker_bronze'.tr,
                'silver': 'mapboost_marker_silver'.tr,
                'gold': 'mapboost_marker_gold'.tr,
                'platinum': 'mapboost_marker_platinum'.tr,
              }[mapTier] ?? 'mapboost_marker_active'.tr)
            : (isBoosted ? 'mapboost_marker_profile_boosted'.tr : '');

        markers.add(
          Marker(
            markerId: MarkerId('provider_${role}_$id'),
            position: LatLng(lat, lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(hue),
            infoWindow: InfoWindow(
              title: '${role == 'walker' ? '🐕' : '🐾'} ${name.isNotEmpty ? name : (role == 'walker' ? 'pawmap_default_walker'.tr : 'pawmap_default_sitter'.tr)}'
                  '${isMapBoosted ? ' ⭐' : (isBoosted ? ' 🚀' : '')}',
              snippet: tierLabel,
            ),
          ),
        );
      }
    }
    if (_showPois.value) {
      for (final poi in _poiController.visiblePois) {
        markers.add(
          Marker(
            markerId: MarkerId('poi_${poi.id}'),
            position: LatLng(poi.latitude, poi.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(
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
    if (_showReports.value) {
      for (final r in _reportController.reports) {
        if (r.isExpired) continue;
        // v23.1.190 — Daniel : "pour les signalement au lieu de halo
        // rouge emoji du signalement". On pioche dans le cache emoji
        // pre-calcule, fallback sur le pin teardrop coloré si pas
        // encore pret (pendant le pre-warm initial).
        final emojiIcon = _reportEmojiMarkers[r.type];
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
      for (final pos in _liveMap.friendPositions.values) {
        final friend = friendById[pos.userId];
        // v23.1 part 240 — autorise aussi l'affichage du focusUserId (sitter
        // ou walker depuis un chat) meme s'il n'est pas dans la liste
        // d'amis. Sinon Daniel voit le halo sans le pin → confusion.
        final isFocus =
            (widget.focusUserId ?? '').isNotEmpty && pos.userId == widget.focusUserId;
        if (friend == null && !isFocus) continue;
        final displayName = friend?.other!.name ??
            widget.focusUserName ??
            '—';
        // v249 — choix du role + avatar.
        final role = (friend?.other?.model ?? pos.role).toLowerCase();
        final avatarUrl = friend?.other?.avatar ?? '';
        final isFamily = familyMemberIds.contains(
          pos.userId.trim().toLowerCase(),
        );
        final icon = _friendMarkerService.getOrPlaceholder(
          userId: pos.userId,
          avatarUrl: avatarUrl,
          role: role,
          isFamily: isFamily,
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

  double _hueForRole(String role) {
    switch (role) {
      // Owners get the rose/pink pin on the map to distinguish them
      // visually from sitters (blue) and walkers (green). This also
      // mirrors the "mon animal en rose" UX requested for owners.
      case 'owner':
        return BitmapDescriptor.hueRose;
      case 'sitter':
        return BitmapDescriptor.hueBlue;
      case 'walker':
        return BitmapDescriptor.hueGreen;
      default:
        return BitmapDescriptor.hueMagenta;
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
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        title: Row(
          children: [
            Text('🗺️', style: TextStyle(fontSize: 20.sp)),
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
      body: Column(
        children: [
          // v21.1.1 — Banner "Live actif" : visible quand l'user broadcast
          // sa position. Met en valeur PawFollow + permet stop rapide.
          _buildLiveBroadcastBanner(),

          // v23.1.184 — Daniel : "je veux que tu reorganise la paw map
          // dans ce style" (mockup avec 4 grosses cartes colorees Suivre
          // / Famille & Amis / Alertes / Signaler). Remplace les anciens
          // _buildQuickSignalRow + _buildEmergencyRow qui faisaient
          // doublon avec le FAB et chargeaient l'ecran.
          _buildQuickActionsRow(),

          // Layer toggle row (POIs / Reports)
          _buildLayerRow(),

          // Category chips (POIs filter)
          SizedBox(
            height: 48.h,
            child: Obx(() {
              // `.toSet()` forces a synchronous read of the RxSet's contents
              // inside the Obx builder. Without it, GetX reports "improper
              // use of GetX" because the real lookups (.isEmpty / .contains)
              // happen in the itemBuilder closure, which runs outside the
              // builder's reactive scope.
              final active = _poiController.enabledCategories.toSet();
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                itemCount: PoiCategories.all.length + 1,
                separatorBuilder: (_, __) => SizedBox(width: 8.w),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    final isAll = active.isEmpty;
                    return _Chip(
                      // v23.1.147 — fix i18n : "Tous" hardcodé FR → .tr.
                      label: 'paw_map_filter_all'.tr,
                      emoji: '✨',
                      selected: isAll,
                      onTap: _poiController.clearFilters,
                    );
                  }
                  final cat = PoiCategories.all[i - 1];
                  return _Chip(
                    label: PoiCategories.label(cat),
                    emoji: PoiCategories.emoji(cat),
                    selected: active.contains(cat),
                    onTap: () => _poiController.toggleCategory(cat),
                  );
                },
              );
            }),
          ),

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
                      final _famLen = fc?.familyMembers.length ?? 0;
                      // ignore: unused_local_variable
                      final _friLen = fc?.friends.length ?? 0;
                    } catch (_) {/* defensive */}
                    // v23.1 part 249 — rebuild quand un nouveau marker
                    // custom (photo profil) finit de generer. Sans cette
                    // dependance Obx, le marker reste sur le placeholder
                    // par defaut jusqu'a la prochaine vraie data change.
                    // ignore: unused_local_variable
                    final _markerRev = _friendMarkerService.rev.value;
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
                Positioned(
                  left: 12.w,
                  top: 80.h,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_isUserPremium())
                        _buildMapCornerButton(
                          color: const Color(0xFFF5A623),
                          icon: Icons.star_rounded,
                          tooltip: 'PawFollow',
                          onTap: () =>
                              Get.to(() => const CoinShopScreen(initialTab: 1)),
                        ),
                      if (!_isUserPremium()) SizedBox(height: 8.h),
                      _buildMapCornerButton(
                        color: const Color(0xFF2196F3),
                        icon: Icons.location_on_rounded,
                        tooltip: 'PawSpot',
                        onTap: () =>
                            Get.to(() => const CoinShopScreen(initialTab: 2)),
                      ),
                    ],
                  ),
                ),

                // Barre de recherche ville (gauche) + bouton géoloc (droite)
                // en haut de la map. Les deux sont visibles en permanence
                // pour un accès rapide.
                // v23.1.189 — Daniel : "geolocalicasation + et -" plus
                // modernes. La search-bar est seule sur la 1ere ligne ;
                // les boutons + / - / geoloc sont regroupes dans un
                // pill vertical blanc plein a droite (style Google Maps
                // moderne) avec un divider fin entre chaque action.
                Positioned(
                  top: 12.h,
                  left: 12.w,
                  right: 12.w,
                  child: _buildCitySearchBar(context),
                ),
                Positioned(
                  top: 74.h,
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
                Positioned(
                  right: 12.w,
                  bottom: 24.h,
                  child: _buildReportFab(),
                ),

                // v23.1.187 — Daniel mockup : carte "Autour de vous" flottante
                // en bas de la PawMap. Liste compacte des 3 signalements les
                // plus proches avec badge severite + tap → AlertsScreen.
                Positioned(
                  left: 12.w,
                  right: 12.w,
                  bottom: 12.h,
                  child: _buildAroundYouCard(),
                ),
              ],
            ),
          ),
        ],
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

  Widget _buildZoomBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(8.w),
          child: Icon(icon, color: AppColors.primaryColor, size: 22.sp),
        ),
      ),
    );
  }

  // ─── Suivi live d'un ami (v23.1.263) ────────────────────────────────────
  /// Recentre la caméra sur [target]. Marque le mouvement comme "programmatique"
  /// pendant ~800 ms pour que onCameraMoveStarted ne coupe pas le suivi.
  Future<void> _animateFollowCamera(LatLng target, {double? zoom}) async {
    if (!_mapCtl.isCompleted) return;
    final ctl = await _mapCtl.future;
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

  Future<void> _zoomIn() async {
    if (!_mapCtl.isCompleted) return;
    final ctl = await _mapCtl.future;
    // Zoomer ne doit pas couper le suivi en cours.
    if (_followUserId != null) _suppressFollowAutoStop = true;
    await ctl.animateCamera(CameraUpdate.zoomIn());
    if (_followUserId != null) {
      Future.delayed(const Duration(milliseconds: 800),
          () => _suppressFollowAutoStop = false);
    }
  }

  Future<void> _zoomOut() async {
    if (!_mapCtl.isCompleted) return;
    final ctl = await _mapCtl.future;
    if (_followUserId != null) _suppressFollowAutoStop = true;
    await ctl.animateCamera(CameraUpdate.zoomOut());
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
      final top = list.take(3).toList();
      return Container(
        padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(18.r),
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
            SizedBox(height: 8.h),
            ...top.map((r) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.h),
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
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 6.h),
      // v23.1.191 — Daniel : "les gros icone doive etre toute lissible
      // et de la meme taille". IntrinsicHeight force les 4 Expanded a
      // adopter la hauteur de la plus grande card (Famille & Amis qui
      // wrap sur 2 lignes) → toutes les cards identiques.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // v23.1 part 243 — Daniel : "met juste un titre par bouton cour
          // quon comprene et que ce sois traducible ds tte les langue".
          // Sublabels supprimes, labels raccourcis a 1 mot par bouton.
          //
          // 1. Suivre — toggle broadcast (= je partage ma position aux
          // amis qui peuvent me suivre). Etat actif → vert + icon plein.
          Expanded(
            child: Obx(() {
              final on = _liveMap.broadcasting.value;
              return _quickActionCard(
                icon: on
                    ? Icons.gps_fixed_rounded
                    : Icons.location_searching_rounded,
                // v23.1 part 243 — un seul label qui change selon l'etat.
                label: on
                    ? 'pawmap_quick_follow_on'.tr
                    : 'pawmap_quick_follow'.tr,
                color: on
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFEF4324),
                onTap: _toggleBroadcast,
                // v23.1.273 — "Me suivre" sur une seule ligne.
                maxLines: 1,
              );
            }),
          ),
          SizedBox(width: 8.w),
          // 2. Famille & Amis — ouvre FriendsScreen.
          // v23.1.255 — badge avec le nombre de demandes d'amis en attente
          // (FriendController.incomingRequests). Obx → se met à jour en
          // temps réel quand une demande arrive (socket friend_request:received).
          Expanded(
            child: Obx(() {
              final pending = _friendController.incomingRequests.length;
              return _quickActionCard(
                icon: Icons.people_alt_rounded,
                label: 'pawmap_quick_family'.tr,
                color: const Color(0xFF8B5CF6),
                badgeCount: pending,
                onTap: () => Get.to(() => const FriendsScreen()),
              );
            }),
          ),
          SizedBox(width: 8.w),
          // 3. Personnes live position — screen autonome PeopleLiveScreen.
          Expanded(
            child: _quickActionCard(
              icon: Icons.gps_fixed_rounded,
              label: 'pawmap_quick_people_live'.tr,
              color: const Color(0xFF10B981),
              onTap: () => Get.to(() => const PeopleLiveScreen()),
            ),
          ),
          SizedBox(width: 8.w),
          // 4. Alertes — ouvre l'ecran AlertsScreen dedie.
          Expanded(
            child: _quickActionCard(
              icon: Icons.notifications_active_rounded,
              label: 'pawmap_quick_alerts'.tr,
              color: const Color(0xFFF59E0B),
              onTap: () => Get.to(() => const AlertsScreen()),
            ),
          ),
          SizedBox(width: 8.w),
          // 5. Signaler — ouvre la grille 2x3 ReportCategoryGridScreen.
          Expanded(
            child: _quickActionCard(
              icon: Icons.add_circle_rounded,
              label: 'pawmap_quick_report'.tr,
              color: const Color(0xFFDC2626),
              onTap: () async {
                final created = await Get.to(
                  () => const ReportCategoryGridScreen(),
                );
                if (created == true) await _reloadAtCenter();
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// Carte unique du header — gros bloc carré arrondi avec icône blanche
  /// sur cercle coloré + label en gras.
  /// v23.1 part 243 — Daniel : "met juste un titre par bouton cour quon
  /// comprene et que ce sois traducible ds tte les langue". On supprime
  /// le sublabel (deuxieme ligne grisee en dessous) qui faisait double
  /// emploi avec le label principal et compliquait les traductions.
  /// Le param sublabel est conserve mais ignore — retro-compat des appels.
  Widget _quickActionCard({
    required IconData icon,
    required String label,
    String? sublabel,
    required Color color,
    required VoidCallback onTap,
    // v23.1.255 — Daniel : "badge 1 sur le quick bouton" pour les demandes
    // d'amis en attente. >0 → pastille rouge en coin haut-droit.
    int badgeCount = 0,
    // v23.1.273 — Daniel : "Me suivre sur une ligne". maxLines=1 + FittedBox
    // scaleDown → le label reste sur 1 ligne et la police se réduit au besoin.
    int maxLines = 2,
  }) {
    final card = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: onTap,
        child: Container(
          // v23.1 part 248 — Daniel : "les bouton quick action peux etre
          // reduit encore la police des titre pour que tt sois aligner et
          // lissible dand tte les langue". Padding horizontal reduit
          // (6 -> 4) pour donner plus de place au texte ; vertical
          // legerement reduit (12 -> 10) pour cards plus compactes.
          padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 4.w),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: color.withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.10),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            // v23.1.191 — IntrinsicHeight parent uniformise les hauteurs ;
            // on centre verticalement le contenu pour que toutes les
            // cards aient leur icone + label aligne meme si elles
            // n'ont pas le meme nombre de lignes de label.
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // v23.1 part 248 — cercle icone 38 -> 34 + icon 20 -> 18
              // pour laisser plus de place au label en langues longues
              // (allemand "Warnungen", italien "Avvisi").
              Container(
                width: 34.w,
                height: 34.w,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 18.sp),
              ),
              SizedBox(height: 5.h),
              // v248 — police 12 -> 10.5 (compromis lisibilite / parite
              // visuelle entre les 5 langues). minFontSize via FittedBox
              // pour eviter le wrap quand la traduction depasse de 1-2 px.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: InterText(
                  text: label,
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w800,
                  color: color,
                  maxLines: maxLines,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (badgeCount <= 0) return card;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        Positioned(
          top: -5,
          right: -3,
          child: Container(
            width: 18.w,
            height: 18.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4324),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: InterText(
              text: badgeCount > 9 ? '9+' : '$badgeCount',
              fontSize: 9.5.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickSignalRow() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Row(
        children: [
          Expanded(
            child: _quickSignalChip(
              emoji: '🔎',
              label: 'pawmap_filter_lost'.tr,
              type: ReportTypes.lostPet,
              color: const Color(0xFFEC407A), // rose/pink for lost_pet
            ),
          ),
          SizedBox(width: 8.w),
          // Session v3.2 — "Trouvé" remplacé par "Chien méchant" dans les
          // quick-signals (found_pet passé Premium, aggressive_dog en free).
          Expanded(
            child: _quickSignalChip(
              emoji: '😾',
              label: 'pawmap_filter_aggressive_dog'.tr,
              type: ReportTypes.aggressiveDog,
              color: const Color(0xFFE53935), // red for aggressive_dog
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _quickSignalChip(
              emoji: '🚰',
              label: 'pawmap_filter_water_point'.tr,
              type: ReportTypes.waterActive,
              color: const Color(0xFF26C6DA), // cyan for water_active
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickSignalChip({
    required String emoji,
    required String label,
    required String type,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () async {
            final created = await CreateReportSheet.show(
          context,
          initialPoint: _currentCenter,
          preselectedType: type,
        );
        if (created) await _reloadAtCenter();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: color.withValues(alpha: 0.30), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: TextStyle(fontSize: 16.sp)),
            SizedBox(width: 6.w),
            Flexible(
              child: InterText(
                text: label,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: color,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Session v3.3 — Emergency quick-access row.
  ///
  /// Gros boutons colorés qui filtrent la PawMap sur une catégorie POI en
  /// un seul tap (utile quand on cherche un véto / une animalerie en
  /// urgence). Tap bascule le filtre ; retap = reset.
  Widget _buildEmergencyRow() {
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 8.h),
      child: Row(
        children: [
          Expanded(
            child: _emergencyChip(
              emoji: '🏥',
              label: 'map_emergency_vet'.tr,
              category: PoiCategories.vet,
              color: const Color(0xFFE53935), // red — urgent medical
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _emergencyChip(
              emoji: '🛍️',
              label: 'map_emergency_shop'.tr,
              category: PoiCategories.shop,
              color: const Color(0xFF8E24AA), // purple — pet supplies
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _emergencyChip(
              emoji: '🌳',
              label: 'map_emergency_park'.tr,
              category: PoiCategories.park,
              color: const Color(0xFF2E7D32), // green — parks
            ),
          ),
        ],
      ),
    );
  }

  /// Single emergency chip — tap toggles a single-category filter on the
  /// PawMap (so only those POIs remain visible) and ensures the POI layer
  /// is shown. Retap the active chip to clear the filter.
  Widget _emergencyChip({
    required String emoji,
    required String label,
    required String category,
    required Color color,
  }) {
    return Obx(() {
      final active = _poiController.enabledCategories.length == 1 &&
          _poiController.enabledCategories.contains(category);
      return GestureDetector(
        onTap: () async {
          if (active) {
            _poiController.clearFilters();
          } else {
            _poiController.enabledCategories
              ..clear()
              ..add(category);
          }
          // Ensure the POI layer itself is on so the filter takes effect.
          _showPois.value = true;
          // Reload nearby POIs at the current center for this category so
          // the user sees results even before panning the map.
          {
            await _poiController.loadNearby(
              _currentCenter,
              category: active ? null : category,
            );
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: active ? color : color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: active ? color : color.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: TextStyle(fontSize: 16.sp)),
              SizedBox(width: 6.w),
              Flexible(
                child: InterText(
                  text: label,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : color,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildLayerRow() {
    // Session v3.3 — single horizontal scroll with the active-reports count
    // now living inside the "Signalements" toggle so nothing overflows on
    // small screens (the old side-badge was clipping on a Galaxy device).
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Obx(() => _LayerToggle(
                  label: 'pawmap_filter_pois'.tr,
                  emoji: '📍',
                  active: _showPois.value,
                  onTap: () => _showPois.value = !_showPois.value,
                )),
            SizedBox(width: 8.w),
            Obx(() => _LayerToggle(
                  label: 'pawmap_filter_reports_48h'.tr,
                  emoji: '⚠️',
                  active: _showReports.value,
                  // Inline active-count pill — replaces the old side badge
                  // that was overflowing the row on narrow screens.
                  count: _reportController.reports
                      .where((r) => !r.isExpired)
                      .length,
                  onTap: () => _showReports.value = !_showReports.value,
                )),
            SizedBox(width: 8.w),
            Obx(() {
              // Read the RxBool explicitly to guarantee Obx registers a
              // reactive dependency (accessing .length on an RxMap doesn't
              // always trigger tracking).
              final active = _showFriends.value;
              final count = _liveMap.friendPositions.length;
              return _LayerToggle(
                label: 'pawmap_filter_friends'.tr,
                emoji: '👥',
                active: active,
                premiumBadge: true,
                count: count,
                onTap: () => _showFriends.value = !_showFriends.value,
              );
            }),
            if (_isSitterOrWalker) ...[
              SizedBox(width: 8.w),
              Obx(() => _LayerToggle(
                    label: 'pawmap_filter_requests'.tr,
                    emoji: '📣',
                    active: _showRequests.value,
                    count: _requests.length,
                    onTap: () => _showRequests.value = !_showRequests.value,
                  )),
            ],
          ],
        ),
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
  Widget _buildMapCornerButton({
    required Color color,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26.r),
        child: Container(
          padding: EdgeInsets.fromLTRB(5.w, 5.h, 14.w, 5.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26.r),
            border: Border.all(
              color: color.withValues(alpha: 0.30),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
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
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.80)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.50),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 17.sp),
              ),
              SizedBox(width: 8.w),
              InterText(
                text: tooltip,
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// v21.1.1 — Banner "Live actif" qui apparaît au-dessus de la map quand
  /// l'user broadcast sa position. Met en valeur le PawFollow temps réel
  /// pour que le user comprenne qu'il est visible par ses amis.
  Widget _buildLiveBroadcastBanner() {
    return Obx(() {
      if (!_liveMap.broadcasting.value) return const SizedBox.shrink();
      return Container(
        margin: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 0),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF16A34A), Color(0xFF059669)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF16A34A).withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Pulsing live dot
            Container(
              width: 10.w,
              height: 10.w,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.7),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InterText(
                    text: 'pawmap_live_banner_title'.tr,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  SizedBox(height: 1.h),
                  InterText(
                    text: 'pawmap_live_banner_msg'.tr,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _toggleBroadcast,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: InterText(
                  text: 'pawmap_btn_stop'.tr,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // Premium users see all 9 types. The CreateReportSheet handles the per-type
  // lock UI and the final submit guard.
  Widget _buildReportFab() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryColor.withValues(alpha: 0.45),
            blurRadius: 18,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryColor,
        elevation: 6,
        icon: Icon(Icons.add_alert_rounded, color: Colors.white, size: 22.sp),
        label: InterText(
          text: 'pawmap_btn_send'.tr,
          fontSize: 14.sp,
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
        onPressed: () async {
                final created = await CreateReportSheet.show(
            context,
            initialPoint: _currentCenter,
          );
          if (created) await _reloadAtCenter();
        },
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
          ],
        ),
      ),
    );
  }

  // ─── Report details sheet ────────────────────────────────────────────────
  void _showReportBottomSheet(MapReport report) {
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
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final ok = await _reportController.confirm(report.id);
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

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryColor : AppColors.card(context),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: selected ? AppColors.primaryColor : AppColors.divider(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: TextStyle(fontSize: 14.sp)),
            SizedBox(width: 6.w),
            InterText(
              text: label,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textPrimary(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _LayerToggle extends StatelessWidget {
  const _LayerToggle({
    required this.label,
    required this.emoji,
    required this.active,
    required this.onTap,
    this.premiumBadge = false,
    this.count,
  });

  final String label;
  final String emoji;
  final bool active;
  final VoidCallback onTap;
  final bool premiumBadge;

  /// Optional inline count pill rendered to the right of the label. Used
  /// e.g. to show the number of active reports next to the "Signalements"
  /// toggle instead of as a separate badge that used to overflow the row.
  final int? count;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          // v23.1.278 — Daniel : "en mode dark on voit mal la barre sur la
          // PawMap". La GoogleMap reste TOUJOURS claire (pas de style sombre),
          // donc on FIXE les chips en surface CLAIRE (blanc + texte sombre)
          // dans les 2 modes, avec une ombre douce pour bien les détacher de
          // la carte — au lieu de couleurs adaptatives qui devenaient sombres
          // et incohérentes en dark mode.
          color: active
              ? AppColors.primaryColor.withValues(alpha: 0.14)
              : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: active ? AppColors.primaryColor : const Color(0xFFE0E0E0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: TextStyle(fontSize: 13.sp)),
            SizedBox(width: 6.w),
            InterText(
              text: label,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: active
                  ? AppColors.primaryColor
                  : const Color(0xFF1F2937),
            ),
            if (premiumBadge) ...[
              SizedBox(width: 4.w),
              Text('⭐', style: TextStyle(fontSize: 10.sp)),
            ],
            if (count != null && count! > 0) ...[
              SizedBox(width: 6.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: InterText(
                  text: '$count',
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

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

/// Premium upsell banner shown at the bottom of the PawMap for users who
/// haven't subscribed yet. Tapping opens the coin shop.
///
/// v18.9.8 — ancien design gold gradient remplacé par un vert vibrant avec
/// double glow (vert vif + halo blanc) pour matcher l'identité Premium =
/// accès vert-brillant selon spec Daniel.
class _PremiumUpsell extends StatelessWidget {
  const _PremiumUpsell();

  // Palette vert brillant (emerald) — saturé, lumineux, effet "shiny".
  static const Color _greenLight = Color(0xFF34D399); // emerald-400
  static const Color _greenMid = Color(0xFF10B981);   // emerald-500
  static const Color _greenDark = Color(0xFF059669);  // emerald-600

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Land directly on the Premium tab (index 1) since this banner is
      // specifically a Premium upsell. The default tab (0) is generic Boost.
      onTap: () => Get.to(() => const CoinShopScreen(initialTab: 1)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_greenLight, _greenMid, _greenDark],
            stops: [0.0, 0.55, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            // Glow principal vert saturé.
            BoxShadow(
              color: _greenMid.withValues(alpha: 0.55),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            // Halo intérieur blanc pour l'effet "brillant".
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, -1),
            ),
          ],
          // Léger liseré clair en haut pour accentuer le brillant.
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 24.sp),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InterText(
                    text: 'pawmap_premium_title'.tr,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  SizedBox(height: 2.h),
                  InterText(
                    text: 'pawmap_premium_subtitle'.tr,
                    fontSize: 12.sp,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16.sp),
          ],
        ),
      ),
    );
  }
}

/// Session v15-4 — Map Boost CTA on the PawMap, distinct from the Premium
/// banner (bleu vs vert) so the user sees they are two different products.
/// Tapping opens the shop directly on the Map Boost tab (index 2).
///
/// v18.9.8 — bleu rendu plus brillant (tricolor gradient + double shadow)
/// pour matcher la demande "bleu brillant" à côté du Signaler rouge.
class _MapBoostUpsell extends StatelessWidget {
  const _MapBoostUpsell();

  // Palette bleu vibrant — lumière sky-400 → blue-500 → indigo-600 pour
  // un effet "brillant/shiny" sans tomber dans le violet.
  static const Color _blueLight = Color(0xFF38BDF8); // sky-400
  static const Color _blueMid = Color(0xFF3B82F6);   // blue-500
  static const Color _blueDark = Color(0xFF1D4ED8);  // blue-700

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.to(() => const CoinShopScreen(initialTab: 2)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_blueLight, _blueMid, _blueDark],
            stops: [0.0, 0.55, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            // Glow principal bleu saturé.
            BoxShadow(
              color: _blueMid.withValues(alpha: 0.55),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            // Halo intérieur blanc pour l'effet "brillant".
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, -1),
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.push_pin_rounded, color: Colors.white, size: 22.sp),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InterText(
                    text: 'pawmap_boost_title'.tr,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  SizedBox(height: 2.h),
                  InterText(
                    text: 'pawmap_boost_subtitle'.tr,
                    fontSize: 12.sp,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white, size: 16.sp),
          ],
        ),
      ),
    );
  }
}
