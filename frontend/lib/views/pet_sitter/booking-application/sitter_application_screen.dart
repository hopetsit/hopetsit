import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/sitter_application_controller.dart';
import 'package:hopetsit/controllers/sitter_profile_controller.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/views/pet_sitter/widgets/pet_sitter_application_card.dart';
import 'package:hopetsit/views/pet_sitter/booking-application/sitter_booking_detail_screen.dart';
import 'package:hopetsit/widgets/custom_app_bar.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/utils/string_utils.dart';
import 'package:hopetsit/widgets/chat_access_upsell_helper.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/repositories/sitter_repository.dart';
import 'package:hopetsit/repositories/walker_repository.dart';
import 'package:hopetsit/views/pet_sitter/chat/sitter_individual_chat_screen.dart';
import 'package:intl/intl.dart';

class SitterApplicationScreen extends StatefulWidget {
  const SitterApplicationScreen({super.key});

  @override
  State<SitterApplicationScreen> createState() =>
      _SitterApplicationScreenState();
}

class _SitterApplicationScreenState extends State<SitterApplicationScreen> {
  /// Mirrors the owner-side ApplicationScreen filter: 'all' | 'pending' |
  /// 'accepted' | 'paid' | 'cancelled'.
  String _selectedFilter = 'all';
  late SitterApplicationController _sitterApplicationController;
  late SitterProfileController _sitterProfileController;

  @override
  void initState() {
    super.initState();
    _sitterApplicationController = Get.put(SitterApplicationController());
    _sitterProfileController = Get.put(SitterProfileController());
  }

  /// Returns bookings whose status matches the active filter chip.
  List<BookingModel> _filteredBookings() {
    final all = _sitterApplicationController.bookings;
    if (_selectedFilter == 'all') return all.toList();
    return all.where((b) {
      final s = b.status.toLowerCase().trim();
      final p = (b.paymentStatus ?? '').toLowerCase().trim();
      switch (_selectedFilter) {
        case 'pending':
          return s == 'pending';
        case 'accepted':
          return s == 'accepted' && p != 'paid';
        case 'paid':
          return p == 'paid' || s == 'paid';
        case 'cancelled':
          return s == 'cancelled' || s == 'rejected' || s == 'refunded';
        default:
          return true;
      }
    }).toList();
  }

  int _countByFilter(String filter) {
    if (filter == 'all') return _sitterApplicationController.bookings.length;
    final old = _selectedFilter;
    _selectedFilter = filter;
    final n = _filteredBookings().length;
    _selectedFilter = old;
    return n;
  }

