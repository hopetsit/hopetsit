import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Walker profile screen — Phase-1 minimal scaffold.
/// Presents a placeholder with logout action until the full walker profile
/// (avatar, bio, insurance certificate, walkRates manager, coverage settings)
/// is implemented in later sessions.
class WalkerProfileScreen extends StatelessWidget {
  const WalkerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.appBar(context),
        surfaceTintColor: Colors.transparent,
        title: PoppinsText(
          text: 'walker_profile_title'.tr,
          fontSize: 20.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 24.h),
              // Profile status card.
              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: AppColors.divider(context),
                    width: 1,
                  ),
                  boxShadow: AppColors.cardShadow(context),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32.r,
                      backgroundColor: AppColors.greenColor.withOpacity(0.12),
                      child: Icon(
                        Icons.directions_walk_rounded,
                        color: AppColors.greenColor,
                        size: 32.sp,
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PoppinsText(
                            text: 'walker_profile_welcome'.tr,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context),
                          ),
                          SizedBox(height: 4.h),
                          InterText(
                            text: 'walker_profile_subtitle'.tr,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
              InterText(
                text: 'walker_profile_coming_soon'.tr,
                fontSize: 13.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary(context),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              // Logout action.
              OutlinedButton(
                onPressed: () async {
                  if (Get.isRegistered<AuthController>()) {
                    await Get.find<AuthController>().logout();
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.errorColor, width: 1),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: InterText(
                  text: 'button_logout'.tr,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.errorColor,
                ),
              ),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }
}
