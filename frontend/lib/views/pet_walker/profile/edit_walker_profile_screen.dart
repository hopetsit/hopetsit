import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/edit_walker_profile_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/date_slash_formatter.dart';
import 'package:hopetsit/utils/pet_species_color.dart';
import 'package:hopetsit/widgets/city_location_picker.dart';
import 'package:hopetsit/views/profile/widgets/profile_field_widgets.dart';
import 'package:hopetsit/views/profile/widgets/email_change_field.dart';
import 'package:hopetsit/views/profile/widgets/appearance_language_section.dart';
import 'package:hopetsit/utils/profile_completion.dart' show ProfileFocusField;
import 'package:hopetsit/views/profile/widgets/profile_about_fields.dart';
import 'package:hopetsit/views/profile/widgets/profile_focus_anchors.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/views/profile/widgets/edit_profile_widgets.dart';
import 'package:hopetsit/utils/bottom_inset.dart';

class EditWalkerProfileScreen extends StatefulWidget {
  /// v575 — champ à mettre en évidence à l'ouverture (`ProfileFocusField.*`).
  /// Facultatif : `null` = comportement historique (haut de page).
  final String? focusField;

  const EditWalkerProfileScreen({super.key, this.focusField});

  @override
  State<EditWalkerProfileScreen> createState() => _EditWalkerProfileScreenState();
}

class _EditWalkerProfileScreenState extends State<EditWalkerProfileScreen> {
  final ProfileFocusAnchors _anchors = ProfileFocusAnchors();

  @override
  void initState() {
    super.initState();
    _anchors.reveal(widget.focusField);
  }

  @override
  void dispose() {
    _anchors.dispose();
    super.dispose();
  }

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
    final controller = Get.put(EditWalkerProfileController());
    const accent = AppColors.walkerAccent;

