import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:hopetsit/data/network/api_config.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/data/network/secure_token_store.dart';

/// Sprint 6 step 3 — sitter submits a visit report with photos.
///
/// v565 — kit Profil (humeur en pilules, champs, grille photos avec retrait,
/// bouton du rôle), textes en clés v565_vr_* (9 langues).
class SubmitVisitReportScreen extends StatefulWidget {
  final String bookingId;
  const SubmitVisitReportScreen({super.key, required this.bookingId});

  @override
  State<SubmitVisitReportScreen> createState() =>
      _SubmitVisitReportScreenState();
}

class _SubmitVisitReportScreenState extends State<SubmitVisitReportScreen> {
  final _notesController = TextEditingController();
  final _activitiesController = TextEditingController();
  final _picker = ImagePicker();
  final List<File> _photos = [];
  String _mood = 'calm';
  bool _busy = false;

  Color get _accent => currentRoleAccent();

  @override
  void dispose() {
    _notesController.dispose();
    _activitiesController.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    if (_photos.length >= 10) return;
    final picked = await _picker.pickMultiImage(
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked.isNotEmpty) {
      setState(() {
        for (final x in picked) {
          if (_photos.length < 10) _photos.add(File(x.path));
        }
      });
    }
  }

  // v565 — retirer une photo choisie par erreur (avant : impossible).
  void _removePhoto(File f) => setState(() => _photos.remove(f));

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final token = SecureTokenStore.currentToken() ?? '';
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/bookings/${widget.bookingId}/visit-report'),
      );
      req.headers['Authorization'] = 'Bearer $token';
      req.fields['notes'] = _notesController.text.trim();
      req.fields['mood'] = _mood;
      req.fields['activities'] = _activitiesController.text.trim();
      for (final f in _photos) {
        req.files.add(await http.MultipartFile.fromPath('photos', f.path));
      }
      final resp = await req.send();
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        CustomSnackbar.showSuccess(
          title: 'common_success'.tr,
          message: 'v565_vr_submitted'.tr,
        );
        if (mounted) Get.back();
      } else {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'v565_vr_failed'.trParams({'code': '${resp.statusCode}'}),
        );
      }
    } catch (e) {
      CustomSnackbar.showError(title: 'common_error'.tr, message: e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static const _moods = <String, String>{
    'happy': 'v565_vr_mood_happy',
    'calm': 'v565_vr_mood_calm',
    'anxious': 'v565_vr_mood_anxious',
  };

  @override
  Widget build(BuildContext context) {
    // v565 — kit Profil : humeur en pilules (au lieu d'un menu déroulant),
    // champs du kit, grille de photos avec retrait, bouton du rôle en bas.
    final accent = _accent;
    return ProfileSubPageScaffold(
      title: 'v565_vr_title'.tr,
      accent: accent,
      bottom: ProfilePrimaryButton(
        label: _busy ? 'v565_vr_sending'.tr : 'v565_vr_submit'.tr,
        accent: accent,
        icon: Icons.send_rounded,
        loading: _busy,
        onTap: _busy ? null : _submit,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileSectionTitle('v565_vr_mood'.tr, icon: Icons.mood_rounded),
          Row(
            children: [
              for (final entry in _moods.entries) ...[
                Expanded(
                  child: _moodChip(entry.key, entry.value.tr, accent),
                ),
                if (entry.key != _moods.keys.last) SizedBox(width: 8.w),
              ],
            ],
          ),
          ProfileSectionTitle('v565_vr_notes'.tr, icon: Icons.notes_rounded),
          ProfileInput(
            label: '',
            controller: _notesController,
            accent: accent,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            enabled: !_busy,
          ),
          SizedBox(height: 12.h),
          ProfileInput(
            label: 'v565_vr_activities'.tr,
            controller: _activitiesController,
            accent: accent,
            textCapitalization: TextCapitalization.sentences,
            enabled: !_busy,
          ),
          ProfileSectionTitle(
            'v565_pay_vr_photos'.trParams({'count': _photos.length.toString()}),
            icon: Icons.photo_library_rounded,
          ),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              for (final f in _photos)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14.r),
                      child: Image.file(f, width: 84.w, height: 84.w, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: _busy ? null : () => _removePhoto(f),
                        child: Container(
                          width: 22.w,
                          height: 22.w,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close_rounded, size: 14.sp, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              if (_photos.length < 10)
                InkWell(
                  onTap: _busy ? null : _pick,
                  borderRadius: BorderRadius.circular(14.r),
                  child: Container(
                    width: 84.w,
                    height: 84.w,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      border: Border.all(color: accent.withValues(alpha: 0.35)),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_rounded, color: accent, size: 22.sp),
                        SizedBox(height: 4.h),
                        InterText(
                          text: 'v565_pay_vr_add_photo'.tr,
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.w600,
                          color: accent,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }

  Widget _moodChip(String value, String label, Color accent) {
    final selected = _mood == value;
    return GestureDetector(
      onTap: _busy ? null : () => setState(() => _mood = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 6.w),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.12) : AppColors.card(context),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: selected ? accent : AppColors.divider(context),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Center(
          child: InterText(
            text: label,
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w700,
            color: selected ? accent : AppColors.textPrimary(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
