import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:pinput/pinput.dart';
import 'package:hopetsit/controllers/forgot_password_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/views/auth/forgot_flow/reset_password_screen.dart';
import 'package:hopetsit/views/auth/forgot_flow/forgot_password_screen.dart';

/// v569 — RENDU SEULEMENT : longueur du code (6), `otpController`,
/// `verifyPasswordResetOTP`, `resendOTP`, le compte à rebours et le retour
/// « ce n'est pas mon e-mail » sont inchangés. Seules les cases du code,
/// la carte et les espacements changent.
class ForgotPasswordOtpScreen extends StatelessWidget {
  const ForgotPasswordOtpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ForgotPasswordController>();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // 6 cases : on garde de la marge pour l'allemand/polonais et les petits
    // écrans (largeur calculée pour tenir sans défilement horizontal).
    final defaultPinTheme = PinTheme(
      margin: EdgeInsets.symmetric(horizontal: 3.w),
      width: 46.w,
      height: 58.h,
      textStyle: TextStyle(
        fontSize: 22.sp,
        color: AppColors.textPrimary(context),
        fontWeight: FontWeight.w700,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? AppColors.dividerDark : const Color(0xFFE2E5EA),
        ),
        borderRadius: BorderRadius.circular(14.r),
        color: isDark ? AppColors.inputFill(context) : Colors.white,
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: AppColors.primaryColor, width: 1.6),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryColor.withValues(alpha: 0.14),
            blurRadius: 12,
            spreadRadius: -1,
            offset: const Offset(0, 3),
          ),
        ],
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: AppColors.primaryColor, width: 1.4),
        color: isDark
            ? AppColors.inputFill(context)
            : AppColors.primaryColor.withValues(alpha: 0.05),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: forgotFlowAppBar(
        context,
        'forgot_password_verify_code_title'.tr,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          22.w,
          12.h,
          22.w,
          28.h + appBottomInset(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            ForgotFlowHeader(
              icon: Icons.password_rounded,
              title: 'forgot_password_enter_code_title'.tr,
              subtitleWidget: Obx(
                () => InterText(
                  text: 'forgot_password_code_sent_to'.tr
                      .replaceAll('@email', controller.currentEmail.value),
                  fontSize: 14,
                  color: AppColors.textSecondary(context),
                  maxLines: 3,
                ),
              ),
            ),
            SizedBox(height: 28.h),

            ForgotFlowCard(
              child: Column(
                children: [
                  // OTP Input
                  Center(
                    child: Pinput(
                      length: 6,
                      controller: controller.otpController,
                      defaultPinTheme: defaultPinTheme,
                      focusedPinTheme: focusedPinTheme,
                      submittedPinTheme: submittedPinTheme,
                      pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                      showCursor: true,
                      onCompleted: (pin) {
                        // Auto-proceed when 6 digits are entered
                      },
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Verify Button
                  Obx(
                    () => CustomButton(
                      height: 54.h,
                      radius: 18.r,
                      title: controller.isLoading.value
                          ? 'forgot_password_verifying'.tr
                          : 'forgot_password_verify_code_title'.tr,
                      onTap: controller.isLoading.value
                          ? null
                          : () async {
                              final success =
                                  await controller.verifyPasswordResetOTP();
                              if (success) {
                                Get.to(
                                  () => const ResetPasswordScreen(),
                                  transition: Transition.rightToLeft,
                                );
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // Resend Code Section — compte à rebours bien visible
            Center(
              child: Obx(
                () => controller.countdownSeconds.value > 0
                    ? Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 9.h,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.surfaceDark
                              : Colors.white,
                          borderRadius: BorderRadius.circular(99.r),
                          border:
                              Border.all(color: AppColors.divider(context)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 16.sp,
                              color: AppColors.textSecondary(context),
                            ),
                            SizedBox(width: 7.w),
                            Flexible(
                              child: InterText(
                                text: 'forgot_password_resend_in'.tr
                                    .replaceAll(
                                  '@seconds',
                                  controller.countdownSeconds.value.toString(),
                                ),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary(context),
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                      )
                    : TextButton(
                        onPressed: controller.isResending.value
                            ? null
                            : () => controller.resendOTP(),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryColor,
                          minimumSize: Size(0, 44.h),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Obx(
                              () => controller.isResending.value
                                  ? Padding(
                                      padding: EdgeInsets.only(right: 8.w),
                                      child: SizedBox(
                                        width: 16.w,
                                        height: 16.h,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            AppColors.primaryColor,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Icon(Icons.refresh_rounded, size: 18.sp),
                            ),
                            SizedBox(width: 4.w),
                            PoppinsText(
                              text: 'forgot_password_resend_code'.tr,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryColor,
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            SizedBox(height: 10.h),

            // Change Email Link
            Center(
              child: TextButton(
                onPressed: () => Get.back(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  minimumSize: Size(0, 40.h),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: InterText(
                        text: 'forgot_password_wrong_email'.tr,
                        fontSize: 13,
                        color: AppColors.textSecondary(context),
                        maxLines: 2,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Flexible(
                      child: PoppinsText(
                        text: 'forgot_password_change_email'.tr,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryColor,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
