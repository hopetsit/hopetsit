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
    // v569 — DESIGN UNIQUEMENT : même destination au tap (écran « Publier ma
    // demande »), mêmes clés i18n. Nouveau rendu : zone de publication en
    // carte arrondie 22, avatar 34 px avec anneau, bouton d'envoi rond net,
    // couleurs suivant le mode sombre (avant : fond blanc en dur).
    final avatarUrl = _avatarUrl();
    final Color accent = AppColors.activeRoleAccent();
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
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary(context),
          ),
          SizedBox(height: 10.h),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(22.r),
              onTap: () =>
                  Get.to(() => const PublishReservationRequestScreen()),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(22.r),
                  border: Border.all(
                    color: AppColors.divider(context),
                    width: 1,
                  ),
                  boxShadow: AppColors.cardShadow(context),
                ),
                child: Row(
                  children: [
                    // v527 — avatar de l'utilisateur dans le rond à gauche.
                    Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent.withValues(alpha: 0.35),
                          width: 1.4,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 17.r,
                        backgroundColor: accent.withValues(alpha: 0.12),
                        backgroundImage: avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl.isEmpty
                            ? Icon(Icons.pets, size: 16.sp, color: accent)
                            : null,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: InterText(
                        text: 'post_input_hint'.tr,
                        fontSize: 14.sp,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      width: 34.w,
                      height: 34.w,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.32),
                            blurRadius: 10,
                            spreadRadius: -3,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(Icons.arrow_forward_rounded,
                          size: 18.sp, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
