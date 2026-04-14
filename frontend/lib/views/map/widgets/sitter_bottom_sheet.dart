import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/models/sitter_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

Widget sitterBottomSheet(
  SitterModel sitter, {
  VoidCallback? onViewProfile,
  VoidCallback? onSendRequest,
}) {
  return SafeArea(
    child: Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30.r,
                backgroundColor: AppColors.greyColor.withOpacity(0.2),
                backgroundImage: sitter.avatar.url.isNotEmpty
                    ? NetworkImage(sitter.avatar.url)
                    : null,
                child: sitter.avatar.url.isEmpty
                    ? Icon(Icons.person, size: 30.sp, color: AppColors.greyText)
                    : null,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: PoppinsText(
                            text: sitter.name,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.blackColor,
                          ),
                        ),
                        if (sitter.identityVerified) ...[
                          SizedBox(width: 4.w),
                          Icon(Icons.verified, color: Colors.blue, size: 18.sp),
                        ],
                      ],
                    ),
                    SizedBox(height: 4.h),
                    InterText(
                      text: 'map_sitter_services_distance'.trParams({
                        'services': sitter.service.isNotEmpty
                            ? sitter.service.join(', ')
                            : 'label_not_available'.tr,
                        'distance': sitter.distanceKm != null
                            ? sitter.distanceKm!.toStringAsFixed(2)
                            : '—',
                      }),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.greyText,
                    ),
                    if (sitter.rating > 0) ...[
                      SizedBox(height: 4.h),
                      InterText(
                        text: 'sitter_rating_with_count'.trParams({
                          'rating': sitter.rating.toStringAsFixed(1),
                          'count': sitter.reviewsCount.toString(),
                        }),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        color: AppColors.greyText,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onViewProfile,
                  child: Container(
                    height: 44.h,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primaryColor),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Center(
                      child: InterText(
                        text: 'sitter_view_profile'.tr,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: GestureDetector(
                  onTap: onSendRequest,
                  child: Container(
                    height: 44.h,
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Center(
                      child: InterText(
                        text: 'service_card_send_request'.tr,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.whiteColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
        ],
      ),
    ),
  );
}
