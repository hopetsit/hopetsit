import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/sitter_application_controller.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/repositories/sitter_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/string_utils.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/views/pet_sitter/chat/sitter_individual_chat_screen.dart';
import 'package:hopetsit/views/pet_sitter/widgets/pet_sitter_application_card.dart';
import 'package:intl/intl.dart';

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
    // Matches the conversion logic used in `SitterApplicationScreen`.
    String formattedDate = booking.date;
    try {
      final dateTime = DateTime.parse(booking.date);
      formattedDate = DateFormat('MMM dd, yyyy').format(dateTime);
    } catch (_) {
      formattedDate = booking.date;
    }

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
      time: booking.timeSlot,
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
      // Starting chat may fail; keep it silent and show a snackbar.
      final sitterRepository = Get.find<SitterRepository>();
      final response = await sitterRepository.startConversationBySitter(
        ownerId: ownerId,
      );

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
      CustomSnackbar.showError(title: 'common_error'.tr, message: e.toString());
    }
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
                          Get.until((route) => route.isFirst);
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
