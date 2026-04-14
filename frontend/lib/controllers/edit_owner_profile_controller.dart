import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/controllers/profile_controller.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/repositories/user_repository.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/services/location_service.dart';

class EditOwnerProfileController extends GetxController {
  EditOwnerProfileController({
    UserRepository? userRepository,
    GetStorage? storage,
  }) : _userRepository =
           userRepository ??
           (Get.isRegistered<UserRepository>()
               ? Get.find<UserRepository>()
               : throw Exception(
                   'UserRepository not registered. Please ensure setupDependencies() is called.',
                 )),
       _storage = storage ?? GetStorage();

  final UserRepository _userRepository;
  final GetStorage _storage;

  // Form key and controllers
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final locationController = TextEditingController();
  final bioController = TextEditingController();
  final skillsController = TextEditingController();
  final languageController = TextEditingController();

  // Observable state
  final Rx<File?> profileImage = Rx<File?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isFetching = false.obs;
  final RxBool isUploadingImage = false.obs;
  final RxString currentAvatarUrl = ''.obs;
  final RxString selectedCountryCode = ''.obs;
  final RxString _currentUserId = ''.obs;

  // Location state (mirrors SignUpController)
  final LocationService _locationService = LocationService();
  final RxBool isGettingLocation = false.obs;
  final Rxn<double> userLatitude = Rxn<double>();
  final Rxn<double> userLongitude = Rxn<double>();
  final RxString userCity = ''.obs;

  /// Sprint 5 step 2 / UI step 1 — owner service preferences.
  final RxBool servicePrefAtOwner = true.obs;
  final RxBool servicePrefAtSitter = false.obs;

  final ImagePicker _picker = ImagePicker();

