import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/home_controller.dart';
import 'package:hopetsit/controllers/posts_controller.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/pet_model.dart';
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/repositories/pet_repository.dart';
import 'package:hopetsit/repositories/post_repository.dart';
import 'package:hopetsit/services/location_service.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/service_location587.dart';
// v575 — audit P1-7 : bornes de durée de promenade partagées avec le serveur.
import 'package:hopetsit/utils/walk_duration.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class PublishReservationRequestController extends GetxController {
  PublishReservationRequestController({
    PetRepository? petRepository,
    LocationService? locationService,
    ImagePicker? imagePicker,
    OwnerRepository? ownerRepository,
    PostRepository? postRepository,
    PostModel? editPost,
  }) : _petRepository = petRepository ?? Get.find<PetRepository>(),
       _locationService = locationService ?? LocationService(),
       _imagePicker = imagePicker ?? ImagePicker(),
       _ownerRepository = ownerRepository ?? Get.find<OwnerRepository>(),
       _postRepository = postRepository ?? Get.find<PostRepository>(),
       _editPost = editPost;

  final PetRepository _petRepository;
  final LocationService _locationService;
  final ImagePicker _imagePicker;
  final OwnerRepository _ownerRepository;
  final PostRepository _postRepository;

  // v441 — édition d'une annonce existante (owner « Modifier »). Quand non
  // null, le formulaire est pré-rempli et `submit()` PUT/PATCH le post au lieu
  // d'en créer un nouveau. L'édition n'est autorisée que tant que la
  // réservation n'est PAS payée (gardée côté backend updatePost).
  final PostModel? _editPost;

  /// True quand le formulaire édite une annonce existante (mode Modifier).
  bool get isEditMode => _editPost != null;

  /// L'id du post en cours d'édition (vide en mode création).
  String get editPostId => _editPost?.id ?? '';

  final formKey = GlobalKey<FormState>();

  // Form fields
  final notesController = TextEditingController();
  final cityController = TextEditingController();
  /// v587 (point 8) — adresse / quartier du point de rendez-vous (promenade).
  final meetingPointController = TextEditingController();
  final RxString meetingPointText = ''.obs;
  final addressController = TextEditingController();

  final Rxn<DateTime> startDate = Rxn<DateTime>();
  final Rxn<DateTime> endDate = Rxn<DateTime>();
  final Rxn<TimeOfDay> startTime = Rxn<TimeOfDay>();
  final Rxn<TimeOfDay> endTime = Rxn<TimeOfDay>();

  final RxnString selectedServiceType = RxnString();
  final RxnString selectedDuration = RxnString(); // for dog_walking
  final RxnString houseSittingVenue = RxnString();
  /// Sprint 5 UI step 1 — service location ('at_owner' | 'at_sitter' | 'both').
  final RxnString serviceLocation = RxnString();

  final RxList<PetModel> myPets = <PetModel>[].obs;
  final RxBool isPetsLoading = false.obs;
  // v23.1 — multi-pet selection. selectedPetId kept for backwards compat
  // (returns the first selected) but the UI now toggles selectedPetIds.
  final RxList<String> selectedPetIds = <String>[].obs;
  RxnString get selectedPetId =>
      RxnString(selectedPetIds.isNotEmpty ? selectedPetIds.first : null);
  // v21 — Visual highlight flag : when the user taps "Publish" without
  // having picked a pet, we set this true so the pet selector frames in
  // red. Reset to false the moment they pick one.
  final RxBool petSelectionError = false.obs;

  final RxBool isGettingLocation = false.obs;
  final RxString detectedCity = ''.obs;
  final RxnDouble userLat = RxnDouble();
  final RxnDouble userLng = RxnDouble();

  final RxBool isSubmitting = false.obs;

  // v411 — toggle maquette « Afficher le caractère des animaux » (défaut ON).
  final RxBool showAnimalCharacter = true.obs;

  final RxList<File> imageFiles = <File>[].obs;

  /// Service catalog — session avril 2026 simplification from 5 to 3 services.
  ///   • Promenade (dog_walking) — walker-exclusive, green accent
  ///   • Garderie (day_care)     — daytime care at sitter or owner, blue
  ///   • Garde multi-jours (pet_sitting) — overnight stays, blue
  ///
  /// "Boarding" and "house_sitting" are folded into `pet_sitting`; the
  /// previous "Lieu du house sitting" binary choice is replaced by the more
  /// general `serviceLocation` radio (Chez moi / Chez le sitter / Les deux)
  /// which is shown for daycare + pet_sitting but hidden for promenades
  /// (always outdoors).
  List<Map<String, String>> get serviceTypes => <Map<String, String>>[
    {
      'value': 'dog_walking',
      'label': 'publish_request_service_walking'.tr,
      'description': 'publish_request_service_walking_desc'.tr,
      'icon': '🐾',
    },
    {
      'value': 'day_care',
      'label': 'publish_request_service_daycare'.tr,
      'description': 'publish_request_service_daycare_desc'.tr,
      'icon': '☀️',
    },
    {
      'value': 'pet_sitting',
      'label': 'publish_request_service_pet_sitting'.tr,
      'description': 'publish_request_service_pet_sitting_desc'.tr,
      'icon': '🏡',
    },
  ];

  /// Duration presets for Promenade — short walks, 30-min steps up to 2h.
  /// Pricing and chip layout in the UI assume 4 items here.
  static const List<String> promenadeMinutes = <String>['30', '60', '90', '120'];

  /// Duration presets for Sortie longue — half-day outings, hour granularity.
  /// Displayed as a second group under Promenade so owners understand
  /// this is a different product (and walkers can price it differently).
  static const List<String> longOutingMinutes = <String>['180', '240', '300'];

  bool get shouldShowDuration => selectedServiceType.value == 'dog_walking';

  /// The service-location radio (at_owner / at_sitter / both) shows for
  /// sitter services only. Promenade is implicitly outdoor.
  ///
  /// v587 (point 8 de Daniel) — le lieu se choisit pour TOUS les services :
  /// garde (chez moi / chez le gardien), promenade (récupérer chez moi / point
  /// de rendez-vous), visites (chez moi, fixé). Avant, la promenade n'avait
  /// aucun choix et la valeur n'était jamais obligatoire.
  bool get shouldShowServiceLocation =>
      serviceLocationFamily(selectedServiceType.value) != null;

  /// Le lieu est-il choisi et complet (adresse du RDV comprise) ?
  bool get serviceLocationDone {
    final st = selectedServiceType.value;
    if (serviceLocationFamily(st) == ServiceLocationFamily.visit) return true;
    if (!serviceLocationFits(st, serviceLocation.value)) return false;
    if (serviceLocation.value == 'meeting_point') {
      return meetingPointText.value.trim().isNotEmpty;
    }
    return true;
  }

  /// Valeur envoyée au serveur (null si rien de valable).
  String? get serviceLocationToSend {
    final st = selectedServiceType.value;
    if (serviceLocationFamily(st) == ServiceLocationFamily.visit) {
      return 'at_owner';
    }
    final v = serviceLocation.value?.trim();
    return serviceLocationFits(st, v) ? v : null;
  }

  void selectServiceLocation(String value) {
    serviceLocation.value = value;
  }

  void setMeetingPoint(String value) {
    meetingPointText.value = value;
  }

  // Legacy flag kept for backward-compat callers; house_sitting is no longer
  // a selectable type post-simplification, so this now always returns false.
  bool get shouldShowHouseSittingVenue => false;

  // v18.8 — dates + heures localisées via DateFormat (intl) au lieu des
  // tableaux statiques anglais. L'owner FR voit "ven. 24 avr. 2026" et
  // "23:24" au lieu de "Fri, Apr 24, 2026" et "11:24 PM".
  String _formatDate(DateTime d) {
    final lang = Get.locale?.languageCode ?? 'fr';
    return DateFormat('EEE, d MMM y', lang).format(d);
  }

  String _formatTime(TimeOfDay t) {
    final lang = Get.locale?.languageCode ?? 'fr';
    final dt = DateTime(0, 1, 1, t.hour, t.minute);
    // Formats 24h pour fr/de/es/it/pt, 12h avec AM/PM pour en.
    final pattern = lang == 'en' ? 'h:mm a' : 'HH:mm';
    return DateFormat(pattern, lang).format(dt);
  }

  String get formattedStartDate =>
      startDate.value == null ? '' : _formatDate(startDate.value!);
  String get formattedEndDate =>
      endDate.value == null ? '' : _formatDate(endDate.value!);
  String get formattedStartTime =>
      startTime.value == null ? '' : _formatTime(startTime.value!);
  String get formattedEndTime =>
      endTime.value == null ? '' : _formatTime(endTime.value!);

  /// Minimum allowed end time when start/end are same day.
  TimeOfDay? get minEndTime {
    if (startDate.value == null ||
        endDate.value == null ||
        startTime.value == null) {
      return null;
    }
    final sd = startDate.value!;
    final ed = endDate.value!;
    if (sd.year == ed.year && sd.month == ed.month && sd.day == ed.day) {
      final st = startTime.value!;
      final minutes = st.minute + 1;
      final hours = st.hour + (minutes ~/ 60);
      return TimeOfDay(hour: hours % 24, minute: minutes % 60);
    }
    return null;
  }

  @override
  void onInit() {
    super.onInit();
    // v565 — le résumé / la barre collante observent la ville.
    cityController.addListener(() {
      if (cityText.value != cityController.text) {
        cityText.value = cityController.text;
      }
    });
    // v441 — en mode édition, on pré-remplit les champs scalaires AVANT le
    // chargement des animaux (pas besoin d'attendre le réseau pour les dates /
    // service / localisation). La sélection des animaux est rétablie une fois
    // myPets chargé (cf loadMyPets).
    if (isEditMode) {
      _prefillFromEditPost();
    }
    loadMyPets();
  }

  /// v441 — pré-remplit tous les champs du formulaire à partir de l'annonce en
  /// cours d'édition (mode « Modifier »). Couvre dates+heures, type de service,
  /// durée (promenade), lieu de garde (serviceLocation), ville/GPS, notes et le
  /// toggle « Afficher le caractère des animaux ». La sélection des animaux est
  /// rétablie séparément une fois la liste myPets chargée.
  void _prefillFromEditPost() {
    final p = _editPost!;

    // Notes / détails : l'annonce stocke le texte libre dans `notes` (et le
    // recopie dans `body`). On pré-remplit avec notes en priorité, sinon body.
    final preset = p.notes.trim().isNotEmpty ? p.notes.trim() : p.body.trim();
    notesController.text = preset;

    // Type de service (premier élément de serviceTypes).
    if (p.serviceTypes.isNotEmpty) {
      selectedServiceType.value = p.serviceTypes.first.trim();
    }

    // Dates + heures (start/end). On extrait le TimeOfDay de chaque DateTime.
    if (p.startDate != null) {
      final s = p.startDate!;
      startDate.value = DateTime(s.year, s.month, s.day);
      startTime.value = TimeOfDay(hour: s.hour, minute: s.minute);
    }
    if (p.endDate != null) {
      final e = p.endDate!;
      endDate.value = DateTime(e.year, e.month, e.day);
      endTime.value = TimeOfDay(hour: e.hour, minute: e.minute);
    }

    // Promenade : recalcule la durée sélectionnée depuis l'écart start→end pour
    // que la puce de durée soit correctement mise en surbrillance.
    // v575 — audit P1-7 : la durée choisie par le propriétaire est désormais
    // stockée sur l'annonce ; on la relit en priorité.
    if (selectedServiceType.value == 'dog_walking') {
      final stored = p.walkDurationMinutes;
      if (stored != null && stored > 0) {
        selectedDuration.value = stored.toString();
      } else if (p.startDate != null && p.endDate != null) {
        final diffMin = p.endDate!.difference(p.startDate!).inMinutes;
        if (diffMin > 0) selectedDuration.value = diffMin.toString();
      }
    }

    // Lieu de garde (at_owner / at_sitter / both) ou de promenade
    // (pickup / meeting_point) — v587 : seulement s'il va avec le service.
    final svcLoc = p.serviceLocation?.trim();
    if (svcLoc != null &&
        svcLoc.isNotEmpty &&
        serviceLocationFits(selectedServiceType.value, svcLoc)) {
      serviceLocation.value = svcLoc;
    }
    final mp = p.meetingPoint?.trim() ?? '';
    if (mp.isNotEmpty) {
      meetingPointController.text = mp;
      meetingPointText.value = mp;
    }

    // Lieu de house-sitting legacy (owners_home / sitters_home).
    final venue = p.houseSittingVenue?.trim();
    if (venue != null && venue.isNotEmpty) {
      houseSittingVenue.value = venue;
    }

    // Ville + coordonnées GPS.
    final city = p.location?.city.trim() ?? '';
    if (city.isNotEmpty) {
      cityController.text = city;
      detectedCity.value = city;
    }
    if (p.location?.lat != null) userLat.value = p.location!.lat;
    if (p.location?.lng != null) userLng.value = p.location!.lng;

    // Toggle « Afficher le caractère des animaux ».
    showAnimalCharacter.value = p.showAnimalCharacter;
  }

  @override
  void onClose() {
    notesController.dispose();
    cityController.dispose();
    meetingPointController.dispose();
    addressController.dispose();
    super.onClose();
  }

  Future<void> loadMyPets() async {
    isPetsLoading.value = true;
    try {
      final response = await _petRepository.getMyPets();
      myPets.assignAll(response);
      // v441 — mode édition : rétablir la sélection des animaux de l'annonce
      // une fois la liste chargée. On matche par id ; on ne garde que les ids
      // qui existent encore dans myPets (un animal supprimé entre-temps est
      // simplement omis).
      if (isEditMode) {
        final existing = myPets.map((p) => p.id).toSet();
        final preselected = _editPost!.pets
            .map((p) => p.id)
            .where((id) => id.isNotEmpty && existing.contains(id))
            .toList();
        if (preselected.isNotEmpty) {
          selectedPetIds.assignAll(preselected);
        }
      }
    } catch (e) {
      AppLogger.logError('Failed to load owner pets', error: e);
      myPets.clear();
    } finally {
      isPetsLoading.value = false;
    }
  }

  void selectPet(String petId) {
    // v23.1 — toggle pet in/out of selectedPetIds. Tap a selected pet again
    // to deselect it (consistent with the existing send-request-direct flow).
    if (selectedPetIds.contains(petId)) {
      selectedPetIds.remove(petId);
    } else {
      selectedPetIds.add(petId);
    }
    if (selectedPetIds.isNotEmpty) petSelectionError.value = false;
  }

  void selectServiceType(String? value) {
    selectedServiceType.value = value;
    // Duration only applies to promenades.
    if (value != 'dog_walking') {
      selectedDuration.value = null;
    }
    // v587 — le lieu dépend du service : on garde le choix s'il va encore
    // (garderie ↔ garde multi-jours), sinon on le vide.
    if (!serviceLocationFits(value, serviceLocation.value)) {
      serviceLocation.value = null;
    }
    // house_sitting was merged into pet_sitting in the 2026 simplification;
    // always clear the legacy venue field when the type changes.
    houseSittingVenue.value = null;

    // Session v3.3 — auto-tuning of the end fields based on the service:
    //   * dog_walking: end = start + selected duration (computed below on
    //     start / duration change). UI hides the end fields entirely.
    //   * day_care: single-day event → copy start date to end date, let the
    //     user only pick the end hour.
    //   * pet_sitting (multi-day): keep existing behaviour (both dates).
    _recomputeEndForService();
  }

  void selectDuration(String? minutes) {
    selectedDuration.value = minutes;
    _recomputeEndForService();
  }

  /// Public hook called by the view after the user picked a start date/time.
  /// Triggers the same service-aware tuning as selectServiceType/selectDuration.
  void onDatesChanged() => _recomputeEndForService();

  /// Keeps end-date/time consistent with the service semantics so the owner
  /// doesn't have to input redundant fields. Called whenever service type,
  /// duration, start date or start time changes.
  void _recomputeEndForService() {
    final svc = selectedServiceType.value;
    if (svc == 'dog_walking') {
      // End computed from start + duration. No user input required.
      final s = startDate.value;
      final st = startTime.value;
      final d = selectedDuration.value;
      if (s != null && st != null && d != null && int.tryParse(d) != null) {
        final startDt = DateTime(s.year, s.month, s.day, st.hour, st.minute);
        final endDt = startDt.add(Duration(minutes: int.parse(d)));
        endDate.value = DateTime(endDt.year, endDt.month, endDt.day);
        endTime.value = TimeOfDay(hour: endDt.hour, minute: endDt.minute);
      } else {
        endDate.value = null;
        endTime.value = null;
      }
      return;
    }
    if (svc == 'day_care') {
      // Same-day event — align end date with start so the user only picks
      // the end hour. If no start date yet, leave both null.
      if (startDate.value != null) {
        endDate.value = startDate.value;
      }
      return;
    }
    // pet_sitting / unknown → no auto-tuning, user picks both.
  }

  void selectHouseSittingVenue(String? venue) {
    houseSittingVenue.value = venue;
  }

  Future<void> detectLocation() async {
    if (isGettingLocation.value) return;
    isGettingLocation.value = true;
    try {
      final data = await _locationService.getUserLocationWithCity();
      final city = (data?['city'] as String?)?.trim() ?? '';
      final street = (data?['street'] as String?)?.trim() ?? '';
      if (data != null) {
        // Les coordonnées servent au filtre distance même sans nom de ville.
        userLat.value = data['latitude'] as double?;
        userLng.value = data['longitude'] as double?;
      }
      if (city.isNotEmpty) {
        detectedCity.value = city;
        cityController.text = city;
        if (street.isNotEmpty) addressController.text = street;
        CustomSnackbar.showSuccess(
          title: 'location573_title'.tr,
          message: 'location573_found'.tr.replaceAll('{city}', city),
        );
      } else {
        // v573 — Daniel : « la localisation auto marche pas ». Avant, tout
        // échec (GPS coupé, permission, délai, ville introuvable) était muet.
        _showLocationFailure();
      }
    } catch (e) {
      AppLogger.logError('Failed to detect location', error: e);
      _showLocationFailure();
    } finally {
      isGettingLocation.value = false;
    }
  }

  void _showLocationFailure() {
    final String key = switch (_locationService.lastFailure) {
      'service_off' => 'location573_service_off',
      'denied' => 'location573_denied',
      'denied_forever' => 'location573_denied_forever',
      _ => 'location573_not_found',
    };
    CustomSnackbar.showWarning(
      title: 'location573_title'.tr,
      message: key.tr,
    );
  }

  Future<void> pickImages() async {
    try {
      final picked = await _imagePicker.pickMultiImage();
      if (picked.isEmpty) return;
      for (final x in picked) {
        if (x.path.isNotEmpty) {
          imageFiles.add(File(x.path));
        }
      }
    } catch (e) {
      AppLogger.logError('Failed to pick images', error: e);
    }
  }

  void removeImageAt(int index) {
    if (index < 0 || index >= imageFiles.length) return;
    imageFiles.removeAt(index);
  }

  bool get isFormComplete {
    return _firstMissingField() == null;
  }

  // ── v565 — aides pour l'écran en étapes (résumé + barre collante) ──────
  /// Premier champ manquant (null = formulaire complet), même règle que
  /// [submit]. Exposé pour la barre collante « Il manque : … ».
  String? get firstMissingField => _firstMissingField();

  /// Libellé lisible du champ manquant (9 langues).
  String missingFieldLabel(String field) => _missingFieldLabel(field);

  /// Étapes complétées : animaux / service / dates / ville. Les détails et
  /// les photos sont facultatifs.
  bool get stepPetsDone => selectedPetIds.isNotEmpty;
  bool get stepServiceDone {
    final st = selectedServiceType.value;
    if (st == null || st.trim().isEmpty) return false;
    if (st == 'dog_walking') {
      final d = selectedDuration.value;
      if (d == null || d.trim().isEmpty) return false;
    }
    if (st == 'house_sitting') {
      final v = houseSittingVenue.value;
      if (v == null || v.trim().isEmpty) return false;
    }
    if (!serviceLocationDone) return false;
    return true;
  }
  bool get stepDatesDone =>
      startDate.value != null &&
      endDate.value != null &&
      startTime.value != null &&
      endTime.value != null;
  /// Miroir réactif du champ ville (TextEditingController n'est pas Rx).
  final RxString cityText = ''.obs;
  bool get stepCityDone => cityText.value.trim().isNotEmpty;
  int get requiredStepsDone =>
      (stepPetsDone ? 1 : 0) +
      (stepServiceDone ? 1 : 0) +
      (stepDatesDone ? 1 : 0) +
      (stepCityDone ? 1 : 0);
  static const int requiredStepsTotal = 4;

  /// Libellé du service sélectionné (ou vide).
  String get selectedServiceLabel {
    final st = selectedServiceType.value;
    if (st == null) return '';
    for (final t in serviceTypes) {
      if (t['value'] == st) return t['label'] ?? st;
    }
    return st;
  }

  /// Noms des animaux sélectionnés (résumé).
  String get selectedPetNames => myPets
      .where((p) => selectedPetIds.contains(p.id))
      .map((p) => p.petName)
      .where((n) => n.trim().isNotEmpty)
      .join(', ');

  /// v22.1 — Bug 13c : retourne le NOM du premier champ manquant pour
  /// pouvoir afficher un message clair au user au lieu du générique
  /// "Veuillez remplir les champs requis". Returns null si tout est OK.
  String? _firstMissingField() {
    if (selectedPetIds.isEmpty) {
      return 'pet';
    }
    if (startDate.value == null) return 'startDate';
    if (endDate.value == null) return 'endDate';
    if (startTime.value == null) return 'startTime';
    if (endTime.value == null) return 'endTime';
    final st = selectedServiceType.value;
    if (st == null || st.trim().isEmpty) return 'serviceType';
    if (st == 'dog_walking') {
      final d = selectedDuration.value;
      if (d == null || d.trim().isEmpty) return 'duration';
    }
    if (st == 'house_sitting') {
      final venue = houseSittingVenue.value;
      if (venue == null || venue.trim().isEmpty) return 'venue';
    }
    if (!serviceLocationDone) {
      return serviceLocation.value == 'meeting_point'
          ? 'meetingPoint'
          : 'serviceLocation';
    }
    final city = cityController.text.trim();
    if (city.isEmpty) return 'city';
    return null;
  }

  String _missingFieldLabel(String field) {
    switch (field) {
      case 'pet':
        return 'publish_request_pet_required'.tr;
      case 'startDate':
        return 'publish_request_start_date_required'.tr;
      case 'endDate':
        return 'publish_request_end_date_required'.tr;
      case 'startTime':
        return 'publish_request_start_time_required'.tr;
      case 'endTime':
        return 'publish_request_end_time_required'.tr;
      case 'serviceType':
        return 'publish_request_service_required'.tr;
      case 'duration':
        return 'publish_request_duration_required'.tr;
      case 'venue':
        return 'publish_request_venue_required'.tr;
      case 'serviceLocation':
        return 'svc587_required'.tr;
      case 'meetingPoint':
        return 'svc587_meeting_required'.tr;
      case 'city':
        return 'publish_request_city_required'.tr;
      default:
        return 'publish_request_fill_required'.tr;
    }
  }

  Future<void> submit() async {
    if (isSubmitting.value) return;
    final isValid = formKey.currentState?.validate() ?? false;
    final missing = _firstMissingField();
    // v21 — flag the pet selector specifically if it's the missing field,
    // so the user sees a red border instead of just a generic snackbar.
    if (missing == 'pet') petSelectionError.value = true;
    if (!isValid || missing != null) {
      // v22.1 — Bug 13c : message clair indiquant LE champ manquant exact.
      CustomSnackbar.showWarning(
        title: 'send_request_validation_error_title'.tr,
        message: missing != null
            ? _missingFieldLabel(missing)
            : 'publish_request_fill_required'.tr,
      );
      return;
    }

    final notes = notesController.text.trim();
    // Localized default body — was 'Reservation request' in English only.
    final body = notes.isEmpty ? 'post_card_reservation_request'.tr : notes;
    final city = cityController.text.trim();
    final petIdsList = selectedPetIds.toList();

    // Combine selected date + time into full DateTime values
    DateTime combine(DateTime date, TimeOfDay time) {
      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    }

    final start = combine(startDate.value!, startTime.value!);
    final end = combine(endDate.value!, endTime.value!);

    final services = <String>[
      if (selectedServiceType.value != null &&
          selectedServiceType.value!.isNotEmpty)
        selectedServiceType.value!,
    ];
    final venue = selectedServiceType.value == 'house_sitting'
        ? houseSittingVenue.value
        : null;

    // v435 — Daniel : "Lieu de garde" choisi par l'owner pour garderie /
    // pet-sitting (at_owner / at_sitter / both). Avant, la valeur était
    // sélectionnée dans le formulaire mais JAMAIS envoyée → l'annonce
    // n'affichait jamais le lieu de garde. On le transmet désormais.
    final svcLocation = serviceLocationToSend;
    // v587 (point 8) — adresse du point de rendez-vous (promenade seulement).
    final meetingPoint = svcLocation == 'meeting_point'
        ? meetingPointText.value.trim()
        : null;

    // v575 — audit P1-7 : la durée de promenade choisie ici n'était JAMAIS
    // envoyée — l'annonce ne portait que start/end, et le prestataire la
    // devinait (mal). On la transmet, normalisée aux bornes du serveur.
    final walkMinutes = selectedServiceType.value == 'dog_walking'
        ? roundToWalkDuration(int.tryParse(selectedDuration.value ?? ''))
        : null;

    isSubmitting.value = true;
    try {
      if (isEditMode) {
        // v441 — mode « Modifier » : on met à jour l'annonce existante via
        // PUT /posts/:id (le backend refuse si la réservation est déjà payée).
        // Les photos ne sont pas ré-uploadées ici (l'UI masque la section
        // photos en édition) ; tous les autres champs du formulaire sont
        // persistés. Le lieu de garde city/lat/lng est ré-envoyé en bloc.
        final location = <String, dynamic>{
          'city': city,
          if (userLat.value != null) 'lat': userLat.value,
          if (userLng.value != null) 'lng': userLng.value,
        };
        await _postRepository.updatePost(
          editPostId,
          body: body,
          startDate: start,
          endDate: end,
          serviceTypes: services,
          petIds: petIdsList,
          location: location,
          notes: notes,
          houseSittingVenue: venue,
          serviceLocation: svcLocation,
          meetingPoint: meetingPoint,
          showAnimalCharacter: showAnimalCharacter.value,
          walkDurationMinutes: walkMinutes,
        );

        // v449 — Daniel : « modifier l'annonce MÊME les photos ». Si l'owner a
        // ajouté de nouvelles photos en édition, on les envoie (elles s'ajoutent
        // aux existantes). Best-effort : un échec photo ne casse pas la MAJ des
        // autres champs déjà enregistrés.
        if (imageFiles.isNotEmpty) {
          try {
            await _postRepository.addPostMedia(editPostId, imageFiles.toList());
          } catch (e) {
            AppLogger.logError('addPostMedia (edit) failed', error: e);
          }
        }

        await _refreshFeedsAfterPublish();

        CustomSnackbar.showSuccess(
          title: 'common_success'.tr,
          message: 'edit_post_saved'.tr,
        );
        Get.back();
        return;
      }

      if (imageFiles.isEmpty) {
        // v565 — lat/lng (détection GPS ou carte) envoyés avec la ville :
        // le serveur en a besoin pour prévenir les prestataires PROCHES
        // (repli sur la ville seule sinon).
        await _ownerRepository.createReservationRequest(
          body: body,
          startDate: start,
          endDate: end,
          serviceTypes: services,
          petIds: petIdsList,
          city: city,
          lat: userLat.value,
          lng: userLng.value,
          notes: notes,
          houseSittingVenue: venue,
          serviceLocation: svcLocation,
          meetingPoint: meetingPoint,
          showAnimalCharacter: showAnimalCharacter.value,
          walkDurationMinutes: walkMinutes,
        );
      } else {
        await _ownerRepository.createReservationRequestWithMedia(
          body: body,
          startDate: start,
          endDate: end,
          serviceTypes: services,
          petIds: petIdsList,
          city: city,
          lat: userLat.value,
          lng: userLng.value,
          notes: notes,
          houseSittingVenue: venue,
          serviceLocation: svcLocation,
          meetingPoint: meetingPoint,
          showAnimalCharacter: showAnimalCharacter.value,
          walkDurationMinutes: walkMinutes,
          imageFiles: imageFiles.toList(),
        );
      }

      // Session v15 — refresh the feeds BEFORE popping the screen so the user
      // lands back on "Mes publications" with the freshly-published request
      // already visible. Used to require a full logout/login to show up.
      await _refreshFeedsAfterPublish();

      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'publish_request_success'.tr,
      );
      Get.back();
    } on ApiException catch (error) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: error.message.isNotEmpty
            ? error.message
            : 'publish_request_error'.tr,
      );
    } catch (error) {
      AppLogger.logError('publish request failed', error: error);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'publish_request_error'.tr,
      );
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Re-fetches the feeds that depend on the list of reservation posts so a
  /// freshly-published request appears without requiring a logout/login.
  ///   • PostsController — drives "Mes publications" on the owner home.
  ///   • HomeController  — sitters/walkers listing (some UIs surface the
  ///     user's own post count in a header).
  Future<void> _refreshFeedsAfterPublish() async {
    try {
      if (Get.isRegistered<PostsController>()) {
        final pc = Get.find<PostsController>();
        // Use whichever "refresh" API the controller exposes.
        try {
          await pc.refreshPosts();
        } catch (_) {
          await pc.loadPostsWithoutMedia();
          await pc.loadMediaPosts();
        }
      }
      if (Get.isRegistered<HomeController>()) {
        final hc = Get.find<HomeController>();
        try {
          await hc.loadSitters();
        } catch (_) {/* ignore — best effort */}
      }
    } catch (e) {
      AppLogger.logError('refresh feeds after publish failed', error: e);
    }
  }
}
