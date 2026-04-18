import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/views/auth/location_picker_map_screen.dart';

class CityLocationPicker extends StatelessWidget {
  final TextEditingController cityController;
  final VoidCallback onGetLocation;
  final bool isGettingLocation;
  final String detectedCity;
  final Function(String city, double latitude, double longitude)?
  onLocationSelected;

  const CityLocationPicker({
    super.key,
    required this.cityController,
    required this.onGetLocation,
    required this.isGettingLocation,
    this.detectedCity = '',
    this.onLocationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InterText(
              text: 'label_city'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.blackColor,
            ),
            Row(
              children: [
                // Auto-detect button
                GestureDetector(
                  onTap: isGettingLocation ? null : onGetLocation,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.primaryColor,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isGettingLocation)
                          SizedBox(
                            width: 14.w,
                            height: 14.h,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryColor,
                              ),
                            ),
                          )
                        else
                          Icon(
                            Icons.location_on,
                            color: AppColors.primaryColor,
                            size: 14.sp,
                          ),
                        SizedBox(width: 6.w),
                        InterText(
                          text: isGettingLocation
                              ? 'location_getting'.tr
                              : 'location_auto'.tr,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                // Map picker button
                GestureDetector(
                  onTap: () async {
                    final result = await Get.to(
                      () => const LocationPickerMapScreen(),
                    );
                    if (result != null && result is Map<String, dynamic>) {
                      cityController.text = result['city'] ?? '';
                      onLocationSelected?.call(
                        result['city'] ?? '',
                        result['latitude'] ?? 0.0,
                        result['longitude'] ?? 0.0,
                      );
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.primaryColor,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.map,
                          color: AppColors.primaryColor,
                          size: 14.sp,
                        ),
                        SizedBox(width: 6.w),
                        InterText(
                          text: 'location_map'.tr,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: cityController,
          decoration: InputDecoration(
            hintText: detectedCity.isNotEmpty
                ? 'location_detected'.tr.replaceAll('@city', detectedCity)
                : 'location_enter_city'.tr,
            hintStyle: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.greyColor,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24.r),
              borderSide: BorderSide(color: AppColors.grey300Color, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24.r),
              borderSide: BorderSide(color: AppColors.grey300Color, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24.r),
              borderSide: BorderSide(color: AppColors.primaryColor, width: 1.5),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 12.h,
            ),
            suffixIcon: detectedCity.isNotEmpty
                ? Padding(
                    padding: EdgeInsets.only(right: 8.w),
                    child: Icon(
                      Icons.check_circle,
                      color: AppColors.primaryColor,
                      size: 20.sp,
                    ),
                  )
                : null,
          ),
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.blackColor,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'error_city_required'.tr;
            }
            return null;
          },
        ),
        if (detectedCity.isNotEmpty) ...[
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(
                color: AppColors.primaryColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.primaryColor,
                  size: 16.sp,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: InterText(
                    text: 'location_detected_message'.tr,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.primaryColor,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
