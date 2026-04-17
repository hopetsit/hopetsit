import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/choose_service_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

class ChooseServiceScreen extends StatelessWidget {
  final String userType;
  final String email;
  final bool isFromProfile;

  const ChooseServiceScreen({
    super.key,
    required this.userType,
    required this.email,
    this.isFromProfile = false,
  });

  @override
  Widget build(BuildContext context) {
    // Validate email is provided
    if (email.isEmpty) {
      debugPrint('[HOPETSIT] ⚠️ ChooseServiceScreen: Empty email provided');
    }
    debugPrint(
      '[HOPETSIT] ChooseServiceScreen: email=$email, userType=$userType',
    );

    // Check if controller is already registered, if not create it
    // For profile flow, create a new controller instance without tag
    // For signup flow, always ensure controller has correct email - delete and recreate if needed
    ChooseServiceController controller;
    if (isFromProfile) {
      controller = Get.put(
        ChooseServiceController(
          userType: userType,
          email: email,
          isFromProfile: isFromProfile,
        ),
      );
    } else {
      // For signup flow: if controller exists but email might be different, delete and recreate
      if (Get.isRegistered<ChooseServiceController>(tag: userType)) {
        final existingController = Get.find<ChooseServiceController>(
          tag: userType,
        );
        // If email is different or empty, recreate controller with correct email
        if (existingController.email != email ||
            existingController.email.isEmpty) {
          Get.delete<ChooseServiceController>(tag: userType, force: true);
          controller = Get.put(
            ChooseServiceController(
              userType: userType,
              email: email,
              isFromProfile: isFromProfile,
            ),
            tag: userType,
            permanent: true,
          );
        } else {
          controller = existingController;
        }
      } else {
        controller = Get.put(
          ChooseServiceController(
            userType: userType,
            email: email,
            isFromProfile: isFromProfile,
          ),
          tag: userType,
          permanent: true, // Prevents disposal during navigation
        );
      }
    }

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
            backgroundColor: AppColors.appBar(context),
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: isFromProfile
                ? IconButton(
                    icon: Icon(Icons.arrow_back, color: AppColors.textPrimary(context)),
                    onPressed: () => Get.back(),
                  )
                : null,
            title: PoppinsText(
              text: 'choose_service_title'.tr,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
            actions: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Center(
                  child: GestureDetector(
                    onTap: controller.selectAllServices,
                    child: PoppinsText(
                      text: 'choose_service_choose_all'.tr,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
      // : null,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // if (!isFromProfile) SizedBox(height: 30.h),

              // if (!isFromProfile)
              //   // Title
              //   PoppinsText(
              //     text: 'Choose a Service',
              //     fontSize: 20.sp,
              //     fontWeight: FontWeight.w600,
              //     color: AppColors.blackColor,
              //   ),

              // if (!isFromProfile) SizedBox(height: 32.h),
              // if (isFromProfile)
              SizedBox(height: 20.h),

              SizedBox(height: 32.h),

              // Service Options (multi-select in both flows)
              Expanded(
                child: SingleChildScrollView(
                  child: Obx(
                    () => Column(
                      children: controller.services.map((service) {
                        final isSelected = controller.selectedServices.contains(
                          service.value,
                        );

                        return Padding(
                          padding: EdgeInsets.only(bottom: 16.h),
                          child: GestureDetector(
                            onTap: () =>
                                controller.selectService(service.value),
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(20.w),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primaryColor
                                      : AppColors.divider(context),
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(20.r),
                                color: AppColors.card(context),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  PoppinsText(
                                    text: service.titleKey.tr,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary(context),
                                  ),
                                  SizedBox(height: 4.h),
                                  InterText(
                                    text: service.subtitleKey.tr,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.textSecondary(context).withOpacity(0.6),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),

              // Continue/Save Button
              Obx(
                () => CustomButton(
                  title: controller.isLoading.value
                      ? (isFromProfile
                          ? 'choose_service_saving'.tr
                          : 'choose_service_selecting'.tr)
                      : (isFromProfile
                          ? 'choose_service_save'.tr
                          : 'choose_service_continue'.tr),
                  onTap: controller.isLoading.value
                      ? null
                      : () => isFromProfile
                            ? controller.handleSaveService()
                            : controller.handleContinueWithNavigation(),
                ),
              ),

              SizedBox(height: 40.h),
            ],
          ),
        ),
      ),
    );
  }
}
