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
import 'package:hopetsit/utils/pet_age_format.dart';
import 'package:hopetsit/utils/pet_species_color.dart';
import 'package:hopetsit/views/booking/widgets/booking_ui_kit.dart';
import 'package:hopetsit/views/pet_owner/pet_profile/pet_gallery_screen.dart';
import 'package:hopetsit/views/profile/edit_pet_screen.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';
import 'package:hopetsit/widgets/photo_viewer_screen.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/utils/bottom_inset.dart';

/// Règle « la bannière n'est JAMAIS la photo de l'avatar » (Daniel, v573 :
/// « dans Modifier l'animal, la photo du chien et la bannière c'est la MÊME
/// photo »).
///
/// Renvoie la première photo de galerie DIFFÉRENTE de l'avatar, ou `null`
/// quand il n'y en a aucune — l'appelant dessine alors un bandeau (dégradé de
/// l'espèce + motif de pattes). On ne retombe JAMAIS sur l'avatar, ni sur une
/// image marketing.
///
/// Fonction pure (testée dans `test/pets573_test.dart`) : [photos] est la liste
/// brute du modèle (des `Map` avec une clé `url`).
String? resolvePetBannerUrl(List<dynamic> photos, String avatarUrl) {
  final String avatar = avatarUrl.trim();
  // v573 — on parcourt de la plus RÉCENTE à la plus ancienne : quand le
  // propriétaire choisit une nouvelle bannière (ajoutée en fin de galerie),
  // c'est elle qui s'affiche.
  for (final dynamic p in photos.reversed) {
    if (p is! Map) continue;
    final String url = (p['url'] ?? '').toString().trim();
    if (url.isEmpty) continue;
    if (avatar.isNotEmpty && url == avatar) continue;
    return url;
  }
  return null;
}

/// Même règle, appliquée à un [PetModel].
String? petBannerUrl(PetModel pet) =>
    resolvePetBannerUrl(pet.photos, pet.avatar.url);

/// Toutes les URL de photos de la galerie d'un animal (ordre du serveur).
List<String> petGalleryUrls(PetModel pet) {
  final List<String> out = <String>[];
  for (final dynamic p in pet.photos) {
    if (p is Map && (p['url'] ?? '').toString().trim().isNotEmpty) {
      out.add(p['url'].toString());
    }
  }
  return out;
}

/// v573 — fiche animal du propriétaire, au design des builds 567-571.
///
/// Ce qui a changé par rapport à la v565 (logique métier INCHANGÉE) :
///   · l'écran est un `StatefulWidget` qui porte le `pet` courant : les retours
///     de la galerie / de l'édition et le changement de photo rechargent la
///     fiche EN PLACE (`setState`) au lieu de `Get.off(PetProfileScreen(...))`
///     — plus de clignotement ni de transition de page ;
///   · changement de photo : retour visuel IMMÉDIAT (fichier local + voile +
///     indicateur), image allégée (1280 px / q80), `precacheImage` de la
///     nouvelle URL avant de lâcher l'aperçu local, cache évincé quand l'URL ne
///     change pas, message clair et retour à l'ancienne photo en cas d'erreur ;
///   · en-tête héro (bannière ≠ avatar, grand avatar cerclé de blanc, pastilles
///     espèce / sexe / âge, badge vaccination lisible en sombre), sélecteur
///     d'onglets segmenté FIXE, sections en cartes coins 20 avec icône dans un
///     rond teinté, fond à pattes, barre d'actions collante.
class PetProfileScreen extends StatefulWidget {
  final PetModel pet;
  final Color? accent;
  final bool editable;

  /// v427 — callback Supprimer (menu ••• Modifier / Supprimer).
  /// Null ⇒ option Supprimer masquée.
  final VoidCallback? onDelete;

  const PetProfileScreen({
    super.key,
    required this.pet,
    this.accent,
    this.editable = true,
    this.onDelete,
  });

