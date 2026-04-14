import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/sitter_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/repositories/pet_repository.dart';
import 'package:hopetsit/models/pet_model.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/views/pet_owner/bottom_nav/bottom_nav_wrapper.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

class SendRequestController extends GetxController {
  final String serviceProviderName;
  final String serviceProviderId;

  SendRequestController({
    required this.serviceProviderName,
    required this.serviceProviderId,
    OwnerRepository? ownerRepository,
  }) : _ownerRepository = ownerRepository ?? Get.find<OwnerRepository>();

  final OwnerRepository _ownerRepository;

  final formKey = GlobalKey<FormState>();
  final petNameController = TextEditingController();
  final descriptionController = TextEditingController();

  final Rxn<DateTime> selectedDate = Rxn<DateTime>();
  final Rx<DateTime> focusedDate =
      DateTime.now().obs; // UI focus for week strip

  /// Start/End date and time for Dates section (image layout)
  final Rxn<DateTime> startDate = Rxn<DateTime>();
  final Rxn<DateTime> endDate = Rxn<DateTime>();
  final Rxn<TimeOfDay> startTime = Rxn<TimeOfDay>();
  final Rxn<TimeOfDay> endTime = Rxn<TimeOfDay>();

  /// Daily Times section (start/end time for the day)
  final Rxn<TimeOfDay> dailyStartTime = Rxn<TimeOfDay>();
  final Rxn<TimeOfDay> dailyEndTime = Rxn<TimeOfDay>();

  /// If true, time slot is optional and will not be required on submit
  final RxBool isAllDay = true.obs;

  /// Validation error message for date/time validation
  final RxnString dateTimeValidationError = RxnString();

  final RxnString selectedTimeSlot = RxnString('allday');
  final RxnString selectedServiceType = RxnString();
  final RxnString selectedDuration =
      RxnString(); // For dog_walking: '30' or '60'
  final RxnString houseSittingVenue = RxnString();
  final RxBool isLoading = false.obs;
  final RxBool _petNameHasText = false.obs;
  final RxBool _descriptionHasText = false.obs;
  final Rxn<SitterModel> _sitter = Rxn<SitterModel>();

  final List<String> timeSlots = const [
    '11:30 AM',
    '12:00 PM',
    '12:30 PM',
    '1:00 PM',
    '1:30 PM',
    '2:00 PM',
    '3:00 PM',
  ];

  /// Service types matching image: Long Term Care, Dog Walking, Overnight Stay, Home Visit
  List<Map<String, String>> get serviceTypes => [
    {'value': 'long_stay', 'label': 'send_request_service_long_term_care'.tr},
    {'value': 'dog_walking', 'label': 'send_request_service_dog_walking'.tr},
    {'value': 'overnight_stay', 'label': 'send_request_service_overnight_stay'.tr},
    {'value': 'home_visit', 'label': 'send_request_service_home_visit'.tr},
  ];

  @override
  void onInit() {
    super.onInit();
    // Clear all fields when screen is opened
    _clearAllFields();
    // Listen to text changes to make button reactive
    petNameController.addListener(_onPetNameChanged);
    descriptionController.addListener(_onDescriptionChanged);
    // Fetch sitter details to get hourly rate for basePrice
    _loadSitterDetails();
    // Load owner's pets for dropdown
    loadMyPets();
  }

  Future<void> _loadSitterDetails() async {
    try {
      final sitterData = await _ownerRepository.getSitterDetail(
        serviceProviderId,
      );
      _sitter.value = sitterData;
    } catch (e) {
      // Silently fail - basePrice will use a default value
      AppLogger.logError(
        'Failed to load sitter details for basePrice',
        error: e,
      );
    }
  }

  @override
  void onClose() {
    petNameController.removeListener(_onPetNameChanged);
    descriptionController.removeListener(_onDescriptionChanged);
    petNameController.dispose();
    descriptionController.dispose();
    super.onClose();
  }

  void _onPetNameChanged() {
    _petNameHasText.value = petNameController.text.trim().isNotEmpty;
  }

  void _onDescriptionChanged() {
    _descriptionHasText.value = descriptionController.text.trim().isNotEmpty;
  }

  void selectTimeSlot(String timeSlot) {
    selectedTimeSlot.value = timeSlot;
  }

  void selectServiceType(String serviceType) {
    selectedServiceType.value = serviceType;
    // Clear duration when service type changes
    if (serviceType != 'dog_walking') {
      selectedDuration.value = null;
    }
    if (serviceType != 'house_sitting') {
      houseSittingVenue.value = null;
    }
  }

  void selectDuration(String duration) {
    selectedDuration.value = duration;
  }

  void selectHouseSittingVenue(String venue) {
    houseSittingVenue.value = venue;
  }

