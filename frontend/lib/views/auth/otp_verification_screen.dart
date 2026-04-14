import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:pinput/pinput.dart';
import 'package:hopetsit/controllers/otp_verification_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

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
    print('email: $email');
    print('verificationType: $verificationType');
    print('userType: $userType');
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

    final defaultPinTheme = PinTheme(
      width: 50.w,
      height: 50.h,
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      textStyle: TextStyle(
        fontSize: 24.sp,
        color: AppColors.blackColor,
        fontWeight: FontWeight.w400,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.grey300Color),
        borderRadius: BorderRadius.circular(12.r),
        color: AppColors.whiteColor,
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: AppColors.primaryColor),
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: AppColors.primaryColor),
        color: AppColors.whiteColor,
      ),
    );

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) {
          // Clear OTP state when going back
          controller.resetVerificationState();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.whiteColor,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                SizedBox(height: 10.h),
                BackButton(),
                SizedBox(height: 10.h),
                PoppinsText(
                  text: 'Email Verification',
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.blackColor,
                ),

                SizedBox(height: 5.h),

                // Instructions
                InterText(
                  text: 'Enter verification code send on',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.blackColor,
                ),

                // Masked Email
                InterText(
                  text: controller.getMaskedEmail(),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.greyText,
                ),

                SizedBox(height: 40.h),

                // Pin Input
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

                SizedBox(height: 24.h),

                // Resend Code
                Obx(
                  () => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!controller.isResendEnabled.value)
                        InterText(
                          text: 'Resend code in: ',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w400,
                          color: AppColors.blackColor,
                        ),
                      GestureDetector(
                        onTap:
                            (controller.isResendEnabled.value &&
                                !controller.isResending.value)
                            ? controller.resendCode
                            : null,
                        child: controller.isResending.value
                            ? SizedBox(
                                width: 16.w,
                                height: 16.h,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primaryColor,
                                  ),
                                ),
                              )
                            : InterText(
                                text: controller.isResendEnabled.value
                                    ? 'Resend'
                                    : controller.formatTime(
                                        controller.countdownSeconds.value,
                                      ),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color:
                                    (controller.isResendEnabled.value &&
                                        !controller.isResending.value)
                                    ? AppColors.primaryColor
                                    : AppColors.greyColor,
                              ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Continue Button
                Obx(
                  () => CustomButton(
                    title: controller.isLoading.value
                        ? 'Verifying...'
                        : 'Continue',
                    onTap: controller.isLoading.value
                        ? null
                        : () => controller.handleVerificationWithNavigation(),
                  ),
                ),

                SizedBox(height: 40.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
