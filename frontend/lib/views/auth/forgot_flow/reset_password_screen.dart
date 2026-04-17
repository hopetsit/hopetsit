import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/forgot_password_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_text_field.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/views/auth/forgot_flow/password_reset_success_screen.dart';

class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ForgotPasswordController>();
    final formKey = GlobalKey<FormState>(); // Local form key for this screen

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: PoppinsText(
          text: 'forgot_password_create_new_title'.tr,
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
                text: 'forgot_password_set_new_title'.tr,
                fontSize: 26.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
              SizedBox(height: 8.h),
              InterText(
                text: 'forgot_password_set_new_message'.tr,
                fontSize: 14.sp,
                color: AppColors.textSecondary(context),
              ),
              SizedBox(height: 40.h),

              // New Password Input
              CustomTextField(
                labelText: 'change_password_new_label'.tr,
                hintText: 'forgot_password_new_hint'.tr,
                controller: controller.newPasswordController,
                obscureText: true,
                showPasswordToggle: true,
                textInputAction: TextInputAction.next,
                validator: controller.validatePassword,
                prefixIcon: Icon(
                  Icons.lock_outline,
                  color: AppColors.greyColor,
                ),
              ),
              SizedBox(height: 24.h),

              // Confirm Password Input
              CustomTextField(
                labelText: 'change_password_confirm_label'.tr,
                hintText: 'forgot_password_confirm_hint'.tr,
                controller: controller.confirmPasswordController,
                obscureText: true,
                showPasswordToggle: true,
                textInputAction: TextInputAction.done,
                validator: controller.validateConfirmPassword,
                prefixIcon: Icon(
                  Icons.lock_outline,
                  color: AppColors.greyColor,
                ),
              ),
              SizedBox(height: 16.h),

              // // Password Requirements Info
              // Container(
              //   padding: EdgeInsets.all(16.w),
              //   decoration: BoxDecoration(
              //     color: AppColors.lightGrey,
              //     borderRadius: BorderRadius.circular(12.r),
              //     border: Border.all(color: AppColors.textFieldBorder),
              //   ),
              //   child: Column(
              //     crossAxisAlignment: CrossAxisAlignment.start,
              //     children: [
              //       InterText(
              //         text: 'Password requirements:',
              //         fontSize: 12.sp,
              //         fontWeight: FontWeight.w600,
              //         color: AppColors.blackColor,
              //       ),
              //       SizedBox(height: 8.h),
              //       _buildRequirementItem(
              //         icon: Icons.check_circle_outline,
              //         text: 'At least 8 characters',
              //       ),
              //       _buildRequirementItem(
              //         icon: Icons.check_circle_outline,
              //         text: 'One uppercase letter (A-Z)',
              //       ),
              //       _buildRequirementItem(
              //         icon: Icons.check_circle_outline,
              //         text: 'At least one number (0-9)',
              //       ),
              //     ],
              //   ),
              // ),
              SizedBox(height: 20.h),

              // // Error Message (if any)
              // Obx(
              //   () => controller.errorMessage.value != null
              //       ? Container(
              //           padding: EdgeInsets.all(12.w),
              //           decoration: BoxDecoration(
              //             color: AppColors.errorColor.withOpacity(0.1),
              //             borderRadius: BorderRadius.circular(8.r),
              //             border: Border.all(
              //               color: AppColors.errorColor.withOpacity(0.3),
              //             ),
              //           ),
              //           child: InterText(
              //             text: controller.errorMessage.value!,
              //             fontSize: 13.sp,
              //             color: AppColors.errorColor,
              //           ),
              //         )
              //       : const SizedBox(),
              // ),

              // Reset Password Button
              Obx(
                () => CustomButton(
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
      ),
    );
  }
}
