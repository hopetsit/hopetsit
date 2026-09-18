import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
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
        message: 'common_error_generic'.tr,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _roleColor();
    // v565 — sous-page modernisée (kit Profil) : champs « Apple », bouton bas.
    return ProfileSubPageScaffold(
      title: 'bug_report_title'.tr,
      accent: accent,
      actions: [
        IconButton(
          icon: Icon(Icons.close_rounded, color: accent, size: 24.sp),
          tooltip: 'common_close'.tr,
          onPressed: () => Get.back(),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileInfoBanner(
            icon: Icons.bug_report_rounded,
            accent: accent,
            text: 'bug_report_intro'.tr,
          ),
          SizedBox(height: 20.h),
          ProfileInput(
            label: 'bug_report_subject_label'.tr,
            hint: 'bug_report_subject_hint'.tr,
            controller: _titleCtl,
            accent: accent,
            maxLength: 120,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
          ),
          SizedBox(height: 14.h),
          ProfileInput(
            label: 'bug_report_desc_label'.tr,
            hint: 'bug_report_desc_hint'.tr,
            controller: _descCtl,
            accent: accent,
            maxLines: 8,
            maxLength: 4000,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
      bottom: ProfilePrimaryButton(
        label: _sending ? 'bug_report_sending'.tr : 'bug_report_submit'.tr,
        accent: accent,
        loading: _sending,
        onTap: _sending ? null : _submit,
        icon: Icons.send_rounded,
      ),
    );
  }
}
