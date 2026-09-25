import 'dart:io';

import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:hopetsit/views/profile/widgets/appearance_language_section.dart' show showAppLanguagePicker;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/sign_up_controller.dart';
import 'package:hopetsit/repositories/auth_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_text_field.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/widgets/city_location_picker.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';

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

    // v21 — Role-aware accent for the whole sign-up surface (submit button,
    // checkbox, terms link, loading spinner). Owner = orange (primary),
    // sitter = blue, walker = green. Keeps the form visually distinct from
    // the role selector screen without restructuring the layout.
    final Color roleColor = userType == 'pet_walker'
        ? AppColors.walkerAccent
        : userType == 'pet_sitter'
            ? AppColors.sitterAccent
            : AppColors.primaryColor;

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        automaticallyImplyLeading: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppColors.appBar(context),
        leading: BackButton(
          color: AppColors.textPrimary(context),
          onPressed: () => Get.back(),
        ),
        title: PoppinsText(
          text: userType == 'pet_owner'
              ? 'sign_up_as_pet_owner'.tr
              : userType == 'pet_walker'
                  ? 'sign_up_as_pet_walker'.tr
                  : 'sign_up_as_pet_sitter'.tr,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: PawPatternBackground(
          color: AppColors.activeRoleAccent(),
          child: Stack(
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
                      // v20 — Photo de profil + (optionnel) carte CB en haut de
                      // l'inscription. Le _SignupPhotoPicker encapsule l'état
                      // local (ImagePicker) sans toucher au SignUpController.
                      _SignupPhotoPicker(
                        controller: controller,
                        role: userType,
                      ),
                      SizedBox(height: 16.h),
                      // v20.0.6 — Banner expliquant que la CB se rajoute APRÈS
                      // l'inscription (pas pendant — on n'a pas encore de
                      // userId ni de Stripe Customer).
                      Builder(builder: (bCtx) {
                        // Audit mode sombre — bleu #1A73E8 sur voile bleu très
                        // pâle : ~3,5:1 sur fond sombre. Voile un peu plus
                        // dense + bleu éclairci. Clair : valeurs d'origine.
                        final bannerDark =
                            Theme.of(bCtx).brightness == Brightness.dark;
                        const blue = Color(0xFF1A73E8);
                        final blueFg =
                            bannerDark ? const Color(0xFF8AB4F8) : blue;
                        return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 13.h,
                        ),
                        decoration: BoxDecoration(
                          color: blue
                              .withValues(alpha: bannerDark ? 0.16 : 0.07),
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                            color: blue.withValues(alpha: 0.18),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 30.w,
                              height: 30.w,
                              decoration: BoxDecoration(
                                color: blue.withValues(
                                    alpha: bannerDark ? 0.20 : 0.12),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Icon(
                                Icons.credit_card_rounded,
                                color: blueFg,
                                size: 17.sp,
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: InterText(
                                text: 'signup_cb_later_hint'.tr,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: blueFg,
                                maxLines: 3,
                              ),
                            ),
                          ],
                        ),
                        );
                      }),
                      SizedBox(height: 24.h),
                      _sectionTitle(context, 'auth569_section_profile'.tr),
                      SizedBox(height: 14.h),
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
                      SizedBox(height: 24.h),
                      _sectionTitle(context, 'auth569_section_contact'.tr),
                      SizedBox(height: 14.h),
                      // Phone Number (Optional)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel(
                            context,
                            'label_mobile_number'.tr,
                            trailing: 'auth569_optional'.tr,
                          ),
                          SizedBox(height: 7.h),
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
                                    height: 52.h,
                                    decoration: _fieldBox(
                                      context,
                                      error: hasError,
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
                                        left: 4.w,
                                        top: 6.h,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.error_outline_rounded,
                                            size: 14.sp,
                                            color: AppColors.errorColor,
                                          ),
                                          SizedBox(width: 5.w),
                                          Expanded(
                                            child: Text(
                                              field.errorText!,
                                              style: GoogleFonts.inter(
                                                fontSize: 12.sp,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.errorColor,
                                                height: 1.35,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 24.h),
                      _sectionTitle(context, 'auth569_section_security'.tr),
                      SizedBox(height: 14.h),
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
                      SizedBox(height: 8.h),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 14.sp,
                            color: AppColors.textSecondary(context),
                          ),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: InterText(
                              text: 'password_requirement'.tr,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary(context),
                              maxLines: 3,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 22.h),
                      _fieldLabel(context, 'label_language'.tr),
                      SizedBox(height: 7.h),
                      GestureDetector(
                        onTap: () {
                          // Track the selected language inside the dialog so
                          // the green check mark follows the user's tap.
                          // Without StatefulBuilder, the original version
                          // captured `currentCode` once at open-time and the
                          // check stayed stuck on English even after picking
                          // another language.
                          // v585 (bug 17) — le sélecteur signature de
                          // l'app (traduit, langues écrites dans leur
                          // langue, jamais gris) au lieu de Get.defaultDialog.
                          showAppLanguagePicker(
                              context, AppColors.activeRoleAccent());
                        },
                        child: Container(
                          height: 52.h,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                          decoration: _fieldBox(context),
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
                      SizedBox(height: 24.h),
                      _sectionTitle(context, 'auth569_section_location'.tr),
                      SizedBox(height: 14.h),
                      Obx(
                        () => CityLocationPicker(
                          cityController: controller.cityController,
                          onGetLocation: () =>
                              controller.getCurrentLocationFromMaps(),
                          isGettingLocation: controller.isGettingLocation.value,
                          detectedCity: controller.userCity.value,
                          onLocationSelected: (city, lat, lng) {
                            controller.userCity.value = city;
                            controller.userLatitude.value = lat;
                            controller.userLongitude.value = lng;
                          },
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

                      // v20.0.6 — Currency dropdown for OWNER and WALKER too
                      // (not just sitter). Owner uses it for Premium / Boost
                      // / donation pricing. Walker uses it for rates + payout.
                      if (userType == 'pet_owner' ||
                          userType == 'pet_walker') ...[
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
                                color: AppColors.divider(context),
                              ),
                              closedBorderRadius: BorderRadius.circular(14.r),
                              headerStyle: GoogleFonts.inter(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w400,
                                // Audit mode sombre — noir en dur : la devise
                                // choisie devenait noir sur noir.
                                // `textPrimary()` = blackColor exact en clair.
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            disabledDecoration:
                                CustomDropdownDisabledDecoration(
                                  border: Border.all(
                                    color: AppColors.divider(context),
                                  ),
                                ),
                          ),
                        ),
                      ],

                      // v20.0.6 — Walker rates captured at signup (30 & 60 min).
                      // Previously walker had NO rate field at signup which
                      // confused users. Displayed right under the currency.
                      if (userType == 'pet_walker') ...[
                        SizedBox(height: 24.h),
                        _sectionTitle(context, 'auth569_section_rates'.tr),
                        SizedBox(height: 14.h),
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                labelText: 'walker_rate_30min_label'.tr,
                                hintText: '€10',
                                controller:
                                    controller.walkerRate30Controller,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: CustomTextField(
                                labelText: 'walker_rate_60min_label'.tr,
                                hintText: '€18',
                                controller:
                                    controller.walkerRate60Controller,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Pet Sitter specific fields
                      // v19.1.4 — PayPal field removed from signup (user can
                      // add it later from Payment Management). Currency
                      // dropdown moved ABOVE rates so user picks currency
                      // first, then fills the 3 rates.
                      if (userType == 'pet_sitter') ...[
                        SizedBox(height: 24.h),
                        _sectionTitle(context, 'auth569_section_rates'.tr),
                        SizedBox(height: 14.h),
                        // Currency selector — placed with the rates group so
                        // the user picks currency first, then fills the 3 rates.
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
                                color: AppColors.divider(context),
                              ),
                              closedBorderRadius: BorderRadius.circular(14.r),
                              headerStyle: GoogleFonts.inter(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w400,
                                // Audit mode sombre — noir en dur : la devise
                                // choisie devenait noir sur noir.
                                // `textPrimary()` = blackColor exact en clair.
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            disabledDecoration:
                                CustomDropdownDisabledDecoration(
                                  border: Border.all(
                                    color: AppColors.divider(context),
                                  ),
                                ),
                          ),
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
                        CustomTextField(
                          labelText: 'label_skills'.tr,
                          hintText: 'hint_skills'.tr,
                          controller: controller.skillsController,
                          textInputAction: TextInputAction.done,
                          validator: controller.validateSkills,
                        ),
                      ],

                      SizedBox(height: 24.h),
                      _sectionTitle(context, 'auth569_section_finish'.tr),
                      SizedBox(height: 14.h),
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
                                activeColor: roleColor,
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
                                    // v18.9.8 — lien vers CGU hébergées.
                                    // Avant : onTap vide (ne faisait rien).
                                    onTap: () async {
                                      final uri = Uri.parse(
                                          'https://hopetsit.com/terms');
                                      await launchUrl(uri,
                                          mode:
                                              LaunchMode.externalApplication);
                                    },
                                    child: InterText(
                                      text: 'label_terms_title'.tr,
                                      fontSize: 13,
                                      color: roleColor,
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
                              color: AppColors.textSecondary(context).withValues(alpha: 0.2),
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
                              color: AppColors.textSecondary(context).withValues(alpha: 0.2),
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24.h),

                      // Social Sign In Buttons (Apple only on iOS)
                      // v569 — pleine largeur, coins 14, empilés : les
                      // libellés complets (« Se connecter avec Apple ») ne
                      // débordent plus en allemand / polonais. Les handlers
                      // et le mapping de rôle sont inchangés.
                      _signupSocialButton(
                        context,
                        label: 'auth569_google_continue'.tr,
                        imagePath: AppImages.googleIcon,
                        onTap:
                            authController.isLoading.value ||
                                    authController.isSocialLoginLoading.value
                                ? null
                                : () {
                                    // Map userType to API role format.
                                    // 'pet_owner'  -> 'owner'
                                    // 'pet_sitter' -> 'sitter'
                                    // 'pet_walker' -> 'walker'
                                    final role = userType == 'pet_owner'
                                        ? 'owner'
                                        : userType == 'pet_walker'
                                            ? 'walker'
                                            : 'sitter';
                                    authController.loginWithGoogle(
                                      role: role,
                                    );
                                  },
                      ),
                      if (Platform.isIOS) ...[
                        SizedBox(height: 10.h),
                        _signupSocialButton(
                          context,
                          label: 'auth569_apple_continue'.tr,
                          icon: Icons.apple,
                          isApple: true,
                          onTap:
                              authController.isLoading.value ||
                                      authController
                                          .isSocialLoginLoading
                                          .value
                                  ? null
                                  : () {
                                      final role = userType == 'pet_owner'
                                          ? 'owner'
                                          : userType == 'pet_walker'
                                              ? 'walker'
                                              : 'sitter';
                                      Get.find<AuthController>()
                                          .loginWithApple(role: role);
                                    },
                        ),
                      ],

                      SizedBox(height: 32.h),
                      // Sign Up Button — v21 : role-coloured (orange owner /
                      // bleu sitter / vert walker) pour qu'on identifie d'un
                      // coup d'œil quel rôle est en cours d'inscription.
                      Obx(
                        () => CustomButton(
                          height: 54.h,
                          radius: 18.r,
                          title: controller.isLoading.value
                              ? 'button_creating_account'.tr
                              : 'button_create_account'.tr,
                          bgColor: roleColor,
                          onTap: controller.isLoading.value
                              ? null
                              : () => controller.handleSignUpWithNavigation(
                                  email: controller.emailController.text.trim(),
                                ),
                        ),
                      ),
                      // v569 — dégagement bas unique (Samsung edge-to-edge :
                      // viewPadding = 0 alors que la barre à 3 boutons
                      // recouvre). Le SafeArea entoure déjà le contenu.
                      SizedBox(
                        height: 36.h + appBottomInsetInsideSafeArea(context),
                      ),
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
                      color: AppColors.blackColor.withValues(alpha: 0.3),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            roleColor,
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
        ),
    );
  }
}


