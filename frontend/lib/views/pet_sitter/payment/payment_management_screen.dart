import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/stripe_connect_controller.dart';
import 'package:hopetsit/controllers/sitter_paypal_payout_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/views/pet_sitter/onboarding/stripe_connect_onboarding_screen.dart';
import 'package:hopetsit/views/pet_sitter/profile/iban_setup_screen.dart';
import 'package:hopetsit/views/pet_sitter/profile/identity_verification_screen.dart';
import 'package:hopetsit/widgets/paypal_email_dialog.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// Unified payment management screen — Stripe, PayPal, IBAN, and status
/// all in one modern place.
class PaymentManagementScreen extends StatelessWidget {
  const PaymentManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stripeCtrl = Get.put(StripeConnectController());
    final paypalCtrl = Get.put(SitterPayPalPayoutController());
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              // ── Header with 4 quick-status icons ──
              _buildQuickStatusRow(stripeCtrl, paypalCtrl, context),
              SizedBox(height: 24.h),

              // ── Payment Methods Section ──
              PoppinsText(
                text: 'payment_methods_section'.tr,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
              SizedBox(height: 12.h),

              // Stripe Connect Card
              _buildPaymentMethodCard(
                context: context,
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFF635BFF),
                iconBg: const Color(0xFF635BFF).withOpacity(0.1),
                title: 'Stripe',
                subtitle: stripeCtrl.isConnected.value
                    ? 'payment_stripe_connected'.tr
                    : 'payment_stripe_not_connected'.tr,
                isConnected: stripeCtrl.isConnected.value,
                onTap: () => Get.to(() => const StripeConnectOnboardingScreen()),
                buttonLabel: stripeCtrl.isConnected.value
                    ? 'payment_manage'.tr
                    : 'payment_connect'.tr,
              ),
              SizedBox(height: 10.h),

              // PayPal Card
              Obx(() => _buildPaymentMethodCard(
                context: context,
                icon: Icons.paypal_rounded,
                iconColor: const Color(0xFF003087),
                iconBg: const Color(0xFF003087).withOpacity(0.1),
                title: 'PayPal',
                subtitle: paypalCtrl.paypalEmail.value.isNotEmpty
                    ? paypalCtrl.paypalEmail.value
                    : 'payment_paypal_not_set'.tr,
                isConnected: paypalCtrl.paypalEmail.value.isNotEmpty,
                onTap: () => _showPayPalDialog(paypalCtrl),
                buttonLabel: paypalCtrl.paypalEmail.value.isNotEmpty
                    ? 'payment_manage'.tr
                    : 'payment_connect'.tr,
              )),
              SizedBox(height: 10.h),

              // IBAN / Bank Account Card
              _buildPaymentMethodCard(
                context: context,
                icon: Icons.account_balance_rounded,
                iconColor: const Color(0xFF1A73E8),
                iconBg: const Color(0xFF1A73E8).withOpacity(0.1),
                title: 'payment_iban_title'.tr,
                subtitle: 'payment_iban_subtitle'.tr,
                isConnected: false, // TODO: check IBAN status
                onTap: () => Get.to(() => const IbanSetupScreen()),
                buttonLabel: 'payment_configure'.tr,
              ),

              SizedBox(height: 28.h),

              // ── Verification & Status Section ──
              PoppinsText(
                text: 'payment_verification_section'.tr,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
              SizedBox(height: 12.h),

              // Identity Verification Card
              _buildStatusCard(
                context: context,
                icon: Icons.verified_user_rounded,
                iconColor: Colors.teal,
                title: 'payment_identity_title'.tr,
                description: 'payment_identity_desc'.tr,
                statusLabel: 'payout_status_pending'.tr,
                statusActive: false,
                onTap: () => Get.to(() => const IdentityVerificationScreen()),
              ),
              SizedBox(height: 10.h),

              // Payment Status Card
              Obx(() => _buildStatusCard(
                context: context,
                icon: Icons.receipt_long_rounded,
                iconColor: Colors.orange,
                title: 'payment_payout_status_title'.tr,
                description: stripeCtrl.isConnected.value
                    ? 'payment_payout_active_desc'.tr
                    : 'payment_payout_inactive_desc'.tr,
                statusLabel: stripeCtrl.isConnected.value
                    ? 'payout_status_active'.tr
                    : 'payout_status_pending'.tr,
                statusActive: stripeCtrl.isConnected.value,
                onTap: null,
              )),

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

  /// 4 quick status icons at the top
  Widget _buildQuickStatusRow(
    StripeConnectController stripeCtrl,
    SitterPayPalPayoutController paypalCtrl,
    BuildContext context,
  ) {
    return Obx(() => Row(
      children: [
        _quickIcon(
          context,
          Icons.account_balance_wallet_rounded,
          'Stripe',
          stripeCtrl.isConnected.value,
          const Color(0xFF635BFF),
        ),
        SizedBox(width: 10.w),
        _quickIcon(
          context,
          Icons.paypal_rounded,
          'PayPal',
          paypalCtrl.paypalEmail.value.isNotEmpty,
          const Color(0xFF003087),
        ),
        SizedBox(width: 10.w),
        _quickIcon(
          context,
          Icons.account_balance_rounded,
          'IBAN',
          false,
          const Color(0xFF1A73E8),
        ),
        SizedBox(width: 10.w),
        _quickIcon(
          context,
          Icons.verified_user_rounded,
          'ID',
          false,
          Colors.teal,
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
                color: color.withOpacity(active ? 0.15 : 0.06),
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
                color: active ? Colors.green : AppColors.greyColor.withOpacity(0.3),
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
                  InterText(
                    text: subtitle,
                    fontSize: 12.sp,
                    color: AppColors.textSecondary(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: isConnected
                    ? Colors.green.withOpacity(0.1)
                    : iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: InterText(
                text: buttonLabel,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: isConnected ? Colors.green : iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required String statusLabel,
    required bool statusActive,
    VoidCallback? onTap,
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
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, size: 22.sp, color: iconColor),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PoppinsText(
                    text: title,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                  SizedBox(height: 2.h),
                  InterText(
                    text: description,
                    fontSize: 11.sp,
                    color: AppColors.textSecondary(context),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
              decoration: BoxDecoration(
                color: statusActive
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: InterText(
                text: statusLabel,
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: statusActive ? Colors.green : Colors.orange,
              ),
            ),
            if (onTap != null) ...[
              SizedBox(width: 6.w),
              Icon(Icons.arrow_forward_ios, size: 14.sp, color: AppColors.textSecondary(context)),
            ],
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
            AppColors.primaryColor.withOpacity(0.08),
            AppColors.primaryColor.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.primaryColor.withOpacity(0.2)),
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
          // TODO: Connect to Stripe payment for donation
          CustomSnackbar.showSuccess(
            title: 'common_coming_soon'.tr,
            message: 'payment_donate_coming_soon'.tr,
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

  void _showPayPalDialog(SitterPayPalPayoutController controller) {
    controller.emailController.text = controller.paypalEmail.value;
    Get.dialog(
      PayPalEmailDialog(
        controller: controller.emailController,
        initialEmail: controller.paypalEmail.value,
        title: 'payout_update_paypal_email'.tr,
        subtitle: 'payout_paypal_dialog_subtitle'.tr,
        primaryText: 'common_save'.tr,
        secondaryText: 'common_cancel'.tr,
        isLoading: controller.isSaving.value,
        onSecondary: () => Get.back(),
        onPrimary: () async {
          await controller.savePayPalEmail();
          if (Get.isDialogOpen == true) {
            Get.back();
          }
        },
      ),
      barrierDismissible: false,
    );
  }
}
