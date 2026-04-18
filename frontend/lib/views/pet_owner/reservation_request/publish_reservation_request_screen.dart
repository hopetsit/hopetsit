import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/publish_reservation_request_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/city_location_picker.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/custom_text_field.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/views/profile/my_pets_screen.dart';

class PublishReservationRequestScreen extends StatefulWidget {
  const PublishReservationRequestScreen({super.key});

  @override
  State<PublishReservationRequestScreen> createState() =>
      _PublishReservationRequestScreenState();
}

class _PublishReservationRequestScreenState
    extends State<PublishReservationRequestScreen> {
  late final PublishReservationRequestController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(PublishReservationRequestController());
  }

  @override
  void dispose() {
    if (Get.isRegistered<PublishReservationRequestController>()) {
      Get.delete<PublishReservationRequestController>();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        centerTitle: true,
        title: PoppinsText(
          text: 'publish_request_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionCard(
                  icon: Icons.pets,
                  title: 'label_pets'.tr,
                  child: _buildPetsSection(),
                ),
                SizedBox(height: 16.h),
                _buildSectionCard(
                  icon: Icons.calendar_today_rounded,
                  title: 'send_request_dates_label'.tr,
                  child: _buildDatesSection(),
                ),
                SizedBox(height: 16.h),
                _buildServiceTypeSection(),
                Obx(
                  () => controller.shouldShowDuration
                      ? Column(
                          children: [
                            SizedBox(height: 20.h),
                            _buildDurationSection(),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                Obx(
                  () => controller.shouldShowServiceLocation
                      ? Column(
                          children: [
                            SizedBox(height: 20.h),
                            _buildServiceLocationSection(),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                SizedBox(height: 16.h),
                _buildSectionCard(
                  icon: Icons.location_on_rounded,
                  title: 'publish_request_city_label'.tr,
                  child: _buildLocationSection(),
                ),
                SizedBox(height: 16.h),
                _buildSectionCard(
                  icon: Icons.edit_note_rounded,
                  title: 'publish_request_notes_label'.tr,
                  child: CustomTextField(
                    labelText: '',
                    hintText: 'publish_request_notes_hint'.tr,
                    controller: controller.notesController,
                    maxLines: 4,
                    radius: 16,
                  ),
                ),
                SizedBox(height: 16.h),
                _buildSectionCard(
                  icon: Icons.photo_library_rounded,
                  title: 'publish_request_images_label'.tr,
                  child: _buildImagesSection(),
                ),
                SizedBox(height: 24.h),
                Obx(
                  () => CustomButton(
                    title: controller.isSubmitting.value
                        ? null
                        : 'publish_request_publish_button'.tr,
                    onTap: controller.isSubmitting.value
                        ? null
                        : () => controller.submit(),
                    isGradient: true,
                    textColor: AppColors.whiteColor,
                    height: 52.h,
                    radius: 16.r,
                    child: controller.isSubmitting.value
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
                                text: 'post_button_posting'.tr,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.whiteColor,
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
                SizedBox(height: 12.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Modern card wrapper for each form section.
  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(icon, size: 18.sp, color: AppColors.primaryColor),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: PoppinsText(
                  text: title,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          child,
        ],
      ),
    );
  }

  Widget _buildPetsSection() {
    return Obx(() {
      if (controller.isPetsLoading.value) {
        return _labeled(
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

      // If owner has no pets, behave like Send Request: show link to MyPetsScreen
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

      // Build dropdown items from pets
      final items = controller.myPets
          .map(
            (p) => DropdownMenuItem<String>(
              value: p.id,
              child: Text('${p.petName} • ${p.breed}'),
            ),
          )
          .toList();

      final displayText =
          controller.selectedPetId.value == null ||
              controller.selectedPetId.value!.isEmpty
          ? 'common_select'.tr
          : '';

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
              color: AppColors.inputFill(context),
              borderRadius: BorderRadius.circular(30.r),
              border: Border.all(color: AppColors.divider(context), width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: controller.selectedPetId.value,
                      items: items,
                      onChanged: (v) {
                        if (v != null) controller.selectPet(v);
                      },
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

  Widget _buildDatesSection() {
    return Obx(() {
      controller.startDate.value;
      controller.endDate.value;
      controller.startTime.value;
      controller.endTime.value;
      controller.selectedServiceType.value;
      controller.selectedDuration.value;

      // Session v3.3 — service-aware date/time layout:
      //   * dog_walking  → only "Début" (date + time). End is computed from
      //                    the selected duration chip below.
      //   * day_care     → date + start time + end time on the same day (no
      //                    second date — implicit).
      //   * pet_sitting  → full start (date+time) + full end (date+time).
      //   * null         → same as pet_sitting (all fields visible).
      final svc = controller.selectedServiceType.value;
      final isWalking = svc == 'dog_walking';
      final isDayCare = svc == 'day_care';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Start
          InterText(
            text: isWalking
                ? 'Date et heure de la promenade'
                : 'send_request_start_label'.tr,
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.grey700Color,
          ),
          SizedBox(height: 8.h),
          _dateTimeRow(
            dateText: controller.formattedStartDate.isEmpty
                ? 'send_request_select_date'.tr
                : controller.formattedStartDate,
            timeText: controller.formattedStartTime.isEmpty
                ? 'send_request_select_time'.tr
                : controller.formattedStartTime,
            onDateTap: () => _pickDate(isStart: true),
            onTimeTap: () => _pickTime(isStart: true),
            isDatePlaceholder: controller.formattedStartDate.isEmpty,
            isTimePlaceholder: controller.formattedStartTime.isEmpty,
          ),

          // dog_walking → helper text instead of the redundant end fields.
          if (isWalking) ...[
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: AppColors.greenColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: AppColors.greenColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16.sp, color: AppColors.greenColor),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: InterText(
                      text: controller.selectedDuration.value == null
                          ? 'L\'heure de fin sera calculée depuis la durée que tu choisis plus bas.'
                          : 'Fin automatique : ${controller.formattedEndTime.isEmpty ? "…" : controller.formattedEndTime} (durée ${controller.selectedDuration.value} min)',
                      fontSize: 12.sp,
                      color: AppColors.greenColor,
                    ),
                  ),
                ],
              ),
            ),
          ]
          // day_care → single-day event; show only end time (end date
          // implicit = same day as start).
          else if (isDayCare) ...[
            SizedBox(height: 14.h),
            Center(
              child: Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_downward_rounded,
                    size: 16.sp, color: AppColors.primaryColor),
              ),
            ),
            SizedBox(height: 14.h),
            InterText(
              text: 'Heure de fin (même jour)',
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(context),
            ),
            SizedBox(height: 8.h),
            GestureDetector(
              onTap: () => _pickTime(isStart: false),
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 48.h,
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                decoration: BoxDecoration(
                  color: AppColors.inputFill(context),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: controller.formattedEndTime.isEmpty
                        ? AppColors.divider(context)
                        : AppColors.primaryColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 16.sp,
                      color: controller.formattedEndTime.isEmpty
                          ? AppColors.greyColor
                          : AppColors.primaryColor,
                    ),
                    SizedBox(width: 8.w),
                    InterText(
                      text: controller.formattedEndTime.isEmpty
                          ? 'send_request_select_time'.tr
                          : controller.formattedEndTime,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: controller.formattedEndTime.isEmpty
                          ? AppColors.greyColor
                          : AppColors.blackColor,
                    ),
                  ],
                ),
              ),
            ),
          ]
          // pet_sitting / unknown → classic start + end pair.
          else ...[
            SizedBox(height: 14.h),
            Center(
              child: Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_downward_rounded,
                    size: 16.sp, color: AppColors.primaryColor),
              ),
            ),
            SizedBox(height: 14.h),
            InterText(
              text: 'send_request_end_label'.tr,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(context),
            ),
            SizedBox(height: 8.h),
            _dateTimeRow(
              dateText: controller.formattedEndDate.isEmpty
                  ? 'send_request_select_date'.tr
                  : controller.formattedEndDate,
              timeText: controller.formattedEndTime.isEmpty
                  ? 'send_request_select_time'.tr
                  : controller.formattedEndTime,
              onDateTap: () => _pickDate(isStart: false),
              onTimeTap: () => _pickTime(isStart: false),
              isDatePlaceholder: controller.formattedEndDate.isEmpty,
              isTimePlaceholder: controller.formattedEndTime.isEmpty,
            ),
          ],
        ],
      );
    });
  }

  Widget _dateTimeRow({
    required String dateText,
    required String timeText,
    required VoidCallback onDateTap,
    required VoidCallback onTimeTap,
    required bool isDatePlaceholder,
    required bool isTimePlaceholder,
  }) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onDateTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 48.h,
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              decoration: BoxDecoration(
                color: AppColors.inputFill(context),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: isDatePlaceholder ? AppColors.divider(context) : AppColors.primaryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 16.sp,
                    color: isDatePlaceholder ? AppColors.greyColor : AppColors.primaryColor),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: InterText(
                      text: dateText,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: isDatePlaceholder ? AppColors.greyColor : AppColors.blackColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: GestureDetector(
            onTap: onTimeTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 48.h,
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F8),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: isTimePlaceholder ? AppColors.grey300Color : AppColors.primaryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 16.sp,
                    color: isTimePlaceholder ? AppColors.greyColor : AppColors.primaryColor),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: InterText(
                      text: timeText,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: isTimePlaceholder ? AppColors.greyColor : AppColors.blackColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial =
        (isStart ? controller.startDate.value : controller.endDate.value) ??
        now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: DateTime(now.year + 1, now.month, now.day),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryColor,
              onPrimary: AppColors.whiteColor,
              surface: AppColors.whiteColor,
              onSurface: AppColors.blackColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    if (isStart) {
      controller.startDate.value = picked;
      if (controller.endDate.value != null &&
          controller.endDate.value!.isBefore(picked)) {
        controller.endDate.value = picked;
      }
    } else {
      controller.endDate.value = picked;
      if (controller.startDate.value != null &&
          picked.isBefore(controller.startDate.value!)) {
        controller.endDate.value = controller.startDate.value;
      }
    }
    // Session v3.3 — recompute end for dog_walking (based on duration) and
    // force same-day for day_care whenever the start date changes.
    controller.onDatesChanged();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final now = TimeOfDay.now();
    TimeOfDay initial =
        (isStart ? controller.startTime.value : controller.endTime.value) ??
        now;
    final minEnd = controller.minEndTime;
    if (!isStart && minEnd != null) {
      final initialMinutes = initial.hour * 60 + initial.minute;
      final minMinutes = minEnd.hour * 60 + minEnd.minute;
      if (initialMinutes < minMinutes) initial = minEnd;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
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
                        ? AppColors.primaryColor
                        : AppColors.lightGrey),
                hourMinuteTextColor: WidgetStateColor.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? AppColors.whiteColor
                        : AppColors.blackColor),
                dialHandColor: AppColors.primaryColor,
                dialBackgroundColor: AppColors.lightGrey,
                entryModeIconColor: AppColors.primaryColor,
                helpTextStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.grey700Color,
                ),
              ),
              colorScheme: ColorScheme.light(
                primary: AppColors.primaryColor,
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
    if (picked == null) return;
    if (isStart) {
      controller.startTime.value = picked;
      // if end time exists and same-day is now invalid, clear end time
      if (controller.endTime.value != null && controller.minEndTime != null) {
        final min = controller.minEndTime!;
        final end = controller.endTime.value!;
        final endMinutes = end.hour * 60 + end.minute;
        final minMinutes = min.hour * 60 + min.minute;
        if (endMinutes < minMinutes) {
          controller.endTime.value = null;
        }
      }
    } else {
      // Validate end time not before min if same day
      if (minEnd != null) {
        final pickedMinutes = picked.hour * 60 + picked.minute;
        final minMinutes = minEnd.hour * 60 + minEnd.minute;
        if (pickedMinutes < minMinutes) {
          CustomSnackbar.showError(
            title: 'send_request_invalid_time_title'.tr,
            message: 'send_request_invalid_time_message'.tr,
          );
          return;
        }
      }
      controller.endTime.value = picked;
    }
    // Session v3.3 — service-aware auto-tuning of the end fields.
    controller.onDatesChanged();
  }

  // Session avril 2026 — service-type palette. Promenade is walker-exclusive
  // and gets the walker green accent; the two sitter services share the
  // blue accent so owners visually group them as "sitter services".
  static const Color _walkerAccent = AppColors.greenColor;
  static const Color _sitterAccent = Color(0xFF1A73E8);

  Color _accentForService(String value) {
    return value == 'dog_walking' ? _walkerAccent : _sitterAccent;
  }

  Widget _buildServiceTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InterText(
          text: 'send_request_service_type_label'.tr,
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary(context),
        ),
        SizedBox(height: 12.h),
        Obx(() {
          final types = controller.serviceTypes;
          return Column(
            children: List.generate(types.length, (i) {
              final t = types[i];
              final value = t['value']!;
              final label = t['label']!;
              final description = t['description'] ?? '';
              final icon = t['icon'] ?? '🐾';
              final selected =
                  controller.selectedServiceType.value == value;
              final accent = _accentForService(value);

              return Padding(
                padding: EdgeInsets.only(bottom: i == types.length - 1 ? 0 : 10.h),
                child: GestureDetector(
                  onTap: () => controller.selectServiceType(value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 14.h,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? accent.withOpacity(0.08)
                          : AppColors.inputFill(context),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: selected
                            ? accent
                            : AppColors.greyColor.withValues(alpha: 0.25),
                        width: selected ? 1.8 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42.w,
                          height: 42.w,
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          alignment: Alignment.center,
                          child: Text(icon, style: TextStyle(fontSize: 22.sp)),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InterText(
                                text: label,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? accent
                                    : AppColors.textPrimary(context),
                              ),
                              if (description.isNotEmpty) ...[
                                SizedBox(height: 2.h),
                                InterText(
                                  text: description,
                                  fontSize: 11.sp,
                                  color: AppColors.textSecondary(context),
                                  maxLines: 2,
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Selected indicator — checkmark in a tinted circle.
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: selected ? 1 : 0,
                          child: Container(
                            width: 22.w,
                            height: 22.w,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.check_rounded,
                              size: 14.sp,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ],
    );
  }

  /// Duration section for Promenade — split in two groups so owners visually
  /// understand that a 30-min walk and a 5-hour outing are different products.
  /// Group 1 = short walks (30/60/90/120 min). Group 2 = long outings (3/4/5 h).
  Widget _buildDurationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _durationGroup(
          sectionLabel: 'publish_request_duration_walk_label'.tr,
          minutesList: PublishReservationRequestController.promenadeMinutes,
        ),
        SizedBox(height: 16.h),
        _durationGroup(
          sectionLabel: 'publish_request_duration_long_label'.tr,
          minutesList: PublishReservationRequestController.longOutingMinutes,
        ),
      ],
    );
  }

  Widget _durationGroup({
    required String sectionLabel,
    required List<String> minutesList,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InterText(
          text: sectionLabel,
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.greyText,
        ),
        SizedBox(height: 8.h),
        Obx(
          () => Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            children: minutesList.map((m) {
              final selected = controller.selectedDuration.value == m;
              return GestureDetector(
                onTap: () => controller.selectDuration(m),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 18.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? _walkerAccent
                        : AppColors.inputFill(context),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: selected
                          ? _walkerAccent
                          : AppColors.greyColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: InterText(
                    text: _formatMinutes(m),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.whiteColor
                        : AppColors.greyColor,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// "30" → "30 min", "90" → "1 h 30", "180" → "3 h".
  String _formatMinutes(String m) {
    final n = int.tryParse(m) ?? 0;
    if (n < 60) return '$n min';
    final hours = n ~/ 60;
    final rem = n % 60;
    if (rem == 0) return '$hours h';
    return '$hours h $rem';
  }

  /// Service location radio — replaces the old "Lieu du house sitting" +
  /// "Où doit se dérouler le service ?" duplicate, now a single clear
  /// question surfaced for daycare + pet_sitting only.
  Widget _buildServiceLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InterText(
          text: 'service_location_label'.tr,
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary(context),
        ),
        SizedBox(height: 8.h),
        Obx(() {
          final current = controller.serviceLocation.value;
          Widget buildOption(String value, String labelKey) {
            final selected = current == value;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => controller.serviceLocation.value = value,
              child: Container(
                margin: EdgeInsets.only(bottom: 10.h),
                padding: EdgeInsets.symmetric(
                  horizontal: 14.w,
                  vertical: 12.h,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? _sitterAccent.withOpacity(0.08)
                      : AppColors.inputFill(context),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color:
                        selected ? _sitterAccent : AppColors.divider(context),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20.w,
                      height: 20.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? _sitterAccent
                              : AppColors.textSecondary(context),
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? Center(
                              child: Container(
                                width: 10.w,
                                height: 10.w,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _sitterAccent,
                                ),
                              ),
                            )
                          : null,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: InterText(
                        text: labelKey.tr,
                        fontSize: 14.sp,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              buildOption('at_owner', 'service_location_at_owner'),
              buildOption('at_sitter', 'service_location_at_sitter'),
              buildOption('both', 'service_location_both'),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildHouseSittingVenueSection() {
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
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryColor
                        : AppColors.inputFill(context),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: selected
                          ? AppColors.primaryColor
                          : AppColors.greyColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: InterText(
                    text: opt['label']!.tr,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: selected
                        ? AppColors.whiteColor
                        : AppColors.greyColor,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(height: 16.h),
        // Sprint 5 UI step 1 — service location radio.
        InterText(
          text: 'service_location_label'.tr,
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: AppColors.grey700Color,
        ),
        SizedBox(height: 8.h),
        Obx(() {
          final current = controller.serviceLocation.value;
          Widget buildOption(String value, String labelKey) {
            final selected = current == value;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => controller.serviceLocation.value = value,
              child: Container(
                margin: EdgeInsets.only(bottom: 10.h),
                padding: EdgeInsets.symmetric(
                  horizontal: 14.w,
                  vertical: 12.h,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryColor.withValues(alpha: 0.08)
                      : AppColors.inputFill(context),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: selected
                        ? AppColors.primaryColor
                        : AppColors.divider(context),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20.w,
                      height: 20.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? AppColors.primaryColor
                              : AppColors.textSecondary(context),
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? Center(
                              child: Container(
                                width: 10.w,
                                height: 10.w,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primaryColor,
                                ),
                              ),
                            )
                          : null,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: InterText(
                        text: labelKey.tr,
                        fontSize: 14.sp,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              buildOption('at_owner', 'service_location_at_owner'),
              buildOption('at_sitter', 'service_location_at_sitter'),
              buildOption('both', 'service_location_both'),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CityLocationPicker(
            cityController: controller.cityController,
            onGetLocation: controller.detectLocation,
            isGettingLocation: controller.isGettingLocation.value,
            detectedCity: controller.detectedCity.value,
          ),
          SizedBox(height: 14.h),
          CustomTextField(
            labelText: 'publish_request_address_label'.tr,
            hintText: 'publish_request_address_hint'.tr,
            controller: controller.addressController,
            radius: 21,
          ),
        ],
      ),
    );
  }

  Widget _buildImagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InterText(
          text: 'publish_request_images_label'.tr,
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary(context),
        ),
        SizedBox(height: 8.h),
        Obx(() {
          final images = controller.imageFiles.toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (images.isNotEmpty)
                SizedBox(
                  height: 84.h,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    separatorBuilder: (_, __) => SizedBox(width: 10.w),
                    itemBuilder: (_, idx) {
                      final File f = images[idx];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12.r),
                            child: Image.file(
                              f,
                              width: 84.h,
                              height: 84.h,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 84.h,
                                height: 84.h,
                                color: AppColors.grey300Color,
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: AppColors.greyText,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: () => controller.removeImageAt(idx),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              SizedBox(height: 12.h),
              GestureDetector(
                onTap: controller.pickImages,
                child: Container(
                  height: 46.h,
                  decoration: BoxDecoration(
                    color: AppColors.inputFill(context),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: AppColors.divider(context), width: 1),
                  ),
                  child: Center(
                    child: InterText(
                      text: images.isEmpty
                          ? 'publish_request_add_images'.tr
                          : 'publish_request_add_more_images'.tr,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _labeled({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InterText(
          text: label,
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary(context),
        ),
        SizedBox(height: 8.h),
        child,
      ],
    );
  }
}
