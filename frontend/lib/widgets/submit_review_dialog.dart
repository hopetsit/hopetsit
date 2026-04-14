import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
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
    return AlertDialog(
      title: const Text('Leave a review'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          TextField(
            controller: _controller,
            maxLength: 500,
            maxLines: 4,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Share your experience (optional)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Sending...' : 'Submit'),
        ),
      ],
    );
  }
}
