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
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// v428 — écran Galerie dédié de la fiche animal. Grille de photos (+ vidéos),
/// boutons « Ajouter une photo » / « Ajouter une vidéo », suppression d'un
/// média, et « Définir comme principale » (remplace l'avatar en téléversant
/// une nouvelle image — le backend n'expose pas de promotion d'une URL
/// existante en avatar). Réutilise les endpoints média de [PetRepository].
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

  @override
  void initState() {
    super.initState();
    _pet = widget.pet;
  }

  // ── media list helpers ────────────────────────────────────────────────────
  List<_MediaItem> get _photos {
    final out = <_MediaItem>[];
    for (final p in _pet.photos) {
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
    final out = <_MediaItem>[];
    for (final v in _pet.videos) {
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
      final fresh = await _repo.getPetById(_pet.id);
      if (mounted) setState(() => _pet = fresh);
    } catch (_) {
      // best-effort reload
    }
  }

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
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image == null) return;
      setState(() => _busy = true);
      await _repo.uploadPetCreationMedia(
        petId: _pet.id,
        photos: [File(image.path)],
      );
      await _reload();
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'snackbar_text_image_uploaded_successfully'.tr,
      );
    } on ApiException catch (e) {
      CustomSnackbar.showError(title: 'common_error'.tr, message: e.message);
    } catch (_) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
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
        videos: [File(video.path)],
      );
      await _reload();
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'snackbar_text_image_uploaded_successfully'.tr,
      );
    } on ApiException catch (e) {
      CustomSnackbar.showError(title: 'common_error'.tr, message: e.message);
    } catch (_) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'common_error_generic'.tr,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// « Définir comme principale » : téléverse une nouvelle image comme avatar.
  /// Le backend ne permet pas de promouvoir une URL de galerie existante en
  /// avatar, on demande donc une nouvelle sélection (PUT /pets/:id/media,
  /// fileFieldName: 'avatar').
  Future<void> _setMainPhoto() async {
    if (_busy) return;
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image == null) return;
      setState(() => _busy = true);
      await _repo.uploadPetMedia(petId: _pet.id, imageFile: File(image.path));
      await _reload();
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'snackbar_text_image_uploaded_successfully'.tr,
      );
    } on ApiException catch (e) {
      CustomSnackbar.showError(title: 'common_error'.tr, message: e.message);
    } catch (_) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'common_error_generic'.tr,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteMedia(_MediaItem item, String mediaType) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text('pet_photo_delete_title'.tr),
        content: Text('pet_photo_delete_confirm'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common_cancel'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('post_action_delete'.tr,
                style: TextStyle(color: AppColors.errorColor)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (item.publicId.isEmpty) return;
    try {
      setState(() => _busy = true);
      await _repo.deletePetMedia(
        petId: _pet.id,
        mediaType: mediaType,
        publicId: item.publicId,
      );
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

  /// Visionneuse plein écran (tap sur une photo). Zoom via InteractiveViewer.
  void _openFullscreen(String url) {
    Get.to(
      () => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Get.back(),
          ),
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              placeholder: (c, _) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              errorWidget: (c, _, __) => const Icon(
                Icons.broken_image,
                color: Colors.white54,
                size: 48,
              ),
            ),
          ),
        ),
      ),
      transition: Transition.fadeIn,
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final photos = _photos;
    final videos = _videos;
    // v565 — point 39 : kit Profil (barre, boutons du kit, cartes, état vide).
    return ProfileSubPageScaffold(
      title: 'pet_gallery_title'.tr,
      accent: _accent,
      scroll: false,
      padding: EdgeInsets.zero,
      body: Stack(
        children: [
          ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 28.h),
            children: [
              // Boutons d'ajout.
              Row(
                children: [
                  Expanded(
                    child: ProfileSecondaryButton(
                      icon: Icons.add_photo_alternate_rounded,
                      label: 'pet_add_photo'.tr,
                      accent: _accent,
                      onTap: _busy ? null : _addPhoto,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: ProfileSecondaryButton(
                      icon: Icons.video_call_rounded,
                      label: 'pet_add_video'.tr,
                      accent: _accent,
                      onTap: _busy ? null : _addVideo,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              ProfilePrimaryButton(
                icon: Icons.star_rounded,
                label: 'pet_set_as_main'.tr,
                accent: _accent,
                onTap: _busy ? null : _setMainPhoto,
              ),

              // Photos.
              ProfileSectionTitle('pet_gallery_title'.tr,
                  icon: Icons.photo_library_rounded, color: _accent),
              if (photos.isEmpty)
                _empty('pet_gallery_empty'.tr)
              else
                _card(context, _grid(photos, mediaType: 'photo')),

              // Vidéos.
              if (videos.isNotEmpty) ...[
                ProfileSectionTitle('pet_videos_title'.tr,
                    icon: Icons.videocam_rounded, color: _accent),
                _card(context, _grid(videos, mediaType: 'video', isVideo: true)),
              ],
            ],
          ),
          if (_busy)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.25),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_accent),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _grid(List<_MediaItem> items,
      {required String mediaType, bool isVideo = false}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10.w,
        crossAxisSpacing: 10.w,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: isVideo ? null : () => _openFullscreen(item.url),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: isVideo
                    ? Container(
                        color: Colors.black87,
                        child: Center(
                          child: Icon(Icons.play_circle_fill_rounded,
                              color: Colors.white, size: 34.sp),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: item.url,
                        fit: BoxFit.cover,
                        placeholder: (c, _) =>
                            Container(color: AppColors.mediaPlaceholder(context, AppColors.lightGreyColor)),
                        errorWidget: (c, _, __) => Container(
                          color: AppColors.mediaPlaceholder(context, AppColors.lightGreyColor),
                          child: Icon(Icons.broken_image,
                              color: AppColors.greyColor),
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
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.delete_outline_rounded,
                      color: Colors.white, size: 16.sp),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _card(BuildContext context, Widget child) => Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: AppColors.cardShadow(context),
        ),
        child: child,
      );

  Widget _empty(String text) => ProfileEmptyState(
        icon: Icons.photo_library_outlined,
        title: text,
        accent: _accent,
      );
}

class _MediaItem {
  final String url;
  final String publicId;
  const _MediaItem({required this.url, required this.publicId});
}
