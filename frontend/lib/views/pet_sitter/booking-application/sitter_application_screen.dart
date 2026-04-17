import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/controllers/sitter_application_controller.dart';
import 'package:hopetsit/controllers/sitter_profile_controller.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/views/pet_sitter/widgets/pet_sitter_application_card.dart';
import 'package:hopetsit/views/pet_sitter/booking-application/sitter_booking_detail_screen.dart';
import 'package:hopetsit/widgets/custom_app_bar.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/utils/string_utils.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/repositories/sitter_repository.dart';
import 'package:hopetsit/views/pet_sitter/chat/sitter_individual_chat_screen.dart';
import 'package:intl/intl.dart';

class SitterApplicationScreen extends StatefulWidget {
  const SitterApplicationScreen({super.key});

  @override
  State<SitterApplicationScreen> createState() =>
      _SitterApplicationScreenState();
}

class _SitterApplicationScreenState extends State<SitterApplicationScreen> {
  int _selectedTabIndex = 0;
  late SitterApplicationController _sitterApplicationController;
  late SitterProfileController _sitterProfileController;

  @override
  void initState() {
    super.initState();
    _sitterApplicationController = Get.put(SitterApplicationController());
    _sitterProfileController = Get.put(SitterProfileController());
  }

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
                                text: 'sitter_applications_tab'.tr,
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
                    // Requests tab - commented out, only showing Applications tab
                    // Expanded(
                    //   child: GestureDetector(
                    //     onTap: () {
                    //       setState(() {
                    //         _selectedTabIndex = 1;
                    //       });
                    //     },
                    //     child: Container(
                    //       padding: EdgeInsets.symmetric(vertical: 12.h),
                    //       child: Column(
                    //         children: [
                    //           InterText(
                    //             text: 'Requests',
                    //             fontSize: 16.sp,
                    //             fontWeight: _selectedTabIndex == 1
                    //                 ? FontWeight.w600
                    //                 : FontWeight.w400,
                    //             color: _selectedTabIndex == 1
                    //                 ? AppColors.blackColor
                    //                 : AppColors.greyText,
                    //           ),
                    //           if (_selectedTabIndex == 1)
                    //             Container(
                    //               margin: EdgeInsets.only(top: 8.h),
                    //               height: 3.h,
                    //               decoration: BoxDecoration(
                    //                 color: AppColors.primaryColor,
                    //                 borderRadius: BorderRadius.circular(1.r),
                    //               ),
                    //             ),
                    //         ],
                    //       ),
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ),

              // Content based on selected tab
              // Only showing Applications tab, Requests tab is commented out
              Expanded(
                child: _buildApplicationsTab(),
                // child: _selectedTabIndex == 0
                //     ? _buildApplicationsTab()
                //     : _buildBookingTab(),
              ),
            ],
          ),
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

      if (_sitterApplicationController.bookings.isEmpty) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: InterText(
              text: 'sitter_no_bookings_found'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary(context),
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
          itemCount: _sitterApplicationController.bookings.length,
          itemBuilder: (context, index) {
            final booking = _sitterApplicationController.bookings[index];
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

      final sitterRepository = Get.find<SitterRepository>();
      final response = await sitterRepository.startConversationBySitter(
        ownerId: ownerId,
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
