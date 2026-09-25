import 'package:flutter/material.dart';
import 'package:hopetsit/utils/paw_menu_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// v426 — synchro inscription↔profil. Widgets partagés par les 3 écrans
/// « Modifier le profil » (owner/sitter/walker) pour éditer les champs que le
/// wizard d'inscription collecte (animaux acceptés, expérience, services,
/// rayon). Le style reprend EXACTEMENT celui du wizard (chips arrondies +
/// libellé InterText) et la couleur de rôle (`accent`).

/// Petit libellé de section (au-dessus d'un groupe de chips / dropdown).
class ProfileFieldLabel extends StatelessWidget {
  final String text;
  const ProfileFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: InterText(
        text: text,
        fontSize: 14.sp,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary(context),
      ),
    );
  }
}

/// Chip multi-sélection (toggle). `options` = liste de [value, labelTr].
/// `selected` est la RxList source de vérité ; tap → toggle.
class ProfileChoiceChips extends StatelessWidget {
  final Color accent;
  final List<List<String>> options;
  final List<String> selected;
  final void Function(String value) onToggle;

  /// v440 — emoji d'espèce optionnel rendu AVANT le libellé (sélecteur
  /// d'animaux gardés / promenés). Reçoit la `value` canonique (dog/cat/…) et
  /// renvoie l'emoji ('' = aucune icône). Laissé null pour les chips sans
  /// icône (services, expérience) afin de conserver leur rendu d'origine.
  final String Function(String value)? emojiFor;

  const ProfileChoiceChips({
    super.key,
    required this.accent,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.emojiFor,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: options.map((o) {
        final value = o[0];
        final label = o[1];
        final isSel = selected.contains(value);
        final emoji = emojiFor?.call(value) ?? '';
        return GestureDetector(
          onTap: () => onToggle(value),
          // v569 — DESIGN UNIQUEMENT : même `onToggle`, mêmes valeurs. Chips
          // en pilules pleines (999) avec une petite coche quand c'est
          // sélectionné, et un libellé qui s'ellipse au lieu de déborder.
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            constraints: BoxConstraints(maxWidth: 260.w),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
            decoration: BoxDecoration(
              // v444 — Daniel : « Ce que vous recherchez » paraissait un cadre
              // gris vide. Cause : le fond des chips non sélectionnées
              // (inputFill) = EXACTEMENT la couleur du scaffold → pastilles
              // invisibles, zone perçue comme vide. Fond carte (blanc) +
              // bordure plus marquée → chips toujours nettement visibles.
              color: isSel ? accent.withValues(alpha: 0.15) : AppColors.card(context),
              borderRadius: BorderRadius.circular(999.r),
              border: Border.all(
                color: isSel ? accent : AppColors.divider(context),
                width: isSel ? 1.6 : 1.2,
              ),
              boxShadow: isSel
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.18),
                        blurRadius: 8,
                        spreadRadius: -3,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (emoji.isNotEmpty) ...[
                  Text(emoji, style: TextStyle(fontSize: 14.sp)),
                  SizedBox(width: 6.w),
                ],
                Flexible(
                  child: InterText(
                    text: label,
                    fontSize: 13.sp,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
                    color: isSel ? accent : AppColors.textPrimary(context),
                  ),
                ),
                if (isSel) ...[
                  SizedBox(width: 6.w),
                  Icon(Icons.check_rounded, size: 14.sp, color: accent),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Dropdown du rayon d'intervention / recherche (km), style cohérent.
class ProfileRadiusDropdown extends StatelessWidget {
  final Color accent;
  final String value;
  final void Function(String) onChanged;
  const ProfileRadiusDropdown({
    super.key,
    required this.accent,
    required this.value,
    required this.onChanged,
  });

  static const _opts = ['5', '10', '15', '20', '25', '30', '50', '100'];
  static final List<DropdownMenuItem<String>> _items = _opts
      .map((e) => DropdownMenuItem(value: e, child: Text('$e km')))
      .toList();

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: _opts.contains(value) ? value : '20',
      isExpanded: true,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.inputFill(context),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: BorderSide(color: AppColors.divider(context), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: BorderSide(color: AppColors.divider(context), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      ),
      // v585 (bug 9) — menu blanc chaud, coins 16, choix coché.
      dropdownColor: PawMenuColors.paper(context),
      borderRadius: BorderRadius.circular(16),
      icon: Icon(Icons.expand_more_rounded, color: accent),
      selectedItemBuilder: pawDropdownSelected<String>(_items),
      items: pawDropdownItems<String>(context, _items,
          selected: _opts.contains(value) ? value : '20', accent: accent),
      onChanged: (v) => onChanged(v ?? '20'),
    );
  }
}
