import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/controllers/reviews_controller.dart';

class ReviewsScreen extends StatelessWidget {
  final String serviceProviderName;
  final String phoneNumber;
  final String email;
  final String? profileImagePath;
  final String? serviceProviderId;
  // v18.6 — chaîne de trust pour le submit review :
  // le backend exige une booking completed/paid entre owner et provider.
  // On passe bookingId + revieweeRole pour lever toute ambiguïté
  // sitter vs walker.
  final String? bookingId;
  final String? revieweeRole; // 'sitter' | 'walker'

  const ReviewsScreen({
    super.key,
    required this.serviceProviderName,
    required this.phoneNumber,
    required this.email,
    this.profileImagePath,
    this.serviceProviderId,
    this.bookingId,
    this.revieweeRole,
  });

  @override
  Widget build(BuildContext context) {
    final ReviewsController controller = Get.put(ReviewsController());
    final TextEditingController descriptionController = TextEditingController();

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        leading: BackButton(),
        title: PoppinsText(
          text: 'reviews_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: AppColors.card(context),
                      borderRadius: BorderRadius.circular(11.r),
                      boxShadow: AppColors.cardShadow(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile Information Section
                        Row(
                          children: [
                            // Profile Picture
                            CircleAvatar(
                              radius: 40.r,
                              backgroundImage: profileImagePath != null
                                  ? NetworkImage(profileImagePath ?? '')
                                  : AssetImage(
                                      profileImagePath ??
                                          AppImages.placeholderImage,
                                    ),
                            ),
                            SizedBox(width: 16.w),
                            // Contact Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Name
                                  PoppinsText(
                                    text: serviceProviderName,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary(context),
                                  ),
                                  SizedBox(height: 8.h),
                                  // Phone Number
                                  Row(
                                    children: [
                                      Image.asset(
                                        AppImages.callIcon,
                                        width: 16.w,
                                        height: 16.h,
                                        color: AppColors.primaryColor,
                                      ),
                                      SizedBox(width: 8.w),
                                      InterText(
                                        text: phoneNumber,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.grey500Color,
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4.h),
                                  // Email Address (wrap/ellipsis to avoid overflow)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Image.asset(
                                        AppImages.addressIcon,
                                        width: 16.w,
                                        height: 16.h,
                                        color: AppColors.primaryColor,
                                      ),
                                      SizedBox(width: 8.w),
                                      Expanded(
                                        child: InterText(
                                          text: email,
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w400,
                                          color: AppColors.grey500Color,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 24.h),

                        // Rating Section
                        PoppinsText(
                          text: 'reviews_rate_label'.tr,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context),
                        ),
                        SizedBox(height: 12.h),
                        // Star Rating
                        Obx(
                          () => Row(
                            children: List.generate(5, (index) {
                              return GestureDetector(
                                onTap: () {
                                  controller.setRating(index + 1);
                                },
                                child: Padding(
                                  padding: EdgeInsets.only(right: 8.w),
                                  child: Icon(
                                    index < controller.rating.value
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: index < controller.rating.value
                                        ? Colors.amber
                                        : AppColors.grey500Color,
                                    size: 32.sp,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),

                        SizedBox(height: 24.h),

                        // Description Section
                        InterText(
                          text: 'reviews_description_label'.tr,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary(context),
                        ),
                        SizedBox(height: 12.h),
                        // Text Input Field
                        Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: AppColors.inputFill(context),
                            borderRadius: BorderRadius.circular(20.r),
                            boxShadow: AppColors.cardShadow(context),
                          ),
                          child: TextField(
                            controller: descriptionController,
                            maxLines: 6,
                            onChanged: (value) {
                              controller.setDescription(value);
                            },
                            decoration: InputDecoration(
                              hintText: 'reviews_description_hint'.tr,
                              hintStyle: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w400,
                                color: AppColors.grey500Color,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ),

                        SizedBox(height: 24.h),

                        // Submit Button
                        Align(
                          alignment: Alignment.centerRight,
                          child: Obx(
                            () => CustomButton(
                              width: 120.w,
                              height: 48.h,
                              radius: 48.r,
                              title: controller.isLoading.value
                                  ? 'reviews_submitting'.tr
                                  : 'reviews_submit'.tr,
                              bgColor: AppColors.primaryColor,
                              textColor: AppColors.whiteColor,
                              onTap:
                                  controller.canSubmit &&
                                      !controller.isLoading.value
                                  ? () => controller.submitReview(
                                      serviceProviderId:
                                          serviceProviderId ?? '',
                                      serviceProviderName: serviceProviderName,
                                      bookingId: bookingId,
                                      revieweeRole: revieweeRole,
                                    )
                                  : null,
                            ),
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
      ),
    );
  }
}
