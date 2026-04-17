import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/widgets/app_text.dart';

class PetDetailScreen extends StatefulWidget {
  final String petName;
  final String breed;
  final String age;
  final String gender;
  final String weight;
  final String height;
  final String color;
  final String description;
  final List<String> vaccinations;
  final List<String> galleryImages;
  final List<String> petImages; // Changed from String petImage to List<String>
  final String? sitterProfileImage;
  final String? ownerName;
  final String? ownerAvatar;
  final String? ownerCreatedAt;
  final String? ownerUpdatedAt;
  final String? passportNumber;
  final String? chipNumber;
  final String? medicationAllergies;
  final String? dob;
  final String? category;

  const PetDetailScreen({
    super.key,
    required this.petName,
    required this.breed,
    required this.age,
    required this.gender,
    required this.weight,
    required this.height,
    required this.color,
    required this.description,
    required this.vaccinations,
    required this.galleryImages,
    required this.petImages,
    this.sitterProfileImage,
    this.ownerName,
    this.ownerAvatar,
    this.ownerCreatedAt,
    this.ownerUpdatedAt,
    this.passportNumber,
    this.chipNumber,
    this.medicationAllergies,
    this.dob,
    this.category,
  });

  @override
  State<PetDetailScreen> createState() => _PetDetailScreenState();
}

