// v18.6 — Bouton réutilisable "Booster mon profil".
// Utilisé sur profile_screen (owner), sitter_profile_screen,
// walker_profile_screen. Colorisé selon le rôle du user courant.
//
// Tap → ouvre la boutique coin boost (CoinShopScreen). La boutique gère
// le paiement via Stripe et applique le boost au rôle actif.

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
    return GestureDetector(
      onTap: () => Get.to(() => const CoinShopScreen()),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _accent,
              _accent.withValues(alpha: 0.78),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: _accent.withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.rocket_launch_rounded,
                color: Colors.white,
                size: 22.sp,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PoppinsText(
                    text: 'profile_boost_cta'.tr,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  SizedBox(height: 2.h),
                  InterText(
                    text: 'profile_boost_subtitle'.tr,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.85),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 16.sp,
            ),
          ],
        ),
      ),
    );
  }
}
