import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Sprint 6.5 step 1 — shared enriched-pet-profile form sections.
/// Used by both create_pet_profile_screen and edit_pet_screen.
class PetEnrichedFields extends StatelessWidget {
  static const String emergencyLegalText =
      "J'autorise le petsitter à contacter le vétérinaire d'urgence et à engager les soins nécessaires en cas de danger vital pour mon animal, avec prise en charge financière à ma charge. Je reste joignable à tout moment.";

  final TextEditingController ageController;
  final TextEditingController behaviorController;
  final TextEditingController regularVetNameController;
  final TextEditingController regularVetPhoneController;
  final TextEditingController regularVetAddressController;
  final TextEditingController emergencyVetNameController;
  final TextEditingController emergencyVetPhoneController;
  final TextEditingController emergencyVetAddressController;
  final RxBool emergencyAuthAccepted;
  final RxList<Map<String, String>> vaccinationsList;
  final VoidCallback onAddVaccination;
  final void Function(int index) onRemoveVaccination;
  final void Function(int index, String field, String value)
      onSetVaccinationField;

  const PetEnrichedFields({
    super.key,
    required this.ageController,
    required this.behaviorController,
    required this.regularVetNameController,
    required this.regularVetPhoneController,
    required this.regularVetAddressController,
    required this.emergencyVetNameController,
    required this.emergencyVetPhoneController,
    required this.emergencyVetAddressController,
    required this.emergencyAuthAccepted,
    required this.vaccinationsList,
    required this.onAddVaccination,
    required this.onRemoveVaccination,
    required this.onSetVaccinationField,
  });

  TextField _tf(TextEditingController c, String label,
      {int maxLines = 1, TextInputType? kb}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      keyboardType: kb,
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExpansionTile(
          title: const Text('Age & behavior'),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          children: [
            _tf(ageController, 'Age (years)', kb: TextInputType.number),
            const SizedBox(height: 12),
            _tf(behaviorController, 'Behavior (max 500 chars)', maxLines: 4),
          ],
        ),
        ExpansionTile(
          title: const Text('Vaccinations'),
          children: [
            Obx(
              () => Column(
                children: [
                  for (int i = 0; i < vaccinationsList.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(
                                text: vaccinationsList[i]['name'] ?? '',
                              ),
                              onChanged: (v) =>
                                  onSetVaccinationField(i, 'name', v),
                              decoration: const InputDecoration(labelText: 'Name'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(
                                text: vaccinationsList[i]['date'] ?? '',
                              ),
                              onChanged: (v) =>
                                  onSetVaccinationField(i, 'date', v),
                              decoration:
                                  const InputDecoration(labelText: 'YYYY-MM-DD'),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => onRemoveVaccination(i),
                          ),
                        ],
                      ),
                    ),
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add vaccination'),
                    onPressed: onAddVaccination,
                  ),
                ],
              ),
            ),
          ],
        ),
        ExpansionTile(
          title: const Text('Regular vet'),
          children: [
            _tf(regularVetNameController, 'Name'),
            const SizedBox(height: 8),
            _tf(regularVetPhoneController, 'Phone', kb: TextInputType.phone),
            const SizedBox(height: 8),
            _tf(regularVetAddressController, 'Address'),
          ],
        ),
        ExpansionTile(
          title: const Text('Emergency vet'),
          children: [
            _tf(emergencyVetNameController, 'Name'),
            const SizedBox(height: 8),
            _tf(emergencyVetPhoneController, 'Phone', kb: TextInputType.phone),
            const SizedBox(height: 8),
            _tf(emergencyVetAddressController, 'Address'),
          ],
        ),
        ExpansionTile(
          title: const Text('Emergency intervention authorization'),
          children: [
            Obx(
              () => CheckboxListTile(
                value: emergencyAuthAccepted.value,
                onChanged: (v) => emergencyAuthAccepted.value = v ?? false,
                title: const Text('I authorize emergency intervention'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
            Obx(() => emergencyAuthAccepted.value
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      emergencyLegalText,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  )
                : const SizedBox.shrink()),
          ],
        ),
      ],
    );
  }
}
