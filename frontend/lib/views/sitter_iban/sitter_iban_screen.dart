/// Sitter IBAN screen — like Vinted payout setup
/// Sitter enters their bank IBAN → admin verifies → platform pays via bank transfer
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_config.dart';
import 'package:hopetsit/utils/app_colors.dart';
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
      setState(() => _loading = false);
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
        message: 'IBAN saved! Pending admin verification before first payout.',
      );
      await _loadCurrentIban();
    } catch (e) {
      CustomSnackbar.showError(title: 'common_error'.tr, message: e.toString());
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
      CustomSnackbar.showSuccess(title: 'common_success'.tr, message: 'Payout method updated.');
    } catch (e) {
      CustomSnackbar.showError(title: 'common_error'.tr, message: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        title: InterText(text: 'payout_iban_title'.tr, fontSize: 18.sp, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─ Info banner ─
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 24.sp),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: InterText(
                            text: 'payout_iban_info'.tr,
                            fontSize: 12.sp,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // ─ Current IBAN status ─
                  if (_currentIban != null && (_currentIban!['ibanNumberMasked'] as String? ?? '').isNotEmpty) ...[
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: AppColors.grey300Color),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InterText(text: 'payout_current_iban'.tr, fontSize: 14.sp, fontWeight: FontWeight.w600),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: (_currentIban!['ibanVerified'] == true ? Colors.green : Colors.orange).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20.r),
                                ),
                                child: InterText(
                                  text: _currentIban!['ibanVerified'] == true ? '✓ Verified' : '⏳ Pending',
                                  fontSize: 11.sp,
                                  color: _currentIban!['ibanVerified'] == true ? Colors.green : Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10.h),
                          _infoRow(Icons.person_outline, 'Holder', _currentIban!['ibanHolder'] ?? ''),
                          _infoRow(Icons.account_balance, 'IBAN', _currentIban!['ibanNumberMasked'] ?? ''),
                          if ((_currentIban!['ibanBic'] as String? ?? '').isNotEmpty)
                            _infoRow(Icons.code, 'BIC/SWIFT', _currentIban!['ibanBic']),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),
                  ],

                  // ─ Payout method selector ─
                  InterText(text: 'payout_method_label'.tr, fontSize: 15.sp, fontWeight: FontWeight.w600),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      _methodChip('stripe', 'Stripe Card', Icons.credit_card),
                      SizedBox(width: 8.w),
                      _methodChip('paypal', 'PayPal', Icons.paypal),
                      SizedBox(width: 8.w),
                      _methodChip('iban', 'Bank (IBAN)', Icons.account_balance),
                    ],
                  ),
                  SizedBox(height: 24.h),

                  // ─ IBAN Form ─
                  InterText(text: 'payout_add_iban'.tr, fontSize: 15.sp, fontWeight: FontWeight.w600),
                  SizedBox(height: 12.h),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _textField(
                          controller: _holderCtrl,
                          label: 'payout_iban_holder'.tr,
                          icon: Icons.person_outline,
                          validator: (v) => v == null || v.isEmpty ? 'payout_iban_holder_required'.tr : null,
                        ),
                        SizedBox(height: 14.h),
                        _textField(
                          controller: _ibanCtrl,
                          label: 'IBAN',
                          icon: Icons.account_balance,
                          hint: 'e.g. FR76 3000 6000 0112 3456 7890 189',
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 ]')),
                            _IbanFormatter(),
                          ],
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'payout_iban_required'.tr;
                            final clean = v.replaceAll(' ', '');
                            if (clean.length < 15 || clean.length > 34) return 'payout_iban_invalid'.tr;
                            return null;
                          },
                        ),
                        SizedBox(height: 14.h),
                        _textField(
                          controller: _bicCtrl,
                          label: 'BIC / SWIFT (optional)',
                          icon: Icons.code,
                        ),
                        SizedBox(height: 24.h),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                            ),
                            icon: _saving
                                ? SizedBox(width: 18.w, height: 18.h, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Icon(Icons.save, color: Colors.white),
                            label: InterText(text: 'payout_save_iban'.tr, fontSize: 15.sp, fontWeight: FontWeight.w600, color: Colors.white),
                            onPressed: _saving ? null : _saveIban,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: EdgeInsets.only(bottom: 6.h),
    child: Row(
      children: [
        Icon(icon, size: 16.sp, color: AppColors.greyText),
        SizedBox(width: 8.w),
        InterText(text: '$label: ', fontSize: 12.sp, color: AppColors.greyText),
        InterText(text: value, fontSize: 12.sp, fontWeight: FontWeight.w600),
      ],
    ),
  );

  Widget _methodChip(String method, String label, IconData icon) {
    final selected = _payoutMethod == method;
    return GestureDetector(
      onTap: () => _setPayoutMethod(method),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: selected ? AppColors.primaryColor : AppColors.grey300Color),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18.sp, color: selected ? Colors.white : AppColors.greyText),
            SizedBox(height: 4.h),
            InterText(text: label, fontSize: 10.sp, color: selected ? Colors.white : AppColors.greyText, fontWeight: FontWeight.w500),
          ],
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) => TextFormField(
    controller: controller,
    inputFormatters: inputFormatters,
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.primaryColor),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
    ),
  );
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
