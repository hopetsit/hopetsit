// v23.1 part 109 — Daniel : "le boost marche pas".
// Petit row de badges ("Boost actif", "PawSpot actif", "Premium actif")
// affiché en haut du profil pour que le user voie immédiatement après
// achat que son achat a bien pris effet.
//
// Lit les flags depuis UserController.userProfile (rafraîchi par
// refreshAfterPurchase()).

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/controllers/user_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

class ActiveBenefitsRow extends StatelessWidget {
  const ActiveBenefitsRow({super.key, this.compact = false});

  /// Quand `compact: true`, badges plus petits (utile dans le header).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<UserController>()) return const SizedBox.shrink();
    final uc = Get.find<UserController>();
    return Obx(() {
      final p = uc.userProfile;
      final now = DateTime.now();
      final boostExpiry = _toDate(p['boostExpiry']);
      final mapBoostExpiry = _toDate(p['mapBoostExpiry']);
      final isPremium = p['isPremium'] == true ||
          _toDate(p['premiumExpiresAt'])?.isAfter(now) == true ||
          _toDate(p['currentPeriodEnd'])?.isAfter(now) == true;
      final boostActive = boostExpiry != null && boostExpiry.isAfter(now);
      final pawSpotActive = mapBoostExpiry != null && mapBoostExpiry.isAfter(now);

      final children = <Widget>[];
      if (isPremium) {
        children.add(_badge(context, '⭐', 'Premium', const Color(0xFFFFD700)));
      }
      if (boostActive) {
        final days = boostExpiry!.difference(now).inDays;
        children.add(_badge(context, '🚀', 'Boost · ${days}j', const Color(0xFFE8472A)));
      }
      if (pawSpotActive) {
        final days = mapBoostExpiry!.difference(now).inDays;
        children.add(_badge(context, '📍', 'PawSpot · ${days}j', const Color(0xFF10B981)));
      }
      if (children.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        child: Wrap(
          spacing: 6.w,
          runSpacing: 4.h,
          children: children,
        ),
      );
    });
  }

  Widget _badge(BuildContext context, String emoji, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8.w : 10.w,
        vertical: compact ? 3.h : 5.h,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: TextStyle(fontSize: compact ? 11.sp : 13.sp)),
          SizedBox(width: 4.w),
          InterText(
            text: label,
            fontSize: compact ? 10.sp : 12.sp,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ],
      ),
    );
  }

  DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
