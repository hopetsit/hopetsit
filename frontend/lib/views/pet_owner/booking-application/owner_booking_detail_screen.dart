import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/string_utils.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Detail screen for a booking (owner view).
/// Shows: Service Provider (sitter card), Pets, Note, Pay/Chat/Cancel actions.
class OwnerBookingDetailScreen extends StatefulWidget {
  final BookingModel booking;
  final VoidCallback? onPay;
  final VoidCallback? onStartChat;
  final VoidCallback? onCancel;

  const OwnerBookingDetailScreen({
    super.key,
    required this.booking,
    this.onPay,
    this.onStartChat,
    this.onCancel,
  });

  @override
  State<OwnerBookingDetailScreen> createState() =>
      _OwnerBookingDetailScreenState();
}

class _OwnerBookingDetailScreenState extends State<OwnerBookingDetailScreen> {
  String _timeAgo(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return 'owner_time_just_now'.tr;
      if (diff.inMinutes < 60)
        return 'owner_time_mins_ago'.tr.replaceAll(
          '@minutes',
          diff.inMinutes.toString(),
        );
      if (diff.inHours < 24)
        return 'owner_time_hours_ago'.tr.replaceAll(
          '@hours',
          diff.inHours.toString(),
        );
      if (diff.inDays < 7)
        return 'owner_time_days_ago'.tr.replaceAll(
          '@days',
          diff.inDays.toString(),
        );
      return 'owner_time_days_ago'.tr.replaceAll(
        '@days',
        diff.inDays.toString(),
      );
    } catch (_) {
      return '';
    }
  }

  List<String> get _weekdays => [
    'owner_weekday_mon'.tr,
    'owner_weekday_tue'.tr,
    'owner_weekday_wed'.tr,
    'owner_weekday_thu'.tr,
    'owner_weekday_fri'.tr,
    'owner_weekday_sat'.tr,
    'owner_weekday_sun'.tr,
  ];
  List<String> get _months => [
    'owner_month_jan'.tr,
    'owner_month_feb'.tr,
    'owner_month_mar'.tr,
    'owner_month_apr'.tr,
    'owner_month_may'.tr,
    'owner_month_jun'.tr,
    'owner_month_jul'.tr,
    'owner_month_aug'.tr,
    'owner_month_sep'.tr,
    'owner_month_oct'.tr,
    'owner_month_nov'.tr,
    'owner_month_dec'.tr,
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
        return 'owner_service_long_term_care'.tr;
      case 'dog_walking':
        return 'owner_service_dog_walking'.tr;
      case 'overnight_stay':
        return 'owner_service_overnight_stay'.tr;
      case 'home_visit':
        return 'owner_service_home_visit'.tr;
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
    final sitter = booking.sitter;
    final city = sitter.city != null && sitter.city!.isNotEmpty
        ? sitter.city
        : '';
    final phone = sitter.mobile;
    final statusLower = booking.status.toLowerCase();
    final paymentStatusLower = booking.paymentStatus?.toLowerCase() ?? '';
    final isPaid = paymentStatusLower == 'paid';
    final isEligibleForPayment =
        (statusLower == 'agreed' ||
            statusLower == 'accepted' ||
            statusLower == 'confirmed') &&
        (paymentStatusLower.isEmpty ||
            paymentStatusLower == 'pending' ||
            paymentStatusLower == 'failed');

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: AppColors.lightGrey,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: PoppinsText(
          text: 'owner_booking_details_title'.tr,
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

              // Service Provider section – sitter card
              InterText(
                text: 'owner_service_provider_section'.tr,
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
                      backgroundImage: sitter.avatar.url.isNotEmpty
                          ? CachedNetworkImageProvider(sitter.avatar.url)
                          : null,
                      child: sitter.avatar.url.isEmpty
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
                            text: sitter.name,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.blackColor,
                          ),
                          if (city != null && city.isNotEmpty) ...[
                            SizedBox(height: 4.h),
                            InterText(
                              text: city,
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
                          if (sitter.rating > 0 && sitter.reviewsCount > 0) ...[
                            SizedBox(height: 8.h),
                            Row(
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 16.sp,
                                  color: Colors.amber,
                                ),
                                SizedBox(width: 4.w),
                                InterText(
                                  text: 'owner_rating_with_reviews'.tr
                                      .replaceAll(
                                        '@rating',
                                        sitter.rating.toStringAsFixed(1),
                                      )
                                      .replaceAll(
                                        '@count',
                                        sitter.reviewsCount.toString(),
                                      ),
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

              // Pet count, Service type, Date (below Service Provider card)
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
                      'owner_info_pets'.tr,
                      booking.pets.isNotEmpty
                          ? '${booking.pets.length}'
                          : (booking.petName.isNotEmpty
                                ? '1'
                                : 'owner_no_pets'.tr),
                    ),
                    SizedBox(height: 12.h),
                    _buildInfoRow(
                      Icons.calendar_today_outlined,
                      'owner_info_service'.tr,
                      _serviceTypeLabel(booking.serviceType).isNotEmpty
                          ? _serviceTypeLabel(booking.serviceType)
                          : 'owner_no_service_type'.tr,
                    ),
                    SizedBox(height: 12.h),
                    _buildInfoRow(
                      Icons.access_time,
                      'owner_info_date'.tr,
                      _formatBookingDate(
                            booking.date,
                            booking.timeSlot,
                          ).trim().isNotEmpty
                          ? _formatBookingDate(booking.date, booking.timeSlot)
                          : 'owner_no_date_available'.tr,
                    ),
                    if (booking.pricing != null ||
                        booking.totalAmount != null) ...[
                      SizedBox(height: 12.h),
                      _buildInfoRow(
                        Icons.attach_money,
                        'owner_info_total_amount'.tr,
                        '\$${(booking.pricing?.totalPrice ?? booking.totalAmount ?? 0.0).toStringAsFixed(2)}',
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              // Pets section
              InterText(
                text: 'owner_pets_section'.tr,
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
                          ? 'owner_pet_needs_medication'.tr.replaceAll(
                              '@medication',
                              pet.medicationAllergies,
                            )
                          : '',
                      imageUrl: pet.avatar.url,
                    ),
                  ),
                ),

              SizedBox(height: 24.h),

              // Note section
              InterText(
                text: 'owner_note_section'.tr,
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
                      : 'owner_no_note_provided'.tr,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: booking.description.isNotEmpty
                      ? AppColors.blackColor
                      : AppColors.greyText,
                ),
              ),

              SizedBox(height: 24.h),

              // Chat with Sitter – show when paid
              if (isPaid && widget.onStartChat != null)
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
                              text: 'owner_chat_with_sitter'.tr,
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

              // Pay / Cancel buttons
              if (isEligibleForPayment && widget.onPay != null)
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: widget.onPay,
                        child: Container(
                          height: 48.h,
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor,
                            borderRadius: BorderRadius.circular(24.r),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.payment,
                                color: AppColors.whiteColor,
                                size: 20.sp,
                              ),
                              SizedBox(width: 8.w),
                              InterText(
                                text: booking.totalAmount != null
                                    ? 'owner_pay_with_amount'.tr.replaceAll(
                                        '@amount',
                                        booking.totalAmount!.toStringAsFixed(2),
                                      )
                                    : 'owner_pay_now'.tr,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.whiteColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else if (!isPaid &&
                  (statusLower == 'pending' || statusLower == 'agreed') &&
                  widget.onCancel != null)
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: widget.onCancel,
                        child: Container(
                          height: 48.h,
                          decoration: BoxDecoration(
                            color: AppColors.grey300Color,
                            borderRadius: BorderRadius.circular(24.r),
                          ),
                          alignment: Alignment.center,
                          child: InterText(
                            text: 'owner_cancel_booking'.tr,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.grey700Color,
                          ),
                        ),
                      ),
                    ),
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
    final noPetsText = 'owner_no_pets'.tr;
    final isPlaceholder =
        (value.toLowerCase().contains('no ') ||
            value.startsWith('owner_no_')) &&
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
