import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_endpoints.dart';

/// Sprint 7 step 1 — owner loyalty stats controller.
class LoyaltyController extends GetxController {
  final ApiClient _api = Get.isRegistered<ApiClient>()
      ? Get.find<ApiClient>()
      : ApiClient();

  final RxInt completedBookingsCount = 0.obs;
  final RxBool isPremium = false.obs;
  final RxBool hasDiscountAvailable = false.obs;
  final RxDouble availableCreditsTotal = 0.0.obs;
  final RxString currency = 'EUR'.obs;
  final RxBool isLoading = false.obs;
  /// UI intent: apply the -10% discount on next payment intent creation.
  final RxBool useLoyaltyCreditForNextPayment = false.obs;

  Future<void> load() async {
    isLoading.value = true;
    try {
      final r = await _api.get(ApiEndpoints.myLoyalty, requiresAuth: true);
      if (r is Map) {
        // Backend may return counts as double — coerce via num.
        completedBookingsCount.value =
            ((r['completedBookingsCount'] ?? 0) as num).toInt();
        isPremium.value = r['isPremium'] == true;
        hasDiscountAvailable.value = r['hasDiscountAvailable'] == true;
        availableCreditsTotal.value =
            ((r['availableCreditsTotal'] ?? 0) as num).toDouble();
        final credits = (r['credits'] as List?) ?? const [];
        if (credits.isNotEmpty) {
          currency.value = (credits.first['currency'] ?? 'EUR').toString();
        }
      }
    } catch (_) {
      // Silent failure — stats stay at defaults.
    } finally {
      isLoading.value = false;
    }
  }

  int get nextDiscountIn {
    final c = completedBookingsCount.value;
    final remaining = 3 - (c % 3);
    return remaining == 3 ? 3 : remaining;
  }

  int get bookingsToPremium =>
      isPremium.value ? 0 : 10 - completedBookingsCount.value;
}
