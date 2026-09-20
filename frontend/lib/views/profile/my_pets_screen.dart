// v573 — lot 3 : « Mes animaux » entièrement modernisée (demande Daniel,
// capture à l'appui : fond uni, carte plate, bouton « Ajouter » en pastille
// pâle). DESIGN UNIQUEMENT — `MyPetsController`, la navigation vers la fiche
// animal / `EditPetScreen` et la suppression sont inchangés.
//
// Ce qui change :
//   · fond à petites pattes (`PawPatternBackground`) à la couleur du rôle ;
//   · grand titre + sous-titre compteur (« 1 animal » / « {n} animaux ») ;
//   · carte animal plus riche : photo arrondie 96, nom Poppins gras, race,
//     pastilles méta (âge / poids / taille) du kit Réservations, pastilles
//     espèce / sexe, badge vaccination lisible en sombre, appui animé ;
//   · chargement en squelettes de cartes (plus de spinner nu) ;
//   · « Ajouter un animal » = vrai bouton `CustomButton` collé en bas
//     (au-dessus de `appBottomInset`) + petit bouton rond « + » dans la barre ;
//   · état vide accueillant, état d'erreur du kit Profil, tirer pour
//     rafraîchir conservé ;
//   · dialogue de suppression = `showAppConfirmDialog` (plus d'`AlertDialog`).
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/my_pets_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/models/pet_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/utils/pet_age_format.dart';
import 'package:hopetsit/utils/pet_species_color.dart';
import 'package:hopetsit/views/booking/widgets/booking_ui_kit.dart';
import 'package:hopetsit/views/pet_owner/pet_profile/pet_profile_screen.dart';
import 'package:hopetsit/widgets/app_dialog_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/views/profile/edit_pet_screen.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/repositories/pet_repository.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

/// Vert « vacciné » de la marque (éclairci en sombre par `accentOn`).
const Color _kVaccineGreen = Color(0xFF16A34A);

class MyPetsScreen extends StatelessWidget {
  const MyPetsScreen({super.key});

  /// « Mes animaux » est une page propriétaire : accent orange de la marque.
  Color get _accent => AppColors.primaryColor;

  Future<void> _openCreate() async {
    // v428 — système unifié : « Ajouter un animal » ouvre l'écran « Modifier
    // l'animal » en mode CRÉATION (sans petId).
    final result = await Get.to(() => const EditPetScreen());
    if (result == true && Get.isRegistered<MyPetsController>()) {
      await Get.find<MyPetsController>().refreshPets();
    }
  }

