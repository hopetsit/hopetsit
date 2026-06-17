import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/repositories/pet_repository.dart';
import 'package:hopetsit/controllers/my_pets_controller.dart';
import 'package:hopetsit/controllers/enriched_pet_form_state.dart';
import 'package:hopetsit/models/pet_model.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

class EditPetController extends GetxController {
  final String petId;
  final PetModel? petData;
  final PetRepository _petRepository;

  EditPetController({
    this.petId = '',
    this.petData,
    PetRepository? petRepository,
  }) : _petRepository = petRepository ?? Get.find<PetRepository>();

  /// v428 — true quand aucun petId fourni : l'écran sert de formulaire de
  /// CRÉATION (POST) au lieu d'édition (PUT). Écran unifié create+edit.
  bool get isCreate => petId.trim().isEmpty;

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
  final bioController = TextEditingController();
  final colourController = TextEditingController();

  // Sprint 5 UI step 2 — enriched pet profile.
  static const String emergencyLegalText =
      "J'autorise le petsitter à contacter le vétérinaire d'urgence et à engager les soins nécessaires en cas de danger vital pour mon animal, avec prise en charge financière à ma charge. Je reste joignable à tout moment.";
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

  // v406 refonte — champs enrichis (À propos / Santé / Habitudes).
  final EnrichedPetFormState enriched = EnrichedPetFormState();

  void addVaccination() {
    vaccinationsList.add({'name': '', 'date': ''});
  }

  void removeVaccination(int index) {
    if (index >= 0 && index < vaccinationsList.length) {
      vaccinationsList.removeAt(index);
    }
  }

  void setVaccinationField(int index, String field, String value) {
    if (index < 0 || index >= vaccinationsList.length) return;
    final updated = Map<String, String>.from(vaccinationsList[index]);
    updated[field] = value;
    vaccinationsList[index] = updated;
  }

  // Observable state
  final Rx<File?> petProfileImage = Rx<File?>(null);
  final Rx<String?> selectedCategory = Rx<String?>('Dog');
  final Rx<String?> selectedVaccination = Rx<String?>('Up to Date');
  final RxBool isLoading = false.obs;
  final RxBool isFetching = false.obs;
  final RxBool isUploadingImage = false.obs;
  final RxString currentAvatarUrl = ''.obs;

  final ImagePicker _picker = ImagePicker();

  @override
  void onInit() {
    super.onInit();
    if (petData != null) {
      _populateFormFromPetData(petData!);
      // v445 — Daniel : « tous les onglets du profil animal doivent être
      // MODIFIABLES après enregistrement ». GARANTIE : même quand un pet est
      // passé en argument (affichage instantané), on RECHARGE en silence la
      // fiche COMPLÈTE et fraîche via getPetById → le formulaire montre TOUJOURS
      // 100 % des champs réellement enregistrés (À propos/Santé/Habitudes/
      // Documents), jamais une fiche partielle/périmée → tout reste modifiable.
      if (!isCreate) _refreshFullPetSilently();
    } else if (!isCreate) {
      // Édition d'un animal dont les données ne sont pas passées en argument.
      loadPetData();
    }
    // En création (isCreate && petData == null) : on garde le formulaire vide
    // avec les valeurs par défaut (Dog / Up to Date).
  }

  @override
  void onClose() {
    petNameController.dispose();
    breedController.dispose();
    dateOfBirthController.dispose();
    weightController.dispose();
    heightController.dispose();
    passportNumberController.dispose();
    chipNumberController.dispose();
    medicationAllergiesController.dispose();
    bioController.dispose();
    colourController.dispose();
    enriched.dispose();
    super.onClose();
  }

  void _populateFormFromPetData(PetModel pet) {
    petNameController.text = pet.petName;
    breedController.text = pet.breed;
    dateOfBirthController.text = pet.dob;
    weightController.text = pet.weight;
    heightController.text = pet.height;
    passportNumberController.text = pet.passportNumber;
    chipNumberController.text = pet.chipNumber;
    medicationAllergiesController.text = pet.medicationAllergies;
    bioController.text = pet.bio;
    colourController.text = pet.colour;

    selectedCategory.value =
        _mapCategoryToDropdown(pet.category) ?? pet.category;
    selectedVaccination.value =
        _mapVaccinationToDropdown(pet.vaccination) ?? pet.vaccination;

    currentAvatarUrl.value = pet.avatar.url;

    // Sprint 5 UI step 2 — enriched fields.
    ageController.text = pet.age;
    behaviorController.text = pet.behavior;
    regularVetNameController.text = pet.regularVet.name;
    regularVetPhoneController.text = pet.regularVet.phone;
    regularVetAddressController.text = pet.regularVet.address;
    emergencyVetNameController.text = pet.emergencyVet.name;
    emergencyVetPhoneController.text = pet.emergencyVet.phone;
    emergencyVetAddressController.text = pet.emergencyVet.address;
    emergencyAuthAccepted.value = pet.emergencyInterventionAuthorization;

    // v406 — champs enrichis.
    enriched.populateFrom(pet);
  }

