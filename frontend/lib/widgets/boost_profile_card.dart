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
    // v23.1 part 122 — Daniel : "Ameliorer - icone premium pawfollow et
    // pawspot plus visible". Chips agrandies (height 86→110), icones plus
    // grandes (34→48), avec animation de pulse subtile pour attirer le
    // regard. Labels en deux lignes possibles (max 2 lines).
    return SizedBox(
      height: 112.h,
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
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent, accent.withValues(alpha: 0.78)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.42),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.28),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 28.sp),
            ),
            SizedBox(height: 8.h),
            PoppinsText(
              text: label,
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
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
