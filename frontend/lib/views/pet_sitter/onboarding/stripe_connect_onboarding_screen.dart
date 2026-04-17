import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/stripe_connect_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:shimmer/shimmer.dart';

class StripeConnectOnboardingScreen extends StatelessWidget {
  const StripeConnectOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(StripeConnectController());

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        leading: BackButton(),
        title: PoppinsText(
          text: 'stripe_connect_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stripe Logo/Icon
              Center(
                child: Container(
                  width: 80.w,
                  height: 80.h,
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    shape: BoxShape.circle,
                    boxShadow: AppColors.cardShadow(context),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    size: 40.sp,
                    color: Color(0xFF635BFF), // Stripe brand color
                  ),
                ),
              ),

              SizedBox(height: 10.h),

              // Title
              Center(
                child: PoppinsText(
                  text: 'stripe_get_paid_title'.tr,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                  textAlign: TextAlign.center,
                ),
              ),

              SizedBox(height: 10.h),

              // Description
              InterText(
                text: 'stripe_connect_description'.tr,
                fontSize: 14.sp,
                color: AppColors.textSecondary(context),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 10.h),

              // Benefits List
              _buildBenefitsList(context),

              SizedBox(height: 10.h),
              PoppinsText(
                text: 'stripe_account_status_title'.tr,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
              SizedBox(height: 10.h),

              // Account Status Card (with shimmer loading)
              Obx(() {
                if (controller.isLoadingStatus.value) {
                  return _buildAccountStatusShimmer(context);
                } else if (controller.stripeAccountId.value.isNotEmpty) {
                  return _buildAccountStatusCard(context, controller);
                } else {
                  return const SizedBox.shrink();
                }
              }),

              SizedBox(height: 20.h),

              // Connect/Continue Button
              Obx(() {
                final hasAccount = controller.stripeAccountId.value.isNotEmpty;
                final isConnected = controller.isConnected.value;
                final hasOnboardingUrl =
                    controller.onboardingUrl.value.isNotEmpty &&
                    !controller.isOnboardingUrlExpired();

                if (!controller.isLoadingStatus.value) {
                  // Show different button based on account status
                  if (isConnected) {
                  } else if (hasAccount && hasOnboardingUrl) {
                    // Account exists but onboarding not complete
                    return CustomButton(
                      title: controller.isConnecting.value
                          ? null
                          : 'stripe_continue_onboarding'.tr,
                      onTap: controller.isConnecting.value
                          ? null
                          : () => controller.openOnboardingWebview(),
                      bgColor: AppColors.primaryColor,
                      textColor: AppColors.whiteColor,
                      height: 48.h,
                      radius: 48.r,
                      child: controller.isConnecting.value
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
                    );
                  } else {
                    // No account - show create button
                    return CustomButton(
                      title: controller.isConnecting.value
                          ? null
                          : 'stripe_connect_account_button'.tr,
                      onTap: controller.isConnecting.value
                          ? null
                          : () => controller.connectStripe(),
                      bgColor: AppColors.primaryColor,
                      textColor: AppColors.whiteColor,
                      height: 48.h,
                      radius: 48.r,
                      child: controller.isConnecting.value
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
                    );
                  }
                }
                return Container();
              }),

              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitsList(BuildContext context) {
    final benefits = [
      'stripe_benefit_secure'.tr,
      'stripe_benefit_fast_payouts'.tr,
      'stripe_benefit_no_fees'.tr,
      'stripe_benefit_support'.tr,
    ];

    return Column(
      children: benefits.map((benefit) {
        return Container(
          margin: EdgeInsets.only(bottom: 5.h),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.divider(context), width: 1),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, size: 20.sp, color: Colors.green),
              SizedBox(width: 12.w),
              Expanded(
                child: InterText(
                  text: benefit,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAccountStatusShimmer(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.grey300Color,
      highlightColor: AppColors.card(context),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.divider(context), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24.sp,
                  height: 24.sp,
                  decoration: BoxDecoration(
                    color: AppColors.grey300Color,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Container(
                    height: 16.sp,
                    decoration: BoxDecoration(
                      color: AppColors.grey300Color,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Container(
              height: 12.sp,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.grey300Color,
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
            SizedBox(height: 8.h),
            Container(
              height: 12.sp,
              width: 200.w,
              decoration: BoxDecoration(
                color: AppColors.grey300Color,
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Container(
                  height: 12.sp,
                  width: 80.w,
                  decoration: BoxDecoration(
                    color: AppColors.grey300Color,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Container(
                    height: 12.sp,
                    decoration: BoxDecoration(
                      color: AppColors.grey300Color,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountStatusCard(BuildContext context, StripeConnectController controller) {
    return Obx(
      () => Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: controller.isConnected.value ? Colors.green : Colors.orange,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  controller.isConnected.value
                      ? Icons.check_circle
                      : Icons.pending,
                  color: controller.isConnected.value
                      ? Colors.green
                      : Colors.orange,
                  size: 24.sp,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: PoppinsText(
                    text: controller.isConnected.value
                        ? 'stripe_account_connected'.tr
                        : 'stripe_account_created_pending'.tr,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            InterText(
              text: controller.isConnected.value
                  ? 'stripe_account_connected_message'.tr
                  : 'stripe_account_created_message'.tr,
              fontSize: 14.sp,
              color: AppColors.textSecondary(context),
            ),
            if (controller.stripeAccountId.value.isNotEmpty) ...[
              SizedBox(height: 12.h),
              _buildDetailRow(context, 'stripe_account_id_label'.tr, controller.stripeAccountId.value),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InterText(
          text: '$label: ',
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary(context),
        ),
        Expanded(
          child: InterText(
            text: value,
            fontSize: 12.sp,
            color: AppColors.textPrimary(context),
          ),
        ),
      ],
    );
  }
}
