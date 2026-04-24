import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:intl/intl.dart';

/// Mon portefeuille — v19.0.
///
/// Écran Vinted-style pour sitter+walker :
///   1. Carte solde en haut (gradient couleur rôle)
///   2. Boutons "Retirer" (IBAN/PayPal) et "Dépenser" (ouvre le shop)
///   3. Liste paginée des transactions (crédit booking, débit retrait,
///      débit shop, remboursement, ajustement admin)
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final ApiClient _api =
      Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : ApiClient();

  bool _loading = true;
  double _balance = 0;
  String _currency = 'EUR';
  int _pendingWithdrawals = 0;
  double _pendingAmount = 0;
  double _minWithdrawal = 5.0;
  List<dynamic> _transactions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final w = await _api.get('/wallet', requiresAuth: true);
      if (w is Map) {
        _balance = (w['balance'] as num?)?.toDouble() ?? 0;
        _currency = (w['currency'] as String?) ?? 'EUR';
        _pendingWithdrawals = (w['pendingWithdrawals'] as num?)?.toInt() ?? 0;
        _pendingAmount = (w['pendingAmount'] as num?)?.toDouble() ?? 0;
        _minWithdrawal = (w['minWithdrawal'] as num?)?.toDouble() ?? 5.0;
      }
      final t = await _api.get('/wallet/transactions?limit=30',
          requiresAuth: true);
      if (t is Map && t['transactions'] is List) {
        _transactions = t['transactions'] as List;
      }
    } catch (e) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color get _roleColor => AppColors.roleAccent(
        Get.find<AuthController>().userRole.value,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.scaffold(context),
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary(context)),
        title: PoppinsText(
          text: 'wallet_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.all(16.w),
                children: [
                  _balanceCard(),
                  SizedBox(height: 14.h),
                  _actionsRow(),
                  if (_pendingWithdrawals > 0) ...[
                    SizedBox(height: 10.h),
                    _pendingBanner(),
                  ],
                  SizedBox(height: 22.h),
                  _sectionTitle('wallet_history_title'.tr),
                  SizedBox(height: 8.h),
                  if (_transactions.isEmpty)
                    _emptyState()
                  else
                    ..._transactions.map((tx) =>
                        _TransactionTile(tx: tx as Map<String, dynamic>)),
                ],
              ),
            ),
    );
  }

  Widget _balanceCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 22.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _roleColor,
            _roleColor.withValues(alpha: 0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: _roleColor.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white, size: 22.sp),
              SizedBox(width: 8.w),
              InterText(
                text: 'wallet_available_balance'.tr,
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          PoppinsText(
            text: CurrencyHelper.format(_currency, _balance),
            fontSize: 36.sp,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
          SizedBox(height: 4.h),
          InterText(
            text: 'wallet_earn_more_hint'.tr,
            fontSize: 11.sp,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ],
      ),
    );
  }

  Widget _actionsRow() {
    return Row(
      children: [
        Expanded(
          child: _actionBtn(
            icon: Icons.call_made_rounded,
            label: 'wallet_withdraw_button'.tr,
            primary: true,
            // v19.1.5 — quand le solde est insuffisant, on affiche un snackbar
            // explicite au lieu de simplement griser le bouton (utilisateur
            // ne comprenait pas pourquoi rien ne se passait).
            onTap: _balance >= _minWithdrawal
                ? _openWithdrawSheet
                : () {
                    CustomSnackbar.showWarning(
                      title: 'wallet_withdraw_button'.tr,
                      message: 'wallet_withdraw_min_required'.trParams({
                        'amount': _minWithdrawal.toStringAsFixed(2),
                      }),
                    );
                  },
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _actionBtn(
            icon: Icons.storefront_rounded,
            label: 'wallet_spend_button'.tr,
            primary: false,
            // v19.1.5 — Ouvre le shop direct (onglet Boost). L'user choisit
            // ensuite Boost/Premium/MapBoost et peut payer avec son solde
            // wallet (endpoint /boost/purchase/wallet).
            onTap: () => Get.to(() => const CoinShopScreen()),
          ),
        ),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required bool primary,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        height: 50.h,
        decoration: BoxDecoration(
          color: primary ? _roleColor : AppColors.card(context),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: primary ? _roleColor : AppColors.divider(context),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18.sp,
                color: primary ? Colors.white : _roleColor),
            SizedBox(width: 8.w),
            InterText(
              text: label,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: primary ? Colors.white : AppColors.textPrimary(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pendingBanner() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_top_rounded,
              size: 18.sp, color: const Color(0xFFC2410C)),
          SizedBox(width: 8.w),
          Expanded(
            child: InterText(
              text: 'wallet_pending_withdrawals'.trParams({
                'count': _pendingWithdrawals.toString(),
                'amount': CurrencyHelper.format(_currency, _pendingAmount),
              }),
              fontSize: 12.sp,
              color: const Color(0xFF9A3412),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => PoppinsText(
        text: text,
        fontSize: 15.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary(context),
      );

  Widget _emptyState() {
    return Container(
      padding: EdgeInsets.all(24.w),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 48.sp, color: AppColors.greyColor),
          SizedBox(height: 10.h),
          InterText(
            text: 'wallet_history_empty'.tr,
            fontSize: 13.sp,
            color: AppColors.textSecondary(context),
          ),
        ],
      ),
    );
  }

  void _openWithdrawSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => _WithdrawSheet(
        balance: _balance,
        currency: _currency,
        minWithdrawal: _minWithdrawal,
        roleColor: _roleColor,
        onSuccess: () {
          Get.back();
          _load();
        },
      ),
    );
  }
}

/// Bottom sheet : saisie du montant + choix IBAN/PayPal.
class _WithdrawSheet extends StatefulWidget {
  const _WithdrawSheet({
    required this.balance,
    required this.currency,
    required this.minWithdrawal,
    required this.roleColor,
    required this.onSuccess,
  });

  final double balance;
  final String currency;
  final double minWithdrawal;
  final Color roleColor;
  final VoidCallback onSuccess;

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  final TextEditingController _amountCtrl = TextEditingController();
  String _method = 'iban';
  bool _processing = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (amount == null || amount < widget.minWithdrawal) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'wallet_amount_min'
            .trParams({'min': widget.minWithdrawal.toStringAsFixed(2)}),
      );
      return;
    }
    if (amount > widget.balance) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'wallet_amount_exceeds'.tr,
      );
      return;
    }

    setState(() => _processing = true);
    try {
      final api = Get.find<ApiClient>();
      await api.post('/wallet/withdraw',
          requiresAuth: true,
          body: {'amount': amount, 'method': _method});
      if (!mounted) return;
      CustomSnackbar.showSuccess(
        title: 'wallet_withdraw_success_title'.tr,
        message: _method == 'iban'
            ? 'wallet_withdraw_success_iban'.tr
            : 'wallet_withdraw_success_paypal'.tr,
      );
      widget.onSuccess();
    } catch (e) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 20.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.w,
            height: 4.h,
            margin: EdgeInsets.only(bottom: 16.h),
            decoration: BoxDecoration(
              color: AppColors.divider(context),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          PoppinsText(
            text: 'wallet_withdraw_title'.tr,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
          SizedBox(height: 4.h),
          InterText(
            text: 'wallet_withdraw_subtitle'.trParams({
              'balance':
                  CurrencyHelper.format(widget.currency, widget.balance),
            }),
            fontSize: 12.sp,
            color: AppColors.textSecondary(context),
          ),
          SizedBox(height: 18.h),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'wallet_amount_label'.tr,
              hintText: widget.minWithdrawal.toStringAsFixed(2),
              prefixIcon: Icon(Icons.euro, color: widget.roleColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
            ),
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 16.h),
          _methodTile('iban', Icons.account_balance,
              'wallet_method_iban'.tr, 'wallet_method_iban_desc'.tr),
          SizedBox(height: 8.h),
          _methodTile('paypal', Icons.mail_outline,
              'wallet_method_paypal'.tr, 'wallet_method_paypal_desc'.tr),
          SizedBox(height: 24.h),
          SizedBox(
            width: double.infinity,
            height: 50.h,
            child: ElevatedButton(
              onPressed: _processing ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.roleColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              child: _processing
                  ? const CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)
                  : InterText(
                      text: 'wallet_confirm_withdrawal'.tr,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodTile(String value, IconData icon, String title, String desc) {
    final selected = _method == value;
    return GestureDetector(
      onTap: () => setState(() => _method = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: selected
              ? widget.roleColor.withValues(alpha: 0.06)
              : AppColors.card(context),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: selected ? widget.roleColor : AppColors.divider(context),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20.sp, color: widget.roleColor),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PoppinsText(
                    text: title,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                  InterText(
                    text: desc,
                    fontSize: 11.sp,
                    color: AppColors.textSecondary(context),
                  ),
                ],
              ),
            ),
            Container(
              width: 20.w,
              height: 20.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? widget.roleColor
                      : AppColors.divider(context),
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: selected
                  ? Container(
                      width: 10.w,
                      height: 10.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.roleColor,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Row d'une transaction dans l'historique.
class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx});

  final Map<String, dynamic> tx;

  @override
  Widget build(BuildContext context) {
    final type = tx['type'] as String? ?? '';
    final status = tx['status'] as String? ?? '';
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
    final currency = tx['currency'] as String? ?? 'EUR';
    final createdAt = tx['createdAt'] as String?;
    final date = createdAt != null
        ? DateFormat('dd MMM yyyy', Get.locale?.languageCode ?? 'fr')
            .format(DateTime.tryParse(createdAt) ?? DateTime.now())
        : '-';

    final isCredit = type == 'credit_booking' || type == 'refund' ||
        (type == 'admin_adjustment' && amount > 0);
    final sign = isCredit ? '+' : '-';
    final color = isCredit
        ? const Color(0xFF059669)
        : (status == 'pending'
            ? const Color(0xFFF59E0B)
            : const Color(0xFFDC2626));

    final icon = {
      'credit_booking': Icons.call_received_rounded,
      'debit_withdrawal': Icons.call_made_rounded,
      'debit_shop': Icons.shopping_bag_outlined,
      'refund': Icons.replay_rounded,
      'admin_adjustment': Icons.admin_panel_settings_outlined,
    }[type] ?? Icons.swap_horiz_rounded;

    final label = 'wallet_type_$type'.tr;
    final subtitle = type == 'debit_withdrawal'
        ? 'wallet_to_${tx['withdrawalMethod'] ?? 'iban'}'.tr
        : (type == 'debit_shop'
            ? (tx['productType'] as String? ?? '')
            : (tx['serviceType'] as String? ?? ''));

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.divider(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10.r),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18.sp, color: color),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InterText(
                  text: label,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
                if (subtitle.isNotEmpty)
                  InterText(
                    text: subtitle,
                    fontSize: 11.sp,
                    color: AppColors.textSecondary(context),
                  ),
                SizedBox(height: 2.h),
                InterText(
                  text: date,
                  fontSize: 10.sp,
                  color: AppColors.greyColor,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PoppinsText(
                text: '$sign${CurrencyHelper.format(currency, amount)}',
                fontSize: 14.sp,
                fontWeight: FontWeight.w800,
                color: color,
              ),
              if (status == 'pending')
                InterText(
                  text: 'wallet_status_pending'.tr,
                  fontSize: 10.sp,
                  color: const Color(0xFFF59E0B),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
