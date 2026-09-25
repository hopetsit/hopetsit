// v584 — « Comprendre la PawMap » : l'écran ouvert par le bouton « ? » de la
// carte, RÉUTILISABLE (demande de Daniel du 25/09) : le lot D le branchera
// dans Profil › Aide des 3 rôles.
//
//   Ouvrir :  Get.to(() => const PawMapHelpScreen());
//   ou      :  Get.toNamed(PawMapHelpScreen.routeName)  (route nommée déclarée
//             dans `PawMapHelpScreen.page`, à ajouter aux `getPages` si besoin).
//
// Contenu, dans cet ordre : le mémo de la légende, chaque épingle de
// `LEGENDE_PAWMAP.md` dessinée en vrai (mêmes peintres que la carte), chaque
// bouton du rail avec son icône et à quoi il sert, les raccourcis du dock, et
// en bas « Voir sur la carte » qui ouvre l'onglet PawMap.
//
// UNE seule source pour les textes des boutons : `kPawRailSpecs` /
// `kPawDockSpecs` (`pawmap_rail.dart`) — les mêmes que le menu de
// personnalisation du rail et l'appui long sur la carte.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../utils/app_colors.dart';
import '../../utils/map_ui_state.dart';
import '../../utils/pawmap_theme.dart';
import '../profile/widgets/profile_ui_kit.dart';
import 'paw_map_screen.dart';
import 'widgets/paw_rail_button.dart';
import 'widgets/pawmap_buttons.dart';
import 'widgets/pawmap_discreet.dart';
import 'widgets/pawmap_pins.dart';
import 'widgets/pawmap_rail.dart';
import 'widgets/pawmap_sheets.dart';

class PawMapHelpScreen extends StatelessWidget {
  const PawMapHelpScreen({super.key, this.fromMap = false});

  /// Route nommée (facultative) : `Get.toNamed(PawMapHelpScreen.routeName)`.
  static const String routeName = '/pawmap/help';

  /// Page GetX prête à être ajoutée à la liste des routes de l'app.
  static GetPage<dynamic> get page =>
      GetPage<dynamic>(name: routeName, page: () => const PawMapHelpScreen());

  /// `true` quand l'écran est ouvert DEPUIS la carte : « Voir sur la carte »
  /// revient simplement en arrière (la carte est juste derrière).
  final bool fromMap;

