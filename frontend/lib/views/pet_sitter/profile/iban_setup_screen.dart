import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_endpoints.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

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
    try {
      final client = Get.find<ApiClient>();
      final response = await client.get(
        ApiEndpoints.sitterMeIban,
        requiresAuth: true,
      );
      if (response is Map<String, dynamic>) {
        setState(() {
          _holderCtrl.text = (response['ibanHolder'] ?? '') as String;
          _bicCtrl.text = (response['ibanBic'] ?? '') as String;
          _maskedIban = (response['ibanNumberMasked'] ?? '') as String;
          _ibanVerified = (response['ibanVerified'] ?? false) as bool;
          _isSaved = _maskedIban.isNotEmpty;
        });
      }
    } catch (_) {
      // No IBAN saved yet — that's fine
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
        CustomSnackbar.showSuccess(
          title: 'common_success'.tr,
          message: 'iban_saved_success'.tr,
        );
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
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.blackColor),
          onPressed: () => Get.back(),
        ),
        title: InterText(
          text: 'iban_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.blackColor,
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info banner (like Vinted)
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.primaryColor.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primaryColor, size: 20.sp),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: InterText(
                        text: 'iban_info_message'.tr,
                        fontSize: 13.sp,
                        color: AppColors.primaryColor,
                        maxLines: 5,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),

              // Status badge if already saved
              if (_isSaved) ...[
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: _ibanVerified
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: _ibanVerified ? Colors.green : Colors.orange,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _ibanVerified ? Icons.verified : Icons.hourglass_empty,
                        color: _ibanVerified ? Colors.green : Colors.orange,
                        size: 20.sp,
                      ),
                      SizedBox(width: 10.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InterText(
                            text: _maskedIban,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.blackColor,
                          ),
                          InterText(
                            text: _ibanVerified
                                ? 'iban_status_verified'.tr
                                : 'iban_status_pending'.tr,
                            fontSize: 12.sp,
                            color: _ibanVerified ? Colors.green : Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),
              ],

              // Account holder
              _buildLabel('iban_holder_label'.tr),
              SizedBox(height: 6.h),
              TextFormField(
                controller: _holderCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDecoration('iban_holder_hint'.tr, Icons.person_outline),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'iban_holder_required'.tr : null,
              ),
              SizedBox(height: 16.h),

              // IBAN number
              _buildLabel('iban_number_label'.tr),
              SizedBox(height: 6.h),
              TextFormField(
                controller: _ibanCtrl,
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 ]')),
                  // Auto-format with spaces every 4 chars
                  _IbanInputFormatter(),
                ],
                decoration: _inputDecoration(
                  _isSaved ? _maskedIban : 'iban_number_hint'.tr,
                  Icons.account_balance_outlined,
                ),
                validator: _validateIban,
              ),
              SizedBox(height: 6.h),
              InterText(
                text: 'iban_number_example'.tr,
                fontSize: 11.sp,
                color: AppColors.greyText,
              ),
              SizedBox(height: 16.h),

              // BIC/SWIFT
              _buildLabel('iban_bic_label'.tr),
              SizedBox(height: 6.h),
              TextFormField(
                controller: _bicCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: _inputDecoration('iban_bic_hint'.tr, Icons.code),
                validator: (v) => (v == null || v.trim().length < 8) ? 'iban_bic_required'.tr : null,
              ),
              SizedBox(height: 32.h),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading
                      ? SizedBox(
                          height: 20.h,
                          width: 20.h,
                          child: CircularProgressIndicator(
                            color: AppColors.whiteColor,
                            strokeWidth: 2,
                          ),
                        )
                      : InterText(
                          text: 'iban_save_button'.tr,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.whiteColor,
                        ),
                ),
              ),

              SizedBox(height: 20.h),
              // Security note
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 14.sp, color: AppColors.greyText),
                    SizedBox(width: 4.w),
                    InterText(
                      text: 'iban_security_note'.tr,
                      fontSize: 11.sp,
                      color: AppColors.greyText,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return InterText(
      text: text,
      fontSize: 14.sp,
      fontWeight: FontWeight.w600,
      color: AppColors.blackColor,
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.greyText, fontSize: 14.sp),
      prefixIcon: Icon(icon, color: AppColors.greyText, size: 20.sp),
      filled: true,
      fillColor: AppColors.whiteColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: AppColors.grey300Color),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: AppColors.grey300Color),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: AppColors.primaryColor, width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
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
