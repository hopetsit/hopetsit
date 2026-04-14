import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopetsit/data/static/privacy_policy.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Sprint 8 step 3 — Privacy Policy screen (distinct file required by Play / App Store).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = LocalizationService.getCurrentLanguageCode();
    final text = privacyPolicyForLocale(lang);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: PoppinsText(
          text: 'Privacy policy',
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: SelectableText(
            text,
            style: TextStyle(
              fontSize: 13.sp,
              height: 1.45,
              color: AppColors.blackColor,
            ),
          ),
        ),
      ),
    );
  }
}