/// v569 — titre de section (« Ton profil », « Sécurité »…). Il découpe le
/// formulaire visuellement SANS changer l'ordre des champs ni la logique :
/// pastille de marque + libellé 13/800 + filet fin.
Widget _sectionTitle(BuildContext context, String text) {
  return Row(
    children: [
      Container(
        width: 4.w,
        height: 15.h,
        decoration: BoxDecoration(
          color: AppColors.primaryColor,
          borderRadius: BorderRadius.circular(2.r),
        ),
      ),
      SizedBox(width: 9.w),
      Flexible(
        child: InterText(
          text: text,
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary(context),
          letterSpacing: 0.2,
          maxLines: 2,
        ),
      ),
      SizedBox(width: 12.w),
      Expanded(
        child: Divider(
          color: AppColors.divider(context).withValues(alpha: 0.7),
          thickness: 1,
          height: 1,
        ),
      ),
    ],
  );
}

/// v569 — libellé de champ au même langage que `CustomTextField` (13/600),
/// avec une mention « Facultatif » discrète quand le champ n'est pas requis.
Widget _fieldLabel(BuildContext context, String text, {String? trailing}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Flexible(
        child: InterText(
          text: text,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary(context),
          letterSpacing: 0.1,
          maxLines: 2,
        ),
      ),
      if (trailing != null) ...[
        SizedBox(width: 8.w),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: AppColors.divider(context).withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(99.r),
          ),
          child: InterText(
            text: trailing,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary(context),
          ),
        ),
      ],
    ],
  );
}

