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
          title: Text('pet_age_behavior'.tr),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          children: [
            _tf(ageController, 'pet_age_years'.tr, kb: TextInputType.number),
            const SizedBox(height: 12),
            _tf(behaviorController, 'pet_behavior_hint'.tr, maxLines: 4),
          ],
        ),
        ExpansionTile(
          title: Text('pet_vaccinations'.tr),
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
                              decoration: InputDecoration(labelText: 'pet_vaccine_name'.tr),
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
                                  InputDecoration(labelText: 'pet_vaccine_date'.tr),
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
                    label: Text('pet_add_vaccination'.tr),
                    onPressed: onAddVaccination,
                  ),
                ],
              ),
            ),
          ],
        ),
        ExpansionTile(
          title: Text('pet_regular_vet'.tr),
          children: [
            _tf(regularVetNameController, 'pet_vet_name'.tr),
            const SizedBox(height: 8),
            _tf(regularVetPhoneController, 'pet_vet_phone'.tr, kb: TextInputType.phone),
            const SizedBox(height: 8),
            _tf(regularVetAddressController, 'pet_vet_address'.tr),
          ],
        ),
        ExpansionTile(
          title: Text('pet_emergency_vet'.tr),
          children: [
            _tf(emergencyVetNameController, 'pet_vet_name'.tr),
            const SizedBox(height: 8),
            _tf(emergencyVetPhoneController, 'pet_vet_phone'.tr, kb: TextInputType.phone),
            const SizedBox(height: 8),
            _tf(emergencyVetAddressController, 'pet_vet_address'.tr),
          ],
        ),
        ExpansionTile(
          title: Text('pet_emergency_auth'.tr),
          children: [
            Obx(
              () => CheckboxListTile(
                value: emergencyAuthAccepted.value,
                onChanged: (v) => emergencyAuthAccepted.value = v ?? false,
                title: Text('pet_authorize_emergency'.tr),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
            Obx(() => emergencyAuthAccepted.value
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'pet_emergency_legal'.tr,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  )
                : const SizedBox.shrink()),
          ],
        ),
      ],
    );
  }
}
