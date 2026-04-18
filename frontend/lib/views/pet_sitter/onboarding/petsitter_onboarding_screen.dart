import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/controllers/petsitter_onboarding_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_text_field.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

class PetsitterOnboardingScreen extends StatefulWidget {
  const PetsitterOnboardingScreen({super.key});

  @override
  State<PetsitterOnboardingScreen> createState() =>
      _PetsitterOnboardingScreenState();
}

class _PetsitterOnboardingScreenState extends State<PetsitterOnboardingScreen> {
  late PetsitterOnboardingController _controller;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(PetsitterOnboardingController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        leading: _currentStep > 0
            ? IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _currentStep--;
                  });
                },
              )
            : BackButton(),
        title: PoppinsText(
          text: 'Complete Your Profile',
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            _buildProgressIndicator(),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20.w),
                child: Form(
                  key: _controller.formKey,
                  child: _buildStepContent(),
                ),
              ),
            ),

            // Navigation Buttons
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < 2 ? 8.w : 0),
              height: 4.h,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primaryColor
                    : AppColors.grey300Color,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      default:
        return _buildStep1();
    }
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PoppinsText(
          text: 'Personal Information',
          fontSize: 20.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary(context),
        ),
        SizedBox(height: 8.h),
        InterText(
          text: 'Tell us about yourself',
          fontSize: 14.sp,
          color: AppColors.textSecondary(context),
        ),
        SizedBox(height: 24.h),

        // Bio
        CustomTextField(
          labelText: 'Bio',
          controller: _controller.bioController,
          hintText: 'Tell pet owners about yourself and your experience...',
          maxLines: 5,
        ),
        SizedBox(height: 24.h),

        // Skills (optional — sprint 5 step 3)
        CustomTextField(
          labelText: 'Skills (optional)',
          controller: _controller.skillsController,
          hintText: 'e.g., Dog training, Cat care, Pet grooming',
          maxLines: 3,
        ),
        SizedBox(height: 24.h),

        // Hourly Rate
        CustomTextField(
          labelText: 'Hourly Rate',
          controller: _controller.hourlyRateController,
          hintText: '0.00',
          keyboardType: TextInputType.numberWithOptions(decimal: true),
        ),
        SizedBox(height: 24.h),
        // Currency for hourly rate
        Obx(
          () => CustomDropdown<String>(
            items: _controller.currencyOptions,
            initialItem: CurrencyHelper.label(
              _controller.selectedCurrency.value,
            ),
            onChanged: _controller.updateCurrency,
            closedHeaderPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 12.h,
            ),
            decoration: CustomDropdownDecoration(
              closedBorder: Border.all(color: AppColors.divider(context)),
              closedBorderRadius: BorderRadius.circular(30.r),
              headerStyle: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary(context),
              ),
            ),
            disabledDecoration: CustomDropdownDisabledDecoration(
              border: Border.all(color: AppColors.divider(context)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PoppinsText(
          text: 'Service Details',
          fontSize: 20.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary(context),
        ),
        SizedBox(height: 8.h),
        InterText(
          text: 'What services do you offer?',
          fontSize: 14.sp,
          color: AppColors.textSecondary(context),
        ),
        SizedBox(height: 24.h),

        // Service Types
        _buildServiceTypeSection(),
        SizedBox(height: 24.h),

        // Availability
        PoppinsText(
          text: 'Availability',
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary(context),
        ),
        SizedBox(height: 12.h),
        _buildAvailabilitySection(),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PoppinsText(
          text: 'Verification',
          fontSize: 20.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary(context),
        ),
        SizedBox(height: 8.h),
        InterText(
          text: 'Complete your profile to start receiving bookings',
          fontSize: 14.sp,
          color: AppColors.textSecondary(context),
        ),
        SizedBox(height: 24.h),

        // Terms and Conditions
        Obx(
          () => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _controller.acceptTerms.value,
                onChanged: (value) {
                  _controller.acceptTerms.value = value ?? false;
                },
                activeColor: AppColors.primaryColor,
              ),
              Expanded(
                child: InterText(
                  text:
                      'I agree to the Terms and Conditions and Privacy Policy',
                  fontSize: 12.sp,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24.h),

        // Information Card
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 24.sp,
                color: AppColors.primaryColor,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: InterText(
                  text:
                      'You can update your profile information anytime from settings.',
                  fontSize: 12.sp,
                  color: AppColors.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServiceTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PoppinsText(
          text: 'Service Types',
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary(context),
        ),
        SizedBox(height: 12.h),
        Obx(
          () => Wrap(
            spacing: 12.w,
            runSpacing: 12.h,
            children: _controller.serviceTypes.map((service) {
              final isSelected = _controller.selectedServices.contains(service);
              return GestureDetector(
                onTap: () => _controller.toggleService(service),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryColor
                        : AppColors.card(context),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryColor
                          : AppColors.divider(context),
                      width: 1,
                    ),
                  ),
                  child: InterText(
                    text: service,
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

  Widget _buildAvailabilitySection() {
    return Column(
      children: _controller.availabilityDays.map((day) {
        return Obx(
          () => Container(
            margin: EdgeInsets.only(bottom: 12.h),
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.divider(context), width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InterText(
                    text: day,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                Switch(
                  value: _controller.availability[day] ?? false,
                  onChanged: (value) {
                    _controller.setAvailability(day, value);
                  },
                  activeThumbColor: AppColors.primaryColor,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _currentStep--;
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  side: BorderSide(color: AppColors.primaryColor, width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(48.r),
                  ),
                ),
                child: InterText(
                  text: 'Back',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryColor,
                ),
              ),
            ),
          if (_currentStep > 0) SizedBox(width: 12.w),
          Expanded(
            flex: _currentStep == 0 ? 1 : 1,
            child: Obx(
              () => CustomButton(
                title: _currentStep == 2 ? 'Complete' : 'Next',
                onTap: _controller.isLoading.value
                    ? null
                    : () async {
                        if (_currentStep < 2) {
                          if (_validateCurrentStep()) {
                            setState(() {
                              _currentStep++;
                            });
                          }
                        } else {
                          await _controller.completeOnboarding();
                        }
                      },
                bgColor: AppColors.primaryColor,
                textColor: AppColors.whiteColor,
                height: 48.h,
                radius: 48.r,
                child: _controller.isLoading.value
                    ? SizedBox(
                        height: 20.h,
                        width: 20.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.whiteColor,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        // Sprint 5 step 3 — skills (and bio) are optional.
        final rateText = _controller.hourlyRateController.text.trim();
        if (rateText.isEmpty) return false;
        final cleaned = rateText.replaceAll(RegExp(r'[^\d.]'), '');
        final rate = double.tryParse(cleaned);
        if (rate == null || rate <= 0) {
          Get.snackbar(
            'snackbar_text_invalid_hourly_rate'.tr,
            'snackbar_text_hourly_rate_must_be_greater_than_0'.tr,
          );
          return false;
        }
        return rate > 0;
      case 1:
        return _controller.selectedServices.isNotEmpty;
      case 2:
        return _controller.acceptTerms.value;
      default:
        return false;
    }
  }
}
