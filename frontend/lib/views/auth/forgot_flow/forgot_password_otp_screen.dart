import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:pinput/pinput.dart';
import 'package:hopetsit/controllers/forgot_password_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/views/auth/forgot_flow/reset_password_screen.dart';

class ForgotPasswordOtpScreen extends StatelessWidget {
  const ForgotPasswordOtpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ForgotPasswordController>();

    final defaultPinTheme = PinTheme(
      margin: EdgeInsets.zero,
      width: 50.w,
      height: 50.h,
      textStyle: TextStyle(
        fontSize: 24.sp,
        color: AppColors.blackColor,
        fontWeight: FontWeight.w500,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.grey300Color),
        borderRadius: BorderRadius.circular(16.r),
        color: AppColors.whiteColor,
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: AppColors.primaryColor),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryColor.withOpacity(0.1),
            blurRadius: 8.r,
            spreadRadius: 2.r,
          ),
        ],
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: AppColors.primaryColor),
        color: AppColors.primaryColor.withOpacity(0.05),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: PoppinsText(
          text: 'forgot_password_verify_code_title'.tr,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        centerTitle: true,
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            PoppinsText(
              text: 'forgot_password_enter_code_title'.tr,
              fontSize: 26.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.blackColor,
            ),
            SizedBox(height: 8.h),
            Obx(
              () => InterText(
                text: 'forgot_password_code_sent_to'.tr
                    .replaceAll('@email', controller.currentEmail.value),
                fontSize: 14.sp,
                color: AppColors.greyColor,
              ),
            ),
            SizedBox(height: 40.h),

            // OTP Input
            Pinput(
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
            SizedBox(height: 40.h),

            // Verify Button
            Obx(
              () => CustomButton(
                title: controller.isLoading.value
                    ? 'forgot_password_verifying'.tr
                    : 'forgot_password_verify_code_title'.tr,
                onTap: controller.isLoading.value
                    ? null
                    : () async {
                        final success = await controller
                            .verifyPasswordResetOTP();
                        if (success) {
                          Get.to(
                            () => const ResetPasswordScreen(),
                            transition: Transition.rightToLeft,
                          );
                        }
                      },
              ),
            ),
            SizedBox(height: 24.h),

            // Resend Code Section
            Center(
              child: Obx(
                () => controller.countdownSeconds.value > 0
                    ? Column(
                        children: [
                          InterText(
                            text: 'forgot_password_resend_in'.tr
                                .replaceAll('@seconds', controller.countdownSeconds.value.toString()),
                            fontSize: 13.sp,
                            color: AppColors.greyColor,
                          ),
                        ],
                      )
                    : TextButton(
                        onPressed: controller.isResending.value
                            ? null
                            : () => controller.resendOTP(),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryColor,
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
                                  : Icon(Icons.refresh, size: 18.sp),
                            ),
                            SizedBox(width: 4.w),
                            PoppinsText(
                              text: 'forgot_password_resend_code'.tr,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            SizedBox(height: 16.h),

            // Change Email Link
            Center(
              child: TextButton(
                onPressed: () => Get.back(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InterText(
                      text: 'forgot_password_wrong_email'.tr,
                      fontSize: 13.sp,
                      color: AppColors.greyColor,
                    ),
                    PoppinsText(
                      text: 'forgot_password_change_email'.tr,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryColor,
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
