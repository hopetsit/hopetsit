import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/controllers/reviews_controller.dart';
import 'package:hopetsit/views/reviews/widgets/rating_stars.dart' show kRatingStarColor;
import 'package:hopetsit/widgets/paw_pattern_background.dart';

class ReviewsScreen extends StatefulWidget {
  final String serviceProviderName;
  final String phoneNumber;
  final String email;
  final String? profileImagePath;
  final String? serviceProviderId;
  // v18.6 — chaîne de trust pour le submit review :
  // le backend exige une booking completed/paid entre owner et provider.
  // On passe bookingId + revieweeRole pour lever toute ambiguïté
  // sitter vs walker.
  final String? bookingId;
  final String? revieweeRole; // 'sitter' | 'walker'
  // v23.1.291 — note pré-sélectionnée depuis la carte de réservation (l'owner
  // tape une étoile sur la carte → l'écran s'ouvre avec cette note).
  final int initialRating;

  const ReviewsScreen({
    super.key,
    required this.serviceProviderName,
    required this.phoneNumber,
    required this.email,
    this.profileImagePath,
    this.serviceProviderId,
    this.bookingId,
    this.revieweeRole,
    this.initialRating = 0,
  });

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  /// Limite serveur (backend/src/models/Review.js : comment maxlength 500).
  static const int _maxChars = 500;

  late final ReviewsController controller;
  late final TextEditingController descriptionController;

  bool _bootstrapping = true;
  bool _loadFailed = false;
  int? _pressedStar;

  @override
  void initState() {
    super.initState();
    controller = Get.put(ReviewsController());
    descriptionController = TextEditingController();
    // v23.1.290 — charge l'avis existant ; s'il existe, on pré-remplit le champ
    // de texte (le TextField n'est pas lié au Rx, il faut l'alimenter à la main).
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    if (mounted && (!_bootstrapping || _loadFailed)) {
      setState(() {
        _bootstrapping = true;
        _loadFailed = false;
      });
    }
    try {
      await controller.loadExistingReview(widget.bookingId);
      if (!mounted) return;
      if (controller.isEditing.value) {
        descriptionController.text = controller.description.value;
      } else if (widget.initialRating > 0) {
        // Pré-sélection venue de la carte de réservation.
        controller.setRating(widget.initialRating);
      }
    } catch (_) {
      if (mounted) _loadFailed = true;
    }
    if (mounted) {
      setState(() => _bootstrapping = false);
    }
  }

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────

