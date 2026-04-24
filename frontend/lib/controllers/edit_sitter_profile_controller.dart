import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/repositories/sitter_repository.dart';
import 'package:hopetsit/controllers/sitter_profile_controller.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/services/location_service.dart';

class EditSitterProfileController extends GetxController {
  EditSitterProfileController({
    SitterRepository? sitterRepository,
    GetStorage? storage,
  }) : _sitterRepository =
           sitterRepository ??
           (Get.isRegistered<SitterRepository>()
               ? Get.find<SitterRepository>()
               : throw Exception(
                   'SitterRepository not registered. Please ensure setupDependencies() is called.',
                 )),
       _storage = storage ?? GetStorage();

  final SitterRepository _sitterRepository;
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
  final hourlyRateController = TextEditingController();
  final weeklyRateController = TextEditingController();
  final monthlyRateController = TextEditingController();
  final dailyRateController = TextEditingController();
  final languageController = TextEditingController();

  // Observable state
  final Rx<File?> profileImage = Rx<File?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isFetching = false.obs;
  final RxBool isUploadingImage = false.obs;
  final RxString currentAvatarUrl = ''.obs;
  final RxString selectedCountryCode = '+1'.obs;
  final RxString selectedCurrency = CurrencyHelper.eur.obs;
  final RxList<String> selectedLanguages = <String>[].obs;

  // Location state (mirrors EditOwnerProfileController)
  final LocationService _locationService = LocationService();
  final RxBool isGettingLocation = false.obs;
  final Rxn<double> userLatitude = Rxn<double>();
  final Rxn<double> userLongitude = Rxn<double>();
  final RxString userCity = ''.obs;

  final ImagePicker _picker = ImagePicker();

  final List<String> currencyOptions = CurrencyHelper.supportedCurrencies
      .map((c) => CurrencyHelper.label(c))
      .toList();

