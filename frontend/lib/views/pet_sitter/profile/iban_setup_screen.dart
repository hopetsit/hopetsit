import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_endpoints.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/profile/widgets/edit_profile_widgets.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/utils/bottom_inset.dart';

/// IbanSetupScreen — lets a pet sitter enter their IBAN for bank-transfer
/// payouts (like Vinted). The IBAN is stored encrypted server-side and must
/// be verified by an admin before payouts are processed.
class IbanSetupScreen extends StatefulWidget {
  const IbanSetupScreen({super.key});

  @override
  State<IbanSetupScreen> createState() => _IbanSetupScreenState();
}

class _IbanSetupScreenState extends State<IbanSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _holderCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();
  final _bicCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isSaved = false;
  String _maskedIban = '';
  bool _ibanVerified = false;
  // v565 — point 39 : chargement initial + erreur (état « Réessayer »).
  bool _loading = true;
  String _loadError = '';
  static const Color _green = Color(0xFF16A34A);
  static const Color _amber = Color(0xFFE8920A);

  /// v21 — Role-aware accent color. Reads the user role from GetStorage so
  /// the IBAN screen feels native to walker (green) AND sitter (blue) AND
  /// owner (orange — even though IBAN isn't normally for owners, we keep
  /// it defensive). Falls back to primaryColor (orange) if role is unknown.
  ///
  /// v23.1 part 44 — fix infinite recursion : the previous `return _accent`
  /// on the unknown-role branch caused a stack overflow as soon as the
  /// IBAN screen rendered for any role other than walker/sitter (and we
  /// have plans to expose IBAN to walkers using a non-tagged owner JWT
  /// during multi-role tests).
  Color get _accent {
    final role =
        (GetStorage().read(StorageKeys.userRole) ?? '').toString().toLowerCase();
    if (role == 'walker') return AppColors.walkerAccent;
    if (role == 'sitter') return AppColors.sitterAccent;
    return AppColors.primaryColor;
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentIban();
  }

  @override
  void dispose() {
    _holderCtrl.dispose();
    _ibanCtrl.dispose();
    _bicCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentIban() async {
    setState(() {
      _loading = true;
      _loadError = '';
    });
    try {
      final client = Get.find<ApiClient>();
      final response = await client.get(
        ApiEndpoints.sitterMeIban,
        requiresAuth: true,
      );
      if (response is Map<String, dynamic>) {
        _holderCtrl.text = (response['ibanHolder'] ?? '').toString();
        _bicCtrl.text = (response['ibanBic'] ?? '').toString();
        _maskedIban = (response['ibanNumberMasked'] ?? '').toString();
        _ibanVerified = response['ibanVerified'] == true;
        _isSaved = _maskedIban.isNotEmpty;
      }
    } on ApiException catch (e) {
      // 404 = pas encore d'IBAN : formulaire vide, pas une erreur.
      if (e.statusCode != 404) {
        _loadError = e.message.isNotEmpty ? e.message : 'iban_load_error'.tr;
      }
    } catch (_) {
      _loadError = 'iban_load_error'.tr;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final client = Get.find<ApiClient>();
      final response = await client.put(
        ApiEndpoints.sitterMeIban,
        body: {
          'ibanHolder': _holderCtrl.text.trim(),
          'ibanNumber': _ibanCtrl.text.replaceAll(' ', '').toUpperCase(),
          'ibanBic': _bicCtrl.text.trim().toUpperCase(),
        },
        requiresAuth: true,
      );
      if (response is Map<String, dynamic>) {
        setState(() {
          _maskedIban = (response['ibanNumberMasked'] ?? '') as String;
          _ibanVerified = false;
          _isSaved = true;
          _ibanCtrl.clear();
        });
        // v23.1 part 44 — fix Daniel "wallet pas connecté, walker/sitter
        // ne reçoivent pas les paiements". The backend's PUT /iban endpoint
        // now returns `beneficiarySynced: true|false` and `beneficiaryError`
        // — when the Airwallex Beneficiary creation race-conditions or
        // fails, the IBAN is saved encrypted in our DB but the provider
        // has no airwallexBeneficiaryId, so payouts get HELD on the
        // platform wallet forever. The user used to see a "saved" toast
        // and never knew anything was wrong. Now we surface the failure
        // explicitly with the underlying error so they can retry.
        final beneficiarySynced = response['beneficiarySynced'] == true;
        final beneficiaryError =
            (response['beneficiaryError'] ?? '').toString();
        if (beneficiarySynced) {
          CustomSnackbar.showSuccess(
            title: 'common_success'.tr,
            message: 'iban_saved_success'.tr,
          );
        } else {
          CustomSnackbar.showWarning(
            title: 'iban_partial_save_title'.tr,
            message: beneficiaryError.isNotEmpty
                ? '${'iban_partial_save_message'.tr}\n$beneficiaryError'
                : 'iban_partial_save_message'.tr,
          );
        }
      }
    } catch (e) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'iban_save_failed'.tr,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// v23.1 part 44 — show a Material confirm dialog before issuing
  /// DELETE /iban. We never delete silently because losing the IBAN
  /// pauses payouts until a new one is registered.
  Future<void> _confirmDelete() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: PoppinsText(
          text: 'iban_delete_confirm_title'.tr,
          fontSize: 16.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
        content: InterText(
          text: 'iban_delete_confirm_message'.tr,
          fontSize: 13.sp,
          color: AppColors.textSecondary(context),
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(
              'common_cancel'.tr,
              style: const TextStyle(color: AppColors.greyColor),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
            ),
            onPressed: () => Get.back(result: true),
            child: Text(
              'iban_delete_button'.tr,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      barrierDismissible: true,
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final client = Get.find<ApiClient>();
      await client.delete(
        ApiEndpoints.sitterMeIban,
        requiresAuth: true,
      );
      setState(() {
        _holderCtrl.clear();
        _bicCtrl.clear();
        _ibanCtrl.clear();
        _maskedIban = '';
        _ibanVerified = false;
        _isSaved = false;
      });
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'iban_delete_success'.tr,
      );
    } catch (_) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'iban_delete_failed'.tr,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String? _validateIban(String? value) {
    if (value == null || value.trim().isEmpty) return 'iban_required'.tr;
    final clean = value.replaceAll(' ', '').toUpperCase();
    if (!RegExp(r'^[A-Z]{2}[0-9A-Z]{13,32}$').hasMatch(clean)) {
      return 'iban_invalid_format'.tr;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    // v565 — point 39 : kit Profil (bandeau info, carte d'état du compte,
    // carte « Coordonnées bancaires » en champs ProfileInput, boutons
    // Enregistrer / Supprimer collants), états chargement / erreur.
    return ProfileSubPageScaffold(
      title: 'iban_title'.tr,
      accent: accent,
      scroll: false,
      padding: EdgeInsets.zero,
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            )
          : _loadError.isNotEmpty
              ? ProfileEmptyState(
                  icon: Icons.account_balance_outlined,
                  title: 'iban_load_error_title'.tr,
                  message: _loadError,
                  accent: accent,
                  error: true,
                  actionLabel: 'common_retry'.tr,
                  onAction: _loadCurrentIban,
                )
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Info banner (like Vinted)
                              ProfileInfoBanner(
                                icon: Icons.info_outline_rounded,
                                text: 'iban_info_message'.tr,
                                accent: accent,
                              ),

                              // Status card if already saved
                              if (_isSaved)
                                ProfileFormCard(
                                  title: 'iban_section_status'.tr,
                                  icon: Icons.account_balance_rounded,
                                  accent: accent,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 40.w,
                                          height: 40.w,
                                          decoration: BoxDecoration(
                                            color: (_ibanVerified ? _green : _amber)
                                                .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(12.r),
                                          ),
                                          child: Icon(
                                            _ibanVerified
                                                ? Icons.verified_rounded
                                                : Icons.hourglass_top_rounded,
                                            color: _ibanVerified ? _green : _amber,
                                            size: 20.sp,
                                          ),
                                        ),
                                        SizedBox(width: 12.w),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              PoppinsText(
                                                text: _maskedIban,
                                                fontSize: 15.sp,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary(context),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              SizedBox(height: 4.h),
                                              ProfileStatusPill(
                                                icon: _ibanVerified
                                                    ? Icons.check_circle_rounded
                                                    : Icons.schedule_rounded,
                                                text: _ibanVerified
                                                    ? 'iban_status_verified'.tr
                                                    : 'iban_status_pending'.tr,
                                                color: _ibanVerified ? _green : _amber,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                              ProfileFormCard(
                                title: 'iban_section_form'.tr,
                                icon: Icons.edit_outlined,
                                accent: accent,
                                children: [
                                  // Account holder
                                  ProfileInput(
                                    label: 'iban_holder_label'.tr,
                                    hint: 'iban_holder_hint'.tr,
                                    controller: _holderCtrl,
                                    accent: accent,
                                    textCapitalization: TextCapitalization.words,
                                    textInputAction: TextInputAction.next,
                                    prefix: Icon(Icons.person_outline_rounded,
                                        size: 20.sp, color: accent),
                                    validator: (v) => (v == null || v.trim().isEmpty)
                                        ? 'iban_holder_required'.tr
                                        : null,
                                  ),
                                  // IBAN number
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ProfileInput(
                                        label: 'iban_number_label'.tr,
                                        hint: _isSaved ? _maskedIban : 'iban_number_hint'.tr,
                                        controller: _ibanCtrl,
                                        accent: accent,
                                        keyboardType: TextInputType.text,
                                        textCapitalization: TextCapitalization.characters,
                                        textInputAction: TextInputAction.next,
                                        prefix: Icon(Icons.account_balance_outlined,
                                            size: 20.sp, color: accent),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                              RegExp(r'[A-Za-z0-9 ]')),
                                          // Auto-format with spaces every 4 chars
                                          _IbanInputFormatter(),
                                        ],
                                        validator: _validateIban,
                                      ),
                                      SizedBox(height: 6.h),
                                      InterText(
                                        text: 'iban_number_example'.tr,
                                        fontSize: 11.sp,
                                        color: AppColors.textSecondary(context),
                                        maxLines: 2,
                                      ),
                                    ],
                                  ),
                                  // BIC/SWIFT
                                  ProfileInput(
                                    label: 'iban_bic_label'.tr,
                                    hint: 'iban_bic_hint'.tr,
                                    controller: _bicCtrl,
                                    accent: accent,
                                    textCapitalization: TextCapitalization.characters,
                                    textInputAction: TextInputAction.done,
                                    prefix: Icon(Icons.qr_code_2_rounded,
                                        size: 20.sp, color: accent),
                                    validator: (v) => (v == null || v.trim().length < 8)
                                        ? 'iban_bic_required'.tr
                                        : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      // v569 — barre d'action collée en bas : le SafeArea de
              // ProfileSubPageScaffold n'applique rien sur le Samsung de
              // Daniel → le bouton passait sous la barre système.
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w,
                  12.h + appBottomInsetInsideSafeArea(context)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Save button — labelled "Modifier" once an IBAN is
                          // already saved (v23.1 part 44).
                          ProfileSaveBar(
                            label: _isSaved ? 'iban_edit_button'.tr : 'iban_save_button'.tr,
                            accent: accent,
                            loading: _isLoading,
                            icon: Icons.check_rounded,
                            note: 'iban_security_note'.tr,
                            onTap: _isLoading ? null : _save,
                          ),
                          // v23.1 part 44 — IBAN delete button (confirm first).
                          if (_isSaved) ...[
                            SizedBox(height: 8.h),
                            ProfileSecondaryButton(
                              label: 'iban_delete_button'.tr,
                              accent: const Color(0xFFE53935),
                              icon: Icons.delete_outline_rounded,
                              onTap: _isLoading ? null : _confirmDelete,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

/// Auto-formats IBAN input with spaces every 4 chars
class _IbanInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '').toUpperCase();
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
