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
  // v23.1 part 209 — Daniel : "le bouton suivre mon animal apparait mais
  // jappuis dessus y me montre pas la map et le walker, ya une page
  // blanche pas de balade". Cause : `_loadActive` interroge /walks/active
  // qui ne retourne quelque chose QUE quand un walker a explicitement
  // pressé "Démarrer la balade". Or, accepter une demande PawFollow ne
  // crée PAS d'active walk → page vide.
  // Fix : on accepte un fallback lat/lng (snapshot pris par le backend au
  // moment de la création du message pawfollow_request — cf metadata
  // lastLat/lastLng). Si pas d'active walk, on affiche QUAND MEME la map
  // centrée sur cette position avec un pin "Dernière position connue".
  // Le subscribe socket reste actif → si le walker démarre à broadcast,
  // le pin se met à jour en temps réel.
  final double? fallbackLat;
  final double? fallbackLng;
  final String? contactName;

  const LiveWalkMapScreen({
    super.key,
    required this.bookingId,
    this.fallbackLat,
    this.fallbackLng,
    this.contactName,
  });

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
        // v23.1.182 — Daniel : "ecran noir et crash de lapp". Cause
        // racine du crash : cast non-safe `(walk['_id'] ?? walk['id']).toString()`
        // qui throw NoSuchMethodError sur null si la réponse n'a ni l'un
        // ni l'autre. Idem pour `(last['lat'] as num).toDouble()` qui
        // crash si lat manquant ou pas un num. Maintenant on est
        // défensif : si rien n'est utilisable → on bascule sur l'état
        // "no active" au lieu de crasher.
        final rawId = walk['_id'] ?? walk['id'];
        if (rawId == null) {
          if (!mounted) return;
          setState(() => _status = 'live_walk_no_active'.tr);
          return;
        }
        _walkId = rawId.toString();
        final positions = (walk['positions'] is List)
            ? (walk['positions'] as List)
            : const [];
        if (positions.isNotEmpty) {
          final last = positions.last;
          if (last is Map) {
            final lat = last['lat'];
            final lng = last['lng'];
            if (lat is num && lng is num) {
              _current = LatLng(lat.toDouble(), lng.toDouble());
            }
          }
        }
        _subscribeSocket();
        if (!mounted) return;
        setState(() => _status = 'live');
      } else {
        // v23.1 part 209 — Daniel : "page blanche pas de balade" quand
        // la demande PawFollow est acceptée mais que le walker n'a pas
        // explicitement démarré une "balade". On bascule sur le fallback
        // lat/lng snapshotté dans le metadata du message au lieu de
        // montrer un écran vide.
        if (widget.fallbackLat != null && widget.fallbackLng != null) {
          _current = LatLng(widget.fallbackLat!, widget.fallbackLng!);
          // On subscribe quand même au socket pour recevoir d'éventuelles
          // updates si le walker démarre à broadcast après-coup.
          _subscribeProviderBroadcastSocket();
          if (!mounted) return;
          setState(() => _status = 'live_walk_last_known'.tr);
          return;
        }
        // v23.1.162 — Daniel : 'no-active-walk' apparaissait brut. Cle i18n
        // 'live_walk_no_active' resolue via .tr (FR: 'Aucune balade en cours',
        // ES: 'Sin paseo activo', etc.).
        if (!mounted) return;
        setState(() => _status = 'live_walk_no_active'.tr);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '${'live_walk_error'.tr}: $e');
    }
  }

  // v23.1 part 209 — Subscribe à l'event socket que le walker/sitter émet
  // quand il broadcaste sa position en mode PawFollow (hors active walk).
  // Backend : voir live_map_service côté provider qui émet
  // `provider.position` sur le canal user_<ownerId>.
  void _subscribeProviderBroadcastSocket() {
    final sock = Get.isRegistered<SocketService>()
        ? Get.find<SocketService>()
        : null;
    final s = sock?.socket;
    if (s == null) return;
    s.off('provider.position');
    s.on('provider.position', (data) {
      if (data is Map && data['lat'] is num && data['lng'] is num) {
        final next = LatLng(
          (data['lat'] as num).toDouble(),
          (data['lng'] as num).toDouble(),
        );
        if (!mounted) return;
        setState(() => _current = next);
        _mapController?.animateCamera(CameraUpdate.newLatLng(next));
      }
    });
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
          // v23.1.162 — la cle live_walk_title est maintenant definie dans
          // les 6 fichiers de traduction. Le fallback FR 'Balade en direct'
          // n'est plus necessaire — .tr retourne toujours la bonne valeur.
          text: 'live_walk_title'.tr,
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
