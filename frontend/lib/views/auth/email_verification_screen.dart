import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:pinput/pinput.dart';
import 'package:hopetsit/controllers/email_verification_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

/// v569 — RENDU SEULEMENT. Le contrôleur, la longueur du code (4), le
/// `onCompleted`, `resendCode`, le compte à rebours, le `PopScope` et
/// `resetVerificationState()` sont inchangés.
///
/// Ce qui change : en-tête aéré (pastille + titre 26/800 + e-mail masqué dans
/// une puce), cases de code plus larges et lisibles (le collage du code
/// complet reste géré par Pinput), compte à rebours du renvoi bien visible,
/// bouton principal collé en bas et JAMAIS masqué par le clavier, et les deux
/// textes qui restaient en anglais en dur (« Resend », « Continue ») passent
/// par `.tr`.
class EmailVerificationScreen extends StatelessWidget {
  final String email;
  final String userType;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.userType,
  });

  @override
  Widget build(BuildContext context) {
    // Check if controller is already registered, if not create it
    final controller =
        Get.isRegistered<EmailVerificationController>(tag: userType)
        ? Get.find<EmailVerificationController>(tag: userType)
        : Get.put(
            EmailVerificationController(email: email, userType: userType),
            tag: userType,
            permanent: true, // Prevents disposal during navigation
          );

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultPinTheme = PinTheme(
      margin: EdgeInsets.symmetric(horizontal: 6.w),
      width: 62.w,
      height: 66.h,
      textStyle: TextStyle(
        fontSize: 28.sp,
        color: AppColors.textPrimary(context),
        fontWeight: FontWeight.w700,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? AppColors.dividerDark : const Color(0xFFE2E5EA),
        ),
        borderRadius: BorderRadius.circular(16.r),
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

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // Clear OTP state when going back
          controller.resetVerificationState();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffold(context),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 22.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 26.h),

                      // ── Pastille ronde teintée + icône ──
                      Container(
                        width: 62.w,
                        height: 62.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryColor
                              .withValues(alpha: isDark ? 0.18 : 0.10),
                        ),
                        child: Icon(
                          Icons.mark_email_unread_outlined,
                          size: 30.sp,
                          color: AppColors.primaryColor,
                        ),
                      ),
                      SizedBox(height: 18.h),

                      // Title
                      PoppinsText(
                        text: 'email_verif_title'.tr,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary(context),
                        maxLines: 2,
                      ),
                      SizedBox(height: 8.h),

                      // Instructions
                      InterText(
                        text: 'email_verif_enter_code'.tr,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary(context),
                        maxLines: 3,
                      ),
                      SizedBox(height: 12.h),

                      // Masked Email — dans une puce pour bien se détacher
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 7.h,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.surfaceDark
                              : Colors.white,
                          borderRadius: BorderRadius.circular(99.r),
                          border: Border.all(
                            color: AppColors.divider(context),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.alternate_email_rounded,
                              size: 15.sp,
                              color: AppColors.textSecondary(context),
                            ),
                            SizedBox(width: 6.w),
                            Flexible(
                              child: InterText(
                                text: controller.getMaskedEmail(),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary(context),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 36.h),

                      // Pin Input — centré, cases larges
                      Center(
                        child: Pinput(
                          controller: controller.pinController,
                          length: 4,
                          defaultPinTheme: defaultPinTheme,
                          focusedPinTheme: focusedPinTheme,
                          submittedPinTheme: submittedPinTheme,
                          showCursor: true,
                          onCompleted: (pin) =>
                              controller.handleVerificationWithNavigation(),
                          keyboardType: TextInputType.number,
                        ),
                      ),

                      SizedBox(height: 28.h),

                      // Resend Code — compte à rebours bien visible
                      Obx(
                        () => Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 9.h,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.surfaceDark
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(99.r),
                              border: Border.all(
                                color: AppColors.divider(context),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  controller.isResendEnabled.value
                                      ? Icons.refresh_rounded
                                      : Icons.timer_outlined,
                                  size: 16.sp,
                                  color: controller.isResendEnabled.value
                                      ? AppColors.primaryColor
                                      : AppColors.textSecondary(context),
                                ),
                                SizedBox(width: 7.w),
                                InterText(
                                  text: 'email_verif_resend_in'.tr,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary(context),
                                ),
                                SizedBox(width: 5.w),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: controller.isResendEnabled.value
                                      ? controller.resendCode
                                      : null,
                                  child: InterText(
                                    text: controller.isResendEnabled.value
                                        ? 'auth569_resend_code'.tr
                                        : controller.formatTime(
                                            controller.countdownSeconds.value,
                                          ),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 28.h),
                    ],
                  ),
                ),
              ),

              // ── Bouton principal : toujours au-dessus du clavier ──
              Padding(
                padding: EdgeInsets.fromLTRB(
                  22.w,
                  0,
                  22.w,
                  18.h + appBottomInsetInsideSafeArea(context),
                ),
                child: CustomButton(
                  height: 54.h,
                  radius: 18.r,
                  title: 'auth569_continue'.tr,
                  onTap: () => controller.handleVerificationWithNavigation(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