  void _tapStar(int index) {
    controller.setRating(index + 1);
    try {
      HapticFeedback.selectionClick();
    } catch (_) {
      // Pas de moteur haptique.
    }
    setState(() => _pressedStar = index);
    Future.delayed(const Duration(milliseconds: 190), () {
      if (mounted && _pressedStar == index) {
        setState(() => _pressedStar = null);
      }
    });
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    controller.submitReview(
      serviceProviderId: widget.serviceProviderId ?? '',
      serviceProviderName: widget.serviceProviderName,
      bookingId: widget.bookingId,
      revieweeRole: widget.revieweeRole,
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: PoppinsText(
          text: 'reviews_delete_confirm_title'.tr,
          fontSize: 16.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
        content: InterText(
          text: 'reviews_delete_confirm_body'.tr,
          fontSize: 14.sp,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: InterText(
              text: 'common_cancel'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: _mutedGrey,
            ),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: InterText(
              text: 'reviews_delete'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await controller.deleteReview();
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  String? get _roleLabel {
    switch (widget.revieweeRole) {
      case 'sitter':
        return 'ui567_role_sitter'.tr;
      case 'walker':
        return 'ui567_role_walker'.tr;
      default:
        return null;
    }
  }

  /// v573 — `null` quand il n'y a pas de photo. Avant, le repli était
  /// `AssetImage(AppImages.placeholderImage)` : une illustration marketing
  /// présentée comme la photo du prestataire qu'on vient de noter. On affiche
  /// désormais son initiale sur un aplat teinté (voir [_avatarFallback]).
  ImageProvider? _avatarProvider() {
    final path = widget.profileImagePath?.trim() ?? '';
    if (path.startsWith('http')) {
      // v23.1 part 243 round 3 — perf : décodage borné.
      return CachedNetworkImageProvider(path, maxWidth: 240);
    }
    if (path.isNotEmpty) return AssetImage(path);
    return null;
  }

  /// Initiale du prestataire, sinon une silhouette — jamais une image de
  /// catalogue.
  Widget _avatarFallback(BuildContext context) {
    final String name = widget.serviceProviderName.trim();
    final String initial =
        name.isNotEmpty ? name.characters.first.toUpperCase() : '';
    final Color tone = AppColors.accentOn(context, AppColors.primaryColor);
    return Center(
      child: initial.isEmpty
          ? Icon(Icons.person_rounded, size: 34.sp, color: tone)
          : PoppinsText(
              text: initial,
              fontSize: 28.sp,
              fontWeight: FontWeight.w800,
              color: tone,
            ),
    );
  }

  // v571 — audit lisibilité mode sombre : `grey500Color` (#717680) passe
  // inaperçu sur les cartes sombres. Valeur claire conservée à l'identique.
  Color get _mutedGrey => Theme.of(context).brightness == Brightness.dark
      ? AppColors.textSecondaryDark
      : AppColors.grey500Color;

  BoxDecoration _cardDeco(BuildContext context) => BoxDecoration(
    color: AppColors.card(context),
    borderRadius: BorderRadius.circular(18.r),
    border: Border.all(color: AppColors.divider(context), width: 1),
    boxShadow: AppColors.cardShadow(context),
  );

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // ⚠️ Samsung de Daniel : viewPadding.bottom = 0 alors que la barre système
    // couvre le bas de l'écran → repli sur 48 px en Android.
    final double raw = math.max(mq.viewPadding.bottom, mq.padding.bottom);
    final double bottomInset = raw > 0 ? raw : (Platform.isAndroid ? 48.0 : 0.0);

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        leading: const BackButton(),
        title: PoppinsText(
          text: 'reviews_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: PawPatternBackground(
          color: AppColors.activeRoleAccent(),
          child: SafeArea(
        bottom: false,
        child: _bootstrapping
            ? _loadingState()
            : (_loadFailed ? _errorState() : _content(context, bottomInset)),
      ),
        ),
    );
  }

  Widget _loadingState() => Center(
    child: SizedBox(
      width: 30.w,
      height: 30.w,
      child: CircularProgressIndicator(
        strokeWidth: 2.4,
        color: AppColors.primaryColor,
      ),
    ),
  );

  Widget _errorState() => Center(
    child: Padding(
      padding: EdgeInsets.all(28.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 40.sp,
            color: _mutedGrey,
          ),
          SizedBox(height: 12.h),
          InterText(
            text: 'ui567_load_error'.tr,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary(context),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 14.h),
          TextButton(
            onPressed: _loadExisting,
            child: PoppinsText(
              text: 'common_retry'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryColor,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _content(BuildContext context, double bottomInset) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headerCard(context),
                SizedBox(height: 14.h),
                _ratingCard(context),
                SizedBox(height: 14.h),
                _commentCard(context),
                SizedBox(height: 6.h),
                _deleteButton(context),
              ],
            ),
          ),
        ),
        _bottomBar(context, bottomInset),
      ],
    );
  }

