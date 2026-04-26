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
    // v19.1.5 — 3 tuiles compactes, labels courts et LISIBLES (plus de texte
    // tronqué). Layout vertical : icône en haut, label unique en dessous.
    // Couleurs fixes : Boost=red #E8472A, PawPass=gold #F5A623, PawSpot=blue #2196F3.
    return SizedBox(
      height: 86.h,
      child: Row(
        children: [
          Expanded(
            child: _BoostChip(
              accent: const Color(0xFFE8472A),
              icon: Icons.rocket_launch_rounded,
              label: 'shop_tile_boost'.tr,
              onTap: () => Get.to(() => const CoinShopScreen(initialTab: 0)),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _BoostChip(
              accent: const Color(0xFFF5A623),
              icon: Icons.star_rounded,
              label: 'shop_tile_premium'.tr,
              onTap: () => Get.to(() => const CoinShopScreen(initialTab: 1)),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _BoostChip(
              accent: const Color(0xFF2196F3),
              icon: Icons.location_on_rounded,
              label: 'shop_tile_map_boost'.tr,
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
    required this.label,
    required this.onTap,
  });

  final Color accent;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent, accent.withValues(alpha: 0.82)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.30),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34.w,
              height: 34.w,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.24),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20.sp),
            ),
            SizedBox(height: 6.h),
            PoppinsText(
              text: label,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
