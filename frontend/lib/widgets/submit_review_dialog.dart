import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// Sprint 7 step 4 — compact "Leave a review" dialog (mutual).
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
      builder: (_) => SubmitReviewDialog(revieweeId: revieweeId, bookingId: bookingId),
    );
    return result ?? false;
  }

  @override
  State<SubmitReviewDialog> createState() => _SubmitReviewDialogState();
}

class _SubmitReviewDialogState extends State<SubmitReviewDialog> {
  final ApiClient _api =
      Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : ApiClient();
  final _controller = TextEditingController();
  int _rating = 5;
  bool _busy = false;

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
      CustomSnackbar.showError(title: 'common_error', message: e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Leave a review',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ),
            SizedBox(height: 20.h),
            Row(
              children: List.generate(5, (i) {
                final starIdx = i + 1;
                return IconButton(
                  icon: Icon(
                    starIdx <= _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                  onPressed: () => setState(() => _rating = starIdx),
                );
              }),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: _controller,
              maxLength: 500,
              maxLines: 4,
              style: TextStyle(color: AppColors.textPrimary(context)),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: AppColors.divider(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: AppColors.divider(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: AppColors.primaryColor),
                ),
                filled: true,
                fillColor: AppColors.inputFill(context),
                hintText: 'Share your experience (optional)',
                hintStyle: TextStyle(color: AppColors.textSecondary(context)),
              ),
            ),
            SizedBox(height: 24.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textSecondary(context)),
                  ),
                ),
                SizedBox(width: 12.w),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: AppColors.whiteColor,
                  ),
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? 'Sending...' : 'Submit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
