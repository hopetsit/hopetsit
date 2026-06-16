import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hopetsit/controllers/my_pets_controller.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/pet_model.dart';
import 'package:hopetsit/repositories/pet_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/pet_species_color.dart';
import 'package:hopetsit/views/pet_owner/pet_profile/pet_gallery_screen.dart';
import 'package:hopetsit/views/profile/edit_pet_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// v420 — refonte fiche animal À LA LETTRE (maquette « Profil de Helios ») :
/// design CLAIR (fond blanc), bannière photo + avatar superposé + crayon +
/// bouton « Changer la photo », nom + badge « ✓ À jour », race • âge, poids |
/// taille, puis 4 onglets (À propos / Santé / Habitudes / Galerie) sur fond
/// blanc avec indicateur à la couleur du rôle. `accent` = couleur de rôle.
class PetProfileScreen extends StatelessWidget {
  final PetModel pet;
  final Color? accent;
  final bool editable;

  /// v427 — callback Supprimer (maquette : menu ••• Modifier / Supprimer).
  /// Null ⇒ option Supprimer masquée.
  final VoidCallback? onDelete;

  const PetProfileScreen({
    super.key,
    required this.pet,
    this.accent,
    this.editable = true,
    this.onDelete,
  });

  // v428 — accent par espèce (chien=orange, chat=bleu, …) si non fourni.
  Color get _accent => accent ?? petSpeciesColor(pet.category);

  bool get _isUpToDate => pet.vaccinationStatus == 'up_to_date';

  String? get _bannerUrl {
    // 1re photo de la galerie en bannière, sinon l'avatar.
    for (final p in pet.photos) {
      if (p is Map && (p['url'] ?? '').toString().isNotEmpty) {
        return p['url'].toString();
      }
    }
    return pet.avatar.url.isNotEmpty ? pet.avatar.url : null;
  }

  void _openEdit() => Get.to(() => EditPetScreen(petId: pet.id, petData: pet));

  /// v428 — gestion des médias (photos/vidéos) déléguée à l'écran Galerie.
  /// (onglet Galerie → « Ajouter des photos »).
  void _openGallery() =>
      Get.to(() => PetGalleryScreen(pet: pet, accent: _accent));

