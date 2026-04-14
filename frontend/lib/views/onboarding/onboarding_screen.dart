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
    return Scaffold(
      backgroundColor: AppColors.primaryColor,
      body: SafeArea(
        bottom: false,
        child: SizedBox(
          width: double.infinity,
          child: Stack(
            children: [
              Center(
                child: Column(
                  children: [
                    SizedBox(height: 10.h),
                    PoppinsText(
                      text: 'onboarding_app_title'.tr,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.whiteColor,
                    ),
                    SizedBox(height: 10.h),
                    Image.asset(
                      AppImages.bgRemovedLogo,
                      color: AppColors.whiteColor,
                      height: 80.h,
                      fit: BoxFit.cover,
                    ),
                    SizedBox(height: 20.h),
                    Image.asset(
                      AppImages.onboardingIllustration,
                      fit: BoxFit.cover,
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: Get.size.height / 1.85,
                  width: Get.size.width,
                  child: Stack(
                    children: [
                      Image.asset(AppImages.curvedDesign, fit: BoxFit.cover),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40.w),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // PoppinsText(
                            //   text:
                            //       'Hopetsit is the social network for pet lovers - share photos, videos and special moments of your pets with a community that adores animals just as much as you do!',
                            //   fontSize: 13.sp,
                            //   color: AppColors.greyColor,
                            //   textAlign: TextAlign.center,
                            // ),
                            SizedBox(height: 10.h),
                            CustomButton(
                              title: 'button_create_account'.tr,
                              onTap: () => Get.to(() => SignUpAsScreen()),
                            ),
                            SizedBox(height: 16.h),
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
                              ),
                            ),
                            if (Platform.isIOS) ...[
                              SizedBox(height: 12.h),
                              Obx(
                                () => _SocialButton(
                                  onTap:
                                      authController.isSocialLoginLoading.value
                                      ? null
                                      : () =>
                                            authController.loginWithApple(),
                                  icon: Icons.apple,
                                  label: 'onboarding_continue_with_apple'.tr,
                                  isOutlined: false,
                                  isLoading:
                                      authController.isSocialLoginLoading.value,
                                ),
                              ),
                            ] else
                              SizedBox(height: 40.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                InterText(text: 'onboarding_have_account'.tr),
                                GestureDetector(
                                  onTap: () =>
                                      Get.to(() => const LoginScreen()),
                                  child: Container(
                                    color: Colors.transparent,
                                    padding: EdgeInsets.fromLTRB(
                                      5.w,
                                      10.h,
                                      10.w,
                                      10.h,
                                    ),
                                    child: InterText(
                                      text: 'title_login'.tr,
                                      color: AppColors.primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 90.h),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

  const _SocialButton({
    this.onTap,
    required this.icon,
    required this.label,
    required this.isOutlined,
    this.imagePath,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(48.r),
      child: Container(
        height: 50.h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isOutlined ? AppColors.whiteColor : AppColors.blackColor,
          border: isOutlined ? Border.all(color: AppColors.grey300Color) : null,
          borderRadius: BorderRadius.circular(48.r),
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
                            ? AppColors.blackColor
                            : AppColors.whiteColor,
                      ),
                    SizedBox(width: 10.w),
                    InterText(
                      text: label,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      color: isOutlined
                          ? AppColors.blackColor
                          : AppColors.whiteColor,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
