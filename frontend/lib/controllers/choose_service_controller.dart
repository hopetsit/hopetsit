import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/email_verification_controller.dart';
import 'package:hopetsit/controllers/sign_up_controller.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/repositories/auth_repository.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/views/pet_owner/pet_profile/create_pet_profile_screen.dart';
import 'package:hopetsit/controllers/profile_controller.dart';
import 'package:hopetsit/controllers/sitter_profile_controller.dart';
import 'package:hopetsit/views/pet_sitter/bottom_wrapper/sitter_nav_wrapper.dart';

class ChooseServiceController extends GetxController {
  /// For backward compatibility, we keep a \"primary\" selected service,
  /// but all logic should rely on [selectedServices] for multi-select.
  final Rx<String?> selectedService = Rx<String?>('pet_sitting');
  final RxList<String> selectedServices = <String>[].obs;

  final String userType;
  final String email;
  final bool isFromProfile;
  final AuthRepository _authRepository;

  ChooseServiceController({
    required this.userType,
    required this.email,
    this.isFromProfile = false,
    AuthRepository? authRepository,
  }) : _authRepository = authRepository ?? Get.find<AuthRepository>();

  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    if (isFromProfile) {
      // Load current service from profile if available
      _loadCurrentService();
    }
  }

  /// Loads the current services from user profile
  void _loadCurrentService() {
    try {
      List<String> currentServices = [];

      if (userType == 'pet_owner') {
        if (Get.isRegistered<ProfileController>()) {
          final profileController = Get.find<ProfileController>();
          final profile = profileController.profile.value;
          if (profile != null && profile.service.isNotEmpty) {
            // Map API format back to internal format
            currentServices = profile.service
                .map((service) {
                  return _mapApiFormatToServiceValue(service);
                })
                .where((value) => value != null)
                .cast<String>()
                .toList();
          }
        }
      } else if (userType == 'pet_sitter') {
        if (Get.isRegistered<SitterProfileController>()) {
          final sitterProfileController = Get.find<SitterProfileController>();
          final profile = sitterProfileController.profile.value;
          if (profile != null && profile.service.isNotEmpty) {
            // Map API format back to internal format
            currentServices = profile.service
                .map((service) {
                  return _mapApiFormatToServiceValue(service);
                })
                .where((value) => value != null)
                .cast<String>()
                .toList();
          }
        }
      }

      // Filter out services that are not allowed for the current role
      if (currentServices.isNotEmpty) {
        currentServices = currentServices
            .where((value) => _allowedServiceValuesForRole.contains(value))
            .toList();
      }

      // Set selected services
      if (currentServices.isNotEmpty) {
        selectedServices.value = currentServices;
        selectedService.value = currentServices.first;
      }
    } catch (e) {
      // Silently handle errors - user can still select services
      if (kDebugMode) {
        print('Failed to load current services: $e');
      }
    }
  }

  /// Maps API format back to internal service value (e.g., "Pet Sitting" -> "pet_sitting")
  String? _mapApiFormatToServiceValue(String apiService) {
    switch (apiService.toLowerCase()) {
      case 'pet sitting':
        return 'pet_sitting';
      case 'house sitting':
        return 'house_sitting';
      case 'day care':
        return 'day_care';
      case 'dog walking':
        return 'dog_walking';
      default:
        // Try direct match in case API returns internal format
        if ([
          'pet_sitting',
          'house_sitting',
          'day_care',
          'dog_walking',
        ].contains(apiService)) {
          return apiService;
        }
        return null;
    }
  }

  /// Refreshes profile data after service update
  Future<void> _refreshProfileData() async {
    try {
      if (userType == 'pet_owner') {
        // Refresh pet owner profile
        if (Get.isRegistered<ProfileController>()) {
          final profileController = Get.find<ProfileController>();
          await profileController.loadMyProfile();
        }
      } else if (userType == 'pet_sitter') {
        // Refresh pet sitter profile
        if (Get.isRegistered<SitterProfileController>()) {
          final sitterProfileController = Get.find<SitterProfileController>();
          await sitterProfileController.loadMyProfile();
        }
      }
    } catch (e) {
      // Silently handle refresh errors to avoid disrupting the user flow
      print('Failed to refresh profile data: $e');
    }
  }

  /// Allowed internal service values per role.
  /// Owner: pet_sitting, house_sitting, day_care, long_stay
  /// Sitter: dog_walking, pet_sitting, house_sitting, day_care, long_stay
  static const List<String> _ownerAllowedServiceValues = <String>[
    'pet_sitting',
    'house_sitting',
    'day_care',
  ];

  static const List<String> _sitterAllowedServiceValues = <String>[
    'pet_sitting',
    'house_sitting',
    'day_care',
    'dog_walking',
  ];

  List<String> get _allowedServiceValuesForRole => userType == 'pet_owner'
      ? _ownerAllowedServiceValues
      : _sitterAllowedServiceValues;

  final List<ServiceOption> _petOwnerServices = [
    ServiceOption(
      titleKey: 'choose_service_card_pet_sitting_title',
      subtitleKey: 'choose_service_card_subtitle_at_owners_home',
      value: 'pet_sitting',
    ),
    ServiceOption(
      titleKey: 'choose_service_card_house_sitting_title',
      subtitleKey: 'choose_service_card_subtitle_in_your_home',
      value: 'house_sitting',
    ),
    ServiceOption(
      titleKey: 'choose_service_card_day_care_title',
      subtitleKey: 'choose_service_card_subtitle_at_owners_home',
      value: 'day_care',
    ),
  ];

  final List<ServiceOption> _petSitterServices = [
    ServiceOption(
      titleKey: 'choose_service_card_dog_walking_title',
      subtitleKey: 'choose_service_card_subtitle_in_neighborhood',
      value: 'dog_walking',
    ),
    ServiceOption(
      titleKey: 'choose_service_card_pet_sitting_title',
      subtitleKey: 'choose_service_card_subtitle_at_owners_home',
      value: 'pet_sitting',
    ),
    ServiceOption(
      titleKey: 'choose_service_card_house_sitting_title',
      subtitleKey: 'choose_service_card_subtitle_in_your_home',
      value: 'house_sitting',
    ),
    ServiceOption(
      titleKey: 'choose_service_card_day_care_title',
      subtitleKey: 'choose_service_card_subtitle_at_owners_home',
      value: 'day_care',
    ),
  ];

  List<ServiceOption> get services {
    return userType == 'pet_sitter' ? _petSitterServices : _petOwnerServices;
  }

  /// Toggles a service in the multi-select list for BOTH flows.
  /// [selectedService] is kept in sync with the first selected item (if any)
  /// so existing code that uses a single value still works.
  void selectService(String serviceValue) {
    // Guard against invalid services for the current role (e.g., dog_walking for owners)
    if (!_allowedServiceValuesForRole.contains(serviceValue)) {
      if (kDebugMode) {
        print(
          '[HOPETSIT] ⚠️ Ignoring selection of disallowed service "$serviceValue" for userType="$userType"',
        );
      }
      return;
    }
    if (selectedServices.contains(serviceValue)) {
      selectedServices.remove(serviceValue);
    } else {
      selectedServices.add(serviceValue);
    }

    // Keep single-value selection in sync (for legacy usages)
    selectedService.value = selectedServices.isNotEmpty
        ? selectedServices.first
        : null;
  }

  /// Selects all services (profile flow)
  void selectAllServices() {
    selectedServices.clear();
    for (var service in services) {
      selectedServices.add(service.value);
    }
  }

  /// Clears all selected services (profile flow)
  void clearAllServices() {
    selectedServices.clear();
  }

  /// At least one service must be selected (multi-select for both flows).
  bool get hasSelectedService => selectedServices.isNotEmpty;

  /// Maps service value to API format (e.g., "pet_sitting" -> "Pet Sitting")
  String _mapServiceValueToApiFormat(String serviceValue) {
    switch (serviceValue) {
      case 'pet_sitting':
        return 'Pet Sitting';
      case 'house_sitting':
        return 'House Sitting';
      case 'day_care':
        return 'Day Care';
      case 'dog_walking':
        return 'Dog Walking';
      default:
        return serviceValue;
    }
  }

  /// Calls API to choose service
  Future<bool> chooseService({required String email}) async {
    if (!hasSelectedService) {
      return false;
    }

    // Ensure only services allowed for the current role are sent to the API
    final filteredSelected = selectedServices
        .where((service) => _allowedServiceValuesForRole.contains(service))
        .toList();

    if (filteredSelected.isEmpty) {
      if (kDebugMode) {
        print(
          '[HOPETSIT] ⚠️ chooseService: No valid services selected for userType="$userType".',
        );
      }
      CustomSnackbar.showWarning(
        title: 'service_selection_required',
        message: 'snackbar_choose_service_controller_001',
      );
      return false;
    }

    // Validate email is not empty
    final emailToUse = email.isNotEmpty ? email : this.email;
    if (emailToUse.isEmpty) {
      if (kDebugMode) {
        print(
          '[HOPETSIT] ⚠️ ChooseServiceController: No email available for API call',
        );
      }
      return false;
    }
    if (kDebugMode) {
      print(
        '[HOPETSIT] ChooseServiceController: Calling API with email=$emailToUse',
      );
    }

    isLoading.value = true;

    try {
      // Map all selected services to API format and send as array
      final servicesToSend = filteredSelected
          .map((sv) => _mapServiceValueToApiFormat(sv))
          .toList();

      await _authRepository.chooseService(
        email: emailToUse,
        services: servicesToSend,
      );

      if (isFromProfile) {
        // Refresh profile data after service update
        await _refreshProfileData();

        Get.back();
        CustomSnackbar.showSuccess(
          title: 'service_updated',
          message: 'snackbar_choose_service_controller_002',
        );
      } else {
        CustomSnackbar.showSuccess(
          title: 'service_selected',
          message: 'snackbar_choose_service_controller_003',
        );
      }

      return true;
    } on ApiException {
      CustomSnackbar.showError(
        title: 'snackbar_text_selection_failed',
        message: 'snackbar_choose_service_controller_004',
      );
      return false;
    } catch (error) {
      CustomSnackbar.showError(
        title: 'snackbar_text_selection_failed',
        message: 'snackbar_choose_service_controller_004'.tr,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Handles continue with navigation logic (for signup flow)
  Future<void> handleContinueWithNavigation() async {
    if (!hasSelectedService) {
      CustomSnackbar.showWarning(
        title: 'service_selection_required',
        message: 'snackbar_choose_service_controller_005',
      );
      return;
    }

    // Call API to choose service - use controller's stored email
    final emailToUse = email.isNotEmpty ? email : this.email;
    final success = await chooseService(email: emailToUse);

    if (success) {
      // Clean up previous controllers before navigation
      Get.delete<EmailVerificationController>(tag: userType, force: true);
      Get.delete<SignUpController>(tag: userType, force: true);

      // Navigate based on userType
      if (userType == 'pet_sitter') {
        // Stripe setup is done later (from profile) - go directly to dashboard.
        Get.offAll(() => const SitterNavWrapper());
      } else {
        // Pet owners go to create pet profile screen first.
        // For multi-select, use the first selected service as the primary type.
        final primaryService = selectedServices.isNotEmpty
            ? selectedServices.first
            : null;

        if (primaryService != null) {
          Get.to(
            () => CreatePetProfileScreen(
              userType: userType,
              serviceType: primaryService,
              fromSignup: true,
            ),
          );
        } else {
          CustomSnackbar.showWarning(
            title: 'service_selection_required',
            message: 'snackbar_choose_service_controller_006',
          );
        }
      }
    }
  }

  /// Handles save service (for profile flow)
  Future<void> handleSaveService() async {
    if (!hasSelectedService) {
      CustomSnackbar.showWarning(
        title: 'service_selection_required',
        message: 'snackbar_choose_service_controller_007',
      );
      return;
    }

    // Call API to choose service - use controller's stored email
    final emailToUse = email.isNotEmpty ? email : email;
    await chooseService(email: emailToUse);
  }
}

class ServiceOption {
  final String titleKey;
  final String subtitleKey;
  final String value;

  ServiceOption({
    required this.titleKey,
    required this.subtitleKey,
    required this.value,
  });
}
