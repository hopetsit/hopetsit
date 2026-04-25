import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/iban_status_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/views/pet_sitter/profile/iban_setup_screen.dart';
import 'package:hopetsit/views/pet_owner/payments/owner_payments_screen.dart';
import 'package:hopetsit/views/pet_sitter/payment/provider_payout_history_screen.dart';
import 'package:hopetsit/services/donation_service.dart';

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
class PaymentManagementScreen extends StatelessWidget {
  const PaymentManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // v18.5 — #9 fix : charger le statut IBAN pour peindre le point vert
    // dans la rangée des icônes du haut et sur la carte "Compte bancaire".
    final ibanCtrl = Get.put(IbanStatusController());
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        leading: const BackButton(),
        title: PoppinsText(
          text: 'payment_management_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header with quick-status icons ──
              _buildQuickStatusRow(ibanCtrl, context),
              SizedBox(height: 24.h),

              // ── Payment Methods Section ──
              PoppinsText(
                text: 'payment_methods_section'.tr,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
              SizedBox(height: 12.h),

              // IBAN / Bank Account Card
              Obx(() => _buildPaymentMethodCard(
                context: context,
                icon: Icons.account_balance_rounded,
                iconColor: const Color(0xFF1A73E8),
                iconBg: const Color(0xFF1A73E8).withValues(alpha: 0.1),
                title: 'payment_iban_title'.tr,
                subtitle: ibanCtrl.ibanConfigured.value
                    ? (ibanCtrl.ibanVerified.value
                        ? 'payment_iban_verified'.tr
                        : 'payment_iban_saved_pending'.tr)
                    : 'payment_iban_subtitle'.tr,
                isConnected: ibanCtrl.ibanConfigured.value,
                onTap: () async {
                  await Get.to(() => const IbanSetupScreen());
                  // Refresh status when coming back from IBAN screen.
                  ibanCtrl.refreshStatus();
                },
                buttonLabel: ibanCtrl.ibanConfigured.value
                    ? 'payment_manage'.tr
                    : 'payment_configure'.tr,
              )),
              SizedBox(height: 10.h),

              // Add card CB — utile pour acheter Boost / Premium / MapBoost.
              _buildPaymentMethodCard(
                context: context,
                icon: Icons.credit_card_rounded,
                iconColor: const Color(0xFF7C3AED),
                iconBg: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                title: 'payment_add_card_title'.tr,
                subtitle: 'payment_add_card_subtitle'.tr,
                isConnected: false,
                onTap: () => Get.to(() => const OwnerPaymentsScreen()),
                buttonLabel: 'payment_add_card_button'.tr,
              ),
              SizedBox(height: 10.h),

              // Historique de paiement (versements reçus).
              _buildPaymentMethodCard(
                context: context,
                icon: Icons.receipt_long_rounded,
                iconColor: Colors.teal,
                iconBg: Colors.teal.withValues(alpha: 0.1),
                title: 'payment_history_title'.tr,
                subtitle: 'payment_history_subtitle'.tr,
                isConnected: false,
                onTap: () =>
                    Get.to(() => const ProviderPayoutHistoryScreen()),
                buttonLabel: 'payment_history_open'.tr,
              ),

              SizedBox(height: 28.h),

              // ── Donation Section ──
              _buildDonationCard(context),

              SizedBox(height: 40.h),
            ],
          ),
        ),
      ),
    );
  }

  /// 2 quick status icons at the top: Carte + IBAN
  Widget _buildQuickStatusRow(
    IbanStatusController ibanCtrl,
    BuildContext context,
  ) {
    return Obx(() => Row(
      children: [
        // Carte CB (pour payer Boost/Premium si profil sitter/walker fait
        // aussi des achats internes).
        _quickIcon(
          context,
          Icons.credit_card_rounded,
          'Carte',
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
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(16.r),
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
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: active ? color : AppColors.textSecondary(context),
            ),
            SizedBox(height: 2.h),
            Container(
              width: 6.w,
              height: 6.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? Colors.green : AppColors.greyColor.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required bool isConnected,
    required VoidCallback onTap,
    required String buttonLabel,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: AppColors.cardShadow(context),
        ),
        child: Row(
          children: [
            Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Icon(icon, size: 24.sp, color: iconColor),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      PoppinsText(
                        text: title,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                      if (isConnected) ...[
                        SizedBox(width: 8.w),
                        Icon(Icons.check_circle, size: 16.sp, color: Colors.green),
                      ],
                    ],
                  ),
                  SizedBox(height: 2.h),
                  // v20.0.17 — maxLines 3 + visible overflow pour que les
                  // traductions longues (DE / IT) ne soient plus tronquées.
                  InterText(
                    text: subtitle,
                    fontSize: 12.sp,
                    color: AppColors.textSecondary(context),
                    maxLines: 3,
                    overflow: TextOverflow.visible,
                  ),
                ],
              ),
            ),
            // v20.0.17 — Wrap the button label so it can flow on 2 lines and
            // width-limit for very long labels (ex. DE "IBAN konfigurieren").
            Container(
              constraints: BoxConstraints(maxWidth: 110.w),
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: isConnected
                    ? Colors.green.withValues(alpha: 0.1)
                    : iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: InterText(
                text: buttonLabel,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: isConnected ? Colors.green : iconColor,
                maxLines: 2,
                overflow: TextOverflow.visible,
              ),
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
        gradient: LinearGradient(
          colors: [
            AppColors.primaryColor.withValues(alpha: 0.08),
            AppColors.primaryColor.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.favorite_rounded,
            size: 36.sp,
            color: AppColors.primaryColor,
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
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              _donationAmountChip(context, '2€'),
              SizedBox(width: 8.w),
              _donationAmountChip(context, '5€'),
              SizedBox(width: 8.w),
              _donationAmountChip(context, '10€'),
              SizedBox(width: 8.w),
              _donationAmountChip(context, '20€'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _donationAmountChip(BuildContext context, String amount) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          // v18.9.3 — don réel via provider actif (Stripe ou Airwallex).
          // Parse "5€" → 5.0.
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
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: AppColors.primaryColor,
            borderRadius: BorderRadius.circular(12.r),
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
