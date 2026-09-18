import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/static/terms_of_service.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';

/// Sprint 8 step 3 — displays the full Terms of Service in the user's language.
///
/// Daniel's request (admin control): this screen now tries to fetch the
/// live Terms document from the backend (`GET /terms/:lang`). If the admin
/// has published a version, we show that; otherwise we fall back to the
/// static text bundled with the APK (so offline / cold-start users still
/// see the standard document).
class TermsAndConditionsScreen extends StatefulWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  State<TermsAndConditionsScreen> createState() =>
      _TermsAndConditionsScreenState();
}

class _TermsAndConditionsScreenState extends State<TermsAndConditionsScreen> {
  String? _remoteContent;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lang = LocalizationService.getCurrentLanguageCode();
    try {
      final api = Get.find<ApiClient>();
      final data = await api.get('/terms/$lang');
      if (data is Map && data['content'] is String &&
          (data['content'] as String).trim().isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _remoteContent = data['content'] as String;
          _loading = false;
        });
        return;
      }
    } catch (e) {
      // Expected 404 when admin hasn't published yet — not an error.
      AppLogger.logUserAction(
        'terms: remote fetch failed, falling back to bundled default',
        data: {'error': e.toString()},
      );
    }
    if (!mounted) return;
    setState(() {
      _remoteContent = null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocalizationService.getCurrentLanguageCode();
    final text = _remoteContent ?? termsOfServiceForLocale(lang);
    // v565 — sous-page modernisée (kit Profil) : chargement, tirer pour
    // rafraîchir, texte dans une carte.
    final accent = currentRoleAccent();
    return ProfileSubPageScaffold(
      title: 'terms_title'.tr,
      accent: accent,
      scroll: false,
      body: _loading
          ? Center(child: CircularProgressIndicator(color: accent))
          : RefreshIndicator(
              color: accent,
              onRefresh: () async {
                setState(() => _loading = true);
                await _load();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 28.h),
                child: Container(
                  padding: EdgeInsets.all(18.w),
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: AppColors.cardShadow(context),
                  ),
                  child: SelectableText(
                    text,
                    style: TextStyle(
                      fontSize: 13.sp,
                      height: 1.5,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
