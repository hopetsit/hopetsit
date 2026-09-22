import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/edit_pet_controller.dart';
import 'package:hopetsit/controllers/enriched_pet_form_state.dart';
import 'package:hopetsit/models/pet_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/date_slash_formatter.dart' show ageInYears;
import 'package:hopetsit/utils/pet_species_color.dart';
import 'package:hopetsit/views/profile/widgets/edit_profile_widgets.dart';
import 'package:hopetsit/views/profile/widgets/pet_form_widgets.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/utils/bottom_inset.dart';

/// v428 — écran UNIFIÉ « Modifier l'animal » (create + edit). Quand [petId] est
/// vide → mode CRÉATION (POST), titre « Ajouter un animal » + bouton « Créer le
/// profil ». Sinon → mode ÉDITION (PUT), titre « Modifier {nom} ».
///
/// v565 — point 39 (retour Daniel sur la capture « Modifier l'animal Rex ») :
/// page rangée en cartes groupées claires, dans cet ordre — Photo · Identité ·
/// Santé · Caractère & habitudes · Bio · Documents. Plus aucune section
/// repliable : tout est visible, titres en petites capitales, champs
/// `ProfileInput` du kit (fond blanc, bord fin, libellé au-dessus), pilules
/// modernes (contour gris / plein orange + coche blanche, retour haptique),
/// sexe = deux pilules ♂ ♀, bouton « Enregistrer » collant en bas avec état de
/// chargement, validation lisible (champ manquant surligné + message).
/// TOUS les champs historiques restent envoyés au serveur
/// (cf. EditPetController.validateAndUpdateProfile + EnrichedPetFormState).
class EditPetScreen extends StatelessWidget {
  final String petId;
  final PetModel? petData;

  const EditPetScreen({super.key, this.petId = '', this.petData});

  bool get _isCreate => petId.trim().isEmpty;

  /// Titre dynamique : « Ajouter un animal » (création) ou « Modifier {nom} »
  /// (édition). Le nom vient de [petData] (passé en argument) ; fallback sur le
  /// titre générique si inconnu.
  String _buildTitle(EditPetController controller) {
    if (_isCreate) return 'pet_add_animal_title'.tr;
    final name = (petData?.petName ?? controller.petNameController.text).trim();
    // v445 — Daniel : « met Modifier l'animal » (pas « l'annonce »).
    return name.isNotEmpty
        ? '${'pet_edit_animal'.tr} $name'
        : 'edit_pet_profile_title'.tr;
  }

  // Espèces : tokens canoniques ↔ valeur du contrôleur ('Dog', 'Cat', …).
  // v565 — corrige le piège historique où le libellé TRADUIT (« Chien ») était
  // envoyé au serveur comme catégorie : on ne manipule plus que le token.
  static const List<MapEntry<String, String>> _species = [
    MapEntry('Dog', 'create_pet_category_dog'),
    MapEntry('Cat', 'create_pet_category_cat'),
    MapEntry('Bird', 'create_pet_category_bird'),
    MapEntry('Rabbit', 'create_pet_category_rabbit'),
    MapEntry('Other', 'create_pet_category_other'),
  ];

  String _speciesEmoji(String token) => petSpeciesEmoji(token.toLowerCase());

