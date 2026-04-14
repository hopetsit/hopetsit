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
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: AppColors.lightGrey,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        title: PoppinsText(
          text: 'publish_request_title'.tr,
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
                _buildPetsSection(),
                SizedBox(height: 20.h),
                _buildDatesSection(),
                SizedBox(height: 20.h),
                _buildServiceTypeSection(),
                Obx(
                  () => controller.shouldShowHouseSittingVenue
                      ? Column(
                          children: [
                            SizedBox(height: 20.h),
                            _buildHouseSittingVenueSection(),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
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
                SizedBox(height: 20.h),
                _buildLocationSection(),
                SizedBox(height: 20.h),
                CustomTextField(
                  labelText: 'publish_request_notes_label'.tr,
                  hintText: 'publish_request_notes_hint'.tr,
                  controller: controller.notesController,
                  maxLines: 4,
                  radius: 21,
                ),
                SizedBox(height: 20.h),
                _buildImagesSection(),
                SizedBox(height: 28.h),
                Obx(
                  () => CustomButton(
                    title: controller.isSubmitting.value
                        ? null
                        : 'publish_request_publish_button'.tr,
                    onTap: controller.isSubmitting.value
                        ? null
                        : () => controller.submit(),
                    bgColor: AppColors.primaryColor,
                    textColor: AppColors.whiteColor,
                    height: 48.h,
                    radius: 48.r,
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
                                fontWeight: FontWeight.w500,
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

  Widget _buildPetsSection() {
    return Obx(() {
      if (controller.isPetsLoading.value) {
        return _labeled(
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

      // If owner has no pets, behave like Send Request: show link to MyPetsScreen
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
              color: AppColors.whiteColor,
              borderRadius: BorderRadius.circular(30.r),
              border: Border.all(color: AppColors.grey300Color, width: 1),
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

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InterText(
            text: 'send_request_dates_label'.tr,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.grey700Color,
          ),
          SizedBox(height: 8.h),
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
                InterText(
                  text: 'send_request_start_label'.tr,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
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
                SizedBox(height: 16.h),
                InterText(
                  text: 'send_request_end_label'.tr,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.grey700Color,
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
            ),
          ),
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
  }

  Widget _buildServiceTypeSection() {
    return Column(
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
            children: controller.serviceTypes.map((serviceType) {
              final value = serviceType['value']!;
              final label = serviceType['label']!;
              final selected = controller.selectedServiceType.value == value;
              return GestureDetector(
                onTap: () => controller.selectServiceType(value),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryColor
                        : AppColors.whiteColor,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: selected
                          ? AppColors.primaryColor
                          : AppColors.greyColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: InterText(
                    text: label,
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
      ],
    );
  }

  Widget _buildDurationSection() {
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
            children: const ['30', '60'].map((m) {
              final selected = controller.selectedDuration.value == m;
              return GestureDetector(
                onTap: () => controller.selectDuration(m),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 25.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryColor
                        : AppColors.whiteColor,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: selected
                          ? AppColors.primaryColor
                          : AppColors.greyColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: InterText(
                    text: 'send_request_duration_minutes_label'.trParams({
                      'minutes': m,
                    }),
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
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryColor
                        : AppColors.whiteColor,
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
        Obx(() => Column(
              children: [
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: Text('service_location_at_owner'.tr),
                  value: 'at_owner',
                  groupValue: controller.serviceLocation.value,
                  onChanged: (v) => controller.serviceLocation.value = v,
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: Text('service_location_at_sitter'.tr),
                  value: 'at_sitter',
                  groupValue: controller.serviceLocation.value,
                  onChanged: (v) => controller.serviceLocation.value = v,
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: Text('service_location_both'.tr),
                  value: 'both',
                  groupValue: controller.serviceLocation.value,
                  onChanged: (v) => controller.serviceLocation.value = v,
                ),
              ],
            )),
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
          color: AppColors.grey700Color,
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
                    color: AppColors.whiteColor,
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: AppColors.grey300Color, width: 1),
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
          color: AppColors.grey700Color,
        ),
        SizedBox(height: 8.h),
        child,
      ],
    );
  }
}
