// v565 — point 39 (retour Daniel, capture « Modifier l'animal Rex ») :
// pilules modernes de la fiche animal. Non choisie = contour gris fin sur fond
// carte ; choisie = pleine couleur du rôle (owner #C92A12) + coche blanche ;
// retour haptique à chaque tap ; alignées en `Wrap` bien espacé.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/enriched_pet_form_state.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Pilule de base (sélectionnable).
class PetPill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final String? emoji;
  final IconData? icon;

  const PetPill({
    super.key,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.emoji,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.textPrimary(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 9.h),
        decoration: BoxDecoration(
          color: selected ? accent : AppColors.card(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? accent : AppColors.divider(context),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check_rounded, size: 15.sp, color: Colors.white),
              SizedBox(width: 5.w),
            ] else if (icon != null) ...[
              Icon(icon, size: 15.sp, color: accent),
              SizedBox(width: 5.w),
            ] else if (emoji != null && emoji!.isNotEmpty) ...[
              Text(emoji!, style: TextStyle(fontSize: 14.sp)),
              SizedBox(width: 5.w),
            ],
            if (selected && icon != null) ...[
              Icon(icon, size: 15.sp, color: Colors.white),
              SizedBox(width: 5.w),
            ],
            Flexible(
              child: InterText(
                text: label,
                fontSize: 13.sp,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: fg,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Multi-sélection : `options` = [(token, libellé)], `selected` = RxList.
class PetMultiPills extends StatelessWidget {
  final List<MapEntry<String, String>> options;
  final RxList<String> selected;
  final void Function(String token) onToggle;
  final Color accent;
  final String Function(String token)? emojiFor;

  const PetMultiPills({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.accent,
    this.emojiFor,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final current = selected.toList();
      return Wrap(
        spacing: 8.w,
        runSpacing: 10.h,
        children: options
            .map((o) => PetPill(
                  label: o.value,
                  selected: current.contains(o.key),
                  accent: accent,
                  emoji: emojiFor?.call(o.key),
                  onTap: () => onToggle(o.key),
                ))
            .toList(),
      );
    });
  }
}

/// Sélection unique : `value` = RxString ('' = rien). Re-tap = désélection
/// si `allowEmpty`.
class PetSinglePills extends StatelessWidget {
  final List<MapEntry<String, String>> options;
  final RxString value;
  final Color accent;
  final bool allowEmpty;
  final String Function(String token)? emojiFor;
  final ValueChanged<String>? onChanged;

  const PetSinglePills({
    super.key,
    required this.options,
    required this.value,
    required this.accent,
    this.allowEmpty = true,
    this.emojiFor,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final current = value.value;
      return Wrap(
        spacing: 8.w,
        runSpacing: 10.h,
        children: options.map((o) {
          final sel = current == o.key;
          return PetPill(
            label: o.value,
            selected: sel,
            accent: accent,
            emoji: emojiFor?.call(o.key),
            onTap: () {
              final next = (sel && allowEmpty) ? '' : o.key;
              value.value = next;
              onChanged?.call(next);
            },
          );
        }).toList(),
      );
    });
  }
}

/// Sexe : deux pilules Mâle ♂ / Femelle ♀ (`Rx<String?>` : 'male', 'female' ou null).
class PetGenderPills extends StatelessWidget {
  final Rx<String?> gender;
  final Color accent;
  const PetGenderPills({super.key, required this.gender, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final g = gender.value;
      return Wrap(
        spacing: 8.w,
        runSpacing: 10.h,
        children: [
          PetPill(
            label: 'pet_gender_male'.tr,
            selected: g == 'male',
            accent: accent,
            icon: Icons.male_rounded,
            onTap: () => gender.value = g == 'male' ? null : 'male',
          ),
          PetPill(
            label: 'pet_gender_female'.tr,
            selected: g == 'female',
            accent: accent,
            icon: Icons.female_rounded,
            onTap: () => gender.value = g == 'female' ? null : 'female',
          ),
        ],
      );
    });
  }
}

/// Petit libellé au-dessus d'un groupe de pilules / d'un champ.
class PetFieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const PetFieldLabel(this.text, {super.key, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Flexible(
            child: InterText(
              text: text,
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(context),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (required)
            InterText(
              text: ' *',
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.errorColor,
            ),
        ],
      ),
    );
  }
}

/// Rangée « case » moderne (interrupteur) pour un booléen Rx.
class PetToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final RxBool value;
  final Color accent;
  const PetToggleRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final on = value.value;
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          value.value = !on;
        },
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Container(
              width: 34.w,
              height: 34.w,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, size: 17.sp, color: accent),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: InterText(
                text: label,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 8.w),
            Switch.adaptive(
              value: on,
              activeTrackColor: accent,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                value.value = v;
              },
            ),
          ],
        ),
      );
    });
  }
}

/// Particularités libres : saisie + pilules supprimables.
class PetParticularityInput extends StatefulWidget {
  final EnrichedPetFormState state;
  final Color accent;
  const PetParticularityInput({super.key, required this.state, required this.accent});

  @override
  State<PetParticularityInput> createState() => _PetParticularityInputState();
}

class _PetParticularityInputState extends State<PetParticularityInput> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add() {
    widget.state.addParticularity(_ctrl.text);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary(context),
                ),
                decoration: InputDecoration(
                  hintText: 'pet_particularity_add_hint'.tr,
                  hintStyle: TextStyle(
                    fontSize: 13.sp,
                    color: AppColors.textSecondary(context).withValues(alpha: 0.8),
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.card(context),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide(color: AppColors.divider(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide(color: AppColors.divider(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide(color: accent, width: 1.6),
                  ),
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            SizedBox(width: 8.w),
            GestureDetector(
              onTap: _add,
              child: Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(Icons.add_rounded, color: Colors.white, size: 22.sp),
              ),
            ),
          ],
        ),
        Obx(() {
          final items = widget.state.particularities.toList();
          if (items.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: EdgeInsets.only(top: 10.h),
            child: Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: items
                  .map((p) => Container(
                        padding: EdgeInsets.only(left: 12.w, right: 6.w, top: 6.h, bottom: 6.h),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: InterText(
                                text: p,
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w600,
                                color: accent,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            GestureDetector(
                              onTap: () => widget.state.removeParticularity(p),
                              child: Icon(Icons.cancel_rounded, size: 17.sp, color: accent),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          );
        }),
      ],
    );
  }
}
