import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/sitter_application_controller.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/repositories/sitter_repository.dart';
import 'package:hopetsit/repositories/walker_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/string_utils.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/views/pet_sitter/chat/sitter_individual_chat_screen.dart';
import 'package:hopetsit/views/pet_sitter/widgets/pet_sitter_application_card.dart';
import 'package:intl/intl.dart';
import 'package:hopetsit/utils/booking_date_format.dart';
import 'package:hopetsit/views/booking/bookings_history_screen.dart';

class NotificationSitterApplicationCardViewScreen extends StatefulWidget {
  const NotificationSitterApplicationCardViewScreen({
    super.key,
    required this.bookingId,
    required this.title,
  });

  final String bookingId;
  final String title;

  @override
  State<NotificationSitterApplicationCardViewScreen> createState() =>
      _NotificationSitterApplicationCardViewScreenState();
}

class _NotificationSitterApplicationCardViewScreenState
    extends State<NotificationSitterApplicationCardViewScreen> {
  late final SitterApplicationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(SitterApplicationController());

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _controller.loadBookings();
    });
  }

  BookingModel? _findBooking() {
    try {
      return _controller.bookings.firstWhere((b) => b.id == widget.bookingId);
    } catch (_) {
      return null;
    }
  }

  PetSitterApplication _convertBookingToApplication(BookingModel booking) {
    // v18.9.5 — date + heure localisées (avant : 'MMM dd, yyyy' anglais).
    final formattedDate = BookingDateFormat.localizedDate(booking.date);
    final formattedTime = BookingDateFormat.localizedTime(booking.timeSlot);

    // v18.5 — #20 : dérive le rôle du provider pour colorer l'écran
    // (walker = vert, sitter = bleu). Heuristique : serviceType contient
    // "walking" → walker, sinon sitter.
    final serviceLower = (booking.serviceType ?? '').toLowerCase();
    final derivedRole = (serviceLower.contains('walking') ||
            serviceLower.contains('dog_walking'))
        ? 'walker'
        : 'sitter';

    return PetSitterApplication(
      id: booking.id,
      petName: booking.petName,
      petType: booking.petName,
      petImage: '',
      weight: booking.petWeight,
      height: booking.petHeight,
      color: booking.petColor,
      date: formattedDate,
      time: formattedTime,
      phoneNumber: maskPhoneNumber(booking.owner.mobile),
      email: booking.owner.email,
      location: booking.owner.address,
      ownerId: booking.owner.id,
      status: booking.status,
      paymentStatus: booking.paymentStatus ?? 'pending',
      // v18.5 — #20 : prix TTC + net (80%) visibles avant d'accepter.
      // Le modèle frontend expose `netAmount` (pas `netPayout` qui est le
      // nom côté backend Mongo). Si absent, la card tombera en fallback
      // sur totalPrice × 0.8 dans _buildPriceBreakdownCard.
      totalPrice: booking.pricing?.totalPrice ?? booking.totalAmount,
      netPayout: booking.pricing?.netAmount,
      currency: booking.pricing?.currency ?? booking.sitter.currency,
      providerRole: derivedRole,
    );
  }

  Future<void> _handleStartChat({
    required String ownerId,
    required String ownerName,
    required String ownerImage,
  }) async {
    try {
      // v18.8 — route walker→/start-by-walker, sitter→/start-by-sitter.
      // Avant v18.8, un walker qui tapait "Discuter avec le propriétaire"
      // depuis une notification recevait 403 car l'appel sortait sur le
      // endpoint /start-by-sitter qui fait requireRole('sitter').
      final authController = Get.isRegistered<AuthController>()
          ? Get.find<AuthController>()
          : null;
      final role = (authController?.userRole.value ?? 'sitter').toLowerCase();

      Map<String, dynamic> response;
      if (role == 'walker') {
        final walkerRepository = Get.isRegistered<WalkerRepository>()
            ? Get.find<WalkerRepository>()
            : null;
        if (walkerRepository == null) {
          throw StateError('WalkerRepository not registered');
        }
        response = await walkerRepository.startConversationByWalker(
          ownerId: ownerId,
        );
      } else {
        final sitterRepository = Get.find<SitterRepository>();
        response = await sitterRepository.startConversationBySitter(
          ownerId: ownerId,
        );
      }

      String? conversationId;
      if (response['conversation'] != null && response['conversation'] is Map) {
        conversationId = response['conversation']['id']?.toString();
      }

      if (conversationId == null || conversationId.isEmpty) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'sitter_chat_start_failed'.tr,
        );
        return;
      }

      Get.to(
        () => SitterIndividualChatScreen(
          conversationId: conversationId!,
          contactName: ownerName,
          contactImage: ownerImage,
        ),
      );
    } catch (e) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'common_error_message'.tr,
      );
    }
  }

  // v23.1 part 58 — bottom sheet showing owner basic profile (avatar, name,
  // email, phone, address) so sitters / walkers can preview the requester
  // before accepting/rejecting a booking from the in-app banner.
  void _showOwnerProfileSheet(BuildContext context, BookingModel booking) {
    final owner = booking.owner;
    final avatarUrl = owner.avatar.url;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.scaffold(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30.r,
                      backgroundColor: AppColors.primaryColor.withValues(alpha: 0.15),
                      backgroundImage: avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl.isEmpty
                          ? Icon(Icons.person, size: 30.sp,
                              color: AppColors.primaryColor)
                          : null,
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InterText(
                            text: owner.name.isNotEmpty
                                ? owner.name
                                : 'profile_unknown_owner'.tr,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                          ),
                          if (owner.email.isNotEmpty) ...[
                            SizedBox(height: 2.h),
                            InterText(
                              text: owner.email,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textSecondary(context),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 18.h),
                Divider(color: AppColors.divider(context), height: 1),
                SizedBox(height: 14.h),
                if (owner.mobile.isNotEmpty)
                  _ownerInfoRow(context, Icons.phone_outlined, owner.mobile),
                if (owner.address.isNotEmpty)
                  _ownerInfoRow(context, Icons.location_on_outlined, owner.address),
                if (booking.petName.isNotEmpty)
                  _ownerInfoRow(context, Icons.pets, booking.petName),
                SizedBox(height: 20.h),
                SizedBox(
                  width: double.infinity,
                  height: 44.h,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22.r),
                      ),
                    ),
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                    child: InterText(
                      text: 'common_close'.tr,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _ownerInfoRow(BuildContext context, IconData icon, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18.sp, color: AppColors.textSecondary(context)),
          SizedBox(width: 10.w),
          Expanded(
            child: InterText(
              text: value,
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final booking = _findBooking();
      final showLoading = _controller.isLoading.value && booking == null;

      return Scaffold(
        backgroundColor: AppColors.scaffold(context),
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0.5,
          backgroundColor: AppColors.appBar(context),
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: AppColors.primaryColor),
          title: InterText(
            text: widget.title,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
        ),
        body: SafeArea(
          child: showLoading
              ? const Center(child: CircularProgressIndicator())
              : booking == null
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.w),
                    child: InterText(
                      text: 'notifications_application_not_found'.tr,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.grey700Color,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PetSitterApplicationCard(
                    application: _convertBookingToApplication(booking),
                    onViewOwnerProfile: () =>
                        _showOwnerProfileSheet(context, booking),
                    onAccept: () async {
                      final result = await _controller.acceptApplication(
                        booking.id,
                      );
                      if (!mounted) return;

                      if (result['success'] == true) {
                        CustomSnackbar.showSuccess(
                          title: 'common_success'.tr,
                          message: 'sitter_application_accepted_success'.tr,
                        );
                        Get.back();
                      } else {
                        // Session v16.3d - refresh bookings so a stale
                        // 'pending' badge updates after backend 409.
                        await _controller.loadBookings();
                        CustomSnackbar.showError(
                          title: 'common_error'.tr,
                          message:
                              result['message'] as String? ??
                              'sitter_application_accept_failed'.tr,
                        );
                      }
                    },
                    onReject: () async {
                      final result = await _controller.rejectApplication(
                        booking.id,
                      );
                      if (!mounted) return;

                      if (result['success'] == true) {
                        CustomSnackbar.showSuccess(
                          title: 'common_success'.tr,
                          message: 'sitter_application_rejected_success'.tr,
                        );
                        Get.back();
                      } else {
                        await _controller.loadBookings();
                        CustomSnackbar.showError(
                          title: 'common_error'.tr,
                          message:
                              result['message'] as String? ??
                              'sitter_application_reject_failed'.tr,
                        );
                      }
                    },
                    onStartChat:
                        (booking.paymentStatus ?? '').toLowerCase() == 'paid'
                        ? () async {
                            final ownerImage =
                                booking.owner.avatar.url.isNotEmpty
                                ? booking.owner.avatar.url
                                : '';
                            await _handleStartChat(
                              ownerId: booking.owner.id,
                              ownerName: booking.owner.name,
                              ownerImage: ownerImage,
                            );
                          }
                        : null,
                      ),
                      // v18.6 — #20 : CTA "Voir mes réservations" qui renvoie
                      // vers l'onglet Réservations (remplace la sortie molle
                      // en bas de l'écran acceptance).
                      SizedBox(height: 12.h),
                      GestureDetector(
                        onTap: () {
                          // v23.1 — B2 : navigate directly to the bookings
                          // history instead of just popping to home.
                          Get.to(() => const BookingsHistoryScreen());
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: 14.h,
                            horizontal: 16.w,
                          ),
                          decoration: BoxDecoration(
                            color: ((booking.serviceType ?? '')
                                        .toLowerCase()
                                        .contains('walking'))
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                color: AppColors.whiteColor,
                                size: 18.sp,
                              ),
                              SizedBox(width: 8.w),
                              InterText(
                                text: 'application_card_view_reservations'.tr,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.whiteColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      );
    });
  }
}

class NotificationSitterAcceptedCardViewScreen
    extends NotificationSitterApplicationCardViewScreen {
  NotificationSitterAcceptedCardViewScreen({
    super.key,
    required super.bookingId,
  }) : super(title: 'notif_title_booking_accepted'.tr);
}

class NotificationSitterNewRequestCardViewScreen
    extends NotificationSitterApplicationCardViewScreen {
  NotificationSitterNewRequestCardViewScreen({
    super.key,
    required super.bookingId,
  }) : super(title: 'notif_title_booking_new'.tr);
}
