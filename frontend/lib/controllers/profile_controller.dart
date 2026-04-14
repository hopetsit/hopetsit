import 'dart:io';

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/booking/booking_agreement_screen.dart';
import 'package:hopetsit/views/booking/bookings_history_screen.dart';
import 'package:hopetsit/views/profile/edit_owner_profile_screen.dart';
import 'package:hopetsit/views/profile/view_task_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/user_controller.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/models/profile_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/repositories/user_repository.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/auth/login_screen.dart';
import 'package:hopetsit/views/profile/add_card_screen.dart';
import 'package:hopetsit/views/profile/change_password_screen.dart';
import 'package:hopetsit/views/profile/add_task_screen.dart';
import 'package:hopetsit/views/profile/blocked_users_screen.dart';
import 'package:hopetsit/views/profile/my_pets_screen.dart';
import 'package:hopetsit/views/reviews/reviews_screen.dart';
import 'package:hopetsit/views/auth/choose_service_screen.dart';
import 'package:hopetsit/widgets/custom_confirmation_dialog.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

class ProfileController extends GetxController {
  ProfileController({
    OwnerRepository? ownerRepository,
    UserRepository? userRepository,
    GetStorage? storage,
  }) : _ownerRepository =
           ownerRepository ??
           (Get.isRegistered<OwnerRepository>()
               ? Get.find<OwnerRepository>()
               : throw Exception(
                   'OwnerRepository not registered. Please ensure setupDependencies() is called.',
                 )),
       _userRepository =
           userRepository ??
           (Get.isRegistered<UserRepository>()
               ? Get.find<UserRepository>()
               : throw Exception(
                   'UserRepository not registered. Please ensure setupDependencies() is called.',
                 )),
       _storage = storage ?? GetStorage();

  final OwnerRepository _ownerRepository;
  final UserRepository _userRepository;
  final GetStorage _storage;

  // Observable variables
  final RxBool isLoading = false.obs;
  final RxString userName = ''.obs;
  final RxString phoneNumber = ''.obs;
  final RxString email = ''.obs;
  final RxString profileImageUrl = ''.obs;
  final Rxn<ProfileModel> profile = Rxn<ProfileModel>();
  final RxBool isUploadingImage = false.obs;

  // Blocked users list
  final RxList<BlockedUser> blockedUsers = <BlockedUser>[].obs;
  final RxBool isLoadingBlockedUsers = false.obs;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void onInit() {
    super.onInit();
    // Skip authenticated API calls when no token (e.g. signup flow before login).
    final token = _storage.read<String>(StorageKeys.authToken);
    if (token != null && token.isNotEmpty) {
      applyStoredUserProfileDisplay();
      loadMyProfile();
      loadBlockedUsers();
    }
  }

  /// Fills [userName] / [profileImageUrl] from [StorageKeys.userProfile] when
  /// still empty. Helps app bars show the name immediately after signup/OTP
  /// and keeps UI correct if [ProfileController] was created before the token existed.
  void applyStoredUserProfileDisplay() {
    final raw = _storage.read(StorageKeys.userProfile);
    if (raw is! Map) return;
    final map = Map<String, dynamic>.from(raw);
    final name = map['name'] as String?;
    if (userName.value.isEmpty && name != null && name.trim().isNotEmpty) {
      userName.value = name.trim();
    }
    final avatar = map['avatar'];
    if (profileImageUrl.value.isEmpty && avatar is Map) {
      final url = avatar['url'] as String?;
      if (url != null && url.trim().isNotEmpty) {
        profileImageUrl.value = url.trim();
      }
    }
  }

  /// Loads `/users/me/profile` when we have a token but no display name yet
  /// (e.g. controller registered before auth).
  void ensureProfileLoadedForSession() {
    final token = _storage.read<String>(StorageKeys.authToken);
    if (token == null || token.isEmpty) return;
    if (isLoading.value) return;
    if (userName.value.isNotEmpty) return;
    loadMyProfile();
  }

