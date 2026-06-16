import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/enriched_pet_form_state.dart';

/// v406 refonte — sections de formulaire enrichies (À propos / Santé /
/// Habitudes) pour la création et l'édition d'un animal. Consomme un
/// [EnrichedPetFormState] partagé. `accent` = couleur de rôle (owner orange).
class PetExtraFields extends StatelessWidget {
  final EnrichedPetFormState state;
  final Color accent;
  /// L'écran de création possède déjà son sélecteur de sexe → on le masque ici
  /// pour éviter un doublon. L'écran d'édition n'en a pas → on l'affiche.
  final bool showGender;

  const PetExtraFields({
    super.key,
    required this.state,
    required this.accent,
    this.showGender = true,
  });

  // ── helpers ──────────────────────────────────────────────────────────────
  Widget _tf(TextEditingController c, String label,
      {int maxLines = 1, TextInputType? kb}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        keyboardType: kb,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  /// Sélecteur segmenté (une seule valeur). `options` = [(token, label)].
  Widget _segmented(
    RxString value,
    List<MapEntry<String, String>> options, {
    bool allowEmpty = true,
  }) {
    return Obx(
      () => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((o) {
          final selected = value.value == o.key;
          return ChoiceChip(
            label: Text(o.value),
            selected: selected,
            onSelected: (_) {
              if (selected && allowEmpty) {
                value.value = '';
              } else {
                value.value = o.key;
              }
            },
            selectedColor: accent.withValues(alpha: 0.18),
            labelStyle: TextStyle(
              color: selected ? accent : null,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
            side: BorderSide(
              color: selected ? accent : Colors.grey.withValues(alpha: 0.4),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      );

  Widget _compatRow(String label, RxString value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          _segmented(value, [
            MapEntry('compatible', 'pet_compat_yes'.tr),
            MapEntry('supervised', 'pet_compat_supervised'.tr),
            MapEntry('no', 'pet_compat_no'.tr),
          ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── À PROPOS ────────────────────────────────────────────────────────
        ExpansionTile(
          title: Text('pet_section_about'.tr),
          childrenPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          children: [
            if (showGender) ...[
              _label('pet_gender'.tr),
              Obx(
                () => Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text('pet_gender_male'.tr),
                      selected: state.gender.value == 'male',
                      onSelected: (_) => state.gender.value =
                          state.gender.value == 'male' ? null : 'male',
                      selectedColor: accent.withValues(alpha: 0.18),
                    ),
                    ChoiceChip(
                      label: Text('pet_gender_female'.tr),
                      selected: state.gender.value == 'female',
                      onSelected: (_) => state.gender.value =
                          state.gender.value == 'female' ? null : 'female',
                      selectedColor: accent.withValues(alpha: 0.18),
                    ),
                  ],
                ),
              ),
            ],
            _label('pet_character_traits'.tr),
            Obx(
              () => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: EnrichedPetFormState.characterPresets.map((t) {
                  final selected = state.characterTraits.contains(t);
                  return FilterChip(
                    label: Text('pet_trait_$t'.tr),
                    selected: selected,
                    onSelected: (_) => state.toggleTrait(t),
                    selectedColor: accent.withValues(alpha: 0.18),
                    checkmarkColor: accent,
                    labelStyle: TextStyle(
                      color: selected ? accent : null,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  );
                }).toList(),
              ),
            ),
            _label('pet_compatibilities'.tr),
            _compatRow('pet_compat_children'.tr, state.compatChildren),
            _compatRow('pet_compat_dogs'.tr, state.compatDogs),
            _compatRow('pet_compat_cats'.tr, state.compatCats),
            _compatRow('pet_compat_nac'.tr, state.compatNac),
            const SizedBox(height: 8),
            _tf(state.historyController, 'pet_history'.tr, maxLines: 3),
            _label('pet_particularities'.tr),
            _ParticularityInput(state: state, accent: accent),
            _tf(state.notesController, 'pet_notes'.tr, maxLines: 3),
          ],
        ),

        // ── SANTÉ ───────────────────────────────────────────────────────────
        ExpansionTile(
          title: Text('pet_section_health'.tr),
          childrenPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          children: [
            _label('pet_vaccination_status'.tr),
            _segmented(state.vaccinationStatus, [
              MapEntry('up_to_date', 'pet_vax_up_to_date'.tr),
              MapEntry('partial', 'pet_vax_partial'.tr),
              MapEntry('late', 'pet_vax_late'.tr),
              MapEntry('unknown', 'pet_vax_unknown'.tr),
            ]),
            // v440 — puce électronique + stérilisé (booléens).
            Obx(
              () => CheckboxListTile(
                value: state.microchipped.value,
                onChanged: (v) => state.microchipped.value = v ?? false,
                title: Text('pet_microchipped'.tr),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: accent,
              ),
            ),
            Obx(
              () => CheckboxListTile(
                value: state.sterilized.value,
                onChanged: (v) => state.sterilized.value = v ?? false,
                title: Text('pet_sterilized'.tr),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: accent,
              ),
            ),
            const SizedBox(height: 4),
            _tf(state.dewormingLastDateController, 'pet_deworming_last_date'.tr),
            _tf(state.dewormingFrequencyController, 'pet_deworming_frequency'.tr),
            _tf(state.currentTreatmentsController, 'pet_current_treatments'.tr,
                maxLines: 2),
            _tf(state.foodRestrictionsController, 'pet_food_restrictions'.tr,
                maxLines: 2),
            _tf(state.bloodGroupController, 'pet_blood_group'.tr),
            _label('pet_health_insurance'.tr),
            _tf(state.insuranceNameController, 'pet_insurance_name'.tr),
            _tf(state.insuranceNumberController, 'pet_insurance_number'.tr),
          ],
        ),

        // ── HABITUDES ─────────────────────────────────────────────────────
        ExpansionTile(
          title: Text('pet_section_habits'.tr),
          childrenPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          children: [
            _label('pet_sleep'.tr),
            _segmented(state.sleep, [
              MapEntry('indoor', 'pet_sleep_indoor'.tr),
              MapEntry('outdoor', 'pet_sleep_outdoor'.tr),
              MapEntry('crate', 'pet_sleep_crate'.tr),
            ]),
            _label('pet_housetrained'.tr),
            _segmented(state.housetrained, [
              MapEntry('yes', 'pet_housetrained_yes'.tr),
              MapEntry('learning', 'pet_housetrained_learning'.tr),
            ]),
            _label('pet_leash'.tr),
            _segmented(state.leashBehaviour, [
              MapEntry('off_leash', 'pet_leash_off'.tr),
              MapEntry('on_leash', 'pet_leash_on'.tr),
              MapEntry('reliable_recall', 'pet_leash_recall'.tr),
            ]),
            _label('pet_energy_level'.tr),
            _segmented(state.energyLevel, [
              MapEntry('low', 'pet_energy_low'.tr),
              MapEntry('medium', 'pet_energy_medium'.tr),
              MapEntry('high', 'pet_energy_high'.tr),
            ]),
            const SizedBox(height: 4),
            _tf(state.fearsController, 'pet_fears'.tr, maxLines: 2),
            _tf(state.preferredActivityController, 'pet_preferred_activity'.tr),
            _tf(state.educationController, 'pet_education'.tr),
            _tf(state.aloneToleranceController, 'pet_alone_tolerance'.tr),
            _tf(state.barkingController, 'pet_barking'.tr),
            _tf(state.likesController, 'pet_likes'.tr),
            _tf(state.dislikesController, 'pet_dislikes'.tr),
            _tf(state.transportController, 'pet_transport'.tr),
            _tf(state.brushingController, 'pet_brushing'.tr),
            _tf(state.foodController, 'pet_food'.tr),
            _tf(state.allowedTreatsController, 'pet_allowed_treats'.tr),
            _tf(state.favoriteObjectsController, 'pet_favorite_objects'.tr),
            _tf(state.favoritePlacesController, 'pet_favorite_places'.tr),
            _tf(state.remarksController, 'pet_remarks'.tr, maxLines: 2),
          ],
        ),
      ],
    );
  }
}

/// Champ d'ajout de particularités (saisie libre → chips supprimables).
class _ParticularityInput extends StatelessWidget {
  final EnrichedPetFormState state;
  final Color accent;
  const _ParticularityInput({required this.state, required this.accent});

  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController();
    void add() {
      state.addParticularity(ctrl.text);
      ctrl.clear();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  hintText: 'pet_particularity_add_hint'.tr,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => add(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.add_circle, color: accent),
              onPressed: add,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Obx(
          () => Wrap(
            spacing: 6,
            runSpacing: 6,
            children: state.particularities
                .map((p) => Chip(
                      label: Text(p),
                      onDeleted: () => state.removeParticularity(p),
                      backgroundColor: accent.withValues(alpha: 0.10),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}
