import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/repositories/pet_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/views/pet_sitter/widgets/pet_detail_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// #107 — Vue PROFIL PROPRIÉTAIRE en lecture seule, ouverte par un prestataire
/// (promeneur / pet-sitter) depuis l'en-tête (avatar + nom) d'une annonce
/// owner. Affiche : avatar + nom, ville/localisation, « membre depuis » si
/// connu, « À propos de moi » (bio), puis les ANIMAUX de l'annonce sous forme
/// de cartes cliquables → chaque carte ouvre la fiche animal via le même
/// chemin que sitter_homescreen._handleCardTap (PetRepository.getPetById →
/// PetDetailScreen).
///
/// On réutilise les données déjà portées par le post (owner + pets) ; aucune
/// nouvelle source réseau côté owner. Les fiches animaux, elles, sont
/// chargées à la demande au tap (même endpoint que le feed).
class OwnerProfileViewScreen extends StatefulWidget {
  const OwnerProfileViewScreen({
    super.key,
    required this.ownerId,
    required this.ownerName,
    this.ownerAvatar,
    this.ownerBio,
    this.ownerCity,
    this.memberSince,
    this.pets = const <PostPet>[],
  });

  final String ownerId;
  final String ownerName;
  final String? ownerAvatar;
  final String? ownerBio;
  final String? ownerCity;

  /// Libellé déjà localisé « Membre depuis … » (optionnel). Null/vide ⇒ masqué.
  final String? memberSince;

  /// Animaux de l'annonce (cartes cliquables → fiche animal).
  final List<PostPet> pets;

  @override
  State<OwnerProfileViewScreen> createState() => _OwnerProfileViewScreenState();
}

