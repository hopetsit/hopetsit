import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// v441 — Barre « Autour de moi » + rayon km PARTAGÉE par les 3 accueils.
///
/// Extrait du `_buildSearchBlock` de l'accueil owner (maquettes 50/51) pour
/// éviter la duplication : la même UI sert
///   - owner  → filtre les prestataires autour de la ville choisie ;
///   - sitter → filtre les annonces owner autour de la ville choisie (bleu) ;
///   - walker → idem (vert).
///
/// Le widget est purement présentationnel : il reçoit la ville (label), le
/// rayon courant et les bornes, et remonte les changements via callbacks.
/// L'appelant décide quoi faire (recharger nearby prestataires, ou re-filtrer
/// localement le feed d'annonces par distance).
///
/// L'accent (couleur du rôle) colore le pin, le « km » et le slider :
///   - owner  : bleu/vert selon l'onglet actif ;
///   - sitter : bleu  (#2563EB) ;
///   - walker : vert  (#16A34A).
class AroundMeSearchBar extends StatelessWidget {
  const AroundMeSearchBar({
    super.key,
    required this.accent,
    required this.cityLabel,
    required this.radiusKm,
    required this.minRadiusKm,
    required this.maxRadiusKm,
    required this.onTapCity,
    required this.onRadiusChanged,
    required this.onRadiusCommit,
    this.midTickKm,
  });

  /// Couleur d'accent (rôle) : pin, valeur « km » et slider.
  final Color accent;

  /// Libellé de la ville actuelle (ex. « Paris, France » ou « Ma position »).
  final String cityLabel;

  /// Rayon courant en km (déjà borné par l'appelant).
  final double radiusKm;
  final double minRadiusKm;
  final double maxRadiusKm;

  /// Tap sur la carte localisation → ouvre le picker de ville (appelant).
  final VoidCallback onTapCity;

  /// Glissement du slider (mise à jour live de la valeur affichée).
  final ValueChanged<double> onRadiusChanged;

  /// Relâchement du slider → l'appelant applique le nouveau rayon (re-filtre /
  /// recharge). Séparé de [onRadiusChanged] pour ne déclencher la recherche
  /// qu'une fois, pas à chaque pixel.
  final ValueChanged<double> onRadiusCommit;

  /// Tick médian indicatif sous le slider. Si null, on prend le milieu
  /// mathématique (min+max)/2. L'accueil owner passe 50 km pour conserver
  /// son repère visuel d'origine.
  final int? midTickKm;

  @override
  Widget build(BuildContext context) {
    final current = radiusKm.clamp(minRadiusKm, maxRadiusKm).toDouble();
    // Tick médian indicatif : valeur fournie ou milieu mathématique.
    final midTick = midTickKm ?? ((minRadiusKm + maxRadiusKm) / 2).round();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.divider(context), width: 1),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Gauche : chip localisation (tappable → picker ville) ──
          Expanded(
            flex: 5,
            child: InkWell(
              borderRadius: BorderRadius.circular(12.r),
              onTap: onTapCity,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 16.sp, color: accent),
                        SizedBox(width: 4.w),
                        Flexible(
                          child: PoppinsText(
                            text: 'home_around_me'.tr,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Flexible(
                          child: InterText(
                            text: cityLabel,
                            fontSize: 11.sp,
                            color: AppColors.textSecondary(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_down_rounded,
                            size: 16.sp,
                            color: AppColors.textSecondary(context)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Container(width: 1, height: 48.h, color: AppColors.divider(context)),
          SizedBox(width: 10.w),
          // ── Droite : rayon (label + valeur + slider + ticks) ──
          Expanded(
            flex: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InterText(
                      text: 'home_radius'.tr,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
                    ),
                    PoppinsText(
                      text: '${current.toInt()} km',
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: accent,
                    inactiveTrackColor: accent.withValues(alpha: 0.18),
                    thumbColor: accent,
                    overlayColor: accent.withValues(alpha: 0.15),
                    trackHeight: 4,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 9),
                    // v494 — Daniel : la bulle « X km » qui apparaît en glissant
                    // avait un fond MARRON (défaut du thème) → ROSE + texte blanc.
                    valueIndicatorColor: const Color(0xFFEC4899),
                    valueIndicatorTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Slider(
                    value: current,
                    min: minRadiusKm,
                    max: maxRadiusKm,
                    divisions: ((maxRadiusKm - minRadiusKm) ~/ 10),
                    label: '${current.toInt()} km',
                    onChanged: (value) {
                      onRadiusChanged(
                        value.clamp(minRadiusKm, maxRadiusKm).toDouble(),
                      );
                    },
                    onChangeEnd: (value) {
                      onRadiusCommit(
                        value.clamp(minRadiusKm, maxRadiusKm).toDouble(),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InterText(
                      text: '${minRadiusKm.toInt()} km',
                      fontSize: 9.sp,
                      color: AppColors.textSecondary(context),
                    ),
                    InterText(
                      text: '$midTick km',
                      fontSize: 9.sp,
                      color: AppColors.textSecondary(context),
                    ),
                    InterText(
                      text: '${maxRadiusKm.toInt()} km',
                      fontSize: 9.sp,
                      color: AppColors.textSecondary(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
