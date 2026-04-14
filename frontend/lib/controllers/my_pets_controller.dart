import 'package:get/get.dart';
import 'package:hopetsit/models/pet_model.dart';
import 'package:hopetsit/repositories/pet_repository.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

class MyPetsController extends GetxController {
  MyPetsController({PetRepository? petRepository})
    : _petRepository = petRepository ?? Get.find<PetRepository>();

  final PetRepository _petRepository;

  final RxBool isLoading = false.obs;
  final RxList<PetModel> pets = <PetModel>[].obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadMyPets();
  }

  Future<void> loadMyPets() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final response = await _petRepository.getMyPets();
      // Clear and reassign to ensure observable updates
      pets.clear();
      pets.addAll(response);
    } catch (e) {
      errorMessage.value = e.toString();
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'my_pets_load_error'.tr,
      );
      pets.clear();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshPets() async {
    await loadMyPets();
  }
}
