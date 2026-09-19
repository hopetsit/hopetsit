import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/edit_owner_profile_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/date_slash_formatter.dart';
import 'package:hopetsit/widgets/city_location_picker.dart';
import 'package:hopetsit/views/profile/widgets/profile_field_widgets.dart';
import 'package:hopetsit/views/profile/widgets/email_change_field.dart';
import 'package:hopetsit/views/profile/widgets/appearance_language_section.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/views/profile/widgets/edit_profile_widgets.dart';
import 'package:hopetsit/utils/bottom_inset.dart';

class EditOwnerProfileScreen extends StatelessWidget {
  const EditOwnerProfileScreen({super.key});

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
    final controller = Get.put(EditOwnerProfileController());
    const accent = AppColors.primaryColor;

    // v565 — point 39 : corps modernisé (kit Profil) : photo, cartes groupées
    // Identité / Contact / Adresse / À propos / Recherche / Application,
    // bouton « Enregistrer » collant en bas, états chargement / erreur.
    return ProfileSubPageScaffold(
      title: 'edit_profile_title'.tr,
      accent: accent,
      scroll: false,
      padding: EdgeInsets.zero,
      body: Obx(() {
        if (controller.isFetching.value) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          );
        }
        if (controller.loadError.value.isNotEmpty) {
          return ProfileEmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'edit_profile_load_error_title'.tr,
            message: controller.loadError.value,
            accent: accent,
            error: true,
            actionLabel: 'common_retry'.tr,
            onAction: () => controller.loadProfileData(),
          );
        }

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
                child: Form(
                  key: controller.formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 8.h),
                      Center(
                        child: Obx(() => EditProfileAvatar(
                              imageFile: controller.profileImage.value,
                              imageUrl: controller.currentAvatarUrl.value,
                              uploading: controller.isUploadingImage.value,
                              accent: accent,
                              hint: 'edit_profile_photo_hint'.tr,
                              onTap: () => controller.pickProfileImage(context),
                            )),
                      ),

                      // ── Identité ──
                      ProfileFormCard(
                        title: 'edit_profile_section_identity'.tr,
                        icon: Icons.badge_outlined,
                        accent: accent,
                        children: [
                          ProfileInput(
                            label: 'label_name'.tr,
                            hint: 'hint_name'.tr,
                            controller: controller.nameController,
                            accent: accent,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'error_name_required'.tr;
                              }
                              return null;
                            },
                          ),
                          // v426 — Date de naissance (collectée à l'inscription).
                          // v527 — slashs auto pendant la saisie.
                          ProfileInput(
                            label: 'signup_field_dob'.tr,
                            hint: 'date_hint_dmy'.tr,
                            controller: controller.dobController,
                            accent: accent,
                            keyboardType: TextInputType.datetime,
                            inputFormatters: [DateSlashFormatter()],
                            textInputAction: TextInputAction.next,
                            prefix: Icon(Icons.cake_outlined, size: 20.sp, color: accent),
                          ),
                        ],
                      ),

                      // ── Contact ──
                      ProfileFormCard(
                        title: 'edit_profile_section_contact'.tr,
                        icon: Icons.alternate_email_rounded,
                        accent: accent,
                        children: [
                          // v565 — point 2 : e-mail modifiable via la feuille
                          // « Changer mon e-mail » (code envoyé à la nouvelle adresse).
                          EmailChangeField(
                            controller: controller.emailController,
                            accent: accent,
                          ),
                          // v565 — point 25 : téléphone facultatif ici (demandé
                          // au moment utile via ensureContactInfo).
                          ProfilePhoneField(
                            controller: controller.phoneController,
                            countryCode: controller.selectedCountryCode,
                            accent: accent,
                          ),
                        ],
                      ),

                      // ── Adresse ──
                      ProfileFormCard(
                        title: 'edit_profile_section_location'.tr,
                        icon: Icons.place_outlined,
                        accent: accent,
                        children: [
                          ProfileInput(
                            label: 'label_address'.tr,
                            hint: 'hint_address'.tr,
                            controller: controller.addressController,
                            accent: accent,
                            textInputAction: TextInputAction.next,
                            maxLines: 2,
                          ),
                          // Ville / position (même comportement qu'à l'inscription).
                          Obx(
                            () => CityLocationPicker(
                              cityController: controller.locationController,
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
                        ],
                      ),

                      // ── À propos ──
                      ProfileFormCard(
                        title: 'edit_profile_section_about'.tr,
                        icon: Icons.person_outline_rounded,
                        accent: accent,
                        children: [
                          ProfileInput(
                            label: 'label_about_me'.tr,
                            hint: 'hint_bio'.tr,
                            controller: controller.bioController,
                            accent: accent,
                            textInputAction: TextInputAction.newline,
                            keyboardType: TextInputType.multiline,
                            maxLines: 4,
                          ),
                          ProfileInput(
                            label: 'label_language'.tr,
                            hint: 'hint_language'.tr,
                            controller: controller.languageController,
                            accent: accent,
                            textInputAction: TextInputAction.done,
                          ),
                        ],
                      ),

                      // ── Ce que vous recherchez (services + rayon) ──
                      // v426 — synchro inscription↔profil.
                      ProfileFormCard(
                        title: 'signup_step_search'.tr,
                        icon: Icons.search_rounded,
                        accent: accent,
                        children: [
                          Obx(() => ProfileChoiceChips(
                                accent: accent,
                                options: const [
                                  ['walk', 'signup_service_walk'],
                                  ['daycare', 'signup_service_daycare'],
                                  ['boarding', 'signup_service_boarding'],
                                  ['visit', 'signup_service_visit'],
                                ].map((e) => [e[0], e[1].tr]).toList(),
                                // v444 fix — .toList() LIT la RxList DANS l'Obx.
                                selected: controller.searchServices.toList(),
                                onToggle: (v) => _toggle(controller.searchServices, v),
                              )),
                          ProfileFieldLabel('signup_search_radius'.tr),
                          Obx(() => ProfileRadiusDropdown(
                                accent: accent,
                                value: controller.searchRadius.value,
                                onChanged: (v) => controller.searchRadius.value = v,
                              )),
                        ],
                      ),

                      // ── Application (apparence + langue) ──
                      ProfileFormCard(
                        title: 'edit_profile_section_app'.tr,
                        icon: Icons.phone_iphone_rounded,
                        accent: accent,
                        children: const [
                          AppearanceLanguageSection(accent: accent),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              // v569 — barre d'action collée en bas : le SafeArea de
              // ProfileSubPageScaffold n'applique rien sur le Samsung de
              // Daniel → le bouton passait sous la barre système.
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w,
                  12.h + appBottomInsetInsideSafeArea(context)),
              child: Obx(
                () => ProfileSaveBar(
                  label: controller.isLoading.value
                      ? 'edit_profile_button_updating'.tr
                      : 'edit_profile_button'.tr,
                  accent: accent,
                  loading: controller.isLoading.value,
                  icon: Icons.check_rounded,
                  onTap: controller.isLoading.value
                      ? null
                      : () => controller.handleUpdateProfileWithNavigation(),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
