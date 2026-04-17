import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/posts_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/repositories/post_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

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
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: ListView(
            children: [
              InterText(
                text: 'edit_post_body_label'.tr,
                fontSize: 13.sp,
                color: AppColors.textSecondary(context),
              ),
              SizedBox(height: 8.h),
              TextField(
                controller: _bodyCtrl,
                maxLines: 5,
                maxLength: 2000,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  hintText: 'edit_post_body_hint'.tr,
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickStartDate,
                      icon: const Icon(Icons.calendar_today),
                      label: InterText(
                        text: _startDate == null
                            ? 'edit_post_start_date'.tr
                            : '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}',
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickEndDate,
                      icon: const Icon(Icons.calendar_today),
                      label: InterText(
                        text: _endDate == null
                            ? 'edit_post_end_date'.tr
                            : '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}',
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              InterText(
                text: 'house_sitting_venue_title'.tr,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
              SizedBox(height: 8.h),
              RadioListTile<String>(
                value: 'owners_home',
                groupValue: _houseSittingVenue,
                onChanged: (v) => setState(() => _houseSittingVenue = v),
                title: InterText(
                  text: 'house_sitting_venue_owner_home'.tr,
                  fontSize: 13.sp,
                ),
              ),
              RadioListTile<String>(
                value: 'sitters_home',
                groupValue: _houseSittingVenue,
                onChanged: (v) => setState(() => _houseSittingVenue = v),
                title: InterText(
                  text: 'house_sitting_venue_sitter_home'.tr,
                  fontSize: 13.sp,
                ),
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : InterText(
                          text: 'edit_post_save_button'.tr,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.whiteColor,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
