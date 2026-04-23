import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/friend_controller.dart';
import 'package:hopetsit/controllers/map_report_controller.dart';
import 'package:hopetsit/controllers/paw_map_controller.dart';
import 'package:hopetsit/controllers/subscription_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/models/map_poi_model.dart';
import 'package:hopetsit/models/map_report_model.dart';
import 'package:hopetsit/models/nearby_request_model.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/services/location_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/views/friends/friends_screen.dart';
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
  const PawMapScreen({super.key});

  @override
  State<PawMapScreen> createState() => _PawMapScreenState();
}

class _PawMapScreenState extends State<PawMapScreen> {
  final Completer<GoogleMapController> _mapCtl = Completer();
  late final PawMapController _poiController;
  late final MapReportController _reportController;
  late final FriendController _friendController;
  late final LiveMapService _liveMap;
  // Paris fallback by default — guarantees the GoogleMap widget always has
  // a camera position on the very first frame, even before geolocation
  // resolves. This fixes the "need to tap twice to see the map" bug caused
  // by IndexedStack keeping the screen built-but-hidden.
  LatLng _currentCenter = const LatLng(48.8566, 2.3522);

  /// Layer toggles — by default all visible. The Demandes toggle is only
  /// rendered for sitter/walker roles (it stays true internally but the UI
  /// hides it for owners).
  final RxBool _showPois = true.obs;
  final RxBool _showReports = true.obs;
  final RxBool _showFriends = true.obs;
  final RxBool _showRequests = true.obs;

  /// Nearby reservation requests for the sitter/walker layer. Fetched in
  /// `_reloadAtCenter()` via `/posts/requests/nearby`. Empty for owner role.
  final RxList<NearbyRequestPost> _requests = <NearbyRequestPost>[].obs;

  /// Debounce the `onCameraIdle` callback so panning/zooming quickly doesn't
  /// fire 5+ POI/report requests in a row. 500 ms is short enough to feel
  /// instant but long enough to collapse a flick-zoom into one call.
  Timer? _reloadDebounce;

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
    _poiController = Get.isRegistered<PawMapController>()
        ? Get.find<PawMapController>()
        : Get.put(PawMapController());
    _reportController = Get.isRegistered<MapReportController>()
        ? Get.find<MapReportController>()
        : Get.put(MapReportController());
    _friendController = Get.isRegistered<FriendController>()
        ? Get.find<FriendController>()
        : Get.put(FriendController());
    _liveMap = Get.isRegistered<LiveMapService>()
        ? Get.find<LiveMapService>()
        : Get.put(LiveMapService(), permanent: true);
    _liveMap.attach();

