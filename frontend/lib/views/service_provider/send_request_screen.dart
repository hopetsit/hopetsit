import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/send_request_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_text_field.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/views/profile/my_pets_screen.dart';

class SendRequestScreen extends StatefulWidget {
  final String serviceProviderName;
  final String serviceProviderId;

  /// Session v15-3 — role of the recipient ('walker' or 'sitter').
  /// Controls which services are offered in the chip row. Defaults to
  /// 'sitter' so legacy callers (e.g. pets_map_screen) keep working.
  final String serviceProviderRole;

  /// Optional rate hints passed from the card so we can compute a live
  /// "Total estimé" without a second API call. Null = rate unknown →
  /// the estimate row shows "À confirmer avec le prestataire".
  final double? sitterDailyRate;
  final double? sitterWeeklyRate;
  final double? sitterMonthlyRate;
  final double? walkerHalfHourRate;
  final double? walkerHourlyRate;
  final String? currencyCode; // e.g. "EUR", defaults to EUR

  const SendRequestScreen({
    super.key,
    required this.serviceProviderName,
    required this.serviceProviderId,
    this.serviceProviderRole = 'sitter',
    this.sitterDailyRate,
    this.sitterWeeklyRate,
    this.sitterMonthlyRate,
    this.walkerHalfHourRate,
    this.walkerHourlyRate,
    this.currencyCode,
  });

  @override
  State<SendRequestScreen> createState() => _SendRequestScreenState();
}

class _SendRequestScreenState extends State<SendRequestScreen> {
  /// Session v15-3 — the whole request screen now echoes the card color:
  ///   • walker  → green (matches WalkerCard CTA and the home segment)
  ///   • sitter  → blue  (matches SitterCard CTA and the home segment)
  /// The primaryColor red is kept out of this screen to avoid 3 competing
  /// accent colors on the Owner side.
  Color get _roleColor => widget.serviceProviderRole == 'walker'
      ? AppColors.greenColor
      : const Color(0xFF1A73E8);

