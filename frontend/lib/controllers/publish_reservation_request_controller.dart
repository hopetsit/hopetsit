import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/models/pet_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/controllers/posts_controller.dart';
import 'package:hopetsit/repositories/pet_repository.dart';
import 'package:hopetsit/services/location_service.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:image_picker/image_picker.dart';

class PublishReservationRequestController extends GetxController {
  PublishReservationRequestController({
    PetRepository? petRepository,
    LocationService? locationService,
    ImagePicker? imagePicker,
    OwnerRepository? ownerRepository,
  }) : _petRepository = petRepository ?? Get.find<PetRepository>(),
       _locationService = locationService ?? LocationService(),
       _imagePicker = imagePicker ?? ImagePicker(),
       _ownerRepository = ownerRepository ?? Get.find<OwnerRepository>();

  final PetRepository _petRepository;
  final LocationService _locationService;
  final ImagePicker _imagePicker;
  final OwnerRepository _ownerRepository;

  final formKey = GlobalKey<FormState>();

  // Form fields
  final notesController = TextEditingController();
  final cityController = TextEditingController();
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
  final RxnString selectedPetId = RxnString();

  final RxBool isGettingLocation = false.obs;
  final RxString detectedCity = ''.obs;
  final RxnDouble userLat = RxnDouble();
  final RxnDouble userLng = RxnDouble();

  final RxBool isSubmitting = false.obs;

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
  bool get shouldShowServiceLocation =>
      selectedServiceType.value == 'day_care' ||
      selectedServiceType.value == 'pet_sitting';

  // Legacy flag kept for backward-compat callers; house_sitting is no longer
  // a selectable type post-simplification, so this now always returns false.
  bool get shouldShowHouseSittingVenue => false;

  static const List<String> _weekdays = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatDate(DateTime d) {
    final weekday = _weekdays[d.weekday - 1];
    return '$weekday, ${_months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _formatTime(TimeOfDay t) {
    final h24 = t.hour;
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final am = h24 < 12 ? 'AM' : 'PM';
    return '$h12:$m $am';
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
    loadMyPets();
  }

  @override
  void onClose() {
    notesController.dispose();
    cityController.dispose();
    addressController.dispose();
    super.onClose();
  }

  Future<void> loadMyPets() async {
    isPetsLoading.value = true;
    try {
      final response = await _petRepository.getMyPets();
      myPets.assignAll(response);
    } catch (e) {
      AppLogger.logError('Failed to load owner pets', error: e);
      myPets.clear();
    } finally {
      isPetsLoading.value = false;
    }
  }

  void selectPet(String petId) {
    selectedPetId.value = petId;
  }

  void selectServiceType(String? value) {
    selectedServiceType.value = value;
    // Duration only applies to promenades.
    if (value != 'dog_walking') {
      selectedDuration.value = null;
    }
    // Service location only applies to daycare / pet_sitting.
    if (value != 'day_care' && value != 'pet_sitting') {
      serviceLocation.value = null;
    }
    // house_sitting was merged into pet_sitting in the 2026 simplification;
    // always clear the legacy venue field when the type changes.
    houseSittingVenue.value = null;
  }

  void selectDuration(String? minutes) {
    selectedDuration.value = minutes;
  }

  void selectHouseSittingVenue(String? venue) {
    houseSittingVenue.value = venue;
  }

  Future<void> detectLocation() async {
    isGettingLocation.value = true;
    try {
      final data = await _locationService.getUserLocationWithCity();
      if (data != null) {
        final city = (data['city'] as String?)?.trim() ?? '';
        final street = (data['street'] as String?)?.trim() ?? '';
        detectedCity.value = city;
        userLat.value = data['latitude'] as double?;
        userLng.value = data['longitude'] as double?;

        if (city.isNotEmpty) {
          cityController.text = city;
        }
        if (street.isNotEmpty) {
          addressController.text = street;
        }
      }
    } catch (e) {
      AppLogger.logError('Failed to detect location', error: e);
    } finally {
      isGettingLocation.value = false;
    }
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
    if (selectedPetId.value == null || selectedPetId.value!.isEmpty) {
      return false;
    }
    if (startDate.value == null ||
        endDate.value == null ||
        startTime.value == null ||
        endTime.value == null) {
      return false;
    }
    final st = selectedServiceType.value;
    if (st == null || st.trim().isEmpty) return false;
    if (st == 'dog_walking') {
      final d = selectedDuration.value;
      if (d == null || d.trim().isEmpty) return false;
    }
    if (st == 'house_sitting') {
      final venue = houseSittingVenue.value;
      if (venue == null || venue.trim().isEmpty) return false;
    }
    // City is validated by the form via CityLocationPicker.
    return true;
  }

  Future<void> submit() async {
    final isValid = formKey.currentState?.validate() ?? false;
    if (!isValid || !isFormComplete || isSubmitting.value) {
      if (!isValid || !isFormComplete) {
        CustomSnackbar.showWarning(
          title: 'send_request_validation_error_title'.tr,
          message: 'publish_request_fill_required'.tr,
        );
      }
      return;
    }

    final notes = notesController.text.trim();
    // Localized default body — was 'Reservation request' in English only.
    final body = notes.isEmpty ? 'post_card_reservation_request'.tr : notes;
    final city = cityController.text.trim();
    final petId = selectedPetId.value!;

    // Combine selected date + time into full DateTime values
    DateTime _combine(DateTime date, TimeOfDay time) {
      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    }

    final start = _combine(startDate.value!, startTime.value!);
    final end = _combine(endDate.value!, endTime.value!);

    final services = <String>[
      if (selectedServiceType.value != null &&
          selectedServiceType.value!.isNotEmpty)
        selectedServiceType.value!,
    ];
    final venue = selectedServiceType.value == 'house_sitting'
        ? houseSittingVenue.value
        : null;

    isSubmitting.value = true;
    try {
      if (imageFiles.isEmpty) {
        await _ownerRepository.createReservationRequest(
          body: body,
          startDate: start,
          endDate: end,
          serviceTypes: services,
          petId: petId,
          city: city,
          lat: userLat.value,
          lng: userLng.value,
          notes: notes.isEmpty ? null : notes,
          houseSittingVenue: venue,
          serviceLocation: serviceLocation.value,
        );
      } else {
        await _ownerRepository.createReservationRequestWithMedia(
          body: body,
          startDate: start,
          endDate: end,
          serviceTypes: services,
          petId: petId,
          city: city,
          lat: userLat.value,
          lng: userLng.value,
          notes: notes.isEmpty ? null : notes,
          houseSittingVenue: venue,
          serviceLocation: serviceLocation.value,
          imageFiles: imageFiles.toList(),
        );
      }

      clearAll();

      // Reload posts so My Posts screen and feeds see the new reservation
      if (Get.isRegistered<PostsController>()) {
        await Get.find<PostsController>().refreshPosts();
      }

      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        // Always use app key so success snackbar follows current locale.
        message: 'publish_request_success'.tr,
      );

      Get.back();
    } catch (e) {
      AppLogger.logError('Failed to submit reservation request', error: e);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'request_send_failed'.tr,
      );
    } finally {
      isSubmitting.value = false;
    }
  }

  void clearAll() {
    notesController.clear();
    cityController.clear();
    addressController.clear();
    startDate.value = null;
    endDate.value = null;
    startTime.value = null;
    endTime.value = null;
    selectedServiceType.value = null;
    selectedDuration.value = null;
    houseSittingVenue.value = null;
    selectedPetId.value = null;
    imageFiles.clear();
    detectedCity.value = '';
    userLat.value = null;
    userLng.value = null;
  }
}
