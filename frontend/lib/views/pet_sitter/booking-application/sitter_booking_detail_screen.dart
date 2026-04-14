import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/string_utils.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Detail screen for a booking request (sitter view).
/// Shows: Requests (client card), Pets, Note, Accept/Decline.
class SitterBookingDetailScreen extends StatefulWidget {
  final BookingModel booking;
  final Future<void> Function()? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onStartChat;

  const SitterBookingDetailScreen({
    super.key,
    required this.booking,
    this.onAccept,
    this.onReject,
    this.onStartChat,
  });

  @override
  State<SitterBookingDetailScreen> createState() =>
      _SitterBookingDetailScreenState();
}

class _SitterBookingDetailScreenState extends State<SitterBookingDetailScreen> {
  bool _isAccepting = false;

  String _timeAgo(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return 'sitter_time_just_now'.tr;
      if (diff.inMinutes < 60)
        return 'sitter_time_mins_ago'.tr.replaceAll(
          '@minutes',
          diff.inMinutes.toString(),
        );
      if (diff.inHours < 24)
        return 'sitter_time_hours_ago'.tr.replaceAll(
          '@hours',
          diff.inHours.toString(),
        );
      if (diff.inDays < 7)
        return 'sitter_time_days_ago'.tr.replaceAll(
          '@days',
          diff.inDays.toString(),
        );
      return 'sitter_time_days_ago'.tr.replaceAll(
        '@days',
        diff.inDays.toString(),
      );
    } catch (_) {
      return '';
    }
  }

  List<String> get _weekdays => [
    'sitter_weekday_mon'.tr,
    'sitter_weekday_tue'.tr,
    'sitter_weekday_wed'.tr,
    'sitter_weekday_thu'.tr,
    'sitter_weekday_fri'.tr,
    'sitter_weekday_sat'.tr,
    'sitter_weekday_sun'.tr,
  ];
  List<String> get _months => [
    'sitter_month_jan'.tr,
    'sitter_month_feb'.tr,
    'sitter_month_mar'.tr,
    'sitter_month_apr'.tr,
    'sitter_month_may'.tr,
    'sitter_month_jun'.tr,
    'sitter_month_jul'.tr,
    'sitter_month_aug'.tr,
    'sitter_month_sep'.tr,
    'sitter_month_oct'.tr,
    'sitter_month_nov'.tr,
    'sitter_month_dec'.tr,
  ];

  String _formatBookingDate(String? dateIso, String? timeSlot) {
    if (dateIso == null || dateIso.isEmpty) {
      return timeSlot?.trim().isNotEmpty == true ? timeSlot! : '';
    }
    try {
      final d = DateTime.parse(dateIso);
      final weekday = _weekdays[d.weekday - 1];
      final dateStr = '$weekday, ${_months[d.month - 1]} ${d.day}, ${d.year}';
      if (timeSlot != null && timeSlot.trim().isNotEmpty) {
        return '$dateStr, $timeSlot';
      }
      return dateStr;
    } catch (_) {
      return timeSlot?.trim().isNotEmpty == true ? timeSlot! : '';
    }
  }

  String _serviceTypeLabel(String? serviceType) {
    if (serviceType == null || serviceType.isEmpty) return '';
    switch (serviceType) {
      case 'long_stay':
        return 'sitter_service_long_term_care'.tr;
      case 'dog_walking':
        return 'sitter_service_dog_walking'.tr;
      case 'overnight_stay':
        return 'sitter_service_overnight_stay'.tr;
      case 'home_visit':
        return 'sitter_service_home_visit'.tr;
      default:
        return serviceType
            .split('_')
            .map(
              (e) => e.isEmpty
                  ? ''
                  : e.length == 1
                  ? e.toUpperCase()
                  : '${e[0].toUpperCase()}${e.substring(1).toLowerCase()}',
            )
            .join(' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final owner = booking.owner;
    final location = owner.address.isNotEmpty ? owner.address : owner.language;
    final phone = owner.mobile;

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: AppColors.lightGrey,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: PoppinsText(
          text: 'sitter_request_details_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.blackColor,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 16.h),

              // Status chip
              _buildStatusChip(booking),
              SizedBox(height: 16.h),

              // Requests section – client card
              InterText(
                text: 'sitter_requests_section'.tr,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.blackColor,
              ),
              SizedBox(height: 12.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppColors.whiteColor,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: AppColors.grey300Color),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 28.r,
                      backgroundColor: AppColors.grey300Color,
                      backgroundImage: owner.avatar.url.isNotEmpty
                          ? CachedNetworkImageProvider(owner.avatar.url)
                          : null,
                      child: owner.avatar.url.isEmpty
                          ? Icon(
                              Icons.person,
                              size: 28.sp,
                              color: AppColors.greyColor,
                            )
                          : null,
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InterText(
                            text: owner.name,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.blackColor,
                          ),
                          if (location.isNotEmpty) ...[
                            SizedBox(height: 4.h),
                            InterText(
                              text: location,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w400,
                              color: AppColors.greyText,
                            ),
                          ],
                          if (phone.isNotEmpty) ...[
                            SizedBox(height: 8.h),
                            Row(
                              children: [
                                Icon(
                                  Icons.phone,
                                  size: 16.sp,
                                  color: AppColors.primaryColor,
                                ),
                                SizedBox(width: 6.w),
                                InterText(
                                  text: maskPhoneNumber(phone),
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.blackColor,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    InterText(
                      text: _timeAgo(booking.createdAt),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.greyText,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20.h),

              // Pet count, Service type, Date (below Requests card)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                decoration: BoxDecoration(
                  color: AppColors.whiteColor,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.grey300Color),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      Icons.pets,
                      'sitter_info_pets'.tr,
                      booking.pets.isNotEmpty
                          ? '${booking.pets.length}'
                          : (booking.petName.isNotEmpty
                                ? '1'
                                : 'sitter_no_pets'.tr),
                    ),
                    SizedBox(height: 12.h),
                    _buildInfoRow(
                      Icons.calendar_today_outlined,
                      'sitter_info_service'.tr,
                      _serviceTypeLabel(booking.serviceType).isNotEmpty
                          ? _serviceTypeLabel(booking.serviceType)
                          : 'sitter_no_service_type'.tr,
                    ),
                    SizedBox(height: 12.h),
                    _buildInfoRow(
                      Icons.access_time,
                      'sitter_info_date'.tr,
                      _formatBookingDate(
                            booking.date,
                            booking.timeSlot,
                          ).trim().isNotEmpty
                          ? _formatBookingDate(booking.date, booking.timeSlot)
                          : 'sitter_no_date_available'.tr,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              // Pets section
              InterText(
                text: 'sitter_pets_section'.tr,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.blackColor,
              ),
              SizedBox(height: 12.h),
              if (booking.pets.isEmpty)
                _buildPetCard(
                  petName: booking.petName,
                  category: '',
                  breed: '',
                  details:
                      '${booking.petWeight.isNotEmpty ? "${booking.petWeight} kg" : ""}'
                              '${booking.petHeight.isNotEmpty ? ", ${booking.petHeight} cm" : ""}'
                          .replaceFirst(RegExp(r'^,\s*'), ''),
                  traits: '',
                  medication: '',
                  imageUrl: '',
                )
              else
                ...booking.pets.map(
                  (pet) => Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: _buildPetCard(
                      petName: pet.petName,
                      category: pet.category,
                      breed: pet.breed,
                      details: [
                        if (pet.weight.isNotEmpty) '${pet.weight} kg',
                        if (pet.height.isNotEmpty) pet.height,
                      ].join(', '),
                      traits: pet.vaccination.isNotEmpty ? pet.vaccination : '',
                      medication: pet.medicationAllergies.isNotEmpty
                          ? 'Needs medication / ${pet.medicationAllergies}'
                          : '',
                      imageUrl: pet.avatar.url,
                    ),
                  ),
                ),

              SizedBox(height: 24.h),

              // Note section
              InterText(
                text: 'sitter_note_section'.tr,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.blackColor,
              ),
              SizedBox(height: 12.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: AppColors.whiteColor,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.grey300Color),
                ),
                child: InterText(
                  text: booking.description.isNotEmpty
                      ? booking.description
                      : 'sitter_no_note_provided'.tr,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: booking.description.isNotEmpty
                      ? AppColors.blackColor
                      : AppColors.greyText,
                ),
              ),

              SizedBox(height: 24.h),

              // Chat with Owner – same as card: show when paid
              if (widget.onStartChat != null)
                Padding(
                  padding: EdgeInsets.only(bottom: 20.h),
                  child: Center(
                    child: GestureDetector(
                      onTap: widget.onStartChat,
                      child: Container(
                        width: double.infinity,
                        height: 48.h,
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor,
                          borderRadius: BorderRadius.circular(24.r),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_outlined,
                              color: AppColors.whiteColor,
                              size: 20.sp,
                            ),
                            SizedBox(width: 8.w),
                            InterText(
                              text: 'sitter_chat_with_owner'.tr,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color: AppColors.whiteColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              SizedBox(height: 12.h),

              // Accept / Decline – same as card: show row only when pending; when pending show Accept only (Decline only for paid)
              if (booking.status == 'pending')
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _isAccepting
                            ? null
                            : () async {
                                if (widget.onAccept == null) return;
                                setState(() => _isAccepting = true);
                                try {
                                  await widget.onAccept!();
                                } finally {
                                  if (mounted) {
                                    setState(() => _isAccepting = false);
                                  }
                                }
                              },
                        child: Container(
                          height: 48.h,
                          decoration: BoxDecoration(
                            color: _isAccepting
                                ? AppColors.primaryColor.withOpacity(0.7)
                                : AppColors.primaryColor,
                            borderRadius: BorderRadius.circular(24.r),
                          ),
                          alignment: Alignment.center,
                          child: _isAccepting
                              ? SizedBox(
                                  width: 24.w,
                                  height: 24.h,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.whiteColor,
                                    ),
                                  ),
                                )
                              : InterText(
                                  text: 'sitter_accept'.tr,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.whiteColor,
                                ),
                        ),
                      ),
                    ),
                    // Decline: same as card – show only when not pending (API allows cancellation only for paid)
                    if (booking.status != 'pending') ...[
                      SizedBox(width: 16.w),
                      Expanded(
                        child: GestureDetector(
                          onTap: widget.onReject,
                          child: Container(
                            height: 48.h,
                            decoration: BoxDecoration(
                              color: AppColors.grey300Color,
                              borderRadius: BorderRadius.circular(24.r),
                            ),
                            alignment: Alignment.center,
                            child: InterText(
                              text: 'sitter_decline'.tr,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.grey700Color,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

              SizedBox(height: 40.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final noPetsText = 'sitter_no_pets'.tr;
    final isPlaceholder =
        (value.startsWith('sitter_no_'.tr.substring(0, 7)) ||
            value.toLowerCase().contains('no ')) &&
        value != noPetsText;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20.sp, color: AppColors.primaryColor),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InterText(
                text: '$label:',
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.greyText,
              ),
              SizedBox(height: 2.h),
              InterText(
                text: value,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: isPlaceholder
                    ? AppColors.greyColor
                    : AppColors.blackColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPetCard({
    required String petName,
    required String category,
    required String breed,
    required String details,
    required String traits,
    required String medication,
    required String imageUrl,
  }) {
    final typeBreed = [
      if (category.isNotEmpty) category,
      if (breed.isNotEmpty) breed,
    ].join(', ');
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.grey300Color),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 32.r,
            backgroundColor: AppColors.grey300Color,
            backgroundImage: imageUrl.isNotEmpty
                ? CachedNetworkImageProvider(imageUrl)
                : null,
            child: imageUrl.isEmpty
                ? Icon(Icons.pets, size: 32.sp, color: AppColors.greyColor)
                : null,
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InterText(
                  text: petName,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.blackColor,
                ),
                if (typeBreed.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  InterText(
                    text: typeBreed,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.greyText,
                  ),
                ],
                if (details.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  InterText(
                    text: details,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.greyText,
                  ),
                ],
                if (traits.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  InterText(
                    text: traits,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.greyText,
                  ),
                ],
                if (medication.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  InterText(
                    text: medication,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryColor,
                  ),
                ],
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 14.sp,
            color: AppColors.greyColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(BookingModel booking) {
    final statusLower = booking.status.toLowerCase();
    final paymentStatusLower = booking.paymentStatus?.toLowerCase();

    Color backgroundColor;
    Color textColor;
    IconData icon;
    String displayText;

    // Determine the primary status to display (booking + payment)
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
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        icon = Icons.pending;
        displayText = 'PENDING';
        break;
      case 'agreed':
        backgroundColor = AppColors.primaryColor.withOpacity(0.1);
        textColor = AppColors.primaryColor;
        icon = Icons.check_circle;
        displayText = 'AGREED';
        break;
      case 'paid':
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        icon = Icons.check_circle_outline;
        displayText = 'PAID';
        break;
      case 'payment_pending':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        icon = Icons.hourglass_empty;
        displayText = 'PAYMENT PENDING';
        break;
      case 'payment_failed':
        backgroundColor = AppColors.errorColor.withOpacity(0.1);
        textColor = AppColors.errorColor;
        icon = Icons.error_outline;
        displayText = 'PAYMENT FAILED';
        break;
      case 'cancelled':
        backgroundColor = AppColors.errorColor.withOpacity(0.1);
        textColor = AppColors.errorColor;
        icon = Icons.cancel;
        displayText = 'CANCELLED';
        break;
      default:
        backgroundColor = AppColors.primaryColor.withOpacity(0.1);
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
            text: 'Status: $displayText',
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ],
      ),
    );
  }
}
