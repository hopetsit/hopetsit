import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/sitter_paypal_payout_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/paypal_email_dialog.dart';
import 'package:hopetsit/utils/app_constants.dart';

/// Statut des versements (sitter / walker).
///
/// v565 (point 28) — kit Profil : cartes coins 20, couleur du rôle, pastilles
/// de statut avec point, bouton principal du kit. Logique inchangée.
enum VerificationStatus { notStarted, pending, verified, rejected }

enum PayoutStatus { notConnected, pending, active, restricted }

class PayoutStatusScreen extends StatelessWidget {
  const PayoutStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final payPalController = Get.put(SitterPayPalPayoutController());
    // v565 — kit Profil, couleur du rôle (sitter bleu / walker vert).
    final accent = currentRoleAccent();

    return ProfileSubPageScaffold(
      title: 'payout_status_screen_title'.tr,
      accent: accent,
      body: Obx(
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stripe Connect Status Card — deprecated
            SizedBox(height: 8.h),

            // PayPal Payout Email Card — hidden for new sitters (feature flag),
            // but kept visible for legacy accounts that already have a PayPal email.
            if (AppConstants.showPayPalOption ||
                payPalController.paypalEmail.value.isNotEmpty) ...[
              _buildPayPalPayoutEmailCard(payPalController, context, accent),
              SizedBox(height: 14.h),
            ],

            // Verification Status Card
            _buildVerificationStatusCard(context, accent),
            SizedBox(height: 14.h),

            // Payout Status Card
            _buildPayoutStatusCard(context, accent),
            SizedBox(height: 14.h),

            // v21.1.1 — Bouton "Connecter compte Stripe" retiré (Stripe
            // purgé). Le sitter configure ses payouts via IBAN dans
            // Profil → Compte bancaire (Airwallex Beneficiary auto-créé).
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDeco(BuildContext context) => BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: AppColors.cardShadow(context),
      );

  Widget _iconChip(IconData icon, Color color) => Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(icon, size: 20.sp, color: color),
      );

  Widget _buildPayPalPayoutEmailCard(SitterPayPalPayoutController controller, BuildContext context, Color accent) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: _cardDeco(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconChip(Icons.email_outlined, accent),
              SizedBox(width: 12.w),
              Expanded(
                child: PoppinsText(
                  text: 'payout_paypal_email_title'.tr,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                  maxLines: 2,
                ),
              ),
              Flexible(
                child: Obx(
                  () => _buildStatusBadge(
                    controller.paypalEmail.value.isNotEmpty
                        ? 'payout_status_saved'.tr
                        : 'payout_status_not_set'.tr,
                    controller.paypalEmail.value.isNotEmpty,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Obx(
            () => InterText(
              text: controller.paypalEmail.value.isNotEmpty
                  ? controller.paypalEmail.value
                  : 'payout_paypal_email_hint'.tr,
              fontSize: 13.5.sp,
              color: AppColors.textSecondary(context),
              maxLines: 3,
            ),
          ),
          SizedBox(height: 14.h),
          Obx(
            () => ProfilePrimaryButton(
              label: 'payout_update_paypal_email'.tr,
              accent: accent,
              icon: Icons.edit_rounded,
              loading: controller.isSaving.value,
              onTap: controller.isSaving.value
                  ? null
                  : () {
                      controller.emailController.text =
                          controller.paypalEmail.value;
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
                    },
            ),
          ),
        ],
      ),
    );
  }

  // v21.1.1 — _buildStripeConnectStatusCard supprimée (Stripe Connect purgé).

  Widget _buildVerificationStatusCard(BuildContext context, Color accent) {
    // TODO: Get actual verification status from API
    final status = VerificationStatus.pending;

    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: _cardDeco(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconChip(_getVerificationIcon(status), _getVerificationColor(status)),
              SizedBox(width: 12.w),
              Expanded(
                child: PoppinsText(
                  text: 'payout_verification_title'.tr,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                  maxLines: 2,
                ),
              ),
              Flexible(
                child: _buildStatusBadge(
                  _getVerificationStatusText(status),
                  status == VerificationStatus.verified,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          InterText(
            text: _getVerificationMessage(status),
            fontSize: 13.5.sp,
            color: AppColors.textSecondary(context),
            height: 1.4,
            maxLines: 6,
          ),
          if (status == VerificationStatus.pending) ...[
            SizedBox(height: 14.h),
            _buildVerificationSteps(context, accent),
          ],
        ],
      ),
    );
  }