  /// v433 — Daniel : « modifier la photo de profil ouvre la galerie ». Le
  /// crayon de l'avatar + « Changer la photo » ouvrent désormais le sélecteur
  /// de PHOTO DE PROFIL dédié (pick → upload comme avatar), PAS la galerie.
  Future<void> _changeProfilePhoto() async {
    try {
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image == null) return;
      final repo = Get.find<PetRepository>();
      await repo.uploadPetMedia(petId: pet.id, imageFile: File(image.path));
      if (Get.isRegistered<MyPetsController>()) {
        await Get.find<MyPetsController>().refreshPets();
      }
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'snackbar_text_image_uploaded_successfully',
      );
      // La fiche est en lecture (StatelessWidget) → on revient à la liste
      // rafraîchie qui affiche la nouvelle photo de profil.
      Get.back();
    } on ApiException catch (e) {
      CustomSnackbar.showError(title: 'common_error'.tr, message: e.message);
    } catch (_) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'common_error_generic'.tr,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.scaffold(context),
        appBar: AppBar(
          backgroundColor: AppColors.appBar(context),
          elevation: 0,
          scrolledUnderElevation: 0.5,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          title: InterText(
            text: 'pet_profile_title'.trParams({'name': pet.petName}),
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
          actions: [
            if (editable)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz_rounded,
                    color: _accent, size: 24.sp),
                onSelected: (v) {
                  if (v == 'edit') {
                    _openEdit();
                  } else if (v == 'delete') {
                    onDelete?.call();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18.sp, color: _accent),
                        SizedBox(width: 10.w),
                        Text('post_action_edit'.tr),
                      ],
                    ),
                  ),
                  if (onDelete != null)
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 18.sp, color: const Color(0xFFE53935)),
                          SizedBox(width: 10.w),
                          Text('post_action_delete'.tr),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
        body: Column(
          children: [
            _header(context),
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              indicatorColor: _accent,
              labelColor: _accent,
              unselectedLabelColor: AppColors.greyText,
              labelStyle: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
              tabs: [
                Tab(text: 'pet_tab_about'.tr),
                Tab(text: 'pet_tab_health'.tr),
                Tab(text: 'pet_tab_habits'.tr),
                Tab(text: 'pet_tab_gallery'.tr),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _aboutTab(context),
                  _healthTab(context),
                  _habitsTab(context),
                  _galleryTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HEADER (bannière photo + avatar + nom + badge + race/âge + poids/taille)
  Widget _header(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bannière photo + bouton « Changer la photo » + avatar superposé.
        SizedBox(
          height: 168.h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Photo bannière.
              Positioned.fill(
                child: _bannerUrl != null
                    ? CachedNetworkImage(
                        imageUrl: _bannerUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _bannerFallback(),
                        placeholder: (_, __) => _bannerFallback(),
                      )
                    : _bannerFallback(),
              ),
              if (editable)
                Positioned(
                  right: 12.w,
                  bottom: 12.h,
                  child: GestureDetector(
                    onTap: _changeProfilePhoto,
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo_camera_rounded,
                              color: Colors.white, size: 15.sp),
                          SizedBox(width: 6.w),
                          InterText(
                            text: 'pet_change_photo'.tr,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Avatar superposé bas-gauche.
              Positioned(
                left: 16.w,
                bottom: -34.h,
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.scaffold(context),
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 36.r,
                        backgroundColor: _accent.withValues(alpha: 0.15),
                        backgroundImage: pet.avatar.url.isNotEmpty
                            ? CachedNetworkImageProvider(pet.avatar.url)
                            : null,
                        child: pet.avatar.url.isEmpty
                            ? Icon(Icons.pets, size: 32.sp, color: _accent)
                            : null,
                      ),
                    ),
                    if (editable)
                      Positioned(
                        right: 2.w,
                        bottom: 2.h,
                        child: GestureDetector(
                          onTap: _changeProfilePhoto,
                          child: Container(
                            padding: EdgeInsets.all(5.w),
                            decoration: BoxDecoration(
                              color: _accent,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Icon(Icons.edit,
                                color: Colors.white, size: 12.sp),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 42.h),
        // Nom + badge « À jour ».
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PoppinsText(
                    text: pet.petName,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(context),
                  ),
                  SizedBox(width: 8.w),
                  if (_isUpToDate) _upToDateBadge(),
                ],
              ),
              SizedBox(height: 4.h),
              Row(
                children: [
                  Icon(Icons.location_on_rounded,
                      size: 14.sp, color: AppColors.greyText),
                  SizedBox(width: 3.w),
                  InterText(
                    text: [
                      if (pet.breed.isNotEmpty) pet.breed,
                      if (pet.age.isNotEmpty) '${pet.age} ${'pet_age_unit'.tr}',
                    ].join(' • '),
                    fontSize: 13.sp,
                    color: AppColors.greyText,
                  ),
                ],
              ),
              if (pet.weight.isNotEmpty || pet.height.isNotEmpty) ...[
                SizedBox(height: 6.h),
                Row(
                  children: [
                    if (pet.weight.isNotEmpty) ...[
                      Text('🏋', style: TextStyle(fontSize: 13.sp)),
                      SizedBox(width: 4.w),
                      InterText(
                        text: '${pet.weight} kg',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                      SizedBox(width: 16.w),
                    ],
                    if (pet.height.isNotEmpty) ...[
                      Icon(Icons.straighten_rounded,
                          size: 14.sp, color: AppColors.greyText),
                      SizedBox(width: 4.w),
                      InterText(
                        text: '${pet.height} cm',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: 10.h),
      ],
    );
  }

  Widget _bannerFallback() => Container(
        color: _accent.withValues(alpha: 0.12),
        child: Center(child: Text('🐾', style: TextStyle(fontSize: 54.sp))),
      );

  Widget _upToDateBadge() => Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: const Color(0xFF16A34A).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded,
                size: 13.sp, color: const Color(0xFF16A34A)),
            SizedBox(width: 4.w),
            InterText(
              text: 'pet_up_to_date'.tr,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF16A34A),
            ),
          ],
        ),
      );

  // ── ABOUT ─────────────────────────────────────────────────────────────────
  Widget _aboutTab(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        if (pet.characterTraits.isNotEmpty)
          _section('pet_character_traits'.tr,
              icon: Icons.bolt_rounded,
              [_chips(pet.characterTraits.map((t) => 'pet_trait_$t'.tr).toList())]),
        if (pet.bio.isNotEmpty)
          _section('pet_bio'.tr,
              icon: Icons.favorite_rounded, [_paragraph(pet.bio)]),
        if (!pet.compatibilities.isEmpty)
          _section('pet_compatibilities'.tr,
              icon: Icons.group_rounded, [
            if (pet.compatibilities.withDogs.isNotEmpty)
              _compatRow('pet_compat_dogs'.tr, pet.compatibilities.withDogs),
            if (pet.compatibilities.withCats.isNotEmpty)
              _compatRow('pet_compat_cats'.tr, pet.compatibilities.withCats),
            if (pet.compatibilities.withChildren.isNotEmpty)
              _compatRow(
                  'pet_compat_children'.tr, pet.compatibilities.withChildren),
          ]),
        if (pet.particularities.isNotEmpty)
          _section('pet_particularities'.tr,
              icon: Icons.star_rounded, [_chips(pet.particularities)]),
        _section('pet_physical'.tr, icon: Icons.straighten_rounded, [
          if (pet.breed.isNotEmpty) _kv('my_pets_breed_label'.tr, pet.breed),
          if (pet.colour.isNotEmpty) _kv('my_pets_color_label'.tr, pet.colour),
          if (pet.weight.isNotEmpty) _kv('edit_pet_weight'.tr, '${pet.weight} kg'),
          if (pet.height.isNotEmpty) _kv('edit_pet_height'.tr, '${pet.height} cm'),
        ]),
      ],
    );
  }

  // ── HEALTH ──────────────────────────────────────────────────────────────
  Widget _healthTab(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        _section('pet_vaccinations'.tr,
            icon: Icons.vaccines_rounded,
            trailing: _isUpToDate ? _miniUpToDate() : null, [
          if (pet.vaccinations.where((s) => s.trim().isNotEmpty).isEmpty &&
              pet.vaccinationStatus.isNotEmpty)
            _checkRow(_vaxLabel(pet.vaccinationStatus)),
          ...pet.vaccinations
              .where((s) => s.trim().isNotEmpty)
              .map((v) => _checkRow(v)),
        ]),
        if (!pet.deworming.isEmpty)
          _section('pet_deworming'.tr,
              icon: Icons.medication_rounded,
              trailing: _miniUpToDate(), [
            if (pet.deworming.lastDate.isNotEmpty)
              _kv('pet_deworming_last_date'.tr,
                  pet.deworming.lastDate.length >= 10
                      ? pet.deworming.lastDate.substring(0, 10)
                      : pet.deworming.lastDate),
            if (pet.deworming.frequency.isNotEmpty)
              _kv('pet_deworming_frequency'.tr, pet.deworming.frequency),
          ]),
        _section('pet_current_treatments'.tr,
            icon: Icons.healing_rounded, [
          _paragraph(pet.currentTreatments.isEmpty
              ? 'pet_no_treatment'.tr
              : pet.currentTreatments),
        ]),
        if (pet.medicationAllergies.isNotEmpty)
          _section('my_pets_allergies_label'.tr,
              icon: Icons.warning_amber_rounded,
              [_paragraph(pet.medicationAllergies, danger: true)]),
        if (pet.bloodGroup.isNotEmpty)
          _section('pet_blood_group'.tr,
              icon: Icons.bloodtype_rounded, [_paragraph(pet.bloodGroup)]),
        if (!pet.healthInsurance.isEmpty)
          _section('pet_health_insurance'.tr,
              icon: Icons.shield_rounded, [
            if (pet.healthInsurance.name.isNotEmpty)
              _kv('pet_insurance_name'.tr, pet.healthInsurance.name),
            if (pet.healthInsurance.number.isNotEmpty)
              _kv('pet_insurance_number'.tr, pet.healthInsurance.number),
          ]),
        if (pet.regularVet.name.isNotEmpty || pet.regularVet.phone.isNotEmpty)
          _section('pet_regular_vet'.tr, icon: Icons.local_hospital_rounded, [
            if (pet.regularVet.name.isNotEmpty)
              _kv('pet_vet_name'.tr, pet.regularVet.name),
            if (pet.regularVet.address.isNotEmpty)
              _kv('pet_vet_address'.tr, pet.regularVet.address),
            if (pet.regularVet.phone.isNotEmpty)
              _kv('pet_vet_phone'.tr, pet.regularVet.phone),
          ]),
        if (pet.emergencyVet.name.isNotEmpty ||
            pet.emergencyVet.phone.isNotEmpty)
          _section('pet_emergency_vet'.tr, icon: Icons.emergency_rounded, [
            if (pet.emergencyVet.name.isNotEmpty)
              _kv('pet_vet_name'.tr, pet.emergencyVet.name),
            if (pet.emergencyVet.phone.isNotEmpty)
              _kv('pet_vet_phone'.tr, pet.emergencyVet.phone),
          ]),
      ],
    );
  }

  // ── HABITS ──────────────────────────────────────────────────────────────
  Widget _habitsTab(BuildContext context) {
    final h = pet.habits;
    final rows = <Widget>[
      if (h.energyLevel.isNotEmpty)
        _iconRow(Icons.bolt_rounded, 'pet_energy_level'.tr,
            _energyLabel(h.energyLevel)),
      if (h.preferredActivity.isNotEmpty)
        _iconRow(Icons.directions_run_rounded, 'pet_preferred_activity'.tr,
            h.preferredActivity),
      if (h.education.isNotEmpty)
        _iconRow(Icons.school_rounded, 'pet_education'.tr, h.education),
      if (h.aloneTolerance.isNotEmpty)
        _iconRow(Icons.home_rounded, 'pet_alone_tolerance'.tr,
            h.aloneTolerance),
      if (h.barking.isNotEmpty)
        _iconRow(Icons.campaign_rounded, 'pet_barking'.tr, h.barking),
      if (h.likes.isNotEmpty)
        _iconRow(Icons.thumb_up_rounded, 'pet_likes'.tr, h.likes),
      if (h.dislikes.isNotEmpty)
        _iconRow(Icons.thumb_down_rounded, 'pet_dislikes'.tr, h.dislikes),
      if (h.transport.isNotEmpty)
        _iconRow(Icons.directions_car_rounded, 'pet_transport'.tr,
            h.transport),
      if (h.brushing.isNotEmpty)
        _iconRow(Icons.brush_rounded, 'pet_brushing'.tr, h.brushing),
      if (h.food.isNotEmpty)
        _iconRow(Icons.restaurant_rounded, 'pet_food'.tr, h.food),
      if (h.allowedTreats.isNotEmpty)
        _iconRow(Icons.cookie_rounded, 'pet_allowed_treats'.tr,
            h.allowedTreats),
      if (h.favoriteObjects.isNotEmpty)
        _iconRow(Icons.toys_rounded, 'pet_favorite_objects'.tr,
            h.favoriteObjects),
      if (h.favoritePlaces.isNotEmpty)
        _iconRow(Icons.place_rounded, 'pet_favorite_places'.tr,
            h.favoritePlaces),
      if (h.remarks.isNotEmpty)
        _iconRow(Icons.notes_rounded, 'pet_remarks'.tr, h.remarks),
    ];
    if (rows.isEmpty) return _empty('pet_no_info'.tr);
    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: Get.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: _accent.withValues(alpha: 0.15)),
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }

  // ── GALLERY ─────────────────────────────────────────────────────────────
  Widget _galleryTab(BuildContext context) {
    final urls = <String>[];
    for (final p in pet.photos) {
      if (p is Map && (p['url'] ?? '').toString().isNotEmpty) {
        urls.add(p['url'].toString());
      }
    }
    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        InterText(
          text: 'pet_gallery_title'.tr,
          fontSize: 15.sp,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary(context),
        ),
        SizedBox(height: 12.h),
        if (urls.isEmpty)
          _empty('pet_gallery_empty'.tr)
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10.w,
              crossAxisSpacing: 10.w,
            ),
            itemCount: urls.length,
            itemBuilder: (context, i) => ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: CachedNetworkImage(
                imageUrl: urls[i],
                fit: BoxFit.cover,
                placeholder: (c, _) => Container(color: AppColors.lightGreyColor),
                errorWidget: (c, _, __) => Container(
                  color: AppColors.lightGreyColor,
                  child: Icon(Icons.broken_image, color: AppColors.greyColor),
                ),
              ),
            ),
          ),
        if (editable) ...[
          SizedBox(height: 14.h),
          GestureDetector(
            onTap: _openGallery,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                    color: _accent.withValues(alpha: 0.4),
                    style: BorderStyle.solid),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, color: _accent, size: 18.sp),
                  SizedBox(width: 8.w),
                  InterText(
                    text: 'pet_add_photos'.tr,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: _accent,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── building blocks ───────────────────────────────────────────────────────
  Widget _section(String title, List<Widget> children,
      {IconData? icon, Widget? trailing}) {
    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Get.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _accent.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18.sp, color: _accent),
                SizedBox(width: 8.w),
              ],
              Expanded(
                child: PoppinsText(
                  text: title,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(Get.context!),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          SizedBox(height: 10.h),
          ...children,
        ],
      ),
    );
  }

  Widget _miniUpToDate() => Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: const Color(0xFF16A34A).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: InterText(
          text: 'pet_up_to_date'.tr,
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF16A34A),
        ),
      );

  Widget _checkRow(String text) => Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded,
                size: 17.sp, color: const Color(0xFF16A34A)),
            SizedBox(width: 8.w),
            Expanded(
              child: InterText(
                text: text,
                fontSize: 13.sp,
                color: AppColors.textPrimary(Get.context!),
              ),
            ),
          ],
        ),
      );

  Widget _iconRow(IconData icon, String label, String value) => Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18.sp, color: _accent),
            SizedBox(width: 10.w),
            SizedBox(
              width: 110.w,
              child: InterText(
                text: label,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(Get.context!),
              ),
            ),
            Expanded(
              child: InterText(
                text: value,
                fontSize: 12.sp,
                color: AppColors.greyText,
              ),
            ),
          ],
        ),
      );

  Widget _compatRow(String label, String value) {
    final color = value == 'compatible'
        ? const Color(0xFF16A34A)
        : value == 'supervised'
            ? const Color(0xFFF59E0B)
            : const Color(0xFFDC2626);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InterText(
            text: label,
            fontSize: 13.sp,
            color: AppColors.textPrimary(Get.context!),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: InterText(
              text: _compatLabel(value),
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) => Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130.w,
              child: InterText(
                text: label,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.greyText,
              ),
            ),
            Expanded(
              child: InterText(
                text: value,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(Get.context!),
              ),
            ),
          ],
        ),
      );

  Widget _paragraph(String text, {bool danger = false}) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: danger
              ? AppColors.errorColor.withValues(alpha: 0.08)
              : AppColors.lightGrey.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: InterText(
          text: text,
          fontSize: 12.sp,
          color: danger ? AppColors.errorColor : AppColors.textPrimary(Get.context!),
        ),
      );

  Widget _chips(List<String> items) => Wrap(
        spacing: 6.w,
        runSpacing: 6.h,
        children: items
            .map((t) => Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: _accent.withValues(alpha: 0.3)),
                  ),
                  child: InterText(
                    text: t,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: _accent,
                  ),
                ))
            .toList(),
      );

  Widget _empty(String text) => Center(
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🐾', style: TextStyle(fontSize: 40.sp)),
              SizedBox(height: 12.h),
              InterText(text: text, fontSize: 14.sp, color: AppColors.greyColor),
            ],
          ),
        ),
      );

  // ── label helpers ───────────────────────────────────────────────────────
  String _compatLabel(String v) {
    switch (v) {
      case 'compatible':
        return 'pet_compat_yes'.tr;
      case 'supervised':
        return 'pet_compat_supervised'.tr;
      case 'no':
        return 'pet_compat_no'.tr;
      default:
        return v;
    }
  }

  String _vaxLabel(String v) {
    switch (v) {
      case 'up_to_date':
        return 'pet_vax_up_to_date'.tr;
      case 'late':
        return 'pet_vax_late'.tr;
      case 'unknown':
        return 'pet_vax_unknown'.tr;
      default:
        return v;
    }
  }

  String _energyLabel(String v) {
    switch (v) {
      case 'low':
        return 'pet_energy_low'.tr;
      case 'medium':
        return 'pet_energy_medium'.tr;
      case 'high':
        return 'pet_energy_high'.tr;
      default:
        return v;
    }
  }
}
