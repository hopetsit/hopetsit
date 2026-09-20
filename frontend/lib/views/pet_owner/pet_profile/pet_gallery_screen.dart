import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/pet_model.dart';
import 'package:hopetsit/repositories/pet_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/pet_species_color.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';
import 'package:hopetsit/widgets/photo_viewer_screen.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

/// v428 — écran Galerie dédié de la fiche animal. Grille de photos (+ vidéos),
/// ajout d'une photo / d'une vidéo, suppression d'un média, et « Définir comme
/// principale » (remplace l'avatar en téléversant une nouvelle image — le
/// backend n'expose pas de promotion d'une URL existante en avatar).
///
/// v573 — mise au design des builds 567-571 (logique inchangée) : cartes coins
/// 20 avec icône dans un rond teinté, fond à pattes, boutons du kit en barre
/// collante, dialogue de suppression moderne, visionneuse plein écran commune
/// (`PhotoViewerScreen` : zoom, compteur, glissement entre photos) et images
/// plus légères (choix 1280 px / q80, vignettes décodées à leur taille réelle).
class PetGalleryScreen extends StatefulWidget {
  final PetModel pet;
  final Color? accent;

  const PetGalleryScreen({super.key, required this.pet, this.accent});

  @override
  State<PetGalleryScreen> createState() => _PetGalleryScreenState();
}

class _PetGalleryScreenState extends State<PetGalleryScreen> {
  late PetModel _pet;
  final PetRepository _repo = Get.find<PetRepository>();
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;

  Color get _accent => widget.accent ?? petSpeciesColor(widget.pet.category);

