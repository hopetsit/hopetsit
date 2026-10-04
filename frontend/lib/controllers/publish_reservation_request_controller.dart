import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/home_controller.dart';
import 'package:hopetsit/controllers/posts_controller.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/pet_model.dart';
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/repositories/pet_repository.dart';
import 'package:hopetsit/repositories/post_repository.dart';
import 'package:hopetsit/services/location_service.dart';
import 'package:hopetsit/services/supply_city600.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/publish_draft600.dart';
import 'package:hopetsit/utils/service_location587.dart';
import 'package:hopetsit/widgets/city_location_picker.dart'
    show cityPickedFromList610, markCityPicked610;
// v575 — audit P1-7 : bornes de durée de promenade partagées avec le serveur.
import 'package:hopetsit/utils/storage_keys.dart';
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
  // v587 (budget, option A de Daniel) — « Mon budget », facultatif : montant
  // dans la devise du propriétaire. Vide = pas de budget (bulle = icône).
  final budgetController = TextEditingController();
  final RxString budgetText = ''.obs;

  /// Montant saisi (virgule acceptée), ou null si vide / invalide / ≤ 0.
  double? get budgetAmount {
    final v = double.tryParse(
        budgetText.value.trim().replaceAll(' ', '').replaceAll(',', '.'));
    return (v != null && v > 0) ? v : null;
  }

  /// Devise du propriétaire (profil ; sinon celle de son pays ; sinon EUR).
  String get budgetCurrency {
    try {
      final p = GetStorage().read(StorageKeys.userProfile);
      if (p is Map) {
        final c = (p['currency'] ?? '').toString().toUpperCase();
        if (c.isNotEmpty) return c;
        final country = (p['country'] ?? p['countryCode'] ?? '').toString();
        if (country.isNotEmpty) return CurrencyHelper.fromCountry(country);
      }
    } catch (_) {}
    return 'EUR';
  }

  void onBudgetChanged(String v) => budgetText.value = v;
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

  // ── v600 NEO — publier SANS animal enregistré ─────────────────────────────
  // 17 propriétaires sur 20 n'ont jamais créé de fiche animal : le mur
  // « ajoute d'abord un animal » est tombé. Sans fiche, le bloc 1 propose
  // l'ESPÈCE (mêmes clés que le site) et le NOMBRE, envoyés au serveur en
  // `animalTypes` / `animalCount` (déjà acceptés par POST /posts et
  // /posts/with-media). Avec des fiches, on coche ses animaux comme avant.
  final RxList<String> animalTypes = <String>[].obs;
  final RxInt animalCount = 1.obs;
  static const int maxAnimalCount = 20;

  /// Vrai quand le formulaire passe par les puces d'espèce (aucune fiche
  /// animal chargée).
  bool get usesSpeciesPills => !isPetsLoading.value && myPets.isEmpty;

  void toggleSpecies(String species) {
    if (animalTypes.contains(species)) {
      animalTypes.remove(species);
    } else {
      animalTypes.add(species);
    }
    if (animalTypes.isNotEmpty) petSelectionError.value = false;
  }

  void setAnimalCount(int n) {
    animalCount.value = n.clamp(1, maxAnimalCount);
  }

  /// Résumé des animaux : noms des fiches cochées, sinon « 2 · Chien, Chat ».
  String get animalSummary {
    final names = selectedPetNames;
    if (names.isNotEmpty) return names;
    if (animalTypes.isEmpty) return '';
    final labels = animalTypes.map((s) => animalSpeciesI18nKey600(s).tr).join(', ');
    return '${animalCount.value} · $labels';
  }
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
  // v600 NEO — les heures par défaut s'affichent dès le premier rendu : si
  // les données de locale d'intl ne sont pas chargées (langue imprévue,
  // tests), on retombe sur un format simple plutôt que de planter l'écran.
  String _formatDate(DateTime d) {
    final lang = Get.locale?.languageCode ?? 'fr';
    try {
      return DateFormat('EEE, d MMM y', lang).format(d);
    } catch (_) {
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }
  }

  String _formatTime(TimeOfDay t) {
    final lang = Get.locale?.languageCode ?? 'fr';
    final dt = DateTime(0, 1, 1, t.hour, t.minute);
    // Formats 24h pour fr/de/es/it/pt, 12h avec AM/PM pour en.
    final pattern = lang == 'en' ? 'h:mm a' : 'HH:mm';
    try {
      return DateFormat(pattern, lang).format(dt);
    } catch (_) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
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

  /// v591 — ville à laquelle se rapportent userLat/userLng (en minuscules).
  String _coordsCity = '';

  @override
  void onInit() {
    super.onInit();
    // v565 — le résumé / la barre collante observent la ville.
    cityController.addListener(() {
      if (cityText.value != cityController.text) {
        cityText.value = cityController.text;
      }
      // v591 — audit du 26/09 : GPS puis autre ville tapée à la main → les
      // anciennes coordonnées partaient avec l'annonce (mauvais endroit sur la
      // carte). Ville changée = coordonnées oubliées ; le serveur géocode la
      // nouvelle ville.
      final typed = cityController.text.trim().toLowerCase();
      if (_coordsCity.isNotEmpty && typed != _coordsCity &&
          (userLat.value != null || userLng.value != null)) {
        userLat.value = null;
        userLng.value = null;
        _coordsCity = '';
      }
    });
    // v441 — en mode édition, on pré-remplit les champs scalaires AVANT le
    // chargement des animaux (pas besoin d'attendre le réseau pour les dates /
    // service / localisation). La sélection des animaux est rétablie une fois
    // myPets chargé (cf loadMyPets).
    if (isEditMode) {
      _prefillFromEditPost();
    } else {
      // v600 NEO — la ville du profil est pré-remplie (elle était vide alors
      // que le profil la connaît : une friction mesurée le 29/09). Le
      // propriétaire peut la changer ; sans coordonnées, le serveur géocode.
      final c = profileCity600();
      if (c.isNotEmpty && cityController.text.trim().isEmpty) {
        cityController.text = c;
        // v610 — ville du profil = ville déjà validée.
        markCityPicked610(cityController, c);
      }
      // v600 NEO — brouillon d'une demande interrompue (retour arrière,
      // fermeture de l'app) : proposé par l'écran (« Reprendre ma demande ? »).
      final d = readPublishDraft600();
      if (publishDraftIsMeaningful600(d)) {
        pendingDraft = d;
      } else {
        _draftReady = true;
      }
    }
    _watchDraft();
    loadMyPets();
  }

  // ── v600 NEO — brouillon local ────────────────────────────────────────────
  /// Brouillon trouvé à l'ouverture, en attente de la décision du
  /// propriétaire (« Reprendre » / « Recommencer »). Null sinon.
  Map<String, dynamic>? pendingDraft;
  bool _draftReady = false;
  Timer? _draftTimer;
  List<String> _draftPetIds = const <String>[];
  final List<Worker> _draftWorkers = <Worker>[];

  void _watchDraft() {
    if (isEditMode) return;
    _draftWorkers.add(everAll(<RxInterface>[
      startDate, endDate, startTime, endTime, selectedServiceType,
      selectedDuration, serviceLocation, animalTypes, animalCount,
      selectedPetIds, showAnimalCharacter, meetingPointText, budgetText,
      cityText,
    ], (_) => _scheduleDraftSave()));
    notesController.addListener(_scheduleDraftSave);
  }

  void _scheduleDraftSave() {
    if (isEditMode || !_draftReady) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 350), saveDraftNow);
  }

  /// Écrit le brouillon tout de suite (utile aux tests). Un formulaire qui ne
  /// porte rien de plus que le service pré-réglé n'est pas gardé.
  void saveDraftNow() {
    if (isEditMode || !_draftReady) return;
    final d = toDraft();
    if (publishDraftIsMeaningful600(d)) {
      writePublishDraft600(d);
    } else {
      clearPublishDraft600();
    }
  }

  String? _hm(TimeOfDay? t) => t == null
      ? null
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  TimeOfDay? _parseHm(Object? v) {
    if (v is! String || !v.contains(':')) return null;
    final p = v.split(':');
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  DateTime? _parseDay(Object? v) {
    if (v is! String || v.isEmpty) return null;
    final d = DateTime.tryParse(v);
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  /// Le formulaire tel qu'il est (sans les photos : un chemin de fichier
  /// temporaire ne survit pas à la fermeture de l'app).
  Map<String, dynamic> toDraft() => <String, dynamic>{
        'serviceType': selectedServiceType.value,
        'duration': selectedDuration.value,
        'serviceLocation': serviceLocation.value,
        'meetingPoint': meetingPointText.value.trim(),
        'startDate': startDate.value?.toIso8601String(),
        'endDate': endDate.value?.toIso8601String(),
        'startTime': _hm(startTime.value),
        'endTime': _hm(endTime.value),
        'city': cityController.text.trim(),
        'lat': userLat.value,
        'lng': userLng.value,
        'notes': notesController.text.trim(),
        'budget': budgetText.value.trim(),
        'animalTypes': animalTypes.toList(),
        'animalCount': animalCount.value,
        'petIds': selectedPetIds.toList(),
        'showAnimalCharacter': showAnimalCharacter.value,
      };

  /// « Reprendre » : remet le formulaire dans l'état du brouillon.
  void restoreDraft() {
    final d = pendingDraft;
    pendingDraft = null;
    if (d != null) applyDraft(d);
    _draftReady = true;
  }

  /// « Recommencer » : le brouillon est effacé, le formulaire reste tel quel.
  void discardDraft() {
    pendingDraft = null;
    clearPublishDraft600();
    _draftReady = true;
  }

  void applyDraft(Map<String, dynamic> d) {
    final st = (d['serviceType'] ?? '').toString();
    if (st.isNotEmpty) selectedServiceType.value = st;
    final du = (d['duration'] ?? '').toString();
    selectedDuration.value = du.isNotEmpty ? du : null;
    final sl = (d['serviceLocation'] ?? '').toString();
    serviceLocation.value =
        sl.isNotEmpty && serviceLocationFits(selectedServiceType.value, sl) ? sl : null;
    final mp = (d['meetingPoint'] ?? '').toString();
    meetingPointController.text = mp;
    meetingPointText.value = mp;
    startDate.value = _parseDay(d['startDate']);
    endDate.value = _parseDay(d['endDate']);
    startTime.value = _parseHm(d['startTime']);
    endTime.value = _parseHm(d['endTime']);
    final city = (d['city'] ?? '').toString();
    if (city.isNotEmpty) {
      cityController.text = city;
      final lat = d['lat'], lng = d['lng'];
      if (lat is num && lng is num) {
        userLat.value = lat.toDouble();
        userLng.value = lng.toDouble();
        _coordsCity = city.toLowerCase();
      }
    }
    notesController.text = (d['notes'] ?? '').toString();
    final b = (d['budget'] ?? '').toString();
    budgetController.text = b;
    budgetText.value = b;
    final at = d['animalTypes'];
    if (at is List) {
      animalTypes.assignAll(at.map((e) => e.toString()).where(kAnimalSpecies600.contains));
    }
    final ac = d['animalCount'];
    if (ac is num) setAnimalCount(ac.toInt());
    final ids = d['petIds'];
    if (ids is List) {
      _draftPetIds = ids.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
      // Les fiches sont peut-être déjà chargées (sinon : loadMyPets).
      final existing = myPets.map((p) => p.id).toSet();
      final keep = _draftPetIds.where(existing.contains).toList();
      if (keep.isNotEmpty) selectedPetIds.assignAll(keep);
    }
    final sac = d['showAnimalCharacter'];
    if (sac is bool) showAnimalCharacter.value = sac;
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
    // v587 — budget déjà saisi.
    if (p.budget > 0) {
      final txt = p.budget == p.budget.roundToDouble()
          ? p.budget.toStringAsFixed(0)
          : p.budget.toStringAsFixed(2);
      budgetController.text = txt;
      budgetText.value = txt;
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
    if (userLat.value != null) _coordsCity = city.toLowerCase();

    // Toggle « Afficher le caractère des animaux ».
    showAnimalCharacter.value = p.showAnimalCharacter;

    // v600 NEO — demande publiée sans fiche animal : espèces + nombre.
    if (p.animalTypes.isNotEmpty) {
      animalTypes.assignAll(p.animalTypes.where(kAnimalSpecies600.contains));
    }
    if (p.animalCount > 0) setAnimalCount(p.animalCount);
  }

  @override
  void onClose() {
    // v600 NEO — retour arrière ou fermeture : le brouillon est écrit une
    // dernière fois (le débounce n'a peut-être pas encore tiré).
    _draftTimer?.cancel();
    if (_draftReady && !isEditMode) saveDraftNow();
    for (final w in _draftWorkers) {
      w.dispose();
    }
    notesController.removeListener(_scheduleDraftSave);
    notesController.dispose();
    cityController.dispose();
    meetingPointController.dispose();
    budgetController.dispose();
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
      } else if (_draftPetIds.isNotEmpty) {
        // v600 NEO — fiches cochées dans le brouillon, rétablies une fois la
        // liste connue (un animal supprimé entre-temps est simplement omis).
        final existing = myPets.map((p) => p.id).toSet();
        final keep = _draftPetIds.where(existing.contains).toList();
        if (keep.isNotEmpty) selectedPetIds.assignAll(keep);
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

    // v600 NEO — garde / garderie : heures 8 h – 20 h par défaut, modifiables
    // en un appui (4 sélecteurs date+heure obligatoires = friction mesurée).
    // Promenade : l'heure compte, aucune valeur par défaut ; si les heures
    // sont encore celles posées par défaut, on les retire.
    if (!isEditMode) {
      if (value == 'pet_sitting' || value == 'day_care') {
        startTime.value ??= const TimeOfDay(hour: kDefaultStartHour600, minute: 0);
        endTime.value ??= const TimeOfDay(hour: kDefaultEndHour600, minute: 0);
      } else if (value == 'dog_walking' && hasDefaultHours) {
        startTime.value = null;
        endTime.value = null;
      }
    }

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

  /// v600 NEO — les heures affichées sont-elles encore celles par défaut ?
  bool get hasDefaultHours {
    final s = startTime.value, e = endTime.value;
    return s != null &&
        e != null &&
        s.hour == kDefaultStartHour600 &&
        s.minute == 0 &&
        e.hour == kDefaultEndHour600 &&
        e.minute == 0;
  }

  /// Public hook called by the view after the user picked a start date/time.
  /// Triggers the same service-aware tuning as selectServiceType/selectDuration.
  void onDatesChanged() {
    // v600 NEO — garde multi-jours : la date de fin suit la date de début
    // (le lendemain) tant que le propriétaire ne l'a pas choisie.
    if (!isEditMode &&
        selectedServiceType.value == 'pet_sitting' &&
        startDate.value != null &&
        endDate.value == null) {
      endDate.value = startDate.value!.add(const Duration(days: 1));
    }
    _recomputeEndForService();
  }

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
        // v610 — « Ma position » = ville validée (posée AVANT le texte, pour
        // que la barre « Il manque » se mette à jour dans la même image).
        markCityPicked610(cityController, city);
        detectedCity.value = city;
        _coordsCity = city.toLowerCase();
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
  bool get stepPetsDone =>
      selectedPetIds.isNotEmpty || (usesSpeciesPills && animalTypes.isNotEmpty);
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
  // v610 — la ville doit être CHOISIE (liste, position, carte), pas tapée.
  bool get stepCityDone =>
      cityText.value.trim().isNotEmpty && cityPickedFromList610(cityController);
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
      // v600 NEO — sans fiche animal, l'espèce suffit ; avec des fiches, on
      // en coche au moins une (comportement conservé).
      if (!usesSpeciesPills) return 'pet';
      if (animalTypes.isEmpty) return 'species';
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
    // v610 (Daniel, 04/10 : « on peut écrire n'importe quoi ») — texte tapé
    // sans choisir une ville de la liste : refusé.
    cityText.value; // lecture réactive (barre collante)
    if (!cityPickedFromList610(cityController)) return 'cityPick';
    return null;
  }

  String _missingFieldLabel(String field) {
    switch (field) {
      case 'pet':
        return 'publish_request_pet_required'.tr;
      case 'species':
        return 'neo600_species_required'.tr;
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
      case 'cityPick':
        return 'city610_missing_label'.tr;
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
    if (missing == 'pet' || missing == 'species') petSelectionError.value = true;
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

    // v600 NEO — sans fiche animal : espèce(s) + nombre partent avec la
    // demande (mêmes champs que le site). Avec des fiches cochées, le serveur
    // lit les animaux dans petIds comme avant.
    final List<String> speciesToSend =
        petIdsList.isEmpty ? animalTypes.toList() : const <String>[];
    final int? countToSend = petIdsList.isEmpty ? animalCount.value : null;

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
          // v587 — 0 = budget effacé.
          budget: budgetAmount ?? 0,
          budgetCurrency: budgetCurrency,
          animalTypes: speciesToSend,
          animalCount: countToSend,
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

      // v600 NEO — « Envoyée à N gardiens et promeneurs » : N vient de la
      // réponse du serveur si elle le dit un jour, sinon de /supply/city
      // (demandé en parallèle de l'envoi, jamais bloquant).
      final Future<int?> supplyFuture = fetchSupplyTotal600(city);
      Map<String, dynamic> created;
      if (imageFiles.isEmpty) {
        // v565 — lat/lng (détection GPS ou carte) envoyés avec la ville :
        // le serveur en a besoin pour prévenir les prestataires PROCHES
        // (repli sur la ville seule sinon).
        created = await _ownerRepository.createReservationRequest(
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
          budget: budgetAmount,
          budgetCurrency: budgetCurrency,
          animalTypes: speciesToSend,
          animalCount: countToSend,
        );
      } else {
        created = await _ownerRepository.createReservationRequestWithMedia(
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
          budget: budgetAmount,
          budgetCurrency: budgetCurrency,
          imageFiles: imageFiles.toList(),
          animalTypes: speciesToSend,
          animalCount: countToSend,
        );
      }

      // v600 NEO — la demande est partie : plus de brouillon, et la pop-up
      // « Un cadeau pour toi » attend (elle recouvrait la demande fraîche).
      _draftReady = false;
      clearPublishDraft600();
      snoozePromoPopup600();

      // Session v15 — refresh the feeds BEFORE popping the screen so the user
      // lands back on "Mes publications" with the freshly-published request
      // already visible. Used to require a full logout/login to show up.
      await _refreshFeedsAfterPublish();

      final int? notified = notifiedCountFromResponse(created) ??
          await supplyFuture.timeout(const Duration(seconds: 3),
              onTimeout: () => null);
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: notified != null && notified > 0
            ? 'neo600_sent_to'.tr.replaceAll('{n}', '$notified')
            : 'publish_request_success'.tr,
      );
      // v600 NEO — l'accueil lit ce résultat pour rester sur « Mes demandes ».
      Get.back(result: kPublishedResult600);
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

  /// v600 NEO — valeur rendue par `Get.back` après une publication réussie.
  static const String kPublishedResult600 = 'published600';

  /// v600 NEO — nombre de prestataires prévenus si le serveur le renvoie
  /// (`notified`, `notifiedCount`, ou dans `post`) ; null sinon.
  static int? notifiedCountFromResponse(Map<String, dynamic> res) {
    int? pick(Object? v) => v is num && v > 0 ? v.toInt() : null;
    final direct = pick(res['notified']) ?? pick(res['notifiedCount']);
    if (direct != null) return direct;
    final post = res['post'];
    if (post is Map) {
      return pick(post['notified']) ?? pick(post['notifiedCount']);
    }
    return null;
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
