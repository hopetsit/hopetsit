import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/add_card_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_text_field.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

class AddCardScreen extends StatelessWidget {
  final String userType;

  const AddCardScreen({super.key, this.userType = 'pet_owner'});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AddCardController(userType: userType));

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: AppColors.lightGrey,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        leading: BackButton(),
        title: PoppinsText(
          text: 'add_card_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.blackColor,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card holder name Field
                    CustomTextField(
                      labelText: 'add_card_holder_label'.tr,
                      controller: controller.cardHolderController,
                      hintText: 'add_card_holder_hint'.tr,
                      maxLines: 1,
                    ),
                    SizedBox(height: 24.h),

                    // Card Number Field
                    CustomTextField(
                      labelText: 'add_card_number_label'.tr,
                      controller: controller.cardNumberController,
                      hintText: 'add_card_number_hint'.tr,
                      maxLines: 1,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(16),
                        CardNumberInputFormatter(),
                      ],
                    ),
                    SizedBox(height: 24.h),

                    // Exp Date and CVC Row
                    Row(
                      children: [
                        // Exp Date Field
                        Expanded(
                          child: CustomTextField(
                            labelText: 'add_card_exp_label'.tr,
                            controller: controller.expDateController,
                            hintText: 'add_card_exp_hint'.tr,
                            maxLines: 1,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              ExpDateInputFormatter(),
                            ],
                          ),
                        ),
                        SizedBox(width: 16.w),

                        // CVC Field
                        Expanded(
                          child: CustomTextField(
                            labelText: 'add_card_cvc_label'.tr,
                            controller: controller.cvcController,
                            hintText: 'add_card_cvc_hint'.tr,
                            maxLines: 1,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 40.h),
                  ],
                ),
              ),
            ),

            // Save Button at bottom
            Padding(
              padding: EdgeInsets.all(20.w),
              child: Obx(
                () => CustomButton(
                  child: controller.isLoading.value
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
                  title: controller.isLoading.value ? null : 'common_save'.tr,
                  onTap: !controller.isLoading.value
                      ? () => controller.saveCard()
                      : null,
                  bgColor: controller.isLoading.value
                      ? AppColors.primaryColor.withOpacity(0.7)
                      : AppColors.primaryColor,
                  textColor: AppColors.whiteColor,
                  height: 48.h,
                  radius: 48.r,
                ),
              ),
            ),
          ],
        ),
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
