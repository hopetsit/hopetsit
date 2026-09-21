import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/controllers/billing_info_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/invoice_model.dart';
import 'package:hopetsit/repositories/invoice_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/views/booking/widgets/booking_ui_kit.dart';
import 'package:hopetsit/views/invoices/invoice_viewer_screen.dart';
import 'package:hopetsit/views/invoices/widgets/invoice_billing_blocks.dart';
import 'package:hopetsit/views/pet_owner/payments/saved_cards_screen.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:intl/intl.dart';
import 'package:hopetsit/utils/bottom_inset.dart';

/// v23.1 — Mes factures (auto-générées au paiement de chaque réservation).
/// Accessible depuis l'onglet "Factures" de Mes Réservations sur les 3
/// profils owner / sitter / walker.
///
/// v565 (point 28) — kit Profil / Réservations : liste groupée, couleur du
/// rôle, états chargement / vide / erreur avec « Réessayer », dates localisées.
class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  late final InvoiceRepository _repo;
  final RxList<InvoiceModel> _invoices = <InvoiceModel>[].obs;
  final RxBool _isLoading = false.obs;
  final RxnString _errorMessage = RxnString();
  // v566 — bandeau « Ajoute tes informations de facturation ».
  late final BillingInfoController _billing;

  Color get _accent => currentRoleAccent();

  @override
  void initState() {
    super.initState();
    _repo = Get.isRegistered<InvoiceRepository>()
        ? Get.find<InvoiceRepository>()
        : InvoiceRepository(Get.find<ApiClient>());
    _billing = BillingInfoController.ensure();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _billing.loadIfNeeded();
    });
    _load();
  }

  Future<void> _load() async {
    _isLoading.value = true;
    _errorMessage.value = null;
    try {
      final list = await _repo.getMyInvoices();
      _invoices.assignAll(list);
    } on ApiException catch (e) {
      _errorMessage.value = paymentErrorMessage(e);
    } catch (e) {
      _errorMessage.value = e.toString();
    } finally {
      _isLoading.value = false;
    }
  }

  /// v23.1 part 48 — fix Daniel "qd je clique sur facture, on voit
  /// backend.onrender.com peut on cacher ?". Previously we used
  /// `launchUrl(externalApplication)` which opens Chrome with the full
  /// Render URL visible in the address bar — looks unprofessional. Now
  /// we open the same HTML in an in-app WebView with a clean HoPetSit
  /// header. The user never sees the backend URL.
  Future<void> _openInvoice(InvoiceModel inv) async {
    // v576 — BUG : un identifiant vide produisait l'URL « /invoices//html »
    // (et « /invoices/undefined/html » côté web), donc une page d'erreur au
    // lieu de la facture. Le tap doit toujours aboutir à un résultat VISIBLE.
    if (inv.id.trim().isEmpty) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'invoice576_open_failed'.tr,
      );
      return;
    }
    // v23.1.162 — Daniel : page facture en FR sur UI espagnole. Le HTML
    // est genere par le backend, donc on doit lui dire dans quelle langue
    // afficher. On lit la locale active de GetX et on ajoute ?lang=xx a
    // l'URL. Backend (invoiceController.js) accepte en/fr/es/de/it/pt et
    // fallback sur en si la locale n'est pas supportee.
    final baseUrl = _repo.htmlUrlFor(inv.id);
    final lang = (Get.locale?.languageCode ?? 'en').toLowerCase();
    final separator = baseUrl.contains('?') ? '&' : '?';
    final url = '$baseUrl${separator}lang=$lang';
    Get.to(
      () => InvoiceViewerScreen(
        url: url,
        invoiceNumber: inv.invoiceNumber,
        invoice: inv, // v23.1 part 73 — needed for native PDF generation
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return ProfileSubPageScaffold(
      title: 'invoices_title'.tr,
      accent: accent,
      scroll: false,
      padding: EdgeInsets.zero,
      body: RefreshIndicator(
        color: accent,
        onRefresh: _load,
        child: Obx(() {
          // v566 — lu AVANT les retours anticipés : l'Obx doit suivre ces valeurs.
          final billingMissing = _billing.loaded.value && _billing.info.value.isEmpty;
          if (_isLoading.value && _invoices.isEmpty) {
            return BookingLoadingList(accent: accent);
          }
          if (_errorMessage.value != null && _invoices.isEmpty) {
            return BookingErrorState(
              message: _errorMessage.value!,
              onRetry: _load,
            );
          }
          if (_invoices.isEmpty) {
            return BookingEmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'invoices_empty_title'.tr,
              subtitle: 'invoices_empty_message'.tr,
              accent: accent,
            );
          }
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            // v569 — dernière facture au-dessus de la barre système.
            padding: EdgeInsets.fromLTRB(
                16.w, 8.h, 16.w, 28.h + appBottomInsetInsideSafeArea(context)),
            children: [
              ProfileInfoBanner(
                icon: Icons.picture_as_pdf_rounded,
                text: 'v565_pay_receipts_hint'.tr,
                accent: accent,
              ),
              SizedBox(height: 12.h),
              if (billingMissing) ...[
                // Au retour : recharger pour reprendre les blocs à jour.
                BillingMissingBanner(accent: accent, onReturn: _load),
                SizedBox(height: 12.h),
              ],
              ProfileGroupCard(
                children: [
                  for (final inv in _invoices)
                    _InvoiceRow(
                      invoice: inv,
                      accent: accent,
                      onTap: () => _openInvoice(inv),
                    ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// Rangée d'une facture : numéro + pastille payée / remboursée, date ·
/// prestataire, montant, chevron.
class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
    required this.invoice,
    required this.accent,
    required this.onTap,
  });

  final InvoiceModel invoice;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRefunded = invoice.status == 'refunded';
    final statusColor =
        isRefunded ? const Color(0xFF2563EB) : const Color(0xFF16A34A);
    final dateLabel = invoice.issuedAt != null
        ? DateFormat.yMMMd(Get.locale?.languageCode).format(invoice.issuedAt!)
        : '';
    final who = invoice.providerName.isNotEmpty
        ? invoice.providerName
        : invoice.ownerName;
    final subtitle = [
      if (dateLabel.isNotEmpty) dateLabel,
      if (who.isNotEmpty) who,
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        child: Row(
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11.r),
              ),
              child: Icon(Icons.receipt_long_rounded, size: 18.sp, color: accent),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: PoppinsText(
                          text: invoice.invoiceNumber,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 7.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: InterText(
                          text: (isRefunded
                                  ? 'invoice_status_refunded'
                                  : 'invoice_status_paid')
                              .tr,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    InterText(
                      text: subtitle,
                      fontSize: 11.sp,
                      color: AppColors.textSecondary(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 8.w),
            PoppinsText(
              text: CurrencyHelper.format(invoice.currency, invoice.grossAmount),
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: isRefunded ? statusColor : accent,
            ),
            SizedBox(width: 4.w),
            Icon(Icons.chevron_right_rounded,
                size: 20.sp, color: AppColors.textSecondary(context)),
          ],
        ),
      ),
    );
  }
}
