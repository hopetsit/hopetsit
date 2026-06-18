import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/my_pets_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/models/pet_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/pet_age_format.dart';
import 'package:hopetsit/utils/pet_species_color.dart';
import 'package:hopetsit/views/pet_owner/pet_profile/pet_profile_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/views/profile/edit_pet_screen.dart';
import 'package:hopetsit/repositories/pet_repository.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

class MyPetsScreen extends StatelessWidget {
  const MyPetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final MyPetsController controller = Get.put(MyPetsController());

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
          text: 'my_pets_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: TextButton(
              onPressed: () async {
                // v428 — système unifié : « Ajouter un animal » ouvre l'écran
                // « Modifier l'animal » en mode CRÉATION (sans petId).
                final result = await Get.to(() => const EditPetScreen());
                if (result == true && Get.isRegistered<MyPetsController>()) {
                  await Get.find<MyPetsController>().refreshPets();
                }
              },
              child: PoppinsText(
                text: 'my_pets_add_pet'.tr,
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryColor,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.errorMessage.value.isNotEmpty &&
              controller.pets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PoppinsText(
                    text: 'my_pets_error_loading'.tr,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.errorColor,
                  ),
                  SizedBox(height: 8.h),
                  ElevatedButton(
                    onPressed: () => controller.refreshPets(),
                    child: Text('my_pets_retry'.tr),
                  ),
                ],
              ),
            );
          }

          if (controller.pets.isEmpty) {
            // v23.1.389 — état vide modernisé : icône + CTA direct.
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(22.w),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Text('🐾', style: TextStyle(fontSize: 44.sp)),
                  ),
                  SizedBox(height: 14.h),
                  PoppinsText(
                    text: 'my_pets_empty'.tr,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.greyColor,
                  ),
                  SizedBox(height: 16.h),
                  ElevatedButton.icon(
                    onPressed: () async {
                      // v428 — système unifié : création via EditPetScreen.
                      final result =
                          await Get.to(() => const EditPetScreen());
                      if (result == true &&
                          Get.isRegistered<MyPetsController>()) {
                        await Get.find<MyPetsController>().refreshPets();
                      }
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: Text('my_pets_add_pet'.tr),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => controller.refreshPets(),
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              itemCount: controller.pets.length,
              itemBuilder: (context, index) {
                final pet = controller.pets[index];
                return _buildPetCardV2(context, pet, index);
              },
            ),
          );
        }),
      ),
    );
  }

  /// v427 — maquette « Mes animaux » : carte propre (photo gauche + infos +
  /// badge À jour + métriques + puces espèce/sexe + chevron). Tap → fiche
  /// (4 onglets) où l'on peut Modifier / Supprimer.
  Widget _buildPetCardV2(BuildContext context, PetModel pet, int index) {
    final imageUrl = pet.avatar.url.isNotEmpty ? pet.avatar.url : null;
    // v428 — accent par espèce (chien=orange, chat=bleu, …) au lieu de la
    // rotation d'index, pour une couleur stable et signifiante par animal.
    final accent = petSpeciesColor(pet.category);
    final isUpToDate = pet.vaccinationStatus == 'up_to_date';

    return GestureDetector(
      onTap: () => Get.to(() => PetProfileScreen(
            pet: pet,
            accent: accent,
            onDelete: () => _confirmAndDeletePet(context, pet.id),
          )),
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.6),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16.r),
              child: SizedBox(
                width: 88.w,
                height: 88.w,
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 300,
                        placeholder: (c, _) =>
                            Container(color: AppColors.lightGreyColor),
                        errorWidget: (c, _, __) => Container(
                          color: accent.withValues(alpha: 0.12),
                          child: Icon(Icons.pets, color: accent, size: 30.sp),
                        ),
                      )
                    : Container(
                        color: accent.withValues(alpha: 0.12),
                        child: Icon(Icons.pets, color: accent, size: 30.sp),
                      ),
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: PoppinsText(
                          text: pet.petName,
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isUpToDate) _aJourBadge(),
                    ],
                  ),
                  if (pet.breed.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    InterText(
                      text: pet.breed,
                      fontSize: 13.sp,
                      color: AppColors.greyText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  SizedBox(height: 8.h),
                  Wrap(
                    spacing: 14.w,
                    runSpacing: 4.h,
                    children: [
                      if (petAgeDisplay(pet.age).isNotEmpty)
                        _petMetric(context, Icons.calendar_today_rounded,
                            petAgeDisplay(pet.age), accent),
                      if (pet.weight.isNotEmpty)
                        _petMetric(context, Icons.monitor_weight_outlined,
                            '${pet.weight} kg', accent),
                      if (pet.height.isNotEmpty)
                        _petMetric(context, Icons.height_rounded,
                            '${pet.height} cm', accent),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 6.h,
                    children: [
                      _petChip('🐾 ${_localizedCategory(pet.category)}',
                          accent.withValues(alpha: 0.12), accent),
                      if (pet.gender == 'male')
                        _petChip('♂ ${'pet_gender_male'.tr}',
                            AppColors.inputFill(context), AppColors.greyText),
                      if (pet.gender == 'female')
                        _petChip('♀ ${'pet_gender_female'.tr}',
                            AppColors.inputFill(context), AppColors.greyText),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 6.w),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.greyColor, size: 22.sp),
          ],
        ),
      ),
    );
  }

  Widget _aJourBadge() => Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: const Color(0xFF16A34A).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded,
                size: 12.sp, color: const Color(0xFF16A34A)),
            SizedBox(width: 4.w),
            InterText(
              text: 'pet_up_to_date'.tr,
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF16A34A),
            ),
          ],
        ),
      );

  Widget _petMetric(
          BuildContext context, IconData icon, String text, Color accent) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.sp, color: accent),
          SizedBox(width: 4.w),
          InterText(
            text: text,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(context),
          ),
        ],
      );

  Widget _petChip(String text, Color bg, Color fg) => Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12.r)),
        child: InterText(
          text: text,
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      );

  // v19.1.5 — Localize user-entered category values. Some pets were created
  // with the category label in the user's previous locale (e.g. "Chien" when
  // they were in French). Map those known French/English values to the i18n
  // keys so the chip follows the current locale regardless of saved data.
  String _localizedCategory(String raw) {
    final lower = raw.trim().toLowerCase();
    // Match common free-text values to canonical keys.
    switch (lower) {
      case 'dog':
      case 'chien':
      case 'perro':
      case 'hund':
      case 'cane':
      case 'cão':
      case 'cao':
        return 'create_pet_category_dog'.tr;
      case 'cat':
      case 'chat':
      case 'gato':
      case 'katze':
      case 'gatto':
        return 'create_pet_category_cat'.tr;
      case 'bird':
      case 'oiseau':
      case 'pájaro':
      case 'pajaro':
      case 'vogel':
      case 'uccello':
      case 'pássaro':
      case 'passaro':
        return 'create_pet_category_bird'.tr;
      case 'rabbit':
      case 'lapin':
      case 'conejo':
      case 'kaninchen':
      case 'coniglio':
      case 'coelho':
        return 'create_pet_category_rabbit'.tr;
      case 'other':
      case 'autre':
      case 'otro':
      case 'andere':
      case 'altro':
      case 'outro':
        return 'create_pet_category_other'.tr;
      default:
        return raw; // keep as-is if not recognized
    }
  }
}


// v23.1 — Delete pet confirmation + API call.
Future<void> _confirmAndDeletePet(BuildContext context, String petId) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('pet_delete_dialog_title'.tr),
      content: Text('pet_delete_dialog_message'.tr),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('common_cancel'.tr),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('common_delete'.tr,
              style: const TextStyle(color: Color(0xFFE53935))),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    final repo = Get.isRegistered<PetRepository>()
        ? Get.find<PetRepository>()
        : PetRepository(Get.find<ApiClient>());
    await repo.deletePet(petId: petId);
    if (Get.isRegistered<MyPetsController>()) {
      await Get.find<MyPetsController>().refreshPets();
    }
    CustomSnackbar.showSuccess(
      title: 'common_success'.tr,
      message: 'pet_delete_success'.tr,
    );
  } catch (e) {
    String msg = e.toString();
    if (e is ApiException && e.details is Map) {
      final d = (e.details as Map)['details'];
      if (d is String && d.isNotEmpty) msg = d;
    }
    CustomSnackbar.showError(
      title: 'common_error'.tr,
      message: msg,
    );
  }
}
