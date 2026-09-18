import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/static/privacy_policy.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';

/// Sprint 8 step 3 — Privacy Policy screen (distinct file required by Play / App Store).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = LocalizationService.getCurrentLanguageCode();
    final text = privacyPolicyForLocale(lang);
    // v565 — sous-page modernisée (kit Profil) : texte dans une carte.
    final accent = currentRoleAccent();
    return ProfileSubPageScaffold(
      title: 'profile_privacy'.tr,
      accent: accent,
      body: Container(
        padding: EdgeInsets.all(18.w),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: AppColors.cardShadow(context),
        ),
        child: SelectableText(
          text,
          style: TextStyle(
            fontSize: 13.sp,
            height: 1.5,
            color: AppColors.textPrimary(context),
          ),
        ),
      ),
    );
  }
}
