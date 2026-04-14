import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/views/auth/login_screen.dart';

class PasswordResetSuccessScreen extends StatefulWidget {
  const PasswordResetSuccessScreen({super.key});

  @override
  State<PasswordResetSuccessScreen> createState() =>
      _PasswordResetSuccessScreenState();
}

class _PasswordResetSuccessScreenState extends State<PasswordResetSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 40.h),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 60.h),

                // Success Icon Animation
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 120.w,
                    height: 120.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryColor.withOpacity(0.1),
                    ),
                    child: Icon(
                      Icons.check_circle,
                      size: 80.sp,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ),
                SizedBox(height: 40.h),

                // Success Title
                PoppinsText(
                  text: 'forgot_password_reset_success_title'.tr,
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.blackColor,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.h),

                // Success Message
                InterText(
                  text: 'forgot_password_reset_success_message'.tr,
                  fontSize: 14.sp,
                  color: AppColors.greyColor,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 60.h),

                // Success Checkpoints
                Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: AppColors.lightGrey,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: AppColors.textFieldBorder),
                  ),
                  child: Column(
                    children: [
                      _buildCheckpoint(
                        icon: Icons.mail_outline,
                        title: 'forgot_password_email_verified_title'.tr,
                        subtitle: 'forgot_password_email_verified_subtitle'.tr,
                      ),
                      SizedBox(height: 16.h),
                      Divider(color: AppColors.grey300Color),
                      SizedBox(height: 16.h),
                      _buildCheckpoint(
                        icon: Icons.lock_outline,
                        title: 'forgot_password_password_updated_title'.tr,
                        subtitle:
                            'forgot_password_password_updated_subtitle'.tr,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 60.h),

                // Continue Button
                CustomButton(
                  title: 'forgot_password_login_new_password'.tr,
                  onTap: () {
                    Get.offAll(() => const LoginScreen());
                  },
                ),
                SizedBox(height: 24.h),

                // Info Text
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: AppColors.detailBoxColor,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: const Color(0xFFFFBC11).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: const Color(0xFFFFBC11),
                        size: 20.sp,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: InterText(
                          text: 'forgot_password_security_warning'.tr,
                          fontSize: 12.sp,
                          color: AppColors.greyText,
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
    );
  }

  Widget _buildCheckpoint({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 48.w,
          height: 48.h,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryColor.withOpacity(0.1),
          ),
          child: Icon(icon, color: AppColors.primaryColor, size: 24.sp),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PoppinsText(
                text: title,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.blackColor,
              ),
              SizedBox(height: 2.h),
              InterText(
                text: subtitle,
                fontSize: 12.sp,
                color: AppColors.greyColor,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