  void _seeMap(BuildContext context) {
    if (fromMap && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    openMainTabOr(kPawMapTabIndex, () => const PawMapScreen());
  }

  void _explain(BuildContext context, PawRailSpec spec) {
    showPawMapSheet<void>(
      context,
      PawRailHelpSheet(
        title: spec.label,
        help: spec.help,
        color: spec.color,
        icon: spec.icon,
        onDo: () {
          Navigator.of(context).pop();
          _seeMap(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = pawLegendEntries();
    return ProfileSubPageScaffold(
      title: 'pawmap_help_title'.tr,
      accent: PawMapTheme.accent,
      body: Column(
        key: const ValueKey<String>('pawmap_help_body'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'pawmap_help_intro'.tr,
            style: PawMapTheme.fontOn(context,
                size: 14.sp, weight: FontWeight.w600, color: AppColors.textSecondaryStrong(context)),
          ),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
            decoration: BoxDecoration(
              color: PawMapLegend.ink,
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Text(
              'pawmap_legend_memo'.tr,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: PawMapLegend.gold,
                height: 1.35,
              ),
            ),
          ),
          SizedBox(height: 18.h),
          _SectionTitle('pawmap_help_pins'.tr),
          SizedBox(height: 6.h),
          for (final e in entries)
            PawLegendRow(
              key: ValueKey<String>('legend_${e.key}'),
              label: e.label,
              child: PawPinPreview(entry: e),
            ),
          // Signalement : inchangé (emoji du type), décrit sans image.
          PawLegendRow(
            key: const ValueKey<String>('legend_report'),
            label: 'pawmap_legend_report'.tr,
            child: Icon(Icons.warning_amber_rounded,
                size: 26.sp, color: PawMapTheme.danger),
          ),
          SizedBox(height: 18.h),
          _SectionTitle('pawmap_help_buttons'.tr),
          SizedBox(height: 2.h),
          Text(
            'pawmap_help_buttons_sub'.tr,
            style: PawMapTheme.fontOn(context,
                size: 12.5.sp, weight: FontWeight.w500, color: AppColors.textSecondaryStrong(context)),
          ),
          SizedBox(height: 8.h),
          for (final spec in kPawRailSpecs)
            _ButtonRow(
              key: ValueKey<String>('help_rail_${spec.id}'),
              icon: PawRailButton(
                color: spec.color,
                label: spec.label,
                svg: spec.svg,
                gradientTop: spec.g1,
                gradientBottom: spec.g2,
                onTap: () => _explain(context, spec),
              ),
              title: spec.label,
              help: spec.help,
            ),
          SizedBox(height: 18.h),
          _SectionTitle('pawmap_help_dock'.tr),
          SizedBox(height: 8.h),
          for (final d in kPawDockSpecs)
            _ButtonRow(
              key: ValueKey<String>('help_dock_${d.id}'),
              icon: Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: d.color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: d.color.withValues(alpha: 0.45)),
                ),
                child: Icon(d.icon, size: 22.sp, color: PawMapTheme.toneOn(context, d.color)),
              ),
              title: d.label,
              help: d.help,
            ),
          SizedBox(height: 18.h),
          // v586 — la carte dégagée : poignée « Options », Publier / Direct,
          // œil (qui me voit), effacement au geste. Même source que l'appui
          // long sur la carte (`kPawCapsuleSpecs`).
          _SectionTitle('pawmap586_help_capsule'.tr),
          SizedBox(height: 8.h),
          for (final c in kPawCapsuleSpecs)
            _ButtonRow(
              key: ValueKey<String>('help_capsule_${c.id}'),
              icon: Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  gradient: c.id == 'publish' || c.id == 'direct'
                      ? LinearGradient(colors: [
                          Color.lerp(c.color, Colors.white, 0.12)!,
                          c.color,
                        ])
                      : null,
                  color: c.id == 'publish' || c.id == 'direct'
                      ? null
                      : c.color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: c.id == 'publish' || c.id == 'direct'
                          ? Colors.white
                          : c.color.withValues(alpha: 0.45),
                      width: c.id == 'publish' || c.id == 'direct' ? 2 : 1),
                ),
                child: Icon(c.icon,
                    size: 22.sp,
                    color: c.id == 'publish' || c.id == 'direct'
                        ? Colors.white
                        : PawMapTheme.toneOn(context, c.color)),
              ),
              title: c.label,
              help: c.help,
            ),
          SizedBox(height: 18.h),
          // v584 (25/09, point 14) — « Suivre ma promenade : Daniel ne sait
          // pas comment faire » : l'explication vit aussi ici.
          _SectionTitle('pawmap_help_live_title'.tr),
          SizedBox(height: 6.h),
          Container(
            key: const ValueKey<String>('help_live_share'),
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: PawMapLegend.pawFollow.withValues(alpha: PawMapTheme.isDark(context) ? 0.18 : 0.08),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: PawMapLegend.pawFollow.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: const BoxDecoration(
                    color: PawMapLegend.pawFollow,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.share_location_rounded, color: Colors.white, size: 22.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'pawmap_help_live_body'.tr,
                    style: PawMapTheme.fontOn(context,
                        size: 12.5.sp, weight: FontWeight.w500, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),
        ],
      ),
      bottom: PawSignatureButton(
        key: const ValueKey<String>('pawmap_help_see_map'),
        label: 'pawmap_help_see_map'.tr,
        icon: Icons.map_rounded,
        color: PawMapTheme.accent,
        onTap: () => _seeMap(context),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: PawMapTheme.fontOn(context, size: 16.sp, weight: FontWeight.w800),
    );
  }
}

class _ButtonRow extends StatelessWidget {
  const _ButtonRow({
    super.key,
    required this.icon,
    required this.title,
    required this.help,
  });

  final Widget icon;
  final String title;
  final String help;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 56.w, child: Center(child: icon)),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: PawMapTheme.fontOn(context,
                        size: 14.sp, weight: FontWeight.w800)),
                SizedBox(height: 2.h),
                Text(
                  help,
                  style: PawMapTheme.fontOn(context,
                      size: 12.5.sp,
                      weight: FontWeight.w500,
                      color: AppColors.textSecondaryStrong(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