  Future<void> _confirmRemovePhoto(
      BuildContext context, EditPetController controller) async {
    final hasLocal = controller.petProfileImage.value != null;
    final hasRemote = controller.currentAvatarUrl.value.isNotEmpty;
    if (!hasLocal && !hasRemote) return;
    // v573 — patron moderne (cf. `widgets/custom_confirmation_dialog.dart`) :
    // carte coins 22, disque rouge, PoppinsText / InterText, boutons du kit.
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: dark ? 0.62 : 0.38),
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.card(ctx),
        insetPadding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 24.h),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.r)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 18.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56.w,
                height: 56.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.errorColor
                      .withValues(alpha: dark ? 0.22 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline_rounded,
                    size: 28.sp,
                    color: AppColors.accentOn(ctx, AppColors.errorColor)),
              ),
              SizedBox(height: 14.h),
              PoppinsText(
                text: 'pet_photo_delete_title'.tr,
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(ctx),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
              SizedBox(height: 8.h),
              InterText(
                text: 'pet_photo_delete_confirm'.tr,
                fontSize: 13.5.sp,
                height: 1.45,
                color: AppColors.textSecondary(ctx),
                textAlign: TextAlign.center,
                maxLines: 4,
              ),
              SizedBox(height: 20.h),
              CustomButton(
                height: 48.h,
                radius: 14.r,
                title: 'post_action_delete'.tr,
                fontSize: 15.sp,
                bgColor: AppColors.errorColor,
                textColor: Colors.white,
                onTap: () => Navigator.of(ctx).pop(true),
              ),
              SizedBox(height: 10.h),
              CustomButton(
                height: 48.h,
                radius: 14.r,
                title: 'common_cancel'.tr,
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                bgColor:
                    dark ? const Color(0xFF342420) : const Color(0xFFF6F1EF),
                textColor: AppColors.textPrimary(ctx),
                onTap: () => Navigator.of(ctx).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) {
      if (hasLocal) controller.petProfileImage.value = null;
      if (hasRemote) await controller.deletePetAvatar();
    }
  }

  Future<void> _pickDob(BuildContext context, EditPetController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      // v527 — retour Jose (R3-7) : JJ/MM/AAAA + âge (années révolues) prérempli.
      final dd = picked.day.toString().padLeft(2, '0');
      final mm = picked.month.toString().padLeft(2, '0');
      controller.dateOfBirthController.text = '$dd/$mm/${picked.year}';
      final years = ageInYears(picked);
      if (years >= 0) controller.ageController.text = years.toString();
    }
  }

  List<MapEntry<String, String>> _opts(List<List<String>> raw) =>
      raw.map((e) => MapEntry(e[0], e[1].tr)).toList();

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      EditPetController(petId: petId, petData: petData),
    );
    // Couleur du rôle (owner orange) — AppColors.scaffold() gère déjà le rôle
    // + le mode sombre.
    final accent = AppColors.activeRoleAccent();
    final enriched = controller.enriched;

    return ProfileSubPageScaffold(
      title: _buildTitle(controller),
      accent: accent,
      scroll: false,
      padding: EdgeInsets.zero,
      body: Obx(() {
        if (controller.isFetching.value) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          );
        }
        if (controller.loadError.value.isNotEmpty) {
          return ProfileEmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'edit_pet_load_error_title'.tr,
            message: controller.loadError.value,
            accent: accent,
            error: true,
            actionLabel: 'common_retry'.tr,
            onAction: () => controller.loadPetData(),
          );
        }

        // v573 — fond à petites pattes derrière le formulaire (comme les
        // accueils / réservations / fiche animal).
        return PawPatternBackground(
          color: accent,
          child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
                child: Form(
                  key: controller.formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── PHOTO ──
                      SizedBox(height: 8.h),
                      Center(
                        child: Obx(() => EditProfileAvatar(
                              imageFile: controller.petProfileImage.value,
                              imageUrl: controller.currentAvatarUrl.value,
                              uploading: controller.isUploadingImage.value,
                              accent: accent,
                              placeholderIcon: Icons.pets_rounded,
                              radius: 60,
                              hint: 'edit_pet_photo_hint'.tr,
                              // v445 — Daniel : cliquer sur la PHOTO permet
                              // aussi de la changer.
                              onTap: () => controller.pickPetProfileImage(),
                              onRemove: () => _confirmRemovePhoto(context, controller),
                            )),
                      ),

                      // ── IDENTITÉ ──
                      ProfileFormCard(
                        title: 'edit_pet_section_identity'.tr,
                        icon: Icons.badge_outlined,
                        accent: accent,
                        children: [
                          ProfileInput(
                            label: 'edit_pet_name_label'.tr,
                            hint: 'edit_pet_name_hint'.tr,
                            controller: controller.petNameController,
                            accent: accent,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'edit_pet_name_required'.tr
                                : null,
                          ),
                          // Espèce — pilules à tokens canoniques.
                          PetFieldLabel('create_pet_category_label'.tr),
                          Obx(() {
                            final current = controller.selectedCategory.value ?? '';
                            return Wrap(
                              spacing: 8.w,
                              runSpacing: 10.h,
                              children: _species
                                  .map((s) => PetPill(
                                        label: s.value.tr,
                                        selected: current.toLowerCase() ==
                                            s.key.toLowerCase(),
                                        accent: accent,
                                        emoji: _speciesEmoji(s.key),
                                        onTap: () => controller.setCategory(s.key),
                                      ))
                                  .toList(),
                            );
                          }),
                          ProfileInput(
                            label: 'edit_pet_breed_label'.tr,
                            hint: 'edit_pet_breed_hint'.tr,
                            controller: controller.breedController,
                            accent: accent,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                          ),
                          // Sexe — deux pilules ♂ ♀.
                          PetFieldLabel('pet_gender'.tr),
                          PetGenderPills(gender: enriched.gender, accent: accent),
                          // Date de naissance (tap → calendrier) + âge.
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: ProfileInput(
                                  label: 'edit_pet_dob_label'.tr,
                                  hint: 'edit_pet_dob_hint'.tr,
                                  controller: controller.dateOfBirthController,
                                  accent: accent,
                                  readOnly: true,
                                  onTap: () => _pickDob(context, controller),
                                  suffix: Icon(Icons.calendar_month_rounded,
                                      size: 20.sp, color: accent),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                flex: 2,
                                child: ProfileInput(
                                  // v471 — champ Âge (années) direct.
                                  label: 'edit_pet_age_years'.tr,
                                  hint: '0',
                                  controller: controller.ageController,
                                  accent: accent,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(2),
                                  ],
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                            ],
                          ),
                          // Poids + taille.
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ProfileInput(
                                  label: 'edit_pet_weight_label'.tr,
                                  hint: 'edit_pet_weight_hint'.tr,
                                  controller: controller.weightController,
                                  accent: accent,
                                  keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true),
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: ProfileInput(
                                  label: 'edit_pet_height_label'.tr,
                                  hint: 'edit_pet_height_hint'.tr,
                                  controller: controller.heightController,
                                  accent: accent,
                                  keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true),
                                  textInputAction: TextInputAction.next,
                                  validator: (value) {
                                    final text = (value ?? '').trim();
                                    if (text.isEmpty) return null;
                                    final cleaned = text
                                        .replaceAll(',', '.')
                                        .replaceAll(RegExp(r'[^\d.]'), '');
                                    final parsed = double.tryParse(cleaned);
                                    if (parsed == null || parsed <= 0) {
                                      return 'edit_pet_height_invalid'.tr;
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          ProfileInput(
                            label: 'edit_pet_color_label'.tr,
                            hint: 'edit_pet_color_hint'.tr,
                            controller: controller.colourController,
                            accent: accent,
                            textInputAction: TextInputAction.next,
                          ),
                        ],
                      ),

                      // ── SANTÉ ──
                      ProfileFormCard(
                        title: 'edit_pet_section_health'.tr,
                        icon: Icons.favorite_border_rounded,
                        accent: accent,
                        children: [
                          ProfileInput(
                            label: 'edit_pet_passport_label'.tr,
                            hint: 'edit_pet_passport_hint'.tr,
                            controller: controller.passportNumberController,
                            accent: accent,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.characters,
                          ),
                          ProfileInput(
                            label: 'edit_pet_chip_label'.tr,
                            hint: 'edit_pet_chip_hint'.tr,
                            controller: controller.chipNumberController,
                            accent: accent,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                          ),
                          PetFieldLabel('pet_vaccination_status'.tr),
                          PetSinglePills(
                            accent: accent,
                            value: enriched.vaccinationStatus,
                            options: _opts(const [
                              ['up_to_date', 'pet_vax_up_to_date'],
                              ['partial', 'pet_vax_partial'],
                              ['late', 'pet_vax_late'],
                              ['unknown', 'pet_vax_unknown'],
                            ]),
                          ),
                          ProfileInput(
                            label: 'edit_pet_medication_label'.tr,
                            hint: 'edit_pet_medication_hint'.tr,
                            controller: controller.medicationAllergiesController,
                            accent: accent,
                            textInputAction: TextInputAction.next,
                            maxLines: 2,
                          ),
                          PetToggleRow(
                            icon: Icons.content_cut_rounded,
                            label: 'pet_sterilized'.tr,
                            value: enriched.sterilized,
                            accent: accent,
                          ),
                          PetToggleRow(
                            icon: Icons.memory_rounded,
                            label: 'pet_microchipped'.tr,
                            value: enriched.microchipped,
                            accent: accent,
                          ),
                          // v444 — traitement en cours : Oui/Non + détail si Oui.
                          PetFieldLabel('pet_treatment_ongoing'.tr),
                          PetSinglePills(
                            accent: accent,
                            value: enriched.treatmentOngoing,
                            allowEmpty: false,
                            options: _opts(const [
                              ['yes', 'pet_yes'],
                              ['no', 'pet_no'],
                            ]),
                          ),
                          Obx(() => enriched.treatmentOngoing.value == 'yes'
                              ? ProfileInput(
                                  label: 'pet_current_treatments'.tr,
                                  controller: enriched.currentTreatmentsController,
                                  accent: accent,
                                  maxLines: 2,
                                  textInputAction: TextInputAction.next,
                                )
                              : const SizedBox.shrink()),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ProfileInput(
                                  label: 'pet_deworming_last_date'.tr,
                                  hint: 'date_hint_dmy'.tr,
                                  controller: enriched.dewormingLastDateController,
                                  accent: accent,
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: ProfileInput(
                                  label: 'pet_deworming_frequency'.tr,
                                  controller: enriched.dewormingFrequencyController,
                                  accent: accent,
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                            ],
                          ),
                          ProfileInput(
                            label: 'pet_food_restrictions'.tr,
                            controller: enriched.foodRestrictionsController,
                            accent: accent,
                            maxLines: 2,
                            textInputAction: TextInputAction.next,
                          ),
                          ProfileInput(
                            label: 'pet_blood_group'.tr,
                            controller: enriched.bloodGroupController,
                            accent: accent,
                            textInputAction: TextInputAction.next,
                          ),
                          PetFieldLabel('pet_health_insurance'.tr),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ProfileInput(
                                  label: 'pet_insurance_name'.tr,
                                  controller: enriched.insuranceNameController,
                                  accent: accent,
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: ProfileInput(
                                  label: 'pet_insurance_number'.tr,
                                  controller: enriched.insuranceNumberController,
                                  accent: accent,
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // ── CARACTÈRE & HABITUDES ──
                      ProfileFormCard(
                        title: 'edit_pet_section_character'.tr,
                        icon: Icons.auto_awesome_rounded,
                        accent: accent,
                        children: [
                          PetFieldLabel('pet_character_traits'.tr),
                          PetMultiPills(
                            accent: accent,
                            selected: enriched.characterTraits,
                            onToggle: enriched.toggleTrait,
                            options: EnrichedPetFormState.characterPresets
                                .map((t) => MapEntry(t, 'pet_trait_$t'.tr))
                                .toList(),
                          ),
                          PetFieldLabel('pet_habits_quick'.tr),
                          PetMultiPills(
                            accent: accent,
                            selected: enriched.habitTags,
                            onToggle: enriched.toggleHabit,
                            options: EnrichedPetFormState.habitPresets
                                .map((t) => MapEntry(t, 'pet_habit_$t'.tr))
                                .toList(),
                          ),
                          PetFieldLabel('pet_compatibilities'.tr),
                          _compatRow(context, 'pet_compat_children'.tr,
                              enriched.compatChildren, accent),
                          _compatRow(context, 'pet_compat_dogs'.tr,
                              enriched.compatDogs, accent),
                          _compatRow(context, 'pet_compat_cats'.tr,
                              enriched.compatCats, accent),
                          _compatRow(context, 'pet_compat_nac'.tr,
                              enriched.compatNac, accent),
                          PetFieldLabel('pet_energy_level'.tr),
                          PetSinglePills(
                            accent: accent,
                            value: enriched.energyLevel,
                            options: _opts(const [
                              ['low', 'pet_energy_low'],
                              ['medium', 'pet_energy_medium'],
                              ['high', 'pet_energy_high'],
                            ]),
                          ),
                          PetFieldLabel('pet_sleep'.tr),
                          PetSinglePills(
                            accent: accent,
                            value: enriched.sleep,
                            options: _opts(const [
                              ['indoor', 'pet_sleep_indoor'],
                              ['outdoor', 'pet_sleep_outdoor'],
                              ['crate', 'pet_sleep_crate'],
                            ]),
                          ),
                          PetFieldLabel('pet_housetrained'.tr),
                          PetSinglePills(
                            accent: accent,
                            value: enriched.housetrained,
                            options: _opts(const [
                              ['yes', 'pet_housetrained_yes'],
                              ['learning', 'pet_housetrained_learning'],
                            ]),
                          ),
                          PetFieldLabel('pet_leash'.tr),
                          PetSinglePills(
                            accent: accent,
                            value: enriched.leashBehaviour,
                            options: _opts(const [
                              ['off_leash', 'pet_leash_off'],
                              ['on_leash', 'pet_leash_on'],
                              ['reliable_recall', 'pet_leash_recall'],
                            ]),
                          ),
                        ],
                      ),

                      // ── DÉTAILS DU QUOTIDIEN (textes libres des habitudes) ──
                      ProfileFormCard(
                        title: 'edit_pet_section_details'.tr,
                        icon: Icons.notes_rounded,
                        accent: accent,
                        gap: 12,
                        children: [
                          _tf(enriched.fearsController, 'pet_fears'.tr, accent, maxLines: 2),
                          _tf(enriched.preferredActivityController, 'pet_preferred_activity'.tr, accent),
                          _tf(enriched.educationController, 'pet_education'.tr, accent),
                          _tf(enriched.aloneToleranceController, 'pet_alone_tolerance'.tr, accent),
                          _tf(enriched.barkingController, 'pet_barking'.tr, accent),
                          _tf(enriched.likesController, 'pet_likes'.tr, accent),
                          _tf(enriched.dislikesController, 'pet_dislikes'.tr, accent),
                          _tf(enriched.transportController, 'pet_transport'.tr, accent),
                          _tf(enriched.brushingController, 'pet_brushing'.tr, accent),
                          _tf(enriched.foodController, 'pet_food'.tr, accent),
                          _tf(enriched.allowedTreatsController, 'pet_allowed_treats'.tr, accent),
                          _tf(enriched.favoriteObjectsController, 'pet_favorite_objects'.tr, accent),
                          _tf(enriched.favoritePlacesController, 'pet_favorite_places'.tr, accent),
                          _tf(enriched.remarksController, 'pet_remarks'.tr, accent, maxLines: 2),
                        ],
                      ),

                      // ── BIO ──
                      ProfileFormCard(
                        title: 'edit_pet_section_bio'.tr,
                        icon: Icons.edit_note_rounded,
                        accent: accent,
                        children: [
                          ProfileInput(
                            label: 'edit_pet_bio_label'.tr,
                            hint: 'edit_pet_bio_hint'.tr,
                            controller: controller.bioController,
                            accent: accent,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            maxLines: 4,
                          ),
                          _tf(enriched.historyController, 'pet_history'.tr, accent, maxLines: 3),
                          PetFieldLabel('pet_particularities'.tr),
                          PetParticularityInput(state: enriched, accent: accent),
                          _tf(enriched.notesController, 'pet_notes'.tr, accent, maxLines: 3),
                        ],
                      ),

                      // ── DOCUMENTS (v443) ──
                      ProfileFormCard(
                        title: 'pet_documents'.tr,
                        icon: Icons.folder_outlined,
                        accent: accent,
                        children: [
                          PetFieldLabel('pet_documents_pick_hint'.tr),
                          PetMultiPills(
                            accent: accent,
                            selected: enriched.documentTypes,
                            onToggle: enriched.toggleDocument,
                            options: EnrichedPetFormState.documentPresets
                                .map((t) => MapEntry(t, 'pet_doc_$t'.tr))
                                .toList(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Bouton collant ──
            Padding(
              // v569 — le SafeArea de ProfileSubPageScaffold n'applique rien
              // sur le Samsung de Daniel : le bouton passait sous la barre.
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w,
                  12.h + appBottomInsetInsideSafeArea(context)),
              child: Obx(
                () => ProfileSaveBar(
                  label: controller.isLoading.value
                      ? 'edit_pet_updating_profile'.tr
                      : (_isCreate
                          ? 'pet_create_button'.tr
                          : 'edit_pet_update_profile_button'.tr),
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
          ),
        );
      }),
    );
  }

  Widget _tf(TextEditingController c, String label, Color accent,
          {int maxLines = 1}) =>
      ProfileInput(
        label: label,
        controller: c,
        accent: accent,
        maxLines: maxLines,
        textInputAction:
            maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
        keyboardType: maxLines > 1 ? TextInputType.multiline : null,
        textCapitalization: TextCapitalization.sentences,
      );

  Widget _compatRow(
      BuildContext context, String label, RxString value, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InterText(
          text: label,
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary(context),
          maxLines: 2,
        ),
        SizedBox(height: 6.h),
        PetSinglePills(
          accent: accent,
          value: value,
          options: _opts(const [
            ['compatible', 'pet_compat_yes'],
            ['supervised', 'pet_compat_supervised'],
            ['no', 'pet_compat_no'],
          ]),
        ),
      ],
    );
  }
}
