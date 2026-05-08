import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_config.dart';

/// v23.1 part 36 — KYC verification repository (Persona).
/// v23.1 part 113 — fallback manuel : si Persona n'est pas dispo, le user
/// peut uploader sa pièce d'identité directement (revue par l'admin).
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

  /// v23.1 part 75 — POST /kyc/confirm-payment.
  /// Forces server-side confirmation of the KYC payment without waiting
  /// for the Airwallex webhook. Idempotent : if already confirmed,
  /// returns the existing kycStatus. Used as a fallback when the webhook
  /// is misconfigured or hasn't yet landed.
  Future<Map<String, dynamic>> confirmPayment() async {
    final response = await _apiClient.post(
      '/kyc/confirm-payment',
      requiresAuth: true,
      body: {},
    );
    if (response is Map) return Map<String, dynamic>.from(response);
    return const {};
  }

  /// v23.1 part 113 — Fallback manuel.
  ///
  /// POST /sitters/identity-verification (ou /walkers/identity-verification
  /// selon le rôle) en multipart avec le fichier "document".
  /// Crée identityVerification.status='pending'. L'admin review depuis
  /// la queue admin web ; à l'approbation, kycStatus + verified passent
  /// tous deux à 'verified' (cf v23.1 part 112 sync).
  Future<Map<String, dynamic>> uploadIdentityManually({
    required File file,
    required String role, // 'sitter' | 'walker'
  }) async {
    final basePath = role == 'walker'
        ? '/walkers/identity-verification'
        : '/sitters/identity-verification';
    final uri = Uri.parse('${ApiConfig.baseUrl}$basePath');

    final token = Get.find<ApiClient>().authToken;
    final request = http.MultipartRequest('POST', uri);
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(
      await http.MultipartFile.fromPath('document', file.path),
    );
    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode >= 400) {
      throw Exception('Upload failed (${streamed.statusCode}): $body');
    }
    if (body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        // Ignore: server returned non-JSON, treat as empty success.
      }
    }
    return const {};
  }
}