  // En-tête : avatar 72 px, nom, rôle, et les lignes contact UNIQUEMENT
  // si la valeur existe (l'icône e-mail orpheline de la capture).
  Widget _headerCard(BuildContext context) {
    final phone = widget.phoneNumber.trim();
    final email = widget.email.trim();
    final role = _roleLabel;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: _cardDeco(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Builder(builder: (context) {
            final ImageProvider? avatar = _avatarProvider();
            return Container(
              width: 72.w,
              height: 72.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: avatar == null
                    ? AppColors.primaryColor.withValues(alpha: 0.12)
                    : null,
                border: Border.all(
                  color: AppColors.primaryColor.withValues(alpha: 0.18),
                  width: 2,
                ),
                image: avatar == null
                    ? null
                    : DecorationImage(image: avatar, fit: BoxFit.cover),
              ),
              child: avatar == null ? _avatarFallback(context) : null,
            );
          }),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PoppinsText(
                  text: widget.serviceProviderName,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (role != null) ...[
                  SizedBox(height: 6.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: InterText(
                      text: role,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryColor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (phone.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  _contactLine(context, Icons.phone_rounded, phone),
                ],
                if (email.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  _contactLine(context, Icons.mail_outline_rounded, email),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactLine(BuildContext context, IconData icon, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15.sp, color: AppColors.primaryColor),
        SizedBox(width: 7.w),
        Expanded(
          child: InterText(
            text: value,
            fontSize: 13.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _ratingCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14.w, 16.h, 14.w, 16.h),
      decoration: _cardDeco(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 4.w),
            child: PoppinsText(
              text: 'reviews_rate_label'.tr,
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
          ),
          SizedBox(height: 8.h),
          // Règle GetX : le .value est lu DIRECTEMENT dans la closure de l'Obx.
          Obx(() {
            final current = controller.rating.value;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List<Widget>.generate(
                5,
                (index) => _star(index, current),
              ),
            );
          }),
          SizedBox(height: 4.h),
          Obx(() {
            final current = controller.rating.value;
            final bool rated = current >= 1 && current <= 5;
            return Padding(
              padding: EdgeInsets.only(left: 4.w),
              child: InterText(
                text: rated
                    ? 'ui567_rating_$current'.tr
                    : 'ui567_rating_hint'.tr,
                fontSize: 13.sp,
                fontWeight: rated ? FontWeight.w700 : FontWeight.w400,
                color: rated
                    ? AppColors.textPrimary(context)
                    : AppColors.textSecondary(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Étoile tactile : cible ≥ 44 px, animation d'échelle au tap.
  /// La couleur est celle du widget partagé `rating_stars.dart`.
  Widget _star(int index, int current) {
    final bool filled = index < current;
    final bool pressed = _pressedStar == index;
    return Semantics(
      button: true,
      label: '${index + 1}',
      child: InkResponse(
        onTap: () => _tapStar(index),
        radius: 26.r,
        child: SizedBox(
          width: 48.w,
          height: 48.w,
          child: Center(
            child: AnimatedScale(
              scale: pressed ? 1.28 : 1.0,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutBack,
              child: Icon(
                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 38.sp,
                color: filled
                    ? kRatingStarColor
                    : _mutedGrey.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _commentCard(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: _cardDeco(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: PoppinsText(
                  text: 'ui567_comment_label'.tr,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8.w),
              Obx(() {
                final length = controller.description.value.characters.length;
                return InterText(
                  text: '$length/$_maxChars',
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: length >= _maxChars
                      ? AppColors.primaryColor
                      : _mutedGrey,
                  maxLines: 1,
                );
              }),
            ],
          ),
          SizedBox(height: 10.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF251A17) : Colors.white,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: AppColors.divider(context), width: 1),
            ),
            child: TextField(
              controller: descriptionController,
              minLines: 5,
              maxLines: 8,
              maxLength: _maxChars,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              cursorColor: AppColors.primaryColor,
              buildCounter:
                  (
                    _, {
                    required int currentLength,
                    required bool isFocused,
                    int? maxLength,
                  }) => null,
              onChanged: controller.setDescription,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'reviews_description_hint'.tr,
                hintStyle: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: _mutedGrey,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                height: 1.4,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // v23.1.290 — « Supprimer mon avis » (mode édition uniquement).
  Widget _deleteButton(BuildContext context) {
    return Obx(() {
      final editing = controller.isEditing.value;
      final loading = controller.isLoading.value;
      if (!editing) return const SizedBox.shrink();
      return Align(
        alignment: Alignment.center,
        child: TextButton.icon(
          onPressed: loading ? null : _confirmDelete,
          icon: Icon(
            Icons.delete_outline_rounded,
            color: Colors.red.withValues(alpha: loading ? 0.4 : 1),
            size: 18.sp,
          ),
          label: InterText(
            text: 'reviews_delete'.tr,
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: Colors.red.withValues(alpha: loading ? 0.4 : 1),
          ),
        ),
      );
    });
  }

  Widget _bottomBar(BuildContext context, double bottomInset) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h + bottomInset),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        border: Border(
          top: BorderSide(color: AppColors.divider(context), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(() {
            final rating = controller.rating.value;
            final text = controller.description.value;
            final bool can = rating > 0 && text.trim().isNotEmpty;
            if (can) return const SizedBox.shrink();
            return Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: InterText(
                text: 'ui567_submit_hint'.tr,
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
                color: _mutedGrey,
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            );
          }),
          Obx(() {
            final rating = controller.rating.value;
            final text = controller.description.value;
            final loading = controller.isLoading.value;
            final editing = controller.isEditing.value;
            final bool enabled =
                rating > 0 && text.trim().isNotEmpty && !loading;
            return _primaryButton(
              context,
              enabled: enabled,
              loading: loading,
              label: loading
                  ? 'reviews_submitting'.tr
                  : (editing ? 'reviews_edit'.tr : 'reviews_submit'.tr),
            );
          }),
        ],
      ),
    );
  }

  Widget _primaryButton(
    BuildContext context, {
    required bool enabled,
    required bool loading,
    required String label,
  }) {
    final radius = BorderRadius.circular(16.r);
    return SizedBox(
      width: double.infinity,
      height: 54.h,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [Color(0xFFD83C28), Color(0xFFC92A12)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: enabled
              ? null
              : _mutedGrey.withValues(alpha: 0.25),
          borderRadius: radius,
          boxShadow: enabled
              ? const [
                  BoxShadow(
                    color: Color(0x33C92A12),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: enabled ? _submit : null,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading) ...[
                    SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 10.w),
                  ],
                  Flexible(
                    child: PoppinsText(
                      text: label,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: enabled || loading
                          ? AppColors.whiteColor
                          : AppColors.whiteColor.withValues(alpha: 0.85),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
}
