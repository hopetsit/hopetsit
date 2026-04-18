import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/views/auth/login_screen.dart';
import 'package:hopetsit/views/auth/sign_up_as.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    AppColors.primaryColor,
                    AppColors.primaryColor.withValues(alpha: 0.85),
                    AppColors.backgroundDark,
                    AppColors.backgroundDark,
                  ]
                : [
                    AppColors.primaryColor,
                    AppColors.primaryColor.withValues(alpha: 0.9),
                    Colors.white,
                    Colors.white,
                  ],
            stops: const [0.0, 0.35, 0.35, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 28.w),
              child: Column(
                children: [
                  SizedBox(height: 30.h),

                  // ── Logo icon (paw) ──
                  Container(
                    width: 80.w,
                    height: 80.h,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(24.r),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.pets,
                        size: 44.sp,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // ── App name ──
                  PoppinsText(
                    text: 'HopeTSIT',
                    fontSize: 32.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),

                  SizedBox(height: 6.h),

                  // ── Tagline ──
                  InterText(
                    text: 'onboarding_tagline'.tr,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.85),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: 40.h),

                  // ── Feature highlights ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _FeatureChip(
                        icon: Icons.verified_user_outlined,
                        label: 'onboarding_feature_trusted'.tr,
                      ),
                      _FeatureChip(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'onboarding_feature_chat'.tr,
                      ),
                      _FeatureChip(
                        icon: Icons.location_on_outlined,
                        label: 'onboarding_feature_nearby'.tr,
                      ),
                    ],
                  ),

                  SizedBox(height: 40.h),

                  // ── CTA Section (white card area) ──
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 8.h,
                    ),
                    child: Column(
                      children: [
                        // Create account button
                        CustomButton(
                          title: 'button_create_account'.tr,
                          onTap: () => Get.to(() => SignUpAsScreen()),
                        ),

                        SizedBox(height: 16.h),

                        // Google button
                        Obx(
                          () => _SocialButton(
                            onTap: authController.isSocialLoginLoading.value
                                ? null
                                : () => authController.loginWithGoogle(),
                            icon: Icons.g_mobiledata,
                            label: 'onboarding_continue_with_google'.tr,
                            isOutlined: true,
                            imagePath: AppImages.googleIcon,
                            isLoading:
                                authController.isSocialLoginLoading.value,
                            isDark: isDark,
                          ),
                        ),

                        // Apple button (iOS only)
                        if (Platform.isIOS) ...[
                          SizedBox(height: 12.h),
                          Obx(
                            () => _SocialButton(
                              onTap: authController.isSocialLoginLoading.value
                                  ? null
                                  : () => authController.loginWithApple(),
                              icon: Icons.apple,
                              label: 'onboarding_continue_with_apple'.tr,
                              isOutlined: false,
                              isLoading:
                                  authController.isSocialLoginLoading.value,
                              isDark: isDark,
                            ),
                          ),
                        ],

                        SizedBox(height: 24.h),

                        // Divider
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: isDark
                                    ? AppColors.dividerDark
                                    : AppColors.grey300Color,
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              child: InterText(
                                text: 'onboarding_or'.tr,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: isDark
                                    ? AppColors.dividerDark
                                    : AppColors.grey300Color,
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 20.h),

                        // Login link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            InterText(
                              text: 'onboarding_have_account'.tr,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textSecondary(context),
                            ),
                            GestureDetector(
                              onTap: () => Get.to(() => const LoginScreen()),
                              child: Container(
                                color: Colors.transparent,
                                padding: EdgeInsets.fromLTRB(
                                  6.w, 10.h, 10.w, 10.h,
                                ),
                                child: InterText(
                                  text: 'title_login'.tr,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 20.h),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small feature highlight chip for the onboarding hero area.
class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 54.w,
          height: 54.h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 28.sp, color: AppColors.primaryColor),
        ),
        SizedBox(height: 8.h),
        InterText(
          text: label,
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final String? imagePath;
  final String label;
  final bool isOutlined;
  final bool isLoading;
  final bool isDark;

  const _SocialButton({
    this.onTap,
    required this.icon,
    required this.label,
    required this.isOutlined,
    this.imagePath,
    this.isLoading = false,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        height: 52.h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isOutlined
              ? (isDark ? AppColors.cardDark : AppColors.whiteColor)
              : AppColors.blackColor,
          border: isOutlined
              ? Border.all(
                  color: isDark
                      ? AppColors.dividerDark
                      : AppColors.grey300Color,
                )
              : null,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  height: 24.r,
                  width: 24.r,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isOutlined ? AppColors.blackColor : AppColors.whiteColor,
                    ),
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (imagePath != null)
                      Image.asset(
                        imagePath!,
                        height: 22.sp,
                        width: 22.sp,
                        fit: BoxFit.cover,
                      )
                    else
                      Icon(
                        icon,
                        size: 22.sp,
                        color: isOutlined
                            ? AppColors.textPrimary(context)
                            : AppColors.whiteColor,
                      ),
                    SizedBox(width: 10.w),
                    InterText(
                      text: label,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                      color: isOutlined
                          ? AppColors.textPrimary(context)
                          : AppColors.whiteColor,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
