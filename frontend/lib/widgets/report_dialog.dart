import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

/// Reusable "Signaler" dialog shared by profile / comment / message / photo
/// report entry points. Presents the standard reason list + free-text details
/// box and POSTs to /reports.
///
/// v569 — DESIGN UNIQUEMENT : même API (`show(...)` renvoie toujours `true`
/// quand le signalement est parti, `false` sinon), même corps de requête,
/// mêmes clés i18n pour les motifs. Nouveau rendu : carte coins 24, disque
/// ambre 56 px, motifs en lignes sélectionnables, champ de détails moderne
/// avec compteur, boutons pleine largeur empilés.
class ReportDialog {
  /// Ambre « attention » — nature du dialogue.
  static const Color _amber = Color(0xFFE8920A);

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
        final bool dark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 24.h),
          child: Container(
            padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 18.h),
            decoration: BoxDecoration(
              color: AppColors.card(ctx),
              borderRadius: BorderRadius.circular(24.r),
              border: dark
                  ? Border.all(color: AppColors.dividerDark, width: 1)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow(dark ? 0.5 : 0.16),
                  blurRadius: 28,
                  spreadRadius: -8,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56.w,
                  height: 56.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _amber.withValues(alpha: dark ? 0.22 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.flag_rounded, color: _amber, size: 28.sp),
                ),
                SizedBox(height: 14.h),
                PoppinsText(
                  text: 'report_dialog_title'.tr,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(ctx),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8.h),
                InterText(
                  text: 'report_dialog_subtitle'.tr,
                  fontSize: 14.sp,
                  height: 1.45,
                  color: AppColors.textSecondary(ctx),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 18.h),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel(ctx, 'misc569_report_reason_label'.tr),
                        SizedBox(height: 8.h),
                        Obx(() {
                          final selected = reason.value;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: reasons.map((r) {
                              return _reasonRow(
                                ctx,
                                label: r.value,
                                isSelected: r.key == selected,
                                onTap: () => reason.value = r.key,
                              );
                            }).toList(),
                          );
                        }),
                        SizedBox(height: 14.h),
                        _fieldLabel(ctx, 'misc569_report_details_label'.tr),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: detailsCtrl,
                          maxLines: 3,
                          maxLength: 500,
                          buildCounter: (
                            _, {
                            required currentLength,
                            required isFocused,
                            required maxLength,
                          }) =>
                              null,
                          style: TextStyle(
                            color: AppColors.textPrimary(ctx),
                            fontSize: 14.sp,
                          ),
                          decoration: InputDecoration(
                            hintText: 'report_dialog_details_hint'.tr,
                            hintStyle: TextStyle(
                              color: AppColors.textSecondary(ctx),
                              fontSize: 13.sp,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 12.h,
                            ),
                            border: _inputBorder(ctx, AppColors.divider(ctx)),
                            enabledBorder:
                                _inputBorder(ctx, AppColors.divider(ctx)),
                            focusedBorder: _inputBorder(ctx, _amber, width: 1.5),
                            filled: true,
                            fillColor: AppColors.inputFill(ctx),
                            isDense: true,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ValueListenableBuilder<TextEditingValue>(
                            valueListenable: detailsCtrl,
                            builder: (_, value, __) => InterText(
                              text: '${value.text.length}/500',
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary(ctx),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 18.h),
                CustomButton(
                  width: double.infinity,
                  height: 50.h,
                  radius: 14.r,
                  title: 'report_submit_button'.tr,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  bgColor: _amber,
                  textColor: AppColors.whiteColor,
                  onTap: () async {
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
                ),
                SizedBox(height: 10.h),
                CustomButton(
                  width: double.infinity,
                  height: 50.h,
                  radius: 14.r,
                  title: 'common_cancel'.tr,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  bgColor: dark
                      ? const Color(0xFF342420)
                      : const Color(0xFFF6F1EF),
                  textColor: AppColors.textPrimary(ctx),
                  onTap: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
    return submitted;
  }

  static OutlineInputBorder _inputBorder(
    BuildContext context,
    Color color, {
    double width = 1,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14.r),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static Widget _fieldLabel(BuildContext context, String text) => InterText(
        text: text,
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary(context),
      );

  static Widget _reasonRow(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
            decoration: BoxDecoration(
              color: isSelected
                  ? _amber.withValues(alpha: 0.10)
                  : AppColors.card(context),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: isSelected ? _amber : AppColors.divider(context),
                width: isSelected ? 1.6 : 1.1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 20.w,
                  height: 20.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? _amber : AppColors.divider(context),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Container(
                          width: 10.w,
                          height: 10.w,
                          decoration: const BoxDecoration(
                            color: _amber,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: InterText(
                    text: label,
                    fontSize: 13.sp,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
