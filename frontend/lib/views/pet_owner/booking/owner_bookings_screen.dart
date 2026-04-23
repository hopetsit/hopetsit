import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/bookings_controller.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/booking_date_format.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/views/booking/booking_agreement_screen.dart';
import 'package:hopetsit/views/payment/stripe_payment_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// v18.9 — "Mes réservations" côté Owner, clone du design walker/sitter
/// (cartes compactes + filter chips) avec l'accent ORANGE du rôle owner.
/// Daniel : "ce design de reservation je le veux pareil pour le profil
/// owner et petsitter en respectant role et couleur".
class OwnerBookingsScreen extends StatefulWidget {
  const OwnerBookingsScreen({super.key});

  @override
  State<OwnerBookingsScreen> createState() => _OwnerBookingsScreenState();
}

class _OwnerBookingsScreenState extends State<OwnerBookingsScreen> {
  static const Color _ownerAccent = Color(0xFFEF4324);

  late BookingsController _bookingsController;
  String _selectedStatus = 'all';

  final List<String> _statuses = const [
    'all',
    'pending',
    'agreed',
    'paid',
    'failed',
    'cancelled',
    'refunded',
  ];

  @override
  void initState() {
    super.initState();
    _bookingsController = Get.isRegistered<BookingsController>()
        ? Get.find<BookingsController>()
        : Get.put(BookingsController());
  }

