import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// v23.1 part 253 — Daniel : "verifie que tt les badge boost ... sont les
/// memes design sur les 3 profils".
///
/// Badge "Boost" UNIFIE pour les cartes provider (sitter_card, walker_card,
/// service_provider_card). Avant : 3 designs differents (flamme+gradient
/// pour sitter/service_provider mais label hardcode 'Boost' ; badge OR avec
/// icone premium pour walker). Maintenant : un seul widget partage =
/// gradient flamme orange→rouge + 🔥 + label i18n 'boost_badge' (Boosté).
///
/// Source unique de verite : tout changement de design se fait ici et se
/// propage aux 3 cartes.
class BoostBadge extends StatelessWidget {
  const BoostBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFA000), Color(0xFFEF4444)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.30),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🔥', style: TextStyle(fontSize: 10.sp)),
          SizedBox(width: 3.w),
          InterText(
            text: 'boost_badge'.tr,
            fontSize: 10.sp,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

/// v23.1 part 253 — badge "Top" (Top Sitter / Top Walker) — distinct du
/// Boost, garde un look OR/premium. Unifie aussi pour coherence.
class TopProviderBadge extends StatelessWidget {
  const TopProviderBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFB8860B), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded,
              size: 12.sp, color: const Color(0xFFB8860B)),
          SizedBox(width: 3.w),
          InterText(
            text: 'top_badge'.tr,
            fontSize: 10.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFB8860B),
          ),
        ],
      ),
    );
  }
}
