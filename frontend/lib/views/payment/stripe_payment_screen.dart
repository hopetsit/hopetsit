import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/stripe_payment_controller.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

/// Stripe payment screen for booking payments.
///
/// Session v17 — coloured by provider role:
///   walker  → green  (#16A34A)
///   sitter  → blue   (#2563EB)
///   fallback → app primary
///
/// Provider type is taken from the [providerType] argument when supplied,
/// otherwise derived from `booking.serviceType` (same heuristic as
/// owner_booking_detail_screen.dart). Caller should pass it explicitly when
/// known so that legacy bookings without serviceType still render correctly.
///
/// Now also displays the provider name, service label, and date range so
/// the owner sees exactly what they are about to pay for.
class StripePaymentScreen extends StatelessWidget {
  final BookingModel booking;
  final double totalAmount;
  final String? currency;

  /// Optional explicit provider type ('walker' or 'sitter'). When null, the
  /// type is inferred from `booking.serviceType`.
  final String? providerType;

  const StripePaymentScreen({
    super.key,
    required this.booking,
    required this.totalAmount,
    this.currency,
    this.providerType,
  });

  // ── Role detection (same logic as owner_booking_detail_screen v16.3i) ─────
  static const Color _walkerAccent = Color(0xFF16A34A);
  static const Color _sitterAccent = Color(0xFF2563EB);

  bool get _isWalker {
    final explicit = providerType?.toLowerCase();
    if (explicit == 'walker') return true;
    if (explicit == 'sitter') return false;
    final s = (booking.serviceType ?? '').toLowerCase();
    return s.contains('dog_walking') || s.contains('walking');
  }

  bool get _isSitter {
    final explicit = providerType?.toLowerCase();
    if (explicit == 'sitter') return true;
    if (explicit == 'walker') return false;
    if (_isWalker) return false;
    final s = (booking.serviceType ?? '').toLowerCase();
    return s.contains('sitting') ||
        s.contains('day_care') ||
        s.contains('boarding');
  }

  Color _accent() {
    if (_isWalker) return _walkerAccent;
    if (_isSitter) return _sitterAccent;
    return AppColors.primaryColor;
  }

  String _providerName() {
    final n = booking.sitter.name;
    return n.isNotEmpty ? n : 'provider_unknown'.tr;
  }

  String _serviceLabel() {
    final raw = (booking.serviceType ?? '').trim();
    if (raw.isEmpty) return '';
    // Try a translation key first ("service_dog_walking", "service_house_sitting"…)
    final key = 'service_${raw.toLowerCase().replaceAll(' ', '_')}';
    final translated = key.tr;
    if (translated != key) return translated;
    // Fallback: humanise the raw string ("dog_walking" → "Dog walking").
    return raw
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  String _dateLabel() {
    // booking.date is required ("YYYY-MM-DD"). timeSlot is "HH:mm"-ish.
    // We render: "30 Apr 2026 · 14h00" for single-day,
    // and append the duration if it is set.
    final date = booking.date.trim();
    final time = booking.timeSlot.trim();
    final duration = booking.duration;
    final buf = StringBuffer();
    if (date.isNotEmpty) buf.write(date);
    if (time.isNotEmpty) {
      if (buf.isNotEmpty) buf.write(' · ');
      buf.write(time);
    }
    if (duration != null && duration > 0) {
      if (buf.isNotEmpty) buf.write(' · ');
      buf.write('${duration}min');
    }
    return buf.toString();
  }

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

    final accent = _accent();

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
                    _buildSummaryCard(context, accent),
                    SizedBox(height: 20.h),
                    _buildInfoBanner(context, accent),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
              child: Row(
                children: [
                  // Cancel (red) — left
                  Expanded(
                    child: Obx(
                      () => CustomButton(
                        title: 'common_cancel'.tr,
                        onTap: !controller.isProcessing.value
                            ? () => Get.back()
                            : null,
                        bgColor: const Color(0xFFEF4444),
                        textColor: AppColors.whiteColor,
                        height: 48.h,
                        radius: 48.r,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  // Pay (role-coloured) — right
                  Expanded(
                    flex: 2,
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
                            ? accent.withValues(alpha: 0.7)
                            : accent,
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
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, Color accent) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.2),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Provider name + role chip
          Row(
            children: [
              Expanded(
                child: PoppinsText(
                  text: _providerName(),
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: InterText(
                  text: _isWalker
                      ? 'role_walker'.tr
                      : _isSitter
                          ? 'role_sitter'.tr
                          : 'role_provider'.tr,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ],
          ),
          if (_serviceLabel().isNotEmpty) ...[
            SizedBox(height: 6.h),
            InterText(
              text: _serviceLabel(),
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary(context),
            ),
          ],
          if (_dateLabel().isNotEmpty) ...[
            SizedBox(height: 4.h),
            Row(
              children: [
                Icon(Icons.event, size: 16.sp, color: AppColors.textSecondary(context)),
                SizedBox(width: 6.w),
                InterText(
                  text: _dateLabel(),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary(context),
                ),
              ],
            ),
          ],
          SizedBox(height: 18.h),
          Divider(color: accent.withValues(alpha: 0.2), height: 1),
          SizedBox(height: 14.h),
          PoppinsText(
            text: 'payment_amount_label'.tr,
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary(context),
          ),
          SizedBox(height: 6.h),
          PoppinsText(
            text: _formatPrice(
              totalAmount,
              currency ??
                  booking.pricing?.currency ??
                  booking.sitter.currency,
            ),
            fontSize: 26.sp,
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner(BuildContext context, Color accent) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20.sp, color: accent),
          SizedBox(width: 12.w),
          Expanded(
            child: InterText(
              text: 'payment_stripe_info'.tr,
              fontSize: 14.sp,
              color: accent,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price, String currency) {
    return CurrencyHelper.format(currency, price);
  }
}
