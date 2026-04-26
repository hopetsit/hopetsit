import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/stripe_payment_controller.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:intl/intl.dart';

/// v21.1.1 — Écran de paiement de réservation, pure Airwallex.
///
/// Stripe purgé. L'écran affiche le résumé de la réservation + un bouton
/// "Payer" qui ouvre le hosted payment page Airwallex (webview). C'est
/// Airwallex qui collecte les détails carte / billing — plus de CardFormField
/// inline, plus de saved cards (PaymentConsent à venir v22).
///
/// Le nom de classe `StripePaymentScreen` est conservé pour ne pas casser
/// les imports existants (notifications, owner_bookings, deep_link...).
class StripePaymentScreen extends StatefulWidget {
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

  @override
  State<StripePaymentScreen> createState() => _StripePaymentScreenState();
}

class _StripePaymentScreenState extends State<StripePaymentScreen> {
  late final StripePaymentController _controller;

  @override
  void initState() {
    super.initState();
    final tag = 'stripe_payment_${widget.booking.id}';
    if (Get.isRegistered<StripePaymentController>(tag: tag)) {
      Get.delete<StripePaymentController>(tag: tag);
    }
    _controller = Get.put(
      StripePaymentController(
        booking: widget.booking,
        totalAmount: widget.totalAmount,
        currency: widget.currency ??
            widget.booking.pricing?.currency ??
            widget.booking.sitter.currency,
      ),
      tag: tag,
    );
  }

  bool get _isWalker {
    final explicit = widget.providerType?.toLowerCase();
    if (explicit == 'walker') return true;
    if (explicit == 'sitter') return false;
    final s = (widget.booking.serviceType ?? '').toLowerCase();
    return s.contains('dog_walking') || s.contains('walking');
  }

  bool get _isSitter {
    final explicit = widget.providerType?.toLowerCase();
    if (explicit == 'sitter') return true;
    if (explicit == 'walker') return false;
    if (_isWalker) return false;
    final s = (widget.booking.serviceType ?? '').toLowerCase();
    return s.contains('sitting') ||
        s.contains('day_care') ||
        s.contains('boarding');
  }

  Color _accent() {
    if (_isWalker) return AppColors.walkerAccent;
    if (_isSitter) return AppColors.sitterAccent;
    return AppColors.primaryColor;
  }

  String _providerName() {
    final n = widget.booking.sitter.name;
    return n.isNotEmpty ? n : 'provider_unknown'.tr;
  }

  String _serviceLabel() {
    final raw = (widget.booking.serviceType ?? '').trim();
    if (raw.isEmpty) return '';
    final key = 'service_${raw.toLowerCase().replaceAll(' ', '_')}';
    final translated = key.tr;
    if (translated != key) return translated;
    return raw
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  String _formatDate(String raw, String lang) {
    if (raw.isEmpty) return '';
    if (raw.contains('T') || raw.contains('-')) {
      try {
        final dt = DateTime.parse(raw).toLocal();
        return DateFormat('EEE, d MMM y', lang).format(dt);
      } catch (_) {}
    }
    return raw;
  }

  String _formatTime(String raw, String lang) {
    if (raw.isEmpty) return '';
    if (raw.contains('T')) {
      try {
        final dt = DateTime.parse(raw).toLocal();
        final pattern = lang == 'en' ? 'h:mm a' : 'HH:mm';
        return DateFormat(pattern, lang).format(dt);
      } catch (_) {}
    }
    final m = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$',
            caseSensitive: false)
        .firstMatch(raw.trim());
    if (m != null) {
      int h = int.parse(m.group(1)!);
      final mm = int.parse(m.group(2)!);
      final ampm = m.group(3)?.toUpperCase();
      if (ampm == 'PM' && h < 12) h += 12;
      if (ampm == 'AM' && h == 12) h = 0;
      final dt = DateTime(0, 1, 1, h, mm);
      final pattern = lang == 'en' ? 'h:mm a' : 'HH:mm';
      return DateFormat(pattern, lang).format(dt);
    }
    return raw;
  }

  String _dateLabel() {
    final lang = Get.locale?.languageCode ?? 'fr';
    final date = _formatDate(widget.booking.date.trim(), lang);
    final time = _formatTime(widget.booking.timeSlot.trim(), lang);
    final duration = widget.booking.duration;
    final buf = StringBuffer();
    if (date.isNotEmpty) buf.write(date);
    if (time.isNotEmpty) {
      if (buf.isNotEmpty) buf.write(' · ');
      buf.write(time);
    }
    if (duration != null && duration > 0) {
      if (buf.isNotEmpty) buf.write(' · ');
      buf.write('${duration} min');
    }
    return buf.toString();
  }

  Future<void> _onPayTap() async {
    // v21.1.1 — Airwallex HPP collecte la carte directement dans son webview.
    // Plus besoin de billingDetails côté Flutter.
    await _controller.initiateAndConfirmPayment();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent();
    final currency = widget.currency ??
        widget.booking.pricing?.currency ??
        widget.booking.sitter.currency;

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
                    _buildSummaryCard(context, accent, currency),
                    SizedBox(height: 20.h),
                    _buildInfoBanner(context, accent),
                  ],
                ),
              ),
            ),
            // Sticky pay button at the bottom.
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
              child: Obx(() => CustomButton(
                    title: _controller.isProcessing.value
                        ? 'payment_processing'.tr
                        : '${'button_pay'.tr} ${CurrencyHelper.format(
                            currency,
                            widget.totalAmount,
                          )}',
                    onTap: _controller.isProcessing.value ? () {} : _onPayTap,
                    bgColor: accent,
                  )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, Color accent, String currency) {
    return Container(
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
              CircleAvatar(
                radius: 22.r,
                backgroundColor: accent.withValues(alpha: 0.15),
                child: Icon(Icons.person, color: accent, size: 22.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PoppinsText(
                      text: _providerName(),
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                    if (_serviceLabel().isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      InterText(
                        text: _serviceLabel(),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary(context),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Divider(color: AppColors.divider(context), height: 1),
          SizedBox(height: 14.h),
          if (_dateLabel().isNotEmpty) ...[
            _summaryRow(
              context,
              icon: Icons.event_outlined,
              label: 'payment_date_label'.tr,
              value: _dateLabel(),
            ),
            SizedBox(height: 10.h),
          ],
          if (widget.booking.petName.isNotEmpty) ...[
            _summaryRow(
              context,
              icon: Icons.pets,
              label: 'payment_pet_label'.tr,
              value: widget.booking.petName,
            ),
            SizedBox(height: 10.h),
          ],
          SizedBox(height: 4.h),
          Divider(color: AppColors.divider(context), height: 1),
          SizedBox(height: 14.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PoppinsText(
                text: 'payment_total_label'.tr,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
              PoppinsText(
                text: CurrencyHelper.format(currency, widget.totalAmount),
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18.sp, color: AppColors.textSecondary(context)),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InterText(
                text: label,
                fontSize: 11.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary(context),
              ),
              SizedBox(height: 1.h),
              PoppinsText(
                text: value,
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBanner(BuildContext context, Color accent) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: accent, size: 18.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: InterText(
              text: 'payment_secure_info'.tr,
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}
