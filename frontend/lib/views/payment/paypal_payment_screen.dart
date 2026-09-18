import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/paypal_payment_controller.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/service_type_translator.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';

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

    // v565 (point 28) — en-tête clair : montant, prestataire, moyen de
    // paiement (PayPal), état, bouton du rôle ; logique inchangée.
    final accent = AppColors.roleAccent(booking.serviceType?.toLowerCase().contains('walk') == true ? 'walker' : 'sitter');
    return ProfileSubPageScaffold(
      title: 'payment_method_paypal'.tr,
      accent: accent,
      bottom: Obx(
        () => ProfilePrimaryButton(
          label: 'payment_pay_with_paypal'.tr.replaceAll(
            '@amount',
            CurrencyHelper.format(currency, totalAmount),
          ),
          accent: accent,
          icon: Icons.paypal,
          loading: controller.isProcessing.value,
          onTap: controller.isProcessing.value
              ? null
              : () => controller.initiatePayPalPayment(),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 8.h),
          Center(
            child: Container(
              width: 72.w,
              height: 72.w,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.paypal, size: 34.sp, color: accent),
            ),
          ),
          SizedBox(height: 12.h),
          PoppinsText(
            text: 'v565_pay_secure_title'.tr,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4.h),
          PoppinsText(
            text: CurrencyHelper.format(currency, totalAmount),
            fontSize: 30.sp,
            fontWeight: FontWeight.w800,
            color: accent,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 18.h),
          ProfileGroupCard(
            children: [
              ProfileRow(
                icon: Icons.person_rounded,
                color: accent,
                title: booking.sitter.name.isNotEmpty
                    ? booking.sitter.name
                    : 'provider_unknown'.tr,
                subtitle: translateServiceType(booking.serviceType),
                showChevron: false,
              ),
              ProfileRow(
                icon: Icons.paypal,
                color: accent,
                title: 'v565_pay_method_label'.tr,
                subtitle: 'payment_method_paypal'.tr,
                showChevron: false,
              ),
              ProfileRow(
                icon: Icons.payments_rounded,
                color: accent,
                title: 'payment_amount_label'.tr,
                showChevron: false,
                trailing: PoppinsText(
                  text: CurrencyHelper.format(currency, totalAmount),
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ProfileInfoBanner(
            icon: Icons.info_outline_rounded,
            text: 'payment_paypal_info'.tr,
            accent: accent,
          ),
          SizedBox(height: 10.h),
          Obx(() => controller.isProcessing.value
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: CircularProgressIndicator(
                          color: accent, strokeWidth: 2.2),
                    ),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: InterText(
                        text: 'payment_connecting'.tr,
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink()),
        ],
      ),
    );
  }
}
