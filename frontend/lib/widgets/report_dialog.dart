import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// Reusable "Signaler" dialog shared by profile / comment / message / photo
/// report entry points. Presents the standard reason list + free-text details
/// box and POSTs to /reports.
class ReportDialog {
  /// Shows the dialog. Returns true if the report was submitted.
  static Future<bool> show({
    required BuildContext context,
    required String targetType, // profile | comment | message | photo | post | review
    required String targetId,
    String? conversationId,
    String? postId,
    String? photoUrl,
    String? snapshot,
  }) async {
    final reason = RxString('inappropriate');
    final detailsCtrl = TextEditingController();
    bool submitted = false;
    final reasons = <MapEntry<String, String>>[
      MapEntry('spam', 'report_reason_spam'.tr),
      MapEntry('harassment', 'report_reason_harassment'.tr),
      MapEntry('inappropriate', 'report_reason_inappropriate'.tr),
      MapEntry('fraud', 'report_reason_fraud'.tr),
      MapEntry('safety', 'report_reason_safety'.tr),
      MapEntry('other', 'report_reason_other'.tr),
    ];

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.whiteColor,
          title: Text(
            'report_dialog_title'.tr,
            style: const TextStyle(
              color: AppColors.blackColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SizedBox(
            width: 340.w,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'report_dialog_subtitle'.tr,
                  style: const TextStyle(
                    color: AppColors.grey700Color,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 8.h),
                Obx(
                  () => Column(
                    children: reasons.map((r) {
                      return RadioListTile<String>(
                        value: r.key,
                        groupValue: reason.value,
                        onChanged: (v) {
                          if (v != null) reason.value = v;
                        },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppColors.primaryColor,
                        title: Text(
                          r.value,
                          style: const TextStyle(
                            color: AppColors.blackColor,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                TextField(
                  controller: detailsCtrl,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: 'report_dialog_details_hint'.tr,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'common_cancel'.tr,
                style: const TextStyle(color: AppColors.grey700Color),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: AppColors.whiteColor,
              ),
              onPressed: () async {
                try {
                  final api = Get.find<ApiClient>();
                  await api.post(
                    '/reports',
                    requiresAuth: true,
                    body: {
                      'targetType': targetType,
                      'targetId': targetId,
                      'reason': reason.value,
                      'details': detailsCtrl.text.trim(),
                      if (snapshot != null) 'snapshot': snapshot,
                      if (conversationId != null)
                        'conversationId': conversationId,
                      if (postId != null) 'postId': postId,
                      if (photoUrl != null) 'photoUrl': photoUrl,
                    },
                  );
                  submitted = true;
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  CustomSnackbar.showSuccess(
                    title: 'common_success'.tr,
                    message: 'report_submit_success'.tr,
                  );
                } catch (e) {
                  AppLogger.logError('Report submit failed', error: e);
                  CustomSnackbar.showError(
                    title: 'common_error'.tr,
                    message: 'report_submit_failed'.tr,
                  );
                }
              },
              child: Text('report_submit_button'.tr),
            ),
          ],
        );
      },
    );
    return submitted;
  }
}
