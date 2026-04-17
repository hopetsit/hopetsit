import 'dart:io';

import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/sign_up_controller.dart';
import 'package:hopetsit/repositories/auth_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_text_field.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/widgets/city_location_picker.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

class SignUpScreen extends StatelessWidget {
  final String userType; // 'pet_owner' or 'pet_sitter'

  const SignUpScreen({super.key, required this.userType});

  @override
  Widget build(BuildContext context) {
    // Check if controller is already registered, if not create it
    final controller = Get.isRegistered<SignUpController>(tag: userType)
        ? Get.find<SignUpController>(tag: userType)
        : Get.put(
            SignUpController(
              userType: userType,
              authRepository: Get.find<AuthRepository>(),
            ),
            tag: userType,
            permanent: true, // Prevents disposal during navigation
          );
    final authController = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>()
        : Get.put(
            AuthController(Get.find<AuthRepository>(), GetStorage()),
            tag: userType,
            permanent: true, // Prevents disposal during navigation
          );

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.backgroundDark : Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.backgroundDark : Colors.white,
        leading: BackButton(
          color: AppColors.textPrimary(context),
          onPressed: () => Get.back(),
        ),
        title: PoppinsText(
          text: userType == 'pet_owner'
              ? 'sign_up_as_pet_owner'.tr
              : 'sign_up_as_pet_sitter'.tr,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0.w),
                child: Form(
                  key: controller.formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      SizedBox(height: 8.h),
                      // InterText(
                      //   text: userType == 'pet_owner'
                      //       ? 'Signing up as a Pet Owner'
                      //       : 'Signing up as a Pet Sitter',
                      //   fontSize: 15,
                      //   fontWeight: FontWeight.w400,
                      //   color: AppColors.greyColor,
                      // ),
                      // const SizedBox(height: 20),
                      // Full Name
                      CustomTextField(
                        labelText: 'label_name'.tr,
                        hintText: 'hint_name'.tr,
                        controller: controller.nameController,
                        keyboardType: TextInputType.name,
                        textInputAction: TextInputAction.next,
                        validator: controller.validateName,
                      ),
                      SizedBox(height: 20.h),
                      // Email
                      CustomTextField(
                        labelText: 'label_email'.tr,
                        hintText: 'hint_email'.tr,
                        controller: controller.emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: controller.validateEmail,
                      ),
                      SizedBox(height: 20.h),
                      // Phone Number (Optional)
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
                            validator: (_) => controller.validatePhone(
                              controller.phoneController.text,
                              countryCode: controller.selectedCountryCode.value,
                            ),
                            builder: (field) {
                              final hasError = field.hasError;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: 50.h,
                                    decoration: BoxDecoration(
                                      color: AppColors.card(context),
                                      border: Border.all(
                                        color: hasError
                                            ? AppColors.errorColor
                                            : AppColors.textSecondary(context).withOpacity(0.2),
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.circular(30.r),
                                    ),
                                    child: Row(
                                      children: [
                                        CountryCodePicker(
                                          boxDecoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              16.r,
                                            ),
                                            color: AppColors.card(context),
                                          ),
                                          onChanged: (country) {
                                            controller
                                                    .selectedCountryCode
                                                    .value =
                                                country.dialCode ?? '+1';
                                            // Sprint 6.5 step 2 — persist ISO-2 country code too.
                                            controller.selectedCountry.value =
                                                country.code ?? 'US';
                                            field.didChange(
                                              controller.phoneController.text,
                                            );
                                          },
                                          initialSelection: 'US',
                                          favorite: const ['+1', 'US'],
                                          showCountryOnly: false,
                                          showOnlyCountryWhenClosed: false,
                                          alignLeft: false,
                                          padding: EdgeInsets.zero,
                                          textStyle: GoogleFonts.inter(
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w400,
                                            color: AppColors.textPrimary(context),
                                          ),
                                          dialogTextStyle: GoogleFonts.inter(
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w400,
                                            color: AppColors.textPrimary(context),
                                          ),
                                        ),
                                        Expanded(
                                          child: TextFormField(
                                            controller:
                                                controller.phoneController,
                                            keyboardType: TextInputType.phone,
                                            textInputAction:
                                                TextInputAction.next,
                                            onChanged: field.didChange,
                                            decoration: InputDecoration(
                                              hintText: 'hint_phone'.tr,
                                              hintStyle: GoogleFonts.inter(
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
                                            style: GoogleFonts.inter(
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w400,
                                              color: AppColors.textPrimary(context),
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
                                        style: GoogleFonts.inter(
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
                      // Password
                      CustomTextField(
                        labelText: 'label_password'.tr,
                        hintText: 'hint_password'.tr,
                        controller: controller.passwordController,
                        obscureText: true,
                        showPasswordToggle: true,
                        textInputAction: TextInputAction.next,
                        validator: controller.validatePassword,
                      ),
                      SizedBox(height: 10.h),
                      InterText(text: 'password_requirement'.tr),
                      SizedBox(height: 20.h),
                      InterText(
                        text: 'label_language'.tr,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.grey700Color,
                      ),
                      SizedBox(height: 8.h),
                      GestureDetector(
                        onTap: () {
                          final currentCode =
                              LocalizationService.getCurrentLanguageCode();
                          final entries = LocalizationService
                              .languageLabels
                              .entries
                              .toList();

                          Get.defaultDialog(
                            title: 'language_dialog_title'.tr,
                            backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.surfaceDark : AppColors.whiteColor,
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: entries.map((entry) {
                                final isSelected = entry.key == currentCode;
                                return ListTile(
                                  title: InterText(
                                    text: entry.value,
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  trailing: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.green,
                                        )
                                      : null,
                                  onTap: () async {
                                    await LocalizationService.updateLocale(
                                      entry.key,
                                    );
                                    Get.back();
                                    CustomSnackbar.showSuccess(
                                      title: 'language_updated_title'.tr,
                                      message: 'language_updated_message'.tr,
                                    );
                                  },
                                );
                              }).toList(),
                            ),
                            textCancel: 'common_cancel'.tr,
                          );
                        },
                        child: Container(
                          height: 50.h,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.textSecondary(context).withOpacity(0.2)),
                            borderRadius: BorderRadius.circular(30.r),
                          ),
                          child: Builder(
                            builder: (context) {
                              final currentCode =
                                  LocalizationService.getCurrentLanguageCode();
                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  InterText(
                                    text:
                                        LocalizationService
                                            .languageLabels[currentCode] ??
                                        'English',
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.textPrimary(context),
                                  ),
                                  Icon(
                                    Icons.keyboard_arrow_down,
                                    color: AppColors.textPrimary(context),
                                    size: 20.sp,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),
                      Obx(
                        () => CityLocationPicker(
                          cityController: controller.cityController,
                          onGetLocation: () =>
                              controller.getCurrentLocationFromMaps(),
                          isGettingLocation: controller.isGettingLocation.value,
                          detectedCity: controller.userCity.value,
                        ),
                      ),

                      SizedBox(height: 20.h),
                      CustomTextField(
                        labelText: 'label_address'.tr,
                        hintText: 'hint_address'.tr,
                        controller: controller.addressController,
                        textInputAction: TextInputAction.next,
                        validator: controller.validateAddress,
                      ),

                      // Pet Sitter specific fields
                      if (userType == 'pet_sitter') ...[
                        SizedBox(height: 20.h),
                        CustomTextField(
                          labelText: 'PayPal Email (Optional)',
                          hintText: 'sitter-payments@example.com',
                          controller: controller.paypalEmailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: controller.validatePayPalEmail,
                        ),
                        SizedBox(height: 20.h),
                        CustomTextField(
                          labelText: 'label_rate_per_hour'.tr,
                          hintText: 'hint_rate_per_hour'.tr,
                          controller: controller.ratePerHourController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          validator: controller.validateRatePerHour,
                        ),
                        SizedBox(height: 20.h),
                        CustomTextField(
                          labelText: 'sitter_detail_weekly_rate_label'.tr,
                          hintText: 'hint_rate_per_hour'.tr,
                          controller: controller.ratePerWeekController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          validator: controller.validateRatePerWeek,
                        ),
                        SizedBox(height: 20.h),
                        CustomTextField(
                          labelText: 'sitter_detail_monthly_rate_label'.tr,
                          hintText: 'hint_rate_per_hour'.tr,
                          controller: controller.ratePerMonthController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          validator: controller.validateRatePerMonth,
                        ),
                        SizedBox(height: 20.h),
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
                            disabledDecoration:
                                CustomDropdownDisabledDecoration(
                                  border: Border.all(
                                    color: AppColors.grey300Color,
                                  ),
                                ),
                          ),
                        ),
                        SizedBox(height: 20.h),
                        CustomTextField(
                          labelText: 'label_skills'.tr,
                          hintText: 'hint_skills'.tr,
                          controller: controller.skillsController,
                          textInputAction: TextInputAction.done,
                          validator: controller.validateSkills,
                        ),
                      ],

                      SizedBox(height: 20.h),
                      // Sprint 7 step 3 — referral code (optional).
                      CustomTextField(
                        labelText: 'signup_referral_code_label'.tr,
                        hintText: 'XXXXXXXX',
                        controller: controller.referralCodeController,
                        textInputAction: TextInputAction.next,
                      ),

                      SizedBox(height: 24.h),
                      // Terms and Conditions
                      Obx(
                        () => Row(
                          children: [
                            SizedBox(
                              height: 20.h,
                              width: 20.w,
                              child: Checkbox(
                                value: controller.agreeToTerms.value,
                                onChanged: controller.toggleAgreeToTerms,
                                activeColor: AppColors.primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Wrap(
                                children: [
                                  InterText(
                                    text: 'label_terms_prefix'.tr,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary(context),
                                  ),
                                  GestureDetector(
                                    onTap: () {},
                                    child: InterText(
                                      text: 'label_terms_title'.tr,
                                      fontSize: 13,
                                      color: AppColors.primaryColor,
                                      fontWeight: FontWeight.w600,
                                      // textDecoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24.h),

                      // Social Sign In Options
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: AppColors.textSecondary(context).withOpacity(0.2),
                              thickness: 1,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            child: InterText(
                              text: 'or_sign_up_with'.tr,
                              fontSize: 12.sp,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: AppColors.textSecondary(context).withOpacity(0.2),
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24.h),

                      // Social Sign In Buttons (Apple only on iOS)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  authController.isLoading.value ||
                                      authController.isSocialLoginLoading.value
                                  ? null
                                  : () {
                                      // Map userType to API role format
                                      // 'pet_owner' -> 'owner', 'pet_sitter' -> 'sitter'
                                      final role = userType == 'pet_owner'
                                          ? 'owner'
                                          : 'sitter';
                                      authController.loginWithGoogle(
                                        role: role,
                                      );
                                    },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.textSecondary(context).withOpacity(0.2)),
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    AppImages.googleIcon,
                                    height: 20.sp,
                                    width: 20.sp,
                                    fit: BoxFit.cover,
                                  ),

                                  SizedBox(width: 8.w),
                                  InterText(
                                    text: 'button_google'.tr,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary(context),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (Platform.isIOS) ...[
                            SizedBox(width: 12.w),
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    authController.isLoading.value ||
                                        authController
                                            .isSocialLoginLoading
                                            .value
                                    ? null
                                    : () {
                                        final role = userType == 'pet_owner'
                                            ? 'owner'
                                            : 'sitter';
                                        Get.find<AuthController>()
                                            .loginWithApple(role: role);
                                      },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: AppColors.textSecondary(context).withOpacity(0.2),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 12.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.apple,
                                      size: 20.sp,
                                      color: AppColors.textPrimary(context),
                                    ),
                                    SizedBox(width: 8.w),
                                    InterText(
                                      text: 'button_apple'.tr,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary(context),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 24.h),

                      SizedBox(height: 45.h),
                      // Sign Up Button
                      Obx(
                        () => CustomButton(
                          title: controller.isLoading.value
                              ? 'button_creating_account'.tr
                              : 'button_create_account'.tr,
                          onTap: controller.isLoading.value
                              ? null
                              : () => controller.handleSignUpWithNavigation(
                                  email: controller.emailController.text.trim(),
                                ),
                        ),
                      ),
                      SizedBox(height: 60.h),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Obx(
            () => authController.isSocialLoginLoading.value
                ? Positioned.fill(
                    child: Container(
                      color: AppColors.blackColor.withOpacity(0.3),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
