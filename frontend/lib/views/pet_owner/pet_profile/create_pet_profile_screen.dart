import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:hopetsit/widgets/pet_enriched_fields.dart';
import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hopetsit/controllers/create_pet_profile_controller.dart';
import 'package:hopetsit/controllers/profile_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/views/pet_owner/bottom_nav/bottom_nav_wrapper.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_text_field.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/widgets/custom_app_bar.dart';

class CreatePetProfileScreen extends StatelessWidget {
  final String userType;
  final String serviceType;
  final String? email;
  final bool? fromSignup;

  const CreatePetProfileScreen({
    super.key,
    required this.userType,
    required this.serviceType,
    this.email,
    this.fromSignup = false,
  });

  @override
  Widget build(BuildContext context) {
    // Check if controller is already registered, if not create it
    final tag = '$userType-$serviceType';
    final controller = Get.isRegistered<CreatePetProfileController>(tag: tag)
        ? Get.find<CreatePetProfileController>(tag: tag)
        : Get.put(
            CreatePetProfileController(
              userType: userType,
              serviceType: serviceType,
            ),
            tag: tag,
            permanent: true, // Prevents disposal during navigation
          );

    final ProfileController profileController = Get.put(ProfileController());
    profileController.applyStoredUserProfileDisplay();
    profileController.ensureProfileLoadedForSession();

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
          leading: BackButton(),
          actions: [
            if (fromSignup == true)
              TextButton(
                onPressed: () => Get.to(() => const BottomNavWrapper()),
                child: InterText(
                  text: 'create_pet_skip'.tr,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryColor,
                ),
              ),
          ],
          onProfileTap: () {
            // Handle profile tap
            // debug removed
          },
        ),
        backgroundColor: AppColors.scaffold(context),
        body: SafeArea(
          child: Column(
            children: [
              // Title Container - Attached to AppBar with full width
              Container(
                padding: EdgeInsets.all(15),
                height: 54.h,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: PoppinsText(
                  text: 'create_pet_header'.tr,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary(context),
                ),
              ),

              // Rest of the content in scrollable area
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Form(
                      key: controller.formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 32.h),

                          // Pet Profile Image
                          Obx(
                            () => Center(
                              child: Stack(
                                children: [
                                  Container(
                                    width: 120.r,
                                    height: 120.r,
                                    decoration: BoxDecoration(
                                      color: AppColors.grey300Color,
                                      shape: BoxShape.circle,
                                    ),
                                    child: ClipOval(
                                      child: _buildPetProfileImage(controller),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 2,
                                    child: GestureDetector(
                                      onTap: controller.pickPetProfileImage,
                                      child: SvgPicture.asset(
                                        AppImages.editIcon,
                                        height: 28.h,
                                        width: 28.w,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: 32.h),

                          // Pet Name
                          CustomTextField(
                            labelText: 'create_pet_name_label'.tr,
                            hintText: 'create_pet_name_hint'.tr,
                            controller: controller.petNameController,
                            textInputAction: TextInputAction.next,
                          ),

                          SizedBox(height: 20.h),

                          // Breed
                          CustomTextField(
                            labelText: 'create_pet_breed_label'.tr,
                            hintText: 'create_pet_breed_hint'.tr,
                            controller: controller.breedController,
                            textInputAction: TextInputAction.next,
                          ),

                          SizedBox(height: 20.h),

                          // Date of Birth
                          CustomTextField(
                            labelText: 'create_pet_dob_label'.tr,
                            hintText: 'create_pet_dob_hint'.tr,
                            controller: controller.dateOfBirthController,
                            textInputAction: TextInputAction.next,
                            readOnly: true,
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                controller.dateOfBirthController.text = picked
                                    .toString()
                                    .split(' ')[0];
                              }
                            },
                          ),

                          SizedBox(height: 20.h),

                          // Weight and Height Row
                          Row(
                            children: [
                              Expanded(
                                child: CustomTextField(
                                  labelText: 'create_pet_weight_label'.tr,
                                  hintText: 'create_pet_weight_hint'.tr,
                                  controller: controller.weightController,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: CustomTextField(
                                  labelText: 'create_pet_height_label'.tr,
                                  hintText: 'create_pet_height_hint'.tr,
                                  controller: controller.heightController,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                  validator: (value) {
                                    final text = (value ?? '').trim();
                                    if (text.isEmpty) return null;
                                    // Strip non-numeric chars (e.g. "50cms" -> "50") before parsing
                                    final cleaned = text.replaceAll(
                                      RegExp(r'[^\d.]'),
                                      '',
                                    );
                                    if (cleaned.isEmpty) {
                                      return 'Height must be a valid number.';
                                    }
                                    final parsed = double.tryParse(cleaned);
                                    if (parsed == null || parsed <= 0) {
                                      return 'Height must be greater than 0.';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 20.h),

                          // Passport Number
                          CustomTextField(
                            labelText: 'create_pet_passport_label'.tr,
                            hintText: 'create_pet_passport_hint'.tr,
                            controller: controller.passportNumberController,
                            textInputAction: TextInputAction.next,
                          ),

                          SizedBox(height: 20.h),

                          // Chip Number
                          CustomTextField(
                            labelText: 'create_pet_chip_label'.tr,
                            hintText: 'create_pet_chip_hint'.tr,
                            controller: controller.chipNumberController,
                            textInputAction: TextInputAction.next,
                          ),

                          SizedBox(height: 20.h),

                          // Medication Allergies
                          CustomTextField(
                            labelText: 'create_pet_med_allergies_label'.tr,
                            hintText: 'create_pet_med_allergies_hint'.tr,
                            controller:
                                controller.medicationAllergiesController,
                            textInputAction: TextInputAction.next,
                          ),

                          SizedBox(height: 20.h),

                          // Category Dropdown
                          InterText(
                            text: 'create_pet_category_label'.tr,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.grey700Color,
                          ),
                          SizedBox(height: 8.h),
                          CustomDropdown(
                            items: [
                              'create_pet_category_dog'.tr,
                              'create_pet_category_cat'.tr,
                              'create_pet_category_bird'.tr,
                              'create_pet_category_rabbit'.tr,
                              'create_pet_category_other'.tr,
                            ],
                            onChanged: controller.setCategory,
                            closedHeaderPadding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 12.h,
                            ),
                            hintText: 'common_select_value'.tr,
                            decoration: CustomDropdownDecoration(
                              closedBorder: Border.all(
                                color: AppColors.grey300Color,
                              ),
                              closedBorderRadius: BorderRadius.circular(30.r),
                              headerStyle: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w400,
                                color: AppColors.blackColor,
                              ),
                            ),
                          ),

                          SizedBox(height: 20.h),

                          // Vaccination Dropdown
                          InterText(
                            text: 'create_pet_vaccination_label'.tr,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.grey700Color,
                          ),
                          SizedBox(height: 8.h),
                          CustomDropdown(
                            items: [
                              'create_pet_vaccination_up_to_date'.tr,
                              'create_pet_vaccination_not_vaccinated'.tr,
                              'create_pet_vaccination_partial'.tr,
                            ],
                            onChanged: controller.setVaccination,
                            closedHeaderPadding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 12.h,
                            ),
                            hintText: 'common_select_value'.tr,
                            decoration: CustomDropdownDecoration(
                              closedBorder: Border.all(
                                color: AppColors.grey300Color,
                              ),
                              closedBorderRadius: BorderRadius.circular(30.r),
                              headerStyle: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w400,
                                color: AppColors.blackColor,
                              ),
                            ),
                          ),

                          SizedBox(height: 20.h),

                          // Profile View Dropdown
                          InterText(
                            text: 'create_pet_profile_view_label'.tr,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.grey700Color,
                          ),
                          SizedBox(height: 8.h),
                          CustomDropdown(
                            items: [
                              'create_pet_profile_view_public'.tr,
                              'create_pet_profile_view_private'.tr,
                              'create_pet_profile_view_friends'.tr,
                            ],
                            onChanged: controller.setProfileView,
                            closedHeaderPadding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 12.h,
                            ),
                            hintText: 'common_select_value'.tr,
                            decoration: CustomDropdownDecoration(
                              closedBorder: Border.all(
                                color: AppColors.grey300Color,
                              ),
                              closedBorderRadius: BorderRadius.circular(30.r),
                              headerStyle: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w400,
                                color: AppColors.blackColor,
                              ),
                            ),
                          ),

                          SizedBox(height: 12.h),

                          // Upload Pet Pictures and Videos
                          Obx(
                            () => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: InterText(
                                        text:
                                            'create_pet_upload_media_label'.tr,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.grey700Color,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: controller.pickPetPicturesVideos,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 20.w,
                                          vertical: 12.h,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: AppColors.primaryColor,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            26.r,
                                          ),
                                        ),
                                        child: InterText(
                                          text:
                                              controller
                                                  .petPicturesVideos
                                                  .isNotEmpty
                                              ? 'create_pet_upload_media_change'
                                                    .trParams({
                                                      'count': controller
                                                          .petPicturesVideos
                                                          .length
                                                          .toString(),
                                                    })
                                              : 'create_pet_upload_media_upload'
                                                    .tr,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.blackColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // Show selected files count
                                if (controller
                                    .petPicturesVideos
                                    .isNotEmpty) ...[
                                  SizedBox(height: 10.h),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12.w,
                                      vertical: 8.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryColor.withOpacity(
                                        0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(8.r),
                                      border: Border.all(
                                        color: AppColors.primaryColor
                                            .withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: AppColors.primaryColor,
                                          size: 18.sp,
                                        ),
                                        SizedBox(width: 8.w),
                                        InterText(
                                          text:
                                              'create_pet_upload_media_selected'
                                                  .trParams({
                                                    'count': controller
                                                        .petPicturesVideos
                                                        .length
                                                        .toString(),
                                                  }),
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w400,
                                          color: AppColors.primaryColor,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          SizedBox(height: 15.h),

                          // Upload Passport Picture
                          Obx(
                            () => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: InterText(
                                        text: 'create_pet_upload_passport_label'
                                            .tr,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.grey700Color,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: controller.pickPassportImage,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 20.w,
                                          vertical: 12.h,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: AppColors.primaryColor,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            26.r,
                                          ),
                                        ),
                                        child: InterText(
                                          text:
                                              controller.passportImage.value !=
                                                  null
                                              ? 'create_pet_upload_passport_change'
                                                    .tr
                                              : 'create_pet_upload_passport_upload'
                                                    .tr,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.blackColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // Show selected file status
                                if (controller.passportImage.value != null) ...[
                                  SizedBox(height: 10.h),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12.w,
                                      vertical: 8.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryColor.withOpacity(
                                        0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(8.r),
                                      border: Border.all(
                                        color: AppColors.primaryColor
                                            .withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: AppColors.primaryColor,
                                          size: 18.sp,
                                        ),
                                        SizedBox(width: 8.w),
                                        Expanded(
                                          child: InterText(
                                            text:
                                                'create_pet_upload_passport_selected'
                                                    .tr,
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.w400,
                                            color: AppColors.primaryColor,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          SizedBox(height: 16.h),

                          // Sprint 6.5 step 1 — enriched sections shared with edit screen.
                          PetEnrichedFields(
                            ageController: controller.ageController,
                            behaviorController: controller.behaviorController,
                            regularVetNameController:
                                controller.regularVetNameController,
                            regularVetPhoneController:
                                controller.regularVetPhoneController,
                            regularVetAddressController:
                                controller.regularVetAddressController,
                            emergencyVetNameController:
                                controller.emergencyVetNameController,
                            emergencyVetPhoneController:
                                controller.emergencyVetPhoneController,
                            emergencyVetAddressController:
                                controller.emergencyVetAddressController,
                            emergencyAuthAccepted:
                                controller.emergencyAuthAccepted,
                            vaccinationsList: controller.vaccinationsList,
                            onAddVaccination: controller.addVaccination,
                            onRemoveVaccination: controller.removeVaccination,
                            onSetVaccinationField:
                                controller.setVaccinationField,
                          ),

                          SizedBox(height: 40.h),

                          // Create Pet Profile Button
                          Obx(
                            () => CustomButton(
                              title: controller.isLoading.value
                                  ? 'create_pet_button_creating'.tr
                                  : 'create_pet_button'.tr,
                              onTap: controller.isLoading.value
                                  ? null
                                  : () => controller
                                        .handleCreateProfileWithNavigation(),
                            ),
                          ),

                          SizedBox(height: 40.h),
                        ],
                      ),
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

  /// Build pet profile image with three priority levels:
  /// 1. If profileImageUrl is valid, display CachedNetworkImage
  /// 2. Else if petProfileImage file exists, display FileImage with error handling
  /// 3. Else display placeholder image
  Widget _buildPetProfileImage(CreatePetProfileController controller) {
    // Check if pet has a profile image URL (from existing pet)
    // You may need to add petProfileImageUrl to the controller if editing existing pet
    final petImageUrl =
        ''; // Replace with controller.petProfileImageUrl.value if available

    // If profile image URL is valid (starts with http)
    if (petImageUrl.isNotEmpty &&
        (petImageUrl.startsWith('http://') ||
            petImageUrl.startsWith('https://'))) {
      return CachedNetworkImage(
        imageUrl: petImageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
          ),
        ),
        errorWidget: (context, url, error) =>
            Image.asset(AppImages.placeholderImage, fit: BoxFit.cover),
      );
    }

    // Else if local file image is selected
    if (controller.petProfileImage.value != null &&
        controller.petProfileImage.value!.path.isNotEmpty) {
      // Wrap Image.file with error handling
      return _buildFileImage(controller.petProfileImage.value!);
    }

    // Else display placeholder image
    return Image.asset(AppImages.placeholderImage, fit: BoxFit.cover);
  }

  /// Safely load a file image with error handling for corrupted images
  Widget _buildFileImage(File imageFile) {
    return Image.file(
      imageFile,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        // If file image fails to load (corrupted, invalid format, etc.)
        // Show placeholder instead
        return Container(
          color: AppColors.grey300Color,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_not_supported_outlined,
                  color: AppColors.greyColor,
                  size: 40.sp,
                ),
                SizedBox(height: 8.h),
                InterText(
                  text: 'Image failed to load',
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.greyColor,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
