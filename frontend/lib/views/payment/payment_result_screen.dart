import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/user_controller.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/views/reviews/reviews_screen.dart';

class PaymentResultScreen extends StatelessWidget {
  final bool isSuccess;
  final String? message;
  final String? transactionId;
  final double? amount;
  final String? currency;
  final VoidCallback? onContinue;
  final BookingModel? booking;

  const PaymentResultScreen({
    super.key,
    required this.isSuccess,
    this.message,
    this.transactionId,
    this.amount,
    this.currency,
    this.onContinue,
    this.booking,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 40.h),

              // v18.5 — #6 fix : HopeTSIT logo + success/error badge overlay.
              // Replaces the generic check_circle icon. The logo anchors the
              // page and feels on-brand. On failure we show the logo dimmed
              // with a red error badge instead of a green check.
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 140.w,
                    height: 140.h,
                    decoration: BoxDecoration(
                      color: isSuccess
                          ? Colors.green.withValues(alpha: 0.08)
                          : AppColors.errorColor.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    padding: EdgeInsets.all(20.w),
                    child: ColorFiltered(
                      colorFilter: isSuccess
                          ? const ColorFilter.mode(
                              Colors.transparent,
                              BlendMode.multiply,
                            )
                          : ColorFilter.matrix(const <double>[
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0, 0, 0, 1, 0,
                            ]),
                      child: SvgPicture.asset(
                        'assets/brand/web/logo-orange.svg',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 42.w,
                      height: 42.w,
                      decoration: BoxDecoration(
                        color: isSuccess
                            ? const Color(0xFF16A34A)
                            : AppColors.errorColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.scaffold(context),
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        isSuccess ? Icons.check_rounded : Icons.close_rounded,
                        size: 24.sp,
                        color: AppColors.whiteColor,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 24.h),

              // v18.5 — product name right under the logo so the success
              // feels like a branded confirmation, not a generic toast.
              PoppinsText(
                text: 'HoPetSit',
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryColor,
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 20.h),

              // Title
              PoppinsText(
                text: isSuccess ? 'payment_success_title'.tr : 'payment_failed_title'.tr,
                fontSize: 24.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 16.h),

              // Message
              if (message != null) ...[
                InterText(
                  text: message!,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary(context),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32.h),
              ],

              // Transaction Details Card
              if (isSuccess && (transactionId != null || amount != null))
                _buildTransactionDetailsCard(context),

              if (!isSuccess) SizedBox(height: 32.h),

              // v18.5 — #17 : on retire le bouton "Noter le pet sitter" de
              // l'écran paiement réussi car le service n'a pas encore eu
              // lieu à ce moment-là. L'avis sera proposé à l'utilisateur
              // sur l'écran "Mes réservations" quand le booking passe en
              // statut 'completed'. Sur l'écran paiement réussi on garde
              // juste "Retour à l'accueil" en succès et "Réessayer" en
              // échec — avec la couleur du rôle (vert walker / bleu sitter)
              // quand c'est un succès.
              CustomButton(
                title: isSuccess
                    ? 'common_back_to_home'.tr
                    : 'payment_try_again'.tr,
                onTap: () {
                  if (isSuccess) {
                    Get.until(
                      (route) =>
                          route.isFirst || route.settings.name == '/home',
                    );
                  } else {
                    onContinue ?? Get.back();
                  }
                },
                bgColor: isSuccess
                    ? _resolveAccentColor()
                    : AppColors.primaryColor,
                textColor: AppColors.whiteColor,
                height: 48.h,
                radius: 48.r,
                width: double.infinity,
              ),

              if (!isSuccess) ...[
                SizedBox(height: 16.h),
                // Back to Home Button
                CustomButton(
                  title: 'common_back_to_home'.tr,
                  onTap: () {
                    Get.until(
                      (route) =>
                          route.isFirst || route.settings.name == '/home',
                    );
                  },
                  bgColor: AppColors.whiteColor,
                  textColor: AppColors.primaryColor,
                  borderColor: AppColors.primaryColor,
                  height: 48.h,
                  radius: 48.r,
                  width: double.infinity,
                ),
              ],

              SizedBox(height: 40.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionDetailsCard(BuildContext context) {
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
            text: 'payment_transaction_details'.tr,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(context),
          ),
          SizedBox(height: 16.h),
          if (transactionId != null) ...[
            _buildDetailRow('payment_transaction_id_label'.tr, transactionId!, context),
            SizedBox(height: 12.h),
          ],
          if (amount != null) ...[
            _buildDetailRow(
              'payment_amount_label'.tr,
              _formatPrice(
                amount!,
                currency ??
                    booking?.pricing?.currency ??
                    booking?.sitter.currency ??
                    CurrencyHelper.eur,
              ),
              context,
            ),
            SizedBox(height: 12.h),
          ],
          _buildDetailRow('payment_date_label'.tr, _formatDate(DateTime.now()), context),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InterText(
          text: label,
          fontSize: 14.sp,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary(context),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: InterText(
              text: value,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary(context),
            ),
          ),
        ),
      ],
    );
  }

  String _formatPrice(double price, String currency) {
    return CurrencyHelper.format(currency, price);
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// v18.5 — #17 : resolve the role accent color (green for walker,
  /// blue for sitter, fallback primary). Used to color the "back to home"
  /// button on the payment success screen so it matches the role that was
  /// just paid.
  ///
  /// v18.9.8 — utilise les constantes centralisées AppColors (walkerAccent /
  /// sitterAccent) au lieu de Color(0xFF16A34A) / Color(0xFF2563EB) dupliqués.
  Color _resolveAccentColor() {
    if (booking == null) return AppColors.primaryColor;
    final service = (booking!.serviceType ?? '').toLowerCase();
    if (service.contains('dog_walking') || service.contains('walking')) {
      return AppColors.walkerAccent;
    }
    if (service.contains('sitting') ||
        service.contains('day_care') ||
        service.contains('boarding')) {
      return AppColors.sitterAccent;
    }
    return AppColors.primaryColor;
  }

  bool _alreadyReviewed(List<dynamic> reviewsGiven, String sitterId) {
    for (final review in reviewsGiven) {
      // Sometimes the API might return a list of ids.
      if (review is String && review == sitterId) {
        return true;
      }

      if (review is! Map) continue;

      // Common shapes:
      // - { revieweeId: "..." }
      // - { reviewee: "..." }
      // - { reviewee: { id: "..."} } or { reviewee: { _id: "..." } }
      final dynamic revieweeId =
          review['revieweeId'] ??
          review['reviewee'] ??
          (review['reviewee'] is Map ? (review['reviewee']['id']) : null) ??
          (review['reviewee'] is Map ? (review['reviewee']['_id']) : null);

      if (revieweeId is String && revieweeId == sitterId) {
        return true;
      }
    }
    return false;
  }
}
