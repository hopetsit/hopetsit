import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:get/get.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:intl/intl.dart';

/// Session v18.2 — "Mes paiements" screen in the owner profile.
///
/// Two sections:
///   1. Cartes enregistrées — list of PaymentMethods attached to the
///      owner's Stripe Customer. Tap Supprimer to detach. Tap "Ajouter
///      une carte" to run Stripe PaymentSheet in setup-only mode.
///   2. Historique — list of paid bookings (provider name, amount, date).
///
/// Backend endpoints: /owner/payments/methods, /owner/payments/setup-intent,
/// /owner/payments/methods/:id (DELETE), /owner/payments/history.
class OwnerPaymentsScreen extends StatefulWidget {
  const OwnerPaymentsScreen({super.key});

  @override
  State<OwnerPaymentsScreen> createState() => _OwnerPaymentsScreenState();
}

class _OwnerPaymentsScreenState extends State<OwnerPaymentsScreen> {
  late final OwnerRepository _repo = Get.find<OwnerRepository>();

  bool _loading = true;
  List<Map<String, dynamic>> _methods = const [];
  List<Map<String, dynamic>> _history = const [];
  bool _addingCard = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repo.getOwnerPaymentMethods(),
        _repo.getOwnerPaymentHistory(),
      ]);
      if (!mounted) return;
      setState(() {
        _methods = results[0];
        _history = results[1];
        _loading = false;
      });
    } catch (e) {
      AppLogger.logError('Load owner payments failed', error: e);
      if (!mounted) return;
      setState(() => _loading = false);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.toString(),
      );
    }
  }

  Future<void> _addCard() async {
    if (_addingCard) return;
    setState(() => _addingCard = true);
    try {
      final setup = await _repo.createOwnerSetupIntent();
      final clientSecret = setup['clientSecret']?.toString();
      if (clientSecret == null || clientSecret.isEmpty) {
        throw 'Missing clientSecret from backend';
      }
      // Init Stripe PaymentSheet in setup-intent mode — user enters the
      // card but no charge is made. On success, Stripe attaches the
      // PaymentMethod to the Customer.
      await stripe.Stripe.instance.initPaymentSheet(
        paymentSheetParameters: stripe.SetupPaymentSheetParameters(
          setupIntentClientSecret: clientSecret,
          merchantDisplayName: 'HopeTSIT',
        ),
      );
      await stripe.Stripe.instance.presentPaymentSheet();

      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'card_added_success'.tr == 'card_added_success'
            ? 'Carte ajoutée'
            : 'card_added_success'.tr,
      );
      await _load();
    } on stripe.StripeException catch (e) {
      // User cancelled or Stripe refused — don't treat as hard error.
      final code = e.error.code.name;
      if (code != 'Canceled' && code != 'canceled') {
        AppLogger.logError('Stripe setup failed', error: e.error.localizedMessage);
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: e.error.localizedMessage ?? 'Stripe error',
        );
      }
    } catch (e) {
      AppLogger.logError('Add card failed', error: e);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _addingCard = false);
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> method) async {
    final id = method['id']?.toString();
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: InterText(
          text: 'payments_delete_card_title'.tr == 'payments_delete_card_title'
              ? 'Supprimer cette carte ?'
              : 'payments_delete_card_title'.tr,
          fontSize: 16.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.blackColor,
        ),
        content: InterText(
          text: _methodLabel(method),
          fontSize: 14.sp,
          color: AppColors.grey700Color,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common_cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: AppColors.whiteColor,
            ),
            child: Text('common_yes'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.deleteOwnerPaymentMethod(id);
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'card_deleted_success'.tr == 'card_deleted_success'
            ? 'Carte supprimée'
            : 'card_deleted_success'.tr,
      );
      await _load();
    } catch (e) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.toString(),
      );
    }
  }

  String _methodLabel(Map<String, dynamic> m) {
    final brand = (m['brand']?.toString() ?? 'card').toUpperCase();
    final last4 = m['last4']?.toString() ?? '••••';
    final month = m['expMonth']?.toString().padLeft(2, '0') ?? '--';
    final year = m['expYear']?.toString() ?? '----';
    return '$brand •••• $last4  ·  $month/$year';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        title: PoppinsText(
          text: 'owner_payments_title'.tr == 'owner_payments_title'
              ? 'Mes paiements'
              : 'owner_payments_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.primaryColor))
          : RefreshIndicator(
              color: AppColors.primaryColor,
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
                children: [
                  _sectionTitle('owner_payments_cards_title'.tr ==
                          'owner_payments_cards_title'
                      ? 'Cartes enregistrées'
                      : 'owner_payments_cards_title'.tr),
                  SizedBox(height: 8.h),
                  if (_methods.isEmpty)
                    _emptyCardsCard()
                  else
                    ..._methods.map(_buildCardTile),
                  SizedBox(height: 10.h),
                  _addCardButton(),
                  SizedBox(height: 24.h),
                  _sectionTitle('owner_payments_history_title'.tr ==
                          'owner_payments_history_title'
                      ? 'Historique'
                      : 'owner_payments_history_title'.tr),
                  SizedBox(height: 8.h),
                  if (_history.isEmpty)
                    _emptyHistoryCard()
                  else
                    ..._history.map(_buildHistoryTile),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String label) => Padding(
        padding: EdgeInsets.only(left: 4.w, bottom: 4.h),
        child: PoppinsText(
          text: label,
          fontSize: 14.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary(context),
        ),
      );

  Widget _buildCardTile(Map<String, dynamic> m) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 6.w, 12.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.grey300Color),
      ),
      child: Row(
        children: [
          Container(
            width: 42.w,
            height: 28.h,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6.r),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.credit_card_rounded,
                size: 18.sp, color: AppColors.primaryColor),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: InterText(
              text: _methodLabel(m),
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.blackColor,
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                color: const Color(0xFFEF4444), size: 22.sp),
            onPressed: () => _confirmDelete(m),
          ),
        ],
      ),
    );
  }

  Widget _emptyCardsCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.grey300Color),
      ),
      child: InterText(
        text: 'owner_payments_empty_cards'.tr ==
                'owner_payments_empty_cards'
            ? "Aucune carte enregistrée. Ajoute-en une pour payer plus vite."
            : 'owner_payments_empty_cards'.tr,
        fontSize: 13.sp,
        color: AppColors.grey700Color,
      ),
    );
  }

  Widget _addCardButton() {
    return SizedBox(
      height: 48.h,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _addingCard ? null : _addCard,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          foregroundColor: AppColors.whiteColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
        icon: _addingCard
            ? SizedBox(
                width: 18.w,
                height: 18.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.whiteColor),
                ),
              )
            : Icon(Icons.add_rounded, size: 22.sp),
        label: InterText(
          text: 'owner_payments_add_card'.tr ==
                  'owner_payments_add_card'
              ? 'Ajouter une carte'
              : 'owner_payments_add_card'.tr,
          fontSize: 15.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.whiteColor,
        ),
      ),
    );
  }

  Widget _emptyHistoryCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.grey300Color),
      ),
      child: InterText(
        text: 'owner_payments_empty_history'.tr ==
                'owner_payments_empty_history'
            ? 'Aucun paiement pour le moment.'
            : 'owner_payments_empty_history'.tr,
        fontSize: 13.sp,
        color: AppColors.grey700Color,
      ),
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> h) {
    final providerRole = (h['providerRole']?.toString() ?? '').toLowerCase();
    final Color accent = providerRole == 'walker'
        ? const Color(0xFF16A34A)
        : providerRole == 'sitter'
            ? const Color(0xFF2563EB)
            : AppColors.primaryColor;

    String formatDate(String? iso) {
      if (iso == null || iso.isEmpty) return '';
      final dt = DateTime.tryParse(iso)?.toLocal();
      if (dt == null) return iso;
      return DateFormat.yMMMd().add_Hm().format(dt);
    }

    final amount = (h['amount'] is num) ? (h['amount'] as num).toDouble() : 0.0;
    final currency = h['currency']?.toString() ?? 'EUR';
    final name = h['providerName']?.toString() ?? '';
    final service = h['serviceType']?.toString() ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InterText(
                  text: name.isNotEmpty ? name : 'provider_unknown'.tr,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blackColor,
                ),
                if (service.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  InterText(
                    text: service,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.grey700Color,
                  ),
                ],
                SizedBox(height: 4.h),
                InterText(
                  text: formatDate(h['paidAt']?.toString()),
                  fontSize: 11.sp,
                  color: AppColors.greyText,
                ),
              ],
            ),
          ),
          PoppinsText(
            text: CurrencyHelper.format(currency, amount),
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ],
      ),
    );
  }
}
