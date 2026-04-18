import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/sitter_bookings_controller.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/pricing_display_helper.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_confirmation_dialog.dart';

class SitterBookingsScreen extends StatefulWidget {
  const SitterBookingsScreen({super.key});

  @override
  State<SitterBookingsScreen> createState() => _SitterBookingsScreenState();
}

class _SitterBookingsScreenState extends State<SitterBookingsScreen> {
  late SitterBookingsController _bookingsController;
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
    _bookingsController = Get.put(SitterBookingsController());
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
          text: 'sitter_bookings_title'.tr,
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
                              ? 'sitter_bookings_empty_all'.tr
                              : 'sitter_bookings_empty_filtered'.trParams({
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
              _bookingsController.loadBookings(
                status: status == 'all' ? null : status,
              );
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
          // Header: Status and Pet Owner
          Row(
            children: [
              // Status Badge
              _buildStatusBadge(booking.status),
              const Spacer(),
              // Pet Owner Avatar
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    // Navigate to pet owner detail if needed
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipOval(
                        child: booking.owner.avatar.url.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: booking.owner.avatar.url,
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
                          text: booking.owner.name,
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
          _buildDetailRow(Icons.pets, 'sitter_bookings_pet_label'.tr, booking.petName),
          SizedBox(height: 12.h),
          _buildDetailRow(Icons.calendar_today, 'sitter_bookings_date_label'.tr, booking.date),
          SizedBox(height: 12.h),
          _buildDetailRow(Icons.access_time, 'sitter_bookings_time_label'.tr, booking.timeSlot),
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
                text: 'sitter_bookings_rate_label'.tr,
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.grey700Color,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: InterText(
                  text: PricingDisplayHelper.sitterBookingRateLine(booking),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary(context),
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

  Widget _buildStatusBadge(String status) {
    final statusLower = status.toLowerCase();
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (statusLower) {
      case 'pending':
        backgroundColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange;
        icon = Icons.pending;
        break;
      case 'agreed':
        backgroundColor = AppColors.primaryColor.withValues(alpha: 0.1);
        textColor = AppColors.primaryColor;
        icon = Icons.check_circle;
        break;
      case 'paid':
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        textColor = Colors.green;
        icon = Icons.payment;
        break;
      case 'failed':
        backgroundColor = AppColors.errorColor.withValues(alpha: 0.1);
        textColor = AppColors.errorColor;
        icon = Icons.error;
        break;
      case 'cancelled':
        backgroundColor = AppColors.greyColor.withValues(alpha: 0.1);
        textColor = AppColors.greyColor;
        icon = Icons.cancel;
        break;
      case 'refunded':
        backgroundColor = Colors.blue.withValues(alpha: 0.1);
        textColor = Colors.blue;
        icon = Icons.undo;
        break;
      default:
        backgroundColor = AppColors.greyColor.withValues(alpha: 0.1);
        textColor = AppColors.greyColor;
        icon = Icons.info;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: textColor),
          SizedBox(width: 6.w),
          InterText(
            text: _getStatusLabel(status),
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
            color: AppColors.blackColor,
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
            text: 'sitter_bookings_description_label'.tr,
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

    return Row(
      children: [
        // Cancel Button (for pending and agreed statuses)
        if (statusLower == 'pending' || statusLower == 'agreed') ...[
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
                text: 'sitter_bookings_cancel_button'.tr,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.errorColor,
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
      message: 'sitter_bookings_cancel_dialog_message'.tr,
      yesText: 'sitter_bookings_cancel_dialog_yes'.tr,
      cancelText: 'common_no'.tr,
      onYes: () {
        _bookingsController.requestCancellation(bookingId: booking.id);
      },
    );
  }
}
