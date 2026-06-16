import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/repositories/auth_repository.dart';
import 'package:hopetsit/services/location_service.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/views/auth/otp_verification_screen.dart';
import 'package:hopetsit/controllers/otp_verification_controller.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/storage_keys.dart';

class SignUpController extends GetxController {
  SignUpController({
    required this.userType,
    required AuthRepository authRepository,
  }) : _authRepository = authRepository;

  final String userType;
  final AuthRepository _authRepository;
  final LocationService _locationService = LocationService();

  // Sign Up Form key and controllers
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final addressController = TextEditingController();
  final ratePerHourController = TextEditingController();
  final ratePerWeekController = TextEditingController();
  final ratePerMonthController = TextEditingController();
  final skillsController = TextEditingController();
  // v20.0.6 — Walker rates at signup.
  final walkerRate30Controller = TextEditingController();
  final walkerRate60Controller = TextEditingController();
  final cityController = TextEditingController();
  final paypalEmailController = TextEditingController();
  // v20 — Photo de profil uploadée pendant l'inscription. Assignée par
  // _SignupPhotoPicker. Uploadée en post-signup via users/me/profile-picture.
  File? profileImageFile;
  // v409 — avatar réactif (aperçu live dans le wizard). profileImageFile reste
  // synchronisé pour la file d'upload post-OTP.
  final Rxn<File> profileImageRx = Rxn<File>();
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> pickProfileImage() async {
    try {
      final x = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (x != null) {
        final f = File(x.path);
        profileImageRx.value = f;
        profileImageFile = f;
      }
    } catch (_) {/* annulé / refusé */}
  }

  // Observable state - Sign Up
  final RxBool isLoading = false.obs;
  final RxBool isGettingLocation = false.obs;
  final RxBool agreeToTerms = false.obs;
  final RxString selectedLanguage = 'Français'.obs;
  final RxString selectedCountryCode = '+1'.obs;
  /// Sprint 6.5 step 2 — ISO 3166-1 alpha-2 country code (e.g. 'FR').
  /// Populated from CountryCodePicker.onChanged(country.code).
  final RxString selectedCountry = 'US'.obs;

  /// Sprint 7 step 3 — optional referral code entered at signup.
  final TextEditingController referralCodeController = TextEditingController();
  final RxString selectedCurrency = CurrencyHelper.eur.obs;
  final Rxn<double> userLatitude = Rxn<double>();
  final Rxn<double> userLongitude = Rxn<double>();
  final RxString userCity = ''.obs;

  // ─── v409 refonte — inscription en wizard 5 étapes (maquette). 100% additif :
  // ces champs alimentent _buildUserPayload (le backend accepte déjà
  // dateOfBirth/bio/experienceTags/acceptedPetTypes/availableDays/
  // coverageRadiusKm/preferences/searchPreferences/dailyRate via les schémas).
  final dobController = TextEditingController();           // date de naissance
  final confirmPasswordController = TextEditingController();
  final bioController = TextEditingController();            // « À propos de vous »
  final ratePerDayController = TextEditingController();     // sitter : tarif journée (+10h)
  final walkerRate120Controller = TextEditingController();  // walker : tarif 2h
  final extraAnimalController = TextEditingController();    // tarif animal supplémentaire
  final RxInt currentStep = 0.obs;
  final RxString passwordLive = ''.obs;                     // pour la checklist live
  final RxList<String> selectedServices = <String>[].obs;   // services proposés/recherchés
  final RxList<String> acceptedAnimals = <String>[].obs;    // animaux acceptés/promenés
  final RxList<String> availableDays = <String>[].obs;      // walker : disponibilités
  final RxList<String> selectedDurations = <String>[].obs;  // walker : '30' | '60' | '120'
  final RxList<String> experienceTags = <String>[].obs;     // expérience (cases)
  final RxString coverageRadius = '20'.obs;                 // rayon km (recherche/intervention)
  // Préférences owner (toggles maquette).
  final RxBool prefNotifications = true.obs;
  final RxBool prefQuickReplies = true.obs;
  final RxBool prefPhotos = true.obs;
  final RxBool prefInsurance = true.obs;
  final RxBool prefFlexCancel = true.obs;

  void toggleInList(RxList<String> list, String value) {
    if (list.contains(value)) {
      list.remove(value);
    } else {
      list.add(value);
    }
  }

