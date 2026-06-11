import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hopetsit/controllers/pawspot_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// v23.1.353 — refonte PawSpot (Daniel) : sheets de CRÉATION et de DÉTAIL
/// des spots communautaires de la PawMap. Les clés i18n `pawspot_*`
/// existent déjà dans les 6 langues.

const Color _kGold = Color(0xFFE8A00A);
const Color _kGoldPaw = Color(0xFFFFD700);
const Color _kOrange = Color(0xFFEF4324);
const Color _kViolet = Color(0xFF7C3AED);

/// Ouvre la sheet de création d'un PawSpot. La position du spot est figée au
/// centre de la carte au moment de l'ouverture. Retourne `true` si un spot a
/// été publié (le caller recharge la couche).
Future<bool?> showPawSpotCreateSheet(
  BuildContext context, {
  required PawSpotController controller,
  required LatLng position,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.card(context),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    useSafeArea: true,
    builder: (_) => _PawSpotCreateSheet(
      controller: controller,
      position: position,
    ),
  );
}

/// Ouvre la sheet de détail d'un PawSpot. [onDirections] est appelé après
/// fermeture quand l'utilisateur tape "Itinéraire" (le caller dessine la
/// polyline + appelle visit() en best-effort). [onChanged] est appelé après
/// une mutation (suppression, mise en avant...) pour recharger la couche.
void showPawSpotDetailSheet(
  BuildContext context, {
  required PawSpotModel spot,
  required PawSpotController controller,
  required void Function(PawSpotModel spot) onDirections,
  VoidCallback? onChanged,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card(context),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    useSafeArea: true,
    builder: (_) => _PawSpotDetailSheet(
      spot: spot,
      controller: controller,
      onDirections: onDirections,
      onChanged: onChanged,
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// CRÉATION
// ════════════════════════════════════════════════════════════════════════════

class _PawSpotCreateSheet extends StatefulWidget {
  const _PawSpotCreateSheet({
    required this.controller,
    required this.position,
  });

  final PawSpotController controller;
  final LatLng position;

  @override
  State<_PawSpotCreateSheet> createState() => _PawSpotCreateSheetState();
}

class _PawSpotCreateSheetState extends State<_PawSpotCreateSheet> {
  String? _type;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  String _photoUrl = '';
  bool _uploadingPhoto = false;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_uploadingPhoto) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        imageQuality: 80,
      );
      if (picked == null) return;
      setState(() => _uploadingPhoto = true);
      final url = await widget.controller.uploadPhoto(File(picked.path));
      if (!mounted) return;
      setState(() {
        _uploadingPhoto = false;
        _photoUrl = url ?? '';
      });
      if (url == null) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'pawspot_add_photo'.tr,
        );
      }
    } catch (e) {
      debugPrint('[PawSpot] pickPhoto error: $e');
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _publish() async {
    if (_submitting) return;
    if (_type == null) {
      CustomSnackbar.showWarning(
        title: 'pawspot_add_type_label'.tr,
        message: 'pawspot_add_type_hint'.tr,
      );
      return;
    }
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      CustomSnackbar.showWarning(
        title: 'pawspot_add_name_label'.tr,
        message: 'pawspot_add_name_hint'.tr,
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final earned = await widget.controller.create(
        type: _type!,
        name: name,
        description: _descCtrl.text.trim(),
        photoUrl: _photoUrl,
        lat: widget.position.latitude,
        lng: widget.position.longitude,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      CustomSnackbar.showSuccess(
        title: 'PawSpot 🐾',
        message: 'pawspot_published_msg'.trParams({'points': '$earned'}),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      if (PawSpotController.errorCode(e) == 'PAWSPOT_REQUIRED') {
        Navigator.of(context).pop(false);
        CustomSnackbar.showWarning(
          title: 'pawspot_subscribe_required'.tr,
          message: 'pawspot_limit_reached'.tr,
        );
        Get.to(() => const CoinShopScreen(initialTab: 2));
        return;
      }
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'pawmap_snack_search_failed_msg'.tr,
      );
    }
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 13.sp,
        color: AppColors.greyText,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: AppColors.scaffold(context),
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: InterText(
        text: text,
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Suit le clavier (isScrollControlled) pour que le bouton publier reste
      // visible pendant la saisie.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('🐾', style: TextStyle(fontSize: 24.sp)),
                SizedBox(width: 10.w),
                Expanded(
                  child: PoppinsText(
                    text: 'pawspot_add_title'.tr,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            // Position = centre de la carte au moment de l'ouverture.
            Row(
              children: [
                Icon(Icons.place_rounded, size: 14.sp, color: _kGold),
                SizedBox(width: 4.w),
                InterText(
                  text:
                      '📍 ${widget.position.latitude.toStringAsFixed(5)}, ${widget.position.longitude.toStringAsFixed(5)}',
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(context),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            _label('pawspot_add_type_label'.tr),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              decoration: BoxDecoration(
                color: AppColors.scaffold(context),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _type,
                  isExpanded: true,
                  hint: InterText(
                    text: 'pawspot_add_type_hint'.tr,
                    fontSize: 13.sp,
                    color: AppColors.greyText,
                  ),
                  items: PawSpotTypes.all
                      .map(
                        (t) => DropdownMenuItem<String>(
                          value: t,
                          child: InterText(
                            text: PawSpotTypes.label(t),
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _type = v),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            _label('pawspot_add_name_label'.tr),
            TextField(
              controller: _nameCtrl,
              maxLength: 80,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
              decoration: _fieldDecoration('pawspot_add_name_hint'.tr)
                  .copyWith(counterText: ''),
            ),
            SizedBox(height: 12.h),
            _label('pawspot_add_desc_label'.tr),
            TextField(
              controller: _descCtrl,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              style: TextStyle(
                fontSize: 13.sp,
                color: AppColors.textPrimary(context),
              ),
              decoration: _fieldDecoration('pawspot_add_desc_hint'.tr)
                  .copyWith(counterText: ''),
            ),
            SizedBox(height: 12.h),
            // Photo optionnelle (+5 pts) — upload Cloudinary existant.
            InkWell(
              borderRadius: BorderRadius.circular(12.r),
              onTap: _pickPhoto,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 12.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: _photoUrl.isNotEmpty
                        ? _kGold
                        : AppColors.greyText.withValues(alpha: 0.4),
                    width: 1.3,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_uploadingPhoto)
                      SizedBox(
                        width: 16.w,
                        height: 16.w,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (_photoUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8.r),
                        child: CachedNetworkImage(
                          imageUrl: _photoUrl,
                          width: 36.w,
                          height: 36.w,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Icon(Icons.add_a_photo_outlined,
                          size: 18.sp, color: AppColors.greyText),
                    SizedBox(width: 8.w),
                    InterText(
                      text: 'pawspot_add_photo'.tr,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: _photoUrl.isNotEmpty
                          ? _kGold
                          : AppColors.textSecondary(context),
                    ),
                    if (_photoUrl.isNotEmpty) ...[
                      SizedBox(width: 6.w),
                      Icon(Icons.check_circle_rounded,
                          size: 16.sp, color: _kGold),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: 18.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kOrange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 13.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                onPressed: _submitting ? null : _publish,
                icon: _submitting
                    ? SizedBox(
                        width: 16.w,
                        height: 16.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(Icons.publish_rounded,
                        color: Colors.white, size: 18.sp),
                label: InterText(
                  text: 'pawspot_publish_btn'.tr,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// DÉTAIL
// ════════════════════════════════════════════════════════════════════════════

class _PawSpotDetailSheet extends StatefulWidget {
  const _PawSpotDetailSheet({
    required this.spot,
    required this.controller,
    required this.onDirections,
    this.onChanged,
  });

  final PawSpotModel spot;
  final PawSpotController controller;
  final void Function(PawSpotModel spot) onDirections;
  final VoidCallback? onChanged;

  @override
  State<_PawSpotDetailSheet> createState() => _PawSpotDetailSheetState();
}

class _PawSpotDetailSheetState extends State<_PawSpotDetailSheet> {
  late int _likesCount = widget.spot.likesCount;
  late int _validationsCount = widget.spot.validationsCount;
  bool _liked = false;
  bool _likeBusy = false;
  bool _validateBusy = false;
  List<Map<String, dynamic>> _comments = const [];
  bool _commentsLoading = true;
  final TextEditingController _commentCtrl = TextEditingController();
  bool _sendingComment = false;

  /// Suis-je le créateur du spot ? (profil GetStorage → id)
  bool get _isCreator {
    try {
      final raw = GetStorage().read(StorageKeys.userProfile);
      final myId = raw is Map ? (raw['id'] ?? '').toString() : '';
      return myId.isNotEmpty && myId == widget.spot.creatorId;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    final list = await widget.controller.comments(widget.spot.id);
    if (!mounted) return;
    setState(() {
      _comments = list;
      _commentsLoading = false;
    });
  }

  Future<void> _toggleLike() async {
    if (_likeBusy) return;
    setState(() => _likeBusy = true);
    final r = await widget.controller.like(widget.spot.id);
    if (!mounted) return;
    setState(() {
      _likeBusy = false;
      if (r != null) {
        _liked = r['liked'] == true;
        _likesCount = ((r['likesCount'] as num?) ?? _likesCount).toInt();
      }
    });
  }

  Future<void> _validateSpot() async {
    if (_validateBusy) return;
    setState(() => _validateBusy = true);
    final r = await widget.controller.validate(widget.spot.id);
    if (!mounted) return;
    setState(() {
      _validateBusy = false;
      if (r != null) {
        _validationsCount =
            ((r['validationsCount'] as num?) ?? _validationsCount).toInt();
      }
    });
    if (r != null && r['already'] != true) {
      CustomSnackbar.showSuccess(
        title: 'PawSpot 🐾',
        message: 'pawspot_validate_btn'.tr,
      );
      widget.onChanged?.call();
    }
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _sendingComment) return;
    setState(() => _sendingComment = true);
    final ok = await widget.controller.comment(widget.spot.id, text);
    if (!mounted) return;
    setState(() => _sendingComment = false);
    if (ok) {
      _commentCtrl.clear();
      setState(() => _commentsLoading = true);
      await _loadComments();
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.r),
        ),
        title: InterText(
          text: 'pawspot_delete_confirm'.tr,
          fontSize: 15.sp,
          fontWeight: FontWeight.w700,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common_cancel'.tr),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('common_delete'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await widget.controller.deleteSpot(widget.spot.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    if (ok) {
      CustomSnackbar.showSuccess(
        title: 'PawSpot 🐾',
        message: 'common_delete'.tr,
      );
      widget.onChanged?.call();
    } else {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'pawmap_snack_search_failed_msg'.tr,
      );
    }
  }

  /// Mise en avant 7 j (50 pts) — récompense premium réservée au créateur.
  Future<void> _featureSpot() async {
    try {
      await widget.controller
          .redeemReward('feature_spot', spotId: widget.spot.id);
      if (!mounted) return;
      CustomSnackbar.showSuccess(
        title: 'PawSpot 🐾',
        message: 'pawspot_reward_redeemed'.tr,
      );
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      final code = PawSpotController.errorCode(e);
      if (code == 'INSUFFICIENT_POINTS') {
        CustomSnackbar.showError(
          title: 'pawspot_points_title'.tr,
          message: 'pawspot_reward_feature'.tr,
        );
      } else if (code == 'PAWSPOT_REQUIRED') {
        CustomSnackbar.showWarning(
          title: 'pawspot_subscribe_required'.tr,
          message: 'pawspot_shop_subtitle'.tr,
        );
        Get.to(() => const CoinShopScreen(initialTab: 2));
      } else {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'pawmap_snack_search_failed_msg'.tr,
        );
      }
    }
  }

  Widget _statChip(String emoji, String value, String label) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: AppColors.scaffold(context),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          children: [
            InterText(
              text: '$emoji $value',
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary(context),
            ),
            SizedBox(height: 2.h),
            InterText(
              text: label,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spot = widget.spot;
    final typeColor = PawSpotTypes.color(spot.type);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20.w,
          16.h,
          20.w,
          16.h +
              MediaQuery.of(context).viewPadding.bottom +
              MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Photo (si présente) + badge 🐾 doré en surimpression ─────
            if (spot.photoUrl.isNotEmpty) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16.r),
                    child: CachedNetworkImage(
                      imageUrl: spot.photoUrl,
                      width: double.infinity,
                      height: 160.h,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 160.h,
                        color: AppColors.scaffold(context),
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  if (spot.isGolden)
                    Positioned(
                      top: 8.h,
                      right: 8.w,
                      child: Container(
                        padding: EdgeInsets.all(6.w),
                        decoration: BoxDecoration(
                          color: _kGoldPaw,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text('🐾', style: TextStyle(fontSize: 14.sp)),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 12.h),
            ],
            // ── Nom + chip type ──────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (spot.photoUrl.isEmpty && spot.isGolden) ...[
                  Text('🐾', style: TextStyle(fontSize: 22.sp)),
                  SizedBox(width: 6.w),
                ],
                Expanded(
                  child: PoppinsText(
                    text: spot.name,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8.r),
                    border:
                        Border.all(color: typeColor.withValues(alpha: 0.4)),
                  ),
                  child: InterText(
                    text: PawSpotTypes.label(spot.type),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: typeColor,
                  ),
                ),
              ],
            ),
            if (spot.communityValidated) ...[
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: _kGoldPaw.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: _kGold),
                ),
                child: InterText(
                  text: '🏆 ${'pawspot_validated_badge'.tr}',
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                  color: _kGold,
                ),
              ),
            ],
            SizedBox(height: 6.h),
            InterText(
              text: 'pawspot_added_by'
                  .trParams({'name': spot.creatorName.isNotEmpty ? spot.creatorName : '—'}),
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(context),
            ),
            SizedBox(height: 12.h),
            // ── Stats : ⭐ qualité / 🏆 validations / 👣 visites ──────────
            Row(
              children: [
                _statChip('⭐', spot.quality.toStringAsFixed(1),
                    'pawspot_quality'.tr),
                SizedBox(width: 8.w),
                _statChip('🏆', '$_validationsCount',
                    'pawspot_validations'.tr),
                SizedBox(width: 8.w),
                _statChip('👣', '${spot.visitsCount}', 'pawspot_visits'.tr),
              ],
            ),
            if (spot.description.isNotEmpty) ...[
              SizedBox(height: 12.h),
              InterText(
                text: spot.description,
                fontSize: 13.sp,
                color: AppColors.textPrimary(context),
              ),
            ],
            SizedBox(height: 14.h),
            // ── Actions : ❤️ like / 🏆 valider / itinéraire ──────────────
            Row(
              children: [
                OutlinedButton(
                  onPressed: _toggleLike,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                        horizontal: 12.w, vertical: 10.h),
                    side: BorderSide(
                      color: _liked
                          ? Colors.red
                          : AppColors.greyText.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 16.sp,
                        color: Colors.red,
                      ),
                      SizedBox(width: 4.w),
                      InterText(
                        text: '$_likesCount',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _validateBusy ? null : _validateSpot,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      side: const BorderSide(color: _kGold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: InterText(
                        text: 'pawspot_validate_btn'.tr,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: _kGold,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kViolet,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onDirections(spot);
                    },
                    icon: Icon(Icons.directions_rounded,
                        color: Colors.white, size: 16.sp),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: InterText(
                        text: 'pawspot_directions_btn'.tr,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // ── Boutons créateur : supprimer + mise en avant ─────────────
            if (_isCreator) ...[
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _featureSpot,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                        side: const BorderSide(color: _kGold),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      icon: Icon(Icons.rocket_launch_rounded,
                          size: 15.sp, color: _kGold),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: InterText(
                          text: 'pawspot_reward_feature'.tr,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: _kGold,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  OutlinedButton(
                    onPressed: _confirmDelete,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 10.h),
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Icon(Icons.delete_outline_rounded,
                        size: 16.sp, color: Colors.red),
                  ),
                ],
              ),
            ],
            SizedBox(height: 16.h),
            // ── Commentaires ─────────────────────────────────────────────
            InterText(
              text: 'pawspot_comments_title'.tr,
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary(context),
            ),
            SizedBox(height: 8.h),
            if (_commentsLoading)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              ..._comments.take(5).map(
                    (c) => Padding(
                      padding: EdgeInsets.only(bottom: 8.h),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('💬', style: TextStyle(fontSize: 13.sp)),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InterText(
                                  text: (c['authorName'] ?? '—').toString(),
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textSecondary(context),
                                ),
                                InterText(
                                  text: (c['text'] ?? '').toString(),
                                  fontSize: 12.sp,
                                  color: AppColors.textPrimary(context),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            SizedBox(height: 4.h),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendComment(),
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.textPrimary(context),
                    ),
                    decoration: InputDecoration(
                      hintText: 'pawspot_comment_hint'.tr,
                      hintStyle: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.greyText,
                      ),
                      filled: true,
                      fillColor: AppColors.scaffold(context),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 10.h),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Material(
                  color: _kOrange,
                  borderRadius: BorderRadius.circular(12.r),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12.r),
                    onTap: _sendingComment ? null : _sendComment,
                    child: SizedBox(
                      width: 40.w,
                      height: 40.w,
                      child: _sendingComment
                          ? Padding(
                              padding: EdgeInsets.all(11.w),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(Icons.send_rounded,
                              size: 18.sp, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// v23.1.356 — maquette Daniel : « Voir les spots ». Liste des PawSpots
/// chargés autour du centre courant, avec mes PawPoints en tête (relus à
/// chaque ouverture, pas de cache). Tap sur une ligne → le caller centre la
/// carte et ouvre la sheet détail.
Future<void> showPawSpotListSheet(
  BuildContext context, {
  required PawSpotController controller,
  required void Function(PawSpotModel spot) onOpenSpot,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card(context),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    useSafeArea: true,
    builder: (ctx) {
      final spots = controller.spots.toList();
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.greyText.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Text('🐾', style: TextStyle(fontSize: 20.sp)),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: PoppinsText(
                      text: 'pawspot_list_title'.tr,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(ctx),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              // Mes PawPoints — relus à CHAQUE ouverture ("que ça
              // comptabilise les points", Daniel).
              FutureBuilder<Map<String, dynamic>?>(
                future: controller.myPoints(),
                builder: (c, snap) {
                  final pts = (snap.data?['points'] as num?)?.toInt();
                  final badge = snap.data?['badge'];
                  final badgeEmoji =
                      badge is Map ? (badge['emoji'] ?? '').toString() : '';
                  return Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: _kGold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12.r),
                      border:
                          Border.all(color: _kGold.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emoji_events_rounded,
                            size: 16.sp, color: _kGold),
                        SizedBox(width: 6.w),
                        InterText(
                          text: 'pawmap_my_points_chip'
                              .trParams({'points': pts?.toString() ?? '…'}),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(ctx),
                        ),
                        if (badgeEmoji.isNotEmpty) ...[
                          SizedBox(width: 5.w),
                          Text(badgeEmoji, style: TextStyle(fontSize: 14.sp)),
                        ],
                      ],
                    ),
                  );
                },
              ),
              SizedBox(height: 12.h),
              if (spots.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 28.h),
                  child: Center(
                    child: Column(
                      children: [
                        Text('🐾', style: TextStyle(fontSize: 34.sp)),
                        SizedBox(height: 8.h),
                        InterText(
                          text: 'pawspot_list_empty'.tr,
                          fontSize: 13.sp,
                          color: AppColors.greyText,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: spots.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: AppColors.greyText.withValues(alpha: 0.15),
                    ),
                    itemBuilder: (c, i) {
                      final s = spots[i];
                      final color = PawSpotTypes.color(s.type);
                      return ListTile(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 2.w),
                        leading: Container(
                          width: 38.w,
                          height: 38.w,
                          decoration: BoxDecoration(
                            color: s.isGolden ? _kGoldPaw : color,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 2),
                          ),
                          child: Center(
                            child: Text('🐾',
                                style: TextStyle(fontSize: 16.sp)),
                          ),
                        ),
                        title: InterText(
                          text: s.name,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(ctx),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: InterText(
                          text:
                              '${PawSpotTypes.label(s.type)}  ·  ❤️ ${s.likesCount}'
                              '${s.isGolden ? '  ·  🐾✨' : ''}',
                          fontSize: 12.sp,
                          color: AppColors.greyText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Icon(Icons.chevron_right_rounded,
                            size: 20.sp, color: AppColors.greyText),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          onOpenSpot(s);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
