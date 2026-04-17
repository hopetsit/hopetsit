import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/paypal_payment_controller.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

class PayPalPaymentScreen extends StatelessWidget {
  const PayPalPaymentScreen({
    super.key,
    required this.booking,
    required this.totalAmount,
    required this.currency,
  });

  final BookingModel booking;
  final double totalAmount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final tag = 'paypal_payment_${booking.id}';
    if (Get.isRegistered<PayPalPaymentController>(tag: tag)) {
      Get.delete<PayPalPaymentController>(tag: tag);
    }

    final controller = Get.put(
      PayPalPaymentController(
        booking: booking,
        totalAmount: totalAmount,
        currency: currency,
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
        leading: const BackButton(),
        title: PoppinsText(
          text: 'payment_method_paypal'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
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
                    Container(
                      padding: EdgeInsets.all(20.w),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(16.r),
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
                            text: CurrencyHelper.format(currency, totalAmount),
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryColor,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: AppColors.primaryColor.withValues(alpha: 0.25),
                        ),
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
                              text: 'payment_paypal_info'.tr,
                              fontSize: 14.sp,
                              color: AppColors.textSecondary(context),
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
            Padding(
              padding: EdgeInsets.all(20.w),
              child: Obx(
                () => CustomButton(
                  title: controller.isProcessing.value
                      ? null
                      : 'payment_pay_with_paypal'.tr.replaceAll(
                          '@amount',
                          CurrencyHelper.format(currency, totalAmount),
                        ),
                  onTap: controller.isProcessing.value
                      ? null
                      : () => controller.initiatePayPalPayment(),
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
}

