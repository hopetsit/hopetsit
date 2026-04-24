// v19.1.1 — Boost profil : 2 boutons côte à côte sans CrossAxisAlignment.stretch
// (qui cassait le rendu des sections en-dessous sur le profil owner).
// Chaque chip est un Container à hauteur fixe, donc pas d'infinite height
// constraint qui fait bugger le scroll parent.

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
        return const Color(0xFF16A34A);
      case 'sitter':
        return const Color(0xFF2563EB);
      default:
        return AppColors.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    // v19.1.3 — 3 boutons : Boost (couleur rôle) / Premium (vert) / MapBoost
    // (bleu). Chacun ouvre un onglet dédié dans CoinShopScreen.
    return SizedBox(
      height: 90.h,
      child: Row(
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
          SizedBox(width: 8.w),
          Expanded(
            child: _BoostChip(
              accent: const Color(0xFF16A34A),
              icon: Icons.workspace_premium_rounded,
              title: 'premium_choose_plan'.tr,
              subtitle: 'premium_choose_plan_subtitle'.tr,
              onTap: () => Get.to(() => const CoinShopScreen(initialTab: 1)),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _BoostChip(
              accent: const Color(0xFF2563EB),
              icon: Icons.push_pin_rounded,
              title: 'mapboost_header_title'.tr,
              subtitle: 'mapboost_header_subtitle'.tr,
              onTap: () => Get.to(() => const CoinShopScreen(initialTab: 2)),
            ),
          ),
        ],
      ),
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
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
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
        child: Row(
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
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PoppinsText(
                    text: title,
                    fontSize: 12.sp,
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
          ],
        ),
      ),
    );
  }
}
