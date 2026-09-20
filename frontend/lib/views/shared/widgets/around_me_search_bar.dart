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
///
/// v571 — REDESIGN (Daniel : « le bloc de gauche, je croyais que ça ne servait
/// à rien »). L'ancienne disposition gauche/droite coupée par un trait cachait
/// que le bloc ville était CLIQUABLE. Nouvelle disposition VERTICALE dans la
/// même carte :
///   · ligne 1 = une pastille-bouton pleine largeur (rond teinté + « Autour de
///     moi » / nom de ville en gras + « Changer › » en accent) → `onTapCity` ;
///   · ligne 2 = « Rayon » / valeur en accent, puis le slider pleine largeur
///     avec ses 3 graduations.
/// L'API publique et la logique (onRadiusChanged / onRadiusCommit, bornes,
/// divisions) sont INCHANGÉES : l'accueil propriétaire continue de marcher.
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
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 10.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: AppColors.divider(context).withValues(alpha: 0.7),
          width: 1,
        ),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cityButton(context),
          SizedBox(height: 12.h),
          _radiusRow(context, current),
          _slider(context, current),
          _ticks(context, midTick),
        ],
      ),
    );
  }

  /// Ligne 1 — pastille-bouton PLEINE LARGEUR, clairement cliquable.
  Widget _cityButton(BuildContext context) {
    return Material(
      color: accent.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(16.r),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey<String>('around_me_city_button'),
        onTap: onTapCity,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: accent.withValues(alpha: 0.20),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34.w,
                height: 34.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  size: 18.sp,
                  color: accent,
                ),
              ),
              SizedBox(width: 10.w),
              // Le bloc texte prend toute la place restante : les libellés
              // longs (allemand, polonais) sont tronqués, jamais débordants.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InterText(
                      text: 'home_around_me'.tr,
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 1.h),
                    PoppinsText(
                      text: cityLabel,
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              // Libellé-action : borné en largeur et tronqué pour ne jamais
              // pousser la ville hors de la carte.
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 86.w),
                child: InterText(
                  text: 'home571_change'.tr,
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w700,
                  color: accent,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18.sp,
                color: accent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ligne 2 — « Rayon » à gauche, valeur en accent à droite.
  Widget _radiusRow(BuildContext context, double current) {
    return Row(
      children: [
        Expanded(
          child: InterText(
            text: 'home_radius'.tr,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: 8.w),
        PoppinsText(
          text: '${current.toInt()} km',
          fontSize: 13.sp,
          fontWeight: FontWeight.w800,
          color: accent,
          maxLines: 1,
        ),
      ],
    );
  }

  /// Slider pleine largeur — logique STRICTEMENT identique à l'origine.
  Widget _slider(BuildContext context, double current) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: accent,
        inactiveTrackColor: accent.withValues(alpha: 0.18),
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: 0.15),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
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
          onRadiusChanged(value.clamp(minRadiusKm, maxRadiusKm).toDouble());
        },
        onChangeEnd: (value) {
          onRadiusCommit(value.clamp(minRadiusKm, maxRadiusKm).toDouble());
        },
      ),
    );
  }

  /// Les 3 graduations sous le slider (min / milieu / max).
  Widget _ticks(BuildContext context, int midTick) {
    Widget tick(String text, TextAlign align) => Expanded(
          child: InterText(
            text: text,
            fontSize: 9.sp,
            color: AppColors.textSecondary(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: align,
          ),
        );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 2.w),
      child: Row(
        children: [
          tick('${minRadiusKm.toInt()} km', TextAlign.start),
          tick('$midTick km', TextAlign.center),
          tick('${maxRadiusKm.toInt()} km', TextAlign.end),
        ],
      ),
    );
  }
}
