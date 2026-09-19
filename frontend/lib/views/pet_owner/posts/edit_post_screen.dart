// v569 — « Modifier mon annonce » remis au format du lot « listes » :
// formulaire en BLOCS (Service · Dates · Description), champ commun de l'app
// (`CustomTextField`), bouton « Enregistrer » collé en bas au-dessus de la
// barre système (`appBottomInset`).
//
// ⚠️ DESIGN UNIQUEMENT : mêmes champs envoyés (`body`, `startDate`,
// `endDate`, `houseSittingVenue`), même `PostRepository.updatePost`, même
// rafraîchissement de `PostsController`, mêmes messages, même `pop(true)`.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/posts_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/repositories/post_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/views/pet_sitter/widgets/post_card_kit.dart';
import 'package:hopetsit/widgets/action_banner_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/custom_text_field.dart';
import 'package:intl/intl.dart';

/// Edit post screen for the post owner.
///
/// Lets the owner tweak the body, the start/end date and the house‑sitting
/// venue ("at my house" / "at your house"). Photos are kept as‑is to avoid
/// re‑uploading the entire post.
class EditPostScreen extends StatefulWidget {
  const EditPostScreen({super.key, required this.post});

  final PostModel post;

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late final TextEditingController _bodyCtrl;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _houseSittingVenue; // 'owners_home' | 'sitters_home' | null
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _bodyCtrl = TextEditingController(text: widget.post.body);
    _startDate = widget.post.startDate;
    _endDate = widget.post.endDate;
    // Not all PostModels expose this; default to null if unsupported.
    _houseSittingVenue = _readHouseVenueSafe(widget.post);
  }

  static String? _readHouseVenueSafe(PostModel post) {
    try {
      // If the field exists on the model it will be returned, otherwise null.
      final dynamic p = post;
      final v = p.houseSittingVenue;
      if (v is String && v.isNotEmpty) return v;
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _save() async {
    if (_bodyCtrl.text.trim().isEmpty) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'edit_post_body_required'.tr,
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final repo = PostRepository(Get.find<ApiClient>());
      await repo.updatePost(
        widget.post.id,
        body: _bodyCtrl.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        houseSittingVenue: _houseSittingVenue,
      );
      if (Get.isRegistered<PostsController>()) {
        await Get.find<PostsController>().refreshPosts();
      }
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'edit_post_saved'.tr,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'edit_post_failed'.tr,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// v569 — la date s'affichait en `j/m/aaaa` brut (table maison). Elle suit
  /// désormais la langue de l'app.
  String _dateLabel(DateTime? d, String placeholderKey) {
    if (d == null) return placeholderKey.tr;
    return DateFormat.yMMMd(Get.locale?.toLanguageTag()).format(d);
  }

  Widget _dateTile({
    required String label,
    required DateTime? value,
    required String placeholderKey,
    required VoidCallback onTap,
  }) {
    final empty = value == null;
    return Material(
      color: AppColors.inputFill(context),
      borderRadius: BorderRadius.circular(PostCardKit.blockRadius.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PostCardKit.blockRadius.r),
        child: Container(
          constraints: BoxConstraints(minHeight: 56.h),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PostCardKit.blockRadius.r),
            border: Border.all(color: AppColors.divider(context)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 16.sp,
                color: AppColors.primaryColor,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InterText(
                      text: label,
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    InterText(
                      text: _dateLabel(value, placeholderKey),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: empty
                          ? AppColors.textSecondary(context)
                          : AppColors.textPrimary(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Option de lieu en PILULE sélectionnable (les `RadioListTile` empilés
  /// débordaient en allemand et en polonais).
  Widget _venueOption(String value, String labelKey, IconData icon) {
    final selected = _houseSittingVenue == value;
    return Material(
      color: selected
          ? AppColors.primaryColor.withValues(alpha: 0.10)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(PostCardKit.pillRadius.r),
      child: InkWell(
        onTap: () => setState(() => _houseSittingVenue = value),
        borderRadius: BorderRadius.circular(PostCardKit.pillRadius.r),
        child: Container(
          constraints: BoxConstraints(minHeight: PostCardKit.tapTarget.w),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PostCardKit.pillRadius.r),
            border: Border.all(
              color: selected
                  ? AppColors.primaryColor.withValues(alpha: 0.45)
                  : AppColors.divider(context),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle_rounded : icon,
                size: 18.sp,
                color: selected
                    ? AppColors.primaryColor
                    : AppColors.textSecondary(context),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: InterText(
                  text: labelKey.tr,
                  fontSize: 12.5.sp,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppColors.primaryColor
                      : AppColors.textPrimary(context),
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
        title: InterText(
          text: 'edit_post_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
              children: [
                // ── Bloc Service ────────────────────────────────────────
                PostBlock(
                  accent: AppColors.primaryColor,
                  title: 'lists569_section_service'.tr,
                  titleIcon: Icons.home_work_rounded,
                  background: AppColors.card(context),
                  borderColor: AppColors.divider(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InterText(
                        text: 'house_sitting_venue_title'.tr,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary(context),
                      ),
                      SizedBox(height: 10.h),
                      _venueOption(
                        'owners_home',
                        'house_sitting_venue_owner_home',
                        Icons.house_rounded,
                      ),
                      SizedBox(height: 8.h),
                      _venueOption(
                        'sitters_home',
                        'house_sitting_venue_sitter_home',
                        Icons.cottage_rounded,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14.h),

                // ── Bloc Dates ──────────────────────────────────────────
                PostBlock(
                  accent: AppColors.primaryColor,
                  title: 'lists569_section_dates'.tr,
                  titleIcon: Icons.event_rounded,
                  background: AppColors.card(context),
                  borderColor: AppColors.divider(context),
                  child: Row(
                    children: [
                      Expanded(
                        child: _dateTile(
                          label: 'edit_post_start_date'.tr,
                          value: _startDate,
                          placeholderKey: 'edit_post_start_date',
                          onTap: _pickStartDate,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: _dateTile(
                          label: 'edit_post_end_date'.tr,
                          value: _endDate,
                          placeholderKey: 'edit_post_end_date',
                          onTap: _pickEndDate,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14.h),

                // ── Bloc Description ────────────────────────────────────
                PostBlock(
                  accent: AppColors.primaryColor,
                  title: 'lists569_section_description'.tr,
                  titleIcon: Icons.notes_rounded,
                  background: AppColors.card(context),
                  borderColor: AppColors.divider(context),
                  child: CustomTextField(
                    controller: _bodyCtrl,
                    labelText: 'edit_post_body_label'.tr,
                    hintText: 'edit_post_body_hint'.tr,
                    maxLines: 6,
                    minLines: 4,
                    maxLength: 2000,
                    radius: 16,
                  ),
                ),
              ],
            ),
          ),

          // ── « Enregistrer » collé en bas, au-dessus de la barre système.
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              16.w,
              10.h,
              16.w,
              10.h + appBottomInset(context),
            ),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              border: Border(
                top: BorderSide(color: AppColors.divider(context)),
              ),
            ),
            child: ActionPillButton(
              label: 'edit_post_save_button'.tr,
              icon: Icons.check_rounded,
              tone: AppColors.primaryColor,
              expand: true,
              busy: _isSaving,
              onPressed: _isSaving ? null : _save,
            ),
          ),
        ],
      ),
    );
  }
}
