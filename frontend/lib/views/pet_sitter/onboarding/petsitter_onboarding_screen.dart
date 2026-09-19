import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/petsitter_onboarding_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/views/profile/widgets/edit_profile_widgets.dart';
import 'package:hopetsit/views/profile/widgets/pet_form_widgets.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/utils/bottom_inset.dart';

/// Onboarding sitter en 3 étapes (Infos · Services · Vérification).
///
/// v565 — point 39 : modernisé avec le kit Profil (barre de progression
/// « Étape n/3 », cartes groupées, champs `ProfileInput`, pilules de services,
/// interrupteurs de disponibilité, barre de boutons collante) et ENTIÈREMENT
/// traduit (l'écran était en anglais en dur). Les valeurs envoyées au serveur
/// (`serviceTypes` / `availabilityDays` du contrôleur) ne changent pas : seul
/// l'affichage est traduit (clés `onb_svc_*` / `onb_day_*`).
class PetsitterOnboardingScreen extends StatefulWidget {
  const PetsitterOnboardingScreen({super.key});

  @override
  State<PetsitterOnboardingScreen> createState() =>
      _PetsitterOnboardingScreenState();
}

class _PetsitterOnboardingScreenState extends State<PetsitterOnboardingScreen> {
  late PetsitterOnboardingController _controller;
  int _currentStep = 0;
  static const Color _accent = AppColors.sitterAccent;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(PetsitterOnboardingController());
  }

  /// Token i18n d'une valeur anglaise du contrôleur (« Dog Walking » →
  /// `onb_svc_dog_walking`, « Monday » → `onb_day_monday`). Si la clé n'existe
  /// pas, on affiche la valeur brute (jamais une clé).
  String _label(String prefix, String raw) {
    final key = '$prefix${raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
    final t = key.tr;
    return t == key ? raw : t;
  }

  @override
  Widget build(BuildContext context) {
    return ProfileSubPageScaffold(
      title: 'onb_title'.tr,
      accent: _accent,
      scroll: false,
      padding: EdgeInsets.zero,
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
              child: Form(
                key: _controller.formKey,
                child: _buildStepContent(),
              ),
            ),
          ),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(3, (index) {
              final isActive = index <= _currentStep;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: EdgeInsets.only(right: index < 2 ? 6.w : 0),
                  height: 5.h,
                  decoration: BoxDecoration(
                    color: isActive ? _accent : AppColors.divider(context),
                    borderRadius: BorderRadius.circular(3.r),
                  ),
                ),
              );
            }),
          ),
          SizedBox(height: 6.h),
          InterText(
            text: 'onb_step_of'.trParams({'n': '${_currentStep + 1}', 'total': '3'}),
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary(context),
            maxLines: 1,
          ),
        ],
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

  Widget _stepHeader(String title, String subtitle, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h, top: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(icon, color: _accent, size: 22.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PoppinsText(
                  text: title,
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                InterText(
                  text: subtitle,
                  fontSize: 13.sp,
                  color: AppColors.textSecondary(context),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader('onb_step1_title'.tr, 'onb_step1_sub'.tr, Icons.person_rounded),
        ProfileFormCard(
          title: 'onb_section_presentation'.tr,
          icon: Icons.edit_note_rounded,
          accent: _accent,
          children: [
            ProfileInput(
              label: 'onb_bio_label'.tr,
              hint: 'onb_bio_hint'.tr,
              controller: _controller.bioController,
              accent: _accent,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              maxLines: 5,
            ),
            // Sprint 5 step 3 — compétences facultatives.
            ProfileInput(
              label: 'onb_skills_label'.tr,
              hint: 'onb_skills_hint'.tr,
              controller: _controller.skillsController,
              accent: _accent,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              maxLines: 3,
            ),
          ],
        ),
        ProfileFormCard(
          title: 'onb_section_rate'.tr,
          icon: Icons.payments_rounded,
          accent: _accent,
          children: [
            Obx(() => ProfileInput(
                  label: 'onb_hourly_rate_label'.tr,
                  hint: '0.00',
                  controller: _controller.hourlyRateController,
                  accent: _accent,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
                  ],
                  textInputAction: TextInputAction.done,
                  suffix: Padding(
                    padding: EdgeInsets.only(right: 14.w, top: 14.h),
                    child: Text(
                      CurrencyHelper.symbol(_controller.selectedCurrency.value),
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: _accent,
                      ),
                    ),
                  ),
                  validator: (v) {
                    final cleaned = (v ?? '').replaceAll(',', '.').replaceAll(RegExp(r'[^\d.]'), '');
                    final rate = double.tryParse(cleaned);
                    if (rate == null || rate <= 0) return 'onb_rate_required'.tr;
                    return null;
                  },
                )),
            Obx(() {
              final label = CurrencyHelper.label(_controller.selectedCurrency.value);
              return ProfileDropdownField<String>(
                key: ValueKey('onb_currency_$label'),
                label: 'onb_currency_label'.tr,
                value: _controller.currencyOptions.contains(label)
                    ? label
                    : _controller.currencyOptions.first,
                accent: _accent,
                prefix: Icon(Icons.currency_exchange_rounded, color: _accent, size: 20.sp),
                items: _controller.currencyOptions
                    .map((l) => DropdownMenuItem(
                          value: l,
                          child: Text(l, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: _controller.updateCurrency,
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader('onb_step2_title'.tr, 'onb_step2_sub'.tr, Icons.pets_rounded),
        ProfileFormCard(
          title: 'onb_service_types'.tr,
          icon: Icons.checklist_rounded,
          accent: _accent,
          children: [
            PetMultiPills(
              accent: _accent,
              selected: _controller.selectedServices,
              onToggle: _controller.toggleService,
              options: _controller.serviceTypes
                  .map((s) => MapEntry(s, _label('onb_svc_', s)))
                  .toList(),
            ),
          ],
        ),
        ProfileFormCard(
          title: 'onb_availability'.tr,
          icon: Icons.calendar_month_rounded,
          accent: _accent,
          gap: 4,
          children: [
            for (var i = 0; i < _controller.availabilityDays.length; i++) ...[
              Obx(() {
                final day = _controller.availabilityDays[i];
                return ProfileSwitchRow(
                  icon: Icons.today_rounded,
                  title: _label('onb_day_', day),
                  value: _controller.availability[day] ?? false,
                  accent: _accent,
                  onChanged: (v) => _controller.setAvailability(day, v),
                );
              }),
              if (i < _controller.availabilityDays.length - 1)
                Divider(
                  height: 10.h,
                  thickness: 1,
                  indent: 48.w,
                  color: AppColors.divider(context).withValues(alpha: 0.6),
                ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader('onb_step3_title'.tr, 'onb_step3_sub'.tr, Icons.verified_rounded),
        ProfileFormCard(
          accent: _accent,
          children: [
            Obx(() {
              final on = _controller.acceptTerms.value;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _controller.acceptTerms.value = !on,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 24.w,
                      height: 24.w,
                      margin: EdgeInsets.only(top: 1.h),
                      decoration: BoxDecoration(
                        color: on ? _accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(7.r),
                        border: Border.all(
                          color: on ? _accent : AppColors.divider(context),
                          width: 1.5,
                        ),
                      ),
                      child: on
                          ? Icon(Icons.check_rounded, size: 16.sp, color: Colors.white)
                          : null,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: InterText(
                        text: 'onb_terms'.tr,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary(context),
                        maxLines: 4,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
        ProfileInfoBanner(
          icon: Icons.info_outline_rounded,
          text: 'onb_info'.tr,
          accent: _accent,
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Padding(
      // v569 — le SafeArea de ProfileSubPageScaffold n'applique rien sur le
      // Samsung de Daniel : « Suivant » passait sous la barre système.
      padding: EdgeInsets.fromLTRB(
          16.w, 8.h, 16.w, 12.h + appBottomInsetInsideSafeArea(context)),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(
              child: ProfileSecondaryButton(
                label: 'onb_back'.tr,
                accent: _accent,
                icon: Icons.arrow_back_rounded,
                onTap: () => setState(() => _currentStep--),
              ),
            ),
            SizedBox(width: 10.w),
          ],
          Expanded(
            flex: 2,
            child: Obx(
              () => ProfilePrimaryButton(
                label: _currentStep == 2 ? 'onb_complete'.tr : 'onb_next'.tr,
                accent: _accent,
                loading: _controller.isLoading.value,
                icon: _currentStep == 2 ? Icons.check_rounded : Icons.arrow_forward_rounded,
                onTap: _controller.isLoading.value
                    ? null
                    : () async {
                        if (_currentStep < 2) {
                          if (_validateCurrentStep()) {
                            setState(() => _currentStep++);
                          }
                        } else {
                          if (!_validateCurrentStep()) return;
                          await _controller.completeOnboarding();
                        }
                      },
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
        final cleaned = rateText.replaceAll(',', '.').replaceAll(RegExp(r'[^\d.]'), '');
        final rate = double.tryParse(cleaned);
        if (rateText.isEmpty || rate == null || rate <= 0) {
          _controller.formKey.currentState?.validate();
          CustomSnackbar.showWarning(
            title: 'snackbar_text_invalid_hourly_rate'.tr,
            message: 'snackbar_text_hourly_rate_must_be_greater_than_0'.tr,
          );
          return false;
        }
        return true;
      case 1:
        if (_controller.selectedServices.isEmpty) {
          CustomSnackbar.showWarning(
            title: 'snackbar_text_required'.tr,
            message: 'onb_select_service'.tr,
          );
          return false;
        }
        return true;
      case 2:
        if (!_controller.acceptTerms.value) {
          CustomSnackbar.showWarning(
            title: 'snackbar_text_required'.tr,
            message: 'onb_accept_terms'.tr,
          );
          return false;
        }
        return true;
      default:
        return false;
    }
  }
}
