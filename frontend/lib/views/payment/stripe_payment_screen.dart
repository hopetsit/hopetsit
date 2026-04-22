import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/stripe_payment_controller.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

/// v18.5 — #1/#2/#8 fix : UNIFIED payment screen.
///
/// Merged StripePaymentScreen (summary) + ModernCardPaymentScreen (card
/// form) into a single scrollable page. Before v18.5, tapping "Accepter
/// et payer" from a notification took the owner through 2 screens
/// (summary → card form) which felt laggy and double-tap heavy.
///
/// Now: 1 screen, 1 tap on "Pay €X.XX".
/// Role-coloured:
///   walker → green  (#16A34A)
///   sitter → blue   (#2563EB)
///   fallback → app primary
///
/// Provider type is taken from the [providerType] argument when supplied,
/// otherwise derived from `booking.serviceType`.
///
/// The card collection still goes through Stripe's `CardFormField` widget
/// so PCI compliance is preserved — only the visual shell is ours.
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
  // ── Role detection (same logic as owner_booking_detail_screen v16.3i) ─────
  static const Color _walkerAccent = Color(0xFF16A34A);
  static const Color _sitterAccent = Color(0xFF2563EB);

  // Card form state.
  CardFieldInputDetails? _cardDetails;
  final TextEditingController _holderNameCtrl = TextEditingController();
  final TextEditingController _holderEmailCtrl = TextEditingController();
  String _country = 'FR';

  // v18.5 — #19 saved card auto-populate
  // Si l'owner a une carte sauvegardée (via "Mes paiements"), on la propose
  // en haut du formulaire en radio. Sélection = payer avec pm_xxx sans
  // ressaisir le numéro. Tap "Utiliser une nouvelle carte" = révèle les
  // CardFormField + form holder.
  List<Map<String, dynamic>> _savedMethods = const [];
  String? _selectedSavedPmId; // null = nouvelle carte
  bool _loadingMethods = true;

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
    _loadSavedMethods();
  }

  /// v18.5 — #19 : fetch saved cards so the owner doesn't re-type.
  Future<void> _loadSavedMethods() async {
    try {
      final repo = Get.find<OwnerRepository>();
      final methods = await repo.getOwnerPaymentMethods();
      if (!mounted) return;
      setState(() {
        _savedMethods = methods;
        // Si au moins une carte, on présélectionne la 1re pour accélérer.
        if (methods.isNotEmpty) {
          _selectedSavedPmId = methods.first['id']?.toString();
        }
        _loadingMethods = false;
      });
    } catch (e) {
      AppLogger.logDebug('StripePaymentScreen: load saved methods failed: $e');
      if (mounted) setState(() => _loadingMethods = false);
    }
  }

  @override
  void dispose() {
    _holderNameCtrl.dispose();
    _holderEmailCtrl.dispose();
    super.dispose();
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
    if (_isWalker) return _walkerAccent;
    if (_isSitter) return _sitterAccent;
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

  String _dateLabel() {
    final date = widget.booking.date.trim();
    final time = widget.booking.timeSlot.trim();
    final duration = widget.booking.duration;
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

  Future<void> _onPayTap() async {
    // v18.5 — #19 : 2 routes possibles au moment du paiement.
    // (A) Saved card sélectionnée → confirmPayment avec payment_method=pm_id
    //     (pas de CardFormField, pas de holder name obligatoire).
    // (B) Nouvelle carte → flow CardFormField comme avant.
    if (_selectedSavedPmId != null && _selectedSavedPmId!.isNotEmpty) {
      await _controller.initiateAndConfirmPaymentWithSavedMethod(
        paymentMethodId: _selectedSavedPmId!,
      );
      return;
    }

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

    final billingDetails = BillingDetails(
      name: _holderNameCtrl.text.trim(),
      email: _holderEmailCtrl.text.trim().isEmpty
          ? null
          : _holderEmailCtrl.text.trim(),
      address: Address(
        country: _country,
        city: null,
        line1: null,
        line2: null,
        postalCode: null,
        state: null,
      ),
    );

    await _controller.initiateAndConfirmPayment(billingDetails: billingDetails);
  }

  @override
  Widget build(BuildContext context) {
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
                    if (_savedMethods.isNotEmpty) ...[
                      _buildSavedCardsSection(context, accent),
                      SizedBox(height: 16.h),
                    ],
                    // La section carte inline n'apparaît que si l'user
                    // choisit "Nouvelle carte" (ou n'a aucune carte).
                    if (_selectedSavedPmId == null)
                      _buildCardFormSection(context, accent),
                    if (_selectedSavedPmId == null) SizedBox(height: 16.h),
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
                        onTap: !_controller.isProcessing.value
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
                        title: _controller.isProcessing.value
                            ? null
                            : 'payment_pay_button'.tr.replaceAll(
                                '@amount',
                                _formatPrice(
                                  widget.totalAmount,
                                  _controller.currency,
                                ),
                              ),
                        onTap: !_controller.isProcessing.value
                            ? _onPayTap
                            : null,
                        bgColor: _controller.isProcessing.value
                            ? accent.withValues(alpha: 0.7)
                            : accent,
                        textColor: AppColors.whiteColor,
                        height: 48.h,
                        radius: 48.r,
                        child: _controller.isProcessing.value
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
              widget.totalAmount,
              widget.currency ??
                  widget.booking.pricing?.currency ??
                  widget.booking.sitter.currency,
            ),
            fontSize: 26.sp,
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ],
      ),
    );
  }

  /// v18.5 — #19 : section "Cartes enregistrées" au-dessus du CardFormField.
  /// Permet à l'owner de payer en 1 tap avec une carte déjà sauvegardée via
  /// "Mes paiements", sans ressaisir le numéro.
  Widget _buildSavedCardsSection(BuildContext context, Color accent) {
    return Container(
      padding: EdgeInsets.all(14.w),
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
              Icon(Icons.credit_card_rounded, size: 20.sp, color: accent),
              SizedBox(width: 8.w),
              PoppinsText(
                text: 'payment_saved_cards_title'.tr,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          for (final m in _savedMethods) _buildSavedCardOption(m, accent),
          Divider(color: AppColors.grey300Color, height: 20.h),
          GestureDetector(
            onTap: () {
              setState(() => _selectedSavedPmId = null);
            },
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
              child: Row(
                children: [
                  Radio<String?>(
                    value: null,
                    groupValue: _selectedSavedPmId,
                    onChanged: (v) =>
                        setState(() => _selectedSavedPmId = null),
                    activeColor: accent,
                  ),
                  SizedBox(width: 4.w),
                  Icon(Icons.add_card_outlined, size: 18.sp, color: accent),
                  SizedBox(width: 8.w),
                  InterText(
                    text: 'payment_use_new_card'.tr,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedCardOption(Map<String, dynamic> method, Color accent) {
    // v18.5 — #19 : le backend listOwnerPaymentMethods renvoie les champs
    // à plat : {id, brand, last4, expMonth, expYear, holder}. Pas de
    // nested `card`. Si la forme change, les fallbacks vides évitent
    // un crash UI.
    final id = method['id']?.toString() ?? '';
    final brand = (method['brand'] ?? '').toString().toUpperCase();
    final last4 = (method['last4'] ?? '').toString();
    final expMonth = (method['expMonth'] ?? '').toString();
    final expYear = (method['expYear'] ?? '').toString();
    final expLabel = (expMonth.isNotEmpty && expYear.isNotEmpty)
        ? ' — $expMonth/${expYear.length >= 2 ? expYear.substring(expYear.length - 2) : expYear}'
        : '';
    final label = '${brand.isNotEmpty ? brand : "CARD"} •••• $last4$expLabel';

    return GestureDetector(
      onTap: () => setState(() => _selectedSavedPmId = id),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
        child: Row(
          children: [
            Radio<String?>(
              value: id,
              groupValue: _selectedSavedPmId,
              onChanged: (v) => setState(() => _selectedSavedPmId = v),
              activeColor: accent,
            ),
            SizedBox(width: 4.w),
            Icon(Icons.credit_card, size: 18.sp, color: accent),
            SizedBox(width: 8.w),
            Expanded(
              child: InterText(
                text: label,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// v18.5 — card collection inline (Stripe CardFormField + cardholder
  /// details). Replaces the old ModernCardPaymentScreen detour.
  Widget _buildCardFormSection(BuildContext context, Color accent) {
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
              Icon(Icons.credit_card_rounded, size: 20.sp, color: accent),
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
          // Stripe CardFormField — PCI-compliant, card stays in Stripe's
          // sandbox, we just render the chrome around it.
          CardFormField(
            style: CardFormStyle(
              borderColor: accent.withValues(alpha: 0.25),
              borderRadius: 12,
              borderWidth: 1,
              textColor: AppColors.textPrimary(context),
              placeholderColor: AppColors.textSecondary(context),
              backgroundColor: AppColors.scaffold(context),
              fontSize: 14,
            ),
            onCardChanged: (details) {
              setState(() => _cardDetails = details);
            },
          ),
          SizedBox(height: 14.h),
          // Cardholder name
          TextField(
            controller: _holderNameCtrl,
            decoration: InputDecoration(
              labelText: 'payment_cardholder_name'.tr,
              prefixIcon: Icon(Icons.person_outline, color: accent),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            textInputAction: TextInputAction.next,
          ),
          SizedBox(height: 10.h),
          // Cardholder email (optional)
          TextField(
            controller: _holderEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'payment_cardholder_email_optional'.tr,
              prefixIcon: Icon(Icons.mail_outline, color: accent),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            textInputAction: TextInputAction.done,
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
          Icon(Icons.lock_outline, size: 20.sp, color: accent),
          SizedBox(width: 12.w),
          Expanded(
            child: InterText(
              text: 'payment_stripe_info'.tr,
              fontSize: 13.sp,
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
