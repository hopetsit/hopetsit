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

  /// Map service value to a Material icon
  IconData _serviceIcon(String value) {
    switch (value) {
      case 'dog_walking':
        return Icons.pets_rounded;
      case 'pet_sitting':
        return Icons.home_rounded;
      case 'house_sitting':
        return Icons.house_rounded;
      case 'day_care':
        return Icons.child_care_rounded;
      default:
        return Icons.miscellaneous_services_rounded;
    }
  }

  /// Map service value to an accent color
  Color _serviceColor(String value) {
    switch (value) {
      case 'dog_walking':
        return const Color(0xFF4CAF50);
      case 'pet_sitting':
        return const Color(0xFF2196F3);
      case 'house_sitting':
        return const Color(0xFF9C27B0);
      case 'day_care':
        return const Color(0xFFFF9800);
      default:
        return AppColors.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (email.isEmpty) {
      debugPrint('[HOPETSIT] ⚠️ ChooseServiceScreen: Empty email provided');
    }

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
      if (Get.isRegistered<ChooseServiceController>(tag: userType)) {
        final existingController = Get.find<ChooseServiceController>(
          tag: userType,
        );
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
          permanent: true,
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
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: PoppinsText(
                    text: 'choose_service_choose_all'.tr,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8.h),

              // Subtitle
              InterText(
                text: 'choose_service_subtitle'.tr,
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary(context),
              ),

              SizedBox(height: 20.h),

              // Service Options — modern grid-style cards
              Expanded(
                child: SingleChildScrollView(
                  child: Obx(
                    () => Column(
                      children: controller.services.map((service) {
                        final isSelected = controller.selectedServices.contains(
                          service.value,
                        );
                        final color = _serviceColor(service.value);
                        final icon = _serviceIcon(service.value);

                        return Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: GestureDetector(
                            onTap: () => controller.selectService(service.value),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: double.infinity,
                              padding: EdgeInsets.all(16.w),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? color.withOpacity(0.06)
                                    : AppColors.card(context),
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(
                                  color: isSelected ? color : AppColors.divider(context),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color.withOpacity(0.15),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : AppColors.cardShadow(context),
                              ),
                              child: Row(
                                children: [
                                  // Service icon
                                  Container(
                                    width: 52.w,
                                    height: 52.w,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? color.withOpacity(0.15)
                                          : color.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(14.r),
                                    ),
                                    child: Icon(
                                      icon,
                                      size: 26.sp,
                                      color: isSelected ? color : color.withOpacity(0.6),
                                    ),
                                  ),
                                  SizedBox(width: 14.w),

                                  // Title + subtitle
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        PoppinsText(
                                          text: service.titleKey.tr,
                                          fontSize: 15.sp,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? color
                                              : AppColors.textPrimary(context),
                                        ),
                                        SizedBox(height: 2.h),
                                        InterText(
                                          text: service.subtitleKey.tr,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w400,
                                          color: AppColors.textSecondary(context),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Checkmark
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 28.w,
                                    height: 28.w,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected ? color : Colors.transparent,
                                      border: Border.all(
                                        color: isSelected ? color : AppColors.greyColor.withOpacity(0.3),
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? Icon(
                                            Icons.check_rounded,
                                            size: 16.sp,
                                            color: Colors.white,
                                          )
                                        : null,
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

              // Selected count
              Obx(() {
                final count = controller.selectedServices.length;
                if (count > 0) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 8.h),
                    child: Center(
                      child: InterText(
                        text: '$count ${'choose_service_selected_count'.tr}',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),

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

              SizedBox(height: 30.h),
            ],
          ),
        ),
      ),
    );
  }
}
