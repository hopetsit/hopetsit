import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/bookings_controller.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_confirmation_dialog.dart';
import 'package:hopetsit/views/booking/booking_agreement_screen.dart';
import 'package:hopetsit/views/reviews/reviews_screen.dart';

class BookingsHistoryScreen extends StatefulWidget {
  const BookingsHistoryScreen({super.key});

  @override
  State<BookingsHistoryScreen> createState() => _BookingsHistoryScreenState();
}

class _BookingsHistoryScreenState extends State<BookingsHistoryScreen> {
  late BookingsController _bookingsController;
  String? _selectedStatus;

  // All available statuses
  final List<String> _statuses = [
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
    _bookingsController = Get.put(BookingsController());
    _selectedStatus = 'all';
  }

  List<BookingModel> get _filteredBookings {
    if (_selectedStatus == 'all') {
      return _bookingsController.bookings;
    }
    return _bookingsController.bookings
        .where((booking) => booking.status.toLowerCase() == _selectedStatus)
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
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        leading: BackButton(),
        title: PoppinsText(
          text: 'bookings_history_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: Column(
        children: [
          // Status Filter Chips
          _buildStatusFilter(),

          // Bookings List
          Expanded(
            child: Obx(() {
              if (_bookingsController.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryColor,
                    ),
                  ),
                );
              }

              final filteredBookings = _filteredBookings;

              if (filteredBookings.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 64.sp,
                          color: AppColors.greyColor,
                        ),
                        SizedBox(height: 16.h),
                        InterText(
                          text: _selectedStatus == 'all'
                              ? 'bookings_history_empty_all'.tr
                              : 'bookings_history_empty_filtered'.trParams({
                                  'status': _getStatusLabel(_selectedStatus!),
                                }),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w400,
                          color: AppColors.greyColor,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                color: AppColors.primaryColor,
                onRefresh: () => _bookingsController.loadBookings(),
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
                  itemCount: filteredBookings.length,
                  itemBuilder: (context, index) {
                    final booking = filteredBookings[index];
                    return _buildBookingCard(booking);
                  },
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
            onTap: () {
              setState(() {
                _selectedStatus = status;
              });
            },
            child: Container(
              margin: EdgeInsets.only(right: 12.w),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryColor
                    : AppColors.whiteColor,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryColor
                      : AppColors.grey300Color,
                  width: 1,
                ),
              ),
              child: Center(
                child: InterText(
                  text: _getStatusLabel(status),
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

  String _getStatusLabel(String status) {
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
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.grey300Color, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Status and Service Provider
          Row(
            children: [
              // Status Badge
              _buildStatusBadge(booking),
              const Spacer(),
              // Service Provider Avatar
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    // Navigate to service provider detail if needed
                  },
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
                                placeholder: (context, url) => Container(
                                  width: 32.w,
                                  height: 32.h,
                                  color: AppColors.lightGrey,
                                  child: Icon(
                                    Icons.person,
                                    size: 20.sp,
                                    color: AppColors.primaryColor,
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 32.w,
                                  height: 32.h,
                                  color: AppColors.lightGrey,
                                  child: Icon(
                                    Icons.person,
                                    size: 20.sp,
                                    color: AppColors.primaryColor,
                                  ),
                                ),
                              )
                            : Container(
                                width: 32.w,
                                height: 32.h,
                                color: AppColors.lightGrey,
                                child: Icon(
                                  Icons.person,
                                  size: 20.sp,
                                  color: AppColors.primaryColor,
                                ),
                              ),
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
              ),
            ],
          ),

          SizedBox(height: 16.h),

          // Booking Details
          _buildDetailRow(
            Icons.pets,
            'bookings_detail_pet_label'.tr,
            booking.petName,
          ),
          SizedBox(height: 12.h),
          _buildDetailRow(
            Icons.calendar_today,
            'bookings_detail_date_label'.tr,
            booking.date,
          ),
          SizedBox(height: 12.h),
          _buildDetailRow(
            Icons.access_time,
            'bookings_detail_time_label'.tr,
            booking.timeSlot,
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Icon(
                Icons.attach_money,
                size: 16.sp,
                color: AppColors.grey700Color,
              ),
              SizedBox(width: 8.w),
              InterText(
                text: 'bookings_detail_total_amount_label'.tr,
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.grey700Color,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: InterText(
                  text: CurrencyHelper.format(
                    booking.pricing?.currency ?? booking.sitter.currency,
                    booking.pricing?.totalPrice ??
                        booking.totalAmount ??
                        booking.pricing?.basePrice ??
                        booking.sitter.hourlyRate,
                  ),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              InterText(
                text: 'bookings_detail_phone_label'.tr,
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.grey700Color,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: InterText(
                  text: booking.sitter.mobile.isNotEmpty
                      ? booking.sitter.mobile
                      : 'service_card_no_phone'.tr,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: booking.sitter.mobile.isNotEmpty
                      ? AppColors.textPrimary(context)
                      : AppColors.textSecondary(context),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              InterText(
                text: 'bookings_detail_location_label'.tr,
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.grey700Color,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: InterText(
                  text:
                      booking.sitter.city != null &&
                          booking.sitter.city!.isNotEmpty
                      ? booking.sitter.city!
                      : 'service_card_no_location'.tr,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color:
                      booking.sitter.city != null &&
                          booking.sitter.city!.isNotEmpty
                      ? AppColors.textPrimary(context)
                      : AppColors.textSecondary(context),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              InterText(
                text: 'bookings_detail_rating_label'.tr,
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.grey700Color,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: InterText(
                  text:
                      (booking.sitter.rating > 0 &&
                          booking.sitter.reviewsCount > 0)
                      ? 'sitter_rating_with_count'.trParams({
                          'rating': booking.sitter.rating.toStringAsFixed(1),
                          'count': booking.sitter.reviewsCount.toString(),
                        })
                      : 'sitter_detail_no_rating'.tr,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color:
                      (booking.sitter.rating > 0 &&
                          booking.sitter.reviewsCount > 0)
                      ? AppColors.textPrimary(context)
                      : AppColors.textSecondary(context),
                ),
              ),
            ],
          ),

          if (booking.description.isNotEmpty) ...[
            SizedBox(height: 12.h),
            _buildDescription(booking.description),
          ],

          SizedBox(height: 16.h),

          // Action Buttons
          _buildActionButtons(booking),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BookingModel booking) {
    final statusLower = booking.status.toLowerCase();
    final paymentStatusLower = booking.paymentStatus?.toLowerCase();
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
        displayText = 'status_pending_label'.tr;
        break;
      case 'agreed':
        backgroundColor = AppColors.primaryColor.withValues(alpha: 0.1);
        textColor = AppColors.primaryColor;
        icon = Icons.check_circle;
        displayText = 'status_agreed_label'.tr;
        break;
      case 'paid':
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        textColor = Colors.green;
        icon = Icons.check_circle_outline;
        displayText = 'status_paid_label'.tr;
        break;
      case 'payment_pending':
        backgroundColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange;
        icon = Icons.hourglass_empty;
        displayText = 'status_payment_pending_label'.tr;
        break;
      case 'payment_failed':
        backgroundColor = AppColors.errorColor.withValues(alpha: 0.1);
        textColor = AppColors.errorColor;
        icon = Icons.error_outline;
        displayText = 'status_payment_failed_label'.tr;
        break;
      case 'failed':
        backgroundColor = AppColors.errorColor.withValues(alpha: 0.1);
        textColor = AppColors.errorColor;
        icon = Icons.error;
        displayText = 'status_failed_label'.tr;
        break;
      case 'cancelled':
        backgroundColor = AppColors.errorColor.withValues(alpha: 0.1);
        textColor = AppColors.errorColor;
        icon = Icons.cancel;
        displayText = 'status_cancelled_label'.tr;
        break;
      case 'refunded':
        backgroundColor = Colors.blue.withValues(alpha: 0.1);
        textColor = Colors.blue;
        icon = Icons.undo;
        displayText = 'status_refunded_label'.tr;
        break;
      default:
        backgroundColor = AppColors.greyColor.withValues(alpha: 0.1);
        textColor = AppColors.greyColor;
        icon = Icons.info;
        displayText = statusLower.tr;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: textColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: textColor),
          SizedBox(width: 6.w),
          InterText(
            text: displayText,
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
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
            text: value,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildDescription(String description) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InterText(
            text: 'bookings_detail_description_label'.tr,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.grey700Color,
          ),
          SizedBox(height: 4.h),
          InterText(
            text: description,
            fontSize: 12.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.textPrimary(context),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BookingModel booking) {
    final statusLower = booking.status.toLowerCase();
    final paymentStatusLower = booking.paymentStatus?.toLowerCase();

    return Row(
      children: [
        // View Details Button
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              Get.to(() => BookingAgreementScreen(booking: booking));
            },
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 10.h),
              side: BorderSide(color: AppColors.primaryColor, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: InterText(
              text: 'bookings_action_view_details'.tr,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryColor,
            ),
          ),
        ),

        // Status-specific actions
        if (statusLower == 'agreed' && paymentStatusLower == 'pending') ...[
          SizedBox(width: 12.w),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Get.to(() => BookingAgreementScreen(booking: booking));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
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

        if (statusLower == 'pending' || statusLower == 'agreed') ...[
          SizedBox(width: 12.w),
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                _showCancelBookingDialog(context, booking);
              },
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                side: BorderSide(color: AppColors.errorColor, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: InterText(
                text: 'service_card_cancel'.tr,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.errorColor,
              ),
            ),
          ),
        ],

        // v18.5 — #22 : bouton "Laisser un avis" sur bookings completed.
        // Remplace l'option review sur l'écran paiement réussi (#17) qui
        // n'avait pas de sens car le service n'était pas encore fait.
        if (statusLower == 'completed') ...[
          SizedBox(width: 12.w),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Get.to(
                  () => ReviewsScreen(
                    serviceProviderName: booking.sitter.name,
                    phoneNumber: booking.sitter.mobile,
                    email: booking.sitter.email,
                    profileImagePath: booking.sitter.avatar.url.isNotEmpty
                        ? booking.sitter.avatar.url
                        : null,
                    serviceProviderId: booking.sitter.id,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                padding: EdgeInsets.symmetric(vertical: 10.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: InterText(
                text: 'booking_leave_review'.tr,
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

  void _showCancelBookingDialog(BuildContext context, BookingModel booking) {
    CustomConfirmationDialog.show(
      context: context,
      message: 'booking_cancel_dialog_message'.tr,
      yesText: 'common_yes'.tr,
      cancelText: 'common_no'.tr,
      onYes: () {
        _bookingsController.cancelBooking(
          bookingId: booking.id,
          sitterId: booking.sitter.id,
        );
      },
    );
  }
}
