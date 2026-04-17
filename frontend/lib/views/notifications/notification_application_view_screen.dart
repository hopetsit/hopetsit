import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/applications_controller.dart';
import 'package:hopetsit/controllers/bookings_controller.dart';
import 'package:hopetsit/models/application_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/pricing_display_helper.dart';
import 'package:hopetsit/views/service_provider/service_provider_detail_screen.dart';
import 'package:hopetsit/views/service_provider/widgets/service_provider_card.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Shows one sitter request as the same [ServiceProviderCard] used on Applications tab.
class NotificationApplicationViewScreen extends StatefulWidget {
  const NotificationApplicationViewScreen({
    super.key,
    required this.applicationId,
    this.sitterIdFallback,
  });

  final String applicationId;
  final String? sitterIdFallback;

  @override
  State<NotificationApplicationViewScreen> createState() =>
      _NotificationApplicationViewScreenState();
}

class _NotificationApplicationViewScreenState
    extends State<NotificationApplicationViewScreen> {
  late final ApplicationsController _applicationsController;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<ApplicationsController>()) {
      Get.put(ApplicationsController());
    }
    _applicationsController = Get.find<ApplicationsController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applicationsController.loadApplications();
    });
  }

  ApplicationModel? _findApplication() {
    for (final a in _applicationsController.applications) {
      if (a.id == widget.applicationId) return a;
    }
    return null;
  }

  Future<void> _onAccept(ApplicationModel application) async {
    final ok = await _applicationsController.respondToApplication(
      applicationId: application.id,
      action: 'accept',
    );
    if (!mounted) return;
    if (ok) {
      if (Get.isRegistered<BookingsController>()) {
        await Get.find<BookingsController>().loadBookings();
      }
      Get.back();
    }
  }

  Future<void> _onReject(ApplicationModel application) async {
    final ok = await _applicationsController.respondToApplication(
      applicationId: application.id,
      action: 'reject',
    );
    if (!mounted) return;
    if (ok) {
      Get.back();
    }
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
          text: 'notifications_request_view_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: Obx(() {
        final loading =
            _applicationsController.isLoading.value &&
            _applicationsController.applications.isEmpty;
        if (loading) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primaryColor),
          );
        }

        final application = _findApplication();
        if (application == null) {
          return Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InterText(
                  text: 'notifications_application_not_found'.tr,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.grey700Color,
                  textAlign: TextAlign.center,
                ),
                if (widget.sitterIdFallback != null &&
                    widget.sitterIdFallback!.isNotEmpty) ...[
                  SizedBox(height: 20.h),
                  TextButton(
                    onPressed: () {
                      Get.to(
                        () => ServiceProviderDetailScreen(
                          sitterId: widget.sitterIdFallback!,
                          status: 'pending',
                        ),
                      );
                    },
                    child: InterText(
                      text: 'notifications_open_sitter_profile'.tr,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
          child: ServiceProviderCard(
            name: application.sitter.name,
            phoneNumber: application.sitter.mobile,
            email: application.sitter.email,
            rating: application.sitter.rating,
            status: application.status,
            reviewsCount: application.sitter.reviewsCount,
            location: application.sitter.city ?? '',
              pricePerHour: PricingDisplayHelper.serviceProviderCardPriceTail(
                pricing: application.pricing,
                hourlyRate: application.sitter.hourlyRate,
              ),
            currencyCode: application.sitter.currency,
            profileImagePath: application.sitter.avatar.url.isNotEmpty
                ? application.sitter.avatar.url
                : null,
            sitterId: application.sitter.id,
            isBlurred: true,
            cardType: ServiceProviderCardType.application,
            onAccept: () => _onAccept(application),
            onReject: () => _onReject(application),
          ),
        );
      }),
    );
  }
}
