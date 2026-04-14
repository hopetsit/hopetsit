import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_text_field.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/views/auth/forgot_flow/forgot_password_email_screen.dart';
import 'package:hopetsit/views/auth/sign_up_as.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AuthController>();

    return Scaffold(
      // Sprint 6 step 4 — let ThemeData.scaffoldBackgroundColor drive so dark mode works.
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: PoppinsText(
          text: 'title_login'.tr,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        centerTitle: true,
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.language_outlined,
              color: AppColors.blackColor,
            ),
            onPressed: () {
              final currentCode = LocalizationService.getCurrentLanguageCode();
              final entries = LocalizationService.languageLabels.entries
                  .toList();

              Get.defaultDialog(
                title: 'language_dialog_title'.tr,
                backgroundColor: AppColors.whiteColor,
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: entries.map((entry) {
                    final isSelected = entry.key == currentCode;
                    return ListTile(
                      title: InterText(
                        text: entry.value,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w500,
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      onTap: () async {
                        await LocalizationService.updateLocale(entry.key);
                        Get.back();
                        CustomSnackbar.showSuccess(
                          title: 'language_updated_title'.tr,
                          message: 'language_updated_message'.tr,
                        );
                      },
                    );
                  }).toList(),
                ),
                textCancel: 'common_cancel'.tr,
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
              child: Form(
                key: controller.formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PoppinsText(
                      text: 'welcome_back'.tr,
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.blackColor,
                    ),
                    SizedBox(height: 8.h),
                    InterText(
                      text: 'login_subtitle'.tr,
                      fontSize: 14.sp,
                      color: AppColors.greyColor,
                    ),
                    SizedBox(height: 32.h),
                    CustomTextField(
                      labelText: 'label_email'.tr,
                      hintText: 'hint_email'.tr,
                      controller: controller.emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: controller.validateEmail,
                    ),
                    SizedBox(height: 24.h),
                    CustomTextField(
                      labelText: 'label_password'.tr,
                      hintText: 'hint_password_login'.tr,
                      controller: controller.passwordController,
                      obscureText: true,
                      showPasswordToggle: true,
                      textInputAction: TextInputAction.done,
                      validator: controller.validatePassword,
                    ),
                    SizedBox(height: 12.h),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Get.to(
                          () => const ForgotPasswordEmailScreen(),
                          transition: Transition.rightToLeft,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryColor,
                        ),
                        child: InterText(
                          text: 'forgot_password'.tr,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: 40.h),
                    Obx(
                      () => CustomButton(
                        title: controller.isLoading.value
                            ? 'logging_in'.tr
                            : 'title_login'.tr,
                        onTap: controller.isLoading.value
                            ? null
                            : () => controller.handleLoginWithNavigation(),
                      ),
                    ),
                    SizedBox(height: 24.h),

                    // Social Sign In Options
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: AppColors.grey300Color,
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          child: InterText(
                            text: 'or_continue_with'.tr,
                            fontSize: 12.sp,
                            color: AppColors.greyColor,
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: AppColors.grey300Color,
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24.h),

                    // Social Sign In Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                controller.isLoading.value ||
                                    controller.isSocialLoginLoading.value
                                ? null
                                : () => controller.loginWithGoogle(),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.grey300Color),
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  AppImages.googleIcon,
                                  height: 20.sp,
                                  width: 20.sp,
                                  fit: BoxFit.cover,
                                ),
                                SizedBox(width: 8.w),
                                InterText(
                                  text: 'button_google'.tr,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.blackColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (Platform.isIOS) ...[
                          SizedBox(width: 12.w),
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  controller.isLoading.value ||
                                      controller.isSocialLoginLoading.value
                                  ? null
                                  : () => controller.loginWithApple(),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.grey300Color),
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.apple,
                                    size: 20.sp,
                                    color: AppColors.blackColor,
                                  ),
                                  SizedBox(width: 8.w),
                                  InterText(
                                    text: 'button_apple'.tr,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.blackColor,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 24.h),

                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          InterText(
                            text: 'dont_have_account'.tr,
                            fontSize: 13.sp,
                            color: AppColors.greyColor,
                          ),
                          TextButton(
                            onPressed: () =>
                                Get.to(() => const SignUpAsScreen()),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: PoppinsText(
                              text: 'sign_up'.tr,
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
          ),
          Obx(
            () => controller.isSocialLoginLoading.value
                ? Positioned.fill(
                    child: Container(
                      color: AppColors.blackColor.withOpacity(0.3),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
