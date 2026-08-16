import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/services/firebase_analytics_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/auth/login_screen.dart';
import 'package:hopetsit/views/auth/signup_wizard_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// v535 — SPEC ONBOARDING P1.2 : le MUR D'INSCRIPTION CONTEXTUEL.
///
/// Avant, le mur était à l'OUVERTURE de l'app (0 contenu sans compte,
/// ~2 % d'inscriptions). Désormais l'app s'explore librement, et cette
/// feuille n'apparaît qu'au moment où l'invité veut AGIR — contacter,
/// réserver, publier, taguer un spot. À cet instant l'intention est déjà
/// là : c'est le moment où la conversion est la plus forte.
///
/// [trigger] alimente l'événement `signup_wall_shown` (P3) :
/// 'contact' | 'booking' | 'publish' | 'spot' | 'profile'.
/// [name] personnalise le titre (« Crée ton compte pour contacter Marie »).
class SignupWallSheet extends StatelessWidget {
  final String trigger;
  final String? name;
  const SignupWallSheet({super.key, required this.trigger, this.name});

  static Future<void> show({required String trigger, String? name}) {
    FirebaseAnalyticsService.instance
        .logFunnel('signup_wall_shown', params: {'trigger': trigger});
    return Get.bottomSheet(
      SignupWallSheet(trigger: trigger, name: name),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = (name != null && name!.isNotEmpty)
        ? 'guest_wall_title_named'.trParams({'name': name!})
        : 'guest_wall_title'.tr;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      padding: EdgeInsets.fromLTRB(24.w, 14.h, 24.w, 24.h),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 18.h),
            Center(
              child: Image.asset(
                'assets/brand/png/logo-mark.png',
                width: 64.w,
                height: 64.w,
              ),
            ),
            SizedBox(height: 14.h),
            PoppinsText(
              text: title,
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 6.h),
            InterText(
              text: 'guest_wall_subtitle'.tr,
              fontSize: 13.sp,
              color: Colors.grey,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20.h),
            SizedBox(
              height: 52.h,
              child: ElevatedButton(
                onPressed: () {
                  FirebaseAnalyticsService.instance.logFunnel('signup_start',
                      params: {'trigger': trigger});
                  Get.back();
                  // v535 — P2 : PAS de choix de rôle bloquant depuis le mur
                  // invité. Un visiteur qui veut contacter un gardien est un
                  // propriétaire : rôle owner par défaut, modifiable ensuite
                  // dans le profil (« Tu veux proposer tes services ? »).
                  Get.to(() => SignupWizardScreen(userType: 'owner'));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                child: PoppinsText(
                  text: 'guest_wall_signup'.tr,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 10.h),
            TextButton(
              onPressed: () {
                Get.back();
                Get.to(() => const LoginScreen());
              },
              child: InterText(
                text: 'guest_wall_login'.tr,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