  @override
  Widget build(BuildContext context) {
    final MyPetsController controller = Get.put(MyPetsController());

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: _accent),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 20.sp, color: _accent),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          // Petit bouton rond « + » : raccourci toujours visible, même quand
          // la liste est longue et que le bouton du bas est hors écran.
          Padding(
            padding: EdgeInsets.only(right: 14.w),
            child: Semantics(
              button: true,
              label: 'my_pets_add_pet'.tr,
              child: InkWell(
                key: const ValueKey<String>('my_pets_add_round'),
                onTap: _openCreate,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 38.w,
                  height: 38.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accentOn(context, _accent)
                        .withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add_rounded,
                      size: 21.sp, color: AppColors.accentOn(context, _accent)),
                ),
              ),
            ),
          ),
        ],
      ),
      body: PawPatternBackground(
        color: _accent,
        child: SafeArea(
          top: false,
          child: Obx(() {
            final bool loading = controller.isLoading.value;
            final bool failed = controller.errorMessage.value.isNotEmpty &&
                controller.pets.isEmpty;
            final List<PetModel> pets = controller.pets.toList();

            Widget body;
            if (loading && pets.isEmpty) {
              body = _skeletonList(context);
            } else if (failed) {
              // v565 — point 39 : état d'erreur du kit + « Réessayer ».
              body = ProfileEmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'my_pets_error_loading'.tr,
                message: controller.errorMessage.value,
                accent: _accent,
                error: true,
                actionLabel: 'my_pets_retry'.tr,
                onAction: () => controller.refreshPets(),
              );
            } else if (pets.isEmpty) {
              body = _emptyState(context);
            } else {
              body = RefreshIndicator(
                onRefresh: () => controller.refreshPets(),
                color: _accent,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
                  itemCount: pets.length,
                  itemBuilder: (ctx, index) =>
                      _PetCard(pet: pets[index], onDelete: _confirmAndDeletePet),
                ),
              );
            }

            return Column(
              children: [
                _header(context, loading ? -1 : pets.length),
                Expanded(child: body),
                if (pets.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        16.w, 8.h, 16.w, 12.h + appBottomInset(context)),
                    child: CustomButton(
                      key: const ValueKey<String>('my_pets_add_bottom'),
                      height: 52.h,
                      radius: 16.r,
                      bgColor: _accent,
                      onTap: _openCreate,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded,
                              size: 20.sp, color: Colors.white),
                          SizedBox(width: 8.w),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: InterText(
                                text: 'my_pets_add_pet'.tr,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // ── En-tête : grand titre + compteur ────────────────────────────────────
  /// [count] = -1 pendant le premier chargement (sous-titre masqué).
  Widget _header(BuildContext context, int count) {
    final String subtitle = count < 0
        ? ''
        : count == 0
            ? 'lot3_573_pets_none'.tr
            : count == 1
                ? 'lot3_573_pets_count_one'.tr
                : 'lot3_573_pets_count'.tr.replaceAll('{n}', '$count');
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          PoppinsText(
            text: 'my_pets_title'.tr,
            fontSize: 24.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle.isNotEmpty) ...[
            SizedBox(height: 2.h),
            InterText(
              text: subtitle,
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  // ── États ───────────────────────────────────────────────────────────────
  Widget _emptyState(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
      children: [
        SizedBox(height: 18.h),
        Center(
          child: Container(
            width: 104.w,
            height: 104.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.pets_rounded,
                size: 46.sp, color: AppColors.accentOn(context, _accent)),
          ),
        ),
        SizedBox(height: 18.h),
        PoppinsText(
          text: 'my_pets_empty'.tr,
          fontSize: 17.sp,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary(context),
          textAlign: TextAlign.center,
          maxLines: 3,
        ),
        SizedBox(height: 8.h),
        InterText(
          text: 'my_pets_empty_body'.tr,
          fontSize: 13.5.sp,
          height: 1.45,
          color: AppColors.textSecondary(context),
          textAlign: TextAlign.center,
          maxLines: 6,
        ),
        SizedBox(height: 22.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          child: CustomButton(
            key: const ValueKey<String>('my_pets_add_first'),
            height: 52.h,
            radius: 16.r,
            bgColor: _accent,
            title: 'lot3_573_pets_add_first'.tr,
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            onTap: _openCreate,
          ),
        ),
      ],
    );
  }

  Widget _skeletonList(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
      itemCount: 3,
      itemBuilder: (ctx, _) => const _PetCardSkeleton(),
    );
  }
}

// ── Carte animal ──────────────────────────────────────────────────────────

/// Carte d'un animal : photo, nom, race, pastilles méta, espèce / sexe,
/// badge vaccination. Appui animé (léger enfoncement).
class _PetCard extends StatefulWidget {
  const _PetCard({required this.pet, required this.onDelete});

  final PetModel pet;
  final Future<void> Function(BuildContext context, String petId) onDelete;

  @override
  State<_PetCard> createState() => _PetCardState();
}

class _PetCardState extends State<_PetCard> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v && mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final PetModel pet = widget.pet;
    final String? imageUrl = pet.avatar.url.isNotEmpty ? pet.avatar.url : null;
    // v428 — accent par espèce (chien = orange, chat = bleu, …) : couleur
    // stable et signifiante par animal.
    final Color accent = petSpeciesColor(pet.category);
    final Color accentText = AppColors.accentOn(context, accent);
    final bool isUpToDate = pet.vaccinationStatus == 'up_to_date';

    return AnimatedScale(
      scale: _pressed ? 0.982 : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        onTap: () => Get.to(() => PetProfileScreen(
              pet: pet,
              accent: accent,
              onDelete: () => widget.onDelete(context, pet.id),
            )),
        child: Container(
          margin: EdgeInsets.only(bottom: 12.h),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: AppColors.cardShadow(context),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _photo(context, imageUrl, accent, accentText),
              SizedBox(width: 12.w),
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
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isUpToDate) ...[
                          SizedBox(width: 6.w),
                          _vaccineBadge(context),
                        ],
                        Icon(Icons.chevron_right_rounded,
                            color: AppColors.textSecondary(context), size: 20.sp),
                      ],
                    ),
                    if (pet.breed.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      InterText(
                        text: pet.breed,
                        fontSize: 12.5.sp,
                        color: AppColors.textSecondary(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    SizedBox(height: 8.h),
                    // Pastilles méta du kit Réservations (icône + valeur).
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 6.h,
                      children: [
                        if (petAgeDisplay(pet.age).isNotEmpty)
                          BookingMetaChip(
                            icon: Icons.cake_rounded,
                            value: petAgeDisplay(pet.age),
                            tint: accentText,
                          ),
                        if (pet.weight.isNotEmpty)
                          BookingMetaChip(
                            icon: Icons.monitor_weight_outlined,
                            value: '${pet.weight} kg',
                            tint: accentText,
                          ),
                        if (pet.height.isNotEmpty)
                          BookingMetaChip(
                            icon: Icons.height_rounded,
                            value: '${pet.height} cm',
                            tint: accentText,
                          ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 6.h,
                      children: [
                        _chip(
                          context,
                          '🐾 ${_localizedCategory(pet.category)}',
                          accentText.withValues(alpha: 0.14),
                          accentText,
                        ),
                        if (pet.gender == 'male')
                          _chip(
                            context,
                            '♂ ${'pet_gender_male'.tr}',
                            AppColors.inputFill(context),
                            AppColors.textSecondaryStrong(context),
                          ),
                        if (pet.gender == 'female')
                          _chip(
                            context,
                            '♀ ${'pet_gender_female'.tr}',
                            AppColors.inputFill(context),
                            AppColors.textSecondaryStrong(context),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photo(
      BuildContext context, String? imageUrl, Color accent, Color accentText) {
    final Widget fallback = Container(
      color: accent.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Icon(Icons.pets_rounded, color: accentText, size: 30.sp),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(18.r),
      child: SizedBox(
        width: 96.w,
        height: 96.w,
        child: imageUrl == null
            ? fallback
            : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                // 96 dp × densité : 320 px suffit et évite de décoder du 4K.
                memCacheWidth: 320,
                // Aplat thémé pendant le chargement (jamais de carré blanc
                // sur une carte sombre).
                placeholder: (c, _) => Container(
                  color: AppColors.mediaPlaceholder(
                      context, AppColors.lightGreyColor),
                ),
                errorWidget: (c, _, __) => fallback,
              ),
      ),
    );
  }

  Widget _vaccineBadge(BuildContext context) {
    final Color c = AppColors.accentOn(context, _kVaccineGreen);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 12.sp, color: c),
          SizedBox(width: 4.w),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 92.w),
            child: InterText(
              text: 'pet_up_to_date'.tr,
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              color: c,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String text, Color bg, Color fg) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10.r)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 170.w),
        child: InterText(
          text: text,
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          color: fg,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Squelette de carte pendant le premier chargement.
class _PetCardSkeleton extends StatelessWidget {
  const _PetCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final Color bone = AppColors.divider(context).withValues(alpha: 0.6);
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: bone,
            borderRadius: BorderRadius.circular(6.r),
          ),
        );
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 96.w,
            height: 96.w,
            decoration: BoxDecoration(
              color: bone,
              borderRadius: BorderRadius.circular(18.r),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                bar(120.w, 15.h),
                SizedBox(height: 8.h),
                bar(80.w, 11.h),
                SizedBox(height: 14.h),
                Row(children: [
                  bar(58.w, 22.h),
                  SizedBox(width: 6.w),
                  bar(58.w, 22.h),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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

// v23.1 — Delete pet confirmation + API call.
// v573 — dialogue maison (`app_dialog_kit`) au lieu de l'`AlertDialog` brut.
Future<void> _confirmAndDeletePet(BuildContext context, String petId) async {
  final confirmed = await showAppConfirmDialog(
    context,
    title: 'pet_delete_dialog_title'.tr,
    message: 'pet_delete_dialog_message'.tr,
    confirmLabel: 'common_delete'.tr,
    cancelLabel: 'common_cancel'.tr,
    destructive: true,
    icon: Icons.delete_outline_rounded,
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