class _PetDetailScreenState extends State<PetDetailScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
        title: InterText(
          text: widget.petName,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16.w),
            child: CircleAvatar(
              radius: 16.r,
              backgroundColor: AppColors.primaryColor,
              child: CircleAvatar(
                radius: 14.r,
                backgroundColor: AppColors.grey300Color,
                backgroundImage:
                    widget.sitterProfileImage != null &&
                        widget.sitterProfileImage!.isNotEmpty &&
                        (widget.sitterProfileImage!.startsWith('http://') ||
                            widget.sitterProfileImage!.startsWith('https://'))
                    ? CachedNetworkImageProvider(widget.sitterProfileImage!)
                    : null,
                child:
                    widget.sitterProfileImage == null ||
                        widget.sitterProfileImage!.isEmpty ||
                        (!widget.sitterProfileImage!.startsWith('http://') &&
                            !widget.sitterProfileImage!.startsWith('https://'))
                    ? Icon(
                        Icons.person,
                        size: 20.sp,
                        color: AppColors.greyColor,
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Column(
            children: [
              // Hero Section
              _buildHeroSection(),

              // Content Sections
              Padding(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // About Pet Section
                    _buildAboutSection(),
                    SizedBox(height: 24.h),

                    // Vaccinations Section
                    _buildVaccinationsSection(),
                    SizedBox(height: 24.h),

                    // Owner Information Section (if available)
                    if (widget.ownerName != null) ...[
                      _buildOwnerSection(),
                      SizedBox(height: 24.h),
                    ],

                    // Gallery Section
                    _buildGallerySection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    final hasImages = widget.petImages.isNotEmpty;
    final hasMultipleImages = widget.petImages.length > 1;

    return SizedBox(
      height: 350.h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Image Slider or Single Image
          Container(
            width: double.infinity,
            height: 300.h,
            decoration: BoxDecoration(color: AppColors.lightGrey),
            child: hasImages
                ? (hasMultipleImages
                      ? _buildImageSlider()
                      : _buildSingleImage(widget.petImages.first))
                : Center(
                    child: Image.asset(
                      AppImages.placeholderImage,
                      width: 60.w,
                      height: 60.h,
                      fit: BoxFit.cover,
                    ),
                  ),
          ),

          // Page Indicators (only show if multiple images)
          if (hasMultipleImages)
            Positioned(
              bottom: 120.h,
              left: 0,
              right: 0,
              child: _buildPageIndicators(),
            ),

          // Profile Overlay Card
          Positioned(
            bottom: -10.h,
            left: 8.w,
            right: 8.w,
            child: Container(
              height: 110.h,
              decoration: BoxDecoration(
                color: AppColors.card(context).withOpacity(0.9),
                borderRadius: BorderRadius.all(Radius.circular(26.r)),
              ),
              padding: EdgeInsets.all(26.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column - Pet Name and Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PoppinsText(
                          text: widget.petName,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                        SizedBox(height: 4.h),
                        PoppinsText(
                          text: '${widget.breed} . ${widget.age}',
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary(context),
                        ),
                      ],
                    ),
                  ),

                  // Right Column - Gender Container
                  Container(
                    width: 39.w,
                    height: 39.h,
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Center(
                      child: Image.asset(
                        AppImages.genderIcon,
                        width: 16.w,
                        height: 16.h,
                        color: AppColors.whiteColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
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
              text: 'pet_detail_about'.tr.replaceAll('@name', widget.petName),
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildDetailBox('pet_detail_weight'.tr, widget.weight, AppColors.primaryColor),
            _buildDetailBox('pet_detail_height'.tr, widget.height, AppColors.primaryColor),
            _buildDetailBox('pet_detail_color'.tr, widget.color, AppColors.primaryColor),
          ],
        ),
        SizedBox(height: 16.h),
        PoppinsText(
          text: widget.description,
          fontSize: 12.sp,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary(context),
        ),
        // Additional pet details
        if (widget.passportNumber != null &&
            widget.passportNumber!.isNotEmpty) ...[
          SizedBox(height: 12.h),
          _buildDetailRow('pet_detail_passport_number'.tr, widget.passportNumber!),
        ],
        if (widget.chipNumber != null && widget.chipNumber!.isNotEmpty) ...[
          SizedBox(height: 12.h),
          _buildDetailRow('pet_detail_chip_number'.tr, widget.chipNumber!),
        ],
        if (widget.medicationAllergies != null &&
            widget.medicationAllergies!.isNotEmpty) ...[
          SizedBox(height: 12.h),
          _buildDetailRow('pet_detail_medication_allergies'.tr, widget.medicationAllergies!),
        ],
        if (widget.dob != null && widget.dob!.isNotEmpty) ...[
          SizedBox(height: 12.h),
          _buildDetailRow('pet_detail_date_of_birth'.tr, widget.dob!),
        ],
        if (widget.category != null && widget.category!.isNotEmpty) ...[
          SizedBox(height: 12.h),
          _buildDetailRow('pet_detail_category'.tr, widget.category!),
        ],
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: PoppinsText(
            text: '$label:',
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.greyText,
          ),
        ),
        Expanded(
          flex: 3,
          child: PoppinsText(
            text: value,
            fontSize: 12.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.blackColor,
          ),
        ),
      ],
    );
  }

  Widget _buildVaccinationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Image.asset(AppImages.skillIcon, width: 26.w, height: 26.h),
            SizedBox(width: 8.w),
            PoppinsText(
              text: 'pet_detail_vaccinations'.tr.replaceAll('@name', widget.petName),
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.blackColor,
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: widget.vaccinations
              .map((vaccination) => _buildVaccinationTag(vaccination))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildGallerySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Image.asset(AppImages.skillIcon, width: 26.w, height: 26.h),
            SizedBox(width: 8.w),
            PoppinsText(
              text: 'pet_detail_gallery'.tr.replaceAll('@name', widget.petName),
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.blackColor,
            ),
          ],
        ),
        SizedBox(height: 12.h),
        if (widget.galleryImages.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24.h),
              child: InterText(
                text: 'pet_detail_no_photos'.tr,
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.greyColor,
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8.w,
              mainAxisSpacing: 8.h,
              childAspectRatio: 1,
            ),
            itemCount: widget.galleryImages.length,
            itemBuilder: (context, index) {
              final imageUrl = widget.galleryImages[index];
              final isNetworkImage =
                  imageUrl.startsWith('http://') ||
                  imageUrl.startsWith('https://');

              return ClipRRect(
                borderRadius: BorderRadius.circular(5.r),
                child: isNetworkImage
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppColors.lightGrey,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryColor,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.lightGrey,
                          child: Icon(
                            Icons.broken_image,
                            color: AppColors.greyColor,
                          ),
                        ),
                      )
                    : Image.asset(imageUrl, fit: BoxFit.cover),
              );
            },
          ),
      ],
    );
  }

  Widget _buildDetailBox(String title, String value, Color valueColor) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4.w),
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
        decoration: BoxDecoration(
          color: AppColors.detailBoxColor,
          borderRadius: BorderRadius.circular(17.r),
        ),
        child: Column(
          children: [
            PoppinsText(
              text: title,
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.greyColor,
            ),
            SizedBox(height: 4.h),
            PoppinsText(
              text: value,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVaccinationTag(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primaryColor),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: PoppinsText(
        text: text,
        fontSize: 14.sp,
        fontWeight: FontWeight.w500,
        color: AppColors.greyColor,
      ),
    );
  }

  Widget _buildOwnerSection() {
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
              text: 'pet_detail_owner_information'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: AppColors.cardShadow(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.ownerName != null && widget.ownerName!.isNotEmpty) ...[
                _buildOwnerDetailRow(context, 'pet_detail_owner_name'.tr, widget.ownerName!),
                SizedBox(height: 12.h),
              ],
              if (widget.ownerCreatedAt != null &&
                  widget.ownerCreatedAt!.isNotEmpty) ...[
                _buildOwnerDetailRow(
                  context,
                  'pet_detail_owner_created_at'.tr,
                  _formatDate(widget.ownerCreatedAt!),
                ),
                SizedBox(height: 12.h),
              ],
              if (widget.ownerUpdatedAt != null &&
                  widget.ownerUpdatedAt!.isNotEmpty)
                _buildOwnerDetailRow(
                  context,
                  'pet_detail_owner_updated_at'.tr,
                  _formatDate(widget.ownerUpdatedAt!),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOwnerDetailRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: PoppinsText(
            text: '$label:',
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary(context),
          ),
        ),
        Expanded(
          flex: 3,
          child: PoppinsText(
            text: value,
            fontSize: 13.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.textPrimary(context),
          ),
        ),
      ],
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  Widget _buildImageSlider() {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: (index) {
        setState(() {
          _currentPage = index;
        });
      },
      itemCount: widget.petImages.length,
      itemBuilder: (context, index) {
        final imageUrl = widget.petImages[index];
        final isNetworkImage =
            imageUrl.startsWith('http://') || imageUrl.startsWith('https://');

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(color: AppColors.lightGrey),
          child: isNetworkImage
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: AppColors.lightGrey,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: AppColors.lightGrey,
                    child: Center(
                      child: Image.asset(
                        AppImages.placeholderImage,
                        width: 60.w,
                        height: 60.h,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                )
              : Image.asset(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.lightGrey,
                    child: Center(
                      child: Image.asset(
                        AppImages.placeholderImage,
                        width: 60.w,
                        height: 60.h,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildSingleImage(String imageUrl) {
    final isNetworkImage =
        imageUrl.startsWith('http://') || imageUrl.startsWith('https://');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: AppColors.lightGrey),
      child: isNetworkImage
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: AppColors.lightGrey,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryColor,
                    ),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: AppColors.lightGrey,
                child: Center(
                  child: Image.asset(
                    AppImages.placeholderImage,
                    width: 60.w,
                    height: 60.h,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            )
          : Image.asset(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: AppColors.lightGrey,
                child: Center(
                  child: Image.asset(
                    AppImages.placeholderImage,
                    width: 60.w,
                    height: 60.h,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildPageIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.petImages.length,
        (index) => Container(
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          width: _currentPage == index ? 24.w : 8.w,
          height: 8.h,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? AppColors.primaryColor
                : AppColors.whiteColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),
      ),
    );
  }
}
