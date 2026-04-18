import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/task_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_text_field.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

class AddTaskScreen extends StatelessWidget {
  const AddTaskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(TaskController());

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
          text: 'add_task_title'.tr,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Field
                    CustomTextField(
                      labelText: 'add_task_title_label'.tr,
                      controller: controller.titleController,
                      hintText: 'add_task_title_hint'.tr,
                      maxLines: 1,
                    ),
                    SizedBox(height: 24.h),

                    // Description Field
                    CustomTextField(
                      labelText: 'add_task_description_label'.tr,
                      controller: controller.descriptionController,
                      hintText: 'add_task_description_hint'.tr,
                      maxLines: 4,
                    ),
                    SizedBox(height: 40.h),
                  ],
                ),
              ),
            ),

            // Save Button at bottom
            Padding(
              padding: EdgeInsets.all(20.w),
              child: Obx(
                () => CustomButton(
                  title: controller.isLoading.value ? null : 'add_task_save_button'.tr,
                  onTap: !controller.isLoading.value
                      ? () => controller.saveTask()
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
                              text: 'add_task_saving'.tr,
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
