import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/controllers/reviews_controller.dart';

class ReviewsScreen extends StatefulWidget {
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
  // v23.1.291 — note pré-sélectionnée depuis la carte de réservation (l'owner
  // tape une étoile sur la carte → l'écran s'ouvre avec cette note).
  final int initialRating;

  const ReviewsScreen({
    super.key,
    required this.serviceProviderName,
    required this.phoneNumber,
    required this.email,
    this.profileImagePath,
    this.serviceProviderId,
    this.bookingId,
    this.revieweeRole,
    this.initialRating = 0,
  });

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  late final ReviewsController controller;
  late final TextEditingController descriptionController;

  @override
  void initState() {
    super.initState();
    controller = Get.put(ReviewsController());
    descriptionController = TextEditingController();
    // v23.1.290 — charge l'avis existant ; s'il existe, on pré-remplit le champ
    // de texte (le TextField n'est pas lié au Rx, il faut l'alimenter à la main).
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    await controller.loadExistingReview(widget.bookingId);
    if (!mounted) return;
    if (controller.isEditing.value) {
      descriptionController.text = controller.description.value;
    } else if (widget.initialRating > 0) {
      // Pré-sélection venue de la carte de réservation.
      controller.setRating(widget.initialRating);
    }
  }

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.card(context),
        title: PoppinsText(
          text: 'reviews_delete_confirm_title'.tr,
          fontSize: 16.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
        content: InterText(
          text: 'reviews_delete_confirm_body'.tr,
          fontSize: 14.sp,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: InterText(
              text: 'common_cancel'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.grey500Color,
            ),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: InterText(
              text: 'reviews_delete'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await controller.deleteReview();
    }
  }

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
                              // v23.1 part 243 round 3 — perf.
                              backgroundImage: widget.profileImagePath != null
                                  ? CachedNetworkImageProvider(
                                      widget.profileImagePath ?? '',
                                      maxWidth: 200,
                                    ) as ImageProvider
                                  : AssetImage(
                                      widget.profileImagePath ??
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
                                    text: widget.serviceProviderName,
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
                                        text: widget.phoneNumber,
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
                                          text: widget.email,
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

                        // Submit / Edit Button
                        Align(
                          alignment: Alignment.centerRight,
                          child: Obx(
                            () => CustomButton(
                              width: 120.w,
                              height: 48.h,
                              radius: 48.r,
                              title: controller.isLoading.value
                                  ? 'reviews_submitting'.tr
                                  : (controller.isEditing.value
                                        ? 'reviews_edit'.tr
                                        : 'reviews_submit'.tr),
                              bgColor: AppColors.primaryColor,
                              textColor: AppColors.whiteColor,
                              onTap:
                                  controller.canSubmit &&
                                      !controller.isLoading.value
                                  ? () => controller.submitReview(
                                      serviceProviderId:
                                          widget.serviceProviderId ?? '',
                                      serviceProviderName:
                                          widget.serviceProviderName,
                                      bookingId: widget.bookingId,
                                      revieweeRole: widget.revieweeRole,
                                    )
                                  : null,
                            ),
                          ),
                        ),

                        // v23.1.290 — bouton "Supprimer mon avis" (mode édition).
                        Obx(
                          () => controller.isEditing.value
                              ? Padding(
                                  padding: EdgeInsets.only(top: 12.h),
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: controller.isLoading.value
                                          ? null
                                          : _confirmDelete,
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.red,
                                        size: 18.sp,
                                      ),
                                      label: InterText(
                                        text: 'reviews_delete'.tr,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
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
