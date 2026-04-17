import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/controllers/friend_controller.dart';
import 'package:hopetsit/controllers/map_report_controller.dart';
import 'package:hopetsit/controllers/paw_map_controller.dart';
import 'package:hopetsit/controllers/subscription_controller.dart';
import 'package:hopetsit/models/map_poi_model.dart';
import 'package:hopetsit/models/map_report_model.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/services/location_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
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
  LatLng? _currentCenter;

  /// Layer toggles — by default all 3 are visible.
  final RxBool _showPois = true.obs;
  final RxBool _showReports = true.obs;
  final RxBool _showFriends = true.obs;

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
    _bootstrap();
  }

  @override
  void dispose() {
    _liveMap.stopBroadcasting();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final loc = await LocationService().getCurrentLocation();
      LatLng center;
      if (loc != null) {
        center = LatLng(loc.latitude, loc.longitude);
      } else {
        // Fallback to Paris center so the map still renders.
        center = const LatLng(48.8566, 2.3522);
      }
      if (!mounted) return;
      setState(() => _currentCenter = center);
      await _reloadAtCenter();
    } catch (e) {
      debugPrint('[PawMap] bootstrap error: $e');
    }
  }

  Future<void> _reloadAtCenter() async {
    if (_currentCenter == null) return;
    await Future.wait([
      _poiController.loadNearby(_currentCenter!),
      _reportController.loadNearby(_currentCenter!),
    ]);
  }

  void _onCameraMove(CameraPosition pos) {
    _currentCenter = pos.target;
  }

  void _toggleBroadcast() {
    final sub = Get.isRegistered<SubscriptionController>()
        ? Get.find<SubscriptionController>()
        : null;
    final isPremium = sub?.isPremium ?? false;
    if (!isPremium) {
      CustomSnackbar.showError(
        title: 'Premium requis',
        message: 'Partager ta position en live est une fonctionnalité Premium.',
      );
      return;
    }
    if (_liveMap.broadcasting.value) {
      _liveMap.stopBroadcasting();
      CustomSnackbar.showSuccess(
        title: 'Position masquée',
        message: 'Tes amis ne te voient plus.',
      );
    } else {
      if (_currentCenter == null) return;
      _liveMap.startBroadcasting(() => _currentCenter ?? const LatLng(0, 0));
      CustomSnackbar.showSuccess(
        title: 'Position partagée',
        message: 'Tes amis te voient en temps réel.',
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
                  : PoiCategories.labelFr(poi.category),
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
    return markers;
  }

  double _hueForRole(String role) {
    switch (role) {
      case 'owner':
        return BitmapDescriptor.hueOrange;
      case 'sitter':
        return BitmapDescriptor.hueBlue;
      case 'walker':
        return BitmapDescriptor.hueGreen;
      default:
        return BitmapDescriptor.hueRose;
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
          // Live position broadcast toggle
          Obx(() {
            final on = _liveMap.broadcasting.value;
            return IconButton(
              tooltip: on ? 'Je suis visible' : 'Partager ma position',
              icon: Icon(
                on ? Icons.location_on : Icons.location_off,
                color: on ? Colors.green : AppColors.greyText,
              ),
              onPressed: _toggleBroadcast,
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
          // Layer toggle row (POIs / Reports)
          _buildLayerRow(),

          // Category chips (POIs filter)
          SizedBox(
            height: 48.h,
            child: Obx(() {
              final active = _poiController.enabledCategories;
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
                    label: PoiCategories.labelFr(cat),
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
                if (_currentCenter == null)
                  const Center(child: CircularProgressIndicator())
                else
                  Obx(() {
                    // Force rebuild when either list changes
                    _poiController.visiblePois.length;
                    _reportController.reports.length;
                    _showPois.value;
                    _showReports.value;
                    return GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _currentCenter!,
                        zoom: 13,
                      ),
                      onMapCreated: (c) {
                        if (!_mapCtl.isCompleted) _mapCtl.complete(c);
                      },
                      onCameraMove: _onCameraMove,
                      onCameraIdle: _reloadAtCenter,
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
                          color: Colors.black.withOpacity(0.7),
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

                // Premium upsell banner when the report API returns 402
                Obx(() {
                  if (!_reportController.premiumRequired.value) {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
                    left: 12.w,
                    right: 12.w,
                    bottom: 82.h,
                    child: _PremiumUpsell(),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildReportFab(),
    );
  }

  Widget _buildLayerRow() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
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
                premiumBadge: true,
                onTap: () => _showReports.value = !_showReports.value,
              )),
          SizedBox(width: 8.w),
          Obx(() => _LayerToggle(
                label: 'Amis',
                emoji: '👥',
                active: _showFriends.value,
                premiumBadge: true,
                onTap: () => _showFriends.value = !_showFriends.value,
              )),
          const Spacer(),
          Obx(() {
            final n = _reportController.reports
                .where((r) => !r.isExpired)
                .length;
            if (n == 0) return const SizedBox.shrink();
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: InterText(
                text: '$n actif(s)',
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Floating action button for creating reports ─────────────────────────
  Widget _buildReportFab() {
    final sub = Get.isRegistered<SubscriptionController>()
        ? Get.find<SubscriptionController>()
        : null;
    if (sub == null) return const SizedBox.shrink();
    return Obx(() {
      final isPremium = sub.isPremium;
      return FloatingActionButton.extended(
        backgroundColor:
            isPremium ? AppColors.primaryColor : Colors.grey.shade500,
        icon: Icon(isPremium ? Icons.add_alert : Icons.lock, color: Colors.white),
        label: InterText(
          text: isPremium ? 'Signaler' : 'Premium requis',
          fontSize: 13.sp,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        onPressed: () async {
          if (_currentCenter == null) return;
          if (!isPremium) {
            CustomSnackbar.showError(
              title: 'Premium requis',
              message: 'Passe Premium pour signaler et voir les signalements 48h.',
            );
            return;
          }
          final created = await CreateReportSheet.show(
            context,
            initialPoint: _currentCenter!,
          );
          if (created) await _reloadAtCenter();
        },
      );
    });
  }

  // ─── POI details sheet ───────────────────────────────────────────────────
  void _showPoiBottomSheet(MapPOI poi) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.all(20.w),
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
                    color: AppColors.primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: InterText(
                    text: PoiCategories.labelFr(poi.category),
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
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
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
                        if (!mounted) return;
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
                        if (!mounted) return;
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
  });

  final String label;
  final String emoji;
  final bool active;
  final VoidCallback onTap;
  final bool premiumBadge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primaryColor.withOpacity(0.12)
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
    final clampedMins = minutes < 0 ? 0 : minutes;
    final hours = clampedMins ~/ 60;
    final rem = clampedMins % 60;
    final String text = hours >= 1 ? '${hours}h${rem.toString().padLeft(2, '0')}' : '${rem}m';
    final bool urgent = minutes < 120; // < 2h left
    final Color color = urgent ? Colors.red : AppColors.primaryColor;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 10.sp, color: color),
          SizedBox(width: 3.w),
          InterText(
            text: text,
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ],
      ),
    );
  }
}

/// In-map banner shown to free users after we discover the report API
/// returns 402. Tapping it should open the boutique (TODO: wire a route).
class _PremiumUpsell extends StatelessWidget {
  const _PremiumUpsell();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFF9500)],
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text('⭐', style: TextStyle(fontSize: 24.sp)),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InterText(
                  text: 'Passe Premium',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                SizedBox(height: 2.h),
                InterText(
                  text: 'Vois les signalements 48h autour de toi + crée les tiens.',
                  fontSize: 11.sp,
                  color: Colors.white.withOpacity(0.95),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
