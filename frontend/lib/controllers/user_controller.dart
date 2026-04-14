import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/profile_model.dart';
import 'package:hopetsit/repositories/user_repository.dart';

/// Controller exposing user data to the presentation layer.
class UserController extends GetxController {
  UserController(this._userRepository);

  final UserRepository _userRepository;

  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();
  final RxMap<String, dynamic> userProfile = <String, dynamic>{}.obs;
  final Rxn<ProfileModel> profile = Rxn<ProfileModel>();

  Future<void> loadUserProfile(String userId) async {
    isLoading.value = true;
    errorMessage.value = null;

    try {
      final response = await _userRepository.fetchUserProfile(userId);
      userProfile
        ..clear()
        ..addAll(response);
    } on ApiException catch (error) {
      errorMessage.value = error.message;
    } catch (error) {
      errorMessage.value = error.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> payload,
  ) async {
    isLoading.value = true;
    errorMessage.value = null;

    try {
      final response = await _userRepository.updateUserProfile(userId, payload);
      userProfile
        ..clear()
        ..addAll(response);
    } on ApiException catch (error) {
      errorMessage.value = error.message;
      rethrow;
    } catch (error) {
      errorMessage.value = error.toString();
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  /// Loads the current user's profile.
  Future<void> loadMyProfile() async {
    isLoading.value = true;
    errorMessage.value = null;

    try {
      final response = await _userRepository.getMyProfile();
      userProfile
        ..clear()
        ..addAll(response);

      // Parse profile model from response
      final profileData = response['profile'] as Map<String, dynamic>?;
      if (profileData != null) {
        profile.value = ProfileModel.fromJson(profileData);
      }
    } on ApiException catch (error) {
      errorMessage.value = error.message;
    } catch (error) {
      errorMessage.value = error.toString();
    } finally {
      isLoading.value = false;
    }
  }
}
