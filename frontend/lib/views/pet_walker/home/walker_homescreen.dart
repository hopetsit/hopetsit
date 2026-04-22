import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_app_bar.dart';

/// Walker home screen — Phase-1 placeholder.
/// Presents a welcome state until the walker-specific widgets (today's walks,
/// nearby walk requests, earnings summary) are implemented in later sessions.
class WalkerHomescreen extends StatelessWidget {
  const WalkerHomescreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.appBar(context),
        surfaceTintColor: Colors.transparent,
        title: PoppinsText(
          text: 'walker_home_title'.tr,
          fontSize: 20.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
        // v18.6 — mini bouton Boost vert walker dans le header.
        actions: const [
          BoostQuickAction(role: 'walker'),
          SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 24.h),
              // Welcome card with green accent.
              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: AppColors.greenColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: AppColors.greenColor.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.directions_walk_rounded,
                          color: AppColors.greenColor,
                          size: 28.sp,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: PoppinsText(
                            text: 'walker_home_welcome_title'.tr,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    InterText(
                      text: 'walker_home_welcome_body'.tr,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary(context),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
              InterText(
                text: 'walker_home_coming_soon'.tr,
                fontSize: 13.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary(context),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
