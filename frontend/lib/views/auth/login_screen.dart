import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_text_field.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/views/auth/forgot_flow/forgot_password_email_screen.dart';
import 'package:hopetsit/views/auth/sign_up_as.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AuthController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: Stack(
        children: [
          // ── Subtle gradient overlay at top ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 200.h,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primaryColor.withValues(alpha: 0.06),
                    AppColors.scaffold(context).withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Form(
                key: controller.formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 12.h),

                    // ── Top bar: dark mode toggle + language ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Dark mode toggle
                        GestureDetector(
                          onTap: () {
                            final currentMode = Get.isDarkMode;
                            Get.changeThemeMode(
                              currentMode ? ThemeMode.light : ThemeMode.dark,
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.all(10.w),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.surfaceDark
                                  : AppColors.grey300Color.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Icon(
                              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                              size: 22.sp,
                              color: isDark ? Colors.amber : AppColors.grey700Color,
                            ),
                          ),
                        ),

                        // Language selector
                        GestureDetector(
                          onTap: () => _showLanguageDialog(context),
                          child: Container(
                            padding: EdgeInsets.all(10.w),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.surfaceDark
                                  : AppColors.grey300Color.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Icon(
                              Icons.language_rounded,
                              size: 22.sp,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 40.h),

                    // ── Welcome greeting card with logo ──
                    Container(
                      padding: EdgeInsets.all(24.w),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: AppColors.primaryColor.withValues(alpha: 0.15),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryColor.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // v22.1 — Logo : passage SVG → PNG pour fix l'effet
                          // "tordu" (le SVG a un transform Y=471 hors-centre).
                          // Carré strict via 64.w sur les 2 axes.
                          Container(
                            width: 64.w,
                            height: 64.w,
                            decoration: BoxDecoration(
                              color: AppColors.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            padding: EdgeInsets.all(6.w),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12.r),
                              child: Image.asset(
                                'assets/brand/png/apple-icon-original.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          SizedBox(height: 16.h),
                          PoppinsText(
                            text: 'welcome_back'.tr,
                            fontSize: 26.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                          ),
                          SizedBox(height: 8.h),
                          InterText(
                            text: 'login_subtitle'.tr,
                            fontSize: 13.sp,
                            color: AppColors.textSecondary(context),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 40.h),

                    // ── Email field with icon ──
                    CustomTextField(
                      labelText: 'label_email'.tr,
                      hintText: 'hint_email'.tr,
                      controller: controller.emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: controller.validateEmail,
                      prefixIcon: Icon(
                        Icons.mail_outline_rounded,
                        size: 20.sp,
                        color: AppColors.textSecondary(context),
                      ),
                      radius: 16.r,
                    ),
                    SizedBox(height: 16.h),

                    // ── Password field with icon and show/hide toggle ──
                    CustomTextField(
                      labelText: 'label_password'.tr,
                      hintText: 'hint_password_login'.tr,
                      controller: controller.passwordController,
                      obscureText: true,
                      showPasswordToggle: true,
                      textInputAction: TextInputAction.done,
                      validator: controller.validatePassword,
                      prefixIcon: Icon(
                        Icons.lock_outline_rounded,
                        size: 20.sp,
                        color: AppColors.textSecondary(context),
                      ),
                      radius: 16.r,
                    ),
                    SizedBox(height: 12.h),

                    // ── Forgot password link (right-aligned, small) ──
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Get.to(
                          () => const ForgotPasswordEmailScreen(),
                          transition: Transition.rightToLeft,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryColor,
                          padding: EdgeInsets.symmetric(horizontal: 0.w, vertical: 4.h),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: InterText(
                          text: 'forgot_password'.tr,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryColor,
                          textDecoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    SizedBox(height: 28.h),

                    // ── Sign in button (full-width, modern) ──
                    Obx(
                      () => SizedBox(
                        width: double.infinity,
                        height: 48.h,
                        child: CustomButton(
                          title: controller.isLoading.value
                              ? 'logging_in'.tr
                              : 'title_login'.tr,
                          onTap: controller.isLoading.value
                              ? null
                              : () => controller.handleLoginWithNavigation(),
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),

                    // ── Divider with "OR" text ──
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
                          padding: EdgeInsets.symmetric(horizontal: 12.w),
                          child: InterText(
                            text: 'or_continue_with'.tr,
                            fontSize: 12.sp,
                            color: AppColors.textSecondary(context),
                            fontWeight: FontWeight.w500,
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
                    SizedBox(height: 24.h),

                    // ── Social buttons (Google + Apple on iOS) ──
                    Row(
                      children: [
                        Expanded(
                          child: _SocialLoginButton(
                            onTap: controller.isLoading.value ||
                                    controller.isSocialLoginLoading.value
                                ? null
                                : () => controller.loginWithGoogle(),
                            imagePath: AppImages.googleIcon,
                            label: 'button_google'.tr,
                            isDark: isDark,
                          ),
                        ),
                        if (Platform.isIOS) ...[
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _SocialLoginButton(
                              onTap: controller.isLoading.value ||
                                      controller.isSocialLoginLoading.value
                                  ? null
                                  : () => controller.loginWithApple(),
                              icon: Icons.apple,
                              label: 'button_apple'.tr,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 32.h),

                    // ── Sign up link (footer) ──
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          InterText(
                            text: 'dont_have_account'.tr,
                            fontSize: 13.sp,
                            color: AppColors.textSecondary(context),
                          ),
                          TextButton(
                            onPressed: () =>
                                Get.to(() => const SignUpAsScreen()),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: 4.w),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: PoppinsText(
                              text: 'sign_up'.tr,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            ),
          ),

          // ── Loading overlay ──
          Obx(
            () => controller.isSocialLoginLoading.value
                ? Positioned.fill(
                    child: Container(
                      color: AppColors.blackColor.withValues(alpha: 0.3),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Track the selected language inside the dialog so the check mark moves
    // when the user taps. Without StatefulBuilder, the check stayed frozen
    // on whatever language was active at open-time.
    String selectedCode = LocalizationService.getCurrentLanguageCode();
    final entries = LocalizationService.languageLabels.entries.toList();

    Get.defaultDialog(
      title: 'language_dialog_title'.tr,
      titleStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.textPrimaryDark : AppColors.blackColor,
      ),
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.whiteColor,
      content: StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: entries.map((entry) {
              final isSelected = entry.key == selectedCode;
              return ListTile(
                title: InterText(
                  text: entry.value,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w500,
                  color:
                      isDark ? AppColors.textPrimaryDark : AppColors.blackColor,
                ),
                trailing: isSelected
                    ? Icon(Icons.check, color: AppColors.primaryColor)
                    : null,
                onTap: () async {
                  setDialogState(() {
                    selectedCode = entry.key;
                  });
                  await LocalizationService.updateLocale(entry.key);
                  // Brief pause so the visual confirmation registers.
                  await Future.delayed(const Duration(milliseconds: 250));
                  Get.back();
                  CustomSnackbar.showSuccess(
                    title: 'language_updated_title'.tr,
                    message: 'language_updated_message'.tr,
                  );
                },
              );
            }).toList(),
          );
        },
      ),
      textCancel: 'common_cancel'.tr,
      cancelTextColor: AppColors.primaryColor,
    );
  }
}

/// Modern social login button with icon + label (Google/Apple).
/// Google: white background with subtle grey border.
/// Apple: black background with white text.
class _SocialLoginButton extends StatelessWidget {
  final VoidCallback? onTap;
  final String? imagePath;
  final IconData? icon;
  final String label;
  final bool isDark;

  const _SocialLoginButton({
    this.onTap,
    this.imagePath,
    this.icon,
    required this.label,
    required this.isDark,
  });

  bool get _isApple => icon == Icons.apple;

  @override
  Widget build(BuildContext context) {
    final isAppleButton = _isApple;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24.r),
      child: Container(
        height: 48.h,
        decoration: BoxDecoration(
          color: isAppleButton
              ? AppColors.blackColor
              : (isDark ? AppColors.surfaceDark : Colors.white),
          borderRadius: BorderRadius.circular(24.r),
          border: isAppleButton
              ? null
              : Border.all(
                  color: isDark ? AppColors.dividerDark : Colors.grey.shade300,
                  width: 1.5,
                ),
          boxShadow: isAppleButton
              ? null
              : [
                  BoxShadow(
                    color: AppColors.blackColor.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (imagePath != null)
                Image.asset(
                  imagePath!,
                  height: 20.sp,
                  width: 20.sp,
                  fit: BoxFit.cover,
                )
              else if (icon != null)
                Icon(
                  icon,
                  size: 20.sp,
                  color: isAppleButton ? Colors.white : AppColors.textPrimary(context),
                ),
              SizedBox(width: 8.w),
              InterText(
                text: label,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: isAppleButton ? Colors.white : AppColors.textPrimary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
