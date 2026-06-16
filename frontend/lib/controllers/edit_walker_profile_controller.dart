import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hopetsit/controllers/edit_sitter_profile_controller.dart'
    show providerRatesVersion;
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/walker_model.dart';
import 'package:hopetsit/repositories/user_repository.dart';
import 'package:hopetsit/repositories/walker_repository.dart';
import 'package:hopetsit/services/location_service.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// Dedicated controller for the Walker "Edit profile" screen.
///
/// Walkers have a different backend contract than Owners/Sitters:
///   - profile lives under /walkers/me (not /users/me/profile)
///   - pricing is a list of per-duration walkRates (not hourlyRate/dailyRate)
///   - there's no "servicePreferences.atSitter" concept (walkers only work
///     at the owner's side)
///
/// The MVP of this screen exposes a single hourly-ish price (60 min walk)
/// and a single pickup toggle ("I'll pick up the dog at the owner's home").
class EditWalkerProfileController extends GetxController {
  EditWalkerProfileController({
    WalkerRepository? walkerRepository,
    UserRepository? userRepository,
    GetStorage? storage,
  })  : _walkerRepository = walkerRepository ??
            (Get.isRegistered<WalkerRepository>()
                ? Get.find<WalkerRepository>()
                : WalkerRepository(
                    Get.isRegistered<ApiClient>()
                        ? Get.find<ApiClient>()
                        : ApiClient(),
                  )),
        _userRepository = userRepository ??
            (Get.isRegistered<UserRepository>()
                ? Get.find<UserRepository>()
                : null),
        _storage = storage ?? GetStorage();

  final WalkerRepository _walkerRepository;
  final UserRepository? _userRepository;
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
  // v426 — synchro inscription↔profil : champs collectés par le wizard 5 étapes.
  final dobController = TextEditingController();
  final RxList<String> acceptedAnimals = <String>[].obs;
  final RxList<String> experienceTags = <String>[].obs;
  final RxString coverageRadius = '15'.obs;
  // v18.6 — multi-select chips pour la langue, en cohérence avec sitter/owner.
  // Source de vérité : selectedLanguages. languageController.text reste
  // synchronisé (join `, `) pour l'API.
  final RxList<String> selectedLanguages = <String>[].obs;

  /// Walker-specific: price for a 30-minute walk.
  /// Stored as WalkRate{duration:30, basePrice:X, enabled:true}.
  final halfHourRateController = TextEditingController();

  /// Walker-specific: price for a 60-minute walk (the "hourly rate").
  /// Stored as WalkRate{duration:60, basePrice:X, enabled:true}.
  final hourlyRateController = TextEditingController();

  /// v23.1.153 — Daniel : "Faltarían las tarifas para 90 y 120 minutos".
  /// Backend Walker.walkRates accepte deja n'importe quelle duree multiple
  /// de 15min (15-300). On ajoute 2 controllers pour les durees populaires
  /// 90 et 120 min (promenade longue / demi-journee).
  final ninetyMinRateController = TextEditingController();
  final twoHourRateController = TextEditingController();

  /// Additif — surcharge par animal supplémentaire + temps de réponse type.
  /// Persistés via PATCH /walkers/me (updateMyWalkerProfile côté backend).
  final extraPetRateController = TextEditingController();
  final responseTimeController = TextEditingController();

  // Observable state
  final Rx<File?> profileImage = Rx<File?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isFetching = false.obs;
  final RxBool isUploadingImage = false.obs;
  final RxString currentAvatarUrl = ''.obs;
  final RxString selectedCountryCode = ''.obs;
  final RxString _currentUserId = ''.obs;

  // Location state
  final LocationService _locationService = LocationService();
  final RxBool isGettingLocation = false.obs;
  final Rxn<double> userLatitude = Rxn<double>();
  final Rxn<double> userLongitude = Rxn<double>();
  final RxString userCity = ''.obs;

