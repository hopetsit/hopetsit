// v19.1 — Bouton "Booster" divisé en deux CTA côte à côte :
//   • Boost profil (rocket, orange/bleu/vert selon rôle) → shop tab 0 (Boost)
//   • Boost map (pin, cyan) → shop tab 2 (Map Boost)
//
// Avant v19.1 : un seul gros bouton qui ouvrait le shop sur l'onglet Boost.
// Les users voulaient atteindre Map Boost directement depuis leur profil
// sans passer par la navigation 3-onglets.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';

class BoostProfileCard extends StatelessWidget {
  final String role; // 'owner' | 'sitter' | 'walker'

  const BoostProfileCard({super.key, required this.role});

  Color get _accent {
    switch (role) {
      case 'walker':
        return const Color(0xFF16A34A); // vert
      case 'sitter':
        return const Color(0xFF2563EB); // bleu
      default:
        return AppColors.primaryColor; // orange owner
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _BoostChip(
            accent: _accent,
            icon: Icons.rocket_launch_rounded,
            title: 'profile_boost_profile_title'.tr,
            subtitle: 'profile_boost_profile_subtitle'.tr,
            onTap: () => Get.to(() => const CoinShopScreen(initialTab: 0)),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _BoostChip(
            // Map Boost garde un accent bleu cyan distinct du rôle user :
            // c'est un produit différent (carte plutôt que feed).
            accent: const Color(0xFF3B82F6),
            icon: Icons.push_pin_rounded,
            title: 'profile_boost_map_title'.tr,
            subtitle: 'profile_boost_map_subtitle'.tr,
            onTap: () => Get.to(() => const CoinShopScreen(initialTab: 2)),
          ),
        ),
      ],
    );
  }
}

class _BoostChip extends StatelessWidget {
  const _BoostChip({
    required this.accent,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color accent;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent, accent.withValues(alpha: 0.78)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20.sp),
            ),
            SizedBox(height: 10.h),
            PoppinsText(
              text: title,
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2.h),
            InterText(
              text: subtitle,
              fontSize: 10.sp,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.9),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
