import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/services/donation_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/service_type_translator.dart';
import 'package:hopetsit/views/booking/widgets/booking_ui_kit.dart';
import 'package:hopetsit/views/invoices/invoices_screen.dart';
import 'package:hopetsit/views/pet_owner/payments/saved_cards_screen.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
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
///
/// v565 (point 28) — modernisation : kit Profil, résumé des dépenses, bouton
/// « Ajouter une carte » réactivé (flux 0,50 € remboursé, partagé avec Mes
/// cartes), accès aux factures, états chargement / vide / erreur.
class OwnerPaymentsScreen extends StatefulWidget {
  const OwnerPaymentsScreen({super.key});

  @override
  State<OwnerPaymentsScreen> createState() => _OwnerPaymentsScreenState();
}

class _OwnerPaymentsScreenState extends State<OwnerPaymentsScreen> {
  late final OwnerRepository _repo = Get.find<OwnerRepository>();

  bool _loading = true;
  // v565 — état d'erreur explicite (avant : snackbar + écran vide).
  String? _error;
  bool _adding = false;
  List<Map<String, dynamic>> _methods = const [];
  List<Map<String, dynamic>> _history = const [];

  // v565 — l'écran est ouvert par les 3 rôles (Profil owner et « Gérer mes
  // paiements » sitter / walker) : couleur du rôle courant.
  Color get _accent => currentRoleAccent();

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
      setState(() {
        _loading = false;
        _error = paymentErrorMessage(e);
      });
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> method) async {
    final id = method['id']?.toString();
    if (id == null) return;
    final confirmed = await showPaymentConfirmSheet(
      context,
      title: 'payments_delete_card_title'.tr,
      message: _methodLabel(method),
      confirmLabel: 'common_delete'.tr,
      accent: _accent,
      icon: Icons.delete_outline_rounded,
      danger: true,
    );
    if (!confirmed) return;
    try {
      await _repo.deleteOwnerPaymentMethod(id);
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'card_deleted_success'.tr,
      );
      await _load();
    } catch (e) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: paymentErrorMessage(e),
      );
    }
  }

  // v565 — « Ajouter une carte » réactivé : même flux de vérification 0,50 €
  // (remboursé) que l'écran Mes cartes (helper partagé).
  Future<void> _addCard() async {
    if (_adding) return;
    setState(() => _adding = true);
    try {
      final added = await runAddCardVerificationFlow(
        context,
        repo: _repo,
        accent: _accent,
      );
      if (added) await _load();
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  /// v568 — carte par défaut (celle proposée au paiement, sur les 3 profils).
  Future<void> _setDefault(Map<String, dynamic> method) async {
    final id = method['id']?.toString();
    if (id == null || id.isEmpty) return;
    try {
      await _repo.setDefaultOwnerPaymentMethod(id);
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'cards568_set_default_done'.tr,
      );
      await _load();
    } catch (e) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: paymentErrorMessage(e),
      );
    }
  }

  String _methodLabel(Map<String, dynamic> m) {
    final brand = (m['brand']?.toString() ?? 'card').toUpperCase();
    final last4 = m['last4']?.toString() ?? '••••';
    final month = (m['expiryMonth'] ?? m['expMonth'])?.toString().padLeft(2, '0') ?? '--';
    final year = (m['expiryYear'] ?? m['expYear'])?.toString() ?? '----';
    return '$brand •••• $last4  ·  $month/$year';
  }

  double get _totalSpent => _history.fold<double>(
        0,
        (sum, h) => sum + ((h['amount'] is num) ? (h['amount'] as num).toDouble() : 0.0),
      );

  String get _historyCurrency =>
      _history.isNotEmpty ? (_history.first['currency']?.toString() ?? 'EUR') : 'EUR';

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return ProfileSubPageScaffold(
      title: 'owner_payments_title'.tr,
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
                    padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 32.h),
                    children: [
                      _summaryCard(accent),
                      ProfileSectionTitle('owner_payments_cards_title'.tr,
                          icon: Icons.credit_card_rounded),
                      if (_methods.isEmpty)
                        ProfileGroupCard(
                          children: [
                            ProfileRow(
                              icon: Icons.credit_card_off_rounded,
                              color: AppColors.greyText,
                              title: 'saved_cards_empty_title'.tr,
                              subtitle: 'owner_payments_empty_cards'.tr,
                              showChevron: false,
                            ),
                          ],
                        )
                      else
                        ProfileGroupCard(
                          children: [
                            // v568 — « par défaut » = le choix de
                            // l'utilisateur (renvoyé par le serveur), plus
                            // « la première de la liste ».
                            for (var i = 0; i < _methods.length; i++)
                              SavedCardRow(
                                card: _methods[i],
                                accent: accent,
                                isDefault: _methods[i]['isDefault'] == true ||
                                    (i == 0 &&
                                        !_methods.any(
                                            (c) => c['isDefault'] == true)),
                                onDelete: () => _confirmDelete(_methods[i]),
                                onSetDefault: () => _setDefault(_methods[i]),
                              ),
                          ],
                        ),
                      SizedBox(height: 8.h),
                      ProfileSecondaryButton(
                        label: _adding
                            ? 'saved_cards_verifying'.tr
                            : 'saved_cards_add_button'.tr,
                        accent: accent,
                        icon: Icons.add_card_rounded,
                        onTap: _adding ? null : _addCard,
                      ),
                      SizedBox(height: 10.h),
                      ProfileInfoBanner(
                        icon: Icons.verified_user_outlined,
                        text: _methods.isEmpty
                            ? 'v565_pay_cards_hint'.tr
                            : '${'v565_pay_default_hint'.tr}\n${'v565_pay_cards_hint'.tr}',
                        accent: accent,
                      ),
                      ProfileSectionTitle('v565_pay_receipts'.tr,
                          icon: Icons.receipt_long_rounded),
                      ProfileGroupCard(
                        children: [
                          ProfileRow(
                            icon: Icons.picture_as_pdf_rounded,
                            color: accent,
                            title: 'invoices_title'.tr,
                            subtitle: 'v565_pay_receipts_hint'.tr,
                            onTap: () => Get.to(() => const InvoicesScreen()),
                          ),
                        ],
                      ),
                      ProfileSectionTitle('owner_payments_history_title'.tr,
                          icon: Icons.history_rounded),
                      if (_history.isEmpty)
                        ProfileGroupCard(
                          children: [
                            ProfileRow(
                              icon: Icons.receipt_long_outlined,
                              color: AppColors.greyText,
                              title: 'owner_payments_empty_history'.tr,
                              subtitle: 'v565_pay_history_hint'.tr,
                              showChevron: false,
                            ),
                          ],
                        )
                      else
                        ProfileGroupCard(
                          children: _history.map(_buildHistoryRow).toList(),
                        ),
                      SizedBox(height: 22.h),
                      // v18.9 — widget Soutenir HoPetSit (précédemment sitter/walker
                      // uniquement).
                      _buildDonationCard(context),
                    ],
                  ),
      ),
    );
  }

  /// v565 — en-tête : total dépensé + nombre de paiements + nombre de cartes.
  Widget _summaryCard(Color accent) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent, accent.withValues(alpha: 0.78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white, size: 20.sp),
              SizedBox(width: 8.w),
              InterText(
                text: 'v565_pay_total_spent'.tr,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          PoppinsText(
            text: CurrencyHelper.format(_historyCurrency, _totalSpent),
            fontSize: 32.sp,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
          SizedBox(height: 6.h),
          // v565 — Wrap (pas Row) : deux libellés longs en DE / PT passent à
          // la ligne au lieu de déborder.
          Wrap(
            spacing: 8.w,
            runSpacing: 6.h,
            children: [
              _pill('v565_pay_payments_count'
                  .trParams({'count': _history.length.toString()})),
              _pill('${_methods.length} ${'owner_payments_cards_title'.tr}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String text) => Container(
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

  /// v18.9 — carte Soutenir HoPetSit. Dupliqué depuis payment_management_screen
  /// pour que les 3 profils aient le même widget. Les amounts 2/5/10/20 sont
  /// en placeholder tant que l'endpoint donation n'est pas branché.
  Widget _buildDonationCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        children: [
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.favorite_rounded,
                size: 28.sp, color: AppColors.primaryColor),
          ),
          SizedBox(height: 10.h),
          PoppinsText(
            text: 'payment_donate_title'.tr,
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4.h),
          InterText(
            text: 'payment_donate_desc'.tr,
            fontSize: 12.sp,
            color: AppColors.textSecondary(context),
            textAlign: TextAlign.center,
            maxLines: 4,
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              _donationChip(context, '2€'),
              SizedBox(width: 8.w),
              _donationChip(context, '5€'),
              SizedBox(width: 8.w),
              _donationChip(context, '10€'),
              SizedBox(width: 8.w),
              _donationChip(context, '20€'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _donationChip(BuildContext context, String amount) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          // v18.9.3 — don réel via Stripe.
          final parsed = double.tryParse(
                amount.replaceAll('€', '').replaceAll(',', '.').trim(),
              ) ??
              0;
          if (parsed <= 0) return;
          DonationService.donate(
            context: context,
            amount: parsed,
          );
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 11.h),
          decoration: BoxDecoration(
            color: AppColors.primaryColor,
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Center(
            child: InterText(
              text: amount,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryRow(Map<String, dynamic> h) {
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
      return DateFormat.yMMMd(Get.locale?.languageCode).add_Hm().format(dt);
    }

    final amount = (h['amount'] is num) ? (h['amount'] as num).toDouble() : 0.0;
    final currency = h['currency']?.toString() ?? 'EUR';
    final name = h['providerName']?.toString() ?? '';
    final service = h['serviceType']?.toString() ?? '';
    final date = formatDate(h['paidAt']?.toString());
    final subtitle = [
      if (service.isNotEmpty) translateServiceType(service),
      if (date.isNotEmpty) date,
    ].join(' · ');

    return ProfileRow(
      icon: providerRole == 'walker'
          ? Icons.directions_walk_rounded
          : Icons.pets_rounded,
      color: accent,
      title: name.isNotEmpty ? name : 'provider_unknown'.tr,
      subtitle: subtitle,
      showChevron: false,
      trailing: PoppinsText(
        text: CurrencyHelper.format(currency, amount),
        fontSize: 15.sp,
        fontWeight: FontWeight.w700,
        color: accent,
      ),
    );
  }
}
