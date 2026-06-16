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
import 'package:hopetsit/widgets/app_text.dart';
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
        message: 'snackbar_text_image_uploaded_successfully',
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
        message: 'snackbar_text_image_uploaded_successfully',
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
        message: 'snackbar_text_image_uploaded_successfully',
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

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final photos = _photos;
    final videos = _videos;
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: _accent),
        leading: const BackButton(),
        title: PoppinsText(
          text: 'pet_gallery_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.all(16.w),
            children: [
              // Boutons d'ajout.
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      icon: Icons.add_photo_alternate_rounded,
                      label: 'pet_add_photo'.tr,
                      onTap: _busy ? null : _addPhoto,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _actionButton(
                      icon: Icons.video_call_rounded,
                      label: 'pet_add_video'.tr,
                      onTap: _busy ? null : _addVideo,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              _actionButton(
                icon: Icons.star_rounded,
                label: 'pet_set_as_main'.tr,
                onTap: _busy ? null : _setMainPhoto,
                filled: true,
              ),
              SizedBox(height: 18.h),

              // Photos.
              InterText(
                text: 'pet_gallery_title'.tr,
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
              ),
              SizedBox(height: 12.h),
              if (photos.isEmpty)
                _empty('pet_gallery_empty'.tr)
              else
                _grid(photos, mediaType: 'photo'),

              // Vidéos.
              if (videos.isNotEmpty) ...[
                SizedBox(height: 22.h),
                InterText(
                  text: 'pet_videos_title'.tr,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                ),
                SizedBox(height: 12.h),
                _grid(videos, mediaType: 'video', isVideo: true),
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
            ClipRRect(
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
                          Container(color: AppColors.lightGreyColor),
                      errorWidget: (c, _, __) => Container(
                        color: AppColors.lightGreyColor,
                        child:
                            Icon(Icons.broken_image, color: AppColors.greyColor),
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

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          color: filled
              ? _accent.withValues(alpha: 0.14)
              : _accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: _accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _accent, size: 18.sp),
            SizedBox(width: 8.w),
            Flexible(
              child: InterText(
                text: label,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: _accent,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
}

class _MediaItem {
  final String url;
  final String publicId;
  const _MediaItem({required this.url, required this.publicId});
}
