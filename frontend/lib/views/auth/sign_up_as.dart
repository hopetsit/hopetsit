import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/views/auth/sign_up_screen.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/widgets/app_text.dart';

class SignUpAsScreen extends StatelessWidget {
  const SignUpAsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8.h),
              BackButton(color: AppColors.textPrimary(context)),
              SizedBox(height: 32.h),
              Center(
                child: PoppinsText(
                  text: 'sign_up'.tr,
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
              ),
              SizedBox(height: 8.h),
              Center(
                child: InterText(
                  text: 'sign_up_as_subtitle'.tr,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary(context),
                ),
              ),
              SizedBox(height: 40.h),
              _buildRoleCard(
                context: context,
                image: AppImages.petOwner,
                titleKey: 'role_pet_owner',
                subtitleKey: 'role_pet_owner_desc',
                onTap: () => Get.off(() => SignUpScreen(userType: 'pet_owner')),
              ),
              SizedBox(height: 20.h),
              _buildRoleCard(
                context: context,
                image: AppImages.petSitter,
                titleKey: 'role_pet_sitter',
                subtitleKey: 'role_pet_sitter_desc',
                onTap: () => Get.off(() => SignUpScreen(userType: 'pet_sitter')),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String image,
    required String titleKey,
    required String subtitleKey,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: AppColors.divider(context),
            width: 1,
          ),
          boxShadow: AppColors.cardShadow(context),
        ),
        child: Row(
          children: [
            // Image
            Container(
              width: 100.w,
              height: 100.h,
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.r),
                child: Image.asset(
                  image,
                  width: 100.w,
                  height: 100.h,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SizedBox(width: 16.w),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PoppinsText(
                    text: titleKey.tr,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                  SizedBox(height: 6.h),
                  InterText(
                    text: subtitleKey.tr,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary(context),
                  ),
                ],
              ),
            ),
            // Arrow
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 20.sp,
              color: AppColors.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