  void updateCurrency(String? label) {
    if (label == null || label.isEmpty) return;
    for (final code in CurrencyHelper.supportedCurrencies) {
      if (CurrencyHelper.label(code) == label) {
        selectedCurrency.value = code;
        return;
      }
    }
  }

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
    hourlyRateController.dispose();
    weeklyRateController.dispose();
    monthlyRateController.dispose();
    dailyRateController.dispose();
    languageController.dispose();
    super.onClose();
  }

  /// Loads the current sitter's profile data into the form.
  /// Uses GET /sitters/{id} to fetch the logged-in sitter's profile.
  Future<void> loadProfileData() async {
    isFetching.value = true;

    try {
      // Get sitter ID from storage
      final userProfile = _storage.read<Map<String, dynamic>>(
        StorageKeys.userProfile,
      );
      final sitterId = userProfile?['id']?.toString();

      if (sitterId == null || sitterId.isEmpty) {
        await AuthController.handleLoginRequiredError();
        return;
      }

      // Use GET /sitters/{id} to fetch current sitter's profile
      final response = await _sitterRepository.getSitterProfile(sitterId);

      // Extract profile data from response
      // The response structure is flat with all fields at the root level
      final profileData =
          response['sitter'] as Map<String, dynamic>? ??
          response['profile'] as Map<String, dynamic>? ??
          response;

      // Populate form fields
      nameController.text = profileData['name']?.toString() ?? '';
      emailController.text = profileData['email']?.toString() ?? '';
      phoneController.text =
          profileData['mobile']?.toString() ??
          profileData['phone']?.toString() ??
          '';
      selectedCountryCode.value = profileData['countryCode']?.toString() ?? '';

      // Address + location handling (same pattern as owner):
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

      addressController.text = city.isNotEmpty
          ? '$rawAddress, $city'
          : rawAddress;

      // For the separate Location field, just show the city (or empty)
      locationController.text = city;
      bioController.text = profileData['bio']?.toString() ?? '';

      // Some backends may return skills/language as a List, which .toString()
      // turns into a bracketed string (e.g. [Pet Sitting]). To avoid the
      // bracket-wrapping bug when reopening this screen, normalize both fields
      // to plain strings here.
      final rawSkills = profileData['skills'];
      if (rawSkills is List) {
        skillsController.text = rawSkills.join(', ');
      } else {
        skillsController.text = rawSkills?.toString() ?? '';
      }

      // Small helper: show an empty field instead of "0" / "0.0" so the user
      // can type directly without having to erase the placeholder.
      String fmtRate(dynamic v) {
        if (v == null) return '';
        if (v is num) {
          if (v <= 0) return '';
          // Drop trailing ".0" for integer-valued rates.
          return v == v.truncate() ? v.truncate().toString() : v.toString();
        }
        final s = v.toString();
        final parsed = double.tryParse(s);
        if (parsed == null || parsed <= 0) return s == '0' || s == '0.0' ? '' : s;
        return parsed == parsed.truncate()
            ? parsed.truncate().toString()
            : parsed.toString();
      }

      hourlyRateController.text = fmtRate(profileData['hourlyRate']);
      weeklyRateController.text = fmtRate(profileData['weeklyRate']);
      monthlyRateController.text = fmtRate(profileData['monthlyRate']);
      dailyRateController.text = fmtRate(profileData['dailyRate']);

      // Primary rates endpoint: GET /sitters/me/rates.
      try {
        final ratesResponse = await _sitterRepository.getMyRates();
        final ratesData =
            ratesResponse['rates'] as Map<String, dynamic>? ?? ratesResponse;
        final fetchedHourly = ratesData['hourlyRate'];
        final fetchedWeekly = ratesData['weeklyRate'];
        final fetchedMonthly = ratesData['monthlyRate'];
        String fmt(dynamic v) {
          if (v == null) return '';
          if (v is num) {
            if (v <= 0) return '';
            return v == v.truncate() ? v.truncate().toString() : v.toString();
          }
          final parsed = double.tryParse(v.toString());
          if (parsed == null || parsed <= 0) return '';
          return parsed == parsed.truncate()
              ? parsed.truncate().toString()
              : parsed.toString();
        }
        if (fetchedHourly != null) hourlyRateController.text = fmt(fetchedHourly);
        if (fetchedWeekly != null) weeklyRateController.text = fmt(fetchedWeekly);
        if (fetchedMonthly != null) monthlyRateController.text = fmt(fetchedMonthly);
        final fetchedDaily = ratesData['dailyRate'];
        if (fetchedDaily != null) dailyRateController.text = fmt(fetchedDaily);
      } catch (error) {
        AppLogger.logError('Failed to load sitter rates', error: error);
      }

      // Currency for hourly rate
      final rawCurrency =
          profileData['currency'] ?? profileData['hourlyRateCurrency'];
      if (rawCurrency != null) {
        final code = rawCurrency.toString().trim().toUpperCase();
        if (code == CurrencyHelper.eur) {
          selectedCurrency.value = CurrencyHelper.eur;
        } else {
          selectedCurrency.value = code.isNotEmpty ? code : CurrencyHelper.eur;
        }
      }

      final rawLanguage = profileData['language'];
      if (rawLanguage is List) {
        languageController.text = rawLanguage.join(', ');
      } else {
        languageController.text = rawLanguage?.toString() ?? '';
      }

      // Populate language chips from the language string
      final langText = languageController.text;
      if (langText.isNotEmpty) {
        selectedLanguages.value = langText.split(RegExp(r'[,;]\s*')).where((s) => s.isNotEmpty).toList();
      } else {
        selectedLanguages.clear();
      }

      // Set current avatar URL
      final avatar = profileData['avatar'];
      if (avatar is Map<String, dynamic>) {
        currentAvatarUrl.value = avatar['url']?.toString() ?? '';
      } else if (avatar is String) {
        currentAvatarUrl.value = avatar;
      } else if (profileData['profileImage'] != null) {
        currentAvatarUrl.value = profileData['profileImage'].toString();
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
      // Prepare location payload with coordinates and city (if available)
      Map<String, dynamic>? locationPayload;
      final hasLatLng =
          userLatitude.value != null && userLongitude.value != null;
      final cityText = locationController.text.trim();
      final hasCity = cityText.isNotEmpty || userCity.value.isNotEmpty;

      if (hasLatLng || hasCity) {
        locationPayload = {};

        if (hasLatLng) {
          locationPayload['lat'] = userLatitude.value!;
          locationPayload['lng'] = userLongitude.value!;
        }

        // Prefer the reactive userCity if set, otherwise fall back to controller text
        final cityValue = userCity.value.isNotEmpty ? userCity.value : cityText;
        if (cityValue.isNotEmpty) {
          locationPayload['city'] = cityValue;
        }
      }

      // Parse hourly rate (similar to signup controller)
      double? hourlyRate;
      double? dailyRate;
      double? weeklyRate;
      double? monthlyRate;
      final hourlyRateText = hourlyRateController.text.replaceAll(
        RegExp(r'[^\d.]'),
        '',
      );
      final dailyRateText = dailyRateController.text.replaceAll(
        RegExp(r'[^\d.]'),
        '',
      );
      final weeklyRateText = weeklyRateController.text.replaceAll(
        RegExp(r'[^\d.]'),
        '',
      );
      final monthlyRateText = monthlyRateController.text.replaceAll(
        RegExp(r'[^\d.]'),
        '',
      );
      if (hourlyRateText.isNotEmpty) {
        hourlyRate = double.tryParse(hourlyRateText);
      }
      if (dailyRateText.isNotEmpty) {
        dailyRate = double.tryParse(dailyRateText);
      }
      if (weeklyRateText.isNotEmpty) {
        weeklyRate = double.tryParse(weeklyRateText);
      }
      if (monthlyRateText.isNotEmpty) {
        monthlyRate = double.tryParse(monthlyRateText);
      }

      // Hourly rate must be greater than 0 if provided
      if (hourlyRate != null && hourlyRate <= 0) {
        CustomSnackbar.showError(
          title: 'snackbar_text_invalid_hourly_rate',
          message: 'snackbar_text_hourly_rate_must_be_greater_than_0',
        );
        return false;
      }
      if (dailyRate != null && dailyRate <= 0) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'error_rate_zero'.tr,
        );
        return false;
      }
      if (weeklyRate != null && weeklyRate <= 0) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'snackbar_text_weekly_rate_must_be_greater_than_0'.tr,
        );
        return false;
      }
      if (monthlyRate != null && monthlyRate <= 0) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'snackbar_text_monthly_rate_must_be_greater_than_0'.tr,
        );
        return false;
      }

      // Update profile using the new /sitters/me/profile endpoint
      await _sitterRepository.updateSitterProfileMe(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        mobile: phoneController.text.trim(),
        countryCode: selectedCountryCode.value,
        address: addressController.text.trim().isNotEmpty
            ? addressController.text.trim()
            : null,
        location: locationPayload,
        bio: bioController.text.trim().isNotEmpty
            ? bioController.text.trim()
            : null,
        skills: skillsController.text.trim().isNotEmpty
            ? skillsController.text.trim()
            : null,
        language: languageController.text.trim().isNotEmpty
            ? languageController.text.trim()
            : null,
        // Hourly rate is no longer editable from the UI (sitters work on a
        // min 1-day basis). We send `null` so the backend keeps whatever
        // value is currently stored without overwriting it.
        hourlyRate: null,
        currency: selectedCurrency.value,
      );

      // Primary rates endpoint: PUT /sitters/me/rates.
      if (hourlyRate != null || dailyRate != null || weeklyRate != null || monthlyRate != null) {
        final currentHourly = double.tryParse(
          hourlyRateController.text.replaceAll(RegExp(r'[^\d.]'), ''),
        );
        final currentDaily = double.tryParse(
          dailyRateController.text.replaceAll(RegExp(r'[^\d.]'), ''),
        );
        final currentWeekly = double.tryParse(
          weeklyRateController.text.replaceAll(RegExp(r'[^\d.]'), ''),
        );
        final currentMonthly = double.tryParse(
          monthlyRateController.text.replaceAll(RegExp(r'[^\d.]'), ''),
        );
        await _sitterRepository.setMyRates(
          hourlyRate: hourlyRate ?? currentHourly ?? 0,
          dailyRate: dailyRate ?? currentDaily ?? 0,
          weeklyRate: weeklyRate ?? currentWeekly ?? 0,
          monthlyRate: monthlyRate ?? currentMonthly ?? 0,
        );
      }

      // Note: Profile image is uploaded immediately when picked,
      // so we don't need to upload it again here

      // Reload edit screen profile to get updated data
      await loadProfileData();

      // Also refresh the main sitter profile screen so it picks up
      // the latest bio, location, rating, etc. using GET /sitters/{id}.
      if (Get.isRegistered<SitterProfileController>()) {
        await Get.find<SitterProfileController>().loadMyProfile();
      }

      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'profile_picture_update_success'.tr,
      );

      return true;
    } on ApiException catch (error) {
      AppLogger.logError('Failed to update profile', error: error.message);
      CustomSnackbar.showError(
        title: 'pet_update_failed'.tr,
        message: error.message,
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

  /// Uploads profile image using sitters/me/profile-picture endpoint
  Future<void> uploadProfileImage(File imageFile) async {
    isUploadingImage.value = true;

    try {
      // Use SitterRepository to upload profile picture via sitters/me/profile-picture
      // The API uses "avatar" as the key in multipart request
      await _sitterRepository.updateSitterProfilePicture(imageFile);

      // Reload profile to get updated avatar URL
      await loadProfileData();

      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'profile_picture_update_success'.tr,
      );
    } on ApiException catch (error) {
      AppLogger.logError('Failed to upload image', error: error.message);
      CustomSnackbar.showError(
        title: 'profile_upload_failed'.tr,
        message: error.message,
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

  /// Get user's current location using Google Maps (same behavior as EditOwnerProfileController)
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
          title: 'Location Found',
          message: 'Your city (@city) has been detected'.trParams({
            'city': userCity.value,
          }),
        );

        AppLogger.logInfo(
          'EditSitterProfile location detected: City=${userCity.value}, '
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
        'Error getting location in EditSitterProfile',
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
      // Reload profile data to get the latest from API (already done in validateAndUpdateProfile)
      // Refresh the profile controller if it exists to update the profile screen
      if (Get.isRegistered<SitterProfileController>()) {
        final profileController = Get.find<SitterProfileController>();
        await profileController.loadMyProfile();
      }

      // Add a small delay to ensure snackbar is visible
      await Future.delayed(const Duration(milliseconds: 800));
      Get.back();
    }
  }

  /// v20.0.10 — Save ONLY the sitter rates (daily / weekly / monthly)
  /// without running the full form validation. Used by MyRatesScreen which
  /// doesn't wrap fields in a Form widget so formKey.currentState is null.
  Future<void> updateRatesOnly() async {
    isLoading.value = true;
    try {
      final dailyText =
          dailyRateController.text.trim().replaceAll(',', '.').replaceAll(RegExp(r'[^\d.]'), '');
      final weeklyText =
          weeklyRateController.text.trim().replaceAll(',', '.').replaceAll(RegExp(r'[^\d.]'), '');
      final monthlyText =
          monthlyRateController.text.trim().replaceAll(',', '.').replaceAll(RegExp(r'[^\d.]'), '');
      final hourlyText =
          hourlyRateController.text.trim().replaceAll(',', '.').replaceAll(RegExp(r'[^\d.]'), '');

      final dailyRate = double.tryParse(dailyText) ?? 0;
      final weeklyRate = double.tryParse(weeklyText) ?? 0;
      final monthlyRate = double.tryParse(monthlyText) ?? 0;
      final hourlyRate = double.tryParse(hourlyText) ?? 0;

      if (dailyRate <= 0 && weeklyRate <= 0 && monthlyRate <= 0 && hourlyRate <= 0) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'error_rate_required'.tr,
        );
        return;
      }

      await _sitterRepository.setMyRates(
        hourlyRate: hourlyRate,
        dailyRate: dailyRate,
        weeklyRate: weeklyRate,
        monthlyRate: monthlyRate,
      );

      // Persist chosen currency on the sitter profile too.
      try {
        final chosenCurrency = selectedCurrency.value.isNotEmpty
            ? selectedCurrency.value
            : 'EUR';
        await _sitterRepository.updateSitterProfileMe(
          {'currency': chosenCurrency},
        );
      } catch (_) {
        // non-blocking — rates are already saved.
      }

      if (Get.isRegistered<SitterProfileController>()) {
        await Get.find<SitterProfileController>().loadMyProfile();
      }
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'edit_profile_success_message'.tr,
      );
      Get.back();
    } catch (e) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.toString(),
      );
    } finally {
      isLoading.value = false;
    }
  }
}
