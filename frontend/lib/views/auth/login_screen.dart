import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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

                    // v478 — maquette « App Opening » : bandeau de marque
                    // arrondi (dégradé orange) avec logo + « Bon retour 👋 ».
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20.w),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primaryColor,
                            isDark
                                ? const Color(0xFFC93D18)
                                : const Color(0xFFED4F25),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(28.r),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.primaryColor.withValues(alpha: 0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -12.w,
                            top: -18.h,
                            child: Transform.rotate(
                              angle: 0.28,
                              child: Text(
                                '🐾',
                                style: TextStyle(
                                  fontSize: 86.sp,
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              // Logo squircle blanc.
                              Container(
                                width: 60.w,
                                height: 60.w,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.16),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
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
                              SizedBox(width: 14.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    PoppinsText(
                                      text: '${'welcome_back'.tr} 👋',
                                      fontSize: 24.sp,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 6.h),
                                    InterText(
                                      text: 'login_subtitle'.tr,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          Colors.white.withValues(alpha: 0.92),
                                      maxLines: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
                        // v23.1 part 200 — Daniel : "le bouton Google et
                        // Apple chargent en même temps quand on clique sur
                        // un seul". Chaque bouton lit MAINTENANT son propre
                        // flag (isGoogleLoginLoading / isAppleLoginLoading),
                        // donc le spinner ne s'affiche que sur le bouton
                        // pressé. Les deux désactivent quand même l'autre
                        // pendant la requête (sécurité : évite un double
                        // sign-in concurrent).
                        Expanded(
                          child: _SocialLoginButton(
                            onTap: controller.isLoading.value ||
                                    controller.isGoogleLoginLoading.value ||
                                    controller.isAppleLoginLoading.value
                                ? null
                                : () => controller.loginWithGoogle(),
                            imagePath: AppImages.googleIcon,
                            label: 'button_google'.tr,
                            isDark: isDark,
                            isLoading: controller.isGoogleLoginLoading.value,
                          ),
                        ),
                        if (Platform.isIOS) ...[
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _SocialLoginButton(
                              onTap: controller.isLoading.value ||
                                      controller.isGoogleLoginLoading.value ||
                                      controller.isAppleLoginLoading.value
                                  ? null
                                  : () => controller.loginWithApple(),
                              icon: Icons.apple,
                              label: 'button_apple'.tr,
                              isDark: isDark,
                              isLoading: controller.isAppleLoginLoading.value,
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 18.h),

                    // v23.1 part 138 — Daniel : "interface de connexion
                    // c mélanger pas clair distinguer ou s'inscrire ou
                    // se connecter avec compte". On remplace le mini-link
                    // en bas par UN VRAI BLOC bien visible "Pas encore
                    // de compte ?" + un BOUTON OUTLINED large
                    // "Créer un compte" (vs le bouton bleu plein
                    // "Se connecter" en haut). Les 2 actions sont
                    // maintenant nettement différenciées.
                    SizedBox(height: 8.h),
                    // Séparateur visuel "compte"
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: AppColors.primaryColor.withValues(alpha: 0.18),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_add_alt_1_rounded,
                                size: 18.sp,
                                color: AppColors.primaryColor,
                              ),
                              SizedBox(width: 8.w),
                              PoppinsText(
                                text: 'dont_have_account'.tr,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary(context),
                              ),
                            ],
                          ),
                          SizedBox(height: 10.h),
                          SizedBox(
                            width: double.infinity,
                            height: 44.h,
                            child: OutlinedButton(
                              onPressed: () => Get.to(() => const SignUpAsScreen()),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: AppColors.primaryColor,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.r),
                                ),
                                foregroundColor: AppColors.primaryColor,
                              ),
                              child: PoppinsText(
                                text: 'sign_up'.tr,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                  ],
                ),
              ),
            ),
          ),

          // v23.1 part 200 — overlay full-screen supprimé. Le spinner est
          // maintenant inline dans le bouton pressé (Google OU Apple,
          // indépendant). Plus de masque noir qui bloque toute l'UI.
          const SizedBox.shrink(),
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
                  text:
                      '${LocalizationService.languageFlags[entry.key] ?? ''} ${entry.value}'
                          .trim(),
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
  // v23.1 part 200 — spinner par-bouton (Google ou Apple indépendant)
  final bool isLoading;

  const _SocialLoginButton({
    this.onTap,
    this.imagePath,
    this.icon,
    required this.label,
    required this.isDark,
    this.isLoading = false,
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
          child: isLoading
              // v23.1 part 200 — spinner inline (remplace icon+label) sur
              // CE bouton uniquement quand son provider est en cours
              ? SizedBox(
                  width: 20.sp,
                  height: 20.sp,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isAppleButton ? Colors.white : AppColors.primaryColor,
                    ),
                  ),
                )
              : Row(
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
