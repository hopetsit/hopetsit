import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:hopetsit/controllers/edit_pet_controller.dart';
import 'package:hopetsit/models/pet_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_text_field.dart';
import 'package:hopetsit/widgets/pet_extra_fields.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart' show CustomButton;

/// v428 — écran UNIFIÉ « Modifier l'animal » (create + edit). Quand [petId] est
/// vide → mode CRÉATION (POST), titre « Ajouter un animal » + bouton « Créer le
/// profil ». Sinon → mode ÉDITION (PUT), titre « Modifier {nom} ».
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

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      EditPetController(petId: petId, petData: petData),
    );

    return Scaffold(
      // v449 — fond pâle teinté par RÔLE (au lieu du jaune v448).
      // AppColors.scaffold() gère déjà le rôle + le mode sombre.
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        leading: BackButton(),
        title: PoppinsText(
          text: _buildTitle(controller),
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: Obx(() {
        if (controller.isFetching.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return SafeArea(
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
                    Center(
                      child: Stack(
                        children: [
                          // v445 — Daniel : cliquer sur la PHOTO (pas seulement
                          // le petit stylo orange) permet aussi de la changer.
                          GestureDetector(
                            onTap: () => controller.pickPetProfileImage(),
                            child: Obx(() {
                            final imageFile = controller.petProfileImage.value;
                            final imageUrl = controller.currentAvatarUrl.value;

                            // v449 — avatar placeholder teinté par RÔLE (au lieu
                            // du jaune v444) : fond pâle + patte à l'accent du rôle.
                            final Color petPlaceholderBg =
                                AppColors.inputFillLightForRole();
                            final Color petPlaceholderIcon =
                                AppColors.activeRoleAccent();
                            if (imageFile != null) {
                              return ClipOval(
                                child: Container(
                                  width: 120.r,
                                  height: 120.r,
                                  color: petPlaceholderBg,
                                  child: Image.file(
                                    imageFile,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: petPlaceholderBg,
                                        child: Icon(
                                          Icons.pets,
                                          size: 40.sp,
                                          color: petPlaceholderIcon,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            }

                            if (imageUrl.isNotEmpty) {
                              return CircleAvatar(
                                radius: 60.r,
                                backgroundColor: petPlaceholderBg,
                                backgroundImage: CachedNetworkImageProvider(
                                  imageUrl,
                                ),
                                child: null,
                              );
                            }

                            return CircleAvatar(
                              radius: 60.r,
                              backgroundColor: petPlaceholderBg,
                              child: Icon(
                                Icons.pets,
                                size: 40.sp,
                                color: petPlaceholderIcon,
                              ),
                            );
                          })),
                          Positioned(
                            bottom: 0,
                            right: 2,
                            child: Obx(
                              () => GestureDetector(
                                onTap: controller.isUploadingImage.value
                                    ? null
                                    : () => controller.pickPetProfileImage(),
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
                          // Delete avatar button
                          Positioned(
                            top: 0,
                            right: 2,
                            child: Obx(() {
                              final hasLocal =
                                  controller.petProfileImage.value != null;
                              final hasRemote = controller
                                  .currentAvatarUrl
                                  .value
                                  .isNotEmpty;
                              if (!hasLocal && !hasRemote) {
                                return const SizedBox.shrink();
                              }
                              return GestureDetector(
                                onTap: controller.isUploadingImage.value
                                    ? null
                                    : () async {
                                        final confirmed =
                                            await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: Text(
                                              'pet_photo_delete_title'.tr,
                                            ),
                                            content: Text(
                                              'pet_photo_delete_confirm'.tr,
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(ctx).pop(false),
                                                child:
                                                    Text('common_cancel'.tr),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(ctx).pop(true),
                                                child: Text(
                                                  'post_action_delete'.tr,
                                                  style: TextStyle(
                                                    color:
                                                        AppColors.errorColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirmed == true) {
                                          if (hasLocal) {
                                            controller.petProfileImage.value =
                                                null;
                                          }
                                          if (hasRemote) {
                                            await controller.deletePetAvatar();
                                          }
                                        }
                                      },
                                child: Container(
                                  width: 28.w,
                                  height: 28.h,
                                  decoration: BoxDecoration(
                                    color: AppColors.errorColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 18.sp,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24.h),

                    // v444 — Daniel : « Ajouter un animal = garde QUE la photo,
                    // tout repart en sections dépliables (comme À propos) ».
                    // Les anciennes sections inline en texte brut (Apparence /
                    // Identité / Santé) sont SUPPRIMÉES : il n'y a plus qu'une
                    // suite cohérente d'ExpansionTile. « Informations
                    // principales » regroupe l'identité de base + les champs
                    // qui n'existent pas dans le nouveau bloc (couleur,
                    // passeport, n° de puce, médicaments, bio) pour ne RIEN
                    // perdre — tous restent envoyés au backend
                    // (cf. EditPetController.validateAndUpdateProfile).
                    Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: AppColors.grey300Color),
                      child: ExpansionTile(
                        title: Text(
                          'edit_pet_section_basics'.tr,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        initiallyExpanded: true,
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.symmetric(vertical: 8.h),
                        children: [
                          CustomTextField(
                            labelText: 'edit_pet_name_label'.tr,
                            hintText: 'edit_pet_name_hint'.tr,
                            controller: controller.petNameController,
                            textInputAction: TextInputAction.next,
                          ),
                          SizedBox(height: 16.h),
                          CustomTextField(
                            labelText: 'edit_pet_breed_label'.tr,
                            hintText: 'edit_pet_breed_hint'.tr,
                            controller: controller.breedController,
                            textInputAction: TextInputAction.next,
                          ),
                          SizedBox(height: 16.h),
                          // Catégorie (espèce) — déplacée ici depuis l'ancienne
                          // section Santé pour rester saisissable.
                          InterText(
                            text: 'create_pet_category_label'.tr,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.grey700Color,
                          ),
                          SizedBox(height: 8.h),
                          Obx(
                            () => CustomDropdown(
                              items: [
                                'create_pet_category_dog'.tr,
                                'create_pet_category_cat'.tr,
                                'create_pet_category_bird'.tr,
                                'create_pet_category_rabbit'.tr,
                                'create_pet_category_other'.tr,
                              ],
                              initialItem:
                                  controller.selectedCategory.value != null &&
                                          [
                                            'create_pet_category_dog'.tr,
                                            'create_pet_category_cat'.tr,
                                            'create_pet_category_bird'.tr,
                                            'create_pet_category_rabbit'.tr,
                                            'create_pet_category_other'.tr,
                                          ].contains(
                                              controller.selectedCategory.value)
                                      ? controller.selectedCategory.value
                                      : null,
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
                          ),
                          SizedBox(height: 16.h),
                          CustomTextField(
                            labelText: 'edit_pet_dob_label'.tr,
                            hintText: 'edit_pet_dob_hint'.tr,
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
                                controller.dateOfBirthController.text =
                                    picked.toString().split(' ')[0];
                              }
                            },
                          ),
                          SizedBox(height: 16.h),
                          Row(
                            children: [
                              Expanded(
                                child: CustomTextField(
                                  labelText: 'edit_pet_weight_label'.tr,
                                  hintText: 'edit_pet_weight_hint'.tr,
                                  controller: controller.weightController,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: CustomTextField(
                                  labelText: 'edit_pet_height_label'.tr,
                                  hintText: 'edit_pet_height_hint'.tr,
                                  controller: controller.heightController,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                  validator: (value) {
                                    final text = (value ?? '').trim();
                                    if (text.isEmpty) return null;
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
                          SizedBox(height: 16.h),
                          CustomTextField(
                            labelText: 'edit_pet_color_label'.tr,
                            hintText: 'edit_pet_color_hint'.tr,
                            controller: controller.colourController,
                            textInputAction: TextInputAction.next,
                          ),
                          SizedBox(height: 16.h),
                          CustomTextField(
                            labelText: 'edit_pet_passport_label'.tr,
                            hintText: 'edit_pet_passport_hint'.tr,
                            controller: controller.passportNumberController,
                            textInputAction: TextInputAction.next,
                          ),
                          SizedBox(height: 16.h),
                          CustomTextField(
                            labelText: 'edit_pet_chip_label'.tr,
                            hintText: 'edit_pet_chip_hint'.tr,
                            controller: controller.chipNumberController,
                            textInputAction: TextInputAction.next,
                          ),
                          SizedBox(height: 16.h),
                          CustomTextField(
                            labelText: 'edit_pet_medication_label'.tr,
                            hintText: 'edit_pet_medication_hint'.tr,
                            controller: controller.medicationAllergiesController,
                            textInputAction: TextInputAction.next,
                          ),
                          SizedBox(height: 16.h),
                          CustomTextField(
                            labelText: 'edit_pet_bio_label'.tr,
                            hintText: 'edit_pet_bio_hint'.tr,
                            controller: controller.bioController,
                            textInputAction: TextInputAction.next,
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 8.h),

                    // Sections enrichies (À propos / Santé / Habitudes /
                    // Documents) — le « nouveau bloc » demandé par Daniel.
                    PetExtraFields(
                      state: controller.enriched,
                      accent: AppColors.primaryColor,
                      showGender: true,
                    ),

                    SizedBox(height: 40.h),

                    Obx(
                      () => CustomButton(
                        title: controller.isLoading.value
                            ? 'edit_pet_updating_profile'.tr
                            : (_isCreate
                                ? 'pet_create_button'.tr
                                : 'edit_pet_update_profile_button'.tr),
                        onTap: controller.isLoading.value
                            ? null
                            : () => controller
                                .handleUpdateProfileWithNavigation(),
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
