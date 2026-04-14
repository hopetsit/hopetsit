import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/models/task_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

class TaskController extends GetxController {
  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();

  final RxBool isLoading = false.obs;
  final RxBool isFetching = false.obs;

  final RxList<TaskModel> tasks = <TaskModel>[].obs;

  late final OwnerRepository _ownerRepository;

  TaskController() {
    _ownerRepository = Get.find<OwnerRepository>();
  }

  @override
  void onInit() {
    super.onInit();
    getTasks();
  }

  @override
  void onClose() {
    titleController.dispose();
    descriptionController.dispose();
    super.onClose();
  }

  Future<void> getTasks() async {
    isFetching.value = true;

    try {
      final response = await _ownerRepository.getTasks();

      tasks.assignAll(response);
    } catch (e) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'task_fetch_failed'.tr,
      );
    } finally {
      isFetching.value = false;
    }
  }

  Future<void> saveTask() async {
    // Check if both fields are empty
    if (titleController.text.trim().isEmpty &&
        descriptionController.text.trim().isEmpty) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'task_fields_required'.tr,
      );
      return;
    }

    isLoading.value = true;

    try {
      await _ownerRepository.createTask(
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
      );

      Get.back();

      // Clear fields after successful save
      titleController.clear();
      descriptionController.clear();

      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'task_add_success'.tr,
      );

      // Refresh tasks list after creating a new task
      await getTasks();
    } catch (e) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'task_add_failed'.tr,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
