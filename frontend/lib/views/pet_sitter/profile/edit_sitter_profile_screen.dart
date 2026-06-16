import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
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
import 'package:hopetsit/views/profile/widgets/profile_field_widgets.dart';
import 'package:hopetsit/views/profile/widgets/appearance_language_section.dart';
import 'package:hopetsit/utils/pet_species_color.dart';

class EditSitterProfileScreen extends StatelessWidget {
  const EditSitterProfileScreen({super.key});

  // v426 — toggle helper partagé par les chips multi-sélection.
  void _toggle(List<String> list, String value) {
    if (list.contains(value)) {
      list.remove(value);
    } else {
      list.add(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(EditSitterProfileController());

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

                    // v426 — Date de naissance (collectée à l'inscription).
                    CustomTextField(
                      labelText: 'signup_field_dob'.tr,
                      hintText: 'JJ/MM/AAAA',
                      controller: controller.dobController,
                      keyboardType: TextInputType.datetime,
                      textInputAction: TextInputAction.next,
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
                          color: AppColors.textPrimary(context),
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
                                    color: AppColors.inputFill(context),
                                    border: hasError
                                        ? Border.all(
                                            color: AppColors.errorColor,
                                            width: 1,
                                          )
                                        : null,
                                    borderRadius: BorderRadius.circular(30.r),
                                    boxShadow: AppColors.cardShadow(context).isEmpty
                                        ? []
                                        : [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.04),
                                              blurRadius: 10,
                                              offset: const Offset(0, 2),
                                            )
                                          ],
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
                                        // v23.1 part 252 — fallback locale
                                        // device si vide (sinon Pakistan).
                                        initialSelection: controller
                                                .selectedCountryCode
                                                .value
                                                .isNotEmpty
                                            ? controller
                                                .selectedCountryCode.value
                                            : (Get.deviceLocale?.countryCode ??
                                                'FR'),
                                        showCountryOnly: false,
                                        showOnlyCountryWhenClosed: false,
                                        alignLeft: false,
                                        boxDecoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            16.r,
                                          ),
                                          color: AppColors.inputFill(context),
                                        ),
                                        textStyle: TextStyle(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w400,
                                          color: AppColors.textPrimary(context),
                                        ),
                                        dialogTextStyle: TextStyle(
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
                                          textInputAction: TextInputAction.next,
                                          onChanged: (_) => field.didChange(
                                            controller.phoneController.text,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'hint_phone'.tr,
                                            hintStyle: TextStyle(
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w400,
                                              color: AppColors.textSecondary(context),
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

                    // Bio Field — label « À propos de moi » (champ bio conservé).
                    CustomTextField(
                      labelText: 'label_about_me'.tr,
                      hintText: 'hint_bio'.tr,
                      controller: controller.bioController,
                      textInputAction: TextInputAction.next,
                      maxLines: 4,
                    ),

                    SizedBox(height: 20.h),

                    // v444 — Daniel : champ « Compétences » (texte libre) RETIRÉ
                    // (doublon des puces « Expérience » ci-dessous ; rendait un
                    // grand cadre gris vide). skillsController reste alimenté.

                    // v20.0.19 — Toute la section "Tarifs" (hourly/daily/weekly/
                    // monthly + devise) a été déplacée vers l'écran dédié
                    // MyRatesScreen (tile "Mes tarifs" sur le profil sitter).
                    // Le doublon créait des conflits de save et écrasait les
                    // valeurs correctes (dailyRate notamment). Ne rien mettre
                    // ici — l'utilisateur tape sur "Mes tarifs" pour éditer.

                    // Language Field — multi-select chips
                    InterText(
                      text: 'label_language'.tr,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary(context),
                    ),
                    SizedBox(height: 8.h),
                    Obx(() {
                      final selected = controller.selectedLanguages;
                      const languages = [
                        'Français', 'English', 'Deutsch', 'Español',
                        'Italiano', 'Português', 'العربية', '中文',
                        '日本語', '한국어', 'Русский', 'Türkçe',
                        'Nederlands', 'Polski', 'हिन्दी',
                      ];
                      return Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: languages.map((lang) {
                          final isSelected = selected.contains(lang);
                          return GestureDetector(
                            onTap: () {
                              if (isSelected) {
                                selected.remove(lang);
                              } else {
                                selected.add(lang);
                              }
                              // Sync to controller text for API
                              controller.languageController.text = selected.join(', ');
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primaryColor : AppColors.inputFill(context),
                                borderRadius: BorderRadius.circular(20.r),
                                border: Border.all(
                                  color: isSelected ? AppColors.primaryColor : AppColors.divider(context),
                                ),
                              ),
                              child: InterText(
                                text: lang,
                                fontSize: 13.sp,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                color: isSelected ? Colors.white : AppColors.textPrimary(context),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    }),

                    SizedBox(height: 24.h),

                    // v426 — synchro inscription↔profil : services proposés,
                    // animaux acceptés, expérience, rayon (mêmes options que le
                    // wizard 5 étapes, style chips cohérent).
                    ProfileFieldLabel('signup_services_offered'.tr),
                    Obx(() => ProfileChoiceChips(
                          accent: AppColors.sitterAccent,
                          options: const [
                            ['sit_home', 'signup_sitsvc_at_mine'],
                            ['sit_owner', 'signup_sitsvc_at_owner'],
                            ['daycare', 'signup_sitsvc_daycare'],
                            ['meds', 'signup_sitsvc_meds'],
                            ['vet_transport', 'signup_sitsvc_vet_transport'],
                          ].map((e) => [e[0], e[1].tr]).toList(),
                          selected: controller.selectedServices,
                          onToggle: (v) => _toggle(controller.selectedServices, v),
                        )),

                    SizedBox(height: 20.h),

                    ProfileFieldLabel('signup_animals_accepted'.tr),
                    Obx(() => ProfileChoiceChips(
                          accent: AppColors.sitterAccent,
                          options: const [
                            ['dog', 'pet_animal_dog'],
                            ['cat', 'pet_animal_cat'],
                            ['rodent', 'pet_animal_rodent'],
                            ['bird', 'pet_animal_bird'],
                            ['reptile', 'pet_animal_reptile'],
                            ['nac', 'pet_animal_nac'],
                          ].map((e) => [e[0], e[1].tr]).toList(),
                          selected: controller.acceptedAnimals,
                          onToggle: (v) => _toggle(controller.acceptedAnimals, v),
                          emojiFor: petSpeciesEmoji,
                        )),

                    SizedBox(height: 20.h),

                    ProfileFieldLabel('signup_experience'.tr),
                    Obx(() => ProfileChoiceChips(
                          accent: AppColors.sitterAccent,
                          options: const [
                            ['passionate', 'signup_exp_passionate'],
                            ['owner', 'signup_exp_owner'],
                            ['ex_sitter', 'signup_exp_ex_sitter'],
                            ['training', 'signup_exp_training'],
                            ['educator', 'signup_exp_educator'],
                            ['vet_aux', 'signup_exp_vet_aux'],
                            ['shelter', 'signup_exp_shelter'],
                          ].map((e) => [e[0], e[1].tr]).toList(),
                          selected: controller.experienceTags,
                          onToggle: (v) => _toggle(controller.experienceTags, v),
                        )),

                    SizedBox(height: 20.h),

                    ProfileFieldLabel('signup_field_radius'.tr),
                    Obx(() => ProfileRadiusDropdown(
                          accent: AppColors.sitterAccent,
                          value: controller.coverageRadius.value,
                          onChanged: (v) => controller.coverageRadius.value = v,
                        )),

                    SizedBox(height: 24.h),

                    // v441 — Apparence (Clair/Sombre/Système) + Langue de l'app.
                    const AppearanceLanguageSection(
                      accent: AppColors.sitterAccent,
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
