import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/sitter_detail_controller.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/models/sitter_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/views/pet_owner/chat/individual_chat_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/report_dialog.dart';

class Review {
  final String reviewerName;
  final String reviewerImage;
  final double rating;
  final String reviewText;

  Review({
    required this.reviewerName,
    required this.reviewerImage,
    required this.rating,
    required this.reviewText,
  });
}

class ServiceProviderDetailScreen extends StatelessWidget {
  final String sitterId;
  final String status;
  final BookingModel? booking;

  const ServiceProviderDetailScreen({
    super.key,
    required this.sitterId,
    required this.status,
    this.booking,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SitterDetailController(sitterId: sitterId));

    return _ServiceProviderDetailContent(
      controller: controller,
      sitterId: sitterId,
      status: status,
      booking: booking,
    );
  }
}

class _ServiceProviderDetailContent extends StatelessWidget {
  final SitterDetailController controller;
  final String sitterId;
  final String status;
  final BookingModel? booking;

  const _ServiceProviderDetailContent({
    required this.controller,
    required this.sitterId,
    required this.status,
    this.booking,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        leading: BackButton(),
        title: Obx(
          () => PoppinsText(
            text:
                controller.sitter.value?.name ??
                'sitter_detail_loading_name'.tr,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'report_dialog_title'.tr,
            icon: const Icon(Icons.flag_outlined, color: AppColors.primaryColor),
            onPressed: () {
              ReportDialog.show(
                context: context,
                targetType: 'profile',
                targetId: sitterId,
                snapshot: controller.sitter.value?.name ?? '',
              );
            },
          ),
        ],
        // actionsLegacy: [
        //   Obx(
        //     () => Padding(
        //       padding: EdgeInsets.only(right: 16.w),
        //       child:
        //           controller.sitter.value?.avatar.url != null &&
        //               controller.sitter.value!.avatar.url.isNotEmpty &&
        //               (controller.sitter.value!.avatar.url.startsWith(
        //                     'http://',
        //                   ) ||
        //                   controller.sitter.value!.avatar.url.startsWith(
        //                     'https://',
        //                   ))
        //           ? ClipOval(
        //               child: CachedNetworkImage(
        //                 imageUrl: controller.sitter.value!.avatar.url,
        //                 width: 32.w,
        //                 height: 32.h,
        //                 fit: BoxFit.cover,
        //                 placeholder: (context, url) => CircleAvatar(
        //                   radius: 16.r,
        //                   backgroundColor: AppColors.lightGrey,
        //                   child: CircularProgressIndicator(
        //                     strokeWidth: 2,
        //                     valueColor: AlwaysStoppedAnimation<Color>(
        //                       AppColors.primaryColor,
        //                     ),
        //                   ),
        //                 ),
        //                 errorWidget: (context, url, error) => CircleAvatar(
        //                   radius: 16.r,
        //                   backgroundImage: AssetImage(AppImages.AppImages.placeholderImageage),
        //                 ),
        //               ),
        //             )
        //           : CircleAvatar(
        //               radius: 16.r,
        //               backgroundImage: AssetImage(AppImages.AppImages.placeholderImageage),
        //             ),
        //     ),
        //   ),
        // ],
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryColor,
                ),
              ),
            );
          }

          if (controller.sitter.value == null) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(20.w),
                child: InterText(
                  text:
                      controller.errorMessage.value ??
                      'sitter_detail_load_error'.tr,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.greyColor,
                ),
              ),
            );
          }

          final sitter = controller.sitter.value!;
          return SingleChildScrollView(
            child: Column(
              children: [
                // Hero Section
                _buildHeroSection(sitter, context),

                // Content Sections
                Padding(
                  padding: EdgeInsets.all(20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Start Chat Button
                      _buildStartChatButton(controller, sitter, booking),
                      SizedBox(height: 16.h),

                      // Booking/Application Details Section
                      _buildBookingDetailsSection(sitter, status, context),
                      SizedBox(height: 24.h),

                      // About Section
                      _buildAboutSection(sitter, context),
                      SizedBox(height: 24.h),

                      // Skills Section
                      _buildSkillsSection(sitter, context),
                      SizedBox(height: 24.h),

                      // Reviews Section
                      _buildReviewsSection(sitter, context),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHeroSection(sitter, BuildContext context) {
    final imageUrl =
        sitter.avatar.url.isNotEmpty &&
            (sitter.avatar.url.startsWith('http://') ||
                sitter.avatar.url.startsWith('https://'))
        ? sitter.avatar.url
        : null;

    return Container(
      height: 350.h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background Image
          Container(
            width: double.infinity,
            height: 300.h,
            child: imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: double.infinity,
                    height: 300.h,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppColors.lightGrey,
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primaryColor,
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.grey300Color,
                      child: Center(
                        child: Icon(
                          Icons.person,
                          size: 80.sp,
                          color: AppColors.greyColor,
                        ),
                      ),
                    ),
                  )
                : Container(
                    color: AppColors.grey300Color,
                    child: Center(
                      child: Icon(
                        Icons.person,
                        size: 80.sp,
                        color: AppColors.greyColor,
                      ),
                    ),
                  ),
          ),

          // Profile Overlay Card
          Positioned(
            bottom: -10.h,
            left: 40.w,
            right: 40.w,
            child: Container(
              height: 110.h,
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.all(Radius.circular(26.r)),
              ),
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PoppinsText(
                    text: sitter.name,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      if (sitter.rating > 0 && sitter.reviewsCount > 0) ...[
                        Row(
                          children: List.generate(5, (index) {
                            if (index < sitter.rating.floor()) {
                              return Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 16.sp,
                              );
                            } else if (index == sitter.rating.floor() &&
                                sitter.rating % 1 != 0) {
                              return Icon(
                                Icons.star_half,
                                color: Colors.amber,
                                size: 16.sp,
                              );
                            } else {
                              return Icon(
                                Icons.star_border,
                                color: Colors.amber,
                                size: 16.sp,
                              );
                            }
                          }),
                        ),
                        SizedBox(width: 8.w),
                        PoppinsText(
                          text: sitter.rating.toStringAsFixed(1),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textPrimary(context),
                        ),
                      ] else ...[
                        InterText(
                          text: 'sitter_detail_no_rating'.tr,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w400,
                          color: AppColors.greyColor,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(sitter, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Image.asset(
              AppImages.pawIcon,
              width: 20.w,
              height: 20.h,
              color: AppColors.textPrimary(context),
            ),
            SizedBox(width: 8.w),
            PoppinsText(
              text: 'sitter_detail_about_title'.trParams({'name': sitter.name}),
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        PoppinsText(
          text: sitter.bio?.isNotEmpty == true
              ? sitter.bio!
              : 'sitter_detail_no_bio'.tr,
          fontSize: 13.sp,
          fontWeight: FontWeight.w400,
          color: AppColors.greyColor,
        ),
      ],
    );
  }

  Widget _buildBookingDetailsSection(SitterModel sitter, String status, BuildContext context) {
    final hourlyRate = sitter.hourlyRate;
    final hasBooking =
        status.toLowerCase() != 'available' &&
        status.toLowerCase() != 'offline' &&
        status.toLowerCase() != 'online';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 20.sp,
              color: AppColors.primaryColor,
            ),
            SizedBox(width: 8.w),
            PoppinsText(
              text: hasBooking
                  ? 'sitter_detail_booking_details_title'.tr
                  : 'sitter_detail_availability_pricing_title'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hourly Rate
              if (hourlyRate > 0) ...[
                _buildRateRow(
                  'price_per_hour'.tr,
                  CurrencyHelper.format(sitter.currency, hourlyRate),
                  context,
                ),
              ],
              // Daily Rate
              if (sitter.dailyRate > 0) ...[
                if (hourlyRate > 0) SizedBox(height: 12.h),
                _buildRateRow(
                  'price_per_day'.tr,
                  CurrencyHelper.format(sitter.currency, sitter.dailyRate),
                  context,
                ),
              ],
              // Weekly Rate
              if (sitter.weeklyRate > 0) ...[
                SizedBox(height: 12.h),
                _buildRateRow(
                  'price_per_week'.tr,
                  CurrencyHelper.format(sitter.currency, sitter.weeklyRate),
                  context,
                ),
              ],
              // Monthly Rate
              if (sitter.monthlyRate > 0) ...[
                SizedBox(height: 12.h),
                _buildRateRow(
                  'price_per_month'.tr,
                  CurrencyHelper.format(sitter.currency, sitter.monthlyRate),
                  context,
                ),
              ],
              SizedBox(height: 12.h),
              Divider(color: AppColors.grey300Color, thickness: 1),
              SizedBox(height: 12.h),

              // Current Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InterText(
                    text: 'sitter_detail_current_status_label'.tr,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.grey700Color,
                  ),
                  _buildStatusChip(status),
                ],
              ),
              if (hasBooking) ...[
                SizedBox(height: 12.h),
                Divider(color: AppColors.grey300Color, thickness: 1),
                SizedBox(height: 12.h),
                // Application/Booking Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InterText(
                      text: 'sitter_detail_application_status_label'.tr,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.grey700Color,
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            status.toLowerCase() == 'pending'
                                ? Icons.timer
                                : status.toLowerCase() == 'agreed' ||
                                      status.toLowerCase() == 'accepted'
                                ? Icons.check_circle
                                : Icons.info,
                            size: 12.sp,
                            color: AppColors.primaryColor,
                          ),
                          SizedBox(width: 4.w),
                          InterText(
                            text: _localizedStatusLabel(status),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRateRow(String label, String value, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InterText(
          text: label,
          fontSize: 13.sp,
          fontWeight: FontWeight.w400,
          color: AppColors.grey700Color,
        ),
        PoppinsText(
          text: value,
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryColor,
        ),
      ],
    );
  }

  Widget _buildSkillsSection(sitter, BuildContext context) {
    final skillsList = sitter.skillsList;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Image.asset(AppImages.skillIcon, width: 26.w, height: 26.h),
            SizedBox(width: 8.w),
            PoppinsText(
              text: 'sitter_detail_skills_title'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        if (skillsList.isNotEmpty)
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: skillsList
                .map<Widget>((skill) => _buildSkillTag(skill, context))
                .toList(),
          )
        else
          InterText(
            text: 'sitter_detail_no_skills'.tr,
            fontSize: 13.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.greyColor,
          ),
      ],
    );
  }

  Widget _buildSkillTag(String skill, BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primaryColor),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: InterText(
        text: skill,
        fontSize: 14.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary(context),
      ),
    );
  }

  Widget _buildReviewsSection(sitter, BuildContext context) {
    final reviewsList = sitter.reviews as List<dynamic>? ?? [];
    final List<Widget> reviewWidgets = reviewsList.isEmpty
        ? [
            InterText(
              text: 'sitter_detail_no_reviews'.tr,
              fontSize: 13.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.greyColor,
            ),
          ]
        : reviewsList
              .map<Widget>(
                (review) => Column(
                  children: [
                    _buildReviewItem(review, context),
                    SizedBox(height: 16.h),
                  ],
                ),
              )
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Image.asset(AppImages.skillIcon, width: 26.w, height: 26.h),
            SizedBox(width: 8.w),
            InterText(
              text: 'sitter_detail_reviews_title'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        ...reviewWidgets,
      ],
    );
  }

  Widget _buildReviewItem(dynamic review, BuildContext context) {
    final reviewerName =
        review['reviewer']['name'] as String? ??
        'sitter_detail_anonymous_reviewer'.tr;
    final reviewerImage = review['reviewerImage'] as String? ?? '';
    final rating = (review['rating'] as num?)?.toDouble() ?? 0.0;
    final reviewText = review['comment'] as String? ?? '';

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          reviewerImage.isNotEmpty &&
                  (reviewerImage.startsWith('http://') ||
                      reviewerImage.startsWith('https://'))
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: reviewerImage,
                    width: 50.w,
                    height: 50.h,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => CircleAvatar(
                      radius: 25.r,
                      backgroundColor: AppColors.lightGrey,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryColor,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => CircleAvatar(
                      radius: 25.r,
                      backgroundColor: AppColors.grey300Color,
                      child: Icon(
                        Icons.person,
                        size: 28.sp,
                        color: AppColors.greyColor,
                      ),
                    ),
                  ),
                )
              : CircleAvatar(
                  radius: 25.r,
                  backgroundColor: AppColors.grey300Color,
                  child: Icon(
                    Icons.person,
                    size: 28.sp,
                    color: AppColors.greyColor,
                  ),
                ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PoppinsText(
                  text: reviewerName,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          if (index < rating.floor()) {
                            return Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 12.sp,
                            );
                          } else if (index == rating.floor() &&
                              rating % 1 != 0) {
                            return Icon(
                              Icons.star_half,
                              color: Colors.amber,
                              size: 12.sp,
                            );
                          } else {
                            return Icon(
                              Icons.star_border,
                              color: Colors.amber,
                              size: 12.sp,
                            );
                          }
                        }),
                        SizedBox(width: 4.w),
                        PoppinsText(
                          text: rating.toStringAsFixed(1),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textPrimary(context),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                InterText(
                  text: reviewText,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartChatButton(
    SitterDetailController controller,
    sitter,
    BookingModel? booking,
  ) {
    return Obx(() {
      final isLoading = controller.isStartingChat.value;

      // Check if payment status is paid
      final paymentStatus = booking?.paymentStatus?.toLowerCase().trim();
      final isPaid = paymentStatus == 'paid';
      final isLocked = booking != null && !isPaid;

      return GestureDetector(
        onTap: (isLoading || isLocked)
            ? null
            : () => _handleStartChat(
                controller,
                sitter.id,
                sitter.name,
                sitter.avatar.url,
              ),
        child: Container(
          width: double.infinity,
          height: 48.h,
          decoration: BoxDecoration(
            gradient: isLocked ? null : LinearGradient(colors: [AppColors.primaryColor, AppColors.primaryColor.withOpacity(0.85)]),
            color: isLocked ? AppColors.grey300Color : null,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: isLocked ? null : [BoxShadow(color: AppColors.primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading) ...[
                SizedBox(
                  width: 18.w,
                  height: 18.h,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.whiteColor,
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                InterText(
                  text: 'sitter_detail_starting_chat'.tr,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.whiteColor,
                ),
              ] else if (isLocked) ...[
                Icon(Icons.lock, color: AppColors.whiteColor, size: 20.sp),
                SizedBox(width: 8.w),
                InterText(
                  text: 'sitter_detail_unlock_after_payment'.tr,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.whiteColor,
                ),
              ] else ...[
                Icon(
                  Icons.chat_bubble_outline,
                  color: AppColors.whiteColor,
                  size: 20.sp,
                ),
                SizedBox(width: 8.w),
                InterText(
                  text: 'sitter_detail_start_chat'.tr,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.whiteColor,
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  Future<void> _handleStartChat(
    SitterDetailController controller,
    String sitterId,
    String sitterName,
    String sitterImage,
  ) async {
    try {
      controller.isStartingChat.value = true;

      final ownerRepository = Get.find<OwnerRepository>();
      final response = await ownerRepository.startConversation(
        sitterId: sitterId,
      );

      // Extract conversation ID and sitter info from response
      final conversation = response['conversation'] as Map<String, dynamic>?;
      final conversationId = conversation?['id'] as String? ?? '';

      if (conversationId.isEmpty) {
        throw Exception('Conversation ID not found in response');
      }

      // Extract sitter name and image from API response if available
      String finalSitterName = sitterName;
      String finalSitterImage = sitterImage.isNotEmpty ? sitterImage : '';

      if (conversation != null) {
        // Try to get sitter info from conversation object
        final sitterData = conversation['sitter'] as Map<String, dynamic>?;
        if (sitterData != null) {
          finalSitterName = sitterData['name']?.toString() ?? sitterName;

          // Extract sitter avatar
          if (sitterData['avatar'] != null) {
            if (sitterData['avatar'] is String) {
              finalSitterImage = sitterData['avatar'] as String;
            } else if (sitterData['avatar'] is Map &&
                sitterData['avatar']['url'] != null) {
              finalSitterImage = sitterData['avatar']['url'] as String;
            }
          }
        }
      }

      // Navigate to chat screen
      Get.to(
        () => IndividualChatScreen(
          conversationId: conversationId,
          contactName: finalSitterName,
          contactImage: finalSitterImage.isNotEmpty ? finalSitterImage : '',
        ),
      );
    } on ApiException catch (error) {
      AppLogger.logError('Failed to start conversation', error: error.message);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: error.message,
      );
    } catch (error) {
      AppLogger.logError('Failed to start conversation', error: error);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'sitter_detail_start_chat_failed'.tr,
      );
    } finally {
      controller.isStartingChat.value = false;
    }
  }

  String _localizedStatusLabel(String status) {
    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'available':
      case 'online':
        return 'status_available_label'.tr;
      case 'cancelled':
        return 'status_cancelled_label'.tr;
      case 'rejected':
        return 'status_rejected_label'.tr;
      case 'pending':
        return 'status_pending_label'.tr;
      case 'agreed':
        return 'status_agreed_label'.tr;
      case 'paid':
        return 'status_paid_label'.tr;
      case 'accepted':
        return 'status_accepted_label'.tr;
      default:
        if (status.isEmpty) return status;
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  Widget _buildStatusChip(String status) {
    final statusLower = status.toLowerCase();
    Color backgroundColor;
    Color textColor;
    IconData icon;
    String displayText = _localizedStatusLabel(status);

    switch (statusLower) {
      case 'available':
      case 'online':
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'cancelled':
        backgroundColor = AppColors.errorColor.withOpacity(0.1);
        textColor = AppColors.errorColor;
        icon = Icons.cancel;
        break;
      case 'rejected':
        backgroundColor = AppColors.errorColor.withOpacity(0.1);
        textColor = AppColors.errorColor;
        icon = Icons.close_rounded;
        break;
      case 'pending':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        icon = Icons.timer;
        break;
      case 'agreed':
        backgroundColor = AppColors.greenColor.withOpacity(0.1);
        textColor = AppColors.greenColor;
        icon = Icons.check_circle;
        break;
      case 'paid':
        backgroundColor = AppColors.greenColor.withOpacity(0.1);
        textColor = AppColors.greenColor;
        icon = Icons.check_circle;
        break;
      case 'accepted':
        backgroundColor = AppColors.greenColor.withOpacity(0.1);
        textColor = AppColors.greenColor;
        icon = Icons.check_circle;
        break;
      default:
        backgroundColor = AppColors.greyColor.withOpacity(0.1);
        textColor = AppColors.greyColor;
        icon = Icons.info;
        displayText = status.toUpperCase();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: textColor),
          SizedBox(width: 6.w),
          InterText(
            text: displayText,
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ],
      ),
    );
  }
}
