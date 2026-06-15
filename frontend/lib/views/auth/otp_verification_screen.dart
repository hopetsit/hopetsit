import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:pinput/pinput.dart';
import 'package:hopetsit/controllers/otp_verification_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

class OtpVerificationScreen extends StatelessWidget {
  final String email;
  final VerificationType verificationType;
  final String? userType; // Only needed for signup

  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.verificationType,
    this.userType,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('email: $email');
    debugPrint('verificationType: $verificationType');
    debugPrint('userType: $userType');
    // Create a unique tag based on verification type and email
    final tag = '${verificationType.name}_$email';

    // Check if controller is already registered, if not create it
    final controller = Get.isRegistered<OtpVerificationController>(tag: tag)
        ? Get.find<OtpVerificationController>(tag: tag)
        : Get.put(
            OtpVerificationController(
              email: email,
              verificationType: verificationType,
              userType: userType,
            ),
            tag: tag,
            permanent: true, // Prevents disposal during navigation
          );

    // v420 — Daniel : "la page de vérification email ne suit pas le code
    // couleur (que orange) et n'est pas centrée". On colore selon le rôle en
    // cours d'inscription (owner=orange, sitter=bleu, walker=vert) et on centre
    // tout le contenu.
    final Color accent = userType == 'pet_sitter'
        ? AppColors.sitterAccent
        : userType == 'pet_walker'
            ? AppColors.greenColor
            : AppColors.primaryColor;

    final defaultPinTheme = PinTheme(
      width: 48.w,
      height: 52.h,
      margin: EdgeInsets.symmetric(horizontal: 3.w),
      padding: EdgeInsets.zero,
      textStyle: TextStyle(
        fontSize: 22.sp,
        color: AppColors.textPrimary(context),
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider(context)),
        borderRadius: BorderRadius.circular(12.r),
        color: AppColors.inputFill(context),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: accent, width: 1.8),
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: accent),
        color: accent.withValues(alpha: 0.06),
      ),
    );

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          controller.resetVerificationState();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffold(context),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              children: [
                SizedBox(height: 6.h),
                Align(alignment: Alignment.centerLeft, child: BackButton()),
                // Contenu centré verticalement + horizontalement.
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Icône e-mail dans un cercle à la couleur du rôle.
                          Container(
                            width: 76.w,
                            height: 76.w,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.mark_email_unread_rounded,
                                color: accent, size: 38.sp),
                          ),
                          SizedBox(height: 18.h),
                          PoppinsText(
                            text: 'otp_title'.tr,
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 6.h),
                          InterText(
                            text: 'otp_subtitle'.tr,
                            fontSize: 14.sp,
                            color: AppColors.textSecondary(context),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 2.h),
                          InterText(
                            text: controller.getMaskedEmail(),
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: accent,
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 30.h),
                          Pinput(
                            controller: controller.pinController,
                            length: 6,
                            defaultPinTheme: defaultPinTheme,
                            focusedPinTheme: focusedPinTheme,
                            submittedPinTheme: submittedPinTheme,
                            showCursor: true,
                            onCompleted: (pin) =>
                                controller.handleVerificationWithNavigation(),
                            keyboardType: TextInputType.number,
                          ),
                          SizedBox(height: 22.h),
                          Obx(
                            () => Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (!controller.isResendEnabled.value)
                                  InterText(
                                    text: 'otp_resend_in'.tr,
                                    fontSize: 14.sp,
                                    color: AppColors.textSecondary(context),
                                  ),
                                GestureDetector(
                                  onTap: (controller.isResendEnabled.value &&
                                          !controller.isResending.value)
                                      ? controller.resendCode
                                      : null,
                                  child: controller.isResending.value
                                      ? SizedBox(
                                          width: 16.w,
                                          height: 16.h,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    accent),
                                          ),
                                        )
                                      : InterText(
                                          text: controller.isResendEnabled.value
                                              ? 'otp_resend'.tr
                                              : controller.formatTime(controller
                                                  .countdownSeconds.value),
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w700,
                                          color: (controller
                                                      .isResendEnabled.value &&
                                                  !controller.isResending.value)
                                              ? accent
                                              : AppColors.greyColor,
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
                // Bouton Continuer à la couleur du rôle.
                Obx(
                  () => SizedBox(
                    width: double.infinity,
                    height: 52.h,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      onPressed: controller.isLoading.value
                          ? null
                          : () =>
                              controller.handleVerificationWithNavigation(),
                      child: InterText(
                        text: controller.isLoading.value
                            ? 'otp_verifying'.tr
                            : 'otp_continue'.tr,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 30.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
