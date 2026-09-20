// v565 — couleurs du chat selon le rôle courant (CLAUDE.md « Marque »).
//   owner  = orange #C92A12   walker = vert #16A34A   sitter = bleu #2563EB
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/storage_keys.dart';

/// Rouge d'action destructive (supprimer, signaler, bloquer) posé en TEXTE ou
/// en ICÔNE sur une surface : `AppColors.errorColor` tombe à ~3:1 sur un fond
/// sombre. Mode clair : valeur d'origine, rendu inchangé.
Color chatDanger(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFF07070)
        : AppColors.errorColor;

class ChatRoleTheme {
  const ChatRoleTheme._({
    required this.role,
    required this.accent,
    required this.accentDark,
    required this.tint,
    required this.tintStrong,
  });

  final String role;

  /// Couleur principale (bulles envoyées, boutons, pastilles).
  final Color accent;
  final Color accentDark;

  /// Fond très pâle (arrière-plan de la discussion en mode clair).
  final Color tint;

  /// Fond pâle plus marqué (badges, chips).
  final Color tintStrong;

  static const owner = ChatRoleTheme._(
    role: 'owner',
    accent: Color(0xFFC92A12),
    accentDark: Color(0xFFA32110),
    tint: Color(0xFFFFF4F0),
    tintStrong: Color(0xFFFCE4DC),
  );
  static const walker = ChatRoleTheme._(
    role: 'walker',
    accent: Color(0xFF16A34A),
    accentDark: Color(0xFF12803B),
    tint: Color(0xFFF0FAF3),
    tintStrong: Color(0xFFDCEFE3),
  );
  static const sitter = ChatRoleTheme._(
    role: 'sitter',
    accent: Color(0xFF2563EB),
    accentDark: Color(0xFF1D4FBD),
    tint: Color(0xFFF0F5FE),
    tintStrong: Color(0xFFDDEAFB),
  );

  static const online = Color(0xFF22C55E);
  static const offline = Color(0xFFB3AFA8);

  static ChatRoleTheme forRole(String? raw) {
    final r = (raw ?? '').toLowerCase();
    if (r.contains('walker')) return walker;
    if (r.contains('sitter')) return sitter;
    return owner;
  }

  /// Thème du rôle actif (lu dans GetStorage, comme AppColors).
  static ChatRoleTheme current() {
    try {
      final box = GetStorage();
      final byRole = box.read<String>(StorageKeys.userRole);
      if (byRole != null && byRole.isNotEmpty) return forRole(byRole);
      final p = box.read<Map>(StorageKeys.userProfile);
      return forRole((p?['role'] ?? '').toString());
    } catch (_) {
      return owner;
    }
  }

  bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Fond de la zone des messages.
  Color background(BuildContext context) =>
      isDark(context) ? AppColors.backgroundDark : tint;

  /// Bulle reçue.
  Color receivedBubble(BuildContext context) =>
      isDark(context) ? const Color(0xFF2A2A2A) : Colors.white;

  Color receivedText(BuildContext context) => AppColors.textPrimary(context);

  /// Fond pâle (aperçu de citation, bandeaux). Les pastels `tint` /
  /// `tintStrong` sont quasi blancs : posés tels quels en mode sombre ils
  /// donnent un pavé éblouissant sous un texte clair. En sombre on garde la
  /// teinte du rôle, mais en voile transparent sur la surface sombre.
  /// Mode clair : valeur d'origine, rendu inchangé.
  Color softTint(BuildContext context) =>
      isDark(context) ? accent.withValues(alpha: 0.16) : tint;

  /// Idem pour les disques / pastilles teintés (bouton « + », icône d'état…).
  Color softTintStrong(BuildContext context) =>
      isDark(context) ? accent.withValues(alpha: 0.24) : tintStrong;

  /// Accent utilisé en TEXTE ou en ICÔNE sur une surface (carte, bulle reçue,
  /// barre du haut) : le rouge propriétaire et le bleu gardien tombent à ~2,9:1
  /// sur un fond sombre. On l'éclaircit alors de 40 %. Mode clair : valeur
  /// d'origine, rendu inchangé. À NE PAS utiliser comme couleur de fond.
  Color accentOn(BuildContext context) => isDark(context)
      ? (Color.lerp(accent, Colors.white, 0.40) ?? accent)
      : accent;

  /// Bulle envoyée.
  Color get sentBubble => accent;
  Color get sentText => Colors.white;

  /// Fond de la citation à l'intérieur d'une bulle.
  Color quoteBackground(bool mine, BuildContext context) => mine
      ? Colors.white.withValues(alpha: 0.18)
      : (isDark(context)
          ? Colors.white.withValues(alpha: 0.06)
          : accent.withValues(alpha: 0.08));
}
