import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Filter state for reservation requests (location, dates, service type, distance).
class ReservationRequestFilterState {
  const ReservationRequestFilterState({
    this.city,
    this.dateRange,
    this.serviceType,
    this.maxDistanceKm,
  });

  final String? city;
  final DateTimeRange? dateRange;
  final String? serviceType;
  final double? maxDistanceKm;

  bool get hasActiveFilters =>
      (city != null && city!.trim().isNotEmpty) ||
      dateRange != null ||
      (serviceType != null && serviceType!.isNotEmpty) ||
      (maxDistanceKm != null && maxDistanceKm! > 0);

  ReservationRequestFilterState copyWith({
    String? city,
    DateTimeRange? dateRange,
    String? serviceType,
    double? maxDistanceKm,
  }) {
    return ReservationRequestFilterState(
      city: city ?? this.city,
      dateRange: dateRange ?? this.dateRange,
      serviceType: serviceType ?? this.serviceType,
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
    );
  }
}

/// Service type options matching API values.
const List<String> kReservationServiceTypes = [
  'boarding',
  'walking',
  'daycare',
  'pet_sitting',
  'house_sitting',
  'dog_walking',
];

/// Minimal custom dialog to filter reservation requests by city, dates, and service type.
class ReservationRequestFilterDialog extends StatefulWidget {
  const ReservationRequestFilterDialog({
    super.key,
    required this.initialState,
    required this.onApply,
    required this.onClear,
  });

  final ReservationRequestFilterState initialState;
  final void Function(ReservationRequestFilterState state) onApply;
  final VoidCallback onClear;

  static Future<void> show(
    BuildContext context, {
    required ReservationRequestFilterState initialState,
    required void Function(ReservationRequestFilterState state) onApply,
    required VoidCallback onClear,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ReservationRequestFilterDialog(
        initialState: initialState,
        onApply: onApply,
        onClear: onClear,
      ),
    );
  }

  @override
  State<ReservationRequestFilterDialog> createState() =>
      _ReservationRequestFilterDialogState();
}

class _ReservationRequestFilterDialogState
    extends State<ReservationRequestFilterDialog> {
  late TextEditingController _cityController;
  DateTimeRange? _dateRange;
  String? _serviceType;
  double _maxDistanceKm = 0;

  @override
  void initState() {
    super.initState();
    _cityController = TextEditingController(
      text: widget.initialState.city ?? '',
    );
    _dateRange = widget.initialState.dateRange;
    _serviceType = widget.initialState.serviceType;
    _maxDistanceKm = widget.initialState.maxDistanceKm ?? 0;
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 40.h),
      backgroundColor: Colors.transparent,
      child: Builder(
        builder: (context) => Container(
          constraints: BoxConstraints(maxWidth: 400.w),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(24.r),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary(context).withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.fromLTRB(24.w, 20.h, 16.w, 16.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InterText(
                        text: 'filter_requests_title'.tr,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(20.r),
                          child: Padding(
                            padding: EdgeInsets.all(8.w),
                            child: Icon(
                              Icons.close_rounded,
                              size: 24.sp,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: AppColors.divider(context)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionLabel('filter_location'.tr, context),
                    SizedBox(height: 10.h),
                    TextField(
                      controller: _cityController,
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: AppColors.textPrimary(context),
                      ),
                      decoration: InputDecoration(
                        hintText: 'filter_city_hint'.tr,
                        hintStyle: TextStyle(
                          fontSize: 15.sp,
                          color: AppColors.textSecondary(context),
                        ),
                        filled: true,
                        fillColor: AppColors.inputFill(context),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 18.w,
                          vertical: 14.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          borderSide: BorderSide(
                            color: AppColors.primaryColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),
                    _buildSectionLabel('filter_service_type'.tr, context),
                    SizedBox(height: 10.h),
                    Wrap(
                      spacing: 10.w,
                      runSpacing: 10.h,
                      children: kReservationServiceTypes.map((service) {
                        final isSelected = _serviceType == service;
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _serviceType = isSelected ? null : service;
                              });
                            },
                            borderRadius: BorderRadius.circular(20.r),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 10.h,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primaryColor
                                    : AppColors.inputFill(context),
                                borderRadius: BorderRadius.circular(20.r),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primaryColor
                                      : AppColors.divider(context),
                                ),
                              ),
                              child: InterText(
                                text: service.replaceAll('_', ' '),
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? AppColors.whiteColor
                                    : AppColors.textPrimary(context),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 24.h),
                    _buildSectionLabel('filter_dates'.tr, context),
                    SizedBox(height: 10.h),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _pickDateRange,
                        borderRadius: BorderRadius.circular(16.r),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 18.w,
                            vertical: 14.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.inputFill(context),
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 20.sp,
                                color: AppColors.textSecondary(context),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: InterText(
                                  text: _dateRange == null
                                      ? 'filter_any_dates'.tr
                                      : '${_formatDate(_dateRange!.start)} – ${_formatDate(_dateRange!.end)}',
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w500,
                                  color: _dateRange == null
                                      ? AppColors.textSecondary(context)
                                      : AppColors.textPrimary(context),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 22.sp,
                                color: AppColors.textSecondary(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),
                    _buildSectionLabel('filter_distance'.tr, context),
                    SizedBox(height: 10.h),
                    Column(
                      children: [
                        Slider(
                          value: _maxDistanceKm,
                          min: 0,
                          max: 500,
                          divisions: 50,
                          label: _maxDistanceKm == 0
                              ? 'filter_all_distances'.tr
                              : '${_maxDistanceKm.toInt()} km',
                          onChanged: (value) {
                            setState(() => _maxDistanceKm = value);
                          },
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 18.w),
                          child: InterText(
                            text: _maxDistanceKm == 0
                                ? 'filter_all_distances'.tr
                                : 'filter_distance_km'
                                    .trParams({'km': _maxDistanceKm.toInt().toString()}),
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 28.h),
                    // Clear (text) + Apply (full-width primary button)
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            widget.onClear();
                            Navigator.of(context).pop();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary(context),
                          ),
                          child: InterText(
                            text: 'filter_clear'.tr,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                        const Spacer(),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              foregroundColor: AppColors.whiteColor,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                            ),
                            onPressed: () {
                              widget.onApply(
                                ReservationRequestFilterState(
                                  city: _cityController.text.trim().isEmpty
                                      ? null
                                      : _cityController.text.trim(),
                                  dateRange: _dateRange,
                                  serviceType: _serviceType,
                                  maxDistanceKm:
                                      _maxDistanceKm > 0 ? _maxDistanceKm : null,
                                ),
                              );
                              Navigator.of(context).pop();
                            },
                            child: InterText(
                              text: 'filter_apply'.tr,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.whiteColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, BuildContext context) {
    return InterText(
      text: label,
      fontSize: 13.sp,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary(context),
    );
  }

  String _formatDate(DateTime d) {
    final local = d.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTimeRange initial;
    if (_dateRange != null) {
      // Clamp existing range so end is not after today
      final start = _dateRange!.start.isAfter(today)
          ? today
          : _dateRange!.start;
      final end = _dateRange!.end.isAfter(today) ? today : _dateRange!.end;
      initial = DateTimeRange(
        start: start,
        end: end.isBefore(start) ? start : end,
      );
    } else {
      initial = DateTimeRange(start: today, end: today);
    }
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: today,
      initialDateRange: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppColors.primaryColor),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _dateRange = picked);
    }
  }
}
