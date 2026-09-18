import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/add_card_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/profile/widgets/edit_profile_widgets.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// v565 — point 39 : « Ajouter une carte » côté Profil modernisé (kit) :
/// aperçu de carte animé (titulaire / numéro masqué / expiration), champs
/// `ProfileInput` dans une carte groupée, note « sécurisé », bouton collant
/// avec état de chargement. Même contrôleur, mêmes formateurs, même appel
/// réseau (`AddCardController.saveCard`).
class AddCardScreen extends StatelessWidget {
  final String userType;

  const AddCardScreen({super.key, this.userType = 'pet_owner'});

  /// v20.0.3 — couleur rôle (orange owner / bleu sitter / vert walker).
  Color _roleColor() {
    try {
      final role = GetStorage().read<String>(StorageKeys.userRole);
      return AppColors.roleAccent(role);
    } catch (_) {
      return AppColors.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AddCardController(userType: userType));
    final roleColor = _roleColor();

    return ProfileSubPageScaffold(
      title: 'add_card_title'.tr,
      accent: roleColor,
      body: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4.h),
            _CardPreview(controller: controller, accent: roleColor),
            ProfileFormCard(
              title: 'add_card_section_title'.tr,
              icon: Icons.credit_card_rounded,
              accent: roleColor,
              children: [
                ProfileInput(
                  label: 'add_card_holder_label'.tr,
                  hint: 'add_card_holder_hint'.tr,
                  controller: controller.cardHolderController,
                  accent: roleColor,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                  prefix: Icon(Icons.person_outline_rounded, size: 20.sp, color: roleColor),
                ),
                ProfileInput(
                  label: 'add_card_number_label'.tr,
                  hint: 'add_card_number_hint'.tr,
                  controller: controller.cardNumberController,
                  accent: roleColor,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  prefix: Icon(Icons.credit_card_rounded, size: 20.sp, color: roleColor),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(16),
                    CardNumberInputFormatter(),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ProfileInput(
                        label: 'add_card_exp_label'.tr,
                        hint: 'add_card_exp_hint'.tr,
                        controller: controller.expDateController,
                        accent: roleColor,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          ExpDateInputFormatter(),
                        ],
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ProfileInput(
                        label: 'add_card_cvc_label'.tr,
                        hint: 'add_card_cvc_hint'.tr,
                        controller: controller.cvcController,
                        accent: roleColor,
                        keyboardType: TextInputType.number,
                        obscure: true,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            ProfileInfoBanner(
              icon: Icons.lock_outline_rounded,
              text: 'add_card_secure'.tr,
              accent: roleColor,
            ),
          ],
        ),
      ),
      // v20.0.3 — bouton « Enregistrer ma carte » couleur rôle.
      bottom: Obx(
        () => ProfileSaveBar(
          label: 'save_my_card_button'.tr,
          accent: roleColor,
          loading: controller.isLoading.value,
          icon: Icons.credit_card_rounded,
          onTap: controller.isLoading.value ? null : () => controller.saveCard(),
        ),
      ),
    );
  }
}

/// Aperçu de carte bancaire (suit la saisie en direct).
class _CardPreview extends StatelessWidget {
  final AddCardController controller;
  final Color accent;
  const _CardPreview({required this.controller, required this.accent});

  String _masked(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (var i = 0; i < 16; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(i < digits.length ? digits[i] : '•');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Color.lerp(accent, Colors.black, 0.35)!;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 6.h),
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, dark],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38.w,
                height: 26.w,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(6.r),
                ),
              ),
              const Spacer(),
              Icon(Icons.contactless_rounded, color: Colors.white.withValues(alpha: 0.9), size: 22.sp),
            ],
          ),
          SizedBox(height: 18.h),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller.cardNumberController,
            builder: (_, v, __) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: PoppinsText(
                text: _masked(v.text),
                fontSize: 19.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: Colors.white,
                maxLines: 1,
              ),
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InterText(
                      text: 'add_card_holder_label'.tr.toUpperCase(),
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: Colors.white.withValues(alpha: 0.75),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller.cardHolderController,
                      builder: (_, v, __) => InterText(
                        text: v.text.trim().isEmpty
                            ? 'add_card_holder_hint'.tr
                            : v.text.trim().toUpperCase(),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  InterText(
                    text: 'add_card_expires'.tr.toUpperCase(),
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: Colors.white.withValues(alpha: 0.75),
                    maxLines: 1,
                  ),
                  SizedBox(height: 2.h),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller.expDateController,
                    builder: (_, v, __) => InterText(
                      text: v.text.isEmpty ? 'MM/YY' : v.text,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Custom input formatters
class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Extract only digits from the new value
    final newText = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    // Limit to 16 digits
    final digits = newText.length > 16 ? newText.substring(0, 16) : newText;

    // Format with spaces every 4 digits
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(digits[i]);
    }

    final formattedText = buffer.toString();

    // Calculate cursor position - always place at end for simplicity
    // This prevents range errors and works well for card number input
    final cursorPosition = formattedText.length;

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );
  }
}

class ExpDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Extract only digits from the new value
    final newText = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    // Limit to 4 digits (MMYY)
    final digits = newText.length > 4 ? newText.substring(0, 4) : newText;

    // Format with slash after 2 digits
    String formattedText;
    if (digits.isEmpty) {
      formattedText = '';
    } else if (digits.length <= 2) {
      formattedText = digits;
    } else {
      formattedText = '${digits.substring(0, 2)}/${digits.substring(2)}';
    }

    // Calculate cursor position
    // For exp date, place cursor at the end of the formatted text
    // This prevents range errors and works naturally
    int cursorPosition = formattedText.length;

    // Special handling: if we have exactly 2 digits, place cursor after them
    // (so when user types the 3rd digit, it goes after the slash)
    if (digits.length == 2) {
      cursorPosition = 2;
    }

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(
        offset: cursorPosition.clamp(0, formattedText.length),
      ),
    );
  }
}
