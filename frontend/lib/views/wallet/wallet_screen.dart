import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_endpoints.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/service_type_translator.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/views/booking/widgets/booking_ui_kit.dart';
import 'package:hopetsit/views/pet_owner/payments/saved_cards_screen.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/views/pet_sitter/profile/iban_setup_screen.dart';
import 'package:hopetsit/views/pet_sitter/payment/payment_management_screen.dart';
import 'package:intl/intl.dart';
import 'package:hopetsit/utils/bottom_inset.dart';

/// Mon portefeuille — v19.0.
///
/// Écran Vinted-style pour sitter+walker :
///   1. Carte solde en haut (gradient couleur rôle)
///   2. Boutons "Retirer" (IBAN/PayPal) et "Dépenser" (ouvre le shop)
///   3. Liste paginée des transactions (crédit booking, débit retrait,
///      débit shop, remboursement, ajustement admin)
///
/// v565 (point 28) — modernisation : kit Profil, états chargement / erreur
/// (« Réessayer »), minimum de retrait affiché, bouton « Tout » dans la
/// feuille de retrait, historique en carte groupée.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, this.accent});

  /// v565 (lot app-calendar-wallet) — couleur du rôle imposée par l'écran
  /// appelant (profil sitter = bleu gardien, walker = vert promeneur). Si null,
  /// déduite du rôle courant de l'AuthController (comportement historique).
  final Color? accent;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final ApiClient _api =
      Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : ApiClient();

  bool _loading = true;
  // v565 — état d'erreur explicite avec « Réessayer » (avant : snackbar et
  // solde à 0 affiché comme si tout allait bien).
  String? _error;
  double _balance = 0;
  String _currency = 'EUR';
  int _pendingWithdrawals = 0;
  double _pendingAmount = 0;
  // v23.1.349 — Daniel : "mettre un message AVEC LE MONTANT bloqué : sera
  // débloqué une fois le service fini et confirmé". Somme des gains en
  // séquestre (réservations payées pas encore confirmées), calculée backend.
  double _pendingEscrowTotal = 0;
  double _minWithdrawal = 5.0;
  List<dynamic> _transactions = [];
  // v565 (lot app-calendar-wallet) — statut IBAN lu en même temps que le solde :
  // null = inconnu (erreur réseau, on n'affiche rien), false = pas d'IBAN →
  // bannière « IBAN manquant » avec accès direct à la configuration, au lieu
  // de le découvrir seulement au moment du retrait.
  bool? _ibanConfigured;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final w = await _api.get('/wallet', requiresAuth: true);
      if (w is Map) {
        _balance = (w['balance'] as num?)?.toDouble() ?? 0;
        _currency = (w['currency'] as String?) ?? 'EUR';
        _pendingWithdrawals = (w['pendingWithdrawals'] as num?)?.toInt() ?? 0;
        _pendingAmount = (w['pendingAmount'] as num?)?.toDouble() ?? 0;
        _pendingEscrowTotal =
            (w['pendingEscrowTotal'] as num?)?.toDouble() ?? 0;
        _minWithdrawal = (w['minWithdrawal'] as num?)?.toDouble() ?? 5.0;
      }
      final t = await _api.get('/wallet/transactions?limit=30',
          requiresAuth: true);
      if (t is Map && t['transactions'] is List) {
        _transactions = t['transactions'] as List;
      }
      await _loadIbanStatus();
    } catch (e) {
      _error = paymentErrorMessage(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Lecture tolérante du statut IBAN (`/sitter/iban` sert aussi le walker).
  /// Ne fait jamais échouer le chargement du portefeuille.
  Future<void> _loadIbanStatus() async {
    try {
      final r = await _api.get(ApiEndpoints.sitterMeIban, requiresAuth: true);
      if (r is Map) {
        _ibanConfigured =
            (r['ibanNumberMasked'] ?? '').toString().isNotEmpty;
      }
    } catch (_) {
      _ibanConfigured = null;
    }
  }

  Color get _roleColor =>
      widget.accent ??
      AppColors.roleAccent(
        Get.find<AuthController>().userRole.value,
      );

  @override
  Widget build(BuildContext context) {
    final accent = _roleColor;
    return ProfileSubPageScaffold(
      title: 'wallet_title'.tr,
      accent: accent,
      scroll: false,
      padding: EdgeInsets.zero,
      body: RefreshIndicator(
        color: accent,
        onRefresh: _load,
        child: _loading
            ? BookingLoadingList(accent: accent)
            : _error != null
                ? BookingErrorState(message: _error!, onRetry: _load)
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    // v569 — dernière carte au-dessus de la barre système.
                    padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w,
                        32.h + appBottomInsetInsideSafeArea(context)),
                    children: [
                      _balanceCard(),
                      SizedBox(height: 12.h),
                      _actionsRow(),
                      SizedBox(height: 12.h),
                      // v23.1.330 — Daniel : message clair pour sitter/walker —
                      // l'argent d'une prestation est BLOQUÉ jusqu'à ce que le
                      // propriétaire confirme la fin du service.
                      _heldFundsBanner(),
                      if (_ibanConfigured == false) ...[
                        SizedBox(height: 10.h),
                        _ibanMissingBanner(),
                      ],
                      if (_pendingWithdrawals > 0) ...[
                        SizedBox(height: 10.h),
                        _pendingBanner(),
                      ],
                      ProfileSectionTitle('wallet_history_title'.tr,
                          icon: Icons.history_rounded),
                      if (_transactions.isEmpty)
                        _emptyState()
                      else
                        ProfileGroupCard(
                          children: _transactions
                              .map((tx) =>
                                  _TransactionTile(tx: tx as Map<String, dynamic>))
                              .toList(),
                        ),
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
        borderRadius: BorderRadius.circular(22.r),
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
          SizedBox(height: 6.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 6.h,
            children: [
              _whitePill('v565_pay_wallet_min_hint'.trParams({
                'amount': CurrencyHelper.format(_currency, _minWithdrawal),
              })),
            ],
          ),
          SizedBox(height: 8.h),
          InterText(
            text: 'wallet_earn_more_hint'.tr,
            fontSize: 11.sp,
            color: Colors.white.withValues(alpha: 0.85),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _whitePill(String text) => Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(999),
        ),
        child: InterText(
          text: text,
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );

  Widget _heldFundsBanner() {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: _roleColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_clock_rounded, color: _roleColor, size: 20.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // v23.1.349 — Daniel : afficher LE MONTANT bloqué
                // ("sera débloqué une fois le service fini et
                // confirmé"). Ligne mise en avant quand > 0.
                if (_pendingEscrowTotal > 0) ...[
                  InterText(
                    text: 'wallet_held_funds_amount'.trParams({
                      'amount': CurrencyHelper.format(
                          _currency, _pendingEscrowTotal),
                    }),
                    fontSize: 13.sp,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: _roleColor,
                    maxLines: 3,
                  ),
                  SizedBox(height: 4.h),
                ],
                InterText(
                  text: 'wallet_held_funds_info'.tr,
                  fontSize: 12.sp,
                  height: 1.4,
                  color: AppColors.textSecondary(context),
                  maxLines: 6,
                ),
              ],
            ),
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
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        height: 52.h,
        decoration: BoxDecoration(
          color: primary ? _roleColor : _roleColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18.sp,
                color: primary ? Colors.white : _roleColor),
            SizedBox(width: 8.w),
            Flexible(
              child: PoppinsText(
                text: label,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: primary ? Colors.white : _roleColor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// v565 — bannière « IBAN manquant » : titre, explication, bouton vers
  /// l'écran IBAN ; le portefeuille se recharge au retour.
  Widget _ibanMissingBanner() {
    const amber = Color(0xFFE8920A);
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: amber.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_rounded, size: 20.sp, color: amber),
              SizedBox(width: 10.w),
              Expanded(
                child: PoppinsText(
                  text: 'wallet_iban_missing_title'.tr,
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          InterText(
            text: 'wallet_iban_missing_body'.tr,
            fontSize: 12.sp,
            height: 1.4,
            color: AppColors.textSecondary(context),
            maxLines: 3,
          ),
          SizedBox(height: 10.h),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () {
                Get.to(() => const IbanSetupScreen())?.then((_) => _load());
              },
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: _roleColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_card_rounded, size: 15.sp, color: Colors.white),
                    SizedBox(width: 6.w),
                    InterText(
                      text: 'quick_wallet_iban'.tr,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingBanner() {
    const amber = Color(0xFFC2410C);
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_top_rounded, size: 20.sp, color: amber),
          SizedBox(width: 10.w),
          Expanded(
            child: InterText(
              text: 'wallet_pending_withdrawals'.trParams({
                'count': _pendingWithdrawals.toString(),
                'amount': CurrencyHelper.format(_currency, _pendingAmount),
              }),
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return ProfileGroupCard(
      children: [
        ProfileEmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'wallet_history_empty'.tr,
          message: 'v565_pay_wallet_history_hint'.tr,
          accent: _roleColor,
        ),
      ],
    );
  }

  void _openWithdrawSheet() {
    showProfileSheet<void>(
      context,
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
      // v20.0.19 — before this fix, errors were rendered as the raw
      // "ApiException(statusCode: 400, message: ...)" which looked broken.
      // Now we detect the structured error codes PAYPAL_NOT_CONFIGURED
      // and IBAN_NOT_CONFIGURED returned by the backend and show a clear
      // dialog with a "Configurer maintenant" CTA that deep-links the
      // provider to the right config screen.
      if (!mounted) return;
      final code = _extractErrorCode(e);
      if (code == 'PAYPAL_NOT_CONFIGURED') {
        _showConfigNeededDialog(
          title: 'wallet_paypal_needed_title'.tr,
          message: 'wallet_paypal_needed_message'.tr,
          ctaLabel: 'wallet_configure_paypal'.tr,
          onConfigure: () {
            Navigator.of(context).pop();
            Get.to(() => const PaymentManagementScreen());
          },
        );
      } else if (code == 'IBAN_NOT_CONFIGURED') {
        _showConfigNeededDialog(
          title: 'wallet_iban_needed_title'.tr,
          message: 'wallet_iban_needed_message'.tr,
          ctaLabel: 'wallet_configure_iban'.tr,
          onConfigure: () {
            Navigator.of(context).pop();
            Get.to(() => const IbanSetupScreen());
          },
        );
      } else {
        // Fallback generic message — no more raw ApiException toString.
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: e is ApiException && e.message.isNotEmpty
              ? e.message
              : 'wallet_withdraw_error_generic'.tr,
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  /// v20.0.19 — extract the backend error code from an ApiException.
  /// Backend returns `{ error, code }` in the details map on 4xx.
  String? _extractErrorCode(Object e) {
    if (e is! ApiException) return null;
    final d = e.details;
    if (d is Map) {
      final code = d['code']?.toString();
      if (code != null && code.isNotEmpty) return code;
    }
    return null;
  }

  /// v20.0.19 — « Configuration requise » avec bouton d'action direct.
  /// v565 — feuille Apple (kit Profil) au lieu d'un AlertDialog.
  Future<void> _showConfigNeededDialog({
    required String title,
    required String message,
    required String ctaLabel,
    required VoidCallback onConfigure,
  }) async {
    final ok = await showPaymentConfirmSheet(
      context,
      title: title,
      message: message,
      confirmLabel: ctaLabel,
      accent: widget.roleColor,
      icon: Icons.settings_rounded,
    );
    if (ok && mounted) onConfigure();
  }

  @override
  Widget build(BuildContext context) {
    // v23.1.316 — Daniel : "le menu du téléphone gêne + empêche de scroll". On
    // rend la feuille scrollable ; showProfileSheet gère déjà le clavier
    // (viewInsets) et la barre système (SafeArea).
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ProfileSheetHandle(),
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
              fontSize: 12.5.sp,
              color: AppColors.textSecondary(context),
              maxLines: 3,
            ),
            SizedBox(height: 18.h),
            // v23.1.314 — Daniel : "en dark mode l'écriture est blanche, on voit
            // rien". ProfileInput est thème-aware (texte, label, hint, fond).
            ProfileInput(
              label: 'wallet_amount_label'.tr,
              controller: _amountCtrl,
              accent: widget.roleColor,
              hint: widget.minWithdrawal.toStringAsFixed(2),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              prefix: Icon(Icons.payments_rounded, color: widget.roleColor),
              suffix: Padding(
                padding: EdgeInsets.only(right: 6.w),
                child: TextButton(
                  onPressed: () => setState(() {
                    _amountCtrl.text = widget.balance.toStringAsFixed(2);
                  }),
                  style: TextButton.styleFrom(
                    foregroundColor: widget.roleColor,
                    minimumSize: Size(0, 32.h),
                    padding: EdgeInsets.symmetric(horizontal: 10.w),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: InterText(
                    text: 'v565_pay_wallet_all'.tr,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: widget.roleColor,
                  ),
                ),
              ),
            ),
            SizedBox(height: 6.h),
            InterText(
              text: 'v565_pay_wallet_min_hint'.trParams({
                'amount':
                    CurrencyHelper.format(widget.currency, widget.minWithdrawal),
              }),
              fontSize: 11.5.sp,
              color: AppColors.textSecondary(context),
            ),
            SizedBox(height: 16.h),
            _methodTile('iban', Icons.account_balance_rounded,
                'wallet_method_iban'.tr, 'wallet_method_iban_desc'.tr),
            SizedBox(height: 8.h),
            _methodTile('paypal', Icons.mail_outline_rounded,
                'wallet_method_paypal'.tr, 'wallet_method_paypal_desc'.tr),
            SizedBox(height: 22.h),
            ProfilePrimaryButton(
              label: 'wallet_confirm_withdrawal'.tr,
              accent: widget.roleColor,
              loading: _processing,
              icon: Icons.call_made_rounded,
              onTap: _processing ? null : _submit,
            ),
          ],
        ),
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
              ? widget.roleColor.withValues(alpha: 0.08)
              : AppColors.card(context),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: selected ? widget.roleColor : AppColors.divider(context),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: widget.roleColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11.r),
              ),
              child: Icon(icon, size: 18.sp, color: widget.roleColor),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PoppinsText(
                    text: title,
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                  InterText(
                    text: desc,
                    fontSize: 11.sp,
                    color: AppColors.textSecondary(context),
                    maxLines: 2,
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

/// Row d'une transaction dans l'historique (rangée d'un [ProfileGroupCard]).
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
            : translateServiceType(tx['serviceType'] as String?));

    return ProfileRow(
      icon: icon,
      color: color,
      title: label,
      subtitle: subtitle.isNotEmpty ? '$subtitle · $date' : date,
      showChevron: false,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
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
              fontWeight: FontWeight.w600,
              color: const Color(0xFFF59E0B),
            ),
        ],
      ),
    );
  }
}
