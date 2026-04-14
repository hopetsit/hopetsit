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
      backgroundColor: AppColors.whiteColor,
      body: SafeArea(
        child: Center(
          child: Column(
            // mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(children: [BackButton()]),
              SizedBox(height: 60.h),
              PoppinsText(
                text: 'sign_up'.tr,
                fontSize: 26.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.blackColor,
              ),
              SizedBox(height: 40.h),
              GestureDetector(
                onTap: () => Get.off(() => SignUpScreen(userType: 'pet_owner')),
                child: Container(
                  height: 200.h,
                  width: 200.w,
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: AppColors.whiteColor,
                    border: Border.all(color: AppColors.primaryColor, width: 1),
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryColor.withOpacity(0.2),
                        spreadRadius: 1,
                        offset: Offset(0, 4),
                        blurRadius: 2,
                      ),
                    ],
                  ),

                  child: Column(
                    children: [
                      Image.asset(
                        AppImages.petOwner,
                        height: 130.h,
                        fit: BoxFit.cover,
                      ),
                      PoppinsText(text: 'role_pet_owner'.tr),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 30.h),
              GestureDetector(
                onTap: () =>
                    Get.off(() => SignUpScreen(userType: 'pet_sitter')),
                child: Container(
                  height: 200.h,
                  width: 200.w,
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: AppColors.whiteColor,
                    border: Border.all(color: AppColors.primaryColor, width: 1),
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryColor.withOpacity(0.2),
                        spreadRadius: 1,
                        offset: Offset(0, 4),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Image.asset(
                        AppImages.petSitter,
                        height: 130.h,
                        fit: BoxFit.cover,
                      ),
                      PoppinsText(text: 'role_pet_sitter'.tr),
                    ],
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
