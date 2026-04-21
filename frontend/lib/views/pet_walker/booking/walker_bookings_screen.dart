import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/walker_bookings_controller.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Walker bookings history screen.
///
/// Session v17 — created so walkers see the bookings the owners have
/// confirmed with them. Mirrors the visual structure of
/// `SitterBookingsScreen` but uses [WalkerBookingsController] which hits the
/// /bookings/my endpoint with the walker's auth token. Walker payment cards
/// use the walker accent green (#16A34A) — same colour as the post price
/// block in v16.3h and the PaymentPage in v17d.
class WalkerBookingsScreen extends StatefulWidget {
  const WalkerBookingsScreen({super.key});

  @override
  State<WalkerBookingsScreen> createState() => _WalkerBookingsScreenState();
}

class _WalkerBookingsScreenState extends State<WalkerBookingsScreen> {
  // Same colour as walker price-block in PetPostCard / PaymentPage v17d.
  static const Color _walkerAccent = Color(0xFF16A34A);

  late WalkerBookingsController _bookingsController;
  String _selectedStatus = 'all';

  // Same status filter chips as sitter for parity.
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
    _bookingsController = Get.put(WalkerBookingsController());
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
        iconTheme: const IconThemeData(color: _walkerAccent),
        title: PoppinsText(
          // Same key as sitter screen — title is generic.
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
                    valueColor: AlwaysStoppedAnimation<Color>(_walkerAccent),
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
                color: _walkerAccent,
                onRefresh: () => _bookingsController.loadBookings(
                  status: _selectedStatus == 'all' ? null : _selectedStatus,
                ),
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
                  itemCount: list.length,
                  itemBuilder: (context, index) => _buildBookingCard(list[index]),
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
              setState(() => _selectedStatus = status);
              _bookingsController.loadBookings(
                status: status == 'all' ? null : status,
              );
            },
            child: Container(
              margin: EdgeInsets.only(right: 12.w),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isSelected ? _walkerAccent : AppColors.whiteColor,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: isSelected ? _walkerAccent : AppColors.grey300Color,
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
    return Container(
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
              _statusBadge(booking.status),
              const Spacer(),
              Expanded(
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
                              placeholder: (_, __) => _avatarPlaceholder(),
                              errorWidget: (_, __, ___) => _avatarPlaceholder(),
                            )
                          : _avatarPlaceholder(),
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
            ],
          ),
          SizedBox(height: 16.h),
          _row(Icons.pets, 'sitter_bookings_pet_label'.tr, booking.petName),
          SizedBox(height: 12.h),
          _row(Icons.calendar_today,
              'sitter_bookings_date_label'.tr, booking.date),
          SizedBox(height: 12.h),
          _row(Icons.access_time,
              'sitter_bookings_time_label'.tr, booking.timeSlot),
          if (booking.duration != null && booking.duration! > 0) ...[
            SizedBox(height: 12.h),
            _row(Icons.timer, 'duration_label'.tr.isNotEmpty
                ? 'duration_label'.tr
                : 'Duration', '${booking.duration} min'),
          ],
          if (booking.totalAmount != null) ...[
            SizedBox(height: 12.h),
            Row(
              children: [
                Icon(Icons.attach_money,
                    size: 16.sp, color: _walkerAccent),
                SizedBox(width: 8.w),
                InterText(
                  text: '${booking.totalAmount!.toStringAsFixed(2)} '
                      '${booking.pricing?.currency ?? booking.sitter.currency}',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: _walkerAccent,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'paid':
        color = _walkerAccent;
        break;
      case 'pending':
        color = const Color(0xFFF59E0B);
        break;
      case 'agreed':
      case 'accepted':
        color = const Color(0xFF3B82F6);
        break;
      case 'cancelled':
      case 'rejected':
      case 'refunded':
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
        text: _label(status),
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
            text: value,
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
      child: Icon(Icons.person, size: 20.sp, color: _walkerAccent),
    );
  }
}
