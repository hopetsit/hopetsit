// 639 — suggestions de races courantes sous le champ « Race » de la fiche
// animal. Le champ reste LIBRE et FACULTATIF : une pastille ne fait que
// remplir le champ, on peut toujours écrire autre chose ou le laisser vide.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/breeds639.dart';
import 'package:hopetsit/views/profile/widgets/pet_form_widgets.dart';
import 'package:hopetsit/widgets/app_text.dart';

class BreedSuggestions639 extends StatelessWidget {
  /// Jeton d'espèce du formulaire ('Dog', 'Cat', 'Bird', …).
  final String species;

  /// Contrôleur du champ « Race » (lu et rempli ici).
  final TextEditingController controller;
  final Color accent;

  const BreedSuggestions639({
    super.key,
    required this.species,
    required this.controller,
    required this.accent,
  });

  void _pick(String name, bool selected) {
    // Retoucher une pastille déjà choisie vide le champ (rien d'obligatoire).
    final next = selected ? '' : name;
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Get.locale?.languageCode ?? 'en';
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final names = breedSuggestions639(species, value.text, lang);
        if (names.isEmpty) return const SizedBox.shrink();
        return Padding(
          key: const Key('f639_breed_suggestions'),
          padding: EdgeInsets.only(top: 10.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              InterText(
                text: 'f639_breed_suggest'.tr,
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 8.h),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < names.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                            right: i == names.length - 1 ? 0 : 8.w),
                        child: Builder(builder: (context) {
                          final selected = sameBreed639(value.text, names[i]);
                          return PetPill(
                            key: ValueKey<String>('f639_breed_${names[i]}'),
                            label: names[i],
                            selected: selected,
                            accent: accent,
                            onTap: () => _pick(names[i], selected),
                          );
                        }),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
