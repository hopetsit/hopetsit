// 631 (PAM-C, 31/10/2026) — contenu de l'onglet « Ouverture » de Profil ›
// Préférences (3 rôles) : « L'app s'ouvre sur » + bouton « Balade rapide ».
// Même langage visuel que les autres onglets du profil : cartes blanches à
// ombre douce, pilules de choix à la couleur du rôle, interrupteur `AppSwitch`,
// aucun gris terne (textes = `AppColors.textPrimary/textSecondary`).
// Les réglages vivent dans `OpenOnPrefs3110` (téléphone seulement, voir là-bas).
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/services/open_on_prefs_3110.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_switch.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/paw_button_kit.dart';
import 'package:hopetsit/widgets/paw_icons.dart';

class PrefsOpenOnTab3110 extends StatelessWidget {
  final Color accent;
  const PrefsOpenOnTab3110({super.key, required this.accent});

  @override
  Widget build(BuildContext context) {
    OpenOnPrefs3110.load();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(context, 'pamc3110_open_title'.tr),
        _openOnCard(context),
        SizedBox(height: 18.h),
        _title(context, 'pamc3110_qw_title'.tr),
        _quickWalkCard(context),
        SizedBox(height: 10.h),
        Padding(
          padding: EdgeInsets.only(left: 4.w),
          child: InterText(
            key: const ValueKey<String>('pamc3110_local_note'),
            text: 'pamc3110_local_note'.tr,
            fontSize: 11.sp,
            color: AppColors.textSecondary(context),
          ),
        ),
      ],
    );
  }

  Widget _title(BuildContext context, String text) => Padding(
        padding: EdgeInsets.only(left: 4.w, bottom: 10.h),
        child: PoppinsText(
          text: text,
          fontSize: 15.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      );

  BoxDecoration _card(BuildContext context) => BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: AppColors.cardShadow(context),
      );

  Widget _openOnCard(BuildContext context) {
    const options = <(OpenOnChoice3110, PawIcon, String)>[
      (OpenOnChoice3110.home, PawIcon.home, 'pamc3110_open_home'),
      (OpenOnChoice3110.pawmap, PawIcon.pin, 'pamc3110_open_pawmap'),
      (OpenOnChoice3110.chat, PawIcon.chat, 'pamc3110_open_chat'),
      (OpenOnChoice3110.bookings, PawIcon.calendar, 'pamc3110_open_bookings'),
      (OpenOnChoice3110.last, PawIcon.clock, 'pamc3110_open_last'),
    ];
    return Container(
      key: const ValueKey<String>('pamc3110_open_card'),
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
      decoration: _card(context),
      child: Obx(() {
        final current = OpenOnPrefs3110.openOn.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InterText(
              text: 'pamc3110_open_sub'.tr,
              fontSize: 11.5.sp,
              color: AppColors.textSecondary(context),
              maxLines: 4,
            ),
            SizedBox(height: 10.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                for (final o in options)
                  PawChoicePill(
                    key: ValueKey<String>('pamc3110_open_${o.$1.code}'),
                    label: o.$1 == OpenOnChoice3110.home
                        ? '${o.$3.tr} · ${'pamc3110_default'.tr}'
                        : o.$3.tr,
                    icon: o.$2,
                    color: accent,
                    selected: current == o.$1,
                    onTap: current == o.$1
                        ? null
                        : () => OpenOnPrefs3110.setOpenOn(o.$1),
                  ),
              ],
            ),
            if (current == OpenOnChoice3110.last) ...[
              SizedBox(height: 10.h),
              InterText(
                key: const ValueKey<String>('pamc3110_open_last_sub'),
                text: 'pamc3110_open_last_sub'.tr,
                fontSize: 11.sp,
                color: AppColors.textSecondary(context),
                maxLines: 3,
              ),
            ],
          ],
        );
      }),
    );
  }

  Widget _quickWalkCard(BuildContext context) {
    return Container(
      key: const ValueKey<String>('pamc3110_qw_card'),
      padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 12.h),
      decoration: _card(context),
      child: Obx(() {
        final visible = OpenOnPrefs3110.quickWalkVisible.value;
        final side = OpenOnPrefs3110.quickWalkSide.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38.w,
                  height: 38.w,
                  decoration: BoxDecoration(
                    color: AppColors.walkerAccent,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Center(
                    child: PawIconWidget(PawIcon.walker,
                        size: 20.sp, color: Colors.white),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PoppinsText(
                        text: 'pamc3110_qw_visible'.tr,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                        maxLines: 2,
                      ),
                      SizedBox(height: 2.h),
                      InterText(
                        text: 'pamc3110_qw_visible_sub'.tr,
                        fontSize: 11.sp,
                        color: AppColors.textSecondary(context),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                AppSwitch(
                  key: const ValueKey<String>('pamc3110_qw_switch'),
                  value: visible,
                  accent: accent,
                  onChanged: (v) => OpenOnPrefs3110.setQuickWalkVisible(v),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.topLeft,
              child: !visible
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      key: const ValueKey<String>('pamc3110_qw_side_block'),
                      padding: EdgeInsets.only(top: 12.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PoppinsText(
                            text: 'pamc3110_qw_side'.tr,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                          ),
                          SizedBox(height: 8.h),
                          Wrap(
                            spacing: 8.w,
                            runSpacing: 8.h,
                            children: [
                              PawChoicePill(
                                key: const ValueKey<String>('pamc3110_qw_right'),
                                label: 'pamc3110_qw_right'.tr,
                                icon: Icons.east_rounded,
                                color: accent,
                                selected: side == QuickWalkSide3110.right,
                                onTap: side == QuickWalkSide3110.right
                                    ? null
                                    : () => OpenOnPrefs3110.setQuickWalkSide(
                                        QuickWalkSide3110.right),
                              ),
                              PawChoicePill(
                                key: const ValueKey<String>('pamc3110_qw_left'),
                                label: 'pamc3110_qw_left'.tr,
                                icon: Icons.west_rounded,
                                color: accent,
                                selected: side == QuickWalkSide3110.left,
                                onTap: side == QuickWalkSide3110.left
                                    ? null
                                    : () => OpenOnPrefs3110.setQuickWalkSide(
                                        QuickWalkSide3110.left),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      }),
    );
  }
}
