// v19.1.5 — Dedicated "Mes tarifs" screen, pulled out of the Edit profile
// form so sitters/walkers can tweak rates without scrolling through the full
// profile form. Reuses the existing edit controllers to keep backend wiring
// unchanged.
//
// v565 — point 39 : modernisé avec le kit Profil (cartes groupées Devise /
// Tarifs / Options, champs ProfileInput avec suffixe devise, bouton
// « Enregistrer » collant, états chargement / erreur « Réessayer »).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/edit_sitter_profile_controller.dart';
import 'package:hopetsit/controllers/edit_walker_profile_controller.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/views/profile/widgets/edit_profile_widgets.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/utils/bottom_inset.dart';

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

/// Coquille commune : scaffold + états + bouton collant.
class _RatesShell extends StatelessWidget {
  final Color accent;
  final RxBool isFetching;
  final RxString loadError;
  final RxBool isLoading;
  final VoidCallback onRetry;
  final VoidCallback onSave;
  final List<Widget> children;

  const _RatesShell({
    required this.accent,
    required this.isFetching,
    required this.loadError,
    required this.isLoading,
    required this.onRetry,
    required this.onSave,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileSubPageScaffold(
      title: 'my_rates_section_title'.tr,
      accent: accent,
      scroll: false,
      padding: EdgeInsets.zero,
      body: Obx(() {
        if (isFetching.value) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          );
        }
        if (loadError.value.isNotEmpty) {
          return ProfileEmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'my_rates_load_error_title'.tr,
            message: loadError.value,
            accent: accent,
            error: true,
            actionLabel: 'common_retry'.tr,
            onAction: onRetry,
          );
        }
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
            Padding(
              // v569 — barre d'action collée en bas : le SafeArea de
              // ProfileSubPageScaffold n'applique rien sur le Samsung de
              // Daniel → le bouton passait sous la barre système.
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w,
                  12.h + appBottomInsetInsideSafeArea(context)),
              child: Obx(() => ProfileSaveBar(
                    label: isLoading.value
                        ? 'edit_profile_button_updating'.tr
                        : 'edit_profile_button'.tr,
                    accent: accent,
                    loading: isLoading.value,
                    icon: Icons.check_rounded,
                    onTap: isLoading.value ? null : onSave,
                  )),
            ),
          ],
        );
      }),
    );
  }
}

class _WalkerRates extends StatelessWidget {
  final Color accent;
  const _WalkerRates({required this.accent});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(EditWalkerProfileController());
    return _RatesShell(
      accent: accent,
      isFetching: controller.isFetching,
      loadError: controller.loadError,
      isLoading: controller.isLoading,
      onRetry: () => controller.loadProfileData(),
      onSave: () => controller.updateRatesOnly(),
      children: [
        SizedBox(height: 4.h),
        ProfileInfoBanner(
          icon: Icons.payments_rounded,
          text: 'my_rates_walker_hint'.tr,
          accent: accent,
        ),
        // v540 — sélecteur de devise pour le PROMENEUR aussi (won, yen…).
        _CurrencyCard(
          accent: accent,
          selected: controller.selectedCurrency,
          onChanged: controller.updateCurrency,
          hint: 'walker_currency_info'.tr,
        ),
        // v23.1.153 / v445 — 30 min / 1 h / 2 h (le 90 min est retiré ; le
        // contrôleur garde le champ pour compat données).
        ProfileFormCard(
          title: 'my_rates_section_amounts'.tr,
          icon: Icons.directions_walk_rounded,
          accent: accent,
          children: [
            Obx(() => _RateField(
                  label: 'walker_rate_30min_label'.tr,
                  hint: 'walker_rate_hint_8'.tr,
                  controller: controller.halfHourRateController,
                  accent: accent,
                  suffix: CurrencyHelper.symbol(controller.selectedCurrency.value),
                  errorText: 'walker_rate_invalid'.tr,
                )),
            Obx(() => _RateField(
                  label: 'walker_rate_60min_label'.tr,
                  hint: 'walker_rate_hint_15'.tr,
                  controller: controller.hourlyRateController,
                  accent: accent,
                  suffix: CurrencyHelper.symbol(controller.selectedCurrency.value),
                  errorText: 'walker_rate_invalid'.tr,
                )),
            Obx(() => _RateField(
                  label: 'walker_rate_120min_label'.tr,
                  hint: 'walker_rate_hint_30'.tr,
                  controller: controller.twoHourRateController,
                  accent: accent,
                  suffix: CurrencyHelper.symbol(controller.selectedCurrency.value),
                  errorText: 'walker_rate_invalid'.tr,
                )),
          ],
        ),
        ProfileFormCard(
          title: 'my_rates_section_extras'.tr,
          icon: Icons.tune_rounded,
          accent: accent,
          children: [
            Obx(() => _RateField(
                  label: 'rates_extra_pet_label'.tr,
                  hint: '0',
                  controller: controller.extraPetRateController,
                  accent: accent,
                  suffix: CurrencyHelper.symbol(controller.selectedCurrency.value),
                  errorText: 'walker_rate_invalid'.tr,
                )),
            _ResponseTimeField(
              controller: controller.responseTimeController,
              accent: accent,
            ),
          ],
        ),
      ],
    );
  }
}