  // v441 — préremplissage région à la PREMIÈRE entrée du wizard. La langue de
  // l'app ET l'indicatif téléphonique sont déduits de la locale du device
  // (Get.deviceLocale) : region ES → langue Español + indicatif +34. On ne fixe
  // QUE la valeur initiale (l'utilisateur reste libre de changer les deux).
  /// ISO 3166-1 alpha-2 du device (ex. 'ES'/'FR'), fallback 'FR'. Utilisé comme
  /// `initialSelection` du CountryCodePicker dans le wizard d'inscription.
  String get initialCountryIso {
    final iso = Get.deviceLocale?.countryCode?.toUpperCase();
    if (iso != null && RegExp(r'^[A-Z]{2}$').hasMatch(iso)) return iso;
    return 'FR';
  }

  @override
  void onInit() {
    super.onInit();
    // Langue de l'app par défaut = langue du device si supportée (sinon on
    // garde 'Français'). Mappe le code locale vers le libellé affiché.
    final lang = Get.deviceLocale?.languageCode;
    if (lang != null) {
      for (final e in _langToLocale.entries) {
        if (e.value == lang) {
          selectedLanguage.value = e.key;
          break;
        }
      }
    }
    // Indicatif + pays par défaut = région du device (ISO-2 → on garde l'ISO
    // pour le CountryCodePicker, qui renverra l'indicatif via onChanged).
    selectedCountry.value = initialCountryIso;
  }

