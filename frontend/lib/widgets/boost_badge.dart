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
    // v569 — liseré blanc pour rester lisible posé sur une photo, pilule
    // complète (999) et ombre un peu plus diffuse. Aucun changement d'API.
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.5.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFA000), Color(0xFFEF4444)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.32),
            blurRadius: 8,
            spreadRadius: -2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🔥', style: TextStyle(fontSize: 10.sp)),
          SizedBox(width: 4.w),
          InterText(
            text: 'boost_badge'.tr,
            fontSize: 10.sp,
            fontWeight: FontWeight.w800,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            letterSpacing: 0.1,
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
    // v569 — mêmes dimensions que BoostBadge (pilule 999, liseré blanc) pour
    // que les deux badges s'alignent parfaitement côte à côte.
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.5.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE9A8), Color(0xFFF6D169)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB8860B).withValues(alpha: 0.26),
            blurRadius: 8,
            spreadRadius: -2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded,
              size: 12.sp, color: const Color(0xFF8A6508)),
          SizedBox(width: 4.w),
          InterText(
            text: 'top_badge'.tr,
            fontSize: 10.sp,
            fontWeight: FontWeight.w800,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            letterSpacing: 0.1,
            color: const Color(0xFF8A6508),
          ),
        ],
      ),
    );
  }
}
