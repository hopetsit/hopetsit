import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// Sprint 7 step 4 — compact "Leave a review" dialog (mutual).
///
/// v565 — look modernisé (étoiles grandes + libellé de la note, champ du kit
/// Profil, bouton couleur du rôle), textes en clés (9 langues).
///
/// Usage:
///   await SubmitReviewDialog.show(
///     context: context,
///     revieweeId: booking.sitter.id,
///     bookingId: booking.id,
///   );
class SubmitReviewDialog extends StatefulWidget {
  final String revieweeId;
  final String bookingId;

  const SubmitReviewDialog({
    super.key,
    required this.revieweeId,
    required this.bookingId,
  });

  static Future<bool> show({
    required BuildContext context,
    required String revieweeId,
    required String bookingId,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) =>
          SubmitReviewDialog(revieweeId: revieweeId, bookingId: bookingId),
    );
    return result ?? false;
  }

  @override
  State<SubmitReviewDialog> createState() => _SubmitReviewDialogState();
}

class _SubmitReviewDialogState extends State<SubmitReviewDialog> {
  final ApiClient _api = Get.isRegistered<ApiClient>()
      ? Get.find<ApiClient>()
      : ApiClient();
  final _controller = TextEditingController();
  int _rating = 5;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _api.post(
        '/reviews',
        body: {
          'revieweeId': widget.revieweeId,
          'bookingId': widget.bookingId,
          'rating': _rating,
          'comment': _controller.text.trim(),
        },
        requiresAuth: true,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      CustomSnackbar.showError(title: 'common_error'.tr, message: e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _ratingLabel() => 'v565_rv_star_$_rating'.tr;

  @override
  Widget build(BuildContext context) {
    // v565 — look modernisé : étoiles grandes et animées, libellé de la note,
    // champ du kit Profil, bouton plein couleur du rôle.
    final accent = currentRoleAccent();
    const star = Color(0xFFF4C04A);
    return Dialog(
      backgroundColor: AppColors.card(context),
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(22.w, 22.h, 22.w, 18.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      Icons.rate_review_rounded,
                      color: accent,
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: PoppinsText(
                      text: 'review_leave_title'.tr,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18.h),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    final starIdx = i + 1;
                    final filled = starIdx <= _rating;
                    return GestureDetector(
                      onTap: _busy
                          ? null
                          : () => setState(() => _rating = starIdx),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
                        child: AnimatedScale(
                          scale: filled ? 1.0 : 0.86,
                          duration: const Duration(milliseconds: 160),
                          child: Icon(
                            filled
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 42.sp,
                            color: filled
                                ? star
                                : AppColors.textSecondary(
                                    context,
                                  ).withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              SizedBox(height: 6.h),
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: InterText(
                    key: ValueKey(_rating),
                    text: _ratingLabel(),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              ProfileInput(
                label: '',
                controller: _controller,
                accent: accent,
                hint: 'v565_rv_hint'.tr,
                maxLength: 500,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                enabled: !_busy,
              ),
              SizedBox(height: 18.h),
              ProfilePrimaryButton(
                label: 'review_leave_submit'.tr,
                accent: accent,
                icon: Icons.send_rounded,
                loading: _busy,
                onTap: _busy ? null : _submit,
              ),
              SizedBox(height: 6.h),
              ProfileSecondaryButton(
                label: 'common_cancel'.tr,
                accent: AppColors.textSecondary(context),
                onTap: _busy ? null : () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
