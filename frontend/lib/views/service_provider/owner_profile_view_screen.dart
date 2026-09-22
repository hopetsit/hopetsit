// v573 — FICHE PROPRIÉTAIRE vue par un gardien / promeneur depuis une annonce.
//
// Harmonisée avec les fiches gardien et promeneur via `public_profile_kit.dart`
// (même en-tête héro, mêmes tuiles, mêmes cartes de section, même fond à
// petites pattes). Aucune logique touchée : mêmes données portées par l'annonce,
// même chemin de chargement d'une fiche animal au tap.
//
// ⚠️ L'avatar n'utilise PLUS `AppImages.placeholderImage` en repli (l'image de
// catalogue grise) : sans photo on affiche l'initiale du prénom sur un aplat à
// la couleur du rôle.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/repositories/pet_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/views/pet_sitter/widgets/pet_detail_screen.dart';
import 'package:hopetsit/views/pet_sitter/widgets/post_card_kit.dart';
import 'package:hopetsit/views/service_provider/widgets/public_profile_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';

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
  static const PublicProfilePalette _palette = kOwnerProfilePalette;

  @override
  Widget build(BuildContext context) {
    final String bio = (widget.ownerBio ?? '').trim();
    final String city = (widget.ownerCity ?? '').trim();
    final String memberSince = (widget.memberSince ?? '').trim();
    final String name = widget.ownerName.trim().isNotEmpty
        ? widget.ownerName.trim()
        : 'common_user'.tr;

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: publicProfileAppBar(
        palette: _palette,
        title: PoppinsText(
          text: 'owner_profile_title'.tr,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: PawPatternBackground(
          color: AppColors.activeRoleAccent(),
          child: SafeArea(
        bottom: false,
        child: PublicProfileBackground(
          accent: _palette.accent,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: publicProfileBottomPadding(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                PublicProfileHero(
                  palette: _palette,
                  role: 'owner',
                  name: name,
                  imageUrl: widget.ownerAvatar,
                  location: city,
                  subtitle: memberSince,
                ),
                SizedBox(height: 18.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (widget.pets.isNotEmpty) ...<Widget>[
                        PublicProfileStatsRow(
                          accent: _palette.accent,
                          stats: <PublicProfileStat>[
                            PublicProfileStat(
                              icon: Icons.pets_rounded,
                              value: '${widget.pets.length}',
                              label: 'profiles573_stat_pets'.tr,
                            ),
                          ],
                        ),
                        SizedBox(height: 14.h),
                      ],
                      if (bio.isNotEmpty) ...<Widget>[
                        _buildAboutCard(context, bio),
                        SizedBox(height: 14.h),
                      ],
                      if (widget.pets.isNotEmpty)
                        PublicProfileSection(
                          accent: _palette.accent,
                          icon: Icons.pets_rounded,
                          title: 'owner_profile_pets'.tr,
                          trailing: InterText(
                            text: '${widget.pets.length}',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary(context),
                          ),
                          child: Column(
                            children: <Widget>[
                              for (int i = 0; i < widget.pets.length; i++)
                                ...<Widget>[
                                  if (i > 0) SizedBox(height: 10.h),
                                  _buildPetCard(context, widget.pets[i]),
                                ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
        ),
    );
  }

  /// v569 — BUG mode sombre : le fond était `AppColors.scaffoldOwnerLight`
  /// (orange TRÈS pâle, en dur) alors que le texte suit le thème → bio
  /// quasi invisible en sombre. v573 : carte de section du kit, et le
  /// « voir plus / voir moins » de `PostExpandableText` est conservé.
  Widget _buildAboutCard(BuildContext context, String bio) {
    return PublicProfileSection(
      accent: _palette.accent,
      icon: Icons.person_rounded,
      title: 'owner_profile_about'.tr,
      child: PostExpandableText(
        text: bio,
        moreLabel: 'post569_see_more'.tr,
        lessLabel: 'post569_see_less'.tr,
        accent: _palette.accent,
        maxLines: 6,
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
      borderRadius: BorderRadius.circular(PostCardKit.blockRadius.r),
      child: Container(
        constraints: BoxConstraints(minHeight: PostCardKit.tapTarget.w),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppColors.scaffold(context),
          borderRadius: BorderRadius.circular(PostCardKit.blockRadius.r),
          border: Border.all(color: AppColors.divider(context)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26.r,
              backgroundColor: _palette.accent.withValues(alpha: 0.12),
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
                          // v569 — le repli affichait le titre de section
                          // (« Ses animaux ») comme NOM d'animal.
                          text: pet.petName.trim().isNotEmpty
                              ? pet.petName.trim()
                              : 'lists569_pet_fallback'.tr,
                          fontSize: 15,
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
                      fontSize: 12,
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
                size: 22.sp, color: AppColors.textTertiary(context)),
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
      // v569 — même carte de chargement que le reste du lot.
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 22.h),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(18.r),
            boxShadow: AppColors.cardShadow(context),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                strokeWidth: 2.6,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
              ),
              SizedBox(height: 16.h),
              InterText(
                text: 'pet_detail_loading'.tr,
                fontSize: 13,
                fontWeight: FontWeight.w600,
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