  Widget _buildPayoutStatusCard(BuildContext context, Color accent) {
    // TODO: Get actual payout status from API
    final status = PayoutStatus.pending;

    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: _cardDeco(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconChip(_getPayoutIcon(status), _getPayoutColor(status)),
              SizedBox(width: 12.w),
              Expanded(
                child: PoppinsText(
                  text: 'payout_status_title'.tr,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                  maxLines: 2,
                ),
              ),
              Flexible(
                child: _buildStatusBadge(
                  _getPayoutStatusText(status),
                  status == PayoutStatus.active,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          InterText(
            text: _getPayoutMessage(status),
            fontSize: 13.5.sp,
            color: AppColors.textSecondary(context),
            height: 1.4,
            maxLines: 6,
          ),
          if (status == PayoutStatus.active) ...[
            SizedBox(height: 14.h),
            _buildPayoutInfo(context),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String text, bool isActive) {
    final c = isActive ? const Color(0xFF16A34A) : const Color(0xFFF59E0B);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          SizedBox(width: 5.w),
          Flexible(
            child: InterText(
              text: text,
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

  Widget _buildDetailRow(String label, String value, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: InterText(
            text: label,
            fontSize: 12.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: 8.w),
        Flexible(
          child: InterText(
            text: value,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationSteps(BuildContext context, Color accent) {
    final steps = [
      'payout_verification_step_identity'.tr,
      'payout_verification_step_bank'.tr,
      'payout_verification_step_business'.tr,
    ];

    return Column(
      children: steps.map((step) {
        return Container(
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 18.sp,
                color: accent,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: InterText(
                  text: step,
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary(context),
                  maxLines: 3,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPayoutInfo(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            'payout_next_payout_label'.tr,
            'payout_status_pending'.tr,
            context,
          ),
          SizedBox(height: 8.h),
          _buildDetailRow(
            'payout_schedule_label'.tr,
            'payout_schedule_daily'.tr,
            context,
          ),
          SizedBox(height: 8.h),
          _buildDetailRow('payout_minimum_amount_label'.tr, '\$10.00', context),
        ],
      ),
    );
  }

  IconData _getVerificationIcon(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.verified:
        return Icons.verified;
      case VerificationStatus.pending:
        return Icons.pending;
      case VerificationStatus.rejected:
        return Icons.error;
      case VerificationStatus.notStarted:
        return Icons.info;
    }
  }

  Color _getVerificationColor(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.verified:
        return Colors.green;
      case VerificationStatus.pending:
        return Colors.orange;
      case VerificationStatus.rejected:
        return AppColors.errorColor;
      case VerificationStatus.notStarted:
        return AppColors.greyColor;
    }
  }

  String _getVerificationStatusText(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.verified:
        return 'payout_status_verified'.tr;
      case VerificationStatus.pending:
        return 'payout_status_pending'.tr;
      case VerificationStatus.rejected:
        return 'payout_status_rejected'.tr;
      case VerificationStatus.notStarted:
        return 'payout_status_not_started'.tr;
    }
  }

  String _getVerificationMessage(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.verified:
        return 'payout_verification_message_verified'.tr;
      case VerificationStatus.pending:
        return 'payout_verification_message_pending'.tr;
      case VerificationStatus.rejected:
        return 'payout_verification_message_rejected'.tr;
      case VerificationStatus.notStarted:
        return 'payout_verification_message_not_started'.tr;
    }
  }

  IconData _getPayoutIcon(PayoutStatus status) {
    switch (status) {
      case PayoutStatus.active:
        return Icons.payment;
      case PayoutStatus.pending:
        return Icons.pending;
      case PayoutStatus.restricted:
        return Icons.block;
      case PayoutStatus.notConnected:
        return Icons.link_off;
    }
  }

  Color _getPayoutColor(PayoutStatus status) {
    switch (status) {
      case PayoutStatus.active:
        return Colors.green;
      case PayoutStatus.pending:
        return Colors.orange;
      case PayoutStatus.restricted:
        return AppColors.errorColor;
      case PayoutStatus.notConnected:
        return AppColors.greyColor;
    }
  }

  String _getPayoutStatusText(PayoutStatus status) {
    switch (status) {
      case PayoutStatus.active:
        return 'payout_status_active'.tr;
      case PayoutStatus.pending:
        return 'payout_status_pending'.tr;
      case PayoutStatus.restricted:
        return 'payout_status_restricted'.tr;
      case PayoutStatus.notConnected:
        return 'payout_status_not_connected'.tr;
    }
  }

  String _getPayoutMessage(PayoutStatus status) {
    switch (status) {
      case PayoutStatus.active:
        return 'payout_message_active'.tr;
      case PayoutStatus.pending:
        return 'payout_message_pending'.tr;
      case PayoutStatus.restricted:
        return 'payout_message_restricted'.tr;
      case PayoutStatus.notConnected:
        return 'payout_message_not_connected'.tr;
    }
  }
}
