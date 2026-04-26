import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/repositories/pet_repository.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/views/pet_owner/bottom_nav/bottom_nav_wrapper.dart';
import 'package:hopetsit/views/pet_sitter/bottom_wrapper/sitter_nav_wrapper.dart';
import 'package:hopetsit/utils/logger.dart';

class CreatePetProfileController extends GetxController {
  final String userType;
  final String serviceType;
  final PetRepository _petRepository;

  CreatePetProfileController({
    required this.userType,
    required this.serviceType,
    PetRepository? petRepository,
  }) : _petRepository = petRepository ?? Get.find<PetRepository>();

  // Form key and controllers
  final formKey = GlobalKey<FormState>();
  final petNameController = TextEditingController();
  final breedController = TextEditingController();
  final dateOfBirthController = TextEditingController();
  final weightController = TextEditingController();
  final heightController = TextEditingController();
  final passportNumberController = TextEditingController();
  final chipNumberController = TextEditingController();
  final medicationAllergiesController = TextEditingController();

  // Sprint 6.5 step 1 — enriched pet profile fields (parity with edit screen).
  final ageController = TextEditingController();
  final behaviorController = TextEditingController();
  final regularVetNameController = TextEditingController();
  final regularVetPhoneController = TextEditingController();
  final regularVetAddressController = TextEditingController();
  final emergencyVetNameController = TextEditingController();
  final emergencyVetPhoneController = TextEditingController();
  final emergencyVetAddressController = TextEditingController();
  final RxBool emergencyAuthAccepted = false.obs;
  final RxList<Map<String, String>> vaccinationsList =
      <Map<String, String>>[].obs;

  void addVaccination() => vaccinationsList.add({'name': '', 'date': ''});
  void removeVaccination(int i) {
    if (i >= 0 && i < vaccinationsList.length) vaccinationsList.removeAt(i);
  }

  void setVaccinationField(int i, String field, String value) {
    if (i < 0 || i >= vaccinationsList.length) return;
    final updated = Map<String, String>.from(vaccinationsList[i]);
    updated[field] = value;
    vaccinationsList[i] = updated;
  }

  // Observable state
  final Rx<File?> petProfileImage = Rx<File?>(null);
  final Rx<File?> passportImage = Rx<File?>(null);
  final RxList<File> petPicturesVideos = <File>[].obs;
  final Rx<String?> selectedCategory = Rx<String?>(null);
  final Rx<String?> selectedVaccination = Rx<String?>(null);
  final Rx<String?> selectedProfileView = Rx<String?>(null);
  // v22.1 — Bug 11a : sexe de l'animal (male / female / null = pas spécifié)
  final Rx<String?> selectedGender = Rx<String?>(null);
  final RxBool isLoading = false.obs;

  final ImagePicker _picker = ImagePicker();

  @override
  void onClose() {
    // Dispose controllers
    petNameController.dispose();
    breedController.dispose();
    dateOfBirthController.dispose();
    weightController.dispose();
    heightController.dispose();
    passportNumberController.dispose();
    chipNumberController.dispose();
    medicationAllergiesController.dispose();
    super.onClose();
  }