  bool _dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _pet = widget.pet;
  }

  // ── media list helpers ────────────────────────────────────────────────────
  List<_MediaItem> get _photos {
    final List<_MediaItem> out = <_MediaItem>[];
    for (final dynamic p in _pet.photos) {
      if (p is Map && (p['url'] ?? '').toString().isNotEmpty) {
        out.add(_MediaItem(
          url: p['url'].toString(),
          publicId: (p['publicId'] ?? '').toString(),
        ));
      }
    }
    return out;
  }

  List<_MediaItem> get _videos {
    final List<_MediaItem> out = <_MediaItem>[];
    for (final dynamic v in _pet.videos) {
      if (v is Map && (v['url'] ?? '').toString().isNotEmpty) {
        out.add(_MediaItem(
          url: v['url'].toString(),
          publicId: (v['publicId'] ?? '').toString(),
        ));
      }
    }
    return out;
  }

  // ── actions ───────────────────────────────────────────────────────────────
  Future<void> _reload() async {
    try {
      final PetModel fresh = await _repo.getPetById(_pet.id);
      if (mounted) setState(() => _pet = fresh);
    } catch (_) {
      // best-effort reload
    }
  }

  /// Sélecteur commun : 1280 px / q80 (v573 — avant 1600/q85, pour rien).
  Future<XFile?> _pickImage() => _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1280,
        maxHeight: 1280,
      );

  Future<void> _addPhoto() async {
    if (_busy) return;
    // v440 — limite : 20 photos max.
    if (_photos.length >= 20) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'pet_gallery_limit_photos'.tr,
      );
      return;
    }
    try {
      final XFile? image = await _pickImage();
      if (image == null) return;
      setState(() => _busy = true);
      await _repo.uploadPetCreationMedia(
        petId: _pet.id,
        photos: <File>[File(image.path)],
      );
      await _reload();
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'snackbar_text_image_uploaded_successfully'.tr,
      );
    } on ApiException catch (e) {
      CustomSnackbar.showError(title: 'profile_upload_failed'.tr, message: e.message);
    } catch (_) {
      CustomSnackbar.showError(
        title: 'profile_upload_failed'.tr,
        message: 'common_error_generic'.tr,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addVideo() async {
    if (_busy) return;
    // v440 — limite : 5 vidéos max.
    if (_videos.length >= 5) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'pet_gallery_limit_videos'.tr,
      );
      return;
    }
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 2),
      );
      if (video == null) return;
      setState(() => _busy = true);
      await _repo.uploadPetCreationMedia(
        petId: _pet.id,
        videos: <File>[File(video.path)],
      );
      await _reload();
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'snackbar_text_image_uploaded_successfully'.tr,
      );
    } on ApiException catch (e) {
      CustomSnackbar.showError(title: 'profile_upload_failed'.tr, message: e.message);
    } catch (_) {
      CustomSnackbar.showError(
        title: 'profile_upload_failed'.tr,
        message: 'common_error_generic'.tr,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// « Définir comme principale » : téléverse une NOUVELLE image comme avatar
  /// (le backend ne promeut pas une URL de galerie existante).
  Future<void> _setMainPhoto() async {
    if (_busy) return;
    try {
      final XFile? image = await _pickImage();
      if (image == null) return;
      setState(() => _busy = true);
      final String previousUrl = _pet.avatar.url;
      await _repo.uploadPetMedia(petId: _pet.id, imageFile: File(image.path));
      await _reload();
      // v573 — même URL Cloudinary ⇒ l'ancienne image resterait en cache.
      final String newUrl = _pet.avatar.url;
      if (newUrl.isNotEmpty && newUrl == previousUrl) {
        try {
          await CachedNetworkImage.evictFromCache(newUrl);
          PaintingBinding.instance.imageCache
              .evict(CachedNetworkImageProvider(newUrl));
          PaintingBinding.instance.imageCache.clearLiveImages();
        } catch (_) {/* cache indisponible */}
      }
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'snackbar_text_image_uploaded_successfully'.tr,
      );
    } on ApiException catch (e) {
      CustomSnackbar.showError(title: 'profile_upload_failed'.tr, message: e.message);
    } catch (_) {
      CustomSnackbar.showError(
        title: 'profile_upload_failed'.tr,
        message: 'common_error_generic'.tr,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteMedia(_MediaItem item, String mediaType) async {
    if (_busy) return;
    final bool confirmed = await _confirmDelete(context);
    if (!confirmed) return;
    if (item.publicId.isEmpty) return;
    try {
      setState(() => _busy = true);
      await _repo.deletePetMedia(
        petId: _pet.id,
        mediaType: mediaType,
        publicId: item.publicId,
      );
      // La vignette supprimée ne doit pas réapparaître depuis le cache.
      try {
        await CachedNetworkImage.evictFromCache(item.url);
      } catch (_) {/* cache indisponible */}
      await _reload();
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'pet_photo_deleted'.tr,
      );
    } on ApiException catch (e) {
      CustomSnackbar.showError(title: 'common_error'.tr, message: e.message);
    } catch (_) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'pet_photo_delete_failed'.tr,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Dialogue de suppression au patron moderne (cf.
  /// `widgets/custom_confirmation_dialog.dart`) : carte coins 22 sur
  /// `AppColors.card`, disque rouge, PoppinsText / InterText, boutons du kit.
  Future<bool> _confirmDelete(BuildContext context) async {
    final bool dark = _dark(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: dark ? 0.62 : 0.38),
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: AppColors.card(ctx),
        insetPadding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 24.h),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.r)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 18.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 56.w,
                height: 56.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.errorColor
                      .withValues(alpha: dark ? 0.22 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline_rounded,
                    size: 28.sp,
                    color: AppColors.accentOn(ctx, AppColors.errorColor)),
              ),
              SizedBox(height: 14.h),
              PoppinsText(
                text: 'pet_photo_delete_title'.tr,
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(ctx),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
              SizedBox(height: 8.h),
              InterText(
                text: 'pet_photo_delete_confirm'.tr,
                fontSize: 13.5.sp,
                height: 1.45,
                color: AppColors.textSecondary(ctx),
                textAlign: TextAlign.center,
                maxLines: 4,
              ),
              SizedBox(height: 20.h),
              CustomButton(
                key: const ValueKey<String>('pet_media_delete_confirm'),
                height: 48.h,
                radius: 14.r,
                title: 'post_action_delete'.tr,
                fontSize: 15.sp,
                bgColor: AppColors.errorColor,
                textColor: Colors.white,
                onTap: () => Navigator.of(ctx).pop(true),
              ),
              SizedBox(height: 10.h),
              CustomButton(
                height: 48.h,
                radius: 14.r,
                title: 'common_cancel'.tr,
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                bgColor:
                    dark ? const Color(0xFF2A2A2A) : const Color(0xFFF1F2F4),
                textColor: AppColors.textPrimary(ctx),
                onTap: () => Navigator.of(ctx).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
    return ok == true;
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final List<_MediaItem> photos = _photos;
    final List<_MediaItem> videos = _videos;
    final Color onAccent = AppColors.accentOn(context, _accent);

    return ProfileSubPageScaffold(
      title: 'pet_gallery_title'.tr,
      accent: _accent,
      scroll: false,
      padding: EdgeInsets.zero,
      // Barre d'actions collante (le kit ajoute déjà le dégagement bas).
      bottom: Row(
        children: <Widget>[
          Expanded(
            child: CustomButton(
              key: const ValueKey<String>('pet_add_photo'),
              height: 48.h,
              radius: 16.r,
              bgColor: _accent,
              onTap: _busy ? null : _addPhoto,
              child: _buttonLabel(context, Icons.add_photo_alternate_rounded,
                  'pet_add_photo'.tr, Colors.white),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: CustomButton(
              key: const ValueKey<String>('pet_add_video'),
              height: 48.h,
              radius: 16.r,
              bgColor: AppColors.card(context),
              borderColor: _accent,
              textColor: onAccent,
              onTap: _busy ? null : _addVideo,
              child: _buttonLabel(
                  context, Icons.videocam_rounded, 'pet_add_video'.tr, onAccent),
            ),
          ),
        ],
      ),
      body: PawPatternBackground(
        color: _accent,
        child: Stack(
          children: <Widget>[
            ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
              children: <Widget>[
                // Photo principale (avatar).
                _card(
                  context,
                  icon: Icons.star_rounded,
                  title: 'pet_set_as_main'.tr,
                  children: <Widget>[
                    CustomButton(
                      key: const ValueKey<String>('pet_set_as_main'),
                      height: 46.h,
                      radius: 14.r,
                      bgColor: AppColors.card(context),
                      borderColor: _accent,
                      textColor: onAccent,
                      onTap: _busy ? null : _setMainPhoto,
                      child: _buttonLabel(context, Icons.photo_camera_rounded,
                          'pet_change_photo'.tr, onAccent),
                    ),
                  ],
                ),

                // Photos.
                if (photos.isEmpty)
                  ProfileEmptyState(
                    icon: Icons.photo_library_outlined,
                    title: 'pet_gallery_empty'.tr,
                    accent: _accent,
                  )
                else
                  _card(
                    context,
                    icon: Icons.photo_library_rounded,
                    title: 'pet_gallery_title'.tr,
                    children: <Widget>[
                      _grid(context, photos, mediaType: 'photo'),
                    ],
                  ),

                // Vidéos.
                if (videos.isNotEmpty)
                  _card(
                    context,
                    icon: Icons.videocam_rounded,
                    title: 'pet_videos_title'.tr,
                    children: <Widget>[
                      _grid(context, videos, mediaType: 'video', isVideo: true),
                    ],
                  ),
              ],
            ),
            if (_busy)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.28),
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 18.w, vertical: 14.h),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(18.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SizedBox(
                            width: 20.w,
                            height: 20.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(_accent),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Flexible(
                            child: InterText(
                              text: 'pawspot_photo_uploading'.tr,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
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

  Widget _grid(BuildContext context, List<_MediaItem> items,
      {required String mediaType, bool isVideo = false}) {
    final MediaQueryData mq = MediaQuery.of(context);
    final int decode =
        (mq.size.width * 0.34 * mq.devicePixelRatio).round().clamp(120, 1200);
    // Liste des URL photo pour la visionneuse (glissement entre les photos).
    final List<String> urls =
        items.map((_MediaItem m) => m.url).toList(growable: false);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8.w,
        crossAxisSpacing: 8.w,
      ),
      itemCount: items.length,
      itemBuilder: (BuildContext context, int i) {
        final _MediaItem item = items[i];
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            GestureDetector(
              onTap: isVideo
                  ? null
                  : () => openPhotoViewer(urls, initialIndex: i),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14.r),
                child: isVideo
                    ? ColoredBox(
                        color: Colors.black87,
                        child: Center(
                          child: Icon(Icons.play_circle_fill_rounded,
                              color: Colors.white, size: 34.sp),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: item.url,
                        fit: BoxFit.cover,
                        memCacheWidth: decode,
                        fadeInDuration: const Duration(milliseconds: 120),
                        placeholder: (_, __) => ColoredBox(
                          color: AppColors.mediaPlaceholder(
                              context, AppColors.lightGreyColor),
                        ),
                        errorWidget: (_, __, ___) => ColoredBox(
                          color: AppColors.mediaPlaceholder(
                              context, AppColors.lightGreyColor),
                          child: Icon(Icons.broken_image_rounded,
                              color: AppColors.textTertiary(context)),
                        ),
                      ),
              ),
            ),
            // Bouton supprimer.
            Positioned(
              top: 4.h,
              right: 4.w,
              child: GestureDetector(
                onTap: _busy ? null : () => _deleteMedia(item, mediaType),
                child: Container(
                  padding: EdgeInsets.all(5.w),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.delete_outline_rounded,
                      color: Colors.white, size: 15.sp),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Carte de section : coins 20, bord fin, icône dans un rond teinté.
  Widget _card(BuildContext context,
      {required IconData icon,
      required String title,
      required List<Widget> children}) {
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
              Expanded(
                child: PoppinsText(
                  text: title,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                  maxLines: 2,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          ...children,
        ],
      ),
    );
  }
}

class _MediaItem {
  final String url;
  final String publicId;
  const _MediaItem({required this.url, required this.publicId});
}
