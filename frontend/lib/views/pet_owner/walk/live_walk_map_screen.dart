import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_endpoints.dart';
import 'package:hopetsit/services/socket_service.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Sprint 6 step 2 — owner watches a live walk on a map.
class LiveWalkMapScreen extends StatefulWidget {
  final String bookingId;
  const LiveWalkMapScreen({super.key, required this.bookingId});

  @override
  State<LiveWalkMapScreen> createState() => _LiveWalkMapScreenState();
}

class _LiveWalkMapScreenState extends State<LiveWalkMapScreen> {
  final ApiClient _api = Get.isRegistered<ApiClient>()
      ? Get.find<ApiClient>()
      : ApiClient();
  GoogleMapController? _mapController;
  LatLng? _current;
  String? _walkId;
  String _status = 'loading';

  @override
  void initState() {
    super.initState();
    _loadActive();
  }

  Future<void> _loadActive() async {
    try {
      final r = await _api.get(
        '${ApiEndpoints.walksActive}?bookingId=${widget.bookingId}',
        requiresAuth: true,
      );
      final walk = r is Map ? r['walk'] : null;
      if (walk is Map) {
        _walkId = (walk['_id'] ?? walk['id']).toString();
        final positions = (walk['positions'] as List?) ?? [];
        if (positions.isNotEmpty) {
          final last = positions.last as Map;
          _current = LatLng(
            (last['lat'] as num).toDouble(),
            (last['lng'] as num).toDouble(),
          );
        }
        _subscribeSocket();
        setState(() => _status = 'live');
      } else {
        setState(() => _status = 'no-active-walk');
      }
    } catch (e) {
      setState(() => _status = 'error: $e');
    }
  }

  void _subscribeSocket() {
    final sock = Get.isRegistered<SocketService>()
        ? Get.find<SocketService>()
        : null;
    final s = sock?.socket;
    if (s == null || _walkId == null) return;
    final profile = GetStorage().read<Map<String, dynamic>>(StorageKeys.userProfile);
    final role = GetStorage().read<String>(StorageKeys.userRole);
    s.emit('walk:join', {
      'walkId': _walkId,
      'role': role ?? 'owner',
      'userId': profile?['id']?.toString(),
    });
    s.off('walk.position');
    s.on('walk.position', (data) {
      if (data is Map && data['lat'] is num && data['lng'] is num) {
        final next = LatLng(
          (data['lat'] as num).toDouble(),
          (data['lng'] as num).toDouble(),
        );
        setState(() => _current = next);
        _mapController?.animateCamera(CameraUpdate.newLatLng(next));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: PoppinsText(
          text: 'Live walk',
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: _current == null
          ? Center(
              child: InterText(
                text: _status,
                fontSize: 14.sp,
                color: AppColors.textSecondary(context),
              ),
            )
          : GoogleMap(
              initialCameraPosition: CameraPosition(target: _current!, zoom: 16),
              onMapCreated: (c) => _mapController = c,
              markers: {
                Marker(
                  markerId: const MarkerId('sitter'),
                  position: _current!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure),
                ),
              },
            ),
    );
  }
}
