import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/booking_date_format.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/views/payment/stripe_payment_screen.dart';
import 'package:hopetsit/views/payment/paypal_payment_screen.dart';
import 'package:hopetsit/utils/app_constants.dart';
import 'package:hopetsit/controllers/loyalty_controller.dart';

class BookingAgreementScreen extends StatefulWidget {
  final BookingModel booking;
  final double? totalPrice; // Optional: if not provided, will fetch from API

  const BookingAgreementScreen({
    super.key,
    required this.booking,
    this.totalPrice,
  });

  @override
  State<BookingAgreementScreen> createState() => _BookingAgreementScreenState();
}

class _BookingAgreementScreenState extends State<BookingAgreementScreen> {
  final OwnerRepository _ownerRepository = Get.find<OwnerRepository>();
  bool _isLoading = false;
  double? _basePrice;
  double? _platformFee;
  double? _finalTotal;
  String? _currency;
  String? _agreementStartDate;
  String? _agreementEndDate;
  String? _agreementHouseSittingVenue;

  /// Walk duration from agreement API (minutes: 30 or 60).
  int? _agreementDurationMinutes;

  /// Parsed from agreement GET (includes tier, applied rate, hours/days).
  BookingPricing? _agreementPricing;

  @override
  void initState() {
    super.initState();
    _loadBookingAgreement();
  }