/// v569 — cadre commun des champs « maison » (téléphone, sélecteur de langue)
/// pour qu'ils aient EXACTEMENT la surface, le rayon et la bordure de
/// `CustomTextField`.
BoxDecoration _fieldBox(BuildContext context, {bool error = false}) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: isDark ? AppColors.inputFill(context) : Colors.white,
    border: Border.all(
      color: error
          ? AppColors.errorColor
          : (isDark ? AppColors.dividerDark : const Color(0xFFECE2DF)),
      width: error ? 1.2 : 1,
    ),
    borderRadius: BorderRadius.circular(14.r),
  );
}

/// v569 — bouton social pleine largeur de l'inscription (même gabarit que
/// l'écran de connexion). Apple reste NOIR avec son logo officiel.
Widget _signupSocialButton(
  BuildContext context, {
  required String label,
  required VoidCallback? onTap,
  String? imagePath,
  IconData? icon,
  bool isApple = false,
}) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  final Color fg = isApple ? Colors.white : AppColors.textPrimary(context);
  return Opacity(
    opacity: onTap == null ? 0.5 : 1,
    child: Material(
      color: isApple
          ? const Color(0xFF191210)
          : (isDark ? AppColors.surfaceDark : Colors.white),
      borderRadius: BorderRadius.circular(14.r),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: fg.withValues(alpha: 0.10),
        highlightColor: fg.withValues(alpha: 0.05),
        child: Container(
          width: double.infinity,
          height: 52.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            border: isApple
                ? null
                : Border.all(
                    color: isDark
                        ? AppColors.dividerDark
                        : const Color(0xFFECE2DF),
                    width: 1.2,
                  ),
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (imagePath != null)
                    Image.asset(
                      imagePath,
                      height: 20.sp,
                      width: 20.sp,
                      fit: BoxFit.contain,
                    )
                  else if (icon != null)
                    Icon(icon, size: 21.sp, color: fg),
                  SizedBox(width: 10.w),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: InterText(
                        text: label,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: fg,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// v20 — Sélecteur photo de profil pour l'inscription (3 rôles).
/// Encapsule l'état local ImagePicker sans toucher au SignUpController.
/// L'image sélectionnée est stockée dans controller.profileImageFile pour
/// être uploadée via l'endpoint /users/me/profile-picture après création.
class _SignupPhotoPicker extends StatefulWidget {
  final dynamic controller;
  final String role;
  const _SignupPhotoPicker({required this.controller, required this.role});

  @override
  State<_SignupPhotoPicker> createState() => _SignupPhotoPickerState();
}

class _SignupPhotoPickerState extends State<_SignupPhotoPicker> {
  File? _file;

  Color get _accent => widget.role == 'pet_walker'
      ? const Color(0xFF16A34A)
      : widget.role == 'pet_sitter'
          ? const Color(0xFF2563EB)
          : AppColors.primaryColor;

  Future<void> _pick() async {
    final picker = ImagePicker();
    try {
      final x = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1024,
      );
      if (x != null) {
        setState(() => _file = File(x.path));
        // Expose to the SignUpController so handleSignUp can upload it after
        // the account is created (property added dynamically, safe fallback).
        try {
          (widget.controller as dynamic).profileImageFile = _file;
        } catch (_) {}
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // v20.0.6 — Photo circle very visibly role-colored: thick ring (4px) +
    // colored halo shadow + gradient background behind the placeholder icon.
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pick,
            child: Container(
              // Outer "halo" — soft colored shadow so the role tint is
              // immediately readable even before the image is picked.
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.32),
                    blurRadius: 16,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Container(
                    width: 110.w,
                    height: 110.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _file == null
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                _accent.withValues(alpha: 0.22),
                                _accent.withValues(alpha: 0.08),
                              ],
                            )
                          : null,
                      color: _file != null ? null : null,
                      border: Border.all(color: _accent, width: 4),
                      image: _file != null
                          ? DecorationImage(
                              image: FileImage(_file!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _file == null
                        ? Icon(Icons.person_rounded,
                            size: 54.sp, color: _accent)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: _accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: _accent.withValues(alpha: 0.45),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        _file != null ? Icons.edit : Icons.add_a_photo,
                        color: Colors.white,
                        size: 18.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            _file == null ? 'signup_photo_add'.tr : 'signup_photo_change'.tr,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: _accent,
            ),
          ),
        ],
      ),
    );
  }
}
