import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/change_password_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_text_field.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

class ChangePasswordScreen extends StatelessWidget {
  final String userType;

  const ChangePasswordScreen({super.key, this.userType = 'pet_owner'});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ChangePasswordController(userType: userType));

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        leading: BackButton(),
        title: PoppinsText(
          text: 'change_password_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20.w),
                child: Form(
                  key: controller.formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // New Password Field
                      CustomTextField(
                        labelText: 'change_password_new_label'.tr,
                        controller: controller.newPasswordController,
                        hintText: 'label_password'.tr,
                        maxLines: 1,
                        obscureText: true,
                        showPasswordToggle: true,
                        validator: controller.validateNewPassword,
                      ),
                      SizedBox(height: 24.h),

                      // Confirm Password Field
                      CustomTextField(
                        labelText: 'change_password_confirm_label'.tr,
                        controller: controller.confirmPasswordController,
                        hintText: 'change_password_confirm_hint'.tr,
                        maxLines: 1,
                        obscureText: true,
                        showPasswordToggle: true,
                        validator: controller.validateConfirmPassword,
                      ),
                      SizedBox(height: 40.h),
                    ],
                  ),
                ),
              ),
            ),

            // Save Button at bottom
            Padding(
              padding: EdgeInsets.all(20.w),
              child: Obx(
                () => CustomButton(
                  title: controller.isLoading.value ? null : 'common_save'.tr,
                  onTap: !controller.isLoading.value
                      ? () => controller.savePassword()
                      : null,
                  bgColor: AppColors.primaryColor,
                  textColor: AppColors.whiteColor,
                  height: 48.h,
                  radius: 48.r,
                  // Show loading indicator in button
                  child: controller.isLoading.value
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20.w,
                              height: 20.h,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.whiteColor,
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            InterText(
                              text: 'common_saving'.tr,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                              color: AppColors.whiteColor,
                            ),
                          ],
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