class _OwnerProfileViewScreenState extends State<OwnerProfileViewScreen> {
  @override
  Widget build(BuildContext context) {
    final bio = (widget.ownerBio ?? '').trim();
    final city = (widget.ownerCity ?? '').trim();
    final memberSince = (widget.memberSince ?? '').trim();

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: AppColors.appBar(context),
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        title: PoppinsText(
          text: 'owner_profile_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, city: city, memberSince: memberSince),
              if (bio.isNotEmpty) ...[
                SizedBox(height: 18.h),
                _buildAboutCard(context, bio),
              ],
              if (widget.pets.isNotEmpty) ...[
                SizedBox(height: 18.h),
                InterText(
                  text: 'owner_profile_pets'.tr,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                ),
                SizedBox(height: 12.h),
                ...widget.pets.map((p) => Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: _buildPetCard(context, p),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required String city,
    required String memberSince,
  }) {
    final avatar = (widget.ownerAvatar ?? '').trim();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 44.r,
            backgroundColor: AppColors.primaryColor.withValues(alpha: 0.15),
            backgroundImage: avatar.isNotEmpty
                ? CachedNetworkImageProvider(avatar, maxWidth: 300)
                    as ImageProvider
                : AssetImage(AppImages.placeholderImage) as ImageProvider,
          ),
          SizedBox(height: 12.h),
          PoppinsText(
            text: widget.ownerName.trim().isNotEmpty
                ? widget.ownerName.trim()
                : 'common_user'.tr,
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary(context),
            maxLines: 2,
          ),
          SizedBox(height: 4.h),
          InterText(
            text: 'role_pet_owner'.tr,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryColor,
          ),
          if (city.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on_rounded,
                    size: 14.sp, color: AppColors.textSecondary(context)),
                SizedBox(width: 4.w),
                Flexible(
                  child: InterText(
                    text: city,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (memberSince.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_available_rounded,
                    size: 14.sp, color: AppColors.textSecondary(context)),
                SizedBox(width: 4.w),
                Flexible(
                  child: InterText(
                    text: memberSince,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context, String bio) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
      decoration: BoxDecoration(
        // Cohérent avec « À propos de moi » de la carte annonce (jaune clair).
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFFF6C343).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_rounded,
                  size: 16.sp, color: const Color(0xFFB8860B)),
              SizedBox(width: 8.w),
              InterText(
                text: 'owner_profile_about'.tr,
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          InterText(
            text: bio,
            fontSize: 12.5.sp,
            color: AppColors.textSecondary(context),
            maxLines: 12,
          ),
        ],
      ),
    );
  }

  Widget _buildPetCard(BuildContext context, PostPet pet) {
    final avatar = pet.avatar.trim();
    final metaParts = <String>[
      if (pet.breed.trim().isNotEmpty) pet.breed.trim(),
      if (pet.age != null) _ageLabel(pet.age!),
    ];
    return InkWell(
      onTap: pet.id.isNotEmpty ? () => _openPetDetails(pet.id) : null,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: AppColors.cardShadow(context),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26.r,
              backgroundColor: AppColors.primaryColor.withValues(alpha: 0.12),
              backgroundImage: avatar.isNotEmpty
                  ? CachedNetworkImageProvider(avatar, maxWidth: 200)
                      as ImageProvider
                  : null,
              child: avatar.isEmpty
                  ? Text(_speciesEmoji(pet.category),
                      style: TextStyle(fontSize: 22.sp))
                  : null,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(_speciesEmoji(pet.category),
                          style: TextStyle(fontSize: 14.sp)),
                      SizedBox(width: 5.w),
                      Flexible(
                        child: InterText(
                          text: pet.petName.trim().isNotEmpty
                              ? pet.petName.trim()
                              : 'owner_profile_pets'.tr,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (metaParts.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    InterText(
                      text: metaParts.join(' • '),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Icon(Icons.chevron_right_rounded,
                size: 22.sp, color: AppColors.greyColor),
          ],
        ),
      ),
    );
  }

  String _ageLabel(int years) => years <= 1
      ? '$years ${'pet_year_unit'.tr}'
      : '$years ${'pet_years_unit'.tr}';

  String _speciesEmoji(String category) {
    switch (category.trim().toLowerCase()) {
      case 'dog':
      case 'chien':
        return '🐕';
      case 'cat':
      case 'chat':
        return '🐈';
      case 'bird':
      case 'oiseau':
        return '🐦';
      case 'small':
      case 'small_animal':
      case 'lapin':
      case 'rongeur':
      case 'petit':
        return '🐹';
      case 'nac':
      case 'reptile':
        return '🦎';
      default:
        return '🐾';
    }
  }

  /// Ouvre la fiche animal — MÊME chemin que sitter_homescreen._handleCardTap :
  /// PetRepository.getPetById → mapping → PetDetailScreen.
  Future<void> _openPetDetails(String petId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
              ),
              SizedBox(height: 16.h),
              InterText(
                text: 'pet_detail_loading'.tr,
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary(context),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final petRepository = Get.find<PetRepository>();
      final pet = await petRepository.getPetById(petId);

      if (mounted) Navigator.of(context).pop();

      final age = pet.age.isNotEmpty ? pet.age : 'label_not_available'.tr;
      final gender = 'pet_detail_gender_unknown'.tr;
      final weight = pet.weight.isNotEmpty
          ? '${pet.weight} kg'
          : 'label_not_available'.tr;
      final height = pet.height.isNotEmpty
          ? '${pet.height} cm'
          : 'label_not_available'.tr;
      final description =
          pet.bio.isNotEmpty ? pet.bio : 'pet_detail_no_description'.tr;

      final List<String> galleryImages = [];
      if (pet.photos.isNotEmpty) {
        for (var photo in pet.photos) {
          if (photo is Map<String, dynamic> && photo['url'] != null) {
            galleryImages.add(photo['url'].toString());
          } else if (photo is String) {
            galleryImages.add(photo);
          }
        }
      }

      final vaccinations = pet.vaccinations.isNotEmpty
          ? pet.vaccinations
          : ['pet_detail_no_vaccinations'.tr];

      final List<String> petImages = [];
      if (pet.avatar.url.isNotEmpty) {
        petImages.add(pet.avatar.url);
      }
      for (var galleryImage in galleryImages) {
        if (!petImages.contains(galleryImage)) {
          petImages.add(galleryImage);
        }
      }

      final ownerName = pet.owner?.name;
      final ownerAvatar = pet.owner?.avatar;
      final ownerCity = pet.owner?.city;
      final ownerCreatedAt = pet.owner?.createdAt;
      final ownerUpdatedAt = pet.owner?.updatedAt;

      final passportNumber =
          pet.passportNumber.isNotEmpty ? pet.passportNumber : null;
      final chipNumber = pet.chipNumber.isNotEmpty ? pet.chipNumber : null;
      final medicationAllergies =
          pet.medicationAllergies.isNotEmpty ? pet.medicationAllergies : null;
      final dob = pet.dob.isNotEmpty ? pet.dob : null;
      final category = pet.category.isNotEmpty ? pet.category : null;

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PetDetailScreen(
              petName: pet.petName,
              breed: pet.breed.isNotEmpty
                  ? pet.breed
                  : 'pet_detail_breed_unknown'.tr,
              age: age,
              gender: gender,
              weight: weight,
              height: height,
              description: description,
              vaccinations: vaccinations,
              galleryImages: galleryImages,
              petImages: petImages,
              ownerName: ownerName,
              ownerAvatar: ownerAvatar,
              ownerCity: ownerCity,
              ownerCreatedAt: ownerCreatedAt,
              ownerUpdatedAt: ownerUpdatedAt,
              passportNumber: passportNumber,
              chipNumber: chipNumber,
              medicationAllergies: medicationAllergies,
              dob: dob,
              category: category,
            ),
          ),
        );
      }
    } on ApiException catch (error) {
      if (mounted) Navigator.of(context).pop();
      AppLogger.logError('Failed to load pet details', error: error.message);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: error.message,
      );
    } catch (error) {
      if (mounted) Navigator.of(context).pop();
      AppLogger.logError('Failed to load pet details', error: error);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'pet_detail_load_error'.tr,
      );
    }
  }
}
