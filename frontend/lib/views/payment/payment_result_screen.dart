import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
              SizedBox(height: 60.h),

              // Icon
              Container(
                width: 120.w,
                height: 120.h,
                decoration: BoxDecoration(
                  color: isSuccess
                      ? Colors.green.withOpacity(0.1)
                      : AppColors.errorColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSuccess ? Icons.check_circle : Icons.error_outline,
                  size: 60.sp,
                  color: isSuccess ? Colors.green : AppColors.errorColor,
                ),
              ),

              SizedBox(height: 32.h),

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

              // Action Button
              CustomButton(
                title: isSuccess ? 'payment_rate_sitter'.tr : 'payment_try_again'.tr,
                onTap: () async {
                  if (isSuccess && booking != null) {
                    final sitterId = booking!.sitter.id;
                    final userController = Get.find<UserController>();

                    // If the user's profile is loaded and contains a review for this sitter,
                    // don't navigate to the review screen.
                    if (userController.profile.value == null) {
                      await userController.loadMyProfile();
                    }

                    final reviewsGiven =
                        userController.profile.value?.reviewsGiven ?? const [];
                    if (_alreadyReviewed(reviewsGiven, sitterId)) {
                      CustomSnackbar.showWarning(
                        title: 'review_already_reviewed_title'.tr,
                        message:
                            'snackbar_text_you_have_already_reviewed_this_sitter_you_can_only_submit_on',
                      );
                      return;
                    }

                    // Navigate to reviews screen
                    Get.off(
                      () => ReviewsScreen(
                        serviceProviderName: booking!.sitter.name,
                        phoneNumber: booking!.sitter.mobile,
                        email: booking!.sitter.email,
                        profileImagePath: booking!.sitter.avatar.url.isNotEmpty
                            ? booking!.sitter.avatar.url
                            : null,
                        serviceProviderId: booking!.sitter.id,
                      ),
                    );
                  } else if (isSuccess) {
                    // Fallback: Navigate back to home if no booking data
                    Get.until(
                      (route) =>
                          route.isFirst || route.settings.name == '/home',
                    );
                  } else {
                    // For failed payments, use custom onContinue or go back
                    onContinue ?? Get.back();
                  }
                },
                bgColor: AppColors.primaryColor,
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
