// v585 (25/09/2026, bug 9) — Daniel : « dans Mes tarifs, le menu des devises
// s'ouvre en GRIS ». Cause : en Material 3, un menu déroulant sans couleur
// prend `canvasColor` / `surfaceContainer` du thème (un gris rosé) avec une
// teinte d'élévation par-dessus. Règle zéro gris : TOUS les menus de l'app
// (DropdownButton, DropdownMenu, PopupMenuButton, showMenu, MenuAnchor) ouvrent
// sur un blanc chaud (encre foncée en sombre), coins 16, ombre teintée, texte
// encre chaude ; la valeur choisie en teinte pâle de la couleur du rôle avec
// une coche (`pawDropdownItems`).
import 'package:flutter/material.dart';

class PawMenuColors {
  static const Color paperLight = Color(0xFFFFFBF7); // blanc chaud
  static const Color paperDark = Color(0xFF2D1F1B); // encre foncée chaude
  static const Color inkLight = Color(0xFF2B1D19);
  static const Color inkDark = Color(0xFFF7EDE8);
  static const Color shadow = Color(0x332B1D19); // ombre teintée encre

  static Color paper(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? paperDark : paperLight;
  static Color ink(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? inkDark : inkLight;
}

/// Thèmes des menus, à poser dans `ThemeData` (clair et sombre).
class PawMenuThemes {
  PawMenuThemes({required this.dark});
  final bool dark;

  Color get _paper => dark ? PawMenuColors.paperDark : PawMenuColors.paperLight;
  Color get _ink => dark ? PawMenuColors.inkDark : PawMenuColors.inkLight;
  static final RoundedRectangleBorder _shape =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

  PopupMenuThemeData get popup => PopupMenuThemeData(
        color: _paper,
        surfaceTintColor: Colors.transparent,
        shadowColor: PawMenuColors.shadow,
        elevation: 6,
        shape: _shape,
        textStyle: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w500),
        labelTextStyle: WidgetStatePropertyAll(
            TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w500)),
      );

  MenuStyle get _menuStyle => MenuStyle(
        backgroundColor: WidgetStatePropertyAll(_paper),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: const WidgetStatePropertyAll(PawMenuColors.shadow),
        elevation: const WidgetStatePropertyAll(6),
        shape: WidgetStatePropertyAll(_shape),
      );

  MenuThemeData get menu => MenuThemeData(style: _menuStyle);

  DropdownMenuThemeData get dropdownMenu => DropdownMenuThemeData(
        menuStyle: _menuStyle,
        textStyle: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w500),
      );
}

/// Items d'un DropdownButton : la valeur choisie sur un fond pâle de la
/// couleur [accent] avec une coche. À utiliser AVEC `selectedItemBuilder:
/// pawDropdownSelected(items)` pour que le champ fermé n'affiche pas la coche.
List<DropdownMenuItem<T>> pawDropdownItems<T>(
  BuildContext context,
  List<DropdownMenuItem<T>> items, {
  required T? selected,
  required Color accent,
}) {
  return [
    for (final it in items)
      DropdownMenuItem<T>(
        value: it.value,
        enabled: it.enabled,
        onTap: it.onTap,
        child: it.value == selected
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: DefaultTextStyle.merge(
                        style: TextStyle(
                            color: PawMenuColors.ink(context),
                            fontWeight: FontWeight.w700),
                        child: it.child,
                      ),
                    ),
                    Icon(Icons.check_rounded, color: accent, size: 20),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: PawMenuColors.ink(context)),
                  child: it.child,
                ),
              ),
      ),
  ];
}

/// Le champ FERMÉ affiche l'item tel quel (sans coche ni fond).
DropdownButtonBuilder pawDropdownSelected<T>(List<DropdownMenuItem<T>> items) =>
    (BuildContext context) => [
          for (final it in items)
            Align(alignment: AlignmentDirectional.centerStart, child: it.child),
        ];
