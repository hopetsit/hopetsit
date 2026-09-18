// v565 — Daniel : « dans Messages, moderniser le bouton Nouvelle conversation ».
// v566 — Daniel : « améliorer le bouton nouvelle conversation » → plus élégant
// et moins encombrant : bouton flottant ROND de 56 à la couleur du rôle
// (dégradé doux, anneau blanc fin, ombre colorée, icône « nouveau message »)
// qui s'ÉTEND en pilule avec le libellé quand la liste est en haut ou à
// l'arrêt, et se replie en rond pendant le défilement (200 ms). Retour
// haptique. `expanded` est piloté par ChatListBody (ChatSession.newChatExpanded).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/views/chat_shared/chat_theme.dart';
import 'package:hopetsit/widgets/app_text.dart';

class NewConversationButton extends StatelessWidget {
  const NewConversationButton({
    super.key,
    required this.theme,
    required this.onTap,
    this.expanded,
  });

  final ChatRoleTheme theme;
  final VoidCallback onTap;

  /// true = pilule avec libellé, false = rond. null = toujours étendu.
  final ValueListenable<bool>? expanded;

  static const double size = 56;
  static const double _ring = 1.5;

  @override
  Widget build(BuildContext context) {
    final listenable = expanded;
    if (listenable == null) return _button(context, true);
    return ValueListenableBuilder<bool>(
      valueListenable: listenable,
      builder: (context, isExpanded, _) => _button(context, isExpanded),
    );
  }

  Widget _button(BuildContext context, bool isExpanded) {
    final accent = theme.accent;
    final soft = Color.lerp(accent, Colors.white, 0.22) ?? accent;
    final inner = size - 2 * _ring;
    final radius = BorderRadius.circular(size / 2);
    return Semantics(
      button: true,
      label: 'chat_new_conversation_btn'.tr,
      child: Container(
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [soft, accent, theme.accentDark],
            stops: const [0.0, 0.55, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: radius,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.92),
            width: _ring,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.38),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: inner,
                    height: inner,
                    child: const Icon(
                      Icons.maps_ugc_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  if (isExpanded)
                    Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 190.w),
                        child: PoppinsText(
                          text: 'chat_new_conversation_btn'.tr,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// v566 — état vide de la liste : grand bouton centré « Démarrer une
/// conversation » (même langage visuel que le bouton flottant).
class StartConversationButton extends StatelessWidget {
  const StartConversationButton({
    super.key,
    required this.theme,
    required this.label,
    required this.onTap,
  });

  final ChatRoleTheme theme;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = theme.accent;
    final soft = Color.lerp(accent, Colors.white, 0.22) ?? accent;
    final radius = BorderRadius.circular(29);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 340.w, minHeight: 58),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [soft, accent, theme.accentDark],
            stops: const [0.0, 0.55, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: radius,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.92),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.maps_ugc_rounded,
                      color: Colors.white, size: 24),
                  SizedBox(width: 10.w),
                  Flexible(
                    child: PoppinsText(
                      text: label,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