  @override
  void onInit() {
    super.onInit();
    loadProfileData();
  }

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    addressController.dispose();
    locationController.dispose();
    bioController.dispose();
    skillsController.dispose();
    languageController.dispose();
    super.onClose();
  }

  /// Loads the current sitter's profile data into the form.
  /// Uses GET /sitters/{id} to fetch the logged-in sitter's profile.
  Future<void> loadProfileData() async {
    isFetching.value = true;

    try {
      final userProfile = _storage.read<Map<String, dynamic>>(
        StorageKeys.userProfile,
      );

      // Use GET /users/me/profile to fetch current owner's profile
      final response = await _userRepository.getMyProfile();

      // Extract profile data from response
      // The response structure is flat with all fields at the root level
      final profileData =
          response['profile'] as Map<String, dynamic>? ?? response;

      // Capture current user id for update calls
      _currentUserId.value =
          profileData['id']?.toString() ?? userProfile?['id']?.toString() ?? '';

      // Populate form fields
      nameController.text = profileData['name']?.toString() ?? '';
      emailController.text = profileData['email']?.toString() ?? '';
      phoneController.text =
          profileData['mobile']?.toString() ??
          profileData['phone']?.toString() ??
          '';

      // Address + location handling
      // Backend returns location as an object, e.g.:
      // \"location\": { \"type\": \"Point\", \"coordinates\": [...], \"city\": \"Islamabad\" }
      // We want to render address like: \"{address}, {location.city}\" without brackets.
      final rawAddress = profileData['address']?.toString() ?? '';
      final rawLocation = profileData['location'];
      String city = '';
      if (rawLocation is Map<String, dynamic>) {
        city = rawLocation['city']?.toString() ?? '';

        // Extract coordinates if available (GeoJSON [lng, lat])
        final coordinates = rawLocation['coordinates'];
        if (coordinates is List && coordinates.length >= 2) {
          final lng = (coordinates[0] as num?)?.toDouble();
          final lat = (coordinates[1] as num?)?.toDouble();
          if (lat != null) {
            userLatitude.value = lat;
          }
          if (lng != null) {
            userLongitude.value = lng;
          }
        }
      }

      userCity.value = city;

      addressController.text = rawAddress;

      // For the separate Location field, just show the city (or empty)
      locationController.text = city;
      bioController.text = profileData['bio']?.toString() ?? '';

      // Normalize skills/language: if API returns a List, join it to avoid
      // bracketed strings like [Pet Sitting] / [[Pet Sitting]] on reopen.
      final rawSkills = profileData['skills'];
      if (rawSkills is List) {
        skillsController.text = rawSkills.join(', ');
      } else {
        skillsController.text = rawSkills?.toString() ?? '';
      }

      final rawLanguage = profileData['language'];
      if (rawLanguage is List) {
        languageController.text = rawLanguage.join(', ');
      } else {
        languageController.text = rawLanguage?.toString() ?? '';
      }

      selectedCountryCode.value = profileData['countryCode']?.toString() ?? '';

      // Set current avatar URL
      final avatar = profileData['avatar'];
      if (avatar is Map<String, dynamic>) {
        currentAvatarUrl.value = avatar['url']?.toString() ?? '';
      } else if (avatar is String) {
        currentAvatarUrl.value = avatar;
      } else if (profileData['profileImage'] != null) {
        currentAvatarUrl.value = profileData['profileImage'].toString();
      }

      // Sprint 5 UI step 1 — load existing service preferences.
      final prefs = profileData['servicePreferences'];
      if (prefs is Map) {
        servicePrefAtOwner.value = prefs['atOwner'] != false;
        servicePrefAtSitter.value = prefs['atSitter'] == true;
      }
    } on ApiException catch (error) {
      AppLogger.logError('Failed to load profile', error: error.message);
      if (AuthController.isLoginRequiredError(
        error.message,
        statusCode: error.statusCode,
      )) {
        await AuthController.handleLoginRequiredError();
        return;
      }
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'profile_load_error'.tr,
      );
    } catch (error) {
      AppLogger.logError('Failed to load profile', error: error);
      final errorMessage = error.toString();
      if (AuthController.isLoginRequiredError(errorMessage)) {
        await AuthController.handleLoginRequiredError();
        return;
      }
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'profile_load_error'.tr,
      );
    } finally {
      isFetching.value = false;
    }
  }

  /// Picks an image from gallery and uploads it immediately
  Future<void> pickProfileImage(BuildContext context) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        final imageFile = File(image.path);
        profileImage.value = imageFile;

        // Upload the image immediately using uploadProfileImage
        await uploadProfileImage(imageFile);
      }
    } catch (error) {
      AppLogger.logError('Failed to pick image', error: error);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'profile_image_pick_failed'.tr,
      );
    }
  }

  /// Validates and updates the profile
  Future<bool> validateAndUpdateProfile() async {
    if (!formKey.currentState!.validate()) {
      CustomSnackbar.showError(
        title: 'pet_validation_error'.tr,
        message: 'error_invalid_details_message'.tr,
      );
      return false;
    }

    isLoading.value = true;

    try {
      final userId = _currentUserId.value.isNotEmpty
          ? _currentUserId.value
          : (_storage
                    .read<Map<String, dynamic>>(StorageKeys.userProfile)?['id']
                    ?.toString() ??
                '');

      if (userId.isEmpty) {
        await AuthController.handleLoginRequiredError();
        return false;
      }

      final rawPhone = phoneController.text.trim();
      final mobile = rawPhone.startsWith('+')
          ? rawPhone
          : '${selectedCountryCode.value}$rawPhone';

      final payload = <String, dynamic>{
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'mobile': mobile,
      };

      final address = addressController.text.trim();
      final language = languageController.text.trim();
      final bio = bioController.text.trim();
      final skills = skillsController.text.trim();
      final countryCode = selectedCountryCode.value;

      if (address.isNotEmpty) {
        payload['address'] = address;
      }
      if (language.isNotEmpty) {
        payload['language'] = language;
      }
      if (bio.isNotEmpty) {
        payload['bio'] = bio;
      }
      if (skills.isNotEmpty) {
        payload['skills'] = skills;
      }
      if (countryCode.isNotEmpty) {
        payload['countryCode'] = countryCode;
      }

      // Sprint 5 UI step 1 — service preferences.
      payload['servicePreferences'] = {
        'atOwner': servicePrefAtOwner.value,
        'atSitter': servicePrefAtSitter.value,
      };

      // Include location coordinates if available (same format as signup)
      if (userLatitude.value != null && userLongitude.value != null) {
        // Prefer detected city; fall back to what's in the location text field
        final cityForLocation =
            (userCity.value.isNotEmpty
                    ? userCity.value
                    : locationController.text)
                .trim();

        payload['location'] = {
          'lat': userLatitude.value,
          'lng': userLongitude.value,
          if (cityForLocation.isNotEmpty) 'city': cityForLocation,
        };
      }

      await _userRepository.updateUserProfile(userId, payload);

      // Note: Profile image is uploaded immediately when picked,
      // so we don't need to upload it again here

      // Reload profile to get updated data
      await loadProfileData();

      CustomSnackbar.showSuccess(
        title: 'common_success',
        message: 'edit_profile_update_success',
      );

      return true;
    } on ApiException catch (error) {
      AppLogger.logError('Failed to update profile', error: error.message);
      CustomSnackbar.showError(
        title: 'pet_update_failed',
        message: 'common_error_generic',
      );
      return false;
    } catch (error) {
      AppLogger.logError('Failed to update profile', error: error);
      CustomSnackbar.showError(
        title: 'pet_update_failed'.tr,
        message: 'common_error_generic'.tr,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Uploads profile image using /users/me/profile-picture endpoint
  Future<void> uploadProfileImage(File imageFile) async {
    isUploadingImage.value = true;

    try {
      // Upload current user's profile picture
      // The API uses "avatar" as the key in multipart request
      await _userRepository.updateProfilePicture(imageFile);

      // Reload profile to get updated avatar URL
      await loadProfileData();

      CustomSnackbar.showSuccess(
        title: 'common_success',
        message: 'profile_picture_update_success',
      );
    } on ApiException catch (error) {
      AppLogger.logError('Failed to upload image', error: error.message);
      CustomSnackbar.showError(
        title: 'profile_upload_failed',
        message: 'common_error_generic',
      );
    } catch (error) {
      AppLogger.logError('Failed to upload image', error: error);
      CustomSnackbar.showError(
        title: 'profile_upload_failed'.tr,
        message: 'common_error_generic'.tr,
      );
    } finally {
      isUploadingImage.value = false;
    }
  }

  /// Get user's current location using Google Maps (same behavior as SignUpController)
  Future<void> getCurrentLocationFromMaps() async {
    try {
      isGettingLocation.value = true;

      // Get location and city information
      final locationData = await _locationService.getUserLocationWithCity();

      if (locationData != null) {
        userLatitude.value = locationData['latitude'] as double?;
        userLongitude.value = locationData['longitude'] as double?;
        userCity.value = locationData['city'] as String? ?? '';

        // Auto-fill city and address fields
        if (userCity.value.isNotEmpty) {
          locationController.text = userCity.value;
        }

        if (locationData['street'] != null) {
          addressController.text = locationData['street'] as String;
        }

        CustomSnackbar.showSuccess(
          title: 'location_found_title',
          message: 'location_found_message'.trParams({
            'city': userCity.value,
          }),
        );

        AppLogger.logInfo(
          'EditOwnerProfile location detected: City=${userCity.value}, '
          'Lat=${userLatitude.value}, Lon=${userLongitude.value}',
        );
      } else {
        CustomSnackbar.showWarning(
          title: 'snackbar_text_location_not_found',
          message:
              'snackbar_text_could_not_detect_your_location_please_enable_location_servic',
        );
      }
    } catch (e) {
      AppLogger.logError(
        'Error getting location in EditOwnerProfile',
        error: e,
      );
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'map_load_error'.tr,
      );
    } finally {
      isGettingLocation.value = false;
    }
  }

  /// Handles update with navigation
  Future<void> handleUpdateProfileWithNavigation() async {
    final success = await validateAndUpdateProfile();
    if (success) {
      // Refresh profile screen state if it's active
      if (Get.isRegistered<ProfileController>()) {
        final profileController = Get.find<ProfileController>();
        await profileController.loadMyProfile();
      }

      Get.back();
    }
  }
}
