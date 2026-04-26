import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/repositories/sitter_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/auth/login_screen.dart';
import 'package:hopetsit/views/profile/add_card_screen.dart';
import 'package:hopetsit/views/profile/change_password_screen.dart';
import 'package:hopetsit/views/profile/blocked_users_screen.dart';
import 'package:hopetsit/views/reviews/reviews_screen.dart';
import 'package:hopetsit/views/pet_sitter/onboarding/petsitter_onboarding_screen.dart';
import 'package:hopetsit/views/pet_sitter/payment/payout_status_screen.dart';
import 'package:hopetsit/views/pet_sitter/profile/edit_sitter_profile_screen.dart';
import 'package:hopetsit/views/pet_sitter/booking/sitter_bookings_screen.dart';
import 'package:hopetsit/views/auth/choose_service_screen.dart';
import 'package:hopetsit/models/profile_model.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_confirmation_dialog.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

class SitterProfileController extends GetxController {
  SitterProfileController({
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

  // Observable variables
  final RxBool isLoading = false.obs;
  final RxString userName = ''.obs;
  final RxString phoneNumber = ''.obs;
  final RxString email = ''.obs;
  final RxString profileImageUrl = ''.obs;
  final RxString selectedCountryCode = '+1'.obs;
  final Rxn<ProfileModel> profile = Rxn<ProfileModel>();

  // Blocked users list
  final RxList<BlockedUser> blockedUsers = <BlockedUser>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadMyProfile();
    loadBlockedUsers();
  }

  /// Loads the current sitter's profile from the API.
  /// Uses GET /sitters/{id} to fetch the logged-in sitter's profile.
  ///
  /// When the logged-in user is a Walker (Promeneur), we skip this call
  /// entirely because the `/sitters/{id}` endpoint returns 404 for walkers.
  /// The walker flow reuses several sitter screens (feed, chat, etc.) so
  /// this controller can still be mounted — we just leave its observables
  /// empty instead of triggering a spurious "Échec du chargement du profil"
  /// snackbar.
  Future<void> loadMyProfile() async {
    isLoading.value = true;

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

      // Short-circuit for walkers — they don't have a sitter profile.
      final role = userProfile?['role']?.toString().toLowerCase() ?? '';
      if (role == 'walker') {
        AppLogger.logDebug(
          'SitterProfileController.loadMyProfile: skipping — user role is walker',
        );
        // Seed display name/email from the stored user profile so app bars
        // have something to show.
        userName.value = userProfile?['name']?.toString() ?? '';
        email.value = userProfile?['email']?.toString() ?? '';
        phoneNumber.value = userProfile?['mobile']?.toString() ?? '';

        // Session v15-2 — also seed the avatar so the home / chat /
        // reservations tabs stop rendering a grey placeholder for walkers.
        // Avatar may be stored either as a Map {'url': ..., 'publicId': ...}
        // (preferred shape) or a plain String URL from older payloads.
        final avatar = userProfile?['avatar'];
        if (avatar is Map) {
          profileImageUrl.value = avatar['url']?.toString() ?? '';
        } else if (avatar is String) {
          profileImageUrl.value = avatar;
        } else if (userProfile?['profileImage'] != null) {
          profileImageUrl.value = userProfile!['profileImage'].toString();
        } else {
          profileImageUrl.value = '';
        }
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

      // Store the full profile data
      try {
        profile.value = ProfileModel.fromJson(profileData);
      } catch (e) {
        AppLogger.logError('Failed to parse profile model', error: e);
        // Fallback: create a basic profile model with available data
        profile.value = ProfileModel(
          id: profileData['id']?.toString() ?? '',
          name: profileData['name']?.toString() ?? '',
          email: profileData['email']?.toString() ?? '',
          mobile:
              profileData['mobile']?.toString() ??
              profileData['phone']?.toString() ??
              '',
          language: profileData['language']?.toString() ?? '',
          address: profileData['address']?.toString() ?? '',
          acceptedTerms: profileData['acceptedTerms'] as bool? ?? false,
          service: profileData['service'] is List
              ? (profileData['service'] as List)
                    .map((e) => e.toString())
                    .toList()
              : (profileData['service'] is String &&
                        (profileData['service'] as String).isNotEmpty
                    ? [(profileData['service'] as String)]
                    : []),
          verified: profileData['verified'] as bool? ?? false,
          createdAt: profileData['createdAt']?.toString() ?? '',
          updatedAt: profileData['updatedAt']?.toString() ?? '',
          avatar: ProfileAvatar.fromJson(
            profileData['avatar'] as Map<String, dynamic>? ?? {},
          ),
          pets: profileData['pets'] as List<dynamic>? ?? [],
          bookings: profileData['bookings'] as List<dynamic>? ?? [],
          posts: profileData['posts'] as List<dynamic>? ?? [],
          tasks: profileData['tasks'] as List<dynamic>? ?? [],
          reviewsGiven: profileData['reviewsGiven'] as List<dynamic>? ?? [],
          reviewsReceived:
              profileData['reviewsReceived'] as List<dynamic>? ?? [],
          stats: ProfileStats.fromJson(
            profileData['stats'] as Map<String, dynamic>? ?? {},
          ),
        );
      }

      // Update observable variables for backward compatibility
      userName.value = profileData['name']?.toString() ?? '';
      email.value = profileData['email']?.toString() ?? '';
      phoneNumber.value =
          profileData['mobile']?.toString() ??
          profileData['phone']?.toString() ??
          '';
      selectedCountryCode.value =
          profileData['countryCode']?.toString() ?? '+1';

      // Extract profile image
      final avatar = profileData['avatar'];
      if (avatar is Map<String, dynamic>) {
        profileImageUrl.value = avatar['url']?.toString() ?? '';
      } else if (avatar is String) {
        profileImageUrl.value = avatar;
      } else if (profileData['profileImage'] != null) {
        profileImageUrl.value = profileData['profileImage'].toString();
      }
    } on ApiException catch (error) {
      AppLogger.logError('Failed to load sitter profile', error: error.message);
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
      AppLogger.logError('Failed to load sitter profile', error: error);
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
      isLoading.value = false;
    }
  }

  void loadBlockedUsers() {
    // TODO: Replace with actual API call
    blockedUsers.value = [
      BlockedUser(
        id: '1',
        sitterId: 'sitter_1',
        name: 'Darlene Robertson',
        company: 'Pet Owner',
        profileImage: AppImages.placeholderImage,
        blockedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      BlockedUser(
        id: '2',
        sitterId: 'sitter_2',
        name: 'John Smith',
        company: 'Pet Owner',
        profileImage: AppImages.placeholderImage,
        blockedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      BlockedUser(
        id: '3',
        sitterId: 'sitter_3',
        name: 'Sarah Johnson',
        company: 'Pet Owner',
        profileImage: AppImages.placeholderImage,
        blockedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      BlockedUser(
        id: '4',
        sitterId: 'sitter_4',
        name: 'Michael Brown',
        company: 'Pet Owner',
        profileImage: AppImages.placeholderImage,
        blockedAt: DateTime.now().subtract(const Duration(hours: 12)),
      ),
      BlockedUser(
        id: '5',
        sitterId: 'sitter_5',
        name: 'Emily Davis',
        company: 'Pet Owner',
        profileImage: AppImages.placeholderImage,
        blockedAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
      BlockedUser(
        id: '6',
        sitterId: 'sitter_6',
        name: 'David Wilson',
        company: 'Pet Owner',
        profileImage: AppImages.placeholderImage,
        blockedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ];
  }

  void unblockUser(String userId) {
    // TODO: Implement API call to unblock user
    blockedUsers.removeWhere((user) => user.id == userId);
    CustomSnackbar.showSuccess(
      title: 'common_success'.tr,
      message: 'blocked_users_unblock_success'.tr,
    );
  }

  /// Shows the logout confirmation dialog. Mirrors [ProfileController.showLogoutDialog]
  /// so the sitter profile screen can call the same API on its own controller.
  void showLogoutDialog(BuildContext context) {
    CustomConfirmationDialog.show(
      context: context,
      message: 'logout_dialog_message'.tr,
      yesText: 'common_yes'.tr,
      cancelText: 'common_cancel'.tr,
      onYes: () async {
        if (Get.isRegistered<AuthController>()) {
          final authController = Get.find<AuthController>();
          await authController.logout();
        } else {
          Get.offAll(() => const LoginScreen());
        }
      },
    );
  }

  /// Navigates to the edit sitter profile screen.
  void editProfile() {
    navigateToEditProfile();
  }

  void saveBlockedUsers() {
    // TODO: Implement API call to save blocked users
    CustomSnackbar.showSuccess(
      title: 'common_success'.tr,
      message: 'blocked_users_save_success'.tr,
    );
    Get.back();
  }

  // Navigation methods
  void navigateToEditProfile() {
    Get.to(() => const EditSitterProfileScreen());
  }

  void navigateToChooseService() {
    // Get user email from storage
    final userProfile = _storage.read<Map<String, dynamic>>(
      StorageKeys.userProfile,
    );
    if (userProfile == null || userProfile['email'] == null) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'error_email_not_found'.tr,
      );
      return;
    }

    final email = userProfile['email'] as String;
    Get.to(
      () => ChooseServiceScreen(
        userType: 'pet_sitter',
        email: email,
        isFromProfile: true,
      ),
    );
  }

  void navigateToChangePassword() {
    Get.to(() => const ChangePasswordScreen(userType: 'pet_sitter'));
  }

  void navigateToAddCard() {
    Get.to(() => const AddCardScreen(userType: 'pet_sitter'));
  }

  void showLanguageDialog() {
    final currentCode = LocalizationService.getCurrentLanguageCode();
    final entries = LocalizationService.languageLabels.entries.toList();

    Get.defaultDialog(
      title: 'language_dialog_title'.tr,
      backgroundColor: AppColors.whiteColor,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: entries.map((entry) {
          final isSelected = entry.key == currentCode;
          return ListTile(
            title: InterText(
              text: entry.value,
              fontSize: 15.sp,
              fontWeight: FontWeight.w500,
            ),
            trailing: isSelected
                ? const Icon(Icons.check, color: Colors.green)
                : null,
            onTap: () async {
              await LocalizationService.updateLocale(entry.key);
              Get.back();
            },
          );
        }).toList(),
      ),
      textCancel: 'common_cancel'.tr,
    );
  }

  void navigateToBlockedUsers() {
    Get.to(() => const BlockedUsersScreen(userType: 'pet_sitter'));
  }

  void navigateToReviews() {
    Get.to(
      () => ReviewsScreen(
        serviceProviderName: 'Maryam Shakoor',
        phoneNumber: '04848204834',
        email: 'doisv@gmail.com',
        profileImagePath: AppImages.placeholderImage,
        serviceProviderId: '1',
      ),
    );
  }

  void navigateToDonate() {
    // TODO: Implement donate navigation
    CustomSnackbar.showWarning(
      title: 'common_coming_soon'.tr,
      message: 'donate_coming_soon'.tr,
    );
  }

  void navigateToPetsitterOnboarding() {
    Get.to(() => const PetsitterOnboardingScreen());
  }

  // v21.1.1 — Stripe Connect onboarding retiré (Stripe purgé). Le sitter
  // configure désormais ses payouts via l'écran IBAN (Airwallex Beneficiary).
  void navigateToStripeConnect() {
    CustomSnackbar.showWarning(
      title: 'Configuration de paiement',
      message: 'Renseigne ton IBAN dans Profil → Compte bancaire pour recevoir tes paiements.',
    );
  }

  void navigateToPayoutStatus() {
    Get.to(() => const PayoutStatusScreen());
  }

  void navigateToBookings() {
    Get.to(() => const SitterBookingsScreen());
  }

  void showDeleteAccountDialog(BuildContext context) {
    CustomConfirmationDialog.show(
      context: context,
      message: 'delete_account_dialog_message'.tr,
      yesText: 'common_yes'.tr,
      cancelText: 'common_cancel'.tr,
      onYes: () async {
        await deleteAccount();
      },
    );
  }

  Future<void> deleteAccount() async {
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );
    try {
      await _sitterRepository.deleteAccount();

      // Clear authentication token and user data
      await _storage.remove(StorageKeys.authToken);
      await _storage.remove(StorageKeys.userProfile);
      await _storage.remove(StorageKeys.userRole);

      CustomSnackbar.showSuccess(
        title: 'delete_account_success_title'.tr,
        message: 'delete_account_success_message'.tr,
      );

      // Navigate to login screen
      Get.offAll(() => const LoginScreen());
    } on ApiException catch (error) {
      AppLogger.logError('Failed to delete account', error: error.message);
      CustomSnackbar.showError(
        title: 'delete_account_failed_title'.tr,
        message: error.message,
      );
    } catch (error) {
      AppLogger.logError('Failed to delete account', error: error);
      CustomSnackbar.showError(
        title: 'delete_account_failed_title'.tr,
        message: 'delete_account_failed_generic'.tr,
      );
    } finally {
      if (Get.isDialogOpen == true) Get.back();
    }
  }

  void showUnblockUserDialog(
    BuildContext context,
    String blockId,
    String userName,
  ) {
    CustomConfirmationDialog.show(
      context: context,
      message: 'blocked_users_unblock_dialog_message'.trParams({
        'name': userName,
      }),
      yesText: 'common_yes'.tr,
      cancelText: 'common_cancel'.tr,
      onYes: () {
        unblockUser(blockId);
      },
    );
  }
}