  /// Loads the current user's profile from the API.
  Future<void> loadMyProfile() async {
    isLoading.value = true;

    try {
      // Get or create UserController
      UserController userController;
      if (Get.isRegistered<UserController>()) {
        userController = Get.find<UserController>();
      } else {
        userController = Get.put(UserController(_userRepository));
      }

      await userController.loadMyProfile();

      // Use the profile model from UserController
      if (userController.profile.value != null) {
        final profileData = userController.profile.value!;
        profile.value = profileData;
        userName.value = profileData.name;
        email.value = profileData.email;
        phoneNumber.value = profileData.mobile;
        profileImageUrl.value = profileData.avatar.url;
      }
    } on ApiException catch (error) {
      AppLogger.logError('Failed to load profile', error: error.message);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'profile_load_error'.tr,
      );
    } catch (error) {
      AppLogger.logError('Failed to load profile', error: error);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadBlockedUsers() async {
    isLoadingBlockedUsers.value = true;

    try {
      final blocksList = await _ownerRepository.getBlockedUsers();
      blockedUsers.value = blocksList.map((block) {
        return BlockedUser(
          id: block.id,
          sitterId: block.blocked.id,
          name: block.blocked.name,
          company: block.blocked.service.isNotEmpty
              ? block.blocked.service.join(', ')
              : 'Pet Sitter',
          profileImage: block.blocked.avatar.url.isNotEmpty
              ? block.blocked.avatar.url
              : '',
          blockedAt: DateTime.parse(block.createdAt),
        );
      }).toList();
    } on ApiException catch (error) {
      AppLogger.logError('Failed to load blocked users', error: error.message);
      blockedUsers.clear();
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'profile_blocked_users_load_error'.tr,
      );
    } catch (error) {
      AppLogger.logError('Failed to load blocked users', error: error);
      blockedUsers.clear();
    } finally {
      isLoadingBlockedUsers.value = false;
    }
  }

