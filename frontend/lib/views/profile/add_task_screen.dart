import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/task_controller.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';

class AddTaskScreen extends StatelessWidget {
  const AddTaskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(TaskController());

    final accent = currentRoleAccent();
    // v565 — sous-page modernisée (kit Profil).
    return ProfileSubPageScaffold(
      title: 'add_task_title'.tr,
      accent: accent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileInput(
            label: 'add_task_title_label'.tr,
            hint: 'add_task_title_hint'.tr,
            controller: controller.titleController,
            accent: accent,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
          ),
          SizedBox(height: 16.h),
          ProfileInput(
            label: 'add_task_description_label'.tr,
            hint: 'add_task_description_hint'.tr,
            controller: controller.descriptionController,
            accent: accent,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
      bottom: Obx(
        () => ProfilePrimaryButton(
          label: controller.isLoading.value ? 'add_task_saving'.tr : 'add_task_save_button'.tr,
          accent: accent,
          loading: controller.isLoading.value,
          onTap: controller.isLoading.value ? null : () => controller.saveTask(),
          icon: Icons.check_rounded,
        ),
      ),
    );
  }
}
