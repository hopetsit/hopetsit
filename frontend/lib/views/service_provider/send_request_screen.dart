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

  const SendRequestScreen({
    super.key,
    required this.serviceProviderName,
    required this.serviceProviderId,
  });

  @override
  State<SendRequestScreen> createState() => _SendRequestScreenState();
}

class _SendRequestScreenState extends State<SendRequestScreen> {
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
      ),
      tag: tag,
    );

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: AppColors.lightGrey,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        leading: BackButton(),
        title: PoppinsText(
          text: 'send_request_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.blackColor,
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
                    bgColor: AppColors.primaryColor,
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
              color: AppColors.whiteColor,
              borderRadius: BorderRadius.circular(30.r),
              border: Border.all(color: AppColors.grey300Color, width: 1),
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
              color: AppColors.grey700Color,
            ),
            SizedBox(height: 8.h),
            GestureDetector(
              onTap: () => Get.to(() => const MyPetsScreen()),
              child: Container(
                height: 50.h,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                decoration: BoxDecoration(
                  color: AppColors.whiteColor,
                  borderRadius: BorderRadius.circular(30.r),
                  border: Border.all(color: AppColors.grey300Color, width: 1),
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
            color: AppColors.grey700Color,
          ),
          SizedBox(height: 8.h),
          // Single container with border and decoration containing Start + End
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.whiteColor,
              borderRadius: BorderRadius.circular(21.r),
              border: Border.all(color: AppColors.grey300Color, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Start: label inside container + date|time row
                InterText(
                  text: 'send_request_start_label'.tr,
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
                SizedBox(height: 16.h),
                // End: label inside container + date|time row
                InterText(
                  text: 'send_request_end_label'.tr,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.grey700Color,
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
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.grey300Color, width: 1),
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
                      ? AppColors.greyColor
                      : AppColors.blackColor,
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 24.h,
            margin: EdgeInsets.symmetric(horizontal: 12.w),
            color: AppColors.grey300Color,
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
                      ? AppColors.greyColor
                      : AppColors.blackColor,
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
                              ? AppColors.primaryColor
                              : AppColors.whiteColor,
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primaryColor
                                : AppColors.greyColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: InterText(
                          text: serviceType['label']!,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? AppColors.whiteColor
                              : AppColors.greyColor,
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
          color: AppColors.grey700Color,
        ),
        SizedBox(height: 12.h),
        Obx(
          () => Wrap(
            spacing: 12.w,
            runSpacing: 12.h,
            direction: Axis.horizontal,
            alignment: WrapAlignment.spaceEvenly,
            children: ['30', '60'].map((duration) {
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
                        ? AppColors.primaryColor
                        : AppColors.whiteColor,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryColor
                          : AppColors.greyColor.withOpacity(0.3),
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
          color: AppColors.grey700Color,
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
                    color: selected ? AppColors.primaryColor : AppColors.whiteColor,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: selected
                          ? AppColors.primaryColor
                          : AppColors.greyColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: InterText(
                    text: opt['label']!.tr,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: selected ? AppColors.whiteColor : AppColors.greyColor,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
