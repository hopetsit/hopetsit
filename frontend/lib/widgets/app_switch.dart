import 'package:flutter/material.dart';

/// v441 — Daniel : « dans toute l'app les boutons on/off sont comme ça, on
/// distingue pas bien le full orange ». Le `Switch` Material par défaut (avec
/// seulement `activeTrackColor`) rendait une pastille pleine sans pouce
/// nettement visible → impossible de distinguer ON de OFF.
///
/// `AppSwitch` est un interrupteur partagé et LISIBLE :
///   • OFF → piste GRISE claire + pouce blanc à gauche
///   • ON  → piste à la couleur d'accent + pouce BLANC (contraste fort) à droite
///   • contour léger pour détacher le pouce du fond clair de la carte
///
/// Drop-in : remplace `Switch(value:…, onChanged:…, activeTrackColor:accent)`.
class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  /// Couleur ON (piste). Par défaut l'orange de la marque.
  final Color accent;

  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.accent = const Color(0xFFC92A12),
  });

  @override
  Widget build(BuildContext context) {
    // v569 — même langage que les champs : pilule animée, pouce blanc net.
    // La piste OFF suit le thème (l'ancien gris clair FIXE disparaissait sur
    // le fond sombre des cartes en mode nuit).
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color offTrack =
        isDark ? const Color(0xFF433431) : const Color(0xFFECE2DF);
    final Color offOutline =
        isDark ? const Color(0xFF584540) : const Color(0xFFD4C5C2);
    final bool enabled = onChanged != null;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Switch(
        value: value,
        onChanged: onChanged,
        // Pouce TOUJOURS blanc → bien visible sur la piste (grise ou accent).
        thumbColor: const WidgetStatePropertyAll<Color>(Colors.white),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          return states.contains(WidgetState.selected) ? accent : offTrack;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith<Color>((states) {
          return states.contains(WidgetState.selected) ? accent : offOutline;
        }),
        trackOutlineWidth: const WidgetStatePropertyAll<double>(1),
        // Halo de pression à la couleur d'accent (au lieu du violet Material).
        overlayColor: WidgetStatePropertyAll<Color>(
          accent.withValues(alpha: 0.12),
        ),
        // Pas d'icône check dans le pouce (rend le blanc plus net).
        thumbIcon: const WidgetStatePropertyAll<Icon?>(null),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
