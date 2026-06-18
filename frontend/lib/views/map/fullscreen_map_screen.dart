import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/controllers/map_report_controller.dart';
import 'package:hopetsit/controllers/pawspot_controller.dart';
import 'package:hopetsit/models/map_report_model.dart';

/// v457 — Daniel : « agrandir la carte » EN VERSION SÛRE.
///
/// L'ancien mode « agrandir » (v451) cachait les contrôles AU-DESSUS de la
/// carte → la GoogleMap était REDIMENSIONNÉE en direct, ce qui faisait blanchir
/// le rendu natif Android (et a tout cassé). Ici on fait l'inverse : un écran
/// DÉDIÉ plein écran, totalement SÉPARÉ de la PawMap. Il ne touche donc jamais
/// à la PawMap qui marche → impossible de la recasser.
///
/// La carte plein écran est créée UNE fois, ne se redimensionne jamais, sans
/// aucun `Obx` autour de la GoogleMap → zéro risque de blanc ou de crash GetX.
/// Idéal pour marcher / conduire : grande carte + position en direct + zoom.
class FullScreenMapScreen extends StatefulWidget {
  const FullScreenMapScreen({super.key, required this.initialCenter});

  /// Centre initial (on réutilise le centre actuel de la PawMap).
  final LatLng initialCenter;

  @override
  State<FullScreenMapScreen> createState() => _FullScreenMapScreenState();
}

class _FullScreenMapScreenState extends State<FullScreenMapScreen> {
  // Marqueurs figés au moment de l'ouverture (pas de flux réactif → pas d'Obx,
  // pas de rebuild surprise). Suffisant pour un mode « voir la carte en grand ».
  late final Set<Marker> _markers = _buildMarkers();

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // PawSpots (si le contrôleur est chargé).
    if (Get.isRegistered<PawSpotController>()) {
      for (final s in Get.find<PawSpotController>().spots) {
        markers.add(
          Marker(
            markerId: MarkerId('fs_spot_${s.id}'),
            position: LatLng(s.lat, s.lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              s.isGolden ? BitmapDescriptor.hueYellow : BitmapDescriptor.hueAzure,
            ),
          ),
        );
      }
    }

    // Signalements (si le contrôleur est chargé).
    if (Get.isRegistered<MapReportController>()) {
      for (final r in Get.find<MapReportController>().reports) {
        if (r.latitude == 0 && r.longitude == 0) continue;
        markers.add(
          Marker(
            markerId: MarkerId('fs_report_${r.id}'),
            position: LatLng(r.latitude, r.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(_hueForReport(r.type)),
          ),
        );
      }
    }

    return markers;
  }

  double _hueForReport(String type) {
    switch (type) {
      case ReportTypes.hazard:
      case ReportTypes.aggressiveDog:
        return BitmapDescriptor.hueRed;
      case ReportTypes.waterActive:
        return BitmapDescriptor.hueCyan;
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
      body: Stack(
        children: [
          // Carte plein écran — UNE seule instance, jamais redimensionnée.
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initialCenter,
              zoom: 15,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            compassEnabled: true,
            mapToolbarEnabled: false,
          ),

          // Bouton « Réduire » (revient à la PawMap) — en haut à gauche, sous
          // la barre de statut.
          Positioned(
            top: MediaQuery.of(context).padding.top + 10.h,
            left: 12.w,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 4,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Get.back(),
                child: Padding(
                  padding: EdgeInsets.all(10.w),
                  child: Icon(Icons.fullscreen_exit_rounded,
                      size: 24.sp, color: const Color(0xFF1F2937)),
                ),
              ),
            ),
          ),

          // Libellé « Carte plein écran » à côté du bouton réduire.
          Positioned(
            top: MediaQuery.of(context).padding.top + 14.h,
            left: 62.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Text(
                'pawmap_fullscreen_title'.tr,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