  List<BookingModel> get _filteredBookings {
    if (_selectedStatus == 'all') {
      return _bookingsController.bookings;
    }
    return _bookingsController.bookings
        .where((b) => b.status.toLowerCase() == _selectedStatus)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _ownerAccent),
        title: PoppinsText(
          text: 'sitter_bookings_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: Column(
        children: [
          _buildStatusFilter(),
          Expanded(
            child: Obx(() {
              if (_bookingsController.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(_ownerAccent),
                  ),
                );
              }

              final list = _filteredBookings;
              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy,
                            size: 64.sp, color: AppColors.greyColor),
                        SizedBox(height: 16.h),
                        InterText(
                          text: _selectedStatus == 'all'
                              ? 'sitter_bookings_empty_all'.tr
                              : 'sitter_bookings_empty_filtered'.trParams({
                                  'status': _label(_selectedStatus),
                                }),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w400,
                          color: AppColors.greyColor,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                color: _ownerAccent,
                onRefresh: () => _bookingsController.loadBookings(),
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
                  itemCount: list.length,
                  itemBuilder: (context, index) =>
                      _buildBookingCard(list[index]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      height: 50.h,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        itemCount: _statuses.length,
        itemBuilder: (context, index) {
          final status = _statuses[index];
          final isSelected = _selectedStatus == status;
          return GestureDetector(
            onTap: () => setState(() => _selectedStatus = status),
            child: Container(
              margin: EdgeInsets.only(right: 12.w),
              padding:
                  EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isSelected ? _ownerAccent : AppColors.whiteColor,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: isSelected
                      ? _ownerAccent
                      : AppColors.grey300Color,
                ),
              ),
              child: Center(
                child: InterText(
                  text: _label(status),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? AppColors.whiteColor
                      : AppColors.grey700Color,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _label(String status) {
    switch (status) {
      case 'all':
        return 'status_all_label'.tr;
      case 'pending':
        return 'status_pending_label'.tr;
      case 'agreed':
        return 'status_agreed_label'.tr;
      case 'paid':
        return 'status_paid_label'.tr;
      case 'failed':
        return 'status_failed_label'.tr;
      case 'cancelled':
        return 'status_cancelled_label'.tr;
      case 'refunded':
        return 'status_refunded_label'.tr;
      default:
        return status.tr;
    }
  }

  Widget _buildBookingCard(BookingModel booking) {
    final totalAmount = booking.totalAmount ??
        booking.pricing?.totalPrice ??
        booking.basePrice;
    return GestureDetector(
      onTap: () {
        Get.to(() => BookingAgreementScreen(booking: booking));
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.grey300Color),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _statusBadge(booking.status, booking.paymentStatus),
                const Spacer(),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipOval(
                        child: booking.sitter.avatar.url.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: booking.sitter.avatar.url,
                                width: 32.w,
                                height: 32.h,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => _avatarPlaceholder(),
                                errorWidget: (_, __, ___) =>
                                    _avatarPlaceholder(),
                              )
                            : _avatarPlaceholder(),
                      ),
                      SizedBox(width: 8.w),
                      Flexible(
                        child: InterText(
                          text: booking.sitter.name,
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
              ],
            ),
            SizedBox(height: 16.h),
            _row(Icons.pets, 'sitter_bookings_pet_label'.tr,
                booking.petName),
            SizedBox(height: 12.h),
            _row(Icons.calendar_today, 'sitter_bookings_date_label'.tr,
                BookingDateFormat.localizedDate(booking.date)),
            SizedBox(height: 12.h),
            _row(Icons.access_time, 'sitter_bookings_time_label'.tr,
                BookingDateFormat.localizedTime(booking.timeSlot)),
            if (booking.duration != null && booking.duration! > 0) ...[
              SizedBox(height: 12.h),
              _row(Icons.timer, 'duration_label'.tr,
                  '${booking.duration} min'),
            ],
            if (totalAmount != null) ...[
              SizedBox(height: 12.h),
              Row(
                children: [
                  Icon(Icons.attach_money, size: 16.sp, color: _ownerAccent),
                  SizedBox(width: 8.w),
                  InterText(
                    text: CurrencyHelper.format(
                      booking.pricing?.currency ?? booking.sitter.currency,
                      totalAmount,
                    ),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: _ownerAccent,
                  ),
                ],
              ),
            ],
            SizedBox(height: 16.h),
            _buildActionButtons(booking),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BookingModel booking) {
    final statusLower = booking.status.toLowerCase();
    final paymentStatusLower = booking.paymentStatus?.toLowerCase();
    final isEligibleForPayment = (statusLower == 'agreed' ||
            statusLower == 'accepted' ||
            statusLower == 'confirmed') &&
        (paymentStatusLower == null ||
            paymentStatusLower.isEmpty ||
            paymentStatusLower != 'paid');

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              Get.to(() => BookingAgreementScreen(booking: booking));
            },
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 10.h),
              side: const BorderSide(color: _ownerAccent, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: InterText(
              text: 'bookings_action_view_details'.tr,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: _ownerAccent,
            ),
          ),
        ),
        if (isEligibleForPayment) ...[
          SizedBox(width: 12.w),
          Expanded(
            child: ElevatedButton(
              onPressed: () async {
                final pricing = booking.pricing;
                final base = (pricing?.totalPrice ??
                        pricing?.resolvedBaseAmount ??
                        booking.totalAmount ??
                        booking.basePrice) ??
                    0.0;
                final serviceLower =
                    (booking.serviceType ?? '').toLowerCase();
                final providerType = serviceLower.contains('walking') ||
                        serviceLower.contains('dog_walking')
                    ? 'walker'
                    : 'sitter';
                await Get.to(
                  () => StripePaymentScreen(
                    booking: booking,
                    totalAmount: base,
                    currency:
                        pricing?.currency ?? booking.sitter.currency,
                    providerType: providerType,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _ownerAccent,
                padding: EdgeInsets.symmetric(vertical: 10.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: InterText(
                text: 'service_card_pay_now'.tr,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.whiteColor,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _statusBadge(String status, String? paymentStatus) {
    final statusLower = status.toLowerCase();
    final paymentLower = paymentStatus?.toLowerCase();
    String primary;
    if (paymentLower == 'paid') {
      primary = 'paid';
    } else if (paymentLower == 'failed') {
      primary = 'failed';
    } else {
      primary = statusLower;
    }

    Color color;
    switch (primary) {
      case 'paid':
        color = const Color(0xFF16A34A);
        break;
      case 'pending':
        color = const Color(0xFFF59E0B);
        break;
      case 'agreed':
      case 'accepted':
        color = _ownerAccent;
        break;
      case 'cancelled':
      case 'rejected':
      case 'refunded':
      case 'failed':
      case 'payment_failed':
        color = const Color(0xFFEF4444);
        break;
      default:
        color = AppColors.greyColor;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: InterText(
        text: _label(primary),
        fontSize: 11.sp,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16.sp, color: AppColors.grey700Color),
        SizedBox(width: 8.w),
        InterText(
          text: label,
          fontSize: 12.sp,
          fontWeight: FontWeight.w400,
          color: AppColors.grey700Color,
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: InterText(
            text: value.isNotEmpty ? value : '—',
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      width: 32.w,
      height: 32.h,
      color: AppColors.lightGrey,
      child: Icon(Icons.person, size: 20.sp, color: _ownerAccent),
    );
  }
}
