import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

class PetSitterRequestCard extends StatelessWidget {
  final String petName;
  final String petOwnerName;
  final String description;
  final String? ownerAvatar;
  final String ownerId;
  final String? petId;

  /// Optional: location (e.g. city) to show on card.
  final String? locationLabel;

  /// Optional: date range text (e.g. "25 Feb – 28 Feb") to show on card.
  final String? dateRangeLabel;

  /// Optional: service types (e.g. "Boarding, Walking") to show on card.
  final String? serviceTypesLabel;
  final bool isLoading;
  final bool showSendRequestButton;
  final VoidCallback? onSendRequest;
  final VoidCallback? onCardTap;

  const PetSitterRequestCard({
    super.key,
    required this.petName,
    required this.petOwnerName,
    required this.description,
    required this.ownerId,
    this.ownerAvatar,
    this.petId,
    this.locationLabel,
    this.dateRangeLabel,
    this.serviceTypesLabel,
    this.isLoading = false,
    this.showSendRequestButton = true,
    this.onSendRequest,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCardTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.circular(17.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Profile Picture with border
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryColor,
                      width: 2.w,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 25.r,
                    backgroundColor: AppColors.grey300Color,
                    backgroundImage:
                        ownerAvatar != null &&
                            ownerAvatar!.isNotEmpty &&
                            (ownerAvatar!.startsWith('http://') ||
                                ownerAvatar!.startsWith('https://'))
                        ? CachedNetworkImageProvider(ownerAvatar!)
                        : null,
                    child:
                        ownerAvatar == null ||
                            ownerAvatar!.isEmpty ||
                            (!ownerAvatar!.startsWith('http://') &&
                                !ownerAvatar!.startsWith('https://'))
                        ? Icon(
                            Icons.person,
                            size: 25.sp,
                            color: AppColors.greyColor,
                          )
                        : null,
                  ),
                ),
                SizedBox(width: 12.w),

                // Name and Pet Owner info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InterText(
                        text: petName,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.blackColor,
                      ),
                      SizedBox(height: 2.h),
                      InterText(
                        text: 'request_card_pet_owner'.trParams({
                          'name': petOwnerName,
                        }),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w300,
                        color: AppColors.greyText,
                      ),
                    ],
                  ),
                ),

                // Send Request Button (optional)
                if (showSendRequestButton)
                  GestureDetector(
                    onTap: isLoading ? null : onSendRequest,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 15.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primaryColor),
                        borderRadius: BorderRadius.circular(21.r),
                      ),
                      child: isLoading
                          ? SizedBox(
                              width: 12.w,
                              height: 12.h,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primaryColor,
                                ),
                              ),
                            )
                          : PoppinsText(
                              text: 'service_card_send_request'.tr,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w400,
                              color: AppColors.greyText,
                            ),
                    ),
                  ),
              ],
            ),
            Divider(color: AppColors.greyText.withValues(alpha: 0.2)),
            SizedBox(height: 12.h),

            // Description
            InterText(
              text: description,
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.grey500Color,
            ),

            // Optional details (location, dates, service type)
            if (locationLabel != null ||
                dateRangeLabel != null ||
                serviceTypesLabel != null) ...[
              SizedBox(height: 10.h),
              Wrap(
                spacing: 10.w,
                runSpacing: 6.h,
                children: [
                  if (locationLabel != null && locationLabel!.isNotEmpty)
                    _detailChip(
                      icon: Icons.location_on_outlined,
                      label: locationLabel!,
                    ),
                  if (dateRangeLabel != null && dateRangeLabel!.isNotEmpty)
                    _detailChip(
                      icon: Icons.calendar_today_outlined,
                      label: dateRangeLabel!,
                    ),
                  if (serviceTypesLabel != null &&
                      serviceTypesLabel!.isNotEmpty)
                    _detailChip(
                      icon: Icons.pets_outlined,
                      label: serviceTypesLabel!,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _detailChip({required IconData icon, required String label}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.chatFieldColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.grey300Color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: AppColors.greyText),
          SizedBox(width: 6.w),
          InterText(
            text: label,
            fontSize: 12.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.grey700Color,
          ),
        ],
      ),
    );
  }
}
