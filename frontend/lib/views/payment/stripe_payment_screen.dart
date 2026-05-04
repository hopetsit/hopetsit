import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/stripe_payment_controller.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
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
  // v23.1 — "Save my card" checkbox state.
  final RxBool _saveCard = false.obs;
  // v23.1 part 39 — saved cards loaded from /owner/payments/methods
  final RxList<Map<String, dynamic>> _savedCards = <Map<String, dynamic>>[].obs;
  final RxnString _selectedCardId = RxnString();
  final RxBool _loadingCards = false.obs;

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
    // v23.1 part 39 — charge les saved cards au mount.
    _loadSavedCards();
  }

  Future<void> _loadSavedCards() async {
    _loadingCards.value = true;
    try {
      final repo = Get.find<OwnerRepository>();
      final cards = await repo.getOwnerPaymentMethods();
      _savedCards.assignAll(cards);
    } catch (_) {
      _savedCards.clear();
    } finally {
      _loadingCards.value = false;
    }
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

  Future<void> _onCancelTap() async {
    try {
      final repo = Get.find<OwnerRepository>();
      await repo.cancelPaymentIntent(bookingId: widget.booking.id);
    } catch (_) {
      // Soft-fail — even if the cancel call errors, we still pop the screen.
      // The PI will expire on Airwallex side anyway.
    }
    if (mounted) Get.back();
  }

  Future<void> _onPayTap() async {
    // v21.1.1 — Airwallex HPP collecte la carte directement dans son webview.
    // Plus besoin de billingDetails côté Flutter.
    // v23.1 — pass saveCard checkbox state for payment_consent attach.
    await _controller.initiateAndConfirmPayment(saveCard: _saveCard.value);
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
                    // v23.1 part 39 — Section "Mes cartes enregistrées" si > 0.
                    _buildSavedCardsSection(context, accent),
                    _buildInfoBanner(context, accent),
                  ],
                ),
              ),
            ),
            // Sticky pay + cancel buttons at the bottom.
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // v23.1 — "Save my card" checkbox above the pay button.
                  Obx(() => InkWell(
                        onTap: _controller.isProcessing.value
                            ? null
                            : () => _saveCard.value = !_saveCard.value,
                        borderRadius: BorderRadius.circular(8.r),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 4.w, vertical: 6.h),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 22.w,
                                height: 22.w,
                                child: Checkbox(
                                  value: _saveCard.value,
                                  onChanged: _controller.isProcessing.value
                                      ? null
                                      : (v) =>
                                          _saveCard.value = v ?? false,
                                  activeColor: accent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(4.r),
                                  ),
                                ),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    InterText(
                                      text: 'payment_save_card_label'.tr,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary(context),
                                    ),
                                    SizedBox(height: 2.h),
                                    InterText(
                                      text:
                                          'payment_save_card_subtitle'.tr,
                                      fontSize: 11.sp,
                                      color: AppColors.textSecondary(context),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),
                  SizedBox(height: 8.h),
                  Obx(() => CustomButton(
                        title: _controller.isProcessing.value
                            ? 'payment_processing'.tr
                            : '${'button_pay'.tr} ${CurrencyHelper.format(
                                currency,
                                widget.totalAmount,
                              )}',
                        onTap: _controller.isProcessing.value ? () {} : _onPayTap,
                        bgColor: accent,
                      )),
                  SizedBox(height: 10.h),
                  // v23.1 — explicit Cancel button.
                  // Calls cancel-payment-intent backend so Airwallex PI is
                  // properly voided + booking marked cancelled_by_user.
                  Obx(() => TextButton(
                        onPressed: _controller.isProcessing.value
                            ? null
                            : () => _onCancelTap(),
                        child: Text(
                          'common_cancel'.tr,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: _controller.isProcessing.value
                                ? Colors.grey
                                : accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )),
                ],
              ),
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

  /// v23.1 part 39 — Liste les cartes sauvegardées du user. Si vide, retourne
  /// SizedBox. Si présente, permet de tap sur une carte pour la pré-sélectionner
  /// (elle sera utilisée par défaut sur l'HPP Airwallex).
  Widget _buildSavedCardsSection(BuildContext context, Color accent) {
    return Obx(() {
      if (_loadingCards.value) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: const Center(child: CircularProgressIndicator()),
        );
      }
      if (_savedCards.isEmpty) {
        return const SizedBox.shrink();
      }
      return Container(
        margin: EdgeInsets.only(bottom: 20.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.appBar(context),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: accent.withValues(alpha: 0.20), width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.credit_card_rounded, color: accent, size: 20.sp),
                SizedBox(width: 8.w),
                PoppinsText(
                  text: 'Mes cartes enregistrées (${_savedCards.length})',
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            ..._savedCards.map((card) => _buildSavedCardTile(card, accent)),
            SizedBox(height: 8.h),
            InkWell(
              onTap: () => _selectedCardId.value = null,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 4.w),
                child: Row(
                  children: [
                    Obx(() => Icon(
                          _selectedCardId.value == null
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: accent, size: 20.sp,
                        )),
                    SizedBox(width: 10.w),
                    InterText(
                      text: 'Payer avec une nouvelle carte',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSavedCardTile(Map<String, dynamic> card, Color accent) {
    final brand = (card['brand'] ?? '').toString().toUpperCase();
    final last4 = (card['last4'] ?? '').toString();
    final expM = card['expiryMonth'];
    final expY = card['expiryYear'];
    final id = (card['id'] ?? '').toString();
    return Obx(() {
      final isSelected = _selectedCardId.value == id;
      return InkWell(
        onTap: () => _selectedCardId.value = id,
        child: Container(
          margin: EdgeInsets.only(bottom: 6.h),
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: 0.10)
                : AppColors.scaffold(context),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: isSelected
                  ? accent
                  : AppColors.divider(context),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: accent,
                size: 20.sp,
              ),
              SizedBox(width: 10.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.scaffold(context),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  brand.isNotEmpty ? brand : 'CARD',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InterText(
                      text: '•••• •••• •••• $last4',
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    if (expM != null && expY != null)
                      InterText(
                        text: 'Exp $expM/$expY',
                        fontSize: 10.sp,
                        color: AppColors.textSecondary(context),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
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
