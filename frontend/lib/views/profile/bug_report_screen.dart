import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io' show Platform;

/// v20.0.8 — In-app "Signaler un bug" screen, accessible from each of the
/// 3 profile menus. Sends a POST /bug-reports which stores the report and
/// emails hopetsit@gmail.com in the background.
class BugReportScreen extends StatefulWidget {
  const BugReportScreen({super.key});

  @override
  State<BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends State<BugReportScreen> {
  final _titleCtl = TextEditingController();
  final _descCtl = TextEditingController();
  bool _sending = false;

  Color _roleColor() {
    try {
      final role = GetStorage().read<String>(StorageKeys.userRole);
      return AppColors.roleAccent(role);
    } catch (_) {
      return AppColors.primaryColor;
    }
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _descCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final desc = _descCtl.text.trim();
    if (desc.length < 10) {
      CustomSnackbar.showError(
        title: 'bug_report_short_title'.tr,
        message: 'bug_report_short_msg'.tr,
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final api = Get.find<ApiClient>();
      String version = '';
      try {
        final info = await PackageInfo.fromPlatform();
        version = '${info.version}+${info.buildNumber}';
      } catch (_) {}
      final platform = Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'other');
      await api.post(
        '/bug-reports',
        body: {
          'title': _titleCtl.text.trim(),
          'description': desc,
          'appVersion': version,
          'platform': platform,
        },
        requiresAuth: true,
      );
      if (!mounted) return;
      CustomSnackbar.showSuccess(
        title: 'bug_report_sent_title'.tr,
        message: 'bug_report_sent_msg'.tr,
      );
      Get.back();
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _roleColor();
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        iconTheme: IconThemeData(color: accent),
        title: PoppinsText(
          text: 'bug_report_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bug_report_rounded, color: accent, size: 22.sp),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        'bug_report_intro'.tr,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              InterText(
                text: 'bug_report_subject_label'.tr,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(context),
              ),
              SizedBox(height: 6.h),
              TextField(
                controller: _titleCtl,
                maxLength: 120,
                decoration: InputDecoration(
                  hintText: 'bug_report_subject_hint'.tr,
                  filled: true,
                  fillColor: AppColors.card(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: AppColors.divider(context)),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              InterText(
                text: 'bug_report_desc_label'.tr,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(context),
              ),
              SizedBox(height: 6.h),
              TextField(
                controller: _descCtl,
                maxLines: 8,
                maxLength: 4000,
                decoration: InputDecoration(
                  hintText: 'bug_report_desc_hint'.tr,
                  filled: true,
                  fillColor: AppColors.card(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: AppColors.divider(context)),
                  ),
                ),
              ),
              SizedBox(height: 18.h),
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton.icon(
                  onPressed: _sending ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    elevation: 3,
                  ),
                  icon: _sending
                      ? SizedBox(
                          width: 18.w,
                          height: 18.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: PoppinsText(
                    text: _sending
                        ? 'bug_report_sending'.tr
                        : 'bug_report_submit'.tr,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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
