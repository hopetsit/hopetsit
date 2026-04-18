import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/widgets/app_text.dart';

class PetSitterApplication {
  final String id;
  final String petName;
  final String petType;
  final String petImage;
  final String weight;
  final String height;
  final String color;
  final String date;
  final String time;
  final String phoneNumber;
  final String email;
  final String location;
  final String status; // 'pending', 'accepted', 'rejected'
  final String paymentStatus; // 'pending', 'paid', 'failed'
  final String ownerId; // Owner ID for starting chat

  PetSitterApplication({
    required this.id,
    required this.petName,
    required this.petType,
    required this.petImage,
    required this.weight,
    required this.height,
    required this.color,
    required this.date,
    required this.time,
    required this.phoneNumber,
    required this.email,
    required this.location,
    required this.ownerId,
    this.status = 'pending',
    this.paymentStatus = 'pending',
  });
}

class PetSitterApplicationCard extends StatefulWidget {
  final PetSitterApplication application;
  final Future<void> Function()? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onStartChat;

  const PetSitterApplicationCard({
    super.key,
    required this.application,
    this.onAccept,
    this.onReject,
    this.onStartChat,
  });

  @override
  State<PetSitterApplicationCard> createState() =>
      _PetSitterApplicationCardState();
}

class _PetSitterApplicationCardState extends State<PetSitterApplicationCard> {
  bool _isAccepting = false;
  bool _isRejecting = false;

  PetSitterApplication get application => widget.application;

