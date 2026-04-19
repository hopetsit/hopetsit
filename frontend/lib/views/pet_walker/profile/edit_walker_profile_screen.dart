import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/edit_walker_profile_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_text_field.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart' show CustomButton;
import 'package:hopetsit/widgets/city_location_picker.dart';

/// Dedicated "Edit profile" screen for walkers. Mirrors EditOwnerProfileScreen
/// visually but with walker-specific bits: a 60-minute walk rate field and a
/// single pickup preference toggle (no "at sitter" option).
class EditWalkerProfileScreen extends StatelessWidget {
  const EditWalkerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(EditWalkerProfileController());

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        leading: const BackButton(),
        title: PoppinsText(
          text: 'edit_profile_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: Obx(() {
        if (controller.isFetching.value) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
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

                    // Profile Picture
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
                                      : null) as ImageProvider?,
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
                                        child: const CircularProgressIndicator(
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

                    // Name
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

                    // Email (read-only)
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

                    // Phone
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InterText(
                          text: 'label_mobile_number'.tr,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary(context),
                        ),
                        SizedBox(height: 8.h),
                        FormField<String>(
                          validator: (_) {
                            final v =
                                controller.phoneController.text.trim();
                            if (v.isEmpty) {
                              return 'error_phone_required'.tr;
                            }
                            final allowedChars =
                                RegExp(r'^\+?[0-9\s\-\(\)]+$');
                            if (!allowedChars.hasMatch(v)) {
                              return 'error_phone_invalid'.tr;
                            }
                            final countryDigits = (controller
                                    .selectedCountryCode.value)
                                .replaceAll(RegExp(r'\D'), '');
                            final phoneDigits =
                                v.replaceAll(RegExp(r'\D'), '');
                            final fullDigits = countryDigits + phoneDigits;
                            if (!RegExp(r'^\d{7,15}$')
                                .hasMatch(fullDigits)) {
                              return 'error_phone_invalid'.tr;
                            }
                            return null;
                          },
                          builder: (field) {
                            final hasError = field.hasError;
                            return Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 50.h,
                                  decoration: BoxDecoration(
                                    color: AppColors.inputFill(context),
                                    border: hasError
                                        ? Border.all(
                                            color: AppColors.errorColor,
                                            width: 1,
                                          )
                                        : null,
                                    borderRadius:
                                        BorderRadius.circular(30.r),
                                    boxShadow: AppColors.cardShadow(context)
                                            .isEmpty
                                        ? []
                                        : [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.04),
                                              blurRadius: 10,
                                              offset: const Offset(0, 2),
                                            )
                                          ],
                                  ),
                                  child: Row(
                                    children: [
                                      CountryCodePicker(
                                        onChanged: (country) {
                                          controller
                                                  .selectedCountryCode.value =
                                              country.dialCode ?? '+1';
                                          field.didChange(
                                            controller.phoneController.text,
                                          );
                                        },
                                        initialSelection: controller
                                            .selectedCountryCode.value,
                                        showCountryOnly: false,
                                        showOnlyCountryWhenClosed: false,
                                        alignLeft: false,
                                        boxDecoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(16.r),
                                          color:
                                              AppColors.inputFill(context),
                                        ),
                                        textStyle: TextStyle(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w400,
                                          color: AppColors.textPrimary(
                                              context),
                                        ),
                                        dialogTextStyle: TextStyle(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w400,
                                          color: AppColors.textPrimary(
                                              context),
                                        ),
                                      ),
                                      Expanded(
                                        child: TextFormField(
                                          controller:
                                              controller.phoneController,
                                          keyboardType: TextInputType.phone,
                                          textInputAction:
                                              TextInputAction.next,
                                          onChanged: (_) => field.didChange(
                                            controller.phoneController.text,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'hint_phone'.tr,
                                            hintStyle: TextStyle(
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w400,
                                              color:
                                                  AppColors.textSecondary(
                                                      context),
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
                                            color: AppColors.textPrimary(
                                                context),
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

                    // Address
                    CustomTextField(
                      labelText: 'label_address'.tr,
                      hintText: 'hint_address'.tr,
                      controller: controller.addressController,
                      textInputAction: TextInputAction.next,
                      maxLines: 2,
                    ),

                    SizedBox(height: 20.h),

                    // City + map picker
                    Obx(
                      () => CityLocationPicker(
                        cityController: controller.locationController,
                        onGetLocation: () =>
                            controller.getCurrentLocationFromMaps(),
                        isGettingLocation:
                            controller.isGettingLocation.value,
                        detectedCity: controller.userCity.value,
                      ),
                    ),

                    SizedBox(height: 20.h),

                    // Bio
                    CustomTextField(
                      labelText: 'label_bio'.tr,
                      hintText: 'hint_bio'.tr,
                      controller: controller.bioController,
                      textInputAction: TextInputAction.next,
                      maxLines: 4,
                    ),

                    SizedBox(height: 20.h),

                    // Skills
                    CustomTextField(
                      labelText: 'label_skills'.tr,
                      hintText: 'hint_skills'.tr,
                      controller: controller.skillsController,
                      textInputAction: TextInputAction.next,
                      maxLines: 3,
                    ),

                    SizedBox(height: 20.h),

                    // Language
                    CustomTextField(
                      labelText: 'label_language'.tr,
                      hintText: 'hint_language'.tr,
                      controller: controller.languageController,
                      textInputAction: TextInputAction.next,
                    ),

                    SizedBox(height: 24.h),

                    // Walker-specific: 30-min walk rate (short walks).
                    InterText(
                      text: 'Tarif pour 30 min de balade',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                    SizedBox(height: 8.h),
                    TextFormField(
                      controller: controller.halfHourRateController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9\.,]'),
                        ),
                      ],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'Ex : 8',
                        suffixText: '€',
                        suffixStyle: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryColor,
                        ),
                        filled: true,
                        fillColor: AppColors.inputFill(context),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 14.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.r),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary(context),
                      ),
                      validator: (value) {
                        final v = (value ?? '').trim().replaceAll(',', '.');
                        if (v.isEmpty) return null; // optional
                        final parsed = double.tryParse(v);
                        if (parsed == null || parsed < 0) {
                          return 'Tarif invalide';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 16.h),

                    // Walker-specific: 60-min walk rate (aka "hourly rate").
                    InterText(
                      text: 'Tarif pour 60 min de balade',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                    SizedBox(height: 8.h),
                    TextFormField(
                      controller: controller.hourlyRateController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9\.,]'),
                        ),
                      ],
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: 'Ex : 15',
                        suffixText: '€',
                        suffixStyle: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryColor,
                        ),
                        filled: true,
                        fillColor: AppColors.inputFill(context),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 14.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.r),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary(context),
                      ),
                      validator: (value) {
                        final v = (value ?? '').trim().replaceAll(',', '.');
                        if (v.isEmpty) return null; // optional
                        final parsed = double.tryParse(v);
                        if (parsed == null || parsed < 0) {
                          return 'Tarif invalide';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 16.h),

                    // Walker-specific: single pickup toggle.
                    Obx(
                      () => SwitchListTile(
                        title: Text(
                          'J\'accepte d\'aller chercher le chien chez le propriétaire',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        value: controller.pickupAtOwner.value,
                        activeThumbColor: AppColors.primaryColor,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) =>
                            controller.pickupAtOwner.value = v,
                      ),
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
