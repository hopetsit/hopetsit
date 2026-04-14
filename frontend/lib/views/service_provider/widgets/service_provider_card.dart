import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/views/service_provider/service_provider_detail_screen.dart';
import 'package:hopetsit/views/pet_owner/booking-application/owner_booking_detail_screen.dart';

enum ServiceProviderCardType { home, application, booking }

class ServiceProviderCard extends StatefulWidget {
  final String name;
  final String phoneNumber;
  final String email;
  final double rating;
  final int? reviewsCount;
  final String location;
  final String status;
  final String pricePerHour;
  final String? profileImagePath;
  final bool? isBlurred;
  final bool? showStatusChip;
  final String? sitterId;
  final VoidCallback? onSendRequest;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;
  final VoidCallback? onBlock;
  final VoidCallback? onPay; // Payment callback
  final VoidCallback? onStartChat; // Start chat callback for paid bookings
  final ServiceProviderCardType cardType;
  final BookingModel? booking; // Booking model for payment status
  /// Currency code for hourly rate display (e.g. USD, EUR). Defaults to EUR.
  final String currencyCode;
  /// Sprint 5 UI step 4 — show a blue verified badge next to the name.
  final bool identityVerified;

  const ServiceProviderCard({
    super.key,
    required this.name,
    required this.phoneNumber,
    required this.email,
    required this.rating,
    this.showStatusChip = true,
    this.reviewsCount,
    this.isBlurred = false,
    required this.location,
    required this.status,
    required this.pricePerHour,
    this.profileImagePath,
    this.sitterId,
    this.onSendRequest,
    this.onAccept,
    this.onReject,
    this.onCancel,
    this.onBlock,
    this.onPay,
    this.onStartChat,
    this.cardType = ServiceProviderCardType.home,
    this.booking,
    this.currencyCode = CurrencyHelper.eur,
    this.identityVerified = false,
  });

  @override
  State<ServiceProviderCard> createState() => _ServiceProviderCardState();
}

class _ServiceProviderCardState extends State<ServiceProviderCard> {
  late bool isPhoneLocked;
  late bool isEmailLocked;
  bool _isAccepting = false;
  bool _isRejecting = false;

  @override
  void initState() {
    super.initState();
    isPhoneLocked = widget.isBlurred ?? false;
    isEmailLocked = widget.isBlurred ?? false;
  }

  String getMaskedPhoneNumber(String phone) {
    if (phone.isEmpty) return '';
    return '****${phone.replaceRange(0, phone.length - 4, '')}';
  }

