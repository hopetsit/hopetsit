import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/models/pet_model.dart';

/// v406 refonte — état de formulaire partagé pour les champs enrichis de la
/// fiche animal (onglets À propos / Santé / Habitudes). Utilisé par
/// edit_pet_controller (écran unifié création + édition, v428+).
/// 100% additif : `toPayload()` n'envoie que des champs additifs
/// que le backend accepte déjà (Pet.js v405), donc aucun impact sur l'existant.
class EnrichedPetFormState {
  // ── À propos ─────────────────────────────────────────────────────────────
  /// 'male' | 'female' | null (non spécifié)
  final Rx<String?> gender = Rx<String?>(null);

  /// Traits de caractère sélectionnés (tokens canoniques, cf [characterPresets]).
  final RxList<String> characterTraits = <String>[].obs;

  /// Compatibilités : '' (non renseigné) | 'compatible' | 'supervised' | 'no'.
  final RxString compatDogs = ''.obs;
  final RxString compatCats = ''.obs;
  final RxString compatChildren = ''.obs;
  // v440 — compatibilité avec les NAC (additif).
  final RxString compatNac = ''.obs;

  final TextEditingController historyController = TextEditingController();

  /// Particularités libres (texte saisi par l'owner).
  final RxList<String> particularities = <String>[].obs;

  final TextEditingController notesController = TextEditingController();

  // ── Santé ────────────────────────────────────────────────────────────────
  /// '' | 'up_to_date' | 'partial' | 'late' | 'unknown'
  final RxString vaccinationStatus = ''.obs;
  // v440 — santé additive : stérilisé / pucé / restrictions alimentaires.
  final RxBool sterilized = false.obs;
  final RxBool microchipped = false.obs;
  final TextEditingController foodRestrictionsController =
      TextEditingController();
  final TextEditingController dewormingLastDateController =
      TextEditingController();
  final TextEditingController dewormingFrequencyController =
      TextEditingController();
  final TextEditingController currentTreatmentsController =
      TextEditingController();
  final TextEditingController bloodGroupController = TextEditingController();
  final TextEditingController insuranceNameController = TextEditingController();
  final TextEditingController insuranceNumberController =
      TextEditingController();

  // ── Habitudes ──────────────────────────────────────────────────────────
  /// '' | 'low' | 'medium' | 'high'
  final RxString energyLevel = ''.obs;
  // v440 — habitudes additives (segmentées + textes).
  /// '' | 'indoor' | 'outdoor' | 'crate'
  final RxString sleep = ''.obs;
  /// '' | 'yes' | 'learning'
  final RxString housetrained = ''.obs;
  /// '' | 'off_leash' | 'on_leash' | 'reliable_recall'
  final RxString leashBehaviour = ''.obs;
  // v443 — habitudes COCHABLES (presets), cf [habitPresets].
  final RxList<String> habitTags = <String>[].obs;
  // v443 — documents COCHABLES (carnet/passeport/…), cf [documentPresets].
  final RxList<String> documentTypes = <String>[].obs;
  final TextEditingController fearsController = TextEditingController();
  final TextEditingController preferredActivityController =
      TextEditingController();
  final TextEditingController educationController = TextEditingController();
  final TextEditingController aloneToleranceController =
      TextEditingController();
  final TextEditingController barkingController = TextEditingController();
  final TextEditingController likesController = TextEditingController();
  final TextEditingController dislikesController = TextEditingController();
  final TextEditingController transportController = TextEditingController();
  final TextEditingController brushingController = TextEditingController();
  final TextEditingController foodController = TextEditingController();
  final TextEditingController allowedTreatsController = TextEditingController();
  final TextEditingController favoriteObjectsController =
      TextEditingController();
  final TextEditingController favoritePlacesController =
      TextEditingController();
  final TextEditingController remarksController = TextEditingController();

  /// Presets de traits de caractère (tokens stockés en base ; labels i18n via
  /// la clé `pet_trait_<token>`).
  static const List<String> characterPresets = [
    'affectionate',
    'playful',
    'protective',
    'calm',
    'curious',
    'social',
    'shy',
    'energetic',
    'dominant',
    'independent',
    // conservés (utilisés sur d'anciens profils) :
    'smart',
    'gentle',
    'obedient',
  ];

  /// v443 — presets d'HABITUDES cochables (≥10) ; labels i18n `pet_habit_<token>`.
  static const List<String> habitPresets = [
    'likes_sleeping',
    'calm',
    'nervous',
    'dislikes_cats',
    'dislikes_dogs',
    'playful',
    'sociable',
    'barks',
    'greedy',
    'fearful',
    'clean',
    'energetic',
    'cuddly',
    'independent',
  ];

  /// v443 — types de DOCUMENTS cochables ; labels i18n `pet_doc_<token>`.
  static const List<String> documentPresets = [
    'health_book',
    'eu_passport',
    'vaccination_card',
    'sterilization_cert',
    'identification',
    'insurance_doc',
  ];

