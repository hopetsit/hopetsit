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
import 'package:hopetsit/widgets/chat_access_upsell_helper.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/views/pet_owner/chat/individual_chat_screen.dart';

/// Represents a unified item that can be either an application or a booking.
class _UnifiedItem {
  final String type; // 'application' or 'booking'
  final dynamic data; // ApplicationModel or BookingModel
  final String sitterName;
  final String status;
  final String sitterId;

  _UnifiedItem({
    required this.type,
    required this.data,
    required this.sitterName,
    required this.status,
    required this.sitterId,
  });
}

class ApplicationScreen extends StatefulWidget {
  const ApplicationScreen({super.key});

  @override
  State<ApplicationScreen> createState() => _ApplicationScreenState();
}

class _ApplicationScreenState extends State<ApplicationScreen> {
  String _selectedFilter = 'all';
  late BookingsController _bookingsController;
  late ApplicationsController _applicationsController;

  @override
  void initState() {
    super.initState();
    _bookingsController = Get.put(BookingsController());
    _applicationsController = Get.put(ApplicationsController());
    Get.put(ProfileController());
  }

  /// Merge applications + bookings into one unified list
  List<_UnifiedItem> _buildUnifiedList() {
    final items = <_UnifiedItem>[];

    // Add applications
    for (final app in _applicationsController.applications) {
      items.add(_UnifiedItem(
        type: 'application',
        data: app,
        sitterName: app.sitter.name,
        status: app.status.toLowerCase().trim(),
        sitterId: app.sitter.id,
      ));
    }

    // Add bookings
    for (final booking in _bookingsController.bookings) {
      items.add(_UnifiedItem(
        type: 'booking',
        data: booking,
        sitterName: booking.sitter.name,
        status: booking.status.toLowerCase().trim(),
        sitterId: booking.sitter.id,
      ));
    }

    // Filter by selected status
    if (_selectedFilter != 'all') {
      return items.where((item) {
        switch (_selectedFilter) {
          case 'pending':
            return item.status == 'pending';
          case 'accepted':
            return item.status == 'accepted' || item.status == 'agreed' || item.status == 'confirmed';
          case 'paid':
            if (item.type == 'booking') {
              final b = item.data as BookingModel;
              return b.paymentStatus?.toLowerCase() == 'paid';
            }
            return false;
          case 'cancelled':
            return item.status == 'cancelled' || item.status == 'rejected';
          default:
            return true;
        }
      }).toList();
    }

    return items;
  }

