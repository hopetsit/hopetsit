// v23.1 part 105 — Daniel : "Chat traduire selon langue profil".
// Petit bouton "Traduire" sous chaque message reçu dans le chat. Au tap,
// appelle POST /translate et affiche le texte traduit en dessous du
// message original (en italique grisé). Re-tap = on cache la traduction.
//
// Usage :
//   TranslateMessageButton(
//     text: message.message,
//     targetLang: Get.locale?.languageCode ?? 'fr',
//   )
//
// Le widget est self-contained : il gère son propre state (texte traduit,
// loading, erreur) et n'a pas besoin que le ChatMessage model expose un
// champ "translation".

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/repositories/chat_repository.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/utils/app_colors.dart';

class TranslateMessageButton extends StatefulWidget {
  const TranslateMessageButton({
    super.key,
    required this.text,
    required this.targetLang,
    this.leftPadding = 0,
  });

  final String text;
  final String targetLang;
  final double leftPadding;

  @override
  State<TranslateMessageButton> createState() => _TranslateMessageButtonState();
}

class _TranslateMessageButtonState extends State<TranslateMessageButton> {
  String? _translated;
  bool _loading = false;
  String? _error;
  bool _showOriginal = false;

  Future<void> _onTap() async {
    if (_loading) return;
    // Si on a déjà la traduction, on toggle l'affichage.
    if (_translated != null) {
      setState(() => _showOriginal = !_showOriginal);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = Get.find<ChatRepository>();
      final r = await repo.translateMessage(
        text: widget.text,
        targetLang: widget.targetLang,
      );
      final translated = (r['translation'] as String?) ?? widget.text;
      final warning = r['warning'] as String?;
      if (!mounted) return;
      setState(() {
        _translated = translated;
        _showOriginal = false;
        _loading = false;
        // v23.1 part 118 — la clé translation_unavailable existe maintenant
        // dans les 6 langues, on lit direct.
        _error = warning == 'translation_unavailable'
            ? 'translation_unavailable'.tr
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.primaryColor;
    return Padding(
      padding: EdgeInsets.only(left: widget.leftPadding, top: 6.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bouton compact "Traduire" / "Voir l'original" / loader.
          GestureDetector(
            onTap: _onTap,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_loading)
                  SizedBox(
                    width: 12.sp,
                    height: 12.sp,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  )
                else
                  Icon(
                    Icons.translate,
                    size: 14.sp,
                    color: accent,
                  ),
                SizedBox(width: 4.w),
                InterText(
                  // v23.1 part 118 — keys présents dans les 6 langues.
                  text: _loading
                      ? 'translating'.tr
                      : (_translated == null
                          ? 'translate_button'.tr
                          : (_showOriginal
                              ? 'translate_show_translation'.tr
                              : 'translate_show_original'.tr)),
                  fontSize: 12.sp,
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
              ],
            ),
          ),
          // Texte traduit (ou erreur).
          if (_translated != null && !_showOriginal) ...[
            SizedBox(height: 4.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: accent.withOpacity(0.25),
                  width: 1,
                ),
              ),
              child: InterText(
                text: _translated!,
                fontSize: 12.sp,
                color: AppColors.textPrimary(context),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (_error != null) ...[
            SizedBox(height: 4.h),
            InterText(
              text: _error!,
              fontSize: 11.sp,
              color: AppColors.textSecondary(context),
              fontStyle: FontStyle.italic,
            ),
          ],
        ],
      ),
    );
  }

}