  @override
  Widget build(BuildContext context) {
    // Delete existing controller if it exists to ensure fresh state
    final tag = 'send_request_${widget.serviceProviderId}';
    if (Get.isRegistered<SendRequestController>(tag: tag)) {
      Get.delete<SendRequestController>(tag: tag);
    }

    final controller = Get.put(
      SendRequestController(
        serviceProviderName: widget.serviceProviderName,
        serviceProviderId: widget.serviceProviderId,
        serviceProviderRole: widget.serviceProviderRole,
      ),
      tag: tag,
    );

    return Scaffold(
      // v18.9.7 — léger background neutre pour contraster avec les cards.
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.scaffold(context),
        elevation: 0,
        iconTheme: IconThemeData(color: _roleColor),
        leading: BackButton(),
        title: PoppinsText(
          text: 'send_request_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // v18.9.7 — chaque section dans une card propre avec icône
                // + titre. Avant c'était à plat avec labels en texte.
                _sectionCard(
                  context: context,
                  icon: Icons.pets_rounded,
                  title: 'label_pets'.tr,
                  child: _buildPetsSection(context, controller),
                ),
                SizedBox(height: 14.h),

                // v20.0.14 — Service type en 2ème position (juste après
                // les pets). Avant c'était après les dates et l'utilisateur
                // devait redéfiler pour comprendre quel format de dates
                // attendre. Maintenant : on choisit d'abord le service →
                // les dates s'adaptent (Garderie = 1 jour, Multi-jours =
                // plage, Promenade = début + durée).
                Obx(() => _sectionCard(
                      context: context,
                      icon: Icons.work_outline_rounded,
                      title: 'send_request_service_type_label'.tr,
                      child: _buildServiceTypeSection(controller),
                      hasError: controller.attemptedSubmit.value &&
                          (controller.selectedServiceType.value ?? '')
                              .isEmpty,
                    )),
                SizedBox(height: 14.h),

                Obx(() {
                  final svc = (controller.selectedServiceType.value ?? '')
                      .toLowerCase();
                  final isWalker = widget.serviceProviderRole == 'walker';
                  final isDayCare =
                      svc == 'day_care' || svc == 'garderie';
                  final missingDates = controller.startDate.value == null ||
                      controller.startTime.value == null ||
                      (isDayCare && controller.endTime.value == null) ||
                      (!isWalker &&
                          !isDayCare &&
                          (controller.endDate.value == null ||
                              controller.endTime.value == null));
                  return _sectionCard(
                    context: context,
                    icon: Icons.calendar_today_rounded,
                    title: 'send_request_dates_label'.tr,
                    child: _buildDatesSection(context, controller),
                    hasError:
                        controller.attemptedSubmit.value && missingDates,
                  );
                }),
                SizedBox(height: 14.h),

                _sectionCard(
                  context: context,
                  icon: Icons.edit_note_rounded,
                  title: 'send_request_description_label'.tr,
                  child: CustomTextField(
                    labelText: '',
                    controller: controller.descriptionController,
                    hintText: 'send_request_description_hint'.tr,
                    maxLines: 4,
                    radius: 21,
                  ),
                ),
                SizedBox(height: 14.h),

                Obx(
                  () => controller.shouldShowHouseSittingVenue
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionCard(
                              context: context,
                              icon: Icons.home_outlined,
                              title: 'house_sitting_venue_label'.tr,
                              child: _buildHouseSittingVenueSection(controller),
                            ),
                            SizedBox(height: 14.h),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),

                Obx(
                  () => controller.shouldShowDuration
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionCard(
                              context: context,
                              icon: Icons.timer_outlined,
                              title: 'send_request_duration_label'.tr,
                              child: _buildDurationSection(controller),
                            ),
                            SizedBox(height: 14.h),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),

                // Total estimé — version premium card gradient couleur rôle.
                _buildEstimatedTotalSection(context, controller),

                SizedBox(height: 40.h),

                // Send Request Button
                Obx(
                  () => CustomButton(
                    title: controller.isLoading.value
                        ? null
                        : 'send_request_button'.tr,
                    onTap: controller.isLoading.value
                        ? null
                        : () {
                            // v20.0.14 — check required sections before
                            // sending. If any missing, turn them orange via
                            // attemptedSubmit.
                            final missingService =
                                (controller.selectedServiceType.value ?? '')
                                    .isEmpty;
                            final svc = (controller
                                        .selectedServiceType.value ??
                                    '')
                                .toLowerCase();
                            final isDayCare = svc == 'day_care' ||
                                svc == 'garderie';
                            final isWalker =
                                widget.serviceProviderRole == 'walker';
                            final missingStartDate =
                                controller.startDate.value == null;
                            final missingStartTime =
                                controller.startTime.value == null;
                            final missingEnd = !isWalker &&
                                !isDayCare &&
                                (controller.endDate.value == null ||
                                    controller.endTime.value == null);
                            final missingEndTimeDayCare = isDayCare &&
                                controller.endTime.value == null;
                            final hasAnyMissing = missingService ||
                                missingStartDate ||
                                missingStartTime ||
                                missingEnd ||
                                missingEndTimeDayCare;
                            if (hasAnyMissing) {
                              controller.attemptedSubmit.value = true;
                              CustomSnackbar.showError(
                                title:
                                    'send_request_validation_error_title'.tr,
                                message:
                                    'send_request_fill_required_fields'.tr,
                              );
                              return;
                            }
                            if (controller.dateTimeValidationError.value !=
                                null) {
                              CustomSnackbar.showError(
                                title:
                                    'send_request_validation_error_title'.tr,
                                message: controller
                                    .dateTimeValidationError.value!,
                              );
                              return;
                            }
                            controller.sendRequest(
                              isAllDay: controller.isAllDay.value,
                              fallbackDate: controller.focusedDate.value,
                            );
                          },
                    bgColor: _roleColor,
                    textColor: AppColors.whiteColor,
                    height: 48.h,
                    radius: 48.r,
                    // Show loading indicator in button
                    child: controller.isLoading.value
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20.w,
                                height: 20.h,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.whiteColor,
                                  ),
                                ),
                              ),
                              SizedBox(width: 10.w),
                              InterText(
                                text: 'send_request_button_sending'.tr,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                                color: AppColors.whiteColor,
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// v18.9.7 — wrapper card uniforme pour toutes les sections du formulaire
  /// Envoyer une demande. Icône circulaire en couleur rôle + titre en bold +
  /// contenu. Remplace l'ancien layout plat avec labels texte.
  Widget _sectionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Widget child,
    // v20.0.14 — if true the card is outlined in orange to signal a missing field
    bool hasError = false,
  }) {
    final errorColor = const Color(0xFFF59E0B); // amber-500
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: hasError
                ? errorColor.withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: hasError ? 14 : 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: hasError
              ? errorColor
              : AppColors.divider(context).withValues(alpha: 0.5),
          width: hasError ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: _roleColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18.sp, color: _roleColor),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: PoppinsText(
                  text: title,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          child,
        ],
      ),
    );
  }

  Widget _buildPetsSection(
    BuildContext context,
    SendRequestController controller,
  ) {
    return Obx(() {
      if (controller.isPetsLoading.value) {
        return Container(
          height: 50.h,
          decoration: BoxDecoration(
            color: AppColors.inputFill(context),
            borderRadius: BorderRadius.circular(30.r),
            border: Border.all(color: AppColors.divider(context), width: 1),
          ),
          child: const Center(child: CircularProgressIndicator()),
        );
      }
      if (controller.myPets.isEmpty) {
        return GestureDetector(
          onTap: () => Get.to(() => const MyPetsScreen()),
          child: Container(
            height: 50.h,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: AppColors.inputFill(context),
              borderRadius: BorderRadius.circular(30.r),
              border: Border.all(color: AppColors.divider(context), width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InterText(
                    text: 'send_request_no_pets_message'.tr,
                    fontSize: 14.sp,
                    color: AppColors.greyColor,
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14.sp,
                  color: AppColors.greyColor,
                ),
              ],
            ),
          ),
        );
      }
      final items = controller.myPets
          .map(
            (p) => DropdownMenuItem<String>(
              value: p.id,
              child: Text('${p.petName} • ${p.breed}'),
            ),
          )
          .toList();
      final count = controller.selectedPetsCount;
      final displayText = count > 0 ? '$count' : 'common_select'.tr;
      return Container(
        height: 50.h,
        decoration: BoxDecoration(
          color: AppColors.inputFill(context),
          borderRadius: BorderRadius.circular(30.r),
          border: Border.all(color: AppColors.divider(context), width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: controller.selectedPetIds.isNotEmpty
                      ? controller.selectedPetIds.first
                      : null,
                  items: items,
                  onChanged: (v) => controller.selectPet(v),
                  isExpanded: true,
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  hint: InterText(
                    text: displayText,
                    fontSize: 14.sp,
                    color: AppColors.greyColor,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => Get.to(() => const MyPetsScreen()),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 14.sp,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildDatesSection(
    BuildContext context,
    SendRequestController controller,
  ) {
    final isWalker = widget.serviceProviderRole == 'walker';
    return Obx(() {
      controller.startDate.value;
      controller.endDate.value;
      controller.startTime.value;
      controller.endTime.value;

      // v20.0.14 — layout des dates adapté au service choisi :
      //   - Walker (dog_walking)        : 1 date + 1 heure début (durée séparée)
      //   - Garderie (day_care)         : 1 date + heure début + heure fin (même jour)
      //   - Multi-jours (pet_sitting/boarding) : début (date+heure) + fin (date+heure)
      final service =
          (controller.selectedServiceType.value ?? '').toLowerCase();
      final isDayCare = service == 'day_care' || service == 'garderie';
      final isMultiDay = !isWalker && !isDayCare;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Start label + pill
          Row(
            children: [
              Container(
                width: 6.w,
                height: 6.w,
                decoration: BoxDecoration(
                  color: _roleColor,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8.w),
              InterText(
                text: isDayCare
                    ? 'send_request_day_label'.tr
                    : 'send_request_start_label'.tr,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          _buildDateTimeRow(
            dateText: controller.formattedStartDate.isEmpty
                ? 'send_request_select_date'.tr
                : controller.formattedStartDate,
            timeText: controller.formattedStartTime.isEmpty
                ? 'send_request_select_time'.tr
                : controller.formattedStartTime,
            isDatePlaceholder: controller.formattedStartDate.isEmpty,
            isTimePlaceholder: controller.formattedStartTime.isEmpty,
            onDateTap: () =>
                _pickDate(context, controller, isStart: true),
            onTimeTap: () =>
                _pickTime(context, controller, isStart: true),
          ),
          if (isDayCare) ...[
            SizedBox(height: 14.h),
            // Garderie : seulement une heure de fin (même jour), pas de 2e date.
            Row(
              children: [
                Container(
                  width: 6.w,
                  height: 6.w,
                  decoration: BoxDecoration(
                    color: _roleColor,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8.w),
                InterText(
                  text: 'send_request_end_time_same_day'.tr,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            _buildDateTimeRow(
              dateText: '', // hidden
              timeText: controller.formattedEndTime.isEmpty
                  ? 'send_request_select_time'.tr
                  : controller.formattedEndTime,
              isDatePlaceholder: false,
              isTimePlaceholder: controller.formattedEndTime.isEmpty,
              onDateTap: null, // disabled — same day as start
              onTimeTap: () =>
                  _pickTime(context, controller, isStart: false),
              hideDate: true,
            ),
          ],
          if (isMultiDay) ...[
            SizedBox(height: 14.h),
            // End label + pill
            Row(
              children: [
                Container(
                  width: 6.w,
                  height: 6.w,
                  decoration: BoxDecoration(
                    color: _roleColor,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8.w),
                InterText(
                  text: 'send_request_end_label'.tr,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            _buildDateTimeRow(
              dateText: controller.formattedEndDate.isEmpty
                  ? 'send_request_select_date'.tr
                  : controller.formattedEndDate,
              timeText: controller.formattedEndTime.isEmpty
                  ? 'send_request_select_time'.tr
                  : controller.formattedEndTime,
              isDatePlaceholder: controller.formattedEndDate.isEmpty,
              isTimePlaceholder: controller.formattedEndTime.isEmpty,
              onDateTap: () =>
                  _pickDate(context, controller, isStart: false),
              onTimeTap: () =>
                  _pickTime(context, controller, isStart: false),
            ),
          ],
          // Show validation error message if exists
          Obx(() {
            final error = controller.dateTimeValidationError.value;
            if (error == null || error.isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded,
                      size: 14.sp, color: AppColors.errorColor),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: InterText(
                      text: error,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.errorColor,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      );
    });
  }

  /// One row inside the dates container: date (left) | vertical line | time (right) | arrow.
  /// v20.0.14 — add `hideDate` for Garderie layout (time only, full-width).
  Widget _buildDateTimeRow({
    required String dateText,
    required String timeText,
    required bool isDatePlaceholder,
    required bool isTimePlaceholder,
    required VoidCallback? onDateTap,
    required VoidCallback onTimeTap,
    bool hideDate = false,
  }) {
    return Container(
      height: 50.h,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: AppColors.inputFill(context),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.divider(context), width: 1),
      ),
      child: Row(
        children: [
          if (!hideDate) ...[
            Expanded(
              child: GestureDetector(
                onTap: onDateTap,
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: InterText(
                    text: dateText,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    color: isDatePlaceholder
                        ? AppColors.textSecondary(context)
                        : AppColors.textPrimary(context),
                  ),
                ),
              ),
            ),
            Container(
              width: 1,
              height: 24.h,
              margin: EdgeInsets.symmetric(horizontal: 12.w),
              color: AppColors.divider(context),
            ),
          ],
          Expanded(
            child: GestureDetector(
              onTap: onTimeTap,
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: InterText(
                  text: timeText,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: isTimePlaceholder
                      ? AppColors.textSecondary(context)
                      : AppColors.textPrimary(context),
                ),
              ),
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 14.sp,
            color: AppColors.greyColor,
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    SendRequestController controller, {
    required bool isStart,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          (isStart ? controller.startDate.value : controller.endDate.value) ??
          now,
      firstDate: now,
      lastDate: DateTime(now.year + 1, now.month, now.day),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _roleColor,
              onPrimary: AppColors.whiteColor,
              surface: AppColors.whiteColor,
              onSurface: AppColors.blackColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      if (isStart) {
        controller.startDate.value = picked;
        // Clear validation error when start date changes
        controller.dateTimeValidationError.value = null;
      } else {
        controller.endDate.value = picked;
        // Clear validation error when end date changes
        controller.dateTimeValidationError.value = null;
        // If end date is before start date, reset end date to start date
        if (controller.startDate.value != null &&
            picked.isBefore(controller.startDate.value!)) {
          controller.endDate.value = controller.startDate.value;
        }
      }
      controller.selectedDate.value = picked;
      controller.setFocusedDate(picked);
      // Session v15-3 — walker has no End UI, so we mirror Start→End here.
      controller.syncWalkerEnd();
      // Trigger validation after date change
      controller.validateDateTimeRange();
    }
  }

  Future<void> _pickTime(
    BuildContext context,
    SendRequestController controller, {
    required bool isStart,
  }) async {
    final now = TimeOfDay.now();
    TimeOfDay? initialTime;
    TimeOfDay? minTime;

    if (isStart) {
      initialTime = controller.startTime.value ?? now;
    } else {
      initialTime = controller.endTime.value ?? now;
      // Get minimum allowed time for End Time
      minTime = controller.minEndTime;
      // If minTime is set and initialTime is before it, use minTime as initial
      if (minTime != null) {
        final initialMinutes = initialTime.hour * 60 + initialTime.minute;
        final minMinutes = minTime.hour * 60 + minTime.minute;
        if (initialMinutes < minMinutes) {
          initialTime = minTime;
        }
      }
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      initialEntryMode: TimePickerEntryMode.input,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: Theme(
            data: Theme.of(context).copyWith(
              timePickerTheme: TimePickerThemeData(
                backgroundColor: AppColors.whiteColor,
                hourMinuteShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                hourMinuteColor: WidgetStateColor.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? _roleColor
                        : AppColors.lightGrey),
                hourMinuteTextColor: WidgetStateColor.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? AppColors.whiteColor
                        : AppColors.blackColor),
                dialHandColor: _roleColor,
                dialBackgroundColor: AppColors.lightGrey,
                entryModeIconColor: _roleColor,
                helpTextStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.grey700Color,
                ),
              ),
              colorScheme: ColorScheme.light(
                primary: _roleColor,
                onPrimary: AppColors.whiteColor,
                surface: AppColors.whiteColor,
                onSurface: AppColors.blackColor,
              ),
            ),
            child: child!,
          ),
        );
      },
    );
    if (picked != null) {
      if (isStart) {
        controller.startTime.value = picked;
        // Clear validation error when start time changes
        controller.dateTimeValidationError.value = null;
        // If end time exists and is now invalid, clear it
        if (controller.endTime.value != null) {
          final endDateTime = controller.endDateTime;
          final startDateTime = controller.startDateTime;
          if (endDateTime != null &&
              startDateTime != null &&
              (endDateTime.isBefore(startDateTime) ||
                  endDateTime.isAtSameMomentAs(startDateTime))) {
            controller.endTime.value = null;
          }
        }
      } else {
        // Validate that picked time is after start time if same date
        final minEndTime = controller.minEndTime;
        if (minEndTime != null) {
          final pickedMinutes = picked.hour * 60 + picked.minute;
          final minMinutes = minEndTime.hour * 60 + minEndTime.minute;
          if (pickedMinutes < minMinutes) {
            // Show error and don't set the time
            controller.dateTimeValidationError.value =
                'send_request_invalid_time_message'.tr;
            CustomSnackbar.showError(
              title: 'send_request_invalid_time_title'.tr,
              message: 'send_request_invalid_time_message'.tr,
            );
            return;
          }
        }
        controller.endTime.value = picked;
        // Clear validation error when end time changes
        controller.dateTimeValidationError.value = null;
      }
      // Session v15-3 — walker has no End UI; keep endTime in sync.
      controller.syncWalkerEnd();
      // Trigger validation after time change
      controller.validateDateTimeRange();
    }
  }

  /// v18.9.7 — icône spécifique par service type pour rendre les chips
  /// plus lisibles et engageants.
  IconData _serviceTypeIcon(String value) {
    switch (value) {
      case 'dog_walking':
        return Icons.directions_walk_rounded;
      case 'day_care':
      case 'pet_sitting':
        return Icons.home_work_outlined;
      case 'house_sitting':
      case 'long_stay':
      case 'long_term_care':
        return Icons.hotel_outlined;
      case 'overnight_stay':
        return Icons.nightlight_round;
      case 'home_visit':
        return Icons.house_outlined;
      default:
        return Icons.pets_rounded;
    }
  }

  Widget _buildServiceTypeSection(SendRequestController controller) {
    return Obx(
      () => Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: controller.serviceTypes.map((serviceType) {
          final isSelected =
              controller.selectedServiceType.value == serviceType['value'];
          return GestureDetector(
            onTap: () => controller.selectServiceType(serviceType['value']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: isSelected ? _roleColor : AppColors.inputFill(context),
                borderRadius: BorderRadius.circular(22.r),
                border: Border.all(
                  color: isSelected ? _roleColor : AppColors.divider(context),
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: _roleColor.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _serviceTypeIcon(serviceType['value'] ?? ''),
                    size: 15.sp,
                    color: isSelected
                        ? AppColors.whiteColor
                        : _roleColor,
                  ),
                  SizedBox(width: 6.w),
                  InterText(
                    text: serviceType['label']!,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppColors.whiteColor
                        : AppColors.textPrimary(context),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDurationSection(SendRequestController controller) {
    return Obx(
      () => Wrap(
        spacing: 10.w,
        runSpacing: 10.h,
        // Session v15-3 — align walk duration presets with the Publish flow
        // (publish_reservation_request_controller.promenadeMinutes).
        children: const ['30', '60', '90', '120'].map((duration) {
          final isSelected = controller.selectedDuration.value == duration;
          return GestureDetector(
            onTap: () => controller.selectDuration(duration),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(
                horizontal: 14.w,
                vertical: 10.h,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? _roleColor
                    : AppColors.inputFill(context),
                borderRadius: BorderRadius.circular(22.r),
                border: Border.all(
                  color: isSelected
                      ? _roleColor
                      : AppColors.divider(context),
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: _roleColor.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 15.sp,
                    color: isSelected
                        ? AppColors.whiteColor
                        : _roleColor,
                  ),
                  SizedBox(width: 6.w),
                  InterText(
                    text: 'send_request_duration_minutes_label'.trParams({
                      'minutes': duration,
                    }),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppColors.whiteColor
                        : AppColors.textPrimary(context),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHouseSittingVenueSection(SendRequestController controller) {
    const options = <Map<String, String>>[
      {'value': 'owners_home', 'label': 'house_sitting_venue_owners_home', 'icon': 'owner'},
      {'value': 'sitters_home', 'label': 'house_sitting_venue_sitters_home', 'icon': 'sitter'},
    ];
    return Obx(
      () => Wrap(
        spacing: 10.w,
        runSpacing: 10.h,
        children: options.map((opt) {
          final value = opt['value']!;
          final selected = controller.houseSittingVenue.value == value;
          final icon = opt['icon'] == 'owner'
              ? Icons.home_outlined
              : Icons.night_shelter_outlined;
          return GestureDetector(
            onTap: () => controller.selectHouseSittingVenue(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: selected ? _roleColor : AppColors.inputFill(context),
                borderRadius: BorderRadius.circular(22.r),
                border: Border.all(
                  color: selected
                      ? _roleColor
                      : AppColors.divider(context),
                  width: 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: _roleColor.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 15.sp,
                    color: selected ? AppColors.whiteColor : _roleColor,
                  ),
                  SizedBox(width: 6.w),
                  InterText(
                    text: opt['label']!.tr,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.whiteColor
                        : AppColors.textPrimary(context),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Live "Total estimé" card — re-computed on every relevant Rx change.
  /// Formula:
  ///   • dog_walking : 1 balade = durationMinutes → walkerHalfHourRate (30 min)
  ///                   or walkerHourlyRate (60 min). × nbPets × nbJours
  ///   • pet_sitting / house_sitting / day_care / long_stay :
  ///     nbJours × sitterDailyRate
  /// Null rate → "À confirmer avec le prestataire".
  Widget _buildEstimatedTotalSection(
    BuildContext context,
    SendRequestController controller,
  ) {
    return Obx(() {
      final service = controller.selectedServiceType.value;
      final sDate = controller.startDate.value;
      final eDate = controller.endDate.value;
      final duration = controller.selectedDuration.value; // "30" / "60" / "90"…

      // v18.9.8 — commission 20% payée PAR L'OWNER au-dessus du tarif
      // prestataire. L'estimateur affiche désormais le total owner TTC.
      const double commissionRate = 0.20;
      final currency = widget.currencyCode ?? 'EUR';

      String? totalText;
      String? breakdown;
      double? providerGross; // ce que le prestataire reçoit net

      if (service == 'dog_walking') {
        // v18.8 — estimateur strict : on ne montre un total que si la
        // durée sélectionnée a un tarif EXPLICITE côté walker (walkRate
        // enabled). Sinon on affiche "À confirmer avec le prestataire".
        final minutes = int.tryParse(duration ?? '') ?? 0;
        final halfHour = widget.walkerHalfHourRate;
        final hour = widget.walkerHourlyRate;
        String? notSetNotice;
        if (minutes > 0) {
          if (minutes == 30) {
            if (halfHour != null && halfHour > 0) {
              providerGross = halfHour;
            } else {
              notSetNotice = 'send_request_duration_rate_missing'.tr;
            }
          } else if (minutes == 60) {
            if (hour != null && hour > 0) {
              providerGross = hour;
            } else {
              notSetNotice = 'send_request_duration_rate_missing'.tr;
            }
          } else if (minutes == 90) {
            if (hour != null && hour > 0 &&
                halfHour != null && halfHour > 0) {
              providerGross = hour + halfHour;
            } else {
              notSetNotice = 'send_request_duration_rate_missing'.tr;
            }
          } else if (minutes == 120) {
            if (hour != null && hour > 0) {
              providerGross = hour * 2;
            } else {
              notSetNotice = 'send_request_duration_rate_missing'.tr;
            }
          }
        }
        if (providerGross != null && providerGross > 0) {
          final commission = providerGross * commissionRate;
          final ownerTotal = providerGross + commission;
          totalText = '${ownerTotal.toStringAsFixed(2)} $currency';
          breakdown =
              '$minutes min · ${providerGross.toStringAsFixed(2)} $currency prestataire + ${commission.toStringAsFixed(2)} $currency commission (20%)';
        } else if (notSetNotice != null) {
          breakdown = notSetNotice;
        }
      } else if (service != null && service.isNotEmpty) {
        if (sDate != null && eDate != null) {
          final raw = eDate.difference(sDate).inDays;
          final days = raw > 0 ? raw : 1;
          double? dailyRate = widget.sitterDailyRate;
          if (dailyRate == null || dailyRate <= 0) {
            if (widget.sitterWeeklyRate != null &&
                widget.sitterWeeklyRate! > 0) {
              dailyRate = widget.sitterWeeklyRate! / 7;
            } else if (widget.sitterMonthlyRate != null &&
                widget.sitterMonthlyRate! > 0) {
              dailyRate = widget.sitterMonthlyRate! / 30;
            }
          }
          if (dailyRate != null && dailyRate > 0) {
            providerGross = dailyRate * days;
            final commission = providerGross * commissionRate;
            final ownerTotal = providerGross + commission;
            totalText = '${ownerTotal.toStringAsFixed(2)} $currency';
            breakdown =
                '$days jour${days > 1 ? 's' : ''} × ${dailyRate.toStringAsFixed(2)} $currency/j + ${commission.toStringAsFixed(2)} $currency commission (20%)';
          }
        }
      }

      // v20.0.12 — card modernisée avec breakdown 3 lignes clair :
      //   - Tu paies (owner total)           → gros chiffre accent rôle
      //   - Prestataire touche (net)         → ligne verte check
      //   - Commission HoPetSit (20%)        → ligne grise info
      final commission =
          providerGross != null ? providerGross * commissionRate : 0.0;
      final ownerTotal =
          providerGross != null ? providerGross + commission : 0.0;
      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _roleColor.withValues(alpha: 0.10),
              _roleColor.withValues(alpha: 0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
              color: _roleColor.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _roleColor.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header : icône + label
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(
                    color: _roleColor,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(Icons.euro_rounded,
                      size: 18.sp, color: Colors.white),
                ),
                SizedBox(width: 10.w),
                InterText(
                  text: 'send_request_total_estimated'.tr,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary(context),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            // Grand total — tu paies
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PoppinsText(
                  text: totalText ?? 'À confirmer',
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w800,
                  color: _roleColor,
                ),
                if (totalText != null) ...[
                  SizedBox(width: 8.w),
                  Padding(
                    padding: EdgeInsets.only(bottom: 6.h),
                    child: InterText(
                      text: 'send_request_owner_pays'.tr,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 12.h),
            // Breakdown lines
            if (providerGross != null && providerGross > 0) ...[
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  children: [
                    _buildBreakdownRow(
                      context,
                      icon: Icons.check_circle_rounded,
                      iconColor: const Color(0xFF16A34A),
                      label: 'send_request_provider_receives'.tr,
                      amount:
                          '${providerGross.toStringAsFixed(2)} $currency',
                      boldAmount: true,
                    ),
                    SizedBox(height: 8.h),
                    _buildBreakdownRow(
                      context,
                      icon: Icons.percent_rounded,
                      iconColor: AppColors.textSecondary(context),
                      label: 'send_request_commission_label'.tr,
                      amount:
                          '${commission.toStringAsFixed(2)} $currency',
                    ),
                    SizedBox(height: 6.h),
                    Divider(
                      color: _roleColor.withValues(alpha: 0.2),
                      height: 1,
                    ),
                    SizedBox(height: 8.h),
                    _buildBreakdownRow(
                      context,
                      icon: Icons.payments_rounded,
                      iconColor: _roleColor,
                      label: 'send_request_you_pay'.tr,
                      amount:
                          '${ownerTotal.toStringAsFixed(2)} $currency',
                      boldAmount: true,
                      emphasisColor: _roleColor,
                    ),
                  ],
                ),
              ),
              if (breakdown != null) ...[
                SizedBox(height: 8.h),
                InterText(
                  text: breakdown,
                  fontSize: 10.sp,
                  color: AppColors.textSecondary(context),
                  maxLines: 3,
                  overflow: TextOverflow.visible,
                ),
              ],
            ] else ...[
              InterText(
                text: breakdown ??
                    'send_request_select_to_see_total'.tr,
                fontSize: 11.sp,
                color: AppColors.textSecondary(context),
                maxLines: 3,
                overflow: TextOverflow.visible,
              ),
            ],
          ],
        ),
      );
    });
  }

  // v20.0.12 — Row helper for the modernized breakdown section.
  Widget _buildBreakdownRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String amount,
    bool boldAmount = false,
    Color? emphasisColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16.sp, color: iconColor),
        SizedBox(width: 8.w),
        Expanded(
          child: InterText(
            text: label,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary(context),
          ),
        ),
        PoppinsText(
          text: amount,
          fontSize: boldAmount ? 14.sp : 13.sp,
          fontWeight: boldAmount ? FontWeight.w800 : FontWeight.w600,
          color: emphasisColor ?? AppColors.textPrimary(context),
        ),
      ],
    );
  }
}