  int _countByFilter(String filter) {
    final allItems = <_UnifiedItem>[];
    for (final app in _applicationsController.applications) {
      allItems.add(_UnifiedItem(type: 'application', data: app, sitterName: '', status: app.status.toLowerCase().trim(), sitterId: ''));
    }
    for (final b in _bookingsController.bookings) {
      allItems.add(_UnifiedItem(type: 'booking', data: b, sitterName: '', status: b.status.toLowerCase().trim(), sitterId: ''));
    }
    if (filter == 'all') return allItems.length;
    return allItems.where((item) {
      switch (filter) {
        case 'pending': return item.status == 'pending';
        case 'accepted': return item.status == 'accepted' || item.status == 'agreed' || item.status == 'confirmed';
        case 'paid':
          if (item.type == 'booking') return (item.data as BookingModel).paymentStatus?.toLowerCase() == 'paid';
          return false;
        case 'cancelled': return item.status == 'cancelled' || item.status == 'rejected';
        default: return true;
      }
    }).length;
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
          showNotificationIcon: false,
          onProfileTap: () {},
        ),
        backgroundColor: AppColors.scaffold(context),
        body: SafeArea(
          child: Column(
            children: [
              // ── Summary cards ──
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
                child: Row(
                  children: [
                    _summaryCard(
                      context,
                      icon: Icons.send_rounded,
                      label: 'applications_tab_title'.tr,
                      count: _applicationsController.applications.length,
                      color: const Color(0xFF1A73E8),
                    ),
                    SizedBox(width: 10.w),
                    _summaryCard(
                      context,
                      icon: Icons.event_note_rounded,
                      label: 'bookings_tab_title'.tr,
                      count: _bookingsController.bookings.length,
                      color: AppColors.primaryColor,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 12.h),

              // ── Status filter chips ──
              SizedBox(
                height: 38.h,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  children: [
                    _filterChip(context, 'all', 'unified_filter_all'.tr),
                    SizedBox(width: 8.w),
                    _filterChip(context, 'pending', 'unified_filter_pending'.tr),
                    SizedBox(width: 8.w),
                    _filterChip(context, 'accepted', 'unified_filter_accepted'.tr),
                    SizedBox(width: 8.w),
                    _filterChip(context, 'paid', 'unified_filter_paid'.tr),
                    SizedBox(width: 8.w),
                    _filterChip(context, 'cancelled', 'unified_filter_cancelled'.tr),
                  ],
                ),
              ),

              SizedBox(height: 8.h),

              // ── Unified list ──
              Expanded(child: _buildUnifiedContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(BuildContext context, {
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 12.w),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: AppColors.cardShadow(context),
        ),
        child: Row(
          children: [
            Container(
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, size: 18.sp, color: color),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PoppinsText(
                    text: count.toString(),
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                  InterText(
                    text: label,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(BuildContext context, String filter, String label) {
    final isSelected = _selectedFilter == filter;
    final count = _countByFilter(filter);

    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filter),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryColor : AppColors.card(context),
          borderRadius: BorderRadius.circular(20.r),
          border: isSelected ? null : Border.all(color: AppColors.divider(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InterText(
              text: label,
              fontSize: 12.sp,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? Colors.white : AppColors.textSecondary(context),
            ),
            if (count > 0) ...[
              SizedBox(width: 6.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.2) : AppColors.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: InterText(
                  text: count.toString(),
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.primaryColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedContent() {
    return Obx(() {
      final isLoading = _applicationsController.isLoading.value ||
          _bookingsController.isLoading.value;

      if (isLoading) {
        return const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
          ),
        );
      }

      final items = _buildUnifiedList();

      if (items.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox_rounded,
                size: 48.sp,
                color: AppColors.greyColor.withValues(alpha: 0.4),
              ),
              SizedBox(height: 12.h),
              InterText(
                text: _selectedFilter == 'all'
                    ? 'unified_empty_all'.tr
                    : 'unified_empty_filtered'.tr,
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary(context),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        color: AppColors.primaryColor,
        onRefresh: () async {
          await Future.wait([
            _applicationsController.loadApplications(),
            _bookingsController.loadBookings(),
          ]);
        },
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 100.h),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];

            // ── Type badge above the card ──
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type label
                Padding(
                  padding: EdgeInsets.only(left: 4.w, bottom: 4.h),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: item.type == 'application'
                              ? const Color(0xFF1A73E8).withValues(alpha: 0.1)
                              : AppColors.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: InterText(
                          text: item.type == 'application'
                              ? 'unified_type_application'.tr
                              : 'unified_type_booking'.tr,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                          color: item.type == 'application'
                              ? const Color(0xFF1A73E8)
                              : AppColors.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // The card
                item.type == 'application'
                    ? _buildApplicationCard(item.data)
                    : _buildBookingCard(item.data),
              ],
            );
          },
        ),
      );
    });
  }

  Widget _buildApplicationCard(dynamic application) {
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
              // ignore: unnecessary_cast
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

        // Session v17.1 — always navigate to the PaymentPage when a booking
        // was created, even if clientSecret is still missing. The payment
        // page will call createPaymentIntent on Pay-click and surface the
        // error there (instead of leaving the owner stuck on this screen
        // with no visible way to pay).
        if (booking != null) {
          final pricing = booking.pricing;
          final base = (pricing?.totalPrice
              ?? pricing?.resolvedBaseAmount
              ?? booking.totalAmount
              ?? booking.basePrice) ?? 0.0;
          // Infer provider type: walker if booking already carries walker,
          // else sitter if it carries sitter, else fall back to the services
          // offered by the applying provider.
          String? resolvedProviderType;
          final bookingJsonLocal = response['booking'];
          if (bookingJsonLocal is Map) {
            final walker = bookingJsonLocal['walker'];
            if (walker is Map && (walker['id']?.toString().isNotEmpty ?? false)) {
              resolvedProviderType = 'walker';
            } else {
              final sitter = bookingJsonLocal['sitter'];
              if (sitter is Map && (sitter['id']?.toString().isNotEmpty ?? false)) {
                resolvedProviderType = 'sitter';
              }
            }
          }
          resolvedProviderType ??= application.sitter.service
                  .map((s) => s.toLowerCase())
                  .any((s) => s.contains('dog_walking') || s.contains('walking'))
              ? 'walker'
              : 'sitter';

          if (!mounted) return;
          await Get.to(
            () => StripePaymentScreen(
              booking: booking!,
              totalAmount: base,
              currency: pricing?.currency ?? booking.sitter.currency,
              providerType: resolvedProviderType,
            ),
          );
          if ((clientSecret == null || clientSecret.isEmpty) &&
              payment is Map &&
              payment['error'] != null) {
            AppLogger.logDebug(
              'Accept&Pay: navigated to PaymentPage without clientSecret (error: ${payment['error']})',
            );
          }
          return;
        }

        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'payment_unavailable_message'.tr,
        );
      },
      onReject: () async {
        await _applicationsController.respondToApplication(
          applicationId: application.id,
          action: 'reject',
        );
      },
    );
  }

  Widget _buildBookingCard(BookingModel booking) {
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
        Get.to(
          () => BookingAgreementScreen(
            booking: booking,
            totalPrice: booking.totalAmount ?? booking.basePrice,
          ),
        );
      },
      onStartChat: booking.paymentStatus == 'paid'
          ? () async {
              // v18.8 — booking walker → walkerId, sinon sitterId.
              // Avant v18.8, on tapait toujours /conversations/start?sitterId=X
              // même pour un walker → 404 "Sitter not found" cracheur.
              final svcLower = (booking.serviceType ?? '').toLowerCase();
              final isWalker = svcLower.contains('walking') ||
                  svcLower.contains('dog_walking');
              await _handleStartChatForBooking(
                booking.sitter.id,
                booking.sitter.name,
                booking.sitter.avatar.url.isNotEmpty
                    ? booking.sitter.avatar.url
                    : '',
                isWalkerBooking: isWalker,
              );
            }
          : null,
    );
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
    String providerId,
    String providerName,
    String providerImage, {
    bool isWalkerBooking = false,
  }) async {
    try {
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
        sitterId: isWalkerBooking ? null : providerId,
        walkerId: isWalkerBooking ? providerId : null,
      );

      if (mounted) Navigator.pop(context);

      String? conversationId;
      if (response['conversation'] != null && response['conversation'] is Map) {
        conversationId = response['conversation']['id']?.toString();
      }

      if (conversationId != null && conversationId.isNotEmpty) {
        if (mounted) {
          Get.to(
            () => IndividualChatScreen(
              conversationId: conversationId!,
              contactName: providerName,
              contactImage: providerImage.isNotEmpty ? providerImage : '',
            ),
          );
        }
      } else {
        if (mounted) {
          CustomSnackbar.showError(
            title: 'common_error'.tr,
            message: 'snackbar_text_failed_to_start_conversation_please_try_again'.tr,
          );
        }
      }
    } on ApiException catch (e) {
      if (mounted) Navigator.pop(context);
      AppLogger.logError('Failed to start conversation', error: e.message);
      if (mounted) {
        // Chat-access 402 → upsell dialog instead of a generic error toast.
        if (ChatAccessUpsellHelper.maybeShowChatUpsell(context, e)) return;
        // v18.8 — les 404 "Sitter not found" / "Walker not found" viennent
        // d'un booking mal typé côté backend. On remplace le message
        // technique par une erreur générique traduite.
        final m = e.message.toLowerCase();
        final isNotFound = m.contains('not found');
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: isNotFound ? 'common_error_message'.tr : e.message,
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      AppLogger.logError('Failed to start conversation', error: e);
      if (mounted) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'snackbar_text_failed_to_start_conversation_please_try_again'.tr,
        );
      }
    }
  }
}
