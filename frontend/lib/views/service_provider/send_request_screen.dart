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
          padding: EdgeInsets.all(20.w),
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pets section (image: label "Pets", count + dropdown + arrow)
                _buildPetsSection(context, controller),
                SizedBox(height: 24.h),

                // Description
                CustomTextField(
                  labelText: 'send_request_description_label'.tr,
                  controller: controller.descriptionController,
                  hintText: 'send_request_description_hint'.tr,
                  maxLines: 4,
                  radius: 21,
                ),
                SizedBox(height: 24.h),

                // Dates section: Start (date + time), End (date + time)
                _buildDatesSection(context, controller),
                SizedBox(height: 24.h),

                // Service Type chips
                _buildServiceTypeSection(controller),
                SizedBox(height: 24.h),

                Obx(
                  () => controller.shouldShowHouseSittingVenue
                      ? Column(
                          children: [
                            _buildHouseSittingVenueSection(controller),
                            SizedBox(height: 24.h),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),

                // Duration (only for dog_walking)
                Obx(
                  () => controller.shouldShowDuration
                      ? Column(
                          children: [
                            _buildDurationSection(controller),
                            SizedBox(height: 24.h),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),

                // Session v15 — Total estimé (live). Se met à jour dès que
                // l'user change dates / service / durée.
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
                        : controller.dateTimeValidationError.value == null
                        ? () => controller.sendRequest(
                            isAllDay: controller.isAllDay.value,
                            fallbackDate: controller.focusedDate.value,
                          )
                        : () {
                            CustomSnackbar.showError(
                              title: 'send_request_validation_error_title'.tr,
                              message:
                                  controller.dateTimeValidationError.value!,
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

  Widget _buildPetsSection(
    BuildContext context,
    SendRequestController controller,
  ) {
    return Obx(() {
      if (controller.isPetsLoading.value) {
        return _labeledField(
          label: 'label_pets'.tr,
          child: Container(
            height: 50.h,
            decoration: BoxDecoration(
              color: AppColors.inputFill(context),
              borderRadius: BorderRadius.circular(30.r),
              border: Border.all(color: AppColors.divider(context), width: 1),
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
        );
      }
      if (controller.myPets.isEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InterText(
              text: 'label_pets'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary(context),
            ),
            SizedBox(height: 8.h),
            GestureDetector(
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
                      Icons.keyboard_arrow_down,
                      size: 20.sp,
                      color: AppColors.greyColor,
                    ),
                    SizedBox(width: 8.w),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14.sp,
                      color: AppColors.greyColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InterText(
            text: 'label_pets'.tr,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.grey700Color,
          ),
          SizedBox(height: 8.h),
          Container(
            height: 50.h,
            decoration: BoxDecoration(
              color: AppColors.whiteColor,
              borderRadius: BorderRadius.circular(30.r),
              border: Border.all(color: AppColors.grey300Color, width: 1),
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
                // Icon(
                //   Icons.keyboard_arrow_down,
                //   size: 20.sp,
                //   color: AppColors.greyColor,
                // ),
                //SizedBox(width: 8.w),
                GestureDetector(
                  onTap: () => Get.to(() => const MyPetsScreen()),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      size: 14.sp,
                      color: AppColors.blackColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _labeledField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InterText(
          text: label,
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: AppColors.grey700Color,
        ),
        SizedBox(height: 8.h),
        child,
      ],
    );
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title outside the container (same style as other section labels)
          InterText(
            text: 'send_request_dates_label'.tr,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary(context),
          ),
          SizedBox(height: 8.h),
          // Single container with border and decoration.
          //   • Sitter → Début + Fin (multi-day stays need both ends)
          //   • Walker → single Date + Heure row (endDate/endTime are
          //     derived from Start + selected duration by the controller)
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.inputFill(context),
              borderRadius: BorderRadius.circular(21.r),
              border: Border.all(color: AppColors.divider(context), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Start (walker label = "Date & heure", sitter label = "Début")
                InterText(
                  text: isWalker
                      ? 'send_request_start_label'.tr
                      : 'send_request_start_label'.tr,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.grey700Color,
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
                if (!isWalker) ...[
                  SizedBox(height: 16.h),
                  // End: label inside container + date|time row (sitter only)
                  InterText(
                    text: 'send_request_end_label'.tr,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary(context),
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
                    child: InterText(
                      text: error,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.errorColor,
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      );
    });
  }

  /// One row inside the dates container: date (left) | vertical line | time (right) | arrow.
  Widget _buildDateTimeRow({
    required String dateText,
    required String timeText,
    required bool isDatePlaceholder,
    required bool isTimePlaceholder,
    required VoidCallback onDateTap,
    required VoidCallback onTimeTap,
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

  Widget _buildServiceTypeSection(SendRequestController controller) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InterText(
                text: 'send_request_service_type_label'.tr,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.grey700Color,
              ),
              SizedBox(height: 12.h),
              Obx(
                () => Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  direction: Axis.horizontal,
                  alignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: controller.serviceTypes.map((serviceType) {
                    final isSelected =
                        controller.selectedServiceType.value ==
                        serviceType['value'];

                    return GestureDetector(
                      onTap: () =>
                          controller.selectServiceType(serviceType['value']!),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 10.h,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _roleColor
                              : AppColors.inputFill(context),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(
                            color: isSelected
                                ? _roleColor
                                : AppColors.divider(context),
                            width: 1,
                          ),
                        ),
                        child: InterText(
                          text: serviceType['label']!,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? AppColors.whiteColor
                              : AppColors.textSecondary(context),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDurationSection(SendRequestController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InterText(
          text: 'send_request_duration_label'.tr,
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary(context),
        ),
        SizedBox(height: 12.h),
        Obx(
          () => Wrap(
            spacing: 12.w,
            runSpacing: 12.h,
            direction: Axis.horizontal,
            alignment: WrapAlignment.spaceEvenly,
            // Session v15-3 — align walk duration presets with the Publish flow
            // (publish_reservation_request_controller.promenadeMinutes).
            children: const ['30', '60', '90', '120'].map((duration) {
              final isSelected = controller.selectedDuration.value == duration;

              return GestureDetector(
                onTap: () => controller.selectDuration(duration),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 25.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _roleColor
                        : AppColors.inputFill(context),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: isSelected
                          ? _roleColor
                          : AppColors.divider(context),
                      width: 1,
                    ),
                  ),
                  child: InterText(
                    text: 'send_request_duration_minutes_label'.trParams({
                      'minutes': duration,
                    }),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? AppColors.whiteColor
                        : AppColors.textSecondary(context),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildHouseSittingVenueSection(SendRequestController controller) {
    const options = <Map<String, String>>[
      {'value': 'owners_home', 'label': 'house_sitting_venue_owners_home'},
      {'value': 'sitters_home', 'label': 'house_sitting_venue_sitters_home'},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InterText(
          text: 'house_sitting_venue_label'.tr,
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary(context),
        ),
        SizedBox(height: 12.h),
        Obx(
          () => Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: options.map((opt) {
              final value = opt['value']!;
              final selected = controller.houseSittingVenue.value == value;
              return GestureDetector(
                onTap: () => controller.selectHouseSittingVenue(value),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: selected ? _roleColor : AppColors.inputFill(context),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: selected
                          ? _roleColor
                          : AppColors.divider(context),
                      width: 1,
                    ),
                  ),
                  child: InterText(
                    text: opt['label']!.tr,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: selected ? AppColors.whiteColor : AppColors.textSecondary(context),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
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

      String? totalText;
      String? breakdown;

      if (service == 'dog_walking') {
        // v18.8 — estimateur strict : on ne montre un total que si la
        // durée sélectionnée a un tarif EXPLICITE côté walker (walkRate
        // enabled). Sinon on affiche "À confirmer avec le prestataire".
        // Avant, on devinait via hourlyRate/2 ce qui donnait des
        // estimations fausses quand le walker n'avait pas défini sa
        // grille 30min (le cas de la plupart des walkers).
        final minutes = int.tryParse(duration ?? '') ?? 0;
        final halfHour = widget.walkerHalfHourRate;
        final hour = widget.walkerHourlyRate;
        double? total;
        String? notSetNotice;
        if (minutes > 0) {
          if (minutes == 30) {
            if (halfHour != null && halfHour > 0) {
              total = halfHour;
            } else {
              notSetNotice =
                  'send_request_duration_rate_missing'.tr;
            }
          } else if (minutes == 60) {
            if (hour != null && hour > 0) {
              total = hour;
            } else {
              notSetNotice =
                  'send_request_duration_rate_missing'.tr;
            }
          } else if (minutes == 90) {
            if (hour != null && hour > 0 &&
                halfHour != null && halfHour > 0) {
              total = hour + halfHour;
            } else {
              notSetNotice =
                  'send_request_duration_rate_missing'.tr;
            }
          } else if (minutes == 120) {
            if (hour != null && hour > 0) {
              total = hour * 2;
            } else {
              notSetNotice =
                  'send_request_duration_rate_missing'.tr;
            }
          }
        }
        if (total != null && total > 0) {
          totalText =
              '${total.toStringAsFixed(2)} ${widget.currencyCode ?? 'EUR'}';
          breakdown = '1 balade $minutes min';
        } else if (notSetNotice != null) {
          breakdown = notSetNotice;
        }
      } else if (service != null && service.isNotEmpty) {
        if (sDate != null && eDate != null) {
          final raw = eDate.difference(sDate).inDays;
          final days = raw > 0 ? raw : 1;
          // Session v15-3 — derive a daily rate when the sitter only has
          // weekly/monthly saved, otherwise the Total sits at "À confirmer"
          // even though we have enough info to estimate.
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
            final total = dailyRate * days;
            totalText =
                '${total.toStringAsFixed(0)} ${widget.currencyCode ?? 'EUR'}';
            breakdown =
                '$days jour${days > 1 ? 's' : ''} × ~${dailyRate.toStringAsFixed(0)} €/j';
          }
        }
      }

      return Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _roleColor.withValues(alpha: 0.08),
              _roleColor.withValues(alpha: 0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
              color: _roleColor.withValues(alpha: 0.2), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.attach_money_rounded,
                size: 28.sp, color: _roleColor),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InterText(
                    text: 'Total estimé',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary(context),
                  ),
                  SizedBox(height: 2.h),
                  PoppinsText(
                    text: totalText ?? 'À confirmer',
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                    color: _roleColor,
                  ),
                  if (breakdown != null) ...[
                    SizedBox(height: 2.h),
                    InterText(
                      text: breakdown,
                      fontSize: 11.sp,
                      color: AppColors.textSecondary(context),
                    ),
                  ] else ...[
                    SizedBox(height: 2.h),
                    InterText(
                      text: 'Sélectionnez service + dates pour voir le total',
                      fontSize: 11.sp,
                      color: AppColors.textSecondary(context),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