  Future<void> unblockUser(String userId) async {
    // Find the blocked user to get the sitterId
    final blockedUser = blockedUsers.firstWhere(
      (user) => user.id == userId,
      orElse: () => BlockedUser(
        id: '',
        sitterId: '',
        name: '',
        company: '',
        profileImage: '',
        blockedAt: DateTime.now(),
      ),
    );

    if (blockedUser.id.isEmpty || blockedUser.sitterId.isEmpty) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'profile_user_not_found'.tr,
      );
      return;
    }

    try {
      await _ownerRepository.unblockSitter(sitterId: blockedUser.sitterId);

      // Reload the blocked users list
      await loadBlockedUsers();

      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'profile_unblock_success'.tr,
      );
    } on ApiException catch (error) {
      CustomSnackbar.showError(
        title: 'profile_unblock_failed'.tr,
        message: error.message,
      );
    } catch (error) {
      AppLogger.logError('Failed to unblock user', error: error);
      CustomSnackbar.showError(
        title: 'profile_unblock_failed'.tr,
        message: 'profile_unblock_failed_generic'.tr,
      );
    }
  }

  // void saveBlockedUsers() {
  //   // TODO: Implement API call to save blocked users
  //   CustomSnackbar.showSuccess(
  //     title: 'snackbar_text_success',
  //     message: 'snackbar_text_blocked_users_saved_successfully',
  //   );
  //   Get.back();
  // }

  // Navigation methods
  void navigateToViewTask() {
    Get.to(() => const ViewTaskScreen());
  }

  void navigateToAddTasks() {
    Get.to(() => const AddTaskScreen());
  }

  void navigateToBookingsHistory() {
    Get.to(() => const BookingsHistoryScreen());
  }

  void navigateToBookingAgreement() {
    Get.to(
      () => BookingAgreementScreen(
        booking: BookingModel(
          id: '',
          petName: '',
          petWeight: '',
          petHeight: '',
          petColor: '',
          description: '',
          date: '',
          timeSlot: '',
          status: '',
          createdAt: '',
          updatedAt: '',
          owner: BookingUser(
            id: '',
            name: '',
            email: '',
            mobile: '',
            language: '',
            address: '',
            acceptedTerms: false,
            service: [],
            verified: false,
            createdAt: '',
            updatedAt: '',
            avatar: BookingAvatar(url: '', publicId: ''),
          ),
          sitter: BookingSitter(
            id: '',
            name: '',
            email: '',
            mobile: '',
            language: '',
            address: '',
            rate: '',
            skills: '',
            bio: '',
            acceptedTerms: false,
            service: [],
            verified: false,
            rating: 0,
            reviewsCount: 0,
            feedback: [],
            hourlyRate: 0,
            createdAt: '',
            updatedAt: '',
            avatar: BookingAvatar(url: '', publicId: ''),
          ),
          pets: [],
        ),
      ),
    );
  }

  void navigateToChangePassword() {
    Get.to(() => const ChangePasswordScreen(userType: 'pet_owner'));
  }

  void navigateToAddCard() {
    Get.to(() => const AddCardScreen(userType: 'pet_owner'));
  }

  void navigateToEditPetProfile() {
    Get.to(() => const MyPetsScreen());
  }

  void navigateToEditProfile() {
    Get.to(() => const EditOwnerProfileScreen());
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
        userType: 'pet_owner',
        email: email,
        isFromProfile: true,
      ),
    );
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
    Get.to(() => const BlockedUsersScreen(userType: 'pet_owner'));
  }

  void navigateToReviews() {
    Get.to(
      () => ReviewsScreen(
        serviceProviderName: 'Darlene Robertson',
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
      await _userRepository.deleteAccount();

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
    String userId,
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
        unblockUser(userId);
      },
    );
  }

  void showLogoutDialog(BuildContext context) {
    CustomConfirmationDialog.show(
      context: context,
      message: 'logout_dialog_message'.tr,
      yesText: 'common_yes'.tr,
      cancelText: 'common_cancel'.tr,
      onYes: () async {
        // Get AuthController and call logout
        if (Get.isRegistered<AuthController>()) {
          final authController = Get.find<AuthController>();
          await authController.logout();
        } else {
          // Fallback: navigate to login if AuthController is not registered
          Get.offAll(() => const LoginScreen());
        }
      },
    );
  }

  void editProfile() {
    // TODO: Implement edit profile functionality
    CustomSnackbar.showWarning(
      title: 'edit_profile_title'.tr,
      message: 'profile_edit_coming_soon'.tr,
    );
  }

  /// Picks an image from gallery and uploads it as profile picture.
  Future<void> pickAndUploadProfilePicture() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        // Ensure we only pick valid image formats
        preferredCameraDevice: CameraDevice.rear,
      );

      if (pickedFile == null) {
        return; // User cancelled
      }

      // Verify the file extension is valid
      final fileExtension = pickedFile.path.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'webp'].contains(fileExtension)) {
        CustomSnackbar.showError(
          title: 'profile_invalid_file_type'.tr,
          message: 'profile_invalid_file_type_message'.tr,
        );
        return;
      }

      final imageFile = File(pickedFile.path);
      await uploadProfilePicture(imageFile);
    } catch (error) {
      AppLogger.logError('Failed to pick image', error: error);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'profile_image_pick_failed'.tr,
      );
    }
  }

  /// Uploads the profile picture to the server.
  Future<void> uploadProfilePicture(File imageFile) async {
    isUploadingImage.value = true;

    try {
      final response = await _userRepository.updateProfilePicture(imageFile);

      // Extract the updated profile picture URL from response
      final profileData = response['profile'] as Map<String, dynamic>?;
      if (profileData != null) {
        final avatar = profileData['avatar'] as Map<String, dynamic>?;
        if (avatar != null) {
          final newImageUrl = avatar['url'] as String? ?? '';
          profileImageUrl.value = newImageUrl;

          // Update the profile model if it exists
          if (profile.value != null) {
            profile.value = ProfileModel.fromJson(profileData);
          }
        }
      }

      // Reload profile to get updated data
      await loadMyProfile();

      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'profile_picture_update_success'.tr,
      );
    } on ApiException catch (error) {
      AppLogger.logError(
        'Failed to upload profile picture',
        error: error.message,
      );
      CustomSnackbar.showError(
        title: 'profile_upload_failed'.tr,
        message: error.message,
      );
    } catch (error) {
      AppLogger.logError('Failed to upload profile picture', error: error);
      CustomSnackbar.showError(
        title: 'profile_upload_failed'.tr,
        message: 'profile_upload_failed_generic'.tr,
      );
    } finally {
      isUploadingImage.value = false;
    }
  }
}
