import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/paypal_payment_controller.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/utils/service_type_translator.dart';
import 'package:hopetsit/views/payment/widgets/payment_ui_kit.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';

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

    // v569 — même habillage que la carte : barre « Paiement sécurisé »,
    // montant en gros, récapitulatif repliable, rangée de confiance, états de
    // chargement. La logique PayPal (contrôleur, initiatePayPalPayment) est
    // strictement inchangée.
    final accent = AppColors.roleAccent(booking.serviceType?.toLowerCase().contains('walk') == true ? 'walker' : 'sitter');
    final amountText = CurrencyHelper.format(currency, totalAmount);
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: PaySecureAppBar(
        accent: accent,
        title: 'pay569_title'.tr,
        subtitle: amountText,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: PawPatternBackground(
          color: AppColors.activeRoleAccent(),
          child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 12.h),
                child: Column(
                  children: [
                    SizedBox(height: 8.h),
                    PayAmountHero(
                      label: 'pay569_amount_label'.tr,
                      amount: amountText,
                      accent: accent,
                      icon: Icons.paypal,
                    ),
                    SizedBox(height: 20.h),
                    PayRecapCard(
                      title: booking.sitter.name.isNotEmpty
                          ? booking.sitter.name
                          : 'provider_unknown'.tr,
                      subtitle: translateServiceType(booking.serviceType),
                      avatarUrl: booking.sitter.avatar.url,
                      totalLabel: 'payment_amount_label'.tr,
                      totalValue: amountText,
                      accent: accent,
                      expandLabel: 'pay569_details_show'.tr,
                      collapseLabel: 'pay569_details_hide'.tr,
                      lines: [
                        PayRecapLine(
                          icon: Icons.paypal,
                          label: 'v565_pay_method_label'.tr,
                          value: 'payment_method_paypal'.tr,
                        ),
                      ],
                    ),
                    SizedBox(height: 14.h),
                    Obx(() => controller.isProcessing.value
                        ? PayLoadingCard(
                            message: 'pay569_connecting'.tr,
                            hint: 'pay569_dont_close'.tr,
                            accent: accent,
                          )
                        : ProfileInfoBanner(
                            icon: Icons.info_outline_rounded,
                            text: 'payment_paypal_info'.tr,
                            accent: accent,
                          )),
                    SizedBox(height: 14.h),
                    PayTrustRow(
                      accent: accent,
                      brands: const <String>['PayPal'],
                      assurances: [
                        'pay569_trust_encrypted'.tr,
                        'pay569_trust_escrow'.tr,
                      ],
                    ),
                    SizedBox(height: 12.h),
                    InterText(
                      text: 'pay569_paypal_redirect'.tr,
                      fontSize: 11.sp,
                      color: AppColors.textSecondary(context),
                      textAlign: TextAlign.center,
                      height: 1.4,
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              // v569 — dégagement bas unique de l'app (le SafeArea ci-dessus
              // n'applique rien sur le Samsung de Daniel).
              padding: EdgeInsets.fromLTRB(
                  20.w, 8.h, 20.w, 12.h + appBottomInsetInsideSafeArea(context)),
              child: Obx(() {
                final busy = controller.isProcessing.value;
                return CustomButton(
                  bgColor: accent,
                  onTap: busy ? null : () => controller.initiatePayPalPayment(),
                  child: busy
                      ? SizedBox(
                          width: 22.w,
                          height: 22.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14.w),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.paypal,
                                  size: 18.sp, color: Colors.white),
                              SizedBox(width: 8.w),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: InterText(
                                    text: 'payment_pay_with_paypal'
                                        .tr
                                        .replaceAll('@amount', amountText),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                );
              }),
            ),
          ],
        ),
      ),
        ),
    );
  }
}
