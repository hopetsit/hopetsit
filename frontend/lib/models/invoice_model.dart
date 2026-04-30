/// v23.1 — Invoice model used by Mes Réservations → onglet Factures
/// (owner / sitter / walker).
class InvoiceModel {
  final String id;
  final String invoiceNumber;
  final String bookingId;
  final String ownerName;
  final String providerName;
  final String providerRole; // 'sitter' | 'walker'
  final String serviceType;
  final List<String> petNames;
  final DateTime? serviceDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final double grossAmount;
  final double commission;
  final double netPayout;
  final String currency;
  final String status; // 'paid' | 'refunded'
  final DateTime? issuedAt;
  final DateTime? paidAt;
  final DateTime? refundedAt;

  InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.bookingId,
    required this.ownerName,
    required this.providerName,
    required this.providerRole,
    required this.serviceType,
    required this.petNames,
    this.serviceDate,
    this.startDate,
    this.endDate,
    required this.grossAmount,
    required this.commission,
    required this.netPayout,
    required this.currency,
    required this.status,
    this.issuedAt,
    this.paidAt,
    this.refundedAt,
  });

  static DateTime? _date(dynamic v) {
    if (v == null) return null;
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    return null;
  }

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      invoiceNumber: (json['invoiceNumber'] ?? '').toString(),
      bookingId: (json['bookingId'] ?? '').toString(),
      ownerName: (json['ownerName'] ?? '').toString(),
      providerName: (json['providerName'] ?? '').toString(),
      providerRole: (json['providerRole'] ?? 'sitter').toString(),
      serviceType: (json['serviceType'] ?? '').toString(),
      petNames: (json['petNames'] is List)
          ? List<String>.from(
              (json['petNames'] as List).map((e) => e.toString()),
            )
          : <String>[],
      serviceDate: _date(json['serviceDate']),
      startDate: _date(json['startDate']),
      endDate: _date(json['endDate']),
      grossAmount: (json['grossAmount'] as num?)?.toDouble() ?? 0.0,
      commission: (json['commission'] as num?)?.toDouble() ?? 0.0,
      netPayout: (json['netPayout'] as num?)?.toDouble() ?? 0.0,
      currency: (json['currency'] ?? 'EUR').toString(),
      status: (json['status'] ?? 'paid').toString(),
      issuedAt: _date(json['issuedAt']),
      paidAt: _date(json['paidAt']),
      refundedAt: _date(json['refundedAt']),
    );
  }
}
