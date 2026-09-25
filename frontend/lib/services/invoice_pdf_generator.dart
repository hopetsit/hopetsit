// v23.1 part 73 — Native PDF generation for invoices.
// v23.1.168 — Daniel : "qd je change la facture de langue sa marche pas
// et le symbole euro est partie verifie et corrige".
//   Fix #1 : la facture PDF ignorait `Get.locale` et hardcodait tout en
//   français → on lit la locale au build et on traduit toutes les strings.
//   Fix #2 : le symbole € s'affichait en carré vide car la fonte Helvetica
//   par défaut (Type1, WinAnsi) du package `pdf` ne contient pas le glyphe
//   selon le `pdf_widgets` build sur Android. On charge maintenant Noto Sans
//   via `printing/PdfGoogleFonts` qui contient tous les glyphes Unicode
//   (€, €, accents diacritiques, etc.).

import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:hopetsit/models/billing_info_model.dart';
import 'package:hopetsit/models/invoice_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:hopetsit/utils/currency_helper.dart';

class InvoicePdfGenerator {
  InvoicePdfGenerator._();

  // v576 — logos RÉELS dans le PDF enregistré sur le téléphone : le logo
  // officiel HoPetSit (celui de la marque refaite au build 570) en en-tête, et
  // celui de CARDELLI HERMANOS LIMITED — l'entité qui facture — dans le bloc
  // légal. Avant, l'en-tête n'avait qu'un carré orange avec un emoji 🐾.
  // Chargés une seule fois puis gardés en mémoire ; un asset illisible ne doit
  // jamais empêcher la génération du PDF (repli : pas d'image).
  static pw.MemoryImage? _brandLogo;
  static pw.MemoryImage? _issuerLogo;
  static bool _logosTried = false;

  static Future<void> _loadLogos() async {
    if (_logosTried) return;
    _logosTried = true;
    Future<pw.MemoryImage?> load(String asset) async {
      try {
        final data = await rootBundle.load(asset);
        return pw.MemoryImage(data.buffer.asUint8List());
      } catch (_) {
        return null;
      }
    }
    _brandLogo = await load('assets/brand/png/logo-mark-192.png');
    _issuerLogo = await load('assets/brand/png/cardelli_hermanos_logo.png');
  }

