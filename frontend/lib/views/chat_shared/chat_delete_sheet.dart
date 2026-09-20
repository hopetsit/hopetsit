// v569 — Daniel : « quand on veut supprimer une conversation : plus moderne,
// et que tout soit bien synchronisé Android / iOS / web ».
//
// Feuille du bas de confirmation, commune aux 3 rôles (owner / sitter /
// walker) : avatar + nom du correspondant, titre, phrase HONNÊTE sur ce que
// fait vraiment le serveur (masquage pour MOI sur tous MES appareils, l'autre
// garde sa copie, retour avec l'historique si elle réécrit), bouton rouge
// pleine largeur, bouton « Annuler ».
//
// ⚠️ `showModalBottomSheet(useSafeArea: true)` enveloppe la feuille dans un
// `SafeArea(bottom: false)` : le BAS n'est jamais protégé. Le dégagement bas
// vient donc de `appBottomInset(context)` (cf. utils/bottom_inset.dart).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/views/chat_shared/chat_avatar.dart';
import 'package:hopetsit/views/chat_shared/chat_theme.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Ouvre la feuille et renvoie `true` si l'utilisateur confirme.
///
/// [contactName] peut être vide : on bascule alors sur la formulation
/// générique (« l'autre personne »), jamais sur un nom inventé.
Future<bool> showChatDeleteSheet(
  BuildContext context, {
  required String contactName,
  required String contactImage,
  ChatRoleTheme? theme,
  bool isOnline = false,
}) async {
  final t = theme ?? ChatRoleTheme.current();
  final name = contactName.trim();
  final body = name.isEmpty
      ? 'chatdel569_sheet_body_generic'.tr
      : 'chatdel569_sheet_body'.tr.replaceAll('{name}', name);

  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.card(context),
    useSafeArea: true,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          24.w,
          14.h,
          24.w,
          18.h + appBottomInset(ctx),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  // `divider()` renvoie exactement grey300Color en clair.
                  color: AppColors.divider(ctx),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 18.h),
            // Avatar du correspondant, avec une pastille rouge « corbeille »
            // pour dire d'un coup d'œil de quelle action il s'agit.
            Center(
              child: SizedBox(
                width: 78.w,
                height: 78.w,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Center(
                        child: ChatAvatar(
                          imageUrl: contactImage,
                          size: 70,
                          online: isOnline ? true : null,
                          borderColor: t.softTintStrong(ctx),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 28.w,
                        height: 28.w,
                        decoration: BoxDecoration(
                          color: AppColors.errorColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.card(ctx),
                            width: 2.5,
                          ),
                        ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 15.sp,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (name.isNotEmpty) ...[
              SizedBox(height: 12.h),
              PoppinsText(
                text: name,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary(ctx),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            SizedBox(height: 8.h),
            PoppinsText(
              text: 'chatdel569_sheet_title'.tr,
              fontSize: 19.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary(ctx),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 10.h),
            InterText(
              text: body,
              fontSize: 13.5.sp,
              color: AppColors.textSecondary(ctx),
              textAlign: TextAlign.center,
              height: 1.45,
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 20.h),
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.of(ctx).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.r),
                ),
              ),
              icon: Icon(Icons.delete_outline_rounded, size: 18.sp),
              label: Text(
                'chatdel569_confirm'.tr,
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(height: 6.h),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'common_cancel'.tr,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: AppColors.textSecondary(ctx),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
  return confirmed == true;
}
