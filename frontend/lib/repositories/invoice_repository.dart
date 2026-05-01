import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_config.dart';
import 'package:hopetsit/data/network/api_endpoints.dart';
import 'package:hopetsit/models/invoice_model.dart';
import 'package:hopetsit/utils/storage_keys.dart';

/// v23.1 — repository for the auto-generated Invoice resource.
class InvoiceRepository {
  final ApiClient _apiClient;
  InvoiceRepository(this._apiClient);

  /// Returns the invoices visible to the current user (owner / sitter / walker).
  Future<List<InvoiceModel>> getMyInvoices() async {
    final response = await _apiClient.get(
      ApiEndpoints.invoicesMy,
      requiresAuth: true,
    );
    if (response is Map) {
      final list = response['invoices'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => InvoiceModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    }
    return const [];
  }

  /// Builds the printable HTML URL for a given invoice. The Flutter screen
  /// opens this in a WebView so the user can use the system "Imprimer → PDF"
  /// to save the file locally.
  ///
  /// v23.1 part 34 — fix Daniel "page noire" : ajoute le JWT en query param
  /// `?token=JWT` pour que le browser/WebView (qui n'a pas de header
  /// Authorization) puisse s'authentifier auprès du backend.
  String htmlUrlFor(String invoiceId) {
    final base = '${ApiConfig.baseUrl}${ApiEndpoints.invoiceById}/$invoiceId/html';
    try {
      final storage = GetStorage();
      final token = storage.read<String>(StorageKeys.authToken) ?? '';
      if (token.isNotEmpty) {
        return '$base?token=${Uri.encodeQueryComponent(token)}';
      }
    } catch (_) {}
    return base;
  }
}
