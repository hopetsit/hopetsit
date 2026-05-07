import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/invoice_model.dart';
import 'package:hopetsit/repositories/invoice_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/views/invoices/invoice_viewer_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// v23.1 — Mes factures (auto-générées au paiement de chaque réservation).
/// Accessible depuis l'onglet "Factures" de Mes Réservations sur les 3
/// profils owner / sitter / walker.
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

  @override
  void initState() {
    super.initState();
    _repo = Get.isRegistered<InvoiceRepository>()
        ? Get.find<InvoiceRepository>()
        : InvoiceRepository(Get.find<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    _isLoading.value = true;
    _errorMessage.value = null;
    try {
      final list = await _repo.getMyInvoices();
      _invoices.assignAll(list);
    } on ApiException catch (e) {
      _errorMessage.value = e.message;
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
    final url = _repo.htmlUrlFor(inv.id);
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
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        title: PoppinsText(
          text: 'invoices_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: Obx(() {
            if (_isLoading.value && _invoices.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_errorMessage.value != null) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(20.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          color: const Color(0xFFE53935), size: 48.sp),
                      SizedBox(height: 12.h),
                      InterText(
                        text: _errorMessage.value!,
                        fontSize: 14.sp,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 16.h),
                      ElevatedButton(
                        onPressed: _load,
                        child: Text('common_retry'.tr),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (_invoices.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: 80.h),
                  Icon(Icons.receipt_long_outlined,
                      size: 56.sp, color: Colors.grey),
                  SizedBox(height: 16.h),
                  Center(
                    child: PoppinsText(
                      text: 'invoices_empty_title'.tr,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: InterText(
                      text: 'invoices_empty_message'.tr,
                      fontSize: 13.sp,
                      color: Colors.grey,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: EdgeInsets.all(16.w),
              itemCount: _invoices.length,
              separatorBuilder: (_, __) => SizedBox(height: 10.h),
              itemBuilder: (_, i) {
                final inv = _invoices[i];
                return _InvoiceCard(
                  invoice: inv,
                  onTap: () => _openInvoice(inv),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice, required this.onTap});

  final InvoiceModel invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRefunded = invoice.status == 'refunded';
    final accent = isRefunded ? const Color(0xFFE53935) : AppColors.primaryColor;
    final symbol = CurrencyHelper.symbol(invoice.currency);
    final dateLabel = invoice.issuedAt != null
        ? '${invoice.issuedAt!.day.toString().padLeft(2, '0')}/'
            '${invoice.issuedAt!.month.toString().padLeft(2, '0')}/'
            '${invoice.issuedAt!.year}'
        : '';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: AppColors.cardShadow(context),
          border: Border.all(
            color: accent.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(Icons.receipt_long_rounded,
                  color: accent, size: 24.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: PoppinsText(
                          text: invoice.invoiceNumber,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: InterText(
                          text: (isRefunded
                                  ? 'invoice_status_refunded'
                                  : 'invoice_status_paid')
                              .tr,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  InterText(
                    text: dateLabel.isNotEmpty
                        ? '$dateLabel · ${invoice.providerName}'
                        : invoice.providerName,
                    fontSize: 12.sp,
                    color: Colors.grey,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PoppinsText(
                  text: '$symbol${invoice.grossAmount.toStringAsFixed(2)}',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
                SizedBox(height: 2.h),
                Icon(Icons.download_rounded,
                    size: 18.sp, color: AppColors.primaryColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