  /// Règles mot de passe (pour la checklist live de l'étape 1).
  bool get pwMinLength => passwordLive.value.length >= 8;
  bool get pwHasUpper => passwordLive.value.contains(RegExp(r'[A-Z]'));
  bool get pwHasDigit => passwordLive.value.contains(RegExp(r'[0-9]'));
  bool get pwHasSpecial =>
      passwordLive.value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-]'));

  // v417 — Daniel : "ya que 3 langues c'est n'importe quoi". L'app gère 6
  // langues (fr/en/es/de/it/pt) → on les propose toutes (et on retire 'Urdu').
  final List<String> languageOptions = const [
    'Français', 'English', 'Español', 'Deutsch', 'Italiano', 'Português',
  ];
  final List<String> currencyOptions = CurrencyHelper.supportedCurrencies
      .map((c) => CurrencyHelper.label(c))
      .toList();

  @override
  void onClose() {
    // Don't dispose controllers here - they should persist during auth flow
    // Since SignUpController is permanent with tags, controllers will persist across navigation
    // They will be cleaned up when the auth flow is complete or user logs out
    super.onClose();
  }

  // v420 — Daniel : "ce n'est pas langue parlée, c'est la langue de l'app, et
  // la changer doit VRAIMENT changer la langue". On mappe le nom affiché vers
  // le code locale et on bascule l'app immédiatement (LocalizationService).
  static const Map<String, String> _langToLocale = {
    'Français': 'fr',
    'English': 'en',
    'Español': 'es',
    'Deutsch': 'de',
    'Italiano': 'it',
    'Português': 'pt',
  };

  void updateLanguage(String? value) {
    if (value == null || value.isEmpty) {
      return;
    }
    selectedLanguage.value = value;
    final code = _langToLocale[value];
    if (code != null) {
      try {
        LocalizationService.updateLocale(code);
      } catch (_) {/* best-effort : le changement de langue ne doit pas crasher */}
    }
  }

  void updateCurrency(String? label) {
    if (label == null || label.isEmpty) return;
    for (final code in CurrencyHelper.supportedCurrencies) {
      if (CurrencyHelper.label(code) == label) {
        selectedCurrency.value = code;
        return;
      }
    }
  }

  // Validation methods
  String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'error_name_required'.tr;
    }
    if (value.length < 2) {
      return 'error_name_length'.tr;
    }
    return null;
  }

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'error_email_required'.tr;
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'error_email_invalid'.tr;
    }
    return null;
  }

  String? validatePayPalEmail(String? value) {
    final v = value?.trim() ?? '';
    if (userType == 'pet_sitter') {
      // Optional for sitter signup: validate only when user enters a value.
      if (v.isEmpty) return null;
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
      if (!emailRegex.hasMatch(v)) {
        return 'error_email_invalid'.tr;
      }
    }
    return null;
  }

  String? validatePhone(String? value, {String? countryCode}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) {
      return null; // Phone is optional
    }
    // Accept common formatting chars (digits, spaces, hyphens, parentheses, leading +)
    final allowedChars = RegExp(r'^\+?[0-9\s\-\(\)]+$');
    if (!allowedChars.hasMatch(v)) {
      return 'error_phone_invalid'.tr;
    }
    // Combine country code + phone for full number validation (E.164: 7-15 digits)
    final countryDigits = (countryCode ?? '').replaceAll(RegExp(r'\D'), '');
    final phoneDigits = v.replaceAll(RegExp(r'\D'), '');
    final fullDigits = countryDigits + phoneDigits;
    if (!RegExp(r'^\d{7,15}$').hasMatch(fullDigits)) {
      return 'error_phone_invalid'.tr;
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'error_password_required'.tr;
    }
    if (value.length < 8) {
      return 'error_password_length'.tr;
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'error_password_uppercase'.tr;
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'error_password_lowercase'.tr;
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'error_password_number'.tr;
    }
    return null;
  }

  String? validateAddress(String? value) {
    if (value == null || value.isEmpty) {
      return 'error_address_required'.tr;
    }
    if (value.length < 2) {
      return 'error_address_length'.tr;
    }
    return null;
  }

  String? validateRatePerHour(String? value) {
    if (userType == 'pet_sitter') {
      if (value == null || value.isEmpty) {
        return 'error_rate_required'.tr;
      }
      final rate = double.tryParse(value.replaceAll(RegExp(r'[^\d.]'), ''));
      if (rate == null) {
        return 'error_rate_invalid'.tr;
      }
      if (rate == 0) {
        return 'error_rate_zero'.tr;
      }
      if (rate < 0) {
        return 'error_rate_invalid'.tr;
      }
    }
    return null;
  }

  String? validateRatePerWeek(String? value) {
    if (userType == 'pet_sitter') {
      // Optional in signup. Validate only when provided.
      if (value == null || value.isEmpty) {
        return null;
      }
      final rate = double.tryParse(value.replaceAll(RegExp(r'[^\d.]'), ''));
      if (rate == null) {
        return 'error_rate_invalid'.tr;
      }
      if (rate <= 0) {
        return 'error_rate_zero'.tr;
      }
    }
    return null;
  }

  String? validateRatePerMonth(String? value) {
    if (userType == 'pet_sitter') {
      // Optional in signup. Validate only when provided.
      if (value == null || value.isEmpty) {
        return null;
      }
      final rate = double.tryParse(value.replaceAll(RegExp(r'[^\d.]'), ''));
      if (rate == null) {
        return 'error_rate_invalid'.tr;
      }
      if (rate <= 0) {
        return 'error_rate_zero'.tr;
      }
    }
    return null;
  }

  String? validateSkills(String? value) {
    if (userType == 'pet_sitter') {
      if (value == null || value.isEmpty) {
        return 'error_skills_required'.tr;
      }
      if (value.length < 2) {
        return 'error_skills_length'.tr;
      }
    }
    return null;
  }

  /// Get user's current location using Google Maps
  Future<void> getCurrentLocationFromMaps() async {
    try {
      isGettingLocation.value = true;

      // Get location and city information
      Map<String, dynamic>? locationData = await _locationService
          .getUserLocationWithCity();

      if (locationData != null) {
        userLatitude.value = locationData['latitude'] as double?;
        userLongitude.value = locationData['longitude'] as double?;
        userCity.value = locationData['city'] as String? ?? '';
        // Sprint 6.5 step 2 — default country from reverse geocoding (user can override via CountryCodePicker).
        final iso = (locationData['countryCodeIso'] as String?)?.toUpperCase();
        if (iso != null && RegExp(r'^[A-Z]{2}$').hasMatch(iso)) {
          selectedCountry.value = iso;
        }

        // Auto-fill city and address fields
        if (userCity.value.isNotEmpty) {
          cityController.text = userCity.value;
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
          'Location detected: City=${userCity.value}, Lat=${userLatitude.value}, Lon=${userLongitude.value}',
        );
      } else {
        CustomSnackbar.showWarning(
          title: 'snackbar_text_location_not_found',
          message:
              'snackbar_text_could_not_detect_your_location_please_enable_location_servic',
        );
      }
    } catch (e) {
      AppLogger.logError('Error getting location', error: e);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'map_load_error'.tr,
      );
    } finally {
      isGettingLocation.value = false;
    }
  }

  void toggleAgreeToTerms(bool? value) {
    agreeToTerms.value = value ?? false;
  }

  /// Clears all form text fields (e.g. after success or error).
  void clearFields() {
    nameController.clear();
    emailController.clear();
    phoneController.clear();
    passwordController.clear();
    addressController.clear();
    ratePerHourController.clear();
    skillsController.clear();
    cityController.clear();
    paypalEmailController.clear();
    agreeToTerms.value = false;
  }

  Future<bool> handleSignUp() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      CustomSnackbar.showError(
        title: 'error_invalid_details_title'.tr,
        message: 'error_invalid_details_message'.tr,
      );
      return false;
    }

    if (!agreeToTerms.value) {
      CustomSnackbar.showWarning(
        title: 'error_terms_required_title'.tr,
        message: 'error_terms_required_message'.tr,
      );
      return false;
    }

    isLoading.value = true;

    try {
      await _authRepository.signup(role: _apiRole, user: _buildUserPayload());

      // v20.2.1 — bug fix : la photo profil sélectionnée pendant l'inscription
      // n'était jamais uploadée car aucun token d'auth n'existe encore à ce
      // stade (signup retourne juste "compte créé, vérifie ton email"). On
      // persiste le chemin du fichier en GetStorage ; OtpVerificationController
      // l'upload via /users/me/profile-picture dès que /auth/verify renvoie
      // un token. Le fichier reste sur le téléphone le temps de la vérif OTP.
      try {
        final pending = profileImageFile;
        if (pending != null && pending.existsSync()) {
          await GetStorage().write(
            StorageKeys.pendingSignupPhotoPath,
            pending.path,
          );
          AppLogger.logInfo(
            '[signup] queued profile photo for post-OTP upload: ${pending.path}',
          );
        }
      } catch (e) {
        AppLogger.logError(
          '[signup] failed to queue profile photo (non-fatal)',
          error: e,
        );
      }

      CustomSnackbar.showSuccess(
        title: 'signup_account_created_title'.tr,
        message: 'signup_account_created_message'.tr,
      );
      clearFields();
      return true;
    } on ApiException catch (error) {
      CustomSnackbar.showError(
        title: 'signup_failed_title'.tr,
        message: error.message,
      );
      return false;
    } catch (error) {
      CustomSnackbar.showError(
        title: 'signup_failed_title'.tr,
        message: 'common_error_generic'.tr,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Map<String, dynamic> _buildUserPayload() {
    // Mobile: send number only; countryCode as separate field (API format).
    final phone = phoneController.text.trim();
    final data = <String, dynamic>{
      'name': nameController.text.trim(),
      'email': emailController.text.trim(),
      'password': passwordController.text,
      'mobile': phone,
      'countryCode': selectedCountryCode.value,
      // Sprint 6.5 step 2 — ISO-2 country code for Stripe Connect + pricing.
      'country': selectedCountry.value,
      // Sprint 7 step 3 — optional referral code (parrain).
      if (referralCodeController.text.trim().isNotEmpty)
        'referralCode': referralCodeController.text.trim().toUpperCase(),
      'language': selectedLanguage.value,
      'address': addressController.text.trim(),
      'acceptedTerms': agreeToTerms.value,
    };

    // API expects location as { lat, lng }, not latitude/longitude.
    if (userLatitude.value != null && userLongitude.value != null) {
      data['location'] = {
        'lat': userLatitude.value,
        'lng': userLongitude.value,
        'city': cityController.text.trim(),
      };
    }

    // if (cityController.text.isNotEmpty) {
    //   data['location']['city'] = cityController.text.trim();
    // }

    if (userType == 'pet_sitter') {
      data['skills'] = skillsController.text.trim();
      data['currency'] = selectedCurrency.value;

      final rateText = ratePerHourController.text.replaceAll(
        RegExp(r'[^\d.]'),
        '',
      );
      final rate = double.tryParse(rateText);
      if (rate != null) {
        data['hourlyRate'] = rate;
      }

      final weeklyRateText = ratePerWeekController.text.replaceAll(
        RegExp(r'[^\d.]'),
        '',
      );
      final weeklyRate = double.tryParse(weeklyRateText);
      if (weeklyRate != null) {
        data['weeklyRate'] = weeklyRate;
      }

      final monthlyRateText = ratePerMonthController.text.replaceAll(
        RegExp(r'[^\d.]'),
        '',
      );
      final monthlyRate = double.tryParse(monthlyRateText);
      if (monthlyRate != null) {
        data['monthlyRate'] = monthlyRate;
      }

      final paypal = paypalEmailController.text.trim();
      if (paypal.isNotEmpty) {
        data['paypalEmail'] = paypal;
      }
    }

    // Walker-specific signup payload. At signup the walker only provides base
    // account info + currency. Detailed walkRates (per duration pricing) and
    // coverage preferences are configured later in the walker onboarding flow.
    if (userType == 'pet_walker') {
      data['currency'] = selectedCurrency.value;
      // The walker service is always seeded with dog_walking by default —
      // the backend will fill this if it's empty.
      data['service'] = ['dog_walking'];

      // v20.0.6 — walker rates captured at signup (30 min / 60 min). We ship
      // them as `walkRates` (same shape used by edit-profile) so the walker
      // can start accepting requests immediately after OTP.
      final r30 = double.tryParse(
        walkerRate30Controller.text.trim().replaceAll(',', '.'),
      );
      final r60 = double.tryParse(
        walkerRate60Controller.text.trim().replaceAll(',', '.'),
      );
      // v23.1 part 141 — fix : aligner sur le shape du Walker model
      // backend (durationMinutes + basePrice au lieu de duration + amount).
      // Backend tolère désormais les 2 formats pour rétrocompat, mais
      // on envoie le bon format pour rester clean.
      final rates = <Map<String, dynamic>>[];
      if (r30 != null && r30 > 0) {
        rates.add({
          'durationMinutes': 30,
          'basePrice': r30,
          'currency': selectedCurrency.value,
        });
      }
      if (r60 != null && r60 > 0) {
        rates.add({
          'durationMinutes': 60,
          'basePrice': r60,
          'currency': selectedCurrency.value,
        });
      }
      if (rates.isNotEmpty) {
        data['walkRates'] = rates;
      }

      final paypal = paypalEmailController.text.trim();
      if (paypal.isNotEmpty) {
        data['paypalEmail'] = paypal;
      }
    }

    // v20.0.6 — Owner also gets a currency at signup (used for Premium,
    // Boost, donation displays). Defaults to EUR.
    if (userType == 'pet_owner') {
      data['currency'] = selectedCurrency.value;
    }

    // ─── v409 refonte — champs collectés par le wizard 5 étapes. Additifs :
    // Mongoose strict mode ne garde que ceux présents dans le schéma du rôle.
    final dob = dobController.text.trim();
    if (dob.isNotEmpty) data['dateOfBirth'] = dob;
    final bio = bioController.text.trim();
    if (bio.isNotEmpty) data['bio'] = bio;
    if (experienceTags.isNotEmpty) {
      data['experienceTags'] = experienceTags.toList();
    }
    final extra = double.tryParse(
      extraAnimalController.text.trim().replaceAll(',', '.'),
    );

    if (userType == 'pet_owner') {
      data['searchPreferences'] = {
        'services': selectedServices.toList(),
        'radiusKm': int.tryParse(coverageRadius.value) ?? 20,
        'preferredLanguage': selectedLanguage.value,
      };
      data['preferences'] = {
        'sendPhotosVideos': prefPhotos.value,
        'quickReplies': prefQuickReplies.value,
        'flexibleCancellation': prefFlexCancel.value,
        'pawMapInsurance': prefInsurance.value,
        'notifications': prefNotifications.value,
      };
    }

    if (userType == 'pet_sitter') {
      if (selectedServices.isNotEmpty) data['service'] = selectedServices.toList();
      if (acceptedAnimals.isNotEmpty) {
        data['acceptedPetTypes'] = acceptedAnimals.toList();
      }
      data['coverageRadiusKm'] = int.tryParse(coverageRadius.value) ?? 20;
      final daily = double.tryParse(
        ratePerDayController.text.trim().replaceAll(',', '.'),
      );
      if (daily != null && daily > 0) data['dailyRate'] = daily;
      if (extra != null && extra >= 0) data['additionalAnimalFee'] = extra;
    }

    if (userType == 'pet_walker') {
      if (acceptedAnimals.isNotEmpty) {
        data['acceptedPetTypes'] = acceptedAnimals.toList();
      }
      if (availableDays.isNotEmpty) data['availableDays'] = availableDays.toList();
      data['coverageRadiusKm'] = int.tryParse(coverageRadius.value) ?? 15;
      // Tarif 2h en plus des 30/60 min déjà ajoutés au bloc walker ci-dessus.
      final r120 = double.tryParse(
        walkerRate120Controller.text.trim().replaceAll(',', '.'),
      );
      if (r120 != null && r120 > 0) {
        final rates = (data['walkRates'] as List?)?.cast<Map<String, dynamic>>() ??
            <Map<String, dynamic>>[];
        rates.add({
          'durationMinutes': 120,
          'basePrice': r120,
          'currency': selectedCurrency.value,
        });
        data['walkRates'] = rates;
      }
      if (extra != null && extra >= 0) data['additionalAnimalFee'] = extra;
    }

    return data;
  }

  /// Maps the frontend userType (used across the auth UI) to the backend role
  /// string expected by the /auth/signup endpoint.
  /// - pet_owner  -> owner
  /// - pet_sitter -> sitter
  /// - pet_walker -> walker
  String get _apiRole {
    switch (userType) {
      case 'pet_owner':
        return 'owner';
      case 'pet_walker':
        return 'walker';
      case 'pet_sitter':
      default:
        return 'sitter';
    }
  }

  /// v409 — validation de l'étape 1 du wizard (infos perso), sans formKey
  /// (les champs des autres étapes ne sont pas montés dans un Form unique).
  String? validateStep1() {
    final e = validateName(nameController.text) ??
        validateEmail(emailController.text) ??
        validatePassword(passwordController.text);
    if (e != null) return e;
    if (confirmPasswordController.text != passwordController.text) {
      return 'signup_pw_mismatch'.tr;
    }
    return null;
  }

  /// v409 — soumission depuis le wizard 5 étapes. Validation MANUELLE (le
  /// wizard n'utilise pas un Form unique), puis réutilise exactement le même
  /// flux que handleSignUp (signup → file photo → OTP).
  Future<void> handleWizardSignUp({required String email}) async {
    final err = validateStep1();
    if (err != null) {
      CustomSnackbar.showError(
        title: 'error_invalid_details_title'.tr,
        message: err,
      );
      currentStep.value = 0; // ramène à l'étape infos perso
      return;
    }
    if (!agreeToTerms.value) {
      CustomSnackbar.showWarning(
        title: 'error_terms_required_title'.tr,
        message: 'error_terms_required_message'.tr,
      );
      return;
    }
    isLoading.value = true;
    try {
      await _authRepository.signup(role: _apiRole, user: _buildUserPayload());
      try {
        final pending = profileImageFile;
        if (pending != null && pending.existsSync()) {
          await GetStorage().write(
            StorageKeys.pendingSignupPhotoPath,
            pending.path,
          );
        }
      } catch (_) {/* non-fatal */}
      CustomSnackbar.showSuccess(
        title: 'signup_account_created_title'.tr,
        message: 'signup_account_created_message'.tr,
      );
      // v419 — Daniel : "après Créer mon compte sitter, une page owner
      // garderie/add-animal réapparaît et me bascule en propriétaire". CAUSE :
      // l'OTP routait TOUS les inscrits vers ChooseServiceScreen (ancien
      // onboarding owner) alors que le wizard 5 étapes collecte déjà tout.
      // FIX : on pré-remplit AuthController pour l'auto-login après l'OTP →
      // l'OTP route ensuite vers le home du BON rôle (sitter = bleu), sans
      // ChooseServiceScreen.
      try {
        if (Get.isRegistered<AuthController>()) {
          final auth = Get.find<AuthController>();
          auth.emailController.text = email.trim();
          auth.passwordController.text = passwordController.text;
        }
      } catch (_) {/* non-fatal : l'OTP retombera sur le login manuel */}
      Get.off(
        () => OtpVerificationScreen(
          email: email,
          verificationType: VerificationType.signup,
          userType: userType,
        ),
      );
    } on ApiException catch (error) {
      CustomSnackbar.showError(
        title: 'signup_failed_title'.tr,
        message: error.message,
      );
    } catch (_) {
      CustomSnackbar.showError(
        title: 'signup_failed_title'.tr,
        message: 'common_error_generic'.tr,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Handles signup with navigation logic
  Future<void> handleSignUpWithNavigation({required String email}) async {
    // Store email before signup (in case fields are cleared)
    final success = await handleSignUp();

    if (success) {
      Get.off(
        () => OtpVerificationScreen(
          email: email,
          verificationType: VerificationType.signup,
          userType: userType,
        ),
      );
    }
  }
}
