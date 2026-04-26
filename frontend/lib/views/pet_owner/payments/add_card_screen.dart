// v21.1.1 — Stripe purgé.
// Cet écran était l'ancien CardFormField Stripe pour ajouter une carte
// via SetupIntent. Stripe n'est plus utilisé : le screen owner_payments
// est désactivé avec un message friendly. Ce fichier reste comme stub
// pour ne pas casser les imports résiduels.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

class AddCardScreen extends StatelessWidget {
  final String? setupIntentClientSecret;
  final String? publishableKey;

  const AddCardScreen({
    super.key,
    this.setupIntentClientSecret,
    this.publishableKey,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        title: PoppinsText(
          text: 'Ajouter une carte',
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
              Icon(Icons.credit_card,
                  size: 48.sp, color: AppColors.textSecondary(context)),
              SizedBox(height: 16.h),
              PoppinsText(
                text: 'Carte enregistrée automatiquement',
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              InterText(
                text:
                    'Avec Airwallex ta carte est enregistrée automatiquement lors de ton premier paiement. Plus besoin de l\'ajouter à l\'avance.',
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
