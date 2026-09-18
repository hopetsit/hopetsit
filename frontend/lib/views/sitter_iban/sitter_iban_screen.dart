/// Sitter IBAN screen — like Vinted payout setup
/// Sitter enters their bank IBAN → admin verifies → platform pays via bank transfer
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_config.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/profile/widgets/edit_profile_widgets.dart';
import 'package:hopetsit/views/profile/widgets/pet_form_widgets.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

class SitterIbanScreen extends StatefulWidget {
  const SitterIbanScreen({super.key});
  @override
  State<SitterIbanScreen> createState() => _SitterIbanScreenState();
}

class _SitterIbanScreenState extends State<SitterIbanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _holderCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();
  final _bicCtrl = TextEditingController();

  bool _loading = false;
  bool _saving = false;
  Map<String, dynamic>? _currentIban;
  String _payoutMethod = 'stripe';

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
    setState(() => _loading = true);
    try {
      final data = await ApiClient().get('${ApiConfig.baseUrl}/sitter/iban');
      setState(() {
        _currentIban = data as Map<String, dynamic>;
        _payoutMethod = _currentIban?['payoutMethod'] ?? 'stripe';
        _holderCtrl.text = _currentIban?['ibanHolder'] ?? '';
        _bicCtrl.text = _currentIban?['ibanBic'] ?? '';
      });
    } catch (_) {
      // No IBAN set yet
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveIban() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final result = await ApiClient().put(
        '${ApiConfig.baseUrl}/sitter/iban',
        body: {
          'ibanHolder': _holderCtrl.text.trim(),
          'ibanNumber': _ibanCtrl.text.trim().replaceAll(' ', ''),
          'ibanBic': _bicCtrl.text.trim(),
        },
      );
      setState(() => _currentIban = result as Map<String, dynamic>);
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'payout_iban_saved_success'.tr,
      );
      await _loadCurrentIban();
    } catch (e) {
      // v18.9.2 — message générique traduit au lieu de e.toString().
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'common_error_message'.tr,
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _setPayoutMethod(String method) async {
    try {
      await ApiClient().patch(
        '${ApiConfig.baseUrl}/sitter/payout-method',
        body: {'payoutMethod': method},
      );
      setState(() => _payoutMethod = method);
      CustomSnackbar.showSuccess(title: 'common_success'.tr, message: 'payout_method_updated'.tr);
    } catch (e) {
      // v18.9.2 — message générique traduit au lieu de e.toString().
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'common_error_message'.tr,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = currentRoleAccent();
    final current = _currentIban;
    final hasIban = current != null &&
        (current['ibanNumberMasked'] as String? ?? '').isNotEmpty;
    final verified = current?['ibanVerified'] == true;
    // v565 — point 39 : kit Profil (bandeau, carte d'état, méthode de
    // versement en pilules, formulaire ProfileInput, bouton collant).
    return ProfileSubPageScaffold(
      title: 'payout_iban_title'.tr,
      accent: accent,
      scroll: false,
      padding: EdgeInsets.zero,
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProfileInfoBanner(
                          icon: Icons.info_outline_rounded,
                          text: 'payout_iban_info'.tr,
                          accent: accent,
                        ),

                        // ─ Current IBAN status ─
                        if (hasIban)
                          ProfileFormCard(
                            title: 'payout_current_iban'.tr,
                            icon: Icons.account_balance_rounded,
                            accent: accent,
                            gap: 8,
                            children: [
                              ProfileStatusPill(
                                icon: verified
                                    ? Icons.check_circle_rounded
                                    : Icons.schedule_rounded,
                                text: verified
                                    ? 'payout_iban_verified'.tr
                                    : 'payout_iban_pending'.tr,
                                color: verified
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFE8920A),
                              ),
                              _infoRow(context, Icons.person_outline_rounded,
                                  'payout_label_holder'.tr, '${current['ibanHolder'] ?? ''}'),
                              _infoRow(context, Icons.account_balance_outlined, 'IBAN',
                                  '${current['ibanNumberMasked'] ?? ''}'),
                              if ((current['ibanBic'] as String? ?? '').isNotEmpty)
                                _infoRow(context, Icons.qr_code_2_rounded,
                                    'payout_label_bic'.tr, '${current['ibanBic']}'),
                            ],
                          ),

                        // ─ Payout method selector ─
                        ProfileFormCard(
                          title: 'payout_method_label'.tr,
                          icon: Icons.payments_rounded,
                          accent: accent,
                          children: [
                            Wrap(
                              spacing: 8.w,
                              runSpacing: 10.h,
                              children: [
                                _methodChip(accent, 'stripe', 'payout_chip_card'.tr,
                                    Icons.credit_card_rounded),
                                _methodChip(accent, 'paypal', 'PayPal', Icons.paypal),
                                _methodChip(accent, 'iban', 'payout_chip_iban'.tr,
                                    Icons.account_balance_rounded),
                              ],
                            ),
                          ],
                        ),

                        // ─ IBAN Form ─
                        Form(
                          key: _formKey,
                          child: ProfileFormCard(
                            title: 'payout_add_iban'.tr,
                            icon: Icons.edit_outlined,
                            accent: accent,
                            children: [
                              ProfileInput(
                                label: 'payout_iban_holder'.tr,
                                controller: _holderCtrl,
                                accent: accent,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                prefix: Icon(Icons.person_outline_rounded,
                                    size: 20.sp, color: accent),
                                validator: (v) => v == null || v.isEmpty
                                    ? 'payout_iban_holder_required'.tr
                                    : null,
                              ),
                              ProfileInput(
                                label: 'IBAN',
                                hint: 'payout_iban_hint'.tr,
                                controller: _ibanCtrl,
                                accent: accent,
                                textCapitalization: TextCapitalization.characters,
                                textInputAction: TextInputAction.next,
                                prefix: Icon(Icons.account_balance_outlined,
                                    size: 20.sp, color: accent),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 ]')),
                                  _IbanFormatter(),
                                ],
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'payout_iban_required'.tr;
                                  final clean = v.replaceAll(' ', '');
                                  if (clean.length < 15 || clean.length > 34) {
                                    return 'payout_iban_invalid'.tr;
                                  }
                                  return null;
                                },
                              ),
                              ProfileInput(
                                label: 'payout_bic_label'.tr,
                                controller: _bicCtrl,
                                accent: accent,
                                textCapitalization: TextCapitalization.characters,
                                textInputAction: TextInputAction.done,
                                prefix: Icon(Icons.qr_code_2_rounded,
                                    size: 20.sp, color: accent),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
                  child: ProfileSaveBar(
                    label: 'payout_save_iban'.tr,
                    accent: accent,
                    loading: _saving,
                    icon: Icons.check_rounded,
                    onTap: _saving ? null : _saveIban,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String label, String value) => Row(
        children: [
          Icon(icon, size: 16.sp, color: AppColors.textSecondary(context)),
          SizedBox(width: 8.w),
          InterText(
            text: '$label: ',
            fontSize: 12.5.sp,
            color: AppColors.textSecondary(context),
            maxLines: 1,
          ),
          Expanded(
            child: InterText(
              text: value,
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );

  Widget _methodChip(Color accent, String method, String label, IconData icon) {
    final selected = _payoutMethod == method;
    return PetPill(
      label: label,
      selected: selected,
      accent: accent,
      icon: icon,
      onTap: () => _setPayoutMethod(method),
    );
  }
}

/// Auto-formats IBAN input with spaces every 4 chars
class _IbanFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
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
