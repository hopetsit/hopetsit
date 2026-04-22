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
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Form(
                key: controller.formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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

                    SizedBox(height: 28.h),

                    // ── Logo + Welcome ──
                    // v18.5 — logo V4 officiel (SVG) à la place de l'icône
                    // Icons.pets générique. Container en dessous garde le
                    // boxShadow/gradient mais affiche la patte HoPetSit.
                    Center(
                      child: Container(
                        width: 72.w,
                        height: 72.h,
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor,
                          borderRadius: BorderRadius.circular(20.r),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryColor.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.all(10.w),
                        child: SvgPicture.asset(
                          'assets/brand/apple/apple-icon-original.svg',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    SizedBox(height: 20.h),

                    Center(
                      child: PoppinsText(
                        text: 'welcome_back'.tr,
                        fontSize: 26.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Center(
                      child: InterText(
                        text: 'login_subtitle'.tr,
                        fontSize: 14.sp,
                        color: AppColors.textSecondary(context),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    SizedBox(height: 32.h),

                    // ── Email field ──
                    CustomTextField(
                      labelText: 'label_email'.tr,
                      hintText: 'hint_email'.tr,
                      controller: controller.emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: controller.validateEmail,
                    ),
                    SizedBox(height: 20.h),

                    // ── Password field ──
                    CustomTextField(
                      labelText: 'label_password'.tr,
                      hintText: 'hint_password_login'.tr,
                      controller: controller.passwordController,
                      obscureText: true,
                      showPasswordToggle: true,
                      textInputAction: TextInputAction.done,
                      validator: controller.validatePassword,
                    ),
                    SizedBox(height: 8.h),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Get.to(
                          () => const ForgotPasswordEmailScreen(),
                          transition: Transition.rightToLeft,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryColor,
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: InterText(
                          text: 'forgot_password'.tr,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    ),
                    SizedBox(height: 28.h),

                    // ── Login button ──
                    Obx(
                      () => CustomButton(
                        title: controller.isLoading.value
                            ? 'logging_in'.tr
                            : 'title_login'.tr,
                        onTap: controller.isLoading.value
                            ? null
                            : () => controller.handleLoginWithNavigation(),
                      ),
                    ),
                    SizedBox(height: 24.h),

                    // ── Divider ──
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
                            text: 'or_continue_with'.tr,
                            fontSize: 12.sp,
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
                    SizedBox(height: 24.h),

                    // ── Social buttons ──
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
                    SizedBox(height: 28.h),

                    // ── Sign up link ──
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: PoppinsText(
                              text: 'sign_up'.tr,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
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

/// Clean social login button with icon + label.
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

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        height: 52.h,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isDark ? AppColors.dividerDark : AppColors.grey300Color,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (imagePath != null)
              Image.asset(imagePath!, height: 20.sp, width: 20.sp, fit: BoxFit.cover)
            else if (icon != null)
              Icon(icon, size: 22.sp, color: AppColors.textPrimary(context)),
            SizedBox(width: 8.w),
            InterText(
              text: label,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary(context),
            ),
          ],
        ),
      ),
    );
  }
}
