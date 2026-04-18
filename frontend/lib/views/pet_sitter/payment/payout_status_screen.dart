import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/sitter_paypal_payout_controller.dart';
import 'package:hopetsit/controllers/stripe_connect_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/views/pet_sitter/onboarding/stripe_connect_onboarding_screen.dart';
import 'package:hopetsit/widgets/paypal_email_dialog.dart';
import 'package:hopetsit/utils/app_constants.dart';

enum VerificationStatus { notStarted, pending, verified, rejected }

enum PayoutStatus { notConnected, pending, active, restricted }

class PayoutStatusScreen extends StatelessWidget {
  const PayoutStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(StripeConnectController());
    final payPalController = Get.put(SitterPayPalPayoutController());

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        leading: BackButton(),
        title: PoppinsText(
          text: 'payout_status_screen_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: Obx(
            () => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stripe Connect Status Card
                _buildStripeConnectStatusCard(controller, context),
                SizedBox(height: 24.h),

                // PayPal Payout Email Card — hidden for new sitters (feature flag),
                // but kept visible for legacy accounts that already have a PayPal email.
                if (AppConstants.showPayPalOption ||
                    payPalController.paypalEmail.value.isNotEmpty) ...[
                  _buildPayPalPayoutEmailCard(payPalController, context),
                  SizedBox(height: 24.h),
                ],

                // Verification Status Card
                _buildVerificationStatusCard(context),
                SizedBox(height: 24.h),

                // Payout Status Card
                _buildPayoutStatusCard(context),
                SizedBox(height: 24.h),

                // Action Buttons
                if (!controller.isConnected.value)
                  CustomButton(
                    title: 'payout_connect_stripe_account'.tr,
                    onTap: () {
                      Get.to(() => const StripeConnectOnboardingScreen());
                    },
                    bgColor: AppColors.primaryColor,
                    textColor: AppColors.whiteColor,
                    height: 48.h,
                    radius: 48.r,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPayPalPayoutEmailCard(SitterPayPalPayoutController controller, BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.email_outlined,
                size: 24.sp,
                color: AppColors.primaryColor,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: PoppinsText(
                  text: 'payout_paypal_email_title'.tr,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
              ),
              Obx(
                () => _buildStatusBadge(
                  controller.paypalEmail.value.isNotEmpty
                      ? 'payout_status_saved'.tr
                      : 'payout_status_not_set'.tr,
                  controller.paypalEmail.value.isNotEmpty,
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
              fontSize: 14.sp,
              color: AppColors.textSecondary(context),
            ),
          ),
          SizedBox(height: 16.h),
          Obx(
            () => CustomButton(
              title: controller.isSaving.value
                  ? null
                  : 'payout_update_paypal_email'.tr,
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
              bgColor: AppColors.primaryColor,
              textColor: AppColors.whiteColor,
              height: 44.h,
              radius: 44.r,
              child: controller.isSaving.value
                  ? SizedBox(
                      height: 20.h,
                      width: 20.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.whiteColor,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStripeConnectStatusCard(StripeConnectController controller, BuildContext context) {
    final isConnected = controller.isConnected.value;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet,
                size: 24.sp,
                color: isConnected ? Colors.green : AppColors.greyColor,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: PoppinsText(
                  text: 'payout_stripe_connect_title'.tr,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
              ),
              _buildStatusBadge(
                isConnected
                    ? 'payout_status_connected'.tr
                    : 'payout_status_not_connected'.tr,
                isConnected,
              ),
            ],
          ),
          SizedBox(height: 16.h),
          InterText(
            text: isConnected
                ? 'payout_stripe_connected_message'.tr
                : 'payout_stripe_not_connected_message'.tr,
            fontSize: 14.sp,
            color: AppColors.textSecondary(context),
          ),
          if (isConnected && controller.stripeAccountId.value.isNotEmpty) ...[
            SizedBox(height: 12.h),
            _buildDetailRow(
              'payout_account_id_label'.tr,
              controller.stripeAccountId.value,
              context,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVerificationStatusCard(BuildContext context) {
    // TODO: Get actual verification status from API
    final status = VerificationStatus.pending;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getVerificationIcon(status),
                size: 24.sp,
                color: _getVerificationColor(status),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: PoppinsText(
                  text: 'payout_verification_title'.tr,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
              ),
              _buildStatusBadge(
                _getVerificationStatusText(status),
                status == VerificationStatus.verified,
              ),
            ],
          ),
          SizedBox(height: 16.h),
          InterText(
            text: _getVerificationMessage(status),
            fontSize: 14.sp,
            color: AppColors.textSecondary(context),
          ),
          if (status == VerificationStatus.pending) ...[
            SizedBox(height: 16.h),
            _buildVerificationSteps(context),
          ],
        ],
      ),
    );
  }

  Widget _buildPayoutStatusCard(BuildContext context) {
    // TODO: Get actual payout status from API
    final status = PayoutStatus.pending;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getPayoutIcon(status),
                size: 24.sp,
                color: _getPayoutColor(status),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: PoppinsText(
                  text: 'payout_status_title'.tr,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
              ),
              _buildStatusBadge(
                _getPayoutStatusText(status),
                status == PayoutStatus.active,
              ),
            ],
          ),
          SizedBox(height: 16.h),
          InterText(
            text: _getPayoutMessage(status),
            fontSize: 14.sp,
            color: AppColors.textSecondary(context),
          ),
          if (status == PayoutStatus.active) ...[
            SizedBox(height: 16.h),
            _buildPayoutInfo(context),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String text, bool isActive) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withValues(alpha: 0.1)
            : AppColors.greyColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: InterText(
        text: text,
        fontSize: 11.sp,
        fontWeight: FontWeight.w600,
        color: isActive ? Colors.green : AppColors.greyColor,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InterText(
          text: label,
          fontSize: 12.sp,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary(context),
        ),
        InterText(
          text: value,
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary(context),
        ),
      ],
    );
  }

  Widget _buildVerificationSteps(BuildContext context) {
    final steps = [
      'payout_verification_step_identity'.tr,
      'payout_verification_step_bank'.tr,
      'payout_verification_step_business'.tr,
    ];

    return Column(
      children: steps.map((step) {
        return Container(
          margin: EdgeInsets.only(bottom: 12.h),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 16.sp,
                color: AppColors.primaryColor,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: InterText(
                  text: step,
                  fontSize: 12.sp,
                  color: AppColors.textPrimary(context),
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
