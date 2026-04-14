import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Terms & Conditions / Legal Notice screen.
///
/// Owner of the platform: CARDELLI HERMANOS LIMITED (HK Company No. 2671528)
/// Address: Flat/Rm A 12/F, ZJ 300, 300 Lockhart Road, Wan Chai, Hong Kong
///
/// This screen is designed to satisfy both Google Play Store and Apple App
/// Store review requirements:
///   - Identification of the service provider
///   - Clear disclaimer that the company is a technical platform only
///   - Limitation of liability for animals, pet sitters and pet sitting services
///   - Contact information
///   - Mention of applicable laws protecting the platform and its users
class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      appBar: AppBar(
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        centerTitle: true,
        title: PoppinsText(
          text: 'terms_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.blackColor,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _section('terms_section_owner_title', 'terms_section_owner_body'),
              _section(
                'terms_section_platform_title',
                'terms_section_platform_body',
              ),
              _section(
                'terms_section_liability_title',
                'terms_section_liability_body',
              ),
              _section(
                'terms_section_responsibilities_title',
                'terms_section_responsibilities_body',
              ),
              _section(
                'terms_section_payment_title',
                'terms_section_payment_body',
              ),
              _section(
                'terms_section_data_title',
                'terms_section_data_body',
              ),
              _section('terms_section_law_title', 'terms_section_law_body'),
              _section(
                'terms_section_contact_title',
                'terms_section_contact_body',
              ),
              SizedBox(height: 24.h),
              Center(
                child: InterText(
                  text: 'terms_last_update'.tr,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.greyColor,
                ),
              ),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String titleKey, String bodyKey) {
    return Padding(
      padding: EdgeInsets.only(bottom: 18.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PoppinsText(
            text: titleKey.tr,
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryColor,
          ),
          SizedBox(height: 6.h),
          InterText(
            text: bodyKey.tr,
            fontSize: 13.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.blackColor,
          ),
        ],
      ),
    );
  }
}
