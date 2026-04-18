import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/stripe_payment_controller.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

class StripePaymentScreen extends StatelessWidget {
  final BookingModel booking;
  final double totalAmount;
  final String? currency;

  const StripePaymentScreen({
    super.key,
    required this.booking,
    required this.totalAmount,
    this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final tag = 'stripe_payment_${booking.id}';
    if (Get.isRegistered<StripePaymentController>(tag: tag)) {
      Get.delete<StripePaymentController>(tag: tag);
    }

    final controller = Get.put(
      StripePaymentController(
        booking: booking,
        totalAmount: totalAmount,
        currency: currency ??
            booking.pricing?.currency ??
            booking.sitter.currency,
      ),
      tag: tag,
    );

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
          text: 'payment_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Amount Summary Card
                    _buildAmountSummaryCard(context),
                    SizedBox(height: 40.h),

                    // Information Card
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20.sp,
                            color: AppColors.primaryColor,
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: InterText(
                              text:
                                  'payment_stripe_info'.tr,
                              fontSize: 14.sp,
                              color: AppColors.primaryColor,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Pay Button at bottom
            Padding(
              padding: EdgeInsets.all(20.w),
              child: Obx(
                () => CustomButton(
                  title: controller.isProcessing.value
                      ? null
                      : 'payment_pay_button'.tr.replaceAll(
                          '@amount',
                          _formatPrice(totalAmount, controller.currency),
                        ),
                  onTap: !controller.isProcessing.value
                      ? () => controller.initiatePayment()
                      : null,
                  bgColor: controller.isProcessing.value
                      ? AppColors.primaryColor.withValues(alpha: 0.7)
                      : AppColors.primaryColor,
                  textColor: AppColors.whiteColor,
                  height: 48.h,
                  radius: 48.r,
                  child: controller.isProcessing.value
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountSummaryCard(BuildContext context) {
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
          PoppinsText(
            text: 'payment_amount_label'.tr,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary(context),
          ),
          SizedBox(height: 8.h),
          PoppinsText(
            text: _formatPrice(
              totalAmount,
              currency ??
                  booking.pricing?.currency ??
                  booking.sitter.currency,
            ),
            fontSize: 24.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryColor,
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price, String currency) {
    return CurrencyHelper.format(currency, price);
  }
}
