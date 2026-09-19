import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/forgot_password_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_text_field.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/views/auth/forgot_flow/forgot_password_otp_screen.dart';
import 'package:hopetsit/views/auth/forgot_flow/forgot_password_screen.dart';

/// v569 — RENDU SEULEMENT : `Get.put(ForgotPasswordController(...))`, la
/// `formKey` locale, `requestPasswordResetOTP`, `startCountdown()` et la
/// navigation vers l'écran de code sont inchangés. Seul le gabarit change
/// (pastille + titre 26/800 + carte + dégagement bas).
class ForgotPasswordEmailScreen extends StatelessWidget {
  const ForgotPasswordEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ForgotPasswordController(Get.find()));
    final formKey = GlobalKey<FormState>(); // Local form key for this screen
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: forgotFlowAppBar(context, 'forgot_password'.tr),
      body: SingleChildScrollView(
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
                icon: Icons.lock_reset_rounded,
                title: 'forgot_password_reset_title'.tr,
                subtitle: 'forgot_password_reset_message'.tr,
              ),
              SizedBox(height: 28.h),

              ForgotFlowCard(
                child: Column(
                  children: [
                    // Email Input
                    CustomTextField(
                      labelText: 'forgot_password_email_label'.tr,
                      hintText: 'hint_email'.tr,
                      controller: controller.emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      validator: controller.validateEmail,
                      radius: 16.r,
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        size: 20.sp,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    SizedBox(height: 18.h),

                    // Send Code Button
                    Obx(
                      () => CustomButton(
                        height: 54.h,
                        radius: 18.r,
                        title: controller.isLoading.value
                            ? 'forgot_password_sending_code'.tr
                            : 'forgot_password_send_code'.tr,
                        onTap: controller.isLoading.value
                            ? null
                            : () async {
                                final success = await controller
                                    .requestPasswordResetOTP(formKey: formKey);
                                if (success) {
                                  controller.startCountdown();
                                  Get.to(
                                    () => const ForgotPasswordOtpScreen(),
                                    transition: Transition.rightToLeft,
                                  );
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 22.h),

              // Back to Login Link
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InterText(
                      text: 'forgot_password_remember'.tr,
                      fontSize: 13,
                      color: AppColors.textSecondary(context),
                    ),
                    TextButton(
                      onPressed: () => Get.back(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 6.w),
                        minimumSize: Size(0, 36.h),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: PoppinsText(
                        text: 'title_login'.tr,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