  @override
  Widget build(BuildContext context) {
    final onStartChat = widget.onStartChat;
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.fromLTRB(20.w, 20.w, 0, 20.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(17.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pet Profile Section
          _buildPetProfileSection(),

          SizedBox(height: 10.h),

          // Details Section
          _buildDetailsSection(),

          SizedBox(height: 20.h),

          // Start Chat Button
          if (onStartChat != null)
            Padding(
              padding: EdgeInsets.only(bottom: 12.h, right: 16.w),
              child: GestureDetector(
                onTap: onStartChat,
                child: Center(
                  child: Container(
                    width: Get.size.width / 2,
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

          // Action Buttons
          if (application.status == 'pending') _buildActionButtons(context),
          SizedBox(height: 10.h),
          Padding(
            padding: EdgeInsets.only(right: 16.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (application.status != 'paid')
                  Flexible(child: _buildStatusChip(application.status)),
                // else
                //   Container(),

                // if (application.paymentStatus == 'paid')
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _buildPaymentStatusChip(application.paymentStatus),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetProfileSection() {
    return Row(
      children: [
        // Pet Profile Picture and Name
        // Column(
        //   crossAxisAlignment: CrossAxisAlignment.center,
        //   children: [
        //     CircleAvatar(
        //       radius: 45.r,
        //       backgroundColor: AppColors.greyColor.withValues(alpha: 0.3),
        //       backgroundImage:
        //           application.petImage.isNotEmpty &&
        //               (application.petImage.startsWith('http://') ||
        //                   application.petImage.startsWith('https://'))
        //           ? CachedNetworkImageProvider(application.petImage)
        //           : null,
        //       child:
        //           application.petImage.isEmpty ||
        //               (!application.petImage.startsWith('http://') &&
        //                   !application.petImage.startsWith('https://'))
        //           ? Icon(Icons.person, size: 40.sp, color: AppColors.greyColor)
        //           : null,
        //     ),
        //   ],
        // ),
        // SizedBox(width: 12.w),

        // Attribute Boxes
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildAttributeBox(
                  'sitter_pet_weight'.tr,
                  application.weight,
                  AppColors.primaryColor,
                ),
                SizedBox(width: 8.w),
                _buildAttributeBox(
                  'sitter_pet_height'.tr,
                  application.height,
                  AppColors.primaryColor,
                ),
                SizedBox(width: 8.w),
                _buildAttributeBox(
                  'sitter_pet_color'.tr,
                  application.color,
                  AppColors.primaryColor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttributeBox(String title, String value, Color valueColor) {
    final displayValue = value.isEmpty ? 'sitter_not_yet_available'.tr : value;
    return Container(
      height: 72.h,
      width: 78.w,
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 4.w),
      decoration: BoxDecoration(
        color: AppColors.detailBoxColor,
        borderRadius: BorderRadius.circular(17.r),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PoppinsText(
            text: title,
            fontSize: 10.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary(context),
          ),
          SizedBox(height: 4.h),
          Flexible(
            child: PoppinsText(
              text: displayValue,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: valueColor,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PoppinsText(
          text: application.petName,
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary(context),
        ),
        SizedBox(height: 12.h),
        _buildDetailRow(
          AppImages.calendarIcon,
          'sitter_detail_date'.tr,
          application.date,
        ),
        SizedBox(height: 12.h),
        _buildDetailRow(
          AppImages.timeIcon,
          'sitter_detail_time'.tr,
          application.time,
        ),
        SizedBox(height: 12.h),
        _buildDetailRow(
          AppImages.callIcon,
          'sitter_detail_phone'.tr,
          application.phoneNumber,
        ),
        SizedBox(height: 12.h),
        _buildDetailRow(
          AppImages.mailIcon,
          'sitter_detail_email'.tr,
          application.email,
        ),
        SizedBox(height: 12.h),
        _buildDetailRow(
          AppImages.locationIcon,
          'sitter_detail_location'.tr,
          application.location,
        ),
      ],
    );
  }

  Widget _buildDetailRow(String iconPath, String label, String value) {
    final displayValue = value.isEmpty ? 'sitter_not_available_yet'.tr : value;
    return Row(
      children: [
        Image.asset(
          iconPath,
          width: 25.w,
          height: 25.h,
          color: AppColors.primaryColor,
        ),
        SizedBox(width: 5.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InterText(
                text: displayValue,
                fontSize: 13.sp,
                fontWeight: FontWeight.w400,
                color: value.isEmpty ? AppColors.textSecondary(context) : AppColors.textSecondary(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final showReject = widget.application.status == 'pending';
    return Row(
      children: [
        if (showReject) ...[
          Expanded(
            child: GestureDetector(
              onTap: _isRejecting || _isAccepting || widget.onReject == null
                  ? null
                  : () async {
                      setState(() => _isRejecting = true);
                      try {
                        widget.onReject!();
                      } finally {
                        if (mounted) setState(() => _isRejecting = false);
                      }
                    },
              child: Container(
                height: 48.h,
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  border: Border.all(color: AppColors.primaryColor),
                  borderRadius: BorderRadius.circular(24.r),
                ),
                child: Center(
                  child: _isRejecting
                      ? SizedBox(
                          width: 22.w,
                          height: 22.h,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primaryColor,
                            ),
                          ),
                        )
                      : InterText(
                          text: 'sitter_reject'.tr,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryColor,
                        ),
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
        ],
        Expanded(
          child: GestureDetector(
            onTap: _isAccepting || _isRejecting
                ? null
                : () async {
                    if (widget.onAccept == null) return;
                    setState(() => _isAccepting = true);
                    try {
                      await widget.onAccept!();
                    } finally {
                      if (mounted) setState(() => _isAccepting = false);
                    }
                  },
            child: Container(
              height: 48.h,
              decoration: BoxDecoration(
                color: _isAccepting
                    ? AppColors.primaryColor.withValues(alpha: 0.7)
                    : AppColors.primaryColor,
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: Center(
                child: _isAccepting
                    ? SizedBox(
                        width: 22.w,
                        height: 22.h,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.whiteColor,
                          ),
                        ),
                      )
                    : InterText(
                        text: 'sitter_accept'.tr,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.whiteColor,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    final statusLower = status.toLowerCase();
    Color backgroundColor;
    Color textColor;
    IconData icon;
    String displayText;

    switch (statusLower) {
      case 'agreed':
        backgroundColor = AppColors.greenColor.withValues(alpha: 0.1);
        textColor = AppColors.greenColor;
        icon = Icons.check_circle;
        displayText = 'status_agreed_label'.tr;
        break;
      case 'pending':
        backgroundColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange;
        icon = Icons.timer;
        displayText = 'status_pending_label'.tr;
        break;
      case 'rejected':
        backgroundColor = AppColors.errorColor.withValues(alpha: 0.1);
        textColor = AppColors.errorColor;
        icon = Icons.close_rounded;
        displayText = 'status_rejected_label'.tr;
        break;
      default:
        backgroundColor = AppColors.greyColor.withValues(alpha: 0.1);
        textColor = AppColors.greyColor;
        icon = Icons.info;
        displayText = status.toUpperCase();
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
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: InterText(
                text: 'sitter_status_label'.tr.replaceAll(
                  '@status',
                  displayText,
                ),
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: textColor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStatusChip(String paymentStatus) {
    final statusLower = paymentStatus.toLowerCase();
    Color backgroundColor;
    Color textColor;
    IconData icon;
    String displayText;

    switch (statusLower) {
      case 'paid':
        backgroundColor = AppColors.greenColor.withValues(alpha: 0.1);
        textColor = AppColors.greenColor;
        icon = Icons.check_circle;
        displayText = 'status_paid_label'.tr.toUpperCase();
        break;
      case 'pending':
        backgroundColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange;
        icon = Icons.timer;
        displayText = 'status_pending_label'.tr.toUpperCase();
        break;
      case 'rejected':
        backgroundColor = AppColors.errorColor.withValues(alpha: 0.1);
        textColor = AppColors.errorColor;
        icon = Icons.close_rounded;
        displayText = 'status_rejected_label'.tr;
        break;
      default:
        backgroundColor = AppColors.greyColor.withValues(alpha: 0.1);
        textColor = AppColors.greyColor;
        icon = Icons.info;
        displayText = paymentStatus.toUpperCase();
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
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: InterText(
                text: 'sitter_payment_status_label'.tr.replaceAll(
                  '@status',
                  displayText,
                ),
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: textColor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