  /// Single pickup toggle for walkers: "I'll pick up at the owner's home".
  /// There's no atSitter option for walkers by design.
  final RxBool pickupAtOwner = true.obs;

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
    dobController.dispose();
    halfHourRateController.dispose();
    hourlyRateController.dispose();
    ninetyMinRateController.dispose();
    twoHourRateController.dispose();
    extraPetRateController.dispose();
    responseTimeController.dispose();
    super.onClose();
  }

  /// Loads the current walker's profile (GET /walkers/me) + rates
  /// (GET /walkers/me/rates). Populates all form controllers.
  Future<void> loadProfileData() async {
    isFetching.value = true;

    try {
      final storedProfile = _storage.read<Map<String, dynamic>>(
        StorageKeys.userProfile,
      );

      final WalkerModel walker =
          await _walkerRepository.getMyWalkerProfile();

      _currentUserId.value =
          walker.id.isNotEmpty ? walker.id : (storedProfile?['id']?.toString() ?? '');

      nameController.text = walker.name;
      emailController.text = walker.email;
      phoneController.text = walker.mobile;
      addressController.text = walker.address;
      locationController.text = walker.city ?? '';
      bioController.text = walker.bio ?? '';
      skillsController.text = walker.skills ?? '';
      languageController.text = walker.language;
      // v18.6 — sync multi-select chips depuis la string serveur.
      final langText = (walker.language).trim();
      if (langText.isNotEmpty) {
        selectedLanguages.value = langText
            .split(RegExp(r'[,;]\s*'))
            .where((s) => s.isNotEmpty)
            .toList();
      } else {
        selectedLanguages.clear();
      }
      userCity.value = walker.city ?? '';

      // v426 — synchro inscription↔profil : recharge les champs du wizard.
      dobController.text = walker.dateOfBirth;
      acceptedAnimals.value = walker.acceptedPetTypes.toList();
      experienceTags.value = walker.experienceTags.toList();
      if (walker.coverageRadiusKm > 0) {
        coverageRadius.value = walker.coverageRadiusKm.toString();
      }

      if (walker.latitude != null) userLatitude.value = walker.latitude;
      if (walker.longitude != null) userLongitude.value = walker.longitude;

      currentAvatarUrl.value = walker.avatar.url;

      // Session v16.3 — trust the backend's stored countryCode first. Previously
      // we regex-extracted it from the mobile string, which caused the picker
      // to desync when the stored number format changed (e.g. flag showing
      // Afghanistan while the number started with +34). Regex stays as a
      // fallback for old accounts that don't have countryCode persisted.
      if (walker.countryCode.isNotEmpty) {
        selectedCountryCode.value = walker.countryCode;
      } else {
        final mobileMatch = RegExp(r'^\+(\d+)').firstMatch(walker.mobile);
        if (mobileMatch != null) {
          selectedCountryCode.value = '+${mobileMatch.group(1)}';
        }
      }

      // Load the four standard walk durations (30/60/90/120 min). Any can
      // be empty — the UI shows "Tarif à confirmer" when none is set.
      // v23.1.153 — ajout 90min + 120min (promenade longue / demi-journee).
      final rates = await _walkerRepository.getMyWalkerRates();
      WalkRate? thirtyMin;
      WalkRate? sixtyMin;
      WalkRate? ninetyMin;
      WalkRate? oneTwentyMin;
      for (final r in rates) {
        if (r.durationMinutes == 30 && r.enabled) thirtyMin = r;
        if (r.durationMinutes == 60 && r.enabled) sixtyMin = r;
        if (r.durationMinutes == 90 && r.enabled) ninetyMin = r;
        if (r.durationMinutes == 120 && r.enabled) oneTwentyMin = r;
      }
      halfHourRateController.text =
          thirtyMin != null ? thirtyMin.basePrice.toStringAsFixed(2) : '';
      hourlyRateController.text =
          sixtyMin != null ? sixtyMin.basePrice.toStringAsFixed(2) : '';
      ninetyMinRateController.text =
          ninetyMin != null ? ninetyMin.basePrice.toStringAsFixed(2) : '';
      twoHourRateController.text =
          oneTwentyMin != null ? oneTwentyMin.basePrice.toStringAsFixed(2) : '';

      // Additif — surcharge par animal + temps de réponse depuis le profil.
      extraPetRateController.text = walker.extraPetRate > 0
          ? walker.extraPetRate.toStringAsFixed(
              walker.extraPetRate == walker.extraPetRate.truncate() ? 0 : 2)
          : '';
      responseTimeController.text = walker.responseTimeMinutes > 0
          ? walker.responseTimeMinutes.toString()
          : '';
    } on ApiException catch (error) {
      AppLogger.logError('Failed to load walker profile',
          error: error.message);
      // Never auto-logout the walker from this screen — show the real reason.
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: error.message.isNotEmpty
            ? error.message
            : 'profile_load_error'.tr,
      );
    } catch (error) {
      AppLogger.logError('Failed to load walker profile', error: error);
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

  /// Uploads profile picture. The backend route /users/me/profile-picture
  /// is `requireAuth` only (no role check) and handled generically; if this
  /// turns out not to resolve walker documents we'll add a walker-scoped
  /// endpoint later.
  Future<void> uploadProfileImage(File imageFile) async {
    final repo = _userRepository;
    if (repo == null) {
      CustomSnackbar.showWarning(
        title: 'common_error'.tr,
        message: 'profile_upload_failed'.tr,
      );
      return;
    }
    isUploadingImage.value = true;
    try {
      await repo.updateProfilePicture(imageFile);
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

  /// Validates and updates the walker profile + the 60-min rate.
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
      final rawPhone = phoneController.text.trim();
      final mobile = rawPhone.startsWith('+')
          ? rawPhone
          : '${selectedCountryCode.value}$rawPhone';

      final payload = <String, dynamic>{
        'name': nameController.text.trim(),
        'mobile': mobile,
      };

      final address = addressController.text.trim();
      final language = languageController.text.trim();
      final bio = bioController.text.trim();
      final skills = skillsController.text.trim();
      final countryCode = selectedCountryCode.value;

      if (address.isNotEmpty) payload['address'] = address;
      if (language.isNotEmpty) payload['language'] = language;
      if (bio.isNotEmpty) payload['bio'] = bio;
      if (skills.isNotEmpty) payload['skills'] = skills;
      if (countryCode.isNotEmpty) payload['countryCode'] = countryCode;

      // v426 — synchro inscription↔profil : champs additifs du wizard 5 étapes.
      payload['dateOfBirth'] = dobController.text.trim();
      payload['acceptedPetTypes'] = acceptedAnimals.toList();
      payload['experienceTags'] = experienceTags.toList();
      final radiusKm = int.tryParse(coverageRadius.value);
      if (radiusKm != null && radiusKm > 0) payload['coverageRadiusKm'] = radiusKm;

      // Walker pickup preference — keep it as a nested object so the backend
      // can ignore gracefully if the field isn't modeled yet.
      payload['pickupPreferences'] = {
        'atOwner': pickupAtOwner.value,
      };

      // Location coordinates
      if (userLatitude.value != null && userLongitude.value != null) {
        final cityForLocation = (userCity.value.isNotEmpty
                ? userCity.value
                : locationController.text)
            .trim();
        payload['location'] = {
          'lat': userLatitude.value,
          'lng': userLongitude.value,
          if (cityForLocation.isNotEmpty) 'city': cityForLocation,
        };
      }

      // Session v16.2 — SAVE ORDER REVERSED. Previously the profile PATCH ran
      // first; if any field (e.g. location) caused a validation error, the
      // rates update was skipped and the walker's hourly price silently
      // disappeared on next login. We now upsert rates FIRST so a broken
      // profile payload can never wipe the rate out of the DB.
      final thirtyText =
          halfHourRateController.text.trim().replaceAll(',', '.');
      final sixtyText = hourlyRateController.text.trim().replaceAll(',', '.');
      final thirtyParsed = double.tryParse(thirtyText);
      final sixtyParsed = double.tryParse(sixtyText);

      // 1. Persist the walk rates (30 min + 60 min). We upsert both tiers in
      // one round-trip. Empty fields are skipped — existing values are
      // preserved.
      if ((thirtyParsed != null && thirtyParsed > 0) ||
          (sixtyParsed != null && sixtyParsed > 0)) {
        try {
          final existing = await _walkerRepository.getMyWalkerRates();
          final byDuration = <int, WalkRate>{
            for (final r in existing) r.durationMinutes: r,
          };

          if (thirtyParsed != null && thirtyParsed > 0) {
            final cur = byDuration[30]?.currency ?? 'EUR';
            byDuration[30] = WalkRate(
              durationMinutes: 30,
              basePrice: thirtyParsed,
              currency: cur,
              enabled: true,
            );
          }
          if (sixtyParsed != null && sixtyParsed > 0) {
            final cur = byDuration[60]?.currency ?? 'EUR';
            byDuration[60] = WalkRate(
              durationMinutes: 60,
              basePrice: sixtyParsed,
              currency: cur,
              enabled: true,
            );
          }
          final sorted = byDuration.values.toList()
            ..sort((a, b) => a.durationMinutes.compareTo(b.durationMinutes));
          await _walkerRepository.updateMyWalkerRates(sorted);
        } catch (rateError) {
          // Don't bury this: a rate save failure is the #1 root cause of
          // "tarif horaire" errors in the request flow.
          AppLogger.logError(
            'Failed to update walker rates (step 1/2)',
            error: rateError,
          );
          rethrow;
        }
      }

      // 2. Update profile fields. If this fails the rate is already safe.
      await _walkerRepository.updateMyWalkerProfile(payload);

      await loadProfileData();

      CustomSnackbar.showSuccess(
        title: 'common_success',
        message: 'edit_profile_update_success',
      );

      return true;
    } on ApiException catch (error) {
      AppLogger.logError('Failed to update walker profile',
          error: error.message);
      CustomSnackbar.showError(
        title: 'pet_update_failed',
        message: error.message.isNotEmpty
            ? error.message
            : 'common_error_generic'.tr,
      );
      return false;
    } catch (error) {
      AppLogger.logError('Failed to update walker profile', error: error);
      CustomSnackbar.showError(
        title: 'pet_update_failed'.tr,
        message: 'common_error_generic'.tr,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Tries to detect the user's location (reverse geocoded to city).
  Future<void> getCurrentLocationFromMaps() async {
    try {
      isGettingLocation.value = true;
      final locationData = await _locationService.getUserLocationWithCity();
      if (locationData != null) {
        userLatitude.value = locationData['latitude'] as double?;
        userLongitude.value = locationData['longitude'] as double?;
        userCity.value = locationData['city'] as String? ?? '';
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
      } else {
        CustomSnackbar.showWarning(
          title: 'snackbar_text_location_not_found',
          message:
              'snackbar_text_could_not_detect_your_location_please_enable_location_servic',
        );
      }
    } catch (e) {
      AppLogger.logError('Error getting location in EditWalkerProfile',
          error: e);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'map_load_error'.tr,
      );
    } finally {
      isGettingLocation.value = false;
    }
  }

  /// Validate + save, then pop back if successful.
  Future<void> handleUpdateProfileWithNavigation() async {
    final success = await validateAndUpdateProfile();
    if (success) {
      Get.back();
    }
  }

  /// v20.0.10 — Save only the walk rates (30 min / 60 min + currency)
  /// without triggering the form-key validation. Used by MyRatesScreen
  /// which renders ONLY the 2 rate fields (no Form ancestor), so calling
  /// the full validateAndUpdateProfile would crash on formKey.currentState
  /// being null.
  Future<void> updateRatesOnly() async {
    isLoading.value = true;
    try {
      final thirtyText =
          halfHourRateController.text.trim().replaceAll(',', '.');
      final sixtyText = hourlyRateController.text.trim().replaceAll(',', '.');
      final ninetyText =
          ninetyMinRateController.text.trim().replaceAll(',', '.');
      final twoHourText =
          twoHourRateController.text.trim().replaceAll(',', '.');
      final thirtyParsed = double.tryParse(thirtyText);
      final sixtyParsed = double.tryParse(sixtyText);
      final ninetyParsed = double.tryParse(ninetyText);
      final twoHourParsed = double.tryParse(twoHourText);

      // v23.1.153 — au moins UN des 4 rates doit etre rempli.
      final hasAny = [thirtyParsed, sixtyParsed, ninetyParsed, twoHourParsed]
          .any((v) => v != null && v > 0);
      if (!hasAny) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'walker_rate_invalid'.tr,
        );
        return;
      }

      final existing = await _walkerRepository.getMyWalkerRates();
      final byDuration = <int, WalkRate>{
        for (final r in existing) r.durationMinutes: r,
      };
      // v20.0.10 — reuse whatever currency exists on the existing rates
      // (or EUR). The walker edit profile screen is where currency picker
      // lives; My Rates screen is for the 2 amounts only.
      final existingCurrency =
          existing.isNotEmpty ? existing.first.currency : 'EUR';

      // v23.1.153 — helper pour eviter la duplication. Si l'utilisateur vide
      // un champ existant (parsed == null/0), on retire le rate de la map.
      void upsertOrRemove(int duration, double? parsed) {
        if (parsed != null && parsed > 0) {
          byDuration[duration] = WalkRate(
            durationMinutes: duration,
            basePrice: parsed,
            currency: byDuration[duration]?.currency ?? existingCurrency,
            enabled: true,
          );
        } else {
          byDuration.remove(duration);
        }
      }

      upsertOrRemove(30, thirtyParsed);
      upsertOrRemove(60, sixtyParsed);
      upsertOrRemove(90, ninetyParsed);
      upsertOrRemove(120, twoHourParsed);

      final sorted = byDuration.values.toList()
        ..sort((a, b) => a.durationMinutes.compareTo(b.durationMinutes));
      await _walkerRepository.updateMyWalkerRates(sorted);

      // Additif — surcharge par animal + temps de réponse (PATCH /walkers/me).
      // Envoyés séparément des walkRates car ce sont des champs profil walker.
      final extraPetText = extraPetRateController.text
          .trim()
          .replaceAll(',', '.')
          .replaceAll(RegExp(r'[^\d.]'), '');
      final responseText =
          responseTimeController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
      final extraPetParsed = double.tryParse(extraPetText);
      final responseParsed = int.tryParse(responseText);
      final profilePatch = <String, dynamic>{};
      if (extraPetParsed != null) profilePatch['extraPetRate'] = extraPetParsed;
      if (responseParsed != null) {
        profilePatch['responseTimeMinutes'] = responseParsed;
      }
      if (profilePatch.isNotEmpty) {
        await _walkerRepository.updateMyWalkerProfile(profilePatch);
      }

      // v20.0.19 — publie le broadcast "rates changed" pour que sitter_homescreen
      // (walker feed aussi) recharge instant sans pull-to-refresh.
      providerRatesVersion.value = providerRatesVersion.value + 1;

      await loadProfileData();
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