class _SitterRates extends StatelessWidget {
  final Color accent;
  const _SitterRates({required this.accent});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(EditSitterProfileController());
    return _RatesShell(
      accent: accent,
      isFetching: controller.isFetching,
      loadError: controller.loadError,
      isLoading: controller.isLoading,
      onRetry: () => controller.loadProfileData(),
      onSave: () => controller.updateRatesOnly(),
      children: [
        SizedBox(height: 4.h),
        ProfileInfoBanner(
          icon: Icons.payments_rounded,
          text: 'my_rates_sitter_hint'.tr,
          accent: accent,
        ),
        // v20 — devise AVANT les montants.
        _CurrencyCard(
          accent: accent,
          selected: controller.selectedCurrency,
          onChanged: controller.updateCurrency,
        ),
        ProfileFormCard(
          title: 'my_rates_section_amounts'.tr,
          icon: Icons.home_rounded,
          accent: accent,
          children: [
            Obx(() => _RateField(
                  label: 'sitter_detail_daily_rate_label'.tr,
                  hint: '0.00',
                  controller: controller.dailyRateController,
                  accent: accent,
                  suffix: CurrencyHelper.symbol(controller.selectedCurrency.value),
                  errorText: 'walker_rate_invalid'.tr,
                )),
            Obx(() => _RateField(
                  label: 'sitter_detail_weekly_rate_label'.tr,
                  hint: '0.00',
                  controller: controller.weeklyRateController,
                  accent: accent,
                  suffix: CurrencyHelper.symbol(controller.selectedCurrency.value),
                  errorText: 'walker_rate_invalid'.tr,
                )),
            Obx(() => _RateField(
                  label: 'sitter_detail_monthly_rate_label'.tr,
                  hint: '0.00',
                  controller: controller.monthlyRateController,
                  accent: accent,
                  suffix: CurrencyHelper.symbol(controller.selectedCurrency.value),
                  errorText: 'walker_rate_invalid'.tr,
                )),
          ],
        ),
        ProfileFormCard(
          title: 'my_rates_section_extras'.tr,
          icon: Icons.tune_rounded,
          accent: accent,
          children: [
            Obx(() => _RateField(
                  label: 'rates_extra_pet_label'.tr,
                  hint: '0.00',
                  controller: controller.extraPetRateController,
                  accent: accent,
                  suffix: CurrencyHelper.symbol(controller.selectedCurrency.value),
                  errorText: 'walker_rate_invalid'.tr,
                )),
            _ResponseTimeField(
              controller: controller.responseTimeController,
              accent: accent,
            ),
          ],
        ),
      ],
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────

/// Carte « Devise » : liste centrale (won ₩ et yen ¥ inclus).
class _CurrencyCard extends StatelessWidget {
  final Color accent;
  final RxString selected;
  final void Function(String?) onChanged;
  final String? hint;
  const _CurrencyCard({
    required this.accent,
    required this.selected,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileFormCard(
      title: 'my_rates_section_currency'.tr,
      icon: Icons.currency_exchange_rounded,
      accent: accent,
      children: [
        Obx(() {
          final current = selected.value;
          final value = CurrencyHelper.supportedCurrencies.contains(current)
              ? current
              : CurrencyHelper.defaultCurrency;
          return ProfileDropdownField<String>(
            key: ValueKey('currency_$value'),
            label: 'currency_label'.tr,
            value: value,
            accent: accent,
            prefix: Icon(Icons.payments_outlined, color: accent, size: 20.sp),
            items: CurrencyHelper.supportedCurrencies
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(CurrencyHelper.label(c),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          );
        }),
        if (hint != null && hint!.isNotEmpty)
          ProfileInfoBanner(
            icon: Icons.info_outline_rounded,
            text: hint!,
            accent: accent,
          ),
      ],
    );
  }
}

class _RateField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final Color accent;
  final String errorText;
  final String suffix;

  const _RateField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.accent,
    required this.errorText,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileInput(
      label: label,
      hint: hint,
      controller: controller,
      accent: accent,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
      ],
      textInputAction: TextInputAction.next,
      suffix: Padding(
        padding: EdgeInsets.only(right: 14.w, top: 14.h),
        child: Text(
          suffix,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ),
      ),
      validator: (value) {
        final v = (value ?? '').trim().replaceAll(',', '.');
        if (v.isEmpty) return null;
        final parsed = double.tryParse(v);
        if (parsed == null || parsed < 0) return errorText;
        return null;
      },
    );
  }
}

/// Additif — temps de réponse type (minutes). Suffixe "min".
class _ResponseTimeField extends StatelessWidget {
  final TextEditingController controller;
  final Color accent;

  const _ResponseTimeField({
    required this.controller,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileInput(
      label: 'rates_response_time_label'.tr,
      hint: '0',
      controller: controller,
      accent: accent,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textInputAction: TextInputAction.done,
      suffix: Padding(
        padding: EdgeInsets.only(right: 14.w, top: 14.h),
        child: Text(
          'min',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ),
      ),
    );
  }
}