  static Future<List<int>> build(InvoiceModel inv) async {
    final doc = pw.Document();
    await _loadLogos();

    // v23.1.168 — Noto Sans contient le € + accents. On charge regular + bold
    // une seule fois et on les réutilise via le pw.Theme global.
    final fontReg = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final fontEmoji = await PdfGoogleFonts.notoColorEmoji();
    final theme = pw.ThemeData.withFont(
      base: fontReg,
      bold: fontBold,
      fontFallback: [fontEmoji, fontReg],
    );

    final orange = PdfColor.fromInt(0xFFC92A12);
    final dark = PdfColor.fromInt(0xFF261B18);
    final muted = PdfColor.fromInt(0xFF8A6C64);
    final isRefunded = inv.status.toLowerCase() == 'refunded';
    final accent = isRefunded ? PdfColor.fromInt(0xFFC62828) : orange;
    // Lot D — même format que l'écran des factures (langue de l'app).
    String fmtAmount(double v) => CurrencyHelper.format(inv.currency, v);
    String fmtDate(DateTime? d) {
      if (d == null) return '—';
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      return '$dd/$mm/${d.year}';
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
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
                    // v576 — ces deux lignes étaient EN ANGLAIS en dur, même
                    // sur une facture française.
                    pw.Text(
                      '${'invoice576_operated_by'.tr} $_kIssuerName · $_kIssuerPlace',
                      style: pw.TextStyle(fontSize: 9, color: muted),
                    ),
                    pw.Text(
                      '${'invoice576_company_no'.tr} : $_kIssuerNumber · $_kIssuerEmail',
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
                  (isRefunded ? 'invoice576_status_refunded' : 'invoice576_status_paid')
                      .tr
                      .toUpperCase(),
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
                    pw.Text('invoice_pdf_label'.tr,
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
                  _kvRight('invoice_pdf_issued'.tr, fmtDate(inv.issuedAt), muted),
                  _kvRight('invoice_pdf_paid'.tr, fmtDate(inv.paidAt), muted),
                  if (inv.refundedAt != null)
                    _kvRight('invoice_pdf_refunded'.tr, fmtDate(inv.refundedAt), muted),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 24),

          // v566 — Émetteur (prestataire) / Client (propriétaire), avec les
          // informations de facturation de chacun quand elles existent (nom
          // légal, « NIF : … », « TVA : … », adresse). Rien si c'est vide.
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _partyBox(
                  'billing_issuer'.tr.toUpperCase(),
                  inv.providerName,
                  _roleLabel(inv.providerRole),
                  accent,
                  billing: inv.issuerBilling,
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _partyBox(
                  'billing_customer'.tr.toUpperCase(),
                  inv.ownerName,
                  'invoice_pdf_owner_role'.tr,
                  accent,
                  billing: inv.customerBilling,
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
                _totalRow('invoice_pdf_gross'.tr, fmtAmount(inv.grossAmount), muted),
                _totalRow(
                  'invoice_pdf_commission'.tr,
                  '-${fmtAmount(inv.commission)}',
                  muted,
                ),
                _totalRow(
                  'invoice_pdf_net_provider'.tr,
                  fmtAmount(inv.netPayout),
                  muted,
                ),
                pw.Divider(color: orange, thickness: 2),
                _totalRow(
                  'invoice_pdf_total_paid'.tr,
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
                top: pw.BorderSide(color: PdfColor.fromInt(0xFFDECBC6), width: 1),
              ),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (_issuerLogo != null) ...[
                  pw.SizedBox(width: 34, height: 34, child: pw.Image(_issuerLogo!)),
                  pw.SizedBox(width: 10),
                ],
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '$_kIssuerName · $_kIssuerPlace · '
                        '${'invoice576_company_no'.tr} : $_kIssuerNumber · $_kIssuerEmail',
                        style: pw.TextStyle(fontSize: 9, color: muted),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'invoice_pdf_footer'.tr,
                        style: pw.TextStyle(fontSize: 9, color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  // Identité de l'entité qui facture (mêmes valeurs que le pied de page de la
  // facture HTML côté serveur — rien d'inventé).
  static const String _kIssuerName = 'CARDELLI HERMANOS LIMITED';
  static const String _kIssuerPlace = 'Hong Kong';
  static const String _kIssuerNumber = 'n-2671528';
  static const String _kIssuerEmail = 'contact@hopetsit.com';

  static String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'walker':
        return 'invoice576_role_walker'.tr;
      case 'sitter':
        return 'invoice576_role_sitter'.tr;
      default:
        return role;
    }
  }

  static pw.Widget _logo() {
    // v576 — logo officiel de la marque. Repli sur le carré rouge uni si
    // l'asset manque : jamais de trou ni de plantage.
    final img = _brandLogo;
    if (img != null) {
      return pw.SizedBox(width: 56, height: 56, child: pw.Image(img));
    }
    return pw.Container(
      width: 56,
      height: 56,
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFC92A12),
        borderRadius: pw.BorderRadius.circular(12),
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

  static pw.Widget _partyBox(
    String label,
    String name,
    String sub,
    PdfColor accent, {
    BillingInfo billing = BillingInfo.empty,
  }) {
    // Le nom légal prime sur le nom de profil ; ce dernier reste affiché en
    // dessous quand il est différent (ex. raison sociale + personne).
    final legal = billing.legalName;
    final title = legal.isNotEmpty ? legal : name;
    final showProfileName = legal.isNotEmpty &&
        name.isNotEmpty &&
        legal.toLowerCase() != name.toLowerCase();
    final details = billing.detailLines;
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
          pw.Text(title.isNotEmpty ? title : '—',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text(showProfileName ? '$name · $sub' : sub,
              style: pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFF6E4F48))),
          if (details.isNotEmpty) pw.SizedBox(height: 6),
          for (final line in details)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 1.5),
              child: pw.Text(line,
                  style: pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFF261B18))),
            ),
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
      border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFDECBC6), width: 0.4),
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
            _th('invoice_pdf_desc'.tr),
            _th('invoice_pdf_service_dates'.tr),
            _th('invoice_pdf_pets'.tr),
            _th('invoice_pdf_status'.tr),
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
    if (s.contains('walk')) return 'invoice_pdf_service_walk'.tr;
    if (s.contains('day_care') || s.contains('garderie')) return 'invoice_pdf_service_daycare'.tr;
    if (s.contains('boarding') || s.contains('overnight')) return 'invoice_pdf_service_boarding'.tr;
    if (s.contains('sitting')) return 'invoice_pdf_service_sitting'.tr;
    return raw.isEmpty ? 'invoice_pdf_service_generic'.tr : raw;
  }

  static String _serviceDateRange(
      InvoiceModel inv, String Function(DateTime?) fmt) {
    if (inv.startDate != null && inv.endDate != null &&
        inv.startDate!.day != inv.endDate!.day) {
      return '${fmt(inv.startDate)} → ${fmt(inv.endDate)}';
    }
    return fmt(inv.serviceDate ?? inv.startDate ?? inv.issuedAt);
  }

}
