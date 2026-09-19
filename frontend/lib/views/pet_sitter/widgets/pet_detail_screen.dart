// v569 — fiche animal vue par le prestataire, remise au format du lot :
// en-tête photo arrondi, identité, puces d'infos à icônes (`PostBullet`) et
// blocs encadrés (`PostBlock`), pilules de vaccination lisibles.
//
// ⚠️ DESIGN UNIQUEMENT : mêmes paramètres, mêmes données, aucune requête.
// BUG corrigé : « Membre depuis » / « Mis à jour » s'affichaient en
// `j/m/aaaa h:mm` construit à la main → date et heure dans la langue de
// l'app (`Get.locale`), heure sur 2 chiffres.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/views/pet_sitter/widgets/post_card_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:intl/intl.dart';

class PetDetailScreen extends StatefulWidget {
  final String petName;
  final String breed;
  final String age;
  final String gender;
  final String weight;
  final String height;
  // v21.1 — `color` (couleur de l'animal) retiré : info peu utile pour le sitter
  // et redondante avec la galerie photo. Allège la fiche pet.
  final String description;
  final List<String> vaccinations;
  final List<String> galleryImages;
  final List<String> petImages; // Changed from String petImage to List<String>
  final String? sitterProfileImage;
  final String? ownerName;
  final String? ownerAvatar;
  // v22.1 — Bug 11c : ville propriétaire affichée dans la section Owner.
  final String? ownerCity;
  final String? ownerCreatedAt;
  final String? ownerUpdatedAt;
  final String? passportNumber;
  final String? chipNumber;
  final String? medicationAllergies;
  final String? dob;
  final String? category;

  const PetDetailScreen({
    super.key,
    required this.petName,
    required this.breed,
    required this.age,
    required this.gender,
    required this.weight,
    required this.height,
    required this.description,
    required this.vaccinations,
    required this.galleryImages,
    required this.petImages,
    this.sitterProfileImage,
    this.ownerName,
    this.ownerAvatar,
    this.ownerCity,
    this.ownerCreatedAt,
    this.ownerUpdatedAt,
    this.passportNumber,
    this.chipNumber,
    this.medicationAllergies,
    this.dob,
    this.category,
  });

  @override
  State<PetDetailScreen> createState() => _PetDetailScreenState();
}

