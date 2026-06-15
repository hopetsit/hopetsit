import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/models/pet_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/profile/edit_pet_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// v406 refonte — fiche animal en lecture (maquette : 4 onglets À propos /
/// Santé / Habitudes / Galerie). `accent` = couleur de rôle (owner orange par
/// défaut ; un sitter/walker qui consulte la fiche peut passer sa couleur).
/// `editable` masque le crayon d'édition quand un prestataire consulte.
class PetProfileScreen extends StatelessWidget {
  final PetModel pet;
  final Color? accent;
  final bool editable;

  const PetProfileScreen({
    super.key,
    required this.pet,
    this.accent,
    this.editable = true,
  });

  Color get _accent => accent ?? AppColors.primaryColor;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.scaffold(context),
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              pinned: true,
              expandedHeight: 250.h,
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                if (editable)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () =>
                        Get.to(() => EditPetScreen(petId: pet.id, petData: pet)),
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _header(context),
              ),
              bottom: TabBar(
                isScrollable: true,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(text: 'pet_tab_about'.tr),
                  Tab(text: 'pet_tab_health'.tr),
                  Tab(text: 'pet_tab_habits'.tr),
                  Tab(text: 'pet_tab_gallery'.tr),
                ],
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _aboutTab(context),
              _healthTab(context),
              _habitsTab(context),
              _galleryTab(context),
            ],
          ),
        ),
      ),
    );
  }

  // ── header ────────────────────────────────────────────────────────────────
  Widget _header(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_accent, _accent.withValues(alpha: 0.82)],
        ),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 70.h, 20.w, 56.h),
      child: Row(
        children: [
          CircleAvatar(
            radius: 42.r,
            backgroundColor: Colors.white,
            backgroundImage: pet.avatar.url.isNotEmpty
                ? CachedNetworkImageProvider(pet.avatar.url)
                : null,
            child: pet.avatar.url.isEmpty
                ? Icon(Icons.pets, size: 40.sp, color: _accent)
                : null,
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                PoppinsText(
                  text: pet.petName,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                SizedBox(height: 6.h),
                Wrap(
                  spacing: 6.w,
                  runSpacing: 6.h,
                  children: [
                    if (pet.category.isNotEmpty) _headerChip(pet.category),
                    if (pet.breed.isNotEmpty) _headerChip(pet.breed),
                    if (pet.gender.isNotEmpty) _headerChip(_genderLabel(pet.gender)),
                    if (pet.age.isNotEmpty)
                      _headerChip('${pet.age} ${'pet_age_unit'.tr}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerChip(String text) => Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: InterText(
          text: text,
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      );

  // ── ABOUT ─────────────────────────────────────────────────────────────────
  Widget _aboutTab(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        if (pet.bio.isNotEmpty) _section('pet_bio'.tr, [_paragraph(pet.bio)]),
        if (pet.characterTraits.isNotEmpty)
          _section('pet_character_traits'.tr, [
            _chips(pet.characterTraits.map((t) => 'pet_trait_$t'.tr).toList()),
          ]),
        if (!pet.compatibilities.isEmpty)
          _section('pet_compatibilities'.tr, [
            if (pet.compatibilities.withDogs.isNotEmpty)
              _kv('pet_compat_dogs'.tr,
                  _compatLabel(pet.compatibilities.withDogs)),
            if (pet.compatibilities.withCats.isNotEmpty)
              _kv('pet_compat_cats'.tr,
                  _compatLabel(pet.compatibilities.withCats)),
            if (pet.compatibilities.withChildren.isNotEmpty)
              _kv('pet_compat_children'.tr,
                  _compatLabel(pet.compatibilities.withChildren)),
          ]),
        if (pet.particularities.isNotEmpty)
          _section('pet_particularities'.tr, [_chips(pet.particularities)]),
        if (pet.history.isNotEmpty)
          _section('pet_history'.tr, [_paragraph(pet.history)]),
        if (pet.notes.isNotEmpty)
          _section('pet_notes'.tr, [_paragraph(pet.notes)]),
        _section('pet_physical'.tr, [
          if (pet.breed.isNotEmpty) _kv('my_pets_breed_label'.tr, pet.breed),
          if (pet.colour.isNotEmpty) _kv('my_pets_color_label'.tr, pet.colour),
          if (pet.weight.isNotEmpty) _kv('edit_pet_weight'.tr, '${pet.weight} kg'),
          if (pet.height.isNotEmpty) _kv('edit_pet_height'.tr, '${pet.height} cm'),
        ]),
        if (pet.passportNumber.isNotEmpty || pet.chipNumber.isNotEmpty)
          _section('pet_identification'.tr, [
            if (pet.passportNumber.isNotEmpty)
              _kv('my_pets_passport_label'.tr, pet.passportNumber),
            if (pet.chipNumber.isNotEmpty)
              _kv('my_pets_chip_label'.tr, pet.chipNumber),
          ]),
      ],
    );
  }

  // ── HEALTH ──────────────────────────────────────────────────────────────
  Widget _healthTab(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        if (pet.vaccinationStatus.isNotEmpty)
          _section('pet_vaccination_status'.tr,
              [_statusPill(_vaxLabel(pet.vaccinationStatus))]),
        if (pet.vaccinations.isNotEmpty)
          _section('pet_vaccinations'.tr, [
            _chips(pet.vaccinations
                .where((s) => s.trim().isNotEmpty)
                .toList()),
          ]),
        if (pet.medicationAllergies.isNotEmpty)
          _section('my_pets_allergies_label'.tr, [
            _paragraph(pet.medicationAllergies, danger: true),
          ]),
        if (!pet.deworming.isEmpty)
          _section('pet_deworming'.tr, [
            if (pet.deworming.lastDate.isNotEmpty)
              _kv('pet_deworming_last_date'.tr,
                  pet.deworming.lastDate.length >= 10
                      ? pet.deworming.lastDate.substring(0, 10)
                      : pet.deworming.lastDate),
            if (pet.deworming.frequency.isNotEmpty)
              _kv('pet_deworming_frequency'.tr, pet.deworming.frequency),
          ]),
        if (pet.currentTreatments.isNotEmpty)
          _section('pet_current_treatments'.tr,
              [_paragraph(pet.currentTreatments)]),
        if (pet.bloodGroup.isNotEmpty)
          _section('pet_blood_group'.tr, [_paragraph(pet.bloodGroup)]),
        if (!pet.healthInsurance.isEmpty)
          _section('pet_health_insurance'.tr, [
            if (pet.healthInsurance.name.isNotEmpty)
              _kv('pet_insurance_name'.tr, pet.healthInsurance.name),
            if (pet.healthInsurance.number.isNotEmpty)
              _kv('pet_insurance_number'.tr, pet.healthInsurance.number),
          ]),
        if (pet.regularVet.name.isNotEmpty || pet.regularVet.phone.isNotEmpty)
          _section('pet_regular_vet'.tr, [
            if (pet.regularVet.name.isNotEmpty)
              _kv('pet_vet_name'.tr, pet.regularVet.name),
            if (pet.regularVet.phone.isNotEmpty)
              _kv('pet_vet_phone'.tr, pet.regularVet.phone),
            if (pet.regularVet.address.isNotEmpty)
              _kv('pet_vet_address'.tr, pet.regularVet.address),
          ]),
        if (pet.emergencyVet.name.isNotEmpty ||
            pet.emergencyVet.phone.isNotEmpty)
          _section('pet_emergency_vet'.tr, [
            if (pet.emergencyVet.name.isNotEmpty)
              _kv('pet_vet_name'.tr, pet.emergencyVet.name),
            if (pet.emergencyVet.phone.isNotEmpty)
              _kv('pet_vet_phone'.tr, pet.emergencyVet.phone),
            if (pet.emergencyVet.address.isNotEmpty)
              _kv('pet_vet_address'.tr, pet.emergencyVet.address),
          ]),
        if (pet.emergencyInterventionAuthorization)
          _section('pet_emergency_auth'.tr, [
            Row(
              children: [
                Icon(Icons.verified_user, color: _accent, size: 18.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: InterText(
                    text: 'pet_authorize_emergency'.tr,
                    fontSize: 12.sp,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ],
            ),
          ]),
      ],
    );
  }

  // ── HABITS ──────────────────────────────────────────────────────────────
  Widget _habitsTab(BuildContext context) {
    final h = pet.habits;
    final rows = <Widget>[
      if (h.energyLevel.isNotEmpty)
        _kv('pet_energy_level'.tr, _energyLabel(h.energyLevel)),
      if (h.preferredActivity.isNotEmpty)
        _kv('pet_preferred_activity'.tr, h.preferredActivity),
      if (h.education.isNotEmpty) _kv('pet_education'.tr, h.education),
      if (h.aloneTolerance.isNotEmpty)
        _kv('pet_alone_tolerance'.tr, h.aloneTolerance),
      if (h.barking.isNotEmpty) _kv('pet_barking'.tr, h.barking),
      if (h.likes.isNotEmpty) _kv('pet_likes'.tr, h.likes),
      if (h.dislikes.isNotEmpty) _kv('pet_dislikes'.tr, h.dislikes),
      if (h.transport.isNotEmpty) _kv('pet_transport'.tr, h.transport),
      if (h.brushing.isNotEmpty) _kv('pet_brushing'.tr, h.brushing),
      if (h.food.isNotEmpty) _kv('pet_food'.tr, h.food),
      if (h.allowedTreats.isNotEmpty)
        _kv('pet_allowed_treats'.tr, h.allowedTreats),
      if (h.favoriteObjects.isNotEmpty)
        _kv('pet_favorite_objects'.tr, h.favoriteObjects),
      if (h.favoritePlaces.isNotEmpty)
        _kv('pet_favorite_places'.tr, h.favoritePlaces),
    ];
    if (rows.isEmpty && h.remarks.isEmpty) return _empty('pet_no_info'.tr);
    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        if (rows.isNotEmpty) _section('pet_tab_habits'.tr, rows),
        if (h.remarks.isNotEmpty)
          _section('pet_remarks'.tr, [_paragraph(h.remarks)]),
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
    if (urls.isEmpty) return _empty('pet_gallery_empty'.tr);
    return GridView.builder(
      padding: EdgeInsets.all(16.w),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12.w,
        crossAxisSpacing: 12.w,
      ),
      itemCount: urls.length,
      itemBuilder: (context, i) => ClipRRect(
        borderRadius: BorderRadius.circular(14.r),
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
    );
  }

  // ── building blocks ───────────────────────────────────────────────────────
  Widget _section(String title, List<Widget> children) {
    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Get.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PoppinsText(
            text: title,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: _accent,
          ),
          SizedBox(height: 8.h),
          ...children,
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
                color: AppColors.blackColor,
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
          color: danger ? AppColors.errorColor : AppColors.blackColor,
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

  Widget _statusPill(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: InterText(
            text: text,
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: _accent,
          ),
        ),
      );

  Widget _empty(String text) => Center(
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🐾', style: TextStyle(fontSize: 40.sp)),
              SizedBox(height: 12.h),
              InterText(
                text: text,
                fontSize: 14.sp,
                color: AppColors.greyColor,
              ),
            ],
          ),
        ),
      );

  // ── label helpers ───────────────────────────────────────────────────────
  String _genderLabel(String g) =>
      g == 'male' ? 'pet_gender_male'.tr : 'pet_gender_female'.tr;

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
