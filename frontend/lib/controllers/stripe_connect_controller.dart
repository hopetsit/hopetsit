import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/repositories/sitter_repository.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/views/pet_sitter/onboarding/stripe_connect_webview_screen.dart';

class StripeConnectController extends GetxController {
  StripeConnectController({SitterRepository? sitterRepository})
    : _sitterRepository = sitterRepository ?? Get.find<SitterRepository>();

  final SitterRepository _sitterRepository;

  final RxBool isConnecting = false.obs;
  final RxBool isLoadingStatus = false.obs;
  final RxString stripeAccountId = ''.obs;
  final RxBool isConnected = false.obs;
  final RxString accountStatus = ''.obs;
  final RxString onboardingUrl = ''.obs;
  final RxInt expiresAt = 0.obs;

  @override
  void onInit() {
    super.onInit();
    checkAccountStatus();
  }

  /// Checks the current Stripe Connect account status
  Future<void> checkAccountStatus() async {
    isLoadingStatus.value = true;

    try {
      final response = await _sitterRepository.getStripeConnectAccountStatus();

      stripeAccountId.value =
          response['accountId'] as String? ??
          response['account_id'] as String? ??
          '';
      accountStatus.value = response['status'] as String? ?? '';

      // Account is considered "connected" if it exists, but check if it's actually active
      final chargesEnabled = response['chargesEnabled'] as bool? ?? false;
      final payoutsEnabled = response['payoutsEnabled'] as bool? ?? false;
      final detailsSubmitted = response['detailsSubmitted'] as bool? ?? false;
      
      // Also check allVerificationsComplete if available (more reliable indicator)
      final allVerificationsComplete = response['allVerificationsComplete'] as bool?;
      
      // Account is truly active only if charges and payouts are enabled AND details are submitted
      // If allVerificationsComplete is available, use it as the primary check
      // Note: We ignore the API's "connected" field as it may be misleading (can be true even when restricted)
      if (allVerificationsComplete != null) {
        isConnected.value = allVerificationsComplete && chargesEnabled && payoutsEnabled;
      } else {
        // Fallback to original logic - all three must be true
        isConnected.value = chargesEnabled && payoutsEnabled && detailsSubmitted;
      }
      
      // Log the connection status for debugging
      AppLogger.logInfo(
        'Stripe Connect Status Calculated',
        data: {
          'accountId': stripeAccountId.value,
          'status': accountStatus.value,
          'chargesEnabled': chargesEnabled,
          'payoutsEnabled': payoutsEnabled,
          'detailsSubmitted': detailsSubmitted,
          'allVerificationsComplete': allVerificationsComplete,
          'isConnected': isConnected.value,
        },
      );

      // Get onboarding URL if available (for incomplete onboarding)
      final onboardingUrlString =
          response['onboardingUrl'] as String? ??
          response['onboarding_url'] as String? ??
          '';
      if (onboardingUrlString.isNotEmpty) {
        onboardingUrl.value = onboardingUrlString;
      }

      // If account exists but is restricted, we may need to create a new onboarding session
      if (stripeAccountId.value.isNotEmpty &&
          accountStatus.value == 'restricted' &&
          (!chargesEnabled || !payoutsEnabled || !detailsSubmitted)) {
        // Account needs to complete verification - we'll need to get a new onboarding URL
        // This will be handled when user tries to connect
      }

      // Get expiration timestamp if available
      if (response['expiresAt'] != null) {
        expiresAt.value = response['expiresAt'] is int
            ? response['expiresAt'] as int
            : (response['expires_at'] as int? ?? 0);
      }

      AppLogger.logUserAction(
        'Stripe Connect Status Checked',
        data: {
          'accountId': stripeAccountId.value,
          'status': accountStatus.value,
          'connected': isConnected.value,
          'hasOnboardingUrl': onboardingUrl.value.isNotEmpty,
        },
      );
    } on ApiException catch (error) {
      AppLogger.logError('Failed to check Stripe status', error: error.message);
      // Don't show error to user on init, just log it
    } catch (e) {
      AppLogger.logError('Failed to check Stripe status', error: e);
    } finally {
      isLoadingStatus.value = false;
    }
  }

