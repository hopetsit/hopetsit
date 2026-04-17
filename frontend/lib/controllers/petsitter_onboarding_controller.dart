import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/repositories/sitter_repository.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/views/pet_sitter/onboarding/stripe_connect_onboarding_screen.dart';

class PetsitterOnboardingController extends GetxController {
  final formKey = GlobalKey<FormState>();
  final bioController = TextEditingController();
  final skillsController = TextEditingController();
  final hourlyRateController = TextEditingController();

  final RxBool isLoading = false.obs;
  final RxBool acceptTerms = false.obs;
  final RxList<String> selectedServices = <String>[].obs;
  final RxString selectedCurrency = CurrencyHelper.eur.obs;

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

  final List<String> serviceTypes = [
    'Dog Walking',
    'Pet Sitting',
    'Pet Grooming',
    'Pet Training',
    'Overnight Care',
    'Pet Boarding',
  ];

  final List<String> availabilityDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final RxMap<String, bool> availability = <String, bool>{}.obs;

  @override
  void onInit() {
    super.onInit();
    // Initialize availability map
    for (var day in availabilityDays) {
      availability[day] = false;
    }
  }

  @override
  void onClose() {
    bioController.dispose();
    skillsController.dispose();
    hourlyRateController.dispose();
    super.onClose();
  }

  void toggleService(String service) {
    if (selectedServices.contains(service)) {
      selectedServices.remove(service);
    } else {
      selectedServices.add(service);
    }
  }

  void setAvailability(String day, bool value) {
    availability[day] = value;
  }

  Future<void> completeOnboarding() async {
    if (!acceptTerms.value) {
      CustomSnackbar.showWarning(
        title: 'snackbar_text_required',
        message: 'snackbar_text_please_accept_the_terms_and_conditions',
      );
      return;
    }

    isLoading.value = true;

    try {
      // Validate hourly rate: must be numeric and greater than 0
      final rateText = hourlyRateController.text.replaceAll(
        RegExp(r'[^\d.]'),
        '',
      );
      final rate = double.tryParse(rateText ?? '');
      if (rate == null || rate <= 0) {
        CustomSnackbar.showError(
          title: 'snackbar_text_invalid_hourly_rate',
          message: 'snackbar_text_hourly_rate_must_be_greater_than_0',
        );
        return;
      }

      // Persist the onboarding data on the backend so it survives app
      // reinstall / rebuild. Previously this was a simulated delay which
      // caused the owner to lose their bio/rate/services every time.
      AppLogger.logUserAction(
        'Completing Petsitter Onboarding',
        data: {
          'bio': bioController.text.trim(),
          'skills': skillsController.text.trim(),
          'hourlyRate': hourlyRateController.text.trim(),
          'currency': selectedCurrency.value,
          'services': selectedServices.toList(),
          'availability': availability,
        },
      );

      final sitterRepository = Get.find<SitterRepository>();

      // 1) Save bio + skills + hourly rate + currency on the sitter profile.
      try {
        await sitterRepository.updateMyBioAndSkills(
          bio: bioController.text.trim(),
          skills: skillsController.text.trim(),
          hourlyRate: rate,
          currency: selectedCurrency.value,
        );
      } catch (e) {
        AppLogger.logError('Onboarding: profile save failed', error: e);
        rethrow;
      }

      // 2) Save rates (hourly = rate, weekly = 5 days * 8h * rate, monthly = 4x weekly).
      try {
        final weekly = (rate * 40).roundToDouble();
        final monthly = (rate * 160).roundToDouble();
        final daily = (rate * 8).roundToDouble();
        await sitterRepository.setMyRates(
          hourlyRate: rate,
          dailyRate: daily,
          weeklyRate: weekly,
          monthlyRate: monthly,
        );
      } catch (e) {
        AppLogger.logError('Onboarding: rates save failed (non-blocking)', error: e);
      }

      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'snackbar_text_profile_completed_successfully',
      );

      // Navigate to Stripe Connect onboarding
      Get.off(() => const StripeConnectOnboardingScreen());
    } on ApiException catch (error) {
      AppLogger.logError('Failed to complete onboarding', error: error.message);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: error.message,
      );
    } catch (e) {
      AppLogger.logError('Failed to complete onboarding', error: e);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'snackbar_text_failed_to_complete_profile_please_try_again',
      );
    } finally {
      isLoading.value = false;
    }
  }
}
