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
import 'package:hopetsit/widgets/rounded_text_button.dart' show CustomButton;

class EditPetScreen extends StatelessWidget {
  final String petId;
  final PetModel? petData;

  const EditPetScreen({super.key, required this.petId, this.petData});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      EditPetController(petId: petId, petData: petData),
    );

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
          text: 'edit_pet_profile_title'.tr,
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
                          Obx(() {
                            final imageFile = controller.petProfileImage.value;
                            final imageUrl = controller.currentAvatarUrl.value;

                            if (imageFile != null) {
                              return ClipOval(
                                child: Container(
                                  width: 120.r,
                                  height: 120.r,
                                  color: AppColors.grey300Color,
                                  child: Image.file(
                                    imageFile,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: AppColors.grey300Color,
                                        child: Icon(
                                          Icons.pets,
                                          size: 40.sp,
                                          color: AppColors.greyColor,
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
                                backgroundColor: AppColors.grey300Color,
                                backgroundImage: CachedNetworkImageProvider(
                                  imageUrl,
                                ),
                                child: null,
                              );
                            }

                            return CircleAvatar(
                              radius: 60.r,
                              backgroundColor: AppColors.grey300Color,
                              child: Icon(
                                Icons.pets,
                                size: 40.sp,
                                color: AppColors.greyColor,
                              ),
                            );
                          }),
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

                    SizedBox(height: 32.h),

                    CustomTextField(
                      labelText: 'edit_pet_name_label'.tr,
                      hintText: 'edit_pet_name_hint'.tr,
                      controller: controller.petNameController,
                      textInputAction: TextInputAction.next,
                    ),

                    SizedBox(height: 20.h),

                    CustomTextField(
                      labelText: 'edit_pet_breed_label'.tr,
                      hintText: 'edit_pet_breed_hint'.tr,
                      controller: controller.breedController,
                      textInputAction: TextInputAction.next,
                    ),

                    SizedBox(height: 20.h),

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

                    SizedBox(height: 20.h),

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

                    SizedBox(height: 20.h),

                    CustomTextField(
                      labelText: 'edit_pet_bio_label'.tr,
                      hintText: 'edit_pet_bio_hint'.tr,
                      controller: controller.bioController,
                      textInputAction: TextInputAction.next,
                      maxLines: 3,
                    ),

                    SizedBox(height: 20.h),

                    CustomTextField(
                      labelText: 'edit_pet_color_label'.tr,
                      hintText: 'edit_pet_color_hint'.tr,
                      controller: controller.colourController,
                      textInputAction: TextInputAction.next,
                    ),

                    SizedBox(height: 20.h),

                    CustomTextField(
                      labelText: 'edit_pet_passport_label'.tr,
                      hintText: 'edit_pet_passport_hint'.tr,
                      controller: controller.passportNumberController,
                      textInputAction: TextInputAction.next,
                    ),

                    SizedBox(height: 20.h),

                    CustomTextField(
                      labelText: 'edit_pet_chip_label'.tr,
                      hintText: 'edit_pet_chip_hint'.tr,
                      controller: controller.chipNumberController,
                      textInputAction: TextInputAction.next,
                    ),

                    SizedBox(height: 20.h),

                    CustomTextField(
                      labelText: 'edit_pet_medication_label'.tr,
                      hintText: 'edit_pet_medication_hint'.tr,
                      controller: controller.medicationAllergiesController,
                      textInputAction: TextInputAction.next,
                    ),

                    SizedBox(height: 20.h),

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
                        initialItem: controller.selectedCategory.value != null &&
                                [
                                  'create_pet_category_dog'.tr,
                                  'create_pet_category_cat'.tr,
                                  'create_pet_category_bird'.tr,
                                  'create_pet_category_rabbit'.tr,
                                  'create_pet_category_other'.tr,
                                ].contains(controller.selectedCategory.value)
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

                    SizedBox(height: 20.h),

                    InterText(
                      text: 'create_pet_vaccination_label'.tr,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.grey700Color,
                    ),
                    SizedBox(height: 8.h),
                    Obx(
                      () => CustomDropdown(
                        items: [
                          'create_pet_vaccination_up_to_date'.tr,
                          'create_pet_vaccination_not_vaccinated'.tr,
                          'create_pet_vaccination_partial'.tr,
                        ],
                        initialItem: controller.selectedVaccination.value !=
                                    null &&
                                [
                                  'create_pet_vaccination_up_to_date'.tr,
                                  'create_pet_vaccination_not_vaccinated'.tr,
                                  'create_pet_vaccination_partial'.tr,
                                ].contains(controller.selectedVaccination.value)
                            ? controller.selectedVaccination.value
                            : null,
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
                    ),

                    SizedBox(height: 16.h),

                    // Sprint 5 UI step 2 — enriched pet profile sections.
                    _buildEnrichedSections(controller),

                    SizedBox(height: 40.h),

                    Obx(
                      () => CustomButton(
                        title: controller.isLoading.value
                            ? 'edit_pet_updating_profile'.tr
                            : 'edit_pet_update_profile_button'.tr,
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

  Widget _buildEnrichedSections(EditPetController controller) {
    TextField tf(TextEditingController c, String label, {int maxLines = 1, TextInputType? kb}) {
      return TextField(
        controller: c,
        maxLines: maxLines,
        keyboardType: kb,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExpansionTile(
          title: Text('edit_pet_age_behavior'.tr),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          children: [
            tf(controller.ageController, 'edit_pet_age_years'.tr, kb: TextInputType.number),
            const SizedBox(height: 12),
            tf(controller.behaviorController, 'edit_pet_behavior_max'.tr, maxLines: 4),
          ],
        ),
        ExpansionTile(
          title: Text('edit_pet_vaccinations'.tr),
          children: [
            Obx(
              () => Column(
                children: [
                  for (int i = 0; i < controller.vaccinationsList.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(
                                text: controller.vaccinationsList[i]['name'] ?? '',
                              ),
                              onChanged: (v) =>
                                  controller.setVaccinationField(i, 'name', v),
                              decoration: InputDecoration(labelText: 'common_name'.tr),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(
                                text: controller.vaccinationsList[i]['date'] ?? '',
                              ),
                              onChanged: (v) =>
                                  controller.setVaccinationField(i, 'date', v),
                              decoration:
                                  const InputDecoration(labelText: 'YYYY-MM-DD'),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => controller.removeVaccination(i),
                          ),
                        ],
                      ),
                    ),
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text('edit_pet_add_vaccination'.tr),
                    onPressed: controller.addVaccination,
                  ),
                ],
              ),
            ),
          ],
        ),
        ExpansionTile(
          title: Text('edit_pet_regular_vet'.tr),
          children: [
            tf(controller.regularVetNameController, 'common_name'.tr),
            const SizedBox(height: 8),
            tf(controller.regularVetPhoneController, 'common_phone'.tr,
                kb: TextInputType.phone),
            const SizedBox(height: 8),
            tf(controller.regularVetAddressController, 'common_address'.tr),
          ],
        ),
        ExpansionTile(
          title: Text('edit_pet_emergency_vet'.tr),
          children: [
            tf(controller.emergencyVetNameController, 'common_name'.tr),
            const SizedBox(height: 8),
            tf(controller.emergencyVetPhoneController, 'common_phone'.tr,
                kb: TextInputType.phone),
            const SizedBox(height: 8),
            tf(controller.emergencyVetAddressController, 'common_address'.tr),
          ],
        ),
        ExpansionTile(
          title: Text('edit_pet_emergency_auth'.tr),
          children: [
            Obx(
              () => CheckboxListTile(
                value: controller.emergencyAuthAccepted.value,
                onChanged: (v) =>
                    controller.emergencyAuthAccepted.value = v ?? false,
                title: Text('edit_pet_emergency_auth_checkbox'.tr),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
            Obx(() => controller.emergencyAuthAccepted.value
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      EditPetController.emergencyLegalText,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  )
                : const SizedBox.shrink()),
          ],
        ),
      ],
    );
  }
}
