import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/edit_sitter_profile_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_text_field.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart' show CustomButton;
import 'package:hopetsit/widgets/city_location_picker.dart';
import 'package:hopetsit/utils/currency_helper.dart';

class EditSitterProfileScreen extends StatelessWidget {
  const EditSitterProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(EditSitterProfileController());

    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      appBar: AppBar(
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        leading: BackButton(),
        title: PoppinsText(
          text: 'edit_profile_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.blackColor,
        ),
      ),
      body: Obx(() {
        if (controller.isFetching.value) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
            ),
          );
        }

        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Form(
                key: controller.formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 32.h),

                    // Profile Picture Section
                    Center(
                      child: Stack(
                        children: [
                          Obx(() {
                            final imageFile = controller.profileImage.value;
                            final imageUrl = controller.currentAvatarUrl.value;

                            return CircleAvatar(
                              radius: 60.r,
                              backgroundColor: AppColors.grey300Color,
                              backgroundImage: imageFile != null
                                  ? FileImage(imageFile)
                                  : (imageUrl.isNotEmpty
                                        ? CachedNetworkImageProvider(imageUrl)
                                        : null),
                              child: imageFile == null && imageUrl.isEmpty
                                  ? Icon(
                                      Icons.person,
                                      size: 40.sp,
                                      color: AppColors.greyColor,
                                    )
                                  : null,
                            );
                          }),
                          Positioned(
                            bottom: 0,
                            right: 2,
                            child: Obx(
                              () => GestureDetector(
                                onTap: controller.isUploadingImage.value
                                    ? null
                                    : () =>
                                          controller.pickProfileImage(context),
                                child: controller.isUploadingImage.value
                                    ? Container(
                                        width: 28.w,
                                        height: 28.h,
                                        padding: EdgeInsets.all(4.w),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                AppColors.primaryColor,
                                              ),
                                        ),
                                      )
                                    : SvgPicture.asset(
                                        AppImages.editIcon,
                                        height: 28.h,
                                        width: 28.w,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32.h),

                    // Name Field
                    CustomTextField(
                      labelText: 'label_name'.tr,
                      hintText: 'hint_name'.tr,
                      controller: controller.nameController,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'error_name_required'.tr;
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 20.h),

                    // Email Field
                    CustomTextField(
                      labelText: 'label_email'.tr,
                      hintText: 'hint_email'.tr,
                      controller: controller.emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      enabled: false,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'error_email_required'.tr;
                        }
                        if (!GetUtils.isEmail(value.trim())) {
                          return 'error_email_invalid'.tr;
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 20.h),

                    // Phone Field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InterText(
                          text: 'label_mobile_number'.tr,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.blackColor,
                        ),
                        SizedBox(height: 8.h),
                        FormField<String>(
                          validator: (_) {
                            final v = controller.phoneController.text.trim();
                            if (v.isEmpty) {
                              return 'error_phone_required'.tr;
                            }
                            final allowedChars = RegExp(r'^\+?[0-9\s\-\(\)]+$');
                            if (!allowedChars.hasMatch(v)) {
                              return 'error_phone_invalid'.tr;
                            }
                            // Combine country code + phone for full number (E.164: 7-15 digits)
                            final countryDigits =
                                (controller.selectedCountryCode.value)
                                    .replaceAll(RegExp(r'\D'), '');
                            final phoneDigits = v.replaceAll(RegExp(r'\D'), '');
                            final fullDigits = countryDigits + phoneDigits;
                            if (!RegExp(r'^\d{7,15}$').hasMatch(fullDigits)) {
                              return 'error_phone_invalid'.tr;
                            }
                            return null;
                          },
                          builder: (field) {
                            final hasError = field.hasError;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 50.h,
                                  decoration: BoxDecoration(
                                    color: AppColors.whiteColor,
                                    border: Border.all(
                                      color: hasError
                                          ? AppColors.errorColor
                                          : AppColors.grey300Color,
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(30.r),
                                  ),
                                  child: Row(
                                    children: [
                                      CountryCodePicker(
                                        onChanged: (country) {
                                          controller.selectedCountryCode.value =
                                              country.dialCode ?? '+1';
                                          field.didChange(
                                            controller.phoneController.text,
                                          );
                                        },
                                        initialSelection: controller
                                            .selectedCountryCode
                                            .value,
                                        showCountryOnly: false,
                                        showOnlyCountryWhenClosed: false,
                                        alignLeft: false,
                                        boxDecoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            16.r,
                                          ),
                                          color: AppColors.whiteColor,
                                        ),
                                        textStyle: TextStyle(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w400,
                                          color: AppColors.blackColor,
                                        ),
                                        dialogTextStyle: TextStyle(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w400,
                                          color: AppColors.blackColor,
                                        ),
                                      ),
                                      Expanded(
                                        child: TextFormField(
                                          controller:
                                              controller.phoneController,
                                          keyboardType: TextInputType.phone,
                                          textInputAction: TextInputAction.next,
                                          onChanged: (_) => field.didChange(
                                            controller.phoneController.text,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'hint_phone'.tr,
                                            hintStyle: TextStyle(
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w400,
                                              color: AppColors.greyColor,
                                            ),
                                            border: InputBorder.none,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 16.w,
                                                  vertical: 12.h,
                                                ),
                                          ),
                                          style: TextStyle(
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w400,
                                            color: AppColors.blackColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (hasError && field.errorText != null)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      left: 12.w,
                                      top: 4.h,
                                    ),
                                    child: Text(
                                      field.errorText!,
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.errorColor,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),

                    SizedBox(height: 20.h),

                    // Address Field
                    CustomTextField(
                      labelText: 'label_address'.tr,
                      hintText: 'hint_address'.tr,
                      controller: controller.addressController,
                      textInputAction: TextInputAction.next,
                      maxLines: 2,
                    ),

                    SizedBox(height: 20.h),

                    // Location selection (same behavior as edit owner profile)
                    Obx(
                      () => CityLocationPicker(
                        cityController: controller.locationController,
                        onGetLocation: () =>
                            controller.getCurrentLocationFromMaps(),
                        isGettingLocation: controller.isGettingLocation.value,
                        detectedCity: controller.userCity.value,
                        onLocationSelected: (city, latitude, longitude) {
                          controller.userCity.value = city;
                          controller.userLatitude.value = latitude;
                          controller.userLongitude.value = longitude;
                        },
                      ),
                    ),

                    SizedBox(height: 20.h),

                    // Bio Field
                    CustomTextField(
                      labelText: 'label_bio'.tr,
                      hintText: 'hint_bio'.tr,
                      controller: controller.bioController,
                      textInputAction: TextInputAction.next,
                      maxLines: 4,
                    ),

                    SizedBox(height: 20.h),

                    // Skills Field
                    CustomTextField(
                      labelText: 'label_skills'.tr,
                      hintText: 'hint_skills'.tr,
                      controller: controller.skillsController,
                      textInputAction: TextInputAction.next,
                      maxLines: 3,
                    ),

                    SizedBox(height: 20.h),

                    // Hourly Rate Field
                    CustomTextField(
                      labelText: 'sitter_detail_hourly_rate_label'.tr,
                      hintText: '0.00',
                      controller: controller.hourlyRateController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          // Allow empty (optional field); controller enforces > 0 when present
                          return null;
                        }
                        final cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');
                        final rate = double.tryParse(cleaned);
                        if (rate == null) {
                          return 'error_rate_invalid'.tr;
                        }
                        if (rate <= 0) {
                          return 'error_rate_zero'.tr;
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 20.h),

                    // Weekly Rate Field
                    CustomTextField(
                      labelText: 'sitter_detail_weekly_rate_label'.tr,
                      hintText: '0.00',
                      controller: controller.weeklyRateController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return null;
                        }
                        final cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');
                        final rate = double.tryParse(cleaned);
                        if (rate == null) {
                          return 'error_rate_invalid'.tr;
                        }
                        if (rate <= 0) {
                          return 'error_rate_zero'.tr;
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 20.h),

                    // Monthly Rate Field
                    CustomTextField(
                      labelText: 'sitter_detail_monthly_rate_label'.tr,
                      hintText: '0.00',
                      controller: controller.monthlyRateController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return null;
                        }
                        final cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');
                        final rate = double.tryParse(cleaned);
                        if (rate == null) {
                          return 'error_rate_invalid'.tr;
                        }
                        if (rate <= 0) {
                          return 'error_rate_zero'.tr;
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 20.h),

                    // Currency for hourly rate
                    Obx(
                      () => CustomDropdown<String>(
                        items: controller.currencyOptions,
                        initialItem: CurrencyHelper.label(
                          controller.selectedCurrency.value,
                        ),
                        onChanged: controller.updateCurrency,
                        closedHeaderPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 12.h,
                        ),
                        decoration: CustomDropdownDecoration(
                          closedBorder: Border.all(
                            color: AppColors.grey300Color,
                          ),
                          closedBorderRadius: BorderRadius.circular(30.r),
                          headerStyle: GoogleFonts.inter(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w400,
                            color: AppColors.blackColor,
                          ),
                        ),
                        disabledDecoration: CustomDropdownDisabledDecoration(
                          border: Border.all(color: AppColors.grey300Color),
                        ),
                      ),
                    ),

                    SizedBox(height: 20.h),

                    // Language Field
                    CustomTextField(
                      labelText: 'label_language'.tr,
                      hintText: 'hint_language'.tr,
                      controller: controller.languageController,
                      textInputAction: TextInputAction.done,
                    ),

                    SizedBox(height: 40.h),

                    // Update Profile Button
                    Obx(
                      () => CustomButton(
                        title: controller.isLoading.value
                            ? 'edit_profile_button_updating'.tr
                            : 'edit_profile_button'.tr,
                        onTap: controller.isLoading.value
                            ? null
                            : () => controller
                                  .handleUpdateProfileWithNavigation(),
                        bgColor: AppColors.primaryColor,
                        textColor: AppColors.whiteColor,
                        height: 48.h,
                        radius: 48.r,
                      ),
                    ),

                    SizedBox(height: 40.h),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
