import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopetsit/models/pet_map_item.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

Widget petBottomSheet(
  PetMapItem pet, {
  VoidCallback? onMessage,
  VoidCallback? onViewProfile,
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
                backgroundColor: AppColors.greyColor.withValues(alpha: 0.2),
                backgroundImage: pet.avatarUrl.isNotEmpty
                    ? NetworkImage(pet.avatarUrl)
                    : null,
                child: pet.avatarUrl.isEmpty
                    ? Icon(Icons.pets, size: 30.sp, color: AppColors.greyText)
                    : null,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PoppinsText(
                      text: pet.name,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.blackColor,
                    ),
                    SizedBox(height: 4.h),
                    InterText(
                      text:
                          '${pet.petType} • ${pet.distanceKm?.toStringAsFixed(2) ?? '—'} km',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.greyText,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              // Expanded(
              //   child: GestureDetector(
              //     onTap: onMessage,
              //     child: Container(
              //       height: 44.h,
              //       decoration: BoxDecoration(
              //         color: AppColors.primaryColor,
              //         borderRadius: BorderRadius.circular(12.r),
              //       ),
              //       child: Center(
              //         child: InterText(
              //           text: 'Message Owner',
              //           fontSize: 14.sp,
              //           fontWeight: FontWeight.w500,
              //           color: AppColors.whiteColor,
              //         ),
              //       ),
              //     ),
              //   ),
              // ),
              // SizedBox(width: 12.w),
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
                        text: 'View Profile',
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryColor,
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
