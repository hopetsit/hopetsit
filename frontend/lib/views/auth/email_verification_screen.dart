import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:pinput/pinput.dart';
import 'package:hopetsit/controllers/email_verification_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

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

    final defaultPinTheme = PinTheme(
      margin: EdgeInsets.all(10.w),
      width: 60.w,
      height: 60.h,
      textStyle: TextStyle(
        fontSize: 32.sp,
        color: AppColors.textPrimary(context),
        fontWeight: FontWeight.w400,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider(context)),
        borderRadius: BorderRadius.circular(16.r),
        color: AppColors.inputFill(context),
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
        color: AppColors.inputFill(context),
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
        backgroundColor: AppColors.scaffold(context),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                SizedBox(height: 30.h),
                PoppinsText(
                  text: 'Email Verification',
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),

                SizedBox(height: 5.h),

                // Instructions
                InterText(
                  text: 'Enter verification code send on',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary(context),
                ),

                // Masked Email
                InterText(
                  text: controller.getMaskedEmail(),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary(context).withOpacity(0.6),
                ),

                SizedBox(height: 48.h),

                // Pin Input
                Pinput(
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

                SizedBox(height: 24.h),

                // Resend Code
                Obx(
                  () => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InterText(
                        text: 'Resent code in: ',
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textPrimary(context),
                      ),
                      GestureDetector(
                        onTap: controller.isResendEnabled.value
                            ? controller.resendCode
                            : null,
                        child: InterText(
                          text: controller.isResendEnabled.value
                              ? 'Resend'
                              : controller.formatTime(
                                  controller.countdownSeconds.value,
                                ),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: controller.isResendEnabled.value
                              ? Colors.blue
                              : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Continue Button
                CustomButton(
                  title: 'Continue',
                  onTap: () => controller.handleVerificationWithNavigation(),
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
