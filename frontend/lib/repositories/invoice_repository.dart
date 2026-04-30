import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_config.dart';
import 'package:hopetsit/data/network/api_endpoints.dart';
import 'package:hopetsit/models/invoice_model.dart';

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
  String htmlUrlFor(String invoiceId) {
    return '${ApiConfig.baseUrl}${ApiEndpoints.invoiceById}/$invoiceId/html';
  }
}