  // My pets (for dropdown). API expects petIds array (at least one).
  final RxList<PetModel> myPets = <PetModel>[].obs;
  final RxBool isPetsLoading = false.obs;
  final RxList<String> selectedPetIds = <String>[].obs;

  Future<void> loadMyPets() async {
    isPetsLoading.value = true;
    try {
      final repo = Get.find<PetRepository>();
      final response = await repo.getMyPets();
      myPets.assignAll(response);
    } catch (e) {
      AppLogger.logError('Failed to load owner pets', error: e);
      myPets.clear();
    } finally {
      isPetsLoading.value = false;
    }
  }

  void selectPet(String? petId) {
    if (petId == null || petId == 'other') {
      selectedPetIds.clear();
      petNameController.clear();
    } else {
      selectedPetIds.assignAll([petId]);
      final matches = myPets.where((p) => p.id == petId);
      if (matches.isNotEmpty) {
        petNameController.text = matches.first.petName;
      }
    }
  }

  // UI helpers: week dates and day selection/focus
  List<DateTime> weekDates() {
    final center = focusedDate.value;
    final DateTime today = DateTime.now();
    final DateTime todayDateOnly = DateTime(today.year, today.month, today.day);
    DateTime start = center.subtract(Duration(days: 3));
    if (start.isBefore(todayDateOnly)) {
      start = todayDateOnly;
    }
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  void setFocusedDate(DateTime d) {
    focusedDate.value = DateTime(d.year, d.month, d.day);
  }

  void toggleDaySelection(DateTime d) {
    final exists =
        selectedDate.value != null &&
        selectedDate.value!.year == d.year &&
        selectedDate.value!.month == d.month &&
        selectedDate.value!.day == d.day;

    if (exists) {
      selectedDate.value = null;
    } else {
      selectedDate.value = DateTime(d.year, d.month, d.day);
    }

    // Always set focus to tapped day
    setFocusedDate(d);
  }

  void toggleAllDay() => isAllDay.value = !isAllDay.value;

  bool canSendRequest({bool requireTimeSlot = true}) {
    final dateSet = (startDate.value ?? selectedDate.value) != null;
    final timeSet =
        !requireTimeSlot ||
        (startTime.value != null) ||
        (selectedTimeSlot.value != null && selectedTimeSlot.value!.isNotEmpty);
    final hasAllRequiredFields =
        (_petNameHasText.value || selectedPetIds.isNotEmpty) &&
        _descriptionHasText.value &&
        dateSet &&
        timeSet &&
        selectedServiceType.value != null &&
        selectedServiceType.value!.isNotEmpty;

    // If dog_walking is selected, duration is required
    if (selectedServiceType.value == 'dog_walking') {
      return hasAllRequiredFields &&
          selectedDuration.value != null &&
          selectedDuration.value!.isNotEmpty;
    }
    if (selectedServiceType.value == 'house_sitting') {
      return hasAllRequiredFields &&
          houseSittingVenue.value != null &&
          houseSittingVenue.value!.isNotEmpty;
    }

    return hasAllRequiredFields;
  }

  /// Returns true if duration field should be shown (for dog_walking)
  bool get shouldShowDuration => selectedServiceType.value == 'dog_walking';
  bool get shouldShowHouseSittingVenue =>
      selectedServiceType.value == 'house_sitting';

  /// Formats selected date to display format (e.g., "Thu, Apr 25, 2024")
  String get formattedDate {
    if (selectedDate.value == null) return '';
    return _formatDate(selectedDate.value!);
  }

  static const List<String> _weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const List<String> _months = [
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

  String get formattedStartDate =>
      startDate.value == null ? '' : _formatDate(startDate.value!);
  String get formattedEndDate =>
      endDate.value == null ? '' : _formatDate(endDate.value!);

  String _formatTime(TimeOfDay t) {
    final h24 = t.hour;
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final am = h24 < 12 ? 'AM' : 'PM';
    return '$h12:$m $am';
  }

  String get formattedStartTime =>
      startTime.value == null ? '' : _formatTime(startTime.value!);
  String get formattedEndTime =>
      endTime.value == null ? '' : _formatTime(endTime.value!);

  /// Combines date and time into a single DateTime object
  DateTime? _combineDateTime(DateTime? date, TimeOfDay? time) {
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  /// Gets the combined start DateTime
  DateTime? get startDateTime =>
      _combineDateTime(startDate.value, startTime.value);

  /// Gets the combined end DateTime
  DateTime? get endDateTime => _combineDateTime(endDate.value, endTime.value);

  /// Validates that End DateTime is after Start DateTime
  bool validateDateTimeRange() {
    dateTimeValidationError.value = null;

    // If both dates/times are not set, validation passes (will be caught by required field validation)
    if (startDate.value == null ||
        startTime.value == null ||
        endDate.value == null ||
        endTime.value == null) {
      return true;
    }

    final start = startDateTime!;
    final end = endDateTime!;

    if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
      dateTimeValidationError.value = 'End time must be after start time.';
      return false;
    }

    return true;
  }

  /// Gets the minimum time that can be selected for End Time
  /// Returns null if no restriction, otherwise returns the minimum allowed TimeOfDay
  TimeOfDay? get minEndTime {
    if (startDate.value == null ||
        endDate.value == null ||
        startTime.value == null) {
      return null;
    }

    // Only restrict if End Date is the same as Start Date
    if (startDate.value!.year == endDate.value!.year &&
        startDate.value!.month == endDate.value!.month &&
        startDate.value!.day == endDate.value!.day) {
      // Return time that is 1 minute after start time
      final start = startTime.value!;
      final minutes = start.minute + 1;
      final hours = start.hour + (minutes ~/ 60);
      return TimeOfDay(hour: hours % 24, minute: minutes % 60);
    }

    return null;
  }

  String get formattedDailyStartTime =>
      dailyStartTime.value == null ? '' : _formatTime(dailyStartTime.value!);
  String get formattedDailyEndTime =>
      dailyEndTime.value == null ? '' : _formatTime(dailyEndTime.value!);

  /// Selected pets count for Pets field display (image shows "2")
  int get selectedPetsCount => selectedPetIds.length;

  Future<void> sendRequest({
    bool isAllDay = true,
    DateTime? fallbackDate,
  }) async {
    // Prefer startDate/startTime from Dates section; fallback to selectedDate/selectedTimeSlot
    final effectiveDate = startDate.value ?? selectedDate.value;
    if (effectiveDate == null && fallbackDate != null) {
      selectedDate.value = DateTime(
        fallbackDate.year,
        fallbackDate.month,
        fallbackDate.day,
      );
    } else if (effectiveDate != null) {
      selectedDate.value = effectiveDate;
    }
    if (startTime.value != null) {
      selectedTimeSlot.value = _formatTime(startTime.value!);
    }

    // Validate date/time range first
    if (!validateDateTimeRange()) {
      CustomSnackbar.showError(
        title: 'request_validation_error'.tr,
        message:
            dateTimeValidationError.value ??
            'send_request_invalid_time_message'.tr,
      );
      return;
    }

    if (!canSendRequest(requireTimeSlot: !isAllDay)) {
      final missing = _missingFields(requireTimeSlot: !isAllDay);
      final message = missing.isEmpty
          ? 'Please fill in all required fields'
          : 'Please fill: ${missing.join(', ')}';

      CustomSnackbar.showWarning(title: 'request_validation_error'.tr, message: message);

      // Log validation state for debugging
      AppLogger.logUserAction(
        'SendRequest validation failed',
        data: {
          'petName': petNameController.text.trim(),
          'description': descriptionController.text.trim(),
          'selectedDate': selectedDate.value?.toIso8601String(),
          'selectedTimeSlot': selectedTimeSlot.value,
          'selectedServiceType': selectedServiceType.value,
          'selectedDuration': selectedDuration.value,
          'requireTimeSlot': !isAllDay,
          'fallbackDate': fallbackDate?.toIso8601String(),
        },
      );

      return;
    }

    isLoading.value = true;

    try {
      // Format the selected date to ISO 8601 format
      final serviceDate = _formatDateToISO(selectedDate.value!);

      // Full start/end instants for backend (matches sitter application + agreement API).
      final String startDateIso = startDateTime != null
          ? startDateTime!.toUtc().toIso8601String()
          : _formatDateToISO(startDate.value ?? selectedDate.value!);
      final String? endDateIso = endDateTime != null
          ? endDateTime!.toUtc().toIso8601String()
          : (endDate.value != null ? _formatDateToISO(endDate.value!) : null);

      // Legacy request field: backend may ignore this when computing tiered pricing.
      // Prefer hourly, then weekly, then monthly so sitters with only long-term rates still work.
      double basePrice = _referenceRateForBookingPayload(_sitter.value);
      if (basePrice <= 0) {
        try {
          final sitterData = await _ownerRepository.getSitterDetail(
            serviceProviderId,
          );
          _sitter.value = sitterData;
          basePrice = _referenceRateForBookingPayload(sitterData);
          if (basePrice <= 0 && sitterData.rate != null) {
            basePrice = double.tryParse(sitterData.rate!) ?? basePrice;
          }
        } catch (e) {
          AppLogger.logError(
            'Failed to refresh sitter details before sending request',
            error: e,
          );
        }
      }

      if (basePrice <= 0) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'request_sitter_pricing_error'.tr,
        );
        return;
      }

      // Validate duration for dog_walking
      if (selectedServiceType.value == 'dog_walking') {
        if (selectedDuration.value == null || selectedDuration.value!.isEmpty) {
          CustomSnackbar.showError(
            title: 'request_validation_error'.tr,
            message: 'request_duration_required'.tr,
          );
          return;
        }
      }

      final petIds = selectedPetIds.toList();
      if (petIds.isEmpty) {
        CustomSnackbar.showError(
          title: 'request_validation_error'.tr,
          message: 'request_pet_required'.tr,
        );
        return;
      }

      // Log the booking creation
      final logData = {
        'sitterId': serviceProviderId,
        'petIds': petIds,
        'description': descriptionController.text.trim(),
        'serviceDate': serviceDate,
        'startDate': startDateIso,
        if (endDateIso != null) 'endDate': endDateIso,
        'timeSlot': selectedTimeSlot.value ?? '',
        'serviceType': selectedServiceType.value ?? '',
        'basePrice': basePrice,
        if (selectedServiceType.value == 'house_sitting')
          'houseSittingVenue': houseSittingVenue.value ?? '',
      };
      if (selectedServiceType.value == 'dog_walking' &&
          selectedDuration.value != null) {
        logData['duration'] = selectedDuration.value!;
      }
      AppLogger.logUserAction('Creating Booking', data: logData);

      await _ownerRepository.createBooking(
        sitterId: serviceProviderId,
        petIds: petIds,
        description: descriptionController.text.trim(),
        serviceDate: serviceDate,
        timeSlot: selectedTimeSlot.value!,
        serviceType: selectedServiceType.value!,
        basePrice: basePrice,
        duration: selectedServiceType.value == 'dog_walking'
            ? selectedDuration.value
            : null,
        startDate: startDateIso,
        endDate: endDateIso,
        houseSittingVenue: selectedServiceType.value == 'house_sitting'
            ? houseSittingVenue.value
            : null,
      );

      // Clear all fields before showing success message
      _clearAllFields();

      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'request_send_success'.tr,
      );

      // Navigate to home screen after a short delay to ensure snackbar is visible
      await Future.delayed(const Duration(milliseconds: 500));
      Get.offAll(() => const BottomNavWrapper());
    } on ApiException catch (error) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: error.message,
      );
    } catch (e) {
      AppLogger.logError('Failed to send request', error: e);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'request_send_failed'.tr,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Formats DateTime to ISO 8601 format (e.g., "2025-11-22T00:00:00.000Z")
  String _formatDateToISO(DateTime date) {
    // Format to ISO 8601 with time set to midnight UTC
    return date
        .toUtc()
        .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
        .toIso8601String();
  }

  /// Returns list of missing required fields for validation
  List<String> _missingFields({bool requireTimeSlot = true}) {
    final missing = <String>[];
    if (!_petNameHasText.value && selectedPetIds.isEmpty) missing.add('Pets');
    if (!_descriptionHasText.value) missing.add('Description');
    if (startDate.value == null && selectedDate.value == null)
      missing.add('Start date');
    if (requireTimeSlot &&
        startTime.value == null &&
        (selectedTimeSlot.value == null || selectedTimeSlot.value!.isEmpty))
      missing.add('Time');
    if (selectedServiceType.value == null || selectedServiceType.value!.isEmpty)
      missing.add('Service type');
    if (selectedServiceType.value == 'dog_walking' &&
        (selectedDuration.value == null || selectedDuration.value!.isEmpty))
      missing.add('Duration');
    if (selectedServiceType.value == 'house_sitting' &&
        (houseSittingVenue.value == null || houseSittingVenue.value!.isEmpty)) {
      missing.add('Venue');
    }
    return missing;
  }

  /// Value for legacy `basePrice` on create-booking; tiered totals come from the API response.
  double _referenceRateForBookingPayload(SitterModel? s) {
    if (s == null) return 0;
    if (s.hourlyRate > 0) return s.hourlyRate;
    if (s.weeklyRate > 0) return s.weeklyRate;
    if (s.monthlyRate > 0) return s.monthlyRate;
    return 0;
  }

  /// Clears all form fields
  void _clearAllFields() {
    petNameController.clear();
    descriptionController.clear();
    selectedDate.value = null;
    startDate.value = null;
    endDate.value = null;
    startTime.value = null;
    endTime.value = null;
    dailyStartTime.value = null;
    dailyEndTime.value = null;
    selectedTimeSlot.value = null;
    selectedServiceType.value = null;
    selectedDuration.value = null;
    houseSittingVenue.value = null;
    selectedPetIds.clear();
  }
}