class _PetDetailScreenState extends State<PetDetailScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// v22.1 — Bug 11b : filtre les valeurs default (Inconnu / N/D / vide)
  /// avant de construire la sous-ligne race · âge sous le nom du pet.
  /// Si tout est default, retourne chaîne vide → la ligne disparaît.
  String _buildBreedAgeLine() {
    bool isDefault(String s) {
      final v = s.trim().toLowerCase();
      return v.isEmpty ||
          v == 'inconnu' ||
          v == 'n/d' ||
          v == 'unknown' ||
          v == 'breed_unknown';
    }
    final parts = <String>[];
    if (!isDefault(widget.breed)) parts.add(widget.breed);
    if (!isDefault(widget.age)) parts.add(widget.age);
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        leading: BackButton(),
        title: InterText(
          text: widget.petName,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16.w),
            child: CircleAvatar(
              radius: 16.r,
              backgroundColor: AppColors.primaryColor,
              child: CircleAvatar(
                radius: 14.r,
                backgroundColor: AppColors.grey300Color,
                backgroundImage:
                    widget.sitterProfileImage != null &&
                        widget.sitterProfileImage!.isNotEmpty &&
                        (widget.sitterProfileImage!.startsWith('http://') ||
                            widget.sitterProfileImage!.startsWith('https://'))
                    ? CachedNetworkImageProvider(widget.sitterProfileImage!)
                    : null,
                child:
                    widget.sitterProfileImage == null ||
                        widget.sitterProfileImage!.isEmpty ||
                        (!widget.sitterProfileImage!.startsWith('http://') &&
                            !widget.sitterProfileImage!.startsWith('https://'))
                    ? Icon(
                        Icons.person,
                        size: 20.sp,
                        color: AppColors.greyColor,
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Column(
            children: [
              // Hero Section
              _buildHeroSection(),

              // Content Sections
              Padding(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // About Pet Section
                    _buildAboutSection(),
                    SizedBox(height: 24.h),

                    // Vaccinations Section
                    _buildVaccinationsSection(),
                    SizedBox(height: 24.h),

                    // Owner Information Section (if available)
                    if (widget.ownerName != null) ...[
                      _buildOwnerSection(),
                      SizedBox(height: 24.h),
                    ],

                    // Gallery Section
                    _buildGallerySection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    final hasImages = widget.petImages.isNotEmpty;
    final hasMultipleImages = widget.petImages.length > 1;

    return SizedBox(
      height: 350.h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Image Slider or Single Image — v569 : coins bas arrondis.
          ClipRRect(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28.r)),
            child: Container(
              width: double.infinity,
              height: 300.h,
              decoration: BoxDecoration(color: AppColors.lightGrey),
              child: hasImages
                  ? (hasMultipleImages
                        ? _buildImageSlider()
                        : _buildSingleImage(widget.petImages.first))
                  : Center(
                      child: Image.asset(
                        AppImages.placeholderImage,
                        width: 60.w,
                        height: 60.h,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
          ),

          // Page Indicators (only show if multiple images)
          if (hasMultipleImages)
            Positioned(
              bottom: 120.h,
              left: 0,
              right: 0,
              child: _buildPageIndicators(),
            ),

          // Profile Overlay Card
          Positioned(
            bottom: -10.h,
            left: 8.w,
            right: 8.w,
            child: Container(
              // v569 — hauteur FIXE supprimée : le nom + « race · âge »
              // débordaient en allemand et en polonais.
              constraints: BoxConstraints(minHeight: 92.h),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.all(Radius.circular(26.r)),
                boxShadow: AppColors.cardShadow(context),
              ),
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left Column - Pet Name and Details
                  // v22.1 — bugs 11b + 11d :
                  //   * Sous-ligne breed.age : on n'affiche que les valeurs
                  //     non-default. Avant on voyait "Inconnu . N/D" qui était
                  //     moche. Maintenant : seulement les morceaux qui ont
                  //     une vraie valeur, séparés par " · ".
                  //   * Icône orange à droite (gender container) supprimée :
                  //     redondante avec le champ sexe affiché ailleurs.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PoppinsText(
                          text: widget.petName,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_buildBreedAgeLine().isNotEmpty) ...[
                          SizedBox(height: 4.h),
                          PoppinsText(
                            text: _buildBreedAgeLine(),
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary(context),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Titre de section unifié : pastille ronde teintée + libellé 14/800.
  Widget _sectionTitle(IconData icon, String label) {
    return Row(
      children: [
        Container(
          width: 30.w,
          height: 30.w,
          decoration: BoxDecoration(
            color: AppColors.primaryColor.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16.sp, color: AppColors.primaryColor),
        ),
        SizedBox(width: 9.w),
        Expanded(
          child: PoppinsText(
            text: label,
            fontSize: 14.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    final extras = <Widget>[
      if (widget.passportNumber != null && widget.passportNumber!.isNotEmpty)
        PostBullet(
          icon: Icons.badge_rounded,
          accent: AppColors.primaryColor,
          label: 'pet_detail_passport_number'.tr,
          value: widget.passportNumber!,
        ),
      if (widget.chipNumber != null && widget.chipNumber!.isNotEmpty)
        PostBullet(
          icon: Icons.memory_rounded,
          accent: AppColors.primaryColor,
          label: 'pet_detail_chip_number'.tr,
          value: widget.chipNumber!,
        ),
      if (widget.medicationAllergies != null &&
          widget.medicationAllergies!.isNotEmpty)
        PostBullet(
          icon: Icons.medical_information_rounded,
          accent: AppColors.primaryColor,
          label: 'pet_detail_medication_allergies'.tr,
          value: widget.medicationAllergies!,
        ),
      if (widget.dob != null && widget.dob!.isNotEmpty)
        PostBullet(
          icon: Icons.cake_rounded,
          accent: AppColors.primaryColor,
          label: 'pet_detail_date_of_birth'.tr,
          value: widget.dob!,
        ),
      if (widget.category != null && widget.category!.isNotEmpty)
        PostBullet(
          icon: Icons.category_rounded,
          accent: AppColors.primaryColor,
          label: 'pet_detail_category'.tr,
          value: _localizedCategory(widget.category!),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          Icons.pets_rounded,
          'pet_detail_about'.tr.replaceAll('@name', widget.petName),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            _buildDetailBox('pet_detail_weight'.tr, widget.weight),
            SizedBox(width: 10.w),
            _buildDetailBox(
              'pet_detail_height'.tr,
              _sanitizeHeight(widget.height),
            ),
          ],
        ),
        if (widget.description.trim().isNotEmpty) ...[
          SizedBox(height: 14.h),
          PostBlock(
            accent: AppColors.primaryColor,
            background: AppColors.card(context),
            borderColor: AppColors.divider(context),
            child: PostExpandableText(
              text: widget.description,
              moreLabel: 'post569_see_more'.tr,
              lessLabel: 'post569_see_less'.tr,
              accent: AppColors.primaryColor,
              maxLines: 4,
            ),
          ),
        ],
        if (extras.isNotEmpty) ...[
          SizedBox(height: 12.h),
          PostBlock(
            accent: AppColors.primaryColor,
            background: AppColors.card(context),
            borderColor: AppColors.divider(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: extras,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVaccinationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          Icons.vaccines_rounded,
          'pet_detail_vaccinations'.tr.replaceAll('@name', widget.petName),
        ),
        SizedBox(height: 12.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: widget.vaccinations
              .map((vaccination) => _buildVaccinationTag(_localizedVaccination(vaccination)))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildGallerySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          Icons.photo_library_rounded,
          'pet_detail_gallery'.tr.replaceAll('@name', widget.petName),
        ),
        SizedBox(height: 12.h),
        if (widget.galleryImages.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24.h),
              child: InterText(
                text: 'pet_detail_no_photos'.tr,
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.greyColor,
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8.w,
              mainAxisSpacing: 8.h,
              childAspectRatio: 1,
            ),
            itemCount: widget.galleryImages.length,
            itemBuilder: (context, index) {
              final imageUrl = widget.galleryImages[index];
              final isNetworkImage =
                  imageUrl.startsWith('http://') ||
                  imageUrl.startsWith('https://');

              return ClipRRect(
                borderRadius: BorderRadius.circular(14.r),
                child: isNetworkImage
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppColors.lightGrey,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryColor,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.lightGrey,
                          child: Icon(
                            Icons.broken_image,
                            color: AppColors.greyColor,
                          ),
                        ),
                      )
                    : Image.asset(imageUrl, fit: BoxFit.cover),
              );
            },
          ),
      ],
    );
  }

  Widget _buildDetailBox(String title, String value) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 10.w),
        decoration: BoxDecoration(
          color: AppColors.primaryColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(PostCardKit.blockRadius.r),
          border: Border.all(
            color: AppColors.primaryColor.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          children: [
            PoppinsText(
              text: title,
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4.h),
            PoppinsText(
              text: value,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryColor,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // v23.1.168 — Daniel : "Chien" et "À jour" restaient en français même sur
  // l'app en espagnol. Cause : la valeur du champ avait été stockée en FR
  // brut dans Mongo. On normalise vers les clés i18n pour suivre la locale.
  String _localizedCategory(String raw) {
    final lower = raw.trim().toLowerCase();
    switch (lower) {
      case 'dog': case 'chien': case 'perro':
      case 'hund': case 'cane': case 'cão': case 'cao':
        return 'create_pet_category_dog'.tr;
      case 'cat': case 'chat': case 'gato':
      case 'katze': case 'gatto':
        return 'create_pet_category_cat'.tr;
      case 'bird': case 'oiseau': case 'pájaro': case 'pajaro':
      case 'vogel': case 'uccello': case 'pássaro': case 'passaro':
        return 'create_pet_category_bird'.tr;
      case 'rabbit': case 'lapin': case 'conejo':
      case 'kaninchen': case 'coniglio': case 'coelho':
        return 'create_pet_category_rabbit'.tr;
      case 'other': case 'autre': case 'otro':
      case 'andere': case 'altro': case 'outro':
        return 'create_pet_category_other'.tr;
      default:
        return raw;
    }
  }

  String _localizedVaccination(String raw) {
    final lower = raw.trim().toLowerCase();
    switch (lower) {
      case 'up to date': case 'à jour': case 'a jour':
      case 'al día': case 'al dia':
      case 'aktuell':
      case 'aggiornate': case 'aggiornato':
      case 'atualizado': case 'em dia':
        return 'create_pet_vaccination_up_to_date'.tr;
      case 'not vaccinated':
      case 'non vacciné': case 'non vaccine':
      case 'no vacunado':
      case 'nicht geimpft':
      case 'non vaccinato':
      case 'não vacinado': case 'nao vacinado':
        return 'create_pet_vaccination_not_vaccinated'.tr;
      case 'partial': case 'partially vaccinated':
      case 'partiel': case 'partiellement vacciné':
      case 'parcial': case 'parcialmente vacunado':
      case 'teilweise geimpft':
      case 'parziale': case 'parzialmente vaccinato':
      case 'parcialmente vacinado':
        return 'create_pet_vaccination_partial'.tr;
      default:
        return raw;
    }
  }

  // v23.1.168 — Daniel : "Altura .100 cm" — la string était stockée comme
  // ".100" (ex. virgule décimale FR convertie en point par IME, ou typo).
  // On nettoie : ajoute le 0 devant le point si la chaîne commence par "."
  // et on dépouille les caractères non numériques au passage.
  String _sanitizeHeight(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return s;
    // .100 -> 0.100
    if (s.startsWith('.')) s = '0$s';
    // ,100 -> 0.100 (decimal comma)
    if (s.startsWith(',')) s = '0.${s.substring(1)}';
    s = s.replaceAll(',', '.');
    return s;
  }

  Widget _buildVaccinationTag(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withValues(alpha: 0.08),
        border: Border.all(
          color: AppColors.primaryColor.withValues(alpha: 0.30),
        ),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: PoppinsText(
        text: text,
        // Avant : texte GRIS sur contour orange — illisible en mode sombre.
        fontSize: 12.5.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.primaryColor,
      ),
    );
  }

  Widget _buildOwnerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          Icons.person_rounded,
          'pet_detail_owner_information'.tr,
        ),
        SizedBox(height: 12.h),
        PostBlock(
          accent: AppColors.primaryColor,
          background: AppColors.card(context),
          borderColor: AppColors.divider(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.ownerName != null && widget.ownerName!.isNotEmpty)
                PostBullet(
                  icon: Icons.person_rounded,
                  accent: AppColors.primaryColor,
                  label: 'pet_detail_owner_name'.tr,
                  value: widget.ownerName!,
                ),
              // v22.1 — Bug 11c : ville propriétaire affichée pour donner du
              // contexte au sitter (savoir d'où vient l'animal).
              if (widget.ownerCity != null && widget.ownerCity!.isNotEmpty)
                PostBullet(
                  icon: Icons.location_on_rounded,
                  accent: AppColors.primaryColor,
                  label: 'pet_detail_owner_city'.tr,
                  value: widget.ownerCity!,
                ),
              if (widget.ownerCreatedAt != null &&
                  widget.ownerCreatedAt!.isNotEmpty)
                PostBullet(
                  icon: Icons.event_available_rounded,
                  accent: AppColors.primaryColor,
                  label: 'pet_detail_owner_created_at'.tr,
                  value: _formatDate(widget.ownerCreatedAt!),
                ),
              if (widget.ownerUpdatedAt != null &&
                  widget.ownerUpdatedAt!.isNotEmpty)
                PostBullet(
                  icon: Icons.update_rounded,
                  accent: AppColors.primaryColor,
                  label: 'pet_detail_owner_updated_at'.tr,
                  value: _formatDate(widget.ownerUpdatedAt!),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// v569 — date + heure dans la langue de l'app (avant : « 4/9/2026 9:5 »).
  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate).toLocal();
      final lang = Get.locale?.toLanguageTag();
      return '${DateFormat.yMMMd(lang).format(date)} '
          '${DateFormat.Hm(lang).format(date)}';
    } catch (_) {
      return isoDate;
    }
  }

  Widget _buildImageSlider() {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: (index) {
        setState(() {
          _currentPage = index;
        });
      },
      itemCount: widget.petImages.length,
      itemBuilder: (context, index) {
        final imageUrl = widget.petImages[index];
        final isNetworkImage =
            imageUrl.startsWith('http://') || imageUrl.startsWith('https://');

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(color: AppColors.lightGrey),
          child: isNetworkImage
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: AppColors.lightGrey,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: AppColors.lightGrey,
                    child: Center(
                      child: Image.asset(
                        AppImages.placeholderImage,
                        width: 60.w,
                        height: 60.h,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                )
              : Image.asset(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.lightGrey,
                    child: Center(
                      child: Image.asset(
                        AppImages.placeholderImage,
                        width: 60.w,
                        height: 60.h,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildSingleImage(String imageUrl) {
    final isNetworkImage =
        imageUrl.startsWith('http://') || imageUrl.startsWith('https://');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: AppColors.lightGrey),
      child: isNetworkImage
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: AppColors.lightGrey,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryColor,
                    ),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: AppColors.lightGrey,
                child: Center(
                  child: Image.asset(
                    AppImages.placeholderImage,
                    width: 60.w,
                    height: 60.h,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            )
          : Image.asset(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: AppColors.lightGrey,
                child: Center(
                  child: Image.asset(
                    AppImages.placeholderImage,
                    width: 60.w,
                    height: 60.h,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildPageIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.petImages.length,
        (index) => Container(
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          width: _currentPage == index ? 24.w : 8.w,
          height: 8.h,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? AppColors.primaryColor
                : AppColors.whiteColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),
      ),
    );
  }
}
