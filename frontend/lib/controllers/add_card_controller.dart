import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/repositories/user_repository.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

class AddCardController extends GetxController {
  final String userType;

  AddCardController({required this.userType})
    : _userRepository = Get.find<UserRepository>();

  final UserRepository _userRepository;

  final formKey = GlobalKey<FormState>();
  final cardHolderController = TextEditingController();
  final cardNumberController = TextEditingController();
  final expDateController = TextEditingController();
  final cvcController = TextEditingController();

  final RxBool isLoading = false.obs;

  @override
  void onClose() {
    cardHolderController.dispose();
    cardNumberController.dispose();
    expDateController.dispose();
    cvcController.dispose();
    super.onClose();
  }

  Future<void> saveCard() async {
    isLoading.value = true;

    try {
      await _userRepository.saveCard(
        holderName: cardHolderController.text.trim(),
        cardNumber: cardNumberController.text.trim(),
        expDate: expDateController.text.trim(),
        cvc: cvcController.text.trim(),
      );

      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'snackbar_text_card_saved_successfully',
      );

      Get.back();
    } on ApiException catch (error) {
      AppLogger.logError('Failed to save card', error: error.message);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: error.message,
      );
    } catch (e) {
      AppLogger.logError('Failed to save card', error: e);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'snackbar_text_failed_to_save_card_please_try_again',
      );
    } finally {
      isLoading.value = false;
    }
  }
}
