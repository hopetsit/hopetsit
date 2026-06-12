// v19.1.1 — Boost profil : boutons côte à côte sans CrossAxisAlignment.stretch
// (qui cassait le rendu des sections en-dessous sur le profil owner).
// v23.1.390 — Daniel : 4 carrés ALIGNÉS sur une ligne (les 3 profils) :
//   PawBoost (orange) · PawFollow (nouveau logo pin violet) · PawSpot (pièce
//   dorée) · Paw Premium (NOIR/or, sous-titre "PawFollow+PawSpot", ouvre
//   l'onglet Premium de la boutique). Tailles réduites pour tenir à 4.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/golden_paw_coin.dart';

class BoostProfileCard extends StatelessWidget {
  final String role; // 'owner' | 'sitter' | 'walker'

  const BoostProfileCard({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108.h,
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
          SizedBox(width: 8.w),
          Expanded(
            child: _BoostChip(
              accent: const Color(0xFF7C3AED), // v354 — PawFollow = violet (Daniel)
              icon: Icons.star_rounded,
              // v23.1.390 — nouveau logo officiel (pin violet + patte).
              iconWidget: Image.asset(
                'assets/images/pawfollow_logo.png',
                width: 40.w,
                height: 40.w,
              ),
              label: 'shop_tile_premium'.tr,
              onTap: () => Get.to(() => const CoinShopScreen(initialTab: 1)),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _BoostChip(
              // v23.1.363 — Daniel : le logo PawSpot = la pièce DORÉE
              // officielle (emoji fourni), aussi sur le chip du profil.
              accent: const Color(0xFFE8A00A),
              icon: Icons.pets_rounded,
              iconWidget: const GoldenPawCoin(size: 36),
              label: 'shop_tile_map_boost'.tr,
              onTap: () => Get.to(() => const CoinShopScreen(initialTab: 2)),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _BoostChip(
              // v23.1.390 — Paw Premium : carré NOIR, liseré or, pièce or.
              accent: const Color(0xFF15120D),
              borderColor: const Color(0xFFE8A00A),
              labelColor: const Color(0xFFFFD700),
              icon: Icons.workspace_premium_rounded,
              iconWidget: Image.asset(
                'assets/images/pawpremium_logo.png',
                width: 40.w,
                height: 40.w,
              ),
              label: 'shop_tile_pawpremium'.tr,
              subLabel: 'PawFollow+PawSpot',
              onTap: () => Get.to(() => const CoinShopScreen(initialTab: 3)),
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
    this.iconWidget,
    this.subLabel,
    this.borderColor,
    this.labelColor,
  });

  final Color accent;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// v23.1.363 — icône custom (ex. pièce dorée PawSpot) à la place de
  /// l'IconData.
  final Widget? iconWidget;

  /// v23.1.390 — petite 2e ligne (ex. "PawFollow+PawSpot" sur Premium).
  final String? subLabel;
  final Color? borderColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 10.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent, accent.withValues(alpha: 0.82)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: (borderColor ?? accent).withValues(alpha: 0.38),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: borderColor ?? Colors.white.withValues(alpha: 0.18),
            width: borderColor != null ? 1.8 : 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.24),
                shape: BoxShape.circle,
              ),
              child: iconWidget != null
                  ? Center(child: iconWidget)
                  : Icon(icon, color: Colors.white, size: 22.sp),
            ),
            SizedBox(height: 6.h),
            // v23.1.391 — Daniel : « qu'on arrive à lire sans coupure ».
            // FittedBox(scaleDown) : le texte rétrécit pour TOUJOURS tenir
            // en entier dans le carré (jamais de « Paw Premi… »).
            FittedBox(
              fit: BoxFit.scaleDown,
              child: PoppinsText(
                text: label,
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w800,
                color: labelColor ?? Colors.white,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
            if (subLabel != null) ...[
              SizedBox(height: 1.h),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: InterText(
                  text: subLabel!,
                  fontSize: 7.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
