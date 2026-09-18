// v565 (point 38) — affichage moderne de la note d'un prestataire.
//
// Une seule source pour la carte prestataire, le détail, la liste de
// l'accueil et le détail de réservation :
//   • note > 0 ET au moins un avis → 5 étoiles (pleine / demie / vide),
//     valeur en gras, nombre d'avis en gris ;
//   • sinon → pastille « Nouveau » (jamais « 0.0 (0 avis) » ni étoiles vides).
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

const Color kRatingStarColor = Color(0xFFFFB300);

class RatingStars extends StatelessWidget {
  final double rating;
  final int reviewsCount;
  /// Taille des étoiles (sp). La valeur et le compteur suivent.
  final double size;
  /// Afficher « (N avis) » après la note.
  final bool showCount;
  /// Compact = une seule étoile + valeur (cartes étroites).
  final bool compact;
  /// Couleur de la pastille « Nouveau » (par défaut : couleur secondaire).
  final Color? newAccent;

  const RatingStars({
    super.key,
    required this.rating,
    required this.reviewsCount,
    this.size = 14,
    this.showCount = true,
    this.compact = false,
    this.newAccent,
  });

  bool get hasRating => rating > 0 && reviewsCount > 0;

  @override
  Widget build(BuildContext context) {
    if (!hasRating) {
      final c = newAccent ?? AppColors.textSecondary(context);
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded, size: (size - 2).sp, color: c),
            SizedBox(width: 4.w),
            InterText(
              text: 'v565_rating_new'.tr,
              fontSize: (size - 3).sp,
              fontWeight: FontWeight.w700,
              color: c,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    final value = InterText(
      text: rating.toStringAsFixed(1),
      fontSize: (size - 1).sp,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary(context),
      maxLines: 1,
    );
    final count = showCount
        ? Flexible(
            child: InterText(
              text: 'reviews_count_short'.trParams({'count': '$reviewsCount'}),
              fontSize: (size - 3).sp,
              color: AppColors.textSecondary(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )
        : null;

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: size.sp, color: kRatingStarColor),
          SizedBox(width: 3.w),
          value,
          if (count != null) ...[SizedBox(width: 3.w), count],
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          final IconData icon;
          if (i < rating.floor()) {
            icon = Icons.star_rounded;
          } else if (i == rating.floor() && rating - rating.floor() >= 0.25) {
            icon = Icons.star_half_rounded;
          } else {
            icon = Icons.star_outline_rounded;
          }
          return Icon(icon, size: size.sp, color: kRatingStarColor);
        }),
        SizedBox(width: 6.w),
        value,
        if (count != null) ...[SizedBox(width: 4.w), count],
      ],
    );
  }
}