  String getMaskedEmail(String email) {
    if (email.isEmpty) return '';
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    return '${name[0]}${'*' * (name.length - 1)}@${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to booking detail screen if it's a booking card
        if (widget.cardType == ServiceProviderCardType.booking &&
            widget.booking != null) {
          Get.to(
            () => OwnerBookingDetailScreen(
              booking: widget.booking!,
              onPay: widget.onPay,
              onStartChat: widget.onStartChat,
              onCancel: widget.onCancel,
            ),
          );
        } else if (widget.sitterId != null && widget.sitterId!.isNotEmpty) {
          // Navigate to service provider detail screen for other card types
          Get.to(
            () => ServiceProviderDetailScreen(
              sitterId: widget.sitterId!,
              status: widget.status,
              booking: widget.booking,
            ),
          );
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.circular(11.r),
          border: Border.all(color: AppColors.textFieldBorder, width: 1.w),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Picture and Info
                Row(
                  children: [
                    widget.profileImagePath != null &&
                            (widget.profileImagePath!.startsWith('http://') ||
                                widget.profileImagePath!.startsWith('https://'))
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: widget.profileImagePath!,
                              width: 100.w,
                              height: 100.h,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 100.w,
                                height: 100.h,
                                color: AppColors.lightGrey,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  CircleAvatar(
                                    radius: 50.r,
                                    backgroundImage: AssetImage(
                                      AppImages.placeholderImage,
                                    ),
                                  ),
                            ),
                          )
                        : CircleAvatar(
                            radius: 50.r,
                            backgroundImage: AssetImage(
                              widget.profileImagePath ??
                                  AppImages.placeholderImage,
                            ),
                          ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right:
                              widget.cardType ==
                                  ServiceProviderCardType.application
                              ? 80.w
                              : 0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name + verified badge (sprint 5 UI step 4)
                            Row(
                              children: [
                                Flexible(
                                  child: PoppinsText(
                                    text: widget.name,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.blackColor,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (widget.identityVerified) ...[
                                  SizedBox(width: 4.w),
                                  Tooltip(
                                    message: 'profile_identity_verified'.tr,
                                    child: Icon(
                                      Icons.verified,
                                      color: Colors.blue,
                                      size: 16.sp,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            SizedBox(height: 8.h),
                            // Contact Information
                            GestureDetector(
                              // onTap: () => setState(
                              //   () => isPhoneLocked = !isPhoneLocked,
                              // ),
                              child: _buildContactInfo(
                                AppImages.callIcon,
                                widget.phoneNumber.isNotEmpty
                                    ? widget.phoneNumber
                                    : 'service_card_no_phone'.tr,
                                isPhoneLocked,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            GestureDetector(
                              // onTap: () => setState(
                              //   () => isEmailLocked = !isEmailLocked,
                              // ),
                              child: _buildContactInfo(
                                AppImages.mailIcon,
                                widget.email,
                                isEmailLocked,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16.h),

                // Rating and Location
                Row(
                  children: [
                    // Stars (only show if rating > 0)
                    if (widget.rating > 0 &&
                        (widget.reviewsCount ?? 0) > 0) ...[
                      Row(
                        children: List.generate(5, (starIndex) {
                          return Icon(
                            starIndex < widget.rating.floor()
                                ? Icons.star
                                : Icons.star_border,
                            size: 16.sp,
                            color: starIndex < widget.rating.floor()
                                ? Colors.amber
                                : AppColors.greyText,
                          );
                        }),
                      ),
                      SizedBox(width: 8.w),
                      InterText(
                        text: widget.rating.toStringAsFixed(1),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        color: AppColors.greyText,
                      ),
                    ] else ...[
                      InterText(
                        text: 'sitter_detail_no_rating'.tr,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        color: AppColors.greyText,
                      ),
                    ],

                    SizedBox(width: 16.w),
                  ],
                ),
                // Location
                Row(
                  children: [
                    Image.asset(
                      AppImages.pinIcon,
                      width: 24.w,
                      height: 24.h,
                      color: AppColors.primaryColor,
                    ),
                    SizedBox(width: 4.w),

                    Expanded(
                      child: InterText(
                        text: widget.location.isNotEmpty
                            ? widget.location
                            : 'service_card_no_location'.tr,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
                        color: AppColors.greyText,
                      ),
                    ),
                  ],
                ),

                // Status Chip
                if (widget.showStatusChip == true) ...[
                  SizedBox(height: 5.h),
                  _buildStatusChip(),
                ],

                // Action Buttons
                if (widget.cardType == ServiceProviderCardType.home ||
                    (widget.cardType == ServiceProviderCardType.application &&
                        widget.status == 'pending') ||
                    widget.cardType == ServiceProviderCardType.booking) ...[
                  SizedBox(height: 16.h),
                  _buildActionButtons(),
                ],
              ],
            ),
            // More Options Icon or Price - Top Right
            if (widget.cardType != ServiceProviderCardType.booking)
              Positioned(
                top: 0,
                right: 0,
                child: widget.cardType == ServiceProviderCardType.application
                    ? Padding(
                        padding: EdgeInsets.all(8.w),
                        child: PoppinsText(
                          text:
                              '${CurrencyHelper.symbol(widget.currencyCode)}${widget.pricePerHour}',
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.blackColor,
                        ),
                      )
                    : PopupMenuButton<String>(
                        icon: Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: AppColors.whiteColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.more_vert,
                            color: AppColors.grey500Color,
                            size: 20.sp,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        elevation: 8,
                        color: AppColors.whiteColor,
                        itemBuilder: (BuildContext context) => [
                          PopupMenuItem<String>(
                            value: 'block',
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 8.h,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5.r),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(6.w),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryColor.withOpacity(
                                        0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(6.r),
                                    ),
                                    child: Icon(
                                      Icons.block,
                                      size: 18.sp,
                                      color: AppColors.primaryColor,
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: PoppinsText(
                                      text: 'service_card_block'.tr,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        onSelected: (String value) {
                          if (value == 'block') {
                            widget.onBlock?.call();
                          }
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }

  String _localizedStatusLabel(String status) {
    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'available':
      case 'online':
        return 'status_available_label'.tr;
      case 'cancelled':
        return 'status_cancelled_label'.tr;
      case 'rejected':
        return 'status_rejected_label'.tr;
      case 'pending':
        return 'status_pending_label'.tr;
      case 'agreed':
        return 'status_agreed_label'.tr;
      case 'paid':
        return 'status_paid_label'.tr;
      case 'accepted':
        return 'status_accepted_label'.tr;
      default:
        if (status.isEmpty) return status;
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  Widget _buildStatusChip() {
    final statusLower = widget.status.toLowerCase();
    Color backgroundColor;
    Color textColor;
    IconData icon;
    final displayText = _localizedStatusLabel(widget.status);

    switch (statusLower) {
      case 'available':
      case 'online':
        backgroundColor = AppColors.greenColor.withOpacity(0.1);
        textColor = AppColors.greenColor;
        icon = Icons.check_circle;
        break;
      case 'cancelled':
        backgroundColor = AppColors.errorColor.withOpacity(0.1);
        textColor = AppColors.errorColor;
        icon = Icons.cancel;
        break;
      case 'rejected':
        backgroundColor = AppColors.errorColor.withOpacity(0.1);
        textColor = AppColors.errorColor;
        icon = Icons.close_rounded;
        break;
      case 'pending':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        icon = Icons.timer;
        break;
      case 'agreed':
      case 'paid':
      case 'accepted':
        backgroundColor = AppColors.greenColor.withOpacity(0.1);
        textColor = AppColors.greenColor;
        icon = Icons.check_circle;
        break;
      default:
        backgroundColor = AppColors.greyColor.withOpacity(0.1);
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
            text: displayText,
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo(String iconPath, String text, bool isLocked) {
    final displayText = isLocked
        ? (iconPath == AppImages.callIcon
              ? getMaskedPhoneNumber(text)
              : getMaskedEmail(text))
        : text;

    return Row(
      children: [
        Icon(
          isLocked ? Icons.lock : Icons.lock_open,
          size: 20.sp,
          color: AppColors.grey500Color,
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: InterText(
            text: displayText,
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.greyColor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // SizedBox(width: 8.w),
        // Icon(
        //   isLocked ? Icons.lock : Icons.lock_open,
        //   size: 16.sp,
        //   color: AppColors.primaryColor,
        // ),
      ],
    );
  }

  Widget _buildActionButtons() {
    switch (widget.cardType) {
      case ServiceProviderCardType.home:
        final priceString =
            '${CurrencyHelper.symbol(widget.currencyCode)}${widget.pricePerHour}';
        return Row(
          children: [
            Expanded(
              child: Container(
                height: 48.h,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primaryColor),
                  borderRadius: BorderRadius.circular(48.r),
                ),
                child: Center(
                  child: InterText(
                    text: 'service_card_per_hour_label'.trParams({
                      'price': priceString,
                    }),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.greyText,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: GestureDetector(
                onTap:
                    widget.onSendRequest ??
                    () {
                      // Default navigation to send request screen
                    },
                child: Container(
                  height: 48.h,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor,
                    borderRadius: BorderRadius.circular(48.r),
                  ),
                  child: Center(
                    child: InterText(
                      text: 'service_card_send_request'.tr,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.whiteColor,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );

      case ServiceProviderCardType.application:
        return Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: (_isAccepting || _isRejecting || widget.onAccept == null)
                    ? null
                    : () async {
                        setState(() => _isAccepting = true);
                        try {
                          await Future.sync(() => widget.onAccept!.call());
                        } finally {
                          if (mounted) setState(() => _isAccepting = false);
                        }
                      },
                child: Container(
                  height: 48.h,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  decoration: BoxDecoration(
                    color: _isAccepting
                        ? AppColors.primaryColor.withOpacity(0.7)
                        : AppColors.primaryColor,
                    borderRadius: BorderRadius.circular(48.r),
                  ),
                  child: Center(
                    child: _isAccepting
                        ? SizedBox(
                            width: 20.w,
                            height: 20.h,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.whiteColor,
                              ),
                            ),
                          )
                        : InterText(
                            text: 'service_card_accept'.tr,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.whiteColor,
                          ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: GestureDetector(
                onTap: (_isAccepting || _isRejecting || widget.onReject == null)
                    ? null
                    : () async {
                        setState(() => _isRejecting = true);
                        try {
                          await Future.sync(() => widget.onReject!.call());
                        } finally {
                          if (mounted) setState(() => _isRejecting = false);
                        }
                      },
                child: Container(
                  height: 48.h,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primaryColor),
                    borderRadius: BorderRadius.circular(48.r),
                  ),
                  child: Center(
                    child: _isRejecting
                        ? SizedBox(
                            width: 20.w,
                            height: 20.h,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryColor,
                              ),
                            ),
                          )
                        : InterText(
                            text: 'service_card_reject'.tr,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.greyText,
                          ),
                  ),
                ),
              ),
            ),
          ],
        );

      case ServiceProviderCardType.booking:
        if (widget.booking == null) {
          // No booking data, show cancel button
          return Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: widget.onCancel,
                  child: Container(
                    height: 48.h,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primaryColor),
                      borderRadius: BorderRadius.circular(48.r),
                    ),
                    child: Center(
                      child: InterText(
                        text: 'service_card_cancel'.tr,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.greyText,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // Check if booking is cancelled
        final status = widget.booking!.status.toLowerCase().trim();
        if (status == 'cancelled' || widget.booking!.cancelledAt != null) {
          // Show no action buttons for cancelled bookings
          return SizedBox.shrink();
        }

        final paymentStatus = widget.booking!.paymentStatus
            ?.toLowerCase()
            .trim();

        // Booking is eligible for payment if:
        // 1. Status is 'agreed', 'accepted', or 'confirmed'
        // 2. Payment status is null, 'pending', 'failed', or anything other than 'paid'
        final isEligibleForPayment =
            (status == 'agreed' ||
                status == 'accepted' ||
                status == 'confirmed') &&
            (paymentStatus == null ||
                paymentStatus.isEmpty ||
                paymentStatus != 'paid');

        final isPaid = paymentStatus == 'paid';

        // Show Pay button if eligible for payment and onPay callback is provided
        if (isEligibleForPayment && widget.onPay != null) {
          return Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: widget.onPay,
                  child: Container(
                    height: 48.h,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor,
                      borderRadius: BorderRadius.circular(48.r),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.payment,
                            color: AppColors.whiteColor,
                            size: 18.sp,
                          ),
                          SizedBox(width: 8.w),
                          InterText(
                            text: widget.booking!.totalAmount != null
                                ? 'service_card_pay_with_amount'.trParams({
                                    'amount': CurrencyHelper.format(
                                      widget.currencyCode,
                                      widget.booking!.totalAmount!,
                                    ),
                                  })
                                : 'service_card_pay_now'.tr,
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
            ],
          );
        }

        // Show Cancel button for other booking statuses (but not for paid bookings)
        if (!isPaid) {
          return Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: widget.onCancel,
                  child: Container(
                    height: 48.h,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primaryColor),
                      borderRadius: BorderRadius.circular(48.r),
                    ),
                    child: Center(
                      child: InterText(
                        text: 'service_card_cancel'.tr,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.greyText,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // For paid bookings, show a chat button
        return Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap:
                    widget.onStartChat ??
                    () {
                      // Default: navigate to detail screen where chat can be started
                      if (widget.sitterId != null &&
                          widget.sitterId!.isNotEmpty) {
                        Get.to(
                          () => ServiceProviderDetailScreen(
                            sitterId: widget.sitterId!,
                            status: widget.status,
                            booking: widget.booking,
                          ),
                        );
                      }
                    },
                child: Container(
                  height: 48.h,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor,
                    borderRadius: BorderRadius.circular(48.r),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: AppColors.whiteColor,
                          size: 18.sp,
                        ),
                        SizedBox(width: 8.w),
                        InterText(
                          text: 'service_card_chat'.tr,
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
          ],
        );
    }
  }
}
