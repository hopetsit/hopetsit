import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/views/auth/sign_up_screen.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Sign-up role selector.
///
/// Displays the 3 available roles — Pet Owner, Pet Sitter, Pet Walker — as
/// distinct cards with their own color tone:
///   • Owner  → primary (warm orange)
///   • Sitter → blue (`sitterAccent`)
///   • Walker → green (`greenColor`)
///
/// Each card's illustration is tinted with the role accent so the 3 cards
/// feel visually distinct even if they share base illustrations.
class SignUpAsScreen extends StatelessWidget {
  const SignUpAsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8.h),
                BackButton(color: AppColors.textPrimary(context)),
                SizedBox(height: 24.h),
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
                SizedBox(height: 32.h),
                _RoleCard(
                  image: AppImages.petOwner,
                  titleKey: 'role_pet_owner',
                  subtitleKey: 'role_pet_owner_desc',
                  iconEmoji: '🏠',
                  accentColor: AppColors.primaryColor,
                  onTap: () => Get.off(() => SignUpScreen(userType: 'pet_owner')),
                ),
                SizedBox(height: 16.h),
                _RoleCard(
                  image: AppImages.petSitter,
                  titleKey: 'role_pet_sitter',
                  subtitleKey: 'role_pet_sitter_desc',
                  iconEmoji: '🛏️',
                  accentColor: AppColors.sitterAccent,
                  onTap: () => Get.off(() => SignUpScreen(userType: 'pet_sitter')),
                ),
                SizedBox(height: 16.h),
                _RoleCard(
                  image: AppImages.petWalker,
                  titleKey: 'role_pet_walker',
                  subtitleKey: 'role_pet_walker_desc',
                  iconEmoji: '🐕‍🦺',
                  accentColor: AppColors.greenColor,
                  onTap: () => Get.off(() => SignUpScreen(userType: 'pet_walker')),
                ),
                SizedBox(height: 32.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Single role card — image with a tonal wash in the role accent color,
/// large emoji badge, and a 2-line subtitle describing the service.
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.image,
    required this.titleKey,
    required this.subtitleKey,
    required this.iconEmoji,
    required this.accentColor,
    required this.onTap,
  });

  final String image;
  final String titleKey;
  final String subtitleKey;
  final String iconEmoji;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: accentColor.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Tinted image tile with emoji badge overlay
            Stack(
              children: [
                Container(
                  width: 96.w,
                  height: 96.h,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16.r),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Base illustration
                        Image.asset(image, fit: BoxFit.cover),
                        // Tonal wash in the role accent
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accentColor.withOpacity(0.25),
                                accentColor.withOpacity(0.05),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Emoji badge bottom-right
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    width: 28.w,
                    height: 28.w,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(iconEmoji, style: TextStyle(fontSize: 13.sp)),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PoppinsText(
                    text: titleKey.tr,
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                  SizedBox(height: 6.h),
                  InterText(
                    text: subtitleKey.tr,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary(context),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18.sp,
              color: accentColor,
            ),
          ],
        ),
      ),
    );
  }
}
