// v565 — point 2 : feuille « Changer mon e-mail » (3 rôles).
//   1. nouvel e-mail + mot de passe → code envoyé à la nouvelle adresse
//   2. code à 6 chiffres (+ renvoyer) → e-mail remplacé sur les 3 profils
// Renvoie le nouvel e-mail confirmé, ou null si annulé.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/controllers/change_email_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';

Future<String?> showChangeEmailSheet(
  BuildContext context, {
  required Color accent,
  required String currentEmail,
}) {
  return showProfileSheet<String>(
    context,
    builder: (ctx) => _ChangeEmailSheet(accent: accent, currentEmail: currentEmail),
  );
}

class _ChangeEmailSheet extends StatefulWidget {
  const _ChangeEmailSheet({required this.accent, required this.currentEmail});
  final Color accent;
  final String currentEmail;

  @override
  State<_ChangeEmailSheet> createState() => _ChangeEmailSheetState();
}

class _ChangeEmailSheetState extends State<_ChangeEmailSheet> {
  static const String _tag = 'change_email_sheet';
  late final ChangeEmailController _c;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _c = Get.isRegistered<ChangeEmailController>(tag: _tag)
        ? Get.find<ChangeEmailController>(tag: _tag)
        : Get.put(ChangeEmailController(), tag: _tag);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    try {
      Get.delete<ChangeEmailController>(tag: _tag);
    } catch (_) {/* déjà libéré */}
    super.dispose();
  }

  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus();
    final newEmail = _email.text.trim().toLowerCase();
    if (newEmail == widget.currentEmail.trim().toLowerCase()) {
      _c.error.value = 'change_email_same'.tr;
      return;
    }
    await _c.request(newEmail: newEmail, password: _password.text);
  }

  Future<void> _submitCode() async {
    FocusScope.of(context).unfocus();
    final ok = await _c.confirm(_code.text);
    if (ok) HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
      child: Obx(() {
        final step = _c.step.value;
        final busy = _c.busy.value;
        final err = _c.error.value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ProfileSheetHandle(),
            Row(
              children: [
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Icon(Icons.alternate_email_rounded, color: accent, size: 22.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PoppinsText(
                        text: 'change_email_title'.tr,
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      InterText(
                        text: step == ChangeEmailStep.code
                            ? 'change_email_code_sent'.trParams({'email': _c.pendingEmail.value})
                            : 'change_email_current'.trParams({'email': widget.currentEmail}),
                        fontSize: 12.sp,
                        color: AppColors.textSecondary(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: busy ? null : () => Navigator.of(context).pop(null),
                  icon: Icon(Icons.close_rounded, color: AppColors.textSecondary(context)),
                ),
              ],
            ),
            SizedBox(height: 18.h),
            if (step == ChangeEmailStep.form) ...[
              ProfileInput(
                label: 'change_email_new_label'.tr,
                hint: 'hint_email'.tr,
                controller: _email,
                accent: accent,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofocus: true,
                enabled: !busy,
                onChanged: (_) {
                  if (err.isNotEmpty) _c.error.value = '';
                },
              ),
              SizedBox(height: 14.h),
              ProfileInput(
                label: 'change_email_password_label'.tr,
                hint: 'label_password'.tr,
                controller: _password,
                accent: accent,
                obscure: !_showPassword,
                textInputAction: TextInputAction.done,
                enabled: !busy,
                suffix: IconButton(
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: AppColors.textSecondary(context),
                    size: 20.sp,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              InterText(
                text: 'change_email_help'.tr,
                fontSize: 11.5.sp,
                color: AppColors.textSecondary(context),
                maxLines: 3,
                height: 1.35,
              ),
              if (err.isNotEmpty) _error(context, err),
              SizedBox(height: 16.h),
              ProfilePrimaryButton(
                label: 'change_email_send_code'.tr,
                accent: accent,
                loading: busy,
                onTap: busy ? null : _submitForm,
                icon: Icons.send_rounded,
              ),
            ] else if (step == ChangeEmailStep.code) ...[
              ProfileInput(
                label: 'change_email_code_label'.tr,
                hint: '123456',
                controller: _code,
                accent: accent,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofocus: true,
                enabled: !busy,
                maxLength: 6,
                onChanged: (v) {
                  if (err.isNotEmpty) _c.error.value = '';
                  if (v.length == 6) _submitCode();
                },
              ),
              if (err.isNotEmpty) _error(context, err),
              SizedBox(height: 16.h),
              ProfilePrimaryButton(
                label: 'change_email_confirm'.tr,
                accent: accent,
                loading: busy,
                onTap: busy ? null : _submitCode,
                icon: Icons.check_rounded,
              ),
              SizedBox(height: 6.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: (busy || _c.resending.value || _c.resendCooldown.value > 0)
                        ? null
                        : _c.resend,
                    child: InterText(
                      text: _c.resendCooldown.value > 0
                          ? 'change_email_resend_in'.trParams({'s': '${_c.resendCooldown.value}'})
                          : 'change_email_resend'.tr,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: _c.resendCooldown.value > 0 ? AppColors.textSecondary(context) : accent,
                    ),
                  ),
                  TextButton(
                    onPressed: busy ? null : () => _c.step.value = ChangeEmailStep.form,
                    child: InterText(
                      text: 'change_email_edit_address'.tr,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Container(
                padding: EdgeInsets.all(18.w),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56.w,
                      height: 56.w,
                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                      child: Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 28.sp),
                    ),
                    SizedBox(height: 12.h),
                    PoppinsText(
                      text: 'change_email_done_title'.tr,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 6.h),
                    InterText(
                      text: 'change_email_done_body'.trParams({'email': _c.confirmedEmail.value}),
                      fontSize: 13.sp,
                      color: AppColors.textSecondary(context),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      height: 1.35,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 14.h),
              ProfilePrimaryButton(
                label: 'common_done'.tr,
                accent: accent,
                onTap: () => Navigator.of(context).pop(_c.confirmedEmail.value),
              ),
            ],
          ],
        );
      }),
    );
  }

  Widget _error(BuildContext context, String msg) {
    return Padding(
      padding: EdgeInsets.only(top: 8.h, left: 4.w),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 16.sp, color: AppColors.errorColor),
          SizedBox(width: 6.w),
          Expanded(
            child: InterText(
              text: msg,
              fontSize: 12.sp,
              color: AppColors.errorColor,
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }
}