  @override
  State<PetProfileScreen> createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends State<PetProfileScreen> {
  static const List<String> _tabs = <String>[
    'about',
    'health',
    'habits',
    'gallery',
  ];

  late PetModel _pet;

  /// Photo choisie mais pas encore confirmée par le serveur : elle s'affiche
  /// tout de suite dans l'avatar, sous un voile + indicateur.
  File? _pendingAvatar;
  File? _pendingBanner;
  bool _uploadingBanner = false;
  bool _uploadingAvatar = false;
  String _tab = _tabs.first;

  @override
  void initState() {
    super.initState();
    _pet = widget.pet;
  }

  Color get _accent => widget.accent ?? petSpeciesColor(_pet.category);

  bool get _editable => widget.editable;

  bool get _isUpToDate => _pet.vaccinationStatus == 'up_to_date';

  bool _dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // ── navigation ────────────────────────────────────────────────────────────
  Future<void> _openEdit() async {
    await Get.to(() => EditPetScreen(petId: _pet.id, petData: _pet));
    await _reloadInPlace();
  }

  /// v428 — gestion des médias (photos/vidéos) déléguée à l'écran Galerie.
  Future<void> _openGallery() async {
    await Get.to(() => PetGalleryScreen(pet: _pet, accent: _accent));
    await _reloadInPlace();
  }

  /// v443 puis v573 — au retour de la galerie ou de l'édition, la fiche se
  /// recharge EN PLACE avec le pet frais (avant : `Get.off` d'un nouvel écran,
  /// donc une transition + un clignotement à chaque retour).
  Future<void> _reloadInPlace() async {
    try {
      final PetModel fresh =
          await Get.find<PetRepository>().getPetById(_pet.id);
      if (Get.isRegistered<MyPetsController>()) {
        await Get.find<MyPetsController>().refreshPets();
      }
      // Au retour de « Modifier l'animal », la photo a pu changer : on décode
      // la nouvelle avant de l'afficher → pas de trou gris à la place de
      // l'avatar.
      if (mounted && fresh.avatar.url.isNotEmpty) {
        try {
          await precacheImage(
              CachedNetworkImageProvider(fresh.avatar.url), context);
        } catch (_) {/* best-effort */}
      }
      if (!mounted) return;
      setState(() => _pet = fresh);
    } catch (_) {
      // Rechargement best-effort : on garde la fiche actuelle si l'API échoue.
    }
  }

  // ── photo de profil ───────────────────────────────────────────────────────
  /// v433 — le crayon / « Changer la photo » ouvre le sélecteur de PHOTO DE
  /// PROFIL (pick → upload comme avatar), PAS la galerie.
  ///
  /// v573 — Daniel : « ça charge doucement et mal quand on change de photo ».
  /// Désormais : aperçu local immédiat, image plus légère, préchargement de la
  /// nouvelle URL avant de lâcher l'aperçu, rechargement en place.
  /// v573 — Daniel : « la photo du chien et la bannière, je ne peux pas les
  /// modifier ». La bannière est une photo de la galerie : on en ajoute une
  /// (aperçu local immédiat) et la règle « la plus récente ≠ avatar » l'affiche.
  Future<void> _changeBanner() async {
    if (_uploadingBanner) return;
    if (_pet.photos.length >= 20) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'pet_gallery_limit_photos'.tr,
      );
      return;
    }
    File? picked;
    try {
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image == null) return;
      picked = File(image.path);
    } catch (_) {
      CustomSnackbar.showError(
        title: 'profile_upload_failed'.tr,
        message: 'profile_image_pick_failed'.tr,
      );
      return;
    }
    setState(() {
      _pendingBanner = picked;
      _uploadingBanner = true;
    });
    try {
      await Get.find<PetRepository>().uploadPetCreationMedia(
        petId: _pet.id,
        photos: <File>[picked],
      );
      await _reloadInPlace();
      if (!mounted) return;
      final String? fresh = petBannerUrl(_pet);
      if (fresh != null) {
        try {
          await precacheImage(CachedNetworkImageProvider(fresh), context);
        } catch (_) {/* l'aperçu local reste le temps du chargement */}
      }
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'snackbar_text_image_uploaded_successfully'.tr,
      );
    } on ApiException catch (e) {
      CustomSnackbar.showError(
          title: 'profile_upload_failed'.tr, message: e.message);
    } catch (_) {
      CustomSnackbar.showError(
        title: 'profile_upload_failed'.tr,
        message: 'common_error_generic'.tr,
      );
    } finally {
      if (mounted) {
        setState(() {
          _pendingBanner = null;
          _uploadingBanner = false;
        });
      }
    }
  }

  Future<void> _changeProfilePhoto() async {
    if (_uploadingAvatar) return;
    File? picked;
    try {
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        // v573 — 1600/q85 → 1280/q80 : ~40 % de moins à téléverser, aucune
        // perte visible (l'avatar s'affiche à 100 dp). `uploadPetMedia` envoie
        // le fichier tel quel (multipart), il n'y a pas de 2e compression.
        imageQuality: 80,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (image == null) return;
      picked = File(image.path);
    } catch (_) {
      CustomSnackbar.showError(
        title: 'profile_upload_failed'.tr,
        message: 'profile_image_pick_failed'.tr,
      );
      return;
    }

    final String previousUrl = _pet.avatar.url;
    setState(() {
      _pendingAvatar = picked;
      _uploadingAvatar = true;
    });

    try {
      final PetRepository repo = Get.find<PetRepository>();
      await repo.uploadPetMedia(petId: _pet.id, imageFile: picked);
      final PetModel fresh = await repo.getPetById(_pet.id);
      final String newUrl = fresh.avatar.url;

      if (newUrl.isNotEmpty) {
        // Cloudinary renvoie parfois EXACTEMENT la même URL : sans éviction,
        // l'ancienne image resterait affichée indéfiniment.
        if (newUrl == previousUrl) {
          try {
            await CachedNetworkImage.evictFromCache(newUrl);
            PaintingBinding.instance.imageCache
                .evict(CachedNetworkImageProvider(newUrl));
            PaintingBinding.instance.imageCache.clearLiveImages();
          } catch (_) {/* cache indisponible : on continue */}
        }
        // Préchargement : on ne remplace l'aperçu local par l'URL distante
        // qu'une fois l'image décodée → plus de trou gris.
        if (mounted) {
          try {
            await precacheImage(CachedNetworkImageProvider(newUrl), context);
          } catch (_) {/* best-effort */}
        }
      }

      if (Get.isRegistered<MyPetsController>()) {
        await Get.find<MyPetsController>().refreshPets();
      }
      if (!mounted) return;
      setState(() {
        _pet = fresh;
        _pendingAvatar = null;
        _uploadingAvatar = false;
      });
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'snackbar_text_image_uploaded_successfully'.tr,
      );
    } on ApiException catch (e) {
      _restoreAvatar();
      CustomSnackbar.showError(
        title: 'profile_upload_failed'.tr,
        message: e.message,
      );
    } catch (_) {
      _restoreAvatar();
      CustomSnackbar.showError(
        title: 'profile_upload_failed'.tr,
        message: 'common_error_generic'.tr,
      );
    }
  }

  /// Échec : l'avatar revient à l'ancienne photo.
  void _restoreAvatar() {
    if (!mounted) return;
    setState(() {
      _pendingAvatar = null;
      _uploadingAvatar = false;
    });
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.scaffold(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        iconTheme: IconThemeData(color: _accent),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 20.sp, color: _accent),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        title: PoppinsText(
          text: 'pet_profile_title'.trParams({'name': _pet.petName}),
          fontSize: 17.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
        actions: <Widget>[
          if (_editable)
            PopupMenuButton<String>(
              color: AppColors.card(context),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r)),
              icon: Icon(Icons.more_horiz_rounded, color: _accent, size: 24.sp),
              onSelected: (String v) {
                if (v == 'edit') {
                  _openEdit();
                } else if (v == 'delete') {
                  widget.onDelete?.call();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.edit_outlined, size: 18.sp, color: _accent),
                      SizedBox(width: 10.w),
                      Text('post_action_edit'.tr),
                    ],
                  ),
                ),
                if (widget.onDelete != null)
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.delete_outline_rounded,
                            size: 18.sp, color: AppColors.errorColor),
                        SizedBox(width: 10.w),
                        Text('post_action_delete'.tr),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: PawPatternBackground(
        color: _accent,
        child: Column(
          children: <Widget>[
            _hero(context),
            BookingSegmentedTabs(
              values: _tabs,
              selected: _tab,
              accent: _accent,
              margin: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 6.h),
              label: _tabLabel,
              icon: _tabIcon,
              onSelected: (String v) {
                if (v != _tab) setState(() => _tab = v);
              },
            ),
            Expanded(child: _tabBody(context)),
          ],
        ),
      ),
      bottomNavigationBar: _editable ? _stickyActions(context) : null,
    );
  }

  String _tabLabel(String v) {
    switch (v) {
      case 'health':
        return 'pet_tab_health'.tr;
      case 'habits':
        return 'pet_tab_habits'.tr;
      case 'gallery':
        return 'pet_tab_gallery'.tr;
      default:
        return 'pet_tab_about'.tr;
    }
  }

  IconData _tabIcon(String v) {
    switch (v) {
      case 'health':
        return Icons.favorite_rounded;
      case 'habits':
        return Icons.auto_awesome_rounded;
      case 'gallery':
        return Icons.photo_library_rounded;
      default:
        return Icons.pets_rounded;
    }
  }

  Widget _tabBody(BuildContext context) {
    switch (_tab) {
      case 'health':
        return _healthTab(context);
      case 'habits':
        return _habitsTab(context);
      case 'gallery':
        return _galleryTab(context);
      default:
        return _aboutTab(context);
    }
  }

  /// Barre d'actions collante (dégagement barre système Android inclus).
  Widget _stickyActions(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16.w, 10.h, 16.w, 10.h + appBottomInset(context)),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        border: Border(
          top: BorderSide(color: AppColors.divider(context), width: 1),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: CustomButton(
              key: const ValueKey<String>('pet_profile_change_photo'),
              height: 48.h,
              radius: 16.r,
              bgColor: AppColors.card(context),
              borderColor: _accent,
              textColor: AppColors.accentOn(context, _accent),
              onTap: _uploadingAvatar ? null : _changeProfilePhoto,
              child: _buttonLabel(
                context,
                Icons.photo_camera_rounded,
                'pet_change_photo'.tr,
                AppColors.accentOn(context, _accent),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: CustomButton(
              key: const ValueKey<String>('pet_profile_edit'),
              height: 48.h,
              radius: 16.r,
              bgColor: _accent,
              onTap: _openEdit,
              child: _buttonLabel(
                context,
                Icons.edit_rounded,
                'pet_edit_animal'.tr,
                Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buttonLabel(
          BuildContext context, IconData icon, String label, Color color) =>
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 17.sp, color: color),
            SizedBox(width: 7.w),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: InterText(
                  text: label,
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w700,
                  color: color,
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      );

  // ── HÉRO ──────────────────────────────────────────────────────────────────
  Widget _hero(BuildContext context) {
    final String? banner = petBannerUrl(_pet);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 152.h,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(24.r)),
                  child: _pendingBanner != null
                      ? Image.file(_pendingBanner!, fit: BoxFit.cover)
                      : banner != null
                      ? CachedNetworkImage(
                          imageUrl: banner,
                          fit: BoxFit.cover,
                          // 152 dp de haut, plein écran de large : inutile de
                          // décoder 1600 px.
                          memCacheWidth: _decodeWidth(context, 1.0),
                          fadeInDuration: const Duration(milliseconds: 150),
                          errorWidget: (_, __, ___) => _drawnBanner(context),
                          placeholder: (_, __) => _drawnBanner(context),
                        )
                      : _drawnBanner(context),
                ),
              ),
              if (_editable)
                Positioned(
                  right: 12.w,
                  bottom: 12.h,
                  child: _roundPhotoAction(
                    key: const ValueKey<String>('pet_profile_banner_edit'),
                    busy: _uploadingBanner,
                    onTap: _changeBanner,
                    size: 40.w,
                  ),
                ),
              // Avatar superposé, cerclé de blanc ; un tap change la photo.
              Positioned(
                left: 16.w,
                bottom: -32.h,
                child: GestureDetector(
                  onTap: _editable && !_uploadingAvatar
                      ? _changeProfilePhoto
                      : null,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      _avatar(context),
                      if (_editable)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: IgnorePointer(
                            child: _roundPhotoAction(
                              busy: false,
                              onTap: null,
                              size: 30.w,
                              filled: true,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 40.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Flexible(
                    child: PoppinsText(
                      text: _pet.petName,
                      fontSize: 21.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_isUpToDate) ...<Widget>[
                    SizedBox(width: 8.w),
                    _vaccinationBadge(context),
                  ],
                ],
              ),
              if (_pet.breed.trim().isNotEmpty) ...<Widget>[
                SizedBox(height: 3.h),
                InterText(
                  text: _pet.breed,
                  fontSize: 12.5.sp,
                  color: AppColors.textSecondary(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              SizedBox(height: 8.h),
              _metaPills(context),
            ],
          ),
        ),
        SizedBox(height: 2.h),
      ],
    );
  }

  /// Largeur de décodage bornée : évite de décoder une image de 1600 px pour
  /// une vignette ou un avatar.
  int _decodeWidth(BuildContext context, double fractionOfScreen) {
    final MediaQueryData mq = MediaQuery.of(context);
    final double px = mq.size.width * fractionOfScreen * mq.devicePixelRatio;
    return px.round().clamp(120, 1600);
  }

  /// Bandeau DESSINÉ quand aucune photo de galerie ne diffère de l'avatar :
  /// dégradé à la couleur de l'espèce + motif de pattes. Jamais d'image
  /// marketing (`AppImages.placeholderImage` est interdit ici).
  Widget _drawnBanner(BuildContext context) {
    final bool dark = _dark(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.lerp(_accent, dark ? Colors.black : Colors.white,
                dark ? 0.50 : 0.78)!,
            Color.lerp(_accent, dark ? Colors.black : Colors.white,
                dark ? 0.28 : 0.55)!,
          ],
        ),
      ),
      child: CustomPaint(
        painter: PawPatternPainter(
          color: dark ? Colors.white : Colors.white,
          opacity: dark ? 0.10 : 0.26,
          cell: 74,
        ),
        isComplex: true,
        willChange: false,
        child: const SizedBox.expand(),
      ),
    );
  }

  /// Pastille ronde « appareil photo » (bannière : voile sombre translucide ;
  /// avatar : pleine, à la couleur d'accent).
  Widget _roundPhotoAction({
    Key? key,
    required bool busy,
    required VoidCallback? onTap,
    required double size,
    bool filled = false,
  }) {
    return Material(
      key: key,
      color: filled ? _accent : Colors.black.withValues(alpha: 0.42),
      shape: CircleBorder(
        side: BorderSide(
          color: Colors.white.withValues(alpha: filled ? 1 : 0.55),
          width: filled ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: busy
                ? SizedBox(
                    width: size * 0.45,
                    height: size * 0.45,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(Icons.photo_camera_rounded,
                    size: size * 0.5, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _avatar(BuildContext context) {
    final double size = 88.w;
    final int decode = (size * MediaQuery.of(context).devicePixelRatio)
        .round()
        .clamp(120, 600);
    final String url = _pet.avatar.url;

    Widget inner;
    if (_pendingAvatar != null) {
      inner = Image.file(
        _pendingAvatar!,
        fit: BoxFit.cover,
        width: size,
        height: size,
        cacheWidth: decode,
        errorBuilder: (_, __, ___) => _avatarPlaceholder(context, size),
      );
    } else if (url.isNotEmpty) {
      inner = CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: size,
        height: size,
        memCacheWidth: decode,
        fadeInDuration: const Duration(milliseconds: 120),
        placeholder: (_, __) => _avatarPlaceholder(context, size),
        errorWidget: (_, __, ___) => _avatarPlaceholder(context, size),
      );
    } else {
      inner = _avatarPlaceholder(context, size);
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        shape: BoxShape.circle,
        boxShadow: AppColors.cardShadow(context),
      ),
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              inner,
              if (_uploadingAvatar)
                ColoredBox(
                  color: Colors.black.withValues(alpha: 0.42),
                  child: Center(
                    child: SizedBox(
                      width: 26.w,
                      height: 26.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.6,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarPlaceholder(BuildContext context, double size) => ColoredBox(
        color: _accent.withValues(alpha: _dark(context) ? 0.26 : 0.14),
        child: Center(
          child: Icon(Icons.pets_rounded,
              size: size * 0.42, color: AppColors.accentOn(context, _accent)),
        ),
      );

  /// Pastilles espèce / sexe / âge (+ poids / taille quand ils existent).
  Widget _metaPills(BuildContext context) {
    final String age = petAgeDisplay(_pet.age);
    final String sex = _genderLabel(_pet.gender);
    final List<Widget> pills = <Widget>[
      if (_pet.category.trim().isNotEmpty)
        _pill(context,
            emoji: petSpeciesEmoji(_pet.category),
            label: _speciesLabel(_pet.category)),
      if (sex.isNotEmpty)
        _pill(context,
            icon: _pet.gender == 'female'
                ? Icons.female_rounded
                : Icons.male_rounded,
            label: sex),
      if (age.isNotEmpty)
        _pill(context, icon: Icons.cake_rounded, label: age),
      if (_pet.weight.trim().isNotEmpty)
        _pill(context,
            icon: Icons.monitor_weight_rounded, label: '${_pet.weight} kg'),
      if (_pet.height.trim().isNotEmpty)
        _pill(context,
            icon: Icons.straighten_rounded, label: '${_pet.height} cm'),
    ];
    if (pills.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6.w, runSpacing: 6.h, children: pills);
  }

  Widget _pill(BuildContext context,
      {IconData? icon, String? emoji, required String label}) {
    final Color fg = AppColors.accentOn(context, _accent);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: _dark(context) ? 0.22 : 0.10),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (emoji != null && emoji.isNotEmpty)
            Text(emoji, style: TextStyle(fontSize: 11.sp))
          else if (icon != null)
            Icon(icon, size: 13.sp, color: fg),
          SizedBox(width: 5.w),
          InterText(
            text: label,
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w700,
            color: fg,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  /// Badge vaccination — vert LISIBLE en sombre (`accentOn`).
  Widget _vaccinationBadge(BuildContext context) {
    const Color green = Color(0xFF16A34A);
    final Color fg = AppColors.accentOn(context, green);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: green.withValues(alpha: _dark(context) ? 0.26 : 0.12),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.verified_rounded, size: 13.sp, color: fg),
          SizedBox(width: 4.w),
          InterText(
            text: 'pet_up_to_date'.tr,
            fontSize: 10.5.sp,
            fontWeight: FontWeight.w700,
            color: fg,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  // ── ABOUT ─────────────────────────────────────────────────────────────────
  EdgeInsets get _listPadding =>
      EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 24.h);

  Widget _aboutTab(BuildContext context) {
    final String sexLabel = _genderLabel(_pet.gender);
    final bool hasChar = _pet.characterTraits.isNotEmpty;
    final bool hasCompat = !_pet.compatibilities.isEmpty;
    final List<Widget> cards = <Widget>[
      if (_pet.bio.isNotEmpty)
        _section(context, 'pet_presentation'.tr,
            icon: Icons.favorite_rounded,
            <Widget>[_paragraph(context, _pet.bio)]),
      _section(context, 'pet_characteristics'.tr,
          icon: Icons.straighten_rounded, <Widget>[
        if (_pet.breed.isNotEmpty) _kv(context, 'pet_breed'.tr, _pet.breed),
        if (petAgeDisplay(_pet.age).isNotEmpty)
          _kv(context, 'pet_age'.tr, petAgeDisplay(_pet.age)),
        if (sexLabel.isNotEmpty) _kv(context, 'pet_sex'.tr, sexLabel),
        if (_pet.weight.isNotEmpty)
          _kv(context, 'pet_weight'.tr, '${_pet.weight} kg'),
        if (_pet.height.isNotEmpty)
          _kv(context, 'pet_height'.tr, '${_pet.height} cm'),
        if (_pet.colour.isNotEmpty) _kv(context, 'pet_color'.tr, _pet.colour),
      ]),
      if (hasChar)
        _section(context, 'pet_character_traits'.tr,
            icon: Icons.bolt_rounded,
            <Widget>[
              _chips(context,
                  _pet.characterTraits.map((String t) => 'pet_trait_$t'.tr).toList())
            ]),
      if (hasCompat)
        _section(context, 'pet_compatibilities'.tr, icon: Icons.group_rounded,
            <Widget>[
          if (_pet.compatibilities.withChildren.isNotEmpty)
            _compatRow(context, 'pet_compat_children'.tr,
                _pet.compatibilities.withChildren),
          if (_pet.compatibilities.withDogs.isNotEmpty)
            _compatRow(
                context, 'pet_compat_dogs'.tr, _pet.compatibilities.withDogs),
          if (_pet.compatibilities.withCats.isNotEmpty)
            _compatRow(
                context, 'pet_compat_cats'.tr, _pet.compatibilities.withCats),
          if (_pet.compatibilities.withNac.isNotEmpty)
            _compatRow(
                context, 'pet_compat_nac'.tr, _pet.compatibilities.withNac),
        ]),
      if (_pet.particularities.isNotEmpty)
        _section(context, 'pet_particularities'.tr,
            icon: Icons.star_rounded,
            <Widget>[_chips(context, _pet.particularities)]),
    ];
    if (cards.isEmpty) return _emptyBody('pet_no_info'.tr);
    return ListView(
      key: const PageStorageKey<String>('pet_tab_about'),
      padding: _listPadding,
      children: cards,
    );
  }

  // ── HEALTH ────────────────────────────────────────────────────────────────
  Widget _healthTab(BuildContext context) {
    return ListView(
      key: const PageStorageKey<String>('pet_tab_health'),
      padding: _listPadding,
      children: <Widget>[
        _section(context, 'pet_section_health'.tr,
            icon: Icons.vaccines_rounded,
            trailing: _isUpToDate ? _miniUpToDate(context) : null, <Widget>[
          _kv(context, 'pet_vaccination_status'.tr,
              _vaxLabel(_pet.vaccinationStatus)),
          _yesNoRow(context, 'pet_microchipped'.tr, _pet.microchipped),
          _yesNoRow(context, 'pet_sterilized'.tr, _pet.sterilized),
          ..._pet.vaccinations
              .where((String s) => s.trim().isNotEmpty)
              .map((String v) => _checkRow(context, v)),
        ]),
        if (!_pet.deworming.isEmpty)
          _section(context, 'pet_deworming'.tr,
              icon: Icons.medication_rounded,
              trailing: _miniUpToDate(context), <Widget>[
            if (_pet.deworming.lastDate.isNotEmpty)
              _kv(
                  context,
                  'pet_deworming_last_date'.tr,
                  _pet.deworming.lastDate.length >= 10
                      ? _pet.deworming.lastDate.substring(0, 10)
                      : _pet.deworming.lastDate),
            if (_pet.deworming.frequency.isNotEmpty)
              _kv(context, 'pet_deworming_frequency'.tr,
                  _pet.deworming.frequency),
          ]),
        _section(context, 'pet_current_treatments'.tr,
            icon: Icons.healing_rounded, <Widget>[
          // v445 — Oui/Non propre (pastille verte/grise) + détail si besoin.
          _yesNoRow(context, 'pet_treatment_ongoing'.tr,
              _pet.currentTreatments.trim().isNotEmpty),
          if (_pet.currentTreatments.trim().isNotEmpty) ...<Widget>[
            SizedBox(height: 8.h),
            _paragraph(context, _pet.currentTreatments),
          ],
        ]),
        if (_pet.medicationAllergies.isNotEmpty)
          _section(context, 'my_pets_allergies_label'.tr,
              icon: Icons.warning_amber_rounded,
              <Widget>[
                _paragraph(context, _pet.medicationAllergies, danger: true)
              ]),
        if (_pet.foodRestrictions.isNotEmpty)
          _section(context, 'pet_food_restrictions'.tr,
              icon: Icons.no_food_rounded,
              <Widget>[_paragraph(context, _pet.foodRestrictions)]),
        if (_pet.bloodGroup.isNotEmpty)
          _section(context, 'pet_blood_group'.tr,
              icon: Icons.bloodtype_rounded,
              <Widget>[_paragraph(context, _pet.bloodGroup)]),
        _section(context, 'pet_documents'.tr, icon: Icons.folder_rounded,
            <Widget>[
          // v443 — documents COCHÉS par l'owner (carnet/passeport/vaccination…).
          if (_pet.documentTypes.isEmpty && _pet.passportImage.url.isEmpty)
            InterText(
              text: 'pet_doc_none'.tr,
              fontSize: 12.sp,
              color: AppColors.textSecondary(context),
            )
          else ...<Widget>[
            for (final String d in _pet.documentTypes)
              _docRow(context, 'pet_doc_$d'.tr),
            if (_pet.passportImage.url.isNotEmpty &&
                !_pet.documentTypes.contains('eu_passport'))
              _docRow(context, 'pet_doc_passport'.tr),
          ],
          SizedBox(height: 10.h),
          // v443 — « Ajouter un document » → écran Galerie.
          if (_editable)
            CustomButton(
              key: const ValueKey<String>('pet_doc_upload'),
              height: 44.h,
              radius: 14.r,
              bgColor: AppColors.card(context),
              borderColor: _accent,
              textColor: AppColors.accentOn(context, _accent),
              onTap: _openGallery,
              child: _buttonLabel(context, Icons.upload_file_rounded,
                  'pet_doc_upload'.tr, AppColors.accentOn(context, _accent)),
            ),
          SizedBox(height: 6.h),
          InterText(
            text: 'pet_doc_add_hint'.tr,
            fontSize: 11.sp,
            color: AppColors.textSecondary(context),
          ),
        ]),
        if (!_pet.healthInsurance.isEmpty)
          _section(context, 'pet_health_insurance'.tr,
              icon: Icons.shield_rounded, <Widget>[
            if (_pet.healthInsurance.name.isNotEmpty)
              _kv(context, 'pet_insurance_name'.tr, _pet.healthInsurance.name),
            if (_pet.healthInsurance.number.isNotEmpty)
              _kv(context, 'pet_insurance_number'.tr,
                  _pet.healthInsurance.number),
          ]),
        if (_pet.regularVet.name.isNotEmpty || _pet.regularVet.phone.isNotEmpty)
          _section(context, 'pet_regular_vet'.tr,
              icon: Icons.local_hospital_rounded, <Widget>[
            if (_pet.regularVet.name.isNotEmpty)
              _kv(context, 'pet_vet_name'.tr, _pet.regularVet.name),
            if (_pet.regularVet.address.isNotEmpty)
              _kv(context, 'pet_vet_address'.tr, _pet.regularVet.address),
            if (_pet.regularVet.phone.isNotEmpty)
              _kv(context, 'pet_vet_phone'.tr, _pet.regularVet.phone),
          ]),
        if (_pet.emergencyVet.name.isNotEmpty ||
            _pet.emergencyVet.phone.isNotEmpty)
          _section(context, 'pet_emergency_vet'.tr,
              icon: Icons.emergency_rounded, <Widget>[
            if (_pet.emergencyVet.name.isNotEmpty)
              _kv(context, 'pet_vet_name'.tr, _pet.emergencyVet.name),
            if (_pet.emergencyVet.phone.isNotEmpty)
              _kv(context, 'pet_vet_phone'.tr, _pet.emergencyVet.phone),
          ]),
      ],
    );
  }

  // ── HABITS ────────────────────────────────────────────────────────────────
  Widget _habitsTab(BuildContext context) {
    final PetHabits h = _pet.habits;
    final List<Widget> rows = <Widget>[
      if (h.sleep.isNotEmpty)
        _iconRow(context, Icons.bed_rounded, 'pet_sleep'.tr,
            _sleepLabel(h.sleep)),
      if (h.housetrained.isNotEmpty)
        _iconRow(context, Icons.cleaning_services_rounded,
            'pet_housetrained'.tr, _housetrainedLabel(h.housetrained)),
      if (h.leashBehaviour.isNotEmpty)
        _iconRow(context, Icons.directions_walk_rounded, 'pet_leash'.tr,
            _leashLabel(h.leashBehaviour)),
      if (h.energyLevel.isNotEmpty)
        _iconRow(context, Icons.bolt_rounded, 'pet_energy_level'.tr,
            _energyLabel(h.energyLevel)),
      if (h.fears.isNotEmpty)
        _iconRow(context, Icons.sentiment_dissatisfied_rounded, 'pet_fears'.tr,
            h.fears),
      if (h.preferredActivity.isNotEmpty)
        _iconRow(context, Icons.directions_run_rounded,
            'pet_preferred_activity'.tr, h.preferredActivity),
      if (h.education.isNotEmpty)
        _iconRow(context, Icons.school_rounded, 'pet_education'.tr,
            h.education),
      if (h.aloneTolerance.isNotEmpty)
        _iconRow(context, Icons.home_rounded, 'pet_alone_tolerance'.tr,
            h.aloneTolerance),
      if (h.barking.isNotEmpty)
        _iconRow(context, Icons.campaign_rounded, 'pet_barking'.tr, h.barking),
      if (h.likes.isNotEmpty)
        _iconRow(context, Icons.thumb_up_rounded, 'pet_likes'.tr, h.likes),
      if (h.dislikes.isNotEmpty)
        _iconRow(
            context, Icons.thumb_down_rounded, 'pet_dislikes'.tr, h.dislikes),
      if (h.transport.isNotEmpty)
        _iconRow(context, Icons.directions_car_rounded, 'pet_transport'.tr,
            h.transport),
      if (h.brushing.isNotEmpty)
        _iconRow(context, Icons.brush_rounded, 'pet_brushing'.tr, h.brushing),
      if (h.food.isNotEmpty)
        _iconRow(context, Icons.restaurant_rounded, 'pet_food'.tr, h.food),
      if (h.allowedTreats.isNotEmpty)
        _iconRow(context, Icons.cookie_rounded, 'pet_allowed_treats'.tr,
            h.allowedTreats),
      if (h.favoriteObjects.isNotEmpty)
        _iconRow(context, Icons.toys_rounded, 'pet_favorite_objects'.tr,
            h.favoriteObjects),
      if (h.favoritePlaces.isNotEmpty)
        _iconRow(context, Icons.place_rounded, 'pet_favorite_places'.tr,
            h.favoritePlaces),
      if (h.remarks.isNotEmpty)
        _iconRow(context, Icons.notes_rounded, 'pet_remarks'.tr, h.remarks),
    ];
    final List<String> tags = _pet.habits.tags;
    if (rows.isEmpty && tags.isEmpty) return _emptyBody('pet_no_info'.tr);
    return ListView(
      key: const PageStorageKey<String>('pet_tab_habits'),
      padding: _listPadding,
      children: <Widget>[
        // v443 — habitudes COCHABLES en chips en tête de l'onglet.
        if (tags.isNotEmpty)
          _section(context, 'pet_habits_quick'.tr,
              icon: Icons.bolt_rounded,
              <Widget>[
                _chips(context,
                    tags.map((String t) => 'pet_habit_$t'.tr).toList())
              ]),
        if (rows.isNotEmpty)
          _section(context, 'pet_tab_habits'.tr,
              icon: Icons.auto_awesome_rounded, rows),
      ],
    );
  }

  // ── GALLERY ───────────────────────────────────────────────────────────────
  Widget _galleryTab(BuildContext context) {
    final List<String> urls = petGalleryUrls(_pet);
    return ListView(
      key: const PageStorageKey<String>('pet_tab_gallery'),
      padding: _listPadding,
      children: <Widget>[
        if (urls.isEmpty)
          _empty('pet_gallery_empty'.tr)
        else
          _section(context, 'pet_gallery_title'.tr,
              icon: Icons.photo_library_rounded, <Widget>[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8.w,
                crossAxisSpacing: 8.w,
              ),
              itemCount: urls.length,
              itemBuilder: (BuildContext context, int i) => _thumb(
                context,
                urls[i],
                onTap: () => openPhotoViewer(urls, initialIndex: i),
              ),
            ),
          ]),
        if (_editable) ...<Widget>[
          SizedBox(height: 12.h),
          CustomButton(
            key: const ValueKey<String>('pet_add_photos'),
            height: 48.h,
            radius: 16.r,
            bgColor: AppColors.card(context),
            borderColor: _accent,
            textColor: AppColors.accentOn(context, _accent),
            onTap: _openGallery,
            child: _buttonLabel(context, Icons.add_photo_alternate_rounded,
                'pet_add_photos'.tr, AppColors.accentOn(context, _accent)),
          ),
        ],
      ],
    );
  }

  Widget _thumb(BuildContext context, String url, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.r),
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          // Vignette : ~1/3 de la largeur d'écran.
          memCacheWidth: _decodeWidth(context, 0.34),
          fadeInDuration: const Duration(milliseconds: 120),
          placeholder: (_, __) => ColoredBox(
            color: AppColors.mediaPlaceholder(context, AppColors.lightGreyColor),
          ),
          errorWidget: (_, __, ___) => ColoredBox(
            color: AppColors.mediaPlaceholder(context, AppColors.lightGreyColor),
            child: Icon(Icons.broken_image_rounded,
                color: AppColors.textTertiary(context)),
          ),
        ),
      ),
    );
  }

  // ── briques ───────────────────────────────────────────────────────────────
  /// Carte de section : coins 20, bord fin, ombre douce, icône dans un rond
  /// teinté à la couleur de l'espèce.
  Widget _section(BuildContext context, String title, List<Widget> children,
      {IconData? icon, Widget? trailing}) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 14.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.divider(context), width: 1),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Container(
                  width: 32.w,
                  height: 32.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        _accent.withValues(alpha: _dark(context) ? 0.24 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon,
                      size: 17.sp, color: AppColors.accentOn(context, _accent)),
                ),
                SizedBox(width: 10.w),
              ],
              Expanded(
                child: PoppinsText(
                  text: title,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                  maxLines: 2,
                ),
              ),
              if (trailing != null) ...<Widget>[
                SizedBox(width: 8.w),
                trailing,
              ],
            ],
          ),
          SizedBox(height: 10.h),
          ...children,
        ],
      ),
    );
  }

  Widget _miniUpToDate(BuildContext context) {
    const Color green = Color(0xFF16A34A);
    final Color fg = AppColors.accentOn(context, green);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: green.withValues(alpha: _dark(context) ? 0.26 : 0.12),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: InterText(
        text: 'pet_up_to_date'.tr,
        fontSize: 10.sp,
        fontWeight: FontWeight.w700,
        color: fg,
        maxLines: 1,
      ),
    );
  }

  Widget _checkRow(BuildContext context, String text) => Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Row(
          children: <Widget>[
            Icon(Icons.check_circle_rounded,
                size: 17.sp,
                color: AppColors.accentOn(context, const Color(0xFF16A34A))),
            SizedBox(width: 8.w),
            Expanded(
              child: InterText(
                text: text,
                fontSize: 13.sp,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
      );

  Widget _iconRow(
          BuildContext context, IconData icon, String label, String value) =>
      Padding(
        padding: EdgeInsets.symmetric(vertical: 7.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon,
                size: 17.sp, color: AppColors.accentOn(context, _accent)),
            SizedBox(width: 10.w),
            SizedBox(
              width: 100.w,
              child: InterText(
                text: label,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
                maxLines: 3,
              ),
            ),
            SizedBox(width: 6.w),
            Expanded(
              child: InterText(
                text: value,
                fontSize: 12.sp,
                color: AppColors.textSecondary(context),
              ),
            ),
          ],
        ),
      );

  Widget _compatRow(BuildContext context, String label, String value) {
    final Color base = value == 'compatible'
        ? const Color(0xFF16A34A)
        : value == 'supervised'
            ? const Color(0xFFF59E0B)
            : const Color(0xFFDC2626);
    final Color fg = AppColors.accentOn(context, base);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: Row(
        children: <Widget>[
          Expanded(
            child: InterText(
              text: label,
              fontSize: 13.sp,
              color: AppColors.textPrimary(context),
              maxLines: 2,
            ),
          ),
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: base.withValues(alpha: _dark(context) ? 0.26 : 0.12),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: InterText(
              text: _compatLabel(value),
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: fg,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  /// Ligne « Label : Oui/Non » avec pastille colorée (pucé, stérilisé…).
  Widget _yesNoRow(BuildContext context, String label, bool value) {
    final Color base =
        value ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF);
    final Color fg = AppColors.accentOn(context, base);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: Row(
        children: <Widget>[
          Expanded(
            child: InterText(
              text: label,
              fontSize: 13.sp,
              color: AppColors.textPrimary(context),
              maxLines: 2,
            ),
          ),
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: base.withValues(alpha: _dark(context) ? 0.26 : 0.12),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: InterText(
              text: value ? 'pet_yes'.tr : 'pet_no'.tr,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: fg,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  /// Ligne document (carnet de santé / passeport).
  Widget _docRow(BuildContext context, String label) => Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Row(
          children: <Widget>[
            Icon(Icons.check_circle_rounded,
                size: 17.sp,
                color: AppColors.accentOn(context, const Color(0xFF16A34A))),
            SizedBox(width: 8.w),
            Expanded(
              child: InterText(
                text: label,
                fontSize: 13.sp,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
      );

  Widget _kv(BuildContext context, String label, String value) => Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 118.w,
              child: InterText(
                text: label,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary(context),
                maxLines: 3,
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: InterText(
                text: value,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
      );

  Widget _paragraph(BuildContext context, String text, {bool danger = false}) {
    final bool dark = _dark(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: danger
            ? AppColors.errorColor.withValues(alpha: dark ? 0.18 : 0.08)
            : _accent.withValues(alpha: dark ? 0.14 : 0.07),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: InterText(
        text: text,
        fontSize: 12.sp,
        height: 1.4,
        color: danger
            ? AppColors.accentOn(context, AppColors.errorColor)
            : AppColors.textPrimary(context),
      ),
    );
  }

  Widget _chips(BuildContext context, List<String> items) => Wrap(
        spacing: 6.w,
        runSpacing: 6.h,
        children: items
            .map((String t) => Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: _accent.withValues(
                        alpha: _dark(context) ? 0.20 : 0.10),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                        color: _accent.withValues(alpha: 0.30), width: 1),
                  ),
                  child: InterText(
                    text: t,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentOn(context, _accent),
                  ),
                ))
            .toList(),
      );

  Widget _empty(String text) => ProfileEmptyState(
        icon: Icons.pets_rounded,
        title: text,
        accent: _accent,
      );

  /// État vide qui occupe tout l'onglet (reste défilable pour le pull).
  Widget _emptyBody(String text) => ListView(
        padding: _listPadding,
        children: <Widget>[SizedBox(height: 16.h), _empty(text)],
      );

  // ── libellés ──────────────────────────────────────────────────────────────
  String _speciesLabel(String category) {
    switch (category.trim().toLowerCase()) {
      case 'dog':
        return 'create_pet_category_dog'.tr;
      case 'cat':
        return 'create_pet_category_cat'.tr;
      case 'bird':
        return 'create_pet_category_bird'.tr;
      case 'rabbit':
        return 'create_pet_category_rabbit'.tr;
      case 'other':
        return 'create_pet_category_other'.tr;
      default:
        // Ancienne valeur libre saisie par l'utilisateur : on l'affiche telle
        // quelle plutôt qu'une clé brute.
        return category;
    }
  }

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
      case 'partial':
        return 'pet_vax_partial'.tr;
      case 'late':
        return 'pet_vax_late'.tr;
      case 'unknown':
        return 'pet_vax_unknown'.tr;
      default:
        // Vide ou valeur inconnue ⇒ « Non renseignés » (jamais de clé brute).
        return 'pet_vax_not_provided'.tr;
    }
  }

  String _genderLabel(String g) {
    switch (g) {
      case 'male':
        return 'pet_gender_male'.tr;
      case 'female':
        return 'pet_gender_female'.tr;
      default:
        return '';
    }
  }

  String _sleepLabel(String v) {
    switch (v) {
      case 'indoor':
        return 'pet_sleep_indoor'.tr;
      case 'outdoor':
        return 'pet_sleep_outdoor'.tr;
      case 'crate':
        return 'pet_sleep_crate'.tr;
      default:
        return v;
    }
  }

  String _housetrainedLabel(String v) {
    switch (v) {
      case 'yes':
        return 'pet_housetrained_yes'.tr;
      case 'learning':
        return 'pet_housetrained_learning'.tr;
      default:
        return v;
    }
  }

  String _leashLabel(String v) {
    switch (v) {
      case 'off_leash':
        return 'pet_leash_off'.tr;
      case 'on_leash':
        return 'pet_leash_on'.tr;
      case 'reliable_recall':
        return 'pet_leash_recall'.tr;
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
