import 'package:hopetsit/data/network/api_client.dart';

/// v23.1 part 36 — KYC verification repository (Persona).
class KycRepository {
  final ApiClient _apiClient;
  KycRepository(this._apiClient);

  /// GET /kyc/status — returns current user's KYC state.
  Future<Map<String, dynamic>> getStatus() async {
    final response = await _apiClient.get('/kyc/status', requiresAuth: true);
    if (response is Map) return Map<String, dynamic>.from(response);
    return const {};
  }

  /// POST /kyc/initiate-payment — starts the 3 EUR Airwallex flow.
  /// Returns { paymentIntent: { id, clientSecret }, amount, currency }.
  Future<Map<String, dynamic>> initiatePayment() async {
    final response = await _apiClient.post(
      '/kyc/initiate-payment',
      requiresAuth: true,
      body: {},
    );
    if (response is Map) return Map<String, dynamic>.from(response);
    return const {};
  }

  /// POST /kyc/start — after payment, creates Persona inquiry and returns
  /// the one-time hosted link to open in a WebView.
  Future<Map<String, dynamic>> startVerification() async {
    final response = await _apiClient.post(
      '/kyc/start',
      requiresAuth: true,
      body: {},
    );
    if (response is Map) return Map<String, dynamic>.from(response);
    return const {};
  }
}
