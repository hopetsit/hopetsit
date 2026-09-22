import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/forgot_password_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/widgets/custom_text_field.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/views/auth/forgot_flow/password_reset_success_screen.dart';
import 'package:hopetsit/views/auth/forgot_flow/forgot_password_screen.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';

/// v569 — RENDU SEULEMENT : la `formKey` locale, les deux contrôleurs de mot
/// de passe, `validatePassword` / `validateConfirmPassword`, `resetPassword`
/// et la navigation vers l'écran de succès sont inchangés.
///
/// Le bloc « Password requirements » et le bloc d'erreur, tous deux commentés
/// depuis des mois (texte anglais en dur, jamais traduits), ont été retirés :
/// ils n'étaient pas compilés. Les règles de mot de passe restent affichées
/// par le validateur, en 9 langues.
class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ForgotPasswordController>();
    final formKey = GlobalKey<FormState>(); // Local form key for this screen

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: forgotFlowAppBar(
        context,
        'forgot_password_create_new_title'.tr,
      ),
      body: PawPatternBackground(
          color: AppColors.activeRoleAccent(),
          child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          22.w,
          12.h,
          22.w,
          28.h + appBottomInset(context),
        ),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              ForgotFlowHeader(
                icon: Icons.shield_moon_outlined,
                title: 'forgot_password_set_new_title'.tr,
                subtitle: 'forgot_password_set_new_message'.tr,
              ),
              SizedBox(height: 28.h),

              ForgotFlowCard(
                child: Column(
                  children: [
                    // New Password Input
                    CustomTextField(
                      labelText: 'change_password_new_label'.tr,
                      hintText: 'forgot_password_new_hint'.tr,
                      controller: controller.newPasswordController,
                      obscureText: true,
                      showPasswordToggle: true,
                      textInputAction: TextInputAction.next,
                      validator: controller.validatePassword,
                      radius: 16.r,
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        size: 20.sp,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Confirm Password Input
                    CustomTextField(
                      labelText: 'change_password_confirm_label'.tr,
                      hintText: 'forgot_password_confirm_hint'.tr,
                      controller: controller.confirmPasswordController,
                      obscureText: true,
                      showPasswordToggle: true,
                      textInputAction: TextInputAction.done,
                      validator: controller.validateConfirmPassword,
                      radius: 16.r,
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        size: 20.sp,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // Reset Password Button
                    Obx(
                      () => CustomButton(
                        height: 54.h,
                        radius: 18.r,
                        title: controller.isLoading.value
                            ? 'forgot_password_resetting'.tr
                            : 'forgot_password_reset_button'.tr,
                        onTap: controller.isLoading.value
                            ? null
                            : () async {
                                final success = await controller.resetPassword(
                                  formKey: formKey,
                                );
                                if (success) {
                                  Get.to(
                                    () => const PasswordResetSuccessScreen(),
                                    transition: Transition.rightToLeft,
                                  );
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
        ),
    );
  }
}