  /// Creates a Stripe Connect account and opens onboarding URL
  Future<void> connectStripe() async {
    // If account exists but is not fully active, create a new onboarding session
    if (stripeAccountId.value.isNotEmpty && !isConnected.value) {
      // Account exists but needs verification - create new onboarding session
      AppLogger.logUserAction(
        'Creating new onboarding session for existing account',
        data: {
          'accountId': stripeAccountId.value,
          'status': accountStatus.value,
        },
      );
      // Continue to create onboarding session below
    } else if (stripeAccountId.value.isNotEmpty && isConnected.value) {
      CustomSnackbar.showSuccess(
        title: 'stripe_already_connected'.tr,
        message: 'stripe_already_connected_message'.tr,
      );
      return;
    } else if (stripeAccountId.value.isNotEmpty) {
      // Account exists but onboarding URL might be expired
      if (onboardingUrl.value.isNotEmpty && !isOnboardingUrlExpired()) {
        openOnboardingWebview();
        return;
      }
      // Continue to create new onboarding session
    }

    isConnecting.value = true;

    try {
      AppLogger.logUserAction('Creating Stripe Connect Account');

      final response = await _sitterRepository.createStripeConnectAccount();

      final onboardingUrlString =
          response['onboardingUrl'] as String? ??
          response['onboarding_url'] as String? ??
          response['url'] as String?;

      if (onboardingUrlString == null || onboardingUrlString.isEmpty) {
        throw ApiException('Failed to get Stripe onboarding URL.');
      }

      final accountIdString =
          response['accountId'] as String? ??
          response['account_id'] as String? ??
          '';

      if (accountIdString.isEmpty) {
        throw ApiException('Failed to get Stripe account ID.');
      }

      // Store response data
      onboardingUrl.value = onboardingUrlString;
      stripeAccountId.value = accountIdString;

      // Handle expiresAt timestamp if provided
      if (response['expiresAt'] != null) {
        expiresAt.value = response['expiresAt'] is int
            ? response['expiresAt'] as int
            : (response['expires_at'] as int? ?? 0);
      }

      AppLogger.logUserAction(
        'Stripe Connect Account Created',
        data: {
          'accountId': stripeAccountId.value,
          'onboardingUrl': onboardingUrl.value,
          'expiresAt': expiresAt.value,
        },
      );

      // Navigate to webview screen to complete onboarding
      Get.to(
        () => StripeConnectWebviewScreen(
          onboardingUrl: onboardingUrl.value,
          accountId: stripeAccountId.value,
        ),
      )?.then((_) {
        // Refresh account status when returning from webview
        checkAccountStatus();
      });
    } on ApiException catch (error) {
      AppLogger.logError('Failed to connect Stripe', error: error.message);
      CustomSnackbar.showError(title: 'common_error'.tr, message: error.message);
    } catch (e) {
      AppLogger.logError('Failed to connect Stripe', error: e);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'stripe_connect_error'.tr,
      );
    } finally {
      isConnecting.value = false;
    }
  }

  /// Checks if the onboarding URL has expired
  bool isOnboardingUrlExpired() {
    if (expiresAt.value == 0) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return expiresAt.value < now;
  }

  /// Opens the onboarding webview if URL is available and not expired
  void openOnboardingWebview() {
    if (onboardingUrl.value.isEmpty) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'stripe_no_onboarding_url'.tr,
      );
      return;
    }

    if (isOnboardingUrlExpired()) {
      CustomSnackbar.showWarning(
        title: 'stripe_onboarding_expired_title'.tr,
        message: 'stripe_onboarding_expired_message'.tr,
      );
      return;
    }

    Get.to(
      () => StripeConnectWebviewScreen(
        onboardingUrl: onboardingUrl.value,
        accountId: stripeAccountId.value,
      ),
    )?.then((_) {
      // Refresh account status when returning from webview
      checkAccountStatus();
    });
  }

  Future<void> disconnectStripe() async {
    try {
      // TODO: Implement Stripe disconnect API call
      AppLogger.logUserAction('Disconnecting Stripe Account');

      isConnected.value = false;
      stripeAccountId.value = '';

      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'stripe_disconnect_success'.tr,
      );
    } on ApiException catch (error) {
      AppLogger.logError('Failed to disconnect Stripe', error: error.message);
      CustomSnackbar.showError(title: 'common_error'.tr, message: error.message);
    } catch (e) {
      AppLogger.logError('Failed to disconnect Stripe', error: e);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'stripe_disconnect_error'.tr,
      );
    }
  }
}
