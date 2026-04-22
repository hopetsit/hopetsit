// v18.7 — Écran d'ajout de carte custom.
// Avant v18.7 : owner_payments_screen appelait Stripe.instance.presentPaymentSheet()
// en setup-intent mode pour ajouter une carte. Le sheet natif avait un bug
// connu sur Android où le premier champ (numéro de carte) ne recevait pas
// les taps — l'user devait commencer par la date pour débloquer.
//
// Fix : on remplace la PaymentSheet par ce widget custom qui utilise
// CardFormField (widget Flutter de flutter_stripe) + Stripe.instance
// .confirmSetupIntent(). Même modèle que ModernCardPaymentScreen pour les
// paiements booking.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

class AddCardScreen extends StatefulWidget {
  final String setupIntentClientSecret;
  final String? publishableKey;

  const AddCardScreen({
    super.key,
    required this.setupIntentClientSecret,
    this.publishableKey,
  });

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  CardFieldInputDetails? _cardDetails;
  final TextEditingController _holderNameCtrl = TextEditingController();
  bool _processing = false;

  @override
  void dispose() {
    _holderNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmAddCard() async {
    if (_processing) return;
    if (_cardDetails == null || !(_cardDetails!.complete)) {
      CustomSnackbar.showError(
        title: 'payment_card_incomplete_title'.tr,
        message: 'payment_card_incomplete_message'.tr,
      );
      return;
    }
    if (_holderNameCtrl.text.trim().isEmpty) {
      CustomSnackbar.showError(
        title: 'payment_cardholder_required_title'.tr,
        message: 'payment_cardholder_required_message'.tr,
      );
      return;
    }

    setState(() => _processing = true);
    try {
      // Apply publishable key if provided (safety net).
      if (widget.publishableKey != null && widget.publishableKey!.isNotEmpty) {
        Stripe.publishableKey = widget.publishableKey!;
        await Stripe.instance.applySettings();
      }

      await Stripe.instance.confirmSetupIntent(
        paymentIntentClientSecret: widget.setupIntentClientSecret,
        params: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(
            billingDetails: BillingDetails(
              name: _holderNameCtrl.text.trim(),
            ),
          ),
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true); // success
    } on StripeException catch (e) {
      AppLogger.logError('AddCardScreen: confirmSetupIntent failed', error: e);
      final code = e.error.code.toString().toLowerCase();
      if (code.contains('cancel')) {
        // User cancelled — bail quietly.
        if (mounted) Navigator.of(context).pop(false);
        return;
      }
      if (!mounted) return;
      CustomSnackbar.showError(
        title: 'payment_failed_title'.tr,
        message: e.error.localizedMessage ?? e.error.message ?? 'Erreur carte',
      );
    } catch (e) {
      AppLogger.logError('AddCardScreen: unexpected', error: e);
      if (!mounted) return;
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color accent = Color(0xFFEF4324); // owner orange (Mes paiements)
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: accent),
        leading: const BackButton(),
        title: PoppinsText(
          text: 'add_card_title'.tr,
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
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: AppColors.cardShadow(context),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.credit_card_rounded,
                                  size: 20.sp, color: accent),
                              SizedBox(width: 8.w),
                              PoppinsText(
                                text: 'payment_card_section_title'.tr,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary(context),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          CardFormField(
                            style: CardFormStyle(
                              borderColor: accent.withValues(alpha: 0.25),
                              borderRadius: 12,
                              borderWidth: 1,
                              textColor: AppColors.textPrimary(context),
                              placeholderColor:
                                  AppColors.textSecondary(context),
                              backgroundColor: AppColors.scaffold(context),
                              fontSize: 14,
                            ),
                            onCardChanged: (details) {
                              setState(() => _cardDetails = details);
                            },
                          ),
                          SizedBox(height: 14.h),
                          TextField(
                            controller: _holderNameCtrl,
                            decoration: InputDecoration(
                              labelText: 'payment_cardholder_name'.tr,
                              prefixIcon: Icon(Icons.person_outline,
                                  color: accent),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            textInputAction: TextInputAction.done,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline, size: 20.sp, color: accent),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: InterText(
                              text: 'payment_stripe_info'.tr,
                              fontSize: 13.sp,
                              color: accent,
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
              padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
              child: CustomButton(
                title: _processing ? null : 'add_card_save'.tr,
                onTap: _processing ? null : _confirmAddCard,
                bgColor: _processing ? accent.withValues(alpha: 0.7) : accent,
                textColor: AppColors.whiteColor,
                height: 48.h,
                radius: 48.r,
                width: double.infinity,
                child: _processing
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
      ),
    );
  }
}
