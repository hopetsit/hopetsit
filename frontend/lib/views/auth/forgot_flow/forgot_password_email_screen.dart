import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/forgot_password_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_text_field.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/views/auth/forgot_flow/forgot_password_otp_screen.dart';

class ForgotPasswordEmailScreen extends StatelessWidget {
  const ForgotPasswordEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ForgotPasswordController(Get.find()));
    final formKey = GlobalKey<FormState>(); // Local form key for this screen
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: PoppinsText(
          text: 'forgot_password'.tr,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
        centerTitle: true,
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              PoppinsText(
                text: 'forgot_password_reset_title'.tr,
                fontSize: 26.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
              SizedBox(height: 8.h),
              InterText(
                text: 'forgot_password_reset_message'.tr,
                fontSize: 14.sp,
                color: AppColors.textSecondary(context),
              ),
              SizedBox(height: 40.h),

              // Email Input
              CustomTextField(
                labelText: 'forgot_password_email_label'.tr,
                hintText: 'hint_email'.tr,
                controller: controller.emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                validator: controller.validateEmail,
                prefixIcon: Icon(
                  Icons.email_outlined,
                  color: AppColors.greyColor,
                ),
              ),
              SizedBox(height: 20.h),

              // Send Code Button
              Obx(
                () => CustomButton(
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
              SizedBox(height: 24.h),

              // Back to Login Link
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InterText(
                      text: 'forgot_password_remember'.tr,
                      fontSize: 13.sp,
                      color: AppColors.textSecondary(context),
                    ),
                    TextButton(
                      onPressed: () => Get.back(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: PoppinsText(
                        text: 'title_login'.tr,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
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
