import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/sitter_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

class SitterDetailController extends GetxController {
  SitterDetailController({
    required this.sitterId,
    OwnerRepository? ownerRepository,
  }) : _ownerRepository = ownerRepository ?? Get.find<OwnerRepository>();

  final String sitterId;
  final OwnerRepository _ownerRepository;

  final RxBool isLoading = false.obs;
  final RxBool isStartingChat = false.obs;
  final Rxn<SitterModel> sitter = Rxn<SitterModel>();
  final RxnString errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    loadSitterDetail();
  }

  Future<void> loadSitterDetail() async {
    isLoading.value = true;
    errorMessage.value = null;

    try {
      final sitterData = await _ownerRepository.getSitterDetail(sitterId);
      sitter.value = sitterData;
    } on ApiException catch (error) {
      errorMessage.value = error.message;
      AppLogger.logError('Failed to load sitter detail', error: error.message);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: error.message,
      );
    } catch (error) {
      errorMessage.value = error.toString();
      AppLogger.logError('Failed to load sitter detail', error: error);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'snackbar_text_failed_to_load_sitter_details_please_try_again',
      );
    } finally {
      isLoading.value = false;
    }
  }
}