  Future<void> loadPetData() async {
    isFetching.value = true;

    try {
      final pet = await _petRepository.getPetById(petId);
      _populateFormFromPetData(pet);
    } catch (e) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'snackbar_text_failed_to_load_pet_data_please_try_again',
      );
    } finally {
      isFetching.value = false;
    }
  }

  /// v445 — recharge la fiche COMPLÈTE sans spinner (les champs sont déjà
  /// affichés instantanément via [petData]) → met à jour TOUS les champs
  /// enrichis avec les vraies valeurs serveur, pour garantir que tout est
  /// visible et modifiable. Best-effort : garde l'affichage actuel si échec.
  Future<void> _refreshFullPetSilently() async {
    try {
      final pet = await _petRepository.getPetById(petId);
      _populateFormFromPetData(pet);
    } catch (_) {
      // On garde les données passées en argument si l'API échoue.
    }
  }

  Future<void> pickPetProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (image != null) {
        final imageFile = File(image.path);

        if (await imageFile.exists()) {
          petProfileImage.value = imageFile;
        } else {
          CustomSnackbar.showError(
            title: 'snackbar_text_image_error',
            message: 'snackbar_text_selected_image_file_is_not_accessible_please_try_again',
          );
        }
      }
    } catch (error) {
      CustomSnackbar.showError(
        title: 'snackbar_text_image_error',
        message: 'profile_image_pick_failed'.tr,
      );
    }
  }

  /// Deletes the pet's avatar on the server, then reloads the profile.
  Future<void> deletePetAvatar() async {
    isUploadingImage.value = true;
    try {
      await _petRepository.deletePetMedia(
        petId: petId,
        mediaType: 'avatar',
      );
      petProfileImage.value = null;
      await loadPetData();
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'pet_photo_deleted'.tr,
      );
    } on ApiException catch (error) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: error.message,
      );
    } catch (_) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'pet_photo_delete_failed'.tr,
      );
    } finally {
      isUploadingImage.value = false;
    }
  }

  /// Removes a gallery photo for this pet.
  Future<void> deletePetGalleryPhoto(String publicId) async {
    if (publicId.isEmpty) return;
    isUploadingImage.value = true;
    try {
      await _petRepository.deletePetMedia(
        petId: petId,
        mediaType: 'photo',
        publicId: publicId,
      );
      await loadPetData();
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'pet_photo_deleted'.tr,
      );
    } on ApiException catch (error) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: error.message,
      );
    } catch (_) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'pet_photo_delete_failed'.tr,
      );
    } finally {
      isUploadingImage.value = false;
    }
  }

  Future<void> uploadPetImage(File imageFile) async {
    isUploadingImage.value = true;

    try {
      await _petRepository.uploadPetMedia(petId: petId, imageFile: imageFile);

      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'snackbar_text_image_uploaded_successfully',
      );

      await loadPetData();
    } on ApiException catch (error) {
      CustomSnackbar.showError(
        title: 'profile_upload_failed'.tr,
        message: error.message,
      );
    } catch (error) {
      CustomSnackbar.showError(
        title: 'profile_upload_failed'.tr,
        message: 'common_error_generic'.tr,
      );
    } finally {
      isUploadingImage.value = false;
    }
  }

  void setCategory(String? value) {
    selectedCategory.value = value;
  }

  void setVaccination(String? value) {
    selectedVaccination.value = value;
  }

  Future<bool> validateAndUpdateProfile() async {
    if (!formKey.currentState!.validate()) {
      CustomSnackbar.showError(
        title: 'pet_validation_error'.tr,
        message: 'error_invalid_details_message'.tr,
      );
      return false;
    }

    // v23.1.168 — Daniel : "Altura .100 cm" — la string contenait un
    // point décimal en tête (typo / IME). On normalise pour stocker
    // une valeur propre dans Mongo.
    var heightText = heightController.text.trim().replaceAll(',', '.');
    if (heightText.startsWith('.')) heightText = '0$heightText';
    final heightCleaned = heightText.replaceAll(RegExp(r'[^\d.]'), '');
    // v425 — Daniel : "Mes animaux pas modifier". La hauteur était OBLIGATOIRE
    // à l'édition alors que la création (wizard) ne la collecte pas → modifier
    // un animal sans hauteur était IMPOSSIBLE (« hauteur requise »). Désormais
    // optionnelle : on valide seulement qu'elle soit > 0 SI renseignée.
    if (heightCleaned.isNotEmpty) {
      final h = double.tryParse(heightCleaned);
      if (h != null && h <= 0) {
        CustomSnackbar.showError(
          title: 'pet_validation_error'.tr,
          message: 'snackbar_text_height_must_be_greater_than_0',
        );
        return false;
      }
    }

    isLoading.value = true;

    try {
      final petData = <String, dynamic>{
        'petName': petNameController.text.trim(),
        'breed': breedController.text.trim(),
        'dob': dateOfBirthController.text.trim(),
        'weight': weightController.text.trim(),
        'height': heightCleaned,
        'passportNumber': passportNumberController.text.trim(),
        'chipNumber': chipNumberController.text.trim(),
        'medicationAllergies': medicationAllergiesController.text.trim(),
        'category': selectedCategory.value?.toLowerCase(),
        'vaccination': selectedVaccination.value?.toLowerCase(),
        'bio': bioController.text.trim(),
        'colour': colourController.text.trim(),
        // Sprint 5 UI step 2 — enriched fields.
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
        'emergencyAuthorizationText':
            emergencyAuthAccepted.value ? emergencyLegalText : '',
        // v406 — champs enrichis (À propos / Santé / Habitudes).
        ...enriched.toPayload(),
      };

      if (isCreate) {
        // ── CRÉATION (POST) ──────────────────────────────────────────────
        final createResponse =
            await _petRepository.createPetProfile(petData: petData);

        // Extraction du petId nouvellement créé (fallbacks tolérants selon la
        // forme de la réponse backend).
        final newPetId = createResponse['pet']?['_id']?.toString() ??
            createResponse['pet']?['id']?.toString() ??
            createResponse['_id']?.toString() ??
            createResponse['id']?.toString() ??
            createResponse['data']?['pet']?['_id']?.toString() ??
            createResponse['data']?['pet']?['id']?.toString() ??
            createResponse['data']?['_id']?.toString() ??
            createResponse['data']?['id']?.toString();

        // Upload de l'avatar choisi à la création (best-effort, ne bloque pas).
        if (petProfileImage.value != null &&
            newPetId != null &&
            newPetId.isNotEmpty) {
          try {
            await _petRepository.uploadPetCreationMedia(
              petId: newPetId,
              avatar: petProfileImage.value,
            );
          } catch (_) {
            CustomSnackbar.showWarning(
              title: 'common_error'.tr,
              message:
                  'snackbar_text_pet_profile_created_but_media_upload_failed_you_can_add_medi',
            );
          }
        }

        CustomSnackbar.showSuccess(
          title: 'common_success'.tr,
          message: 'snackbar_text_pet_profile_created_successfully',
        );
        return true;
      }

      // ── ÉDITION (PUT) ──────────────────────────────────────────────────
      await _petRepository.updatePet(petId: petId, petData: petData);

      if (petProfileImage.value != null) {
        try {
          await _petRepository.uploadPetMediaWithQuery(
            petId: petId,
            imageFile: petProfileImage.value!,
          );
          await loadPetData();
        } catch (error) {
          if (error is ApiException) {
            CustomSnackbar.showWarning(
              title: 'common_error'.tr,
              message: 'Profile updated but image upload failed: @error'
                  .trParams({'error': error.message}),
            );
          } else {
            CustomSnackbar.showWarning(
              title: 'common_error'.tr,
              message:
                  'snackbar_text_profile_updated_but_image_upload_failed_please_try_again',
            );
          }
        }
      }

      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'snackbar_text_pet_profile_updated_successfully',
      );

      return true;
    } on ApiException catch (error) {
      CustomSnackbar.showError(
        title: 'pet_update_failed'.tr,
        message: error.message,
      );
      return false;
    } catch (error) {
      CustomSnackbar.showError(
        title: 'pet_update_failed'.tr,
        message: 'common_error_generic'.tr,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  String? _mapCategoryToDropdown(String? apiValue) {
    if (apiValue == null) return null;
    final categories = ['Dog', 'Cat', 'Bird', 'Rabbit', 'Other'];
    if (categories.contains(apiValue)) return apiValue;
    for (final category in categories) {
      if (category.toLowerCase() == apiValue.toLowerCase()) {
        return category;
      }
    }
    return null;
  }

  String? _mapVaccinationToDropdown(String? apiValue) {
    if (apiValue == null) return null;
    final vaccinations = [
      'Up to Date',
      'Not Vaccinated',
      'Partially Vaccinated',
    ];
    if (vaccinations.contains(apiValue)) return apiValue;
    final lowerValue = apiValue.toLowerCase();
    if (lowerValue.contains('up to date') ||
        lowerValue.contains('updated') ||
        lowerValue.contains('current')) {
      return 'Up to Date';
    } else if (lowerValue.contains('not') ||
        lowerValue.contains('none') ||
        lowerValue.contains('unvaccinated')) {
      return 'Not Vaccinated';
    } else if (lowerValue.contains('partial') || lowerValue.contains('some')) {
      return 'Partially Vaccinated';
    }
    return null;
  }

  Future<void> handleUpdateProfileWithNavigation() async {
    final success = await validateAndUpdateProfile();

    if (success) {
      // v428 — écran unifié create+edit : on rafraîchit « Mes animaux » PUIS on
      // revient une seule fois avec result:true (les appelants — Mes animaux,
      // fiche animal — déclenchent un refresh sur ce résultat). Le précédent
      // double Get.back() faisait sauter un écran en trop en mode création.
      if (Get.isRegistered<MyPetsController>()) {
        try {
          await Get.find<MyPetsController>().refreshPets();
        } catch (_) {
          // Silently fail if controller not found.
        }
      }

      await Future.delayed(const Duration(milliseconds: 400));
      Get.back(result: true);
    }
  }
}
