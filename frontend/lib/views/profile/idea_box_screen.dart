// v585 (lot D du chantier du 24/09) — « Une idée ? Un problème ? » (demande
// de Daniel du 25/09, Profil › Aide des 3 rôles) : UNE seule entrée, un choix
// idée / problème, un texte libre, envoi en un appui, petit merci après envoi
// — jamais de réponse automatique qui promet quelque chose.
//
// Passe par le circuit de signalement de bugs DÉJÀ existant côté serveur
// (`POST /bug-reports`) avec l'étiquette `kind: 'idea' | 'problem'` (le
// serveur range « problem » comme un bug). Même formulaire que le tableau de
// bord du site (`website/src/components/FeedbackBox.tsx`). L'admin les voit
// dans la section des signalements avec le filtre « Idées ».
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/paw_button_kit.dart';
import 'package:hopetsit/widgets/paw_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';

class IdeaBoxScreen extends StatefulWidget {
  const IdeaBoxScreen({super.key, this.screen = 'app:profile_help'});

  /// D'où vient l'envoi (« screen » du signalement).
  final String screen;

  @override
  State<IdeaBoxScreen> createState() => _IdeaBoxScreenState();
}

class _IdeaBoxScreenState extends State<IdeaBoxScreen> {
  final TextEditingController _text = TextEditingController();
  String _kind = 'idea'; // 'idea' | 'problem'
  bool _sent = false;

  int get _min => _kind == 'idea' ? 3 : 10;
  bool get _ready => _text.text.trim().length >= _min;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_ready) return;
    final String desc = _text.text.trim();
    String version = '';
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version}+${info.buildNumber}';
    } catch (_) {}
    final String platform = Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'other');
    try {
      final api = Get.find<ApiClient>();
      await api.post(
        '/bug-reports',
        body: {
          'kind': _kind,
          'title': desc.length > 60 ? desc.substring(0, 60) : desc,
          'description': desc,
          'screen': widget.screen,
          'appVersion': version,
          'platform': platform,
        },
        requiresAuth: true,
      );
      if (!mounted) return;
      setState(() {
        _sent = true;
        _text.clear();
      });
    } catch (_) {
      if (!mounted) return;
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'feedback_error'.tr,
      );
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = currentRoleAccent();
    return ProfileSubPageScaffold(
      title: 'feedback_title'.tr,
      accent: accent,
      body: _sent ? _thanks(context, accent) : _form(context, accent),
      bottom: _sent
          ? PawButton(
              label: 'common_close'.tr,
              icon: PawIcon.check,
              color: accent,
              kind: PawButtonKind.secondary,
              onTap: () => Get.back(),
            )
          : PawButton(
              label: 'feedback_send'.tr,
              icon: PawIcon.send,
              color: accent,
              action: PawButtonAction.send,
              enabled: _ready,
              disabledReason: _kind == 'idea'
                  ? 'feedback_too_short_idea'.tr
                  : 'feedback_too_short_problem'.tr,
              onTap: _submit,
            ),
    );
  }

  Widget _form(BuildContext context, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileInfoBanner(
          icon: Icons.lightbulb_rounded,
          accent: accent,
          text: 'feedback_sub'.tr,
        ),
        SizedBox(height: 18.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            PawChoicePill(
              label: 'feedback_kind_idea'.tr,
              icon: PawIcon.bulb,
              color: accent,
              selected: _kind == 'idea',
              onTap: () => setState(() => _kind = 'idea'),
            ),
            PawChoicePill(
              label: 'feedback_kind_problem'.tr,
              icon: PawIcon.wrench,
              color: accent,
              selected: _kind == 'problem',
              onTap: () => setState(() => _kind = 'problem'),
            ),
          ],
        ),
        SizedBox(height: 14.h),
        ProfileInput(
          label: _kind == 'idea' ? 'feedback_kind_idea'.tr : 'feedback_kind_problem'.tr,
          hint: _kind == 'idea'
              ? 'feedback_placeholder_idea'.tr
              : 'feedback_placeholder_problem'.tr,
          controller: _text,
          accent: accent,
          maxLines: 6,
          maxLength: 4000,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }

  Widget _thanks(BuildContext context, Color accent) {
    return Padding(
      padding: EdgeInsets.only(top: 40.h),
      child: Column(
        children: [
          Container(
            width: 84.w,
            height: 84.w,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: PawIconWidget(PawIcon.heart, size: 40.sp, color: accent, fill: accent),
            ),
          ),
          SizedBox(height: 18.h),
          PoppinsText(
            text: 'feedback_thanks'.tr,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            textAlign: TextAlign.center,
            color: AppColors.textPrimary(context),
          ),
        ],
      ),
    );
  }
}
