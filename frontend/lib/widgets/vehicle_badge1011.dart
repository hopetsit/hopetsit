import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// 1011 — pastille « Véhiculé » : le gardien ou le promeneur a déclaré un
/// véhicule (`hasVehicle == true`), il peut venir chercher l'animal.
///
/// À n'afficher QUE quand la valeur du serveur est `true` : absente ou `null`
/// = on ne montre rien (jamais « non véhiculé »). Icône de la famille maison
/// + texte, sans emoji (NORME_DESIGN), teinte de la couleur du rôle.
class VehicleBadge1011 extends StatelessWidget {
  const VehicleBadge1011({super.key, required this.accent});

  /// Couleur du rôle du candidat (gardien bleu, promeneur vert).
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final fg = AppColors.accentOn(context, accent);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_car_rounded, size: 11.sp, color: fg),
          SizedBox(width: 3.w),
          InterText(
            text: 'c1011_vehicle_badge'.tr,
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ],
      ),
    );
  }
}
