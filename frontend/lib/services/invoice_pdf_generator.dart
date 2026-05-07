// v23.1 part 73 — Native PDF generation for invoices.
//
// Daniel : "facture se telecharge en htlm elle peux pas se telecharger
// directement en pdf sur le tel". Previously _triggerPrint downloaded
// the HTML invoice and shared it as text/html — fine on desktop but
// the user wanted a real PDF that opens with any PDF viewer on the
// phone.
//
// This module builds the PDF locally from InvoiceModel using the `pdf`
// package (no backend round-trip, no external service). The resulting
// bytes are returned ; the caller saves to disk or shares via Share.

import 'package:hopetsit/models/invoice_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class InvoicePdfGenerator {
  InvoicePdfGenerator._();

  static Future<List<int>> build(InvoiceModel inv) async {
    final doc = pw.Document();

    final orange = PdfColor.fromInt(0xFFEF4324);
    final dark = PdfColor.fromInt(0xFF1F1F1F);
    final muted = PdfColor.fromInt(0xFF777777);
    final isRefunded = inv.status.toLowerCase() == 'refunded';
    final accent = isRefunded ? PdfColor.fromInt(0xFFC62828) : orange;
    final symbol = _symbolFor(inv.currency);
    final fmtAmount = (double v) => '$symbol${v.toStringAsFixed(2)}';
    final fmtDate = (DateTime? d) {
      if (d == null) return '—';
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      return '$dd/$mm/${d.year}';
    };

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 40),
        build: (context) => [
          // Header : logo + "Facture HoPetSit"
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _logo(),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('HoPetSit',
                        style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: orange)),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Operated by CARDELLI HERMANOS LIMITED · Hong Kong',
                      style: pw.TextStyle(fontSize: 9, color: muted),
                    ),
                    pw.Text(
                      'Company No. n-2671528 · contact@hopetsit.com',
                      style: pw.TextStyle(fontSize: 9, color: muted),
                    ),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: accent,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  isRefunded ? 'REFUNDED' : 'PAID',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Container(height: 2, color: orange),
          pw.SizedBox(height: 18),

          // Invoice number + dates
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('FACTURE',
                        style: pw.TextStyle(
                            fontSize: 11, color: muted, letterSpacing: 1.4)),
                    pw.SizedBox(height: 4),
                    pw.Text(inv.invoiceNumber,
                        style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: dark)),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _kvRight('Émise le', fmtDate(inv.issuedAt), muted),
                  _kvRight('Payée le', fmtDate(inv.paidAt), muted),
                  if (inv.refundedAt != null)
                    _kvRight('Remboursée le', fmtDate(inv.refundedAt), muted),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 24),

          // Bill To / Service Provider
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _partyBox('FACTURÉ À', inv.ownerName, 'Propriétaire', accent),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _partyBox(
                  'PRESTATAIRE',
                  inv.providerName,
                  inv.providerRole.toUpperCase(),
                  accent,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 24),

          // Service description table
          _serviceTable(inv, accent, muted, fmtDate),

          pw.SizedBox(height: 24),

          // Totals
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 280,
              child: pw.Column(children: [
                _totalRow('Montant brut', fmtAmount(inv.grossAmount), muted),
                _totalRow(
                  'Commission HoPetSit (20%)',
                  '-${fmtAmount(inv.commission)}',
                  muted,
                ),
                _totalRow(
                  'Net au prestataire',
                  fmtAmount(inv.netPayout),
                  muted,
                ),
                pw.Divider(color: orange, thickness: 2),
                _totalRow(
                  'Total payé',
                  fmtAmount(inv.grossAmount),
                  accent,
                  bold: true,
                  big: true,
                ),
              ]),
            ),
          ),

          pw.SizedBox(height: 30),

          // Footer
          pw.Container(
            padding: const pw.EdgeInsets.only(top: 14),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey300, width: 1),
              ),
            ),
            child: pw.Text(
              'Cette facture est générée automatiquement par HoPetSit. '
              'Toute question : contact@hopetsit.com',
              style: pw.TextStyle(fontSize: 9, color: muted),
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _logo() {
    // Simple orange rounded square + multicolor paw, recreated with pdf
    // primitives. Simplified version of the SVG used in the HTML invoice.
    return pw.Container(
      width: 56,
      height: 56,
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFEF4324),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Center(
        child: pw.Text(
          '🐾',
          style: const pw.TextStyle(fontSize: 30, color: PdfColors.white),
        ),
      ),
    );
  }

  static pw.Widget _kvRight(String k, String v, PdfColor muted) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text('$k : ', style: pw.TextStyle(fontSize: 10, color: muted)),
          pw.Text(v,
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _partyBox(String label, String name, String sub, PdfColor accent) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF7F2FF),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: accent, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.2,
                  color: accent,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(name.isNotEmpty ? name : '—',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text(sub, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        ],
      ),
    );
  }

  static pw.Widget _serviceTable(
    InvoiceModel inv,
    PdfColor accent,
    PdfColor muted,
    String Function(DateTime?) fmtDate,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.5),
        1: pw.FlexColumnWidth(1.7),
        2: pw.FlexColumnWidth(1.6),
        3: pw.FlexColumnWidth(1.0),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: accent),
          children: [
            _th('Description'),
            _th('Date(s) de service'),
            _th('Animal(aux)'),
            _th('Statut'),
          ],
        ),
        pw.TableRow(children: [
          _td(_serviceLabel(inv.serviceType)),
          _td(_serviceDateRange(inv, fmtDate)),
          _td(inv.petNames.isEmpty ? '—' : inv.petNames.join(', ')),
          _td(inv.status.toUpperCase()),
        ]),
      ],
    );
  }

  static pw.Widget _th(String t) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: pw.Text(
          t,
          style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );

  static pw.Widget _td(String t) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: pw.Text(t, style: const pw.TextStyle(fontSize: 10)),
      );

  static pw.Widget _totalRow(
    String k,
    String v,
    PdfColor color, {
    bool bold = false,
    bool big = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(k, style: pw.TextStyle(fontSize: big ? 13 : 11, color: color)),
          pw.Text(
            v,
            style: pw.TextStyle(
              fontSize: big ? 14 : 11,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static String _serviceLabel(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('walk')) return 'Promenade chien';
    if (s.contains('day_care') || s.contains('garderie')) return 'Garderie';
    if (s.contains('boarding') || s.contains('overnight')) return 'Garde nuit';
    if (s.contains('sitting')) return 'Pet-sitting';
    return raw.isEmpty ? 'Service' : raw;
  }

  static String _serviceDateRange(
      InvoiceModel inv, String Function(DateTime?) fmt) {
    if (inv.startDate != null && inv.endDate != null &&
        inv.startDate!.day != inv.endDate!.day) {
      return '${fmt(inv.startDate)} → ${fmt(inv.endDate)}';
    }
    return fmt(inv.serviceDate ?? inv.startDate ?? inv.issuedAt);
  }

  static String _symbolFor(String currency) {
    switch (currency.toUpperCase()) {
      case 'EUR': return '€';
      case 'GBP': return '£';
      case 'CHF': return 'CHF ';
      case 'USD': return '\$';
      default:    return '$currency ';
    }
  }
}
