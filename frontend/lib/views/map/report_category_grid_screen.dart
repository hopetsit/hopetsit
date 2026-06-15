// v23.1.186 — Daniel mockup : ecran Signaler en grille 2x3 avec 6
// grosses categories colorees (Animal perdu / Danger / Chien mechant /
// Accident / Poison / Autre). Tap → ouvre CreateReportSheet avec le type
// pre-selectionne.
//
// v23.1.192 — Daniel : "ds les petit carre ya les option gratuite en
// un clic et en desous les petit carrer avec option premium". On
// restructure en DEUX sections :
//   1. Section "Gratuit" — 4 cards FREE (1 tap, accessible a tous)
//   2. Section "Premium" — toutes les autres categories (Animal perdu,
//      Caca, Pipi, Piège repéré, etc.) dans une grille compacte.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopetsit/services/location_service.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:hopetsit/models/map_report_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/map/widgets/create_report_sheet.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

class ReportCategoryGridScreen extends StatelessWidget {
  const ReportCategoryGridScreen({super.key});

  // v23.1.192 — Categories GRATUITES (mockup top section).
  static const _freeCategories = <_CategoryDef>[
    _CategoryDef(
      type: ReportTypes.aggressiveDog,
      labelKey: 'report_cat_aggressive_dog',
      icon: Icons.report_problem_rounded,
      color: Color(0xFFE53935),
    ),
    _CategoryDef(
      type: ReportTypes.hazard,
      labelKey: 'report_cat_hazard',
      icon: Icons.warning_amber_rounded,
      color: Color(0xFFF59E0B),
    ),
    _CategoryDef(
      type: ReportTypes.waterActive,
      labelKey: 'report_cat_water_active',
      icon: Icons.water_drop_rounded,
      color: Color(0xFF0288D1),
    ),
    _CategoryDef(
      type: ReportTypes.deadAnimal,
      labelKey: 'report_cat_accident',
      icon: Icons.medical_services_rounded,
      color: Color(0xFFDC2626),
    ),
    // v23.1.293 — 2 nouveaux signalements GRATUITS (Daniel).
    _CategoryDef(
      type: ReportTypes.food,
      labelKey: 'report_cat_food',
      icon: Icons.restaurant_rounded,
      color: Color(0xFF8BC34A),
    ),
    _CategoryDef(
      type: ReportTypes.trash,
      labelKey: 'report_cat_trash',
      icon: Icons.delete_rounded,
      color: Color(0xFF607D8B),
    ),
    // v414 — véto ouvert / de garde : gratuit (utile à toute la communauté).
    _CategoryDef(
      type: ReportTypes.vetOpen,
      labelKey: 'report_cat_vet_open',
      icon: Icons.local_hospital_rounded,
      color: Color(0xFF00897B),
    ),
  ];

  // v23.1.192 — Categories PREMIUM (mockup bottom section).
  static const _premiumCategories = <_CategoryDef>[
    _CategoryDef(
      type: ReportTypes.lostPet,
      labelKey: 'report_cat_lost_pet',
      icon: Icons.pets_rounded,
      color: Color(0xFFEC407A),
    ),
    _CategoryDef(
      type: ReportTypes.foundPet,
      labelKey: 'report_cat_found_pet',
      icon: Icons.handshake_rounded,
      color: Color(0xFFFB923C),
    ),
    _CategoryDef(
      type: ReportTypes.poison,
      labelKey: 'report_cat_poison',
      icon: Icons.dangerous_rounded,
      color: Color(0xFF795548),
    ),
    _CategoryDef(
      type: ReportTypes.trap,
      labelKey: 'report_cat_trap',
      icon: Icons.gps_off_rounded,
      color: Color(0xFF6B7280),
    ),
    _CategoryDef(
      type: ReportTypes.strayPet,
      labelKey: 'report_cat_stray_pet',
      icon: Icons.pets_outlined,
      color: Color(0xFFA855F7),
    ),
    _CategoryDef(
      type: ReportTypes.busyTraffic,
      labelKey: 'report_cat_busy_traffic',
      icon: Icons.directions_car_rounded,
      color: Color(0xFFEF4444),
    ),
    _CategoryDef(
      type: ReportTypes.fireSmoke,
      labelKey: 'report_cat_fire_smoke',
      icon: Icons.local_fire_department_rounded,
      color: Color(0xFFEA580C),
    ),
    _CategoryDef(
      type: ReportTypes.flood,
      labelKey: 'report_cat_flood',
      icon: Icons.water_rounded,
      color: Color(0xFF3B82F6),
    ),
    _CategoryDef(
      type: ReportTypes.fallenTree,
      labelKey: 'report_cat_fallen_tree',
      icon: Icons.park_rounded,
      color: Color(0xFF16A34A),
    ),
    _CategoryDef(
      type: ReportTypes.chemical,
      labelKey: 'report_cat_chemical',
      icon: Icons.science_rounded,
      color: Color(0xFF9333EA),
    ),
    _CategoryDef(
      type: ReportTypes.wildlife,
      labelKey: 'report_cat_wildlife',
      icon: Icons.cruelty_free_rounded,
      color: Color(0xFF14B8A6),
    ),
    // v414 — 3 nouveaux types Premium (Daniel : "nouveau detail signeaux").
    _CategoryDef(
      type: ReportTypes.leashRequired,
      labelKey: 'report_cat_leash_required',
      icon: Icons.pets_rounded,
      color: Color(0xFF455A64),
    ),
    _CategoryDef(
      type: ReportTypes.heatHotGround,
      labelKey: 'report_cat_heat_hot_ground',
      icon: Icons.local_fire_department_outlined,
      color: Color(0xFFFF5722),
    ),
    _CategoryDef(
      type: ReportTypes.tickZone,
      labelKey: 'report_cat_tick_zone',
      icon: Icons.bug_report_rounded,
      color: Color(0xFF6D4C41),
    ),
    _CategoryDef(
      type: ReportTypes.other,
      labelKey: 'report_cat_other',
      icon: Icons.more_horiz_rounded,
      color: Color(0xFF6B7280),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.add_circle_rounded,
                color: const Color(0xFFDC2626), size: 22.sp),
            SizedBox(width: 8.w),
            InterText(
              text: 'report_screen_title'.tr,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 24.h),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: InterText(
                text: 'report_what_to_report'.tr,
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
              ),
            ),
            SizedBox(height: 4.h),
            Align(
              alignment: Alignment.centerLeft,
              child: InterText(
                text: 'report_pick_category_hint'.tr,
                fontSize: 12.sp,
                color: AppColors.greyText,
              ),
            ),
            SizedBox(height: 16.h),

