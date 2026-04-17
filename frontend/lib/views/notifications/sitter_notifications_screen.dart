import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/models/app_notification_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/notification_card.dart';
import 'package:hopetsit/views/notifications/notification_sitter_application_card_view_screen.dart';

class SitterNotificationsScreen extends StatefulWidget {
  const SitterNotificationsScreen({super.key});

  @override
  State<SitterNotificationsScreen> createState() =>
      _SitterNotificationsScreenState();
}

class _SitterNotificationsScreenState extends State<SitterNotificationsScreen> {
  final ScrollController _scrollController = ScrollController();

  NotificationsController get _c {
    if (!Get.isRegistered<NotificationsController>()) {
      return Get.put(NotificationsController(), permanent: true);
    }
    return Get.find<NotificationsController>();
  }

  bool _isRequestAccepted(AppNotificationModel n) {
    final t = n.type.toLowerCase();
    return t == 'application_accepted' || t.contains('application_accepted');
  }

  bool _isNewBookingRequest(AppNotificationModel n) {
    final t = n.type.toLowerCase();
    return t == 'booking_new' || t.contains('booking_new');
  }

  String? _dataString(Map<String, dynamic> data, String key) {
    final v = data[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  Future<void> _onTapNotification(AppNotificationModel n) async {
    await _c.markAsRead(n);

    if (!context.mounted) return;
    final bookingId = _dataString(n.data, 'bookingId');
    if (bookingId == null || bookingId.isEmpty) {
      CustomSnackbar.showWarning(
        title: 'common_error'.tr,
        message: 'notifications_application_not_found'.tr,
      );
      return;
    }

    if (_isNewBookingRequest(n)) {
      Get.to(
        () => NotificationSitterNewRequestCardViewScreen(bookingId: bookingId),
      );
      return;
    }

    if (_isRequestAccepted(n)) {
      Get.to(
        () => NotificationSitterAcceptedCardViewScreen(bookingId: bookingId),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _c.loadInitial();
    });
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 160) {
        _c.loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: AppColors.appBar(context),
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        title: InterText(
          text: 'notifications_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
        actions: [
          Obx(() {
            final hasUnread = _c.notifications.any((e) => e.isUnread);
            if (!hasUnread) return const SizedBox.shrink();
            return TextButton(
              onPressed: () async => _c.markAllAsRead(),
              child: InterText(
                text: 'notifications_mark_all_read'.tr,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryColor,
              ),
            );
          }),
        ],
      ),
      body: Obx(() {
        if (_c.isLoading.value && _c.notifications.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final relevant = _c.notifications
            .where((n) => _isRequestAccepted(n) || _isNewBookingRequest(n))
            .toList();

        if (relevant.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_none_rounded,
                      size: 56.sp,
                      color: AppColors.primaryColor.withValues(alpha: 0.8),
                    ),
                  ),
                  SizedBox(height: 24.h),
                  InterText(
                    text: 'notifications_empty_title'.tr,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.blackColor,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8.h),
                  InterText(
                    text: 'notifications_empty_subtitle'.tr,
                    fontSize: 14.sp,
                    color: AppColors.grey700Color,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.primaryColor,
          onRefresh: () => _c.refreshAll(),
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 100.h),
            itemCount: relevant.length + (_c.isLoadingMore.value ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= relevant.length) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  child: Center(
                    child: SizedBox(
                      width: 24.w,
                      height: 24.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ),
                );
              }

              final item = relevant[index];
              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: NotificationCard(
                  notification: item,
                  onTap: () => _onTapNotification(item),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