    // v565 — point 39 : corps modernisé (kit Profil) : photo, cartes groupées
    // Identité / Contact / Adresse / À propos / Services / Application,
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
                          // v575 — « dans mon profil j'ai que "nom" et
                          // pas "nom et prénom" » : deux champs distincts,
                          // Prénom puis Nom, identiques sur les 3 rôles.
                          // `name` reste la source d'affichage : le serveur le
                          // recalcule depuis ces deux champs.
                          Container(
                            key: _anchors.anchor(ProfileFocusField.name),
                            child: ProfileInput(
                              label: 'label_first_name'.tr,
                              hint: 'hint_first_name'.tr,
                              controller: controller.firstNameController,
                              accent: accent,
                              focusNode: _anchors.node(ProfileFocusField.name),
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'error_first_name_required'.tr;
                                }
                                return null;
                              },
                            ),
                          ),
                          // Le NOM n'est pas bloquant à l'édition : un compte
                          // historique peut n'avoir qu'un mot (« Madonna »), et
                          // refuser l'enregistrement empêcherait de modifier
                          // n'importe quel autre champ. La barre « profil
                          // complété » se charge de le réclamer.
                          ProfileInput(
                            label: 'label_last_name'.tr,
                            hint: 'hint_last_name'.tr,
                            controller: controller.lastNameController,
                            accent: accent,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                          ),
                          // v426 — Date de naissance ; v527 — slashs auto.
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
                            key: _anchors.anchor(ProfileFocusField.address),
                            label: 'label_address'.tr,
                            hint: 'hint_address'.tr,
                            controller: controller.addressController,
                            accent: accent,
                            textInputAction: TextInputAction.next,
                            maxLines: 2,
                          ),
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
                        ],
                      ),

                      // ── À propos ──
                      // v575 — bloc UNIFIÉ sur les 3 rôles : même carte, même
                      // ordre, mêmes widgets partagés. « À propos de moi »
                      // reste PROPRE au rôle (on ne se présente pas pareil en
                      // gardien et en propriétaire) ; « Langues parlées » est
                      // une information de la PERSONNE, partagée par les 3
                      // profils — et elle ne se confond plus avec « Langue de
                      // l'app », qui vit dans Préférences.
                      ProfileFormCard(
                        title: 'edit_profile_section_about'.tr,
                        icon: Icons.person_outline_rounded,
                        accent: accent,
                        children: [
                          Container(
                            key: _anchors.anchor(ProfileFocusField.bio),
                            child: ProfileAboutField(
                              controller: controller.bioController,
                              accent: accent,
                              focusNode: _anchors.node(ProfileFocusField.bio),
                            ),
                          ),
                          Container(
                            key: _anchors.anchor(ProfileFocusField.languages),
                            child: ProfileLanguageField(
                              selected: controller.selectedLanguages,
                              accent: accent,
                              onChanged: (joined) =>
                                  controller.languageController.text = joined,
                            ),
                          ),
                        ],
                      ),

                      // ── Services (synchro inscription↔profil, v426) ──
                      ProfileFormCard(
                        key: _anchors.anchor(ProfileFocusField.services),
                        title: 'edit_profile_section_services'.tr,
                        icon: Icons.pets_rounded,
                        accent: accent,
                        children: [
                          // v444 — Daniel : types de promenade (Walker.service).
                          ProfileFieldLabel('walker_service_label'.tr),
                          Obx(() => ProfileChoiceChips(
                                accent: accent,
                                options: const [
                                  ['individual', 'walker_svc_individual'],
                                  ['group', 'walker_svc_group'],
                                  ['long', 'walker_svc_long'],
                                  ['visit', 'walker_svc_visit'],
                                ].map((e) => [e[0], e[1].tr]).toList(),
                                selected: controller.selectedServices.toList(), // v444: read RxList in Obx
                                onToggle: (v) => _toggle(controller.selectedServices, v),
                              )),
                          // v576 — l'ancre « Animaux acceptés » MANQUAIT côté
                          // promeneur (elle existait chez le gardien) : la
                          // pastille de complétion ouvrait l'écran en haut de
                          // page, sans jamais montrer le choix demandé.
                          ProfileFieldLabel(
                            'signup_animals_walked'.tr,
                            key: _anchors.anchor(ProfileFocusField.animals),
                          ),
                          Obx(() => ProfileChoiceChips(
                                accent: accent,
                                options: const [
                                  ['dog', 'pet_animal_dog'],
                                  ['cat', 'pet_animal_cat'],
                                  ['small', 'pet_animal_small'],
                                  ['nac', 'pet_animal_nac'],
                                ].map((e) => [e[0], e[1].tr]).toList(),
                                selected: controller.acceptedAnimals.toList(),
                                onToggle: (v) => _toggle(controller.acceptedAnimals, v),
                                emojiFor: petSpeciesEmoji,
                              )),
                          ProfileFieldLabel('signup_experience'.tr),
                          Obx(() => ProfileChoiceChips(
                                accent: accent,
                                options: const [
                                  ['passionate', 'signup_exp_passionate'],
                                  ['owner', 'signup_exp_owner'],
                                  ['shelter', 'signup_exp_shelter'],
                                  ['training_dog', 'signup_exp_training_dog'],
                                  ['ex_pro_walker', 'signup_exp_ex_pro_walker'],
                                  ['educator_dog', 'signup_exp_educator_dog'],
                                ].map((e) => [e[0], e[1].tr]).toList(),
                                selected: controller.experienceTags.toList(),
                                onToggle: (v) => _toggle(controller.experienceTags, v),
                              )),
                          ProfileFieldLabel('signup_field_radius'.tr),
                          Obx(() => ProfileRadiusDropdown(
                                accent: accent,
                                value: controller.coverageRadius.value,
                                onChanged: (v) => controller.coverageRadius.value = v,
                              )),
                        ],
                      ),

                      // ── Préférences walker (v21.1.1 : le toggle pickup reste ici,
                      // les tarifs sont dans « Mes tarifs ») ──
                      ProfileFormCard(
                        title: 'edit_profile_section_preferences'.tr,
                        icon: Icons.tune_rounded,
                        accent: accent,
                        children: [
                          Obx(() => ProfileSwitchRow(
                                icon: Icons.home_work_outlined,
                                title: 'walker_pickup_at_owner'.tr,
                                value: controller.pickupAtOwner.value,
                                accent: accent,
                                onChanged: (v) => controller.pickupAtOwner.value = v,
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