            // ── Section Gratuit ──────────────────────────────────────
            _sectionHeader(
              context,
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF16A34A),
              label: 'report_section_free'.tr,
              hint: 'report_section_free_hint'.tr,
            ),
            SizedBox(height: 10.h),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8.w,
                mainAxisSpacing: 8.h,
                childAspectRatio: 0.85,
              ),
              itemCount: _freeCategories.length,
              itemBuilder: (_, i) => _buildCategoryTile(
                context,
                _freeCategories[i],
                isFree: true,
              ),
            ),

            SizedBox(height: 22.h),

            // ── Section Premium ───────────────────────────────────────
            _sectionHeader(
              context,
              icon: Icons.workspace_premium_rounded,
              color: const Color(0xFFF59E0B),
              label: 'report_section_premium'.tr,
              hint: 'report_section_premium_hint'.tr,
            ),
            SizedBox(height: 8.h),
            // v414 — Daniel : "précise que tout abonnement débloque les
            // signalements premium". Note visible sous l'en-tête Premium.
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Text('✨', style: TextStyle(fontSize: 13.sp)),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: InterText(
                      text: 'premium_signals_note'.tr,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF7C3AED),
                      maxLines: 3,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 10.h),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8.w,
                mainAxisSpacing: 8.h,
                childAspectRatio: 0.85,
              ),
              itemCount: _premiumCategories.length,
              itemBuilder: (_, i) => _buildCategoryTile(
                context,
                _premiumCategories[i],
                isFree: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required String hint,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InterText(
                  text: label,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
                SizedBox(height: 2.h),
                InterText(
                  text: hint,
                  fontSize: 10.sp,
                  color: AppColors.textSecondary(context),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(BuildContext context, _CategoryDef cat,
      {required bool isFree}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: () async {
          // v23.1 part 214 — Daniel : "j'ai fais un signalement et c
          // toujours ecris aucune alerte". MEME BUG QUE v213 (alerts_screen)
          // appliquait deja le fix, mais cette grid avait son propre
          // fallback (0,0) toxique. Si pas de GPS, on refuse la creation
          // au lieu de stocker un fantome.
          // v23.1.258 — Daniel : "les signalements ne marchent pas". CAUSE :
          // on capturait le GPS via Geolocator.getCurrentPosition (timeout 8s)
          // SANS fallback → si le GPS était lent/indispo (intérieur, cold
          // start), point==null → erreur "pas de GPS" → impossible de
          // signaler. FIX : LocationService (getLastKnownPosition INSTANTANÉ
          // en fallback + getCurrentPosition medium) — même robustesse que la
          // PawMap, qui a déjà ta position.
          LatLng? point;
          try {
            final pos = await LocationService().getCurrentLocation();
            if (pos != null) point = LatLng(pos.latitude, pos.longitude);
          } catch (_) {/* point reste null */}
          if (point == null || (point.latitude == 0 && point.longitude == 0)) {
            if (!context.mounted) return;
            CustomSnackbar.showError(
              title: 'alerts_no_gps_title'.tr,
              message: 'alerts_no_gps_msg'.tr,
            );
            return;
          }
          if (!context.mounted) return;
          final created = await CreateReportSheet.show(
            context,
            initialPoint: point,
            preselectedType: cat.type,
          );
          if (created && context.mounted) {
            Navigator.of(context).pop(true);
          }
        },
        child: Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            color: cat.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: cat.color.withValues(alpha: 0.22),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: cat.color.withValues(alpha: 0.08),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              // v23.1.262 — Daniel : "recentrer les icônes". Avant, le bloc
              // icône+label était centré dans la tuile, mais comme certains
              // labels tiennent sur 1 ligne et d'autres sur 2, la hauteur du
              // bloc variait → les icônes n'étaient pas alignées entre elles.
              // Fix : Positioned.fill (le Column occupe toute la tuile) +
              // hauteur de label FIXE (2 lignes réservées) → chaque icône est
              // exactement au même niveau, peu importe la longueur du label.
              Positioned.fill(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 34.w,
                      height: 34.w,
                      decoration: BoxDecoration(
                        color: cat.color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: cat.color.withValues(alpha: 0.40),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(cat.icon, color: Colors.white, size: 16.sp),
                    ),
                    SizedBox(height: 6.h),
                    SizedBox(
                      height: 24.h,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: InterText(
                          text: cat.labelKey.tr,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w700,
                          color: cat.color,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isFree)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF59E0B),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.star_rounded,
                        color: Colors.white, size: 10.sp),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryDef {
  final String type;
  final String labelKey;
  final IconData icon;
  final Color color;
  const _CategoryDef({
    required this.type,
    required this.labelKey,
    required this.icon,
    required this.color,
  });
}
