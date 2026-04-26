import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// v21.1.1 — Stripe purgé. Cet écran était l'ancien CardFormField Stripe
/// pour saisir une carte sans saved-card. Avec Airwallex tout passe par
/// l'HPP (webview) — donc cet écran ne devrait plus être atteint.
///
/// On garde le fichier comme stub pour ne pas casser d'éventuels imports
/// résiduels. Si jamais quelqu'un le push, il affiche un message clair
/// et permet de revenir en arrière.
class ModernCardPaymentScreen extends StatelessWidget {
  final String? clientSecret;
  final double? amount;
  final String? currency;
  final String? productLabel;
  final String? productSubtitle;
  final List<Map<String, dynamic>>? savedPaymentMethods;

  const ModernCardPaymentScreen({
    super.key,
    this.clientSecret,
    this.amount,
    this.currency,
    this.productLabel,
    this.productSubtitle,
    this.savedPaymentMethods,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        title: PoppinsText(
          text: 'Paiement',
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline,
                  size: 48.sp, color: AppColors.textSecondary(context)),
              SizedBox(height: 16.h),
              PoppinsText(
                text: 'Le paiement passe désormais par Airwallex',
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              InterText(
                text:
                    'Reviens à l\'écran précédent et relance ton achat — un nouveau formulaire de paiement va s\'ouvrir.',
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary(context),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
