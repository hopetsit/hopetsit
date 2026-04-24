// v19.1.5 — Dedicated "Mes tarifs" screen, pulled out of the Edit profile
// form so sitters/walkers can tweak rates without scrolling through the full
// profile form. Reuses the existing edit controllers to keep backend wiring
// unchanged.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/edit_sitter_profile_controller.dart';
import 'package:hopetsit/controllers/edit_walker_profile_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_text_field.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart' show CustomButton;

class MyRatesScreen extends StatelessWidget {
  final String role; // 'sitter' | 'walker'

  const MyRatesScreen({super.key, required this.role});

  Color get _accent => role == 'walker'
      ? const Color(0xFF16A34A)
      : const Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    if (role == 'walker') {
      return _WalkerRates(accent: _accent);
    }
    return _SitterRates(accent: _accent);
  }
}

class _WalkerRates extends StatelessWidget {
  final Color accent;
  const _WalkerRates({required this.accent});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(EditWalkerProfileController());
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: accent),
        leading: const BackButton(),
        title: PoppinsText(
          text: 'my_rates_section_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: Obx(() {
        if (controller.isFetching.value) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          );
        }
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderCard(
                  accent: accent,
                  subtitle: 'my_rates_walker_hint'.tr,
                ),
                SizedBox(height: 20.h),
                // v20 — Simple currency dropdown (walker has no per-rate currency,
                // so we just display EUR by default). Info text for user.
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.euro_rounded, color: accent, size: 18.sp),
                      SizedBox(width: 8.w),
                      InterText(
                        text: 'walker_currency_info'.tr,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary(context),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                _RateField(
                  label: 'walker_rate_30min_label'.tr,
                  hint: 'walker_rate_hint_8'.tr,
                  controller: controller.halfHourRateController,
                  accent: accent,
                  errorText: 'walker_rate_invalid'.tr,
                ),
                SizedBox(height: 16.h),
                _RateField(
                  label: 'walker_rate_60min_label'.tr,
                  hint: 'walker_rate_hint_15'.tr,
                  controller: controller.hourlyRateController,
                  accent: accent,
                  errorText: 'walker_rate_invalid'.tr,
                ),
                SizedBox(height: 32.h),
                Obx(
                  () => CustomButton(
                    title: controller.isLoading.value
                        ? 'edit_profile_button_updating'.tr
                        : 'edit_profile_button'.tr,
                    onTap: controller.isLoading.value
                        ? null
                        : () => controller.handleUpdateProfileWithNavigation(),
                    bgColor: accent,
                    textColor: AppColors.whiteColor,
                    height: 48.h,
                    radius: 48.r,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _SitterRates extends StatelessWidget {
  final Color accent;
  const _SitterRates({required this.accent});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(EditSitterProfileController());
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: accent),
        leading: const BackButton(),
        title: PoppinsText(
          text: 'my_rates_section_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: Obx(() {
        if (controller.isFetching.value) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          );
        }
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderCard(
                  accent: accent,
                  subtitle: 'my_rates_sitter_hint'.tr,
                ),
                SizedBox(height: 20.h),
                // v20 — Currency picker (EUR / USD). Mandatory BEFORE rates so
                // the user picks the currency then fills amounts.
                InterText(
                  text: 'currency_label'.tr,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(context),
                ),
                SizedBox(height: 6.h),
                Obx(() {
                  final current = controller.selectedCurrency.value;
                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.inputFill(context),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: accent.withValues(alpha: 0.25)),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: ['EUR', 'USD', 'GBP', 'CHF'].contains(current)
                            ? current
                            : 'EUR',
                        items: const [
                          DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                          DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                          DropdownMenuItem(value: 'GBP', child: Text('GBP (£)')),
                          DropdownMenuItem(value: 'CHF', child: Text('CHF')),
                        ],
                        onChanged: (v) {
                          if (v != null) controller.updateCurrency(v);
                        },
                      ),
                    ),
                  );
                }),
                SizedBox(height: 16.h),
                CustomTextField(
                  labelText: 'sitter_detail_daily_rate_label'.tr,
                  hintText: '0.00',
                  controller: controller.dailyRateController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                ),
                SizedBox(height: 16.h),
                CustomTextField(
                  labelText: 'sitter_detail_weekly_rate_label'.tr,
                  hintText: '0.00',
                  controller: controller.weeklyRateController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                ),
                SizedBox(height: 16.h),
                CustomTextField(
                  labelText: 'sitter_detail_monthly_rate_label'.tr,
                  hintText: '0.00',
                  controller: controller.monthlyRateController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                ),
                SizedBox(height: 32.h),
                Obx(
                  () => CustomButton(
                    title: controller.isLoading.value
                        ? 'edit_profile_button_updating'.tr
                        : 'edit_profile_button'.tr,
                    onTap: controller.isLoading.value
                        ? null
                        : () => controller.handleUpdateProfileWithNavigation(),
                    bgColor: accent,
                    textColor: AppColors.whiteColor,
                    height: 48.h,
                    radius: 48.r,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// Shared helpers
class _HeaderCard extends StatelessWidget {
  final Color accent;
  final String subtitle;
  const _HeaderCard({required this.accent, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.12),
            accent.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.euro_rounded, size: 22.sp, color: accent),
          SizedBox(width: 10.w),
          Expanded(
            child: InterText(
              text: subtitle,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _RateField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final Color accent;
  final String errorText;

  const _RateField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.accent,
    required this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InterText(
          text: label,
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary(context),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
          ],
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: hint,
            suffixText: '€',
            suffixStyle: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
            filled: true,
            fillColor: AppColors.inputFill(context),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 20.w,
              vertical: 14.h,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30.r),
              borderSide: BorderSide.none,
            ),
          ),
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary(context),
          ),
          validator: (value) {
            final v = (value ?? '').trim().replaceAll(',', '.');
            if (v.isEmpty) return null;
            final parsed = double.tryParse(v);
            if (parsed == null || parsed < 0) return errorText;
            return null;
          },
        ),
      ],
    );
  }
}
