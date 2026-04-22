// v18.5 — #9 fix : lightweight controller that surfaces the IBAN
// configuration status so UI widgets (e.g. the 4 quick-status icons on
// PaymentManagementScreen) can paint a green dot once the provider has
// saved a verified IBAN.
//
// Backend: GET /sitter/iban (sitter) or /walker/iban (walker). Both routes
// are served by ibanRoutes.js which uses req.user.role to pick the right
// collection. If the provider has not saved an IBAN yet, backend returns
// an object with empty `ibanNumberMasked` and `ibanVerified: false`.

import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_endpoints.dart';
import 'package:hopetsit/utils/logger.dart';

class IbanStatusController extends GetxController {
  IbanStatusController({ApiClient? apiClient})
    : _apiClient = apiClient ?? Get.find<ApiClient>();

  final ApiClient _apiClient;

  /// True if the provider has saved an IBAN (masked string not empty).
  final RxBool ibanConfigured = false.obs;

  /// True if the saved IBAN passed the mod97 validation on the backend.
  final RxBool ibanVerified = false.obs;

  /// Loading flag for UI shimmer if needed.
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    refreshStatus();
  }

  /// Fetch from backend. Safe to call multiple times (idempotent).
  Future<void> refreshStatus() async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      final response = await _apiClient.get(
        ApiEndpoints.sitterMeIban, // unified: /sitter/iban works for walker too
        requiresAuth: true,
      );
      if (response is Map<String, dynamic>) {
        final masked = (response['ibanNumberMasked'] ?? '') as String;
        final verified = (response['ibanVerified'] ?? false) as bool;
        ibanConfigured.value = masked.isNotEmpty;
        ibanVerified.value = verified;
      }
    } catch (e) {
      // No IBAN saved yet or not a provider — keep defaults (false).
      AppLogger.logDebug('IbanStatusController refresh: ${e.toString()}');
      ibanConfigured.value = false;
      ibanVerified.value = false;
    } finally {
      isLoading.value = false;
    }
  }
}
