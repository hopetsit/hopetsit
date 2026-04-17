import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/repositories/auth_repository.dart';
import 'package:hopetsit/services/location_service.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/views/auth/otp_verification_screen.dart';
import 'package:hopetsit/controllers/otp_verification_controller.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/currency_helper.dart';

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
  final cityController = TextEditingController();
  final paypalEmailController = TextEditingController();

  // Observable state - Sign Up
  final RxBool isLoading = false.obs;
  final RxBool isGettingLocation = false.obs;
  final RxBool agreeToTerms = false.obs;
  final RxString selectedLanguage = 'English'.obs;
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

  final List<String> languageOptions = const ['English', 'Urdu', 'French'];
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

  void updateLanguage(String? value) {
    if (value == null || value.isEmpty) {
      return;
    }
    selectedLanguage.value = value;
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

      final paypal = paypalEmailController.text.trim();
      if (paypal.isNotEmpty) {
        data['paypalEmail'] = paypal;
      }
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