  void populateFrom(PetModel p) {
    gender.value = (p.gender == 'male' || p.gender == 'female')
        ? p.gender
        : null;
    characterTraits.assignAll(p.characterTraits);
    compatDogs.value = p.compatibilities.withDogs;
    compatCats.value = p.compatibilities.withCats;
    compatChildren.value = p.compatibilities.withChildren;
    compatNac.value = p.compatibilities.withNac;
    historyController.text = p.history;
    particularities.assignAll(p.particularities);
    notesController.text = p.notes;

    vaccinationStatus.value = p.vaccinationStatus;
    sterilized.value = p.sterilized;
    microchipped.value = p.microchipped;
    foodRestrictionsController.text = p.foodRestrictions;
    // Backend renvoie une ISO date ; on garde juste la partie YYYY-MM-DD.
    final dw = p.deworming.lastDate;
    dewormingLastDateController.text =
        dw.length >= 10 ? dw.substring(0, 10) : dw;
    dewormingFrequencyController.text = p.deworming.frequency;
    currentTreatmentsController.text = p.currentTreatments;
    bloodGroupController.text = p.bloodGroup;
    insuranceNameController.text = p.healthInsurance.name;
    insuranceNumberController.text = p.healthInsurance.number;

    energyLevel.value = p.habits.energyLevel;
    preferredActivityController.text = p.habits.preferredActivity;
    educationController.text = p.habits.education;
    aloneToleranceController.text = p.habits.aloneTolerance;
    barkingController.text = p.habits.barking;
    likesController.text = p.habits.likes;
    dislikesController.text = p.habits.dislikes;
    transportController.text = p.habits.transport;
    brushingController.text = p.habits.brushing;
    foodController.text = p.habits.food;
    allowedTreatsController.text = p.habits.allowedTreats;
    favoriteObjectsController.text = p.habits.favoriteObjects;
    favoritePlacesController.text = p.habits.favoritePlaces;
    remarksController.text = p.habits.remarks;
    sleep.value = p.habits.sleep;
    housetrained.value = p.habits.housetrained;
    leashBehaviour.value = p.habits.leashBehaviour;
    fearsController.text = p.habits.fears;
    habitTags.assignAll(p.habits.tags);
    documentTypes.assignAll(p.documentTypes);
  }

  /// Champs additifs à fusionner dans le payload create/update.
  Map<String, dynamic> toPayload() {
    return {
      if (gender.value != null) 'gender': gender.value,
      'characterTraits': characterTraits.toList(),
      'compatibilities': {
        'withDogs': compatDogs.value,
        'withCats': compatCats.value,
        'withChildren': compatChildren.value,
        'withNac': compatNac.value,
      },
      'history': historyController.text.trim(),
      'particularities': particularities.toList(),
      'notes': notesController.text.trim(),
      'vaccinationStatus': vaccinationStatus.value,
      'sterilized': sterilized.value,
      'microchipped': microchipped.value,
      'foodRestrictions': foodRestrictionsController.text.trim(),
      'deworming': {
        if (dewormingLastDateController.text.trim().isNotEmpty)
          'lastDate': dewormingLastDateController.text.trim(),
        'frequency': dewormingFrequencyController.text.trim(),
      },
      'currentTreatments': currentTreatmentsController.text.trim(),
      'bloodGroup': bloodGroupController.text.trim(),
      'healthInsurance': {
        'name': insuranceNameController.text.trim(),
        'number': insuranceNumberController.text.trim(),
      },
      'habits': {
        'energyLevel': energyLevel.value,
        'preferredActivity': preferredActivityController.text.trim(),
        'education': educationController.text.trim(),
        'aloneTolerance': aloneToleranceController.text.trim(),
        'barking': barkingController.text.trim(),
        'likes': likesController.text.trim(),
        'dislikes': dislikesController.text.trim(),
        'transport': transportController.text.trim(),
        'brushing': brushingController.text.trim(),
        'food': foodController.text.trim(),
        'allowedTreats': allowedTreatsController.text.trim(),
        'favoriteObjects': favoriteObjectsController.text.trim(),
        'favoritePlaces': favoritePlacesController.text.trim(),
        'remarks': remarksController.text.trim(),
        'sleep': sleep.value,
        'housetrained': housetrained.value,
        'leashBehaviour': leashBehaviour.value,
        'fears': fearsController.text.trim(),
        'tags': habitTags.toList(),
      },
      'documentTypes': documentTypes.toList(),
    };
  }

  void toggleTrait(String token) {
    if (characterTraits.contains(token)) {
      characterTraits.remove(token);
    } else {
      characterTraits.add(token);
    }
  }

  void toggleHabit(String token) {
    if (habitTags.contains(token)) {
      habitTags.remove(token);
    } else {
      habitTags.add(token);
    }
  }

  void toggleDocument(String token) {
    if (documentTypes.contains(token)) {
      documentTypes.remove(token);
    } else {
      documentTypes.add(token);
    }
  }

  void addParticularity(String value) {
    final v = value.trim();
    if (v.isNotEmpty && !particularities.contains(v)) {
      particularities.add(v);
    }
  }

  void removeParticularity(String value) => particularities.remove(value);

  void dispose() {
    historyController.dispose();
    notesController.dispose();
    foodRestrictionsController.dispose();
    fearsController.dispose();
    dewormingLastDateController.dispose();
    dewormingFrequencyController.dispose();
    currentTreatmentsController.dispose();
    bloodGroupController.dispose();
    insuranceNameController.dispose();
    insuranceNumberController.dispose();
    preferredActivityController.dispose();
    educationController.dispose();
    aloneToleranceController.dispose();
    barkingController.dispose();
    likesController.dispose();
    dislikesController.dispose();
    transportController.dispose();
    brushingController.dispose();
    foodController.dispose();
    allowedTreatsController.dispose();
    favoriteObjectsController.dispose();
    favoritePlacesController.dispose();
    remarksController.dispose();
  }
}