  int get _pendingCount => _countByFilter('pending');
  int get _confirmedCount =>
      _countByFilter('accepted') + _countByFilter('paid');

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        appBar: CustomAppBar(
          userName: _sitterProfileController.userName.value.isNotEmpty
              ? _sitterProfileController.userName.value
              : 'home_default_user_name'.tr,
          userImage: _sitterProfileController.profileImageUrl.value.isNotEmpty
              ? _sitterProfileController.profileImageUrl.value
              : AppImages.placeholderImage,
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
              // ── Summary cards (Candidatures / Réservations) ──
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
                child: Row(
                  children: [
                    _summaryCard(
                      context,
                      icon: Icons.send_rounded,
                      label: 'Candidatures',
                      count: _pendingCount,
                      color: const Color(0xFF1A73E8),
                    ),
                    SizedBox(width: 10.w),
                    _summaryCard(
                      context,
                      icon: Icons.event_note_rounded,
                      label: 'Réservations',
                      count: _confirmedCount,
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
                    _filterChip(context, 'all', 'Tout'),
                    SizedBox(width: 8.w),
                    _filterChip(context, 'pending', 'En attente'),
                    SizedBox(width: 8.w),
                    _filterChip(context, 'accepted', 'Acceptée'),
                    SizedBox(width: 8.w),
                    _filterChip(context, 'paid', 'Payée'),
                    SizedBox(width: 8.w),
                    _filterChip(context, 'cancelled', 'Annulée'),
                  ],
                ),
              ),

              SizedBox(height: 8.h),

              // ── Filtered list ──
              Expanded(child: _buildApplicationsTab()),
            ],
          ),
        ),
      ),
    );
  }

  /// Owner-style summary card. Mirrors [ApplicationScreen._summaryCard].
  Widget _summaryCard(
    BuildContext context, {
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

  /// Owner-style filter chip — selected = primary color pill, otherwise
  /// a bordered pill on card background. Shows a count badge when > 0.
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
          border: isSelected
              ? null
              : Border.all(color: AppColors.divider(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InterText(
              text: label,
              fontSize: 12.sp,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? Colors.white
                  : AppColors.textSecondary(context),
            ),
            if (count > 0) ...[
              SizedBox(width: 6.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppColors.primaryColor.withValues(alpha: 0.1),
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

  Widget _buildApplicationsTab() {
    return Obx(() {
      if (_sitterApplicationController.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
          ),
        );
      }

      final bookings = _filteredBookings();
      if (bookings.isEmpty) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 48.sp,
                  color: AppColors.textSecondary(context).withValues(alpha: 0.4),
                ),
                SizedBox(height: 12.h),
                InterText(
                  text: _selectedFilter == 'all'
                      ? 'Aucune candidature ni réservation'
                      : 'Aucun résultat pour ce filtre',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary(context),
                ),
              ],
            ),
          ),
        );
      }

      return RefreshIndicator(
        color: AppColors.primaryColor,
        onRefresh: () => _sitterApplicationController.loadBookings(),
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(
            20.w,
            16.h,
            20.w,
            100.h,
          ), // Extra bottom padding for navigation bar
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index];
            final application = _convertBookingToApplication(booking);
            return GestureDetector(
              onTap: () {
                Get.to(
                  () => SitterBookingDetailScreen(
                    booking: booking,
                    onStartChat: application.paymentStatus == 'paid'
                        ? () async {
                            final ownerImage =
                                booking.owner.avatar.url.isNotEmpty
                                ? booking.owner.avatar.url
                                : '';
                            await _handleStartChat(
                              application.ownerId,
                              booking.owner.name,
                              ownerImage,
                            );
                          }
                        : null,
                    onAccept: () async {
                      final result = await _sitterApplicationController
                          .acceptApplication(booking.id);
                      if (result['success'] == true) {
                        CustomSnackbar.showSuccess(
                          title: 'common_success'.tr,
                          message: 'sitter_application_accepted_success'.tr,
                        );
                        Get.back();
                      } else {
                        CustomSnackbar.showError(
                          title: 'common_error'.tr,
                          message:
                              result['message'] as String? ??
                              'sitter_application_accept_failed'.tr,
                        );
                      }
                    },
                    onReject: () async {
                      final result = await _sitterApplicationController
                          .rejectApplication(booking.id);
                      if (result['success'] == true) {
                        CustomSnackbar.showSuccess(
                          title: 'common_success'.tr,
                          message: 'sitter_application_rejected_success'.tr,
                        );
                        Get.back();
                      } else {
                        CustomSnackbar.showError(
                          title: 'common_error'.tr,
                          message:
                              result['message'] as String? ??
                              'sitter_application_reject_failed'.tr,
                        );
                      }
                    },
                  ),
                );
              },
              child: PetSitterApplicationCard(
                application: application,
                onStartChat: application.paymentStatus == 'paid'
                    ? () async {
                        final ownerImage = booking.owner.avatar.url.isNotEmpty
                            ? booking.owner.avatar.url
                            : '';
                        await _handleStartChat(
                          application.ownerId,
                          booking.owner.name,
                          ownerImage,
                        );
                      }
                    : null,
                onAccept: () async {
                  final result = await _sitterApplicationController
                      .acceptApplication(booking.id);
                  if (result['success'] == true) {
                    CustomSnackbar.showSuccess(
                      title: 'common_success'.tr,
                      message:
                          'snackbar_text_application_accepted_successfully',
                    );
                  } else {
                    CustomSnackbar.showError(
                      title: 'common_error'.tr,
                      message:
                          result['message'] as String? ??
                          'Failed to accept application',
                    );
                  }
                },
                onReject: () async {
                  final result = await _sitterApplicationController
                      .rejectApplication(booking.id);
                  if (result['success'] == true) {
                    CustomSnackbar.showSuccess(
                      title: 'common_success'.tr,
                      message:
                          'snackbar_text_application_rejected_successfully',
                    );
                  } else {
                    CustomSnackbar.showError(
                      title: 'common_error'.tr,
                      message:
                          result['message'] as String? ??
                          'Failed to reject application',
                    );
                  }
                },
              ),
            );
          },
        ),
      );
    });
  }

  // Requests tab method - commented out, only showing Applications tab
  // Widget _buildBookingTab() {
  //   return Center(
  //     child: Padding(
  //       padding: EdgeInsets.all(20.w),
  //       child: InterText(
  //         text: 'No requests found',
  //         fontSize: 14.sp,
  //         fontWeight: FontWeight.w400,
  //         color: AppColors.greyColor,
  //       ),
  //     ),
  //   );
  // }

  PetSitterApplication _convertBookingToApplication(BookingModel booking) {
    // Format date
    String formattedDate = booking.date;
    try {
      final dateTime = DateTime.parse(booking.date);
      formattedDate = DateFormat('MMM dd, yyyy').format(dateTime);
    } catch (e) {
      formattedDate = booking.date;
    }

    return PetSitterApplication(
      id: booking.id,
      petName: booking.petName,
      petType:
          booking.petName, // Using petName as petType since type not available
      petImage:
          '', // Pet image will be loaded from API if available, otherwise icon will be shown
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
    );
  }

  Future<void> _handleStartChat(
    String ownerId,
    String ownerName,
    String ownerImage,
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

      // v18.8 — walker chat fix : dispatch selon rôle courant.
      // Walker → /start-by-walker, sitter → /start-by-sitter.
      final authController = Get.isRegistered<AuthController>()
          ? Get.find<AuthController>()
          : null;
      final role = (authController?.userRole.value ?? 'sitter').toLowerCase();
      final Map<String, dynamic> response;
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
            () => SitterIndividualChatScreen(
              conversationId: conversationId!,
              contactName: ownerName,
              contactImage: ownerImage,
            ),
          );
        }
      } else {
        if (mounted) {
          CustomSnackbar.showError(
            title: 'common_error'.tr,
            message: 'sitter_chat_start_failed'.tr,
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        // Chat-access 402 → upsell dialog (Premium / Chat add-on) rather
        // than a generic failure toast.
        if (ChatAccessUpsellHelper.maybeShowChatUpsell(context, e)) return;
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
