// v566 — « Informations de facturation » (demande Daniel 18/09) : CIF, NIE,
// NIF, SIRET, n° TVA, EIN, passeport, numéro d'entreprise… saisis ici et
// repris sur les factures (aperçu + PDF). Partagé par les 3 rôles, couleur du
// rôle courant. Tout est FACULTATIF.
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/controllers/billing_info_controller.dart';
import 'package:hopetsit/models/billing_info_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/profile/widgets/edit_profile_widgets.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

class BillingInfoScreen extends StatefulWidget {
  final Color? accent;
  const BillingInfoScreen({super.key, this.accent});

  @override
  State<BillingInfoScreen> createState() => _BillingInfoScreenState();
}

class _BillingInfoScreenState extends State<BillingInfoScreen> {
  late final BillingInfoController c;

  Color get _accent => widget.accent ?? currentRoleAccent();

  @override
  void initState() {
    super.initState();
    c = BillingInfoController.ensure();
    if (c.isLoadedForCurrentUser) {
      // Déjà connu (rangée du Profil / factures) : on repart de la dernière
      // valeur enregistrée, sans écraser plus tard une saisie en cours.
      c.resetForm();
    } else {
      // Après la 1re frame : jamais de changement d'état pendant un build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) c.load();
      });
    }
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final err = await c.save();
    if (!mounted) return;
    if (err == null) {
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'billing_saved'.tr,
      );
      Navigator.of(context).maybePop();
    } else if (c.idNumberError.value.isEmpty) {
      // (l'erreur de validation s'affiche déjà sous le champ)
      CustomSnackbar.showError(title: 'common_error'.tr, message: err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return ProfileSubPageScaffold(
      title: 'billing_title'.tr,
      accent: accent,
      bottom: Obx(() {
        final ready = c.loaded.value;
        final saving = c.saving.value;
        if (!ready) return const SizedBox.shrink();
        return ProfileSaveBar(
          label: 'common_save'.tr,
          accent: accent,
          icon: Icons.check_rounded,
          loading: saving,
          note: 'billing_save_note'.tr,
          onTap: saving ? null : _save,
        );
      }),
      body: Obx(() {
        final ready = c.loaded.value;
        final loading = c.loading.value;
        final err = c.error.value;
        if (!ready && (loading || err.isEmpty)) {
          return Padding(
            padding: EdgeInsets.only(top: 120.h),
            child: Center(child: CircularProgressIndicator(color: accent)),
          );
        }
        if (!ready) {
          return Padding(
            padding: EdgeInsets.only(top: 40.h),
            child: ProfileEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'billing_load_error_title'.tr,
              message: err,
              accent: accent,
              error: true,
              actionLabel: 'common_retry'.tr,
              onAction: c.load,
            ),
          );
        }
        return _form(context, accent);
      }),
    );
  }

  Widget _form(BuildContext context, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileInfoBanner(
          icon: Icons.receipt_long_rounded,
          text: 'billing_intro'.tr,
          accent: accent,
        ),
        // ── Je suis ──────────────────────────────────────────────────────
        ProfileFormCard(
          title: 'billing_card_type'.tr,
          icon: Icons.badge_rounded,
          children: [
            Obx(() {
              final t = c.type.value;
              return Row(
                children: [
                  Expanded(
                    child: _TypePill(
                      label: 'billing_type_individual'.tr,
                      icon: Icons.person_rounded,
                      selected: t != 'business',
                      accent: accent,
                      onTap: () => c.setType('individual'),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _TypePill(
                      label: 'billing_type_business'.tr,
                      icon: Icons.business_center_rounded,
                      selected: t == 'business',
                      accent: accent,
                      onTap: () => c.setType('business'),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
        // ── Identité ─────────────────────────────────────────────────────
        ProfileFormCard(
          title: 'billing_card_identity'.tr,
          icon: Icons.person_outline_rounded,
          children: [
            Obx(() {
              final business = c.type.value == 'business';
              return ProfileInput(
                label: business ? 'billing_company_name'.tr : 'billing_legal_name'.tr,
                hint: business ? 'billing_company_name_hint'.tr : 'billing_legal_name_hint'.tr,
                controller: c.legalNameCtl,
                accent: accent,
                maxLength: 120,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              );
            }),
          ],
        ),
        // ── Identifiant ──────────────────────────────────────────────────
        ProfileFormCard(
          title: 'billing_card_id'.tr,
          icon: Icons.fingerprint_rounded,
          children: [
            Obx(() {
              final country = c.country.value;
              final current = c.idType.value;
              final options = c.idTypeOptions;
              return ProfileDropdownField<String>(
                // `initialValue` n'est lu qu'à la création : la clé force la
                // reconstruction quand le pays (donc la liste) change.
                key: ValueKey<String>('billing-idtype-$country-$current'),
                label: 'billing_id_type'.tr,
                hint: 'billing_id_type_hint'.tr,
                value: current,
                accent: accent,
                items: [
                  DropdownMenuItem<String>(
                    value: '',
                    child: Text('billing_id_none'.tr, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  for (final t in options)
                    DropdownMenuItem<String>(
                      value: t,
                      child: Text(BillingInfo.idTypeLabel(t), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: c.setIdType,
              );
            }),
            Obx(() {
              final current = c.idType.value;
              final err = c.idNumberError.value;
              final label = BillingInfo.idTypeLabel(current);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ProfileInput(
                    label: label.isEmpty
                        ? 'billing_id_number'.tr
                        : '${'billing_id_number'.tr} · $label',
                    hint: _hintFor(current),
                    controller: c.idNumberCtl,
                    accent: accent,
                    maxLength: 40,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) {
                      if (c.idNumberError.value.isNotEmpty) c.idNumberError.value = '';
                    },
                  ),
                  if (err.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 6.h, left: 4.w),
                      child: InterText(
                        text: err,
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.errorColor,
                        maxLines: 2,
                      ),
                    ),
                ],
              );
            }),
            Obx(() {
              final business = c.type.value == 'business';
              final current = c.idType.value;
              // Pas de doublon quand l'identifiant choisi EST le n° TVA.
              if (!business || current == 'vat') return const SizedBox.shrink();
              return ProfileInput(
                label: 'billing_vat_number'.tr,
                hint: 'billing_vat_number_hint'.tr,
                controller: c.vatNumberCtl,
                accent: accent,
                maxLength: 40,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
              );
            }),
          ],
        ),
        // ── Adresse de facturation ───────────────────────────────────────
        ProfileFormCard(
          title: 'billing_card_address'.tr,
          icon: Icons.home_work_rounded,
          children: [
            ProfileInput(
              label: 'billing_address'.tr,
              hint: 'billing_address_hint'.tr,
              controller: c.addressCtl,
              accent: accent,
              maxLength: 200,
              keyboardType: TextInputType.streetAddress,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: ProfileInput(
                    label: 'billing_postal_code'.tr,
                    controller: c.postalCodeCtl,
                    accent: accent,
                    maxLength: 16,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  flex: 3,
                  child: ProfileInput(
                    label: 'billing_city'.tr,
                    controller: c.cityCtl,
                    accent: accent,
                    maxLength: 80,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                  ),
                ),
              ],
            ),
            Obx(() {
              final iso = c.country.value;
              return _CountryField(
                label: 'billing_country'.tr,
                iso: iso,
                accent: accent,
                onChanged: c.setCountry,
              );
            }),
          ],
        ),
        SizedBox(height: 8.h),
      ],
    );
  }

  String? _hintFor(String idType) {
    switch (idType) {
      case 'nif':
        return '12345678Z';
      case 'nie':
        return 'X1234567L';
      case 'cif':
        return 'B12345678';
      case 'siret':
        return '123 456 789 00012';
      case 'vat':
        return 'FR12 345678901';
      case 'ein':
        return '12-3456789';
      default:
        return null;
    }
  }
}

/// Pilule de choix (Particulier / Professionnel).
class _TypePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  const _TypePill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.textPrimary(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 46.h,
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          decoration: BoxDecoration(
            color: selected ? accent : accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? accent : accent.withValues(alpha: 0.22),
              width: 1.1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17.sp, color: selected ? Colors.white : accent),
              SizedBox(width: 6.w),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: InterText(
                    text: label,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Champ « Pays » : même habillage que [ProfileInput], ouvre la liste des pays.
class _CountryField extends StatelessWidget {
  final String label;
  final String iso;
  final Color accent;
  final ValueChanged<String> onChanged;
  const _CountryField({
    required this.label,
    required this.iso,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InterText(
          text: label,
          fontSize: 12.5.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary(context),
        ),
        SizedBox(height: 6.h),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppColors.divider(context)),
          ),
          child: CountryCodePicker(
            key: ValueKey<String>('billing-country-$iso'),
            onChanged: (cc) {
              final code = (cc.code ?? '').trim();
              if (code.isNotEmpty) onChanged(code);
            },
            initialSelection: iso.isNotEmpty ? iso : null,
            favorite: const ['FR', 'ES', 'US', 'BE', 'CH'],
            showCountryOnly: true,
            showOnlyCountryWhenClosed: true,
            alignLeft: true,
            showFlagDialog: true,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            textStyle: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary(context),
            ),
          ),
        ),
      ],
    );
  }
}
