import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/iban_status_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/views/pet_sitter/profile/iban_setup_screen.dart';
import 'package:hopetsit/views/pet_owner/payments/owner_payments_screen.dart';
import 'package:hopetsit/views/pet_sitter/payment/provider_payout_history_screen.dart';
import 'package:hopetsit/views/pet_sitter/payment/earnings_history_screen.dart';
import 'package:hopetsit/views/invoices/invoices_screen.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/views/wallet/wallet_screen.dart';
import 'package:hopetsit/services/donation_service.dart';
import 'package:hopetsit/utils/currency_helper.dart';

/// v20.1 — Unified payment management screen pour walker + petsitter.
///
/// Migration Airwallex : retiré "Compte de paiement" (Stripe Connect) et
/// "PayPal" du flow walker/sitter. Les payouts passent désormais
/// uniquement par IBAN (qui est branché sur Airwallex Beneficiaries côté
/// backend dès que la migration P4 est terminée).
///
/// Sections affichées :
///   • Compte bancaire (IBAN) — pour recevoir les paiements
///   • Ajouter une carte CB — pour payer (utile au walker/sitter quand il
///     joue aussi le rôle d'owner ou veut acheter Boost/Premium)
///   • Historique de paiement
///   • Soutenir HoPetSit (donation)
///
/// v565 (point 28) — kit Profil (cartes groupées, couleur du rôle), rangées
/// Portefeuille / Mes gains / Factures ajoutées, chips de statut traduits.
class PaymentManagementScreen extends StatelessWidget {
  const PaymentManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // v18.5 — #9 fix : charger le statut IBAN pour peindre le point vert
    // dans la rangée des icônes du haut et sur la carte "Compte bancaire".
    final ibanCtrl = Get.put(IbanStatusController());
    // v565 — couleur du rôle (sitter bleu / walker vert), kit Profil.
    final accent = currentRoleAccent();
    return ProfileSubPageScaffold(
      title: 'payment_management_title'.tr,
      accent: accent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header with quick-status icons ──
          _buildQuickStatusRow(ibanCtrl, context, accent),

          // ── Payment Methods Section ──
          ProfileSectionTitle('payment_methods_section'.tr,
              icon: Icons.account_balance_wallet_rounded),
          Obx(() => ProfileGroupCard(
                children: [
                  // IBAN / Bank Account
                  ProfileRow(
                    icon: Icons.account_balance_rounded,
                    color: const Color(0xFF1A73E8),
                    title: 'payment_iban_title'.tr,
                    subtitle: ibanCtrl.ibanConfigured.value
                        ? (ibanCtrl.ibanVerified.value
                            ? 'payment_iban_verified'.tr
                            : 'payment_iban_saved_pending'.tr)
                        : 'payment_iban_subtitle'.tr,
                    // v565 — état de chargement du statut IBAN (avant :
                    // « Configurer » affiché à tort pendant la requête).
                    trailing: ibanCtrl.isLoading.value
                        ? SizedBox(
                            width: 18.w,
                            height: 18.w,
                            child: const CircularProgressIndicator(
                                strokeWidth: 2.2, color: Color(0xFF1A73E8)),
                          )
                        : _statusChip(
                            ibanCtrl.ibanConfigured.value
                                ? 'payment_manage'.tr
                                : 'payment_configure'.tr,
                            ibanCtrl.ibanConfigured.value,
                            const Color(0xFF1A73E8),
                          ),
                    onTap: () async {
                      await Get.to(() => const IbanSetupScreen());
                      // Refresh status when coming back from IBAN screen.
                      ibanCtrl.refreshStatus();
                    },
                  ),
                  // Add card CB — utile pour acheter Boost / Premium / MapBoost.
                  ProfileRow(
                    icon: Icons.credit_card_rounded,
                    color: const Color(0xFF7C3AED),
                    title: 'payment_add_card_title'.tr,
                    subtitle: 'payment_add_card_subtitle'.tr,
                    trailing: _statusChip(
                      'payment_add_card_button'.tr,
                      false,
                      const Color(0xFF7C3AED),
                    ),
                    onTap: () => Get.to(() => const OwnerPaymentsScreen()),
                  ),
                ],
              )),

          // ── Gains, portefeuille, historiques ──
          ProfileSectionTitle('payment_history_title'.tr,
              icon: Icons.history_rounded),
          ProfileGroupCard(
            children: [
              ProfileRow(
                icon: Icons.account_balance_wallet_rounded,
                color: accent,
                title: 'wallet_title'.tr,
                subtitle: 'v565_pay_wallet_row_hint'.tr,
                onTap: () => Get.to(() => const WalletScreen()),
              ),
              // v565 — l'écran « Mes gains » n'était plus atteignable
              // depuis aucun menu : rangée ajoutée ici.
              ProfileRow(
                icon: Icons.trending_up_rounded,
                color: accent,
                title: 'earnings_title'.tr,
                subtitle: 'v565_pay_earnings_row_hint'.tr,
                onTap: () => Get.to(() => const EarningsHistoryScreen()),
              ),
              // Historique de paiement (versements reçus).
              ProfileRow(
                icon: Icons.receipt_long_rounded,
                color: Colors.teal,
                title: 'payment_history_title'.tr,
                subtitle: 'payment_history_subtitle'.tr,
                onTap: () =>
                    Get.to(() => const ProviderPayoutHistoryScreen()),
              ),
              ProfileRow(
                icon: Icons.picture_as_pdf_rounded,
                color: accent,
                title: 'v565_pay_receipts'.tr,
                subtitle: 'v565_pay_receipts_hint'.tr,
                onTap: () => Get.to(() => const InvoicesScreen()),
              ),
            ],
          ),

          SizedBox(height: 22.h),

          // ── Donation Section ──
          _buildDonationCard(context),

          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  Widget _statusChip(String label, bool active, Color color) {
    final c = active ? const Color(0xFF16A34A) : color;
    return Container(
      constraints: BoxConstraints(maxWidth: 110.w),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active) ...[
            Icon(Icons.check_circle_rounded, size: 13.sp, color: c),
            SizedBox(width: 4.w),
          ],
          Flexible(
            child: InterText(
              text: label,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: c,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 2 quick status icons at the top: Carte + IBAN
  Widget _buildQuickStatusRow(
    IbanStatusController ibanCtrl,
    BuildContext context,
    Color accent,
  ) {
    return Obx(() => Row(
      children: [
        // Carte CB (pour payer Boost/Premium si profil sitter/walker fait
        // aussi des achats internes).
        _quickIcon(
          context,
          Icons.credit_card_rounded,
          // v527 — retour Jose (R3-11) : « Carte » était en dur en français ;
          // la clé existe déjà dans les 6 langues.
          'payout_chip_card'.tr,
          false,
          const Color(0xFF7C3AED),
        ),
        SizedBox(width: 10.w),
        // IBAN — réel statut binding.
        _quickIcon(
          context,
          Icons.account_balance_rounded,
          'IBAN',
          ibanCtrl.ibanConfigured.value,
          const Color(0xFF1A73E8),
        ),
      ],
    ));
  }

  Widget _quickIcon(BuildContext context, IconData icon, String label, bool active, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: AppColors.cardShadow(context),
          border: active ? Border.all(color: color, width: 1.5) : null,
        ),
        child: Column(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: color.withValues(alpha: active ? 0.15 : 0.06),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, size: 20.sp, color: active ? color : AppColors.greyColor),
            ),
            SizedBox(height: 6.h),
            InterText(
              text: label,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: active ? color : AppColors.textSecondary(context),
            ),
            SizedBox(height: 4.h),
            InterText(
              text: active
                  ? 'v565_pay_status_configured'.tr
                  : 'v565_pay_status_missing'.tr,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: active
                  ? const Color(0xFF16A34A)
                  : AppColors.textSecondary(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

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
            child: Icon(
              Icons.favorite_rounded,
              size: 28.sp,
              color: AppColors.primaryColor,
            ),
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
              _donationAmountChip(context, 2),
              SizedBox(width: 8.w),
              _donationAmountChip(context, 5),
              SizedBox(width: 8.w),
              _donationAmountChip(context, 10),
              SizedBox(width: 8.w),
              _donationAmountChip(context, 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _donationAmountChip(BuildContext context, int euros) {
    // Lot D — libellé au format de la langue (« 2 € » / « €2 ») ; le don est
    // toujours en euros côté serveur.
    final amount = CurrencyHelper.formatCompact('EUR', euros.toDouble());
    return Expanded(
      child: GestureDetector(
        onTap: () {
          // v18.9.3 — don réel via provider actif (Stripe ou Airwallex).
          final parsed = euros.toDouble();
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
}