  Future<void> _loadBookingAgreement() async {
    // Use provided totalPrice if available
    if (widget.totalPrice != null) {
      _agreementPricing = widget.booking.pricing;
      _basePrice =
          widget.booking.pricing?.basePrice ??
          widget.booking.pricing?.resolvedBaseAmount ??
          widget.booking.basePrice ??
          widget.totalPrice;
      _platformFee =
          widget.booking.pricing?.platformFee ??
          _calculatePlatformFee(_basePrice!);
      _finalTotal =
          widget.booking.pricing?.totalPrice ??
          widget.booking.totalAmount ??
          _calculateFinalTotal(_basePrice!, _platformFee!);
      _currency =
          widget.booking.pricing?.currency ?? widget.booking.sitter.currency;
      _agreementStartDate = null;
      _agreementEndDate = null;
      _agreementDurationMinutes = null;
      _agreementHouseSittingVenue = widget.booking.houseSittingVenue;
      return;
    }

    // Otherwise fetch from API
    setState(() => _isLoading = true);
    try {
      final response = await _ownerRepository.getBookingAgreement(
        bookingId: widget.booking.id,
      );

      // API returns { "agreement": { "pricing": { ... } } } - extract nested data
      final agreementData =
          response['agreement'] as Map<String, dynamic>? ?? response;
      final pricing =
          agreementData['pricing'] as Map<String, dynamic>? ?? agreementData;

      _basePrice =
          (pricing['basePrice'] as num?)?.toDouble() ??
          (pricing['base_price'] as num?)?.toDouble() ??
          (agreementData['basePrice'] as num?)?.toDouble() ??
          (agreementData['base_price'] as num?)?.toDouble() ??
          widget.booking.pricing?.basePrice ??
          widget.booking.basePrice ??
          widget.booking.sitter.hourlyRate;

      _platformFee =
          (pricing['platformFee'] as num?)?.toDouble() ??
          (pricing['platform_fee'] as num?)?.toDouble() ??
          (agreementData['platformFee'] as num?)?.toDouble() ??
          (agreementData['platform_fee'] as num?)?.toDouble() ??
          widget.booking.pricing?.platformFee ??
          _calculatePlatformFee(_basePrice ?? 0);

      _finalTotal =
          (pricing['totalPrice'] as num?)?.toDouble() ??
          (pricing['finalTotal'] as num?)?.toDouble() ??
          (pricing['total_price'] as num?)?.toDouble() ??
          (agreementData['totalAmount'] as num?)?.toDouble() ??
          (agreementData['total_amount'] as num?)?.toDouble() ??
          widget.booking.pricing?.totalPrice ??
          widget.booking.totalAmount ??
          _calculateFinalTotal(_basePrice ?? 0, _platformFee ?? 0);

      _currency =
          pricing['currency'] as String? ??
          agreementData['currency'] as String? ??
          widget.booking.pricing?.currency ??
          widget.booking.sitter.currency;
      _agreementStartDate =
          agreementData['startDate'] as String? ??
          agreementData['start_date'] as String?;
      _agreementEndDate =
          agreementData['endDate'] as String? ??
          agreementData['end_date'] as String?;
      _agreementHouseSittingVenue =
          agreementData['houseSittingVenue'] as String? ??
          agreementData['house_sitting_venue'] as String? ??
          widget.booking.houseSittingVenue;
      _agreementDurationMinutes = (agreementData['duration'] as num?)?.toInt();

      _agreementPricing = BookingPricing.fromJson(pricing);

      if (_basePrice == null || _basePrice! <= 0) {
        final fb =
            _agreementPricing?.resolvedBaseAmount ??
            widget.booking.pricing?.resolvedBaseAmount ??
            widget.booking.sitter.hourlyRate;
        if (fb > 0) {
          _basePrice = fb;
          _platformFee = _calculatePlatformFee(_basePrice!);
          _finalTotal = _calculateFinalTotal(_basePrice!, _platformFee!);
        }
      }
    } on ApiException catch (e) {
      // v18.9.1 — plus de popup rouge "Impossible de charger les details de
      // reservation" quand le fallback pricing fonctionne déjà. L'erreur est
      // loggée, l'utilisateur voit le prix correct (booking.pricing),
      // inutile de polluer l'UI avec un snackbar.
      AppLogger.logError(
        'Failed to refresh booking agreement — silent fallback to booking.pricing',
        error: e,
      );
      _basePrice =
          widget.booking.pricing?.basePrice ??
          widget.booking.pricing?.resolvedBaseAmount ??
          widget.booking.basePrice ??
          widget.booking.sitter.hourlyRate;
      _platformFee =
          widget.booking.pricing?.platformFee ??
          _calculatePlatformFee(_basePrice!);
      _finalTotal =
          widget.booking.pricing?.totalPrice ??
          widget.booking.totalAmount ??
          _calculateFinalTotal(_basePrice!, _platformFee!);
      _currency =
          widget.booking.pricing?.currency ?? widget.booking.sitter.currency;
      _agreementStartDate = null;
      _agreementEndDate = null;
      _agreementDurationMinutes = null;
      _agreementHouseSittingVenue = widget.booking.houseSittingVenue;
    } catch (e) {
      AppLogger.logError('Failed to load booking agreement', error: e);
      _basePrice =
          widget.booking.pricing?.basePrice ??
          widget.booking.pricing?.resolvedBaseAmount ??
          widget.booking.basePrice ??
          widget.booking.sitter.hourlyRate;
      _platformFee =
          widget.booking.pricing?.platformFee ??
          _calculatePlatformFee(_basePrice!);
      _finalTotal =
          widget.booking.pricing?.totalPrice ??
          widget.booking.totalAmount ??
          _calculateFinalTotal(_basePrice!, _platformFee!);
      _currency =
          widget.booking.pricing?.currency ?? widget.booking.sitter.currency;
      _agreementStartDate = null;
      _agreementEndDate = null;
      _agreementDurationMinutes = null;
      _agreementHouseSittingVenue = widget.booking.houseSittingVenue;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Agreement API and booking model both use minutes for dog walking (30/60).
  int? get _durationMinutesForDisplay {
    final v = _agreementDurationMinutes ?? widget.booking.duration;
    if (v == null || v <= 0) return null;
    return v;
  }

  double _calculatePlatformFee(double total) {
    return total * 0.20; // 20% platform fee
  }

  double _calculateFinalTotal(double total, double platformFee) {
    return total + platformFee;
  }

  @override
  Widget build(BuildContext context) {
    final baseTotal =
        _basePrice ??
        widget.booking.pricing?.resolvedBaseAmount ??
        widget.booking.sitter.hourlyRate;

    final platformFee = _platformFee ?? _calculatePlatformFee(baseTotal);
    final finalTotal =
        _finalTotal ?? _calculateFinalTotal(baseTotal, platformFee);

    final bookingStatus = widget.booking.status.toLowerCase();
    final paymentStatus = widget.booking.paymentStatus?.toLowerCase() ?? '';

    // Show pay button if:
    // 1. Booking status is 'agreed' or 'confirmed'
    // 2. Payment status is null, empty, 'pending', or 'failed'
    final shouldShowPayButton =
        (bookingStatus == 'agreed' ||
            bookingStatus == 'accepted' ||
            bookingStatus == 'confirmed') &&
        (paymentStatus.isEmpty ||
            paymentStatus == 'pending' ||
            paymentStatus == 'failed');

    // Show payment completed if payment status is 'paid'
    final isPaymentCompleted = paymentStatus == 'paid';

    // Show cancelled status if booking is cancelled
    final isCancelled = bookingStatus == 'cancelled';

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        leading: BackButton(),
        title: PoppinsText(
          text: 'booking_agreement_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryColor,
                ),
              ),
            )
          : SingleChildScrollView(
              // Extra bottom padding so the Pay button never sits under the
              // system navigation gesture bar on devices with no physical nav.
              padding: EdgeInsets.fromLTRB(
                20.w,
                20.h,
                20.w,
                40.h + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Badge
                  _buildStatusBadge(),
                  SizedBox(height: 24.h),

                  // Booking Details Card
                  _buildBookingDetailsCard(),
                  SizedBox(height: 24.h),

                  // Price Breakdown Card
                  _buildPriceBreakdownCard(baseTotal, platformFee, finalTotal),
                  SizedBox(height: 40.h),

                  // Pay Buttons - Only show if booking is agreed and payment is pending
                  if (shouldShowPayButton)
                    Column(
                      children: [
                        // Sprint 7 step 1 — loyalty discount checkbox.
                        Builder(
                          builder: (context) {
                            final ctrl = Get.isRegistered<LoyaltyController>()
                                ? Get.find<LoyaltyController>()
                                : Get.put(LoyaltyController());
                            return Obx(() {
                              if (!ctrl.hasDiscountAvailable.value) return const SizedBox.shrink();
                              return CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: ctrl.useLoyaltyCreditForNextPayment.value,
                                onChanged: (v) => ctrl.useLoyaltyCreditForNextPayment.value = v ?? false,
                                title: Text('loyalty_use_credit'.tr),
                                controlAffinity: ListTileControlAffinity.leading,
                              );
                            });
                          },
                        ),
                        CustomButton(
                          title: 'payment_pay_with_stripe'.tr.replaceAll(
                            '@amount',
                            CurrencyHelper.format(
                              _currency ??
                                  widget.booking.pricing?.currency ??
                                  widget.booking.sitter.currency,
                              finalTotal,
                            ),
                          ),
                          // Session v16.3b — if status is still 'accepted',
                          // transition it to 'agreed' before opening the
                          // Stripe sheet. Backend rejects payment intents
                          // on non-'agreed' bookings, which left owners
                          // stuck in a deadlock.
                          onTap: () async {
                            await _agreeAndPayWithStripe(finalTotal);
                          },
                          bgColor: AppColors.primaryColor,
                          textColor: AppColors.whiteColor,
                          height: 48.h,
                          radius: 48.r,
                        ),
                        if (AppConstants.showPayPalOption) ...[
                          SizedBox(height: 12.h),
                          CustomButton(
                            title: 'payment_pay_with_paypal'.tr.replaceAll(
                              '@amount',
                              CurrencyHelper.format(
                                _currency ??
                                    widget.booking.pricing?.currency ??
                                    widget.booking.sitter.currency,
                                finalTotal,
                              ),
                            ),
                            // Session v16.3b — see Stripe onTap comment.
                            onTap: () async {
                              await _agreeAndPayWithPaypal(finalTotal);
                            },
                            bgColor: AppColors.whiteColor,
                            textColor: AppColors.grey700Color,
                            borderColor: AppColors.grey300Color,
                            height: 48.h,
                            radius: 48.r,
                          ),
                        ],
                      ],
                    )
                  else if (isPaymentCompleted)
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.green, width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20.sp,
                          ),
                          SizedBox(width: 8.w),
                          PoppinsText(
                            text: 'booking_agreement_payment_completed'.tr,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                          ),
                        ],
                      ),
                    )
                  else if (isCancelled)
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: AppColors.greyColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: AppColors.greyColor,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cancel,
                            color: AppColors.greyColor,
                            size: 20.sp,
                          ),
                          SizedBox(width: 8.w),
                          PoppinsText(
                            text: 'booking_agreement_booking_cancelled'.tr,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.greyColor,
                          ),
                        ],
                      ),
                    )
                  else
                    // Default case - show booking status
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: AppColors.primaryColor,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info,
                            color: AppColors.primaryColor,
                            size: 20.sp,
                          ),
                          SizedBox(width: 8.w),
                          PoppinsText(
                            text: 'booking_agreement_status_label'.trParams({
                              'status': widget.booking.status.toUpperCase(),
                            }),
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryColor,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  /// Session v16.3b — owner agrees to booking (if needed) then opens
  /// the Stripe payment sheet. Wrapping the Pay button removes the need
  /// for a separate "Agree" UI while still calling the required backend
  /// transition `accepted -> agreed`.
  Future<void> _agreeAndPayWithStripe(double finalTotal) async {
    final status = widget.booking.status.toLowerCase();
    if (status == 'accepted') {
      final ok = await _ensureAgreed();
      if (!ok) return;
    }
    if (!mounted) return;
    Get.to(
      () => StripePaymentScreen(
        booking: widget.booking,
        totalAmount: finalTotal,
        currency: _currency ??
            widget.booking.pricing?.currency ??
            widget.booking.sitter.currency,
      ),
    );
  }

  /// Session v16.3b — symmetric helper for the PayPal path.
  Future<void> _agreeAndPayWithPaypal(double finalTotal) async {
    final status = widget.booking.status.toLowerCase();
    if (status == 'accepted') {
      final ok = await _ensureAgreed();
      if (!ok) return;
    }
    if (!mounted) return;
    Get.to(
      () => PayPalPaymentScreen(
        booking: widget.booking,
        totalAmount: finalTotal,
        currency: _currency ??
            widget.booking.pricing?.currency ??
            widget.booking.sitter.currency,
      ),
    );
  }

  /// Calls PUT /bookings/:id/agree. Returns true on success.
  /// Mutates widget.booking.status to 'agreed' locally so the UI reflects
  /// the new state immediately if the user comes back before a refresh.
  Future<bool> _ensureAgreed() async {
    try {
      setState(() => _isLoading = true);
      await _ownerRepository.agreeToBooking(bookingId: widget.booking.id);
      widget.booking.status = 'agreed';
      return true;
    } on ApiException catch (e) {
      AppLogger.logError('Failed to agree before payment', error: e.message);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.message.isNotEmpty ? e.message : 'common_error_generic'.tr,
      );
      return false;
    } catch (e) {
      AppLogger.logError('Failed to agree before payment', error: e);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'common_error_generic'.tr,
      );
      return false;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildStatusBadge() {
    final statusLower = widget.booking.status.toLowerCase();
    final paymentStatusLower = widget.booking.paymentStatus?.toLowerCase();
    Color backgroundColor;
    Color textColor;
    IconData icon;
    String displayText;

    // Determine the primary status to display
    String primaryStatus;
    if (paymentStatusLower == 'paid') {
      primaryStatus = 'paid';
    } else if (paymentStatusLower == 'pending' && statusLower == 'agreed') {
      primaryStatus = 'payment_pending';
    } else if (paymentStatusLower == 'failed') {
      primaryStatus = 'payment_failed';
    } else {
      primaryStatus = statusLower;
    }

    switch (primaryStatus) {
      case 'pending':
        backgroundColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange;
        icon = Icons.pending;
        displayText = 'status_pending_label'.tr.toUpperCase();
        break;
      case 'agreed':
        backgroundColor = AppColors.primaryColor.withValues(alpha: 0.1);
        textColor = AppColors.primaryColor;
        icon = Icons.check_circle;
        displayText = 'status_agreed_label'.tr.toUpperCase();
        break;
      case 'paid':
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        textColor = Colors.green;
        icon = Icons.check_circle_outline;
        displayText = 'status_paid_label'.tr.toUpperCase();
        break;
      case 'payment_pending':
        backgroundColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange;
        icon = Icons.hourglass_empty;
        displayText = 'status_payment_pending_label'.tr.toUpperCase();
        break;
      case 'payment_failed':
        backgroundColor = AppColors.errorColor.withValues(alpha: 0.1);
        textColor = AppColors.errorColor;
        icon = Icons.error_outline;
        displayText = 'status_payment_failed_label'.tr.toUpperCase();
        break;
      case 'cancelled':
        backgroundColor = AppColors.greyColor.withValues(alpha: 0.1);
        textColor = AppColors.greyColor;
        icon = Icons.cancel;
        displayText = 'status_cancelled_label'.tr.toUpperCase();
        break;
      default:
        backgroundColor = AppColors.primaryColor.withValues(alpha: 0.1);
        textColor = AppColors.primaryColor;
        icon = Icons.info;
        displayText = statusLower.toUpperCase();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: textColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16.sp, color: textColor),
          SizedBox(width: 8.w),
          PoppinsText(
            text: 'booking_agreement_status_label'.trParams({
              'status': displayText,
            }),
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ],
      ),
    );
  }

  Widget _buildBookingDetailsCard() {
    final venue =
        _agreementHouseSittingVenue ?? widget.booking.houseSittingVenue;
    String? venueLabel;
    if (venue == 'owners_home') {
      venueLabel = 'house_sitting_venue_owners_home'.tr;
    } else if (venue == 'sitters_home') {
      venueLabel = 'house_sitting_venue_sitters_home'.tr;
    }

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
            text: 'owner_booking_details_title'.tr,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(context),
          ),
          SizedBox(height: 16.h),
          _buildDetailRow(
            'bookings_detail_pet_label'.tr,
            widget.booking.petName,
          ),
          SizedBox(height: 12.h),
          // _buildDetailRow('Date', _formatBookingDate(widget.booking.date)),
          if (_agreementStartDate != null &&
              _agreementStartDate!.isNotEmpty) ...[
            SizedBox(height: 12.h),
            _buildDetailRow(
              'booking_agreement_start_date_label'.tr,
              _formatBookingDate(_agreementStartDate!),
            ),
          ],
          if (_agreementEndDate != null && _agreementEndDate!.isNotEmpty) ...[
            SizedBox(height: 12.h),
            _buildDetailRow(
              'booking_agreement_end_date_label'.tr,
              _formatBookingDate(_agreementEndDate!),
            ),
          ],
          SizedBox(height: 12.h),
          _buildDetailRow(
            'booking_agreement_time_slot_label'.tr,
            // v18.9.1 — heure localisée (plus de "12:04 PM" en FR).
            BookingDateFormat.localizedTime(widget.booking.timeSlot),
          ),
          SizedBox(height: 12.h),
          _buildDetailRow(
            'booking_agreement_service_provider_label'.tr,
            widget.booking.sitter.name,
          ),
          // v18.9.3 — ville du provider affichée dans les détails.
          if (widget.booking.sitter.city != null &&
              widget.booking.sitter.city!.trim().isNotEmpty) ...[
            SizedBox(height: 12.h),
            _buildDetailRow(
              'booking_agreement_city_label'.tr,
              widget.booking.sitter.city!,
            ),
          ],
          if (widget.booking.serviceType != null &&
              widget.booking.serviceType!.isNotEmpty) ...[
            SizedBox(height: 12.h),
            _buildDetailRow(
              'booking_agreement_service_type_label'.tr,
              // v18.9.1 — service type localisé au lieu de 'dog_walking' brut.
              _localizedServiceType(widget.booking.serviceType!),
            ),
          ],
          if (venueLabel != null &&
              (widget.booking.serviceType ?? '').toLowerCase() ==
                  'house_sitting') ...[
            SizedBox(height: 12.h),
            _buildDetailRow('house_sitting_venue_label'.tr, venueLabel),
          ],
          if (_durationMinutesForDisplay != null) ...[
            SizedBox(height: 12.h),
            _buildDetailRow(
              'send_request_duration_label'.tr,
              'send_request_duration_minutes_label'.trParams({
                'minutes': _durationMinutesForDisplay.toString(),
              }),
            ),
          ],
          if (widget.booking.description.isNotEmpty) ...[
            SizedBox(height: 12.h),
            _buildDetailRow(
              'bookings_detail_description_label'.tr,
              widget.booking.description,
            ),
          ],
          if (widget.booking.specialInstructions != null &&
              widget.booking.specialInstructions!.isNotEmpty) ...[
            SizedBox(height: 12.h),
            _buildDetailRow(
              'booking_agreement_special_instructions_label'.tr,
              widget.booking.specialInstructions!,
            ),
          ],
          if (widget.booking.cancelledAt != null &&
              widget.booking.cancelledAt!.isNotEmpty) ...[
            SizedBox(height: 12.h),
            _buildDetailRow(
              'booking_agreement_cancelled_at_label'.tr,
              _formatDateTime(widget.booking.cancelledAt!),
            ),
          ],
          if (widget.booking.cancellationReason != null &&
              widget.booking.cancellationReason!.isNotEmpty) ...[
            SizedBox(height: 12.h),
            _buildDetailRow(
              'booking_agreement_cancellation_reason_label'.tr,
              widget.booking.cancellationReason!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: InterText(
            text: label,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.grey700Color,
          ),
        ),
        Expanded(
          flex: 3,
          child: InterText(
            text: value,
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.textPrimary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceBreakdownCard(
    double baseTotal,
    double platformFee,
    double finalTotal,
  ) {
    final effectivePricing = _agreementPricing ?? widget.booking.pricing;
    final displayBasePrice = baseTotal;
    final displayPlatformFee = platformFee;
    final displayTotalPrice = finalTotal;
    final displayNetAmount = effectivePricing?.netAmount;

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
            text: 'booking_agreement_price_breakdown_title'.tr,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(context),
          ),
          SizedBox(height: 20.h),
          if (effectivePricing?.pricingTier != null &&
              effectivePricing!.pricingTier!.isNotEmpty) ...[
            _buildDetailRow(
              'booking_agreement_pricing_tier_label'.tr,
              effectivePricing.pricingTier!,
            ),
            SizedBox(height: 12.h),
          ],
          if (effectivePricing?.totalHours != null &&
              effectivePricing!.totalHours! > 0) ...[
            _buildDetailRow(
              'booking_agreement_total_hours_label'.tr,
              effectivePricing.totalHours!.toStringAsFixed(1),
            ),
            SizedBox(height: 12.h),
          ],
          if (effectivePricing?.totalDays != null &&
              effectivePricing!.totalDays! > 0) ...[
            _buildDetailRow(
              'booking_agreement_total_days_label'.tr,
              effectivePricing.totalDays!.toStringAsFixed(0),
            ),
            SizedBox(height: 12.h),
          ],
          _buildPriceRow(
            'booking_agreement_base_price_label'.tr,
            _formatPrice(displayBasePrice),
          ),
          SizedBox(height: 16.h),
          _buildPriceRow(
            'booking_agreement_platform_fee_label'.tr,
            _formatPrice(displayPlatformFee),
            isSecondary: true,
          ),
          if (displayNetAmount != null) ...[
            SizedBox(height: 16.h),
            _buildPriceRow(
              'booking_agreement_net_amount_label'.tr,
              _formatPrice(displayNetAmount),
              isSecondary: true,
            ),
          ],
          SizedBox(height: 20.h),
          Divider(color: AppColors.grey300Color, thickness: 1),
          SizedBox(height: 16.h),
          _buildPriceRow(
            'bookings_detail_total_amount_label'.tr,
            _formatPrice(displayTotalPrice),
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    String value, {
    bool isSecondary = false,
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InterText(
          text: label,
          fontSize: isTotal ? 16.sp : 14.sp,
          fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
          color: isSecondary ? AppColors.grey500Color : AppColors.textPrimary(context),
        ),
        PoppinsText(
          text: value,
          fontSize: isTotal ? 18.sp : 14.sp,
          fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
          color: isTotal ? AppColors.primaryColor : AppColors.textPrimary(context),
        ),
      ],
    );
  }

  String _formatPrice(double price) {
    final currency =
        _currency ??
        widget.booking.pricing?.currency ??
        widget.booking.sitter.currency;
    return CurrencyHelper.format(currency, price);
  }

  /// v18.9.1 — localise un service type brut ('dog_walking', 'day_care'...)
  /// en label lisible selon la locale. Fallback : capitalise underscore → espace.
  String _localizedServiceType(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) return raw;
    // Essaie d'abord les clés send_request_service_{type} déjà utilisées dans
    // le formulaire Envoyer une demande.
    final key = 'send_request_service_$normalized';
    final translated = key.tr;
    if (translated != key) return translated;
    // Fallback : 'dog_walking' → 'Dog Walking'.
    return normalized
        .split('_')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        return 'booking_agreement_today_at'.trParams({
          'time':
              '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}',
        });
      } else if (difference.inDays == 1) {
        return 'booking_agreement_yesterday_at'.trParams({
          'time':
              '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}',
        });
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${'booking_agreement_at'.tr} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return dateTimeString; // Return original string if parsing fails
    }
  }

  String _formatBookingDate(String rawDate) {
    final value = rawDate.trim();
    if (value.isEmpty) return rawDate;
    try {
      final date = DateTime.parse(value).toLocal();
      const months = <String>[
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
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return rawDate;
    }
  }
}
