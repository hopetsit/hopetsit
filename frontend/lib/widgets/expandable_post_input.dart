import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/views/pet_owner/reservation_request/publish_reservation_request_screen.dart';

class ExpandablePostInput extends StatefulWidget {
  const ExpandablePostInput({super.key});

  @override
  State<ExpandablePostInput> createState() => _ExpandablePostInputState();
}

class _ExpandablePostInputState extends State<ExpandablePostInput> {
  // v527 — retour Jose : « la photo de profil dans le petit cercle à gauche,
  // ce serait plus personnalisé ». Avatar lu depuis le profil local
  // (GetStorage) ; l'API renvoie avatar en Map {url} OU en String selon les
  // écrans → on gère les deux. Fallback : icône patte.
  String _avatarUrl() {
    try {
      final p = GetStorage().read<Map<String, dynamic>>(StorageKeys.userProfile);
      for (final key in ['avatar', 'profilePicture']) {
        final a = p?[key];
        if (a is Map && (a['url'] ?? '').toString().isNotEmpty) {
          return a['url'].toString();
        }
        if (a is String && a.isNotEmpty) return a;
      }
    } catch (_) {/* profil pas encore chargé */}
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _avatarUrl();
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          InterText(
            text: 'post_input_label'.tr,
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.greyColor,
          ),
          SizedBox(height: 12.h),

          // Read-only textfield-style area that opens the reservation screen
          TextField(
            readOnly: true,
            onTap: () => Get.to(() => const PublishReservationRequestScreen()),
            decoration: InputDecoration(
              hintText: 'post_input_hint'.tr,
              hintStyle: TextStyle(fontSize: 14.sp, color: AppColors.greyColor),
              filled: true,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20.r),
                borderSide: BorderSide(color: AppColors.grey300Color),
              ),
              fillColor: AppColors.whiteColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20.r),
                borderSide: BorderSide(color: AppColors.grey300Color),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20.r),
                borderSide: BorderSide(color: AppColors.primaryColor),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 12.h,
              ),
              // v527 — avatar de l'utilisateur dans le rond à gauche.
              prefixIcon: Padding(
                padding: EdgeInsets.only(left: 8.w, right: 6.w, top: 6.h, bottom: 6.h),
                child: CircleAvatar(
                  radius: 16.r,
                  backgroundColor:
                      AppColors.primaryColor.withValues(alpha: 0.12),
                  backgroundImage:
                      avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl.isEmpty
                      ? Icon(Icons.pets,
                          size: 15.sp, color: AppColors.primaryColor)
                      : null,
                ),
              ),
              suffixIcon: Icon(
                Icons.arrow_forward_ios,
                size: 16.sp,
                color: AppColors.greyText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
