// v565 — panneaux du bas quand la saisie est indisponible : « paiement
// requis » (403 PAYMENT_REQUIRED) et « verrouillé après paiement ».
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/views/chat_shared/chat_theme.dart';
import 'package:hopetsit/widgets/app_text.dart';

class ChatPaymentGate extends StatelessWidget {
  const ChatPaymentGate({super.key, required this.theme});
  final ChatRoleTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        border: Border(top: BorderSide(color: AppColors.divider(context))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_rounded, size: 20.sp, color: theme.accent),
              SizedBox(width: 8.w),
              Expanded(
                child: InterText(
                  text: 'chat_gate_title'.tr,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          InterText(
            text: 'chat_gate_body'.tr,
            fontSize: 12.5.sp,
            color: AppColors.textSecondary(context),
            height: 1.35,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24.r),
                    ),
                  ),
                  child: Text(
                    'chat_pay_now_button'.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.sp),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Get.to(() => const CoinShopScreen()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.accent,
                    side: BorderSide(color: theme.accent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24.r),
                    ),
                  ),
                  child: Text(
                    'chat_gate_shop'.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.sp),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ChatLockedNotice extends StatelessWidget {
  const ChatLockedNotice({super.key, required this.theme});
  final ChatRoleTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        border: Border(top: BorderSide(color: AppColors.divider(context))),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 18.sp, color: theme.accent),
          SizedBox(width: 8.w),
          Expanded(
            child: InterText(
              text: 'chat_locked_after_payment'.tr,
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary(context),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
