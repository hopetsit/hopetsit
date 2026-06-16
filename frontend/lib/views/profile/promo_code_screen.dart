import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/controllers/promo_controller.dart';
import 'package:hopetsit/repositories/promo_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

/// Écran de saisie d'un code promo (accessible depuis les 3 profils).
///
/// L'utilisateur saisit un code émis par l'admin (onglet Promotions) → on
/// valide / consomme via `/promo/check` + `/promo/redeem`. En cas de succès :
///   - abonnement offert  → crédité directement par le serveur (badges à jour) ;
///   - réduction %        → message + persistance locale pour la boutique.
///
/// [accent] colore le bouton et les accents pour coller au rôle (owner orange,
/// sitter bleu, walker vert).
class PromoCodeScreen extends StatefulWidget {
  const PromoCodeScreen({super.key, required this.accent});

  final Color accent;

  @override
  State<PromoCodeScreen> createState() => _PromoCodeScreenState();
}

class _PromoCodeScreenState extends State<PromoCodeScreen> {
  late final PromoController _controller;
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Instance dédiée à l'écran (pas de tag global), libérée à la fermeture.
    _controller = Get.put(PromoController(), tag: 'promo_screen');
  }

  @override
  void dispose() {
    _textController.dispose();
    Get.delete<PromoController>(tag: 'promo_screen');
    super.dispose();
  }

  Future<void> _onApply() async {
    FocusScope.of(context).unfocus();
    final ok = await _controller.redeem(_textController.text);
    if (!mounted) return;
    if (ok) {
      Get.snackbar(
        'promo_success_title'.tr,
        _successMessage(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: widget.accent,
        colorText: Colors.white,
        margin: EdgeInsets.all(12.w),
        duration: const Duration(seconds: 4),
      );
    }
  }

  String _successMessage() {
    final res = _controller.result.value;
    if (res == null) return 'promo_success_generic'.tr;
    if (res.isPercentDiscount) {
      return 'promo_success_discount'.trParams({'percent': '${res.discountPercent}'});
    }
    return 'promo_success_subscription'.trParams({'plan': _planLabel(res.plan)});
  }

  /// Libellé lisible du forfait offert (clés canoniques alignées sur l'admin).
  String _planLabel(String plan) {
    switch (plan) {
      case 'premium_monthly':
      case 'premium_yearly':
      case 'premium':
        return 'promo_plan_premium'.tr;
      case 'monthly':
      case 'yearly':
        return 'promo_plan_pawfollow'.tr;
      case 'family':
      case 'famille':
      case 'family_yearly':
        return 'promo_plan_pawfamily'.tr;
      case 'pawspot':
        return 'promo_plan_pawspot'.tr;
      case 'pawboost':
        return 'promo_plan_pawboost'.tr;
      default:
        return plan.isEmpty ? 'promo_plan_generic'.tr : plan;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.scaffold(context),
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary(context)),
        title: PoppinsText(
          text: 'promo_screen_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header illustration chip.
            Center(
              child: Container(
                width: 72.w,
                height: 72.w,
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Icon(
                  Icons.confirmation_number_rounded,
                  size: 36.sp,
                  color: widget.accent,
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Center(
              child: PoppinsText(
                text: 'promo_screen_heading'.tr,
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 6.h),
            Center(
              child: InterText(
                text: 'promo_screen_subtitle'.tr,
                fontSize: 13.sp,
                color: AppColors.textSecondary(context),
                textAlign: TextAlign.center,
                maxLines: 3,
              ),
            ),
            SizedBox(height: 24.h),

            // Code input.
            InterText(
              text: 'promo_field_label'.tr,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(context),
            ),
            SizedBox(height: 8.h),
            Obx(() {
              final hasError = _controller.status.value == PromoStatus.error;
              return TextField(
                controller: _textController,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                enabled: !_controller.isBusy,
                inputFormatters: [
                  // Codes émis : MAJUSCULES + tiret (ex. LANCEMENT-ABC123).
                  UpperCaseTextFormatter(),
                ],
                onChanged: (_) {
                  if (_controller.status.value == PromoStatus.error ||
                      _controller.status.value == PromoStatus.success) {
                    _controller.reset();
                  }
                },
                onSubmitted: (_) => _onApply(),
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: AppColors.textPrimary(context),
                ),
                decoration: InputDecoration(
                  hintText: 'promo_field_hint'.tr,
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary(context),
                    letterSpacing: 0.5,
                  ),
                  filled: true,
                  fillColor: AppColors.card(context),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide(
                      color: hasError ? Colors.red : AppColors.divider(context),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide(color: widget.accent, width: 1.6),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
              );
            }),

            // Error message.
            Obx(() {
              final msg = _controller.errorMessage.value;
              if (msg.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: EdgeInsets.only(top: 8.h, left: 4.w),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 16.sp, color: Colors.red),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: InterText(
                        text: msg,
                        fontSize: 12.sp,
                        color: Colors.red,
                        maxLines: 3,
                      ),
                    ),
                  ],
                ),
              );
            }),

            SizedBox(height: 20.h),

            // Apply button.
            Obx(() {
              final busy = _controller.isBusy;
              return CustomButton(
                bgColor: widget.accent,
                textColor: Colors.white,
                radius: 16.r,
                onTap: busy ? null : _onApply,
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
                    : PoppinsText(
                        text: 'promo_apply_button'.tr,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
              );
            }),

            SizedBox(height: 24.h),

            // Success reward card.
            Obx(() {
              final res = _controller.result.value;
              if (_controller.status.value != PromoStatus.success ||
                  res == null) {
                return const SizedBox.shrink();
              }
              return _rewardCard(context, res);
            }),
          ],
        ),
      ),
    );
  }

  Widget _rewardCard(BuildContext context, PromoResult res) {
    final detail = res.isPercentDiscount
        ? 'promo_success_discount'.trParams({'percent': '${res.discountPercent}'})
        : 'promo_success_subscription'.trParams({'plan': _planLabel(res.plan)});
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: widget.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: widget.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.celebration_rounded, size: 28.sp, color: widget.accent),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PoppinsText(
                  text: 'promo_success_title'.tr,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
                SizedBox(height: 4.h),
                InterText(
                  text: detail,
                  fontSize: 12.sp,
                  color: AppColors.textSecondary(context),
                  maxLines: 3,
                ),
                if (res.isPercentDiscount) ...[
                  SizedBox(height: 4.h),
                  InterText(
                    text: 'promo_success_discount_hint'.tr,
                    fontSize: 11.sp,
                    color: AppColors.textSecondary(context),
                    maxLines: 3,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Force la saisie en majuscules (codes émis en MAJUSCULES par l'admin).
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