    // Paris fallback is the initial value — the map renders immediately
    // and _bootstrap() upgrades to real location in the background.
    _bootstrap();
  }

  @override
  void dispose() {
    _reloadDebounce?.cancel();
    _liveMap.stopBroadcasting();
    _cityCtrl.dispose();
    super.dispose();
  }

  /// Search bar widget — typing a city name and submitting geocodes the
  /// query and recenters the map there.
  Widget _buildCitySearchBar(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14.r),
      elevation: 4,
      child: TextField(
        controller: _cityCtrl,
        textInputAction: TextInputAction.search,
        onSubmitted: _searchCity,
        decoration: InputDecoration(
          hintText: 'Chercher une ville…',
          hintStyle: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 13.sp,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20.sp,
            color: AppColors.textSecondary(context),
          ),
          suffixIcon: _cityCtrl.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, size: 18.sp),
                  onPressed: () {
                    _cityCtrl.clear();
                    setState(() {});
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
          isDense: true,
        ),
        onChanged: (_) => setState(() {}),
        style: TextStyle(fontSize: 13.sp),
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
          title: 'Ville introuvable',
          message: 'Aucune position trouvée pour "$trimmed".',
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
        title: 'Recherche impossible',
        message: 'Vérifiez votre connexion et réessayez.',
      );
    }
  }

  Future<void> _bootstrap() async {
    // Fire nearby loads immediately using the Paris fallback set in initState
    // so users see POIs/reports without waiting on geolocation.
    unawaited(_reloadAtCenter());

    // Then try to upgrade to the real user location with a hard timeout
    // (geolocation can hang forever on some devices / permission states).
    try {
      final loc = await LocationService()
          .getCurrentLocation()
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
      if (loc == null) return;
      final center = LatLng(loc.latitude, loc.longitude);
      if (!mounted) return;
      setState(() => _currentCenter = center);
      // Try to re-center the actual GoogleMap camera if it has already been
      // created (Completer resolves on onMapCreated).
      try {
        if (_mapCtl.isCompleted) {
          final ctl = await _mapCtl.future;
          await ctl.animateCamera(CameraUpdate.newLatLng(center));
        }
      } catch (_) {}
      await _reloadAtCenter();
    } catch (e) {
      debugPrint('[PawMap] bootstrap error: $e');
    }
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
    }
    await Future.wait(futures);
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
  void _toggleBroadcast() {
    if (_liveMap.broadcasting.value) {
      _liveMap.stopBroadcasting();
      CustomSnackbar.showSuccess(
        title: 'Suivi désactivé',
        message: 'Tes amis ne voient plus ta position.',
      );
    } else {
        _liveMap.startBroadcasting(() => _currentCenter);
      CustomSnackbar.showSuccess(
        title: 'Suivi activé',
        message: 'Tes amis voient ta position et celle de ton animal en live.',
      );
    }
  }

  // ─── Marker building ─────────────────────────────────────────────────────
  Set<Marker> _buildMarkers() {
    final Set<Marker> markers = {};
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
        markers.add(
          Marker(
            markerId: MarkerId('report_${r.id}'),
            position: LatLng(r.latitude, r.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(_hueForReport(r.type)),
            infoWindow: InfoWindow(
              title: '${ReportTypes.emoji(r.type)} ${ReportTypes.labelFr(r.type)}',
              snippet:
                  '${r.liveHoursRemaining.toStringAsFixed(0)}h restantes · ${r.confirmationsCount} confirmation(s)',
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
      for (final pos in _liveMap.friendPositions.values) {
        final friend = friendById[pos.userId];
        if (friend == null) continue; // Only show accepted friends.
        markers.add(
          Marker(
            markerId: MarkerId('friend_${pos.userId}'),
            position: LatLng(pos.latitude, pos.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(_hueForRole(pos.role)),
            infoWindow: InfoWindow(
              title: '👤 ${friend.other!.name}',
              snippet: 'Vu il y a ${_timeAgo(pos.at)}',
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
              title: '📣 ${req.ownerName.isNotEmpty ? req.ownerName : 'Demande'}',
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
                    title: 'Demande ouverte',
                    message:
                        'Retrouve l\'annonce complète dans l\'onglet Accueil.',
                  );
                },
                icon: const Icon(Icons.open_in_new, color: Colors.white),
                label: InterText(
                  text: 'Voir l\'annonce',
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
    if (diff.inMinutes < 1) return "à l'instant";
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    return '${diff.inDays} j';
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
          // "Suivre mon animal" — toggles the live-position broadcast for
          // the user. When on, friends see this user's pin moving on their
          // own PawMap. Rendered as a colored pill (not a plain icon) so
          // it stands out as the primary tracking action per Daniel's ask.
          Obx(() {
            final on = _liveMap.broadcasting.value;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 8.h),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _toggleBroadcast,
                  borderRadius: BorderRadius.circular(20.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: on
                          ? Colors.green.withValues(alpha: 0.15)
                          : AppColors.primaryColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: on
                            ? Colors.green
                            : AppColors.primaryColor.withValues(alpha: 0.50),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '🐾',
                          style: TextStyle(fontSize: 13.sp),
                        ),
                        SizedBox(width: 4.w),
                        InterText(
                          text: on ? 'Live' : 'Suivre',
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: on ? Colors.green : AppColors.primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          IconButton(
            tooltip: 'Mes amis',
            icon: const Icon(Icons.people_outline),
            onPressed: () => Get.to(() => const FriendsScreen()),
          ),
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh),
            onPressed: _reloadAtCenter,
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick-signal row — the 3 freemium report types are reachable
          // without even opening the Signaler FAB. Pushes conversion by
          // showing free users what they can do right away.
          _buildQuickSignalRow(),

          // Session v3.3 — "Urgence" quick-access row. Gros boutons qui
          // filtrent la PawMap sur une catégorie POI utile en situation
          // d'urgence (trouver un véto rapidement, une animalerie proche).
          _buildEmergencyRow(),

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
                      label: 'Tous',
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
                    return GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _currentCenter,
                        zoom: 13,
                      ),
                      onMapCreated: (c) {
                        if (!_mapCtl.isCompleted) _mapCtl.complete(c);
                      },
                      onCameraMove: _onCameraMove,
                      onCameraIdle: _scheduleReload,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      markers: _buildMarkers(),
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
                              text: 'Chargement…',
                              fontSize: 12.sp,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                // Premium upsell banner — shown statiquement pour tous les
                // utilisateurs free. Plus de Obx ici (ça déclenchait le
                // warning "[Get] improper use of GetX" chez certains users
                // quand les controllers n'étaient pas encore initialisés).
                // Le masquage pour Premium se fait via une simple check
                // synchrone lue depuis le SubscriptionController si présent.
                // Upsell stack : Premium (masqué si déjà abonné) + Map Boost
                // (toujours visible — Map Boost se vend aussi aux Premium qui
                // veulent utiliser leur crédit mensuel gratuit).
                Positioned(
                  left: 12.w,
                  right: 12.w,
                  bottom: 170.h,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_isUserPremium()) ...[
                        const _PremiumUpsell(),
                        SizedBox(height: 8.h),
                      ],
                      const _MapBoostUpsell(),
                    ],
                  ),
                ),

                // Barre de recherche ville (gauche) + bouton géoloc (droite)
                // en haut de la map. Les deux sont visibles en permanence
                // pour un accès rapide.
                Positioned(
                  top: 12.h,
                  left: 12.w,
                  right: 12.w,
                  child: Row(
                    children: [
                      Expanded(child: _buildCitySearchBar(context)),
                      SizedBox(width: 8.w),
                      Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 4,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _recenterOnUser,
                          child: Padding(
                            padding: EdgeInsets.all(11.w),
                            child: Icon(
                              Icons.my_location_rounded,
                              color: AppColors.primaryColor,
                              size: 22.sp,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // "Signaler" — disponible pour tous les rôles. Positionné
                // en Stack (pas en FAB) pour rester visible au-dessus de la
                // barre de navigation du StackedNavigationWrapper.
                Positioned(
                  right: 12.w,
                  bottom: 100.h,
                  child: _buildReportFab(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Recenters the GoogleMap camera on the user's current GPS location.
  Future<void> _recenterOnUser() async {
    try {
      final loc = await LocationService()
          .getCurrentLocation()
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
      if (loc == null) {
        CustomSnackbar.showWarning(
          title: 'Localisation indisponible',
          message: 'Activez le GPS et les permissions.',
        );
        return;
      }
      final center = LatLng(loc.latitude, loc.longitude);
      if (!mounted) return;
      setState(() => _currentCenter = center);
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
  Widget _buildQuickSignalRow() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Row(
        children: [
          Expanded(
            child: _quickSignalChip(
              emoji: '🔎',
              label: 'Perdu',
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
              label: 'Chien méchant',
              type: ReportTypes.aggressiveDog,
              color: const Color(0xFFE53935), // red for aggressive_dog
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _quickSignalChip(
              emoji: '🚰',
              label: 'Point d\'eau',
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
                  label: 'POIs',
                  emoji: '📍',
                  active: _showPois.value,
                  onTap: () => _showPois.value = !_showPois.value,
                )),
            SizedBox(width: 8.w),
            Obx(() => _LayerToggle(
                  label: 'Signalements 48h',
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
                label: 'Amis',
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
                    label: 'Demandes',
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
  // Post-freemium refactor: the FAB is always active. Free users can open the
  // sheet and pick among the 3 free types (lost_pet, found_pet, water_active).
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
          text: 'Signaler',
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
                    text: '${report.confirmationsCount} confirmation(s)',
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
                            title: 'Merci !',
                            message: 'Signalement prolongé de 12h.',
                          );
                        }
                      },
                      icon: Icon(Icons.check_circle_outline, size: 16.sp),
                      label: InterText(
                        text: 'Confirmer +12h',
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
                            title: 'Signalé',
                            message: 'Merci, un modérateur va vérifier.',
                          );
                        }
                      },
                      icon: Icon(Icons.flag_outlined,
                          size: 16.sp, color: Colors.red),
                      label: InterText(
                        text: 'Signaler abus',
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
          color: active
              ? AppColors.primaryColor.withValues(alpha: 0.12)
              : AppColors.card(context),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: active ? AppColors.primaryColor : AppColors.divider(context),
          ),
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
                  : AppColors.textPrimary(context),
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