  Future<void> pickPetProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        petProfileImage.value = File(image.path);
        AppLogger.logInfo('Pet profile image selected: ${image.path}');
      }
    } catch (error) {
      AppLogger.logError('Failed to pick pet profile image', error: error);
      CustomSnackbar.showError(
        title: 'snackbar_text_image_error',
        message: 'snackbar_text_failed_to_pick_pet_profile_image_please_try_again',
      );
    }
  }

  Future<void> pickPassportImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        passportImage.value = File(image.path);
        AppLogger.logInfo('Passport image selected: ${image.path}');
      }
    } catch (error) {
      AppLogger.logError('Failed to pick passport image', error: error);
      CustomSnackbar.showError(
        title: 'snackbar_text_image_error',
        message: 'snackbar_text_failed_to_pick_passport_image_please_try_again',
      );
    }
  }

  Future<void> pickPetPicturesVideos() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(imageQuality: 85);
      petPicturesVideos.value = images
          .map((image) => File(image.path))
          .toList();
      AppLogger.logInfo(
        'Pet pictures/videos selected: ${petPicturesVideos.length} file(s)',
      );
    } catch (error) {
      AppLogger.logError('Failed to pick pet pictures/videos', error: error);
      CustomSnackbar.showError(
        title: 'snackbar_text_image_error',
        message: 'snackbar_text_failed_to_pick_pet_pictures_or_videos_please_try_again',
      );
    }
  }

  // v22.1 — Bug 11a : setter pour le sexe.
  void setGender(String? value) {
    selectedGender.value = value;
  }

  void setCategory(String? value) {
    selectedCategory.value = value;
  }

  void setVaccination(String? value) {
    selectedVaccination.value = value;
  }

  void setProfileView(String? value) {
    selectedProfileView.value = value;
  }

  Future<bool> validateAndCreateProfile() async {
    AppLogger.logUserAction('Starting pet profile creation validation');

    if (!formKey.currentState!.validate()) {
      AppLogger.logInfo('Pet profile creation failed: Form validation failed');
      CustomSnackbar.showError(
        title: 'pet_create_validation_error'.tr,
        message: 'error_invalid_details_message'.tr,
      );
      return false;
    }

    // Explicit height check (backup: cannot be zero)
    final heightText = heightController.text.trim();
    if (heightText.isNotEmpty) {
      final cleaned = heightText.replaceAll(RegExp(r'[^\d.]'), '');
      if (cleaned.isNotEmpty) {
        final h = double.tryParse(cleaned);
        if (h != null && h <= 0) {
          CustomSnackbar.showError(
            title: 'pet_create_validation_error'.tr,
            message: 'snackbar_text_height_must_be_greater_than_0',
          );
          return false;
        }
      }
    } else {
      CustomSnackbar.showError(
        title: 'pet_create_validation_error'.tr,
        message: 'snackbar_text_height_is_required',
      );
      return false;
    }

    // Validate required dropdowns
    if (selectedCategory.value == null ||
        selectedVaccination.value == null ||
        selectedProfileView.value == null) {
      AppLogger.logInfo(
        'Pet profile creation failed: Required dropdowns not selected',
      );
      CustomSnackbar.showError(
        title: 'pet_create_validation_error'.tr,
        message: 'snackbar_text_please_fill_in_all_required_fields',
      );
      return false;
    }

    isLoading.value = true;
    AppLogger.logUserAction('Pet profile validation passed, starting API call');

    try {
      // Build pet data payload
      final petData = <String, dynamic>{
        'petName': petNameController.text.trim(),
        'breed': breedController.text.trim(),
        'dob': dateOfBirthController.text.trim(),
        'weight': weightController.text.trim(),
        'height': heightController.text.trim(),
        'passportNumber': passportNumberController.text.trim(),
        'chipNumber': chipNumberController.text.trim(),
        // v22.1 — Bug 11a : sexe de l'animal envoyé au backend.
        if (selectedGender.value != null) 'gender': selectedGender.value,
        'medicationAllergies': medicationAllergiesController.text.trim(),
        'category': selectedCategory.value,
        'vaccination': selectedVaccination.value,
        'profileView': selectedProfileView.value,
        if (selectedCategory.value != null) 'colour': '',
        'bio': '',
        // Sprint 6.5 step 1 — enriched fields (parity with edit screen).
        if (ageController.text.trim().isNotEmpty)
          'age': int.tryParse(ageController.text.trim()) ?? 0,
        'behavior': behaviorController.text.trim(),
        'vaccinations': vaccinationsList
            .where((v) => (v['name'] ?? '').trim().isNotEmpty)
            .map((v) => {
                  'name': v['name']!.trim(),
                  if ((v['date'] ?? '').isNotEmpty) 'date': v['date'],
                })
            .toList(),
        'regularVet': {
          'name': regularVetNameController.text.trim(),
          'phone': regularVetPhoneController.text.trim(),
          'address': regularVetAddressController.text.trim(),
        },
        'emergencyVet': {
          'name': emergencyVetNameController.text.trim(),
          'phone': emergencyVetPhoneController.text.trim(),
          'address': emergencyVetAddressController.text.trim(),
        },
        'emergencyInterventionAuthorization': emergencyAuthAccepted.value,
        'emergencyAuthorizationText': emergencyAuthAccepted.value
            ? "J'autorise le petsitter à contacter le vétérinaire d'urgence et à engager les soins nécessaires en cas de danger vital pour mon animal, avec prise en charge financière à ma charge. Je reste joignable à tout moment."
            : '',
      };

      AppLogger.logInfo(
        'Creating pet profile with data: ${petData.keys.join(', ')}',
      );
      final createResponse = await _petRepository.createPetProfile(
        petData: petData,
      );

      // Extract petId from the create pet profile response
      // Response structure: { 'pet': { '_id': '...' } } or { '_id': '...' }
      final petId =
          createResponse['pet']?['_id']?.toString() ??
          createResponse['pet']?['id']?.toString() ??
          createResponse['_id']?.toString() ??
          createResponse['id']?.toString() ??
          createResponse['data']?['pet']?['_id']?.toString() ??
          createResponse['data']?['pet']?['id']?.toString() ??
          createResponse['data']?['_id']?.toString() ??
          createResponse['data']?['id']?.toString();

      if (petId == null || petId.isEmpty) {
        AppLogger.logError(
          'Failed to extract petId from create pet profile response',
          error: createResponse,
        );
        throw ApiException(
          'Pet profile created but petId not found in response. Cannot upload media.',
        );
      }

      final finalPetId = petId; // Ensure non-null for flow analysis
      AppLogger.logInfo('Pet profile created with ID: $finalPetId');

      // Upload pet media/images after profile creation
      // Only upload if at least one file is selected
      if (petProfileImage.value != null ||
          passportImage.value != null ||
          petPicturesVideos.isNotEmpty) {
        AppLogger.logInfo('Uploading pet media/images for petId: $finalPetId');
        try {
          await _petRepository.uploadPetCreationMedia(
            petId: finalPetId,
            avatar: petProfileImage.value,
            passportImage: passportImage.value,
            photos: petPicturesVideos.isNotEmpty
                ? petPicturesVideos.toList()
                : null,
            videos:
                null, // Currently only images are supported via pickMultiImage
          );
          AppLogger.logInfo('Pet media/images uploaded successfully');
        } catch (error) {
          // Log error but don't fail the entire flow
          AppLogger.logError('Failed to upload pet media/images', error: error);
          // Show warning but don't block navigation
          CustomSnackbar.showWarning(
            title: 'common_error'.tr,
            message:
                'snackbar_text_pet_profile_created_but_media_upload_failed_you_can_add_medi',
          );
        }
      }

      AppLogger.logUserAction('Pet profile created successfully');
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'snackbar_text_pet_profile_created_successfully',
      );

      return true;
    } on ApiException catch (error) {
      AppLogger.logError(
        'Pet profile creation failed: API exception',
        error: error.message,
      );
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: error.message,
      );
      return false;
    } catch (error) {
      AppLogger.logError(
        'Pet profile creation failed: Unexpected error',
        error: error,
      );
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'common_error_generic'.tr,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Handles profile creation with navigation logic
  Future<void> handleCreateProfileWithNavigation() async {
    final success = await validateAndCreateProfile();

    if (success) {
      // Navigate to appropriate home screen based on userType
      if (userType == 'sitter') {
        await Get.offAll(() => const SitterNavWrapper());
      } else {
        await Get.offAll(() => const BottomNavWrapper());
      }

      // Clean up permanent controller after leaving the screen.
      // Deleting it before navigation can dispose TextEditingControllers
      // while the form is still rebuilding during the route transition.
      Get.delete<CreatePetProfileController>(
        tag: '$userType-$serviceType',
        force: true,
      );
    }
  }
}
