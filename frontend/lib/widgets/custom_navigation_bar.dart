import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/widgets/notification_badge.dart';

class CustomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70.h,
      margin: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.primaryColor,
        borderRadius: BorderRadius.circular(100.r),
        // boxShadow: [
        //   BoxShadow(
        //     color: AppColors.primaryColor.withOpacity(0.3),
        //     blurRadius: 10,
        //     offset: const Offset(0, 5),
        //   ),
        // ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(0, AppImages.pawIcon, 'Home'),
          _buildNavItem(1, AppImages.chatIcon, 'Chat'),
          _buildNavItem(2, AppImages.calendarIcon, 'Calendar'),
          _buildNavItem(3, AppImages.personIcon, 'Profile'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String iconPath, String label) {
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        // Sprint 4 step 4 — clear the corresponding badge when the user opens the tab.
        if (Get.isRegistered<NotificationsController>()) {
          final nc = Get.find<NotificationsController>();
          if (index == 1) nc.clearChatBadge();
          if (index == 2) nc.clearBookingsBadge();
        }
        onTap(index);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 8.h),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              width: 4,
              color: isSelected
                  ? AppColors.purpleLineNavigation
                  : Colors.transparent,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Image.asset(
                  iconPath,
                  width: 24.w,
                  height: 24.h,
                  color: isSelected ? AppColors.whiteColor : AppColors.whiteColor,
                ),
                if (index == 1 || index == 2)
                  Positioned(
                    top: -6.h,
                    right: -8.w,
                    child: Obx(() {
                      if (!Get.isRegistered<NotificationsController>()) {
                        return const SizedBox.shrink();
                      }
                      final nc = Get.find<NotificationsController>();
                      final count = index == 1
                          ? nc.unreadChat.value
                          : nc.unreadBookings.value;
                      return NotificationBadge(count: count);
                    }),
                  ),
              ],
            ),
            // SizedBox(height: 4.h),
            // Text(
            //   label,
            //   style: TextStyle(
            //     fontSize: 10.sp,
            //     fontWeight: FontWeight.w500,
            //     color: isSelected
            //         ? AppColors.whiteColor
            //         : AppColors.whiteColor.withOpacity(0.7),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
