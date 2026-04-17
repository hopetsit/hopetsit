import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/applications_controller.dart';
import 'package:hopetsit/controllers/bookings_controller.dart';
import 'package:hopetsit/controllers/profile_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/pricing_display_helper.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/views/service_provider/widgets/service_provider_card.dart';
import 'package:hopetsit/widgets/custom_app_bar.dart';
import 'package:hopetsit/widgets/custom_confirmation_dialog.dart';
import 'package:hopetsit/views/booking/booking_agreement_screen.dart';
import 'package:hopetsit/views/payment/stripe_payment_screen.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/views/pet_owner/chat/individual_chat_screen.dart';

class ApplicationScreen extends StatefulWidget {
  const ApplicationScreen({super.key});

  @override
  State<ApplicationScreen> createState() => _ApplicationScreenState();
}

class _ApplicationScreenState extends State<ApplicationScreen> {
  int _selectedTabIndex = 0;
  late BookingsController _bookingsController;
  late ApplicationsController _applicationsController;

  @override
  void initState() {
    super.initState();
    _bookingsController = Get.put(BookingsController());
    _applicationsController = Get.put(ApplicationsController());
    Get.put(ProfileController());
  }

  @override
  Widget build(BuildContext context) {
    final profileController = Get.find<ProfileController>();
    return Obx(
      () => Scaffold(
        appBar: CustomAppBar(
          userName: profileController.userName.value.isNotEmpty
              ? profileController.userName.value
              : 'home_default_user_name'.tr,
          userImage: profileController.profileImageUrl.value.isNotEmpty
              ? profileController.profileImageUrl.value
              : '',
          showNotificationIcon:
              false, // Hide notification icon on application screen
          onProfileTap: () {
            // Handle profile tap
            // debug removed
          },
        ),
        backgroundColor: AppColors.scaffold(context),
        body: SafeArea(
          child: Column(
            children: [
              // Tab Navigation
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTabIndex = 0;
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          child: Column(
                            children: [
                              InterText(
                                text: 'applications_tab_title'.tr,
                                fontSize: 16.sp,
                                fontWeight: _selectedTabIndex == 0
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: _selectedTabIndex == 0
                                    ? AppColors.textPrimary(context)
                                    : AppColors.textSecondary(context),
                              ),
                              if (_selectedTabIndex == 0)
                                Container(
                                  margin: EdgeInsets.only(top: 8.h),
                                  height: 3.h,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryColor,
                                    borderRadius: BorderRadius.circular(1.r),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTabIndex = 1;
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          child: Column(
                            children: [
                              InterText(
                                text: 'bookings_tab_title'.tr,
                                fontSize: 16.sp,
                                fontWeight: _selectedTabIndex == 1
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: _selectedTabIndex == 1
                                    ? AppColors.textPrimary(context)
                                    : AppColors.textSecondary(context),
                              ),
                              if (_selectedTabIndex == 1)
                                Container(
                                  margin: EdgeInsets.only(top: 8.h),
                                  height: 3.h,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryColor,
                                    borderRadius: BorderRadius.circular(1.r),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content based on selected tab
              Expanded(
                child: _selectedTabIndex == 0
                    ? _buildApplicationsTab()
                    : _buildBookingTab(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApplicationsTab() {
    return Obx(() {
      if (_applicationsController.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
          ),
        );
      }

      if (_applicationsController.applications.isEmpty) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: InterText(
              text: 'applications_empty_message'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary(context),
            ),
          ),
        );
      }

      return RefreshIndicator(
        color: AppColors.primaryColor,
        onRefresh: () => _applicationsController.loadApplications(),
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(
            20.w,
            16.h,
            20.w,
            100.h,
          ), // Extra bottom padding for navigation bar
          itemCount: _applicationsController.applications.length,
          itemBuilder: (context, index) {
            final application = _applicationsController.applications[index];
            return ServiceProviderCard(
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
              onAccept: () async {
                // One-tap Accept & Pay. Flow:
                //  1) respond accept (backend may already include payment)
                //  2) if no clientSecret, force-create one via createPaymentIntent
                //  3) open Stripe PaymentSheet directly — no detour via Reservations
                final response = await _applicationsController
                    .respondToApplicationFull(
                      applicationId: application.id,
                      action: 'accept',
                    );
                if (response == null || !mounted) return;

                await _bookingsController.loadBookings();

                BookingModel? booking;
                String? clientSecret;

                final bookingJson = response['booking'];
                final payment = response['payment'];
                if (bookingJson is Map) {
                  try {
                    booking = BookingModel.fromJson(
                      Map<String, dynamic>.from(bookingJson as Map),
                    );
                  } catch (e) {
                    AppLogger.logError('Accept&Pay: failed to parse booking', error: e);
                  }
                }
                if (payment is Map) {
                  final cs = payment['clientSecret'] ?? payment['client_secret'];
                  if (cs is String && cs.isNotEmpty) clientSecret = cs;
                }

                // If the accept didn't include a booking (older backend),
                // reload bookings and pick the freshly-agreed one for this sitter.
                if (booking == null) {
                  await _bookingsController.loadBookings();
                  try {
                    booking = _bookingsController.bookings.firstWhere(
                      (b) =>
                          b.sitter.id == application.sitter.id &&
                          (b.status.toLowerCase() == 'agreed' ||
                              b.status.toLowerCase() == 'accepted' ||
                              b.status.toLowerCase() == 'confirmed') &&
                          (b.paymentStatus?.toLowerCase() ?? '') != 'paid',
                    );
                  } catch (_) {
                    booking = null;
                  }
                }

                // Fallback: backend didn't prepare a PaymentIntent. Ask it to
                // create one now so we never force the owner to hunt for a
                // "Pay" button in the Reservations tab.
                if (booking != null && (clientSecret == null || clientSecret.isEmpty)) {
                  try {
                    final ownerRepository = Get.find<OwnerRepository>();
                    final piResp = await ownerRepository.createPaymentIntent(
                      bookingId: booking.id,
                    );
                    final cs = piResp['clientSecret'] ?? piResp['client_secret'];
                    if (cs is String && cs.isNotEmpty) clientSecret = cs;
                  } catch (e) {
                    AppLogger.logError('Accept&Pay: createPaymentIntent failed', error: e);
                  }
                }

                if (booking != null && clientSecret != null && clientSecret.isNotEmpty) {
                  final pricing = booking.pricing;
                  final base = (pricing?.totalPrice
                      ?? pricing?.resolvedBaseAmount
                      ?? booking.totalAmount
                      ?? booking.basePrice) ?? 0.0;
                  if (!mounted) return;
                  await Get.to(
                    () => StripePaymentScreen(
                      booking: booking!,
                      totalAmount: base,
                      currency: pricing?.currency ?? booking.sitter.currency,
                    ),
                  );
                  return;
                }

                // True last-resort fallback: sitter has no Stripe Connect
                // configured. Warn clearly and switch to Reservations.
                if (payment is Map && payment['error'] != null) {
                  CustomSnackbar.showError(
                    title: 'payment_unavailable_title'.tr,
                    message: 'payment_unavailable_message'.tr,
                  );
                } else {
                  CustomSnackbar.showError(
                    title: 'common_error'.tr,
                    message: 'payment_unavailable_message'.tr,
                  );
                }
                if (!mounted) return;
                setState(() {
                  _selectedTabIndex = 1;
                });
              },
              onReject: () async {
                await _applicationsController.respondToApplication(
                  applicationId: application.id,
                  action: 'reject',
                );
              },
            );
          },
        ),
      );
    });
  }

  Widget _buildBookingTab() {
    return Obx(() {
      if (_bookingsController.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
          ),
        );
      }

      if (_bookingsController.bookings.isEmpty) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: InterText(
              text: 'bookings_empty_message'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary(context),
            ),
          ),
        );
      }

      return RefreshIndicator(
        color: AppColors.primaryColor,
        onRefresh: () => _bookingsController.loadBookings(),
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(
            20.w,
            16.h,
            20.w,
            100.h,
          ), // Extra bottom padding for navigation bar
          itemCount: _bookingsController.bookings.length,
          itemBuilder: (context, index) {
            final booking = _bookingsController.bookings[index];
            return ServiceProviderCard(
              name: booking.sitter.name,
              phoneNumber: booking.sitter.mobile,
              email: booking.sitter.email,
              rating: booking.sitter.rating,
              status: booking.status,
              reviewsCount: booking.sitter.reviewsCount,
              location: booking.sitter.city ?? '',
              isBlurred: true,
              pricePerHour: PricingDisplayHelper.serviceProviderCardPriceTail(
                pricing: booking.pricing,
                hourlyRate: booking.sitter.hourlyRate,
              ),
              currencyCode: booking.sitter.currency,
              profileImagePath: booking.sitter.avatar.url.isNotEmpty
                  ? booking.sitter.avatar.url
                  : null,
              sitterId: booking.sitter.id,
              cardType: ServiceProviderCardType.booking,
              booking: booking,
              onCancel: () {
                _showCancelBookingDialog(
                  context,
                  booking.id,
                  booking.sitter.id,
                );
              },
              onPay: () async {
                // Skip the intermediate "Booking agreement" screen — go
                // straight to Stripe PaymentSheet. Create the PaymentIntent
                // on the fly if the booking doesn't already have one.
                try {
                  final ownerRepository = Get.find<OwnerRepository>();
                  final piResp = await ownerRepository.createPaymentIntent(
                    bookingId: booking.id,
                  );
                  final cs = piResp['clientSecret'] ?? piResp['client_secret'];
                  if (cs is String && cs.isNotEmpty) {
                    final pricing = booking.pricing;
                    final base = (pricing?.totalPrice
                        ?? pricing?.resolvedBaseAmount
                        ?? booking.totalAmount
                        ?? booking.basePrice) ?? 0.0;
                    if (!mounted) return;
                    await Get.to(
                      () => StripePaymentScreen(
                        booking: booking,
                        totalAmount: base,
                        currency: pricing?.currency ?? booking.sitter.currency,
                      ),
                    );
                    return;
                  }
                } catch (e) {
                  AppLogger.logError('onPay: createPaymentIntent failed', error: e);
                }
                // Fallback — old behaviour if PI creation fails.
                Get.to(
                  () => BookingAgreementScreen(
                    booking: booking,
                    totalPrice: booking.totalAmount ?? booking.basePrice,
                  ),
                );
              },
              onStartChat: booking.paymentStatus == 'paid'
                  ? () async {
                      await _handleStartChatForBooking(
                        booking.sitter.id,
                        booking.sitter.name,
                        booking.sitter.avatar.url.isNotEmpty
                            ? booking.sitter.avatar.url
                            : '',
                      );
                    }
                  : null,
            );
          },
        ),
      );
    });
  }

  void _showCancelBookingDialog(
    BuildContext context,
    String bookingId,
    String sitterId,
  ) {
    CustomConfirmationDialog.show(
      context: context,
      message: 'booking_cancel_dialog_message'.tr,
      yesText: 'common_yes'.tr,
      cancelText: 'common_cancel'.tr,
      onYes: () {
        _bookingsController.cancelBooking(
          bookingId: bookingId,
          sitterId: sitterId,
        );
      },
    );
  }

  Future<void> _handleStartChatForBooking(
    String sitterId,
    String sitterName,
    String sitterImage,
  ) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
          ),
        ),
      );

      final ownerRepository = Get.find<OwnerRepository>();
      final response = await ownerRepository.startConversation(
        sitterId: sitterId,
      );

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Extract conversation ID from response
      String? conversationId;
      if (response['conversation'] != null && response['conversation'] is Map) {
        conversationId = response['conversation']['id']?.toString();
      }

      if (conversationId != null && conversationId.isNotEmpty) {
        // Navigate to chat screen
        if (mounted) {
          Get.to(
            () => IndividualChatScreen(
              conversationId: conversationId!,
              contactName: sitterName,
              contactImage: sitterImage.isNotEmpty ? sitterImage : '',
            ),
          );
        }
      } else {
        if (mounted) {
          CustomSnackbar.showError(
            title: 'common_error'.tr,
            message: 'snackbar_text_failed_to_start_conversation_please_try_again',
          );
        }
      }
    } on ApiException catch (e) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.pop(context);
      }
      AppLogger.logError('Failed to start conversation', error: e.message);
      if (mounted) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: e.message,
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.pop(context);
      }
      AppLogger.logError('Failed to start conversation', error: e);
      if (mounted) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: e.toString().contains('Exception')
              ? e.toString().split(':').last.trim()
              : 'Failed to start conversation. Please try again.',
        );
      }
    }
  }
}
